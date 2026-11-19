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
## A cor do papel da arte: o miolo dos átomos de hidrogênio desenhados.
const PAPEL := Color8(0xe7, 0xd5, 0xb3)

## Os índices das fórmulas (o 2 de H₂O) vêm escritos nas PaginasCaderno com os
## algarismos de índice (₀ a ₉), que a fonte não tem: na face, cada um vira o
## algarismo comum numa letra menor, um pouco abaixo da linha (ver
## _separar_indices).
const PRIMEIRO_INDICE := 0x2080

## Nos "blocos": a folga entre um bloco e o seguinte.
const FOLGA_ENTRE_BLOCOS := 16.0
## Nos "passos": da linha de base do fim de um passo à do número do próximo,
## e do número até o texto.
const ENTRE_PASSOS := 50.0
const FOLGA_NUMERO := 14.0

# Os desenhos feitos aqui (ver _desenho()).
## O pixel dos anéis do átomo: o do átomo de lítio em 1,5× (o traço de 2 px da
## arte vira 3).
const PX_ATOMO := 3.0
## As partículas (a arte delas) no tamanho em que estão no átomo de lítio.
const ESCALA_PARTICULA := 1.5
## Distância entre as partículas do núcleo: elas se encostam, como na arte.
const PASSO_DO_NUCLEO := 8.5
## Cada partícula do núcleo vai girada deste ângulo em relação à anterior (o
## ângulo de ouro: o cacho fica redondo e sem buracos).
const ANGULO_DE_OURO := 2.39996
## Os átomos das moléculas desenhadas: hidrogênio pequeno e claro, oxigênio
## maior e na cor das fórmulas.
const RAIO_H := 7.0
const RAIO_O := 10.0
## O cilindro do compressor (por dentro) e o êmbolo.
const CILINDRO := Vector2(96, 168)
const GROSSURA_DO_EMBOLO := 10.0
## As moléculas do ar no cilindro (fração da largura e da altura do gás): as
## mesmas nos dois desenhos, só o espaço muda.
const MOLECULAS_NO_CILINDRO := [Vector2(0.1, 0.12), Vector2(0.48, 0.05), Vector2(0.86, 0.2),
	Vector2(0.28, 0.42), Vector2(0.66, 0.36), Vector2(0.95, 0.62), Vector2(0.06, 0.78),
	Vector2(0.45, 0.72), Vector2(0.78, 0.95)]
const RAIO_MOLECULA_DO_AR := 4.0
## O termômetro: do bulbo até o topo da escala, e a largura do tubo.
const ALTURA_DO_TERMOMETRO := 320.0
const LARGURA_DO_TUBO := 14.0
const RAIO_DO_BULBO := 16.0

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
		"blocos":
			itens.append_array(_montar_blocos(area))
		"passos":
			itens.append_array(_montar_passos(area))
	if numero > 0:
		_por_numero(itens)
	return _separar_indices(itens)


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


# ─────────────────────────────────────────────────────────────
# BLOCOS (texto, fórmula e desenho, um embaixo do outro)
# ─────────────────────────────────────────────────────────────

