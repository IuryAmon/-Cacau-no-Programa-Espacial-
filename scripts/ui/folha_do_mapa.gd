class_name FolhaDoMapa
extends Control

# --- O MAPA (a aba MAPA do caderno): O DESENHO E O QUE ELE LÊ DO JOGO ---
#
# A planta do Centro de Lançamento numa folha de papel quadriculado, do mesmo
# papel e da mesma tinta do caderno. Cada sala da PlantaDoMapa (scripts/
# planta_do_mapa.gd, onde fica O QUE está no mapa) vira um bloco na cor do
# esquema das fases, com a moldura de tinta das fichas do HUD, e as passagens
# viram corredores entre elas. Do lado, o CARIMBO — o quadro dos desenhos
# técnicos — diz onde a Cacau está, o objetivo da vez, os elementos e a
# legenda.
#
#   sala explorada       cheia, na cor dela, com a moldura de tinta
#   sala a explorar      tracejada, só com uma aguada da cor: já está na
#                        planta para guiar, mas a Cacau nunca pisou lá
#   onde a Cacau está    a sala ganha um aro na tinta do título, e o rosto
#                        dela (o do HUD) fica no ponto da sala que corresponde
#                        a onde ela está na cena, com um sinal se espalhando
#   o objetivo           o losango na cor da trilha (a do cabeçalho da lista de
#                        objetivos), no lugar em que ele se cumpre
#   passagem trancada    o cadeado, até a Cacau ter a habilidade que a abre
#   elemento             a fichinha em cima da sala: vazia até ela pegar o
#                        elemento, cheia na cor dele depois
#
# Nada aqui guarda estado do jogo: ler_o_jogo() pergunta tudo (à cena, ao
# Objetivos e ao Progresso) e guarda em "estado"; o desenho só lê o "estado".
# O caderno chama ler_o_jogo() ao abrir e ao trocar para a aba do mapa — com
# ele aberto o jogo está pausado, e nada muda.
#
# Tudo aqui está em px da folha (o nó tem o TAMANHO dela). Quem põe a folha na
# tela, amplia e anima é o autoload Caderno.

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")
## O rosto da Cacau é o do HUD: a cabeça do primeiro quadro e, de sombra, a
## silhueta do quadro do clarão (ver HudVital).
const FOLHA_ROSTO := preload("res://assets/Cacau Assets/cara do hud.png")
const RECORTE_ROSTO := HudVital.ROSTO_INTEIRA
const RECORTE_SILHUETA := HudVital.ROSTO_CLARAO

# --- A folha ---
## A folha inteira: o papel (PAPEL_DA_FOLHA) e a sombra dura embaixo dele.
const TAMANHO := Vector2(1480, 704)
const PAPEL_DA_FOLHA := Rect2(0, 0, 1480, 700)
## O papel quadriculado, com a planta no meio, e o carimbo ao lado dele.
const QUADRICULADO := Rect2(24, 24, 1044, 652)
const CARIMBO := Rect2(1088, 24, 368, 652)

# --- As cores: o papel e as tintas do caderno ---
const PAPEL := EstiloHUD.PAPEL
const TINTA := EstiloHUD.TINTA
const TINTA_TITULO := FaceCaderno.TINTA_TITULO
const TINTA_FRACA := FaceCaderno.TINTA_FRACA
## As linhas do quadriculado: a de cada célula e as de cada terço dela.
const LINHA_CELULA := Color(0.24, 0.165, 0.133, 0.15)
const LINHA_TERCO := Color(0.24, 0.165, 0.133, 0.06)
## A sombra das peças no papel: a tinta aguada, caindo para baixo.
const SOMBRA := Color(0.24, 0.165, 0.133, 0.22)
## O chão dos corredores entre as salas: o papel, um tom abaixo.
const CHAO_DO_CORREDOR := Color("d8c3a0")
## Quanto da cor da sala vai na aguada de uma sala a explorar.
const AGUADA := 0.24
const COR_CADEADO := Color8(0xf6, 0xc9, 0x52)

# --- As salas ---
const MOLDURA_SALA := 3.0
const QUEDA_SALA := 3.0
## O tracejado das salas a explorar: o traço, o vão e a grossura.
const TRACO := 8.0
const VAO := 6.0
const GROSSURA_TRACEJADO := 2.0
## O aro da sala em que a Cacau está: quanto ele fica para fora e a grossura.
const RECUO_ANEL := 5.0
const GROSSURA_ANEL := 3.0
## A largura dos corredores (e da porta que eles abrem na parede das salas).
const LARGURA_PASSAGEM := 16.0

# --- Os nomes ---
const TAM_NOME := 22
const TAM_PEQUENO := 11
## Folga do nome até as paredes da sala (e até a sala, no nome de fora).
const FOLGA_NOME := 10.0
## Largura máxima do nome escrito ao lado da sala ("nome_fora" à direita ou à
## esquerda, ver PlantaDoMapa).
const LARGURA_NOME_DE_FORA := 108.0
## Nas salas por onde a Cacau anda, o nome fica no alto, com o meio a esta
## altura (ou a esta fração da sala, na sala baixa): embaixo dele é o trilho.
const ALTURA_DO_NOME := 28.0
const FRACAO_DO_NOME := 0.28
## O título da planta, no canto de cima do quadriculado.
const TITULO := "CENTRO DE LANÇAMENTO"

# --- As marcas ---
## A plaquinha de papel em volta do rosto da Cacau.
const FOLGA_ROSTO := Vector2(4, 3)
## O sinal que se espalha dela: de quanto em quanto tempo e de que raio a que raio.
const PERIODO_SINAL := 1.6
const RAIO_SINAL := Vector2(16, 52)
## O losango do objetivo: meia diagonal, quanto ele balança e quantas vezes por
## segundo.
const LOSANGO := 9.0
const BALANCO := 2.0
const BALANCOS_POR_SEGUNDO := 1.1
## Objetivo a menos disto da Cacau vai para o lado da plaquinha dela.
const PERTO_DA_CACAU := 30.0
## As fichinhas dos elementos, em cima da sala, encostadas no canto direito.
const LADO_FICHINHA := 24.0
const ENTRE_FICHINHAS := 4.0
const RECUO_FICHINHAS := 10.0
## O cadeado, um caractere por pixel ("." = vazio).
const CADEADO := [
	"..KKKK..",
	".K....K.",
	".K....K.",
	"KKKKKKKK",
	"KYYYYYYK",
	"KYYKKYYK",
	"KYYKKYYK",
	"KYYYYYYK",
	"KKKKKKKK",
]
const PIXEL_CADEADO := 2.0

