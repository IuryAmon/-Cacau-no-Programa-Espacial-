class_name Elementos
extends RefCounted

# --- OS 118 ELEMENTOS (os dados da tabela periódica) ---
#
# Tudo o que o Laboratório sabe de cada elemento sai daqui: a tabela periódica,
# o "Monte seu átomo" e o quiz "Que átomo é esse?". Quem precisa pergunta pelo
# número atômico (Z, de 1 a 118):
#
#   Elementos.simbolo(6)          "C"
#   Elementos.nome(6)             "Carbono"
#   Elementos.massa(6)            "12,011"   o texto da caixa do elemento
#   Elementos.isotopo(6)          12         o número de massa do mais comum
#   Elementos.camadas(6)          [2, 4]     elétrons em cada camada (K, L...)
#   Elementos.familia(6)          Familia.NAO_METAL
#   Elementos.casa(6)             (13, 1)    coluna e linha no desenho da tabela
#
# DE ONDE VÊM OS DADOS (conferidos um a um contra as fontes, não digitados de
# cabeça):
#
#   nomes e massas   a Tabela Periódica dos Elementos da Sociedade Brasileira de
#                    Química (SBQ, versão 5.0, junho de 2025). A massa é o peso
#                    atômico padrão abreviado da IUPAC (2024), com cinco
#                    algarismos. Elemento que não existe estável na natureza
#                    não tem peso padrão: no lugar vai, entre colchetes, o
#                    número de massa do nuclídeo mais estável ([226]).
#                    Os nomes são os da SBQ, inclusive onde ela difere do
#                    costume: crômio (e não cromo), kriptônio, neptúnio,
#                    berkélio, tennesso e oganessônio.
#                    A única diferença: o hidrogênio vai como 1,008 (na SBQ,
#                    1,0080), que é como está na caixa desenhada do caderno.
#   isótopos         NIST, "Atomic Weights and Isotopic Compositions": de cada
#                    100 átomos do elemento na natureza, quantos são de cada
#                    isótopo. O "isótopo" de um elemento é o mais abundante
#                    deles; para os que não existem na natureza, o do colchete.
#   camadas          a distribuição dos elétrons do átomo neutro: a ordem de
#                    preenchimento dos subníveis (o diagrama de Linus Pauling)
#                    com as 20 exceções conhecidas (crômio, cobre, ouro...).
#                    Confere com a distribuição por camadas publicada para
#                    todos os 118 (o teste traz a lista inteira).
#   famílias         a classificação usada nas escolas (a mesma do PubChem):
#                    os semimetais são B, Si, Ge, As, Sb, Te e Po.
#
# ÍONS. O "Monte seu átomo" deixa pôr mais ou menos elétrons que prótons.
# "camadas_com" diz em que camadas eles ficam:
#   * a menos (cátion): saem primeiro os elétrons de valência, do subnível de
#     camada mais alta para o de mais baixa. É por isso que o Fe²⁺ fica 2-8-14
#     (perde os dois da camada N, não os da M) e o Cu⁺ fica 2-8-18.
#   * a mais (ânion): ficam como no átomo neutro que tem esse tanto de
#     elétrons (o Cl⁻, com 18, fica 2-8-8, igual ao argônio).
#
# ONDE MEXER: para trocar um nome ou uma massa, é só a linha do elemento em
# DADOS. O resto (grupo, período, família, camadas) é calculado.

const TOTAL := 118

enum Familia {
	NAO_METAL, GAS_NOBRE, METAL_ALCALINO, METAL_ALCALINOTERROSO, SEMIMETAL,
	HALOGENIO, OUTRO_METAL, METAL_DE_TRANSICAO, LANTANIDIO, ACTINIDIO,
}

## O nome de cada família: um elemento ("gás nobre") e o conjunto ("gases
## nobres"), na ordem em que a legenda da tabela os mostra.
const FAMILIAS := {
	Familia.METAL_ALCALINO: ["metal alcalino", "metais alcalinos"],
	Familia.METAL_ALCALINOTERROSO: ["metal alcalinoterroso", "metais alcalinoterrosos"],
	Familia.METAL_DE_TRANSICAO: ["metal de transição", "metais de transição"],
	Familia.OUTRO_METAL: ["outro metal", "outros metais"],
	Familia.SEMIMETAL: ["semimetal", "semimetais"],
	Familia.NAO_METAL: ["não metal", "não metais"],
	Familia.HALOGENIO: ["halogênio", "halogênios"],
	Familia.GAS_NOBRE: ["gás nobre", "gases nobres"],
	Familia.LANTANIDIO: ["lantanídio", "lantanídios"],
	Familia.ACTINIDIO: ["actinídio", "actinídios"],
}

