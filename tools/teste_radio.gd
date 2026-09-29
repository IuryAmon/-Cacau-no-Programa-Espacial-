extends Node

# Teste do rádio do Dr. Chico (scripts/fases/radio_comunicacao.gd) na fase 1
# de verdade, com o Dialogic de verdade:
#
#   * o rádio mora na parede da entrada, parado no quadro 1, atrás da Cacau;
#   * a Cacau entra na fase e, com ela livre, o rádio CHAMA: pisca o LED, treme,
#     solta ondas e toca os bipes — e ela ainda pode andar;
#   * o canal abre: a timeline radio_fase1 com o retrato "cientistaradio" e o
#     "Testando 1 2 3"; a Cacau para e se vira para o rádio;
#   * enquanto a fala é escrita o alto-falante trabalha (quadros 1→3, LED,
#     ondas); escrita a frase, ele volta ao quadro 1;
#   * acabou a conversa: rádio parado, Cacau livre, e ele não chama de novo
#     nem recarregando a fase.
#
#   godot --headless --path . res://tools/teste_radio.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva imagens da chamada e
# da fala, para conferir o efeito a olho.

const FASE := "res://scenes/fases/fase1_oficina.tscn"

var _falhas := 0
var _pasta_capturas := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			_pasta_capturas = arg.trim_prefix("--capturas=")
	await get_tree().process_frame

	await _testar_transmissao()
	await _testar_nao_repete()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


# ─────────────────────────────────────────────────────────────

