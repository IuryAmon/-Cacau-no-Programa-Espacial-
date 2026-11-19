class_name DicaDeArrastar
extends Control

# --- "DÁ PARA ARRASTAR ISTO COM O MOUSE" (a mãozinha mostrando o gesto) ---
#
# Até a pessoa arrastar pela primeira vez, a coisa que se arrasta (o cabo do
# êmbolo, o ponteiro do termômetro) ganha um contorno amarelo que pisca, duas
# setinhas mostrando para onde ela anda, e uma mão (MaoDoMouse) que chega,
# fecha em cima dela, arrasta um pouco e solta. Nenhum texto: o gesto se
# explica. A mão some enquanto o ponteiro do mouse está em cima da coisa (a
# pessoa já achou) e a dica toda para quando quem usa chama parar().
#
# Quem usa põe este nó (do tamanho da tela) por cima de tudo e chama
# mostrar(retangulo, sentido). "retangulo" é um Callable que devolve onde a
# coisa está na tela a cada quadro (ela anda).

## A mão do Roret_Cursor (a mesma do cursor do mouse), ampliada.
const ESCALA_DA_MAO := 2
## Uma volta do gesto: chega, fecha, arrasta, solta, some e espera.
const CICLO := 2.6
const COR := Color("f2c84b")

var _retangulo: Callable = Callable()
## Para onde a coisa anda (Vector2.DOWN, Vector2.UP...), e quanto o gesto
## arrasta (px).
var _sentido: Vector2 = Vector2.DOWN
var _distancia: float = 48.0
## Onde a mão pega, em fração da coisa (0,0 = canto de cima à esquerda).
var _onde_pegar: Vector2 = Vector2(0.5, 0.5)
var _relogio: float = 0.0
var _alfa: float = 0.0
var _ativa: bool = false
## O ponteiro do mouse em cima da coisa: a mão some (o contorno fica).
var ponteiro_em_cima: bool = false
## Escondida por fora (a tela está entrando, alguém está falando...).
var pausada: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Começa a mostrar o gesto na coisa que "retangulo" devolve. "onde_pegar" é
## o ponto em que a mão fecha, em fração da coisa (o meio, se não disser).
func mostrar(retangulo: Callable, sentido: Vector2 = Vector2.DOWN, distancia: float = 48.0,
		onde_pegar: Vector2 = Vector2(0.5, 0.5)) -> void:
	_retangulo = retangulo
	_onde_pegar = onde_pegar
	_sentido = sentido.normalized()
	_distancia = distancia
	_relogio = 0.0
	_ativa = true


## Para de vez (a pessoa já arrastou).
func parar() -> void:
	_ativa = false


func mostrando() -> bool:
	return _ativa


func _process(delta: float) -> void:
	var visivel := _ativa and not pausada and _retangulo.is_valid()
	_alfa = move_toward(_alfa, 1.0 if visivel else 0.0, delta / 0.25)
	if _alfa > 0.0:
		_relogio = fmod(_relogio + delta, CICLO)
	queue_redraw()


func _draw() -> void:
	if _alfa <= 0.0 or not _retangulo.is_valid():
		return
	var caixa: Rect2 = _retangulo.call()
	if caixa.size == Vector2.ZERO:
		return
	var t := _relogio
	# O contorno pisca, e acende mais enquanto a mão arrasta.
	var pulso := 0.5 + 0.5 * sin(t / CICLO * TAU * 2.0)
	var arrastando := t > 0.6 and t < 1.45
	var forca := (0.55 + 0.45 * pulso) if not arrastando else 1.0
	var contorno := caixa.grow(6.0)
	_moldura(contorno, Color(COR, 0.85 * forca * _alfa))
	# As setinhas: uma de cada lado no sentido em que a coisa anda.
	_setinhas(contorno, Color(COR, (0.6 + 0.4 * pulso) * _alfa))
	if not ponteiro_em_cima:
		_desenhar_a_mao(caixa, t)


