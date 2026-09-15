extends CharacterBody2D

enum Estado { PATROL, CARREGANDO, ATIRANDO, SUPERAQUECIDO, TOMANDO_DANO, MORTO }

# Mecânica: Superaquecimento
# Patrulha → detecta jogador → carrega (animação attack) → dispara bola de fogo no frame_disparo
# Após tiros_para_superaquecer tiros consecutivos: SUPERAQUECE por tempo_superaquecido (fica laranja, vulnerável)
# Pisar em cima = stompe (microondas toma dano); encostar de lado = player toma dano

const CENA_FIREBALL = preload("res://scenes/fireball.tscn")

@export var velocidade_patrulha: float = 80.0
@export var vida_maxima: int = 3
@export var tiros_para_superaquecer: int = 3
@export var tempo_cooldown: float = 0.8
@export var tempo_superaquecido: float = 2.5
@export var frame_disparo: int = 7
@export var som_dano: AudioStream

var vida_atual: int
var estado: Estado = Estado.PATROL
var direcao_patrulha: float = 1.0
var tiros_disparados: int = 0
var player: Node2D = null
var _imune_stompe: bool = false  # Evita re-trigger do stompe no mesmo salto
var _invencivel: bool = false
var _knockback: float = 0.0

var gravidade = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var sprite = $AnimatedSprite2D
@onready var area_deteccao = $AreaDeteccao
@onready var area_pisada = $AreaPisada
@onready var area_hitbox = $AreaHitbox
@onready var ponto_tiro = $PontoTiro

func _ready() -> void:
	vida_atual = vida_maxima
	add_to_group("microwave")
	area_deteccao.body_entered.connect(_on_player_detectado)
	area_deteccao.body_exited.connect(_on_player_saiu)
	sprite.animation_finished.connect(_on_animacao_terminou)
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.play("walk")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravidade * delta

	if abs(_knockback) > 0.0:
		velocity.x = _knockback
		_knockback = move_toward(_knockback, 0.0, 500.0 * delta)
	else:
		match estado:
			Estado.PATROL:
				_processo_patrulha()
			_:
				velocity.x = 0.0

	move_and_slide()

	if estado != Estado.MORTO:
		_verificar_contato_player()

# Toda a lógica de colisão com o player acontece aqui, de forma síncrona e ordenada.
# Stompe é checado PRIMEIRO — se ocorrer, a checagem de hitbox é bloqueada no mesmo frame.
func _verificar_contato_player() -> void:
	# --- STOMPE: player caindo sobre AreaPisada (faixa fina no topo) ---
	for body in area_pisada.get_overlapping_bodies():
		if not body.is_in_group("player"):
			continue
		if body.velocity.y < 0 or _imune_stompe:
			break
		# Stompe válido: player caindo rápido o suficiente
		body.velocity.y = -380.0
		var player_sprite = body.get_node_or_null("AnimatedSprite2D")
		if player_sprite and player_sprite.sprite_frames.has_animation("jump"):
			player_sprite.stop()
			player_sprite.play("jump")
		var kb_dir = sign(global_position.x - body.global_position.x)
		if kb_dir == 0:
			kb_dir = 1.0
		_knockback = kb_dir * 300.0
		velocity.y = -220.0
		var dano = 2 if estado == Estado.SUPERAQUECIDO else 1
		_tomar_dano(dano)
		_imune_stompe = true
		_aguardar(0.4, func(): _imune_stompe = false)
		return  # Garante que o hitbox NÃO processa no mesmo frame

	# --- HITBOX: contato lateral com o corpo do microondas ---
	if _imune_stompe:
		return
	for body in area_hitbox.get_overlapping_bodies():
		if not body.is_in_group("player"):
			continue
		# Não dá dano enquanto o player está subindo (pulo, pulo duplo, knockback upward)
		if body.velocity.y < 0:
			break
		if body.has_method("take_damage"):
			var dir_recuo = (body.global_position - global_position).normalized()
			body.take_damage(1, dir_recuo)
		break

func _ha_chao_a_frente() -> bool:
	var espaco = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position + Vector2(direcao_patrulha * 40.0, 10.0),
		global_position + Vector2(direcao_patrulha * 40.0, 55.0)
	)
	query.exclude = [self]
	return not espaco.intersect_ray(query).is_empty()

func _processo_patrulha() -> void:
	if is_on_wall() or not _ha_chao_a_frente():
		direcao_patrulha *= -1.0
	velocity.x = velocidade_patrulha * direcao_patrulha
	# Sprite original olha pra ESQUERDA → flip_h=true = olha pra DIREITA
	sprite.flip_h = direcao_patrulha > 0

