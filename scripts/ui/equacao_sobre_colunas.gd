extends RefCounted

# --- A EQUAÇÃO ESCRITA EM CIMA DOS DESENHOS ---
#
# Nos puzzles de balanceamento que desenham as moléculas (o do foguete, o do
# maçarico e os níveis fácil e médio do Laboratório), a equação química fica
# logo acima dos desenhos, e cada termo dela ("2 H₂O") fica centrado em cima da
# coluna da molécula que ele representa. O "+" e a seta ficam em cima dos vãos.
# Assim o olho liga a fórmula escrita ao desenho que está embaixo dela.
#
# (A contagem dos átomos — "Reagentes: H = 4  O = 2" — mora acima da equação.)
#
# Este arquivo não tem class_name: quem usa faz
#     const EquacaoSobreColunas := preload("res://scripts/ui/equacao_sobre_colunas.gd")
#
# COMO USAR: monte a lista de PEÇAS, na ordem da equação, e chame escrever().
#   termo("2", "H2O", x)     o coeficiente (ou "?"), a fórmula e o x do MEIO da
#                            coluna do desenho
#   operador("+", x)         "+" ou "→", com o x do meio do vão entre as duas
#                            colunas (entre dois vizinhos escritos, ele se
#                            ajeita no meio do vão entre as LETRAS deles)
#   solto("+ Energia", x)    um texto qualquer, começando em x
# Os x são medidos dentro do nó em que a equação é escrita (a "linha"): quando a
# coluna é um nó da cena, x_do_meio() faz a conta.
#
# A LETRA é uma só para a linha inteira: tamanho_que_cabe() acha a maior em que
# nenhum termo passa da largura que a coluna dele tem.
#
# A "linha" é um Control comum (não um container): cada peça é uma caixinha
# posta no lugar. Os índices das fórmulas são letras de verdade, menores e
# apoiadas no pé da linha.

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

const TIPO_TERMO := "termo"
const TIPO_OPERADOR := "operador"
const TIPO_SOLTO := "solto"

## Quanto do tamanho da letra têm os índices das fórmulas (o 2 de H₂O).
const PROPORCAO_DO_INDICE := 0.36


# ─────────────────────────────────────────────────────────────
# AS PEÇAS
# ─────────────────────────────────────────────────────────────

## Um termo da equação: o coeficiente como se escreve ("2", "?" ou "" para não
## escrever nenhum), a fórmula ("H2O") e o x do meio da coluna do desenho dele.
static func termo(coeficiente: String, formula: String, centro: float) -> Dictionary:
	return {"tipo": TIPO_TERMO, "coeficiente": coeficiente, "formula": formula, "centro": centro}


## O "+" entre dois termos, ou a seta ("->" e "→" dão no mesmo) entre os dois
## lados, com o x do meio do vão.
static func operador(texto: String, centro: float) -> Dictionary:
	return {"tipo": TIPO_OPERADOR, "texto": "→" if texto == "->" else texto, "centro": centro}


## Um texto que não é coluna nem operador ("+ Energia"), começando em "esquerda".
static func solto(texto: String, esquerda: float) -> Dictionary:
	return {"tipo": TIPO_SOLTO, "texto": texto, "esquerda": esquerda}


## O x do meio de "no", medido dentro de "linha" — para pôr um termo em cima de
## uma coluna que é um nó da cena. Os dois precisam estar na árvore.
static func x_do_meio(linha: Control, no: Control) -> float:
	return (linha.get_global_transform().affine_inverse() * no.get_global_rect().get_center()).x


## O x do lado esquerdo de "no", medido dentro de "linha".
static func x_da_esquerda(linha: Control, no: Control) -> float:
	return (linha.get_global_transform().affine_inverse() * no.get_global_rect().position).x


# ─────────────────────────────────────────────────────────────
# ESCREVER
# ─────────────────────────────────────────────────────────────

