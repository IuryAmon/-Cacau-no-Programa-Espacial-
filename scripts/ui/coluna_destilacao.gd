@tool
class_name ColunaDestilacao
extends Control

# --- A COLUNA DE DESTILAÇÃO POR DENTRO (o desenho animado da explicação) ---
#
# É a coluna da fase do nitrogênio vista em raio X, com o ar sendo separado
# dentro dela. Quem a põe na tela e a rege é a explicação do Dr. Chico
# (scripts/explicacao_destilador.gd); este nó só desenha e anima.
#
# COMO UMA COLUNA DESSAS FUNCIONA (é isto que o desenho mostra):
#
#   * Cada substância ferve numa temperatura, o PONTO DE EBULIÇÃO: o
#     nitrogênio a -196 °C, o argônio a -186 °C, o oxigênio a -183 °C. Mais
#     quente que isso ela é gás; mais fria, líquido.
#   * O calor não vem de máquina nenhuma: a -200 °C o ar líquido é muito mais
#     frio que tudo em volta, e o CALOR DO AMBIENTE vai entrando nele sozinho.
#     Quem tira calor é o RESFRIADOR, a serpentina dentro da cúpula. Por isso
#     o fundo, onde está o líquido, é o lugar menos frio (-183 °C) e o topo o
#     mais frio (-196 °C), e cada andar do meio fica entre um e outro. É a
#     régua colorida à esquerda.
#   * O fundo não passa de -183 °C enquanto houver oxigênio líquido lá: um
#     líquido fervendo não fica mais quente que o ponto de ebulição dele (a
#     água na panela não passa de 100 °C).
#   * O gás sobe porque é gás, e esfria no caminho porque vai passando por
#     andares cada vez mais frios. Quando chega no andar que está no ponto de
#     ebulição dele, vira líquido de novo e fica ali. É a tampa da panela: o
#     vapor sobe, encosta na tampa fria e vira gota.
#   * Resultado: o nitrogênio (o que ferve mais fácil) só vira líquido lá no
#     topo; o argônio para um andar acima do fundo; o oxigênio (o mais difícil
#     de ferver) nem sai do fundo. Numa coluna de verdade é assim: oxigênio
#     líquido embaixo, nitrogênio em cima, argônio no meio.
#
# O QUE SE VÊ, NA ORDEM (cada parte é uma Etapa, pedida com ir_para):
#
#   FECHADA      a coluna de aço, como ela é no mapa.
#   RAIO_X       uma faixa de luz desce por ela e o aço vira o desenho preto,
#                com as bandejas à mostra.
#   AR_LIQUIDO   o ar entra no fundo já LÍQUIDO, a -200 °C: as moléculas dos
#                três tipos (N₂, O₂ e Ar) misturadas e encostadas.
#   FERVER       o resfriador liga e o líquido vai ganhando calor do ambiente:
#                o fundo fica menos frio aos poucos e para um grau antes de o
#                argônio ferver. Passando de -196 °C o NITROGÊNIO ferve: as
#                moléculas dele saem do líquido, sobem
#                como gás pelas fendas e só viram líquido no topo, onde o
#                resfriador segura os -196 °C. O que não cabe na bandeja de
#                cima continua gás: no ponto de ebulição, os dois convivem.
#   SEPARAR      o fundo segue ganhando calor, até -183 °C. A -186 °C ferve o
#                ARGÔNIO, que sobe um andar só (lá já está no ponto de ebulição
#                dele). O OXIGÊNIO fica: o fundo não passa do ponto dele.
#
# A separação NÃO é encenada. O fundo e o topo têm uma temperatura, os andares
# do meio ficam repartidos por igual entre as duas, cada substância tem um
# ponto de ebulição, e a molécula decide sozinha: ferve quando o fundo passa do
# ponto dela e vira líquido no primeiro andar que está nesse ponto ou abaixo.
# Mudar um número muda o que acontece na tela — é a mesma conta que o puzzle
# do controle de temperatura vai precisar.
#
# A ARTE É LIDA SOZINHA. "coluna de destilação.png" tem dois desenhos lado a
# lado, o de aço e o de raio X. Do de raio X saem as bandejas: toda barra clara
# presa em uma parede só é uma bandeja, o vão que sobra do outro lado é a fenda
# por onde o gás sobe, e o dente na ponta dela é a borda que segura o líquido.
# Pode redesenhar, mudar de tamanho e pôr mais bandejas: o desenho animado
# acompanha (ver _ler_arte).
#
# ONDE MEXER:
#   SUBSTANCIAS    quantas moléculas de cada, o ponto de ebulição e as cores do
#                  líquido de cada uma.
#   TEMPERATURA_DO_FUNDO / TEMPERATURA_DO_TOPO
#                  onde o fundo estaciona e onde o resfriador segura o topo.
#   RAMPA_DE_TEMPERATURA   as cores da régua (e do gás), do mais frio ao menos.
#   os tempos      logo abaixo.
#   assets/fase nitrogenio/moleculas do ar.png
#                  a arte das moléculas pequenas: 3 linhas (N₂, O₂, Ar) de 4
#                  quadros de 12×12 px — a molécula girando. O 1º quadro
#                  (deitada) é o que aparece dentro do líquido e nas plaquinhas.

## O fundo passou do ponto de ebulição desta substância: ela começou a ferver.
signal ferveu(substancia: String)
## A substância chegou no andar dela: a primeira molécula virou líquido na
## bandeja — ou, para a que nem sai do fundo, só sobrou ela lá.
signal assentou(substancia: String)
## Cada substância está no andar dela e não há mais nada subindo.
signal separou

enum Etapa { FECHADA, RAIO_X, AR_LIQUIDO, FERVER, SEPARAR }

const CAMINHO_ARTE := "res://assets/fase nitrogenio/coluna de destilação.png"
const CAMINHO_MOLECULAS := "res://assets/fase nitrogenio/moleculas do ar.png"
const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

## Quantos px de tela vale cada pixel da arte da coluna.
const ESCALA := 4.0
## E cada pixel da arte das moléculas: a metade, para caberem deitadas na
## poça de uma bandeja (4 px de arte de fundura).
const ESCALA_MOLECULA := 2.0
const CELULA_DA_MOLECULA := 12
const QUADROS_DA_MOLECULA := 4

# ── O AR ──
## "linha" é a linha da substância na folha das moléculas. "ebulicao" é o ponto
## de ebulição dela, em °C, a 1 atm (os de verdade: -195,8, -185,8 e -183,0).
## "quantas" é quantas entram na coluna: a proporção é só para se ver (no ar de
## verdade, de cada 100 moléculas, 78 são N₂, 21 são O₂ e 1 é argônio — é a
## ficha ao lado da coluna que diz isso).
const SUBSTANCIAS := {
	"N2": {"linha": 0, "ebulicao": -196, "quantas": 16,
		"liquido": Color("0f4a37"), "tona": Color("58d68d")},
	"O2": {"linha": 1, "ebulicao": -183, "quantas": 7,
		"liquido": Color("15186b"), "tona": Color("7f8cff")},
	"Ar": {"linha": 2, "ebulicao": -186, "quantas": 3,
		"liquido": Color("47206a"), "tona": Color("d9a6ff")},
}
## O ar líquido do fundo, antes de separar.
const COR_MISTURA := Color("1b3350")
const COR_TONA_MISTURA := Color("8fc1e8")

# ── AS TEMPERATURAS (°C) ──
## O ar entra na coluna já líquido (abaixo de -196 °C ele é líquido inteiro).
const TEMPERATURA_DO_AR_LIQUIDO := -200.0
## Onde o fundo estaciona, ganhando calor do ambiente: o ponto de ebulição do
## oxigênio. Enquanto houver oxigênio líquido lá ele não passa disso (um
## líquido fervendo não fica mais quente que o ponto de ebulição dele), e é por
## isso que o oxigênio fica no fundo.
const TEMPERATURA_DO_FUNDO := -183.0
## Onde o resfriador segura o topo: o ponto de ebulição do nitrogênio, que por
## isso vira líquido lá.
const TEMPERATURA_DO_TOPO := -196.0
## As cores da régua de temperatura, do mais frio ao menos frio. Entre duas
## temperaturas da lista a cor é a mistura das duas.
const RAMPA_DE_TEMPERATURA := [
	[-200.0, Color("5fb8ff")],
	[-196.0, Color("8fd8ff")],
	[-190.0, Color("d9dcc8")],
	[-186.0, Color("f1c27d")],
	[-183.0, Color("f4a259")],
]

# ── OS TEMPOS ──
const DURACAO_DO_RAIO_X := 0.9
const DURACAO_DE_FECHAR := 0.5
## Na etapa AR_LIQUIDO, entra uma molécula a cada tanto.
const INTERVALO_DE_ENTRADA := 0.045
## Quantos graus o fundo sobe por segundo, ganhando calor do ambiente.
const GRAUS_POR_SEGUNDO := 2.0
## Fervendo, sai uma molécula do líquido a cada tanto.
const INTERVALO_DE_EMISSAO := 0.3
## Velocidade do gás subindo e do gás solto num andar (px de tela por segundo).
const VELOCIDADE_SUBINDO := 180.0
const VELOCIDADE_SOLTO := 96.0
## Quando a explicação pede uma etapa com a anterior ainda no meio, a anterior
## corre nesta pressa até acabar.
const PRESSA_PARA_ALCANCAR := 6.0