## As letras das camadas, de dentro para fora.
const LETRAS_DAS_CAMADAS := ["K", "L", "M", "N", "O", "P", "Q"]
## Quantos elétrons cada camada comporta nos átomos que existem.
const CABEM_NAS_CAMADAS := [2, 8, 18, 32, 32, 18, 8]

## Um elemento por linha, na ordem do número atômico:
## [símbolo, nome, massa (como se escreve na caixa), isótopo mais comum].
const DADOS: Array = [
	["H", "Hidrogênio", "1,008", 1],
	["He", "Hélio", "4,0026", 4],
	["Li", "Lítio", "6,94", 7],
	["Be", "Berílio", "9,0122", 9],
	["B", "Boro", "10,81", 11],
	["C", "Carbono", "12,011", 12],
	["N", "Nitrogênio", "14,007", 14],
	["O", "Oxigênio", "15,999", 16],
	["F", "Flúor", "18,998", 19],
	["Ne", "Neônio", "20,180", 20],
	["Na", "Sódio", "22,990", 23],
	["Mg", "Magnésio", "24,305", 24],
	["Al", "Alumínio", "26,982", 27],
	["Si", "Silício", "28,085", 28],
	["P", "Fósforo", "30,974", 31],
	["S", "Enxofre", "32,06", 32],
	["Cl", "Cloro", "35,45", 35],
	["Ar", "Argônio", "39,95", 40],
	["K", "Potássio", "39,098", 39],
	["Ca", "Cálcio", "40,078", 40],
	["Sc", "Escândio", "44,956", 45],
	["Ti", "Titânio", "47,867", 48],
	["V", "Vanádio", "50,942", 51],
	["Cr", "Crômio", "51,996", 52],
	["Mn", "Manganês", "54,938", 55],
	["Fe", "Ferro", "55,845", 56],
	["Co", "Cobalto", "58,933", 59],
	["Ni", "Níquel", "58,693", 58],
	["Cu", "Cobre", "63,546", 63],
	["Zn", "Zinco", "65,38", 64],
	["Ga", "Gálio", "69,723", 69],
	["Ge", "Germânio", "72,630", 74],
	["As", "Arsênio", "74,922", 75],
	["Se", "Selênio", "78,971", 80],
	["Br", "Bromo", "79,904", 79],
	["Kr", "Kriptônio", "83,798", 84],
	["Rb", "Rubídio", "85,468", 85],
	["Sr", "Estrôncio", "87,62", 88],
	["Y", "Ítrio", "88,906", 89],
	["Zr", "Zircônio", "91,222", 90],
	["Nb", "Nióbio", "92,906", 93],
	["Mo", "Molibdênio", "95,95", 98],
	["Tc", "Tecnécio", "[97]", 97],
	["Ru", "Rutênio", "101,07", 102],
	["Rh", "Ródio", "102,91", 103],
	["Pd", "Paládio", "106,42", 106],
	["Ag", "Prata", "107,87", 107],
	["Cd", "Cádmio", "112,41", 114],
	["In", "Índio", "114,82", 115],
	["Sn", "Estanho", "118,71", 120],
	["Sb", "Antimônio", "121,76", 121],
	["Te", "Telúrio", "127,60", 130],
	["I", "Iodo", "126,90", 127],
	["Xe", "Xenônio", "131,29", 132],
	["Cs", "Césio", "132,91", 133],
	["Ba", "Bário", "137,33", 138],
	["La", "Lantânio", "138,91", 139],
	["Ce", "Cério", "140,12", 140],
	["Pr", "Praseodímio", "140,91", 141],
	["Nd", "Neodímio", "144,24", 142],
	["Pm", "Promécio", "[145]", 145],
	["Sm", "Samário", "150,36", 152],
	["Eu", "Európio", "151,96", 153],
	["Gd", "Gadolínio", "157,25", 158],
	["Tb", "Térbio", "158,93", 159],
	["Dy", "Disprósio", "162,50", 164],
	["Ho", "Hólmio", "164,93", 165],
	["Er", "Érbio", "167,26", 166],
	["Tm", "Túlio", "168,93", 169],
	["Yb", "Itérbio", "173,05", 174],
	["Lu", "Lutécio", "174,97", 175],
	["Hf", "Háfnio", "178,49", 180],
	["Ta", "Tântalo", "180,95", 181],
	["W", "Tungstênio", "183,84", 184],
	["Re", "Rênio", "186,21", 187],
	["Os", "Ósmio", "190,23", 192],
	["Ir", "Irídio", "192,22", 193],
	["Pt", "Platina", "195,08", 195],
	["Au", "Ouro", "196,97", 197],
	["Hg", "Mercúrio", "200,59", 202],
	["Tl", "Tálio", "204,38", 205],
	["Pb", "Chumbo", "207,2", 208],
	["Bi", "Bismuto", "208,98", 209],
	["Po", "Polônio", "[209]", 209],
	["At", "Astato", "[210]", 210],
	["Rn", "Radônio", "[222]", 222],
	["Fr", "Frâncio", "[223]", 223],
	["Ra", "Rádio", "[226]", 226],
	["Ac", "Actínio", "[227]", 227],
	["Th", "Tório", "232,04", 232],
	["Pa", "Protactínio", "231,04", 231],
	["U", "Urânio", "238,03", 238],
	["Np", "Neptúnio", "[237]", 237],
	["Pu", "Plutônio", "[244]", 244],
	["Am", "Amerício", "[243]", 243],
	["Cm", "Cúrio", "[247]", 247],
	["Bk", "Berkélio", "[247]", 247],
	["Cf", "Califórnio", "[251]", 251],
	["Es", "Einstênio", "[252]", 252],
	["Fm", "Férmio", "[257]", 257],
	["Md", "Mendelévio", "[258]", 258],
	["No", "Nobélio", "[259]", 259],
	["Lr", "Laurêncio", "[262]", 262],
	["Rf", "Rutherfórdio", "[267]", 267],
	["Db", "Dúbnio", "[268]", 268],
	["Sg", "Seabórgio", "[269]", 269],
	["Bh", "Bóhrio", "[270]", 270],
	["Hs", "Hássio", "[269]", 269],
	["Mt", "Meitnério", "[277]", 277],
	["Ds", "Darmstádtio", "[281]", 281],
	["Rg", "Roentgênio", "[282]", 282],
	["Cn", "Copernício", "[285]", 285],
	["Nh", "Nihônio", "[286]", 286],
	["Fl", "Fleróvio", "[290]", 290],
	["Mc", "Moscóvio", "[290]", 290],
	["Lv", "Livermório", "[293]", 293],
	["Ts", "Tennesso", "[294]", 294],
	["Og", "Oganessônio", "[294]", 294],
]