## Apaga o que estava em "linha" e escreve as peças, na cor e no tamanho dados.
## "indice" é o tamanho da letra dos índices das fórmulas (0 = a proporção de
## sempre, ver tamanho_do_indice).
static func escrever(linha: Control, pecas: Array, cor: Color, tamanho: int, indice: int = 0) -> void:
	for filho in linha.get_children():
		filho.free()
	if indice <= 0:
		indice = tamanho_do_indice(tamanho)
	linha.set_meta("tamanho", tamanho)
	linha.set_meta("cor", cor)

	var lugares := _lugares(pecas, tamanho, indice)
	var n_termos := 0
	var n_outras := 0
	for i in pecas.size():
		var peca: Dictionary = pecas[i]
		var caixa := HBoxContainer.new()
		caixa.add_theme_constant_override("separation", 0)
		caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caixa.set_meta("tipo", peca["tipo"])
		match peca["tipo"]:
			TIPO_TERMO:
				caixa.name = "Termo%d" % n_termos
				n_termos += 1
				var coeficiente := String(peca["coeficiente"])
				if coeficiente != "":
					_por_letra(caixa, coeficiente + " ", false, cor, tamanho)
				for pedaco: Array in pedacos(String(peca["formula"])):
					_por_letra(caixa, pedaco[0], pedaco[1], cor, indice if pedaco[1] else tamanho)
			TIPO_OPERADOR:
				caixa.name = "Operador%d" % n_outras
				n_outras += 1
				_por_letra(caixa, String(peca["texto"]), false, cor, tamanho)
			_:
				caixa.name = "Solto%d" % n_outras
				n_outras += 1
				_por_letra(caixa, String(peca["texto"]), false, cor, tamanho)
		linha.add_child(caixa)
		var lugar: Vector2 = lugares[i]
		# Em px inteiros: letra de pixel em meio pixel fica borrada.
		caixa.position = Vector2(roundf(lugar.x), 0.0)
		caixa.size = Vector2(ceilf(lugar.y), linha.size.y)


## Onde cada peça fica na linha: Vector2(esquerda, largura), na ordem delas.
##
## O termo fica centrado na coluna dele, e o texto solto começa onde foi pedido.
## O operador ("+", "→") fica no meio do VÃO ENTRE AS LETRAS dos dois vizinhos,
## e não no meio do vão entre as colunas: com um termo largo de um lado e um
## estreito do outro ("C₂H₂ + O₂"), no meio das colunas ele ficaria encostado
## no largo. Sem vizinho de um dos lados, vale o "centro" da própria peça.
static func _lugares(pecas: Array, tamanho: int, indice: int) -> Array:
	var lugares: Array = []
	for peca: Dictionary in pecas:
		var largura := largura_da_peca(peca, tamanho, indice)
		match peca["tipo"]:
			TIPO_SOLTO:
				lugares.append(Vector2(float(peca["esquerda"]), largura))
			_:
				lugares.append(Vector2(float(peca["centro"]) - largura * 0.5, largura))
	for i in pecas.size():
		if pecas[i]["tipo"] != TIPO_OPERADOR or i == 0 or i == pecas.size() - 1:
			continue
		if pecas[i - 1]["tipo"] == TIPO_OPERADOR or pecas[i + 1]["tipo"] == TIPO_OPERADOR:
			continue
		var fim_do_anterior: float = lugares[i - 1].x + lugares[i - 1].y
		var comeco_do_seguinte: float = lugares[i + 1].x
		var largura: float = lugares[i].y
		lugares[i] = Vector2((fim_do_anterior + comeco_do_seguinte - largura) * 0.5, largura)
	return lugares


## A maior letra, de "maxima" para baixo (de 2 em 2, até "minima"), em que todo
## termo cabe em "largura_do_termo" — o espaço que a coluna dele tem.
static func tamanho_que_cabe(pecas: Array, largura_do_termo: float, maxima: int, minima: int) -> int:
	var tamanho := maxima
	while tamanho > minima and _termo_mais_largo(pecas, tamanho) > largura_do_termo:
		tamanho -= 2
	return maxi(tamanho, minima)


static func _termo_mais_largo(pecas: Array, tamanho: int) -> float:
	var maior := 0.0
	for peca: Dictionary in pecas:
		if peca["tipo"] == TIPO_TERMO:
			maior = maxf(maior, largura_da_peca(peca, tamanho, tamanho_do_indice(tamanho)))
	return maior


## A largura que a peça ocupa escrita nesta letra.
static func largura_da_peca(peca: Dictionary, tamanho: int, indice: int = 0) -> float:
	if indice <= 0:
		indice = tamanho_do_indice(tamanho)
	if peca["tipo"] != TIPO_TERMO:
		return _medir(String(peca["texto"]), tamanho)
	var largura := 0.0
	var coeficiente := String(peca["coeficiente"])
	if coeficiente != "":
		largura += _medir(coeficiente + " ", tamanho)
	for pedaco: Array in pedacos(String(peca["formula"])):
		largura += _medir(pedaco[0], indice if pedaco[1] else tamanho)
	return largura


