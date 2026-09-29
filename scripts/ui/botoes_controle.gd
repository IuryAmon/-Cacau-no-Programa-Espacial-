class_name BotoesControle
extends RefCounted

# --- OS BOTÕES DO CONTROLE (desenho e nome de cada um) ---
#
# Quem precisa MOSTRAR um botão do controle pergunta aqui: a barra de comandos
# dos puzzles (cursor_virtual.gd), os textos que trocam "E" por "□" quando a
# pessoa joga de controle (icones_no_texto.gd), a ficha de coleta e o cinto.
# Os desenhos saem da folha gdb-playstation-2.png — a mesma do direcional do
# tutorial —, então todo botão do jogo tem a mesma cara.
#
# Esta classe não sabe QUAL dispositivo está em uso (isso é do autoload
# Controle): ela só traduz ação -> botão -> desenho. É estática de propósito:
# o cinto e a ficha de coleta também rodam no editor (@tool), onde autoload
# nenhum existe.
#
# MARCAS NOS TEXTOS (ver "traduzir"):
#   {interact}           a tecla/botão da ação do mapa de entrada
#   {ui_right:D}         o que vem depois do ":" é o que o TECLADO mostra
#   {@cruz:CLIQUE}       botão pelo nome (sem ação), com o texto do teclado
#   {teclado:...}        trecho que só aparece no teclado
#   {controle:...}       trecho que só aparece no controle
#
# TECLAS DESENHADAS: num Label com IconesNoTexto (o "rotular" já põe um), a
# tecla do teclado também sai desenhada — ESC, E, W, A, S, D e M, da folha
# gdb-keyboard-2.png, a mesma do WASD e do E do world1. Tecla sem desenho
# (ESPAÇO, ENTER, CLIQUE) continua escrita.
#
# APERTANDO: as teclas e os botões ✕ ○ □ △ têm os 4 quadros da animação de
# apertar nas folhas; desenhados num texto, eles afundam em loop como o E da
# samambaia e o W das portas (ver "quadro_atual").

const FOLHA := preload("res://assets/UI/gdb-playstation-2.png")
const FOLHA_TECLADO := preload("res://assets/UI/gdb-keyboard-2.png")

## As teclas desenhadas (primeiro quadro da animação de 4 da folha).
const TECLAS := {
	"tecla_esc": Rect2(32, 16, 16, 16),
	"tecla_e": Rect2(96, 48, 16, 16),
	"tecla_w": Rect2(80, 48, 16, 16),
	"tecla_a": Rect2(64, 64, 16, 16),
	"tecla_s": Rect2(80, 64, 16, 16),
	"tecla_d": Rect2(96, 64, 16, 16),
	"tecla_m": Rect2(160, 80, 16, 16),
}

## Onde cada botão está na folha (a versão "flat": aro escuro e símbolo
## colorido, que lê bem por cima de qualquer tela). Todos são quadros de 16 px,
## menos o direcional, que a folha só tem grande (32 px).
const REGIOES := {
	"cruz": Rect2(16, 64, 16, 16),
	"bolinha": Rect2(16, 48, 16, 16),
	"quadrado": Rect2(16, 80, 16, 16),
	"triangulo": Rect2(16, 32, 16, 16),
	"l1": Rect2(336, 112, 16, 16),
	"r1": Rect2(336, 128, 16, 16),
	"l2": Rect2(336, 80, 16, 16),
	"r2": Rect2(336, 96, 16, 16),
	"l3": Rect2(216, 32, 16, 16),
	"r3": Rect2(280, 32, 16, 16),
	"analogico_esquerdo": Rect2(216, 32, 16, 16),
	"analogico_direito": Rect2(280, 32, 16, 16),
	"direcional": Rect2(16, 504, 32, 32),
	"options": Rect2(336, 48, 16, 16),
}

## A animação de apertar: 4 quadros, no ritmo do E do IconeInteragir. Na folha
## do teclado os quadros descem 112 px (a folha repete o teclado inteiro 4
## vezes); na do controle, os botões apertando ficam logo à direita do
## "flat", a partir de x = 48, um quadro a cada 16 px.
const QUADROS_APERTANDO := 4
const QUADROS_POR_SEGUNDO := 5.0
const PASSO_QUADRO_TECLADO := Vector2(0, 112)
const PASSO_QUADRO_CONTROLE := Vector2(16, 0)
const X_APERTANDO_CONTROLE := 48.0
const BOTOES_APERTANDO := ["cruz", "bolinha", "quadrado", "triangulo"]

