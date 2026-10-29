extends "res://tools/teste_de_tela.gd"

# Teste do COMPRESSOR DE AR do Laboratório (o simulador de gases):
#
#   * O GÁS IDEAL (GasFechado com pode_condensar desligado): frio e apertado,
#     continua gás; pôr ou tirar ar não muda a temperatura, e a pressão vai
#     junto; vazio, a pressão é zero e nada quebra.
#   * A MÁQUINA (MaquinaDoSimulador), lei por lei, esperando o termostato
#     assentar: Boyle (metade do volume, o dobro da pressão), Gay-Lussac (o
#     dobro da temperatura em kelvin, o dobro da pressão), Avogadro (o dobro
#     de ar, o dobro da pressão), Charles (o êmbolo solto: o dobro da
#     temperatura, o dobro do volume, a pressão parada); P·V = n·R·T sempre; e
#     os três jeitos de estourar: apertando, esquentando e enchendo.
#   * A TELA (scripts/laboratorio/compressor.gd): a caixa sem o cilindro (a
#     altura do gás é a do volume, e as bolinhas ficam embaixo do êmbolo), as
#     peças e as fichas, as setas, o arrasto do êmbolo e do termômetro, a bomba
#     e o alívio no fundo da caixa (as bolinhas que passam pelo furo são o ar a
#     mais e a menos, e o ar que entra se espalha), o cadeado, as teclas, a
#     equação e as setinhas; estourar faz o êmbolo ceder, racha as paredes, e
#     no estrondo o êmbolo sai voando — só então vem o cartão; RECOMEÇAR monta
#     tudo de novo; o controle; toda letra existe na fonte.
#
#   godot --headless --path . res://tools/teste_compressor_do_laboratorio.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma imagem de cada
# momento.

const CENA := "res://scenes/laboratorio/compressor.tscn"
const QUADRO := 1.0 / 60.0


func _ready() -> void:
	await _comecar()
	_testar_o_gas()
	_testar_as_leis()
	_testar_os_estouros()
	await _testar_a_tela()
	await _testar_a_bomba_e_o_alivio()
	await _testar_o_cadeado()
	await _testar_as_teclas()
	await _testar_o_estouro_na_tela()
	await _testar_o_controle()
	await _testar_a_saida()
	_terminar()


# ─────────────────────────────────────────────────────────────
# O GÁS IDEAL
# ─────────────────────────────────────────────────────────────

func _testar_o_gas() -> void:
	print("\n--- O GÁS IDEAL ---")
	var g := GasFechado.new(1.0, 3.0, GasFechado.kelvin(-150.0))
	var com_liquido := GasFechado.new(1.0, 3.0, 84.0)
	g.pode_condensar = false
	g.definir_temperatura(GasFechado.kelvin(-150.0))
	_checar(com_liquido.fracao_liquida > 0.3 and g.fracao_liquida == 0.0 and _ideal(g),
		"só gás: o ar que viraria líquido continua gás, e P·V = n·R·T (%.2f atm a -150 °C em 3 L)" % g.pressao())
	var sem := GasFechado.new(1.0, 3.0, 84.0)
	sem.pode_condensar = false
	sem.definir_temperatura(84.0)
	_checar(sem.fracao_liquida == 0.0 and sem.copiar().pode_condensar == false, "a cópia continua só gás")
	var t := g.temperatura
	var p := g.pressao()
	g.mudar_quantidade(2.0)
	_checar(is_equal_approx(g.temperatura, t) and is_equal_approx(g.pressao(), p * 2.0),
		"o dobro de ar na mesma temperatura: o dobro da pressão")
	g.mudar_quantidade(0.0)
	g.trocar_calor_com(300.0, 10.0, 1.0)
	g.mudar_volume(5.0)
	_checar(g.pressao() == 0.0 and g.temperatura == 300.0 and is_finite(g.energia),
		"vazio: pressão zero, a temperatura de dentro é a do termostato, e nada quebra")
	g.mudar_quantidade(0.5)
	_checar(is_equal_approx(g.temperatura, 300.0) and _ideal(g), "enchendo de novo, o ar entra na temperatura de dentro")
	# Comprimir ainda esquenta (o trabalho do êmbolo), mesmo sem virar líquido.
	var adiabatico := GasFechado.new(1.0, 24.47, 298.15)
	adiabatico.pode_condensar = false
	for i in 400:
		adiabatico.mudar_volume(24.47 - 12.235 * (i + 1) / 400.0)
	_checar(absf(adiabatico.temperatura - 298.15 * pow(2.0, 0.4)) < 0.5,
		"apertar pela metade sem trocar calor esquenta de 298 K para %.1f K" % adiabatico.temperatura)


