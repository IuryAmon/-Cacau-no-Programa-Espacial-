@tool
class_name CestaMacas
extends Area2D

# --- CESTA DE MAÇÃS (recupera a vida da Cacau) ---
#
# Chegando perto, o desenho do botão acende em cima da cesta — a tecla E, ou o
# □ de controle (a cena componentes/icone_interagir.tscn, a mesma da chapa
# soldada e da porta de metal) — e a cesta ganha um contorno branco, que
# pulsa de leve: é ele que diz QUAL objeto o botão vai usar. O contorno é uma
# textura montada no _ready a partir da própria arte (ver
# _textura_do_contorno), 1 texel em volta da silhueta, sem shader.
#
# Apertando, a Cacau come as maçãs: a vida volta
# (vida_recuperada pontos, sem passar da máxima), toca o RecuperandoVida.mp3 e
# no lugar fica só a cesta vazia, que dá uma amassadinha com a perda de peso.
#
# É UMA VEZ SÓ. A cesta vazia fica anotada no EstadoMundo: morrer (que recarrega
# a fase) ou sair e voltar para a cena não enche a cesta de novo — senão ir e
# voltar pela porta viraria cura infinita.
#
# COM A VIDA CHEIA ela não se gasta (ver so_com_vida_faltando): o botão continua
# aparecendo, mas o E só faz a cesta balançar, e as maçãs ficam para depois.
#
# A ARTE é a mesma folha de decoração do world1 (Decor.png), recortada do
# atlas: as duas cestas têm o mesmo corpo pixel a pixel, então esvaziar é só
# trocar o recorte do Sprite. Ele desenha em z_index 1: ATRÁS da personagem
# (z_index 2), que passa na frente da cesta, e ainda na frente do chão (os
# TileMapLayers ficam em 0 no world1 e abaixo disso nas fases). O botão (Dica)
# também fica em 1, atrás dela: por vir depois do Sprite na árvore, ainda
# desenha por cima da cesta.
#
# COMO EDITAR NO EDITOR:
#   posição do nó -> no CHÃO, no meio da cesta: a arte cresce para cima dele, e
#                    é em volta dele que ela amassa e balança
#   Dica          -> o botão E/□ em cima da cesta
#   Sprite/Contorno -> a linha em volta da cesta; a cor é o "modulate" dele
#                    (a textura só existe com o jogo rodando)
#   Colisao       -> a área em que dá para comer (maior que a cesta, para não
#                    precisar parar exatamente em cima dela) — é também onde
#                    o botão e o contorno acendem
#   Som           -> o RecuperandoVida.mp3; ajuste o volume_db por lá

const CENA := "res://scenes/fases/componentes/cesta_macas.tscn"

## Os dois recortes da Decor.png (32×16 px cada — dois tiles de 16).
const REGIAO_CHEIA := Rect2(352, 48, 32, 16)
const REGIAO_VAZIA := Rect2(320, 80, 32, 16)

## A amassada de quando as maçãs saem (escala da arte no primeiro instante) e
## quanto ela leva para voltar ao normal.
const AMASSADA := Vector2(1.2, 0.72)
const TEMPO_DA_AMASSADA := 0.4
## O "não" da vida cheia: quanto a cesta inclina para cada lado (rad).
const BALANCO_RECUSA := 0.12

## Quanto o contorno leva para acender (e para apagar quando ela se afasta).
const TEMPO_DE_ACENDER := 0.12
## Aceso, ele respira entre esta opacidade e a cheia, uma vez a cada
## TEMPO_DO_PULSO segundos.
const CONTORNO_ALFA_MIN := 0.55
const TEMPO_DO_PULSO := 1.0

## Quantos pontos de vida as maçãs devolvem. Nunca passa da vida máxima.
@export var vida_recuperada: int = 3
## Com a vida cheia, o E não gasta a cesta: ela só balança.
@export var so_com_vida_faltando: bool = true

## Emitido quando a Cacau come as maçãs.
signal consumida

var _jogador: Node2D = null
var _vazia: bool = false
# Estado do botão, para o ícone só ser religado na virada.
var _dica_visivel: bool = false
var _escala_da_arte: Vector2 = Vector2.ONE
var _tween: Tween
# Contorno: 0 = apagado, 1 = aceso; e o relógio do pulso.
var _brilho_do_contorno: float = 0.0
var _fase_do_pulso: float = 0.0

@onready var _sprite: Sprite2D = $Sprite
## A linha em volta da cesta. É filha do Sprite para amassar e balançar junto.
@onready var _contorno: Sprite2D = get_node_or_null("Sprite/Contorno")
## O desenho do botão que acende quando ela chega perto (ver IconeInteragir).
@onready var _dica: AnimatedSprite2D = get_node_or_null("Dica")
@onready var _som: AudioStreamPlayer2D = get_node_or_null("Som")