# --- O carimbo ---
const MARGEM_CARIMBO := 16.0
const TAM_CABECALHO := 11
const ESPACO_CABECALHO := 1.6
const ENTRE_SECOES := 22.0
## O quadrinho com o rosto, ao lado do nome da sala em que ela está.
const CHIP := Vector2(60, 40)
const LADO_ELEMENTO := 40.0
## De uma linha da legenda à outra, e a altura dos desenhos dela (o rosto é o
## mais alto).
const LINHA_DA_LEGENDA := 30.0
const DESENHO_DA_LEGENDA := 22.0
## [o desenho, o nome]; duas colunas, na ordem.
const LEGENDA := [["sala", "EXPLORADA"], ["tracejado", "A EXPLORAR"], ["rosto", "VOCÊ"],
	["losango", "OBJETIVO"], ["cadeado", "TRANCADA"], ["fichinha", "ELEMENTO"]]

## O que o mapa mostra (ler_o_jogo e montar_estado preenchem):
##   cena         o caminho da cena em que a Cacau está
##   area         o id da sala dela ("" = fora da planta)
##   nome, lugar  o que o carimbo escreve em VOCÊ ESTÁ EM
##   ponto        onde ela está na planta, em células (INF = sem marcador)
##   exploradas   id da sala -> true, para cada sala que ela já pisou
##   objetivos    os objetivos da vez (ver Objetivos.atuais)
##   alvos        [{"ponto" (células), "cor"}]: os losangos dos objetivos
##   onde         os nomes dos lugares dos objetivos
##   habilidades  nome -> true, as que ela já tem (para os cadeados)
##   elementos    letra -> 0 (falta), 1 (com ela) ou 2 (no painel), na ordem
##                do CHONPS
var estado: Dictionary = {}:
	set(valor):
		estado = valor
		_montar()
		queue_redraw()

## Os textos dos nomes das salas e o carimbo, já no lugar (ver _montar).
var _rotulos: Array = []
var _carimbo: Array = []
var _fim_do_carimbo: float = 0.0


func _ready() -> void:
	size = TAMANHO
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _rotulos.is_empty():
		_montar()


func _process(_delta: float) -> void:
	# O sinal, o losango e o elemento na mão se mexem.
	if is_visible_in_tree():
		queue_redraw()


## Clicar na folha não faz nada (nem fecha o caderno: fecha clicar fora dela).
func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed:
		accept_event()


# ─────────────────────────────────────────────────────────────
# O QUE ELE LÊ DO JOGO
# ─────────────────────────────────────────────────────────────

## Lê do jogo o que o mapa mostra: a cena e a posição da Cacau, os objetivos,
## as habilidades e os elementos.
func ler_o_jogo() -> void:
	var arvore := get_tree()
	if arvore == null:
		return
	var cena := arvore.current_scene
	var caminho := cena.scene_file_path if cena != null else ""
	var cacau := arvore.get_first_node_in_group("player") as Node2D
	var posicao := cacau.global_position if cacau != null else Vector2.INF
	estado = montar_estado(caminho, posicao, limites_da_cena(caminho, cena))


## O "estado" do mapa com a Cacau na cena "cena", em "posicao" (px do mundo),
## numa cena que vai de "limites" (ver PlantaDoMapa.ponto_no_mapa). O resto
## vem do Progresso e, sem "objetivos" (a lista do Objetivos.atuais), do
## Objetivos.
func montar_estado(cena: String, posicao: Vector2 = Vector2.INF,
		limites: Rect2 = Rect2(), objetivos: Variant = null) -> Dictionary:
	if objetivos == null:
		objetivos = Objetivos.atuais()
	# Na cena com trechos (o subsolo), a sala é a do trecho em que ela está.
	var trecho := PlantaDoMapa.trecho(cena, posicao.x if posicao.is_finite() else INF)
	var area := String(trecho.get("area", ""))
	var sala := PlantaDoMapa.area(area)
	var nome := "FORA DO MAPA"
	var lugar := String(trecho.get("lugar", ""))
	if not sala.is_empty():
		nome = String(sala["nome"])
		if lugar.is_empty():
			lugar = String(sala.get("detalhe", ""))
	elif not lugar.is_empty():
		nome = lugar.to_upper()
		lugar = "fora do mapa"

	var exploradas := {}
	if not area.is_empty():
		exploradas[area] = true
	for caminho: String in PlantaDoMapa.CENAS:
		var id := PlantaDoMapa.area_da_cena(caminho)
		if not id.is_empty() and Objetivos.visitou(caminho):
			exploradas[id] = true
	for dados in PlantaDoMapa.AREAS:
		if Objetivos.visitou_area(dados["id"]):
			exploradas[dados["id"]] = true

	var alvos: Array[Dictionary] = []
	var onde := PackedStringArray()
	var lugares_dos_objetivos := {}
	for objetivo in objetivos:
		var alvo := PlantaDoMapa.lugar_do_objetivo(String(objetivo["id"]))
		var chave := "%s|%s" % [alvo.get("cena"), alvo.get("area")]
		if alvo.is_empty() or lugares_dos_objetivos.has(chave):
			continue
		lugares_dos_objetivos[chave] = true
		var nome_do_alvo := nome_do_lugar(alvo["cena"], alvo["area"])
		if not nome_do_alvo.is_empty() and not nome_do_alvo in onde:
			onde.append(nome_do_alvo)
		var ponto := PlantaDoMapa.meio_do_trilho(alvo["cena"], alvo["area"])
		if ponto.is_finite():
			alvos.append({"ponto": ponto, "cor": objetivo["cor"]})

	var habilidades := {}
	for habilidade: String in Progresso.HABILIDADES:
		if Progresso.tem_habilidade(habilidade):
			habilidades[habilidade] = true
	var elementos := {}
	for letra: String in Progresso.CELULAS:
		elementos[letra] = 2 if Progresso.tem_celula(letra) \
			else (1 if Progresso.carrega_celula(letra) else 0)

	return {"cena": cena, "area": area, "nome": nome, "lugar": lugar,
		"ponto": PlantaDoMapa.ponto_no_mapa(cena, posicao, limites),
		"exploradas": exploradas, "objetivos": objetivos, "alvos": alvos, "onde": onde,
		"habilidades": habilidades, "elementos": elementos}


