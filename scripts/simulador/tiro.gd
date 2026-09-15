extends Area2D

# Tiro da nave do simulador. Sobe a tela da esquerda para a direita e explode
# ao encostar em qualquer coisa (a molécula só é destruída se for do tipo certo
# — quem decide isso é o script do meteoro).

@export var velocidade: float = 600.0

var _explodiu: bool = false

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_anim.play("default")
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	if _explodiu:
		return

	position.x += velocidade * delta

	if position.x > get_viewport_rect().size.x + 200.0:
		queue_free()


func _on_area_entered(_area: Area2D) -> void:
	explodir()


func explodir() -> void:
	if _explodiu:
		return
	_explodiu = true

	$CollisionShape2D.set_deferred("disabled", true)
	_anim.play("explosion")
	await _anim.animation_finished
	queue_free()
