extends Node

# --- O LANÇAMENTO, NO TELHADO DA TORRE (fase 2) ---
#
# Na primeira vez que a Cacau passa do meio do telhado rumo ao elevador, o Dr.
# Chico sobe atrás dela: "Corre, senão você vai perder!". Os dois vão até a
# grade do fundo, a câmera abre para o céu e, na contagem dele, um foguete
# brasileiro sobe lá longe levando um satélite para a órbita. É nessa conversa
# que ele conta: passando no teste, ela vai para a LUA — e por que o programa
# precisava de uma criança (a vírgula trocada nas contas do módulo lunar).
#
# Quem dispara é o fase2_telhado.gd, que também guarda as regulagens (grupo
# "Lançamento" no Inspector da raiz do telhado). Tudo aqui nasce na hora e vai
# embora no fim: nada disto fica gravado na cena. Acontece uma vez só
# (MissaoNitrogenio.viu_o_lancamento).
#
# A CENA, em ordem:
#   1. "CACAU!": entram as faixas de cinema e o HUD some; ela para e se vira;
#      ele chega correndo pela esquerda e para ofegante ao lado dela
#   2. timelines/cientista_lancamento_chegada.dtl
#   3. os dois vão até a grade do fundo e a câmera abre devagar para o céu,
#      até a lua aparecer; a trilha da fase silencia
#   4. os holofotes da base acendem lá no horizonte e ele conta no balão
#      ("3...", "2...", "1...")
#   5. a ignição (scripts/fx/foguete_ao_longe.gd): um "!" na cabeça dela; o
#      clarão no horizonte esquenta os dois e a grade, a nuvem de fumaça rola
#      por cima da beirada, o ronco chega atrasado (o som anda mais devagar que
#      a luz) e o telhado treme; o foguete sai da nuvem, deita rumo à lua,
#      solta os propulsores e some
#   6. timelines/cientista_lancamento_lua.dtl — antes do "Você vai... pra Lua."
#      a caixa de fala some e, em silêncio, a câmera chega devagar nos dois
#      (DialogicBridge.lancamento_suspense); no "EU?! PRA LUA?!" ela comemora
#      e a câmera volta para o céu (DialogicBridge.lancamento_comemorar)
#   7. ele volta para a escada, a câmera volta, as faixas saem, o HUD e o
#      controle voltam; o rastro do foguete se desfaz devagar no céu
#
# A MÚSICA DA CENA é a "Musica Do Lancamento" do telhado (vazio = só os sons
# do lançamento). Ela entra no momento de "Musica Entra" e some no fim, quando
# a trilha da fase volta.

signal terminou

const GRUPO := &"cena_do_lancamento"
const TIMELINE_CHEGADA := "res://timelines/cientista_lancamento_chegada.dtl"
const TIMELINE_LUA := "res://timelines/cientista_lancamento_lua.dtl"
const CENA_DO_CIENTISTA := preload("res://scenes/cientista.tscn")
const CENA_DO_BALAO := preload("res://scenes/dialog_box.tscn")
const FOGUETE := preload("res://scripts/fx/foguete_ao_longe.gd")
const FAIXAS := preload("res://scripts/ui/faixas_de_cinema.gd")
const SOM_DO_RONCO := preload("res://sounds/somfoguete2.mp3")
const SOM_DO_ESTRONDO := preload("res://assets/simulador lua/sons/explosion-very-far-away-gamemaster-audio-3-00-03.mp3")

enum Musica { NA_CHEGADA, NA_IGNICAO, NA_CONVERSA }

# ─── Regulagens (o fase2_telhado.gd passa as do Inspector dele) ───
## Onde a Cacau para na grade do fundo (x do mundo). Ele fica à esquerda dela.
var beirada_x := 880.0
## Zoom da câmera olhando o céu (menor = mais céu; em 1,6 a lua aparece).
var zoom_do_ceu := 1.6
var musica: AudioStream = null
var volume_da_musica_db := -6.0
var musica_entra: int = Musica.NA_IGNICAO
## A beirada do fundo do telhado (y do mundo): acima dela, por entre a grade,
## o céu aparece. O foguete parte escondido logo abaixo.
var beirada_do_fundo_y := 508.0
## A porta da escada (x do mundo): é por lá que ele vai embora no fim.
var porta_x := 260.0

# ─── A composição do céu, em fração da tela no zoom do céu ───
## Onde o foguete sobe (x).
const FOGUETE_X := 0.6
## O ponto que puxa a curva do voo (a virada para a direita).
const CURVA := Vector2(0.615, 0.42)
## Onde ele vira um ponto e some: logo abaixo da lua.
const CHEGADA := Vector2(0.83, 0.305)
## Quanto, da largura vista, o meio dos dois fica à esquerda do centro.
const FOLGA_PARA_O_CEU := 0.16

