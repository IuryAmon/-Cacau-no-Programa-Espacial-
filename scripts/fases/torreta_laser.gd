@tool
class_name TorretaLaser
extends Node2D

# --- TORRETA A LASER (ARMADILHA DE PAREDE) ---
#
# Fica grudada numa parede e VIGIA EM VOLTA: campo de visão de 360°, sem cone
# nenhum. Basta a personagem estar dentro do "alcance" com a linha de visão
# limpa. Uma parede, uma caixa empurrada para o lugar certo, qualquer corpo
# entre as duas — e a torreta perde o alvo na hora.
#
# A arte vem em DUAS PEÇAS, e a torreta é montada assim:
#   corpo_torreta.png       a base. Um quadro só, parafusado na parede: não
#                           gira atrás de ninguém nem anima, só acompanha o
#                           "angulo_repouso_graus" para saber de que parede a
#                           torreta sai.
#   cabeça_da_torreta.png   a cabeça. É ela que gira para mirar e é ela que
#                           carrega os 17 quadros da animação — inclusive o
#                           recuo, que já vem desenhado quadro a quadro. Por
#                           isso a cabeça afunda na base sozinha, sem ninguém
#                           mexer em posição no código.
# As duas peças foram recortadas do MESMO quadro de 32×32, então em repouso
# elas se encaixam exatamente como no desenho inteiro: a cabeça por cima da
# base, e o encaixe entre as duas é o pino em que a cabeça gira.
#
# Vendo a personagem, ela vira a cabeça para lá e toca a animação de disparo
# INTEIRA (17 quadros): os dez primeiros são a carga, no 11º o tiro sai e os
# últimos são o recuo. Sem alvo, ela trava no ÚLTIMO quadro — a pose de
# repouso, com o canhão fechado.
#
# O tiro nasce no quadro do clarão, e não num relógio à parte: mexer na
# velocidade da animação muda o timing do disparo junto, e o clarão do desenho
# nunca sai fora de hora.
#
# COMO EDITAR NO EDITOR (tudo é nó ou export — nada é criado escondido):
#   Base     a peça inteira encostada na parede. Só o "angulo_repouso_graus"
#            mexe nela, e ela leva corpo e cabeça juntos: 0° = parede à
#            esquerda, 180° = parede à direita, 90° = teto, -90° = chão. A
#            ORIGEM da torreta é o pé da base, o ponto que encosta na parede,
#            e o cano cresce para +X. O ângulo é aplicado ao vivo no editor.
#   Corpo    a base imóvel. Mudando a escala, ajuste o "position" dele junto:
#            ele vale meio quadro, e é o que mantém o pé da base em cima da
#            origem da torreta.
#   Canhao   o PINO em que a cabeça gira — por isso ele fica no encaixe, em
#            cima da base, e não lá atrás na parede. Arraste para acertar o
#            pino; cabeça e boca vão junto.
#   Visual   a arte da cabeça. O PNG está desenhado NA VERTICAL (cano para
#            cima), então o nó já vem com rotation = 90° para deitar a torreta
#            na horizontal. A posição dele é medida A PARTIR DO PINO: é o que
#            faz a cabeça pousar em cima da base na pose de repouso.
#   Boca     de onde a bala nasce. Arraste para a pontinha do cano.
#
#   O "flip_h" ligado no Corpo e no Visual é o espelho VERTICAL da torreta na
#   tela — as duas peças têm de virar juntas. Parece trocado, mas não é: com a
#   arte deitada 90°, o X do sprite é o Y da tela, então quem espelha em cima/
#   embaixo é o flip_H. O flip_v é que espelharia o cano de trás para frente.
#
#   SomTiro  o estalo do disparo. Volume e alcance são do próprio nó.
#
# --- QUANDO O BUMERANGUE ACERTA ---
#
# POR PADRÃO, NADA: as torretas são imortais ("quebravel" vem desligado) e o
# bumerangue atravessa. O resto desta seção só vale para uma torreta com
# "quebravel" ligado no Inspetor.
#
# Uma torreta quebrável não tem vida nem barra de dano: um acerto de
# bumerangue e ela ESTRAGA, de uma vez — a ferramenta da personagem DESARMA a
# armadilha, em vez de fugir dela.
#
# No frame do acerto:
#   * o ciclo de disparo morre onde estiver, mesmo no meio da carga: quem
#     acerta a torreta carregando CANCELA o tiro que já vinha — é o prêmio de
#     arremessar na hora certa;
#   * a cabeça leva um coice e volta à POSIÇÃO INICIAL, a mesma pose de
#     repouso de canhão fechado. Torreta parada, apontada para o nada: é isso
#     que diz "essa aí já era" sem precisar de arte nova;
#   * a carcaça escurece (tinta de queimado) e passa a soltar fumaça
#     contínua, com uma chispa de curto de vez em quando.
# Daí em diante ela não vê, não gira e não atira mais nada.
#
# NÓS DA AVARIA (todos opcionais — tirar um só apaga aquela camada):
#   AreaAlvo    o HITBOX do bumerangue: uma HitboxBumerangue no grupo
#               "alvo_bumerangue". Mora dentro da Base, então acompanha
#               sozinha a parede em que a torreta foi montada. Arraste a
#               forma para cobrir a arte.
#   Fumaca      a fumacinha constante depois do estrago.
#   Faiscas     a rajada única do baque.
#   Chispas     o curto que volta de tempos em tempos (relógio TempoChispa).
#   SomQuebra   o baque de metal do acerto.
#
#   Fumaça e faíscas moram dentro da Base para nascerem na cabeça, mas o
#   script zera a rotação GLOBAL delas: fumaça sobe para o CÉU, não para
#   "cima da torreta" — senão a torreta de teto fumaçaria para baixo.

