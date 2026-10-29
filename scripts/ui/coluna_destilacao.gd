@tool
class_name ColunaDestilacao
extends Control

# --- A COLUNA DE DESTILAÇÃO POR DENTRO (o desenho animado da explicação) ---
#
# É a coluna da fase do nitrogênio vista em raio X, com o ar sendo separado
# dentro dela. Quem a põe na tela e a rege é a explicação do Dr. Chico
# (scripts/explicacao_destilador.gd); este nó desenha e anima.
#
# A FÍSICA NÃO É ENCENADA: por baixo do desenho roda a mesma coluna do
# simulador do Laboratório e do puzzle (ColunaDoSimulador, escondida — o
# "motor"), com o mesmo ar (MisturasDoDestilador, "ar": 22 N₂, 7 O₂ e 2 Ar, o
# argônio aumentado para aparecer). A explicação só diz até onde o calor do
# ambiente leva o fundo em cada etapa; quem decide qual molécula evapora,
# condensa ou escorre é a conta (ver EquilibrioLiquidoVapor). Este nó lê o
# motor e desenha tudo com a arte da história (as moléculas de "moleculas do
# ar.png", as plaquinhas, a geada do resfriador).
#
# COMO UMA COLUNA DESSAS FUNCIONA (é isto que o desenho mostra):
#
#   * Cada substância tem um PONTO DE EBULIÇÃO: o nitrogênio -196 °C, o argônio
#     -186 °C, o oxigênio -183 °C. Mas EVAPORAR elas evaporam abaixo dele: as
#     moléculas mais agitadas da superfície escapam em qualquer temperatura
#     (a roupa no varal seca a 25 °C). Num lugar fechado, tanto escapa quanto
#     volta: é o vai-e-volta da superfície do líquido.
#   * A MISTURA ferve numa temperatura entre os pontos de ebulição dela: o ar
#     líquido, a uns -194 °C. E o vapor tem de tudo: uns 90% de nitrogênio (o
#     que evapora mais fácil) e o resto de oxigênio e argônio, que evaporam ali
#     uns 10 °C abaixo do ponto de ebulição deles.
#   * O calor não vem de máquina nenhuma: a -200 °C o ar líquido é muito mais
#     frio que tudo em volta, e o CALOR DO AMBIENTE vai entrando sozinho. Quem
#     tira calor é o RESFRIADOR, a serpentina da cúpula: por isso o fundo é o
#     lugar menos frio e o topo, o mais frio. Fervendo, o fundo não esquenta: o
#     calor vai todo para virar vapor. Mas, como sai mais nitrogênio, o líquido
#     que fica é cada vez mais rico em oxigênio e ferve cada vez mais quente.
#   * O vapor sobe e esfria. Nas bandejas e no topo, perto do resfriador, ele
#     condensa; numa bandeja quente demais para aquele líquido, ele ferve de
#     novo. A cada vez fica mais rico em nitrogênio: é a destilação
#     FRACIONADA.
#   * No fim: topo rico em nitrogênio, fundo rico em oxigênio, e o argônio (que
#     ferve quase junto com o oxigênio) misturado no meio. Nada sai 100% puro.
#
# O QUE SE VÊ, NA ORDEM (cada parte é uma Etapa, pedida com ir_para):
#
#   FECHADA      a coluna de aço, como ela é no mapa.
#   RAIO_X       uma faixa de luz desce por ela e o aço vira o desenho preto,
#                com as bandejas à mostra.
#   AR_LIQUIDO   o ar entra no fundo já LÍQUIDO, a -200 °C: as moléculas dos
#                três tipos misturadas e encostadas.
#   EVAPORAR     ainda a -200 °C, nada ferve, mas moléculas da superfície pulam
#                para fora e voltam — mais de nitrogênio, às vezes uma de
#                oxigênio ou argônio. O vai-e-volta fica mais frequente aqui
#                (RITMO_DOS_PULOS_AO_EVAPORAR), para dar tempo de ver.
#   FERVER       o resfriador liga e o calor do ambiente leva o fundo até
#                TEMPERATURA_AO_FERVER: a uns -194 °C a mistura começa a ferver
#                e o fundo vai esquentando conforme o nitrogênio sai.
#   SEPARAR      o fundo segue até TEMPERATURA_DO_FUNDO e a coluna assenta.
#
# Além das etapas, mostrar_pureza() faz aparecer, no topo e no fundo, quanto do
# líquido de lá é da substância que mais tem ali ("95% NITROGÊNIO").
#
# A ARTE É LIDA SOZINHA. "coluna de destilação.png" tem dois desenhos lado a
# lado, o de aço e o de raio X. Do de raio X saem as bandejas: toda barra clara
# presa em uma parede só é uma bandeja, o vão que sobra do outro lado é a fenda
# por onde o gás sobe, e o dente na ponta dela é a borda que segura o líquido.
# Pode redesenhar, mudar de tamanho e pôr mais bandejas: o desenho animado
# acompanha (ver _ler_arte) — e o motor lê a mesma arte (ArteDaColuna).
#
# ONDE MEXER:
#   MISTURA        a chave da mistura em MisturasDoDestilador (quantas moléculas
#                  de cada, os pontos de ebulição e as pressões de vapor).
#   SUBSTANCIAS    a linha de cada uma na folha das moléculas e as cores.
#   TEMPERATURA_AO_FERVER / TEMPERATURA_DO_FUNDO
#                  até onde o calor do ambiente leva o fundo em FERVER e no fim.
#   RAMPA_DE_TEMPERATURA   as cores da régua (e do gás), do mais frio ao menos.
#   os tempos      logo abaixo.
#   assets/fase nitrogenio/moleculas do ar.png
#                  a arte das moléculas pequenas: 3 linhas (N₂, O₂, Ar) de 4
#                  quadros de 12×12 px — a molécula girando. O 1º quadro
#                  (deitada) é o que aparece dentro do líquido e nas plaquinhas.

