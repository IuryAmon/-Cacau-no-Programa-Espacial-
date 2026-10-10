@tool
class_name CaixaElemento
extends Control

# --- A CAIXA DE UM ELEMENTO (uma casa da tabela periódica, numa tela) ---
#
# Mostra a caixa de um dos 118 elementos do jeito que a do hidrogênio aparece
# no caderno da Cacau: o papel, a moldura de tinta, o número atômico, o símbolo
# e a massa (a arte vem de CaixasDosElementos) e, quando ampliada, o nome do
# elemento escrito no vão entre o símbolo e a massa.
#
# É a peça com que o Laboratório representa um átomo: as 118 casas da tabela
# periódica, a resposta do "Monte seu átomo", as alternativas do quiz.
#
# COMO USAR NO EDITOR: ponha um Control com este script e escolha, no
# Inspector, o "numero_atomico" e a "escala". O tamanho do nó se ajusta
# sozinho (76 x 92 px vezes a escala).
#
#   escala 1   a casa da tabela: cabe sem o nome
#   escala 2   a do caderno: o nome vai dentro, na letra de 11 ampliada 1,5x
#              (é o que cabe no vão, como na página do hidrogênio)
#   escala 3   para um destaque
#
# Quem usa também pode pintar: "tom" tinge o papel (a cor da família, na
# tabela), "destaque" acende um contorno em volta (a casa escolhida, a
# resposta certa do quiz) e "apagada" esmaece a caixa inteira.

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")
const TAM_NOME := 11
## O nome vai na letra de 11 ampliada 0,75 x a escala da caixa: 1,5x na caixa
## de escala 2, que é o tamanho dele na página do caderno.
const FATOR_DO_NOME := 0.75

## O tom que o papel da caixa ganha numa tabela, pela família do elemento: é a
## cor de cada família na tabela periódica do Laboratório (e na miniatura dela,
## no menu). Quem desenha a caixa passa o tom em "tom".
const TONS_DAS_FAMILIAS := {
	Elementos.Familia.METAL_ALCALINO: Color(0.93, 0.42, 0.33, 0.50),
	Elementos.Familia.METAL_ALCALINOTERROSO: Color(0.97, 0.62, 0.22, 0.50),
	Elementos.Familia.METAL_DE_TRANSICAO: Color(0.98, 0.84, 0.30, 0.48),
	Elementos.Familia.OUTRO_METAL: Color(0.58, 0.66, 0.62, 0.50),
	Elementos.Familia.SEMIMETAL: Color(0.30, 0.70, 0.62, 0.48),
	Elementos.Familia.NAO_METAL: Color(0.36, 0.62, 0.92, 0.46),
	Elementos.Familia.HALOGENIO: Color(0.56, 0.48, 0.90, 0.44),
	Elementos.Familia.GAS_NOBRE: Color(0.88, 0.46, 0.78, 0.42),
	Elementos.Familia.LANTANIDIO: Color(0.60, 0.80, 0.36, 0.46),
	Elementos.Familia.ACTINIDIO: Color(0.80, 0.58, 0.42, 0.52),
}

## O número atômico do elemento (1 a 118). 0 = caixa vazia, com "?".
@export_range(0, 118, 1) var numero_atomico: int = 1:
	set(valor):
		numero_atomico = clampi(valor, 0, Elementos.TOTAL)
		_ajustar()
## Quantas vezes a arte é ampliada. Inteira, para o pixel não entortar.
@export_range(1, 4, 1) var escala: int = 2:
	set(valor):
		escala = maxi(valor, 1)
		_ajustar()
## Escreve o nome do elemento dentro da caixa (só cabe da escala 2 para cima).
@export var com_nome: bool = true:
	set(valor):
		com_nome = valor
		queue_redraw()
## Desenha o papel do caderno atrás da tinta. Desligue para pôr a caixa em
## cima de um papel que já existe (a folha da tabela).
@export var com_papel: bool = true:
	set(valor):
		com_papel = valor
		queue_redraw()
## A sombra dura embaixo, como a das fichas do HUD.
@export var com_sombra: bool = false:
	set(valor):
		com_sombra = valor
		queue_redraw()
@export var cor_do_papel: Color = EstiloHUD.PAPEL:
	set(valor):
		cor_do_papel = valor
		queue_redraw()

## Tinge o papel (a cor da família, de TONS_DAS_FAMILIAS). Transparente = papel
## puro.
var tom: Color = Color(0, 0, 0, 0):
	set(valor):
		tom = valor
		queue_redraw()
## Contorno aceso em volta da caixa. Transparente = sem contorno.
var destaque: Color = Color(0, 0, 0, 0):
	set(valor):
		destaque = valor
		queue_redraw()
## Esmaece a caixa (uma alternativa do quiz que já foi descartada).
var apagada: bool = false:
	set(valor):
		apagada = valor
		queue_redraw()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ajustar()