## Direcional com o(s) braço(s) apertado(s) aceso(s). A folha não tem esses
## desenhos: eles são montados a partir do direcional (ver _direcional_aceso).
const DIRECOES := {
	"direcional_cima": ["cima"],
	"direcional_baixo": ["baixo"],
	"direcional_esquerda": ["esquerda"],
	"direcional_direita": ["direita"],
	"direcional_horizontal": ["esquerda", "direita"],
	"direcional_vertical": ["cima", "baixo"],
}
## O tom claro dos braços do direcional na folha, e a cor do braço aceso.
const COR_BRACO := Color8(0x68, 0x6F, 0x99)
const COR_BRACO_ACESO := Color(0.95, 0.97, 1.0)

## Ordem fixa dos botões que viram CARACTERE dentro de um texto. Cada um mora
## num código da área de uso privado do Unicode (a partir de U+E000), que
## fonte nenhuma desenha: é o IconesNoTexto que troca o caractere pelo botão.
## Só acrescente nomes no FIM — mudar a ordem troca os botões de textos já
## montados.
const NOMES := ["cruz", "bolinha", "quadrado", "triangulo", "l1", "r1", "l2", "r2",
	"l3", "r3", "analogico_esquerdo", "analogico_direito", "direcional", "options",
	"direcional_cima", "direcional_baixo", "direcional_esquerda", "direcional_direita",
	"direcional_horizontal", "direcional_vertical",
	"tecla_esc", "tecla_e", "tecla_w", "tecla_a", "tecla_s", "tecla_d", "tecla_m"]
const PRIMEIRO_CODIGO := 0xE000

static var _texturas := {}
static var _marca: RegEx = null


# ─────────────────────────────────────────────────────────────
# DESENHO
# ─────────────────────────────────────────────────────────────

## O desenho do botão (null para nome desconhecido). "quadro": o quadro da
## animação de apertar (0 = solto), para quem tem animação (ver "anima").
static func icone(nome: String, quadro: int = 0) -> Texture2D:
	if not anima(nome):
		quadro = 0
	var chave := nome if quadro == 0 else "%s#%d" % [nome, quadro]
	if _texturas.has(chave):
		return _texturas[chave]
	var textura: Texture2D = null
	if REGIOES.has(nome) or TECLAS.has(nome):
		var recorte := AtlasTexture.new()
		recorte.atlas = FOLHA if REGIOES.has(nome) else FOLHA_TECLADO
		recorte.region = _regiao(nome, quadro)
		textura = recorte
	elif DIRECOES.has(nome):
		textura = _direcional_aceso(DIRECOES[nome])
	else:
		return null
	_texturas[chave] = textura
	return textura


## O botão tem os quadros de apertar na folha?
static func anima(nome: String) -> bool:
	return TECLAS.has(nome) or nome in BOTOES_APERTANDO


## Quadro da animação de apertar agora. Sai do relógio, e não de um contador
## de cada texto: todos os botões da tela afundam juntos.
static func quadro_atual() -> int:
	return int(Time.get_ticks_msec() * 0.001 * QUADROS_POR_SEGUNDO) % QUADROS_APERTANDO


static func _regiao(nome: String, quadro: int) -> Rect2:
	if TECLAS.has(nome):
		var tecla: Rect2 = TECLAS[nome]
		return Rect2(tecla.position + PASSO_QUADRO_TECLADO * quadro, tecla.size)
	var regiao: Rect2 = REGIOES[nome]
	if quadro == 0 or not nome in BOTOES_APERTANDO:
		return regiao
	# O quadro 0 é o "flat" solto; os apertando começam logo ao lado dele.
	return Rect2(Vector2(X_APERTANDO_CONTROLE, regiao.position.y) + PASSO_QUADRO_CONTROLE * quadro,
		regiao.size)


static func existe(nome: String) -> bool:
	return REGIOES.has(nome) or DIRECOES.has(nome) or TECLAS.has(nome)


## Escala inteira para o botão acompanhar uma altura de texto (o botão fica um
## pouco maior que as letras, como nos jogos de console). Inteira porque pixel
## art em escala quebrada vira coluna de pixel com largura dobrada no meio.
static func escala_para(altura: float) -> float:
	return maxf(1.0, roundf(altura / 12.0))


