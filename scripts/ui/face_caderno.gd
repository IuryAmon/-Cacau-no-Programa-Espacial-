class_name FaceCaderno
extends Control

# --- UMA FACE DO CADERNO (a tipografia) ---
#
# Desenha uma face de PaginasCaderno no papel. O tamanho do nó é o papel da
# face (CadernoLivro.FACE_ESQUERDA / FACE_DIREITA), e o texto fica dentro da
# MARGEM, longe do fio da borda.
#
# Tinta de caneta sobre o papel da arte, na fonte do jogo. A ari-w9500 é pixel
# art numa grade de 11 px por em, então os tamanhos são múltiplos de 11 e cada
# pixel da letra fica inteiro: o texto na 22 (pixel de 2 px), a fórmula na 33 e
# o título na 44. A caixa do hidrogênio vai ampliada 2×, no mesmo pixel de 2 px
# do texto (o nome do elemento dentro dela vai na 11 ampliada 1,5×: na 22 não
# cabe no vão).
# O átomo de lítio vai em 1,5×, para caber com o título: o traço de 2 px dele
# vira 3 px certinhos.
#
# O CadernoLivro espreme este nó (scale.x) e o apaga (modulate) enquanto ele
# vai na folha que vira; aqui nada disso importa.

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

const TAM_TEXTO := 22
const TAM_FORMULA := 33
const TAM_TITULO := 44
const TAM_NOME := 11
## O nome na caixa vai na TAM_NOME ampliada assim, desenhado ampliado e não
## numa letra maior: na 22 não cabe (136 px num vão de 132), e numa letra fora
## da grade de 11 o pixel dela borra. Em 1,5×, cada pixel da letra fica com 1
## ou 2 px, como o traço do átomo.
const ESCALA_NOME := 1.5
const ENTRELINHA := 32.0
const MARGEM := Vector2(24, 24)
## O bloco fica um pouco acima do meio: o meio "de olho" de uma página é mais
## alto que o meio medido.
const SUBIDA_OPTICA := 14.0

## Linha de base do título; o resto da face vai do FIM_TITULO para baixo.
const BASE_TITULO := 84.0
const FIM_TITULO := 124.0
## O sublinhado do título, abaixo da linha de base.
const SUBLINHADO := 14.0
## Linha de base do número da página, contada do pé do papel.
const PE_NUMERO := 16.0

## O desenho vai ampliado assim quando a página não diz a "escala" (o pixel
## dele = o pixel da letra na TAM_TEXTO).
const ESCALA_ARTE := 2.0
## Os traços do mapa mental: grossura (o pixel da letra), folga até a parte do
## desenho, quanto passam da tinta do desenho e folga até o texto.
const TRACO := 2.0
const FOLGA_PARTE := 4.0
const ALCANCE := 28.0
const FOLGA_TEXTO := 8.0

## Nas propriedades, de linha de base a linha de base: da fórmula ao texto
## dela, e do fim de um item à fórmula do próximo. Com a fórmula embaixo do
## texto: do texto à fórmula dele, e da fórmula ao texto do próximo item (as
## mesmas folgas, contando a altura de cada letra).
const DA_FORMULA := 36.0
const ENTRE_ITENS := 64.0
const ATE_A_FORMULA := 44.0
const DEPOIS_DA_FORMULA := 56.0
## O ícone antes da fórmula: ampliado assim e com esta folga até ela.
const ESCALA_ICONE := 2.0
const FOLGA_ICONE := 12.0
## O ícone no meio do texto ({nome}): no tamanho em que a partícula está no
## átomo (e cabe entre uma linha e outra), com esta folga de cada lado.
const ESCALA_ICONE_NO_TEXTO := 1.5
const FOLGA_ICONE_NO_TEXTO := 3.0

