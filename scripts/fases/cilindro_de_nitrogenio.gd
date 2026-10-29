class_name CilindroDeNitrogenio
extends Area2D

# --- O CILINDRO DE NITROGÊNIO (a amostra do elemento N, fase 2) ---
#
# O prêmio da fase do nitrogênio: o cilindro VERDE com o N₂ que a coluna de
# destilação separou do ar (quase puro: um pouquinho de oxigênio e argônio
# evapora junto, ver TelaDaDestilacao). Fica escondido até a destilação acabar
# (MissaoNitrogenio.nitrogenio_destilado); aí ele salta da saída da coluna,
# quica no chão e fica ali, brilhando. Chegando perto, o botão (E/□) acende;
# o E pega a AMOSTRA DO ELEMENTO N (AmostraChonps): a ficha de coleta sobe, ela
# vai para a mochila e a Cacau comenta ("fala_ao_pegar"). O resto é o de
# sempre: levar ao receptor do painel CHONPS, no laboratório.
#
# Pego uma vez, não volta (Progresso.conquistou_celula("N")).
#
# COMO EDITAR NO EDITOR:
#   posição do nó  -> no CHÃO, onde o cilindro fica parado
#   destilador     -> a coluna de destilação: é da saída dela que ele salta
#   Sprite         -> a arte (assets/fase nitrogenio/cilindro de nitrogenio.png)
#   Dica           -> o botão E/□
#   Luz            -> o brilho verde em volta (uma LuzPontual)

## A coluna de destilação da sala: ele aparece quando ela avisa.
@export var destilador: NodePath
## A Cacau, depois de pegar.
@export var fala_ao_pegar: String = "cacau_tem_nitrogenio"

var _jogador: Node2D = null
var _pronto: bool = false
var _dica_visivel: bool = false
var _tempo: float = 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _dica: AnimatedSprite2D = get_node_or_null("Dica")
@onready var _luz: Node2D = get_node_or_null("Luz")
@onready var _som: AudioStreamPlayer2D = get_node_or_null("Som")


func _ready() -> void:
	if Progresso.conquistou_celula("N"):
		queue_free()
		return
	if _dica:
		_dica.visible = false
	body_entered.connect(func(corpo: Node2D) -> void:
		if corpo.is_in_group("player"):
			_jogador = corpo)
	body_exited.connect(func(corpo: Node2D) -> void:
		if corpo == _jogador:
			_jogador = null)
	var coluna := get_node_or_null(destilador)
	if coluna and coluna.has_signal("nitrogenio_pronto"):
		coluna.nitrogenio_pronto.connect(_aparecer.bind(true))
	_mostrar(MissaoNitrogenio.nitrogenio_destilado)
	_pronto = MissaoNitrogenio.nitrogenio_destilado


func _mostrar(sim: bool) -> void:
	visible = sim
	monitoring = sim
	if _luz:
		_luz.visible = sim


## Salta da saída da coluna e quica até o lugar dele.
func _aparecer(com_salto: bool) -> void:
	_mostrar(true)
	if not com_salto:
		_pronto = true
		return
	var coluna := get_node_or_null(destilador) as Node2D
	var de := coluna.global_position + Vector2(0, -60) if coluna else global_position + Vector2(0, -80)
	_sprite.global_position = de
	_sprite.scale = Vector2(0.4, 0.4)
	var salto := create_tween()
	salto.set_parallel(true)
	salto.tween_property(_sprite, "position:x", 0.0, 0.55).set_trans(Tween.TRANS_SINE)
	salto.tween_property(_sprite, "scale", Vector2(2, 2), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	salto.tween_method(_altura_do_salto.bind(_sprite.position.y), 0.0, 1.0, 0.55)
	await salto.finished
	var quique := create_tween().set_trans(Tween.TRANS_QUAD)
	quique.tween_property(_sprite, "position:y", -10.0, 0.12).set_ease(Tween.EASE_OUT)
	quique.tween_property(_sprite, "position:y", 0.0, 0.12).set_ease(Tween.EASE_IN)
	await quique.finished
	if _som and _som.stream:
		_som.play()
	_pronto = true


## Uma parábola: do alto da coluna até o chão do nó, passando por cima.
func _altura_do_salto(t: float, y_inicial: float) -> void:
	_sprite.position.y = lerpf(y_inicial, 0.0, t) - sin(t * PI) * 60.0


func _process(delta: float) -> void:
	if not visible:
		return
	_tempo += delta
	if _pronto:
		# Flutua um tiquinho, como os itens do jogo.
		_sprite.position.y = roundf(-2.0 + sin(_tempo * 2.4) * 2.0)
	if _luz and "energia" in _luz:
		_luz.energia = 0.8 + 0.2 * sin(_tempo * 3.0)
	var perto := _pronto and _jogador != null
	if perto != _dica_visivel:
		_dica_visivel = perto
		if _dica:
			_dica.visible = perto
			if perto and _dica.has_method("reiniciar"):
				_dica.reiniciar()
	if perto and Interacao.pediu():
		_pegar()


func _pegar() -> void:
	_pronto = false
	_mostrar(false)
	if _dica:
		_dica.visible = false
	AmostraChonps.coletar("N")
	# A fala vem depois da ficha de coleta fechar.
	while Inventario.popup_aberto or Interacao.ocupada():
		await get_tree().process_frame
		if not is_inside_tree():
			return
	await get_tree().create_timer(0.3).timeout
	if not fala_ao_pegar.is_empty():
		DialogicBridge.falar(fala_ao_pegar)
	queue_free()
