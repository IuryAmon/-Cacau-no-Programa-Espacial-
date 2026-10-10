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
#
# O AR DA FASE DO NITROGÊNIO (N₂ e Ar) TAMBÉM NÃO TEM DESENHO PRÓPRIO. O N₂ é
# o O₂ com as três cores trocadas (base, brilho e sombra) e o argônio, que é
# um átomo sozinho, é o O com as cores trocadas — ver RECOLORIDAS. Assim os
# três saem com o mesmo traço. As cores de cada um são as mesmas das moléculas
# pequenas da coluna de destilação ("assets/fase nitrogenio/moleculas do
# ar.png"). Se a folha ganhar um N₂ ou um Ar desenhado, é só pôr em LINHAS: o
# desenho vale mais que a troca de cor.
#
# AS MOLÉCULAS DO LABORATÓRIO (CH₄, NH₃, C₃H₈...) TAMBÉM NÃO ESTÃO NA FOLHA. O
# balanceamento do Laboratório tem muito mais reações que a história, e cada
# substância delas precisa de um desenho. Essas são MONTADAS com os átomos
# soltos da folha (H, O, C e o N trocado de cor), encostados um no outro do
# jeito das moléculas desenhadas: ver MONTADAS, que diz onde vai cada átomo e
# quem fica na frente de quem. Como nos outros casos, se a folha ganhar o
# desenho de uma delas, é só pôr em LINHAS.

const CAMINHO := "res://assets/UI/Computador receptor/atomos e moleculas.png"

const LINHAS := [
	["H", "O", "C"],
	["H2", "O2", "C2"],
	["H2O", "CO2"],
	["C2H2"],
]

## Trechos com menos pixels visíveis que isto são sujeira de pincel, não desenho.
const MINIMO_DE_PIXELS := 40

## As três cores do oxigênio na folha, na ordem base, brilho, sombra. É por
## elas que a troca de cor sabe que parte da esfera cada pixel é.
const CORES_DO_OXIGENIO: Array[Color] = [Color("2400b9"), Color("819fff"), Color("300057")]

## Desenhos que são outro desenho da folha com as cores trocadas: "de" é o
## desenho de origem e "cores" as novas, na mesma ordem (base, brilho, sombra).
const RECOLORIDAS := {
	"N2": {"de": "O2", "cores": [Color("3ecf72"), Color("d2ffd6"), Color("12704a")]},
	"N": {"de": "O", "cores": [Color("3ecf72"), Color("d2ffd6"), Color("12704a")]},
	"Ar": {"de": "O", "cores": [Color("c77dff"), Color("f6e2ff"), Color("6f2f9c")]},
}

## Moléculas montadas com os átomos soltos da folha. Cada átomo é [elemento, x,
## y]: o meio dele, em pixels da folha, a partir do meio da molécula (x cresce
## para a direita e y para baixo). A ordem da lista é a de desenhar: quem vem
## depois fica na frente. Os átomos se encostam mais ou menos como nas
## moléculas desenhadas (o meio de um a uns 60% da soma dos raios do outro).
const MONTADAS := {
	# Metano: o carbono com dois hidrogênios atrás e dois na frente.
	"CH4": [["H", -22, -20], ["H", 22, -20], ["C", 0, 0], ["H", -22, 20], ["H", 22, 20]],
	# Amônia: uma pirâmide, com o nitrogênio em cima e os três hidrogênios embaixo.
	"NH3": [["H", 0, 24], ["N", 0, 0], ["H", -22, 14], ["H", 22, 14]],
	"NO": [["N", -10, 11], ["O", 10, -11]],
	# Dióxido de nitrogênio: dobrado, com o nitrogênio no alto.
	"NO2": [["O", -28, 12], ["N", 0, -8], ["O", 28, 12]],
	# Água oxigenada: H-O-O-H, em zigue-zague.
	"H2O2": [["H", -32, 22], ["O", -10, 11], ["O", 10, -11], ["H", 30, 2]],
	# Hidrazina: dois nitrogênios, cada um com dois hidrogênios.
	"N2H4": [["H", -32, 2], ["H", 18, -34], ["N", -10, 11], ["N", 10, -11], ["H", -18, 34], ["H", 32, -2]],
	# Tetróxido de dinitrogênio: dois NO₂ ligados pelos nitrogênios.
	"N2O4": [["O", -44, 4], ["O", 22, -44], ["N", -12, 13], ["N", 12, -13], ["O", -22, 44], ["O", 44, -4]],
	# Propano: três carbonos em zigue-zague, com os hidrogênios apontando para fora.
	"C3H8": [["H", -68, 2], ["H", -16, -38], ["H", 16, -38], ["H", 68, 2],
		["C", -38, 10], ["C", 0, -10], ["C", 38, 10],
		["H", -58, 30], ["H", -22, 38], ["H", 22, 38], ["H", 58, 30]],
	# Etanol: dois carbonos e, na ponta, o oxigênio com o hidrogênio dele.
	"C2H6O": [["H", -70, 0], ["H", -18, -40], ["H", 14, -40],
		["C", -40, 8], ["C", -2, -12], ["O", 34, 6],
		["H", -60, 28], ["H", -24, 36], ["H", 58, 0]],
}

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
	elif RECOLORIDAS.has(formula) and _recortes.has(RECOLORIDAS[formula]["de"]):
		saida = _recolorir(RECOLORIDAS[formula]["de"], RECOLORIDAS[formula]["cores"])
	elif MONTADAS.has(formula):
		saida = _montar(formula)
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


