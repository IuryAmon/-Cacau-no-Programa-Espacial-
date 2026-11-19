extends Node2D

# Faz os ícones de "Pressione W/A/S/D ou o direcional do controle" reagirem
# ao input real do jogador, em vez de ficar em loop automático.
#
# O frame é controlado manualmente (sem usar play()/stop() da AnimatedSprite2D,
# que corre o animação sozinha) para garantir que ela trave exatamente no
# frame "apertado" enquanto a tecla/botão estiver pressionado:
#   - Pressionando: avança frame a frame até FRAME_APERTADO_* e trava lá
#     enquanto o input continuar seguro.
#   - Soltando: mostra rapidamente o frame seguinte ("soltando") e depois
#     volta e permanece no frame 0.
#
# A frase só aparece com a Cacau por perto (AparecerPerto): chegando, surge
# num fade in; indo embora, some num fade out. O fade é nas partes da frase
# (os filhos), e não neste nó: o modulate dele é da AberturaDaHistoria, que o
# acende quando a Cacau termina de entrar correndo.

@export_group("Aparecer")
## O meio da frase, a partir da posição deste nó (é dele que se mede a
## distância até a Cacau).
@export var meio_da_frase: Vector2 = Vector2(60, -20)
## A Cacau a menos disto do meio da frase, na horizontal (px do mundo), e a
## frase aparece.
@export var distancia_para_aparecer: float = AparecerPerto.DISTANCIA
## Ela some só depois de a Cacau se afastar um pouco mais que isso.
@export var folga_para_sumir: float = AparecerPerto.FOLGA
## Mais longe que isto na vertical, não aparece.
@export var altura_para_aparecer: float = AparecerPerto.ALTURA
## Duração do fade in e do fade out (segundos).
@export var duracao_do_fade: float = AparecerPerto.DURACAO
@export_group("")

var _a_vista := false
var _alfa := 0.0

@onready var _teclado := {
	"w": $DirecionalTelcado/w,
	"a": $DirecionalTelcado/A,
	"s": $DirecionalTelcado/S,
	"d": $DirecionalTelcado/D,
}

@onready var _controle := {
	"cima": $DirecionalControle/cima,
	"direita": $DirecionalControle/direita,
	"baixo": $DirecionalControle/baixo,
	"esquerda": $DirecionalControle/esquerda,
}

# Frame em que a tecla/botão fica "afundado" (0-indexado).
# Teclado: animação tem 4 frames (0..3) e o pressionado é o 3º frame -> índice 2.
const FRAME_APERTADO_TECLADO := 2
# Controle: animação tem 2 frames (0..1), o pressionado é o último -> índice 1.
const FRAME_APERTADO_CONTROLE := 1

# idle | subindo | segurando | soltando
var _estado := {}
var _tempo := {}


func _ready() -> void:
	for sprite in _teclado.values():
		_resetar(sprite)
	for sprite in _controle.values():
		_resetar(sprite)
	_aplicar_alfa()


## O alfa da frase vai nas partes dela (ver o cabeçalho).
func _aplicar_alfa() -> void:
	for parte in get_children():
		if parte is CanvasItem:
			parte.modulate.a = _alfa


func _resetar(sprite: AnimatedSprite2D) -> void:
	sprite.stop()
	sprite.frame = 0
	_tempo[sprite] = 0.0
	_estado[sprite] = "idle"


func _process(delta: float) -> void:
	_a_vista = AparecerPerto.cacau_perto(get_tree(), to_global(meio_da_frase), distancia_para_aparecer,
		altura_para_aparecer, folga_para_sumir, _a_vista)
	var antes := _alfa
	_alfa = AparecerPerto.alfa(_alfa, _a_vista, delta, duracao_do_fade)
	if _alfa != antes:
		_aplicar_alfa()
	_atualizar(_teclado["w"], Input.is_physical_key_pressed(KEY_W), FRAME_APERTADO_TECLADO, delta)
	_atualizar(_teclado["a"], Input.is_physical_key_pressed(KEY_A), FRAME_APERTADO_TECLADO, delta)
	_atualizar(_teclado["s"], Input.is_physical_key_pressed(KEY_S), FRAME_APERTADO_TECLADO, delta)
	_atualizar(_teclado["d"], Input.is_physical_key_pressed(KEY_D), FRAME_APERTADO_TECLADO, delta)

	_atualizar(_controle["cima"], Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP), FRAME_APERTADO_CONTROLE, delta)
	_atualizar(_controle["direita"], Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT), FRAME_APERTADO_CONTROLE, delta)
	_atualizar(_controle["baixo"], Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN), FRAME_APERTADO_CONTROLE, delta)
	_atualizar(_controle["esquerda"], Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT), FRAME_APERTADO_CONTROLE, delta)


func _atualizar(sprite: AnimatedSprite2D, pressionado: bool, frame_alvo: int, delta: float) -> void:
	var estado: String = _estado.get(sprite, "idle")

	# Enquanto o "soltar" está tocando, deixa terminar antes de aceitar novo estado.
	if estado == "soltando":
		return

	if pressionado:
		if estado == "segurando":
			return # já travado no frame apertado, não faz nada

		var duracao_frame: float = sprite.sprite_frames.get_frame_duration("default", 0) / sprite.sprite_frames.get_animation_speed("default")
		_tempo[sprite] = _tempo.get(sprite, 0.0) + delta
		var frame_calculado: int = int(_tempo[sprite] / duracao_frame)

		if frame_calculado >= frame_alvo:
			sprite.frame = frame_alvo
			_estado[sprite] = "segurando"
		else:
			sprite.frame = frame_calculado
			_estado[sprite] = "subindo"
	else:
		if estado == "segurando":
			_soltar(sprite, frame_alvo)
		elif estado == "subindo":
			_resetar(sprite)


func _soltar(sprite: AnimatedSprite2D, frame_alvo: int) -> void:
	_estado[sprite] = "soltando"

	var total_frames := sprite.sprite_frames.get_frame_count("default")
	var frame_de_soltura := frame_alvo + 1

	if frame_de_soltura < total_frames:
		sprite.frame = frame_de_soltura
		var velocidade: float = sprite.sprite_frames.get_animation_speed("default")
		var duracao: float = sprite.sprite_frames.get_frame_duration("default", frame_de_soltura)
		await get_tree().create_timer(duracao / velocidade).timeout

	sprite.frame = 0
	_tempo[sprite] = 0.0
	_estado[sprite] = "idle"
