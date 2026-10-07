@tool
class_name PostesDeLuz
extends Node2D
## Acende sozinho todo poste pintado nos TileMapLayers da cena.
##
## Poste aqui é tile: pinta-se no TileMap como qualquer outro pedaço de cenário.
## Este nó varre as camadas atrás das células que são a LÂMPADA (o braço do
## poste do `Props-01.png`) e põe uma [LuzDePoste] no tubo de cada uma. Pintou
## um poste novo, ele acende; apagou, a luz vai embora. No editor a varredura
## refaz sozinha enquanto se pinta.
##
## As luzes são filhas internas deste nó: não aparecem na árvore da cena e não
## são gravadas no .tscn — só existem enquanto a cena está aberta. O que se
## ajusta é aqui, e vale para todos os postes da fase de uma vez.
##
## Para ensinar outra arte de lâmpada, acrescente uma entrada em [constant
## LAMPADAS]. Para acender algo que não é tile, instancie
## `scenes/luz/luz_de_poste.tscn` direto na cena.

## Quais células de quais texturas são lâmpada. Células vizinhas na mesma linha
## formam UMA lâmpada (o braço do poste tem três tiles de largura).
##   "celulas"  coordenadas no atlas;
##   "tubo_y"   altura do tubo dentro do tile, em pixels da arte, contando do topo;
##   "sobra"    quanto o tubo é mais curto que os tiles somados, em pixels da arte.
const LAMPADAS := {
	"Props-01.png": {
		"celulas": [Vector2i(1, 9), Vector2i(2, 9), Vector2i(3, 9)],
		"tubo_y": 5.5,
		"sobra": 2.0,
	},
}

## Onde procurar os TileMapLayers. O padrão é a cena inteira.
@export_node_path("Node") var onde_procurar := NodePath("..")

@export_group("Luz")
@export var cor := Color(1.0, 0.8, 0.5):
	set(v):
		cor = v
		_repassar()
## Força da poça de luz no auge (à noite).
@export_range(0.0, 4.0, 0.01) var energia := 1.0:
	set(v):
		energia = v
		_repassar()
## Até onde a luz desce, em pixels do mundo. O poste tem 256 de altura.
@export_range(40.0, 900.0, 2.0) var alcance := 400.0:
	set(v):
		alcance = v
		_repassar()
## Abertura do cone (0 = quase reto para baixo, 1 = bem aberto).
@export_range(0.0, 1.0, 0.01) var abertura := 0.5:
	set(v):
		abertura = v
		_repassar()

@export_group("Pixel art")
## Em quantos degraus a luz cai.
@export_range(2, 16, 1) var degraus := 6:
	set(v):
		degraus = v
		_repassar()
## Quanto de cada degrau é pontilhado na emenda.
@export_range(0.0, 1.0, 0.01) var pontilhado := 0.5:
	set(v):
		pontilhado = v
		_repassar()

@export_group("Ar")
## Força do clarão em volta da lâmpada.
@export_range(0.0, 1.0, 0.01) var clarao := 0.5:
	set(v):
		clarao = v
		_repassar()
## Força do feixe visível no ar.
@export_range(0.0, 1.0, 0.01) var feixe := 0.12:
	set(v):
		feixe = v
		_repassar()

@export_group("Vida")
## Quanto a luz treme (0 = parada).
@export_range(0.0, 0.3, 0.005) var tremor := 0.025:
	set(v):
		tremor = v
		_repassar()
## Mariposas rodando cada lâmpada, à noite.
@export_range(0, 8, 1) var mariposas := 3:
	set(v):
		mariposas = v
		_repassar()

var _luzes: Array[LuzDePoste] = []
var _camadas_ouvidas: Array[TileMapLayer] = []
var _busca_pedida := false


func _ready() -> void:
	set_meta(&"_edit_lock_", true)
	_pedir_busca()


func _exit_tree() -> void:
	for camada in _camadas_ouvidas:
		if is_instance_valid(camada) and camada.changed.is_connected(_pedir_busca):
			camada.changed.disconnect(_pedir_busca)
	_camadas_ouvidas.clear()


## Quantas lâmpadas a varredura achou.
func quantidade() -> int:
	return _luzes.size()


