extends Node

# Teste da coluna de destilação da fase do nitrogênio e da explicação do
# Dr. Chico (scripts/fases/destilador.gd, scripts/explicacao_destilador.gd,
# scripts/ui/coluna_destilacao.gd, scripts/ui/ficha_substancia.gd):
#
#   * A ARTE: a folha tem os dois desenhos (aço e raio X) e do de raio X saem
#     sozinhas as quatro bandejas, com a fenda de cada uma de um lado e a
#     borda que segura o líquido; as moléculas pequenas têm folha própria e a
#     FolhaMoleculas dá o N₂ e o Ar grandes;
#   * A QUÍMICA: o fundo, que ganha calor do ambiente, estaciona no ponto de
#     ebulição do oxigênio e o topo (resfriador) no do nitrogênio, com os
#     andares do meio entre os
#     dois, cada um mais frio que o de baixo. Cada substância fica líquida no
#     primeiro andar que está no ponto de ebulição dela: o oxigênio nem sai do
#     fundo, o argônio para um andar acima e o nitrogênio só no topo;
#   * O DESENHO ANIMADO, sozinho: aço → raio X → ar líquido a -200 °C → o
#     líquido ganha calor do ambiente e o nitrogênio ferve primeiro (só ele),
#     sobe e vira líquido no topo → o fundo chega a -183 °C, o argônio ferve
#     e sobe um andar, o oxigênio fica. Nenhuma molécula na bandeja errada;
#     pedir uma
#     etapa lá da frente não pula as do meio;
#   * NA FASE: a coluna mora no começo da fase 2; perto dela o botão e o
#     contorno acendem; o E para o jogo e abre a explicação em cima dela; as
#     falas do Dr. Chico (com o retrato do rádio) fazem o desenho andar, marca
#     por marca; a caixa de fala não cobre a coluna nem as fichas; no fim a
#     tela fecha sozinha e o jogo volta; o E abre de novo do zero; o ESC fecha
#     no meio;
#   * sem conversa (timeline vazia) o desenho passa sozinho e o E fecha;
#   * toda letra da tela existe na fonte, e em lugar nenhum ela fala em
#     "aquecer": não há aquecedor, o calor vem do ambiente.
#
#   godot --headless --path . res://tools/teste_destilador.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma imagem de cada
# momento da explicação na pasta, para conferir o desenho a olho.

const FASE := "res://scenes/fases/fase2_torre.tscn"
const TELA := "res://scenes/explicacao_destilador.tscn"
const TIMELINE := "res://timelines/cientista_destilador.dtl"
const PASSO := 1.0 / 60.0

var _falhas := 0
var _pasta_capturas := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			_pasta_capturas = arg.trim_prefix("--capturas=")
	await get_tree().process_frame

	await _testar_arte()
	await _testar_desenho_animado()
	await _testar_conversa()
	await _testar_na_fase()
	await _testar_sem_fala()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


# ─────────────────────────────────────────────────────────────
# A ARTE E A QUÍMICA
# ─────────────────────────────────────────────────────────────