# ── MEDIDAS (px de tela) ──
## Meia molécula: o quanto ela se afasta de parede, teto e líquido.
const FOLGA := 13.0
## Quanto a molécula pode sair do meio da fenda ao passar por ela.
const FOLGA_NA_FENDA := 9.0
## A régua de temperatura, colada na parede esquerda da coluna.
const LARGURA_DA_REGUA := 12.0
const DISTANCIA_DA_REGUA := 4.0
## As plaquinhas de temperatura, à esquerda da régua.
const TAMANHO_DA_LETRA := 22
const DISTANCIA_DA_PLAQUINHA := 6.0
## Quanto a plaquinha alarga para caber o desenho da molécula.
const LARGURA_DO_DESENHO_NA_PLAQUINHA := 26.0
const LEGENDA_DO_RESFRIADOR := "RESFRIADOR"
## Em duas linhas, embaixo da plaquinha do fundo.
const LEGENDA_DO_CALOR := "CALOR DO\nAMBIENTE"

## A névoa do gás: a partir de quanta névoa aparece cada um dos dois tons (o
## pontilhado é a beirada da nuvem). A cor é a da temperatura do andar.
const NEVOA_PONTILHADA := 0.16
const NEVOA_FRACA := 0.34
const NEVOA_FORTE := 0.95

## O calor do ambiente entrando por baixo (as setinhas embaixo do piso): os
## dois tons em que elas piscam.
const COR_DO_CALOR := Color("ff9f1c")
const COR_DO_CALOR_CLARA := Color("ffd166")
## O resfriador (a serpentina dentro da cúpula): parado e ligado. Ligado,
## pisca entre os dois tons.
const COR_SERPENTINA_PARADA := Color("3d4a5c")
const COR_SERPENTINA := Color("8fd8ff")
const COR_SERPENTINA_CLARA := Color("f2fbff")

enum Estado { FORA, LIQUIDA, SUBINDO, MERGULHANDO, GAS_SOLTO }


class Molecula:
	var tipo: String = ""
	var estado: int = 0
	## O meio dela, em px de tela a partir do canto da coluna.
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var caminho := PackedVector2Array()
	var passo: int = 0
	## Relógio só dela: o giro, o balanço dentro do líquido.
	var relogio: float = 0.0
	## Giros por segundo (quadros da folha) enquanto é gás.
	var giro: float = 5.0
	## Espera antes de entrar na coluna (etapa AR_LIQUIDO).
	var espera: float = 0.0
	## 0..1: o estalo de quando ela aparece.
	var tamanho: float = 0.0
	## A poça em que ela mora quando é líquido, e o lugar dela ali.
	var poca: int = -1
	var alvo_x: float = 0.0
	## O andar em que ela quica enquanto é gás solto.
	var camara: int = 0
	var proxima_fumaca: float = 0.0


class Poca:
	## Paredes, fundo e fundura cheia, em px de tela.
	var x0: float = 0.0
	var x1: float = 0.0
	var base: float = 0.0
	var funda: float = 0.0
	## A substância que vira líquido nesta bandeja ("" nas fileiras do fundo e
	## nas bandejas em que nenhuma para).
	var substancia: String = ""
	var camara: int = 0
	var cabem: int = 0
	## As moléculas que moram nela, da esquerda para a direita.
	var moleculas: Array = []
	## 0..1: quanto do líquido já se vê.
	var nivel: float = 0.0


static var _folha_das_moleculas: Texture2D

# ── O que a arte diz ──
var _textura: Texture2D
var _moleculas_tex: Texture2D
var _linhas_tex: Texture2D
var _recorte_aco := Rect2i()
var _recorte_raio_x := Rect2i()
## Cada bandeja, do fundo para o topo: y0/y1 (as linhas da barra), x0/x1,
## fenda_x0/fenda_x1, borda (altura do dente) e lado (-1 = fenda à esquerda).
var _bandejas: Array[Dictionary] = []
var _piso: int = 0
## Por linha da arte, a primeira e a última coluna do miolo preto (-1 = não há).
var _miolo_esq := PackedInt32Array()
var _miolo_dir := PackedInt32Array()
## Os vãos embaixo do piso, entre os pés: é onde se desenha o calor do
## ambiente entrando.
var _vaos_dos_pes: Array[Vector2i] = []
## A serpentina do resfriador, dentro da cúpula: x, y, largura e altura, em
## pixels da arte (sem área se a cúpula for estreita demais).
var _serpentina := Rect2i()
## 1 em cada pixel da arte que é miolo: o gás só é desenhado ali.
var _e_miolo := PackedByteArray()
## Quanto gás há em cada pixel da arte, refeito a cada quadro (ver _desenhar_fumaca).
var _nevoa := PackedFloat32Array()
## Em que andar fica cada linha da arte (para a cor do gás).
var _andar_da_linha := PackedInt32Array()

# ── A animação ──
var _etapa: Etapa = Etapa.FECHADA
var _pedida: Etapa = Etapa.FECHADA
var _relogio_da_etapa: float = 0.0
var _relogio: float = 0.0
## 0 = aço, 1 = raio X: quanto da coluna, de cima para baixo, já virou.
var _raio_x: float = 0.0
## 0..1: o que tem dentro (moléculas, líquidos, régua, plaquinhas) some ao fechar.
var _conteudo: float = 1.0
var _fechando: bool = false
var _temperatura_do_fundo: float = TEMPERATURA_DO_AR_LIQUIDO
## 0..1: o calor do ambiente e o resfriador aparecendo.
var _calor: float = 0.0
var _resfriador: float = 0.0
## 0..1: a régua de temperatura aparecendo.
var _regua: float = 0.0
var _moleculas: Array[Molecula] = []
## 0 e 1 são as duas fileiras do fundo; daí em diante, uma por bandeja.
var _pocas: Array[Poca] = []
var _altura_do_fundo: float = 0.0
var _proxima_emissao: float = 0.0
var _proxima_bolha: float = 0.0
var _proxima_geada: float = 0.0
var _bolhas: Array[Vector3] = []     # x, y, velocidade
var _fumaca: Array[Dictionary] = []
var _respingos: Array[Dictionary] = []
var _geada: Array[Dictionary] = []
## Por andar: quanto da plaquinha de temperatura já apareceu (0..1).
var _etiquetas := PackedFloat32Array()
## Por andar: 1 quando alguma coisa acaba de acontecer ali; volta a 0 sozinho.
var _pulsos := PackedFloat32Array()
## Por andar: a substância que ficou ali ("" enquanto não ficou nenhuma).
var _donos: Array[String] = []
var _ja_ferveu: Dictionary = {}
var _ja_assentou: Dictionary = {}
var _avisou_separou: bool = false

## Multiplica o tempo da animação (a explicação acelera quando a pessoa passa
## as falas depressa).
var ritmo: float = 1.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ler_arte()
	custom_minimum_size = tamanho_da_coluna()
	size = custom_minimum_size
	reiniciar()
	if Engine.is_editor_hint():
		# No editor fica o desenho de raio X pronto (régua, calor do ambiente,
		# resfriador e as plaquinhas das duas pontas), para posicionar.
		_raio_x = 1.0
		_regua = 1.0
		_calor = 1.0
		_resfriador = 1.0
		_temperatura_do_fundo = TEMPERATURA_DO_FUNDO
		_etiquetas[0] = 1.0
		_etiquetas[_etiquetas.size() - 1] = 1.0
		set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	avancar(delta)


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

## Volta ao começo: a coluna de aço, sem nada dentro.
func reiniciar() -> void:
	_etapa = Etapa.FECHADA
	_pedida = Etapa.FECHADA
	_relogio_da_etapa = 0.0
	_raio_x = 0.0
	_conteudo = 1.0
	_fechando = false
	_temperatura_do_fundo = TEMPERATURA_DO_AR_LIQUIDO
	_calor = 0.0
	_resfriador = 0.0
	_regua = 0.0
	_altura_do_fundo = 0.0
	_proxima_emissao = 0.0
	_proxima_bolha = 0.0
	_proxima_geada = 0.0
	_bolhas.clear()
	_fumaca.clear()
	_respingos.clear()
	_geada.clear()
	_ja_ferveu.clear()
	_ja_assentou.clear()
	_avisou_separou = false
	var andares := numero_de_andares()
	_etiquetas.resize(andares)
	_etiquetas.fill(0.0)
	_pulsos.resize(andares)
	_pulsos.fill(0.0)
	_donos.resize(andares)
	_donos.fill("")
	_montar_pocas()
	_criar_moleculas()
	queue_redraw()


## Pede uma etapa. Elas acontecem em ordem: pedindo uma lá da frente, as do
## meio passam correndo (PRESSA_PARA_ALCANCAR) em vez de serem puladas.
func ir_para(etapa: Etapa) -> void:
	if etapa == Etapa.FECHADA:
		fechar()
		return
	_fechando = false
	_pedida = maxi(_pedida, etapa) as Etapa


## Some com o que tem dentro e devolve o aço, de baixo para cima.
func fechar() -> void:
	_fechando = true
	_pedida = Etapa.FECHADA


## Um sopro de frio do resfriador (a explicação chama quando o Dr. Chico fala
## dele): uma nuvem de geada e a plaquinha do topo dá um pulo.
func soprar_frio() -> void:
	if _etapa < Etapa.FERVER or _fechando:
		return
	for i in 14:
		_soltar_geada()
	_pulsos[_pulsos.size() - 1] = 1.0


func etapa_atual() -> Etapa:
	return _etapa


## True quando a coluna voltou a ser a de aço (depois de fechar()).
func esta_fechada() -> bool:
	return _etapa == Etapa.FECHADA and _raio_x <= 0.0


