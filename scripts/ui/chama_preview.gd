class_name ChamaPreview
extends Control

# --- A CHAMA DO MAÇARICO, DESENHADA AO VIVO ---
#
# O olho do puzzle da mistura: a proporção que o jogador escolhe nas válvulas
# vira forma e cor de chama na hora. Cada estado é uma chama real de maçarico:
#
#   apagada     -> só o bico; falta combustível, comburente, ou os dois
#   fuliginosa  -> H₂ demais: chama comprida, mole e amarelada, sobra sem queimar
#   oxidante    -> O₂ demais: chama curta, branca e sibilante, que oxida o metal
#   ideal       -> 2 H₂ : 1 O₂, o azul-vivo que corta solda
#
# Tudo em _draw(), sem sprite nenhum: mudar o desenho é mudar número aqui.

const ESTADOS := {
	"apagada":    {"altura": 0.0,  "largura": 0.0, "externa": Color(0, 0, 0, 0),
					"nucleo": Color(0, 0, 0, 0), "tremor": 0.0},
	"fuliginosa": {"altura": 1.05, "largura": 1.25, "externa": Color(1.0, 0.68, 0.22, 0.85),
					"nucleo": Color(1.0, 0.88, 0.55, 0.9), "tremor": 3.4},
	"oxidante":   {"altura": 0.62, "largura": 0.72, "externa": Color(0.82, 0.93, 1.0, 0.9),
					"nucleo": Color(1.0, 1.0, 1.0, 0.95), "tremor": 1.0},
	"ideal":      {"altura": 0.92, "largura": 0.95, "externa": Color(0.30, 0.60, 1.0, 0.9),
					"nucleo": Color(0.75, 0.92, 1.0, 0.95), "tremor": 1.6},
}

## Nome do estado atual (uma das chaves de ESTADOS).
var estado: String = "apagada":
	set(valor):
		if valor != estado:
			estado = valor
			queue_redraw()

var _t: float = 0.0
# A chama muda de tamanho suavemente entre um estado e outro, em vez de saltar.
var _altura: float = 0.0
var _largura: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	var ficha: Dictionary = ESTADOS[estado]
	_altura = lerpf(_altura, ficha["altura"], minf(delta * 7.0, 1.0))
	_largura = lerpf(_largura, ficha["largura"], minf(delta * 7.0, 1.0))
	queue_redraw()


func _draw() -> void:
	var base := Vector2(size.x * 0.5, size.y - 26.0)
	_desenhar_bico(base)

	var ficha: Dictionary = ESTADOS[estado]
	if _altura < 0.02:
		return

	var altura := (size.y - 70.0) * _altura
	var largura := 54.0 * _largura
	var tremor: float = ficha["tremor"]

	# Halo: a luz que a chama joga em volta, o que dá o "acesa" sem shader.
	var brilho: Color = ficha["externa"]
	draw_circle(base + Vector2(0, -altura * 0.42), altura * 0.44,
		Color(brilho.r, brilho.g, brilho.b, 0.07), true, -1.0, true)

	draw_colored_polygon(_forma(base, altura, largura, tremor, 0.0), ficha["externa"])
	draw_colored_polygon(_forma(base, altura * 0.52, largura * 0.5, tremor * 0.6, 2.1),
		ficha["nucleo"])


# O bico do maçarico, fixo: é dele que a chama sai.
func _desenhar_bico(base: Vector2) -> void:
	var corpo := PackedVector2Array([
		base + Vector2(-9, 0), base + Vector2(9, 0),
		base + Vector2(13, 26), base + Vector2(-13, 26),
	])
	draw_colored_polygon(corpo, Color(0.42, 0.45, 0.52))
	draw_line(base + Vector2(-9, 0), base + Vector2(9, 0), Color(0.62, 0.66, 0.74), 2.0, true)


# Perfil de gota: largo logo acima do bico e afinando até a ponta, com um
# tremor que sobe junto (embaixo a chama é firme, em cima ela dança).
func _forma(base: Vector2, altura: float, largura: float, tremor: float, semente: float) -> PackedVector2Array:
	const PASSOS := 20
	var direita := PackedVector2Array()
	var esquerda := PackedVector2Array()

	for i in PASSOS + 1:
		var t := float(i) / float(PASSOS)
		var meia := largura * 0.5 * sin(PI * pow(t, 0.62)) * (1.0 - 0.3 * t)
		var desvio := sin(_t * 8.0 + t * 5.5 + semente) * tremor * t
		var y := base.y - altura * t
		direita.append(Vector2(base.x + meia + desvio, y))
		esquerda.append(Vector2(base.x - meia + desvio, y))

	esquerda.reverse()
	direita.append_array(esquerda)
	return direita
