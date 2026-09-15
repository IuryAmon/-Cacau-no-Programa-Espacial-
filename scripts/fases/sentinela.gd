class_name Sentinela
extends CharacterBody2D

# --- SENTINELA DO BLECAUTE ---
#
# O monstro do subsolo: ANDA no chão (nada de voar), espreita parado no
# escuro e só começa a perseguir quando a personagem entra no raio dele.
# Qualquer fonte de luz do grupo "fonte_de_luz" (hoje, a Lanterna) que o
# ilumine congela ele NO MESMO FRAME — velocity zerada, sem inércia.
#
# Máquina de estados:
#   PERSEGUINDO -> CONGELADO   no frame em que a luz bate (imediato, legível)
#   CONGELADO   -> PERSEGUINDO após "delay_retomada" contínuo no escuro
#                              (o delay evita tremulação com o feixe raspando)
#   ATORDOADO   (opcional)     via atordoar(); sai sozinho para PERSEGUINDO
#
# Dentro de PERSEGUINDO existem dois momentos, e a diferença é só o raio:
# fora de "raio_perseguicao" ele ESPREITA parado; dentro, anda na direção da
# personagem em velocidade constante. Com vários em cena, cada um decide
# sozinho: só os DENTRO do cone congelam — esse é o dilema central da fase.
#
# Física: camada 0 / máscara 1 — pisa no chão e esbarra nas paredes do
# TileMap, mas não bloqueia o player nem faz sombra na luz (fantasma sólido
# só para o cenário). O dano é por DISTÂNCIA (distancia_contato), não por
# colisão física.
#
# TODO: patrulha simples (andar e voltar num trecho) se o espreitar parado
# deixar os corredores sem vida no playtest.

signal congelou
signal descongelou
signal tocou_player

enum Estado { PERSEGUINDO, CONGELADO, ATORDOADO }

const CENA := "res://scenes/fases/componentes/sentinela.tscn"
const TAMANHO := Vector2(44, 56)
const COR_CORPO := Color(0.30, 0.22, 0.42)
const COR_OLHOS := Color(0.98, 0.92, 0.9)
## Tinta do congelamento: aplicada NUM frame, sem tween — a leitura do
## "parou" tem que ser instantânea.
const COR_CONGELADO := Color(0.55, 0.78, 1.0)

# --- AJUSTE NO PLAYTEST ---
## px/s da perseguição. Player anda a 350: a Sentinela ameaça por acúmulo
## (várias acordadas ao mesmo tempo), não por corrida.
@export var velocidade: float = 120.0
## Raio que acorda a perseguição. MAIOR que o alcance da lanterna (320) de
## propósito: dá para ser notado por quem você ainda não consegue congelar.
@export var raio_perseguicao: float = 420.0
## Segundos CONTÍNUOS no escuro antes de voltar a andar (anti-tremulação
## quando o feixe passa raspando). Padrão do plano: 0.15.
@export var delay_retomada: float = 0.15
@export var dano_contato: int = 1
## Distância centro-a-centro que conta como toque (a origem do player fica
## nos pés e a da Sentinela no centro do corpo, ~28 px acima do chão).
@export var distancia_contato: float = 60.0

var estado: Estado = Estado.PERSEGUINDO

var _gravidade: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _tempo_no_escuro: float = 0.0
var _atordoado_restante: float = 0.0
var _cooldown_contato: float = 0.0
var _fase_gingado: float = randf() * TAU

var _player: CharacterBody2D = null
var _visual: Node2D = null
var _placeholder: Node2D = null
var _sprite: Sprite2D = null
var _anim: AnimationPlayer = null


static func criar(pai: Node, nome: String, pos: Vector2, config: Dictionary = {}) -> Sentinela:
	var sentinela: Sentinela = load(CENA).instantiate()
	sentinela.name = nome
	sentinela.position = pos
	for chave in config:
		sentinela.set(chave, config[chave])
	Blockout.adicionar(pai, sentinela)
	return sentinela


