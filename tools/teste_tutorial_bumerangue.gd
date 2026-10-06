extends Node

# Teste do tutorial do bumerangue: a ficha que sobe logo depois da ficha de
# coleta (scripts/ui/tutorial_ferramenta.gd) e a telinha animada dela
# (scenes/ui/demo_bumerangue.tscn).
#
#   * o catálogo: só o bumerangue tem tutorial, e o texto é uma frase só;
#   * as teclas são as desenhadas da folha do teclado: o F existe ao lado do E,
#     com os quatro quadros de apertar, e é ele que o cinto, a ficha e a
#     telinha mostram (o □, de controle na mão);
#   * a ficha é limpa e se mede sozinha: a telinha, a frase embaixo dela e
#     mais nada escrito; cabe na tela e a frase não passa da largura;
#   * a telinha vai para a ficha AMPLIADA (o dobro do tamanho do jogo), e a
#     ficha cresce junto;
#   * o cenário da telinha é o do mapa: os mesmos tiles de parede e de piso da
#     fase, com os cabos subindo só em cima da caixa;
#   * a telinha conta a história inteira, em ordem: parada (idle), a tecla
#     afunda, a Cacau faz o gesto, o bumerangue vai até a caixa, a caixa
#     quebra, ele volta para a mão, a Cacau volta para a idle, e tudo recomeça
#     com a caixa inteira;
#   * na fase 1, de verdade: pegar o bumerangue abre a ficha de coleta; o E
#     fecha e sobe o tutorial, com o mundo parado; a tecla desenhada para sair
#     é o ESC, e o E também sai; apertados cedo demais, nenhum dos dois fecha;
#     de controle saem o △ e o □, e o □ que fecha não arremessa o bumerangue.
#
#   godot --headless --path . res://tools/teste_tutorial_bumerangue.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma imagem de cada
# momento na pasta, para conferir o desenho a olho.

const DEMO := "res://scenes/ui/demo_bumerangue.tscn"
const FASE := "res://scenes/fases/fase1_oficina.tscn"
const PLAYER := "res://scenes/player.tscn"
const TILESET := "res://assets/tilesets/tileset_fases.tres"
const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

const FRASE := "Jogue o bumerangue nas caixinhas para cortar os circuitos elétricos"

## Os tiles do level_tileset.png que o mapa usa: a placa rebitada da parede e
## a mesma placa com os cabos (as duas são blocos de 2×2 tiles).
const PLACA := Rect2i(16, 6, 2, 2)
const PLACA_COM_CABOS := Rect2i(14, 6, 2, 2)
## A fileira de cima do piso (a da faixa amarela).
const LINHA_DO_PISO := 0

## Passo do relógio da telinha quando o teste a conduz na mão.
const PASSO := 1.0 / 60.0

var _falhas := 0
var _pasta_capturas := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			_pasta_capturas = arg.trim_prefix("--capturas=")
	await get_tree().process_frame

	_testar_catalogo()
	await _testar_teclas()
	await _testar_ficha()
	await _testar_cenario()
	await _testar_telinha()
	await _testar_na_fase()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


# ─────────────────────────────────────────────────────────────

func _testar_catalogo() -> void:
	print("\n--- O CATALOGO ---")
	var dados := CatalogoFerramentas.tutorial("bumerangue")
	_checar(not dados.is_empty(), "o bumerangue tem tutorial")
	_checar(CatalogoFerramentas.tutorial("macarico").is_empty()
		and CatalogoFerramentas.tutorial("nao_existe").is_empty(),
		"ferramenta sem o campo (e ferramenta que nao existe) nao tem")
	_checar(dados.get("texto", "") == FRASE, "o texto e a frase pedida, e so ela")
	_checar(not dados.has("titulo") and not dados.has("etiqueta"),
		"sem titulo nem etiqueta: nada mais para escrever na ficha")
	_checar((dados.get("cor", Color.BLACK) as Color).is_equal_approx(CatalogoFerramentas.cor("bumerangue")),
		"a ficha leva a cor da ferramenta")
	_checar(ResourceLoader.exists(String(dados.get("demo", ""))), "a cena da telinha existe")
	_checar(InputMap.has_action(DemoBumerangue.ACAO)
		and BotoesControle.tecla_da_acao(DemoBumerangue.ACAO) == CatalogoFerramentas.tecla("bumerangue")
		and BotoesControle.nome_da_acao(DemoBumerangue.ACAO) == "quadrado",
		"a tecla da telinha e o F do teclado e o quadrado do controle")

	var faltando := ""
	for c in FRASE:
		if c != " " and not FONTE.has_char(c.unicode_at(0)) and not faltando.contains(c):
			faltando += c
	_checar(faltando.is_empty(), "toda letra da frase existe na fonte [%s]" % faltando)


# ─────────────────────────────────────────────────────────────