## Como o mapa chama um lugar: o nome da sala (a "area" ou, sem ela, a da
## cena) ou, fora da planta, o "lugar" da cena (em maiúsculas). "" se a cena
## não está nas CENAS.
static func nome_do_lugar(cena: String, area: String = "") -> String:
	var sala := PlantaDoMapa.area(area if not area.is_empty() else PlantaDoMapa.area_da_cena(cena))
	if not sala.is_empty():
		return String(sala["nome"])
	return String(PlantaDoMapa.CENAS.get(cena, {}).get("lugar", "")).to_upper()


## Até onde a Cacau anda na cena, em px do mundo: o "limites" da cena na
## PlantaDoMapa ou, sem ele, o LimitesDaCamera da fase somado aos andares
## (AndarCamera) e às zonas de câmera (ZonaCamera) dela. Rect2() se não achar
## nada (o marcador fica no meio do trilho).
static func limites_da_cena(caminho: String, cena: Node) -> Rect2:
	var dados: Dictionary = PlantaDoMapa.CENAS.get(caminho, {})
	if dados.has("limites"):
		return dados["limites"]
	if cena == null or not cena.is_inside_tree():
		return Rect2()
	var caixas: Array[Rect2] = []
	var limites := cena.get_node_or_null(^"LimitesDaCamera") as Control
	if limites != null:
		caixas.append(limites.get_global_rect())
	for no in cena.get_tree().get_nodes_in_group(AndarCamera.GRUPO):
		if no is Control and cena.is_ancestor_of(no):
			caixas.append((no as Control).get_global_rect())
	for no in cena.get_tree().get_nodes_in_group(ZonaCamera.GRUPO):
		if no is Polygon2D and cena.is_ancestor_of(no):
			var poligono := no as Polygon2D
			var pontos := PackedVector2Array()
			for p in poligono.polygon:
				pontos.append(poligono.global_transform * p)
			if pontos.size() >= 3:
				var caixa := Rect2(pontos[0], Vector2.ZERO)
				for p in pontos:
					caixa = caixa.expand(p)
				caixas.append(caixa)
	if caixas.is_empty():
		return Rect2()
	var total := caixas[0]
	for caixa in caixas:
		total = total.merge(caixa)
	return total


# ─────────────────────────────────────────────────────────────
# ONDE CADA COISA FICA NA FOLHA
# ─────────────────────────────────────────────────────────────

## O lado de uma célula da planta, em px: o maior inteiro em que a planta, com
## uma célula de folga em volta, cabe no quadriculado.
static func celula() -> float:
	var celulas := Vector2(PlantaDoMapa.tamanho() + Vector2i(2, 2))
	return floorf(minf(QUADRICULADO.size.x / celulas.x, QUADRICULADO.size.y / celulas.y))


## Onde fica o canto da célula (0, 0): a planta vai no meio do quadriculado.
static func origem() -> Vector2:
	var planta := Vector2(PlantaDoMapa.tamanho()) * celula()
	return (QUADRICULADO.position + (QUADRICULADO.size - planta) * 0.5).round()


## Um ponto da planta (em células) na folha (em px).
static func no_papel(celulas: Vector2) -> Vector2:
	return origem() + celulas * celula()


## A sala na folha, em px.
static func caixa_da_sala(id: String) -> Rect2:
	var sala := PlantaDoMapa.area(id)
	if sala.is_empty():
		return Rect2()
	var caixa: Rect2i = sala["caixa"]
	return Rect2(no_papel(Vector2(caixa.position)), Vector2(caixa.size) * celula())


## Onde fica um texto de rotulos() ou carimbo(), do ascendente ao descendente.
static func caixa_do_texto(item: Dictionary) -> Rect2:
	var tam: int = item["tam"]
	var sobe := FONTE.get_ascent(tam)
	return Rect2(item["pos"] - Vector2(0, sobe),
		Vector2(_largura(item["texto"], tam, item.get("espaco", 0.0)), sobe + FONTE.get_descent(tam)))


## Os nomes das salas e o título, já no lugar ({"texto", "pos" (na linha de
## base), "tam", "cor"}, e "sala" = o id da sala do nome).
func rotulos() -> Array:
	return _rotulos


## O que vai no carimbo, já no lugar: textos como os de rotulos() e os
## desenhos (ver _desenhar_item).
func carimbo() -> Array:
	return _carimbo


# ─────────────────────────────────────────────────────────────
# MONTAGEM (os textos no lugar, uma vez por "estado")
# ─────────────────────────────────────────────────────────────

func _montar() -> void:
	_rotulos = _montar_rotulos()
	# O objetivo vai na letra do caderno; se não couber (a legenda sai do
	# quadro), na pequena.
	_carimbo = _montar_carimbo(TAM_NOME)
	if _fim_do_carimbo > CARIMBO.end.y - MARGEM_CARIMBO + 0.5:
		_carimbo = _montar_carimbo(TAM_PEQUENO)


func _montar_rotulos() -> Array:
	var itens: Array = []
	var x_titulo := origem().x
	var base_titulo := QUADRICULADO.position.y + 42.0
	itens.append({"texto": TITULO, "pos": Vector2(x_titulo, base_titulo), "tam": TAM_NOME,
		"cor": TINTA_TITULO, "sala": ""})
	itens.append({"faixa": Rect2(x_titulo, base_titulo + 8.0, _largura(TITULO, TAM_NOME), 2.0),
		"cor": TINTA_TITULO})

	for sala in PlantaDoMapa.AREAS:
		var id := String(sala["id"])
		var caixa := caixa_da_sala(id)
		var cor := TINTA if _explorada(id) else TINTA_FRACA
		var fora := String(sala.get("nome_fora", ""))
		var de_lado := fora == "direita" or fora == "esquerda"
		var largura := LARGURA_NOME_DE_FORA if de_lado else caixa.size.x - FOLGA_NOME * 2.0
		# O nome na letra grande se couber (em duas linhas só nas salas altas);
		# senão, na pequena.
		var nome := String(sala["nome"])
		var tam := TAM_NOME
		var linhas := _quebrar(nome, tam, largura)
		var cabe := linhas.size() <= (2 if caixa.size.y >= celula() * 3.0 or de_lado else 1)
		for linha in linhas:
			cabe = cabe and _largura(linha, tam) <= largura
		if not cabe:
			tam = TAM_PEQUENO
			linhas = _quebrar(nome, tam, largura)
		var pilha: Array = []
		for linha in linhas:
			pilha.append([linha, tam, cor])
		var detalhe := String(sala.get("detalhe", ""))
		if not detalhe.is_empty():
			pilha.append([detalhe, TAM_PEQUENO, cor])
		var altura := _altura_da_pilha(pilha)

		var x := caixa.get_center().x
		var topo := caixa.get_center().y - altura * 0.5
		var alinhar := "meio"
		match fora:
			"cima":
				topo = caixa.position.y - FOLGA_NOME - altura
			"direita":
				x = caixa.end.x + FOLGA_NOME
				alinhar = "esquerda"
			"esquerda":
				x = caixa.position.x - FOLGA_NOME
				alinhar = "direita"
			_:
				if _tem_cena(id):
					topo = caixa.position.y + minf(ALTURA_DO_NOME, caixa.size.y * FRACAO_DO_NOME) \
						- altura * 0.5
		var inicio := itens.size()
		_empilhar(itens, pilha, x, topo, alinhar)
		for i in range(inicio, itens.size()):
			itens[i]["sala"] = id
	return itens