## Folha de rosto: linha de base da primeira linha do título e da linha do
## nome (fração da altura da face), de uma linha do título à outra, e a linha
## em que o nome vai escrito.
const ALTURA_TITULO_ROSTO := 0.3
const ALTURA_NOME := 0.72
const ENTRELINHA_TITULO := 52.0
const LINHA_NOME := 220.0
const FOLGA_NOME := 12.0

## Epígrafe: a largura em que a citação quebra (mais estreita que o papel, com
## folga dos lados) e, de linha de base a linha de base, do fim dela à autoria.
const LARGURA_EPIGRAFE := 352.0
const DA_CITACAO := 56.0

const TINTA := Color8(0x3d, 0x2a, 0x22)
const TINTA_TITULO := Color8(0x8e, 0x3b, 0x2c)
const TINTA_FRACA := Color8(0x8a, 0x6d, 0x52)

## O que está escrito nesta face (ver PaginasCaderno). Vazio = folha em branco.
var dados: Dictionary = {}:
	set(valor):
		if valor == dados:
			return
		dados = valor
		queue_redraw()

## O número desta face no caderno (PaginasCaderno.numero); 0 = sem número. Vai
## no canto de baixo de fora, como num livro: par à esquerda, ímpar à direita.
var numero: int = 0:
	set(valor):
		if valor == numero:
			return
		numero = valor
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## O papel por dentro da margem: texto nenhum sai daqui.
func area_util() -> Rect2:
	return Rect2(MARGEM, size - MARGEM * 2.0)


## O que vai nesta face, já no lugar, na ordem de desenhar. Cada item é um
## texto ({"texto", "pos" (na linha de base), "tam", "cor"}), um traço
## ({"traco": Rect2, "cor"}), um polígono ({"poligono", "cor"}) ou uma arte
## ({"arte": Texture2D, "rect"}, com "regiao" se for só um pedaço dela, e
## "tinta" = onde o desenho tem tinta, na face). Texto com "limite" não pode
## sair dele (o nome, do vão da caixa); os outros, da area_util. O
## teste_caderno confere.
func montar() -> Array:
	var itens: Array = []
	var area := area_util()
	var titulo := String(dados.get("titulo", ""))
	if not titulo.is_empty():
		_por_titulo(itens, titulo)
		area = Rect2(area.position.x, FIM_TITULO, area.size.x, area.end.y - FIM_TITULO)
	match String(dados.get("tipo", "")):
		"rosto":
			itens.append_array(_montar_rosto())
		"epigrafe":
			itens.append_array(_montar_epigrafe(area))
		"desenho":
			itens.append_array(_montar_desenho(area))
		"propriedades":
			itens.append_array(_montar_propriedades(area))
	if numero > 0:
		_por_numero(itens)
	return itens


## Onde fica o texto de um item de montar(), do ascendente ao descendente.
static func caixa_do_texto(item: Dictionary) -> Rect2:
	var tam: int = item["tam"]
	var escala: float = item.get("escala", 1.0)
	var sobe := FONTE.get_ascent(tam)
	return Rect2(item["pos"] - Vector2(0, sobe * escala),
		Vector2(_largura(item["texto"], tam), sobe + FONTE.get_descent(tam)) * escala)


func _draw() -> void:
	for item in montar():
		if item.has("regiao"):
			draw_texture_rect_region(item["arte"], item["rect"], item["regiao"])
		elif item.has("arte"):
			draw_texture_rect(item["arte"], item["rect"], false)
		elif item.has("traco"):
			draw_rect(item["traco"], item["cor"])
		elif item.has("poligono"):
			draw_colored_polygon(item["poligono"], item["cor"])
		elif item.has("escala"):
			draw_set_transform(item["pos"], 0.0, Vector2.ONE * item["escala"])
			draw_string(FONTE, Vector2.ZERO, item["texto"], HORIZONTAL_ALIGNMENT_LEFT, -1,
				item["tam"], item["cor"])
			draw_set_transform(Vector2.ZERO)
		else:
			draw_string(FONTE, item["pos"], item["texto"], HORIZONTAL_ALIGNMENT_LEFT, -1,
				item["tam"], item["cor"])


