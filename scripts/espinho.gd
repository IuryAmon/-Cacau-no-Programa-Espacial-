extends Area2D

var _corpos_dentro: Array = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		_corpos_dentro.append(body)

func _on_body_exited(body: Node2D) -> void:
	_corpos_dentro.erase(body)

func _physics_process(_delta: float) -> void:
	for body in _corpos_dentro:
		if is_instance_valid(body):
			body.take_damage(1, Vector2(0, -1))
