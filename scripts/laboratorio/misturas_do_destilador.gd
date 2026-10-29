class_name MisturasDoDestilador
extends RefCounted

# --- AS MISTURAS E AS SUBSTÂNCIAS DO DESTILADOR (Laboratório) ---
#
# O que o simulador de destilação sabe destilar. Cada MISTURA é um conjunto de
# SUBSTÂNCIAS que se separam porque umas evaporam mais fácil que as outras. A
# conta de quanto cada uma evapora, em cada temperatura, é a PRESSÃO DE VAPOR
# dela ("vapor", abaixo), e quem a faz é o EquilibrioLiquidoVapor
# (scripts/laboratorio/equilibrio_liquido_vapor.gd): toda substância evapora
# um pouco em qualquer temperatura, cada vez mais quanto mais quente, e a
# mistura FERVE quando a pressão de vapor dela chega a 1 atm.
#
# O PONTO DE EBULIÇÃO ("ebulicao") é o da substância PURA, a 1 atm, arredondado
# para o grau (NIST Chemistry WebBook e a tabela periódica do PubChem). É o que
# as fichas e o termômetro mostram:
#   nitrogênio -195,8   argônio -185,8   oxigênio -183,0   (os três da coluna
#   da história, que os mostra como -196, -186 e -183)
#   neônio -246,1   criptônio -153,4   xenônio -108,1
#   metano -161,5   etano -88,6   propano -42,1   butano -0,5
#   octano 125,6   dodecano 216,3   hexadecano 286,9
#   etanol 78,4   água 100,0   sal de cozinha 1465
# O butano fica com a vírgula: arredondado, ele deixaria de ferver "um pouco
# abaixo de zero", que é o que ele tem de curioso.
#
# A PRESSÃO DE VAPOR ("vapor") é a equação de Antoine, log₁₀(P/bar) =
# A − B / (T + C), com T em kelvin. De onde vem cada uma:
#   N₂, O₂, Ar, propano, butano   Lange's Handbook of Chemistry (de mmHg e °C
#                                 para bar e K: A − 2,8751 e C − 273,15)
#   metano, etano, octano, dodecano, hexadecano, etanol, água
#                                 NIST Chemistry WebBook
#   neônio, criptônio, xenônio    Clausius-Clapeyron com o calor de
#                                 vaporização no ponto de ebulição (CRC
#                                 Handbook): B = ΔH / (R·ln 10), C = 0
#   o sal                         não evapora (não tem "vapor")
# O teste (tools/teste_destilador_do_laboratorio.tscn) confere que cada uma
# ferve, pela conta, a menos de meio grau do "ebulicao" dela.
#
# UMA SUBSTÂNCIA:
#   "nome"      como se escreve na ficha
#   "formula"   a fórmula (os números descem na hora de escrever)
#   "ebulicao"  o ponto de ebulição da substância pura, em °C
#   "vapor"     [A, B, C] da equação de Antoine (sem ele: não evapora)
#   "fusao"     o ponto de fusão, em °C: só do que é SÓLIDO na escala do
#               termômetro (o sal, 801 °C, CRC Handbook). A ficha diz SÓLIDO —
#               ou DISSOLVIDO, se todo ele cabe na água que há junto
#   "forma"     o desenho da molécula (ver MoleculasDoDestilador): "bola" (um
#               átomo sozinho), "dupla" (dois átomos iguais), "agua", "alcool",
#               "sal" ou "cadeia" (uma fileira de carbonos; "carbonos" diz
#               quantos)
#   "cores"     as três cores da bolinha: base, brilho e sombra
#   "liquido" e "tona"   a cor do líquido dela na coluna e a da ondinha de cima
#
# UMA MISTURA:
#   "nome"         como aparece na lista
#   "substancias"  quantas moléculas de cada uma entram na coluna. A conta é
#                  feita com ELAS: a mistura que se destila é exatamente a que
#                  se vê. Por isso o ar da lista é quase o de verdade (o ar tem
#                  78% de N₂, 21% de O₂ e 1% de argônio; aqui o argônio está
#                  aumentado para aparecer: 22 N₂, 7 O₂ e 2 Ar)
#   "minima" e "maxima"   até onde o termômetro vai, em °C
#   "resfriador"   a temperatura em que o resfriador segura o topo da coluna.
#                  É a do topo de uma coluna de verdade: perto do ponto de
#                  ebulição do que sai por cima (o nitrogênio, a água, o
#                  álcool). Mais frio que isso, as bandejas do meio também
#                  ficariam frias demais e o vapor condensaria todo nelas
#   "calor"        de onde vem o calor que entra por baixo. No frio extremo
#                  não há aparelho nenhum: é o calor do ambiente (como na
#                  coluna da história). Nas misturas quentes é o fogo
#   "nota"         o que essa destilação é no mundo, numa frase
#
# PARA PÔR UMA MISTURA: acrescente as substâncias que faltarem e a mistura na
# lista. O teste (tools/teste_destilador_do_laboratorio.tscn) confere que dá
# para separá-la com o termômetro.

