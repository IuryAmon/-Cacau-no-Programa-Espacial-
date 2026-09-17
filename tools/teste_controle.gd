extends Node

# Teste do CONTROLE (PlayStation): mapa de botões, troca teclado <-> controle,
# posse do toque, cursor dos puzzles e o □ que divide interagir e bumerangue.
#
# Tudo entra como entrada de verdade — eventos de botão e de analógico por
# Input.parse_input_event, do mesmo jeito que o controle físico chega:
#
#   * o mapa: ✕ pula, □ interage e arremessa, ○ dá dash e é "sair" (ui_cancel),
#     △ acende o maçarico, ✕ e □ passam a fala do Dialogic;
#   * o Controle percebe o controle e o teclado, e os textos com {acao} viram
#     "E" no teclado e o desenho do □ no controle;
#   * o toque que nasce com tela aberta fica preso a ela até ser solto;
#   * puzzle do maçarico resolvido SÓ com o controle (cursor, direcional, ✕) e
#     a gaiola aberta com □;
#   * puzzle do hidrogênio: segurar ✕ arrasta, soltar larga;
#   * puzzle de ordenar: arrastar até o encaixe, e ○ desiste;
#   * guincho sem cursor: direcional gira o mostrador, ✕ aciona, □ solta;
#   * dosagem: ○ desiste;
#   * □ perto de algo que responde: interagir vence, o bumerangue fica na mão;
#     longe de tudo: o bumerangue voa;
#   * o bumerangue sai no ângulo exato do analógico (não só nas 8 direções),
#     encaixando no reto só bem perto da horizontal/vertical; o direcional e o
#     dash continuam nas 8 direções;
#   * o analógico como círculo: a diagonal anda na velocidade normal, só a
#     fatia vertical não anda, com folga nas divisas; o dash reparte em fatias
#     de 45°; descer da plataforma e entrar na porta só apontando de verdade.
#
#   godot --headless --path . res://tools/teste_controle.tscn

const MACARICO := "res://scenes/puzzle_macarico.tscn"
const HIDROGENIO := "res://scenes/puzzle_hidrogenio.tscn"
const GUINCHO := "res://scenes/puzzle_guincho.tscn"
const PLAYER := "res://scenes/player.tscn"

var _falhas := 0


## Uma coisa do mundo que responde ao E/□ (como a gaiola ou o item do chão).
class Interagivel extends Node:
	var ativo := true
	var usos := 0

	func _process(_delta: float) -> void:
		if ativo and Interacao.pediu():
			usos += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame

	_testar_mapa()
	await _testar_troca_de_dispositivo()
	await _testar_posse_do_toque()
	await _testar_macarico()
	await _testar_hidrogenio()
	await _testar_ordenar()
	await _testar_guincho()
	await _testar_dosagem()
	await _testar_quadrado_dividido()
	await _testar_mira_analogica()
	await _testar_andar_analogico()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


# ─────────────────────────────────────────────────────────────

func _testar_mapa() -> void:
	print("\n--- MAPA DO CONTROLE ---")
	_checar(_tem_botao("jump", JOY_BUTTON_A), "✕ pula")
	_checar(_tem_botao("interact", JOY_BUTTON_X), "□ interage")
	_checar(_tem_botao("arremessar", JOY_BUTTON_X), "□ arremessa o bumerangue")
	_checar(_tem_botao("dash", JOY_BUTTON_B), "○ dá o dash")
	_checar(_tem_botao("usar_macarico", JOY_BUTTON_Y) and not _tem_botao("usar_macarico", JOY_BUTTON_B),
		"△ acende o maçarico (e ○ ficou só para o dash)")
	_checar(_tem_botao("ui_cancel", JOY_BUTTON_B), "○ é sair (ui_cancel)")
	_checar(_tem_tecla("ui_cancel", KEY_ESCAPE), "ESC continua sendo sair")
	_checar(_tem_botao("ui_accept", JOY_BUTTON_A), "✕ confirma (ui_accept)")
	_checar(_tem_botao("dialogic_default_action", JOY_BUTTON_A)
		and _tem_botao("dialogic_default_action", JOY_BUTTON_X), "✕ e □ passam a fala")
	for acao in ["ui_accept", "dialogic_default_action", "ui_cancel"]:
		var qualquer := true
		for evento in InputMap.action_get_events(acao):
			if evento is InputEventJoypadButton and evento.device != -1:
				qualquer = false
		_checar(qualquer, "%s aceita qualquer controle (não só o nº 0)" % acao)


