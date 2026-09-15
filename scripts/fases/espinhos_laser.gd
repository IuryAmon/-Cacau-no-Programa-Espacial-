@tool
class_name EspinhosLaser
extends Area2D

# --- ESPINHOS DE LASER (ARMADILHA DE CHÃO) ---
#
# Uma fileira de espinhos que sobe do piso e MATA na hora quem encosta. Na Oficina
# de Carbono ela é alimentada pela CAIXA ELÉTRICA: acertar a caixa com o
# bumerangue corta a corrente, os espinhos recolhem (animação "desativando") e
# a passagem fica livre.
#
# COMO EDITAR NO EDITOR (tudo é nó ou export — nada é criado escondido):
#   Visual      AnimatedSprite2D com as três animações. Troque os PNGs, a
#               velocidade (FPS) e a escala aqui — o resto se ajusta sozinho:
#                   "ativando"     espinhos subindo    (laser_spikes_activate)
#                   "armado"       espinhos fora, em loop  (laser_spikes_idle)
#                   "desativando"  espinhos recolhendo (laser_spikes_deactivate)
#   Segmentos   onde nascem as cópias do Visual quando "segmentos" > 1. Não
#               mexa à mão: é reconstruído a cada mudança.
#   Colisao     o hitbox. NÓ COMUM — arraste as alças ou mude Shape/Position
#               no Inspector, do jeito que preferir. O script nunca mexe nele;
#               fica exatamente do jeito que você deixar em CADA lugar onde os
#               espinhos foram colocados (a forma é "resource_local_to_scene",
#               então cada instância guarda o próprio tamanho).
#   SomLaser    "laserpulsando.mp3" em loop: entra com a subida, toca o tempo
#               todo com a fileira de pé e acompanha o recolhimento inteiro,
#               sumindo só no finalzinho. Volume, "attenuation" e
#               "max_distance" são do próprio nó.
#   AtrasoDesligar  relógio da espera entre o acerto na caixa e o recolhimento
#               (o tempo em si é o export "atraso_desligar").
#
# ONDE FICA A ORIGEM DO NÓ: na LINHA DO CHÃO. Encoste o nó no topo do tile e
# os espinhos nascem em cima dele, sem precisar mirar o meio do sprite.

const CENA := "res://scenes/fases/componentes/espinhos_laser.tscn"

## Largura, em pixels de ARTE, de um quadro da fileira.
const LARGURA_QUADRO := 32.0

const ANIM_ATIVANDO := &"ativando"
const ANIM_ARMADO := &"armado"
const ANIM_DESATIVANDO := &"desativando"

## Fade final do zumbido: ele toca inteiro durante o recolhimento e some nesses
## últimos instantes, terminando junto com o último quadro da animação.
const FADE_SOM := 0.3

## O golpe da fileira quando "letal" está ligado: qualquer número acima da vida
## cheia zera a barra no mesmo toque, sem depender de quantos corações o
## jogador tem naquele momento.
const GOLPE_LETAL := 9999

@export_group("Fileira")
## Quantos módulos de espinho, lado a lado. A fileira cresce para os dois
## lados, mantendo o nó no centro.
@export_range(1, 40, 1) var segmentos: int = 3:
	set(valor):
		segmentos = maxi(1, valor)
		if is_inside_tree():
			_montar()

@export_group("Dano")
## Ligado (padrão): encostar na fileira MATA na hora, não importa quanta vida
## reste. Desligado: os espinhos viram uma armadilha comum, que tira "dano" a
## cada "intervalo_dano".
@export var letal: bool = true
@export var dano: int = 1
## Espera mínima entre dois danos de quem fica parado em cima. Só conta com
## "letal" desligado — com ele ligado não existe segundo toque.
@export_range(0.1, 5.0, 0.05) var intervalo_dano: float = 0.8

@export_group("Corrente")
## A caixa elétrica (ou qualquer AlvoBumerangue) que alimenta a armadilha.
## Deixe vazio para uns espinhos que nunca desligam.
@export var caixa_eletrica: NodePath
## Ligado (padrão): assim que a caixa é acertada, os espinhos morrem de vez.
## Desligado: eles voltam a subir quando a janela do alvo expira — vira uma
## passagem cronometrada.
@export var desligar_para_sempre: bool = true
## Respiro entre o acerto na caixa e o recolhimento. Nesse tempo os espinhos
## continuam de pé e MACHUCANDO — dá para ver o baque e a faísca da caixa antes
## de a fileira reagir, e só depois a animação "desativando" roda inteira.
## Padrão: 0 — recolhe no mesmo frame do acerto.
@export_range(0.0, 3.0, 0.05) var atraso_desligar: float = 0.0
## Estado inicial. Desligado = a fileira já nasce recolhida.
@export var armado_no_inicio: bool = true
## Aviso que sobe na tela quando a corrente cai. Vazio = nenhum aviso.
@export var aviso: String = ""

