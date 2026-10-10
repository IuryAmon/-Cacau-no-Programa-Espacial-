extends Node

# Teste do corredor do pátio (scenes/fases/corredor_patio.tscn) e do caminho
# novo entre a oficina e o pátio:
#
#   oficina  Entrada/ElevadorPatio  <->  Elevador  [ corredor ]  SaidaPatio  <->  PassagemCorredor  pátio
#
#   godot --headless --fixed-fps 60 --path . res://tools/teste_corredor_patio.tscn
#
# (Roda como cena, e não com -s: as fases usam autoloads desde o _ready().)
#
# Casos:
#   * o corredor: é o mesmo da torre (as mesmas peças), pintado sem buraco, com
#     a colisão nos tiles e a câmera mostrando exatamente a faixa dela; não tem
#     porta — a ponta esquerda é o ELEVADOR, encostado no canto, de tags
#     cruzadas com o da oficina, com o piso desenhado na frente da cabine (é o
#     poço); a ponta direita é uma PassagemDeCena para o pátio;
#   * o pátio: o prédio do elevador saiu (nem cabine, nem porta de metal, nem
#     parede, nem piso de pedra) e o chão é grama de ponta a ponta; a ponta
#     esquerda é uma PassagemDeCena na beirada do quadro, com grama sobrando
#     para fora e sem parede no caminho;
#   * a ida: chegando da oficina, a cabine sobe do poço fechada, abre e devolve
#     o controle; correndo de verdade até o fundo a cena troca sozinha, e no
#     pátio ela vem de fora do quadro e entra andando na grama;
#   * a volta: andando para a esquerda no pátio, a cena troca sozinha; no
#     corredor ela entra pelo fundo, corre até a cabine (subindo a rampa) e
#     desce — chegando na oficina dentro do elevador de lá;
#   * e de novo para cima, agora partindo da oficina de verdade.

const FASE1 := "res://scenes/fases/fase1_oficina.tscn"
const CORREDOR := "res://scenes/fases/corredor_patio.tscn"
const PATIO := "res://scenes/fases/fase1_2_exterior.tscn"
const CORREDOR_DA_TORRE := "res://scenes/fases/corredor_torre.tscn"
const SCRIPT_PORTA := "res://scripts/porta_simulador.gd"
## O rádio da entrada da oficina (ele chama assim que a Cacau entra na fase).
const RADIO_DA_OFICINA := "/root/Fase1Oficina/Entrada/RadioDrChico"
## As fontes do tileset_fases que são chão de grama e tufo de mato.
const GRAMA := 3
const TUFOS := 5
## Do centro da cápsula da Cacau até a sola.
const ATE_A_SOLA := 36.0
## O mínimo que a cabine tem de andar para se dizer que desceu pelo poço.
const DESCIDA_MINIMA := 200.0

var _falhas := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# O teste sai de cena: as trocas de cena de verdade não o apagam.
	get_tree().current_scene = null
	_rodar()


func _rodar() -> void:
	EstadoMundo.revelou_dr_chico = true
	# O rádio da oficina já falou: a conversa dele não é o assunto aqui.
	EstadoMundo._feitos[RADIO_DA_OFICINA] = true
	await _testar_corredor()
	await _testar_patio()
	await _testar_viagem()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


# ─────────────────────────────────────────────────────────────

