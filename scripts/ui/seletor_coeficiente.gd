class_name SeletorCoeficiente
extends Control

# --- UM SELETOR DE COEFICIENTE (seta de cima, número, seta de baixo) ---
#
# O balanceamento do Laboratório no nível difícil não mostra as moléculas: é só
# a equação escrita. Cada coeficiente dela é um destes: o número com uma seta
# em cima (soma 1) e outra embaixo (tira 1). As setas são as do termo da
# equação dos puzzles da história (scenes/ui/termo_equacao.tscn): a mesma arte
# e o mesmo piscar.
#
# COMO EDITAR NO EDITOR (scenes/ui/seletor_coeficiente.tscn):
#   BotaoMais / BotaoMenos   a área de clique (Panel) e a seta (Seta) dentro.
#   Numero                   o coeficiente (quem usa escreve o número e a cor).
#
# Quem usa pergunta "botao_no_ponto()" no clique e chama "animar_seta()" quando
# a seta vale, como no SeletorParticula.

@onready var botao_mais: Control = $BotaoMais
@onready var botao_menos: Control = $BotaoMenos
@onready var numero: Label = $Numero


## +1 se o ponto (na tela) está na seta de cima, -1 na de baixo, 0 fora.
func botao_no_ponto(pos: Vector2) -> int:
	if retangulo_do_botao(1).has_point(pos):
		return 1
	if retangulo_do_botao(-1).has_point(pos):
		return -1
	return 0


## Área clicável da seta, na tela: a do desenho dela, com uma folga.
func retangulo_do_botao(sentido: int) -> Rect2:
	var botao := botao_mais if sentido > 0 else botao_menos
	var escala := botao.get_global_transform().get_scale()
	return botao.get_global_rect().grow_individual(2.0 * escala.x, 6.0 * escala.y,
		2.0 * escala.x, 6.0 * escala.y)


## A seta clicada dá o "piscar" dela.
func animar_seta(sentido: int) -> void:
	var seta := (botao_mais if sentido > 0 else botao_menos).get_node_or_null("Seta") as AnimatedSprite2D
	if seta:
		seta.frame = 0
		seta.play("default")
