class_name PlantaDoMapa
extends RefCounted

# --- O MAPA DO COMPLEXO: O QUE ESTÁ NELE (as salas, as cenas e as passagens) ---
#
# O M abre o caderno da Cacau, e o caderno tem duas abas: CADERNO e MAPA (Q/E
# ou L1/R1 trocam). O mapa é a planta do Centro de Lançamento no esquema das
# fases: cada ÁREA é uma sala retangular desenhada na grade de CÉLULAS do papel
# quadriculado, ligada às vizinhas por PASSAGENS, e a Cacau aparece onde ela
# está. Três peças, como o caderno:
#
#   este arquivo                                  O QUE está no mapa
#   o autoload Caderno (scripts/caderno.gd)       QUANDO: as abas, abrir e fechar
#   FolhaDoMapa (scripts/ui/folha_do_mapa.gd)     COMO: o desenho, e o que ele lê
#                                                 do jogo (onde a Cacau está, o
#                                                 objetivo, o que já foi visitado)
#
# AS ÁREAS (AREAS) — uma linha por sala do mapa:
#   id          o nome interno: é por ele que as cenas e as passagens apontam
#               para a sala
#   nome        o que vem escrito na sala ("FASE CARBONO"). Fica no alto dela
#               (por onde a Cacau anda é embaixo), na letra grande se couber,
#               senão na pequena
#   detalhe     uma linha menor embaixo do nome (opcional)
#   nome_fora   "cima", "direita" ou "esquerda": o nome vai do lado de fora,
#               encostado na sala (opcional; para a sala estreita demais, ou
#               com o trilho no meio, como a torre)
#   cor         a cor da sala, a mesma do esquema das fases
#   caixa       Rect2i(coluna, linha, largura, altura), em células. A coluna 0
#               é a da borda esquerda do mapa, e a linha 0, a de cima
#   elementos   as letras do CHONPS que se conquistam ali (opcional): viram as
#               fichinhas em pé em cima da sala, vazias até a Cacau pegar o
#               elemento
#
# AS CENAS (CENAS) — cada .tscn em que a Cacau anda, e a sala em que ela fica:
#   area        o id da sala. "" = a cena fica fora da planta (o mapa abre,
#               mas sem o "você está aqui")
#   lugar       o nome do lugar dentro da sala, no quadro VOCÊ ESTÁ EM
#               (opcional)
#   trilho      por onde a Cacau anda NO MAPA enquanto anda na cena, em
#               células: a cena inteira é espremida neste retângulo (a ponta
#               esquerda da cena cai na ponta esquerda do trilho). Com altura
#               0, só a posição na horizontal conta; com largura e altura 0, o
#               marcador fica parado no ponto (uma sala pequena dentro de
#               outra). Sem trilho, vale uma linha na parte de baixo da sala
#               (ver RECUO_DO_TRILHO). O trilho fica abaixo do nome da sala
#               (o teste confere)
#   limites     até onde a Cacau anda na cena, em px do mundo (opcional). Sem
#               ele valem o LimitesDaCamera da fase e os andares e zonas de
#               câmera dela (ver FolhaDoMapa.limites_da_cena) — só o world1 e
#               o laboratório, que não têm LimitesDaCamera, precisam dele
#   trechos     para a cena que atravessa mais de uma sala (o subsolo: a ala
#               oeste, o átrio e a ala leste): uma lista, da esquerda para a
#               direita, de {"area", "lugar", "trilho", "ate"}. "ate" é o x
#               (px do mundo) em que o trecho acaba (o último vai até o fim da
#               cena), e cada trecho vale como uma cena à parte, com a sala, o
#               lugar e o trilho dele. A "area" da cena fica sendo a sala por
#               onde se chega a ela. O mapa marca explorada cada sala em que a
#               Cacau pisou (Objetivos.visitou_area)
#
# AS PASSAGENS (PASSAGENS) — o corredor entre duas salas:
#   de, para    os ids das duas salas. Elas ficam lado a lado ou uma em cima
#               da outra, separadas por uma célula (o corredor atravessa o
#               vão) ou encostadas (o corredor vira uma porta na parede)
#   em          onde o corredor passa: a coluna (salas uma em cima da outra) ou
#               a linha (lado a lado), em células. Sem ele, no meio do trecho
#               que as duas salas dividem. O corredor fica perto de onde a
#               porta está de verdade nas cenas (a porta da oficina e o
#               elevador do pátio estão na ponta esquerda da fase 1, por
#               exemplo)
#   requer      a habilidade sem a qual a passagem fica trancada (o cadeado)
#
# OS OBJETIVOS (ONDE_FICA) — o mapa aponta o objetivo da lista do canto
# (scripts/roteiro_objetivos.gd): cada id de objetivo diz em que cena ele se
# cumpre ou, na cena com trechos, [cena, sala]. O losango fica no meio do
# trilho. Cena fora da planta (a Torre de Lançamento) não ganha o losango, mas
# o carimbo diz o nome dela. Objetivo novo no roteiro entra aqui também — o
# teste tools/teste_mapa.tscn avisa quando falta algum.
#
# PARA ACRESCENTAR UMA FASE: a cena nova entra em CENAS, na sala dela (sala
# nova: uma linha em AREAS e as passagens dela em PASSAGENS), e os objetivos
# dela em ONDE_FICA. Sala que a Cacau nunca pisou aparece A EXPLORAR
# (tracejada), com o nome escrito, para guiar quem joga. A Torre de Lançamento
# ainda não tem sala: fica fora da planta. O teste confere se as portas das
# cenas batem com as passagens da planta.

