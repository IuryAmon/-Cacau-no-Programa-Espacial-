extends "res://tools/teste_de_tela.gd"

# Teste da introdução do modo história (scenes/introducao.tscn,
# scripts/introducao.gd):
#
#   * o roteiro: o primeiro quadro é o vídeo da câmera de segurança, num
#     VideoStreamPlayer, com a legenda de Alcântara no alto; o segundo é a
#     foto da base destruída;
#   * toda letra do roteiro existe na fonte dos tutoriais; a telinha é menor
#     que a tela e fica no alto; a legenda cabe em cima dela e cada página
#     cabe embaixo, na parte preta (no máximo LINHAS_POR_PAGINA linhas);
#   * do menu, de verdade: MODO HISTÓRIA abre a introdução; sem ninguém
#     mexer, os quadros e as páginas passam na ordem do roteiro, o vídeo anda
#     o quadro inteiro (mais devagar, sem parar antes da narração acabar),
#     tudo apaga, a tela fica preta, e a cortina leva ao world1;
#   * a música: o menu fica sem música (por enquanto), a introdução toca a
#     intro1, e ela some junto com a foto da base: a segunda parte (o sonho,
#     a Lua, o quarto da Cacau, o jornal) e o fim são em silêncio;
#   * o world1 que chega da introdução abre num plano de grua
#     (scripts/abertura_da_historia.gd): a câmera no céu, sem HUD; o nome do
#     jogo acende com a bossa nova entrando de uma vez; a câmera desce até o
#     começo do mapa, o nome sai, e só então a Cacau entra correndo pela
#     esquerda, sem controle e sem o aviso de "Pressione ... para
#     movimentar-se" até ela parar no x 940, quando os dois e o HUD voltam;
#   * ENTER completa a página que está sendo escrita e, com ela inteira, passa
#     para a próxima; ESC pula tudo e leva ao world1; o ESPAÇO apertado na
#     introdução não vira pulo quando a Cacau chega; sair do world1 no meio da
#     abertura não deixa o HUD escondido.
#
#   godot --headless --path . res://tools/teste_introducao.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva imagens de cada parte:
# o vídeo, a foto, a Lua, a TV, o nome no céu, a descida, a Cacau entrando.

const CENA := "res://scenes/introducao.tscn"
const CENA_MENU := "res://scenes/menu_principal.tscn"
const CENA_HISTORIA := "res://scenes/world1.tscn"
const VIDEO := "res://Videos/2026-10-13 22-21-35.ogv"
const FOTO := "res://Videos/Q2SGOVHSJZK6JFHTSQKQBJY42Q.jpg"
const LEGENDA := "Centro Espacial de Alcântara, Maranhão."
const MUSICA := "res://sounds/Trilhas/bossa nova estilo stardew valley.mp3"
const MUSICA_DA_INTRODUCAO := "res://sounds/Trilhas/intro1.mp3"
const TELA_DO_JOGO := Vector2(1600, 900)
## A introdução inteira passa assim mais depressa no teste.
const PRESSA := 8.0


func _ready() -> void:
	await _comecar()
	await _testar_o_roteiro_e_o_desenho()
	await _testar_a_introducao_inteira()
	await _testar_adiantar_e_pular()
	_terminar()


# ─────────────────────────────────────────────────────────────
# APOIO
# ─────────────────────────────────────────────────────────────

## O arquivo da música que a TrilhaSonora está tocando ("" no silêncio).
func _musica() -> String:
	var musica := TrilhaSonora.musica_atual()
	return musica.resource_path if musica != null else ""


## Todas as páginas do roteiro, na ordem.
func _paginas_do_roteiro() -> Array[String]:
	var todas: Array[String] = []
	for quadro: Dictionary in Introducao.ROTEIRO:
		for pagina: String in quadro.get("paginas", []):
			todas.append(pagina)
	return todas


## Tira a introdução da tela sem a cortina: o roteiro para no quadro seguinte
## e só então ela é desfeita.
func _desmontar(intro: Introducao) -> void:
	intro._pulou = true
	await _quadros(2)
	intro.queue_free()
	await _quadros(2)


