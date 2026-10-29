extends Node

# Teste da SUBIDA da Torre de Gases (fase2_torre_interior.tscn), salto por
# salto, com a Cacau controlada de verdade (as teclas entram pelo Input):
#
#   godot --headless --path . res://tools/teste_subida_torre.tscn
#
# É a prova de que a torre fecha: do chão do térreo até a porta do telhado,
# cada passo da subida desenhada (o primeiro degrau com pulo + jato, as vigas
# com pulo e pulo duplo, as plataformas que caem, a corrente de válvulas, a
# plataforma móvel...) é feito com a física da Cacau (pulo 94 px, pulo duplo,
# jato da mochila). As armadilhas saem antes (espinhos, serras, torretas,
# morcegos, chamas, laser e vapor): aqui se mede só se dá para chegar, não se
# dá para sobreviver.
#
# Cada passo diz para onde ela vai (o meio da plataforma e o topo dela) e com
# quais movimentos; um "piloto" aperta esquerda/direita para chegar ao meio do
# alvo, como quem joga. Passo que falha é anotado, e ela é posta no alvo para o
# teste seguir medindo os outros.

const C := 32.0
const ANDARES := 8

var _falhas := 0
var _player: CharacterBody2D
var _ferramentas: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	get_tree().current_scene = null
	_rodar()


func _rodar() -> void:
	EstadoMundo.revelou_dr_chico = true
	FerramentasHUD.apresentar_ferramentas = false
	Progresso._habilidades["mochila"] = true
	get_tree().change_scene_to_file(MissaoNitrogenio.CENA_TORRE)
	for i in 600:
		await get_tree().process_frame
		var cena := get_tree().current_scene
		if cena and cena.scene_file_path == MissaoNitrogenio.CENA_TORRE and cena.is_node_ready():
			break
	await _segundos(0.6)
	var torre := get_tree().current_scene
	_player = torre.get_node("Player") as CharacterBody2D
	_ferramentas = _player.get_node("Ferramentas")
	_tirar_armadilhas(torre)
	await _quadros(3)
	_player.max_health = 99
	_player.current_health = 99

	print("\n--- A SUBIDA ---")
	_por_no(18.0 * C, 16)
	await _segundos(0.4)
	# Térreo.
	await _passo("térreo: o primeiro degrau (pulo + jato)", 23.0 * C, _topo(0, 8),
		{"de_x": 20.5 * C, "jato": Vector2.UP, "jato_em": 0.1})
	await _passo("térreo: degrau -> viga (pulo duplo)", 26.0 * C, _topo(0, 12), {"duplo": true})
	await _passo("térreo: viga -> bloquinho do buraco", 28.0 * C, _topo(0, 16), {"duplo": true})
	await _passo("térreo -> andar 1 (pelo buraco)", 21.5 * C, _topo(1, 0), {"duplo": true, "subir_antes": true})
	# Andar 1: espinhos.
	await _passo("andar 1: viga 1", 17.0 * C, _topo(1, 2), {})
	await _passo("andar 1: viga 2", 11.5 * C, _topo(1, 4), {})
	await _passo("andar 1: viga 3", 5.0 * C, _topo(1, 6), {})
	await _passo("andar 1: viga 4 (volta)", 11.5 * C, _topo(1, 10), {"duplo": true})
	await _passo("andar 1: viga 5 (embaixo do buraco; pode passar direto para o bloquinho)", 6.0 * C, _topo(1, 14),
		{"duplo": true, "ou_acima": true})
	await _passo("andar 1: bloquinho do buraco", 6.0 * C, _topo(1, 16), {})
	await _passo("andar 1 -> andar 2", 11.0 * C, _topo(2, 0), {"duplo": true, "subir_antes": true})
	# Andar 2: a chaminé de serras.
	await _passo("andar 2: entra na chaminé (por baixo do pilar)", 27.5 * C, _topo(2, 0), {"andar": true})
	await _passo("andar 2: chaminé 1", 30.5 * C, _topo(2, 2), {})
	await _passo("andar 2: chaminé 2", 27.0 * C, _topo(2, 6), {"duplo": true})
	await _passo("andar 2: chaminé 3", 30.5 * C, _topo(2, 10), {"duplo": true})
	await _passo("andar 2: chaminé 4", 27.0 * C, _topo(2, 14), {"duplo": true})
	await _passo("andar 2: chaminé 5", 30.5 * C, _topo(2, 16), {})
	await _passo("andar 2 -> andar 3", 23.0 * C, _topo(3, 0), {"duplo": true, "subir_antes": true})
	# Andar 3: as plataformas que caem e as válvulas.
	await _passo("andar 3: queda 1", 15.5 * C, _topo(3, 2), {})
	await _passo("andar 3: queda 2", 9.5 * C, _topo(3, 4), {})
	await _passo("andar 3: queda 3", 15.5 * C, _topo(3, 6), {})
	await _passo("andar 3: queda 4", 21.5 * C, _topo(3, 8), {})
	await _passo("andar 3: queda 5", 27.5 * C, _topo(3, 10), {})
	await _passo("andar 3: jato, válvula, jato, válvula... até a viga", 4.5 * C, _topo(3, 13),
		{"corrente": true, "duplo": true, "limite": 4.0})
	await _passo("andar 3 -> andar 4 (pulo + jato)", 10.5 * C, _topo(4, 0),
		{"jato": Vector2.UP, "jato_em": 0.1, "duplo": true, "subir_antes": true})
	# Andar 4: os morcegos.
	await _passo("andar 4: patamar da direita", 26.0 * C, _topo(4, 4), {"de_x": 21.0 * C, "duplo": true})
	await _passo("andar 4: viga do meio", 16.0 * C, _topo(4, 8), {"duplo": true})
	await _passo("andar 4: patamar da esquerda", 5.0 * C, _topo(4, 12), {"duplo": true})
	await _passo("andar 4: viga do buraco", 15.0 * C, _topo(4, 16), {"de_x": 8.0 * C, "duplo": true})
	await _passo("andar 4 -> andar 5", 21.0 * C, _topo(5, 0), {"duplo": true, "subir_antes": true})
	# Andar 5: as torretas.
	await _passo("andar 5: viga 1", 25.5 * C, _topo(5, 2), {})
	await _passo("andar 5: viga 2", 19.0 * C, _topo(5, 6), {"duplo": true})
	await _passo("andar 5: viga 3", 26.0 * C, _topo(5, 10), {"duplo": true})
	await _passo("andar 5: viga 4", 14.0 * C, _topo(5, 12), {"duplo": true})
	await _passo("andar 5: bloquinho do buraco", 8.0 * C, _topo(5, 16), {"de_x": 12.5 * C, "duplo": true})
	await _passo("andar 5 -> andar 6", 12.3 * C, _topo(6, 0), {"duplo": true, "subir_antes": true})
	await _passo("andar 6: viga 1", 15.5 * C, _topo(6, 2), {})
	# Andar 6: fogo e vapor (sem o vapor: a travessia com ele é do teste_fase2).
	await _passo("andar 6: viga 2", 22.0 * C, _topo(6, 6), {"duplo": true})
	await _passo("andar 6: patamar da direita", 29.0 * C, _topo(6, 8), {})
	await _passo("andar 6: viga de cima", 18.5 * C, _topo(6, 13), {"duplo": true})
	await _passo("andar 6: viga do buraco", 14.0 * C, _topo(6, 17), {"de_x": 17.0 * C, "duplo": true})
	await _passo("andar 6 -> andar 7", 19.5 * C, _topo(7, 0), {"duplo": true, "subir_antes": true})
	# Andar 7: o topo.
	await _passo("andar 7: viga 1", 29.0 * C, _topo(7, 2), {"de_x": 25.0 * C})
	await _passo("andar 7: viga 2", 29.0 * C, _topo(7, 6), {"duplo": true})
	await _passo_na_plataforma_movel(torre)
	var porta := torre.get_node("Andares/Andar7_Topo/PortaTelhado") as Area2D
	_checar(porta.overlaps_body(_player), "no patamar, na frente da porta do telhado")

	FerramentasHUD.apresentar_ferramentas = true
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


