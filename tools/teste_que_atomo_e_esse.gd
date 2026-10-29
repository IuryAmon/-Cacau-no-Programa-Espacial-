extends "res://tools/teste_de_tela.gd"

# Teste do quiz "Que átomo é esse?" do Laboratório
# (scenes/laboratorio/que_atomo_e_esse.tscn), jogado com o mouse de verdade.
#
#   * o conteúdo fica direto na tela (sem monitor), as letras existem na fonte e todo texto cabe (o
#     rodapé de qualquer resposta, certa ou errada);
#   * as perguntas crescem: átomos pequenos e neutros primeiro; isótopos e íons
#     só no fim (FASES);
#   * o sorteio nunca repete elemento na partida, e o átomo sorteado é o que o
#     tipo promete: o neutro mais comum, um isótopo que existe na natureza, o
#     íon mais comum do elemento (que fica com os elétrons de um gás nobre);
#   * as quatro caixas são elementos diferentes, a certa está entre elas e cai
#     em qualquer das quatro posições; nas perguntas de íon e de isótopo, uma
#     das erradas é a "conta trocada" (o elemento com aquele tanto de elétrons
#     ou de nêutrons);
#   * o desenho mostra o átomo perguntado, sem Z, A nem carga embaixo dele;
#   * acertar soma ponto, pinta a caixa de verde e explica; errar não soma,
#     pinta a escolhida de vermelho, a certa de verde e explica;
#   * respondida, um clique (ou ENTER, ESPAÇO, E) passa adiante, e esse clique
#     não responde a pergunta seguinte;
#   * depois da décima vem o placar, com a mensagem do tanto de acertos, e dá
#     para jogar de novo;
#   * de controle, o ✕ responde e o ✕ seguinte só continua (não responde a
#     próxima com a caixa que estiver debaixo do cursor);
#   * ESC volta ao menu do Laboratório.
#
#   godot --headless --path . res://tools/teste_que_atomo_e_esse.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma imagem de cada
# momento.

const CENA := "res://scenes/laboratorio/que_atomo_e_esse.tscn"
## Os elétrons dos gases nobres até o criptônio: é com um destes que o íon
## mais comum de um elemento representativo fica.
const ELETRONS_DE_GAS_NOBRE := [2, 10, 18, 36]


func _ready() -> void:
	await _comecar()
	await _testar_a_tela()
	await _testar_o_sorteio()
	await _testar_as_respostas()
	await _testar_a_partida()
	await _testar_o_controle()
	await _testar_a_saida()
	_terminar()


## Clica na caixa do elemento "z" (que precisa estar entre as opções).
func _clicar_no_elemento(tela: TelaInterativa, z: int) -> void:
	await _clicar(tela, "opcao_%d" % (tela.opcoes.find(z) + 1))


## O número de uma opção errada.
func _uma_errada(tela: TelaInterativa) -> int:
	for opcao: int in tela.opcoes:
		if opcao != int(tela.atual["z"]):
			return opcao
	return 0


# ─────────────────────────────────────────────────────────────

