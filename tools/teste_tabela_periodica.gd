extends "res://tools/teste_de_tela.gd"

# Teste da tabela periódica do Laboratório
# (scenes/laboratorio/tabela_periodica.tscn), usada com o mouse e o teclado de
# verdade.
#
#   * as 118 casas existem, cada uma no lugar do elemento (período e grupo), sem
#     duas no mesmo lugar, e a folha inteira cabe na tela; as duas fileiras de
#     baixo são os lantanídios e os actinídios, e as casas "57-71" e "89-103"
#     apontam para elas;
#   * toda casa tem o tom da família do elemento, e a legenda tem todas as
#     famílias;
#   * passar o mouse numa casa põe o foco nela e o alto da folha diz que
#     elemento é; as setas e o WASD levam o foco de casa em casa, inclusive
#     para as fileiras de baixo;
#   * clicar (ou ENTER) abre a ficha: a caixa ampliada, o átomo no modelo de
#     camadas com as partículas do isótopo mais comum, a distribuição, a
#     família, o lugar e os isótopos da natureza;
#   * com a ficha aberta as casas não valem; ← e → e os botões passam de
#     elemento, e param no hidrogênio e no oganessônio;
#   * ENTER, ESC ou um clique fora fecham a ficha, e o foco fica no elemento
#     visto; ESC sem ficha volta ao Laboratório;
#   * para os 118 elementos, toda letra existe na fonte e nenhum texto da ficha
#     sai do papel nem encosta no desenho do átomo.
#
#   godot --headless --path . res://tools/teste_tabela_periodica.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva a folha e algumas fichas.

const CENA := "res://scenes/laboratorio/tabela_periodica.tscn"
## A folga mínima entre um texto da ficha e o que está ao lado dele.
const RESPIRO := 8.0


func _ready() -> void:
	await _comecar()
	await _testar_a_folha()
	await _testar_o_foco()
	await _testar_a_ficha()
	await _testar_os_textos()
	await _testar_o_controle()
	await _testar_a_saida()
	_terminar()


# ─────────────────────────────────────────────────────────────

