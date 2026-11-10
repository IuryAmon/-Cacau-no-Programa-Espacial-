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
#     do começo ao fim, a tela não apaga, a fase fica no crepúsculo, ela fala
#     do anoitecer, o controle e o HUD voltam, e a cena não repete. A música:
#     o piano G com o balão, a trilha pausada, "vendo foguete2" um respiro
#     depois do piano, e no fim a trilha de volta, já com a bossa do sol posto;
#   * a música segue a hora em todo lugar de céu aberto: a bossa da tarde, a
#     do sol posto e o jazz da noite — inclusive quando a noite cai no pátio e
#     com a tecla Ç —, sem recomeçar de uma fase para a outra; a oficina toca a
#     dela;
#   * de volta ao world1 depois disso, a fase abre no crepúsculo;
#   * o pátio (fase 1.2) abre no crepúsculo, sem lua; encher e acender a
#     fornalha não muda a hora, e resolver o painel da temperatura também não:
#     com o forno de boca aberta o tempo não passa. É quando a porta do forno
#     fecha, com ele ainda queimando lá dentro, que a noite cai com a lua
#     subindo, uma vez só; daí em diante o pátio e o world1 abrem de noite.
#     Os postes do pátio ficam apagados até a noite cair e pegam no meio dela;
#   * a hora é uma só para o jogo inteiro: na tarde, no crepúsculo e na noite,
#     as três fases ao ar livre abrem na mesma hora;
#   * a tecla Ç (debug) passa para a hora seguinte, na fase e na partida;
#   * a fase2_torre, de noite, tem a lua no alto;
#   * as janelas dos prédios da torre acendem à noite, todas e todas iguais
#     (o vidro de uma cor só), cada uma em cima da sua janela; ficam fracas ao
#     entardecer, e a rua nunca põe na tela mais luzes do que o Godot soma num
#     desenho só;
#   * a interface do mundo (balões, teclas, textos) fica fora da luz ambiente,
#     e a placa da estrada não;
#   * as luzes que seguem o horário (o laser) ficam apagadas numa cena sem
#     Atmosfera; o fogo da fornalha acende junto com ela.