## Uma substância começou a evaporar de verdade: a primeira molécula dela saiu
## do líquido como vapor (todas evaporam, cada uma no seu ritmo).
signal ferveu(substancia: String)
## A primeira molécula de vapor da substância virou líquido lá em cima (numa
## bandeja ou no topo).
signal assentou(substancia: String)
## A coluna assentou no fim (o fundo chegou na temperatura dele e nada mais se
## mexe).
signal separou

enum Etapa { FECHADA, RAIO_X, AR_LIQUIDO, EVAPORAR, FERVER, SEPARAR }

const CAMINHO_ARTE := "res://assets/fase nitrogenio/coluna de destilação.png"
const CAMINHO_MOLECULAS := "res://assets/fase nitrogenio/moleculas do ar.png"
const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

## Quantos px de tela vale cada pixel da arte da coluna.
const ESCALA := 4.0
## E cada pixel da arte das moléculas: a metade, para caberem deitadas na
## poça de uma bandeja.
const ESCALA_MOLECULA := 2.0
const CELULA_DA_MOLECULA := 12
const QUADROS_DA_MOLECULA := 4

# ── O AR ──
## A mistura que entra na coluna (uma chave de MisturasDoDestilador.MISTURAS).
const MISTURA := "ar"
## "linha" é a linha da substância na folha das moléculas. "ebulicao" é o ponto
## de ebulição dela pura, em °C, como as fichas o mostram (os de verdade: -195,8,
## -185,8 e -183,0; a conta usa a pressão de vapor de MisturasDoDestilador).
const SUBSTANCIAS := {
	"N2": {"linha": 0, "ebulicao": -196, "liquido": Color("0f4a37"), "tona": Color("58d68d")},
	"O2": {"linha": 1, "ebulicao": -183, "liquido": Color("15186b"), "tona": Color("7f8cff")},
	"Ar": {"linha": 2, "ebulicao": -186, "liquido": Color("47206a"), "tona": Color("d9a6ff")},
}