# --- As cores do esquema ---
const CIANO := Color("41b6d3")
const VERMELHO := Color("e0584d")
const CINZA := Color("aab3be")
const VERDE := Color("7cc65b")
const ROXO := Color("b47ad4")

const AREAS: Array[Dictionary] = [
	{"id": "chegada", "nome": "ÁREA 1", "detalhe": "CHEGADA", "cor": CIANO,
		"caixa": Rect2i(0, 7, 7, 3), "elementos": ["H", "O"]},
	{"id": "laboratorio", "nome": "LABORATÓRIO", "cor": VERMELHO, "caixa": Rect2i(8, 7, 7, 3)},
	{"id": "carbono", "nome": "FASE CARBONO", "cor": CINZA, "caixa": Rect2i(8, 3, 7, 3),
		"elementos": ["C"]},
	{"id": "corredor_patio", "nome": "CORREDOR", "cor": CINZA, "caixa": Rect2i(8, 0, 3, 2)},
	{"id": "pirolise", "nome": "ÁREA DE PIRÓLISE", "cor": CINZA, "caixa": Rect2i(12, 0, 3, 2)},
	{"id": "corredor_torre", "nome": "CORREDOR", "cor": CINZA, "caixa": Rect2i(16, 8, 3, 1),
		"nome_fora": "cima"},
	{"id": "nitrogenio", "nome": "FASE NITROGÊNIO", "cor": VERDE, "caixa": Rect2i(20, 7, 7, 3),
		"elementos": ["N"]},
	{"id": "torre", "nome": "TORRE", "cor": VERDE, "caixa": Rect2i(21, 3, 3, 4),
		"nome_fora": "direita"},
	# As alas do subsolo, como na cena: o fósforo a oeste, o enxofre a leste.
	{"id": "subsolo", "nome": "SUBSOLO", "cor": ROXO, "caixa": Rect2i(8, 11, 7, 2)},
	{"id": "fosforo", "nome": "FASE FÓSFORO", "cor": ROXO, "caixa": Rect2i(3, 11, 4, 2),
		"elementos": ["P"]},
	{"id": "enxofre", "nome": "FASE ENXOFRE", "cor": ROXO, "caixa": Rect2i(16, 11, 4, 2),
		"elementos": ["S"]},
]

const WORLD1 := "res://scenes/world1.tscn"
const LAB := "res://scenes/laboratório_(world_2).tscn"
const SIMULADOR := "res://scenes/simulador_(world_3).tscn"
const OFICINA := "res://scenes/fases/fase1_oficina.tscn"
const CORREDOR_PATIO := "res://scenes/fases/corredor_patio.tscn"
const PATIO := "res://scenes/fases/fase1_2_exterior.tscn"
const CORREDOR_TORRE := "res://scenes/fases/corredor_torre.tscn"
const RUA := "res://scenes/fases/fase2_torre.tscn"
const COMPRESSOR := "res://scenes/fases/fase2_sala_compressor.tscn"
const DESTILACAO := "res://scenes/fases/fase2_sala_destilacao.tscn"
const TORRE := "res://scenes/fases/fase2_torre_interior.tscn"
const TELHADO := "res://scenes/fases/fase2_telhado.tscn"
const SUBSOLO := "res://scenes/fases/fase3_subsolo.tscn"
const LANCAMENTO := "res://scenes/fases/fase_final.tscn"