## De cada 100 átomos do elemento na natureza, quantos são de cada isótopo
## (número atômico -> {número de massa: %}). Elemento que não está aqui não
## tem isótopo estável.
const ISOTOPOS_NATURAIS := {
	1: {1: 99.9885, 2: 0.0115},
	2: {3: 0.000134, 4: 99.9999},
	3: {6: 7.59, 7: 92.41},
	4: {9: 100},
	5: {10: 19.9, 11: 80.1},
	6: {12: 98.93, 13: 1.07},
	7: {14: 99.636, 15: 0.364},
	8: {16: 99.757, 17: 0.038, 18: 0.205},
	9: {19: 100},
	10: {20: 90.48, 21: 0.27, 22: 9.25},
	11: {23: 100},
	12: {24: 78.99, 25: 10, 26: 11.01},
	13: {27: 100},
	14: {28: 92.223, 29: 4.685, 30: 3.092},
	15: {31: 100},
	16: {32: 94.99, 33: 0.75, 34: 4.25, 36: 0.01},
	17: {35: 75.76, 37: 24.24},
	18: {36: 0.3336, 38: 0.0629, 40: 99.6035},
	19: {39: 93.2581, 40: 0.0117, 41: 6.7302},
	20: {40: 96.941, 42: 0.647, 43: 0.135, 44: 2.086, 46: 0.004, 48: 0.187},
	21: {45: 100},
	22: {46: 8.25, 47: 7.44, 48: 73.72, 49: 5.41, 50: 5.18},
	23: {50: 0.25, 51: 99.75},
	24: {50: 4.345, 52: 83.789, 53: 9.501, 54: 2.365},
	25: {55: 100},
	26: {54: 5.845, 56: 91.754, 57: 2.119, 58: 0.282},
	27: {59: 100},
	28: {58: 68.077, 60: 26.223, 61: 1.1399, 62: 3.6346, 64: 0.9255},
	29: {63: 69.15, 65: 30.85},
	30: {64: 49.17, 66: 27.73, 67: 4.04, 68: 18.45, 70: 0.61},
	31: {69: 60.108, 71: 39.892},
	32: {70: 20.57, 72: 27.45, 73: 7.75, 74: 36.5, 76: 7.73},
	33: {75: 100},
	34: {74: 0.89, 76: 9.37, 77: 7.63, 78: 23.77, 80: 49.61, 82: 8.73},
	35: {79: 50.69, 81: 49.31},
	36: {78: 0.355, 80: 2.286, 82: 11.593, 83: 11.5, 84: 56.987, 86: 17.279},
	37: {85: 72.17, 87: 27.83},
	38: {84: 0.56, 86: 9.86, 87: 7, 88: 82.58},
	39: {89: 100},
	40: {90: 51.45, 91: 11.22, 92: 17.15, 94: 17.38, 96: 2.8},
	41: {93: 100},
	42: {92: 14.53, 94: 9.15, 95: 15.84, 96: 16.67, 97: 9.6, 98: 24.39, 100: 9.82},
	44: {96: 5.54, 98: 1.87, 99: 12.76, 100: 12.6, 101: 17.06, 102: 31.55, 104: 18.62},
	45: {103: 100},
	46: {102: 1.02, 104: 11.14, 105: 22.33, 106: 27.33, 108: 26.46, 110: 11.72},
	47: {107: 51.839, 109: 48.161},
	48: {106: 1.25, 108: 0.89, 110: 12.49, 111: 12.8, 112: 24.13, 113: 12.22, 114: 28.73, 116: 7.49},
	49: {113: 4.29, 115: 95.71},
	50: {112: 0.97, 114: 0.66, 115: 0.34, 116: 14.54, 117: 7.68, 118: 24.22, 119: 8.59, 120: 32.58, 122: 4.63, 124: 5.79},
	51: {121: 57.21, 123: 42.79},
	52: {120: 0.09, 122: 2.55, 123: 0.89, 124: 4.74, 125: 7.07, 126: 18.84, 128: 31.74, 130: 34.08},
	53: {127: 100},
	54: {124: 0.0952, 126: 0.089, 128: 1.9102, 129: 26.4006, 130: 4.071, 131: 21.2324, 132: 26.9086, 134: 10.4357, 136: 8.8573},
	55: {133: 100},
	56: {130: 0.106, 132: 0.101, 134: 2.417, 135: 6.592, 136: 7.854, 137: 11.232, 138: 71.698},
	57: {138: 0.08881, 139: 99.9112},
	58: {136: 0.185, 138: 0.251, 140: 88.45, 142: 11.114},
	59: {141: 100},
	60: {142: 27.152, 143: 12.174, 144: 23.798, 145: 8.293, 146: 17.189, 148: 5.756, 150: 5.638},
	62: {144: 3.07, 147: 14.99, 148: 11.24, 149: 13.82, 150: 7.38, 152: 26.75, 154: 22.75},
	63: {151: 47.81, 153: 52.19},
	64: {152: 0.2, 154: 2.18, 155: 14.8, 156: 20.47, 157: 15.65, 158: 24.84, 160: 21.86},
	65: {159: 100},
	66: {156: 0.056, 158: 0.095, 160: 2.329, 161: 18.889, 162: 25.475, 163: 24.896, 164: 28.26},
	67: {165: 100},
	68: {162: 0.139, 164: 1.601, 166: 33.503, 167: 22.869, 168: 26.978, 170: 14.91},
	69: {169: 100},
	70: {168: 0.123, 170: 2.982, 171: 14.09, 172: 21.68, 173: 16.103, 174: 32.026, 176: 12.996},
	71: {175: 97.401, 176: 2.599},
	72: {174: 0.16, 176: 5.26, 177: 18.6, 178: 27.28, 179: 13.62, 180: 35.08},
	73: {180: 0.01201, 181: 99.988},
	74: {180: 0.12, 182: 26.5, 183: 14.31, 184: 30.64, 186: 28.43},
	75: {185: 37.4, 187: 62.6},
	76: {184: 0.02, 186: 1.59, 187: 1.96, 188: 13.24, 189: 16.15, 190: 26.26, 192: 40.78},
	77: {191: 37.3, 193: 62.7},
	78: {190: 0.012, 192: 0.782, 194: 32.86, 195: 33.78, 196: 25.21, 198: 7.356},
	79: {197: 100},
	80: {196: 0.15, 198: 9.97, 199: 16.87, 200: 23.1, 201: 13.18, 202: 29.86, 204: 6.87},
	81: {203: 29.52, 205: 70.48},
	82: {204: 1.4, 206: 24.1, 207: 22.1, 208: 52.4},
	83: {209: 100},
	90: {232: 100},
	91: {231: 100},
	92: {234: 0.0054, 235: 0.7204, 238: 99.2742},
}

