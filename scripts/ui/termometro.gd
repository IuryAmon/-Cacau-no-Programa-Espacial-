class_name Termometro
extends Control

# --- O TERMÔMETRO DO DESTILADOR (Laboratório) ---
#
# É por ele que a pessoa manda na temperatura do fundo da coluna do simulador de
# destilação. Um termômetro de parede: a ficha de papel do HUD (EstiloHUD.ficha)
# em pé, com o tubo de vidro e o bulbo dentro, em pixel art chapada como o resto
# da interface.
#
#   a COLUNA COLORIDA   a temperatura que o fundo TEM agora. Ela vai atrás do
#                       que foi pedido, aos poucos, e muda de cor com a
#                       temperatura (as mesmas cores da régua da coluna)
#   o PONTEIRO          à esquerda, com o número: a temperatura PEDIDA. É ele
#                       que a pessoa arrasta (ou que as setas levam)
#   as MARCAS           à direita, uma para cada substância da mistura, na
#                       altura do ponto de ebulição dela, com a molécula e o
#                       número. É por elas que se vê quem já passou do ponto e
#                       vai ferver
#
# O termômetro não decide nada: quem o usa (scripts/laboratorio/destilador.gd)
# lê os cliques, pergunta "graus_no_ponto()" e diz o que mostrar com
# "definir_faixa()", "definir_marcas()", "pedida" e "medida".
#
# COMO EDITAR NO EDITOR: a ficha fica no meio do nó, de cima a baixo dele. À
# esquerda ficam o ponteiro e o número pedido; à direita, as marcas. Dê ao nó a
# altura que o termômetro deve ter.

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

## A ficha de papel em que o tubo está preso.
const LARGURA_DA_FICHA := 52.0
const LARGURA_DO_TUBO := 20.0
const LADO_DO_BULBO := 32.0
## Do alto do nó até o começo da escala, e do fim dela até o pé do nó (onde
## fica o bulbo).
const FOLGA_DE_CIMA := 26.0
const FOLGA_DE_BAIXO := 62.0
const COR_DO_VIDRO := Color("1c2440")

## Os dois extremos da escala, em °C.
var minima: float = 0.0
var maxima: float = 100.0
## O que a pessoa pediu (onde o ponteiro está).
var pedida: float = 0.0:
	set(valor):
		if not is_equal_approx(valor, pedida):
			pedida = valor
			queue_redraw()
## O que o fundo da coluna tem agora (até onde a coluna colorida sobe).
var medida: float = 0.0:
	set(valor):
		if not is_equal_approx(valor, medida):
			medida = valor
			queue_redraw()
## As marcas dos pontos de ebulição: [{"chave" (a substância), "graus"}].
var marcas: Array[Dictionary] = []
## Devolve a cor de uma temperatura (a régua da coluna). Sem isto, laranja.
var cor_da_temperatura: Callable = Callable()
## O ponteiro aceso: em foco ou sendo arrastado.
var em_foco: bool = false:
	set(valor):
		if valor != em_foco:
			em_foco = valor
			queue_redraw()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func definir_faixa(nova_minima: float, nova_maxima: float) -> void:
	minima = nova_minima
	maxima = maxf(nova_maxima, nova_minima + 1.0)
	queue_redraw()


func definir_marcas(novas: Array[Dictionary]) -> void:
	marcas = novas
	queue_redraw()


# ─────────────────────────────────────────────────────────────
# ONDE FICA CADA COISA (px do nó)
# ─────────────────────────────────────────────────────────────

## A altura (y) em que a escala marca esta temperatura. Fora da escala, a
## altura do extremo mais próximo.
func altura_de(graus: float) -> float:
	var t := clampf(inverse_lerp(minima, maxima, graus), 0.0, 1.0)
	return lerpf(size.y - FOLGA_DE_BAIXO, FOLGA_DE_CIMA, t)