func _testar_transmissao() -> void:
	print("\n--- A PRIMEIRA ENTRADA NA FASE ---")
	var fase := await _abrir()
	var radio := fase.get_node_or_null("Entrada/RadioDrChico") as RadioComunicacao
	_checar(radio != null, "o rádio mora na entrada da fase 1")
	if radio == null:
		return
	var player := fase.get_node("Player") as CharacterBody2D
	var sprite_radio := radio.get_node("Sprite") as Sprite2D
	var luz := radio.get_node("Luz") as PointLight2D
	var porta := fase.get_node("Entrada/PortaHub") as Node2D

	_checar(str(Dialogic.VAR.get_variable("reveal_name")) == "Dr. Chico",
		"na fase o cientista já se chama Dr. Chico")
	_checar(sprite_radio.hframes == 3 and sprite_radio.frame == 0, "parado, no quadro 1 dos 3")
	_checar(radio.z_index < player.z_index, "desenha atrás da Cacau")
	_checar(absf(radio.global_position.x - porta.global_position.x) < 400.0,
		"pendurado perto da porta de chegada (x = %.0f)" % radio.global_position.x)

	# --- chamando ---
	_checar(await _esperar(func() -> bool: return radio.estado == RadioComunicacao.Estado.CHAMANDO, 3.0),
		"com a Cacau livre na fase, o rádio começa a chamar")
	var quadros := {}
	var tremeu := false
	var bipou := false
	var bipes := 0
	var tocando := false
	var ondas := 0
	var base := sprite_radio.position
	var t := 0.0
	while radio.estado == RadioComunicacao.Estado.CHAMANDO and t < 3.0:
		quadros[sprite_radio.frame] = true
		tremeu = tremeu or sprite_radio.position != base
		var agora := (radio.get_node("SomChamada") as AudioStreamPlayer2D).playing
		bipou = bipou or agora
		if agora and not tocando:
			bipes += 1
		tocando = agora
		ondas = maxi(ondas, radio.ondas_no_ar())
		if t > 0.2 and t < 0.25:
			await _capturar("1_chamando")
		await get_tree().process_frame
		t += get_process_delta_time()
	_checar(quadros.has(0) and quadros.has(2), "chamando, o LED pisca (quadros vistos: %s)" % [quadros.keys()])
	_checar(tremeu, "e o rádio treme")
	_checar(ondas > 0, "e solta ondas de sinal (%d no ar)" % ondas)
	_checar(bipou and bipes == 1, "e toca um bip-bip só antes de abrir (%d)" % bipes)

	# --- no ar ---
	_checar(await _esperar(func() -> bool: return Dialogic.current_timeline != null, 2.0),
		"depois de chamar, a conversa abre")
	_checar(radio.estado == RadioComunicacao.Estado.NO_AR, "e o rádio fica no ar")
	_checar(not player.pode_se_mover, "a Cacau para para ouvir")
	var sprite_cacau := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_checar(sprite_cacau.flip_h == (radio.global_position.x < player.global_position.x), "virada para o rádio")
	# O primeiro evento é o "join" do retrato; a fala vem logo depois.
	await _esperar(func() -> bool: return _fala_atual() != null, 2.0)
	var fala := _fala_atual()
	_checar(fala != null and fala.text.contains("Testando 1 2 3"), "o Dr. Chico diz \"Testando 1 2 3\"")
	_checar(fala != null and fala.portrait == "cientistaradio", "com o retrato cientistaradio")

	quadros.clear()
	var falou := false
	ondas = 0
	var luz_acesa := false
	var capturou := false
	var tempo_falando := 0.0
	t = 0.0
	while t < 4.0:
		if radio.falando:
			falou = true
			tempo_falando += get_process_delta_time()
			quadros[sprite_radio.frame] = true
			ondas = maxi(ondas, radio.ondas_no_ar())
			luz_acesa = luz_acesa or luz.enabled
			if tempo_falando > 0.7 and not capturou:
				capturou = true
				await _capturar("2_falando")
		elif falou:
			break
		await get_tree().process_frame
		t += get_process_delta_time()
	_checar(falou, "enquanto a fala é escrita, o rádio fala")
	_checar(quadros.size() == 3, "rodando os quadros 1, 2 e 3 (vistos: %s)" % [quadros.keys()])
	_checar(ondas > 0 and luz_acesa, "com ondas e o LED aceso")
	await _esperar_segundos(0.4)
	_checar(sprite_radio.frame == 0 and not luz.enabled, "frase escrita: volta ao quadro 1, escutando")
	_checar(Dialogic.current_timeline != null, "e o canal continua aberto esperando o botão")

	# A câmera foi até o rádio: ele fica à esquerda do retrato (que ocupa o
	# terço da direita) e acima da caixa de texto (que começa a 76% da altura;
	# mais para cima o limite de baixo da fase não deixa a câmera descer).
	var camera := player.get_node("Camera2D") as CameraJogador
	_checar(is_equal_approx(camera.zoom.x, radio.zoom_na_transmissao), "a câmera aproximou (zoom %.2f)" % camera.zoom.x)
	var na_tela := radio.get_global_transform_with_canvas().origin / get_viewport().get_visible_rect().size
	_checar(na_tela.x > 0.1 and na_tela.x < 0.58 and na_tela.y > 0.1 and na_tela.y < 0.76,
		"e enquadrou o rádio fora do retrato e acima da caixa (%.2f, %.2f da tela)" % [na_tela.x, na_tela.y])

	# --- desliga ---
	var terminou := [false]
	radio.transmissao_terminou.connect(func() -> void: terminou[0] = true)
	var espera := 0.0
	while Dialogic.current_timeline != null and espera < 4.0:
		Dialogic.Inputs.handle_input()
		await _esperar_segundos(0.2)
		espera += 0.2
	await get_tree().process_frame
	_checar(Dialogic.current_timeline == null, "o botão fecha a conversa")
	_checar(terminou[0] and radio.estado == RadioComunicacao.Estado.PARADO, "o rádio desliga")
	_checar(sprite_radio.frame == 0 and not luz.enabled, "e volta ao quadro 1")
	_checar(player.pode_se_mover, "a Cacau volta a andar")
	await _esperar_segundos(0.8)
	_checar(camera.zoom.is_equal_approx(camera.zoom_padrao) and camera.position.is_equal_approx(camera.posicao_padrao),
		"a câmera volta ao normal")
	_checar(EstadoMundo.ja_feito(radio), "a conversa fica anotada")
	await _fechar(fase)


func _testar_nao_repete() -> void:
	print("\n--- VOLTANDO À FASE ---")
	var fase := await _abrir()
	var radio := fase.get_node("Entrada/RadioDrChico") as RadioComunicacao
	await _esperar_segundos(3.0)
	_checar(radio.estado == RadioComunicacao.Estado.PARADO and Dialogic.current_timeline == null,
		"o rádio não chama de novo")
	await _fechar(fase)


# ─────────────────────────────────────────────────────────────

func _fala_atual() -> DialogicTextEvent:
	if Dialogic.current_timeline == null or Dialogic.current_event_idx < 0 \
			or Dialogic.current_event_idx >= Dialogic.current_timeline_events.size():
		return null
	return Dialogic.current_timeline_events[Dialogic.current_event_idx] as DialogicTextEvent


func _esperar(condicao: Callable, limite: float) -> bool:
	var t := 0.0
	while not condicao.call() and t < limite:
		await get_tree().process_frame
		t += get_process_delta_time()
	return condicao.call()


func _abrir() -> Node:
	var fase: Node = (load(FASE) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(fase)
	await get_tree().process_frame
	await get_tree().process_frame
	return fase


func _fechar(fase: Node) -> void:
	fase.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _esperar_segundos(segundos: float) -> void:
	await get_tree().create_timer(segundos, true).timeout


func _capturar(nome: String) -> void:
	if _pasta_capturas.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_pasta_capturas.path_join(nome + ".png"))
