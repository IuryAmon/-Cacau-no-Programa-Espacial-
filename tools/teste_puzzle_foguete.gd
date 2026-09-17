extends Node

# Teste de fumaça do puzzle do computador receptor (scenes/puzzle_foguete.tscn),
# aberto pelo painel com tubo de coleta (scenes/receptor_item_geral.tscn).
#
# Joga o puzzle inteiro com eventos de mouse de verdade (os mesmos que a
# pessoa gera), então os testes de acerto — alvéolo da mochila, boca do tubo,
# encaixes do foguete, setas da equação — são exercitados junto:
#
#   * o painel do mapa usa as folhas novas (vermelho travado, azul resolvido);
#   * a mochila sai do canto, ocupa (maior) o retangulo AreaMochila e volta;
#   * cilindro solto no tubo acende a vaga; item errado é recusado e volta;
#     solto fora do tubo, volta para o mesmo alvéolo;
#   * montagem: encaixe errado recusa, o certo instala;
#   * balanceamento e ignição continuam como antes, e resolver consome os
#     cilindros do inventário e deixa o painel azul;
#   * fechar no meio devolve os cilindros à mochila, sem perder nada.
#
#   godot --headless --path . res://tools/teste_puzzle_foguete.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma imagem de cada etapa
# na pasta, para conferir o layout a olho.

const HUD := "res://scenes/inventario_hud.tscn"
const RECEPTOR := "res://scenes/receptor_item_geral.tscn"
const ITEM_H2 := "Cilindro_de_Hidrogenio"
const ITEM_O2 := "Cilindro_Oxigenio"

var _falhas := 0
var _pasta_capturas := ""
var _hud: CanvasLayer = null


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			_pasta_capturas = arg.trim_prefix("--capturas=")
	# Sai do _ready da árvore antes de pendurar cenas na raiz.
	await get_tree().process_frame

	_hud = (load(HUD) as PackedScene).instantiate()
	get_tree().root.add_child(_hud)
	await get_tree().process_frame

	await _testar_painel_do_mapa()
	await _testar_abandonar_no_meio()
	await _testar_caminho_completo()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


# ─────────────────────────────────────────────────────────────

func _testar_painel_do_mapa() -> void:
	print("\n--- PAINEL NO MAPA (folhas novas) ---")
	var receptor := _novo_receptor("ReceptorPainel")
	await get_tree().process_frame
	var sprite: AnimatedSprite2D = receptor.get_node("ComputadorAnimado")
	var frames := sprite.sprite_frames
	_checar(frames.has_animation("vermelho") and frames.has_animation("azul"),
		"o painel tem as animacoes vermelho e azul")
	_checar(frames.get_frame_count("vermelho") == 20 and frames.get_frame_count("azul") == 20,
		"as duas animacoes usam os 20 quadros das folhas novas")
	var textura := frames.get_frame_texture("vermelho", 0) as AtlasTexture
	_checar(textura != null and textura.atlas.resource_path.ends_with(
		"Painel_Com_Tubo_De_Coleta_Vermelho.png"), "o vermelho vem do painel com tubo de coleta")
	textura = frames.get_frame_texture("azul", 19) as AtlasTexture
	_checar(textura != null and textura.atlas.resource_path.ends_with(
		"Painel_Com_Tubo_De_Coleta_Azul.png") and textura.region.position.x == 608.0,
		"o azul vem do painel azul, ate o ultimo quadro")
	_checar(sprite.animation == &"vermelho", "painel nao resolvido comeca vermelho")
	receptor.get_parent().queue_free()
	await get_tree().process_frame


func _testar_abandonar_no_meio() -> void:
	print("\n--- FECHAR NO MEIO DEVOLVE OS CILINDROS ---")
	_dar_cilindros()
	var receptor := _novo_receptor("ReceptorAbandono")
	await get_tree().process_frame
	var puzzle: CanvasLayer = receptor.puzzle_ui
	var mochila: MochilaHUD = _hud.get_node("Mochila")
	var canto := mochila.global_position

	receptor.verificar_puzzle()
	await _esperar(0.7)
	_checar(puzzle.visible and get_tree().paused, "o puzzle abriu e pausou o mundo")
	_checar(mochila.global_position.distance_to(canto) > 200.0, "a mochila saiu do canto")

	await _arrastar_da_mochila(puzzle, mochila, ITEM_H2, puzzle.centro_da_boca())
	await _esperar(0.2)
	_checar(mochila.esta_retirado(ITEM_H2), "cilindro jogado no tubo sai da mochila")
	_checar(Inventario.tem_item(ITEM_H2), "mas continua no inventario enquanto o puzzle nao acaba")

	puzzle._input(_tecla(KEY_ESCAPE))
	await _esperar(0.6)
	_checar(not puzzle.visible and not get_tree().paused, "ESC fecha e despausa")
	_checar(not mochila.esta_retirado(ITEM_H2) and mochila.tem(ITEM_H2),
		"o cilindro voltou para o alveolo")
	_checar(mochila.global_position.distance_to(canto) < 1.0, "a mochila voltou para o canto")
	_checar(receptor.get_node("ComputadorAnimado").animation == &"vermelho",
		"o painel continua vermelho")

	# Fecha e reabre antes de a mochila terminar de voltar ao canto.
	receptor.verificar_puzzle()
	await _esperar(0.3)
	puzzle._input(_tecla(KEY_ESCAPE))
	await _esperar(0.15)
	receptor.verificar_puzzle()
	await _esperar(0.3)
	puzzle._input(_tecla(KEY_ESCAPE))
	await _esperar(0.7)
	_checar(mochila.global_position.distance_to(canto) < 1.0,
		"fechar e reabrir rapido nao faz a mochila esquecer o canto")

	receptor.get_parent().queue_free()
	await get_tree().process_frame


