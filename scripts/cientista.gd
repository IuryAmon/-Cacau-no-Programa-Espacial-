extends CharacterBody2D

# Emitido quando o diálogo principal termina — a plataforma escuta isso
signal plataforma_acionada

# Timelines do Dialogic
const TIMELINE_PRINCIPAL    = "cientista_fase1"
const TIMELINE_SEM_ITENS    = "cientista_dica_sem_itens"
const TIMELINE_TEM_H2       = "cientista_dica_tem_h2"
const TIMELINE_TEM_O2       = "cientista_dica_tem_o2"
const TIMELINE_TEM_AMBOS    = "cientista_dica_tem_ambos"
const TIMELINE_LASER_ABERTO = "cientista_laser_aberto"

## Marque na instância que já é o Dr. Chico revelado (a do laboratório): ela
## não some quando a revelação acontece — é justamente onde ele passa a morar —
## e garante o nome certo mesmo se a cena for aberta direto no editor.
@export var apos_revelacao: bool = false
## Timeline única desta instância. Vazio = ele escolhe pela situação da fase 1
## (dicas de H2/O2, laser aberto, etc), que é o comportamento do world1.
@export var timeline_fixa: String = ""

@export_group("Patrulha")
## Liga o vaivém dele pela sala. Desligado, ele fica plantado no lugar como
## sempre foi — é assim que a instância do world1 continua.
@export var patrulha: bool = false
## Quanto ele se afasta, para cada lado, do ponto onde foi posto na cena.
@export var patrulha_alcance: float = 110.0
## Velocidade da caminhada, em pixels por segundo.
@export var patrulha_velocidade: float = 48.0
## Faixa de pausa (segundos) ao chegar numa ponta, antes de virar e voltar.
@export var patrulha_pausa_min: float = 2.2
@export var patrulha_pausa_max: float = 4.5
@export_group("")

# Arranque e freada suaves: sem isso ele parte e para de forma seca e os pés
# patinam na virada.
const PATRULHA_ACELERACAO := 240.0
# A partir daqui a animação de andar entra (em px/s).
const LIMIAR_ANDANDO := 4.0
# Onde ficam os sensores, à frente dele, na direção em que está indo.
const SENSOR_CHAO_X := 26.0
const SENSOR_PAREDE_X := 30.0

var player_perto    : bool = false
var dialogo_ativo   : bool = false
# True quando apertou "interact" com o player no ar: assim que ele pisar no
# chão, o diálogo começa (senão trava a animação de pulo no meio do ar)
var dialogo_pendente : bool = false
var plataforma_sobe : bool = false  # vira true após acionar a plataforma
var laser_aberto    : bool = false  # vira true quando os lasers são desativados

var player_ref : Node = null  # referência ao player que está perto

# --- Patrulha ---
var _origem_x : float = 0.0    # ponto em que ele foi posto na cena; o vaivém é em volta dele
var _direcao  : int   = 1      # 1 = indo para a direita, -1 = para a esquerda
var _espera   : float = 0.0    # segundos restantes da pausa na ponta do trecho
var _x_anterior : float = 0.0  # x do quadro passado, para perceber que emperrou
var _parado_ha  : float = 0.0  # há quanto tempo ele empurra algo sem sair do lugar

var gravity : float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var exclamacao_animada = $ExclamacaoAnimada
@onready var sprite = $AnimatedSprite2D
@onready var raio_chao   : RayCast2D = $RaioChao    # olha o piso à frente: não anda para fora da plataforma
@onready var raio_parede : RayCast2D = $RaioParede  # olha parede/móvel à frente


