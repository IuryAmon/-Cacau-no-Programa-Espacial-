class_name CaixasDosElementos
extends RefCounted

# --- AS CAIXAS DOS ELEMENTOS (a arte de cada casa da tabela periódica) ---
#
# A caixa do hidrogênio do caderno da Cacau ("Hidrogênio tabela periódica.png")
# é a fonte do jogo, sem mais nada: moldura de tinta de 4 px, o número atômico
# e a massa na letra de 11 e o símbolo na de 33. Aqui a mesma caixa é montada
# para qualquer um dos 118 elementos, com os dados de Elementos:
#
#   CaixasDosElementos.textura(6)     a caixa do carbono (76 x 92 px, tinta
#                                     sobre fundo transparente, como a do H)
#
# Quem põe a caixa numa tela é o nó CaixaElemento (scripts/ui/caixa_elemento.gd),
# que desenha o papel atrás e o nome do elemento dentro. A tabela periódica do
# Laboratório, o "Monte seu átomo" e o quiz usam todos estas mesmas caixas.
#
# A MEDIDA DE CADA COISA foi tirada da caixa do H, pixel por pixel:
#   moldura            1 px de folga em volta e 4 px de traço
#   número atômico     a tinta começa na coluna 12; pé da letra na linha 19
#   símbolo            centrado na coluna 38; pé da letra na linha 49
#   massa              centrada entre as colunas 5 e 70; pé na linha 83
# O teste (tools/teste_caixas_dos_elementos.tscn) monta a do H e a do O e
# compara com as duas artes que já existem: não pode sobrar um pixel diferente.
#
# POR QUE NÃO É SÓ ESCREVER COM A FONTE: no projeto a fonte é importada como
# MSDF (letra lisa em qualquer tamanho), e escrita assim ela ganha um halo
# claro em volta que a arte do caderno não tem. Para sair igual à arte, as
# letras são desenhadas aqui a partir do mesmo arquivo da fonte, como mapa de
# pixels: sem MSDF, sem suavização. Cada letra é desenhada uma vez e
# carimbada nas caixas; as 118 ficam numa folha só, montada no primeiro pedido.

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

## O tamanho de uma caixa, em pixels da arte.
const LARGURA := 76
const ALTURA := 92
const TAMANHO := Vector2i(LARGURA, ALTURA)
## A tinta das caixas do caderno.
const TINTA := Color8(0x3d, 0x2a, 0x22)

## A moldura: a folga transparente em volta dela e a espessura do traço.
const FOLGA := 1
const TRACO := 4
## O miolo: o que fica por dentro da moldura.
const MIOLO := Rect2i(5, 5, 66, 82)

const TAM_NUMERO := 11
const TAM_SIMBOLO := 33
const TAM_MASSA := 11
## Onde a tinta do número atômico começa, e a linha do pé das letras dele.
const X_NUMERO := 12
const PE_NUMERO := 19
## A coluna em que o símbolo é centrado, e a linha do pé das letras dele.
const MEIO_SIMBOLO := 38
const PE_SIMBOLO := 49
const PE_MASSA := 83

## Entre o pé do símbolo e o topo da massa: é onde o nome do elemento cabe
## quando a caixa é desenhada ampliada (ver CaixaElemento).
const VAO_DO_NOME := Rect2(5, 49, 66, 25)

## Quantas caixas por linha na folha em que as 118 são guardadas.
const POR_LINHA := 18

static var _fonte_de_pixels: FontFile
## (tamanho da letra, índice do desenho na fonte) -> {"imagem", "desvio"}.
static var _letras := {}
static var _folha: Image
static var _textura_da_folha: ImageTexture
static var _texturas := {}
static var _faixas := {}
static var _vaos := {}


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

## A caixa do elemento (76 x 92 px): tinta sobre fundo transparente.
static func textura(z: int) -> Texture2D:
	if not Elementos.existe(z):
		return null
	if _texturas.has(z):
		return _texturas[z]
	_montar_a_folha()
	var recorte := AtlasTexture.new()
	recorte.atlas = _textura_da_folha
	recorte.region = Rect2(_canto_na_folha(z), TAMANHO)
	_texturas[z] = recorte
	return recorte


## A mesma caixa como imagem (para os testes compararem com a arte).
static func imagem(z: int) -> Image:
	if not Elementos.existe(z):
		return null
	_montar_a_folha()
	return _folha.get_region(Rect2i(_canto_na_folha(z), TAMANHO))


