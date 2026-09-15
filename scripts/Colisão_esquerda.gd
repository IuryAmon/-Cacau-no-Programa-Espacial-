extends Area2D

# Função disparada quando algo entra na área
func _on_body_entered(body: Node2D) -> void:
	# Verificamos se foi o seu personagem (nome do nó deve ser "Player")
	if body.name == "Player":
		# Pegamos o nó da caixa de diálogo que está no seu cenário
		# O caminho "$" depende de onde ela está na árvore de nós
		get_parent().get_node("DialogBox").mostrar("Não faz sentido voltar agora.")

# Função disparada quando algo sai da área
func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		# Comando para a caixa desaparecer
		get_parent().get_node("DialogBox").esconder()
