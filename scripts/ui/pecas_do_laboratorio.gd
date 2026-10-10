class_name PecasDoLaboratorio
extends RefCounted

# --- AS PEÇAS DE PAPEL DO MENU E DO LABORATÓRIO (traços compartilhados) ---
#
# O menu principal e o Laboratório são feitos do mesmo material do HUD do jogo
# (ver EstiloHUD): a FICHA, que é papel do caderno com moldura de tinta e uma
# sombra dura embaixo. Aqui ficam as peças que essas telas repetem, todas
# montadas com a ficha:
#
#   plaquinha   um nome escrito numa ficha baixa: o título de uma tela, uma
#               legenda. É a mesma das plaquinhas de temperatura da coluna de
#               destilação da história (mesmas medidas).
#   botão       uma ficha que se aperta: levanta quando está em foco, afunda
#               no clique e esmaece quando não pode ser usada.
#   escrita     texto centrado num ponto ou quebrado em linhas numa largura.
#
# Nada daqui sabe de átomo, mistura ou elemento: são só formas e letras.

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

## A plaquinha: a folga do texto até a borda de cada lado, e a altura para cada
## tamanho de letra (o tamanho mais este tanto).
const FOLGA_DA_PLAQUINHA := 10.0
const ALTURA_A_MAIS := 10.0
const MOLDURA_FINA := 2.0
const QUEDA_CURTA := 2.0

## O botão em foco sobe isto, e apertado desce isto.
const SUBIDA_DO_FOCO := 3.0
const DESCIDA_DO_CLIQUE := 2.0
## O papel do botão em foco: um tom mais claro.
const PAPEL_ACESO := Color("f4e6c8")
## O botão que não pode ser usado.
const ALFA_INDISPONIVEL := 0.4


# ─────────────────────────────────────────────────────────────
# PLAQUINHA
# ─────────────────────────────────────────────────────────────

## Onde fica a plaquinha com o meio em "meio".
static func retangulo_da_plaquinha(meio: Vector2, texto: String, tamanho: int = 22) -> Rect2:
	var largura := FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x \
		+ FOLGA_DA_PLAQUINHA * 2.0
	var altura := float(tamanho) + ALTURA_A_MAIS
	return Rect2(roundf(meio.x - largura * 0.5), roundf(meio.y - altura * 0.5), largura, altura)


## Desenha a plaquinha com o meio em "meio" e devolve o retângulo dela.
## "inchada" são os px a mais de cada lado (o pulo de quando ela muda).
static func plaquinha(ci: CanvasItem, meio: Vector2, texto: String, tamanho: int = 22,
		papel: Color = EstiloHUD.PAPEL, alfa: float = 1.0, inchada: float = 0.0,
		tinta: Color = EstiloHUD.TINTA) -> Rect2:
	var caixa := retangulo_da_plaquinha(meio, texto, tamanho)
	if alfa <= 0.004:
		return caixa
	EstiloHUD.ficha(ci, caixa.grow(roundf(inchada)), alfa, papel, EstiloHUD.TINTA, MOLDURA_FINA, QUEDA_CURTA)
	ci.draw_string(FONTE, Vector2(caixa.position.x + FOLGA_DA_PLAQUINHA, _pe_da_letra(caixa, tamanho)), texto,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, EstiloHUD.com_alfa(tinta, alfa))
	return caixa


## A linha de base de um texto de uma linha só centrado, a olho, numa caixa.
static func _pe_da_letra(caixa: Rect2, tamanho: int) -> float:
	return roundf(caixa.position.y + caixa.size.y * 0.22 + FONTE.get_ascent(tamanho) * 0.86)


# ─────────────────────────────────────────────────────────────
# BOTÃO
# ─────────────────────────────────────────────────────────────

## Onde a ficha do botão é desenhada de verdade: no lugar, mais alta em foco e
## mais baixa apertada.
static func caixa_do_botao(caixa: Rect2, em_foco: bool, apertado: bool) -> Rect2:
	if apertado:
		return Rect2(caixa.position + Vector2(0.0, DESCIDA_DO_CLIQUE), caixa.size)
	if em_foco:
		return Rect2(caixa.position - Vector2(0.0, SUBIDA_DO_FOCO), caixa.size)
	return caixa


## A ficha de um botão, sem nada dentro (quem chama desenha o miolo). Devolve
## onde ela ficou.
static func ficha_de_botao(ci: CanvasItem, caixa: Rect2, em_foco: bool, apertado: bool,
		disponivel: bool = true, papel: Color = EstiloHUD.PAPEL, moldura: float = EstiloHUD.MOLDURA) -> Rect2:
	var alfa := 1.0 if disponivel else ALFA_INDISPONIVEL
	var foco := em_foco and disponivel
	var ficha := caixa_do_botao(caixa, foco, apertado and disponivel)
	var queda := EstiloHUD.QUEDA
	if apertado and disponivel:
		queda -= DESCIDA_DO_CLIQUE
	elif foco:
		queda += SUBIDA_DO_FOCO
	if foco:
		# Em foco, um aro claro em volta: é o que se vê de longe, e o que diz a
		# quem está nas teclas onde o foco está.
		EstiloHUD.bloco(ci, Rect2(ficha.position + Vector2(-4.0, -4.0), ficha.size + Vector2(8.0, 8.0 + queda)),
			EstiloHUD.CLARO)
	var cor_do_papel := papel
	if foco and papel == EstiloHUD.PAPEL:
		cor_do_papel = PAPEL_ACESO
	EstiloHUD.ficha(ci, ficha, alfa, cor_do_papel, EstiloHUD.TINTA, moldura, queda)
	return ficha


