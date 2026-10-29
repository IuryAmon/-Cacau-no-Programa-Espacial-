extends Node

# Teste das lajes vazadas da fase 2 — a faixa de cornija do Buildings.png na
# versão one-way (alternativa 1 dos tiles 0..3 da linha 0, fonte 15 do
# tileset_fases):
#
#   godot --headless --fixed-fps 60 --path . res://tools/teste_lajes_vazadas.tscn
#
# Em cada laje — a faixa do meio da sala do compressor, a faixa do meio e o
# telhado do prédio do compressor na rua, e o telhado da casinha da escada no
# telhado da torre:
#   * a faixa está numa camada que colide, na versão vazada — o Terreno na
#     sala e no telhado, a camada Lajes na rua (lá o Terreno é só a grama);
#   * a Cacau, caindo de cima, pisa nela;
#   * vindo de baixo, passa por ela (o pulo atravessa);
#   * em pé nela, S + espaço a atravessa para baixo (o "pulo para baixo" do
#     player.gd) — sem isso a faixa da sala, que vai de parede a parede,
#     prenderia a Cacau lá em cima.
# E a versão sólida (alternativa 0) continua sólida: o teto e as paredes de
# faixa girada da sala.

const FONTE_PREDIOS := 15
const VAZADA := 1
## Do centro da cápsula da Cacau até a sola (e até o alto da cabeça).
const ATE_A_SOLA := 36.0

const LAJES := [
	{"cena": MissaoNitrogenio.CENA_COMPRESSOR, "nome": "a faixa do meio da sala do compressor",
		"camada": "Terreno", "fileira": 7, "colunas": Vector2i(1, 41)},
	{"cena": MissaoNitrogenio.CENA_RUA, "nome": "a faixa do meio do prédio do compressor, na rua",
		"camada": "Lajes", "fileira": 9, "colunas": Vector2i(6, 26)},
	{"cena": MissaoNitrogenio.CENA_RUA, "nome": "o telhado do prédio do compressor",
		"camada": "Lajes", "fileira": 2, "colunas": Vector2i(6, 26)},
	{"cena": MissaoNitrogenio.CENA_TELHADO, "nome": "o telhado da casinha da escada",
		"camada": "Terreno", "fileira": 9, "colunas": Vector2i(3, 12)},
]

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
	for laje: Dictionary in LAJES:
		await _testar_laje(laje)
	await _testar_solidas()
	MissaoNitrogenio.esquecer()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


# ─────────────────────────────────────────────────────────────

func _testar_laje(laje: Dictionary) -> void:
	print("\n--- %s ---" % str(laje.nome).to_upper())
	await _abrir(laje.cena)
	var cena := get_tree().current_scene
	var terreno := cena.get_node(NodePath(laje.camada)) as TileMapLayer
	var colunas: Vector2i = laje.colunas
	var fileira: int = laje.fileira
	var vazadas := 0
	for x in range(colunas.x, colunas.y + 1):
		var celula := Vector2i(x, fileira)
		var dados := terreno.get_cell_tile_data(celula)
		if terreno.get_cell_source_id(celula) == FONTE_PREDIOS and terreno.get_cell_alternative_tile(celula) == VAZADA \
				and dados != null and dados.is_collision_polygon_one_way(0, 0):
			vazadas += 1
	var total := colunas.y - colunas.x + 1
	_checar(vazadas == total, "a faixa está na camada %s, vazada (%d de %d tiles)" % [laje.camada, vazadas, total])

	var lado := float(terreno.tile_set.tile_size.y) * terreno.global_scale.y
	var topo := fileira * lado
	var x_meio := (colunas.x + colunas.y + 1) * 0.5 * lado
	var player := _player()
	player.pode_se_mover = true

	# Caindo de cima, pisa.
	player.global_position = Vector2(x_meio, topo - ATE_A_SOLA - 20.0)
	player.velocity = Vector2.ZERO
	await _fisica(40)
	var sola := player.global_position.y + ATE_A_SOLA
	_checar(player.is_on_floor() and absf(sola - topo) < 2.0,
		"caindo de cima, ela pisa nela (sola em %.0f, laje em %.0f)" % [sola, topo])

	# Vindo de baixo, passa: o movimento para cima não bate em nada.
	var embaixo := Transform2D(0.0, Vector2(x_meio, topo + lado + ATE_A_SOLA + 8.0))
	_checar(not player.test_move(embaixo, Vector2(0.0, -(lado + ATE_A_SOLA * 2.0 + 24.0))),
		"vindo de baixo, o pulo passa por ela")

	# Em pé nela, S + espaço atravessa para baixo.
	player.global_position = Vector2(x_meio, topo - ATE_A_SOLA - 4.0)
	player.velocity = Vector2.ZERO
	await _fisica(20)
	var em_cima := player.is_on_floor()
	await get_tree().physics_frame
	Input.action_press("ui_down")
	Input.action_press("jump")
	await _fisica(2)
	Input.action_release("jump")
	Input.action_release("ui_down")
	await _fisica(25)
	sola = player.global_position.y + ATE_A_SOLA
	_checar(em_cima and sola > topo + lado,
		"em pé nela, S + espaço atravessa para baixo (sola em %.0f, embaixo da laje em %.0f)" % [sola, topo + lado])


func _testar_solidas() -> void:
	print("\n--- A FAIXA SÓLIDA CONTINUA SÓLIDA (SALA DO COMPRESSOR) ---")
	await _abrir(MissaoNitrogenio.CENA_COMPRESSOR)
	var cena := get_tree().current_scene
	var terreno := cena.get_node("Terreno") as TileMapLayer
	var lado := float(terreno.tile_set.tile_size.y) * terreno.global_scale.y
	var player := _player()
	# O teto (faixa sólida na fileira 1): de baixo, bate.
	var sob_o_teto := Transform2D(0.0, Vector2(20.5 * lado, 2.0 * lado + ATE_A_SOLA + 8.0))
	_checar(player.test_move(sob_o_teto, Vector2(0.0, -40.0)), "o teto segura o pulo")
	# As paredes de faixa girada (colunas 0 e 42): de lado, batem.
	var perto_da_esquerda := Transform2D(0.0, Vector2(1.0 * lado + 24.0, 12.0 * lado))
	var perto_da_direita := Transform2D(0.0, Vector2(42.0 * lado - 24.0, 12.0 * lado))
	_checar(player.test_move(perto_da_esquerda, Vector2(-60.0, 0.0))
		and player.test_move(perto_da_direita, Vector2(60.0, 0.0)), "as paredes seguram dos dois lados")


# ─────────────────────────────────────────────────────────────

func _abrir(caminho: String) -> void:
	get_tree().change_scene_to_file(caminho)
	for i in 900:
		await get_tree().process_frame
		var cena := get_tree().current_scene
		if cena and cena.scene_file_path == caminho and cena.get_node_or_null("Player"):
			break
	# A tela clareia e a porta de chegada (se houver) devolve o controle.
	await _fisica(60)


func _player() -> CharacterBody2D:
	return get_tree().current_scene.get_node("Player") as CharacterBody2D


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1
