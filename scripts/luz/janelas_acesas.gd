@tool
class_name JanelasAcesas
extends Node2D
## Acende sozinho, à noite, toda janela pintada nos TileMapLayers da cena — como
## se as casas estivessem com a luz acesa lá dentro.
##
## Janela aqui é tile: pinta-se no TileMap como qualquer outro pedaço de
## cenário. Este nó varre as camadas atrás da arte de janela (o bloco de 2 × 3
## tiles do `Buildings.png`) e acende todas, todas iguais. Pintou uma janela
## nova, ela acende; apagou, a luz vai embora. No editor a varredura refaz
## sozinha enquanto se pinta.
##
## [codeblock]
## vidro    os vidros da arte pintados de uma cor só, a [member cor], por cima
##          do vidro escuro do tile (o caixilho continua sendo o do tile). Não
##          recebe sombra: é a luz de dentro.
## clarão   o brilho do vidro no ar, somado por cima da parede.
## luz      a luz que sai e bate no caixilho, na parede e em quem passa perto.
## [/codeblock]
##
## O que este nó desenha e as luzes são filhos internos: não aparecem na árvore
## da cena e não são gravados no .tscn. O que se ajusta é aqui, e vale para
## todas as janelas da fase de uma vez. A força vem da hora, como a dos postes:
## a [Atmosfera] escreve a [member intensidade] — fraca ao entardecer, com tudo
## à noite, apagada no "Tudo claro (para pintar)".
##
## [b]Uma luz por fileira.[/b] O Godot soma no máximo 15 luzes num mesmo
## desenho, e o cenário da rua é desenhado num bloco só: com mais de 15 luzes
## na tela, alguma deixa de bater na parede. Por isso as janelas vizinhas de um
## mesmo andar dividem uma luz só, com uma poça em cada janela — a mesma luz que
## teriam cada uma com a sua.
##
## Para ensinar outra arte de janela, acrescente uma entrada em [constant
## JANELAS].

const GRUPO := &"luz_artificial"
## Tamanho do pixel de arte no mundo (os tiles são 16 px em escala 2).
const PIXEL := 2.0
## Quanto o clarão passa da borda do vidro, em pixels de arte.
const RAIO_DO_CLARAO := 14
## Curva da queda da luz: maior aperta a luz contra a janela.
const QUEDA := 1.6
## Janelas do mesmo andar até esta distância (de meio a meio, no mundo) dividem
## uma luz.
const VIZINHAS := 320.0

## Quais artes de quais texturas são janela.
##   "celula"   a célula de cima, à esquerda, da arte no atlas;
##   "tamanho"  a arte inteira, em células;
##   "vidros"   cada vidro, em pixels da arte, contando do canto de cima à
##              esquerda: a bandeira em cima e as folhas embaixo dela.
const JANELAS := {
	"Buildings.png": {
		"celula": Vector2i(9, 0),
		"tamanho": Vector2i(2, 3),
		"vidros": [Rect2i(8, 9, 16, 5), Rect2i(8, 16, 6, 5), Rect2i(18, 16, 6, 5),
			Rect2i(8, 23, 6, 17), Rect2i(18, 23, 6, 17)],
	},
}

## Onde procurar os TileMapLayers. O padrão é a cena inteira.
@export_node_path("Node") var onde_procurar := NodePath("..")

@export_group("Luz")
## A cor da luz da casa: é a cor do vidro, do clarão e da luz na parede.
@export var cor := Color(1.0, 0.84, 0.46):
	set(v):
		cor = v
		_aplicar()
## Força da luz que sai da janela e bate no caixilho e na parede.
@export_range(0.0, 4.0, 0.01) var energia := 1.1:
	set(v):
		energia = v
		_aplicar()
## Até onde essa luz chega, em pixels do mundo. A janela tem 64 × 96.
@export_range(16.0, 400.0, 2.0) var alcance := 140.0:
	set(v):
		alcance = v
		_montar()