# ── AS TEMPERATURAS (°C) ──
## O ar entra na coluna já líquido (abaixo de uns -194 °C ele não ferve).
const TEMPERATURA_DO_AR_LIQUIDO := -200.0
## Até onde o calor do ambiente leva o fundo na etapa FERVER. A mistura começa
## a ferver antes, a uns -194 °C, e o fundo vai subindo conforme o nitrogênio
## sai dele.
const TEMPERATURA_AO_FERVER := -190.0
## Onde o fundo estaciona no fim: um pouco abaixo do ponto de ebulição do
## oxigênio, que por isso fica (quase todo) lá.
const TEMPERATURA_DO_FUNDO := -188.0
## Onde o resfriador segura o topo: o ponto de ebulição do nitrogênio.
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
## Quantos graus o calor do ambiente leva o fundo a subir por segundo (quando
## nada ferve; fervendo, quem manda é o ponto de ebulição da mistura).
const GRAUS_POR_SEGUNDO := 2.0
## Na etapa EVAPORAR o vai-e-volta da superfície fica tantas vezes mais
## frequente, para dar tempo de vê-lo (não muda nada na conta).
const RITMO_DOS_PULOS_AO_EVAPORAR := 3.0
## Quanto tempo, no mínimo, a etapa EVAPORAR fica na tela.
const DURACAO_MINIMA_DE_EVAPORAR := 1.2
## Quando a explicação pede uma etapa com a anterior ainda no meio, a anterior
## corre nesta pressa até acabar.
const PRESSA_PARA_ALCANCAR := 6.0
## O passo da conta da coluna de verdade, sempre o mesmo (ver _passo).
const PASSO_DO_MOTOR := 1.0 / 60.0

# ── MEDIDAS (px de tela) ──
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
## A etiqueta de pureza: "93% NITROGÊNIO", acima do líquido do topo e do fundo.
const TEXTO_DA_PUREZA := "%d%% %s"
const LETRA_DA_PUREZA := 15

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
const COR_DA_BOLHA := Color("8fc1e8")


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
## A coluna de verdade, escondida: é ela que faz a conta.
var _motor: ColunaDoSimulador
var _etapa: Etapa = Etapa.FECHADA
var _pedida: Etapa = Etapa.FECHADA
var _relogio_da_etapa: float = 0.0
var _relogio: float = 0.0
## 0 = aço, 1 = raio X: quanto da coluna, de cima para baixo, já virou.
var _raio_x: float = 0.0
## 0..1: o que tem dentro (moléculas, líquidos, régua, plaquinhas) some ao fechar.
var _conteudo: float = 1.0
var _fechando: bool = false
## 0..1: o calor do ambiente e o resfriador aparecendo.
var _calor: float = 0.0
var _resfriador: float = 0.0
## 0..1: a régua de temperatura aparecendo.
var _regua: float = 0.0
## 0..1: as etiquetas de pureza do topo e do fundo aparecendo.
var _pureza_a_vista: float = 0.0
var _mostrar_pureza: bool = false
## Na etapa AR_LIQUIDO, quando cada molécula (na ordem do motor) aparece.
var _entrada := PackedFloat32Array()
var _proxima_geada: float = 0.0
var _geada: Array[Dictionary] = []
## Por andar: quanto da plaquinha de temperatura já apareceu (0..1).
var _etiquetas := PackedFloat32Array()
## Por andar: 1 quando alguma coisa acaba de acontecer ali; volta a 0 sozinho.
var _pulsos := PackedFloat32Array()
var _ja_ferveu: Dictionary = {}
var _ja_assentou: Dictionary = {}
var _avisou_separou: bool = false
## O tempo da animação que ainda não virou passo do motor.
var _tempo_do_motor: float = 0.0

## Multiplica o tempo da animação (a explicação acelera quando a pessoa passa
## as falas depressa).
var ritmo: float = 1.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ler_arte()
	custom_minimum_size = tamanho_da_coluna()
	size = custom_minimum_size
	if not Engine.is_editor_hint():
		_motor = ColunaDoSimulador.new()
		_motor.name = "Motor"
		_motor.visible = false
		add_child(_motor)
		_motor.set_process(false)
		_motor.graus_por_segundo = GRAUS_POR_SEGUNDO
		_motor.ferveu.connect(_ao_ferver)
		_motor.condensou.connect(_ao_condensar)
		_motor.mudou.connect(queue_redraw)
	var andares := numero_de_andares()
	_etiquetas.resize(andares)
	_pulsos.resize(andares)
	reiniciar()
	if Engine.is_editor_hint():
		# No editor fica o desenho de raio X pronto (régua, calor do ambiente,
		# resfriador e as plaquinhas das duas pontas), para posicionar.
		_raio_x = 1.0
		_regua = 1.0
		_calor = 1.0
		_resfriador = 1.0
		_etiquetas[0] = 1.0
		_etiquetas[_etiquetas.size() - 1] = 1.0
		set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	avancar(delta)


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

