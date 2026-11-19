class_name CompressorDeAr
extends Area2D

# --- O COMPRESSOR DE AR (a máquina da sala do compressor, fase 2) ---
#
# A máquina do mapa. Chegando perto, o botão (E, ou □ de controle) acende em
# cima dela e ela ganha o contorno branco (o mesmo jeito da coluna de
# destilação e da cesta de maçãs). O que o E faz depende de onde a Cacau está
# no caminho do nitrogênio (MissaoNitrogenio):
#
#   SEM CILINDRO    a câmera aproxima da máquina, como nas conversas com o
#                   Dr. Chico, e a Cacau comenta: dá para pôr um cilindro ali
#                   ("fala_sem_cilindro"). É a fechadura à vista antes da
#                   chave: o cilindro está no telhado da torre.
#   COM O CILINDRO  (o vazio, na mochila) ela anda até o berço, o cilindro
#                   voa da mão dela e encaixa com um estalo, e o puzzle abre.
#                   Da segunda vez em diante ele já está preso: o E abre
#                   direto.
#   PRONTO          a amostra já saiu: ela comenta ("fala_concluido").
#
# O PUZZLE NASCE NA PRÓPRIA MÁQUINA: a Cacau sai da frente dela (para a
# esquerda), o jogo para, a câmera chega perto (ZoomNoObjeto, zoom 4) e a tela
# do puzzle (scenes/puzzle_compressor.tscn) se abre em cima da arte — uma
# linha de luz desce trocando o aço pelo raio X da câmara, que é a mesma
# máquina, pixel por pixel (ArteDoCompressor). Fechando, a linha sobe, a arte
# volta e a câmera volta para a Cacau.
#
# A tela recebe a MÁQUINA guardada no MissaoNitrogenio: fechar no meio (ESC) e
# voltar depois encontra o êmbolo e o resfriador onde estavam — e a arte do
# mapa mostra isso: o cabo e a placa do êmbolo descem com ele (a câmara fica
# aberta em cima), as garras abrem quando o cilindro é solto, o cilindro gela
# com o ar frio. Na primeira vez, o Dr. Chico explica a máquina pelo rádio
# ("fala_de_abertura").
#
#   amostra pronta  a tela se fecha, a Cacau pega o cilindro de ar líquido e
#                   começa a corrida (MissaoNitrogenio.comecar_amostra);
#   estourou        fim de jogo (TelaGameOver). Tentar de novo monta a máquina
#                   do começo e a tela continua aberta.
#
# COMO EDITAR NO EDITOR:
#   posição do nó     -> no CHÃO, no meio da máquina: a arte cresce para cima
#   Sprite            -> a estrutura (a base, as pernas, o armário do
#                        resfriador e os canos), que fica à vista com o puzzle
#                        aberto. Desenha em z_index 1, atrás da Cacau
#   Sprite/Contorno   -> a linha em volta da máquina inteira; a cor é o
#                        "modulate" dele
#   CilindroAcoplado  -> o cilindro preso no berço (aparece quando acoplado)
#   Cabo              -> o cabo do êmbolo com a haste
#   Aparelho          -> a câmara de aço, a válvula, o berço, as garras e o
#                        manômetro
#   Dica              -> o botão E/□
#   Colisao           -> a área em que o botão aparece e o E funciona
# As artes estão em assets/fase nitrogenio/compressor/ e saem de
# tools/gerar_arte_do_compressor.tscn; onde fica cada peça (o cilindro, o
# cabo) vem do ArteDoCompressor, não da cena — é o que o raio X usa.

const TELA := preload("res://scenes/puzzle_compressor.tscn")
const CAMADA_DA_TELA := 98
const TEMPO_DE_ACENDER := 0.12
const CONTORNO_ALFA_MIN := 0.55
const TEMPO_DO_PULSO := 1.0
## O zoom da câmera com o puzzle aberto: 4 deixa cada pixel da arte (escala 2)
## com 8 px na tela, o tamanho do desenho da câmara.
const ZOOM_DO_PUZZLE := 4.0
## A Cacau sai de baixo da máquina (para a esquerda) antes do zoom: a metade da
## largura dela, a folga e a pressa.
const MEIA_LARGURA_DA_CACAU := 22.0
const FOLGA_DA_CACAU := 8.0
const VELOCIDADE_DE_RECUAR := 260.0