const MUNDO := "res://scenes/world1.tscn"
const PATIO := "res://scenes/fases/fase1_2_exterior.tscn"
const TORRE := "res://scenes/fases/fase2_torre.tscn"
const OFICINA := "res://scenes/fases/fase1_oficina.tscn"
const MUSICA_DA_TARDE := "res://sounds/Trilhas/bossa nova estilo stardew valley.mp3"
const MUSICA_DO_SOL_POSTO := "res://sounds/Trilhas/bossa nova estila stardew valley2.mp3"
const MUSICA_DA_NOITE := "res://sounds/Trilhas/jazz noite.mp3"
const MUSICA_DO_FOGUETE := "res://sounds/Trilhas/vendo foguete2.mp3"
const MUSICA_DA_OFICINA := "res://sounds/Trilhas/fase1.mp3"
const ARTE_DO_POSTE := "Props-01.png"
## O mastro do poste da fase2_torre, de cima para baixo (linhas do atlas).
const MASTRO := [9, 10, 11, 12, 10, 11, 12, 13]
## O Godot soma no máximo 15 luzes num mesmo desenho, e o cenário da rua é
## desenhado num bloco só: as luzes da fase na tela (postes e janelas) ficam
## nisto, e sobra lugar para as que andam com a Cacau (lanterna, maçarico,
## ferramenta).
const LUZES_DA_FASE_NA_TELA := 12

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
	await _testar_tecla_da_hora()
	await _testar_torre_de_noite()
	await _testar_janelas_da_torre()
	await _testar_oficina()
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
	var da_torre := _postes_de_cena(get_tree().current_scene)
	_checar(da_torre.size() >= 4 and da_torre.all(func(p: PosteDeLuz) -> bool: return p.linhas_da_haste() == MASTRO),
		"os %d postes da fase2_torre (cena PosteDeLuz) são o modelo: %d tiles" % [da_torre.size(), MASTRO.size()])

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
	_checar(_musica_tocando() == MUSICA_DA_TARDE, "toca a bossa da tarde (%s)" % _musica_tocando().get_file())

	var ambiente := _ambiente(atm)
	_checar(ambiente != null and ambiente.color.is_equal_approx(atm.entardecer.ambiente),
		"o mundo está na luz ambiente do entardecer")
	_checar(atm._camadas.size() >= 5, "o fundo foi vestido com a luz do horário (%d desenhos)" % atm._camadas.size())
	_checar(_sem_material(cena.get_node("BG")), "sem gravar material nenhum nos nós do fundo")

	var postes := cena.get_node("PostesDeLuz") as PostesDeLuz
	var fracos := postes.luzes().all(func(l: LuzDePoste) -> bool:
		return is_equal_approx(l.intensidade, atm.entardecer.postes))
	_checar(fracos and atm.entardecer.postes < 0.6, "os postes estão acesos, mas fracos (%.2f)" % atm.entardecer.postes)

	# O céu, o sol e as nuvens sobem e descem juntos, e menos que a serra do
	# fundo (ela está mais perto); a lua fica presa na tela.
	var serra := cena.get_node("BG/4") as ParallaxLayer
	var ceu := cena.get_node("BG/Ceu") as ParallaxLayer
	var juntos := ["BG/CamadaDoSol", "BG/NuvensDoFundo", "BG/Nuvens"].all(func(caminho: String) -> bool:
		var camada := cena.get_node(caminho) as ParallaxLayer
		return is_equal_approx(camada.motion_scale.y, ceu.motion_scale.y) and camada.motion_offset.is_equal_approx(ceu.motion_offset))
	_checar(juntos and is_zero_approx(ceu.motion_scale.x)
		and is_zero_approx((cena.get_node("BG/CamadaDoSol") as ParallaxLayer).motion_scale.x),
		"o céu, o sol e as nuvens sobem e descem juntos (%.2f)" % ceu.motion_scale.y)
	_checar(ceu.motion_scale.y > 0.0 and ceu.motion_scale.y < serra.motion_scale.y,
		"   e menos que a serra (%.2f)" % serra.motion_scale.y)
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
	var falou_do_anoitecer := false
	var coracao := player.get_node("CoracaoFoguete") as AnimatedSprite2D
	var coracao_no_por_do_sol := true
	var coracao_na_fala := false
	var retrato := ""
	var falas_a_direita := true
	var uau_so_com_o_retrato := false
	var presa_na_fala := true
	var tocou_o_piano := false
	var piano_com_o_balao := false
	var quando_o_piano_acabou := -1.0
	var quando_o_foguete_entrou := -1.0
	var trilha_pausou := false
	var musica_do_foguete_tocou := false
	var trilha_parada_com_ela := true
	var exclamacao := player.get_node("ExclamacaoFoguete") as CanvasItem
	var quando_pisou := -1.0
	var quando_o_balao_pulou := -1.0
	var espera := 0.0
	while espera < 40.0 and not (EstadoMundo.sol_se_pos and player.pode_se_mover):
		await get_tree().process_frame
		espera += get_process_delta_time()
		if gatilho._disparado and quando_pisou < 0.0:
			quando_pisou = espera
		if exclamacao.visible and quando_o_balao_pulou < 0.0:
			quando_o_balao_pulou = espera - quando_pisou
		if gatilho._susto != null and is_instance_valid(gatilho._susto) and gatilho._susto.playing:
			if not tocou_o_piano:
				piano_com_o_balao = exclamacao.visible and Dialogic.current_timeline == null
			tocou_o_piano = true
		elif tocou_o_piano and quando_o_piano_acabou < 0.0:
			quando_o_piano_acabou = espera
		trilha_pausou = trilha_pausou or TrilhaSonora.esta_pausada()
		if gatilho.tocando_a_musica_do_foguete():
			if quando_o_foguete_entrou < 0.0:
				quando_o_foguete_entrou = espera
			musica_do_foguete_tocou = true
			var pausado := TrilhaSonora._tocador
			trilha_parada_com_ela = trilha_parada_com_ela and TrilhaSonora.esta_pausada() \
				and pausado != null and pausado.stream_paused
		if Dialogic.current_timeline != null:
			falou = true
			var quem := load("res://timelines/cacau.dch") as DialogicCharacter
			if Dialogic.Portraits.is_character_joined(quem) and Dialogic.current_state_info.get("speaker", "") != "":
				var nomes := get_tree().get_nodes_in_group("dialogic_name_label")
				var a_direita := not nomes.is_empty() and is_equal_approx((nomes[0].get_parent() as Control).anchor_left, 1.0)
				# O "Uau..." é a primeira fala da timeline do foguete (eventos 1 e 2:
				# a fala e a caminhada que vem com ela ainda na tela).
				var uau := Dialogic.current_event_idx <= 2 \
					and Dialogic.current_timeline.resource_path.get_file() == "cacau_ve_foguete.dtl"
				if uau and str(Dialogic.current_state_info.get("text", "")).begins_with("Uau"):
					uau_so_com_o_retrato = not a_direita
				falas_a_direita = falas_a_direita \
					and str(Dialogic.current_state_info["portraits"][quem.resource_path].get("position_id", "")) == "right" \
					and (uau or a_direita)
			if EstadoMundo.sol_se_pos:
				falou_do_anoitecer = falou_do_anoitecer \
					or Dialogic.current_timeline.resource_path.get_file() == "cacau_anoitecendo.dtl"
				presa_na_fala = presa_na_fala and not player.pode_se_mover
				coracao_na_fala = coracao_na_fala or coracao.visible
				var cacau := load("res://timelines/cacau.dch") as DialogicCharacter
				if Dialogic.Portraits.is_character_joined(cacau):
					retrato = Dialogic.current_state_info["portraits"][cacau.resource_path].get("portrait", "")
			Dialogic.Inputs.handle_input()
		var cortina := cena.get_node_or_null("FadeTela")
		if cortina != null and (cortina.get_child(0) as ColorRect).visible:
			tela_apagou = true
		if EstadoMundo.viu_o_foguete and not EstadoMundo.sol_se_pos:
			# Entre a fala e o sol posto ela não pode sair andando.
			solta_cedo = solta_cedo or player.pode_se_mover
			hud_sumiu = hud_sumiu or not hud.visible
			viu_crepusculo = viu_crepusculo or atm.andamento_do_por_do_sol() > 0.5
			if atm.andamento_do_por_do_sol() > 0.1 and atm.andamento_do_por_do_sol() < 1.0:
				coracao_no_por_do_sol = coracao_no_por_do_sol and coracao.visible and coracao.is_playing()

	_checar(gatilho._disparado and falou, "pisar no mirante dispara a fala do foguete")
	_checar(EstadoMundo.viu_o_foguete, "ela viu o foguete")
	_checar(viu_crepusculo, "depois da fala o sol desceu")
	_checar(not solta_cedo, "a Cacau ficou parada do coração até o sol sumir")
	_checar(hud_sumiu, "e o HUD saiu de cena enquanto isso")
	_checar(EstadoMundo.sol_se_pos and atm.momento == Atmosfera.Momento.CREPUSCULO
		and atm.perfil_atual() == atm.crepusculo, "o sol se pôs e a fase ficou no crepúsculo (%.1f s)" % espera)
	_checar(not EstadoMundo.anoiteceu and not tela_apagou, "sem tela preta e sem virar noite")
	_checar(falou_do_anoitecer and presa_na_fala, "com o sol posto ela fala do anoitecer, ainda parada")
	_checar(coracao_no_por_do_sol, "o coração ficou batendo o pôr do sol inteiro")
	_checar(not coracao_na_fala and not coracao.visible, "e saiu na hora da fala")
	_checar(falas_a_direita, "nas falas da cena o retrato e o nome ficam do lado direito")
	_checar(uau_so_com_o_retrato, "menos no \"Uau...\": ali só o retrato vai para a direita")
	_checar(retrato == "cacau_superneutro", "a fala usa o retrato superneutro (%s)" % retrato)
	_checar(player.pode_se_mover and not player.segurar_apos_o_foguete, "o controle voltou")
	await _quadros(3)
	_checar(hud.visible and cena.get_node_or_null("FadeTela") == null, "o HUD voltou e a cortina saiu")
	_checar(quando_o_balao_pulou >= 0.0 and quando_o_balao_pulou < 0.05,
		"o balão pula na hora em que ela entra no mirante (%.2f s)" % quando_o_balao_pulou)
	_checar(tocou_o_piano and piano_com_o_balao, "o piano G tocou junto com o balão de exclamação")
	_checar(trilha_pausou and musica_do_foguete_tocou and trilha_parada_com_ela
		and gatilho.musica_do_foguete.resource_path == MUSICA_DO_FOGUETE,
		"a trilha parou e \"vendo foguete2\" tocou no lugar")
	var respiro := quando_o_foguete_entrou - quando_o_piano_acabou
	_checar(quando_o_piano_acabou > 0.0 and respiro >= gatilho.espera_antes_da_musica - 0.05,
		"   %.1f s depois de o piano acabar" % respiro)
	await _segundos(gatilho.fade_de_volta + 0.3)
	var trilha := TrilhaSonora._tocador
	_checar(not gatilho.tocando_a_musica_do_foguete() and not TrilhaSonora.esta_pausada()
		and trilha != null and trilha.playing and not trilha.stream_paused
		and is_equal_approx(trilha.volume_db, atm.volume_da_musica_db),
		"no fim a trilha voltou (%.1f dB)" % (trilha.volume_db if trilha != null else 0.0))
	_checar(_musica_tocando() == MUSICA_DO_SOL_POSTO,
		"   já com a bossa do sol posto (%s)" % _musica_tocando().get_file())

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
	_checar(_musica_tocando() == MUSICA_DO_SOL_POSTO, "   com a bossa do sol posto")
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
	_checar(_musica_tocando() == MUSICA_DO_SOL_POSTO, "   com a bossa do sol posto")
	var lua := cena.get_node_or_null("BG/CamadaDaLua/Lua") as AstroPixel
	var lugar_da_lua := lua._base.y
	_checar(lua != null and lua.tipo == AstroPixel.Tipo.LUA and is_zero_approx(lua.presenca())
		and is_equal_approx(lua.position.y, lugar_da_lua + atm.subida_da_lua),
		"sem lua no céu: ela espera embaixo da serra")
	_checar(lua.texture.resource_path == "res://assets/Area Aberta/Lua/2.png"
		and not lua.brilho_pixelado and lua.scale.x < 1.0, "   (Lua/2.png, pequena e de brilho liso)")
	_checar(cena.get_node_or_null("PostesDeLuz") is PostesDeLuz, "pronto para poste pintado acender")
	var postes := _luzes_de_poste(cena)
	_checar(atm.postes_so_de_noite and postes.size() >= 2 and _postes_apagados(postes),
		"os %d postes do pátio esperam a noite: apagados no crepúsculo" % postes.size())

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

	# O painel foi resolvido, mas a boca do forno continua aberta: a fornalha
	# fica pegando fogo à espera da porta, e a hora NÃO anda.
	retorta.espera_antes_da_dica = 0.0
	retorta._on_painel_terminado(true, false)
	await _segundos(2.5)
	_checar(retorta._esperando_porta and retorta._acesa and not retorta._carbono_pronto
		and atm.momento == Atmosfera.Momento.CREPUSCULO and atm.pode_anoitecer() and player.pode_se_mover,
		"resolvido o painel, com o forno de boca aberta, o tempo não passa")
	_checar(_postes_apagados(postes), "   e os postes continuam apagados")

	# A porta fechou: com o fogo abafado lá dentro, o tempo avança.
	var hud := player.get_node("CanvasLayer") as CanvasLayer
	var porta_na_boca := retorta.get_node("PortaFechada") as Sprite2D
	(retorta.get_node("Porta") as PortaDaFornalha).apanhar()
	retorta._fechar_a_porta()
	var lua_subindo := false
	var tela_apagou := false
	var parada := true
	var hud_sumiu := false
	var fogo_aceso := true
	# Os postes, enquanto a noite cai: apagados no começo, acesos antes do fim.
	var postes_esperaram := true
	var postes_acenderam := false
	var espera := 0.0
	while espera < 5.0 and atm.pode_anoitecer():
		await get_tree().process_frame
		espera += get_process_delta_time()
	await _quadros(2)
	_checar(not atm.pode_anoitecer() and atm.momento != Atmosfera.Momento.NOITE and not player.pode_se_mover,
		"fechada a porta do forno, a noite começa a cair e a Cacau para (%.1f s depois)" % espera)
	espera = 0.0
	while espera < 20.0 and atm.momento != Atmosfera.Momento.NOITE:
		await get_tree().process_frame
		espera += get_process_delta_time()
		if atm.momento == Atmosfera.Momento.NOITE:
			break
		parada = parada and not player.pode_se_mover
		hud_sumiu = hud_sumiu or not hud.visible
		fogo_aceso = fogo_aceso and retorta._acesa and not retorta._carbono_pronto and porta_na_boca.visible
		var cortina := cena.get_node_or_null("FadeTela")
		if cortina != null and (cortina.get_child(0) as ColorRect).visible:
			tela_apagou = true
		if lua.presenca() > 0.9 and lua.position.y > lugar_da_lua + 20.0 \
				and lua.position.y < lugar_da_lua + atm.subida_da_lua - 20.0:
			lua_subindo = true
		if espera < atm.duracao_do_anoitecer * atm.hora_dos_postes_no_anoitecer * 0.8:
			postes_esperaram = postes_esperaram and _postes_apagados(postes)
		postes_acenderam = postes_acenderam or postes.all(func(l: LuzDePoste) -> bool: return l._nivel() > 0.5)
	_checar(fogo_aceso, "a fornalha ficou acesa, de porta fechada, enquanto a noite caía")
	_checar(postes_esperaram and postes_acenderam,
		"os postes ficaram apagados no começo da noite caindo e acenderam antes de ela terminar")
	_checar(parada and hud_sumiu, "ela ficou parada e o HUD saiu de cena")
	_checar(lua_subindo, "a lua subiu de trás da serra, já acesa")
	_checar(not tela_apagou, "sem tela preta")
	_checar(atm.momento == Atmosfera.Momento.NOITE and atm.perfil_atual() == atm.noite
		and is_equal_approx(atm.perfil_atual().estrelas, 1.0), "a noite caiu: céu estrelado (%.1f s)" % espera)
	_checar(is_equal_approx(lua.position.y, lugar_da_lua) and is_equal_approx(lua.presenca(), 1.0),
		"a lua parou no lugar em que foi deixada na cena")
	_checar(postes.all(func(l: LuzDePoste) -> bool: return is_equal_approx(l.intensidade, atm.noite.postes)),
		"de noite os postes estão com tudo")
	_checar(EstadoMundo.anoiteceu and not atm.pode_anoitecer(), "e a noite ficou lembrada")
	_checar(_musica_tocando() == MUSICA_DA_NOITE, "com a noite, entra o jazz (%s)" % _musica_tocando().get_file())
	await _segundos(RetortaCarbonizacao.BRASA_APOS_A_NOITE + 0.4)
	_checar(not retorta._acesa and retorta._carbono_pronto, "a brasa apagou e o carvão saiu, já de noite")
	_checar(player.pode_se_mover and hud.visible and cena.get_node_or_null("FadeTela") == null,
		"o controle e o HUD voltaram")
	# (O carvão do teste não fica anotado para os casos seguintes.)
	retorta._carbono_pronto = false
	retorta._madeiras_no_forno = no_forno
	retorta._guardar_carga()

	# Daí em diante o pátio e o world1 abrem de noite.
	var jazz := TrilhaSonora._tocador
	await _abrir(PATIO)
	atm = Atmosfera.da_cena(get_tree().current_scene)
	await _quadros(4)
	lua = get_tree().current_scene.get_node("BG/CamadaDaLua/Lua") as AstroPixel
	_checar(atm.momento == Atmosfera.Momento.NOITE and is_equal_approx(lua.presenca(), 1.0)
		and is_zero_approx(lua.descida), "voltando ao pátio, já é noite, com a lua no alto")
	_checar(_luzes_de_poste(get_tree().current_scene).all(func(l: LuzDePoste) -> bool:
		return is_equal_approx(l.intensidade, atm.noite.postes)), "   e os postes acesos")
	_checar(jazz != null and TrilhaSonora._tocador == jazz, "   e o jazz segue, sem recomeçar")
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
		["de tarde", false, false, Atmosfera.Momento.ENTARDECER, MUSICA_DA_TARDE],
		["no crepúsculo", true, false, Atmosfera.Momento.CREPUSCULO, MUSICA_DO_SOL_POSTO],
		["de noite", true, true, Atmosfera.Momento.NOITE, MUSICA_DA_NOITE],
	]
	for hora: Array in horas:
		_zerar_a_partida()
		EstadoMundo.sol_se_pos = hora[1]
		EstadoMundo.anoiteceu = hora[2]
		var iguais := true
		var luas_certas := true
		var musicas_certas := true
		var sem_recomecar := true
		var tocador: AudioStreamPlayer = null
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
			musicas_certas = musicas_certas and _musica_tocando() == hora[4]
			if tocador == null:
				tocador = TrilhaSonora._tocador
			sem_recomecar = sem_recomecar and tocador != null and TrilhaSonora._tocador == tocador
		_checar(iguais, "%s, é %s no world1, no pátio e na torre" % [hora[0], hora[0]])
		_checar(luas_certas, "   e a lua %s" % ("está no céu" if hora[2] else "ainda não apareceu em nenhuma"))
		_checar(musicas_certas, "   e toca %s nas três" % String(hora[4]).get_file())
		_checar(sem_recomecar, "   sem recomeçar de uma fase para a outra")