func _testar_caminho_completo() -> void:
	print("\n--- CAMINHO COMPLETO ---")
	_dar_cilindros()
	# Um item que nao e combustivel, para o tubo recusar.
	var lenha := ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	Inventario.adicionar_item("lenha", "Lenha", lenha)
	await get_tree().process_frame

	var receptor := _novo_receptor("ReceptorCompleto")
	var resolvidos := []
	receptor.puzzle_resolvido.connect(func() -> void: resolvidos.append(true))
	await get_tree().process_frame
	var puzzle: CanvasLayer = receptor.puzzle_ui
	var mochila: MochilaHUD = _hud.get_node("Mochila")
	var canto := mochila.global_position

	receptor.verificar_puzzle()
	await _esperar(0.8)
	var tubo: TextureRect = puzzle.tubo
	var painel := mochila.retangulo_do_painel()
	var area: Rect2 = puzzle.area_mochila.get_global_rect()
	_checar(painel.get_center().distance_to(area.get_center()) < 2.0
		and area.grow(1.0).encloses(painel),
		"a mochila ocupa o retangulo AreaMochila da cena")
	_checar(mochila.scale.x > 1.05, "a mochila fica maior durante o puzzle")
	_checar(not puzzle.area_mochila.get_node("Etiqueta").visible,
		"a etiqueta de posicionamento some no jogo")
	_checar(puzzle.tela.scale.x > 1.05 and puzzle.tubo.scale.x > 1.05,
		"tela e tubo ficaram maiores")
	# Folga de uns pixels: a arte do tubo pode encostar na borda de baixo.
	var tela_cheia := Rect2(Vector2.ZERO, puzzle.get_viewport().get_visible_rect().size).grow(8.0)
	_checar(tela_cheia.encloses(puzzle.tela.get_global_rect())
		and tela_cheia.encloses(tubo.get_global_rect()) and tela_cheia.encloses(painel),
		"tubo, tela e mochila cabem na tela")
	_checar(not tubo.get_global_rect().intersects(puzzle.tela.get_global_rect()),
		"o tubo fica a esquerda da tela, sem sobrepor")
	await _capturar("1_coleta")

	# Item que nao e cilindro: recusado e devolvido.
	await _arrastar_da_mochila(puzzle, mochila, "lenha", puzzle.centro_da_boca())
	await _esperar(0.5)
	_checar(not mochila.esta_retirado("lenha"), "o tubo recusa o que nao e combustivel")

	# Solto fora do tubo: volta.
	await _arrastar_da_mochila(puzzle, mochila, ITEM_O2, Vector2(800, 850))
	await _esperar(0.5)
	_checar(not mochila.esta_retirado(ITEM_O2) and not puzzle._inseridos[ITEM_O2],
		"cilindro solto fora do tubo volta para a mochila")

	# H2 no tubo: a vaga acende.
	await _arrastar_da_mochila(puzzle, mochila, ITEM_H2, puzzle.centro_da_boca(), true)
	_checar(puzzle._inseridos[ITEM_H2], "hidrogenio entrou no tubo")
	# Afundar no tubo (0,3 s) + pulso na mangueira (0,5 s) + encher a vaga (0,9 s).
	await _esperar(2.0)
	_checar(puzzle._acesos[ITEM_H2], "a vaga do hidrogenio acendeu")
	var material: ShaderMaterial = puzzle._arte(ITEM_H2).material
	_checar(is_equal_approx(material.get_shader_parameter("aceso"), 1.0),
		"a silhueta encheu de cor")
	_checar(puzzle.etapa == puzzle.Etapa.COLETA, "com um so, continua na coleta")
	await _capturar("3_h2_aceso")

	await _arrastar_da_mochila(puzzle, mochila, ITEM_O2, puzzle.centro_da_boca())
	await _esperar(2.2)
	_checar(puzzle._acesos[ITEM_O2], "a vaga do oxigenio acendeu")
	_checar(puzzle.etapa == puzzle.Etapa.MONTAGEM, "com os dois acesos, vai para a montagem")
	await _esperar(1.2)
	_checar(not mochila.retangulo_do_painel().intersects(puzzle.tela.get_global_rect()),
		"na montagem a mochila continua sobre o tubo, sem cobrir a tela")
	_checar(mochila.modulate.a < 0.6, "e apaga, porque ja cumpriu o papel")
	_checar(puzzle.grupo_montagem.visible and not puzzle._em_transicao, "o foguete apareceu")
	await _capturar("4_montagem")

	# Montagem: errado recusa, certo instala.
	await _arrastar_peca(puzzle, ITEM_H2, puzzle.vaga_o2.get_global_rect().get_center())
	await _esperar(0.4)
	_checar(not puzzle._instalados[ITEM_H2], "hidrogenio no encaixe do oxigenio e recusado")
	await _arrastar_peca(puzzle, ITEM_H2, puzzle.vaga_h2.get_global_rect().get_center())
	_checar(puzzle._instalados[ITEM_H2], "hidrogenio instalado no encaixe dele")
	await _esperar(0.8)
	await _capturar("4b_h2_encaixado")
	await _arrastar_peca(puzzle, ITEM_O2, puzzle.vaga_o2.get_global_rect().get_center())
	_checar(puzzle._instalados[ITEM_O2], "oxigenio instalado no encaixe dele")
	_checar(puzzle.etapa == puzzle.Etapa.BALANCEAMENTO, "com os dois instalados, vai para a equacao")

	await _esperar(1.8)
	_checar(puzzle.grupo_equacao.visible and not puzzle.grupo_montagem.visible,
		"a equacao ocupa a tela sozinha")

	var display: Control = puzzle.display
	var caixa_tela := display.get_global_rect()
	for botao in [puzzle.botao_mais_h2, puzzle.botao_menos_h2o, puzzle.botao_ignicao,
			puzzle.label_produtos_valor]:
		_checar(caixa_tela.encloses(botao.get_global_rect()),
			"%s cabe dentro da tela do computador" % botao.name)

	# Balanceamento guiado: fala -> botão pedido -> meta, passo a passo.
	var mais_h2: Control = puzzle.botao_mais_h2
	var mais_o2: Control = puzzle.botao_mais_o2
	var mais_h2o: Control = puzzle.botao_mais_h2o
	var roteiro := [
		[mais_h2, [1, 0, 0], "5_passo1_lavoisier"],
		[mais_h2o, [1, 0, 1], "6_passo2_reagentes"],
		[mais_o2, [1, 1, 1], ""],
		[mais_h2o, [1, 1, 2], "7_passo4_oxigenio_em_dupla"],
		[null, [2, 1, 2], ""],
	]
	for i in roteiro.size():
		var alvo: Control = roteiro[i][0]
		var meta: Array = roteiro[i][1]
		_checar(await _esperar_fala(puzzle), "passo %d: o cientista fala" % (i + 1))
		_checar(puzzle.destaque.esta_ativo() or alvo == null,
			"passo %d: o holofote acende no que ele comenta" % (i + 1))
		if roteiro[i][2] != "":
			await _esperar(0.5)
			await _capturar(roteiro[i][2] + "_fala")
		await _pular_fala(puzzle)
		await _esperar(0.1)
		if alvo != null:
			_checar(puzzle._botao_do_passo == alvo and puzzle.destaque.tem_seta(),
				"passo %d: a seta aponta o botao %s" % [i + 1, alvo.name])
			if roteiro[i][2] != "":
				await _esperar(0.4)
				await _capturar(roteiro[i][2] + "_acao")
			# Clique no botão errado não conta.
			var errado: Control = puzzle.botao_menos_h2 if alvo != puzzle.botao_menos_h2 else mais_o2
			var antes: Array = puzzle.coeficientes.duplicate()
			puzzle._input(_clique(errado.get_global_rect().get_center(), true))
			_checar(puzzle.coeficientes == antes,
				"passo %d: botao fora do roteiro nao responde" % (i + 1))
			puzzle._input(_clique(alvo.get_global_rect().get_center(), true))
		else:
			_checar(puzzle._botao_do_passo == null and not puzzle.destaque.tem_seta(),
				"passo %d: livre, sem seta (voce ja sabe o que fazer)" % (i + 1))
			puzzle._input(_clique(mais_h2.get_global_rect().get_center(), true))
		_checar(puzzle.coeficientes == meta, "passo %d: coeficientes em %s" % [i + 1, str(meta)])

	# Último passo: equação certa, a seta vai para a ignição.
	_checar(await _esperar_fala(puzzle), "passo 6: o cientista comemora")
	await _pular_fala(puzzle)
	await _esperar(0.1)
	_checar(puzzle._botao_do_passo == puzzle.botao_ignicao and puzzle.destaque.tem_seta(),
		"passo 6: a seta aponta a ignicao")
	await _esperar(0.4)
	await _capturar("8_balanceada_ignicao")
	puzzle._input(_clique(puzzle.botao_ignicao.get_global_rect().get_center(), true))
	_checar(puzzle.etapa == puzzle.Etapa.IGNICAO and puzzle.travado, "ignicao iniciada")
	await _esperar(2.2)
	_checar(puzzle.grupo_montagem.visible and puzzle.fogo.emitting, "o foguete acende na tela")
	await _capturar("9_ignicao")
	await _esperar(2.4)
	_checar(puzzle.aguardando_fechamento, "pede o E para liberar o acesso")
	await _capturar("10_liberar_acesso")

	puzzle._input(_tecla(KEY_E))
	await _esperar(0.7)
	_checar(resolvidos.size() == 1, "puzzle_resolvido saiu uma vez")
	_checar(not Inventario.tem_item(ITEM_H2) and not Inventario.tem_item(ITEM_O2),
		"o receptor consumiu os cilindros")
	_checar(not mochila.tem(ITEM_H2) and not mochila.tem(ITEM_O2) and mochila.tem("lenha"),
		"os alveolos dos cilindros esvaziaram e a lenha ficou")
	_checar(receptor.get_node("ComputadorAnimado").animation == &"azul", "o painel ficou azul")
	_checar(not get_tree().paused and not puzzle.visible, "o mundo voltou a andar")
	_checar(mochila.global_position.distance_to(canto) < 1.0
		and is_equal_approx(mochila.modulate.a, 1.0) and mochila.scale.is_equal_approx(Vector2.ONE),
		"a mochila voltou acesa para o canto")
	_checar(Input.get_current_cursor_shape() == Input.CURSOR_ARROW, "o cursor voltou ao normal")

	receptor.get_parent().queue_free()
	await get_tree().process_frame


