extends "res://tools/teste_de_tela.gd"

# Teste do compressor de ar da fase do nitrogênio:
#
#   * A FÍSICA (scripts/laboratorio/gas_fechado.gd): as pressões de vapor batem
#     com o NIST; o ar a 1 atm começa a pingar e termina de ferver nas
#     temperaturas dos livros; P·V = n·R·T; a compressão adiabática esquenta
#     exatamente o que a teoria diz (e a expansão devolve); virar líquido solta
#     calor; a primeira gota é mais rica em oxigênio;
#   * A MÁQUINA (scripts/laboratorio/maquina_de_compressao.gd): começa com o ar
#     da sala; apertar sem resfriar estoura o cilindro antes do fim; resfriando
#     dá para levar todo o ar ao cilindro, ele vira líquido, a amostra fica
#     pronta; fechada, ela aguenta um tempo que dá para correr até a coluna
#     (e quanto mais fria, mais tempo); esquentando, ela estoura em 4 atm;
#   * A TELA (scripts/puzzle_compressor.gd): as setas, o arrasto do êmbolo e do
#     termômetro, as teclas; o botão de fechar só acende com a amostra pronta;
#     fechar a válvula comemora e entrega a amostra; estourar toca a explosão
#     inteira e só então avisa; toda letra existe na fonte;
#   * NO MAPA (scripts/fases/compressor_de_ar.gd): na sala do compressor o E
#     não troca de tela — a Cacau sai da frente, a câmera chega perto e o
#     puzzle nasce em cima da arte da máquina, do tamanho dela; o raio X cobre
#     a arte e ela some; o cabo e o ponteiro do termômetro viram mãozinha e a
#     mão da dica mostra o gesto num e depois no outro; fechando, tudo volta, a
#     arte da sala mostra a máquina como ficou, e a amostra sai com a Cacau.
#
#   godot --headless --path . res://tools/teste_compressor.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma imagem de cada
# momento.

const CENA := "res://scenes/puzzle_compressor.tscn"


func _ready() -> void:
	await _comecar()
	_testar_fisica()
	_testar_maquina()
	await _testar_tela()
	await _testar_explosao()
	await _testar_no_mapa()
	_terminar()


# ─────────────────────────────────────────────────────────────
# A FÍSICA
# ─────────────────────────────────────────────────────────────

func _testar_fisica() -> void:
	print("\n--- A FÍSICA DO AR ---")
	# Pontos de ebulição a 1 atm (NIST): N₂ 77,36 K, O₂ 90,19 K, Ar 87,30 K.
	for dados in [["N2", 77.36], ["O2", 90.19], ["Ar", 87.30]]:
		var p := GasFechado.pressao_de_vapor(dados[0], dados[1])
		_checar(absf(p - 1.0) < 0.06, "%s ferve a %.2f K com %.3f atm (a 1 atm, ±6%%)" % [dados[0], dados[1], p])
	var orvalho := GasFechado.temperatura_de_orvalho(1.0)
	var bolha := GasFechado.temperatura_de_ebulicao(1.0)
	_checar(absf(orvalho - 81.6) < 1.5, "o ar a 1 atm começa a pingar a %.1f K (livros: 81,6 K)" % orvalho)
	_checar(absf(bolha - 78.8) < 1.5, "e termina de ferver a %.1f K (livros: 78,8 K)" % bolha)
	_checar(orvalho > bolha, "o ponto de orvalho fica acima do de bolha (é uma mistura)")

	var g := GasFechado.new(1.0, 24.47, 298.15)
	_checar(absf(g.pressao() - 1.0) < 0.01, "1 mol a 25 °C em 24,47 L: 1 atm (%.3f)" % g.pressao())
	_checar(absf(g.pressao() * g.volume - g.mols * GasFechado.R * g.temperatura) < 0.001, "P·V = n·R·T")

	# Compressão adiabática pela metade: T·V^(γ-1) constante, γ = 1,4.
	for i in 400:
		g.mudar_volume(24.47 - 12.235 * (i + 1) / 400.0)
	var esperado := 298.15 * pow(2.0, 0.4)
	_checar(absf(g.temperatura - esperado) < 0.5, "comprimir pela metade esquenta de 298 K para %.1f K (teoria: %.1f K)" % [g.temperatura, esperado])
	for i in 400:
		g.mudar_volume(12.235 + 12.235 * (i + 1) / 400.0)
	_checar(absf(g.temperatura - 298.15) < 0.5, "e expandir de volta esfria até onde estava (%.1f K)" % g.temperatura)

	# Virar líquido solta calor: o ar apertado e frio, com a mesma energia,
	# fica mais quente que o "tudo gás".
	var frio := GasFechado.new(1.0, 3.0, 84.0)
	_checar(frio.fracao_liquida > 0.3, "1 mol a 84 K em 3 L: ar líquido (%d%%)" % roundi(frio.fracao_liquida * 100.0))
	var energia_antes := frio.energia
	frio.trocar_calor(-300.0)
	_checar(frio.fracao_liquida > 0.4 and frio.temperatura < 84.0 and frio.temperatura > 80.0,
		"tirando 300 J, mais ar condensa e a temperatura quase não cai (o calor de vaporização segura): %.1f K, %d%%" \
		% [frio.temperatura, roundi(frio.fracao_liquida * 100.0)])
	_checar(is_equal_approx(frio.energia, energia_antes - 300.0), "a energia que saiu é a energia que falta")

	var gota := GasFechado.composicao_da_primeira_gota(80.0)
	_checar(float(gota["O2"]) > 0.45, "a primeira gota tem %d%% de oxigênio (o ar tem 21%%): ele condensa antes" % roundi(float(gota["O2"]) * 100.0))


