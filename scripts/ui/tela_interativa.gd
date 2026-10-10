class_name TelaInterativa
extends Control

# --- A BASE DAS TELAS DO MENU E DO LABORATÓRIO ---
#
# O menu principal, o menu do Laboratório e cada atividade dele (montar átomos,
# balancear equações, destilar misturas, a tabela periódica) são cenas de tela
# cheia, fora da história: não têm a Cacau nem o mundo. O nó raiz de cada uma
# tem um script que estende este aqui, e o que todas têm em comum mora nesta
# base:
#
#   VOLTAR      ESC (△ ou ○ no controle) leva à cena "cena_de_volta": o menu do
#               Laboratório, para as atividades; o menu principal, para ele.
#   MOLDURA     o aviso da tecla de voltar no canto e, com "titulo" preenchido,
#               a plaquinha com o nome da tela no alto.
#   ALVOS       tudo o que dá para clicar. A tela registra cada um
#               (registrar_alvo) com o retângulo dele e o que fazer no clique;
#               a base cuida do resto: achar o que está sob o ponteiro, trocar
#               a seta pela mãozinha, repetir enquanto o botão fica segurado
#               (as setas de pôr partículas) e dizer a quem desenha qual alvo
#               está em foco.
#   TECLAS      com "navegar_com_teclas" (os menus), as setas, o WASD, o
#               direcional e o analógico levam o foco de um alvo a outro, e
#               ENTER, ESPAÇO, E ou ✕ apertam o que está em foco. As teclas
#               chegam pelos eventos; o direcional e o analógico, pelo passo
#               com repetição do autoload Controle (passo_navegacao).
#   CONTROLE    sem ela (as atividades), a tela usa o cursor do controle, como
#               os puzzles da história: o analógico leva o cursor, o direcional
#               pula de alvo em alvo e o ✕ clica (ver cursor_virtual.gd).
#   SONS        tocar("pop"), tocar("erro")... os mesmos sons dos puzzles.
#
# QUEM ESTENDE não escreve _ready, _process nem _input: escreve os ganchos
# _ao_abrir(), _a_cada_quadro(delta) e _ao_receber(event), que esta base chama
# na hora certa. (No Godot 4 o _ready de uma classe filha substitui o da mãe;
# com os ganchos, ninguém precisa lembrar de chamar o da mãe.)
#
# Os cliques são lidos nos eventos (event.position), e não pelos botões do
# Godot: é o que o cursor do controle pede e o que deixa os testes clicarem de
# verdade sem janela.

## A pessoa pediu para sair (a troca de cena já começou).
signal saindo
## A tela pediu um dos SONS (o nome dele). É por aqui que os testes sabem que o
## som saiu: um estalo curto já acabou de tocar um quadro depois.
signal som_tocado(nome: String)

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

const SONS := {
	"pop": preload("res://sounds/POP.mp3"),
	"tirar": preload("res://sounds/drag.mp3"),
	"erro": preload("res://sounds/AcessoNegado.mp3"),
	"sucesso": preload("res://sounds/PuzzleConcluido2.mp3"),
	"certo": preload("res://sounds/check.mp3"),
	"passo": preload("res://sounds/Blip2.wav"),
	"botao": preload("res://sounds/PauseButton.mp3"),
}
## O volume de cada som, em dB (os que não estão aqui tocam em 0).
const VOLUMES := {"erro": 2.0, "sucesso": 2.0, "passo": -8.0, "botao": -6.0, "certo": -2.0}

## Segurando um alvo que repete: o primeiro repeteco vem depois deste tempo...
const REPETICAO_ATRASO := 0.36
## ...e os seguintes vão ficando mais rápidos, deste intervalo até aquele.
const REPETICAO_LENTA := 0.12
const REPETICAO_RAPIDA := 0.022
## Quanto tempo segurando até chegar na repetição mais rápida.
const REPETICAO_RAMPA := 1.8

## A altura do meio da plaquinha do título.
const ALTURA_DO_TITULO := 36.0

## O nome da tela, na plaquinha do alto. Vazio = sem plaquinha.
@export var titulo: String = ""
## Para onde o ESC leva. Vazio = o ESC não faz nada (o menu principal).
@export_file("*.tscn") var cena_de_volta: String = TransicaoDeCena.CENA_LABORATORIO
## O que o aviso do canto diz que o ESC faz. Vazio = sem aviso.
@export var texto_de_voltar: String = "voltar"
## Onde o aviso fica (o canto de cima à esquerda dele) e a cor da letra.
@export var lugar_do_aviso: Vector2 = Vector2(30, 20)
@export var cor_do_aviso: Color = Color(0.65, 0.65, 0.8)
## Ligado (os menus), o foco anda pelas teclas e pelo direcional, e a tela não
## usa o cursor do controle. Desligado (as atividades), usa.
@export var navegar_com_teclas: bool = false

