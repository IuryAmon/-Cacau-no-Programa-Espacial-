class_name Introducao
extends Control

# --- A INTRODUÇÃO DO MODO HISTÓRIA ---
#
# O que passa entre o MODO HISTÓRIA do menu principal e o world1: o acidente
# do VLS-1 em Alcântara, contado como as aberturas de Undertale e de Final
# Fight. A tela é preta; no alto dela, uma TELINHA com moldura clara mostra a
# imagem do momento (o vídeo da câmera de segurança, depois a foto da base
# destruída) e, embaixo, na parte preta, o texto vai sendo escrito em branco,
# letra a letra, na letra dos tutoriais (a ari-w9500, no tamanho da ficha de
# tutorial). Depois, em silêncio: "Mas o sonho não morreu com eles", décadas
# depois, a Lua, o quarto da Cacau e o plantão do jornal procurando uma
# criança para o módulo lunar. No fim, a tela fica preta e em silêncio, e a
# cortina (TransicaoDeCena) leva ao world1 — onde o nome do jogo aparece no
# céu, com a bossa nova, antes de a câmera descer até a Cacau
# (abertura_da_historia.gd).
#
# O ROTEIRO é a lista logo abaixo, um QUADRO por imagem:
#   "imagem"    o que aparece na telinha: um vídeo (.ogv), uma imagem, uma
#               cena montada (.tscn, como o céu com a lua — se ela tiver
#               pagina_aberta(indice), é avisada a cada página) ou,
#               enquanto o desenho não fica pronto, um TEXTO: a telinha fica
#               preta, com a descrição da imagem escrita dentro dela. Sem
#               "imagem", não há telinha: a tela toda fica preta e o texto
#               vem no meio dela;
#   "legenda"   (opcional) o letreiro no alto da tela, acima da telinha;
#   "paginas"   o texto de baixo, uma página por vez ("\n" quebra a linha ali);
#   "corte"     (opcional) true: o quadro entra num corte seco — o anterior
#               some de uma vez e este aparece de uma vez, sem apagar e
#               acender;
#   "segura"    (opcional) segundos a mais que a imagem fica, depois do texto
#               (num quadro sem texto, o tempo dele; sem isto, SEGURA_SEM_TEXTO);
#   "escuro_antes"  (opcional) segundos de tela preta antes do quadro;
#   "para_a_musica" (opcional) true: a música some junto com este quadro, e o
#               resto da introdução segue em silêncio.
# Mudar o texto, trocar uma imagem ou pôr mais um quadro é só mexer nela.
# Cada página cabe em LINHAS_POR_PAGINA linhas: o teste
# (tools/teste_introducao.tscn) avisa se alguma passar.
#
# O RITMO: cada página é escrita na velocidade das falas do jogo (a do
# dialog_box.gd), respira um pouco mais na vírgula e no ponto, fica parada o
# tempo de ler e some. A última página de um quadro sai junto com a imagem.
#
# O VÍDEO da câmera de segurança tem só 40 imagens em 17 segundos, e o texto
# que passa em cima dele leva quase o dobro disso. Em vez de acabar e ficar
# congelado no meio da narração, ele anda mais devagar (speed_scale), na
# medida para terminar junto com o quadro: numa câmera dessas, uma imagem a
# cada meio segundo e pouco continua parecendo a gravação.
#
# A MÚSICA (intro1) toca do começo até o quadro com "para_a_musica" (a foto da
# base destruída) — quem toca é a TrilhaSonora, que a pega em "musica", aqui
# embaixo — e some junto com a imagem dele: dali em diante (o sonho, a Lua, o
# quarto da Cacau, o jornal) e no fim, silêncio. A próxima música é a bossa
# nova do world1, que entra com o nome do jogo, lá.
#
# ONDE MEXER:
#   ROTEIRO                        o texto e as imagens;
#   o nó Tela, na cena             a telinha: arraste ou redimensione no
#                                  editor; a legenda e o texto se arrumam em
#                                  volta dela;
#   as constantes de O RITMO       os tempos;
#   "musica", no Inspector da raiz a música e o volume dela.
#
# CONTROLES: ENTER, ESPAÇO, E, o clique ou ✕ adiantam (completam a página que
# está sendo escrita; com ela inteira, passam para a próxima). ESC (△ ou ○ no
# controle) pula a introdução inteira.

