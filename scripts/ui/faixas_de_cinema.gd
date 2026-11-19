extends CanvasLayer

# --- AS FAIXAS DE CINEMA ---
#
# As duas tarjas pretas, em cima e embaixo, que entram deslizando quando uma
# cena vira filme (o lançamento no telhado da fase 2) e saem no fim.
#
# Ficam no layer 0, como a cortina do FadeTela: por cima do mundo e por baixo
# do Dialogic (layer 1), então a caixa de fala aparece por cima delas. Quem as
# usa esconde o HUD antes de pô-las na cena — o esconder_huds() do FadeTela
# apagaria as faixas também, se elas já estivessem lá.

## Altura de cada faixa, em fração da altura da tela.
const ALTURA := 0.062
const COR := Color(0, 0, 0, 1)

## Quanto das faixas está na tela, de 0 (fora) a 1 (inteiras).
var entrada := 0.0:
	set(v):
		entrada = v
		_posicionar()

var _de_cima: ColorRect
var _de_baixo: ColorRect
var _tween: Tween


func _init() -> void:
	name = "FaixasDeCinema"
	layer = 0


func _ready() -> void:
	_de_cima = _nova_faixa("DeCima")
	_de_baixo = _nova_faixa("DeBaixo")
	get_viewport().size_changed.connect(_posicionar)
	_posicionar()


## Entram deslizando.
func entrar(duracao: float = 0.8) -> void:
	await _deslizar(1.0, duracao, Tween.EASE_OUT)


## Saem deslizando e vão embora.
func sair(duracao: float = 0.8) -> void:
	await _deslizar(0.0, duracao, Tween.EASE_IN_OUT)
	queue_free()


func _nova_faixa(nome: String) -> ColorRect:
	var faixa := ColorRect.new()
	faixa.name = nome
	faixa.color = COR
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(faixa)
	return faixa


func _posicionar() -> void:
	if _de_cima == null or not is_inside_tree():
		return
	var tela := get_viewport().get_visible_rect().size
	var altura := ceilf(tela.y * ALTURA)
	_de_cima.size = Vector2(tela.x, altura)
	_de_baixo.size = Vector2(tela.x, altura)
	_de_cima.position = Vector2(0.0, -altura + altura * entrada)
	_de_baixo.position = Vector2(0.0, tela.y - altura * entrada)


func _deslizar(alvo: float, duracao: float, suavidade: Tween.EaseType) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "entrada", alvo, duracao).set_trans(Tween.TRANS_CUBIC).set_ease(suavidade)
	await _tween.finished