func _testar_tecla_da_hora() -> void:
	print("\n--- A TECLA Ç MUDA A HORA ---")
	_zerar_a_partida()
	await _abrir(PATIO)
	var cena := get_tree().current_scene
	var atm := Atmosfera.da_cena(cena)
	var player := _player()
	await _quadros(4)
	var lua := cena.get_node("BG/CamadaDaLua/Lua") as AstroPixel
	var tecla := InputEventKey.new()
	tecla.pressed = true
	tecla.physical_keycode = KEY_SEMICOLON
	var esperadas := [Atmosfera.Momento.CREPUSCULO, Atmosfera.Momento.NOITE, Atmosfera.Momento.ENTARDECER]
	var nomes := ["crepúsculo", "noite", "tarde de novo"]
	var musicas := [MUSICA_DO_SOL_POSTO, MUSICA_DA_NOITE, MUSICA_DA_TARDE]
	for i in esperadas.size():
		player._input(tecla)
		await _quadros(2)
		_checar(atm.momento == esperadas[i] and atm.perfil_atual() == atm.perfil_de(esperadas[i])
			and Atmosfera.hora_da_partida() == esperadas[i]
			and is_equal_approx(lua.presenca(), 1.0 if esperadas[i] == Atmosfera.Momento.NOITE else 0.0),
			"um toque: %s, na fase e na partida" % nomes[i])
		_checar(_musica_tocando() == musicas[i], "   e a música da hora entra junto (%s)" % _musica_tocando().get_file())
	player._input(tecla)
	await _abrir(MUNDO)
	await _quadros(4)
	_checar(Atmosfera.da_cena(get_tree().current_scene).momento == Atmosfera.Momento.CREPUSCULO,
		"e a outra fase abre na hora escolhida")


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
	var postes := _postes_de_cena(cena)
	var acesos := 0
	for poste: PosteDeLuz in postes:
		var luz := poste.get_node_or_null(^"Luz") as LuzDePoste
		if luz != null and luz.is_in_group(LuzDePoste.GRUPO) and luz.intensidade > 0.9 \
				and luz.position == poste.ponto_da_lampada():
			acesos += 1
	_checar(postes.size() >= 4 and acesos == postes.size(),
		"os postes da torre acendem, cada um com a luz no tubo (%d de %d)" % [acesos, postes.size()])