## Um quadro do ROTEIRO acendeu (o número dele na lista).
signal quadro_aberto(indice: int)
## Uma página começou a ser escrita.
signal pagina_aberta(texto: String)

const ROTEIRO := [
	{
		"imagem": preload("res://Videos/2026-10-13 22-21-35.ogv"),
		"legenda": "Centro Espacial de Alcântara, Maranhão.",
		"paginas": [
			"Era 22 de agosto de 2003\no Programa Espacial Brasileiro vivia seu maior acidente da história",
			"Três dias antes do lançamento, em um dos motores do VLS-1 (Veículo Lançador de Satélites) aconteceu uma ignição prematura de um dos motores, às 13h26, resultou na explosão do protótipo de 21 metros de altura.",
			"O foguete, preso à torre de lançamento, virou um maçarico gigante virado pro chão.",
		],
	},
	{
		"imagem": preload("res://Videos/Q2SGOVHSJZK6JFHTSQKQBJY42Q.jpg"),
		"paginas": [
			"Nesse dia, 21 técnicos e engenheiros não voltaram para casa.",
			"Com eles, o Brasil viu seu avanço espacial, e tudo que viria com ele, parar no meio do caminho.",
		],
		"para_a_musica": true,
	},
	# Tela preta, silêncio.
	{
		"escuro_antes": 2.5,
		"paginas": ["Mas o sonho não morreu com eles."],
	},
	{
		"imagem": preload("res://scenes/ceu_com_lua.tscn"),
		"paginas": [
			"Décadas depois, o Brasil partiria para sua maior missão…",
			"...a Lua!",
		],
	},
	# Os quadros com texto no lugar da imagem esperam o desenho: trocar o texto
	# pelo preload da imagem quando ela existir.
	{
		"imagem": "O quarto da Cacau, à noite.\nA luz do abajur e a da TV ligada.",
		"segura": 3.0,
	},
	{
		"imagem": "Close na TV: o plantão do jornal, a jornalista na bancada.",
		"corte": true,
		"paginas": [
			"Jornalista:\n“...a missão lunar brasileira enfrenta um imprevisto de última hora. Um erro no projeto deixou o módulo pequeno demais para qualquer adulto.”",
			"Jornalista:\n“O alinhamento orbital não espera. Por isso, o Programa Espacial Brasileiro faz um chamado inédito a todo o país.”",
			"Jornalista:\n“Procura-se uma criança. Pequena o bastante para caber no módulo lunar.”",
		],
	},
	{
		"imagem": "Close no rosto da Cacau, com os olhos brilhando, iluminados pela TV.",
		"corte": true,
		"paginas": ["Jornalista:\n“E corajosa o bastante para entrar nele.”"],
	},
	{
		"imagem": "A Cacau calça o tênis, apaga o abajur e sai do quarto. A porta fica aberta. A TV continua ligada, iluminando o quarto vazio.",
		"corte": true,
		"segura": 5.0,
	},
	# O nome do jogo vem depois, já no world1: no céu, antes de a câmera descer
	# até a Cacau (abertura_da_historia.gd).
]

## A descrição no lugar da imagem que ainda não existe: letra menor e apagada.
const TAM_DESCRICAO := 22
const COR_DA_DESCRICAO := Color(0.96, 1.0, 0.91, 0.6)

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

# --- A letra e o lugar dela (px da tela, 1600 x 900) ---
## O tamanho da frase da ficha de tutorial (TutorialFerramenta).
const TAM_LETRA := 26
const ENTRELINHA := 1.45
## A moldura clara em volta da telinha.
const MOLDURA := 4.0
## Da moldura até a legenda (em cima) e até a primeira linha do texto (embaixo).
const ESPACO_DA_LEGENDA := 30.0
const ESPACO_DO_TEXTO := 38.0
## O texto é centrado embaixo da telinha, nesta largura.
const LARGURA_DO_TEXTO := 1040.0
const LINHAS_POR_PAGINA := 4