func _tem_botao(acao: String, botao: JoyButton) -> bool:
	for evento in InputMap.action_get_events(acao):
		if evento is InputEventJoypadButton and evento.button_index == botao:
			return true
	return false


func _tem_tecla(acao: String, tecla: Key) -> bool:
	for evento in InputMap.action_get_events(acao):
		if evento is InputEventKey and (evento.keycode == tecla or evento.physical_keycode == tecla):
			return true
	return false


# ─────────────────────────────────────────────────────────────

func _testar_troca_de_dispositivo() -> void:
	print("\n--- TECLADO OU CONTROLE ---")
	_tecla(KEY_F10)
	await _quadros(3)
	_checar(not Controle.em_uso, "tecla põe no teclado")

	var avisos := [0]
	var contar := func(_em_uso: bool) -> void: avisos[0] += 1
	Controle.mudou.connect(contar)
	await _tocar(JOY_BUTTON_Y)
	_checar(Controle.em_uso, "botão do controle põe no controle")
	_checar(avisos[0] == 1, "e avisa pelo sinal 'mudou'")

	_mouse(Vector2(40, 0), 0)
	await _quadros(3)
	_checar(not Controle.em_uso, "mexer o mouse de verdade volta para o teclado")
	await _tocar(JOY_BUTTON_Y)
	_mouse(Vector2(200, 0), Controle.DISPOSITIVO_VIRTUAL)
	await _quadros(3)
	_checar(Controle.em_uso, "o mouse fabricado pelo cursor não conta como mouse")
	Controle.mudou.disconnect(contar)

	print("\n--- TEXTOS COM {acao} ---")
	var quadrado := BotoesControle.caractere("quadrado")
	_checar(BotoesControle.traduzir("APERTE {interact} PARA", false) == "APERTE E PARA",
		"teclado: {interact} vira E")
	_checar(BotoesControle.traduzir("APERTE {interact} PARA", true) == "APERTE %s PARA" % quadrado,
		"controle: {interact} vira o □")
	_checar(BotoesControle.traduzir("{ui_cancel}", false) == "ESC", "teclado: {ui_cancel} vira ESC")
	_checar(BotoesControle.traduzir("{ui_cancel}", true) == BotoesControle.caractere("bolinha"),
		"controle: {ui_cancel} vira o ○")
	_checar(BotoesControle.traduzir("{ui_right:D}", false) == "D", "teclado: a tecla depois do ':' vale")
	_checar(BotoesControle.traduzir("{ui_right:D}", true) == BotoesControle.caractere("direcional_direita"),
		"controle: o direcional com o lado apertado aceso")
	_checar(BotoesControle.traduzir("A{teclado: B}{controle: C}", false) == "A B"
		and BotoesControle.traduzir("A{teclado: B}{controle: C}", true) == "A C",
		"trechos só do teclado e só do controle")

	var label := Label.new()
	add_child(label)
	Controle.rotular(label, "APERTE {interact} PARA ABRIR")
	await _quadros(2)
	var icones := label.get_children(true).filter(func(n): return n is IconesNoTexto)
	_checar(icones.size() == 1 and icones[0].visible and label.self_modulate.a == 0.0,
		"no controle o Label some e o desenhista de botões assume")
	_tecla(KEY_F10)
	await _quadros(3)
	_checar(label.text == "APERTE E PARA ABRIR" and label.self_modulate.a == 1.0 and not icones[0].visible,
		"voltou ao teclado: o Label se reescreve e volta a se desenhar")
	label.queue_free()


