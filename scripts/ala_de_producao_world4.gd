extends Node2D

# Ajusta os limites da câmera do Player em runtime, em vez de depender de um
# override de propriedade no .tscn (que o editor do Godot costuma descartar
# toda vez que o TileMap é editado e a cena é resalva).

@onready var camera: Camera2D = $Player/Camera2D


func _ready() -> void:
	camera.limit_left = -10000000
	camera.limit_bottom = -30

	# Quem visitou a ala de produção de lítio resolve a checagem final do
	# purificador de CO₂ (2LiOH + CO₂ -> Li₂CO₃ + H₂O) com vantagem.
	Progresso.visitou_ala_litio = true