# ─────────────────────────────────────────────────────────────
# OS PASSOS
# ─────────────────────────────────────────────────────────────

## y do topo de uma superfície "r" células acima do piso do andar k.
func _topo(k: int, r: int) -> float:
	return (16 - 20 * k - r) * C


func _por_no(x: float, fileira: int) -> void:
	_player.global_position = Vector2(x, fileira * C - 36.0)
	_player.velocity = Vector2.ZERO


## Um passo da subida. Opções:
##   duplo        o segundo pulo no alto do primeiro
##   jato         direção do jato (a mochila), "jato_em" segundos depois do pulo
##   subir_antes  só anda para o lado depois de passar da altura do alvo
##                (para sair por um buraco de laje sem bater a cabeça)
##   corrente     a corrente de válvulas: jato sempre que ele estiver de volta
##   andar        sem pulo: só anda até lá
func _passo(nome: String, alvo_x: float, alvo_y: float, op: Dictionary) -> void:
	await _ate_pousar()
	await _quadros(2)
	# "de_x": antes do pulo, anda até ali (a beirada de onde quem joga pularia).
	if op.has("de_x"):
		var de: float = op["de_x"]
		var andou := 0.0
		while absf(de - _player.global_position.x) > 6.0 and andou < 3.0:
			_direcao(signf(de - _player.global_position.x))
			await get_tree().physics_frame
			andou += get_physics_process_delta_time()
		_direcao(0.0)
		await _quadros(3)
	var limite: float = op.get("limite", 3.0)
	var t := 0.0
	var no_ar := false
	var pulou_duas := false
	var jatou := false
	var jatos := 0
	if not op.get("andar", false):
		await _toque(["jump"])
	while t < limite:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var pe := _player.global_position.y + 36.0
		if not _player.is_on_floor():
			no_ar = true
		# O piloto: para o meio do alvo (ou só para cima, se tem de sair por um buraco).
		var dx := alvo_x - _player.global_position.x
		var pode_andar: bool = not op.get("subir_antes", false) or pe < alvo_y - 4.0
		_direcao(signf(dx) if absf(dx) > 6.0 and pode_andar else 0.0)
		if op.has("jato") and not jatou and t >= op.get("jato_em", 0.12):
			jatou = true
			await _jato(op["jato"])
		if op.get("corrente", false) and no_ar and not _ferramentas.player.ferramenta_controla_movimento \
				and _ferramentas._dash_disponivel and jatos < 6 and (_player.velocity.y >= -40.0 or jatos > 0):
			jatos += 1
			var para := Vector2(signf(dx), 0.0)
			if pe > alvo_y - 10.0 and absf(dx) < 260.0:
				para = Vector2(signf(dx), -1.0).normalized()
			await _jato(para)
		if op.get("duplo", false) and not pulou_duas and no_ar and _player.velocity.y >= -20.0 \
				and not _player.ferramenta_controla_movimento:
			pulou_duas = true
			await _toque(["jump"])
		if op.get("andar", false) and absf(dx) <= 6.0:
			break
		if no_ar and _player.is_on_floor():
			break
	_direcao(0.0)
	await _quadros(2)
	var pe_final := _player.global_position.y + 36.0
	var chegou := _player.is_on_floor() and absf(pe_final - alvo_y) < 6.0
	# "ou_acima": passar do alvo e pousar mais alto também vale.
	if op.get("ou_acima", false) and _player.is_on_floor() and pe_final <= alvo_y + 6.0:
		chegou = true
	_checar(chegou, "%s (pé em %.0f, alvo %.0f; x %.0f, alvo %.0f)" % [nome, pe_final, alvo_y,
		_player.global_position.x, alvo_x])
	if not chegou:
		_player.global_position = Vector2(alvo_x, alvo_y - 36.0)
		_player.velocity = Vector2.ZERO
		await _segundos(0.3)


