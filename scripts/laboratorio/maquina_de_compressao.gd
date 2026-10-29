class_name MaquinaDeCompressao
extends RefCounted

# --- O COMPRESSOR DE AR (a máquina, sem o desenho) ---
#
# A máquina da sala do compressor, na fase do nitrogênio. Ela é só números:
# quem desenha é a CamaraDeCompressao (scripts/ui/camara_de_compressao.gd) e
# quem joga é a tela do puzzle (scripts/puzzle_compressor.gd). O simulador de
# gases do Laboratório usa a mesma máquina, com o que ele muda nela, em
# MaquinaDoSimulador (scripts/laboratorio/maquina_do_simulador.gd).
#
#   CÂMARA      a caixa grande, cheia de ar da sala (1 atm, 25 °C). O ÊMBOLO
#               desce dentro dela e diminui o volume.
#   CILINDRO    o cilindro de amostra, acoplado embaixo da câmara pela
#               válvula. Com ela aberta, câmara e cilindro são um volume só: o
#               gás se espalha pelos dois, e o êmbolo, descendo, empurra o ar
#               para dentro do cilindro. Com o êmbolo no fim, todo o ar está
#               nele.
#   RESFRIADOR  a serpentina que passa pelas paredes da câmara e abraça o
#               cilindro. A pessoa escolhe a temperatura dela; o gás troca
#               calor com ela (e, um pouco, com a sala).
#   MANÔMETRO   no gargalo do cilindro. O cilindro aguenta até a PRESSÃO DE
#               TRABALHO com folga; passou dela, range; passou da PRESSÃO DE
#               RUPTURA, estoura.
#
# A FÍSICA é toda do GasFechado (scripts/laboratorio/gas_fechado.gd): o
# trabalho do êmbolo esquenta o gás, o resfriador tira calor, e abaixo do ponto
# de orvalho o ar vira líquido e escorre para o fundo do cilindro.
#
# OS NÚMEROS (ver as constantes):
#   1 mol de ar a 25 °C e 1 atm ocupa 24,47 L: é a câmara inteira com o
#   cilindro. O cilindro tem 3 L, um oitavo disso. Empurrar todo o ar para ele
#   SEM resfriar daria 8 atm (e bem mais, com o calor da compressão): o
#   cilindro estoura em 4. É preciso resfriar — e, abaixo de uns −183 °C, o ar
#   apertado no cilindro começa a virar líquido, e a pressão para de subir.
#
# A AMOSTRA PRONTA é o ar todo no cilindro e já pingando (ar líquido): é o
# que a coluna de destilação recebe. Fechada a válvula, ela começa a esquentar
# (o calor da sala vaza para dentro) e a pressão volta a subir: quanto mais
# fria e mais líquida ela sair daqui, mais tempo ela aguenta até a coluna.

## A pressão passou da ruptura: o cilindro estourou.
signal estourou(pressao: float)
## O primeiro líquido apareceu (a primeira gota desta vez).
signal comecou_a_condensar

## 1 mol de ar a 25 °C e 1 atm: o volume da câmara cheia mais o do cilindro.
const MOLS := 1.0
const TEMPERATURA_DA_SALA := 298.15
const VOLUME_TOTAL := MOLS * GasFechado.R * TEMPERATURA_DA_SALA / 1.0
## O cilindro de amostra.
const VOLUME_DO_CILINDRO := 3.0
const VOLUME_DA_CAMARA := VOLUME_TOTAL - VOLUME_DO_CILINDRO

## Até aqui o cilindro trabalha tranquilo (o verde do manômetro).
const PRESSAO_DE_TRABALHO := 3.0
## Daqui ele estoura (o fim do amarelo).
const PRESSAO_DE_RUPTURA := 4.0
## Quanto tempo acima da ruptura até estourar: um respiro para um pico de um
## quadro não estourar o cilindro, curto demais para dar tempo de salvá-lo.
const TEMPO_DE_RUPTURA := 0.12

## O êmbolo vai do alto ao fim em 3 s, no mais rápido.
const VELOCIDADE_DO_EMBOLO := 1.0 / 3.0
## A serpentina do resfriador: de −200 °C a 150 °C (também aquece, para dar
## para brincar), e a pressa com que ela segue o que foi pedido.
const RESFRIADOR_MINIMO := 73.15
const RESFRIADOR_MAXIMO := 423.15
const VELOCIDADE_DA_SERPENTINA := 140.0
## Condutância térmica (W/K): do gás com a serpentina e com a sala. Com a
## serpentina, o gás sozinho (20,8 J/K) chega perto dela em ~1 s; virando
## líquido, demora mais — tem o calor de vaporização para tirar.
const TROCA_COM_O_RESFRIADOR := 25.0
const TROCA_COM_A_SALA := 0.6
## O cilindro fechado e solto, longe do resfriador: o calor da sala entra por
## esta condutância (W/K). É ela que dá o tempo até a coluna.
const VAZAMENTO_DO_CILINDRO := 0.35