func tamanho_da_coluna() -> Vector2:
	return Vector2(_recorte_raio_x.size) * ESCALA


## Andares da coluna: o fundo e mais um por bandeja.
func numero_de_andares() -> int:
	return _bandejas.size() + 1


## A temperatura do fundo agora, em °C.
func temperatura_do_fundo() -> float:
	return _temperatura_do_fundo


## A temperatura do topo agora: ele acompanha o fundo só até o resfriador
## segurar.
func temperatura_do_topo() -> float:
	return minf(_temperatura_do_fundo, TEMPERATURA_DO_TOPO)


## A temperatura do andar agora (0 = o fundo): os do meio ficam repartidos por
## igual entre a do fundo e a do topo.
func temperatura_do_andar(andar: int) -> float:
	return lerpf(_temperatura_do_fundo, temperatura_do_topo(), _altura_relativa(andar))


## A mesma, com a coluna já quente no fundo e fria no topo (o fim da história).
func temperatura_final_do_andar(andar: int) -> float:
	return lerpf(TEMPERATURA_DO_FUNDO, TEMPERATURA_DO_TOPO, _altura_relativa(andar))


## A temperatura do andar como ela é escrita na plaquinha.
func graus_do_andar(andar: int) -> int:
	return roundi(temperatura_do_andar(andar))


func _altura_relativa(andar: int) -> float:
	var andares := numero_de_andares()
	if andares <= 1:
		return 0.0
	return float(clampi(andar, 0, andares - 1)) / float(andares - 1)


## O andar em que a substância fica líquida: o primeiro, do fundo para cima,
## que está no ponto de ebulição dela ou abaixo (0 = ela nem sai do fundo).
## -1 se nenhum é frio o bastante.
func andar_de(substancia: String) -> int:
	var ebulicao := float(SUBSTANCIAS[substancia]["ebulicao"])
	for andar in numero_de_andares():
		if temperatura_final_do_andar(andar) <= ebulicao + 0.001:
			return andar
	return -1


## O fundo já passou do ponto de ebulição dela?
func ja_ferveu(substancia: String) -> bool:
	return _ja_ferveu.has(substancia)


## Ela já está (pelo menos uma molécula) no andar dela?
func ja_assentou(substancia: String) -> bool:
	return _ja_assentou.has(substancia)


## A substância que ficou no andar ("" se nenhuma, ou ainda nenhuma).
func dono_do_andar(andar: int) -> String:
	return _donos[andar] if andar >= 0 and andar < _donos.size() else ""


## Quantas moléculas da substância já são líquido na bandeja dela.
func liquidas_na_bandeja(substancia: String) -> int:
	var poca := _poca_de(substancia)
	if poca == null:
		return 0
	var conta := 0
	for m: Molecula in poca.moleculas:
		if m.estado == Estado.LIQUIDA:
			conta += 1
	return conta


## Quantas moléculas estão no líquido do fundo: de uma substância, ou todas ("").
func liquidas_no_fundo(substancia: String = "") -> int:
	var conta := 0
	for fileira in 2:
		for m: Molecula in _pocas[fileira].moleculas:
			if substancia == "" or m.tipo == substancia:
				conta += 1
	return conta


## Quantas estão neste estado (Estado.*), de uma substância ou de todas ("").
func quantas_em(estado: Estado, substancia: String = "") -> int:
	var conta := 0
	for m in _moleculas:
		if m.estado == estado and (substancia == "" or m.tipo == substancia):
			conta += 1
	return conta


func total_de_moleculas() -> int:
	return _moleculas.size()


## True quando o fundo chegou na temperatura dele, só sobrou lá o que não
## ferve e não há mais nada subindo.
func separado() -> bool:
	if _etapa != Etapa.SEPARAR or not is_equal_approx(_temperatura_do_fundo, TEMPERATURA_DO_FUNDO):
		return false
	for m in _moleculas:
		if m.estado == Estado.SUBINDO or m.estado == Estado.MERGULHANDO:
			return false
		if m.estado == Estado.LIQUIDA and m.poca < 2 and andar_de(m.tipo) != 0:
			return false
	return true


## Onde fica a plaquinha de temperatura do andar (o meio do lado direito dela).
func lugar_da_plaquinha(andar: int) -> Vector2:
	return Vector2(-(DISTANCIA_DA_REGUA + LARGURA_DA_REGUA + DISTANCIA_DA_PLAQUINHA),
		roundf(_meio_do_andar(andar)))


## O que as bandejas da arte dizem (para os testes).
func bandejas() -> Array[Dictionary]:
	return _bandejas


## A cor de uma temperatura na régua (ver RAMPA_DE_TEMPERATURA).
static func cor_da_temperatura(graus: float) -> Color:
	var primeira: Array = RAMPA_DE_TEMPERATURA[0]
	if graus <= float(primeira[0]):
		return primeira[1]
	for i in range(1, RAMPA_DE_TEMPERATURA.size()):
		var de: Array = RAMPA_DE_TEMPERATURA[i - 1]
		var ate: Array = RAMPA_DE_TEMPERATURA[i]
		if graus <= float(ate[0]):
			return (de[1] as Color).lerp(ate[1], inverse_lerp(float(de[0]), float(ate[0]), graus))
	var ultima: Array = RAMPA_DE_TEMPERATURA[RAMPA_DE_TEMPERATURA.size() - 1]
	return ultima[1]


# ─────────────────────────────────────────────────────────────
# LER A ARTE
# ─────────────────────────────────────────────────────────────

func _ler_arte() -> void:
	_textura = load(CAMINHO_ARTE) as Texture2D
	_moleculas_tex = _textura_das_moleculas()
	_bandejas.clear()
	_vaos_dos_pes.clear()
	_serpentina = Rect2i()
	if _textura == null:
		push_warning("ColunaDestilacao: não achei a arte em '%s'." % CAMINHO_ARTE)
		return
	var folha := _textura.get_image()
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
			var caixa := folha.get_region(Rect2i(inicio, 0, x - inicio, folha.get_height())) \
				.get_used_rect()
			caixa.position.x += inicio
			desenhos.append(caixa)
			inicio = -1
	if desenhos.size() < 2:
		push_warning("ColunaDestilacao: a folha '%s' devia ter dois desenhos lado a lado (aço e raio X); achei %d."
			% [CAMINHO_ARTE, desenhos.size()])
		if desenhos.is_empty():
			return
		desenhos.append(desenhos[0])
	_recorte_aco = desenhos[0]
	_recorte_raio_x = desenhos[1]

	var raio := folha.get_region(_recorte_raio_x)
	var largura := raio.get_width()
	var altura := raio.get_height()

	# Só as linhas claras (paredes e bandejas), para desenhar por cima de tudo:
	# gás e moléculas passam por trás delas.
	var linhas := Image.create_empty(largura, altura, false, Image.FORMAT_RGBA8)
	_miolo_esq.resize(altura)
	_miolo_dir.resize(altura)
	_e_miolo.resize(largura * altura)
	_e_miolo.fill(0)
	_nevoa.resize(largura * altura)
	for y in altura:
		_miolo_esq[y] = -1
		_miolo_dir[y] = -1
		for x in largura:
			if _claro(raio, x, y):
				linhas.set_pixel(x, y, raio.get_pixel(x, y))
			elif _escuro(raio, x, y):
				_e_miolo[y * largura + x] = 1
				if _miolo_esq[y] < 0:
					_miolo_esq[y] = x
				_miolo_dir[y] = x
	_linhas_tex = ImageTexture.create_from_image(linhas)

	# As barras: linhas da arte com um traço claro de mais de meia largura.
	var barras: Array[Dictionary] = []
	var aberta := {}
	for y in altura + 1:
		var traco := _maior_traco_claro(raio, y) if y < altura else Vector2i(-1, -1)
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
	_piso = altura - 1
	var achou_piso := false
	for i in range(barras.size() - 1, -1, -1):
		var barra := barras[i]
		if barra["x0"] <= 0 and barra["x1"] >= largura - 1:
			if not achou_piso:
				_piso = barra["y0"]
				achou_piso = true
			continue
		if achou_piso and barra["y0"] > _piso:
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
		_bandejas.append(barra)
	# _bandejas ficou do fundo para o topo (as barras foram lidas de baixo
	# para cima).

	# Em que andar fica cada linha: tantas bandejas abaixo dela, tal o andar.
	_andar_da_linha.resize(altura)
	for y in altura:
		var andar := 0
		for bandeja in _bandejas:
			if int(bandeja["y0"]) > y:
				andar += 1
		_andar_da_linha[y] = andar

	# Os vãos entre os pés, duas linhas abaixo do piso.
	var y_pes := _piso + 2
	if y_pes < altura:
		inicio = -1
		for x in largura + 1:
			var vazio := x < largura and raio.get_pixel(x, y_pes).a <= 0.0
			if vazio and inicio < 0:
				inicio = x
			elif not vazio and inicio >= 0:
				if x - inicio >= 6:
					_vaos_dos_pes.append(Vector2i(inicio + 1, x - 2))
				inicio = -1

	# A serpentina do resfriador: no alto da cúpula, logo abaixo da primeira
	# linha em que o miolo já tem largura para ela (3 linhas de altura).
	for y in altura - 4:
		if _miolo_esq[y] >= 0 and _miolo_dir[y] - _miolo_esq[y] + 1 >= largura * 2 / 5:
			_serpentina = Rect2i(_miolo_esq[y] + 2, y + 1, _miolo_dir[y] - _miolo_esq[y] - 3, 3)
			break