## As janelas pintadas nos prédios da rua acendem à noite, todas iguais
## (JanelasAcesas).
func _testar_janelas_da_torre() -> void:
	print("\n--- AS JANELAS DA TORRE, DE NOITE ---")
	_zerar_a_partida()
	EstadoMundo.sol_se_pos = true
	EstadoMundo.anoiteceu = true
	await _abrir(TORRE)
	await _quadros(4)
	var cena := get_tree().current_scene
	var janelas := cena.get_node_or_null("JanelasAcesas") as JanelasAcesas
	var pintadas := _janelas_pintadas(cena)
	_checar(janelas != null and pintadas > 0 and janelas.quantidade() == pintadas,
		"toda janela pintada nos prédios acende (%d de %d)"
			% [janelas.quantidade() if janelas != null else -1, pintadas])
	if janelas == null:
		return
	var em_cima := janelas.janelas().filter(func(arte: Rect2) -> bool: return _em_cima_de_janela(cena, arte))
	_checar(em_cima.size() == janelas.quantidade(),
		"   cada uma em cima da sua janela (%d)" % em_cima.size())
	_checar(janelas.get_child_count() == 0 and janelas.get_child_count(true) > 0,
		"   o que acende é filho interno: não entra no .tscn")
	_checar(janelas.is_in_group(Atmosfera.GRUPO_DE_LUZES) and janelas.intensidade > 0.9,
		"   e de noite estão com tudo")

	# Todas iguais: o vidro é a mesma arte, pintada da cor do nó, e só nos vidros.
	var receita: Dictionary = JanelasAcesas.JANELAS["Buildings.png"]
	var vidro := JanelasAcesas._mascara(receita["tamanho"] * 16, receita["vidros"]).get_image()
	var tons := {}
	var acesos := 0
	for y in vidro.get_height():
		for x in vidro.get_width():
			if vidro.get_pixel(x, y).a > 0.0:
				tons[vidro.get_pixel(x, y)] = true
				acesos += 1
	var nos_vidros := 0
	for v: Rect2i in receita["vidros"]:
		nos_vidros += v.get_area()
	var desenho := janelas.get_children(true).filter(func(no: Node) -> bool: return no.name == &"Vidros")
	_checar(tons.size() == 1 and acesos == nos_vidros and desenho.size() == 1
		and Color((desenho[0] as CanvasItem).modulate, 1.0).is_equal_approx(Color(janelas.cor, 1.0)),
		"   todas iguais: o vidro é de uma cor só, a do nó, e só nos vidros (%d tom, %d de %d pixels)"
			% [tons.size(), acesos, nos_vidros])

	var luzes := janelas.luzes()
	_checar(luzes.size() > 0 and luzes.size() < janelas.quantidade(),
		"   as janelas vizinhas de um andar dividem a luz na parede (%d luzes para %d janelas)"
			% [luzes.size(), janelas.quantidade()])
	var mais := _mais_luzes_na_tela(cena)
	_checar(mais <= LUZES_DA_FASE_NA_TELA,
		"na rua, a câmera nunca vê mais que %d luzes da fase de uma vez (%d no pior lugar)"
			% [LUZES_DA_FASE_NA_TELA, mais])

	var atm := Atmosfera.da_cena(cena)
	atm.definir_momento(Atmosfera.Momento.ENTARDECER)
	await _quadros(2)
	_checar(is_equal_approx(janelas.intensidade, atm.entardecer.postes),
		"ao entardecer elas ficam fracas, como os postes (%.2f)" % atm.entardecer.postes)
	atm.definir_momento(Atmosfera.Momento.NOITE)


