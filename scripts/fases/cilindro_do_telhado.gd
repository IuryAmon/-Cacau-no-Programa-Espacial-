class_name CilindroDoTelhado
extends Area2D

# --- O CILINDRO DE AMOSTRA, NO TELHADO DA TORRE (fase 2) ---
#
# O prêmio da subida: o cilindro de amostra VAZIO, preso no suporte lá em
# cima. Chegando perto, o botão (E/□) acende; o E pega o cilindro — a ficha de
# coleta sobe (item MissaoNitrogenio.ID_CILINDRO_VAZIO) e a Cacau comenta para
# onde ele vai ("fala_ao_pegar"): descer de elevador e levar ao compressor.
#
# Pego uma vez, não volta: nem morrendo, nem saindo e voltando (EstadoMundo),
# nem depois — preso no compressor, cheio de ar líquido ou até estourado, ele
# continua sendo o mesmo cilindro (MissaoNitrogenio).
#
# COMO EDITAR NO EDITOR:
#   posição do nó -> no CHÃO, onde o cilindro fica de pé
#   Sprite        -> a arte (assets/fase nitrogenio/Cilindro de Ar.png)
#   Dica          -> o botão E/□
#   Luz           -> o brilho em volta (uma LuzPontual)

## A Cacau, depois de pegar.
@export var fala_ao_pegar: String = "cacau_cilindro_pego"

var _jogador: Node2D = null
var _dica_visivel: bool = false
var _tempo: float = 0.0
var _pegou: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _dica: AnimatedSprite2D = get_node_or_null("Dica")
@onready var _luz: Node2D = get_node_or_null("Luz")
@onready var _som: AudioStreamPlayer2D = get_node_or_null("Som")


func _ready() -> void:
	if ja_foi_pego(self):
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


## O cilindro já saiu do telhado: está na mochila, preso no compressor, cheio
## de amostra, na coluna — ou o nitrogênio até já foi colhido.
static func ja_foi_pego(no: Node) -> bool:
	return EstadoMundo.ja_feito(no) or MissaoNitrogenio.tem_cilindro_vazio() \
		or MissaoNitrogenio.cilindro_acoplado or MissaoNitrogenio.compressor_concluido()


## Ainda de pé no suporte — o telhado não deixa a Cacau descer sem ele (ver
## fase2_telhado.gd). Vira false no instante do E, antes mesmo de a ficha abrir.
func ainda_no_lugar() -> bool:
	return not _pegou and not is_queued_for_deletion()


func _process(delta: float) -> void:
	if _pegou:
		return
	_tempo += delta
	if _luz and "energia" in _luz:
		_luz.energia = 0.75 + 0.15 * sin(_tempo * 2.2)
	var perto := _jogador != null
	if perto != _dica_visivel:
		_dica_visivel = perto
		if _dica:
			_dica.visible = perto
			if perto and _dica.has_method("reiniciar"):
				_dica.reiniciar()
	if perto and Interacao.pediu():
		_pegar()


func _pegar() -> void:
	_pegou = true
	EstadoMundo.marcar_feito(self)
	if _dica:
		_dica.visible = false
	if _som and _som.stream:
		_som.play()

	if Inventario.tela_hud_referencia != null:
		Inventario.tela_hud_referencia.exibir_popup(MissaoNitrogenio.NOME_CILINDRO_VAZIO, MissaoNitrogenio.TEXTURA_CILINDRO_VAZIO,
			MissaoNitrogenio.DESCRICAO_CILINDRO_VAZIO, MissaoNitrogenio.ID_CILINDRO_VAZIO)
	else:
		Inventario.adicionar_item(MissaoNitrogenio.ID_CILINDRO_VAZIO, MissaoNitrogenio.NOME_CILINDRO_VAZIO,
			MissaoNitrogenio.TEXTURA_CILINDRO_VAZIO, MissaoNitrogenio.DESCRICAO_CILINDRO_VAZIO)
	# Some do suporte num pulinho, como quem é tirado de lá.
	var saida := create_tween().set_parallel(true)
	saida.tween_property(_sprite, "position:y", _sprite.position.y - 18.0, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	saida.tween_property(_sprite, "modulate:a", 0.0, 0.22)
	if _luz:
		saida.tween_property(_luz, "modulate:a", 0.0, 0.3)
	# A fala vem depois da ficha de coleta fechar.
	while Inventario.popup_aberto or Interacao.ocupada():
		await get_tree().process_frame
		if not is_inside_tree():
			return
	await get_tree().create_timer(0.3).timeout
	if not fala_ao_pegar.is_empty():
		DialogicBridge.falar(fala_ao_pegar)
	queue_free()
