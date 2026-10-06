extends Node

# Teste das notas do caderno (scripts/fases/nota_caderno.gd, o que mudou em
# scripts/paginas_caderno.gd e scripts/caderno.gd, scripts/ui/caderno_aviso.gd
# e a marca de nota nova do scripts/ui/caderno_icone.gd):
#
#   * o caderno começa só até a página 3, e as páginas do átomo (4 a 7) são
#     uma nota só, "O Átomo";
#   * a nota entra no lugar dela, com o número das faces de sempre, e traz as
#     duas páginas duplas de uma vez;
#   * a nota mora no world1, dentro de NotasDoCaderno, no chão, atrás da Cacau
#     e fora do canto em que o HUD rouba o clique no editor;
#   * o botão E só aparece com a Cacau por perto;
#   * o E pega a folha: ela some do mapa, voa até o ícone do caderno e a página
#     entra no caderno, que já fica aberto nela;
#   * quando a folha chega, o ícone pula e acende a marca de nota nova, e o
#     aviso sobe em cima dele com o título e as páginas, dentro da tela e com
#     todas as letras na fonte;
#   * M abre o caderno na primeira página da nota nova, e a marca e o aviso
#     somem; D vira para a segunda;
#   * o aviso sai sozinho depois de lido, e a marca de nota nova fica até o
#     caderno ser aberto;
#   * recarregar a cena não traz a nota de volta;
#   * com a ficha de coleta na tela o aviso espera ela fechar.
#
#   godot --headless --path . res://tools/teste_notas_caderno.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva a folha no mapa com o
# botão, o voo, o aviso e o caderno aberto na nota, para conferir a olho.

const MUNDO := "res://scenes/world1.tscn"
## No editor, o HUD da Cacau é desenhado aqui e ganha o clique (coordenadas do
## editor, que são as globais da cena).
const CANTO_DO_HUD_NO_EDITOR := Rect2(0, 0, 1600, 900)

var _falhas := 0
var _pasta_capturas := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			_pasta_capturas = arg.trim_prefix("--capturas=")
	await get_tree().process_frame

	_testar_caderno_do_comeco()
	_testar_numeracao()
	await _testar_no_mapa_e_pegar()
	await _testar_recarregar()
	await _testar_aviso_espera()
	PaginasCaderno.esquecer_notas()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


# ─────────────────────────────────────────────────────────────

func _testar_caderno_do_comeco() -> void:
	print("\n--- O CADERNO DO COMEÇO ---")
	PaginasCaderno.esquecer_notas()
	_checar(PaginasCaderno.quantas() == 2 and PaginasCaderno.numero(1, 1) == 3,
		"o caderno começa só até a página 3 (%d páginas duplas)" % PaginasCaderno.quantas())
	_checar(PaginasCaderno.faces(0)[1].get("tipo") == "rosto" \
		and PaginasCaderno.faces(1)[0].get("tipo") == "epigrafe",
		"com a folha de rosto e a epígrafe")
	_checar(PaginasCaderno.faces(2) == [{}, {}], "e nada depois dela")

	var notas := PaginasCaderno.NOTAS
	_checar(notas.keys() == ["atomo"], "a nota é uma só: a do átomo %s" % [notas.keys()])
	_checar(PaginasCaderno.titulo_da_nota("atomo") == "O Átomo" \
		and PaginasCaderno.numeros_da_nota("atomo") == Vector2i(4, 7),
		"\"O Átomo\" traz as páginas 4 a 7")
	var paginas := {}
	var boas := true
	for nota in notas:
		if PaginasCaderno.titulo_da_nota(nota).is_empty() or PaginasCaderno.paginas_da_nota(nota).is_empty():
			boas = false
		for pagina: int in PaginasCaderno.paginas_da_nota(nota):
			if paginas.has(pagina) or pagina < 0 or pagina >= PaginasCaderno.PAGINAS.size():
				boas = false
			paginas[pagina] = true
	_checar(boas, "cada nota tem título e páginas só dela, que existem")
	_checar(PaginasCaderno.PAGINAS[2][0].get("titulo") == PaginasCaderno.titulo_da_nota("atomo") \
		and not PaginasCaderno.PAGINAS[3][0].has("titulo"),
		"o título da nota é o da primeira página dela, e a segunda não tem título")
	var fonte := CadernoAviso.FONTE
	var faltando := ""
	var textos: Array = [CadernoAviso.CHAPEU, "páginas 0123456789 e a"]
	for nota in notas:
		textos.append(PaginasCaderno.titulo_da_nota(nota))
	for texto in textos:
		for c in String(texto):
			if c != " " and not fonte.has_char(c.unicode_at(0)) and not faltando.contains(c):
				faltando += c
	_checar(faltando.is_empty(), "toda letra do aviso existe na fonte [%s]" % faltando)


