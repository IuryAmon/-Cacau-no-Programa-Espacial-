@tool
class_name CorrenteVapor
extends Area2D

# --- CORRENTE DE VAPOR (Torre de Gases) ---
#
# Um trecho da torre onde o vapor empurra a personagem. Andar contra o fluxo
# (350 px/s) até avança, mas devagar; o dash da mochila (1050 px/s) cruza com
# folga. O ventilador (um AlvoBumerangue) desliga a corrente.
#
# COMO EDITAR NO EDITOR:
#   tamanho  -> redimensiona colisão, faixa visual e emissor das partículas
#   direcao  -> +1 empurra para a direita, -1 para a esquerda
#   empuxo   -> força em px/s (a Cacau anda a 350)
#   Vapor    -> partículas; troque cor/textura pela sua arte

const CENA := "res://scenes/fases/componentes/corrente_vapor.tscn"

@export var tamanho: Vector2 = Vector2(400, 200):
	set(valor):
		tamanho = valor
		if is_inside_tree():
			_aplicar_tamanho()
@export var empuxo: float = 280.0:
	set(valor):
		empuxo = valor
		if is_inside_tree():
			_aplicar_tamanho()
## +1 empurra para a direita, -1 para a esquerda.
@export_enum("Direita:1", "Esquerda:-1") var direcao: int = 1:
	set(valor):
		direcao = valor
		if is_inside_tree():
			_aplicar_tamanho()

var ativa: bool = true
var _jogador: Node2D = null

@onready var _colisao: CollisionShape2D = $Colisao
@onready var _faixa: ColorRect = $Faixa
@onready var _vapor: CPUParticles2D = $Vapor


static func criar(pai: Node, nome: String, centro: Vector2, config: Dictionary = {}) -> CorrenteVapor:
	var corrente: CorrenteVapor = load(CENA).instantiate()
	corrente.name = nome
	corrente.position = centro
	for chave in config:
		corrente.set(chave, config[chave])
	Blockout.adicionar(pai, corrente)
	return corrente


func _ready() -> void:
	_aplicar_tamanho()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _aplicar_tamanho() -> void:
	if _colisao and _colisao.shape is RectangleShape2D:
		(_colisao.shape as RectangleShape2D).size = tamanho
	if _faixa:
		_faixa.size = tamanho
		_faixa.position = -tamanho / 2.0
	if _vapor:
		_vapor.lifetime = maxf(tamanho.x / maxf(empuxo, 1.0), 0.1)
		_vapor.direction = Vector2(direcao, 0)
		_vapor.initial_velocity_min = empuxo * 0.8
		_vapor.initial_velocity_max = empuxo * 1.1
		_vapor.position = Vector2(-direcao * tamanho.x / 2.0, 0)
		_vapor.emission_rect_extents = Vector2(8, tamanho.y / 2.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# O empurrão vai direto na posição: o player reescreve velocity.x pelo
	# input a cada frame, então mexer na posição é estável.
	if ativa and _jogador:
		_jogador.global_position.x += direcao * empuxo * delta


func desligar() -> void:
	ativa = false
	_faixa.color.a = 0.04
	_vapor.emitting = false
	set_physics_process(false)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_jogador = body


func _on_body_exited(body: Node2D) -> void:
	if body == _jogador:
		_jogador = null
