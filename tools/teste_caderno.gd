extends Node

# Teste do caderno da Cacau (scripts/caderno.gd, scripts/ui/caderno_livro.gd,
# scripts/ui/face_caderno.gd, scripts/ui/caderno_icone.gd e
# scripts/paginas_caderno.gd), apertando as teclas de verdade:
#
#   * a ação "caderno" é M e △, e os atalhos de teste saíram do M;
#   * o ícone aparece com a Cacau em cena, com a tecla M desenhada (e o △ de
#     controle na mão);
#   * o △ que fecha um puzzle não abre o caderno junto;
#   * M abre: o jogo pausa, o caderno segura as teclas e sai do ícone; aberto,
#     o ícone some. M e ESC fecham, o jogo volta e o espaço apertado em cima do
#     caderno não vira pulo;
#   * D vira para a frente e A para trás, quadro a quadro na ordem da arte (2 a
#     9 indo, 9 a 2 voltando), e em cada quadro o texto fica onde a folha deixa:
#     a face de baixo só aparece depois da borda da folha que vira, e a folha
#     leva a frente (face da direita) ou o verso (a próxima esquerda);
#   * na primeira e na última página não vira nada;
#   * pedir uma página longe folheia até ela, mais rápido que uma a uma, e
#     clicar numa face vira para aquele lado;
#   * a primeira página é a folha de rosto, à direita (a esquerda é o verso da
#     capa, em branco), com o título e o nome da Cacau;
#   * a segunda é a do átomo de lítio, em 1,5× e com o título em cima, com
#     traços até eletrosfera, próton, elétron, núcleo e nêutron, e à direita
#     as três partículas comentadas, cada uma com o ícone dela;
#   * a terceira é a de atomística: a caixa do hidrogênio em 2×, com o nome em
#     texto dentro dela e um traço de cada parte até o que ela é, e as
#     propriedades na face da direita;
#   * cada face tem o número dela no canto de baixo de fora (a folha de rosto é
#     a 1; esquerda par, direita ímpar), também na folha que vira;
#   * todo texto cabe no papel (o nome, no vão da caixa) e toda letra existe
#     na fonte;
#   * com a ficha de coleta aberta ou sem a Cacau em cena, o ícone some e M
#     não abre.
#
# O caderno tem poucas páginas por enquanto: para ter várias para folhear, o
# teste põe as FOLHAS_DE_TESTE depois delas.
#
#   godot --headless --path . res://tools/teste_caderno.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva o ícone, o caderno
# aberto e uma virada quadro a quadro, para conferir o desenho a olho.

const FOLHAS_DE_TESTE := [
	[
		{"tipo": "propriedades", "itens": [{"formula": "teste 4", "texto": "Face esquerda."}]},
		{"tipo": "propriedades", "itens": [{"formula": "teste 4", "texto": "Face direita."}]},
	],
	[
		{"tipo": "propriedades", "itens": [{"formula": "teste 5", "texto": "Face esquerda."}]},
		{"tipo": "propriedades", "itens": [{"formula": "teste 5", "texto": "Face direita."}]},
	],
]

var _falhas := 0
var _pasta_capturas := ""
var _cacau: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			_pasta_capturas = arg.trim_prefix("--capturas=")
	PaginasCaderno.paginas = PaginasCaderno.PAGINAS + FOLHAS_DE_TESTE
	_cacau = Node.new()
	_cacau.name = "Cacau"
	_cacau.add_to_group("player")
	add_child(_cacau)
	await _quadros(2)

	_testar_mapa_de_entrada()
	_testar_paginas()
	await _testar_icone()
	await _testar_abrir_e_fechar()
	await _testar_virar()
	await _testar_bordas()
	await _testar_folhear()
	await _testar_espaco_nao_vira_pulo()
	await _testar_quando_nao_abre()
	await _testar_controle()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


# ─────────────────────────────────────────────────────────────

