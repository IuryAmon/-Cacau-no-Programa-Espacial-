extends Node

# --- ÁRBITRO DA TECLA E (autoload "Interacao") ---
#
# Antes, cada coisa interativa (gaiola, jaleco, samambaia, cientista, itens do
# chão, receptores, escotilha do foguete) olhava a tecla sozinha, com
# Input.is_action_just_pressed("interact") dentro do próprio _process. Só que o
# E também é a tecla que passa a fala do Dialogic, a que fecha o popup do
# inventário e a que fecha os puzzles — então um único toque conseguia disparar
# duas coisas de uma vez. Era assim que, parada perto da gaiola, a Cacau pulava
# a fala da cutscene do foguete E abria o painel do puzzle no mesmo toque.
#
# Agora ninguém olha o Input direto: todo mundo pergunta aqui. Duas regras:
#   1. um toque de E vale UMA ação — o primeiro que pedir leva;
#   2. enquanto há diálogo, popup ou puzzle na tela, o E é deles, e o cenário
#      atrás da tela não recebe nada.
#
# A regra 2 tem uma pegadinha: o mesmo toque que FECHA a última fala já chega
# no _process com o diálogo encerrado (o input é entregue antes dos _process do
# frame). Por isso este nó também escuta o input direto: todo _input roda antes
# de qualquer _unhandled_input, que é onde o Dialogic passa a fala, então aqui o
# toque ainda é visto "em cima" do diálogo e já é queimado.
#
# A mesma pegadinha vale para as ações de gameplay, e com o controle ela
# aparece toda hora: o ✕ que passa a última fala é o botão de pular, o ○ que
# sai do puzzle é o dash, o □ que abre a gaiola é o bumerangue. Um toque que
# nasce com tela aberta fica PRESO a ela até ser solto — quem lê ação de
# gameplay pergunta "livre_para(acao)" antes de agir.

## Ação do E no mapa de entrada do projeto.
const ACAO := "interact"

## Telas que seguram o E enquanto estão abertas entram neste grupo
## (ver "marcar_tela_aberta").
const GRUPO_TELA := "tela_usa_tecla_e"

## Ações do mundo que um toque feito em cima de uma tela não pode disparar
## depois que ela fecha (ver "livre_para").
const ACOES_DO_MUNDO: Array[StringName] = [&"jump", &"arremessar", &"arremessar_mouse",
	&"dash", &"usar_macarico", &"luz", &"lanterna", &"alternar_mira"]

# O toque atual já virou ação? Os dois zeram sozinhos quando a tecla é solta.
var _toque_usado: bool = false
# O toque atual chegou com alguma tela já aberta? Se sim, ele é da tela.
var _toque_de_tela: bool = false
# Ações apertadas com tela aberta: continuam presas até a tecla ser solta.
var _acoes_presas: Dictionary = {}


func _ready() -> void:
	# Continua arbitrando mesmo se alguma tela pausar a árvore.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A janela avisa de todo toque ANTES de qualquer nó: nem o puzzle que marca
	# o evento como tratado esconde dela o botão que o fechou.
	get_tree().root.window_input.connect(_ao_receber_entrada)


func _ao_receber_entrada(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventJoypadMotion:
		return
	if not event.is_pressed() or event.is_echo() or not ocupada():
		return
	for acao in ACOES_DO_MUNDO:
		if InputMap.has_action(acao) and event.is_action_pressed(acao):
			_acoes_presas[acao] = true


func _input(event: InputEvent) -> void:
	# Se o E chegou com alguma tela aberta, ele é dela: fica marcado aqui para
	# não sobrar nada para o cenário quando essa tela fechar ainda neste frame.
	if event.is_action_pressed(ACAO) and ocupada():
		_toque_de_tela = true
		consumir()


func _process(_delta: float) -> void:
	# Soltou a tecla: o próximo toque é um toque novo.
	if not Input.is_action_pressed(ACAO):
		_toque_usado = false
		_toque_de_tela = false
	# O "just_released" segura a trava mais um quadro: toque tão rápido que
	# apertou e soltou no mesmo quadro ainda chega como "just_pressed" nele.
	for acao in _acoes_presas.keys():
		if not Input.is_action_pressed(acao) and not Input.is_action_just_released(acao):
			_acoes_presas.erase(acao)


## O mundo pode usar esta ação agora? Não com tela aberta — e nem depois que
## ela fecha, se o toque nasceu em cima dela: é assim que o ✕ que passa a
## última fala não faz a Cacau pular e o ○ que sai do puzzle não vira dash.
func livre_para(acao: StringName) -> bool:
	return not ocupada() and not toque_preso(acao)


## True enquanto a tecla da ação segue apertada desde um toque feito em cima de
## uma tela (mesmo que a tela já tenha fechado).
func toque_preso(acao: StringName) -> bool:
	return _acoes_presas.has(acao)


## True se o toque de E (□ no controle) deste quadro já virou ação de alguém.
## O bumerangue divide o □ com a interação e só é arremessado quando ninguém
## usou o toque.
func toque_foi_usado() -> bool:
	return _toque_usado


## Pede o toque de E deste frame. Devolve true no máximo uma vez por toque, e
## nunca enquanto alguma tela estiver com a tecla.
## Marca o toque como usado, então deixe sempre por ÚLTIMO no "if" — assim só
## consome quando quem perguntou realmente vai agir.
func pediu() -> bool:
	if not Input.is_action_just_pressed(ACAO):
		return false
	if ocupada():
		return false
	return consumir()


## True quando o toque de E deste frame chegou com a tela de quem pergunta já
## aberta — ou seja, o toque é da tela e não do mundo. É assim que o popup do
## inventário sabe que pode fechar sem fechar no mesmo toque que o abriu.
func toque_de_tela() -> bool:
	return _toque_de_tela and Input.is_action_just_pressed(ACAO)


## Queima o toque atual sem perguntar nada, para ele não vazar para o cenário
## atrás da tela. É para quem trata o E por conta própria (puzzles, caixa de
## fala do player) — essas telas agem sozinhas, isto aqui só protege o mundo.
## Devolve false se o toque já tinha sido queimado por outra pessoa.
func consumir() -> bool:
	if _toque_usado:
		return false
	_toque_usado = true
	return true


## True enquanto o E pertence a alguma tela, e não ao mundo.
func ocupada() -> bool:
	if Dialogic.current_timeline != null:
		return true
	if Inventario.popup_aberto:
		return true
	for tela in get_tree().get_nodes_in_group(GRUPO_TELA):
		# Rede de segurança: se alguém escondeu a tela sem avisar, ela não
		# continua segurando a tecla.
		if "visible" in tela and not tela.visible:
			continue
		return true
	return false


## Liga/desliga uma tela como dona do E enquanto ela estiver aberta.
func marcar_tela_aberta(tela: Node, aberta: bool) -> void:
	if aberta:
		if not tela.is_in_group(GRUPO_TELA):
			tela.add_to_group(GRUPO_TELA)
	elif tela.is_in_group(GRUPO_TELA):
		tela.remove_from_group(GRUPO_TELA)
