class_name Destilador
extends Area2D

# --- A COLUNA DE DESTILAÇÃO (fase do nitrogênio) ---
#
# A torre de aço do mapa. Chegando perto, o desenho do botão acende na frente
# dela (a tecla E, ou o □ de controle: componentes/icone_interagir.tscn, o
# mesmo da cesta de maçãs) e a coluna ganha um contorno branco que pulsa de
# leve. Apertando, o jogo para e o Dr. Chico explica, pelo rádio, como ela
# separa o ar: a coluna "sai" do mapa, vem para o meio da tela, vira o desenho
# de raio X e mostra as moléculas trabalhando lá dentro. Toda essa tela é
# scenes/explicacao_destilador.tscn (scripts/explicacao_destilador.gd).
#
# Dá para ver quantas vezes quiser: cada E recomeça a explicação do zero. A
# primeira vez fica anotada no EstadoMundo (ja_explicou), para o dia em que a
# fase quiser cobrar isso antes de liberar os puzzles.
#
# A ARTE é "assets/fase nitrogenio/coluna de destilação.png", que tem dois
# desenhos lado a lado: o de aço (o que se vê aqui, pelo region_rect do
# Sprite) e o de raio X (que só a tela da explicação usa).
#
# COMO EDITAR NO EDITOR:
#   posição do nó -> no CHÃO, no meio da coluna: a arte cresce para cima dele
#   Sprite        -> a arte de aço. Desenha em z_index 1: atrás da Cacau
#                    (z_index 2), na frente do cenário
#   Sprite/Contorno -> a linha em volta; a cor é o "modulate" dele (a textura
#                    só existe com o jogo rodando)
#   Dica          -> o botão E/□
#   Colisao       -> a área em que o botão aparece e o E funciona
#   explicacao    -> a cena da tela que o E abre

const CENA := "res://scenes/fases/componentes/destilador.tscn"

## Quanto o contorno leva para acender (e para apagar quando ela se afasta).
const TEMPO_DE_ACENDER := 0.12
## Aceso, ele respira entre esta opacidade e a cheia, uma vez a cada
## TEMPO_DO_PULSO segundos.
const CONTORNO_ALFA_MIN := 0.55
const TEMPO_DO_PULSO := 1.0

## A tela da explicação que o E abre.
@export var explicacao: PackedScene

## A explicação abriu / acabou de fechar.
signal explicacao_abriu
signal explicacao_fechou

var _jogador: Node2D = null
var _tela: ExplicacaoDestilador = null
# Estado do botão, para o ícone só ser religado na virada.
var _dica_visivel: bool = false
# Contorno: 0 = apagado, 1 = aceso; e o relógio do pulso.
var _brilho_do_contorno: float = 0.0
var _fase_do_pulso: float = 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _contorno: Sprite2D = get_node_or_null("Sprite/Contorno")
@onready var _dica: AnimatedSprite2D = get_node_or_null("Dica")


func _ready() -> void:
	if _dica:
		_dica.visible = false
	if _contorno:
		_contorno.texture = _textura_do_contorno()
	body_entered.connect(_ao_entrar)
	body_exited.connect(_ao_sair)
	# A tela já fica montada (escondida) desde a chegada na fase: montada só
	# no primeiro E, o jogo engasgava bem na hora de a coluna sair do mapa.
	_montar_a_tela.call_deferred()


func _process(delta: float) -> void:
	var perto := _jogador != null and not explicando()
	if perto != _dica_visivel:
		_dica_visivel = perto
		_atualizar_dica()
	_animar_contorno(delta)

	# pediu() por último: ele queima o toque, e só pode queimar quando a
	# coluna vai mesmo responder.
	if perto and Interacao.pediu():
		explicar()


## Abre a explicação do Dr. Chico (o que o E faz).
func explicar() -> void:
	if explicando():
		return
	_montar_a_tela()
	if _tela == null:
		push_warning("%s: falta a cena da explicação (campo 'explicacao')." % name)
		return
	_olhar_para_a_coluna()
	# A tela para o jogo, e este nó para junto: o botão e o contorno têm de
	# sumir já, senão ficariam acesos por baixo dela.
	_dica_visivel = false
	_atualizar_dica()
	_brilho_do_contorno = 0.0
	_animar_contorno(0.0)
	# O desenho da tela nasce exatamente em cima da coluna do mapa e a leva
	# embora: a de cá some enquanto a explicação está aberta.
	var na_tela := retangulo_na_tela()
	_sprite.visible = false
	_tela.abrir(na_tela)
	explicacao_abriu.emit()


