class_name ArteDaColuna
extends RefCounted

# --- A ARTE DA COLUNA DE DESTILAÇÃO, LIDA ---
#
# "coluna de destilação.png" (a arte da fase do nitrogênio) tem dois desenhos
# lado a lado: a coluna de aço e a mesma coluna em raio X, preta, com as
# bandejas à mostra. Esta classe lê o desenho de raio X e diz onde está cada
# coisa nele, para quem for animar o que acontece lá dentro:
#
#   as BANDEJAS   toda barra clara presa em uma parede só. O vão que sobra do
#                 outro lado é a FENDA por onde o gás sobe, e o dente na ponta
#                 dela é a BORDA que segura o líquido
#   o PISO        a barra de parede a parede mais baixa
#   o MIOLO       por linha da arte, de que coluna a que coluna vai o preto de
#                 dentro: é até onde o gás pode ir para os lados
#   os VÃOS DOS PÉS   embaixo do piso, entre os pés: onde se desenha o calor
#                 entrando
#   a SERPENTINA  o lugar do resfriador, no alto da cúpula
#
# Nada disso é coordenada escrita: redesenhar a coluna, mudar o tamanho ou pôr
# mais bandejas muda o que é lido. A coluna da história
# (scripts/ui/coluna_destilacao.gd) lê a arte do mesmo jeito, dentro dela; aqui
# a leitura é uma peça à parte, que o simulador do Laboratório
# (scripts/ui/coluna_do_simulador.gd) usa.
#
# Tudo o que esta classe devolve está em PIXELS DA ARTE do desenho de raio X
# (a origem é o canto dele). Quem desenha multiplica pela escala.

const CAMINHO := "res://assets/fase nitrogenio/coluna de destilação.png"

static var _lida: ArteDaColuna

var textura: Texture2D
## Só as linhas claras do raio X (paredes e bandejas), para desenhar por cima
## de tudo: gás e moléculas passam por trás delas.
var linhas: Texture2D
var recorte_do_aco := Rect2i()
var recorte_do_raio_x := Rect2i()
## Cada bandeja, do fundo para o topo: {"y0", "y1" (as linhas da barra), "x0",
## "x1", "fenda_x0", "fenda_x1", "borda" (altura do dente), "lado" (-1 = a
## fenda fica à esquerda)}.
var bandejas: Array[Dictionary] = []
var piso: int = 0
## Por linha da arte, a primeira e a última coluna do miolo preto (-1 = não há).
var miolo_esq := PackedInt32Array()
var miolo_dir := PackedInt32Array()
## 1 em cada pixel da arte que é miolo.
var e_miolo := PackedByteArray()
## Em que andar fica cada linha da arte (0 = o fundo).
var andar_da_linha := PackedInt32Array()
var vaos_dos_pes: Array[Vector2i] = []
## x, y, largura e altura da serpentina (sem área se a cúpula for estreita).
var serpentina := Rect2i()


## A arte lida (uma vez só; as outras vezes devolve a mesma).
static func ler() -> ArteDaColuna:
	if _lida == null:
		_lida = ArteDaColuna.new()
		_lida._ler()
	return _lida


func tamanho() -> Vector2i:
	return recorte_do_raio_x.size


## Andares da coluna: o fundo e mais um por bandeja.
func andares() -> int:
	return bandejas.size() + 1


## A linha do chão do andar: o piso, para o fundo; a barra da bandeja, para os
## outros.
func chao_do_andar(andar: int) -> float:
	if andar <= 0 or bandejas.is_empty():
		return float(piso)
	return float(bandejas[mini(andar, bandejas.size()) - 1]["y0"])


## A linha do teto do andar: a bandeja de cima ou, no último, a serpentina (ou
## a cúpula).
func teto_do_andar(andar: int) -> float:
	if andar < bandejas.size():
		return float(bandejas[andar]["y1"]) + 1.0
	if serpentina.has_area():
		return float(serpentina.end.y + 1)
	for y in miolo_esq.size():
		if miolo_esq[y] >= 0:
			return float(y)
	return 0.0


## A altura da tona de um líquido raso na bandeja que é o chão do andar (a
## altura da borda dela). No fundo é o próprio chão.
func tona_do_andar(andar: int) -> float:
	if andar <= 0 or bandejas.is_empty():
		return chao_do_andar(0)
	return chao_do_andar(andar) - float(bandejas[mini(andar, bandejas.size()) - 1]["borda"])


