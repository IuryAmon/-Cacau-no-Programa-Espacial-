extends Node

# Teste do HUD de jogo: a vida (scripts/ui/hud_vital.gd), a mochila
# (scripts/ui/mochila_hud.gd) e os equipamentos (scripts/ui/equipamentos_hud.gd),
# as três peças feitas da mesma ficha (EstiloHUD.ficha).
#
#   * a vida da Cacau é o NOME dela na tabela periódica: Ca, Ca e U, uma ficha
#     por vida, com o número atômico de cada elemento;
#   * levar dano arranca a ÚLTIMA ficha do nome, curar a devolve, e a primeira
#     vez que a vida é dita não anima nada;
#   * com uma ficha só, a peça entra em perigo (o rosto machucado, a ficha
#     pulsando);
#   * no jogo, a peça fica inteira dentro da tela, no canto de cima à esquerda,
#     ouve o player e a lista de objetivos começa logo abaixo dela;
#   * a nave do simulador não tem fichas: é barra e porcentagem;
#   * os equipamentos se chamam EQUIPAMENTOS, nascem encostados no canto de
#     baixo à direita e empurram os antigos para a esquerda.
#
#   godot --headless --path . res://tools/teste_hud.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva imagens do HUD no pátio
# (fundo claro), no dano, no perigo e na cura, para conferir a olho.

const VIDA := "res://scenes/ui/hud_vital.tscn"
const MUNDO := "res://scenes/world1.tscn"
const CAMINHO_DA_VIDA := "Player/CanvasLayer/HealthHUD/HudVital"

var _falhas := 0
var _pasta_capturas := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			_pasta_capturas = arg.trim_prefix("--capturas=")
	await get_tree().process_frame

	await _testar_nome_em_fichas()
	await _testar_dano_e_cura()
	await _testar_nave()
	await _testar_equipamentos()
	await _testar_no_jogo()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


# ─────────────────────────────────────────────────────────────
# A vida é o nome dela
# ─────────────────────────────────────────────────────────────

func _testar_nome_em_fichas() -> void:
	print("\n--- A VIDA DA CACAU E O NOME DELA NA TABELA PERIODICA ---")
	var vida := await _nova_vida()
	vida.definir_vida_maxima(3)

	var simbolos := vida.simbolos()
	_checar(simbolos == PackedStringArray(["Ca", "Ca", "U"]),
		"tres fichas: calcio, calcio e uranio %s" % [simbolos])
	_checar("".join(simbolos).to_upper() == "CACAU", "lidas em ordem, elas escrevem CACAU")
	_checar(HudVital.ELEMENTOS[0][1] == 20 and HudVital.ELEMENTOS[2][1] == 92,
		"com o numero atomico certo (Ca 20, U 92)")
	_checar(vida.fichas_cheias() == 3, "vida cheia, as tres fichas estao la")

	# Da esquerda para a direita, sem se cruzar, dentro do retangulo do no.
	var quadro := Rect2(Vector2.ZERO, HudVital.TAMANHO_BASE)
	var em_fila := true
	for i in 3:
		var casa := vida.retangulo_da_ficha(i)
		if not quadro.encloses(casa):
			em_fila = false
		if i > 0 and casa.position.x < vida.retangulo_da_ficha(i - 1).end.x:
			em_fila = false
	_checar(em_fila, "as fichas ficam em fila, dentro da peca")
	_checar(is_equal_approx(vida.retangulo_da_ficha(0).size.x, vida.retangulo_da_ficha(0).size.y),
		"cada ficha e um quadrado")
	_checar(vida.custom_minimum_size.is_equal_approx(HudVital.TAMANHO_BASE),
		"e a peca tem o tamanho das tres %s" % vida.custom_minimum_size)

	vida.queue_free()
	await get_tree().process_frame


