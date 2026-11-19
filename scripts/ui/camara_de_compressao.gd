class_name CamaraDeCompressao
extends Control

# --- O COMPRESSOR DE AR, DESENHADO (câmara, êmbolo, cilindro e moléculas) ---
#
# O desenho da MaquinaDeCompressao (scripts/laboratorio/maquina_de_compressao.gd)
# em "raio X", como a coluna de destilação: a pessoa vê o ar lá dentro. Serve
# ao puzzle da fase do nitrogênio (scripts/puzzle_compressor.gd); o simulador
# de gases do Laboratório usa a CamaraDoSimulador (scripts/ui/
# camara_do_simulador.gd), que é esta câmara sem o cilindro, com a bomba de ar
# e a trava do êmbolo.
# Quem usa só entrega a máquina e chama avancar(delta) a cada quadro.
#
#   CÂMARA      a caixa grande, de paredes de aço. O ÊMBOLO desce dentro dela;
#               acima dele ficam a haste e o cabo (é por onde ele é puxado).
#   GARGALO     o furo no fundo da câmara, com a VÁLVULA (o volante ao lado) e
#               o MANÔMETRO pendurado num cano: 0 a 5 atm, verde até a pressão
#               de trabalho, amarelo até a ruptura, vermelho depois.
#   CILINDRO    o cilindro de amostra, azul como a arte dele no mapa, preso
#               por duas garras. O ar líquido junta no fundo dele.
#   SERPENTINA  o cano do resfriador, colado nas paredes da câmara e abraçando
#               o cilindro. A cor é a temperatura dela: laranja quente, azul
#               frio, coberta de geada abaixo de uns −60 °C.
#
# AS MOLÉCULAS são as do destilador (MoleculasDoDestilador): N₂ verde, O₂ azul
# e Ar roxo, na proporção do ar (78 + 21 + 1 = 100 no mol de ar da fase; cada
# bolinha vale 0,01 mol).
# Nada é sorteado contra a física:
#   * a VELOCIDADE de cada uma vem da temperatura do gás e da massa dela (as
#     pesadas andam mais devagar). Na física ela anda com √T; o desenho
#     EXAGERA (EXPOENTE_DA_TEMPERATURA), para a diferença saltar
#     aos olhos: no ar da sala elas correm, no frio do resfriador ficam
#     lentinhas; cada uma tem a sua "sorte" (a
#     distribuição de Maxwell-Boltzmann), trocada de tempos em tempos, como se
#     tivesse batido em outra;
#   * o êmbolo descendo empurra quem bate nele: elas saem mais rápidas (é a
#     compressão esquentando o gás, molécula por molécula);
#   * QUANTAS ESTÃO LÍQUIDAS é o que o modelo diz (a fração de líquido). Quem
#     condensa vira gota, desacelera, cai e escorre pelo gargalo até o fundo do
#     cilindro — e o OXIGÊNIO condensa antes (ele ferve mais quente), na
#     proporção da primeira gota do modelo. Fervendo, o nitrogênio sai antes.
#
# A EXPLOSÃO: quando a máquina estoura, a câmara toca a cena inteira — o
# cilindro incha e treme, rachaduras correm pela parede, o vidro do manômetro
# trinca, o gás assobia pelas frestas, e então o estrondo: clarão, onda de
# choque, o cilindro em pedaços, as moléculas lançadas para fora e a fumaça.
# Os sinais avisam quem a usa (o puzzle faz o clarão da tela inteira, o
# tremor e o som): estourando -> estrondo -> explosao_terminou.
#
# ONDE MEXER: as medidas e as cores estão nas constantes logo abaixo. As áreas
# da câmara e do cilindro estão na mesma proporção dos volumes da máquina (o
# cilindro é ~1/8 do total): é isso que faz a conta das moléculas que estão no
# cilindro bater com o desenho.
#
# NO MAPA: na história o puzzle abre em cima da máquina da sala do compressor,
# e aí as medidas vêm da arte dela (medidas_do_mapa, ArteDoCompressor): a
# câmara é desenhada na grade da arte, medidas.pixel px por pixel dela. O que é
# igual por fora (as paredes, a válvula, as garras, o cabo, o cilindro) vem da
# própria arte, e só o de dentro é desenhado — ver "No mapa", mais abaixo. Sem
# isso (o Laboratório, os testes), valem as constantes (medidas_de_sempre).

## A máquina começou a estourar (o inchaço; o estrondo vem logo depois).
signal estourando
## O instante do estrondo.
signal estrondo
## A explosão acabou de acontecer (os cacos já caíram): hora da tela de fim.
signal explosao_terminou
## Sons pequenos do aparelho, para quem toca os sons.
signal rangeu
signal gotejou
signal valvula_fechou

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

# ── A geometria (px do nó) ──
## O vão da câmara, por dentro das paredes, com o êmbolo no alto.
const CAMARA := Rect2(52, 100, 456, 288)
## A espessura das paredes de aço.
const PAREDE := 12.0
## O furo do fundo e o gargalo, até o ombro do cilindro.
const GARGALO := Rect2(264, 388, 32, 52)
## O vão do cilindro, por dentro da parede.
const CILINDRO := Rect2(232, 440, 96, 176)
const PAREDE_DO_CILINDRO := 8.0
## O êmbolo: a placa e a haste até o cabo.
const ESPESSURA_DO_EMBOLO := 20.0
const HASTE := 62.0
## O manômetro (o centro e o raio do mostrador).
const MANOMETRO_CENTRO := Vector2(404, 474)
const MANOMETRO_RAIO := 52.0
## Até onde a escala do manômetro vai (atm).
const ESCALA_DO_MANOMETRO := 5.0
## A válvula: o corpo dela em volta do gargalo e o volante à esquerda.
const VALVULA := Rect2(254, 402, 52, 24)
const VOLANTE := Vector2(232, 414)

# ── As moléculas ──
## Quantas bolinhas desenham 1 mol de ar (ver contas_do_ar).
const BOLINHAS_POR_MOL := 100.0
## Massa molar de cada uma (g/mol): as pesadas andam mais devagar (v ∝ 1/√M).
const MASSAS := {"N2": 28.01, "O2": 32.00, "Ar": 39.95}
const MASSA_DO_AR := 28.96
## O tamanho do desenho, além da escala do destilador (2x): 0,75 deixa a
## molécula com ~18 px de comprimento.
const AMPLIACAO := 0.75
## O raio com que a molécula bate nas paredes.
const RAIO := 6.0
## A velocidade média (px/s) a 25 °C, a temperatura em que a câmara começa.
const VELOCIDADE_A_25 := 280.0
## Como a velocidade segue a temperatura: v ∝ (T / 25 °C) ^ isto. A física diz
## 0,5 (√T); o desenho usa 1,3, para o frio ficar bem visível: a −190 °C elas
## andam a ~1/5 da velocidade da sala (com √T seria metade).
const EXPOENTE_DA_TEMPERATURA := 1.3
## Teto da conta acima (em vezes a velocidade da sala): quente demais, elas não
## atravessam a câmara num quadro.
const MAIS_RAPIDA := 2.4
## Quanto tempo, em média, até a molécula "bater em outra" e mudar de sorte.
const TEMPO_ENTRE_CHOQUES := 1.6
## A gota: a gravidade dela e a pressa com que escorre pelo chão até o furo.
const GRAVIDADE_DA_GOTA := 900.0
const ESCORRIDA := 150.0
## A poça: quantas cabem numa fileira e a altura de cada fileira.
const NA_FILEIRA := 5
const ALTURA_DA_FILEIRA := 8.0
## Quantas moléculas podem condensar (ou ferver) num quadro: o líquido se forma
## aos poucos, dá para ver as gotas.
const TROCAS_POR_QUADRO := 2

# ── As cores ──
const COR_VAO := Color("0a0d14")
const COR_VAO_FRIO := Color("0b1a33")
const COR_VAO_QUENTE := Color("2b1209")
const COR_ACO := Color("8a93b8")
const COR_ACO_CLARO := Color("d9dcc8")
const COR_ACO_ESCURO := Color("3a4160")
const COR_CILINDRO := Color("3232ac")
const COR_CILINDRO_CLARO := Color("6357d9")
const COR_CILINDRO_ESCURO := Color("1212ae")
const COR_LIQUIDO := Color(0.62, 0.80, 1.0, 0.24)
const COR_LIQUIDO_TONA := Color(0.80, 0.92, 1.0, 0.75)
const COR_GEADA := Color(0.88, 0.96, 1.0)
const COR_QUENTE := Color("f4a259")
const COR_FRIO := Color("5fb8ff")
const COR_VERDE := Color("3ecf72")
const COR_AMARELO := Color("f2c84b")
const COR_VERMELHO := Color("e8463a")

## As medidas do desenho (px do nó). As de sempre são as constantes da
## geometria lá em cima (a tela inteira, e o simulador do Laboratório). Aberta
## em cima da máquina do mapa, a câmara troca por medidas_do_mapa(): as mesmas
## peças, na grade da arte do compressor (ArteDoCompressor) — ver "No mapa",
## no desenho.
class Medidas:
	var camara: Rect2
	var parede: float
	var gargalo: Rect2
	var cilindro: Rect2
	var parede_do_cilindro: float
	var espessura_do_embolo: float
	var haste: float
	var manometro_centro: Vector2
	var manometro_raio: float
	var valvula: Rect2
	var volante: Vector2
	var raio_do_volante: float = 13.0
	var na_fileira: int
	var altura_da_fileira: float
	## Onde as paredes da câmara começam (na tela inteira, no alto do nó).
	var topo_das_paredes: float = 0.0
	## A barra do cabo (largura e altura) e quanto ela desce por cima da haste.
	var cabo: Vector2 = Vector2(128, 28)
	var cabo_sobre_a_haste: float = 12.0
	## Onde a geada da serpentina aparece (as faixas em que o cano corre).
	var faixas_da_serpentina: Array[Rect2] = []
	## No mapa: quantos px tem um pixel da arte (0 fora do mapa); as artes (a do
	## aparelho, a do cabo com a haste e a do cilindro preso no berço — a mesma
	## que o mapa mostra) e o canto do cilindro; os canos do resfriador por trás
	## da máquina (faixas) e o cano da serpentina, que sobe pelas pernas e anda
	## em zigue-zague dentro das paredes.
	var pixel: float = 0.0
	var arte_do_aparelho: Texture2D = null
	var arte_do_cabo: Texture2D = null
	var arte_do_cilindro: Texture2D = null
	var arte_do_cilindro_gelado: Texture2D = null
	var canto_do_cilindro: Vector2 = Vector2.ZERO
	var canos_de_tras: Array[Rect2] = []
	var serpentina: Array[PackedVector2Array] = []

	func no_mapa() -> bool:
		return pixel > 0.0


## As medidas de sempre (as constantes).
static func medidas_de_sempre() -> Medidas:
	var m := Medidas.new()
	m.camara = CAMARA
	m.parede = PAREDE
	m.gargalo = GARGALO
	m.cilindro = CILINDRO
	m.parede_do_cilindro = PAREDE_DO_CILINDRO
	m.espessura_do_embolo = ESPESSURA_DO_EMBOLO
	m.haste = HASTE
	m.manometro_centro = MANOMETRO_CENTRO
	m.manometro_raio = MANOMETRO_RAIO
	m.valvula = VALVULA
	m.volante = VOLANTE
	m.na_fileira = NA_FILEIRA
	m.altura_da_fileira = ALTURA_DA_FILEIRA
	# A geada: nos 16 px de fora de cada parede, onde o cano desce.
	m.faixas_da_serpentina = [
		Rect2(CAMARA.position.x - PAREDE - 16.0, CAMARA.position.y, 16.0, CAMARA.size.y - 10.0),
		Rect2(CAMARA.end.x + PAREDE, CAMARA.position.y, 16.0, CAMARA.size.y - 10.0),
	]
	return m


