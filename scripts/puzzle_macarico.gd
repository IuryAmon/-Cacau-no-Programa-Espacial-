extends CanvasLayer

# --- PUZZLE DO MAÇARICO (gaiola de vidro do pátio, fase 1) ---
#
# O maçarico do Dr. Chico está trancado na gaiola de vidro do pátio da Oficina
# do Carbono. Para destravar, o computador pede a queima do acetileno
# balanceada — em DUAS ETAPAS, como acontece na chama de verdade:
#
#   ETAPA 1   C₂H₂ + O₂  ->  CO + H₂
#             o acetileno reage com o oxigênio.
#   ETAPA 2   CO + H₂ + O₂  ->  CO₂ + H₂O
#             os gases da etapa 1 queimam com mais oxigênio.
#
# No fim, a tela mostra só "MAÇARICO LIBERADO!" e a foto do maçarico; o
# rodapé pede o E que abre a gaiola.
#
# A tela é a do puzzle do foguete (combustão do hidrogênio): setas sobem e
# descem cada coeficiente, as moléculas aparecem, e a contagem de átomos dos
# reagentes e dos produtos fica verde quando bate. A diferença é que aqui o
# Dr. Chico NÃO ajuda — quem responde é o próprio terminal, no rodapé.
#
# VALE QUALQUER RESPOSTA BALANCEADA: se C, H e O batem dos dois lados, a etapa
# conclui. Não existe um gabarito — na etapa 1 vale 1-1-2-1 e qualquer
# múltiplo dele (2-2-4-2...); na etapa 2 vale 1-1-1-1-1, 4-2-3-4-2, 3-1-2-3-1,
# e assim por diante. Resposta certa que não está na forma mais simples passa
# do mesmo jeito, e o rodapé só mostra a forma simplificada como dica.
#
#   coeficiente sem escolher   -> DEFINA TODOS OS COEFICIENTES
#   algum elemento não bate    -> diz qual (C, H, O)
#   balanceada                 -> conclui (e, se der para simplificar, mostra
#                                 a forma mais simples)
#
# Concluir a etapa 1 fica guardado até a fase recarregar: fechar a tela no
# meio da etapa 2 e voltar recomeça da etapa 2.
#
# ONDE MEXER:
#   ETAPAS (logo abaixo)          as reações, as respostas e os textos.
#   scenes/puzzle_macarico.tscn   a tela: posições, fontes, cores, sons.
#   scenes/ui/termo_equacao.tscn  a coluna de cada substância (setas e o
#                                 tamanho das moléculas).
#   scripts/ui/folha_moleculas.gd de onde vêm os desenhos das moléculas.
#
# INTERFACE (a mesma que a GaiolaPuzzle espera de todo puzzle de gaiola):
#   sinal "puzzle_resolvido" e método "abrir_puzzle()".
# CONTROLES: mouse nas setas e no botão; ENTER confirma; ESC fecha.
#   No controle: o analógico leva o cursor, o direcional pula de seta em seta,
#   ✕ aperta, ○ fecha e □ abre a gaiola no fim (ver cursor_virtual.gd).
# DEBUG: a tecla L resolve o puzzle na hora.

signal puzzle_resolvido

const TERMO := preload("res://scenes/ui/termo_equacao.tscn")
const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

const ETAPAS := [
	{
		"cabecalho": "LIBERAÇÃO DO MAÇARICO (ETAPA 1/2)",
		"instrucao": "BALANCEIE A REAÇÃO DO ACETILENO COM O OXIGÊNIO",
		"reagentes": ["C2H2", "O2"],
		"produtos": ["CO", "H2"],
		"botao": "CONFIRMAR ETAPA 1",
		"concluida": "ETAPA 1 CONCLUÍDA: 2 CO + H2 SEGUEM PARA A QUEIMA",
	},
	{
		"cabecalho": "LIBERAÇÃO DO MAÇARICO (ETAPA 2/2)",
		"instrucao": "QUEIME COM OXIGÊNIO OS GASES DA ETAPA 1",
		"reagentes": ["CO", "H2", "O2"],
		"produtos": ["CO2", "H2O"],
		"botao": "ACENDER MAÇARICO",
		"concluida": "COMBUSTÃO COMPLETA",
	},
]