## A Cacau, sem cilindro: "dá para pôr um cilindro aqui".
@export var fala_sem_cilindro: String = "cacau_compressor_sem_cilindro"
## A Cacau, com a amostra já pronta.
@export var fala_concluido: String = "cacau_compressor_concluido"
## O Dr. Chico explicando a máquina, na primeira vez que a tela abre.
@export var fala_de_abertura: String = "cientista_compressor"
## O zoom da câmera na fala sem cilindro (o das conversas do world1).
@export var zoom_da_fala: float = 2.2

## A tela do puzzle abriu / fechou (fechou: a câmera já voltou para a Cacau).
signal tela_abriu
signal tela_fechou

var _jogador: Node2D = null
var _ocupado: bool = false
var _dica_visivel: bool = false
var _brilho_do_contorno: float = 0.0
var _fase_do_pulso: float = 0.0
var _tela: TelaDoCompressor = null
## A Cacau saindo da frente / a câmera indo ou voltando do puzzle.
var _abrindo: bool = false
var _zoom: ZoomNoObjeto = null
## A arte do aparelho como veio do arquivo (a do mapa muda com a máquina) e o
## que a arte mostra agora (para só refazer quando a máquina muda).
var _base_do_aparelho: Image = null
var _como_esta_a_arte: String = ""

@onready var _sprite: Sprite2D = $Sprite
@onready var _contorno: Sprite2D = get_node_or_null("Sprite/Contorno")
@onready var _cilindro: Sprite2D = get_node_or_null("CilindroAcoplado")
@onready var _cabo: Sprite2D = get_node_or_null("Cabo")
@onready var _aparelho: Sprite2D = get_node_or_null("Aparelho")
@onready var _dica: AnimatedSprite2D = get_node_or_null("Dica")
@onready var _som_engate: AudioStreamPlayer2D = get_node_or_null("SomEngate")


func _ready() -> void:
	if _dica:
		_dica.visible = false
	if _aparelho and _aparelho.texture:
		_base_do_aparelho = _imagem(_aparelho.texture)
	if _cilindro:
		_cilindro.position = _lugar_do_cilindro()
	body_entered.connect(_ao_entrar)
	body_exited.connect(_ao_sair)
	_atualizar_a_arte(true)


func _process(delta: float) -> void:
	var perto := _jogador != null and not _ocupado and not puzzle_em_curso()
	if perto != _dica_visivel:
		_dica_visivel = perto
		_atualizar_dica()
	_animar_contorno(delta)
	_atualizar_a_arte()
	# pediu() por último: ele queima o toque.
	if perto and Interacao.pediu():
		usar()


## O que o E faz (ver o topo).
func usar() -> void:
	if _ocupado or puzzle_em_curso():
		return
	if MissaoNitrogenio.compressor_concluido():
		_falar(fala_concluido, false)
	elif MissaoNitrogenio.cilindro_acoplado:
		abrir_tela()
	elif MissaoNitrogenio.tem_cilindro_vazio():
		_acoplar_e_abrir()
	else:
		_falar(fala_sem_cilindro, true)


## A tela do puzzle está aberta?
func tela_aberta() -> bool:
	return _tela != null and is_instance_valid(_tela)


func tela() -> TelaDoCompressor:
	return _tela if tela_aberta() else null


## O puzzle está aberto, ou a Cacau está saindo da frente, ou a câmera ainda
## está indo ou voltando dele.
func puzzle_em_curso() -> bool:
	return _abrindo or tela_aberta() or _zoom != null


# ─────────────────────────────────────────────────────────────
# A FALA (com a câmera chegando perto)
# ─────────────────────────────────────────────────────────────

