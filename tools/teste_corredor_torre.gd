extends Node

# Teste do corredor da torre (scenes/fases/corredor_torre.tscn) e da passagem
# de cena da ponta dele (scripts/fases/passagem_de_cena.gd):
#
#   godot --headless --fixed-fps 60 --path . res://tools/teste_corredor_torre.tscn
#
# (Roda como cena, e não com -s: o laboratório tem uma PortaFase, e o
# porta_fase.gd só compila com os autoloads já carregados.)
#
# Casos:
#   * a cena: a parede e o piso são os tiles do laboratório (os mesmos ids no
#     tileset_fases), o corredor é curto, a câmera fica travada na altura e o
#     piso soa como o do laboratório (metal);
#   * as pontas: a porta de dentro leva ao laboratório e recebe quem vem dele;
#     a ponta do fundo é uma PassagemDeCena para a fase 2, dentro do quadro, com
#     piso sobrando depois da linha;
#   * a ida: laboratório -> porta da torre -> sai pela porta do corredor ->
#     correndo de verdade até o fundo, a cena troca sozinha (sem apertar nada,
#     e ela continua correndo) -> sai pela porta da fase 2;
#   * a volta: a porta da fase 2 dá no fundo do corredor, ela entra andando
#     para a esquerda, para com o controle de volta e não é mandada de volta ->
#     corre até a porta -> laboratório, saindo pela porta da torre;
#   * dentro do corredor a lista de objetivos mostra a trilha do nitrogênio.

const LAB := "res://scenes/laboratório_(world_2).tscn"
const CORREDOR := "res://scenes/fases/corredor_torre.tscn"
const FASE2 := "res://scenes/fases/fase2_torre.tscn"
const MODELO := "res://scenes/fases/componentes/porta_modelo.tscn"
const TILESET := "res://assets/tilesets/tileset_fases.tres"

## Os ids do laboratório no tileset_fases: o industrial (piso) e a parede.
const FONTE_PISO := 13
const FONTE_PAREDE := 14
## Do centro da cápsula da Cacau até a sola.
const ATE_A_SOLA := 36.0
## Largura da tela em pixels do mundo (1600 / zoom 1,5 da câmera).
const LARGURA_DA_TELA := 1600.0 / 1.5

var _falhas := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# O teste sai de cena: as trocas de cena de verdade não o apagam.
	get_tree().current_scene = null
	_rodar()


func _rodar() -> void:
	EstadoMundo.revelou_dr_chico = true
	await _testar_cena()
	await _testar_ida_e_volta()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


# ─────────────────────────────────────────────────────────────