## Centrado no alto da face, sublinhado à mão.
func _por_titulo(itens: Array, titulo: String) -> void:
	var largura := _largura(titulo, TAM_TITULO)
	var x := roundf((size.x - largura) * 0.5)
	itens.append({"texto": titulo, "pos": Vector2(x, BASE_TITULO), "tam": TAM_TITULO,
		"cor": TINTA_TITULO})
	itens.append({"traco": Rect2(x, BASE_TITULO + SUBLINHADO, largura, TRACO),
		"cor": TINTA_TITULO})


## No canto de baixo de fora: na linha da margem do lado e um pouco abaixo da
## margem de baixo, perto do pé do papel (arredondado para dentro).
func _por_numero(itens: Array) -> void:
	var texto := str(numero)
	var x := MARGEM.x if numero % 2 == 0 \
		else floorf(size.x - MARGEM.x - _largura(texto, TAM_TEXTO))
	itens.append({"texto": texto, "tam": TAM_TEXTO, "cor": TINTA_FRACA,
		"pos": Vector2(x, size.y - PE_NUMERO), "limite": Rect2(Vector2.ZERO, size)})


# ─────────────────────────────────────────────────────────────
# FOLHA DE ROSTO
# ─────────────────────────────────────────────────────────────

## O título no alto, com um enfeite embaixo, e o nome da dona escrito na
## linha, como na etiqueta de um caderno de escola.
func _montar_rosto() -> Array:
	var itens: Array = []
	var meio := size.x * 0.5
	var y := roundf(size.y * ALTURA_TITULO_ROSTO)
	for linha in dados.get("linhas", []):
		var texto := String(linha)
		itens.append({"texto": texto, "tam": TAM_TITULO, "cor": TINTA_TITULO,
			"pos": Vector2(roundf(meio - _largura(texto, TAM_TITULO) * 0.5), y)})
		y += ENTRELINHA_TITULO
	itens.append_array(_enfeite(Vector2(meio, y - ENTRELINHA_TITULO + 34.0), 96.0, TINTA_TITULO))

	var rotulo := String(dados.get("rotulo_nome", ""))
	var nome := String(dados.get("nome", ""))
	var largura_rotulo := _largura(rotulo, TAM_TEXTO)
	var x := roundf(meio - (largura_rotulo + FOLGA_NOME + LINHA_NOME) * 0.5)
	var base := roundf(size.y * ALTURA_NOME)
	var x_linha := x + largura_rotulo + FOLGA_NOME
	itens.append({"texto": rotulo, "pos": Vector2(x, base), "tam": TAM_TEXTO, "cor": TINTA_FRACA})
	itens.append({"traco": Rect2(x_linha, base + 8.0, LINHA_NOME, TRACO), "cor": TINTA_FRACA})
	itens.append({"texto": nome, "tam": TAM_TITULO, "cor": TINTA,
		"pos": Vector2(roundf(x_linha + (LINHA_NOME - _largura(nome, TAM_TITULO)) * 0.5), base)})
	return itens


## Um fio com um losango no meio, no pixel da letra.
func _enfeite(centro: Vector2, meia_largura: float, cor: Color) -> Array:
	centro = centro.round()
	var losango := 8.0
	var fio := meia_largura - losango - 4.0
	return [
		{"traco": Rect2(centro.x - meia_largura, centro.y - TRACO * 0.5, fio, TRACO), "cor": cor},
		{"traco": Rect2(centro.x + losango + 4.0, centro.y - TRACO * 0.5, fio, TRACO), "cor": cor},
		{"poligono": PackedVector2Array([centro + Vector2(0, -losango),
			centro + Vector2(losango, 0), centro + Vector2(0, losango),
			centro + Vector2(-losango, 0)]), "cor": cor},
	]