## O direcional da folha com os braços pedidos pintados de claro. Cada pixel
## claro é de um braço só: o do eixo em que ele está mais longe do centro.
static func _direcional_aceso(lados: Array) -> Texture2D:
	var imagem := FOLHA.get_image()
	if imagem == null or imagem.is_empty():
		return icone("direcional")
	if imagem.is_compressed():
		imagem.decompress()
	var regiao := Rect2i(REGIOES["direcional"])
	var recorte := imagem.get_region(regiao)
	recorte.convert(Image.FORMAT_RGBA8)
	var centro := Vector2(regiao.size) * 0.5
	for y in recorte.get_height():
		for x in recorte.get_width():
			var cor := recorte.get_pixel(x, y)
			if cor.a < 0.5 or absf(cor.r - COR_BRACO.r) + absf(cor.g - COR_BRACO.g) \
					+ absf(cor.b - COR_BRACO.b) > 0.03:
				continue
			var d := Vector2(x + 0.5, y + 0.5) - centro
			var lado := ""
			if absf(d.x) > absf(d.y):
				lado = "direita" if d.x > 0.0 else "esquerda"
			else:
				lado = "baixo" if d.y > 0.0 else "cima"
			if lado in lados:
				recorte.set_pixel(x, y, COR_BRACO_ACESO)
	return ImageTexture.create_from_image(recorte)


## Botão desenhado centrado em "centro", no tamanho de um quadro de 16 px vezes
## a escala (o direcional grande encolhe para o mesmo lugar). Devolve a largura.
static func desenhar(ci: CanvasItem, centro: Vector2, nome: String, escala: float,
		cor: Color = Color.WHITE, quadro: int = 0) -> float:
	var textura := icone(nome, quadro)
	if textura == null:
		return 0.0
	var lado := 16.0 * escala
	ci.draw_texture_rect(textura, Rect2((centro - Vector2(lado, lado) * 0.5).round(),
		Vector2(lado, lado)), false, cor)
	return lado


# ─────────────────────────────────────────────────────────────
# AÇÃO -> BOTÃO / TECLA
# ─────────────────────────────────────────────────────────────

## Nome do botão do controle ligado a uma ação do mapa de entrada ("" se ela
## não tiver botão). O primeiro botão da ação vence; analógico só se não houver
## botão nenhum.
static func nome_da_acao(acao: StringName) -> String:
	if not InputMap.has_action(acao):
		return ""
	var eixo := ""
	for evento in InputMap.action_get_events(acao):
		if evento is InputEventJoypadButton:
			return nome_do_botao(evento.button_index)
		if eixo == "" and evento is InputEventJoypadMotion:
			eixo = _nome_do_eixo(evento.axis)
	return eixo


static func nome_do_botao(botao: JoyButton) -> String:
	match botao:
		JOY_BUTTON_A:
			return "cruz"
		JOY_BUTTON_B:
			return "bolinha"
		JOY_BUTTON_X:
			return "quadrado"
		JOY_BUTTON_Y:
			return "triangulo"
		JOY_BUTTON_LEFT_SHOULDER:
			return "l1"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "r1"
		JOY_BUTTON_LEFT_STICK:
			return "l3"
		JOY_BUTTON_RIGHT_STICK:
			return "r3"
		JOY_BUTTON_START:
			return "options"
		JOY_BUTTON_DPAD_UP:
			return "direcional_cima"
		JOY_BUTTON_DPAD_DOWN:
			return "direcional_baixo"
		JOY_BUTTON_DPAD_LEFT:
			return "direcional_esquerda"
		JOY_BUTTON_DPAD_RIGHT:
			return "direcional_direita"
	return ""


static func _nome_do_eixo(eixo: JoyAxis) -> String:
	match eixo:
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
			return "analogico_esquerdo"
		JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
			return "analogico_direito"
		JOY_AXIS_TRIGGER_LEFT:
			return "l2"
		JOY_AXIS_TRIGGER_RIGHT:
			return "r2"
	return ""


## Tecla do TECLADO ligada à ação, do jeito que se escreve na tela ("E",
## "ESC", "ESPAÇO"). Sem tecla, vale o botão do mouse.
static func tecla_da_acao(acao: StringName) -> String:
	if not InputMap.has_action(acao):
		return ""
	for evento in InputMap.action_get_events(acao):
		if evento is InputEventKey:
			var codigo: Key = evento.keycode if evento.keycode != KEY_NONE else evento.physical_keycode
			return nome_da_tecla(codigo)
	for evento in InputMap.action_get_events(acao):
		if evento is InputEventMouseButton:
			return "CLIQUE" if evento.button_index == MOUSE_BUTTON_LEFT else "BOTÃO DIREITO"
	return ""