const COEF_MAX := 4
## Rodapé da tela final. {interact} vira "E" no teclado e □ no controle.
const TXT_ABRIR_GAIOLA := "APERTE {interact} PARA ABRIR A GAIOLA"
## Ordem dos elementos na contagem de átomos.
const ORDEM_ELEMENTOS := ["C", "H", "O"]

# ── Montagem da linha de termos (px do Display) ──
const LARGURA_MAIS := 40.0
const LARGURA_SETA := 64.0
## Tamanho de fonte máximo da equação escrita; encolhe se não couber.
const FONTE_EQUACAO := 30
const FONTE_EQUACAO_MIN := 18

const COR_AMARELO := Color(1, 0.85, 0)
const COR_CERTO := Color.GREEN
const COR_ERRO := Color(1.0, 0.35, 0.3)
const COR_LED_TRAVADO := Color(0.9, 0.12, 0.1)
const COR_LED_ETAPA := Color(0.35, 0.95, 0.45)
const COR_LED_LIBERADO := Color(0.3, 0.75, 1.0)

var etapa: int = 0
var coeficientes: Array[int] = []
var tocado: Array[bool] = []
var travado: bool = false
var aguardando_fechamento: bool = false

# Cada abertura é uma sessão nova. Toda corrotina anota a sua e desiste se,
# ao acordar, a tela já tiver sido fechada (ou fechada e reaberta).
var _sessao: int = 0
var _em_transicao: bool = false
var _tweens: Array = []
var _tempo: float = 0.0
## Etapa em que a tela reabre (vira 1 depois de concluir a etapa 1).
var _etapa_liberada: int = 0
## Resposta de cada etapa concluída, já na forma mais simples (índice -> coeficientes).
var _respostas := {}
var _termos: Array[TermoEquacao] = []
var _largura_termo: float = 0.0
var _rodape_texto: String = ""
var _rodape_padrao: String = ""
var _rodape_cursor: bool = false

@onready var tela: TextureRect = $RootControl/Tela
@onready var led: ColorRect = $RootControl/Tela/Led
@onready var display: Control = $RootControl/Tela/Display
@onready var cabecalho: Label = $RootControl/Tela/Display/Cabecalho
@onready var rodape: Label = $RootControl/Tela/Display/Rodape
@onready var aura: ColorRect = $RootControl/Tela/Display/Aura
@onready var grupo_equacao: Control = $RootControl/Tela/Display/GrupoEquacao
@onready var resumo: HBoxContainer = $RootControl/Tela/Display/GrupoEquacao/Resumo
@onready var linha_equacao: HBoxContainer = $RootControl/Tela/Display/GrupoEquacao/LinhaEquacao
@onready var reagentes_titulo: Label = $RootControl/Tela/Display/GrupoEquacao/LabelReagentesTitulo
@onready var reagentes_valor: RichTextLabel = $RootControl/Tela/Display/GrupoEquacao/LabelReagentesValor
@onready var produtos_titulo: Label = $RootControl/Tela/Display/GrupoEquacao/LabelProdutosTitulo
@onready var produtos_valor: RichTextLabel = $RootControl/Tela/Display/GrupoEquacao/LabelProdutosValor
@onready var termos: Control = $RootControl/Tela/Display/GrupoEquacao/Termos
@onready var botao_confirmar: Panel = $RootControl/Tela/Display/GrupoEquacao/BotaoConfirmar
@onready var texto_botao: Label = $RootControl/Tela/Display/GrupoEquacao/BotaoConfirmar/LabelBotao
@onready var grupo_liberado: Control = $RootControl/Tela/Display/GrupoLiberado
@onready var label_liberado: Label = $RootControl/Tela/Display/GrupoLiberado/LabelLiberado
@onready var macarico: TextureRect = $RootControl/Tela/Display/GrupoLiberado/Macarico
@onready var audio_sucesso: AudioStreamPlayer = $AudioSucesso
@onready var audio_erro: AudioStreamPlayer = $AudioErro
@onready var audio_pop: AudioStreamPlayer = $AudioPop
@onready var audio_etapa: AudioStreamPlayer = $AudioEtapa


