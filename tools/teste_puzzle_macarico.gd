extends Node

# Teste do puzzle do maçarico (scenes/puzzle_macarico.tscn), da folha de
# moléculas (scripts/ui/folha_moleculas.gd) e da gaiola de vidro elétrica da
# fase 1 (scenes/fases/componentes/gaiola_vidro_eletrica.tscn).
#
# Joga o puzzle com cliques de mouse de verdade nas setas e no botão:
#
#   * a folha acha os 9 desenhos na ordem das linhas, monta o CO a partir do
#     CO₂, e H₂/O₂/H₂O continuam idênticos aos da folha antiga do foguete;
#   * vale QUALQUER resposta balanceada: sem coeficientes e desbalanceada são
#     recusadas com a mensagem certa; multiplicada (2-2-4-2) passa e mostra a
#     forma mais simples; a etapa 2 entra com a etapa 1 simplificada no alto;
#   * etapa 2: desbalanceada é recusada; 1-1-1-1-1 (uma de cada) mostra a
#     tela final — só "MAÇARICO LIBERADO!" e a foto do maçarico, sem chama — e
#     E fecha resolvendo; 4-2-3-4-2 e 3-1-2-3-1 também passam;
#   * fechar no meio da etapa 2 e reabrir volta na etapa 2;
#   * na fase 1, as duas gaiolas são a de vidro, nascem no 1º quadro com o
#     item trancado, e abrir toca os 12 quadros, para no último e solta o item.
#
#   godot --headless --path . res://tools/teste_puzzle_macarico.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma imagem de cada etapa
# na pasta, para conferir o layout a olho.

const PUZZLE := "res://scenes/puzzle_macarico.tscn"
const FASE := "res://scenes/fases/fase1_oficina.tscn"
const GAIOLA_VIDRO := "res://scenes/fases/componentes/gaiola_vidro_eletrica.tscn"
const FOLHA_ANTIGA := "res://assets/puzzle combustão do hidrogênio/atomos H2 O2 H2O.png"

var _falhas := 0
var _pasta_capturas := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			_pasta_capturas = arg.trim_prefix("--capturas=")
	await get_tree().process_frame

	_testar_folha()
	await _testar_puzzle()
	await _testar_reabrir_na_etapa_2()
	await _testar_gaiolas_da_fase()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


# ─────────────────────────────────────────────────────────────

func _testar_folha() -> void:
	print("\n--- FOLHA DE ÁTOMOS E MOLÉCULAS ---")
	var recortes := FolhaMoleculas.recortes()
	for linha in FolhaMoleculas.LINHAS:
		for formula in linha:
			_checar(recortes.has(formula) and FolhaMoleculas.textura(formula) != null,
				"a folha tem o desenho de %s" % formula)

	var co := FolhaMoleculas.textura("CO")
	var co2 := FolhaMoleculas.textura("CO2")
	_checar(co != null, "o CO é montado a partir do CO2")
	if co != null and co2 != null:
		var img_co := co.get_image()
		var vermelhos := 0
		var azuis := 0
		for y in img_co.get_height():
			for x in img_co.get_width():
				var p := img_co.get_pixel(x, y)
				if p.a > 0.0:
					if p.r > p.b:
						vermelhos += 1
					else:
						azuis += 1
		_checar(co.get_width() < co2.get_width() or co.get_height() < co2.get_height(),
			"o CO é menor que o CO2 (%s x %s)" % [co.get_size(), co2.get_size()])
		_checar(vermelhos > 0 and azuis > 0 and azuis < vermelhos * 2,
			"o CO tem o carbono e um oxigênio só (%d px vermelhos, %d azuis)" % [vermelhos, azuis])

	# O puzzle do foguete continua com os mesmos desenhos de antes.
	if not ResourceLoader.exists(FOLHA_ANTIGA):
		print("  (folha antiga já apagada: comparação com ela pulada)")
		return
	var antiga := (load(FOLHA_ANTIGA) as Texture2D).get_image()
	if antiga.is_compressed():
		antiga.decompress()
	antiga.convert(Image.FORMAT_RGBA8)
	var regioes_antigas := {"H2": Rect2i(11, 11, 49, 45), "O2": Rect2i(74, 1, 73, 75), "H2O": Rect2i(31, 86, 71, 60)}
	for formula in regioes_antigas:
		var velha := antiga.get_region(regioes_antigas[formula])
		var nova := FolhaMoleculas.textura(formula).get_image()
		nova.convert(Image.FORMAT_RGBA8)
		var diferentes := -1
		if nova.get_size() == velha.get_size():
			diferentes = 0
			for y in velha.get_height():
				for x in velha.get_width():
					var a := velha.get_pixel(x, y)
					var b := nova.get_pixel(x, y)
					if (a.a > 0.0 or b.a > 0.0) and not a.is_equal_approx(b):
						diferentes += 1
		_checar(diferentes == 0, "%s igual ao da folha antiga, no mesmo tamanho" % formula)