# --- O RITMO (segundos) ---
## Tela preta antes da primeira imagem.
const ESCURO_NO_COMECO := 1.0
## A imagem acendendo e apagando, com a moldura junto.
const ACENDER := 1.0
const APAGAR := 1.0
## A telinha vazia entre um quadro e o outro.
const ENTRE_QUADROS := 0.5
## Da imagem acesa até a legenda, e daí até a primeira página.
const ANTES_DA_LEGENDA := 0.6
const ANTES_DO_TEXTO := 0.8
## A velocidade das falas do jogo (dialog_box.gd).
const LETRAS_POR_SEGUNDO := 25.0
## O respiro a mais depois da vírgula, do ponto e da quebra escrita no texto.
const PAUSA_NA_VIRGULA := 0.15
const PAUSA_NO_PONTO := 0.45
const PAUSA_NA_QUEBRA := 0.35
## Quanto a página fica parada, já escrita: um tanto fixo e mais um pouco por letra.
const LEITURA := 1.6
const LEITURA_POR_LETRA := 0.012
## A página sumindo, e o vão até a próxima.
const APAGAR_PAGINA := 0.3
const ENTRE_PAGINAS := 0.3
## O tempo de um quadro sem texto e sem "segura".
const SEGURA_SEM_TEXTO := 3.0
## O fim: a última imagem, o texto e a moldura apagam juntos, e a tela fica
## preta antes do jogo.
const APAGAR_TUDO := 1.5
const SILENCIO_FINAL := 3.0
## O vídeo anda mais devagar para durar o quadro inteiro (ver o topo). Com
## false, ele toca na velocidade dele e, se acabar antes, fica parado na
## última imagem.
const VIDEO_ACOMPANHA_O_TEXTO := true


## Um texto sendo escrito: a legenda do alto ou a página de baixo.
class Escrita:
	var linhas := PackedStringArray()
	## Quando cada letra aparece, em segundos desde o começo da escrita.
	var horarios := PackedFloat32Array()
	## Quantas letras já estão na tela.
	var letras := 0
	var alfa := 0.0

	func total() -> int:
		return horarios.size()

	func duracao() -> float:
		return horarios[horarios.size() - 1] if horarios.size() > 0 else 0.0

	func completa() -> bool:
		return letras >= horarios.size()


## A música da introdução (ver o topo).
@export var musica: AudioStream = preload("res://sounds/Trilhas/intro1.mp3")
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var volume_da_musica_db := -6.0

@onready var tela: Control = $Tela
@onready var video: VideoStreamPlayer = $Tela/Video
@onready var foto: TextureRect = $Tela/Foto

var _legenda := Escrita.new()
var _pagina := Escrita.new()
## O quadro do ROTEIRO na tela.
var _quadro := {}
## A moldura e a descrição provisória acendendo e apagando.
var _alfa_do_quadro := 0.0
var _musica_parou := false
## A cena montada na telinha (o "imagem" .tscn do quadro), enquanto ele dura.
var _montagem: Node
## Um toque de adiantar esperando ser usado.
var _adiantar := false
var _pulou := false
var _foi_para_o_jogo := false


func _ready() -> void:
	# O E, o espaço e o ✕ apertados aqui são da introdução: seguem presos a ela
	# e não viram pulo nem interação quando o world1 chegar (ver interacao.gd).
	Interacao.marcar_tela_aberta(self, true)
	# O ponteiro do mouse some enquanto a introdução passa.
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	tela.modulate.a = 0.0
	video.visible = false
	foto.visible = false
	_rodar_o_roteiro()


func _exit_tree() -> void:
	# E volta como o Controle o quer: escondido só com o controle na mão.
	if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN and not Controle.em_uso:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _foi_para_o_jogo or TransicaoDeCena.em_curso():
		return
	if event.is_action_pressed("fechar") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_pular()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		_adiantar = true


# ─────────────────────────────────────────────────────────────
# O ROTEIRO
# ─────────────────────────────────────────────────────────────
# Cada passo devolve false se a introdução foi pulada no meio dele: quem
# chamou para tudo e volta (a cortina já está levando ao jogo).

func _rodar_o_roteiro() -> void:
	if not await _esperar(ESCURO_NO_COMECO, false):
		return
	for i in ROTEIRO.size():
		if not await _mostrar_o_quadro(i):
			return
	if not await _esperar(SILENCIO_FINAL, false):
		return
	_ir_para_o_jogo()