const SUBSTANCIAS := {
	"N2": {"nome": "Nitrogênio", "formula": "N2", "ebulicao": -196.0, "forma": "dupla",
		"vapor": [3.619473, 255.68, -6.6],
		"cores": [Color("3ecf72"), Color("d2ffd6"), Color("12704a")],
		"liquido": Color("0f4a37"), "tona": Color("58d68d")},
	"O2": {"nome": "Oxigênio", "formula": "O2", "ebulicao": -183.0, "forma": "dupla",
		"vapor": [3.816343, 319.013, -6.453],
		"cores": [Color("3232e0"), Color("819fff"), Color("1a0f6e")],
		"liquido": Color("15186b"), "tona": Color("7f8cff")},
	"Ar": {"nome": "Argônio", "formula": "Ar", "ebulicao": -186.0, "forma": "bola",
		"vapor": [3.741413, 304.227, -5.83],
		"cores": [Color("c77dff"), Color("f6e2ff"), Color("6f2f9c")],
		"liquido": Color("47206a"), "tona": Color("d9a6ff")},
	"Ne": {"nome": "Neônio", "formula": "Ne", "ebulicao": -246.0, "forma": "bola",
		"vapor": [3.30164, 89.3195, 0.0],
		"cores": [Color("ff7a59"), Color("ffe0c8"), Color("a8321f")],
		"liquido": Color("6e2416"), "tona": Color("ffab8f")},
	"Kr": {"nome": "Kriptônio", "formula": "Kr", "ebulicao": -153.0, "forma": "bola",
		"vapor": [3.96631, 474.281, 0.0],
		"cores": [Color("46c2d6"), Color("d9fbff"), Color("176b7c")],
		"liquido": Color("12454f"), "tona": Color("7fe3f2")},
	"Xe": {"nome": "Xenônio", "formula": "Xe", "ebulicao": -108.0, "forma": "bola",
		"vapor": [3.983784, 656.58, 0.0],
		"cores": [Color("f2c84b"), Color("fff6cf"), Color("96721a")],
		"liquido": Color("5c4510"), "tona": Color("ffe07a")},
	"CH4": {"nome": "Metano", "formula": "CH4", "ebulicao": -162.0, "forma": "cadeia", "carbonos": 1,
		"vapor": [3.9895, 443.028, -0.49],
		"cores": [Color("d94a3d"), Color("ffb39a"), Color("7a1c14")],
		"liquido": Color("5a1a14"), "tona": Color("ff8a78")},
	"C2H6": {"nome": "Etano", "formula": "C2H6", "ebulicao": -89.0, "forma": "cadeia", "carbonos": 2,
		"vapor": [3.93835, 659.739, -16.719],
		"cores": [Color("e8862e"), Color("ffd9a8"), Color("8a4410")],
		"liquido": Color("5c3210"), "tona": Color("ffb268")},
	"C3H8": {"nome": "Propano", "formula": "C3H8", "ebulicao": -42.0, "forma": "cadeia", "carbonos": 3,
		"vapor": [3.954633, 813.2, -25.15],
		"cores": [Color("e6c229"), Color("fff5b8"), Color("8a7210")],
		"liquido": Color("5a4a0c"), "tona": Color("ffe46a")},
	"C4H10": {"nome": "Butano", "formula": "C4H10", "ebulicao": -0.5, "forma": "cadeia", "carbonos": 4,
		"vapor": [3.955193, 945.9, -33.15],
		"cores": [Color("7fd13b"), Color("e2ffc2"), Color("3d7a12")],
		"liquido": Color("2c520f"), "tona": Color("aef07a")},
	"C8H18": {"nome": "Octano", "formula": "C8H18", "ebulicao": 126.0, "forma": "cadeia", "carbonos": 8,
		"vapor": [4.04867, 1355.126, -63.633],
		"cores": [Color("e6c229"), Color("fff5b8"), Color("8a7210")],
		"liquido": Color("5a4a0c"), "tona": Color("ffe46a")},
	"C12H26": {"nome": "Dodecano", "formula": "C12H26", "ebulicao": 216.0, "forma": "cadeia", "carbonos": 12,
		"vapor": [4.10549, 1625.928, -92.839],
		"cores": [Color("e8862e"), Color("ffd9a8"), Color("8a4410")],
		"liquido": Color("5c3210"), "tona": Color("ffb268")},
	"C16H34": {"nome": "Hexadecano", "formula": "C16H34", "ebulicao": 287.0, "forma": "cadeia", "carbonos": 16,
		"vapor": [4.17312, 1845.672, -117.054],
		"cores": [Color("b9603f"), Color("f2c2a6"), Color("5e2a16")],
		"liquido": Color("40200f"), "tona": Color("d98a66")},
	"C2H6O": {"nome": "Etanol", "formula": "C2H6O", "ebulicao": 78.0, "forma": "alcool",
		"vapor": [5.24677, 1598.673, -46.424],
		"cores": [Color("f0a13c"), Color("ffe3b5"), Color("8f5412")],
		"liquido": Color("5e3a10"), "tona": Color("ffc670")},
	"H2O": {"nome": "Água", "formula": "H2O", "ebulicao": 100.0, "forma": "agua",
		"vapor": [5.0768, 1659.793, -45.854],
		"cores": [Color("3f8fe8"), Color("cfe6ff"), Color("1a4d94")],
		"liquido": Color("123a70"), "tona": Color("7fb8ff")},
	"NaCl": {"nome": "Sal", "formula": "NaCl", "ebulicao": 1465.0, "fusao": 801.0, "forma": "sal",
		"cores": [Color("e8e6f0"), Color("ffffff"), Color("8f8ca8")],
		"liquido": Color("6a6880"), "tona": Color("f4f2ff")},
}

