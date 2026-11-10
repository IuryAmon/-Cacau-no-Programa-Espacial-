extends Node

# --- A ABERTURA DA HISTÓRIA, NO WORLD1 ---
#
# Logo depois da introdução (scripts/introducao.gd), o world1 abre como um
# plano de cinema:
#
#   1. a tela clareia com a câmera lá no alto: só o céu da tarde, as nuvens e
#      o topo da serra, sem HUD e em silêncio;
#   2. o nome do jogo (ui/titulo_do_jogo.gd) acende no céu, e a bossa nova do
#      world1 entra junto, de uma vez, já no volume normal;
#   3. a câmera desce devagar (o plano de grua do CameraJogador) até o lugar
#      onde a Cacau vai entrar, e o nome apaga no caminho;
#   4. a Cacau entra correndo pela esquerda até "destino_x", sozinha, sem
#      controle;
#   5. ela para: o controle, o HUD e o aviso de "Pressione ... para
#      movimentar-se" (BotaoMoviment) voltam.
#
# Só acontece na chegada pela introdução (EstadoMundo.abertura_pendente): a
# fase recarregada depois de uma morte, a volta do laboratório e a cena aberta
# direto no editor começam como sempre.
#
# A corrida é a mesma da Cacau abrindo espaço para a porta derreter
# (recuar_ate_x, no player.gd): a animação de correr, na velocidade dela.
#
# ONDE MEXER: os tempos e a altura da grua ficam no Inspector deste nó
# (AberturaDaHistoria, no world1), no grupo Plano de grua.

const TituloDoJogo := preload("res://scripts/ui/titulo_do_jogo.gd")
## A camada do nome do jogo: por cima do mundo e do HUD, embaixo da cortina de
## troca de cena (TransicaoDeCena, na 120).
const CAMADA_DO_TITULO := 50

## As partes da abertura, na ordem.
enum Etapa { NADA, TITULO, DESCIDA, CORRIDA, FIM }

## Ela terminou de entrar e o controle voltou.
signal terminou

## Onde ela para (x do mundo).
@export var destino_x: float = 940.0
## Onde ela começa: fora da tela, à esquerda, com o pé no chão do começo do
## mapa (posição do mundo).
@export var largada: Vector2 = Vector2(-90.0, 481.0)
## O aviso de movimento, que espera ela parar.
@export var aviso: NodePath = ^"../BotaoMoviment"
## Quanto o aviso leva para aparecer.
@export var duracao_do_aviso: float = 0.6

@export_group("Plano de grua")
## Quanto acima do enquadramento normal a câmera começa, em px do mundo.
@export var altura_da_grua: float = 1100.0
## Da tela clareando até o nome do jogo (e a música) aparecer.
@export var antes_do_titulo: float = 0.8
## O nome do jogo acendendo.
@export var acender_o_titulo: float = 1.2
## O nome parado no céu, antes de a câmera descer.
@export var titulo_no_ceu: float = 3.0
## A descida da câmera, do céu até o lugar da Cacau.
@export var descida: float = 5.5
## O nome apagando, já com a câmera descendo.
@export var apagar_o_titulo: float = 1.6
## Da câmera parada até a Cacau começar a correr.
@export var antes_da_cacau: float = 0.5
## Camadas do fundo que não podem ser vistas lá do alto: a imagem da base de
## lançamento (BG/BASE) é um retângulo que fica escondido atrás das árvores no
## jogo, mas com a câmera no céu as árvores descem e a borda dela aparece.
## Elas ficam apagadas e acendem no fim da descida, já atrás das árvores.
@export var escondidas_no_alto: Array[NodePath] = [^"../BG/BASE"]
## Em que ponto da descida (0 a 1) elas começam a acender; acabam quando a
## Cacau começa a correr. A borda só fica coberta pelas árvores bem no fim.
@export_range(0.0, 1.0, 0.01) var acendem_na_descida: float = 0.92

var _etapa := Etapa.NADA
var _titulo: TituloDoJogo
var _cortina: FadeTela
var _hud_escondido := false


func _ready() -> void:
	if not EstadoMundo.abertura_pendente:
		return
	EstadoMundo.abertura_pendente = false
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("recuar_ate_x"):
		return
	_abrir(player)


func _exit_tree() -> void:
	# A cena saiu no meio da abertura (o menu de pausa, uma morte...): o HUD
	# não pode ficar escondido para sempre.
	if _hud_escondido:
		_mostrar_o_hud()


## Em que parte a abertura está (Etapa).
func etapa() -> Etapa:
	return _etapa


## True do começo da abertura até a Cacau parar.
func em_andamento() -> bool:
	return _etapa != Etapa.NADA and _etapa != Etapa.FIM


