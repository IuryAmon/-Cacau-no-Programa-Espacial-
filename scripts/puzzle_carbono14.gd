extends CanvasLayer

# --- O PUZZLE DO ELEVADOR DE CARGA (corredores, fase 1) ---
#
# O terminal ao lado da plataforma só liga o guincho com a resposta certa, e a
# pergunta é a curiosidade do carbono-14 que o Dr. Chico contava no rádio,
# virada desafio:
#
#   QUAL ISÓTOPO RADIOATIVO OS CIENTISTAS USAM PARA DESCOBRIR A IDADE DE
#   FÓSSEIS E ARTEFATOS ARQUEOLÓGICOS DE ATÉ 50 MIL ANOS?
#
#   CARBONO-12   o carbono comum (quase todo o carbono do mundo): não é
#                radioativo
#   CARBONO-13   o outro carbono estável, bem mais raro
#   CARBONO-14   o radioativo: a resposta
#
# Cada resposta é uma caixinha de isótopo: o número de massa no canto, o
# símbolo e o nome. Errar não trava nada: a caixa treme, fica marcada de
# vermelho e o rodapé diz por que não é aquela. Acertou, a tela mostra
# ELEVADOR LIBERADO! com a caixa do carbono-14, e o E liga a plataforma.
#
# A tela é a dos outros puzzles da fase 1 (o monitor do bumerangue e do
# maçarico): a imagem do computador, o brilho do vidro, as linhas de
# varredura e o LED, que pisca vermelho até a resposta certa.
#
# ONDE MEXER:
#   PERGUNTA e ALTERNATIVAS (logo abaixo)   o texto e as respostas; CERTA diz
#                                           qual delas libera o elevador.
#   scenes/puzzle_carbono14.tscn            a tela: posições, fontes, cores e
#                                           sons. As caixas das respostas são
#                                           GrupoPergunta/Respostas/Resposta1..3
#                                           (os textos delas saem daqui).
#
# INTERFACE (a que o ComputadorPuzzle espera): sinal "puzzle_resolvido" e
# método "abrir_puzzle()".
# CONTROLES: mouse nas caixas; A/D ou ←/→ escolhem e ENTER ou ESPAÇO
# respondem; ESC fecha. No controle: o direcional pula de caixa em caixa, ✕
# responde, △ fecha e □ liga o elevador no fim (ver cursor_virtual.gd).
# DEBUG: a tecla L resolve na hora.

signal puzzle_resolvido

const PERGUNTA := "QUAL ISÓTOPO RADIOATIVO OS CIENTISTAS USAM PARA DESCOBRIR A IDADE DE FÓSSEIS E ARTEFATOS ARQUEOLÓGICOS DE ATÉ 50 MIL ANOS?"
## As respostas, da esquerda para a direita. "por_que_nao" é o que o rodapé
## diz quando a pessoa escolhe a errada.
const ALTERNATIVAS := [
	{"massa": 12, "nome": "Carbono-12", "por_que_nao": "O CARBONO-12 NÃO É RADIOATIVO: É O CARBONO COMUM"},
	{"massa": 13, "nome": "Carbono-13", "por_que_nao": "O CARBONO-13 TAMBÉM NÃO É RADIOATIVO"},
	{"massa": 14, "nome": "Carbono-14", "por_que_nao": ""},
]
## A que libera o elevador (índice em ALTERNATIVAS).
const CERTA := 2
const SIMBOLO := "C"

const TXT_INSTRUCAO := "RESPONDA PARA LIBERAR O ELEVADOR"
const TXT_CERTO := "CERTO: É O CARBONO-14!"
const TXT_LIGAR := "APERTE {interact} PARA LIGAR O ELEVADOR"

const COR_BORDA := Color(0.9, 0.95, 1, 0.9)
const COR_FOCO := Color(1, 0.85, 0)
const COR_ERRO := Color(1.0, 0.35, 0.3)
const COR_CERTO := Color(0.4, 1.0, 0.4)
const COR_TEXTO := Color(0.9, 0.95, 1, 1)
const COR_FUNDO := Color(0.05, 0.1, 0.18, 0.55)
const COR_FUNDO_FOCO := Color(0.16, 0.15, 0.05, 0.7)
const COR_LED_TRAVADO := Color(0.9, 0.12, 0.1)
const COR_LED_CERTO := Color(0.35, 0.95, 0.45)
const COR_LED_LIBERADO := Color(0.3, 0.75, 1.0)
## Quanto tempo o "CERTO" fica na tela antes do ELEVADOR LIBERADO!.
const ESPERA_DO_CERTO := 1.3

