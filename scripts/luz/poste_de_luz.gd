@tool
class_name PosteDeLuz
extends Node2D
## Um poste de rua inteiro, aceso: a arte do poste ([code]Props-01.png[/code],
## a mesma dos tiles) e a [LuzDePoste] no tubo da lâmpada. É uma cena
## ([code]scenes/luz/poste_de_luz.tscn[/code]) para ser arrastada no editor.
##
## A ORIGEM É O PÉ do poste, no meio da haste: solte o nó em cima do chão. O
## braço com a lâmpada sai para a direita ([member espelhado] vira para a
## esquerda) e a haste cresce em tiles com [member altura].
##
## A luz é a do nó filho "Luz": para mudar a cor ou o alcance de um poste só,
## clique com o botão direito na instância, "Filhos Editáveis", e mexa nela.
## Ela se acomoda sozinha no tubo quando a altura ou o lado mudam.
##
## Pintar o poste no TileMap continua valendo (o [PostesDeLuz] da cena acende
## os pintados), mas aí ele não se arrasta.

const ARTE := preload("res://assets/fase nitrogenio/Sidescroller Shooter - Central City/Assets/Props-01.png")
## Lado do tile da arte, em pixels da arte, e quanto ele cresce no mundo.
const TILE := 16
const ESCALA := 2.0
## Linhas da coluna 0 do atlas: o topo da haste, os três pedaços do meio (que
## se repetem nessa ordem) e a base.
const LINHA_TOPO := 9
const LINHAS_MEIO := [10, 11, 12]
const LINHA_BASE := 13
## O braço com a lâmpada: as colunas 1 a 3 da linha do topo.
const COLUNAS_BRACO := 3
## Altura do tubo dentro do tile do braço e quanto ele é mais curto que o
## braço, em pixels da arte (as mesmas medidas do PostesDeLuz).
const TUBO_Y := 5.5
const SOBRA_DO_TUBO := 2.0

## Altura do poste em tiles, contando o topo e a base. Os postes da rua da
## fase 2 têm 8 (256 px no mundo).
@export_range(3, 20, 1) var altura := 8:
	set(v):
		altura = v
		_atualizar()
## Braço (e lâmpada) para a esquerda.
@export var espelhado := false:
	set(v):
		espelhado = v
		_atualizar()


func _ready() -> void:
	_atualizar()


func _draw() -> void:
	var lado := TILE * ESCALA
	if espelhado:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
	var linhas := linhas_da_haste()
	for i in linhas.size():
		var y := -(altura - i) * lado
		_desenhar_celula(Vector2i(0, linhas[i]), Vector2(-lado * 0.5, y))
	for c in COLUNAS_BRACO:
		_desenhar_celula(Vector2i(1 + c, LINHA_TOPO), Vector2(lado * (0.5 + c), -altura * lado))


func _desenhar_celula(celula: Vector2i, onde: Vector2) -> void:
	var lado := TILE * ESCALA
	draw_texture_rect_region(ARTE, Rect2(onde, Vector2(lado, lado)),
		Rect2(Vector2(celula * TILE), Vector2(TILE, TILE)))


## As linhas do atlas da haste, de cima para baixo: o topo, os pedaços do meio
## (repetindo na ordem) e a base.
func linhas_da_haste() -> Array[int]:
	var linhas: Array[int] = [LINHA_TOPO]
	for i in altura - 2:
		linhas.append(LINHAS_MEIO[i % LINHAS_MEIO.size()])
	linhas.append(LINHA_BASE)
	return linhas


## Posição do tubo da lâmpada, a partir do pé.
func ponto_da_lampada() -> Vector2:
	var lado := TILE * ESCALA
	var x := lado * 0.5 + lado * COLUNAS_BRACO * 0.5
	var y := -altura * lado + TUBO_Y * ESCALA
	return Vector2(-x if espelhado else x, y)


func _atualizar() -> void:
	queue_redraw()
	var luz := get_node_or_null(^"Luz") as LuzDePoste
	if luz == null:
		return
	luz.position = ponto_da_lampada()
	luz.largura = (TILE * COLUNAS_BRACO - SOBRA_DO_TUBO) * ESCALA