## Os isótopos do hidrogênio têm nome próprio.
const APELIDOS := {1: {1: "prótio", 2: "deutério", 3: "trítio"}}

const _SEMIMETAIS := [5, 14, 32, 33, 51, 52, 84]
const _NAO_METAIS := [1, 6, 7, 8, 15, 16, 34]
## O primeiro elemento de cada período (o índice é o período).
const _INICIO_DO_PERIODO := [0, 1, 3, 11, 19, 37, 55, 87, 119]

# ── A distribuição eletrônica ──
## Os subníveis na ordem em que enchem (o diagrama de Pauling).
const _ORDEM := ["1s", "2s", "2p", "3s", "3p", "4s", "3d", "4p", "5s", "4d", "5p", "6s", "4f",
	"5d", "6p", "7s", "5f", "6d", "7p"]
const _CABEM := {"s": 2, "p": 6, "d": 10, "f": 14}
## Os átomos que não seguem a ordem: o que cada um tem de diferente.
const _EXCECOES := {
	24: {"3d": 5, "4s": 1}, 29: {"3d": 10, "4s": 1},
	41: {"4d": 4, "5s": 1}, 42: {"4d": 5, "5s": 1}, 44: {"4d": 7, "5s": 1},
	45: {"4d": 8, "5s": 1}, 46: {"4d": 10, "5s": 0}, 47: {"4d": 10, "5s": 1},
	57: {"4f": 0, "5d": 1}, 58: {"4f": 1, "5d": 1}, 64: {"4f": 7, "5d": 1},
	78: {"5d": 9, "6s": 1}, 79: {"5d": 10, "6s": 1},
	89: {"5f": 0, "6d": 1}, 90: {"5f": 0, "6d": 2}, 91: {"5f": 2, "6d": 1},
	92: {"5f": 3, "6d": 1}, 93: {"5f": 4, "6d": 1}, 96: {"5f": 7, "6d": 1},
	103: {"6d": 0, "7p": 1},
}
## Os subníveis que enchem em cada período (o índice é o período): os de
## valência de quem está nele.
const _DO_PERIODO := [[], ["1s"], ["2s", "2p"], ["3s", "3p"], ["4s", "3d", "4p"],
	["5s", "4d", "5p"], ["6s", "4f", "5d", "6p"], ["7s", "5f", "6d", "7p"]]