const MISTURAS := [
	{"chave": "ar", "nome": "AR LÍQUIDO",
		"substancias": {"N2": 22, "Ar": 2, "O2": 7},
		"minima": -200.0, "maxima": -170.0, "resfriador": -196.0, "calor": "CALOR DO\nAMBIENTE",
		"nota": "É ASSIM QUE AS FÁBRICAS TIRAM O NITROGÊNIO E O OXIGÊNIO DO AR. O ARGÔNIO, QUE FERVE QUASE JUNTO COM O OXIGÊNIO, FICA MISTURADO NO MEIO."},
	{"chave": "gases_nobres", "nome": "GASES NOBRES",
		"substancias": {"Ne": 5, "Ar": 6, "Kr": 5, "Xe": 5},
		"minima": -200.0, "maxima": -90.0, "resfriador": -196.0, "calor": "CALOR DO\nAMBIENTE",
		"nota": "O NEÔNIO NÃO VIRA LÍQUIDO NEM NO TOPO: SAI DA COLUNA COMO GÁS."},
	{"chave": "gas_natural", "nome": "GÁS NATURAL",
		"substancias": {"CH4": 8, "C2H6": 5, "C3H8": 4, "C4H10": 4},
		"minima": -170.0, "maxima": 20.0, "resfriador": -162.0, "calor": "CALOR DO\nAMBIENTE",
		"nota": "QUANTO MAIOR A MOLÉCULA, MAIS QUENTE ELA FERVE: O BUTANO É O ÚLTIMO A SUBIR."},
	{"chave": "petroleo", "nome": "PETRÓLEO",
		"substancias": {"C4H10": 5, "C8H18": 5, "C12H26": 4, "C16H34": 4},
		"minima": 25.0, "maxima": 350.0, "resfriador": 100.0, "calor": "FORNALHA",
		"nota": "NA REFINARIA, O GÁS SAI PELO TOPO E A GASOLINA, O QUEROSENE E O DIESEL SE CONCENTRAM CADA UM NUMA ALTURA DA COLUNA."},
	{"chave": "cana", "nome": "ÁLCOOL DA CANA",
		"substancias": {"C2H6O": 7, "H2O": 9},
		"minima": 20.0, "maxima": 110.0, "resfriador": 78.0, "calor": "FOGO",
		"nota": "É ASSIM QUE O ÁLCOOL COMBUSTÍVEL SAI DO CALDO DE CANA FERMENTADO. A ÁGUA EVAPORA JUNTO: DESTILANDO, O ÁLCOOL NÃO PASSA DE UNS 96%."},
	{"chave": "mar", "nome": "ÁGUA DO MAR",
		"substancias": {"H2O": 9, "NaCl": 6},
		"minima": 20.0, "maxima": 120.0, "resfriador": 100.0, "calor": "FOGO",
		"nota": "O SAL NÃO EVAPORA: FICA NO FUNDO, E A ÁGUA SAI PURA PELO TOPO. SALGADA, ELA SÓ FERVE ACIMA DE 100 °C."},
]