## Cada bloco centrado na largura da área, um embaixo do outro, e o conjunto
## no meio da altura (um pouco acima). Os blocos:
##   {"texto": ...}          um parágrafo, com *destaque* e {nome} como nas
##                           propriedades; "cor": "fraca" para a tinta fraca, e
##                           "alinhar": "esquerda" ou "direita"
##   {"formula": ...}        uma fórmula, na letra e na cor das propriedades
##   {"desenho": nome, ...}  um dos desenhos feitos aqui (ver _desenho())
##   {"espaco": px}          mais folga até o próximo bloco
func _montar_blocos(area: Rect2) -> Array:
	var itens: Array = []
	var icones: Texture2D = dados.get("icones")
	var largura := area.size.x
	var y := 0.0
	var primeiro := true
	for bloco: Dictionary in dados.get("blocos", []):
		if bloco.has("espaco"):
			y += float(bloco["espaco"])
			continue
		if not primeiro:
			y += FOLGA_ENTRE_BLOCOS
		primeiro = false
		var parte: Array = []
		# O desenho primeiro: alguns têm "formula" (a da molécula desenhada).
		if bloco.has("desenho"):
			parte = _desenho(bloco)
			var caixa := _caixa_de(parte)
			_mover(parte, Vector2(roundf(largura * 0.5 - caixa.get_center().x), roundf(y - caixa.position.y)))
			y += caixa.size.y
		elif bloco.has("texto"):
			var linhas := _quebrar_com_icones(String(bloco["texto"]), largura)
			var alinhar := String(bloco.get("alinhar", "meio"))
			var base := y + FONTE.get_ascent(TAM_TEXTO)
			for i in linhas.size():
				var sobra := largura - _largura_dos_pedacos(linhas[i])
				var x := 0.0 if alinhar == "esquerda" else (sobra if alinhar == "direita" else sobra * 0.5)
				_por_linha(parte, linhas[i], Vector2(roundf(x), base + ENTRELINHA * i), icones)
			if String(bloco.get("cor", "")) == "fraca":
				for item in parte:
					if item.has("texto") and item["cor"] == TINTA:
						item["cor"] = TINTA_FRACA
			y = base + ENTRELINHA * (linhas.size() - 1) + FONTE.get_descent(TAM_TEXTO)
		elif bloco.has("formula"):
			var formula := String(bloco["formula"])
			var base := y + FONTE.get_ascent(TAM_FORMULA)
			parte.append({"texto": formula, "tam": TAM_FORMULA, "cor": TINTA_TITULO,
				"pos": Vector2(roundf((largura - _largura(formula, TAM_FORMULA)) * 0.5), base)})
			y = base + FONTE.get_descent(TAM_FORMULA)
		itens.append_array(parte)
	_mover(itens, Vector2(area.position.x, roundf(area.get_center().y - y * 0.5 - SUBIDA_OPTICA)))
	return itens


# ─────────────────────────────────────────────────────────────
# PASSOS (uma lista numerada)
# ─────────────────────────────────────────────────────────────

## Cada passo com o número grande à esquerda, na cor das fórmulas, e o texto
## dele quebrado à direita do número. O bloco vai no meio da área, centrado
## pela linha mais larga e um pouco acima do meio, como nas propriedades.
func _montar_passos(area: Rect2) -> Array:
	var itens: Array = []
	var icones: Texture2D = dados.get("icones")
	var passos: Array = dados.get("passos", [])
	var coluna := 0.0
	for i in passos.size():
		coluna = maxf(coluna, _largura(str(i + 1), TAM_FORMULA))
	var x := coluna + FOLGA_NUMERO
	var y := NAN
	var mais_largo := 0.0
	for i in passos.size():
		# O número e a primeira linha do texto na mesma linha de base.
		y = FONTE.get_ascent(TAM_FORMULA) if is_nan(y) else y + ENTRE_PASSOS
		var numero_do_passo := str(i + 1)
		itens.append({"texto": numero_do_passo, "tam": TAM_FORMULA, "cor": TINTA_TITULO,
			"pos": Vector2(coluna - _largura(numero_do_passo, TAM_FORMULA), y)})
		var linhas := _quebrar_com_icones(String(passos[i]), area.size.x - x)
		for j in linhas.size():
			if j > 0:
				y += ENTRELINHA
			mais_largo = maxf(mais_largo, _por_linha(itens, linhas[j], Vector2(x, y), icones))
	var altura := (0.0 if is_nan(y) else y) + FONTE.get_descent(TAM_TEXTO)
	_mover(itens, Vector2(area.get_center().x - mais_largo * 0.5,
		area.get_center().y - altura * 0.5 - SUBIDA_OPTICA).round())
	return itens


# ─────────────────────────────────────────────────────────────
# DESENHOS (feitos aqui, no pixel da letra, com as tintas do caderno)
# ─────────────────────────────────────────────────────────────