## A amostra está pronta quando todo o ar está no cilindro e pelo menos esta
## parte dele já é líquida.
const FRACAO_LIQUIDA_DA_AMOSTRA := 0.2
## O êmbolo conta como "no fim" daqui para baixo.
const FIM_DO_CURSO := 0.999

## Passos de física por chamada de avancar() (o êmbolo e a troca de calor em
## pedaços pequenos).
const SUBPASSOS := 4

var gas: GasFechado
## Onde o êmbolo está: 0 = no alto (câmara cheia), 1 = no fim (câmara vazia).
var posicao: float = 0.0
## Para onde a pessoa mandou o êmbolo.
var alvo: float = 0.0
## A temperatura que a pessoa pediu para a serpentina, e a que ela tem.
var temperatura_pedida: float = TEMPERATURA_DA_SALA
var temperatura_da_serpentina: float = TEMPERATURA_DA_SALA
var valvula_aberta: bool = true
var estourado: bool = false
## A maior pressão desde o começo (o "recorde" do manômetro).
var pressao_maxima: float = 1.0

var _acima_da_ruptura: float = 0.0
var _ja_condensou: bool = false


func _init() -> void:
	reiniciar()


## Tudo de volta ao começo: câmara cheia de ar da sala, êmbolo no alto,
## serpentina desligada (na temperatura da sala), válvula aberta.
func reiniciar() -> void:
	gas = GasFechado.new(MOLS, VOLUME_TOTAL, TEMPERATURA_DA_SALA)
	posicao = 0.0
	alvo = 0.0
	temperatura_pedida = TEMPERATURA_DA_SALA
	temperatura_da_serpentina = TEMPERATURA_DA_SALA
	valvula_aberta = true
	estourado = false
	pressao_maxima = gas.pressao()
	_acima_da_ruptura = 0.0
	_ja_condensou = false


# ─────────────────────────────────────────────────────────────
# O QUE A PESSOA FAZ
# ─────────────────────────────────────────────────────────────

## Manda o êmbolo para "nova" (0 = alto, 1 = fim). Ele vai até lá na
## velocidade dele, não de uma vez.
func mandar_embolo(nova: float) -> void:
	if not valvula_aberta or estourado:
		return
	alvo = clampf(nova, 0.0, 1.0)


## Pede a temperatura da serpentina, em K (presa entre o mínimo e o máximo).
func pedir_temperatura(kelvin: float) -> void:
	if estourado:
		return
	temperatura_pedida = clampf(kelvin, RESFRIADOR_MINIMO, RESFRIADOR_MAXIMO)


func pedir_celsius(graus: float) -> void:
	pedir_temperatura(GasFechado.kelvin(graus))


## Fecha a válvula e solta o cilindro: devolve a AMOSTRA, o ar que ficou nele
## (um GasFechado só com o volume do cilindro). Só vale com a amostra pronta.
func fechar_valvula() -> GasFechado:
	if not amostra_pronta():
		return null
	valvula_aberta = false
	alvo = posicao
	var amostra := gas.copiar()
	amostra.volume = VOLUME_DO_CILINDRO
	amostra._equilibrar()
	return amostra


# ─────────────────────────────────────────────────────────────
# O TEMPO PASSANDO
# ─────────────────────────────────────────────────────────────

func avancar(delta: float) -> void:
	if estourado or delta <= 0.0:
		return
	var passo := delta / SUBPASSOS
	for i in SUBPASSOS:
		_passo(passo)
		if estourado:
			return


func _passo(dt: float) -> void:
	# A serpentina vai atrás do que foi pedido.
	temperatura_da_serpentina = move_toward(temperatura_da_serpentina, temperatura_pedida,
		VELOCIDADE_DA_SERPENTINA * dt)

	# O êmbolo anda, e o gás sente o trabalho dele.
	if valvula_aberta and not is_equal_approx(posicao, alvo):
		posicao = move_toward(posicao, alvo, VELOCIDADE_DO_EMBOLO * dt)
		gas.mudar_volume(volume())

	gas.trocar_calor_com(temperatura_da_serpentina, TROCA_COM_O_RESFRIADOR, dt)
	gas.trocar_calor_com(TEMPERATURA_DA_SALA, TROCA_COM_A_SALA, dt)

	var p := gas.pressao()
	pressao_maxima = maxf(pressao_maxima, p)
	if gas.fracao_liquida > 0.0 and not _ja_condensou:
		_ja_condensou = true
		comecou_a_condensar.emit()
	_conferir_a_ruptura(p, dt)


