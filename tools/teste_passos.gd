extends Node

# Teste dos passos da Cacau (scripts/som_passos.gd):
#
#   * a player.tscn traz o SomPassos ligado ao sprite, com a grama (14
#     variações de passo grama.mp3), o concreto (10 de passo Concreto.mp3) e
#     o metal (4 de passo metal.mp3);
#   * world1: grama no começo; concreto do x 6110 em diante e nas tábuas da
#     ponte (x 3575..4666), e em nenhum outro tile;
#   * fase 1 (oficina): o piso todo é concreto; as plataformas laranja que
#     caem, a plataforma móvel, a de viagem e a do guincho são metal;
#   * laboratório (world 2): todo o chão é metal;
#   * fase 1.2: grama no pátio, concreto no piso do laboratório, e o
#     industrial (ainda sem som) fica mudo;
#   * correndo de verdade, sai um passo para cada quadro 1 e 7 da "run" — um a
#     cada 6 quadros, 0,25 s —, um tiquinho antes de o pé tocar (o
#     "adiantamento"), e nenhum no ar nem com a pose parada do dash;
#   * a grama soa 3 dB abaixo do concreto.
#
#   godot --headless --path . res://tools/teste_passos.tscn

const PLAYER := "res://scenes/player.tscn"
const MUNDO := "res://scenes/world1.tscn"
const FASE1 := "res://scenes/fases/fase1_oficina.tscn"
const FASE := "res://scenes/fases/fase1_2_exterior.tscn"
const LAB := "res://scenes/laboratório_(world_2).tscn"
const CHAO_DO_PATIO := 512.0
## Do centro da cápsula até a sola (72 de altura, centrada na origem).
const ATE_A_SOLA := 36.0

var _falhas := 0
var _passos: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame

	_testar_player()
	await _testar_world1()
	await _testar_fase1_oficina()
	await _testar_laboratorio()
	await _testar_fase_superficies()
	await _testar_corrida_na_grama()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


# ─────────────────────────────────────────────────────────────

func _testar_player() -> void:
	print("\n--- A PLAYER.TSCN ---")
	var player := (load(PLAYER) as PackedScene).instantiate()
	var som := player.get_node_or_null("SomPassos") as SomPassos
	_checar(som != null, "o Player tem o nó SomPassos")
	if som == null:
		player.free()
		return
	_checar(som.sprite == player.get_node("AnimatedSprite2D"), "ligado ao AnimatedSprite2D da Cacau")
	_checar(som.quadros_de_passo == PackedInt32Array([1, 7]), "pisa nos quadros 1 e 7")
	_checar(som.sprite.sprite_frames.get_frame_count(&"run") == 12, "a \"run\" tem os 12 quadros")
	var grama := som.sons_por_superficie.get(&"grama") as AudioStreamRandomizer
	_checar_variacoes(som, &"grama", 14)
	_checar_variacoes(som, &"concreto", 10)
	_checar_variacoes(som, &"metal", 4)
	_checar(som.volume_por_superficie.get(&"grama", 0.0) < 0.0, "a grama soa mais baixo que o concreto")
	_checar(som.adiantamento > 0.0 and som.adiantamento < 1.0 / 24.0,
		"o passo sai adiantado, menos de um quadro (%.3f s)" % som.adiantamento)
	player.free()


func _checar_variacoes(som: SomPassos, superficie: StringName, quantas: int) -> void:
	var banco := som.sons_por_superficie.get(superficie) as AudioStreamRandomizer
	_checar(banco != null, "%s tem som" % superficie)
	if banco == null:
		return
	_checar(banco.streams_count == quantas, "com as %d variações (%d)" % [quantas, banco.streams_count])
	var todas := true
	for i in banco.streams_count:
		todas = todas and banco.get_stream(i) is AudioStreamWAV
	_checar(todas, "todas carregam")
	_checar(banco.playback_mode == AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS,
		"sorteia sem repetir a anterior")