## Os itens de um bloco {"desenho": nome, ...}, em volta de (0, 0):
##   "atomo"            núcleo, camadas e elétrons (ver _desenho_atomo)
##   "equacao"          a equação com as moléculas embaixo de cada termo
##   "moleculas"        "quantas" moléculas da "formula", lado a lado
##   "formula_anotada"  uma fórmula grande com o nome das partes dela
##   "embolos"          o gás no cilindro, com muito e com pouco volume
##   "termometro"       um termômetro com as temperaturas marcadas
func _desenho(bloco: Dictionary) -> Array:
	match String(bloco["desenho"]):
		"atomo":
			return _desenho_atomo(bloco)
		"equacao":
			return _desenho_equacao(bloco)
		"moleculas":
			return _desenho_moleculas(String(bloco.get("formula", "")), int(bloco.get("quantas", 1)),
				Vector2.ZERO)
		"formula_anotada":
			return _desenho_formula_anotada(bloco)
		"embolos":
			return _desenho_embolos(bloco)
		"termometro":
			return _desenho_termometro(bloco)
	return []


## Onde os itens têm tinta (traços, polígonos, artes e textos).
static func _caixa_de(itens: Array) -> Rect2:
	var caixa := Rect2()
	var primeiro := true
	for item in itens:
		var r := Rect2()
		if item.has("texto"):
			r = caixa_do_texto(item)
		elif item.has("traco"):
			r = item["traco"]
		elif item.has("rect"):
			r = item["rect"]
		elif item.has("poligono"):
			var pontos: PackedVector2Array = item["poligono"]
			r = Rect2(pontos[0], Vector2.ZERO)
			for ponto in pontos:
				r = r.expand(ponto)
		else:
			continue
		caixa = r if primeiro else caixa.merge(r)
		primeiro = false
	return caixa


## Um disco cheio em pixel art, uma fileira de "px" de altura de cada vez.
static func _disco(centro: Vector2, raio: float, cor: Color, px: float = TRACO) -> Array:
	var itens: Array = []
	var r := raio / px
	var n := ceili(r)
	for j in range(-n, n):
		var y := absf(j + 0.5)
		if y >= r:
			continue
		var meia := roundf(sqrt(r * r - y * y))
		if meia > 0.0:
			itens.append({"traco": Rect2(centro.x - meia * px, centro.y + j * px, meia * 2.0 * px, px),
				"cor": cor})
	return itens


## Uma circunferência em pixel art, da grossura de um "px".
static func _anel(centro: Vector2, raio: float, cor: Color, px: float) -> Array:
	var itens: Array = []
	var fora := raio / px + 0.5
	var dentro := raio / px - 0.5
	var n := ceili(fora)
	for j in range(-n, n):
		var y := absf(j + 0.5)
		if y >= fora:
			continue
		var x_fora := roundf(sqrt(fora * fora - y * y))
		var x_dentro := minf(roundf(sqrt(dentro * dentro - y * y)) if y < dentro else 0.0, x_fora - 1.0)
		var topo := centro.y + j * px
		if x_dentro <= 0.0:
			itens.append({"traco": Rect2(centro.x - x_fora * px, topo, x_fora * 2.0 * px, px), "cor": cor})
		else:
			var largura := (x_fora - x_dentro) * px
			itens.append({"traco": Rect2(centro.x - x_fora * px, topo, largura, px), "cor": cor})
			itens.append({"traco": Rect2(centro.x + x_dentro * px, topo, largura, px), "cor": cor})
	return itens


## Uma partícula da arte das partículas (o pedaço "regiao"), centrada.
static func _particula(arte: Texture2D, regiao: Rect2, centro: Vector2) -> Dictionary:
	var lado := regiao.size * ESCALA_PARTICULA
	return {"arte": arte, "regiao": regiao, "rect": Rect2((centro - lado * 0.5).round(), lado)}


## Um texto com o meio da letra na altura "y" e o meio dele em "x".
static func _texto_no_meio(texto: String, centro: Vector2, tam: int, cor: Color) -> Dictionary:
	return {"texto": texto, "tam": tam, "cor": cor, "pos": Vector2(
		roundf(centro.x - _largura(texto, tam) * 0.5),
		roundf(centro.y + (FONTE.get_ascent(tam) - FONTE.get_descent(tam)) * 0.5))}