func _mostrar_o_quadro(indice: int) -> bool:
	var quadro: Dictionary = ROTEIRO[indice]
	var ultimo := indice == ROTEIRO.size() - 1
	var corta_para_o_proximo := not ultimo and bool(ROTEIRO[indice + 1].get("corte", false))
	var paginas: Array = quadro.get("paginas", [])
	if quadro.has("escuro_antes"):
		if not await _esperar(float(quadro["escuro_antes"]), false):
			return false
	_quadro = quadro
	_legenda = _montar(String(quadro.get("legenda", "")))
	_pagina = Escrita.new()
	_por_a_imagem(quadro.get("imagem"))
	if video.visible:
		video.play()
		video.speed_scale = _velocidade_do_video(quadro, ultimo)
	quadro_aberto.emit(indice)

	var acender := func(t: float) -> void:
		tela.modulate.a = t
		_alfa_do_quadro = t
	if quadro.get("corte", false):
		acender.call(1.0)
	elif not await _animar(ACENDER, acender):
		return false

	if _legenda.total() > 0:
		if not await _esperar(ANTES_DA_LEGENDA):
			return false
		_legenda.alfa = 1.0
		if not await _digitar(_legenda):
			return false
	if not await _esperar(ANTES_DO_TEXTO):
		return false

	var apagar_a_pagina := func(t: float) -> void:
		_pagina.alfa = 1.0 - t
	for p in paginas.size():
		_pagina = _montar(String(paginas[p]))
		_pagina.alfa = 1.0
		pagina_aberta.emit(String(paginas[p]))
		# Uma cena montada pode mudar com a página (a lua aparecendo no "...a Lua!").
		if _montagem != null and _montagem.has_method("pagina_aberta"):
			_montagem.pagina_aberta(p)
		if not await _digitar(_pagina):
			return false
		if not await _esperar(_tempo_de_leitura(_pagina)):
			return false
		# A última página fica até o quadro apagar.
		if p < paginas.size() - 1:
			if not await _animar(APAGAR_PAGINA, apagar_a_pagina):
				return false
			if not await _esperar(ENTRE_PAGINAS):
				return false

	var segura := _segura(quadro)
	if segura > 0.0 and not await _esperar(segura):
		return false

	# A imagem, a moldura, a legenda e a última página apagam juntas — e, no
	# quadro que para a música (ou no último), a música também. Antes de um
	# corte seco, tudo some de uma vez.
	var para_a_musica := _para_a_musica(quadro, ultimo) and not _musica_parou
	if para_a_musica:
		_musica_parou = true
		TrilhaSonora.parar(0.0 if corta_para_o_proximo else APAGAR_TUDO)
	var apagar := func(t: float) -> void:
		tela.modulate.a = 1.0 - t
		_alfa_do_quadro = 1.0 - t
		_legenda.alfa = minf(_legenda.alfa, 1.0 - t)
		_pagina.alfa = minf(_pagina.alfa, 1.0 - t)
	if corta_para_o_proximo:
		apagar.call(1.0)
	elif not await _animar(_tempo_de_apagar(quadro, ultimo), apagar):
		return false
	_tirar_a_imagem()
	if ultimo or corta_para_o_proximo:
		return true
	return await _esperar(ENTRE_QUADROS, false)


## O tempo que a imagem fica depois do texto (ver "segura" no topo).
func _segura(quadro: Dictionary) -> float:
	if quadro.has("segura"):
		return float(quadro["segura"])
	return SEGURA_SEM_TEXTO if (quadro.get("paginas", []) as Array).is_empty() else 0.0


func _para_a_musica(quadro: Dictionary, ultimo: bool) -> bool:
	return ultimo or bool(quadro.get("para_a_musica", false))


## O quadro que leva a música (ou a introdução) embora apaga mais devagar.
func _tempo_de_apagar(quadro: Dictionary, ultimo: bool) -> float:
	return APAGAR_TUDO if _para_a_musica(quadro, ultimo) else APAGAR


## A imagem do quadro na telinha: um vídeo ou uma foto. A descrição de uma
## imagem que ainda não existe (um texto) é desenhada no _draw.
func _por_a_imagem(imagem: Variant) -> void:
	video.visible = imagem is VideoStream
	foto.visible = imagem is Texture2D
	if imagem is VideoStream:
		video.stream = imagem
	elif imagem is Texture2D:
		foto.texture = imagem
	elif imagem is PackedScene:
		_montagem = (imagem as PackedScene).instantiate()
		tela.add_child(_montagem)


## Tira a imagem da telinha, depois que o quadro apagou.
func _tirar_a_imagem() -> void:
	video.stop()
	video.visible = false
	foto.visible = false
	if _montagem != null:
		_montagem.queue_free()
		_montagem = null


