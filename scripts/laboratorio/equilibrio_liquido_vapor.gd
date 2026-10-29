class_name EquilibrioLiquidoVapor
extends RefCounted

# --- O EQUILÍBRIO ENTRE O LÍQUIDO E O VAPOR (a física da destilação) ---
#
# A conta que as duas colunas de destilação do jogo fazem (a do simulador, em
# scripts/ui/coluna_do_simulador.gd, e a da explicação do Dr. Chico, em
# scripts/ui/coluna_destilacao.gd). Nada aqui desenha.
#
# EVAPORAR NÃO É FERVER. As moléculas da superfície de um líquido estão sempre
# se mexendo, umas mais depressa que as outras, e as mais agitadas escapam: é a
# EVAPORAÇÃO, e ela acontece em QUALQUER temperatura (a roupa seca no varal a
# 25 °C, longe dos 100 °C da água). Ao mesmo tempo, moléculas do vapor batem no
# líquido e ficam: é a CONDENSAÇÃO. Num lugar fechado as duas se equilibram, e a
# pressão que o vapor faz nessa hora é a PRESSÃO DE VAPOR da substância. Ela
# cresce depressa com a temperatura (equação de Antoine, abaixo).
#
# O PONTO DE EBULIÇÃO é só a temperatura em que a pressão de vapor chega na
# pressão de fora (1 atm): daí em diante o vapor se forma também DENTRO do
# líquido, em bolhas. Abaixo dele a evaporação continua, pela superfície.
#
# NUMA MISTURA (lei de Raoult) cada substância evapora na proporção de quanto
# dela há no líquido e da pressão de vapor dela:
#
#     pressão parcial de i  =  aᵢ · Pᵢ(T)        (aᵢ = xᵢ · γᵢ, a "atividade")
#     pressão do líquido    =  Σ aᵢ · Pᵢ(T)      (a mistura FERVE quando passa de 1 atm)
#     vapor que sai          yᵢ = aᵢ · Pᵢ(T) / Σ aⱼ · Pⱼ(T)
#
# Por isso: (1) a mistura ferve numa temperatura ENTRE os pontos de ebulição das
# substâncias (o ar líquido ferve a uns -194 °C: mais quente que o nitrogênio
# puro, mais frio que o oxigênio puro); (2) o vapor tem DE TUDO, só que mais da
# que evapora mais fácil — o vapor do ar líquido sai com uns 94% de nitrogênio
# e 6% de oxigênio, que evapora 11 °C abaixo do ponto de ebulição dele; (3) por
# isso nenhuma destilação dá uma substância 100% pura: cada vez que o vapor
# condensa e evapora de novo (cada bandeja da coluna) ele fica mais rico, mas
# nunca puro.
#
# O QUE O MODELO SABE
#   * Antoine, log₁₀(P/bar) = A − B / (T + C), com T em K, para cada
#     substância ("vapor" em MisturasDoDestilador.SUBSTANCIAS). Os números saem
#     de tabelas de verdade (ver lá de onde veio cada um) e dão o ponto de
#     ebulição de cada uma a menos de meio grau do que ela tem escrito.
#   * Raoult (solução ideal) para quase tudo: o ar, os gases nobres e os
#     hidrocarbonetos se misturam quase sem preferência.
#   * ÁLCOOL E ÁGUA NÃO SÃO IDEAIS: as moléculas de um "empurram" as do outro
#     para fora (γ > 1), e isso cria o AZEÓTROPO: com uns 89% de etanol (em
#     moléculas; 95,6% em massa) o vapor sai igual ao líquido, e daí não se
#     destila mais. É por isso que o álcool da destilação não passa de uns 96%.
#     Coeficientes de Van Laar para etanol-água a 1 atm: A₁₂ = 1,6798 e
#     A₂₁ = 0,9227 (Seader & Henley, Separation Process Principles).
#   * O SAL não evapora (pressão de vapor ~0). Dissolvido, ele separa as
#     moléculas de água (cada NaCl vira dois íons, Na⁺ e Cl⁻) e a água evapora
#     menos: a água salgada ferve acima de 100 °C. Até onde o sal se dissolve:
#     ~0,11 NaCl por molécula de água (36 g em 100 g); o resto fica sólido, sem
#     mudar nada no vapor.
#
# A CONTA É EM MOLÉCULAS: "contas" é um Dictionary {substância: quantas} — as
# moléculas de um líquido. O jogo mostra poucas, mas a conta é a mesma para
# muitas.
#
# AS ESCOLHAS JUSTAS. A coluna precisa decidir, molécula por molécula, QUAL
# evapora (a proporção é a do vapor, yᵢ) e qual transborda (a do líquido). Em
# vez de sortear, ela usa "escolher()": cada substância junta crédito na
# proporção do seu peso e sai a que tem mais. Assim, em 10 moléculas de um
# vapor com 90% de N₂ saem exatamente 9 de N₂ e 1 de outra: a coluna faz sempre
# a mesma coisa, sem sorte nem azar, e na proporção certa.