func _testar_arte() -> void:
	print("\n--- A ARTE DA COLUNA ---")
	var coluna := ColunaDestilacao.new()
	add_child(coluna)
	await get_tree().process_frame

	_checar(coluna.tamanho_da_coluna() == Vector2(80, 181) * ColunaDestilacao.ESCALA,
		"os dois desenhos da folha foram achados, e a coluna tem 80 x 181 px de arte %s" % [coluna.tamanho_da_coluna()])
	var bandejas := coluna.bandejas()
	_checar(bandejas.size() == 4, "o raio X tem 4 bandejas (achei %d)" % bandejas.size())
	var lados := bandejas.map(func(b: Dictionary) -> int: return b["lado"])
	_checar(lados == [-1, 1, -1, 1],
		"as fendas alternam de lado, do fundo para o topo: esquerda, direita, esquerda, direita %s" % [lados])
	var bordas_ok := true
	var fendas_ok := true
	var subindo := true
	for i in bandejas.size():
		var b: Dictionary = bandejas[i]
		if int(b["borda"]) < 2:
			bordas_ok = false
		if int(b["fenda_x1"]) - int(b["fenda_x0"]) + 1 < 8:
			fendas_ok = false
		if i > 0 and int(b["y0"]) >= int(bandejas[i - 1]["y0"]):
			subindo = false
	_checar(bordas_ok, "toda bandeja tem a borda que segura o líquido")
	_checar(fendas_ok, "toda fenda tem largura para uma molécula passar")
	_checar(subindo, "as bandejas estão em ordem, do fundo para o topo")
	_checar(coluna.numero_de_andares() == 5, "a coluna tem 5 andares (o fundo e um por bandeja)")
	var serpentina: Rect2i = coluna.get("_serpentina")
	_checar(serpentina.has_area() and serpentina.end.y < int(bandejas[3]["y0"]) - 10,
		"a serpentina do resfriador cabe no alto da cúpula, acima da bandeja de cima %s" % [serpentina])
	_checar(not (coluna.get("_vaos_dos_pes") as Array).is_empty(),
		"e o calor do ambiente tem onde ser desenhado: embaixo do piso, entre os pés")

	print("\n--- A QUÍMICA ---")
	var pontos := {}
	for nome: String in ColunaDestilacao.SUBSTANCIAS:
		pontos[nome] = int(ColunaDestilacao.SUBSTANCIAS[nome]["ebulicao"])
	_checar(pontos == {"N2": -196, "O2": -183, "Ar": -186},
		"pontos de ebulição: N2 -196 °C, Ar -186 °C, O2 -183 °C")
	_checar(ColunaDestilacao.TEMPERATURA_DO_AR_LIQUIDO < pontos["N2"],
		"o ar entra a -200 °C: abaixo do ponto de ebulição do nitrogênio, é líquido inteiro")
	_checar(is_equal_approx(ColunaDestilacao.TEMPERATURA_DO_FUNDO, pontos["O2"]),
		"o fundo estaciona no ponto de ebulição do oxigênio (%d °C)" % pontos["O2"])
	_checar(is_equal_approx(ColunaDestilacao.TEMPERATURA_DO_TOPO, pontos["N2"]),
		"o resfriador segura o topo no ponto de ebulição do nitrogênio (%d °C)" % pontos["N2"])
	var topo := coluna.numero_de_andares() - 1
	var esfria := true
	for andar in range(1, coluna.numero_de_andares()):
		if coluna.temperatura_final_do_andar(andar) >= coluna.temperatura_final_do_andar(andar - 1):
			esfria = false
	_checar(esfria, "com a coluna ligada, cada andar é mais frio que o de baixo")
	_checar(is_equal_approx(coluna.temperatura_final_do_andar(0), ColunaDestilacao.TEMPERATURA_DO_FUNDO)
			and is_equal_approx(coluna.temperatura_final_do_andar(topo), ColunaDestilacao.TEMPERATURA_DO_TOPO),
		"do fundo (-183 °C) ao topo (-196 °C)")
	_checar(coluna.andar_de("O2") == 0, "o oxigênio fica líquido no fundo: nem sai de lá (andar %d)" % coluna.andar_de("O2"))
	_checar(coluna.andar_de("Ar") == 1, "o argônio para um andar acima (andar %d)" % coluna.andar_de("Ar"))
	_checar(coluna.andar_de("N2") == topo, "e o nitrogênio só vira líquido no topo (andar %d)" % coluna.andar_de("N2"))
	for nome: String in ["Ar", "N2"]:
		var andar := coluna.andar_de(nome)
		_checar(coluna.temperatura_final_do_andar(andar) <= pontos[nome] + 0.001
				and coluna.temperatura_final_do_andar(andar - 1) > pontos[nome],
			"%s: o andar dela está no ponto de ebulição, e o de baixo ainda é quente demais" % nome)
	_checar(is_equal_approx(coluna.temperatura_do_fundo(), ColunaDestilacao.TEMPERATURA_DO_AR_LIQUIDO)
			and is_equal_approx(coluna.temperatura_do_topo(), ColunaDestilacao.TEMPERATURA_DO_AR_LIQUIDO),
		"antes de ligar, a coluna inteira está na temperatura do ar líquido")

	print("\n--- AS MOLÉCULAS ---")
	var folha := load(ColunaDestilacao.CAMINHO_MOLECULAS) as Texture2D
	_checar(folha != null and folha.get_size() == Vector2(
			ColunaDestilacao.CELULA_DA_MOLECULA * ColunaDestilacao.QUADROS_DA_MOLECULA,
			ColunaDestilacao.CELULA_DA_MOLECULA * 3),
		"a folha das moléculas pequenas tem 3 linhas de 4 quadros de 12 px")
	if folha != null:
		var imagem := folha.get_image()
		var todos := true
		for linha in 3:
			for quadro in ColunaDestilacao.QUADROS_DA_MOLECULA:
				var celula := imagem.get_region(Rect2i(quadro * 12, linha * 12, 12, 12)).get_used_rect()
				if celula.size.x < 5 or celula.size.y < 5:
					todos = false
		_checar(todos, "os 12 quadros têm desenho")
		var deitada := imagem.get_region(Rect2i(0, 0, 12, 12)).get_used_rect()
		_checar(deitada.size.y * ColunaDestilacao.ESCALA_MOLECULA <= 4.0 * ColunaDestilacao.ESCALA,
			"a molécula deitada (o 1º quadro) cabe na fundura do líquido de uma bandeja")
	for par in [["N2", "O2"], ["Ar", "O"]]:
		var nova := FolhaMoleculas.textura(par[0])
		var origem := FolhaMoleculas.textura(par[1])
		_checar(nova != null and origem != null and nova.get_size() == origem.get_size(),
			"a FolhaMoleculas dá o %s grande, do tamanho do %s" % par)
		if nova != null:
			_checar(not _tem_cor(nova.get_image(), FolhaMoleculas.CORES_DO_OXIGENIO[0]),
				"e nele não sobrou o azul do oxigênio")
	coluna.queue_free()
	await get_tree().process_frame


func _tem_cor(imagem: Image, cor: Color) -> bool:
	for y in imagem.get_height():
		for x in imagem.get_width():
			var p := imagem.get_pixel(x, y)
			if p.a > 0.0 and p.is_equal_approx(cor):
				return true
	return false


# ─────────────────────────────────────────────────────────────
# O DESENHO ANIMADO, SOZINHO
# ─────────────────────────────────────────────────────────────