static var _por_simbolo := {}
static var _camadas := {}


# ─────────────────────────────────────────────────────────────
# O QUE ESTÁ NA CAIXA
# ─────────────────────────────────────────────────────────────

static func existe(z: int) -> bool:
	return z >= 1 and z <= TOTAL


static func simbolo(z: int) -> String:
	return String(DADOS[z - 1][0]) if existe(z) else ""


static func nome(z: int) -> String:
	return String(DADOS[z - 1][1]) if existe(z) else ""


## A massa atômica como se escreve na caixa: "12,011", ou "[226]".
static func massa(z: int) -> String:
	return String(DADOS[z - 1][2]) if existe(z) else ""


## O número atômico do elemento com este símbolo (0 se não existe).
static func numero(simbolo_pedido: String) -> int:
	if _por_simbolo.is_empty():
		for z in range(1, TOTAL + 1):
			_por_simbolo[simbolo(z)] = z
	return int(_por_simbolo.get(simbolo_pedido, 0))


# ─────────────────────────────────────────────────────────────
# O NÚCLEO
# ─────────────────────────────────────────────────────────────

## O número de massa (prótons + nêutrons) do isótopo mais comum na natureza
## ou, para quem não existe nela, do mais estável.
static func isotopo(z: int) -> int:
	return int(DADOS[z - 1][3]) if existe(z) else 0