func _testar_corredor() -> void:
	print("\n--- O CORREDOR DO PÁTIO ---")
	await _abrir(CORREDOR)
	await _segundos(0.4)
	var cena := get_tree().current_scene
	_checar(cena is FaseBase, "a raiz é uma fase (FaseBase)")

	# É o mesmo corredor da torre: tudo o que aquele tem, este tem (menos as
	# pontas, que são outras).
	var torre: Node = (load(CORREDOR_DA_TORRE) as PackedScene).instantiate()
	var faltando := PackedStringArray()
	for nome in ["Fundo", "LuzDaSaida", "Pilares", "Estrutura", "ParalaxeDaFrente", "Colisoes",
			"LimitesDaCamera", "SpawnPadrao", "Player"]:
		if torre.get_node_or_null(nome) != null and cena.get_node_or_null(nome) == null:
			faltando.append(nome)
	torre.free()
	_checar(faltando.is_empty(), "é o mesmo corredor da torre: as mesmas peças %s" % [faltando])

	var fundo := cena.get_node("Fundo") as TileMapLayer
	var estrutura := cena.get_node("Estrutura") as TileMapLayer
	var limites := cena.get_node("LimitesDaCamera") as ReferenceRect
	var fim := limites.position + limites.size
	var player := _player()
	var camera := player.get_node("Camera2D") as Camera2D
	var passo := 32.0
	var buracos := 0
	for x in range(0, int(limites.size.x / passo)):
		for y in range(int(floor(limites.position.y / passo)), int(ceil(fim.y / passo))):
			var celula := Vector2i(x, y)
			if fundo.get_cell_source_id(celula) == -1 and estrutura.get_cell_source_id(celula) == -1:
				buracos += 1
	_checar(buracos == 0, "sem buraco no cenário dentro do quadro (%d)" % buracos)
	_checar(estrutura.collision_enabled and cena.get_node_or_null("Colisoes/Piso") == null,
		"a colisão do piso e do teto é a dos próprios tiles")
	_checar(absf(900.0 / camera.zoom.y - limites.size.y) < 1.0,
		"a câmera mostra exatamente a faixa do LimitesDaCamera (%.0f px de altura)" % limites.size.y)
	var frente := cena.get_node_or_null("ParalaxeDaFrente") as ParalaxeDaFrente
	_checar(frente != null and frente.get_child_count() > 0, "com a camada de pilastras que passa na frente")

	# A ponta esquerda: o elevador, e não uma porta.
	_checar(_portas_da(cena).is_empty(), "o corredor não tem porta")
	var elevador := cena.get_node_or_null("Elevador") as ElevadorFase
	_checar(elevador != null, "a ponta esquerda é o elevador de carga")
	if elevador != null:
		_checar(elevador.direcao == ElevadorFase.Direcao.DESCE and elevador.cena_destino == FASE1
			and elevador.recebe_chegada, "ele desce para a oficina e recebe quem vem dela")
		var oficina: Node = (load(FASE1) as PackedScene).instantiate()
		var sobe := oficina.get_node_or_null("Entrada/ElevadorPatio") as ElevadorFase
		_checar(sobe != null and sobe.cena_destino == CORREDOR and sobe.direcao == ElevadorFase.Direcao.SOBE,
			"o elevador da oficina sobe para este corredor (e não mais direto para o pátio)")
		_checar(sobe != null and sobe.tag_destino == elevador.tag_aqui and elevador.tag_destino == sobe.tag_aqui,
			"as tags das duas pontas se cruzam")
		oficina.free()
		# A cabine encostada no canto, em pé no piso, dentro do quadro.
		var cabine_de := elevador.global_position.x - ElevadorFase.CABINE_LARGURA * 0.5 * elevador.escala_da_arte
		_checar(cabine_de >= limites.position.x and cabine_de < limites.position.x + 40.0,
			"a cabine fica encostada no canto esquerdo (começa em x = %.0f)" % cabine_de)
		var chao_dela := _chao_abaixo(cena, elevador.global_position + Vector2(140.0, -120.0))
		_checar(not chao_dela.is_empty() and absf((chao_dela.position as Vector2).y - elevador.global_position.y) <= 6.0,
			"com a origem na linha do piso")
		# O piso: atrás da Cacau enquanto ela anda, e na frente da cabine e
		# da passageira só durante a viagem (o poço).
		_checar(estrutura.z_index < player.z_index, "a Cacau pisa NA FRENTE do piso")
		_checar(elevador.cenario_do_poco == estrutura, "o piso é o cenário do poço do elevador")
		elevador._esconder_no_poco(true)
		_checar(estrutura.z_index > elevador.z_index and estrutura.z_index > player.z_index,
			"na viagem o piso desenha NA FRENTE da cabine e da Cacau (é o que esconde o elevador no poço)")
		_checar(frente != null and frente.z_index > estrutura.z_index, "e as pilastras da frente continuam por cima de tudo")
		elevador._esconder_no_poco(false)
		_checar(estrutura.z_index < player.z_index, "e volta para trás dela com a cabine parada")

	# A ponta direita: a passagem para o pátio.
	var saida := cena.get_node_or_null("SaidaPatio") as PassagemDeCena
	_checar(saida != null and saida.cena_destino == PATIO and saida.tag_destino == "entrada"
		and saida.tag_aqui == "fundo" and saida.sentido > 0.0,
		"a ponta do fundo é uma passagem para o pátio, saindo pela direita")
	if saida != null:
		_checar(saida.global_position.x < fim.x and saida.global_position.x > fim.x - 80.0,
			"a linha fica no fim do corredor, ainda dentro do quadro (x = %.0f de %.0f)" % [saida.global_position.x, fim.x])
		var depois := _chao_abaixo(cena, Vector2(fim.x + 300.0, player.global_position.y))
		_checar(not depois.is_empty(), "e o piso continua depois dela, para a Cacau sair andando")