# ─────────────────────────────────────────────────────────────

func _testar_posse_do_toque() -> void:
	print("\n--- O TOQUE QUE FECHA A TELA É DA TELA ---")
	var tela := Node.new()
	add_child(tela)
	Interacao.marcar_tela_aberta(tela, true)
	_botao(JOY_BUTTON_A, true)
	await _quadros(3)
	_checar(Interacao.toque_preso(&"jump"), "✕ apertado com tela aberta fica preso")
	Interacao.marcar_tela_aberta(tela, false)
	_checar(not Interacao.livre_para(&"jump"), "a tela fechou, mas o ✕ segurado não vira pulo")
	_botao(JOY_BUTTON_A, false)
	await _quadros(4)
	_checar(Interacao.livre_para(&"jump"), "soltou: o próximo ✕ é do mundo")
	_botao(JOY_BUTTON_A, true)
	await _quadros(3)
	_checar(not Interacao.toque_preso(&"jump"), "✕ sem tela aberta não fica preso")
	_botao(JOY_BUTTON_A, false)
	await _quadros(3)
	tela.queue_free()


# ─────────────────────────────────────────────────────────────

func _testar_macarico() -> void:
	print("\n--- PUZZLE DO MAÇARICO SÓ COM O CONTROLE ---")
	var puzzle: CanvasLayer = load(MACARICO).instantiate()
	add_child(puzzle)
	await _quadros(2)
	var resolvido := [false]
	puzzle.puzzle_resolvido.connect(func() -> void: resolvido[0] = true)
	await _tocar(JOY_BUTTON_Y)
	puzzle.abrir_puzzle()
	await _esperar(0.4)

	_checar(CursorVirtual.ativo() and CursorVirtual._com_cursor, "o cursor aparece no puzzle")
	_checar(CursorVirtual._alvos.size() == 9, "alvos: as 8 setas da etapa 1 e o botão (%d)" % CursorVirtual._alvos.size())
	_checar(BotoesControle.tem_icone(puzzle.get_node("RootControl/Instrucoes").text),
		"o '{ui_cancel} para fechar' do canto virou botão")

	# O analógico move o cursor.
	CursorVirtual._pos = Vector2(300, 450)
	CursorVirtual._ir_ao_alvo_em = -1.0
	_eixo(JOY_AXIS_LEFT_X, 1.0)
	await _esperar(0.25)
	_eixo(JOY_AXIS_LEFT_X, 0.0)
	await _quadros(2)
	_checar(CursorVirtual._pos.x > 400.0, "analógico para a direita leva o cursor (x = %.0f)" % CursorVirtual._pos.x)

	# O direcional pula de alvo em alvo.
	CursorVirtual._pos = puzzle._termos[0].retangulo_do_botao(1).get_center()
	await _tocar(JOY_BUTTON_DPAD_RIGHT)
	await _esperar(0.2)
	var destino: Vector2 = puzzle._termos[1].retangulo_do_botao(1).get_center()
	_checar(CursorVirtual._pos.distance_to(destino) < 2.0,
		"direcional → vai da seta de cima do 1º termo para a do 2º")
	await _tocar(JOY_BUTTON_DPAD_DOWN)
	await _esperar(0.2)
	destino = puzzle._termos[1].retangulo_do_botao(-1).get_center()
	_checar(CursorVirtual._pos.distance_to(destino) < 2.0, "direcional ↓ vai para a seta de baixo do mesmo termo")

	# Etapa 1: 1 C2H2 + 1 O2 -> 2 CO + 1 H2, tudo no ✕.
	await _clicar_seta(puzzle, 0, 1)
	_checar(puzzle.coeficientes[0] == 1, "✕ na seta de cima soma 1")
	await _clicar_seta(puzzle, 1, 1)
	await _clicar_seta(puzzle, 2, 2)
	await _clicar_seta(puzzle, 3, 1)
	_checar(puzzle.coeficientes == [1, 1, 2, 1], "coeficientes da etapa 1 montados com o controle")
	await _clicar_em(puzzle._retangulo_do_confirmar().get_center())
	await _esperar(3.0)
	_checar(puzzle.etapa == 1, "✕ no botão confirma e a etapa 2 entra")

	for i in 5:
		await _clicar_seta(puzzle, i, 1)
	await _clicar_em(puzzle._retangulo_do_confirmar().get_center())
	await _esperar(2.2)
	_checar(puzzle.aguardando_fechamento, "etapa 2 resolvida: maçarico liberado")
	_checar(BotoesControle.tem_icone(puzzle.rodape.text), "o rodapé pede o □ desenhado, e não o E")
	_checar(CursorVirtual._dicas()[0][0] == Interacao.ACAO, "a barra mostra o □ para abrir a gaiola")

	_botao(JOY_BUTTON_X, true)
	await _quadros(4)
	_checar(resolvido[0] and not puzzle.visible, "□ abre a gaiola e fecha o puzzle")
	_checar(not get_tree().paused, "o jogo volta a andar")
	_checar(Interacao.toque_preso(&"arremessar"), "o □ que fechou o puzzle não vira bumerangue")
	_botao(JOY_BUTTON_X, false)
	await _quadros(4)
	_checar(Interacao.livre_para(&"arremessar"), "soltou o □: o bumerangue volta a estar livre")
	_checar(not CursorVirtual.ativo(), "o cursor some com o puzzle")
	puzzle.queue_free()
	await _quadros(2)