## O tiro saiu. A direção é o rumo da bala, já normalizada.
signal disparou(direcao: Vector2)

## Estragada pelo bumerangue. Daqui para frente ela é enfeite fumegante — as
## portas e os puzzles que dependiam dela escutam por aqui.
signal avariou

const CENA := "res://scenes/fases/componentes/torreta_laser.tscn"

const ANIM_DISPARO := &"disparo"

## Coice da cabeça no baque (9°) e os tempos do tombo de volta ao repouso.
const COICE_AVARIA := PI / 20.0
const TEMPO_COICE := 0.07
const TEMPO_TOMBO := 0.55

@export_group("Vigia")
## Raio da vigia. Dentro dele, e só com a linha de visão limpa, a torreta vê a
## personagem venha ela de onde vier — o campo é de 360°.
@export_range(0.0, 2000.0, 8.0) var alcance: float = 520.0
## Camadas que CORTAM a visão. O projeto inteiro usa a camada 1, então paredes
## de TileMap e caixas empurráveis já contam como obstáculo.
@export_flags_2d_physics var mascara_visao: int = 1
## Desligada, ela fica parada na pose de repouso e não atira em ninguém.
@export var ativa: bool = true

@export_group("Mira")
## De que parede a torreta sai — gira a peça inteira, base e cabeça. 0° = cano
## para a direita (parede à esquerda), 180° = para a esquerda, 90° = para
## baixo (teto), -90° = para cima (chão).
@export_range(-180.0, 180.0, 1.0) var angulo_repouso_graus: float = 0.0:
	set(valor):
		angulo_repouso_graus = valor
		if Engine.is_editor_hint():
			_aplicar_repouso()
## Desligado, a cabeça nunca gira: continua vendo 360° em volta, mas só atira
## na direção de repouso. Serve para torreta de corredor, de tiro fixo.
@export var girar_para_mirar: bool = true
## Graus por segundo do giro. Vale 0 para mira instantânea.
@export_range(0.0, 1440.0, 10.0) var velocidade_giro: float = 420.0
## A origem da personagem fica nos PÉS. A torreta mira este tanto acima dela,
## na altura do peito — senão o tiro passa rente ao chão e a própria linha de
## visão bate no piso.
@export_range(0.0, 96.0, 1.0) var altura_do_alvo: float = 28.0