func _testar_numeracao() -> void:
	print("\n--- A NOTA NO LUGAR DELA ---")
	PaginasCaderno.esquecer_notas()
	_checar(not PaginasCaderno.guardar_nota("nao_existe"), "nota que não existe não entra")
	_checar(not PaginasCaderno.guardar_nota("atomistica"), "a atomística não é mais uma nota à parte")
	_checar(PaginasCaderno.lugar_da_nota("atomo") == -1, "o átomo ainda não está no caderno")
	_checar(PaginasCaderno.guardar_nota("atomo") and PaginasCaderno.quantas() == 4,
		"achando a nota, o caderno ganha as duas páginas duplas dela de uma vez")
	_checar(PaginasCaderno.lugar_da_nota("atomo") == 2 \
		and PaginasCaderno.faces(2)[0].get("titulo") == "O Átomo" \
		and PaginasCaderno.faces(3)[0].get("arte") == PaginasCaderno.ARTE_HIDROGENIO,
		"ela vem logo depois da epígrafe: o átomo e, na folha seguinte, a caixa do hidrogênio")
	_checar(PaginasCaderno.numero(1, 1) == 3 and PaginasCaderno.numero(2, 0) == 4 \
		and PaginasCaderno.numero(3, 1) == 7,
		"com os números de sempre: 4, 5, 6, 7")
	_checar(not PaginasCaderno.guardar_nota("atomo") and PaginasCaderno.notas_achadas() == 1,
		"a mesma nota não entra duas vezes")
	PaginasCaderno.esquecer_notas()