## O som chega depois da luz: segundos entre a ignição e o ronco.
const ATRASO_DO_SOM := 1.3
## Volume do ronco no máximo (dB) e o tom (mais grave = mais longe).
const VOLUME_DO_RONCO_DB := -7.0
const TOM_DO_RONCO := 0.62
## Tremor da câmera com o ronco no máximo (px do mundo).
const TREMOR := 1.4
## Força máxima da luz quente que o lançamento joga nos dois.
const LUZ_DO_LANCAMENTO := 1.8
## O "!" que sobe na cabeça da Cacau na ignição (o emote vermelho do pacote;
## o ExclamacaoFoguete dela é o "?" laranja).
const EMOTE_EXCLAMACAO := preload("res://assets/UI/Pipoya Popup  Emotes Pack/pipo-popupemotes Split images/pipo-popupemotes001.png")
## O "?!" do susto, no "EU?! PRA LUA?!".
const EMOTE_SUSTO := preload("res://assets/UI/Pipoya Popup  Emotes Pack/pipo-popupemotes Split images/pipo-popupemotes003.png")

## A escala do Dr. Chico na cena dele, para uma Cacau de escala 1.
const ESCALA_DO_CIENTISTA := 1.4
## Da origem do Dr. Chico até a sola (a base da cápsula dele), sem escala.
const PES_DO_CIENTISTA := 46.67
## Px/s em que o "andando" dele bate com o chão, na escala 1,4.
const PASSO_DO_CIENTISTA := 120.0
## Px/s em que a corrida da Cacau bate com o chão (a velocidade na faixa).
const PASSO_DA_CACAU := 250.0
## Quanto à esquerda dela ele para.
const AFASTAMENTO := 58.0
## Chegando ofegante: a velocidade da animação de parado dele (1 = normal),
## quantos segundos ela fica assim e em quantos acalma de volta ao normal.
const FOLEGO_OFEGANTE := 2.2
const FOLEGO_SEGURA := 1.5
const FOLEGO_ACALMA := 6.0
## O suspense antes do "pra Lua": o zoom da câmera chegando nos dois e o
## tempo da aproximação (s).
const ZOOM_DO_SUSPENSE := 2.5
const APROXIMACAO_DO_SUSPENSE := 2.8
## Depois da comemoração, o tempo da câmera voltando para o céu (s).
const VOLTA_PARA_O_CEU := 2.6
## Altura do pulinho de susto no "EU?! PRA LUA?!" (px).
const PULINHO_DO_SUSTO := 12.0
## Quanto tempo o balão "?!" fica no ar antes de começar a sumir (s).
const TEMPO_DO_SUSTO := 1.1
## Do balão: onde fica a ponta do rabinho, no desenho dele (sem escala).
const PONTA_DO_BALAO := Vector2(12.0, 0.0)
const ESCALA_DO_BALAO := 0.6

var fase: Node2D
var _cacau: CharacterBody2D
var _sprite_cacau: AnimatedSprite2D
var _camera: Camera2D
var _chico: Node2D
var _sprite_chico: AnimatedSprite2D
var _foguete: FOGUETE
var _faixas: FAIXAS
var _fade: FadeTela
var _luz: LuzPontual
var _ronco: AudioStreamPlayer
var _musica: AudioStreamPlayer
var _pausou_a_trilha := false
var _limite_de_cima := 0
var _mexeu_no_limite := false
var _segurando_a_camera := false
var _centro := Vector2.ZERO
## Onde a câmera fica no plano aberto (o céu com a lua).
var _centro_do_ceu := Vector2.ZERO
var _folego: Tween
var _virando := false
var _desde_a_ignicao := -1.0
var _som_chegou := false
var _huds_escondidos := false
var _acabou := false


func _init() -> void:
	name = "LancamentoNoTelhado"


func _ready() -> void:
	add_to_group(GRUPO)
	set_process(false)


## A cena inteira. Chamado pelo telhado com a Cacau livre e no chão.
func comecar() -> void:
	fase = get_parent() as Node2D
	_cacau = fase.get("player") as CharacterBody2D
	if _cacau == null:
		queue_free()
		return
	_sprite_cacau = _cacau.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_camera = _cacau.get_node_or_null("Camera2D") as Camera2D

	MissaoNitrogenio.viu_o_lancamento = true
	# Enquanto a cena roda, o E e os botões do mundo são dela.
	Interacao.marcar_tela_aberta(self, true)
	_travar_a_cacau()
	_fade = FadeTela.criar(fase)
	_fade.esconder_huds(fase)
	_huds_escondidos = true
	# Depois do esconder_huds: ele apagaria as faixas também.
	_faixas = FAIXAS.new()
	fase.add_child(_faixas)
	_faixas.entrar(0.9)
	if musica_entra == Musica.NA_CHEGADA:
		_tocar_a_musica()
	set_process(true)

	await _esperar(0.45)
	if not _viva():
		return
	await _o_grito()
	if not _viva():
		return
	await _a_chegada()
	if not _viva():
		return
	await _conversa(TIMELINE_CHEGADA)
	if not _viva():
		return
	await _ir_para_a_beirada()
	if not _viva():
		return
	await _contagem()
	if not _viva():
		return
	await _lancamento()
	if not _viva():
		return
	if musica_entra == Musica.NA_CONVERSA:
		_tocar_a_musica()
	await _conversa(TIMELINE_LUA)
	if not _viva():
		return
	await _encerrar()