## O carimbo inteiro, com o texto dos objetivos no tamanho "tam". Guarda em
## _fim_do_carimbo até onde ele desceu.
func _montar_carimbo(tam: int) -> Array:
	var itens: Array = []
	var x := CARIMBO.position.x + MARGEM_CARIMBO
	var largura := CARIMBO.size.x - MARGEM_CARIMBO * 2.0
	var y := CARIMBO.position.y + MARGEM_CARIMBO

	# VOCÊ ESTÁ EM: o rosto dela na cor da sala, o nome da sala e o lugar.
	y = _cabecalho(itens, "VOCÊ ESTÁ EM", x, y, largura)
	var sala := PlantaDoMapa.area(String(estado.get("area", "")))
	var chip := Rect2(x, y, CHIP.x, CHIP.y)
	itens.append({"ficha": chip, "papel": sala.get("cor", PAPEL), "moldura": 2.0})
	itens.append({"rosto": chip.get_center()})
	var x_nome := chip.end.x + 12.0
	var largura_nome := x + largura - x_nome
	var nome := String(estado.get("nome", "FORA DO MAPA"))
	var tam_nome := TAM_NOME
	var linhas := _quebrar(nome, tam_nome, largura_nome)
	if linhas.size() > 2:
		tam_nome = TAM_PEQUENO
		linhas = _quebrar(nome, tam_nome, largura_nome)
	var pilha: Array = []
	for linha in linhas:
		pilha.append([linha, tam_nome, TINTA])
	var lugar := String(estado.get("lugar", ""))
	if not lugar.is_empty():
		for linha in _quebrar(lugar, TAM_PEQUENO, largura_nome):
			pilha.append([linha, TAM_PEQUENO, TINTA_FRACA])
	# Na altura do meio do quadrinho; se for mais alto que ele, desce a partir
	# do alto dele.
	var altura := _altura_da_pilha(pilha)
	var topo := maxf(chip.position.y, chip.get_center().y - altura * 0.5)
	var fim := _empilhar(itens, pilha, x_nome, topo, "esquerda")
	y = maxf(chip.end.y, fim) + ENTRE_SECOES

	# OBJETIVO: a trilha (o losango na cor dela e o título, como na lista do
	# canto), cada objetivo com a caixinha e, no fim, onde fica no mapa.
	y = _cabecalho(itens, "OBJETIVO", x, y, largura)
	var objetivos: Array = estado.get("objetivos", [])
	if objetivos.is_empty():
		var nada: Array = []
		for linha in _quebrar("Nenhum objetivo agora. Explore o mapa!", tam, largura):
			nada.append([linha, tam, TINTA_FRACA])
		y = _empilhar(itens, nada, x, y, "esquerda") + ENTRE_SECOES
	else:
		var trilha: Dictionary = objetivos[0]
		var letra := _altura_da_letra(TAM_CABECALHO)
		itens.append({"losango": Vector2(x + 7.0, y + letra * 0.5), "raio": 7.0,
			"cor": trilha["cor"]})
		itens.append({"texto": String(trilha["titulo"]), "pos": Vector2(x + 22.0, y + letra),
			"tam": TAM_CABECALHO, "cor": TINTA, "espaco": ESPACO_CABECALHO})
		y += letra + 14.0
		for objetivo in objetivos:
			var recuo := 18.0 if not String(objetivo.get("pai", "")).is_empty() else 0.0
			var lado := 14.0 if tam == TAM_NOME else 10.0
			var letra_do_texto := _altura_da_letra(tam)
			itens.append({"caixinha": Rect2(x + recuo, y + (letra_do_texto - lado) * 0.5,
				lado, lado)})
			var texto: Array = []
			var x_texto := x + recuo + lado + 10.0
			for linha in _quebrar(String(objetivo["texto"]), tam, x + largura - x_texto):
				texto.append([linha, tam, TINTA])
			y = _empilhar(itens, texto, x_texto, y, "esquerda") + roundf(_vao_antes(tam) * 1.6)
		var onde: PackedStringArray = estado.get("onde", PackedStringArray())
		if not onde.is_empty():
			var no_mapa: Array = []
			for linha in _quebrar("→ " + " · ".join(onde), TAM_CABECALHO, largura):
				no_mapa.append([linha, TAM_CABECALHO, TINTA_TITULO])
			y = _empilhar(itens, no_mapa, x, y + 2.0, "esquerda")
		y += ENTRE_SECOES

	# ELEMENTOS: as seis fichas do CHONPS e quantas já acenderam no painel.
	var elementos: Dictionary = estado.get("elementos", {})
	var no_painel := 0
	for letra: String in elementos:
		if int(elementos[letra]) >= 2:
			no_painel += 1
	var total := elementos.size()
	y = _cabecalho(itens, "ELEMENTOS", x, y, largura,
		"%d/%d NO PAINEL" % [no_painel, total] if total > 0 else "")
	if total > 0:
		var vao := floorf((largura - LADO_ELEMENTO * total) / maxf(total - 1, 1))
		var i := 0
		for letra: String in elementos:
			itens.append({"elemento": Rect2(x + i * (LADO_ELEMENTO + vao), y, LADO_ELEMENTO,
				LADO_ELEMENTO), "letra": letra, "nivel": int(elementos[letra]), "tam": TAM_NOME})
			i += 1
		y += LADO_ELEMENTO + ENTRE_SECOES

	# EXPLORAÇÃO: quantas salas da planta ela já pisou, na régua do cabeçalho.
	var pisadas: int = (estado.get("exploradas", {}) as Dictionary).size()
	var salas := PlantaDoMapa.AREAS.size()
	_cabecalho(itens, "EXPLORAÇÃO", x, y, largura, "%d/%d SALAS" % [pisadas, salas],
		float(pisadas) / salas)
	y += _altura_da_letra(TAM_CABECALHO) + ENTRE_SECOES

	# LEGENDA: no pé do carimbo (o que sobra de espaço fica em cima dela), em
	# duas colunas, um desenho e o nome dele.
	var linhas_da_legenda := ceili(LEGENDA.size() / 2.0)
	var altura_da_legenda := _altura_da_letra(TAM_CABECALHO) + 12.0 \
		+ (linhas_da_legenda - 1) * LINHA_DA_LEGENDA + DESENHO_DA_LEGENDA
	y = maxf(y, CARIMBO.end.y - MARGEM_CARIMBO - altura_da_legenda)
	y = _cabecalho(itens, "LEGENDA", x, y, largura)
	var coluna := floorf(largura * 0.5)
	var cor_do_losango: Color = objetivos[0]["cor"] if not objetivos.is_empty() else TINTA_TITULO
	for i in LEGENDA.size():
		var canto := Vector2(x + (i % 2) * coluna, y + floorf(i / 2.0) * LINHA_DA_LEGENDA)
		var meio := canto + Vector2(22.0, 11.0)
		match String(LEGENDA[i][0]):
			"sala":
				itens.append({"ficha": Rect2(canto + Vector2(6, 2), Vector2(32, 18)),
					"papel": PlantaDoMapa.CINZA, "moldura": 2.0})
			"tracejado":
				itens.append({"tracejado": Rect2(canto + Vector2(6, 2), Vector2(32, 18)),
					"cor": TINTA_FRACA, "fundo": PAPEL.lerp(PlantaDoMapa.CINZA, AGUADA)})
			"rosto":
				itens.append({"rosto": meio, "sem_placa": true})
			"losango":
				itens.append({"losango": meio, "raio": 8.0, "cor": cor_do_losango})
			"cadeado":
				itens.append({"cadeado": meio})
			"fichinha":
				itens.append({"elemento": Rect2(meio - Vector2(10, 10), Vector2(20, 20)), "letra": "C",
					"nivel": 0, "tam": TAM_PEQUENO})
		itens.append({"texto": String(LEGENDA[i][1]),
			"pos": Vector2(canto.x + 52.0, meio.y + _altura_da_letra(TAM_PEQUENO) * 0.5),
			"tam": TAM_PEQUENO, "cor": TINTA, "espaco": 1.0})
	_fim_do_carimbo = y + (linhas_da_legenda - 1) * LINHA_DA_LEGENDA + DESENHO_DA_LEGENDA
	return itens


