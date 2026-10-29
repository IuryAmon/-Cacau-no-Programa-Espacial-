extends "res://tools/teste_de_tela.gd"

# Teste dos tutoriais da mochila de N₂ e do maçarico: a ficha que sobe depois
# da ficha de coleta (scripts/ui/tutorial_ferramenta.gd) e as telinhas
# animadas deles (scenes/ui/demo_mochila.tscn e scenes/ui/demo_macarico.tscn).
# O do bumerangue tem o teste dele (tools/teste_tutorial_bumerangue.tscn).
#
#   * o catálogo: as duas têm tutorial, com telinha, e a frase marca a tecla
#     ({dash}, {interact}) em vez de escrevê-la;
#   * a frase sai com a tecla do dispositivo em uso: SHIFT e o E desenhado no
#     teclado, o R2 e o □ desenhados no controle — e troca sozinha, com a
#     ficha aberta, quando a pessoa troca de um para o outro; nenhuma linha
#     passa da largura, contando o desenho do botão;
#   * a telinha da mochila: parada na beirada, a tecla afunda, o congelamento,
#     o arranco por cima do vão (esticada, azul, fantasmas, jato) e a freada
#     do outro lado, no piso; e tudo recomeça na beirada;
#   * a telinha do maçarico: parada, a tecla afunda, a pose da chama, a porta
#     esquenta, escorre quadro a quadro e esfria; ela guarda o maçarico; e a
#     porta volta inteira na volta seguinte;
#   * no jogo: o FerramentasHUD abre cada ficha com a telinha certa e fecha com
#     a tecla de ação.
#
#   godot --headless --path . res://tools/teste_tutoriais_ferramentas.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma imagem de cada
# ficha e de cada momento das telinhas.

const DEMO_MOCHILA := "res://scenes/ui/demo_mochila.tscn"
const DEMO_MACARICO := "res://scenes/ui/demo_macarico.tscn"
## O passo do relógio das telinhas, avançadas à mão (sem esperar o tempo real).
const PASSO := 1.0 / 60.0


func _ready() -> void:
	await _comecar()
	_testar_catalogo()
	await _voltar_ao_teclado()
	await _testar_frase("mochila", "SHIFT", "r2", DemoMochila)
	await _testar_frase("macarico", "", "quadrado", DemoMacarico)
	await _testar_mochila()
	await _testar_macarico()
	await _testar_no_jogo()
	_terminar()


# ─────────────────────────────────────────────────────────────
# APOIO
# ─────────────────────────────────────────────────────────────

## Avança o relógio da telinha "segundos", em passos de um quadro.
func _avancar(demo: DemoDeFerramenta, segundos: float) -> void:
	var passos := int(ceilf(segundos / PASSO))
	for i in passos:
		demo._process(PASSO)


## Avança até o instante "t" da volta (sem dar a volta).
func _ate(demo: DemoDeFerramenta, t: float) -> void:
	_avancar(demo, t - demo._tempo)


func _de_controle() -> void:
	_botao_do_controle(JOY_BUTTON_DPAD_UP, true)
	await _quadros(2)
	_botao_do_controle(JOY_BUTTON_DPAD_UP, false)
	await _quadros(3)


## Tem piso (um tile) embaixo deste ponto do mundo da telinha?
func _piso_em(cenario: TileMapLayer, ponto: Vector2) -> bool:
	var celula := cenario.local_to_map((ponto - cenario.position) / cenario.scale)
	return cenario.get_cell_source_id(celula) != -1


func _linhas_cabem(ficha: TutorialFerramenta) -> bool:
	for linha in ficha.linhas_do_texto():
		if EstiloHUD.largura_com_icones(FONTE, linha, TutorialFerramenta.TAM_TEXTO) > ficha.largura_do_texto() + 0.5:
			return false
	return true


## A telinha sozinha, ampliada, para conferir o desenho.
func _foto_da_telinha(demo: DemoDeFerramenta, nome: String) -> void:
	if _pasta_capturas.is_empty() or DisplayServer.get_name() == "headless":
		return
	var antes := demo.scale
	demo.scale = Vector2(3, 3)
	await _foto(nome)
	demo.scale = antes


# ─────────────────────────────────────────────────────────────
# OS TESTES
# ─────────────────────────────────────────────────────────────

