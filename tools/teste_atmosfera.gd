extends Node

# Teste do sistema de iluminação (scripts/luz/) e da cena do pôr do sol:
#
#   godot --headless --path . res://tools/teste_atmosfera.tscn
#
# Casos:
#   * os postes: todo poste pintado no world1 tem a altura do poste da
#     fase2_torre (8 tiles, na mesma sequência), e cada lâmpada pintada ganhou
#     uma luz em cima do tubo;
#   * o world1 abre ao ENTARDECER: sol no céu, lua fora, sem estrelas, postes
#     fracos, o fundo vestido com a luz do horário — e nada disso gravado nos
#     nós da cena;
#   * o pôr do sol: o sol desce, a fase chega ao crepúsculo, os postes ganham
#     força; virar a noite acende a lua e as estrelas e fica lembrado;
#   * a cena do mirante inteira, com o diálogo de verdade: a Cacau fica parada
#     do começo ao fim, a noite cai, o controle e o HUD voltam, e a cena não
#     repete;
#   * de volta ao world1 depois disso, a fase já abre de noite;
#   * o pátio (fase 1.2) e a fase2_torre são sempre noite, com a lua;
#   * a interface do mundo (balões, teclas, textos) fica fora da luz ambiente,
#     e a placa da estrada não;
#   * as luzes que seguem o horário (o laser) ficam apagadas numa cena sem
#     Atmosfera; o fogo da fornalha acende junto com ela.

const MUNDO := "res://scenes/world1.tscn"
const PATIO := "res://scenes/fases/fase1_2_exterior.tscn"
const TORRE := "res://scenes/fases/fase2_torre.tscn"
const ARTE_DO_POSTE := "Props-01.png"
## O mastro do poste da fase2_torre, de cima para baixo (linhas do atlas).
const MASTRO := [9, 10, 11, 12, 10, 11, 12, 13]

var _falhas := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# O teste sai de cena: as trocas de cena de verdade não o apagam.
	get_tree().current_scene = null
	_rodar()


func _rodar() -> void:
	_zerar_a_partida()
	await _testar_postes()
	await _testar_entardecer()
	await _testar_por_do_sol()
	await _testar_cena_do_mirante()
	await _testar_volta_de_noite()
	await _testar_fases_de_noite()
	await _testar_luzes_proprias()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _zerar_a_partida() -> void:
	EstadoMundo.anoiteceu = false
	EstadoMundo.viu_o_foguete = false
	EstadoMundo.revelou_dr_chico = false


# ─────────────────────────────────────────────────────────────

func _testar_postes() -> void:
	print("\n--- OS POSTES ---")
	await _abrir(TORRE)
	var da_torre := _mastros(get_tree().current_scene)
	_checar(da_torre.size() >= 1 and da_torre.all(func(m: Array) -> bool: return m == MASTRO),
		"o poste da fase2_torre é o modelo: %d tiles" % MASTRO.size())

	await _abrir(MUNDO)
	var cena := get_tree().current_scene
	var do_mundo := _mastros(cena)
	_checar(do_mundo.size() == 5, "o world1 tem 5 postes (%d)" % do_mundo.size())
	_checar(do_mundo.all(func(m: Array) -> bool: return m == MASTRO),
		"todos com a altura e a sequência do poste da torre %s" % [do_mundo.map(func(m: Array) -> int: return m.size())])

	# Cada lâmpada pintada (os 5 postes e a luminária do tronco) tem a sua luz.
	await _quadros(4)
	var postes := cena.get_node("PostesDeLuz") as PostesDeLuz
	_checar(postes != null and postes.quantidade() == 6,
		"cada lâmpada pintada ganhou uma luz (%d)" % (postes.quantidade() if postes else -1))
	var chao := cena.get_node("Chão") as TileMapLayer
	var no_tubo := 0
	for luz in postes.luzes():
		# O ponto da luz cai dentro de um tile de lâmpada, na linha do tubo.
		for camada: TileMapLayer in [chao, chao.get_node("Detalhes")]:
			var celula := camada.local_to_map(camada.to_local(luz.global_position))
			var fonte := camada.tile_set.get_source(camada.get_cell_source_id(celula)) as TileSetAtlasSource \
				if camada.get_cell_source_id(celula) >= 0 else null
			if fonte != null and fonte.texture.resource_path.get_file() == ARTE_DO_POSTE \
					and camada.get_cell_atlas_coords(celula).y == 9:
				no_tubo += 1
				break
	_checar(no_tubo == postes.quantidade(), "e cada luz está em cima do tubo da sua lâmpada (%d)" % no_tubo)
	_checar(postes.get_child_count() == 0 and postes.get_child_count(true) == postes.quantidade(),
		"as luzes são filhas internas: não entram no .tscn")