## O nome de uma seção do carimbo, em letra pequena espaçada, e um fio até o
## fim da linha (com "direita" escrito na ponta, se houver). Com "medidor" (0 a
## 1), o fio vira uma régua cheia até ali. Devolve onde a seção começa.
func _cabecalho(itens: Array, texto: String, x: float, y: float, largura: float,
		direita: String = "", medidor: float = -1.0) -> float:
	var letra := _altura_da_letra(TAM_CABECALHO)
	itens.append({"texto": texto, "pos": Vector2(x, y + letra), "tam": TAM_CABECALHO,
		"cor": TINTA_FRACA, "espaco": ESPACO_CABECALHO})
	var fim := x + largura
	if not direita.is_empty():
		var w := _largura(direita, TAM_CABECALHO, 1.0)
		fim -= w + 8.0
		itens.append({"texto": direita, "pos": Vector2(x + largura - w, y + letra),
			"tam": TAM_CABECALHO, "cor": TINTA_FRACA, "espaco": 1.0})
	var inicio := x + _largura(texto, TAM_CABECALHO, ESPACO_CABECALHO) + 8.0
	if fim > inicio and medidor < 0.0:
		itens.append({"faixa": Rect2(inicio, roundf(y + letra * 0.5 - 1.0), fim - inicio, 2.0),
			"cor": EstiloHUD.com_alfa(TINTA_FRACA, 0.45)})
	elif fim > inicio:
		var regua := Rect2(inicio, roundf(y + letra * 0.5 - 3.0), fim - inicio, 6.0)
		itens.append({"faixa": regua, "cor": EstiloHUD.com_alfa(TINTA_FRACA, 0.3)})
		itens.append({"faixa": Rect2(regua.position,
			Vector2(roundf(regua.size.x * clampf(medidor, 0.0, 1.0)), regua.size.y)), "cor": TINTA_TITULO})
	return y + letra + 12.0


## Põe as linhas ([texto, tam, cor]) uma embaixo da outra a partir de "topo"
## (o alto da letra da primeira), alinhadas a "x" pelo meio, pela esquerda ou
## pela direita. Devolve a linha de base da última.
func _empilhar(itens: Array, linhas: Array, x: float, topo: float, alinhar: String) -> float:
	var base := topo
	for i in linhas.size():
		var texto := String(linhas[i][0])
		var tam: int = linhas[i][1]
		if i > 0:
			base += _vao_antes(tam)
		base += _altura_da_letra(tam)
		var largura := _largura(texto, tam)
		var x_texto := x
		match alinhar:
			"meio":
				x_texto = x - largura * 0.5
			"direita":
				x_texto = x - largura
		itens.append({"texto": texto, "pos": Vector2(x_texto, base).round(), "tam": tam,
			"cor": linhas[i][2]})
	return base


## Do alto da primeira letra ao pé da última.
func _altura_da_pilha(linhas: Array) -> float:
	var altura := 0.0
	for i in linhas.size():
		var tam: int = linhas[i][1]
		altura += _altura_da_letra(tam) + (_vao_antes(tam) if i > 0 else 0.0)
	return altura


## A altura de uma letra maiúscula (sem acento) no tamanho: 7 px na 11, 14 na 22.
static func _altura_da_letra(tam: int) -> float:
	return roundf(FONTE.get_ascent(tam) - FONTE.get_descent(tam))


## Do pé de uma linha ao alto da letra da linha seguinte, se ela for deste
## tamanho (26 px de linha de base a linha de base, na 22).
static func _vao_antes(tam: int) -> float:
	return roundf(tam * 0.45) + 2.0


# ─────────────────────────────────────────────────────────────
# DESENHO
# ─────────────────────────────────────────────────────────────

