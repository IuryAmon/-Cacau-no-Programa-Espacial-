extends Node

# Teste automático do ELEVADOR entre fases (scripts/fases/elevador_fase.gd): o
# par que liga a oficina (fase 1) ao corredor do pátio — e do pátio da fase
# 1.2, a fase de tela única do outro lado desse corredor.
#
#   godot --headless --path . res://tools/teste_elevador.tscn
#
# O que dá para conferir sem abrir o jogo: a fiação das duas pontas (tags,
# cena de destino), o sheet de 13 quadros abrindo e fechando, o percurso
# levando a passageira junto SEM levar a câmera, e a chegada encenada — que é
# a parte que roda sozinha no _ready() do elevador de destino.
#
# A viagem inteira, com as trocas de cena de verdade (oficina <-> corredor <->
# pátio), tem um teste só dela: tools/teste_corredor_patio.tscn.

const OFICINA := "res://scenes/fases/fase1_oficina.tscn"
const CORREDOR := "res://scenes/fases/corredor_patio.tscn"
const PATIO := "res://scenes/fases/fase1_2_exterior.tscn"

var _falhas := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# O teste sai de cena: a chegada é testada com uma troca de cena de verdade
	# (o elevador procura a passageira na cena atual), e ela não pode apagar o
	# próprio teste.
	get_tree().current_scene = null

	await _testar_fiacao()
	await _testar_patio()
	await _testar_estrado()
	await _testar_grade()
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

	var oficina := await _abrir(OFICINA)
	var sobe := _elevador(oficina, "Entrada/ElevadorPatio")
	_checar(sobe != null, "elevador na entrada da fase1")
	if sobe:
		_checar(sobe.direcao == ElevadorFase.Direcao.SOBE, "o da oficina sobe")
		_checar(sobe.cena_destino == CORREDOR,
			"o da oficina leva para o corredor do patio (e nao mais direto para a fase1.2)")
		_checar(sobe.tag_aqui == "oficina" and sobe.tag_destino == "patio",
			"tags da oficina apontam para o patio")
		_checar(sobe.recebe_chegada, "o da oficina tambem recebe quem volta")
		_checar(sobe._ultimo_quadro() == 12, "o sheet tem os 13 quadros")
		_checar(sobe._sprite.frame == 0, "ele comeca ABERTO (quadro 1 do sheet)")
	# A fornalha e a lenha mudaram de endereço.
	_checar(oficina.get_node_or_null("Patio/Retorta") == null, "fornalha saiu da oficina")
	_checar(get_tree().get_nodes_in_group("madeira").is_empty(), "as toras sairam da oficina")
	await _fechar(oficina)

	var corredor := await _abrir(CORREDOR)
	var desce := _elevador(corredor, "Elevador")
	_checar(desce != null, "elevador na ponta do corredor do patio")
	if desce and sobe:
		_checar(desce.direcao == ElevadorFase.Direcao.DESCE, "o do corredor desce")
		_checar(desce.tag_aqui == sobe.tag_destino and desce.tag_destino == sobe.tag_aqui,
			"as tags das duas pontas se cruzam")
		_checar(desce.cena_destino == OFICINA, "o do corredor volta para a oficina")
	if desce:
		# O piso na frente de tudo é o que esconde a cabine dentro do poço.
		var piso: TileMapLayer = corredor.get_node_or_null("Estrutura")
		var player: Node2D = corredor.get_node("Player")
		_checar(piso != null and piso.z_index > desce.z_index,
			"o piso do corredor desenha NA FRENTE da cabine (o poco esconde ela)")
		_checar(piso != null and piso.z_index > player.z_index,
			"e NA FRENTE da passageira")
	await _fechar(corredor)


# --- O PÁTIO (fase 1.2) ---