## 1 atm em bar.
const ATM_EM_BAR := 1.01325
const ZERO_CELSIUS := 273.15
## A pressão de fora da coluna, em atm.
const PRESSAO := 1.0

## Quantos NaCl se dissolvem por molécula de água (6,15 mol/kg × 0,018 kg/mol).
const SOLUBILIDADE_DO_SAL := 0.111
## Os pares de substâncias que se misturam sem ser uma solução ideal: os
## coeficientes de Van Laar (ln γ), na ordem [a do primeiro, a do segundo].
const VAN_LAAR := {
	["C2H6O", "H2O"]: [1.6798, 0.9227],
}

## O ponto de ebulição de um líquido sem nada que evapore (o sal sozinho).
const SEM_EBULICAO := INF


# ─────────────────────────────────────────────────────────────
# UMA SUBSTÂNCIA PURA
# ─────────────────────────────────────────────────────────────

## Se a substância evapora (o sal, não).
static func volatil(chave: String) -> bool:
	return MisturasDoDestilador.substancia(chave).has("vapor")


## A pressão de vapor da substância pura a esta temperatura, em atm (0 para a
## que não evapora). Antoine com T em K; perto do zero absoluto, 0.
static func pressao_de_vapor(chave: String, celsius: float) -> float:
	var dados := MisturasDoDestilador.substancia(chave)
	if not dados.has("vapor"):
		return 0.0
	var antoine: Array = dados["vapor"]
	var kelvin := celsius + ZERO_CELSIUS
	var denominador := kelvin + float(antoine[2])
	if denominador <= 1.0:
		return 0.0
	return pow(10.0, float(antoine[0]) - float(antoine[1]) / denominador) / ATM_EM_BAR


## A "vontade de evaporar" da substância pura (K = P / P de fora): menor que 1,
## abaixo do ponto de ebulição; 1 nele; maior que 1, acima.
static func volatilidade(chave: String, celsius: float) -> float:
	return pressao_de_vapor(chave, celsius) / PRESSAO


## O ponto de ebulição da substância pura que a conta dá (a 1 atm), em °C.
static func ebulicao_pela_conta(chave: String) -> float:
	return temperatura_de_bolha({chave: 1})


# ─────────────────────────────────────────────────────────────
# UMA MISTURA LÍQUIDA
# ─────────────────────────────────────────────────────────────

## As atividades (aᵢ = xᵢ·γᵢ) das substâncias que evaporam, num líquido com
## estas moléculas. É o "quanto de cada uma está na superfície querendo sair".
static func atividades(contas: Dictionary) -> Dictionary:
	var ativ := {}
	# O sal só pesa enquanto está dissolvido: dois íons por NaCl.
	var ions := 2.0 * sal_dissolvido(contas)
	var total := ions
	for chave: String in contas:
		if int(contas[chave]) > 0 and volatil(chave):
			total += float(contas[chave])
	if total <= 0.0:
		return ativ
	for chave: String in contas:
		if int(contas[chave]) > 0 and volatil(chave):
			ativ[chave] = float(contas[chave]) / total
	for par: Array in VAN_LAAR:
		var um := String(par[0])
		var outro := String(par[1])
		if not ativ.has(um) or not ativ.has(outro):
			continue
		var gamas := _van_laar(float(contas[um]) / float(int(contas[um]) + int(contas[outro])), VAN_LAAR[par])
		ativ[um] *= gamas.x
		ativ[outro] *= gamas.y
	return ativ


## Quantos NaCl estão dissolvidos num líquido com estas moléculas: até a
## solubilidade, na água que houver. O resto do sal fica sólido.
static func sal_dissolvido(contas: Dictionary) -> float:
	return minf(float(contas.get("NaCl", 0)), SOLUBILIDADE_DO_SAL * float(contas.get("H2O", 0)))


