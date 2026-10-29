extends Node

# --- O MENU DE PAUSA (autoload "Pausa") ---
#
# ESC no teclado, START no controle (a ação "pausar"): o jogo para e sobe a
# tela de pausa (scripts/ui/tela_de_pausa.gd), com CONTINUAR, REINICIAR e MENU
# INICIAL. Vale em toda cena com a Cacau; no menu, no Laboratório e na
# introdução não há o que pausar.
#
# Este autoload só decide QUANDO a pausa pode abrir. Ela espera:
#   * nenhuma outra tela na frente: fala, ficha de item, puzzle, caderno,
#     tutorial (Interacao.ocupada) — e o jogo não estar parado por elas;
#   * nenhuma troca de cena no meio (a cortina das portas e a do menu);
#   * a Cacau viva e livre: nem morrendo, nem numa cutscene, nem andando
#     sozinha (o elevador, a porta) — nessas horas o jogo conta com o tempo
#     correndo, e as falas e os tweens das cenas seguiriam por baixo da pausa;
#   * o tempo andando normal (o congelamento de impacto do dash).
# O ESC que FECHA um puzzle ou o caderno não abre a pausa logo em seguida: ele
# nasceu em cima da tela e fica preso a ela até ser solto (Interacao).
#
# Um toque que chega numa hora dessas (o dash congelado, o fim do tranco de um
# golpe) não se perde: o pedido espera um pouco (ESPERA_DO_PEDIDO) e a pausa
# abre assim que der. Se ela morrer ou a cena trocar nesse meio-tempo, o pedido
# cai: renascer não abre a pausa sozinho.
#
# CENA COM PAUSA PRÓPRIA: o simulador do foguete tem o menu dele (continuar ou
# sair do foguete). Quem tem o seu entra no grupo GRUPO_PAUSA_PROPRIA, e este
# aqui não abre por cima.

## A tecla (ESC) e o botão (START) da pausa no mapa de entrada.
const ACAO := &"pausar"
## Acima do caderno aberto (100) e abaixo da barra de botões do controle (110),
## que mostra o que cada botão faz na pausa.
const CAMADA := 105
const GRUPO_PAUSA_PROPRIA := &"pausa_propria"
## Por quanto tempo um pedido feito numa hora em que a pausa não pode abrir
## continua valendo.
const ESPERA_DO_PEDIDO := 0.6

const SOM := preload("res://sounds/PauseButton.mp3")
const VOLUME_DO_SOM_DB := -6.0

var _tela: TelaDePausa = null
## Até quando (Time.get_ticks_msec) o último pedido de pausa vale. 0 = nenhum.
var _pedido_ate_ms: int = 0
## A cena em que o pedido foi feito.
var _cena_do_pedido: Node = null
var _som: AudioStreamPlayer


func _ready() -> void:
	# Com a árvore parada, o som do fechar ainda precisa tocar.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_som = AudioStreamPlayer.new()
	_som.name = "Som"
	_som.stream = SOM
	_som.volume_db = VOLUME_DO_SOM_DB
	add_child(_som)


func _unhandled_input(evento: InputEvent) -> void:
	if not evento.is_action_pressed(ACAO) or evento.is_echo():
		return
	if aberta() or get_tree().paused or not Interacao.livre_para(ACAO):
		return
	if _cacau() == null:
		return
	get_viewport().set_input_as_handled()
	_pedido_ate_ms = Time.get_ticks_msec() + int(ESPERA_DO_PEDIDO * 1000.0)
	_cena_do_pedido = get_tree().current_scene
	_atender_o_pedido()


func _process(_delta: float) -> void:
	if _pedido_ate_ms == 0:
		return
	# Abriu outra tela, a cena trocou, ela morreu ou o pedido já é velho: esquece.
	var cacau := _cacau()
	if Time.get_ticks_msec() > _pedido_ate_ms or get_tree().paused or Interacao.ocupada() \
			or get_tree().current_scene != _cena_do_pedido or cacau == null \
			or ("current_health" in cacau and cacau.current_health <= 0):
		_pedido_ate_ms = 0
		_cena_do_pedido = null
		return
	_atender_o_pedido()


func _atender_o_pedido() -> void:
	if pode_abrir():
		_pedido_ate_ms = 0
		_cena_do_pedido = null
		abrir()


## A pausa pode abrir agora? (Ver o topo do arquivo.)
func pode_abrir() -> bool:
	var arvore := get_tree()
	if aberta() or arvore.paused or Interacao.ocupada():
		return false
	if TransicaoDeCena.em_curso() or FadeTela.cobrindo(arvore) or Engine.time_scale < 1.0:
		return false
	if not arvore.get_nodes_in_group(GRUPO_PAUSA_PROPRIA).is_empty():
		return false
	var cacau := _cacau()
	if cacau == null:
		return false
	if "current_health" in cacau and cacau.current_health <= 0:
		return false
	if "pode_se_mover" in cacau and not cacau.pode_se_mover:
		return false
	if "animacao_controlada_externamente" in cacau and cacau.animacao_controlada_externamente:
		return false
	return true


## A Cacau da cena aberta (ou null, nas cenas sem ela).
func _cacau() -> Node:
	var cena := get_tree().current_scene
	var cacau := get_tree().get_first_node_in_group(&"player")
	if cena == null or cacau == null or not cena.is_ancestor_of(cacau):
		return null
	return cacau


## Para o jogo e sobe a tela de pausa. A tela mora numa camada dentro da cena:
## trocou de cena (REINICIAR, MENU INICIAL), ela vai junto.
func abrir() -> void:
	if aberta():
		return
	var cena := get_tree().current_scene
	if cena == null:
		return
	var camada := CanvasLayer.new()
	camada.name = "MenuDePausa"
	camada.layer = CAMADA
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	_tela = TelaDePausa.new()
	_tela.name = "TelaDePausa"
	_tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tela.mouse_filter = Control.MOUSE_FILTER_STOP
	camada.add_child(_tela)
	cena.add_child(camada)
	get_tree().paused = true
	_tocar_som()


## Fecha a pausa e o jogo segue de onde parou.
func continuar() -> void:
	if not aberta():
		return
	var camada := _tela.get_parent()
	Interacao.marcar_tela_aberta(_tela, false)
	_tela.visible = false
	_tela = null
	if camada != null:
		camada.queue_free()
	get_tree().paused = false
	_tocar_som()


## True com a tela de pausa na tela (inclusive enquanto a cortina do REINICIAR
## ou do MENU INICIAL escurece por cima dela).
func aberta() -> bool:
	return is_instance_valid(_tela) and _tela.is_inside_tree() and _tela.visible


func _tocar_som() -> void:
	_som.stop()
	_som.play()