@export_group("Ar")
## Força do clarão em volta do vidro.
@export_range(0.0, 1.0, 0.01) var clarao := 0.3:
	set(v):
		clarao = v
		_aplicar()

@export_group("Pixel art")
## Desligado (o padrão), o clarão e a luz na parede são um degradê liso. Ligado,
## eles caem em degraus com a emenda pontilhada. O vidro é sempre pixel art.
@export var pixelada := false:
	set(v):
		pixelada = v
		_montar()
## Em quantos degraus a luz cai. Só vale com [member pixelada] ligado.
@export_range(2, 16, 1) var degraus := 6:
	set(v):
		degraus = v
		_montar()
## Quanto de cada degrau é pontilhado na emenda. Só vale com [member pixelada]
## ligado.
@export_range(0.0, 1.0, 0.01) var pontilhado := 0.5:
	set(v):
		pontilhado = v
		_montar()

## Força pedida pelo horário, de 0 (apagadas) a 1. Quem escreve é a Atmosfera.
var intensidade := 1.0:
	set(v):
		intensidade = clampf(v, 0.0, 1.0)
		_aplicar()

## A arte do vidro de cada receita, já pintada.
static var _mascaras: Dictionary = {}

## Cada janela achada, da esquerda para a direita (e de cima para baixo):
## {"arte": Rect2 da arte inteira no mundo, "vidros": Rect2i que abraça os
## vidros, em pixels de arte, "mascara": a arte do vidro}.
var _janelas: Array[Dictionary] = []
## As janelas que dividem cada luz: índices em [member _janelas], da esquerda
## para a direita.
var _fileiras: Array[Array] = []
var _luzes: Array[PointLight2D] = []
var _ar: Node2D
var _vidros: Node2D
var _camadas_ouvidas: Array[TileMapLayer] = []
var _busca_pedida := false


func _enter_tree() -> void:
	add_to_group(GRUPO)
	# No editor, cada aba de cena sai da árvore quando se troca para outra e
	# volta quando se volta para ela: a busca é pedida de novo a cada entrada
	# (ver postes_de_luz.gd).
	_pedir_busca()


func _ready() -> void:
	set_meta(&"_edit_lock_", true)
	var do_ar := CanvasItemMaterial.new()
	do_ar.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	do_ar.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var de_dentro := CanvasItemMaterial.new()
	de_dentro.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	# O clarão vem antes: os vidros são desenhados por cima dele.
	_ar = _nova_camada("Clarao", do_ar, _desenhar_o_clarao)
	_vidros = _nova_camada("Vidros", de_dentro, _desenhar_os_vidros)
	_vidros.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# As janelas são achadas um quadro depois da cena abrir, e a Atmosfera pode
	# já ter distribuído o horário: pergunta a ela.
	var regente := get_tree().get_first_node_in_group(&"atmosfera")
	if regente != null and regente.has_method(&"nivel_dos_postes"):
		intensidade = regente.nivel_dos_postes()
	_pedir_busca()


func _exit_tree() -> void:
	for camada in _camadas_ouvidas:
		if is_instance_valid(camada) and camada.changed.is_connected(_pedir_busca):
			camada.changed.disconnect(_pedir_busca)
	_camadas_ouvidas.clear()


## Quantas janelas a varredura achou.
func quantidade() -> int:
	return _janelas.size()


## Onde cada janela está no mundo: o retângulo da arte inteira.
func janelas() -> Array[Rect2]:
	var lista: Array[Rect2] = []
	for janela in _janelas:
		lista.append(janela["arte"])
	return lista


## As luzes na parede, uma por fileira de janelas.
func luzes() -> Array[PointLight2D]:
	return _luzes