func _testar_mapa_de_entrada() -> void:
	print("\n--- MAPA DE ENTRADA ---")
	_checar(InputMap.has_action(Caderno.ACAO), "a ação \"caderno\" existe")
	_checar(_tem_tecla(Caderno.ACAO, KEY_M), "M abre o caderno")
	_checar(BotoesControle.nome_da_acao(Caderno.ACAO) == "triangulo",
		"no controle, o botão do caderno é o △")
	for acao in InputMap.get_actions():
		if acao != Caderno.ACAO and _tem_tecla(acao, KEY_M):
			_checar(false, "M não pode ser de outra ação (%s)" % acao)
	_checar(_tem_tecla(&"debug_coletar_tudo", KEY_N), "o atalho de teste da oficina foi para o N")
	_checar(BotoesControle.caractere("tecla_m") != "" \
		and BotoesControle.traduzir("{caderno}", false, true) == BotoesControle.caractere("tecla_m"),
		"{caderno} vira a tecla M desenhada")


func _tem_tecla(acao: StringName, tecla: Key) -> bool:
	for evento in InputMap.action_get_events(acao):
		# Atalho com Ctrl/Alt (o Ctrl+M embutido do Godot) é outra tecla.
		if evento is InputEventKey and not (evento.ctrl_pressed or evento.alt_pressed 				or evento.meta_pressed or evento.command_or_control_autoremap) 				and (evento.physical_keycode == tecla or evento.keycode == tecla):
			return true
	return false