## Espera a cortina levar à próxima cena e devolve o caminho dela. A cena fica
## (quem chamou confere o que quiser e a desfaz com _desfazer_a_fase).
func _esperar_a_chegada() -> String:
	await _esperar_ate(func() -> bool: return TransicaoDeCena.em_curso(), 10.0)
	await _esperar_ate(func() -> bool: return not TransicaoDeCena.em_curso(), 20.0)
	await _quadros(2)
	var cena := get_tree().current_scene
	return cena.scene_file_path if cena != null else ""


func _desfazer_a_fase() -> void:
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()
	var cena := get_tree().current_scene
	if cena != null:
		cena.queue_free()
	await _quadros(3)


# ─────────────────────────────────────────────────────────────

func _testar_o_roteiro_e_o_desenho() -> void:
	print("\n--- O ROTEIRO E O DESENHO ---")
	var intro := await _trocar_de_cena(CENA) as Introducao
	_checar(intro != null, "a cena da introdução abre com o script dela")
	if intro == null:
		return
	var roteiro := Introducao.ROTEIRO
	_checar(roteiro.size() == 8, "o roteiro tem oito quadros (%d)" % roteiro.size())
	_checar(roteiro[1].get("para_a_musica", false), "a música para com a foto da base destruída")
	_checar(not roteiro[2].has("imagem") and roteiro[2]["paginas"] == ["Mas o sonho não morreu com eles."]
		and float(roteiro[2].get("escuro_antes", 0.0)) > 1.0,
		"depois, tela preta e silêncio, e \"Mas o sonho não morreu com eles.\" sem telinha")
	_checar(roteiro[3].get("imagem") is PackedScene and (roteiro[3]["paginas"] as Array).size() == 2
		and String(roteiro[3]["paginas"][1]).ends_with("a Lua!"),
		"\"Décadas depois...\" e \"...a Lua!\" em cima do céu estrelado com a lua")
	var provisorios := roteiro.filter(func(q: Dictionary) -> bool: return q.get("imagem") is String)
	_checar(provisorios.size() == 4, "o quarto, a TV, o rosto e o quarto vazio esperam o desenho (%d)" % provisorios.size())
	_checar(String(roteiro[roteiro.size() - 1].get("imagem", "")).contains("quarto vazio"),
		"e o último é o quarto vazio: o nome do jogo fica para o céu do world1")
	var imagem_do_video: Resource = roteiro[0]["imagem"]
	var imagem_da_foto: Resource = roteiro[1]["imagem"]
	_checar(imagem_do_video is VideoStream and imagem_do_video.resource_path == VIDEO,
		"o primeiro é o vídeo da câmera de segurança")
	_checar(String(roteiro[0].get("legenda", "")) == LEGENDA, "com a legenda de Alcântara no alto")
	_checar(imagem_da_foto is Texture2D and imagem_da_foto.resource_path == FOTO, "o segundo é a foto da base destruída")
	_checar(intro.video is VideoStreamPlayer and intro.video.get_parent() == intro.tela and intro.foto.get_parent() == intro.tela,
		"o vídeo toca num VideoStreamPlayer, dentro da telinha, junto com a foto")

	var textos: Array = []
	_juntar_textos(roteiro, textos)
	var faltando := _letras_que_faltam(textos)
	_checar(faltando.is_empty(), "toda letra do roteiro existe na fonte dos tutoriais [%s]" % faltando)

	var tela := intro.tela.get_rect()
	var com_moldura := tela.grow(Introducao.MOLDURA)
	_checar(Rect2(Vector2.ZERO, TELA_DO_JOGO).encloses(com_moldura), "a telinha e a moldura cabem na tela %s" % com_moldura)
	_checar(tela.size.x < TELA_DO_JOGO.x * 0.6 and tela.size.y < TELA_DO_JOGO.y * 0.66,
		"a telinha é menor que a tela (%s)" % tela.size)
	_checar(is_equal_approx(tela.size.aspect(), 4.0 / 3.0), "em 4:3, a proporção do vídeo (%.3f)" % tela.size.aspect())
	_checar(absf(tela.get_center().x - TELA_DO_JOGO.x * 0.5) < 1.0 and tela.position.y < TELA_DO_JOGO.y * 0.2,
		"centrada, no alto da tela")

	var altura := Introducao.FONTE.get_height(Introducao.TAM_LETRA)
	var entrelinha := Introducao.TAM_LETRA * Introducao.ENTRELINHA
	var topo_da_legenda := intro._topo_da_legenda()
	_checar(topo_da_legenda >= 16.0 and topo_da_legenda + altura <= com_moldura.position.y - 16.0,
		"a legenda fica entre o alto da tela e a moldura (%d)" % roundi(topo_da_legenda))
	var fora := PackedStringArray()
	for quadro: Dictionary in roteiro:
		var legenda := intro._montar(String(quadro.get("legenda", "")))
		if legenda.linhas.size() > 1:
			fora.append("legenda em %d linhas" % legenda.linhas.size())
		for pagina: String in quadro.get("paginas", []):
			var escrita := intro._montar(pagina)
			var fundo := intro._topo_do_texto() + (escrita.linhas.size() - 1) * entrelinha + altura
			if escrita.linhas.size() > Introducao.LINHAS_POR_PAGINA or fundo > TELA_DO_JOGO.y - 40.0:
				fora.append("\"%s...\" em %d linhas" % [pagina.left(20), escrita.linhas.size()])
			for linha in escrita.linhas:
				if Introducao.FONTE.get_string_size(linha, HORIZONTAL_ALIGNMENT_LEFT, -1, Introducao.TAM_LETRA).x \
						> Introducao.LARGURA_DO_TEXTO:
					fora.append("linha larga: \"%s\"" % linha)
	_checar(fora.is_empty(), "a legenda cabe numa linha e cada página cabe embaixo da telinha %s" % [fora])
	_checar(intro._topo_do_texto() > com_moldura.end.y, "o texto começa abaixo da moldura, na parte preta")
	await _desmontar(intro)