## As medidas da máquina do mapa: o nó da câmara fica com o canto em cima do
## canto da arte do compressor, e cada pixel da arte vale "pixel" px (8, com a
## câmera em zoom 4: a arte está em escala 2 no mapa).
static func medidas_do_mapa(pixel: float = 8.0) -> Medidas:
	var A := ArteDoCompressor
	var m := Medidas.new()
	m.pixel = pixel
	m.camara = A.em_px(A.CAMARA, pixel)
	m.parede = A.PAREDE * pixel
	m.topo_das_paredes = A.CASCO.position.y * pixel
	m.gargalo = A.em_px(A.GARGALO, pixel)
	m.cilindro = A.em_px(A.VAO_DO_CILINDRO, pixel)
	m.parede_do_cilindro = pixel
	m.espessura_do_embolo = A.EMBOLO * pixel
	m.haste = A.HASTE * pixel
	m.cabo = Vector2(A.BARRA_DO_CABO) * pixel
	m.cabo_sobre_a_haste = 0.0
	m.manometro_centro = A.MANOMETRO * pixel
	m.manometro_raio = A.RAIO_DO_MANOMETRO * pixel
	m.valvula = A.em_px(A.VALVULA, pixel)
	m.volante = A.VOLANTE * pixel
	m.raio_do_volante = A.RAIO_DO_VOLANTE * pixel
	# A poça no cilindro fino: 4 por fileira, fileiras mais baixas (cabem as
	# 100 moléculas, se o ar todo virar líquido).
	m.na_fileira = 4
	m.altura_da_fileira = 7.0
	m.arte_do_aparelho = load(A.APARELHO) as Texture2D
	m.arte_do_cabo = load(A.CABO) as Texture2D
	m.arte_do_cilindro = load(A.ARTE_DO_CILINDRO) as Texture2D
	m.arte_do_cilindro_gelado = load(A.ARTE_DO_CILINDRO_GELADO) as Texture2D
	m.canto_do_cilindro = Vector2(A.CILINDRO) * pixel
	# Os canos do resfriador (3 pixels de altura cada), das pernas ao armário.
	var perna_esq: Rect2i = A.PERNAS[0]
	var perna_dir: Rect2i = A.PERNAS[1]
	var ate_o_armario := A.ARMARIO.position.x + 2
	m.canos_de_tras = [
		A.em_px(Rect2i(perna_dir.end.x, A.CANO_DE_IDA - 1, ate_o_armario - perna_dir.end.x, 3), pixel),
		A.em_px(Rect2i(perna_esq.end.x, A.CANO_DE_VOLTA - 1, ate_o_armario - perna_esq.end.x, 3), pixel),
	]
	# A serpentina corre no aço de dentro de cada parede (sem o contorno).
	var na_esquerda := A.em_px(Rect2i(A.CASCO.position.x + 1, A.CASCO.position.y + 1,
		A.PAREDE - 1, A.CASCO.size.y - 2), pixel)
	var na_direita := A.em_px(Rect2i(A.CASCO.end.x - A.PAREDE, A.CASCO.position.y + 1,
		A.PAREDE - 1, A.CASCO.size.y - 2), pixel)
	m.faixas_da_serpentina = [na_esquerda, na_direita]
	m.serpentina = [
		_serpentina_da_parede(na_esquerda, (A.CANO_DE_VOLTA + 0.5) * pixel, pixel),
		_serpentina_da_parede(na_direita, (A.CANO_DE_IDA + 0.5) * pixel, pixel),
	]
	return m


## O cano da serpentina de uma parede, no mapa: sobe por dentro da perna (do
## cano do resfriador até a câmara) e, dentro da parede, sobe em zigue-zague
## até a borda de cima.
static func _serpentina_da_parede(faixa: Rect2, y_do_cano: float, pixel: float) -> PackedVector2Array:
	var meio := faixa.get_center().x
	var x_a := faixa.position.x + faixa.size.x * 0.25
	var x_b := faixa.end.x - faixa.size.x * 0.25
	var pontos := PackedVector2Array([Vector2(meio, y_do_cano), Vector2(meio, faixa.end.y)])
	var y := faixa.end.y - pixel * 0.5
	var lado := 0
	while y > faixa.position.y + pixel:
		var x := x_a if lado == 0 else x_b
		pontos.append(Vector2(x, y))
		pontos.append(Vector2(x, maxf(y - pixel * 1.5, faixa.position.y + pixel * 0.5)))
		y -= pixel * 2.5
		lado = 1 - lado
	return pontos


## As medidas do desenho agora (troque antes de entregar a máquina).
var medidas: Medidas = medidas_de_sempre()

## Quem a câmara desenha. Sem máquina, nada.
var maquina: MaquinaDeCompressao = null:
	set(valor):
		if maquina != null and maquina.estourou.is_connected(_ao_estourar):
			maquina.estourou.disconnect(_ao_estourar)
		maquina = valor
		if maquina != null:
			maquina.estourou.connect(_ao_estourar)
		reiniciar()

## Desenhar os nomes das peças (CÂMARA, ÊMBOLO...).
@export var com_nomes: bool = true
## Desenhar o volante da válvula do cilindro (sem ele, a válvula fica só o
## corpo em volta do gargalo, sempre aberta).
@export var com_valvula: bool = true
## Quanto da névoa fria escorre do cilindro (o resto escorre das paredes da
## câmara).
var nevoa_no_cilindro: float = 0.35
## O cabo do êmbolo aceso (a pessoa está com o ponteiro nele ou arrastando).
var cabo_em_foco: bool = false

var _moleculas: Array[Molecula] = []
var _tempo: float = 0.0
var _y_do_embolo: float = 0.0
var _velocidade_do_embolo: float = 0.0
## O ponteiro do manômetro (atm), com mola, e a velocidade dele.
var _ponteiro: float = 1.0
var _velocidade_do_ponteiro: float = 0.0
## O tremor do aparelho (px) e o que o provoca: a pressão perto da ruptura.
var _tremor: Vector2 = Vector2.ZERO
var _proximo_rangido: float = 0.0
## A geada: 0 nada, 1 coberto. Vai atrás do frio aos poucos.
var _geada: float = 0.0
var _geada_no_cilindro: float = 0.0
## O volante da válvula (o ângulo) e o quanto ela está fechada (0 a 1).
var _giro_do_volante: float = 0.0
var _fechamento: float = 0.0
## As garras que prendem o cilindro: 0 fechadas, 1 abertas.
var _abertura_das_garras: float = 0.0
## Os fiapos de névoa fria que escorrem da serpentina.
var _nevoa: Array[Dictionary] = []
var _proxima_nevoa: float = 0.0

# ── A explosão ──
enum Fase { NORMAL, INCHANDO, ESTOURADA }
const TEMPO_DE_INCHAR := 1.1
const TEMPO_DEPOIS_DO_ESTRONDO := 2.6
var _fase: Fase = Fase.NORMAL
var _tempo_da_explosao: float = 0.0
var _rachaduras: Array[PackedVector2Array] = []
var _cacos: Array[Dictionary] = []
var _fumaca: Array[Dictionary] = []
var _faiscas: Array[Dictionary] = []
var _jatos: Array[Dictionary] = []
var _anunciou_fim: bool = false


## Uma molécula do desenho.
class Molecula:
	var chave: String = "N2"
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	## A "sorte" dela na distribuição de velocidades (média quadrática 1).
	var sorte: float = 1.0
	var proximo_choque: float = 1.0
	var giro: float = 0.0
	var velocidade_do_giro: float = 1.0
	## 0 gás, 1 gota caindo, 2 líquida na poça.
	var estado: int = 0
	var vaga: int = -1
	## Fora do aparelho (a explosão a jogou para longe).
	var solta: bool = false
	## Na explosão, quem estava na câmara sai pelo furo do fundo antes de voar.
	var pelo_gargalo: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _moleculas.is_empty():
		reiniciar()


## Tudo como a máquina está agora: as moléculas espalhadas pelo gás (ou na
## poça, se já há líquido), sem gota a caminho, sem cacos.
func reiniciar() -> void:
	_moleculas.clear()
	_fase = Fase.NORMAL
	_tempo_da_explosao = 0.0
	_rachaduras.clear()
	_cacos.clear()
	_fumaca.clear()
	_faiscas.clear()
	_jatos.clear()
	_nevoa.clear()
	_anunciou_fim = false
	_tremor = Vector2.ZERO
	_y_do_embolo = _y_do_embolo_alvo()
	_ponteiro = maquina.pressao() if maquina else 1.0
	_velocidade_do_ponteiro = 0.0
	_fechamento = 0.0 if maquina == null or maquina.valvula_aberta else 1.0
	_abertura_das_garras = _fechamento
	var frio := _frio_da_serpentina()
	_geada = frio
	_geada_no_cilindro = _frio_do_gas()
	var liquidas := _liquidas_pedidas()
	var contas := contas_do_ar(_quantas_bolinhas())
	for chave: String in contas:
		for i in int(contas[chave]):
			_moleculas.append(_nova_molecula(chave, _ponto_livre()))
	_moleculas.shuffle()
	# Quem já está líquido começa direto na poça (escolhido como o modelo
	# escolheria: o oxigênio primeiro).
	for i in liquidas:
		var m := _escolher(0, true)
		if m == null:
			break
		_por_na_poca(m, true)
	queue_redraw()


# ─────────────────────────────────────────────────────────────
# O TEMPO PASSANDO
# ─────────────────────────────────────────────────────────────

## Anda a máquina e o desenho. Quem usa a câmara chama isto a cada quadro.
func avancar(delta: float) -> void:
	if maquina == null:
		return
	_tempo += delta
	if _fase == Fase.NORMAL:
		maquina.avancar(delta)
	_animar_pecas(delta)
	match _fase:
		Fase.NORMAL:
			_acertar_o_liquido()
			_mover_moleculas(delta)
		Fase.INCHANDO:
			_inchar(delta)
			_mover_moleculas(delta)
		Fase.ESTOURADA:
			_depois_do_estrondo(delta)
	_animar_nevoa(delta)
	queue_redraw()


func _animar_pecas(delta: float) -> void:
	var y_antes := _y_do_embolo
	_y_do_embolo = _y_do_embolo_alvo()
	_velocidade_do_embolo = (_y_do_embolo - y_antes) / maxf(delta, 0.0001)

	# O ponteiro do manômetro: uma mola com amortecimento (ele passa um
	# tiquinho e volta), e treme perto da ruptura.
	var p := maquina.pressao()
	if _fase != Fase.NORMAL:
		p = ESCALA_DO_MANOMETRO + 0.4
	var forca := (p - _ponteiro) * 120.0 - _velocidade_do_ponteiro * 16.0
	_velocidade_do_ponteiro += forca * delta
	_ponteiro += _velocidade_do_ponteiro * delta

	# O aparelho treme quando a pressão chega perto do limite.
	var perigo := clampf(inverse_lerp(MaquinaDeCompressao.PRESSAO_DE_TRABALHO,
		MaquinaDeCompressao.PRESSAO_DE_RUPTURA, p), 0.0, 1.0)
	if _fase == Fase.INCHANDO:
		perigo = 1.0 + _tempo_da_explosao * 2.0
	var amplitude := perigo * perigo * 2.5
	_tremor = Vector2(randf_range(-amplitude, amplitude), randf_range(-amplitude, amplitude)).round() \
		if amplitude > 0.3 else Vector2.ZERO
	if perigo > 0.05 and _fase == Fase.NORMAL:
		_proximo_rangido -= delta * (0.5 + perigo * 2.5)
		if _proximo_rangido <= 0.0:
			_proximo_rangido = randf_range(0.8, 1.6)
			rangeu.emit()

	# A geada cresce devagar e derrete devagar.
	_geada = move_toward(_geada, _frio_da_serpentina(), delta * 0.35)
	_geada_no_cilindro = move_toward(_geada_no_cilindro, _frio_do_gas(), delta * 0.25)

	# A válvula fechando: o volante gira e a comporta desce.
	var fechar := 0.0 if maquina.valvula_aberta else 1.0
	var antes := _fechamento
	_fechamento = move_toward(_fechamento, fechar, delta * 1.6)
	_giro_do_volante += (_fechamento - antes) * TAU * 2.0
	if antes < 1.0 and _fechamento >= 1.0:
		valvula_fechou.emit()
	# As garras soltam o cilindro depois que a válvula fechou.
	var soltar := 1.0 if _fechamento >= 1.0 else 0.0
	_abertura_das_garras = move_toward(_abertura_das_garras, soltar, delta * 2.0)


## 0 com a serpentina na sala (ou mais quente), 1 lá embaixo, a −200 °C.
func _frio_da_serpentina() -> float:
	if maquina == null:
		return 0.0
	return clampf(inverse_lerp(-60.0, -190.0, GasFechado.para_celsius(maquina.temperatura_da_serpentina)), 0.0, 1.0)


