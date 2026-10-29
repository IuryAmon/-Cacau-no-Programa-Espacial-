class_name GasFechado
extends RefCounted

# --- O AR PRESO NUM RECIPIENTE (a física do compressor) ---
#
# Uma porção de AR SECO (N₂, O₂ e Ar) dentro de um recipiente de volume
# conhecido. É o que o compressor da fase do nitrogênio aperta e resfria, e o
# que o cilindro leva gelado até o destilador. Nada aqui é encenado: a tela só
# desenha o que estas contas dizem.
#
# O QUE O MODELO SABE
#
#   GÁS IDEAL       P · V = n · R · T. É a conta que manda enquanto tudo é gás.
#   ENERGIA         o estado é guardado pela ENERGIA INTERNA (U), e não pela
#                   temperatura. Por isso as três coisas que mexem no gás saem
#                   sozinhas da mesma conta:
#                     * empurrar o êmbolo faz TRABALHO sobre o gás (−P·ΔV): ele
#                       esquenta (compressão adiabática, a bomba de bicicleta
#                       que fica quente); puxar o êmbolo esfria;
#                     * o resfriador e o ar da sala trocam CALOR com ele;
#                     * virar líquido SOLTA calor (o calor de vaporização), e
#                       ferver ROUBA calor.
#   CONDENSAÇÃO     abaixo da temperatura crítica do ar (−140,6 °C), se a
#                   pressão do gás passar do PONTO DE ORVALHO, o que sobra vira
#                   líquido e fica no fundo. A pressão de vapor de cada gás vem
#                   da equação de Antoine com os números do NIST; a do ar é a
#                   da mistura (lei de Raoult):
#                     orvalho  1/P = Σ yᵢ/Pᵢ   (a primeira gota)
#                     bolha    P = Σ xᵢ·Pᵢ     (a última bolha)
#                   Entre as duas a pressão sobe junto com a fração de líquido
#                   (em linha reta: é a simplificação do modelo). É por isso que
#                   o ar líquido aguenta tanta molécula num cilindro: o líquido
#                   ocupa ~700 vezes menos que o gás a 1 atm.
#
# O QUE O MODELO NÃO FAZ (de propósito)
#   * o gás é ideal até virar líquido (sem Van der Waals): nas pressões do
#     jogo (até 5 atm) o erro é de poucos por cento;
#   * o ar é tratado como uma substância só na hora de condensar (a pressão
#     entre o orvalho e a bolha é uma reta). Quem quiser a COMPOSIÇÃO da
#     primeira gota (o oxigênio condensa primeiro) pergunta a
#     "composicao_da_primeira_gota()";
#   * nada congela: o resfriador não desce abaixo de −200 °C, bem acima do
#     ponto de fusão do nitrogênio (−210 °C).
#
# SÓ GÁS: com "pode_condensar" desligado (o simulador de gases do
# Laboratório, MaquinaDoSimulador), nada vira líquido e P · V = n · R · T vale
# em qualquer temperatura.
#
# UNIDADES: pressão em atm, volume em L, temperatura em K, quantidade em mol,
# energia em J. Para mostrar em °C, "celsius()".

## Constante dos gases, em L·atm/(mol·K).
const R := 0.0820574
## Constante dos gases, em J/(mol·K).
const R_JOULE := 8.314463
## 1 L·atm em joules (é a unidade do trabalho −P·ΔV).
const JOULES_POR_ATM_LITRO := 101.325
## Capacidade calorífica a volume constante do gás: o ar é quase todo
## diatômico, Cv = 5/2 R (e é daí que sai o γ = 1,4 da compressão adiabática).
const CV_GAS := 2.5 * R_JOULE
## Capacidade calorífica do ar líquido (o N₂ líquido tem ~56 J/(mol·K)).
const C_LIQUIDO := 56.0
## Calor de vaporização do ar: média dos dois gases principais, pesada pela
## composição (N₂ 5,57 kJ/mol e O₂ 6,82 kJ/mol).
const CALOR_DE_VAPORIZACAO := 5830.0
## Volume de 1 mol de ar líquido: 28,96 g/mol ÷ 0,875 g/mL.
const VOLUME_MOLAR_DO_LIQUIDO := 0.0331
## Temperatura crítica do ar (−140,6 °C). Acima dela nenhum aperto faz líquido.
const TEMPERATURA_CRITICA := 132.5
## A temperatura mais baixa que o modelo considera (o N₂ congela a 63 K).
const TEMPERATURA_MINIMA := 60.0
const ZERO_CELSIUS := 273.15
const BAR_EM_ATM := 1.0 / 1.01325

