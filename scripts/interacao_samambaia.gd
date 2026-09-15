extends Area2D

const TIMELINE = "samambaia"

var player_perto  : bool = false
var dialogo_ativo : bool = false
var player_ref    : Node = null

@onready var balao      = $interactballon2
@onready var icone_e    = $"tecla E"
@onready var icone_x    = $"tecla X"
@onready var label_local = $Label

func _ready() -> void:
	_mostrar_indicador(false)

func _mostrar_indicador(mostrar: bool) -> void:
	if mostrar:
		PopupFX.mostrar(balao)
	else:
		PopupFX.esconder(balao)
	icone_e.visible    = mostrar
	icone_x.visible    = mostrar
	label_local.visible = mostrar

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

func _process(_delta: float) -> void:
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