## Passou da ruptura por TEMPO_DE_RUPTURA (ou muito acima dela), o cilindro
## estoura.
func _conferir_a_ruptura(p: float, dt: float) -> void:
	if p > PRESSAO_DE_RUPTURA:
		_acima_da_ruptura += dt
		# Muito acima, não há respiro: estoura na hora.
		if _acima_da_ruptura >= TEMPO_DE_RUPTURA or p > PRESSAO_DE_RUPTURA * 1.12:
			estourado = true
			estourou.emit(p)
	else:
		_acima_da_ruptura = 0.0


# ─────────────────────────────────────────────────────────────
# PERGUNTAS
# ─────────────────────────────────────────────────────────────

## O volume que o gás tem agora: o cilindro mais o que sobra da câmara.
func volume() -> float:
	return VOLUME_DO_CILINDRO + VOLUME_DA_CAMARA * (1.0 - posicao)


func volume_da_camara() -> float:
	return VOLUME_DA_CAMARA * (1.0 - posicao)


func pressao() -> float:
	return gas.pressao()


## Que parte do ar está dentro do cilindro (de 0 a 1). O gás se espalha por
## igual (a parte dele que cabe no volume do cilindro); o líquido escorre todo
## para o fundo do cilindro.
func fracao_no_cilindro() -> float:
	var no_gas := (1.0 - gas.fracao_liquida) * minf(VOLUME_DO_CILINDRO / gas.volume_do_gas(), 1.0)
	return clampf(no_gas + gas.fracao_liquida, 0.0, 1.0)


func embolo_no_fim() -> bool:
	return posicao >= FIM_DO_CURSO


## Todo o ar no cilindro e já virando líquido: dá para fechar a válvula.
func amostra_pronta() -> bool:
	return valvula_aberta and not estourado and embolo_no_fim() \
		and gas.fracao_liquida >= FRACAO_LIQUIDA_DA_AMOSTRA \
		and gas.pressao() < PRESSAO_DE_RUPTURA


## Em que faixa do manômetro a pressão está: 0 verde, 1 amarelo, 2 vermelho.
func faixa_da_pressao(p: float = -1.0) -> int:
	if p < 0.0:
		p = gas.pressao()
	if p > PRESSAO_DE_RUPTURA:
		return 2
	if p > PRESSAO_DE_TRABALHO:
		return 1
	return 0


## Se a válvula fosse fechada agora, quanto tempo (s) a amostra aguentaria
## esquentando até estourar. INF se ela nunca chegaria lá (sem ar suficiente
## no cilindro para passar da ruptura nem na temperatura da sala).
func tempo_ate_estourar_se_fechar() -> float:
	var amostra := gas.copiar()
	amostra.volume = VOLUME_DO_CILINDRO
	amostra._equilibrar()
	return MaquinaDeCompressao.tempo_ate_estourar(amostra)


## Quanto tempo (s) esta amostra fechada aguenta, com o calor da sala vazando
## para dentro, até a pressão passar da ruptura. Conta em passos de 0,2 s (é
## a precisão de um cronômetro de jogo) e desiste depois de "limite".
static func tempo_ate_estourar(amostra: GasFechado, limite: float = 300.0) -> float:
	var teste := amostra.copiar()
	var tempo := 0.0
	var passo := 0.2
	if teste.pressao() >= PRESSAO_DE_RUPTURA:
		return 0.0
	# Na temperatura da sala, essa amostra passaria da ruptura? Se não, nunca
	# estoura.
	if teste.mols * GasFechado.R * TEMPERATURA_DA_SALA / teste.volume < PRESSAO_DE_RUPTURA:
		return INF
	while tempo < limite:
		teste.trocar_calor_com(TEMPERATURA_DA_SALA, VAZAMENTO_DO_CILINDRO, passo)
		tempo += passo
		if teste.pressao() >= PRESSAO_DE_RUPTURA:
			return tempo
	return INF


## Avança uma amostra fechada por "segundos" (o calor da sala entrando).
static func esquentar_amostra(amostra: GasFechado, segundos: float) -> void:
	amostra.trocar_calor_com(TEMPERATURA_DA_SALA, VAZAMENTO_DO_CILINDRO, segundos)


## DEBUG: põe a máquina no ponto de fechar a válvula (o ar todo no cilindro,
## a −192 °C, já metade líquido). É o atalho da tecla L do puzzle.
func resolver_na_hora() -> void:
	estourado = false
	valvula_aberta = true
	posicao = 1.0
	alvo = 1.0
	temperatura_pedida = RESFRIADOR_MINIMO
	temperatura_da_serpentina = RESFRIADOR_MINIMO
	gas.volume = volume()
	gas.definir_temperatura(GasFechado.kelvin(-192.0))
	_ja_condensou = true
