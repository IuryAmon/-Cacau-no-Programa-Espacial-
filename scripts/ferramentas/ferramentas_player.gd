class_name FerramentasPlayer
extends Node

# --- FERRAMENTAS DA PERSONAGEM (componente anexado ao Player) ---
#
# Como pede o plano: cada ferramenta nasce como componente isolado, anexado
# ao player e ativado por flag do Progresso — nada aqui mexe na física normal
# do player além do gancho "ferramenta_controla_movimento" (usado no dash).
#
#   F           -> arremessa o bumerangue nas 8 direções, lidas do
#                  teclado/analógico (fase 1 em diante). O arremesso HERDA O
#                  MOMENTO da personagem: correndo para a frente ele sai mais
#                  rápido e mais longe, correndo para trás sai fraco (a conta
#                  está em bumerangue.gd). Com ele já no ar, F de novo não é
#                  ignorado: chama o bumerangue de volta no meio do voo.
#   Clique esq. -> arremessa o bumerangue mirado NO CURSOR — qualquer ângulo,
#                  não só as 8 direções. As duas formas convivem: F para quem
#                  joga só de teclado/controle, clique para mira de precisão.
#   Shift       -> dash da mochila de N₂ em 8 direções, no chão ou no ar (fase
#                  2 em diante); o jato apaga chamas no caminho. Enquanto dura,
#                  a personagem fica INVULNERÁVEL A DANO (esta_invencivel_dash
#                  no player.gd) — e já atravessa qualquer Sentinela mesmo fora
#                  do dash, porque elas não colidem com o player (só com
#                  paredes; ver collision_layer em sentinela.gd). No ar vale 1
#                  dash por salto — volta ao pisar no chão ou tocar uma
#                  válvula de purga
#   T           -> acende/apaga o sinalizador quimioluminescente (fase 3)
#   Botas       -> passivas: o PisoEletrificado consulta o Progresso direto
#   M           -> DEBUG: equipa a mochila na hora, para testar o dash

# --- AJUSTE FINO DO ARREMESSO ---
#
# A física do voo mora em bumerangue.gd; o que fica aqui é o retorno dela para
# quem arremessou. Os três são dosados pela FORÇA do arremesso (0 parada, 1 no
# teto do momento herdado), então arremessar em corrida se vê e se sente, não
# só se mede.

## Coice do arremesso, só no ar — no chão o atrito engoliria. É terceira lei
## em dose de tempero: 70 px/s contra os 475 do pulo não movem level design
## nenhum, mas tiram do arremesso a sensação de que ele não custa nada.
const ARREMESSO_COICE_AR := 70.0
const ARREMESSO_TREMOR_MIN := 1.2
const ARREMESSO_TREMOR_MAX := 4.5


# --- AJUSTE FINO DO DASH ---
#
# Os números seguem a receita dos dashes de plataformer moderno (Celeste,
# Katana ZERO): curto, em 8 direções, com congelamento de impacto no primeiro
# frame e inércia sobrando no fim. Mexer aqui muda o "feel" todo.

## ~190 px de arranco + a sobra de inércia: alcance igual ou maior que o dash
## antigo (920 px/s por 0,22 s), pra não quebrar os vãos já desenhados.
const DASH_VELOCIDADE := 1050.0
## Curto de propósito: dash longo vira "voar" e some com a leitura do impulso.
const DASH_DURACAO := 0.18
## Fração da velocidade que sobra quando o dash acaba — é ela que faz o
## movimento escoar em vez de bater num muro invisível.
const DASH_FIM_FATOR := 0.5
## Congelamento de impacto (hitstop): o mundo inteiro para por 3 frames no
## instante do dash. É o truque que dá peso ao golpe.
const DASH_CONGELAMENTO := 0.05
## Tempo mínimo entre dois dashes (impede metralhar dash na válvula de purga).
const DASH_COOLDOWN := 0.15
## Apertar Shift um pouco antes da recarga chegar ainda conta.
const DASH_BUFFER := 0.12
## Pequeno atraso na recarga ao tocar o chão, pra não recarregar em raspões
## de um frame só.
const DASH_RECARGA_CHAO := 0.05
## Intervalo entre os fantasmas do rastro.
const DASH_FANTASMA_INTERVALO := 0.02
const DASH_FANTASMA_VIDA := 0.22
const DASH_TREMOR := 4.0
## Enquanto o dash corre, a Cacau fica gelada (azul do N₂); acabou o arranco,
## a cor volta na hora — não espera pisar no chão.
const COR_DASH := Color(0.62, 0.78, 1.0)
## Pose do dash: o dash trava no ÚLTIMO frame desta animação.
const ANIM_POSE_DASH := "run"

