class_name Destilador
extends Area2D

# --- A COLUNA DE DESTILAÇÃO (fase do nitrogênio) ---
#
# A torre de aço do mapa. Chegando perto, o desenho do botão acende na frente
# dela (a tecla E, ou o □ de controle: componentes/icone_interagir.tscn, o
# mesmo da cesta de maçãs) e a coluna ganha um contorno branco que pulsa de
# leve. Apertando, o jogo para e o Dr. Chico explica, pelo rádio, como ela
# separa o ar: a coluna "sai" do mapa, vem para o meio da tela, vira o desenho
# de raio X e mostra as moléculas trabalhando lá dentro. Toda essa tela é
# scenes/explicacao_destilador.tscn (scripts/explicacao_destilador.gd).
#
# Dá para ver quantas vezes quiser: cada E recomeça a explicação do zero. A
# primeira vez fica anotada no EstadoMundo (ja_explicou), para o dia em que a
# fase quiser cobrar isso antes de liberar os puzzles.
#
# A AMOSTRA (o fim do caminho do nitrogênio, ver MissaoNitrogenio): quando a
# Cacau chega correndo com o cilindro de ar líquido do compressor, o E não
# explica — RECEBE a amostra. Ela vai até a coluna, o cilindro sai das costas
# dela e encaixa na base, o relógio da amostra para ("CONECTADA!") e abre o
# puzzle em que ela mesma destila o ar (scenes/puzzle_destilacao.tscn, campo
# "tela_da_destilacao"). Fechar no meio deixa a amostra na coluna: o E volta
# para o puzzle. Separado o ar e retirado o nitrogênio, sai o sinal
# "nitrogenio_pronto" (o cilindro verde aparece na sala).
#
# DEPOIS DO NITROGÊNIO a coluna fica quieta: nem botão, nem contorno, e o E não
# abre mais nada (nem o puzzle, nem a explicação). O cilindro verde salta bem
# ao lado dela, e o E perto dele tem de ser só dele (ver interativa()).
#
# O PUZZLE NASCE NA PRÓPRIA COLUNA: o jogo para, a câmera chega perto
# (ZoomNoObjeto) até a coluna do mapa ficar do tamanho exato da do puzzle
# (ZOOM_DA_DESTILACAO) e a tela do puzzle abre por cima dela, sem fundo: uma
# linha de luz desce trocando a arte de aço pelo raio X. Fechando, a linha
# sobe, a coluna de aço reaparece e a câmera volta para a Cacau.
#
# A ARTE é "assets/fase nitrogenio/coluna de destilação.png", que tem dois
# desenhos lado a lado: o de aço (o que se vê aqui, pelo region_rect do
# Sprite) e o de raio X (o da explicação e do puzzle).
#
# COMO EDITAR NO EDITOR:
#   posição do nó -> no CHÃO, no meio da coluna: a arte cresce para cima dele
#   Sprite        -> a arte de aço. Desenha em z_index 1: atrás da Cacau
#                    (z_index 2), na frente do cenário
#   Sprite/Contorno -> a linha em volta; a cor é o "modulate" dele (a textura
#                    só existe com o jogo rodando)
#   Dica          -> o botão E/□
#   Colisao       -> a área em que o botão aparece e o E funciona. Tem de
#                    passar dos lados do Corpo, senão encostada nele a Cacau
#                    fica fora dela
#   Corpo/Forma   -> a parede: a silhueta da arte de aço, cúpula incluída
#                    (a Cacau não atravessa a coluna e pode pousar em cima)
#   explicacao    -> a cena da tela que o E abre

const CENA := "res://scenes/fases/componentes/destilador.tscn"

## Quanto o contorno leva para acender (e para apagar quando ela se afasta).
const TEMPO_DE_ACENDER := 0.12
## Aceso, ele respira entre esta opacidade e a cheia, uma vez a cada
## TEMPO_DO_PULSO segundos.
const CONTORNO_ALFA_MIN := 0.55
const TEMPO_DO_PULSO := 1.0