func _frio_do_gas() -> float:
	if maquina == null:
		return 0.0
	return clampf(inverse_lerp(-100.0, -190.0, maquina.gas.celsius()), 0.0, 1.0)


# ─────────────────────────────────────────────────────────────
# AS MOLÉCULAS
# ─────────────────────────────────────────────────────────────

## Quantas moléculas a câmara desenha: o ar da máquina, a BOLINHAS_POR_MOL.
func _quantas_bolinhas() -> int:
	var mols := maquina.gas.mols if maquina else MaquinaDeCompressao.MOLS
	return roundi(mols * BOLINHAS_POR_MOL)


## Quantas bolinhas de cada gás um total delas tem, na proporção do ar
## (GasFechado.COMPOSICAO): a parte inteira de cada um e, as que sobram, para
## quem tem o maior resto. 100 dão 78 de N₂, 21 de O₂ e 1 de Ar.
static func contas_do_ar(total: int) -> Dictionary:
	var contas := {}
	var restos: Array = []
	var soma := 0
	for chave: String in GasFechado.COMPOSICAO:
		var exata := float(GasFechado.COMPOSICAO[chave]) * total
		contas[chave] = floori(exata)
		soma += floori(exata)
		restos.append([exata - floorf(exata), chave])
	restos.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for i in maxi(total - soma, 0):
		var chave: String = restos[i % restos.size()][1]
		contas[chave] = int(contas[chave]) + 1
	return contas


## Uma molécula de gás nova, em "onde", andando para um lado qualquer na
## velocidade da temperatura de agora.
func _nova_molecula(chave: String, onde: Vector2) -> Molecula:
	var m := Molecula.new()
	m.chave = chave
	m.sorte = _sortear_sorte()
	m.proximo_choque = randf() * TEMPO_ENTRE_CHOQUES * 2.0
	m.giro = randf() * 4.0
	m.velocidade_do_giro = randf_range(2.0, 6.0) * (1.0 if randf() < 0.5 else -1.0)
	m.pos = onde
	m.vel = Vector2.from_angle(randf() * TAU) * _velocidade_de(m)
	return m


## A velocidade de agora desta molécula (px/s): a temperatura (exagerada, ver
## EXPOENTE_DA_TEMPERATURA), a massa dela e a sorte.
func _velocidade_de(m: Molecula) -> float:
	var t := maquina.gas.temperatura if maquina else 298.15
	var pela_temperatura := minf(pow(maxf(t, 1.0) / 298.15, EXPOENTE_DA_TEMPERATURA), MAIS_RAPIDA)
	return VELOCIDADE_A_25 * pela_temperatura * sqrt(MASSA_DO_AR / float(MASSAS[m.chave])) * m.sorte


## Uma sorte da distribuição de velocidades em 2D (Rayleigh), com média
## quadrática 1: a maioria perto de 1, umas lentas, umas bem rápidas.
func _sortear_sorte() -> float:
	return clampf(sqrt(-log(maxf(1.0 - randf(), 0.0001))), 0.25, 2.2)


func _mover_moleculas(delta: float) -> void:
	# Passos curtos o bastante para a mais rápida não pular uma parede (uns 5 px).
	var mais_rapida := VELOCIDADE_A_25 * MAIS_RAPIDA * 2.2
	var passos := maxi(2, ceili(mais_rapida * delta / 5.0))
	var dt := delta / passos
	for i in passos:
		for m in _moleculas:
			match m.estado:
				0:
					_mover_gas(m, dt)
				1:
					_mover_gota(m, dt)
				2:
					_assentar(m, dt)
			m.giro += m.velocidade_do_giro * dt * (0.25 if m.estado == 2 else 1.0)


func _mover_gas(m: Molecula, dt: float) -> void:
	# Um choque com outra molécula, de vez em quando: a sorte muda.
	m.proximo_choque -= dt
	if m.proximo_choque <= 0.0:
		m.proximo_choque = randf_range(0.4, 2.0) * TEMPO_ENTRE_CHOQUES
		m.sorte = _sortear_sorte()
		m.vel = m.vel.rotated(randf_range(-1.2, 1.2))
	# A velocidade vai atrás da temperatura (devagar o bastante para o empurrão
	# do êmbolo se ver).
	var alvo := _velocidade_de(m)
	var agora := m.vel.length()
	if agora < 0.001:
		m.vel = Vector2.from_angle(randf() * TAU) * alvo
	else:
		m.vel *= lerpf(agora, alvo, 1.0 - exp(-dt / 0.35)) / agora

	var nova := m.pos + m.vel * dt
	if not _dentro(nova):
		if not _dentro(Vector2(nova.x, m.pos.y)):
			m.vel.x = -m.vel.x
		if not _dentro(Vector2(m.pos.x, nova.y)):
			m.vel.y = -m.vel.y
		nova = m.pos + m.vel * dt
		if not _dentro(nova):
			nova = m.pos
	m.pos = nova
	_empurrar_pelo_embolo(m)
	if not _dentro(m.pos):
		m.pos = _ponto_mais_perto_dentro(m.pos)


## Quem ficou acima da cara do êmbolo é empurrado para baixo — e, se o êmbolo
## está descendo, quica nele mais rápido (o choque elástico com uma parede que
## anda: v' = 2·v_parede − v).
func _empurrar_pelo_embolo(m: Molecula) -> void:
	if m.pos.x < medidas.camara.position.x or m.pos.x > medidas.camara.end.x:
		return
	var cara := _y_do_embolo + RAIO
	if m.pos.y >= cara or m.pos.y > medidas.camara.end.y:
		return
	m.pos.y = cara
	if m.vel.y < _velocidade_do_embolo:
		m.vel.y = 2.0 * maxf(_velocidade_do_embolo, 0.0) - m.vel.y
	# A câmara fechou de vez: quem estava nela desce pelo furo.
	if medidas.camara.end.y - _y_do_embolo < RAIO * 2.0 + 2.0:
		m.pos = Vector2(randf_range(medidas.gargalo.position.x + RAIO, medidas.gargalo.end.x - RAIO), medidas.gargalo.position.y + RAIO + 2.0)
		m.vel = Vector2(randf_range(-30, 30), absf(m.vel.y) + 40.0)


## O vão por onde o gás anda: a câmara (abaixo do êmbolo), o gargalo e o
## cilindro, cada um com a folga do raio. Com a válvula fechada, o cilindro fica
## de fora para quem está na câmara (e vice-versa).
func _dentro(p: Vector2) -> bool:
	var camara := Rect2(medidas.camara.position.x + RAIO, _y_do_embolo + RAIO,
		medidas.camara.size.x - RAIO * 2.0, medidas.camara.end.y - _y_do_embolo - RAIO * 2.0)
	var gargalo := Rect2(medidas.gargalo.position.x + RAIO, medidas.gargalo.position.y - RAIO,
		medidas.gargalo.size.x - RAIO * 2.0, medidas.gargalo.size.y + RAIO * 2.0)
	var cilindro := Rect2(medidas.cilindro.position.x + RAIO, medidas.cilindro.position.y + RAIO,
		medidas.cilindro.size.x - RAIO * 2.0, medidas.cilindro.size.y - RAIO * 2.0)
	if camara.size.y > 0.0 and camara.has_point(p):
		return true
	if cilindro.has_point(p):
		return true
	if _fechamento > 0.5:
		return false
	return gargalo.has_point(p)


func _ponto_mais_perto_dentro(p: Vector2) -> Vector2:
	var cilindro := medidas.cilindro.grow(-RAIO)
	if p.y > medidas.gargalo.position.y or medidas.camara.end.y - _y_do_embolo < RAIO * 2.0 + 2.0:
		return Vector2(clampf(p.x, cilindro.position.x, cilindro.end.x),
			clampf(p.y, cilindro.position.y, cilindro.end.y))
	return Vector2(clampf(p.x, medidas.camara.position.x + RAIO, medidas.camara.end.x - RAIO),
		clampf(p.y, _y_do_embolo + RAIO, medidas.camara.end.y - RAIO))


## Um lugar ao acaso no vão do gás, na proporção da área de cada parte (é o
## gás espalhado por igual).
func _ponto_livre() -> Vector2:
	var area_camara := medidas.camara.size.x * maxf(medidas.camara.end.y - _y_do_embolo, 0.0)
	var area_cilindro := medidas.cilindro.size.x * medidas.cilindro.size.y
	if randf() * (area_camara + area_cilindro) < area_camara and area_camara > 0.0:
		return Vector2(randf_range(medidas.camara.position.x + RAIO, medidas.camara.end.x - RAIO),
			randf_range(_y_do_embolo + RAIO, medidas.camara.end.y - RAIO))
	return Vector2(randf_range(medidas.cilindro.position.x + RAIO, medidas.cilindro.end.x - RAIO),
		randf_range(medidas.cilindro.position.y + RAIO, medidas.cilindro.end.y - RAIO))


# ── O líquido ──

## Quantas moléculas o modelo diz que estão líquidas agora.
func _liquidas_pedidas() -> int:
	if maquina == null:
		return 0
	var total := _moleculas.size() if not _moleculas.is_empty() else _quantas_bolinhas()
	return clampi(roundi(maquina.gas.fracao_liquida * total), 0, total)


func _acertar_o_liquido() -> void:
	var pedidas := _liquidas_pedidas()
	var agora := 0
	for m in _moleculas:
		if m.estado != 0:
			agora += 1
	var trocas := 0
	while agora < pedidas and trocas < TROCAS_POR_QUADRO:
		var m := _escolher(0, true)
		if m == null:
			break
		_virar_gota(m)
		agora += 1
		trocas += 1
	while agora > pedidas and trocas < TROCAS_POR_QUADRO:
		var m := _escolher(2, false)
		if m == null:
			m = _escolher(1, false)
		if m == null:
			break
		_ferver(m)
		agora -= 1
		trocas += 1


## Escolhe uma molécula no estado pedido, com o peso de cada gás: condensando,
## pesa quanto ele se enriquece na primeira gota (o O₂ mais); fervendo, o
## contrário (o N₂ sai primeiro) — e, fervendo, quem está mais em cima da poça.
func _escolher(estado: int, condensando: bool) -> Molecula:
	var t := maquina.gas.temperatura if maquina else 80.0
	var gota := GasFechado.composicao_da_primeira_gota(clampf(t, 65.0, 125.0))
	var total := 0.0
	var pesos: Array[float] = []
	var candidatas: Array[Molecula] = []
	for m in _moleculas:
		if m.estado != estado or m.solta:
			continue
		var enriquecimento := float(gota[m.chave]) / float(GasFechado.COMPOSICAO[m.chave])
		var peso := enriquecimento if condensando else 1.0 / maxf(enriquecimento, 0.01)
		if estado == 2:
			# Da superfície para baixo: as vagas mais altas primeiro.
			peso *= 1.0 + float(m.vaga) * 0.25
		candidatas.append(m)
		pesos.append(peso)
		total += peso
	if candidatas.is_empty():
		return null
	var sorteio := randf() * total
	for i in candidatas.size():
		sorteio -= pesos[i]
		if sorteio <= 0.0:
			return candidatas[i]
	return candidatas.back()


func _virar_gota(m: Molecula) -> void:
	m.estado = 1
	m.vel *= 0.2
	m.vaga = _vaga_livre()
	gotejou.emit()


func _ferver(m: Molecula) -> void:
	m.estado = 0
	m.vaga = -1
	m.sorte = _sortear_sorte()
	m.vel = Vector2(randf_range(-0.6, 0.6), -1.0).normalized() * _velocidade_de(m) * 1.4
	_compactar_poca()


