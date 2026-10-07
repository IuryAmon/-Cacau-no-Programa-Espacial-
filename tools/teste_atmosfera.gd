extends Node

# Teste do sistema de iluminação (scripts/luz/) e da cena do pôr do sol:
#
#   godot --headless --path . res://tools/teste_atmosfera.tscn
#
# Casos:
#   * os postes: todo poste pintado no world1 tem a altura do poste da
#     fase2_torre (8 tiles, na mesma sequência), e cada lâmpada pintada ganhou
#     uma luz em cima do tubo — lisa, sem degraus nem pontilhado;
#   * o world1 abre ao ENTARDECER: sol no céu, lua fora, sem estrelas, postes
#     fracos, o fundo vestido com a luz do horário — e nada disso gravado nos
#     nós da cena;
#   * o pôr do sol: o sol desce, a fase chega ao crepúsculo — só um pouco mais
#     escura, sem noite — e os postes ganham força; virar a noite acende as
#     estrelas e fica lembrado;
#   * a cena do mirante inteira, com o diálogo de verdade: a Cacau fica parada
#     do começo ao fim, a tela não apaga, a fase fica no crepúsculo, o controle
#     e o HUD voltam, e a cena não repete;
#   * de volta ao world1 depois disso, a fase abre no crepúsculo;
#   * o pátio (fase 1.2) abre no crepúsculo, sem lua; encher e acender a
#     fornalha não muda a hora — é depois do painel resolvido, com ela ainda
#     queimando, que a noite cai com a lua subindo, uma vez só; daí em diante
#     o pátio e o world1 abrem de noite;
#   * a hora é uma só para o jogo inteiro: na tarde, no crepúsculo e na noite,
#     as três fases ao ar livre abrem na mesma hora;
#   * a fase2_torre, de noite, tem a lua no alto;
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
	await _testar_volta_no_crepusculo()
	await _testar_noite_no_patio()
	await _testar_hora_sincronizada()
	await _testar_torre_de_noite()
	await _testar_luzes_proprias()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _zerar_a_partida() -> void:
	EstadoMundo.anoiteceu = false
	EstadoMundo.sol_se_pos = false
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

	# A luz é lisa: um degradê contínuo, e não meia dúzia de patamares.
	var tons := _tons_da_poca(postes.luzes()[0])
	_checar(postes.luzes().all(func(l: LuzDePoste) -> bool: return not l.pixelada) and tons > 64,
		"a luz dos postes é lisa (%d tons na poça)" % tons)
	postes.pixelada = true
	var em_degraus := _tons_da_poca(postes.luzes()[0])
	_checar(em_degraus <= postes.degraus + 1, "ligando \"pixelada\" ela volta a cair em degraus (%d tons)" % em_degraus)
	postes.pixelada = false