## O átomo: o núcleo (os prótons e nêutrons da arte das partículas — a face
## precisa do "icones" e do "pedacos" das PaginasCaderno), os anéis das
## camadas e os elétrons em cada um.
##   "protons", "neutrons"   quantos de cada no núcleo
##   "camadas"   quantos elétrons em cada camada, de dentro para fora
##   "raios"     o raio de cada anel (px)
##   "angulos"   onde fica o primeiro elétron de cada camada (graus; 0 = à
##               direita, e cresce no sentido do relógio); os outros se
##               espalham por igual
##   "marcas"    as do desenho (ver _marca), com "parte" no lugar do "de":
##               "nucleo", "camada0", "camada1"... (a beira do anel, do lado
##               do rumo) ou "eletron" (o primeiro elétron da camada de fora)
func _desenho_atomo(bloco: Dictionary) -> Array:
	var itens: Array = []
	var arte: Texture2D = dados.get("icones")
	var pedacos: Dictionary = dados.get("pedacos", {})
	var raios: Array = bloco.get("raios", [])
	var camadas: Array = bloco.get("camadas", [])
	var angulos: Array = bloco.get("angulos", [])
	for raio in raios:
		itens.append_array(_anel(Vector2.ZERO, float(raio), TINTA, PX_ATOMO))

	# O núcleo: prótons e nêutrons alternados num cacho redondo, os de fora
	# desenhados primeiro (os do meio ficam por cima).
	var protons := int(bloco.get("protons", 0))
	var neutrons := int(bloco.get("neutrons", 0))
	var total := protons + neutrons
	var tipos: Array[String] = []
	for i in total:
		var proton := protons > 0 and (i % 2 == 0 or neutrons == 0)
		tipos.append("próton" if proton else "nêutron")
		if proton:
			protons -= 1
		else:
			neutrons -= 1
	var raio_do_nucleo := 0.0
	for i in range(total - 1, -1, -1):
		var onde := Vector2.from_angle(i * ANGULO_DE_OURO) * PASSO_DO_NUCLEO * sqrt(i + 0.5) \
			if total > 1 else Vector2.ZERO
		if arte != null and pedacos.has(tipos[i]):
			var particula := _particula(arte, pedacos[tipos[i]], onde)
			itens.append(particula)
			raio_do_nucleo = maxf(raio_do_nucleo, onde.length() + particula["rect"].size.x * 0.5)

	var primeiro_de_fora := Vector2.ZERO
	for c in camadas.size():
		var raio: float = raios[c] if c < raios.size() else 0.0
		var giro := deg_to_rad(float(angulos[c]) if c < angulos.size() else 0.0)
		var quantos := int(camadas[c])
		for e in quantos:
			var onde := Vector2.from_angle(giro + e * TAU / quantos) * raio
			if c == camadas.size() - 1 and e == 0:
				primeiro_de_fora = onde
			if arte != null and pedacos.has("elétron"):
				itens.append(_particula(arte, pedacos["elétron"], onde))

	# A tinta (de onde os traços das marcas passam): o anel de fora com os
	# elétrons em cima dele.
	var fora := (float(raios[-1]) if not raios.is_empty() else raio_do_nucleo) + 10.0
	var tinta := Rect2(-fora, -fora, fora * 2.0, fora * 2.0)
	var meio_eletron := 0.0
	if pedacos.has("elétron"):
		meio_eletron = pedacos["elétron"].size.y * ESCALA_PARTICULA * 0.5
	for marca: Dictionary in bloco.get("marcas", []):
		var rumo := String(marca["rumo"])
		var direcao: Vector2 = {"cima": Vector2.UP, "baixo": Vector2.DOWN,
			"esquerda": Vector2.LEFT}.get(rumo, Vector2.RIGHT)
		var parte := String(marca.get("parte", ""))
		var de := Vector2.ZERO
		if parte == "nucleo":
			de = direcao * raio_do_nucleo
		elif parte == "eletron":
			de = primeiro_de_fora + direcao * meio_eletron
		elif parte.begins_with("camada") and int(parte.trim_prefix("camada")) < raios.size():
			de = direcao * (float(raios[int(parte.trim_prefix("camada"))]) + PX_ATOMO * 0.5)
		var com_de := marca.duplicate()
		com_de["de"] = de
		itens.append_array(_marca(com_de, 1.0, tinta))
	return itens


