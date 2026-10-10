class_name EquacaoQuimica
extends RefCounted

# --- A CONTA DE UMA EQUAÇÃO QUÍMICA ---
#
# O que o balanceamento do Laboratório precisa saber de uma equação, sem tela
# nenhuma: quantos átomos de cada elemento há numa fórmula, se os dois lados
# batem com os coeficientes escolhidos e como a fórmula se escreve (o que é
# letra e o que é índice, que vai pequeno e rebaixado).
#
#   EquacaoQuimica.composicao("C2H6O")     {"C": 2, "H": 6, "O": 1}
#   EquacaoQuimica.composicao("Ca(OH)2")   {"Ca": 1, "O": 2, "H": 2}
#   EquacaoQuimica.balanceada(["H2", "O2"], ["H2O"], [2, 1, 2])   true
#
# As fórmulas são escritas sem enfeite, como nos puzzles da história: a letra
# maiúscula começa um elemento, a minúscula continua, o número depois é o
# índice. Aqui valem também os parênteses, que multiplicam o que está dentro:
# Ca3(PO4)2 tem 2 fósforos e 8 oxigênios.
#
# VALE QUALQUER RESPOSTA BALANCEADA, como no puzzle do maçarico: se todos os
# átomos batem, está certo, ainda que com os coeficientes em dobro.
# "forma_mais_simples" dá os menores números inteiros da mesma resposta.

## Os átomos de cada elemento numa fórmula (elemento -> quantidade), na ordem
## em que aparecem. Fórmula malformada devolve o que deu para ler.
static func composicao(formula: String) -> Dictionary:
	var lido := _ler_grupo(formula, 0)
	return lido["atomos"]


## Os elementos que aparecem nestas fórmulas, na ordem em que aparecem.
static func elementos(formulas: Array) -> Array[String]:
	var lista: Array[String] = []
	for formula: String in formulas:
		for elemento: String in composicao(formula):
			if not elemento in lista:
				lista.append(elemento)
	return lista


## Os átomos de cada elemento em "formulas", cada uma multiplicada pelo
## coeficiente dela.
static func contar(formulas: Array, coeficientes: Array) -> Dictionary:
	var contagem := {}
	for i in formulas.size():
		var atomos := composicao(String(formulas[i]))
		for elemento: String in atomos:
			contagem[elemento] = int(contagem.get(elemento, 0)) + int(coeficientes[i]) * int(atomos[elemento])
	return contagem


## Os dois lados têm os mesmos átomos? "coeficientes" vem na ordem dos
## reagentes e depois dos produtos; com algum zero, não está balanceada.
static func balanceada(reagentes: Array, produtos: Array, coeficientes: Array) -> bool:
	if coeficientes.size() != reagentes.size() + produtos.size():
		return false
	for valor in coeficientes:
		if int(valor) <= 0:
			return false
	return contar(reagentes, coeficientes.slice(0, reagentes.size())) \
		== contar(produtos, coeficientes.slice(reagentes.size()))


## Os elementos que não batem com estes coeficientes, na ordem em que aparecem.
static func desbalanceados(reagentes: Array, produtos: Array, coeficientes: Array) -> Array[String]:
	var de_um_lado := contar(reagentes, coeficientes.slice(0, reagentes.size()))
	var do_outro := contar(produtos, coeficientes.slice(reagentes.size()))
	var lista: Array[String] = []
	for elemento in elementos(reagentes + produtos):
		if int(de_um_lado.get(elemento, 0)) != int(do_outro.get(elemento, 0)):
			lista.append(elemento)
	return lista


## Os coeficientes divididos pelo maior divisor comum a todos (2-2-4-2 -> 1-1-2-1).
static func forma_mais_simples(valores: Array) -> Array[int]:
	var divisor := 0
	for valor in valores:
		var a := divisor
		var b := int(valor)
		while b != 0:
			var resto := a % b
			a = b
			b = resto
		divisor = a
	var saida: Array[int] = []
	for valor in valores:
		@warning_ignore("integer_division")
		saida.append(int(valor) / maxi(divisor, 1))
	return saida


## A fórmula em pedaços para escrever: [[texto, é índice], ...]. "Ca(OH)2" vira
## [["Ca(OH)", false], ["2", true]].
static func pedacos(formula: String) -> Array:
	var lista: Array = []
	var atual := ""
	var numero := false
	for letra in formula:
		var e_numero := letra.is_valid_int()
		if atual != "" and e_numero != numero:
			lista.append([atual, numero])
			atual = ""
		atual += letra
		numero = e_numero
	if atual != "":
		lista.append([atual, numero])
	return lista


## A equação numa linha de texto, para o registro e para os testes:
## "2 H2 + O2 -> 2 H2O". O coeficiente 1 não se escreve.
static func escrita(reagentes: Array, produtos: Array, coeficientes: Array) -> String:
	var lados := PackedStringArray()
	var k := 0
	for lado: Array in [reagentes, produtos]:
		var termos := PackedStringArray()
		for formula: String in lado:
			var coeficiente := int(coeficientes[k])
			termos.append(formula if coeficiente == 1 else "%d %s" % [coeficiente, formula])
			k += 1
		lados.append(" + ".join(termos))
	return " -> ".join(lados)


# ─────────────────────────────────────────────────────────────
# LEITURA DA FÓRMULA
# ─────────────────────────────────────────────────────────────

## Lê um grupo da fórmula a partir de "i": até o fim, ou até o parêntese que o
## fecha. Devolve {"atomos": {elemento: quantidade}, "fim": onde parou}.
static func _ler_grupo(formula: String, i: int) -> Dictionary:
	var atomos := {}
	while i < formula.length():
		var letra := formula[i]
		if letra == ")":
			break
		if letra == "(":
			var dentro := _ler_grupo(formula, i + 1)
			# Depois do parêntese que fecha, o número que multiplica o grupo.
			var numero := _ler_numero(formula, int(dentro["fim"]) + 1)
			for elemento: String in dentro["atomos"]:
				atomos[elemento] = int(atomos.get(elemento, 0)) + int(dentro["atomos"][elemento]) * int(numero["valor"])
			i = int(numero["fim"])
			continue
		if letra != letra.to_upper() or letra.is_valid_int():
			# Uma minúscula ou um número solto, sem elemento antes: pula.
			i += 1
			continue
		var elemento := letra
		i += 1
		while i < formula.length() and formula[i] != formula[i].to_upper() and not formula[i].is_valid_int():
			elemento += formula[i]
			i += 1
		var indice := _ler_numero(formula, i)
		atomos[elemento] = int(atomos.get(elemento, 0)) + int(indice["valor"])
		i = int(indice["fim"])
	return {"atomos": atomos, "fim": i}


## O número escrito a partir de "i" (1 se não há número ali).
static func _ler_numero(formula: String, i: int) -> Dictionary:
	var texto := ""
	while i < formula.length() and formula[i].is_valid_int():
		texto += formula[i]
		i += 1
	return {"valor": int(texto) if texto != "" else 1, "fim": i}