func _testar_a_folha() -> void:
	print("\n--- A FOLHA ---")
	var tela := await _abrir(CENA)
	_checar(tela.navegar_com_teclas and not tela.usa_cursor(), "a tabela anda pelas teclas (sem cursor do controle)")
	_checar(tela.cena_de_volta == TransicaoDeCena.CENA_LABORATORIO, "ESC leva ao menu do Laboratório")
	_checar(tela.na_ficha == 0 and not tela.ficha.visible and not tela.veu.visible, "abre na folha, sem ficha")

	var sem_casa := PackedStringArray()
	var lugares := {}
	var fora_da_folha := PackedStringArray()
	var tela_inteira := Rect2(Vector2.ZERO, tela.size)
	var folha: Rect2 = tela.retangulo_da_folha()
	for z in range(1, Elementos.TOTAL + 1):
		var nome: String = tela.nome_da_casa(z)
		if not tela.tem_alvo(nome) or not tela.alvo_disponivel(nome):
			sem_casa.append(Elementos.simbolo(z))
			continue
		var casa: Rect2 = tela.retangulo_do_alvo(nome)
		lugares[casa.position] = z
		if casa.size != Vector2(CaixasDosElementos.TAMANHO) or not folha.encloses(casa):
			fora_da_folha.append(Elementos.simbolo(z))
	_checar(sem_casa.is_empty(), "os 118 elementos têm casa %s" % [sem_casa])
	_checar(lugares.size() == Elementos.TOTAL, "nenhuma casa em cima de outra (%d lugares)" % lugares.size())
	_checar(fora_da_folha.is_empty(), "todas do tamanho da caixa do caderno e dentro da folha %s" % [fora_da_folha])
	_checar(tela_inteira.encloses(folha), "a folha inteira cabe na tela %s" % folha)
	_checar(tela.titulo.is_empty() and tela.TITULO_DA_FOLHA == "Tabela Periódica",
		"o título é o da própria folha: Tabela Periódica")

	# O lugar de cada um: período na linha, grupo na coluna.
	var passo: Vector2 = tela.PASSO
	var canto: Vector2 = tela.CANTO_DA_TABELA
	var mal_colocados := PackedStringArray()
	for z in range(1, Elementos.TOTAL + 1):
		var onde: Vector2 = tela.retangulo_da_casa(z).position
		var esperado := Vector2.ZERO
		if Elementos.grupo(z) > 0:
			esperado = canto + Vector2(Elementos.grupo(z) - 1, Elementos.periodo(z) - 1) * passo
		else:
			# Lantanídios (linha 7) e actinídios (linha 8), a partir da coluna 3.
			var linha := 7 if Elementos.e_lantanidio(z) else 8
			var primeiro := 57 if Elementos.e_lantanidio(z) else 89
			esperado = canto + Vector2(2 + z - primeiro, linha) * passo + Vector2(0, tela.VAO_DAS_FILEIRAS)
		if not onde.is_equal_approx(esperado):
			mal_colocados.append("%s %s (era %s)" % [Elementos.simbolo(z), onde, esperado])
	_checar(mal_colocados.is_empty(), "cada elemento na linha do período e na coluna do grupo dele %s" % [mal_colocados.slice(0, 4)])
	_checar(tela.retangulo_da_casa(1).position == canto and is_equal_approx(tela.retangulo_da_casa(2).end.x,
		tela.retangulo_da_tabela().end.x), "o hidrogênio no canto de cima à esquerda, o hélio na ponta direita")
	_checar(is_equal_approx(tela.retangulo_da_casa(103).end.y, tela.retangulo_da_tabela().end.y) \
		and tela.retangulo_da_casa(57).position.y > tela.retangulo_da_casa(118).end.y,
		"as duas fileiras de baixo ficam separadas do 7º período")
	# As casas "57-71" e "89-103": no lugar vago do grupo 3, nos períodos 6 e 7.
	var faixas_certas := true
	for faixa: Dictionary in tela.FAIXAS:
		var casa: Vector2i = faixa["casa"]
		if Elementos.na_casa(casa.x, casa.y) != 0:
			faixas_certas = false
		if lugares.has(tela.canto_da_casa(casa)):
			faixas_certas = false
	_checar(faixas_certas and tela.FAIXAS[0]["texto"] == "57-71" and tela.FAIXAS[1]["texto"] == "89-103" \
		and (tela.FAIXAS[0]["casa"] as Vector2i) == Vector2i(2, 5) and (tela.FAIXAS[1]["casa"] as Vector2i) == Vector2i(2, 6),
		"as casas 57-71 e 89-103 ocupam o lugar vago do grupo 3, nos períodos 6 e 7")

	# Os tons das famílias.
	var sem_tom := PackedStringArray()
	for chave: int in Elementos.FAMILIAS:
		if not tela.TONS.has(chave) or (tela.TONS[chave] as Color).a <= 0.0:
			sem_tom.append(Elementos.nome_da_familia(chave as Elementos.Familia))
	_checar(sem_tom.is_empty(), "toda família tem o seu tom %s" % [sem_tom])
	var tons := {}
	for chave: int in tela.TONS:
		tons[(tela.TONS[chave] as Color).to_html()] = true
	_checar(tons.size() == Elementos.FAMILIAS.size(), "e nenhum tom se repete (%d tons)" % tons.size())
	var vao: Rect2 = tela.retangulo_do_vao()
	var legenda: Rect2 = tela.retangulo_da_legenda()
	var livres := true
	for z in range(1, Elementos.TOTAL + 1):
		var casa: Rect2 = tela.retangulo_da_casa(z)
		if casa.intersects(vao) or casa.intersects(legenda):
			livres = false
	_checar(livres and not vao.intersects(legenda), "o vão do alto (o elemento em foco e a legenda) não cobre casa nenhuma")
	_checar(legenda.size.y >= Elementos.FAMILIAS.size() * 15.5 - 4.0, "a legenda das %d famílias cabe no vão" % Elementos.FAMILIAS.size())
	await _foto("tabela_1_folha")
	await _fechar(tela)


