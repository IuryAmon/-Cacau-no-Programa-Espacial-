extends Node

# Teste da cesta de maçãs do world1 (scripts/fases/cesta_macas.gd):
#
#   * a cesta cheia mora no world1, no chão, e os tiles dela saíram da camada
#     "à frente" (senão sobraria uma cesta cheia desenhada por baixo da vazia);
#   * o botão E só aparece com a Cacau por perto;
#   * com a vida cheia o E não gasta a cesta;
#   * machucada, o E devolve a vida, toca o som e deixa só a cesta vazia;
#   * vazia, não cura de novo — nem depois de recarregar a cena.
#
#   godot --headless --path . res://tools/teste_cesta_macas.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva imagens da cesta cheia
# com o botão e da cesta vazia, para conferir a olho.

const MUNDO := "res://scenes/world1.tscn"

var _falhas := 0
var _pasta_capturas := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			_pasta_capturas = arg.trim_prefix("--capturas=")
	await get_tree().process_frame

	await _testar_comer()
	await _testar_recarregar()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


# ─────────────────────────────────────────────────────────────

func _testar_comer() -> void:
	print("\n--- COMER AS MAÇÃS ---")
	var mundo := await _abrir()
	var cesta: CestaMacas = mundo.get_node_or_null("CestaMacas")
	_checar(cesta != null, "a cesta mora no world1")
	if cesta == null:
		return
	var player := mundo.get_node("Player") as CharacterBody2D
	var sprite := cesta.get_node("Sprite") as Sprite2D
	var dica := cesta.get_node("Dica") as CanvasItem
	var som := cesta.get_node("Som") as AudioStreamPlayer2D

	var frente := mundo.get_node("Chão/à frente") as TileMapLayer
	_checar(frente.get_cell_source_id(Vector2i(153, 8)) == -1
			and frente.get_cell_source_id(Vector2i(154, 8)) == -1,
		"os tiles da cesta saíram da camada 'à frente'")
	_checar(frente.get_cell_source_id(Vector2i(-28, -13)) == -1,
		"a cesta vazia de referência saiu do mapa")
	_checar(sprite.region_rect == CestaMacas.REGIAO_CHEIA, "começa cheia")
	_checar(sprite.z_index == frente.z_index, "desenha na mesma camada dos enfeites da frente")
	_checar(not dica.visible, "de longe, sem botão")

	await _chegar_perto(player, cesta)
	_checar(dica.visible, "de perto, o botão E aparece em cima da cesta")
	_checar(dica.global_position.y < sprite.global_position.y - 32.0, "o botão fica acima da cesta")
	await _capturar("1_cheia_com_botao")

	# Vida cheia: o toque não gasta nada.
	_checar(player.current_health == player.max_health, "a Cacau chega com a vida cheia")
	await _apertar_e()
	_checar(not cesta.esta_vazia(), "com a vida cheia, o E não gasta a cesta")
	_checar(not som.playing, "e não toca o som")

	# Machucada.
	player.current_health = 1
	player.health_changed.emit(player.current_health)
	var avisos: Array[int] = []
	player.health_changed.connect(func(v: int) -> void: avisos.append(v))
	await _apertar_e()
	_checar(cesta.esta_vazia(), "machucada, o E come as maçãs")
	_checar(player.current_health == player.max_health, "a vida volta inteira")
	_checar(avisos == [player.max_health], "o HUD fica sabendo da cura")
	_checar(sprite.region_rect == CestaMacas.REGIAO_VAZIA, "fica só a cesta")
	_checar(som.playing, "toca o RecuperandoVida")
	await _capturar("2_amassando")
	await _quadros(2)
	_checar(not dica.visible, "vazia, o botão some")
	_checar(EstadoMundo.ja_feito(cesta), "a cesta vazia fica anotada no EstadoMundo")

	# Vazia não cura de novo.
	player.current_health = 1
	await _apertar_e()
	_checar(player.current_health == 1, "vazia, o E não cura de novo")
	player.current_health = player.max_health
	await _esperar(0.5)
	_checar(sprite.scale.is_equal_approx(Vector2(2, 2)), "a amassada volta ao tamanho normal")
	await _capturar("3_vazia")
	await _fechar(mundo)


func _testar_recarregar() -> void:
	print("\n--- RECARREGAR A CENA ---")
	var mundo := await _abrir()
	var cesta: CestaMacas = mundo.get_node_or_null("CestaMacas")
	if cesta == null:
		_checar(false, "a cesta existe depois de recarregar")
		return
	var player := mundo.get_node("Player") as CharacterBody2D
	_checar(cesta.esta_vazia(), "recarregar não enche a cesta de novo")
	_checar((cesta.get_node("Sprite") as Sprite2D).region_rect == CestaMacas.REGIAO_VAZIA,
		"e ela nasce desenhada vazia")
	await _chegar_perto(player, cesta)
	player.current_health = 1
	await _apertar_e()
	_checar(player.current_health == 1, "nem cura")
	_checar(not (cesta.get_node("Dica") as CanvasItem).visible, "nem mostra o botão")
	player.current_health = player.max_health
	await _fechar(mundo)


# ─────────────────────────────────────────────────────────────

func _abrir() -> Node:
	var mundo: Node = (load(MUNDO) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(mundo)
	await _quadros(2)
	# A personagem fica parada fora da física, longe da cesta: o teste é da
	# cesta, e cair ou morrer recarregaria a cena atual (este teste) no meio do
	# caminho. A posição sai da própria cesta porque o nó World não está na
	# origem — ele fica deslocado em (909, 340).
	var player := mundo.get_node("Player") as CharacterBody2D
	player.set_physics_process(false)
	var cesta := mundo.get_node_or_null("CestaMacas") as Node2D
	if cesta:
		player.global_position = cesta.global_position + Vector2(-400, -36)
	await get_tree().physics_frame
	await _quadros(2)
	return mundo


## Põe a Cacau em pé ao lado da cesta e deixa a física perceber: é a Colisao
## da cesta de verdade que acende o botão, não uma chamada direta.
func _chegar_perto(player: Node2D, cesta: Node2D) -> void:
	player.global_position = cesta.global_position + Vector2(-40, -36)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# A câmera tem suavização: espera ela chegar na personagem (capturas).
	await _esperar(1.5)


func _fechar(mundo: Node) -> void:
	mundo.queue_free()
	await _quadros(2)


func _apertar_e() -> void:
	Input.action_press(Interacao.ACAO)
	await get_tree().process_frame
	Input.action_release(Interacao.ACAO)
	await _quadros(2)


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos, true).timeout


func _capturando() -> bool:
	return not _pasta_capturas.is_empty() and DisplayServer.get_name() != "headless"


func _capturar(nome: String) -> void:
	if not _capturando():
		return
	await RenderingServer.frame_post_draw
	var imagem := get_viewport().get_texture().get_image()
	imagem.save_png(_pasta_capturas.path_join(nome + ".png"))
