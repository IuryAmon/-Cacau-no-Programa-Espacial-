class_name GuinchoPreview
extends Control

# --- O GUINCHO DA PLATAFORMA, DESENHADO AO VIVO ---
#
# O olho do puzzle do elevador, no mesmo espírito da ChamaPreview do maçarico:
# a regulagem do terminal vira desenho na hora, porque o desenho é que ensina.
#
# UMA SETA SÓ, E ELA É A DO JOGADOR. O peso da Cacau NÃO é desenhado como
# seta — ela aparece como o corpo dela em cima da plataforma, e mais nada. Se
# as duas setas estivessem lado a lado bastaria igualar os tamanhos no olho e
# o puzzle deixaria de pedir a conta. Do jeito que está, a única forma de
# saber se a força serve é ACIONAR e ver o que acontece:
#
#   fraca  -> o cabo estica, a plataforma treme e não sai do chão
#   certa  -> ela sobe firme até o topo
#   forte  -> ela arranca, bate na viga e balança
#
# É a mesma gramática do maçarico (chama fuliginosa / oxidante / ideal): o
# erro tem cara própria, e a cara diz para que lado corrigir.

## Força regulada no terminal, em newtons. Só muda o tamanho da seta.
var forca: float = 0.0:
	set(valor):
		if not is_equal_approx(valor, forca):
			forca = valor
			queue_redraw()

## Força que a seta cheia representa — o topo da escala do desenho.
var forca_maxima: float = 900.0

## Como está a plataforma agora: "parada" (ninguém acionou ainda), "fraca",
## "certa" ou "forte".
var resultado: String = "parada":
	set(valor):
		if valor != resultado:
			resultado = valor
			_tempo_resultado = 0.0
			queue_redraw()

const COR_VIGA := Color(0.28, 0.30, 0.36)
const COR_ACO := Color(0.55, 0.59, 0.68)
const COR_ACO_ESCURO := Color(0.34, 0.37, 0.44)
const COR_CABO := Color(0.72, 0.76, 0.84)
const COR_CHAO := Color(0.24, 0.26, 0.31)
const COR_PLATAFORMA := Color(0.62, 0.66, 0.74)
const COR_CACAU := Color(0.90, 0.42, 0.20)
const COR_JALECO := Color(0.88, 0.88, 0.82)
const COR_SETA := Color(0.55, 0.85, 1.0)
const COR_TEXTO := Color(0.86, 0.89, 0.94)

## Tamanho da seta, em pixels, quando a força está no topo da escala.
const SETA_CHEIA := 118.0
const SETA_MINIMA := 6.0

var _tempo_resultado: float = 0.0
## Altura atual da plataforma no desenho, 0 = no chão, 1 = encostada na viga.
var _altura: float = 0.0
var _giro: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	_tempo_resultado += delta
	var alvo := 0.0
	match resultado:
		"certa":
			alvo = 1.0
		"forte":
			# Arranca até a viga e fica batendo nela: a batida é a leitura de
			# "sobrou força".
			alvo = 1.0
	# A subida certa é firme; a forte chega em disparada.
	var passo: float = 1.6 if resultado == "certa" else 5.0
	_altura = move_toward(_altura, alvo, delta * passo)
	# O tambor só gira enquanto a plataforma está subindo.
	if _altura < 1.0 and alvo > 0.0:
		_giro += delta * 7.0
	queue_redraw()


func _draw() -> void:
	var cx: float = size.x * 0.55
	var y_viga := 12.0
	var y_polia := y_viga + 30.0
	var y_chao: float = size.y - 26.0
	var y_topo := y_polia + 74.0
	var y_plat: float = lerpf(y_chao, y_topo, _altura) + _sacudida()

	# Viga, chão e tambor.
	draw_rect(Rect2(0.0, 0.0, size.x, y_viga), COR_VIGA)
	draw_rect(Rect2(0.0, y_chao, size.x, size.y - y_chao), COR_CHAO)
	_desenhar_tambor(Vector2(34.0, y_polia))

	# O cabo: sai do tambor, passa pela polia da viga e desce até a plataforma.
	draw_line(Vector2(53.0, y_polia), Vector2(cx - 8.0, y_polia), COR_CABO, 2.5, true)
	draw_circle(Vector2(cx, y_polia), 8.0, COR_ACO)
	draw_circle(Vector2(cx, y_polia), 3.0, COR_ACO_ESCURO)
	draw_line(Vector2(cx, y_polia + 8.0), Vector2(cx, y_plat), COR_CABO, 2.5, true)

	# A plataforma e a Cacau em cima dela — o peso é ELA, não uma seta.
	draw_rect(Rect2(cx - 56.0, y_plat, 112.0, 10.0), COR_PLATAFORMA)
	_desenhar_cacau(Vector2(cx, y_plat))

	# A única seta do desenho é a força que o jogador regulou.
	_seta_para_cima(Vector2(cx + 84.0, y_plat + 5.0))


func _desenhar_tambor(centro: Vector2) -> void:
	draw_circle(centro, 19.0, COR_ACO_ESCURO)
	draw_arc(centro, 19.0, 0.0, TAU, 28, COR_ACO, 2.0, true)
	for i in 3:
		var a: float = _giro + TAU * float(i) / 3.0
		draw_line(centro, centro + Vector2(cos(a), sin(a)) * 15.0, COR_CABO, 2.0, true)
	draw_circle(centro, 4.0, COR_ACO)


## Um bonequinho de jaleco e cabelo laranja: é ele que representa a carga.
func _desenhar_cacau(pes: Vector2) -> void:
	draw_rect(Rect2(pes.x - 11.0, pes.y - 34.0, 22.0, 26.0), COR_JALECO)
	draw_circle(pes + Vector2(0.0, -42.0), 9.0, COR_CACAU)
	draw_line(pes + Vector2(-5.0, -8.0), pes + Vector2(-5.0, 0.0), COR_ACO_ESCURO, 3.0, true)
	draw_line(pes + Vector2(5.0, -8.0), pes + Vector2(5.0, 0.0), COR_ACO_ESCURO, 3.0, true)


func _seta_para_cima(base: Vector2) -> void:
	var escala: float = clampf(forca / maxf(forca_maxima, 1.0), 0.0, 1.0)
	var comprimento: float = maxf(escala * SETA_CHEIA, SETA_MINIMA)
	var ponta := base - Vector2(0.0, comprimento)
	draw_line(base, ponta, COR_SETA, 3.0, true)
	draw_colored_polygon(PackedVector2Array([
		ponta, ponta + Vector2(-6.0, 10.0), ponta + Vector2(6.0, 10.0)]), COR_SETA)
	_texto("F", ponta + Vector2(9.0, 4.0))


## Tremor da plataforma: curto e nervoso quando falta força, uma batida que
## vai morrendo quando sobra.
func _sacudida() -> float:
	match resultado:
		"fraca":
			return sin(_tempo_resultado * 44.0) * 1.6
		"forte":
			var morrendo: float = maxf(1.0 - _tempo_resultado * 0.7, 0.0)
			return sin(_tempo_resultado * 30.0) * 7.0 * morrendo * _altura
	return 0.0


func _texto(texto: String, pos: Vector2) -> void:
	var fonte := ThemeDB.fallback_font
	if fonte == null:
		return
	draw_string(fonte, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COR_TEXTO)