## Os átomos de uma molécula em volta do meio dela: [elemento, onde].
static func _atomos_da_molecula(formula: String) -> Array:
	match formula:
		"H₂":
			return [["H", Vector2(-6, 0)], ["H", Vector2(6, 0)]]
		"O₂":
			return [["O", Vector2(-8, 0)], ["O", Vector2(8, 0)]]
		"H₂O":
			return [["O", Vector2(0, -3)], ["H", Vector2(-11, 5)], ["H", Vector2(11, 5)]]
	return []


## "quantas" moléculas da fórmula lado a lado, com o meio do conjunto em
## "centro". Cada átomo é um disco com contorno; os contornos vão todos antes
## dos miolos, então os átomos de uma molécula se emendam num contorno só.
static func _desenho_moleculas(formula: String, quantas: int, centro: Vector2) -> Array:
	var atomos := _atomos_da_molecula(formula)
	if atomos.is_empty() or quantas <= 0:
		return []
	var esquerda := INF
	var direita := -INF
	for atomo in atomos:
		var raio := RAIO_O if atomo[0] == "O" else RAIO_H
		esquerda = minf(esquerda, atomo[1].x - raio)
		direita = maxf(direita, atomo[1].x + raio)
	var largura := direita - esquerda
	var folga := 6.0
	var inicio := centro.x - (largura * quantas + folga * (quantas - 1)) * 0.5 - esquerda
	var contornos: Array = []
	var miolos: Array = []
	for m in quantas:
		var meio := Vector2(roundf(inicio + m * (largura + folga)), centro.y)
		for atomo in atomos:
			var raio := RAIO_O if atomo[0] == "O" else RAIO_H
			contornos.append_array(_disco(meio + atomo[1], raio, TINTA))
			miolos.append_array(_disco(meio + atomo[1], raio - TRACO,
				TINTA_TITULO if atomo[0] == "O" else PAPEL))
	return contornos + miolos


## A equação escrita (na letra das fórmulas), com as moléculas de cada termo
## desenhadas embaixo dele e o nome de cada lado da seta embaixo de tudo.
##   "termos"  [coeficiente, fórmula] de cada substância ("" = 1) e, entre
##             elas, o texto dos sinais ("+", "→")
##   "lados"   [o nome do lado de antes da seta, o do lado de depois]
func _desenho_equacao(bloco: Dictionary) -> Array:
	var itens: Array = []
	var espaco := _largura(" ", TAM_FORMULA)
	var base := FONTE.get_ascent(TAM_FORMULA)
	var y_moleculas := base + FONTE.get_descent(TAM_FORMULA) + RAIO_O + 12.0
	var x := 0.0
	var lado := 0
	var lados := [[INF, -INF], [INF, -INF]]
	for termo in bloco.get("termos", []):
		if x > 0.0:
			x += espaco
		if termo is String:
			itens.append({"texto": termo, "pos": Vector2(x, base), "tam": TAM_FORMULA, "cor": TINTA_TITULO})
			x += _largura(termo, TAM_FORMULA)
			if termo == "→":
				lado = 1
			continue
		var coeficiente := String(termo[0])
		var formula := String(termo[1])
		var texto := formula if coeficiente.is_empty() else coeficiente + " " + formula
		var largura := _largura(texto, TAM_FORMULA)
		itens.append({"texto": texto, "pos": Vector2(x, base), "tam": TAM_FORMULA, "cor": TINTA_TITULO})
		itens.append_array(_desenho_moleculas(formula, 1 if coeficiente.is_empty() else int(coeficiente),
			Vector2(x + largura * 0.5, y_moleculas)))
		lados[lado][0] = minf(lados[lado][0], x)
		lados[lado][1] = maxf(lados[lado][1], x + largura)
		x += largura
	var nomes: Array = bloco.get("lados", [])
	var meio_dos_nomes := y_moleculas + RAIO_O + 22.0
	for i in mini(nomes.size(), 2):
		if lados[i][0] != INF:
			itens.append(_texto_no_meio(String(nomes[i]),
				Vector2((lados[i][0] + lados[i][1]) * 0.5, meio_dos_nomes), TAM_TEXTO, TINTA_FRACA))
	return itens