func _ready() -> void:
	hide()
	set_process(false)
	# Controle: cursor nesta tela e as teclas dos textos viram botões. O texto do
	# canto mora na cena, com as marcas {ui_cancel}/{teclado:...}; o do rodapé é
	# escrito aqui (ver _mostrar_liberado).
	add_to_group(CursorVirtual.GRUPO)
	Controle.rotular($RootControl/Instrucoes, $RootControl/Instrucoes.text)
	IconesNoTexto.acoplar(rodape)
	Controle.mudou.connect(_ao_trocar_controle)
	var modelo := TERMO.instantiate() as Control
	_largura_termo = modelo.custom_minimum_size.x
	modelo.free()
	# Onde cada coisa que treme fica em repouso: tremer duas vezes seguidas
	# não pode deixar a peça fora do lugar.
	for no: Control in [grupo_equacao, botao_confirmar]:
		no.set_meta("pos_base", no.position)


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
	audio_etapa.stop()
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
	_em_transicao = false
	_tempo = 0.0

	display.scale = Vector2.ONE
	display.modulate = Color.WHITE
	cabecalho.modulate = Color.WHITE
	rodape.modulate = Color.WHITE
	# O brilho da tela (o tom esverdeado do vidro) fica aceso em todas as
	# etapas, não só no maçarico aceso.
	aura.modulate.a = 1.0
	led.color = COR_LED_TRAVADO

	grupo_equacao.show()
	grupo_equacao.modulate = Color.WHITE
	grupo_equacao.scale = Vector2.ONE
	grupo_equacao.position = grupo_equacao.get_meta("pos_base", Vector2.ZERO)
	botao_confirmar.position = botao_confirmar.get_meta("pos_base", botao_confirmar.position)

	grupo_liberado.hide()
	grupo_liberado.modulate = Color.WHITE

	_montar_etapa(_etapa_liberada)