## True enquanto os espinhos estão fora E machucando. Vira FALSO já no começo
## do recolhimento: assim que a corrente cai o jogador não leva mais dano,
## mesmo com as pontas ainda descendo.
var perigoso: bool = false

## Espinhos guardados: nem fora, nem subindo. Começa true porque a fileira
## nasce recolhida e só sobe no _ready(). É o que impede um segundo acerto na
## caixa de repetir o recolhimento de quem já está recolhido.
var _recolhido: bool = true
var _travado: bool = false
var _cooldown: float = 0.0
var _corpos: Array[Node2D] = []
## Caixas empurráveis dentro da fileira: enquanto os espinhos estão fora
## (`perigoso`), elas ficam barradas na borda e não atravessam.
var _caixas: Array[Node2D] = []
var _pecas: Array[AnimatedSprite2D] = []
## Volume que o nó SomLaser tem no editor. O fade mexe no volume_db, então o
## valor original fica guardado aqui para o som voltar sempre no mesmo nível.
var _volume_som: float = 0.0
var _fade: Tween = null

@onready var _visual: AnimatedSprite2D = get_node_or_null("Visual")
@onready var _extras: Node2D = get_node_or_null("Segmentos")
@onready var _som: AudioStreamPlayer2D = get_node_or_null("SomLaser")
@onready var _atraso: Timer = get_node_or_null("AtrasoDesligar")


static func criar(pai: Node, nome: String, pos: Vector2, config: Dictionary = {}) -> EspinhosLaser:
	var espinhos: EspinhosLaser = load(CENA).instantiate()
	espinhos.name = nome
	espinhos.position = pos
	for chave in config:
		espinhos.set(chave, config[chave])
	Blockout.adicionar(pai, espinhos)
	return espinhos


func _ready() -> void:
	_montar()
	if Engine.is_editor_hint():
		return

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _visual and not _visual.animation_finished.is_connected(_ao_fim_da_animacao):
		_visual.animation_finished.connect(_ao_fim_da_animacao)
	if _som:
		_volume_som = _som.volume_db
	if _atraso and not _atraso.timeout.is_connected(_ao_fim_do_atraso):
		_atraso.timeout.connect(_ao_fim_do_atraso)

	_ligar_na_caixa()

	# Estado inicial sem animação: quem entra na sala já vê a armadilha do
	# jeito que ela está. As animações são para as MUDANÇAS.
	if armado_no_inicio and not _travado:
		armar(false)
	else:
		_pose_recolhida()


# --- MONTAGEM DA FILEIRA ---

## Reconstrói as cópias do Visual (a ARTE). A colisão é assunto seu: o nó
## Colisao não é tocado aqui — arraste as alças dele à vontade, em cada lugar
## onde os espinhos foram colocados, e o tamanho fica exatamente do jeito que
## você deixar.
func _montar() -> void:
	if _visual == null or _extras == null:
		return

	for antigo in _extras.get_children():
		antigo.free()

	var largura_modulo: float = LARGURA_QUADRO * absf(_visual.scale.x)
	var esquerda: float = -(segmentos - 1) * largura_modulo * 0.5

	_visual.position.x = esquerda
	_pecas = [_visual]
	for i in range(1, segmentos):
		var copia: AnimatedSprite2D = _visual.duplicate()
		copia.name = "Segmento%d" % i
		copia.position.x = esquerda + i * largura_modulo
		# Sem owner de propósito: as cópias são geradas, não salvas no .tscn.
		_extras.add_child(copia)
		_pecas.append(copia)


# --- LIGAÇÃO COM A CAIXA ELÉTRICA ---

func _ligar_na_caixa() -> void:
	if caixa_eletrica.is_empty():
		return
	var caixa: Node = get_node_or_null(caixa_eletrica)
	if caixa == null:
		push_warning("%s: não achei a caixa elétrica em '%s'." % [name, caixa_eletrica])
		return
	if not caixa.has_signal("mudou"):
		push_warning("%s: '%s' não é alvo de bumerangue (falta o sinal 'mudou')." % [name, caixa.name])
		return

	caixa.mudou.connect(_ao_mudar_caixa)

	# A caixa pode já estar arrebentada quando os espinhos nascem (alvo com
	# "persistir"). Nesse caso a corrente nunca chega: nascem recolhidos.
	var ja_acertada: bool = ("quebrada" in caixa and caixa.quebrada) or ("ativo" in caixa and caixa.ativo)
	if ja_acertada:
		_travado = desligar_para_sempre
		armado_no_inicio = false


