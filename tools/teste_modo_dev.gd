extends Node

# Teste do modo de desenvolvedor (scripts/modo_dev.gd):
#
#   godot --headless --path . res://tools/teste_modo_dev.tscn
#
# Casos:
#   * LIGAR: F1 dá todas as ferramentas e já sai voando;
#   * O VOO: sem gravidade, anda nas 4 direções, atravessa parede, a câmera
#     solta dos limites; pousar devolve a colisão, a gravidade e o zoom;
#   * NADA MACHUCA: dano não entra; cair no buraco volta a voar;
#   * AS TRAVAS: porta de fase sem a ferramenta, saída barrada e porta da torre
#     com a amostra (que não esquenta), elevador parado;
#   * AS PORTAS VOANDO: o W não entra (é subir), o E entra;
#   * O MENU DE CENAS: pausa, despausa e leva à cena escolhida;
#   * DESLIGAR: tudo volta, as ferramentas ficam.

const RUA := MissaoNitrogenio.CENA_RUA
const DESTILACAO := MissaoNitrogenio.CENA_DESTILACAO

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
	await _testar_ligar()
	await _testar_voo()
	await _testar_dano()
	await _testar_travas()
	await _testar_portas_voando()
	await _testar_menu()
	await _testar_desligar()
	MissaoNitrogenio.esquecer()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


# ─────────────────────────────────────────────────────────────

func _testar_ligar() -> void:
	print("\n--- LIGAR ---")
	_checar(not ModoDev.ativo and not ModoDev.voando, "começa desligado")
	ModoDev.voar(true)
	_checar(not ModoDev.voando, "com o modo desligado, o V não faz voar")
	await _abrir(RUA)
	ModoDev.alternar()
	_checar(ModoDev.ativo and ModoDev.voando, "F1 liga o modo e já sai voando")
	var todas := true
	for habilidade in Progresso.HABILIDADES:
		todas = todas and Progresso.tem_habilidade(habilidade)
	_checar(todas, "e dá todas as ferramentas")


func _testar_voo() -> void:
	print("\n--- O VOO ---")
	var player := _player()
	_pousar(player, Vector2(800, 300))
	await _fisica(3)
	_checar(player.collision_mask == 0, "voando, ela não colide com o mundo")
	var camera := player.get_node("Camera2D") as Camera2D
	_checar(camera.limit_top < -100000 and camera.limit_right > 100000, "a câmera solta dos limites da cena")

	var antes := player.global_position
	await _segundos(0.4)
	_checar(player.global_position.distance_to(antes) < 1.0, "parada no ar, ela não cai")

	antes = player.global_position
	await _segurar("ui_right", 0.4)
	_checar(player.global_position.x > antes.x + 150.0, "→ voa para a direita (%.0f px)" % (player.global_position.x - antes.x))
	antes = player.global_position
	await _segurar("ui_up", 0.4)
	_checar(player.global_position.y < antes.y - 150.0, "↑ voa para cima (%.0f px)" % (antes.y - player.global_position.y))
	antes = player.global_position
	await _segurar("ui_down", 0.4)
	_checar(player.global_position.y > antes.y + 150.0, "↓ voa para baixo")
	antes = player.global_position
	Input.action_press("dash")
	await _segurar("ui_left", 0.4)
	Input.action_release("dash")
	_checar(player.global_position.x < antes.x - 500.0, "← com Shift voa bem mais rápido (%.0f px)" % (antes.x - player.global_position.x))

	# A parede direita da rua (x = 5524) e o chão (topo em y = 512).
	_pousar(player, Vector2(5400, 470))
	await _fisica(2)
	await _segurar("ui_right", 0.5)
	_checar(player.global_position.x > 5560.0, "atravessa a parede da ponta da rua")
	_pousar(player, Vector2(800, 470))
	await _fisica(2)
	await _segurar("ui_down", 0.3)
	_checar(player.global_position.y > 560.0, "e atravessa o chão")

	camera.zoom = Vector2(0.4, 0.4)
	_pousar(player, Vector2(800, 300))
	ModoDev.voar(false)
	_checar(not ModoDev.voando and ModoDev.ativo, "V pousa sem desligar o modo")
	await _fisica(3)
	_checar(player.collision_mask != 0, "pousando, a colisão volta")
	_checar(camera.zoom == (camera as CameraJogador).zoom_padrao, "o zoom volta ao da fase")
	_checar(camera.limit_right == 5504, "e a câmera volta aos limites da cena")
	await _segundos(1.0)
	_checar(player.is_on_floor(), "e ela cai e pisa no chão")


func _testar_dano() -> void:
	print("\n--- NADA MACHUCA ---")
	var player := _player()
	var vida: int = player.current_health
	player.take_damage(1, Vector2.LEFT)
	await _fisica(2)
	_checar(player.current_health == vida, "dano não entra")
	_pousar(player, Vector2(800, 1200))
	await _fisica(3)
	_checar(ModoDev.voando and player.current_health > 0, "cair no buraco volta a voar em vez de morrer")


