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
#     tudo apaga, a tela fica preta e em silêncio, e a cortina leva ao world1;
#   * a música: o menu (de céu aberto, à tarde) toca a bossa da tarde, a
#     introdução toca a intro1, e ela some junto com a última imagem;
#   * o world1 que chega da introdução abre com a bossa nova tocando e a Cacau
#     entrando correndo pela esquerda (scripts/abertura_da_historia.gd): sem
#     controle e sem o aviso de "Pressione ... para movimentar-se" até ela
#     parar no x 940, quando os dois voltam;
#   * ENTER completa a página que está sendo escrita e, com ela inteira, passa
#     para a próxima; ESC pula tudo e leva ao world1; o ESPAÇO apertado na
#     introdução não vira pulo quando a Cacau chega.
#
#   godot --headless --path . res://tools/teste_introducao.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma imagem do vídeo,
# da foto e da tela preta do fim.

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
	_checar(roteiro.size() == 2, "o roteiro tem dois quadros (%d)" % roteiro.size())
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
	_checar(_musica() == MUSICA, "e toca a bossa da tarde: o céu do menu é o da tarde (%s)" % _musica().get_file())
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

	await _esperar_ate(func() -> bool:
		return intro.tela.modulate.a <= 0.0 and intro._alfa_da_moldura <= 0.0 and intro._pagina.alfa <= 0.0, 30.0)
	_checar(quadros == [0, 1], "os quadros passam na ordem do roteiro %s" % [quadros])
	_checar(paginas == _paginas_do_roteiro(), "e as páginas também (%d de %d)" % [paginas.size(), _paginas_do_roteiro().size()])
	_checar(not TransicaoDeCena.em_curso(), "no fim tudo apaga e a tela fica preta, sem trocar de cena ainda")
	await _foto("introducao_3_preta")
	var silencio := 0.0
	var inicio := Time.get_ticks_msec()
	while not TransicaoDeCena.em_curso() and Time.get_ticks_msec() - inicio < 20000:
		await get_tree().process_frame
		silencio += get_process_delta_time()
	_checar(silencio >= Introducao.SILENCIO_FINAL - 0.3, "o silêncio dura uns %.1f s antes do jogo" % silencio)
	_checar(TrilhaSonora.musica_atual() == null and TrilhaSonora.get_child_count() == 0,
		"   silêncio mesmo: a intro1 sumiu junto com a última imagem")
	var caminho := await _esperar_a_chegada()
	Engine.time_scale = 1.0
	_checar(caminho == CENA_HISTORIA, "e a cortina leva ao world1 (%s)" % caminho)
	_checar(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "com o ponteiro do mouse de volta")
	if caminho == CENA_HISTORIA:
		await _conferir_a_entrada_da_cacau()
	await _desfazer_a_fase()


## O world1 que acabou de chegar da introdução: a Cacau entra correndo.
func _conferir_a_entrada_da_cacau() -> void:
	print("\n--- A CACAU ENTRANDO NO WORLD1 ---")
	var mundo := get_tree().current_scene
	var abertura := mundo.get_node_or_null("AberturaDaHistoria")
	var cacau = get_tree().get_first_node_in_group("player")
	var aviso := mundo.get_node_or_null("BotaoMoviment") as CanvasItem
	var musica := TrilhaSonora._tocador
	_checar(abertura != null and cacau != null and aviso != null, "o world1 tem a abertura, a Cacau e o aviso de movimento")
	if abertura == null or cacau == null or aviso == null:
		return
	_checar(not EstadoMundo.abertura_pendente, "a abertura foi usada (não se repete ao recarregar a fase)")
	_checar(musica != null and musica.playing and _musica() == MUSICA,
		"a bossa nova já está tocando quando a tela clareia")
	_checar(musica != null and musica.stream.get("loop") == true, "e volta ao começo quando acaba")
	var sprite: AnimatedSprite2D = cacau._animated_sprite
	_checar(abertura.correndo() and cacau.global_position.x < abertura.destino_x and sprite.animation == &"run" \
		and not sprite.flip_h, "a Cacau entra correndo, da esquerda para a direita (x %d)" % roundi(cacau.global_position.x))
	_checar(abertura.largada.x < 0.0, "vinda de fora da tela (x %d)" % roundi(abertura.largada.x))
	_checar(not cacau.pode_se_mover and not aviso.visible, "sem controle e sem o aviso de movimento enquanto corre")
	await _foto("introducao_4_correndo")
	await _esperar_ate(func() -> bool: return not abertura.correndo(), 10.0)
	_checar(absf(cacau.global_position.x - 940.0) < 2.0 and cacau.pode_se_mover,
		"ela para no x 940 (%d) e o controle volta" % roundi(cacau.global_position.x))
	await _esperar(abertura.duracao_do_aviso + 0.2)
	_checar(aviso.visible and aviso.modulate.a >= 1.0, "e só então o aviso de movimento aparece")
	await _quadros(10)
	_checar(cacau.is_on_floor() and absf(cacau.global_position.x - 940.0) < 2.0, "de pé no chão, no mesmo lugar")
	await _foto("introducao_5_parada")


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
