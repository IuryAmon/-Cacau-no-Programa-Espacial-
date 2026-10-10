extends "res://tools/teste_de_tela.gd"

# Teste do "Monte seu átomo" do Laboratório
# (scenes/laboratorio/monte_seu_atomo.tscn), jogado com o mouse de verdade.
#
#   * a tela é a do computador da fase 1, começa vazia e toda letra dela existe
#     na fonte; todo texto cabe no lugar (o nome de qualquer isótopo, a carga
#     de três algarismos, o que o rodapé diz, a linha "na natureza" de todos os
#     isótopos que existem);
#   * as seis setas são alvos que não se cobrem; segurando uma, ela repete;
#   * a cada partícula o computador responde NA HORA: o nome do átomo, a caixa
#     do elemento, Z, A, a carga (neutro, cátion, ânion), a notação e quanto
#     daquele isótopo existe na natureza;
#   * o desenho acompanha: núcleo e camadas iguais às contas;
#   * sem prótons não há elemento (e a tela explica por quê); isótopo que não
#     existe na natureza é instável; a luzinha fica verde só no átomo neutro
#     que existe;
#   * os limites (118 prótons, 177 nêutrons, 118 elétrons) recusam com o aviso
#     certo, e abaixo de zero nada acontece;
#   * a roda do mouse em cima de um seletor põe e tira; LIMPAR esvazia;
#   * de controle, o cursor para nas setas e o ✕ clica (segurando, repete);
#   * ESC volta ao menu do Laboratório.
#
#   godot --headless --path . res://tools/teste_monte_seu_atomo.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma imagem de cada
# momento.

const CENA := "res://scenes/laboratorio/monte_seu_atomo.tscn"


func _ready() -> void:
	await _comecar()
	await _testar_a_tela()
	await _testar_a_montagem()
	await _testar_os_limites()
	await _testar_o_mouse()
	await _testar_o_controle()
	await _testar_a_saida()
	_terminar()


# ─────────────────────────────────────────────────────────────