func _testar_entardecer() -> void:
	print("\n--- O WORLD1 ABRE AO ENTARDECER ---")
	await _abrir(MUNDO)
	var cena := get_tree().current_scene
	var atm := Atmosfera.da_cena(cena)
	_checar(atm != null and atm.momento == Atmosfera.Momento.ENTARDECER, "a fase começa ao entardecer")
	await _quadros(4)

	var sol := cena.get_node("BG/CamadaDoSol/Sol") as AstroPixel
	var lua := cena.get_node("BG/CamadaDaLua/Lua") as AstroPixel
	_checar(sol.tipo == AstroPixel.Tipo.SOL and is_equal_approx(sol.presenca(), 1.0), "o sol está no céu")
	_checar(lua.tipo == AstroPixel.Tipo.LUA and is_zero_approx(lua.presenca()), "a lua ainda não")
	_checar(atm.perfil_atual() == atm.entardecer and is_zero_approx(atm.perfil_atual().estrelas),
		"o perfil é o do entardecer, sem estrelas")
	_checar(atm.pode_anoitecer(), "e ainda dá para anoitecer")

	var ambiente := _ambiente(atm)
	_checar(ambiente != null and ambiente.color.is_equal_approx(atm.entardecer.ambiente),
		"o mundo está na luz ambiente do entardecer")
	_checar(atm._camadas.size() >= 5, "o fundo foi vestido com a luz do horário (%d desenhos)" % atm._camadas.size())
	_checar(_sem_material(cena.get_node("BG")), "sem gravar material nenhum nos nós do fundo")

	var postes := cena.get_node("PostesDeLuz") as PostesDeLuz
	var fracos := postes.luzes().all(func(l: LuzDePoste) -> bool:
		return is_equal_approx(l.intensidade, atm.entardecer.postes))
	_checar(fracos and atm.entardecer.postes < 0.6, "os postes estão acesos, mas fracos (%.2f)" % atm.entardecer.postes)

	# O céu e o sol sobem e descem com a serra do fundo; a lua fica presa na tela.
	var serra := cena.get_node("BG/4") as ParallaxLayer
	_checar((cena.get_node("BG/Ceu") as ParallaxLayer).motion_scale == Vector2(0, serra.motion_scale.y)
		and (cena.get_node("BG/CamadaDoSol") as ParallaxLayer).motion_scale == Vector2(0, serra.motion_scale.y),
		"o céu e o sol acompanham a altura da serra")
	_checar(cena.get_node("BG").get_child(0) is CeuPixel, "o céu é a camada mais do fundo")
	var nuvens := 0
	for filho in cena.get_node("BG").get_children():
		if filho is Nuvens:
			nuvens += (filho as Nuvens).quantidade
	_checar(nuvens >= 6, "há nuvens passando (%d)" % nuvens)