## A gota: cai, escorre pelo chão da câmara até o furo e desce pelo gargalo
## até a vaga dela na poça.
func _mover_gota(m: Molecula, dt: float) -> void:
	var destino := _lugar_da_vaga(m.vaga)
	var na_camara := m.pos.y < medidas.gargalo.position.y - RAIO
	if na_camara:
		m.vel.y += GRAVIDADE_DA_GOTA * dt
		var chao := medidas.camara.end.y - RAIO
		var meio_do_furo := medidas.gargalo.get_center().x
		if m.pos.y + m.vel.y * dt >= chao and absf(m.pos.x - meio_do_furo) > medidas.gargalo.size.x * 0.5 - RAIO:
			# No chão: escorre até o furo.
			m.pos.y = chao
			m.vel.y = 0.0
			m.vel.x = signf(meio_do_furo - m.pos.x) * ESCORRIDA
		else:
			m.vel.x = lerpf(m.vel.x, (meio_do_furo - m.pos.x) * 1.5, 1.0 - exp(-dt / 0.3))
		m.pos += m.vel * dt
		m.pos.x = clampf(m.pos.x, medidas.camara.position.x + RAIO, medidas.camara.end.x - RAIO)
		if m.pos.y < _y_do_embolo + RAIO:
			m.pos.y = _y_do_embolo + RAIO
	else:
		# No gargalo e no cilindro: cai reto para a vaga.
		m.vel.x = (destino.x - m.pos.x) * 4.0
		m.vel.y = minf(m.vel.y + GRAVIDADE_DA_GOTA * dt, 520.0)
		m.pos += m.vel * dt
		if m.pos.y >= destino.y:
			m.pos = destino
			m.vel = Vector2.ZERO
			m.estado = 2


## Na poça a molécula fica na vaga dela, vibrando um tiquinho (no líquido elas
## se encostam, mas não param).
func _assentar(m: Molecula, dt: float) -> void:
	var destino := _lugar_da_vaga(m.vaga)
	m.pos = m.pos.lerp(destino, 1.0 - exp(-dt / 0.08))


func _vaga_livre() -> int:
	var ocupadas := {}
	for m in _moleculas:
		if m.estado != 0 and m.vaga >= 0:
			ocupadas[m.vaga] = true
	var i := 0
	while ocupadas.has(i):
		i += 1
	return i


## Quem ferveu deixou um buraco: a poça se acomoda (as de cima descem).
func _compactar_poca() -> void:
	var na_poca: Array[Molecula] = []
	for m in _moleculas:
		if m.estado != 0 and m.vaga >= 0:
			na_poca.append(m)
	na_poca.sort_custom(func(a: Molecula, b: Molecula) -> bool: return a.vaga < b.vaga)
	for i in na_poca.size():
		na_poca[i].vaga = i


func _por_na_poca(m: Molecula, na_hora: bool) -> void:
	m.estado = 2
	m.vaga = _vaga_livre()
	m.vel = Vector2.ZERO
	if na_hora:
		m.pos = _lugar_da_vaga(m.vaga)


## Onde fica a vaga i da poça: fileiras de NA_FILEIRA a partir do fundo do
## cilindro, uma sim, uma não deslocada meia molécula (como laranjas numa
## caixa).
func _lugar_da_vaga(i: int) -> Vector2:
	var fileira := i / medidas.na_fileira
	var coluna := i % medidas.na_fileira
	var largura := (medidas.cilindro.size.x - RAIO * 2.0) / float(medidas.na_fileira)
	var x := medidas.cilindro.position.x + RAIO + largura * (coluna + 0.5)
	if fileira % 2 == 1:
		x += largura * 0.5 * (1.0 if coluna < medidas.na_fileira - 1 else -1.0)
	var y := medidas.cilindro.end.y - 6.0 - fileira * medidas.altura_da_fileira
	var vibra := Vector2(sin(_tempo * 13.0 + i * 1.7), cos(_tempo * 11.0 + i * 2.3)) * 0.7
	return Vector2(x, y) + vibra


## A altura (y) da superfície da poça.
func _superficie_da_poca() -> float:
	var maior := -1
	for m in _moleculas:
		if m.estado == 2 and not m.solta:
			maior = maxi(maior, m.vaga)
	if maior < 0:
		return medidas.cilindro.end.y
	return medidas.cilindro.end.y - 6.0 - (maior / medidas.na_fileira) * medidas.altura_da_fileira - 6.0


# ─────────────────────────────────────────────────────────────
# A NÉVOA FRIA
# ─────────────────────────────────────────────────────────────
# Ar muito frio é pesado: em volta da serpentina gelada, o vapor da sala
# condensa em névoa, que ESCORRE para baixo (ao contrário da fumaça).

func _animar_nevoa(delta: float) -> void:
	_proxima_nevoa -= delta * _geada * 6.0
	if _geada > 0.15 and _proxima_nevoa <= 0.0 and _nevoa.size() < 40:
		_proxima_nevoa = 1.0
		var lado := -1.0 if randf() < 0.5 else 1.0
		var x := medidas.camara.position.x - medidas.parede - 10.0 if lado < 0.0 else medidas.camara.end.x + medidas.parede + 10.0
		if randf() < nevoa_no_cilindro:
			x = randf_range(medidas.cilindro.position.x - 20.0, medidas.cilindro.end.x + 20.0)
			_nevoa.append({"pos": Vector2(x, randf_range(medidas.cilindro.position.y + 20.0, medidas.cilindro.end.y - 10.0)),
				"vel": Vector2(randf_range(-8, 8), randf_range(10, 22)), "vida": 0.0, "duracao": randf_range(1.6, 2.8),
				"raio": randf_range(5.0, 10.0)})
		else:
			_nevoa.append({"pos": Vector2(x, randf_range(medidas.camara.position.y + 20.0, medidas.camara.end.y)),
				"vel": Vector2(lado * randf_range(4, 14), randf_range(12, 26)), "vida": 0.0,
				"duracao": randf_range(1.6, 2.8), "raio": randf_range(5.0, 11.0)})
	for i in range(_nevoa.size() - 1, -1, -1):
		var n: Dictionary = _nevoa[i]
		n["vida"] = float(n["vida"]) + delta
		n["pos"] = (n["pos"] as Vector2) + (n["vel"] as Vector2) * delta
		n["raio"] = float(n["raio"]) + delta * 3.0
		if float(n["vida"]) >= float(n["duracao"]):
			_nevoa.remove_at(i)


# ─────────────────────────────────────────────────────────────
# A EXPLOSÃO
# ─────────────────────────────────────────────────────────────

func _ao_estourar(_pressao: float) -> void:
	if _fase != Fase.NORMAL:
		return
	_fase = Fase.INCHANDO
	_tempo_da_explosao = 0.0
	_rachaduras.clear()
	estourando.emit()


## Explode na hora (para testar a cena da explosão sem precisar estourar).
func explodir() -> void:
	if maquina:
		maquina.estourado = true
	_ao_estourar(ESCALA_DO_MANOMETRO)


func esta_explodindo() -> bool:
	return _fase != Fase.NORMAL


## De onde a explosão sai (o clarão, a onda de choque, os jatos das
## rachaduras): o meio do cilindro, que é o que estoura.
func _centro_da_explosao() -> Vector2:
	return medidas.cilindro.get_center()


## O cilindro incha, racha e chia; depois, o estrondo.
func _inchar(delta: float) -> void:
	_tempo_da_explosao += delta
	var t := _tempo_da_explosao / TEMPO_DE_INCHAR
	# As rachaduras nascem e crescem pela parede do cilindro.
	if _rachaduras.size() < int(t * 7.0) + 1:
		_rachaduras.append(_nova_rachadura())
	for i in _rachaduras.size():
		var r := _rachaduras[i]
		if r.size() < 7 and randf() < delta * 9.0:
			var ultimo := r[r.size() - 1]
			var anterior := r[r.size() - 2] if r.size() > 1 else ultimo + Vector2(0, -1)
			var rumo := (ultimo - anterior).normalized().rotated(randf_range(-0.9, 0.9))
			r.append((ultimo + rumo * randf_range(5.0, 11.0)).round())
			_rachaduras[i] = r
	# O gás assobia pelas frestas: jatos brancos.
	if t > 0.3 and randf() < delta * (14.0 + t * 30.0):
		var r := _rachaduras[randi() % _rachaduras.size()]
		var ponto: Vector2 = r[r.size() - 1]
		var fora := (ponto - _centro_da_explosao()).normalized()
		_jatos.append({"pos": ponto, "vel": fora.rotated(randf_range(-0.3, 0.3)) * randf_range(160, 260),
			"vida": 0.0, "duracao": randf_range(0.3, 0.6)})
	_animar_jatos(delta)
	if _tempo_da_explosao >= TEMPO_DE_INCHAR:
		_estrondo()


func _nova_rachadura() -> PackedVector2Array:
	var lado := randi() % 3
	var p := Vector2.ZERO
	match lado:
		0:
			p = Vector2(medidas.cilindro.position.x - medidas.parede_do_cilindro * 0.5, randf_range(medidas.cilindro.position.y + 20, medidas.cilindro.end.y - 20))
		1:
			p = Vector2(medidas.cilindro.end.x + medidas.parede_do_cilindro * 0.5, randf_range(medidas.cilindro.position.y + 20, medidas.cilindro.end.y - 20))
		_:
			p = Vector2(randf_range(medidas.cilindro.position.x + 10, medidas.cilindro.end.x - 10), medidas.cilindro.position.y - 2.0)
	return PackedVector2Array([p.round()])


## O estrondo. É uma explosão FÍSICA, sem fogo nenhum: o gás preso rasga o
## aço e se expande de uma vez. Expandindo tão depressa ele esfria, e a umidade
## da sala vira uma nuvem branca (a mesma de um pneu estourando). O que se vê:
## o clarão do instante, a onda de choque, o cilindro em cacos, o volante da
## válvula voando, a nuvem — e as moléculas, todas, indo embora.
func _estrondo() -> void:
	_fase = Fase.ESTOURADA
	_tempo_da_explosao = 0.0
	var centro := _centro_da_explosao()
	# Os cacos do cilindro: pedaços da parede azul (e do aço do gargalo)
	# voando para fora, girando.
	for i in 26:
		var angulo := randf() * TAU
		var tamanho := Vector2(randf_range(6, 24), randf_range(5, 14)).round()
		var origem := centro + Vector2(cos(angulo) * medidas.cilindro.size.x * 0.5, sin(angulo) * medidas.cilindro.size.y * 0.5)
		var cor: Color = [COR_CILINDRO, COR_CILINDRO_CLARO, COR_CILINDRO_ESCURO, COR_ACO][i % 4]
		_cacos.append({"pos": origem, "vel": Vector2.from_angle(angulo) * randf_range(300, 680) + Vector2(0, -200),
			"giro": randf() * TAU, "velocidade_do_giro": randf_range(-14, 14), "tamanho": tamanho,
			"cor": cor, "vida": 0.0, "tipo": "placa"})
	# Os do vidro do manômetro.
	for i in 10:
		var angulo := randf() * TAU
		_cacos.append({"pos": _centro_do_manometro(), "vel": Vector2.from_angle(angulo) * randf_range(180, 420),
			"giro": randf() * TAU, "velocidade_do_giro": randf_range(-16, 16),
			"tamanho": Vector2(randf_range(4, 9), randf_range(3, 6)).round(),
			"cor": Color(0.85, 0.95, 1.0, 0.85), "vida": 0.0, "tipo": "placa"})
	# O volante da válvula, inteiro, voando e rodando.
	if com_valvula:
		_cacos.append({"pos": medidas.volante, "vel": Vector2(-260, -520), "giro": 0.0, "velocidade_do_giro": 22.0,
			"tamanho": Vector2(26, 26), "cor": Color("36f2fb"), "vida": 0.0, "tipo": "volante"})
	# As moléculas, todas, lançadas para fora — as da câmara descem pelo furo
	# primeiro (é o único caminho para fora dela).
	for m in _moleculas:
		m.solta = true
		m.estado = 0
		m.velocidade_do_giro *= 4.0
		if m.pos.y < medidas.gargalo.position.y:
			m.pelo_gargalo = true
			m.vel = (medidas.gargalo.get_center() - m.pos).normalized() * randf_range(700, 1000)
		else:
			var fora := (m.pos - centro)
			if fora.length() < 1.0:
				fora = Vector2.from_angle(randf() * TAU)
			m.vel = fora.normalized().rotated(randf_range(-0.4, 0.4)) * randf_range(500, 1100)
	# A nuvem de condensação (branca) e um pouco de poeira (cinza).
	for i in 26:
		var branca := i % 4 != 0
		_fumaca.append({"pos": centro + Vector2(randf_range(-30, 30), randf_range(-70, 70)),
			"vel": Vector2.from_angle(randf() * TAU) * randf_range(60, 260), "raio": randf_range(12, 26),
			"vida": 0.0, "duracao": randf_range(1.8, 3.0),
			"cor": Color(0.92, 0.96, 1.0) if branca else Color(0.45, 0.46, 0.52)})
	# Faíscas: aço raspando em aço.
	for i in 28:
		_faiscas.append({"pos": centro, "vel": Vector2.from_angle(randf() * TAU) * randf_range(250, 760),
			"vida": 0.0, "duracao": randf_range(0.2, 0.55)})
	estrondo.emit()