func _ready() -> void:
	sprite.flip_h = true

	# O desenho dele olha para a esquerda, então flip_h ligado = virado para a
	# direita. É de onde a patrulha parte.
	_origem_x = global_position.x
	_direcao = 1 if sprite.flip_h else -1
	_x_anterior = global_position.x
	raio_chao.enabled = patrulha
	raio_parede.enabled = patrulha
	_posicionar_sensores()
	exclamacao_animada.visible = false
	exclamacao_animada.stop()
	$Area2D.body_entered.connect(_on_player_entrou)
	$Area2D.body_exited.connect(_on_player_saiu)
	Dialogic.text_signal.connect(_on_dialogic_signal)
	Dialogic.VAR.variable_was_set.connect(_on_variable_was_set)

	# Numa cena recarregada os sinais que mudaram o estado dele não voltam a ser
	# emitidos: ele se lembra sozinho de onde a conversa tinha parado.
	laser_aberto = EstadoMundo.ja_feito(self, "laser_aberto")
	if EstadoMundo.ja_feito(self, "plataforma"):
		plataforma_sobe = true
		plataforma_acionada.emit()

	if apos_revelacao:
		# Ele já é o Dr. Chico aqui, mesmo se a cena for aberta direto no editor
		# sem passar pela cutscene do world1.
		Dialogic.VAR.set_variable("reveal_name", "Dr. Chico")
	elif EstadoMundo.revelou_dr_chico:
		# Voltando ao world1 depois da revelação, o "variable_was_set" não
		# dispara de novo — este placeholder já não deveria estar no mapa.
		_sumir()

	# Não deixa o corpo físico dele empurrar/travar o player nem as caixas empurráveis
	# (continua colidindo normalmente com o chão)
	await get_tree().process_frame
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		add_collision_exception_with(player_node)
		# O sensor de parede também ignora o player: quem manda ele parar
		# quando você chega perto é a Area2D, não um esbarrão.
		raio_parede.add_exception(player_node)
		raio_chao.add_exception(player_node)
	for caixa in get_tree().get_nodes_in_group("empurravel"):
		add_collision_exception_with(caixa)


func _on_dialogic_signal(signal_name: String) -> void:
	if signal_name == "missao_aceita":
		plataforma_sobe = true
		EstadoMundo.marcar_feito(self, "plataforma")
		emit_signal("plataforma_acionada")


func on_laser_aberto() -> void:
	laser_aberto = true
	EstadoMundo.marcar_feito(self, "laser_aberto")


# Some que o "Dr. Chico" já se revelou (cutscene final): este NPC placeholder
# não faz mais sentido continuar presente no mapa.
func _on_variable_was_set(info: Dictionary) -> void:
	if apos_revelacao:
		return
	if info.get("variable") == "reveal_name" and info.get("new_value") == "Dr. Chico":
		_sumir()


func _sumir() -> void:
	visible = false
	set_physics_process(false)
	set_process(false)
	$Area2D.set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)
	raio_chao.enabled = false
	raio_parede.enabled = false



func _process(_delta: float) -> void:
	# Só verifica input se o player estiver perto e nenhum diálogo estiver rodando
	if player_perto and not dialogo_ativo and Interacao.pediu():
		if player_ref and player_ref.has_method("is_on_floor") and not player_ref.is_on_floor():
			# No ar: guarda o pedido e espera ele pisar no chão
			dialogo_pendente = true
		else:
			_iniciar_dialogo()

	# Pedido pendente: assim que o player tocar o chão, inicia o diálogo
	if dialogo_pendente and player_perto and not dialogo_ativo:
		if player_ref and player_ref.has_method("is_on_floor") and player_ref.is_on_floor():
			dialogo_pendente = false
			_iniciar_dialogo()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	# A horizontal nunca salta de um valor para o outro: ele ganha e perde
	# velocidade aos poucos, então a caminhada tem arranque e freada.
	velocity.x = move_toward(velocity.x, _velocidade_desejada(delta), PATRULHA_ACELERACAO * delta)
	move_and_slide()
	_atualizar_animacao()


# ─────────────────────────────────────────────
#  Patrulha (vaivém pela sala)
# ─────────────────────────────────────────────

## Quanto ele quer andar neste quadro. Zero em toda situação que pede que ele
## fique parado: patrulha desligada, player por perto, diálogo rolando, pausa
## na ponta do trecho ou pé fora do chão.
func _velocidade_desejada(delta: float) -> float:
	if not patrulha or player_perto or dialogo_ativo or dialogo_pendente:
		_parado_ha = 0.0
		_x_anterior = global_position.x
		return 0.0
	if not is_on_floor():
		return 0.0

	if _espera > 0.0:
		_espera -= delta
		return 0.0

	# Emperrou em algo que os sensores não pegaram (um degrau, um móvel baixo):
	# ele quer andar mas o corpo não sai do lugar. Trata como parede e volta.
	var avanco := absf(global_position.x - _x_anterior)
	_x_anterior = global_position.x
	if absf(velocity.x) > LIMIAR_ANDANDO and avanco < absf(velocity.x) * delta * 0.4:
		_parado_ha += delta
	else:
		_parado_ha = 0.0

	_posicionar_sensores()
	raio_chao.force_raycast_update()
	raio_parede.force_raycast_update()

	if _parado_ha > 0.35 or _precisa_virar():
		_parado_ha = 0.0
		_direcao = -_direcao
		_posicionar_sensores()
		_espera = randf_range(patrulha_pausa_min, patrulha_pausa_max)
		return 0.0

	return patrulha_velocidade * float(_direcao)


