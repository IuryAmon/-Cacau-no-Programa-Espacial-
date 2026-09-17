extends CanvasLayer

# --- PUZZLE DO GUINCHO DA PLATAFORMA (corredores, fase 1) ---
#
# O elevador de carga da oficina está parado no chão. O terminal ao lado dele
# é o controle do guincho, e o guincho só sobe se souber COM QUANTA FORÇA
# puxar. A balança da plataforma diz a MASSA da Cacau; o guincho pede a FORÇA.
# Converter uma na outra é o puzzle inteiro.
#
# --- O QUE ELE ENSINA ---
#
# Massa e peso não são a mesma coisa, e esse é o erro mais teimoso da física
# escolar — "eu peso 45 quilos" é uma frase errada que todo mundo fala. A
# balança mede MASSA, em quilogramas: é o tanto de matéria, e ele é o mesmo
# aqui, na Lua ou flutuando. O PESO é a FORÇA com que a gravidade puxa essa
# massa, e força se mede em NEWTONS:
#
#     P = m · g          45 kg × 10 N/kg = 450 N
#
# O painel não dá a resposta: mostra os dois números e a fórmula com um ponto
# de interrogação no lugar do resultado. Fechar essa conta destrava a
# plataforma.
#
# --- POR QUE O DESENHO NÃO ENTREGA A RESPOSTA ---
#
# Só a força REGULADA vira seta. O peso aparece como a Cacau em pé na
# plataforma, sem seta nenhuma. Se os dois fossem setas bastaria igualar os
# tamanhos no olho, e a conta viraria enfeite. Assim, a única forma de saber é
# acionar — e o erro tem cara própria, do jeito que a chama do maçarico tem:
#
#   força de menos -> o cabo estica, a plataforma treme e não sai do chão
#   força de mais  -> ela arranca e bate na viga
#   força certa    -> sobe firme
#
# --- ONDE MEXER ---
#
# A TELA VIVE EM puzzle_guincho.tscn: posições, tamanhos, fontes e cores se
# ajustam lá, no editor. Aqui ficam os números — trocar a MASSA ou a GRAVIDADE
# muda a resposta, e as três plaquinhas da direita se reescrevem sozinhas a
# partir daqui, sem sobrar número escrito à mão na cena.
#
# INTERFACE (a mesma que a GaiolaPuzzle e o ComputadorPuzzle esperam):
#   sinal "puzzle_resolvido" e método "abrir_puzzle()".
#
# CONTROLES: A/D mudam de 100 em 100, W/S de 10 em 10, ESPAÇO aciona, ESC sai.
# O mouse também clica nos + / − e no acionador.
# No controle, sem cursor: direcional (ou analógico) ←→ muda de 100 em 100 e
# ↑↓ de 10 em 10, ✕ aciona, ○ sai e □ solta a plataforma no fim.

signal puzzle_resolvido

## Massa medida pela balança da plataforma, em quilogramas.
const MASSA := 45.0
## Gravidade da Terra, arredondada. O valor de verdade é 9,8 N/kg — a plaquinha
## diz isso, porque esconder o arredondamento seria ensinar errado.
const GRAVIDADE := 10.0

## Passos do mostrador. Dois tamanhos de propósito: o grosso monta as centenas
## e o fino as dezenas, então chegar em 450 são quatro toques de D e cinco de
## W. O número é CONSTRUÍDO a partir da conta, não caçado a cliques.
const PASSO_FINO := 10.0
const PASSO_GROSSO := 100.0
const FORCA_MAXIMA := 900.0

## Linha de ajuda do rodapé, em cada dispositivo ({acao} vira tecla ou botão).
const STATUS_TECLADO := "A/D  ±100 N   ·   W/S  ±10 N   ·   ESPAÇO aciona   ·   ESC sai"
const STATUS_CONTROLE := "{@direcional_horizontal:} ±100 N   ·   {@direcional_vertical:} ±10 N   ·   {@cruz:} aciona   ·   {ui_cancel} sai"
const STATUS_LIBERADO := "APERTE {interact} PARA SOLTAR A PLATAFORMA"

const COR_OK := Color(0.5, 0.95, 0.6)
const COR_ERRO := Color(0.95, 0.6, 0.45)
const COR_NEUTRA := Color(0.62, 0.66, 0.74)
const COR_APAGADA := Color(0.30, 0.33, 0.40)
const COR_DIAL := Color(0.55, 0.85, 1.0)

var _forca: float = 0.0
var _travado: bool = false