static func _textura_das_moleculas() -> Texture2D:
	if _folha_das_moleculas == null and ResourceLoader.exists(CAMINHO_MOLECULAS):
		_folha_das_moleculas = load(CAMINHO_MOLECULAS) as Texture2D
	return _folha_das_moleculas


func _escuro(imagem: Image, x: int, y: int) -> bool:
	var p := imagem.get_pixel(x, y)
	return p.a > 0.5 and p.get_luminance() < 0.2


func _claro(imagem: Image, x: int, y: int) -> bool:
	var p := imagem.get_pixel(x, y)
	return p.a > 0.5 and p.get_luminance() >= 0.2


## O maior traço claro da linha: (primeira coluna, última), ou (-1, -1).
func _maior_traco_claro(imagem: Image, y: int) -> Vector2i:
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
func _altura_da_borda(imagem: Image, x: int, y_da_barra: int) -> int:
	var altura := 0
	while y_da_barra - altura - 1 >= 0 and _claro(imagem, x, y_da_barra - altura - 1):
		altura += 1
	return altura


# ─────────────────────────────────────────────────────────────
# OS ANDARES (tudo em px de tela, a partir do canto da coluna)
# ─────────────────────────────────────────────────────────────

func _largura() -> float:
	return _recorte_raio_x.size.x * ESCALA


func _chao_do_andar(andar: int) -> float:
	if andar <= 0 or _bandejas.is_empty():
		return _piso * ESCALA
	return float(_bandejas[mini(andar, _bandejas.size()) - 1]["y0"]) * ESCALA


func _teto_do_andar(andar: int) -> float:
	if andar < _bandejas.size():
		return (float(_bandejas[andar]["y1"]) + 1.0) * ESCALA
	# O andar de cima acaba embaixo da serpentina do resfriador — ou, sem ela,
	# na cúpula: a primeira linha com miolo.
	if _serpentina.has_area():
		return float(_serpentina.end.y + 1) * ESCALA
	for y in _miolo_esq.size():
		if _miolo_esq[y] >= 0:
			return y * ESCALA
	return 0.0


## A tona do líquido da bandeja que é o chão do andar (ou o chão, no fundo).
func _tona_do_andar(andar: int) -> float:
	if andar <= 0 or _bandejas.is_empty():
		return _chao_do_andar(0)
	var bandeja := _bandejas[mini(andar, _bandejas.size()) - 1]
	return _chao_do_andar(andar) - float(bandeja["borda"]) * ESCALA


## A altura em que se lê a temperatura do andar: o meio do vão dele (no de
## cima, o meio da parte reta, sem contar a cúpula).
func _meio_do_andar(andar: int) -> float:
	var chao := _chao_do_andar(andar)
	var teto := _teto_do_andar(andar)
	if andar >= _bandejas.size() and _bandejas.size() >= 2:
		var vao := _chao_do_andar(andar - 1) - _teto_do_andar(andar - 1)
		teto = maxf(teto, chao - vao)
	return (chao + teto) * 0.5


## O trecho da régua que é do andar: (de cima, de baixo). Os trechos se emendam
## no meio de cada bandeja; o de cima vai até o alto da cúpula e o do fundo até
## o piso.
func _trecho_da_regua(andar: int) -> Vector2:
	var de_cima := 0.0
	if andar < _bandejas.size():
		de_cima = (float(_bandejas[andar]["y0"]) + float(_bandejas[andar]["y1"]) + 1.0) * 0.5 * ESCALA
	var de_baixo := float(_piso + 1) * ESCALA
	if andar > 0 and not _bandejas.is_empty():
		var bandeja := _bandejas[mini(andar, _bandejas.size()) - 1]
		de_baixo = (float(bandeja["y0"]) + float(bandeja["y1"]) + 1.0) * 0.5 * ESCALA
	return Vector2(de_cima, de_baixo)


func _meio_da_fenda(bandeja: int) -> float:
	var b := _bandejas[bandeja]
	return (float(b["fenda_x0"]) + float(b["fenda_x1"]) + 1.0) * 0.5 * ESCALA


## Até onde o gás pode ir para os lados na altura y: as paredes do miolo.
func _paredes_em(y: float) -> Vector2:
	var linha := clampi(int(y / ESCALA), 0, _miolo_esq.size() - 1)
	if _miolo_esq.is_empty() or _miolo_esq[linha] < 0:
		return Vector2(ESCALA, _largura() - ESCALA)
	return Vector2(_miolo_esq[linha] * ESCALA, (_miolo_dir[linha] + 1) * ESCALA)


func _montar_pocas() -> void:
	_pocas.clear()
	var passo := CELULA_DA_MOLECULA * ESCALA_MOLECULA - 1.0
	var total := 0
	for nome: String in SUBSTANCIAS:
		total += int(SUBSTANCIAS[nome]["quantas"])
	# O fundo: duas fileiras, uma em cima da outra.
	for fileira in 2:
		var poca := Poca.new()
		poca.x0 = ESCALA
		poca.x1 = _largura() - ESCALA
		poca.funda = 4.0 * ESCALA
		poca.base = _piso * ESCALA - fileira * poca.funda
		poca.cabem = ceili(total / 2.0)
		_pocas.append(poca)
	# Uma por bandeja, com a substância que vira líquido no andar dela.
	for i in _bandejas.size():
		var bandeja := _bandejas[i]
		var poca := Poca.new()
		if int(bandeja["lado"]) < 0:
			poca.x0 = (float(bandeja["x0"]) + 1.0) * ESCALA
			poca.x1 = _largura() - ESCALA
		else:
			poca.x0 = ESCALA
			poca.x1 = float(bandeja["x1"]) * ESCALA
		poca.base = float(bandeja["y0"]) * ESCALA
		poca.funda = float(bandeja["borda"]) * ESCALA
		poca.camara = i + 1
		poca.cabem = maxi(1, int((poca.x1 - poca.x0) / passo))
		for nome: String in SUBSTANCIAS:
			if andar_de(nome) == i + 1:
				poca.substancia = nome
		_pocas.append(poca)


## A bandeja em que a substância vira líquido (null para a que fica no fundo).
func _poca_de(substancia: String) -> Poca:
	for i in range(2, _pocas.size()):
		if _pocas[i].substancia == substancia:
			return _pocas[i]
	return null


# ─────────────────────────────────────────────────────────────
# AS MOLÉCULAS
# ─────────────────────────────────────────────────────────────

func _criar_moleculas() -> void:
	_moleculas.clear()
	var tipos: Array[String] = []
	for nome: String in SUBSTANCIAS:
		for i in int(SUBSTANCIAS[nome]["quantas"]):
			tipos.append(nome)
	# Sempre a mesma mistura embaralhada: a explicação é igual toda vez.
	var sorteio := RandomNumberGenerator.new()
	sorteio.seed = 828
	for i in range(tipos.size() - 1, 0, -1):
		var j := sorteio.randi_range(0, i)
		var troca := tipos[i]
		tipos[i] = tipos[j]
		tipos[j] = troca
	for i in tipos.size():
		var m := Molecula.new()
		m.tipo = tipos[i]
		m.estado = Estado.FORA
		m.espera = i * INTERVALO_DE_ENTRADA
		m.relogio = sorteio.randf() * 10.0
		m.giro = sorteio.randf_range(3.0, 6.0)
		_moleculas.append(m)


## Um passo da animação. O _process chama sozinho; os testes chamam direto.
func avancar(delta: float) -> void:
	if _textura == null or Engine.is_editor_hint():
		return
	# Em passos curtos (1/60 s de animação): com pressa, um quadro só não pode
	# atravessar parede. A pressa é vista de novo a cada passo, porque ela
	# acaba no instante em que a etapa pedida começa.
	var resto := delta
	while resto > 0.0:
		var pressa := ritmo
		if _pedida > _etapa and not _fechando:
			pressa = maxf(pressa, PRESSA_PARA_ALCANCAR)
		var fatia := minf(resto, 1.0 / (60.0 * maxf(pressa, 0.01)))
		resto -= fatia
		_passo(fatia * pressa)
	queue_redraw()


func _passo(delta: float) -> void:
	_relogio += delta
	_relogio_da_etapa += delta

	if _fechando:
		_passo_de_fechar(delta)
	elif _pedida > _etapa and _etapa_pronta():
		_entrar((_etapa + 1) as Etapa)

	match _etapa:
		Etapa.RAIO_X:
			_raio_x = minf(_raio_x + delta / DURACAO_DO_RAIO_X, 1.0)
		Etapa.FERVER, Etapa.SEPARAR:
			_calor = minf(_calor + delta / 0.35, 1.0)
			_resfriador = minf(_resfriador + delta / 0.35, 1.0)
			_ganhar_calor(delta)
			_ferver(delta)
			_conferir_o_fundo()

	# A régua e a plaquinha do fundo desde que o ar entra; a do topo quando o
	# resfriador liga; as do meio só quando alguma substância fica ali.
	var a_regua := 1.0 if _etapa >= Etapa.AR_LIQUIDO and not _fechando else 0.0
	_regua = move_toward(_regua, a_regua, delta / 0.3)
	var topo := _etiquetas.size() - 1
	for andar in _etiquetas.size():
		var a_vista := _etapa >= Etapa.AR_LIQUIDO if andar == 0 \
			else _etapa >= Etapa.FERVER if andar == topo \
			else _donos[andar] != ""
		_etiquetas[andar] = move_toward(_etiquetas[andar], 1.0 if a_vista else 0.0, delta / 0.25)
	for andar in _pulsos.size():
		_pulsos[andar] = move_toward(_pulsos[andar], 0.0, delta / 0.5)

	for i in _pocas.size():
		_arrumar_poca(_pocas[i], delta)
	for m in _moleculas:
		_mover(m, delta)
	_passo_do_fundo(delta)
	_passo_das_bolhas(delta)
	_passo_da_fumaca(delta)
	_passo_dos_respingos(delta)
	_passo_da_geada(delta)

	if not _avisou_separou and separado():
		_avisou_separou = true
		separou.emit()