## True enquanto ela está correndo para o lugar.
func correndo() -> bool:
	return _etapa == Etapa.CORRIDA


## O nome do jogo no céu (null fora da abertura).
func titulo() -> TituloDoJogo:
	return _titulo if is_instance_valid(_titulo) else null


func _abrir(player) -> void:
	var cena := owner if owner != null else get_tree().current_scene
	_etapa = Etapa.TITULO
	var no_aviso := get_node_or_null(aviso) as CanvasItem
	if no_aviso:
		no_aviso.visible = false
	player.global_position = largada
	player.velocity = Vector2.ZERO
	player.pode_se_mover = false
	CameraJogador.encaixar(player)
	var camera := player.get_node_or_null("Camera2D") as CameraJogador
	if camera:
		camera.comecar_acima(altura_da_grua)
	var escondidas := _esconder_o_que_nao_se_ve_do_alto()
	# A bossa nova espera o nome do jogo.
	TrilhaSonora.esperar_a_deixa(cena)
	_esconder_o_hud(cena)
	_por_o_titulo()

	# 1. A cortina da troca de cena abre no céu.
	while TransicaoDeCena.em_curso():
		await get_tree().process_frame
		if not is_inside_tree():
			return
	if not await _esperar(antes_do_titulo):
		return

	# 2. O nome do jogo e a música.
	TrilhaSonora.dar_a_deixa(0.0)
	create_tween().tween_property(_titulo, "alfa", 1.0, acender_o_titulo)
	if not await _esperar(acender_o_titulo + titulo_no_ceu):
		return

	# 3. A câmera desce, e o nome apaga no caminho.
	_etapa = Etapa.DESCIDA
	create_tween().tween_property(_titulo, "alfa", 0.0, apagar_o_titulo) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if not escondidas.is_empty():
		var volta := create_tween().set_parallel(true)
		for no in escondidas:
			volta.tween_property(no, "modulate:a", 1.0, descida * (1.0 - acendem_na_descida) + antes_da_cacau) \
				.set_delay(descida * acendem_na_descida)
	if camera:
		await camera.descer_ao_lugar(descida).finished
	if not await _esperar(antes_da_cacau):
		return
	_titulo.get_parent().queue_free()
	_titulo = null

	# 4. A Cacau entra correndo.
	_etapa = Etapa.CORRIDA
	await player.recuar_ate_x(destino_x)
	if not is_inside_tree():
		return

	# 5. Ela parou: o jogo começa.
	_etapa = Etapa.FIM
	_mostrar_o_hud()
	if no_aviso:
		no_aviso.modulate.a = 0.0
		no_aviso.visible = true
		create_tween().tween_property(no_aviso, "modulate:a", 1.0, duracao_do_aviso)
	terminou.emit()


## Apaga as "escondidas_no_alto" e devolve quem foi apagado.
func _esconder_o_que_nao_se_ve_do_alto() -> Array[CanvasItem]:
	var escondidas: Array[CanvasItem] = []
	for caminho in escondidas_no_alto:
		var no := get_node_or_null(caminho) as CanvasItem
		if no != null:
			no.modulate.a = 0.0
			escondidas.append(no)
	return escondidas


## O nome do jogo, apagado, numa camada por cima de tudo (menos da cortina).
func _por_o_titulo() -> void:
	var camada := CanvasLayer.new()
	camada.name = "TituloDoJogo"
	camada.layer = CAMADA_DO_TITULO
	_titulo = TituloDoJogo.new()
	_titulo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_titulo.alfa = 0.0
	camada.add_child(_titulo)
	add_child(camada)


func _esconder_o_hud(cena: Node) -> void:
	# A FadeTela fica transparente: está aqui só para tirar o HUD de cena.
	_cortina = FadeTela.criar(cena)
	_cortina.esconder_huds(cena)
	_hud_escondido = true


func _mostrar_o_hud() -> void:
	_hud_escondido = false
	if is_instance_valid(_cortina):
		_cortina.restaurar_huds()
		_cortina.queue_free()
	_cortina = null
	# Os HUDs autoload (fora da cena) voltam sempre, mesmo com a cortina já
	# saindo junto com a cena (ver FadeTela.esconder_huds).
	if is_inside_tree():
		for nome in FadeTela.HUDS_AUTOLOAD:
			var hud := get_tree().root.get_node_or_null(nome)
			if hud is CanvasLayer:
				hud.visible = true


## Espera "segundos" (parando junto com o jogo pausado). False se a cena saiu.
func _esperar(segundos: float) -> bool:
	if segundos > 0.0:
		await create_tween().tween_interval(segundos).finished
	return is_inside_tree()