## Uma fórmula grande (na letra do título) com um traço até o nome de cada
## parte, como nos desenhos: "marcas" do jeito de sempre (ver _marca), com
## "parte" no lugar do "de" — "coeficiente" (o número da frente) ou "indice"
## (o primeiro índice da fórmula).
func _desenho_formula_anotada(bloco: Dictionary) -> Array:
	var formula := String(bloco.get("formula", ""))
	var base := FONTE.get_ascent(TAM_TITULO)
	var itens: Array = [{"texto": formula, "pos": Vector2(0, base), "tam": TAM_TITULO, "cor": TINTA_TITULO}]
	var letra := caixa_do_texto(itens[0])
	var tam_indice := _tam_do_indice(TAM_TITULO)
	var desce := _descida_do_indice(TAM_TITULO)
	# O índice: depois de tudo o que vem antes dele.
	var x_indice := 0.0
	var largura_indice := 0.0
	for i in formula.length():
		if _e_indice(formula.unicode_at(i)):
			x_indice = _largura(formula.substr(0, i), TAM_TITULO)
			largura_indice = _largura(formula[i], TAM_TITULO)
			break
	var tinta := letra.grow_individual(0.0, 0.0, 0.0, desce)
	var largura_coeficiente := _largura(formula.get_slice(" ", 0), TAM_TITULO)
	for marca: Dictionary in bloco.get("marcas", []):
		var em_cima := String(marca["rumo"]) == "cima"
		var com_de := marca.duplicate()
		if String(marca.get("parte", "")) == "indice":
			com_de["de"] = Vector2(x_indice + largura_indice * 0.5, base + desce
				+ (-FONTE.get_ascent(tam_indice) if em_cima else FONTE.get_descent(tam_indice)))
		else:
			com_de["de"] = Vector2(largura_coeficiente * 0.5, letra.position.y if em_cima else base)
		itens.append_array(_marca(com_de, 1.0, tinta))
	return itens


## O gás no cilindro, duas vezes, com uma seta entre os dois: à esquerda o
## êmbolo em cima (muito volume), à direita o êmbolo descido (pouco volume),
## com as mesmas moléculas. Embaixo, uma tabelinha: cada linha da "legendas"
## é [o do cilindro da esquerda, o nome da linha (no meio, mais fraco), o do
## cilindro da direita].
func _desenho_embolos(bloco: Dictionary) -> Array:
	var itens: Array = []
	var distancia := CILINDRO.x + 124.0
	for i in 2:
		itens.append_array(_cilindro((i - 0.5) * distancia, CILINDRO.y * (0.8 if i == 0 else 0.38)))
	itens.append(_texto_no_meio("→", Vector2(0, CILINDRO.y * 0.55), TAM_FORMULA, TINTA_TITULO))
	var legendas: Array = bloco.get("legendas", [])
	for j in legendas.size():
		var y := CILINDRO.y + 30.0 + ENTRELINHA * j
		var linha: Array = legendas[j]
		for k in mini(linha.size(), 3):
			itens.append(_texto_no_meio(String(linha[k]), Vector2((k - 1) * distancia * 0.5, y),
				TAM_TEXTO, TINTA_FRACA if k == 1 else TINTA_TITULO))
	return itens