var travado: bool = false
var aguardando_fechamento: bool = false
## A caixa em foco (mouse em cima, teclas ou direcional). -1 = nenhuma.
var foco: int = -1
## As respostas erradas já tentadas nesta abertura: ficam marcadas.
var erradas: Array[bool] = []

# Abrir e fechar de novo invalida o que estava esperando um timer.
var _sessao: int = 0
var _tweens: Array = []
var _tempo: float = 0.0
var _rodape_texto: String = ""
var _rodape_padrao: String = ""
var _rodape_cursor: bool = false

@onready var tela: TextureRect = $RootControl/Tela
@onready var led: ColorRect = $RootControl/Tela/Led
@onready var display: Control = $RootControl/Tela/Display
@onready var rodape: Label = $RootControl/Tela/Display/Rodape
@onready var aura: ColorRect = $RootControl/Tela/Display/Aura
@onready var grupo_pergunta: Control = $RootControl/Tela/Display/GrupoPergunta
@onready var pergunta: Label = $RootControl/Tela/Display/GrupoPergunta/Pergunta
@onready var respostas: Array[Panel] = [
	$RootControl/Tela/Display/GrupoPergunta/Respostas/Resposta1,
	$RootControl/Tela/Display/GrupoPergunta/Respostas/Resposta2,
	$RootControl/Tela/Display/GrupoPergunta/Respostas/Resposta3,
]
@onready var grupo_liberado: Control = $RootControl/Tela/Display/GrupoLiberado
@onready var isotopo_liberado: Panel = $RootControl/Tela/Display/GrupoLiberado/Isotopo
@onready var audio_sucesso: AudioStreamPlayer = $AudioSucesso
@onready var audio_erro: AudioStreamPlayer = $AudioErro
@onready var audio_pop: AudioStreamPlayer = $AudioPop


func _ready() -> void:
	hide()
	set_process(false)
	# Controle: cursor nesta tela, e as teclas dos textos viram botões.
	add_to_group(CursorVirtual.GRUPO)
	Controle.rotular($RootControl/Instrucoes, $RootControl/Instrucoes.text, 2.0)
	IconesNoTexto.acoplar(rodape)
	Controle.mudou.connect(_ao_trocar_controle)

	pergunta.text = PERGUNTA
	for i in respostas.size():
		var caixa := respostas[i]
		_escrever_isotopo(caixa, ALTERNATIVAS[i])
		# Cada caixa com o estilo dela: a borda muda de cor sozinha.
		caixa.add_theme_stylebox_override("panel", _estilo_de(caixa).duplicate())
		caixa.set_meta("pos_base", caixa.position)
	_escrever_isotopo(isotopo_liberado, ALTERNATIVAS[CERTA])


func _escrever_isotopo(caixa: Panel, dados: Dictionary) -> void:
	(caixa.get_node("Massa") as Label).text = str(dados["massa"])
	(caixa.get_node("Simbolo") as Label).text = SIMBOLO
	(caixa.get_node("Nome") as Label).text = String(dados["nome"])


func _estilo_de(caixa: Panel) -> StyleBoxFlat:
	return caixa.get_theme_stylebox("panel") as StyleBoxFlat


# ------------------------- ABRIR E FECHAR -------------------------

func abrir_puzzle() -> void:
	_sessao += 1
	show()
	Interacao.marcar_tela_aberta(self, true)
	set_process(true)
	_resetar()

	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = false
	get_tree().paused = true
	_ligar_tela()


func fechar_puzzle(resolvido: bool) -> void:
	_sessao += 1
	hide()
	Interacao.marcar_tela_aberta(self, false)
	set_process(false)
	_matar_tweens()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	get_tree().paused = false
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = true
	if resolvido:
		puzzle_resolvido.emit()


func _resetar() -> void:
	_matar_tweens()
	travado = false
	aguardando_fechamento = false
	foco = -1
	erradas.clear()
	for i in respostas.size():
		erradas.append(false)
		respostas[i].position = respostas[i].get_meta("pos_base", respostas[i].position)
		respostas[i].scale = Vector2.ONE
	_tempo = 0.0

	display.scale = Vector2.ONE
	display.modulate = Color.WHITE
	aura.modulate.a = 1.0
	led.color = COR_LED_TRAVADO
	grupo_pergunta.show()
	grupo_pergunta.modulate = Color.WHITE
	grupo_liberado.hide()
	_definir_rodape(TXT_INSTRUCAO, true)
	_pintar_respostas()


