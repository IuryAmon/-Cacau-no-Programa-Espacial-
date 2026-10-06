class_name EstiloHUD
extends RefCounted

# --- A LINGUAGEM VISUAL DA INTERFACE (paleta + traços compartilhados) ---
#
# O HUD é feito do mesmo material do resto do jogo, e não de um aparelho à
# parte colado por cima dele. A peça de que tudo sai é a FICHA: o quadrado da
# caixa de elemento do caderno da Cacau ("Hidrogênio tabela periódica.png"),
# que é papel do caderno, moldura de tinta de um traço só e mais nada. Em volta
# dela valem as regras da arte de interface que o jogo já usa (as teclas, os
# balões de fala):
#
#   * QUADRADO E RETÂNGULO, com o pixel do canto tirado. Nada de hexágono,
#     chanfro ou paralelogramo;
#   * COR CHAPADA. Nada de degradê, de halo nem de vidro: o volume vem de uma
#     sombra dura, deslocada para baixo, como a das teclas;
#   * CONTORNO ESCURO, grosso, que segura a peça tanto no laboratório escuro
#     quanto no céu claro do pátio;
#   * LETRA NO TAMANHO DA FONTE. A ari-w9500 é desenhada em 11 px: 11, 22 e 33
#     são os tamanhos em que cada ponto dela vira um quadrado inteiro na tela.
#
# A vida (hud_vital), os equipamentos (equipamentos_hud), a mochila
# (mochila_hud), a ficha de coleta (popup_item) e o tutorial das ferramentas
# (tutorial_ferramenta) são desenhados INTEIROS com estas funções: mudar uma
# cor aqui muda todos de uma vez.
#
# Nada nesta classe conhece mochila, item ou vida: são só formas e cores.


# ─────────────────────────────────────────────────────────────
# PALETA
# ─────────────────────────────────────────────────────────────
# Tirada da arte do jogo, cor por cor, e não inventada para o HUD.

## A folha do caderno ("Caderno Definitivo.png").
const PAPEL := Color("e7d5b3")
## A dobra da folha: a beirada de baixo de cada ficha.
const PAPEL_DOBRA := Color("d7b594")
## A tinta das caixas de elemento do caderno.
const TINTA := Color("3d2a22")
## A mesma tinta, aguada: o que se lê em segundo lugar numa ficha.
const TINTA_FRACA := Color("6b5443")
## O contorno das teclas e dos balões de fala ("gdb-keyboard-2.png").
const CONTORNO := Color("14182e")
## A letra das teclas: o claro do que é escrito direto em cima do cenário.
const CLARO := Color("f5ffe8")
## A tampa das teclas e a beirada dela, para a tecla que ainda não tem desenho.
const TECLA_TAMPA := Color("a3a7c2")
const TECLA_BEIRA := Color("686f99")
## A casa vazia: um furo escuro, que deixa o cenário aparecer.
const CASA_VAZIA := Color(0.078, 0.094, 0.180, 0.55)
## A sombra dura embaixo de cada ficha.
const SOMBRA_DURA := Color(0.047, 0.055, 0.110, 0.55)
## Véu que apaga o cenário atrás da ficha de coleta e do tutorial.
const VEU := Color(0.047, 0.055, 0.110, 0.74)

# --- Medidas da ficha ---
## Espessura da moldura de tinta (a da caixa de elemento do caderno).
const MOLDURA := 4.0
## O pixel tirado de cada canto.
const CANTO := 2.0
## Quanto a sombra dura cai.
const QUEDA := 4.0

## Acento de quem não tem cor própria (item comum de laboratório).
const ACENTO_PADRAO := Color(0.42, 0.72, 1.0)


# ─────────────────────────────────────────────────────────────
# IDENTIDADE DE CADA ITEM
# ─────────────────────────────────────────────────────────────

## Cor de destaque do item: o clarão da ficha quando ele chega, o rastro do
## voo, a luz do tubo no puzzle do foguete. Ferramenta pega a cor da própria
## ficha no catálogo; o resto está listado aqui.
##
## O carvão fica com o laranja da brasa que o produziu, e não com o preto da
## fuligem: é o que a pessoa acabou de ver na retorta.
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
	# Amostras do CHONPS (N, P, S): a cor do próprio elemento.
	if AmostraChonps.e_amostra(id):
		return AmostraChonps.cor(id.trim_prefix(AmostraChonps.PREFIXO_ID))
	return ACENTO_PADRAO