func _etapa_pronta() -> bool:
	match _etapa:
		Etapa.FECHADA:
			return true
		Etapa.RAIO_X:
			return _raio_x >= 1.0
		Etapa.AR_LIQUIDO:
			for m in _moleculas:
				if m.estado == Estado.FORA or m.tamanho < 1.0:
					return false
			return true
		Etapa.FERVER:
			# O fundo chegou na parada e tudo o que ferve até ali já saiu dele.
			if not is_equal_approx(_temperatura_do_fundo, _parada_do_calor()):
				return false
			for fileira in 2:
				for m: Molecula in _pocas[fileira].moleculas:
					if _ferve(m):
						return false
			return true
	return false


func _entrar(nova: Etapa) -> void:
	_etapa = nova
	_relogio_da_etapa = 0.0
	if nova == Etapa.FERVER:
		_proxima_bolha = 0.2


func _passo_de_fechar(delta: float) -> void:
	_pedida = Etapa.FECHADA
	if _conteudo > 0.0 and _etapa > Etapa.RAIO_X:
		_conteudo = maxf(_conteudo - delta / 0.22, 0.0)
		return
	_etapa = Etapa.FECHADA
	_raio_x = maxf(_raio_x - delta / DURACAO_DE_FECHAR, 0.0)


func _mover(m: Molecula, delta: float) -> void:
	m.relogio += delta
	if m.estado != Estado.FORA:
		m.tamanho = minf(m.tamanho + delta / 0.16, 1.0)
	match m.estado:
		Estado.FORA:
			if _etapa >= Etapa.AR_LIQUIDO and _relogio_da_etapa >= m.espera:
				_entrar_no_fundo(m)
		Estado.GAS_SOLTO:
			_quicar(m, delta)
		Estado.MERGULHANDO:
			_ir_para_a_poca(m, delta)
		Estado.LIQUIDA:
			_boiar(m, delta)
		Estado.SUBINDO:
			_subir(m, delta)


## Etapa AR_LIQUIDO: ela cai no líquido do fundo, na fileira de baixo enquanto
## houver lugar, e as vizinhas abrem espaço.
func _entrar_no_fundo(m: Molecula) -> void:
	var fileira := 0 if _pocas[0].moleculas.size() < _pocas[0].cabem else 1
	m.pos = Vector2(randf_range(ESCALA + FOLGA, _largura() - ESCALA - FOLGA),
		_altura_na_poca(_pocas[fileira]) - 26.0)
	m.vel = Vector2.ZERO
	m.tamanho = 0.0
	m.estado = Estado.LIQUIDA
	_por_na_poca(m, fileira)


## Gás solto num andar: anda reto e bate nas paredes, no teto e no líquido.
func _quicar(m: Molecula, delta: float) -> void:
	m.pos += m.vel * delta
	var teto := _teto_do_andar(m.camara) + FOLGA
	var chao := _tona_do_andar(m.camara) - FOLGA
	if m.pos.y < teto:
		m.pos.y = teto
		m.vel.y = absf(m.vel.y)
	elif m.pos.y > chao:
		m.pos.y = chao
		m.vel.y = -absf(m.vel.y)
	var paredes := _paredes_em(m.pos.y - FOLGA * 0.6)
	if paredes.y - paredes.x < FOLGA * 2.5:
		# Lá no alto da cúpula não cabe: volta para baixo.
		m.vel.y = absf(m.vel.y)
		paredes = _paredes_em(m.pos.y + FOLGA)
	if m.pos.x < paredes.x + FOLGA:
		m.pos.x = paredes.x + FOLGA
		m.vel.x = absf(m.vel.x)
	elif m.pos.x > paredes.y - FOLGA:
		m.pos.x = paredes.y - FOLGA
		m.vel.x = -absf(m.vel.x)


## Entra na lista da poça no lugar que a posição dela pede (a lista anda da
## esquerda para a direita): as vizinhas abrem espaço.
func _por_na_poca(m: Molecula, indice: int) -> void:
	var poca := _pocas[indice]
	var lugar := 0
	while lugar < poca.moleculas.size() and (poca.moleculas[lugar] as Molecula).pos.x < m.pos.x:
		lugar += 1
	poca.moleculas.insert(lugar, m)
	m.poca = indice


## O lugar de cada uma na poça: espalhadas por igual de parede a parede.
func _arrumar_poca(poca: Poca, delta: float) -> void:
	var quantas := poca.moleculas.size()
	for i in quantas:
		(poca.moleculas[i] as Molecula).alvo_x = poca.x0 + (i + 0.5) * (poca.x1 - poca.x0) / quantas
	poca.nivel = move_toward(poca.nivel, 1.0 if _tem_liquida(poca) else 0.0, delta / 0.3)


func _tem_liquida(poca: Poca) -> bool:
	for m: Molecula in poca.moleculas:
		if m.estado == Estado.LIQUIDA:
			return true
	return false


func _altura_na_poca(poca: Poca) -> float:
	return poca.base - poca.funda * 0.5


## O gás chegou no andar dele e desce para o lugar dele no líquido.
func _ir_para_a_poca(m: Molecula, delta: float) -> void:
	var poca := _pocas[m.poca]
	var alvo := Vector2(m.alvo_x, _altura_na_poca(poca))
	var distancia := m.pos.distance_to(alvo)
	m.pos = m.pos.move_toward(alvo, maxf(60.0, distancia * 4.5) * delta)
	m.vel = Vector2.ZERO
	if distancia < 1.5:
		m.estado = Estado.LIQUIDA
		# Virou líquido na bandeja: um respingo na cor dele.
		_respingar(Vector2(m.pos.x, poca.base - poca.funda), SUBSTANCIAS[m.tipo]["tona"])
		_assentar(m.tipo, poca.camara)


## A substância ficou no andar: a plaquinha dele ganha a cor e o desenho dela.
func _assentar(substancia: String, andar: int) -> void:
	if _ja_assentou.has(substancia):
		return
	_ja_assentou[substancia] = true
	_donos[andar] = substancia
	_pulsos[andar] = 1.0
	assentou.emit(substancia)


## Líquida: encostada nas vizinhas, só balançando no lugar.
func _boiar(m: Molecula, delta: float) -> void:
	var poca := _pocas[m.poca]
	m.pos.x = lerpf(m.pos.x, m.alvo_x, 1.0 - exp(-5.0 * delta))
	m.pos.y = lerpf(m.pos.y, _altura_na_poca(poca) + sin(m.relogio * 2.6), 1.0 - exp(-10.0 * delta))


# ─────────────────────────────────────────────────────────────
# GANHAR CALOR, FERVER E SUBIR
# ─────────────────────────────────────────────────────────────

## Onde o fundo para de subir na etapa FERVER: um grau antes do segundo ponto
## de ebulição, para só a substância que ferve primeiro sair. (Sem uma
## segunda, vai direto até a temperatura do fundo.)
func _parada_do_calor() -> float:
	var pontos: Array[float] = []
	for nome: String in SUBSTANCIAS:
		var ebulicao := float(SUBSTANCIAS[nome]["ebulicao"])
		if ebulicao < TEMPERATURA_DO_FUNDO and not pontos.has(ebulicao):
			pontos.append(ebulicao)
	pontos.sort()
	if pontos.size() < 2:
		return TEMPERATURA_DO_FUNDO
	return minf(pontos[1] - 1.0, TEMPERATURA_DO_FUNDO)


## O líquido ganha calor do ambiente e o fundo fica menos frio, até a parada
## da etapa. Cada ponto de ebulição por que ele passa é avisado (é quando
## aquela substância começa a ferver).
func _ganhar_calor(delta: float) -> void:
	var alvo := TEMPERATURA_DO_FUNDO if _etapa == Etapa.SEPARAR else _parada_do_calor()
	var antes := _temperatura_do_fundo
	_temperatura_do_fundo = move_toward(antes, alvo, GRAUS_POR_SEGUNDO * delta)
	for nome: String in SUBSTANCIAS:
		var ebulicao := float(SUBSTANCIAS[nome]["ebulicao"])
		if antes <= ebulicao and _temperatura_do_fundo > ebulicao and not _ja_ferveu.has(nome):
			_ja_ferveu[nome] = true
			_pulsos[0] = 1.0
			ferveu.emit(nome)


## A molécula ferve quando o fundo está mais quente que o ponto de ebulição dela.
func _ferve(m: Molecula) -> bool:
	return m.estado == Estado.LIQUIDA and m.poca < 2 \
		and float(SUBSTANCIAS[m.tipo]["ebulicao"]) < _temperatura_do_fundo - 0.001


func _ferver(delta: float) -> void:
	_proxima_emissao -= delta
	if _proxima_emissao > 0.0:
		return
	# Sai uma das que estão fervendo: da fileira de cima, se houver.
	var prontas: Array[Molecula] = []
	for fileira: int in [1, 0]:
		for m: Molecula in _pocas[fileira].moleculas:
			if _ferve(m):
				prontas.append(m)
		if not prontas.is_empty():
			break
	if prontas.is_empty():
		return
	_proxima_emissao = INTERVALO_DE_EMISSAO
	_soltar(prontas[randi() % prontas.size()])