func _testar_catalogo() -> void:
	print("\n--- O CATÁLOGO ---")
	var mochila := CatalogoFerramentas.tutorial("mochila")
	var macarico := CatalogoFerramentas.tutorial("macarico")
	_checar(String(mochila.get("texto", "")).contains("{dash}") and not String(mochila.get("texto", "")).contains("SHIFT"),
		"a frase da mochila marca a tecla do dash ({dash}), e não escreve SHIFT")
	_checar(String(macarico.get("texto", "")).contains("{interact}"), "a frase do maçarico marca a tecla da interação")
	_checar(String(mochila.get("demo", "")) == DEMO_MOCHILA and ResourceLoader.exists(DEMO_MOCHILA),
		"a mochila tem a telinha dela")
	_checar(String(macarico.get("demo", "")) == DEMO_MACARICO and ResourceLoader.exists(DEMO_MACARICO),
		"o maçarico tem a telinha dele")
	# O "₂" do N₂ vem da fonte do sistema, como em todo o jogo (H₂, O₂...).
	var faltando := _letras_que_faltam([String(mochila.get("texto", "")).replace("₂", ""), macarico.get("texto", "")])
	_checar(faltando.is_empty(), "a fonte do jogo tem todas as letras das frases%s" % ("" if faltando.is_empty() else " (faltam: %s)" % faltando))
	_checar(BotoesControle.nome_da_acao(DemoMochila.ACAO) == "r2" and BotoesControle.tecla_da_acao(DemoMochila.ACAO) == "SHIFT",
		"a tecla da telinha da mochila é o SHIFT do teclado e o R2 do controle")
	_checar(BotoesControle.nome_da_acao(DemoMacarico.ACAO) == "quadrado" and BotoesControle.tecla_da_acao(DemoMacarico.ACAO) == "E",
		"a do maçarico é o E do teclado e o □ do controle")


func _testar_frase(habilidade: String, escrita_no_teclado: String, botao: String, classe: Variant) -> void:
	print("\n--- A FICHA DE %s ---" % habilidade.to_upper())
	var ficha := TutorialFerramenta.new()
	ficha.fonte = FONTE
	add_child(ficha)
	await _quadros(1)
	ficha.abrir(CatalogoFerramentas.tutorial(habilidade))
	await _quadros(2)

	var tecla := BotoesControle.tecla_da_acao(DemoMochila.ACAO if habilidade == "mochila" else DemoMacarico.ACAO)
	var frase := ficha.frase()
	if escrita_no_teclado.is_empty():
		_checar(frase.contains(BotoesControle.caractere("tecla_" + tecla.to_lower())) and not frase.contains("{"),
			"no teclado a frase leva a tecla %s desenhada" % tecla)
	else:
		_checar(frase.contains(escrita_no_teclado) and not BotoesControle.tem_icone(frase) and not frase.contains("{"),
			"no teclado a frase diz %s (a tecla não tem desenho)" % escrita_no_teclado)
	_checar(_linhas_cabem(ficha), "nenhuma linha passa da largura da telinha: %s" % [ficha.linhas_do_texto()])
	var quadro := ficha.retangulo_da_ficha()
	_checar(Rect2(Vector2.ZERO, ficha.size).encloses(quadro), "a ficha cabe na tela %s" % quadro)
	var telinha := ficha.telinha()
	_checar(is_instance_of(telinha, classe), "a telinha é a cena da ferramenta")
	_checar(telinha != null and ficha.retangulo_da_telinha().size.is_equal_approx(telinha.size * 2.0),
		"ampliada no dobro do tamanho do jogo %s" % ficha.retangulo_da_telinha().size)

	await _de_controle()
	ficha.atualizar_teclas()
	frase = ficha.frase()
	var linhas := " ".join(ficha.linhas_do_texto())
	_checar(Controle.em_uso and frase.contains(BotoesControle.caractere(botao))
		and linhas.contains(BotoesControle.caractere(botao)) and (escrita_no_teclado.is_empty() or not frase.contains(escrita_no_teclado)),
		"de controle na mão, a frase leva o %s desenhado" % botao)
	_checar(_linhas_cabem(ficha), "e as linhas ainda cabem, contando o botão: %s" % [ficha.linhas_do_texto()])
	await _voltar_ao_teclado()
	ficha.queue_free()
	await _quadros(2)


