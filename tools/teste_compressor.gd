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
#     inteira e só então avisa; toda letra existe na fonte.
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

