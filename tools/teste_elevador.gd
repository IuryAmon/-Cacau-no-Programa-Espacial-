extends Node

# Teste automático do ELEVADOR entre fases (scripts/fases/elevador_fase.gd) e
# do pátio da fase1.2, que é a fase de tela única para onde ele leva.
#
#   godot --headless --path . res://tools/teste_elevador.tscn
#
# O que dá para conferir sem abrir o jogo: a fiação das duas pontas (tags,
# cena de destino), o sheet de 13 quadros abrindo e fechando, o percurso
# levando a passageira junto SEM levar a câmera, e a chegada encenada — que é
# a parte que roda sozinha no _ready() do elevador de destino.
#
# A troca de cena em si (o FadeTela.trocar_cena no fim da partida) fica de
# fora: ela derrubaria a própria cena do teste. O que este arquivo garante é
# que tudo ANTES dela acontece direito.

var _falhas := 0


func _ready() -> void:
	await _testar_fiacao()
	await _testar_patio()
	await _testar_estrado()
	await _testar_portas()
	await _testar_percurso()
	await _testar_chegada()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok   " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


func _abrir(caminho: String) -> Node:
	var raiz: Node = (load(caminho) as PackedScene).instantiate()
	# call_deferred: no primeiro _ready() a raiz da árvore ainda está montando
	# os filhos e um add_child() direto é recusado.
	get_tree().root.add_child.call_deferred(raiz)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	return raiz


func _fechar(raiz: Node) -> void:
	raiz.queue_free()
	await get_tree().process_frame


## Deixa a física correr até a personagem parar no chão.
func _pousar(player: CharacterBody2D) -> void:
	for _i in 120:
		await get_tree().physics_frame
		if player.is_on_floor():
			return


func _elevador(raiz: Node, caminho: String) -> ElevadorFase:
	return raiz.get_node_or_null(caminho) as ElevadorFase


# --- AS DUAS PONTAS ---

func _testar_fiacao() -> void:
	print("\n--- FIACAO DOS DOIS ELEVADORES ---")

	var oficina := await _abrir("res://scenes/fases/fase1_oficina.tscn")
	var sobe := _elevador(oficina, "Entrada/ElevadorPatio")
	_checar(sobe != null, "elevador na entrada da fase1")
	if sobe:
		_checar(sobe.direcao == ElevadorFase.Direcao.SOBE, "o da oficina sobe")
		_checar(sobe.cena_destino == "res://scenes/fases/fase1_2_exterior.tscn",
			"o da oficina leva para a fase1.2")
		_checar(sobe.tag_aqui == "oficina" and sobe.tag_destino == "patio",
			"tags da oficina apontam para o patio")
		_checar(sobe.recebe_chegada, "o da oficina tambem recebe quem volta")
		_checar(sobe._ultimo_quadro() == 12, "o sheet tem os 13 quadros")
		_checar(sobe._sprite.frame == 0, "ele comeca ABERTO (quadro 1 do sheet)")
	# A fornalha e a lenha mudaram de endereço.
	_checar(oficina.get_node_or_null("Patio/Retorta") == null, "fornalha saiu da oficina")
	_checar(get_tree().get_nodes_in_group("madeira").is_empty(), "as toras sairam da oficina")
	await _fechar(oficina)

	var patio := await _abrir("res://scenes/fases/fase1_2_exterior.tscn")
	var desce := _elevador(patio, "Elevador")
	_checar(desce != null, "elevador no patio da fase1.2")
	if desce and sobe:
		_checar(desce.direcao == ElevadorFase.Direcao.DESCE, "o do patio desce")
		_checar(desce.tag_aqui == sobe.tag_destino and desce.tag_destino == sobe.tag_aqui,
			"as tags das duas pontas se cruzam")
		_checar(desce.cena_destino == "res://scenes/fases/fase1_oficina.tscn",
			"o do patio volta para a oficina")
	await _fechar(patio)


# --- O PÁTIO (fase 1.2) ---