## Fração molar de cada gás no ar seco: 78,08% de N₂, 20,95% de O₂ e 0,93% de
## argônio, divididos pela soma dos três (99,96%) — o CO₂ e os gases nobres
## menores, 0,04% juntos, ficam de fora.
const COMPOSICAO := {"N2": 0.78108, "O2": 0.20958, "Ar": 0.00934}

## Equação de Antoine do NIST Chemistry WebBook: log₁₀(P/bar) = A − B/(T + C).
## Faixas medidas: N₂ 63–126 K, O₂ 54–154 K, Ar 84–151 K.
const ANTOINE := {
	"N2": [3.7362, 264.651, -6.788],
	"O2": [3.9523, 340.024, -4.144],
	"Ar": [3.29555, 215.24, -22.233],
}

## Quantidade de ar, em mol.
var mols: float = 1.0
## Volume do recipiente, em L.
var volume: float = 24.47
## Temperatura do gás (e do líquido, que estão juntos), em K.
var temperatura: float = 298.15
## Quanto do ar está líquido: de 0 (só gás) a 1.
var fracao_liquida: float = 0.0
## Energia interna, em J. É ela que guarda o estado: a temperatura e a fração
## de líquido saem dela (ver _equilibrar).
var energia: float = 0.0
## O ar pode virar líquido? Desligado, ele é um gás ideal em qualquer
## temperatura (o simulador do Laboratório).
var pode_condensar: bool = true


func _init(quantos_mols: float = 1.0, litros: float = 24.47, kelvin: float = 298.15) -> void:
	mols = quantos_mols
	volume = litros
	definir_temperatura(kelvin)


## Põe o ar em equilíbrio a esta temperatura, no volume de agora: se nela o ar
## já pinga, a fração de líquido certa vem junto.
func definir_temperatura(kelvin: float) -> void:
	temperatura = kelvin
	fracao_liquida = _fracao_de_equilibrio(kelvin)
	energia = _energia_em(kelvin, fracao_liquida)


## Uma cópia independente (para prever o futuro sem mexer no presente).
func copiar() -> GasFechado:
	var outro := GasFechado.new(mols, volume, temperatura)
	outro.fracao_liquida = fracao_liquida
	outro.energia = energia
	outro.pode_condensar = pode_condensar
	return outro


# ─────────────────────────────────────────────────────────────
# O ESTADO
# ─────────────────────────────────────────────────────────────

## Pressão, em atm.
func pressao() -> float:
	if fracao_liquida > 0.0:
		return _pressao_em_duas_fases(temperatura, fracao_liquida)
	return mols * R * temperatura / maxf(volume, 0.0001)


func mols_de_gas() -> float:
	return mols * (1.0 - fracao_liquida)


func mols_de_liquido() -> float:
	return mols * fracao_liquida


## O volume que sobra para o gás (o líquido ocupa um tiquinho do fundo).
func volume_do_gas() -> float:
	return maxf(volume - mols_de_liquido() * VOLUME_MOLAR_DO_LIQUIDO, 0.0001)


func celsius() -> float:
	return temperatura - ZERO_CELSIUS


## A temperatura em que, NESTA pressão, o ar começa a virar líquido (o ponto
## de orvalho). Acima da pressão crítica, devolve a temperatura crítica.
func temperatura_de_condensacao() -> float:
	return temperatura_de_orvalho(pressao())


# ─────────────────────────────────────────────────────────────
# O QUE MEXE NO GÁS
# ─────────────────────────────────────────────────────────────

## O êmbolo andou e o recipiente agora tem "litros". O gás troca energia com o
## êmbolo (o trabalho −P·ΔV): espremido ele esquenta; expandido, esfria. A
## pressão usada é a média do começo e do fim do passo (regra do trapézio),
## para a compressão adiabática não depender do tamanho do passo.
func mudar_volume(litros: float) -> void:
	litros = maxf(litros, mols_de_liquido() * VOLUME_MOLAR_DO_LIQUIDO + 0.0001)
	var dv := litros - volume
	if is_zero_approx(dv):
		return
	var antes := pressao()
	energia -= antes * dv * JOULES_POR_ATM_LITRO
	volume = litros
	_equilibrar()
	var depois := pressao()
	energia -= (depois - antes) * 0.5 * dv * JOULES_POR_ATM_LITRO
	_equilibrar()


## Entra ar (ou sai), na temperatura em que o gás está: cada mol que entra
## traz a energia de um mol do gás de agora, e cada um que sai leva a dele.
## A temperatura não muda; a pressão, sim (P = n·R·T/V).
func mudar_quantidade(novos_mols: float) -> void:
	novos_mols = maxf(novos_mols, 0.0)
	if is_equal_approx(novos_mols, mols):
		return
	mols = novos_mols
	energia = _energia_em(temperatura, fracao_liquida)
	_equilibrar()


