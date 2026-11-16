class_name BlocoDeTiles
extends Node2D

# --- UM PEDAÇO DO TILEMAP QUE SE MEXE ---
#
# O elevador de carga da fase 2 é PINTADO nos TileMapLayers, como o resto do
# cenário. Para ele andar, este nó tira do mapa as células dele — toda célula
# com o CENTRO dentro de um retângulo do mundo — e as redesenha numa cópia da
# camada, filha deste nó, exatamente no mesmo lugar. Daí é só mexer no
# "deslocamento".
#
# Pelo centro, e não pela borda: uma camada que está uns pixels fora da grade
# (a Frente do telhado está 3 px para a direita) entra certinha, sem pegar a
# célula vizinha.
#
# Cada camada de origem vira uma cópia com o MESMO tileset, escala, posição e
# z_index (a grade da Frente continua na frente da Cacau, o Cenario atrás),
# mas sem colisão. Quem cria é a fase, no _ready() dela (fase2_telhado.gd,
# fase2_torre.gd): no editor as células continuam nas camadas de sempre.
#
# Os cortes valem para o bloco inteiro, em y do mundo (shader
# corte_abaixo.gdshader): abaixo de "cortar_abaixo_de" e acima de
# "cortar_acima_de" nada dele aparece.

const SHADER_DO_CORTE := preload("res://shaders/corte_abaixo.gdshader")

## Quanto o bloco desceu (px; negativo = subiu) do lugar em que foi pintado.
var deslocamento: float = 0.0:
	set(valor):
		deslocamento = valor
		position.y = _y_de_origem + valor

var _y_de_origem: float = 0.0
var _copias: Array[TileMapLayer] = []
var _material: ShaderMaterial = null


## Cria o bloco como filho de "pai" e já passa para ele as células de
## "camadas" com o centro dentro de "area" (retângulo do mundo).
static func recortar(pai: Node, nome: String, camadas: Array, area: Rect2) -> BlocoDeTiles:
	var bloco := BlocoDeTiles.new()
	bloco.name = nome
	pai.add_child(bloco)
	bloco._y_de_origem = bloco.position.y
	for camada in camadas:
		if camada is TileMapLayer:
			bloco.tirar_de(camada, area)
	return bloco


## Passa para o bloco toda célula de "camada" com o centro dentro de "area"
## (mundo). Devolve quantas foram.
func tirar_de(camada: TileMapLayer, area: Rect2) -> int:
	var celulas: Array[Vector2i] = []
	for celula in camada.get_used_cells():
		if area.has_point(camada.to_global(camada.map_to_local(celula))):
			celulas.append(celula)
	if celulas.is_empty():
		return 0
	var copia := _copia_de(camada)
	for celula in celulas:
		copia.set_cell(celula, camada.get_cell_source_id(celula),
			camada.get_cell_atlas_coords(celula), camada.get_cell_alternative_tile(celula))
		camada.erase_cell(celula)
	return celulas.size()


## Repete para cima a célula do topo de cada coluna até cobrir a altura "ate_y"
## do mundo. É o tubo da torre: pintado só até onde o elevador está no editor,
## ele precisa ir até onde a plataforma começa a descer.
func estender_colunas_para_cima(ate_y: float) -> void:
	for copia in _copias:
		var topo := {}
		for celula in copia.get_used_cells():
			if not topo.has(celula.x) or celula.y < (topo[celula.x] as Vector2i).y:
				topo[celula.x] = celula
		var linha_alvo := copia.local_to_map(copia.to_local(Vector2(global_position.x, ate_y))).y
		for coluna in topo:
			var de: Vector2i = topo[coluna]
			for linha in range(linha_alvo, de.y):
				copia.set_cell(Vector2i(coluna, linha), copia.get_cell_source_id(de),
					copia.get_cell_atlas_coords(de), copia.get_cell_alternative_tile(de))


## Abaixo desta altura (y do mundo) nada do bloco aparece. INF desliga.
func cortar_abaixo_de(y: float) -> void:
	_material_do_bloco().set_shader_parameter(&"corte_y", y if is_finite(y) else 1.0e9)


## Acima desta altura (y do mundo) nada do bloco aparece. -INF desliga.
func cortar_acima_de(y: float) -> void:
	_material_do_bloco().set_shader_parameter(&"corte_acima_y", y if is_finite(y) else -1.0e9)


func corte_abaixo() -> float:
	return float(_material_do_bloco().get_shader_parameter(&"corte_y"))


func corte_acima() -> float:
	return float(_material_do_bloco().get_shader_parameter(&"corte_acima_y"))


## Quantas células o bloco tem, somando as camadas.
func celulas() -> int:
	var total := 0
	for copia in _copias:
		total += copia.get_used_cells().size()
	return total


## As cópias das camadas, uma por camada de origem.
func copias() -> Array[TileMapLayer]:
	return _copias


## Onde o retângulo "area", pintado no lugar de origem, está agora.
func area_agora(area: Rect2) -> Rect2:
	return Rect2(area.position + Vector2(0.0, deslocamento), area.size)


func _copia_de(camada: TileMapLayer) -> TileMapLayer:
	for copia in _copias:
		if copia.get_meta(&"origem", null) == camada:
			return copia
	var copia := TileMapLayer.new()
	copia.name = camada.name
	copia.set_meta(&"origem", camada)
	copia.tile_set = camada.tile_set
	copia.transform = global_transform.affine_inverse() * camada.global_transform
	copia.z_index = _z_no_mundo(camada) - _z_no_mundo(self)
	copia.modulate = camada.modulate
	copia.self_modulate = camada.self_modulate
	copia.light_mask = camada.light_mask
	copia.visibility_layer = camada.visibility_layer
	copia.texture_filter = camada.texture_filter
	copia.texture_repeat = camada.texture_repeat
	copia.rendering_quadrant_size = camada.rendering_quadrant_size
	copia.collision_enabled = false
	copia.navigation_enabled = false
	copia.material = _material_do_bloco()
	add_child(copia)
	_copias.append(copia)
	return copia


func _material_do_bloco() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER_DO_CORTE
	return _material


## O z_index de verdade, somando o dos pais enquanto ele for relativo.
static func _z_no_mundo(item: Node) -> int:
	var z := 0
	var no := item
	while no is CanvasItem:
		z += (no as CanvasItem).z_index
		if not (no as CanvasItem).z_as_relative:
			break
		no = no.get_parent()
	return z