## Os trilhos das salas de 3 linhas passam abaixo do meio (linha + 2,1): o
## nome da sala fica no alto, e a Cacau anda embaixo dele. E todos ficam a 0,75
## célula das paredes: a plaquinha do rosto dela tem 1,3 célula de largura e
## não pode sair da sala.
const CENAS := {
	WORLD1: {"area": "chegada", "trilho": Rect2(0.75, 9.1, 5.5, 0.0),
		"limites": Rect2(0, -900, 7400, 1100)},
	LAB: {"area": "laboratorio", "trilho": Rect2(8.75, 9.1, 5.5, 0.0),
		"limites": Rect2(0, -400, 3584, 700)},
	# A porta do simulador fica a 28% do laboratório.
	SIMULADOR: {"area": "laboratorio", "lugar": "Simulador", "trilho": Rect2(10.3, 9.1, 0.0, 0.0)},
	# A oficina tem andar de cima: o marcador sobe e desce também.
	OFICINA: {"area": "carbono", "lugar": "Oficina do Carbono", "trilho": Rect2(8.75, 4.65, 5.5, 0.85)},
	CORREDOR_PATIO: {"area": "corredor_patio", "trilho": Rect2(8.75, 1.4, 1.5, 0.0)},
	PATIO: {"area": "pirolise", "lugar": "Pátio da Oficina", "trilho": Rect2(12.75, 1.4, 1.5, 0.0)},
	CORREDOR_TORRE: {"area": "corredor_torre", "trilho": Rect2(16.75, 8.5, 1.5, 0.0)},
	RUA: {"area": "nitrogenio", "lugar": "Rua da Torre de Gases", "trilho": Rect2(20.75, 9.1, 5.5, 0.0)},
	# As salas dos prédios da rua ficam onde as portas delas estão na rua.
	COMPRESSOR: {"area": "nitrogenio", "lugar": "Sala do compressor", "trilho": Rect2(20.9, 9.1, 0.8, 0.0)},
	DESTILACAO: {"area": "nitrogenio", "lugar": "Sala de destilação", "trilho": Rect2(23.6, 9.1, 0.8, 0.0)},
	# Oito andares de subida (o térreo embaixo) e, por cima, o telhado.
	TORRE: {"area": "torre", "lugar": "Torre de Gases", "trilho": Rect2(22.5, 4.3, 0.0, 2.2)},
	TELHADO: {"area": "torre", "lugar": "Telhado da torre", "trilho": Rect2(21.75, 3.5, 1.5, 0.0)},
	# O subsolo atravessa três salas: a ala oeste (o fósforo), o átrio central,
	# aonde o fosso de ventilação chega, e a ala leste (o enxofre).
	SUBSOLO: {"area": "subsolo", "trechos": [
		{"area": "fosforo", "lugar": "Ala oeste do subsolo", "ate": 2000.0},
		{"area": "subsolo", "lugar": "Átrio central", "ate": 3400.0},
		{"area": "enxofre", "lugar": "Ala leste do subsolo"},
	]},
	LANCAMENTO: {"area": "", "lugar": "Torre de Lançamento"},
}

const PASSAGENS: Array[Dictionary] = [
	{"de": "chegada", "para": "laboratorio"},
	{"de": "laboratorio", "para": "carbono", "em": 9.5},
	{"de": "carbono", "para": "corredor_patio", "em": 8.5},
	{"de": "corredor_patio", "para": "pirolise"},
	{"de": "laboratorio", "para": "corredor_torre"},
	{"de": "corredor_torre", "para": "nitrogenio"},
	{"de": "nitrogenio", "para": "torre"},
	{"de": "laboratorio", "para": "subsolo", "requer": "mochila"},
	{"de": "subsolo", "para": "enxofre"},
	{"de": "subsolo", "para": "fosforo"},
]

## Em que cena cada objetivo do roteiro se cumpre.
const ONDE_FICA := {
	# Prólogo
	"h2": WORLD1, "o2": WORLD1, "caixa": WORLD1, "computador": WORLD1, "entrar_lab": LAB,
	# Carbono
	"entrar_oficina": OFICINA, "bumerangue": OFICINA, "macarico": OFICINA, "espinhos": OFICINA,
	"porta_metal": OFICINA, "porta_elevador": OFICINA, "patio": PATIO, "carvao": PATIO,
	"entregar_c": LAB,
	# Nitrogênio
	"entrar_torre": RUA, "mochila": DESTILACAO, "cilindro": TELHADO, "comprimir": COMPRESSOR,
	"levar_amostra": DESTILACAO, "destilar": DESTILACAO, "pegar_n": DESTILACAO, "entregar_n": LAB,
	# Enxofre e fósforo: a chegada é no átrio; o resto, nas alas
	"entrar_subsolo": SUBSOLO, "pegar_p": [SUBSOLO, "fosforo"],
	"botas": [SUBSOLO, "enxofre"], "pegar_s": [SUBSOLO, "enxofre"], "entregar_ps": LAB,
	# Torre de Lançamento: a porta fica no laboratório; o resto, fora da planta
	# (sem losango, mas o carimbo diz o nome do lugar)
	"entrar_lancamento": LAB, "purificador": LANCAMENTO, "embarque": LANCAMENTO,
}

