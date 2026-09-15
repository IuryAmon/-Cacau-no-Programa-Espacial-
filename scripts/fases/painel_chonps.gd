@tool
class_name PainelChonps
extends Node2D

# --- PAINEL DO CHONPS ---
#
# O centro visual do hub: seis células, uma por elemento da vida, acesas
# conforme o Progresso entrega.
#
# COMO EDITAR NO EDITOR: o painel tem um nó por elemento (SlotC, SlotH, ...),
# cada um com seu próprio Sprite2D. Solte a arte de cada símbolo no Sprite do
# slot correspondente; o placeholder colorido some sozinho. O apagado/aceso é
# feito por transparência, então uma arte só já funciona.

const CENA := "res://scenes/fases/componentes/painel_chonps.tscn"

var _slots: Dictionary = {}


static func criar(pai: Node, pos: Vector2) -> PainelChonps:
	var painel: PainelChonps = load(CENA).instantiate()
	painel.name = "PainelChonps"
	painel.position = pos
	Blockout.adicionar(pai, painel)
	return painel


func _ready() -> void:
	for letra in Progresso.CELULAS:
		var slot := get_node_or_null("Slot" + letra)
		if slot == null:
			continue
		var sprite: Sprite2D = slot.get_node_or_null("Sprite")
		var placeholder: ColorRect = slot.get_node_or_null("Placeholder")
		Blockout.aplicar_arte(sprite, placeholder)
		# A "luz" é o que fica transparente quando o elemento não foi
		# conquistado: a arte, se houver, ou o miolo do placeholder.
		_slots[letra] = sprite if sprite and sprite.texture else slot.get_node_or_null("Placeholder/Miolo")

	if Engine.is_editor_hint():
		return

	_atualizar()
	Progresso.celula_entregue.connect(_on_celula_entregue)


func _atualizar() -> void:
	for letra in _slots:
		var luz: CanvasItem = _slots[letra]
		if luz:
			luz.modulate.a = 1.0 if Progresso.tem_celula(letra) else 0.12


func _on_celula_entregue(letra: String) -> void:
	_atualizar()
	var luz: CanvasItem = _slots.get(letra)
	if luz == null:
		return
	var tween := create_tween()
	tween.set_loops(3)
	tween.tween_property(luz, "modulate:a", 0.3, 0.15)
	tween.tween_property(luz, "modulate:a", 1.0, 0.25)
