extends Node

# --- GERA A ARTE DO COMPRESSOR DE AR DO MAPA (as três camadas) ---
#
# Pinta, pixel a pixel, as camadas da máquina da sala do compressor
# (assets/fase nitrogenio/compressor/: estrutura.png, aparelho.png e cabo.png)
# nas medidas do ArteDoCompressor (scripts/fases/arte_do_compressor.gd), que
# são as mesmas que o raio X do puzzle usa. Pedaços da arte antiga ("compressor
# de ar.png") são reaproveitados: o armário do resfriador com o monitor, a base
# listrada, o manômetro e a placa de perigo.
#
# COMO RODAR: abra esta cena e aperte F6 (ou: godot --headless --path .
# res://tools/gerar_arte_do_compressor.tscn). Depois o editor reimporta as PNG
# sozinho. Quem quiser redesenhar à mão pode: basta manter cada peça no lugar
# das medidas (senão o raio X não cai em cima dela).

const ANTIGA := "res://assets/fase nitrogenio/compressor de ar.png"

## A paleta da arte antiga (uma letra por cor).
const COR := {
	"#": Color("101425"), "k": Color("181c32"), "n": Color("1e223c"), "d": Color("2a2f55"),
	"s": Color("3a4160"), "m": Color("5a6280"), "l": Color("8a93b8"), "c": Color("d9dcc8"),
	"Y": Color("f2c84b"), "R": Color("e8463a"), "r": Color("ff968c"),
	"B": Color("dcf5ff"), "b": Color("8fd8ff"), "q": Color("5096c8"),
	"C": Color("36f2fb"), "t": Color("1c9ca2"),
}

var _antiga: Image


func _ready() -> void:
	_antiga = Image.load_from_file(ProjectSettings.globalize_path(ANTIGA))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ArteDoCompressor.PASTA))
	_salvar(_estrutura(), ArteDoCompressor.ESTRUTURA)
	_salvar(_aparelho(), ArteDoCompressor.APARELHO)
	_salvar(_cabo(), ArteDoCompressor.CABO)
	print(">>> ARTE DO COMPRESSOR GERADA <<<")
	get_tree().quit()


func _salvar(imagem: Image, caminho: String) -> void:
	var erro := imagem.save_png(ProjectSettings.globalize_path(caminho))
	print(caminho, " -> ", "ok" if erro == OK else "ERRO %d" % erro)


func _nova() -> Image:
	return Image.create_empty(ArteDoCompressor.TAMANHO.x, ArteDoCompressor.TAMANHO.y, false, Image.FORMAT_RGBA8)


func _px(imagem: Image, x: int, y: int, letra: String) -> void:
	if x < 0 or y < 0 or x >= imagem.get_width() or y >= imagem.get_height():
		return
	if letra == ".":
		imagem.set_pixel(x, y, Color(0, 0, 0, 0))
	else:
		imagem.set_pixel(x, y, COR[letra])


func _retangulo(imagem: Image, r: Rect2i, letra: String) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_px(imagem, x, y, letra)


## Um bloco de aço: o contorno, o miolo e uma linha de luz em cima.
func _bloco(imagem: Image, r: Rect2i, miolo: String = "m", luz: String = "l", sombra: String = "s") -> void:
	_retangulo(imagem, r, "#")
	var dentro := r.grow(-1)
	if dentro.size.x <= 0 or dentro.size.y <= 0:
		return
	_retangulo(imagem, dentro, miolo)
	_retangulo(imagem, Rect2i(dentro.position, Vector2i(dentro.size.x, 1)), luz)
	if dentro.size.y > 2:
		_retangulo(imagem, Rect2i(dentro.position.x, dentro.end.y - 1, dentro.size.x, 1), sombra)


## A cor da arte antiga, como letra ("" se transparente ou fora da paleta).
func _letra_antiga(x: int, y: int) -> String:
	var c := _antiga.get_pixel(x, y)
	if c.a < 0.5:
		return ""
	for letra: String in COR:
		if (COR[letra] as Color).is_equal_approx(Color(c.r, c.g, c.b)):
			return letra
	return "?"


## Copia um pedaço da arte antiga (os pixels opacos), deslocado.
func _copiar(imagem: Image, de: Rect2i, deslocamento: Vector2i, pular: String = "") -> void:
	for y in range(de.position.y, de.end.y):
		for x in range(de.position.x, de.end.x):
			var c := _antiga.get_pixel(x, y)
			if c.a < 0.5:
				continue
			if not pular.is_empty() and pular.contains(_letra_antiga(x, y)):
				continue
			var destino := Vector2i(x, y) + deslocamento
			if destino.x >= 0 and destino.y >= 0 and destino.x < imagem.get_width() and destino.y < imagem.get_height():
				imagem.set_pixelv(destino, c)