# ─────────────────────────────────────────────────────────────
# EPÍGRAFE (a citação e de quem ela é)
# ─────────────────────────────────────────────────────────────

## A citação alinhada à esquerda e, embaixo, a autoria mais fraca, alinhada à
## direita do bloco; o bloco vai no meio da área, um pouco acima.
func _montar_epigrafe(area: Rect2) -> Array:
	var itens: Array = []
	var linhas := EstiloHUD.quebrar(FONTE, String(dados.get("texto", "")), TAM_TEXTO,
		minf(LARGURA_EPIGRAFE, area.size.x))
	var autoria: Array = dados.get("autoria", [])
	var mais_largo := 0.0
	for linha in Array(linhas) + autoria:
		mais_largo = maxf(mais_largo, _largura(String(linha), TAM_TEXTO))

	var y := FONTE.get_ascent(TAM_TEXTO)
	for i in linhas.size():
		if i > 0:
			y += ENTRELINHA
		itens.append({"texto": linhas[i], "pos": Vector2(0, y), "tam": TAM_TEXTO, "cor": TINTA})
	for i in autoria.size():
		var texto := String(autoria[i])
		y += DA_CITACAO if i == 0 else ENTRELINHA
		itens.append({"texto": texto, "tam": TAM_TEXTO, "cor": TINTA_FRACA,
			"pos": Vector2(mais_largo - _largura(texto, TAM_TEXTO), y)})
	var altura := y + FONTE.get_descent(TAM_TEXTO)
	_mover(itens, Vector2(area.get_center().x - mais_largo * 0.5,
		area.get_center().y - altura * 0.5 - SUBIDA_OPTICA).round())
	return itens


# ─────────────────────────────────────────────────────────────
# DESENHO (a arte e o mapa mental dela)
# ─────────────────────────────────────────────────────────────

## Monta com o desenho em (0, 0); no fim, o conjunto (a tinta do desenho, os
## traços e os textos) vai para o meio da área. Com "desenho_no_meio", quem
## vai para o meio é só a tinta do desenho, e os nomes ficam em volta dela.
func _montar_desenho(area: Rect2) -> Array:
	var arte: Texture2D = dados.get("arte")
	if arte == null:
		return []
	var escala := float(dados.get("escala", ESCALA_ARTE))
	var tinta: Rect2 = dados.get("tinta", Rect2(Vector2.ZERO, arte.get_size()))
	tinta = Rect2(tinta.position * escala, tinta.size * escala)
	var itens: Array = [{"arte": arte, "tinta": tinta,
		"rect": Rect2(Vector2.ZERO, arte.get_size() * escala)}]

	var nome := String(dados.get("nome", ""))
	if not nome.is_empty():
		var vao: Rect2 = dados.get("vao_do_nome", Rect2(Vector2.ZERO, arte.get_size()))
		vao = Rect2(vao.position * escala, vao.size * escala)
		var sobe := FONTE.get_ascent(TAM_NOME) * ESCALA_NOME
		var desce := FONTE.get_descent(TAM_NOME) * ESCALA_NOME
		itens.append({"texto": nome, "tam": TAM_NOME, "escala": ESCALA_NOME, "cor": TINTA,
			"limite": vao,
			"pos": Vector2(vao.get_center().x - _largura(nome, TAM_NOME) * ESCALA_NOME * 0.5,
				vao.get_center().y + (sobe - desce) * 0.5)})

	for marca in dados.get("marcas", []):
		itens.append_array(_marca(marca, escala, tinta))

	var conjunto := tinta
	if not dados.get("desenho_no_meio", false):
		for item in itens:
			if item.has("texto"):
				conjunto = conjunto.merge(caixa_do_texto(item))
	_mover(itens, (area.get_center() - conjunto.get_center()).round())
	return itens