func _falar(timeline: String, aproximar: bool) -> void:
	if timeline.is_empty():
		return
	_ocupado = true
	_olhar_para_a_maquina()
	var camera := _camera()
	if aproximar and camera and camera.has_method("aproximar"):
		# O foco é o meio da máquina (o nó Foco), não o pé dela.
		var foco := get_node_or_null("Foco") as Node2D
		camera.aproximar(foco if foco else self, zoom_da_fala)
	if DialogicBridge.falar(timeline):
		await Dialogic.timeline_ended
	if camera and is_instance_valid(camera) and aproximar and camera.has_method("restaurar"):
		camera.restaurar()
	_ocupado = false


func _camera() -> Camera2D:
	var cacau := _cacau()
	return cacau.get_node_or_null("Camera2D") as Camera2D if cacau else null


func _cacau() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D


func _olhar_para_a_maquina() -> void:
	var cacau := _cacau()
	var sprite := cacau.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D if cacau else null
	if sprite and not is_equal_approx(cacau.global_position.x, global_position.x):
		sprite.flip_h = global_position.x < cacau.global_position.x


# ─────────────────────────────────────────────────────────────
# ACOPLAR O CILINDRO
# ─────────────────────────────────────────────────────────────

func _acoplar_e_abrir() -> void:
	_ocupado = true
	var cacau := _cacau()
	# Ela vai até a frente do berço.
	if cacau and cacau.has_method("recuar_ate_x") and _cilindro:
		var lado := signf(cacau.global_position.x - _cilindro.global_position.x)
		if lado == 0.0:
			lado = -1.0
		await cacau.recuar_ate_x(_cilindro.global_position.x + lado * 46.0)
	_olhar_para_a_maquina()
	MissaoNitrogenio.acoplar_cilindro()
	# O cilindro voa da mão dela até o berço e encaixa.
	if _cilindro and cacau:
		var destino := _lugar_do_cilindro()
		_cilindro.visible = true
		_cilindro.global_position = cacau.global_position + Vector2(0, -36)
		_cilindro.rotation = deg_to_rad(-30.0)
		var voo := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		voo.set_parallel(true)
		voo.tween_property(_cilindro, "position", destino + Vector2(0, -18), 0.32)
		voo.tween_property(_cilindro, "rotation", 0.0, 0.32)
		await voo.finished
		var encaixe := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		encaixe.tween_property(_cilindro, "position", destino, 0.14)
		await encaixe.finished
	if _som_engate and _som_engate.stream:
		_som_engate.play()
	var camera := _camera()
	if camera and camera.has_method("disparar_tremor"):
		camera.disparar_tremor(3.0)
	await get_tree().create_timer(0.35).timeout
	_ocupado = false
	_atualizar_a_arte(true)
	abrir_tela()


## Onde o cilindro fica preso (o meio dele, px do nó): o berço da arte.
func _lugar_do_cilindro() -> Vector2:
	var A := ArteDoCompressor
	var tamanho := Vector2(15, 39)
	if _cilindro and _cilindro.texture:
		tamanho = _cilindro.texture.get_size()
	return A.CANTO_NO_MAPA + (Vector2(A.CILINDRO) + tamanho * 0.5) * A.ESCALA_NO_MAPA


# ─────────────────────────────────────────────────────────────
# A ARTE DO MAPA SEGUE A MÁQUINA
# ─────────────────────────────────────────────────────────────

## O cabo e a placa do êmbolo onde ele está, as garras abertas com o cilindro
## solto, o cilindro (preso ou não, gelado com o ar frio) e o contorno em volta
## de tudo. Só refaz quando algo disso muda ("forcar" refaz de qualquer jeito).
func _atualizar_a_arte(forcar: bool = false) -> void:
	if _ocupado and not forcar:
		return
	var maquina := MissaoNitrogenio.maquina()
	var A := ArteDoCompressor
	var descida := A.descida_do_embolo(maquina.posicao)
	var garras_abertas := not maquina.valvula_aberta
	var acoplado := MissaoNitrogenio.cilindro_acoplado
	var gelado := maquina.gas.celsius() < A.CILINDRO_GELA_ABAIXO_DE
	var como := "%d %s %s %s" % [descida, garras_abertas, acoplado, gelado]
	if como == _como_esta_a_arte and not forcar:
		return
	_como_esta_a_arte = como
	if _aparelho and _base_do_aparelho:
		_aparelho.texture = ImageTexture.create_from_image(A.aparelho_no_mapa(_base_do_aparelho, maquina.posicao, garras_abertas))
	if _cabo:
		_cabo.position = A.CANTO_NO_MAPA + Vector2(A.canto_do_cabo(maquina.posicao)) * A.ESCALA_NO_MAPA
	if _cilindro:
		# (Com o puzzle aberto o mundo está parado e isto não roda: quem esconde
		# e mostra a máquina então é _mostrar_a_maquina.)
		_cilindro.visible = acoplado
		_cilindro.texture = MissaoNitrogenio.TEXTURA_AMOSTRA if gelado else MissaoNitrogenio.TEXTURA_CILINDRO_VAZIO
	if _contorno:
		_contorno.texture = _textura_do_contorno(_silhueta())