func _testar_desenho_animado() -> void:
	print("\n--- O DESENHO ANIMADO ---")
	var coluna := ColunaDestilacao.new()
	add_child(coluna)
	await get_tree().process_frame
	# Daqui em diante quem faz o tempo andar é o teste.
	coluna.set_process(false)
	var total := coluna.total_de_moleculas()
	var n2: int = ColunaDestilacao.SUBSTANCIAS["N2"]["quantas"]
	var o2: int = ColunaDestilacao.SUBSTANCIAS["O2"]["quantas"]
	var argonio: int = ColunaDestilacao.SUBSTANCIAS["Ar"]["quantas"]
	var topo := coluna.numero_de_andares() - 1
	_checar(total == n2 + o2 + argonio and total > 0, "as moléculas do ar estão prontas para entrar (%d)" % total)
	_checar(coluna.etapa_atual() == ColunaDestilacao.Etapa.FECHADA and coluna.esta_fechada(),
		"começa fechada: a coluna de aço")
	var ferveram: Array[String] = []
	coluna.ferveu.connect(func(nome: String) -> void: ferveram.append(nome))
	var assentaram: Array[String] = []
	coluna.assentou.connect(func(nome: String) -> void: assentaram.append(nome))
	var avisos := [0]
	coluna.separou.connect(func() -> void: avisos[0] += 1)

	coluna.ir_para(ColunaDestilacao.Etapa.RAIO_X)
	_andar(coluna, 0.4)
	_checar(coluna.etapa_atual() == ColunaDestilacao.Etapa.RAIO_X and not coluna.esta_fechada(),
		"o raio X começa a descer")
	_andar(coluna, 1.0)

	coluna.ir_para(ColunaDestilacao.Etapa.AR_LIQUIDO)
	_andar(coluna, 2.5)
	_checar(coluna.quantas_em(ColunaDestilacao.Estado.LIQUIDA) == total and coluna.liquidas_no_fundo() == total,
		"AR_LIQUIDO: o ar entra já líquido e enche o fundo (%d)" % coluna.liquidas_no_fundo())
	_checar(coluna.liquidas_no_fundo("N2") == n2 and coluna.liquidas_no_fundo("O2") == o2
			and coluna.liquidas_no_fundo("Ar") == argonio, "com as três substâncias misturadas")
	_checar(is_equal_approx(coluna.temperatura_do_fundo(), ColunaDestilacao.TEMPERATURA_DO_AR_LIQUIDO),
		"a -200 °C")
	_andar(coluna, 3.0)
	_checar(coluna.liquidas_no_fundo() == total and ferveram.is_empty(),
		"antes da etapa de ferver, nada ferve: o líquido fica onde está")

	# --- FERVER: só o nitrogênio ---
	coluna.ir_para(ColunaDestilacao.Etapa.FERVER)
	# Pouco mais de 1 s a 2 °C por segundo: o fundo ainda está abaixo de tudo.
	_andar(coluna, 1.2)
	_checar(coluna.temperatura_do_fundo() < -196.0 and coluna.liquidas_no_fundo() == total
			and ferveram.is_empty(),
		"FERVER: abaixo de -196 °C ainda nada ferve (fundo a %.1f °C)" % coluna.temperatura_do_fundo())
	_andar(coluna, 1.8)
	_checar(ferveram == ["N2"], "passando de -196 °C, quem ferve primeiro é o nitrogênio %s" % [ferveram])
	_checar(coluna.quantas_em(ColunaDestilacao.Estado.SUBINDO, "N2") > 0
			and coluna.liquidas_no_fundo("N2") < n2,
		"as moléculas dele saem do líquido e sobem como gás")
	_checar(coluna.liquidas_no_fundo("O2") == o2 and coluna.liquidas_no_fundo("Ar") == argonio,
		"o oxigênio e o argônio continuam líquidos no fundo")
	_andar(coluna, 25.0)
	_checar(is_equal_approx(coluna.temperatura_do_fundo(), -187.0),
		"o fundo para de subir um grau antes de o argônio ferver (%.1f °C)" % coluna.temperatura_do_fundo())
	_checar(is_equal_approx(coluna.temperatura_do_topo(), ColunaDestilacao.TEMPERATURA_DO_TOPO)
			and coluna.temperatura_do_topo() < coluna.temperatura_do_fundo(),
		"e o resfriador segura o topo em -196 °C: mais frio que o fundo")
	_checar(coluna.liquidas_no_fundo("N2") == 0, "não sobra nitrogênio no fundo")
	var n2_liquido := coluna.liquidas_na_bandeja("N2")
	var n2_gas := coluna.quantas_em(ColunaDestilacao.Estado.GAS_SOLTO, "N2")
	_checar(n2_liquido > 0 and n2_liquido + n2_gas == n2,
		"o nitrogênio está todo no topo: %d viraram líquido e %d seguem gás" % [n2_liquido, n2_gas])
	_checar(assentaram == ["N2"] and coluna.dono_do_andar(topo) == "N2",
		"e a plaquinha do topo passa a ser dele")
	_checar(ferveram == ["N2"] and coluna.liquidas_no_fundo() == o2 + argonio,
		"o resto não ferveu: oxigênio e argônio seguem no fundo (%d)" % coluna.liquidas_no_fundo())
	_checar(not coluna.separado(), "ainda não está separado: falta o argônio")

	# --- SEPARAR: o argônio; o oxigênio fica ---
	coluna.ir_para(ColunaDestilacao.Etapa.SEPARAR)
	_andar(coluna, 12.0)
	_checar(is_equal_approx(coluna.temperatura_do_fundo(), ColunaDestilacao.TEMPERATURA_DO_FUNDO),
		"SEPARAR: o fundo chega a -183 °C e para")
	_checar(ferveram == ["N2", "Ar"], "o argônio ferve depois; o oxigênio não ferve %s" % [ferveram])
	_checar(coluna.liquidas_na_bandeja("Ar") == argonio and coluna.dono_do_andar(1) == "Ar",
		"todo o argônio vira líquido um andar acima do fundo (%d)" % argonio)
	_checar(coluna.liquidas_no_fundo() == o2 and coluna.liquidas_no_fundo("O2") == o2
			and coluna.dono_do_andar(0) == "O2",
		"e no fundo só sobra o oxigênio, líquido (%d)" % o2)
	_checar(assentaram == ["N2", "Ar", "O2"],
		"ficaram no lugar nesta ordem: nitrogênio, argônio, oxigênio %s" % [assentaram])
	_checar(coluna.separado() and avisos[0] == 1, "a mistura está separada (e avisa uma vez só)")
	_checar(coluna.dono_do_andar(2) == "" and coluna.dono_do_andar(3) == "",
		"nos andares do meio não fica nada: são só passagem")
	var graus: Array[int] = []
	for andar in coluna.numero_de_andares():
		graus.append(coluna.graus_do_andar(andar))
	_checar(graus == [-183, -186, -190, -193, -196],
		"as temperaturas dos andares, do fundo para o topo %s" % [graus])
	for nome: String in ColunaDestilacao.SUBSTANCIAS:
		_checar(coluna.graus_do_andar(coluna.andar_de(nome)) == int(ColunaDestilacao.SUBSTANCIAS[nome]["ebulicao"]),
			"%s: a temperatura do andar em que ficou é o ponto de ebulição dela" % nome)
	_checar(coluna.quantas_em(ColunaDestilacao.Estado.GAS_SOLTO) == n2_gas,
		"só nitrogênio continua gás (lá no topo, no ponto de ebulição dele)")
	_checar(_cada_uma_na_sua_bandeja(coluna), "nenhuma molécula está na bandeja de outra substância")
	_checar(_todas_dentro_da_coluna(coluna), "nenhuma molécula saiu de dentro da coluna")

	coluna.fechar()
	_andar(coluna, 1.5)
	_checar(coluna.esta_fechada(), "fechar devolve a coluna de aço")

	# Pedir a última etapa de uma vez não pula as do meio: elas passam correndo.
	coluna.reiniciar()
	coluna.ir_para(ColunaDestilacao.Etapa.SEPARAR)
	var passou_por := {}
	for i in 60 * 40:
		coluna.avancar(PASSO)
		passou_por[coluna.etapa_atual()] = true
		if coluna.separado():
			break
	_checar(passou_por.has(ColunaDestilacao.Etapa.RAIO_X) and passou_por.has(ColunaDestilacao.Etapa.AR_LIQUIDO)
			and passou_por.has(ColunaDestilacao.Etapa.FERVER) and coluna.separado(),
		"pedindo SEPARAR direto, o desenho passa por raio X, ar líquido e ferver e ainda separa")
	_checar(_cada_uma_na_sua_bandeja(coluna) and coluna.liquidas_no_fundo("O2") == o2
			and coluna.liquidas_na_bandeja("Ar") == argonio and coluna.liquidas_no_fundo() == o2,
		"e separa do mesmo jeito")
	coluna.queue_free()
	await get_tree().process_frame