## O trilho padrão (cena sem "trilho"): uma linha deitada a 70% da altura da
## sala (o nome fica no alto; na sala de uma linha só, no meio), recuada isto
## das paredes, em células — a plaquinha do rosto não sai da sala.
const RECUO_DO_TRILHO := 0.75


# ─────────────────────────────────────────────────────────────
# CONSULTAS
# ─────────────────────────────────────────────────────────────

## A sala com este id ({} se não existir).
static func area(id: String) -> Dictionary:
	for dados in AREAS:
		if dados["id"] == id:
			return dados
	return {}


## O id da sala da cena ("" = fora da planta, ou cena desconhecida). Na cena
## com trechos, a sala por onde se chega a ela (ver trecho()).
static func area_da_cena(cena: String) -> String:
	return String(CENAS.get(cena, {}).get("area", ""))


## Todas as salas por onde a cena passa (uma só, na cena sem trechos).
static func areas_da_cena(cena: String) -> PackedStringArray:
	var lista := PackedStringArray()
	for pedaco in trechos(cena):
		if not pedaco["area"].is_empty() and not pedaco["area"] in lista:
			lista.append(pedaco["area"])
	return lista


## A cena atravessa mais de uma sala ("trechos" em CENAS)?
static func tem_trechos(cena: String) -> bool:
	return CENAS.get(cena, {}).has("trechos")


## Os trechos da cena, cada um já com o trilho dele: {"area", "lugar",
## "trilho", "ate"} ("ate" = INF no último). A cena sem trechos é um trecho
## só, a cena inteira; a cena desconhecida não tem nenhum.
static func trechos(cena: String) -> Array[Dictionary]:
	var dados: Dictionary = CENAS.get(cena, {})
	var lista: Array[Dictionary] = []
	if dados.is_empty():
		return lista
	for pedaco: Dictionary in dados.get("trechos", [dados]):
		var id := String(pedaco.get("area", ""))
		lista.append({"area": id, "lugar": String(pedaco.get("lugar", "")),
			"trilho": pedaco.get("trilho", trilho_padrao(id)), "ate": float(pedaco.get("ate", INF))})
	return lista


## O trecho da cena em que fica o x (px do mundo); sem x (INF), o da sala por
## onde se chega. {} se a cena não estiver nas CENAS.
static func trecho(cena: String, x: float = INF) -> Dictionary:
	var lista := trechos(cena)
	var i := _indice_do_trecho(cena, lista, x)
	return lista[i] if i >= 0 else {}


## Quantas colunas e linhas a planta ocupa.
static func tamanho() -> Vector2i:
	var fim := Vector2i.ZERO
	for dados in AREAS:
		fim = fim.max((dados["caixa"] as Rect2i).end)
	return fim


## Por onde a Cacau anda no mapa nesta cena, em células (ver CENAS); na cena
## com trechos, o trilho do trecho por onde se chega.
static func trilho_da_cena(cena: String) -> Rect2:
	return trecho(cena).get("trilho", Rect2())


## O trilho de uma cena sem "trilho" na sala "id" (ver RECUO_DO_TRILHO).
## Rect2() se a sala não existir.
static func trilho_padrao(id: String) -> Rect2:
	var sala := area(id)
	if sala.is_empty():
		return Rect2()
	var caixa := Rect2(sala["caixa"])
	var altura := caixa.size.y * (0.7 if caixa.size.y >= 2.0 else 0.5)
	return Rect2(caixa.position.x + RECUO_DO_TRILHO, caixa.position.y + altura,
		caixa.size.x - RECUO_DO_TRILHO * 2.0, 0.0)


