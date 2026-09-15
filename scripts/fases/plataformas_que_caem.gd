class_name PlataformasQueCaem
extends ReferenceRect

# --- PLATAFORMAS QUE CAEM ---
#
# Pinte as plataformas normalmente na camada Terreno. Quando a fase começa,
# todo tile das FONTES escolhidas que estiver DENTRO deste retângulo vira uma
# PlataformaQueCai (ver plataforma_que_cai.gd) e sai do TileMap. Tiles
# encostados — lado a lado ou empilhados — formam uma plataforma só.
#
# COMO EDITAR NO EDITOR
#   - Arraste/redimensione o retângulo (borda vermelha, só aparece no editor)
#     para cobrir a área. Para mais plataformas, é só pintar mais tiles lá
#     dentro; nada de código ou cena nova.
#   - "fontes" diz QUAIS tiles caem, pelo ID da fonte no TileSet (aba TileSet,
#     lista de fontes à esquerda). No tileset das fases, a fonte 0 é a
#     "Plataformas.png". Tiles de outras fontes na mesma área ficam normais.
#   - Os ajustes de sensação (tempos, força da queda, sons) estão abaixo, no
#     Inspetor, e valem para todas as plataformas deste retângulo. Quer um
#     trecho com outro ritmo? Duplique o nó e cubra só aquele trecho.
#
# No editor os tiles continuam no lugar (é assim que você os vê e pinta);
# eles só viram plataformas soltas durante o jogo.

const _PLATAFORMA := preload("res://scripts/fases/plataforma_que_cai.gd")

## A camada de tiles de onde saem as plataformas.
@export var camada: NodePath = ^"../Terreno"
## IDs das fontes do TileSet cujos tiles viram plataformas que caem.
@export var fontes: Array[int] = [0]

@export_group("Aviso")
## Quanto tempo ela treme antes de cair — a janela para pular.
@export_range(0.05, 3.0, 0.01, "suffix:s") var tempo_aviso: float = 0.95
## Quanto ela cede com o peso ao receber alguém (px).
@export_range(0.0, 12.0, 0.5, "suffix:px") var afundamento: float = 3.0
## Força do tremor no fim do aviso (px).
@export_range(0.0, 6.0, 0.1, "suffix:px") var intensidade_tremor: float = 1.5

@export_group("Queda")
@export_range(100.0, 6000.0, 10.0, "suffix:px/s²") var aceleracao_queda: float = 1800.0
@export_range(50.0, 3000.0, 10.0, "suffix:px/s") var velocidade_max_queda: float = 950.0
## Depois de começar a cair, em quanto tempo ela some.
@export_range(0.1, 5.0, 0.01, "suffix:s") var tempo_ate_sumir: float = 0.6
## Tremor da câmera no instante em que ela se solta (0 = nenhum).
@export_range(0.0, 20.0, 0.1) var tremor_camera: float = 2.5

@export_group("Retorno")
## Quanto tempo fica sumida antes de voltar ao lugar.
@export_range(0.1, 30.0, 0.1, "suffix:s") var tempo_retorno: float = 2.5

@export_group("Sons")
@export var som_aviso: AudioStream = preload("res://sounds/drag.mp3")
@export var som_queda: AudioStream = preload("res://plataforma-caindo-som.mp3")
@export var som_retorno: AudioStream = preload("res://sounds/POP.mp3")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Adiado: a fase termina de montar tudo antes de os tiles virarem corpos.
	_gerar.call_deferred()


func _gerar() -> void:
	var tiles := get_node_or_null(camada) as TileMapLayer
	if tiles == null:
		push_warning("%s: não achei a camada de tiles em '%s'." % [name, camada])
		return

	var area := get_global_rect()
	var livres := {}
	for c in tiles.get_used_cells():
		if tiles.get_cell_source_id(c) in fontes \
				and area.has_point(tiles.to_global(tiles.map_to_local(c))):
			livres[c] = true

	# Agrupa por vizinhança (4 direções): cada grupo é uma plataforma.
	var total := 0
	while not livres.is_empty():
		var inicio: Vector2i = livres.keys()[0]
		livres.erase(inicio)
		var grupo: Array[Vector2i] = []
		var pilha: Array[Vector2i] = [inicio]
		while not pilha.is_empty():
			var c: Vector2i = pilha.pop_back()
			grupo.append(c)
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var vizinho: Vector2i = c + d
				if livres.has(vizinho):
					livres.erase(vizinho)
					pilha.append(vizinho)
		total += 1
		_criar_plataforma(tiles, grupo, total)

	if total == 0:
		push_warning("%s: nenhum tile das fontes %s dentro da área." % [name, fontes])


func _criar_plataforma(tiles: TileMapLayer, grupo: Array[Vector2i], numero: int) -> void:
	var p: Node2D = _PLATAFORMA.new()
	p.name = "%s_%d" % [name, numero]
	p.tempo_aviso = tempo_aviso
	p.afundamento = afundamento
	p.intensidade_tremor = intensidade_tremor
	p.aceleracao_queda = aceleracao_queda
	p.velocidade_max_queda = velocidade_max_queda
	p.tempo_ate_sumir = tempo_ate_sumir
	p.tempo_retorno = tempo_retorno
	p.tremor_camera = tremor_camera
	p.som_aviso = som_aviso
	p.som_queda = som_queda
	p.som_retorno = som_retorno
	get_parent().add_child(p)
	p.montar(tiles, grupo)
	for c in grupo:
		tiles.erase_cell(c)
