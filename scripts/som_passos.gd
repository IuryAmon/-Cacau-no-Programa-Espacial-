class_name SomPassos
extends AudioStreamPlayer2D

# --- OS PASSOS DA CACAU ---
#
# Um passo soa no quadro em que o pé ENCOSTA no chão, não num relógio à parte:
# quem manda no ritmo é a própria animação "run". Se a velocidade da animação
# mudar, os passos mudam junto. O som sai um tiquinho ANTES do quadro (ver
# "adiantamento"), para o impacto chegar no ouvido junto com o pé na tela.
#
# O som depende do que está debaixo do pé. Cada chão diz o que ele é:
#
#   * TILES — a camada de dados "superficie" do TileSet (aba "Custom Data" do
#     editor de TileSet). Hoje:
#       "grama"     a grama do Floor Tiles1/Floor Tiles2 (world1 e fase 1.2);
#       "concreto"  o level_tileset do laboratório (world1 do x 6110 em
#                   diante, fase 1 inteira e o piso do lab na fase 1.2), o
#                   industrial do world1 (também depois do x 6110) e as
#                   tábuas do world1: a ponte do começo (x 3575..4666) e os
#                   degraus e o topo do mirante na árvore (x ~5400..5800).
#       "metal"     todo o chão do laboratório (world 2) — os TileSets dele
#                   ficam dentro da própria cena — e as plataformas laranja
#                   (Plataformas.png) do tileset_fases.tres.
#     No tileset_fases.tres o industrial fica sem nome: é o chão das fases
#     2, 3 e final, que ainda vão ganhar som próprio.
#   * QUALQUER OUTRO CORPO (plataforma, caixa, elevador) — uma metadata
#     "superficie" no próprio corpo em que ela pisa. Hoje é "metal" na
#     PlataformaMovel, na PlataformaDeViagem e na plataforma.tscn (a do guincho
#     da fase 1 e a do world1). As plataformas que caem herdam a dos tiles de
#     que saíram (plataforma_que_cai.gd).
#
# E "sons_por_superficie" liga o nome ao som. Chão que não diz nada, ou que
# diz um nome ainda sem som, fica mudo.
#
# Para uma superfície nova: faça o AudioStreamRandomizer das variações (como
# sounds/passos/grama.tres), adicione-o em "sons_por_superficie" no SomPassos
# da player.tscn e pinte o nome na camada "superficie" dos tiles.

signal passo_dado(superficie: StringName)

const CAMADA_DO_TILESET := "superficie"
const META_DO_CORPO := &"superficie"
## Quanto o raio procura abaixo da sola. Cobre o floor_snap da personagem
## (10 px) sem chegar a achar um chão que ela ainda nem alcançou.
const FOLGA_ABAIXO_DOS_PES := 8.0

@export var sprite: AnimatedSprite2D
@export var animacao_corrida: StringName = &"run"
## Quadros da "run" em que um pé toca o chão, contados do 0 como no editor de
## SpriteFrames: no 1 pisa um pé e no 7 o outro (0 e 6 são o pé ainda no ar).
@export var quadros_de_passo: PackedInt32Array = PackedInt32Array([1, 7])
## Quanto ANTES do quadro do pé o som sai, em segundos. Compensa o atraso da
## saída de áudio e o tempo que o som leva do começo do arquivo até o impacto
## (na grama o "crunch" cresce por uns 20 ms). Afine de ouvido: mais alto = mais
## cedo. 0 = exatamente no quadro do pé.
@export_range(0.0, 0.1, 0.005, "suffix:s") var adiantamento := 0.04
@export var sons_por_superficie: Dictionary[StringName, AudioStream] = {}
## Ajuste de volume de cada chão, em dB, somado ao volume_db deste nó.
@export var volume_por_superficie: Dictionary[StringName, float] = {}

@onready var _corpo := get_parent() as CharacterBody2D
@onready var _volume_base_db := volume_db

## Distância do centro do corpo até a sola, e até onde vão os raios dos lados.
## Saem da forma de colisão no _ready: mudar a cápsula não desafina nada aqui.
var _ate_a_sola := 36.0
var _meia_sola := 11.0
## O quadro de passo cujo som já saiu (adiantado ou não) — para o mesmo pé não
## soar duas vezes: uma na janela do adiantamento e outra ao chegar no quadro.
var _pe_que_soou := -1


func _ready() -> void:
	var forma := _corpo.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if forma and forma.shape:
		var caixa := forma.shape.get_rect()
		_ate_a_sola = forma.position.y + caixa.end.y
		_meia_sola = maxf(caixa.size.x * 0.5 - 2.0, 0.0)