static func nome_da_tecla(codigo: Key) -> String:
	match codigo:
		KEY_ESCAPE:
			return "ESC"
		KEY_SPACE:
			return "ESPAÇO"
		KEY_ENTER, KEY_KP_ENTER:
			return "ENTER"
		KEY_SHIFT:
			return "SHIFT"
		KEY_LEFT:
			return "←"
		KEY_RIGHT:
			return "→"
		KEY_UP:
			return "↑"
		KEY_DOWN:
			return "↓"
	return OS.get_keycode_string(codigo).to_upper()


## Nome de botão para uma dica: aceita tanto um nome da folha ("cruz") quanto
## uma ação do mapa ("ui_cancel").
static func nome_para_dica(chave: String) -> String:
	if existe(chave):
		return chave
	return nome_da_acao(chave)


# ─────────────────────────────────────────────────────────────
# TEXTO
# ─────────────────────────────────────────────────────────────

## A pessoa está de controle na mão? Sempre falso no editor: as peças @tool
## (cinto, ficha de coleta, rótulos do blockout) rodam lá, onde o autoload
## Controle não existe.
static func controle_em_uso() -> bool:
	if Engine.is_editor_hint():
		return false
	var arvore := Engine.get_main_loop() as SceneTree
	if arvore == null:
		return false
	var controle := arvore.root.get_node_or_null(^"Controle")
	return controle != null and controle.em_uso


## Escreve o modelo com marcas {acao} no Label e o mantém certo sozinho: trocou
## de teclado para controle, o Label se reescreve e o botão aparece desenhado.
## Seguro de chamar de script @tool — no editor fica o texto do teclado.
## "escala_minima": ver IconesNoTexto.
static func rotular(label: Label, modelo: String, escala_minima: float = 1.0) -> void:
	if label == null:
		return
	if Engine.is_editor_hint():
		label.text = traduzir(modelo, false)
		return
	var icones := IconesNoTexto.acoplar(label)
	icones.modelo = modelo
	icones.escala_minima = escala_minima
	label.text = traduzir(modelo, controle_em_uso(), true)


static func caractere(nome: String) -> String:
	var i := NOMES.find(nome)
	if i < 0:
		return ""
	return String.chr(PRIMEIRO_CODIGO + i)


static func eh_icone(codigo: int) -> bool:
	return codigo >= PRIMEIRO_CODIGO and codigo < PRIMEIRO_CODIGO + NOMES.size()


static func nome_do_caractere(codigo: int) -> String:
	if not eh_icone(codigo):
		return ""
	return NOMES[codigo - PRIMEIRO_CODIGO]


static func tem_icone(texto: String) -> bool:
	for i in texto.length():
		if eh_icone(texto.unicode_at(i)):
			return true
	return false


## Troca as marcas do texto pelo que o dispositivo mostra (ver o topo do
## arquivo). No controle o botão vira um caractere especial que só aparece
## desenhado num Label com IconesNoTexto. "teclas_desenhadas" faz o mesmo com
## as teclas do teclado que têm desenho — só para quem vai parar num Label
## desses.
static func traduzir(modelo: String, controle: bool, teclas_desenhadas: bool = false) -> String:
	if not modelo.contains("{"):
		return modelo
	if _marca == null:
		_marca = RegEx.create_from_string("\\{(@?[A-Za-z0-9_]+)(?::([^}]*))?\\}")
	var saida := ""
	var inicio := 0
	for achado in _marca.search_all(modelo):
		saida += modelo.substr(inicio, achado.get_start() - inicio)
		inicio = achado.get_end()
		var nome := achado.get_string(1)
		var resto := achado.get_string(2)
		var tem_resto := achado.get_start(2) >= 0
		match nome:
			"teclado":
				saida += "" if controle else resto
			"controle":
				saida += resto if controle else ""
			_:
				saida += _marca_traduzida(nome, resto, tem_resto, controle, teclas_desenhadas)
	return saida + modelo.substr(inicio)


static func _marca_traduzida(nome: String, texto_teclado: String, tem_texto: bool,
		controle: bool, teclas_desenhadas: bool) -> String:
	if nome.begins_with("@"):
		var botao := nome.substr(1)
		if controle and existe(botao):
			return caractere(botao)
		return _tecla(texto_teclado, teclas_desenhadas)
	if controle:
		var botao := nome_da_acao(nome)
		if botao != "":
			return caractere(botao)
	return _tecla(texto_teclado if tem_texto else tecla_da_acao(nome), teclas_desenhadas)


## A tecla escrita ("ESC") vira a tecla desenhada, quando existe o desenho.
static func _tecla(texto: String, desenhada: bool) -> String:
	var nome := "tecla_" + texto.to_lower()
	if desenhada and TECLAS.has(nome):
		return caractere(nome)
	return texto