## O traço de uma parte do desenho até o texto que diz o que ela é. Ele vai até
## ALCANCE depois da tinta do desenho, para o texto não encostar em nada, ou
## até o "ate" da marca (px da arte), quando o texto cabe num vão do desenho.
## Subindo ou descendo, o texto fica na ponta, centrado; com "lado" (esquerda
## ou direita), fica ao lado da ponta, na mesma altura em que ficaria na
## ponta, e o traço vai até o meio dele.
func _marca(marca: Dictionary, escala: float, tinta: Rect2) -> Array:
	var de: Vector2 = marca["de"] * escala
	var texto := String(marca["texto"])
	var lado := String(marca.get("lado", ""))
	var ate: float = marca.get("ate", NAN) * escala
	var largura := _largura(texto, TAM_TEXTO)
	var sobe := FONTE.get_ascent(TAM_TEXTO)
	var desce := FONTE.get_descent(TAM_TEXTO)
	var ate_o_meio := 0.0 if lado.is_empty() else FOLGA_TEXTO + (sobe + desce) * 0.5
	var meio := TRACO * 0.5
	var traco: Rect2
	var base: Vector2
	match String(marca["rumo"]):
		"cima":
			var fim := (tinta.position.y - ALCANCE if is_nan(ate) else ate) - ate_o_meio
			traco = Rect2(de.x - meio, fim, TRACO, de.y - FOLGA_PARTE - fim)
			base = Vector2(de.x - largura * 0.5, fim - FOLGA_TEXTO - desce)
		"baixo":
			var inicio := de.y + FOLGA_PARTE
			var fim := (tinta.end.y + ALCANCE if is_nan(ate) else ate) + ate_o_meio
			traco = Rect2(de.x - meio, inicio, TRACO, fim - inicio)
			base = Vector2(de.x - largura * 0.5, fim + FOLGA_TEXTO + sobe)
		"esquerda":
			var fim := tinta.position.x - ALCANCE if is_nan(ate) else ate
			traco = Rect2(fim, de.y - meio, de.x - FOLGA_PARTE - fim, TRACO)
			base = Vector2(fim - FOLGA_TEXTO - largura, de.y + sobe * 0.5)
		_:
			var inicio := de.x + FOLGA_PARTE
			var fim := tinta.end.x + ALCANCE if is_nan(ate) else ate
			traco = Rect2(inicio, de.y - meio, fim - inicio, TRACO)
			base = Vector2(fim + FOLGA_TEXTO, de.y + sobe * 0.5)
	if ate_o_meio > 0.0 and String(marca["rumo"]) in ["cima", "baixo"]:
		var ponta := traco.position.y if marca["rumo"] == "cima" else traco.end.y
		var x := de.x + meio + FOLGA_TEXTO if lado == "direita" \
			else de.x - meio - FOLGA_TEXTO - largura
		base = Vector2(x, ponta + (sobe - desce) * 0.5)
	return [{"traco": traco, "cor": TINTA},
		{"texto": texto, "pos": base, "tam": TAM_TEXTO, "cor": TINTA}]


# ─────────────────────────────────────────────────────────────
# PROPRIEDADES (fórmula e explicação curta)
# ─────────────────────────────────────────────────────────────