# ─────────────────────────────────────────────────────────────
# A MÁQUINA
# ─────────────────────────────────────────────────────────────

func _testar_maquina() -> void:
	print("\n--- A MÁQUINA ---")
	var m := MaquinaDeCompressao.new()
	_checar(absf(m.pressao() - 1.0) < 0.01 and absf(m.gas.celsius() - 25.0) < 0.1,
		"começa com o ar da sala: 1 atm, 25 °C")
	_checar(absf(m.fracao_no_cilindro() - MaquinaDeCompressao.VOLUME_DO_CILINDRO / MaquinaDeCompressao.VOLUME_TOTAL) < 0.001,
		"o ar se espalha: %d%% dele está no cilindro (3 L de 24,47 L)" % roundi(m.fracao_no_cilindro() * 100.0))

	# Apertar sem resfriar: estoura antes do fim.
	var estourou := [false]
	m.estourou.connect(func(_p: float) -> void: estourou[0] = true)
	m.mandar_embolo(1.0)
	var t := 0.0
	while not m.estourado and t < 10.0:
		m.avancar(1.0 / 60.0)
		t += 1.0 / 60.0
	_checar(estourou[0] and m.posicao < 0.95, "apertar sem resfriar estoura o cilindro no meio do caminho (êmbolo em %d%%)" % roundi(m.posicao * 100.0))
	m.mandar_embolo(0.5)
	_checar(is_equal_approx(m.alvo, 1.0), "estourado, o êmbolo não obedece mais")

	# Resfriar, apertar devagar: todo o ar no cilindro, virando líquido.
	m.reiniciar()
	m.pedir_celsius(-200.0)
	_avancar(m, 5.0)
	_checar(m.gas.celsius() < -185.0, "5 s com o resfriador a −200 °C: o ar a %d °C" % roundi(m.gas.celsius()))
	m.mandar_embolo(1.0)
	var maior := 0.0
	t = 0.0
	while t < 14.0:
		m.avancar(1.0 / 60.0)
		maior = maxf(maior, m.pressao())
		t += 1.0 / 60.0
	_checar(not m.estourado and maior < MaquinaDeCompressao.PRESSAO_DE_RUPTURA,
		"frio, dá para apertar até o fim sem estourar (a pressão chegou a %.2f atm)" % maior)
	_checar(m.embolo_no_fim() and is_equal_approx(m.fracao_no_cilindro(), 1.0), "todo o ar no cilindro")
	_checar(m.gas.fracao_liquida >= MaquinaDeCompressao.FRACAO_LIQUIDA_DA_AMOSTRA,
		"e virando líquido (%d%%), a %d °C e %.2f atm" % [roundi(m.gas.fracao_liquida * 100.0), roundi(m.gas.celsius()), m.pressao()])
	_checar(m.amostra_pronta(), "a amostra está pronta")
	var aguenta := m.tempo_ate_estourar_se_fechar()
	_checar(aguenta > 25.0 and aguenta < 90.0, "fechada, ela aguentaria %.0f s (dá para correr, mas é apertado)" % aguenta)

	# Mais fria, aguenta mais.
	var menos_fria := m.gas.copiar()
	menos_fria.definir_temperatura(GasFechado.kelvin(-186.0))
	var mais_fria := m.gas.copiar()
	mais_fria.definir_temperatura(GasFechado.kelvin(-194.0))
	var t_menos := MaquinaDeCompressao.tempo_ate_estourar(menos_fria)
	var t_mais := MaquinaDeCompressao.tempo_ate_estourar(mais_fria)
	_checar(t_mais > t_menos + 5.0, "a −194 °C a amostra aguenta %.0f s; a −186 °C, %.0f s" % [t_mais, t_menos])

	var amostra := m.fechar_valvula()
	_checar(amostra != null and not m.valvula_aberta, "fechar a válvula solta a amostra")
	_checar(is_equal_approx(amostra.volume, MaquinaDeCompressao.VOLUME_DO_CILINDRO), "a amostra tem o volume do cilindro")
	var segundos := 0.0
	while amostra.pressao() < MaquinaDeCompressao.PRESSAO_DE_RUPTURA and segundos < 200.0:
		MaquinaDeCompressao.esquentar_amostra(amostra, 0.1)
		segundos += 0.1
	_checar(absf(segundos - aguenta) < 2.0, "esquentando, ela passa de 4 atm em %.1f s (previsto: %.0f s)" % [segundos, aguenta])
	_checar(amostra.fracao_liquida == 0.0, "e nessa hora o líquido já ferveu todo (%.0f °C)" % amostra.celsius())

	# Aquecer também estoura.
	var q := MaquinaDeCompressao.new()
	q.mandar_embolo(0.78)
	_avancar(q, 4.0)
	q.pedir_celsius(150.0)
	_avancar(q, 6.0)
	_checar(q.estourado, "com o êmbolo a três quartos do curso, aquecer a 150 °C estoura o cilindro (%.2f atm)" % q.pressao())