func _testar_dano_e_cura() -> void:
	print("\n--- DANO ARRANCA A ULTIMA FICHA, CURA DEVOLVE ---")
	var vida := await _nova_vida()
	vida.definir_vida_maxima(3)
	_checar(not _animando(vida), "a primeira vez que a vida e dita nao anima nada")

	vida.definir_vida(2)
	_checar(vida.fichas_cheias() == 2 and not vida._fichas[2]["cheia"]
		and vida._fichas[0]["cheia"] and vida._fichas[1]["cheia"],
		"um dano tira o U, a ultima ficha do nome")
	_checar(vida._fichas[2]["queda"] >= 0.0, "e ela sai caindo")
	_checar(vida._estado() == HudVital.Estado.ALERTA, "com duas fichas ainda nao e perigo")
	await _esperar_o_jogo(HudVital.T_QUEDA + 0.6, func() -> bool: return not _animando(vida))
	_checar(not _animando(vida), "a queda acaba e a peca volta a ficar parada")

	vida.definir_vida(1)
	_checar(vida.fichas_cheias() == 1 and vida._fichas[0]["cheia"],
		"outro dano tira o segundo Ca: sobra o primeiro")
	_checar(vida._estado() == HudVital.Estado.CRITICO, "com uma ficha so, e perigo")

	vida.definir_vida(0)
	_checar(vida.fichas_cheias() == 0, "sem vida, nenhuma ficha")

	# De volta do zero (a Cacau renasce): as tres brotam, uma depois da outra.
	vida.definir_vida(3)
	_checar(vida.fichas_cheias() == 3, "a vida inteira de volta traz as tres fichas")
	_checar(vida._fichas[0]["brota"] >= 0.0 and vida._fichas[2]["brota"] >= 0.0
		and vida._fichas[2]["atraso"] > vida._fichas[0]["atraso"],
		"elas brotam em fila, da primeira para a ultima")
	await _esperar_o_jogo(HudVital.T_BROTAR + 0.8, func() -> bool: return not _animando(vida))
	_checar(not _animando(vida), "e assentam")

	# Cura de uma vida so: so a ficha que faltava se mexe.
	vida.definir_vida(2)
	await _esperar_o_jogo(HudVital.T_QUEDA + 0.6, func() -> bool: return not _animando(vida))
	vida.definir_vida(3)
	_checar(vida._fichas[2]["brota"] >= 0.0 and vida._fichas[0]["brota"] < 0.0
		and vida._fichas[1]["brota"] < 0.0, "curar uma vida faz brotar so o U")

	vida.queue_free()
	await get_tree().process_frame


func _testar_nave() -> void:
	print("\n--- A NAVE DO SIMULADOR: BARRA, E NAO FICHAS ---")
	var nave := await _nova_vida()
	nave.modo = HudVital.Modo.NAVE
	nave.segmentos = 0
	nave.mostrar_porcentagem = true
	nave.definir_vida(100.0, 100.0)
	nave.definir_vida(62.0)
	_checar(nave._quantas_fichas() == 0 and nave.simbolos().is_empty(), "a nave nao tem fichas de vida")
	_checar(nave._texto_valor() == "62%", "ela mostra o casco em porcentagem")
	_checar(nave._estado() == HudVital.Estado.OK, "62% ainda nao e alerta")
	nave.definir_vida(18.0)
	_checar(nave._estado() == HudVital.Estado.CRITICO, "18% e perigo")
	_checar(HudVital.BARRA.end.x <= HudVital.TAMANHO_BASE.x - HudVital.RESPIRO.x + 0.5,
		"a barra cabe na largura da peca")
	nave.queue_free()
	await get_tree().process_frame

	var simulador := load("res://scenes/simulador/simulador_lua.tscn") as PackedScene
	var estado := simulador.get_state()
	var achou := false
	for i in estado.get_node_count():
		if estado.get_node_name(i) == &"HudNave":
			achou = true
	_checar(achou, "o simulador usa a mesma peca (HudNave)")


# ─────────────────────────────────────────────────────────────
# Os equipamentos
# ─────────────────────────────────────────────────────────────

