class_name AmostraChonps
extends RefCounted

# --- AMOSTRA DE UM ELEMENTO DO CHONPS ---
#
# O que a Cacau carrega de uma ala até o laboratório: pega a amostra na fase
# (célula do CHONPS, carvão da retorta), ela vai para a mochila, e só acende
# no painel quando é jogada no receptor (ver receptor_chonps.gd).
#
# Esta classe só responde perguntas sobre cada elemento — nome, cor, ícone e
# qual item da mochila o representa — para a célula, a retorta, o receptor e
# a mochila falarem a mesma língua.
#
# A ARTE DAS AMOSTRAS:
#   H e O  -> os próprios cilindros do prólogo (assets/itens/CILINDRO.png);
#   C      -> o carvão vegetal da retorta (assets/itens/Carvão.png);
#   N, P, S -> ainda sem arte: sai um frasco provisório desenhado por código,
#              na cor do elemento e com a letra.
# Para trocar qualquer uma, salve o PNG em
#   res://assets/itens/amostras/amostra_<LETRA>.png   (ex: amostra_N.png)
# e ele passa a valer no jogo inteiro — ficha de coleta, mochila e o pulo para
# dentro do receptor — sem mexer em código.

const PASTA_ARTE := "res://assets/itens/amostras/amostra_%s.png"
const PREFIXO_ID := "amostra_"

## O carbono não tem "amostra" própria: é o carvão que a retorta entrega.
const ID_CARVAO := "carvao_vegetal"

const NOMES := {
	"C": "Carbono",
	"H": "Hidrogênio",
	"O": "Oxigênio",
	"N": "Nitrogênio",
	"P": "Fósforo",
	"S": "Enxofre",
}

## Cor de cada elemento aceso: lâmpadas do receptor, brilho que sobe até o
## painel, acento na mochila. H, O e C repetem o acento que o HUD já dava ao
## cilindro/carvão de cada um.
const CORES := {
	"C": Color(0.98, 0.60, 0.28),
	"H": Color(1.0, 0.36, 0.38),
	"O": Color(0.36, 0.76, 1.0),
	"N": Color(0.42, 0.92, 0.52),
	"P": Color(1.0, 0.70, 0.30),
	"S": Color(1.0, 0.90, 0.32),
}

const DESCRICOES := {
	"C": "A base de toda molécula orgânica: cadeias de carbono formam açúcares, gorduras e o próprio DNA.",
	"H": "O elemento mais abundante do universo, e metade de cada molécula de água.",
	"O": "O que as células usam para tirar energia do alimento, na respiração.",
	"N": "Quase 80% do ar que você respira, e peça de toda proteína e do DNA.",
	"P": "Guarda a energia das células (ATP) e forma a espinha do DNA.",
	"S": "Faz as pontes que dão forma às proteínas.",
}

const RECADO_ENTREGA := "Leve ao receptor do painel CHONPS, no laboratório."

const TEXTURA_CILINDROS := preload("res://assets/itens/CILINDRO.png")
const TEXTURA_CARVAO := preload("res://assets/itens/Carvão.png")
## Onde cada cilindro mora na folha CILINDRO.png (mesmos recortes do world1).
const RECORTE_CILINDRO := {
	"H": Rect2(16, 28, 12, 36),
	"O": Rect2(32, 28, 16, 36),
}

static var _texturas: Dictionary = {}


## O id do item da mochila que representa a amostra.
static func id_no_inventario(letra: String) -> String:
	if letra == "C":
		return ID_CARVAO
	return PREFIXO_ID + letra


## Este item da mochila é uma amostra do CHONPS?
static func e_amostra(id: String) -> bool:
	return id == ID_CARVAO or (id.begins_with(PREFIXO_ID) and NOMES.has(id.trim_prefix(PREFIXO_ID)))


static func nome(letra: String) -> String:
	return NOMES.get(letra, letra)


static func cor(letra: String) -> Color:
	return CORES.get(letra, EstiloHUD.ACENTO_PADRAO)


## Nome que aparece na ficha de coleta: "Amostra de Nitrogênio (Elemento N)".
static func nome_do_item(letra: String) -> String:
	return "Amostra de %s (Elemento %s)" % [nome(letra), letra]