# ───────────────────────────────────────────────────────────── 1. o grito

func _o_grito() -> void:
	var visivel := _retangulo_visivel()
	var cabeca := _cacau.global_position.y - 64.0
	var balao := _balao("CACAU!", Vector2(visivel.position.x + 12.0, cabeca))
	await _esperar(0.4)
	# Ela para e se vira para o grito.
	if _sprite_cacau:
		_sprite_cacau.flip_h = true
	await _esperar(1.0)
	_fechar_balao(balao)


# ───────────────────────────────────────────────────────────── chegada

func _a_chegada() -> void:
	_chico = CENA_DO_CIENTISTA.instantiate() as Node2D
	_chico.name = "DrChicoNoTelhado"
	var escala := ESCALA_DO_CIENTISTA * absf(_cacau.scale.x)
	_chico.scale = Vector2(escala, escala)
	_chico.z_index = _cacau.z_index
	fase.add_child(_chico)
	# Desenhado antes dela: passando junto, ela fica na frente.
	fase.move_child(_chico, _cacau.get_index())
	_virar_ator(_chico)
	_sprite_chico = _chico.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

	var fundo := _faixa().position.y
	var pes := clampf(_pes_da_cacau(), fundo, fundo + 18.0)
	var visivel := _retangulo_visivel()
	_por_os_pes(_chico, Vector2(visivel.position.x - 50.0, pes))
	var chegada := _andar(_chico, _sprite_chico, Vector2(_cacau.global_position.x - AFASTAMENTO, pes),
		210.0, true, &"andando", &"default")
	await _esperar_tween(chegada)
	if not _viva():
		return
	_ofegar(_sprite_chico)
	await _esperar(0.9)


## O cientista.gd é o Dr. Chico que conversa e anda sozinho. Aqui ele é ator:
## sem física, sem conversa no E, visível — quem o move é esta cena.
func _virar_ator(chico: Node2D) -> void:
	chico.set_physics_process(false)
	chico.set_process(false)
	var area := chico.get_node_or_null("Area2D") as Area2D
	if area:
		area.set_deferred("monitoring", false)
	var forma := chico.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if forma:
		forma.set_deferred("disabled", true)
	# Ele some quando alguém muda o nome dele no Dialogic: aqui não pode.
	var ao_mudar_o_nome := Callable(chico, &"_on_variable_was_set")
	if chico.has_method(&"_on_variable_was_set") \
			and Dialogic.VAR.variable_was_set.is_connected(ao_mudar_o_nome):
		Dialogic.VAR.variable_was_set.disconnect(ao_mudar_o_nome)
	chico.visible = true


## Chegou correndo: a animação de parado dele (a respiração) bem mais rápida,
## ofegante, e acalmando aos poucos durante a primeira conversa.
func _ofegar(sprite: AnimatedSprite2D) -> void:
	if sprite == null:
		return
	_tocar(sprite, &"default")
	sprite.speed_scale = FOLEGO_OFEGANTE
	_folego = create_tween()
	_folego.tween_interval(FOLEGO_SEGURA)
	_folego.tween_property(sprite, "speed_scale", 1.0, FOLEGO_ACALMA) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _parar_de_ofegar() -> void:
	if _folego and _folego.is_valid():
		_folego.kill()
	_folego = null
	if _sprite_chico:
		_sprite_chico.speed_scale = 1.0


# ───────────────────────────────────────────────────────────── 3. a beirada

func _ir_para_a_beirada() -> void:
	_pausar_a_trilha(2.5)
	_parar_de_ofegar()
	var fundo := _faixa().position.y
	var pes_dela := Vector2(beirada_x, fundo + 3.0)
	var pes_dele := Vector2(beirada_x - AFASTAMENTO, fundo + 1.0)
	var camera := _abrir_para_o_ceu(3.4)
	var ele := _andar(_chico, _sprite_chico, pes_dele, 150.0, true, &"andando", &"default")
	var ela := _andar(_cacau, _sprite_cacau, pes_dela, 190.0, false, &"run", &"idle", 0.35)
	await _esperar_tween(ele)
	await _esperar_tween(ela)
	if not _viva():
		return
	# Os dois de frente para o céu (o foguete sobe à direita deles).
	if _sprite_chico:
		_sprite_chico.flip_h = true
	if _sprite_cacau:
		_sprite_cacau.flip_h = false
	await _esperar_tween(camera)


