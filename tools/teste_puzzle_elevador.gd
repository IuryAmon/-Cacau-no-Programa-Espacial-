extends Node

# Teste do elevador de carga da fase 1 (ElevadorCarga/) e do puzzle que o
# libera (scenes/puzzle_carbono14.tscn): a pergunta do carbono-14 na tela do
# computador da fase 1.
#
#   * a tela é a do computador dos outros puzzles da fase 1, com a pergunta
#     (o isótopo radioativo que data fósseis de até 50 mil anos) e três
#     caixinhas de isótopo: carbono-12, 13 e 14, nessa ordem;
#   * toda letra existe na fonte e todo texto cabe no vidro, sem a pergunta
#     encostar nas caixas;
#   * abrir pausa o jogo, com nada escolhido; o mouse em cima foca a caixa, e
#     A/D (←/→) andam o foco;
#   * a resposta errada não libera: a caixa fica marcada e o rodapé diz por
#     que não é ela; ESC fecha sem resolver e reabrir começa limpo;
#   * a certa (pelo clique ou pelo ENTER) mostra ELEVADOR LIBERADO! e o E fecha
#     resolvendo; de controle, os alvos do cursor são as três caixas;
#   * na fase: o poço é vertical, o terminal fica no chão ao lado do pé da
#     plataforma e abre este puzzle; resolvido, a plataforma sobe e o terminal
#     fica azul e lembra;
#   * a curiosidade saiu do rádio do começo da fase (virou esta pergunta).
#
#   godot --headless --path . res://tools/teste_puzzle_elevador.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma imagem de cada
# momento na pasta, para conferir o layout a olho.