## Faz o desenho andar "segundos" de uma vez, sem esperar o relógio.
func _andar(coluna: ColunaDestilacao, segundos: float) -> void:
	for i in roundi(segundos / PASSO):
		coluna.avancar(PASSO)


func _cada_uma_na_sua_bandeja(coluna: ColunaDestilacao) -> bool:
	var pocas: Array = coluna.get("_pocas")
	for i in range(2, pocas.size()):
		for m in pocas[i].moleculas:
			if m.tipo != pocas[i].substancia:
				return false
	return true


func _todas_dentro_da_coluna(coluna: ColunaDestilacao) -> bool:
	var caixa := Rect2(Vector2.ZERO, coluna.tamanho_da_coluna())
	for m in coluna.get("_moleculas"):
		if not caixa.has_point(m.pos):
			return false
	return true


# ─────────────────────────────────────────────────────────────
# A CONVERSA (o arquivo da timeline)
# ─────────────────────────────────────────────────────────────

func _testar_conversa() -> void:
	print("\n--- A CONVERSA ---")
	_checar(FileAccess.file_exists(TIMELINE), "a timeline da explicação existe")
	var diretorio: Dictionary = ProjectSettings.get_setting("dialogic/directories/dtl_directory", {})
	_checar(diretorio.get("cientista_destilador", "") == TIMELINE,
		"e está registrada no Dialogic (project.godot)")
	var linhas := FileAccess.get_file_as_string(TIMELINE).split("\n", false)
	var marcas: Array[String] = []
	var marca_sem_fala := false
	var falas := 0
	var fala_longa := ""
	for i in linhas.size():
		var linha := linhas[i].strip_edges()
		if linha.begins_with("[signal arg=\""):
			marcas.append(linha.trim_prefix("[signal arg=\"").trim_suffix("\"]"))
			if i + 1 >= linhas.size() or not linhas[i + 1].begins_with("cientista"):
				marca_sem_fala = true
		elif linha.begins_with("cientista"):
			falas += 1
			var texto := linha.substr(linha.find(": ") + 2)
			if texto.length() > 100:
				fala_longa = texto
	_checar(marcas == ExplicacaoDestilador.MARCOS,
		"ela tem as marcas do desenho, na ordem %s" % [marcas])
	_checar(not marca_sem_fala, "cada marca vem logo antes da fala que a comenta")
	_checar(falas == marcas.size(), "uma fala por marca (%d)" % falas)
	_checar(fala_longa.is_empty(), "nenhuma fala passa de 100 letras %s" % fala_longa)
	_checar(linhas[0].contains("cientistaradio"), "o Dr. Chico entra com o retrato do rádio")
	var falas_juntas := FileAccess.get_file_as_string(TIMELINE).to_lower()
	_checar(_fala_em_aquecer(falas_juntas).is_empty(),
		"nenhuma fala (nem marca) fala em aquecer: o calor vem do ambiente %s" % _fala_em_aquecer(falas_juntas))
	_checar(falas_juntas.contains("calor do ambiente"), "é isso que o Dr. Chico diz")