## Onde a Cacau está no mapa, em células: a posição dela na cena ("posicao",
## px do mundo) espremida de "limites" para o trilho do trecho em que ela
## está (na horizontal, o trecho vai do fim do anterior até o "ate" dele). Sem
## posição ou sem limites, o meio do trilho. Vector2.INF se a cena não está na
## planta.
static func ponto_no_mapa(cena: String, posicao: Vector2 = Vector2.INF,
		limites: Rect2 = Rect2()) -> Vector2:
	var lista := trechos(cena)
	var i := _indice_do_trecho(cena, lista, posicao.x if posicao.is_finite() else INF)
	if i < 0 or String(lista[i]["area"]).is_empty():
		return Vector2.INF
	var trilho: Rect2 = lista[i]["trilho"]
	if not posicao.is_finite():
		return trilho.get_center()
	var de := limites.position.x if i == 0 else float(lista[i - 1]["ate"])
	var ate := float(lista[i]["ate"]) if i < lista.size() - 1 else limites.end.x
	var fracao := Vector2(0.5, 0.5)
	if ate > de:
		fracao.x = clampf((posicao.x - de) / (ate - de), 0.0, 1.0)
	if limites.size.y > 0.0:
		fracao.y = clampf((posicao.y - limites.position.y) / limites.size.y, 0.0, 1.0)
	return trilho.position + trilho.size * fracao


## O meio do trilho da sala "id" nesta cena, onde fica o losango de um
## objetivo. Vector2.INF se a cena não passa pela sala.
static func meio_do_trilho(cena: String, id: String) -> Vector2:
	if id.is_empty():
		return Vector2.INF
	for pedaco in trechos(cena):
		if pedaco["area"] == id:
			return (pedaco["trilho"] as Rect2).get_center()
	return Vector2.INF


## Onde o objetivo se cumpre (ver ONDE_FICA): {"cena", "area"}, com a sala do
## trecho dele ou, sem trecho, a da cena. {} se o ONDE_FICA não o conhece.
static func lugar_do_objetivo(id: String) -> Dictionary:
	var valor: Variant = ONDE_FICA.get(id)
	if valor is String:
		return {"cena": valor, "area": area_da_cena(valor)}
	if valor is Array and valor.size() == 2:
		return {"cena": String(valor[0]), "area": String(valor[1])}
	return {}


## O índice do trecho em que fica o x (px do mundo); sem x (INF), o da sala
## por onde se chega à cena. -1 sem trechos (cena desconhecida).
static func _indice_do_trecho(cena: String, lista: Array[Dictionary], x: float) -> int:
	if lista.is_empty():
		return -1
	if is_inf(x) or is_nan(x):
		var entrada := area_da_cena(cena)
		for i in lista.size():
			if lista[i]["area"] == entrada:
				return i
		return 0
	for i in lista.size():
		if x < float(lista[i]["ate"]):
			return i
	return lista.size() - 1


## O traço de uma passagem, em células: {"de", "ate"} são as duas pontas da
## linha do meio dele, uma na parede de cada sala (iguais = salas encostadas:
## o traço é a porta na parede), e "deitado" diz se ele corre na horizontal.
## Vazio se as duas salas não estiverem lado a lado nem uma em cima da outra.
static func traco(passagem: Dictionary) -> Dictionary:
	var a := area(String(passagem.get("de", "")))
	var b := area(String(passagem.get("para", "")))
	if a.is_empty() or b.is_empty():
		return {}
	var ca := Rect2(a["caixa"])
	var cb := Rect2(b["caixa"])
	# Lado a lado: uma termina antes da outra começar, e as duas dividem linhas.
	var esquerda := ca if ca.position.x <= cb.position.x else cb
	var direita := cb if esquerda == ca else ca
	var de_y := maxf(ca.position.y, cb.position.y)
	var ate_y := minf(ca.end.y, cb.end.y)
	if esquerda.end.x <= direita.position.x and ate_y > de_y:
		var y := float(passagem.get("em", (de_y + ate_y) * 0.5))
		if y <= de_y or y >= ate_y:
			return {}
		return {"de": Vector2(esquerda.end.x, y), "ate": Vector2(direita.position.x, y), "deitado": true}
	# Uma em cima da outra.
	var cima := ca if ca.position.y <= cb.position.y else cb
	var baixo := cb if cima == ca else ca
	var de_x := maxf(ca.position.x, cb.position.x)
	var ate_x := minf(ca.end.x, cb.end.x)
	if cima.end.y <= baixo.position.y and ate_x > de_x:
		var x := float(passagem.get("em", (de_x + ate_x) * 0.5))
		if x <= de_x or x >= ate_x:
			return {}
		return {"de": Vector2(x, cima.end.y), "ate": Vector2(x, baixo.position.y), "deitado": false}
	return {}


## As salas ligadas a esta por uma passagem.
static func vizinhas(id: String) -> PackedStringArray:
	var lista := PackedStringArray()
	for passagem in PASSAGENS:
		if passagem["de"] == id:
			lista.append(passagem["para"])
		elif passagem["para"] == id:
			lista.append(passagem["de"])
	return lista


## Há passagem entre as duas salas (em qualquer sentido)?
static func ligadas(a: String, b: String) -> bool:
	return b in vizinhas(a)
