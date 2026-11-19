extends Node

# Teste da cena do lançamento, no telhado da fase 2
# (scripts/fases/lancamento_no_telhado.gd):
#
#   godot --headless --path . res://tools/teste_lancamento.tscn
#
# Casos:
#   * AS FALAS: as duas timelines existem e são curtas (nenhuma fala passa de
#     MAXIMO_DA_FALA letras); a do "pra Lua" chama a comemoração;
#   * O GATILHO: antes dele, nada; andando para a direita e passando dele, a
#     cena começa — a Cacau para, o E fica com a cena, o HUD some e as faixas
#     de cinema entram;
#   * A CENA: o Dr. Chico chega e a primeira conversa roda; os dois vão para a
#     grade do fundo, a trilha da fase pausa e a câmera abre para o céu (o zoom
#     do céu, com o topo mais alto); o foguete sobe na camada do fundo, com luz
#     e tremor; na segunda conversa ela comemora (o coração aparece);
#   * O FIM: o controle, o HUD, a câmera (zoom e limite de cima), a trilha e o
#     E voltam; as faixas e o Dr. Chico vão embora; a Cacau continua na faixa e
#     anda;
#   * UMA VEZ SÓ: passando de novo pelo gatilho, ou reabrindo o telhado, nada
#     recomeça; com a amostra gelada na mão, a cena espera.

const TELHADO := MissaoNitrogenio.CENA_TELHADO
const LANCAMENTO := preload("res://scripts/fases/lancamento_no_telhado.gd")
const MAXIMO_DA_FALA := 70

var _falhas := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# O teste sai de cena: as trocas de cena de verdade não o apagam.
	get_tree().current_scene = null
	_rodar()


func _rodar() -> void:
	EstadoMundo.revelou_dr_chico = true
	MissaoNitrogenio.esquecer()
	# Chegar ao telhado pela primeira vez faz a Cacau comentar: aqui já subiu.
	MissaoNitrogenio.subiu_a_torre = true
	_testar_falas()
	await _testar_a_cena()
	await _testar_uma_vez_so()
	await _testar_com_a_amostra()
	Dialogic.Inputs.auto_skip.enabled = false
	MissaoNitrogenio.esquecer()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


# ─────────────────────────────────────────────────────────────

func _testar_falas() -> void:
	print("\n--- AS FALAS ---")
	var fala := RegEx.create_from_string("^(cacau|cientista)( \\([^)]*\\))?: (.*)$")
	var marcas := RegEx.create_from_string("\\[[^\\]]*\\]")
	for caminho in [LANCAMENTO.TIMELINE_CHEGADA, LANCAMENTO.TIMELINE_LUA]:
		var texto := FileAccess.get_file_as_string(caminho)
		_checar(not texto.is_empty() and load(caminho) != null, "%s existe" % caminho.get_file())
		var falas := 0
		var maior := ""
		for linha in texto.split("\n"):
			var achou := fala.search(linha.strip_edges())
			if achou == null:
				continue
			falas += 1
			var dito := marcas.sub(achou.get_string(3), "", true).strip_edges()
			if dito.length() > maior.length():
				maior = dito
		_checar(falas > 0 and maior.length() <= MAXIMO_DA_FALA,
			"   %d falas, todas curtas (a maior tem %d letras: \"%s\")" % [falas, maior.length(), maior])
	_checar(FileAccess.get_file_as_string(LANCAMENTO.TIMELINE_LUA).contains("do DialogicBridge.lancamento_comemorar()"),
		"a conversa do \"pra Lua\" chama a comemoração")
	_checar(FileAccess.get_file_as_string(LANCAMENTO.TIMELINE_LUA).contains("do DialogicBridge.lancamento_suspense()"),
		"   e o suspense antes do \"pra Lua\"")
	_checar(FileAccess.get_file_as_string(LANCAMENTO.TIMELINE_LUA).contains("do DialogicBridge.lancamento_virar_para_ele()"),
		"   e o pulinho virando para ele no \"EU?! PRA LUA?!\"")