# ─────────────────────────────────────────────────────────────
# A ESTRUTURA (fica à vista com o puzzle aberto)
# ─────────────────────────────────────────────────────────────

func _estrutura() -> Image:
	var img := _nova()
	var A := ArteDoCompressor
	# A base listrada, inteira, da arte antiga (sem o pé do berço antigo, que
	# clareava a borda de cima dela).
	_copiar(img, Rect2i(0, A.BASE_DO_CHAO, A.TAMANHO.x, A.TAMANHO.y - A.BASE_DO_CHAO), Vector2i.ZERO)
	for x in range(59, 74):
		_px(img, x, A.BASE_DO_CHAO, "#")
	# O armário do resfriador: o monitor (de x 81 em diante) e o corpo (de x
	# 79). Os canos e o volante antigos que encostavam nele saem: a parede
	# esquerda dele volta a ser contorno.
	_copiar(img, Rect2i(81, A.ARMARIO.position.y, A.TAMANHO.x - 81, 39 - A.ARMARIO.position.y), Vector2i.ZERO, "Ct")
	for y in range(39, A.BASE_DO_CHAO):
		for x in range(A.ARMARIO.position.x, A.TAMANHO.x):
			var letra := _letra_antiga(x, y)
			if letra.is_empty():
				continue
			if x <= 80 and "BbqCt".contains(letra):
				letra = "#" if x == 79 else "s"
			if x >= 81 and "Ct".contains(letra):
				continue
			_px(img, x, y, letra)
	# Os canos do resfriador: o de ida sai da perna da direita, o de volta da
	# perna da esquerda (passando por trás do cilindro e do manômetro). Os dois
	# entram no armário.
	var perna_esq: Rect2i = A.PERNAS[0]
	var perna_dir: Rect2i = A.PERNAS[1]
	_cano(img, perna_dir.end.x, A.ARMARIO.position.x + 1, A.CANO_DE_IDA)
	_cano(img, perna_esq.end.x, A.ARMARIO.position.x + 1, A.CANO_DE_VOLTA)
	# As pernas que seguram a câmara (começam escondidas atrás dela).
	for perna: Rect2i in A.PERNAS:
		var r := Rect2i(perna.position.x, A.CASCO.end.y - 4, perna.size.x, perna.end.y - (A.CASCO.end.y - 4))
		_retangulo(img, r, "#")
		_retangulo(img, Rect2i(r.position.x + 1, r.position.y, r.size.x - 2, r.size.y), "s")
		_retangulo(img, Rect2i(r.position.x + 1, r.position.y, 1, r.size.y), "l")
		# O pé, um pouco mais largo, assentado na base.
		_retangulo(img, Rect2i(r.position.x - 1, A.BASE_DO_CHAO - 2, r.size.x + 2, 2), "#")
		_retangulo(img, Rect2i(r.position.x, A.BASE_DO_CHAO - 2, r.size.x, 1), "m")
	return img


## Um cano de 3 linhas (luz, cor, sombra), com "meio" na do meio.
func _cano(img: Image, de_x: int, ate_x: int, meio: int) -> void:
	for x in range(de_x, ate_x + 1):
		_px(img, x, meio - 1, "B")
		_px(img, x, meio, "b")
		_px(img, x, meio + 1, "q")


# ─────────────────────────────────────────────────────────────
# O APARELHO (o que o raio X troca)
# ─────────────────────────────────────────────────────────────

