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
#   * a cena: parede e piso pintados com o tileset_fases, sem buraco no quadro;
#     a colisão do piso e do teto é a dos próprios tiles, a câmera fica mais
#     perto que nas outras fases e o piso diz que chão é (o som do passo);
#   * a camada da frente (scripts/fases/paralaxe_da_frente.gd): cada pilar dela
#     é a gêmea de uma pilastra do cenário, pintada no mesmo lugar. Em silhueta
#     preta, as gêmeas desenham por cima da Cacau e do cenário, maiores que eles
#     e a partir do centro da tela — cruzam o meio da tela no x em que foram
#     pintadas (por cima da pilastra delas), andam mais depressa que a parede,
#     cabem inteiras na tela, do capitel no alto à base embaixo, e não tapam nem
#     a chegada pela porta nem a saída;
#   * as pontas: a porta de dentro leva ao laboratório e recebe quem vem dele;
#     a ponta do fundo é uma PassagemDeCena para a fase 2, dentro do quadro, com
#     piso sobrando depois da linha;
#   * a fase 2 não tem porta: a ponta ESQUERDA dela é outra PassagemDeCena, na
#     beirada do quadro, com chão sobrando para fora e sem parede no caminho;
#   * a ida: laboratório -> porta da torre -> sai pela porta do corredor ->
#     correndo de verdade até o fundo, a cena troca sozinha (sem apertar nada,
#     e ela continua correndo) -> na fase 2 ela vem de fora do quadro e entra
#     andando pela esquerda, para com o controle de volta e não é mandada de
#     volta;
#   * a volta: andando para a esquerda na fase 2, cruzou a linha e a cena troca
#     sozinha -> no corredor ela entra andando pelo fundo, para com o controle
#     de volta e não é mandada de volta -> corre até a porta -> laboratório,
#     saindo pela porta da torre;
#   * dentro do corredor a lista de objetivos mostra a trilha do nitrogênio.

