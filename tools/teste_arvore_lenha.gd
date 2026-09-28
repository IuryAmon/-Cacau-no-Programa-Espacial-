extends Node

# Teste da árvore da lenha do pátio (scripts/fases/arvore_lenha.gd) com a
# fase 1.2 de verdade e o bumerangue de verdade:
#
#   * o pátio não tem mais tora no chão: as três estão na copa;
#   * um arremesso real no tronco derruba UMA tora — a volta do mesmo
#     bumerangue pela árvore sacode, mas não derruba outra;
#   * a copa verga e volta exatamente ao lugar; as folhas pousam no chão, não
#     atravessam o terreno, e somem;
#   * a tora cai girando, não dá para recolher no ar e assenta deitada no chão,
#     embaixo do galho de onde saiu;
#   * nunca caem mais que três;
#   * sair da fase e voltar mantém as toras caídas e as recolhidas;
#   * uma queima que falha devolve à copa SÓ as toras que viraram cinza — e
#     elas voltam a cair, sem se acharem já recolhidas.
#
#   godot --headless --path . res://tools/teste_arvore_lenha.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva imagens da pancada e da
# queda na pasta, para conferir o efeito a olho.

const FASE := "res://scenes/fases/fase1_2_exterior.tscn"
const CHAO_DO_PATIO := 512.0

var _falhas := 0
var _pasta_capturas := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			_pasta_capturas = arg.trim_prefix("--capturas=")
	await get_tree().process_frame

	await _testar_arremesso_de_verdade()
	await _testar_limite_de_tres()
	await _testar_voltar_para_a_fase()
	await _testar_queima_perdida()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


# ─────────────────────────────────────────────────────────────

