class_name PaginasCaderno
extends RefCounted

# --- O QUE ESTÁ ESCRITO NO CADERNO DA CACAU ---
#
# Só o conteúdo. Quem desenha e vira as folhas é o CadernoLivro
# (scripts/ui/caderno_livro.gd); quem abre e fecha é o autoload Caderno
# (scripts/caderno.gd); quem põe cada coisa no lugar é a FaceCaderno
# (scripts/ui/face_caderno.gd).
#
# O caderno abre em PÁGINA DUPLA: cada página é uma abertura do caderno, com
# uma face à esquerda e outra à direita, e cada virada de folha troca as duas.
#
# UMA FACE é um dicionário com "tipo" (e um "titulo" opcional no alto); vazio
# = folha em branco. Os tipos:
#
#   "rosto"         a folha de rosto: "linhas" do título e o "nome" da dona
#                   escrito na linha, depois do "rotulo_nome"
#   "epigrafe"      uma citação ("texto", já com as aspas) e, embaixo e
#                   alinhadas à direita, as linhas da "autoria"
#   "desenho"       um desenho com um traço de cada parte até o nome dela,
#                   feito mapa mental:
#                   "arte"         o desenho
#                   "escala"       quanto ele é ampliado (sem dizer, 2×)
#                   "tinta"        onde o desenho tem tinta (px da arte; sem
#                                  dizer, a arte toda): os traços passam dela
#                   "nome"         texto escrito dentro do desenho (o nome do
#                                  elemento na caixa — em texto, para traduzir)
#                   "vao_do_nome"  onde esse nome vai (px da arte)
#                   "marcas"       [{"de", "rumo", "texto"}]: "de" é a beira da
#                                  parte (px da arte) de onde o traço sai, e
#                                  "rumo" para onde ele vai (cima, baixo,
#                                  esquerda, direita). Subindo ou descendo,
#                                  "lado" (esquerda, direita) põe o texto ao
#                                  lado da ponta, em vez de na ponta. "ate"
#                                  (px da arte) para o traço antes, para o
#                                  texto caber num vão do desenho
#   "propriedades"  "itens": [{"formula", "texto"}] — a fórmula e uma
#                   explicação curta embaixo. Com "icones" (uma arte) na face,
#                   cada item pode ter um "icone": o pedaço dela (px da arte)
#                   que vai antes da fórmula; e, com "pedacos" ({nome: o
#                   pedaço}), o texto pode ter {nome} no meio, que vira o
#                   ícone. O que vai *entre asteriscos* fica na cor da
#                   fórmula. Com "formulas_no_meio", cada fórmula vai
#                   centrada na face, e com "formula_embaixo", embaixo do
#                   texto dela
#
# O texto é quebrado e medido na face; o teste_caderno confere que tudo cabe
# no papel.

const ARTE_HIDROGENIO := preload("res://assets/caderno de anotaçõess/Hidrogênio tabela periódica.png")
const ARTE_LITIO := preload("res://assets/caderno de anotaçõess/litio atomo3.png")
## Elétron, próton e nêutron lado a lado, do mesmo tamanho que no átomo.
const ARTE_PARTICULAS := preload("res://assets/caderno de anotaçõess/eletron, proton e neutron.png")
## Cada partícula na ARTE_PARTICULAS (px da arte), para o {nome} no texto.
const PARTICULAS := {
	"elétron": Rect2(2, 3, 12, 12),
	"próton": Rect2(15, 0, 16, 16),
	"nêutron": Rect2(32, 0, 16, 16),
}