func _testar_paginas() -> void:
	print("
--- PÁGINAS ---")
	var paginas := PaginasCaderno.PAGINAS
	_checar(paginas.size() >= 2, "o caderno tem o que ler (%d páginas)" % paginas.size())
	var fonte := FaceCaderno.FONTE
	var faltando := ""
	var fora := PackedStringArray()
	var cantos := PackedStringArray()
	for p in paginas.size():
		_checar(not (paginas[p][0].is_empty() and paginas[p][1].is_empty()),
			"página %d escrita" % (p + 1))
		for lado in 2:
			var dados: Dictionary = paginas[p][lado]
			if dados.is_empty():
				continue
			var face := _face_montada(dados, p, lado)
			var itens := face.montar()
			for item in itens:
				if not item.has("texto"):
					continue
				var limite: Rect2 = item.get("limite", face.area_util())
				if not limite.encloses(FaceCaderno.caixa_do_texto(item)):
					fora.append(item["texto"])
				for c in String(item["texto"]):
					if c != " " and not fonte.has_char(c.unicode_at(0)) and not faltando.contains(c):
						faltando += c
			# O número é o último: no canto de baixo de fora.
			var caixa_numero := FaceCaderno.caixa_do_texto(itens[-1])
			var fora_de_canto: bool = itens[-1].get("texto") != str(face.numero) \
				or caixa_numero.end.y <= face.area_util().end.y \
				or (lado == 0 and caixa_numero.position.x != FaceCaderno.MARGEM.x) \
				or (lado == 1 and absf(caixa_numero.end.x - face.area_util().end.x) > 1.0)
			if fora_de_canto:
				cantos.append("%d: %s" % [face.numero, caixa_numero])
			face.free()
	_checar(fora.is_empty(), "todo texto cabe no papel, e o nome no vão da caixa %s" % [fora])
	_checar(faltando.is_empty(), "toda letra existe na fonte [%s]" % faltando)
	_checar(cantos.is_empty(),
		"cada face com o número no canto de baixo de fora, abaixo da margem do texto %s" % [cantos])
	_checar(PaginasCaderno.numero(0, 1) == 1 and PaginasCaderno.numero(1, 0) == 2 \
		and PaginasCaderno.numero(1, 1) == 3 and PaginasCaderno.numero(0, 0) == 0,
		"a folha de rosto é a 1, o átomo 2 e 3, e o verso da capa não tem número")

	var rosto: Dictionary = paginas[0][1]
	_checar(paginas[0][0].is_empty() and rosto.get("tipo") == "rosto",
		"a primeira página é a folha de rosto, à direita do verso da capa")
	_checar(" ".join(rosto.get("linhas", [])) == "Caderno de Anotações" and rosto.get("nome") == "Cacau",
		"com o título e o nome da Cacau")

	var atomo: Dictionary = paginas[1][0]
	_checar(atomo.get("tipo") == "desenho" and atomo.get("arte") == PaginasCaderno.ARTE_LITIO,
		"a segunda é a do átomo de lítio")
	var face := _face_montada(atomo, 1, 0)
	var caixa := Rect2()
	var tinta := Rect2()
	var titulo := {}
	for item in face.montar():
		if item.has("arte"):
			caixa = item["rect"]
			tinta = item["tinta"]
		elif item.get("tam") == FaceCaderno.TAM_TITULO:
			titulo = item
	face.free()
	_checar(caixa.size == PaginasCaderno.ARTE_LITIO.get_size() * 1.5 and caixa.position == caixa.position.round(),
		"o átomo vai em 1,5×, no pixel inteiro (%s)" % caixa)
	_checar(titulo.get("texto") == "O átomo" and FaceCaderno.caixa_do_texto(titulo).end.y < tinta.position.y,
		"com o título \"O átomo\" em cima dele")
	_conferir_mapa(atomo, 1, ["eletrosfera", "próton", "elétron", "núcleo", "nêutron"])
	var comentarios: Dictionary = paginas[1][1]
	face = _face_montada(comentarios, 1, 1)
	var icones := 0
	for item in face.montar():
		if item.has("regiao") and item["rect"].size == item["regiao"].size * FaceCaderno.ESCALA_ICONE:
			icones += 1
	face.free()
	_checar(icones == 3,
		"e à direita as três partículas comentadas, cada uma com o ícone dela (%d)" % icones)

	var hidrogenio: Dictionary = paginas[2][0]
	_checar(hidrogenio.get("tipo") == "desenho" and hidrogenio.get("titulo") == "Atomística",
		"a terceira é a de atomística")
	face = _face_montada(hidrogenio, 2, 0)
	var nome := {}
	for item in face.montar():
		if item.has("arte"):
			caixa = item["rect"]
		elif item.get("tam") == FaceCaderno.TAM_NOME:
			nome = item
	face.free()
	var arte: Texture2D = hidrogenio["arte"]
	_checar(caixa.size == arte.get_size() * 2.0 and caixa.position == caixa.position.round(),
		"a caixa do hidrogênio vai em 2×, no pixel inteiro (%s)" % caixa)
	_checar(nome.get("texto") == "Hidrogênio" and caixa.encloses(FaceCaderno.caixa_do_texto(nome)),
		"o nome vai em texto, dentro da caixa")
	_conferir_mapa(hidrogenio, 2, ["número atômico (Z)", "símbolo", "massa atômica"])

	var propriedades: Dictionary = paginas[2][1]
	var formulas: Array = []
	for item in propriedades.get("itens", []):
		formulas.append(item["formula"])
	_checar(propriedades.get("tipo") == "propriedades" and "A = Z + n" in formulas,
		"e as propriedades à direita, com A = Z + n %s" % [formulas])


## O mapa mental de um desenho: um traço para cada nome pedido, que sai de
## dentro da tinta do desenho, passa dela e chega até o texto dele, fora da
## tinta (a não ser que a marca pare o traço num vão do desenho, com "ate");
## e texto nenhum encosta em outro.
func _conferir_mapa(dados: Dictionary, pagina: int, nomes: Array) -> void:
	var face := _face_montada(dados, pagina, 0)
	var tinta := Rect2()
	var tracos: Array[Rect2] = []
	var rotulos: Array[Rect2] = []
	var textos: Array = []
	for item in face.montar():
		if item.has("tinta"):
			tinta = item["tinta"]
		elif item.has("traco") and item["cor"] == FaceCaderno.TINTA:
			tracos.append(item["traco"])
		elif item.has("texto") and not item.has("limite") and item["tam"] == FaceCaderno.TAM_TEXTO \
				and item["cor"] == FaceCaderno.TINTA:
			rotulos.append(FaceCaderno.caixa_do_texto(item))
			textos.append(item["texto"])
	face.free()
	var marcas: Array = dados.get("marcas", [])
	var ligados := 0
	for i in mini(marcas.size(), mini(tracos.size(), rotulos.size())):
		var por_fora: bool = marcas[i].has("ate") or (tinta.intersects(tracos[i]) \
			and not tinta.encloses(tracos[i]) and not tinta.intersects(rotulos[i]))
		if por_fora and tracos[i].grow(FaceCaderno.FOLGA_TEXTO + 1.0).intersects(rotulos[i]):
			ligados += 1
	var encostados := 0
	for i in rotulos.size():
		for j in range(i + 1, rotulos.size()):
			if rotulos[i].intersects(rotulos[j]):
				encostados += 1
	var faltam := nomes.filter(func(n): return not n in textos)
	_checar(faltam.is_empty() and textos.size() == nomes.size() and ligados == nomes.size() \
		and encostados == 0,
		"%s: cada um com seu traço até o nome (%d de %d ligados, faltam %s, %d encostados)" \
		% [", ".join(nomes), ligados, nomes.size(), faltam, encostados])


func _face_montada(dados: Dictionary, pagina: int, lado: int) -> FaceCaderno:
	var face := FaceCaderno.new()
	face.size = (CadernoLivro.FACE_ESQUERDA if lado == 0 else CadernoLivro.FACE_DIREITA).size
	face.dados = dados
	face.numero = PaginasCaderno.numero(pagina, lado)
	return face


func _testar_icone() -> void:
	print("\n--- ÍCONE ---")
	await _esperar(0.35)
	var icone := _icone()
	_checar(icone.visible and is_equal_approx(icone.modulate.a, 1.0), "o ícone aparece com a Cacau em cena")
	var canto := icone.get_global_rect()
	var tela := get_viewport().get_visible_rect().size
	_checar(canto.position.x < tela.x * 0.1 and canto.end.y > tela.y * 0.9,
		"no canto inferior esquerdo (%s)" % canto)
	_checar(icone.nome_da_tecla() == "tecla_m", "com a tecla M desenhada ao lado")
	_checar(BotoesControle.anima("tecla_m"), "e a tecla M afunda em loop")
	await _capturar("0_icone")


func _testar_abrir_e_fechar() -> void:
	print("\n--- ABRIR E FECHAR ---")
	_tecla(KEY_M)
	await _quadros(2)
	_checar(Caderno.aberto(), "M abre o caderno")
	_checar(get_tree().paused, "o jogo pausa")
	_checar(Interacao.ocupada(), "o caderno segura as teclas")
	await _esperar(Caderno.DURACAO_ABRIR + 0.1)
	var livro := Caderno.livro()
	_checar(livro.scale.is_equal_approx(Vector2.ONE), "abre no tamanho da arte (%s)" % livro.scale)
	_checar(livro.position == livro.position.round(), "no pixel inteiro (%s)" % livro.position)
	var caixa := Rect2(livro.position + CadernoLivro.CAIXA_DESENHO.position, CadernoLivro.CAIXA_DESENHO.size)
	_checar(get_viewport().get_visible_rect().encloses(caixa), "o caderno inteiro cabe na tela (%s)" % caixa)
	_checar(not _icone().visible, "aberto, o ícone some")
	_checar(livro.pagina() == 0 and livro.quadro() == 0, "na primeira página, parado")
	var dicas: Array = Caderno._dicas().map(func(d): return d[1])
	_checar(dicas == ["FOLHEAR", "FECHAR"], "o rodapé só diz FOLHEAR e FECHAR, sem contador %s" % [dicas])
	_checar(not livro._recortes[0].visible and _face(1).dados.get("tipo") == "rosto" \
		and _face(1).numero == 1, "o verso da capa em branco e a folha de rosto à direita, com o 1")
	await _capturar("1_aberto")

	_tecla(KEY_M)
	await _quadros(2)
	_checar(not Caderno.aberto(), "M fecha")
	await _esperar(Caderno.DURACAO_FECHAR + 0.1)
	_checar(not get_tree().paused, "o jogo volta")
	_checar(not Interacao.ocupada(), "as teclas voltam para o jogo")
	await _esperar(0.3)
	_checar(_icone().visible and is_equal_approx(_icone().modulate.a, 1.0), "o ícone volta")

	_tecla(KEY_M)
	await _esperar(Caderno.DURACAO_ABRIR + 0.1)
	_tecla(KEY_ESCAPE)
	await _esperar(Caderno.DURACAO_FECHAR + 0.1)
	_checar(not Caderno.aberto() and not get_tree().paused, "ESC também fecha")


func _testar_virar() -> void:
	print("\n--- VIRAR AS FOLHAS ---")
	await _abrir()
	var livro := Caderno.livro()
	var lento := _capturando()
	if lento:
		Engine.time_scale = 0.08

	_tecla(KEY_D)
	await _quadros(1)
	_checar(livro.virando(), "D vira a folha")
	var vistos := await _acompanhar_virada(0, "indo")
	_checar(vistos == [1, 2, 3, 4, 5, 6, 7, 8], "indo, quadros 2 a 9 da arte, em ordem %s" % [vistos])
	_checar(livro.pagina() == 1 and livro.quadro() == 0, "parou na página 2, no quadro parado")
	_checar(_face(0).dados == PaginasCaderno.faces(1)[0] and _face(1).dados == PaginasCaderno.faces(1)[1],
		"com as faces da página 2")
	_checar(_face(0).numero == 2 and _face(1).numero == 3,
		"numeradas 2 e 3 (%d e %d)" % [_face(0).numero, _face(1).numero])

	_tecla(KEY_A)
	await _quadros(1)
	vistos = await _acompanhar_virada(0, "")
	_checar(vistos == [8, 7, 6, 5, 4, 3, 2, 1], "voltando, quadros 9 a 2, de trás para a frente %s" % [vistos])
	_checar(livro.pagina() == 0, "A volta para a página 1")

	Engine.time_scale = 1.0
	_tecla(KEY_RIGHT)
	await _quadros(1)
	await _esperar_parar()
	_checar(livro.pagina() == 1, "a seta para a direita também folheia")
	_tecla(KEY_LEFT)
	await _quadros(1)
	await _esperar_parar()
	_checar(livro.pagina() == 0, "e a para a esquerda volta")

	# Para conferir a olho: cada página de verdade, parada.
	if _capturando():
		for p in PaginasCaderno.PAGINAS.size():
			livro.ir_para_na_hora(p)
			await _capturar("3_pagina%d" % (p + 1))
		livro.ir_para_na_hora(0)


## Segue a virada quadro a quadro, conferindo o texto em cada um. Devolve os
## quadros vistos, na ordem.
func _acompanhar_virada(a: int, nome_captura: String) -> Array:
	var livro := Caderno.livro()
	var vistos: Array = []
	var ruins := PackedStringArray()
	while livro.virando():
		var q := livro.quadro()
		if vistos.is_empty() or vistos[-1] != q:
			vistos.append(q)
			var problema := _conferir_composicao(a, q)
			if problema != "":
				ruins.append("quadro %d: %s" % [q + 1, problema])
			if nome_captura != "":
				await _capturar("2_%s_quadro%d" % [nome_captura, q + 1])
		await _quadros(1)
	_checar(ruins.is_empty(), "o texto fica onde a folha deixa, em todo quadro %s" % [ruins])
	return vistos


func _conferir_composicao(a: int, q: int) -> String:
	var livro := Caderno.livro()
	var folha: Vector2 = CadernoLivro.VIRANDO[q]
	var esquerda: Control = livro._recortes[0]
	var direita: Control = livro._recortes[1]
	var virando: Control = livro._recortes[2]
	if esquerda.visible and esquerda.position.x + esquerda.size.x > folha.x + 0.5:
		return "a face de baixo à esquerda passa por baixo da folha"
	if esquerda.visible and _face(0).dados != PaginasCaderno.faces(a)[0]:
		return "a face de baixo à esquerda não é a da página de trás"
	if esquerda.visible and _face(0).numero != PaginasCaderno.numero(a, 0):
		return "a face de baixo à esquerda com o número errado"
	if direita.visible and direita.position.x < folha.y - 0.5:
		return "a face de baixo à direita aparece antes da borda da folha"
	if direita.visible and _face(1).dados != PaginasCaderno.faces(a + 1)[1]:
		return "a face de baixo à direita não é a da página da frente"
	if direita.visible and _face(1).numero != PaginasCaderno.numero(a + 1, 1):
		return "a face de baixo à direita com o número errado"
	var tinta: float = CadernoLivro.TINTA_NA_FOLHA[q]
	if virando.visible != (tinta > 0.0):
		return "texto na folha que vira: %s, esperado %s" % [virando.visible, tinta > 0.0]
	if virando.visible:
		var esperado: Dictionary = PaginasCaderno.faces(a)[1] if q <= CadernoLivro.ULTIMO_QUADRO_DA_FRENTE \
			else PaginasCaderno.faces(a + 1)[0]
		if _face(2).dados != esperado:
			return "a folha que vira leva a face errada"
		var numero := PaginasCaderno.numero(a, 1) if q <= CadernoLivro.ULTIMO_QUADRO_DA_FRENTE \
			else PaginasCaderno.numero(a + 1, 0)
		if _face(2).numero != numero:
			return "a folha que vira leva o número errado"
		if not is_equal_approx(virando.position.x, folha.x) \
				or not is_equal_approx(virando.size.x, folha.y - folha.x):
			return "o texto da folha não acompanha a largura dela"
	return ""


func _testar_bordas() -> void:
	print("\n--- PRIMEIRA E ÚLTIMA PÁGINA ---")
	var livro := Caderno.livro()
	_tecla(KEY_A)
	await _quadros(3)
	_checar(not livro.virando() and livro.pagina() == 0, "na primeira página, A não vira")
	_checar(livro._velocidade_empurrao != 0.0 or livro._empurrao != 0.0, "só dá um empurrãozinho")
	await _esperar(0.5)
	_checar(livro._arte.position.x == 0.0, "e assenta de volta")
	livro.ir_para_na_hora(PaginasCaderno.quantas() - 1)
	_tecla(KEY_D)
	await _quadros(3)
	_checar(not livro.virando() and livro.pagina() == PaginasCaderno.quantas() - 1,
		"na última página, D não vira")
	livro.ir_para_na_hora(0)


func _testar_folhear() -> void:
	print("\n--- FOLHEAR E CLICAR ---")
	var livro := Caderno.livro()
	var ultima := PaginasCaderno.quantas() - 1
	livro.ir_para(ultima)
	await _quadros(2)
	_checar(livro.virando(), "pedir a última página folheia")
	var viradas := 0
	var inicio := Time.get_ticks_msec()
	var ultima_pagina := livro.pagina()
	while livro.virando() or livro.pagina() != ultima:
		if livro.pagina() != ultima_pagina:
			ultima_pagina = livro.pagina()
			viradas += 1
		if Time.get_ticks_msec() - inicio > 8000:
			break
		await _quadros(1)
	_checar(livro.pagina() == ultima, "até a última página (%d)" % (livro.pagina() + 1))
	var tempo_uma := 0.0
	for t in CadernoLivro.TEMPOS:
		tempo_uma += t
	_checar((Time.get_ticks_msec() - inicio) * 0.001 < tempo_uma * ultima,
		"folheando mais rápido que virar uma a uma")
	await _capturar("4_ultima_pagina")

	_clicar(CadernoLivro.FACE_ESQUERDA.get_center())
	await _quadros(2)
	_checar(livro.virando(), "clicar na face esquerda volta uma página")
	await _esperar_parar()
	_checar(livro.pagina() == ultima - 1, "(página %d)" % (livro.pagina() + 1))
	livro.ir_para_na_hora(0)

	_clicar(Vector2(20, 20))  # na borda transparente do quadro
	await _quadros(2)
	_checar(not Caderno.aberto(), "clicar fora do caderno fecha")
	await _esperar(Caderno.DURACAO_FECHAR + 0.1)


func _testar_espaco_nao_vira_pulo() -> void:
	print("\n--- NADA VAZA PARA O JOGO ---")
	await _abrir()
	_apertar(KEY_SPACE, true)
	await _quadros(2)
	_tecla(KEY_M)
	await _esperar(Caderno.DURACAO_FECHAR + 0.1)
	_checar(not get_tree().paused, "fechou")
	_checar(Interacao.toque_preso(&"jump"), "o espaço apertado em cima do caderno não vira pulo")
	_apertar(KEY_SPACE, false)
	await _quadros(3)
	_checar(not Interacao.toque_preso(&"jump"), "solto, o espaço volta a ser do jogo")


func _testar_quando_nao_abre() -> void:
	print("\n--- QUANDO NÃO ABRE ---")
	Inventario.popup_aberto = true
	await _esperar(0.3)
	_checar(not _icone().visible, "com a ficha de coleta aberta o ícone some")
	_tecla(KEY_M)
	await _quadros(2)
	_checar(not Caderno.aberto(), "e M não abre")
	Inventario.popup_aberto = false
	await _esperar(0.3)

	_cacau.remove_from_group("player")
	await _esperar(0.3)
	_checar(not _icone().visible, "sem a Cacau em cena o ícone some")
	_tecla(KEY_M)
	await _quadros(2)
	_checar(not Caderno.aberto(), "e M não abre")
	_cacau.add_to_group("player")
	await _esperar(0.3)


func _testar_controle() -> void:
	print("\n--- CONTROLE ---")
	# O △ também fecha os puzzles: o toque que fecha um não pode abrir o caderno.
	var puzzle := Control.new()
	add_child(puzzle)
	Interacao.marcar_tela_aberta(puzzle, true)
	await _esperar(0.3)
	Interacao.marcar_tela_aberta(puzzle, false)
	puzzle.queue_free()
	_botao(JOY_BUTTON_Y, true)
	await _quadros(2)
	_botao(JOY_BUTTON_Y, false)
	_checar(not Caderno.aberto(), "o △ que fecha um puzzle não abre o caderno junto")
	await _esperar(0.3)

	_botao(JOY_BUTTON_Y, true)
	await _quadros(2)
	_botao(JOY_BUTTON_Y, false)
	_checar(Controle.em_uso, "o controle entrou em uso")
	_checar(Caderno.aberto(), "△ abre o caderno")
	_checar(_icone().nome_da_tecla() == "triangulo", "e o ícone mostra o △")
	await _esperar(Caderno.DURACAO_ABRIR + 0.1)
	await _capturar("5_controle")
	_botao(JOY_BUTTON_DPAD_RIGHT, true)
	await _quadros(2)
	_botao(JOY_BUTTON_DPAD_RIGHT, false)
	_checar(Caderno.livro().virando(), "o direcional folheia")
	await _esperar_parar()
	_botao(JOY_BUTTON_Y, true)
	await _quadros(2)
	_botao(JOY_BUTTON_Y, false)
	_checar(not Caderno.aberto(), "△ fecha")
	await _esperar(Caderno.DURACAO_FECHAR + 0.1)
	Caderno.livro().ir_para_na_hora(0)
	_tecla(KEY_F10)  # volta para o teclado
	await _quadros(2)


# ─────────────────────────────────────────────────────────────

func _abrir() -> void:
	_tecla(KEY_M)
	await _esperar(Caderno.DURACAO_ABRIR + 0.1)


func _esperar_parar() -> void:
	var inicio := Time.get_ticks_msec()
	while Caderno.livro().virando() and Time.get_ticks_msec() - inicio < 5000:
		await _quadros(1)


func _icone() -> CadernoIcone:
	return Caderno.get_node("Icone")


func _face(i: int) -> FaceCaderno:
	return Caderno.livro()._faces[i]


func _tecla(codigo: Key) -> void:
	_apertar(codigo, true)
	_apertar(codigo, false)


func _apertar(codigo: Key, apertada: bool) -> void:
	var evento := InputEventKey.new()
	evento.keycode = codigo
	evento.physical_keycode = codigo
	evento.pressed = apertada
	Input.parse_input_event(evento)


func _botao(botao: JoyButton, apertado: bool) -> void:
	var evento := InputEventJoypadButton.new()
	evento.device = 0
	evento.button_index = botao
	evento.pressed = apertado
	Input.parse_input_event(evento)


## Clique num ponto do caderno (px do quadro). Vai direto para o _gui_input:
## sem janela (headless) o mouse nunca "entra" nela, e o Godot não entrega
## clique de Input.parse_input_event à interface.
func _clicar(ponto: Vector2) -> void:
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = true
	evento.position = ponto
	Caderno.livro()._gui_input(evento)


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos, true, false, true).timeout


func _capturando() -> bool:
	return not _pasta_capturas.is_empty() and DisplayServer.get_name() != "headless"


func _capturar(nome: String) -> void:
	if not _capturando():
		return
	await RenderingServer.frame_post_draw
	var imagem := get_viewport().get_texture().get_image()
	imagem.save_png(_pasta_capturas.path_join(nome + ".png"))
