extends "res://tools/teste_de_tela.gd"

# Teste do balanceamento de equações do Laboratório: a conta
# (scripts/laboratorio/equacao_quimica.gd), as equações de cada nível
# (equacoes_do_laboratorio.gd) e a tela (scenes/laboratorio/balanceamento.tscn),
# jogada com o mouse de verdade.
#
#   * a conta: os átomos de uma fórmula (com índices e parênteses), se os dois
#     lados batem, que elemento sobra e a forma mais simples de uma resposta;
#   * as equações: toda resposta escrita balanceia de verdade, é a mais simples
#     e cabe nas setas (até 9); nas equações de até quatro termos, TODA
#     resposta balanceada que as setas alcançam é múltipla dela; nenhuma
#     equação se repete; no fácil e no médio toda fórmula tem desenho;
#   * a tela de escolha mostra os três níveis;
#   * FÁCIL é como os puzzles da história: as moléculas aparecem conforme o
#     coeficiente e a contagem dos átomos fica verde quando bate;
#   * a arrumação dos níveis com moléculas: a contagem dos átomos no alto, a
#     equação escrita embaixo dela e, embaixo da equação, os desenhos — cada
#     termo escrito centrado em cima da coluna da molécula dele, o "+" e a seta
#     em cima dos vãos;
#   * MÉDIO tem as moléculas e não tem a contagem, e nada muda de cor antes de
#     confirmar;
#   * DIFÍCIL é só a equação escrita, com um seletor em cada coeficiente;
#   * confirmar sem definir tudo pede os coeficientes; errado, o rodapé diz
#     que elemento não bate; certo, passa (inclusive em dobro, mostrando a
#     forma mais simples); PULAR mostra a resposta e não conta;
#   * as setas dão a volta (9 -> 0 e 0 -> 9);
#   * em todas as equações dos três níveis, com os coeficientes no máximo, nada
#     sai do area, as setas não se cobrem e as moléculas cabem no lugar;
#   * os três níveis se resolvem até o fim, clicando; o fim diz quantas foram
#     balanceadas e quantas confirmações saíram erradas;
#   * ESC no meio volta à escolha do nível e, de lá, ao Laboratório.
#
#   godot --headless --path . res://tools/teste_balanceamento.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma imagem de cada
# momento.

const CENA := "res://scenes/laboratorio/balanceamento.tscn"
const EquacaoSobreColunas := preload("res://scripts/ui/equacao_sobre_colunas.gd")
const NIVEIS := [EquacoesDoLaboratorio.Nivel.FACIL, EquacoesDoLaboratorio.Nivel.MEDIO, EquacoesDoLaboratorio.Nivel.DIFICIL]
## O jogo anda mais depressa enquanto o teste espera a equação seguinte.
const PRESSA := 8.0


func _ready() -> void:
	await _comecar()
	_testar_a_conta()
	_testar_as_equacoes()
	await _testar_a_escolha()
	await _testar_o_facil()
	await _testar_o_medio()
	await _testar_o_dificil()
	await _testar_o_layout()
	await _testar_os_niveis_inteiros()
	await _testar_o_controle()
	await _testar_a_saida()
	_terminar()


# ─────────────────────────────────────────────────────────────
# APOIO
# ─────────────────────────────────────────────────────────────

## O que a linha da equação (níveis com moléculas) está escrevendo, peça por
## peça: "2 H2 + ? O2 → ? H2O".
func _linha_escrita(tela: TelaInterativa) -> String:
	return EquacaoSobreColunas.texto(tela.linha_equacao)


## A cor em que a equação está escrita.
func _cor_da_linha(tela: TelaInterativa) -> Color:
	return EquacaoSobreColunas.cor(tela.linha_equacao)


## A arrumação dos níveis com moléculas, de cima para baixo: a contagem dos
## átomos, a equação escrita e os desenhos — com cada termo escrito em cima da
## coluna da molécula dele e os operadores em cima dos vãos. Devolve o que
## estiver fora do lugar (vazio = tudo certo).
func _fora_da_arrumacao(tela: TelaInterativa) -> PackedStringArray:
	var problemas := PackedStringArray()
	var linha: Control = tela.linha_equacao
	var faixa := linha.get_global_rect()
	var titulo: Rect2 = tela.reagentes_titulo.get_global_rect()
	if titulo.end.y > faixa.position.y + 0.5:
		problemas.append("os títulos Reagentes/Produtos não estão acima da equação")
	if tela.reagentes_valor.visible and tela.reagentes_valor.get_global_rect().end.y > faixa.position.y + 0.5:
		problemas.append("a contagem dos átomos não está acima da equação")
	if tela.reagentes_valor.visible and tela.reagentes_valor.get_global_rect().position.y < titulo.end.y - 0.5:
		problemas.append("a contagem por cima do título")
	if EquacaoSobreColunas.quantos_termos(linha) != tela._termos.size():
		problemas.append("%d termos escritos para %d colunas" % [EquacaoSobreColunas.quantos_termos(linha), tela._termos.size()])
		return problemas
	for i in tela._termos.size():
		var coluna: TermoEquacao = tela._termos[i]
		var escrito := EquacaoSobreColunas.retangulo_do_termo(linha, i)
		var seta: Rect2 = coluna.retangulo_do_botao(1)
		if escrito.end.y > coluna.botao_mais.get_global_rect().position.y + 0.5:
			problemas.append("o termo %s escrito não está acima da coluna dele" % coluna.formula)
		if absf(EquacaoSobreColunas.meio_do_termo(linha, i) - seta.get_center().x) > 1.5:
			problemas.append("o termo %s escrito não está centrado na coluna (%.1f x %.1f)" \
				% [coluna.formula, EquacaoSobreColunas.meio_do_termo(linha, i), seta.get_center().x])
		if escrito.size.x > coluna.get_global_rect().size.x + tela.FOLGA_DO_TERMO * coluna.get_global_transform().get_scale().x + 0.5:
			problemas.append("o termo %s escrito é mais largo que a coluna" % coluna.formula)
	if EquacaoSobreColunas.menor_folga(linha) < 0.0:
		problemas.append("uma peça da equação por cima da vizinha (%.1f)" % EquacaoSobreColunas.menor_folga(linha))
	var extensao := EquacaoSobreColunas.extensao(linha)
	if extensao.x < 0.0 or extensao.y > linha.size.x:
		problemas.append("a equação escrita sai da linha dela (%s)" % extensao)
	return problemas