## O desenho "origem" (feito de oxigênio) com as cores trocadas: cada pixel
## vira a cor nova da parte da esfera a que ele pertence — a das três cores do
## oxigênio de que ele está mais perto.
static func _recolorir(origem: String, cores: Array) -> Texture2D:
	return ImageTexture.create_from_image(_imagem_recolorida(origem, cores))


## Tem desenho para esta fórmula (na folha, trocado de cor ou montado)?
static func tem(formula: String) -> bool:
	_ler_folha()
	return _recortes.has(formula) or (formula == "CO" and _recortes.has("CO2")) \
		or (RECOLORIDAS.has(formula) and _recortes.has(RECOLORIDAS[formula]["de"])) \
		or (MONTADAS.has(formula) and _da_para_montar(formula))


## A molécula montada com os átomos soltos (ver MONTADAS), recortada rente com
## o mesmo 1 px de folga dos outros desenhos.
static func _montar(formula: String) -> Texture2D:
	if not _da_para_montar(formula):
		push_warning("FolhaMoleculas: falta na folha algum átomo para montar '%s'." % formula)
		return null
	var atomos: Array = MONTADAS[formula]
	var desenhos: Array[Image] = []
	var caixa := Rect2i()
	for i in atomos.size():
		var desenho := _imagem_do_atomo(String(atomos[i][0]))
		desenhos.append(desenho)
		var canto := Vector2i(int(atomos[i][1]), int(atomos[i][2])) - desenho.get_size() / 2
		var dele := Rect2i(canto, desenho.get_size())
		caixa = dele if i == 0 else caixa.merge(dele)
	var tela := Image.create_empty(caixa.size.x, caixa.size.y, false, Image.FORMAT_RGBA8)
	for i in atomos.size():
		var desenho := desenhos[i]
		var canto := Vector2i(int(atomos[i][1]), int(atomos[i][2])) - desenho.get_size() / 2 - caixa.position
		tela.blend_rect(desenho, Rect2i(Vector2i.ZERO, desenho.get_size()), canto)
	var usado := tela.get_used_rect().grow(1).intersection(Rect2i(Vector2i.ZERO, tela.get_size()))
	return ImageTexture.create_from_image(tela.get_region(usado))


static func _da_para_montar(formula: String) -> bool:
	for atomo: Array in MONTADAS[formula]:
		var elemento := String(atomo[0])
		if not _recortes.has(elemento) \
				and not (RECOLORIDAS.has(elemento) and _recortes.has(RECOLORIDAS[elemento]["de"])):
			return false
	return true


## O desenho de um átomo solto: o da folha, ou o trocado de cor.
static func _imagem_do_atomo(elemento: String) -> Image:
	if _recortes.has(elemento):
		return _imagem().get_region(_recortes[elemento])
	return _imagem_recolorida(RECOLORIDAS[elemento]["de"], RECOLORIDAS[elemento]["cores"])


static func _imagem_recolorida(origem: String, cores: Array) -> Image:
	var imagem := _imagem().get_region(_recortes[origem])
	for y in imagem.get_height():
		for x in imagem.get_width():
			var pixel := imagem.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			var parte := 0
			var menor := INF
			for i in CORES_DO_OXIGENIO.size():
				var c := CORES_DO_OXIGENIO[i]
				var distancia := Vector3(pixel.r - c.r, pixel.g - c.g, pixel.b - c.b).length_squared()
				if distancia < menor:
					menor = distancia
					parte = i
			var nova: Color = cores[parte]
			imagem.set_pixel(x, y, Color(nova.r, nova.g, nova.b, pixel.a))
	return imagem


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
