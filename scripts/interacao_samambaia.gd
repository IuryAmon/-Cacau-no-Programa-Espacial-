extends Area2D

# A samambaia do world1 e a frase "Pressione E ou □ para interagir" em cima
# dela. Com a Cacau dentro da área (CollisionShape2D), o balão salta e a
# frase surge num fade in; saindo, ou abrindo a conversa, ela some num fade
# out — o mesmo jeito das outras frases do world1 (AparecerPerto).

const TIMELINE = "samambaia"

## Duração do fade in e do fade out da frase (segundos).
@export var duracao_do_fade: float = AparecerPerto.DURACAO

var player_perto  : bool = false
var dialogo_ativo : bool = false
var player_ref    : Node = null

@onready var balao      = $interactballon2
@onready var icone_e    = $"tecla E"
@onready var icone_x    = $"tecla X"
@onready var label_local = $Label

var _frase_a_vista := false
var _alfa := 0.0

func _ready() -> void:
	_mostrar_indicador(false)
	_aplicar_alfa()

func _mostrar_indicador(mostrar: bool) -> void:
	if mostrar:
		PopupFX.mostrar(balao)
	else:
		PopupFX.esconder(balao)
	_frase_a_vista = mostrar

## As três partes da frase com o mesmo alfa (escondidas de vez quando apagadas).
func _aplicar_alfa() -> void:
	for parte in [icone_e, icone_x, label_local]:
		parte.modulate.a = _alfa
		parte.visible = _alfa > 0.0

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body is CharacterBody2D:
		player_perto = true
		player_ref = body
		_mostrar_indicador(true)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player" or body is CharacterBody2D:
		player_perto = false
		player_ref = null
		_mostrar_indicador(false)

func _process(delta: float) -> void:
	var antes := _alfa
	_alfa = AparecerPerto.alfa(_alfa, _frase_a_vista, delta, duracao_do_fade)
	if _alfa != antes:
		_aplicar_alfa()
	if player_perto and not dialogo_ativo and Interacao.pediu():
		_iniciar_dialogo()

func _iniciar_dialogo() -> void:
	dialogo_ativo = true
	if player_ref:
		player_ref.pode_se_mover = false
	_mostrar_indicador(false)
	Dialogic.timeline_ended.connect(_on_dialogo_terminou, CONNECT_ONE_SHOT)
	Dialogic.start(TIMELINE)

func _on_dialogo_terminou() -> void:
	dialogo_ativo = false
	if player_ref:
		player_ref.pode_se_mover = true
	if player_perto:
		_mostrar_indicador(true)