func _testar_a_introducao_inteira() -> void:
	print("\n--- A INTRODUÇÃO INTEIRA, DO MENU AO WORLD1 ---")
	var menu := await _trocar_de_cena(CENA_MENU) as TelaInterativa
	await _quadros(3)
	_checar(menu != null and menu.alvo_em_foco() == "historia", "o menu abre com o foco no MODO HISTÓRIA")
	_checar(_musica().is_empty(), "e fica sem música, por enquanto (%s)" % _musica().get_file())
	Engine.time_scale = PRESSA
	await _teclar(KEY_ENTER)
	var chegou := await _esperar_ate(func() -> bool:
		var cena := get_tree().current_scene
		return cena is Introducao and not TransicaoDeCena.em_curso(), 20.0)
	_checar(chegou, "ENTER no MODO HISTÓRIA abre a introdução, e não o world1 direto")
	var intro := get_tree().current_scene as Introducao
	if intro == null:
		Engine.time_scale = 1.0
		return
	_checar(_musica() == MUSICA_DA_INTRODUCAO and TrilhaSonora._tocador.playing,
		"a introdução toca a intro1 (%s)" % _musica().get_file())
	if DisplayServer.get_name() != "headless":
		_checar(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "o ponteiro do mouse some durante a introdução")

	var quadros: Array[int] = []
	var paginas: Array[String] = []
	var visto := {}
	intro.quadro_aberto.connect(func(i: int) -> void:
		quadros.append(i)
		visto["video_%d" % i] = intro.video.visible and intro.video.is_playing()
		visto["foto_%d" % i] = intro.foto.visible
		visto["textura_%d" % i] = intro.foto.texture.resource_path if intro.foto.texture != null else "")
	intro.pagina_aberta.connect(func(texto: String) -> void:
		paginas.append(texto)
		visto["video_na_pagina_%d" % paginas.size()] = intro.video.is_playing())
	# O ponto mais adiantado a que o vídeo chegou (olhado a cada quadro).
	var ponto := [0.0]
	var olhar_o_video := func() -> void:
		if is_instance_valid(intro) and intro.video.is_playing():
			ponto[0] = maxf(ponto[0], intro.video.stream_position)

	# O vídeo, com a legenda escrita e a página comprida inteira embaixo.
	await _esperar_ate(func() -> bool:
		olhar_o_video.call()
		return paginas.size() >= 2 and intro._pagina.completa(), 30.0)
	var comprimento := intro.video.get_stream_length()
	var velocidade := intro.video.speed_scale
	var esperada := comprimento / intro._duracao_do_quadro(Introducao.ROTEIRO[0], false)
	_checar(visto.get("video_0", false) and not visto.get("foto_0", true), "o primeiro quadro toca o vídeo (a foto fica escondida)")
	_checar(comprimento > 16.0 and velocidade < 1.0 and velocidade > 0.3 and absf(velocidade - esperada) < 0.01,
		"o vídeo (%.1f s) anda mais devagar, na medida do quadro: %.2f" % [comprimento, velocidade])
	_checar(intro._legenda.completa() and intro._legenda.alfa >= 1.0 and " ".join(intro._legenda.linhas) == LEGENDA,
		"a legenda está escrita no alto")
	await _foto("introducao_1_video")

	await _esperar_ate(func() -> bool:
		olhar_o_video.call()
		return quadros.size() >= 2, 30.0)
	_checar(visto.get("video_na_pagina_3", false), "o vídeo ainda anda durante a última página dele")
	_checar(ponto[0] >= comprimento * 0.85, "e chega ao fim junto com o quadro (%.1f de %.1f s)" % [ponto[0], comprimento])
	_checar(visto.get("foto_1", false) and visto.get("textura_1", "") == FOTO and not visto.get("video_1", true),
		"o segundo quadro mostra a foto, com o vídeo parado e escondido")

	await _esperar_ate(func() -> bool: return paginas.size() >= 5 and intro._pagina.completa(), 30.0)
	await _foto("introducao_2_foto")

	# A segunda parte: a música já foi embora com a foto.
	await _esperar_ate(func() -> bool: return quadros.size() >= 3, 30.0)
	_checar(TrilhaSonora.musica_atual() == null, "a intro1 some com a foto: a segunda parte começa em silêncio")
	await _esperar_ate(func() -> bool: return intro._pagina.completa() and intro._pagina.letras > 0, 30.0)
	var meio_do_texto := intro._topo_do_texto(intro._pagina)
	_checar(absf(meio_do_texto - TELA_DO_JOGO.y * 0.5) < 40.0 and intro._alfa_do_quadro > 0.0
		and not intro.video.visible and not intro.foto.visible,
		"\"Mas o sonho...\" fica no meio da tela preta, sem telinha (topo %d)" % roundi(meio_do_texto))
	await _foto("introducao_3_sonho")
	await _esperar_ate(func() -> bool:
		return quadros.size() >= 4 and intro._pagina.letras > 0 and intro._pagina.completa(), 60.0)
	_checar(intro._montagem != null and intro._montagem.get_parent() == intro.tela and intro._montagem.has_node("Lua"),
		"o céu estrelado está montado dentro da telinha")
	var ceu = intro._montagem
	_checar(ceu != null and is_zero_approx(ceu.lua_visivel()),
		"   em \"Décadas depois...\", só as estrelas: a lua ainda não aparece")
	await _foto("introducao_3_ceu")
	await _esperar_ate(func() -> bool:
		return paginas.size() >= 8 and is_instance_valid(ceu) and ceu.lua_visivel() >= 1.0, 30.0)
	_checar(paginas.size() >= 8 and paginas[7] == "...a Lua!" and is_instance_valid(ceu) and ceu.lua_visivel() >= 1.0,
		"   e ela acende com \"...a Lua!\"")
	await _foto("introducao_3_lua")
	await _esperar_ate(func() -> bool:
		return quadros.size() >= 6 and intro._pagina.letras > 0 and intro._pagina.completa(), 60.0)
	_checar(intro._alfa_do_quadro >= 1.0 and intro._quadro.get("imagem") is String,
		"a TV entra num corte seco, com a descrição provisória na telinha")
	await _foto("introducao_4_tv")
	_checar(TrilhaSonora.musica_atual() == null, "o jornal passa em silêncio")

	await _esperar_ate(func() -> bool:
		return intro.tela.modulate.a <= 0.0 and intro._alfa_do_quadro <= 0.0 and intro._pagina.alfa <= 0.0, 30.0)
	var todos: Array[int] = []
	for i in Introducao.ROTEIRO.size():
		todos.append(i)
	_checar(quadros == todos, "os quadros passam na ordem do roteiro %s" % [quadros])
	_checar(paginas == _paginas_do_roteiro(), "e as páginas também (%d de %d)" % [paginas.size(), _paginas_do_roteiro().size()])
	_checar(not TransicaoDeCena.em_curso(), "no fim tudo apaga e a tela fica preta, sem trocar de cena ainda")
	await _foto("introducao_6_preta")
	var silencio := 0.0
	var inicio := Time.get_ticks_msec()
	while not TransicaoDeCena.em_curso() and Time.get_ticks_msec() - inicio < 20000:
		await get_tree().process_frame
		silencio += get_process_delta_time()
	_checar(silencio >= Introducao.SILENCIO_FINAL - 0.3, "o silêncio dura uns %.1f s antes do jogo" % silencio)
	_checar(TrilhaSonora.musica_atual() == null and TrilhaSonora.get_child_count() == 0,
		"   silêncio mesmo: nenhuma música até o jogo")
	var caminho := await _esperar_a_chegada()
	Engine.time_scale = 1.0
	_checar(caminho == CENA_HISTORIA, "e a cortina leva ao world1 (%s)" % caminho)
	_checar(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "com o ponteiro do mouse de volta")
	if caminho == CENA_HISTORIA:
		await _conferir_a_entrada_da_cacau()
	await _desfazer_a_fase()