func _nova_camada(nome: String, material_da_camada: CanvasItemMaterial, desenho: Callable) -> Node2D:
	var camada := Node2D.new()
	camada.name = nome
	camada.material = material_da_camada
	camada.set_meta(&"_edit_lock_", true)
	camada.draw.connect(desenho)
	add_child(camada, false, Node.INTERNAL_MODE_BACK)
	return camada


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
	_janelas.clear()
	_fileiras.clear()
	var raiz := get_node_or_null(onde_procurar)
	if raiz != null:
		_varrer(raiz, _janelas)
	_janelas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: Vector2 = (a["arte"] as Rect2).position
		var pb: Vector2 = (b["arte"] as Rect2).position
		return pa.x < pb.x if pa.x != pb.x else pa.y < pb.y)

	# As janelas de um mesmo andar, vizinhas, dividem uma luz.
	var por_andar := {}
	for i in _janelas.size():
		var y := roundi((_janelas[i]["arte"] as Rect2).position.y)
		if not por_andar.has(y):
			por_andar[y] = []
		por_andar[y].append(i)
	for andar: Array in por_andar.values():
		var fileira: Array[int] = []
		for i: int in andar:
			if not fileira.is_empty() and (_janelas[i]["arte"] as Rect2).position.x \
					- (_janelas[fileira.back()]["arte"] as Rect2).position.x > VIZINHAS:
				_fileiras.append(fileira)
				fileira = []
			fileira.append(i)
		_fileiras.append(fileira)
	_montar()


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
	for i in tile_set.get_source_count():
		var id := tile_set.get_source_id(i)
		var fonte := tile_set.get_source(id) as TileSetAtlasSource
		if fonte == null or fonte.texture == null:
			continue
		var receita: Dictionary = JANELAS.get(fonte.texture.resource_path.get_file(), {})
		if receita.is_empty():
			continue
		var tamanho: Vector2i = receita["tamanho"] * tile_set.tile_size
		var mascara := _mascara(tamanho, receita["vidros"])
		var vidros := Rect2i()
		for vidro: Rect2i in receita["vidros"]:
			vidros = vidro if vidros.size == Vector2i.ZERO else vidros.merge(vidro)
		for canto in camada.get_used_cells_by_id(id, receita["celula"]):
			if not _inteira(camada, id, canto, receita):
				continue
			# map_to_local dá o CENTRO da célula, em pixels da camada.
			var no_mundo := camada.to_global(camada.map_to_local(canto) - lado * 0.5)
			achadas.append({
				"arte": Rect2(no_mundo, Vector2(tamanho) * PIXEL),
				"vidros": vidros,
				"mascara": mascara,
			})


## A arte inteira está pintada, e não só o canto dela.
func _inteira(camada: TileMapLayer, id: int, canto: Vector2i, receita: Dictionary) -> bool:
	var celulas: Vector2i = receita["tamanho"]
	for y in celulas.y:
		for x in celulas.x:
			var passo := Vector2i(x, y)
			if camada.get_cell_source_id(canto + passo) != id \
					or camada.get_cell_atlas_coords(canto + passo) != receita["celula"] + passo:
				return false
	return true


func _ouvir(camada: TileMapLayer) -> void:
	# Só no editor: no jogo o cenário não é repintado.
	if not Engine.is_editor_hint() or _camadas_ouvidas.has(camada):
		return
	camada.changed.connect(_pedir_busca)
	_camadas_ouvidas.append(camada)


