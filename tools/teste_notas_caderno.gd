extends Node

# Teste das notas do caderno (scripts/paginas_caderno.gd, scripts/caderno.gd,
# scripts/ui/caderno_aviso.gd, a marca de nota nova do scripts/ui/caderno_icone.gd
# e a folha solta, scripts/fases/nota_caderno.gd):
#
#   * o caderno começa só até a página 3; o resto são cinco notas — o átomo, a
#     eletrosfera, o balanceamento, os gases e a destilação —, uma atrás da
#     outra, sem buraco entre elas;
#   * cada nota entra no lugar dela, com o número das faces de sempre, e traz
#     todas as páginas duplas dela de uma vez, achada em qualquer ordem;
#   * QUEM ANOTA É A CONVERSA: toda nota tem uma conversa do Dr. Chico que a
#     ensina (do Caderno.anotar("nome")), toda conversa que anota fala de uma
#     nota que existe e está registrada no Dialogic, e quem escolhe "Já sei..."
#     também leva a nota;
#   * a conversa de verdade, pelo Dialogic: a nota entra sem folha voando, o
#     aviso espera a fala acabar e aí sobe com o título e as páginas; M abre o
#     caderno onde ele ficou (a primeira vez, no MAPA), com a marca de nota
#     nova na aba CADERNO, que já está na página da nota; a marca só apaga
#     quando a pessoa vê o CADERNO;
#   * o world1 não tem mais a folha do átomo no chão;
#   * a folha solta (nota_caderno.tscn) continua funcionando, para uma nota
#     futura no mapa: o botão E só aparece com a Cacau por perto, o E pega a
#     folha, ela voa até o ícone e o aviso sobe; uma folha de nota que já está
#     no caderno some sozinha;
#   * com a ficha de coleta na tela o aviso espera ela fechar.
#
#   godot --headless --path . res://tools/teste_notas_caderno.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva a folha com o botão, o
# voo, o aviso e o caderno aberto na nota, para conferir a olho.