## Uma caixa sem elemento, só com um texto no meio: é a casa "57-71" que, na
## tabela, aponta para a fileira dos lantanídios (e a "89-103", dos actinídios).
static func textura_da_faixa(texto: String) -> Texture2D:
	if not _faixas.has(texto):
		var caixa := _caixa_vazia()
		var tinta := _escrever(texto, TAM_NUMERO)
		_carimbar(caixa, tinta, Vector2i(MIOLO.position.x + (MIOLO.size.x - tinta["imagem"].get_width()) / 2,
			MIOLO.get_center().y + 4))
		_faixas[texto] = ImageTexture.create_from_image(caixa)
	return _faixas[texto]


## Onde, dentro da caixa, cada escrita de um elemento tem tinta (em pixels da
## arte): {"numero", "simbolo", "massa"}. O teste confere que nenhuma encosta
## na moldura nem na outra.
static func tintas(z: int) -> Dictionary:
	var saida := {}
	var numero := _escrever(str(z), TAM_NUMERO)
	saida["numero"] = _retangulo(numero, Vector2i(X_NUMERO, PE_NUMERO))
	var simbolo := _escrever(Elementos.simbolo(z), TAM_SIMBOLO)
	saida["simbolo"] = _retangulo(simbolo, _lugar_do_simbolo(simbolo))
	var massa := _escrever(Elementos.massa(z), TAM_MASSA)
	saida["massa"] = _retangulo(massa, _lugar_da_massa(massa))
	return saida


## O vão em que o nome do elemento cabe nesta caixa (em pixels da arte): entre
## o símbolo e a massa. Quando o símbolo tem letra com perna (o g do Mg, o y do
## Dy), o vão começa abaixo dela: o nome não pode encostar na perna.
static func vao_do_nome(z: int) -> Rect2:
	if not _vaos.has(z):
		var vao := VAO_DO_NOME
		if Elementos.existe(z):
			var fim_da_tinta := float((tintas(z)["simbolo"] as Rect2i).end.y)
			if fim_da_tinta > vao.position.y:
				vao = Rect2(vao.position.x, fim_da_tinta + 1.0, vao.size.x, vao.end.y - fim_da_tinta - 1.0)
		_vaos[z] = vao
	return _vaos[z]


# ─────────────────────────────────────────────────────────────
# MONTAGEM
# ─────────────────────────────────────────────────────────────