var _alvos: Array[Dictionary] = []
## O nome do alvo em foco: sob o ponteiro, ou escolhido pelas teclas ("" = nenhum).
var _em_foco: String = ""
## O alvo com o botão do mouse segurado em cima, e há quanto tempo.
var _segurado: String = ""
var _tempo_segurado: float = 0.0
var _proxima_repeticao: float = 0.0
var _ponteiro: Vector2 = Vector2(-1.0, -1.0)
var _de_saida: bool = false
var _tweens: Array[Tween] = []
var _tocadores := {}
var _moldura: Control
var _aviso_de_voltar: Label


func _ready() -> void:
	# A tela segura a tecla E (nada do mundo existe atrás dela) e ganha a barra
	# de comandos do controle; o cursor dele, só sem "navegar_com_teclas".
	add_to_group(CursorVirtual.GRUPO)
	Interacao.marcar_tela_aberta(self, true)
	_montar_a_moldura()
	_ao_abrir()


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _process(delta: float) -> void:
	_repetir(delta)
	# O direcional e o analógico do controle, nos menus: um passo por toque e,
	# segurando, um a cada tanto (Controle.passo_navegacao). Não dá para ler o
	# analógico pelos eventos como as teclas: empurrado, ele manda um evento a
	# cada tremida do polegar, e o foco atravessaria a tela num toque só.
	if navegar_com_teclas and not _de_saida and not TransicaoDeCena.em_curso():
		var passo := Controle.passo_navegacao()
		if passo != Vector2i.ZERO:
			_dar_passo(Vector2(passo))
	_a_cada_quadro(delta)