const MUNDO := "res://scenes/world1.tscn"
const PASTA_DAS_CONVERSAS := "res://timelines/"
## Uma conversa que anota e pergunta antes: a do compressor (nota "gases").
const CONVERSA_DE_TESTE := "res://timelines/cientista_compressor.dtl"
const NOTAS_EM_ORDEM := ["atomo", "eletrosfera", "balanceamento", "gases", "destilacao"]

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
	_testar_conversas_que_anotam()
	await _testar_conversa_de_verdade()
	_testar_world1_sem_folha()
	await _testar_folha_solta()
	await _testar_aviso_espera()
	await _testar_tecla_p()
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
	_checar(notas.keys() == NOTAS_EM_ORDEM, "as notas, na ordem do caderno: %s" % [notas.keys()])
	var esperados := {"atomo": Vector2i(4, 9), "eletrosfera": Vector2i(10, 11),
		"balanceamento": Vector2i(12, 15), "gases": Vector2i(16, 17), "destilacao": Vector2i(18, 19)}
	for nota in esperados:
		_checar(PaginasCaderno.numeros_da_nota(nota) == esperados[nota],
			"\"%s\" traz as páginas %d a %d" % [PaginasCaderno.titulo_da_nota(nota),
				esperados[nota].x, esperados[nota].y])
	# Uma atrás da outra, da página dupla 2 até a última, sem buraco e sem
	# página de duas notas.
	var seguidas: Array = []
	var boas := true
	for nota in notas:
		if PaginasCaderno.titulo_da_nota(nota).is_empty() or PaginasCaderno.paginas_da_nota(nota).is_empty():
			boas = false
		seguidas.append_array(PaginasCaderno.paginas_da_nota(nota))
	_checar(boas, "cada nota tem título e páginas")
	_checar(seguidas == range(2, PaginasCaderno.PAGINAS.size()),
		"todas as páginas depois da 3 são de uma nota só, em ordem %s" % [seguidas])
	var titulos_certos := true
	for nota in notas:
		var primeira: Dictionary = PaginasCaderno.PAGINAS[int(PaginasCaderno.paginas_da_nota(nota)[0])][0]
		if primeira.get("titulo") != PaginasCaderno.titulo_da_nota(nota):
			titulos_certos = false
	_checar(titulos_certos, "o título de cada nota é o da primeira página dela")
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
	_checar(PaginasCaderno.guardar_nota("atomo") and PaginasCaderno.quantas() == 5,
		"achando o átomo, o caderno ganha as três páginas duplas dele de uma vez")
	_checar(PaginasCaderno.lugar_da_nota("atomo") == 2 \
		and PaginasCaderno.faces(2)[0].get("titulo") == "O Átomo" \
		and PaginasCaderno.faces(3)[0].get("arte") == PaginasCaderno.ARTE_HIDROGENIO \
		and PaginasCaderno.faces(4)[0].get("titulo") == "Hidrogênio",
		"logo depois da epígrafe: o átomo, a caixa do hidrogênio e o hidrogênio montado")
	_checar(PaginasCaderno.numero(1, 1) == 3 and PaginasCaderno.numero(2, 0) == 4 \
		and PaginasCaderno.numero(4, 1) == 9,
		"com os números de sempre: 4 a 9")
	_checar(not PaginasCaderno.guardar_nota("atomo") and PaginasCaderno.notas_achadas() == 1,
		"a mesma nota não entra duas vezes")

	# Os puzzles podem vir em qualquer ordem: a nota de trás entra antes da
	# da frente, e cada uma vai para o lugar dela.
	PaginasCaderno.esquecer_notas()
	PaginasCaderno.guardar_nota("gases")
	_checar(PaginasCaderno.lugar_da_nota("gases") == 2 and PaginasCaderno.numero(2, 0) == 16 \
		and PaginasCaderno.numero(2, 1) == 17,
		"só os gases: logo depois da epígrafe, mas com os números deles (16 e 17)")
	PaginasCaderno.guardar_nota("eletrosfera")
	_checar(PaginasCaderno.lugar_da_nota("eletrosfera") == 2 and PaginasCaderno.lugar_da_nota("gases") == 3,
		"a eletrosfera, achada depois, entra na frente dos gases")
	for nota in NOTAS_EM_ORDEM:
		PaginasCaderno.guardar_nota(nota)
	_checar(PaginasCaderno.quantas() == PaginasCaderno.PAGINAS.size() \
		and PaginasCaderno.no_caderno() == range(PaginasCaderno.PAGINAS.size()),
		"com todas, o caderno inteiro, na ordem (%d páginas duplas)" % PaginasCaderno.quantas())
	PaginasCaderno.esquecer_notas()