# A tela "liga" como monitor de tubo: uma linha que abre na vertical.
func _ligar_tela() -> void:
	display.scale = Vector2(1.0, 0.02)
	display.modulate.a = 0.0
	var tween := _tween()
	tween.set_parallel(true)
	tween.tween_property(display, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(display, "modulate:a", 1.0, 0.16)


# ------------------------- MONTAGEM DE UMA ETAPA -------------------------

func _montar_etapa(indice: int) -> void:
	etapa = indice
	var dados: Dictionary = ETAPAS[indice]
	var formulas := _formulas()

	coeficientes.clear()
	tocado.clear()
	for i in formulas.size():
		coeficientes.append(0)
		tocado.append(false)

	for filho in termos.get_children():
		filho.free()
	_termos.clear()

	# A linha: termo, "+", termo, "->", termo, "+", termo... centralizada.
	var pecas: Array = []
	var n_reagentes: int = dados["reagentes"].size()
	for i in formulas.size():
		if i > 0:
			pecas.append("->" if i == n_reagentes else "+")
		pecas.append(formulas[i])
	var total := 0.0
	for peca in pecas:
		total += _largura_da_peca(peca)
	var x := (termos.size.x - total) * 0.5
	var inicio_produtos := 0.0
	var fim_reagentes := 0.0
	for peca in pecas:
		var largura := _largura_da_peca(peca)
		if peca == "+" or peca == "->":
			if peca == "->":
				fim_reagentes = x
				inicio_produtos = x + largura
			termos.add_child(_criar_operador(peca, x, largura))
		else:
			var termo := TERMO.instantiate() as TermoEquacao
			termo.formula = peca
			termo.position = Vector2(x, 0)
			termos.add_child(termo)
			termo.molecula_apareceu.connect(_tocar_pop)
			_termos.append(termo)
		x += largura
	var fim_produtos := x
	var inicio_reagentes := (termos.size.x - total) * 0.5

	# Reagentes e Produtos centralizados em cima dos termos de cada lado.
	_centralizar_contagem(reagentes_titulo, reagentes_valor, inicio_reagentes, fim_reagentes)
	_centralizar_contagem(produtos_titulo, produtos_valor, inicio_produtos, fim_produtos)

	texto_botao.text = dados["botao"]
	cabecalho.text = dados["cabecalho"]
	_definir_rodape(dados["instrucao"], true)
	led.color = COR_LED_TRAVADO

	# Da etapa 2 em diante, a etapa anterior resolvida fica escrita no alto da
	# tela (na forma mais simples): são os gases que vão queimar agora.
	for filho in resumo.get_children():
		filho.free()
	resumo.visible = indice > 0 and _respostas.has(indice - 1)
	if resumo.visible:
		var anterior: Dictionary = ETAPAS[indice - 1]
		_add_texto(resumo, "ETAPA %d:   " % indice, false, COR_CERTO, 15)
		_escrever_equacao(resumo, anterior["reagentes"], anterior["produtos"],
			_respostas[indice - 1], [], COR_CERTO, 15, true)

	_atualizar_equacao()


func _largura_da_peca(peca: String) -> float:
	match peca:
		"+":
			return LARGURA_MAIS
		"->":
			return LARGURA_SETA
	return _largura_termo


func _criar_operador(texto: String, x: float, largura: float) -> Label:
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_theme_font_override("font", FONTE)
	lbl.add_theme_font_size_override("font_size", 33)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.position = Vector2(x, 0)
	lbl.size = Vector2(largura, termos.size.y)
	return lbl


func _centralizar_contagem(titulo: Label, valor: RichTextLabel, de: float, ate: float) -> void:
	var centro := termos.position.x + (de + ate) * 0.5
	var largura := maxf(ate - de + 60.0, 300.0)
	for no: Control in [titulo, valor]:
		no.position.x = centro - largura * 0.5
		no.size.x = largura


func _formulas() -> Array:
	var dados: Dictionary = ETAPAS[etapa]
	return dados["reagentes"] + dados["produtos"]


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
	# a gaiola que está logo atrás dela.
	if event.is_action_pressed(Interacao.ACAO):
		Interacao.consumir()

	if event is InputEventMouseMotion:
		_atualizar_cursor(event.position)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if aguardando_fechamento:
			fechar_puzzle(true)
			return
		_clicar(event.position)
		_atualizar_cursor(event.position)

	var tecla: bool = event is InputEventKey and event.pressed and not event.echo
	if tecla and event.keycode == KEY_L:
		# DEBUG: resolve o puzzle na hora, para não balancear a cada teste.
		fechar_puzzle(true)
		return
	# As teclas de sempre e, pelas ações do mapa, ○/□/✕ do controle.
	if aguardando_fechamento:
		if (tecla and event.keycode in [KEY_ESCAPE, KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]) \
				or event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") \
				or event.is_action_pressed(Interacao.ACAO):
			fechar_puzzle(true)
		return
	if (tecla and event.keycode == KEY_ESCAPE) or event.is_action_pressed("ui_cancel"):
		if not travado:
			fechar_puzzle(false)
	elif tecla and event.keycode in [KEY_ENTER, KEY_KP_ENTER] and _pode_mexer():
		_confirmar()


func _pode_mexer() -> bool:
	return not travado and not _em_transicao and grupo_equacao.visible


# ------------------------- CONTROLE (ver cursor_virtual.gd) -------------------------

## As setas de cada termo e o botão de confirmar.
func alvos_do_cursor() -> Array[Rect2]:
	var alvos: Array[Rect2] = []
	if not _pode_mexer():
		return alvos
	for termo in _termos:
		alvos.append(termo.retangulo_do_botao(1))
		alvos.append(termo.retangulo_do_botao(-1))
	alvos.append(_retangulo_do_confirmar())
	return alvos


func dicas_do_controle() -> Array:
	if aguardando_fechamento:
		return [[Interacao.ACAO, "ABRIR A GAIOLA"]]
	return [
		["analogico_esquerdo", "MOVER"],
		["direcional", "ESCOLHER"],
		["cruz", "APERTAR"],
		["ui_cancel", "SAIR"],
	]


## O rodapé final diz a tecla (ou o botão) que abre a gaiola: trocou de
## teclado para controle com ele na tela, ele se reescreve.
func _ao_trocar_controle(_em_uso: bool) -> void:
	if aguardando_fechamento:
		_definir_rodape(Controle.texto(TXT_ABRIR_GAIOLA), true)


func _clicar(pos: Vector2) -> void:
	if not _pode_mexer():
		return
	if _retangulo_do_confirmar().has_point(pos):
		_confirmar()
		return
	for i in _termos.size():
		var sentido := _termos[i].botao_no_ponto(pos)
		if sentido != 0:
			_alterar_coeficiente(i, sentido)
			return


func _atualizar_cursor(pos: Vector2) -> void:
	var sobre := false
	if _pode_mexer():
		sobre = _retangulo_do_confirmar().has_point(pos)
		for termo in _termos:
			if sobre:
				break
			sobre = termo.botao_no_ponto(pos) != 0
	elif aguardando_fechamento:
		sobre = true
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if sobre else Input.CURSOR_ARROW)


