class_name SalaDeRetorno
extends ReferenceRect

# --- SALA DE RETORNO (checkpoint automático ao entrar numa sala) ---
#
# Retângulo desenhado no editor em volta de uma sala da fase. Quando a
# personagem ENTRA nele, o jogo grava ali o ponto para onde ela volta se
# morrer — sem bandeira, sem aviso, como nos jogos de plataforma por salas.
#
# Grava no mesmo PontoDeRetorno das bandeiras de checkpoint, então os dois
# convivem sem conflito: vale sempre o último registrado (ver
# ponto_de_retorno.gd).
#
# ONDE ELA RENASCE:
#   * COM marcadores: crie um ou mais Marker2D como filhos deste nó (qualquer
#     nome). Na entrada, vale o marcador MAIS PERTO de onde a personagem
#     entrou — um na porta da esquerda e outro na da direita resolvem as salas
#     que dá para atravessar nos dois sentidos. A origem do marcador é a
#     origem da personagem (o meio da cápsula): ponha ~37 px acima do chão.
#   * SEM marcadores: vale o primeiro lugar SEGURO em que ela pisa depois de
#     entrar — chão fixo (tile ou StaticBody), pisado por alguns quadros
#     seguidos sem tomar dano (pode ser correndo; vale o primeiro desses
#     quadros). Plataforma que cai, plataforma móvel e caixa não contam: ela
#     nunca renasce em cima de algo que pode sumir.
#
# O QUE NÃO GRAVA:
#   * a sala em que ela já está quando a cena abre (a entrada da fase ou o
#     lugar onde acabou de renascer) — assim renascer numa bandeira no meio da
#     sala não é trocado pelo começo dela;
#   * entrar e sair antes de achar chão seguro (atravessar pulando);
#   * entrar morrendo ou no meio do recuo de um golpe.
#
# COMO EDITAR: arraste e redimensione o retângulo (só aparece no editor). O que
# vale é a ORIGEM da personagem estar dentro dele. Salas vizinhas podem
# encostar; se sobrepuserem, cada uma grava ao ser ENTRADA, então a última
# atravessada vence.

const GRUPO := &"sala_de_retorno"

## Quadros de física seguidos em chão seguro antes de gravar (sem
## marcadores). 6 quadros = 0,1 s: evita gravar o instante de um pouso que já
## escorrega para um buraco.
@export var quadros_no_chao: int = 6

## Desligue para a sala deixar de gravar sem precisar apagar o nó.
@export var ativa: bool = true

var _player: CharacterBody2D = null
var _dentro: bool = false
## Entrou e ainda não gravou (esperando chão seguro).
var _aguardando: bool = false
var _quadros_seguros: int = 0
## Onde a sequência de chão seguro começou — é isso que vira o ponto, e não
## onde ela estava no último quadro (mais perto da entrada = mais seguro).
var _inicio_seguro: Vector2 = Vector2.ZERO
var _conferiu_inicio: bool = false


func _ready() -> void:
	add_to_group(GRUPO)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## True se o ponto (global) está dentro da sala.
func contem(ponto_global: Vector2) -> bool:
	return get_global_rect().has_point(ponto_global)


func _physics_process(_delta: float) -> void:
	if not ativa:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
		if _player == null:
			return

	var dentro_agora := contem(_player.global_position)

	# Primeiro quadro: quem já nasce dentro não conta como "entrou". Espera um
	# quadro de física para as portas/fase/retorno já terem posicionado o player.
	if not _conferiu_inicio:
		_conferiu_inicio = true
		_dentro = dentro_agora
		return

	if dentro_agora and not _dentro:
		_ao_entrar()
	elif not dentro_agora and _dentro:
		_aguardando = false
	_dentro = dentro_agora

	if _aguardando:
		_tentar_gravar_no_chao()


func _ao_entrar() -> void:
	if not _player_pode_gravar():
		# Entrou já morrendo/em recuo: não grava nesta passagem.
		_aguardando = false
		return

	var marcador := _marcador_mais_perto(_player.global_position)
	if marcador:
		PontoDeRetorno.registrar(self, marcador.global_position)
		_aguardando = false
		return

	_aguardando = true
	_quadros_seguros = 0


func _tentar_gravar_no_chao() -> void:
	if not _player_pode_gravar():
		# Tomou um golpe esperando: só grava quando estiver bem de novo, e o
		# lugar tem que provar de novo que é seguro.
		_quadros_seguros = 0
		return
	if not _em_chao_seguro():
		_quadros_seguros = 0
		return
	if _quadros_seguros == 0:
		_inicio_seguro = _player.global_position
	_quadros_seguros += 1
	if _quadros_seguros >= quadros_no_chao:
		PontoDeRetorno.registrar(self, _inicio_seguro)
		_aguardando = false


func _player_pode_gravar() -> bool:
	if "current_health" in _player and _player.current_health <= 0:
		return false
	if "esta_no_knockback" in _player and _player.esta_no_knockback:
		return false
	if not _player.visible:
		return false  # no meio de uma sequência (porta, cutscene)
	return true


## Chão parado e que não some: tile ou StaticBody2D comum. AnimatableBody2D
## (plataforma móvel, plataforma que cai) herda de StaticBody2D, por isso é
## recusado antes.
func _em_chao_seguro() -> bool:
	if not _player.is_on_floor():
		return false
	for i in _player.get_slide_collision_count():
		var colisao := _player.get_slide_collision(i)
		if colisao.get_normal().dot(Vector2.UP) < 0.7:
			continue
		var corpo := colisao.get_collider()
		if corpo is AnimatableBody2D:
			return false
		if corpo is TileMapLayer or corpo is TileMap or corpo is StaticBody2D:
			return true
	return false


func _marcador_mais_perto(ponto: Vector2) -> Marker2D:
	var melhor: Marker2D = null
	var melhor_dist := INF
	for filho in get_children():
		if filho is Marker2D:
			var d := ponto.distance_squared_to((filho as Marker2D).global_position)
			if d < melhor_dist:
				melhor_dist = d
				melhor = filho
	return melhor