func _testar_por_do_sol() -> void:
	print("\n--- O PÔR DO SOL ---")
	_zerar_a_partida()
	await _abrir(MUNDO)
	var cena := get_tree().current_scene
	var atm := Atmosfera.da_cena(cena)
	await _quadros(4)
	var sol := cena.get_node("BG/CamadaDoSol/Sol") as AstroPixel
	var lua := cena.get_node("BG/CamadaDaLua/Lua") as AstroPixel
	var y_antes := sol.position.y
	var postes := cena.get_node("PostesDeLuz") as PostesDeLuz

	await atm.por_do_sol(0.5)
	_checar(is_equal_approx(sol.position.y, y_antes + atm.descida_do_sol),
		"o sol desceu %.0f px (de %.0f para %.0f)" % [atm.descida_do_sol, y_antes, sol.position.y])
	_checar(atm.momento == Atmosfera.Momento.CREPUSCULO and is_equal_approx(atm.andamento_do_por_do_sol(), 1.0),
		"a fase chegou ao crepúsculo")
	_checar(atm.perfil_atual().ambiente.is_equal_approx(atm.crepusculo.ambiente)
		and atm.perfil_atual().estrelas > 0.0, "com a luz do crepúsculo e as primeiras estrelas")
	_checar(postes.luzes().all(func(l: LuzDePoste) -> bool: return l.intensidade > atm.entardecer.postes),
		"os postes ganharam força")
	_checar(not EstadoMundo.anoiteceu, "ainda não é noite")

	atm.definir_momento(Atmosfera.Momento.NOITE)
	_checar(is_zero_approx(sol.presenca()) and is_equal_approx(lua.presenca(), 1.0), "virou a noite: sai o sol, entra a lua")
	_checar(is_equal_approx(atm.perfil_atual().estrelas, 1.0), "céu estrelado")
	_checar(_ambiente(atm).color.is_equal_approx(atm.noite.ambiente)
		and atm.noite.ambiente.get_luminance() < atm.entardecer.ambiente.get_luminance() * 0.7,
		"a luz ambiente caiu")
	_checar(postes.luzes().all(func(l: LuzDePoste) -> bool: return is_equal_approx(l.intensidade, 1.0)),
		"os postes estão com tudo")
	_checar(atm.noite.luz_do_fundo.get_luminance() < atm.entardecer.luz_do_fundo.get_luminance() * 0.5,
		"e o fundo mudou de tom")
	_checar(EstadoMundo.anoiteceu and not atm.pode_anoitecer(), "a noite ficou lembrada")


func _testar_cena_do_mirante() -> void:
	print("\n--- A CENA DO MIRANTE ---")
	_zerar_a_partida()
	await _abrir(MUNDO)
	var cena := get_tree().current_scene
	var atm := Atmosfera.da_cena(cena)
	var gatilho := cena.get_node("ColisaoCenaFoguete") as Area2D
	var player := _player()
	await _quadros(4)

	# A cena é a de verdade; só os tempos de olhar é que são encurtados.
	atm.duracao_do_por_do_sol = 0.8
	gatilho.respiro_antes_do_sol = 0.1
	gatilho.duracao_do_escurecer = 0.25
	gatilho.pausa_no_escuro = 0.1
	gatilho.duracao_do_clarear = 0.25

	var hud := player.get_node("CanvasLayer") as CanvasLayer
	var forma := gatilho.get_node("CollisionShape2D") as CollisionShape2D
	player.global_position = forma.global_position + Vector2(60, -30)
	player.velocity = Vector2.ZERO

	var falou := false
	var solta_cedo := false
	var hud_sumiu := false
	var viu_crepusculo := false
	var espera := 0.0
	while espera < 40.0 and not (EstadoMundo.anoiteceu and player.pode_se_mover):
		await get_tree().process_frame
		espera += get_process_delta_time()
		if Dialogic.current_timeline != null:
			falou = true
			Dialogic.Inputs.handle_input()
		if EstadoMundo.viu_o_foguete and not EstadoMundo.anoiteceu:
			# Entre a fala e a noite ela não pode sair andando.
			solta_cedo = solta_cedo or player.pode_se_mover
			hud_sumiu = hud_sumiu or not hud.visible
			viu_crepusculo = viu_crepusculo or atm.andamento_do_por_do_sol() > 0.5

	_checar(gatilho._disparado and falou, "pisar no mirante dispara a fala do foguete")
	_checar(EstadoMundo.viu_o_foguete, "ela viu o foguete")
	_checar(viu_crepusculo, "depois da fala o sol desceu")
	_checar(not solta_cedo, "a Cacau ficou parada do coração até a noite")
	_checar(hud_sumiu, "e o HUD saiu de cena enquanto isso")
	_checar(EstadoMundo.anoiteceu and atm.momento == Atmosfera.Momento.NOITE, "a noite caiu (%.1f s)" % espera)
	_checar(player.pode_se_mover and not player.segurar_apos_o_foguete, "o controle voltou")
	await _quadros(3)
	_checar(hud.visible and cena.get_node_or_null("FadeTela") == null, "o HUD voltou e a cortina saiu")

	# A cena não repete: nem pisando de novo, nem se a fase recarregar.
	player.global_position = forma.global_position + Vector2(60, -120)
	await _quadros(3)
	player.global_position = forma.global_position + Vector2(60, -30)
	await _segundos(0.6)
	_checar(player.pode_se_mover and Dialogic.current_timeline == null, "pisar de novo no mirante não repete a cena")