# ─────────────────────────────────────────────────────────────
# Apoio
# ─────────────────────────────────────────────────────────────

func _novo_receptor(nome: String) -> Area2D:
	var mundo := Node2D.new()
	mundo.name = nome
	get_tree().root.add_child(mundo)
	var receptor: Area2D = (load(RECEPTOR) as PackedScene).instantiate()
	mundo.add_child(receptor)
	return receptor


func _dar_cilindros() -> void:
	var folha := load("res://assets/itens/CILINDRO.png")
	for dados in [[ITEM_H2, "Cilindro de Hidrogênio", Rect2(16, 28, 12, 36)],
			[ITEM_O2, "Cilindro de Oxigênio", Rect2(32, 28, 16, 36)]]:
		if Inventario.tem_item(dados[0]):
			continue
		var arte := AtlasTexture.new()
		arte.atlas = folha
		arte.region = dados[2]
		Inventario.adicionar_item(dados[0], dados[1], arte)


func _arrastar_da_mochila(puzzle: CanvasLayer, mochila: MochilaHUD, id: String,
		destino: Vector2, capturar_no_meio: bool = false) -> void:
	var origem := mochila.centro_do_slot(mochila.indice_de(id))
	puzzle._input(_movimento(origem))
	puzzle._input(_clique(origem, true))
	await get_tree().process_frame
	for passo in 6:
		puzzle._input(_movimento(origem.lerp(destino, (passo + 1) / 6.0)))
		await get_tree().process_frame
	if capturar_no_meio:
		await _esperar(0.15)
		await _capturar("2_arrastando")
	puzzle._input(_clique(destino, false))


func _arrastar_peca(puzzle: CanvasLayer, id: String, destino: Vector2) -> void:
	var origem: Vector2 = puzzle._arte(id).get_global_rect().get_center()
	puzzle._input(_movimento(origem))
	puzzle._input(_clique(origem, true))
	await get_tree().process_frame
	puzzle._input(_movimento(destino))
	await get_tree().process_frame
	puzzle._input(_clique(destino, false))


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


## Espera o roteiro abrir a próxima fala (true se abriu).
func _esperar_fala(puzzle: CanvasLayer) -> bool:
	var espera := 0.0
	while not (puzzle.mostrando_dialogo_cientista and Dialogic.current_timeline != null) \
			and espera < 4.0:
		await _esperar(0.05)
		espera += 0.05
	return puzzle.mostrando_dialogo_cientista


## Pula a fala aberta (o Dialogic encerra de forma assíncrona).
func _pular_fala(puzzle: CanvasLayer) -> void:
	var espera := 0.0
	while puzzle.mostrando_dialogo_cientista and espera < 3.0:
		if Dialogic.current_timeline != null:
			Dialogic.end_timeline(true)
		await _esperar(0.1)
		espera += 0.1
