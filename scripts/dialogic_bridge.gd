extends Node

# Autoload usado por eventos "do" dentro das timelines do Dialogic, para
# chamar funções do player sem fechar o diálogo (o Dialogic aguarda o await).

func andar_ate_foguete() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("andar_ate_foguete"):
		await player.andar_ate_foguete()


# --- FALA CURTA DO CENÁRIO ---
#
# Quando um obstáculo precisa fazer a Cacau comentar alguma coisa (a porta de
# metal e a chapa soldada, quando ela ainda não tem com o que abri-las), ele
# chama daqui em vez de montar o diálogo por conta própria: a caixa é a mesma
# do resto do jogo, com o retrato dela do lado, e o movimento volta sozinho
# quando a fala acaba.
#
# Bater de novo com uma fala já no ar não faz nada: o Dialogic empilharia as
# duas e a segunda roubaria o "timeline_ended" da primeira, deixando a Cacau
# parada para sempre.

var _falando: bool = false
var _player_travado: Node = null


## Roda uma timeline curta da Cacau e trava o movimento dela enquanto ela fala.
func falar_cacau(timeline: String) -> void:
	if _falando or Dialogic.current_timeline != null:
		return
	_falando = true

	_player_travado = get_tree().get_first_node_in_group("player")
	if _player_travado and "pode_se_mover" in _player_travado:
		_player_travado.pode_se_mover = false

	Dialogic.timeline_ended.connect(_ao_terminar_fala, CONNECT_ONE_SHOT)
	Dialogic.start(timeline)


func _ao_terminar_fala() -> void:
	_falando = false
	if is_instance_valid(_player_travado) and "pode_se_mover" in _player_travado:
		_player_travado.pode_se_mover = true
	_player_travado = null