func _testar_world1() -> void:
	print("\n--- WORLD1 ---")
	var mundo := await _abrir(MUNDO)
	var player := mundo.get_node("Player") as CharacterBody2D
	var som := player.get_node("SomPassos") as SomPassos

	# Onde a Cacau nasce, com a física de verdade: ela cai e assenta na grama.
	await _esperar(1.5)
	_checar(player.is_on_floor(), "no começo do world1 ela está no chão")
	_checar(_pisar(som) == [&"grama"], "e o chão do começo é grama")
	_checar(som.stream == som.sons_por_superficie[&"grama"], "o som que ficou é o da grama")
	var volume_grama := som.volume_db

	# As faixas combinadas, conferidas em TODO tile com colisão do world1:
	# concreto do x 6110 em diante, nas tábuas da ponte (camada "à frente",
	# x 3575..4666) e nas do mirante da árvore (camada Detalhes, x ~5600, dos
	# degraus ao topo); em nenhum outro lugar.
	var errados: Array[String] = []
	var concreto := 0
	var grama := 0
	for camada: TileMapLayer in mundo.find_children("*", "TileMapLayer", true, false):
		if camada.tile_set == null or camada.tile_set.get_physics_layers_count() == 0:
			continue
		for celula in camada.get_used_cells():
			var dados := camada.get_cell_tile_data(celula)
			if dados == null or dados.get_collision_polygons_count(0) == 0:
				continue
			var topo := _topo_da_celula(camada, celula)
			var ponte := camada.name == "à frente" and topo.x >= 3575.0 and topo.x <= 4666.0
			var mirante := camada.name == "Detalhes" and topo.x >= 5350.0 and topo.x <= 5850.0
			var esperado_concreto := topo.x >= 6110.0 or ponte or mirante
			var achou := SomPassos.superficie_do_chao(camada, topo)
			concreto += int(achou == &"concreto")
			grama += int(achou == &"grama")
			if (achou == &"concreto") != esperado_concreto:
				errados.append("%s %s x=%.0f -> \"%s\"" % [camada.name, celula, topo.x, achou])
	_checar(errados.is_empty(), "concreto só do x 6110 em diante, na ponte e no mirante %s" % [errados.slice(0, 5)])
	print("        tiles com colisão: %d de concreto, %d de grama" % [concreto, grama])

	# Pisando de verdade: no meio da ponte e no piso do laboratório.
	player.set_physics_process(false)
	player.global_position = Vector2(4100, 326 - ATE_A_SOLA - 0.5)
	await get_tree().physics_frame
	_checar(_pisar(som) == [&"concreto"], "no meio da ponte, concreto")
	_checar(som.stream == som.sons_por_superficie[&"concreto"], "e o som troca para o do concreto")
	_checar(is_equal_approx(som.volume_db - volume_grama, 3.0),
		"a grama soa 3 dB abaixo do concreto (%.1f x %.1f dB)" % [volume_grama, som.volume_db])

	# O mirante: o degrau mais baixo da árvore e o topo lá em cima.
	var detalhes := mundo.get_node("Chão/Detalhes") as TileMapLayer
	var tabuas: Array[Vector2i] = []
	for c in detalhes.get_used_cells():
		var x := _topo_da_celula(detalhes, c).x
		var dados := detalhes.get_cell_tile_data(c)
		if x >= 5350.0 and x <= 5850.0 and dados and dados.get_collision_polygons_count(0) > 0:
			tabuas.append(c)
	tabuas.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	_checar(tabuas.size() == 28, "o mirante tem as 28 tábuas (%d)" % tabuas.size())
	if not tabuas.is_empty():
		for par in [["no topo do mirante", tabuas.front()], ["no degrau mais baixo da árvore", tabuas.back()]]:
			player.global_position = _em_cima_de(detalhes, par[1])
			await get_tree().physics_frame
			_checar(_pisar(som) == [&"concreto"], "%s (y = %.0f), concreto" % [par[0], player.global_position.y])
	var chao := mundo.get_node("Chão") as TileMapLayer
	var celula := _chao_descoberto(chao, 12)
	_checar(celula != Vector2i(-99999, -99999), "achou o piso do laboratório descoberto")
	player.global_position = _em_cima_de(chao, celula)
	await get_tree().physics_frame
	_checar(_pisar(som) == [&"concreto"], "no laboratório (x = %.0f), concreto" % player.global_position.x)
	await _fechar(mundo)