func _testar_patio() -> void:
	print("\n--- PATIO: A FASE DE TELA UNICA ---")
	var f := await _abrir("res://scenes/fases/fase1_2_exterior.tscn")

	var player: CharacterBody2D = f.get_node_or_null("Player")
	_checar(player != null, "player na cena")

	# A câmera parada é só isto: limites do tamanho de UM quadro (1600x900
	# dividido pelo zoom 1.5). Se o retângulo crescer, ela volta a andar.
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	var largura_visivel: float = 1600.0 / camera.zoom.x
	var altura_visivel: float = 900.0 / camera.zoom.y
	_checar(camera.limit_right - camera.limit_left <= ceili(largura_visivel) + 1,
		"limites travam a camera na horizontal")
	_checar(camera.limit_bottom - camera.limit_top <= ceili(altura_visivel) + 1,
		"limites travam a camera na vertical")

	# O retângulo é 0,33px mais largo que o quadro (1067 contra 1066,67), então
	# sobra essa fração de folga — o bastante para o limite CONTER a tela
	# inteira e pouco demais para alguém enxergar.
	var antes := camera.get_screen_center_position()
	player.global_position.x += 400.0
	CameraJogador.encaixar(player)
	await get_tree().process_frame
	_checar(camera.get_screen_center_position().distance_to(antes) < 1.0,
		"andar 400px pelo patio nao move a camera")
	player.global_position.x -= 400.0
	CameraJogador.encaixar(player)

	# Chão de verdade embaixo da personagem (o TileMapLayer do terreno).
	await _pousar(player)
	_checar(player.is_on_floor(), "o chao do patio segura a personagem")

	# A fornalha e as três toras mudaram de fase junto.
	_checar(f.get_node_or_null("Patio/Retorta") != null, "fornalha mora no patio")
	_checar(get_tree().get_nodes_in_group("madeira").size() == 3, "as tres toras vieram junto")

	# O terreno na frente de tudo é o que esconde a cabine dentro do poço.
	var terreno: TileMapLayer = f.get_node_or_null("Terreno")
	var elevador := _elevador(f, "Elevador")
	_checar(terreno != null and terreno.z_index > elevador.z_index,
		"terreno desenha NA FRENTE da cabine (o poco esconde ela)")
	_checar(terreno != null and terreno.z_index > player.z_index,
		"terreno desenha NA FRENTE da passageira")

	await _fechar(f)


# --- O ESTRADO E A RAMPINHA ---

func _testar_estrado() -> void:
	print("\n--- O ESTRADO: onde se pisa dentro da cabine ---")
	var f := await _abrir("res://scenes/fases/fase1_2_exterior.tscn")
	var elevador := _elevador(f, "Elevador")
	var player: CharacterBody2D = f.get_node("Player")

	var poligono: CollisionPolygon2D = elevador.get_node_or_null("Cabine/Piso/Colisao")
	_checar(poligono != null and poligono.polygon.size() >= 3, "a cabine tem poligono de colisao")
	_checar(elevador.get_node_or_null("Cabine/Piso") is AnimatableBody2D,
		"o estrado e AnimatableBody2D (anda com a cabine)")

	var piso: float = elevador._altura_do_piso()
	_checar(piso < 0.0, "o estrado fica ACIMA do chao de fora (e por isso existe a rampinha)")

	# Solta a personagem em cima da cabine: ela tem de parar no estrado, e não
	# atravessar até o chão da fase.
	player.global_position = elevador.global_position + Vector2(0.0, piso - 140.0)
	player.velocity = Vector2.ZERO
	await _pousar(player)
	var pes: float = player.global_position.y + elevador._altura_dos_pes(player)
	_checar(player.is_on_floor(), "o estrado segura a personagem")
	_checar(absf(pes - (elevador.global_position.y + piso)) < 3.0,
		"ela para em cima do estrado, e nao no chao da fase")

	# A rampa é subível: entre o pé dela e o estrado não pode haver degrau maior
	# do que a inclinação máxima de chão do jogo.
	var topo := INF
	var base := -INF
	var direita := -INF
	for ponto in poligono.polygon:
		topo = minf(topo, ponto.y)
		base = maxf(base, ponto.y)
		direita = maxf(direita, ponto.x)
	var subida: float = base - topo
	var corrida: float = direita - ElevadorFase.CABINE_LARGURA * 0.5
	_checar(corrida > 0.0 and rad_to_deg(atan(subida / corrida)) < 45.0,
		"a rampa sobe em angulo de chao (da para entrar andando)")

	await _fechar(f)