func _depois_do_estrondo(delta: float) -> void:
	_tempo_da_explosao += delta
	for c in _cacos:
		c["vel"] = (c["vel"] as Vector2) + Vector2(0, 900) * delta
		c["vel"] = (c["vel"] as Vector2) * pow(0.4, delta)
		c["pos"] = (c["pos"] as Vector2) + (c["vel"] as Vector2) * delta
		c["giro"] = float(c["giro"]) + float(c["velocidade_do_giro"]) * delta
		c["vida"] = float(c["vida"]) + delta
	for m in _moleculas:
		if m.pelo_gargalo:
			# Ainda na câmara: corre para o furo; passou dele, voa para fora.
			if m.pos.y >= medidas.gargalo.end.y:
				m.pelo_gargalo = false
				m.vel = Vector2.from_angle(randf_range(0.0, PI)) * randf_range(500, 1000)
			else:
				var furo := Vector2(medidas.gargalo.get_center().x, medidas.gargalo.end.y + 10.0)
				m.vel = m.vel.lerp((furo - m.pos).normalized() * 900.0, 1.0 - exp(-delta / 0.05))
		else:
			m.vel *= pow(0.25, delta)
		m.pos += m.vel * delta
		m.giro += m.velocidade_do_giro * delta
	for i in range(_fumaca.size() - 1, -1, -1):
		var f: Dictionary = _fumaca[i]
		f["vida"] = float(f["vida"]) + delta
		f["pos"] = (f["pos"] as Vector2) + (f["vel"] as Vector2) * delta
		f["vel"] = (f["vel"] as Vector2) * pow(0.12, delta)
		f["raio"] = float(f["raio"]) + delta * lerpf(70.0, 12.0, clampf(float(f["vida"]) / 0.6, 0.0, 1.0))
		if float(f["vida"]) >= float(f["duracao"]):
			_fumaca.remove_at(i)
	for i in range(_faiscas.size() - 1, -1, -1):
		var s: Dictionary = _faiscas[i]
		s["vida"] = float(s["vida"]) + delta
		s["vel"] = (s["vel"] as Vector2) + Vector2(0, 700) * delta
		s["pos"] = (s["pos"] as Vector2) + (s["vel"] as Vector2) * delta
		if float(s["vida"]) >= float(s["duracao"]):
			_faiscas.remove_at(i)
	_animar_jatos(delta)
	if _tempo_da_explosao >= TEMPO_DEPOIS_DO_ESTRONDO and not _anunciou_fim:
		_anunciou_fim = true
		explosao_terminou.emit()


func _animar_jatos(delta: float) -> void:
	for i in range(_jatos.size() - 1, -1, -1):
		var j: Dictionary = _jatos[i]
		j["vida"] = float(j["vida"]) + delta
		j["pos"] = (j["pos"] as Vector2) + (j["vel"] as Vector2) * delta
		if float(j["vida"]) >= float(j["duracao"]):
			_jatos.remove_at(i)


# ─────────────────────────────────────────────────────────────
# PERGUNTAS DE QUEM USA (o puzzle registra o cabo como alvo)
# ─────────────────────────────────────────────────────────────

## A cara de baixo do êmbolo (y no nó), pela posição da máquina.
func _y_do_embolo_alvo() -> float:
	var posicao := maquina.posicao if maquina else 0.0
	return lerpf(medidas.camara.position.y, medidas.camara.end.y, posicao)


## O cabo do êmbolo (a barra onde se pega para arrastar), em px do nó.
func retangulo_do_cabo() -> Rect2:
	var m := medidas
	var topo := _y_do_embolo - m.espessura_do_embolo - m.haste - m.cabo.y + m.cabo_sobre_a_haste
	return Rect2(m.gargalo.get_center().x - m.cabo.x * 0.5, topo, m.cabo.x, m.cabo.y)


## O mesmo, na tela.
func retangulo_do_cabo_na_tela() -> Rect2:
	var r := retangulo_do_cabo()
	return Rect2(global_position + r.position, r.size)


## A área inteira em que pegar arrasta o êmbolo: o cabo, a haste e a placa.
func retangulo_de_pegar_o_embolo() -> Rect2:
	var de_cima := retangulo_do_cabo().position.y - 2.0
	return Rect2(medidas.camara.position.x, de_cima, medidas.camara.size.x, _y_do_embolo - de_cima)


## O mesmo, na tela.
func retangulo_de_pegar_o_embolo_na_tela() -> Rect2:
	var r := retangulo_de_pegar_o_embolo()
	return Rect2(global_position + r.position, r.size)


## A posição do êmbolo (0 a 1) que deixa o meio do cabo na altura y (px da
## tela, mais a "pegada": a distância do ponteiro ao meio do cabo).
func posicao_no_ponto_da_tela(y_tela: float, pegada: float = 0.0) -> float:
	var y := y_tela - global_position.y + pegada
	var do_cabo_ao_embolo := _y_do_embolo - retangulo_do_cabo().get_center().y
	return clampf(inverse_lerp(medidas.camara.position.y, medidas.camara.end.y, y + do_cabo_ao_embolo), 0.0, 1.0)


## Onde o manômetro está, na tela (para quem quiser destacar).
func retangulo_do_manometro_na_tela() -> Rect2:
	return Rect2(global_position + _centro_do_manometro() - Vector2.ONE * medidas.manometro_raio,
		Vector2.ONE * medidas.manometro_raio * 2.0)


func retangulo_do_cilindro_na_tela() -> Rect2:
	return Rect2(global_position + medidas.cilindro.position - Vector2.ONE * medidas.parede_do_cilindro,
		medidas.cilindro.size + Vector2.ONE * medidas.parede_do_cilindro * 2.0)


func retangulo_da_valvula_na_tela() -> Rect2:
	return Rect2(global_position + medidas.valvula.position - Vector2(36, 8), medidas.valvula.size + Vector2(44, 16))


## Quantas moléculas estão, de fato, desenhadas dentro do cilindro (gargalo
## incluído). É o que se vê; o número do modelo é o fracao_no_cilindro().
func moleculas_no_cilindro() -> int:
	var conta := 0
	for m in _moleculas:
		if m.solta:
			continue
		if m.estado != 0 or m.pos.y >= medidas.gargalo.position.y:
			conta += 1
	return conta


func moleculas_liquidas() -> int:
	var conta := 0
	for m in _moleculas:
		if m.estado == 2 and not m.solta:
			conta += 1
	return conta


# ─────────────────────────────────────────────────────────────
# O DESENHO
# ─────────────────────────────────────────────────────────────

func _draw() -> void:
	if maquina == null:
		return
	if medidas.no_mapa():
		_desenhar_no_mapa()
		return
	draw_set_transform(_tremor)
	_desenhar_serpentina_de_tras()
	_desenhar_vao()
	_desenhar_liquido()
	# Estourado, as moléculas voam por cima de tudo (ver _desenhar_explosao).
	if _fase != Fase.ESTOURADA:
		_desenhar_moleculas()
	_desenhar_embolo()
	_desenhar_paredes()
	if _fase != Fase.ESTOURADA:
		_desenhar_cilindro()
	_desenhar_serpentina_da_frente()
	_desenhar_valvula()
	_desenhar_manometro()
	_desenhar_garras()
	_desenhar_geada()
	_desenhar_nevoa()
	_desenhar_rachaduras()
	if com_nomes and _fase == Fase.NORMAL:
		_desenhar_nomes()
	draw_set_transform(Vector2.ZERO)
	if _fase == Fase.ESTOURADA:
		_desenhar_explosao()


# ── No mapa ──
# Aberta em cima da máquina do mapa (medidas_do_mapa), a câmara é desenhada
# na grade da arte do compressor (ArteDoCompressor), medidas.pixel px por
# pixel dela. O que é igual por fora vem da própria arte — as paredes e o fundo
# da câmara, a válvula, a cabeça do berço, as garras, o volante, o cabo e o
# cilindro (o mesmo do mapa) — e só o que o raio X mostra por dentro é
# desenhado: o vão com o ar, o êmbolo descendo, a poça, a serpentina dentro das
# paredes, a comporta da válvula e o mostrador do manômetro. Por isso a troca da
# arte pelo raio X não pula: a moldura é a mesma, pixel por pixel.

func _desenhar_no_mapa() -> void:
	draw_set_transform(_tremor)
	_desenhar_canos_de_tras()
	_desenhar_vao()
	_desenhar_liquido()
	if _fase != Fase.ESTOURADA:
		_desenhar_moleculas()
		_desenhar_cilindro_no_mapa()
	_desenhar_aparelho_vazado()
	_desenhar_serpentina_no_mapa()
	_desenhar_embolo_no_mapa()
	_desenhar_garras_no_mapa()
	_desenhar_valvula_no_mapa()
	_desenhar_manometro()
	_desenhar_geada()
	_desenhar_nevoa()
	_desenhar_rachaduras()
	if com_nomes and _fase == Fase.NORMAL:
		_desenhar_nomes()
	draw_set_transform(Vector2.ZERO)
	if _fase == Fase.ESTOURADA:
		_desenhar_explosao()


## Os canos do resfriador, por trás da máquina, por cima dos da arte: na
## temperatura da sala, com as cores dela (o azul dos canos); quanto mais longe
## dela, mais na cor da serpentina (a luz em cima, a sombra embaixo).
const CORES_DOS_CANOS_NA_ARTE: Array[Color] = [Color("dcf5ff"), Color("8fd8ff"), Color("5096c8")]

func _desenhar_canos_de_tras() -> void:
	var celsius := GasFechado.para_celsius(maquina.temperatura_da_serpentina)
	var cor := _cor_da_temperatura(celsius)
	var longe_da_sala := clampf(absf(celsius - GasFechado.para_celsius(MaquinaDeCompressao.TEMPERATURA_DA_SALA)) / 60.0, 0.0, 1.0)
	var luz := CORES_DOS_CANOS_NA_ARTE[0].lerp(cor.lightened(0.45), longe_da_sala)
	var meio := CORES_DOS_CANOS_NA_ARTE[1].lerp(cor, longe_da_sala)
	var sombra := CORES_DOS_CANOS_NA_ARTE[2].lerp(cor.darkened(0.4), longe_da_sala)
	var p := medidas.pixel
	for faixa in medidas.canos_de_tras:
		draw_rect(faixa, meio)
		draw_rect(Rect2(faixa.position, Vector2(faixa.size.x, p)), luz)
		draw_rect(Rect2(faixa.position.x, faixa.end.y - p, faixa.size.x, p), sombra)


## A serpentina: sobe pelas pernas e anda em zigue-zague dentro das paredes.
func _desenhar_serpentina_no_mapa() -> void:
	var cor := _cor_da_temperatura(GasFechado.para_celsius(maquina.temperatura_da_serpentina))
	for cano in medidas.serpentina:
		_desenhar_cano(cano, cor, 4.0)


## A arte do aparelho, vazada onde o raio X desenha outra coisa: o miolo da
## câmara (com a borda de cima, que é a placa do êmbolo), o canal do gargalo
## (pela válvula e pela cabeça do berço), as garras e o volante.
func _desenhar_aparelho_vazado() -> void:
	var A := ArteDoCompressor
	var buracos: Array[Rect2i] = [
		Rect2i(A.CAMARA.position.x, A.CASCO.position.y, A.CAMARA.size.x, A.CAMARA.end.y - A.CASCO.position.y),
		A.GARGALO, A.quadrado_do_volante()]
	buracos.append_array(A.garras())
	var arte := _arte_vazada(medidas.arte_do_aparelho, buracos)
	if arte:
		draw_texture_rect(arte, Rect2(Vector2.ZERO, Vector2(arte.get_size()) * medidas.pixel), false)