func _draw() -> void:
	var agora := Time.get_ticks_msec() * 0.001
	EstiloHUD.ficha(self, PAPEL_DA_FOLHA)
	_desenhar_quadriculado()
	for sala in PlantaDoMapa.AREAS:
		_desenhar_sala(sala)
	for passagem in PlantaDoMapa.PASSAGENS:
		_desenhar_passagem(passagem)
	var atual := String(estado.get("area", ""))
	if not atual.is_empty():
		EstiloHUD.aro(self, caixa_da_sala(atual).grow(RECUO_ANEL), TINTA_TITULO, GROSSURA_ANEL)
	for item in _rotulos:
		_desenhar_item(item, agora)
	for sala in PlantaDoMapa.AREAS:
		_desenhar_fichinhas(sala)
	for passagem in PlantaDoMapa.PASSAGENS:
		_desenhar_cadeado(passagem)
	# O losango por cima da Cacau: o que fica ao lado dela encosta na plaquinha.
	_desenhar_cacau(agora)
	_desenhar_alvos(agora)
	EstiloHUD.aro(self, CARIMBO, TINTA_FRACA, 2.0, 0.0)
	for item in _carimbo:
		_desenhar_item(item, agora)


## Papel quadriculado: uma linha a cada terço de célula e, mais forte, uma a
## cada célula, todas alinhadas com as paredes das salas.
func _desenhar_quadriculado() -> void:
	var area := QUADRICULADO
	var o := origem()
	var c := celula()
	for passo: float in [c / 3.0, c]:
		var cor := LINHA_CELULA if passo == c else LINHA_TERCO
		var x := o.x + ceilf((area.position.x - o.x) / passo) * passo
		while x < area.end.x:
			draw_rect(Rect2(roundf(x), area.position.y, 1.0, area.size.y), cor)
			x += passo
		var y := o.y + ceilf((area.position.y - o.y) / passo) * passo
		while y < area.end.y:
			draw_rect(Rect2(area.position.x, roundf(y), area.size.x, 1.0), cor)
			y += passo
	EstiloHUD.aro(self, area, TINTA_FRACA, 2.0, 0.0)


func _desenhar_sala(sala: Dictionary) -> void:
	var id := String(sala["id"])
	var caixa := caixa_da_sala(id)
	if _explorada(id):
		EstiloHUD.bloco(self, Rect2(caixa.position + Vector2(0, QUEDA_SALA), caixa.size), SOMBRA)
		EstiloHUD.ficha(self, caixa, 1.0, sala["cor"], TINTA, MOLDURA_SALA, 0.0)
	else:
		draw_rect(caixa, _fundo(id))
		_tracejar(caixa, TINTA_FRACA)


## O corredor de uma passagem: o chão entre as duas paredes e, em cada sala, a
## porta (o chão cobre a moldura dela ali). Entre salas encostadas fica só a
## porta na parede. Uma passagem com sala a explorar fica tracejada.
func _desenhar_passagem(passagem: Dictionary) -> void:
	var traco := PlantaDoMapa.traco(passagem)
	if traco.is_empty():
		return
	var salas := _em_ordem(passagem, traco["deitado"])
	var de := no_papel(traco["de"])
	var ate := no_papel(traco["ate"])
	var meia := LARGURA_PASSAGEM * 0.5
	var m := MOLDURA_SALA
	var conhecida := _explorada(salas[0]) and _explorada(salas[1])
	var chao := CHAO_DO_CORREDOR if conhecida else PAPEL
	if traco["deitado"]:
		draw_rect(Rect2(de.x - m, de.y - meia, m, LARGURA_PASSAGEM), _fundo(salas[0]))
		draw_rect(Rect2(ate.x, ate.y - meia, m, LARGURA_PASSAGEM), _fundo(salas[1]))
		var vao := Rect2(de.x, de.y - meia, ate.x - de.x, LARGURA_PASSAGEM)
		if vao.size.x > 0.0:
			draw_rect(vao, chao)
			_parede(Rect2(vao.position.x, vao.position.y - m, vao.size.x, m), conhecida)
			_parede(Rect2(vao.position.x, vao.end.y, vao.size.x, m), conhecida)
	else:
		# Na parede de baixo da sala de cima a porta cobre também a dobra.
		draw_rect(Rect2(de.x - meia, de.y - m * 2.0, LARGURA_PASSAGEM, m * 2.0), _fundo(salas[0]))
		draw_rect(Rect2(ate.x - meia, ate.y, LARGURA_PASSAGEM, m), _fundo(salas[1]))
		var vao := Rect2(de.x - meia, de.y, LARGURA_PASSAGEM, ate.y - de.y)
		if vao.size.y > 0.0:
			draw_rect(vao, chao)
			_parede(Rect2(vao.position.x - m, vao.position.y, m, vao.size.y), conhecida)
			_parede(Rect2(vao.end.x, vao.position.y, m, vao.size.y), conhecida)


func _parede(r: Rect2, inteira: bool) -> void:
	if inteira:
		draw_rect(r, TINTA)
	elif r.size.x > r.size.y:
		_tracejar_linha(Rect2(r.position.x, r.position.y + (r.size.y - GROSSURA_TRACEJADO) * 0.5,
			r.size.x, GROSSURA_TRACEJADO), TINTA_FRACA)
	else:
		_tracejar_linha(Rect2(r.position.x + (r.size.x - GROSSURA_TRACEJADO) * 0.5, r.position.y,
			GROSSURA_TRACEJADO, r.size.y), TINTA_FRACA)


## As duas salas da passagem: a da esquerda (ou a de cima) primeiro.
func _em_ordem(passagem: Dictionary, deitado: bool) -> PackedStringArray:
	var a := String(passagem["de"])
	var b := String(passagem["para"])
	var ca := caixa_da_sala(a)
	var cb := caixa_da_sala(b)
	var a_primeiro := ca.position.x < cb.position.x if deitado else ca.position.y < cb.position.y
	return PackedStringArray([a, b] if a_primeiro else [b, a])


## As fichinhas do CHONPS, em pé em cima da parede de cima da sala, no canto
## direito.
func _desenhar_fichinhas(sala: Dictionary) -> void:
	var letras: Array = sala.get("elementos", [])
	var caixas := caixas_das_fichinhas(String(sala["id"]))
	var elementos: Dictionary = estado.get("elementos", {})
	for i in caixas.size():
		_desenhar_elemento(caixas[i], letras[i], mini(int(elementos.get(letras[i], 0)), 2),
			TAM_PEQUENO, 0.0)


