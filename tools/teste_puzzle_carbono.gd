extends Node

# Teste do puzzle do bumerangue (scenes/puzzle_carbono.tscn): montar o átomo de
# carbono na tela do computador da fase 1, pelas setas dos seletores
# (scenes/ui/seletor_particula.tscn).
#
# Joga o puzzle clicando nas setas com o mouse de verdade:
#
#   * as setas são as dos puzzles de balanceamento (a arte e o piscar do
#     termo da equação), duas por seletor, sem uma por cima da outra;
#   * abrir mostra a tela e pausa o jogo, com as contas zeradas;
#   * a seta de cima põe a partícula no átomo: próton e nêutron vão para o
#     núcleo, e o elétron para a camada do seletor dele, girando no raio dela;
#   * a seta de baixo tira, e com a conta em zero não faz nada;
#   * o que não cabe é recusado, com o aviso certo no rodapé: o terceiro
#     elétron na camada K, o nono próton no núcleo;
#   * ESC fecha sem resolver, e reabrir não desmonta o átomo;
#   * passar da conta (5 elétrons na L, 7 prótons) deixa a conta vermelha e
#     não conclui; a seta de baixo corrige;
#   * 6 prótons, 6 nêutrons, 2 elétrons na K e 4 na L concluem: a tela final
#     diz BUMERANGUE LIBERADO! e o E fecha resolvendo;
#   * de controle, os alvos do cursor são as setas;
#   * toda letra da tela existe na fonte e todo texto cabe no lugar dele;
#   * na fase 1, o domo do bumerangue abre este puzzle, e resolver abre o domo.
#
#   godot --headless --path . res://tools/teste_puzzle_carbono.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma imagem de cada
# momento na pasta, para conferir o layout a olho.

const PUZZLE := "res://scenes/puzzle_carbono.tscn"
const TERMO := "res://scenes/ui/termo_equacao.tscn"
const FASE := "res://scenes/fases/fase1_oficina.tscn"

var _falhas := 0
var _pasta_capturas := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			_pasta_capturas = arg.trim_prefix("--capturas=")
	await get_tree().process_frame

	await _testar_tela()
	await _testar_puzzle()
	await _testar_controle()
	await _testar_domo_da_fase()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


# ─────────────────────────────────────────────────────────────

