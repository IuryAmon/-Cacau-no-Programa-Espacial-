extends Area2D

# Molécula flutuando no simulador (as "meteoro" do shoot'em up original).
#
# Cada uma só é neutralizada pelo tiro do tipo oposto:
#   ácida  (HCl)  -> só morre com o tiro azul  (OH⁻, base)
#   básica (NaOH) -> só morre com o tiro verde (H⁺, ácido)
# Qual é qual vem do export abaixo, então o mesmo script serve para as duas.

## Grupo do tiro capaz de neutralizar esta molécula.
@export var tiro_que_neutraliza: StringName = &"blue_bullet"
@export var base_speed: float = 35.0
@export var dano: int = 30
@export var pontos: int = 20
@export var explosao_cena: PackedScene

var velocidade := Vector2.ZERO
var _giro := 0.0
var _morrendo := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	scale = Vector2.ONE * randf_range(0.6, 1.6)

	# Entra sempre indo para a esquerda, com uma diagonal para cima ou para baixo.
	var direcao_y := 1.0 if randf() > 0.5 else -1.0
	velocidade = Vector2(-base_speed, base_speed * 0.7 * direcao_y)
	_giro = randf_range(-1.5, 1.5)


func _process(delta: float) -> void:
	if _morrendo:
		return

	position += velocidade * delta
	rotation += _giro * delta

	# Ricocheteia nas bordas da tela em vez de sumir.
	var tela := get_viewport_rect().size
	if (position.x >= tela.x and velocidade.x > 0.0) or (position.x <= 0.0 and velocidade.x < 0.0):
		velocidade.x *= -1.0
	if (position.y >= tela.y and velocidade.y > 0.0) or (position.y <= 0.0 and velocidade.y < 0.0):
		velocidade.y *= -1.0


func _on_body_entered(corpo: Node2D) -> void:
	if _morrendo:
		return
	if corpo.is_in_group("player") and corpo.has_method("take_damage"):
		corpo.take_damage(dano, global_position)
		neutralizar(false)


func _on_area_entered(area: Area2D) -> void:
	if _morrendo:
		return
	if area.is_in_group(tiro_que_neutraliza):
		neutralizar(true)


func neutralizar(dar_pontos: bool) -> void:
	if _morrendo:
		return
	_morrendo = true

	velocidade = Vector2.ZERO
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	if dar_pontos:
		var nave := get_tree().get_first_node_in_group("player")
		if nave and nave.has_method("add_score"):
			nave.add_score(pontos)

	if explosao_cena:
		var explosao := explosao_cena.instantiate()
		get_parent().add_child(explosao)
		explosao.global_position = global_position

	queue_free()