const PAGINAS := [
	# A esquerda é o verso da capa, em branco; virando a folha de rosto, a
	# epígrafe está atrás dela.
	[
		{},
		{
			"tipo": "rosto",
			"linhas": ["Caderno de", "Anotações"],
			"rotulo_nome": "nome:",
			"nome": "Cacau",
		},
	],
	[
		# A direita fica em branco: o átomo ocupa as duas faces da folha
		# seguinte.
		{
			"tipo": "epigrafe",
			"texto": "“Equipado com seus cinco sentidos, o ser humano explora o universo ao seu redor e chama essa aventura de ciência.”",
			"autoria": ["— Edwin Hubble"],
		},
		{},
	],
	[
		# O átomo não cabe do lado dos nomes: eles vão numa fileira em cima e
		# noutra embaixo. Em 2× não sobra lugar para o título; em 1,5× o traço
		# de 2 px da arte vira 3 px certinhos.
		{
			"tipo": "desenho",
			"titulo": "O átomo",
			"arte": ARTE_LITIO,
			"escala": 1.5,
			# Os anéis vão de (47, 18) a (221, 193); o resto é transparente.
			"tinta": Rect2(47, 18, 175, 176),
			"marcas": [
				# Em cima: o anel de fora e o elétron de cima.
				{"de": Vector2(70, 46), "rumo": "cima", "texto": "eletrosfera"},
				{"de": Vector2(187, 76), "rumo": "cima", "texto": "elétron (e)"},
				# O núcleo, no vão entre ele e o anel de dentro: o traço sai do
				# próton de cima, entre os dois nêutrons.
				{"de": Vector2(135, 96), "rumo": "cima", "ate": 82, "texto": "núcleo"},
				# Embaixo, cada nome ao lado da ponta do traço: o próton da
				# esquerda e o nêutron de baixo.
				{"de": Vector2(120, 120), "rumo": "baixo", "lado": "esquerda", "texto": "próton (p)"},
				{"de": Vector2(135, 129), "rumo": "baixo", "lado": "direita", "texto": "nêutron (n)"},
			],
		},
		{
			"tipo": "propriedades",
			"icones": ARTE_PARTICULAS,
			"itens": [
				{"icone": Rect2(15, 0, 16, 16), "formula": "próton (p)",
					"texto": "Carga positiva. Fica no núcleo."},
				{"icone": Rect2(32, 0, 16, 16), "formula": "nêutron (n)",
					"texto": "Sem carga. Fica no núcleo, junto dos prótons."},
				{"icone": Rect2(2, 3, 12, 12), "formula": "elétron (e)",
					"texto": "Carga negativa. Gira na eletrosfera e é bem mais leve que o próton."},
			],
		},
	],
	[
		{
			"tipo": "desenho",
			"titulo": "Atomística",
			"arte": ARTE_HIDROGENIO,
			"nome": "Hidrogênio",
			# Entre o pé do H e o topo do 1,008, por dentro da borda.
			"vao_do_nome": Rect2(5, 49, 66, 25),
			"marcas": [
				{"de": Vector2(15, 10), "rumo": "cima", "texto": "número atômico (Z)"},
				{"de": Vector2(49, 34), "rumo": "direita", "texto": "símbolo"},
				{"de": Vector2(38, 83), "rumo": "baixo", "texto": "número de massa (A)"},
			],
		},
		{
			"tipo": "propriedades",
			"formulas_no_meio": true,
			"formula_embaixo": true,
			"icones": ARTE_PARTICULAS,
			"pedacos": PARTICULAS,
			"itens": [
				{"formula": "Z = p", "texto": "*Número atômico (Z)* é a quantidade de *prótons* {próton} existentes no núcleo do átomo."},
				{"formula": "A = Z + n", "texto": "*Número de massa (A)* é a soma da quantidade de *prótons* {próton} e *nêutrons* {nêutron}."},
				{"formula": "p = e", "texto": "Um átomo neutro terá a mesma quantidade de *elétrons* {elétron} e *prótons* {próton}."},
			],
		},
	],
]

## O que o caderno mostra: as PAGINAS. O teste_caderno põe folhas a mais aqui
## para ter várias para folhear.
static var paginas: Array = PAGINAS


static func quantas() -> int:
	return paginas.size()


## O número de uma face (lado 0 = esquerda, 1 = direita), contando as duas de
## cada página: a folha de rosto é a 1 e, dali em diante, as da esquerda são
## pares e as da direita, ímpares. O verso da capa é o 0: sem número.
static func numero(pagina: int, lado: int) -> int:
	return pagina * 2 + lado


## As duas faces da página ([esquerda, direita]); fora do caderno, duas vazias.
static func faces(pagina: int) -> Array:
	if pagina < 0 or pagina >= paginas.size():
		return [{}, {}]
	return paginas[pagina]