## Bloco alinhado à esquerda, centrado pela linha mais larga e um pouco acima
## do meio da área. Com ícones, eles ficam numa coluna à esquerda, no meio da
## altura da fórmula, e a fórmula e o texto se alinham depois dela. Com
## "formulas_no_meio", cada fórmula fica centrada no bloco, e o bloco já está
## no meio da face; com "formula_embaixo", o texto vem antes e a fórmula dele
## embaixo. Um {nome} no texto vira o ícone do "pedacos", na linha.
func _montar_propriedades(area: Rect2) -> Array:
	var icones: Texture2D = dados.get("icones")
	var coluna := 0.0
	if icones != null:
		for item in dados.get("itens", []):
			if item.has("icone"):
				coluna = maxf(coluna, item["icone"].size.x * ESCALA_ICONE)
	var x := coluna + FOLGA_ICONE if coluna > 0.0 else 0.0
	var embaixo: bool = dados.get("formula_embaixo", false)

	var itens: Array = []
	var formulas: Array = []
	var y := NAN
	var ultimo_tam := TAM_TEXTO
	var mais_largo := 0.0
	for item in dados.get("itens", []):
		# A fórmula (String) e as linhas do texto, na ordem em que vão.
		var ordem: Array = _quebrar_com_icones(String(item.get("texto", "")), area.size.x - x)
		var formula := String(item.get("formula", ""))
		if embaixo:
			ordem.append(formula)
		else:
			ordem.push_front(formula)
		var anterior := ""
		for coisa in ordem:
			var e_formula: bool = coisa is String
			if is_nan(y):
				y = FONTE.get_ascent(TAM_FORMULA if e_formula else TAM_TEXTO)
			elif anterior.is_empty():
				y += DEPOIS_DA_FORMULA if embaixo else ENTRE_ITENS
			elif e_formula:
				y += ATE_A_FORMULA
			else:
				y += DA_FORMULA if anterior == "formula" else ENTRELINHA
			anterior = "formula" if e_formula else "texto"
			ultimo_tam = TAM_FORMULA if e_formula else TAM_TEXTO
			if not e_formula:
				mais_largo = maxf(mais_largo, _por_linha(itens, coisa, Vector2(x, y), icones))
				continue
			if icones != null and item.has("icone"):
				var regiao: Rect2 = item["icone"]
				var lado := regiao.size * ESCALA_ICONE
				var meio_da_formula := y - FONTE.get_ascent(TAM_FORMULA) * 0.5
				itens.append({"arte": icones, "regiao": regiao, "rect": Rect2(
					Vector2((coluna - lado.x) * 0.5, meio_da_formula - lado.y * 0.5).round(), lado)})
			formulas.append({"texto": formula, "pos": Vector2(x, y), "tam": TAM_FORMULA,
				"cor": TINTA_TITULO})
			itens.append(formulas[-1])
			mais_largo = maxf(mais_largo, x + _largura(formula, TAM_FORMULA))
	if dados.get("formulas_no_meio", false):
		for formula in formulas:
			formula["pos"] = Vector2((mais_largo - _largura(formula["texto"], TAM_FORMULA)) * 0.5,
				formula["pos"].y)
	var altura := (0.0 if is_nan(y) else y) + FONTE.get_descent(ultimo_tam)
	_mover(itens, Vector2(area.get_center().x - mais_largo * 0.5,
		area.get_center().y - altura * 0.5 - SUBIDA_OPTICA).round())
	return itens


## Quebra o texto em linhas que cabem na largura, como o EstiloHUD.quebrar,
## mas com os ícones ({nome}) ocupando o lugar deles e o *destaque* na cor da
## fórmula. Cada linha é uma lista de pedaços: texto ({"texto", "cor"}) ou
## ícone (Rect2, a região dele na arte).
func _quebrar_com_icones(texto: String, largura: float) -> Array:
	var linhas: Array = []
	var linha: Array = []
	var ocupado := 0.0
	var espaco := _largura(" ", TAM_TEXTO)
	var destaque := false
	for palavra in texto.split(" ", false):
		var pedacos := _pedacos_da_palavra(palavra, destaque)
		var largura_da_palavra := _largura_dos_pedacos(pedacos)
		if not linha.is_empty() and ocupado + espaco + largura_da_palavra > largura:
			linhas.append(linha)
			linha = []
		if linha.is_empty():
			ocupado = largura_da_palavra
		else:
			# O espaço fica da cor de onde ele está: dentro do destaque, emenda.
			linha.append({"texto": " ", "cor": _cor_do_texto(destaque)})
			ocupado += espaco + largura_da_palavra
		linha.append_array(pedacos)
		if palavra.count("*") % 2 == 1:
			destaque = not destaque
	if not linha.is_empty():
		linhas.append(linha)
	return linhas


