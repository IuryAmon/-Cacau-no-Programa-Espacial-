extends Node

# Teste do dash em cima das plataformas que andam (fase 1, oficina): a de
# viagem e a móvel. O congelamento de impacto do dash não pode zerar o tempo
# do jogo — com passo de física 0 a velocidade da plataforma sai de 0 / 0 e a
# Cacau ia parar em posição NaN (sumia da tela e o jogo "bugava").
#
#   godot --headless --path . res://tools/teste_dash_na_plataforma.tscn

const FASE1 := "res://scenes/fases/fase1_oficina.tscn"
## Do centro da cápsula até a sola (72 de altura, centrada na origem).
const ATE_A_SOLA := 36.0
## Metade da altura da colisão das plataformas (32 px).
const MEIA_ALTURA_PLATAFORMA := 16.0

var _falhas := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var tinha_mochila := Progresso.tem_habilidade("mochila")
	Progresso._habilidades["mochila"] = true

	for alvo: String in ["PlataformaDeViagem", "PlataformaMovel"]:
		print("\n--- %s ---" % alvo)
		for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			await _dash_em_cima(alvo, dir)

	if not tinha_mochila:
		Progresso._habilidades.erase("mochila")
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


func _dash_em_cima(alvo: String, dir: Vector2) -> void:
	var fase: Node = (load(FASE1) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(fase)
	for i in 3:
		await get_tree().physics_frame
	var player := fase.get_node("Player") as CharacterBody2D
	var plataforma := fase.get_node(alvo) as Node2D
	var ferramentas := player.get_node("Ferramentas") as FerramentasPlayer
	player.global_position = plataforma.global_position \
		+ Vector2(0, -MEIA_ALTURA_PLATAFORMA - ATE_A_SOLA - 1.0)
	player.velocity = Vector2.ZERO

	# Pousa e espera a plataforma pegar velocidade (a de viagem só sai depois
	# que alguém pisa nela).
	var x_da_plataforma := plataforma.global_position.x
	for i in 90:
		await get_tree().physics_frame
	var andando := not is_equal_approx(plataforma.global_position.x, x_da_plataforma)
	if not player.is_on_floor() or not andando:
		_checar(false, "dash %s: ela devia estar em pé na plataforma andando" % dir)
		fase.queue_free()
		await get_tree().process_frame
		return

	var antes := player.global_position
	ferramentas._iniciar_dash(dir)
	var sempre_finita := true
	for i in 40:
		await get_tree().physics_frame
		sempre_finita = sempre_finita and player.global_position.is_finite() \
			and player.velocity.is_finite()
	_checar(sempre_finita, "dash %s: a posição nunca vira NaN" % dir)
	_checar(is_equal_approx(Engine.time_scale, 1.0), "dash %s: o tempo volta ao normal" % dir)
	if dir != Vector2.DOWN:
		# Para baixo ela fica em pé na plataforma, que é de mão única. A móvel
		# anda de parede a parede: um dash para o lado da parede bate nela antes
		# dos ~190 px do arranco, então basta ter saído para o lado certo.
		_checar((player.global_position - antes).dot(dir) > 50.0,
			"dash %s: ela sai voando para o lado do dash (%s -> %s)" % [dir, antes.round(), player.global_position.round()])

	fase.queue_free()
	for i in 3:
		await get_tree().process_frame