func _testar_fase1_oficina() -> void:
	print("\n--- FASE 1 (OFICINA) ---")
	var fase := await _abrir(FASE1)
	var player := fase.get_node("Player") as CharacterBody2D
	var som := player.get_node("SomPassos") as SomPassos
	await _esperar(1.5)
	_checar(player.is_on_floor(), "no começo da fase ela está no chão")
	_checar(_pisar(som) == [&"concreto"], "e o chão é concreto")

	# O piso inteiro é concreto. As plataformas laranja (Plataformas.png) são
	# metal, e no jogo nem são tiles: o PlataformasQueCaem as troca por corpos
	# que caem, e o corpo leva a superfície dos tiles de que saiu.
	var errados := 0
	for camada: TileMapLayer in [fase.get_node("Terreno"), fase.get_node("Cenário")]:
		for celula in camada.get_used_cells():
			var dados := camada.get_cell_tile_data(celula)
			if dados == null or dados.get_collision_polygons_count(0) == 0:
				continue
			var achou := SomPassos.superficie_do_chao(camada, _topo_da_celula(camada, celula))
			var textura := (camada.tile_set.get_source(camada.get_cell_source_id(celula)) as TileSetAtlasSource).texture
			var esperado := &""
			if textura.resource_path.ends_with("level_tileset.png"):
				esperado = &"concreto"
			elif textura.resource_path.ends_with("Plataformas.png"):
				esperado = &"metal"
			errados += int(achou != esperado)
	_checar(errados == 0, "todo o piso do laboratório é concreto (%d fora do lugar)" % errados)
	var tileset := (fase.get_node("Terreno") as TileMapLayer).tile_set
	var plataformas := tileset.get_source(0) as TileSetAtlasSource
	var metal := 0
	for i in plataformas.get_tiles_count():
		var dados := plataformas.get_tile_data(plataformas.get_tile_id(i), 0)
		metal += int(dados.get_custom_data(SomPassos.CAMADA_DO_TILESET) == "metal")
	_checar(plataformas.texture.resource_path.ends_with("Plataformas.png") and metal == plataformas.get_tiles_count(),
		"as plataformas laranja são metal (%d de %d tiles)" % [metal, plataformas.get_tiles_count()])

	# As que caem já viraram corpos: cada uma de metal, e pisar nela soa metal.
	player.set_physics_process(false)
	var que_caem := fase.find_children("*", "PlataformaQueCai", true, false)
	_checar(que_caem.size() > 0, "as plataformas que caem viraram corpos (%d)" % que_caem.size())
	var corpos_metal := que_caem.filter(func(p: Node) -> bool:
		return p.get_node("Corpo").get_meta(SomPassos.META_DO_CORPO, &"") == &"metal")
	_checar(corpos_metal.size() == que_caem.size(), "todas de metal (%d de %d)" % [corpos_metal.size(), que_caem.size()])
	if not que_caem.is_empty():
		await _checar_metal_em_cima(player, som, que_caem[0].get_node("Corpo"), "numa plataforma que cai")

	# As que andam: a móvel, a de viagem e a do guincho (plataforma.tscn).
	for par in [["PlataformaMovel", "na plataforma móvel"], ["PlataformaDeViagem", "na plataforma de viagem"],
			["ElevadorCarga/PlataformaCarga/platform", "na plataforma do guincho"]]:
		await _checar_metal_em_cima(player, som, fase.get_node(par[0]), par[1])
	await _fechar(fase)


func _testar_laboratorio() -> void:
	print("\n--- LABORATÓRIO (WORLD 2) ---")
	# Sem a cutscene da revelação: ela dispara se a Cacau cair na área dela.
	var revelou := EstadoMundo.revelou_dr_chico
	EstadoMundo.revelou_dr_chico = true
	var lab := await _abrir(LAB)
	var player := lab.get_node("Player") as CharacterBody2D
	var som := player.get_node("SomPassos") as SomPassos
	player.set_physics_process(false)

	# Todo tile com colisão, nas duas camadas, é metal.
	var errados: Array[String] = []
	var metal := 0
	for camada: TileMapLayer in lab.find_children("*", "TileMapLayer", true, false):
		for celula in camada.get_used_cells():
			var dados := camada.get_cell_tile_data(celula)
			if dados == null or dados.get_collision_polygons_count(0) == 0:
				continue
			var achou := SomPassos.superficie_do_chao(camada, _topo_da_celula(camada, celula))
			metal += int(achou == &"metal")
			if achou != &"metal":
				errados.append("%s %s -> \"%s\"" % [camada.name, celula, achou])
	_checar(errados.is_empty() and metal > 0, "todo o chão do laboratório é metal (%d tiles) %s" % [metal, errados.slice(0, 5)])

	var chao := lab.get_node("TileMap/Chão") as TileMapLayer
	_checar(_ficar_sobre_o_tile(player, som, chao, 13), "achou o piso do laboratório à mostra")
	await get_tree().physics_frame
	_checar(_pisar(som) == [&"metal"], "no piso do laboratório (x = %.0f), metal" % player.global_position.x)
	_checar(som.stream == som.sons_por_superficie[&"metal"], "com o som do metal")
	await _fechar(lab)
	EstadoMundo.revelou_dr_chico = revelou