func _testar_equipamentos() -> void:
	print("\n--- OS EQUIPAMENTOS ---")
	var ancora := Control.new()
	ancora.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(ancora)
	var peca := EquipamentosHUD.new()
	ancora.add_child(peca)
	await get_tree().process_frame

	_checar(EquipamentosHUD.ROTULO == "EQUIPAMENTOS", "a peca se chama EQUIPAMENTOS")
	_checar(not peca.visible and peca.quantidade() == 0, "sem equipamento nenhum, ela nem aparece")

	var entrada := peca.ponto_de_entrada()
	peca.equipar(_ficha_de("macarico"), false)
	_checar(peca.visible and peca.tem("macarico"), "o primeiro equipamento a faz aparecer")
	var primeiro: Dictionary = peca._equipamentos[0]
	_checar(is_equal_approx(peca.global_position.x + peca.size.x - primeiro["recuo"], entrada.x),
		"ele fica no ponto de entrada, encostado no canto")
	_checar(primeiro["tecla"] == "E", "com a tecla dele embaixo (E)")

	peca.equipar(_ficha_de("bumerangue"), true)
	_checar(peca.quantidade() == 2 and peca.ponto_de_entrada().is_equal_approx(entrada),
		"o segundo entra no mesmo ponto")
	await _esperar_o_jogo(1.2, func() -> bool:
		return is_equal_approx(peca._equipamentos[0]["recuo"],
			EquipamentosHUD.LADO * 1.5 + EquipamentosHUD.VAO))
	_checar(is_equal_approx(peca._equipamentos[0]["recuo"],
			EquipamentosHUD.LADO * 1.5 + EquipamentosHUD.VAO)
		and is_equal_approx(peca._equipamentos[1]["recuo"], EquipamentosHUD.LADO * 0.5),
		"e o antigo escorrega uma casa para a esquerda")

	peca.equipar(_ficha_de("bumerangue"), true)
	_checar(peca.quantidade() == 2, "equipamento repetido nao entra duas vezes")
	peca.destacar("macarico")
	peca.destacar("nao_existe")
	_checar(peca._equipamentos[0]["pulso"] > 0.0, "usar o equipamento no mundo faz a ficha dele pular")

	ancora.queue_free()
	await get_tree().process_frame


func _ficha_de(id: String) -> Dictionary:
	var ficha := CatalogoFerramentas.dados(id)
	ficha["tecla"] = CatalogoFerramentas.tecla(id)
	ficha["acao"] = CatalogoFerramentas.acao(id)
	return ficha


# ─────────────────────────────────────────────────────────────
# No jogo
# ─────────────────────────────────────────────────────────────