## A fase 1 é um galpão fechado: tem a luz DELA (um perfil fixo), que não muda
## com a hora do jogo, e as lâmpadas pintadas no cenário acendem como os postes.
func _testar_oficina() -> void:
	print("\n--- A OFICINA (FASE 1), POR DENTRO ---")
	var ambientes: Array[Color] = []
	for noite: bool in [false, true]:
		_zerar_a_partida()
		EstadoMundo.sol_se_pos = noite
		EstadoMundo.anoiteceu = noite
		await _abrir(OFICINA)
		await _quadros(5)
		# (O rádio do Dr. Chico pode chamar na chegada: o teste não é dele.)
		if Dialogic.current_timeline != null:
			Dialogic.end_timeline()
			await _quadros(2)
		var atm := Atmosfera.da_cena(get_tree().current_scene)
		var onde := "de noite" if noite else "de tarde"
		_checar(atm != null and atm.e_interior() and atm.perfil_atual() == atm.perfil_fixo
			and atm.perfil_fixo.resource_path.get_file() == "oficina.tres",
			"%s lá fora, a oficina está na luz dela (oficina.tres)" % onde)
		if atm == null:
			return
		_checar(not atm.pode_por_o_sol() and not atm.pode_anoitecer(), "   lá dentro não há pôr do sol nem anoitecer")
		_checar(_musica_tocando() == MUSICA_DA_OFICINA, "   e toca a música da fase 1, seja que hora for")
		_checar(EstadoMundo.sol_se_pos == noite and EstadoMundo.anoiteceu == noite,
			"   e entrar nela não mexe na hora do jogo")
		ambientes.append(_ambiente(atm).color)
	_checar(ambientes.size() == 2 and ambientes[0].is_equal_approx(ambientes[1]),
		"a luz ambiente da oficina é a mesma a qualquer hora %s" % [ambientes])

	var cena := get_tree().current_scene
	var atm := Atmosfera.da_cena(cena)
	var ambiente := _ambiente(atm).color
	# Só um pouco: com 0,62 a fase ficou "muito escura" — a maior parte dela não
	# tem lâmpada nenhuma, então quem manda no que se enxerga é o ambiente.
	_checar(ambiente.is_equal_approx(atm.perfil_fixo.ambiente) and ambiente.get_luminance() < 0.95
		and ambiente.get_luminance() > 0.75,
		"um pouco mais escura que o dia, e só um pouco (luminância %.2f)" % ambiente.get_luminance())
	_checar(ambiente.b > ambiente.r, "e fria, para as lâmpadas quentes aparecerem")

	# As lâmpadas: as duas pontas do braço do poste, pintadas lado a lado.
	var postes := cena.get_node_or_null("PostesDeLuz") as PostesDeLuz
	var pintadas := _lampadas_pintadas(cena)
	_checar(postes != null and pintadas.size() >= 6 and postes.quantidade() == pintadas.size(),
		"cada lâmpada pintada na fase ganhou uma luz (%d de %d)" % [postes.quantidade() if postes else -1, pintadas.size()])
	if postes == null:
		return
	var acesas := postes.luzes().all(func(l: LuzDePoste) -> bool:
		return is_equal_approx(l.intensidade, 1.0) and not l.pixelada)
	_checar(acesas, "todas acesas com tudo, de luz lisa")
	var nos_tubos := 0
	for luz in postes.luzes():
		for ponto: Vector2 in pintadas:
			if luz.global_position.distance_to(ponto) < 24.0:
				nos_tubos += 1
				break
	_checar(nos_tubos == postes.quantidade(), "e cada luz sai do tubo da sua lâmpada (%d)" % nos_tubos)
	_checar(postes.mariposas == 0, "sem mariposas: é do lado de dentro")
	var nascimento := (cena.get_node("SpawnPadrao") as Marker2D).global_position
	var na_entrada := postes.luzes().any(func(l: LuzDePoste) -> bool:
		return absf(l.global_position.x - nascimento.x) < 160.0 and l.global_position.y < nascimento.y)
	_checar(na_entrada, "a Cacau já chega debaixo de uma lâmpada")

	# As luzes soltas (a placa da porta, os domos) são nós da cena, acesos.
	var soltas := cena.get_node_or_null("Luzes")
	var todas_acesas := soltas != null and soltas.get_child_count() >= 1
	if soltas != null:
		for luz in soltas.get_children():
			todas_acesas = todas_acesas and luz is LuzPontual and (luz as LuzPontual).acesa
	_checar(todas_acesas, "as luzes soltas da cena (%d) estão acesas" % (soltas.get_child_count() if soltas else 0))

	# O laser dos espinhos joga clarão vermelho; a serra, que é metal, não.
	var espinhos: Array[EspinhosLaser] = []
	var serras: Array[SerraEletrica] = []
	for no in get_tree().get_nodes_in_group("espinhos_laser") + get_tree().get_nodes_in_group("serra_eletrica"):
		if no is SerraEletrica:
			serras.append(no)
		elif no is EspinhosLaser and not espinhos.has(no):
			espinhos.append(no)
	var com_clarao := espinhos.size() >= 1
	for fileira in espinhos:
		com_clarao = com_clarao and fileira._brilho != null and fileira._brilho.acesa == (not fileira._recolhido) \
			and is_equal_approx(fileira._brilho.intensidade, 1.0)
	_checar(com_clarao, "cada fileira de espinhos de laser de pé joga o clarão dela (%d)" % espinhos.size())
	_checar(serras.size() >= 1 and serras.all(func(s: SerraEletrica) -> bool: return s._brilho == null),
		"as serras (%d) não: são lâmina, não luz" % serras.size())
	var de_pe: EspinhosLaser = null
	for fileira in espinhos:
		if not fileira._recolhido:
			de_pe = fileira
	if de_pe != null:
		de_pe.desarmar(false)
		_checar(not de_pe._brilho.acesa, "recolhidos os espinhos, o clarão apaga")

	# Interface do mundo continua fora do escuro; o cenário e a Cacau, dentro.
	_checar(atm._e_interface(cena.get_node("Salas/Sala448")), "os textos do mundo ficam fora da luz ambiente")
	_checar(not atm._e_interface(cena.get_node("Terreno")) and not atm._e_interface(_player().get_node("AnimatedSprite2D")),
		"o cenário e a personagem escurecem")

	# Fora de uma fase escura (sem Atmosfera) os espinhos não jogam clarão nenhum.
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()
	get_tree().current_scene = null
	cena.queue_free()
	await _quadros(2)
	var soltos := (load("res://scenes/fases/componentes/espinhos_laser.tscn") as PackedScene).instantiate() as EspinhosLaser
	get_tree().root.add_child(soltos)
	await _quadros(2)
	_checar(soltos._brilho != null and is_zero_approx(soltos._brilho.intensidade),
		"sem Atmosfera na cena, o clarão dos espinhos fica apagado")
	soltos.queue_free()
	await _quadros(2)