func _testar_patio() -> void:
	print("\n--- PATIO: A FASE DE TELA UNICA ---")
	var f := await _abrir(PATIO)

	var player: CharacterBody2D = f.get_node_or_null("Player")
	_checar(player != null, "player na cena")

	# A câmera parada é só isto: limites do tamanho de UM quadro (1600x900
	# dividido pelo zoom da fase — 1,35, o do world1). Se o retângulo crescer,
	# ela volta a andar.
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	var largura_visivel: float = 1600.0 / camera.zoom.x
	var altura_visivel: float = 900.0 / camera.zoom.y
	_checar(camera.limit_right - camera.limit_left <= ceili(largura_visivel) + 1,
		"limites travam a camera na horizontal")
	_checar(camera.limit_bottom - camera.limit_top <= ceili(altura_visivel) + 1,
		"limites travam a camera na vertical")

	# O retângulo não tem como ser do tamanho exato do quadro (1185 x 667 contra
	# 1185,19 x 666,67): sobra uma fração de pixel de diferença em cada eixo,
	# pouco demais para a câmera andar ou para alguém enxergar.
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

	# A fornalha mudou de fase junto, e a lenha dela está na copa da árvore do
	# pátio: nenhuma tora largada no chão, as três esperando o bumerangue.
	_checar(f.get_node_or_null("Patio/Retorta") != null, "fornalha mora no patio")
	var arvore: ArvoreLenha = f.get_node_or_null("Patio/ArvoreLenha")
	_checar(arvore != null and arvore.toras_na_copa() == 3, "as tres toras estao na copa da arvore")
	_checar(get_tree().get_nodes_in_group("madeira").is_empty(), "nenhuma tora largada no chao")

	# O elevador não chega mais aqui: ele dá no corredor, e do corredor se entra
	# no pátio andando, pela ponta esquerda.
	_checar(f.get_node_or_null("Elevador") == null, "o patio nao tem mais elevador")
	var passagem := f.get_node_or_null("PassagemCorredor") as PassagemDeCena
	_checar(passagem != null and passagem.cena_destino == CORREDOR and passagem.sentido < 0.0,
		"entra-se e sai-se dele andando, pela ponta esquerda (passagem para o corredor)")

	await _fechar(f)


# --- O ESTRADO E A RAMPINHA ---

func _testar_estrado() -> void:
	print("\n--- O ESTRADO: onde se pisa dentro da cabine ---")
	var f := await _abrir(CORREDOR)
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


# --- A GRADE DA CABINE E A PAREDE DA ESQUERDA DA OFICINA ---
#
# Na oficina o elevador fica na ponta esquerda do mapa, e o chão acaba logo
# depois dele, fora da tela. Andando reto pela cabine, a Cacau saía pelo lado
# esquerdo e caía do mundo. Agora a cabine tem a GRADE (uma colisão baixa na
# beirada esquerda do estrado: andando não passa, pulando passa) e a oficina
# tem a PAREDE DA ESQUERDA, que segura quem pulou a grade.