func _testar_volta_de_noite() -> void:
	print("\n--- DE VOLTA AO WORLD1, DEPOIS ---")
	# (EstadoMundo.anoiteceu e viu_o_foguete vêm do caso anterior.)
	await _abrir(MUNDO)
	var cena := get_tree().current_scene
	var atm := Atmosfera.da_cena(cena)
	await _quadros(4)
	_checar(atm.momento == Atmosfera.Momento.NOITE and atm.perfil_atual() == atm.noite, "a fase já abre de noite")
	var sol := cena.get_node("BG/CamadaDoSol/Sol") as AstroPixel
	_checar(is_zero_approx(sol.presenca()) and is_equal_approx(sol.descida, atm.descida_do_sol),
		"com o sol posto")
	_checar((cena.get_node("ColisaoCenaFoguete") as Area2D)._disparado, "e a cena do mirante desarmada")
	_checar(not atm.pode_anoitecer(), "não há outro pôr do sol para acontecer")


func _testar_fases_de_noite() -> void:
	print("\n--- O PÁTIO E A TORRE SÃO NOITE ---")
	_zerar_a_partida()
	for caminho: String in [PATIO, TORRE]:
		await _abrir(caminho)
		var cena := get_tree().current_scene
		var atm := Atmosfera.da_cena(cena)
		var nome := caminho.get_file().get_basename()
		await _quadros(4)
		_checar(atm != null and atm.momento == Atmosfera.Momento.NOITE and atm.perfil_atual() == atm.noite,
			"%s: é noite" % nome)
		var lua := cena.get_node_or_null("BG/CamadaDaLua/Lua") as AstroPixel
		_checar(lua != null and lua.tipo == AstroPixel.Tipo.LUA and is_equal_approx(lua.presenca(), 1.0)
			and lua.texture.resource_path == "res://assets/Area Aberta/Lua/2.png",
			"   quem ilumina é a lua (Lua/2.png)")
		var sois := 0
		for astro in get_tree().get_nodes_in_group(Atmosfera.GRUPO_DE_CLIENTES):
			if astro is AstroPixel and (astro as AstroPixel).tipo == AstroPixel.Tipo.SOL:
				sois += 1
		_checar(sois == 0, "   sem sol nenhum")
		_checar(cena.get_node("BG").get_child(0) is CeuPixel and is_equal_approx(atm.perfil_atual().estrelas, 1.0),
			"   céu estrelado")
		_checar(cena.get_node_or_null("PostesDeLuz") is PostesDeLuz, "   pronta para poste pintado acender")
		_checar(not EstadoMundo.anoiteceu, "   e ela não mexe na hora do world1")
	var torre := get_tree().current_scene
	await _quadros(3)
	_checar((torre.get_node("PostesDeLuz") as PostesDeLuz).quantidade() == 1, "o poste da torre acende")