## O centro do tubo de cada lâmpada pintada com o braço do poste (qualquer
## camada de tiles da cena), em coordenadas do mundo.
func _lampadas_pintadas(raiz: Node) -> Array[Vector2]:
	var pontos: Array[Vector2] = []
	for camada in _camadas_de_tiles(raiz):
		for i in camada.tile_set.get_source_count():
			var id := camada.tile_set.get_source_id(i)
			var fonte := camada.tile_set.get_source(id) as TileSetAtlasSource
			if fonte == null or fonte.texture == null or fonte.texture.resource_path.get_file() != ARTE_DO_POSTE:
				continue
			var celulas := {}
			for x in [1, 2, 3]:
				for celula in camada.get_used_cells_by_id(id, Vector2i(x, 9)):
					celulas[celula] = true
			for celula: Vector2i in celulas:
				if celulas.has(celula + Vector2i.LEFT):
					continue
				var comprimento := 1
				while celulas.has(celula + Vector2i(comprimento, 0)):
					comprimento += 1
				var lado := Vector2(camada.tile_set.tile_size)
				var meio := camada.map_to_local(celula) + Vector2(lado.x * (comprimento - 1) * 0.5, 0.0)
				pontos.append(camada.to_global(meio))
	return pontos


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


## Os postes que são a cena PosteDeLuz (os que se arrastam no editor).
func _postes_de_cena(raiz: Node) -> Array:
	return raiz.find_children("*", "", true, false).filter(func(no: Node) -> bool: return no is PosteDeLuz)


