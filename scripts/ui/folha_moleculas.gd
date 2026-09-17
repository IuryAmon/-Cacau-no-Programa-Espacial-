class_name FolhaMoleculas
extends RefCounted

# --- FOLHA DE ÁTOMOS E MOLÉCULAS ---
#
# Uma folha só para todos os puzzles de química: o do foguete (combustão do
# hidrogênio) e o do maçarico (combustão do acetileno). Quem precisa de um
# desenho pede pela fórmula:
#
#   FolhaMoleculas.textura("H2O")
#
# A folha é assets/UI/Computador receptor/atomos e moleculas.png, organizada
# em linhas (de cima para baixo) e, dentro de cada linha, da esquerda para a
# direita — exatamente a ordem de LINHAS, logo abaixo.
#
# OS DESENHOS SÃO ACHADOS SOZINHOS: não há coordenada nenhuma escrita aqui. Ao
# carregar, a folha é varrida — uma linha da folha é uma faixa de pixels
# visíveis separada da próxima por uma faixa transparente; um desenho é um
# trecho da faixa separado do vizinho por colunas transparentes. Cada recorte
# é a caixa exata do desenho com 1 px de folga em volta. Pode redesenhar,
# mudar tamanho e posição à vontade: basta manter a ordem e deixar um espaço
# vazio entre um desenho e outro.
#
# CO NÃO TEM DESENHO PRÓPRIO na folha. Ele é recortado do CO₂: fica o carbono
# (os pixels vermelhos) e o oxigênio do lado de cima/direita; sai o oxigênio
# de baixo/esquerda. Sai com o mesmo sombreado e a mesma escala das outras
# moléculas. Se a folha ganhar um CO desenhado, é só pôr "CO" em LINHAS.

const CAMINHO := "res://assets/UI/Computador receptor/atomos e moleculas.png"

const LINHAS := [
	["H", "O", "C"],
	["H2", "O2", "C2"],
	["H2O", "CO2"],
	["C2H2"],
]

## Trechos com menos pixels visíveis que isto são sujeira de pincel, não desenho.
const MINIMO_DE_PIXELS := 40

static var _recortes := {}
static var _cache := {}
static var _lida := false


## Desenho da fórmula pedida ("H2", "CO2", "C2H2", "CO"...). Fórmula que não
## está na folha devolve null e avisa no console.
static func textura(formula: String) -> Texture2D:
	if _cache.has(formula):
		return _cache[formula]
	_ler_folha()
	var saida: Texture2D = null
	if _recortes.has(formula):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(CAMINHO)
		atlas.region = Rect2(_recortes[formula])
		saida = atlas
	elif formula == "CO" and _recortes.has("CO2"):
		saida = _montar_co()
	else:
		push_warning("FolhaMoleculas: não há desenho para '%s' na folha." % formula)
	_cache[formula] = saida
	return saida


## Onde cada desenho foi achado na folha (fórmula -> Rect2i). Só para testes e
## para conferir a folha.
static func recortes() -> Dictionary:
	_ler_folha()
	return _recortes.duplicate()


static func _imagem() -> Image:
	var imagem := (load(CAMINHO) as Texture2D).get_image()
	if imagem.is_compressed():
		imagem.decompress()
	imagem.convert(Image.FORMAT_RGBA8)
	return imagem


