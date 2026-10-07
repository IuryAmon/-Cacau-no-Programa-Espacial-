@tool
class_name TexturaDeLuz
extends RefCounted
## Texturas de luz pintadas por conta: a forma da luz que uma PointLight2D joga
## no cenário, ou que um sprite soma no ar.
##
## Saem de dois jeitos, conforme os "degraus" pedidos:
##
##   LISA (degraus 0)        o degradê contínuo, que é o padrão do jogo: a luz
##                           clareia o cenário sem deixar marca nenhuma dela.
##   PIXELADA (degraus > 0)  a luz cai em patamares, com a emenda entre um e o
##                           outro feita em pontilhado, e cada pixel da textura
##                           é um pixel de arte do cenário.
##
## A conta é sempre feita na resolução da arte (um ponto para cada pixel do
## cenário, que tem escala 2). A lisa é ampliada ao dobro com interpolação
## antes de virar textura, para chegar ao tamanho do pixel do mundo sem
## quadriculado — por isso cada função devolve também a "escala": quantos
## pixels de arte vale um pixel da textura.
##
## As texturas são montadas uma vez e ficam guardadas: dez postes iguais usam a
## mesma, e trocar de fase não refaz nenhuma.

const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
## Quanto a textura lisa é ampliada depois da conta.
const AMPLIACAO_DA_LISA := 2

static var _guardadas: Dictionary = {}


## A luz de uma lâmpada comprida (um tubo deitado) apontada para baixo: um
## clarão em volta do tubo e um cone que abre até o chão.
##
## Medidas em pixels de arte. Devolve {"textura": ImageTexture, "fonte":
## Vector2, "escala": float} — "fonte" é onde fica o centro do tubo dentro da
## textura, e "escala" é quantos pixels de arte vale cada pixel dela.
static func cone(largura: int, alcance: int, abertura: float, degraus: int = 0, pontilhado: float = 0.5) -> Dictionary:
	var chave := "cone:%d:%d:%.3f:%d:%.3f" % [largura, alcance, abertura, degraus, pontilhado]
	if _guardadas.has(chave):
		return _guardadas[chave]

	var meia := largura * 0.5
	var tangente := lerpf(0.12, 0.9, clampf(abertura, 0.0, 1.0))
	var topo := 26
	var meia_largura := int(ceil(meia + alcance * tangente)) + 4
	var w := meia_largura * 2
	var h := topo + alcance + 2
	var dados := PackedByteArray()
	dados.resize(w * h)
	var fonte := Vector2(meia_largura, topo)

	for y in h:
		var py := float(y) + 0.5 - fonte.y
		# O que só depende da altura é contado uma vez por linha.
		var fundo := 0.0
		var fim := 0.0
		if py > 0.0:
			# Cai DEVAGAR com a distância — o que importa numa lâmpada de rua é
			# a poça no chão, lá embaixo, e não o ar logo abaixo do tubo. Só o
			# último quarto do alcance é que apaga.
			fundo = 1.0 - 0.45 * pow(clampf(py / float(alcance), 0.0, 1.0), 0.8)
			fim = clampf((alcance - py) / (alcance * 0.25), 0.0, 1.0)
		var meia_do_cone := meia + maxf(py, 0.0) * tangente
		# A luz é igual dos dois lados: a conta é feita para a metade esquerda e
		# espelhada (só o pontilhado é que é de cada pixel).
		for x in meia_largura:
			var px := fonte.x - (float(x) + 0.5)

			# Clarão em volta do tubo, para todos os lados.
			var fora := maxf(px - meia, 0.0)
			var valor := exp(-(fora * fora + py * py) / 225.0)

			# Cone: abre com a distância e fecha no alcance.
			if py > 0.0:
				var lado := clampf(1.0 - px / meia_do_cone, 0.0, 1.0)
				lado = lado * lado * (3.0 - 2.0 * lado)
				valor = maxf(valor, lado * fundo * fim)

			var espelho := w - 1 - x
			dados[y * w + x] = _byte(valor, x, y, degraus, pontilhado)
			dados[y * w + espelho] = _byte(valor, espelho, y, degraus, pontilhado)

	return _guardar(chave, w, h, dados, fonte, degraus <= 0)