## A velocidade que faz o vídeo durar o quadro inteiro, até a imagem apagar
## (nunca mais depressa que o normal).
func _velocidade_do_video(quadro: Dictionary, ultimo: bool) -> float:
	var comprimento := video.get_stream_length()
	var duracao := _duracao_do_quadro(quadro, ultimo)
	if not VIDEO_ACOMPANHA_O_TEXTO or comprimento <= 0.0 or duracao <= 0.0:
		return 1.0
	return minf(1.0, comprimento / duracao)


## Quanto o quadro dura sem ninguém adiantar nada: da imagem acendendo até ela
## apagar.
func _duracao_do_quadro(quadro: Dictionary, ultimo: bool) -> float:
	var total := 0.0 if quadro.get("corte", false) else ACENDER
	var legenda := String(quadro.get("legenda", ""))
	if not legenda.is_empty():
		total += ANTES_DA_LEGENDA + _montar(legenda).duracao()
	total += ANTES_DO_TEXTO
	var paginas: Array = quadro.get("paginas", [])
	for p in paginas.size():
		var escrita := _montar(String(paginas[p]))
		total += escrita.duracao() + _tempo_de_leitura(escrita)
		if p < paginas.size() - 1:
			total += APAGAR_PAGINA + ENTRE_PAGINAS
	return total + _segura(quadro) + _tempo_de_apagar(quadro, ultimo)


func _tempo_de_leitura(escrita: Escrita) -> float:
	return LEITURA + LEITURA_POR_LETRA * escrita.total()


func _pular() -> void:
	_pulou = true
	_ir_para_o_jogo()


func _ir_para_o_jogo() -> void:
	if _foi_para_o_jogo:
		return
	_foi_para_o_jogo = true
	# O world1 abre com a Cacau entrando correndo (abertura_da_historia.gd).
	EstadoMundo.abertura_pendente = true
	TransicaoDeCena.ir_para(get_tree(), TransicaoDeCena.CENA_HISTORIA)


# ─────────────────────────────────────────────────────────────
# O TEMPO
# ─────────────────────────────────────────────────────────────

## Espera o próximo quadro. Devolve false se a introdução foi pulada (ou saiu
## da árvore).
func _proximo_quadro() -> bool:
	if _pulou or not is_inside_tree():
		return false
	await get_tree().process_frame
	return not _pulou and is_inside_tree()


## Espera "segundos". Com "adiantavel", um toque de adiantar encurta a espera.
func _esperar(segundos: float, adiantavel: bool = true) -> bool:
	var passado := 0.0
	while passado < segundos:
		if not await _proximo_quadro():
			return false
		if adiantavel and _pediu_adiantar():
			break
		passado += get_process_delta_time()
	return true


## Leva "aplicar(t)" de t = 0 a t = 1 em "duracao" segundos.
func _animar(duracao: float, aplicar: Callable) -> bool:
	var passado := 0.0
	while passado < duracao:
		aplicar.call(passado / duracao)
		if not await _proximo_quadro():
			return false
		passado += get_process_delta_time()
	aplicar.call(1.0)
	return true


## Escreve letra a letra. Adiantar põe o resto do texto de uma vez.
func _digitar(escrita: Escrita) -> bool:
	# Um toque que sobrou de antes (no meio de um apagar) não vale para esta.
	_adiantar = false
	var passado := 0.0
	while not escrita.completa():
		if not await _proximo_quadro():
			return false
		if _pediu_adiantar():
			escrita.letras = escrita.total()
			break
		passado += get_process_delta_time()
		while escrita.letras < escrita.total() and escrita.horarios[escrita.letras] <= passado:
			escrita.letras += 1
	return true


func _pediu_adiantar() -> bool:
	var pediu := _adiantar
	_adiantar = false
	return pediu


# ─────────────────────────────────────────────────────────────
# O TEXTO
# ─────────────────────────────────────────────────────────────