# O passo não espera o frame_changed do quadro do pé: a cada quadro de tela
# ele mede quanto falta para a animação chegar lá e dispara quando entra na
# janela do adiantamento.
func _process(_delta: float) -> void:
	# is_playing() de fora deixa passar o dash, que estaciona o sprite num
	# quadro da "run" com pause() — pose congelada não é passo.
	if sprite == null or sprite.animation != animacao_corrida or not sprite.is_playing():
		_pe_que_soou = -1
		return

	# Já no quadro do pé sem ter soado: a corrida começou dentro da janela
	# (ou o adiantamento é 0). Sai agora mesmo.
	if sprite.frame in quadros_de_passo:
		if _pe_que_soou != sprite.frame:
			_pe_que_soou = sprite.frame
			pisar()
		return

	var proximo := _proximo_pe()
	if proximo.is_empty():
		return
	var pe: int = proximo[0]
	var falta: float = proximo[1]
	if falta <= adiantamento:
		if _pe_que_soou != pe:
			_pe_que_soou = pe
			pisar()
	elif _pe_que_soou == pe:
		# Longe dele de novo: é o mesmo pé na volta seguinte da animação.
		_pe_que_soou = -1


## [quadro, segundos]: o próximo quadro de passo e quanto falta para ele
## começar, contando o resto do quadro atual e os do meio. Vazio se a
## animação não anda.
func _proximo_pe() -> Array:
	var quadros := sprite.sprite_frames
	var total := quadros.get_frame_count(animacao_corrida)
	var fps := quadros.get_animation_speed(animacao_corrida) * absf(sprite.get_playing_speed())
	if total == 0 or fps <= 0.0:
		return []
	var falta := (1.0 - sprite.frame_progress) \
			* quadros.get_frame_duration(animacao_corrida, sprite.frame) / fps
	for i in range(1, total + 1):
		var q := (sprite.frame + i) % total
		if q in quadros_de_passo:
			return [q, falta]
		falta += quadros.get_frame_duration(animacao_corrida, q) / fps
	return []


## Um passo agora, no chão que estiver sob os pés. Sem chão (ela saiu da
## beirada no meio da passada) não sai nada.
func pisar() -> void:
	var chao := _chao_sob_os_pes()
	if chao.is_empty():
		return
	var superficie := superficie_do_chao(chao.collider, chao.position)
	passo_dado.emit(superficie)

	var som: AudioStream = sons_por_superficie.get(superficie)
	if som == null:
		return
	# Trocar o stream corta o que ainda está soando: só troca quando o chão
	# muda de fato, para a cauda de um passo não morrer no início do próximo.
	if stream != som:
		stream = som
	volume_db = _volume_base_db + float(volume_por_superficie.get(superficie, 0.0))
	play()


## Três raios descendo do corpo — o do meio e um em cada ponta da sola —
## porque na beirada de uma plataforma o meio dela já está sobre o vazio.
func _chao_sob_os_pes() -> Dictionary:
	var espaco := _corpo.get_world_2d().direct_space_state
	var alcance := Vector2.DOWN * (_ate_a_sola + FOLGA_ABAIXO_DOS_PES)
	for lado in [0.0, -_meia_sola, _meia_sola]:
		var de := _corpo.global_position + Vector2(lado, 0.0)
		var raio := PhysicsRayQueryParameters2D.create(de, de + alcance,
				_corpo.collision_mask, [_corpo.get_rid()])
		var achou := espaco.intersect_ray(raio)
		if not achou.is_empty():
			return achou
	return {}


## O que o chão diz que é, no ponto em que o raio bateu nele.
static func superficie_do_chao(colisor: Object, ponto: Vector2) -> StringName:
	var camada := colisor as TileMapLayer
	if camada:
		var tileset := camada.tile_set
		if tileset == null or tileset.get_custom_data_layer_by_name(CAMADA_DO_TILESET) < 0:
			return &""
		# O raio para em cima da borda do tile; 1 px para dentro garante que a
		# célula lida é a de baixo, e não a vazia logo acima dela. (A célula sai
		# da posição, não do RID do corpo: com os quadrantes de física do
		# TileMapLayer, um corpo junta vários tiles.)
		var celula := camada.local_to_map(camada.to_local(ponto + Vector2.DOWN))
		var dados := camada.get_cell_tile_data(celula)
		if dados == null:
			return &""
		return StringName(dados.get_custom_data(CAMADA_DO_TILESET))
	var corpo := colisor as Node
	if corpo and corpo.has_meta(META_DO_CORPO):
		return StringName(corpo.get_meta(META_DO_CORPO))
	return &""