func _testar_arremesso_de_verdade() -> void:
	print("\n--- ARREMESSO NO TRONCO ---")
	var fase := await _abrir()
	var arvore: ArvoreLenha = fase.get_node_or_null("Patio/ArvoreLenha")
	_checar(arvore != null, "a árvore da lenha mora no pátio")
	if arvore == null:
		return
	_checar(arvore.is_in_group("alvo_bumerangue"), "é alvo de bumerangue")
	_checar(arvore.arvore == fase.get_node("Terreno/Arvore"), "balança o TileMapLayer da árvore")
	_checar(_toras().is_empty(), "nenhuma tora largada no chão do pátio")
	_checar(arvore.toras_na_copa() == 3, "as três toras estão na copa")

	var desenho: Node2D = arvore.arvore
	var parado := desenho.transform
	var player: CharacterBody2D = fase.get_node("Player")
	var frente: Sprite2D = desenho.get_node_or_null("Frente")
	_checar(frente != null, "a parte da frente da copa é filha do desenho que verga")
	_checar(not desenho.z_as_relative and desenho.z_index < player.z_index,
		"o salgueiro fica atrás da personagem")
	if frente:
		_checar(not frente.z_as_relative and frente.z_index > player.z_index,
			"e a parte da frente, na frente dela")
		# A Frente cobre exatamente o mesmo retângulo que os tiles da árvore.
		var tiles: Rect2i = (desenho as TileMapLayer).get_used_rect()
		var tile := Vector2((desenho as TileMapLayer).tile_set.tile_size)
		var ret_tiles := Rect2(Vector2(tiles.position) * tile, Vector2(tiles.size) * tile)
		var ret_frente := Rect2(frente.position, frente.texture.get_size())
		_checar(ret_frente.encloses(ret_tiles) and ret_frente.position == ret_tiles.position,
			"a frente está alinhada com os tiles da árvore (%s, %s)" % [ret_frente, ret_tiles])
	var frente_parada := frente.global_transform if frente else Transform2D.IDENTITY
	var ferramentas: FerramentasPlayer = player.get_node("Ferramentas")
	Progresso._habilidades["bumerangue"] = true
	# Parada à esquerda do tronco, de pé no chão, arremesso reto na altura da
	# mão. Sem física: o teste é da árvore, não do chão (a cápsula do corpo tem
	# 72 de altura centrada na origem, então o centro fica 36 acima do chão).
	player.set_physics_process(false)
	player.global_position = Vector2(440, CHAO_DO_PATIO - 36)
	player.velocity = Vector2.ZERO
	await _capturar("1_antes")
	var bumerangue := Bumerangue.lancar(player, ferramentas, Vector2.RIGHT)

	var caindo: Madeira = null
	var vergou := false
	var frente_vergou := false
	var folhas_no_chao := true
	var tentou_no_ar := false
	var capturou_queda := false
	var espera := 0.0
	while espera < 3.0:
		await get_tree().process_frame
		espera += get_process_delta_time()
		if caindo == null and not _toras().is_empty():
			caindo = _toras()[0]
			_checar(caindo.esta_caindo(), "a tora nasce caindo")
			_checar(caindo.global_position.y < CHAO_DO_PATIO - 100.0, "e nasce lá em cima, na copa")
			await _capturar("2_pancada")
		if not desenho.transform.is_equal_approx(parado):
			vergou = true
		if frente and not frente.global_transform.is_equal_approx(frente_parada):
			frente_vergou = true
		for folhas in _folhas_de(arvore):
			for folha in folhas._folhas:
				if folha["pos"].y > CHAO_DO_PATIO + 0.5:
					folhas_no_chao = false
		if caindo and caindo.esta_caindo() and not tentou_no_ar:
			# No ar não se recolhe: E apertado com ela "perto" não faz nada.
			tentou_no_ar = true
			caindo._jogador_perto = true
			Input.action_press(Interacao.ACAO)
			await get_tree().process_frame
			Input.action_release(Interacao.ACAO)
			_checar(is_instance_valid(caindo) and Madeira.quantidade_no_inventario() == 0,
				"tora no ar não vai para o inventário")
			caindo._jogador_perto = false
		if caindo and caindo.esta_caindo() and not capturou_queda \
				and caindo.global_position.y > CHAO_DO_PATIO - 80.0:
			capturou_queda = true
			await _capturar("3_queda")
	_checar(not is_instance_valid(bumerangue) or not bumerangue.is_physics_processing(),
		"o bumerangue voltou para a mão")
	_checar(vergou, "a copa vergou com a pancada")
	if frente:
		_checar(frente_vergou, "a parte da frente vergou junto")
	_checar(folhas_no_chao, "nenhuma folha passou do chão")
	_checar(_toras().size() == 1, "um arremesso derruba UMA tora (ida e volta pela árvore)")
	_checar(arvore.toras_na_copa() == 2, "sobram duas na copa")

	if caindo:
		_checar(not caindo.esta_caindo(), "a tora assentou")
		_checar(absf(caindo.global_position.y + caindo.meia_altura() - CHAO_DO_PATIO) < 1.0,
			"deitada rente ao chão (y=%.1f)" % caindo.global_position.y)
		_checar(is_zero_approx(caindo.rotation), "e deitada reta")
		_checar(caindo.z_index == 0 and caindo.z_as_relative, "de volta à camada normal")
		var galho_x := _galhos_x(arvore)
		_checar(galho_x.has(roundi(caindo.global_position.x)), "embaixo de um dos galhos")
		await _capturar("4_no_chao")

	await _esperar(1.0)
	_checar(desenho.transform.is_equal_approx(parado), "a copa voltou exatamente ao lugar")
	_checar(desenho.modulate.is_equal_approx(Color.WHITE), "e à cor normal")
	if frente:
		_checar(frente.global_transform.is_equal_approx(frente_parada),
			"a parte da frente também voltou ao lugar")
	await _esperar(4.0)
	_checar(_folhas_de(arvore).is_empty(),
		"as folhas somem sozinhas")
	await _fechar(fase)


func _testar_limite_de_tres() -> void:
	print("\n--- SÓ TRÊS TORAS ---")
	var fase := await _abrir()
	var arvore: ArvoreLenha = fase.get_node("Patio/ArvoreLenha")
	_checar(_toras().size() == 1, "a tora do teste anterior continua no chão")
	for i in 5:
		arvore.atingir_bumerangue()
		await _esperar(0.25)
	await _esperar(1.0)
	var toras := _toras()
	_checar(toras.size() == 3, "cinco pancadas depois, só três toras (%d)" % toras.size())
	_checar(arvore.toras_na_copa() == 0, "a copa ficou sem lenha")
	var xs: Array[int] = []
	for tora in toras:
		xs.append(roundi(tora.global_position.x))
	xs.sort()
	var separadas := xs.size() == 3 and xs[1] - xs[0] >= 78 and xs[2] - xs[1] >= 78
	_checar(separadas, "cada uma embaixo de um galho, sem encavalar (%s)" % str(xs))
	await _capturar("5_tres_toras")

	# Recolhe duas: uma fica no chão para o próximo teste.
	for tora in toras.slice(0, 2):
		tora.coletar()
	await get_tree().process_frame
	_checar(Madeira.quantidade_no_inventario() == 2, "duas recolhidas vão para o inventário")
	await _fechar(fase)


