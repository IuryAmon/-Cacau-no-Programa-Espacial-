extends Node

var itens_coletados = []
var tela_hud_referencia: CanvasLayer = null
var popup_aberto: bool = false

func registrar_tela_inventario(instancia_da_tela: CanvasLayer):
	tela_hud_referencia = instancia_da_tela
	print("Cérebro: Tela de inventário conectada com sucesso!")

func adicionar_item(id_do_item: String, nome_do_item: String, textura: Texture2D, descricao: String = ""):
	if not tem_item(id_do_item):
		var dados_do_item = {
			"id": id_do_item,
			"nome": nome_do_item,
			"textura": textura,
			"descricao": descricao
		}
		itens_coletados.append(dados_do_item)
		print("Cérebro: Item guardado -> ", nome_do_item, " (ID: ", id_do_item, ")")

		if tela_hud_referencia != null:
			tela_hud_referencia.exibir_item_na_tela(id_do_item, nome_do_item, textura)
		else:
			print("Aviso: Item coletado, mas a tela InventarioHud não foi encontrada para exibir!")

func tem_item(id_do_item: String) -> bool:
	for item in itens_coletados:
		if item["id"] == id_do_item:
			return true
	return false

func remover_item(id_do_item: String):
	for item in itens_coletados:
		if item["id"] == id_do_item:
			itens_coletados.erase(item)
			print("Cérebro: Item removido -> ID: ", id_do_item)

			if tela_hud_referencia != null:
				tela_hud_referencia.remover_item_da_tela(id_do_item)
			return