## Um botão com o texto no meio.
static func botao(ci: CanvasItem, caixa: Rect2, texto: String, em_foco: bool, apertado: bool,
		disponivel: bool = true, tamanho: int = 22, papel: Color = EstiloHUD.PAPEL) -> Rect2:
	var ficha := ficha_de_botao(ci, caixa, em_foco, apertado, disponivel, papel)
	escrever_no_meio(ci, ficha.get_center() - Vector2(0.0, 1.0), texto, tamanho,
		EstiloHUD.com_alfa(EstiloHUD.TINTA, 1.0 if disponivel else ALFA_INDISPONIVEL))
	return ficha


# ─────────────────────────────────────────────────────────────
# TECLAS
# ─────────────────────────────────────────────────────────────

## O lado de uma tecla desenhada nas dicas (o desenho de 16 px, 2x).
const LADO_DA_TECLA := 32.0
const TAM_DA_DICA := 11


## Uma fileira de dicas de teclado, centrada em "meio": cada dica é
## [[nomes das teclas], "o que elas fazem"], e as teclas são os desenhos da
## folha do teclado do jogo (BotoesControle: "tecla_w", "tecla_e"...),
## afundando em loop. É para quem está no teclado: de controle na mão, quem
## mostra os botões é a barra do cursor virtual, e isto não desenha nada.
## Quem chama precisa se redesenhar a cada quadro, para as teclas afundarem.
static func dicas_de_teclado(ci: CanvasItem, meio: Vector2, dicas: Array) -> void:
	if BotoesControle.controle_em_uso():
		return
	var entre_dicas := 28.0
	var total := 0.0
	for dica: Array in dicas:
		total += (dica[0] as Array).size() * (LADO_DA_TECLA + 2.0) + 6.0 + largura(String(dica[1]), TAM_DA_DICA)
	total += entre_dicas * (dicas.size() - 1)
	var x := meio.x - total * 0.5
	for dica: Array in dicas:
		for tecla: String in dica[0]:
			BotoesControle.desenhar(ci, Vector2(x + LADO_DA_TECLA * 0.5, meio.y), tecla, 2.0, Color.WHITE,
				BotoesControle.quadro_atual())
			x += LADO_DA_TECLA + 2.0
		x += 6.0
		EstiloHUD.rotulo(ci, FONTE, Vector2(x, meio.y + 4.0).round(), String(dica[1]), TAM_DA_DICA)
		x += largura(String(dica[1]), TAM_DA_DICA) + entre_dicas


# ─────────────────────────────────────────────────────────────
# ESCRITA
# ─────────────────────────────────────────────────────────────

static func largura(texto: String, tamanho: int) -> float:
	return FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x


## Escreve o texto com o meio (dos dois sentidos) em "meio".
static func escrever_no_meio(ci: CanvasItem, meio: Vector2, texto: String, tamanho: int, cor: Color) -> void:
	if texto.is_empty() or cor.a <= 0.0:
		return
	var sobe := FONTE.get_ascent(tamanho)
	var desce := FONTE.get_descent(tamanho)
	ci.draw_string(FONTE, Vector2(meio.x - largura(texto, tamanho) * 0.5, meio.y + (sobe - desce) * 0.5).round(),
		texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)


## Escreve o texto com o canto de cima à esquerda em "canto".
static func escrever(ci: CanvasItem, canto: Vector2, texto: String, tamanho: int, cor: Color) -> void:
	if texto.is_empty() or cor.a <= 0.0:
		return
	ci.draw_string(FONTE, Vector2(canto.x, canto.y + FONTE.get_ascent(tamanho)).round(), texto,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)


## Escreve o texto quebrado em linhas que cabem em "caixa.size.x", cada linha
## centrada (ou encostada à esquerda), a partir do alto da caixa. A entrelinha
## é escolha de quem chama (a da fonte é apertada demais para parágrafo).
## Devolve a altura escrita.
static func escrever_em_linhas(ci: CanvasItem, caixa: Rect2, texto: String, tamanho: int, cor: Color,
		entrelinha: float, centrado: bool = true) -> float:
	var linhas := EstiloHUD.quebrar(FONTE, texto, tamanho, caixa.size.x)
	var y := caixa.position.y + FONTE.get_ascent(tamanho)
	for linha in linhas:
		var x := caixa.position.x
		if centrado:
			x += (caixa.size.x - largura(linha, tamanho)) * 0.5
		ci.draw_string(FONTE, Vector2(x, y).round(), linha, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)
		y += entrelinha
	return altura_das_linhas(linhas.size(), tamanho, entrelinha)


static func altura_das_linhas(linhas: int, tamanho: int, entrelinha: float) -> float:
	if linhas <= 0:
		return 0.0
	return FONTE.get_ascent(tamanho) + FONTE.get_descent(tamanho) + entrelinha * (linhas - 1)


## Quantas linhas o texto ocupa nesta largura.
static func contar_linhas(texto: String, tamanho: int, largura_disponivel: float) -> int:
	return EstiloHUD.quebrar(FONTE, texto, tamanho, largura_disponivel).size()