## Um clarão oval em volta de um tubo deitado — o brilho da própria lâmpada no
## ar. Mesmas medidas e mesmo retorno do [method cone].
static func halo(largura: int, raio: int, degraus: int = 0, pontilhado: float = 0.5) -> Dictionary:
	var chave := "halo:%d:%d:%d:%.3f" % [largura, raio, degraus, pontilhado]
	if _guardadas.has(chave):
		return _guardadas[chave]

	var meia := largura * 0.5
	var meia_largura := int(ceil(meia)) + raio + 2
	var w := meia_largura * 2
	var h := (raio + 2) * 2
	var dados := PackedByteArray()
	dados.resize(w * h)
	var fonte := Vector2(w * 0.5, h * 0.5)

	for y in h:
		var py := float(y) + 0.5 - fonte.y
		for x in meia_largura:
			var px := fonte.x - (float(x) + 0.5)
			var fora := maxf(px - meia, 0.0)
			# Mais largo que alto: é um tubo, não uma lâmpada redonda.
			var d := sqrt(fora * fora * 0.55 + py * py)
			var valor := clampf(1.0 - d / float(raio), 0.0, 1.0)
			valor = valor * valor
			var espelho := w - 1 - x
			dados[y * w + x] = _byte(valor, x, y, degraus, pontilhado)
			dados[y * w + espelho] = _byte(valor, espelho, y, degraus, pontilhado)

	return _guardar(chave, w, h, dados, fonte, degraus <= 0)


## Um clarão redondo, para fontes pequenas (uma brasa, uma tela, um farol).
static func ponto(raio: int, degraus: int = 0, pontilhado: float = 0.5, queda: float = 1.6) -> Dictionary:
	var chave := "ponto:%d:%d:%.3f:%.3f" % [raio, degraus, pontilhado, queda]
	if _guardadas.has(chave):
		return _guardadas[chave]

	var meia := raio + 2
	var w := meia * 2
	var dados := PackedByteArray()
	dados.resize(w * w)
	var fonte := Vector2(meia, meia)
	# Redondo: basta contar um quarto e espelhar nos outros três.
	for y in meia:
		var py := fonte.y - (float(y) + 0.5)
		for x in meia:
			var px := fonte.x - (float(x) + 0.5)
			var d := sqrt(px * px + py * py)
			var valor := pow(clampf(1.0 - d / float(raio), 0.0, 1.0), queda)
			var xe := w - 1 - x
			var ye := w - 1 - y
			dados[y * w + x] = _byte(valor, x, y, degraus, pontilhado)
			dados[y * w + xe] = _byte(valor, xe, y, degraus, pontilhado)
			dados[ye * w + x] = _byte(valor, x, ye, degraus, pontilhado)
			dados[ye * w + xe] = _byte(valor, xe, ye, degraus, pontilhado)

	return _guardar(chave, w, w, dados, fonte, degraus <= 0)


# O byte de um pixel, a partir do valor liso de 0 a 1. Sem degraus, é o próprio
# valor. Com degraus, ele é derrubado para "degraus" patamares, e só o fim de
# cada patamar é pontilhado (a fração "pontilhado" dele); o resto é chapado.
static func _byte(valor: float, x: int, y: int, degraus: int, pontilhado: float) -> int:
	if degraus <= 0:
		return int(clampf(valor, 0.0, 1.0) * 255.0 + 0.5)
	var f := clampf(valor, 0.0, 1.0) * degraus
	var patamar := int(f)
	var janela := maxf(pontilhado, 0.0001)
	var emenda := (f - float(patamar) - (1.0 - janela)) / janela
	if emenda * 16.0 > float(BAYER[(x & 3) + (y & 3) * 4]) + 0.5:
		patamar += 1
	return mini(patamar, degraus) * 255 / degraus


# Um canal só (L8): a luz é branca, e quem dá a cor é a PointLight2D ou o
# `modulate` do sprite.
static func _guardar(chave: String, w: int, h: int, dados: PackedByteArray, fonte: Vector2, lisa: bool) -> Dictionary:
	var img := Image.create_from_data(w, h, false, Image.FORMAT_L8, dados)
	var escala := 1.0
	if lisa:
		# Ampliada com interpolação: a luz lisa chega ao tamanho do pixel do
		# mundo sem o quadriculado do pixel de arte.
		img.resize(w * AMPLIACAO_DA_LISA, h * AMPLIACAO_DA_LISA, Image.INTERPOLATE_BILINEAR)
		fonte *= float(AMPLIACAO_DA_LISA)
		escala = 1.0 / float(AMPLIACAO_DA_LISA)
	var resultado := {"textura": ImageTexture.create_from_image(img), "fonte": fonte, "escala": escala}
	_guardadas[chave] = resultado
	return resultado