func _testar_tela() -> void:
	print("\n--- A TELA ---")
	var puzzle := await _novo()
	var fonte: Font = puzzle.FONTE
	var textos: Array = [puzzle.TXT_INSTRUCAO, puzzle.TXT_MONTADO, puzzle.TXT_ABRIR_DOMO,
		"NÚCLEO K L 0123456789"]
	for qual: String in puzzle.SELETORES:
		textos.append(puzzle._aviso_de_cheio(qual))
		textos.append(puzzle._aviso_de_sobra(qual))
	# Texto largo demais estica o Label para a direita: ele sai da tela do
	# computador (que corta o que passa dela) ou entra no desenho do átomo.
	var cortados := PackedStringArray()
	var vidro: Rect2 = puzzle.display.get_global_rect()
	var desenho: Rect2 = puzzle.atomo.get_global_rect()
	for label: Label in puzzle.find_children("*", "Label", true, false):
		textos.append(label.text)
		if not puzzle.display.is_ancestor_of(label):
			continue
		var caixa := label.get_global_rect()
		if not vidro.encloses(caixa) or (puzzle.grupo_atomo.is_ancestor_of(label) and desenho.intersects(caixa)):
			cortados.append("%s %s" % [label.name, caixa])
	var faltando := ""
	var marca := RegEx.create_from_string("\\{[^}]*\\}")
	for texto in textos:
		for c in marca.sub(String(texto), "", true):
			# As teclas desenhadas (o ESC do canto) são códigos de uso privado, que
			# o IconesNoTexto troca pelo desenho: não são letra da fonte.
			if c == " " or c == "\n" or c.unicode_at(0) >= BotoesControle.PRIMEIRO_CODIGO:
				continue
			if not fonte.has_char(c.unicode_at(0)) and not faltando.contains(c):
				faltando += c
	_checar(faltando.is_empty(), "toda letra da tela e dos avisos existe na fonte [%s]" % faltando)
	_checar(cortados.is_empty(), "todo texto cabe no lugar dele %s" % [cortados])

	var tela: TextureRect = puzzle.get_node("RootControl/Tela")
	_checar(tela.texture.resource_path.ends_with("Computador receptor/tela_computador.png"),
		"a tela é a do computador da fase 1")
	var caixa_do_elemento := puzzle.get_node("RootControl/Tela/Display/GrupoAtomo/Caixa")
	_checar(caixa_do_elemento.get_node("Numero").text == "6" and caixa_do_elemento.get_node("Simbolo").text == "C" \
		and caixa_do_elemento.get_node("Nome").text == "Carbono" and caixa_do_elemento.get_node("Massa").text == "12,011",
		"a caixa do elemento é a do carbono: 6, C, Carbono, 12,011")
	_checar(puzzle.PROTONS == 6 and puzzle.NEUTRONS == 6 \
		and puzzle.ELETRONS_K + puzzle.ELETRONS_L == puzzle.PROTONS and puzzle.ELETRONS_K == 2,
		"o átomo pedido é o carbono-12: 6 prótons, 6 nêutrons, 2 + 4 elétrons")

	print("  . os seletores")
	var nomes: Array = []
	var artes: Array = []
	for qual: String in puzzle.seletores:
		var seletor: SeletorParticula = puzzle.seletores[qual]
		nomes.append(seletor.get_node("Nome").text)
		artes.append((seletor.icone.texture as AtlasTexture).region)
	_checar(puzzle.seletores.keys() == puzzle.SELETORES.keys() \
		and nomes == ["Prótons", "Nêutrons", "Camada K", "Camada L"],
		"são quatro: prótons, nêutrons, camada K e camada L %s" % [nomes])
	_checar(artes[0] != artes[1] and artes[1] != artes[2] and artes[2] == artes[3],
		"cada um com a partícula dele (as duas camadas, com o elétron)")
	# As setas são as do termo da equação: a mesma folha, os mesmos quadros, no
	# mesmo tamanho, a de cima virada para cima.
	var termo := (load(TERMO) as PackedScene).instantiate()
	var seta_do_termo: AnimatedSprite2D = termo.get_node("BotaoMais/Seta")
	var iguais := true
	for qual: String in puzzle.seletores:
		for botao: String in ["BotaoMais", "BotaoMenos"]:
			var seta: AnimatedSprite2D = puzzle.seletores[qual].get_node(botao + "/Seta")
			var quadros := seta.sprite_frames
			if quadros.get_frame_count("default") != seta_do_termo.sprite_frames.get_frame_count("default") \
					or seta.scale != seta_do_termo.scale or seta.flip_v != (botao == "BotaoMais") \
					or quadros.get_animation_loop("default") \
					or quadros.get_animation_speed("default") != seta_do_termo.sprite_frames.get_animation_speed("default"):
				iguais = false
			for i in quadros.get_frame_count("default"):
				var quadro := quadros.get_frame_texture("default", i) as AtlasTexture
				var do_termo := seta_do_termo.sprite_frames.get_frame_texture("default", i) as AtlasTexture
				if quadro.atlas != do_termo.atlas or quadro.region != do_termo.region:
					iguais = false
	termo.free()
	_checar(iguais, "as setas são as dos puzzles de balanceamento: a mesma arte, no mesmo tamanho")
	puzzle.abrir_puzzle()
	await _esperar(0.4)
	var areas: Array[Rect2] = puzzle.alvos_do_cursor()
	var sobrepostas := 0
	for i in areas.size():
		if not vidro.encloses(areas[i]):
			sobrepostas += 1
		for j in range(i + 1, areas.size()):
			if areas[i].intersects(areas[j]):
				sobrepostas += 1
	_checar(areas.size() == 8 and sobrepostas == 0,
		"oito setas, dentro da tela e sem uma área de clique por cima da outra (%d)" % sobrepostas)
	puzzle.fechar_puzzle(false)

	# O núcleo cheio (com as partículas a mais que ele aceita) não chega na
	# camada K, e a partícula do seletor é a que vai para o átomo.
	var borda := 0.0
	var icone: Control = puzzle.seletores["protons"].icone
	for i in puzzle.MAXIMO_DE_CADA * 2:
		borda = maxf(borda, puzzle.PASSO_DO_NUCLEO * sqrt(i + 0.5) + icone.size.x * 0.5)
	_checar(borda < puzzle.RAIO_NUCLEO and puzzle.RAIO_NUCLEO + 8.0 < puzzle.RAIO_K \
		and puzzle.RAIO_K < puzzle.RAIO_L,
		"o núcleo cheio cabe no tracejado dele, por dentro da camada K (%d px de %d)" \
		% [borda, puzzle.RAIO_NUCLEO])
	puzzle.queue_free()
	await get_tree().process_frame