func _testar_a_tela() -> void:
	print("\n--- A TELA ---")
	var tela := await _abrir(CENA)
	await _esperar(0.4)
	_checar(tela.titulo == "MONTE SEU ÁTOMO" and tela.retangulo_do_titulo().has_area(), "o título é MONTE SEU ÁTOMO")
	_checar(tela.cena_de_volta == TransicaoDeCena.CENA_LABORATORIO, "ESC leva ao menu do Laboratório")
	_checar((tela.computador.texture as Texture2D).resource_path.ends_with("Computador receptor/tela_computador.png"),
		"a tela é a do computador da fase 1")
	_checar(tela.protons == 0 and tela.neutrons == 0 and tela.eletrons == 0, "começa sem partícula nenhuma")
	_checar(tela.nome.text == tela.TXT_VAZIO and tela.caixa.numero_atomico == 0 and not tela.notacao.visible \
		and tela.na_natureza.text.is_empty(), "vazia: MONTE UM ÁTOMO, a caixa em branco, sem notação")
	_checar(tela.numero_atomico.text == "Z = 0" and tela.numero_de_massa.text == "A = 0" and tela.carga.text == "CARGA 0" \
		and tela.legenda_da_carga.text.is_empty(), "Z = 0, A = 0, CARGA 0")
	_checar(tela.computador.texto_do_rodape() == tela.TXT_INSTRUCAO, "o rodapé ensina a usar as setas")
	_checar(tela.computador.led.color == ComputadorDoLaboratorio.COR_LED_PARADO, "a luzinha começa vermelha")

	# Letras e caixas.
	var textos := _textos_dos_labels(tela)
	textos.append_array(_textos_do_script(tela))
	for z in range(1, Elementos.TOTAL + 1):
		textos.append(Elementos.nome(z).to_upper())
	_checar(_letras_que_faltam(textos).is_empty(), "toda letra da tela e dos avisos existe na fonte [%s]" \
		% _letras_que_faltam(textos))
	var vidro: Rect2 = tela.computador.retangulo_do_vidro()
	var fora := _labels_fora_do_lugar(tela.computador, vidro)
	_checar(fora.is_empty(), "vazia, todo texto cabe no lugar dele %s" % [fora])

	# O rodapé: tudo o que o terminal pode dizer cabe numa linha dele.
	var rodape: Label = tela.computador.rodape
	var largos := PackedStringArray()
	var falas: Array = [tela.TXT_INSTRUCAO + "_", tela.TXT_PROTONS_DEMAIS, tela.TXT_NEUTRONS_DEMAIS, tela.TXT_ELETRONS_DEMAIS]
	for z in range(1, Elementos.TOTAL + 1):
		falas.append(tela.TXT_ELEMENTO % [z, "PRÓTONS", Elementos.nome(z).to_upper()])
	for fala: String in falas:
		if FONTE.get_string_size(fala, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > rodape.size.x:
			largos.append(fala)
	_checar(largos.is_empty(), "tudo o que o terminal diz cabe no rodapé %s" % [largos])

	# O nome de qualquer isótopo, com número de massa de três algarismos.
	largos.clear()
	for z in range(1, Elementos.TOTAL + 1):
		var nome_largo := Elementos.nome_do_isotopo(z, 288).to_upper()
		if FONTE.get_string_size(nome_largo, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x > tela.nome.size.x:
			largos.append(nome_largo)
	for texto: String in [tela.TXT_SEM_PROTONS, tela.TXT_VAZIO]:
		if FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x > tela.nome.size.x:
			largos.append(texto)
	_checar(largos.is_empty(), "o nome de qualquer átomo cabe na linha do nome %s" % [largos])

	# Os três números, nos extremos.
	var apertados := PackedStringArray()
	for caso: Array in [[tela.numero_atomico, "Z = 118"], [tela.numero_de_massa, "A = 295"], [tela.carga, "CARGA +118"],
			[tela.carga, "CARGA -118"], [tela.legenda_da_carga, tela.TXT_NEUTRO], [tela.legenda_da_carga, tela.TXT_CATION]]:
		var label: Label = caso[0]
		var largura := FONTE.get_string_size(String(caso[1]), HORIZONTAL_ALIGNMENT_LEFT, -1,
			label.get_theme_font_size("font_size")).x
		if largura > label.size.x:
			apertados.append("%s: %.0f de %.0f" % [caso[1], largura, label.size.x])
	_checar(apertados.is_empty(), "Z, A e a carga cabem até com três algarismos %s" % [apertados])

	# A linha "na natureza": de todos os isótopos que existem, e a do instável.
	var cortados := PackedStringArray()
	var mais_linhas := 0
	for z: int in Elementos.ISOTOPOS_NATURAIS:
		for massa: int in Elementos.ISOTOPOS_NATURAIS[z]:
			tela.montar(z, massa - z, z)
			mais_linhas = maxi(mais_linhas, tela.na_natureza.get_line_count())
			if not _cabe_inteiro(tela.na_natureza):
				cortados.append(Elementos.nome_do_isotopo(z, massa))
	tela.montar(104, 163, 104)
	if not _cabe_inteiro(tela.na_natureza):
		cortados.append("instável")
	tela.montar(0, 5, 5)
	if not _cabe_inteiro(tela.na_natureza):
		cortados.append("sem prótons")
	_checar(cortados.is_empty(), "a linha \"na natureza\" cabe inteira para todo isótopo (até %d linhas) %s" \
		% [mais_linhas, cortados])
	tela.montar(0, 0, 0)

	print("  . as setas")
	var nomes: Array = []
	for qual: String in tela.seletores:
		nomes.append((tela.seletores[qual] as SeletorParticula).get_node("Nome").text)
	_checar(nomes == ["Prótons", "Nêutrons", "Elétrons"], "três seletores: prótons, nêutrons e elétrons %s" % [nomes])
	var setas: Array[Rect2] = []
	var dentro := true
	for qual: String in tela.seletores:
		for prefixo: String in ["mais_", "menos_"]:
			_checar(tela.tem_alvo(prefixo + qual) and tela.alvo_disponivel(prefixo + qual), "o alvo %s existe" % (prefixo + qual))
			var caixa: Rect2 = tela.retangulo_do_alvo(prefixo + qual)
			if not vidro.encloses(caixa) or caixa.size.x < 30.0 or caixa.size.y < 30.0:
				dentro = false
			setas.append(caixa)
	var cobertas := false
	for i in setas.size():
		for j in range(i + 1, setas.size()):
			if setas[i].intersects(setas[j]):
				cobertas = true
	_checar(dentro, "as seis setas ficam dentro do vidro e têm tamanho de clicar")
	_checar(not cobertas, "nenhuma seta cobre a outra")
	_checar(tela.tem_alvo("limpar") and not tela.alvo_disponivel("limpar"), "LIMPAR só vale com alguma partícula")
	await _foto("monte_1_vazio")
	await _fechar(tela)


func _testar_a_montagem() -> void:
	print("\n--- MONTANDO ---")
	var tela := await _abrir(CENA)
	await _esperar(0.4)

	await _clicar(tela, "mais_protons")
	_checar(tela.protons == 1 and tela.nome.text == "HIDROGÊNIO-1" and tela.caixa.numero_atomico == 1,
		"um próton: na mesma hora é o HIDROGÊNIO-1, com a caixa do H")
	_checar(tela.numero_atomico.text == "Z = 1" and tela.numero_de_massa.text == "A = 1" and tela.carga.text == "CARGA +1" \
		and tela.legenda_da_carga.text == tela.TXT_CATION, "Z = 1, A = 1, CARGA +1: é um cátion")
	_checar(tela.notacao.visible and tela.notacao.simbolo == "H" and tela.notacao.massa == 1 \
		and tela.notacao.numero_atomico == 1 and tela.notacao.carga == 1, "a notação mostra o H com 1, 1 e +")
	_checar(tela.computador.texto_do_rodape() == "1 PRÓTON: HIDROGÊNIO" and tela.computador.avisando(),
		"o terminal diz: 1 PRÓTON: HIDROGÊNIO")
	_checar(_tocou(tela, "pop"), "a partícula que entra faz o estalo")
	_checar(tela.atomo.protons() == 1 and tela.atomo.no_nucleo(AtomoCamadas.PROTON) == 1, "o próton aparece no núcleo do desenho")
	_checar(tela.na_natureza.text.contains("PRÓTIO") and tela.na_natureza.text.contains("99,99%"),
		"na natureza: é o prótio, 99,99%% do hidrogênio (\"%s\")" % tela.na_natureza.text)
	_checar(tela.computador.led.color == ComputadorDoLaboratorio.COR_LED_ATENCAO, "íon: a luzinha fica amarela")
	_checar(tela.alvo_disponivel("limpar"), "com partícula, LIMPAR passa a valer")

	await _clicar(tela, "mais_eletrons")
	_checar(tela.eletrons == 1 and tela.carga.text == "CARGA 0" and tela.legenda_da_carga.text == tela.TXT_NEUTRO \
		and tela.notacao.carga == 0, "um elétron: a carga zera, o átomo fica neutro")
	_checar(tela.computador.led.color == ComputadorDoLaboratorio.COR_LED_CERTO, "neutro e existe na natureza: luzinha verde")
	_checar(tela.atomo.eletrons_por_camada() == PackedInt32Array([1]), "o elétron vai para a camada K do desenho")
	await _foto("monte_2_hidrogenio")

	await _clicar(tela, "mais_neutrons")
	_checar(tela.nome.text == "HIDROGÊNIO-2" and tela.numero_de_massa.text == "A = 2" and tela.caixa.numero_atomico == 1,
		"um nêutron: continua hidrogênio, agora o HIDROGÊNIO-2")
	_checar(tela.na_natureza.text.contains("DEUTÉRIO"), "que é o deutério (\"%s\")" % tela.na_natureza.text)
	await _clicar(tela, "mais_neutrons")
	_checar(tela.na_natureza.text.contains("TRÍTIO") and tela.na_natureza.text.contains(tela.TXT_INSTAVEL) \
		and tela.computador.led.color == ComputadorDoLaboratorio.COR_LED_ATENCAO,
		"com dois nêutrons é o trítio, instável: luzinha amarela")

	# O carbono-12, clicando.
	await _clicar(tela, "mais_protons", 5)
	await _clicar(tela, "mais_neutrons", 4)
	await _clicar(tela, "mais_eletrons", 5)
	_checar(tela.protons == 6 and tela.neutrons == 6 and tela.eletrons == 6 and tela.nome.text == "CARBONO-12",
		"6 prótons, 6 nêutrons e 6 elétrons: CARBONO-12")
	_checar(tela.caixa.numero_atomico == 6 and tela.numero_atomico.text == "Z = 6" and tela.numero_de_massa.text == "A = 12" \
		and tela.carga.text == "CARGA 0", "a caixa do C, Z = 6, A = 12, CARGA 0")
	_checar(tela.atomo.eletrons_por_camada() == PackedInt32Array([2, 4]) \
		and tela.atomo.no_nucleo(AtomoCamadas.PROTON) == 6 and tela.atomo.no_nucleo(AtomoCamadas.NEUTRON) == 6,
		"no desenho: 6 e 6 no núcleo, 2 elétrons na K e 4 na L")
	_checar(tela.na_natureza.text.contains("98,9") and tela.na_natureza.text.contains("CARBONO"),
		"na natureza: quase 99%% do carbono é assim (\"%s\")" % tela.na_natureza.text)
	_checar(tela.massa() == 12 and tela.carga_do_atomo() == 0 and tela.tipo_de_carga() == tela.TXT_NEUTRO,
		"massa() = 12, carga_do_atomo() = 0")
	await _esperar(0.5)
	await _foto("monte_3_carbono")

	await _clicar(tela, "menos_eletrons", 2)
	_checar(tela.eletrons == 4 and tela.carga.text == "CARGA +2" and tela.atomo.eletrons_por_camada() == PackedInt32Array([2, 2]),
		"tirar dois elétrons: CARGA +2, e eles saem da camada de fora")
	_checar(_tocou(tela, "tirar"), "tirar faz o som de tirar")
	await _clicar(tela, "menos_protons")
	_checar(tela.nome.text == "BORO-11" and tela.caixa.numero_atomico == 5 \
		and tela.computador.texto_do_rodape() == "5 PRÓTONS: BORO", "tirar um próton troca o elemento na hora: BORO-11")

	print("  . de uma vez")
	tela.montar(11, 12, 10)
	_checar(tela.nome.text == "SÓDIO-23" and tela.carga.text == "CARGA +1" and tela.legenda_da_carga.text == tela.TXT_CATION \
		and tela.notacao.simbolo == "Na" and tela.notacao.massa == 23 and tela.notacao.carga == 1,
		"Na+: SÓDIO-23, CARGA +1, cátion")
	_checar(tela.na_natureza.text == tela.TXT_TODOS_ASSIM % "SÓDIO", "todo sódio da natureza é sódio-23")
	_checar(tela.atomo.eletrons_por_camada() == PackedInt32Array([2, 8]), "com 10 elétrons: 2 e 8")
	await _esperar(0.5)
	await _foto("monte_4_sodio_ion")
	tela.montar(17, 18, 18)
	_checar(tela.carga.text == "CARGA -1" and tela.legenda_da_carga.text == tela.TXT_ANION and tela.notacao.carga == -1,
		"Cl-: CARGA -1, ânion")
	tela.montar(0, 3, 2)
	_checar(tela.nome.text == tela.TXT_SEM_PROTONS and tela.caixa.numero_atomico == 0 and not tela.notacao.visible \
		and tela.legenda_da_carga.text.is_empty(), "nêutrons e elétrons sem próton: NENHUM ELEMENTO, a caixa em branco")
	_checar(tela.na_natureza.text == tela.TXT_EXPLICA_SEM_PROTONS, "e o quadro explica: sem prótons não há elemento")
	_checar(tela.numero_atomico.text == "Z = 0" and tela.numero_de_massa.text == "A = 3" and tela.carga.text == "CARGA -2",
		"mas as contas continuam: Z = 0, A = 3, CARGA -2")
	_checar(tela.computador.led.color == ComputadorDoLaboratorio.COR_LED_PARADO, "e a luzinha volta ao vermelho")
	tela.montar(92, 146, 92)
	await _esperar(0.6)
	_checar(tela.nome.text == "URÂNIO-238" and tela.atomo.eletrons_por_camada() == Elementos.camadas(92),
		"o urânio-238 inteiro: as 7 camadas no desenho")
	var fora := _labels_fora_do_lugar(tela.computador, tela.computador.retangulo_do_vidro())
	_checar(fora.is_empty(), "com o átomo grande, todo texto continua no lugar %s" % [fora])
	await _foto("monte_5_uranio")
	await _fechar(tela)


func _testar_os_limites() -> void:
	print("\n--- OS LIMITES ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	await _clicar(tela, "menos_protons")
	await _clicar(tela, "menos_neutrons")
	await _clicar(tela, "menos_eletrons")
	_checar(tela.protons == 0 and tela.neutrons == 0 and tela.eletrons == 0 and not tela.computador.avisando(),
		"a seta de baixo com a conta em zero não faz nada")

	tela.montar(999, 999, 999)
	_checar(tela.protons == 118 and tela.neutrons == 177 and tela.eletrons == 118,
		"montar() prende nos limites: 118 prótons, 177 nêutrons, 118 elétrons")
	_checar(tela.nome.text == "OGANESSÔNIO-295", "o maior átomo da tela: OGANESSÔNIO-295")
	var casos := {"protons": tela.TXT_PROTONS_DEMAIS, "neutrons": tela.TXT_NEUTRONS_DEMAIS, "eletrons": tela.TXT_ELETRONS_DEMAIS}
	for qual: String in casos:
		var antes: int = tela.quantas(qual)
		await _clicar(tela, "mais_" + qual)
		_checar(tela.quantas(qual) == antes and tela.computador.texto_do_rodape() == casos[qual] \
			and tela.computador.avisando() and _tocou(tela, "erro"),
			"passar do limite de %s é recusado: \"%s\"" % [qual, casos[qual]])
	# A conta que tremeu volta para o lugar.
	await _esperar(0.5)
	var no_lugar := true
	for qual: String in tela.seletores:
		var conta: Label = (tela.seletores[qual] as SeletorParticula).quantos
		if not conta.position.is_equal_approx(conta.get_meta("pos_base")):
			no_lugar = false
	_checar(no_lugar, "a conta treme e volta para o lugar")
	tela.alterar("nada", 1)
	_checar(tela.protons == 118 and tela.neutrons == 177 and tela.eletrons == 118, "um seletor que não existe é ignorado")
	await _foto("monte_6_limite")
	await _fechar(tela)


func _testar_o_mouse() -> void:
	print("\n--- SEGURAR, RODA E LIMPAR ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	var seta: Vector2 = tela.retangulo_do_alvo("mais_neutrons").get_center()
	_mover_o_mouse(seta)
	_checar(tela.alvo_em_foco() == "mais_neutrons", "o mouse em cima da seta põe o foco nela")
	# (Sem janela não há ponteiro para conferir.)
	if DisplayServer.get_name() != "headless":
		_checar(Input.get_current_cursor_shape() == Input.CURSOR_POINTING_HAND, "e o ponteiro vira a mãozinha")
	_botao_do_mouse(seta, true)
	_checar(tela.neutrons == 1 and tela.alvo_segurado() == "mais_neutrons", "apertar põe um nêutron na hora")
	await _esperar(1.2)
	var segurando: int = tela.neutrons
	_checar(segurando >= 5, "segurando, a seta repete (%d nêutrons em 1,2 s)" % segurando)
	_botao_do_mouse(seta, false)
	await _esperar(0.3)
	_checar(tela.neutrons == segurando and tela.alvo_segurado().is_empty(), "soltando, para")

	# Segurar e arrastar para fora da seta também para.
	_botao_do_mouse(seta, true)
	_mover_o_mouse(seta + Vector2(0, -160))
	var arrastado: int = tela.neutrons
	await _esperar(0.7)
	_checar(tela.neutrons == arrastado, "tirar o mouse de cima da seta segurada também para")
	_botao_do_mouse(seta + Vector2(0, -160), false)
	if DisplayServer.get_name() != "headless":
		_checar(Input.get_current_cursor_shape() == Input.CURSOR_ARROW, "e fora dos alvos o ponteiro volta a ser a seta")

	# A roda do mouse em cima de um seletor.
	var em_cima: Vector2 = (tela.seletores["protons"] as Control).get_global_rect().get_center()
	_rodar_o_mouse(em_cima, true)
	_rodar_o_mouse(em_cima, true)
	_checar(tela.protons == 2, "a roda para cima em cima dos prótons põe prótons")
	_rodar_o_mouse(em_cima, false)
	_checar(tela.protons == 1, "a roda para baixo tira")
	var antes := [tela.protons, tela.neutrons, tela.eletrons]
	_rodar_o_mouse(tela.atomo.get_global_rect().get_center(), true)
	_checar([tela.protons, tela.neutrons, tela.eletrons] == antes, "a roda fora dos seletores não faz nada")

	# Um clique fora de qualquer alvo não faz nada.
	await _clicar_em(tela.atomo.get_global_rect().get_center())
	_checar([tela.protons, tela.neutrons, tela.eletrons] == antes, "um clique no desenho do átomo não mexe em nada")

	await _clicar(tela, "limpar")
	_checar(tela.protons == 0 and tela.neutrons == 0 and tela.eletrons == 0 and tela.nome.text == tela.TXT_VAZIO \
		and tela.caixa.numero_atomico == 0, "LIMPAR tira tudo de uma vez")
	_checar(tela.computador.texto_do_rodape() == tela.TXT_INSTRUCAO and not tela.alvo_disponivel("limpar"),
		"o rodapé volta à instrução e LIMPAR deixa de valer")
	_checar(tela.atomo.protons() == 0 and tela.atomo.eletrons_por_camada().is_empty(), "o desenho também esvazia")
	await _fechar(tela)


func _testar_o_controle() -> void:
	print("\n--- NO CONTROLE ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	_checar(tela.usa_cursor() and tela.is_in_group(CursorVirtual.GRUPO), "a tela usa o cursor do controle")
	_checar(tela.alvos_do_cursor().size() == 6, "vazia, o cursor para nas seis setas")
	tela.montar(1, 0, 0)
	_checar(tela.alvos_do_cursor().size() == 7, "com partícula, também no LIMPAR")
	var dicas: Array = tela.dicas_do_controle()
	_checar(dicas.any(func(d: Array) -> bool: return d[0] == "fechar" and d[1] == "VOLTAR") \
		and dicas.any(func(d: Array) -> bool: return d[0] == "cruz"), "a barra diz o que o ✕ e o △ fazem %s" % [dicas])

	# O ✕ é o clique: o cursor em cima da seta e um toque.
	await _tocar_no_controle(JOY_BUTTON_DPAD_UP)
	_checar(Controle.em_uso and CursorVirtual.ativo(), "um toque no controle liga o cursor")
	await _levar_o_cursor(tela.retangulo_do_alvo("mais_eletrons").get_center())
	await _tocar_no_controle(JOY_BUTTON_A)
	_checar(tela.eletrons == 1, "✕ em cima da seta dos elétrons põe um elétron (%d)" % tela.eletrons)
	# Segurando o ✕, repete.
	await _levar_o_cursor(tela.retangulo_do_alvo("mais_neutrons").get_center())
	_botao_do_controle(JOY_BUTTON_A, true)
	await _esperar(1.2)
	var segurando: int = tela.neutrons
	_botao_do_controle(JOY_BUTTON_A, false)
	await _esperar(0.3)
	_checar(segurando >= 5 and tela.neutrons == segurando, "segurando o ✕, a seta repete e, soltando, para (%d)" % segurando)
	# O analógico leva o cursor e não mexe em mais nada.
	var antes := [tela.protons, tela.neutrons, tela.eletrons]
	var onde := CursorVirtual._pos
	_eixo_do_controle(JOY_AXIS_LEFT_Y, -1.0)
	await _esperar(0.25)
	_eixo_do_controle(JOY_AXIS_LEFT_Y, 0.0)
	await _quadros(3)
	_checar(CursorVirtual._pos.y < onde.y - 20.0 and [tela.protons, tela.neutrons, tela.eletrons] == antes,
		"o analógico leva o cursor para cima, sem pôr nem tirar partícula")
	await _voltar_ao_teclado()
	_checar(not Controle.em_uso and not CursorVirtual.ativo(), "uma tecla devolve a tela ao teclado")
	await _fechar(tela)


func _testar_a_saida() -> void:
	print("\n--- SAIR ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	var saiu := [false]
	tela.saindo.connect(func() -> void: saiu[0] = true)
	tela.montar(6, 6, 6)
	await _teclar(KEY_ESCAPE)
	_checar(saiu[0] and tela.de_saida() and TransicaoDeCena.em_curso(), "ESC pede para sair: a cortina começa a fechar")
	await _clicar(tela, "mais_protons")
	_checar(tela.protons == 6, "de saída, a tela não responde a mais nada")
	_checar(tela.alvos_do_cursor().is_empty(), "nem oferece alvo ao cursor do controle")
	var chegou := await _esperar_a_troca()
	_checar(chegou == TransicaoDeCena.CENA_LABORATORIO, "e a cena que chega é o menu do Laboratório (%s)" % chegou)
	await _fechar(tela)