func _testar_teclas() -> void:
	print("\n--- AS TECLAS DESENHADAS (E e F) ---")
	var folha: Texture2D = BotoesControle.FOLHA_TECLADO
	var imagem := folha.get_image()
	for caso: Array in [["tecla_e", Vector2(96, 48)], ["tecla_f", Vector2(112, 64)]]:
		var nome: String = caso[0]
		var canto: Vector2 = caso[1]
		var certos := 0
		var desenhados := 0
		for quadro in BotoesControle.QUADROS_APERTANDO:
			var arte := BotoesControle.icone(nome, quadro) as AtlasTexture
			var esperado := Rect2(canto + BotoesControle.PASSO_QUADRO_TECLADO * quadro, Vector2(16, 16))
			if arte != null and arte.atlas == folha and arte.region == esperado:
				certos += 1
			if imagem.get_region(Rect2i(esperado)).get_used_rect().size.x >= 12:
				desenhados += 1
		_checar(BotoesControle.existe(nome) and BotoesControle.anima(nome)
			and certos == BotoesControle.QUADROS_APERTANDO and desenhados == certos,
			"%s esta na folha do teclado, com os 4 quadros de apertar" % nome)
	_checar(not _mesmos_pixels(imagem, Rect2i(96, 48, 16, 16), Rect2i(112, 64, 16, 16)),
		"e o desenho do F nao e o do E")
	_checar(BotoesControle.NOMES[-1] == "tecla_f"
		and BotoesControle.caractere("tecla_m").unicode_at(0) == BotoesControle.PRIMEIRO_CODIGO + 26,
		"o F entrou no FIM da lista: os botoes dos textos ja montados nao mudaram de codigo")

	_checar(EstiloHUD.desenho_da_tecla("F", &"arremessar") == "tecla_f",
		"no teclado, a tecla do bumerangue no HUD e o F desenhado")
	_checar(EstiloHUD.desenho_da_tecla("E", &"interact") == "tecla_e", "e a de continuar, o E desenhado")
	var sair := BotoesControle.tecla_da_acao(TutorialFerramenta.ACAO_FECHAR)
	_checar(sair == "ESC" and EstiloHUD.desenho_da_tecla(sair, TutorialFerramenta.ACAO_FECHAR) == "tecla_esc",
		"a tecla desenhada para sair do tutorial e o ESC")
	_checar(EstiloHUD.desenho_da_tecla("SHIFT", &"dash") == "",
		"tecla que ainda nao tem desenho (SHIFT) continua na tampa escrita")
	_botao(JOY_BUTTON_DPAD_UP, true)
	await _quadros(2)
	_botao(JOY_BUTTON_DPAD_UP, false)
	await _quadros(2)
	_checar(Controle.em_uso and EstiloHUD.desenho_da_tecla("F", &"arremessar") == "quadrado"
		and EstiloHUD.desenho_da_tecla("E", &"interact") == "quadrado",
		"de controle na mao, as duas viram o quadrado")
	_checar(EstiloHUD.desenho_da_tecla(sair, TutorialFerramenta.ACAO_FECHAR) == "triangulo",
		"e a de sair do tutorial vira o triangulo")
	_tecla(KEY_CTRL)
	await _quadros(3)
	_checar(not Controle.em_uso and EstiloHUD.desenho_da_tecla("F", &"arremessar") == "tecla_f",
		"de volta ao teclado, o F volta")


func _mesmos_pixels(imagem: Image, a: Rect2i, b: Rect2i) -> bool:
	return imagem.get_region(a).get_data() == imagem.get_region(b).get_data()


# ─────────────────────────────────────────────────────────────

func _testar_ficha() -> void:
	print("\n--- A FICHA: TELINHA, FRASE E MAIS NADA ---")
	var ficha := TutorialFerramenta.new()
	ficha.fonte = FONTE
	add_child(ficha)
	await get_tree().process_frame
	_checar(not ficha.visible and not ficha.esta_aberto(), "a ficha nasce escondida")

	ficha.abrir(CatalogoFerramentas.tutorial("bumerangue"))
	await get_tree().process_frame
	_checar(ficha.visible and ficha.esta_aberto(), "abrir mostra a ficha")
	_checar(not ficha.pode_fechar(), "recem aberta, ela ainda nao aceita o E")

	var tela := ficha.size
	var quadro := ficha.retangulo_da_ficha()
	_checar(quadro.position.x >= 0.0 and quadro.end.x <= tela.x
		and quadro.position.y >= 0.0 and quadro.end.y <= tela.y, "a ficha cabe na tela %s" % quadro)
	_checar(absf(quadro.get_center().x - tela.x * 0.5) < 1.0, "e fica centrada na horizontal")

	var telinha := ficha.telinha()
	_checar(telinha is DemoBumerangue, "a telinha e a cena do bumerangue")
	var quadro_telinha := ficha.retangulo_da_telinha()
	_checar(quadro.grow(-TutorialFerramenta.MARGEM + 1.0).encloses(quadro_telinha),
		"a telinha fica dentro da ficha %s" % quadro_telinha)
	_checar(quadro_telinha.size.is_equal_approx(telinha.size * 2.0) and quadro_telinha.size.x >= 590.0,
		"a telinha vai ampliada, no dobro do tamanho do jogo %s" % quadro_telinha.size)
	_checar(is_equal_approx(quadro.size.x, quadro_telinha.size.x + TutorialFerramenta.MARGEM * 2.0)
		and absf(quadro_telinha.get_center().x - quadro.get_center().x) < 1.0,
		"a ficha e da largura da telinha, com ela no meio")

	var linhas := ficha.linhas_do_texto()
	_checar(" ".join(linhas) == FRASE, "a frase esta inteira na ficha: %s" % [linhas])
	var maior := 0.0
	for linha in linhas:
		maior = maxf(maior, FONTE.get_string_size(linha, HORIZONTAL_ALIGNMENT_LEFT, -1,
			TutorialFerramenta.TAM_TEXTO).x)
	_checar(maior <= ficha.largura_do_texto() + 0.5,
		"nenhuma linha passa da largura da telinha (%d de %d px)" % [maior, ficha.largura_do_texto()])
	var m: Dictionary = ficha._medidas()
	var topo_frase: float = m["topo_frase"]
	var centro_tecla: Vector2 = m["centro_tecla"]
	var fim_da_frase := topo_frase + linhas.size() * float(m["entrelinha"])
	_checar(topo_frase >= quadro_telinha.end.y + 8.0, "a frase fica embaixo da telinha")
	_checar(centro_tecla.y - TutorialFerramenta.ALTURA_TECLA * 0.5 >= fim_da_frase
		and centro_tecla.y + TutorialFerramenta.ALTURA_TECLA * 0.5 <= quadro.end.y - 8.0
		and absf(centro_tecla.x - quadro.get_center().x) < 1.0,
		"e a tecla que fecha, embaixo da frase, no meio da ficha")
	# A frase é o único texto: a ficha não guarda nem título, nem etiqueta, nem rodapé.
	var escritos := PackedStringArray()
	for constante: String in (ficha.get_script() as GDScript).get_script_constant_map():
		if (ficha.get_script() as GDScript).get_script_constant_map()[constante] is String:
			escritos.append(constante)
	_checar(escritos.is_empty(), "a ficha nao tem nenhum outro texto para escrever %s" % [escritos])

	print("  . fechar")
	await _esperar_ate(ficha.pode_fechar)
	_checar(ficha.pode_fechar(), "montada, a ficha aceita o E")
	var fechou := [false]
	ficha.fechado.connect(func() -> void: fechou[0] = true)
	ficha.fechar()
	_checar(not ficha.pode_fechar(), "fechando, ela nao aceita outro E")
	await _esperar_ate(func() -> bool: return fechou[0])
	_checar(fechou[0] and not ficha.visible, "fechar tira a ficha da tela e avisa")
	await get_tree().process_frame
	_checar(ficha.telinha() == null and not is_instance_valid(telinha),
		"e a telinha sai junto")
	ficha.queue_free()
	await get_tree().process_frame