# ─────────────────────────────────────────────────────────────

func _testar_puzzle() -> void:
	print("\n--- PUZZLE DO MAÇARICO ---")
	var puzzle := (load(PUZZLE) as PackedScene).instantiate() as CanvasLayer
	add_child(puzzle)
	await get_tree().process_frame
	var resolvido := [false]
	puzzle.puzzle_resolvido.connect(func(): resolvido[0] = true)

	puzzle.abrir_puzzle()
	await _esperar(0.4)
	_checar(puzzle.visible and get_tree().paused, "abrir mostra a tela e pausa o jogo")
	_checar(puzzle.etapa == 0 and puzzle._termos.size() == 4, "começa na etapa 1, com 4 termos")
	_checar(puzzle.cabecalho.text == "LIBERAÇÃO DO MAÇARICO (ETAPA 1/2)",
		"o cabeçalho é LIBERAÇÃO DO MAÇARICO (ETAPA 1/2)")
	_checar(puzzle.aura.visible and puzzle.aura.modulate.a == 1.0,
		"o brilho esverdeado da tela já está aceso na etapa 1")
	await _capturar("1_etapa1_inicio")

	# Confirmar sem escolher nada.
	await _clicar_confirmar(puzzle)
	_checar(puzzle.etapa == 0 and not puzzle.travado, "sem coeficientes não conclui")
	_checar(puzzle._rodape_texto == "DEFINA TODOS OS COEFICIENTES", "e o terminal pede os coeficientes")

	# As setas: sobe, desce e dá a volta (0 -> 4).
	await _clicar_seta(puzzle, 0, 1, 2)
	_checar(puzzle.coeficientes[0] == 2, "a seta de cima soma 1 (duas vezes: 2)")
	await _clicar_seta(puzzle, 0, -1, 1)
	_checar(puzzle.coeficientes[0] == 1, "a seta de baixo tira 1")
	await _clicar_seta(puzzle, 1, -1, 1)
	_checar(puzzle.coeficientes[1] == 4 and puzzle.tocado[1], "descer do 0 dá a volta para o 4")
	_checar(puzzle._termos[0].moleculas.get_child_count() == 1, "o termo mostra uma molécula por coeficiente")

	# Desbalanceada: 1 C2H2 + 1 O2 -> 1 CO + 1 H2 (C e O não batem).
	await _definir(puzzle, [1, 1, 1, 1])
	await _clicar_confirmar(puzzle)
	_checar(puzzle.etapa == 0 and puzzle._rodape_texto.contains("DESBALANCEADO"),
		"desbalanceada é recusada: %s" % puzzle._rodape_texto)
	_checar(puzzle._rodape_texto.contains("C") and puzzle._rodape_texto.contains("O"),
		"a mensagem aponta C e O")
	await _capturar("2_etapa1_desbalanceada")

	# Multiplicada (2-2-4-2 é o 1-1-2-1 dobrado): também está balanceada, então
	# passa — e o rodapé mostra a forma mais simples.
	await _definir(puzzle, [2, 2, 4, 2])
	_checar(puzzle.reagentes_titulo.get_theme_color("font_color") == Color.GREEN,
		"balanceada, Reagentes e Produtos ficam verdes")
	await _clicar_confirmar(puzzle)
	_checar(puzzle.travado, "2-2-4-2 (multiplicada) conclui a etapa 1")
	_checar(puzzle._rodape_texto == "BALANCEADA! FORMA MAIS SIMPLES: 1-1-2-1",
		"e o rodapé mostra a forma mais simples: %s" % puzzle._rodape_texto)
	await _capturar("3_etapa1_concluida")
	await _esperar(3.5)
	_checar(puzzle.etapa == 1 and puzzle._termos.size() == 5 and not puzzle.travado,
		"a etapa 2 entra com 5 termos e destravada")
	var resumo := ""
	for lbl in puzzle.resumo.get_children():
		resumo += lbl.text
	_checar(puzzle.resumo.visible and resumo.contains("2 CO") and not resumo.contains("4 CO"),
		"a etapa 1 fica escrita no alto, na forma mais simples: %s" % resumo.strip_edges())
	_checar(puzzle.texto_botao.text == "ACENDER MAÇARICO", "o botão vira ACENDER MAÇARICO")
	_checar(puzzle.cabecalho.text == "LIBERAÇÃO DO MAÇARICO (ETAPA 2/2)",
		"o cabeçalho vira LIBERAÇÃO DO MAÇARICO (ETAPA 2/2)")
	await _capturar("4_etapa2_inicio")

	# Desbalanceada no oxigênio.
	await _definir(puzzle, [1, 1, 2, 1, 1])
	await _clicar_confirmar(puzzle)
	_checar(not puzzle.travado and puzzle._rodape_texto == "ELEMENTO O DESBALANCEADO",
		"1-1-2-1-1: só o O desbalanceado")

	# Uma molécula de cada: CO + H2 + O2 -> CO2 + H2O está balanceada. ENTER
	# também confirma.
	await _definir(puzzle, [1, 1, 1, 1, 1])
	_checar(puzzle._balanceada(), "1-1-1-1-1 está balanceada (C 1=1, H 2=2, O 3=3)")
	await _capturar("5_etapa2_certa")
	puzzle._input(_tecla(KEY_ENTER))
	_checar(puzzle.travado, "1-1-1-1-1 com ENTER conclui a etapa 2")
	_checar(puzzle._rodape_texto == "COMBUSTÃO COMPLETA", "já na forma mais simples: sem dica")
	await _esperar(1.8)
	_checar(puzzle.grupo_liberado.visible and not puzzle.grupo_equacao.visible,
		"a tela final aparece no lugar da equação")
	_checar(puzzle.label_liberado.text == "MAÇARICO LIBERADO!", "a tela final diz MAÇARICO LIBERADO!")
	_checar(puzzle.macarico.texture.resource_path.ends_with("maçaricoDesligado.png")
		and puzzle.grupo_liberado.get_children().filter(func(n): return n is CPUParticles2D).is_empty(),
		"só a foto do maçarico, sem chama acendendo")
	_checar(puzzle.aguardando_fechamento and puzzle._rodape_texto == "APERTE E PARA ABRIR A GAIOLA",
		"o rodapé pede o E para abrir a gaiola")
	await _capturar("6_macarico_liberado")

	puzzle._input(_tecla(KEY_E))
	await get_tree().process_frame
	_checar(resolvido[0], "E fecha e avisa que o puzzle foi resolvido")
	_checar(not puzzle.visible and not get_tree().paused, "a tela some e o jogo despausa")
	puzzle.queue_free()
	await get_tree().process_frame