# ─────────────────────────────────────────────────────────────
# NA FASE
# ─────────────────────────────────────────────────────────────

func _testar_na_fase() -> void:
	print("\n--- A COLUNA NA FASE 2 ---")
	var fase := await _abrir()
	var destilador := fase.get_node_or_null("Destilador") as Destilador
	_checar(destilador != null, "a coluna de destilação mora na fase 2")
	if destilador == null:
		await _fechar(fase)
		return
	var player := fase.get_node("Player") as CharacterBody2D
	var sprite := destilador.get_node("Sprite") as Sprite2D
	var dica := destilador.get_node("Dica") as CanvasItem
	var contorno := destilador.get_node("Sprite/Contorno") as Sprite2D
	var limites := fase.get_node("LimitesDaCamera") as ReferenceRect

	_checar(destilador.global_position.x > 200.0 and destilador.global_position.x < 1100.0,
		"no começo da fase, à vista de quem chega (x = %d)" % destilador.global_position.x)
	_checar(is_equal_approx(destilador.global_position.y, 512.0), "com o pé no chão de grama (y = 512)")
	var arte := sprite.get_global_transform() * sprite.get_rect()
	_checar(is_equal_approx(arte.end.y, destilador.global_position.y)
			and is_equal_approx(arte.get_center().x, destilador.global_position.x),
		"a arte cresce para cima do nó, centrada nele")
	_checar(arte.position.y >= limites.position.y, "e cabe inteira na altura da câmera")
	_checar(sprite.region_enabled and sprite.region_rect == Rect2(16, 7, 80, 181)
			and sprite.scale == Vector2(2, 2),
		"o que se vê no mapa é o desenho de aço, no tamanho dos tiles (×2)")
	_checar(sprite.z_index < player.z_index, "a Cacau passa na frente dela")
	var forma := destilador.get_node_or_null("Corpo/Forma") as CollisionPolygon2D
	var parede := Rect2()
	if forma:
		parede = Rect2(forma.global_transform * forma.polygon[0], Vector2.ZERO)
		for ponto in forma.polygon:
			parede = parede.expand(forma.global_transform * ponto)
	_checar(forma != null and destilador.get_node("Corpo") is StaticBody2D
			and (player.collision_mask & (destilador.get_node("Corpo") as StaticBody2D).collision_layer) != 0
			and absf(parede.size.x - arte.size.x) < 1.0 and absf(parede.size.y - arte.size.y) < 4.0,
		"ela é sólida, do tamanho da arte (a Cacau não atravessa)")
	_checar(contorno.texture != null and contorno.texture.get_size() == Vector2(82, 183),
		"o contorno foi montado da própria arte")
	_checar(destilador.explicacao != null, "a tela da explicação está ligada nela")
	_checar(destilador.tela() != null and not destilador.tela().visible and not destilador.explicando(),
		"e já fica montada, escondida, desde a chegada")

	# A fase abre no escuro e a Cacau chega andando: espera ela ficar livre.
	await _esperar(func() -> bool: return player.pode_se_mover and not get_tree().paused, 6.0)
	await _esperar_segundos(0.3)
	_checar(not dica.visible and not contorno.visible, "de longe, nem botão nem contorno")
	_checar(not destilador.ja_explicou(), "e a explicação ainda não foi vista")

	# A coluna é parede: encostada nela pela esquerda (capsula de raio 13).
	player.global_position = destilador.global_position + Vector2(-94, -12)
	player.velocity = Vector2.ZERO
	await _esperar(func() -> bool: return dica.visible, 2.0)
	_checar(dica.visible, "chegando perto, o botão acende")
	await _esperar_segundos(0.3)
	_checar(contorno.visible, "e o contorno em volta da coluna também")
	await _capturar("01_perto")

	# --- O E ---
	# A câmera ainda vem deslizando atrás da Cacau: espera ela parar, para a
	# coluna estar no mesmo lugar da tela antes e depois do toque.
	# (Com janela os quadros são de 2 ms e ela anda menos de um centésimo de
	# pixel por quadro bem antes de parar: só vale parada por meio segundo.)
	var na_tela := destilador.retangulo_na_tela()
	var parada := 0.0
	var esperou := 0.0
	while parada < 0.5 and esperou < 6.0:
		await get_tree().process_frame
		var passo := get_process_delta_time()
		esperou += passo
		var agora := destilador.retangulo_na_tela()
		parada = parada + passo if agora.position.distance_to(na_tela.position) < 0.05 else 0.0
		na_tela = agora
	# O toque tem de nascer no começo de um quadro (acabamos de esperar um):
	# apertado logo depois de um timer, ele chega depois do _process e o
	# "acabou de apertar" já passou.
	Input.action_press("interact")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("interact")
	var tela := destilador.tela()
	_checar(tela != null and tela.esta_aberta() and destilador.explicando(), "o E abre a explicação")
	if tela == null:
		await _fechar(fase)
		return
	var coluna := tela.coluna()
	var total := coluna.total_de_moleculas()
	var topo := coluna.numero_de_andares() - 1
	_checar(get_tree().paused and not player.pode_se_mover, "o jogo para e a Cacau não anda")
	_checar(Interacao.ocupada(), "e o E passa a ser da tela")
	_checar(not sprite.visible and not dica.visible and not contorno.visible,
		"a coluna do mapa sai de cena (com o botão e o contorno): quem aparece é a da tela")
	var origem: Rect2 = tela.get("_origem")
	_checar(na_tela.has_area() and origem.position.distance_to(na_tela.position) < 3.0
			and origem.size.distance_to(na_tela.size) < 1.0,
		"o desenho nasce em cima da coluna do mapa, do tamanho dela (mapa %s, tela %s)" % [na_tela, origem])
	_checar(coluna.get_global_rect().position.distance_to(na_tela.position) < 60.0
			and coluna.scale.x < 1.0,
		"e sai dali para o lugar dele na tela")
	_checar(coluna.esta_fechada(), "ainda como a coluna de aço")
	await _capturar("02_saindo_do_mapa")

	# --- A CONVERSA FAZ O DESENHO ANDAR ---
	_checar(await _esperar(func() -> bool: return tela.marco_atual() == "raio_x", 6.0),
		"a conversa começa e a primeira marca chega sozinha: raio_x")
	_checar(_retrato_no_ar() == "cientistaradio", "quem fala é o Dr. Chico, com o retrato do rádio")
	_checar(str(Dialogic.VAR.get_variable("reveal_name")) == "Dr. Chico", "com o nome dele na caixa")
	var lugar: Vector2 = tela.get("_lugar_da_coluna")
	_checar(coluna.get_global_rect().position.distance_to(lugar) < 1.0
			and coluna.scale.is_equal_approx(Vector2.ONE),
		"a coluna já está no lugar dela na tela, em tamanho cheio %s" % [lugar])
	var plaquinha_de_baixo := ColunaDestilacao.retangulo_da_plaquinha(coluna.lugar_da_plaquinha(0), "-183 °C", true)
	_checar(lugar.x + plaquinha_de_baixo.position.x >= 16.0,
		"com lugar à esquerda dela para a régua e as plaquinhas de temperatura")
	var palco: Node = Dialogic.Styles.get_layout_node()
	var caixa := palco.find_child("DialogTextPanel", true, false) as Control if palco else null
	_checar(palco != null and int(palco.get("layer")) > tela.layer, "a caixa de fala fica por cima da tela")
	await _esperar_segundos(1.2)
	if caixa != null:
		_checar(caixa.get_global_rect().position.x >= coluna.get_global_rect().end.x,
			"e não cobre a coluna (caixa em x = %d, coluna até x = %d)"
			% [caixa.get_global_rect().position.x, coluna.get_global_rect().end.x])
	_checar(coluna.etapa_atual() == ColunaDestilacao.Etapa.RAIO_X and not coluna.esta_fechada(),
		"raio_x: a coluna de aço vira o desenho preto")
	_checar(tela.titulo() == ExplicacaoDestilador.TITULO, "com o nome dela em cima")
	var fichas: Array[FichaSubstancia] = []
	for nome in ["N2", "Ar", "O2"]:
		fichas.append(tela.ficha_de(nome))
	_checar(not fichas.has(null), "há uma ficha para cada substância do ar (N2, Ar e O2)")
	_checar(fichas.all(func(f: FichaSubstancia) -> bool: return f.modulate.a < 0.01),
		"que ainda não apareceram")
	await _capturar("03_raio_x")

	_checar(await _ate(tela, "ar"), "passando a fala, chega a marca: ar")
	await _esperar_segundos(1.4)
	coluna.avancar(3.0)
	_checar(coluna.etapa_atual() == ColunaDestilacao.Etapa.AR_LIQUIDO
			and coluna.liquidas_no_fundo() == total,
		"ar: o ar líquido enche o fundo da coluna (%d moléculas)" % coluna.liquidas_no_fundo())
	_checar(coluna.graus_do_andar(0) == -200, "a -200 °C")
	_checar(fichas.all(func(f: FichaSubstancia) -> bool: return f.modulate.a > 0.99),
		"e as três fichas aparecem")
	_checar(fichas.all(func(f: FichaSubstancia) -> bool: return f.ebulicao_a_vista == 0.0),
		"ainda sem o ponto de ebulição")
	_checar(not _fichas_se_cobrem(fichas), "uma embaixo da outra, sem se cobrir")
	var alturas := {}
	for ficha in fichas:
		alturas[ficha.substancia] = ficha.get_global_rect().get_center().y
	_checar(alturas["N2"] < alturas["Ar"] and alturas["Ar"] < alturas["O2"],
		"na ordem dos andares da coluna: nitrogênio, argônio, oxigênio")
	await _capturar("04_ar")

	_checar(await _ate(tela, "ebulicao"), "marca: ebulicao")
	await _esperar_segundos(1.5)
	_checar(fichas.all(func(f: FichaSubstancia) -> bool: return f.ebulicao_a_vista > 0.99),
		"ebulicao: cada ficha mostra o ponto de ebulição")
	for ficha in fichas:
		_checar(ficha.texto_da_ebulicao() == "%d °C" % int(ColunaDestilacao.SUBSTANCIAS[ficha.substancia]["ebulicao"]),
			"%s: %s" % [ficha.substancia, ficha.texto_da_ebulicao()])
	_checar(fichas.all(func(f: FichaSubstancia) -> bool:
			var placa := f.retangulo_da_plaquinha()
			placa.position += f.global_position
			return placa.position.x >= f.get_global_rect().end.x and placa.end.x <= 1080.0),
		"a plaquinha fica à direita da ficha, sem entrar no retrato do Dr. Chico")
	if caixa != null:
		_checar(fichas.all(func(f: FichaSubstancia) -> bool:
				return f.get_global_rect().end.y <= caixa.get_global_rect().position.y),
			"e nenhuma ficha fica atrás da caixa de fala")
	_checar(coluna.liquidas_no_fundo() == total and not coluna.ja_ferveu("N2"),
		"na coluna nada mudou: o líquido segue a -200 °C")
	await _capturar("05_ebulicao")

	_checar(await _ate(tela, "ferver"), "marca: ferver")
	coluna.avancar(3.0)
	await get_tree().process_frame
	_checar(coluna.etapa_atual() == ColunaDestilacao.Etapa.FERVER and coluna.ja_ferveu("N2")
			and not coluna.ja_ferveu("Ar"),
		"ferver: o líquido ganha calor do ambiente e o nitrogênio (só ele) começa a ferver")
	_checar(tela.ficha_de("N2").pulsando() and not tela.ficha_de("Ar").pulsando(),
		"a plaquinha da ficha dele dá um pulo")
	_checar(coluna.liquidas_no_fundo("N2") < int(ColunaDestilacao.SUBSTANCIAS["N2"]["quantas"]),
		"e o gás sobe")
	await _capturar("06_fervendo")
	coluna.avancar(4.0)
	_checar(coluna.temperatura_do_topo() < coluna.temperatura_do_fundo(),
		"a coluna fica mais fria em cima (%d °C) que embaixo (%d °C)"
		% [coluna.graus_do_andar(topo), coluna.graus_do_andar(0)])
	_checar(not coluna.ja_assentou("N2"), "o nitrogênio ainda está a caminho do topo")

	_checar(await _ate(tela, "esfriar"), "marca: esfriar")
	await get_tree().process_frame
	await get_tree().process_frame
	_checar(not (coluna.get("_geada") as Array).is_empty(), "esfriar: o resfriador solta um sopro de geada")
	coluna.avancar(20.0)
	_checar(coluna.ja_assentou("N2") and coluna.dono_do_andar(topo) == "N2"
			and coluna.liquidas_na_bandeja("N2") > 0,
		"e no topo o nitrogênio vira líquido de novo")
	_checar(coluna.graus_do_andar(topo) == -196, "a -196 °C")
	_checar(coluna.liquidas_no_fundo("Ar") > 0 and not coluna.ja_ferveu("Ar"),
		"o argônio espera a vez dele")
	await _esperar_segundos(0.3)
	await _capturar("07_nitrogenio_no_topo")

	_checar(await _ate(tela, "separar"), "marca: separar")
	coluna.avancar(12.0)
	_checar(coluna.etapa_atual() == ColunaDestilacao.Etapa.SEPARAR and coluna.separado(),
		"separar: o fundo chega a -183 °C e a mistura se separa")
	_checar(coluna.ja_ferveu("Ar") and not coluna.ja_ferveu("O2"), "ferve o argônio; o oxigênio, não")
	_checar(coluna.dono_do_andar(0) == "O2" and coluna.dono_do_andar(1) == "Ar"
			and coluna.dono_do_andar(topo) == "N2",
		"oxigênio no fundo, argônio um andar acima, nitrogênio no topo")
	for ficha in fichas:
		var andar := coluna.andar_de(ficha.substancia)
		_checar(ficha.texto_da_ebulicao() == "%d °C" % coluna.graus_do_andar(andar),
			"%s: a plaquinha do andar dela mostra o mesmo número da ficha (%s)"
			% [ficha.substancia, ficha.texto_da_ebulicao()])
	await _esperar_segundos(0.5)
	await _capturar("08_separado")

	_checar(await _ate(tela, "fim"), "marca: fim")
	_checar(tela.titulo() == ExplicacaoDestilador.TITULO_FINAL, "fim: o título vira DESTILAÇÃO FRACIONADA")
	await _esperar_segundos(0.6)
	await _capturar("09_fim")

	# --- A ÚLTIMA FALA FECHA A TELA ---
	_checar(await _passar_ate(func() -> bool: return not tela.esta_aberta(), 8.0),
		"passando a última fala, a tela fecha sozinha")
	_checar(not get_tree().paused and player.pode_se_mover, "o jogo volta e a Cacau anda de novo")
	_checar(Dialogic.current_timeline == null and not Interacao.ocupada(), "a conversa acabou")
	_checar(sprite.visible, "a coluna do mapa reaparece")
	_checar(destilador.ja_explicou(), "e fica anotado que a explicação foi vista")
	await _esperar_segundos(0.4)
	_checar(dica.visible, "o botão acende de novo: dá para ver outra vez")
	await _capturar("10_de_volta")

	# --- DE NOVO, E O ESC NO MEIO ---
	destilador.explicar()
	_checar(tela.esta_aberta() and get_tree().paused, "o E abre de novo")
	_checar(coluna.esta_fechada() and coluna.liquidas_no_fundo() == 0 and tela.marco_atual() == ""
			and coluna.dono_do_andar(topo) == "",
		"do zero: a coluna de aço, sem nada dentro")
	_checar(await _esperar(func() -> bool: return tela.marco_atual() == "raio_x", 6.0),
		"e a conversa recomeça")
	_checar(await _ate(tela, "ferver"), "passando até o meio (ferver)")
	_apertar(&"fechar")
	await get_tree().process_frame
	await get_tree().process_frame
	_checar(await _esperar(func() -> bool: return not tela.esta_aberta(), 5.0),
		"o ESC fecha a tela no meio da explicação")
	_checar(Dialogic.current_timeline == null, "e corta a conversa")
	_checar(not get_tree().paused and player.pode_se_mover and sprite.visible,
		"o jogo volta do mesmo jeito")
	await _fechar(fase)


