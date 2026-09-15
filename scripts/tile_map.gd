extends TileMap

func _ready():
	clean_invalid_tiles()

func clean_invalid_tiles():
	print("Iniciando limpeza de tiles inválidos...")
	var layers = get_layers_count()
	var error_count = 0

	for l in range(layers):
		# Pega todas as coordenadas onde você pintou algo nesta camada
		var used_cells = get_used_cells(l)
		
		for cell in used_cells:
			var source_id = get_cell_source_id(l, cell)
			var atlas_coords = get_cell_atlas_coords(l, cell)
			
			# Acessa o recurso de Tileset
			var source = tile_set.get_source(source_id)
			
			# Se a fonte (imagem) não existe ou o tile na coordenada (x, y) não está no atlas
			if source == null or not source.has_tile(atlas_coords):
				# -1 remove a célula bugada do mapa
				set_cell(l, cell, -1)
				error_count += 1
				
	if error_count > 0:
		print("Sucesso: ", error_count, " tiles inválidos foram removidos.")
	else:
		print("Nenhum tile inválido encontrado nas camadas.")

# DICA: Se os erros persistirem no console do Editor (sem dar Play), 
# adicione '@tool' na primeira linha do script, salve, e depois remova.
