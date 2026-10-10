@tool
class_name FundoDoLaboratorio
extends Control

# --- O FUNDO DAS TELAS DO LABORATÓRIO ---
#
# Papel quadriculado de projeto, em azul-escuro: é a "bancada" em que os
# cartões, a tela do computador e a tabela periódica do Laboratório ficam
# apoiados. Uma cor chapada (o contorno das teclas e dos balões de fala), uma
# linha fina a cada quadradinho e uma mais forte a cada cinco, como num papel
# milimetrado. Nada de degradê: é a mesma linguagem do HUD (ver EstiloHUD).
#
# COMO EDITAR NO EDITOR: ponha o nó ocupando a tela inteira, atrás de tudo. As
# cores e o tamanho do quadriculado estão no Inspector.

## A cor do papel.
@export var cor: Color = Color("14182e"):
	set(valor):
		cor = valor
		queue_redraw()
## A cor das linhas (a força de cada uma é o alfa abaixo).
@export var cor_das_linhas: Color = Color("686f99"):
	set(valor):
		cor_das_linhas = valor
		queue_redraw()
## O lado de um quadradinho, em px.
@export_range(8.0, 128.0, 1.0) var quadradinho: float = 32.0:
	set(valor):
		quadradinho = maxf(valor, 4.0)
		queue_redraw()
## De quantos em quantos quadradinhos a linha é mais forte.
@export_range(2, 10, 1) var de_quantos_em_quantos: int = 5:
	set(valor):
		de_quantos_em_quantos = maxi(valor, 2)
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var forca_da_linha: float = 0.09:
	set(valor):
		forca_da_linha = valor
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var forca_da_linha_forte: float = 0.2:
	set(valor):
		forca_da_linha_forte = valor
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), cor)
	# A grade parte do meio da tela, para sobrar igual dos dois lados.
	var meio := (size * 0.5).round()
	var colunas := ceili(size.x * 0.5 / quadradinho) + 1
	for i in range(-colunas, colunas + 1):
		var x := meio.x + i * quadradinho
		if x < 0.0 or x > size.x:
			continue
		draw_rect(Rect2(x - 1.0, 0.0, 2.0, size.y), _cor_da_linha(i))
	var linhas := ceili(size.y * 0.5 / quadradinho) + 1
	for i in range(-linhas, linhas + 1):
		var y := meio.y + i * quadradinho
		if y < 0.0 or y > size.y:
			continue
		draw_rect(Rect2(0.0, y - 1.0, size.x, 2.0), _cor_da_linha(i))


func _cor_da_linha(i: int) -> Color:
	return Color(cor_das_linhas, forca_da_linha_forte if i % de_quantos_em_quantos == 0 else forca_da_linha)