## O cilindro: a arte dele (a mesma do mapa: a de sempre ou, com o ar bem frio,
## a gelada), com o vão de dentro e o canal do gargalo vazados — o gás e a poça já estão desenhados por baixo. Estourando,
## ele incha e treme.
func _desenhar_cilindro_no_mapa() -> void:
	var A := ArteDoCompressor
	var canal := Rect2i(A.GARGALO.position.x - A.CILINDRO.x, 0, A.GARGALO.size.x, A.GARGALO.end.y - A.CILINDRO.y)
	var buracos: Array[Rect2i] = [A.VAO_NA_ARTE_DO_CILINDRO, canal]
	# Com o ar bem frio, a arte gelada (a mesma regra do mapa: CompressorDeAr).
	var textura := medidas.arte_do_cilindro
	if medidas.arte_do_cilindro_gelado and maquina.gas.celsius() < A.CILINDRO_GELA_ABAIXO_DE:
		textura = medidas.arte_do_cilindro_gelado
	var arte := _arte_vazada(textura, buracos)
	if arte == null:
		return
	var r := Rect2(medidas.canto_do_cilindro, Vector2(arte.get_size()) * medidas.pixel)
	if _fase == Fase.INCHANDO:
		var inchaco := ease(_tempo_da_explosao / TEMPO_DE_INCHAR, 2.2) * r.size.x * 0.06
		r = r.grow_individual(inchaco, 0.0, inchaco, 0.0)
		r.position.x += roundf(sin(_tempo * 60.0) * 2.0)
	draw_texture_rect(arte, r, false)
	# A pintura azul por dentro das paredes (no raio X, o miolo é o gás): a
	# luz à esquerda, a sombra à direita, como na arte.
	var largura_da_arte := float(arte.get_width())
	var vao := ArteDoCompressor.VAO_NA_ARTE_DO_CILINDRO
	var de_x := r.position.x + r.size.x * vao.position.x / largura_da_arte
	var ate_x := r.position.x + r.size.x * vao.end.x / largura_da_arte
	var faixa := roundf(medidas.pixel * 0.5)
	draw_rect(Rect2(de_x, medidas.cilindro.position.y, faixa, medidas.cilindro.size.y), COR_CILINDRO_CLARO)
	draw_rect(Rect2(ate_x - faixa, medidas.cilindro.position.y, faixa, medidas.cilindro.size.y), COR_CILINDRO_ESCURO)


## O cabo com a haste (a arte dele) e, embaixo, a placa do êmbolo: a borda de
## cima da câmara na arte (o contorno e as duas linhas de aço), descendo junto.
## O desenho anda de pixel em pixel da arte (a conta das moléculas segue lisa).
## Com o ponteiro em cima, a barra fica amarela.
func _desenhar_embolo_no_mapa() -> void:
	var A := ArteDoCompressor
	var p := medidas.pixel
	var descida := roundf((_y_do_embolo - medidas.camara.position.y) / p) * p
	var cabo := retangulo_do_cabo()
	cabo.position.y += medidas.camara.position.y + descida - _y_do_embolo
	if medidas.arte_do_cabo:
		draw_texture_rect(medidas.arte_do_cabo, Rect2(cabo.position, Vector2(cabo.size.x, cabo.size.y + medidas.haste)), false)
	if cabo_em_foco:
		var barra := cabo.grow(-p)
		draw_rect(barra, COR_AMARELO)
		draw_rect(Rect2(barra.position, Vector2(barra.size.x, p)), COR_AMARELO.lightened(0.45))
	var borda := Rect2i(A.CAMARA.position.x, A.CASCO.position.y, A.CAMARA.size.x, A.CAMARA.position.y - A.CASCO.position.y)
	if medidas.arte_do_aparelho:
		draw_texture_rect_region(medidas.arte_do_aparelho,
			Rect2(Vector2(borda.position) * p + Vector2(0.0, descida), Vector2(borda.size) * p), Rect2(borda))


## As garras (a arte delas), que se abrem um pixel por vez quando o cilindro é
## solto.
func _desenhar_garras_no_mapa() -> void:
	if medidas.arte_do_aparelho == null:
		return
	var p := medidas.pixel
	var abre := roundf(_abertura_das_garras * 2.0) * p
	var garras := ArteDoCompressor.garras()
	for i in garras.size():
		var g := garras[i]
		var para_fora := -abre if i == 0 else abre
		draw_texture_rect_region(medidas.arte_do_aparelho,
			Rect2(Vector2(g.position) * p + Vector2(para_fora, 0.0), Vector2(g.size) * p), Rect2(g))


## A comporta da válvula (desce no canal quando ela fecha) e o volante (a arte
## dele), com os raios girando enquanto fecha. Estourado, o volante saiu voando.
func _desenhar_valvula_no_mapa() -> void:
	var p := medidas.pixel
	if _fechamento > 0.0:
		var canal := Rect2(medidas.gargalo.position.x, medidas.valvula.position.y, medidas.gargalo.size.x, medidas.valvula.size.y)
		var comporta := Rect2(canal.position, Vector2(canal.size.x, roundf(canal.size.y * _fechamento)))
		draw_rect(comporta, Color("c0392b"))
		draw_rect(Rect2(comporta.position.x, comporta.end.y - 3.0, comporta.size.x, 3.0), Color("7b1d14"))
	if _fase == Fase.ESTOURADA or not com_valvula or medidas.arte_do_aparelho == null:
		return
	var q := ArteDoCompressor.quadrado_do_volante()
	draw_texture_rect_region(medidas.arte_do_aparelho, Rect2(Vector2(q.position) * p, Vector2(q.size) * p), Rect2(q))
	if _fechamento > 0.0 and _fechamento < 1.0:
		var c := medidas.volante
		for i in 3:
			var a := _giro_do_volante + i * TAU / 3.0
			draw_line(c, c + Vector2.from_angle(a) * medidas.raio_do_volante * 0.65, Color("0b4e52"), 3.0)
		draw_rect(Rect2(c - Vector2.ONE * p * 0.5, Vector2.ONE * p), EstiloHUD.CONTORNO)


## Uma arte com retângulos transparentes (px dela), feita uma vez para cada
## arte e cada jeito de vazar.
static var _artes_vazadas := {}

func _arte_vazada(textura: Texture2D, buracos: Array[Rect2i]) -> Texture2D:
	if textura == null:
		return null
	var chave := "%d %s" % [textura.get_instance_id(), str(buracos)]
	if not _artes_vazadas.has(chave):
		var imagem := textura.get_image()
		if imagem.is_compressed():
			imagem.decompress()
		imagem.convert(Image.FORMAT_RGBA8)
		for buraco in buracos:
			imagem.fill_rect(buraco, Color(0, 0, 0, 0))
		_artes_vazadas[chave] = ImageTexture.create_from_image(imagem)
	return _artes_vazadas[chave]


# ── Peças ──

func _cor_da_temperatura(celsius: float) -> Color:
	if celsius <= 20.0:
		return COR_FRIO.lerp(COR_ACO_CLARO, clampf(inverse_lerp(-190.0, 20.0, celsius), 0.0, 1.0))
	return COR_ACO_CLARO.lerp(COR_QUENTE, clampf(inverse_lerp(20.0, 150.0, celsius), 0.0, 1.0))


func _desenhar_vao() -> void:
	var cor := _cor_do_vao_agora()
	# A câmara inteira (a parte de cima, acima do êmbolo, é o lado de fora da
	# câmara: mais escura e sem gás). No mapa, ela fica aberta, como na arte:
	# acima do êmbolo aparece a sala.
	if not medidas.no_mapa():
		draw_rect(Rect2(medidas.camara.position.x, medidas.topo_das_paredes, medidas.camara.size.x,
			medidas.camara.end.y - medidas.topo_das_paredes), COR_VAO.darkened(0.35))
	draw_rect(Rect2(medidas.camara.position.x, _y_do_embolo, medidas.camara.size.x, medidas.camara.end.y - _y_do_embolo), cor)
	draw_rect(medidas.gargalo, cor)
	draw_rect(medidas.cilindro, cor)
	# A grade de raio X, bem fraca, no vão do gás.
	var grade := Color(1, 1, 1, 0.035)
	var x := medidas.camara.position.x + 24.0
	while x < medidas.camara.end.x:
		draw_rect(Rect2(x, _y_do_embolo, 2.0, medidas.camara.end.y - _y_do_embolo), grade)
		x += 24.0


func _desenhar_liquido() -> void:
	var superficie := _superficie_da_poca()
	if superficie >= medidas.cilindro.end.y - 0.5:
		return
	var poca := Rect2(medidas.cilindro.position.x, superficie, medidas.cilindro.size.x, medidas.cilindro.end.y - superficie)
	draw_rect(poca, COR_LIQUIDO)
	# A tona: uma linha clara que ondula.
	var x := medidas.cilindro.position.x
	while x < medidas.cilindro.end.x:
		var onda := roundf(sin(_tempo * 4.0 + x * 0.21) * 1.2)
		draw_rect(Rect2(x, superficie + onda, 4.0, 2.0), COR_LIQUIDO_TONA)
		x += 4.0


func _desenhar_moleculas() -> void:
	for m in _moleculas:
		if m.solta and _fase != Fase.ESTOURADA:
			continue
		var quadro := 0 if m.estado == 2 else int(floor(m.giro)) % MoleculasDoDestilador.QUADROS
		MoleculasDoDestilador.desenhar(self, m.chave, m.pos, quadro, AMPLIACAO)


func _desenhar_embolo() -> void:
	var y := roundf(_y_do_embolo)
	var placa := Rect2(medidas.camara.position.x, y - medidas.espessura_do_embolo, medidas.camara.size.x, medidas.espessura_do_embolo)
	# A haste e o cabo.
	var meio := medidas.gargalo.get_center().x
	var haste := Rect2(meio - 9.0, y - medidas.espessura_do_embolo - medidas.haste, 18.0, medidas.haste)
	draw_rect(haste.grow(2.0), EstiloHUD.CONTORNO)
	draw_rect(haste, COR_ACO)
	draw_rect(Rect2(haste.position.x + 3.0, haste.position.y, 3.0, haste.size.y), COR_ACO_CLARO)
	var cabo := retangulo_do_cabo()
	cabo = Rect2(cabo.position.x + 14.0, cabo.position.y + 4.0, cabo.size.x - 28.0, 18.0)
	draw_rect(cabo.grow(2.0), EstiloHUD.CONTORNO)
	draw_rect(cabo, COR_AMARELO if cabo_em_foco else Color("d65a31"))
	draw_rect(Rect2(cabo.position.x + 2.0, cabo.position.y + 2.0, cabo.size.x - 4.0, 4.0),
		Color(1, 1, 1, 0.35))
	# A placa, com as duas vedações de borracha.
	draw_rect(placa.grow(2.0), EstiloHUD.CONTORNO)
	draw_rect(placa, COR_ACO)
	draw_rect(Rect2(placa.position.x, placa.position.y, placa.size.x, 3.0), COR_ACO_CLARO)
	draw_rect(Rect2(placa.position.x, placa.end.y - 6.0, placa.size.x, 3.0), Color("1b1b24"))
	draw_rect(Rect2(placa.position.x, placa.position.y + 7.0, placa.size.x, 3.0), Color("1b1b24"))


func _desenhar_paredes() -> void:
	# As duas paredes da câmara, do alto até o fundo, e o fundo com o furo.
	var esquerda := Rect2(medidas.camara.position.x - medidas.parede, 0.0, medidas.parede, medidas.camara.end.y + medidas.parede)
	var direita := Rect2(medidas.camara.end.x, 0.0, medidas.parede, medidas.camara.end.y + medidas.parede)
	for parede: Rect2 in [esquerda, direita]:
		draw_rect(parede.grow(2.0), EstiloHUD.CONTORNO)
		draw_rect(parede, COR_ACO)
		draw_rect(Rect2(parede.position.x + 2.0, parede.position.y, 2.0, parede.size.y), COR_ACO_CLARO)
	var fundo_esq := Rect2(medidas.camara.position.x - medidas.parede, medidas.camara.end.y, medidas.gargalo.position.x - medidas.camara.position.x + medidas.parede, medidas.parede)
	var fundo_dir := Rect2(medidas.gargalo.end.x, medidas.camara.end.y, medidas.camara.end.x + medidas.parede - medidas.gargalo.end.x, medidas.parede)
	for fundo: Rect2 in [fundo_esq, fundo_dir]:
		draw_rect(Rect2(fundo.position.x, fundo.position.y, fundo.size.x, fundo.size.y + 2.0), EstiloHUD.CONTORNO)
		draw_rect(fundo, COR_ACO)
		draw_rect(Rect2(fundo.position.x, fundo.position.y, fundo.size.x, 2.0), COR_ACO_CLARO)
	# Os rebites.
	for y in range(20, int(medidas.camara.end.y), 48):
		for x: float in [medidas.camara.position.x - medidas.parede * 0.5, medidas.camara.end.x + medidas.parede * 0.5]:
			draw_rect(Rect2(x - 1.0, y, 2.0, 2.0), COR_ACO_ESCURO)
	# O gargalo: duas paredinhas descendo até o cilindro.
	for x: float in [medidas.gargalo.position.x - 6.0, medidas.gargalo.end.x]:
		var parede := Rect2(x, medidas.gargalo.position.y, 6.0, medidas.gargalo.size.y)
		draw_rect(parede.grow(1.0), EstiloHUD.CONTORNO)
		draw_rect(parede, COR_ACO)