func _testar_patio() -> void:
	print("\n--- O PÁTIO: GRAMA DESDE A BEIRADA ---")
	await _abrir(PATIO)
	await _segundos(0.4)
	var cena := get_tree().current_scene
	var sobras := PackedStringArray()
	for nome in ["Elevador", "PortaMetalMacarico", "fundo"]:
		if cena.get_node_or_null(nome) != null:
			sobras.append(nome)
	var cabines := cena.find_children("*", "Node2D", true, false).filter(func(n: Node) -> bool: return n is ElevadorFase)
	var portas_de_metal := cena.find_children("*", "StaticBody2D", true, false).filter(
		func(n: Node) -> bool: return n is PortaMetalMacarico)
	_checar(sobras.is_empty() and cabines.is_empty() and portas_de_metal.is_empty() and _portas_da(cena).is_empty(),
		"o prédio do elevador saiu: nem cabine, nem porta, nem parede %s" % [sobras])

	# O chão: só grama (e os tufos de mato), em todo o Terreno.
	var terreno := cena.get_node("Terreno") as TileMapLayer
	var estranhas := {}
	var menor_x := 1 << 30
	for celula in terreno.get_used_cells():
		var fonte := terreno.get_cell_source_id(celula)
		menor_x = mini(menor_x, celula.x)
		if fonte != GRAMA and fonte != TUFOS:
			estranhas[fonte] = true
	_checar(estranhas.is_empty(), "o chão do pátio é só grama (outras fontes de tile: %s)" % [estranhas.keys()])
	# Nenhuma outra camada de tiles além do terreno e da árvore dele.
	var outras := PackedStringArray()
	for camada: TileMapLayer in cena.find_children("*", "TileMapLayer", true, false):
		if camada != terreno and not terreno.is_ancestor_of(camada) and not camada.get_used_cells().is_empty():
			outras.append(camada.name)
	_checar(outras.is_empty(), "e não sobrou outra camada de cenário pintada %s" % [outras])

	# A ponta esquerda: a passagem do corredor.
	var limites := cena.get_node("LimitesDaCamera") as ReferenceRect
	var passagem := cena.get_node_or_null("PassagemCorredor") as PassagemDeCena
	_checar(passagem != null and passagem.cena_destino == CORREDOR and passagem.tag_destino == "fundo"
		and passagem.tag_aqui == "entrada" and passagem.sentido < 0.0,
		"a ponta esquerda é uma passagem: recebe quem vem do corredor e devolve ao fundo dele")
	if passagem == null:
		return
	var linha := passagem.global_position.x
	_checar(linha > limites.position.x and linha < limites.position.x + 80.0
		and linha - passagem.recuo_fora_da_tela < limites.position.x - 30.0,
		"a linha fica na beirada esquerda do quadro e ela vem de fora dele (x = %.0f, nasce em %.0f)"
		% [linha, linha - passagem.recuo_fora_da_tela])
	var fora := _chao_abaixo(cena, Vector2(limites.position.x - 300.0, passagem.global_position.y))
	_checar(not fora.is_empty() and menor_x * 32.0 <= limites.position.x - 300.0,
		"a grama continua para a esquerda da linha, para ela chegar e sair andando")
	if not fora.is_empty():
		var altura := (fora.position as Vector2).y - 40.0
		var espaco := (cena as Node2D).get_world_2d().direct_space_state
		var raio := PhysicsRayQueryParameters2D.create(Vector2(linha + 100.0, altura),
			Vector2(limites.position.x - 300.0, altura), 1, [_player().get_rid()])
		_checar(espaco.intersect_ray(raio).is_empty(), "e não há parede nenhuma nesse caminho")
	# Grama embaixo dela em todo o caminho da chegada.
	var so_grama := true
	for x: float in [linha - passagem.recuo_fora_da_tela, linha, linha + passagem.distancia_entrada]:
		var chao := _chao_abaixo(cena, Vector2(x, passagem.global_position.y))
		so_grama = so_grama and not chao.is_empty() and chao.collider == terreno \
			and SomPassos.superficie_do_chao(chao.collider, chao.position) == &"grama"
	_checar(so_grama, "ela chega pisando em grama, de fora do quadro até onde para")