func _ideal(g: GasFechado) -> bool:
	return absf(g.pressao() * g.volume - g.mols * GasFechado.R * g.temperatura) < 1e-4 * maxf(g.pressao() * g.volume, 1.0)


# ─────────────────────────────────────────────────────────────
# A MÁQUINA: AS LEIS
# ─────────────────────────────────────────────────────────────

func _assentar(m: MaquinaDoSimulador, segundos: float) -> void:
	var t := 0.0
	while t < segundos and not m.estourado:
		m.avancar(QUADRO)
		t += QUADRO


func _perto(a: float, b: float, folga: float = 0.01) -> bool:
	return absf(a - b) <= absf(b) * folga


func _testar_as_leis() -> void:
	print("\n--- AS LEIS DOS GASES ---")
	var m := MaquinaDoSimulador.new()
	_checar(m.bolinhas == 50 and is_equal_approx(m.gas.mols, 1.0) and _perto(m.pressao(), 1.0)
		and _perto(m.gas.temperatura, 298.15, 0.0001) and _perto(m.volume(), 24.47, 0.001) and not m.gas.pode_condensar,
		"começa com 1 mol (50 bolinhas) do ar da sala: 1 atm, 25 °C, 24,47 L, só gás")

	# Boyle: metade do volume, o dobro da pressão (o termostato segura T).
	var p0 := m.pressao()
	m.mandar_embolo(MaquinaDoSimulador.posicao_do_volume(m.volume() * 0.5))
	_assentar(m, 6.0)
	_checar(_perto(m.pressao(), p0 * 2.0) and _perto(m.gas.temperatura, 298.15, 0.002),
		"Boyle: metade do volume, o dobro da pressão (%.3f atm), na mesma temperatura" % m.pressao())

	# O termostato leva o calor do trabalho do êmbolo na hora: andando, a
	# temperatura não sai do lugar, e a pressão só sobe.
	m.reiniciar()
	m.mandar_embolo(0.6)
	var desvio := 0.0
	var p_antes := m.pressao()
	var so_subiu := true
	for i in 150:
		m.avancar(QUADRO)
		desvio = maxf(desvio, absf(m.gas.temperatura - 298.15))
		if m.pressao() < p_antes - 1e-9:
			so_subiu = false
		p_antes = m.pressao()
	_checar(desvio < 0.01 and so_subiu,
		"isotérmica: com o êmbolo descendo, a temperatura não sai de 298 K (%.3f K) e a pressão só sobe" % desvio)

	# Gay-Lussac: o dobro da temperatura em kelvin, o dobro da pressão.
	m.reiniciar()
	m.pedir_temperatura(298.15 * 2.0)
	_assentar(m, 5.0)
	_checar(_perto(m.pressao(), 2.0) and _perto(m.gas.temperatura, 596.3, 0.002),
		"Gay-Lussac: de 25 °C para 323 °C (o dobro em kelvin), o dobro da pressão (%.3f atm)" % m.pressao())

	# Avogadro: o dobro de ar, o dobro da pressão.
	m.reiniciar()
	m.mudar_bolinhas(50)
	_checar(m.bolinhas == 100 and is_equal_approx(m.gas.mols, 2.0) and _perto(m.pressao(), 2.0)
		and _perto(m.gas.temperatura, 298.15, 0.0001),
		"Avogadro: o dobro de ar, o dobro da pressão (%.3f atm), na mesma temperatura" % m.pressao())
	m.mudar_bolinhas(-1000)
	_checar(m.bolinhas == 0 and m.pressao() == 0.0, "tirando tudo, a pressão vai a zero (e não passa de zero bolinha)")
	m.mudar_bolinhas(10000)
	_checar(m.bolinhas == MaquinaDoSimulador.BOLINHAS_MAXIMAS, "nem passa do máximo (%d)" % m.bolinhas)

	# Charles: o êmbolo solto segura a pressão; o dobro da temperatura, o
	# dobro do volume.
	m.reiniciar()
	m.mandar_embolo(MaquinaDoSimulador.posicao_do_volume(10.0))
	_assentar(m, 6.0)
	var p_presa := m.pressao()
	m.soltar_embolo()
	_checar(m.embolo_solto and _perto(m.pressao_segurada, p_presa), "o cadeado aberto segura a pressão de agora")
	m.pedir_temperatura(298.15 * 2.0)
	_assentar(m, 8.0)
	_checar(_perto(m.volume(), 20.0) and _perto(m.pressao(), p_presa),
		"Charles: o dobro da temperatura, o dobro do volume (%.2f L), e a pressão parada (%.3f atm)" % [m.volume(), m.pressao()])
	m.mudar_bolinhas(-25)
	_assentar(m, 6.0)
	_checar(_perto(m.volume(), 10.0) and _perto(m.pressao(), p_presa),
		"solto, tirar metade do ar leva o volume pela metade (%.2f L)" % m.volume())
	m.mandar_embolo(m.posicao)
	_checar(not m.embolo_solto, "pegar no êmbolo trava de novo")

	# P·V = n·R·T vale em qualquer momento (o gás é ideal). As faixas não
	# chegam a estourar: 1,2 mol a 200 °C em 15 L dão 3,1 atm.
	var sempre := true
	var falhou := ""
	m.reiniciar()
	for i in 600:
		if i % 60 == 0:
			m.mandar_embolo(randf_range(0.0, 0.4))
			m.pedir_celsius(randf_range(-150.0, 200.0))
		if i % 20 == 0:
			m.mudar_bolinhas(randi_range(-3, 3))
		if i % 120 == 0:
			if m.embolo_solto:
				m.travar_embolo()
			else:
				m.soltar_embolo()
		m.avancar(QUADRO)
		if (m.estourado or not _ideal(m.gas)) and falhou.is_empty():
			falhou = " (quadro %d: %.3f atm, %.2f L, %.3f mol, %.1f K)" % [i, m.pressao(), m.volume(), m.gas.mols, m.gas.temperatura]
			sempre = false
	_checar(sempre, "mexendo em tudo ao acaso por 10 s, P·V = n·R·T o tempo todo" + falhou)
	m.reiniciar()
	m.pedir_celsius(-400.0)
	_checar(is_equal_approx(GasFechado.para_celsius(m.temperatura_pedida), MaquinaDoSimulador.TERMOSTATO_MINIMO),
		"o termostato não desce de %d °C" % roundi(MaquinaDoSimulador.TERMOSTATO_MINIMO))
	m.pedir_celsius(5000.0)
	_checar(is_equal_approx(GasFechado.para_celsius(m.temperatura_pedida), MaquinaDoSimulador.TERMOSTATO_MAXIMO),
		"nem passa de %d °C" % roundi(MaquinaDoSimulador.TERMOSTATO_MAXIMO))