func _testar_entardecer() -> void:
	print("\n--- O WORLD1 ABRE AO ENTARDECER ---")
	await _abrir(MUNDO)
	var cena := get_tree().current_scene
	var atm := Atmosfera.da_cena(cena)
	_checar(atm != null and atm.momento == Atmosfera.Momento.ENTARDECER, "a fase começa ao entardecer")
	await _quadros(4)

	var sol := cena.get_node("BG/CamadaDoSol/Sol") as AstroPixel
	_checar(sol.tipo == AstroPixel.Tipo.SOL and is_equal_approx(sol.presenca(), 1.0), "o sol está no céu")
	_checar(cena.get_node_or_null("BG/CamadaDaLua") == null, "o world1 não tem lua")
	_checar(sol.brilho_pixelado, "o brilho do sol é em pixel art")
	_checar(atm.perfil_atual() == atm.entardecer and is_zero_approx(atm.perfil_atual().estrelas),
		"o perfil é o do entardecer, sem estrelas")
	_checar(atm.pode_por_o_sol(), "e o sol ainda está para se pôr")

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
	_checar(atm.crepusculo.ambiente.get_luminance() > atm.entardecer.ambiente.get_luminance() * 0.75
		and atm.crepusculo.ambiente.get_luminance() > atm.noite.ambiente.get_luminance() * 1.3,
		"escureceu só de leve (%.2f, contra %.2f do entardecer e %.2f da noite)" % [
			atm.crepusculo.ambiente.get_luminance(), atm.entardecer.ambiente.get_luminance(),
			atm.noite.ambiente.get_luminance()])
	_checar(not EstadoMundo.anoiteceu and EstadoMundo.sol_se_pos and not atm.pode_por_o_sol(),
		"ainda não é noite: o que ficou lembrado é o sol posto")

	atm.definir_momento(Atmosfera.Momento.NOITE)
	_checar(is_zero_approx(sol.presenca()), "virou a noite: o sol saiu do céu")
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
	gatilho.respiro_depois_do_sol = 0.1

	var hud := player.get_node("CanvasLayer") as CanvasLayer
	var forma := gatilho.get_node("CollisionShape2D") as CollisionShape2D
	player.global_position = forma.global_position + Vector2(60, -30)
	player.velocity = Vector2.ZERO

	var falou := false
	var solta_cedo := false
	var hud_sumiu := false
	var viu_crepusculo := false
	var tela_apagou := false
	var espera := 0.0
	while espera < 40.0 and not (EstadoMundo.sol_se_pos and player.pode_se_mover):
		await get_tree().process_frame
		espera += get_process_delta_time()
		if Dialogic.current_timeline != null:
			falou = true
			Dialogic.Inputs.handle_input()
		var cortina := cena.get_node_or_null("FadeTela")
		if cortina != null and (cortina.get_child(0) as ColorRect).visible:
			tela_apagou = true
		if EstadoMundo.viu_o_foguete and not EstadoMundo.sol_se_pos:
			# Entre a fala e o sol posto ela não pode sair andando.
			solta_cedo = solta_cedo or player.pode_se_mover
			hud_sumiu = hud_sumiu or not hud.visible
			viu_crepusculo = viu_crepusculo or atm.andamento_do_por_do_sol() > 0.5

	_checar(gatilho._disparado and falou, "pisar no mirante dispara a fala do foguete")
	_checar(EstadoMundo.viu_o_foguete, "ela viu o foguete")
	_checar(viu_crepusculo, "depois da fala o sol desceu")
	_checar(not solta_cedo, "a Cacau ficou parada do coração até o sol sumir")
	_checar(hud_sumiu, "e o HUD saiu de cena enquanto isso")
	_checar(EstadoMundo.sol_se_pos and atm.momento == Atmosfera.Momento.CREPUSCULO
		and atm.perfil_atual() == atm.crepusculo, "o sol se pôs e a fase ficou no crepúsculo (%.1f s)" % espera)
	_checar(not EstadoMundo.anoiteceu and not tela_apagou, "sem tela preta e sem virar noite")
	_checar(player.pode_se_mover and not player.segurar_apos_o_foguete, "o controle voltou")
	await _quadros(3)
	_checar(hud.visible and cena.get_node_or_null("FadeTela") == null, "o HUD voltou e a cortina saiu")

	# A cena não repete: nem pisando de novo, nem se a fase recarregar.
	player.global_position = forma.global_position + Vector2(60, -120)
	await _quadros(3)
	player.global_position = forma.global_position + Vector2(60, -30)
	await _segundos(0.6)
	_checar(player.pode_se_mover and Dialogic.current_timeline == null, "pisar de novo no mirante não repete a cena")


func _testar_volta_no_crepusculo() -> void:
	print("\n--- DE VOLTA AO WORLD1, DEPOIS ---")
	# (EstadoMundo.sol_se_pos e viu_o_foguete vêm do caso anterior.)
	await _abrir(MUNDO)
	var cena := get_tree().current_scene
	var atm := Atmosfera.da_cena(cena)
	await _quadros(4)
	_checar(atm.momento == Atmosfera.Momento.CREPUSCULO and atm.perfil_atual() == atm.crepusculo,
		"a fase abre no crepúsculo, não de noite")
	var sol := cena.get_node("BG/CamadaDoSol/Sol") as AstroPixel
	_checar(is_equal_approx(sol.descida, atm.descida_do_sol), "com o sol posto")
	_checar((cena.get_node("ColisaoCenaFoguete") as Area2D)._disparado, "e a cena do mirante desarmada")
	_checar(not atm.pode_por_o_sol(), "não há outro pôr do sol para acontecer")