## Um contorno de 2 px com os cantos quebrados (pixel art).
func _moldura(r: Rect2, cor: Color) -> void:
	r = Rect2(r.position.round(), r.size.round())
	draw_rect(Rect2(r.position.x + 4.0, r.position.y, r.size.x - 8.0, 2.0), cor)
	draw_rect(Rect2(r.position.x + 4.0, r.end.y - 2.0, r.size.x - 8.0, 2.0), cor)
	draw_rect(Rect2(r.position.x, r.position.y + 4.0, 2.0, r.size.y - 8.0), cor)
	draw_rect(Rect2(r.end.x - 2.0, r.position.y + 4.0, 2.0, r.size.y - 8.0), cor)
	for canto: Vector2 in [r.position + Vector2(2, 2), Vector2(r.end.x - 4.0, r.position.y + 2.0),
			Vector2(r.position.x + 2.0, r.end.y - 4.0), r.end - Vector2(4, 4)]:
		draw_rect(Rect2(canto, Vector2(2, 2)), cor)


## Dois triângulos de pixel, um antes e um depois da coisa, apontando para
## os dois lados em que ela anda.
func _setinhas(r: Rect2, cor: Color) -> void:
	var vertical := absf(_sentido.y) >= absf(_sentido.x)
	var balanco := roundf(sin(_relogio / CICLO * TAU * 2.0) * 2.0)
	if vertical:
		var x := roundf(r.get_center().x)
		_triangulo(Vector2(x, r.position.y - 8.0 - balanco), -1, true, cor)
		_triangulo(Vector2(x, r.end.y + 8.0 + balanco), 1, true, cor)
	else:
		var y := roundf(r.get_center().y)
		_triangulo(Vector2(r.position.x - 8.0 - balanco, y), -1, false, cor)
		_triangulo(Vector2(r.end.x + 8.0 + balanco, y), 1, false, cor)


## Um triângulo de 4 degraus com a ponta em "ponta", virado para "lado" (-1
## para cima ou para a esquerda, 1 para baixo ou para a direita).
func _triangulo(ponta: Vector2, lado: int, vertical: bool, cor: Color) -> void:
	for i in 4:
		var largura := 2.0 + i * 4.0
		var recuo := float(i) * 2.0 * -lado
		if vertical:
			draw_rect(Rect2(ponta.x - largura * 0.5, ponta.y + recuo - (2.0 if lado > 0 else 0.0), largura, 2.0),
				cor)
		else:
			draw_rect(Rect2(ponta.x + recuo - (2.0 if lado > 0 else 0.0), ponta.y - largura * 0.5, 2.0, largura),
				cor)


## A mão: chega de perto, fecha em cima da coisa, arrasta no sentido dela,
## solta e some.
func _desenhar_a_mao(caixa: Rect2, t: float) -> void:
	var pega := (caixa.position + caixa.size * _onde_pegar).round()
	var de_onde := pega + Vector2(40, 46)
	var ponto := pega
	var fechada := false
	var alfa := 1.0
	if t < 0.45:
		var a := ease(t / 0.45, -2.0)
		ponto = de_onde.lerp(pega, a)
		alfa = clampf(t / 0.2, 0.0, 1.0)
	elif t < 0.6:
		fechada = true
	elif t < 1.35:
		fechada = true
		ponto = pega + _sentido * _distancia * ease((t - 0.6) / 0.75, -2.0)
	elif t < 1.55:
		ponto = pega + _sentido * _distancia
	elif t < 1.95:
		ponto = pega + _sentido * _distancia
		alfa = 1.0 - (t - 1.55) / 0.4
	else:
		return
	var textura := MaoDoMouse.textura(fechada)
	var tamanho := textura.get_size() * ESCALA_DA_MAO
	var canto := (ponto - MaoDoMouse.palma(fechada) * ESCALA_DA_MAO).round()
	# A sombra embaixo, para a mão "flutuar" em cima da coisa.
	draw_texture_rect(textura, Rect2(canto + Vector2(4, 5), tamanho), false, Color(0, 0, 0, 0.35 * alfa * _alfa))
	draw_texture_rect(textura, Rect2(canto, tamanho), false, Color(1, 1, 1, alfa * _alfa))