## A plataforma móvel do último andar: espera ela encostar na viga, sobe, vai
## nela até a ponta da esquerda (sem pular: tem espinhos em cima) e salta para o
## patamar da porta.
func _passo_na_plataforma_movel(torre: Node) -> void:
	var plataforma := torre.get_node("Andares/Andar7_Topo/PlataformaMovel") as Node2D
	await _esperar(func() -> bool: return plataforma.global_position.x > 22.5 * C, 12.0)
	await _passo("andar 7: sobe na plataforma móvel", 24.0 * C, _topo(7, 8), {})
	await _esperar(func() -> bool: return plataforma.global_position.x < 14.0 * C, 12.0)
	var pe := _player.global_position.y + 36.0
	_checar(absf(pe - _topo(7, 8)) < 6.0, "   foi levada até a ponta da esquerda sem cair")
	await _passo("andar 7: salta para o patamar da porta", 6.0 * C, _topo(7, 10), {})


# ─────────────────────────────────────────────────────────────
# AS TECLAS
# ─────────────────────────────────────────────────────────────

func _direcao(lado: float) -> void:
	if lado < 0.0:
		Input.action_press("ui_left")
		Input.action_release("ui_right")
	elif lado > 0.0:
		Input.action_press("ui_right")
		Input.action_release("ui_left")
	else:
		Input.action_release("ui_left")
		Input.action_release("ui_right")


func _toque(acoes: Array) -> void:
	for a in acoes:
		Input.action_press(a)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for a in acoes:
		Input.action_release(a)


## O jato numa direção (as setas apertadas junto com o Shift).
func _jato(dir: Vector2) -> void:
	var acoes := ["dash"]
	if dir.x < -0.1:
		acoes.append("ui_left")
	elif dir.x > 0.1:
		acoes.append("ui_right")
	if dir.y < -0.1:
		acoes.append("ui_up")
	Input.action_release("ui_left")
	Input.action_release("ui_right")
	await _toque(acoes)


func _ate_pousar() -> void:
	await _esperar(func() -> bool: return _player.is_on_floor() and not _player.ferramenta_controla_movimento, 3.0)


# ─────────────────────────────────────────────────────────────

func _tirar_armadilhas(torre: Node) -> void:
	for no in torre.find_children("*", "", true, false):
		if no is EspinhosLaser or no is TorretaLaser or no is Morcego or no is Chama \
				or no is LaserContinuo or no is CorrenteVapor:
			no.queue_free()


func _esperar(condicao: Callable, limite: float) -> void:
	var t := 0.0
	while t < limite and not condicao.call():
		await get_tree().process_frame
		t += get_process_delta_time()


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _segundos(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1