## De que coluna a que coluna vai a poça do andar: de parede a parede no
## fundo; da parede até a borda, nas bandejas.
func poca_do_andar(andar: int) -> Vector2:
	var largura := float(tamanho().x)
	if andar <= 0 or bandejas.is_empty():
		return Vector2(1.0, largura - 1.0)
	var bandeja := bandejas[mini(andar, bandejas.size()) - 1]
	if int(bandeja["lado"]) < 0:
		return Vector2(float(bandeja["x0"]) + 1.0, largura - 1.0)
	return Vector2(1.0, float(bandeja["x1"]))


## O meio da fenda da bandeja (0 = a de baixo), por onde o gás passa do andar
## dela para o de cima.
func meio_da_fenda(bandeja: int) -> float:
	var b := bandejas[bandeja]
	return (float(b["fenda_x0"]) + float(b["fenda_x1"]) + 1.0) * 0.5


## Até onde o gás pode ir para os lados na linha y: as paredes do miolo.
func paredes_em(y: float) -> Vector2:
	var linha := clampi(int(y), 0, miolo_esq.size() - 1)
	if miolo_esq.is_empty() or miolo_esq[linha] < 0:
		return Vector2(1.0, float(tamanho().x) - 1.0)
	return Vector2(float(miolo_esq[linha]), float(miolo_dir[linha]) + 1.0)


## A linha em que se lê a temperatura do andar: o meio do vão dele (no de
## cima, o meio da parte reta, sem contar a cúpula).
func meio_do_andar(andar: int) -> float:
	var chao := chao_do_andar(andar)
	var teto := teto_do_andar(andar)
	if andar >= bandejas.size() and bandejas.size() >= 2:
		var vao := chao_do_andar(andar - 1) - teto_do_andar(andar - 1)
		teto = maxf(teto, chao - vao)
	return (chao + teto) * 0.5


## O trecho da régua de temperatura que é do andar: (de cima, de baixo). Os
## trechos se emendam no meio de cada bandeja.
func trecho_da_regua(andar: int) -> Vector2:
	var de_cima := 0.0
	if andar < bandejas.size():
		de_cima = (float(bandejas[andar]["y0"]) + float(bandejas[andar]["y1"]) + 1.0) * 0.5
	var de_baixo := float(piso + 1)
	if andar > 0 and not bandejas.is_empty():
		var bandeja := bandejas[mini(andar, bandejas.size()) - 1]
		de_baixo = (float(bandeja["y0"]) + float(bandeja["y1"]) + 1.0) * 0.5
	return Vector2(de_cima, de_baixo)


# ─────────────────────────────────────────────────────────────
# LEITURA
# ─────────────────────────────────────────────────────────────