# --- OS 13 QUADROS ---

func _testar_portas() -> void:
	print("\n--- A PORTA: 13 QUADROS PARA FECHAR, OS MESMOS PARA ABRIR ---")
	var f := await _abrir("res://scenes/fases/fase1_2_exterior.tscn")
	var elevador := _elevador(f, "Elevador")
	elevador.duracao_das_portas = 0.2

	_checar(elevador._sprite.frame == 0, "comeca no quadro aberto")
	await elevador._animar_portas(false)
	_checar(elevador._sprite.frame == 12, "fechar termina no quadro 13")
	await elevador._animar_portas(true)
	_checar(elevador._sprite.frame == 0, "abrir e a mesma animacao ao contrario")

	await _fechar(f)


# --- O PERCURSO ---

func _testar_percurso() -> void:
	print("\n--- O PERCURSO: leva a passageira, deixa a camera ---")
	var f := await _abrir("res://scenes/fases/fase1_2_exterior.tscn")
	var elevador := _elevador(f, "Elevador")
	var player: CharacterBody2D = f.get_node("Player")
	elevador.duracao_do_percurso = 0.2

	player.global_position = elevador._ponto_de_embarque(player)
	elevador._travar_passageira(player)
	elevador._congelar_camera(player)

	var camera: Camera2D = player.get_node("Camera2D")
	var camera_antes := camera.global_position
	var player_antes := player.global_position

	await elevador._percorrer(0.0, elevador._passo_do_poco(), player)

	_checar(is_equal_approx(elevador._cabine.position.y, elevador.curso),
		"a cabine desceu o curso inteiro")
	_checar(absf(player.global_position.y - (player_antes.y + elevador.curso)) < 1.0,
		"a passageira desceu junto com a cabine")
	_checar(camera.global_position.is_equal_approx(camera_antes),
		"a camera NAO acompanhou")
	_checar(not player.pode_se_mover and player.animacao_controlada_externamente,
		"a passageira fica travada (e sem gravidade) no percurso")

	elevador._soltar_passageira(player)
	_checar(player.pode_se_mover and not player.animacao_controlada_externamente,
		"o controle volta no fim")
	_checar(camera.position.is_equal_approx(camera.posicao_padrao),
		"a camera volta ao encaixe normal")

	await _fechar(f)


# --- A CHEGADA ---

func _testar_chegada() -> void:
	print("\n--- A CHEGADA: a cabine sobe do poco e abre sozinha ---")
	# É assim que a partida deixa o mundo antes de trocar de cena.
	ElevadorFase.chegando_de_elevador = true
	ElevadorFase.tag_chegada = "patio"

	var f := await _abrir("res://scenes/fases/fase1_2_exterior.tscn")
	var elevador := _elevador(f, "Elevador")
	var player: CharacterBody2D = f.get_node("Player")

	_checar(not ElevadorFase.chegando_de_elevador, "o elevador do patio assumiu a chegada")
	_checar(elevador._sprite.frame == 12, "a tela abre com a cabine FECHADA")
	_checar(elevador._cabine.position.y > 0.0, "a cabine comeca la embaixo, no poco")
	_checar(not player.pode_se_mover, "a passageira chega sem o controle na mao")

	# O percurso da chegada + a pausa + a porta abrindo.
	var espera := 0.0
	var limite: float = elevador.duracao_do_percurso + elevador.pausa_antes_de_abrir \
		+ elevador.duracao_das_portas + 2.0
	while elevador._estado != ElevadorFase.Estado.PARADO and espera < limite:
		await get_tree().create_timer(0.1).timeout
		espera += 0.1

	_checar(elevador._estado == ElevadorFase.Estado.PARADO, "a chegada terminou sozinha")
	_checar(elevador._cabine.position.y == 0.0, "a cabine parou no lugar dela")
	_checar(elevador._sprite.frame == 0, "a rampa abriu para ela sair")
	_checar(player.pode_se_mover and not player.animacao_controlada_externamente,
		"o controle voltou para a passageira")
	_checar(absf(player.global_position.x - elevador.global_position.x) < 2.0,
		"ela chegou em pe dentro da cabine")

	await _pousar(player)
	_checar(player.is_on_floor(), "e sai do elevador pisando no chao do patio")

	await _fechar(f)