@export_group("Disparo")
@export var dano: int = 1
@export var velocidade_tiro: float = 760.0
## Quadro da animação em que a bala sai (0 = o primeiro). O padrão 10 é o 11º
## quadro, exatamente onde a arte solta o clarão.
@export_range(0, 16, 1) var quadro_do_tiro: int = 10
## Respiro entre o fim de uma animação e o começo da próxima.
@export_range(0.0, 8.0, 0.05) var intervalo: float = 0.55
## Multiplicador da animação de disparo, e portanto da CADÊNCIA: os 17 quadros
## a 14 fps levam 1,2 s por ciclo, e é esse ciclo (mais o "intervalo") que
## decide quantos tiros saem por segundo. Subir aqui encurta a carga junto —
## o aviso continua sendo os dez quadros antes do clarão, só que mais curto.
@export_range(0.25, 4.0, 0.05) var velocidade_animacao: float = 1.3:
	set(valor):
		velocidade_animacao = valor
		var visual: AnimatedSprite2D = get_node_or_null("Base/Canhao/Visual")
		if visual:
			visual.speed_scale = valor

@export_group("Avaria")
## Desligado (o padrão: as torretas são imortais), o bumerangue atravessa a
## torreta como se ela não estivesse ali — sem estrago, sem baque e sem o
## tranco de acerto. Ligue só numa torreta que deva ser desarmada.
@export var quebravel: bool = false
## Ligado, ela continua quebrada depois de morrer e recarregar a fase. Use nas
## que fazem parte de um puzzle: refazer o mesmo arremesso a cada morte vira
## pedágio, não desafio.
@export var persistir: bool = false
## Tinta da carcaça queimada. Vale só para a ARTE — fumaça e faísca não herdam.
@export var cor_avariada: Color = Color(0.62, 0.60, 0.58)
## Faixa (sorteada) entre uma chispa do curto e a próxima. Os dois campos
## iguais = intervalo fixo.
@export_range(0.2, 30.0, 0.1) var chispa_intervalo_min: float = 1.8
@export_range(0.2, 30.0, 0.1) var chispa_intervalo_max: float = 4.6

var _player: CharacterBody2D = null
var _espera: float = 0.0
## Este ciclo de animação ainda deve um tiro (vira falso no quadro do clarão).
var _disparo_pendente: bool = false
## Estragada pelo bumerangue. Só anda para frente: uma vez quebrada, só o
## consertar() volta atrás.
var quebrada: bool = false
var _tween_avaria: Tween = null

## A peça toda encostada na parede: não persegue ninguém, só carrega o ângulo
## de repouso. É o referencial contra o qual o giro da cabeça é medido.
@onready var _base: Node2D = get_node_or_null("Base")
## O pino em que a cabeça gira. Rotação 0 = cabeça pousada na base, do jeito
## que a arte foi desenhada; girar isto é mirar.
@onready var _canhao: Node2D = get_node_or_null("Base/Canhao")
@onready var _visual: AnimatedSprite2D = get_node_or_null("Base/Canhao/Visual")
@onready var _boca: Marker2D = get_node_or_null("Base/Canhao/Boca")
@onready var _som: AudioStreamPlayer2D = get_node_or_null("SomTiro")
@onready var _corpo: Sprite2D = get_node_or_null("Base/Corpo")
@onready var _hitbox: Area2D = get_node_or_null("Base/AreaAlvo")
@onready var _fumaca: CPUParticles2D = get_node_or_null("Base/Fumaca")
@onready var _faiscas: CPUParticles2D = get_node_or_null("Base/Faiscas")
@onready var _chispas: CPUParticles2D = get_node_or_null("Base/Chispas")
@onready var _som_quebra: AudioStreamPlayer2D = get_node_or_null("SomQuebra")
@onready var _tempo_chispa: Timer = get_node_or_null("TempoChispa")


static func criar(pai: Node, nome: String, pos: Vector2, config: Dictionary = {}) -> TorretaLaser:
	var torreta: TorretaLaser = load(CENA).instantiate()
	torreta.name = nome
	torreta.position = pos
	for chave in config:
		torreta.set(chave, config[chave])
	Blockout.adicionar(pai, torreta)
	return torreta