## Volta ao começo: a coluna de aço, com o ar líquido pronto para entrar.
func reiniciar() -> void:
	_etapa = Etapa.FECHADA
	_pedida = Etapa.FECHADA
	_relogio_da_etapa = 0.0
	_raio_x = 0.0
	_conteudo = 1.0
	_fechando = false
	_calor = 0.0
	_resfriador = 0.0
	_regua = 0.0
	_pureza_a_vista = 0.0
	_mostrar_pureza = false
	_proxima_geada = 0.0
	_geada.clear()
	_ja_ferveu.clear()
	_ja_assentou.clear()
	_avisou_separou = false
	_tempo_do_motor = 0.0
	_etiquetas.fill(0.0)
	_pulsos.fill(0.0)
	if _motor != null:
		_motor.definir_mistura(MisturasDoDestilador.mistura(MISTURA))
		_motor.ritmo_dos_pulos = 1.0
		_entrada.resize(_motor.total_de_moleculas())
		# Cada uma entra na sua vez: da esquerda para a direita, de baixo para
		# cima, como se o líquido fosse enchendo o fundo.
		var ordem := range(_motor.total_de_moleculas())
		var particulas := _motor.particulas()
		ordem.sort_custom(func(a: int, b: int) -> bool:
			var pa: ColunaDoSimulador.Particula = particulas[a]
			var pb: ColunaDoSimulador.Particula = particulas[b]
			if absf(pa.alvo.y - pb.alvo.y) > 1.0:
				return pa.alvo.y > pb.alvo.y
			return pa.alvo.x < pb.alvo.x)
		for i in ordem.size():
			_entrada[ordem[i]] = i * INTERVALO_DE_ENTRADA
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


## As etiquetas de pureza do topo e do fundo aparecem ("93% NITROGÊNIO").
func mostrar_pureza() -> void:
	_mostrar_pureza = true


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


## A coluna de verdade que faz a conta (para os testes olharem lá dentro).
func motor() -> ColunaDoSimulador:
	return _motor


## A temperatura do fundo agora, em °C.
func temperatura_do_fundo() -> float:
	return _motor.temperatura() if _motor != null else TEMPERATURA_DO_FUNDO


## A temperatura do topo agora: ele acompanha o fundo só até o resfriador
## segurar.
func temperatura_do_topo() -> float:
	return minf(temperatura_do_fundo(), TEMPERATURA_DO_TOPO)


## A temperatura do andar agora (0 = o fundo): os do meio ficam repartidos por
## igual entre a do fundo e a do topo.
func temperatura_do_andar(andar: int) -> float:
	return lerpf(temperatura_do_fundo(), temperatura_do_topo(), _altura_relativa(andar))


## A mesma, com a coluna já no fim (o fundo em TEMPERATURA_DO_FUNDO).
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


## Já saiu alguma molécula dela como vapor?
func ja_ferveu(substancia: String) -> bool:
	return _ja_ferveu.has(substancia)


## Alguma molécula dela já condensou lá em cima?
func ja_assentou(substancia: String) -> bool:
	return _ja_assentou.has(substancia)


## A substância que é a maioria no líquido do andar ("" se nenhuma, ou vazio).
func dono_do_andar(andar: int) -> String:
	if _motor == null or andar < 0 or andar >= numero_de_andares():
		return ""
	return _motor.dono_do_andar(andar)


## Quantas moléculas estão no líquido do andar: de uma substância, ou todas ("").
func liquidas_no_andar(andar: int, substancia: String = "") -> int:
	if _motor == null:
		return 0
	var contas := _motor.contas_do_andar(andar)
	if substancia != "":
		return int(contas.get(substancia, 0))
	var total := 0
	for chave: String in contas:
		total += int(contas[chave])
	return total


## Quantas moléculas estão no líquido do fundo: de uma substância, ou todas ("").
func liquidas_no_fundo(substancia: String = "") -> int:
	return liquidas_no_andar(0, substancia)