## Quantos nêutrons esse isótopo mais comum tem.
static func neutrons(z: int) -> int:
	return isotopo(z) - z if existe(z) else 0


## De cada 100 átomos do elemento na natureza, quantos têm este número de
## massa. -1 se nenhum: esse isótopo é instável ou só existe como traço.
static func abundancia(z: int, massa_pedida: int) -> float:
	var do_elemento: Dictionary = ISOTOPOS_NATURAIS.get(z, {})
	return float(do_elemento.get(massa_pedida, -1.0))


## "Carbono-14": o nome de um átomo com este tanto de prótons e de nêutrons.
static func nome_do_isotopo(z: int, massa_pedida: int) -> String:
	return "%s-%d" % [nome(z), massa_pedida] if existe(z) else ""


## O nome próprio do isótopo, quando ele tem ("deutério"); senão, vazio.
static func apelido_do_isotopo(z: int, massa_pedida: int) -> String:
	var do_elemento: Dictionary = APELIDOS.get(z, {})
	return String(do_elemento.get(massa_pedida, ""))


# ─────────────────────────────────────────────────────────────
# O LUGAR NA TABELA
# ─────────────────────────────────────────────────────────────

static func periodo(z: int) -> int:
	if not existe(z):
		return 0
	for p in range(1, 8):
		if z < int(_INICIO_DO_PERIODO[p + 1]):
			return p
	return 0


## O grupo, de 1 a 18. Os lantanídios e os actinídios, que ficam nas duas
## fileiras de baixo, devolvem 0.
static func grupo(z: int) -> int:
	if not existe(z):
		return 0
	if z == 1:
		return 1
	if z == 2:
		return 18
	var p := periodo(z)
	var n := z - int(_INICIO_DO_PERIODO[p]) + 1
	if p <= 3:
		return n if n <= 2 else n + 10
	if p <= 5 or n <= 2:
		return n
	return 0 if n <= 17 else n - 14


static func e_lantanidio(z: int) -> bool:
	return z >= 57 and z <= 71


static func e_actinidio(z: int) -> bool:
	return z >= 89 and z <= 103


## Onde o elemento fica no desenho da tabela: coluna (0 a 17) e linha (0 a 6
## são os períodos; 7 é a fileira dos lantanídios e 8 a dos actinídios).
static func casa(z: int) -> Vector2i:
	if not existe(z):
		return Vector2i(-1, -1)
	if e_lantanidio(z):
		return Vector2i(2 + z - 57, 7)
	if e_actinidio(z):
		return Vector2i(2 + z - 89, 8)
	return Vector2i(grupo(z) - 1, periodo(z) - 1)


## O elemento que mora nesta casa do desenho da tabela (0 se ela é vazia).
static func na_casa(coluna: int, linha: int) -> int:
	for z in range(1, TOTAL + 1):
		if casa(z) == Vector2i(coluna, linha):
			return z
	return 0


static func familia(z: int) -> Familia:
	if e_lantanidio(z):
		return Familia.LANTANIDIO
	if e_actinidio(z):
		return Familia.ACTINIDIO
	var g := grupo(z)
	if g == 18:
		return Familia.GAS_NOBRE
	if z in _SEMIMETAIS:
		return Familia.SEMIMETAL
	if z in _NAO_METAIS:
		return Familia.NAO_METAL
	if g == 17:
		return Familia.HALOGENIO
	if g == 1:
		return Familia.METAL_ALCALINO
	if g == 2:
		return Familia.METAL_ALCALINOTERROSO
	if g >= 3 and g <= 12:
		return Familia.METAL_DE_TRANSICAO
	return Familia.OUTRO_METAL


## "gás nobre" (um elemento) ou, com "plural", "gases nobres" (a família).
static func nome_da_familia(qual: Familia, plural: bool = false) -> String:
	return String(FAMILIAS[qual][1 if plural else 0])


# ─────────────────────────────────────────────────────────────
# OS ELÉTRONS
# ─────────────────────────────────────────────────────────────

## Quantos elétrons o átomo neutro tem em cada camada, de dentro para fora
## (K, L, M...). O carbono: [2, 4].
static func camadas(z: int) -> PackedInt32Array:
	if not existe(z):
		return PackedInt32Array()
	if not _camadas.has(z):
		_camadas[z] = _em_camadas(_subniveis(z))
	return _camadas[z]


