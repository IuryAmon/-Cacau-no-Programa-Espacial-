extends CharacterBody2D

# Nave do simulador de voo (shoot'em up).
#
# Dois tiros diferentes, e isso é a graça do treinamento do Dr. Chico:
#   ESPAÇO -> tiro azul  (OH⁻, base)  neutraliza as moléculas ácidas (HCl)
#   ENTER  -> tiro verde (H⁺, ácido)  neutraliza as moléculas básicas (NaOH)
# Trocar o tiro errado não faz nada: ácido só é neutralizado por base e
# vice-versa.

signal vida_mudou(vida: int, vida_maxima: int)
signal pontuacao_mudou(pontos: int)
signal morreu

@export var speed: float = 600.0
@export var acceleration: float = 8.0
@export var friction: float = 10.0

@export var tiro_azul: PackedScene
@export var tiro_verde: PackedScene
@export var cadencia: float = 0.2

@export var vida_maxima: int = 100
@export var knockback_forca: float = 2000.0
## Margem (px) que a nave respeita nas bordas da tela.
@export var margem_tela: float = 24.0

var vida: int = 100
var pontos: int = 0
## Enquanto false a nave não responde a nada (usado no fim da rodada).
var ativa: bool = true

var _pode_atirar: bool = true
var _morta: bool = false

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _som_tiro: AudioStreamPlayer = $SomTiro


func _ready() -> void:
	vida = vida_maxima
	vida_mudou.emit(vida, vida_maxima)
	pontuacao_mudou.emit(pontos)


func _physics_process(delta: float) -> void:
	if _morta or not ativa:
		velocity = velocity.lerp(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	# O analógico lido como círculo (ver "O ANALÓGICO NO MUNDO" em controle.gd):
	# a nave vai no ângulo exato do polegar. Pela força de cada eixo, a zona
	# morta de 0,5 por eixo entortava a direção — a 30° ela ia reta na
	# horizontal. Teclado e direcional continuam nas 8 direções.
	var direcao := Controle.vetor_direcional().normalized()

	if direcao != Vector2.ZERO:
		velocity = velocity.lerp(direcao * speed, acceleration * delta)
		if _anim.animation != "moving":
			_anim.play("moving")
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction * delta)
		if _anim.animation != "default":
			_anim.play("default")

	move_and_slide()

	var tela := get_viewport_rect().size
	position.x = clampf(position.x, margem_tela, tela.x - margem_tela)
	position.y = clampf(position.y, margem_tela, tela.y - margem_tela)

	if Input.is_action_pressed("shoot"):
		_tentar_atirar(tiro_azul)
	elif Input.is_action_pressed("shoot_special"):
		_tentar_atirar(tiro_verde)


func _tentar_atirar(cena: PackedScene) -> void:
	if not _pode_atirar or _morta or cena == null:
		return

	var tiro := cena.instantiate()
	tiro.position = position + Vector2(0, -20)
	get_parent().add_child(tiro)

	if _som_tiro:
		_som_tiro.stop()
		_som_tiro.play()

	_pode_atirar = false
	await get_tree().create_timer(cadencia).timeout
	_pode_atirar = true


func take_damage(quantidade: int, origem = null) -> void:
	if _morta or not ativa:
		return

	vida = clampi(vida - quantidade, 0, vida_maxima)
	vida_mudou.emit(vida, vida_maxima)

	if origem != null:
		velocity += (global_position - origem).normalized() * knockback_forca

	if vida <= 0:
		_morrer()


func add_score(valor: int) -> void:
	if _morta:
		return
	pontos += valor
	pontuacao_mudou.emit(pontos)


## Congela a nave no fim da rodada (vitória, derrota ou saída pelo menu).
func desligar() -> void:
	ativa = false
	velocity = Vector2.ZERO


func _morrer() -> void:
	if _morta:
		return
	_morta = true
	velocity = Vector2.ZERO
	morreu.emit()