## A temperatura que a escala marca na altura y (presa entre os extremos).
func graus_no_ponto(y: float) -> float:
	var t := inverse_lerp(size.y - FOLGA_DE_BAIXO, FOLGA_DE_CIMA, y)
	return lerpf(minima, maxima, clampf(t, 0.0, 1.0))


## A ficha de papel do termômetro.
func retangulo_da_ficha() -> Rect2:
	return Rect2(roundf((size.x - LARGURA_DA_FICHA) * 0.5), 0.0, LARGURA_DA_FICHA, size.y)


## O tubo de vidro, do alto da escala até o bulbo.
func retangulo_do_tubo() -> Rect2:
	var bulbo := retangulo_do_bulbo()
	var topo := FOLGA_DE_CIMA - 12.0
	return Rect2(roundf((size.x - LARGURA_DO_TUBO) * 0.5), topo, LARGURA_DO_TUBO, bulbo.position.y + 6.0 - topo)


func retangulo_do_bulbo() -> Rect2:
	return Rect2(roundf((size.x - LADO_DO_BULBO) * 0.5), size.y - LADO_DO_BULBO - 12.0, LADO_DO_BULBO, LADO_DO_BULBO)


## Onde clicar e arrastar pega: a ficha, com o lugar do ponteiro à esquerda.
func retangulo_de_pegar() -> Rect2:
	var ficha := retangulo_da_ficha()
	return Rect2(ficha.position.x - 40.0, FOLGA_DE_CIMA - 14.0, ficha.size.x + 40.0,
		size.y - FOLGA_DE_BAIXO - FOLGA_DE_CIMA + 28.0)


## O mesmo, na tela.
func retangulo_de_pegar_na_tela() -> Rect2:
	var local := retangulo_de_pegar()
	return Rect2(global_position + local.position, local.size)


# ─────────────────────────────────────────────────────────────
# DESENHO
# ─────────────────────────────────────────────────────────────

func _draw() -> void:
	var ficha := retangulo_da_ficha()
	var tubo := retangulo_do_tubo()
	var bulbo := retangulo_do_bulbo()
	var cor := _cor(medida)
	EstiloHUD.ficha(self, ficha)

	# O tubo e o bulbo: o contorno de tinta, o vidro escuro e a coluna colorida.
	EstiloHUD.bloco(self, tubo.grow(2.0), EstiloHUD.TINTA, 4.0)
	EstiloHUD.bloco(self, bulbo.grow(2.0), EstiloHUD.TINTA, 8.0)
	draw_rect(tubo, COR_DO_VIDRO)
	EstiloHUD.bloco(self, bulbo, cor, 6.0)
	var topo := roundf(altura_de(medida))
	draw_rect(Rect2(tubo.position.x + 4.0, topo, tubo.size.x - 8.0, bulbo.position.y + 4.0 - topo), cor)
	# Um brilho de vidro, de cima a baixo, e outro no bulbo.
	draw_rect(Rect2(tubo.position.x + 2.0, tubo.position.y + 4.0, 2.0, tubo.size.y - 12.0),
		Color(EstiloHUD.CLARO, 0.3))
	draw_rect(Rect2(bulbo.position + Vector2(6, 6), Vector2(6, 4)), Color(EstiloHUD.CLARO, 0.45))

	# Os riscos da escala, em tinta, no papel à direita do tubo: um a cada
	# décimo, mais compridos nas pontas e no meio.
	for i in 11:
		var y := roundf(lerpf(size.y - FOLGA_DE_BAIXO, FOLGA_DE_CIMA, i / 10.0))
		var comprido := i % 5 == 0
		draw_rect(Rect2(tubo.end.x + 4.0, y - 1.0, 8.0 if comprido else 4.0, 2.0), EstiloHUD.TINTA_FRACA)
	_desenhar_as_marcas(ficha)
	_desenhar_o_ponteiro(ficha)


