@tool
class_name PlacaDeCaminho
extends Node2D

# --- PLACA DE CAMINHO (a plaquinha "DESTILADOR ->" do laboratório) ---
#
# Uma placa verde de parede, do jeito das placas de saída: o nome do lugar em
# letra de pixel e uma seta para o lado em que ele fica. É desenhada pelo
# próprio nó, sem PNG: mude o texto ou a seta no Inspetor e ela se refaz (no
# editor também).
#
# COMO EDITAR NO EDITOR
#   posição do nó     -> o MEIO da placa
#   texto             -> o nome do lugar (a fonte de pixel fica melhor em
#                        maiúsculas)
#   seta              -> para que lado ela aponta (ou nenhuma)
#   tamanho_da_letra  -> a altura da letra, em pixels do mundo
#
# A letra é desenhada no dobro do tamanho e encolhida pela metade (o mesmo
# truque do "PAINEL" do painel CHONPS): com a câmera chegando perto, ela
# continua nítida.
#
# No laboratório: PlacaDestilador, perto da ponta direita da sala — é andando
# para a direita, para fora da sala, que se chega ao corredor da torre e à fase
# do nitrogênio.

enum Seta { NENHUMA, DIREITA, ESQUERDA }

const FONTE := preload("res://assets/fonts/BoldPixels.ttf")

const VERDE := Color("17924a")
const VERDE_ESCURO := Color("0d5f2f")
const FILETE := Color("dff5e6")
const LETRA := Color("f6fff8")
const CONTORNO := Color(0.03, 0.07, 0.05)
const PARAFUSO := Color("9fb8a8")

## Folga entre a borda da placa e o que vai escrito nela (px do mundo).
const FOLGA := Vector2(10, 7)
## Do texto até a seta.
const ESPACO_ATE_A_SETA := 8.0
## Espessura do contorno escuro em volta da placa.
const ESPESSURA_DO_CONTORNO := 2.0

@export var texto: String = "TORRE DE GASES":
	set(valor):
		texto = valor
		queue_redraw()
@export var seta: Seta = Seta.DIREITA:
	set(valor):
		seta = valor
		queue_redraw()
@export_range(8, 48, 1, "suffix:px") var tamanho_da_letra: int = 18:
	set(valor):
		tamanho_da_letra = valor
		queue_redraw()


## O retângulo da placa em volta da origem do nó (px do mundo, sem o contorno).
func retangulo() -> Rect2:
	var tamanho := _tamanho_do_miolo() + FOLGA * 2.0
	return Rect2(-tamanho * 0.5, tamanho).abs()


func _draw() -> void:
	var placa := retangulo()
	# Contorno escuro, a placa, a faixa mais escura embaixo (o volume) e o
	# filete claro por dentro, como nas placas de rua.
	draw_rect(placa.grow(ESPESSURA_DO_CONTORNO), CONTORNO)
	draw_rect(placa, VERDE)
	draw_rect(Rect2(placa.position.x, placa.end.y - 3.0, placa.size.x, 3.0), VERDE_ESCURO)
	draw_rect(placa.grow(-2.5), FILETE, false, 1.0)
	for canto in [placa.position + Vector2(5, 5), Vector2(placa.end.x - 5, placa.position.y + 5)]:
		draw_rect(Rect2(canto - Vector2.ONE, Vector2(2, 2)), PARAFUSO)

	var miolo := _tamanho_do_miolo()
	var largura_da_seta := _largura_da_seta()
	var x := -miolo.x * 0.5
	if seta == Seta.ESQUERDA:
		_desenhar_seta(Vector2(x, 0.0), -1.0)
		x += largura_da_seta + ESPACO_ATE_A_SETA
	_desenhar_texto(Vector2(x, 0.0))
	if seta == Seta.DIREITA:
		x += _largura_do_texto() + ESPACO_ATE_A_SETA
		_desenhar_seta(Vector2(x, 0.0), 1.0)


## O texto com a ponta esquerda em "esquerda" e centrado na altura (y = 0).
func _desenhar_texto(esquerda: Vector2) -> void:
	if texto.is_empty():
		return
	var grande := tamanho_da_letra * 2
	var subida := (FONTE.get_ascent(grande) - FONTE.get_descent(grande)) * 0.25
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.5, 0.5))
	var pos := Vector2(esquerda.x, esquerda.y + subida) * 2.0
	draw_string_outline(FONTE, pos.round(), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, grande, 4, CONTORNO)
	draw_string(FONTE, pos.round(), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, grande, LETRA)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A seta (haste e ponta), a partir da beirada "inicio", apontando para "lado".
func _desenhar_seta(inicio: Vector2, lado: float) -> void:
	var largura := _largura_da_seta()
	var altura := tamanho_da_letra * 0.8
	var haste := altura * 0.36
	var corpo := largura * 0.45
	# Desenhada apontando para a direita a partir de x = 0 e espelhada se for
	# para a esquerda.
	var pontos := PackedVector2Array([
		Vector2(0.0, -haste * 0.5), Vector2(corpo, -haste * 0.5), Vector2(corpo, -altura * 0.5),
		Vector2(largura, 0.0),
		Vector2(corpo, altura * 0.5), Vector2(corpo, haste * 0.5), Vector2(0.0, haste * 0.5),
	])
	var forma := PackedVector2Array()
	for p in pontos:
		var x := p.x if lado > 0.0 else largura - p.x
		forma.append(inicio + Vector2(x, p.y))
	for inflado in Geometry2D.offset_polygon(forma, 1.5, Geometry2D.JOIN_MITER):
		draw_colored_polygon(inflado, CONTORNO)
	draw_colored_polygon(forma, LETRA)


func _tamanho_do_miolo() -> Vector2:
	var largura := _largura_do_texto()
	if seta != Seta.NENHUMA:
		largura += _largura_da_seta() + (ESPACO_ATE_A_SETA if not texto.is_empty() else 0.0)
	return Vector2(largura, float(tamanho_da_letra))


func _largura_do_texto() -> float:
	if texto.is_empty():
		return 0.0
	return FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho_da_letra * 2).x * 0.5


func _largura_da_seta() -> float:
	return tamanho_da_letra * 1.15 if seta != Seta.NENHUMA else 0.0