# ─────────────────────────────────────────────────────────────

func _testar_puzzle() -> void:
	print("\n--- PUZZLE DO BUMERANGUE ---")
	var puzzle := await _novo()
	var resolvido := [false]
	puzzle.puzzle_resolvido.connect(func(): resolvido[0] = true)

	puzzle.abrir_puzzle()
	await _esperar(0.4)
	_checar(puzzle.visible and get_tree().paused, "abrir mostra a tela e pausa o jogo")
	_checar(puzzle.cabecalho.text == "LIBERAÇÃO DO BUMERANGUE", "o cabeçalho é LIBERAÇÃO DO BUMERANGUE")
	_checar(_contagem(puzzle) == [0, 0, 0, 0] and _numeros(puzzle) == ["0", "0", "0", "0"],
		"começa com as contas zeradas")
	_checar(puzzle._rodape_texto == puzzle.TXT_INSTRUCAO, "e o terminal manda usar as setas")
	await _capturar("1_inicio")

	print("  . a seta de cima")
	await _seta(puzzle, "protons", 1)
	await _seta(puzzle, "neutrons", 1)
	_checar(_contagem(puzzle) == [1, 1, 0, 0] and _numeros(puzzle) == ["1", "1", "0", "0"],
		"a seta de cima dos prótons e a dos nêutrons põem um de cada")
	_checar(_cor(puzzle, "protons") == puzzle.COR_AMARELO, "faltando, a conta fica amarela")
	var seta: AnimatedSprite2D = puzzle.seletores["neutrons"].get_node("BotaoMais/Seta")
	_checar(seta.is_playing() or seta.frame > 0, "a seta clicada pisca")
	await _esperar(0.4)
	var no_nucleo := true
	for peca: Control in puzzle._nucleo:
		if peca != null and _centro_de(peca).distance_to(puzzle.centro_na_tela()) > puzzle.RAIO_NUCLEO * _escala(puzzle):
			no_nucleo = false
	_checar(no_nucleo, "e eles vão do seletor para o núcleo")
	await _seta(puzzle, "camada_k", 1)
	_checar(_contagem(puzzle) == [1, 1, 1, 0], "a seta de cima da camada K põe um elétron nela")
	await _esperar(0.5)
	var eletron: Control = puzzle._camada_k[0]
	var antes := eletron.global_position
	await _esperar(0.5)
	var raio := _centro_de(eletron).distance_to(puzzle.centro_na_tela()) / _escala(puzzle)
	_checar(eletron.global_position.distance_to(antes) > 20.0 and absf(raio - puzzle.RAIO_K) < 3.0,
		"e ele gira no raio dela (%d px de %d)" % [raio, puzzle.RAIO_K])
	_checar(puzzle.particulas.get_child_count() == 3, "na tela, só as três partículas postas")
	await _capturar("2_tres_particulas")

	print("  . a seta de baixo")
	await _seta(puzzle, "camada_l", -1)
	_checar(_contagem(puzzle) == [1, 1, 1, 0] and puzzle._rodape_texto == puzzle.TXT_INSTRUCAO,
		"com a conta em zero, a seta de baixo não faz nada")
	await _seta(puzzle, "neutrons", -1)
	_checar(_contagem(puzzle) == [1, 0, 1, 0] and _numeros(puzzle)[1] == "0", "a seta de baixo tira o nêutron")
	await _esperar(0.4)
	_checar(puzzle.particulas.get_child_count() == 2, "que volta para o seletor e some da tela")
	await _seta(puzzle, "neutrons", 1)

	print("  . fechar no meio")
	puzzle._input(_tecla(KEY_ESCAPE))
	_checar(not puzzle.visible and not get_tree().paused and not resolvido[0],
		"ESC fecha sem resolver e despausa o jogo")
	puzzle.abrir_puzzle()
	await _esperar(0.4)
	_checar(_contagem(puzzle) == [1, 1, 1, 0] and puzzle.particulas.get_child_count() == 3,
		"reabrir não desmonta o átomo")

	print("  . as camadas")
	await _seta(puzzle, "camada_k", 1)
	_checar(_contagem(puzzle)[2] == 2 and _cor(puzzle, "camada_k") == puzzle.COR_CERTO,
		"com 2 elétrons a conta da camada K fica verde")
	await _seta(puzzle, "camada_k", 1)
	_checar(_contagem(puzzle)[2] == 2 and puzzle._rodape_texto == "A CAMADA K SÓ COMPORTA 2 ELÉTRONS",
		"o terceiro elétron na K é recusado: %s" % puzzle._rodape_texto)
	await _capturar("3_recusado")
	await _seta(puzzle, "camada_l", 1, 5)
	_checar(_contagem(puzzle)[3] == 5 and _cor(puzzle, "camada_l") == puzzle.COR_ERRO \
		and puzzle._rodape_texto == puzzle.TXT_ELETRONS_DEMAIS,
		"5 elétrons na L: a conta fica vermelha e o terminal avisa")
	await _esperar(0.5)
	await _capturar("4_eletrons_demais")
	await _seta(puzzle, "camada_l", -1)
	_checar(_contagem(puzzle)[3] == 4 and _cor(puzzle, "camada_l") == puzzle.COR_CERTO,
		"a seta de baixo tira um: a L fica com 4, verde")
	await _esperar(0.5)
	var espalhados := true
	for peca: Control in puzzle._camada_l:
		var perto := 0
		for outra: Control in puzzle._camada_l:
			if outra != peca and _centro_de(outra).distance_to(_centro_de(peca)) < 60.0:
				perto += 1
		if perto > 0 or absf(_centro_de(peca).distance_to(puzzle.centro_na_tela()) / _escala(puzzle) - puzzle.RAIO_L) > 3.0:
			espalhados = false
	_checar(espalhados, "e os 4 se espalham por igual na camada L")

	print("  . o núcleo")
	await _seta(puzzle, "protons", 1, 6)
	_checar(_contagem(puzzle)[0] == 7 and _cor(puzzle, "protons") == puzzle.COR_ERRO \
		and puzzle._rodape_texto == "PRÓTONS DEMAIS: O CARBONO TEM NÚMERO ATÔMICO 6",
		"7 prótons: a conta fica vermelha e o terminal avisa (%s)" % puzzle._rodape_texto)
	await _seta(puzzle, "protons", 1, 2)
	_checar(_contagem(puzzle)[0] == 8 and puzzle._rodape_texto == "O NÚCLEO NÃO COMPORTA MAIS PRÓTONS",
		"o nono próton é recusado: %s" % puzzle._rodape_texto)
	await _seta(puzzle, "protons", -1)
	await _seta(puzzle, "neutrons", 1, 5)
	_checar(_contagem(puzzle) == [7, 6, 2, 4] and not puzzle.travado,
		"com um próton a mais, o resto certo não conclui")
	await _esperar(0.4)
	var juntas := 0
	var pecas: Array = puzzle._nucleo.filter(func(p): return p != null)
	for i in pecas.size():
		for j in range(i + 1, pecas.size()):
			if _centro_de(pecas[i]).distance_to(_centro_de(pecas[j])) < 15.0 * _escala(puzzle):
				juntas += 1
	_checar(pecas.size() == 13 and juntas == 0, "no núcleo, cada partícula tem a vaga dela (%d em cima de outra)" % juntas)
	await _capturar("5_proton_a_mais")
	await _seta(puzzle, "protons", -1)
	_checar(_contagem(puzzle) == [6, 6, 2, 4], "tirando o próton a mais, a conta bate")
	_checar(puzzle.travado and puzzle._rodape_texto == puzzle.TXT_MONTADO, "e o átomo está montado")
	await _seta(puzzle, "protons", 1)
	_checar(_contagem(puzzle) == [6, 6, 2, 4] and puzzle.alvos_do_cursor().is_empty(),
		"montado, as setas já não mexem em nada")
	puzzle._input(_tecla(KEY_ESCAPE))
	_checar(puzzle.visible, "nem o ESC fecha sem resolver")
	await _capturar("6_montado")

	await _esperar(2.4)
	_checar(puzzle.grupo_liberado.visible and not puzzle.grupo_atomo.visible,
		"a tela final aparece no lugar do átomo")
	_checar(puzzle.label_liberado.text == "BUMERANGUE LIBERADO!", "a tela final diz BUMERANGUE LIBERADO!")
	_checar(puzzle.aguardando_fechamento
		and puzzle._rodape_texto == "APERTE %s PARA ABRIR O DOMO" % BotoesControle.caractere("tecla_e"),
		"o rodapé pede o E (desenhado) para abrir o domo")
	_checar(puzzle.dicas_do_controle().map(func(d): return d[1]) == ["ABRIR O DOMO"],
		"e, de controle, a barra pede o botão que abre o domo")
	await _capturar("7_bumerangue_liberado")

	puzzle._input(_tecla(KEY_E))
	await get_tree().process_frame
	_checar(resolvido[0], "E fecha e avisa que o puzzle foi resolvido")
	_checar(not puzzle.visible and not get_tree().paused, "a tela some e o jogo despausa")
	puzzle.queue_free()
	await get_tree().process_frame