func _on_player_detectado(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	# Sempre atualiza a referência para que re-entradas durante superaquecimento
	# ou cooldown sejam reconhecidas corretamente.
	player = body
	if estado == Estado.PATROL:
		_iniciar_carga()

func _on_player_saiu(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = null

func _iniciar_carga() -> void:
	if estado in [Estado.MORTO, Estado.CARREGANDO]:
		return
	estado = Estado.CARREGANDO
	velocity.x = 0.0
	if is_instance_valid(player):
		sprite.flip_h = player.global_position.x > global_position.x
	sprite.play("attack")

# Dispara no frame certo da animação, não no final
func _on_frame_changed() -> void:
	if sprite.animation == "attack" and sprite.frame == frame_disparo and estado == Estado.CARREGANDO:
		_executar_tiro()

func _executar_tiro() -> void:
	if estado != Estado.CARREGANDO:
		return
	estado = Estado.ATIRANDO

	var dir = 1.0 if sprite.flip_h else -1.0
	ponto_tiro.position.x = 3.5 + 12.0 * dir

	var fb = CENA_FIREBALL.instantiate()
	fb.direcao = dir
	get_parent().add_child(fb)
	fb.global_position = ponto_tiro.global_position

	tiros_disparados += 1

	# Tint amarelo no último tiro: aviso visual de superaquecimento iminente
	if tiros_disparados >= tiros_para_superaquecer:
		sprite.modulate = Color(1.6, 1.0, 0.1, 1.0)

	_aguardar(tempo_cooldown, _pos_tiro)

func _pos_tiro() -> void:
	if not is_instance_valid(self) or estado != Estado.ATIRANDO:
		return
	if tiros_disparados >= tiros_para_superaquecer:
		_iniciar_superaquecimento()
	elif is_instance_valid(player):
		_iniciar_carga()
	else:
		estado = Estado.PATROL
		tiros_disparados = 0
		sprite.play("walk")

func _iniciar_superaquecimento() -> void:
	estado = Estado.SUPERAQUECIDO
	tiros_disparados = 0
	sprite.modulate = Color(1.8, 0.5, 0.2, 1.0)
	sprite.play("idle")
	_aguardar(tempo_superaquecido, _fim_superaquecimento)

func _fim_superaquecimento() -> void:
	if not is_instance_valid(self) or estado != Estado.SUPERAQUECIDO:
		return
	sprite.modulate = Color.WHITE
	if is_instance_valid(player):
		_iniciar_carga()
	else:
		estado = Estado.PATROL
		sprite.play("walk")

func _tocar_som_dano() -> void:
	if not som_dano:
		return
	var audio := AudioStreamPlayer.new()
	audio.stream = som_dano
	audio.finished.connect(audio.queue_free)
	add_child(audio)
	audio.play()

func _tomar_dano(quantidade: int) -> void:
	if estado == Estado.MORTO or _invencivel:
		return
	_tocar_som_dano()
	sprite.modulate = Color.WHITE
	vida_atual -= quantidade
	if vida_atual <= 0:
		_morrer()
	else:
		estado = Estado.TOMANDO_DANO
		sprite.play("hit")
		_invencivel = true
		_piscar_invencibilidade()
		_aguardar(1.2, func():
			_invencivel = false
		)

func _piscar_invencibilidade() -> void:
	while _invencivel and is_instance_valid(self):
		sprite.modulate.a = 0.2
		await get_tree().create_timer(0.1).timeout
		if not _invencivel or not is_instance_valid(self):
			break
		sprite.modulate.a = 1.0
		await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		sprite.modulate.a = 1.0

func _morrer() -> void:
	estado = Estado.MORTO
	sprite.modulate = Color.WHITE
	velocity = Vector2.ZERO
	area_deteccao.set_deferred("monitoring", false)
	sprite.play("death")

func _on_animacao_terminou() -> void:
	match sprite.animation:
		"attack":
			if estado == Estado.ATIRANDO:
				sprite.play("idle")
		"hit":
			if estado == Estado.TOMANDO_DANO:
				if is_instance_valid(player):
					_iniciar_carga()
				else:
					estado = Estado.PATROL
					sprite.play("walk")
		"death":
			queue_free()

func _aguardar(tempo: float, callback: Callable) -> void:
	await get_tree().create_timer(tempo).timeout
	if is_instance_valid(self):
		callback.call()