func _fichas_se_cobrem(fichas: Array[FichaSubstancia]) -> bool:
	for i in fichas.size():
		for j in range(i + 1, fichas.size()):
			if fichas[i].get_global_rect().intersects(fichas[j].get_global_rect()):
				return true
	return false


## O retrato do personagem que está no palco do Dialogic ("" se nenhum).
func _retrato_no_ar() -> String:
	var retratos: Dictionary = Dialogic.current_state_info.get("portraits", {})
	for caminho in retratos:
		return str(retratos[caminho].get("portrait", ""))
	return ""


# ─────────────────────────────────────────────────────────────
# SEM CONVERSA
# ─────────────────────────────────────────────────────────────

func _testar_sem_fala() -> void:
	print("\n--- SEM CONVERSA ---")
	var tela := (load(TELA) as PackedScene).instantiate() as ExplicacaoDestilador
	tela.timeline = ""
	add_child(tela)
	await get_tree().process_frame
	_checar(not tela.visible, "a tela nasce escondida")
	tela.abrir()
	_checar(tela.esta_aberta() and tela.visible and get_tree().paused, "abre mesmo sem coluna no mapa")
	var marcos: Array[String] = []
	tela.marco.connect(func(nome: String) -> void: marcos.append(nome))
	_checar(await _esperar(func() -> bool: return tela.marco_atual() == "fim", 40.0),
		"sem timeline, o desenho passa sozinho até o fim")
	_checar(marcos == ExplicacaoDestilador.MARCOS, "por todas as marcas, na ordem %s" % [marcos])
	_checar(Dialogic.current_timeline == null, "sem abrir conversa nenhuma")
	var coluna := tela.coluna()
	coluna.avancar(40.0)
	await _esperar(func() -> bool: return tela.get("_esperando_fechar"), 3.0)
	_checar(coluna.separado() and tela.get("_esperando_fechar"), "separou, e fica esperando o E")
	_apertar(Interacao.ACAO)
	await get_tree().process_frame
	await get_tree().process_frame
	_checar(await _esperar(func() -> bool: return not tela.esta_aberta(), 5.0), "o E fecha")
	_checar(not get_tree().paused and not tela.visible, "e o jogo volta")

	# Toda letra que a tela escreve existe na fonte.
	var textos: Array[String] = [ExplicacaoDestilador.TITULO, ExplicacaoDestilador.TITULO_FINAL,
		ExplicacaoDestilador.LEGENDA_DA_EBULICAO, ColunaDestilacao.LEGENDA_DO_RESFRIADOR,
		ColunaDestilacao.LEGENDA_DO_CALOR, "-200 °C -183 °C"]
	for nome in ["N2", "O2", "Ar"]:
		var ficha := tela.ficha_de(nome)
		textos.append_array([ficha.substancia, ficha.nome, ficha.parte_do_ar, "DO AR", ficha.texto_da_ebulicao()])
	var faltando := ""
	for texto in textos:
		for i in texto.length():
			var codigo := texto.unicode_at(i)
			if codigo > 32 and not ColunaDestilacao.FONTE.has_char(codigo):
				faltando += texto[i]
	_checar(faltando.is_empty(), "toda letra da tela existe na fonte %s" % faltando)
	_checar(_fala_em_aquecer(" ".join(textos).to_lower()).is_empty(),
		"e nenhum dizer da tela fala em aquecer")
	_checar(not ExplicacaoDestilador.MARCOS.has("aquecer"), "nem as marcas da conversa")
	tela.queue_free()
	await get_tree().process_frame