## A câmera abre devagar: o zoom diminui com a base da tela presa no chão do
## telhado, então ela "olha para cima" até a lua entrar no quadro.
##
## A câmera é filha da Cacau: durante a cena ela é solta do corpo dela
## (top_level), senão cada passo da Cacau a arrastaria junto. Volta a seguir a
## Cacau em _devolver_a_camera().
func _abrir_para_o_ceu(duracao: float) -> Tween:
	if _camera == null:
		return null
	var tela := _tamanho_da_tela()
	var base := float(_camera.limit_bottom)
	_limite_de_cima = _camera.limit_top
	_mexeu_no_limite = true
	# O topo desce para caber o céu (volta no fim, com o zoom de volta).
	_camera.limit_top = int(floor(base - tela.y / zoom_do_ceu)) - 2
	var largura := tela.x / zoom_do_ceu
	var meio_dos_dois := beirada_x - AFASTAMENTO * 0.5
	var alvo_x := clampf(meio_dos_dois + largura * FOLGA_PARA_O_CEU,
		float(_camera.limit_left) + largura * 0.5, float(_camera.limit_right) - largura * 0.5)
	var de := _camera.get_screen_center_position()
	var onde := _camera.global_position
	_camera.top_level = true
	_camera.global_position = onde
	_segurando_a_camera = true
	_centro = de
	_centro_do_ceu = Vector2(alvo_x, base - tela.y / zoom_do_ceu * 0.5)
	var tween := create_tween()
	tween.tween_method(_passo_da_camera.bind(de.x, alvo_x, _camera.zoom.x, zoom_do_ceu, base),
		0.0, 1.0, duracao).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


func _passo_da_camera(t: float, de_x: float, ate_x: float, zoom_de: float, zoom_ate: float,
		base: float) -> void:
	var zoom := lerpf(zoom_de, zoom_ate, t)
	_camera.zoom = Vector2(zoom, zoom)
	var altura := _tamanho_da_tela().y / zoom
	_centro = Vector2(lerpf(de_x, ate_x, t), base - altura * 0.5)
	_camera.global_position = _centro


## Leva a câmera (já solta da Cacau) a "centro" com "zoom" em "duracao" s.
func _mover_a_camera(centro: Vector2, zoom: float, duracao: float) -> Tween:
	if _camera == null or not _segurando_a_camera:
		return null
	var de := _centro
	var zoom_de := _camera.zoom.x
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var z := lerpf(zoom_de, zoom, t)
		_camera.zoom = Vector2(z, z)
		_centro = de.lerp(centro, t)
		_camera.global_position = _centro,
		0.0, 1.0, duracao).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


# ───────────────────────────────────────────────────────────── 4. contagem

func _contagem() -> void:
	_preparar_o_foguete()
	# Um respiro olhando o horizonte, com os holofotes acendendo lá longe.
	await _esperar(1.6)
	for numero in ["3...", "2...", "1..."]:
		if not _viva():
			return
		var balao := _balao(numero, _acima_do_chico())
		await _esperar(0.8)
		_fechar_balao(balao)
		await _esperar(0.2)


## O foguete, os holofotes e o clarão: uma camada do BG, atrás do telhado. O
## px dessa camada é o px do mundo contado do canto de cima da tela (no zoom
## do céu), então o caminho sai da composição da tela.
func _preparar_o_foguete() -> void:
	var bg := fase.get_node_or_null("BG") as ParallaxBackground
	if bg == null:
		return
	_foguete = FOGUETE.new()
	bg.add_child(_foguete)
	# Na frente das nuvens, atrás da serra (a base fica escondida pelo telhado).
	var nuvens := bg.get_node_or_null("Nuvens")
	if nuvens:
		bg.move_child(_foguete, nuvens.get_index() + 1)
	var vista := _tamanho_da_tela() / zoom_do_ceu
	var canto := _centro - vista * 0.5
	var horizonte := beirada_do_fundo_y - canto.y
	# Na torre, a ponta fica logo abaixo da beirada: na soltura ele já aparece.
	_foguete.preparar(
		Vector2(vista.x * FOGUETE_X, horizonte + float(FOGUETE.DESENHO.size()) * FOGUETE.PIXEL + 2.0),
		Vector2(vista.x * CURVA.x, vista.y * CURVA.y),
		Vector2(vista.x * CHEGADA.x, vista.y * CHEGADA.y),
		horizonte)


# ───────────────────────────────────────────────────────────── 5. lançamento

func _lancamento() -> void:
	if _foguete == null:
		return
	_foguete.decolar()
	_desde_a_ignicao = 0.0
	_acender_a_luz()
	if musica_entra == Musica.NA_IGNICAO:
		_tocar_a_musica()
	_exclamar()
	await _foguete.sumiu
	if not _viva():
		return
	# Um respiro olhando o rastro antes de falar.
	await _esperar(1.4)