func _desenhar_cilindro() -> void:
	var p := medidas.parede_do_cilindro
	# O inchaço da explosão estica a parede para fora.
	var inchaco := 0.0
	if _fase == Fase.INCHANDO:
		inchaco = roundf(ease(_tempo_da_explosao / TEMPO_DE_INCHAR, 2.2) * 7.0 + sin(_tempo * 60.0) * 1.0)
	var vao := medidas.cilindro.grow_individual(inchaco, 0.0, inchaco, inchaco * 0.5)
	var fora := vao.grow(p)
	# O corpo azul: as laterais, o fundo arredondado e os ombros até o gargalo.
	var cor := COR_CILINDRO
	var contorno := EstiloHUD.CONTORNO
	var lados := [Rect2(fora.position.x, vao.position.y + 6.0, p, vao.size.y - 6.0),
		Rect2(vao.end.x, vao.position.y + 6.0, p, vao.size.y - 6.0)]
	for lado: Rect2 in lados:
		draw_rect(lado.grow(2.0), contorno)
		draw_rect(lado, cor)
	# O brilho da pintura (o de cima à esquerda, igual à arte do mapa).
	draw_rect(Rect2(fora.position.x + 2.0, vao.position.y + 10.0, 3.0, vao.size.y - 20.0), COR_CILINDRO_CLARO)
	draw_rect(Rect2(vao.end.x + p - 3.0, vao.position.y + 10.0, 2.0, vao.size.y - 20.0), COR_CILINDRO_ESCURO)
	# O fundo: arredondado em degraus.
	var fundo := Rect2(fora.position.x + 4.0, vao.end.y, fora.size.x - 8.0, p)
	draw_rect(fundo.grow(2.0), contorno)
	draw_rect(fundo, cor)
	draw_rect(Rect2(fora.position.x + 2.0, vao.end.y - 2.0, 4.0, 6.0), cor)
	draw_rect(Rect2(fora.end.x - 6.0, vao.end.y - 2.0, 4.0, 6.0), cor)
	# Os ombros, em escada, do corpo até o gargalo.
	var degraus := 4
	for i in degraus:
		var t := float(i) / degraus
		var meio_largura := lerpf(fora.size.x * 0.5, medidas.gargalo.size.x * 0.5 + 8.0, t)
		var y := vao.position.y - 2.0 - i * 3.0
		var faixa := Rect2(medidas.cilindro.get_center().x - meio_largura, y, meio_largura * 2.0, 4.0)
		draw_rect(faixa.grow(1.0), contorno)
		draw_rect(faixa, cor if i < degraus - 1 else COR_CILINDRO_ESCURO)
	# O vão de cima entre o ombro e o gargalo (o gás passa).
	draw_rect(Rect2(medidas.gargalo.position.x, vao.position.y - 14.0, medidas.gargalo.size.x, 16.0), _cor_do_vao_agora())
	# O pé.
	draw_rect(Rect2(fora.position.x + 8.0, fora.end.y, fora.size.x - 16.0, 6.0), Color("1b1b24"))


func _cor_do_vao_agora() -> Color:
	var c := maquina.gas.celsius()
	if c < 0.0:
		return COR_VAO.lerp(COR_VAO_FRIO, clampf(inverse_lerp(0.0, -190.0, c), 0.0, 1.0))
	if c > 40.0:
		return COR_VAO.lerp(COR_VAO_QUENTE, clampf(inverse_lerp(40.0, 200.0, c), 0.0, 1.0))
	return COR_VAO


func _desenhar_valvula() -> void:
	var corpo := medidas.valvula
	draw_rect(corpo.grow(2.0), EstiloHUD.CONTORNO)
	draw_rect(corpo, COR_ACO)
	draw_rect(Rect2(corpo.position.x, corpo.position.y, corpo.size.x, 3.0), COR_ACO_CLARO)
	# O canal por dentro: aberto, ele mostra o gás; fechado, a comporta desce.
	var canal := Rect2(medidas.gargalo.position.x, corpo.position.y + 2.0, medidas.gargalo.size.x, corpo.size.y - 4.0)
	draw_rect(canal, _cor_do_vao_agora())
	if _fechamento > 0.0:
		var comporta := Rect2(canal.position.x - 2.0, canal.position.y, canal.size.x + 4.0,
			canal.size.y * _fechamento)
		draw_rect(comporta, Color("c0392b"))
		draw_rect(Rect2(comporta.position.x, comporta.end.y - 2.0, comporta.size.x, 2.0), Color("7b1d14"))
	# O volante, girando quando fecha (estourado, ele saiu voando).
	if _fase == Fase.ESTOURADA or not com_valvula:
		return
	draw_line(medidas.volante + Vector2(12, 0), Vector2(corpo.position.x, medidas.volante.y), EstiloHUD.CONTORNO, 6.0)
	draw_line(medidas.volante + Vector2(12, 0), Vector2(corpo.position.x, medidas.volante.y), COR_ACO, 3.0)
	draw_circle(medidas.volante, 13.0, EstiloHUD.CONTORNO)
	draw_circle(medidas.volante, 11.0, Color("36f2fb"))
	draw_circle(medidas.volante, 7.0, Color("1c9ca2"))
	for i in 3:
		var a := _giro_do_volante + i * TAU / 3.0
		draw_line(medidas.volante, medidas.volante + Vector2.from_angle(a) * 10.0, Color("0b4e52"), 2.0)
	draw_circle(medidas.volante, 3.0, EstiloHUD.CONTORNO)


## O meio do mostrador do manômetro.
func _centro_do_manometro() -> Vector2:
	return medidas.manometro_centro


## O cano que leva a pressão ao manômetro: da válvula, no gargalo, até o
## mostrador.
func _desenhar_cano_do_manometro() -> void:
	var c := _centro_do_manometro()
	var cano := Rect2(medidas.valvula.end.x, medidas.valvula.position.y + 8.0, c.x - medidas.valvula.end.x, 8.0)
	draw_rect(cano.grow(2.0), EstiloHUD.CONTORNO)
	draw_rect(cano, COR_ACO)
	var descida := Rect2(c.x - 4.0, cano.position.y, 8.0, c.y - medidas.manometro_raio - cano.position.y + 4.0)
	draw_rect(descida.grow(2.0), EstiloHUD.CONTORNO)
	draw_rect(descida, COR_ACO)