func _testar_no_jogo() -> void:
	print("\n--- NO JOGO (world1) ---")
	var mundo: Node = (load(MUNDO) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(mundo)
	await _quadros(3)
	# A personagem fica parada fora da física: cair ou morrer recarregaria a
	# cena atual (este teste) no meio do caminho.
	var player := mundo.get_node("Player") as CharacterBody2D
	player.set_physics_process(false)
	await _quadros(2)

	var vida := mundo.get_node_or_null(CAMINHO_DA_VIDA) as HudVital
	_checar(vida != null, "a vida mora no player (%s)" % CAMINHO_DA_VIDA)
	if vida == null:
		mundo.queue_free()
		return
	_checar(vida.modo == HudVital.Modo.PERSONAGEM and vida.fichas_cheias() == player.max_health,
		"e nasce com uma ficha por vida (%d)" % player.max_health)

	# Inteira dentro da tela, com folga, no canto de cima à esquerda.
	var tela := get_viewport().get_visible_rect()
	var transformacao := vida.get_global_transform()
	var dentro := true
	for i in 3:
		var casa: Rect2 = transformacao * vida.retangulo_da_ficha(i)
		if not tela.grow(-12.0).encloses(casa):
			dentro = false
	var canto: Rect2 = transformacao * Rect2(Vector2.ZERO, vida.size)
	_checar(dentro, "as fichas ficam dentro da tela, com folga da borda")
	_checar(canto.end.x < tela.size.x * 0.5 and canto.end.y < tela.size.y * 0.5,
		"no canto de cima a esquerda")
	# A lista de objetivos procura a vida na cena atual do jogo: por um
	# instante, a cena atual é o mundo aberto pelo teste.
	var cena_do_teste := get_tree().current_scene
	get_tree().current_scene = mundo
	var topo_da_lista := Objetivos._topo_livre()
	get_tree().current_scene = cena_do_teste
	_checar(is_equal_approx(topo_da_lista,
			vida.get_global_rect().end.y + ObjetivosHUD.FOLGA_SOB_A_VIDA),
		"e a lista de objetivos comeca logo abaixo dela (%.0f)" % topo_da_lista)

	# A mochila e os equipamentos, para a foto: nada disso abre ficha de coleta.
	var hud := Inventario.tela_hud_referencia
	if _capturando() and hud != null:
		hud.exibir_item_na_tela("Cilindro_de_Hidrogenio", "Cilíndro de Hidrogênio (Combustível)",
			AmostraChonps.textura("H"))
		hud.exibir_item_na_tela("carvao_vegetal", "Carvão Vegetal", AmostraChonps.textura("C"))
		FerramentasHUD._equipar("macarico", false)
		FerramentasHUD._equipar("bumerangue", false)
	await _esperar_o_jogo(1.6)
	await _capturar("1_vida_cheia")

	# O player machucado e curado: a peça acompanha.
	player.take_damage(1)
	_checar(vida.fichas_cheias() == player.max_health - 1 and not vida._fichas[2]["cheia"],
		"o player leva dano e a ultima ficha cai")
	await _esperar_o_jogo(0.12)
	await _capturar("2_dano_branco")
	await _esperar_o_jogo(0.22)
	await _capturar("3_dano_caindo")
	await _esperar_o_jogo(1.2)
	await _capturar("4_duas_vidas")

	player.current_health = 1
	player.health_changed.emit(player.current_health)
	_checar(vida.fichas_cheias() == 1 and vida._estado() == HudVital.Estado.CRITICO,
		"com uma vida, a peca entra em perigo")
	await _esperar_o_jogo(1.0)
	await _capturar("5_perigo")

	player.curar(player.max_health)
	_checar(vida.fichas_cheias() == player.max_health, "curada, as fichas voltam todas")
	await _esperar_o_jogo(0.16)
	await _capturar("6_cura_brotando")
	await _esperar_o_jogo(1.4)
	await _capturar("7_curada")

	player.current_health = player.max_health
	mundo.queue_free()
	await _quadros(2)


# ─────────────────────────────────────────────────────────────

func _nova_vida() -> HudVital:
	var vida: HudVital = (load(VIDA) as PackedScene).instantiate()
	get_tree().root.add_child(vida)
	await get_tree().process_frame
	return vida


## Alguma ficha de vida ainda está caindo, brotando ou esperando a vez?
func _animando(vida: HudVital) -> bool:
	for ficha in vida._fichas:
		if ficha["queda"] >= 0.0 or ficha["brota"] >= 0.0 or ficha["atraso"] > 0.0:
			return true
	return false


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Espera em tempo de JOGO (somando o delta), ou até a condição valer.
func _esperar_o_jogo(segundos: float, condicao: Callable = Callable()) -> void:
	var passado := 0.0
	while passado < segundos:
		await get_tree().process_frame
		passado += get_process_delta_time()
		if condicao.is_valid() and condicao.call():
			return


func _capturando() -> bool:
	return not _pasta_capturas.is_empty() and DisplayServer.get_name() != "headless"


func _capturar(nome: String) -> void:
	if not _capturando():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_pasta_capturas.path_join(nome + ".png"))