func _testar_fase_superficies() -> void:
	print("\n--- FASE 1.2: GRAMA E LABORATÓRIO ---")
	var fase := await _abrir(FASE)
	var player := fase.get_node("Player") as CharacterBody2D
	var som := player.get_node("SomPassos") as SomPassos
	player.set_physics_process(false)

	player.global_position = Vector2(600, CHAO_DO_PATIO - ATE_A_SOLA)
	await get_tree().physics_frame
	_checar(_pisar(som) == [&"grama"], "no pátio, grama")

	# Lá no alto do pátio, longe de qualquer chão.
	player.global_position = Vector2(700, 200)
	await get_tree().physics_frame
	_checar(_pisar(som).is_empty(), "no ar, nenhum passo")

	# O piso do laboratório, à esquerda do pátio (tiles -3..6).
	var terreno := fase.get_node("Terreno") as TileMapLayer
	# Quase todo ele fica debaixo da cabine do elevador e da porta de metal:
	# vale um tile em que o pé encosta no próprio piso.
	_checar(terreno.get_cell_source_id(Vector2i(3, 16)) == 12, "o piso da esquerda é o do laboratório")
	_checar(_ficar_sobre_o_tile(player, som, terreno, 12), "achou um pedaço do piso do laboratório à mostra")
	_checar(_pisar(som) == [&"concreto"], "no piso do laboratório (x = %.0f), concreto" % player.global_position.x)
	_checar(som.stream == som.sons_por_superficie[&"concreto"], "com o som do concreto")

	# Chão que não diz o que é fica mudo: o industrial das fases 2, 3 e final,
	# que aqui só aparece na marquise lá em cima.
	var industrial := _chao_descoberto(terreno, 13)
	_checar(industrial != Vector2i(-99999, -99999), "achou o industrial descoberto")
	player.global_position = _em_cima_de(terreno, industrial)
	await get_tree().physics_frame
	som.stream = null
	_checar(_pisar(som) == [&""], "o industrial das fases não diz o que é")
	_checar(som.stream == null, "e fica mudo")
	await _fechar(fase)


func _testar_corrida_na_grama() -> void:
	print("\n--- CORRENDO NA GRAMA ---")
	var fase := await _abrir(FASE)
	var player := fase.get_node("Player") as CharacterBody2D
	var som := player.get_node("SomPassos") as SomPassos
	var sprite := som.sprite
	player.global_position = Vector2(300, CHAO_DO_PATIO - ATE_A_SOLA)
	await _esperar(0.3)
	_checar(player.is_on_floor(), "parada no chão do pátio")

	_passos.clear()
	som.passo_dado.connect(_anotar_passo.bind(sprite))
	Input.action_press(&"ui_right")
	await _esperar(1.3)
	Input.action_release(&"ui_right")

	var quadros := _passos.map(func(p: Dictionary) -> int: return p.quadro)
	var antecedencias := _passos.map(func(p: Dictionary) -> String: return "%.0f ms" % (p.falta * 1000.0))
	print("        passos para os quadros ", quadros, ", saindo antes do pé: ", antecedencias)
	_checar(_passos.size() >= 4, "saíram passos correndo (%d em 1,3 s)" % _passos.size())
	_checar(quadros.all(func(q: int) -> bool: return q == 1 or q == 7), "só para os quadros 1 e 7")
	_checar(_passos.all(func(p: Dictionary) -> bool: return p.falta >= 0.0 and p.falta <= som.adiantamento + 0.001),
		"cada um sai antes do pé tocar, no máximo %.0f ms antes" % (som.adiantamento * 1000.0))
	var alternando := true
	var ritmo := true
	for i in range(1, _passos.size()):
		alternando = alternando and quadros[i] != quadros[i - 1]
		var intervalo: float = _passos[i].tempo - _passos[i - 1].tempo
		ritmo = ritmo and absf(intervalo - 6.0 / 24.0) < 0.05
	_checar(alternando, "um pé depois do outro")
	_checar(ritmo, "um passo a cada 6 quadros da animação (0,25 s)")
	_checar(_passos.all(func(p: Dictionary) -> bool: return p.superficie == &"grama"), "todos na grama")
	_checar(player.global_position.x > 600.0, "e ela andou de verdade (x = %.0f)" % player.global_position.x)

	# A pose do dash: "run" parada num quadro de passo não é passo.
	_passos.clear()
	sprite.play(&"run")
	sprite.pause()
	sprite.frame = 1
	await get_tree().process_frame
	_checar(_passos.is_empty(), "\"run\" pausada no quadro 1 não pisa")
	await _fechar(fase)