func _avancar(m: MaquinaDeCompressao, segundos: float) -> void:
	var t := 0.0
	while t < segundos and not m.estourado:
		m.avancar(1.0 / 60.0)
		t += 1.0 / 60.0


# ─────────────────────────────────────────────────────────────
# A TELA
# ─────────────────────────────────────────────────────────────

func _testar_tela() -> void:
	print("\n--- A TELA ---")
	var tela := await _abrir_compressor()
	await _foto("compressor_1_inicio")
	_checar(tela.maquina != null and tela.camara.maquina == tela.maquina, "a tela monta a máquina e a câmara desenha ela")
	for alvo in ["embolo", "embolo_sobe", "embolo_desce", "termometro", "mais_quente", "mais_frio", "fechar_valvula"]:
		_checar(tela.tem_alvo(alvo), "o alvo '%s' existe" % alvo)
	_checar(not tela.alvo_disponivel("fechar_valvula"), "FECHAR A VÁLVULA começa apagado")
	_checar(_letras_que_faltam(_textos_do_script(tela)).is_empty(), "toda letra dos textos existe na fonte: '%s'" % _letras_que_faltam(_textos_do_script(tela)))

	# As setas.
	await _clicar(tela, "embolo_desce", 5)
	await _esperar(0.6)
	_checar(tela.maquina.posicao > 0.05, "a seta de baixo aperta o êmbolo (%d%%)" % roundi(tela.maquina.posicao * 100.0))
	await _clicar(tela, "mais_frio", 3)
	_checar(is_equal_approx(GasFechado.para_celsius(tela.maquina.temperatura_pedida), 22.0), "a seta do resfriador desce 1 °C por toque")

	# Arrastar o termômetro até o fundo.
	var pegar := tela.retangulo_do_alvo("termometro")
	_mover_o_mouse(pegar.get_center())
	_botao_do_mouse(pegar.get_center(), true)
	await _quadros(2)
	_mover_o_mouse(Vector2(pegar.get_center().x, pegar.end.y + 40.0))
	await _quadros(2)
	_botao_do_mouse(Vector2(pegar.get_center().x, pegar.end.y + 40.0), false)
	await _quadros(2)
	_checar(GasFechado.para_celsius(tela.maquina.temperatura_pedida) < -195.0,
		"arrastar o ponteiro até embaixo pede %d °C" % roundi(GasFechado.para_celsius(tela.maquina.temperatura_pedida)))
	await _esperar(4.0)
	await _foto("compressor_2_frio")

	# Arrastar o cabo do êmbolo até o fim.
	var cabo := tela.retangulo_do_alvo("embolo")
	var de := Vector2(cabo.get_center().x, cabo.position.y + 10.0)
	_mover_o_mouse(de)
	_botao_do_mouse(de, true)
	await _quadros(2)
	_mover_o_mouse(de + Vector2(0, 600))
	await _quadros(2)
	_botao_do_mouse(de + Vector2(0, 600), false)
	_checar(tela.maquina.alvo > 0.99, "arrastar o cabo para baixo manda o êmbolo para o fim")
	await _esperar(3.5)
	await _foto("compressor_3_comprimido")
	await _esperar(7.0)
	await _foto("compressor_4_liquido")
	_checar(tela.camara.moleculas_liquidas() > 15, "as moléculas líquidas estão na poça (%d)" % tela.camara.moleculas_liquidas())
	_checar(tela.camara.moleculas_no_cilindro() == 100, "todas as 100 estão no cilindro")
	_checar(tela.alvo_disponivel("fechar_valvula"), "com a amostra pronta, FECHAR A VÁLVULA acende")

	var entregue := [null, 0.0]
	tela.amostra_fechada.connect(func(a: GasFechado, s: float) -> void:
		entregue[0] = a
		entregue[1] = s)
	await _clicar(tela, "fechar_valvula")
	_checar(not tela.maquina.valvula_aberta, "o botão fecha a válvula")
	await _esperar(1.8)
	await _foto("compressor_5_pronta")
	_checar(entregue[0] == null, "a comemoração espera a pessoa continuar")
	await _teclar(KEY_E)
	await _quadros(3)
	_checar(entregue[0] != null and float(entregue[1]) > 20.0, "o E entrega a amostra (%.0f s até estourar)" % float(entregue[1]))
	_checar(not is_instance_valid(tela) or tela.is_queued_for_deletion(), "e a tela da história se fecha sozinha")
	await _quadros(2)


