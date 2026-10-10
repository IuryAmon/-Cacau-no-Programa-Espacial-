class_name MoleculasDoDestilador
extends RefCounted

# --- AS MOLÉCULAS PEQUENAS DO DESTILADOR (Laboratório) ---
#
# As bolinhas que andam dentro da coluna do simulador de destilação. São do
# mesmo feitio das moléculas do ar da coluna da história ("moleculas do ar.png",
# na fase do nitrogênio): bolinhas de pixel art em três tons (a cor, um brilho
# em cima à esquerda e uma sombra embaixo à direita), com 4 quadros da molécula
# girando.
#
# Aqui elas não vêm de uma folha desenhada: são DESENHADAS POR CONTA a partir
# da tabela de substâncias (MisturasDoDestilador.SUBSTANCIAS), que diz a forma
# e as cores de cada uma. Assim, pôr uma substância nova no simulador não pede
# arte nova.
#
#   bola      um átomo sozinho: os gases nobres
#   dupla     dois átomos iguais: N₂ e O₂
#   agua      o oxigênio grande com os dois hidrogênios pequenos, em V
#   alcool    dois carbonos e, na ponta, o oxigênio (mais claro)
#   sal       um grão: o sódio pequeno e o cloro grande, encostados
#   cadeia    uma fileira de carbonos em zigue-zague, um para cada carbono da
#             molécula (os hidrogênios não são desenhados): o butano tem 4, o
#             octano 8, o hexadecano 16. É por serem cada vez mais compridas
#             que elas fervem cada vez mais quente
#
#   MoleculasDoDestilador.textura("N2")      a tira com os 4 quadros
#   MoleculasDoDestilador.recorte("N2", 0)   onde está o quadro 0 nela
#   MoleculasDoDestilador.celula("N2")       o tamanho de um quadro (px da arte)
#
# Como as da história, elas vão na tela ampliadas 2x (ESCALA).

const QUADROS := 4
## Quantos px de tela vale cada pixel da arte.
const ESCALA := 2.0

## O contorno de uma bolinha de cada diâmetro ("#" é a bolinha).
const BOLINHAS := {
	3: ["###", "###", "###"],
	4: [".##.", "####", "####", ".##."],
	5: [".###.", "#####", "#####", "#####", ".###."],
	6: [".####.", "######", "######", "######", "######", ".####."],
	7: ["..###..", ".#####.", "#######", "#######", "#######", ".#####.", "..###.."],
}

## chave da substância -> {"textura", "celula"}.
static var _feitas := {}


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

## A tira com os QUADROS quadros da molécula, lado a lado.
static func textura(chave: String) -> Texture2D:
	return _feita(chave).get("textura")


## O tamanho de um quadro, em pixels da arte (sempre quadrado).
static func celula(chave: String) -> Vector2i:
	return _feita(chave).get("celula", Vector2i(12, 12))


## Onde o quadro está na tira.
static func recorte(chave: String, quadro: int) -> Rect2:
	var lado := celula(chave)
	return Rect2(Vector2(lado.x * posmod(quadro, QUADROS), 0), Vector2(lado))


## Quanto a molécula deitada (o quadro 0, o do líquido) ocupa na tela, de um
## lado ao outro: é o que ela pede de lugar na poça.
static func largura_deitada(chave: String) -> float:
	return float(_feita(chave).get("largura", 12)) * ESCALA


## Desenha a molécula com o meio em "meio", no tamanho da tela (ampliada
## "ampliacao" vezes além da ESCALA).
static func desenhar(ci: CanvasItem, chave: String, meio: Vector2, quadro: int = 0,
		ampliacao: float = 1.0, cor: Color = Color.WHITE) -> void:
	var arte := textura(chave)
	if arte == null:
		return
	var medida := Vector2(celula(chave)) * ESCALA * ampliacao
	ci.draw_texture_rect_region(arte, Rect2((meio - medida * 0.5).round(), medida.round()),
		recorte(chave, quadro), cor)


# ─────────────────────────────────────────────────────────────
# O DESENHO
# ─────────────────────────────────────────────────────────────

static func _feita(chave: String) -> Dictionary:
	if _feitas.has(chave):
		return _feitas[chave]
	var dados := MisturasDoDestilador.substancia(chave)
	var feita := {}
	if not dados.is_empty():
		feita = _desenhar_a_tira(dados)
	_feitas[chave] = feita
	return feita


