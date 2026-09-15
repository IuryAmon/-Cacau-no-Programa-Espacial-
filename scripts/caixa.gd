extends CharacterBody2D

# Caixa empurrável. Lembra onde ficou quando a personagem SAI da fase por uma
# porta ou passagem: voltar do laboratório encontra a caixa no mesmo lugar.
# Morrer não conta — a fase recarrega com a caixa onde ela estava na última
# saída (ou no lugar original), o que também desencalha uma caixa empurrada
# para onde não devia.

const ATRITO := 800.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var _sendo_empurrado := false

func _ready() -> void:
	add_to_group(EstadoMundo.GRUPO_SALVAR_AO_SAIR)
	var guardada = EstadoMundo.ler(self, "posicao")
	if guardada is Vector2:
		global_position = guardada

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	elif not _sendo_empurrado:
		velocity.x = move_toward(velocity.x, 0, ATRITO * delta)

	move_and_slide()
	_sendo_empurrado = false

func empurrar(vel_x: float) -> void:
	velocity.x = vel_x
	_sendo_empurrado = true

## Chamado pelo FadeTela logo antes de trocar de cena (ver EstadoMundo).
func salvar_ao_sair() -> void:
	EstadoMundo.guardar(self, "posicao", global_position)