# ─────────────────────────────────────────────────────────────

func _testar_cenario() -> void:
	print("\n--- O CENARIO DA TELINHA E O DO MAPA ---")
	var demo: DemoBumerangue = (load(DEMO) as PackedScene).instantiate()
	add_child(demo)
	await get_tree().process_frame
	demo.set_process(false)

	var cenario: TileMapLayer = demo.get_node_or_null("Mundo/Cenario")
	_checar(cenario != null and cenario.tile_set != null
		and cenario.tile_set.resource_path == TILESET, "o fundo e um TileMapLayer com o tileset das fases")
	if cenario == null:
		demo.queue_free()
		return
	_checar(not cenario.collision_enabled and not cenario.navigation_enabled,
		"sem colisao nem navegacao: e so desenho, nao cria chao de verdade")
	_checar(cenario.scale == Vector2(2, 2), "na escala das camadas da fase (2x)")

	var caixa: AnimatedSprite2D = demo.get_node("Mundo/Caixa")
	var cacau: AnimatedSprite2D = demo.get_node("Mundo/Cacau")
	var passo := Vector2(cenario.tile_set.tile_size) * cenario.scale
	var canto_da_caixa := (caixa.position - passo - cenario.position) / passo
	var celula_da_caixa := Vector2i(canto_da_caixa.round())
	_checar(canto_da_caixa.is_equal_approx(Vector2(celula_da_caixa))
		and cenario.get_cell_atlas_coords(celula_da_caixa) == PLACA.position,
		"a caixa fica em cima de uma placa inteira da parede, como no mapa")

	# Em cima da caixa, e só ali, a placa com os cabos subindo.
	var acima := true
	for dy in [-1, -2]:
		for dx in [0, 1]:
			if not PLACA_COM_CABOS.has_point(cenario.get_cell_atlas_coords(celula_da_caixa + Vector2i(dx, dy))):
				acima = false
	_checar(acima, "logo em cima da caixa estao as placas com os cabos dela subindo")
	var cabos_fora := 0
	var paredes := 0
	var pisos := 0
	var estranhos := 0
	for celula in cenario.get_used_cells():
		var atlas := cenario.get_cell_atlas_coords(celula)
		if PLACA_COM_CABOS.has_point(atlas):
			if celula.y >= celula_da_caixa.y or celula.x < celula_da_caixa.x or celula.x > celula_da_caixa.x + 1:
				cabos_fora += 1
		elif PLACA.has_point(atlas):
			paredes += 1
		elif atlas.y in [LINHA_DO_PISO, LINHA_DO_PISO + 1] and atlas.x <= 7:
			pisos += 1
		else:
			estranhos += 1
	_checar(cabos_fora == 0, "e em nenhum outro lugar da parede (%d fora)" % cabos_fora)
	_checar(paredes > 20 and pisos > 5 and estranhos == 0,
		"o resto e a placa rebitada da parede e o piso (%d placas, %d de piso, %d estranhos)"
			% [paredes, pisos, estranhos])

	# O piso começa exatamente no pé da Cacau.
	var pe := cacau.position.y + 48.0 * cacau.scale.y
	var celula_do_pe := cenario.local_to_map(cenario.transform.affine_inverse() * Vector2(cacau.position.x, pe + 4.0))
	_checar(cenario.get_cell_atlas_coords(celula_do_pe).y == LINHA_DO_PISO
		and is_equal_approx(cenario.position.y + celula_do_pe.y * passo.y, pe),
		"a Cacau pisa na fileira de cima do piso (a da faixa amarela)")
	var area := Rect2(Vector2.ZERO, demo.size).grow(DemoBumerangue.TREMOR)
	var coberto := true
	for x in range(int(area.position.x), int(area.end.x), 8):
		for y in range(int(area.position.y), int(area.end.y), 8):
			var celula := cenario.local_to_map(cenario.transform.affine_inverse() * Vector2(x, y))
			if cenario.get_cell_source_id(celula) < 0:
				coberto = false
	_checar(coberto, "o cenario cobre o quadradinho inteiro, com folga para o tremor")

	demo.queue_free()
	await get_tree().process_frame