func _testar_luzes_proprias() -> void:
	print("\n--- INTERFACE DO MUNDO E LUZES PRÓPRIAS ---")
	EstadoMundo.anoiteceu = true
	await _abrir(MUNDO)
	var cena := get_tree().current_scene
	var atm := Atmosfera.da_cena(cena)
	await _quadros(4)
	var player := _player()
	_checar(atm._e_interface(player.get_node("CoracaoFoguete")) and atm._e_interface(player.get_node("ExclamacaoFoguete")),
		"os balões da Cacau ficam fora da luz ambiente")
	_checar(atm._e_interface(cena.get_node("BotaoMoviment/Label")), "os textos do mundo também")
	_checar(not atm._e_interface(cena.get_node("Chão")) and not atm._e_interface(player.get_node("AnimatedSprite2D")),
		"o cenário e a personagem escurecem")
	_checar(cena.get_node("Chão/Placa").is_in_group(Atmosfera.GRUPO_RECEBE_LUZ),
		"a placa da estrada é do mundo: escurece junto")

	# O laser e o painel seguem o horário...
	var laser := cena.get_node("Barreira/LuzDoLaser") as LuzPontual
	var tela := cena.get_node("ReceptorItemGeral/LuzDaTela") as LuzPontual
	_checar(laser != null and laser.acesa and is_equal_approx(laser.intensidade, 1.0), "o laser brilha no escuro")
	_checar(tela != null and is_equal_approx(tela.intensidade, 1.0), "a tela do painel também")
	cena.get_node("Barreira").abrir_passagem()
	_checar(not laser.acesa, "desligado o laser, o clarão dele apaga")

	# ...e ficam apagados onde não há Atmosfera (o laboratório).
	get_tree().current_scene = null
	cena.queue_free()
	await _quadros(2)
	var solta := (load("res://scenes/barreira.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(solta)
	await _quadros(2)
	_checar(is_zero_approx((solta.get_node("LuzDoLaser") as LuzPontual).intensidade),
		"sem Atmosfera na cena, a luz do laser fica apagada")
	solta.queue_free()

	# O fogo da fornalha tem luz própria, acesa junto com ele.
	_zerar_a_partida()
	await _abrir(PATIO)
	var retorta := get_tree().current_scene.get_node("Patio/Retorta")
	var fogo := retorta.get_node("LuzDoFogo") as LuzPontual
	_checar(fogo != null and not fogo.acesa and not fogo.segue_o_horario, "a fornalha apagada não ilumina")
	retorta._acesa = true
	retorta._atualizar_sprite()
	_checar(fogo.acesa, "acesa, o fogo ilumina o pátio")


# ─────────────────────────────────────────────────────────────

## A sequência de tiles de cada mastro de poste pintado na cena (uma lista de
## linhas do atlas, de cima para baixo, por poste).
func _mastros(raiz: Node) -> Array:
	var mastros := []
	for camada in _camadas_de_tiles(raiz):
		for i in camada.tile_set.get_source_count():
			var id := camada.tile_set.get_source_id(i)
			var fonte := camada.tile_set.get_source(id) as TileSetAtlasSource
			if fonte == null or fonte.texture == null or fonte.texture.resource_path.get_file() != ARTE_DO_POSTE:
				continue
			for topo in camada.get_used_cells_by_id(id, Vector2i(0, 9)):
				var mastro := []
				var celula: Vector2i = topo
				while camada.get_cell_source_id(celula) == id and camada.get_cell_atlas_coords(celula).x == 0:
					mastro.append(camada.get_cell_atlas_coords(celula).y)
					celula += Vector2i.DOWN
				mastros.append(mastro)
	return mastros


func _camadas_de_tiles(no: Node) -> Array[TileMapLayer]:
	var lista: Array[TileMapLayer] = []
	if no is TileMapLayer and (no as TileMapLayer).tile_set != null:
		lista.append(no)
	for filho in no.get_children():
		lista.append_array(_camadas_de_tiles(filho))
	return lista


func _ambiente(atm: Atmosfera) -> CanvasModulate:
	for filho in atm.get_children(true):
		if filho is CanvasModulate:
			return filho
	return null


## Nenhum desenho do fundo ficou com material gravado (o material do horário
## vai direto para o render).
func _sem_material(no: Node) -> bool:
	if no is CanvasItem and (no as CanvasItem).material != null:
		return false
	for filho in no.get_children():
		if not _sem_material(filho):
			return false
	return true


func _abrir(caminho: String) -> void:
	get_tree().change_scene_to_file(caminho)
	await _quadros(3)


func _player() -> CharacterBody2D:
	return get_tree().current_scene.get_node("Player") as CharacterBody2D


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _segundos(s: float) -> void:
	var resta := s
	while resta > 0.0:
		await get_tree().process_frame
		resta -= get_process_delta_time()


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1