func _ao_mudar_caixa(ligada: bool) -> void:
	if ligada:
		_agendar_desarme()
	elif not desligar_para_sempre:
		armar()


## O acerto na caixa não recolhe a fileira no mesmo frame: espera
## `atraso_desligar` com os espinhos ainda de pé (e ainda machucando) e só
## então começa o recolhimento, com a animação inteira.
func _agendar_desarme() -> void:
	if _recolhido or _travado:
		return
	if atraso_desligar <= 0.0 or _atraso == null:
		desarmar()
		return
	if not _atraso.is_stopped():
		return  # já está na contagem: um segundo acerto não reinicia a espera
	_atraso.start(atraso_desligar)


func _ao_fim_do_atraso() -> void:
	desarmar()


# --- LIGAR E DESLIGAR ---

## Sobe os espinhos. `com_animacao = false` monta a pose final direto.
func armar(com_animacao: bool = true) -> void:
	if _travado:
		return
	# A corrente voltou antes de a fileira reagir ao acerto: cancela o
	# recolhimento que estava agendado e deixa tudo como já estava.
	if _atraso and not _atraso.is_stopped():
		_atraso.stop()
		return
	if not _recolhido:
		return
	_recolhido = false
	_ligar_som()
	if com_animacao and _tem_animacao(ANIM_ATIVANDO):
		# O dano só entra quando as pontas terminam de subir.
		_tocar(ANIM_ATIVANDO)
		return
	perigoso = true
	_tocar(ANIM_ARMADO)


## Recolhe os espinhos. O dano para JÁ, no primeiro quadro da animação.
func desarmar(com_animacao: bool = true) -> void:
	if _recolhido:
		return
	_recolhido = true
	perigoso = false
	_corpos.clear()
	if _atraso:
		_atraso.stop()
	if desligar_para_sempre:
		_travado = true

	if com_animacao and _tem_animacao(ANIM_DESATIVANDO):
		_tocar(ANIM_DESATIVANDO)
		# O zumbido acompanha a descida INTEIRA e só se apaga no finalzinho: o
		# fade é calculado para terminar junto com o último quadro.
		_desligar_som(_duracao(ANIM_DESATIVANDO) - FADE_SOM)
		if aviso != "" and is_inside_tree():
			Blockout.aviso_flutuante(get_parent(), global_position + Vector2(0, -60),
				aviso, Color(0.5, 1.0, 0.6))
		return
	_desligar_som()
	_pose_recolhida()


func _ao_fim_da_animacao() -> void:
	if _visual == null:
		return
	match _visual.animation:
		ANIM_ATIVANDO:
			perigoso = true
			_tocar(ANIM_ARMADO)
		ANIM_DESATIVANDO:
			_pose_recolhida()


## Trava no último quadro do recolhimento: a base, sem ponta nenhuma.
func _pose_recolhida() -> void:
	if not _tem_animacao(ANIM_DESATIVANDO):
		return
	var ultimo: int = _visual.sprite_frames.get_frame_count(ANIM_DESATIVANDO) - 1
	for peca in _pecas:
		peca.stop()
		peca.animation = ANIM_DESATIVANDO
		peca.frame = ultimo


## Todas as peças da fileira andam sempre juntas, no mesmo quadro.
func _tocar(nome: StringName) -> void:
	if not _tem_animacao(nome):
		return
	for peca in _pecas:
		peca.animation = nome
		peca.frame = 0
		peca.play(nome)


func _tem_animacao(nome: StringName) -> bool:
	return _visual != null and _visual.sprite_frames != null and _visual.sprite_frames.has_animation(nome)


# --- SOM DO LASER ---

## O zumbido entra junto com a subida dos espinhos e fica em loop enquanto a
## fileira estiver de pé — inclusive durante a espera do `atraso_desligar`.
func _ligar_som() -> void:
	if _som == null or _som.stream == null or Engine.is_editor_hint():
		return
	if _fade and _fade.is_valid():
		_fade.kill()
		_fade = null
	_som.volume_db = _volume_som
	if _som.playing:
		return
	# Cada fileira começa em um ponto sorteado do arquivo: com várias na mesma
	# sala, os zumbidos não caem todos no mesmo pico.
	_som.play(randf() * _som.stream.get_length())


## Apaga o zumbido. `espera` segura o volume cheio antes do fade — é assim que
## o som acompanha a animação de recolhimento até o fim e só some no finalzinho.
func _desligar_som(espera: float = 0.0) -> void:
	if _som == null or not _som.playing:
		return
	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	if espera > 0.0:
		_fade.tween_interval(espera)
	_fade.tween_property(_som, "volume_db", _volume_som - 30.0, FADE_SOM)
	_fade.tween_callback(_som.stop)