func _testar_grade() -> void:
	print("\n--- A GRADE DA CABINE E A PAREDE DA ESQUERDA (oficina) ---")
	# A oficina abre com o rádio do Dr. Chico chamando, e a conversa prenderia a
	# Cacau no lugar: aqui ele fica calado.
	var f: Node = (load(OFICINA) as PackedScene).instantiate()
	f.get_node("Entrada/RadioDrChico").set("falar_ao_entrar", false)
	get_tree().root.add_child.call_deferred(f)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	var elevador := _elevador(f, "Entrada/ElevadorPatio")
	var player: CharacterBody2D = f.get_node("Player")
	var grade := elevador.get_node_or_null("Cabine/Piso/Grade") as CollisionShape2D
	var parede := f.get_node_or_null("Colisoes/ParedeEsquerda/Colisao") as CollisionShape2D
	_checar(grade != null and grade.shape is RectangleShape2D, "a cabine tem a grade, na beirada esquerda do estrado")
	_checar(parede != null and parede.shape is RectangleShape2D, "a oficina tem a parede da esquerda")
	if grade == null or parede == null:
		await _fechar(f)
		return

	# As medidas, no mundo.
	var meia_grade: Vector2 = (grade.shape as RectangleShape2D).size * 0.5 * grade.global_scale.abs()
	var grade_por_dentro: float = grade.global_position.x + meia_grade.x
	var grade_por_fora: float = grade.global_position.x - meia_grade.x
	var estrado: float = elevador.global_position.y + elevador._altura_do_piso()
	var face_da_parede: float = parede.global_position.x \
		+ (parede.shape as RectangleShape2D).size.x * 0.5 * parede.global_scale.x
	var raio_do_corpo: float = (player.get_node("CollisionShape2D").shape as CapsuleShape2D).radius
	var camera: Camera2D = player.get_node("Camera2D")

	_checar(absf(grade.global_position.y + meia_grade.y - estrado) < 1.0,
		"a grade nasce no estrado (%.0f)" % estrado)
	var altura_da_grade: float = meia_grade.y * 2.0
	var pulo: float = player.jump_velocity * player.jump_velocity / (2.0 * player.gravity)
	_checar(altura_da_grade > 20.0 and altura_da_grade < pulo * 0.6,
		"e e baixa: %.0f px, contra os %.0f de um pulo" % [altura_da_grade, pulo])
	_checar(grade_por_fora - face_da_parede > raio_do_corpo * 2.0,
		"entre a parede e a cabine cabe a Cacau (%.1f px de vao, ela tem %.0f)"
			% [grade_por_fora - face_da_parede, raio_do_corpo * 2.0])
	_checar(face_da_parede > camera.limit_left - raio_do_corpo,
		"e a parede fica na beirada da tela: encostada nela, a Cacau ainda aparece")

	# O chão do vão, à esquerda da cabine.
	var espaco := (f as Node2D).get_world_2d().direct_space_state
	var raio := PhysicsRayQueryParameters2D.create(
		Vector2((grade_por_fora + face_da_parede) * 0.5, estrado - 4.0),
		Vector2((grade_por_fora + face_da_parede) * 0.5, estrado + 200.0), 1, [player.get_rid()])
	var achou := espaco.intersect_ray(raio)
	_checar(not achou.is_empty(), "ha chao no vao entre a parede e a cabine")
	var chao: float = (achou.position as Vector2).y if not achou.is_empty() else estrado

	# 1. Andando para a esquerda por dentro da cabine: a grade segura.
	player.global_position = elevador._ponto_de_embarque(player)
	player.velocity = Vector2.ZERO
	await _pousar(player)
	Input.action_press("ui_left")
	for _i in 90:
		await get_tree().physics_frame
	Input.action_release("ui_left")
	var pes: float = player.global_position.y + elevador._altura_dos_pes(player)
	_checar(player.global_position.x > grade_por_dentro and player.is_on_floor() and absf(pes - estrado) < 3.0,
		"andando para a esquerda ela para na grade, ainda em cima do estrado (x = %.0f)" % player.global_position.x)

	# 2. Pulando por cima da grade: desce pelo lado esquerdo, e não cai do mundo.
	await _pular_para(player, "ui_left", func() -> bool:
		return player.is_on_floor() and player.global_position.x < grade_por_fora)
	pes = player.global_position.y + elevador._altura_dos_pes(player)
	_checar(player.global_position.x < grade_por_fora and player.is_on_floor() and absf(pes - chao) < 3.0,
		"pulando a grade ela desce pelo lado esquerdo e pisa no chao da oficina (x = %.0f)" % player.global_position.x)

	# 3. Insistindo para a esquerda: a parede segura.
	Input.action_press("ui_left")
	for _i in 90:
		await get_tree().physics_frame
	Input.action_release("ui_left")
	pes = player.global_position.y + elevador._altura_dos_pes(player)
	_checar(player.global_position.x - raio_do_corpo >= face_da_parede - 0.5 and player.is_on_floor()
		and absf(pes - chao) < 3.0 and player.current_health == player.max_health,
		"e a parede da esquerda a segura: ela nao cai do mundo (x = %.0f)" % player.global_position.x)
	_checar(player.global_position.x > camera.limit_left,
		"encostada na parede, mais da metade dela continua dentro da tela")

	# 4. De volta, pulando a grade para o lado de dentro. (O pulo dela é
	# comprido: segurando o lado, ela passa por cima da cabine inteira e pousa
	# depois da rampa — o que importa é que saiu do vão.)
	await _pular_para(player, "ui_right", func() -> bool:
		return player.is_on_floor() and player.global_position.x > grade_por_dentro)
	pes = player.global_position.y + elevador._altura_dos_pes(player)
	_checar(player.global_position.x > grade_por_dentro and player.is_on_floor() and pes <= chao + 3.0,
		"e sai do vao do mesmo jeito, pulando a grade de volta (x = %.0f)" % player.global_position.x)

	await _fechar(f)


## Segura o lado pedido e pula (de novo, se pousar antes de chegar) até a
## condição valer.
func _pular_para(player: CharacterBody2D, lado: StringName, chegou: Callable) -> void:
	Input.action_press(lado)
	for _i in 240:
		if chegou.call():
			break
		if player.is_on_floor():
			Input.action_press("jump")
			await get_tree().physics_frame
			await get_tree().physics_frame
			Input.action_release("jump")
		await get_tree().physics_frame
	Input.action_release(lado)


# --- OS 13 QUADROS ---

func _testar_portas() -> void:
	print("\n--- A PORTA: 13 QUADROS PARA FECHAR, OS MESMOS PARA ABRIR ---")
	var f := await _abrir(CORREDOR)
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
	var f := await _abrir(CORREDOR)
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

	# Troca de cena de verdade: o elevador que recebe procura a passageira na
	# cena atual (o _ready() dele roda antes de o player entrar no grupo).
	get_tree().change_scene_to_file(CORREDOR)
	for _i in 120:
		await get_tree().process_frame
		if get_tree().current_scene and get_tree().current_scene.scene_file_path == CORREDOR:
			break
	var f := get_tree().current_scene
	await get_tree().process_frame
	var elevador := _elevador(f, "Elevador")
	var player: CharacterBody2D = f.get_node("Player")

	_checar(not ElevadorFase.chegando_de_elevador, "o elevador do corredor assumiu a chegada")
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
	_checar(player.is_on_floor(), "e sai do elevador pisando no chao do corredor")

	get_tree().current_scene = null
	await _fechar(f)