func _retangulo_do_confirmar() -> Rect2:
	return botao_confirmar.get_global_rect().grow(6.0 * botao_confirmar.get_global_transform().get_scale().x)


# ------------------------- COEFICIENTES E CONTAGEM -------------------------

func _alterar_coeficiente(i: int, sentido: int) -> void:
	var novo := coeficientes[i] + sentido
	if novo > COEF_MAX:
		novo = 0
	elif novo < 0:
		novo = COEF_MAX
	coeficientes[i] = novo
	tocado[i] = true
	var termo := _termos[i]
	termo.animar_seta(sentido)
	_pop(sentido, termo)
	termo.mostrar_quantidade(novo)
	# Mexeu de novo: a mensagem de erro de antes já não vale.
	_voltar_rodape()
	_atualizar_equacao()


func _atualizar_equacao() -> void:
	var dados: Dictionary = ETAPAS[etapa]
	var n_reagentes: int = dados["reagentes"].size()
	var formulas := _formulas()
	var elementos := _elementos_da_etapa()

	var reag := _contar(0, n_reagentes)
	var prod := _contar(n_reagentes, formulas.size())
	var textos_reag: Array[String] = []
	var textos_prod: Array[String] = []
	for el in elementos:
		var definido_reag := _lado_definido(el, 0, n_reagentes)
		var definido_prod := _lado_definido(el, n_reagentes, formulas.size())
		var bate: bool = definido_reag and definido_prod and reag[el] == prod[el]
		var cor := COR_CERTO if bate else COR_AMARELO
		textos_reag.append(_bbcode_contagem(el, str(reag[el]) if definido_reag else "?", cor))
		textos_prod.append(_bbcode_contagem(el, str(prod[el]) if definido_prod else "?", cor))
	reagentes_valor.text = "   ".join(textos_reag)
	produtos_valor.text = "   ".join(textos_prod)

	var cor_geral := COR_AMARELO
	if tocado.all(func(t): return t):
		cor_geral = COR_CERTO if _balanceada() else COR_ERRO
	reagentes_titulo.add_theme_color_override("font_color", cor_geral)
	produtos_titulo.add_theme_color_override("font_color", cor_geral)

	for filho in linha_equacao.get_children():
		filho.free()
	var textos_coef: Array = []
	for i in formulas.size():
		textos_coef.append(str(coeficientes[i]) if tocado[i] else "?")
	# A equação escrita encolhe até caber na largura da tela.
	var tamanho := FONTE_EQUACAO
	while tamanho > FONTE_EQUACAO_MIN and _largura_equacao(textos_coef, tamanho) > linha_equacao.size.x - 20.0:
		tamanho -= 2
	_escrever_equacao(linha_equacao, dados["reagentes"], dados["produtos"], [], textos_coef, cor_geral, tamanho, false)


