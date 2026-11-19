class_name ArteDoCompressor
extends RefCounted

# --- A ARTE DO COMPRESSOR DE AR DO MAPA (onde fica cada peça dela) ---
#
# A máquina da sala do compressor (CompressorDeAr) e o desenho em raio X do
# puzzle (CamaraDeCompressao, aberta em cima dela) são a MESMA máquina: o
# puzzle nasce em cima da arte com a câmera em zoom 4, e aí cada pixel da arte
# (escala 2 no mapa) vira 8 px da tela. Cada peça do raio X cai em cima da
# peça da arte — a câmara de aço vira a câmara por dentro, o cilindro preso
# no berço vira o cilindro com o ar dentro, o cabo vira o cabo que se arrasta.
#
# As medidas abaixo, em PIXELS DA ARTE (a origem é o canto de cima à esquerda
# da arte, de 112 x 92), são a fonte das duas coisas: a arte é gerada a partir
# delas (tools/gerar_arte_do_compressor.tscn) e o raio X as lê
# (CamaraDeCompressao.medidas_do_mapa). Mudou uma medida? Gere a arte de novo.
#
# A arte tem três camadas, do fundo para a frente (assets/fase nitrogenio/
# compressor/):
#   estrutura.png   a base, as pernas, o armário do resfriador e os canos dele —
#                   o que continua à vista com o puzzle aberto;
#   cabo.png        o cabo do êmbolo com a haste: anda com o êmbolo e desce
#                   para dentro da câmara (atrás dela) quando ele desce;
#   aparelho.png    a câmara de aço, a válvula, a cabeça do berço, as garras e o
#                   manômetro — o que o raio X troca pelo desenho de dentro.
# O cilindro preso no berço é a arte do cilindro de sempre ("Cilindro de
# Ar.png"), entre a estrutura e o aparelho.

const TAMANHO := Vector2i(112, 92)
## Onde a arte fica em relação ao nó do CompressorDeAr (px do mundo, escala 2):
## o nó fica no chão, no meio da máquina.
const ESCALA_NO_MAPA := 2
const CANTO_NO_MAPA := Vector2(-112, -184)

# ── A câmara ──
## O casco de aço da câmara inteiro (o contorno incluído).
const CASCO := Rect2i(8, 8, 48, 36)
## O vão do gás, por dentro das paredes, com o êmbolo no alto.
const CAMARA := Rect2i(11, 11, 42, 31)
## As paredes dos lados (com o contorno) e a do fundo.
const PAREDE := 3
const FUNDO := 2
## O êmbolo: a placa, a haste e a barra do cabo (em cima da haste).
const EMBOLO := 2
const HASTE := 5
const LARGURA_DA_HASTE := 3
const BARRA_DO_CABO := Vector2i(13, 4)

# ── O caminho do ar até o cilindro ──
## O furo do fundo da câmara, descendo pela válvula e pela cabeça do berço até
## o cilindro.
const GARGALO := Rect2i(29, 42, 5, 13)
## O corpo da válvula (em volta do gargalo) e o volante dela, à esquerda.
const VALVULA := Rect2i(27, 44, 9, 3)
const VOLANTE := Vector2(24.5, 45.5)
const RAIO_DO_VOLANTE := 2.5
## A cabeça do berço: o bloco em que o cilindro encaixa (cobre a tampa e o
## gargalo dele).
const CABECA_DO_BERCO := Rect2i(26, 47, 11, 8)
## O cilindro: onde fica o canto da arte dele (15 x 39) e o vão dele por dentro
## (no raio X, o ar fica aí).
const CILINDRO := Vector2i(24, 45)
const VAO_DO_CILINDRO := Rect2i(28, 55, 7, 25)
## O vão do cilindro na arte dele.
const VAO_NA_ARTE_DO_CILINDRO := Rect2i(4, 10, 7, 25)
## As garras que seguram o cilindro (uma de cada lado): o tamanho e a linha.
const GARRA := Vector2i(3, 5)
const LINHA_DAS_GARRAS := 69
## O manômetro: o meio e o raio do mostrador.
const MANOMETRO := Vector2(44.5, 59.5)
const RAIO_DO_MANOMETRO := 6.5