func _clicar_seta(puzzle: CanvasLayer, termo: int, vezes: int) -> void:
	for k in vezes:
		await _clicar_em(puzzle._termos[termo].retangulo_do_botao(1).get_center())


func _clicar_em(ponto: Vector2) -> void:
	CursorVirtual._pos = ponto
	CursorVirtual._pulo_t = 1.0
	await _tocar(JOY_BUTTON_A)


# ─────────────────────────────────────────────────────────────

func _testar_hidrogenio() -> void:
	print("\n--- ARRASTAR COM O ✕ (PUZZLE DO HIDROGÊNIO) ---")
	var puzzle: CanvasLayer = load(HIDROGENIO).instantiate()
	add_child(puzzle)
	await _quadros(3)
	var resolvido := [false]
	puzzle.puzzle_resolvido.connect(func() -> void: resolvido[0] = true)
	puzzle.abrir_puzzle()
	await _esperar(0.3)
	_checar(CursorVirtual.ativo(), "cursor ligado no puzzle do hidrogênio")
	_checar(CursorVirtual._alvos.size() == 3, "alvos: próton, nêutron e elétron")

	await _arrastar(puzzle.peca_proton.get_global_rect().get_center(),
		puzzle.zona_nucleo.get_global_rect().get_center(), puzzle)
	_checar(puzzle.proton_colocado, "segurar ✕ no próton, levar ao núcleo e soltar: próton no núcleo")

	await _arrastar(puzzle.peca_eletron.get_global_rect().get_center(),
		puzzle.zona_orbita.get_global_rect().get_center(), puzzle)
	_checar(puzzle.eletron_colocado, "o elétron vai para a órbita do mesmo jeito")
	_checar(puzzle.travado, "átomo montado")
	_checar(CursorVirtual._dicas()[0][0] == Interacao.ACAO, "a barra pede o □ para abrir a gaiola")

	_botao(JOY_BUTTON_A, true)
	await _quadros(4)
	_checar(resolvido[0] and not puzzle.visible, "✕ também fecha o puzzle resolvido")
	_checar(Interacao.toque_preso(&"jump"), "e esse ✕ não faz a Cacau pular ao sair")
	_botao(JOY_BUTTON_A, false)
	await _quadros(4)
	puzzle.queue_free()
	await _quadros(2)