## Os HUDs da tela (o da Cacau e os autoload: equipamentos, objetivos,
## caderno) estão visíveis?
func _huds_visiveis(cacau: Node) -> Array[bool]:
	var da_cacau := cacau.get_node_or_null("CanvasLayer") as CanvasLayer
	var autoload := true
	for nome in FadeTela.HUDS_AUTOLOAD:
		var hud := get_tree().root.get_node_or_null(nome)
		if hud is CanvasLayer and not hud.visible:
			autoload = false
	return [da_cacau != null and da_cacau.visible, autoload]


## O world1 que acabou de chegar da introdução: o plano de grua. A câmera
## começa no céu, o nome do jogo acende com a bossa nova, a câmera desce até o
## começo do mapa e só então a Cacau entra correndo.
func _conferir_a_entrada_da_cacau() -> void:
	print("\n--- O WORLD1: O NOME NO CÉU, A CÂMERA DESCE, A CACAU ENTRA ---")
	var mundo := get_tree().current_scene
	var abertura := mundo.get_node_or_null("AberturaDaHistoria")
	var cacau = get_tree().get_first_node_in_group("player")
	var aviso := mundo.get_node_or_null("BotaoMoviment") as CanvasItem
	_checar(abertura != null and cacau != null and aviso != null, "o world1 tem a abertura, a Cacau e o aviso de movimento")
	if abertura == null or cacau == null or aviso == null:
		return
	var camera := cacau.get_node("Camera2D") as Camera2D
	_checar(not EstadoMundo.abertura_pendente, "a abertura foi usada (não se repete ao recarregar a fase)")
	_checar(abertura.etapa() == abertura.Etapa.TITULO and abertura.titulo() != null,
		"a tela clareia na primeira parte: o céu, esperando o nome do jogo")
	var altura_no_ceu := camera.get_screen_center_position().y
	var huds := _huds_visiveis(cacau)
	_checar(not huds[0] and not huds[1], "sem HUD nenhum durante a abertura %s" % [huds])
	var base := mundo.get_node("BG/BASE") as CanvasItem
	_checar(is_zero_approx(base.modulate.a), "a imagem da base de lançamento, que mostraria a borda lá do alto, fica apagada")
	_checar(not cacau.pode_se_mover and not aviso.visible
		and (cacau as Node2D).get_global_transform_with_canvas().origin.x < 0.0,
		"a Cacau espera fora da tela, sem controle e sem o aviso")

	# O nome e a música: de uma vez, juntos.
	Engine.time_scale = 2.0
	var entrada := {}
	await _esperar_ate(func() -> bool:
		var t := TrilhaSonora._tocador
		if t == null:
			return false
		entrada["volume"] = t.volume_db
		entrada["alfa"] = abertura.titulo().alfa if abertura.titulo() != null else -1.0
		return true, 10.0)
	_checar(_musica() == MUSICA and is_equal_approx(float(entrada.get("volume", -99.0)), TrilhaSonora.VOLUME_PADRAO_DB),
		"a bossa nova entra de uma vez, no volume normal (%.1f dB)" % float(entrada.get("volume", -99.0)))
	_checar(float(entrada.get("alfa", -1.0)) < 0.2, "   junto com o nome do jogo começando a acender")
	await _esperar_ate(func() -> bool: return abertura.titulo() != null and abertura.titulo().alfa >= 1.0, 10.0)
	_checar(absf(camera.get_screen_center_position().y - altura_no_ceu) < 8.0,
		"o nome fica inteiro no céu, com a câmera parada lá em cima (%.1f -> %.1f)" % [altura_no_ceu, camera.get_screen_center_position().y])
	# O sol, a serra e os morros na tela, para medir a paralaxe da descida.
	var fundo: Array[Node2D] = [mundo.get_node("BG/CamadaDoSol/Sol"), mundo.get_node("BG/4/Sprite2D"), mundo.get_node("BG/3/Sprite2D")]
	var fundo_no_ceu := fundo.map(func(no: Node2D) -> float: return no.get_global_transform_with_canvas().origin.y)
	await _foto("introducao_7_titulo_no_ceu")

	# A descida.
	await _esperar_ate(func() -> bool: return abertura.etapa() == abertura.Etapa.DESCIDA, 15.0)
	await _esperar(abertura.descida * 0.5)
	_checar(is_zero_approx(base.modulate.a), "   no meio da descida, a base de lançamento continua apagada")
	_checar(abertura.etapa() == abertura.Etapa.DESCIDA and camera.get_screen_center_position().y > altura_no_ceu + 100.0
		and absf(cacau.global_position.x - abertura.largada.x) < 1.0,
		"a câmera desce, com a Cacau ainda esperando fora da tela")
	await _foto("introducao_8_descendo")
	await _esperar_ate(func() -> bool: return base.modulate.a > 0.0, 15.0)
	await _quadros(2)
	await _foto("introducao_8b_base_acendendo")

	# A Cacau entra.
	await _esperar_ate(func() -> bool: return abertura.correndo(), 15.0)
	var no_lugar := camera.get_screen_center_position().y
	_checar(no_lugar > altura_no_ceu + 600.0,
		"a câmera desceu do céu até o chão (%d -> %d)" % [roundi(altura_no_ceu), roundi(no_lugar)])
	_checar(abertura.titulo() == null, "   e o nome do jogo já saiu")
	var subiu: Array[float] = []
	for i in fundo.size():
		subiu.append(fundo_no_ceu[i] - fundo[i].get_global_transform_with_canvas().origin.y)
	_checar(subiu[1] > subiu[0] * 1.3 and subiu[1] < subiu[2],
		"   na descida a serra sobe mais que o sol e menos que os morros (sol %d, serra %d, morros %d px)" % [roundi(subiu[0]), roundi(subiu[1]), roundi(subiu[2])])
	_checar(is_equal_approx(base.modulate.a, 1.0), "   e a base de lançamento acendeu de volta, atrás das árvores")
	await _quadros(20)
	var sprite: AnimatedSprite2D = cacau._animated_sprite
	_checar(abertura.correndo() and cacau.global_position.x > abertura.largada.x and sprite.animation == &"run" \
		and not sprite.flip_h, "só então a Cacau entra correndo, da esquerda para a direita (x %d)" % roundi(cacau.global_position.x))
	_checar(not cacau.pode_se_mover and not aviso.visible, "sem controle e sem o aviso de movimento enquanto corre")
	await _foto("introducao_9_correndo")
	await _esperar_ate(func() -> bool: return not abertura.correndo(), 15.0)
	Engine.time_scale = 1.0
	_checar(absf(cacau.global_position.x - 940.0) < 2.0 and cacau.pode_se_mover,
		"ela para no x 940 (%d) e o controle volta" % roundi(cacau.global_position.x))
	huds = _huds_visiveis(cacau)
	_checar(huds[0] and huds[1], "   o HUD volta %s" % [huds])
	await _esperar(abertura.duracao_do_aviso + 0.2)
	_checar(aviso.visible and aviso.modulate.a >= 1.0, "e o aviso de movimento aparece")
	await _quadros(10)
	_checar(cacau.is_on_floor() and absf(cacau.global_position.x - 940.0) < 2.0, "de pé no chão, no mesmo lugar")
	_checar(TrilhaSonora._tocador != null and TrilhaSonora._tocador.playing and _musica() == MUSICA,
		"com a bossa nova tocando")
	await _foto("introducao_10_parada")