func _testar_reabrir_na_etapa_2() -> void:
	print("\n--- FECHAR NO MEIO E REABRIR ---")
	var puzzle := (load(PUZZLE) as PackedScene).instantiate() as CanvasLayer
	add_child(puzzle)
	await get_tree().process_frame
	puzzle.abrir_puzzle()
	await _esperar(0.3)
	await _definir(puzzle, [1, 1, 2, 1])
	await _clicar_confirmar(puzzle)
	await _esperar(2.4)
	await _definir(puzzle, [2, 1, 0, 0, 0])
	puzzle._input(_tecla(KEY_ESCAPE))
	_checar(not puzzle.visible and not get_tree().paused, "ESC fecha no meio da etapa 2")
	puzzle.abrir_puzzle()
	await _esperar(0.3)
	_checar(puzzle.etapa == 1 and puzzle.coeficientes.all(func(c): return c == 0),
		"reabrir volta na etapa 2, com os coeficientes zerados")

	# Outras respostas balanceadas da etapa 2 também passam.
	for resposta in [[4, 2, 3, 4, 2], [3, 1, 2, 3, 1]]:
		await _definir(puzzle, resposta)
		_checar(puzzle._balanceada(), "%s está balanceada" % "-".join(PackedStringArray(resposta.map(func(v): return str(v)))))
	await _clicar_confirmar(puzzle)
	_checar(puzzle.travado, "3-1-2-3-1 conclui a etapa 2")
	await _esperar(0.2)
	puzzle.fechar_puzzle(false)
	puzzle.queue_free()
	await get_tree().process_frame