func _bbcode_contagem(elemento: String, valor: String, cor: Color) -> String:
	return "[color=#%s]%s = %s[/color]" % [cor.to_html(false), elemento, valor]


## Átomos de cada elemento nos termos [de, ate).
func _contar(de: int, ate: int) -> Dictionary:
	var contagem := {}
	for el in ORDEM_ELEMENTOS:
		contagem[el] = 0
	var formulas := _formulas()
	for i in range(de, ate):
		var composicao := _composicao(formulas[i])
		for el in composicao:
			contagem[el] = contagem.get(el, 0) + coeficientes[i] * composicao[el]
	return contagem


## O lado só tem contagem para o elemento quando todo termo dele que contém
## esse elemento já teve o coeficiente escolhido.
func _lado_definido(elemento: String, de: int, ate: int) -> bool:
	var formulas := _formulas()
	for i in range(de, ate):
		if _composicao(formulas[i]).has(elemento) and not tocado[i]:
			return false
	return true


func _elementos_da_etapa() -> Array:
	var presentes := {}
	for formula in _formulas():
		for el in _composicao(formula):
			presentes[el] = true
	return ORDEM_ELEMENTOS.filter(func(el): return presentes.has(el))


func _balanceada() -> bool:
	var n_reagentes: int = ETAPAS[etapa]["reagentes"].size()
	return _contar(0, n_reagentes) == _contar(n_reagentes, _formulas().size())


## "C2H2" -> {"C": 2, "H": 2}
static func _composicao(formula: String) -> Dictionary:
	var saida := {}
	var i := 0
	while i < formula.length():
		var el := formula[i]
		i += 1
		while i < formula.length() and formula[i] == formula[i].to_lower() and not formula[i].is_valid_int():
			el += formula[i]
			i += 1
		var numero := ""
		while i < formula.length() and formula[i].is_valid_int():
			numero += formula[i]
			i += 1
		saida[el] = saida.get(el, 0) + (int(numero) if numero != "" else 1)
	return saida


# ------------------------- EQUAÇÃO ESCRITA -------------------------

## Escreve "c₁ R₁ + c₂ R₂ -> c₃ P₁ + ..." com os índices em subscrito de
## verdade (menores e rebaixados). "coefs" são números (omitindo o 1, como se
## escreve em química); "textos_coef" são textos prontos ("?" ou "3").
func _escrever_equacao(container: Control, reagentes: Array, produtos: Array, coefs: Array,
		textos_coef: Array, cor: Color, tamanho: int, omitir_um: bool) -> void:
	var formulas: Array = reagentes + produtos
	for i in formulas.size():
		if i == reagentes.size():
			_add_texto(container, "   →   ", false, cor, tamanho)
		elif i > 0:
			_add_texto(container, "  +  ", false, cor, tamanho)
		var coef := ""
		if not textos_coef.is_empty():
			coef = textos_coef[i] + " "
		elif not (omitir_um and coefs[i] == 1):
			coef = str(coefs[i]) + " "
		if coef != "":
			_add_texto(container, coef, false, cor, tamanho)
		for pedaco in _pedacos_da_formula(formulas[i]):
			_add_texto(container, pedaco[0], pedaco[1], cor, tamanho)


func _largura_equacao(textos_coef: Array, tamanho: int) -> float:
	var dados: Dictionary = ETAPAS[etapa]
	var formulas: Array = dados["reagentes"] + dados["produtos"]
	var largura := 0.0
	for i in formulas.size():
		if i == dados["reagentes"].size():
			largura += _medir("   →   ", tamanho)
		elif i > 0:
			largura += _medir("  +  ", tamanho)
		largura += _medir(textos_coef[i] + " ", tamanho)
		for pedaco in _pedacos_da_formula(formulas[i]):
			largura += _medir(pedaco[0], _tamanho_sub(tamanho) if pedaco[1] else tamanho)
	return largura


func _medir(texto: String, tamanho: int) -> float:
	return FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x