## Entra (positivo) ou sai (negativo) calor, em J.
func trocar_calor(joules: float) -> void:
	if is_zero_approx(joules):
		return
	energia += joules
	_equilibrar()


## Troca calor com um corpo a "kelvin" por "segundos", com a condutância
## "watts_por_kelvin" (lei do resfriamento de Newton). O passo é dividido
## sozinho para nunca passar do ponto: o gás chega na temperatura do corpo, mas
## não atravessa ela.
func trocar_calor_com(kelvin: float, watts_por_kelvin: float, segundos: float) -> void:
	if watts_por_kelvin <= 0.0 or segundos <= 0.0:
		return
	if mols <= 0.0:
		# Vazio, não há ar para esquentar: a temperatura de dentro é a do corpo.
		temperatura = kelvin
		return
	var restante := segundos
	while restante > 0.0:
		# O passo seguro é uma fração da constante de tempo de agora (o gás
		# sozinho tem pouca capacidade térmica; com líquido, muita).
		var capacidade := _capacidade_termica()
		var passo := minf(restante, 0.25 * capacidade / watts_por_kelvin)
		passo = maxf(passo, 0.0005)
		trocar_calor(watts_por_kelvin * (kelvin - temperatura) * passo)
		restante -= passo


# ─────────────────────────────────────────────────────────────
# A CONTA DO EQUILÍBRIO
# ─────────────────────────────────────────────────────────────

## Energia interna de "mols" de ar a T com a fração f de líquido. O zero é o
## gás a 0 K; o líquido fica L abaixo do gás na mesma temperatura.
func _energia_em(kelvin: float, f: float) -> float:
	return mols * ((1.0 - f) * CV_GAS * kelvin + f * (C_LIQUIDO * kelvin - CALOR_DE_VAPORIZACAO))


## A partir da energia, acha a temperatura e quanto é líquido.
##   1. supõe que é tudo gás: T = U / (n·Cv). Se, nessa T, a pressão do gás não
##      passa do ponto de orvalho (ou se T está acima da crítica), é isso;
##   2. senão há líquido. Virar líquido SOLTA calor, então o equilíbrio fica
##      MAIS QUENTE que essa T: procura (por bisseção, entre ela e a crítica)
##      a T em que a energia bate com a fração de líquido que o equilíbrio
##      pede nessa T. A energia de equilíbrio só cresce com a T (mais quente,
##      menos líquido e mais agitação), então a bisseção sempre acha.
func _equilibrar() -> void:
	if mols <= 0.0:
		# Sem ar, nada a equilibrar: a temperatura fica a de antes.
		fracao_liquida = 0.0
		energia = 0.0
		return
	var t_gas := energia / (mols * CV_GAS)
	if not pode_condensar:
		temperatura = maxf(t_gas, 1.0)
		fracao_liquida = 0.0
		return
	# Com muito líquido a energia fica pequena (ou negativa) e o "tudo gás"
	# daria uma temperatura absurda, abaixo de onde as contas de vapor valem:
	# a pergunta "já pinga?" é feita no mínimo do modelo.
	var t_teste := maxf(t_gas, TEMPERATURA_MINIMA)
	if t_teste >= TEMPERATURA_CRITICA or _fracao_de_equilibrio(t_teste) <= 0.0:
		temperatura = t_teste
		fracao_liquida = 0.0
		return
	var baixo := t_teste
	var alto := TEMPERATURA_CRITICA
	for i in 48:
		var meio := (baixo + alto) * 0.5
		if _energia_em(meio, _fracao_de_equilibrio(meio)) > energia:
			alto = meio
		else:
			baixo = meio
	temperatura = (baixo + alto) * 0.5
	fracao_liquida = _fracao_de_equilibrio(temperatura)


## Quanto do ar estaria líquido em equilíbrio a esta temperatura, neste volume.
## Junta duas coisas: o gás que sobra é ideal, n(1−f)RT/(V − f·n·v), e a pressão
## dele é a da mistura em duas fases, P_orv + (P_bol − P_orv)·f. Igualando, sai
## uma equação do 2º grau em f.
func _fracao_de_equilibrio(kelvin: float) -> float:
	if not pode_condensar or kelvin >= TEMPERATURA_CRITICA or mols <= 0.0:
		return 0.0
	var a := mols * R * kelvin
	var p_orv := pressao_de_orvalho(kelvin)
	var p_bol := pressao_de_bolha(kelvin)
	var d := p_bol - p_orv
	var c2 := a - p_orv * volume
	if c2 <= 0.0:
		return 0.0
	var v := VOLUME_MOLAR_DO_LIQUIDO
	var a2 := d * mols * v
	var b2 := -a - d * volume + p_orv * mols * v
	var f: float
	if absf(a2) < 1e-12:
		f = c2 / -b2
	else:
		# Forma estável da raiz menor: 2c / (−b + √(b² − 4ac)).
		var discriminante := maxf(b2 * b2 - 4.0 * a2 * c2, 0.0)
		f = 2.0 * c2 / (-b2 + sqrt(discriminante))
	return clampf(f, 0.0, 0.999)