func _testar_o_foco() -> void:
	print("\n--- O FOCO ---")
	var tela := await _abrir(CENA)
	_checar(tela.elemento_em_foco() == 0, "abre sem elemento em foco (o alto convida a clicar)")
	await _passar_por(tela, tela.nome_da_casa(26))
	_checar(tela.elemento_em_foco() == 26 and tela.alvo_em_foco() == "elemento_26", "o mouse em cima do ferro põe o foco nele")
	await _foto("tabela_2_foco")
	# Tirar o mouse de cima da tabela não apaga o foco (ele pode ter vindo das teclas).
	_mover_o_mouse(Vector2(20, 880))
	await _quadros(1)
	_checar(tela.elemento_em_foco() == 26, "tirar o mouse da folha não apaga o foco")

	# As teclas: do ferro (grupo 8, período 4) para os vizinhos.
	await _teclar(KEY_RIGHT)
	_checar(tela.elemento_em_foco() == 27, "→ vai do ferro ao cobalto")
	await _teclar(KEY_LEFT)
	await _teclar(KEY_LEFT)
	_checar(tela.elemento_em_foco() == 25, "← ← volta ao manganês")
	await _teclar(KEY_DOWN)
	_checar(tela.elemento_em_foco() == 43, "↓ desce ao tecnécio (o de baixo, no mesmo grupo)")
	await _teclar(KEY_UP)
	_checar(tela.elemento_em_foco() == 25, "↑ sobe de volta ao manganês (%s)" % Elementos.simbolo(tela.elemento_em_foco()))
	_checar(_tocou(tela, "passo"), "cada passo do foco faz o som de passo")
	# No topo da coluna dos metais de transição não há casa em cima: o foco vai
	# para a mais próxima das fileiras de cima.
	await _teclar(KEY_W)
	_checar(tela.elemento_em_foco() == 12, "W (↑) no topo da coluna vai à casa mais próxima de cima: o magnésio")
	await _teclar(KEY_D)
	_checar(tela.elemento_em_foco() == 13, "D (→) no magnésio pula o vão e vai ao alumínio, na mesma fileira")
	await _teclar(KEY_S)
	await _teclar(KEY_A)
	_checar(tela.elemento_em_foco() == 30, "S (↓) desce ao gálio e A (←) vai ao zinco")

	# Do hidrogênio para a direita: o hélio, do outro lado do vão.
	tela.focar("elemento_1")
	await _teclar(KEY_RIGHT)
	_checar(tela.elemento_em_foco() == 2, "→ no hidrogênio pula o vão e vai ao hélio")
	await _teclar(KEY_RIGHT)
	_checar(tela.elemento_em_foco() == 2, "na ponta da linha, → não sai do lugar")
	# Para as fileiras de baixo e de volta.
	tela.focar("elemento_105")
	await _teclar(KEY_DOWN)
	var embaixo: int = tela.elemento_em_foco()
	_checar(Elementos.e_lantanidio(embaixo), "↓ no 7º período desce para os lantanídios (%s)" % Elementos.simbolo(embaixo))
	await _teclar(KEY_DOWN)
	_checar(Elementos.e_actinidio(tela.elemento_em_foco()), "outro ↓ desce para os actinídios (%s)" \
		% Elementos.simbolo(tela.elemento_em_foco()))
	await _teclar(KEY_DOWN)
	_checar(Elementos.e_actinidio(tela.elemento_em_foco()), "e dali para baixo não há mais nada")
	# De qualquer casa se chega a qualquer outra só com as setas.
	var alcancados := {1: true}
	var fila: Array[int] = [1]
	while not fila.is_empty():
		var z: int = fila.pop_front()
		for direcao: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var vizinho: int = tela.elemento_da_casa(tela._vizinho(tela.nome_da_casa(z), direcao))
			if vizinho > 0 and not alcancados.has(vizinho):
				alcancados[vizinho] = true
				fila.append(vizinho)
	_checar(alcancados.size() == Elementos.TOTAL, "só com as setas se chega aos 118 elementos (%d)" % alcancados.size())
	await _fechar(tela)