## Nomes no jogo vêm com a categoria entre parênteses ("Cilindro de Oxigênio
## (Comburente)", "Maçarico Oxídrico (Ferramenta)"). Escrito assim, em uma
## linha só, o parêntese rouba tamanho do nome e o título tem de encolher.
##
## Aqui o nome é separado: o que está fora do parêntese vira TÍTULO, e o que
## está dentro vira ETIQUETA (a linha pequena embaixo do nome, na ficha de
## coleta). Ninguém precisa reescrever nada nas cenas nem no catálogo.
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
# A FICHA
# ─────────────────────────────────────────────────────────────

## Retângulo chapado com o pixel de cada canto tirado: o cantinho das teclas e
## dos balões de fala. Em três faixas que não se cruzam, para uma cor
## transparente não escurecer onde elas se encontrariam.
static func bloco(ci: CanvasItem, r: Rect2, cor: Color, canto: float = CANTO) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0 or cor.a <= 0.0:
		return
	var c := minf(canto, minf(r.size.x, r.size.y) * 0.5)
	if c <= 0.0:
		ci.draw_rect(r, cor)
		return
	ci.draw_rect(Rect2(r.position.x + c, r.position.y, r.size.x - c * 2.0, r.size.y), cor)
	ci.draw_rect(Rect2(r.position.x, r.position.y + c, c, r.size.y - c * 2.0), cor)
	ci.draw_rect(Rect2(r.end.x - c, r.position.y + c, c, r.size.y - c * 2.0), cor)


## Só a moldura do bloco (o aro), com o mesmo canto. Também em faixas que não
## se cruzam.
static func aro(ci: CanvasItem, r: Rect2, cor: Color, espessura: float = MOLDURA,
		canto: float = CANTO) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0 or cor.a <= 0.0:
		return
	var e := minf(espessura, minf(r.size.x, r.size.y) * 0.5)
	var c := minf(canto, e)
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	ci.draw_rect(Rect2(x + c, y, w - c * 2.0, e), cor)
	ci.draw_rect(Rect2(x + c, y + h - e, w - c * 2.0, e), cor)
	ci.draw_rect(Rect2(x, y + e, e, h - e * 2.0), cor)
	ci.draw_rect(Rect2(x + w - e, y + e, e, h - e * 2.0), cor)
	if e > c:
		# Os quatro cantinhos que sobram entre as faixas e o pixel tirado.
		for cx: float in [x, x + w - c]:
			ci.draw_rect(Rect2(cx, y + c, c, e - c), cor)
			ci.draw_rect(Rect2(cx, y + h - e, c, e - c), cor)


## A FICHA: papel do caderno, moldura de tinta e a sombra dura embaixo. É a
## peça de que o HUD inteiro é feito (ver o texto no topo deste arquivo).
static func ficha(ci: CanvasItem, r: Rect2, alfa: float = 1.0, papel: Color = PAPEL,
		tinta: Color = TINTA, moldura_px: float = MOLDURA, queda: float = QUEDA) -> void:
	if alfa <= 0.0:
		return
	if queda > 0.0:
		bloco(ci, Rect2(r.position + Vector2(0.0, queda), r.size), com_alfa(SOMBRA_DURA, alfa))
	bloco(ci, r, com_alfa(tinta, alfa))
	var miolo := r.grow(-moldura_px)
	ci.draw_rect(miolo, com_alfa(papel, alfa))
	# A dobra: a beirada de baixo do papel, um tom abaixo.
	var dobra := minf(moldura_px, miolo.size.y * 0.25)
	ci.draw_rect(Rect2(miolo.position.x, miolo.end.y - dobra, miolo.size.x, dobra),
		com_alfa(PAPEL_DOBRA if papel == PAPEL else papel.darkened(0.09), alfa))


## A casa vazia: o lugar de uma ficha que não está lá. Um furo escuro com o
## aro claro, que aparece em qualquer cenário sem competir com ele.
static func casa_vazia(ci: CanvasItem, r: Rect2, alfa: float = 1.0,
		cor_do_aro: Color = CLARO, forca_do_aro: float = 0.34) -> void:
	if alfa <= 0.0:
		return
	bloco(ci, r, com_alfa(CASA_VAZIA, alfa))
	aro(ci, r, com_alfa(cor_do_aro, alfa * forca_do_aro))