## O sinalizador dura ~2 minutos de luz contínua por carga.
const DRENO_SINALIZADOR := 1.0 / 120.0

var player: CharacterBody2D = null

var _sprite: AnimatedSprite2D = null
var _bumerangue_no_ar: bool = false
## O bumerangue em voo, para o segundo toque poder chamá-lo de volta. Some em
## bumerangue_voltou(), que é chamado no instante da captura — antes do nó
## morrer de fato, que ainda vive uns quadros escoando som e rastro.
var _bumerangue: Bumerangue = null

# --- ESTADO DO DASH ---
var _dash_disponivel: bool = true
var _dash_restante: float = 0.0
var _dash_direcao: Vector2 = Vector2.RIGHT
var _dash_cooldown: float = 0.0
var _dash_buffer: float = 0.0
var _dash_recarga_chao: float = 0.0
var _dash_fantasma: float = 0.0
var _escala_base: Vector2 = Vector2.ONE
var _tween_escala: Tween = null
var _tecla_m_estava_pressionada: bool = false

# Congelamento de impacto: mexe no Engine.time_scale, então guarda o valor
# anterior e devolve mesmo se a cena morrer no meio.
var _congelado_ate_ms: int = 0
var _escala_tempo_anterior: float = 1.0

var _luz: PointLight2D = null
var _jato: Area2D = null
var _jato_particulas: CPUParticles2D = null
var _barra_fundo: ColorRect = null
var _barra_carga: ColorRect = null


static func instalar(no_player: Node) -> FerramentasPlayer:
	var existente := no_player.get_node_or_null("Ferramentas")
	if existente:
		return existente as FerramentasPlayer
	var componente := FerramentasPlayer.new()
	componente.name = "Ferramentas"
	no_player.add_child(componente)
	return componente


func _ready() -> void:
	player = get_parent()
	_sprite = player.get_node_or_null("AnimatedSprite2D")
	if _sprite:
		_escala_base = _sprite.scale

	# --- LUZ DO SINALIZADOR (só aparece quando a habilidade existir) ---
	_luz = PointLight2D.new()
	_luz.name = "LuzSinalizador"
	var textura := GradientTexture2D.new()
	textura.width = 512
	textura.height = 512
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	var gradiente := Gradient.new()
	gradiente.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	gradiente.offsets = PackedFloat32Array([0.0, 1.0])
	textura.gradient = gradiente
	_luz.texture = textura
	_luz.color = Color(0.75, 0.95, 0.6)
	_luz.energy = 1.4
	_luz.texture_scale = 2.6
	_luz.position = Vector2(0, -30)
	_luz.enabled = false
	player.add_child.call_deferred(_luz)

	# --- JATO DE N₂ DO DASH (apaga chamas enquanto o dash dura) ---
	# A Area2D fica no peito da personagem e GIRA junto com a direção do
	# dash, pra faixa de gás acompanhar o caminho percorrido.
	_jato = Area2D.new()
	_jato.name = "JatoN2"
	_jato.monitoring = false
	_jato.position = Vector2(0, -30)
	Blockout.forma_ret(_jato, Vector2(140, 64), Vector2.ZERO)
	_jato.area_entered.connect(_on_jato_area_entered)
	player.add_child.call_deferred(_jato)

	_jato_particulas = CPUParticles2D.new()
	_jato_particulas.amount = 30
	_jato_particulas.lifetime = 0.25
	_jato_particulas.emitting = false
	_jato_particulas.spread = 20.0
	_jato_particulas.initial_velocity_min = 250.0
	_jato_particulas.initial_velocity_max = 420.0
	_jato_particulas.gravity = Vector2.ZERO
	_jato_particulas.scale_amount_min = 2.0
	_jato_particulas.scale_amount_max = 5.0
	_jato_particulas.color = Color(0.75, 0.88, 1.0, 0.8)
	_jato_particulas.position = Vector2(0, -30)
	player.add_child.call_deferred(_jato_particulas)

	# --- BARRINHA DE CARGA DO SINALIZADOR (acima da cabeça) ---
	_barra_fundo = ColorRect.new()
	_barra_fundo.color = Color(0, 0, 0, 0.6)
	_barra_fundo.size = Vector2(44, 7)
	_barra_fundo.position = Vector2(-22, -72)
	_barra_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra_fundo.visible = false
	player.add_child.call_deferred(_barra_fundo)

	_barra_carga = ColorRect.new()
	_barra_carga.color = Color(0.7, 0.95, 0.5)
	_barra_carga.size = Vector2(40, 3)
	_barra_carga.position = Vector2(-20, -70)
	_barra_carga.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra_carga.visible = false
	player.add_child.call_deferred(_barra_carga)