func _testar_adiantar_e_pular() -> void:
	print("\n--- ADIANTAR E PULAR ---")
	var intro := await _trocar_de_cena(CENA) as Introducao
	if intro == null:
		_checar(false, "a cena da introdução abre")
		return
	var roteiro_das_paginas := _paginas_do_roteiro()
	var paginas: Array[String] = []
	intro.pagina_aberta.connect(func(texto: String) -> void: paginas.append(texto))
	Engine.time_scale = 4.0
	await _esperar_ate(func() -> bool: return paginas.size() >= 1 and intro._pagina.letras >= 3, 20.0)
	Engine.time_scale = 1.0
	_checar(not intro._pagina.completa(), "a primeira página aparece letra a letra")
	await _teclar(KEY_ENTER)
	await _quadros(2)
	_checar(intro._pagina.completa() and paginas.size() == 1, "ENTER no meio da escrita completa a página, sem trocar")
	await _teclar(KEY_ENTER)
	var trocou := await _esperar_ate(func() -> bool: return paginas.size() >= 2, 2.0)
	_checar(trocou and paginas[paginas.size() - 1] == roteiro_das_paginas[1], "com ela inteira, ENTER passa para a próxima")

	_tecla(KEY_SPACE, true)
	await _quadros(2)
	_checar(Interacao.toque_preso(&"jump"), "o ESPAÇO apertado na introdução fica preso a ela")
	await _teclar(KEY_ESCAPE)
	_checar(TransicaoDeCena.em_curso(), "ESC pula a introdução")
	Engine.time_scale = PRESSA
	var caminho := await _esperar_a_chegada()
	Engine.time_scale = 1.0
	_checar(caminho == CENA_HISTORIA, "direto para o world1 (%s)" % caminho)
	_checar(Interacao.toque_preso(&"jump") and not Interacao.livre_para(&"jump"),
		"com o ESPAÇO ainda apertado na chegada, a Cacau não pula")
	_tecla(KEY_SPACE, false)
	await _quadros(3)
	await _desfazer_a_fase()
	var autoload_de_volta := true
	for nome in FadeTela.HUDS_AUTOLOAD:
		var hud := get_tree().root.get_node_or_null(nome)
		if hud is CanvasLayer and not hud.visible:
			autoload_de_volta = false
	_checar(autoload_de_volta, "sair do world1 no meio da abertura não deixa o HUD escondido")