## Os coeficientes de atividade (γ₁, γ₂) de Van Laar para a fração x₁ do
## primeiro no par.
static func _van_laar(x1: float, a: Array) -> Vector2:
	var a12 := float(a[0])
	var a21 := float(a[1])
	var x2 := 1.0 - x1
	var soma := a12 * x1 + a21 * x2
	if soma <= 0.0:
		return Vector2.ONE
	return Vector2(exp(a12 * pow(a21 * x2 / soma, 2.0)), exp(a21 * pow(a12 * x1 / soma, 2.0)))


## A pressão de vapor da mistura líquida, em atm (Raoult): Σ aᵢ·Pᵢ(T). Passou
## de 1 atm, a mistura ferve.
static func pressao_da_mistura(contas: Dictionary, celsius: float) -> float:
	var soma := 0.0
	var ativ := atividades(contas)
	for chave: String in ativ:
		soma += float(ativ[chave]) * pressao_de_vapor(chave, celsius)
	return soma


## O líquido está acima do ponto de ebulição dele (ferve) a esta temperatura?
static func ferve(contas: Dictionary, celsius: float) -> bool:
	return pressao_da_mistura(contas, celsius) > PRESSAO * 1.0001


## A composição do vapor que sai do líquido a esta temperatura (frações que
## somam 1). Vazio se nada evapora.
static func vapor(contas: Dictionary, celsius: float) -> Dictionary:
	var parciais := {}
	var soma := 0.0
	var ativ := atividades(contas)
	for chave: String in ativ:
		var p := float(ativ[chave]) * pressao_de_vapor(chave, celsius)
		parciais[chave] = p
		soma += p
	if soma <= 0.0:
		return {}
	for chave: String in parciais:
		parciais[chave] = float(parciais[chave]) / soma
	return parciais


## A temperatura em que este líquido ferve (o "ponto de bolha", a 1 atm), em
## °C. SEM_EBULICAO se nada nele evapora.
static func temperatura_de_bolha(contas: Dictionary) -> float:
	if atividades(contas).is_empty():
		return SEM_EBULICAO
	var baixo := -270.0
	var alto := 3000.0
	for i in 60:
		var meio := (baixo + alto) * 0.5
		if pressao_da_mistura(contas, meio) > PRESSAO:
			alto = meio
		else:
			baixo = meio
	return (baixo + alto) * 0.5


## Este líquido (a esta temperatura) ainda recebe uma molécula de "chave" sem
## passar do ponto de ebulição? Num lugar vazio, é a substância pura: ela só
## vira líquido ali se o lugar está no ponto de ebulição dela ou abaixo.
static func cabe(contas: Dictionary, chave: String, celsius: float) -> bool:
	var com := contas.duplicate()
	com[chave] = int(com.get(chave, 0)) + 1
	return pressao_da_mistura(com, celsius) <= PRESSAO * 1.0001


# ─────────────────────────────────────────────────────────────
# AS ESCOLHAS JUSTAS
# ─────────────────────────────────────────────────────────────

## Escolhe uma das chaves de "pesos" (só as de peso > 0), na proporção dos
## pesos, sem sorteio: cada uma junta crédito e sai a que tem mais. "creditos"
## guarda o que sobrou de uma escolha para a outra (é alterado aqui). "" se
## nenhuma tem peso.
static func escolher(pesos: Dictionary, creditos: Dictionary) -> String:
	var soma := 0.0
	for chave: String in pesos:
		soma += maxf(float(pesos[chave]), 0.0)
	if soma <= 0.0:
		return ""
	var escolhida := ""
	for chave: String in pesos:
		var peso := maxf(float(pesos[chave]), 0.0)
		if peso <= 0.0:
			continue
		creditos[chave] = float(creditos.get(chave, 0.0)) + peso / soma
		if escolhida == "" or float(creditos[chave]) > float(creditos[escolhida]):
			escolhida = chave
	creditos[escolhida] = float(creditos[escolhida]) - 1.0
	return escolhida


## As moléculas de um líquido por substância, a partir de uma lista de chaves
## (uma por molécula).
static func contar(tipos: Array) -> Dictionary:
	var contas := {}
	for tipo in tipos:
		contas[tipo] = int(contas.get(tipo, 0)) + 1
	return contas


static func para_celsius(kelvin: float) -> float:
	return kelvin - ZERO_CELSIUS
