extends Node

# Autoload usado por eventos "do" dentro das timelines do Dialogic, para
# chamar funções do player sem fechar o diálogo (o Dialogic aguarda o await).

func andar_ate_foguete() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("andar_ate_foguete"):
		await player.andar_ate_foguete()