func _testar_a_cena() -> void:
	print("\n--- O GATILHO ---")
	await _abrir(TELHADO)
	var telhado := get_tree().current_scene
	var player := _player()
	var camera := player.get_node("Camera2D") as Camera2D
	var zoom_antes := camera.zoom
	var topo_antes := camera.limit_top
	var hud_antes := FerramentasHUD.visible
	var gatilho: float = telhado.gatilho_do_lancamento
	await _conferir_a_antena(telhado)

	_pousar(player, Vector2(gatilho - 140.0, player.global_position.y))
	await _quadros(10)
	_checar(_cena() == null, "antes do gatilho, nada acontece")
	Input.action_press("ui_right")
	await _esperar(func() -> bool: return _cena() != null, 3.0)
	Input.action_release("ui_right")
	var cena := _cena()
	_checar(cena != null, "passando do gatilho (x %.0f), a cena começa" % gatilho)
	if cena == null:
		return
	# As conversas passam sozinhas.
	Dialogic.Inputs.auto_skip.enabled = true
	Dialogic.Inputs.auto_skip.time_per_event = 0.05
	await _quadros(3)
	_checar(MissaoNitrogenio.viu_o_lancamento, "   e fica marcada como vista")
	_checar(not player.pode_se_mover and player.velocity == Vector2.ZERO, "   a Cacau para")
	_checar(Interacao.ocupada(), "   o E fica com a cena")
	_checar(not FerramentasHUD.visible, "   o HUD some")
	_checar(telhado.get_node_or_null("FaixasDeCinema") != null, "   as faixas de cinema entram")

	print("\n--- A CENA ---")
	await _esperar(func() -> bool: return _timeline_tem("lancamento_chegada"), 10.0)
	var chico := telhado.get_node_or_null("DrChicoNoTelhado") as Node2D
	_checar(_timeline_tem("lancamento_chegada"), "a primeira conversa começa")
	_checar(chico != null and chico.visible and absf(chico.global_position.x - player.global_position.x) < 80.0,
		"   com o Dr. Chico ao lado dela")
	if chico:
		_checar(chico.get_index() < player.get_index() and chico.z_index == player.z_index,
			"   desenhado atrás dela")
		var respiro := chico.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		_checar(respiro != null and respiro.animation == &"default" and respiro.speed_scale > 1.5
				and respiro.scale.is_equal_approx(Vector2.ONE * respiro.scale.x),
			"   ofegante: o parado dele acelerado (velocidade %.1f), sem balançar o corpo"
				% (respiro.speed_scale if respiro else 0.0))
	await _esperar(func() -> bool: return telhado.get_node_or_null("BG/FogueteAoLonge") != null, 20.0)
	var foguete := telhado.get_node_or_null("BG/FogueteAoLonge")
	_checar(foguete != null, "o foguete aparece na camada do fundo")
	_checar(TrilhaSonora.esta_pausada(), "   a trilha da fase silencia")
	_checar(absf(player.global_position.x - float(telhado.beirada_do_lancamento)) < 2.0
			and player.altura_dos_pes() < (telhado.get_node("FaixaDoChao") as Control).get_global_rect().position.y + 8.0,
		"   a Cacau está na grade do fundo (x %.0f, pés %.0f)" % [player.global_position.x, player.altura_dos_pes()])
	_checar(chico != null and chico.global_position.x < player.global_position.x,
		"   com ele à esquerda dela")
	_checar(is_equal_approx(camera.zoom.x, telhado.zoom_do_ceu) and camera.limit_top < topo_antes,
		"   a câmera abriu para o céu (zoom %.2f, topo %d -> %d)" % [camera.zoom.x, topo_antes, camera.limit_top])

	var subiu := 0.0
	var tremeu := false
	var iluminou := false
	var t := 0.0
	while t < 30.0 and not _timeline_tem("lancamento_lua"):
		await get_tree().process_frame
		t += get_process_delta_time()
		if is_instance_valid(foguete):
			subiu = maxf(subiu, foguete.andamento())
		tremeu = tremeu or camera.shake_amount > 0.0
		var luz := telhado.get_node_or_null("LuzDoLancamento")
		iluminou = iluminou or (luz != null and luz.energia > 0.2)
	_checar(subiu >= 1.0, "o foguete sobe até o fim do caminho")
	_checar(iluminou, "   o lançamento ilumina o telhado")
	_checar(tremeu, "   e o telhado treme")
	_checar(_timeline_tem("lancamento_lua"), "a conversa do \"pra Lua\" começa depois")

	var coracao := player.get_node_or_null("CoracaoFoguete") as CanvasItem
	var comemorou := false
	var zoom_maximo := 0.0
	var susto := false
	t = 0.0
	while t < 40.0 and not (player.pode_se_mover and not player.animacao_controlada_externamente):
		await get_tree().process_frame
		t += get_process_delta_time()
		comemorou = comemorou or (coracao != null and coracao.visible)
		zoom_maximo = maxf(zoom_maximo, camera.zoom.x)
		susto = susto or player.get_node_or_null("SustoDoLancamento") != null
	_checar(susto, "   no \"EU?! PRA LUA?!\" ela solta o balão \"?!\"")
	_checar(zoom_maximo > LANCAMENTO.ZOOM_DO_SUSPENSE - 0.05,
		"   no suspense a câmera chega nos dois (zoom até %.2f)" % zoom_maximo)
	_checar(comemorou, "   e ela comemora (o coração aparece)")

	print("\n--- O FIM ---")
	_checar(player.pode_se_mover and not player.animacao_controlada_externamente, "o controle volta")
	_checar(not Interacao.ocupada(), "   o E também")
	_checar(FerramentasHUD.visible == hud_antes, "   o HUD volta")
	_checar(not TrilhaSonora.esta_pausada(), "   a trilha da fase volta")
	await _segundos(2.0)
	_checar(camera.zoom.is_equal_approx(zoom_antes) and camera.limit_top == topo_antes
			and not camera.top_level,
		"   a câmera volta (zoom %.2f, topo %d)" % [camera.zoom.x, camera.limit_top])
	_checar(telhado.get_node_or_null("FaixasDeCinema") == null, "   as faixas saem")
	var faixa: Rect2 = (telhado.get_node("FaixaDoChao") as Control).get_global_rect()
	var pes: float = player.altura_dos_pes()
	_checar(player.esta_na_faixa() and pes >= faixa.position.y - 1.0 and pes <= faixa.end.y + 1.0,
		"   ela continua na faixa (pés %.0f)" % pes)
	await _esperar(func() -> bool: return _cena() == null, 10.0)
	_checar(telhado.get_node_or_null("DrChicoNoTelhado") == null and not is_instance_valid(cena),
		"   o Dr. Chico desce a escada e a cena vai embora")
	_checar(telhado.get_node_or_null("LuzDoLancamento") == null
			and player.get_node_or_null("ExclamacaoDoLancamento") == null,
		"   sem sobras: a luz do lançamento e o \"!\" dela também vão embora")
	var x0 := player.global_position.x
	await _segundos(0.6)
	_checar(absf(player.global_position.x - x0) < 0.5 and player.velocity.x == 0.0,
		"   sem ninguém apertando nada, ela fica parada (%.1f -> %.1f)" % [x0, player.global_position.x])
	var y0 := pes
	await _segurar("ui_right", 0.3)
	_checar(player.global_position.x > x0 + 20.0, "   ela anda (%.0f -> %.0f)" % [x0, player.global_position.x])
	await _segurar("ui_down", 0.3)
	_checar(player.altura_dos_pes() > y0 + 2.0, "   e vai para a frente da faixa (%.0f -> %.0f)" % [y0, player.altura_dos_pes()])