func _testar_a_ficha() -> void:
	print("\n--- A FICHA ---")
	var tela := await _abrir(CENA)
	var fichas: Array = []
	tela.ficha_mudou.connect(func(z: int) -> void: fichas.append(z))

	await _clicar(tela, tela.nome_da_casa(6))
	_checar(tela.na_ficha == 6 and tela.ficha.visible and tela.veu.visible and fichas == [6],
		"clicar no carbono abre a ficha dele")
	_checar(tela.caixa_grande.numero_atomico == 6 and tela.caixa_grande.escala == 3 and tela.caixa_grande.com_nome,
		"com a caixa do carbono ampliada 3x e o nome dentro, como na página do caderno")
	_checar(tela.atomo.protons() == 6 and tela.atomo.neutrons() == 6 and tela.atomo.eletrons() == 6 \
		and tela.atomo.eletrons_por_camada() == PackedInt32Array([2, 4]),
		"e o átomo no modelo de camadas: 6 prótons, 6 nêutrons, 2 + 4 elétrons")
	_checar(_tocou(tela, "pop"), "abrir faz o estalo")
	_checar(tela.texto_das_camadas(6) == "K 2 · L 4" and tela.texto_do_lugar(6) == "grupo 14, período 2" \
		and tela.texto_da_natureza(6) == "2 isótopos; 98,93% é carbono-12",
		"a ficha diz: K 2 · L 4; grupo 14, período 2; 2 isótopos; 98,93%% é carbono-12")
	var linhas: Array = tela.linhas_da_ficha(6)
	_checar(linhas.size() == 4 and linhas[0][0] == "camadas" and linhas[1] == ["família", "não metal"] \
		and linhas[2][0] == "lugar" and linhas[3][0] == "na natureza", "quatro linhas: camadas, família, lugar e na natureza")
	_checar(not tela.alvo_disponivel(tela.nome_da_casa(8)) and tela.alvo_disponivel("anterior") and tela.alvo_disponivel("proximo"),
		"com a ficha aberta, as casas não valem; os botões ANTERIOR e PRÓXIMO, sim")
	# (Medidas com a ficha já aberta de todo: ela chega crescendo.)
	await _esperar(0.4)
	var tela_inteira := Rect2(Vector2.ZERO, tela.size)
	var papel: Rect2 = tela.ficha.get_global_rect()
	_checar(tela_inteira.encloses(papel), "a ficha cabe na tela %s" % papel)
	var fora_do_papel := PackedStringArray()
	for peca: Array in [["a caixa", tela.caixa_grande.get_global_rect()], ["o átomo", tela.atomo.get_global_rect()],
			["ANTERIOR", tela.retangulo_do_alvo("anterior")], ["PRÓXIMO", tela.retangulo_do_alvo("proximo")]]:
		if not papel.encloses(peca[1]):
			fora_do_papel.append("%s %s" % [peca[0], peca[1]])
	_checar(fora_do_papel.is_empty(), "e tudo dela cabe no papel %s" % [fora_do_papel])
	_checar(not tela.retangulo_do_alvo("anterior").intersects(tela.retangulo_do_alvo("proximo")) \
		and not tela.caixa_grande.get_global_rect().intersects(tela.atomo.get_global_rect()),
		"os botões não se cobrem, nem a caixa cobre o átomo")
	await _esperar(0.5)
	await _foto("tabela_3_ficha_carbono")

	# Passar de elemento.
	await _clicar(tela, "proximo")
	_checar(tela.na_ficha == 7 and tela.caixa_grande.numero_atomico == 7 and tela.atomo.protons() == 7 and fichas == [6, 7],
		"PRÓXIMO passa ao nitrogênio")
	await _teclar(KEY_RIGHT)
	await _teclar(KEY_D)
	_checar(tela.na_ficha == 9, "→ e D passam adiante (flúor)")
	await _teclar(KEY_LEFT)
	_checar(tela.na_ficha == 8 and tela.atomo.eletrons_por_camada() == PackedInt32Array([2, 6]), "← volta ao oxigênio")
	await _clicar(tela, "anterior")
	_checar(tela.na_ficha == 7, "ANTERIOR volta ao nitrogênio")
	await _teclar(KEY_UP)
	await _teclar(KEY_DOWN)
	_checar(tela.na_ficha == 7 and tela.ficha.visible, "↑ e ↓ não fazem nada com a ficha aberta")
	# Um clique dentro do papel (fora dos botões) não fecha.
	await _clicar_em(tela.caixa_grande.get_global_rect().get_center())
	_checar(tela.na_ficha == 7, "clicar dentro da ficha não a fecha")

	# As pontas.
	tela.abrir_ficha(1)
	_checar(not tela.alvo_disponivel("anterior") and tela.alvo_disponivel("proximo"), "no hidrogênio não há ANTERIOR")
	await _teclar(KEY_LEFT)
	_checar(tela.na_ficha == 1, "e ← não sai dele")
	_checar(tela.atomo.neutrons() == 0 and tela.texto_da_natureza(1) == "2 isótopos; 99,99% é hidrogênio-1",
		"o hidrogênio da ficha não tem nêutron (2 isótopos; 99,99%% é hidrogênio-1)")
	tela.abrir_ficha(118)
	_checar(tela.alvo_disponivel("anterior") and not tela.alvo_disponivel("proximo"), "no oganessônio não há PRÓXIMO")
	await _teclar(KEY_RIGHT)
	_checar(tela.na_ficha == 118 and tela.atomo.eletrons_por_camada() == Elementos.camadas(118),
		"e → não sai dele; o átomo tem as sete camadas")
	_checar(tela.texto_da_natureza(118) == tela.TXT_SEM_ESTAVEL and tela.texto_da_natureza(9) == "todo átomo é flúor-19",
		"elemento sem isótopo estável diz isso; com um só, \"todo átomo é flúor-19\"")
	_checar(tela.texto_do_lugar(57) == "período 6, fileira dos lantanídios" \
		and tela.texto_do_lugar(92) == "período 7, fileira dos actinídios", "os de baixo dizem a fileira: lantanídios, actinídios")
	await _esperar(0.5)
	await _foto("tabela_4_ficha_oganessonio")

	# Fechar: ENTER, ESC, E e o clique fora.
	fichas.clear()
	await _teclar(KEY_ENTER)
	_checar(tela.na_ficha == 0 and not tela.ficha.visible and not tela.veu.visible and fichas == [0], "ENTER fecha a ficha")
	_checar(tela.elemento_em_foco() == 118 and _tocou(tela, "tirar"), "e o foco fica no elemento que foi visto")
	_checar(tela.alvo_disponivel(tela.nome_da_casa(8)) and not tela.alvo_disponivel("proximo"), "as casas voltam a valer")
	await _teclar(KEY_ENTER)
	_checar(tela.na_ficha == 118, "ENTER na casa em foco abre a ficha dela")
	await _teclar(KEY_ESCAPE)
	_checar(tela.na_ficha == 0 and not tela.de_saida(), "ESC com a ficha aberta só fecha a ficha (não sai da tela)")
	await _teclar(KEY_E)
	_checar(tela.na_ficha == 118, "E também abre")
	await _teclar(KEY_E)
	_checar(tela.na_ficha == 0, "e fecha")
	await _clicar(tela, tela.nome_da_casa(79))
	_checar(tela.na_ficha == 79, "clicar no ouro abre a ficha do ouro")
	await _clicar_em(Vector2(60, 860))
	_checar(tela.na_ficha == 0 and tela.elemento_em_foco() == 79, "clicar fora do papel fecha")
	# O clique que fecha, se cair em cima de uma casa, não abre outra ficha.
	await _clicar(tela, tela.nome_da_casa(79))
	var casa_fora: Vector2 = tela.retangulo_da_casa(1).get_center()
	_checar(not tela.ficha.get_global_rect().has_point(casa_fora), "(a casa do hidrogênio fica fora do papel da ficha)")
	await _clicar_em(casa_fora)
	_checar(tela.na_ficha == 0, "o clique fora que cai numa casa só fecha: não abre a ficha dela")
	await _fechar(tela)


