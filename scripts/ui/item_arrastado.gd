class_name ItemArrastado
extends Control

# --- O ITEM NA MÃO (arrastado para fora da mochila) ---
#
# Quando a pessoa pega um item da mochila num puzzle de arrastar, o desenho
# sai do alvéolo e passa a ser este nó: o ícone, maior que no alvéolo (está
# "na mão", mais perto de quem olha), com o halo da cor do item e uma sombra
# caída — a sombra é o que dá a sensação de que ele foi erguido da fileira.
#
# A posição do nó É o centro do ícone. Quem arrasta só move "position"; quem
# anima a entrega ou a volta usa "position", "scale" e "modulate" em tween.

var textura: Texture2D = null
var cor: Color = EstiloHUD.ACENTO_PADRAO
## Caixa em que o ícone é encaixado (mesma regra de pixel art da mochila).
var caixa: float = 72.0

var _tempo: float = 0.0


static func criar(pai: Node, arte: Texture2D, tinta: Color, centro: Vector2,
		tamanho: float = 72.0) -> ItemArrastado:
	var item := ItemArrastado.new()
	item.name = "ItemArrastado"
	item.textura = arte
	item.cor = tinta
	item.caixa = tamanho
	item.position = centro
	pai.add_child(item)
	return item


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Os puzzles pausam a árvore; a mão continua viva.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_tempo += delta
	queue_redraw()


func _draw() -> void:
	if textura == null:
		return
	# Halo respirando devagar: o item está "ativo", esperando lugar para cair.
	EstiloHUD.halo(self, Vector2.ZERO, caixa * 0.8, cor, 7, 0.85 + 0.15 * sin(_tempo * 6.0))
	EstiloHUD.icone(self, textura, Vector2(caixa * 0.10, caixa * 0.16), caixa,
		Color(0.0, 0.0, 0.0, 0.35))
	EstiloHUD.icone(self, textura, Vector2.ZERO, caixa)