# ─────────────────────────────────────────────────────────────

## Anota para qual quadro de passo o som saiu e quanto faltava para a
## animação chegar nele (negativo se já tinha chegado).
func _anotar_passo(superficie: StringName, sprite: AnimatedSprite2D) -> void:
	var som := sprite.get_parent().get_node("SomPassos") as SomPassos
	var quadro := sprite.frame
	var falta := 0.0
	if quadro in som.quadros_de_passo:
		var fps := sprite.sprite_frames.get_animation_speed(sprite.animation)
		falta = -sprite.frame_progress / fps
	else:
		var proximo := som._proximo_pe()
		quadro = proximo[0]
		falta = proximo[1]
	_passos.append({
		"superficie": superficie,
		"quadro": quadro,
		"falta": falta,
		"tempo": Time.get_ticks_usec() / 1_000_000.0,
	})


## Chama um passo na mão e devolve as superfícies que ele anunciou.
func _pisar(som: SomPassos) -> Array[StringName]:
	var ouvidas: Array[StringName] = []
	var anotar := func(superficie: StringName) -> void: ouvidas.append(superficie)
	som.passo_dado.connect(anotar)
	som.pisar()
	som.passo_dado.disconnect(anotar)
	return ouvidas


## Põe a Cacau em pé no topo de um corpo (onde um raio que desce pelo meio
## dele bate primeiro) e confere que o passo ali é de metal.
func _checar_metal_em_cima(player: CharacterBody2D, som: SomPassos, corpo: CollisionObject2D, onde: String) -> void:
	var de := corpo.global_position + Vector2(0, -60)
	var raio := PhysicsRayQueryParameters2D.create(de, de + Vector2(0, 120), player.collision_mask, [player.get_rid()])
	var achou := player.get_world_2d().direct_space_state.intersect_ray(raio)
	if achou.is_empty() or achou.collider != corpo:
		_checar(false, "%s: não achei o topo dela" % onde)
		return
	player.global_position = achou.position - Vector2(0, ATE_A_SOLA + 0.5)
	await get_tree().physics_frame
	_checar(_pisar(som) == [&"metal"], "%s, metal" % onde)


## Uma célula da fonte `fonte` com colisão e nada por cima em nenhuma camada.
func _chao_descoberto(chao: TileMapLayer, fonte: int) -> Vector2i:
	var camadas: Array[TileMapLayer] = [chao]
	for filho in chao.find_children("*", "TileMapLayer", true, false):
		camadas.append(filho)
	for celula in chao.get_used_cells_by_id(fonte):
		var dados := chao.get_cell_tile_data(celula)
		if dados == null or dados.get_collision_polygons_count(0) == 0:
			continue
		var livre := true
		for camada in camadas:
			for acima in range(1, 4):
				livre = livre and camada.get_cell_source_id(celula + Vector2i(0, -acima)) == -1
		if livre:
			return celula
	return Vector2i(-99999, -99999)


## Põe a Cacau em pé sobre um tile da fonte `fonte` em que o raio do pé bate
## no próprio TileMapLayer — e não numa cabine ou porta parada em cima dele.
func _ficar_sobre_o_tile(player: Node2D, som: SomPassos, camada: TileMapLayer, fonte: int) -> bool:
	for celula in camada.get_used_cells_by_id(fonte):
		var dados := camada.get_cell_tile_data(celula)
		if dados == null or dados.get_collision_polygons_count(0) == 0:
			continue
		if camada.get_cell_source_id(celula + Vector2i.UP) != -1:
			continue
		player.global_position = _em_cima_de(camada, celula)
		if som._chao_sob_os_pes().get("collider") == camada:
			return true
	return false


## A borda de cima da célula, no mundo — onde o raio do pé bateria.
func _topo_da_celula(chao: TileMapLayer, celula: Vector2i) -> Vector2:
	var meio := Vector2(chao.tile_set.tile_size) * 0.5
	return chao.to_global(chao.map_to_local(celula) - Vector2(0, meio.y))


## Posição do corpo para a sola ficar em cima da célula.
func _em_cima_de(chao: TileMapLayer, celula: Vector2i) -> Vector2:
	return _topo_da_celula(chao, celula) - Vector2(0, ATE_A_SOLA + 0.5)


func _abrir(caminho: String) -> Node:
	var cena: Node = (load(caminho) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(cena)
	await _quadros(2)
	await get_tree().physics_frame
	return cena


func _fechar(cena: Node) -> void:
	cena.queue_free()
	await _quadros(2)


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos, true).timeout