# ─────────────────────────────────────────────────────────────
# APOIO
# ─────────────────────────────────────────────────────────────

## Passa as falas do Dr. Chico até o desenho chegar na marca.
func _ate(tela: ExplicacaoDestilador, marco: String) -> bool:
	return await _passar_ate(func() -> bool: return tela.marco_atual() == marco, 8.0)


## Aperta "passar a fala" quatro vezes por segundo até a condição valer.
func _passar_ate(condicao: Callable, limite: float) -> bool:
	var t := 0.0
	var proximo := 0.0
	while not condicao.call() and t < limite:
		if t >= proximo:
			proximo = t + 0.25
			Dialogic.Inputs.handle_input()
		await get_tree().process_frame
		t += get_process_delta_time()
	return condicao.call()


## A palavra de "aquecer" ou de "esquentar" que houver no texto ("aquecedor",
## "esquenta"...), ou vazio. Palavra inteira: "enfraquece" não conta.
func _fala_em_aquecer(texto: String) -> String:
	var achado := RegEx.create_from_string("\\b(aquec|esquent)\\w*").search(texto)
	return achado.get_string() if achado != null else ""


## Um toque da ação, como evento (é o que o _input da tela escuta).
func _apertar(acao: StringName) -> void:
	var toque := InputEventAction.new()
	toque.action = acao
	toque.pressed = true
	Input.parse_input_event(toque)


func _esperar(condicao: Callable, limite: float) -> bool:
	var t := 0.0
	while not condicao.call() and t < limite:
		await get_tree().process_frame
		t += get_process_delta_time()
	return condicao.call()


func _esperar_segundos(segundos: float) -> void:
	await get_tree().create_timer(segundos, true).timeout


func _abrir() -> Node:
	var fase: Node = (load(FASE) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(fase)
	await get_tree().process_frame
	await get_tree().process_frame
	return fase


func _fechar(fase: Node) -> void:
	get_tree().paused = false
	fase.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _capturar(nome: String) -> void:
	if _pasta_capturas.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_pasta_capturas.path_join(nome + ".png"))