func _facing() -> float:
	if _sprite and _sprite.flip_h:
		return -1.0
	return 1.0


func _physics_process(delta: float) -> void:
	if player == null:
		return

	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_dash_buffer = maxf(_dash_buffer - delta, 0.0)
	_atualizar_cor_dash(delta)

	# --- DASH EM ANDAMENTO ---
	if _dash_restante > 0.0:
		_atualizar_dash(delta)
	elif player.is_on_floor():
		# Pisar no chão devolve o dash (com um respiro, pra não recarregar
		# em encostões de um frame).
		_dash_recarga_chao += delta
		if _dash_recarga_chao >= DASH_RECARGA_CHAO:
			_recarregar_dash()
	else:
		_dash_recarga_chao = 0.0

	# --- SINALIZADOR: dreno e visual ---
	_atualizar_sinalizador(delta)

	# Atalho de teste (vale mesmo com diálogo aberto).
	_debug_equipar_mochila()

	# Nada de ferramentas enquanto diálogo/puzzle segura a tela ou o player
	# está travado (cutscene, dano).
	if Interacao.ocupada() or not player.pode_se_mover:
		return

	# --- BUMERANGUE: F (8 direções) ou clique esquerdo (mirado no cursor) ---
	var pediu_bumerangue_teclado := Input.is_action_just_pressed("arremessar")
	var pediu_bumerangue_mouse := Input.is_action_just_pressed("arremessar_mouse")
	if (pediu_bumerangue_teclado or pediu_bumerangue_mouse) \
			and Progresso.tem_habilidade("bumerangue"):
		if _bumerangue_no_ar:
			# Com ele no ar o mesmo botão vira CHAMADO: o voo dá meia volta na
			# hora. É o que transforma o alcance de número fixo em decisão —
			# encurta para pegar de novo antes, ou deixa ir até o fim.
			if is_instance_valid(_bumerangue):
				_bumerangue.chamar_de_volta()
		else:
			_arremessar_bumerangue(
				_mira_do_mouse() if pediu_bumerangue_mouse else _ler_direcao_input())

	# --- DASH DA MOCHILA (Shift + direção, no chão ou no ar) ---
	if Input.is_action_just_pressed("dash"):
		_dash_buffer = DASH_BUFFER

	if _dash_buffer > 0.0 and Progresso.tem_habilidade("mochila") \
			and _dash_disponivel and _dash_restante <= 0.0 and _dash_cooldown <= 0.0:
		_dash_buffer = 0.0
		_iniciar_dash(_ler_direcao_input())

	# --- SINALIZADOR (T liga/desliga) ---
	if Input.is_action_just_pressed("luz") and Progresso.tem_habilidade("sinalizador"):
		Progresso.sinalizador_aceso = not Progresso.sinalizador_aceso


# --- DEBUG: TECLA M ------------------------------------------------------
#
# Equipa a mochila de N₂ na hora, em qualquer fase, sem precisar resolver o
# armário da Torre de Gases — é só para testar o dash. Mesmo espírito da
# tecla K do player.gd (coleta os cilindros do puzzle).

func _debug_equipar_mochila() -> void:
	var pressionada := Input.is_physical_key_pressed(KEY_M)
	if pressionada and not _tecla_m_estava_pressionada \
			and not Progresso.tem_habilidade("mochila"):
		Progresso.dar_habilidade("mochila")
		print("DEBUG [Ferramentas]: mochila de N₂ equipada pela tecla M.")
		Blockout.aviso_flutuante(player.get_parent(),
			player.global_position + Vector2(0, -120),
			"DEBUG: mochila de N₂ equipada — Shift + direção", Color(0.5, 0.85, 1.0))
	_tecla_m_estava_pressionada = pressionada