func _testar_mochila() -> void:
	print("\n--- A TELINHA DA MOCHILA ---")
	var demo := (load(DEMO_MOCHILA) as PackedScene).instantiate() as DemoMochila
	add_child(demo)
	await _quadros(2)
	demo.set_process(false)
	demo.reiniciar()
	var cacau := demo.get_node("Mundo/Cacau") as AnimatedSprite2D
	var cenario := demo.get_node("Mundo/Cenario") as TileMapLayer
	var jato := demo.get_node("Mundo/Jato") as CPUParticles2D
	var fantasmas := demo.get_node("Mundo/Fantasmas")
	var partida := cacau.position
	var chegada := partida + Vector2(DemoMochila.DISTANCIA_DASH + DemoMochila.DISTANCIA_SOBRA, 0.0)
	# Os pés: o meio do desenho mais metade do quadro (96 px na escala 1,5).
	var pes := Vector2(0.0, 72.0 + 2.0)

	_checar(_piso_em(cenario, partida + pes) and not _piso_em(cenario, partida.lerp(chegada, 0.5) + pes)
		and _piso_em(cenario, chegada + pes), "ela começa no piso, com um vão no caminho e piso do outro lado")
	_checar(demo.size.is_equal_approx(Vector2(300, 210)) and demo.scale.is_equal_approx(Vector2(2, 2)),
		"a telinha tem o tamanho da do bumerangue")

	_ate(demo, DemoMochila.T_APERTAR - 0.1)
	await _foto_da_telinha(demo, "mochila_1_parada")
	_checar(cacau.animation == &"idle" and cacau.position == partida and not demo.tecla_apertada()
		and not jato.emitting, "antes do toque ela está parada na beirada, respirando")

	_ate(demo, DemoMochila.T_APERTAR + 0.02)
	_checar(demo.tecla_apertada() and cacau.animation == DemoMochila.ANIM_DASH
		and cacau.modulate.is_equal_approx(FerramentasPlayer.COR_DASH)
		and cacau.scale.is_equal_approx(Vector2(1.5, 1.5) * DemoMochila.ESTICADA),
		"no toque a tecla afunda e ela já está na pose do dash: esticada e azul")
	_checar(cacau.position == partida, "e o mundo congela um instante antes do arranco")

	_ate(demo, DemoMochila.T_ARRANCAR + 0.09)
	var visiveis := fantasmas.get_children().filter(func(f: Node) -> bool: return f.visible)
	var atras := visiveis.all(func(f: Node) -> bool: return (f as Node2D).position.x <= cacau.position.x)
	_checar(cacau.position.x > partida.x + 40.0 and cacau.position.x < chegada.x and jato.emitting,
		"no meio do arranco ela está por cima do vão, com o jato soprando (x = %d)" % cacau.position.x)
	_checar(visiveis.size() >= 2 and atras, "e os fantasmas do dash ficam para trás (%d)" % visiveis.size())
	await _foto_da_telinha(demo, "mochila_2_arranco")

	_ate(demo, DemoMochila.T_PARADA + 0.3)
	_checar(demo.atravessou() and cacau.animation == &"idle" and cacau.modulate == Color.WHITE
		and cacau.position.is_equal_approx(chegada) and not jato.emitting,
		"depois ela freia do outro lado, no piso, e volta a ficar parada")
	_checar(fantasmas.get_children().all(func(f: Node) -> bool: return not f.visible), "e os fantasmas somem")
	await _foto_da_telinha(demo, "mochila_3_do_outro_lado")

	_avancar(demo, DemoMochila.T_FIM - demo._tempo + 0.05)
	_checar(cacau.position == partida and demo._tempo < 0.2, "a volta recomeça na beirada")
	demo.queue_free()
	await _quadros(2)