func _testar_explosao() -> void:
	print("\n--- A EXPLOSÃO ---")
	var tela := await _abrir_compressor()
	var como := [{}]
	var avisou := [false]
	tela.cilindro_estourou.connect(func(c: Dictionary) -> void:
		avisou[0] = true
		como[0] = c)
	# Segurar S aperta o êmbolo sem parar (sem resfriar nada).
	_tecla(KEY_S, true)
	await _esperar_ate(func() -> bool: return tela.camara.esta_explodindo(), 8.0)
	_tecla(KEY_S, false)
	_checar(tela.camara.esta_explodindo(), "segurar S sem resfriar estoura o cilindro")
	await _esperar(0.7)
	await _foto("compressor_6_inchando")
	_checar(not avisou[0], "a tela de fim espera a explosão acontecer inteira")
	await _esperar_ate(func() -> bool: return tela._clarao > 0.0, 3.0)
	await _quadros(2)
	await _foto("compressor_7_estrondo")
	await _esperar(0.5)
	await _foto("compressor_8_estilhacos")
	await _esperar_ate(func() -> bool: return avisou[0], 6.0)
	_checar(avisou[0], "acabada a explosão, a tela avisa que o cilindro estourou")
	_checar(float(como[0].get("pressao", 0.0)) > MaquinaDeCompressao.PRESSAO_DE_RUPTURA,
		"com a pressão em que ele estourou (%.2f atm)" % float(como[0].get("pressao", 0.0)))
	await _fechar(tela)


