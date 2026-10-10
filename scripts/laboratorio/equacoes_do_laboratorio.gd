class_name EquacoesDoLaboratorio
extends RefCounted

# --- AS EQUAÇÕES DO BALANCEAMENTO (Laboratório) ---
#
# As reações que o balanceamento do Laboratório pede, nível por nível. O nível
# não muda a regra (acertar os coeficientes até os átomos baterem dos dois
# lados): muda quanta ajuda a tela dá.
#
#   FÁCIL     igual ao puzzle do foguete e ao do maçarico: as moléculas
#             desenhadas e a contagem dos átomos dos reagentes e dos produtos.
#   MÉDIO     as moléculas, mas sem a contagem: quem conta é a pessoa.
#   DIFÍCIL   só a equação escrita.
#
# Cada equação é um dicionário:
#   "nome"       o que a reação é (o terminal diz ao apresentá-la)
#   "reagentes"  as fórmulas do lado esquerdo
#   "produtos"   as do lado direito
#   "resposta"   os menores coeficientes que balanceiam, na ordem dos reagentes
#                e depois dos produtos. A tela NÃO compara com isto (vale
#                qualquer resposta balanceada, inclusive em dobro): serve para
#                o teste conferir que a equação tem solução dentro do limite
#                das setas e para a dica da forma mais simples.
#
# NOS NÍVEIS FÁCIL E MÉDIO toda fórmula precisa de desenho (ver
# scripts/ui/folha_moleculas.gd): por isso eles ficam nas substâncias de H, C,
# N e O. O difícil não tem desenho e aceita qualquer fórmula, com parênteses e
# tudo.
#
# As reações foram escolhidas para dizer alguma coisa do jogo: o que queima no
# foguete, no maçarico e na fornalha, o que move as naves e o que limpa o ar
# delas.
#
# PARA PÔR UMA EQUAÇÃO: acrescente a linha no nível. O teste
# (tools/teste_balanceamento.tscn) confere a resposta e os desenhos.

enum Nivel { FACIL, MEDIO, DIFICIL }

const NOMES := {Nivel.FACIL: "FÁCIL", Nivel.MEDIO: "MÉDIO", Nivel.DIFICIL: "DIFÍCIL"}
## O nome de cada nível sem acento, para o código se referir a ele.
const CHAVES := {Nivel.FACIL: "facil", Nivel.MEDIO: "medio", Nivel.DIFICIL: "dificil"}
## O que cada nível mostra, na tela de escolha.
const DESCRICOES := {
	Nivel.FACIL: "COM AS MOLÉCULAS E A CONTAGEM DOS ÁTOMOS",
	Nivel.MEDIO: "COM AS MOLÉCULAS, SEM A CONTAGEM",
	Nivel.DIFICIL: "SÓ A EQUAÇÃO ESCRITA",
}