## Lê as conversas em timelines/: quem anota o quê, e a pergunta "Quer que eu
## explique?" com o "Já sei..." em segundo.
func _testar_conversas_que_anotam() -> void:
	print("\n--- AS CONVERSAS QUE ANOTAM ---")
	var registradas: Dictionary = ProjectSettings.get_setting("dialogic/directories/dtl_directory", {})
	var achar := RegEx.create_from_string("do Caderno\\.anotar\\(\"([^\"]*)\"\\)")
	var ensinadas := {}
	var nota_que_nao_existe := []
	var fora_do_dialogic := []
	var pulo_ruim := []
	var com_pergunta := 0
	for arquivo in DirAccess.get_files_at(PASTA_DAS_CONVERSAS):
		if not arquivo.ends_with(".dtl"):
			continue
		var caminho := PASTA_DAS_CONVERSAS + arquivo
		var texto := FileAccess.get_file_as_string(caminho)
		var anota := false
		for achado in achar.search_all(texto):
			anota = true
			var nota := achado.get_string(1)
			if PaginasCaderno.NOTAS.has(nota):
				ensinadas[nota] = true
			else:
				nota_que_nao_existe.append("%s: %s" % [arquivo, nota])
		if anota and registradas.get(arquivo.get_basename(), "") != caminho:
			fora_do_dialogic.append(arquivo)
		if not texto.contains(ExplicacaoNoPuzzle.SINAL_PULAR):
			continue
		com_pergunta += 1
		var opcoes: Array[String] = []
		var ramo_de_pular := ""
		for linha in texto.split("\n"):
			if linha.begins_with("- "):
				opcoes.append(linha.substr(2).strip_edges())
			elif opcoes.size() >= 2:
				ramo_de_pular += linha.strip_edges() + "\n"
		var bom := opcoes.size() == 2 and opcoes[1].begins_with("Já sei") \
			and ramo_de_pular.contains("[signal arg=\"%s\"]" % ExplicacaoNoPuzzle.SINAL_PULAR) \
			and achar.search(ramo_de_pular) != null and ramo_de_pular.contains("[end_timeline]")
		if not bom:
			pulo_ruim.append(arquivo)
	_checar(nota_que_nao_existe.is_empty(), "toda conversa anota uma nota que existe %s" % [nota_que_nao_existe])
	_checar(fora_do_dialogic.is_empty(), "e está registrada no Dialogic %s" % [fora_do_dialogic])
	var faltam := []
	for nota in PaginasCaderno.NOTAS:
		if not ensinadas.has(nota):
			faltam.append(nota)
	_checar(faltam.is_empty(), "toda nota tem uma conversa que a ensina %s" % [faltam])
	_checar(com_pergunta == 6, "seis conversas perguntam se a Cacau quer a explicação (%d)" % com_pergunta)
	_checar(pulo_ruim.is_empty(),
		"em todas, \"Já sei...\" é a segunda opção, e quem pula também anota %s" % [pulo_ruim])


