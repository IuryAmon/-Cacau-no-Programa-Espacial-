@tool
class_name CestaMacas
extends Area2D

# --- CESTA DE MAÇÃS (recupera a vida da Cacau) ---
#
# Chegando perto, o desenho do botão acende em cima da cesta — a tecla E, ou o
# □ de controle (a cena componentes/icone_interagir.tscn, a mesma da chapa
# soldada e da porta de metal). Apertando, a Cacau come as maçãs: a vida volta
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
#   Colisao       -> a área em que dá para comer (maior que a cesta, para não
#                    precisar parar exatamente em cima dela)
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

@onready var _sprite: Sprite2D = $Sprite
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

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var perto := _jogador != null and not _vazia
	if perto != _dica_visivel:
		_dica_visivel = perto
		_atualizar_dica()

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


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_jogador = body


func _on_body_exited(body: Node2D) -> void:
	if body == _jogador:
		_jogador = null
