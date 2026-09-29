class_name PaginasCaderno
extends RefCounted

# --- O QUE ESTÁ ESCRITO NO CADERNO DA CACAU ---
#
# Só o texto. Quem desenha e vira as folhas é o CadernoLivro
# (scripts/ui/caderno_livro.gd); quem abre e fecha é o autoload Caderno
# (scripts/caderno.gd).
#
# O caderno abre em PÁGINA DUPLA: cada página é uma abertura do caderno, com
# uma face à esquerda e outra à direita, e cada virada de folha troca as duas.
# A ordem das páginas é a ordem das fitas na borda do caderno (vermelha, azul,
# verde, roxa) — por isso são QUATRO: uma fita para cada página.
#
# UMA FACE é um dicionário com "tipo":
#
#   "rosto"    folha de rosto: "titulo", "autor", "epigrafe" (linhas),
#              "autor_epigrafe" e "obra"
#   "estrofe"  "versos" (linhas); "fim" = true põe o arremate embaixo
#
# O poema: "Meus Oito Anos", de Casimiro de Abreu (As Primaveras, 1859) —
# domínio público. A folha de rosto e as sete estrofes enchem as oito faces.
# Os tamanhos de letra (scripts/ui/face_caderno.gd) cabem na face o verso mais
# comprido ("Que amor, que sonhos, que flores,"); verso maior que isso precisa
# de letra menor lá (o teste_caderno confere).

const PAGINAS := [
	[
		{
			"tipo": "rosto",
			"titulo": "MEUS OITO ANOS",
			"autor": "Casimiro de Abreu",
			"epigrafe": ["Oh! souvenirs!", "printemps! aurores!"],
			"autor_epigrafe": "V. Hugo",
			"obra": "As Primaveras, 1859",
		},
		{
			"tipo": "estrofe",
			"versos": [
				"Oh! que saudades que tenho",
				"Da aurora da minha vida,",
				"Da minha infância querida",
				"Que os anos não trazem mais!",
				"Que amor, que sonhos, que flores,",
				"Naquelas tardes fagueiras",
				"À sombra das bananeiras,",
				"Debaixo dos laranjais!",
			],
		},
	],
	[
		{
			"tipo": "estrofe",
			"versos": [
				"Como são belos os dias",
				"Do despontar da existência!",
				"— Respira a alma inocência",
				"Como perfumes a flor;",
				"O mar é — lago sereno,",
				"O céu — um manto azulado,",
				"O mundo — um sonho dourado,",
				"A vida — um hino d'amor!",
			],
		},
		{
			"tipo": "estrofe",
			"versos": [
				"Que aurora, que sol, que vida,",
				"Que noites de melodia",
				"Naquela doce alegria,",
				"Naquele ingênuo folgar!",
				"O céu bordado d'estrelas,",
				"A terra de aromas cheia,",
				"As ondas beijando a areia",
				"E a lua beijando o mar!",
			],
		},
	],
	[
		{
			"tipo": "estrofe",
			"versos": [
				"Oh! dias da minha infância!",
				"Oh! meu céu de primavera!",
				"Que doce a vida não era",
				"Nessa risonha manhã!",
				"Em vez das mágoas de agora,",
				"Eu tinha nessas delícias",
				"De minha mãe as carícias",
				"E beijos de minha irmã!",
			],
		},
		{
			"tipo": "estrofe",
			"versos": [
				"Livre filho das montanhas,",
				"Eu ia bem satisfeito,",
				"Da camisa aberta o peito,",
				"— Pés descalços, braços nus —",
				"Correndo pelas campinas",
				"À roda das cachoeiras,",
				"Atrás das asas ligeiras",
				"Das borboletas azuis!",
			],
		},
	],
	[
		{
			"tipo": "estrofe",
			"versos": [
				"Naqueles tempos ditosos",
				"Ia colher as pitangas,",
				"Trepava a tirar as mangas,",
				"Brincava à beira do mar;",
				"Rezava às Ave-Marias,",
				"Achava o céu sempre lindo,",
				"Adormecia sorrindo",
				"E despertava a cantar!",
			],
		},
		{
			"tipo": "estrofe",
			"fim": true,
			"versos": [
				"Oh! que saudades que tenho",
				"Da aurora da minha vida,",
				"Da minha infância querida",
				"Que os anos não trazem mais!",
				"Que amor, que sonhos, que flores,",
				"Naquelas tardes fagueiras",
				"À sombra das bananeiras",
				"Debaixo dos laranjais!",
			],
		},
	],
]


static func quantas() -> int:
	return PAGINAS.size()


## As duas faces da página ([esquerda, direita]); fora do caderno, duas vazias.
static func faces(pagina: int) -> Array:
	if pagina < 0 or pagina >= PAGINAS.size():
		return [{}, {}]
	return PAGINAS[pagina]
