@tool
class_name BlocoAlternavel
extends StaticBody2D

# --- BLOCO QUE LIGA E DESLIGA ---
#
# Toda parte do cenário que aparece ou some por causa de um interruptor:
# a porta temporizada e a grade dupla da oficina, a plataforma atrás do
# vidro, a porta do armário da mochila, as esteiras da linha de borracha,
# as lanças dos guindastes e o portão do lançamento.
#
# COMO EDITAR NO EDITOR:
#   Sprite  -> PNG do bloco (o placeholder colorido some sozinho)
#   tamanho -> redimensiona colisão e placeholder
#   solido  -> estado inicial (ligado = existe e barra o caminho)

const CENA := "res://scenes/fases/componentes/bloco_alternavel.tscn"

@export var tamanho: Vector2 = Vector2(120, 20):
	set(valor):
		tamanho = valor
		if is_inside_tree():
			_aplicar_tamanho()
@export var cor: Color = Color(0.55, 0.35, 0.3):
	set(valor):
		cor = valor
		if is_inside_tree():
			_aplicar_cor()
@export var solido: bool = true:
	set(valor):
		solido = valor
		if is_inside_tree():
			_aplicar_estado()

@onready var _sprite: Sprite2D = $Sprite
@onready var _placeholder: ColorRect = $Placeholder
@onready var _colisao: CollisionShape2D = $Colisao


static func criar(pai: Node, nome: String, rect: Rect2, config: Dictionary = {}) -> BlocoAlternavel:
	var bloco: BlocoAlternavel = load(CENA).instantiate()
	bloco.name = nome
	bloco.position = rect.get_center()
	bloco.tamanho = rect.size
	for chave in config:
		bloco.set(chave, config[chave])
	Blockout.adicionar(pai, bloco)
	return bloco


func _ready() -> void:
	_aplicar_tamanho()
	_aplicar_cor()
	Blockout.aplicar_arte(_sprite, _placeholder)
	_aplicar_estado()


func _aplicar_tamanho() -> void:
	if _colisao and _colisao.shape is RectangleShape2D:
		(_colisao.shape as RectangleShape2D).size = tamanho
	if _placeholder:
		_placeholder.size = tamanho
		_placeholder.position = -tamanho / 2.0


func _aplicar_cor() -> void:
	if _placeholder:
		_placeholder.color = cor


func _aplicar_estado() -> void:
	visible = solido
	if _colisao:
		_colisao.set_deferred("disabled", not solido)


## Liga/desliga o bloco inteiro (visual + colisão).
func definir_solido(valor: bool) -> void:
	solido = valor
