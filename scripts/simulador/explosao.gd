extends Node2D

# Explosão de uma molécula neutralizada: dispara as partículas e o som e se
# apaga sozinha quando a emissão acaba (no original o nó ficava para sempre na
# cena, acumulando).

@onready var _particulas: CPUParticles2D = $CPUParticles2D
@onready var _som: AudioStreamPlayer2D = $CPUParticles2D/SomExplosao


func _ready() -> void:
	_particulas.emitting = true
	_som.play()

	var duracao: float = maxf(_particulas.lifetime, 1.0) + 0.5
	await get_tree().create_timer(duracao).timeout
	queue_free()