func _testar_uma_vez_so() -> void:
	print("\n--- UMA VEZ SÓ ---")
	var telhado := get_tree().current_scene
	var player := _player()
	var gatilho: float = telhado.gatilho_do_lancamento
	_pousar(player, Vector2(gatilho - 100.0, player.global_position.y))
	await _quadros(4)
	await _segurar("ui_right", 0.8)
	_checar(player.global_position.x > gatilho and _cena() == null,
		"passando de novo pelo gatilho, nada recomeça")
	await _abrir(TELHADO)
	player = _player()
	_pousar(player, Vector2(gatilho + 20.0, player.global_position.y))
	await _quadros(20)
	_checar(_cena() == null, "nem reabrindo o telhado")


func _testar_com_a_amostra() -> void:
	print("\n--- COM A AMOSTRA ---")
	MissaoNitrogenio.viu_o_lancamento = false
	MissaoNitrogenio.amostra = GasFechado.new(1.0, 3.0, 84.0)
	await _abrir(TELHADO)
	var telhado := get_tree().current_scene
	var player := _player()
	_pousar(player, Vector2(telhado.gatilho_do_lancamento + 20.0, player.global_position.y))
	await _quadros(20)
	_checar(_cena() == null and not MissaoNitrogenio.viu_o_lancamento,
		"com a amostra gelada na mão, a cena espera")
	MissaoNitrogenio.amostra = null
	await _quadros(5)
	_checar(_cena() != null, "   e começa assim que ela não está mais com a amostra")
	await _encerrar_a_cena()