func _testar_no_mapa_e_pegar() -> void:
	print("\n--- A NOTA NO WORLD1 ---")
	var mundo := await _abrir()
	var grupo := mundo.get_node_or_null("NotasDoCaderno")
	_checar(grupo != null, "a nota mora no world1, dentro de NotasDoCaderno")
	if grupo == null:
		return
	var player := mundo.get_node("Player") as CharacterBody2D
	var notas := {}
	for filho in grupo.get_children():
		if filho is NotaCaderno:
			notas[filho.nota] = filho
	_checar(grupo.get_child_count() == 1 and notas.keys() == ["atomo"],
		"é uma só: a do átomo %s" % [notas.keys()])
	if not notas.has("atomo"):
		return
	var espaco := (mundo as Node2D).get_world_2d().direct_space_state
	for nome in notas:
		var nota: NotaCaderno = notas[nome]
		var raio := PhysicsRayQueryParameters2D.create(nota.global_position + Vector2(0, -24),
			nota.global_position + Vector2(0, 24))
		raio.exclude = [player.get_rid()]
		var batida := espaco.intersect_ray(raio)
		var no_chao: bool = not batida.is_empty() and absf(batida["position"].y - nota.global_position.y) <= 2.0
		_checar(no_chao, "%s: no chão (%s)" % [nota.name, nota.position])
		_checar(not CANTO_DO_HUD_NO_EDITOR.has_point(nota.global_position),
			"%s: fora do canto em que o HUD rouba o clique no editor" % nota.name)
		_checar(nota.z_index < player.z_index and nota.z_index > 0,
			"%s: atrás da Cacau e na frente do chão" % nota.name)
		_checar(not (nota.get_node("Dica") as CanvasItem).visible, "%s: de longe, sem botão" % nota.name)
		var arte := nota.caixa_da_arte()
		_checar(arte.end.y < 0.0 and arte.position == arte.position.round() and arte.size == Vector2(42, 48),
			"%s: a folha flutua acima do chão, em 2×, no pixel inteiro (%s)" % [nota.name, arte])

	print("\n--- PEGAR A NOTA ---")
	var atomo: NotaCaderno = notas["atomo"]
	await _chegar_perto(player, atomo)
	var dica := atomo.get_node("Dica") as CanvasItem
	_checar(dica.visible, "de perto, o botão E aparece em cima da folha")
	_checar(dica.global_position.y < atomo.to_global(atomo.caixa_da_arte().position).y,
		"o botão fica acima dela")
	await _esperar(0.4)
	_checar(_icone().visible and is_equal_approx(_icone().modulate.a, 1.0), "o ícone do caderno está na tela")
	_checar(not _icone().novidade and not Caderno.aviso().ocupado(), "sem marca de nota nova nem aviso")
	await _capturar("1_folha_com_botao")

	var avisadas: Array = []
	Caderno.nota_guardada.connect(func(n: String) -> void: avisadas.append(n))
	await _apertar_e()
	_checar(Caderno.tem_nota("atomo") and avisadas == ["atomo"], "o E pega a folha: a nota entra no caderno")
	_checar(not is_instance_valid(atomo), "a folha some do mapa")
	_checar(PaginasCaderno.quantas() == 4 and Caderno.livro().pagina() == PaginasCaderno.lugar_da_nota("atomo"),
		"o caderno ganha as páginas e já fica aberto na primeira delas")
	var voo := Caderno.get_node_or_null("VooDeItem") as VooDeItem
	_checar(voo != null and voo.textura == CadernoAviso.ARTE, "a folha voa para o ícone do caderno")
	_checar(not _icone().novidade and not Caderno.aviso().ocupado(), "no meio do voo, ainda sem marca e sem aviso")
	await _esperar(Caderno.DURACAO_VOO_DA_NOTA * 0.5)
	await _capturar("2_voo")
	await _ate(func() -> bool: return _icone().novidade)
	_checar(_icone().novidade and _icone().pulando(), "a folha chega: o ícone pula e acende a marca de nota nova")
	_checar(Caderno.aviso().ocupado(), "e o aviso sobe")
	await _esperar(CadernoAviso.T_ENTRAR * 0.4)
	await _capturar("3_chegou")
	var aviso := Caderno.aviso()
	await _ate(aviso.na_tela)
	_checar(aviso.na_tela() and aviso.titulo_atual() == "O Átomo" and aviso.texto_das_paginas() == "páginas 4 a 7",
		"\"%s\" com o título e as páginas: %s, %s" % [CadernoAviso.CHAPEU, aviso.titulo_atual(), aviso.texto_das_paginas()])
	var caixa := aviso.caixa()
	_checar(get_viewport().get_visible_rect().encloses(caixa) and caixa.end.y <= _icone().get_global_rect().position.y \
		and caixa.position.x == _icone().get_global_rect().position.x,
		"o aviso fica em cima do ícone, dentro da tela (%s)" % caixa)
	await _capturar("4_aviso")

	print("\n--- ABRIR O CADERNO NA NOTA ---")
	_tecla(KEY_M)
	await _quadros(2)
	_checar(Caderno.aberto(), "M abre o caderno")
	_checar(not _icone().novidade and not aviso.na_tela(), "a marca apaga e o aviso sai")
	await _esperar(Caderno.DURACAO_ABRIR + 0.15)
	var livro := Caderno.livro()
	_checar(livro._faces[0].dados.get("titulo") == "O Átomo" and livro._faces[0].numero == 4 \
		and livro._faces[1].numero == 5, "aberto na nota nova: O Átomo, páginas 4 e 5")
	await _capturar("5_caderno_na_nota")
	_tecla(KEY_D)
	await _ate(func() -> bool: return livro.pagina() == 3 and not livro.virando())
	_checar(livro.pagina() == 3 and not livro._faces[0].dados.has("titulo") \
		and livro._faces[0].numero == 6 and livro._faces[1].numero == 7,
		"D vira para o resto da nota: a caixa do hidrogênio, sem título, páginas 6 e 7")
	await _capturar("6_resto_da_nota")
	_tecla(KEY_D)
	await _quadros(3)
	_checar(not livro.virando() and livro.pagina() == 3, "e é a última página do caderno")
	_tecla(KEY_M)
	await _esperar(Caderno.DURACAO_FECHAR + 0.5)
	_checar(not Caderno.aberto() and not aviso.ocupado(), "fechado, sem aviso sobrando")
	_checar(not _icone().novidade, "nem marca de nota nova")
	await _fechar(mundo)


func _testar_recarregar() -> void:
	print("\n--- RECARREGAR A CENA ---")
	var mundo := await _abrir()
	var grupo := mundo.get_node_or_null("NotasDoCaderno")
	await _quadros(2)
	_checar(grupo != null and grupo.get_child_count() == 0, "recarregar não traz a nota de volta")
	await _fechar(mundo)
	PaginasCaderno.esquecer_notas()
	mundo = await _abrir()
	grupo = mundo.get_node_or_null("NotasDoCaderno")
	_checar(grupo != null and grupo.get_child_count() == 1, "num jogo novo, ela está lá de novo")
	await _fechar(mundo)