func _testar_viagem() -> void:
	print("\n--- OFICINA -> CORREDOR (de elevador) ---")
	# Como a partida do elevador da oficina deixa o mundo antes de trocar de cena.
	ElevadorFase.chegando_de_elevador = true
	ElevadorFase.tag_chegada = "patio"
	FadeTela.chegada_escura = true
	get_tree().change_scene_to_file(CORREDOR)
	await _esperar_cena(CORREDOR)
	await _conferir_chegada_de_elevador(get_tree().current_scene.get_node("Elevador"),
		"chegou no corredor de elevador", ElevadorFase.Direcao.DESCE)
	var player := _player()
	var camera := player.get_node("Camera2D") as Camera2D
	_checar(absf(camera.get_screen_center_position().x - (camera.limit_left + 1600.0 / camera.zoom.x / 2.0)) < 2.0,
		"   com a câmera enquadrada na ponta do elevador")
	_checar(_objetivos().titulos() == PackedStringArray(["CARBONO"]),
		"a lista de objetivos mostra a trilha do carbono (%s)" % [_objetivos().titulos()])

	print("\n--- CORREDOR -> PÁTIO (andando) ---")
	# Correndo de verdade: desce a rampa da cabine, atravessa o corredor e a
	# cena troca sozinha no fundo.
	var saida := get_tree().current_scene.get_node("SaidaPatio") as PassagemDeCena
	var sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var partida := player.global_position.x
	Input.action_press(&"ui_right")
	var quadros := 0
	while not saida._saindo and quadros < 900:
		await get_tree().process_frame
		quadros += 1
	Input.action_release(&"ui_right")
	_checar(saida._saindo, "correu da cabine até o fundo e a passagem disparou (%.1f s, %.0f px)"
		% [quadros / 60.0, saida.global_position.x - partida])
	await _quadros(12)
	_checar(is_instance_valid(player) and not player.pode_se_mover and sprite.animation == &"run"
		and player.global_position.x > saida.global_position.x + 20.0,
		"   sem apertar nada: ela segue correndo para fora enquanto a tela apaga")

	await _esperar_cena(PATIO)
	var entrada := get_tree().current_scene.get_node("PassagemCorredor") as PassagemDeCena
	player = _player()
	sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	camera = player.get_node("Camera2D") as Camera2D
	_checar(entrada._chegando and not player.pode_se_mover, "chegou no pátio pela ponta esquerda, ainda sem o controle")
	var mais_a_esquerda := INF
	var entrou_correndo := false
	for i in 400:
		await get_tree().process_frame
		if not entrada._chegando:
			break
		mais_a_esquerda = minf(mais_a_esquerda, player.global_position.x)
		entrou_correndo = entrou_correndo or (sprite.animation == &"run" and not sprite.flip_h)
	_checar(mais_a_esquerda < camera.limit_left - 20.0,
		"   ela vem de fora do quadro (nasceu em x = %.0f, a tela começa em %d)" % [mais_a_esquerda, camera.limit_left])
	_checar(not entrada._chegando and entrou_correndo, "   e entra andando para a direita")
	var parada := entrada.global_position.x + entrada.distancia_entrada
	_checar(absf(player.global_position.x - parada) < 4.0 and player.is_on_floor(),
		"   parou dentro do pátio, no chão (x = %.0f, esperado %.0f)" % [player.global_position.x, parada])
	var chao := _chao_abaixo(get_tree().current_scene, player.global_position)
	_checar(not chao.is_empty() and SomPassos.superficie_do_chao(chao.collider, chao.position) == &"grama",
		"   pisando na grama")
	_checar(player.visible and player.pode_se_mover and sprite.animation == &"idle", "   com o controle de volta")
	_checar(not PassagemDeCena.PORTA.chegando_por_porta and Progresso.spawn_tag == "",
		"   a tag da viagem foi consumida")
	await _segundos(1.0)
	_checar(get_tree().current_scene.scene_file_path == PATIO and not entrada._saindo,
		"parada ali, ela não é mandada de volta para o corredor")

	print("\n--- PÁTIO -> CORREDOR (andando) ---")
	Input.action_press(&"ui_left")
	quadros = 0
	while not entrada._saindo and quadros < 300:
		await get_tree().process_frame
		quadros += 1
	Input.action_release(&"ui_left")
	_checar(entrada._saindo, "andou para a esquerda e a passagem do pátio disparou (%.1f s)" % (quadros / 60.0))
	await _esperar_cena(CORREDOR)
	saida = get_tree().current_scene.get_node("SaidaPatio") as PassagemDeCena
	player = _player()
	sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_checar(saida._chegando and not player.pode_se_mover, "voltou pelo fundo do corredor, ainda sem o controle")
	for i in 300:
		await get_tree().process_frame
		if not saida._chegando:
			break
	_checar(not saida._chegando and player.pode_se_mover
		and absf(player.global_position.x - (saida.global_position.x - saida.distancia_entrada)) < 4.0,
		"entrou andando e parou dentro do corredor, com o controle (x = %.0f)" % player.global_position.x)
	var elevador := get_tree().current_scene.get_node("Elevador") as ElevadorFase
	_checar(elevador._estado == ElevadorFase.Estado.PARADO and elevador._sprite.frame == 0
		and is_zero_approx(elevador._cabine.position.y),
		"   a cabine espera aberta no lugar dela (quem chegou foi a passagem, não o elevador)")

	print("\n--- CORREDOR -> OFICINA (de elevador) ---")
	# Corre até a cabine: a rampa é subível.
	Input.action_press(&"ui_left")
	quadros = 0
	while quadros < 900 and not (elevador._jogador_dentro and absf(player.global_position.x - elevador.global_position.x) < 30.0):
		await get_tree().process_frame
		quadros += 1
	Input.action_release(&"ui_left")
	_checar(elevador._jogador_dentro, "correu de volta e subiu na cabine pela rampa (%.1f s)" % (quadros / 60.0))
	await _segundos(0.3)
	camera = player.get_node("Camera2D") as Camera2D
	var enquadramento := camera.get_screen_center_position()
	elevador._partir()
	var desceu := 0.0
	var camera_parada := true
	for i in 900:
		await get_tree().process_frame
		if get_tree().current_scene == null or get_tree().current_scene.scene_file_path != CORREDOR:
			break
		if is_instance_valid(elevador):
			desceu = maxf(desceu, elevador._cabine.position.y)
			if elevador._cabine.position.y > 1.0:
				camera_parada = camera_parada and camera.get_screen_center_position().distance_to(enquadramento) < 2.0
	_checar(desceu > DESCIDA_MINIMA, "a cabine fechou e desceu pelo poço com ela (%.0f px)" % desceu)
	_checar(camera_parada, "   e a câmera não foi atrás")
	await _esperar_cena(FASE1)
	await _conferir_chegada_de_elevador(get_tree().current_scene.get_node("Entrada/ElevadorPatio"),
		"chegou na oficina dentro do elevador de lá", ElevadorFase.Direcao.SOBE)

	print("\n--- OFICINA -> CORREDOR (subindo de verdade) ---")
	await _segundos(0.3)
	(get_tree().current_scene.get_node("Entrada/ElevadorPatio") as ElevadorFase)._partir()
	await _esperar_cena(CORREDOR)
	await _conferir_chegada_de_elevador(get_tree().current_scene.get_node("Elevador"),
		"da oficina, o elevador dá no corredor", ElevadorFase.Direcao.DESCE)
	_checar(not ElevadorFase.chegando_de_elevador and ElevadorFase.tag_chegada == "",
		"   e a chegada foi consumida")