## A equação do nível difícil como está escrita: os números dos seletores e as
## fórmulas, na ordem.
func _escrita_do_dificil(tela: TelaInterativa) -> String:
	var partes := PackedStringArray()
	for filho in tela.termos.get_children():
		if filho is SeletorCoeficiente:
			partes.append(filho.numero.text)
		elif filho is Label:
			partes.append(filho.text)
		elif filho is HBoxContainer:
			var formula := ""
			for letra: Label in filho.get_children():
				formula += letra.text
			partes.append(formula)
	return " ".join(partes)


## Clica nas setas de cima até cada coeficiente chegar ao valor pedido.
func _por_coeficientes(tela: TelaInterativa, valores: Array) -> void:
	for i in valores.size():
		while tela.coeficientes[i] != int(valores[i]) or not tela.tocado[i]:
			await _clicar(tela, "mais_%d" % i)


## Espera a tela sair de PASSANDO (a equação seguinte, ou o fim do nível).
func _esperar_a_proxima(tela: TelaInterativa) -> bool:
	Engine.time_scale = PRESSA
	var chegou := await _esperar_ate(func() -> bool: return tela.estado != tela.Estado.PASSANDO, 6.0)
	Engine.time_scale = 1.0
	await _quadros(2)
	return chegou


# ─────────────────────────────────────────────────────────────
# A CONTA
# ─────────────────────────────────────────────────────────────

func _testar_a_conta() -> void:
	print("\n--- A CONTA (EquacaoQuimica) ---")
	var casos := {
		"H2O": {"H": 2, "O": 1},
		"C2H6O": {"C": 2, "H": 6, "O": 1},
		"CO": {"C": 1, "O": 1},
		"Co": {"Co": 1},
		"NaCl": {"Na": 1, "Cl": 1},
		"C6H12O6": {"C": 6, "H": 12, "O": 6},
		"Ca(OH)2": {"Ca": 1, "O": 2, "H": 2},
		"Ca3(PO4)2": {"Ca": 3, "P": 2, "O": 8},
		"NH4ClO4": {"N": 1, "H": 4, "Cl": 1, "O": 4},
		"Al2(SO4)3": {"Al": 2, "S": 3, "O": 12},
		"Mg(OH)(NO3)": {"Mg": 1, "O": 4, "H": 1, "N": 1},
		"Fe": {"Fe": 1},
		"": {},
	}
	var errados := PackedStringArray()
	for formula: String in casos:
		if EquacaoQuimica.composicao(formula) != casos[formula]:
			errados.append("%s -> %s" % [formula, EquacaoQuimica.composicao(formula)])
	_checar(errados.is_empty(), "os átomos de cada fórmula, com índices e parênteses %s" % [errados])
	_checar(EquacaoQuimica.composicao("C2H6O").keys() == ["C", "H", "O"], "os elementos saem na ordem em que aparecem")
	_checar(EquacaoQuimica.composicao("2H").is_empty() or EquacaoQuimica.composicao("2H") == {"H": 1},
		"um número solto antes do elemento não quebra a leitura")
	_checar(EquacaoQuimica.elementos(["CH4", "O2", "CO2", "H2O"]) == ["C", "H", "O"], "os elementos de uma equação: C, H, O")
	_checar(EquacaoQuimica.contar(["H2", "O2"], [2, 1]) == {"H": 4, "O": 2}, "2 H2 + 1 O2 têm 4 H e 2 O")

	_checar(EquacaoQuimica.balanceada(["H2", "O2"], ["H2O"], [2, 1, 2]), "2 H2 + O2 -> 2 H2O está balanceada")
	_checar(EquacaoQuimica.balanceada(["H2", "O2"], ["H2O"], [4, 2, 4]), "em dobro também (4-2-4)")
	_checar(not EquacaoQuimica.balanceada(["H2", "O2"], ["H2O"], [1, 1, 1]), "1-1-1 não está")
	_checar(not EquacaoQuimica.balanceada(["H2", "O2"], ["H2O"], [0, 0, 0]), "tudo zero não é resposta")
	_checar(not EquacaoQuimica.balanceada(["H2", "O2"], ["H2O"], [2, 1]), "nem faltando coeficiente")
	_checar(EquacaoQuimica.desbalanceados(["H2", "O2"], ["H2O"], [1, 1, 1]) == ["O"], "em 1-1-1 quem não bate é o O")
	_checar(EquacaoQuimica.desbalanceados(["CH4", "O2"], ["CO2", "H2O"], [1, 1, 1, 1]) == ["H", "O"],
		"em CH4 + O2 -> CO2 + H2O com 1-1-1-1, o H e o O")
	_checar(EquacaoQuimica.desbalanceados(["CH4", "O2"], ["CO2", "H2O"], [1, 2, 1, 2]).is_empty(), "com 1-2-1-2, nenhum")

	_checar(EquacaoQuimica.forma_mais_simples([2, 2, 4, 2]) == [1, 1, 2, 1] and EquacaoQuimica.forma_mais_simples([4, 2, 4]) == [2, 1, 2],
		"a forma mais simples: 2-2-4-2 vira 1-1-2-1; 4-2-4 vira 2-1-2")
	_checar(EquacaoQuimica.forma_mais_simples([3, 5]) == [3, 5] and EquacaoQuimica.forma_mais_simples([6, 9, 3]) == [2, 3, 1] \
		and EquacaoQuimica.forma_mais_simples([0, 0]) == [0, 0], "3-5 já é a mais simples; 6-9-3 vira 2-3-1; zeros não quebram")
	_checar(EquacaoQuimica.pedacos("Ca(OH)2") == [["Ca(OH)", false], ["2", true]] \
		and EquacaoQuimica.pedacos("C6H12O6") == [["C", false], ["6", true], ["H", false], ["12", true], ["O", false], ["6", true]] \
		and EquacaoQuimica.pedacos("Fe") == [["Fe", false]], "a fórmula em pedaços: o que é letra e o que é índice")
	_checar(EquacaoQuimica.escrita(["H2", "O2"], ["H2O"], [2, 1, 2]) == "2 H2 + O2 -> 2 H2O", "a equação por extenso: 2 H2 + O2 -> 2 H2O")