## Quanto tempo uma animação do Visual leva, já contando o FPS e o
## "speed_scale" que você deixou no nó.
func _duracao(nome: StringName) -> float:
	if not _tem_animacao(nome):
		return 0.0
	var quadros: SpriteFrames = _visual.sprite_frames
	var velocidade: float = quadros.get_animation_speed(nome) * absf(_visual.speed_scale)
	if velocidade <= 0.0:
		return 0.0
	var total: float = 0.0
	for i in quadros.get_frame_count(nome):
		total += quadros.get_frame_duration(nome, i)
	return total / velocidade


# --- DANO ---

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_barrar_caixas()

	_cooldown -= delta
	if not perigoso or _cooldown > 0.0 or _corpos.is_empty():
		return

	for corpo in _corpos:
		if not is_instance_valid(corpo):
			continue
		# Empurrão para fora da fileira, pelo lado mais perto.
		var lado: float = signf(corpo.global_position.x - global_position.x)
		if is_zero_approx(lado):
			lado = -1.0
		if letal:
			_avisar_que_e_corte(corpo)
		corpo.take_damage(GOLPE_LETAL if letal else dano, Vector2(lado, 0))
		_ao_ferir(corpo)
		_cooldown = intervalo_dano


## Gancho para quem herda: chamado no frame em que a armadilha fere alguém.
## Nos espinhos não faz nada — quem usa é a SerraEletrica, para o barulho da
## lâmina pegando o jogador.
func _ao_ferir(_corpo: Node2D) -> void:
	pass


## Morte de lâmina: quem morre aqui não some com a tela, é PICADO no lugar
## (ver scripts/fx/morte_despedacada.gd). A vítima só precisa saber disso ANTES
## de levar o golpe, porque o take_damage() já dispara a morte inteira — por
## isso o aviso sai um passo antes, e não pelo gancho _ao_ferir().
## Quem não entender o recado (uma caixa, um inimigo qualquer) morre do jeito
## normal, sem erro nenhum.
func _avisar_que_e_corte(corpo: Node2D) -> void:
	if not corpo.has_method("marcar_morte_de_corte"):
		return
	var col: CollisionShape2D = get_node_or_null("Colisao")
	var lamina: Vector2 = col.global_position if col else global_position
	# O talho não acontece no centro do disco, e sim onde os dois se encostam:
	# o ponto é puxado da lâmina em direção à vítima.
	corpo.marcar_morte_de_corte(lamina + (corpo.global_position - lamina).limit_length(26.0))


func _on_body_entered(corpo: Node2D) -> void:
	if corpo.has_method("take_damage") and not _corpos.has(corpo):
		_corpos.append(corpo)
	if corpo.is_in_group("empurravel") and not _caixas.has(corpo):
		_caixas.append(corpo)


func _on_body_exited(corpo: Node2D) -> void:
	_corpos.erase(corpo)
	_caixas.erase(corpo)


## Impede que uma caixa empurrável atravesse a fileira enquanto os espinhos
## estão fora. Assim que a corrente cai (`perigoso` vira falso) a passagem
## libera também para a caixa.
func _barrar_caixas() -> void:
	if not perigoso or _caixas.is_empty():
		return

	var col: CollisionShape2D = get_node_or_null("Colisao")
	if col == null or not (col.shape is RectangleShape2D):
		return

	var meia_fileira: float = (col.shape as RectangleShape2D).size.x * 0.5 * absf(scale.x)
	var centro_x: float = global_position.x + col.position.x * scale.x

	for caixa in _caixas:
		if not is_instance_valid(caixa):
			continue

		var meia_caixa: float = 40.0
		var cs: CollisionShape2D = caixa.get_node_or_null("CollisionShape2D")
		if cs and cs.shape is RectangleShape2D:
			meia_caixa = (cs.shape as RectangleShape2D).size.x * 0.5 * absf(caixa.scale.x)

		var lado: float = signf(caixa.global_position.x - centro_x)
		if is_zero_approx(lado):
			lado = -1.0

		var limite: float = centro_x + lado * (meia_fileira + meia_caixa)
		if (lado < 0.0 and caixa.global_position.x > limite) \
		or (lado > 0.0 and caixa.global_position.x < limite):
			caixa.global_position.x = limite
			if (lado < 0.0 and caixa.velocity.x > 0.0) \
			or (lado > 0.0 and caixa.velocity.x < 0.0):
				caixa.velocity.x = 0.0