func _testar_noite_no_patio() -> void:
	print("\n--- A NOITE CAI NO PÁTIO, COM A FORNALHA QUEIMANDO ---")
	_zerar_a_partida()
	EstadoMundo.sol_se_pos = true
	await _abrir(PATIO)
	var cena := get_tree().current_scene
	var atm := Atmosfera.da_cena(cena)
	var player := _player()
	await _quadros(4)
	_checar(atm != null and atm.momento == Atmosfera.Momento.CREPUSCULO and atm.perfil_atual() == atm.crepusculo,
		"o pátio abre no crepúsculo")
	var lua := cena.get_node_or_null("BG/CamadaDaLua/Lua") as AstroPixel
	var lugar_da_lua := lua._base.y
	_checar(lua != null and lua.tipo == AstroPixel.Tipo.LUA and is_zero_approx(lua.presenca())
		and is_equal_approx(lua.position.y, lugar_da_lua + atm.subida_da_lua),
		"sem lua no céu: ela espera embaixo da serra")
	_checar(lua.texture.resource_path == "res://assets/Area Aberta/Lua/2.png"
		and not lua.brilho_pixelado and lua.scale.x < 1.0, "   (Lua/2.png, pequena e de brilho liso)")
	_checar(cena.get_node_or_null("PostesDeLuz") is PostesDeLuz, "pronto para poste pintado acender")

	var retorta := cena.get_node("Patio/Retorta") as RetortaCarbonizacao
	atm.duracao_do_anoitecer = 1.0
	var no_forno: int = retorta._madeiras_no_forno

	# Encher a fornalha não mexe na hora.
	for i in retorta.madeiras_necessarias - no_forno:
		_dar_uma_tora()
		retorta._abastecer()
	await _quadros(3)
	_checar(retorta._cheia() and atm.momento == Atmosfera.Momento.CREPUSCULO
		and atm.pode_anoitecer() and player.pode_se_mover,
		"com a fornalha cheia, mas apagada, a hora não muda")

	# Aceso o fogo (o painel aberto), a hora continua a mesma.
	retorta._acesa = true
	retorta._atualizar_sprite()
	await _quadros(3)
	_checar(atm.momento == Atmosfera.Momento.CREPUSCULO and atm.pode_anoitecer(),
		"com o fogo aceso, antes de o painel ser resolvido, também não")

	# O painel foi resolvido: com a fornalha queimando, o tempo avança.
	var hud := player.get_node("CanvasLayer") as CanvasLayer
	retorta._concluir()
	var lua_subindo := false
	var tela_apagou := false
	var parada := true
	var hud_sumiu := false
	var fogo_aceso := true
	var espera := 0.0
	await _quadros(2)
	_checar(not atm.pode_anoitecer() and atm.momento != Atmosfera.Momento.NOITE and not player.pode_se_mover,
		"resolvido o painel, a noite começa a cair e a Cacau para")
	while espera < 20.0 and atm.momento != Atmosfera.Momento.NOITE:
		await get_tree().process_frame
		espera += get_process_delta_time()
		if atm.momento == Atmosfera.Momento.NOITE:
			break
		parada = parada and not player.pode_se_mover
		hud_sumiu = hud_sumiu or not hud.visible
		fogo_aceso = fogo_aceso and retorta._acesa and not retorta._carbono_pronto
		var cortina := cena.get_node_or_null("FadeTela")
		if cortina != null and (cortina.get_child(0) as ColorRect).visible:
			tela_apagou = true
		if lua.presenca() > 0.9 and lua.position.y > lugar_da_lua + 20.0 \
				and lua.position.y < lugar_da_lua + atm.subida_da_lua - 20.0:
			lua_subindo = true
	_checar(fogo_aceso, "a fornalha ficou pegando fogo enquanto a noite caía")
	_checar(parada and hud_sumiu, "ela ficou parada e o HUD saiu de cena")
	_checar(lua_subindo, "a lua subiu de trás da serra, já acesa")
	_checar(not tela_apagou, "sem tela preta")
	_checar(atm.momento == Atmosfera.Momento.NOITE and atm.perfil_atual() == atm.noite
		and is_equal_approx(atm.perfil_atual().estrelas, 1.0), "a noite caiu: céu estrelado (%.1f s)" % espera)
	_checar(is_equal_approx(lua.position.y, lugar_da_lua) and is_equal_approx(lua.presenca(), 1.0),
		"a lua parou no lugar em que foi deixada na cena")
	_checar(EstadoMundo.anoiteceu and not atm.pode_anoitecer(), "e a noite ficou lembrada")
	await _segundos(RetortaCarbonizacao.BRASA_APOS_A_NOITE + 0.4)
	_checar(not retorta._acesa and retorta._carbono_pronto, "a brasa apagou e o carvão saiu, já de noite")
	_checar(player.pode_se_mover and hud.visible and cena.get_node_or_null("FadeTela") == null,
		"o controle e o HUD voltaram")
	# (O carvão do teste não fica anotado para os casos seguintes.)
	retorta._carbono_pronto = false
	retorta._madeiras_no_forno = no_forno
	retorta._guardar_carga()

	# Daí em diante o pátio e o world1 abrem de noite.
	await _abrir(PATIO)
	atm = Atmosfera.da_cena(get_tree().current_scene)
	await _quadros(4)
	lua = get_tree().current_scene.get_node("BG/CamadaDaLua/Lua") as AstroPixel
	_checar(atm.momento == Atmosfera.Momento.NOITE and is_equal_approx(lua.presenca(), 1.0)
		and is_zero_approx(lua.descida), "voltando ao pátio, já é noite, com a lua no alto")
	await _abrir(MUNDO)
	atm = Atmosfera.da_cena(get_tree().current_scene)
	await _quadros(4)
	var sol := get_tree().current_scene.get_node("BG/CamadaDoSol/Sol") as AstroPixel
	_checar(atm.momento == Atmosfera.Momento.NOITE and atm.perfil_atual() == atm.noite
		and is_zero_approx(sol.presenca()), "e o world1 também abre de noite")


