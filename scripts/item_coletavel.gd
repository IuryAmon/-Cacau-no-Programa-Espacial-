extends Area2D

@export_group("Configurações do Item")
@export var id_do_item: String = "item_padrao"
@export var nome_do_item: String = "Nome do Item"
@export var textura_do_item: Texture2D
@export_multiline var descricao_do_item: String = "Descrição do item aqui."

var jogador_na_area: bool = false

@onready var exclamacao_animada = $ExclamacaoAnimada
@onready var som_coleta = $SomColeta

func _ready():
	add_to_group("item_coletavel")

	# Já foi pego antes: não volta para o cenário quando a cena recarrega.
	# O inventário não serve de prova aqui — os receptores consomem o item ao
	# usar, e aí ele sumiria da mochila e reapareceria no chão.
	if EstadoMundo.ja_feito(self):
		queue_free()
		return

	exclamacao_animada.visible = false
	exclamacao_animada.stop()

func _process(_delta):
	# O popup aberto do inventário já é tratado como "dono do E" pelo Interacao.
	if jogador_na_area and is_visible() and Interacao.pediu():
		coletar_item()

func coletar_item():
	EstadoMundo.marcar_feito(self)

	# 1. Toca o som imediatamente
	if som_coleta and som_coleta.stream != null:
		som_coleta.play()

	# 2. Abre o popup (ainda NÃO adiciona ao inventário)
	if Inventario.tela_hud_referencia != null:
		Inventario.tela_hud_referencia.exibir_popup(nome_do_item, textura_do_item, descricao_do_item, id_do_item)

	# 3. Desativa colisões e esconde o item do cenário
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	hide()
	exclamacao_animada.visible = false

	# 4. Aguarda o som terminar antes de deletar o nó
	if som_coleta and som_coleta.stream != null:
		await som_coleta.finished

	queue_free()

func _on_body_entered(body):
	if body.name == "Player":
		jogador_na_area = true
		PopupFX.mostrar(exclamacao_animada)

func _on_body_exited(body):
	if body.name == "Player":
		jogador_na_area = false
		PopupFX.esconder(exclamacao_animada)