## A BARRA: a faixa escura dos comandos, no pé das telas (o caderno aberto, os
## puzzles). É o contorno das teclas, cheio, com um fio da cor delas por dentro.
static func barra(ci: CanvasItem, r: Rect2, alfa: float = 1.0) -> void:
	if alfa <= 0.0:
		return
	bloco(ci, Rect2(r.position + Vector2(0.0, QUEDA), r.size), com_alfa(SOMBRA_DURA, alfa))
	bloco(ci, r, com_alfa(CONTORNO, alfa))
	aro(ci, r.grow(-2.0), com_alfa(TECLA_BEIRA, alfa), 2.0, 0.0)


## A ETIQUETA: letra clara numa plaquinha escura (o contorno das teclas,
## cheio). É como o HUD dá nome às peças — MOCHILA, EQUIPAMENTOS — e ela se lê
## igual no laboratório escuro e no céu claro do pátio, sem depender do que
## está atrás. "direita_topo" é o canto de cima à direita da plaquinha, que
## cresce para a esquerda com o texto. Devolve o retângulo dela.
static func etiqueta(ci: CanvasItem, f: Font, direita_topo: Vector2, txt: String,
		tamanho: int = 11, alfa: float = 1.0) -> Rect2:
	if f == null or txt.is_empty() or alfa <= 0.0:
		return Rect2(direita_topo, Vector2.ZERO)
	var largura := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
	var placa := Rect2(roundf(direita_topo.x - largura - 12.0), roundf(direita_topo.y),
		largura + 12.0, float(tamanho) + 6.0)
	bloco(ci, placa, com_alfa(CONTORNO, alfa))
	ci.draw_string(f, Vector2(placa.position.x + 6.0,
			placa.position.y + 4.0 + roundf(f.get_ascent(tamanho) * 0.86)),
		txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, com_alfa(CLARO, alfa))
	return placa


## Texto claro com contorno escuro, para escrever DIRETO em cima do cenário
## (o nome e o casco da nave, no simulador): é o mesmo jeito da lista de
## objetivos. Devolve a largura escrita.
static func rotulo(ci: CanvasItem, f: Font, pos: Vector2, txt: String, tamanho: int,
		cor: Color = CLARO, alfa: float = 1.0, contorno: int = -1) -> float:
	if f == null or txt.is_empty() or alfa <= 0.0:
		return 0.0
	# O contorno grosso da lista de objetivos (6 na letra de 11, 8 na de 22).
	var borda := contorno if contorno >= 0 else roundi(4.0 + tamanho * 0.18)
	if borda > 0:
		ci.draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, borda,
			com_alfa(CONTORNO, alfa))
	ci.draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, com_alfa(cor, alfa))
	return f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x


# ─────────────────────────────────────────────────────────────
# POLÍGONOS E LUZ (efeitos de dentro dos puzzles)
# ─────────────────────────────────────────────────────────────
# Não são do HUD: quem desenha com estas é o holofote dos tutoriais de puzzle
# (destaque_tutorial.gd), o contorno do cursor virtual e o pulso de luz da
# mangueira do foguete (cabo_de_dados.gd).

## Retângulo com os quatro cantos cortados — corte fundo no superior-esquerdo
## e no inferior-direito, corte raso nos outros dois.
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


## Contorno de um polígono. Com "progresso" < 1 desenha só o começo do
## perímetro.
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


## Halo macio: camadas concêntricas de alfa baixo. É luz de cenário (o pulso
## que corre pela mangueira), não peça de HUD.
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


# ─────────────────────────────────────────────────────────────
# TECLAS
# ─────────────────────────────────────────────────────────────