# ─────────────────────────────────────────────────────────────

## A antena do teto da casinha da escada: existe e a luz pisca (acende e apaga).
func _conferir_a_antena(telhado: Node) -> void:
	var antena := telhado.get_node_or_null("AntenaDeAviso") as Node2D
	_checar(antena != null and antena.visible, "a antena de aviso está no teto da casinha da escada")
	if antena == null:
		return
	var menor := 1.0
	var maior := 0.0
	var t := 0.0
	while t < 2.0 * antena.periodo:
		await get_tree().process_frame
		t += get_process_delta_time()
		menor = minf(menor, antena._nivel)
		maior = maxf(maior, antena._nivel)
	_checar(maior > 0.95 and menor < 0.05, "   e a luz vermelha pisca (%.2f a %.2f)" % [menor, maior])


func _cena() -> Node:
	return get_tree().get_first_node_in_group(LANCAMENTO.GRUPO)


func _timeline_tem(nome: String) -> bool:
	return Dialogic.current_timeline != null and Dialogic.current_timeline.resource_path.contains(nome)


## Termina a cena do jeito que a pausa faria (voltando ao menu): trocando de
## cena. O que é de fora dela precisa voltar.
func _encerrar_a_cena() -> void:
	await _quadros(30)
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()
	await _abrir(MissaoNitrogenio.CENA_RUA)
	_checar(FerramentasHUD.visible and not TrilhaSonora.esta_pausada() and not Interacao.ocupada(),
		"   saindo da fase no meio da cena, o HUD, a trilha e o E voltam")


func _pousar(player: CharacterBody2D, onde: Vector2) -> void:
	player.global_position = onde
	player.velocity = Vector2.ZERO


func _segurar(acao: String, segundos: float) -> void:
	Input.action_press(acao)
	await _segundos(segundos)
	Input.action_release(acao)
	await get_tree().physics_frame
	await get_tree().physics_frame


func _esperar(condicao: Callable, limite: float) -> void:
	var t := 0.0
	while t < limite and not condicao.call():
		await get_tree().process_frame
		t += get_process_delta_time()


func _abrir(caminho: String) -> void:
	get_tree().change_scene_to_file(caminho)
	for i in 600:
		await get_tree().process_frame
		var cena := get_tree().current_scene
		if cena and cena.scene_file_path == caminho and cena.is_node_ready():
			break
	await _quadros(3)


func _player() -> CharacterBody2D:
	return get_tree().current_scene.get_node("Player") as CharacterBody2D


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _segundos(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1