func _input(event: InputEvent) -> void:
	if _de_saida or TransicaoDeCena.em_curso():
		return
	if event is InputEventMouseMotion:
		_ponteiro = event.position
		_focar_sob_o_ponteiro()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_ponteiro = event.position
		_focar_sob_o_ponteiro()
		if event.pressed:
			if _alvo_no_ponto(_ponteiro).is_empty():
				_segurado = ""
			elif _apertar_o_foco():
				get_viewport().set_input_as_handled()
				return
		else:
			_segurado = ""
	if _ao_receber(event):
		get_viewport().set_input_as_handled()
		return
	if navegar_com_teclas and _navegar(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("fechar") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_ao_pedir_para_voltar()


# ─────────────────────────────────────────────────────────────
# OS GANCHOS (o que cada tela escreve)
# ─────────────────────────────────────────────────────────────

## A tela acabou de abrir: é aqui que ela registra os alvos e arruma o começo.
func _ao_abrir() -> void:
	pass


func _a_cada_quadro(_delta: float) -> void:
	pass


## Um toque que não era clique em alvo nenhum. Devolva true se a tela usou o
## toque (ele então não vira "voltar" nem passa adiante).
func _ao_receber(_event: InputEvent) -> bool:
	return false


## ESC, △ ou ○. Uma tela com algo aberto por cima (a ficha de um elemento)
## fecha isso em vez de sair.
func _ao_pedir_para_voltar() -> void:
	voltar()


## O foco passou para outro alvo (ou saiu de todos): a tela pode querer se
## redesenhar.
func _ao_mudar_o_foco(_nome: String) -> void:
	pass


## Só com "navegar_com_teclas": uma seta do teclado, o direcional ou o
## analógico deram um passo nesta direção. Devolva true se a tela usou o passo
## (a ficha aberta da tabela periódica troca de elemento); senão, ele leva o
## foco para o alvo vizinho.
func _ao_dar_passo(_direcao: Vector2) -> bool:
	return false


# ─────────────────────────────────────────────────────────────
# SAIR
# ─────────────────────────────────────────────────────────────

func voltar() -> void:
	ir_para(cena_de_volta)


## Troca de cena pela cortina. Daqui em diante a tela não responde a mais nada.
func ir_para(cena: String) -> void:
	if _de_saida or cena.is_empty():
		return
	if TransicaoDeCena.ir_para(get_tree(), cena) == null:
		return
	_de_saida = true
	_segurado = ""
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	tocar("botao")
	saindo.emit()


func de_saida() -> bool:
	return _de_saida


# ─────────────────────────────────────────────────────────────
# OS ALVOS
# ─────────────────────────────────────────────────────────────

## Registra uma coisa clicável.
##   nome         como a tela (e o teste) se referem a ela
##   retangulo    devolve onde ela está na tela agora (Rect2)
##   ao_apertar   o que fazer no clique
##   disponivel   (opcional) devolve se ela pode ser clicada agora
##   repete       segurando o botão, o clique se repete, cada vez mais rápido
func registrar_alvo(nome: String, retangulo: Callable, ao_apertar: Callable,
		disponivel: Callable = Callable(), repete: bool = false) -> void:
	esquecer_alvo(nome)
	_alvos.append({"nome": nome, "retangulo": retangulo, "ao_apertar": ao_apertar,
		"disponivel": disponivel, "repete": repete})


func esquecer_alvo(nome: String) -> void:
	for i in range(_alvos.size() - 1, -1, -1):
		if _alvos[i]["nome"] == nome:
			_alvos.remove_at(i)
	if _em_foco == nome:
		_em_foco = ""
	if _segurado == nome:
		_segurado = ""


## Esquece todos os alvos cujo nome começa assim (os de uma lista refeita).
func esquecer_alvos(comeco_do_nome: String) -> void:
	for i in range(_alvos.size() - 1, -1, -1):
		if String(_alvos[i]["nome"]).begins_with(comeco_do_nome):
			esquecer_alvo(_alvos[i]["nome"])


func tem_alvo(nome: String) -> bool:
	return not _alvo(nome).is_empty()


## Os nomes de todos os alvos registrados, na ordem do registro.
func nomes_dos_alvos() -> PackedStringArray:
	var nomes := PackedStringArray()
	for alvo in _alvos:
		nomes.append(alvo["nome"])
	return nomes


## O alvo pode ser clicado agora?
func alvo_disponivel(nome: String) -> bool:
	var alvo := _alvo(nome)
	return not alvo.is_empty() and _disponivel(alvo)


## Onde o alvo está na tela agora (sem área se ele não existe).
func retangulo_do_alvo(nome: String) -> Rect2:
	var alvo := _alvo(nome)
	return (alvo["retangulo"] as Callable).call() if not alvo.is_empty() else Rect2()


## O nome do alvo em foco ("" = nenhum): quem desenha um botão usa isto para
## acendê-lo.
func alvo_em_foco() -> String:
	return _em_foco


func alvo_segurado() -> String:
	return _segurado


## Põe o foco num alvo (o primeiro cartão de um menu, ao abrir).
func focar(nome: String) -> void:
	if nome == _em_foco or (nome != "" and not alvo_disponivel(nome)):
		return
	_em_foco = nome
	_ao_mudar_o_foco(nome)


## Faz o que o clique no alvo faria (se ele estiver disponível). Devolve se fez.
func apertar(nome: String) -> bool:
	var alvo := _alvo(nome)
	if alvo.is_empty() or not _disponivel(alvo) or _de_saida:
		return false
	(alvo["ao_apertar"] as Callable).call()
	return true


func _alvo(nome: String) -> Dictionary:
	for alvo in _alvos:
		if alvo["nome"] == nome:
			return alvo
	return {}


func _disponivel(alvo: Dictionary) -> bool:
	var pergunta: Callable = alvo["disponivel"]
	return not pergunta.is_valid() or bool(pergunta.call())


## O alvo disponível sob o ponto: o registrado por último vence (ele é o que
## está desenhado por cima).
func _alvo_no_ponto(ponto: Vector2) -> Dictionary:
	for i in range(_alvos.size() - 1, -1, -1):
		var alvo := _alvos[i]
		if _disponivel(alvo) and ((alvo["retangulo"] as Callable).call() as Rect2).has_point(ponto):
			return alvo
	return {}


func _focar_sob_o_ponteiro() -> void:
	var alvo := _alvo_no_ponto(_ponteiro)
	var novo := String(alvo.get("nome", ""))
	# Nos menus, tirar o mouse de cima de um cartão não apaga o foco: ele pode
	# ter sido posto ali pelas teclas, e o mouse só esbarrou.
	if novo != "" or not navegar_com_teclas:
		if novo != _em_foco:
			_em_foco = novo
			_ao_mudar_o_foco(novo)
	if _segurado != "" and _segurado != novo:
		_segurado = ""
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if novo != "" else Input.CURSOR_ARROW)


func _apertar_o_foco() -> bool:
	var alvo := _alvo(_em_foco)
	if alvo.is_empty() or not _disponivel(alvo):
		return false
	_segurado = _em_foco
	_tempo_segurado = 0.0
	_proxima_repeticao = REPETICAO_ATRASO
	(alvo["ao_apertar"] as Callable).call()
	return true