func _testar_os_estouros() -> void:
	print("\n--- OS TRÊS JEITOS DE ESTOURAR ---")
	var m := MaquinaDoSimulador.new()
	var estourou := [0.0]
	m.estourou.connect(func(p: float) -> void: estourou[0] = p)
	m.mandar_embolo(1.0)
	_assentar(m, 12.0)
	_checar(m.estourado and m.volume() > 5.0 and m.volume() < 7.0,
		"apertando: 1 mol a 25 °C estoura com %.1f L (a conta dá 6,1 L)" % m.volume())
	_checar(estourou[0] > MaquinaDeCompressao.PRESSAO_DE_RUPTURA, "e avisa com a pressão (%.2f atm)" % estourou[0])

	m.reiniciar()
	m.pedir_celsius(MaquinaDoSimulador.TERMOSTATO_MAXIMO)
	_assentar(m, 12.0)
	_checar(m.estourado and m.gas.celsius() > 880.0 and m.gas.celsius() < 960.0,
		"esquentando: 1 mol na câmara cheia estoura a %d °C (a conta dá 919 °C)" % roundi(m.gas.celsius()))

	m.reiniciar()
	var t := 0.0
	while not m.estourado and t < 40.0:
		m.mudar_bolinhas(5)
		_assentar(m, 0.2)
		t += 0.2
	_checar(m.estourado and m.gas.mols > 3.8 and m.gas.mols < 4.3,
		"enchendo: a câmara cheia a 25 °C estoura com %.2f mol (a conta dá 4)" % m.gas.mols)
	var antes := m.bolinhas
	m.mudar_bolinhas(5)
	m.pedir_celsius(0.0)
	m.mandar_embolo(0.0)
	_checar(m.bolinhas == antes and not m.embolo_solto, "estourado, nada mais obedece")

	# Frio, cabe muito mais ar antes de estourar, mas nunca o máximo da bomba.
	m.reiniciar()
	m.pedir_celsius(MaquinaDoSimulador.TERMOSTATO_MINIMO)
	_assentar(m, 3.0)
	var no_frio := 4.0 * m.volume() / (GasFechado.R * m.gas.temperatura)
	_checar(no_frio < MaquinaDoSimulador.BOLINHAS_MAXIMAS * MaquinaDoSimulador.MOL_POR_BOLINHA,
		"no mais frio, a câmara cheia estoura com %.1f mol, antes do máximo da bomba (%d mol)" \
		% [no_frio, roundi(MaquinaDoSimulador.BOLINHAS_MAXIMAS * MaquinaDoSimulador.MOL_POR_BOLINHA)])


