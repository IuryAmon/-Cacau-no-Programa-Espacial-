@tool
class_name ValvulaPurga
extends Area2D

# --- VÁLVULA DE PURGA DE N₂ (Torre de Gases) ---
#
# O uso real do nitrogênio em foguetes vira ferramenta de ritmo: encostar na
# válvula recarrega o dash da mochila em pleno ar.
#
# COMO EDITAR NO EDITOR:
#   Sprite -> PNG da válvula (o placeholder azul some sozinho)
#   Puff   -> partículas do sopro de N₂ ao recarregar

const CENA := "res://scenes/fases/componentes/valvula_purga.tscn"

@onready var _sprite: Sprite2D = $Sprite
@onready var _placeholder: ColorRect = $Placeholder
@onready var _puff: CPUParticles2D = $Puff


static func criar(pai: Node, nome: String, pos: Vector2, config: Dictionary = {}) -> ValvulaPurga:
	var valvula: ValvulaPurga = load(CENA).instantiate()
	valvula.name = nome
	valvula.position = pos
	for chave in config:
		valvula.set(chave, config[chave])
	Blockout.adicionar(pai, valvula)
	return valvula


func _ready() -> void:
	Blockout.aplicar_arte(_sprite, _placeholder)
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var ferramentas := body.get_node_or_null("Ferramentas")
	if ferramentas and ferramentas.has_method("resetar_dash"):
		if ferramentas.resetar_dash():
			_puff.emitting = true