## Segura o ✕ em "de", leva o cursor até "para" e solta — conferindo no meio
## do caminho que a peça veio junto.
func _arrastar(de: Vector2, para: Vector2, puzzle: CanvasLayer = null) -> void:
	CursorVirtual._pos = de
	CursorVirtual._pulo_t = 1.0
	_botao(JOY_BUTTON_A, true)
	await _quadros(4)
	if puzzle != null and "peca_arrastando" in puzzle:
		_checar(puzzle.peca_arrastando != null, "  (✕ segurado pegou a peça)")
	CursorVirtual._pos = para
	CursorVirtual._enviar_movimento()
	await _quadros(3)
	_botao(JOY_BUTTON_A, false)
	await _quadros(4)


# ─────────────────────────────────────────────────────────────

func _testar_ordenar() -> void:
	print("\n--- PUZZLE DE ARRASTAR GENÉRICO ---")
	var config := {
		"titulo": "TESTE",
		"slots": [{"aceita": "a", "rotulo": "A"}],
		"pecas": [{"id": "a", "texto": "PEÇA A"}, {"id": "b", "texto": "PEÇA B"}],
		"texto_vitoria": "Certo!",
	}
	var resolvido := [false]
	var puzzle := PuzzleOrdenar.nova(self, config)
	puzzle.resolvido.connect(func() -> void: resolvido[0] = true)
	await _esperar(0.3)
	_checar(CursorVirtual.ativo(), "cursor ligado no puzzle de ordenar")
	_checar(BotoesControle.tem_icone(puzzle._status.text), "o rodapé mostra o ○ para desistir")
	var peca_a: Panel = puzzle._nos_pecas.filter(func(p): return p.get_meta("id") == "a")[0]
	await _arrastar(peca_a.get_global_rect().get_center(), puzzle._nos_slots[0].get_global_rect().get_center())
	_checar(puzzle._vitoria, "peça arrastada com o controle encaixa")
	await _tocar(JOY_BUTTON_X)
	await _quadros(2)
	_checar(resolvido[0] and not is_instance_valid(puzzle), "□ continua depois de resolvido")

	var outro := PuzzleOrdenar.nova(self, config)
	await _esperar(0.2)
	_botao(JOY_BUTTON_B, true)
	await _quadros(4)
	_checar(not is_instance_valid(outro), "○ desiste do puzzle")
	_checar(Interacao.toque_preso(&"dash"), "e esse ○ não vira dash")
	_botao(JOY_BUTTON_B, false)
	await _quadros(4)


# ─────────────────────────────────────────────────────────────

func _testar_guincho() -> void:
	print("\n--- GUINCHO: O CONTROLE OPERA DIRETO ---")
	var puzzle: CanvasLayer = load(GUINCHO).instantiate()
	add_child(puzzle)
	await _quadros(2)
	var resolvido := [false]
	puzzle.puzzle_resolvido.connect(func() -> void: resolvido[0] = true)
	puzzle.abrir_puzzle()
	await _esperar(0.2)
	_checar(CursorVirtual.ativo() and not CursorVirtual._com_cursor, "barra de botões sem cursor")
	_checar(BotoesControle.tem_icone(puzzle._status.text), "o rodapé mostra os botões do controle")
	for i in 4:
		await _tocar(JOY_BUTTON_DPAD_RIGHT)
	for i in 5:
		await _tocar(JOY_BUTTON_DPAD_UP)
	_checar(is_equal_approx(puzzle._forca, 450.0), "→ ×4 e ↑ ×5 chegam em 450 N (%.0f)" % puzzle._forca)
	await _tocar(JOY_BUTTON_A)
	_checar(puzzle._travado, "✕ aciona o guincho")
	await _tocar(JOY_BUTTON_X)
	_checar(resolvido[0] and not puzzle.visible, "□ solta a plataforma")
	puzzle.queue_free()
	await _quadros(2)


# ─────────────────────────────────────────────────────────────

