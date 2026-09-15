extends Area2D

var _disparado: bool = false

func _ready() -> void:
	# Voltando ao world1 pela passagem do laser ela já viu o foguete: a cena de
	# avistar não repete.
	_disparado = EstadoMundo.revelou_dr_chico
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _disparado:
		return
	if body.name != "Player":
		return
	_disparado = true
	if body.has_method("reagir_ao_avistar_foguete"):
		body.reagir_ao_avistar_foguete($CollisionShape2D)