func _ready() -> void:
	add_to_group("sentinela")
	z_index = 2
	collision_layer = 0
	collision_mask = 1

	Blockout.forma_ret(self, TAMANHO)

	# --- VISUAL PLACEHOLDER (contrato de arte do Blockout) ---
	# Tudo que representa o corpo mora em "Visual": o modulate do congelamento
	# e o encolher do AnimationPlayer pegam placeholder E arte futura juntos.
	_visual = Node2D.new()
	_visual.name = "Visual"
	add_child(_visual)

	_placeholder = Node2D.new()
	_placeholder.name = "Placeholder"
	_visual.add_child(_placeholder)
	Blockout.visual_ret(_placeholder, TAMANHO, COR_CORPO)
	Blockout.visual_ret(_placeholder, Vector2(8, 11), COR_OLHOS, Vector2(-10, -8))
	Blockout.visual_ret(_placeholder, Vector2(8, 11), COR_OLHOS, Vector2(10, -8))

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_visual.add_child(_sprite)
	Blockout.aplicar_arte(_sprite, _placeholder)

	# Brasa dos olhos: um brilho fraco para a Sentinela ser visível vindo no
	# escuro total — sem isso o blecaute esconde a ameaça em vez de encená-la.
	var brasa := Blockout.luz_radial(Color(1.0, 0.36, 0.30), 0.4, 0.65)
	brasa.name = "BrasaOlhos"
	brasa.position = Vector2(0, -8)
	add_child(brasa)

	_montar_animacoes()


func _physics_process(delta: float) -> void:
	_cooldown_contato = maxf(_cooldown_contato - delta, 0.0)

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
		if _player is PhysicsBody2D:
			# collision_layer = 0 (acima) já garante que o PLAYER nunca vê a
			# Sentinela — mas o inverso não: o move_and_slide() da própria
			# Sentinela precisa continuar vendo PAREDES, e no projeto inteiro
			# não existe uma camada separada para "chão" vs "player" (os dois
			# usam a camada 1 padrão), então sem isto o corpo do player fazia
			# a Sentinela ser EMPURRADA para o lado no recuo automático de
			# colisão do próprio move_and_slide dela — visível sobretudo no
			# dash, mas acontecia em qualquer encontrão. Exceção pontual entre
			# os dois corpos: nenhum vê o outro, e ambos continuam vendo
			# parede. Sempre vale, dash ou não — o dash só cuida do dano
			# (esta_invencivel_dash em player.gd).
			add_collision_exception_with(_player)

	# Tela de puzzle/diálogo aberta: a caçada espera junto — não é justo
	# apanhar (nem descongelar) enquanto a jogadora lê.
	if Interacao.ocupada():
		velocity = Vector2.ZERO
		return

	var iluminado := esta_iluminado()

	match estado:
		Estado.PERSEGUINDO:
			if iluminado:
				# Congela ANTES de mover: zero deslocamento no frame da luz.
				_congelar()
				return
			if not is_on_floor():
				velocity.y += _gravidade * delta
			# Fora do raio ele ESPREITA parado; dentro, anda na direção dela.
			if global_position.distance_to(_player.global_position) <= raio_perseguicao:
				velocity.x = signf(_player.global_position.x - global_position.x) * velocidade
			else:
				velocity.x = 0.0
			move_and_slide()
			_atualizar_gingado()
			_tentar_contato()

		Estado.CONGELADO:
			# Estátua TOTAL: velocity zerada e nada de move_and_slide — nem a
			# gravidade mexe nela. Pega no ar descendo um degrau, fica
			# suspensa: isso lê como o poder do feixe, não como bug (e ao
			# descongelar a gravidade a devolve ao chão em PERSEGUINDO).
			velocity = Vector2.ZERO
			if iluminado:
				_tempo_no_escuro = 0.0
			else:
				_tempo_no_escuro += delta
				if _tempo_no_escuro >= delay_retomada:
					_descongelar()

		Estado.ATORDOADO:
			velocity = Vector2.ZERO
			_atordoado_restante -= delta
			if _atordoado_restante <= 0.0:
				estado = Estado.PERSEGUINDO


## Alguma fonte de luz da cena me ilumina agora? (grupo "fonte_de_luz" —
## a Sentinela não conhece a Lanterna, só o contrato is_body_lit.)
func esta_iluminado() -> bool:
	for fonte in get_tree().get_nodes_in_group("fonte_de_luz"):
		if fonte.has_method("is_body_lit") and fonte.is_body_lit(self):
			return true
	return false