const EQUACOES := {
	Nivel.FACIL: [
		{"nome": "A QUEIMA DO HIDROGÊNIO, QUE EMPURRA O FOGUETE",
			"reagentes": ["H2", "O2"], "produtos": ["H2O"], "resposta": [2, 1, 2]},
		{"nome": "O CARVÃO QUEIMANDO COM POUCO AR",
			"reagentes": ["C", "O2"], "produtos": ["CO"], "resposta": [2, 1, 2]},
		{"nome": "O MONÓXIDO DE CARBONO TERMINANDO DE QUEIMAR",
			"reagentes": ["CO", "O2"], "produtos": ["CO2"], "resposta": [2, 1, 2]},
		{"nome": "A FABRICAÇÃO DA AMÔNIA",
			"reagentes": ["N2", "H2"], "produtos": ["NH3"], "resposta": [1, 3, 2]},
		{"nome": "A ÁGUA OXIGENADA SE DESFAZENDO",
			"reagentes": ["H2O2"], "produtos": ["H2O", "O2"], "resposta": [2, 2, 1]},
		{"nome": "O RAIO JUNTANDO O NITROGÊNIO E O OXIGÊNIO DO AR",
			"reagentes": ["N2", "O2"], "produtos": ["NO"], "resposta": [1, 1, 2]},
		{"nome": "A QUEIMA DO METANO, O GÁS NATURAL",
			"reagentes": ["CH4", "O2"], "produtos": ["CO2", "H2O"], "resposta": [1, 2, 1, 2]},
	],
	Nivel.MEDIO: [
		{"nome": "O GÁS DO RAIO VIRANDO DIÓXIDO DE NITROGÊNIO",
			"reagentes": ["NO", "O2"], "produtos": ["NO2"], "resposta": [2, 1, 2]},
		{"nome": "A QUEIMA DA HIDRAZINA, COMBUSTÍVEL DE FOGUETE",
			"reagentes": ["N2H4", "O2"], "produtos": ["N2", "H2O"], "resposta": [1, 1, 1, 2]},
		{"nome": "COMO SE FAZ HIDROGÊNIO A PARTIR DO GÁS NATURAL",
			"reagentes": ["CH4", "H2O"], "produtos": ["CO", "H2"], "resposta": [1, 1, 1, 3]},
		{"nome": "A QUEIMA DO ETANOL",
			"reagentes": ["C2H6O", "O2"], "produtos": ["CO2", "H2O"], "resposta": [1, 3, 2, 3]},
		{"nome": "A QUEIMA DO PROPANO, DO GÁS DE COZINHA",
			"reagentes": ["C3H8", "O2"], "produtos": ["CO2", "H2O"], "resposta": [1, 5, 3, 4]},
		{"nome": "A CHAMA DO MAÇARICO, EM UMA ETAPA SÓ",
			"reagentes": ["C2H2", "O2"], "produtos": ["CO2", "H2O"], "resposta": [2, 5, 4, 2]},
		{"nome": "A AMÔNIA QUEIMANDO: O COMEÇO DOS FERTILIZANTES",
			"reagentes": ["NH3", "O2"], "produtos": ["NO", "H2O"], "resposta": [4, 5, 4, 6]},
		{"nome": "O PAR QUE MOVE AS NAVES NO ESPAÇO",
			"reagentes": ["N2H4", "N2O4"], "produtos": ["N2", "H2O"], "resposta": [2, 1, 3, 4]},
	],
	Nivel.DIFICIL: [
		{"nome": "O FERRO ENFERRUJANDO",
			"reagentes": ["Fe", "O2"], "produtos": ["Fe2O3"], "resposta": [4, 3, 2]},
		{"nome": "O CLORATO DE POTÁSSIO SOLTANDO OXIGÊNIO",
			"reagentes": ["KClO3"], "produtos": ["KCl", "O2"], "resposta": [2, 2, 3]},
		{"nome": "O SÓDIO NA ÁGUA",
			"reagentes": ["Na", "H2O"], "produtos": ["NaOH", "H2"], "resposta": [2, 2, 2, 1]},
		{"nome": "O FILTRO QUE LIMPA O AR DA NAVE",
			"reagentes": ["CO2", "LiOH"], "produtos": ["Li2CO3", "H2O"], "resposta": [1, 2, 1, 1]},
		{"nome": "O ALUMÍNIO NO ÁCIDO CLORÍDRICO",
			"reagentes": ["Al", "HCl"], "produtos": ["AlCl3", "H2"], "resposta": [2, 6, 2, 3]},
		{"nome": "O ALTO-FORNO TIRANDO O FERRO DO MINÉRIO",
			"reagentes": ["Fe2O3", "CO"], "produtos": ["Fe", "CO2"], "resposta": [1, 3, 2, 3]},
		{"nome": "A RESPIRAÇÃO: A GLICOSE QUEIMANDO NO CORPO",
			"reagentes": ["C6H12O6", "O2"], "produtos": ["CO2", "H2O"], "resposta": [1, 6, 6, 6]},
		{"nome": "A CAL E O ÁCIDO FOSFÓRICO",
			"reagentes": ["Ca(OH)2", "H3PO4"], "produtos": ["Ca3(PO4)2", "H2O"], "resposta": [3, 2, 1, 6]},
		{"nome": "O PROPULSOR SÓLIDO DOS FOGUETES",
			"reagentes": ["NH4ClO4", "Al"], "produtos": ["Al2O3", "AlCl3", "NO", "H2O"],
			"resposta": [3, 3, 1, 1, 3, 6]},
	],
}


## As equações de um nível, na ordem em que são pedidas.
static func do_nivel(nivel: Nivel) -> Array:
	return EQUACOES[nivel]


## O nível mostra as moléculas desenhadas?
static func com_moleculas(nivel: Nivel) -> bool:
	return nivel != Nivel.DIFICIL


## O nível mostra a contagem dos átomos de cada lado?
static func com_contagem(nivel: Nivel) -> bool:
	return nivel == Nivel.FACIL
