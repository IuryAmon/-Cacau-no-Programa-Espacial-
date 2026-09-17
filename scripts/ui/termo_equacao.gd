class_name TermoEquacao
extends Control

# --- UM TERMO DA EQUAÇÃO (seta de cima, moléculas, seta de baixo) ---
#
# A coluna que o puzzle de balanceamento repete para cada substância: a seta
# de cima soma 1 ao coeficiente, a de baixo tira 1, e no meio aparecem tantas
# moléculas quanto o coeficiente — o mesmo visual do puzzle do foguete.
#
# COMO EDITAR NO EDITOR (scenes/ui/termo_equacao.tscn):
#   BotaoMais / BotaoMenos   a área de clique (Panel) e a seta (Seta) dentro.
#   Moleculas                o retângulo em que as moléculas se amontoam.
#   escala_molecula          tamanho dos desenhos da folha. É a MESMA para
#                            todas as fórmulas: um C₂H₂ continua maior que
#                            um H₂, como na folha.
#
# Quem usa (o puzzle) define "formula", pergunta "botao_no_ponto()" no clique
# e chama "mostrar_quantidade()" quando o coeficiente muda.

## Uma molécula nova acabou de pular na tela (o puzzle toca o "pop").
signal molecula_apareceu

## Fórmula do termo ("C2H2", "O2", "CO"...). O desenho vem da FolhaMoleculas.
@export var formula: String = "H2"
## Escala dos desenhos da folha dentro do termo.
@export_range(0.1, 2.0, 0.01) var escala_molecula: float = 0.62
## Quanto uma molécula avança por cima da vizinha no amontoado (0 = lado a
## lado; 0,3 = 30% por cima).
@export_range(0.0, 0.8, 0.01) var sobreposicao: float = 0.35

@onready var botao_mais: Control = $BotaoMais
@onready var botao_menos: Control = $BotaoMenos
@onready var moleculas: Control = $Moleculas


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
	return botao.get_global_rect().grow_individual(6.0 * escala.x, 15.0 * escala.y,
		6.0 * escala.x, 15.0 * escala.y)


## A seta clicada dá o "piscar" dela.
func animar_seta(sentido: int) -> void:
	var seta := (botao_mais if sentido > 0 else botao_menos).get_node_or_null("Seta") as AnimatedSprite2D
	if seta:
		seta.frame = 0
		seta.play("default")


## Refaz o amontoado com "quantidade" moléculas. Com "animar", cada uma entra
## com um pulo elástico, em cascata.
func mostrar_quantidade(quantidade: int, animar: bool = true) -> void:
	for filho in moleculas.get_children():
		filho.free()
	if quantidade <= 0:
		return
	var textura := FolhaMoleculas.textura(formula)
	if textura == null:
		return

	var tamanho := textura.get_size() * escala_molecula
	var passo := tamanho * (1.0 - sobreposicao)
	var colunas := 1 if quantidade == 1 else 2
	var linhas := ceili(float(quantidade) / colunas)
	var altura_total := tamanho.y + passo.y * (linhas - 1)
	for i in quantidade:
		@warning_ignore("integer_division")
		var linha := i / colunas
		# A última linha, se ficou com uma molécula só, vem centralizada.
		var nesta_linha := mini(colunas, quantidade - linha * colunas)
		var largura_linha := tamanho.x + passo.x * (nesta_linha - 1)
		var coluna := i % colunas
		var origem := Vector2(
			(moleculas.size.x - largura_linha) * 0.5 + coluna * passo.x,
			(moleculas.size.y - altura_total) * 0.5 + linha * passo.y)
		_criar_molecula(textura, origem, tamanho, i, animar)


func _criar_molecula(textura: Texture2D, pos: Vector2, tamanho: Vector2, indice: int, animar: bool) -> void:
	var sprite := TextureRect.new()
	sprite.texture = textura
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	# Reduzido, o desenho fica serrilhado no filtro de pixel art do projeto.
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = pos
	sprite.size = tamanho
	sprite.pivot_offset = tamanho / 2.0
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.rotation = deg_to_rad(randf_range(-6.0, 6.0))
	moleculas.add_child(sprite)

	# Os tweens são da própria molécula: quando o amontoado é refeito, eles
	# morrem junto com ela em vez de seguirem rodando no vazio.
	var atraso := indice * 0.03
	if animar:
		sprite.scale = Vector2.ZERO
		var entrada := sprite.create_tween()
		entrada.tween_interval(atraso)
		entrada.tween_callback(molecula_apareceu.emit)
		entrada.tween_property(sprite, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Balancinho sutil e contínuo, para as moléculas parecerem vivas.
	var duracao := randf_range(0.55, 0.75)
	var balanco := sprite.create_tween()
	balanco.tween_interval(atraso + 0.35)
	balanco.set_loops()
	balanco.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	balanco.tween_property(sprite, "position:y", pos.y - 3.0, duracao)
	balanco.tween_property(sprite, "position:y", pos.y, duracao)
