extends SceneTree

# Teste do sistema de retorno (PontoDeRetorno + bandeira Checkpoint +
# SalaDeRetorno) e do encaixe da câmera, rodando na Oficina do Carbono de
# verdade, com mortes de verdade (o mesmo _reiniciar_cena_seguro() do player).
#
#   godot --headless --fixed-fps 60 --path . -s res://tools/teste_ponto_de_retorno.gd
#
# Casos:
#   * visita nova não tem ponto de retorno;
#   * bandeira: morrer volta nela, e ela nasce tremulando;
#   * sala com marcador: entrar grava; morrer volta no marcador mais perto;
#     a bandeira continua tremulando, mas o ponto é da sala (o último vence);
#   * tocar de novo na bandeira retoma o ponto;
#   * renascer DENTRO de uma sala não troca o ponto pela entrada dela;
#   * sala sem marcador: grava o primeiro chão seguro pisado;
#   * sair da fase e voltar esquece o ponto;
#   * a câmera renasce já enquadrada (não desliza nos quadros seguintes);
#   * chegar pela porta do laboratório não faz a câmera deslizar;
#   * morrer logo depois de entrar pela porta renasce saindo pela porta de novo.

const FASE := "res://scenes/fases/fase1_oficina.tscn"
const HUB := "res://scenes/laboratório_(world_2).tscn"

var _falhas := 0


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	await _abrir(FASE)
	var player := _player()
	var inicio := player.global_position
	_checar(not PontoDeRetorno.aplicar(player), "visita nova não tem ponto de retorno")

	# --- BANDEIRA ---
	var bandeira := current_scene.get_node("Checkpoint") as Checkpoint
	bandeira.ativar()
	var pos_bandeira := bandeira.global_position + Vector2(0, -bandeira.altura_do_respawn)
	await _morrer()
	player = _player()
	_perto(player.global_position, pos_bandeira, "morrer volta na bandeira")
	bandeira = current_scene.get_node("Checkpoint") as Checkpoint
	_checar(bandeira.ativada, "bandeira ativa nasce tremulando depois da morte")
	await _checar_camera_parada(player, "câmera renasce enquadrada na bandeira")

	# --- SALA COM MARCADORES ---
	var sala := _criar_sala(Rect2(0, 200, 560, 400), [Vector2(120, 476), Vector2(420, 476)])
	await _quadros_fisica(2)
	player.global_position = Vector2(540, 300)  # entra pelo lado direito
	await _quadros_fisica(3)
	_checar(PontoDeRetorno.eh_origem_atual(sala), "entrar na sala grava o ponto nela")
	await _morrer()
	player = _player()
	_perto(player.global_position, Vector2(420, 476), "morrer volta no marcador mais perto da entrada")
	bandeira = current_scene.get_node("Checkpoint") as Checkpoint
	_checar(bandeira.ativada, "bandeira segue tremulando depois de uma sala gravar")
	_checar(not PontoDeRetorno.eh_origem_atual(bandeira), "o ponto é da sala, não da bandeira (último vence)")

	# Renasceu dentro da sala: a sala recriada não pode regravar a entrada.
	sala = _criar_sala(Rect2(0, 200, 560, 400), [Vector2(120, 476)])
	await _quadros_fisica(5)
	_checar(not PontoDeRetorno.eh_origem_atual(sala), "renascer dentro da sala não conta como entrar")

	# --- VOLTAR NA BANDEIRA ---
	bandeira._on_body_entered(player)
	_checar(PontoDeRetorno.eh_origem_atual(bandeira), "tocar de novo na bandeira retoma o ponto")
	await _morrer()
	_perto(_player().global_position, pos_bandeira, "e morrer volta nela")

	# --- SALA SEM MARCADOR: primeiro chão seguro ---
	player = _player()
	var spawn := (current_scene.get_node("SpawnPadrao") as Marker2D).global_position
	var sala_chao := _criar_sala(Rect2(spawn.x - 150, spawn.y - 300, 300, 400), [])
	await _quadros_fisica(2)
	player.global_position = spawn + Vector2(0, -60)
	player.velocity = Vector2.ZERO
	await _quadros_fisica(90)
	_checar(PontoDeRetorno.eh_origem_atual(sala_chao), "sala sem marcador grava ao pisar em chão seguro")
	var no_chao := player.global_position
	await _morrer()
	_perto(_player().global_position, no_chao, "morrer volta no chão seguro pisado", 4.0)

	# --- SAIR DA FASE ESQUECE ---
	await _abrir(HUB)
	await _abrir(FASE)
	player = _player()
	_checar(not PontoDeRetorno.aplicar(player), "sair e voltar à fase esquece o ponto")
	_perto(player.global_position, inicio, "visita nova começa do início", 40.0)  # pode estar caindo

	# --- CHEGADA PELA PORTA DO LABORATÓRIO ---
	var porta_script: GDScript = load("res://scripts/porta_simulador.gd")
	porta_script.chegando_por_porta = true
	porta_script.tag_chegada = "entrada_oficina"
	FadeTela.chegada_escura = true
	await _abrir(FASE)
	await create_timer(0.3).timeout  # passa do encaixe no vão
	await _checar_camera_parada(_player(), "chegando pela porta a câmera não desliza")

	# Morrer antes de qualquer bandeira/sala: renasce na porta e sai por ela de
	# novo, e não no lugar em que o player está salvo na cena.
	await create_timer(3.0).timeout  # termina a primeira saída
	await _morrer()
	player = _player()
	var porta_hub := current_scene.get_node("Entrada/PortaHub")
	var entrada: Vector2 = (porta_hub.get_node("PontoDeSaida") as Marker2D).global_position \
		+ Vector2(porta_hub.direcao_saida * maxf(porta_hub.distancia_saida, 0.0), 0.0)
	var camera := player.get_node("Camera2D") as Camera2D
	_perto(camera.get_screen_center_position(), Vector2(575, 290),
		"câmera renasce enquadrada na porta", 2.0)
	_checar(not player.pode_se_mover, "renascer na porta começa sem controle")
	await create_timer(0.6).timeout
	var sprite_porta := porta_hub.get_node("SpritePorta") as AnimatedSprite2D
	_checar(sprite_porta.animation != &"fechada",
		"a porta abre de novo ao renascer (animação: %s)" % sprite_porta.animation)
	await create_timer(3.0).timeout
	_checar(player.visible and player.pode_se_mover, "depois da animação ela aparece e anda")
	_perto(player.global_position, entrada, "e termina na frente da porta", 6.0)  # a física tira do chão

	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