## Uma palavra em pedaços de texto e ícones: "{nêutron}." vira o ícone do
## nêutron e o ponto, e cada * liga ou desliga o destaque. Um {nome} que o
## "pedacos" da face não tem fica escrito.
func _pedacos_da_palavra(palavra: String, destaque: bool) -> Array:
	var regioes: Dictionary = dados.get("pedacos", {})
	var pedacos: Array = []
	var corrido := ""
	var i := 0
	while i < palavra.length():
		var fecha := palavra.find("}", i) if palavra[i] == "{" else -1
		var nome := palavra.substr(i + 1, fecha - i - 1) if fecha >= 0 else ""
		if palavra[i] != "*" and not regioes.has(nome):
			corrido += palavra[i]
			i += 1
			continue
		if not corrido.is_empty():
			pedacos.append({"texto": corrido, "cor": _cor_do_texto(destaque)})
			corrido = ""
		if palavra[i] == "*":
			destaque = not destaque
			i += 1
		else:
			pedacos.append(regioes[nome])
			i = fecha + 1
	if not corrido.is_empty():
		pedacos.append({"texto": corrido, "cor": _cor_do_texto(destaque)})
	return pedacos


static func _cor_do_texto(destaque: bool) -> Color:
	return TINTA_TITULO if destaque else TINTA


static func _largura_dos_pedacos(pedacos: Array) -> float:
	var largura := 0.0
	for pedaco in pedacos:
		largura += _largura(pedaco["texto"], TAM_TEXTO) if pedaco is Dictionary \
			else pedaco.size.x * ESCALA_ICONE_NO_TEXTO + FOLGA_ICONE_NO_TEXTO * 2.0
	return largura


## Põe uma linha de _quebrar_com_icones com a linha de base em "pos": o texto
## da mesma cor entre os ícones num item só, e cada ícone no meio da altura da
## letra. Devolve onde a linha acaba.
func _por_linha(itens: Array, linha: Array, pos: Vector2, arte: Texture2D) -> float:
	var x := pos.x
	var corrido := ""
	var cor := TINTA
	var meio := pos.y - FONTE.get_ascent(TAM_TEXTO) * 0.5
	for pedaco in linha + [null]:
		if pedaco is Dictionary and (corrido.is_empty() or pedaco["cor"] == cor):
			corrido += pedaco["texto"]
			cor = pedaco["cor"]
			continue
		if not corrido.is_empty():
			itens.append({"texto": corrido, "pos": Vector2(x, pos.y), "tam": TAM_TEXTO, "cor": cor})
			x += _largura(corrido, TAM_TEXTO)
			corrido = ""
		if pedaco is Dictionary:
			corrido = pedaco["texto"]
			cor = pedaco["cor"]
		elif pedaco is Rect2:
			var lado: Vector2 = pedaco.size * ESCALA_ICONE_NO_TEXTO
			itens.append({"arte": arte, "regiao": pedaco, "rect": Rect2(
				Vector2(x + FOLGA_ICONE_NO_TEXTO, meio - lado.y * 0.5).round(), lado)})
			x += lado.x + FOLGA_ICONE_NO_TEXTO * 2.0
	return x


## Leva os itens montados em (0, 0) para o lugar deles na face.
static func _mover(itens: Array, desvio: Vector2) -> void:
	for item in itens:
		for chave in ["rect", "tinta", "traco", "limite"]:
			if item.has(chave):
				item[chave] = Rect2(item[chave].position + desvio, item[chave].size)
		if item.has("pos"):
			item["pos"] = (item["pos"] + desvio).round()


static func _largura(texto: String, tamanho: int) -> float:
	return FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