## A tela da explicação que o E abre.
@export var explicacao: PackedScene

@export_group("A amostra (fase do nitrogênio)")
## A tela em que a pessoa destila a amostra que trouxe do compressor.
@export var tela_da_destilacao: PackedScene = preload("res://scenes/puzzle_destilacao.tscn")
## O Dr. Chico na primeira vez que essa tela abre.
@export var fala_da_destilacao: String = "cientista_destilacao"

## A explicação abriu / acabou de fechar.
signal explicacao_abriu
signal explicacao_fechou
## A amostra entrou na coluna (o relógio dela parou).
signal amostra_recebida
## A coluna separou o ar e o nitrogênio foi retirado.
signal nitrogenio_pronto

const CAMADA_DA_DESTILACAO := 98
## O zoom da câmera com o puzzle aberto: 2 deixa a coluna do mapa (arte em
## escala 2) do tamanho exato da do puzzle (4 px da tela por pixel da arte).
const ZOOM_DA_DESTILACAO := 2.0
## Onde fica o alto da coluna na tela com o puzzle aberto (px), se os limites
## da câmera deixarem.
const ALTO_DA_COLUNA_NA_TELA := 96.0
## Meia largura da Cacau (px do mundo), e a pressa dela ao sair da frente do
## puzzle.
const MEIA_LARGURA_DA_CACAU := 22.0
const VELOCIDADE_DE_RECUAR := 260.0

var _recebendo: bool = false
## A Cacau está saindo da frente para o puzzle abrir.
var _abrindo: bool = false
var _destilacao: TelaDaDestilacao = null
## A câmera do puzzle (do começo da chegada até ela voltar para a Cacau).
var _zoom: ZoomNoObjeto = null

var _jogador: Node2D = null
var _tela: ExplicacaoDestilador = null
# Estado do botão, para o ícone só ser religado na virada.
var _dica_visivel: bool = false
# Contorno: 0 = apagado, 1 = aceso; e o relógio do pulso.
var _brilho_do_contorno: float = 0.0
var _fase_do_pulso: float = 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _contorno: Sprite2D = get_node_or_null("Sprite/Contorno")
@onready var _dica: AnimatedSprite2D = get_node_or_null("Dica")


func _ready() -> void:
	if _dica:
		_dica.visible = false
	if _contorno:
		_contorno.texture = _textura_do_contorno()
	body_entered.connect(_ao_entrar)
	body_exited.connect(_ao_sair)
	# A tela já fica montada (escondida) desde a chegada na fase: montada só
	# no primeiro E, o jogo engasgava bem na hora de a coluna sair do mapa.
	_montar_a_tela.call_deferred()


func _process(delta: float) -> void:
	var perto := _jogador != null and interativa() and not explicando() and not _recebendo \
		and not destilando()
	if perto != _dica_visivel:
		_dica_visivel = perto
		_atualizar_dica()
	_animar_contorno(delta)

	# pediu() por último: ele queima o toque, e só pode queimar quando a
	# coluna vai mesmo responder.
	if perto and Interacao.pediu():
		usar()


## O que o E faz. Na fase do nitrogênio a coluna também recebe a amostra de
## ar líquido (ver MissaoNitrogenio): carregando a amostra, a Cacau a entrega
## e a tela da destilação abre; com a amostra já dentro, o E volta para essa
## tela. Fora disso, é a explicação do Dr. Chico.
func usar() -> void:
	if not interativa():
		return
	if MissaoNitrogenio.carregando_amostra():
		receber_amostra()
	elif MissaoNitrogenio.amostra_na_coluna:
		abrir_destilacao()
	else:
		explicar()


## A coluna ainda responde ao E? Só até o nitrogênio ser separado: depois
## disso (com o cilindro verde esperando ao lado dela, ou já levado) ela não
## abre mais o puzzle nem a explicação.
func interativa() -> bool:
	return not MissaoNitrogenio.nitrogenio_destilado and not Progresso.conquistou_celula("N")