func _process(delta: float) -> void:
	if _desde_a_ignicao < 0.0:
		return
	_desde_a_ignicao += delta
	if is_instance_valid(_luz):
		var forca := _foguete.luz() if is_instance_valid(_foguete) else 0.0
		_luz.energia = LUZ_DO_LANCAMENTO * forca
	var s := _desde_a_ignicao - ATRASO_DO_SOM
	if s < 0.0:
		return
	if not _som_chegou:
		_som_chegou = true
		_o_som_chega()
	# O ronco cresce, segura enquanto o foguete está baixo e vai sumindo.
	var forte := smoothstep(0.0, 0.9, s) * (1.0 - smoothstep(4.0, 11.0, s))
	if is_instance_valid(_ronco):
		_ronco.volume_db = VOLUME_DO_RONCO_DB + linear_to_db(maxf(forte, 0.001))
	var tremor := TREMOR * smoothstep(0.0, 0.4, s) * (1.0 - smoothstep(2.0, 6.0, s))
	if tremor > 0.05 and _camera and _camera.has_method("disparar_tremor"):
		_camera.disparar_tremor(tremor)


func _o_som_chega() -> void:
	var estrondo := AudioStreamPlayer.new()
	estrondo.stream = SOM_DO_ESTRONDO
	estrondo.volume_db = -10.0
	estrondo.pitch_scale = 0.8
	add_child(estrondo)
	estrondo.play()
	estrondo.finished.connect(estrondo.queue_free)
	_ronco = AudioStreamPlayer.new()
	_ronco.stream = SOM_DO_RONCO
	_ronco.volume_db = -60.0
	_ronco.pitch_scale = TOM_DO_RONCO
	add_child(_ronco)
	_ronco.play()


## A luz quente do lançamento, vinda de trás da grade, nos dois e no telhado.
func _acender_a_luz() -> void:
	_luz = LuzPontual.new()
	_luz.name = "LuzDoLancamento"
	_luz.cor = Color(1.0, 0.64, 0.34)
	_luz.raio = 760.0
	_luz.queda = 1.1
	_luz.clarao = 0.0
	_luz.tremor = 0.12
	_luz.energia = 0.0
	var vista := _tamanho_da_tela() / zoom_do_ceu
	var canto := _centro - vista * 0.5
	_luz.position = Vector2(canto.x + vista.x * FOGUETE_X, beirada_do_fundo_y - 10.0)
	fase.add_child(_luz)


## O "!" na cabeça dela, no lugar dos outros emotes (o coração e o "?" do
## foguete da fase 1), e que vai embora com a cena.
func _exclamar() -> void:
	await _balao_de_emote(EMOTE_EXCLAMACAO, "ExclamacaoDoLancamento", 1.6)


## Um balão do pacote de emotes (tira de 3 quadros de 32 px) em cima da Cacau,
## no mesmo lugar e tamanho dos balões dela (o ExclamacaoFoguete), por
## "segundos" e com a entrada e a saída do PopupFX.
func _balao_de_emote(textura: Texture2D, nome: String, segundos: float) -> void:
	var quadros := SpriteFrames.new()
	quadros.set_animation_loop(&"default", true)
	quadros.set_animation_speed(&"default", 3.0)
	for i in 3:
		var quadro := AtlasTexture.new()
		quadro.atlas = textura
		quadro.region = Rect2(32.0 * i, 0.0, 32.0, 32.0)
		quadros.add_frame(&"default", quadro)
	var balao := AnimatedSprite2D.new()
	balao.name = nome
	# Antes de entrar na árvore: a Atmosfera vê que é arte da interface (não
	# escurece com a noite).
	balao.sprite_frames = quadros
	balao.visible = false
	var molde := _cacau.get_node_or_null("ExclamacaoFoguete") as Node2D
	balao.position = molde.position if molde else Vector2(0.0, -80.0)
	balao.scale = molde.scale if molde else Vector2(1.5, 1.5)
	_cacau.add_child(balao)
	PopupFX.mostrar(balao)
	await _esperar(segundos)
	if is_instance_valid(balao):
		await PopupFX.esconder(balao)
	if is_instance_valid(balao):
		balao.queue_free()


# ───────────────────────────────────────────────────────────── 6. "pra Lua"

## Evento "do" da timeline, entre o "Se você passar no teste..." e o "Você
## vai... pra Lua.": a caixa de fala e os retratos somem e, em silêncio, a
## câmera chega devagar nos dois. Só então ele fala.
func suspense() -> void:
	if _cacau == null:
		return
	await _esconder_dialogo()
	var meio := Vector2(beirada_x - AFASTAMENTO * 0.5, _pes_da_cacau() - 45.0)
	var chegando := _mover_a_camera(meio, ZOOM_DO_SUSPENSE, APROXIMACAO_DO_SUSPENSE)
	await _esperar_tween(chegando)
	await _esperar(0.6)
	await _mostrar_dialogo()