const PUZZLE := "res://scenes/puzzle_carbono14.tscn"
const FASE := "res://scenes/fases/fase1_oficina.tscn"
const RADIO := "res://timelines/radio_fase1.dtl"

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
	await _testar_na_fase()
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
	puzzle.abrir_puzzle()
	await _esperar(0.4)

	var tela: TextureRect = puzzle.get_node("RootControl/Tela")
	_checar(tela.texture.resource_path.ends_with("Computador receptor/tela_computador.png"),
		"a tela é a do computador dos outros puzzles da fase 1")
	_checar(puzzle.pergunta.text == puzzle.PERGUNTA and puzzle.PERGUNTA.contains("RADIOATIVO") \
		and puzzle.PERGUNTA.contains("50 MIL ANOS"), "a pergunta é a da curiosidade do carbono-14")

	var escritos: Array = []
	for caixa: Panel in puzzle.respostas:
		escritos.append([caixa.get_node("Massa").text, caixa.get_node("Simbolo").text, caixa.get_node("Nome").text])
	_checar(escritos == [["12", "C", "Carbono-12"], ["13", "C", "Carbono-13"], ["14", "C", "Carbono-14"]],
		"três caixinhas de isótopo, em ordem: carbono-12, 13 e 14 %s" % [escritos])
	_checar(puzzle.ALTERNATIVAS[puzzle.CERTA]["massa"] == 14, "a certa é o carbono-14")
	var sem_motivo := PackedStringArray()
	for i in puzzle.ALTERNATIVAS.size():
		if i != puzzle.CERTA and String(puzzle.ALTERNATIVAS[i]["por_que_nao"]).is_empty():
			sem_motivo.append(puzzle.ALTERNATIVAS[i]["nome"])
	_checar(sem_motivo.is_empty(), "toda errada diz por que não é ela %s" % [sem_motivo])

	# Toda letra na fonte, todo texto dentro do vidro.
	var fonte: Font = puzzle.pergunta.get_theme_font("font")
	var textos: Array = [puzzle.TXT_INSTRUCAO, puzzle.TXT_CERTO, puzzle.TXT_LIGAR]
	for dados: Dictionary in puzzle.ALTERNATIVAS:
		textos.append(dados["por_que_nao"])
	var vidro: Rect2 = puzzle.display.get_global_rect()
	var cortados := PackedStringArray()
	for label: Label in puzzle.find_children("*", "Label", true, false):
		textos.append(label.text)
		if puzzle.display.is_ancestor_of(label) and label.is_visible_in_tree() \
				and not vidro.encloses(label.get_global_rect()):
			cortados.append(label.name)
	var faltando := ""
	var marca := RegEx.create_from_string("\\{[^}]*\\}")
	for texto in textos:
		for c in marca.sub(String(texto), "", true):
			if c == " " or c == "\n" or c.unicode_at(0) >= BotoesControle.PRIMEIRO_CODIGO:
				continue
			if not fonte.has_char(c.unicode_at(0)) and not faltando.contains(c):
				faltando += c
	_checar(faltando.is_empty(), "toda letra da tela e dos avisos existe na fonte [%s]" % faltando)
	_checar(cortados.is_empty(), "todo texto cabe no vidro %s" % [cortados])
	var linhas: int = puzzle.pergunta.get_line_count()
	var caixas: Rect2 = puzzle.get_node("RootControl/Tela/Display/GrupoPergunta/Respostas").get_global_rect()
	_checar(linhas <= 4 and puzzle.pergunta.get_global_rect().end.y < caixas.position.y,
		"a pergunta (%d linhas) não encosta nas caixas" % linhas)
	var largura_do_rodape: float = puzzle.rodape.size.x
	var compridos := PackedStringArray()
	for dados: Dictionary in puzzle.ALTERNATIVAS:
		if fonte.get_string_size(String(dados["por_que_nao"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > largura_do_rodape:
			compridos.append(dados["nome"])
	_checar(compridos.is_empty(), "cada motivo de erro cabe numa linha do rodapé %s" % [compridos])
	await _capturar("elevador_1_pergunta")
	puzzle.fechar_puzzle(false)
	puzzle.queue_free()
	await get_tree().process_frame


func _testar_puzzle() -> void:
	print("\n--- RESPONDENDO ---")
	var puzzle := await _novo()
	var resolvido := [false]
	puzzle.puzzle_resolvido.connect(func() -> void: resolvido[0] = true)
	puzzle.abrir_puzzle()
	await _esperar(0.4)
	_checar(puzzle.visible and get_tree().paused, "abrir mostra a tela e pausa o jogo")
	_checar(puzzle.foco == -1 and not puzzle.erradas.has(true) and puzzle._rodape_texto == puzzle.TXT_INSTRUCAO,
		"abre com nada escolhido e o rodapé pedindo a resposta")

	print("  . o foco")
	puzzle._input(_movimento(_centro(puzzle, 1)))
	_checar(puzzle.foco == 1, "o mouse em cima da caixa do meio foca ela")
	puzzle._input(_tecla(KEY_D))
	_checar(puzzle.foco == 2, "D anda o foco para a direita")
	puzzle._input(_tecla(KEY_D))
	_checar(puzzle.foco == 2, "e para na última")
	puzzle._input(_tecla(KEY_LEFT))
	puzzle._input(_tecla(KEY_A))
	puzzle._input(_tecla(KEY_A))
	_checar(puzzle.foco == 0, "← e A voltam e param na primeira")
	var borda_do_foco: Color = puzzle._estilo_de(puzzle.respostas[0]).border_color
	_checar(borda_do_foco == puzzle.COR_FOCO, "a caixa em foco fica amarela")

	print("  . a errada")
	_clicar(puzzle, _centro(puzzle, 0))
	await get_tree().process_frame
	_checar(not puzzle.travado and puzzle.erradas[0] and not resolvido[0], "o carbono-12 não libera")
	_checar(puzzle._rodape_texto == puzzle.ALTERNATIVAS[0]["por_que_nao"]
		and puzzle._estilo_de(puzzle.respostas[0]).border_color == puzzle.COR_ERRO,
		"a caixa fica vermelha e o rodapé diz por que não é ela")
	await _capturar("elevador_2_errada")
	puzzle._input(_tecla(KEY_D))
	puzzle._input(_tecla(KEY_ENTER))
	await get_tree().process_frame
	_checar(puzzle.erradas[1] and not puzzle.travado, "o ENTER responde a caixa em foco: o carbono-13 também não")
	puzzle._input(_tecla(KEY_ESCAPE))
	_checar(not puzzle.visible and not get_tree().paused and not resolvido[0], "ESC fecha sem resolver")
	puzzle.abrir_puzzle()
	await _esperar(0.3)
	_checar(not puzzle.erradas.has(true) and puzzle.foco == -1, "reabrir começa limpo")

	print("  . a certa")
	_clicar(puzzle, _centro(puzzle, puzzle.CERTA))
	await get_tree().process_frame
	_checar(puzzle.travado and puzzle._rodape_texto == puzzle.TXT_CERTO
		and puzzle._estilo_de(puzzle.respostas[puzzle.CERTA]).border_color == puzzle.COR_CERTO,
		"o carbono-14 fica verde e o rodapé diz CERTO")
	puzzle._input(_tecla(KEY_ESCAPE))
	_checar(puzzle.visible, "com a resposta dada, o ESC não fecha no meio da festa")
	await _capturar("elevador_3_certa")
	await _esperar(puzzle.ESPERA_DO_CERTO + 0.5)
	_checar(puzzle.grupo_liberado.visible and not puzzle.grupo_pergunta.visible and puzzle.aguardando_fechamento,
		"depois, a tela mostra ELEVADOR LIBERADO!")
	_checar(puzzle._rodape_texto.contains("LIGAR O ELEVADOR"), "e o rodapé diz como ligar o elevador")
	await _capturar("elevador_4_liberado")
	puzzle._input(_tecla(KEY_E))
	await get_tree().process_frame
	_checar(resolvido[0] and not puzzle.visible and not get_tree().paused, "o E fecha resolvendo e o jogo volta")
	puzzle.queue_free()
	await get_tree().process_frame


func _testar_controle() -> void:
	print("\n--- DE CONTROLE ---")
	var puzzle := await _novo()
	puzzle.abrir_puzzle()
	await _esperar(0.4)
	_checar(puzzle.is_in_group(CursorVirtual.GRUPO), "a tela tem o cursor do controle")
	var alvos: Array[Rect2] = puzzle.alvos_do_cursor()
	_checar(alvos.size() == 3 and alvos[0] == puzzle.retangulo_da_resposta(0)
		and alvos[2] == puzzle.retangulo_da_resposta(2), "os alvos do cursor são as três caixas")
	_checar(puzzle.dicas_do_controle().map(func(d): return d[1]) == ["MOVER", "ESCOLHER", "RESPONDER", "SAIR"],
		"a barra diz RESPONDER")
	puzzle._responder(puzzle.CERTA)
	_checar(puzzle.alvos_do_cursor().is_empty(), "respondido certo, nada mais vira alvo")
	puzzle.fechar_puzzle(false)
	puzzle.queue_free()
	await get_tree().process_frame


# ─────────────────────────────────────────────────────────────

func _testar_na_fase() -> void:
	print("\n--- NA FASE 1 ---")
	var radio := FileAccess.get_file_as_string(RADIO)
	_checar(not radio.is_empty() and not radio.to_lower().contains("carbono-14"),
		"a curiosidade do carbono-14 saiu do rádio do começo da fase")

	var fase := (load(FASE) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(fase)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	var terminal: ComputadorPuzzle = fase.get_node("ElevadorCarga/TerminalGuincho")
	var plataforma: Path2D = fase.get_node("ElevadorCarga/PlataformaCarga")
	var trilho: PathFollow2D = plataforma.get_node("PathFollow2D")
	var puzzle: CanvasLayer = terminal._puzzle_ui
	_checar(terminal.puzzle_cena != null and terminal.puzzle_cena.resource_path == PUZZLE and puzzle != null,
		"o terminal do elevador abre a pergunta do carbono-14")
	if puzzle == null:
		fase.queue_free()
		return

	# O poço: nada aqui crava coordenada (arrastar a plataforma no editor é
	# level design). O que se cobra é a RELAÇÃO: o poço é vertical, a ponta de
	# baixo para perto do chão e o terminal fica ao lado dela, a pé.
	# O terminal fica de pé no chão do andar, então a altura dele é o chão.
	var topo: Vector2 = plataforma.to_global(plataforma.curve.get_point_position(0))
	var base: Vector2 = plataforma.to_global(plataforma.curve.get_point_position(1))
	var chao: float = terminal.global_position.y
	_checar(absf(topo.x - base.x) < 8.0, "o poço é vertical (x %.0f em cima, %.0f embaixo)" % [topo.x, base.x])
	_checar(base.y > topo.y and base.y > chao - 96.0 and base.y <= chao,
		"a ponta de baixo para logo acima do chão do terminal (y = %.0f, chão %.0f)" % [base.y, chao])
	_checar(absf(terminal.global_position.x - base.x) < 320.0,
		"o terminal fica ao lado da plataforma (%.0f px)" % (terminal.global_position.x - base.x))
	_checar(plataforma.comecar_no_fim and is_equal_approx(trilho.progress_ratio, 1.0),
		"a plataforma começa no chão")

	puzzle.abrir_puzzle()
	await get_tree().process_frame
	puzzle._responder(puzzle.CERTA)
	await _esperar(puzzle.ESPERA_DO_CERTO + 0.5)
	puzzle._input(_tecla(KEY_E))
	await get_tree().process_frame
	_checar(plataforma.ativa, "resolvida, a pergunta liga a plataforma")
	_checar(terminal._painel.animation == &"azul", "o painel do terminal fica azul")
	_checar(EstadoMundo.ja_feito(terminal), "e o terminal lembra que foi resolvido")
	var antes: float = trilho.progress_ratio
	for i in 40:
		await get_tree().process_frame
	_checar(trilho.progress_ratio < antes, "a plataforma sobe do chão")

	# Deixa tudo como estava para quem rodar outra coisa em seguida.
	EstadoMundo.desmarcar_caminho(str(terminal.get_path()))
	fase.queue_free()
	await get_tree().process_frame


# ─────────────────────────────────────────────────────────────

func _novo() -> CanvasLayer:
	var puzzle := (load(PUZZLE) as PackedScene).instantiate() as CanvasLayer
	add_child(puzzle)
	await get_tree().process_frame
	return puzzle


func _centro(puzzle: CanvasLayer, i: int) -> Vector2:
	return puzzle.retangulo_da_resposta(i).get_center()


## Um clique de mouse de verdade (passar, apertar e soltar) no ponto.
func _clicar(puzzle: CanvasLayer, pos: Vector2) -> void:
	puzzle._input(_movimento(pos))
	puzzle._input(_clique(pos, true))
	puzzle._input(_clique(pos, false))


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