## Que fração do líquido do andar é desta substância (0..1).
func fracao(andar: int, substancia: String) -> float:
	return _motor.fracao(andar, substancia) if _motor != null else 0.0


func total_de_moleculas() -> int:
	return _motor.total_de_moleculas() if _motor != null else 0


## True quando a coluna chegou no fim: o fundo na temperatura dele e nada mais
## fervendo, subindo ou escorrendo.
func separado() -> bool:
	return _etapa == Etapa.SEPARAR and _motor != null and _motor.parada()


## Onde fica a plaquinha de temperatura do andar (o meio do lado direito dela).
func lugar_da_plaquinha(andar: int) -> Vector2:
	return Vector2(-(DISTANCIA_DA_REGUA + LARGURA_DA_REGUA + DISTANCIA_DA_PLAQUINHA),
		roundf(_meio_do_andar(andar)))


## O texto da etiqueta de pureza do andar ("93% NITROGÊNIO"), da substância
## que mais tem no líquido dele (mesmo sem ser mais da metade), ou "" se o
## andar está seco.
func texto_da_pureza(andar: int) -> String:
	var principal := principal_do_andar(andar)
	if principal == "":
		return ""
	var nome := String(MisturasDoDestilador.substancia(principal).get("nome", principal)).to_upper()
	return TEXTO_DA_PUREZA % [roundi(fracao(andar, principal) * 100.0), nome]


## A substância que mais tem no líquido do andar ("" se ele está seco). Num
## empate, a que vem primeiro na mistura.
func principal_do_andar(andar: int) -> String:
	if _motor == null:
		return ""
	var contas := _motor.contas_do_andar(andar)
	var principal := ""
	for chave: String in _motor.mistura().get("substancias", {}):
		if int(contas.get(chave, 0)) > int(contas.get(principal, 0)):
			principal = chave
	return principal


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
		@warning_ignore("integer_division")
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
		@warning_ignore("integer_division")
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


# ─────────────────────────────────────────────────────────────
# A ANIMAÇÃO
# ─────────────────────────────────────────────────────────────

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
	# A coluna de verdade anda desde que o ar todo entrou, sempre em passos de
	# PASSO_DO_MOTOR: assim a conta dá o mesmo resultado em qualquer ritmo de
	# fala (a pressa só faz os passos virem mais depressa).
	if _motor != null and _etapa >= Etapa.AR_LIQUIDO and not _fechando and _todas_entraram():
		_tempo_do_motor += delta
		while _tempo_do_motor >= PASSO_DO_MOTOR:
			_tempo_do_motor -= PASSO_DO_MOTOR
			_motor.avancar(PASSO_DO_MOTOR)

	# A régua e a plaquinha do fundo desde que o ar entra; a do topo quando o
	# resfriador liga; as do meio quando alguma substância manda no líquido de lá.
	var a_regua := 1.0 if _etapa >= Etapa.AR_LIQUIDO and not _fechando else 0.0
	_regua = move_toward(_regua, a_regua, delta / 0.3)
	var topo := _etiquetas.size() - 1
	for andar in _etiquetas.size():
		var a_vista := _etapa >= Etapa.AR_LIQUIDO if andar == 0 \
			else _etapa >= Etapa.FERVER if andar == topo \
			else dono_do_andar(andar) != ""
		_etiquetas[andar] = move_toward(_etiquetas[andar], 1.0 if a_vista else 0.0, delta / 0.25)
	for andar in _pulsos.size():
		_pulsos[andar] = move_toward(_pulsos[andar], 0.0, delta / 0.5)
	var pureza := 1.0 if _mostrar_pureza and not _fechando else 0.0
	_pureza_a_vista = move_toward(_pureza_a_vista, pureza, delta / 0.3)
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
			return _todas_entraram() and _relogio_da_etapa >= _ultima_entrada() + 0.16
		Etapa.EVAPORAR:
			return _relogio_da_etapa >= DURACAO_MINIMA_DE_EVAPORAR
		Etapa.FERVER:
			# O fundo chegou onde o calor desta etapa o leva e a coluna assentou.
			return _motor != null and _motor.parada()
	return false


