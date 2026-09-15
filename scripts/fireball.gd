extends Area2D

var velocidade: float = 280.0
var direcao: float = 1.0
var explodindo: bool = false
var tempo_vivo: float = 0.0

@onready var sprite = $AnimatedSprite2D
@onready var colisao = $CollisionShape2D
@onready var raycast = $RayCast2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	sprite.animation_finished.connect(_on_animacao_terminou)
	# Sprite do fireball olha pra ESQUERDA por padrão
	sprite.flip_h = direcao > 0
	sprite.play("voando")
	# Aponta o raycast na direção do movimento
	raycast.target_position = Vector2(24.0 * direcao, 0)
	get_tree().create_timer(6.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	tempo_vivo += delta
	if explodindo:
		return

	position.x += velocidade * direcao * delta

	# RayCast detecta paredes com mais confiança que body_entered para TileMap
	if tempo_vivo > 0.1 and raycast.is_colliding():
		var colisor = raycast.get_collider()
		if colisor != null and not colisor.is_in_group("microwave"):
			if colisor.has_method("take_damage"):
				colisor.take_damage(1, Vector2(direcao, -0.4).normalized())
			_explodir()

func _on_body_entered(body: Node) -> void:
	if explodindo or tempo_vivo < 0.1 or body.is_in_group("microwave"):
		return
	if body.has_method("take_damage"):
		body.take_damage(1, Vector2(direcao, -0.4).normalized())
	_explodir()

func _explodir() -> void:
	explodindo = true
	set_deferred("monitoring", false)
	colisao.set_deferred("disabled", true)
	raycast.enabled = false
	sprite.flip_h = false
	sprite.play("explosao")

func _on_animacao_terminou() -> void:
	if sprite.animation == "explosao":
		queue_free()