## O tamanho da caixa na tela, com esta escala.
static func tamanho_na_escala(escala_pedida: int) -> Vector2:
	return Vector2(CaixasDosElementos.TAMANHO) * escala_pedida


func _ajustar() -> void:
	custom_minimum_size = tamanho_na_escala(escala)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	queue_redraw()


func _draw() -> void:
	desenhar(self, Vector2.ZERO, numero_atomico, escala, com_nome, com_papel, cor_do_papel, tom,
		destaque, 0.45 if apagada else 1.0, com_sombra)


## Desenha a caixa em qualquer CanvasItem, com o canto em "canto". É o que o
## _draw daqui usa, e o que a tabela periódica usa para desenhar as 118 de uma
## vez, sem um nó para cada.
static func desenhar(ci: CanvasItem, canto: Vector2, z: int, escala_pedida: int,
		nome_dentro: bool = true, papel: bool = true, cor_papel: Color = EstiloHUD.PAPEL,
		tom_do_papel: Color = Color(0, 0, 0, 0), cor_destaque: Color = Color(0, 0, 0, 0),
		alfa: float = 1.0, sombra: bool = false) -> void:
	var e := float(escala_pedida)
	var caixa := Rect2(canto, tamanho_na_escala(escala_pedida))
	# A moldura por fora (sem a folga transparente da arte).
	var moldura := caixa.grow(-CaixasDosElementos.FOLGA * e)
	if sombra:
		ci.draw_rect(Rect2(moldura.position + Vector2(0.0, 2.0 * e), moldura.size),
			EstiloHUD.com_alfa(EstiloHUD.SOMBRA_DURA, alfa))
	if cor_destaque.a > 0.0:
		ci.draw_rect(moldura.grow(2.0 * e), EstiloHUD.com_alfa(cor_destaque, alfa))
	if papel:
		ci.draw_rect(moldura, EstiloHUD.com_alfa(cor_papel, alfa))
	if tom_do_papel.a > 0.0:
		ci.draw_rect(moldura, EstiloHUD.com_alfa(tom_do_papel, alfa))

	var tinta := Color(1, 1, 1, alfa)
	if Elementos.existe(z):
		ci.draw_texture_rect(CaixasDosElementos.textura(z), caixa, false, tinta)
		if nome_dentro and escala_pedida >= 2:
			_escrever_no_vao(ci, canto, z, e, alfa)
	else:
		# Sem elemento: só a moldura e um ponto de interrogação no lugar do símbolo.
		ci.draw_texture_rect(CaixasDosElementos.textura_da_faixa(""), caixa, false, tinta)
		var tamanho := CaixasDosElementos.TAM_SIMBOLO
		var largura := FONTE.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
		ci.draw_set_transform(canto + Vector2(CaixasDosElementos.MEIO_SIMBOLO, CaixasDosElementos.PE_SIMBOLO) * e
			- Vector2(largura * e * 0.5, 0.0), 0.0, Vector2.ONE * e)
		ci.draw_string(FONTE, Vector2.ZERO, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho,
			EstiloHUD.com_alfa(EstiloHUD.TINTA_FRACA, alfa))
		ci.draw_set_transform(Vector2.ZERO)


## O nome do elemento no vão entre o símbolo e a massa, como na página do
## hidrogênio do caderno (FaceCaderno): a letra de 11 desenhada ampliada, e
## não numa letra maior, que sairia da grade de pixels da fonte.
static func _escrever_no_vao(ci: CanvasItem, canto: Vector2, z: int, e: float, alfa: float) -> void:
	var nome := Elementos.nome(z)
	var fator := escala_do_nome(nome, e)
	# Abaixo da perna das letras do símbolo, quando ele tem (Mg, Dy...).
	var vao := CaixasDosElementos.vao_do_nome(z)
	var meio := canto + vao.get_center() * e
	var largura := FONTE.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_NOME).x * fator
	var sobe := FONTE.get_ascent(TAM_NOME) * fator
	var desce := FONTE.get_descent(TAM_NOME) * fator
	ci.draw_set_transform(Vector2(meio.x - largura * 0.5, meio.y + (sobe - desce) * 0.5).round(), 0.0,
		Vector2.ONE * fator)
	ci.draw_string(FONTE, Vector2.ZERO, nome, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_NOME,
		EstiloHUD.com_alfa(CaixasDosElementos.TINTA, alfa))
	ci.draw_set_transform(Vector2.ZERO)


## Quanto a letra de 11 é ampliada para o nome: 0,75 x a escala da caixa (1,5x
## na escala 2) ou, se assim o nome não coubesse no vão, o que couber.
static func escala_do_nome(nome: String, e: float) -> float:
	var fator := FATOR_DO_NOME * e
	var largura := FONTE.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_NOME).x
	var cabe := CaixasDosElementos.VAO_DO_NOME.size.x * e - 4.0
	if largura * fator > cabe:
		fator = cabe / largura
	return fator
