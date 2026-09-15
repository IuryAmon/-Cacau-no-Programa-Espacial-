extends ParallaxBackground

# Rola o cenário lunar para a esquerda o tempo todo, dando a sensação de que
# a nave está avançando.

@export var velocidade_rolagem: float = -1000.0


func _process(delta: float) -> void:
	scroll_offset.x += velocidade_rolagem * delta