## A molécula sai do líquido do fundo e ganha o caminho dela: até debaixo de
## cada fenda, por dentro dela, e assim até o andar em que vira líquido.
func _soltar(m: Molecula) -> void:
	var de_onde := m.pos.x
	_pocas[m.poca].moleculas.erase(m)
	m.poca = -1
	_fechar_o_buraco(de_onde)
	var destino := andar_de(m.tipo)
	var ate := destino if destino >= 0 else numero_de_andares() - 1
	var pontos := PackedVector2Array()
	var altura := _altura_de_voo(0)
	pontos.append(Vector2(m.pos.x, altura))
	for bandeja in ate:
		var fenda := _meio_da_fenda(bandeja) + randf_range(-FOLGA_NA_FENDA, FOLGA_NA_FENDA)
		pontos.append(Vector2(fenda, altura))
		altura = _altura_de_voo(bandeja + 1)
		pontos.append(Vector2(fenda, altura))
	m.caminho = pontos
	m.passo = 0
	m.camara = ate
	m.vel = Vector2(0.0, -VELOCIDADE_SUBINDO * 0.6)
	m.proxima_fumaca = 0.0
	m.estado = Estado.SUBINDO
	# Virou gás: um sopro de vapor no lugar de onde ela saiu.
	for i in 3:
		_soltar_fumaca(m.pos + Vector2(0.0, -6.0), Vector2(0.0, -30.0))


## Saiu uma molécula da fileira de baixo: a de cima que está mais perto desce
## para o lugar dela. O líquido não fica com buraco; ele baixa.
func _fechar_o_buraco(x: float) -> void:
	var baixo := _pocas[0]
	var cima := _pocas[1]
	if baixo.moleculas.size() >= baixo.cabem or cima.moleculas.is_empty():
		return
	var mais_perto: Molecula = null
	for m: Molecula in cima.moleculas:
		if mais_perto == null or absf(m.pos.x - x) < absf(mais_perto.pos.x - x):
			mais_perto = m
	cima.moleculas.erase(mais_perto)
	_por_na_poca(mais_perto, 0)


## Uma altura para atravessar o andar: acima do líquido, abaixo do teto.
func _altura_de_voo(andar: int) -> float:
	var teto := _teto_do_andar(andar) + FOLGA + 4.0
	var tona := _tona_do_andar(andar) - FOLGA - 6.0
	if andar == 0:
		tona = _chao_do_andar(0) - _altura_do_fundo - FOLGA - 6.0
	if andar >= _bandejas.size():
		# No andar de cima, perto da bandeja: é ali que ela vai virar líquido.
		teto = maxf(teto, tona - 70.0)
	return randf_range(minf(teto, tona), tona)


func _subir(m: Molecula, delta: float) -> void:
	var alvo := m.caminho[m.passo]
	var para_la := alvo - m.pos
	if para_la.length() < 10.0:
		m.passo += 1
		if m.passo >= m.caminho.size():
			_chegar(m)
			return
		alvo = m.caminho[m.passo]
		para_la = alvo - m.pos
	var direcao := para_la.normalized()
	# O gás não anda em linha reta: balança de um lado para o outro do rumo.
	var balanco := direcao.orthogonal() * sin(m.relogio * 7.0) * 26.0
	var querida := direcao * VELOCIDADE_SUBINDO + balanco
	m.vel = m.vel.lerp(querida, 1.0 - exp(-9.0 * delta))
	m.pos += m.vel * delta

	m.proxima_fumaca -= delta
	if m.proxima_fumaca <= 0.0:
		m.proxima_fumaca = 0.09
		_soltar_fumaca(m.pos, m.vel * 0.25)


## Chegou no andar dela. Se ainda cabe na bandeja, ela desce e vira líquido;
## senão, continua gás ali (no ponto de ebulição, líquido e gás convivem).
func _chegar(m: Molecula) -> void:
	var poca := _poca_de(m.tipo)
	if poca != null and poca.moleculas.size() < poca.cabem:
		_por_na_poca(m, _pocas.find(poca))
		m.estado = Estado.MERGULHANDO
		return
	m.vel = Vector2.from_angle(randf_range(PI * 0.75, PI * 1.25)) * VELOCIDADE_SOLTO
	m.estado = Estado.GAS_SOLTO


## Com o fundo já na temperatura dele e mais nada a caminho: se só sobrou lá o
## que não ferve, essa substância ficou no fundo. (É a última a ser anunciada:
## primeiro cada gás chega no andar dele.)
func _conferir_o_fundo() -> void:
	if _etapa != Etapa.SEPARAR or not is_equal_approx(_temperatura_do_fundo, TEMPERATURA_DO_FUNDO):
		return
	for m in _moleculas:
		if m.estado == Estado.SUBINDO or m.estado == Estado.MERGULHANDO:
			return
	var contas := {}
	for fileira in 2:
		for m: Molecula in _pocas[fileira].moleculas:
			if andar_de(m.tipo) != 0:
				return
			contas[m.tipo] = int(contas.get(m.tipo, 0)) + 1
	# (Se mais de uma substância não ferve, a plaquinha fica com a que há mais.)
	var nomes := contas.keys()
	nomes.sort_custom(func(a: String, b: String) -> bool: return contas[a] > contas[b])
	for i in range(nomes.size() - 1, -1, -1):
		_assentar(nomes[i], 0)
	if not nomes.is_empty():
		_donos[0] = nomes[0]


# ─────────────────────────────────────────────────────────────
# O FUNDO, AS BOLHAS, A FUMAÇA E A GEADA
# ─────────────────────────────────────────────────────────────

func _passo_do_fundo(delta: float) -> void:
	var fileira := 4.0 * ESCALA
	var alvo := 0.0
	if _tem_liquida(_pocas[1]):
		alvo = fileira * 2.0 + ESCALA
	elif _tem_liquida(_pocas[0]):
		alvo = fileira + ESCALA
	_altura_do_fundo = move_toward(_altura_do_fundo, alvo, delta * 40.0)


func _passo_das_bolhas(delta: float) -> void:
	var tona := _chao_do_andar(0) - _altura_do_fundo
	# Fervendo de verdade, ou só com o que sobrou parado no ponto de ebulição?
	var fervendo := false
	for fileira in 2:
		for m: Molecula in _pocas[fileira].moleculas:
			if _ferve(m):
				fervendo = true
	for i in range(_bolhas.size() - 1, -1, -1):
		var bolha := _bolhas[i]
		bolha.y -= bolha.z * delta
		if bolha.y <= tona + 3.0:
			# Estourou na tona: se está fervendo, sobe um fiapo de vapor.
			if fervendo:
				_soltar_fumaca(Vector2(bolha.x, tona - 4.0), Vector2(0.0, -34.0))
			_bolhas.remove_at(i)
		else:
			_bolhas[i] = bolha
	if _etapa < Etapa.FERVER or _altura_do_fundo < 8.0 or _calor < 1.0 \
			or _temperatura_do_fundo <= TEMPERATURA_DO_TOPO:
		return
	_proxima_bolha -= delta
	if _proxima_bolha <= 0.0:
		# Fervendo, muitas bolhas; senão, uma de vez em quando.
		_proxima_bolha = randf_range(0.07, 0.16) if fervendo else randf_range(0.5, 0.9)
		_bolhas.append(Vector3(randf_range(ESCALA * 2.0, _largura() - ESCALA * 3.0),
			_chao_do_andar(0) - 4.0, randf_range(42.0, 70.0)))


func _soltar_fumaca(pos: Vector2, vel: Vector2) -> void:
	if _fumaca.size() > 220:
		return
	_fumaca.append({"pos": pos + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)),
		"vel": vel + Vector2(randf_range(-10.0, 10.0), randf_range(-16.0, -4.0)),
		"idade": 0.0, "vida": randf_range(0.9, 1.4)})


func _passo_da_fumaca(delta: float) -> void:
	for i in range(_fumaca.size() - 1, -1, -1):
		var f := _fumaca[i]
		f["idade"] += delta
		if f["idade"] >= f["vida"]:
			_fumaca.remove_at(i)
			continue
		f["pos"] += f["vel"] * delta
		f["vel"] *= exp(-1.4 * delta)


## Três pinguinhos que pulam da tona quando uma molécula entra no líquido.
func _respingar(pos: Vector2, cor: Color) -> void:
	for lado: float in [-1.0, 0.0, 1.0]:
		_respingos.append({"pos": pos + Vector2(lado * 6.0, 0.0),
			"vel": Vector2(lado * randf_range(26.0, 44.0), randf_range(-95.0, -70.0)),
			"idade": 0.0, "cor": cor})


func _passo_dos_respingos(delta: float) -> void:
	for i in range(_respingos.size() - 1, -1, -1):
		var r := _respingos[i]
		r["idade"] += delta
		if r["idade"] >= 0.38:
			_respingos.remove_at(i)
			continue
		r["vel"] += Vector2(0.0, 420.0) * delta
		r["pos"] += r["vel"] * delta


## A geada: pontinhos brancos que caem da serpentina do resfriador e somem
## logo abaixo dela. É o frio, que vem de cima.
func _soltar_geada() -> void:
	if not _serpentina.has_area() or _geada.size() > 60:
		return
	_geada.append({"pos": Vector2(randf_range(_serpentina.position.x, _serpentina.end.x) * ESCALA,
			float(_serpentina.end.y) * ESCALA),
		"vel": Vector2(randf_range(-8.0, 8.0), randf_range(22.0, 40.0)),
		"idade": 0.0, "vida": randf_range(0.8, 1.5)})