## O texto quebrado nas linhas que vão para a tela (a quebra escrita com "\n"
## vale) e o horário de cada letra.
func _montar(texto: String) -> Escrita:
	var escrita := Escrita.new()
	var fim_de_paragrafo: Array[bool] = []
	for paragrafo in texto.split("\n"):
		var linhas := EstiloHUD.quebrar(FONTE, paragrafo, TAM_LETRA, LARGURA_DO_TEXTO)
		for i in linhas.size():
			escrita.linhas.append(linhas[i])
			fim_de_paragrafo.append(i == linhas.size() - 1)
	var passo := 1.0 / LETRAS_POR_SEGUNDO
	var t := 0.0
	for l in escrita.linhas.size():
		for letra in escrita.linhas[l]:
			t += passo
			escrita.horarios.append(t)
			t += _pausa_depois(letra)
		# A troca de linha: a quebra escrita respira; a da largura vale um espaço.
		if l < escrita.linhas.size() - 1:
			t += PAUSA_NA_QUEBRA if fim_de_paragrafo[l] else passo
	return escrita


func _pausa_depois(letra: String) -> float:
	if letra in [",", ";", ":"]:
		return PAUSA_NA_VIRGULA
	if letra in [".", "!", "?"]:
		return PAUSA_NO_PONTO
	return 0.0


func _topo_da_legenda() -> float:
	return tela.position.y - MOLDURA - ESPACO_DA_LEGENDA - FONTE.get_height(TAM_LETRA)


## Onde começa o texto de baixo: na parte preta, abaixo da telinha — ou, num
## quadro sem imagem, no meio da tela.
func _topo_do_texto(escrita: Escrita = null) -> float:
	if escrita != null and not _quadro.is_empty() and _quadro.get("imagem") == null:
		var altura := FONTE.get_height(TAM_LETRA) + (escrita.linhas.size() - 1) * TAM_LETRA * ENTRELINHA
		return roundf((size.y - altura) * 0.5)
	return tela.get_rect().end.y + MOLDURA + ESPACO_DO_TEXTO


# ─────────────────────────────────────────────────────────────
# DESENHO
# ─────────────────────────────────────────────────────────────
# A tela preta, a moldura e as letras são desenhadas aqui; a imagem é a
# Tela (o vídeo ou a foto), que fica por cima, dentro da moldura.

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if _alfa_do_quadro > 0.0:
		var imagem: Variant = _quadro.get("imagem")
		if imagem != null:
			EstiloHUD.aro(self, tela.get_rect().grow(MOLDURA), EstiloHUD.com_alfa(EstiloHUD.CLARO, _alfa_do_quadro),
				MOLDURA)
		if imagem is String:
			_descrever(String(imagem), _alfa_do_quadro)
	_escrever(_legenda, _topo_da_legenda())
	_escrever(_pagina, _topo_do_texto(_pagina))


## A imagem que ainda não existe: a telinha preta, com a descrição no meio.
func _descrever(descricao: String, alfa: float) -> void:
	var rect := tela.get_rect()
	var cor := EstiloHUD.com_alfa(COR_DA_DESCRICAO, alfa)
	var linhas := PackedStringArray()
	for paragrafo in descricao.split("\n"):
		linhas.append_array(EstiloHUD.quebrar(FONTE, paragrafo, TAM_DESCRICAO, rect.size.x - 120.0))
	var entrelinha := TAM_DESCRICAO * ENTRELINHA
	var topo := rect.get_center().y - (FONTE.get_height(TAM_DESCRICAO) + (linhas.size() - 1) * entrelinha) * 0.5
	for i in linhas.size():
		var largura := FONTE.get_string_size(linhas[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_DESCRICAO).x
		draw_string(FONTE, Vector2(roundf(rect.get_center().x - largura * 0.5),
			roundf(topo + FONTE.get_ascent(TAM_DESCRICAO) + i * entrelinha)), linhas[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_DESCRICAO, cor)


## As letras que já apareceram, cada linha centrada embaixo da telinha (o
## centro sai da linha inteira: a linha não anda enquanto é escrita).
func _escrever(escrita: Escrita, topo: float) -> void:
	if escrita.alfa <= 0.0 or escrita.letras <= 0:
		return
	var cor := EstiloHUD.com_alfa(EstiloHUD.CLARO, escrita.alfa)
	var meio := tela.get_rect().get_center().x
	var sobra := escrita.letras
	for i in escrita.linhas.size():
		if sobra <= 0:
			break
		var linha := escrita.linhas[i]
		var largura := FONTE.get_string_size(linha, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_LETRA).x
		var base := Vector2(roundf(meio - largura * 0.5),
			roundf(topo + FONTE.get_ascent(TAM_LETRA) + i * TAM_LETRA * ENTRELINHA))
		draw_string(FONTE, base, linha.left(sobra), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_LETRA, cor)
		sobra -= linha.length()