# ─────────────────────────────────────────────────────────────

func _testar_controle() -> void:
	print("\n--- DE CONTROLE ---")
	var puzzle := await _novo()
	puzzle.abrir_puzzle()
	await _esperar(0.4)
	_checar(puzzle.is_in_group(CursorVirtual.GRUPO), "a tela tem o cursor do controle")
	var alvos: Array[Rect2] = puzzle.alvos_do_cursor()
	_checar(alvos.size() == 8 and alvos[0] == puzzle.seletores["protons"].retangulo_do_botao(1) \
		and alvos[1] == puzzle.seletores["protons"].retangulo_do_botao(-1),
		"os alvos do cursor são as duas setas de cada seletor")
	_checar(puzzle.dicas_do_controle().map(func(d): return d[1]) \
		== ["MOVER", "ESCOLHER", "APERTAR", "SAIR"], "a barra diz APERTAR")
	puzzle.alterar("protons", 1)
	_checar(puzzle.alvos_do_cursor().size() == 8, "e as partículas do átomo não viram alvo")
	puzzle.fechar_puzzle(false)
	puzzle.queue_free()
	await get_tree().process_frame


# ─────────────────────────────────────────────────────────────

func _testar_domo_da_fase() -> void:
	print("\n--- O DOMO DO BUMERANGUE NA FASE 1 ---")
	var fase := (load(FASE) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(fase)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	var domo: Node2D = fase.get_node_or_null("Entrada/GaiolaBumerangue")
	var pickup: Area2D = fase.get_node_or_null("Entrada/PickupBumerangue")
	_checar(domo != null and pickup != null, "o domo e o bumerangue estão na entrada")
	if domo == null or pickup == null:
		fase.queue_free()
		return
	_checar(domo.puzzle_cena != null and domo.puzzle_cena.resource_path == PUZZLE,
		"o domo do bumerangue abre o puzzle do carbono")
	_checar(not pickup.monitoring and not domo.puzzle_concluido, "o bumerangue nasce trancado")

	domo._on_zona_deteccao_body_entered(fase.get_node("Player"))
	await get_tree().process_frame
	Input.action_press(Interacao.ACAO)
	await get_tree().process_frame
	Input.action_release(Interacao.ACAO)
	await get_tree().process_frame
	var puzzle: CanvasLayer = domo.puzzle_ui
	_checar(puzzle != null and puzzle.visible and get_tree().paused, "o E perto do domo abre o puzzle")
	_checar(not domo.puzzle_concluido and not pickup.monitoring, "e o domo continua fechado")
	puzzle._input(_tecla(KEY_ESCAPE))
	_checar(not puzzle.visible and not domo.puzzle_concluido, "sair do puzzle não abre o domo")

	puzzle.abrir_puzzle()
	puzzle.fechar_puzzle(true)
	_checar(domo.puzzle_concluido, "resolver o puzzle abre o domo")
	await _esperar(1.6)
	_checar(pickup.monitoring, "e o bumerangue é liberado quando o domo termina de abrir")

	# Abrir o domo o marcou como feito no EstadoMundo: limpa, para o teste não
	# deixar a fase aberta para quem rodar outra coisa em seguida.
	EstadoMundo.desmarcar_caminho(str(fase.get_path()) + "/Entrada/GaiolaBumerangue")
	fase.queue_free()
	await get_tree().process_frame


# ─────────────────────────────────────────────────────────────

func _novo() -> CanvasLayer:
	var puzzle := (load(PUZZLE) as PackedScene).instantiate() as CanvasLayer
	add_child(puzzle)
	await get_tree().process_frame
	return puzzle


## [prótons, nêutrons, elétrons na K, elétrons na L]
func _contagem(puzzle: CanvasLayer) -> Array:
	return [puzzle.quantas("protons"), puzzle.quantas("neutrons"), puzzle.quantas("camada_k"),
		puzzle.quantas("camada_l")]


## O número escrito em cada seletor, na mesma ordem.
func _numeros(puzzle: CanvasLayer) -> Array:
	var numeros: Array = []
	for qual: String in puzzle.seletores:
		numeros.append(puzzle.seletores[qual].quantos.text)
	return numeros


func _cor(puzzle: CanvasLayer, qual: String) -> Color:
	return puzzle.seletores[qual].quantos.get_theme_color("font_color")


func _centro_de(peca: Control) -> Vector2:
	return peca.get_global_rect().get_center()


## Quantos px da tela do jogo vale 1 px da tela do computador.
func _escala(puzzle: CanvasLayer) -> float:
	return puzzle.particulas.get_global_transform().get_scale().x


## Clica na seta de cima (+1) ou de baixo (-1) do seletor (mouse de verdade).
func _seta(puzzle: CanvasLayer, qual: String, sentido: int, vezes: int = 1) -> void:
	for k in vezes:
		var centro: Vector2 = puzzle.seletores[qual].retangulo_do_botao(sentido).get_center()
		puzzle._input(_movimento(centro))
		puzzle._input(_clique(centro, true))
		puzzle._input(_clique(centro, false))
		await get_tree().process_frame


func _clique(pos: Vector2, pressionado: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressionado
	ev.position = pos
	return ev


func _movimento(pos: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	return ev


func _tecla(codigo: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = codigo
	ev.pressed = true
	return ev


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos, true).timeout


func _capturar(nome: String) -> void:
	if _pasta_capturas.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var imagem := get_viewport().get_texture().get_image()
	imagem.save_png(_pasta_capturas.path_join(nome + ".png"))
