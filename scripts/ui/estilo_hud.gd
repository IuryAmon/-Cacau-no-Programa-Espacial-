class_name EstiloHUD
extends RefCounted

# --- A LINGUAGEM VISUAL DA INTERFACE (paleta + traços compartilhados) ---
#
# O jogo já tinha um jeito de desenhar HUD, inventado no hud_vital.gd: vidro
# escuro azulado, contorno frio de um fio só, fio de luz no topo, acento
# colorido na base, hexágono para "isto guarda alguma coisa/alguém" e texto em
# caixa alta com espaçamento largo. O que faltava era esse jeito morar em um
# lugar só, em vez de ser recopiado a cada tela nova.
#
# É isto aqui. O popup de coleta e a mochila do canto superior direito são
# desenhados INTEIROS com estas funções — por isso os dois parecem a mesma
# peça de equipamento, e por isso mudar uma cor aqui muda os dois de uma vez.
#
# Nada nesta classe conhece popup, mochila ou item: são só formas e cores.


# ─────────────────────────────────────────────────────────────
# PALETA
# ─────────────────────────────────────────────────────────────
# Os mesmos valores do hud_vital.gd — é o que garante que as três peças
# (barra de vida, popup, mochila) sejam lidas como um único aparelho.

const VIDRO_TOPO := Color(0.086, 0.110, 0.180, 0.94)
const VIDRO_BASE := Color(0.027, 0.036, 0.066, 0.96)
## Fundo do alvéolo vazio: mais escuro que o vidro, para o slot parecer furo.
const ALVEOLO := Color(0.055, 0.070, 0.115, 0.88)
const BORDA := Color(0.64, 0.80, 1.0, 0.22)
const FIO_LUZ := Color(0.85, 0.93, 1.0, 0.30)
const TEXTO := Color(0.90, 0.95, 1.0, 0.95)
const TEXTO_FRACO := Color(0.56, 0.69, 0.88, 0.60)
const SOMBRA := Color(0.0, 0.0, 0.0, 0.40)
## Véu que apaga o cenário atrás do popup.
const VEU := Color(0.016, 0.024, 0.050, 0.72)

## Acento de quem não tem cor própria (item comum de laboratório).
const ACENTO_PADRAO := Color(0.42, 0.72, 1.0)


# ─────────────────────────────────────────────────────────────
# IDENTIDADE DE CADA ITEM
# ─────────────────────────────────────────────────────────────

## Cor de destaque do item: anel do medalhão, fio da base, faíscas, anel do
## slot na mochila. Ferramenta pega a cor da própria ficha no catálogo; o
## resto está listado aqui.
##
## O carvão é o caso que exigiu decisão de design: fuligem é preta, e preto
## não funciona como acento sobre vidro preto — some. Ele fica com o laranja
## da brasa que o produziu, que é o que a pessoa acabou de ver na retorta.
static func cor_do_item(id: String) -> Color:
	if CatalogoFerramentas.FERRAMENTAS.has(id):
		return CatalogoFerramentas.cor(id)
	match id:
		"Cilindro_de_Hidrogenio":
			return Color(1.0, 0.36, 0.38)
		"Cilindro_Oxigenio":
			return Color(0.36, 0.76, 1.0)
		"carvao_vegetal":
			return Color(0.98, 0.60, 0.28)
	return ACENTO_PADRAO


## Chapéu do popup — a primeira linha, que diz que TIPO de coisa aconteceu.
static func chapeu_do_item(id: String) -> String:
	if CatalogoFerramentas.FERRAMENTAS.has(id):
		return "FERRAMENTA ADQUIRIDA"
	return "ITEM COLETADO"


## Nomes no jogo vêm com a categoria entre parênteses ("Cilindro de Oxigênio
## (Comburente)", "Maçarico Oxídrico (Ferramenta)"). Escrito assim, em uma
## linha só, o parêntese rouba tamanho do nome e o título tem de encolher.
##
## Aqui o nome é separado: o que está fora do parêntese vira TÍTULO grande, e
## o que está dentro vira ETIQUETA pequena ao lado do chapéu. Ninguém precisa
## reescrever nada nas cenas nem no catálogo — a leitura é que melhora.
static func separar_nome(nome: String) -> Dictionary:
	var abre := nome.rfind("(")
	var fecha := nome.rfind(")")
	if abre > 0 and fecha > abre:
		var etiqueta := nome.substr(abre + 1, fecha - abre - 1).strip_edges()
		var titulo := nome.substr(0, abre).strip_edges()
		if not titulo.is_empty():
			return {"titulo": titulo, "etiqueta": etiqueta.to_upper()}
	return {"titulo": nome.strip_edges(), "etiqueta": ""}


# ─────────────────────────────────────────────────────────────
# FORMAS
# ─────────────────────────────────────────────────────────────

## Hexágono de topo plano (largura 2·raio, altura 1,732·raio) — o mesmo do
## medalhão do hud_vital. No popup ele segura o ícone do item; na mochila ele
## é o slot. É essa repetição que faz o voo do ícone parecer encaixe, e não
## teletransporte.
static func hexagono(centro: Vector2, raio: float) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i)
		pontos.append(centro + Vector2(cos(a), sin(a)) * raio)
	return pontos