## Um cilindro com a boca em y = 0 e o meio em "x": as paredes e o fundo, o
## êmbolo descido até sobrar "altura_do_gas" embaixo dele (com a haste e o
## puxador) e as moléculas espalhadas pelo gás.
static func _cilindro(x: float, altura_do_gas: float) -> Array:
	var itens: Array = []
	var esquerda := roundf(x - CILINDRO.x * 0.5)
	itens.append({"traco": Rect2(esquerda - TRACO, 0, TRACO, CILINDRO.y + TRACO), "cor": TINTA})
	itens.append({"traco": Rect2(esquerda + CILINDRO.x, 0, TRACO, CILINDRO.y + TRACO), "cor": TINTA})
	itens.append({"traco": Rect2(esquerda - TRACO, CILINDRO.y, CILINDRO.x + TRACO * 2.0, TRACO), "cor": TINTA})
	var embolo := roundf(CILINDRO.y - altura_do_gas)
	itens.append({"traco": Rect2(esquerda, embolo - GROSSURA_DO_EMBOLO, CILINDRO.x, GROSSURA_DO_EMBOLO),
		"cor": TINTA})
	var topo_da_haste := -28.0
	itens.append({"traco": Rect2(roundf(x) - 3.0, topo_da_haste, 6.0, embolo - GROSSURA_DO_EMBOLO - topo_da_haste),
		"cor": TINTA})
	itens.append({"traco": Rect2(roundf(x) - 22.0, topo_da_haste - 6.0, 44.0, 6.0), "cor": TINTA})
	var folga := RAIO_MOLECULA_DO_AR + 4.0
	for onde: Vector2 in MOLECULAS_NO_CILINDRO:
		var centro := Vector2(esquerda + folga + onde.x * (CILINDRO.x - folga * 2.0),
			embolo + folga + onde.y * (altura_do_gas - folga * 2.0)).round()
		itens.append_array(_disco(centro, RAIO_MOLECULA_DO_AR, TINTA_TITULO))
	return itens


## Um termômetro em pé, da temperatura "de" (logo acima do bulbo) até "ate"
## (no topo), cheio até o "nivel". Em cada temperatura das "marcas" ({"t",
## "texto", "fraca"}): os graus à esquerda do tubo, com um risco até ele, e o
## texto à direita. (Com o risco do lado dos graus, "-183 °C" não vira
## "- -183".)
func _desenho_termometro(bloco: Dictionary) -> Array:
	var itens: Array = []
	var de := float(bloco.get("de", -200.0))
	var ate := float(bloco.get("ate", -180.0))
	var escala := ALTURA_DO_TERMOMETRO / maxf(ate - de, 1.0)
	var meia := LARGURA_DO_TUBO * 0.5
	var topo := -ALTURA_DO_TERMOMETRO - 12.0
	var bulbo := Vector2(0, RAIO_DO_BULBO + 2.0)
	itens.append_array(_disco(bulbo, RAIO_DO_BULBO + TRACO, TINTA))
	itens.append({"traco": Rect2(-meia - TRACO, topo, TRACO, -topo + 4.0), "cor": TINTA})
	itens.append({"traco": Rect2(meia, topo, TRACO, -topo + 4.0), "cor": TINTA})
	itens.append({"traco": Rect2(-meia - TRACO, topo - TRACO, LARGURA_DO_TUBO + TRACO * 2.0, TRACO),
		"cor": TINTA})
	itens.append_array(_disco(bulbo, RAIO_DO_BULBO - TRACO, TINTA_TITULO))
	var nivel := roundf(-(float(bloco.get("nivel", de)) - de) * escala)
	itens.append({"traco": Rect2(-meia + 3.0, nivel, LARGURA_DO_TUBO - 6.0, bulbo.y - nivel),
		"cor": TINTA_TITULO})

	var meio_da_letra := (FONTE.get_ascent(TAM_TEXTO) - FONTE.get_descent(TAM_TEXTO)) * 0.5
	var fim_do_risco := -meia - TRACO - 3.0
	var fim_dos_graus := fim_do_risco - 10.0 - 6.0
	for marca: Dictionary in bloco.get("marcas", []):
		var y := roundf(-(float(marca["t"]) - de) * escala)
		var fraca: bool = marca.get("fraca", false)
		var graus := _graus(float(marca["t"]))
		itens.append({"traco": Rect2(fim_do_risco - 10.0, y - TRACO * 0.5, 10.0, TRACO),
			"cor": TINTA_FRACA if fraca else TINTA})
		itens.append({"texto": graus, "tam": TAM_TEXTO, "cor": TINTA_FRACA if fraca else TINTA,
			"pos": Vector2(roundf(fim_dos_graus - _largura(graus, TAM_TEXTO)), roundf(y + meio_da_letra))})
		itens.append({"texto": String(marca["texto"]), "tam": TAM_TEXTO,
			"cor": TINTA_FRACA if fraca else TINTA_TITULO,
			"pos": Vector2(meia + TRACO + 12.0, roundf(y + meio_da_letra))})
	return itens