## A conversa do compressor de verdade, escolhendo "Já sei como funciona".
func _testar_conversa_de_verdade() -> void:
	print("\n--- A CONVERSA ANOTA ---")
	PaginasCaderno.esquecer_notas()
	var cacau := Node.new()
	cacau.add_to_group("player")
	add_child(cacau)
	await _esperar(0.4)
	var aviso := Caderno.aviso()
	_checar(_icone().visible and not aviso.ocupado(), "o ícone do caderno está na tela, sem aviso")
	var avisadas: Array = []
	var ao_guardar := func(n: String) -> void: avisadas.append(n)
	Caderno.nota_guardada.connect(ao_guardar)

	Dialogic.start(CONVERSA_DE_TESTE)
	_checar(await _ate_a_pergunta(), "o Dr. Chico pergunta se a Cacau quer a explicação")
	_checar(not Caderno.tem_nota("gases"), "antes da resposta, nada anotado")
	_checar(not _icone().visible, "com a fala na tela, o ícone do caderno some")
	_checar(await _escolher(2), "\"Já sei como funciona\"")
	await _ate(func() -> bool: return Caderno.tem_nota("gases"), 3.0)
	_checar(Caderno.tem_nota("gases") and avisadas == ["gases"], "a conversa anota \"gases\" no caderno")
	_checar(Caderno.get_node_or_null("VooDeItem") == null, "sem folha voando: foi a Cacau quem anotou")
	_checar(Caderno.livro().pagina() == PaginasCaderno.lugar_da_nota("gases"),
		"e o caderno já fica aberto na nota nova")
	_checar(_icone().novidade and not aviso.na_tela(), "a marca acende, mas o aviso espera a fala acabar")
	var toques := 0
	while Dialogic.current_timeline != null and toques < 30:
		Dialogic.Inputs.handle_input()
		await _esperar(0.2)
		toques += 1
	_checar(Dialogic.current_timeline == null, "a conversa acaba")
	await _ate(aviso.na_tela)
	_checar(aviso.na_tela() and aviso.titulo_atual() == "Os Gases" and aviso.texto_das_paginas() == "páginas 16 e 17",
		"aí o aviso sobe: %s, %s" % [aviso.titulo_atual(), aviso.texto_das_paginas()])
	var caixa := aviso.caixa()
	_checar(get_viewport().get_visible_rect().encloses(caixa) and caixa.end.y <= _icone().get_global_rect().position.y \
		and caixa.position.x == _icone().get_global_rect().position.x,
		"em cima do ícone, dentro da tela (%s)" % caixa)
	await _capturar("1_aviso_da_conversa")

	_tecla(KEY_M)
	await _quadros(2)
	_checar(Caderno.aberto() and Caderno.aba() == Caderno.Aba.MAPA,
		"M abre o caderno onde ele ficou — a primeira vez, no MAPA: nota nova não muda a aba")
	_checar(not aviso.na_tela(), "o aviso sai")
	_checar(_icone().novidade and Caderno.abas().tem_nota_nova(),
		"mas a marca continua, no ícone e na aba CADERNO: a nota ainda não foi vista")
	await _esperar(Caderno.DURACAO_ABRIR + 0.15)
	_tecla(KEY_E)
	await _esperar(Caderno.DURACAO_TROCA + 0.1)
	var livro := Caderno.livro()
	_checar(Caderno.aba() == Caderno.Aba.CADERNO and livro.visible and not _icone().novidade,
		"E troca para o CADERNO, e a marca apaga")
	_checar(livro._faces[0].dados.get("titulo") == "Os Gases" and livro._faces[0].numero == 16 \
		and livro._faces[1].numero == 17, "aberto na nota nova: Os Gases, páginas 16 e 17")
	await _capturar("2_caderno_na_nota")
	_tecla(KEY_M)
	await _esperar(Caderno.DURACAO_FECHAR + 0.5)
	_checar(not Caderno.aberto() and not aviso.ocupado(), "fechado, sem aviso sobrando")

	# Conversa que anota de novo a mesma nota: nada acontece.
	Caderno.anotar("gases")
	Caderno.anotar("nota_que_nao_existe")
	await _quadros(2)
	_checar(avisadas == ["gases"] and not aviso.ocupado() and PaginasCaderno.notas_achadas() == 1,
		"anotar de novo (ou uma nota que não existe) não faz nada")
	Caderno.nota_guardada.disconnect(ao_guardar)
	cacau.queue_free()
	await _quadros(2)
	PaginasCaderno.esquecer_notas()


func _testar_world1_sem_folha() -> void:
	print("\n--- O WORLD1 ---")
	var cena := FileAccess.get_file_as_string(MUNDO)
	_checar(not cena.is_empty() and not cena.contains("nota_caderno.tscn") and not cena.contains("NotasDoCaderno"),
		"não tem mais a folha do átomo no chão: quem ensina é o Dr. Chico, no puzzle do hidrogênio")