func _montar_a_tela() -> void:
	if _tela != null or explicacao == null:
		return
	_tela = explicacao.instantiate() as ExplicacaoDestilador
	add_child(_tela)
	_tela.pousou.connect(_ao_pousar)
	_tela.fechou.connect(_ao_fechar)


## True enquanto a explicação está na tela.
func explicando() -> bool:
	return _tela != null and _tela.esta_aberta()


## True depois que a explicação foi vista até fechar, pelo menos uma vez.
func ja_explicou() -> bool:
	return EstadoMundo.ja_feito(self)


## A tela da explicação (montada na chegada à fase, escondida até o E).
func tela() -> ExplicacaoDestilador:
	return _tela


## Onde a arte de aço aparece na tela agora, em px da tela do jogo.
func retangulo_na_tela() -> Rect2:
	return _sprite.get_global_transform_with_canvas() * _sprite.get_rect()


## O desenho da tela voltou para cima da coluna: ela reaparece no lugar.
func _ao_pousar() -> void:
	_sprite.visible = true


func _ao_fechar() -> void:
	_sprite.visible = true
	EstadoMundo.marcar_feito(self)
	explicacao_fechou.emit()


func _olhar_para_a_coluna() -> void:
	var cacau := get_tree().get_first_node_in_group("player") as Node2D
	var sprite_dela := cacau.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D if cacau else null
	if sprite_dela and not is_equal_approx(cacau.global_position.x, global_position.x):
		sprite_dela.flip_h = global_position.x < cacau.global_position.x


## O botão só é prometido quando ela está por perto.
func _atualizar_dica() -> void:
	if _dica == null:
		return
	_dica.visible = _dica_visivel
	if _dica_visivel and _dica.has_method("reiniciar"):
		_dica.reiniciar()


## O contorno segue o botão: acende quando ela entra na área, respira enquanto
## ela fica e apaga quando ela sai.
func _animar_contorno(delta: float) -> void:
	if _contorno == null:
		return
	var alvo := 1.0 if _dica_visivel else 0.0
	_brilho_do_contorno = move_toward(_brilho_do_contorno, alvo, delta / TEMPO_DE_ACENDER)
	_contorno.visible = _brilho_do_contorno > 0.0
	if not _contorno.visible:
		_fase_do_pulso = 0.0
		return
	_fase_do_pulso += delta
	var pulso := 0.5 + 0.5 * cos(TAU * _fase_do_pulso / TEMPO_DO_PULSO)
	# self_modulate, e não modulate: a cor escolhida no Inspector fica intacta.
	_contorno.self_modulate.a = _brilho_do_contorno * lerpf(CONTORNO_ALFA_MIN, 1.0, pulso)


## A textura do contorno: branca, com 1 texel aceso em volta da silhueta da
## coluna (o mesmo jeito da cesta de maçãs). Ela é 1 texel maior que a arte
## para cada lado, porque a linha mora onde a arte é transparente.
func _textura_do_contorno() -> Texture2D:
	var folha := _sprite.texture.get_image()
	if folha.is_compressed():
		folha.decompress()
	var arte := folha.get_region(Rect2i(_sprite.region_rect))
	var largura := arte.get_width() + 2
	var altura := arte.get_height() + 2
	var linha := Image.create_empty(largura, altura, false, Image.FORMAT_RGBA8)
	for y in altura:
		for x in largura:
			# (x, y) da linha é o texel (x - 1, y - 1) da arte.
			if _opaco(arte, x - 1, y - 1):
				continue
			if _opaco(arte, x - 2, y - 1) or _opaco(arte, x, y - 1) \
					or _opaco(arte, x - 1, y - 2) or _opaco(arte, x - 1, y):
				linha.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(linha)


func _opaco(imagem: Image, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= imagem.get_width() or y >= imagem.get_height():
		return false
	return imagem.get_pixel(x, y).a > 0.5


func _ao_entrar(corpo: Node2D) -> void:
	if corpo.is_in_group("player"):
		_jogador = corpo


func _ao_sair(corpo: Node2D) -> void:
	if corpo == _jogador:
		_jogador = null
