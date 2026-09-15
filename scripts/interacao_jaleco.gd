extends Area2D

const TIMELINE = "jaleco"

var player_perto  : bool = false
var dialogo_ativo : bool = false
var player_ref    : Node = null

@onready var balao = $interactballon

func _ready() -> void:
	balao.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body is CharacterBody2D:
		player_perto = true
		player_ref = body
		PopupFX.mostrar(balao)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player" or body is CharacterBody2D:
		player_perto = false
		player_ref = null
		PopupFX.esconder(balao)

func _process(_delta: float) -> void:
	if player_perto and not dialogo_ativo and Interacao.pediu():
		_iniciar_dialogo()

func _iniciar_dialogo() -> void:
	dialogo_ativo = true
	if player_ref:
		player_ref.pode_se_mover = false
	PopupFX.esconder(balao)
	Dialogic.timeline_ended.connect(_on_dialogo_terminou, CONNECT_ONE_SHOT)
	Dialogic.start(TIMELINE)

func _on_dialogo_terminou() -> void:
	dialogo_ativo = false
	if player_ref:
		player_ref.pode_se_mover = true
	if player_perto:
		PopupFX.mostrar(balao)