## A folha solta, num mapinha só dela: o chão não importa, só a Cacau chegando
## perto (a Colisao da folha de verdade é que acende o botão).
func _testar_folha_solta() -> void:
	print("\n--- A FOLHA SOLTA (para uma nota no mapa) ---")
	PaginasCaderno.esquecer_notas()
	var mundo := Node2D.new()
	mundo.name = "MapinhaDaFolha"
	var cacau := CharacterBody2D.new()
	cacau.name = "Cacau"
	cacau.add_to_group("player")
	cacau.z_index = 2
	var forma := CollisionShape2D.new()
	var corpo := RectangleShape2D.new()
	corpo.size = Vector2(28, 60)
	forma.shape = corpo
	cacau.add_child(forma)
	cacau.position = Vector2(300, 300)
	mundo.add_child(cacau)
	var folha := (load(NotaCaderno.CENA) as PackedScene).instantiate() as NotaCaderno
	folha.nota = "atomo"
	folha.position = Vector2(800, 520)
	mundo.add_child(folha)
	add_child(mundo)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _quadros(2)

	var dica := folha.get_node("Dica") as CanvasItem
	_checar(not dica.visible, "de longe, sem botão")
	_checar(folha.z_index < cacau.z_index and folha.z_index > 0, "atrás da Cacau e na frente do chão")
	var arte := folha.caixa_da_arte()
	_checar(arte.end.y < 0.0 and arte.position == arte.position.round() and arte.size == Vector2(42, 48),
		"a folha flutua acima do chão, em 2×, no pixel inteiro (%s)" % arte)

	cacau.global_position = folha.global_position + Vector2(-34, -42)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _esperar(0.4)
	_checar(dica.visible, "de perto, o botão E aparece em cima da folha")
	_checar(dica.global_position.y < folha.to_global(folha.caixa_da_arte().position).y, "o botão fica acima dela")
	_checar(_icone().visible and not _icone().novidade and not Caderno.aviso().ocupado(),
		"o ícone do caderno na tela, sem marca de nota nova nem aviso")
	await _capturar("3_folha_com_botao")

	var avisadas: Array = []
	var ao_guardar := func(n: String) -> void: avisadas.append(n)
	Caderno.nota_guardada.connect(ao_guardar)
	await _apertar_e()
	_checar(Caderno.tem_nota("atomo") and avisadas == ["atomo"], "o E pega a folha: a nota entra no caderno")
	_checar(not is_instance_valid(folha), "a folha some do mapa")
	_checar(PaginasCaderno.quantas() == 5 and Caderno.livro().pagina() == PaginasCaderno.lugar_da_nota("atomo"),
		"o caderno ganha as páginas e já fica aberto na primeira delas")
	var voo := Caderno.get_node_or_null("VooDeItem") as VooDeItem
	_checar(voo != null and voo.textura == CadernoAviso.ARTE, "a folha voa para o ícone do caderno")
	_checar(not _icone().novidade and not Caderno.aviso().ocupado(), "no meio do voo, ainda sem marca e sem aviso")
	await _esperar(Caderno.DURACAO_VOO_DA_NOTA * 0.5)
	await _capturar("4_voo")
	await _ate(func() -> bool: return _icone().novidade)
	_checar(_icone().novidade and _icone().pulando(), "a folha chega: o ícone pula e acende a marca de nota nova")
	var aviso := Caderno.aviso()
	_checar(aviso.ocupado(), "e o aviso sobe")
	await _ate(aviso.na_tela)
	_checar(aviso.na_tela() and aviso.titulo_atual() == "O Átomo" and aviso.texto_das_paginas() == "páginas 4 a 9",
		"\"%s\": %s, %s" % [CadernoAviso.CHAPEU, aviso.titulo_atual(), aviso.texto_das_paginas()])
	await _capturar("5_aviso_da_folha")

	_tecla(KEY_M)
	await _quadros(2)
	_checar(Caderno.aberto() and Caderno.aba() == Caderno.Aba.CADERNO and not _icone().novidade,
		"M abre o caderno no CADERNO, onde ele ficou: a nota é vista e a marca apaga")
	await _esperar(Caderno.DURACAO_ABRIR + 0.15)
	var livro := Caderno.livro()
	_checar(livro._faces[0].dados.get("titulo") == "O Átomo" and livro._faces[0].numero == 4 \
		and livro._faces[1].numero == 5, "aberto na nota nova: O Átomo, páginas 4 e 5")
	await _capturar("6_caderno_no_atomo")
	_tecla(KEY_D)
	await _ate(func() -> bool: return livro.pagina() == 3 and not livro.virando())
	_checar(livro.pagina() == 3 and livro._faces[0].numero == 6 and livro._faces[1].numero == 7,
		"D vira para a caixa do hidrogênio, páginas 6 e 7")
	_tecla(KEY_D)
	await _ate(func() -> bool: return livro.pagina() == 4 and not livro.virando())
	_checar(livro.pagina() == 4 and livro._faces[0].dados.get("titulo") == "Hidrogênio" \
		and livro._faces[1].numero == 9, "e para o hidrogênio montado, páginas 8 e 9")
	_tecla(KEY_D)
	await _quadros(3)
	_checar(not livro.virando() and livro.pagina() == 4, "que é a última página do caderno")
	_tecla(KEY_M)
	await _esperar(Caderno.DURACAO_FECHAR + 0.5)
	_checar(not Caderno.aberto() and not aviso.ocupado() and not _icone().novidade,
		"fechado, sem aviso e sem marca sobrando")
	Caderno.nota_guardada.disconnect(ao_guardar)

	# Morrer ou voltar para a cena não traz a folha de volta: quem lembra é o
	# caderno.
	var outra := (load(NotaCaderno.CENA) as PackedScene).instantiate() as NotaCaderno
	outra.nota = "atomo"
	mundo.add_child(outra)
	await _quadros(2)
	_checar(not is_instance_valid(outra), "uma folha de nota que já está no caderno some sozinha")
	mundo.queue_free()
	await _quadros(2)
	PaginasCaderno.esquecer_notas()


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
	_checar(_icone().novidade, "e a marca de nota nova continua até a pessoa ver o CADERNO")
	_icone().novidade = false
	cacau.queue_free()