# ── A estrutura ──
const PERNAS: Array[Rect2i] = [Rect2i(8, 44, 4, 38), Rect2i(52, 44, 4, 38)]
## O armário do resfriador (o da arte antiga, com o monitor em cima).
const ARMARIO := Rect2i(79, 21, 33, 61)
## Os canos do resfriador: a linha do meio de cada um. O de cima leva o frio
## do armário à serpentina (sobe pela perna da direita); o de baixo volta (desce
## pela perna da esquerda e passa por trás do cilindro).
const CANO_DE_IDA := 51
const CANO_DE_VOLTA := 57
const BASE_DO_CHAO := 82

## As artes.
const PASTA := "res://assets/fase nitrogenio/compressor/"
const ESTRUTURA := PASTA + "estrutura.png"
const APARELHO := PASTA + "aparelho.png"
const CABO := PASTA + "cabo.png"
## A arte do cilindro preso no berço: a de sempre e, com o ar lá dentro bem
## frio, a gelada (a mesma da amostra).
const ARTE_DO_CILINDRO := "res://assets/fase nitrogenio/Cilindro de Ar.png"
const ARTE_DO_CILINDRO_GELADO := "res://assets/fase nitrogenio/cilindro de ar liquido.png"
const CILINDRO_GELA_ABAIXO_DE := -100.0
## Quanto o cabo desce (pixels da arte) com o êmbolo no fundo: a altura da
## câmara.
const CURSO_DO_CABO := CAMARA.size.y


## O retângulo da arte (px da arte) em px de quem desenha, com "pixel" px por
## pixel da arte.
static func em_px(r: Rect2i, pixel: float) -> Rect2:
	return Rect2(Vector2(r.position) * pixel, Vector2(r.size) * pixel)


## As duas garras (a da esquerda e a da direita), coladas no vão do cilindro.
static func garras() -> Array[Rect2i]:
	var vao_x := CILINDRO.x + VAO_NA_ARTE_DO_CILINDRO.position.x
	return [
		Rect2i(vao_x - 1 - GARRA.x, LINHA_DAS_GARRAS, GARRA.x, GARRA.y),
		Rect2i(vao_x + VAO_NA_ARTE_DO_CILINDRO.size.x + 1, LINHA_DAS_GARRAS, GARRA.x, GARRA.y),
	]


## O quadrado do volante da válvula (5 x 5).
static func quadrado_do_volante() -> Rect2i:
	var lado := int(RAIO_DO_VOLANTE * 2.0)
	return Rect2i(Vector2i((VOLANTE - Vector2.ONE * RAIO_DO_VOLANTE).floor()), Vector2i(lado, lado))


## Quantos pixels da arte o êmbolo desceu na posição dada (0 no alto, 1 no
## fundo): ele anda de pixel em pixel.
static func descida_do_embolo(posicao: float) -> int:
	return roundi(clampf(posicao, 0.0, 1.0) * CURSO_DO_CABO)


## Onde o cabo fica (o canto de cima à esquerda, px da arte) com o êmbolo na
## posição dada.
static func canto_do_cabo(posicao: float) -> Vector2i:
	var meio := GARGALO.position.x + GARGALO.size.x * 0.5
	return Vector2i(roundi(meio - BARRA_DO_CABO.x * 0.5), descida_do_embolo(posicao))


## A arte do aparelho como o mapa a mostra: com o êmbolo descido, a borda de
## cima da câmara (que é a placa dele) desce junto e, acima dela, a câmara fica
## aberta — é por onde o cabo desce; com o cilindro solto, as garras abertas.
## (É o mesmo que o raio X do puzzle desenha: a troca entre os dois não pula.)
static func aparelho_no_mapa(base: Image, posicao: float, garras_abertas: bool) -> Image:
	var imagem := base.duplicate() as Image
	var descida := descida_do_embolo(posicao)
	if descida > 0:
		var borda := Rect2i(CAMARA.position.x, CASCO.position.y, CAMARA.size.x, CAMARA.position.y - CASCO.position.y)
		imagem.fill_rect(Rect2i(borda.position, Vector2i(borda.size.x, descida)), Color(0, 0, 0, 0))
		imagem.blit_rect(base, borda, borda.position + Vector2i(0, descida))
	if garras_abertas:
		var lados := garras()
		for i in lados.size():
			imagem.fill_rect(lados[i], Color(0, 0, 0, 0))
		for i in lados.size():
			var para_fora := Vector2i(-2 if i == 0 else 2, 0)
			imagem.blend_rect(base, lados[i], lados[i].position + para_fora)
	return imagem
