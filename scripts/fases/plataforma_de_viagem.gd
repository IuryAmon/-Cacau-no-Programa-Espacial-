class_name PlataformaDeViagem
extends AnimatableBody2D

# --- PLATAFORMA DE VIAGEM (ANDA QUANDO PISA) ---
#
# Fica parada até a personagem pousar em cima. Aí, depois de um instante,
# segue em linha reta na horizontal até o ponto final — e, dali em diante,
# fica indo e voltando entre o começo e o fim sem parar, com uma pausa curta
# em cada ponta. Quem está em cima é carregado junto (AnimatableBody2D
# sincronizado com a física). Morrer recarrega a fase e ela reaparece parada
# no começo, esperando alguém pisar de novo.
#
# COMO EDITAR NO EDITOR
#   - A posição do nó é onde ela começa (a origem é o CENTRO da plataforma).
#   - "borda_esquerda_final" é o x global em que o lado ESQUERDO dela encosta
#     no fim da viagem. Se esse x estiver à direita do começo, ela anda para
#     a direita (aí vale o lado esquerdo do mesmo jeito).
#
# É DE MÃO ÚNICA, igual à PlataformaMovel: dá para subir pulando por baixo.

const MASCARA_PERSONAGENS := 1

## x global onde o lado esquerdo da plataforma fica no fim da viagem.
@export var borda_esquerda_final: float = 4353.0

@export_group("Movimento")
## Velocidade média da viagem (no meio do trajeto passa ~1,6x disso).
@export_range(20.0, 800.0, 1.0, "suffix:px/s") var velocidade: float = 220.0
## Espera entre pisar e ela começar a andar.
@export_range(0.0, 3.0, 0.05, "suffix:s") var atraso_ao_pisar: float = 0.25
## Parada em cada ponta antes de voltar.
@export_range(0.0, 5.0, 0.05, "suffix:s") var pausa_nas_pontas: float = 0.6

## ESPERANDO: parada no começo, ninguém pisou ainda. PARTINDO: pisaram, conta
## o atraso. VIAJANDO: indo para uma das pontas. PARADA: numa ponta, na pausa
## antes de voltar.
enum Estado { ESPERANDO, PARTINDO, VIAJANDO, PARADA }

@onready var _colisao: CollisionShape2D = $Colisao
@onready var _sensor: Area2D = $Sensor

var estado := Estado.ESPERANDO
## x do começo e do fim do trajeto (o centro da plataforma).
var _inicio := 0.0
var _fim := 0.0
## De onde para onde vai a viagem atual.
var _origem := 0.0
var _destino := 0.0
var _progresso := 0.0
var _espera := 0.0


func _ready() -> void:
	_sensor.collision_layer = 0
	_sensor.collision_mask = MASCARA_PERSONAGENS
	_sensor.monitorable = false


func _physics_process(delta: float) -> void:
	match estado:
		Estado.ESPERANDO:
			if _alguem_pousou():
				_espera = atraso_ao_pisar
				estado = Estado.PARTINDO
		Estado.PARTINDO:
			_espera -= delta
			if _espera <= 0.0:
				_inicio = global_position.x
				_fim = borda_esquerda_final + _meia_largura()
				_partir_para(_fim)
		Estado.VIAJANDO:
			var distancia := absf(_destino - _origem)
			if distancia < 1.0:
				_progresso = 1.0
			else:
				_progresso = minf(_progresso + delta * velocidade / distancia, 1.0)
			# Senoide: sai devagar, acelera, freia na chegada — sem tranco.
			var suave := 0.5 - 0.5 * cos(PI * _progresso)
			global_position.x = lerpf(_origem, _destino, suave)
			if _progresso >= 1.0:
				_espera = pausa_nas_pontas
				estado = Estado.PARADA
		Estado.PARADA:
			_espera -= delta
			if _espera <= 0.0:
				# Volta para a ponta de onde veio.
				_partir_para(_inicio if is_equal_approx(_destino, _fim) else _fim)


func _partir_para(x: float) -> void:
	_origem = global_position.x
	_destino = x
	_progresso = 0.0
	estado = Estado.VIAJANDO


## Personagem de pé em cima dela — encostar por baixo ou no meio de um pulo
## não conta.
func _alguem_pousou() -> bool:
	for corpo in _sensor.get_overlapping_bodies():
		if corpo is CharacterBody2D \
				and (corpo as CharacterBody2D).is_on_floor() \
				and (corpo as CharacterBody2D).velocity.y >= 0.0 \
				and corpo.global_position.y < global_position.y:
			return true
	return false


func _meia_largura() -> float:
	var forma := _colisao.shape as RectangleShape2D
	if forma == null:
		return 0.0
	return forma.size.x * 0.5 * absf(_colisao.global_scale.x)