static func descricao(letra: String) -> String:
	return "%s %s" % [DESCRICOES.get(letra, ""), RECADO_ENTREGA]


static func textura(letra: String) -> Texture2D:
	if _texturas.has(letra):
		return _texturas[letra]

	var tex: Texture2D = null
	var caminho := PASTA_ARTE % letra
	if ResourceLoader.exists(caminho):
		tex = load(caminho)
	elif RECORTE_CILINDRO.has(letra):
		var atlas := AtlasTexture.new()
		atlas.atlas = TEXTURA_CILINDROS
		atlas.region = RECORTE_CILINDRO[letra]
		tex = atlas
	elif letra == "C":
		tex = TEXTURA_CARVAO
	else:
		tex = _frasco_provisorio(letra)

	_texturas[letra] = tex
	return tex


## A Cacau pegou a amostra no cenário: anota no Progresso e passa pela mesma
## ficha de coleta dos outros itens, que a guarda na mochila.
static func coletar(letra: String) -> void:
	Progresso.coletar_celula(letra)
	if Inventario.tela_hud_referencia != null:
		Inventario.tela_hud_referencia.exibir_popup(
			nome_do_item(letra), textura(letra), descricao(letra), id_no_inventario(letra))


# ─────────────────────────────────────────────
#  Frasco provisório (N, P, S enquanto não há arte)
# ─────────────────────────────────────────────

const LARGURA_FRASCO := 14
const ALTURA_FRASCO := 28

## Letras 5x7 do CHONPS, linha por linha ("#" = pixel aceso).
const FONTE := {
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"N": ["#...#", "##..#", "#.#.#", "#.#.#", "#..##", "#...#", "#...#"],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
}


## Frasco de vidro de 14x28 px, tampa de metal, líquido na cor do elemento e a
## letra gravada. Mesma proporção dos cilindros do prólogo, para as amostras
## parecerem da mesma família na mochila.
static func _frasco_provisorio(letra: String) -> ImageTexture:
	var img := Image.create(LARGURA_FRASCO, ALTURA_FRASCO, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var contorno := Color(0.07, 0.09, 0.13)
	var metal := Color(0.58, 0.63, 0.72)
	var metal_luz := Color(0.80, 0.85, 0.92)
	var vidro := Color(0.70, 0.86, 1.0, 0.45)
	var liquido := cor(letra)

	# Tampa
	_retangulo(img, 3, 0, 10, 4, contorno)
	_retangulo(img, 4, 1, 9, 3, metal)
	_retangulo(img, 4, 1, 4, 3, metal_luz)
	# Gargalo
	_retangulo(img, 4, 4, 9, 6, contorno)
	_retangulo(img, 5, 5, 8, 6, vidro)
	# Corpo: contorno com os cantos arredondados
	_retangulo(img, 0, 6, 13, 27, contorno)
	for canto in [Vector2i(0, 6), Vector2i(13, 6), Vector2i(0, 27), Vector2i(13, 27)]:
		img.set_pixelv(canto, Color(0, 0, 0, 0))
	_retangulo(img, 1, 7, 12, 10, vidro)
	# Líquido: menisco mais claro no topo, fundo mais escuro
	_retangulo(img, 1, 11, 12, 26, liquido)
	_retangulo(img, 1, 11, 12, 11, liquido.lightened(0.35))
	_retangulo(img, 1, 24, 12, 26, liquido.darkened(0.25))
	img.set_pixel(1, 26, contorno)
	img.set_pixel(12, 26, contorno)
	# Reflexo do vidro
	_retangulo(img, 2, 8, 2, 23, Color(1, 1, 1, 0.55))

	# Letra gravada, com sombra de 1 px
	var linhas: Array = FONTE.get(letra, [])
	var sombra := liquido.darkened(0.6)
	for y in linhas.size():
		var linha: String = linhas[y]
		for x in linha.length():
			if linha[x] == "#":
				img.set_pixel(5 + x + 1, 14 + y + 1, sombra)
	for y in linhas.size():
		var linha: String = linhas[y]
		for x in linha.length():
			if linha[x] == "#":
				img.set_pixel(5 + x, 14 + y, Color(1, 1, 1))

	return ImageTexture.create_from_image(img)


static func _retangulo(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			img.set_pixel(x, y, c)
