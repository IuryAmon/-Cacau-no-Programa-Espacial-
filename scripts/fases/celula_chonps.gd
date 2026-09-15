@tool
class_name CelulaChonps
extends Area2D

# --- CÉLULA DO PAINEL CHONPS ---
#
# A recompensa química de cada fase. Encostar entrega a célula ao Progresso —
# o painel do laboratório acende o símbolo na próxima visita.
#
# COMO EDITAR NO EDITOR:
#   Sprite -> PNG da célula (o placeholder colorido some sozinho)
#   letra  -> C, H, O, N, P ou S (define a cor do placeholder)

const CENA := "res://scenes/fases/componentes/celula_chonps.tscn"

const CORES := {
	"C": Color(0.35, 0.35, 0.38),
	"H": Color(0.90, 0.35, 0.35),
	"O": Color(0.35, 0.65, 0.95),
	"N": Color(0.40, 0.80, 0.45),
	"P": Color(0.95, 0.65, 0.25),
	"S": Color(0.95, 0.85, 0.30),
}

@export_enum("C", "H", "O", "N", "P", "S") var letra: String = "C":
	set(valor):
		letra = valor
		if is_inside_tree():
			_aplicar_letra()

@onready var _sprite: Sprite2D = $Sprite
@onready var _placeholder: ColorRect = $Placeholder
@onready var _miolo: ColorRect = $Placeholder/Miolo
@onready var _label: Label = $Letra


static func criar(pai: Node, pos: Vector2, letra_celula: String) -> CelulaChonps:
	var celula: CelulaChonps = load(CENA).instantiate()
	celula.name = "Celula" + letra_celula
	celula.position = pos
	celula.letra = letra_celula
	Blockout.adicionar(pai, celula)
	return celula


func _ready() -> void:
	_aplicar_letra()
	Blockout.aplicar_arte(_sprite, _placeholder)
	if Engine.is_editor_hint():
		return

	# Já entregue nesta sessão: não volta para o cenário.
	if Progresso.tem_celula(letra):
		queue_free()
		return

	body_entered.connect(_on_body_entered)

	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:y", position.y - 10.0, 0.9)
	tween.tween_property(self, "position:y", position.y, 0.9)


func _aplicar_letra() -> void:
	var cor: Color = CORES.get(letra, Color.WHITE)
	if _placeholder:
		_placeholder.color = cor.darkened(0.3)
	if _miolo:
		_miolo.color = cor
	if _label:
		_label.text = letra


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	set_deferred("monitoring", false)
	Progresso.dar_celula(letra)
	Blockout.aviso_flutuante(get_parent(), global_position,
		"CÉLULA %s CONQUISTADA!\nO painel CHONPS acendeu mais um símbolo." % letra,
		Color(0.5, 1.0, 0.6))
	queue_free()