## O puzzle está aberto (ou a Cacau está saindo da frente, ou a câmera ainda
## está indo ou voltando dele).
func destilando() -> bool:
	return _abrindo or (_destilacao != null and is_instance_valid(_destilacao)) or _zoom != null


## A Cacau entrega a amostra: ela vai até a coluna, o cilindro sai das costas
## dela e encaixa na base, o relógio para e a tela da destilação abre.
func receber_amostra() -> void:
	if _recebendo or not MissaoNitrogenio.carregando_amostra():
		return
	_recebendo = true
	var cacau := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if cacau and cacau.has_method("recuar_ate_x"):
		var lado := signf(cacau.global_position.x - global_position.x)
		if lado == 0.0:
			lado = -1.0
		await cacau.recuar_ate_x(global_position.x + lado * 70.0)
	_olhar_para_a_coluna()
	if cacau and "pode_se_mover" in cacau:
		cacau.pode_se_mover = false
	# O cilindro das costas voa até a entrada da coluna (a base).
	var contagem := get_tree().current_scene.get_node_or_null(ContagemDaAmostra.NOME) as ContagemDaAmostra
	var cilindro: Sprite2D = contagem.tirar_cilindro_das_costas() if contagem else null
	MissaoNitrogenio.entregar_amostra_na_coluna()
	amostra_recebida.emit()
	if cilindro and is_instance_valid(cilindro):
		var onde := cilindro.global_position
		cilindro.get_parent().remove_child(cilindro)
		add_child(cilindro)
		cilindro.global_position = onde
		cilindro.z_index = 2
		var destino := Vector2(0.0, -24.0)
		var voo := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		voo.set_parallel(true)
		voo.tween_property(cilindro, "position", destino, 0.45)
		voo.tween_property(cilindro, "rotation", 0.0, 0.45)
		voo.tween_property(cilindro, "scale", Vector2(1.0, 1.0), 0.45)
		await voo.finished
		var some := create_tween()
		some.tween_property(cilindro, "modulate:a", 0.0, 0.3)
		await some.finished
		cilindro.queue_free()
	if cacau and "pode_se_mover" in cacau:
		cacau.pode_se_mover = true
	_recebendo = false
	abrir_destilacao()


## O puzzle em que a pessoa separa o ar (com a amostra dentro da coluna): a
## Cacau dá uns passos para trás, o jogo para, a câmera chega perto da coluna
## e o puzzle nasce em cima dela.
func abrir_destilacao() -> void:
	if destilando() or tela_da_destilacao == null:
		return
	_abrindo = true
	_dica_visivel = false
	_atualizar_dica()
	await _abrir_espaco_para_o_puzzle()
	_parar_a_cacau(true)
	# O contorno some já (o jogo parado não o apagaria).
	_brilho_do_contorno = 0.0
	_animar_contorno(0.0)
	_olhar_para_a_coluna()
	var recorte := recorte_no_mundo()
	var meia_altura := get_viewport().get_visible_rect().size.y * 0.5 / ZOOM_DA_DESTILACAO
	var centro := Vector2(recorte.get_center().x,
		recorte.position.y - ALTO_DA_COLUNA_NA_TELA / ZOOM_DA_DESTILACAO + meia_altura)
	_zoom = ZoomNoObjeto.chegar_perto(self, recorte, ZOOM_DA_DESTILACAO, centro)
	_abrindo = false
	await _zoom.chegou

	var camada := CanvasLayer.new()
	camada.name = "TelaDaDestilacao"
	camada.layer = CAMADA_DA_DESTILACAO
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	_destilacao = tela_da_destilacao.instantiate() as TelaDaDestilacao
	_destilacao.coluna_no_mundo = _zoom.na_tela(recorte)
	if not MissaoNitrogenio.explicou_a_destilacao:
		_destilacao.fala_de_abertura = fala_da_destilacao
		MissaoNitrogenio.explicou_a_destilacao = true
	_destilacao.nitrogenio_retirado.connect(_ao_retirar_o_nitrogenio)
	_destilacao.fechou.connect(_ao_fechar_a_destilacao)
	# O raio X cobriu a coluna de aço: ela some (senão apareceria nas frestas
	# do desenho); saindo, ela volta antes de o raio X começar a subir.
	_destilacao.revelada.connect(func() -> void: _sprite.visible = false)
	_destilacao.escondendo.connect(func() -> void: _sprite.visible = true)
	camada.add_child(_destilacao)
	get_tree().current_scene.add_child(camada)


