class_name PortaDaFornalha
extends Area2D

# --- A PORTA DA FORNALHA (a chapa que tampa a boca do forno) ---
#
# Fica encostada ao lado da fornalha (é filha da cena retorta.tscn) e só entra
# no puzzle no fim. Depois que a temperatura chega no ponto, a fornalha fica
# pegando fogo de boca aberta, À ESPERA dela (ver RetortaCarbonizacao):
#
#   1. a Cacau apanha a porta com E — ela vai para a mochila, como a lenha;
#   2. com a porta na mochila, E na fornalha fecha a boca do forno;
#   3. quando a brasa apaga, a porta salta de volta para o lugar dela e o
#      carvão sai atrás.
#
# Fora dessa espera ela é só cenário: sem balão e sem responder ao E. Quem liga
# e desliga isso é a fornalha, por `disponivel`.
#
# COMO EDITAR NO EDITOR (dentro de retorta.tscn):
#   posição do nó -> onde a porta fica encostada (e para onde ela volta)
#   Sprite        -> a arte: assets/Lab/fornalha/PortaDaFornalha.png. É a mesma
#                    do ícone da mochila e a mesma do nó PortaFechada da
#                    fornalha (a porta já na boca do forno). Ela é desenhada na
#                    paleta e no tamanho de pixel da fornalha (16 x 18 px,
#                    escala 3) e cobre a boca inteira, com o brilho em volta.
#                    A inclinação de "encostada" é a rotação DESTE nó Sprite
#
# Sem texto no mapa: quem avisa que dá para apanhar é o balão de exclamação
# (ExclamacaoAnimada), o mesmo das toras.

## Id no inventário. Só existe uma porta, então o id é fixo.
const ID := "porta_da_fornalha"
const NOME := "Porta da Fornalha"
const DESCRICAO := "Chapa de ferro que tampa a boca do forno. Fechada, não deixa o oxigênio entrar."

## A volta para o lugar quando o carvão sai (ver voltar_de): altura do salto,
## quanto ela leva no ar, e o quique da chegada.
const ALTURA_DO_SALTO := 54.0
const TEMPO_DO_SALTO := 0.4
const ALTURA_DO_QUIQUE := 7.0
const TEMPO_DO_QUIQUE := 0.09
## Voltas que ela dá no ar (termina na inclinação de encostada).
const GIRO_NO_AR := TAU

## A Cacau acabou de guardar a porta na mochila.
signal apanhada

## Dá para apanhar agora? A fornalha liga isto enquanto espera pela porta.
var disponivel: bool = false

var _jogador_perto: bool = false
# Estado do balão, para o PopupFX só ser chamado na virada.
var _aviso_visivel: bool = false
# Voltando da boca do forno para o lugar: no ar não se apanha.
var _no_ar: bool = false
var _repouso: Vector2 = Vector2.ZERO
var _inclinacao: float = 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _exclamacao: AnimatedSprite2D = get_node_or_null("ExclamacaoAnimada")


## A porta está com a Cacau?
static func na_mochila() -> bool:
	return Inventario.tem_item(ID)


## Tira a porta da mochila (para fechar o forno). Devolve false se ela não
## estava lá.
static func tirar_da_mochila() -> bool:
	if not Inventario.tem_item(ID):
		return false
	Inventario.remover_item(ID)
	return true


func _ready() -> void:
	_repouso = position
	_inclinacao = _sprite.rotation
	if _exclamacao:
		_exclamacao.visible = false
	# Ela saiu da fase com a porta na mochila: não está mais encostada aqui.
	visible = not na_mochila()

	body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_jogador_perto = true)
	body_exited.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_jogador_perto = false)


func _process(_delta: float) -> void:
	_atualizar_aviso()
	# Interacao.pediu() queima o toque de E, então fica por ÚLTIMO.
	if _pode_apanhar() and Interacao.pediu():
		apanhar()


func textura() -> Texture2D:
	return _sprite.texture if _sprite else null


## Guarda a porta na mochila e some com ela daqui — usado tanto pelo E quanto
## por atalhos de teste.
func apanhar() -> void:
	Inventario.adicionar_item(ID, NOME, textura(), DESCRICAO)
	visible = false
	_atualizar_aviso()
	apanhada.emit()


## A porta salta de `origem` (ponto GLOBAL: a boca do forno) de volta para o
## lugar em que fica encostada, girando no ar e quicando na chegada.
func voltar_de(origem: Vector2) -> void:
	var pai := get_parent() as Node2D
	var partida := pai.to_local(origem) if pai else origem
	position = partida
	_sprite.rotation = _inclinacao - GIRO_NO_AR
	visible = true
	_no_ar = true

	var tween := create_tween()
	tween.tween_method(_passo_do_salto.bind(partida), 0.0, 1.0, TEMPO_DO_SALTO)
	tween.tween_property(self, "position:y", _repouso.y - ALTURA_DO_QUIQUE, TEMPO_DO_QUIQUE)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", _repouso.y, TEMPO_DO_QUIQUE)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _no_ar = false)


## Um arco: o x anda por igual e o y sobe e desce como uma parábola. `t` vai
## de 0 (na boca do forno) a 1 (no lugar).
func _passo_do_salto(t: float, partida: Vector2) -> void:
	position = partida.lerp(_repouso, t) + Vector2(0.0, -4.0 * ALTURA_DO_SALTO * t * (1.0 - t))
	_sprite.rotation = lerpf(_inclinacao - GIRO_NO_AR, _inclinacao, t)


func _pode_apanhar() -> bool:
	return disponivel and visible and _jogador_perto and not _no_ar


func _atualizar_aviso() -> void:
	if _exclamacao == null:
		return
	var mostrar := _pode_apanhar()
	if mostrar == _aviso_visivel:
		return
	_aviso_visivel = mostrar
	if mostrar:
		PopupFX.mostrar(_exclamacao)
	else:
		PopupFX.esconder(_exclamacao)