@onready var _conteudo: Control = $RootControl/Conteudo
# O mesmo shader dos outros puzzles: a placa vermelha do fundo fica verde
# quando o guincho é liberado.
@onready var _fundo_mat: ShaderMaterial = $RootControl/Painel.material
@onready var _preview: GuinchoPreview = $RootControl/Conteudo/Guincho
@onready var _dial: Panel = $RootControl/Conteudo/Dial
@onready var _dial_numero: Label = $RootControl/Conteudo/Dial/Numero
@onready var _mais: Panel = $RootControl/Conteudo/Dial/BotaoMais
@onready var _menos: Panel = $RootControl/Conteudo/Dial/BotaoMenos
@onready var _acionador: Panel = $RootControl/Conteudo/Acionar
@onready var _acionador_texto: Label = $RootControl/Conteudo/Acionar/Texto
@onready var _diagnostico: Label = $RootControl/Conteudo/Diagnostico
@onready var _status: Label = $RootControl/Conteudo/Status
@onready var _audio_sucesso: AudioStreamPlayer = $AudioSucesso
@onready var _audio_erro: AudioStreamPlayer = $AudioErro
@onready var _audio_clique: AudioStreamPlayer = $AudioClique


func _ready() -> void:
	layer = 15
	# Controle: esta tela ganha a barra de botões (sem cursor, ver usa_cursor) e
	# o rodapé troca as teclas pelos botões.
	add_to_group(CursorVirtual.GRUPO)
	IconesNoTexto.acoplar(_status)
	Controle.mudou.connect(func(_em_uso: bool) -> void: _escrever_status())
	_preview.forca_maxima = FORCA_MAXIMA
	_escrever("Balanca/Valor", "%s kg" % _numero(MASSA))
	_escrever("Gravidade/Valor", "%s N/kg" % _numero(GRAVIDADE))
	_escrever("Conta/Valor", "%s × %s  =  ?" % [_numero(MASSA), _numero(GRAVIDADE)])
	hide()
	set_process(false)


func _escrever(caminho: String, texto: String) -> void:
	var alvo: Label = _conteudo.get_node_or_null(caminho)
	if alvo:
		alvo.text = texto


# --- ABRIR E FECHAR (contrato de quem hospeda o puzzle) ---

func abrir_puzzle() -> void:
	show()
	set_process(true)
	Interacao.marcar_tela_aberta(self, true)

	_forca = 0.0
	_travado = false
	_preview.resultado = "parada"
	_fundo_mat.set_shader_parameter("progress", 0.0)
	_escrever_status()
	_diagnostico.text = ""
	_atualizar()

	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = false


func fechar_puzzle(resolvido: bool) -> void:
	hide()
	set_process(false)
	Interacao.marcar_tela_aberta(self, false)

	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = true
	if resolvido:
		puzzle_resolvido.emit()


# --- ENTRADA ---

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# A tela está por cima de tudo: nada do que acontece aqui pode sobrar para
	# o terminal que está logo atrás.
	get_viewport().set_input_as_handled()

	if event.is_action_pressed(Interacao.ACAO):
		Interacao.consumir()
		if _travado:
			fechar_puzzle(true)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_clique(event.position)
		return

	# ○ do controle: o mesmo ESC (o do teclado segue logo abaixo).
	if event is InputEventJoypadButton and event.is_action_pressed("ui_cancel"):
		fechar_puzzle(_travado)
		return

	# ✕ do controle: o mesmo ESPAÇO.
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		if _travado:
			fechar_puzzle(true)
		else:
			_acionar()
		return

	if not (event is InputEventKey and event.pressed):
		return

	if _travado:
		if event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
			fechar_puzzle(true)
		return

	match event.keycode:
		KEY_ESCAPE:
			fechar_puzzle(false)
		KEY_SPACE, KEY_ENTER:
			_acionar()
		KEY_W, KEY_UP:
			_regular(PASSO_FINO)
		KEY_S, KEY_DOWN:
			_regular(-PASSO_FINO)
		KEY_D, KEY_RIGHT:
			_regular(PASSO_GROSSO)
		KEY_A, KEY_LEFT:
			_regular(-PASSO_GROSSO)
		KEY_L:
			# DEBUG: resolve na hora, para não regular o guincho a cada teste.
			fechar_puzzle(true)


## Direcional (ou analógico) do controle girando o mostrador, com repetição ao
## segurar — o A/D e o W/S de quem joga de controle.
func _process(_delta: float) -> void:
	if not visible or _travado or not Controle.em_uso:
		return
	var passo := Controle.passo_navegacao()
	if passo.x != 0:
		_regular(PASSO_GROSSO * passo.x)
	elif passo.y != 0:
		_regular(-PASSO_FINO * passo.y)