func _testar_dosagem() -> void:
	print("\n--- DOSAGEM: ○ DESISTE ---")
	var fim := [false, false]
	var dosagem := Dosagem.abrir(self, {"modo": "parar", "titulo": "TESTE"})
	dosagem.terminado.connect(func(sucesso: bool, cancelado: bool) -> void:
		fim[0] = true
		fim[1] = cancelado and not sucesso)
	await _esperar(0.2)
	_checar(CursorVirtual.ativo() and not CursorVirtual._com_cursor, "dosagem ganha a barra, sem cursor")
	await _tocar(JOY_BUTTON_B)
	await _quadros(3)
	_checar(fim[0] and fim[1], "○ cancela a dosagem")


# ─────────────────────────────────────────────────────────────

func _testar_quadrado_dividido() -> void:
	print("\n--- □: INTERAGIR VENCE O BUMERANGUE ---")
	var player: CharacterBody2D = load(PLAYER).instantiate()
	add_child(player)
	player.global_position = Vector2(800, 400)
	# Sem chão na cena de teste: a personagem fica parada no ar.
	player.set_physics_process(false)
	var ferramentas := FerramentasPlayer.instalar(player)
	Progresso._habilidades["bumerangue"] = true
	await _esperar(0.3)

	var perto := Interagivel.new()
	add_child(perto)
	_botao(JOY_BUTTON_X, true)
	await _esperar(0.15)
	_checar(perto.usos == 1, "□ perto de algo interativo interage")
	_checar(not ferramentas._bumerangue_no_ar, "e o bumerangue fica na mão")
	_botao(JOY_BUTTON_X, false)
	await _esperar(0.15)

	perto.ativo = false
	_botao(JOY_BUTTON_X, true)
	await _esperar(0.15)
	_checar(ferramentas._bumerangue_no_ar, "□ longe de tudo arremessa o bumerangue")
	_botao(JOY_BUTTON_X, false)
	await _esperar(0.1)

	Progresso._habilidades.erase("bumerangue")
	# O bumerangue em voo aponta para a personagem: sai de cena antes dela.
	if is_instance_valid(ferramentas._bumerangue):
		ferramentas._bumerangue.queue_free()
	await _quadros(2)
	perto.queue_free()
	player.queue_free()
	await _quadros(3)


# ─────────────────────────────────────────────────────────────

func _testar_mira_analogica() -> void:
	print("\n--- BUMERANGUE NO ÂNGULO DO ANALÓGICO ---")
	var player: CharacterBody2D = load(PLAYER).instantiate()
	add_child(player)
	player.global_position = Vector2(800, 400)
	player.set_physics_process(false)
	var ferramentas := FerramentasPlayer.instalar(player)
	Progresso._habilidades["bumerangue"] = true
	await _esperar(0.3)

	for graus in [-60.0, 160.0, 35.0, -125.0]:
		await _analogico(graus, 1.0)
		var mira: Vector2 = ferramentas._mira_do_bumerangue()
		_checar(absf(rad_to_deg(mira.angle()) - graus) < 0.5,
			"analógico a %.0f° mira a %.0f° (saiu %.1f°)" % [graus, graus, rad_to_deg(mira.angle())])

	await _analogico(-60.0, 0.4)
	_checar(absf(rad_to_deg(ferramentas._mira_do_bumerangue().angle()) + 60.0) < 0.5,
		"meio empurrado já mira no ângulo certo (zona morta de andar não atrapalha)")

	await _analogico(3.0, 1.0)
	_checar(ferramentas._mira_do_bumerangue() == Vector2.RIGHT, "3° da horizontal encaixa no reto")
	await _analogico(-92.0, 1.0)
	_checar(ferramentas._mira_do_bumerangue() == Vector2.UP, "2° da vertical encaixa no reto, sem sobra no x")
	await _analogico(10.0, 1.0)
	var dez: float = rad_to_deg(ferramentas._mira_do_bumerangue().angle())
	_checar(dez > 0.5 and dez < 10.0, "10° fica entre o reto e o ângulo cru, sem salto (%.1f°)" % dez)
	await _analogico(15.0, 1.0)
	_checar(absf(rad_to_deg(ferramentas._mira_do_bumerangue().angle()) - 15.0) < 0.5,
		"de 15° em diante vale o ângulo cru")

	await _analogico(45.0, 0.15)
	_checar(ferramentas._mira_do_bumerangue() == Vector2(ferramentas._facing(), 0.0),
		"analógico só tremendo no centro não mira: vale o lado que ela olha")

	await _analogico(0.0, 0.0)
	_botao(JOY_BUTTON_DPAD_UP, true)
	_botao(JOY_BUTTON_DPAD_LEFT, true)
	await _quadros(3)
	_checar(ferramentas._mira_do_bumerangue().is_equal_approx(Vector2(-1, -1).normalized()),
		"direcional continua nas 8 direções")
	_checar(ferramentas._ler_direcao_input().is_equal_approx(Vector2(-1, -1).normalized()),
		"o dash segue nas 8 direções")
	_botao(JOY_BUTTON_DPAD_UP, false)
	_botao(JOY_BUTTON_DPAD_LEFT, false)
	await _quadros(3)

	# Arremesso de verdade, pelo □, com o analógico a 20° abaixo e à esquerda.
	await _analogico(160.0, 1.0)
	_botao(JOY_BUTTON_X, true)
	await _esperar(0.15)
	_checar(ferramentas._bumerangue_no_ar and is_instance_valid(ferramentas._bumerangue)
		and absf(rad_to_deg(ferramentas._bumerangue._direcao.angle()) - 160.0) < 0.5,
		"□ arremessa na direção do analógico")
	_botao(JOY_BUTTON_X, false)
	await _analogico(0.0, 0.0)

	Progresso._habilidades.erase("bumerangue")
	if is_instance_valid(ferramentas._bumerangue):
		ferramentas._bumerangue.queue_free()
	await _quadros(2)
	player.queue_free()
	await _quadros(3)