func _testar_travas() -> void:
	print("\n--- AS TRAVAS ---")
	var porta: PortaFase = (load(PortaFase.CENA) as PackedScene).instantiate()
	porta.requer_habilidade = "habilidade_que_nao_existe"
	porta.requer_todas_celulas = true
	porta.cena_destino = RUA
	_checar(porta._pode_entrar(), "porta de fase trancada abre")
	ModoDev.ativo = false
	_checar(not porta._pode_entrar(), "   (com o modo desligado, continua trancada)")
	ModoDev.ativo = true
	porta.free()

	var rua := get_tree().current_scene
	var player := _player()
	MissaoNitrogenio.amostra = GasFechado.new(1.0, 3.0, 80.0)
	MissaoNitrogenio.instalar_na_fase(rua)
	await _quadros(3)
	var passagem := rua.get_node("PassagemCorredor") as PassagemDeCena
	_checar(rua.segura_a_saida() and passagem._quem_segura() == null,
		"com a amostra na mão, a saída para o corredor não barra")
	_checar(rua.get_node("PortaTorre").interativa, "   a porta da torre abre")
	var pressao: float = MissaoNitrogenio.amostra.pressao()
	await _segundos(1.0)
	_checar(is_equal_approx(MissaoNitrogenio.amostra.pressao(), pressao), "   e a amostra não esquenta")
	MissaoNitrogenio.amostra = null
	await _quadros(3)

	# A cabine do elevador da rua começa lá em cima, no telhado.
	var elevador := rua.get_node("ElevadorDeCarga") as ElevadorFase
	_checar(not elevador.cabine_aqui, "a cabine do elevador de carga está lá no telhado (poço vazio)")
	ModoDev.voar(false)
	_pousar(player, Vector2(elevador.global_position.x, 470))
	await _segundos(0.6)
	elevador._partir()
	await _esperar(func() -> bool: return get_tree().current_scene != null \
		and get_tree().current_scene.scene_file_path == MissaoNitrogenio.CENA_TELHADO, 12.0)
	_checar(get_tree().current_scene.scene_file_path == MissaoNitrogenio.CENA_TELHADO,
		"   e mesmo assim leva ao telhado")
	await _encerrar_fala()


func _testar_portas_voando() -> void:
	print("\n--- AS PORTAS VOANDO ---")
	await _abrir(DESTILACAO)
	await _segundos(1.0)
	await _encerrar_fala()
	ModoDev.voar(true)
	var sala := get_tree().current_scene
	var porta := sala.get_node("PortaRua")
	var player := _player()
	_pousar(player, porta.global_position)
	await _fisica(3)
	await _toque("ui_up")
	await _quadros(5)
	_checar(not porta._ocupada and get_tree().current_scene == sala, "voando, o W na porta não entra (é subir)")
	await _toque("interact")
	await _esperar(func() -> bool: return get_tree().current_scene != null \
		and get_tree().current_scene.scene_file_path == RUA, 10.0)
	_checar(get_tree().current_scene.scene_file_path == RUA, "o E entra, e ela sai na rua")
	# A porta da rua ainda a leva para fora antes de devolver o controle.
	await _esperar(func() -> bool: return not _player().animacao_controlada_externamente, 6.0)
	await _fisica(2)
	_checar(ModoDev.voando and _player().collision_mask == 0, "   ainda voando")


func _testar_menu() -> void:
	print("\n--- O MENU DE CENAS ---")
	ModoDev.abrir_menu()
	_checar(get_tree().paused and ModoDev._menu.visible, "F2 abre o menu e pausa o jogo")
	ModoDev.fechar_menu()
	_checar(not get_tree().paused and not ModoDev._menu.visible, "fechar despausa")
	ModoDev.abrir_menu()
	ModoDev._ir_para(DESTILACAO)
	_checar(not get_tree().paused, "escolher uma cena despausa")
	await _esperar(func() -> bool: return get_tree().current_scene != null \
		and get_tree().current_scene.scene_file_path == DESTILACAO, 10.0)
	_checar(get_tree().current_scene.scene_file_path == DESTILACAO, "e leva até ela")
	await _segundos(0.8)
	await _encerrar_fala()
	var spawn := get_tree().current_scene.get_node("SpawnPadrao") as Marker2D
	_checar(_player().global_position.distance_to(spawn.global_position) < 4.0, "   no ponto de nascimento")


func _testar_desligar() -> void:
	print("\n--- DESLIGAR ---")
	var player := _player()
	ModoDev.alternar()
	_checar(not ModoDev.ativo and not ModoDev.voando, "F1 de novo desliga o modo e o voo")
	await _fisica(3)
	_checar(player.collision_mask != 0, "a colisão volta")
	var todas := true
	for habilidade in Progresso.HABILIDADES:
		todas = todas and Progresso.tem_habilidade(habilidade)
	_checar(todas, "as ferramentas ficam")
	var vida: int = player.current_health
	player.esta_invencivel = false
	player.take_damage(1, Vector2.LEFT)
	_checar(player.current_health == vida - 1, "e o dano volta a entrar")


# ─────────────────────────────────────────────────────────────

func _pousar(player: CharacterBody2D, onde: Vector2) -> void:
	player.global_position = onde
	player.velocity = Vector2.ZERO


func _segurar(acao: String, s: float) -> void:
	Input.action_press(acao)
	await _segundos(s)
	Input.action_release(acao)
	await _fisica(1)


func _toque(acao: String) -> void:
	Input.action_press(acao)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(acao)


func _encerrar_fala() -> void:
	for i in 3:
		if Dialogic.current_timeline != null:
			Dialogic.end_timeline()
		await _quadros(5)
	get_tree().paused = false


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


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _segundos(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1