# ─────────────────────────────────────────────────────────────
# A TELA
# ─────────────────────────────────────────────────────────────

func _testar_a_tela() -> void:
	print("\n--- A TELA ---")
	var tela := await _abrir(CENA)
	await _esperar(0.4)
	var maquina: MaquinaDoSimulador = tela.maquina
	var camara: CamaraDoSimulador = tela.camara
	_checar(camara.maquina == maquina and camara.moleculas_na_maquina() == 50, "a câmara desenha a máquina: 50 bolinhas")
	var contas := CamaraDeCompressao.contas_do_ar(100)
	_checar(contas == {"N2": 78, "O2": 21, "Ar": 1}, "o mol de ar da fase continua 78 N₂ + 21 O₂ + 1 Ar")
	for alvo: String in ["embolo", "trava", "embolo_sobe", "embolo_desce", "bomba", "alivio", "mais_ar", "menos_ar",
			"termometro", "mais_quente", "mais_frio", "recomecar"]:
		_checar(tela.tem_alvo(alvo), "o alvo '%s' existe" % alvo)
	_checar(not tela.alvo_disponivel("embolo_sobe") and tela.alvo_disponivel("embolo_desce"),
		"com o êmbolo no alto, só a seta de descer vale (a de subir fica apagada: %.1f)" % tela.setas_embolo.botao_mais.modulate.a)
	_checar(tela.texto_do_valor("P") == "1,00 atm" and tela.texto_do_valor("V") == "24,5 L"
		and tela.texto_do_valor("n") == "1,00 mol" and tela.texto_do_valor("T") == "298 K" and tela.texto_do_valor("R") == "0,082",
		"a equação começa com 1,00 atm · 24,5 L = 1,00 mol · 0,082 · 298 K")
	var textos := _textos_do_script(tela)
	for letra: String in ["P", "V", "n", "T"]:
		textos.append(tela.texto_do_valor(letra))
	textos.append(tela.TXT_PASSOU % 4)
	_checar(_letras_que_faltam(textos).is_empty(), "toda letra dos textos existe na fonte: '%s'" % _letras_que_faltam(textos))

	# As fichas: uma por peça, sem encostar em nada.
	var fichas: Array[Rect2] = []
	for letra: String in ["V", "n", "T", "P"]:
		var meio: Vector2 = tela.meio_da_ficha_na_maquina(letra)
		fichas.append(Rect2(meio - Vector2.ONE * tela.LADO_DA_FICHA * 0.5, Vector2.ONE * tela.LADO_DA_FICHA))
	var livres := true
	for i in fichas.size():
		if not Rect2(Vector2.ZERO, tela.size).grow(-8.0).encloses(fichas[i]) or fichas[i].intersects(tela.retangulo_do_titulo()):
			livres = false
		for alvo: String in ["embolo_sobe", "menos_ar", "termometro", "mais_quente", "recomecar", "bomba", "alivio"]:
			if fichas[i].intersects(tela.retangulo_do_alvo(alvo)):
				livres = false
	_checar(livres, "as fichas das letras ficam na tela, fora do título e das setas")
	var equacao: Rect2 = tela.EQUACAO
	_checar(equacao.end.y <= tela.size.y - 16.0 and not equacao.intersects(tela.retangulo_do_alvo("recomecar"))
		and not equacao.intersects(tela.setas_termometro.get_global_rect()),
		"a equação cabe embaixo, sem encostar nas setas nem no RECOMEÇAR")
	var colunas_cabem := true
	for letra: String in ["P", "V", "n", "T"]:
		var ficha: Rect2 = tela.retangulo_da_ficha_na_equacao(letra)
		if not equacao.encloses(ficha) or PecasDoLaboratorio.largura("10,00 mol", tela.TAM_DOS_NUMEROS) > 150.0:
			colunas_cabem = false
	_checar(colunas_cabem, "cada ficha e cada número cabem na coluna dele")
	await _foto("compressor_lab_1_inicio")

	# As setas do êmbolo.
	await _clicar(tela, "embolo_desce", 10)
	_checar(is_equal_approx(maquina.alvo, 0.2) and _tocou(tela, "passo"), "a seta de baixo desce o êmbolo (20%% em 10 toques)")
	await _esperar(0.3)
	_checar(tela.tendencia("V") == -1 and tela.tendencia("P") == 1 and tela.tendencia("T") == 0 and tela.tendencia("n") == 0,
		"descendo o êmbolo, a setinha do V aponta para baixo e a do P para cima (e T e n paradas)")
	await _foto("compressor_lab_2_setinhas")
	await _esperar(2.0)
	_checar(tela.tendencia("V") == 0 and tela.tendencia("P") == 0, "parado, sem setinha")
	var caixa := CamaraDeCompressao.CAMARA
	var altura_certa := caixa.size.y * maquina.volume() / MaquinaDeCompressao.VOLUME_TOTAL
	_checar(absf(caixa.end.y - camara._y_do_embolo - altura_certa) < 1.0,
		"sem cilindro, a altura do gás embaixo do êmbolo é a do volume (%.1f L: %d px da caixa)" \
		% [maquina.volume(), roundi(altura_certa)])
	var embaixo := true
	for m in camara._moleculas:
		if m.pos.y < camara._y_do_embolo or m.pos.y > caixa.end.y:
			embaixo = false
	_checar(embaixo, "todas as bolinhas estão na caixa, embaixo do êmbolo")
	await _clicar(tela, "embolo_sobe", 10)
	_checar(is_equal_approx(maquina.alvo, 0.0), "a de cima sobe de volta")
	await _esperar(1.6)

	# O arrasto do cabo.
	var cabo: Rect2 = camara.retangulo_de_pegar_o_embolo_na_tela()
	var pega := Vector2(cabo.get_center().x, cabo.position.y + 12.0)
	_mover_o_mouse(pega)
	_botao_do_mouse(pega, true)
	await _quadros(2)
	_mover_o_mouse(pega + Vector2(0, 140))
	await _quadros(2)
	_botao_do_mouse(pega + Vector2(0, 140), false)
	await _quadros(2)
	var curso_certo := MaquinaDoSimulador.posicao_do_volume((caixa.size.y - 140.0) / caixa.size.y * MaquinaDeCompressao.VOLUME_TOTAL)
	_checar(absf(maquina.alvo - curso_certo) < 0.02,
		"arrastar o cabo 140 px para baixo deixa 148 px de gás: %d%% do curso (a conta: %d%%)" \
		% [roundi(maquina.alvo * 100.0), roundi(curso_certo * 100.0)])
	maquina.mandar_embolo(0.0)
	await _esperar(2.0)

	# As setas do termômetro e o arrasto do ponteiro (com a câmara cheia: assim
	# esquentar não estoura).
	await _clicar(tela, "mais_quente")
	_checar(is_equal_approx(GasFechado.para_celsius(maquina.temperatura_pedida), 26.0), "a seta do termômetro sobe 1 °C por toque")
	var seta: Vector2 = tela.retangulo_do_alvo("mais_quente").get_center()
	_mover_o_mouse(seta)
	_botao_do_mouse(seta, true)
	await _esperar(2.4)
	_botao_do_mouse(seta, false)
	var segurado := GasFechado.para_celsius(maquina.temperatura_pedida)
	_checar(segurado > 100.0 and fmod(segurado, 5.0) == 0.0,
		"segurando a seta, o passo cresce e o número fica redondo (%d °C)" % roundi(segurado))
	var termometro: Termometro = tela.termometro
	var no_tubo := termometro.global_position.x + termometro.size.x * 0.5
	var ponto := Vector2(no_tubo, termometro.global_position.y + termometro.altura_de(500.0))
	_mover_o_mouse(ponto)
	_botao_do_mouse(ponto, true)
	await _quadros(2)
	_botao_do_mouse(ponto, false)
	_checar(absf(GasFechado.para_celsius(maquina.temperatura_pedida) - 500.0) <= 3.0, "clicar no tubo na altura de 500 °C pede 500 °C")
	await _esperar(2.5)
	_checar(absf(maquina.gas.celsius() - GasFechado.para_celsius(maquina.temperatura_pedida)) < 3.0,
		"e o gás vai atrás (%d °C)" % roundi(maquina.gas.celsius()))
	await _foto("compressor_lab_3_quente")
	await _fechar(tela)


