extends Area2D

# Porta de entrada do simulador de voo, no world3.
#
# O jogador chega perto da escotilha do foguete pousado -> balão de exclamação
# (o mesmo efeito das gaiolas do world1). Se apertar E:
#   1. o player trava e a tela escurece devagar;
#   2. o Dr. Chico fala pelo rádio que vai ligar o simulador;
#   3. troca para a cena do simulador, que já nasce escura e clareia com o
#      shoot'em up rodando.
#
# Este mesmo script também cuida da VOLTA: quando o jogador sai do simulador,
# a cena do world3 é recarregada, e aqui ele é reposicionado exatamente onde
# estava e a tela clareia de novo.

## Timeline do Dialogic da primeira vez (briefing completo).
const TIMELINE_PRIMEIRA_VEZ := "simulador_ligar"
## Timeline curta das vezes seguintes.
const TIMELINE_DE_NOVO := "simulador_ligar_de_novo"

@export var duracao_escurecer: float = 1.6
@export var duracao_clarear: float = 1.2
## Tempo (s) em que o E é ignorado logo depois de voltar do simulador, para
## ele não reentrar sem querer com a tecla ainda afundada.
@export var carencia_ao_voltar: float = 0.8

var _player: Node2D = null
var _player_dentro: bool = false
var _ocupada: bool = false
# True quando apertou E no ar: assim que encostar no chão, a sequência começa.
var _pedido_pendente: bool = false
var _bloqueado_ate: float = 0.0

@onready var _exclamacao: AnimatedSprite2D = $ExclamacaoAnimada


func _ready() -> void:
	_exclamacao.visible = false
	_exclamacao.stop()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Voltando do simulador: ela reaparece exatamente onde entrou no foguete e
	# a tela clareia. Chegando do laboratório quem cuida disso é a porta
	# (PortaSimulador com "recebe_chegada"), que faz a animação de saída.
	if SimuladorEstado.voltando:
		_reposicionar_apos_simulador()
		FadeTela.clarear_na_chegada(_raiz_da_cena(), duracao_clarear)


# --- VOLTA DO SIMULADOR ---
func _reposicionar_apos_simulador() -> void:
	SimuladorEstado.voltando = false
	_bloqueado_ate = _agora() + carencia_ao_voltar

	var player := _achar_player()
	if player and SimuladorEstado.posicao_de_retorno != Vector2.ZERO:
		player.global_position = SimuladorEstado.posicao_de_retorno
		if "velocity" in player:
			player.velocity = Vector2.ZERO
		# A câmera é filha do player e tem amortecimento ligado: sem zerar ele,
		# a cena clareia com a câmera ainda vindo de onde o player estava no
		# arquivo da cena, fazendo aquele ajuste rápido no começo.
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera:
			camera.reset_smoothing()
			camera.force_update_scroll()


# --- DETECÇÃO ---
func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player = body
	_player_dentro = true
	if not _ocupada:
		PopupFX.mostrar(_exclamacao)


func _on_body_exited(body: Node2D) -> void:
	if body != _player:
		return
	_player_dentro = false
	_pedido_pendente = false
	PopupFX.esconder(_exclamacao)


func _process(_delta: float) -> void:
	if _ocupada or not _player_dentro or _player == null:
		return
	if _agora() < _bloqueado_ate:
		return

	if Interacao.pediu():
		if _player.has_method("is_on_floor") and not _player.is_on_floor():
			_pedido_pendente = true
		else:
			_entrar_no_simulador()
		return

	# Apertou no ar: espera pisar no chão para não travar a animação de pulo.
	if _pedido_pendente and (not _player.has_method("is_on_floor") or _player.is_on_floor()):
		_pedido_pendente = false
		_entrar_no_simulador()


# --- SEQUÊNCIA DE ENTRADA ---
func _entrar_no_simulador() -> void:
	if _ocupada:
		return
	_ocupada = true
	_pedido_pendente = false

	PopupFX.esconder(_exclamacao)

	if "pode_se_mover" in _player:
		_player.pode_se_mover = false
	if "velocity" in _player:
		_player.velocity = Vector2.ZERO
	var sprite: AnimatedSprite2D = _player.get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.play("idle")

	# Guarda de onde ele saiu ANTES da tela apagar.
	SimuladorEstado.registrar_entrada(
		get_tree().current_scene.scene_file_path,
		_player.global_position
	)

	var raiz := _raiz_da_cena()
	var fade := FadeTela.criar(raiz, false)
	await fade.escurecer(duracao_escurecer)
	fade.esconder_huds(raiz)

	# Nesta altura da história o cientista já se revelou; garante o nome certo
	# mesmo se a fase for aberta direto no editor, sem passar pelo world1.
	Dialogic.VAR.set_variable("reveal_name", "Dr. Chico")

	var timeline := TIMELINE_DE_NOVO if SimuladorEstado.ja_jogou else TIMELINE_PRIMEIRA_VEZ
	Dialogic.timeline_ended.connect(_on_briefing_terminou, CONNECT_ONE_SHOT)
	Dialogic.start(timeline)


func _on_briefing_terminou() -> void:
	SimuladorEstado.ja_jogou = true
	get_tree().change_scene_to_file(SimuladorEstado.CENA_SIMULADOR)


# --- AUXILIARES ---
func _achar_player() -> Node2D:
	var encontrado := get_tree().get_first_node_in_group("player")
	if encontrado == null:
		encontrado = get_tree().current_scene.get_node_or_null("Player")
	return encontrado as Node2D


func _raiz_da_cena() -> Node:
	return get_tree().current_scene


func _agora() -> float:
	return Time.get_ticks_msec() / 1000.0
