@tool
class_name SetaGo
extends Control

# --- A SETA "POR AQUI" (o "GO!" do Metal Slug) ---
#
# A placa que pisca na beirada da tela mandando seguir em frente: seta gorda
# amarela em degradê até o laranja, contorno preto grosso, um relevo laranja-
# escuro embaixo (dá o volume de letreiro de fliperama), brilho no alto e o
# "POR AQUI" em fonte de pixel ao lado. Pisca no ritmo do Metal Slug — acesa, apaga,
# acesa — e a cada piscada dá um empurrão na direção para onde aponta.
#
# Este nó só DESENHA. Onde a ponta fica e quando a seta aparece é decidido por
# quem a usa (a SetaGuia, scripts/fases/seta_guia.gd, que vive na fase). É um
# Control numa CanvasLayer, em coordenadas de TELA: desenhada no mundo, ela
# passaria pelo zoom da câmera e o texto sairia borrado.
#
# Some sozinha (sem perder o estado) com fala, ficha de item, puzzle ou jogo
# pausado na tela.

enum Direcao { DIREITA, ESQUERDA, CIMA, BAIXO }

const FONTE := preload("res://assets/fonts/BoldPixels.ttf")

# --- Forma (em pixels de tela, apontando para a direita, ponta na origem) ---
const PONTA_COMPRIMENTO := 40.0
const PONTA_ALTURA := 68.0
const HASTE_COMPRIMENTO := 46.0
const HASTE_ESPESSURA := 30.0
const CONTORNO := 5.0
## Espessura do relevo embaixo da seta e do texto.
const RELEVO := 4.0
## Folga entre a ponta desenhada e o ponto que ela indica.
const FOLGA_DA_PONTA := 6.0

# --- Cores ---
const AMARELO := Color(1.0, 0.93, 0.32)
const LARANJA := Color(1.0, 0.52, 0.08)
const COR_RELEVO := Color(0.62, 0.18, 0.03)
const BRILHO := Color(1.0, 1.0, 0.92)
const PRETO := Color(0.0, 0.0, 0.0)

# --- Texto ---
const TAM_TEXTO := 34
const CONTORNO_TEXTO := 10
const DISTANCIA_TEXTO := 14.0

# --- Ritmo ---
## Uma piscada inteira: acesa por ACESA segundos, apagada pelo resto.
const CICLO := 0.62
const ACESA := 0.44
## Quanto a seta avança na direção dela a cada piscada.
const EMPURRAO := 11.0
const T_SURGIR := 0.28
const T_SUMIR := 0.18

var direcao: int = Direcao.DIREITA:
	set(valor):
		direcao = valor
		queue_redraw()
var texto: String = "POR AQUI"
## O ponto (na tela) que a seta indica. A ponta fica logo antes dele.
var ponta: Vector2 = Vector2.ZERO
var escala: float = 1.0

var _pedida: bool = false
var _surgir: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Precisa rodar com o jogo pausado para conseguir sumir quando uma ficha
	# de item pausa tudo.
	process_mode = Node.PROCESS_MODE_ALWAYS


func mostrar() -> void:
	if not _pedida:
		_pedida = true
		# Sempre nasce acesa, no começo de uma piscada.
		if _surgir <= 0.0:
			_t = 0.0


func esconder() -> void:
	_pedida = false


func mostrando() -> bool:
	return _pedida


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var livre := not get_tree().paused and not Interacao.ocupada()
	var alvo := 1.0 if (_pedida and livre) else 0.0
	var tempo := T_SURGIR if alvo > _surgir else T_SUMIR
	_surgir = move_toward(_surgir, alvo, delta / tempo)
	if _surgir > 0.0:
		_t += delta
	queue_redraw()


# ─────────────────────────────────────────────
#  Desenho
# ─────────────────────────────────────────────

func _draw() -> void:
	if _surgir <= 0.0:
		return

	var fase := fmod(_t, CICLO)
	# Pisca de verdade (apaga inteira), com um fio de transição para não serrilhar.
	var acesa := clampf((ACESA - fase) / 0.05, 0.0, 1.0) * clampf(fase / 0.03, 0.0, 1.0)
	if _t < T_SURGIR:
		acesa = 1.0  # a entrada não pisca
	var alfa := acesa * clampf(_surgir * 1.6, 0.0, 1.0)
	if alfa <= 0.0:
		return

	var empurrao := EMPURRAO * sin(clampf(fase / ACESA, 0.0, 1.0) * PI)
	var tamanho := escala * _quique(_surgir)
	var sentido := vetor(direcao)
	var origem := ponta - sentido * (FOLGA_DA_PONTA - empurrao)
	var forma := Transform2D(angulo(direcao), Vector2(tamanho, tamanho), 0.0, origem) * contorno_seta()

	_desenhar_seta(forma, tamanho, alfa)
	_desenhar_texto(forma, tamanho, alfa)