# ─────────────────────────────────────────────────────────────

func _testar_gaiolas_da_fase() -> void:
	print("\n--- GAIOLAS DE VIDRO NA FASE 1 ---")
	var fase := (load(FASE) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(fase)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	for info in [["Patio/GaiolaMacarico", "Patio/PickupMacarico", true],
			["Entrada/GaiolaBumerangue", "Entrada/PickupBumerangue", false]]:
		var gaiola: Node2D = fase.get_node_or_null(info[0])
		var pickup: Area2D = fase.get_node_or_null(info[1])
		_checar(gaiola != null and gaiola.scene_file_path == GAIOLA_VIDRO, "%s é a gaiola de vidro" % info[0])
		if gaiola == null or pickup == null:
			continue
		var tem_puzzle: bool = info[2]
		if tem_puzzle:
			_checar(gaiola.puzzle_cena != null and gaiola.puzzle_cena.resource_path == PUZZLE,
				"%s abre o puzzle do maçarico" % info[0])
		else:
			_checar(gaiola.puzzle_cena == null, "%s abre sem puzzle" % info[0])

		var anim: AnimatedSprite2D = gaiola.get_node("GaiolaAnimada")
		var quadros := anim.sprite_frames
		_checar(quadros.get_frame_count("abrindo") == 12, "a abertura tem os 12 quadros")
		var primeiro := quadros.get_frame_texture("fechada", 0) as AtlasTexture
		var ultimo := quadros.get_frame_texture("aberta", 0) as AtlasTexture
		_checar(primeiro.region.position.x == 0.0 and ultimo.region.position.x == 504.0 * 11,
			"fechada é o 1º quadro e aberta é o último")
		_checar(anim.animation == &"fechada", "nasce fechada")
		_checar(not pickup.monitoring, "o item nasce trancado")

		gaiola._on_puzzle_resolvido()
		_checar(anim.animation == &"abrindo", "resolver toca a abertura")
		await _esperar(1.5)
		_checar(anim.animation == &"aberta", "e para no último quadro")
		_checar(pickup.monitoring, "o item é liberado quando a gaiola termina de abrir")

	# Abrir as gaiolas marcou as duas como feitas no EstadoMundo: limpa, para o
	# teste não deixar a fase aberta para quem rodar outra coisa em seguida.
	for caminho in ["Patio/GaiolaMacarico", "Entrada/GaiolaBumerangue"]:
		EstadoMundo.desmarcar_caminho(str(fase.get_path()) + "/" + caminho)
	fase.queue_free()
	await get_tree().process_frame


# ─────────────────────────────────────────────────────────────

## Clica nas setas até cada termo ter o coeficiente pedido (mouse de verdade).
func _definir(puzzle: CanvasLayer, valores: Array) -> void:
	for i in valores.size():
		var alvo: int = valores[i]
		var cliques := 0
		while (puzzle.coeficientes[i] != alvo or not puzzle.tocado[i]) and cliques < 12:
			await _clicar_seta(puzzle, i, 1, 1)
			cliques += 1


func _clicar_seta(puzzle: CanvasLayer, termo: int, sentido: int, vezes: int) -> void:
	for k in vezes:
		var centro: Vector2 = puzzle._termos[termo].retangulo_do_botao(sentido).get_center()
		puzzle._input(_movimento(centro))
		puzzle._input(_clique(centro, true))
		puzzle._input(_clique(centro, false))
		await get_tree().process_frame


func _clicar_confirmar(puzzle: CanvasLayer) -> void:
	var centro: Vector2 = puzzle.botao_confirmar.get_global_rect().get_center()
	puzzle._input(_clique(centro, true))
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
