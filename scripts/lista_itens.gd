extends HBoxContainer

# Função que cria o sprite do item no canto da tela ao coletar
func adicionar_item_na_tela(id_do_item: String, textura: Texture2D):
	if textura == null:
		print("Aviso: O item foi coletado, mas ele não tem nenhuma textura definida no Inspector!")
		return
		
	# Criamos um nó de imagem (TextureRect) via código
	var novo_quadrado = TextureRect.new()
	novo_quadrado.name = id_do_item # Nomeamos com o ID para conseguir achar e remover depois
	novo_quadrado.texture = textura
	
	# Configurações para a imagem não esticar feio e manter um tamanho bom
	novo_quadrado.custom_minimum_size = Vector2(40, 40) # Mude para (64, 64) se quiser maior
	novo_quadrado.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	novo_quadrado.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Adiciona o quadrado de imagem diretamente aqui dentro
	add_child(novo_quadrado)
	print("Visual: Sprite do item '", id_do_item, "' adicionado à tela.")

# Função que remove o sprite da tela quando o item for usado/gasto
func remover_item_da_tela(id_do_item: String):
	var quadrado_para_remover = get_node_or_null(id_do_item)
	if quadrado_para_remover != null:
		quadrado_para_remover.queue_free()
		print("Visual: Sprite do item '", id_do_item, "' removido da tela.")