func _testar_os_textos() -> void:
	print("\n--- OS TEXTOS DOS 118 ---")
	var tela := await _abrir(CENA)
	var textos: Array = _textos_do_script(tela)
	textos.append(tela.TITULO_DA_FOLHA)
	for z in range(1, Elementos.TOTAL + 1):
		textos.append(Elementos.nome(z))
		textos.append(Elementos.nome_do_isotopo(z, Elementos.isotopo(z)).to_lower())
		for linha: Array in tela.linhas_da_ficha(z):
			textos.append_array(linha)
	for chave: int in Elementos.FAMILIAS:
		textos.append(Elementos.nome_da_familia(chave as Elementos.Familia))
		textos.append(Elementos.nome_da_familia(chave as Elementos.Familia, true))
	_checar(_letras_que_faltam(textos).is_empty(), "toda letra da folha e das fichas existe na fonte [%s]" \
		% _letras_que_faltam(textos))

	# O alto da folha: o que se escreve do elemento em foco cabe no vão.
	var vao: Rect2 = tela.retangulo_do_vao()
	var largos := PackedStringArray()
	for z in range(1, Elementos.TOTAL + 1):
		var maior := maxf(PecasDoLaboratorio.largura(Elementos.nome(z), 33),
			maxf(PecasDoLaboratorio.largura(tela.texto_do_lugar(z), tela.TAM_TEXTO),
			PecasDoLaboratorio.largura(Elementos.nome_da_familia(Elementos.familia(z)), tela.TAM_TEXTO)))
		if maior > vao.size.x:
			largos.append("%s (%.0f de %.0f)" % [Elementos.nome(z), maior, vao.size.x])
	_checar(largos.is_empty(), "no alto da folha, o nome, a família e o lugar de qualquer elemento cabem no vão %s" % [largos])
	var legenda: Rect2 = tela.retangulo_da_legenda()
	largos.clear()
	for chave: int in Elementos.FAMILIAS:
		var nome := Elementos.nome_da_familia(chave as Elementos.Familia, true)
		if 22.0 + PecasDoLaboratorio.largura(nome, tela.TAM_MIUDO) > legenda.size.x:
			largos.append(nome)
	_checar(largos.is_empty(), "os nomes das famílias cabem na legenda %s" % [largos])

	# A ficha de cada um: nada sai do papel, e nada encosta no átomo desenhado.
	tela.abrir_ficha(1)
	await _quadros(2)
	var papel: Vector2 = tela.ficha.size
	var caixa: Rect2 = Rect2(tela.caixa_grande.position, tela.caixa_grande.size)
	var meio_do_atomo: Vector2 = tela.atomo.position + tela.atomo.size * 0.5
	var apertados := PackedStringArray()
	var menor_folga := INF
	var mais_justo := ""
	for z in range(1, Elementos.TOTAL + 1):
		tela.abrir_ficha(z)
		# Até onde o desenho do átomo chega: a última camada mais meio elétron.
		var camadas: int = tela.atomo.eletrons_por_camada().size()
		var raio: float = tela.atomo.raio_da_camada(camadas - 1) + tela.atomo.lado_do_eletron() * 0.5
		var escritos: Array = []
		# [texto, x, y do alto, tamanho]
		escritos.append([Elementos.nome(z), 40.0, 64.0 - 40.0, tela.TAM_TITULO])
		var y: float = tela.Y_DAS_PARTICULAS
		var contagem := {"proton": z, "neutron": Elementos.neutrons(z), "eletron": z}
		for tipo: String in ["proton", "neutron", "eletron"]:
			var quantas := int(contagem[tipo])
			escritos.append(["%d %s" % [quantas, tela.TXT_PARTICULAS[tipo][0 if quantas == 1 else 1]],
				tela.X_DAS_PARTICULAS + tela.LADO_DO_ICONE + 12.0, y, tela.TAM_TEXTO])
			y += tela.PASSO_DAS_PARTICULAS
		escritos.append([tela.TXT_ISOTOPO_ESTAVEL, tela.X_DAS_PARTICULAS, y + 10.0, tela.TAM_MIUDO])
		escritos.append([Elementos.nome_do_isotopo(z, Elementos.isotopo(z)).to_lower(), tela.X_DAS_PARTICULAS, y + 30.0,
			tela.TAM_TEXTO])
		y = tela.Y_DAS_LINHAS
		for linha: Array in tela.linhas_da_ficha(z):
			# O nome da linha não pode entrar no valor dela.
			if tela.X_DOS_ROTULOS + PecasDoLaboratorio.largura(String(linha[0]), tela.TAM_TEXTO) + RESPIRO > tela.X_DOS_VALORES:
				apertados.append("%s: \"%s\" entra no valor" % [Elementos.simbolo(z), linha[0]])
			escritos.append([String(linha[1]), tela.X_DOS_VALORES, y, tela.TAM_TEXTO])
			y += tela.PASSO_DAS_LINHAS
		for escrito: Array in escritos:
			var fim: float = float(escrito[1]) + PecasDoLaboratorio.largura(String(escrito[0]), int(escrito[3]))
			var alto := float(escrito[2])
			var pe := alto + float(escrito[3]) + 4.0
			# Onde o círculo do átomo começa nessa altura (a mais próxima do meio).
			var dy := 0.0
			if meio_do_atomo.y < alto:
				dy = alto - meio_do_atomo.y
			elif meio_do_atomo.y > pe:
				dy = meio_do_atomo.y - pe
			var limite := papel.x - 24.0
			if dy < raio:
				limite = minf(limite, meio_do_atomo.x - sqrt(raio * raio - dy * dy))
			var folga := limite - fim
			if folga < menor_folga:
				menor_folga = folga
				mais_justo = "%s: \"%s\"" % [Elementos.simbolo(z), escrito[0]]
			if folga < RESPIRO:
				apertados.append("%s: \"%s\" (%.0f px de folga)" % [Elementos.simbolo(z), escrito[0], folga])
		# As partículas ao lado da caixa não entram nela, e as linhas ficam embaixo.
		if tela.X_DAS_PARTICULAS < caixa.end.x + RESPIRO or tela.Y_DAS_LINHAS < caixa.end.y + RESPIRO:
			apertados.append("%s: caixa" % Elementos.simbolo(z))
	_checar(apertados.is_empty(), "nas 118 fichas, nenhum texto sai do papel nem encosta no átomo %s" % [apertados.slice(0, 6)])
	print("  .     o mais justo: %s, com %.0f px de folga" % [mais_justo, menor_folga])
	var ultima_linha: float = tela.Y_DAS_LINHAS + 3 * tela.PASSO_DAS_LINHAS + tela.TAM_TEXTO + 4.0
	_checar(ultima_linha + RESPIRO <= (tela.BOTAO_ANTERIOR as Rect2).position.y \
		and (tela.BOTAO_ANTERIOR as Rect2).end.y + RESPIRO <= papel.y,
		"as linhas ficam acima dos botões, e os botões dentro do papel")
	await _fechar(tela)