## Evento "do" da timeline, logo ANTES do "EU?! PRA LUA?!": de susto, ela
## vira para ele num pulinho e solta o balão "?!"; só depois sai a fala (a
## timeline espera).
func virar_para_ele() -> void:
	if _cacau == null or _virando:
		return
	_virando = true
	if _sprite_cacau:
		_sprite_cacau.flip_h = true
	_balao_de_emote(EMOTE_SUSTO, "SustoDoLancamento", TEMPO_DO_SUSTO)
	await _pulinho(PULINHO_DO_SUSTO, 0.34)
	_virando = false
	# O balão segue no ar mais um instante; a fala sai com ele indo embora.
	await _esperar(maxf(TEMPO_DO_SUSTO - 0.55, 0.0))


## Evento "do" da timeline, logo depois do "EU?! PRA LUA?!": a caixa de fala
## some e ela comemora no telhado — de frente para ele, dá dois pulinhos, o
## coração sobe, e ela volta a olhar o céu.
func comemorar() -> void:
	if _cacau == null:
		return
	# O pulinho do susto ainda no ar: espera ela pousar (os dois mexem no y).
	while _virando and is_inside_tree():
		await _esperar(0.05)
	await _esconder_dialogo()
	if _sprite_cacau:
		_sprite_cacau.flip_h = true
	for i in 2:
		await _pulinho(15.0, 0.36)
	var coracao := _cacau.get_node_or_null("CoracaoFoguete") as AnimatedSprite2D
	if coracao:
		PopupFX.mostrar(coracao)
	await _esperar(0.6)
	if _sprite_cacau:
		_sprite_cacau.flip_h = false
	var resta := 1.8
	while resta > 0.0 and coracao and is_instance_valid(coracao):
		if not coracao.is_playing():
			coracao.play("default")
		await _esperar(0.1)
		resta -= 0.1
	if coracao and is_instance_valid(coracao):
		await PopupFX.esconder(coracao)
	# Ela olha o céu e a câmera volta com ela para a lua.
	var de_volta := _mover_a_camera(_centro_do_ceu, zoom_do_ceu, VOLTA_PARA_O_CEU)
	await _esperar_tween(de_volta)
	await _esperar(0.3)
	await _mostrar_dialogo()


