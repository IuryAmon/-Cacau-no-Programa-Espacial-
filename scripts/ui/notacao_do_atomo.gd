@tool
class_name NotacaoDoAtomo
extends Control

# --- A NOTAÇÃO DE UM ÁTOMO ---
#
# O átomo escrito como nos livros: o símbolo do elemento com o número de massa
# (A) em cima à esquerda, o número atômico (Z) embaixo à esquerda e a carga em
# cima à direita. O sódio que perdeu um elétron:
#
#        23    +
#          Na
#        11
#
# O "Monte seu átomo" do Laboratório mostra o átomo montado assim, ao lado da
# caixa do elemento.
#
# COMO EDITAR NO EDITOR: o desenho fica no meio do nó. A letra do símbolo é a
# "tamanho" (os números vão na metade dela) e a cor é a "cor". Se o conjunto
# não couber na largura do nó (um elemento de símbolo largo, com carga de dois
# algarismos), ele encolhe até caber.

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")
## Folga entre os números e o símbolo.
const FOLGA := 4.0

@export var simbolo: String = "C":
	set(valor):
		simbolo = valor
		queue_redraw()
## O número de massa: prótons mais nêutrons.
@export var massa: int = 12:
	set(valor):
		massa = valor
		queue_redraw()
@export var numero_atomico: int = 6:
	set(valor):
		numero_atomico = valor
		queue_redraw()
## Prótons menos elétrons: 0 no átomo neutro.
@export var carga: int = 0:
	set(valor):
		carga = valor
		queue_redraw()
## A letra do símbolo. Use um múltiplo de 22, para os números (a metade)
## ficarem na grade de pixels da fonte.
@export var tamanho: int = 44:
	set(valor):
		tamanho = maxi(valor, 2)
		queue_redraw()
@export var cor: Color = Color(0.9, 0.95, 1.0):
	set(valor):
		cor = valor
		queue_redraw()
## A cor dos números (massa e número atômico) e da carga.
@export var cor_dos_numeros: Color = Color(1.0, 0.85, 0.0):
	set(valor):
		cor_dos_numeros = valor
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Diz tudo de uma vez.
func definir(novo_simbolo: String, nova_massa: int, novo_numero: int, nova_carga: int) -> void:
	simbolo = novo_simbolo
	massa = nova_massa
	numero_atomico = novo_numero
	carga = nova_carga


## A largura do conjunto no tamanho cheio (para os testes).
func largura_do_conjunto() -> float:
	return _medidas()["total"]


func _medidas() -> Dictionary:
	@warning_ignore("integer_division")
	var pequeno := tamanho / 2
	var a_esquerda := maxf(_largura(str(massa), pequeno), _largura(str(numero_atomico), pequeno))
	var do_simbolo := _largura(simbolo, tamanho)
	var texto_da_carga := Elementos.carga_no_simbolo(carga)
	var a_direita := _largura(texto_da_carga, pequeno)
	var total := a_esquerda + FOLGA + do_simbolo
	if a_direita > 0.0:
		total += FOLGA + a_direita
	return {"pequeno": pequeno, "esquerda": a_esquerda, "simbolo": do_simbolo, "carga": texto_da_carga,
		"total": total}


func _draw() -> void:
	if simbolo.is_empty():
		return
	var m := _medidas()
	var pequeno: int = m["pequeno"]
	var total: float = m["total"]
	var encolhe := minf(1.0, (size.x - 2.0) / maxf(total, 1.0))
	# A altura de uma letra maiúscula: 9 de cada 11 partes do tamanho.
	var maiuscula := float(tamanho) * 9.0 / 11.0
	var maiuscula_pequena := float(pequeno) * 9.0 / 11.0
	draw_set_transform((size * 0.5).round(), 0.0, Vector2.ONE * encolhe)
	var x := -total * 0.5
	# O pé do símbolo: o conjunto (do topo da massa ao pé do número atômico, que
	# desce um pouco abaixo do símbolo) fica no meio.
	var pe := roundf(maiuscula * 0.5 - 3.0)
	var esquerda: float = m["esquerda"]
	var texto_da_massa := str(massa)
	var texto_do_numero := str(numero_atomico)
	# Os dois números encostados no símbolo (alinhados à direita).
	draw_string(FONTE, Vector2(x + esquerda - _largura(texto_da_massa, pequeno), pe - maiuscula + maiuscula_pequena).round(),
		texto_da_massa, HORIZONTAL_ALIGNMENT_LEFT, -1, pequeno, cor_dos_numeros)
	draw_string(FONTE, Vector2(x + esquerda - _largura(texto_do_numero, pequeno), pe + 6.0).round(),
		texto_do_numero, HORIZONTAL_ALIGNMENT_LEFT, -1, pequeno, cor_dos_numeros)
	x += esquerda + FOLGA
	draw_string(FONTE, Vector2(x, pe).round(), simbolo, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)
	x += float(m["simbolo"]) + FOLGA
	var texto_da_carga: String = m["carga"]
	if not texto_da_carga.is_empty():
		draw_string(FONTE, Vector2(x, pe - maiuscula + maiuscula_pequena).round(), texto_da_carga,
			HORIZONTAL_ALIGNMENT_LEFT, -1, pequeno, cor_dos_numeros)
	draw_set_transform(Vector2.ZERO)


static func _largura(texto: String, tamanho_da_letra: int) -> float:
	if texto.is_empty():
		return 0.0
	return FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho_da_letra).x