func _ready() -> void:
	_escala_da_arte = _sprite.scale
	if _dica:
		_dica.visible = false
	if Engine.is_editor_hint():
		return

	if EstadoMundo.ja_feito(self):
		_esvaziar()
		return

	if _contorno:
		_contorno.texture = _textura_do_contorno()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var perto := _jogador != null and not _vazia
	if perto != _dica_visivel:
		_dica_visivel = perto
		_atualizar_dica()
	_animar_contorno(delta)

	# pediu() por último: ele queima o toque, e só pode queimar quando a cesta
	# vai mesmo responder.
	if perto and Interacao.pediu():
		if so_com_vida_faltando and _vida_cheia():
			_balancar_recusando()
		else:
			comer()


## True depois que as maçãs foram comidas (nesta visita ou numa anterior).
func esta_vazia() -> bool:
	return _vazia


## Come as maçãs: devolve a vida, toca o som e deixa só a cesta.
func comer() -> void:
	if _vazia:
		return
	EstadoMundo.marcar_feito(self)
	_esvaziar()
	_dica_visivel = false
	_atualizar_dica()
	# De estalo, sem o apagar suave: a linha é a silhueta da cesta CHEIA.
	_brilho_do_contorno = 0.0
	_animar_contorno(0.0)

	if _jogador and _jogador.has_method("curar"):
		_jogador.curar(vida_recuperada)
	if _som:
		_som.play()

	# A cesta perde o peso das maçãs: amassa e volta, presa no chão (a arte
	# cresce para cima do nó, então a base não sai do lugar).
	_novo_tween()
	_sprite.scale = _escala_da_arte * AMASSADA
	_tween.tween_property(_sprite, "scale", _escala_da_arte, TEMPO_DA_AMASSADA) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	consumida.emit()


func _esvaziar() -> void:
	_vazia = true
	_sprite.region_rect = REGIAO_VAZIA


func _vida_cheia() -> bool:
	if _jogador == null or not ("current_health" in _jogador and "max_health" in _jogador):
		return false
	return _jogador.current_health >= _jogador.max_health


## O "agora não" da vida cheia: a cesta balança para os lados e para de pé.
func _balancar_recusando() -> void:
	_novo_tween()
	_sprite.rotation = 0.0
	_tween.tween_property(_sprite, "rotation", -BALANCO_RECUSA, 0.06)
	_tween.tween_property(_sprite, "rotation", BALANCO_RECUSA, 0.1)
	_tween.tween_property(_sprite, "rotation", -BALANCO_RECUSA * 0.5, 0.08)
	_tween.tween_property(_sprite, "rotation", 0.0, 0.06)


func _novo_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_sprite.scale = _escala_da_arte
	_sprite.rotation = 0.0
	_tween = create_tween()


## O botão só é prometido quando ela está por perto e ainda há maçãs.
func _atualizar_dica() -> void:
	if _dica == null:
		return
	_dica.visible = _dica_visivel
	if _dica_visivel and _dica.has_method("reiniciar"):
		_dica.reiniciar()


## O contorno segue o botão (_dica_visivel): acende quando ela entra na área,
## respira enquanto ela fica e apaga quando ela sai.
func _animar_contorno(delta: float) -> void:
	if _contorno == null:
		return
	var alvo := 1.0 if _dica_visivel else 0.0
	_brilho_do_contorno = move_toward(_brilho_do_contorno, alvo, delta / TEMPO_DE_ACENDER)
	_contorno.visible = _brilho_do_contorno > 0.0
	if not _contorno.visible:
		# O próximo acender começa do ponto mais claro do pulso.
		_fase_do_pulso = 0.0
		return
	_fase_do_pulso += delta
	var pulso := 0.5 + 0.5 * cos(TAU * _fase_do_pulso / TEMPO_DO_PULSO)
	# self_modulate, e não modulate: a cor escolhida no Inspector fica intacta.
	_contorno.self_modulate.a = _brilho_do_contorno * lerpf(CONTORNO_ALFA_MIN, 1.0, pulso)


## A textura do contorno: branca, com 1 texel aceso em volta da silhueta da
## cesta cheia. Ela é 1 texel maior que a arte para cada lado — a linha mora
## justamente onde a arte é transparente, inclusive fora do recorte (onde, na
## folha, já começa o desenho vizinho).
func _textura_do_contorno() -> Texture2D:
	var arte := _sprite.texture.get_image().get_region(Rect2i(REGIAO_CHEIA))
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


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_jogador = body


func _on_body_exited(body: Node2D) -> void:
	if body == _jogador:
		_jogador = null