## As luzes dos postes que são a cena PosteDeLuz.
func _luzes_de_poste(raiz: Node) -> Array:
	return raiz.find_children("*", "", true, false).filter(func(no: Node) -> bool: return no is LuzDePoste)


## Nenhum dos postes está entregando luz (nem a meia piscada).
func _postes_apagados(luzes: Array) -> bool:
	return luzes.all(func(l: LuzDePoste) -> bool: return is_zero_approx(l.intensidade) and l._nivel() <= 0.01)


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


## Quantas janelas estão pintadas no cenário (a célula de cima, à esquerda, da
## arte de janela do Buildings.png).
func _janelas_pintadas(raiz: Node) -> int:
	var receita: Dictionary = JanelasAcesas.JANELAS["Buildings.png"]
	var total := 0
	for camada in _camadas_de_tiles(raiz):
		for i in camada.tile_set.get_source_count():
			var id := camada.tile_set.get_source_id(i)
			var fonte := camada.tile_set.get_source(id) as TileSetAtlasSource
			if fonte != null and fonte.texture != null and fonte.texture.resource_path.get_file() == "Buildings.png":
				total += camada.get_used_cells_by_id(id, receita["celula"]).size()
	return total


## A janela acesa está em cima de uma janela pintada: no canto de cima, à
## esquerda, dela fica a célula de cima, à esquerda, da arte.
func _em_cima_de_janela(raiz: Node, arte: Rect2) -> bool:
	var receita: Dictionary = JanelasAcesas.JANELAS["Buildings.png"]
	for camada in _camadas_de_tiles(raiz):
		var lado := Vector2(camada.tile_set.tile_size)
		var celula := camada.local_to_map(camada.to_local(arte.position) + lado * 0.5)
		var id := camada.get_cell_source_id(celula)
		if id < 0:
			continue
		var fonte := camada.tile_set.get_source(id) as TileSetAtlasSource
		if fonte != null and fonte.texture.resource_path.get_file() == "Buildings.png" \
				and camada.get_cell_atlas_coords(celula) == receita["celula"]:
			return true
	return false