func _testar_andar_analogico() -> void:
	print("\n--- ANDAR NO ANALÓGICO ---")
	var player: CharacterBody2D = load(PLAYER).instantiate()
	add_child(player)
	player.global_position = Vector2(800, 400)
	# Sem chão na cena de teste ela cai, mas o andar (velocity.x) vale no ar do
	# mesmo jeito — só não pode "morrer" pela altura no meio do teste.
	player.limite_queda = 1.0e9
	var ferramentas := FerramentasPlayer.instalar(player)
	await _esperar(0.3)
	var cheia: float = player.speed

	await _andar_para(-45.0, 1.0)
	_checar(is_equal_approx(player.velocity.x, cheia),
		"diagonal para cima e à direita anda na velocidade normal (%.0f de %.0f)" % [player.velocity.x, cheia])
	await _andar_para(135.0, 1.0)
	_checar(is_equal_approx(player.velocity.x, -cheia),
		"diagonal para baixo e à esquerda também (%.0f)" % player.velocity.x)
	await _andar_para(-30.0, 0.35)
	_checar(is_equal_approx(player.velocity.x, cheia), "pouco empurrado já anda inteiro (%.0f)" % player.velocity.x)
	await _andar_para(-80.0, 1.0)
	_checar(is_zero_approx(player.velocity.x), "apontado para cima (10° da vertical) não anda")
	await _andar_para(0.0, 0.15)
	_checar(is_zero_approx(player.velocity.x), "analógico só tremendo no centro não anda")

	# Folga nas divisas da fatia vertical (22,5° ± 3°).
	await _andar_para(-60.0, 1.0)
	await _andar_para(-69.0, 1.0)
	_checar(is_equal_approx(player.velocity.x, cheia), "andando, entrar 1,5° na fatia vertical ainda anda (folga)")
	await _andar_para(-75.0, 1.0)
	_checar(is_zero_approx(player.velocity.x), "entrando de verdade na fatia vertical, para")
	await _andar_para(-66.0, 1.0)
	_checar(is_zero_approx(player.velocity.x), "parada, sair 1,5° da fatia ainda não anda (folga)")
	await _andar_para(-62.0, 1.0)
	_checar(is_equal_approx(player.velocity.x, cheia), "saindo de verdade da fatia, anda")

	await _analogico(0.0, 0.0)
	Input.action_press("ui_right")
	await _fisica(2)
	_checar(is_equal_approx(player.velocity.x, cheia), "teclado continua andando igual")
	Input.action_press("ui_down")
	_checar(Controle.aponta_para_baixo(), "S+D no teclado ainda é 'para baixo' (descer da plataforma)")
	Input.action_release("ui_right")
	Input.action_release("ui_down")
	await _fisica(2)

	print("\n--- DASH, DESCER, PORTA E NAVE NO ANALÓGICO ---")
	for caso in [[-30.0, Vector2(1, -1).normalized(), "30° acima da horizontal é a diagonal"],
			[-20.0, Vector2.RIGHT, "20° acima da horizontal é reto"],
			[-70.0, Vector2.UP, "70° é para cima"],
			[150.0, Vector2(-1, 1).normalized(), "150° é a diagonal de baixo à esquerda"]]:
		await _analogico(caso[0], 1.0)
		_checar(ferramentas._ler_direcao_input().is_equal_approx(caso[1]), "dash: %s" % caso[2])

	await _analogico(60.0, 1.0)
	_checar(Controle.aponta_para_baixo(), "30° da vertical para baixo desce da plataforma")
	await _analogico(20.0, 1.0)
	_checar(not Controle.aponta_para_baixo(), "correndo com o polegar um pouco para baixo não desce")
	await _analogico(-50.0, 1.0)
	_checar(Controle.aponta_para_cima(), "40° da vertical para cima entra na porta")
	await _analogico(-30.0, 1.0)
	_checar(not Controle.aponta_para_cima(), "andando na diagonal baixa não entra na porta")
	_checar(absf(rad_to_deg(Controle.vetor_direcional().normalized().angle()) + 30.0) < 0.5,
		"a nave do simulador vai nos 30° do polegar (antes ia reta)")

	await _analogico(0.0, 0.0)
	player.queue_free()
	await _quadros(3)