func _ready() -> void:
	_aplicar_repouso()
	# O setter de "velocidade_animacao" corre antes de os filhos existirem
	# quando o valor vem do próprio script; aqui é onde ele pega de fato.
	if _visual:
		_visual.speed_scale = velocidade_animacao
	_pose_de_repouso()
	if Engine.is_editor_hint():
		return
	_visual.frame_changed.connect(_ao_trocar_quadro)
	_visual.animation_finished.connect(_ao_fim_do_disparo)

	if _hitbox and _hitbox.has_signal("atingida"):
		_hitbox.atingida.connect(_ao_levar_bumerangue)
	if _hitbox and not quebravel:
		# Imortal: fora do grupo, o bumerangue nem enxerga a hitbox e passa
		# direto (senão ele ainda travava o mundo e tremia a câmera no acerto).
		_hitbox.remove_from_group(&"alvo_bumerangue")
	if _tempo_chispa:
		_tempo_chispa.timeout.connect(_chispar)

	# Torreta que já tinha sido quebrada numa vida anterior (ver "persistir"):
	# nasce estragada, mas calada e sem coice — aquele acerto não é deste frame.
	if quebravel and persistir and EstadoMundo.ja_feito(self):
		avariar(false)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _visual == null or _canhao == null or _base == null:
		return  # alguém apagou um nó da cena: não vale travar o jogo por isso
	if quebrada:
		return  # já era: não vigia, não gira, só fuma
	# Tela de puzzle/diálogo aberta: a vigia espera junto — não é justo
	# apanhar (nem ser mirado) enquanto a jogadora lê.
	if Interacao.ocupada():
		return

	var alvo := _alvo_na_mira()
	_girar(alvo, delta)

	# Animação em curso: o ciclo vai até o fim, mesmo que o alvo suma no meio.
	# Quem se esconde durante a carga não cancela o tiro — faz ele errar.
	if _visual.is_playing():
		return

	_espera = maxf(_espera - delta, 0.0)
	if alvo == null or _espera > 0.0:
		return
	_comecar_disparo()


# --- VIGIA (360°, cortada por qualquer obstáculo) ---

## A personagem, se estiver visível agora. Null em qualquer outro caso.
func _alvo_na_mira() -> Node2D:
	if not ativa or quebrada:
		return null
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return null
	# Já caiu: a torreta não fica metralhando um corpo no chão.
	if "current_health" in _player and _player.current_health <= 0:
		return null

	var olho := _olho()
	var mira := _ponto_do_player()
	if olho.distance_to(mira) > alcance:
		return null

	# Não existe cone a conferir: o campo é de 360° e o único teste que resta é
	# a LINHA DE VISÃO. O raio exclui o corpo da personagem de propósito — ele
	# é o destino, não um obstáculo; se sobrar qualquer coisa no caminho, é
	# porque tem mesmo algo no meio.
	var ignorar: Array[RID] = [_player.get_rid()]
	var consulta := PhysicsRayQueryParameters2D.create(olho, mira, mascara_visao, ignorar)
	if not get_world_2d().direct_space_state.intersect_ray(consulta).is_empty():
		return null
	return _player


## De onde a torreta enxerga: a boca do cano. Olhar dali (e não do centro do
## corpo) é o que faz a mira e a visão contarem a mesma história — se a bala
## bateria na quina, a torreta também não vê por cima dela.
func _olho() -> Vector2:
	return _boca.global_position if _boca else global_position


func _ponto_do_player() -> Vector2:
	return _player.global_position - Vector2(0, altura_do_alvo)


# --- GIRO DA CABEÇA ---

func _girar(alvo: Node2D, delta: float) -> void:
	if _canhao == null or _base == null:
		return

	# Tudo medido contra a BASE: rotação 0 é a cabeça pousada em repouso, do
	# jeito que a arte foi desenhada. Assim o ângulo de repouso mora num lugar
	# só (a base), e deitar a torreta noutra parede leva a mira junto.
	var destino := 0.0
	if alvo != null and girar_para_mirar:
		destino = (_ponto_do_player() - _canhao.global_position).angle() - _base.global_rotation

	if velocidade_giro <= 0.0:
		_canhao.rotation = destino
		return
	_canhao.rotation = rotate_toward(_canhao.rotation, destino,
		deg_to_rad(velocidade_giro) * delta)