## O tamanho da letra dos índices de uma fórmula escrita na letra "tamanho".
static func tamanho_do_indice(tamanho: int) -> int:
	return maxi(8, roundi(tamanho * PROPORCAO_DO_INDICE))


## A fórmula em pedaços para escrever: [[texto, é índice], ...]. "C2H2" vira
## [["C", false], ["2", true], ["H", false], ["2", true]].
static func pedacos(formula: String) -> Array:
	var lista: Array = []
	var atual := ""
	var numero := false
	for letra in formula:
		var e_numero := letra.is_valid_int()
		if atual != "" and e_numero != numero:
			lista.append([atual, numero])
			atual = ""
		atual += letra
		numero = e_numero
	if atual != "":
		lista.append([atual, numero])
	return lista


static func _medir(texto: String, tamanho: int) -> float:
	return FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x


static func _por_letra(caixa: HBoxContainer, texto: String, e_indice: bool, cor: Color, tamanho: int) -> void:
	var letra := Label.new()
	letra.text = texto
	letra.add_theme_font_override("font", FONTE)
	letra.add_theme_font_size_override("font_size", tamanho)
	letra.add_theme_color_override("font_color", cor)
	# O índice se apoia no pé da linha; o resto fica no meio dela.
	letra.size_flags_vertical = Control.SIZE_SHRINK_END if e_indice else Control.SIZE_SHRINK_CENTER
	letra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letra.set_meta("indice", e_indice)
	caixa.add_child(letra)


# ─────────────────────────────────────────────────────────────
# PERGUNTAS (para o tutorial, que acende um termo, e para os testes)
# ─────────────────────────────────────────────────────────────

## Quantos termos estão escritos na linha.
static func quantos_termos(linha: Control) -> int:
	var conta := 0
	for caixa in linha.get_children():
		if caixa.get_meta("tipo", "") == TIPO_TERMO:
			conta += 1
	return conta


## A caixinha do termo "i" (de 0 em diante), ou null.
static func caixa_do_termo(linha: Control, i: int) -> Control:
	return linha.get_node_or_null("Termo%d" % i) as Control


## Onde o termo "i" está escrito, na tela: justo em volta das letras dele.
static func retangulo_do_termo(linha: Control, i: int) -> Rect2:
	var caixa := caixa_do_termo(linha, i)
	if caixa == null:
		return Rect2()
	var total := Rect2()
	for letra: Control in caixa.get_children():
		var onde := letra.get_global_rect()
		total = onde if total.size == Vector2.ZERO else total.merge(onde)
	return total


## O x do meio do termo "i", na tela.
static func meio_do_termo(linha: Control, i: int) -> float:
	var caixa := caixa_do_termo(linha, i)
	return caixa.get_global_rect().get_center().x if caixa != null else 0.0


## A equação como texto corrido, peça por peça, separadas por um espaço:
## "2 H2 + ? O2 → ? H2O".
static func texto(linha: Control) -> String:
	var partes := PackedStringArray()
	for caixa in linha.get_children():
		var parte := ""
		for letra: Label in caixa.get_children():
			parte += letra.text
		partes.append(parte.strip_edges())
	return " ".join(partes)


## A cor em que a linha foi escrita por último.
static func cor(linha: Control) -> Color:
	return linha.get_meta("cor", Color.WHITE)


## O tamanho da letra em que a linha foi escrita por último.
static func tamanho(linha: Control) -> int:
	return int(linha.get_meta("tamanho", 0))


## Onde a linha escrita começa e acaba (x), dentro dela mesma: para conferir
## que nada sai da tela.
static func extensao(linha: Control) -> Vector2:
	var de := INF
	var ate := -INF
	for caixa: Control in linha.get_children():
		de = minf(de, caixa.position.x)
		ate = maxf(ate, caixa.position.x + caixa.size.x)
	return Vector2(de, ate) if de <= ate else Vector2.ZERO


## Nenhuma peça por cima da vizinha? Devolve a menor folga entre duas peças
## seguidas (negativa = uma cobre a outra).
static func menor_folga(linha: Control) -> float:
	var caixas: Array = linha.get_children()
	var folga := INF
	for i in range(1, caixas.size()):
		var antes := caixas[i - 1] as Control
		var depois := caixas[i] as Control
		folga = minf(folga, depois.position.x - (antes.position.x + antes.size.x))
	return folga