# --- AUXILIARES ---

func _abrir(caminho: String) -> void:
	change_scene_to_file(caminho)
	await _quadros(3)


func _morrer() -> void:
	_player()._reiniciar_cena_seguro()
	await _quadros(3)


func _player() -> CharacterBody2D:
	return current_scene.get_node("Player") as CharacterBody2D


func _criar_sala(area: Rect2, marcadores: Array) -> SalaDeRetorno:
	var sala := SalaDeRetorno.new()
	sala.position = area.position
	sala.size = area.size
	for p in marcadores:
		var m := Marker2D.new()
		sala.add_child(m)
		m.position = (p as Vector2) - area.position
	current_scene.add_child(sala)
	return sala


## A câmera no primeiro quadro e meio segundo depois tem que estar no mesmo
## lugar (a personagem é segurada parada para o teste não depender da queda).
func _checar_camera_parada(player: CharacterBody2D, nome: String) -> void:
	var camera := player.get_node("Camera2D") as Camera2D
	var pos := player.global_position
	await _quadros(1)
	var antes := camera.get_screen_center_position()
	for i in 30:
		player.global_position = pos
		player.velocity = Vector2.ZERO
		await process_frame
	var depois := camera.get_screen_center_position()
	_checar(antes.distance_to(depois) < 2.0, "%s (%s -> %s)" % [nome, antes, depois])


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _quadros_fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _perto(a: Vector2, b: Vector2, nome: String, tolerancia: float = 1.0) -> void:
	_checar(a.distance_to(b) <= tolerancia, "%s (%s vs %s)" % [nome, a, b])


func _checar(ok: bool, nome: String) -> void:
	print(("  ok   " if ok else "  FALHA ") + nome)
	if not ok:
		_falhas += 1
