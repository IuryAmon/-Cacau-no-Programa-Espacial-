class_name CilindroDoTelhado
extends Area2D

# --- UM CILINDRO DE AMOSTRA, NO TELHADO DA TORRE (fase 2) ---
#
# O prêmio da subida: os cilindros de amostra VAZIOS, de pé no telhado em
# fileiras e colunas (a estante CilindrosDeAr monta todos — ver
# cilindros_do_telhado.gd). Chegando perto, o botão (E/□) acende só no MAIS
# PERTO dela; o E pega aquele — a ficha de coleta sobe (item
# MissaoNitrogenio.ID_CILINDRO_VAZIO) e a Cacau comenta para onde ele vai
# ("fala_ao_pegar"): descer de elevador e levar ao compressor.
#
# UM DE CADA VEZ: enquanto ela já tem o dela (na mochila, preso no compressor,
# cheio de ar líquido, na coluna — ou o nitrogênio até já foi colhido, ver
# cacau_tem_um), o E num cilindro vira a fala "fala_ja_tem_um" e ele fica onde
# está.
#
# O que ela pegou não volta: nem morrendo, nem saindo e voltando (EstadoMundo,
# pelo caminho do nó), nem depois. Os outros continuam lá.
#
# NA FRENTE OU ATRÁS DELA: anda-se para o fundo e para a frente no telhado. O
# cilindro com a base ACIMA da última linha do sprite dela (o pé desenhado,
# Player.sola_no_chao — uns pixels abaixo da base da colisão) passa por trás
# dela; com a base abaixo, na frente. No pulo vale a linha do chão dela. Ele
# não segura a Cacau (o telhado é uma faixa; ver "ANDAR NA FAIXA" em
# player.gd).
#
# COMO EDITAR NO EDITOR (componentes/cilindro_do_telhado.tscn):
#   posição do nó -> no CHÃO, onde o cilindro fica de pé
#   Sprite        -> a arte (assets/fase nitrogenio/Cilindro de Ar.png)
#   Dica          -> o botão E/□
#   Luz           -> o brilho em volta (uma LuzPontual; na estante, só a dela)

## O grupo de todos os cilindros do telhado: o mais perto acende o E.
const GRUPO := &"cilindros_do_telhado"

## A Cacau, depois de pegar.
@export var fala_ao_pegar: String = "cacau_cilindro_pego"
## A Cacau, apertando E num cilindro quando já tem o dela.
@export var fala_ja_tem_um: String = "res://timelines/cacau_um_cilindro_basta.dtl"

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
	add_to_group(GRUPO)
	if _dica:
		_dica.visible = false
	body_entered.connect(func(corpo: Node2D) -> void:
		if corpo.is_in_group("player"):
			_jogador = corpo)
	body_exited.connect(func(corpo: Node2D) -> void:
		if corpo == _jogador:
			_jogador = null)


## Este cilindro já saiu do telhado (foi ele que ela pegou).
static func ja_foi_pego(no: Node) -> bool:
	return EstadoMundo.ja_feito(no)


## A Cacau já tem o cilindro dela: na mochila, preso no compressor, cheio de
## amostra, na coluna — ou o nitrogênio até já foi colhido. Conta também o que
## está sendo pego agora mesmo (a ficha de coleta ainda aberta).
static func cacau_tem_um(arvore: SceneTree) -> bool:
	if MissaoNitrogenio.tem_cilindro_vazio() or MissaoNitrogenio.cilindro_acoplado \
			or MissaoNitrogenio.compressor_concluido():
		return true
	if arvore != null:
		for cilindro in arvore.get_nodes_in_group(GRUPO):
			if cilindro is CilindroDoTelhado and (cilindro as CilindroDoTelhado)._pegou:
				return true
	return false


## Ainda de pé no telhado. Vira false no instante do E, antes mesmo de a ficha
## abrir.
func ainda_no_lugar() -> bool:
	return not _pegou and not is_queued_for_deletion()


func _process(delta: float) -> void:
	if _pegou:
		return
	_tempo += delta
	if _luz and "energia" in _luz:
		_luz.energia = 0.75 + 0.15 * sin(_tempo * 2.2)
	_ordenar_com_a_cacau()
	var perto := _jogador != null and _sou_o_mais_perto()
	if perto != _dica_visivel:
		_dica_visivel = perto
		if _dica:
			_dica.visible = perto
			if perto and _dica.has_method("reiniciar"):
				_dica.reiniciar()
	if perto and Interacao.pediu():
		if cacau_tem_um(get_tree()):
			if not fala_ja_tem_um.is_empty():
				DialogicBridge.falar(fala_ja_tem_um)
		else:
			_pegar()


## Na frente dela quando a base dele está mais para a frente que os pés dela.
func _ordenar_com_a_cacau() -> void:
	var cacau := get_tree().get_first_node_in_group("player") as Node2D
	if cacau == null:
		return
	var sola: float
	if cacau.has_method("sola_no_chao"):
		sola = cacau.sola_no_chao()
	elif cacau.has_method("altura_dos_pes"):
		sola = cacau.altura_dos_pes()
	else:
		return
	# A base dele acima da última linha do sprite dela (o pé desenhado): atrás.
	z_index = cacau.z_index + 1 if global_position.y > sola else 0


## Dos cilindros em que ela encosta, só o mais perto dos pés dela acende o E.
func _sou_o_mais_perto() -> bool:
	var pes := _pes_da_cacau()
	var minha := pes.distance_squared_to(global_position)
	for outro in get_tree().get_nodes_in_group(GRUPO):
		if outro == self or not outro is CilindroDoTelhado:
			continue
		var cilindro := outro as CilindroDoTelhado
		if cilindro._jogador == null or not cilindro.ainda_no_lugar():
			continue
		var dele := pes.distance_squared_to(cilindro.global_position)
		# Empate: fica com o primeiro da árvore, para o E não piscar entre dois.
		if dele < minha or (dele == minha and cilindro.get_index() < get_index()):
			return false
	return true


func _pes_da_cacau() -> Vector2:
	if _jogador.has_method("altura_dos_pes"):
		return Vector2(_jogador.global_position.x, _jogador.altura_dos_pes())
	return _jogador.global_position


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
	# Sai do lugar num pulinho, como quem é tirado de lá.
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
