@tool
class_name PisoEletrificado
extends Area2D

# --- PISO / CORREDOR ELETRIFICADO ---
#
# O obstáculo que só as botas vulcanizadas atravessam: borracha é isolante —
# o mesmo enxofre da vulcanização vira proteção.
#
# COMO EDITAR NO EDITOR:
#   Sprite   -> PNG do piso (o placeholder listrado some sozinho)
#   tamanho  -> redimensiona colisão e placeholder

const CENA := "res://scenes/fases/componentes/piso_eletrificado.tscn"

@export var tamanho: Vector2 = Vector2(300, 24):
	set(valor):
		tamanho = valor
		if is_inside_tree():
			_aplicar_tamanho()
@export var dano: int = 1

var _jogador: Node2D = null
var _cooldown: float = 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _placeholder: ColorRect = $Placeholder
@onready var _listras: Node2D = $Placeholder/Listras
@onready var _colisao: CollisionShape2D = $Colisao


static func criar(pai: Node, nome: String, centro: Vector2, config: Dictionary = {}) -> PisoEletrificado:
	var piso: PisoEletrificado = load(CENA).instantiate()
	piso.name = nome
	piso.position = centro
	for chave in config:
		piso.set(chave, config[chave])
	Blockout.adicionar(pai, piso)
	return piso


func _ready() -> void:
	_aplicar_tamanho()
	Blockout.aplicar_arte(_sprite, _placeholder)
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _aplicar_tamanho() -> void:
	if _colisao and _colisao.shape is RectangleShape2D:
		(_colisao.shape as RectangleShape2D).size = tamanho
	if _placeholder:
		_placeholder.size = tamanho
		_placeholder.position = -tamanho / 2.0
	if _listras:
		for filho in _listras.get_children():
			filho.free()
		var passo := 40.0
		for i in int(tamanho.x / passo):
			var listra := ColorRect.new()
			listra.color = Color(0.95, 0.9, 0.2)
			listra.size = Vector2(18, maxf(tamanho.y - 6, 4))
			listra.position = Vector2(20 + i * passo, 3)
			listra.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_listras.add_child(listra)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_cooldown -= delta

	# Cintilação elétrica: a fechadura visível de longe.
	var pulso := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.02 + position.x)
	if _listras:
		_listras.modulate.a = pulso
	if _sprite.texture:
		_sprite.modulate.a = pulso

	if _jogador == null or _cooldown > 0.0:
		return
	if Progresso.tem_habilidade("botas"):
		return
	if _jogador.has_method("take_damage"):
		_jogador.take_damage(dano, Vector2(0.4 if randf() > 0.5 else -0.4, 0))
		_cooldown = 0.9


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_jogador = body
		if Progresso.tem_habilidade("botas"):
			Blockout.aviso_flutuante(get_parent(), body.global_position,
				"As botas vulcanizadas isolam a corrente.", Color(0.6, 0.95, 0.7))


func _on_body_exited(body: Node2D) -> void:
	if body == _jogador:
		_jogador = null