## Estado opcional para ferramentas futuras (flash forte, bumerangue?):
## fica parado "duracao" segundos e volta a perseguir sozinho.
func atordoar(duracao: float = 1.2) -> void:
	estado = Estado.ATORDOADO
	_atordoado_restante = duracao
	velocity = Vector2.ZERO
	_anim.play("congelar")


# --- TRANSIÇÕES ---

func _congelar() -> void:
	estado = Estado.CONGELADO
	_tempo_no_escuro = 0.0
	velocity = Vector2.ZERO
	_visual.rotation = 0.0
	# Tinta instantânea + encolhida seca: legível em um frame.
	_visual.modulate = COR_CONGELADO
	_anim.play("congelar")
	# TODO: quando a arte chegar com AnimatedSprite2D, pausar a animação de
	# andar aqui (sprite.pause()) e retomar no _descongelar().
	congelou.emit()


func _descongelar() -> void:
	estado = Estado.PERSEGUINDO
	_visual.modulate = Color.WHITE
	_anim.play("descongelar")
	descongelou.emit()


# --- CONTATO (por distância, não por colisão física) ---

func _tentar_contato() -> void:
	# Congelada não machuca: a lanterna É a defesa. TODO: se o playtest pedir
	# perigo constante (tocar Boo parado machuca no Mario), mover esta chamada
	# para fora do match e tirar o retorno no CONGELADO.
	if _cooldown_contato > 0.0:
		return
	# Player com controle travado (cutscene, knockback de outro dano) não
	# leva hit — a invencibilidade dele já cobre parte disso, esta é a rede
	# de segurança para as travas que não piscam.
	if "pode_se_mover" in _player and not _player.pode_se_mover:
		return
	if global_position.distance_to(_player.global_position) > distancia_contato:
		return
	_cooldown_contato = 0.9
	tocou_player.emit()
	if _player.has_method("take_damage"):
		var lado := signf(_player.global_position.x - global_position.x)
		_player.take_damage(dano_contato, Vector2(0.6 * (lado if lado != 0.0 else 1.0), 0))


# --- VISUAL DO ANDAR ---

## Gingado de caminhada do placeholder: o corpo balança só ENQUANTO anda —
## parar o gingado é parte da leitura do espreitar e do congelamento.
func _atualizar_gingado() -> void:
	if absf(velocity.x) > 1.0:
		_visual.rotation = sin(Time.get_ticks_msec() * 0.02 + _fase_gingado) * 0.07
	else:
		_visual.rotation = 0.0


# --- ANIMAÇÕES DE TRANSIÇÃO (placeholder até a arte chegar) ---

## O leve "encolher" pedido no plano: um squash seco ao congelar e um
## respiro elástico ao soltar, tocando só a escala do nó Visual.
func _montar_animacoes() -> void:
	_anim = AnimationPlayer.new()
	_anim.name = "Anim"
	add_child(_anim)

	var lib := AnimationLibrary.new()

	var congelar := Animation.new()
	congelar.length = 0.14
	var trilha := congelar.add_track(Animation.TYPE_VALUE)
	congelar.track_set_path(trilha, NodePath("Visual:scale"))
	congelar.track_insert_key(trilha, 0.0, Vector2.ONE)
	congelar.track_insert_key(trilha, 0.05, Vector2(0.80, 0.74))
	congelar.track_insert_key(trilha, 0.14, Vector2(0.90, 0.86))
	lib.add_animation("congelar", congelar)

	var descongelar := Animation.new()
	descongelar.length = 0.22
	trilha = descongelar.add_track(Animation.TYPE_VALUE)
	descongelar.track_set_path(trilha, NodePath("Visual:scale"))
	descongelar.track_insert_key(trilha, 0.0, Vector2(0.90, 0.86))
	descongelar.track_insert_key(trilha, 0.12, Vector2(1.08, 1.10))
	descongelar.track_insert_key(trilha, 0.22, Vector2.ONE)
	lib.add_animation("descongelar", descongelar)

	_anim.add_animation_library("", lib)


## Nome legível do estado (painel de debug da cena de teste).
func nome_do_estado() -> String:
	match estado:
		Estado.PERSEGUINDO: return "PERSEGUINDO"
		Estado.CONGELADO: return "CONGELADO"
		Estado.ATORDOADO: return "ATORDOADO"
	return "?"