func _aparelho() -> Image:
	var img := _nova()
	var A := ArteDoCompressor
	_casco(img)
	# A placa de perigo da arte antiga, no meio da câmara.
	var meio_x := A.CASCO.position.x + A.CASCO.size.x / 2
	_copiar(img, Rect2i(20, 60, 20, 9), Vector2i(meio_x - 10 - 20, 25 - 60))
	# O cano do manômetro: sai da válvula, vai para a direita e desce até ele.
	var centro := Vector2i(floori(A.MANOMETRO.x), floori(A.MANOMETRO.y))
	var topo_do_manometro := centro.y - int(A.RAIO_DO_MANOMETRO) - 1
	var linha := A.VALVULA.position.y + A.VALVULA.size.y / 2
	for x in range(A.VALVULA.end.x, centro.x + 2):
		_px(img, x, linha - 1, "#")
		_px(img, x, linha + 1, "#")
	for y in range(linha - 1, topo_do_manometro + 1):
		_px(img, centro.x - 1, y, "#")
		_px(img, centro.x + 1, y, "#")
	for x in range(A.VALVULA.end.x, centro.x + 1):
		_px(img, x, linha, "l")
	for y in range(linha, topo_do_manometro + 1):
		_px(img, centro.x, y, "l")
	# A válvula: o corpo em volta do gargalo e o volante (ciano) à esquerda.
	_bloco(img, A.VALVULA, "m", "l", "s")
	var v := Vector2i(floori(A.VOLANTE.x), floori(A.VOLANTE.y))
	var volante := [".CCC.", "CtttC", "Ct#tC", "CtttC", ".CCC."]
	for dy in volante.size():
		for dx in (volante[dy] as String).length():
			var letra := (volante[dy] as String)[dx]
			if letra != ".":
				_px(img, v.x - 2 + dx, v.y - 2 + dy, letra)
	# A cabeça do berço, por cima da tampa do cilindro.
	_bloco(img, A.CABECA_DO_BERCO, "m", "l", "s")
	_retangulo(img, Rect2i(A.CABECA_DO_BERCO.position.x + 2, A.CABECA_DO_BERCO.position.y + 3,
		A.CABECA_DO_BERCO.size.x - 4, 1), "d")
	# As garras, uma de cada lado do cilindro.
	var vao_x := A.CILINDRO.x + A.VAO_NA_ARTE_DO_CILINDRO.position.x
	var garra_esq := Rect2i(vao_x - 1 - A.GARRA.x, A.LINHA_DAS_GARRAS, A.GARRA.x, A.GARRA.y)
	var garra_dir := Rect2i(vao_x + A.VAO_NA_ARTE_DO_CILINDRO.size.x + 1, A.LINHA_DAS_GARRAS, A.GARRA.x, A.GARRA.y)
	_bloco(img, garra_esq, "s", "l", "d")
	_bloco(img, garra_dir, "s", "l", "d")
	# O manômetro da arte antiga (o mostrador e o toquinho de cima).
	_copiar(img, Rect2i(24, 35, 13, 14), Vector2i(centro.x - 30, centro.y - 6 - 36), "mslcd")
	return img


## O casco de aço da câmara: faixas verticais (a luz à esquerda, a sombra à
## direita), a borda de cima, duas emendas com rebites e o fundo.
func _casco(img: Image) -> void:
	var c := ArteDoCompressor.CASCO
	var x0 := c.position.x
	var x1 := c.end.x - 1
	var y0 := c.position.y
	var y1 := c.end.y - 1
	for y in range(y0 + 1, y1):
		for x in range(x0 + 1, x1):
			var letra := "m"
			var k := x - x0
			if k == 1:
				letra = "m"
			elif k <= 4:
				letra = "l"
			elif k == 5:
				letra = "c"
			elif x >= x1 - 5 and x < x1 - 1:
				letra = "s"
			elif x == x1 - 1:
				letra = "d"
			_px(img, x, y, letra)
	# A borda de cima (onde a haste entra) e a sombra embaixo dela.
	for x in range(x0 + 1, x1):
		_px(img, x, y0 + 1, "l")
		_px(img, x, y0 + 2, "s")
	# As emendas, com rebites a cada 6 pixels.
	for emenda: int in [19, 35]:
		for x in range(x0 + 1, x1):
			_px(img, x, emenda, "l")
			_px(img, x, emenda + 1, "c" if (x - x0 - 5) % 6 == 0 else "s")
			_px(img, x, emenda + 2, "s")
	# O fundo.
	for x in range(x0 + 1, x1):
		_px(img, x, y1 - 1, "d")
	# O contorno, com os quatro cantos arredondados.
	for x in range(x0 + 1, x1):
		_px(img, x, y0, "#")
		_px(img, x, y1, "#")
	for y in range(y0 + 1, y1):
		_px(img, x0, y, "#")
		_px(img, x1, y, "#")


# ─────────────────────────────────────────────────────────────
# O CABO (a barra vermelha e a haste)
# ─────────────────────────────────────────────────────────────

func _cabo() -> Image:
	var A := ArteDoCompressor
	var largura := A.BARRA_DO_CABO.x
	var altura := A.BARRA_DO_CABO.y + A.HASTE
	var img := Image.create_empty(largura, altura, false, Image.FORMAT_RGBA8)
	var barra := [
		"." + "#".repeat(largura - 2) + ".",
		"#" + "r".repeat(largura - 2) + "#",
		"#" + "R".repeat(largura - 2) + "#",
		"." + "#".repeat(largura - 2) + ".",
	]
	for y in barra.size():
		for x in largura:
			var letra := (barra[y] as String)[x]
			if letra != ".":
				_px(img, x, y, letra)
	var meio := largura / 2
	for y in range(A.BARRA_DO_CABO.y, altura):
		_px(img, meio - 1, y, "#")
		_px(img, meio, y, "l")
		_px(img, meio + 1, y, "#")
	return img