var _toras_dadas := 0

func _dar_uma_tora() -> void:
	_toras_dadas += 1
	Inventario.adicionar_item("%steste_%d" % [Madeira.PREFIXO_ID, _toras_dadas], "Madeira", null)


func _testar_hora_sincronizada() -> void:
	print("\n--- A HORA É A MESMA EM TODAS AS FASES ---")
	var horas := [
		["de tarde", false, false, Atmosfera.Momento.ENTARDECER],
		["no crepúsculo", true, false, Atmosfera.Momento.CREPUSCULO],
		["de noite", true, true, Atmosfera.Momento.NOITE],
	]
	for hora: Array in horas:
		_zerar_a_partida()
		EstadoMundo.sol_se_pos = hora[1]
		EstadoMundo.anoiteceu = hora[2]
		var iguais := true
		var luas_certas := true
		for caminho: String in [MUNDO, PATIO, TORRE]:
			await _abrir(caminho)
			var cena := get_tree().current_scene
			var atm := Atmosfera.da_cena(cena)
			await _quadros(4)
			iguais = iguais and atm != null and atm.segue_a_partida and atm.momento == hora[3] \
				and atm.perfil_atual() == atm.perfil_de(hora[3])
			var lua := cena.get_node_or_null("BG/CamadaDaLua/Lua") as AstroPixel
			if lua != null:
				luas_certas = luas_certas and is_equal_approx(lua.presenca(), 1.0 if hora[2] else 0.0)
		_checar(iguais, "%s, é %s no world1, no pátio e na torre" % [hora[0], hora[0]])
		_checar(luas_certas, "   e a lua %s" % ("está no céu" if hora[2] else "ainda não apareceu em nenhuma"))


func _testar_torre_de_noite() -> void:
	print("\n--- A TORRE, DE NOITE ---")
	_zerar_a_partida()
	EstadoMundo.sol_se_pos = true
	EstadoMundo.anoiteceu = true
	await _abrir(TORRE)
	var cena := get_tree().current_scene
	var atm := Atmosfera.da_cena(cena)
	await _quadros(4)
	_checar(atm != null and atm.momento == Atmosfera.Momento.NOITE and atm.perfil_atual() == atm.noite,
		"fase2_torre: é noite")
	var lua := cena.get_node_or_null("BG/CamadaDaLua/Lua") as AstroPixel
	_checar(lua != null and lua.tipo == AstroPixel.Tipo.LUA and is_equal_approx(lua.presenca(), 1.0)
		and is_zero_approx(lua.descida) and lua.texture.resource_path == "res://assets/Area Aberta/Lua/2.png",
		"   quem ilumina é a lua (Lua/2.png), já no alto")
	_checar(lua != null and not lua.brilho_pixelado and lua.scale.x < 1.0, "   pequena e de brilho liso")
	var sois := 0
	for astro in get_tree().get_nodes_in_group(Atmosfera.GRUPO_DE_CLIENTES):
		if astro is AstroPixel and (astro as AstroPixel).tipo == AstroPixel.Tipo.SOL:
			sois += 1
	_checar(sois == 0, "   sem sol nenhum")
	_checar(cena.get_node("BG").get_child(0) is CeuPixel and is_equal_approx(atm.perfil_atual().estrelas, 1.0),
		"   céu estrelado")
	await _quadros(3)
	_checar((cena.get_node("PostesDeLuz") as PostesDeLuz).quantidade() == 1, "o poste da torre acende")


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
	_checar(not laser.pixelada and not (cena.get_node("BG/BASE/SpritesTiros(4)/Holofotes") as ArteIluminada).pixelada,
		"com luz lisa, como os holofotes do fundo")
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


## Quantos tons diferentes tem a textura da poça de luz de um poste.
func _tons_da_poca(luz: LuzDePoste) -> int:
	for filho in luz.get_children(true):
		if filho is PointLight2D:
			var img := ((filho as PointLight2D).texture as ImageTexture).get_image()
			var tons := {}
			for y in range(0, img.get_height(), 3):
				for x in range(0, img.get_width(), 3):
					tons[img.get_pixel(x, y).r8] = true
			return tons.size()
	return 0


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