## "C2H2" -> [["C", false], ["2", true], ["H", false], ["2", true]]
static func _pedacos_da_formula(formula: String) -> Array:
	var pedacos: Array = []
	var atual := ""
	var numero := false
	for ch in formula:
		var eh_numero := ch.is_valid_int()
		if atual != "" and eh_numero != numero:
			pedacos.append([atual, numero])
			atual = ""
		atual += ch
		numero = eh_numero
	if atual != "":
		pedacos.append([atual, numero])
	return pedacos


static func _tamanho_sub(tamanho: int) -> int:
	return maxi(8, roundi(tamanho * 0.36))


func _add_texto(container: Control, texto: String, subscrito: bool, cor: Color, tamanho: int) -> void:
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_theme_font_override("font", FONTE)
	lbl.add_theme_font_size_override("font_size", _tamanho_sub(tamanho) if subscrito else tamanho)
	lbl.add_theme_color_override("font_color", cor)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_END if subscrito else Control.SIZE_SHRINK_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(lbl)


# ------------------------- CONFERIR A RESPOSTA -------------------------

func _confirmar() -> void:
	if not _pode_mexer():
		return
	var dados: Dictionary = ETAPAS[etapa]

	if not tocado.all(func(t): return t) or coeficientes.has(0):
		_errar("DEFINA TODOS OS COEFICIENTES", botao_confirmar)
		return

	if not _balanceada():
		var n_reagentes: int = dados["reagentes"].size()
		var reag := _contar(0, n_reagentes)
		var prod := _contar(n_reagentes, _formulas().size())
		var fora: Array = _elementos_da_etapa().filter(func(el): return reag[el] != prod[el])
		var texto := "ELEMENTO %s DESBALANCEADO" % fora[0]
		if fora.size() > 1:
			texto = "ELEMENTOS %s E %s DESBALANCEADOS" % [", ".join(PackedStringArray(fora.slice(0, -1))), fora[-1]]
		_errar(texto, grupo_equacao)
		return

	# Todos os átomos batem: qualquer combinação assim é uma resposta certa.
	_concluir_etapa()


func _errar(texto: String, tremer: Control) -> void:
	audio_erro.play()
	_shake(tremer)
	_mostrar_aviso(texto, COR_ERRO)


## Os coeficientes divididos pelo maior divisor comum a todos (2-2-4-2 -> 1-1-2-1).
static func _forma_mais_simples(valores: Array) -> Array:
	var divisor := 0
	for v in valores:
		var a := divisor
		var b := int(v)
		while b != 0:
			var resto := a % b
			a = b
			b = resto
		divisor = a
	var saida: Array = []
	for v in valores:
		@warning_ignore("integer_division")
		var simplificado: int = int(v) / maxi(divisor, 1)
		saida.append(simplificado)
	return saida


func _concluir_etapa() -> void:
	travado = true
	_em_transicao = true
	var sessao := _sessao
	var dados: Dictionary = ETAPAS[etapa]
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	audio_sucesso.play()
	led.color = COR_LED_ETAPA
	_pulsar(linha_equacao)

	# Certa, mas dava para simplificar: passa do mesmo jeito, e o rodapé mostra
	# a forma mais simples (com um pouco mais de tempo na tela para ler).
	var simples := _forma_mais_simples(coeficientes)
	_respostas[etapa] = simples
	var tem_dica := false
	var numeros := PackedStringArray()
	for i in simples.size():
		numeros.append(str(simples[i]))
		if int(simples[i]) != coeficientes[i]:
			tem_dica = true
	if tem_dica:
		_definir_rodape("BALANCEADA! FORMA MAIS SIMPLES: %s" % "-".join(numeros), false)
	else:
		_definir_rodape(dados["concluida"], false)
	rodape.add_theme_color_override("font_color", COR_CERTO)

	if etapa + 1 < ETAPAS.size():
		_etapa_liberada = etapa + 1
		await get_tree().create_timer(2.6 if tem_dica else 1.5).timeout
		if sessao != _sessao:
			return
		await _trocar_para_etapa(etapa + 1)
		if sessao != _sessao:
			return
		travado = false
		_em_transicao = false
		return

	await get_tree().create_timer(1.1).timeout
	if sessao != _sessao:
		return
	_mostrar_liberado()


