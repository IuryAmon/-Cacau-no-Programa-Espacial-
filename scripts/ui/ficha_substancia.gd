@tool
class_name FichaSubstancia
extends Control

# --- A FICHA DE UMA SUBSTÂNCIA DO AR (ao lado da coluna de destilação) ---
#
# Uma ficha do caderno (a mesma peça do HUD, EstiloHUD.ficha) para cada coisa
# de que o ar é feito: o desenho da molécula, a fórmula, o nome e quanto dela
# há no ar. As três juntas são a LEGENDA do desenho animado da coluna
# (coluna_destilacao.gd): a molécula grande daqui é a pequena que anda lá
# dentro, na mesma cor. Elas não saem do lugar.
#
# Pendurada do lado direito vai a PLAQUINHA DO PONTO DE EBULIÇÃO, igual às de
# temperatura da coluna e na cor do líquido da substância. Ela só aparece
# quando a explicação chega nesse assunto (ebulicao_a_vista) e dá um pulo
# quando a primeira molécula da substância evapora do fundo fervendo (pulsar)
# — o que, numa mistura, acontece abaixo desse número: o oxigênio começa a
# evaporar a uns -194 °C, junto com o nitrogênio.
#
# COMO EDITAR NO EDITOR:
#   substancia    "N2", "O2" ou "Ar". Dela saem o desenho (FolhaMoleculas), a
#                 fórmula escrita (os números descem, como em N₂) e o ponto de
#                 ebulição — o número de ColunaDestilacao.SUBSTANCIAS. Quanto
#                 ela evapora em cada temperatura, a coluna tira da pressão de
#                 vapor dela (MisturasDoDestilador), que dá esse mesmo ponto.
#   nome          o que vai escrito embaixo da fórmula.
#   parte_do_ar   o número grande da direita ("78%").
#   posição do nó onde a ficha fica. As três estão na ordem dos andares da
#                 coluna: a que ferve na temperatura mais fria em cima.

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

const TAMANHO := Vector2(292, 100)
## Do lado esquerdo da ficha até o meio do desenho da molécula.
const MEIO_DO_DESENHO := 56.0
## Onde começa o texto.
const X_DO_TEXTO := 110.0
const MARGEM := 16.0
## Do lado direito da ficha até a plaquinha do ponto de ebulição.
const DISTANCIA_DA_PLAQUINHA := 10.0
## Quanto dura o pulo da plaquinha.
const DURACAO_DO_PULO := 0.5

@export var substancia: String = "N2":
	set(valor):
		substancia = valor
		queue_redraw()
@export var nome: String = "NITROGÊNIO":
	set(valor):
		nome = valor
		queue_redraw()
@export var parte_do_ar: String = "78%":
	set(valor):
		parte_do_ar = valor
		queue_redraw()

## 0..1: quanto da plaquinha do ponto de ebulição já apareceu.
var ebulicao_a_vista: float = 0.0:
	set(valor):
		ebulicao_a_vista = clampf(valor, 0.0, 1.0)
		queue_redraw()

## 1 logo depois de pulsar(); volta a 0 sozinho.
var _pulo: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = TAMANHO
	size = TAMANHO
	set_process(false)
	if Engine.is_editor_hint():
		# No editor a plaquinha fica à mostra, para dar para posicionar.
		ebulicao_a_vista = 1.0


func _process(delta: float) -> void:
	_pulo = move_toward(_pulo, 0.0, delta / DURACAO_DO_PULO)
	if _pulo <= 0.0:
		set_process(false)
	queue_redraw()


## A plaquinha do ponto de ebulição dá um pulo: a substância começou a ferver.
func pulsar() -> void:
	_pulo = 1.0
	set_process(true)
	queue_redraw()


## True enquanto o pulo da plaquinha não acabou.
func pulsando() -> bool:
	return _pulo > 0.0


## O ponto de ebulição escrito ("-196 °C").
func texto_da_ebulicao() -> String:
	if not ColunaDestilacao.SUBSTANCIAS.has(substancia):
		return ""
	return "%d °C" % int(ColunaDestilacao.SUBSTANCIAS[substancia]["ebulicao"])


## A cor do líquido da substância: a da plaquinha.
func cor() -> Color:
	if not ColunaDestilacao.SUBSTANCIAS.has(substancia):
		return EstiloHUD.PAPEL
	return ColunaDestilacao.SUBSTANCIAS[substancia]["tona"]


## O retângulo da plaquinha do ponto de ebulição, nas medidas deste nó.
func retangulo_da_plaquinha() -> Rect2:
	return ColunaDestilacao.retangulo_da_plaquinha(_lugar_da_plaquinha(), texto_da_ebulicao())


## O meio do lado direito da plaquinha: ela fica logo depois da ficha.
func _lugar_da_plaquinha() -> Vector2:
	var largura := ColunaDestilacao.retangulo_da_plaquinha(Vector2.ZERO, texto_da_ebulicao()).size.x
	return Vector2(size.x + DISTANCIA_DA_PLAQUINHA + largura, roundf(size.y * 0.5))


func _draw() -> void:
	EstiloHUD.ficha(self, Rect2(Vector2.ZERO, size))

	# O desenho da molécula, no tamanho em que foi desenhado.
	var arte := FolhaMoleculas.textura(substancia)
	if arte != null:
		var medida := Vector2(arte.get_size())
		draw_texture_rect(arte, Rect2((Vector2(MEIO_DO_DESENHO, size.y * 0.5 - 2.0) - medida * 0.5).round(),
			medida), false)

	_escrever_formula(Vector2(X_DO_TEXTO, 52.0))
	draw_string(FONTE, Vector2(X_DO_TEXTO, 74.0), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		EstiloHUD.TINTA_FRACA)

	# Quanto dela há no ar, à direita.
	var largura := FONTE.get_string_size(parte_do_ar, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(FONTE, Vector2(size.x - MARGEM - largura, 48.0), parte_do_ar,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, EstiloHUD.TINTA)
	var legenda := "DO AR"
	largura = FONTE.get_string_size(legenda, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(FONTE, Vector2(size.x - MARGEM - largura, 66.0), legenda,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, EstiloHUD.TINTA_FRACA)

	if ebulicao_a_vista > 0.004:
		# Incha um pouco ao aparecer e bastante no pulo de quando ferve.
		var inchada := sin(ebulicao_a_vista * PI) * 4.0 + sin(_pulo * PI) * 7.0
		ColunaDestilacao.plaquinha(self, _lugar_da_plaquinha(), texto_da_ebulicao(), cor(),
			ebulicao_a_vista, inchada)


## A fórmula com os números descidos (N₂): a letra no tamanho 33 e o número no
## 22, mais baixo. A fonte não tem o "₂" desenhado.
func _escrever_formula(base: Vector2) -> void:
	var x := base.x
	for i in substancia.length():
		var letra := substancia[i]
		var numero := letra.is_valid_int()
		var tamanho := 22 if numero else 33
		draw_string(FONTE, Vector2(x, base.y + (8.0 if numero else 0.0)), letra,
			HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, EstiloHUD.TINTA)
		x += FONTE.get_string_size(letra, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x + 1.0