## As camadas de um átomo com "z" prótons e este tanto de elétrons: o neutro,
## um cátion (elétrons a menos) ou um ânion (a mais). Ver ÍONS, no topo.
static func camadas_com(z: int, eletrons: int) -> PackedInt32Array:
	eletrons = clampi(eletrons, 0, TOTAL)
	if not existe(z) or eletrons >= z:
		# Sem núcleo que diga de que elemento é, ou com elétrons a mais: como
		# no átomo neutro que tem esse tanto de elétrons.
		return camadas(eletrons)
	var cfg := _subniveis(z)
	var restam := z
	while restam > eletrons:
		var qual := _de_onde_sai(cfg, restam)
		var tirar := mini(restam - eletrons, cfg[qual])
		cfg[qual] -= tirar
		restam -= tirar
	return _em_camadas(cfg)


## A distribuição escrita: "2 - 8 - 1".
static func texto_das_camadas(lista: PackedInt32Array) -> String:
	var partes := PackedStringArray()
	for n in lista:
		partes.append(str(n))
	return " - ".join(partes)


## Quantos elétrons em cada subnível, na ordem de _ORDEM.
static func _subniveis(z: int) -> PackedInt32Array:
	var cfg := PackedInt32Array()
	cfg.resize(_ORDEM.size())
	var resto := z
	for i in _ORDEM.size():
		var cabem: int = _CABEM[String(_ORDEM[i])[1]]
		cfg[i] = mini(resto, cabem)
		resto -= cfg[i]
	var diferente: Dictionary = _EXCECOES.get(z, {})
	for sub: String in diferente:
		cfg[_ORDEM.find(sub)] = int(diferente[sub])
	return cfg


static func _em_camadas(cfg: PackedInt32Array) -> PackedInt32Array:
	var lista := PackedInt32Array()
	lista.resize(LETRAS_DAS_CAMADAS.size())
	for i in _ORDEM.size():
		lista[int(String(_ORDEM[i])[0]) - 1] += cfg[i]
	while not lista.is_empty() and lista[lista.size() - 1] == 0:
		lista.remove_at(lista.size() - 1)
	return lista


## O subnível que perde o próximo elétron de um átomo que ainda tem "restam":
## dos de valência (os do período em que esse tanto de elétrons está), o de
## camada mais alta; no empate, o p antes do s.
static func _de_onde_sai(cfg: PackedInt32Array, restam: int) -> int:
	var do_periodo: Array = _DO_PERIODO[periodo(restam)]
	var melhor := -1
	for sub: String in do_periodo:
		var i := _ORDEM.find(sub)
		if cfg[i] <= 0:
			continue
		if melhor < 0 or _mais_de_fora(sub, String(_ORDEM[melhor])):
			melhor = i
	if melhor >= 0:
		return melhor
	# Não devia acontecer (os de valência nunca estão todos vazios): o último
	# subnível com elétron.
	for i in range(_ORDEM.size() - 1, -1, -1):
		if cfg[i] > 0:
			return i
	return 0


static func _mais_de_fora(a: String, b: String) -> bool:
	if a[0] != b[0]:
		return int(a[0]) > int(b[0])
	return "spdf".find(a[1]) > "spdf".find(b[1])


# ─────────────────────────────────────────────────────────────
# COMO SE ESCREVE
# ─────────────────────────────────────────────────────────────

## A carga do jeito que vai em cima do símbolo: "" (neutro), "+", "2+", "-",
## "3-".
static func carga_no_simbolo(carga: int) -> String:
	if carga == 0:
		return ""
	var numero_escrito := "" if absi(carga) == 1 else str(absi(carga))
	return numero_escrito + ("+" if carga > 0 else "-")


## A carga por extenso: "0", "+2", "-1".
static func carga_escrita(carga: int) -> String:
	if carga == 0:
		return "0"
	return ("+" if carga > 0 else "-") + str(absi(carga))


## Um número com vírgula e sem zeros sobrando: 98.93 -> "98,93", 100.0 ->
## "100", 0.0115 -> "0,0115". "algarismos" são os significativos.
static func numero_com_virgula(valor: float, algarismos: int = 4) -> String:
	if is_zero_approx(valor):
		return "0"
	var casas := clampi(algarismos - 1 - floori(log(absf(valor)) / log(10.0)), 0, 8)
	var texto := String.num(valor, casas)
	if texto.contains("."):
		texto = texto.rstrip("0").rstrip(".")
	return texto.replace(".", ",")
