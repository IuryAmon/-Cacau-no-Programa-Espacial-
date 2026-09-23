extends SceneTree

# Confere que o bumerangue DESARMA as torretas da fase 1. Rodar com:
#   godot --headless --script res://tools/teste_torreta_bumerangue.gd
#
# Duas perguntas: as torretas da fase estão marcadas como quebráveis (senão o
# bumerangue atravessa), e o acerto na hitbox estraga mesmo a torreta.

const CENA_TORRETA := "res://scenes/fases/componentes/torreta_laser.tscn"
const CENA_FASE := "res://scenes/fases/fase1_oficina.tscn"


func _initialize() -> void:
	var falhas := 0

	# 1. Toda torreta da fase 1 tem que ser quebrável.
	var fase: PackedScene = load(CENA_FASE)
	var estado := fase.get_state()
	var vistas := 0
	for i in estado.get_node_count():
		# "Torretas" é o nó-pasta que agrupa as torretas, não uma delas.
		if not estado.get_node_name(i).begins_with("TorretaMeio"):
			continue
		vistas += 1
		var quebravel := false
		for p in estado.get_node_property_count(i):
			if estado.get_node_property_name(i, p) == "quebravel":
				quebravel = bool(estado.get_node_property_value(i, p))
		if quebravel:
			print("OK  %s é quebrável" % estado.get_node_name(i))
		else:
			print("FALHA  %s não tem quebravel = true" % estado.get_node_name(i))
			falhas += 1
	if vistas == 0:
		print("FALHA  nenhuma torreta encontrada na fase 1")
		falhas += 1

	# 2. O acerto na hitbox estraga de fato uma torreta quebrável.
	var torreta: Node2D = load(CENA_TORRETA).instantiate()
	torreta.quebravel = true
	root.add_child(torreta)
	await process_frame

	var hitbox: Area2D = torreta.get_node("Base/AreaAlvo")
	if hitbox.is_in_group("alvo_bumerangue"):
		print("OK  a hitbox continua no grupo 'alvo_bumerangue'")
	else:
		print("FALHA  hitbox fora do grupo: o bumerangue passaria batido")
		falhas += 1

	hitbox.atingir_bumerangue()
	await process_frame
	if torreta.quebrada:
		print("OK  o acerto estragou a torreta")
	else:
		print("FALHA  a torreta continuou inteira depois do acerto")
		falhas += 1
	if torreta.get_node("Base/Fumaca").emitting:
		print("OK  a carcaça está fumegando")
	else:
		print("FALHA  a fumaça não ligou")
		falhas += 1

	# 3. Torreta imortal (o padrão): o bumerangue não enxerga a hitbox.
	var intacta: Node2D = load(CENA_TORRETA).instantiate()
	root.add_child(intacta)
	await process_frame
	if intacta.get_node("Base/AreaAlvo").is_in_group("alvo_bumerangue"):
		print("FALHA  torreta imortal ainda apanha do bumerangue")
		falhas += 1
	else:
		print("OK  torreta imortal fica fora do grupo")

	print("--- %s ---" % ("TUDO OK" if falhas == 0 else "%d FALHA(S)" % falhas))
	quit(falhas)