# --- MIRA COMPARTILHADA (dash e bumerangue) -----------------------------

## Direção travada nas 8 direções, lida das setas/WASD ou do analógico. Sem
## nenhuma tecla apontada, vale o lado para onde a personagem está olhando.
## Serve para os dois arranques: o dash da mochila e o arremesso do bumerangue.
func _ler_direcao_input() -> Vector2:
	var bruto := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	var dir := Vector2(
		0.0 if absf(bruto.x) < 0.35 else signf(bruto.x),
		0.0 if absf(bruto.y) < 0.35 else signf(bruto.y)
	)
	if dir == Vector2.ZERO:
		dir.x = _facing()
	return dir.normalized()


## Direção EXATA até o cursor (qualquer ângulo, sem travar nas 8 direções) —
## só para o arremesso do bumerangue no clique. Mouse em cima do player (ou
## sem mouse real, como no headless) cai no mesmo fallback do teclado.
func _mira_do_mouse() -> Vector2:
	var ate_mouse := player.get_global_mouse_position() - player.global_position
	if ate_mouse.length_squared() < 1.0:
		return Vector2(_facing(), 0.0)
	return ate_mouse.normalized()


# --- BUMERANGUE ---------------------------------------------------------

## O arremesso em si. player.velocity vai inteiro para o Bumerangue, que
## projeta no eixo da mira e decide dali a velocidade e o alcance do voo —
## é essa projeção que faz o arremesso em corrida valer a pena (e o arremesso
## correndo para trás sair fraco).
func _arremessar_bumerangue(mira: Vector2) -> void:
	if _sprite and mira.x != 0.0:
		_sprite.flip_h = mira.x < 0.0

	# O gesto do braço. Vem antes do lançamento de propósito: a pose já vira a
	# personagem para o lado da mira, e é dessa mão que o bumerangue sai.
	player.tocar_arremesso_bumerangue(mira.x)

	_bumerangue_no_ar = true
	_bumerangue = Bumerangue.lancar(player, self, mira, player.velocity)
	var forca: float = _bumerangue.forca

	if not player.is_on_floor():
		player.velocity -= mira * ARREMESSO_COICE_AR * forca

	_pancada_arremesso(forca)

	var camera = player.get_viewport().get_camera_2d()
	if camera and camera.has_method("disparar_tremor"):
		camera.disparar_tremor(lerpf(ARREMESSO_TREMOR_MIN, ARREMESSO_TREMOR_MAX, forca))


func bumerangue_voltou() -> void:
	_bumerangue_no_ar = false
	_bumerangue = null


## Comprime a personagem no gesto do arremesso e solta em elástico. Mesmo
## parada ela dá o estufão (o piso de 0.55): a força só decide o TAMANHO do
## gesto, nunca se ele acontece. Usa o tween da esticada do dash de propósito
## — as duas nunca podem estar puxando a escala ao mesmo tempo.
func _pancada_arremesso(forca: float) -> void:
	if _sprite == null:
		return
	if _tween_escala and _tween_escala.is_valid():
		_tween_escala.kill()
	var peso := lerpf(0.55, 1.0, forca)
	_sprite.scale = _escala_base * Vector2(1.0 - 0.16 * peso, 1.0 + 0.14 * peso)
	_soltar_esticada()


# --- DASH ---------------------------------------------------------------