func _pulinho(altura: float, duracao: float) -> void:
	_tocar(_sprite_cacau, &"jump")
	var chao := _cacau.global_position.y
	var pulo := create_tween()
	pulo.tween_property(_cacau, "global_position:y", chao - altura, duracao * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pulo.tween_property(_cacau, "global_position:y", chao, duracao * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await pulo.finished
	_tocar(_sprite_cacau, &"idle")


# Mesmo jeito da revelação no laboratório (cutscene_final_fase.gd): some com
# os retratos e a caixa de fala sem tirar ninguém da conversa.
func _esconder_dialogo() -> void:
	await _esmaecer_retratos(0.0)
	await Dialogic.Text.hide_textbox()


func _mostrar_dialogo() -> void:
	await _esmaecer_retratos(1.0)


func _esmaecer_retratos(alfa: float) -> void:
	var retratos := get_tree().get_nodes_in_group("dialogic_portrait_con_position")
	if retratos.is_empty():
		return
	var fade := create_tween().set_parallel(true)
	for retrato: CanvasItem in retratos:
		fade.tween_property(retrato, "modulate:a", alfa, 0.25)
	await fade.finished


func _restaurar_retratos() -> void:
	if not is_inside_tree():
		return
	for retrato: CanvasItem in get_tree().get_nodes_in_group("dialogic_portrait_con_position"):
		retrato.modulate.a = 1.0


# ───────────────────────────────────────────────────────────── 7. o fim

func _encerrar() -> void:
	if is_instance_valid(_foguete):
		_foguete.dissipar(18.0)
	# Ele volta para a escada; ela fica olhando o céu.
	if _chico and _sprite_chico:
		var pes := _pes_do_chico()
		var volta := _andar(_chico, _sprite_chico, Vector2(porta_x, pes.y), 115.0, true,
			&"andando", &"default", 0.5)
		volta.tween_property(_chico, "modulate:a", 0.0, 0.4)
		volta.tween_callback(_chico.queue_free)

	_devolver_a_camera(1.6)
	_parar_a_musica(2.5)
	await _esperar(0.35)
	if is_instance_valid(_faixas):
		_faixas.sair(1.0)
	await _esperar(1.3)
	if not _viva():
		return
	_devolver_o_limite()
	_mostrar_o_hud()
	_soltar_a_cacau()
	_continuar_a_trilha(3.0)
	Interacao.marcar_tela_aberta(self, false)
	if is_instance_valid(_luz):
		_luz.queue_free()
	_acabou = true
	terminou.emit()
	# Fica viva até ele sumir na escada (o tween dele é desta cena).
	while is_instance_valid(_chico):
		await _esperar(0.25)
	queue_free()


## A câmera volta a ser da Cacau (sem pular de lugar) e desliza de volta ao
## zoom e ao enquadramento de sempre.
func _devolver_a_camera(duracao: float) -> void:
	if not is_instance_valid(_camera) or not _segurando_a_camera:
		return
	_segurando_a_camera = false
	var onde := _camera.global_position
	_camera.top_level = false
	_camera.global_position = onde
	if _camera.has_method("restaurar"):
		_camera.restaurar(duracao)


func _devolver_o_limite() -> void:
	if _mexeu_no_limite and is_instance_valid(_camera):
		_camera.limit_top = _limite_de_cima
	_mexeu_no_limite = false


func _mostrar_o_hud() -> void:
	if not _huds_escondidos:
		return
	_huds_escondidos = false
	if is_instance_valid(_fade):
		_fade.restaurar_huds()
		_fade.queue_free()
	elif is_inside_tree():
		for nome in FadeTela.HUDS_AUTOLOAD:
			var hud := get_tree().root.get_node_or_null(nome)
			if hud is CanvasLayer:
				hud.visible = true


func _travar_a_cacau() -> void:
	_cacau.velocity = Vector2.ZERO
	_cacau.pode_se_mover = false
	# Sem isto o _physics_process dela força o "idle" por cima da corrida (e a
	# gravidade correria escondida por baixo dos tweens).
	_cacau.animacao_controlada_externamente = true
	_tocar(_sprite_cacau, &"idle")


func _soltar_a_cacau() -> void:
	if not is_instance_valid(_cacau):
		return
	if _sprite_cacau:
		_sprite_cacau.speed_scale = 1.0
	_cacau.animacao_controlada_externamente = false
	_cacau.velocity = Vector2.ZERO
	# Ela foi levada para o fundo da faixa: a linha do chão dela vai junto.
	if _cacau.has_method("andar_na_faixa"):
		_cacau.andar_na_faixa(_faixa())
	_cacau.pode_se_mover = true


# Se a cena for embora no meio (voltar ao menu pela pausa), o que é de fora
# dela volta ao normal.
func _exit_tree() -> void:
	_restaurar_retratos()
	if _acabou:
		return
	if _huds_escondidos and is_inside_tree():
		_huds_escondidos = false
		for nome in FadeTela.HUDS_AUTOLOAD:
			var hud := get_tree().root.get_node_or_null(nome)
			if hud is CanvasLayer:
				hud.visible = true
	if _pausou_a_trilha:
		_pausou_a_trilha = false
		TrilhaSonora.continuar(0.5)


# ───────────────────────────────────────────────────────────── música

func _pausar_a_trilha(fade: float) -> void:
	if _pausou_a_trilha:
		return
	_pausou_a_trilha = true
	TrilhaSonora.pausar(fade)


func _continuar_a_trilha(fade: float) -> void:
	if not _pausou_a_trilha:
		return
	_pausou_a_trilha = false
	TrilhaSonora.continuar(fade)


func _tocar_a_musica() -> void:
	_pausar_a_trilha(1.5)
	if musica == null or is_instance_valid(_musica):
		return
	# Uma cópia em loop: a cena pode durar mais que a música.
	var copia := musica.duplicate()
	if "loop" in copia:
		copia.loop = true
	_musica = AudioStreamPlayer.new()
	_musica.name = "MusicaDoLancamento"
	_musica.stream = copia
	_musica.volume_db = -40.0
	_musica.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_musica)
	_musica.play()
	var entra := _musica.create_tween()
	entra.tween_property(_musica, "volume_db", volume_da_musica_db, 1.5)


func _parar_a_musica(fade: float) -> void:
	if not is_instance_valid(_musica):
		return
	var tocador := _musica
	_musica = null
	var sai := tocador.create_tween()
	sai.tween_property(tocador, "volume_db", -60.0, fade)
	sai.tween_callback(tocador.queue_free)


# ───────────────────────────────────────────────────────────── ajudantes

## Roda uma timeline e espera ela acabar. Uma fala que não carregou (arquivo
## renomeado, erro de sintaxe) nunca emite timeline_ended: a rede de segurança
## não deixa a cena travar esperando.
func _conversa(caminho: String) -> void:
	var acabou := [false]
	var ao_acabar := func() -> void: acabou[0] = true
	Dialogic.timeline_ended.connect(ao_acabar, CONNECT_ONE_SHOT)
	Dialogic.start(caminho)
	for i in 3:
		await get_tree().process_frame
	if not acabou[0] and Dialogic.current_timeline == null:
		push_warning("LancamentoNoTelhado: a fala não carregou: %s" % caminho)
		if Dialogic.timeline_ended.is_connected(ao_acabar):
			Dialogic.timeline_ended.disconnect(ao_acabar)
		return
	while not acabou[0] and is_inside_tree():
		await get_tree().process_frame


## Anda (ou corre) com "no" até os pés ficarem em "pes", na animação certa e
## com o passo no ritmo da velocidade. Devolve o tween (para esperar).
func _andar(no: Node2D, sprite: AnimatedSprite2D, pes: Vector2, velocidade: float,
		desenho_olha_esquerda: bool, andando: StringName, parado: StringName,
		atraso: float = 0.0) -> Tween:
	var destino := no.global_position + (pes - _pes_de(no))
	var passo := destino - no.global_position
	var duracao := maxf(passo.length() / velocidade, 0.05)
	var natural := _passo_natural(no)
	var tween := create_tween()
	if atraso > 0.0:
		tween.tween_interval(atraso)
	tween.tween_callback(func() -> void:
		if sprite == null:
			return
		if absf(passo.x) > 0.5:
			var para_a_direita := passo.x > 0.0
			sprite.flip_h = para_a_direita if desenho_olha_esquerda else not para_a_direita
		sprite.speed_scale = clampf(velocidade / natural, 0.5, 2.6)
		_tocar(sprite, andando))
	tween.tween_property(no, "global_position", destino, duracao)
	tween.tween_callback(func() -> void:
		if sprite == null:
			return
		sprite.speed_scale = 1.0
		_tocar(sprite, parado))
	return tween


func _passo_natural(no: Node2D) -> float:
	if no == _cacau:
		return PASSO_DA_CACAU
	return PASSO_DO_CIENTISTA * absf(no.scale.x) / ESCALA_DO_CIENTISTA


func _esperar_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid() and tween.is_running():
		await tween.finished


## Espera "segundos" do jogo (para junto com a pausa).
func _esperar(segundos: float) -> void:
	if not is_inside_tree():
		return
	await create_tween().tween_interval(segundos).finished


func _viva() -> bool:
	return is_inside_tree() and is_instance_valid(_cacau)


func _tocar(sprite: AnimatedSprite2D, animacao: StringName) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(animacao):
		sprite.play(animacao)


func _faixa() -> Rect2:
	var faixa := fase.get_node_or_null("FaixaDoChao") as Control
	if faixa:
		return faixa.get_global_rect()
	return Rect2(0.0, beirada_do_fundo_y + 13.0, 1408.0, 49.0)


func _pes_da_cacau() -> float:
	return _cacau.altura_dos_pes() if _cacau.has_method("altura_dos_pes") else _cacau.global_position.y


func _pes_do_chico() -> Vector2:
	return _chico.global_position + Vector2(0.0, PES_DO_CIENTISTA * absf(_chico.scale.y))


func _pes_de(no: Node2D) -> Vector2:
	if no == _cacau:
		return Vector2(_cacau.global_position.x, _pes_da_cacau())
	return _pes_do_chico()


func _por_os_pes(no: Node2D, pes: Vector2) -> void:
	no.global_position += pes - _pes_de(no)


func _tamanho_da_tela() -> Vector2:
	return fase.get_viewport().get_visible_rect().size


## O pedaço do mundo que está na tela agora.
func _retangulo_visivel() -> Rect2:
	var tela := _tamanho_da_tela()
	if _camera == null:
		return Rect2(Vector2.ZERO, tela)
	var vista := tela / _camera.zoom
	return Rect2(_camera.get_screen_center_position() - vista * 0.5, vista)


## A ponta do rabinho do balão do Dr. Chico: acima da cabeça dele.
func _acima_do_chico() -> Vector2:
	var pes := _pes_do_chico()
	return Vector2(pes.x + 4.0, pes.y - 100.0)


## Um balão de fala no mundo (o do "ESPERA AÍ!!!" do laboratório), com a ponta
## do rabinho em "ponta".
func _balao(texto: String, ponta: Vector2) -> Node2D:
	var balao := CENA_DO_BALAO.instantiate() as Node2D
	balao.scale = Vector2(ESCALA_DO_BALAO, ESCALA_DO_BALAO)
	balao.z_index = 20
	fase.add_child(balao)
	var margem := balao.get_node_or_null("MarginContainer") as Control
	var dentro := balao.get_node_or_null("MarginContainer/MarginContainer") as Control
	var rotulo := balao.get_node_or_null("MarginContainer/MarginContainer/Label") as Label
	if dentro:
		dentro.add_theme_constant_override("margin_left", 22)
		dentro.add_theme_constant_override("margin_right", 14)
	if rotulo:
		rotulo.add_theme_font_size_override("font_size", 22)
		rotulo.text = texto
	var tamanho := Vector2(195.0, 76.0)
	if margem:
		# Do tamanho do texto (o mínimo do desenho do balão vale por baixo).
		margem.size = Vector2.ZERO
		tamanho = margem.get_combined_minimum_size()
		margem.size = tamanho
	balao.global_position = ponta - Vector2(PONTA_DO_BALAO.x, tamanho.y) * ESCALA_DO_BALAO
	if balao.has_method("mostrar"):
		balao.mostrar(texto)
	return balao


func _fechar_balao(balao: Node2D) -> void:
	if not is_instance_valid(balao):
		return
	if balao.has_method("esconder"):
		balao.esconder()
	# Apagado um instante depois: o som da digitação dele espera um timer e
	# precisa achá-lo vivo para parar sozinho.
	get_tree().create_timer(0.3, false).timeout.connect(balao.queue_free)