## Refaz as luzes das fileiras e redesenha as janelas (o que depende do alcance
## e do jeito da luz).
func _montar() -> void:
	if _ar == null:
		return
	for luz in _luzes:
		if is_instance_valid(luz):
			luz.queue_free()
	_luzes.clear()

	var raio := maxi(int(round(alcance / PIXEL)), 4)
	for fileira in _fileiras:
		var primeira: Dictionary = _janelas[fileira[0]]
		var centros: Array[int] = []
		for i: int in fileira:
			centros.append(roundi(((_janelas[i]["arte"] as Rect2).position.x
				- (primeira["arte"] as Rect2).position.x) / PIXEL))
		# Lisa (degraus 0) ou em degraus: a mesma forma, pintada de dois jeitos.
		var poca := TexturaDeLuz.fileira(raio, centros, degraus if pixelada else 0, pontilhado, QUEDA)
		var textura: Texture2D = poca["textura"]
		var passo: float = PIXEL * float(poca["escala"])
		var luz := PointLight2D.new()
		luz.name = "Luz%d" % _luzes.size()
		luz.blend_mode = Light2D.BLEND_MODE_ADD
		luz.texture = textura
		luz.texture_scale = passo
		# O "offset" da luz conta do centro da textura; a poça da primeira
		# janela fica no nó.
		luz.offset = (textura.get_size() * 0.5 - (poca["fonte"] as Vector2)) * passo
		luz.set_meta(&"_edit_lock_", true)
		add_child(luz, false, Node.INTERNAL_MODE_BACK)
		# Um pouco abaixo do meio do vidro: é no peitoril e na parede de baixo
		# que a luz de dentro mais bate.
		var vidros: Rect2i = primeira["vidros"]
		luz.global_position = _meio_do_vidro(primeira) + Vector2(0.0, vidros.size.y * PIXEL * 0.25)
		_luzes.append(luz)

	# A lisa é esticada com interpolação; a pixelada, com o pixel seco.
	_ar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if pixelada \
		else CanvasItem.TEXTURE_FILTER_LINEAR
	_ar.queue_redraw()
	_vidros.queue_redraw()
	_aplicar()


func _aplicar() -> void:
	if _ar == null:
		return
	# Os desenhos são brancos: a cor e a força vêm daqui, sem redesenhar.
	_vidros.modulate = Color(cor.r, cor.g, cor.b, intensidade)
	_vidros.visible = intensidade > 0.01
	_ar.modulate = Color(cor.r, cor.g, cor.b, clampf(clarao * intensidade, 0.0, 1.0))
	_ar.visible = clarao > 0.0 and intensidade > 0.01
	for luz in _luzes:
		luz.color = cor
		luz.energy = energia * intensidade
		luz.enabled = energia > 0.0 and intensidade > 0.01


func _desenhar_o_clarao() -> void:
	for janela in _janelas:
		var vidros: Rect2i = janela["vidros"]
		var brilho := TexturaDeLuz.retangulo(vidros.size.x, vidros.size.y, RAIO_DO_CLARAO,
			maxi(degraus - 2, 2) if pixelada else 0, pontilhado)
		var textura: Texture2D = brilho["textura"]
		var passo: float = PIXEL * float(brilho["escala"])
		var meio := _ar.to_local(_meio_do_vidro(janela))
		_ar.draw_texture_rect(textura,
			Rect2(meio - (brilho["fonte"] as Vector2) * passo, textura.get_size() * passo), false)


func _desenhar_os_vidros() -> void:
	for janela in _janelas:
		var arte: Rect2 = janela["arte"]
		_vidros.draw_texture_rect(janela["mascara"], Rect2(_vidros.to_local(arte.position), arte.size), false)


## O meio dos vidros de uma janela, no mundo.
func _meio_do_vidro(janela: Dictionary) -> Vector2:
	var vidros: Rect2i = janela["vidros"]
	return (janela["arte"] as Rect2).position + (Vector2(vidros.position) + Vector2(vidros.size) * 0.5) * PIXEL


## A arte do vidro de uma janela: branca nos vidros e transparente no resto,
## para o caixilho continuar sendo o do tile. Quem dá a cor é a [member cor].
static func _mascara(tamanho: Vector2i, vidros: Array) -> ImageTexture:
	var chave := "%s:%s" % [tamanho, vidros]
	if _mascaras.has(chave):
		return _mascaras[chave]
	var img := Image.create(maxi(tamanho.x, 1), maxi(tamanho.y, 1), false, Image.FORMAT_RGBA8)
	for vidro: Rect2i in vidros:
		img.fill_rect(vidro, Color.WHITE)
	var textura := ImageTexture.create_from_image(img)
	_mascaras[chave] = textura
	return textura