# ─────────────────────────────────────────────────────────────

func _testar_telinha() -> void:
	print("\n--- A TELINHA ---")
	var demo: DemoBumerangue = (load(DEMO) as PackedScene).instantiate()
	add_child(demo)
	await get_tree().process_frame
	# O relógio dela passa a ser do teste, para cada momento cair no lugar certo.
	demo.set_process(false)
	demo.reiniciar()

	var cacau: AnimatedSprite2D = demo.get_node("Mundo/Cacau")
	var caixa: AnimatedSprite2D = demo.get_node("Mundo/Caixa")
	var bumerangue: Sprite2D = demo.get_node("Mundo/Bumerangue")
	var faiscas: CPUParticles2D = demo.get_node("Mundo/FaiscasImpacto")
	var brilho: Sprite2D = demo.get_node("Mundo/BrilhoAlvo")
	var cortina: ColorRect = demo.get_node("Cortina")
	var mao: Vector2 = cacau.transform * (demo.get_node("Mundo/Cacau/Mao") as Marker2D).position
	var alvo: Vector2 = caixa.transform * (demo.get_node("Mundo/Caixa/Alvo") as Marker2D).position
	var area := Rect2(Vector2.ZERO, demo.size)

	_checar(demo.clip_contents and demo.size.x >= 200.0 and demo.size.y >= 150.0,
		"e um quadradinho que corta o que passa da borda %s" % demo.size)
	_checar(demo.process_mode == Node.PROCESS_MODE_ALWAYS, "anima mesmo com o jogo parado")
	_checar(area.has_point(cacau.position) and area.has_point(caixa.position)
		and caixa.position.x > cacau.position.x + 100.0 and alvo.x > mao.x + 80.0,
		"a Cacau fica de um lado e a caixa do outro, com espaco para o voo")

	# A tecla F do tutorial: no meio do quadradinho no eixo x, e maior que a do
	# cinto (que tem 32 px na tela).
	var tecla: Control = demo.get_node("Tecla")
	var quadro_da_tecla := Rect2(tecla.position, tecla.size)
	_checar(absf(quadro_da_tecla.get_center().x - demo.size.x * 0.5) < 0.5,
		"a tecla F fica no meio do quadradinho no eixo x (centro em %.0f de %.0f)"
			% [quadro_da_tecla.get_center().x, demo.size.x])
	var lado_na_tela := minf(tecla.size.x, tecla.size.y) * demo.scale.x
	_checar(is_equal_approx(tecla.size.x, tecla.size.y) and lado_na_tela > 64.0 and lado_na_tela <= 96.0
		and is_equal_approx(lado_na_tela, roundf(lado_na_tela / 16.0) * 16.0),
		"um pouco maior que antes (%.0f px na tela, contra 64), em multiplo inteiro do desenho" % lado_na_tela)
	# O anel do toque abre 12 px em volta da tecla: nem ele encosta em nada.
	var com_anel := quadro_da_tecla.grow(12.0)
	var cabeca_da_cacau := cacau.position.y - 16.0 * cacau.scale.y
	_checar(area.encloses(com_anel) and com_anel.end.y < cabeca_da_cacau
		and com_anel.end.x < caixa.position.x - 32.0,
		"no alto, sem encostar na Cacau nem nos cabos da caixa")
	_checar(caixa.sprite_frames.get_frame_texture(&"intacta", 0).resource_path.ends_with("CAIXA ELETRICA1.png")
		and caixa.sprite_frames.get_frame_count(&"quebrando") == 4,
		"a caixa e a caixa eletrica do jogo, com a animacao de quebrar")

	# As animações da Cacau são as do player: os mesmos quadros das mesmas folhas.
	var player: Node = (load(PLAYER) as PackedScene).instantiate()
	var do_jogo: SpriteFrames = (player.get_node("AnimatedSprite2D") as AnimatedSprite2D).sprite_frames
	var da_telinha := cacau.sprite_frames
	_checar(_mesmos_quadros(da_telinha, do_jogo, &"idle")
		and is_equal_approx(da_telinha.get_animation_speed(&"idle"), do_jogo.get_animation_speed(&"idle")),
		"a idle da telinha e a idle do jogo, na mesma velocidade")
	_checar(_mesmos_quadros(da_telinha, do_jogo, &"jogando_bumerangue"),
		"e o gesto e o do arremesso do jogo")
	_checar(not cacau.is_playing(), "quem escolhe o quadro dela e o roteiro da telinha")
	player.free()
	var quadros_da_idle := da_telinha.get_frame_count(&"idle")
	var fim_do_gesto := DemoBumerangue.T_APERTAR + demo.duracao_do_gesto()

	print("  . antes do toque")
	var vistos := {}
	while demo._tempo < DemoBumerangue.T_APERTAR - 0.02:
		demo._process(PASSO)
		if cacau.animation == &"idle":
			vistos[cacau.frame] = true
	_checar(cacau.animation == &"idle" and vistos.size() >= quadros_da_idle - 1,
		"ela esta parada, rodando a idle (%d quadros diferentes)" % vistos.size())
	_checar(not demo.tecla_apertada() and not bumerangue.visible,
		"com o bumerangue na mao e a tecla solta")
	_checar(caixa.animation == &"intacta" and not demo.caixa_quebrada() and brilho.modulate.a > 0.05,
		"a caixa esta inteira, com o brilho de alvo")
	_checar(cortina.color.a < 0.01, "e a cortina ja abriu")
	await _capturar_telinha(demo, "telinha_1_parada")

	print("  . o toque e o arremesso")
	_avancar_ate(demo, DemoBumerangue.T_APERTAR + 0.12)
	_checar(demo.tecla_apertada() and cacau.animation == &"jogando_bumerangue" and cacau.frame > 0,
		"a tecla afunda e a Cacau faz o gesto")
	_checar(bumerangue.visible and demo.bumerangue_no_ar(), "o bumerangue sai da mao")
	var x_saida := bumerangue.position.x
	await _capturar_telinha(demo, "telinha_2_gesto")
	_avancar_ate(demo, DemoBumerangue.T_ACERTO - 0.05)
	_checar(bumerangue.position.x > x_saida + 40.0 and bumerangue.position.x < alvo.x
		and not demo.caixa_quebrada(), "e voa na direcao da caixa (%d -> %d)"
			% [x_saida, bumerangue.position.x])
	_checar((demo.get_node("Mundo/Rastro") as Line2D).get_point_count() >= 3,
		"deixando o rastro atras dele")

	print("  . a idle depois do gesto")
	_checar(fim_do_gesto < DemoBumerangue.T_PEGAR, "o gesto acaba com o bumerangue ainda no ar")
	demo.reiniciar()
	# Para no último passo ANTES do fim do gesto, e dá mais um.
	while demo._tempo + PASSO < fim_do_gesto:
		demo._process(PASSO)
	_checar(cacau.animation == &"jogando_bumerangue"
		and cacau.frame == da_telinha.get_frame_count(&"jogando_bumerangue") - 1,
		"o gesto vai ate o ultimo quadro")
	demo._process(PASSO)
	_checar(cacau.animation == &"idle" and cacau.frame == 0,
		"acabou o gesto, a idle comeca do primeiro quadro")
	vistos = {}
	while demo._tempo < fim_do_gesto + 0.9:
		demo._process(PASSO)
		if cacau.animation != &"idle":
			vistos[-1] = true
		vistos[cacau.frame] = true
	_checar(not vistos.has(-1) and vistos.size() >= quadros_da_idle - 1,
		"e segue rodando, sem voltar para o gesto (%d quadros diferentes)" % vistos.size())

	print("  . a batida")
	demo.reiniciar()
	_avancar_ate(demo, DemoBumerangue.T_ACERTO + PASSO)
	_checar(demo.caixa_quebrada() and caixa.animation == &"quebrando" and caixa.is_playing(),
		"o bumerangue chega e a caixa comeca a quebrar")
	_checar(faiscas.emitting, "com as faiscas no mesmo instante")
	_checar(bumerangue.position.distance_to(alvo) < 6.0 and bumerangue.scale.x > 2.4,
		"ele bate no ponto de alvo da caixa e da o estufao")
	_checar(is_zero_approx(brilho.modulate.a), "o brilho de alvo apaga")
	await _capturar_telinha(demo, "telinha_3_batida")

	print("  . a volta")
	_avancar_ate(demo, DemoBumerangue.T_PEGAR - 0.08)
	_checar(bumerangue.visible and bumerangue.position.x < alvo.x - 30.0
		and bumerangue.position.x > mao.x, "ele volta para a mao da Cacau")
	_avancar_ate(demo, DemoBumerangue.T_PEGAR + 0.1)
	_checar(not bumerangue.visible and not demo.bumerangue_no_ar(), "e ela pega de volta")
	# A animação da caixa roda sozinha (são 4 quadros a 12 por segundo).
	await _esperar_ate(func() -> bool: return caixa.frame == 3)
	_checar(caixa.frame == 3 and caixa.sprite_frames.get_frame_texture(&"quebrando", 3)
		.resource_path.ends_with("CAIXA ELETRICA3.png"), "a caixa fica quebrada, com os fios a mostra")
	var estalos := 0
	var arco: CPUParticles2D = demo.get_node("Mundo/FaiscasArco")
	while demo._tempo < DemoBumerangue.T_FIM - DemoBumerangue.DURACAO_CORTINA - 0.05:
		arco.emitting = false
		demo._process(PASSO)
		if arco.emitting:
			estalos += 1
	_checar(estalos >= 2, "e estala de tempos em tempos (%d estalos)" % estalos)
	_checar(cacau.animation == &"idle", "com a Cacau parada na idle ate o fim")
	await _capturar_telinha(demo, "telinha_4_quebrada")

	print("  . a volta seguinte")
	_avancar_ate(demo, DemoBumerangue.T_FIM - 0.02)
	_checar(cortina.color.a > 0.9, "a cortina fecha no fim")
	for i in 30:
		demo._process(PASSO)
	_checar(demo._tempo < 1.0 and caixa.animation == &"intacta" and not demo.caixa_quebrada()
		and cacau.animation == &"idle" and not bumerangue.visible,
		"e a cena recomeca, com a caixa inteira de novo")

	demo.queue_free()
	await get_tree().process_frame


