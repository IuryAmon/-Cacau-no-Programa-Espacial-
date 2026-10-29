extends Node

# --- A CACAU ENTRANDO EM CENA, NO COMEÇO DA HISTÓRIA ---
#
# Logo depois da introdução (scripts/introducao.gd), o world1 abre clareando
# com a música já tocando e a Cacau entra correndo pela esquerda da tela até
# "destino_x". É uma cutscene: ela corre sozinha, sem controle, e o aviso de
# "Pressione ... para movimentar-se" (BotaoMoviment) só aparece quando ela
# para e o controle volta.
#
# Só acontece na chegada pela introdução (EstadoMundo.abertura_pendente): a
# fase recarregada depois de uma morte, a volta do laboratório e a cena aberta
# direto no editor começam como sempre.
#
# A corrida é a mesma da Cacau abrindo espaço para a porta derreter
# (recuar_ate_x, no player.gd): a animação de correr, na velocidade dela.

## Ela terminou de entrar e o controle voltou.
signal terminou

## Onde ela para (x do mundo).
@export var destino_x: float = 940.0
## Onde ela começa: fora da tela, à esquerda, com o pé no chão do começo do
## mapa (posição do mundo).
@export var largada: Vector2 = Vector2(-90.0, 481.0)
## O aviso de movimento, que espera ela parar.
@export var aviso: NodePath = ^"../BotaoMoviment"
## Quanto o aviso leva para aparecer.
@export var duracao_do_aviso: float = 0.6

var _correndo: bool = false


func _ready() -> void:
	if not EstadoMundo.abertura_pendente:
		return
	EstadoMundo.abertura_pendente = false
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("recuar_ate_x"):
		return
	_entrar(player)


## True enquanto ela está correndo para o lugar.
func correndo() -> bool:
	return _correndo


func _entrar(player) -> void:
	_correndo = true
	var no_aviso := get_node_or_null(aviso) as CanvasItem
	if no_aviso:
		no_aviso.visible = false
	player.global_position = largada
	player.velocity = Vector2.ZERO
	player.pode_se_mover = false
	CameraJogador.encaixar(player)

	await player.recuar_ate_x(destino_x)

	_correndo = false
	if no_aviso:
		no_aviso.modulate.a = 0.0
		no_aviso.visible = true
		create_tween().tween_property(no_aviso, "modulate:a", 1.0, duracao_do_aviso)
	terminou.emit()