## As marcas dos pontos de ebulição, à direita da ficha: o traço, a molécula e
## o número. Duas marcas muito perto uma da outra se afastam o bastante para
## as duas se lerem.
func _desenhar_as_marcas(ficha: Rect2) -> void:
	var em_ordem := marcas.duplicate()
	em_ordem.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["graus"]) > float(b["graus"]))
	var ultimo := -INF
	for marca: Dictionary in em_ordem:
		var graus := float(marca["graus"])
		var y := roundf(altura_de(graus))
		# O rótulo desce se o de cima estiver encostado; o traço fica no lugar.
		var y_do_texto := maxf(y, ultimo + 26.0)
		ultimo = y_do_texto
		var chave := String(marca["chave"])
		var cor: Color = marca.get("cor", MisturasDoDestilador.substancia(chave).get("tona", EstiloHUD.CLARO))
		var x := ficha.end.x + 2.0
		draw_rect(Rect2(x, y - 3.0, 14.0, 6.0), EstiloHUD.CONTORNO)
		draw_rect(Rect2(x, y - 1.0, 12.0, 2.0), cor)
		if absf(y_do_texto - y) > 0.5:
			draw_line(Vector2(x + 14.0, y), Vector2(x + 20.0, y_do_texto), cor, 2.0)
		# Marca escrita (sem molécula): o texto, linha por linha, e o número
		# embaixo. É a do compressor ("AR VIRA LÍQUIDO", que anda com a pressão).
		if marca.has("texto"):
			var linhas := String(marca["texto"]).split("\n")
			var y_linha := y_do_texto - 4.0 - (linhas.size() - 1) * 6.0
			for linha in linhas:
				EstiloHUD.rotulo(self, FONTE, Vector2(x + 22.0, y_linha), linha, 11, cor)
				y_linha += 13.0
			EstiloHUD.rotulo(self, FONTE, Vector2(x + 22.0, y_linha + 2.0), MisturasDoDestilador.graus(graus), 11, cor)
			ultimo = y_linha + 2.0
			continue
		# A molécula deitada e, depois dela, o número.
		var largura := float(MoleculasDoDestilador.celula(chave).x) * MoleculasDoDestilador.ESCALA
		MoleculasDoDestilador.desenhar(self, chave, Vector2(x + 24.0 + largura * 0.5, y_do_texto), 0)
		# Fora da escala (o sal, que só ferve a 1465 °C), o número vem com a seta.
		var texto := MisturasDoDestilador.graus(graus)
		if graus > maxima:
			texto = "↑ " + texto
		elif graus < minima:
			texto = "↓ " + texto
		EstiloHUD.rotulo(self, FONTE, Vector2(x + 30.0 + largura, y_do_texto + 4.0), texto, 11, cor)


## O ponteiro da temperatura pedida, à esquerda: uma plaquinha com o número e a
## ponta encostada na ficha.
func _desenhar_o_ponteiro(ficha: Rect2) -> void:
	var y := roundf(altura_de(pedida))
	var texto := MisturasDoDestilador.graus(roundf(pedida))
	var largura := PecasDoLaboratorio.retangulo_da_plaquinha(Vector2.ZERO, texto).size.x
	var ponta := ficha.position.x - 2.0
	var meio := Vector2(ponta - 18.0 - largura * 0.5, y)
	# A ponta: degraus de pixels que afinam até a ficha.
	for i in 4:
		draw_rect(Rect2(ponta - 4.0 - i * 4.0, y - 2.0 - i * 2.0, 4.0, 4.0 + i * 4.0),
			EstiloHUD.CLARO if em_foco else EstiloHUD.PAPEL)
	if em_foco:
		EstiloHUD.bloco(self, PecasDoLaboratorio.retangulo_da_plaquinha(meio, texto).grow(4.0), EstiloHUD.CLARO)
	PecasDoLaboratorio.plaquinha(self, meio, texto, 22,
		PecasDoLaboratorio.PAPEL_ACESO if em_foco else EstiloHUD.PAPEL)


func _cor(graus: float) -> Color:
	if cor_da_temperatura.is_valid():
		return cor_da_temperatura.call(graus)
	return Color("f4a259")