func _entrar(nova: Etapa) -> void:
	_etapa = nova
	_relogio_da_etapa = 0.0
	if _motor == null:
		return
	match nova:
		Etapa.EVAPORAR:
			_motor.ritmo_dos_pulos = RITMO_DOS_PULOS_AO_EVAPORAR
		Etapa.FERVER:
			_motor.ritmo_dos_pulos = 1.0
			_motor.pedir_temperatura(TEMPERATURA_AO_FERVER)
		Etapa.SEPARAR:
			_motor.ritmo_dos_pulos = 1.0
			_motor.pedir_temperatura(TEMPERATURA_DO_FUNDO)


func _todas_entraram() -> bool:
	return _etapa > Etapa.AR_LIQUIDO or _relogio_da_etapa >= _ultima_entrada()


func _ultima_entrada() -> float:
	var ultima := 0.0
	for t in _entrada:
		ultima = maxf(ultima, t)
	return ultima


## 0..1: quanto a molécula número "i" já apareceu (o estalo de quando ela cai
## no fundo, na etapa AR_LIQUIDO).
func _tamanho_na_entrada(i: int) -> float:
	if _etapa > Etapa.AR_LIQUIDO:
		return 1.0
	if _etapa < Etapa.AR_LIQUIDO or i >= _entrada.size():
		return 0.0
	return clampf((_relogio_da_etapa - _entrada[i]) / 0.16, 0.0, 1.0)


func _passo_de_fechar(delta: float) -> void:
	_pedida = Etapa.FECHADA
	if _conteudo > 0.0 and _etapa > Etapa.RAIO_X:
		_conteudo = maxf(_conteudo - delta / 0.22, 0.0)
		return
	_etapa = Etapa.FECHADA
	_raio_x = maxf(_raio_x - delta / DURACAO_DE_FECHAR, 0.0)


func _ao_ferver(substancia: String) -> void:
	if _ja_ferveu.has(substancia):
		return
	_ja_ferveu[substancia] = true
	_pulsos[0] = 1.0
	ferveu.emit(substancia)


func _ao_condensar(substancia: String, andar: int) -> void:
	if andar <= 0 or _ja_assentou.has(substancia):
		return
	_ja_assentou[substancia] = true
	_pulsos[andar] = 1.0
	assentou.emit(substancia)


# ─────────────────────────────────────────────────────────────
# A GEADA
# ─────────────────────────────────────────────────────────────

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
		if _conteudo > 0.0 and _motor != null and _etapa >= Etapa.AR_LIQUIDO:
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
		_desenhar_purezas()
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


## O líquido de cada andar, na cor das substâncias dele misturadas na
## proporção de cada uma (um líquido rico em nitrogênio é quase verde).
func _desenhar_liquidos() -> void:
	for andar in numero_de_andares():
		var caixa := _motor.caixa_do_liquido(andar)
		if not caixa.has_area():
			continue
		_desenhar_liquido(caixa, _motor.cor_do_liquido(andar, "liquido"), _motor.cor_do_liquido(andar, "tona"),
			_alfa_da_entrada() if andar == 0 else 1.0)


## O líquido do fundo vai aparecendo enquanto o ar entra.
func _alfa_da_entrada() -> float:
	if _etapa > Etapa.AR_LIQUIDO:
		return 1.0
	var total := maxf(_ultima_entrada(), 0.01)
	return clampf(_relogio_da_etapa / total, 0.0, 1.0)


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


## Bolhas: aneizinhos de 8 px subindo pelo líquido do fundo (só fervendo).
func _desenhar_bolhas() -> void:
	var cor := Color(COR_DA_BOLHA, 0.85 * _conteudo)
	for bolha in _motor.bolhas():
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
	var fumaca := _motor.fumaca()
	if fumaca.is_empty() or _nevoa.is_empty():
		return
	var largura := _recorte_raio_x.size.x
	var altura := _recorte_raio_x.size.y
	_nevoa.fill(0.0)
	var topo := altura
	var base := -1
	for f in fumaca:
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
	for r in _motor.respingos():
		var pos: Vector2 = r["pos"]
		draw_rect(Rect2((pos / 2.0).floor() * 2.0, Vector2(4, 4)), _com_conteudo(r["cor"]))


