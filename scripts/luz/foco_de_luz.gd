@tool
class_name FocoDeLuz
extends Marker2D
## Um foco de luz artificial sobre a arte do fundo: o ponto onde um holofote, uma
## janela ou um farol clareia o desenho de noite.
##
## Sozinho não faz nada — é filho de uma [ArteIluminada], que junta os focos e
## desenha a arte acesa dentro deles. Arraste o nó para onde a luz bate; o
## círculo que aparece no editor é o alcance.

## Alcance da luz, em pixels da arte.
@export_range(4.0, 800.0, 1.0) var raio := 80.0:
	set(v):
		raio = v
		queue_redraw()
@export var cor := Color(1.0, 0.96, 0.86):
	set(v):
		cor = v
		queue_redraw()
## Força no centro (acima de 1 alarga o miolo totalmente aceso).
@export_range(0.0, 2.0, 0.01) var forca := 1.0
## Piscadas por segundo, para farol e alarme (0 = luz firme).
@export_range(0.0, 10.0, 0.05) var piscar := 0.0
## Fração de cada ciclo em que o farol fica aceso.
@export_range(0.05, 1.0, 0.01) var fatia_acesa := 0.3


## Força neste instante, já com a piscada.
func forca_agora(relogio: float) -> float:
	if piscar > 0.0 and fposmod(relogio * piscar, 1.0) > fatia_acesa:
		return 0.0
	return forca


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_arc(Vector2.ZERO, raio, 0.0, TAU, 48, Color(cor.r, cor.g, cor.b, 0.7), 1.0)