## A cena acabou de abrir com alguém chegando de elevador: confere a chegada
## inteira — fechada e no poço, sobe (ou desce) até o lugar, abre, devolve o
## controle, e ela fica em pé dentro da cabine.
func _conferir_chegada_de_elevador(elevador: ElevadorFase, descricao: String, direcao: int) -> void:
	var player := _player()
	_checar(elevador != null and elevador.direcao == direcao and elevador._estado == ElevadorFase.Estado.EM_USO
		and not player.pode_se_mover, descricao + ", ainda sem o controle")
	if elevador == null:
		return
	var no_poco: float = elevador._cabine.position.y
	_checar(elevador._sprite.frame == elevador._ultimo_quadro()
		and (no_poco > 100.0 if direcao == ElevadorFase.Direcao.DESCE else no_poco < -100.0),
		"   a cabine vem fechada, do fundo do poço (%.0f px)" % no_poco)
	for i in 900:
		await get_tree().process_frame
		if elevador._estado == ElevadorFase.Estado.PARADO:
			break
	_checar(elevador._estado == ElevadorFase.Estado.PARADO and is_zero_approx(elevador._cabine.position.y)
		and elevador._sprite.frame == 0, "   ela chega ao lugar e a rampa abre")
	_checar(player.pode_se_mover and not player.animacao_controlada_externamente, "   o controle volta")
	await _segundos(0.3)
	var estrado: float = elevador.global_position.y + elevador._altura_do_piso()
	_checar(absf(player.global_position.x - elevador.global_position.x) < 2.0 and player.is_on_floor()
		and absf(player.global_position.y + ATE_A_SOLA - estrado) < 3.0,
		"   e ela está em pé dentro da cabine (pé em %.0f, estrado em %.0f)" % [player.global_position.y + ATE_A_SOLA, estrado])


# ─────────────────────────────────────────────────────────────

## As portas de uma cena (as de porta_simulador.gd).
func _portas_da(cena: Node) -> Array:
	var script_porta := load(SCRIPT_PORTA)
	return cena.find_children("*", "Area2D", true, false).filter(func(n: Node) -> bool:
		return n.get_script() == script_porta)


func _chao_abaixo(cena: Node, ponto: Vector2) -> Dictionary:
	var espaco := (cena as Node2D).get_world_2d().direct_space_state
	var raio := PhysicsRayQueryParameters2D.create(ponto, ponto + Vector2(0, 400), 1, [_player().get_rid()])
	return espaco.intersect_ray(raio)


func _objetivos() -> ObjetivosHUD:
	return get_tree().root.get_node("Objetivos/Lista") as ObjetivosHUD


func _esperar_cena(caminho: String) -> void:
	for i in 900:
		if get_tree().current_scene and get_tree().current_scene.scene_file_path == caminho:
			await _quadros(2)
			return
		await get_tree().process_frame
	_checar(false, "a cena %s não abriu" % caminho.get_file())


func _abrir(caminho: String) -> void:
	get_tree().change_scene_to_file(caminho)
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