func _testar_cena() -> void:
	print("\n--- A CENA DO CORREDOR ---")
	await _abrir(CORREDOR)
	var cena := get_tree().current_scene
	_checar(cena is FaseBase, "a raiz é uma fase (FaseBase)")

	var fundo := cena.get_node("Fundo") as TileMapLayer
	var estrutura := cena.get_node("Estrutura") as TileMapLayer
	_checar(fundo.tile_set.resource_path == TILESET and estrutura.tile_set.resource_path == TILESET,
		"parede e piso saem do tileset_fases.tres")
	_checar(_fontes(fundo) == [FONTE_PAREDE], "a parede é o fundo do laboratório (fonte %s)" % [_fontes(fundo)])
	_checar(_fontes(estrutura) == [FONTE_PISO], "piso e teto são o industrial do laboratório (fonte %s)" % [_fontes(estrutura)])

	var limites := cena.get_node("LimitesDaCamera") as ReferenceRect
	var fim := limites.position + limites.size
	var camera := _player().get_node("Camera2D") as Camera2D
	_checar(camera.limit_bottom - camera.limit_top == 600, "a câmera fica travada na altura (uma tela: %d)"
		% (camera.limit_bottom - camera.limit_top))
	_checar(limites.size.x > LARGURA_DA_TELA and limites.size.x < LARGURA_DA_TELA * 1.6,
		"o corredor é curto: %.0f px, menos de uma tela e meia (%.0f)" % [limites.size.x, LARGURA_DA_TELA * 1.5])

	# O quadro inteiro está pintado: nenhum buraco na altura que a câmera mostra.
	var passo := 32.0
	var buracos := 0
	for x in range(0, int(limites.size.x / passo)):
		for y in range(int(floor(limites.position.y / passo)), int(ceil(fim.y / passo))):
			var celula := Vector2i(x, y)
			if fundo.get_cell_source_id(celula) == -1 and estrutura.get_cell_source_id(celula) == -1:
				buracos += 1
	_checar(buracos == 0, "sem buraco no cenário dentro do quadro (%d)" % buracos)

	# Ela fica em pé no piso, e o piso diz que é metal.
	var player := _player()
	await _segundos(0.4)
	var chao := _chao_abaixo(cena, player.global_position)
	_checar(player.is_on_floor() and not chao.is_empty()
		and absf(player.global_position.y + ATE_A_SOLA - (chao.position as Vector2).y) < 2.0,
		"a Cacau nasce em pé no piso (pé em %.0f)" % (player.global_position.y + ATE_A_SOLA))
	var superficie := SomPassos.superficie_do_chao(chao.collider, chao.position) if not chao.is_empty() else &""
	_checar(superficie == &"metal", "e o piso soa como o do laboratório (\"%s\")" % superficie)

	# As duas pontas.
	var porta := cena.get_node("PortaLab")
	_checar(porta.scene_file_path == MODELO, "a porta de dentro é a porta modelo")
	_checar(porta.cena_destino == LAB and porta.tag_destino == "volta_da_torre"
		and porta.recebe_chegada and porta.tag_aqui == "entrada",
		"ela leva ao laboratório e recebe quem vem dele")
	var sola := (porta.get_node("PontoDeSaida") as Marker2D).global_position.y + ATE_A_SOLA
	var chao_da_porta := _chao_abaixo(cena, (porta as Node2D).global_position)
	_checar(not chao_da_porta.is_empty() and absf(sola - (chao_da_porta.position as Vector2).y) <= 5.0,
		"   em pé no chão (vão em %.0f)" % sola)

	var saida := cena.get_node("SaidaTorre") as PassagemDeCena
	_checar(saida != null and saida.cena_destino == FASE2 and saida.tag_destino == "entrada"
		and saida.tag_aqui == "fundo" and saida.sentido > 0.0,
		"a ponta do fundo é uma passagem para a fase 2, saindo pela direita")
	_checar(saida.global_position.x > porta.global_position.x + 600.0
		and saida.global_position.x < fim.x and saida.global_position.x > fim.x - 80.0,
		"a linha fica no fim do corredor, ainda dentro do quadro (x = %.0f de %.0f)"
		% [saida.global_position.x, fim.x])
	var depois := _chao_abaixo(cena, Vector2(fim.x + 300.0, player.global_position.y))
	_checar(not depois.is_empty(), "e o piso continua depois dela, para a Cacau sair andando")

	# Na fase 2, a porta manda para o fundo do corredor; no laboratório, para a porta.
	await _abrir(FASE2)
	var hub := get_tree().current_scene.get_node("PortaHub")
	_checar(hub.cena_destino == CORREDOR and hub.tag_destino == "fundo",
		"a porta da fase 2 dá no fundo do corredor")
	await _abrir(LAB)
	var torre := get_tree().current_scene.get_node("PortaTorre")
	_checar(torre.cena_destino == CORREDOR and torre.tag_destino == "entrada",
		"a porta da torre, no laboratório, dá na porta do corredor")
	await _segundos(1.5)  # o laboratório termina de clarear