func _passo_da_geada(delta: float) -> void:
	for i in range(_geada.size() - 1, -1, -1):
		var g := _geada[i]
		g["idade"] += delta
		if g["idade"] >= g["vida"]:
			_geada.remove_at(i)
			continue
		g["pos"] += g["vel"] * delta
	if _resfriador < 1.0 or _fechando:
		return
	_proxima_geada -= delta
	if _proxima_geada <= 0.0:
		_proxima_geada = randf_range(0.12, 0.26)
		_soltar_geada()


# ─────────────────────────────────────────────────────────────
# DESENHO
# ─────────────────────────────────────────────────────────────

func _draw() -> void:
	if _textura == null:
		return
	var tamanho := tamanho_da_coluna()
	var altura_arte := _recorte_raio_x.size.y
	# Até que linha da arte o raio X já desceu.
	var corte := clampi(roundi(altura_arte * _raio_x), 0, altura_arte)

	if corte < altura_arte:
		_desenhar_fatia(_textura, _recorte_aco, corte, altura_arte)
	if corte > 0:
		_desenhar_fatia(_textura, _recorte_raio_x, 0, corte)

	if _raio_x >= 1.0:
		_desenhar_calor_do_ambiente()
		_desenhar_serpentina()
		if _conteudo > 0.0:
			_desenhar_liquidos()
			_desenhar_bolhas()
			_desenhar_geada()
			_desenhar_fumaca()
			_desenhar_moleculas()
			_desenhar_respingos()
		# Paredes e bandejas por cima: nada passa na frente delas.
		if _linhas_tex != null:
			draw_texture_rect(_linhas_tex, Rect2(Vector2.ZERO, tamanho), false)
		_desenhar_regua()
		_desenhar_plaquinhas()
	elif corte > 0 and corte < altura_arte:
		# A faixa de luz do raio X, com dois rastros atrás dela.
		var y := corte * ESCALA
		draw_rect(Rect2(0.0, y - ESCALA, tamanho.x, ESCALA), EstiloHUD.CLARO)
		draw_rect(Rect2(0.0, y - ESCALA * 3.0, tamanho.x, ESCALA), Color(EstiloHUD.CLARO, 0.35))
		draw_rect(Rect2(0.0, y - ESCALA * 6.0, tamanho.x, ESCALA), Color(EstiloHUD.CLARO, 0.15))


## Um pedaço (das linhas y0 a y1 da arte) de um dos dois desenhos da folha.
func _desenhar_fatia(textura: Texture2D, recorte: Rect2i, y0: int, y1: int) -> void:
	draw_texture_rect_region(textura,
		Rect2(0.0, y0 * ESCALA, recorte.size.x * ESCALA, (y1 - y0) * ESCALA),
		Rect2(recorte.position.x, recorte.position.y + y0, recorte.size.x, y1 - y0))


## O CALOR DO AMBIENTE entrando por baixo: setinhas laranja embaixo do piso,
## entre os pés, que sobem um pixel e voltam. Não é aparelho nenhum: a coluna é
## muito mais fria que tudo em volta, e o calor de fora entra sozinho.
func _desenhar_calor_do_ambiente() -> void:
	if _calor <= 0.0:
		return
	var sobe := int(_relogio * 3.0) % 2
	var cor := Color(COR_DO_CALOR_CLARA if sobe == 1 else COR_DO_CALOR, _calor * _conteudo)
	var y := float(_piso + 3 - sobe) * ESCALA
	for vao in _vaos_dos_pes:
		# Uma setinha de 3 x 2 pixels da arte a cada 5: a ponta em cima, as
		# duas pernas embaixo.
		var x := vao.x + 1
		while x + 2 <= vao.y:
			draw_rect(Rect2((x + 1) * ESCALA, y, ESCALA, ESCALA), cor)
			draw_rect(Rect2(x * ESCALA, y + ESCALA, ESCALA, ESCALA), cor)
			draw_rect(Rect2((x + 2) * ESCALA, y + ESCALA, ESCALA, ESCALA), cor)
			x += 5


## A serpentina do resfriador, dentro da cúpula: o mesmo fio, em azul de gelo.
func _desenhar_serpentina() -> void:
	if not _serpentina.has_area():
		return
	_desenhar_fio(_serpentina.position.x, _serpentina.end.x - 1, _serpentina.position.y * ESCALA,
		_resfriador, COR_SERPENTINA_PARADA, COR_SERPENTINA, COR_SERPENTINA_CLARA)


## Um fio em zigue-zague de 3 linhas, da coluna x0 à x1 da arte. "ligado" vai
## de 0 (a cor parada) a 1 (piscando entre as duas cores acesas).
func _desenhar_fio(x0: int, x1: int, y: float, ligado: float, parada: Color, acesa: Color,
		clara: Color) -> void:
	var zigue: Array[int] = [0, 1, 2, 1]
	for x in range(x0, x1 + 1):
		var cor := parada
		if ligado > 0.0:
			var pisca := (x + int(_relogio * 9.0)) % 3 == 0
			cor = parada.lerp(clara if pisca else acesa, ligado)
		draw_rect(Rect2(x * ESCALA, y + zigue[(x - x0) % 4] * ESCALA, ESCALA, ESCALA), cor)


func _desenhar_liquidos() -> void:
	# O líquido do fundo: o ar misturado e, quando só sobra uma substância, ela.
	if _altura_do_fundo > 0.5:
		var altura := roundf(_altura_do_fundo)
		var cor := COR_MISTURA
		var tona := COR_TONA_MISTURA
		if _donos[0] != "":
			cor = SUBSTANCIAS[_donos[0]]["liquido"]
			tona = SUBSTANCIAS[_donos[0]]["tona"]
		_desenhar_liquido(Rect2(ESCALA, _chao_do_andar(0) - altura, _largura() - ESCALA * 2.0, altura),
			cor, tona, 1.0)
	# O de cada bandeja.
	for i in range(2, _pocas.size()):
		var poca := _pocas[i]
		if poca.nivel <= 0.0 or poca.substancia == "":
			continue
		var altura := roundf(poca.funda * poca.nivel)
		var dados: Dictionary = SUBSTANCIAS[poca.substancia]
		_desenhar_liquido(Rect2(poca.x0, poca.base - altura, poca.x1 - poca.x0, altura),
			dados["liquido"], dados["tona"], poca.nivel)


## Um líquido: a cor chapada e, em cima, a tona em ondinhas de 2 px que andam.
func _desenhar_liquido(caixa: Rect2, cor: Color, tona: Color, forca: float) -> void:
	var alfa := _conteudo * clampf(forca * 1.5, 0.0, 1.0)
	draw_rect(caixa, Color(cor, cor.a * alfa))
	var passo := 8.0
	var onda := int(_relogio * 3.0)
	var x := caixa.position.x
	var i := 0
	while x < caixa.end.x:
		var largura := minf(passo, caixa.end.x - x)
		var sobe := 2.0 if (i + onda) % 3 == 0 else 0.0
		draw_rect(Rect2(x, caixa.position.y - sobe, largura, 2.0), Color(tona, alfa))
		x += passo
		i += 1


## Bolhas: aneizinhos de 8 px subindo pelo líquido do fundo.
func _desenhar_bolhas() -> void:
	var cor := Color(COR_TONA_MISTURA, 0.85 * _conteudo)
	for bolha in _bolhas:
		var canto := Vector2(roundf(bolha.x), roundf(bolha.y))
		draw_rect(Rect2(canto + Vector2(2, 0), Vector2(4, 2)), cor)
		draw_rect(Rect2(canto + Vector2(2, 6), Vector2(4, 2)), cor)
		draw_rect(Rect2(canto + Vector2(0, 2), Vector2(2, 4)), cor)
		draw_rect(Rect2(canto + Vector2(6, 2), Vector2(2, 4)), cor)


## A geada do resfriador: quadradinhos claros que somem em dois degraus.
func _desenhar_geada() -> void:
	for g in _geada:
		var t: float = g["idade"] / g["vida"]
		var pos: Vector2 = g["pos"]
		draw_rect(Rect2((pos / 2.0).floor() * 2.0, Vector2(4, 4)),
			_com_conteudo(Color(COR_SERPENTINA_CLARA, 0.85 if t < 0.55 else 0.4)))