func _iniciar_dash(dir: Vector2) -> void:
	_dash_disponivel = false
	_dash_restante = DASH_DURACAO
	_dash_direcao = dir
	_dash_fantasma = 0.0
	_dash_recarga_chao = 0.0

	player.ferramenta_controla_movimento = true
	# Janela de invulnerabilidade do dash: flag própria (ver o comentário dela
	# em player.gd) — some sozinha em _terminar_dash(), sem depender de timer.
	player.esta_invencivel_dash = true
	player.velocity = dir * DASH_VELOCIDADE
	# Um dash pra baixo não pode ser lido como tombo depois.
	player.maior_velocidade_queda = 0.0

	# O dash toma o sprite para si (pose congelada): um gesto de arremesso em
	# curso tem de sair da frente agora, senão ele voltaria a mandar na
	# animação assim que o dash acabasse.
	player.cancelar_arremesso_bumerangue()

	if _sprite:
		if dir.x != 0.0:
			_sprite.flip_h = dir.x < 0.0
		# Pose congelada no meio do voo: o rastro e a esticada fazem a
		# leitura do movimento, o sprite só precisa ficar quieto. O último
		# frame do "run" (hoje o 11) é o da passada mais esticada — é ele que
		# lê como impulso.
		if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(ANIM_POSE_DASH):
			_sprite.animation = ANIM_POSE_DASH
			_sprite.frame = maxi(_sprite.sprite_frames.get_frame_count(ANIM_POSE_DASH) - 1, 0)
		_sprite.pause()
		_esticar_sprite(dir)

	# Jato de N₂ girado pra faixa acompanhar o caminho do dash.
	_jato.rotation = dir.angle()
	_jato.set_deferred("monitoring", true)
	_jato_particulas.direction = -dir
	_jato_particulas.emitting = true

	var camera = player.get_viewport().get_camera_2d()
	if camera and camera.has_method("disparar_tremor"):
		camera.disparar_tremor(DASH_TREMOR)

	_soltar_fantasma()
	_congelar(DASH_CONGELAMENTO)


func _atualizar_dash(delta: float) -> void:
	_dash_restante -= delta
	# Velocidade CONSTANTE do começo ao fim: é isso que faz o dash parecer um
	# corte na tela em vez de um empurrão que vai morrendo.
	player.velocity = _dash_direcao * DASH_VELOCIDADE

	_dash_fantasma -= delta
	if _dash_fantasma <= 0.0:
		_dash_fantasma = DASH_FANTASMA_INTERVALO
		_soltar_fantasma()

	if _dash_restante <= 0.0:
		_terminar_dash()


func _terminar_dash() -> void:
	_dash_restante = 0.0
	_dash_cooldown = DASH_COOLDOWN
	player.ferramenta_controla_movimento = false
	player.esta_invencivel_dash = false
	# Sobra de inércia: ela sai do dash ainda rápida e a gravidade retoma
	# daí — sem esse resto o movimento trava no ar.
	player.velocity = _dash_direcao * DASH_VELOCIDADE * DASH_FIM_FATOR
	player.maior_velocidade_queda = 0.0

	_jato.set_deferred("monitoring", false)
	_jato_particulas.emitting = false

	if _sprite:
		_sprite.play()
		_soltar_esticada()


## Devolve o dash em pleno ar (válvulas de purga). Retorna true se recarregou.
func resetar_dash() -> bool:
	if not Progresso.tem_habilidade("mochila") or _dash_disponivel:
		return false
	_recarregar_dash()
	return true


func _recarregar_dash() -> void:
	if _dash_disponivel:
		return
	_dash_disponivel = true


## Esticada no eixo do dash (squash & stretch).
func _esticar_sprite(dir: Vector2) -> void:
	if _tween_escala and _tween_escala.is_valid():
		_tween_escala.kill()
	var fator := Vector2(1.15, 0.95)
	if dir.y == 0.0:
		fator = Vector2(1.3, 0.75)
	elif dir.x == 0.0:
		fator = Vector2(0.75, 1.3)
	_sprite.scale = _escala_base * fator


func _soltar_esticada() -> void:
	if _tween_escala and _tween_escala.is_valid():
		_tween_escala.kill()
	_tween_escala = create_tween()
	_tween_escala.tween_property(_sprite, "scale", _escala_base, 0.25) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Cópia congelada do frame atual, que fica pra trás e desbota — o rastro é o
## que deixa o caminho do dash legível mesmo durando 3 piscadas de tela.
func _soltar_fantasma() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var anim := _sprite.animation
	if not _sprite.sprite_frames.has_animation(anim):
		return
	var textura := _sprite.sprite_frames.get_frame_texture(anim, _sprite.frame)
	if textura == null:
		return
	var pai := player.get_parent()
	if pai == null:
		return

	var fantasma := Sprite2D.new()
	fantasma.texture = textura
	fantasma.centered = _sprite.centered
	fantasma.offset = _sprite.offset
	fantasma.flip_h = _sprite.flip_h
	fantasma.flip_v = _sprite.flip_v
	fantasma.z_index = player.z_index - 1
	fantasma.modulate = Color(0.65, 0.85, 1.0, 0.6)
	pai.add_child(fantasma)
	fantasma.global_transform = _sprite.global_transform

	var tween := fantasma.create_tween()
	tween.set_parallel(true)
	tween.tween_property(fantasma, "modulate:a", 0.0, DASH_FANTASMA_VIDA)
	tween.tween_property(fantasma, "scale", fantasma.scale * 0.88, DASH_FANTASMA_VIDA)
	tween.chain().tween_callback(fantasma.queue_free)