func _testar_voltar_para_a_fase() -> void:
	print("\n--- SAIR E VOLTAR ---")
	var fase := await _abrir()
	var arvore: ArvoreLenha = fase.get_node("Patio/ArvoreLenha")
	await get_tree().process_frame
	_checar(_toras().size() == 1, "a que ficou no chão reaparece (as recolhidas não)")
	_checar(arvore.toras_na_copa() == 0, "e a copa continua vazia")
	arvore.atingir_bumerangue()
	await _esperar(1.0)
	_checar(_toras().size() == 1, "bater de novo não derruba mais nada")
	await _fechar(fase)


func _testar_queima_perdida() -> void:
	print("\n--- QUEIMA PERDIDA ---")
	var fase := await _abrir()
	var arvore: ArvoreLenha = fase.get_node("Patio/ArvoreLenha")
	var retorta: RetortaCarbonizacao = fase.get_node("Patio/Retorta")
	await get_tree().process_frame

	# Duas toras no forno; a terceira continua no chão.
	retorta._abastecer()
	retorta._abastecer()
	_checar(retorta._madeiras_no_forno == 2 and Madeira.quantidade_no_inventario() == 0,
		"duas toras foram para a fornalha")
	retorta._on_painel_terminado(false, false)
	await get_tree().process_frame
	_checar(arvore.toras_na_copa() == 2, "a queima perdida devolve à copa só as duas que viraram cinza")
	_checar(_toras().size() == 1, "a que estava no chão não volta para a copa")

	# Agora a da mão: recolhida, ela não é perdida numa segunda queima.
	_toras()[0].coletar()
	await get_tree().process_frame
	retorta._on_painel_terminado(false, false)
	_checar(arvore.toras_na_copa() == 2, "tora no inventário não volta para a copa")

	for i in 3:
		arvore.atingir_bumerangue()
		await _esperar(0.25)
	await _esperar(1.0)
	_checar(_toras().size() == 2, "as devolvidas caem de novo, e só elas (%d)" % _toras().size())
	_checar(arvore.toras_na_copa() == 0, "a copa esvazia de novo")
	for tora in _toras():
		tora.coletar()
	await get_tree().process_frame
	_checar(Madeira.quantidade_no_inventario() == 3, "e voltam a ser recolhidas: três na mão")
	await _fechar(fase)

	# Recolhidas de novo, continuam recolhidas numa próxima visita.
	fase = await _abrir()
	await get_tree().process_frame
	_checar(_toras().is_empty(), "sair e voltar não duplica a lenha")
	await _fechar(fase)


# ─────────────────────────────────────────────────────────────

func _toras() -> Array[Madeira]:
	var toras: Array[Madeira] = []
	for tora in get_tree().get_nodes_in_group(Madeira.GRUPO):
		if tora is Madeira and not tora.is_queued_for_deletion():
			toras.append(tora)
	return toras


func _folhas_de(arvore: ArvoreLenha) -> Array[FolhasCaindo]:
	var nos: Array[FolhasCaindo] = []
	for filho in arvore.get_children():
		if filho is FolhasCaindo and not filho.is_queued_for_deletion():
			nos.append(filho)
	return nos


func _galhos_x(arvore: ArvoreLenha) -> Array[int]:
	var xs: Array[int] = []
	for galho in arvore._galhos():
		xs.append(roundi(galho.global_position.x))
	return xs


func _abrir() -> Node:
	var fase: Node = (load(FASE) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(fase)
	await _quadros(2)
	# A personagem fica parada fora da física: o teste é da árvore, e o chão
	# pintado no pátio pode estar sem colisão enquanto a arte é refeita — ela
	# cairia, e morrer recarrega a cena atual (este teste) no meio do caminho.
	var player := fase.get_node("Player") as CharacterBody2D
	player.set_physics_process(false)
	player.global_position = Vector2(320, CHAO_DO_PATIO - 36)
	await get_tree().physics_frame
	await _esperar(0.3)
	return fase


func _fechar(fase: Node) -> void:
	fase.queue_free()
	await _quadros(2)


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos, true).timeout


func _capturando() -> bool:
	return not _pasta_capturas.is_empty() and DisplayServer.get_name() != "headless"


func _capturar(nome: String) -> void:
	if not _capturando():
		return
	await RenderingServer.frame_post_draw
	var imagem := get_viewport().get_texture().get_image()
	imagem.save_png(_pasta_capturas.path_join(nome + ".png"))
