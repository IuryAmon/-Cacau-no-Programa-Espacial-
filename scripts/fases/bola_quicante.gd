class_name BolaQuicante
extends CharacterBody2D

# --- BOLA QUICANTE ---
#
# Cai, bate numa rampa e desce por ela aos pulinhos, todos do mesmo tamanho
# (como as bolas que descem as rampas no Cuphead): cada quique ignora a
# velocidade que ela trazia e relança com o mesmo impulso, para o lado em que
# a rampa desce. No PRIMEIRO quique em chão reto depois de ter passado por uma
# rampa, ela se despedaça. Machuca a personagem no contato.
#
# Não costuma ser colocada à mão: o GeradorBolas (gerador_bolas.gd) solta uma
# de tempos em tempos e preenche os ajustes abaixo antes de soltar.
#
# O QUE CONTA COMO RAMPA
#   A normal da superfície atingida. Até INCLINACAO_PLANA graus é chão reto;
#   mais que isso é rampa; quase em pé já é parede (ela ricocheteia). As
#   rampas do tileset têm ~26,6° (sobem 1 tile a cada 2).
#
# ESTRUTURA
#   BolaQuicante (CharacterBody2D sem camada: só enxerga o cenário e atravessa
#   │             a personagem e as caixas empurráveis)
#   ├─ Colisao
#   ├─ Hitbox (Area2D que fere a personagem)
#   └─ Visual (o achatamento do quique mexe aqui)
#      └─ Giro (rola conforme anda)
#         ├─ Sprite       arraste a arte aqui: o placeholder some sozinho
#         └─ Placeholder

signal quicou(ponto: Vector2, normal: Vector2)
signal quebrou(ponto: Vector2)

## Até quantos graus de inclinação a superfície ainda conta como chão reto.
const INCLINACAO_PLANA := 12.0
## Normal com y acima disto (superfície quase em pé) é parede ou teto.
const NORMAL_Y_PAREDE := -0.35
## Quem está nestes grupos é atravessado em vez de servir de chão.
const GRUPOS_ATRAVESSAVEIS: Array[StringName] = [&"player", &"empurravel"]

## Velocidade para o lado em cada pulinho.
@export_range(0.0, 1500.0, 5.0, "suffix:px/s") var velocidade_horizontal: float = 260.0
## Impulso para cima em cada quique: é o que define a altura dos pulinhos.
@export_range(50.0, 2000.0, 10.0, "suffix:px/s") var forca_quique: float = 600.0
@export_range(100.0, 6000.0, 10.0, "suffix:px/s²") var gravidade: float = 1800.0
@export_range(100.0, 4000.0, 10.0, "suffix:px/s") var velocidade_max_queda: float = 1400.0
## Para que lado ela pula se o primeiro quique for em chão reto.
@export_enum("Esquerda:-1", "Direita:1") var direcao_inicial: int = -1
@export var dano: int = 1
## Tremor da câmera quando ela se despedaça (0 = nenhum).
@export_range(0.0, 20.0, 0.1) var tremor_ao_quebrar: float = 3.0
## Segurança: se ela se perder (cair num buraco, prender num canto), some
## sozinha depois deste tempo.
@export_range(1.0, 60.0, 0.5, "suffix:s") var tempo_de_vida: float = 15.0

@export_group("Sons")
## Vazios por enquanto: a bola ainda não tem som.
@export var som_quique: AudioStream
@export var som_quebra: AudioStream

var _direcao := -1.0
var _passou_por_rampa := false
var _quebrada := false
var _vida := 0.0
var _raio := 20.0
var _tween_visual: Tween

@onready var _visual: Node2D = $Visual
@onready var _giro: Node2D = $Visual/Giro
@onready var _placeholder: Polygon2D = $Visual/Giro/Placeholder


func _ready() -> void:
	_direcao = float(direcao_inicial)
	Blockout.aplicar_arte($Visual/Giro/Sprite, _placeholder)
	var forma := $Colisao.shape as CircleShape2D
	if forma:
		_raio = forma.radius

	for grupo in GRUPOS_ATRAVESSAVEIS:
		for corpo in get_tree().get_nodes_in_group(grupo):
			if corpo is PhysicsBody2D:
				add_collision_exception_with(corpo)
	$Hitbox.body_entered.connect(_ao_tocar_corpo)

	# Nasce crescendo: sai do buraco em vez de surgir do nada.
	_visual.scale = Vector2(0.2, 0.2)
	_tween_visual = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_visual.tween_property(_visual, "scale", Vector2.ONE, 0.2)