## Onde a arte de aço está no mundo (px do mundo).
func recorte_no_mundo() -> Rect2:
	return _sprite.get_global_transform() * _sprite.get_rect()


## Se a Cacau está onde o puzzle vai desenhar (a régua e os nomes à esquerda
## da coluna, o termômetro e as setas à direita), ela recua até sair de baixo
## disso, do lado em que já está, e fica de frente para a coluna.
func _abrir_espaco_para_o_puzzle() -> void:
	var cacau := get_tree().get_first_node_in_group("player") as Node2D
	if cacau == null or not cacau.has_method("recuar_ate_x"):
		return
	var recorte := recorte_no_mundo()
	var livre: float
	if cacau.global_position.x <= recorte.get_center().x:
		livre = recorte.position.x - TelaDaDestilacao.LARGURA_DA_REGUA_E_NOMES / ZOOM_DA_DESTILACAO \
			- MEIA_LARGURA_DA_CACAU
		if cacau.global_position.x <= livre:
			return
	else:
		livre = recorte.end.x + TelaDaDestilacao.ALCANCE_A_DIREITA / ZOOM_DA_DESTILACAO + MEIA_LARGURA_DA_CACAU
		if cacau.global_position.x >= livre:
			return
	await cacau.recuar_ate_x(livre, VELOCIDADE_DE_RECUAR)


## A tela do puzzle aberta agora (nula fora dele).
func tela_da_destilacao_aberta() -> TelaDaDestilacao:
	return _destilacao if _destilacao != null and is_instance_valid(_destilacao) else null


func _ao_fechar_a_destilacao() -> void:
	_destilacao = null
	await _voltar_a_camera()
	_parar_a_cacau(false)


func _ao_retirar_o_nitrogenio() -> void:
	# A pureza que a comemoração do puzzle mostrou: é a que a Cacau vai dizer
	# quando pegar o cilindro (cacau_tem_nitrogenio).
	var pureza := _destilacao.pureza_retirada() if is_instance_valid(_destilacao) else 0.0
	_destilacao = null
	await _voltar_a_camera()
	_parar_a_cacau(false)
	MissaoNitrogenio.concluir_destilacao(pureza)
	nitrogenio_pronto.emit()


## A câmera do puzzle volta para a Cacau.
func _voltar_a_camera() -> void:
	_sprite.visible = true
	var zoom := _zoom
	if zoom and is_instance_valid(zoom):
		zoom.voltar()
		await zoom.voltou
	_zoom = null


func _parar_a_cacau(parar: bool) -> void:
	get_tree().paused = parar
	var cacau := get_tree().get_first_node_in_group("player")
	if cacau and "pode_se_mover" in cacau:
		cacau.pode_se_mover = not parar


## Abre a explicação do Dr. Chico (o que o E faz).
func explicar() -> void:
	if explicando():
		return
	_montar_a_tela()
	if _tela == null:
		push_warning("%s: falta a cena da explicação (campo 'explicacao')." % name)
		return
	_olhar_para_a_coluna()
	# A tela para o jogo, e este nó para junto: o botão e o contorno têm de
	# sumir já, senão ficariam acesos por baixo dela.
	_dica_visivel = false
	_atualizar_dica()
	_brilho_do_contorno = 0.0
	_animar_contorno(0.0)
	# O desenho da tela nasce exatamente em cima da coluna do mapa e a leva
	# embora: a de cá some enquanto a explicação está aberta.
	var na_tela := retangulo_na_tela()
	_sprite.visible = false
	_tela.abrir(na_tela)
	explicacao_abriu.emit()