func _ler() -> void:
	textura = load(CAMINHO) as Texture2D
	if textura == null:
		push_warning("ArteDaColuna: não achei a arte em '%s'." % CAMINHO)
		return
	var folha := textura.get_image()
	if folha.is_compressed():
		folha.decompress()
	folha.convert(Image.FORMAT_RGBA8)

	# Os desenhos da folha: trechos de colunas com alguma coisa, separados por
	# colunas vazias. O primeiro é o de aço, o segundo o de raio X.
	var desenhos: Array[Rect2i] = []
	var inicio := -1
	for x in folha.get_width() + 1:
		var tem := false
		if x < folha.get_width():
			for y in folha.get_height():
				if folha.get_pixel(x, y).a > 0.0:
					tem = true
					break
		if tem and inicio < 0:
			inicio = x
		elif not tem and inicio >= 0:
			var caixa := folha.get_region(Rect2i(inicio, 0, x - inicio, folha.get_height())).get_used_rect()
			caixa.position.x += inicio
			desenhos.append(caixa)
			inicio = -1
	if desenhos.size() < 2:
		push_warning("ArteDaColuna: a folha '%s' devia ter dois desenhos lado a lado (aço e raio X); achei %d."
			% [CAMINHO, desenhos.size()])
		if desenhos.is_empty():
			return
		desenhos.append(desenhos[0])
	recorte_do_aco = desenhos[0]
	recorte_do_raio_x = desenhos[1]

	var raio := folha.get_region(recorte_do_raio_x)
	var largura := raio.get_width()
	var altura := raio.get_height()
	var so_as_linhas := Image.create_empty(largura, altura, false, Image.FORMAT_RGBA8)
	miolo_esq.resize(altura)
	miolo_dir.resize(altura)
	e_miolo.resize(largura * altura)
	e_miolo.fill(0)
	for y in altura:
		miolo_esq[y] = -1
		miolo_dir[y] = -1
		for x in largura:
			if _claro(raio, x, y):
				so_as_linhas.set_pixel(x, y, raio.get_pixel(x, y))
			elif _escuro(raio, x, y):
				e_miolo[y * largura + x] = 1
				if miolo_esq[y] < 0:
					miolo_esq[y] = x
				miolo_dir[y] = x
	linhas = ImageTexture.create_from_image(so_as_linhas)

	# As barras: linhas da arte com um traço claro de mais de meia largura.
	var barras: Array[Dictionary] = []
	var aberta := {}
	for y in altura + 1:
		var traco := _maior_traco_claro(raio, y) if y < altura else Vector2i(-1, -1)
		@warning_ignore("integer_division")
		var e_barra := traco.x >= 0 and traco.y - traco.x + 1 >= largura / 2
		if e_barra and not aberta.is_empty() and aberta["x0"] == traco.x and aberta["x1"] == traco.y:
			aberta["y1"] = y
			continue
		if not aberta.is_empty():
			barras.append(aberta)
			aberta = {}
		if e_barra:
			aberta = {"y0": y, "y1": y, "x0": traco.x, "x1": traco.y}

	# De parede a parede é o piso (o mais baixo); presa em uma parede só é
	# bandeja, e a fenda é o vão do outro lado.
	piso = altura - 1
	var achou_piso := false
	for i in range(barras.size() - 1, -1, -1):
		var barra := barras[i]
		if barra["x0"] <= 0 and barra["x1"] >= largura - 1:
			if not achou_piso:
				piso = barra["y0"]
				achou_piso = true
			continue
		if achou_piso and barra["y0"] > piso:
			continue
		if barra["x0"] <= 0:
			barra["lado"] = 1
			barra["fenda_x0"] = int(barra["x1"]) + 1
			barra["fenda_x1"] = largura - 2
			barra["borda"] = _altura_da_borda(raio, barra["x1"], barra["y0"])
		elif barra["x1"] >= largura - 1:
			barra["lado"] = -1
			barra["fenda_x0"] = 1
			barra["fenda_x1"] = int(barra["x0"]) - 1
			barra["borda"] = _altura_da_borda(raio, barra["x0"], barra["y0"])
		else:
			continue
		bandejas.append(barra)
	# As barras foram lidas de baixo para cima: "bandejas" ficou do fundo para
	# o topo.

	andar_da_linha.resize(altura)
	for y in altura:
		var andar := 0
		for bandeja in bandejas:
			if int(bandeja["y0"]) > y:
				andar += 1
		andar_da_linha[y] = andar

	# Os vãos entre os pés, duas linhas abaixo do piso.
	var y_dos_pes := piso + 2
	if y_dos_pes < altura:
		inicio = -1
		for x in largura + 1:
			var vazio := x < largura and raio.get_pixel(x, y_dos_pes).a <= 0.0
			if vazio and inicio < 0:
				inicio = x
			elif not vazio and inicio >= 0:
				if x - inicio >= 6:
					vaos_dos_pes.append(Vector2i(inicio + 1, x - 2))
				inicio = -1

	# A serpentina do resfriador: no alto da cúpula, logo abaixo da primeira
	# linha em que o miolo já tem largura para ela (3 linhas de altura).
	for y in altura - 4:
		@warning_ignore("integer_division")
		if miolo_esq[y] >= 0 and miolo_dir[y] - miolo_esq[y] + 1 >= largura * 2 / 5:
			serpentina = Rect2i(miolo_esq[y] + 2, y + 1, miolo_dir[y] - miolo_esq[y] - 3, 3)
			break


static func _escuro(imagem: Image, x: int, y: int) -> bool:
	var p := imagem.get_pixel(x, y)
	return p.a > 0.5 and p.get_luminance() < 0.2


static func _claro(imagem: Image, x: int, y: int) -> bool:
	var p := imagem.get_pixel(x, y)
	return p.a > 0.5 and p.get_luminance() >= 0.2


## O maior traço claro da linha: (primeira coluna, última), ou (-1, -1).
static func _maior_traco_claro(imagem: Image, y: int) -> Vector2i:
	var melhor := Vector2i(-1, -1)
	var inicio := -1
	for x in imagem.get_width() + 1:
		var claro := x < imagem.get_width() and _claro(imagem, x, y)
		if claro and inicio < 0:
			inicio = x
		elif not claro and inicio >= 0:
			if melhor.x < 0 or x - inicio > melhor.y - melhor.x + 1:
				melhor = Vector2i(inicio, x - 1)
			inicio = -1
	return melhor


## Quantos pixels claros sobem da ponta solta da bandeja: a borda que segura o
## líquido em cima dela.
static func _altura_da_borda(imagem: Image, x: int, y_da_barra: int) -> int:
	var altura := 0
	while y_da_barra - altura - 1 >= 0 and _claro(imagem, x, y_da_barra - altura - 1):
		altura += 1
	return altura