## Onde ficam as fichinhas dos elementos da sala, na ordem das letras: em pé
## em cima da parede de cima, encostadas no canto direito.
static func caixas_das_fichinhas(id: String) -> Array[Rect2]:
	var caixas: Array[Rect2] = []
	var letras: Array = PlantaDoMapa.area(id).get("elementos", [])
	if letras.is_empty():
		return caixas
	var caixa := caixa_da_sala(id)
	var largura := letras.size() * LADO_FICHINHA + (letras.size() - 1) * ENTRE_FICHINHAS
	var x := caixa.end.x - RECUO_FICHINHAS - largura
	for i in letras.size():
		caixas.append(Rect2(x + i * (LADO_FICHINHA + ENTRE_FICHINHAS),
			caixa.position.y + MOLDURA_SALA - LADO_FICHINHA, LADO_FICHINHA, LADO_FICHINHA))
	return caixas


## A ficha de um elemento: na cor dele quando a Cacau já o tem (piscando de
## leve quando ele ainda está com ela, esperando o painel, se "agora" vier),
## e papel com a letra apagada quando falta.
func _desenhar_elemento(r: Rect2, letra: String, nivel: int, tam: int, agora: float) -> void:
	EstiloHUD.bloco(self, Rect2(r.position + Vector2(0, 2), r.size), SOMBRA)
	var cor := AmostraChonps.cor(letra)
	if nivel <= 0:
		EstiloHUD.ficha(self, r, 1.0, PAPEL, TINTA_FRACA, 2.0, 0.0)
	else:
		if nivel == 1 and agora > 0.0:
			cor = cor.lerp(PAPEL, 0.35 + 0.35 * sin(agora * TAU * 0.9))
		EstiloHUD.ficha(self, r, 1.0, cor, TINTA, 2.0, 0.0)
	var largura := _largura(letra, tam)
	var base := r.get_center().y + _altura_da_letra(tam) * 0.5
	draw_string(FONTE, Vector2(roundf(r.get_center().x - largura * 0.5), roundf(base)), letra,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tam, TINTA if nivel > 0 else TINTA_FRACA)


func _desenhar_cadeado(passagem: Dictionary) -> void:
	var requer := String(passagem.get("requer", ""))
	if requer.is_empty() or estado.get("habilidades", {}).has(requer):
		return
	var traco := PlantaDoMapa.traco(passagem)
	if traco.is_empty():
		return
	_desenhar_pixels(CADEADO, (no_papel(traco["de"]) + no_papel(traco["ate"])) * 0.5,
		PIXEL_CADEADO, {"K": TINTA, "Y": COR_CADEADO})


## Os losangos dos objetivos, balançando.
func _desenhar_alvos(agora: float) -> void:
	var balanco := roundf(sin(agora * TAU * BALANCOS_POR_SEGUNDO) * BALANCO)
	for alvo in estado.get("alvos", []):
		_losango(centro_do_alvo(alvo["ponto"]) + Vector2(0, balanco), LOSANGO, alvo["cor"])


## Onde fica, na folha, o losango de um objetivo em "ponto" (células): no
## ponto ou, se ele cair embaixo da Cacau, encostado na plaquinha dela, do lado
## em que a sala tem mais espaço (em cima ficaria no nome da sala).
func centro_do_alvo(ponto: Vector2) -> Vector2:
	var centro := no_papel(ponto).round()
	var cacau: Vector2 = estado.get("ponto", Vector2.INF)
	if not cacau.is_finite() or centro.distance_to(no_papel(cacau)) >= PERTO_DA_CACAU:
		return centro
	var placa := _placa_do_rosto(no_papel(cacau).round())
	var sala := caixa_da_sala(String(estado.get("area", "")))
	var direita := sala.end.x - placa.end.x >= placa.position.x - sala.position.x
	return Vector2(placa.end.x if direita else placa.position.x, placa.get_center().y).round()


## A Cacau: o sinal se espalhando e, por cima, o rosto numa plaquinha de papel.
func _desenhar_cacau(agora: float) -> void:
	var ponto: Vector2 = estado.get("ponto", Vector2.INF)
	if not ponto.is_finite():
		return
	var centro := no_papel(ponto).round()
	var fase := fmod(agora, PERIODO_SINAL) / PERIODO_SINAL
	var raio := lerpf(RAIO_SINAL.x, RAIO_SINAL.y, 1.0 - pow(1.0 - fase, 2.0))
	draw_arc(centro, raio, 0.0, TAU, 48, EstiloHUD.com_alfa(TINTA_TITULO, 0.9 * (1.0 - fase)),
		3.0, false)
	_desenhar_rosto(centro, true)


func _placa_do_rosto(centro: Vector2) -> Rect2:
	var tamanho := RECORTE_ROSTO.size + FOLGA_ROSTO * 2.0
	return Rect2((centro - tamanho * 0.5).round(), tamanho)


func _desenhar_rosto(centro: Vector2, com_placa: bool) -> void:
	if com_placa:
		var placa := _placa_do_rosto(centro)
		EstiloHUD.bloco(self, Rect2(placa.position + Vector2(0, 3), placa.size), SOMBRA)
		EstiloHUD.ficha(self, placa, 1.0, PAPEL, TINTA, 2.0, 0.0)
	var canto := (centro - RECORTE_ROSTO.size * 0.5).round()
	if not com_placa:
		draw_texture_rect_region(FOLHA_ROSTO, Rect2(canto + Vector2(0, 2), RECORTE_ROSTO.size),
			Rect2(RECORTE_SILHUETA.position, RECORTE_ROSTO.size), SOMBRA)
	draw_texture_rect_region(FOLHA_ROSTO, Rect2(canto, RECORTE_ROSTO.size), RECORTE_ROSTO)


## Losango com o contorno de tinta.
func _losango(centro: Vector2, raio: float, cor: Color) -> void:
	for passo in 2:
		var r := raio + (2.0 if passo == 0 else 0.0)
		draw_colored_polygon(PackedVector2Array([centro + Vector2(0, -r), centro + Vector2(r, 0),
			centro + Vector2(0, r), centro + Vector2(-r, 0)]), TINTA if passo == 0 else cor)


## Um desenho de pixels (um caractere por pixel, "." = vazio) com o meio em
## "centro".
func _desenhar_pixels(desenho: Array, centro: Vector2, pixel: float, cores: Dictionary) -> void:
	var tamanho := Vector2(String(desenho[0]).length(), desenho.size()) * pixel
	var canto := (centro - tamanho * 0.5).round()
	for y in desenho.size():
		var linha := String(desenho[y])
		for x in linha.length():
			if cores.has(linha[x]):
				draw_rect(Rect2(canto + Vector2(x, y) * pixel, Vector2(pixel, pixel)), cores[linha[x]])