func _testar_aviso_espera() -> void:
	print("\n--- O AVISO ESPERA A TELA FECHAR ---")
	PaginasCaderno.esquecer_notas()
	var cacau := Node.new()
	cacau.add_to_group("player")
	add_child(cacau)
	var aviso := Caderno.aviso()
	Inventario.popup_aberto = true
	await _esperar(0.4)
	_checar(not _icone().visible, "com a ficha de coleta aberta o ícone some")
	_checar(Caderno.guardar_nota("atomo"), "uma nota entra no caderno atrás da ficha")
	await _esperar(CadernoAviso.T_ENTRAR + 0.5)
	_checar(aviso.ocupado() and not aviso.na_tela(), "o aviso espera")
	Inventario.popup_aberto = false
	await _ate(aviso.na_tela)
	_checar(aviso.na_tela() and aviso.titulo_atual() == "O Átomo", "fechada a ficha, ele aparece")
	_checar(not Caderno.guardar_nota("atomo"), "pedir a mesma nota de novo não faz nada")
	await _esperar(CadernoAviso.T_SEGURAR + CadernoAviso.T_SAIR + 0.3)
	_checar(not aviso.ocupado() and not aviso.visible, "o aviso sai sozinho depois de lido")
	_checar(_icone().novidade, "e a marca de nota nova continua até o caderno ser aberto")
	_icone().novidade = false
	cacau.queue_free()


# ─────────────────────────────────────────────────────────────

func _abrir() -> Node:
	var mundo: Node = (load(MUNDO) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(mundo)
	await _quadros(2)
	# A personagem fica parada fora da física: cair ou morrer recarregaria a
	# cena atual (este teste) no meio do caminho.
	var player := mundo.get_node("Player") as CharacterBody2D
	player.set_physics_process(false)
	await get_tree().physics_frame
	await _quadros(2)
	return mundo


## Põe a Cacau em pé ao lado da folha e deixa a física perceber: é a Colisao
## da nota de verdade que acende o botão, não uma chamada direta.
func _chegar_perto(player: Node2D, nota: Node2D) -> void:
	player.global_position = nota.global_position + Vector2(-34, -42)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# A câmera tem suavização: espera ela chegar na personagem (capturas).
	await _esperar(1.5)


func _fechar(mundo: Node) -> void:
	mundo.queue_free()
	await _quadros(2)


func _icone() -> CadernoIcone:
	return Caderno.get_node("Icone")


func _apertar_e() -> void:
	# Aperta no começo de um quadro: depois de uma espera por tempo, o teste
	# acorda DEPOIS dos _process do quadro, e o toque seria solto sem ninguém ver.
	await get_tree().process_frame
	Input.action_press(Interacao.ACAO)
	await get_tree().process_frame
	Input.action_release(Interacao.ACAO)
	await _quadros(2)


func _tecla(codigo: Key) -> void:
	for apertada in [true, false]:
		var evento := InputEventKey.new()
		evento.keycode = codigo
		evento.physical_keycode = codigo
		evento.pressed = apertada
		Input.parse_input_event(evento)


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Espera no tempo DO JOGO (a soma dos deltas), e não no relógio: salvar uma
## captura trava um quadro inteiro, e um temporizador de relógio acordaria com o
## voo da folha e o aviso ainda atrasados.
func _esperar(segundos: float) -> void:
	var falta := segundos
	while falta > 0.0:
		await get_tree().process_frame
		falta -= get_process_delta_time()


## Espera até a condição valer (ou o tempo do jogo acabar).
func _ate(condicao: Callable, limite: float = 6.0) -> void:
	var falta := limite
	while falta > 0.0 and not condicao.call():
		await get_tree().process_frame
		falta -= get_process_delta_time()


func _capturando() -> bool:
	return not _pasta_capturas.is_empty() and DisplayServer.get_name() != "headless"


func _capturar(nome: String) -> void:
	if not _capturando():
		return
	await RenderingServer.frame_post_draw
	var imagem := get_viewport().get_texture().get_image()
	imagem.save_png(_pasta_capturas.path_join(nome + ".png"))