## Aponta o analógico e dá tempo de a física do player ler.
func _andar_para(graus: float, forca: float) -> void:
	await _analogico(graus, forca)
	await _fisica(2)


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Analógico esquerdo apontado para "graus" (0 = direita, positivo = para
## baixo, como no Godot), empurrado até "forca".
func _analogico(graus: float, forca: float) -> void:
	var vetor := Vector2.from_angle(deg_to_rad(graus)) * forca
	_eixo(JOY_AXIS_LEFT_X, vetor.x)
	_eixo(JOY_AXIS_LEFT_Y, vetor.y)
	await _quadros(3)


# ─────────────────────────────────────────────────────────────
# ENTRADA FABRICADA
# ─────────────────────────────────────────────────────────────

func _botao(botao: JoyButton, apertado: bool) -> void:
	var evento := InputEventJoypadButton.new()
	evento.device = 0
	evento.button_index = botao
	evento.pressed = apertado
	evento.pressure = 1.0 if apertado else 0.0
	Input.parse_input_event(evento)


func _tocar(botao: JoyButton) -> void:
	_botao(botao, true)
	await _quadros(3)
	_botao(botao, false)
	await _quadros(3)


func _eixo(eixo: JoyAxis, valor: float) -> void:
	var evento := InputEventJoypadMotion.new()
	evento.device = 0
	evento.axis = eixo
	evento.axis_value = valor
	Input.parse_input_event(evento)


func _tecla(codigo: Key) -> void:
	for apertada in [true, false]:
		var evento := InputEventKey.new()
		evento.keycode = codigo
		evento.physical_keycode = codigo
		evento.pressed = apertada
		Input.parse_input_event(evento)


func _mouse(relativo: Vector2, dispositivo: int) -> void:
	var evento := InputEventMouseMotion.new()
	evento.device = dispositivo
	evento.position = Vector2(10, 10)
	evento.global_position = evento.position
	evento.relative = relativo
	Input.parse_input_event(evento)


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Espera em tempo real (a árvore pode estar pausada pelo puzzle).
func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos, true, false, true).timeout