## O pior lugar da fase para a câmera da Cacau: quantas luzes da fase (fora as
## que andam com ela) caem na tela de uma vez.
func _mais_luzes_na_tela(cena: Node) -> int:
	var player := cena.get_node("Player") as Node2D
	var zoom := (player.get_node("Camera2D") as Camera2D).zoom
	var tela := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")) / zoom
	var luzes: Array[PointLight2D] = []
	_luzes_2d(cena, luzes)
	var caixas: Array[Rect2] = []
	for luz in luzes:
		if not luz.enabled or not luz.is_visible_in_tree() or luz.texture == null or player.is_ancestor_of(luz):
			continue
		var tamanho := luz.texture.get_size() * luz.texture_scale * luz.global_transform.get_scale().abs()
		caixas.append(Rect2(luz.to_global(luz.offset) - tamanho * 0.5, tamanho))

	var area := (cena.get_node("LimitesDaCamera") as ReferenceRect).get_global_rect()
	var mais := 0
	var y := area.position.y
	while true:
		var x := area.position.x
		while true:
			var vista := Rect2(Vector2(x, y), tela)
			mais = maxi(mais, caixas.filter(func(c: Rect2) -> bool: return c.intersects(vista)).size())
			if x + tela.x >= area.end.x:
				break
			x = minf(x + 16.0, area.end.x - tela.x)
		if y + tela.y >= area.end.y:
			break
		y = minf(y + 16.0, area.end.y - tela.y)
	return mais


func _luzes_2d(no: Node, lista: Array[PointLight2D]) -> void:
	if no is PointLight2D:
		lista.append(no)
	for filho in no.get_children(true):
		_luzes_2d(filho, lista)


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


## O arquivo da música que a TrilhaSonora está tocando ("" no silêncio).
func _musica_tocando() -> String:
	var musica := TrilhaSonora.musica_atual()
	return musica.resource_path if musica != null else ""


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
