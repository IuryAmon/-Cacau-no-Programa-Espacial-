class_name PlataformaMovel
extends AnimatableBody2D

# --- PLATAFORMA MÓVEL (DE PAREDE A PAREDE) ---
#
# Vai e volta na horizontal entre duas paredes: sai devagar, ganha velocidade
# no meio, freia antes de chegar e para um instante em cada ponta. Quem está
# em cima é carregado junto (AnimatableBody2D sincronizado com a física).
#
# COMO EDITAR NO EDITOR
#   - Arraste o nó para a altura e o ponto em que ela começa.
#   - Com "detectar_paredes" ligado, ao começar a fase ela procura sozinha a
#     parede mais próxima de cada lado, na altura dela, e esse vira o
#     percurso — mova a plataforma e o percurso acompanha.
#     Desligado, valem "limite_esquerdo" e "limite_direito" (x global do
#     CENTRO da plataforma em cada ponta).
#   - A cor vem do material do Sprite (shader deslocar_matiz): mude
#     "giro_matiz" para outra cor sem mexer no PNG.
#
# É DE MÃO ÚNICA: dá para subir nela pulando por baixo, e ela não empurra
# ninguém de lado. Num corredor apertado isso evita esmagar a personagem
# contra a parede ou contra a plataforma de baixo.

@export var detectar_paredes: bool = true
## Usado quando "detectar_paredes" está desligado (ou não achou parede).
@export var limite_esquerdo: float = 0.0
## Usado quando "detectar_paredes" está desligado (ou não achou parede).
@export var limite_direito: float = 0.0
## Espaço entre a borda da plataforma e a parede, em cada ponta.
@export_range(0.0, 64.0, 1.0, "suffix:px") var folga_da_parede: float = 0.0

@export_group("Movimento")
## Velocidade média de uma ponta à outra (no meio do trajeto passa ~1,6x disso).
@export_range(20.0, 800.0, 1.0, "suffix:px/s") var velocidade: float = 130.0
## Parada em cada ponta antes de voltar.
@export_range(0.0, 5.0, 0.05, "suffix:s") var pausa_nas_pontas: float = 0.6
@export var comecar_para_direita: bool = true

## Até onde procura parede de cada lado.
const ALCANCE_DETECCAO := 2000.0

@onready var _colisao: CollisionShape2D = $Colisao

var _pronta := false
var _quadros := 0
var _esquerda := 0.0
var _direita := 0.0
var _origem := 0.0
var _destino := 0.0
var _progresso := 0.0
var _pausa := 0.0


func _physics_process(delta: float) -> void:
	if not _pronta:
		# As colisões dos tiles só existem depois do primeiro quadro de física.
		_quadros += 1
		if _quadros >= 2:
			_preparar_percurso()
		return

	if _pausa > 0.0:
		_pausa -= delta
		return

	var distancia := absf(_destino - _origem)
	if distancia < 1.0:
		_proxima_perna()
		return

	_progresso = minf(_progresso + delta * velocidade / distancia, 1.0)
	# Senoide: sai devagar, acelera, freia na chegada — sem tranco nas pontas
	# nem para quem está em cima.
	var suave := 0.5 - 0.5 * cos(PI * _progresso)
	global_position.x = lerpf(_origem, _destino, suave)

	if _progresso >= 1.0:
		_pausa = pausa_nas_pontas
		_proxima_perna()


func _proxima_perna() -> void:
	_origem = global_position.x
	_destino = _esquerda if is_equal_approx(_destino, _direita) else _direita
	_progresso = 0.0


func _preparar_percurso() -> void:
	var meia := _meia_largura()
	_esquerda = limite_esquerdo
	_direita = limite_direito

	if detectar_paredes:
		var parede_esq = _procurar_parede(-1.0)
		var parede_dir = _procurar_parede(1.0)
		if parede_esq == null or parede_dir == null:
			push_warning("%s: não achei parede dos dois lados; usando limite_esquerdo/limite_direito." % name)
		else:
			_esquerda = parede_esq + meia + folga_da_parede
			_direita = parede_dir - meia - folga_da_parede

	if _direita < _esquerda:
		push_warning("%s: o percurso é menor que a plataforma; ela vai ficar parada." % name)
		_direita = _esquerda

	global_position.x = clampf(global_position.x, _esquerda, _direita)
	_origem = global_position.x
	_destino = _direita if comecar_para_direita else _esquerda
	_progresso = 0.0
	_pronta = true


## Borda (x global) da parede mais próxima naquele sentido, ou null.
## Ignora personagens e outras coisas que se mexem: só vale cenário parado.
func _procurar_parede(sentido: float) -> Variant:
	var espaco := get_world_2d().direct_space_state
	var consulta := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(sentido * ALCANCE_DETECCAO, 0.0),
		collision_mask)
	var ignorar: Array[RID] = [get_rid()]
	for tentativa in 16:
		consulta.exclude = ignorar
		var acerto := espaco.intersect_ray(consulta)
		if acerto.is_empty():
			return null
		var objeto: Object = acerto.collider
		if objeto is CharacterBody2D or objeto is RigidBody2D or objeto is AnimatableBody2D:
			ignorar.append(acerto.rid)
			continue
		return acerto.position.x
	return null


func _meia_largura() -> float:
	var forma := _colisao.shape as RectangleShape2D
	if forma == null:
		return 0.0
	return forma.size.x * 0.5 * absf(_colisao.global_scale.x)