# --- CICLO DE DISPARO ---

func _comecar_disparo() -> void:
	if not _tem_animacao():
		return
	_disparo_pendente = true
	_visual.animation = ANIM_DISPARO
	_visual.frame = 0
	_visual.play(ANIM_DISPARO)


## O ">=" (e não "==") cobre o quadro perdido: se o jogo engasgar, o
## AnimatedSprite2D pula quadros, e um disparo amarrado num "==" sumiria junto
## com o quadro pulado.
func _ao_trocar_quadro() -> void:
	if not _disparo_pendente or _visual.frame < quadro_do_tiro:
		return
	_disparo_pendente = false
	_disparar()


func _ao_fim_do_disparo() -> void:
	# Animação sem loop: ela já parou sozinha no último quadro, que é
	# exatamente a pose de repouso. Só resta abrir o respiro até o próximo.
	_disparo_pendente = false
	_espera = intervalo


func _disparar() -> void:
	var direcao := Vector2.RIGHT.rotated(_canhao.global_rotation)
	# A bala fica pendurada na FASE, não na torreta: ela precisa continuar
	# viajando mesmo que a torreta seja desligada no meio do voo.
	var pai := get_parent() as Node2D
	if pai == null:
		pai = self
	TiroTorreta.disparar(pai, _olho(), direcao, {
		"dano": dano,
		"velocidade": velocidade_tiro,
		"atirador": self,
	})
	if _som and _som.stream:
		_som.play()
	disparou.emit(direcao)


# --- AVARIA ---

## O bumerangue passou pela AreaAlvo (na ida ou na volta — ele atravessa
## alvos, e a torreta é um deles).
func _ao_levar_bumerangue() -> void:
	if not quebravel:
		return
	if quebrada:
		_baque()  # já estragada: sobra o barulho de bater em ferro-velho
		return
	avariar()


## Estraga a torreta de vez. `com_impacto = false` monta o estado final calado
## e sem tombo — é o caminho de quem já nasce quebrada (ver "persistir").
func avariar(com_impacto: bool = true) -> void:
	if quebrada:
		return
	quebrada = true

	# O ciclo de disparo morre onde estiver, e a cabeça volta à pose de
	# repouso: canhão fechado, do jeito que a arte foi desenhada.
	_disparo_pendente = false
	_espera = 0.0
	if _visual:
		_visual.stop()
	_pose_de_repouso()

	if persistir:
		EstadoMundo.marcar_feito(self)

	# A fumaça é a camada CONSTANTE do estrago; faísca e barulho são do baque,
	# e a chispa do curto volta sozinha de tempos em tempos.
	if _fumaca:
		_fumaca.emitting = true
	_agendar_chispa()

	if com_impacto:
		_baque()
		_tombar()
	else:
		if _canhao:
			_canhao.rotation = 0.0
		_queimar(0.0)

	avariou.emit()


## Volta a torreta ao estado de fábrica. Nenhuma fase usa isto hoje: existe
## para que "quebrada" tenha caminho de volta no dia em que alguma sala quiser
## uma torreta que a manutenção religa.
func consertar() -> void:
	if not quebrada:
		return
	quebrada = false
	if _tween_avaria and _tween_avaria.is_valid():
		_tween_avaria.kill()
	if _tempo_chispa:
		_tempo_chispa.stop()
	if _fumaca:
		_fumaca.emitting = false
	if _chispas:
		_chispas.emitting = false
	if _canhao:
		_canhao.rotation = 0.0
	_pintar(Color.WHITE)
	_pose_de_repouso()


## O baque do metal: som e rajada de faíscas no MESMO frame — é isso que faz
## o barulho parecer vir da torreta, e não da caixa de som.
func _baque() -> void:
	if _som_quebra and _som_quebra.stream:
		_som_quebra.pitch_scale = randf_range(0.92, 1.08)
		_som_quebra.play()
	if _faiscas:
		_faiscas.restart()
		_faiscas.emitting = true