func _repetir(delta: float) -> void:
	if _segurado == "" or _de_saida:
		return
	var alvo := _alvo(_segurado)
	if alvo.is_empty() or not bool(alvo["repete"]) or not _disponivel(alvo):
		return
	_tempo_segurado += delta
	_proxima_repeticao -= delta
	# No máximo alguns por quadro: um quadro demorado não despeja uma enxurrada.
	var feitos := 0
	while _proxima_repeticao <= 0.0 and feitos < 4:
		feitos += 1
		_proxima_repeticao += lerpf(REPETICAO_LENTA, REPETICAO_RAPIDA,
			clampf((_tempo_segurado - REPETICAO_ATRASO) / REPETICAO_RAMPA, 0.0, 1.0))
		(alvo["ao_apertar"] as Callable).call()
		if not _disponivel(alvo):
			break
	_proxima_repeticao = maxf(_proxima_repeticao, 0.0)


# ─────────────────────────────────────────────────────────────
# AS TECLAS (só com "navegar_com_teclas")
# ─────────────────────────────────────────────────────────────

func _navegar(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept"):
		# Sem foco nenhum, o primeiro toque só mostra onde ele está.
		if _em_foco == "" or not alvo_disponivel(_em_foco):
			focar(_primeiro_disponivel())
		else:
			apertar(_em_foco)
		return true
	# As setas e o WASD (segurando, o teclado repete sozinho). O direcional e o
	# analógico do controle estão nas mesmas ações, mas chegam pelo _process.
	if not event is InputEventKey:
		return false
	var direcao := Vector2.ZERO
	if event.is_action_pressed("ui_left", true):
		direcao = Vector2.LEFT
	elif event.is_action_pressed("ui_right", true):
		direcao = Vector2.RIGHT
	elif event.is_action_pressed("ui_up", true):
		direcao = Vector2.UP
	elif event.is_action_pressed("ui_down", true):
		direcao = Vector2.DOWN
	if direcao == Vector2.ZERO:
		return false
	_dar_passo(direcao)
	return true


## Um passo das setas, do direcional ou do analógico: é da tela, se ela quiser
## (_ao_dar_passo); senão, leva o foco para o alvo vizinho naquela direção.
func _dar_passo(direcao: Vector2) -> void:
	if _ao_dar_passo(direcao):
		return
	var destino := _primeiro_disponivel() if _em_foco == "" else _vizinho(_em_foco, direcao)
	if destino != "" and destino != _em_foco:
		focar(destino)
		tocar("passo")


func _primeiro_disponivel() -> String:
	for alvo in _alvos:
		if _disponivel(alvo):
			return alvo["nome"]
	return ""


## O alvo disponível para onde o foco vai na direção pedida.
##   1º  os que estão EM LINHA com o alvo de partida (na mesma fileira, para os
##       lados; na mesma coluna, para cima e para baixo): o mais próximo deles.
##       É o que se espera numa grade: → no hidrogênio vai ao hélio, do outro
##       lado do vão da tabela periódica, e não ao berílio, que está mais perto
##       mas na fileira de baixo.
##   2º  sem ninguém em linha, o que está mais à frente e menos de lado (a
##       mesma conta do direcional no cursor do controle): do cartão de cima
##       para o de baixo, que fica deslocado, no menu do Laboratório.
func _vizinho(nome: String, direcao: Vector2) -> String:
	var partida := retangulo_do_alvo(nome)
	var origem := partida.get_center()
	var melhor := ""
	var melhor_nota := INF
	var em_linha := ""
	var mais_perto := INF
	for alvo in _alvos:
		if alvo["nome"] == nome or not _disponivel(alvo):
			continue
		var caixa: Rect2 = (alvo["retangulo"] as Callable).call()
		var d := caixa.get_center() - origem
		var frente := d.dot(direcao)
		if frente <= 2.0:
			continue
		if _em_linha(partida, caixa, direcao) and frente < mais_perto:
			mais_perto = frente
			em_linha = alvo["nome"]
		var nota := frente + absf(d.cross(direcao)) * 2.2
		if nota < melhor_nota:
			melhor_nota = nota
			melhor = alvo["nome"]
	return em_linha if em_linha != "" else melhor


## As duas caixas estão na mesma fileira (andando para os lados) ou na mesma
## coluna (andando na vertical)? Vale quando elas se cobrem, no outro sentido,
## em pelo menos metade da menor.
static func _em_linha(uma: Rect2, outra: Rect2, direcao: Vector2) -> bool:
	if absf(direcao.x) > absf(direcao.y):
		var coberto := minf(uma.end.y, outra.end.y) - maxf(uma.position.y, outra.position.y)
		return coberto >= minf(uma.size.y, outra.size.y) * 0.5
	var sobreposto := minf(uma.end.x, outra.end.x) - maxf(uma.position.x, outra.position.x)
	return sobreposto >= minf(uma.size.x, outra.size.x) * 0.5


# ─────────────────────────────────────────────────────────────
# CONTROLE (ver cursor_virtual.gd)
# ─────────────────────────────────────────────────────────────

## Com as teclas levando o foco, o controle não precisa de cursor: só da barra.
func usa_cursor() -> bool:
	return not navegar_com_teclas


## Onde o cursor do controle pode parar: os alvos disponíveis.
func alvos_do_cursor() -> Array[Rect2]:
	var lista: Array[Rect2] = []
	if _de_saida or navegar_com_teclas:
		return lista
	for alvo in _alvos:
		if _disponivel(alvo):
			lista.append((alvo["retangulo"] as Callable).call())
	return lista


func dicas_do_controle() -> Array:
	var dicas: Array = []
	if navegar_com_teclas:
		dicas = [["direcional", "ESCOLHER"], ["cruz", "ENTRAR"]]
	else:
		dicas = [["analogico_esquerdo", "MOVER"], ["direcional", "ESCOLHER"], ["cruz", "APERTAR"]]
	if not cena_de_volta.is_empty() and not texto_de_voltar.is_empty():
		dicas.append(["fechar", texto_de_voltar.to_upper()])
	return dicas


# ─────────────────────────────────────────────────────────────
# A MOLDURA (o aviso de voltar e a plaquinha do título)
# ─────────────────────────────────────────────────────────────

func _montar_a_moldura() -> void:
	_moldura = Control.new()
	_moldura.name = "Moldura"
	_moldura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_moldura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_moldura.draw.connect(_desenhar_a_moldura)
	add_child(_moldura)
	if cena_de_volta.is_empty() or texto_de_voltar.is_empty():
		return

	# O mesmo aviso do canto dos puzzles da história: a tecla desenhada (ESC, ou
	# △ de controle na mão) e o que ela faz.
	_aviso_de_voltar = Label.new()
	_aviso_de_voltar.name = "AvisoDeVoltar"
	_aviso_de_voltar.position = lugar_do_aviso
	_aviso_de_voltar.size = Vector2(124, 32)
	_aviso_de_voltar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso_de_voltar.add_theme_font_override("font", FONTE)
	_aviso_de_voltar.add_theme_font_size_override("font_size", 11)
	_aviso_de_voltar.add_theme_color_override("font_color", cor_do_aviso)
	_aviso_de_voltar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_moldura.add_child(_aviso_de_voltar)
	Controle.rotular(_aviso_de_voltar, "{fechar}\n" + texto_de_voltar, 2.0)


func _desenhar_a_moldura() -> void:
	if not titulo.is_empty():
		PecasDoLaboratorio.plaquinha(_moldura, Vector2(size.x * 0.5, ALTURA_DO_TITULO), titulo)


## Onde a plaquinha do título fica (sem área se a tela não tem título).
func retangulo_do_titulo() -> Rect2:
	if titulo.is_empty():
		return Rect2()
	return PecasDoLaboratorio.retangulo_da_plaquinha(Vector2(size.x * 0.5, ALTURA_DO_TITULO), titulo)


# ─────────────────────────────────────────────────────────────
# APOIO
# ─────────────────────────────────────────────────────────────

## Toca um dos SONS. "tom" muda a altura (1 = como foi gravado).
func tocar(nome: String, tom: float = 1.0) -> void:
	if not SONS.has(nome) or not is_inside_tree():
		return
	var tocador: AudioStreamPlayer = _tocadores.get(nome)
	if tocador == null:
		tocador = AudioStreamPlayer.new()
		tocador.name = "Som" + nome.capitalize()
		tocador.stream = SONS[nome]
		tocador.volume_db = float(VOLUMES.get(nome, 0.0))
		add_child(tocador)
		_tocadores[nome] = tocador
	tocador.pitch_scale = tom
	tocador.play()
	som_tocado.emit(nome)


## Um tween que a tela lembra, para matar todos de uma vez.
func novo_tween() -> Tween:
	var tween := create_tween()
	_tweens.append(tween)
	if _tweens.size() > 48:
		_tweens = _tweens.filter(func(t: Tween) -> bool: return is_instance_valid(t) and t.is_valid())
	return tween


func matar_tweens() -> void:
	for tween in _tweens:
		if is_instance_valid(tween) and tween.is_valid():
			tween.kill()
	_tweens.clear()


## Onde o ponteiro está (o mouse ou o cursor do controle), lido dos eventos.
func ponteiro() -> Vector2:
	return _ponteiro