## A máquina inteira numa imagem só, do tamanho da arte (para o contorno): as
## camadas onde estão (o cilindro só se estiver preso).
func _silhueta() -> Image:
	var A := ArteDoCompressor
	var imagem := Image.create_empty(A.TAMANHO.x, A.TAMANHO.y, false, Image.FORMAT_RGBA8)
	for camada: Sprite2D in [_sprite, _cilindro, _cabo, _aparelho]:
		if camada == null or camada.texture == null:
			continue
		if camada == _cilindro and not MissaoNitrogenio.cilindro_acoplado:
			continue
		var pedaco := _imagem(camada.texture)
		# Onde a camada está (px do nó) -> px da arte (todas na escala da arte).
		var no_no := camada.transform * camada.get_rect()
		var canto := Vector2i(((no_no.position - A.CANTO_NO_MAPA) / A.ESCALA_NO_MAPA).round())
		imagem.blend_rect(pedaco, Rect2i(Vector2i.ZERO, pedaco.get_size()), canto)
	return imagem


func _imagem(textura: Texture2D) -> Image:
	var imagem := textura.get_image()
	if imagem.is_compressed():
		imagem.decompress()
	imagem.convert(Image.FORMAT_RGBA8)
	return imagem


# ─────────────────────────────────────────────────────────────
# O PUZZLE, EM CIMA DA MÁQUINA
# ─────────────────────────────────────────────────────────────

## A Cacau sai da frente da máquina, o jogo para, a câmera chega perto e a
## tela do puzzle nasce em cima da arte.
func abrir_tela() -> void:
	if puzzle_em_curso():
		return
	_abrindo = true
	_dica_visivel = false
	_atualizar_dica()
	await _abrir_espaco_para_o_puzzle()
	_parar_o_jogo(true)
	# O contorno some já (o jogo parado não o apagaria).
	_brilho_do_contorno = 0.0
	_animar_contorno(0.0)
	_olhar_para_a_maquina()
	_atualizar_a_arte(true)
	var recorte := recorte_no_mundo()
	_zoom = ZoomNoObjeto.chegar_perto(self, recorte, ZOOM_DO_PUZZLE)
	_abrindo = false
	await _zoom.chegou

	var camada := CanvasLayer.new()
	camada.name = "TelaDoCompressor"
	camada.layer = CAMADA_DA_TELA
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	_tela = TELA.instantiate() as TelaDoCompressor
	_tela.modo_historia = true
	_tela.maquina = MissaoNitrogenio.maquina()
	_tela.aparelho_no_mundo = _zoom.na_tela(recorte)
	if not MissaoNitrogenio.explicou_o_compressor:
		_tela.fala_de_abertura = fala_de_abertura
		MissaoNitrogenio.explicou_o_compressor = true
	_tela.amostra_fechada.connect(_ao_fechar_a_amostra)
	_tela.cilindro_estourou.connect(_ao_estourar)
	_tela.fechou.connect(_ao_fechar_a_tela)
	# O raio X cobriu a máquina: a arte dela some (senão apareceria nas frestas
	# do desenho); saindo, ela volta — como a máquina ficou — antes de o raio X
	# começar a subir. A estrutura (a base, as pernas, o armário) fica.
	_tela.revelada.connect(_mostrar_a_maquina.bind(false))
	_tela.escondendo.connect(_mostrar_a_maquina.bind(true))
	camada.add_child(_tela)
	get_tree().current_scene.add_child(camada)
	tela_abriu.emit()