## O tombo. A cabeça ainda dá um coice para FORA no baque — estava mirando
## alguém e a pancada terminou de arrancá-la de lá — e só então cai de volta
## no repouso, passando um triz do ponto (é o TRANS_BACK): o assentar de uma
## peça pesada que perdeu a força. A carcaça queima no mesmo tempo do tombo,
## para o estrago ser UMA coisa só em vez de duas.
func _tombar() -> void:
	if _canhao == null:
		return
	if _tween_avaria and _tween_avaria.is_valid():
		_tween_avaria.kill()
	var lado := 1.0 if _canhao.rotation >= 0.0 else -1.0
	_tween_avaria = create_tween()
	_tween_avaria.tween_property(_canhao, "rotation",
			_canhao.rotation + lado * COICE_AVARIA, TEMPO_COICE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween_avaria.tween_property(_canhao, "rotation", 0.0, TEMPO_TOMBO) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_queimar(TEMPO_TOMBO)


## Tinta de queimado, em paralelo com o tombo. Só na ARTE (corpo e cabeça):
## pintar a Base inteira apagaria a fumaça e as faíscas junto, que são filhas
## dela.
func _queimar(duracao: float) -> void:
	if duracao <= 0.0 or _tween_avaria == null or not _tween_avaria.is_valid():
		_pintar(cor_avariada)
		return
	if _corpo:
		_tween_avaria.parallel().tween_property(_corpo, "modulate", cor_avariada, duracao)
	if _visual:
		_tween_avaria.parallel().tween_property(_visual, "modulate", cor_avariada, duracao)


func _pintar(cor: Color) -> void:
	if _corpo:
		_corpo.modulate = cor
	if _visual:
		_visual.modulate = cor


# --- O CURTO QUE SOBROU ---

## Uma chispa a cada tantos segundos, para sempre. É o que impede a torreta
## quebrada de virar cenário morto no canto da tela.
func _agendar_chispa() -> void:
	if _tempo_chispa == null or _chispas == null:
		return
	var teto: float = maxf(chispa_intervalo_min, chispa_intervalo_max)
	_tempo_chispa.start(randf_range(chispa_intervalo_min, teto))


func _chispar() -> void:
	if not quebrada:
		return
	_chispas.restart()
	_chispas.emitting = true
	_agendar_chispa()


# --- POSES ---

## Trava no último quadro: canhão fechado, é assim que ela espera.
func _pose_de_repouso() -> void:
	if not _tem_animacao():
		return
	_visual.stop()
	_visual.animation = ANIM_DISPARO
	_visual.frame = _visual.sprite_frames.get_frame_count(ANIM_DISPARO) - 1


## Preview vivo no editor: mudar o ângulo no Inspector já deita a torreta na
## parede escolhida. Quem gira é a BASE, com a peça inteira; a cabeça volta
## para a rotação zero, que é a pose em que a arte foi desenhada.
func _aplicar_repouso() -> void:
	var base: Node2D = get_node_or_null("Base")
	if base:
		base.rotation = deg_to_rad(angulo_repouso_graus)
	var canhao: Node2D = get_node_or_null("Base/Canhao")
	if canhao:
		canhao.rotation = 0.0
	_aprumar_efeitos()


## Fumaça e chispa nascem na cabeça — por isso vivem dentro da Base —, mas
## sobem para o CÉU, e não para "cima da torreta". Zerar a rotação GLOBAL
## delas é o que mantém isso verdadeiro em qualquer parede: a torreta de teto
## fumaçaria para baixo, senão.
func _aprumar_efeitos() -> void:
	if not is_inside_tree():
		return
	for caminho in ["Base/Fumaca", "Base/Faiscas", "Base/Chispas"]:
		var efeito: Node2D = get_node_or_null(caminho)
		if efeito:
			efeito.global_rotation = 0.0


func _tem_animacao() -> bool:
	return _visual != null and _visual.sprite_frames != null \
		and _visual.sprite_frames.has_animation(ANIM_DISPARO)
