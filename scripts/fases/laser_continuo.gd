@tool
class_name LaserContinuo
extends Node2D

# --- LASER CONTÍNUO (ARMADILHA SEMPRE LIGADA) ---
#
# Um raio reto entre dois emissores que fica ligado O TEMPO TODO e MATA na
# hora quem encosta. Não tem caixa elétrica, nem timer, nem botão: é
# obstáculo fixo, para pular por cima ou achar outro caminho.
#
# COMO EDITAR NO EDITOR (tudo é nó ou export, e o raio se ajusta ao vivo):
#   - A ORIGEM do nó é a PONTA de onde o raio sai (encoste na boca do emissor
#     da esquerda). O raio cresce para +X.
#   - "comprimento" é a distância até a boca do outro emissor. Raio vertical?
#     Gire o nó 90° (ou -90°); nada mais muda.
#   - Feixe       ColorRect com o shader feixe_laser.gdshader. Cores, pulsos e
#                 fagulhas ficam no material dele. Tamanho e posição são do
#                 script — não arraste.
#   - Hitbox      Area2D com a forma do dano. A altura é "espessura_dano"; o
#                 comprimento acompanha o raio.
#   - FaiscasInicio / FaiscasFim   faíscas espirrando das duas bocas.
#   - SomLaser    zumbido em loop, no meio do raio. Volume e alcance são do nó.
#
# Morrer aqui é morte de CORTE (a personagem é picada no lugar), igual aos
# espinhos de laser e à serra — ver scripts/fx/morte_despedacada.gd.

## Qualquer valor acima da vida cheia: zera a barra no mesmo toque.
const GOLPE_LETAL := 9999
const MASCARA_PERSONAGENS := 1
## Altura do retângulo do Feixe: sobra espaço em volta do raio para halo e
## fagulhas (o raio em si tem 12 px).
const ALTURA_FEIXE := 40.0

## Distância, em pixels, da boca de um emissor até a do outro.
@export_range(8.0, 4000.0, 1.0, "suffix:px") var comprimento: float = 492.0:
	set(valor):
		comprimento = maxf(8.0, valor)
		_ajustar()

## Altura da área que mata. Um pouco mais fina que o raio desenhado (12 px):
## raspar na beirada do brilho não conta, encostar no raio conta.
@export_range(2.0, 40.0, 1.0, "suffix:px") var espessura_dano: float = 8.0:
	set(valor):
		espessura_dano = valor
		_ajustar()

## Ligado: mata mesmo durante a invencibilidade do dash ou do "piscado" depois
## de um dano. Laser é laser — não dá para atravessar dando dash.
@export var ignora_invencibilidade: bool = true

@onready var _feixe: ColorRect = get_node_or_null("Feixe")
@onready var _hitbox: Area2D = get_node_or_null("Hitbox")
@onready var _colisao: CollisionShape2D = get_node_or_null("Hitbox/Colisao")
@onready var _faiscas_inicio: CPUParticles2D = get_node_or_null("FaiscasInicio")
@onready var _faiscas_fim: CPUParticles2D = get_node_or_null("FaiscasFim")
@onready var _som: AudioStreamPlayer2D = get_node_or_null("SomLaser")


func _ready() -> void:
	# A forma da Hitbox e o material do Feixe são "local to scene" na cena do
	# laser: cada instância tem os seus, e esticar um não estica os outros.
	_ajustar()

	if Engine.is_editor_hint():
		return

	_hitbox.collision_layer = 0
	_hitbox.collision_mask = MASCARA_PERSONAGENS
	_hitbox.monitorable = false

	if _som and _som.stream:
		# Começa num ponto sorteado: vários lasers na tela não pulsam juntos.
		_som.play(randf() * _som.stream.get_length())


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _hitbox == null:
		return
	# Checado todo quadro, e não só na entrada: quem estava invencível dentro
	# do raio morre no quadro em que a invencibilidade acaba.
	for corpo in _hitbox.get_overlapping_bodies():
		if corpo.has_method("take_damage"):
			_matar(corpo)


func _matar(corpo: Node2D) -> void:
	if "current_health" in corpo and corpo.current_health <= 0:
		return
	if ignora_invencibilidade:
		if "esta_invencivel" in corpo:
			corpo.esta_invencivel = false
		if "esta_invencivel_dash" in corpo:
			corpo.esta_invencivel_dash = false

	# O corte sai do ponto do raio mais perto do corpo: os cacos voam para
	# longe do lugar exato em que ele encostou.
	var local := to_local(corpo.global_position)
	var ponto := to_global(Vector2(clampf(local.x, 0.0, comprimento), 0.0))
	if corpo.has_method("marcar_morte_de_corte"):
		corpo.marcar_morte_de_corte(ponto)
	corpo.take_damage(GOLPE_LETAL)


## Estica feixe, hitbox, faíscas e som para o "comprimento" atual.
func _ajustar() -> void:
	if not is_node_ready():
		return

	if _feixe:
		_feixe.position = Vector2(0.0, -ALTURA_FEIXE * 0.5)
		_feixe.size = Vector2(comprimento, ALTURA_FEIXE)
		var material := _feixe.material as ShaderMaterial
		if material:
			material.set_shader_parameter("tamanho", _feixe.size)

	if _colisao:
		_colisao.position = Vector2(comprimento * 0.5, 0.0)
		var forma := _colisao.shape as RectangleShape2D
		if forma:
			forma.size = Vector2(comprimento, espessura_dano)

	if _faiscas_inicio:
		_faiscas_inicio.position = Vector2.ZERO
	if _faiscas_fim:
		_faiscas_fim.position = Vector2(comprimento, 0.0)
	if _som:
		_som.position = Vector2(comprimento * 0.5, 0.0)