func _testar_as_equacoes() -> void:
	print("\n--- AS EQUAÇÕES DE CADA NÍVEL ---")
	var coef_max: int = (load("res://scripts/laboratorio/balanceamento.gd") as Script).get_script_constant_map()["COEF_MAX"]
	_checar(coef_max == 9, "as setas vão até 9")
	_checar(EquacoesDoLaboratorio.com_moleculas(NIVEIS[0]) and EquacoesDoLaboratorio.com_contagem(NIVEIS[0]),
		"fácil: com as moléculas e com a contagem")
	_checar(EquacoesDoLaboratorio.com_moleculas(NIVEIS[1]) and not EquacoesDoLaboratorio.com_contagem(NIVEIS[1]),
		"médio: com as moléculas, sem a contagem")
	_checar(not EquacoesDoLaboratorio.com_moleculas(NIVEIS[2]) and not EquacoesDoLaboratorio.com_contagem(NIVEIS[2]),
		"difícil: sem moléculas e sem contagem")

	var problemas := PackedStringArray()
	var vistas := {}
	var textos: Array = []
	var maior_coeficiente := 0
	var conferidas_a_fundo := 0
	for nivel: EquacoesDoLaboratorio.Nivel in NIVEIS:
		var fila := EquacoesDoLaboratorio.do_nivel(nivel)
		var nome_do_nivel: String = EquacoesDoLaboratorio.NOMES[nivel]
		textos.append_array([nome_do_nivel, EquacoesDoLaboratorio.DESCRICOES[nivel]])
		if fila.size() < 5:
			problemas.append("%s tem só %d equações" % [nome_do_nivel, fila.size()])
		for equacao: Dictionary in fila:
			var reagentes: Array = equacao["reagentes"]
			var produtos: Array = equacao["produtos"]
			var resposta: Array = equacao["resposta"]
			var escrita := EquacaoQuimica.escrita(reagentes, produtos, resposta)
			textos.append(equacao["nome"])
			textos.append_array(reagentes + produtos)
			if String(equacao["nome"]).is_empty() or reagentes.is_empty() or produtos.is_empty():
				problemas.append("%s: incompleta" % escrita)
			if not EquacaoQuimica.balanceada(reagentes, produtos, resposta):
				problemas.append("%s: a resposta NÃO balanceia" % escrita)
			if EquacaoQuimica.forma_mais_simples(resposta) != resposta:
				problemas.append("%s: a resposta não é a mais simples" % escrita)
			for valor: int in resposta:
				maior_coeficiente = maxi(maior_coeficiente, valor)
				if valor < 1 or valor > coef_max:
					problemas.append("%s: coeficiente %d fora das setas" % [escrita, valor])
			# Os mesmos elementos dos dois lados (senão não há como balancear).
			if EquacaoQuimica.elementos(reagentes) != EquacaoQuimica.elementos(reagentes + produtos) \
					or EquacaoQuimica.elementos(produtos).size() != EquacaoQuimica.elementos(reagentes).size():
				problemas.append("%s: elemento que só existe de um lado" % escrita)
			var chave := "%s>%s" % [",".join(PackedStringArray(reagentes)), ",".join(PackedStringArray(produtos))]
			if vistas.has(chave):
				problemas.append("%s: repetida" % escrita)
			vistas[chave] = true
			if EquacoesDoLaboratorio.com_moleculas(nivel):
				for formula: String in reagentes + produtos:
					if not FolhaMoleculas.tem(formula) or FolhaMoleculas.textura(formula) == null:
						problemas.append("%s: %s não tem desenho" % [escrita, formula])
			# Até quatro termos dá para olhar TODAS as respostas que as setas
			# alcançam: as que balanceiam têm de ser múltiplas da resposta escrita.
			if resposta.size() <= 4:
				conferidas_a_fundo += 1
				if not _so_multiplas(reagentes, produtos, resposta, coef_max):
					problemas.append("%s: há outra resposta que não é múltipla dela" % escrita)
	_checar(problemas.is_empty(), "as %d equações: resposta certa, a mais simples, dentro das setas, sem repetição %s" \
		% [vistas.size(), problemas])
	_checar(conferidas_a_fundo >= vistas.size() - 1, "em %d delas, toda resposta balanceada (de 1 a 9) é múltipla da escrita" \
		% conferidas_a_fundo)
	_checar(maior_coeficiente >= 6, "há equações de coeficiente alto (até %d)" % maior_coeficiente)
	_checar(_letras_que_faltam(textos).is_empty(), "toda letra dos nomes e das fórmulas existe na fonte [%s]" \
		% _letras_que_faltam(textos))
	_checar(EquacoesDoLaboratorio.do_nivel(NIVEIS[0])[0]["reagentes"] == ["H2", "O2"] \
		and EquacoesDoLaboratorio.do_nivel(NIVEIS[0])[0]["produtos"] == ["H2O"],
		"o fácil começa pela equação do foguete da história: H2 + O2 -> H2O")
	var do_macarico := false
	for equacao: Dictionary in EquacoesDoLaboratorio.do_nivel(NIVEIS[1]):
		if "C2H2" in (equacao["reagentes"] as Array):
			do_macarico = true
	_checar(do_macarico, "e o médio tem a chama do maçarico (C2H2)")