## O atalho de teste P (o de ganhar todas as ferramentas) também dá o caderno
## inteiro — no world1, onde nenhuma explicação aconteceu ainda.
func _testar_tecla_p() -> void:
	print("\n--- A TECLA P NO WORLD1 ---")
	PaginasCaderno.esquecer_notas()
	var mundo: Node = (load(MUNDO) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(mundo)
	await _quadros(2)
	# Parada fora da física: cair ou morrer recarregaria a cena atual (este teste).
	var player := mundo.get_node("Player") as CharacterBody2D
	player.set_physics_process(false)
	await _esperar(0.3)
	var aviso := Caderno.aviso()
	_checar(PaginasCaderno.quantas() == 2, "o caderno começa só até a página 3")
	_tecla(KEY_P)
	await _quadros(3)
	_checar(PaginasCaderno.notas_achadas() == PaginasCaderno.NOTAS.size() \
		and PaginasCaderno.quantas() == PaginasCaderno.PAGINAS.size(),
		"P: todas as notas, o caderno inteiro (%d páginas duplas)" % PaginasCaderno.quantas())
	_checar(_icone().novidade and not aviso.ocupado(), "com a marca de nota nova e sem fila de avisos")
	var livro := Caderno.livro()
	livro.ir_para_na_hora(PaginasCaderno.quantas() - 1)
	_checar(livro._faces[0].dados.get("titulo") == "Destilação" and livro._faces[1].numero == 19,
		"a última página é a da destilação (19)")
	_tecla(KEY_P)
	await _quadros(3)
	_checar(PaginasCaderno.quantas() == PaginasCaderno.PAGINAS.size() and not aviso.ocupado(),
		"P de novo não muda nada")
	_icone().novidade = false
	mundo.queue_free()
	await _quadros(2)
	PaginasCaderno.esquecer_notas()


# ─────────────────────────────────────────────────────────────

func _icone() -> CadernoIcone:
	return Caderno.get_node("Icone")


## Passa as falas até a pergunta ("Quer que eu explique...?"). True se chegou.
func _ate_a_pergunta() -> bool:
	await _ate(func() -> bool: return Dialogic.current_timeline != null, 3.0)
	var toques := 0
	while Dialogic.current_state != Dialogic.States.AWAITING_CHOICE and toques < 40 \
			and Dialogic.current_timeline != null:
		Dialogic.Inputs.handle_input()
		await _esperar(0.2)
		toques += 1
	return Dialogic.current_state == Dialogic.States.AWAITING_CHOICE


## Escolhe a opção (1 = a primeira). O Dialogic segura as opções um instante
## depois de mostrá-las: tenta de novo até pegar.
func _escolher(opcao: int) -> bool:
	for tentativa in 10:
		await _esperar(0.25)
		Dialogic.Choices.select_choice(opcao)
		await get_tree().process_frame
		if Dialogic.current_state != Dialogic.States.AWAITING_CHOICE:
			return true
	return false


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