func _physics_process(delta: float) -> void:
	_vida += delta
	if _vida >= tempo_de_vida:
		_quebrar(global_position)
		return

	velocity.y = minf(velocity.y + gravidade * delta, velocidade_max_queda)
	var colisao := move_and_collide(velocity * delta)
	_giro.rotation += velocity.x * delta / _raio
	if colisao:
		_ao_bater(colisao)


func _ao_bater(colisao: KinematicCollision2D) -> void:
	var normal := colisao.get_normal()
	if normal.y > NORMAL_Y_PAREDE:
		# Parede ou teto: ricocheteia perdendo força, sem contar como quique.
		velocity = velocity.bounce(normal) * 0.6
		if absf(velocity.x) > 1.0:
			_direcao = signf(velocity.x)
		return

	var plano := absf(rad_to_deg(Vector2.UP.angle_to(normal))) <= INCLINACAO_PLANA
	if plano and _passou_por_rampa:
		_quebrar(colisao.get_position())
		return
	if not plano:
		_passou_por_rampa = true
		_direcao = signf(normal.x)  # a normal aponta para o lado em que a rampa desce

	velocity = Vector2(_direcao * velocidade_horizontal, -forca_quique)
	_achatar(normal)
	_tocar_solto(som_quique, -16.0, colisao.get_position())
	quicou.emit(colisao.get_position(), normal)


## Achata a bola no eixo da batida e deixa ela voltar com um balanço.
func _achatar(normal: Vector2) -> void:
	if _tween_visual and _tween_visual.is_valid():
		_tween_visual.kill()
	# O Visual gira para achatar na direção da normal; o Giro desconta a mesma
	# volta para a bola não trocar de ângulo de repente.
	var angulo := normal.angle() + PI * 0.5
	_giro.rotation -= angulo - _visual.rotation
	_visual.rotation = angulo
	_visual.scale = Vector2(1.3, 0.7)
	_tween_visual = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween_visual.tween_property(_visual, "scale", Vector2.ONE, 0.35)


func _ao_tocar_corpo(corpo: Node2D) -> void:
	if _quebrada or not corpo.is_in_group("player") or not corpo.has_method("take_damage"):
		return
	var lado := signf(corpo.global_position.x - global_position.x)
	if lado == 0.0:
		lado = _direcao
	corpo.take_damage(dano, Vector2(lado, 0))


func _quebrar(ponto: Vector2) -> void:
	if _quebrada:
		return
	_quebrada = true
	set_physics_process(false)
	_soltar_estilhacos(ponto)
	_tocar_solto(som_quebra, -6.0, ponto)
	if tremor_ao_quebrar > 0.0:
		var camera := get_viewport().get_camera_2d()
		if camera and camera.has_method("disparar_tremor"):
			camera.disparar_tremor(tremor_ao_quebrar)
	quebrou.emit(ponto)
	queue_free()


## Os pedaços ficam no pai: a bola já some no mesmo quadro.
func _soltar_estilhacos(ponto: Vector2) -> void:
	var cor := _placeholder.color if _placeholder.visible else Color.WHITE
	var desbotar := Gradient.new()
	desbotar.set_color(0, cor)
	desbotar.set_color(1, Color(cor, 0.0))

	var p := CPUParticles2D.new()
	p.name = "EstilhacosBola"
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 16
	p.lifetime = 0.55
	p.direction = Vector2.UP
	p.spread = 80.0
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0.0, 980.0)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color_ramp = desbotar
	p.finished.connect(p.queue_free)
	p.position = get_parent().to_local(ponto)
	get_parent().add_child(p)
	p.emitting = true


## Som que sobrevive à bola: fica no pai e se apaga sozinho ao terminar.
func _tocar_solto(stream: AudioStream, volume: float, ponto: Vector2) -> void:
	if stream == null:
		return
	var som := AudioStreamPlayer2D.new()
	som.stream = stream
	som.volume_db = volume
	som.finished.connect(som.queue_free)
	som.position = get_parent().to_local(ponto)
	get_parent().add_child(som)
	som.play()