## Toda combinação de coeficientes de 1 a "maximo" que balanceia é múltipla da
## resposta? (Só para equações de até quatro termos.)
func _so_multiplas(reagentes: Array, produtos: Array, resposta: Array, maximo: int) -> bool:
	# Os átomos de cada termo, uma vez só: reagentes somam, produtos tiram.
	var elementos := EquacaoQuimica.elementos(reagentes + produtos)
	var termos: Array = []
	for i in reagentes.size() + produtos.size():
		var formula := String((reagentes + produtos)[i])
		var atomos := EquacaoQuimica.composicao(formula)
		var linha := PackedInt32Array()
		for elemento in elementos:
			linha.append(int(atomos.get(elemento, 0)) * (1 if i < reagentes.size() else -1))
		termos.append(linha)
	var n := termos.size()
	var coeficientes := PackedInt32Array()
	coeficientes.resize(n)
	coeficientes.fill(1)
	while true:
		var bate := true
		for e in elementos.size():
			var soma := 0
			for i in n:
				soma += coeficientes[i] * (termos[i] as PackedInt32Array)[e]
			if soma != 0:
				bate = false
				break
		if bate and EquacaoQuimica.forma_mais_simples(Array(coeficientes)) != resposta:
			return false
		# O próximo, como um hodômetro.
		var k := 0
		while k < n:
			coeficientes[k] += 1
			if coeficientes[k] <= maximo:
				break
			coeficientes[k] = 1
			k += 1
		if k >= n:
			return true
	return true


# ─────────────────────────────────────────────────────────────
# A TELA
# ─────────────────────────────────────────────────────────────

func _testar_a_escolha() -> void:
	print("\n--- A ESCOLHA DO NÍVEL ---")
	var tela := await _abrir(CENA)
	await _esperar(0.4)
	_checar(tela.titulo == "BALANCEAMENTO" and tela.cena_de_volta == TransicaoDeCena.CENA_LABORATORIO,
		"o título é BALANCEAMENTO, e ESC leva ao Laboratório")
	_checar(tela.painel is PainelDaAtividade and not tela.painel.has_node("Display/Varredura") and not tela.painel.has_node("Led"),
		"o conteúdo fica direto na tela do Laboratório: sem moldura de monitor, sem varredura nem luzinha")
	_checar(tela.estado == tela.Estado.ESCOLHA and tela.grupo_escolha.visible and not tela.grupo_equacao.visible \
		and not tela.grupo_fim.visible, "abre na escolha do nível")
	_checar(tela.painel.texto_do_rodape() == tela.TXT_ESCOLHA, "o rodapé avisa: vale qualquer resposta balanceada")
	var certos := true
	var area: Rect2 = tela.painel.retangulo_do_conteudo()
	var caixas: Array[Rect2] = []
	for nivel: EquacoesDoLaboratorio.Nivel in NIVEIS:
		var botao: Panel = tela.botoes_de_nivel[nivel]
		var alvo: String = tela.nome_do_nivel(nivel)
		if (botao.get_node("Nome") as Label).text != EquacoesDoLaboratorio.NOMES[nivel] \
				or (botao.get_node("Descricao") as Label).text != EquacoesDoLaboratorio.DESCRICOES[nivel] \
				or (botao.get_node("Quantas") as Label).text != "%d EQUAÇÕES" % EquacoesDoLaboratorio.do_nivel(nivel).size():
			certos = false
		if not tela.alvo_disponivel(alvo) or not area.encloses(tela.retangulo_do_alvo(alvo)):
			certos = false
		if not _cabe_inteiro(botao.get_node("Descricao") as Label):
			certos = false
		caixas.append(tela.retangulo_do_alvo(alvo))
	_checar(certos, "três botões, com o nome, o que o nível mostra e quantas equações tem")
	_checar(not caixas[0].intersects(caixas[1]) and not caixas[1].intersects(caixas[2]), "um ao lado do outro, sem se cobrir")
	_checar(not tela.alvo_disponivel("confirmar") and not tela.alvo_disponivel("pular") and not tela.alvo_disponivel("outro_nivel"),
		"na escolha, só os níveis podem ser clicados")
	var textos := _textos_dos_labels(tela)
	textos.append_array(_textos_do_script(tela))
	textos.append_array(["BALANCEAMENTO DE EQUAÇÕES", "FIM DO NÍVEL"])
	_checar(_letras_que_faltam(textos).is_empty(), "toda letra da tela e das falas existe na fonte [%s]" % _letras_que_faltam(textos))
	var fora := _labels_fora_do_lugar(tela.painel, area)
	_checar(fora.is_empty(), "todo texto cabe no lugar dele %s" % [fora])
	await _passar_por(tela, "nivel_medio")
	_checar((tela.botoes_de_nivel[NIVEIS[1]] as Panel).self_modulate != Color.WHITE \
		and (tela.botoes_de_nivel[NIVEIS[0]] as Panel).self_modulate == Color.WHITE, "o botão sob o mouse acende")
	await _foto("bal_1_escolha")
	await _fechar(tela)