static func _ler_folha() -> void:
	if _lida:
		return
	_lida = true
	var imagem := _imagem()
	var largura := imagem.get_width()
	var altura := imagem.get_height()
	# Só o canal alfa interessa: 1 byte por pixel, lido direto (sem get_pixel).
	var dados := imagem.get_data()
	var alfa := PackedByteArray()
	alfa.resize(largura * altura)
	for i in alfa.size():
		alfa[i] = dados[i * 4 + 3]

	# Faixas horizontais com algo desenhado = as linhas da folha.
	var faixas: Array[Vector2i] = []
	var inicio := -1
	for y in altura + 1:
		var tem := false
		if y < altura:
			for x in largura:
				if alfa[y * largura + x] > 0:
					tem = true
					break
		if tem and inicio < 0:
			inicio = y
		elif not tem and inicio >= 0:
			faixas.append(Vector2i(inicio, y - 1))
			inicio = -1

	var linhas_achadas: Array = []
	for faixa in faixas:
		var desenhos: Array[Rect2i] = []
		inicio = -1
		for x in largura + 1:
			var tem := false
			if x < largura:
				for y in range(faixa.x, faixa.y + 1):
					if alfa[y * largura + x] > 0:
						tem = true
						break
			if tem and inicio < 0:
				inicio = x
			elif not tem and inicio >= 0:
				var caixa := _caixa_do_trecho(alfa, largura, inicio, x - 1, faixa)
				if caixa.size != Vector2i.ZERO:
					desenhos.append(caixa)
				inicio = -1
		if not desenhos.is_empty():
			linhas_achadas.append(desenhos)

	var esperado := LINHAS.map(func(l): return l.size())
	var achado := linhas_achadas.map(func(l): return l.size())
	if esperado != achado:
		push_warning("FolhaMoleculas: a folha tem %s desenhos por linha, mas LINHAS espera %s. Confira a ordem dos desenhos em '%s'." % [achado, esperado, CAMINHO])

	var limite := Rect2i(Vector2i.ZERO, imagem.get_size())
	for i in mini(LINHAS.size(), linhas_achadas.size()):
		for j in mini(LINHAS[i].size(), linhas_achadas[i].size()):
			_recortes[LINHAS[i][j]] = linhas_achadas[i][j].grow(1).intersection(limite)


## Caixa justa dos pixels visíveis de um trecho da faixa (x0..x1). Trecho com
## pouca coisa desenhada devolve uma caixa vazia.
static func _caixa_do_trecho(alfa: PackedByteArray, largura: int, x0: int, x1: int, faixa: Vector2i) -> Rect2i:
	var topo := faixa.y
	var base := faixa.x
	var pixels := 0
	for x in range(x0, x1 + 1):
		for y in range(faixa.x, faixa.y + 1):
			if alfa[y * largura + x] > 0:
				pixels += 1
				topo = mini(topo, y)
				base = maxi(base, y)
	if pixels < MINIMO_DE_PIXELS:
		return Rect2i()
	return Rect2i(x0, topo, x1 - x0 + 1, base - topo + 1)


## CO = CO₂ sem um dos oxigênios. Carbono é vermelho (R > B), oxigênio é azul
## (B > R) — inclusive brilho e sombra de cada esfera. Fica todo o vermelho e
## só o azul do lado de cima/direita do centro do carbono.
static func _montar_co() -> Texture2D:
	var co2 := _imagem().get_region(_recortes["CO2"])
	var soma := Vector2.ZERO
	var vermelhos := 0
	for y in co2.get_height():
		for x in co2.get_width():
			var pixel := co2.get_pixel(x, y)
			if pixel.a > 0.0 and pixel.r > pixel.b:
				soma += Vector2(x, y)
				vermelhos += 1
	if vermelhos == 0:
		push_warning("FolhaMoleculas: não achei o carbono (vermelho) no CO₂ para montar o CO.")
		return null
	var centro_c := soma / vermelhos
	var eixo := Vector2(1, -1).normalized()

	var saida := Image.create(co2.get_width(), co2.get_height(), false, Image.FORMAT_RGBA8)
	for y in co2.get_height():
		for x in co2.get_width():
			var pixel := co2.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			if pixel.r > pixel.b or (Vector2(x, y) - centro_c).dot(eixo) > 0.0:
				saida.set_pixel(x, y, pixel)

	# Recorta rente ao que sobrou, com o mesmo 1 px de folga dos outros.
	var uso := saida.get_used_rect().grow(1).intersection(Rect2i(Vector2i.ZERO, saida.get_size()))
	return ImageTexture.create_from_image(saida.get_region(uso))
