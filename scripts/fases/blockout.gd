class_name Blockout
extends RefCounted

# --- APOIO VISUAL DAS FASES ---
#
# Depois que as fases viraram cenas .tscn de verdade (editáveis no editor,
# com TileMapLayer e slots de sprite), este arquivo guarda só o que continua
# sendo útil em tempo de execução:
#
#   - o par Sprite2D + Placeholder, que deixa cada componente mostrar um
#     retângulo colorido enquanto a arte não chegou e sumir sozinho assim que
#     você arrasta uma textura para o slot;
#   - o aviso flutuante, usado como feedback de trava/coleta;
#   - alguns helpers de construção, usados pelo gerador de blockout
#     (tools/gerar_cenas_fases.gd) e por objetos criados em runtime.

const COR_CHAO := Color(0.32, 0.34, 0.38)
const COR_PAREDE := Color(0.24, 0.26, 0.30)
const COR_FUNDO := Color(0.15, 0.16, 0.19)
const COR_FUNDO_2 := Color(0.18, 0.19, 0.22)
const COR_PLACA := Color(0.85, 0.87, 0.90)
const COR_DESTAQUE := Color(0.95, 0.75, 0.25)


## O contrato de arte de todo componente: enquanto o Sprite2D estiver sem
## textura, o retângulo de blockout aparece; assim que você soltar um PNG no
## slot "Sprite" pelo editor, o retângulo some sozinho.
static func aplicar_arte(sprite: Sprite2D, placeholder: CanvasItem) -> void:
	if sprite == null or placeholder == null:
		return
	var tem_arte: bool = sprite.texture != null
	sprite.visible = tem_arte
	placeholder.visible = not tem_arte


## add_child() seguro em qualquer momento. Existem três situações e cada uma
## pede um caminho diferente:
##   1. pai fora da árvore (o gerador de blockout monta as cenas assim) —
##      add_child direto, e nenhum _ready() dispara;
##   2. pai na árvore mas ainda montando os filhos (dentro do _ready() de uma
##      fase) — a engine RECUSA add_child, então vai adiado;
##   3. jogo rodando normalmente — add_child direto.
## Sem isso, coisas criadas durante o _ready() de uma fase (as cascas da
## retorta, as células que voltam depois de uma morte) simplesmente não
## apareciam.
static func adicionar(pai: Node, no: Node) -> void:
	if pai.is_inside_tree() and not pai.is_node_ready():
		pai.add_child.call_deferred(no)
	else:
		pai.add_child(no)


## Aviso rápido que sobe e some acima de uma posição do mundo (feedback de
## trava, coleta, erro).
static func aviso_flutuante(pai: Node, pos: Vector2, texto: String, cor: Color = COR_DESTAQUE) -> void:
	if pai == null or not pai.is_inside_tree():
		return
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", cor)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size = Vector2(380, 80)
	lbl.position = pos - Vector2(190, 110)
	lbl.z_index = 50
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(lbl)

	var tween := pai.get_tree().create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 40.0, 1.8)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.8).set_ease(Tween.EASE_IN)
	tween.tween_callback(lbl.queue_free)


# --- HELPERS DE CONSTRUÇÃO (gerador de blockout e objetos de runtime) ---

## Retângulo sólido com colisão. O nó fica no CENTRO do retângulo pedido.
static func bloco(pai: Node, nome: String, rect: Rect2, cor: Color = COR_CHAO) -> StaticBody2D:
	var corpo := StaticBody2D.new()
	corpo.name = nome
	corpo.position = rect.get_center()
	pai.add_child(corpo)

	var forma := CollisionShape2D.new()
	forma.name = "Colisao"
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	forma.shape = shape
	corpo.add_child(forma)

	var visual := ColorRect.new()
	visual.name = "Visual"
	visual.color = cor
	visual.size = rect.size
	visual.position = -rect.size / 2.0
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corpo.add_child(visual)
	return corpo


## Retângulo só visual, sem colisão (fundos de sala, decoração).
static func fundo(pai: Node, nome: String, rect: Rect2, cor: Color = COR_FUNDO, z: int = -10) -> ColorRect:
	var visual := ColorRect.new()
	visual.name = nome
	visual.color = cor
	visual.position = rect.position
	visual.size = rect.size
	visual.z_index = z
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(visual)
	return visual


## Texto flutuante no mundo (dicas, nomes de sala).
static func placa(pai: Node, nome: String, centro: Vector2, texto: String, tamanho: int = 15, cor: Color = COR_PLACA) -> Label:
	var lbl := Label.new()
	lbl.name = nome
	lbl.text = texto
	lbl.add_theme_font_size_override("font_size", tamanho)
	lbl.add_theme_color_override("font_color", cor)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size = Vector2(420, 120)
	lbl.position = centro - lbl.size / 2.0
	lbl.z_index = -4
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(lbl)
	return lbl


## Area2D retangular pronta.
static func area_retangular(pai: Node, nome: String, tamanho: Vector2, pos_local: Vector2 = Vector2.ZERO) -> Area2D:
	var area := Area2D.new()
	area.name = nome
	area.position = pos_local
	forma_ret(area, tamanho)
	pai.add_child(area)
	return area


## CollisionShape2D retangular em um corpo/área já existente.
static func forma_ret(no: Node, tamanho: Vector2, pos_local: Vector2 = Vector2.ZERO, nome: String = "Colisao") -> CollisionShape2D:
	var forma := CollisionShape2D.new()
	forma.name = nome
	var shape := RectangleShape2D.new()
	shape.size = tamanho
	forma.shape = shape
	forma.position = pos_local
	no.add_child(forma)
	return forma


## Retângulo visual filho de um nó qualquer (ancorado pelo centro).
static func visual_ret(no: Node, tamanho: Vector2, cor: Color, pos_local: Vector2 = Vector2.ZERO, z: int = 0, nome: String = "Visual") -> ColorRect:
	var visual := ColorRect.new()
	visual.name = nome
	visual.color = cor
	visual.size = tamanho
	visual.position = pos_local - tamanho / 2.0
	visual.z_index = z
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	no.add_child(visual)
	return visual


## LightOccluder2D retangular: a parede que faz sombra no blecaute e corta o
## feixe da lanterna (o raycast do DetectorConeLuz corta a detecção do mesmo
## jeito — visual e lógica andam juntos).
static func oclusor_ret(pai: Node, tamanho: Vector2, pos_local: Vector2 = Vector2.ZERO, nome: String = "Oclusor") -> LightOccluder2D:
	var oclusor := LightOccluder2D.new()
	oclusor.name = nome
	oclusor.position = pos_local
	var poligono := OccluderPolygon2D.new()
	var meio := tamanho / 2.0
	poligono.polygon = PackedVector2Array([
		Vector2(-meio.x, -meio.y), Vector2(meio.x, -meio.y),
		Vector2(meio.x, meio.y), Vector2(-meio.x, meio.y),
	])
	oclusor.occluder = poligono
	pai.add_child(oclusor)
	return oclusor


## Luz radial pronta (sinalizador, setores do subsolo, estações).
static func luz_radial(cor: Color, escala: float, energia: float = 1.1) -> PointLight2D:
	var luz := PointLight2D.new()
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
	luz.texture = textura
	luz.color = cor
	luz.energy = energia
	luz.texture_scale = escala
	return luz