func _testar_a_tela() -> void:
	print("\n--- A TELA ---")
	var tela := await _abrir(CENA)
	await _esperar(0.4)
	_checar(tela.titulo == "QUE ÁTOMO É ESSE?" and tela.cena_de_volta == TransicaoDeCena.CENA_LABORATORIO,
		"o título é QUE ÁTOMO É ESSE?, e ESC leva ao Laboratório")
	_checar(tela.painel is PainelDaAtividade and not tela.painel.has_node("Display/Varredura") and not tela.painel.has_node("Led"),
		"o conteúdo fica direto na tela do Laboratório: sem moldura de monitor, sem varredura nem luzinha")
	_checar(tela.estado == tela.Estado.PERGUNTANDO and tela.numero == 1 and tela.acertos == 0,
		"abre já perguntando: pergunta 1, nenhum acerto")
	_checar(tela.painel.cabecalho.text == "PERGUNTA 1 DE 10" and tela.placar.text == "ACERTOS: 0",
		"o cabeçalho diz PERGUNTA 1 DE 10 e o placar, ACERTOS: 0")
	_checar(tela.find_child("NumeroAtomico", true, false) == null and tela.find_child("Carga", true, false) == null,
		"embaixo do átomo não há Z, A nem carga: só o desenho")
	_checar(not tela.continuar.visible and tela.grupo_jogo.visible and not tela.grupo_fim.visible,
		"sem \"clique para continuar\" e sem placar final")
	_checar(tela.atomo.protons() == int(tela.atual["z"]) and tela.atomo.neutrons() == int(tela.atual["neutrons"]) \
		and tela.atomo.eletrons() == int(tela.atual["eletrons"]), "o desenho é o do átomo perguntado")

	var textos := _textos_dos_labels(tela)
	textos.append_array(_textos_do_script(tela))
	textos.append_array(["FIM DA PARTIDA", "ESCOLHA: OUTRA PARTIDA OU VOLTAR AO LABORATÓRIO", "ÁTOMO NEUTRO", "CÁTION", "ÂNION"])
	_checar(_letras_que_faltam(textos).is_empty(), "toda letra da tela e das falas existe na fonte [%s]" \
		% _letras_que_faltam(textos))
	var area: Rect2 = tela.painel.retangulo_do_conteudo()
	var fora := _labels_fora_do_lugar(tela.painel, area)
	_checar(fora.is_empty(), "perguntando, todo texto cabe no lugar dele %s" % [fora])

	# As quatro caixas: dentro do area, sem se cobrir e sem cobrir o átomo.
	var caixas: Array[Rect2] = []
	var no_lugar := true
	for i in 4:
		var nome := "opcao_%d" % (i + 1)
		var caixa: Rect2 = tela.retangulo_do_alvo(nome)
		if not tela.alvo_disponivel(nome) or not area.encloses(caixa) or caixa.intersects(tela.atomo.get_global_rect()):
			no_lugar = false
		caixas.append(caixa)
	for i in 4:
		for j in range(i + 1, 4):
			if caixas[i].intersects(caixas[j]):
				no_lugar = false
	_checar(no_lugar, "as quatro caixas ficam no area, sem se cobrir e sem cobrir o átomo")
	_checar(not tela.alvo_disponivel("continuar") and not tela.alvo_disponivel("de_novo") and not tela.alvo_disponivel("sair"),
		"perguntando, só as caixas podem ser clicadas")

	# O rodapé: a dica de cada tipo e a explicação de qualquer resposta.
	var rodape: Label = tela.painel.rodape
	var largos := PackedStringArray()
	var falas: Array = [tela.TXT_DICA + "_", tela.TXT_DICA_NEUTRO + "_", tela.TXT_DICA_ION + "_",
		"ESCOLHA: OUTRA PARTIDA OU VOLTAR AO LABORATÓRIO_"]
	for z in range(1, 21):
		var palavra := "PRÓTON" if z == 1 else "PRÓTONS"
		falas.append(tela.TXT_CERTO % [z, palavra, Elementos.nome(z).to_upper()])
		# As erradas saem dos vizinhos e das contas trocadas: até o elemento 60.
		for errada in range(1, 61):
			falas.append(tela.TXT_ERRADO % [Elementos.nome(errada).to_upper(), z, palavra, Elementos.nome(z).to_upper()])
	var mais_larga := 0.0
	for fala: String in falas:
		var largura := FONTE.get_string_size(fala, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		mais_larga = maxf(mais_larga, largura)
		if largura > rodape.size.x:
			largos.append(fala)
	_checar(largos.is_empty(), "tudo o que o rodapé diz cabe no rodapé (a fala mais larga: %.0f de %.0f px) %s" \
		% [mais_larga, rodape.size.x, largos.slice(0, 3)])
	largos.clear()
	for faixa: Array in tela.TXT_FINAIS:
		if FONTE.get_string_size(String(faixa[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x > tela.mensagem_final.size.x:
			largos.append(faixa[1])
	_checar(largos.is_empty(), "as mensagens do fim cabem na linha delas %s" % [largos])
	await _foto("quiz_1_pergunta")
	await _fechar(tela)


func _testar_o_sorteio() -> void:
	print("\n--- O SORTEIO ---")
	var tela := await _abrir(CENA)

	# As fases: do pequeno e neutro ao íon.
	var fases_certas := true
	var maior_anterior := 0
	for qual in range(1, tela.PERGUNTAS + 1):
		var fase: Dictionary = tela.fase_da_pergunta(qual)
		if int(fase["maior_z"]) < maior_anterior:
			fases_certas = false
		maior_anterior = int(fase["maior_z"])
		if qual <= 6 and fase["tipos"] != ["neutro"]:
			fases_certas = false
	_checar(fases_certas, "as seis primeiras perguntas são de átomo neutro, e os átomos só crescem")
	_checar(int(tela.fase_da_pergunta(1)["maior_z"]) <= 6 and int(tela.fase_da_pergunta(tela.PERGUNTAS)["maior_z"]) <= 20,
		"começa até o carbono e vai, no máximo, até o cálcio")
	var ultimas: Array = tela.fase_da_pergunta(tela.PERGUNTAS)["tipos"]
	_checar("ion" in ultimas and not "neutro" in ultimas, "as últimas são de íon ou de isótopo: contar elétrons não basta")
	_checar(int((tela.FASES[-1] as Dictionary)["ate"]) == tela.PERGUNTAS, "a última fase vai até a última pergunta")

	# Os íons: a carga deixa o elemento com os elétrons de um gás nobre.
	var ions_errados := PackedStringArray()
	for z: int in tela.IONS:
		if not (z - int(tela.IONS[z])) in ELETRONS_DE_GAS_NOBRE or z > 20:
			ions_errados.append("%s%s" % [Elementos.simbolo(z), Elementos.carga_no_simbolo(tela.IONS[z])])
	_checar(ions_errados.is_empty(), "cada íon da lista fica com os elétrons de um gás nobre %s" % [ions_errados])
	_checar(int(tela.IONS[11]) == 1 and int(tela.IONS[17]) == -1 and int(tela.IONS[20]) == 2 and int(tela.IONS[8]) == -2 \
		and int(tela.IONS[13]) == 3, "Na+, Cl-, Ca2+, O2-, Al3+")

	# Muitas partidas inteiras: nada repete, e cada átomo é o que o tipo promete.
	var problemas := PackedStringArray()
	var tipos_vistos := {}
	var posicao_da_certa := [0, 0, 0, 0]
	var com_conta_trocada := 0
	var perguntas_de_conta := 0
	for partida in 120:
		tela._ja_sairam.clear()
		for qual in range(1, tela.PERGUNTAS + 1):
			var atomo: Dictionary = tela.sortear(qual)
			var z := int(atomo["z"])
			var fase: Dictionary = tela.fase_da_pergunta(qual)
			var tipo := String(atomo["tipo"])
			tipos_vistos[tipo] = true
			if z in tela._ja_sairam:
				problemas.append("repetiu %s" % Elementos.simbolo(z))
			tela._ja_sairam.append(z)
			if z < 1 or z > int(fase["maior_z"]):
				problemas.append("%s fora da fase %d" % [Elementos.simbolo(z), qual])
			if not tipo in (fase["tipos"] as Array) and tipo != "neutro":
				problemas.append("tipo %s na pergunta %d" % [tipo, qual])
			var massa := z + int(atomo["neutrons"])
			match tipo:
				"neutro":
					if int(atomo["neutrons"]) != Elementos.neutrons(z) or int(atomo["eletrons"]) != z:
						problemas.append("neutro errado %s" % [atomo])
				"isotopo":
					if massa == Elementos.isotopo(z) or Elementos.abundancia(z, massa) < 0.0 or int(atomo["eletrons"]) != z:
						problemas.append("isótopo errado %s" % [atomo])
				"ion":
					if int(atomo["eletrons"]) != z - int(tela.IONS[z]) or int(atomo["neutrons"]) != Elementos.neutrons(z):
						problemas.append("íon errado %s" % [atomo])
			# As alternativas dessa pergunta.
			var opcoes: Array[int] = tela.alternativas(atomo)
			var distintas := {}
			for opcao in opcoes:
				distintas[opcao] = true
				if not Elementos.existe(opcao):
					problemas.append("opção %d não existe" % opcao)
			if opcoes.size() != 4 or distintas.size() != 4 or not z in opcoes:
				problemas.append("opções %s para %s" % [opcoes, Elementos.simbolo(z)])
			else:
				posicao_da_certa[opcoes.find(z)] += 1
			if tipo == "ion":
				perguntas_de_conta += 1
				if int(atomo["eletrons"]) in opcoes:
					com_conta_trocada += 1
			elif tipo == "isotopo" and Elementos.existe(int(atomo["neutrons"])) and int(atomo["neutrons"]) != z:
				perguntas_de_conta += 1
				if int(atomo["neutrons"]) in opcoes:
					com_conta_trocada += 1
	_checar(problemas.is_empty(), "120 partidas: nenhum elemento repetido, todo átomo do tipo certo, 4 opções diferentes %s" \
		% [problemas.slice(0, 5)])
	_checar(tipos_vistos.has("neutro") and tipos_vistos.has("isotopo") and tipos_vistos.has("ion"),
		"saem os três tipos de pergunta: neutro, isótopo e íon")
	var menor := int(posicao_da_certa.min())
	var maior := int(posicao_da_certa.max())
	_checar(menor > 200 and maior < 400, "a caixa certa cai por igual nas quatro posições %s" % [posicao_da_certa])
	_checar(perguntas_de_conta > 100 and com_conta_trocada == perguntas_de_conta,
		"nas de íon e de isótopo, a \"conta trocada\" está sempre entre as erradas (%d de %d)" \
		% [com_conta_trocada, perguntas_de_conta])

	_checar(tela.outros_isotopos(6) == [13] and tela.outros_isotopos(9).is_empty() and 37 in tela.outros_isotopos(17),
		"outros isótopos naturais: o carbono tem o 13, o flúor não tem outro, o cloro tem o 37")
	var cloro: Dictionary = tela.montar_atomo(17, "ion")
	_checar(int(cloro["eletrons"]) == 18 and int(cloro["neutrons"]) == 18 and cloro["tipo"] == "ion", "o íon do cloro: 18 elétrons")
	var fluor: Dictionary = tela.montar_atomo(9, "isotopo")
	_checar(fluor["tipo"] == "neutro" and int(fluor["neutrons"]) == 10, "sem outro isótopo natural, a pergunta vira de átomo neutro")
	var carbono: Dictionary = tela.montar_atomo(6, "ion")
	_checar(carbono["tipo"] == "neutro" and int(carbono["eletrons"]) == 6, "e elemento sem íon comum também")
	await _fechar(tela)


func _testar_as_respostas() -> void:
	print("\n--- RESPONDER ---")
	var tela := await _abrir(CENA)
	await _esperar(0.4)
	var respostas: Array = []
	tela.respondeu.connect(func(certo: bool) -> void: respostas.append(certo))

	# Certa: o carbono-12.
	var opcoes: Array[int] = [5, 6, 7, 12]
	tela.perguntar({"z": 6, "neutrons": 6, "eletrons": 6, "tipo": "neutro"}, opcoes)
	await _quadros(2)
	_checar(tela.caixas[0].numero_atomico == 5 and tela.caixas[1].numero_atomico == 6 and tela.caixas[3].numero_atomico == 12,
		"as caixas mostram os elementos oferecidos")
	_checar(tela.painel.texto_do_rodape() == tela.TXT_DICA_NEUTRO, "a dica do átomo neutro: um elétron para cada próton")
	await _passar_por(tela, "opcao_3")
	_checar(tela.caixas[2].destaque == EstiloHUD.CLARO and tela.caixas[1].destaque.a == 0.0,
		"a caixa sob o mouse ganha o aro claro")
	await _clicar_no_elemento(tela, 6)
	_checar(tela.estado == tela.Estado.RESPONDIDA and tela.acertos == 1 and tela.escolhida == 1 and respostas == [true],
		"clicar na caixa do carbono: certo, um acerto")
	_checar(tela.painel.texto_do_rodape() == "CERTO! 6 PRÓTONS: CARBONO" and _tocou(tela, "certo"),
		"o rodapé explica: CERTO! 6 PRÓTONS: CARBONO")
	_checar(tela.caixas[1].destaque == PainelDaAtividade.COR_CERTO and tela.caixas[0].apagada \
		and tela.caixas[2].apagada and tela.caixas[3].apagada and not tela.caixas[1].apagada,
		"a caixa certa fica verde e as outras se apagam")
	_checar(tela.placar.text == "ACERTOS: 1" and tela.continuar.visible and tela.continuar.text == tela.TXT_CONTINUAR,
		"o placar sobe e aparece CLIQUE PARA CONTINUAR")
	_checar(not tela.alvo_disponivel("opcao_1") and tela.alvo_disponivel("continuar"),
		"respondida, as caixas deixam de valer: o clique agora continua")
	var fora := _labels_fora_do_lugar(tela.painel, tela.painel.retangulo_do_conteudo())
	_checar(fora.is_empty(), "respondida, todo texto cabe no lugar dele %s" % [fora])
	await _esperar(0.5)
	await _foto("quiz_2_certo")

	# O clique que continua cai em cima de uma caixa: ele NÃO responde a próxima.
	var antes: int = tela.numero
	await _clicar_em(tela.caixas[0].get_global_rect().get_center())
	_checar(tela.numero == antes + 1 and tela.estado == tela.Estado.PERGUNTANDO and tela.escolhida == -1 \
		and respostas.size() == 1, "um clique continua: vem a pergunta seguinte, ainda sem resposta")
	_checar(not tela.continuar.visible, "e o CLIQUE PARA CONTINUAR some")

	# Errada: o íon do sódio, respondido como neônio (que tem os mesmos 10 elétrons).
	opcoes = [10, 11, 12, 23]
	tela.perguntar({"z": 11, "neutrons": 12, "eletrons": 10, "tipo": "ion"}, opcoes)
	await _quadros(2)
	_checar(tela.painel.texto_do_rodape() == tela.TXT_DICA_ION, "a dica do íon: os elétrons não batem com os prótons")
	_checar(tela.atomo.eletrons_por_camada() == PackedInt32Array([2, 8]) and tela.atomo.protons() == 11,
		"o desenho do Na+: 11 prótons e só 10 elétrons")
	await _clicar_no_elemento(tela, 10)
	_checar(tela.estado == tela.Estado.RESPONDIDA and tela.acertos == 1 and respostas == [true, false],
		"responder neônio: errado, o placar não sobe")
	_checar(tela.painel.texto_do_rodape() == "NÃO É NEÔNIO. O NÚCLEO TEM 11 PRÓTONS: É SÓDIO" and _tocou(tela, "erro"),
		"o rodapé explica: NÃO É NEÔNIO. O NÚCLEO TEM 11 PRÓTONS: É SÓDIO")
	_checar(tela.caixas[0].destaque == PainelDaAtividade.COR_ERRO and tela.caixas[1].destaque == PainelDaAtividade.COR_CERTO \
		and tela.caixas[2].apagada, "a escolhida fica vermelha e a certa, verde")
	await _esperar(0.5)
	_checar(tela.caixas[0].position.is_equal_approx(tela.caixas[0].get_meta("pos_base")), "a caixa treme e volta para o lugar")
	await _foto("quiz_3_errado")

	# O teclado continua.
	antes = tela.numero
	await _teclar(KEY_ENTER)
	_checar(tela.numero == antes + 1 and tela.estado == tela.Estado.PERGUNTANDO, "ENTER também continua")
	await _teclar(KEY_ENTER)
	_checar(tela.estado == tela.Estado.PERGUNTANDO and tela.escolhida == -1, "perguntando, ENTER não responde nada")
	await _clicar_no_elemento(tela, int(tela.atual["z"]))
	antes = tela.numero
	await _teclar(KEY_E)
	_checar(tela.numero == antes + 1, "e o E também")

	# Um isótopo: o oxigênio-18.
	opcoes = [8, 10, 18, 9]
	tela.perguntar({"z": 8, "neutrons": 10, "eletrons": 8, "tipo": "isotopo"}, opcoes)
	await _quadros(2)
	_checar(tela.painel.texto_do_rodape() == tela.TXT_DICA, "a dica do isótopo: conte os prótons do núcleo")
	await _clicar_no_elemento(tela, 8)
	_checar(respostas[-1] == true, "oxigênio-18 continua sendo oxigênio")
	tela.responder(2)
	_checar(tela.acertos == 2 + 1 and respostas.size() == 4, "uma pergunta já respondida não aceita outra resposta")
	await _fechar(tela)


func _testar_a_partida() -> void:
	print("\n--- UMA PARTIDA INTEIRA ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	var vistos := {}
	var tudo_certo := true
	for pergunta in range(1, tela.PERGUNTAS + 1):
		if tela.numero != pergunta or tela.estado != tela.Estado.PERGUNTANDO:
			tudo_certo = false
		var z := int(tela.atual["z"])
		if vistos.has(z) or not z in tela.opcoes:
			tudo_certo = false
		vistos[z] = true
		if tela.painel.cabecalho.text != "PERGUNTA %d DE %d" % [pergunta, tela.PERGUNTAS]:
			tudo_certo = false
		await _clicar_no_elemento(tela, z)
		if tela.acertos != pergunta:
			tudo_certo = false
		if pergunta < tela.PERGUNTAS:
			await _clicar(tela, "continuar")
	_checar(tudo_certo and vistos.size() == tela.PERGUNTAS, "dez perguntas, dez elementos diferentes, dez acertos")
	_checar(tela.continuar.text == tela.TXT_VER_PLACAR, "depois da última, o aviso é CLIQUE PARA VER O PLACAR")
	await _clicar(tela, "continuar")
	_checar(tela.estado == tela.Estado.FIM and tela.grupo_fim.visible and not tela.grupo_jogo.visible,
		"um clique mostra o fim da partida")
	_checar(tela.placar_final.text == "10 DE 10" and tela.mensagem_final.text == "PERFEITO! NENHUM ÁTOMO ESCAPOU",
		"10 DE 10: PERFEITO! NENHUM ÁTOMO ESCAPOU")
	_checar(tela.painel.cabecalho.text == "FIM DA PARTIDA" and _tocou(tela, "sucesso"), "o cabeçalho diz FIM DA PARTIDA")
	_checar(tela.alvo_disponivel("de_novo") and tela.alvo_disponivel("sair") and not tela.alvo_disponivel("opcao_1") \
		and not tela.alvo_disponivel("continuar"), "no fim, só os botões JOGAR DE NOVO e VOLTAR valem")
	var area: Rect2 = tela.painel.retangulo_do_conteudo()
	_checar(area.encloses(tela.retangulo_do_alvo("de_novo")) and area.encloses(tela.retangulo_do_alvo("sair")) \
		and not tela.retangulo_do_alvo("de_novo").intersects(tela.retangulo_do_alvo("sair")),
		"os dois botões ficam no area, lado a lado")
	var fora := _labels_fora_do_lugar(tela.painel, area)
	_checar(fora.is_empty(), "no fim, todo texto cabe no lugar dele %s" % [fora])
	await _foto("quiz_4_fim")

	await _clicar(tela, "de_novo")
	_checar(tela.estado == tela.Estado.PERGUNTANDO and tela.numero == 1 and tela.acertos == 0 and tela.grupo_jogo.visible \
		and not tela.grupo_fim.visible and tela.placar.text == "ACERTOS: 0", "JOGAR DE NOVO começa do zero")

	# Uma partida errando tudo, pelo teclado.
	for pergunta in tela.PERGUNTAS:
		await _clicar_no_elemento(tela, _uma_errada(tela))
		await _teclar(KEY_SPACE)
	_checar(tela.estado == tela.Estado.FIM and tela.placar_final.text == "0 DE 10" \
		and tela.mensagem_final.text == String(tela.TXT_FINAIS[0][1]), "errando tudo: 0 DE 10 e o convite a tentar de novo")
	await _teclar(KEY_ENTER)
	_checar(tela.estado == tela.Estado.PERGUNTANDO and tela.numero == 1, "no fim, ENTER começa outra partida")

	_checar(tela.mensagem_do_fim(3) == String(tela.TXT_FINAIS[0][1]) and tela.mensagem_do_fim(4) == String(tela.TXT_FINAIS[1][1]) \
		and tela.mensagem_do_fim(6) == String(tela.TXT_FINAIS[1][1]) and tela.mensagem_do_fim(7) == String(tela.TXT_FINAIS[2][1]) \
		and tela.mensagem_do_fim(9) == String(tela.TXT_FINAIS[2][1]) and tela.mensagem_do_fim(10) == String(tela.TXT_FINAIS[3][1]),
		"a mensagem do fim muda aos 4, aos 7 e aos 10 acertos")
	await _fechar(tela)


func _testar_o_controle() -> void:
	print("\n--- NO CONTROLE ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	_checar(tela.usa_cursor() and tela.alvos_do_cursor().size() == 4, "perguntando, o cursor para nas quatro caixas")
	var opcoes: Array[int] = [5, 6, 7, 12]
	tela.perguntar({"z": 6, "neutrons": 6, "eletrons": 6, "tipo": "neutro"}, opcoes)
	await _tocar_no_controle(JOY_BUTTON_DPAD_UP)
	_checar(Controle.em_uso and CursorVirtual.ativo(), "um toque no controle liga o cursor")
	await _levar_o_cursor(tela.retangulo_do_alvo("opcao_2").get_center())
	await _tocar_no_controle(JOY_BUTTON_A)
	_checar(tela.estado == tela.Estado.RESPONDIDA and tela.acertos == 1, "✕ em cima da caixa do carbono responde: certo")
	_checar(tela.dicas_do_controle()[0] == ["cruz", "CONTINUAR"], "a barra passa a dizer ✕ CONTINUAR")
	# O cursor continua em cima da caixa. O ✕ seguinte só passa adiante.
	var antes: int = tela.numero
	await _tocar_no_controle(JOY_BUTTON_A)
	_checar(tela.numero == antes + 1 and tela.estado == tela.Estado.PERGUNTANDO and tela.escolhida == -1 and tela.acertos == 1,
		"o ✕ seguinte só continua: não responde a pergunta nova com a caixa debaixo do cursor")
	# O □ (interagir) não faz nada de controle na mão.
	await _tocar_no_controle(JOY_BUTTON_X)
	_checar(tela.estado == tela.Estado.PERGUNTANDO and tela.escolhida == -1, "e o □ não responde nem continua")
	await _voltar_ao_teclado()
	await _fechar(tela)


func _testar_a_saida() -> void:
	print("\n--- SAIR ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	await _teclar(KEY_ESCAPE)
	_checar(tela.de_saida() and TransicaoDeCena.em_curso(), "ESC pede para sair")
	var numero: int = tela.numero
	await _clicar(tela, "opcao_1")
	_checar(tela.estado == tela.Estado.PERGUNTANDO and tela.numero == numero, "de saída, a tela não responde a mais nada")
	var chegou := await _esperar_a_troca()
	_checar(chegou == TransicaoDeCena.CENA_LABORATORIO, "e a cena que chega é o menu do Laboratório")
	await _fechar(tela)

	# O botão VOLTAR do fim da partida faz o mesmo.
	tela = await _abrir(CENA)
	await _esperar(0.3)
	tela._mostrar_o_fim()
	await _quadros(2)
	await _clicar(tela, "sair")
	_checar(tela.de_saida(), "o botão VOLTAR do placar também sai")
	chegou = await _esperar_a_troca()
	_checar(chegou == TransicaoDeCena.CENA_LABORATORIO, "para o menu do Laboratório")
	await _fechar(tela)