func _desenhar_manometro() -> void:
	var c := _centro_do_manometro()
	var r := medidas.manometro_raio
	if not medidas.no_mapa():
		_desenhar_cano_do_manometro()
	# O mostrador: aro de aço, papel, as três faixas, os riscos e os números.
	draw_circle(c, r + 5.0, EstiloHUD.CONTORNO)
	draw_circle(c, r + 3.0, COR_ACO)
	var p := maquina.pressao()
	var faixa := maquina.faixa_da_pressao(p)
	var papel := EstiloHUD.PAPEL
	if faixa == 2 or _fase != Fase.NORMAL:
		papel = papel.lerp(COR_VERMELHO, 0.35 + 0.25 * sin(_tempo * 30.0))
	elif faixa == 1:
		papel = papel.lerp(COR_AMARELO, 0.25 + 0.2 * sin(_tempo * 12.0))
	draw_circle(c, r, papel)
	var trabalho := MaquinaDeCompressao.PRESSAO_DE_TRABALHO
	var ruptura := MaquinaDeCompressao.PRESSAO_DE_RUPTURA
	_arco_da_escala(c, r - 7.0, 0.0, trabalho, COR_VERDE)
	_arco_da_escala(c, r - 7.0, trabalho, ruptura, COR_AMARELO)
	_arco_da_escala(c, r - 7.0, ruptura, ESCALA_DO_MANOMETRO, COR_VERMELHO)
	for i in int(ESCALA_DO_MANOMETRO * 2.0) + 1:
		var atm := i * 0.5
		var a := _angulo_do_manometro(atm)
		var comprido := i % 2 == 0
		var de := c + Vector2.from_angle(a) * (r - (14.0 if comprido else 11.0))
		var ate := c + Vector2.from_angle(a) * (r - 3.0)
		draw_line(de, ate, EstiloHUD.TINTA, 2.0)
		if comprido:
			var texto := str(int(atm))
			var onde := c + Vector2.from_angle(a) * (r - 24.0)
			var largura := FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(FONTE, (onde + Vector2(-largura * 0.5, 4.0)).round(), texto,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, EstiloHUD.TINTA)
	var unidade := "atm"
	var largura_u := FONTE.get_string_size(unidade, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(FONTE, (c + Vector2(-largura_u * 0.5, 34.0)).round(), unidade,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, EstiloHUD.TINTA_FRACA)
	# O ponteiro (treme perto da ruptura) e o pino do meio.
	var tremida := 0.0
	if faixa >= 1 or _fase != Fase.NORMAL:
		tremida = randf_range(-0.04, 0.04) * (2.0 if faixa == 2 or _fase != Fase.NORMAL else 1.0)
	var angulo := _angulo_do_manometro(clampf(_ponteiro, 0.0, ESCALA_DO_MANOMETRO + 0.35)) + tremida
	var ponta := c + Vector2.from_angle(angulo) * (r - 9.0)
	draw_line(c, ponta, Color("1b1b24"), 4.0)
	draw_line(c, ponta, Color("e8463a"), 2.0)
	draw_circle(c, 5.0, EstiloHUD.CONTORNO)
	draw_circle(c, 3.0, COR_ACO)
	# O vidro: um reflexo, e trincas quando a pressão passa da conta.
	if _fase == Fase.NORMAL:
		draw_arc(c, r - 4.0, PI * 1.1, PI * 1.45, 6, Color(1, 1, 1, 0.45), 2.0)
	if _fase == Fase.INCHANDO and _tempo_da_explosao > 0.4:
		for i in 4:
			var a := 0.6 + i * 1.7
			draw_line(c + Vector2.from_angle(a) * 6.0, c + Vector2.from_angle(a + 0.3) * (r - 2.0),
				Color(1, 1, 1, 0.8), 1.0)
	if _fase == Fase.ESTOURADA:
		draw_circle(c, r, Color(0, 0, 0, 0.35))


func _angulo_do_manometro(atm: float) -> float:
	# 0 atm embaixo à esquerda, o máximo embaixo à direita: 270° de escala.
	return deg_to_rad(135.0) + deg_to_rad(270.0) * atm / ESCALA_DO_MANOMETRO


func _arco_da_escala(c: Vector2, r: float, de: float, ate: float, cor: Color) -> void:
	draw_arc(c, r, _angulo_do_manometro(de), _angulo_do_manometro(ate), 16, cor, 5.0)


func _desenhar_garras() -> void:
	# Duas garras de aço, uma de cada lado do cilindro. Abrem quando ele é solto.
	var abre := _abertura_das_garras * 10.0
	var y := medidas.cilindro.position.y + 64.0
	for lado: float in [-1.0, 1.0]:
		var x := medidas.cilindro.position.x - medidas.parede_do_cilindro - 14.0 - abre if lado < 0.0 \
			else medidas.cilindro.end.x + medidas.parede_do_cilindro + abre
		var garra := Rect2(x, y, 14.0, 22.0)
		draw_rect(garra.grow(2.0), EstiloHUD.CONTORNO)
		draw_rect(garra, Color("3a4160"))
		draw_rect(Rect2(garra.position.x, garra.position.y, garra.size.x, 3.0), COR_ACO)
		var braco_x := garra.position.x - 20.0 if lado < 0.0 else garra.end.x
		draw_rect(Rect2(braco_x, y + 8.0, 20.0, 6.0), Color("3a4160"))


## Os pontos do cano da serpentina numa parede: ele desce colado nela, indo e
## voltando (as voltas são o que aumenta a área que troca calor).
func _cano_da_serpentina(x_de_dentro: float, para_fora: float) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	var y := medidas.camara.position.y - 30.0
	pontos.append(Vector2(x_de_dentro + para_fora * 6.0, y))
	y = medidas.camara.position.y + 8.0
	var lado := 0
	while y < medidas.camara.end.y - 6.0:
		var x := x_de_dentro + para_fora * (4.0 if lado == 0 else 16.0)
		pontos.append(Vector2(x, y))
		pontos.append(Vector2(x, y + 14.0))
		y += 22.0
		lado = 1 - lado
	return pontos


func _desenhar_cano(pontos: PackedVector2Array, cor: Color, grossura: float) -> void:
	draw_polyline(pontos, EstiloHUD.CONTORNO, grossura + 4.0)
	draw_polyline(pontos, cor, grossura)
	# O brilho do metal, um fio claro por cima.
	draw_polyline(pontos, Color(1, 1, 1, 0.22), 2.0)


func _desenhar_serpentina_de_tras() -> void:
	# O cano que desce colado nas duas paredes da câmara.
	var cor := _cor_da_temperatura(GasFechado.para_celsius(maquina.temperatura_da_serpentina))
	_desenhar_cano(_cano_da_serpentina(medidas.camara.position.x - medidas.parede, -1.0), cor, 6.0)
	_desenhar_cano(_cano_da_serpentina(medidas.camara.end.x + medidas.parede, 1.0), cor, 6.0)
	# A ligação de cima: as duas pontas vão para o resfriador (à direita, fora
	# do nó, onde fica o termômetro dele).
	var entrada := PackedVector2Array([Vector2(medidas.camara.position.x - medidas.parede - 6.0, medidas.camara.position.y - 30.0),
		Vector2(medidas.camara.position.x - medidas.parede - 6.0, medidas.camara.position.y - 52.0),
		Vector2(size.x, medidas.camara.position.y - 52.0)])
	_desenhar_cano(entrada, cor, 6.0)
	var volta := PackedVector2Array([Vector2(medidas.camara.end.x + medidas.parede + 6.0, medidas.camara.position.y - 30.0),
		Vector2(medidas.camara.end.x + medidas.parede + 6.0, medidas.camara.position.y - 38.0), Vector2(size.x, medidas.camara.position.y - 38.0)])
	_desenhar_cano(volta, cor, 6.0)


func _desenhar_serpentina_da_frente() -> void:
	# A jaqueta do cilindro: duas voltas finas do cano por fora dele.
	var cor := _cor_da_temperatura(GasFechado.para_celsius(maquina.temperatura_da_serpentina))
	cor.a = 0.8
	for i in 2:
		var y := medidas.cilindro.position.y + 50.0 + i * 74.0
		var volta := Rect2(medidas.cilindro.position.x - medidas.parede_do_cilindro - 4.0, y,
			medidas.cilindro.size.x + medidas.parede_do_cilindro * 2.0 + 8.0, 5.0)
		draw_rect(volta.grow(1.0), Color(EstiloHUD.CONTORNO, 0.8))
		draw_rect(volta, cor)


func _desenhar_geada() -> void:
	if _geada <= 0.02 and _geada_no_cilindro <= 0.02:
		return
	# Cristais de gelo grudados no cano e no cilindro: pontinhos brancos que
	# aparecem aos poucos (a ordem é fixa, para não piscar).
	var semente := 7
	var quantos := int(_geada * 90.0)
	var faixas := medidas.faixas_da_serpentina
	for i in quantos:
		semente = (semente * 1103515245 + 12345) & 0x7fffffff
		var faixa := faixas[semente % faixas.size()]
		var x := faixa.position.x + float(semente % int(faixa.size.x))
		semente = (semente * 1103515245 + 12345) & 0x7fffffff
		var y := faixa.position.y + float(semente % int(faixa.size.y))
		draw_rect(Rect2(x, y, 2.0, 2.0), COR_GEADA)
	var no_cilindro := int(_geada_no_cilindro * 70.0)
	for i in no_cilindro:
		semente = (semente * 1103515245 + 12345) & 0x7fffffff
		var lado := semente % 3
		semente = (semente * 1103515245 + 12345) & 0x7fffffff
		var y := medidas.cilindro.position.y + float(semente % int(medidas.cilindro.size.y))
		var x := medidas.cilindro.position.x - medidas.parede_do_cilindro + float(semente % 5) if lado == 0 \
			else medidas.cilindro.end.x + medidas.parede_do_cilindro - 2.0 - float(semente % 5)
		if lado == 2:
			x = medidas.cilindro.position.x + float(semente % int(medidas.cilindro.size.x))
			y = medidas.cilindro.end.y + 2.0 + float(semente % 5)
		draw_rect(Rect2(x, y, 2.0, 2.0), Color(COR_GEADA, 0.9))


func _desenhar_nevoa() -> void:
	var p := medidas.pixel
	for n in _nevoa:
		var t := float(n["vida"]) / float(n["duracao"])
		var alfa := sin(t * PI) * 0.22
		var cor := Color(0.85, 0.93, 1.0, alfa)
		if p > 0.0:
			# No mapa, em cima da parede da sala, um círculo liso parecia
			# mancha: a névoa vira pontinhos de gelo na grade da arte (um pixel
			# claro com a cruz em volta, mais fraca) escorrendo da máquina.
			cor.a = sin(t * PI) * 0.6
			_pontinho_de_gelo(n["pos"], cor, p)
		else:
			draw_circle(n["pos"], n["raio"], cor)


## Um pixel da arte (p px) no ponto, com a cruz em volta mais fraca.
func _pontinho_de_gelo(ponto: Vector2, cor: Color, p: float) -> void:
	var canto := (ponto / p).floor() * p
	draw_rect(Rect2(canto, Vector2(p, p)), cor)
	var fraca := Color(cor, cor.a * 0.35)
	for lado: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_rect(Rect2(canto + lado * p, Vector2(p, p)), fraca)


func _desenhar_rachaduras() -> void:
	if _fase != Fase.INCHANDO:
		return
	for r in _rachaduras:
		if r.size() > 1:
			draw_polyline(r, Color("1b1b24"), 3.0)
			draw_polyline(r, Color(1.0, 0.95, 0.8, 0.9), 1.0)
	# Os jatos de gás pelas frestas: riscos brancos que se abrem em névoa.
	for j in _jatos:
		var t := float(j["vida"]) / float(j["duracao"])
		var pos: Vector2 = j["pos"]
		var rastro: Vector2 = (j["vel"] as Vector2).normalized() * lerpf(6.0, 22.0, t)
		draw_line(pos - rastro, pos, Color(0.95, 0.98, 1.0, (1.0 - t) * 0.85), lerpf(2.0, 5.0, t))
		draw_circle(pos, 2.0 + t * 7.0, Color(0.95, 0.98, 1.0, (1.0 - t) * 0.45))


## Os nomes das peças, do lado de fora delas (nada escrito por cima das
## moléculas: a câmara é a caixa grande, não precisa de nome).
func _desenhar_nomes() -> void:
	var cor := Color(EstiloHUD.CLARO, 0.75)
	if medidas.no_mapa():
		_desenhar_nomes_no_mapa(cor)
		return
	var x_do_cilindro := medidas.cilindro.position.x - medidas.parede_do_cilindro - 96.0
	EstiloHUD.rotulo(self, FONTE, Vector2(x_do_cilindro, medidas.cilindro.end.y - 18.0), "CILINDRO", 11, cor)
	EstiloHUD.rotulo(self, FONTE, Vector2(x_do_cilindro, medidas.cilindro.end.y - 4.0), "3 L", 11, cor)
	EstiloHUD.rotulo(self, FONTE, Vector2(medidas.volante.x - 90.0, medidas.volante.y + 5.0), "VÁLVULA", 11, cor)
	EstiloHUD.rotulo(self, FONTE, _centro_do_manometro() + Vector2(medidas.manometro_raio + 12.0, 4.0),
		"PRESSÃO", 11, cor)


## No mapa, os nomes ficam nos vãos da máquina: CILINDRO e 3 L entre a perna
## da esquerda e o cilindro, VÁLVULA à esquerda do volante e PRESSÃO embaixo
## do mostrador.
func _desenhar_nomes_no_mapa(cor: Color) -> void:
	var perna: Rect2i = ArteDoCompressor.PERNAS[0]
	var x := (perna.end.x + 1) * medidas.pixel
	EstiloHUD.rotulo(self, FONTE, Vector2(x, medidas.cilindro.end.y - 18.0), "CILINDRO", 11, cor)
	EstiloHUD.rotulo(self, FONTE, Vector2(x, medidas.cilindro.end.y - 4.0), "3 L", 11, cor)
	var valvula := FONTE.get_string_size("VÁLVULA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	EstiloHUD.rotulo(self, FONTE, Vector2(medidas.volante.x - medidas.raio_do_volante - 10.0 - valvula,
		medidas.volante.y + 5.0), "VÁLVULA", 11, cor)
	var pressao := FONTE.get_string_size("PRESSÃO", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var c := _centro_do_manometro()
	EstiloHUD.rotulo(self, FONTE, Vector2(c.x - pressao * 0.5, c.y + medidas.manometro_raio + 24.0), "PRESSÃO", 11, cor)


func _desenhar_explosao() -> void:
	var t := _tempo_da_explosao
	var centro := _centro_da_explosao()
	# O clarão do instante: um disco branco que abre e some num piscar.
	if t < 0.22:
		var u := t / 0.22
		draw_circle(centro, lerpf(50.0, 230.0, ease(u, 0.35)), Color(1.0, 1.0, 1.0, (1.0 - u) * 0.95))
	# A onda de choque: dois anéis que correm para fora e afinam.
	for k in 2:
		var tk := t - k * 0.07
		if tk > 0.0 and tk < 0.75:
			var u := tk / 0.75
			var raio := lerpf(16.0, 600.0, ease(u, 0.45))
			draw_arc(centro, raio, 0.0, TAU, 72, Color(0.86, 0.94, 1.0, (1.0 - u) * (0.9 - k * 0.35)),
				lerpf(12.0 - k * 5.0, 1.0, u))
	# A nuvem: branca de condensação, com um pouco de poeira.
	for f in _fumaca:
		var u := float(f["vida"]) / float(f["duracao"])
		var cor: Color = f["cor"]
		var alfa := (1.0 - u) * (0.75 if cor.r > 0.8 else 0.5)
		draw_circle(f["pos"], f["raio"], Color(cor, alfa))
		draw_circle((f["pos"] as Vector2) + Vector2(-float(f["raio"]) * 0.25, -float(f["raio"]) * 0.25),
			float(f["raio"]) * 0.55, Color(1, 1, 1, alfa * 0.5))
	for c in _cacos:
		var tamanho: Vector2 = c["tamanho"]
		draw_set_transform(c["pos"], float(c["giro"]))
		if String(c.get("tipo", "placa")) == "volante":
			draw_circle(Vector2.ZERO, 13.0, EstiloHUD.CONTORNO)
			draw_circle(Vector2.ZERO, 11.0, c["cor"])
			draw_circle(Vector2.ZERO, 6.0, Color("1c9ca2"))
			for i in 4:
				draw_line(Vector2.ZERO, Vector2.from_angle(i * TAU / 4.0) * 10.0, Color("0b4e52"), 2.0)
		else:
			draw_rect(Rect2(-tamanho * 0.5 - Vector2.ONE, tamanho + Vector2.ONE * 2.0), EstiloHUD.CONTORNO)
			draw_rect(Rect2(-tamanho * 0.5, tamanho), c["cor"])
			draw_rect(Rect2(-tamanho * 0.5, Vector2(tamanho.x, 2.0)), Color(1, 1, 1, 0.3))
	draw_set_transform(Vector2.ZERO)
	for s in _faiscas:
		var u := float(s["vida"]) / float(s["duracao"])
		var pos: Vector2 = s["pos"]
		var rastro: Vector2 = (s["vel"] as Vector2).normalized() * 8.0
		draw_line(pos - rastro, pos, Color(1.0, lerpf(0.95, 0.5, u), 0.3, 1.0 - u), 2.0)
	_desenhar_moleculas()