func _com_conteudo(cor: Color) -> Color:
	return Color(cor, cor.a * _conteudo)


## As moléculas, com a arte da história: deitadas no líquido, girando como gás
## (subindo, soltas, ou no meio do vai-e-volta da superfície).
func _desenhar_moleculas() -> void:
	if _moleculas_tex == null:
		return
	var lado := CELULA_DA_MOLECULA * ESCALA_MOLECULA
	var particulas := _motor.particulas()
	for i in particulas.size():
		var p: ColunaDoSimulador.Particula = particulas[i]
		if not SUBSTANCIAS.has(p.tipo):
			continue
		var tamanho := _tamanho_na_entrada(i)
		if tamanho <= 0.0:
			continue
		var quadro := 0
		if _motor.girando(p):
			quadro = int(p.relogio * p.giro) % QUADROS_DA_MOLECULA
		var onde := _motor.onde_desenhar(p)
		# Entrando: cai um pouco de cima e dá o estalo (passa do tamanho e volta).
		onde.y -= (1.0 - tamanho) * 26.0
		var estalo := 1.0 + 0.35 * sin(tamanho * PI) if tamanho < 1.0 else 1.0
		var medida := Vector2(lado, lado) * tamanho * estalo
		draw_texture_rect_region(_moleculas_tex,
			Rect2((onde - medida * 0.5).round(), medida.round()),
			Rect2(quadro * CELULA_DA_MOLECULA, int(SUBSTANCIAS[p.tipo]["linha"]) * CELULA_DA_MOLECULA,
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
## a de cada andar em que uma substância manda no líquido — essa na cor dela e
## com o desenho da molécula (e dá um pulo quando algo acontece ali).
func _desenhar_plaquinhas() -> void:
	var topo := _etiquetas.size() - 1
	for andar in _etiquetas.size():
		var alfa := _etiquetas[andar] * _conteudo
		if alfa <= 0.004:
			continue
		var dono := dono_do_andar(andar) if _etapa >= Etapa.FERVER else ""
		var papel: Color = SUBSTANCIAS[dono]["tona"] if SUBSTANCIAS.has(dono) else EstiloHUD.PAPEL
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


## As etiquetas de pureza (mostrar_pureza): em cima do líquido do topo e do
## fundo, quanto dele é da substância que manda ali. Nenhuma diz 100%: é o
## que a explicação quer mostrar.
func _desenhar_purezas() -> void:
	var alfa := _pureza_a_vista * _conteudo
	if alfa <= 0.004 or _motor == null:
		return
	for andar: int in [numero_de_andares() - 1, 0]:
		var texto := texto_da_pureza(andar)
		var caixa_do_liquido := _motor.caixa_do_liquido(andar)
		if texto == "" or not caixa_do_liquido.has_area():
			continue
		var dono := principal_do_andar(andar)
		var largura := FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, LETRA_DA_PUREZA).x + 16.0
		var meio := Vector2(_largura() * 0.5, caixa_do_liquido.position.y - 30.0)
		var caixa := Rect2(roundf(meio.x - largura * 0.5), roundf(meio.y - 13.0), largura, 26.0)
		var papel: Color = SUBSTANCIAS[dono]["tona"] if SUBSTANCIAS.has(dono) else EstiloHUD.PAPEL
		EstiloHUD.ficha(self, caixa.grow(roundf(sin(_pureza_a_vista * PI) * 3.0)), alfa, papel, EstiloHUD.TINTA,
			2.0, 2.0)
		draw_string(FONTE, Vector2(caixa.position.x + 8.0, caixa.position.y + 5.0
			+ roundf(FONTE.get_ascent(LETRA_DA_PUREZA) * 0.9)), texto, HORIZONTAL_ALIGNMENT_LEFT, -1,
			LETRA_DA_PUREZA, EstiloHUD.com_alfa(EstiloHUD.TINTA, alfa))


## A PLAQUINHA DE TEMPERATURA: uma ficha pequena (papel, moldura de tinta e a
## sombra dura embaixo, como as do HUD), presa pelo meio do lado direito. A
## ficha de cada substância usa a mesma para o ponto de ebulição: é por serem
## iguais que se vê que o número do andar e o da substância são do mesmo tipo.
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