func _testar_ida_e_volta() -> void:
	print("\n--- LABORATÓRIO -> CORREDOR -> FASE 2 ---")
	await _abrir(LAB)
	await _usar(get_tree().current_scene.get_node("PortaTorre"))
	await _esperar_cena(CORREDOR)
	var porta := get_tree().current_scene.get_node("PortaLab")
	await _conferir_saida(porta, "chegou no corredor saindo pela porta dele")
	_checar(not (_player().get_node("AnimatedSprite2D") as AnimatedSprite2D).flip_h,
		"   virada para o fundo do corredor")
	_checar(_objetivos().titulos() == PackedStringArray(["NITROGÊNIO"]),
		"a lista de objetivos mostra a trilha do nitrogênio (%s)" % [_objetivos().titulos()])

	# Correndo de verdade até o fundo: nada no caminho, e a cena troca sozinha.
	var saida := get_tree().current_scene.get_node("SaidaTorre") as PassagemDeCena
	var linha := saida.global_position.x
	var player := _player()
	var sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var partida := player.global_position.x
	Input.action_press(&"ui_right")
	var quadros := 0
	while not saida._saindo and quadros < 600:
		await get_tree().process_frame
		quadros += 1
	Input.action_release(&"ui_right")
	_checar(saida._saindo, "correu da porta até o fundo e a passagem disparou (%.1f s, %.0f px)"
		% [quadros / 60.0, linha - partida])
	_checar(quadros / 60.0 < 5.0, "   em menos de 5 s de corrida")
	await _quadros(12)
	_checar(is_instance_valid(player) and not player.pode_se_mover and sprite.animation == &"run"
		and player.global_position.x > linha + 20.0,
		"   sem apertar nada: ela segue correndo para fora enquanto a tela apaga")

	await _esperar_cena(FASE2)
	await _conferir_saida(get_tree().current_scene.get_node("PortaHub"), "chegou na fase 2 saindo pela PortaHub")
	_checar(Progresso.spawn_tag == "", "   e a tag da viagem foi consumida")

	print("\n--- FASE 2 -> CORREDOR -> LABORATÓRIO ---")
	await _usar(get_tree().current_scene.get_node("PortaHub"))
	await _esperar_cena(CORREDOR)
	saida = get_tree().current_scene.get_node("SaidaTorre") as PassagemDeCena
	player = _player()
	sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_checar(saida._chegando and not player.pode_se_mover, "voltou pelo fundo do corredor, ainda sem o controle")
	var viu_correndo := false
	for i in 300:
		await get_tree().process_frame
		viu_correndo = viu_correndo or (sprite.animation == &"run" and sprite.flip_h)
		if not saida._chegando:
			break
	var parada := saida.global_position.x - saida.distancia_entrada
	_checar(not saida._chegando and viu_correndo, "entrou andando para a esquerda")
	_checar(absf(player.global_position.x - parada) < 4.0 and player.is_on_floor(),
		"   e parou dentro do corredor, no chão (x = %.0f, esperado %.0f)" % [player.global_position.x, parada])
	_checar(player.visible and player.pode_se_mover and sprite.animation == &"idle",
		"   com o controle de volta")
	var camera := player.get_node("Camera2D") as Camera2D
	_checar(absf(camera.get_screen_center_position().x - (camera.limit_right - LARGURA_DA_TELA / 2.0)) < 2.0,
		"   e a câmera já enquadrada no fundo do corredor")
	_checar(not PassagemDeCena.PORTA.chegando_por_porta and Progresso.spawn_tag == "",
		"   a chegada foi consumida (nenhuma porta vai achar que é com ela)")
	var porta_lab := get_tree().current_scene.get_node("PortaLab")
	_checar(not porta_lab._ocupada and (porta_lab.get_node("SpritePorta") as AnimatedSprite2D).animation == &"fechada",
		"   a porta de dentro ficou quieta")
	await _segundos(1.0)
	_checar(get_tree().current_scene.scene_file_path == CORREDOR and not saida._saindo,
		"parada ali, ela não é mandada de volta para a fase 2")

	# Corre até a porta e volta ao laboratório.
	var x_da_porta: float = (porta_lab as Node2D).global_position.x
	Input.action_press(&"ui_left")
	quadros = 0
	while player.global_position.x > x_da_porta + 30.0 and quadros < 600:
		await get_tree().process_frame
		quadros += 1
	Input.action_release(&"ui_left")
	_checar(player.global_position.x <= x_da_porta + 30.0, "correu de volta até a porta (%.1f s)" % (quadros / 60.0))
	await _usar(porta_lab)
	await _esperar_cena(LAB)
	await _conferir_saida(get_tree().current_scene.get_node("PortaTorre"),
		"voltou ao laboratório saindo pela porta da torre")


# ─────────────────────────────────────────────────────────────

## As fontes (ids do TileSet) usadas numa camada, em ordem.
func _fontes(camada: TileMapLayer) -> Array:
	var fontes := {}
	for celula in camada.get_used_cells():
		fontes[camada.get_cell_source_id(celula)] = true
	var lista := fontes.keys()
	lista.sort()
	return lista


func _chao_abaixo(cena: Node, ponto: Vector2) -> Dictionary:
	var espaco := (cena as Node2D).get_world_2d().direct_space_state
	var raio := PhysicsRayQueryParameters2D.create(ponto, ponto + Vector2(0, 400), 1, [_player().get_rid()])
	return espaco.intersect_ray(raio)


func _objetivos() -> ObjetivosHUD:
	return get_tree().root.get_node("Objetivos/Lista") as ObjetivosHUD


## A Cacau, parada um pouco ao lado do vão, aperta para cima.
func _usar(porta: Node) -> void:
	var player := _player()
	await _segundos(0.3)
	player.global_position = (porta.get_node("PontoDeSaida") as Marker2D).global_position + Vector2(60, -2)
	player.velocity = Vector2.ZERO
	porta._player = player
	porta._player_dentro = true
	porta._usar_porta()


## Espera a sequência de chegada acabar e confere onde ela terminou.
func _conferir_saida(porta: Node, descricao: String) -> void:
	var sprite := porta.get_node("SpritePorta") as AnimatedSprite2D
	var abriu := false
	for i in 400:
		await get_tree().process_frame
		abriu = abriu or sprite.animation == &"abrindo"
		if abriu and not porta._ocupada:
			break
	var player := _player()
	var saida := (porta.get_node("PontoDeSaida") as Marker2D).global_position
	_checar(abriu and not porta._ocupada, descricao)
	_checar(player.visible and player.pode_se_mover and sprite.animation == &"fechada",
		"   ela aparece, anda e a porta fecha atrás dela")
	_checar(player.global_position.distance_to(saida) < 8.0,
		"   na frente da porta (%s, vão em %s)" % [player.global_position.round(), saida.round()])


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