## O que as moléculas de carbono do petróleo e do gás natural são no dia a dia
## (aparece na ficha, embaixo do nome).
const APELIDOS := {
	"CH4": "gás natural", "C3H8": "gás de cozinha", "C4H10": "gás de cozinha",
	"C8H18": "gasolina", "C12H26": "querosene", "C16H34": "óleo diesel",
	"NaCl": "cloreto de sódio", "C2H6O": "álcool",
}


## A mistura com esta chave (vazio se não existe).
static func mistura(chave: String) -> Dictionary:
	for dados: Dictionary in MISTURAS:
		if dados["chave"] == chave:
			return dados
	return {}


static func substancia(chave: String) -> Dictionary:
	return SUBSTANCIAS.get(chave, {})


static func ebulicao(chave: String) -> float:
	return float(SUBSTANCIAS[chave]["ebulicao"])


## As substâncias da mistura, da que ferve mais fácil (mais fria) à mais
## difícil: é a ordem em que elas saem do fundo.
static func em_ordem_de_ebulicao(dados: Dictionary) -> Array[String]:
	var chaves: Array[String] = []
	for chave: String in dados["substancias"]:
		chaves.append(chave)
	chaves.sort_custom(func(a: String, b: String) -> bool: return ebulicao(a) < ebulicao(b))
	return chaves


## Uma temperatura como se escreve: "-196 °C", "78 °C" e, só quando ela não é
## um grau inteiro, com a vírgula: "-0,5 °C".
static func graus(temperatura: float) -> String:
	if is_equal_approx(temperatura, roundf(temperatura)):
		return "%d °C" % roundi(temperatura)
	return String.num(temperatura, 1).replace(".", ",") + " °C"
