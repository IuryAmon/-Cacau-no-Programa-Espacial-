class_name SeletorParticula
extends Control

# --- UM SELETOR DE PARTÍCULA (seta de cima, partícula, conta, seta de baixo) ---
#
# A coluna que o puzzle do carbono repete para cada conta do átomo (prótons,
# nêutrons, elétrons da camada K e da camada L): a seta de cima põe uma
# partícula no átomo, a de baixo tira, e no meio ficam a partícula e quantas
# dela já estão lá. As setas são as do termo da equação dos puzzles de
# balanceamento (scenes/ui/termo_equacao.tscn): a mesma arte e o mesmo piscar.
#
# COMO EDITAR NO EDITOR (scenes/ui/seletor_particula.tscn):
#   BotaoMais / BotaoMenos   a área de clique (Panel) e a seta (Seta) dentro.
#   Icone                    a partícula. É dela que as partículas do átomo
#                            copiam a arte e o tamanho, e é dali que elas saem.
#   Quantos                  a conta (o puzzle escreve o número e a cor).
#   Nome                     o que o seletor conta.
#
# No puzzle (scenes/puzzle_carbono.tscn) cada seletor é esta cena com os filhos
# editáveis: o Icone e o Nome de cada um são trocados lá. Quem usa pergunta
# "botao_no_ponto()" no clique e chama "animar_seta()" quando a seta vale.

@onready var botao_mais: Control = $BotaoMais
@onready var botao_menos: Control = $BotaoMenos
@onready var icone: TextureRect = $Icone
@onready var quantos: Label = $Quantos


## +1 se o ponto (na tela) está na seta de cima, -1 na de baixo, 0 fora.
func botao_no_ponto(pos: Vector2) -> int:
	if retangulo_do_botao(1).has_point(pos):
		return 1
	if retangulo_do_botao(-1).has_point(pos):
		return -1
	return 0


## Área clicável da seta, na tela. O Panel é pequeno e o sprite da seta (2x)
## sai por cima e por baixo dele: a área acompanha o desenho, não o Panel.
func retangulo_do_botao(sentido: int) -> Rect2:
	var botao := botao_mais if sentido > 0 else botao_menos
	var escala := botao.get_global_transform().get_scale()
	return botao.get_global_rect().grow_individual(6.0 * escala.x, 8.0 * escala.y,
		6.0 * escala.x, 8.0 * escala.y)


## A seta clicada dá o "piscar" dela.
func animar_seta(sentido: int) -> void:
	var seta := (botao_mais if sentido > 0 else botao_menos).get_node_or_null("Seta") as AnimatedSprite2D
	if seta:
		seta.frame = 0
		seta.play("default")