## Leva os dois sensores para o lado em que ele está indo. Quem força a leitura
## é o _velocidade_desejada, dentro do passo de física — o RayCast2D só se
## atualiza sozinho no fim do quadro, e a decisão de virar é tomada antes.
func _posicionar_sensores() -> void:
	raio_chao.position.x = SENSOR_CHAO_X * float(_direcao)
	raio_parede.target_position.x = SENSOR_PAREDE_X * float(_direcao)


func _precisa_virar() -> bool:
	# Chegou na ponta do trecho dele
	if (global_position.x - _origem_x) * float(_direcao) >= patrulha_alcance:
		return true
	# Parede, caixa ou móvel logo à frente
	if raio_parede.is_colliding():
		return true
	# Acabou o chão: ele não anda para fora da plataforma
	if not raio_chao.is_colliding():
		return true
	return false


## Troca entre a pose parada e a caminhada, e cuida de para onde ele olha.
func _atualizar_animacao() -> void:
	if absf(velocity.x) > LIMIAR_ANDANDO:
		# O desenho olha para a esquerda: andar para a direita é o flip.
		sprite.flip_h = velocity.x > 0.0
		# Os pés acompanham a velocidade real, então nada de patinar no
		# arranque nem na freada.
		sprite.speed_scale = clampf(absf(velocity.x) / maxf(patrulha_velocidade, 1.0), 0.45, 1.6)
		if sprite.animation != "andando":
			sprite.play("andando")
		return

	sprite.speed_scale = 1.0
	if sprite.animation != "default":
		sprite.play("default")
	# Parado com alguém por perto: termina o passo e se vira para a pessoa.
	if patrulha and player_perto and player_ref:
		sprite.flip_h = player_ref.global_position.x > global_position.x

# ─────────────────────────────────────────────
#  Detecção de proximidade
# ─────────────────────────────────────────────

func _on_player_entrou(body: Node) -> void:
	if body.name == "Player":
		player_perto = true
		player_ref = body
		PopupFX.mostrar(exclamacao_animada)


func _on_player_saiu(body: Node) -> void:
	if body.name == "Player":
		player_perto = false
		player_ref = null
		dialogo_pendente = false
		# Um respiro antes de voltar a andar: ele não sai em disparada no
		# instante em que você vira as costas.
		_espera = maxf(_espera, 0.5)
		PopupFX.esconder(exclamacao_animada)


# ─────────────────────────────────────────────
#  Diálogo
# ─────────────────────────────────────────────

func _iniciar_dialogo() -> void:
	dialogo_ativo = true

	# Vira para o lado do player
	if player_ref:
		sprite.flip_h = player_ref.global_position.x > global_position.x

	# Trava o movimento do player durante o diálogo
	if player_ref:
		player_ref.pode_se_mover = false

	# Esconde a exclamação enquanto o diálogo está aberto
	PopupFX.esconder(exclamacao_animada)

	var timeline : String
	if not timeline_fixa.is_empty():
		timeline = timeline_fixa
	elif laser_aberto:
		timeline = TIMELINE_LASER_ABERTO
	elif not plataforma_sobe:
		timeline = TIMELINE_PRINCIPAL
	else:
		var tem_h2 = Inventario.tem_item("Cilindro_de_Hidrogenio")
		var tem_o2 = Inventario.tem_item("Cilindro_Oxigenio")
		if tem_h2 and tem_o2:
			timeline = TIMELINE_TEM_AMBOS
		elif tem_h2:
			timeline = TIMELINE_TEM_H2
		elif tem_o2:
			timeline = TIMELINE_TEM_O2
		else:
			timeline = TIMELINE_SEM_ITENS

	# Aproxima a câmera dos dois personagens durante o diálogo
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("aproximar"):
		camera.aproximar(self)

	# Conecta o sinal de fim ANTES de iniciar (sinal fica no autoload Dialogic)
	Dialogic.timeline_ended.connect(_on_dialogo_terminou, CONNECT_ONE_SHOT)
	Dialogic.start(timeline)


func _on_dialogo_terminou() -> void:
	dialogo_ativo = false

	# Libera o movimento do player
	if player_ref:
		player_ref.pode_se_mover = true

	# Volta a câmera ao normal
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("restaurar"):
		camera.restaurar()

	# Volta a mostrar a exclamação se o player ainda estiver perto
	if player_perto:
		PopupFX.mostrar(exclamacao_animada)