func _montar_a_tela() -> void:
	if _tela != null or explicacao == null:
		return
	_tela = explicacao.instantiate() as ExplicacaoDestilador
	add_child(_tela)
	_tela.pousou.connect(_ao_pousar)
	_tela.fechou.connect(_ao_fechar)


## True enquanto a explicação está na tela.
func explicando() -> bool:
	return _tela != null and _tela.esta_aberta()


## True depois que a explicação foi vista até fechar, pelo menos uma vez.
func ja_explicou() -> bool:
	return EstadoMundo.ja_feito(self)


## A tela da explicação (montada na chegada à fase, escondida até o E).
func tela() -> ExplicacaoDestilador:
	return _tela


## Onde a arte de aço aparece na tela agora, em px da tela do jogo.
func retangulo_na_tela() -> Rect2:
	return _sprite.get_global_transform_with_canvas() * _sprite.get_rect()


## O desenho da tela voltou para cima da coluna: ela reaparece no lugar.
func _ao_pousar() -> void:
	_sprite.visible = true


func _ao_fechar() -> void:
	_sprite.visible = true
	EstadoMundo.marcar_feito(self)
	explicacao_fechou.emit()


func _olhar_para_a_coluna() -> void:
	var cacau := get_tree().get_first_node_in_group("player") as Node2D
	var sprite_dela := cacau.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D if cacau else null
	if sprite_dela and not is_equal_approx(cacau.global_position.x, global_position.x):
		sprite_dela.flip_h = global_position.x < cacau.global_position.x


## O botão só é prometido quando ela está por perto.
func _atualizar_dica() -> void:
	if _dica == null:
		return
	_dica.visible = _dica_visivel
	if _dica_visivel and _dica.has_method("reiniciar"):
		_dica.reiniciar()


## O contorno segue o botão: acende quando ela entra na área, respira enquanto
## ela fica e apaga quando ela sai.
func _animar_contorno(delta: float) -> void:
	if _contorno == null:
		return
	var alvo := 1.0 if _dica_visivel else 0.0
	_brilho_do_contorno = move_toward(_brilho_do_contorno, alvo, delta / TEMPO_DE_ACENDER)
	_contorno.visible = _brilho_do_contorno > 0.0
	if not _contorno.visible:
		_fase_do_pulso = 0.0
		return
	_fase_do_pulso += delta
	var pulso := 0.5 + 0.5 * cos(TAU * _fase_do_pulso / TEMPO_DO_PULSO)
	# self_modulate, e não modulate: a cor escolhida no Inspector fica intacta.
	_contorno.self_modulate.a = _brilho_do_contorno * lerpf(CONTORNO_ALFA_MIN, 1.0, pulso)


## A textura do contorno: branca, com 1 texel aceso em volta da silhueta da
## coluna (o mesmo jeito da cesta de maçãs). Ela é 1 texel maior que a arte
## para cada lado, porque a linha mora onde a arte é transparente.
func _textura_do_contorno() -> Texture2D:
	var folha := _sprite.texture.get_image()
	if folha.is_compressed():
		folha.decompress()
	var arte := folha.get_region(Rect2i(_sprite.region_rect))
	var largura := arte.get_width() + 2
	var altura := arte.get_height() + 2
	var linha := Image.create_empty(largura, altura, false, Image.FORMAT_RGBA8)
	for y in altura:
		for x in largura:
			# (x, y) da linha é o texel (x - 1, y - 1) da arte.
			if _opaco(arte, x - 1, y - 1):
				continue
			if _opaco(arte, x - 2, y - 1) or _opaco(arte, x, y - 1) \
					or _opaco(arte, x - 1, y - 2) or _opaco(arte, x - 1, y):
				linha.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(linha)


func _opaco(imagem: Image, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= imagem.get_width() or y >= imagem.get_height():
		return false
	return imagem.get_pixel(x, y).a > 0.5


func _ao_entrar(corpo: Node2D) -> void:
	if corpo.is_in_group("player"):
		_jogador = corpo


func _ao_sair(corpo: Node2D) -> void:
	if corpo == _jogador:
		_jogador = null
