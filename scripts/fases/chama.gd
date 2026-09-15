@tool
class_name Chama
extends Area2D

# --- CHAMA (Torre de Gases) ---
#
# Fogo em cima das plataformas da subida. Machuca ao encostar; o jato de N₂
# do dash da mochila apaga — inertização como verbo de jogo.
#
# COMO EDITAR NO EDITOR:
#   Sprite (AnimatedSprite2D) -> anime o fogo aqui; sem frames, valem as
#                               partículas do nó Fogo
#   Fogo / Fumaca             -> partículas de fogo e do sopro ao apagar

const CENA := "res://scenes/fases/componentes/chama.tscn"

@export var dano: int = 1
@export var intervalo_dano: float = 0.9

var _jogador_dentro: Node2D = null
var _cooldown_dano: float = 0.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _fogo: CPUParticles2D = $Fogo
@onready var _fumaca: CPUParticles2D = $Fumaca


static func criar(pai: Node, nome: String, pos_base: Vector2, config: Dictionary = {}) -> Chama:
	var chama: Chama = load(CENA).instantiate()
	chama.name = nome
	chama.position = pos_base
	for chave in config:
		chama.set(chave, config[chave])
	Blockout.adicionar(pai, chama)
	return chama


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	add_to_group("chama")
	if EstadoMundo.ja_feito(self):
		queue_free()
		return

	if _sprite.sprite_frames and _sprite.sprite_frames.get_animation_names().size() > 0:
		_sprite.play()
	else:
		_sprite.hide()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_cooldown_dano -= delta
	if _jogador_dentro and _cooldown_dano <= 0.0 and _jogador_dentro.has_method("take_damage"):
		var direcao := Vector2(-1.0 if _jogador_dentro.global_position.x < global_position.x else 1.0, 0)
		_jogador_dentro.take_damage(dano, direcao)
		_cooldown_dano = intervalo_dano


## Chamada pelo jato de N₂ do dash: a chama sufoca sem o comburente.
func apagar() -> void:
	EstadoMundo.marcar_feito(self)
	set_physics_process(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	_fogo.emitting = false
	_sprite.hide()
	_fumaca.emitting = true

	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_callback(queue_free)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_jogador_dentro = body


func _on_body_exited(body: Node2D) -> void:
	if body == _jogador_dentro:
		_jogador_dentro = null