func _testar_o_controle() -> void:
	print("\n--- NO CONTROLE ---")
	var tela := await _abrir(CENA)
	tela.focar("elemento_26")
	await _tocar_no_controle(JOY_BUTTON_DPAD_RIGHT)
	_checar(Controle.em_uso and tela.elemento_em_foco() == 27, "um toque no direcional leva o foco UMA casa (ferro -> cobalto)")
	_checar(CursorVirtual.ativo() and not CursorVirtual._com_cursor, "a barra de comandos aparece, sem o cursor")
	# O analógico: empurrado e segurado, um passo e depois a repetição; não uma enxurrada.
	_eixo_do_controle(JOY_AXIS_LEFT_X, 1.0)
	await _quadros(4)
	_checar(tela.elemento_em_foco() == 28, "o analógico empurrado dá UM passo (cobalto -> níquel)")
	# Tremendo no talo (um evento a cada tremida), continua sendo um passo só.
	for i in 6:
		_eixo_do_controle(JOY_AXIS_LEFT_X, 0.92 + 0.01 * i)
		await _quadros(1)
	_checar(tela.elemento_em_foco() == 28, "o polegar tremendo no talo não dispara outros passos")
	await _esperar(Controle.REPETICAO_ATRASO + Controle.REPETICAO_INTERVALO * 2.5)
	var depois: int = tela.elemento_em_foco()
	_checar(depois >= 30 and depois <= 32, "segurando, repete devagar como numa lista (chegou ao %s)" % Elementos.simbolo(depois))
	_eixo_do_controle(JOY_AXIS_LEFT_X, 0.0)
	await _quadros(3)
	var parado: int = tela.elemento_em_foco()
	await _esperar(0.3)
	_checar(tela.elemento_em_foco() == parado, "soltando o analógico, para")

	# ✕ abre a ficha; os lados passam; ✕ fecha.
	await _tocar_no_controle(JOY_BUTTON_A)
	_checar(tela.na_ficha == parado, "✕ abre a ficha do elemento em foco")
	_checar(tela.dicas_do_controle().any(func(d: Array) -> bool: return d[0] == "cruz" and d[1] == "FECHAR"),
		"a barra diz ✕ FECHAR")
	await _tocar_no_controle(JOY_BUTTON_DPAD_RIGHT)
	_checar(tela.na_ficha == parado + 1, "o direcional para a direita passa ao elemento seguinte")
	await _tocar_no_controle(JOY_BUTTON_DPAD_UP)
	_checar(tela.na_ficha == parado + 1, "para cima, nada")
	await _tocar_no_controle(JOY_BUTTON_A)
	_checar(tela.na_ficha == 0 and tela.elemento_em_foco() == parado + 1, "✕ fecha, e o foco fica no elemento visto")
	await _tocar_no_controle(JOY_BUTTON_A)
	await _tocar_no_controle(JOY_BUTTON_Y)
	_checar(tela.na_ficha == 0 and not tela.de_saida(), "△ com a ficha aberta só fecha a ficha")
	await _voltar_ao_teclado()
	await _fechar(tela)


func _testar_a_saida() -> void:
	print("\n--- SAIR ---")
	var tela := await _abrir(CENA)
	await _teclar(KEY_ESCAPE)
	_checar(tela.de_saida() and TransicaoDeCena.em_curso(), "ESC sem ficha pede para sair")
	await _teclar(KEY_ENTER)
	await _clicar(tela, tela.nome_da_casa(6))
	_checar(tela.na_ficha == 0, "de saída, a tela não abre mais ficha")
	var chegou := await _esperar_a_troca()
	_checar(chegou == TransicaoDeCena.CENA_LABORATORIO, "e a cena que chega é o menu do Laboratório")
	await _fechar(tela)