# ─────────────────────────────────────────────────────────────

func _testar_na_fase() -> void:
	print("\n--- PEGANDO O BUMERANGUE NA FASE 1 ---")
	var fase := (load(FASE) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(fase)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	var player: CharacterBody2D = fase.get_node("Player")
	var pickup: PickupHabilidade = fase.get_node_or_null("Entrada/PickupBumerangue")
	var ferramentas: FerramentasPlayer = player.get_node("Ferramentas")
	_checar(pickup != null and pickup.habilidade == "bumerangue", "o bumerangue esta na entrada")
	if pickup == null:
		fase.queue_free()
		return

	# O rádio do Dr. Chico chama assim que a Cacau chega na fase, e a fala dele
	# tomaria o E deste roteiro: sai de cena antes de chamar.
	var radio := fase.get_node_or_null("Entrada/RadioDrChico")
	if radio:
		radio.queue_free()
	# O domo sai do caminho como se o puzzle do carbono já tivesse sido feito.
	var domo := fase.get_node_or_null("Entrada/GaiolaBumerangue")
	if domo:
		domo.queue_free()
	pickup.monitoring = true
	player.global_position = pickup.global_position
	player.velocity = Vector2.ZERO
	await _esperar_ate(func() -> bool: return pickup._jogador_perto)
	_checar(pickup._jogador_perto, "a Cacau chega no bumerangue")

	var fechados := []
	FerramentasHUD.tutorial_fechado.connect(func(h: String) -> void: fechados.append(h))

	await _apertar_e()
	_checar(Progresso.tem_habilidade("bumerangue"), "o E pega o bumerangue")
	await _esperar_ate(func() -> bool: return Inventario.popup_aberto)
	_checar(Inventario.popup_aberto and not FerramentasHUD.tutorial_aberto(),
		"primeiro sobe a ficha de coleta, sem o tutorial por cima")
	if _capturando():
		await _esperar(0.9)
		await _capturar("0_ficha_de_coleta")

	await _apertar_e()
	await _esperar_ate(FerramentasHUD.tutorial_aberto)
	_checar(FerramentasHUD.tutorial_aberto(), "o E fecha a ficha e o tutorial sobe em seguida")
	_checar(not Inventario.popup_aberto and FerramentasHUD.tem_no_cinto("bumerangue"),
		"com a ficha de coleta ja fechada e o bumerangue no cinto")
	var cinto: CintoHUD = FerramentasHUD._cinto
	_checar(cinto._ferramentas[cinto.indice_de("bumerangue")]["tecla"] == "F"
		and EstiloHUD.desenho_da_tecla("F", cinto._ferramentas[cinto.indice_de("bumerangue")]["acao"]) == "tecla_f",
		"no cinto, embaixo do bumerangue, a tecla e o F desenhado")
	_checar(get_tree().paused and Interacao.ocupada(), "o mundo continua parado e o E e do tutorial")
	_checar(not Interacao.livre_para(&"arremessar"), "com ele na tela, o F nao arremessa nada")
	var ficha: TutorialFerramenta = FerramentasHUD._tutorial
	_checar(ficha.visible and ficha.telinha() is DemoBumerangue, "a ficha esta na tela com a telinha")

	print("  . cedo demais")
	await _apertar_e()
	_checar(FerramentasHUD.tutorial_aberto() and ficha.esta_aberto(),
		"apertado com a ficha ainda subindo, o E nao a fecha")
	await _apertar(KEY_ESCAPE)
	_checar(FerramentasHUD.tutorial_aberto() and ficha.esta_aberto(),
		"nem o ESC")
	await _esperar_ate(ficha.pode_fechar)
	_checar(ficha.pode_fechar(), "a ficha termina de subir")
	var telinha: DemoBumerangue = ficha.telinha()
	_checar(telinha.is_processing(), "e a telinha esta animando")
	await _esperar_ate(func() -> bool: return telinha.scale.is_equal_approx(Vector2(2, 2)))
	_checar(telinha.scale.is_equal_approx(Vector2(2, 2))
		and telinha.get_global_rect().size.is_equal_approx(ficha.retangulo_da_telinha().size),
		"ampliada em 2x, do tamanho que a ficha reservou %s" % telinha.get_global_rect().size)
	_checar(telinha.get_global_rect().get_center().distance_to(ficha.retangulo_da_telinha().get_center()) < 2.0,
		"no lugar dela na ficha")

	print("  . o cenario da telinha contra o mapa")
	_comparar_com_o_mapa(fase, telinha)
	await _capturas_da_ficha(telinha)

	print("  . o ESC sai")
	await _apertar(KEY_ESCAPE)
	_checar(not ficha.esta_aberto(), "o ESC fecha o tutorial")
	await _esperar_ate(func() -> bool: return not fechados.is_empty())
	_checar(fechados == ["bumerangue"], "o FerramentasHUD avisa que o tutorial do bumerangue fechou")
	_checar(not FerramentasHUD.tutorial_aberto() and not get_tree().paused and not Interacao.ocupada(),
		"o mundo volta a andar e o E volta para o cenario")
	_checar(not ferramentas._bumerangue_no_ar, "fechar nao arremessou nada")

	print("  . o E tambem sai")
	FerramentasHUD.ensinar("bumerangue")
	await _esperar_ate(ficha.pode_fechar)
	_checar(ficha.pode_fechar() and get_tree().paused, "o tutorial pode ser aberto de novo")
	await _apertar_e()
	_checar(not ficha.esta_aberto(), "o E fecha o tutorial")
	await _esperar_ate(func() -> bool: return fechados.size() >= 2)
	_checar(fechados.size() == 2 and not FerramentasHUD.tutorial_aberto() and not get_tree().paused
		and not Interacao.ocupada(), "e o mundo volta a andar do mesmo jeito")
	_checar(not ferramentas._bumerangue_no_ar, "sem arremessar nada")
	await _esperar(3.2)
	_checar(cinto.is_processing() and cinto._quadro_das_teclas == BotoesControle.quadro_atual(),
		"com o jogo andando e o cinto quieto, a tecla dele continua afundando em loop")
	await _capturar("6_jogo_com_o_cinto")

	print("  . de controle, o quadrado que fecha nao arremessa")
	FerramentasHUD.ensinar("bumerangue")
	await _esperar_ate(ficha.pode_fechar)
	_checar(ficha.pode_fechar() and get_tree().paused, "o tutorial pode ser aberto de novo")
	_botao(JOY_BUTTON_X, true)
	await _quadros(3)
	_checar(not ficha.esta_aberto(), "o quadrado fecha o tutorial")
	await _esperar_ate(func() -> bool: return not FerramentasHUD.tutorial_aberto())
	_checar(not get_tree().paused and Interacao.toque_preso(&"arremessar"),
		"e, ainda apertado, continua preso a ficha que fechou")
	await _quadros(4)
	_checar(not ferramentas._bumerangue_no_ar, "o bumerangue fica na mao")
	_botao(JOY_BUTTON_X, false)
	await _quadros(4)
	_checar(Interacao.livre_para(&"arremessar"), "solto o botao, o proximo toque ja arremessa")

	print("  . de controle, o triangulo sai e a bolinha nao")
	FerramentasHUD.ensinar("bumerangue")
	await _esperar_ate(ficha.pode_fechar)
	_botao(JOY_BUTTON_B, true)
	await _quadros(3)
	_botao(JOY_BUTTON_B, false)
	await _quadros(3)
	_checar(ficha.esta_aberto(), "a bolinha nao fecha o tutorial (e o botao do dash, nao o de sair)")
	_botao(JOY_BUTTON_Y, true)
	await _quadros(3)
	_botao(JOY_BUTTON_Y, false)
	_checar(not ficha.esta_aberto(), "o triangulo fecha")
	await _esperar_ate(func() -> bool: return not FerramentasHUD.tutorial_aberto())
	_checar(not get_tree().paused and not ferramentas._bumerangue_no_ar, "e o mundo volta a andar")
	_tecla(KEY_CTRL)
	await _quadros(3)

	# Deixa tudo como estava para quem rodar outra coisa em seguida.
	Progresso._habilidades.erase("bumerangue")
	fase.queue_free()
	await get_tree().process_frame


## A parede e os cabos da telinha têm de ser os tiles que a fase usa em volta
## de uma caixa de verdade (a de treino, Treino/AlvoFixo1): a mesma folha, a
## placa rebitada ao lado e a placa com cabos logo em cima.
func _comparar_com_o_mapa(fase: Node, telinha: DemoBumerangue) -> void:
	var caixa_do_mapa: Node2D = fase.get_node_or_null("Treino/AlvoFixo1")
	var fundo_do_mapa: TileMapLayer = fase.get_node_or_null("Cenário")
	var cenario: TileMapLayer = telinha.get_node("Mundo/Cenario")
	var caixa: Node2D = telinha.get_node("Mundo/Caixa")
	_checar(caixa_do_mapa != null and fundo_do_mapa != null, "a fase tem a caixa de treino e a camada de fundo")
	if caixa_do_mapa == null or fundo_do_mapa == null:
		return

	var no_mapa := fundo_do_mapa.local_to_map(fundo_do_mapa.to_local(caixa_do_mapa.global_position)) - Vector2i.ONE
	var passo := Vector2(cenario.tile_set.tile_size) * cenario.scale
	var na_telinha := Vector2i(((caixa.position - passo - cenario.position) / passo).round())
	_checar(_folha(fundo_do_mapa, no_mapa) == _folha(cenario, na_telinha),
		"a telinha desenha com a mesma folha de tiles do fundo da fase")
	var iguais := true
	# Duas fileiras em cima da caixa (os cabos) e as duas colunas do lado (a parede).
	for d: Vector2i in [Vector2i(0, -1), Vector2i(1, -1), Vector2i(0, -2), Vector2i(1, -2),
			Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(-2, 1), Vector2i(-1, 1)]:
		if fundo_do_mapa.get_cell_atlas_coords(no_mapa + d) != cenario.get_cell_atlas_coords(na_telinha + d):
			iguais = false
	_checar(iguais, "em cima da caixa e ao lado dela, os tiles sao os mesmos do mapa")


func _folha(camada: TileMapLayer, celula: Vector2i) -> String:
	var fonte := camada.tile_set.get_source(camada.get_cell_source_id(celula)) as TileSetAtlasSource
	return fonte.texture.resource_path if fonte != null else ""


# ─────────────────────────────────────────────────────────────

## As duas animações têm os mesmos quadros (mesma folha, mesmos recortes)?
func _mesmos_quadros(a: SpriteFrames, b: SpriteFrames, animacao: StringName) -> bool:
	if not a.has_animation(animacao) or not b.has_animation(animacao):
		return false
	if a.get_frame_count(animacao) != b.get_frame_count(animacao):
		return false
	for i in a.get_frame_count(animacao):
		var qa := a.get_frame_texture(animacao, i) as AtlasTexture
		var qb := b.get_frame_texture(animacao, i) as AtlasTexture
		if qa == null or qb == null or qa.atlas != qb.atlas or qa.region != qb.region:
			return false
	return true


## Roda o relógio da telinha, em passos de um quadro, até o instante pedido.
func _avancar_ate(demo: DemoBumerangue, instante: float) -> void:
	while demo._tempo < instante:
		demo._process(PASSO)


## Um toque de E de verdade: passa pelo _input, que é onde o Interacao decide
## se o toque é da tela ou do mundo.
func _apertar_e() -> void:
	await _apertar(KEY_E)


## Um toque de tecla de verdade (aperta, espera uns quadros, solta).
func _apertar(codigo: Key) -> void:
	await get_tree().process_frame
	_evento_de_tecla(codigo, true)
	await _quadros(3)
	_evento_de_tecla(codigo, false)
	await _quadros(3)


func _tecla(codigo: Key) -> void:
	_evento_de_tecla(codigo, true)
	_evento_de_tecla(codigo, false)


func _evento_de_tecla(codigo: Key, apertada: bool) -> void:
	var evento := InputEventKey.new()
	evento.keycode = codigo
	evento.physical_keycode = codigo
	evento.pressed = apertada
	Input.parse_input_event(evento)


func _botao(botao: JoyButton, apertado: bool) -> void:
	var evento := InputEventJoypadButton.new()
	evento.device = 0
	evento.button_index = botao
	evento.pressed = apertado
	evento.pressure = 1.0 if apertado else 0.0
	Input.parse_input_event(evento)


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Espera a condição valer, quadro a quadro (com um teto, para um erro não
## travar o teste). É por condição, e não por relógio, porque salvar uma captura
## trava um quadro e o relógio de verdade passa na frente do tempo do jogo.
func _esperar_ate(condicao: Callable, teto: float = 5.0) -> void:
	var inicio := Time.get_ticks_msec()
	while not condicao.call() and Time.get_ticks_msec() - inicio < teto * 1000.0:
		await get_tree().process_frame


## Espera em tempo real (a árvore fica pausada pela ficha).
func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos, true, false, true).timeout


# --- Capturas (só com --capturas=) -------------------------------------------

## A ficha em quatro momentos da telinha, e de controle na mão.
func _capturas_da_ficha(telinha: DemoBumerangue) -> void:
	if not _capturando():
		return
	telinha.set_process(false)
	telinha.reiniciar()
	_avancar_ate(telinha, DemoBumerangue.T_APERTAR - 0.15)
	await _capturar("1_tutorial_parada")
	_avancar_ate(telinha, DemoBumerangue.T_SOLTAR + 0.16)
	await _capturar("2_tutorial_arremesso")
	_avancar_ate(telinha, DemoBumerangue.T_ACERTO + 0.05)
	await _esperar(0.05)
	await _capturar("3_tutorial_batida")
	_avancar_ate(telinha, DemoBumerangue.T_ACERTO + DemoBumerangue.PRIMEIRO_ARCO + 0.03)
	await _esperar(0.12)
	await _capturar("4_tutorial_caixa_quebrada")
	_botao(JOY_BUTTON_DPAD_UP, true)
	await _quadros(2)
	_botao(JOY_BUTTON_DPAD_UP, false)
	await _esperar(0.6)
	telinha.reiniciar()
	_avancar_ate(telinha, DemoBumerangue.T_APERTAR + 0.1)
	await _quadros(2)
	await _capturar("5_tutorial_de_controle")
	_tecla(KEY_CTRL)
	await _quadros(3)
	telinha.set_process(true)


## A telinha sozinha, ampliada, para conferir o desenho.
func _capturar_telinha(demo: DemoBumerangue, nome: String) -> void:
	if not _capturando():
		return
	var escala_antes := demo.scale
	demo.scale = Vector2(3, 3)
	await _esperar(0.04)
	await _capturar(nome)
	demo.scale = escala_antes


func _capturando() -> bool:
	return not _pasta_capturas.is_empty() and DisplayServer.get_name() != "headless"


func _capturar(nome: String) -> void:
	if not _capturando():
		return
	await RenderingServer.frame_post_draw
	var imagem := get_viewport().get_texture().get_image()
	imagem.save_png(_pasta_capturas.path_join(nome + ".png"))