## A cor gelada marca o dash EM CURSO: entra de uma vez no arranco e escoa de
## volta ao normal assim que ele acaba, sem depender de pisar no chão.
## Só o RGB é tocado — o alfa é do piscado de dano do player.
func _atualizar_cor_dash(delta: float) -> void:
	if _sprite == null or not Progresso.tem_habilidade("mochila"):
		return

	var atual := _sprite.modulate
	if _dash_restante > 0.0:
		_sprite.modulate = Color(COR_DASH.r, COR_DASH.g, COR_DASH.b, atual.a)
		return

	# Lerp nunca chega em 1.0 sozinho: perto o bastante, crava o branco e para
	# de escrever no modulate a cada frame.
	if atual.r > 0.995 and atual.g > 0.995 and atual.b > 0.995:
		if atual.r != 1.0 or atual.g != 1.0 or atual.b != 1.0:
			_sprite.modulate = Color(1.0, 1.0, 1.0, atual.a)
		return

	var passo := clampf(delta * 24.0, 0.0, 1.0)
	_sprite.modulate = Color(
		lerpf(atual.r, 1.0, passo),
		lerpf(atual.g, 1.0, passo),
		lerpf(atual.b, 1.0, passo),
		atual.a
	)


# --- CONGELAMENTO DE IMPACTO (hitstop) ---
#
# Para o jogo inteiro por alguns frames no instante do dash. Com time_scale em
# 0 nenhum passo de física roda, então a contagem é feita em tempo real dentro
# do _process (que continua sendo chamado).

## Congelamento de impacto para quem não é o dash: o bumerangue chama isto ao
## ativar um alvo. A trava lá dentro já cuida de dois pedidos ao mesmo tempo
## (varrer três alvos num arremesso não congela o jogo três vezes).
func congelar_impacto(segundos: float) -> void:
	_congelar(segundos)


func _congelar(segundos: float) -> void:
	if segundos <= 0.0 or _congelado_ate_ms > 0:
		return
	_escala_tempo_anterior = Engine.time_scale
	_congelado_ate_ms = Time.get_ticks_msec() + int(segundos * 1000.0)
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 0.0


func _descongelar() -> void:
	if _congelado_ate_ms == 0:
		return
	_congelado_ate_ms = 0
	Engine.time_scale = _escala_tempo_anterior
	process_mode = Node.PROCESS_MODE_INHERIT


func _process(_delta: float) -> void:
	if _congelado_ate_ms > 0 and Time.get_ticks_msec() >= _congelado_ate_ms:
		_descongelar()


func _exit_tree() -> void:
	# Trocar de cena no meio do congelamento não pode deixar o jogo parado.
	_descongelar()


# --- SINALIZADOR --------------------------------------------------------

func _atualizar_sinalizador(delta: float) -> void:
	var tem := Progresso.tem_habilidade("sinalizador")
	var aceso := tem and Progresso.sinalizador_aceso and Progresso.carga_sinalizador > 0.0

	if aceso:
		Progresso.carga_sinalizador = maxf(Progresso.carga_sinalizador - DRENO_SINALIZADOR * delta, 0.0)

	if _luz:
		_luz.enabled = aceso
		# A luz míngua junto com a carga — dosar bem a recarga rende luz
		# mais duradoura (proporção como micro-mecânica).
		var forca := 0.35 + 0.65 * Progresso.carga_sinalizador
		_luz.texture_scale = 2.6 * forca
		_luz.energy = 1.4 * forca

	if _barra_fundo:
		_barra_fundo.visible = tem
		_barra_carga.visible = tem
		_barra_carga.size.x = 40.0 * Progresso.carga_sinalizador
		var carga := Progresso.carga_sinalizador
		_barra_carga.color = Color(0.7, 0.95, 0.5) if carga > 0.3 else Color(0.95, 0.5, 0.3)


func _on_jato_area_entered(area: Area2D) -> void:
	if area.is_in_group("chama") and area.has_method("apagar"):
		area.apagar()