## Tampa de tecla com a letra dentro, nas cores das teclas da folha do teclado.
## É o reserva de "tecla_da_acao" para a tecla que ainda não tem desenho lá
## (SHIFT, T, R...). Devolve a largura desenhada, para quem precisa continuar o
## texto ao lado. "_cor" ficou da versão antiga, que contornava a tampa na cor
## da ferramenta: a tampa agora é sempre a das teclas.
static func tecla(ci: CanvasItem, f: Font, centro: Vector2, txt: String,
		_cor: Color = CLARO, alfa: float = 1.0, tamanho: int = 15) -> float:
	if f == null or txt.is_empty():
		return 0.0
	var largura_txt := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
	var largura := maxf(largura_txt + 16.0, 30.0)
	var altura := float(tamanho) + 13.0
	var quadro := Rect2((centro - Vector2(largura, altura) * 0.5).round(),
		Vector2(largura, altura))
	bloco(ci, quadro, com_alfa(CONTORNO, alfa))
	var tampa := quadro.grow(-2.0)
	ci.draw_rect(tampa, com_alfa(TECLA_BEIRA, alfa))
	ci.draw_rect(Rect2(tampa.position, Vector2(tampa.size.x, tampa.size.y - 4.0)),
		com_alfa(TECLA_TAMPA, alfa))
	ci.draw_string(f, Vector2(roundf(centro.x - largura_txt * 0.5),
			roundf(centro.y + f.get_ascent(tamanho) * 0.5 - 4.0)),
		txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, com_alfa(CLARO, alfa))
	return largura


## A tecla de uma ação, do jeito que o resto do jogo a mostra: o desenho da
## folha do teclado (o mesmo E do cenário), afundando em loop — ou, de controle
## na mão, o botão da ação (□), no mesmo lugar. É a MESMA peça no rodapé da
## ficha de coleta, embaixo de cada equipamento e no tutorial: é por ela que a
## pessoa liga "isto na tela" a "aquilo no teclado".
##
## Tecla sem desenho na folha cai na tampa escrita ("tecla").
## Quem chama precisa se redesenhar para a tecla afundar (5 quadros por
## segundo, ver BotoesControle.quadro_atual). Devolve a largura desenhada.
static func tecla_da_acao(ci: CanvasItem, f: Font, centro: Vector2, txt: String,
		acao: StringName, cor: Color, alfa: float = 1.0, tamanho: int = 15) -> float:
	var desenho := desenho_da_tecla(txt, acao)
	if desenho != "":
		var escala := BotoesControle.escala_para(float(tamanho) + 11.0)
		return BotoesControle.desenhar(ci, centro, desenho, escala, com_alfa(Color.WHITE, alfa),
			BotoesControle.quadro_atual())
	return tecla(ci, f, centro, txt, cor, alfa, tamanho)


## A TECLA DE CONTINUAR DAS FOLHAS. As folhas que seguram o jogo (a ficha de
## coleta e o tutorial das ferramentas) mostram a tecla no MESMO lugar: presa
## na beirada de baixo, no canto direito, metade dentro e metade fora. Ali ela
## nunca disputa lugar com o que a folha tem dentro. É o E desenhado, ampliado
## 3 vezes (48 px), afundando em loop; de controle na mão, o □ da mesma ação.
const TAM_TECLA_DA_FOLHA := 25
const LADO_TECLA_DA_FOLHA := 48.0
## Da borda direita da folha até a tecla.
const RECUO_TECLA_DA_FOLHA := 28.0


## Onde fica o centro da tecla de continuar de uma folha.
static func centro_da_tecla_da_folha(folha: Rect2) -> Vector2:
	return Vector2(folha.end.x - RECUO_TECLA_DA_FOLHA - LADO_TECLA_DA_FOLHA * 0.5, folha.end.y)


static func tecla_da_folha(ci: CanvasItem, f: Font, folha: Rect2, alfa: float = 1.0) -> void:
	if f == null or alfa <= 0.004:
		return
	tecla_da_acao(ci, f, centro_da_tecla_da_folha(folha), "E", &"interact", CLARO, alfa,
		TAM_TECLA_DA_FOLHA)


## O nome (BotoesControle) do desenho que representa a tecla "txt" da ação: o
## botão do controle, se a pessoa está de controle e a ação tem botão; senão a
## tecla da folha do teclado. Vazio se a tecla ainda não tem desenho.
static func desenho_da_tecla(txt: String, acao: StringName) -> String:
	if BotoesControle.controle_em_uso():
		var botao := BotoesControle.nome_da_acao(acao)
		if botao != "":
			return botao
	var nome := "tecla_" + txt.to_lower()
	return nome if BotoesControle.TECLAS.has(nome) else ""


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
