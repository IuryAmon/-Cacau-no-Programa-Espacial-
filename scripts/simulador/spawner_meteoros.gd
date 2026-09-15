extends Node2D

# Solta as moléculas pela direita da tela, apertando o ritmo aos poucos.
# Mesma "escada de dificuldade" do shoot'em up original: acelera, dá um platô
# para o jogador respirar e depois volta a apertar.

@export var meteoro_acido: PackedScene    # HCl  -> morre com o tiro azul
@export var meteoro_basico: PackedScene   # NaOH -> morre com o tiro verde

@export var intervalo_inicial: float = 7.0
@export var atraso_inicial: float = 2.0
@export var velocidade_inicial: float = 300.0
## Margem vertical (px) que os spawns respeitam em cima e embaixo.
@export var margem_vertical: float = 90.0

var _intervalo: float = 7.0
var _tempo_dificuldade: float = 0.0
var _ativo: bool = true


func _ready() -> void:
	_intervalo = intervalo_inicial
	_rodar()


func parar() -> void:
	_ativo = false


func _rodar() -> void:
	await get_tree().create_timer(atraso_inicial, false).timeout

	while _ativo and is_inside_tree():
		if not get_tree().paused:
			_soltar_meteoro()
			_apertar_ritmo()
		await get_tree().create_timer(_intervalo, false).timeout


func _apertar_ritmo() -> void:
	_tempo_dificuldade += 1.0

	if _tempo_dificuldade < 30.0:
		# Aceleração inicial, travando em 0.8s para dar um respiro.
		_intervalo = maxf(0.8, _intervalo * 0.9)
	elif _tempo_dificuldade >= 60.0:
		# Passado o platô, a barreira quebra e volta a cair.
		_intervalo = maxf(0.4, _intervalo * 0.95)


func _soltar_meteoro() -> void:
	var cena := meteoro_basico if randf() < 0.5 else meteoro_acido
	if cena == null:
		return

	var meteoro := cena.instantiate()

	if "base_speed" in meteoro:
		var teto := 600.0 if _tempo_dificuldade < 60.0 else 850.0
		meteoro.base_speed = minf(velocidade_inicial + _tempo_dificuldade * 10.0, teto)

	var tela := get_viewport_rect().size
	meteoro.position = Vector2(
		tela.x - 100.0,
		randf_range(margem_vertical, tela.y - margem_vertical)
	)
	get_parent().add_child(meteoro)