## Onde a arte da máquina está no mundo (px do mundo).
func recorte_no_mundo() -> Rect2:
	return _sprite.get_global_transform() * _sprite.get_rect()


## Se a Cacau está na frente da máquina (ou à direita dela, onde fica o
## termômetro do resfriador), ela anda até sair dela pela esquerda, para o
## raio X e os painéis não ficarem em cima dela.
func _abrir_espaco_para_o_puzzle() -> void:
	var cacau := _cacau()
	if cacau == null or not cacau.has_method("recuar_ate_x"):
		return
	var livre := recorte_no_mundo().position.x - MEIA_LARGURA_DA_CACAU - FOLGA_DA_CACAU
	if cacau.global_position.x <= livre:
		return
	await cacau.recuar_ate_x(livre, VELOCIDADE_DE_RECUAR)


func _mostrar_a_maquina(mostrar: bool) -> void:
	if mostrar:
		_atualizar_a_arte(true)
	for camada: Sprite2D in [_cabo, _aparelho]:
		if camada:
			camada.visible = mostrar
	if _cilindro:
		_cilindro.visible = mostrar and MissaoNitrogenio.cilindro_acoplado


func _ao_fechar_a_tela() -> void:
	_tela = null
	await _voltar_a_camera()
	_parar_o_jogo(false)
	tela_fechou.emit()


func _ao_fechar_a_amostra(amostra: GasFechado, _segundos: float) -> void:
	_tela = null
	await _voltar_a_camera()
	_parar_o_jogo(false)
	MissaoNitrogenio.comecar_amostra(amostra, get_tree().current_scene)
	_atualizar_a_arte(true)
	tela_fechou.emit()


## A câmera do puzzle volta para a Cacau.
func _voltar_a_camera() -> void:
	_mostrar_a_maquina(true)
	var zoom := _zoom
	if zoom and is_instance_valid(zoom):
		zoom.voltar()
		await zoom.voltou
	_zoom = null


func _ao_estourar(como: Dictionary) -> void:
	var tela_aberta_agora := _tela
	var motivo := "aquecimento" if float(como.get("resfriador", 25.0)) > 30.0 \
		and float(como.get("temperatura", 25.0)) > 30.0 else "compressao"
	var dados := {"motivo": motivo, "pressao": float(como.get("pressao", MaquinaDeCompressao.PRESSAO_DE_RUPTURA)),
		"temperatura": float(como.get("temperatura", 25.0))}
	TelaGameOver.mostrar(get_tree(), dados, func() -> void:
		# Tentar de novo: a máquina do começo, a tela continua aberta (e o
		# mundo continua parado atrás dela).
		MissaoNitrogenio.maquina().reiniciar()
		if is_instance_valid(tela_aberta_agora):
			tela_aberta_agora.recomecar()
		get_tree().paused = true)


func _parar_o_jogo(parar: bool) -> void:
	get_tree().paused = parar
	var cacau := _cacau()
	if cacau and "pode_se_mover" in cacau:
		cacau.pode_se_mover = not parar
		if parar:
			cacau.velocity = Vector2.ZERO


# ─────────────────────────────────────────────────────────────
# O BOTÃO E O CONTORNO (como na coluna de destilação)
# ─────────────────────────────────────────────────────────────

func _atualizar_dica() -> void:
	if _dica == null:
		return
	_dica.visible = _dica_visivel
	if _dica_visivel and _dica.has_method("reiniciar"):
		_dica.reiniciar()


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
	_contorno.self_modulate.a = _brilho_do_contorno * lerpf(CONTORNO_ALFA_MIN, 1.0, pulso)


## A textura do contorno: branca, 1 texel em volta da silhueta da máquina —
## dos lados e por cima. Embaixo não: a máquina está assentada no chão.
func _textura_do_contorno(arte: Image) -> Texture2D:
	var largura := arte.get_width() + 2
	var altura := arte.get_height() + 2
	var linha := Image.create_empty(largura, altura, false, Image.FORMAT_RGBA8)
	for y in altura - 1:
		for x in largura:
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