## Rodapé com a ajuda do dispositivo em uso (ou o aviso de liberado).
func _escrever_status() -> void:
	if _travado:
		_status.text = Controle.texto(STATUS_LIBERADO)
		_status.add_theme_color_override("font_color", COR_OK)
		return
	_status.text = Controle.texto(STATUS_CONTROLE if Controle.em_uso else STATUS_TECLADO)
	_status.add_theme_color_override("font_color", COR_NEUTRA)


# --- CONTROLE (ver cursor_virtual.gd) ---

## O controle opera o guincho direto: nada de cursor, só a barra de botões.
func usa_cursor() -> bool:
	return false


func dicas_do_controle() -> Array:
	if _travado:
		return [[Interacao.ACAO, "SOLTAR A PLATAFORMA"]]
	return [
		["direcional_horizontal", "±100 N"],
		["direcional_vertical", "±10 N"],
		["cruz", "ACIONAR"],
		["ui_cancel", "SAIR"],
	]


func _clique(pos: Vector2) -> void:
	if _travado:
		fechar_puzzle(true)
		return
	if _acionador.get_global_rect().has_point(pos):
		_acionar()
	elif _mais.get_global_rect().has_point(pos):
		_regular(PASSO_FINO)
	elif _menos.get_global_rect().has_point(pos):
		_regular(-PASSO_FINO)


func _regular(passo: float) -> void:
	var novo: float = clampf(_forca + passo, 0.0, FORCA_MAXIMA)
	if is_equal_approx(novo, _forca):
		return
	_forca = novo
	if _audio_clique.stream:
		_audio_clique.play()
	# Mexeu no mostrador: a plataforma volta para o chão e o diagnóstico velho
	# sai da tela — cada tentativa começa limpa.
	_preview.resultado = "parada"
	_diagnostico.text = ""
	_atualizar()


# --- A FÍSICA ---

## O peso da Cacau: a força com que a gravidade puxa a massa dela.
func _peso() -> float:
	return MASSA * GRAVIDADE


func _acionar() -> void:
	if is_equal_approx(_forca, _peso()):
		_vencer()
	elif _forca < _peso():
		_preview.resultado = "fraca"
		_falhar("%s N não vencem o peso dela: a plataforma nem sai do chão." % _numero(_forca))
	else:
		_preview.resultado = "forte"
		_falhar("%s N é força demais: a plataforma arranca e bate na viga." % _numero(_forca))


func _falhar(motivo: String) -> void:
	_diagnostico.text = motivo
	_diagnostico.add_theme_color_override("font_color", COR_ERRO)
	if _audio_erro.stream:
		_audio_erro.play()

	var origem := _conteudo.position
	var tween := create_tween()
	tween.tween_property(_conteudo, "position", origem + Vector2(9, 0), 0.04)
	tween.tween_property(_conteudo, "position", origem + Vector2(-9, 0), 0.04)
	tween.tween_property(_conteudo, "position", origem, 0.06)


func _vencer() -> void:
	_travado = true
	_preview.resultado = "certa"
	# A frase da vitória é a lição, não um parabéns.
	_diagnostico.text = "%s kg de massa dão %s N de peso. Guincho regulado." % [
		_numero(MASSA), _numero(_peso())]
	_diagnostico.add_theme_color_override("font_color", COR_OK)
	_escrever_status()
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(v: float) -> void: _fundo_mat.set_shader_parameter("progress", v),
		0.0, 1.0, 0.6)
	if _audio_sucesso.stream:
		_audio_sucesso.play()
	_atualizar()


# --- DESENHO DA TELA ---

func _atualizar() -> void:
	_dial_numero.text = _numero(_forca)
	_dial.add_theme_stylebox_override("panel", _estilo(
		Color(0.10, 0.11, 0.15),
		COR_APAGADA if _travado else COR_DIAL,
		2 if _travado else 3))

	_preview.forca = _forca

	_acionador_texto.text = "LIBERADO" if _travado else "ACIONAR"
	_acionador.add_theme_stylebox_override("panel", _estilo(
		Color(0.16, 0.30, 0.20) if _travado else Color(0.16, 0.17, 0.22),
		COR_OK if _travado else Color(0.40, 0.43, 0.50)))


func _estilo(fundo: Color, borda: Color, largura: int = 2) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fundo
	estilo.border_color = borda
	estilo.set_border_width_all(largura)
	estilo.set_corner_radius_all(8)
	return estilo


## Número sem casas sobrando e com separador de milhar em espaço.
func _numero(valor: float) -> String:
	var texto := str(roundi(valor))
	var saida := ""
	while texto.length() > 3:
		saida = " " + texto.right(3) + saida
		texto = texto.left(texto.length() - 3)
	return texto + saida