func _pressao_em_duas_fases(kelvin: float, f: float) -> float:
	var p_orv := pressao_de_orvalho(kelvin)
	return p_orv + (pressao_de_bolha(kelvin) - p_orv) * f


## Quanto de energia o gás precisa para subir 1 K agora (com líquido, conta o
## que ferve no caminho). Medida pela própria conta, de 0,5 K para cada lado.
func _capacidade_termica() -> float:
	if fracao_liquida <= 0.0:
		return mols * CV_GAS
	var f_baixo := _fracao_de_equilibrio(temperatura - 0.5)
	var f_alto := _fracao_de_equilibrio(temperatura + 0.5)
	return maxf(_energia_em(temperatura + 0.5, f_alto) - _energia_em(temperatura - 0.5, f_baixo), mols * CV_GAS)


# ─────────────────────────────────────────────────────────────
# PRESSÕES DE VAPOR (static: valem para qualquer porção de ar)
# ─────────────────────────────────────────────────────────────

## Pressão de vapor de um gás puro (N2, O2 ou Ar) a T, em atm. Abaixo do
## mínimo do modelo vale a do mínimo (a equação de Antoine explode perto de
## T = −C).
static func pressao_de_vapor(gas: String, kelvin: float) -> float:
	var c: Array = ANTOINE[gas]
	var t := maxf(kelvin, TEMPERATURA_MINIMA)
	return pow(10.0, float(c[0]) - float(c[1]) / (t + float(c[2]))) * BAR_EM_ATM


## A pressão em que a primeira gota de ar aparece, a T (lei de Raoult).
static func pressao_de_orvalho(kelvin: float) -> float:
	var soma := 0.0
	for gas: String in COMPOSICAO:
		soma += float(COMPOSICAO[gas]) / pressao_de_vapor(gas, kelvin)
	return 1.0 / soma


## A pressão em que o ar líquido solta a primeira bolha, a T (lei de Raoult).
static func pressao_de_bolha(kelvin: float) -> float:
	var soma := 0.0
	for gas: String in COMPOSICAO:
		soma += float(COMPOSICAO[gas]) * pressao_de_vapor(gas, kelvin)
	return soma


## A temperatura do ponto de orvalho nesta pressão (atm): a mais quente em que
## o ar, apertado assim, já começa a pingar. Acima da crítica não há.
static func temperatura_de_orvalho(atm: float) -> float:
	if atm >= pressao_de_orvalho(TEMPERATURA_CRITICA):
		return TEMPERATURA_CRITICA
	var baixo := TEMPERATURA_MINIMA
	var alto := TEMPERATURA_CRITICA
	for i in 40:
		var meio := (baixo + alto) * 0.5
		if pressao_de_orvalho(meio) > atm:
			alto = meio
		else:
			baixo = meio
	return (baixo + alto) * 0.5


## A temperatura em que o ar LÍQUIDO ferve nesta pressão (o ponto de bolha).
static func temperatura_de_ebulicao(atm: float) -> float:
	var baixo := TEMPERATURA_MINIMA
	var alto := TEMPERATURA_CRITICA
	for i in 40:
		var meio := (baixo + alto) * 0.5
		if pressao_de_bolha(meio) > atm:
			alto = meio
		else:
			baixo = meio
	return (baixo + alto) * 0.5


## De que é feita a primeira gota, a T: o gás que ferve mais quente (o O₂)
## condensa antes, então a gota sai mais rica nele do que o ar.
## Devolve {"N2": fração, "O2": fração, "Ar": fração}.
static func composicao_da_primeira_gota(kelvin: float) -> Dictionary:
	var p := pressao_de_orvalho(kelvin)
	var gota := {}
	for gas: String in COMPOSICAO:
		gota[gas] = float(COMPOSICAO[gas]) * p / pressao_de_vapor(gas, kelvin)
	return gota


static func kelvin(graus_celsius: float) -> float:
	return graus_celsius + ZERO_CELSIUS


static func para_celsius(graus_kelvin: float) -> float:
	return graus_kelvin - ZERO_CELSIUS