## As luzes criadas, na ordem em que foram achadas (da esquerda para a direita).
func luzes() -> Array[LuzDePoste]:
	return _luzes


## Refaz a varredura no próximo quadro. Várias chamadas no mesmo quadro (o
## TileMap avisa a cada célula pintada) viram uma só.
func _pedir_busca() -> void:
	if _busca_pedida or not is_inside_tree():
		return
	_busca_pedida = true
	_procurar.call_deferred()


func _procurar() -> void:
	_busca_pedida = false
	if not is_inside_tree():
		return
	for luz in _luzes:
		if is_instance_valid(luz):
			luz.queue_free()
	_luzes.clear()

	var raiz := get_node_or_null(onde_procurar)
	if raiz == null:
		return
	var achadas: Array[Dictionary] = []
	_varrer(raiz, achadas)
	achadas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["ponto"].x < b["ponto"].x)

	for achada in achadas:
		var luz := LuzDePoste.new()
		luz.name = "Luz%d" % _luzes.size()
		luz.largura = achada["largura"]
		_vestir(luz)
		luz.set_meta(&"_edit_lock_", true)
		add_child(luz, false, Node.INTERNAL_MODE_BACK)
		luz.global_position = achada["ponto"]
		_luzes.append(luz)


func _varrer(no: Node, achadas: Array[Dictionary]) -> void:
	var camada := no as TileMapLayer
	if camada != null and camada.tile_set != null and camada.is_visible_in_tree():
		_ouvir(camada)
		_varrer_camada(camada, achadas)
	for filho in no.get_children():
		_varrer(filho, achadas)


func _varrer_camada(camada: TileMapLayer, achadas: Array[Dictionary]) -> void:
	var tile_set := camada.tile_set
	var lado := Vector2(tile_set.tile_size)
	# Fonte do TileSet -> receita da lâmpada, para as fontes que usam uma
	# textura conhecida.
	var receitas := {}
	for i in tile_set.get_source_count():
		var id := tile_set.get_source_id(i)
		var fonte := tile_set.get_source(id) as TileSetAtlasSource
		if fonte == null or fonte.texture == null:
			continue
		var arquivo := fonte.texture.resource_path.get_file()
		if LAMPADAS.has(arquivo):
			receitas[id] = LAMPADAS[arquivo]
	if receitas.is_empty():
		return

	# Todas as células de lâmpada, e depois as fileiras contíguas.
	var celulas := {}
	for id: int in receitas:
		for coordenada: Vector2i in receitas[id]["celulas"]:
			for celula in camada.get_used_cells_by_id(id, coordenada):
				celulas[celula] = receitas[id]
	for celula: Vector2i in celulas:
		if celulas.has(celula + Vector2i.LEFT):
			continue  # não é a ponta esquerda da fileira
		var comprimento := 1
		while celulas.has(celula + Vector2i(comprimento, 0)):
			comprimento += 1
		var receita: Dictionary = celulas[celula]
		# map_to_local dá o CENTRO da célula, em pixels da camada.
		var topo_esquerdo := camada.map_to_local(celula) - lado * 0.5
		var tubo := topo_esquerdo + Vector2(lado.x * comprimento * 0.5, receita["tubo_y"])
		var escala := camada.global_transform.get_scale()
		achadas.append({
			"ponto": camada.to_global(tubo),
			"largura": (lado.x * comprimento - float(receita["sobra"])) * absf(escala.x),
		})


func _ouvir(camada: TileMapLayer) -> void:
	# Só no editor: no jogo o cenário não é repintado.
	if not Engine.is_editor_hint() or _camadas_ouvidas.has(camada):
		return
	camada.changed.connect(_pedir_busca)
	_camadas_ouvidas.append(camada)


func _repassar() -> void:
	for luz in _luzes:
		if is_instance_valid(luz):
			_vestir(luz)


func _vestir(luz: LuzDePoste) -> void:
	luz.cor = cor
	luz.energia = energia
	luz.alcance = alcance
	luz.abertura = abertura
	luz.degraus = degraus
	luz.pontilhado = pontilhado
	luz.clarao = clarao
	luz.feixe = feixe
	luz.tremor = tremor
	luz.mariposas = mariposas