func _abrir_compressor() -> TelaDoCompressor:
	var tela := (load(CENA) as PackedScene).instantiate() as TelaDoCompressor
	tela.modo_historia = true
	_escutar(tela)
	add_child(tela)
	await _quadros(3)
	return tela


# ─────────────────────────────────────────────────────────────
# NO MAPA
# ─────────────────────────────────────────────────────────────

func _testar_no_mapa() -> void:
	print("\n--- NO MAPA (a sala do compressor) ---")
	var sala := await _trocar_de_cena(MissaoNitrogenio.CENA_COMPRESSOR)
	var maquina := sala.get_node("CompressorDeAr") as CompressorDeAr
	var cacau := get_tree().get_first_node_in_group("player") as CharacterBody2D
	var A := ArteDoCompressor
	MissaoNitrogenio.maquina().reiniciar()
	MissaoNitrogenio.cilindro_acoplado = true
	MissaoNitrogenio.explicou_o_compressor = true
	TelaDoCompressor.arrastou_o_embolo = false
	TelaDoCompressor.arrastou_o_termometro = false
	# A Cacau bem na frente da máquina.
	cacau.global_position = maquina.global_position + Vector2(-30, -40)
	await _quadros(3)
	var cabo := maquina.get_node("Cabo") as Sprite2D
	var aparelho := maquina.get_node("Aparelho") as Sprite2D
	var cilindro := maquina.get_node("CilindroAcoplado") as Sprite2D
	_checar(cilindro.visible and aparelho.visible and cabo.visible, "a máquina da sala, com o cilindro preso no berço")
	var cabo_no_alto := cabo.position

	maquina.usar()
	await _esperar_ate(func() -> bool: return maquina.tela() != null, 8.0)
	var tela := maquina.tela()
	_checar(tela != null and get_tree().current_scene == sala, "o E abre o puzzle na própria sala, sem trocar de cena")
	if tela == null:
		return
	var recorte := maquina.recorte_no_mundo()
	_checar(cacau.global_position.x + 22.0 <= recorte.position.x,
		"a Cacau saiu da frente da máquina (x %.0f, a máquina começa em %.0f)" % [cacau.global_position.x, recorte.position.x])
	_checar(get_tree().paused and not cacau.pode_se_mover, "o jogo para e a Cacau não anda")
	var na_tela := get_viewport().get_canvas_transform() * recorte
	_checar(tela.no_mundo() and tela.aparelho_no_mundo.position.distance_to(na_tela.position) < 1.0
			and tela.aparelho_no_mundo.size.distance_to(na_tela.size) < 1.0,
		"o puzzle nasce em cima da arte da máquina, do tamanho dela (arte %s, tela %s)" % [na_tela, tela.aparelho_no_mundo])
	_checar(tela.camara.get_global_rect().is_equal_approx(tela.aparelho_no_mundo) and is_equal_approx(tela.camara.medidas.pixel, 8.0),
		"o raio X ocupa o lugar da arte, 8 px por pixel dela")
	_checar(tela.bloqueada, "enquanto a linha do raio X desce, a tela não responde")
	await _esperar_ate(func() -> bool: return not tela.bloqueada, 4.0)
	_checar(not tela.bloqueada and not aparelho.visible and not cabo.visible and not cilindro.visible,
		"coberta pelo raio X, a arte da máquina some (a base e o armário ficam)")
	_checar(maquina.get_node("Sprite").visible, "a estrutura continua à vista")

	# O mouse: em cima do cabo, a mãozinha; a mão da dica mostra o gesto nele.
	_checar(tela._alvo_da_dica() == "embolo", "a mão da dica mostra o gesto no cabo do êmbolo")
	var pegar := tela.retangulo_do_alvo("embolo")
	var de := Vector2(pegar.get_center().x, pegar.position.y + 10.0)
	_mover_o_mouse(de)
	await _quadros(2)
	_checar(tela.alvo_sob_o_ponteiro() == "embolo", "o mouse em cima do cabo acha o cabo")
	# (Sem janela não há ponteiro para conferir.)
	if DisplayServer.get_name() != "headless":
		_checar(Input.get_current_cursor_shape() == MaoDoMouse.CURSOR_DE_PEGAR, "em cima do cabo, o ponteiro vira a mão aberta")
	_botao_do_mouse(de, true)
	await _quadros(2)
	_mover_o_mouse(de + Vector2(0, 600))
	await _quadros(2)
	_checar(tela.arrastando_com_o_mouse, "arrastando o cabo, a tela sabe que o mouse está segurando")
	if DisplayServer.get_name() != "headless":
		_checar(Input.get_current_cursor_shape() == MaoDoMouse.CURSOR_SEGURANDO, "arrastando, a mão fechada")
	_botao_do_mouse(de + Vector2(0, 600), false)
	await _quadros(2)
	_checar(tela.maquina.alvo > 0.99, "arrastar o cabo para baixo manda o êmbolo para o fim (no mapa também)")
	_checar(tela._alvo_da_dica() == "termometro", "soltou o cabo: a mão da dica passa para o ponteiro do termômetro")
	var ponteiro := tela.termometro.retangulo_do_ponteiro_na_tela().get_center()
	_mover_o_mouse(ponteiro)
	await _quadros(2)
	_checar(tela.alvo_sob_o_ponteiro() == "termometro", "o mouse em cima do ponteiro do termômetro acha o termômetro")
	if DisplayServer.get_name() != "headless":
		_checar(Input.get_current_cursor_shape() == MaoDoMouse.CURSOR_DE_PEGAR, "em cima do ponteiro do termômetro, a mão aberta")
	# Tudo o que a tela desenha cabe na tela.
	var tela_toda := Rect2(Vector2.ZERO, Vector2(1600, 900))
	var pecas := {"equação": tela._painel_equacao, "objetivo": tela._painel_objetivo, "botão": tela._botao_fechar,
		"termômetro": tela.termometro.get_global_rect(), "setas do resfriador": tela.setas_resfriador.get_global_rect(),
		"setas do êmbolo": tela.setas_embolo.get_global_rect()}
	var fora := PackedStringArray()
	for nome: String in pecas:
		if not tela_toda.encloses(pecas[nome]):
			fora.append(nome)
	_checar(fora.is_empty(), "os painéis, o termômetro e as setas cabem na tela (fora: %s)" % ", ".join(fora))
	# Nada em cima da câmara nem do armário do resfriador (as setas do êmbolo
	# ficam no vão transparente da arte, ao lado do casco).
	var canto := tela.aparelho_no_mundo.position
	var maquina_na_tela: Array[Rect2] = [Rect2(canto + Vector2(A.CASCO.position) * 8.0, Vector2(A.CASCO.size) * 8.0),
		Rect2(canto + Vector2(A.ARMARIO.position) * 8.0, Vector2(A.ARMARIO.size) * 8.0)]
	var em_cima := PackedStringArray()
	for nome: String in pecas:
		for parte in maquina_na_tela:
			if (pecas[nome] as Rect2).intersects(parte) and not em_cima.has(nome):
				em_cima.append(nome)
	_checar(em_cima.is_empty(), "nenhum painel cobre a câmara nem o armário (em cima: %s)" % ", ".join(em_cima))
	# A Cacau, ao lado da máquina, fica à vista: nenhum painel na frente dela.
	var cacau_na_tela := get_viewport().get_canvas_transform() * _desenho_da_cacau(cacau)
	var na_frente := PackedStringArray()
	for nome: String in pecas:
		if (pecas[nome] as Rect2).intersects(cacau_na_tela):
			na_frente.append(nome)
	_checar(cacau_na_tela.has_area() and na_frente.is_empty(),
		"nenhum painel na frente da Cacau (ela em %s; na frente: %s)" % [cacau_na_tela, ", ".join(na_frente)])
	await _esperar(1.0)
	await _foto("compressor_9_no_mapa")

	# Fechar no meio (ESC): o raio X sai, a arte volta como a máquina ficou e
	# a câmera volta para a Cacau.
	var posicao := tela.maquina.posicao
	await _teclar(KEY_ESCAPE)
	await _esperar_ate(func() -> bool: return not maquina.puzzle_em_curso(), 6.0)
	_checar(not maquina.puzzle_em_curso() and not is_instance_valid(tela), "o ESC fecha o puzzle")
	_checar(not get_tree().paused and cacau.pode_se_mover, "o jogo volta e a Cacau anda de novo")
	_checar(get_viewport().get_camera_2d() == cacau.get_node("Camera2D"), "a câmera é a da Cacau de novo")
	_checar(aparelho.visible and cabo.visible and cilindro.visible, "a arte da máquina volta")
	var descida := A.descida_do_embolo(MissaoNitrogenio.maquina().posicao)
	_checar(descida > 0 and is_equal_approx(cabo.position.y, cabo_no_alto.y + descida * A.ESCALA_NO_MAPA),
		"o cabo do mapa ficou onde o êmbolo parou (%d px da arte abaixo)" % descida)

	# Abrir de novo: a máquina continua onde estava; a amostra pronta sai com
	# a Cacau, e o cilindro sai do berço.
	maquina.usar()
	await _esperar_ate(func() -> bool: return maquina.tela() != null and not maquina.tela().bloqueada, 8.0)
	tela = maquina.tela()
	_checar(tela != null and absf(tela.maquina.posicao - MissaoNitrogenio.maquina().posicao) < 0.001
			and tela.maquina.posicao >= posicao - 0.001,
		"abrindo de novo, o êmbolo está onde ficou (%d%%)" % roundi(MissaoNitrogenio.maquina().posicao * 100.0))
	if tela == null:
		return
	_checar(tela._alvo_da_dica() == "termometro", "a mão da dica lembra que o cabo já foi arrastado")
	tela.maquina.resolver_na_hora()
	tela.camara.reiniciar()
	await _esperar_ate(func() -> bool: return tela.pode_fechar(), 4.0)
	_checar(tela.pode_fechar(), "com a amostra pronta, o botão embaixo do resfriador acende")
	await _clicar(tela, "fechar_valvula")
	await _esperar_ate(func() -> bool: return tela._estado == TelaDoCompressor.Estado.PRONTA, 4.0)
	_checar(tela._estado == TelaDoCompressor.Estado.PRONTA, "o botão fecha a válvula e a tela comemora (estado %d)" % tela._estado)
	await _teclar(KEY_E)
	await _esperar_ate(func() -> bool: return not maquina.puzzle_em_curso(), 6.0)
	_checar(MissaoNitrogenio.carregando_amostra() and not MissaoNitrogenio.cilindro_acoplado,
		"a amostra pronta sai com a Cacau")
	_checar(not cilindro.visible, "e o berço do mapa fica vazio")
	TelaDoCompressor.arrastou_o_embolo = false
	TelaDoCompressor.arrastou_o_termometro = false


## Onde o desenho da Cacau está no mundo: os pixels não transparentes do
## quadro da animação de agora.
func _desenho_da_cacau(cacau: Node2D) -> Rect2:
	var sprite := cacau.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return Rect2()
	var quadro := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if quadro == null:
		return Rect2()
	var imagem := quadro.get_image()
	if imagem.is_compressed():
		imagem.decompress()
	var usado := Rect2(imagem.get_used_rect())
	var canto := sprite.offset - (Vector2(imagem.get_size()) * 0.5 if sprite.centered else Vector2.ZERO)
	return sprite.get_global_transform() * Rect2(canto + usado.position, usado.size)