static func _canto_na_folha(z: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(((z - 1) % POR_LINHA) * LARGURA, ((z - 1) / POR_LINHA) * ALTURA)


static func _montar_a_folha() -> void:
	if _folha != null:
		return
	@warning_ignore("integer_division")
	var linhas := (Elementos.TOTAL + POR_LINHA - 1) / POR_LINHA
	_folha = Image.create_empty(POR_LINHA * LARGURA, linhas * ALTURA, false, Image.FORMAT_RGBA8)
	for z in range(1, Elementos.TOTAL + 1):
		var caixa := _montar(z)
		_folha.blit_rect(caixa, Rect2i(Vector2i.ZERO, TAMANHO), _canto_na_folha(z))
	_textura_da_folha = ImageTexture.create_from_image(_folha)


static func _montar(z: int) -> Image:
	var caixa := _caixa_vazia()
	_carimbar(caixa, _escrever(str(z), TAM_NUMERO), Vector2i(X_NUMERO, PE_NUMERO))
	var simbolo := _escrever(Elementos.simbolo(z), TAM_SIMBOLO)
	_carimbar(caixa, simbolo, _lugar_do_simbolo(simbolo))
	var massa := _escrever(Elementos.massa(z), TAM_MASSA)
	_carimbar(caixa, massa, _lugar_da_massa(massa))
	return caixa


## Só a moldura.
static func _caixa_vazia() -> Image:
	var caixa := Image.create_empty(LARGURA, ALTURA, false, Image.FORMAT_RGBA8)
	caixa.fill_rect(Rect2i(FOLGA, FOLGA, LARGURA - FOLGA * 2, ALTURA - FOLGA * 2), TINTA)
	caixa.fill_rect(MIOLO, Color(0, 0, 0, 0))
	return caixa


## Onde a escrita vai: o canto esquerdo da tinta e a linha do pé das letras.
static func _lugar_do_simbolo(simbolo: Dictionary) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(MEIO_SIMBOLO - (simbolo["imagem"] as Image).get_width() / 2, PE_SIMBOLO)


static func _lugar_da_massa(massa: Dictionary) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(MIOLO.position.x + (MIOLO.size.x - (massa["imagem"] as Image).get_width()) / 2, PE_MASSA)


## Põe a escrita na caixa: "lugar" é o canto esquerdo da tinta (x) e a linha
## logo abaixo do pé das letras (y).
static func _carimbar(caixa: Image, escrita: Dictionary, lugar: Vector2i) -> void:
	var tinta: Image = escrita["imagem"]
	caixa.blend_rect(tinta, Rect2i(Vector2i.ZERO, tinta.get_size()),
		Vector2i(lugar.x, lugar.y - int(escrita["pe"])))


static func _retangulo(escrita: Dictionary, lugar: Vector2i) -> Rect2i:
	return Rect2i(Vector2i(lugar.x, lugar.y - int(escrita["pe"])), (escrita["imagem"] as Image).get_size())


# ─────────────────────────────────────────────────────────────
# AS LETRAS
# ─────────────────────────────────────────────────────────────

## A fonte do jogo lida como mapa de pixels: o mesmo arquivo, sem MSDF e sem
## nenhuma suavização. (Os dados da fonte vêm de dentro do recurso importado,
## então isto funciona igual no jogo exportado.)
static func _fonte() -> FontFile:
	if _fonte_de_pixels == null:
		_fonte_de_pixels = FontFile.new()
		_fonte_de_pixels.data = (FONTE as FontFile).data
		_fonte_de_pixels.multichannel_signed_distance_field = false
		_fonte_de_pixels.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_fonte_de_pixels.hinting = TextServer.HINTING_NONE
		_fonte_de_pixels.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_fonte_de_pixels.generate_mipmaps = false
	return _fonte_de_pixels


## O texto escrito em tinta: {"imagem": só a tinta, rente; "pe": quantas linhas
## da imagem ficam acima do pé das letras (o que passa disso é perna de letra
## ou vírgula)}.
static func _escrever(texto: String, tamanho: int) -> Dictionary:
	var servidor := TextServerManager.get_primary_interface()
	var linha := TextLine.new()
	linha.add_string(texto, _fonte(), tamanho)
	var escrita := linha.get_rid()
	var folga := 4
	var pe := folga + tamanho * 2
	var tela := Image.create_empty(ceili(servidor.shaped_text_get_size(escrita).x) + folga * 2,
		tamanho * 3 + folga * 2, false, Image.FORMAT_RGBA8)
	var x := float(folga)
	for glifo: Dictionary in servidor.shaped_text_get_glyphs(escrita):
		var letra := _letra(servidor, glifo)
		if not letra.is_empty():
			var desenho: Image = letra["imagem"]
			var desvio: Vector2 = letra["desvio"] + (glifo.get("offset", Vector2.ZERO) as Vector2)
			tela.blend_rect(desenho, Rect2i(Vector2i.ZERO, desenho.get_size()),
				Vector2i(roundi(x + desvio.x), roundi(pe + desvio.y)))
		x += float(glifo["advance"])
	var usado := tela.get_used_rect()
	if not usado.has_area():
		return {"imagem": Image.create_empty(1, 1, false, Image.FORMAT_RGBA8), "pe": 0}
	return {"imagem": tela.get_region(usado), "pe": pe - usado.position.y}


## O desenho de uma letra, já em tinta (vazio para o espaço em branco).
static func _letra(servidor: TextServer, glifo: Dictionary) -> Dictionary:
	var fonte: RID = glifo["font_rid"]
	var medida := Vector2i(int(glifo["font_size"]), 0)
	var indice := int(glifo["index"])
	var chave := Vector2i(medida.x, indice)
	if _letras.has(chave):
		return _letras[chave]
	var letra := {}
	servidor.font_render_glyph(fonte, medida, indice)
	var pagina := servidor.font_get_glyph_texture_idx(fonte, medida, indice)
	var recorte := Rect2i(servidor.font_get_glyph_uv_rect(fonte, medida, indice))
	if pagina >= 0 and recorte.has_area():
		var folha_da_fonte := servidor.font_get_texture_image(fonte, medida, pagina)
		var desenho := Image.create_empty(recorte.size.x, recorte.size.y, false, Image.FORMAT_RGBA8)
		for y in recorte.size.y:
			for px in recorte.size.x:
				if folha_da_fonte.get_pixel(recorte.position.x + px, recorte.position.y + y).a > 0.5:
					desenho.set_pixel(px, y, TINTA)
		letra = {"imagem": desenho, "desvio": servidor.font_get_glyph_offset(fonte, medida, indice)}
	_letras[chave] = letra
	return letra