static func _graus(t: float) -> String:
	return "%d °C" % roundi(t)


## Leva os itens montados em (0, 0) para o lugar deles na face.
static func _mover(itens: Array, desvio: Vector2) -> void:
	for item in itens:
		for chave in ["rect", "tinta", "traco", "limite"]:
			if item.has(chave):
				item[chave] = Rect2(item[chave].position + desvio, item[chave].size)
		if item.has("pos"):
			item["pos"] = (item["pos"] + desvio).round()


static func _largura(texto: String, tamanho: int) -> float:
	if not _tem_indice(texto):
		return FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
	var largura := 0.0
	for pedaco in _pedacos_de_indice(texto):
		largura += FONTE.get_string_size(pedaco[0], HORIZONTAL_ALIGNMENT_LEFT, -1,
			_tam_do_indice(tamanho) if pedaco[1] else tamanho).x
	return largura


# ─────────────────────────────────────────────────────────────
# ÍNDICES (o 2 de H₂O)
# ─────────────────────────────────────────────────────────────

static func _e_indice(codigo: int) -> bool:
	return codigo >= PRIMEIRO_INDICE and codigo <= PRIMEIRO_INDICE + 9


static func _tem_indice(texto: String) -> bool:
	for i in texto.length():
		if _e_indice(texto.unicode_at(i)):
			return true
	return false


## "H₂O" -> [["H", false], ["2", true], ["O", false]]. O true é índice.
static func _pedacos_de_indice(texto: String) -> Array:
	var pedacos: Array = []
	var atual := ""
	var atual_indice := false
	for i in texto.length():
		var codigo := texto.unicode_at(i)
		var indice := _e_indice(codigo)
		if indice != atual_indice and not atual.is_empty():
			pedacos.append([atual, atual_indice])
			atual = ""
		atual += String.chr(codigo - PRIMEIRO_INDICE + 48) if indice else texto[i]
		atual_indice = indice
	if not atual.is_empty():
		pedacos.append([atual, atual_indice])
	return pedacos


## A letra do índice: 11 px menor, para continuar na grade da fonte (a 22 fica
## na 11; a 33, na 22).
static func _tam_do_indice(tamanho: int) -> int:
	return maxi(TAM_NOME, tamanho - 11)


## Quanto a linha de base do índice desce da linha do texto.
static func _descida_do_indice(tamanho: int) -> float:
	return roundf(tamanho * 0.25)


## O texto com índice vira um pedaço por trecho, cada um com a letra e a linha
## de base dele, já no lugar. A ordem dos itens não muda (o número da página
## continua o último).
static func _separar_indices(itens: Array) -> Array:
	var saida: Array = []
	for item in itens:
		if not item.has("texto") or not _tem_indice(item["texto"]):
			saida.append(item)
			continue
		var x: float = item["pos"].x
		for pedaco in _pedacos_de_indice(item["texto"]):
			var tam: int = _tam_do_indice(item["tam"]) if pedaco[1] else item["tam"]
			var parte: Dictionary = item.duplicate()
			parte["texto"] = pedaco[0]
			parte["tam"] = tam
			parte["pos"] = Vector2(x, item["pos"].y
				+ (_descida_do_indice(item["tam"]) if pedaco[1] else 0.0))
			saida.append(parte)
			x += FONTE.get_string_size(pedaco[0], HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	return saida
