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
#                   "desenho_no_meio"  o desenho vai no meio da face, com os
#                                  nomes em volta (sem isto, o que vai no meio
#                                  é o conjunto: o desenho e os nomes dele)
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
#
# O CADERNO NÃO VEM INTEIRO. A Cacau começa com ele só até a página 3 (a folha
# de rosto e a epígrafe); as outras páginas são NOTAS soltas pelo mapa
# (scenes/fases/componentes/nota_caderno.tscn). Cada nota das NOTAS devolve as
# páginas duplas dela ao caderno, no lugar delas: o número de cada face não
# muda, então, com uma nota faltando no meio, a numeração pula. Página que
# nenhuma nota traz já vem no caderno.
#
# Por enquanto a nota é uma só, "O Átomo": ela traz as páginas 4 a 7 (o átomo
# e, na folha seguinte, a caixa do elemento e as contas).
#
# PARA UMA NOTA NOVA: escreva as páginas duplas nas PAGINAS, dê um nome a ela
# nas NOTAS e ponha uma nota_caderno.tscn no mapa com esse nome.

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
			"titulo": "O Átomo",
			"arte": ARTE_LITIO,
			"escala": 1.5,
			# Os anéis vão de (47, 18) a (221, 193); o resto é transparente.
			"tinta": Rect2(47, 18, 175, 176),
			"marcas": [
				# Em cima: o elétron de cima.
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
		# Continua a nota do átomo: sem título, com a caixa do elemento bem no
		# meio da face.
		{
			"tipo": "desenho",
			"desenho_no_meio": true,
			"arte": ARTE_HIDROGENIO,
			"nome": "Hidrogênio",
			# Entre o pé do H e o topo do 1,008, por dentro da borda.
			"vao_do_nome": Rect2(5, 49, 66, 25),
			"marcas": [
				{"de": Vector2(15, 10), "rumo": "cima", "texto": "número atômico (Z)"},
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

## As notas soltas pelo mapa: o nome de cada uma (é o que a nota_caderno.tscn
## escolhe no editor), o "titulo" que aparece no aviso de nota adicionada e as
## "paginas" que ela devolve ao caderno (a posição de cada uma nas PAGINAS,
## contando do 0, na ordem).
const NOTAS := {
	"atomo": {"titulo": "O Átomo", "paginas": [2, 3]},
}

## O caderno inteiro: as PAGINAS. O teste_caderno põe folhas a mais aqui para
## ter várias para folhear.
static var paginas: Array = PAGINAS

## As notas que a Cacau já achou (nome -> true). Como o EstadoMundo, vale
## enquanto o jogo estiver aberto: não existe sistema de save ainda.
static var _achadas: Dictionary = {}


# ─────────────────────────────────────────────────────────────
# AS NOTAS
# ─────────────────────────────────────────────────────────────

static func tem_nota(nota: String) -> bool:
	return _achadas.has(nota)


## Põe a nota no caderno. Devolve false se ela não existe ou já estava lá.
## Quem acha uma nota no jogo chama o Caderno.guardar_nota(), que faz isto e
## avisa na tela.
static func guardar_nota(nota: String) -> bool:
	if not NOTAS.has(nota) or tem_nota(nota):
		return false
	_achadas[nota] = true
	return true


## O caderno volta a ser o do começo do jogo, só até a página 3.
static func esquecer_notas() -> void:
	_achadas.clear()


static func notas_achadas() -> int:
	return _achadas.size()


static func titulo_da_nota(nota: String) -> String:
	return String(NOTAS.get(nota, {}).get("titulo", ""))


## As páginas duplas que a nota traz (a posição de cada uma em "paginas").
static func paginas_da_nota(nota: String) -> Array:
	return NOTAS.get(nota, {}).get("paginas", [])


## Os números da primeira e da última face que a nota traz (x e y): a esquerda
## da primeira página dupla dela e a direita da última.
static func numeros_da_nota(nota: String) -> Vector2i:
	var dela := paginas_da_nota(nota)
	if dela.is_empty():
		return Vector2i.ZERO
	return Vector2i(int(dela[0]) * 2, int(dela[-1]) * 2 + 1)


## Em que página do caderno a nota começa agora, contando só as que ele tem
## (-1 = ainda não foi achada).
static func lugar_da_nota(nota: String) -> int:
	var dela := paginas_da_nota(nota)
	if not tem_nota(nota) or dela.is_empty():
		return -1
	return no_caderno().find(int(dela[0]))


# ─────────────────────────────────────────────────────────────
# O QUE O CADERNO TEM AGORA
# ─────────────────────────────────────────────────────────────

## As páginas que estão no caderno agora: a posição de cada uma em "paginas",
## na ordem. Ficam de fora as das notas que a Cacau ainda não achou.
static func no_caderno() -> Array[int]:
	var faltando := {}
	for nota in NOTAS:
		if not tem_nota(nota):
			for pagina in paginas_da_nota(nota):
				faltando[int(pagina)] = true
	var lista: Array[int] = []
	for i in paginas.size():
		if not faltando.has(i):
			lista.append(i)
	return lista


## Quantas páginas o caderno tem agora. Daqui para baixo, "pagina" conta só
## essas: 0 é a primeira que ele tem, 1 a seguinte, e assim por diante.
static func quantas() -> int:
	return no_caderno().size()


## O número de uma face (lado 0 = esquerda, 1 = direita), contando as duas de
## cada página do caderno inteiro: a folha de rosto é a 1 e, dali em diante, as
## da esquerda são pares e as da direita, ímpares. O verso da capa é o 0: sem
## número.
static func numero(pagina: int, lado: int) -> int:
	var tem := no_caderno()
	if pagina < 0 or pagina >= tem.size():
		return pagina * 2 + lado
	return tem[pagina] * 2 + lado


## As duas faces da página ([esquerda, direita]); fora do caderno, duas vazias.
static func faces(pagina: int) -> Array:
	var tem := no_caderno()
	if pagina < 0 or pagina >= tem.size():
		return [{}, {}]
	return paginas[tem[pagina]]
