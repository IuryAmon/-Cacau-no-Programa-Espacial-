extends Area2D

# --- A CENA DO MIRANTE ---
#
# A Cacau pisa na plataforma do mirante e vê o foguete pela primeira vez. A
# parte dela — o susto, a fala, o balão de coração — é do player.gd
# (reagir_ao_avistar_foguete). Aqui fica quem DIRIGE a cena e o que vem depois
# da fala: o pôr do sol.
#
#   fala termina ──> o coração sobe (como sempre)
#                    o sol desce atrás da serra: o céu vai do dourado ao
#                    crepúsculo, o fundo e o mundo escurecem um pouco com ele,
#                    os postes dão a piscada e firmam         (Atmosfera.por_do_sol)
#                    o controle volta
#
# A Cacau fica parada do começo ao fim, e o HUD some junto: é para olhar.
#
# NÃO fica de noite aqui: a fase só escurece de leve e continua no crepúsculo
# (EstadoMundo.sol_se_pos — é assim que o world1 abre quando ela volta, e a
# cena não repete, nem se ela morrer antes de chegar ao laboratório). A noite
# cai depois, no pátio, com a fornalha queimando o carvão (ver retorta.gd).
#
# Numa cena sem Atmosfera (ou em que o sol já se pôs) nada disso acontece: a
# fala e o coração tocam como antes e o controle volta na hora.

## Segundos entre o coração aparecer e o sol começar a descer.
@export var respiro_antes_do_sol := 0.8
## Segundos olhando o crepúsculo, com o sol já posto, antes de o controle voltar.
@export var respiro_depois_do_sol := 1.2

var _disparado: bool = false

func _ready() -> void:
	# Ela já viu o foguete (nesta volta ao world1 ou antes de morrer): a cena
	# de avistar não repete.
	_disparado = EstadoMundo.revelou_dr_chico or EstadoMundo.viu_o_foguete
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _disparado:
		return
	if body.name != "Player":
		return
	_disparado = true
	if not body.has_method("reagir_ao_avistar_foguete"):
		return

	var atmosfera := Atmosfera.da_cena(self)
	if atmosfera != null and atmosfera.pode_por_o_sol():
		body.segurar_apos_o_foguete = true
		body.fala_do_foguete_terminou.connect(_por_o_sol.bind(body, atmosfera), CONNECT_ONE_SHOT)
	else:
		body.fala_do_foguete_terminou.connect(_registrar, CONNECT_ONE_SHOT)
	body.reagir_ao_avistar_foguete($CollisionShape2D)


func _registrar() -> void:
	EstadoMundo.viu_o_foguete = true


## O pôr do sol, da descida ao controle de volta.
func _por_o_sol(player: Node2D, atmosfera: Atmosfera) -> void:
	_registrar()
	var cena := get_tree().current_scene
	# Sem apagar a tela: a cortina está aqui só para tirar o HUD de cena.
	var cortina := FadeTela.criar(cena)

	# O coração ainda está no ar quando o sol começa a descer.
	await _esperar(respiro_antes_do_sol)
	cortina.esconder_huds(cena)

	await atmosfera.por_do_sol()
	await _esperar(respiro_depois_do_sol)

	cortina.restaurar_huds()
	cortina.queue_free()
	if is_instance_valid(player):
		player.segurar_apos_o_foguete = false
		player.pode_se_mover = true


## Espera em tempo de JOGO (o mesmo relógio dos tweens da cena).
func _esperar(segundos: float) -> void:
	var resta := segundos
	while resta > 0.0:
		await get_tree().process_frame
		resta -= get_process_delta_time()