func _testar_a_bomba_e_o_alivio() -> void:
	print("\n--- A BOMBA E O ALÍVIO ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	var maquina: MaquinaDoSimulador = tela.maquina
	var camara: CamaraDoSimulador = tela.camara
	await _passar_por(tela, "bomba")
	await _quadros(1)
	_checar(tela.letra_em_foco() == "n" and camara.bomba_em_foco, "o ponteiro na bomba acende ela e a ficha do n")
	await _foto("compressor_lab_4a_foco_na_bomba")
	await _passar_por(tela, "mais_quente")
	_checar(tela.letra_em_foco() == "T", "nas setas do termômetro, acende a do T")
	await _clicar(tela, "bomba")
	await _clicar(tela, "bomba")
	_checar(camara.moleculas_no_cano() == 5 and maquina.bolinhas == 50,
		"uma bombada: 5 moléculas no cano (a segunda, com o cabo ainda descendo, não conta), e o ar ainda não entrou")
	await _foto("compressor_lab_4_bombada")
	await _esperar(1.1)
	_checar(maquina.bolinhas == 55 and camara.moleculas_na_maquina() == 55 and camara.moleculas_no_cano() == 0
		and tela.texto_do_valor("n") == "1,10 mol",
		"passando pelo furo, cada uma é ar a mais: 1,10 mol, 55 bolinhas")
	var contas := {}
	for m in camara._moleculas:
		contas[m.chave] = int(contas.get(m.chave, 0)) + 1
	var na_proporcao := true
	for chave: String in GasFechado.COMPOSICAO:
		if absf(int(contas.get(chave, 0)) - float(GasFechado.COMPOSICAO[chave]) * 55.0) > 1.0:
			na_proporcao = false
	_checar(na_proporcao, "as novas seguem a mistura do ar (%s)" % contas)
	_checar(_perto(maquina.pressao(), 1.1, 0.01), "e a pressão vai junto: %.2f atm" % maquina.pressao())
	# Segurando a seta de cima do n, bombada atrás de bombada.
	var seta: Vector2 = tela.retangulo_do_alvo("mais_ar").get_center()
	_mover_o_mouse(seta)
	_botao_do_mouse(seta, true)
	await _esperar(2.0)
	_botao_do_mouse(seta, false)
	await _esperar(1.1)
	_checar(maquina.bolinhas >= 75 and maquina.bolinhas % 5 == 0,
		"segurando a seta, a bomba não para (%d bolinhas)" % maquina.bolinhas)
	await _esperar(2.0)
	var na_esquerda := 0
	for m in camara._moleculas:
		if m.pos.x < CamaraDeCompressao.CAMARA.get_center().x:
			na_esquerda += 1
	var parte: float = float(na_esquerda) / camara.moleculas_na_maquina()
	_checar(parte > 0.35 and parte < 0.65,
		"o ar que entra pelo fundo, à esquerda, se espalha pela caixa: %d%% das bolinhas na metade esquerda" \
		% roundi(parte * 100.0))
	# O alívio.
	var antes := maquina.bolinhas
	await _clicar(tela, "alivio")
	_checar(camara.moleculas_no_cano() == 5, "o alívio solta 5 moléculas")
	await _esperar(0.25)
	await _foto("compressor_lab_5_alivio")
	await _esperar(1.0)
	_checar(maquina.bolinhas == antes - 5 and camara.moleculas_na_maquina() == antes - 5 and camara.moleculas_no_cano() == 0,
		"elas saem pelo furo e o ar diminui (%d bolinhas)" % maquina.bolinhas)
	# Esvaziar tudo: a seta de baixo apaga.
	maquina.mudar_bolinhas(-maquina.bolinhas + 3)
	camara.reiniciar()
	await _clicar(tela, "menos_ar")
	await _esperar(1.5)
	_checar(maquina.bolinhas == 0 and maquina.pressao() == 0.0 and not tela.alvo_disponivel("menos_ar")
		and not tela.alvo_disponivel("alivio"),
		"sem ar: pressão zero, e o alívio e a seta de baixo apagam")
	_checar(tela.texto_do_valor("P") == "0,00 atm" and tela.texto_do_valor("n") == "0,00 mol", "a equação mostra 0,00 atm e 0,00 mol")
	await _fechar(tela)


func _testar_o_cadeado() -> void:
	print("\n--- O CADEADO ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	var maquina: MaquinaDoSimulador = tela.maquina
	maquina.mandar_embolo(MaquinaDoSimulador.posicao_do_volume(12.0))
	await _esperar(4.5)
	var p := maquina.pressao()
	await _clicar(tela, "trava")
	_checar(maquina.embolo_solto and _tocou(tela, "botao"), "clicar no cadeado abre a trava")
	await _foto("compressor_lab_6_solto")
	tela.pedir_celsius(150.0)
	await _esperar(3.0)
	_checar(maquina.volume() > 16.0 and _perto(maquina.pressao(), p, 0.02),
		"solto, esquentar sobe o êmbolo (%.1f L) e a pressão fica (%.2f atm)" % [maquina.volume(), maquina.pressao()])
	await _foto("compressor_lab_7_charles")
	await _clicar(tela, "trava")
	_checar(not maquina.embolo_solto, "clicar de novo fecha")
	await _clicar(tela, "trava")
	await _clicar(tela, "embolo_desce")
	_checar(not maquina.embolo_solto, "a seta do êmbolo trava de novo e anda")
	await _fechar(tela)


func _testar_as_teclas() -> void:
	print("\n--- O TECLADO ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	var maquina: MaquinaDoSimulador = tela.maquina
	_tecla(KEY_S, true)
	await _esperar(0.5)
	_tecla(KEY_S, false)
	_checar(maquina.alvo > 0.1, "S segurado desce o êmbolo (%d%%)" % roundi(maquina.alvo * 100.0))
	_tecla(KEY_D, true)
	await _esperar(0.5)
	_tecla(KEY_D, false)
	_checar(GasFechado.para_celsius(maquina.temperatura_pedida) > 60.0, "D segurado esquenta")
	await _teclar(KEY_E)
	_checar(tela.camara.moleculas_no_cano() == 5, "E bombeia")
	await _esperar(1.1)
	await _teclar(KEY_Q)
	_checar(tela.camara.moleculas_no_cano() == 5, "Q solta ar")
	await _teclar(KEY_SPACE)
	_checar(maquina.embolo_solto, "ESPAÇO abre o cadeado")
	await _teclar(KEY_R)
	await _esperar(0.2)
	_checar(not maquina.embolo_solto and maquina.bolinhas == 50 and maquina.alvo == 0.0 and _tocou(tela, "tirar"),
		"R recomeça")
	await _fechar(tela)


func _testar_o_estouro_na_tela() -> void:
	print("\n--- O ESTOURO ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	var maquina: MaquinaDoSimulador = tela.maquina
	var camara: CamaraDoSimulador = tela.camara
	tela.pedir_celsius(400.0)
	maquina.mandar_embolo(0.6)
	var rangeu := [false]
	camara.rangeu.connect(func() -> void: rangeu[0] = true)
	await _esperar_ate(func() -> bool: return maquina.faixa_da_pressao() >= 1 or maquina.estourado, 8.0)
	await _foto("compressor_lab_8_perigo")
	await _esperar_ate(func() -> bool: return camara.esta_explodindo(), 8.0)
	_checar(maquina.estourado and tela.estourou() and rangeu[0], "esquentado e apertado, a caixa range e estoura")
	_checar(not tela.alvo_disponivel("bomba") and not tela.alvo_disponivel("embolo") and not tela.alvo_disponivel("mais_quente"),
		"estourando, nada mais responde")
	var antes_de_ceder: float = camara._y_do_embolo
	await _esperar(0.8)
	await _foto("compressor_lab_9a_cedendo")
	_checar(camara._y_do_embolo < antes_de_ceder - 3.0 and not camara.embolo_voou(),
		"antes do estrondo, o êmbolo cede (%.0f px) e as paredes racham" % (antes_de_ceder - camara._y_do_embolo))
	await _esperar_ate(func() -> bool: return tela._clarao > 0.0, 4.0)
	_checar(camara.embolo_voou(), "no estrondo, o êmbolo sai voando")
	var saiu_de: Vector2 = camara._embolo_voando["pos"]
	await _esperar(0.15)
	await _foto("compressor_lab_9_estrondo")
	_checar((camara._embolo_voando["pos"] as Vector2).y < saiu_de.y - 60.0, "para cima")
	_checar(tela.retangulo_do_recomecar() == tela.BOTAO_RECOMECAR and not tela.cartao_aberto(), "o cartão espera a explosão acabar")
	await _esperar_ate(func() -> bool: return tela.cartao_aberto(), 8.0)
	await _esperar(0.5)
	await _foto("compressor_lab_10_estourou")
	_checar((camara._embolo_voando["pos"] as Vector2).y <= CamaraDoSimulador.EMBOLO_SUMIU,
		"e não volta a cair: com o cartão na tela, ele já sumiu pelo alto")
	_checar(tela.CARTAO_DO_ESTOURO.encloses(tela.retangulo_do_recomecar()), "acabada a explosão, o RECOMEÇAR vem para o cartão")
	await _clicar(tela, "recomecar")
	await _esperar(0.3)
	_checar(not maquina.estourado and not tela.estourou() and maquina.bolinhas == 50 and camara.moleculas_na_maquina() == 50
		and not camara.esta_explodindo() and not camara.embolo_voou() and _perto(maquina.pressao(), 1.0)
		and tela.position == Vector2.ZERO,
		"RECOMEÇAR monta a máquina de novo, com o êmbolo no lugar")
	await _foto("compressor_lab_11_de_novo")
	await _fechar(tela)


func _testar_o_controle() -> void:
	print("\n--- NO CONTROLE ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	var maquina: MaquinaDoSimulador = tela.maquina
	await _tocar_no_controle(JOY_BUTTON_DPAD_UP)
	_checar(Controle.em_uso and CursorVirtual.ativo() and tela.usa_cursor(), "um toque no controle liga o cursor")
	await _levar_o_cursor(tela.retangulo_do_alvo("bomba").get_center())
	await _tocar_no_controle(JOY_BUTTON_A)
	_checar(tela.camara.moleculas_no_cano() == 5, "✕ na bomba bombeia")
	# Segurando o ✕ no cabo, o êmbolo vai com o cursor.
	var cabo: Rect2 = tela.camara.retangulo_de_pegar_o_embolo_na_tela()
	await _levar_o_cursor(Vector2(cabo.get_center().x, cabo.position.y + 12.0))
	_botao_do_controle(JOY_BUTTON_A, true)
	await _quadros(3)
	_eixo_do_controle(JOY_AXIS_LEFT_Y, 1.0)
	await _esperar(0.25)
	_eixo_do_controle(JOY_AXIS_LEFT_Y, 0.0)
	await _quadros(3)
	_botao_do_controle(JOY_BUTTON_A, false)
	await _quadros(3)
	_checar(maquina.alvo > 0.1, "segurando o ✕ no cabo e descendo o cursor, o êmbolo desce (%d%%)" % roundi(maquina.alvo * 100.0))
	await _voltar_ao_teclado()
	await _fechar(tela)


func _testar_a_saida() -> void:
	print("\n--- SAIR ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	await _teclar(KEY_ESCAPE)
	_checar(tela.de_saida() and TransicaoDeCena.em_curso(), "ESC pede para sair")
	var chegou := await _esperar_a_troca()
	_checar(chegou == TransicaoDeCena.CENA_LABORATORIO, "e a cena que chega é o menu do Laboratório")
	await _fechar(tela)