func _desenhar_seta(forma: PackedVector2Array, tamanho: float, alfa: float) -> void:
	var relevo := Vector2(0.0, RELEVO * tamanho)
	var embaixo := _deslocar(forma, relevo)

	# Contorno preto envolvendo a seta e o relevo.
	for p in [embaixo, forma]:
		for inflado in Geometry2D.offset_polygon(p, CONTORNO * tamanho, Geometry2D.JOIN_MITER):
			draw_colored_polygon(inflado, _com_alfa(PRETO, alfa))
	draw_colored_polygon(embaixo, _com_alfa(COR_RELEVO, alfa))

	# Degradê de cima para baixo NA TELA, seja qual for a direção.
	var topo := INF
	var base := -INF
	for p in forma:
		topo = minf(topo, p.y)
		base = maxf(base, p.y)
	var cores := PackedColorArray()
	for p in forma:
		var k := inverse_lerp(topo, base, p.y) if base > topo else 0.0
		cores.append(_com_alfa(AMARELO.lerp(LARANJA, k), alfa))
	draw_polygon(forma, cores)

	# Brilho: a mesma forma encolhida, forte no alto e sumindo para baixo.
	for miolo in Geometry2D.offset_polygon(forma, -5.0 * tamanho, Geometry2D.JOIN_MITER):
		var brilhos := PackedColorArray()
		for p in miolo:
			var k := inverse_lerp(topo, base, p.y) if base > topo else 1.0
			brilhos.append(_com_alfa(BRILHO, alfa * 0.55 * clampf(1.0 - k * 1.8, 0.0, 1.0)))
		draw_polygon(miolo, brilhos)


func _desenhar_texto(forma: PackedVector2Array, tamanho: float, alfa: float) -> void:
	if texto.is_empty():
		return
	var caixa := Rect2(forma[0], Vector2.ZERO)
	for p in forma:
		caixa = caixa.expand(p)

	var tam := int(round(TAM_TEXTO * tamanho))
	var largura := FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var ascendente := FONTE.get_ascent(tam)
	var pos: Vector2
	if direcao == Direcao.DIREITA or direcao == Direcao.ESQUERDA:
		# Em cima da seta, centrado nela.
		pos = Vector2(caixa.get_center().x - largura * 0.5,
			caixa.position.y - DISTANCIA_TEXTO * tamanho)
	else:
		# Ao lado da seta, na altura da cauda.
		var y_cauda := caixa.position.y + ascendente * 0.9 if direcao == Direcao.BAIXO \
			else caixa.end.y - ascendente * 0.1
		pos = Vector2(caixa.position.x - DISTANCIA_TEXTO * tamanho - largura, y_cauda)
	# "POR AQUI" é mais largo que a seta: com ela grudada na borda da tela, o
	# texto não pode sair pela beirada.
	var contorno := int(round(CONTORNO_TEXTO * tamanho))
	if size.x > largura + contorno * 2.0:
		pos.x = clampf(pos.x, contorno, size.x - largura - contorno)
	pos = pos.round()

	var relevo := Vector2(0.0, RELEVO * tamanho).round()
	for p in [pos + relevo, pos]:
		draw_string_outline(FONTE, p, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, contorno,
			_com_alfa(PRETO, alfa))
	draw_string(FONTE, pos + relevo, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, _com_alfa(COR_RELEVO, alfa))
	draw_string(FONTE, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, _com_alfa(AMARELO, alfa))


# ─────────────────────────────────────────────
#  Forma e direção (também usadas pela prévia da SetaGuia no editor)
# ─────────────────────────────────────────────

## A seta apontando para a direita, com a ponta em (0, 0).
static func contorno_seta() -> PackedVector2Array:
	var cp := PONTA_COMPRIMENTO
	var ap := PONTA_ALTURA * 0.5
	var ch := HASTE_COMPRIMENTO
	var eh := HASTE_ESPESSURA * 0.5
	return PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(-cp, -ap),
		Vector2(-cp, -eh),
		Vector2(-cp - ch, -eh),
		Vector2(-cp - ch, eh),
		Vector2(-cp, eh),
		Vector2(-cp, ap),
	])


## Comprimento total da seta, da cauda à ponta.
static func comprimento() -> float:
	return PONTA_COMPRIMENTO + HASTE_COMPRIMENTO


static func angulo(dir: int) -> float:
	match dir:
		Direcao.ESQUERDA:
			return PI
		Direcao.CIMA:
			return -PI * 0.5
		Direcao.BAIXO:
			return PI * 0.5
	return 0.0


static func vetor(dir: int) -> Vector2:
	return Vector2.RIGHT.rotated(angulo(dir)).round()


# ─────────────────────────────────────────────
#  Auxiliares
# ─────────────────────────────────────────────

## Entra passando um pouco do tamanho e volta (o "pop" de placa de fliperama).
func _quique(p: float) -> float:
	if p >= 1.0:
		return 1.0
	var c := 2.2
	var q := p - 1.0
	return maxf(0.0, 1.0 + (c + 1.0) * q * q * q + c * q * q)


func _deslocar(pontos: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var saida := PackedVector2Array()
	for p in pontos:
		saida.append(p + d)
	return saida


func _com_alfa(cor: Color, alfa: float) -> Color:
	return Color(cor.r, cor.g, cor.b, cor.a * alfa)