## A equação resolvida sai, a próxima entra com o mesmo "pulo" do foguete.
func _trocar_para_etapa(indice: int) -> void:
	var sessao := _sessao
	grupo_equacao.pivot_offset = grupo_equacao.size * 0.5
	var sai := _tween()
	sai.set_parallel(true)
	sai.tween_property(grupo_equacao, "modulate:a", 0.0, 0.3)
	sai.tween_property(cabecalho, "modulate:a", 0.0, 0.3)
	await sai.finished
	if sessao != _sessao:
		return

	_montar_etapa(indice)
	grupo_equacao.scale = Vector2(0.7, 0.7)
	var entra := _tween()
	entra.set_parallel(true)
	entra.tween_property(grupo_equacao, "modulate:a", 1.0, 0.2)
	entra.tween_property(cabecalho, "modulate:a", 1.0, 0.2)
	entra.tween_property(grupo_equacao, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	audio_etapa.play()
	await entra.finished


# ------------------------- MAÇARICO LIBERADO -------------------------

## Tela final: só "MAÇARICO LIBERADO!" e a foto do maçarico, parada. O rodapé
## diz como abrir a gaiola.
func _mostrar_liberado() -> void:
	var sessao := _sessao
	var sai := _tween()
	sai.tween_property(grupo_equacao, "modulate:a", 0.0, 0.3)
	await sai.finished
	if sessao != _sessao:
		return
	grupo_equacao.hide()

	grupo_liberado.show()
	grupo_liberado.modulate.a = 0.0
	led.color = COR_LED_LIBERADO
	var entra := _tween()
	entra.tween_property(grupo_liberado, "modulate:a", 1.0, 0.3)
	_definir_rodape(Controle.texto(TXT_ABRIR_GAIOLA), true)
	aguardando_fechamento = true


# ------------------------- RODAPÉ -------------------------

func _definir_rodape(texto: String, com_cursor: bool) -> void:
	_rodape_texto = texto
	_rodape_padrao = texto
	_rodape_cursor = com_cursor
	rodape.remove_theme_color_override("font_color")


## Mensagem no rodapé; depois de "duracao" volta ao texto da etapa.
func _mostrar_aviso(texto: String, cor: Color, duracao: float = 2.2) -> void:
	var sessao := _sessao
	var padrao := _rodape_padrao
	var cursor := _rodape_cursor
	_rodape_texto = texto
	_rodape_cursor = false
	rodape.add_theme_color_override("font_color", cor)
	await get_tree().create_timer(duracao).timeout
	if sessao != _sessao or _rodape_texto != texto:
		return
	_rodape_texto = padrao
	_rodape_cursor = cursor
	rodape.remove_theme_color_override("font_color")


func _voltar_rodape() -> void:
	if travado or _rodape_texto == _rodape_padrao:
		return
	_rodape_texto = _rodape_padrao
	_rodape_cursor = true
	rodape.remove_theme_color_override("font_color")


# ------------------------- APOIO -------------------------

func _tocar_pop() -> void:
	audio_pop.play()


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


## A seta clicada dá um "tranco" no termo, na direção do clique.
func _pop(sentido: int, termo: Control) -> void:
	var moleculas: Control = termo.get_node("Moleculas")
	if not moleculas.has_meta("y_base"):
		moleculas.set_meta("y_base", moleculas.position.y)
	var base: float = moleculas.get_meta("y_base")
	var tween := _tween()
	tween.tween_property(moleculas, "position:y", base - 4.0 * sentido, 0.06) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(moleculas, "position:y", base, 0.18) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _pulsar(alvo: Control) -> void:
	alvo.pivot_offset = alvo.size * 0.5
	var tween := _tween()
	tween.tween_property(alvo, "scale", Vector2(1.08, 1.08), 0.1) \
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