func _testar_macarico() -> void:
	print("\n--- A TELINHA DO MAÇARICO ---")
	var demo := (load(DEMO_MACARICO) as PackedScene).instantiate() as DemoMacarico
	add_child(demo)
	await _quadros(2)
	demo.set_process(false)
	demo.reiniciar()
	var cacau := demo.get_node("Mundo/Cacau") as AnimatedSprite2D
	var porta := demo.get_node("Mundo/Porta") as Sprite2D
	var derretimento := demo.get_node("Mundo/Derretimento") as AnimatedSprite2D
	var fagulhas := demo.get_node("Mundo/Fagulhas") as CPUParticles2D
	var tinta := porta.material as ShaderMaterial

	_checar(derretimento.material == porta.material and tinta != null
		and tinta.shader.resource_path == "res://shaders/metal_incandescente.gdshader",
		"a porta é a do jogo: a folha e o derretimento com o mesmo material de brasa")
	var porta_do_jogo := (load("res://scenes/fases/componentes/porta_metal_macarico.tscn") as PackedScene).instantiate()
	_checar(porta.texture == (porta_do_jogo.get_node("Porta") as Sprite2D).texture
		and derretimento.sprite_frames.get_frame_count(DemoMacarico.ANIM_PORTA) == 16,
		"com a arte da porta de verdade e os 16 quadros do derretimento")
	porta_do_jogo.free()

	_ate(demo, DemoMacarico.T_APERTAR - 0.1)
	await _foto_da_telinha(demo, "macarico_1_parada")
	_checar(cacau.animation == &"idle" and is_zero_approx(demo.calor()) and porta.visible and not derretimento.visible
		and not demo.chama_acesa(), "antes do toque ela está parada e a porta, fria e inteira")

	_ate(demo, DemoMacarico.T_ACESO + 0.02)
	_checar(demo.tecla_apertada() and cacau.animation == DemoMacarico.ANIM_MACARICO
		and cacau.frame == cacau.sprite_frames.get_frame_count(DemoMacarico.ANIM_MACARICO) - 1 and demo.chama_acesa(),
		"no toque ela acende o maçarico e baixa a máscara")

	_ate(demo, DemoMacarico.T_DERRETER - 0.03)
	_checar(demo.calor() > 0.9 and porta.visible and fagulhas.emitting,
		"a folha inteira esquenta até a brasa (calor %.2f)" % demo.calor())
	_checar(is_equal_approx(float(tinta.get_shader_parameter("calor")), demo.calor()), "e o shader acompanha")
	await _foto_da_telinha(demo, "macarico_2_brasa")

	_ate(demo, DemoMacarico.T_DERRETER + DemoMacarico.DURACAO_DERRETIMENTO * 0.5)
	_checar(derretimento.visible and not porta.visible and derretimento.frame >= 6 and derretimento.frame <= 9
		and float(tinta.get_shader_parameter("gradiente_vertical")) < DemoMacarico.GRADIENTE_INICIAL,
		"no meio do derretimento a folha escorre (quadro %d de 16)" % derretimento.frame)
	await _foto_da_telinha(demo, "macarico_3_derretendo")

	_ate(demo, DemoMacarico.T_CAIU + 0.02)
	_checar(demo.porta_derretida() and derretimento.frame == 15 and not fagulhas.emitting and not demo.chama_acesa(),
		"a folha vira poça e a chama apaga")
	_ate(demo, DemoMacarico.T_CAIU + DemoMacarico.DURACAO_GESTO + 0.05)
	_checar(cacau.animation == &"idle", "ela guarda o maçarico e volta a ficar parada")
	_ate(demo, DemoMacarico.T_FRIO + 0.05)
	_checar(is_zero_approx(demo.calor()) and derretimento.visible, "e a poça esfria de volta à cor de metal")
	await _foto_da_telinha(demo, "macarico_4_poca_fria")

	_avancar(demo, DemoMacarico.T_FIM - demo._tempo + 0.05)
	_checar(porta.visible and not derretimento.visible and is_zero_approx(demo.calor()) and cacau.animation == &"idle",
		"a volta recomeça com a porta inteira")
	demo.queue_free()
	await _quadros(2)


func _testar_no_jogo() -> void:
	print("\n--- NO JOGO ---")
	for habilidade: String in ["mochila", "macarico"]:
		FerramentasHUD.ensinar(habilidade)
		var ficha: TutorialFerramenta = FerramentasHUD._tutorial
		await _esperar_ate(func() -> bool: return ficha.pode_fechar(), 5.0)
		var telinha := ficha.telinha()
		_checar(FerramentasHUD.tutorial_aberto() and get_tree().paused
			and is_instance_of(telinha, DemoMochila if habilidade == "mochila" else DemoMacarico),
			"o tutorial de %s abre com a telinha dele e o jogo parado" % habilidade)
		var antes := ficha.linhas_do_texto()
		await _foto("tutorial_%s_teclado" % habilidade)
		await _de_controle()
		var botao := "r2" if habilidade == "mochila" else "quadrado"
		_checar(" ".join(ficha.linhas_do_texto()).contains(BotoesControle.caractere(botao)) and ficha.linhas_do_texto() != antes,
			"pegando o controle com a ficha aberta, a frase troca a tecla pelo %s" % botao)
		await _foto("tutorial_%s_controle" % habilidade)
		_botao_do_controle(JOY_BUTTON_A, true)
		await _quadros(2)
		_botao_do_controle(JOY_BUTTON_A, false)
		await _esperar_ate(func() -> bool: return not FerramentasHUD.tutorial_aberto(), 3.0)
		_checar(not FerramentasHUD.tutorial_aberto() and not get_tree().paused, "o ✕ fecha a ficha e o jogo segue")
		await _voltar_ao_teclado()