## As bolinhas da molécula deitada: [x, y, diâmetro, cores], a partir do meio.
## As cores são [base, brilho, sombra].
static func _bolinhas_de(dados: Dictionary) -> Array:
	var cores: Array = dados["cores"]
	# O átomo "diferente" da molécula (o hidrogênio da água, o oxigênio do
	# álcool, o sódio do sal): um tom mais claro da mesma cor.
	var claras: Array = [(cores[0] as Color).lerp(Color.WHITE, 0.55), Color.WHITE,
		(cores[0] as Color).lerp(Color.WHITE, 0.1)]
	match String(dados.get("forma", "bola")):
		"dupla":
			return [[-3.0, 0.0, 6, cores], [3.0, 0.0, 6, cores]]
		"agua":
			return [[-3.5, 2.5, 4, claras], [3.5, 2.5, 4, claras], [0.0, -1.0, 6, cores]]
		"alcool":
			return [[-4.0, 1.0, 5, cores], [0.0, -1.0, 5, cores], [4.0, 1.0, 4, claras]]
		"sal":
			return [[-3.0, 0.5, 4, claras], [1.5, 0.0, 6, cores]]
		"cadeia":
			var carbonos := maxi(int(dados.get("carbonos", 1)), 1)
			if carbonos == 1:
				return [[0.0, 0.0, 6, cores]]
			if carbonos == 2:
				return [[-2.5, 0.0, 5, cores], [2.5, 0.0, 5, cores]]
			# Uma fileira em zigue-zague, de 2 em 2 px.
			var lista: Array = []
			for i in carbonos:
				lista.append([(i - (carbonos - 1) * 0.5) * 2.0, 0.6 if i % 2 == 0 else -0.6, 3, cores])
			return lista
	return [[0.0, 0.0, 7, cores]]


static func _desenhar_a_tira(dados: Dictionary) -> Dictionary:
	var bolinhas := _bolinhas_de(dados)
	# O quadro é quadrado e do tamanho da molécula girando: a maior distância
	# de uma bolinha ao meio, dos dois lados, e um pixel de folga.
	var alcance := 0.0
	var esquerda := 0.0
	var direita := 0.0
	for bolinha: Array in bolinhas:
		var raio := float(bolinha[2]) * 0.5
		alcance = maxf(alcance, Vector2(bolinha[0], bolinha[1]).length() + raio)
		esquerda = minf(esquerda, float(bolinha[0]) - raio)
		direita = maxf(direita, float(bolinha[0]) + raio)
	var lado := maxi(ceili(alcance * 2.0) + 2, 9)
	var tira := Image.create_empty(lado * QUADROS, lado, false, Image.FORMAT_RGBA8)
	for quadro in QUADROS:
		var giro := quadro * PI / float(QUADROS)
		var meio := Vector2(lado * (quadro + 0.5), lado * 0.5)
		# As de trás primeiro (as de cima na tela), para a ordem não mudar de
		# um quadro para o outro.
		var giradas: Array = []
		for bolinha: Array in bolinhas:
			var onde := Vector2(bolinha[0], bolinha[1]).rotated(giro)
			giradas.append([onde, bolinha[2], bolinha[3]])
		if quadro > 0:
			giradas.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).y < (b[0] as Vector2).y)
		for girada: Array in giradas:
			_carimbar(tira, meio + (girada[0] as Vector2), int(girada[1]), girada[2])
	return {"textura": ImageTexture.create_from_image(tira), "celula": Vector2i(lado, lado),
		"largura": maxi(ceili(direita - esquerda), 3)}


## Uma bolinha de "diametro" px com o meio em "meio": a cor, o brilho no alto à
## esquerda e a sombra na beirada de baixo e da direita.
static func _carimbar(tira: Image, meio: Vector2, diametro: int, cores: Array) -> void:
	var contorno: Array = BOLINHAS[clampi(diametro, 3, 7)]
	var d := contorno.size()
	var canto := Vector2i((meio - Vector2(d, d) * 0.5).round())
	for y in d:
		var linha := String(contorno[y])
		for x in d:
			if linha[x] != "#":
				continue
			var px := canto.x + x
			var py := canto.y + y
			if px < 0 or py < 0 or px >= tira.get_width() or py >= tira.get_height():
				continue
			var cor: Color = cores[0]
			var embaixo_vazio := y + 1 >= d or String(contorno[y + 1])[x] != "#"
			var direita_vazia := x + 1 >= d or linha[x + 1] != "#"
			if (embaixo_vazio or direita_vazia) and x + y >= d - 1:
				cor = cores[2]
			elif d >= 5 and y == 1 and (x == 1 or x == 2):
				cor = cores[1]
			elif d < 5 and x == 0 and y == 0 and linha[0] == "#":
				cor = cores[1]
			elif d == 4 and x == 1 and y == 0:
				cor = cores[1]
			tira.set_pixel(px, py, cor)