func _testar_o_facil() -> void:
	print("\n--- NÍVEL FÁCIL ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	var resolvidas: Array = []
	tela.equacao_resolvida.connect(func(qual: int) -> void: resolvidas.append(qual))
	await _clicar(tela, "nivel_facil")
	_checar(tela.estado == tela.Estado.RESOLVENDO and tela.nivel == NIVEIS[0] and tela.indice == 0 \
		and tela.grupo_equacao.visible and not tela.grupo_escolha.visible, "clicar em FÁCIL começa o nível")
	_checar(tela.painel.cabecalho.text == "FÁCIL: EQUAÇÃO 1 DE 7" \
		and tela.painel.texto_do_rodape() == "BALANCEIE: A QUEIMA DO HIDROGÊNIO, QUE EMPURRA O FOGUETE",
		"o cabeçalho diz FÁCIL: EQUAÇÃO 1 DE 7, e o rodapé apresenta a reação")
	var formulas: Array = []
	for termo: TermoEquacao in tela._termos:
		formulas.append(termo.formula)
	_checar(formulas == ["H2", "O2", "H2O"] and tela._seletores.is_empty(),
		"uma coluna por substância, a mesma dos puzzles da história (termo_equacao.tscn): H2, O2, H2O")
	_checar(tela.linha_equacao.visible and tela.reagentes_valor.visible and tela.produtos_valor.visible \
		and tela.reagentes_titulo.visible, "com a contagem dos átomos e a equação escrita")
	var fora := _fora_da_arrumacao(tela)
	_checar(fora.is_empty(), "a contagem no alto, a equação embaixo dela e cada termo em cima da molécula dele %s" % [fora])
	_checar(_linha_escrita(tela) == "? H2 + ? O2 → ? H2O", "sem mexer, os coeficientes são \"?\" (\"%s\")" % _linha_escrita(tela))
	_checar(tela.reagentes_valor.get_parsed_text() == "H = ?   O = ?" and tela.produtos_valor.get_parsed_text() == "H = ?   O = ?",
		"e a contagem também")
	_checar(tela.alvo_disponivel("mais_0") and tela.alvo_disponivel("menos_2") and not tela.tem_alvo("mais_3") \
		and tela.alvo_disponivel("confirmar") and tela.alvo_disponivel("pular"), "as setas dos três termos, CONFIRMAR e PULAR")

	# Confirmar sem definir.
	await _clicar(tela, "confirmar")
	_checar(tela.painel.texto_do_rodape() == tela.TXT_FALTA_DEFINIR and _tocou(tela, "erro") and tela.erros == 0,
		"confirmar sem mexer pede os coeficientes (e não conta como erro)")

	# As moléculas aparecem conforme o coeficiente.
	await _clicar(tela, "mais_0", 2)
	_checar(tela.coeficientes[0] == 2 and tela._termos[0].moleculas.get_child_count() == 2, "duas vezes a seta do H2: duas moléculas de H2")
	_checar(_linha_escrita(tela) == "2 H2 + ? O2 → ? H2O" and tela.reagentes_valor.get_parsed_text() == "H = 4   O = ?",
		"a equação vira 2 H2 + ? O2 e a contagem, H = 4")
	_checar(not tela.painel.avisando(), "mexer numa seta apaga o aviso de erro")
	await _clicar(tela, "menos_0")
	_checar(tela.coeficientes[0] == 1 and tela._termos[0].moleculas.get_child_count() == 1, "a seta de baixo tira uma")
	await _clicar(tela, "mais_1")
	await _clicar(tela, "mais_2")
	_checar(tela.reagentes_valor.get_parsed_text() == "H = 2   O = 2" and tela.produtos_valor.get_parsed_text() == "H = 2   O = 1",
		"com 1-1-1: reagentes H = 2, O = 2; produtos H = 2, O = 1")
	_checar(tela.reagentes_valor.text.contains(tela.COR_CERTO.to_html(false)) and tela.reagentes_valor.text.contains(tela.COR_AMARELO.to_html(false)),
		"o H, que bate, fica verde; o O, que não bate, amarelo")
	_checar(tela.reagentes_titulo.get_theme_color("font_color") == tela.COR_ERRO, "tudo definido e não bate: os títulos ficam vermelhos")
	await _clicar(tela, "confirmar")
	_checar(tela.painel.texto_do_rodape() == "ELEMENTO O DESBALANCEADO" and tela.erros == 1 and tela.estado == tela.Estado.RESOLVENDO,
		"confirmar 1-1-1: ELEMENTO O DESBALANCEADO, um erro")
	await _esperar(0.4)
	_checar(tela.grupo_equacao.position.is_equal_approx(tela.grupo_equacao.get_meta("pos_base")), "a equação treme e volta para o lugar")
	await _foto("bal_2_facil_errado")

	# Certo.
	await _clicar(tela, "mais_0")
	await _clicar(tela, "mais_2")
	_checar(tela.esta_balanceada() and tela.reagentes_titulo.get_theme_color("font_color") == tela.COR_CERTO,
		"2-1-2: a contagem bate e os títulos ficam verdes antes mesmo de confirmar")
	await _teclar(KEY_ENTER)
	_checar(tela.estado == tela.Estado.PASSANDO and tela.resolvidas == 1 and resolvidas == [0],
		"ENTER confirma: balanceada")
	_checar(tela.painel.texto_do_rodape() == tela.TXT_BALANCEADA and _tocou(tela, "sucesso"), "o rodapé diz BALANCEADA!")
	_checar(not tela.alvo_disponivel("mais_0") and not tela.alvo_disponivel("confirmar"), "enquanto passa, nada pode ser clicado")
	await _foto("bal_3_facil_certo")
	_checar(await _esperar_a_proxima(tela) and tela.indice == 1 and tela.estado == tela.Estado.RESOLVENDO,
		"e logo vem a equação seguinte")
	_checar(tela.painel.cabecalho.text == "FÁCIL: EQUAÇÃO 2 DE 7" and tela.coeficientes == [0, 0, 0] \
		and _linha_escrita(tela) == "? C + ? O2 → ? CO", "a segunda: ? C + ? O2 -> ? CO, do zero")

	# Em dobro vale, e o rodapé mostra a forma mais simples.
	await _por_coeficientes(tela, [4, 2, 4])
	await _clicar(tela, "confirmar")
	_checar(tela.estado == tela.Estado.PASSANDO and tela.resolvidas == 2 \
		and tela.painel.texto_do_rodape() == "BALANCEADA! FORMA MAIS SIMPLES: 2-1-2",
		"4-2-4 também passa: BALANCEADA! FORMA MAIS SIMPLES: 2-1-2")
	await _esperar_a_proxima(tela)

	# As setas dão a volta.
	await _clicar(tela, "menos_0")
	_checar(tela.coeficientes[0] == tela.COEF_MAX and tela.tocado[0], "a seta de baixo no zero vai ao 9")
	await _clicar(tela, "mais_0")
	_checar(tela.coeficientes[0] == 0 and tela._termos[0].moleculas.get_child_count() == 0, "e a de cima no 9 volta ao zero")
	await _por_coeficientes(tela, [0, 1, 2])
	await _clicar(tela, "confirmar")
	_checar(tela.painel.texto_do_rodape() == tela.TXT_FALTA_DEFINIR and tela.erros == 1,
		"com um coeficiente em zero, confirmar pede os coeficientes")

	# PULAR.
	var antes: int = tela.indice
	await _clicar(tela, "pular")
	_checar(tela.estado == tela.Estado.PASSANDO and tela.resolvidas == 2 and resolvidas.size() == 2,
		"PULAR passa adiante sem contar como balanceada")
	_checar(tela.painel.texto_do_rodape() == "A RESPOSTA ERA: 2-1-2" and tela.coeficientes == [2, 1, 2],
		"e mostra a resposta: 2-1-2")
	_checar(await _esperar_a_proxima(tela) and tela.indice == antes + 1, "depois vem a seguinte")

	# ESC no meio do nível volta à escolha.
	await _teclar(KEY_ESCAPE)
	_checar(tela.estado == tela.Estado.ESCOLHA and tela.grupo_escolha.visible and not tela.de_saida() \
		and tela.termos.get_child_count() == 0 and not tela.tem_alvo("mais_0"),
		"ESC no meio do nível volta à escolha (e desmonta a equação)")
	await _fechar(tela)


func _testar_o_medio() -> void:
	print("\n--- NÍVEL MÉDIO ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	await _clicar(tela, "nivel_medio")
	_checar(tela.nivel == NIVEIS[1] and tela.painel.cabecalho.text == "MÉDIO: EQUAÇÃO 1 DE 8", "MÉDIO: EQUAÇÃO 1 DE 8")
	_checar(tela._termos.size() == 3 and tela.linha_equacao.visible, "com as moléculas e a equação escrita")
	var fora := _fora_da_arrumacao(tela)
	_checar(fora.is_empty(), "os títulos no alto, a equação embaixo e cada termo em cima da molécula dele %s" % [fora])
	_checar(not tela.reagentes_valor.visible and not tela.produtos_valor.visible, "mas sem a contagem dos átomos")
	_checar(tela.reagentes_titulo.visible and tela.reagentes_titulo.get_theme_color("font_color") == tela.COR_TEXTO,
		"os títulos Reagentes e Produtos ficam, sem cor de certo ou errado")
	# NO + O2 -> NO2: certa é 2-1-2.
	await _por_coeficientes(tela, [1, 1, 1])
	_checar(tela._termos[0].moleculas.get_child_count() == 1 and tela.reagentes_titulo.get_theme_color("font_color") == tela.COR_TEXTO,
		"errado e tudo definido: nada muda de cor antes de confirmar")
	var cor_da_linha := _cor_da_linha(tela)
	await _por_coeficientes(tela, [2, 1, 2])
	_checar(tela.esta_balanceada() and tela.reagentes_titulo.get_theme_color("font_color") == tela.COR_TEXTO \
		and _cor_da_linha(tela) == cor_da_linha,
		"certo também não: quem conta os átomos é a pessoa")
	await _foto("bal_4_medio")
	await _clicar(tela, "confirmar")
	_checar(tela.estado == tela.Estado.PASSANDO and _cor_da_linha(tela) == tela.COR_CERTO,
		"confirmando, a equação fica verde")
	await _esperar_a_proxima(tela)
	# A hidrazina: 1-1-1-2. Errando dois elementos, o rodapé diz os dois.
	await _por_coeficientes(tela, [1, 2, 1, 1])
	await _clicar(tela, "confirmar")
	_checar(tela.painel.texto_do_rodape() == "ELEMENTOS H E O DESBALANCEADOS" and tela.erros == 1,
		"N2H4 + O2 -> N2 + H2O com 1-2-1-1: ELEMENTOS H E O DESBALANCEADOS")
	await _fechar(tela)


func _testar_o_dificil() -> void:
	print("\n--- NÍVEL DIFÍCIL ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	await _clicar(tela, "nivel_dificil")
	_checar(tela.nivel == NIVEIS[2] and tela.painel.cabecalho.text == "DIFÍCIL: EQUAÇÃO 1 DE 9", "DIFÍCIL: EQUAÇÃO 1 DE 9")
	_checar(tela._termos.is_empty() and tela._seletores.size() == 3, "sem moléculas: um seletor para cada coeficiente")
	_checar(not tela.linha_equacao.visible and not tela.reagentes_titulo.visible and not tela.reagentes_valor.visible,
		"sem a equação do alto, sem Reagentes/Produtos, sem contagem")
	_checar(_escrita_do_dificil(tela) == "? Fe + ? O2 → ? Fe2O3", "só a equação escrita: ? Fe + ? O2 → ? Fe2O3 (\"%s\")" \
		% _escrita_do_dificil(tela))
	await _clicar(tela, "mais_0", 4)
	await _clicar(tela, "mais_1", 3)
	_checar(_tocou(tela, "passo"), "cada clique numa seta faz o som de passo")
	await _clicar(tela, "mais_2", 3)
	await _clicar(tela, "menos_2")
	_checar(tela.coeficientes == [4, 3, 2] and _escrita_do_dificil(tela) == "4 Fe + 3 O2 → 2 Fe2O3",
		"as setas escrevem os coeficientes: 4 Fe + 3 O2 → 2 Fe2O3")
	await _foto("bal_5_dificil")
	await _clicar(tela, "confirmar")
	_checar(tela.estado == tela.Estado.PASSANDO and tela.resolvidas == 1, "4-3-2 balanceia a ferrugem")
	_checar(tela._seletores[0].numero.get_theme_color("font_color") == tela.COR_CERTO, "e a equação fica verde")
	await _esperar_a_proxima(tela)

	# A equação mais comprida ocupa duas fileiras: reagentes em cima, produtos embaixo.
	tela.indice = 8
	tela._montar_equacao()
	await _quadros(2)
	_checar(tela._seletores.size() == 6, "o propulsor sólido tem seis coeficientes")
	var de_cima: float = tela._seletores[0].position.y
	var de_baixo: float = tela._seletores[2].position.y
	_checar(is_equal_approx(tela._seletores[1].position.y, de_cima) and de_baixo > de_cima + 100.0 \
		and is_equal_approx(tela._seletores[5].position.y, de_baixo), "em duas fileiras: os reagentes em cima, os produtos embaixo")
	_checar(_escrita_do_dificil(tela) == "? NH4ClO4 + ? Al → ? Al2O3 + ? AlCl3 + ? NO + ? H2O",
		"? NH4ClO4 + ? Al → ? Al2O3 + ? AlCl3 + ? NO + ? H2O (\"%s\")" % _escrita_do_dificil(tela))
	await _por_coeficientes(tela, [3, 3, 1, 1, 3, 6])
	await _foto("bal_6_dificil_duas_fileiras")
	await _clicar(tela, "confirmar")
	_checar(tela.estado == tela.Estado.PASSANDO, "3-3-1-1-3-6 balanceia")
	_checar(await _esperar_a_proxima(tela) and tela.estado == tela.Estado.FIM, "era a última: vem o fim do nível")
	await _fechar(tela)


func _testar_o_layout() -> void:
	print("\n--- TUDO NO LUGAR, EM TODAS AS EQUAÇÕES ---")
	var tela := await _abrir(CENA)
	await _esperar(0.4)
	var area: Rect2 = tela.painel.retangulo_do_conteudo()
	var rodape: Label = tela.painel.rodape
	var problemas := PackedStringArray()
	var menor_letra := 99
	for nivel: EquacoesDoLaboratorio.Nivel in NIVEIS:
		tela.escolher_nivel(nivel)
		for qual in tela.fila().size():
			tela.indice = qual
			tela._montar_equacao()
			var quantos: int = tela.formulas().size()
			var maximo: Array = []
			maximo.resize(quantos)
			maximo.fill(tela.COEF_MAX)
			tela.definir_coeficientes(maximo)
			await _quadros(2)
			var nome := "%s %d (%s)" % [EquacoesDoLaboratorio.NOMES[nivel], qual + 1,
				EquacaoQuimica.escrita(tela.equacao()["reagentes"], tela.equacao()["produtos"], tela.equacao()["resposta"])]
			# O rodapé apresenta a reação numa linha só.
			if FONTE.get_string_size(tela.painel.texto_do_rodape() + "_", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > rodape.size.x:
				problemas.append("%s: o nome não cabe no rodapé" % nome)
			# As setas: dentro do area, sem cobrir umas às outras nem os botões.
			var setas: Array[Rect2] = []
			for i in quantos:
				for prefixo: String in ["mais_", "menos_"]:
					var seta: Rect2 = tela.retangulo_do_alvo(prefixo + str(i))
					if not seta.has_area() or not area.encloses(seta):
						problemas.append("%s: seta %s%d fora do area %s" % [nome, prefixo, i, seta])
					setas.append(seta)
			for i in setas.size():
				for j in range(i + 1, setas.size()):
					if setas[i].intersects(setas[j]):
						problemas.append("%s: setas %d e %d se cobrem" % [nome, i, j])
				for botao: String in ["confirmar", "pular"]:
					if setas[i].intersects(tela.retangulo_do_alvo(botao)):
						problemas.append("%s: seta %d em cima do %s" % [nome, i, botao])
			if EquacoesDoLaboratorio.com_moleculas(nivel):
				# A equação escrita: embaixo da contagem, cada termo em cima da
				# coluna dele, sem uma peça cobrir a outra nem sair do area.
				for problema in _fora_da_arrumacao(tela):
					problemas.append("%s: %s" % [nome, problema])
				for i in quantos:
					if not area.encloses(EquacaoSobreColunas.retangulo_do_termo(tela.linha_equacao, i)):
						problemas.append("%s: o termo %d escrito sai do area" % [nome, i])
				menor_letra = mini(menor_letra, EquacaoSobreColunas.tamanho(tela.linha_equacao))
				# As nove moléculas de cada termo cabem no retângulo delas.
				for termo: TermoEquacao in tela._termos:
					if not area.encloses(termo.get_global_rect()):
						problemas.append("%s: a coluna do %s sai do area" % [nome, termo.formula])
					var caixa := Rect2(Vector2.ZERO, termo.moleculas.size).grow(6.0)
					if termo.moleculas.get_child_count() != tela.COEF_MAX:
						problemas.append("%s: %s com %d moléculas" % [nome, termo.formula, termo.moleculas.get_child_count()])
					for molecula: Control in termo.moleculas.get_children():
						if not caixa.encloses(Rect2(molecula.position, molecula.size)):
							problemas.append("%s: molécula de %s fora do lugar" % [nome, termo.formula])
							break
				if EquacoesDoLaboratorio.com_contagem(nivel):
					for valor: RichTextLabel in [tela.reagentes_valor, tela.produtos_valor]:
						if valor.get_content_width() > valor.size.x + 0.5 or not area.encloses(valor.get_global_rect()):
							problemas.append("%s: a contagem \"%s\" não cabe" % [nome, valor.get_parsed_text()])
			else:
				for filho: Control in tela.termos.get_children():
					if not area.grow(1.0).encloses(filho.get_global_rect()):
						problemas.append("%s: %s sai do area" % [nome, filho.get_class()])
			var fora := _labels_fora_do_lugar(tela.painel, area)
			if not fora.is_empty():
				problemas.append("%s: %s" % [nome, fora])
	_checar(problemas.is_empty(), "nas 24 equações, com tudo em 9: setas, moléculas, contagem e escrita no lugar %s" \
		% [problemas.slice(0, 6)])
	_checar(menor_letra >= tela.FONTE_EQUACAO_MIN, "a letra da equação escrita nunca fica menor que o mínimo (a menor usada: %d px; mínimo %d)" \
		% [menor_letra, tela.FONTE_EQUACAO_MIN])
	await _fechar(tela)


func _testar_os_niveis_inteiros() -> void:
	print("\n--- OS TRÊS NÍVEIS, ATÉ O FIM ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	var concluidos := [0]
	tela.nivel_concluido.connect(func() -> void: concluidos[0] += 1)
	for nivel: EquacoesDoLaboratorio.Nivel in NIVEIS:
		await _clicar(tela, tela.nome_do_nivel(nivel))
		var fila: Array = tela.fila()
		var tudo_certo := true
		for qual in fila.size():
			if tela.indice != qual or tela.estado != tela.Estado.RESOLVENDO:
				tudo_certo = false
				break
			# A penúltima é pulada; as outras, resolvidas clicando (a primeira com
			# uma confirmação errada antes).
			if qual == fila.size() - 2:
				await _clicar(tela, "pular")
			else:
				if qual == 0:
					var errada: Array = (fila[qual]["resposta"] as Array).duplicate()
					errada[0] = int(errada[0]) + 1
					await _por_coeficientes(tela, errada)
					await _clicar(tela, "confirmar")
					if tela.estado != tela.Estado.RESOLVENDO:
						tudo_certo = false
				await _por_coeficientes(tela, fila[qual]["resposta"])
				await _clicar(tela, "confirmar")
				if tela.estado != tela.Estado.PASSANDO:
					tudo_certo = false
			if not await _esperar_a_proxima(tela):
				tudo_certo = false
		var nome: String = EquacoesDoLaboratorio.NOMES[nivel]
		_checar(tudo_certo and tela.estado == tela.Estado.FIM, "o nível %s se resolve inteiro, clicando (%d equações)" \
			% [nome, fila.size()])
		_checar(tela.grupo_fim.visible and not tela.grupo_equacao.visible and tela.titulo_do_fim.text == "NÍVEL %s CONCLUÍDO" % nome \
			and tela.resumo_do_fim.text == "%d DE %d EQUAÇÕES BALANCEADAS" % [fila.size() - 1, fila.size()] \
			and tela.erros_do_fim.text == "CONFIRMAÇÕES ERRADAS: 1",
			"o fim diz: NÍVEL %s CONCLUÍDO, %d DE %d, CONFIRMAÇÕES ERRADAS: 1" % [nome, fila.size() - 1, fila.size()])
		var area: Rect2 = tela.painel.retangulo_do_conteudo()
		_checar(tela.alvo_disponivel("outro_nivel") and tela.alvo_disponivel("sair") and not tela.alvo_disponivel("confirmar") \
			and area.encloses(tela.retangulo_do_alvo("outro_nivel")) and area.encloses(tela.retangulo_do_alvo("sair")) \
			and _labels_fora_do_lugar(tela.painel, area).is_empty(), "com os botões OUTRO NÍVEL e VOLTAR, tudo no lugar")
		if nivel == NIVEIS[0]:
			await _foto("bal_7_fim")
		await _clicar(tela, "outro_nivel")
		_checar(tela.estado == tela.Estado.ESCOLHA and tela.grupo_escolha.visible and not tela.grupo_fim.visible,
			"OUTRO NÍVEL volta à escolha")
	_checar(concluidos[0] == 3, "o sinal nivel_concluido saiu uma vez por nível")
	await _fechar(tela)


func _testar_o_controle() -> void:
	print("\n--- NO CONTROLE ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	_checar(tela.usa_cursor() and tela.alvos_do_cursor().size() == 3, "na escolha, o cursor para nos três níveis")
	await _tocar_no_controle(JOY_BUTTON_DPAD_UP)
	await _levar_o_cursor(tela.retangulo_do_alvo("nivel_facil").get_center())
	await _tocar_no_controle(JOY_BUTTON_A)
	_checar(tela.estado == tela.Estado.RESOLVENDO and tela.nivel == NIVEIS[0], "✕ em cima de FÁCIL começa o nível")
	_checar(tela.alvos_do_cursor().size() == 3 * 2 + 2, "resolvendo, o cursor para nas setas, no CONFIRMAR e no PULAR")
	_checar(tela.dicas_do_controle().any(func(d: Array) -> bool: return d[0] == "fechar" and d[1] == "NÍVEIS"),
		"e a barra diz que o △ volta aos níveis")
	await _levar_o_cursor(tela.retangulo_do_alvo("mais_0").get_center())
	await _tocar_no_controle(JOY_BUTTON_A)
	await _tocar_no_controle(JOY_BUTTON_A)
	_checar(tela.coeficientes[0] == 2, "✕ na seta soma um a cada toque (2)")
	await _tocar_no_controle(JOY_BUTTON_Y)
	_checar(tela.estado == tela.Estado.ESCOLHA and not tela.de_saida(), "△ no meio do nível volta à escolha")
	await _voltar_ao_teclado()
	await _fechar(tela)


func _testar_a_saida() -> void:
	print("\n--- SAIR ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	await _teclar(KEY_ESCAPE)
	_checar(tela.de_saida() and TransicaoDeCena.em_curso(), "ESC na escolha do nível pede para sair")
	var chegou := await _esperar_a_troca()
	_checar(chegou == TransicaoDeCena.CENA_LABORATORIO, "e a cena que chega é o menu do Laboratório")
	await _fechar(tela)

	# O botão VOLTAR do fim do nível faz o mesmo.
	tela = await _abrir(CENA)
	await _esperar(0.3)
	tela.escolher_nivel(NIVEIS[2])
	tela._mostrar_o_fim()
	await _quadros(2)
	await _clicar(tela, "sair")
	_checar(tela.de_saida(), "o botão VOLTAR do fim do nível também sai")
	chegou = await _esperar_a_troca()
	_checar(chegou == TransicaoDeCena.CENA_LABORATORIO, "para o menu do Laboratório")
	await _fechar(tela)