# A tela "liga" como monitor de tubo: uma linha que abre na vertical.
func _ligar_tela() -> void:
	display.scale = Vector2(1.0, 0.02)
	display.modulate.a = 0.0
	var tween := _tween()
	tween.set_parallel(true)
	tween.tween_property(display, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(display, "modulate:a", 1.0, 0.16)


# ------------------------- ENTRADA -------------------------

func _process(delta: float) -> void:
	_tempo += delta
	if not travado:
		led.modulate.a = 1.0 if fmod(_tempo, 1.1) >= 0.5 else 0.55
	else:
		led.modulate.a = 1.0
	var cursor_visivel := _rodape_cursor and fmod(_tempo, 1.0) < 0.5
	var texto := _rodape_texto + ("_" if cursor_visivel else "")
	if rodape.text != texto:
		rodape.text = texto


func _input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	# A tela está por cima de tudo: o E que fecha o puzzle não pode sobrar para
	# o terminal que está logo atrás dela.
	if event.is_action_pressed(Interacao.ACAO):
		Interacao.consumir()

	if event is InputEventMouseMotion:
		_passar_o_mouse(event.position)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if aguardando_fechamento:
			fechar_puzzle(true)
			return
		var i := _resposta_no_ponto(event.position)
		if i >= 0:
			_responder(i)
		return

	var tecla: bool = event is InputEventKey and event.pressed and not event.echo
	if tecla and event.keycode == KEY_L:
		# DEBUG: resolve o puzzle na hora.
		fechar_puzzle(true)
		return
	# As teclas de sempre e, pelas ações do mapa, △/□/✕ do controle.
	if aguardando_fechamento:
		if (tecla and event.keycode in [KEY_ESCAPE, KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]) \
				or event.is_action_pressed("fechar") or event.is_action_pressed("ui_accept") \
				or event.is_action_pressed(Interacao.ACAO):
			fechar_puzzle(true)
		return
	if (tecla and event.keycode == KEY_ESCAPE) or event.is_action_pressed("fechar"):
		if not travado:
			fechar_puzzle(false)
		return
	if not tecla or travado:
		return
	match event.keycode:
		KEY_A, KEY_LEFT:
			_andar_o_foco(-1)
		KEY_D, KEY_RIGHT:
			_andar_o_foco(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if foco >= 0:
				_responder(foco)


func _andar_o_foco(sentido: int) -> void:
	if foco < 0:
		_focar(0 if sentido > 0 else respostas.size() - 1)
	else:
		_focar(clampi(foco + sentido, 0, respostas.size() - 1))


func _passar_o_mouse(pos: Vector2) -> void:
	var i := _resposta_no_ponto(pos)
	if i >= 0:
		_focar(i)
	var sobre := i >= 0 or aguardando_fechamento
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if sobre else Input.CURSOR_ARROW)


func _focar(i: int) -> void:
	if i == foco or travado:
		return
	foco = i
	audio_pop.play()
	_pintar_respostas()


## Qual caixa está debaixo deste ponto da tela (-1 = nenhuma).
func _resposta_no_ponto(pos: Vector2) -> int:
	if travado or not grupo_pergunta.visible:
		return -1
	for i in respostas.size():
		if retangulo_da_resposta(i).has_point(pos):
			return i
	return -1


## A caixa número "i", em coordenadas da tela (o monitor está em escala 1,2).
func retangulo_da_resposta(i: int) -> Rect2:
	return respostas[i].get_global_rect()


# ------------------------- CONTROLE (ver cursor_virtual.gd) -------------------------

## As três caixas, enquanto dá para responder.
func alvos_do_cursor() -> Array[Rect2]:
	var alvos: Array[Rect2] = []
	if travado or not grupo_pergunta.visible:
		return alvos
	for i in respostas.size():
		alvos.append(retangulo_da_resposta(i))
	return alvos


func dicas_do_controle() -> Array:
	if aguardando_fechamento:
		return [[Interacao.ACAO, "LIGAR O ELEVADOR"]]
	return [
		["analogico_esquerdo", "MOVER"],
		["direcional", "ESCOLHER"],
		["cruz", "RESPONDER"],
		["fechar", "SAIR"],
	]


## O rodapé final diz a tecla (ou o botão) que liga o elevador: trocou de
## teclado para controle com ele na tela, ele se reescreve.
func _ao_trocar_controle(_em_uso: bool) -> void:
	if aguardando_fechamento:
		_definir_rodape(Controle.texto(TXT_LIGAR, true), true)


# ------------------------- A RESPOSTA -------------------------

func _responder(i: int) -> void:
	if travado or i < 0 or i >= respostas.size():
		return
	foco = i
	if i == CERTA:
		_acertar()
	else:
		_errar(i)


func _errar(i: int) -> void:
	erradas[i] = true
	audio_erro.play()
	_pintar_respostas()
	_shake(respostas[i])
	_mostrar_aviso(String(ALTERNATIVAS[i]["por_que_nao"]), COR_ERRO, 2.6)


func _acertar() -> void:
	travado = true
	var sessao := _sessao
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	audio_sucesso.play()
	led.color = COR_LED_CERTO
	_pintar_respostas()
	_pulsar(respostas[CERTA])
	_definir_rodape(TXT_CERTO, false)
	rodape.add_theme_color_override("font_color", COR_CERTO)
	await get_tree().create_timer(ESPERA_DO_CERTO).timeout
	if sessao != _sessao:
		return
	_mostrar_liberado()


## Tela final: ELEVADOR LIBERADO! e a caixa do carbono-14. O rodapé diz como
## ligar o elevador.
func _mostrar_liberado() -> void:
	var sessao := _sessao
	var sai := _tween()
	sai.tween_property(grupo_pergunta, "modulate:a", 0.0, 0.3)
	await sai.finished
	if sessao != _sessao:
		return
	grupo_pergunta.hide()
	grupo_liberado.show()
	grupo_liberado.modulate.a = 0.0
	led.color = COR_LED_LIBERADO
	var entra := _tween()
	entra.tween_property(grupo_liberado, "modulate:a", 1.0, 0.3)
	_definir_rodape(Controle.texto(TXT_LIGAR, true), true)
	aguardando_fechamento = true


## A cor de cada caixa: certa (verde, depois de acertar), errada já tentada
## (vermelha e apagada), em foco (amarela) ou parada (a borda clara de sempre).
func _pintar_respostas() -> void:
	for i in respostas.size():
		var caixa := respostas[i]
		var estilo := _estilo_de(caixa)
		var borda := COR_BORDA
		var texto := COR_TEXTO
		var fundo := COR_FUNDO
		if travado and i == CERTA:
			borda = COR_CERTO
			texto = COR_CERTO
		elif erradas[i]:
			borda = COR_ERRO
			texto = Color(COR_TEXTO, 0.45)
		elif i == foco and not travado:
			borda = COR_FOCO
			texto = COR_FOCO
			fundo = COR_FUNDO_FOCO
		estilo.border_color = borda
		estilo.bg_color = fundo
		for nome: String in ["Massa", "Simbolo", "Nome"]:
			(caixa.get_node(nome) as Label).add_theme_color_override("font_color", texto)
		caixa.modulate.a = 0.55 if travado and i != CERTA else 1.0


# ------------------------- RODAPÉ -------------------------

func _definir_rodape(texto: String, com_cursor: bool) -> void:
	_rodape_texto = texto
	_rodape_padrao = texto
	_rodape_cursor = com_cursor
	rodape.remove_theme_color_override("font_color")


## Mensagem no rodapé; depois de "duracao" volta ao texto de antes.
func _mostrar_aviso(texto: String, cor: Color, duracao: float) -> void:
	var sessao := _sessao
	var padrao := _rodape_padrao
	var cursor := _rodape_cursor
	_rodape_texto = texto
	_rodape_cursor = false
	rodape.add_theme_color_override("font_color", cor)
	await get_tree().create_timer(duracao).timeout
	if sessao != _sessao or _rodape_texto != texto or travado:
		return
	_rodape_texto = padrao
	_rodape_cursor = cursor
	rodape.remove_theme_color_override("font_color")


# ------------------------- APOIO -------------------------

func _tween() -> Tween:
	var tween := create_tween()
	_tweens.append(tween)
	if _tweens.size() > 48:
		_tweens = _tweens.filter(func(t): return is_instance_valid(t) and t.is_valid())
	return tween


func _matar_tweens() -> void:
	for tween in _tweens:
		if is_instance_valid(tween) and tween.is_valid():
			tween.kill()
	_tweens.clear()


func _pulsar(alvo: Control) -> void:
	alvo.pivot_offset = alvo.size * 0.5
	var tween := _tween()
	tween.tween_property(alvo, "scale", Vector2(1.1, 1.1), 0.1) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(alvo, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _shake(alvo: Control) -> void:
	var origem: Vector2 = alvo.get_meta("pos_base", alvo.position)
	var tween := _tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(alvo, "position", origem + Vector2(6, 0), 0.05)
	tween.tween_property(alvo, "position", origem + Vector2(-6, 0), 0.05)
	tween.tween_property(alvo, "position", origem + Vector2(5, 0), 0.04)
	tween.tween_property(alvo, "position", origem + Vector2(-5, 0), 0.04)
	tween.tween_property(alvo, "position", origem, 0.03)