## O gás. Cada fiapo de fumaça soma um tanto de "névoa" nos pixels da arte em
## volta dele (mais no meio, menos na beirada; a mancha cresce e enfraquece
## com a idade). Depois a névoa vira desenho em DOIS TONS chapados, com a
## beirada pontilhada: nuvem de pixel art, na grade do pixel da coluna. A cor é
## a da temperatura do andar em que ela está, a mesma da régua: é o gás
## esfriando enquanto sobe.
func _desenhar_fumaca() -> void:
	if _fumaca.is_empty() or _nevoa.is_empty():
		return
	var largura := _recorte_raio_x.size.x
	var altura := _recorte_raio_x.size.y
	_nevoa.fill(0.0)
	var topo := altura
	var base := -1
	for f in _fumaca:
		var t: float = f["idade"] / f["vida"]
		var raio := lerpf(1.5, 3.3, t)
		# Entra de uma vez e vai sumindo.
		var forca := minf(t * 8.0, 1.0) * (1.0 - t * t)
		var meio: Vector2 = f["pos"] / ESCALA
		var y0 := maxi(0, floori(meio.y - raio))
		var y1 := mini(altura - 1, ceili(meio.y + raio))
		topo = mini(topo, y0)
		base = maxi(base, y1)
		for y in range(y0, y1 + 1):
			for x in range(maxi(0, floori(meio.x - raio)), mini(largura - 1, ceili(meio.x + raio)) + 1):
				var d := (Vector2(x + 0.5, y + 0.5) - meio).length_squared() / (raio * raio)
				if d < 1.0:
					_nevoa[y * largura + x] += forca * (1.0 - d)

	var andar_da_cor := -1
	var fraco := Color()
	var forte := Color()
	for y in range(topo, base + 1):
		if _andar_da_linha[y] != andar_da_cor:
			andar_da_cor = _andar_da_linha[y]
			# Clareada: é vapor, não fumaça.
			var cor := cor_da_temperatura(temperatura_do_andar(andar_da_cor)).lightened(0.3)
			fraco = _com_conteudo(Color(cor, 0.24))
			forte = _com_conteudo(Color(cor, 0.46))
		var x := 0
		while x < largura:
			var tom := _tom_da_nevoa(x, y, largura)
			if tom == 0:
				x += 1
				continue
			# Pixels vizinhos do mesmo tom viram um retângulo só.
			var x0 := x
			while x < largura and _tom_da_nevoa(x, y, largura) == tom:
				x += 1
			draw_rect(Rect2(x0 * ESCALA, y * ESCALA, (x - x0) * ESCALA, ESCALA),
				forte if tom == 2 else fraco)


## 0 = nada, 1 = tom fraco, 2 = tom forte. Só dentro do miolo da coluna.
func _tom_da_nevoa(x: int, y: int, largura: int) -> int:
	var i := y * largura + x
	if _e_miolo[i] == 0:
		return 0
	var n := _nevoa[i]
	if n >= NEVOA_FORTE:
		return 2
	if n >= NEVOA_FRACA:
		return 1
	if n >= NEVOA_PONTILHADA and (x + y) % 2 == 0:
		return 1
	return 0


func _desenhar_respingos() -> void:
	for r in _respingos:
		var pos: Vector2 = r["pos"]
		draw_rect(Rect2((pos / 2.0).floor() * 2.0, Vector2(4, 4)), _com_conteudo(r["cor"]))


func _com_conteudo(cor: Color) -> Color:
	return Color(cor, cor.a * _conteudo)


func _desenhar_moleculas() -> void:
	if _moleculas_tex == null:
		return
	var lado := CELULA_DA_MOLECULA * ESCALA_MOLECULA
	for m in _moleculas:
		if m.estado == Estado.FORA or m.tamanho <= 0.0:
			continue
		var quadro := 0
		if m.estado != Estado.LIQUIDA:
			quadro = int(m.relogio * m.giro) % QUADROS_DA_MOLECULA
		# O estalo de entrada: passa um pouco do tamanho e volta.
		var estalo := 1.0 + 0.35 * sin(m.tamanho * PI) if m.tamanho < 1.0 else 1.0
		var medida := Vector2(lado, lado) * m.tamanho * estalo
		draw_texture_rect_region(_moleculas_tex,
			Rect2((m.pos - medida * 0.5).round(), medida.round()),
			Rect2(quadro * CELULA_DA_MOLECULA, int(SUBSTANCIAS[m.tipo]["linha"]) * CELULA_DA_MOLECULA,
				CELULA_DA_MOLECULA, CELULA_DA_MOLECULA),
			Color(1, 1, 1, _conteudo))


## A RÉGUA DE TEMPERATURA, colada na parede esquerda: um trecho por andar, da
## cor da temperatura dele agora. É ela que mostra a coluna menos fria embaixo
## (onde o líquido ganha calor do ambiente) e mais fria em cima (onde está o
## resfriador).
func _desenhar_regua() -> void:
	var alfa := _regua * _conteudo
	if alfa <= 0.004:
		return
	var x := -(DISTANCIA_DA_REGUA + LARGURA_DA_REGUA)
	var de_cima := _trecho_da_regua(numero_de_andares() - 1).x
	var de_baixo := _trecho_da_regua(0).y
	draw_rect(Rect2(x - 2.0, de_cima - 2.0, LARGURA_DA_REGUA + 4.0, de_baixo - de_cima + 4.0),
		EstiloHUD.com_alfa(EstiloHUD.CONTORNO, alfa))
	for andar in numero_de_andares():
		var trecho := _trecho_da_regua(andar)
		# 2 px de contorno entre um trecho e o seguinte.
		var folga := 0.0 if andar == 0 else 2.0
		draw_rect(Rect2(x, trecho.x, LARGURA_DA_REGUA, trecho.y - trecho.x - folga),
			EstiloHUD.com_alfa(cor_da_temperatura(temperatura_do_andar(andar)), alfa))


## As plaquinhas de temperatura, à esquerda da régua: a do fundo, a do topo e
## a de cada andar em que uma substância ficou — essa na cor dela e com o
## desenho da molécula (e dá um pulo na hora).
func _desenhar_plaquinhas() -> void:
	var topo := _etiquetas.size() - 1
	for andar in _etiquetas.size():
		var alfa := _etiquetas[andar] * _conteudo
		if alfa <= 0.004:
			continue
		var dono := _donos[andar]
		var papel: Color = SUBSTANCIAS[dono]["tona"] if dono != "" else EstiloHUD.PAPEL
		var texto := "%d °C" % graus_do_andar(andar)
		var lugar := lugar_da_plaquinha(andar)
		var caixa := plaquinha(self, lugar, texto, papel, alfa, sin(_pulsos[andar] * PI) * 5.0, dono)
		# De onde vem o frio e de onde vem o calor: o resfriador em cima do
		# topo, o calor do ambiente embaixo do fundo.
		if andar == topo and topo > 0 and _resfriador > 0.0:
			legenda(self, Vector2(caixa.get_center().x, caixa.position.y), LEGENDA_DO_RESFRIADOR,
				alfa * _resfriador)
		elif andar == 0 and _calor > 0.0:
			legenda(self, Vector2(caixa.get_center().x, caixa.end.y), LEGENDA_DO_CALOR,
				alfa * _calor, true)


## A PLAQUINHA DE TEMPERATURA: uma ficha pequena (papel, moldura de tinta e a
## sombra dura embaixo, como as do HUD), presa pelo meio do lado direito. A
## ficha de cada substância usa a mesma para o ponto de ebulição: é por serem
## iguais que se vê que o número do andar e o da substância são o mesmo.
## "inchada" são os px a mais de cada lado, no pulo; "substancia" põe o desenho
## da molécula dela antes do número. Devolve o retângulo dela.
static func plaquinha(ci: CanvasItem, direita_meio: Vector2, texto: String,
		papel: Color = EstiloHUD.PAPEL, alfa: float = 1.0, inchada: float = 0.0,
		substancia: String = "") -> Rect2:
	var com_desenho := SUBSTANCIAS.has(substancia) and _textura_das_moleculas() != null
	var caixa := retangulo_da_plaquinha(direita_meio, texto, com_desenho)
	EstiloHUD.ficha(ci, caixa.grow(roundf(inchada)), alfa, papel, EstiloHUD.TINTA, 2.0, 2.0)
	var x := caixa.position.x + 10.0
	if com_desenho:
		var lado := CELULA_DA_MOLECULA * ESCALA_MOLECULA
		ci.draw_texture_rect_region(_textura_das_moleculas(),
			Rect2(x - 2.0, roundf(caixa.get_center().y - lado * 0.5 - 1.0), lado, lado),
			Rect2(0, int(SUBSTANCIAS[substancia]["linha"]) * CELULA_DA_MOLECULA,
				CELULA_DA_MOLECULA, CELULA_DA_MOLECULA),
			Color(1, 1, 1, alfa))
		x += LARGURA_DO_DESENHO_NA_PLAQUINHA
	ci.draw_string(FONTE, Vector2(x, caixa.position.y + 7.0 + roundf(FONTE.get_ascent(TAMANHO_DA_LETRA) * 0.86)),
		texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO_DA_LETRA, EstiloHUD.com_alfa(EstiloHUD.TINTA, alfa))
	return caixa


static func retangulo_da_plaquinha(direita_meio: Vector2, texto: String,
		com_desenho: bool = false) -> Rect2:
	var largura := FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO_DA_LETRA).x + 20.0
	if com_desenho:
		largura += LARGURA_DO_DESENHO_NA_PLAQUINHA
	return Rect2(roundf(direita_meio.x - largura), roundf(direita_meio.y - 16.0), largura, 32.0)


## O nome de uma plaquinha ou de uma fileira delas ("RESFRIADOR", "PONTO DE
## EBULIÇÃO"): letra miúda e clara, com contorno, centrada em cima dela — ou
## embaixo, com "embaixo". "meio" é o meio do lado de cima (ou de baixo) da
## plaquinha; "\n" quebra a linha.
static func legenda(ci: CanvasItem, meio: Vector2, texto: String, alfa: float = 1.0,
		embaixo: bool = false) -> void:
	var linhas := texto.split("\n")
	for i in linhas.size():
		var largura := FONTE.get_string_size(linhas[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var y := meio.y + 18.0 + i * 15.0 if embaixo else meio.y - 9.0 - (linhas.size() - 1 - i) * 15.0
		EstiloHUD.rotulo(ci, FONTE, Vector2(roundf(meio.x - largura * 0.5), y), linhas[i], 11,
			EstiloHUD.CLARO, alfa)