const LAB := "res://scenes/laboratório_(world_2).tscn"
const CORREDOR := "res://scenes/fases/corredor_torre.tscn"
const FASE2 := "res://scenes/fases/fase2_torre.tscn"
const MODELO := "res://scenes/fases/componentes/porta_modelo.tscn"
const TILESET := "res://assets/tilesets/tileset_fases.tres"
const SCRIPT_PORTA := "res://scripts/porta_simulador.gd"

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
	await _testar_camada_da_frente()
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
	# (Que tiles são é com quem pinta a cena: o corredor foi repintado à mão.)
	_checar(not _fontes(fundo).is_empty() and not _fontes(estrutura).is_empty(), "parede e piso estão pintados")
	_checar(estrutura.collision_enabled and cena.get_node_or_null("Colisoes/Piso") == null
		and cena.get_node_or_null("Colisoes/Teto") == null,
		"a colisão do piso e do teto é a dos próprios tiles")

	var limites := cena.get_node("LimitesDaCamera") as ReferenceRect
	var fim := limites.position + limites.size
	var camera := _player().get_node("Camera2D") as Camera2D
	_checar(camera.limit_bottom - camera.limit_top <= 600, "o corredor tem no máximo uma tela de altura (%d)"
		% (camera.limit_bottom - camera.limit_top))
	_checar(camera.zoom.x > 1.5 and is_equal_approx(camera.zoom.x, camera.zoom.y),
		"e a câmera fica mais perto aqui do que nas outras fases (zoom %.2f)" % camera.zoom.x)
	_checar(limites.size.x > LARGURA_DA_TELA and limites.size.x < LARGURA_DA_TELA * 3.0,
		"o corredor é um corredor: %.0f px, entre uma e três telas (%.0f)" % [limites.size.x, LARGURA_DA_TELA])

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
	_checar(superficie != &"", "e o piso diz que chão é, para o som do passo (\"%s\")" % superficie)

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

	# A fase 2 não tem porta de volta: a ponta esquerda dela é outra passagem,
	# que recebe quem vem do corredor e devolve ao fundo dele. (As portas que ela
	# tem são as dos prédios da rua, e nenhuma leva ao corredor nem ao lab.)
	await _abrir(FASE2)
	await _segundos(0.3)
	var fase2 := get_tree().current_scene
	var entrada := fase2.get_node_or_null("PassagemCorredor") as PassagemDeCena
	var de_volta := _portas_da(fase2).filter(func(p: Node) -> bool:
		return p.cena_destino == CORREDOR or p.cena_destino == LAB)
	_checar(entrada != null and fase2.get_node_or_null("PortaHub") == null and de_volta.is_empty(),
		"a fase 2 não tem porta de volta: a ponta esquerda dela é uma passagem")
	if entrada != null:
		_checar(entrada.cena_destino == CORREDOR and entrada.tag_destino == "fundo"
			and entrada.tag_aqui == "entrada" and entrada.sentido < 0.0,
			"   que recebe quem vem do corredor e devolve ao fundo dele, saindo pela esquerda")
		var quadro := fase2.get_node("LimitesDaCamera") as ReferenceRect
		var linha2 := entrada.global_position.x
		_checar(linha2 > quadro.position.x and linha2 < quadro.position.x + 80.0
			and linha2 - entrada.recuo_fora_da_tela < quadro.position.x - 30.0,
			"   a linha fica na beirada esquerda do quadro e ela vem de fora dele (x = %.0f, nasce em %.0f)"
			% [linha2, linha2 - entrada.recuo_fora_da_tela])
		var fora := _chao_abaixo(fase2, Vector2(quadro.position.x - 300.0, entrada.global_position.y))
		_checar(not fora.is_empty(), "   o chão continua para a esquerda da linha, para ela chegar e sair andando")
		if not fora.is_empty():
			var altura := (fora.position as Vector2).y - 40.0
			var espaco := (fase2 as Node2D).get_world_2d().direct_space_state
			var raio := PhysicsRayQueryParameters2D.create(Vector2(linha2 + 100.0, altura),
				Vector2(quadro.position.x - 300.0, altura), 1, [_player().get_rid()])
			_checar(espaco.intersect_ray(raio).is_empty(), "   e não há parede nenhuma nesse caminho")
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
	while not saida._saindo and quadros < 900:
		await get_tree().process_frame
		quadros += 1
	Input.action_release(&"ui_right")
	_checar(saida._saindo, "correu da porta até o fundo e a passagem disparou (%.1f s, %.0f px)"
		% [quadros / 60.0, linha - partida])
	_checar(quadros / 60.0 < 9.0, "   em menos de 9 s de corrida")
	await _quadros(12)
	_checar(is_instance_valid(player) and not player.pode_se_mover and sprite.animation == &"run"
		and player.global_position.x > linha + 20.0,
		"   sem apertar nada: ela segue correndo para fora enquanto a tela apaga")

	await _esperar_cena(FASE2)
	# Na fase 2 ela não sai de porta nenhuma: vem de fora do quadro e entra
	# andando pela ponta esquerda.
	var entrada := get_tree().current_scene.get_node("PassagemCorredor") as PassagemDeCena
	player = _player()
	sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var camera2 := player.get_node("Camera2D") as Camera2D
	_checar(entrada._chegando and not player.pode_se_mover, "chegou na fase 2 pela ponta esquerda, ainda sem o controle")
	var mais_a_esquerda := INF
	var entrou_correndo := false
	for i in 400:
		await get_tree().process_frame
		if not entrada._chegando:
			break
		mais_a_esquerda = minf(mais_a_esquerda, player.global_position.x)
		entrou_correndo = entrou_correndo or (sprite.animation == &"run" and not sprite.flip_h)
	_checar(mais_a_esquerda < camera2.limit_left - 20.0,
		"   ela vem de fora do quadro (nasceu em x = %.0f, a tela começa em %d)" % [mais_a_esquerda, camera2.limit_left])
	_checar(not entrada._chegando and entrou_correndo, "   e entra andando para a direita")
	var parada2 := entrada.global_position.x + entrada.distancia_entrada
	_checar(absf(player.global_position.x - parada2) < 4.0 and player.is_on_floor(),
		"   parou dentro da fase, no chão (x = %.0f, esperado %.0f)" % [player.global_position.x, parada2])
	_checar(player.visible and player.pode_se_mover and sprite.animation == &"idle", "   com o controle de volta")
	_checar(absf(camera2.get_screen_center_position().x - (camera2.limit_left + 1600.0 / camera2.zoom.x / 2.0)) < 2.0,
		"   e a câmera já enquadrada na ponta esquerda da fase")
	_checar(not PassagemDeCena.PORTA.chegando_por_porta and Progresso.spawn_tag == "",
		"   a tag da viagem foi consumida")
	await _segundos(1.0)
	_checar(get_tree().current_scene.scene_file_path == FASE2 and not entrada._saindo,
		"parada ali, ela não é mandada de volta para o corredor")

	print("\n--- FASE 2 -> CORREDOR -> LABORATÓRIO ---")
	# Andando de verdade para a esquerda: cruzou a linha, a cena troca sozinha.
	Input.action_press(&"ui_left")
	quadros = 0
	while not entrada._saindo and quadros < 300:
		await get_tree().process_frame
		quadros += 1
	Input.action_release(&"ui_left")
	_checar(entrada._saindo, "andou para a esquerda e a passagem da fase 2 disparou (%.1f s)" % (quadros / 60.0))
	await _quadros(12)
	_checar(is_instance_valid(player) and not player.pode_se_mover and sprite.animation == &"run"
		and player.global_position.x < entrada.global_position.x - 20.0,
		"   sem apertar nada: ela segue correndo para fora enquanto a tela apaga")
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
	_checar(absf(camera.get_screen_center_position().x - (camera.limit_right - 1600.0 / camera.zoom.x / 2.0)) < 2.0,
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


func _testar_camada_da_frente() -> void:
	print("\n--- A CAMADA DA FRENTE (PARALAXE) ---")
	await _abrir(CORREDOR)
	var cena := get_tree().current_scene
	var frente := cena.get_node_or_null("ParalaxeDaFrente") as ParalaxeDaFrente
	var pilares := (frente.get_node_or_null("PilaresDaFrente") if frente else null) as TileMapLayer
	_checar(frente != null and pilares != null, "o corredor tem uma camada na frente, com os pilares dentro")
	if frente == null or pilares == null:
		return
	var grupos := _pilares_pintados(pilares)
	_checar(grupos.size() >= 2, "há pilares pintados nela (%d)" % grupos.size())
	# Cada pilar da frente é a gêmea de uma pilastra do cenário: está pintado
	# exatamente em cima de tiles da camada Pilares.
	var cenario := cena.get_node("Pilares") as TileMapLayer
	var soltas := 0
	for celula in pilares.get_used_cells():
		if cenario.get_cell_source_id(celula) == -1:
			soltas += 1
	_checar(soltas == 0 and pilares.scale == cenario.scale and pilares.position == cenario.position,
		"cada pilar da frente está em cima de uma pilastra do cenário (%d tiles fora do lugar)" % soltas)
	_checar(not pilares.collision_enabled and not pilares.navigation_enabled,
		"eles são só desenho: sem colisão nem navegação")

	# Por cima da Cacau e de todo o cenário; o HUD, as falas e a cortina são
	# CanvasLayer — outra camada, sempre acima do mundo.
	var player := _player()
	var mais_alto := _z_mais_alto(cena, frente)
	_checar(not frente.z_as_relative and frente.z_index > mais_alto,
		"ela desenha por cima da Cacau e do cenário (z %d, o resto vai até %d)" % [frente.z_index, mais_alto])
	_checar(_camada_de_tela(frente) == null and _camada_de_tela(player.get_node("CanvasLayer/HealthHUD")) != null,
		"e por baixo do HUD")

	# Preta — e sem gravar a cor em nó nenhum.
	_checar(frente.cor == Color.BLACK and frente._tinta_enviada.is_equal_approx(Color(0, 0, 0, 1)),
		"em silhueta preta, opaca no jogo")
	_checar(frente.modulate == Color.WHITE and pilares.modulate == Color.WHITE,
		"a tinta vai para o render: o modulate dos nós continua como está na cena")

	# Maior que o cenário, a partir do centro da tela. (Sem janela não há
	# quadro desenhado para chamar o encaixe: o teste chama na mão.)
	_checar(RenderingServer.frame_pre_draw.is_connected(frente._ao_desenhar),
		"ela se encaixa na câmera a cada quadro desenhado")
	var camera := player.get_node("Camera2D") as Camera2D
	(cena.get_node("SaidaTorre") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	player.set_physics_process(false)
	var s := frente.aproximacao
	var s_altura := frente.ampliacao().y
	var meia_tela := Vector2(1600.0, 900.0) / camera.zoom / 2.0
	var esquerda := camera.limit_left + meia_tela.x
	var direita := camera.limit_right - meia_tela.x

	# Um pilar que a câmera consegue pôr no meio da tela.
	var pilar: Dictionary = {}
	for grupo: Dictionary in grupos:
		if grupo.meio > esquerda + 200.0 and grupo.meio < direita - 200.0:
			pilar = grupo
			break
	_checar(not pilar.is_empty(), "pelo menos um pilar cruza o meio da tela no caminho")
	if pilar.is_empty():
		return

	var centro := await _levar_a_camera(player, camera, frente, pilar.meio)
	_checar(s > 1.0 and s_altura > 1.0 and frente.global_scale.is_equal_approx(Vector2(s, s_altura)),
		"os pilares aparecem maiores que o cenário (x%.2f na largura, x%.2f na altura)" % [s, s_altura])
	var no_meio: float = (frente.global_transform * Vector2(pilar.meio, centro.y)).x
	_checar(absf(centro.x - pilar.meio) < 0.5 and absf(no_meio - centro.x) < 0.5,
		"o pilar pintado em x = %.0f passa bem na frente dela quando a câmera está lá" % pilar.meio)
	var topo: float = (frente.global_transform * Vector2(pilar.meio, pilar.topo)).y
	var base: float = (frente.global_transform * Vector2(pilar.meio, pilar.base)).y
	_checar(topo <= centro.y - meia_tela.y and base >= centro.y + meia_tela.y,
		"e vai de cima a baixo do quadro (%.0f a %.0f, a tela é de %.0f a %.0f)"
		% [topo, base, centro.y - meia_tela.y, centro.y + meia_tela.y])
	# ...sem passar dele: a pilastra inteira aparece, do capitel à base. (Se a
	# faixa da câmera ou o zoom mudarem, a "aproximacao_vertical" da camada tem
	# de acompanhar: altura da tela ÷ altura da pilastra.)
	_checar(topo >= centro.y - meia_tela.y - 6.0 and base <= centro.y + meia_tela.y + 6.0,
		"a pilastra cabe inteira na tela: o capitel no alto, a base embaixo")
	_checar(absf((frente.global_transform * Vector2(pilar.direita, 0)).x
		- (frente.global_transform * Vector2(pilar.esquerda, 0)).x - (pilar.direita - pilar.esquerda) * s) < 0.5,
		"com %.0f px de largura em vez dos %.0f pintados" % [(pilar.direita - pilar.esquerda) * s, pilar.direita - pilar.esquerda])

	# A câmera anda 150 px: a parede anda 150 px na tela, o pilar anda s vezes isso.
	var passo := 150.0
	var antes: float = (frente.global_transform * Vector2(pilar.meio, centro.y)).x - centro.x
	var depois_centro := await _levar_a_camera(player, camera, frente, pilar.meio + passo)
	var depois: float = (frente.global_transform * Vector2(pilar.meio, centro.y)).x - depois_centro.x
	_checar(absf((antes - depois) - passo * s) < 0.5,
		"ela corre mais que o cenário: a câmera andou %.0f px, o pilar andou %.0f na tela" % [passo, antes - depois])

	# Nas duas pontas, nada na frente de quem chega pela porta nem da saída.
	var ponta := await _levar_a_camera(player, camera, frente, -1000.0)
	var chegada: float = (cena.get_node("PortaLab/PontoDeSaida") as Marker2D).global_position.x
	_checar(absf(ponta.x - esquerda) < 1.0 and not _tem_pilar_sobre(frente, grupos, chegada - 40.0, chegada + 40.0),
		"com a câmera na ponta da porta, nenhum pilar tapa a Cacau chegando")
	ponta = await _levar_a_camera(player, camera, frente, 100000.0)
	var linha: float = (cena.get_node("SaidaTorre") as Node2D).global_position.x
	_checar(absf(ponta.x - direita) < 1.0 and not _tem_pilar_sobre(frente, grupos, linha - 150.0, camera.limit_right),
		"e na ponta do fundo a saída fica limpa")


## Põe a câmera (centrada na Cacau) em [param x], encaixa a camada da frente e
## devolve o ponto do mundo que ficou no meio da tela.
func _levar_a_camera(player: CharacterBody2D, camera: Camera2D, frente: ParalaxeDaFrente, x: float) -> Vector2:
	player.global_position.x = x
	camera.reset_smoothing()
	await _quadros(2)
	frente.encaixar()
	return camera.get_screen_center_position()


## Os pilares pintados numa camada: cada grupo de colunas vizinhas, com o x do
## meio, as beiradas e o topo e a base, em pixels da cena (como no editor).
func _pilares_pintados(camada: TileMapLayer) -> Array[Dictionary]:
	var colunas := {}
	for celula in camada.get_used_cells():
		if not colunas.has(celula.x):
			colunas[celula.x] = Vector2i(celula.y, celula.y)
		else:
			var faixa: Vector2i = colunas[celula.x]
			colunas[celula.x] = Vector2i(mini(faixa.x, celula.y), maxi(faixa.y, celula.y))
	var xs := colunas.keys()
	xs.sort()
	var lado := Vector2(camada.tile_set.tile_size) * camada.scale
	var grupos: Array[Dictionary] = []
	var inicio := 0
	for i in range(1, xs.size() + 1):
		if i < xs.size() and xs[i] == xs[i - 1] + 1:
			continue
		var de: int = xs[inicio]
		var ate: int = xs[i - 1]
		var cima := 1 << 30
		var baixo := -(1 << 30)
		for x in range(de, ate + 1):
			cima = mini(cima, (colunas[x] as Vector2i).x)
			baixo = maxi(baixo, (colunas[x] as Vector2i).y)
		grupos.append({
			"esquerda": camada.position.x + de * lado.x,
			"direita": camada.position.x + (ate + 1) * lado.x,
			"meio": camada.position.x + (de + ate + 1) * lado.x / 2.0,
			"topo": camada.position.y + cima * lado.y,
			"base": camada.position.y + (baixo + 1) * lado.y,
		})
		inicio = i
	return grupos


## Algum pilar está sendo desenhado em cima da faixa de x pedida?
func _tem_pilar_sobre(frente: ParalaxeDaFrente, grupos: Array[Dictionary], de: float, ate: float) -> bool:
	for grupo: Dictionary in grupos:
		var esquerda: float = (frente.global_transform * Vector2(grupo.esquerda, 0)).x
		var direita: float = (frente.global_transform * Vector2(grupo.direita, 0)).x
		if direita > de and esquerda < ate:
			return true
	return false


## O z mais alto com que alguma coisa do mundo é desenhada (fora a camada da
## frente e o que mora em CanvasLayer).
func _z_mais_alto(no: Node, fora: Node) -> int:
	if no == fora or no is CanvasLayer:
		return -4096
	var z := -4096
	var item := no as CanvasItem
	if item != null:
		z = item.z_index
		var subindo := item
		while subindo.z_as_relative and subindo.get_parent() is CanvasItem:
			subindo = subindo.get_parent() as CanvasItem
			z += subindo.z_index
	for filho in no.get_children():
		z = maxi(z, _z_mais_alto(filho, fora))
	return z


## O CanvasLayer em que um nó mora (null = ele é do mundo).
func _camada_de_tela(no: Node) -> CanvasLayer:
	while no != null:
		if no is CanvasLayer:
			return no
		no = no.get_parent()
	return null


# ─────────────────────────────────────────────────────────────

## As portas de uma cena (as de porta_simulador.gd).
func _portas_da(cena: Node) -> Array:
	var script_porta := load(SCRIPT_PORTA)
	return cena.find_children("*", "Area2D", true, false).filter(func(n: Node) -> bool:
		return n.get_script() == script_porta)


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