## Contorno tracejado por dentro do retângulo.
func _tracejar(r: Rect2, cor: Color, traco: float = TRACO, vao: float = VAO) -> void:
	var g := GROSSURA_TRACEJADO
	_tracejar_linha(Rect2(r.position, Vector2(r.size.x, g)), cor, traco, vao)
	_tracejar_linha(Rect2(r.position.x, r.end.y - g, r.size.x, g), cor, traco, vao)
	_tracejar_linha(Rect2(r.position, Vector2(g, r.size.y)), cor, traco, vao)
	_tracejar_linha(Rect2(r.end.x - g, r.position.y, g, r.size.y), cor, traco, vao)


## Uma faixa (deitada ou em pé) em traços inteiros, com um traço em cada ponta
## e o mesmo vão entre todos.
func _tracejar_linha(r: Rect2, cor: Color, traco: float = TRACO, vao: float = VAO) -> void:
	var deitada := r.size.x >= r.size.y
	var comprimento := r.size.x if deitada else r.size.y
	var n := maxi(1, roundi((comprimento + vao) / (traco + vao)))
	var vao_real := (comprimento - n * traco) / maxf(n - 1, 1) if n > 1 else 0.0
	for i in n:
		var inicio := roundf(i * (traco + vao_real))
		var fim := minf(roundf(i * (traco + vao_real) + traco), comprimento)
		if deitada:
			draw_rect(Rect2(r.position.x + inicio, r.position.y, fim - inicio, r.size.y), cor)
		else:
			draw_rect(Rect2(r.position.x, r.position.y + inicio, r.size.x, fim - inicio), cor)


func _desenhar_item(item: Dictionary, agora: float) -> void:
	if item.has("texto"):
		_escrever(item["pos"], item["texto"], item["tam"], item["cor"], item.get("espaco", 0.0))
	elif item.has("faixa"):
		draw_rect(item["faixa"], item["cor"])
	elif item.has("ficha"):
		var r: Rect2 = item["ficha"]
		EstiloHUD.bloco(self, Rect2(r.position + Vector2(0, 2), r.size), SOMBRA)
		EstiloHUD.ficha(self, r, 1.0, item.get("papel", PAPEL), TINTA, item.get("moldura", 2.0), 0.0)
	elif item.has("tracejado"):
		draw_rect(item["tracejado"], item.get("fundo", PAPEL))
		_tracejar(item["tracejado"], item["cor"], 4.0, 3.0)
	elif item.has("rosto"):
		_desenhar_rosto(item["rosto"], false)
	elif item.has("losango"):
		_losango(item["losango"], item["raio"], item["cor"])
	elif item.has("cadeado"):
		_desenhar_pixels(CADEADO, item["cadeado"], PIXEL_CADEADO, {"K": TINTA, "Y": COR_CADEADO})
	elif item.has("elemento"):
		_desenhar_elemento(item["elemento"], item["letra"], item["nivel"], item["tam"], agora)
	elif item.has("caixinha"):
		EstiloHUD.aro(self, item["caixinha"], TINTA, 2.0, 0.0)


# ─────────────────────────────────────────────────────────────
# TEXTO (com os índices químicos: o 2 do N₂ menor e abaixo da linha)
# ─────────────────────────────────────────────────────────────

## A fonte não tem ₂ nem ₃: o índice sai em algarismo normal, na metade do
## tamanho e descendo um quarto dele (como na lista de objetivos).
func _escrever(pos: Vector2, texto: String, tam: int, cor: Color, espaco: float = 0.0) -> void:
	if espaco > 0.0:
		EstiloHUD.texto(self, FONTE, pos, texto, tam, cor, espaco)
		return
	var x := pos.x
	for pedaco in _pedacos(texto):
		var t := _tam_do_pedaco(tam, pedaco[1])
		var y := pos.y + (roundf(tam * 0.25) if pedaco[1] else 0.0)
		draw_string(FONTE, Vector2(x, y), pedaco[0], HORIZONTAL_ALIGNMENT_LEFT, -1, t, cor)
		x += FONTE.get_string_size(pedaco[0], HORIZONTAL_ALIGNMENT_LEFT, -1, t).x


static func _largura(texto: String, tam: int, espaco: float = 0.0) -> float:
	if espaco > 0.0:
		return EstiloHUD.largura_texto(FONTE, texto, tam, espaco)
	var largura := 0.0
	for pedaco in _pedacos(texto):
		largura += FONTE.get_string_size(pedaco[0], HORIZONTAL_ALIGNMENT_LEFT, -1,
			_tam_do_pedaco(tam, pedaco[1])).x
	return largura


static func _tam_do_pedaco(tam: int, indice: bool) -> int:
	return maxi(8, roundi(tam * 0.5)) if indice else tam


## "N₂ puro" -> [["N", false], ["2", true], [" puro", false]]. O true é índice.
static func _pedacos(texto: String) -> Array:
	var pedacos: Array = []
	var atual := ""
	var atual_indice := false
	for i in texto.length():
		var codigo := texto.unicode_at(i)
		var indice := codigo >= 0x2080 and codigo <= 0x2089
		if indice != atual_indice and not atual.is_empty():
			pedacos.append([atual, atual_indice])
			atual = ""
		atual += String.chr(codigo - 0x2080 + 48) if indice else texto[i]
		atual_indice = indice
	if not atual.is_empty():
		pedacos.append([atual, atual_indice])
	return pedacos


## Quebra por palavras na largura; uma palavra maior que a largura fica
## sozinha na linha.
static func _quebrar(texto: String, tam: int, largura: float) -> PackedStringArray:
	var linhas := PackedStringArray()
	var atual := ""
	for palavra in texto.split(" ", false):
		var teste := palavra if atual.is_empty() else atual + " " + palavra
		if atual.is_empty() or _largura(teste, tam) <= largura:
			atual = teste
		else:
			linhas.append(atual)
			atual = palavra
	if not atual.is_empty():
		linhas.append(atual)
	return linhas


# ─────────────────────────────────────────────────────────────
# CONSULTAS AO "estado"
# ─────────────────────────────────────────────────────────────

func _explorada(id: String) -> bool:
	return estado.get("exploradas", {}).has(id)


## A cor de dentro da sala: a dela, se explorada; a aguada, se não.
func _fundo(id: String) -> Color:
	var cor: Color = PlantaDoMapa.area(id).get("cor", PAPEL)
	return cor if _explorada(id) else PAPEL.lerp(cor, AGUADA)


## Alguma cena passa por esta sala (a Cacau anda por ela)?
static func _tem_cena(id: String) -> bool:
	for caminho: String in PlantaDoMapa.CENAS:
		if id in PlantaDoMapa.areas_da_cena(caminho):
			return true
	return false