## Retângulo com os quatro cantos cortados — corte fundo no superior-esquerdo
## e no inferior-direito, corte raso nos outros dois. É a silhueta da ficha do
## popup: retângulo puro parece caixa de diálogo de sistema operacional.
static func chanfro(caixa: Rect2, corte: float, corte_raso: float = -1.0) -> PackedVector2Array:
	var raso := corte_raso if corte_raso >= 0.0 else corte * 0.42
	var x0 := caixa.position.x
	var y0 := caixa.position.y
	var x1 := caixa.end.x
	var y1 := caixa.end.y
	return PackedVector2Array([
		Vector2(x0 + corte, y0),
		Vector2(x1 - raso, y0),
		Vector2(x1, y0 + raso),
		Vector2(x1, y1 - corte),
		Vector2(x1 - corte, y1),
		Vector2(x0 + raso, y1),
		Vector2(x0, y1 - raso),
		Vector2(x0, y0 + corte),
	])


static func fechar(pontos: PackedVector2Array) -> PackedVector2Array:
	var saida := PackedVector2Array(pontos)
	if saida.size() > 0:
		saida.append(saida[0])
	return saida


static func deslocar(pontos: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var saida := PackedVector2Array()
	for p in pontos:
		saida.append(p + d)
	return saida


# ─────────────────────────────────────────────────────────────
# TRAÇOS
# ─────────────────────────────────────────────────────────────

## Vidro: preenchimento com gradiente vertical (mais claro em cima, quase
## preto embaixo). É o gradiente que dá volume — chapado, o painel vira
## adesivo colado na tela.
static func vidro(ci: CanvasItem, poligono: PackedVector2Array, alfa: float = 1.0,
		topo: Color = VIDRO_TOPO, base: Color = VIDRO_BASE) -> void:
	if poligono.size() < 3:
		return
	var y0 := poligono[0].y
	var y1 := y0
	for p in poligono:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var altura := maxf(y1 - y0, 0.001)
	var cores := PackedColorArray()
	for p in poligono:
		cores.append(com_alfa(topo.lerp(base, (p.y - y0) / altura), alfa))
	ci.draw_polygon(poligono, cores)


## Sombra projetada — é o que descola a peça do cenário sem precisar de
## moldura grossa.
static func sombra(ci: CanvasItem, poligono: PackedVector2Array, queda: float = 5.0,
		alfa: float = 1.0) -> void:
	ci.draw_colored_polygon(deslocar(poligono, Vector2(0.0, queda)), com_alfa(SOMBRA, alfa))


## Contorno. Com "progresso" < 1 desenha só o começo do perímetro: é assim que
## a moldura do popup se DESENHA na entrada, como aparelho ligando, em vez de
## a caixa inteira aparecer de uma vez.
static func moldura(ci: CanvasItem, poligono: PackedVector2Array, cor: Color,
		largura: float = 1.5, progresso: float = 1.0) -> void:
	var caminho := fechar(poligono)
	if caminho.size() < 2:
		return
	if progresso >= 1.0:
		ci.draw_polyline(caminho, cor, largura, true)
		return
	var total := 0.0
	for i in caminho.size() - 1:
		total += caminho[i].distance_to(caminho[i + 1])
	var alvo := total * clampf(progresso, 0.0, 1.0)
	if alvo <= 0.0:
		return
	var andado := 0.0
	var parcial := PackedVector2Array([caminho[0]])
	for i in caminho.size() - 1:
		var trecho := caminho[i].distance_to(caminho[i + 1])
		if andado + trecho >= alvo:
			parcial.append(caminho[i].lerp(caminho[i + 1],
				(alvo - andado) / maxf(trecho, 0.001)))
			break
		andado += trecho
		parcial.append(caminho[i + 1])
	if parcial.size() >= 2:
		ci.draw_polyline(parcial, cor, largura, true)


## Halo macio atrás de uma peça: camadas concêntricas de alfa baixo. Sai mais
## barato (e mais controlável) que partícula, e não precisa de material.
static func halo(ci: CanvasItem, centro: Vector2, raio: float, cor: Color,
		camadas: int = 7, forca: float = 1.0) -> void:
	if forca <= 0.0:
		return
	for i in camadas:
		var t := float(i) / float(camadas)
		ci.draw_circle(centro, raio * (0.45 + t * 0.85),
			com_alfa(cor, 0.045 * (1.0 - t) * forca), true, -1.0, true)


static func com_alfa(cor: Color, alfa: float) -> Color:
	return Color(cor.r, cor.g, cor.b, cor.a * clampf(alfa, 0.0, 1.0))


## Tampa de tecla: caixinha chanfrada com a letra dentro. É a MESMA peça no
## rodapé da ficha de coleta ("[E] CONTINUAR") e embaixo de cada ferramenta do
## cinto — é por ela que a pessoa liga "isto na tela" a "aquilo no teclado".
## Devolve a largura desenhada, para quem precisa continuar o texto ao lado.
static func tecla(ci: CanvasItem, f: Font, centro: Vector2, txt: String, cor: Color,
		alfa: float = 1.0, tamanho: int = 15) -> float:
	if f == null or txt.is_empty():
		return 0.0
	var largura_txt := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
	var largura := maxf(largura_txt + 16.0, 30.0)
	var altura := float(tamanho) + 11.0
	var caixa := Rect2(centro - Vector2(largura, altura) * 0.5, Vector2(largura, altura))
	var contorno := chanfro(caixa, 7.0, 3.0)
	ci.draw_colored_polygon(contorno, com_alfa(Color(0.10, 0.14, 0.22, 0.9), alfa))
	moldura(ci, contorno, com_alfa(cor, alfa), 1.5)
	ci.draw_string(f, Vector2(centro.x - largura_txt * 0.5,
			centro.y + f.get_ascent(tamanho) * 0.5 - 1.0),
		txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, com_alfa(TEXTO, alfa))
	return largura


# ─────────────────────────────────────────────────────────────
# ÍCONES (pixel art)
# ─────────────────────────────────────────────────────────────

## A arte do jogo é miúda: 8×17 (bumerangue), 16×16 (cilindros), 26×19
## (carvão), 48×48 (maçarico). Encaixar tudo isso em uma caixa fixa por regra
## de três produz escalas quebradas — e escala quebrada em pixel art vira
## coluna de pixel com o dobro da largura no meio do desenho.
##
## Por isso: acima de 2×, só múltiplo inteiro. Abaixo disso o ajuste fino
## continua valendo, porque a alternativa (cair para 1×) deixaria o item
## visivelmente menor que os vizinhos na fileira da mochila.
static func escala_pixel(textura: Texture2D, caixa: float) -> float:
	if textura == null:
		return 1.0
	var tam := Vector2(textura.get_size())
	var maior := maxf(tam.x, tam.y)
	if maior <= 0.0:
		return 1.0
	var ajuste := caixa / maior
	if ajuste >= 2.0:
		return floorf(ajuste)
	return ajuste


## Desenha o ícone centrado, encaixado na caixa e alinhado ao pixel da tela.
static func icone(ci: CanvasItem, textura: Texture2D, centro: Vector2, caixa: float,
		cor: Color = Color.WHITE, escala_extra: float = 1.0) -> void:
	if textura == null:
		return
	var tam := Vector2(textura.get_size()) * escala_pixel(textura, caixa) * escala_extra
	ci.draw_texture_rect(textura, Rect2((centro - tam * 0.5).round(), tam), false, cor)


# ─────────────────────────────────────────────────────────────
# TIPOGRAFIA
# ─────────────────────────────────────────────────────────────

## draw_string não tem controle de espaçamento entre letras, então o texto vai
## caractere a caractere. É esse "tracking" largo que dá o ar de rótulo gravado
## em painel, e não de legenda.
static func texto(ci: CanvasItem, f: Font, pos: Vector2, txt: String, tamanho: int,
		cor: Color, espaco: float = 0.0) -> void:
	if f == null or txt.is_empty():
		return
	var x := pos.x
	for i in txt.length():
		var c := txt[i]
		ci.draw_string(f, Vector2(x, pos.y), c, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)
		x += f.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x + espaco


static func largura_texto(f: Font, txt: String, tamanho: int, espaco: float = 0.0) -> float:
	if f == null or txt.is_empty():
		return 0.0
	var w := 0.0
	for i in txt.length():
		w += f.get_string_size(txt[i], HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x + espaco
	return maxf(0.0, w - espaco)


## Maior tamanho de fonte (dentro da faixa) em que o texto ainda cabe na
## largura pedida. É o que permite escrever qualquer nome nas cenas sem que a
## ficha do popup estoure nem precise de reajuste no editor.
static func tamanho_que_cabe(f: Font, txt: String, largura: float, espaco: float,
		maximo: int, minimo: int) -> int:
	var tamanho := maximo
	while tamanho > minimo and largura_texto(f, txt, tamanho, espaco) > largura:
		tamanho -= 1
	return tamanho


## Quebra o texto em linhas na mão, em vez de usar draw_multiline_string, para
## que a entrelinha seja escolha de design e não o que a fonte trouxe de
## fábrica — a ari-w9500 é fonte de display e vem apertada demais para
## parágrafo. Respeita as quebras já escritas no texto.
static func quebrar(f: Font, txt: String, tamanho: int, largura: float) -> PackedStringArray:
	var linhas := PackedStringArray()
	if f == null or txt.is_empty():
		return linhas
	for paragrafo in txt.split("\n", false):
		var atual := ""
		for palavra in paragrafo.split(" ", false):
			var teste := palavra if atual.is_empty() else atual + " " + palavra
			if atual.is_empty() or f.get_string_size(teste, HORIZONTAL_ALIGNMENT_LEFT,
					-1, tamanho).x <= largura:
				atual = teste
			else:
				linhas.append(atual)
				atual = palavra
		if not atual.is_empty():
			linhas.append(atual)
	return linhas
