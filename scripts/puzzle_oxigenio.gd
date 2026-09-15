extends CanvasLayer

signal puzzle_resolvido

const MAX_K          := 2
const MAX_L          := 6
const ORBIT_RADIUS_K := 125.0
const ORBIT_RADIUS_L := 220.0
const ORBIT_SPEED_K  := 1.8
const ORBIT_SPEED_L  := 1.0
const ZONE_RADIUS_K  := 145.0
const ZONE_RADIUS_L  := 245.0

var peca_arrastando: Control   = null
var offset_arrasto: Vector2    = Vector2.ZERO
var origem_arrasto: String     = ""  # "spawn", "k" ou "l"

var electrons_k: Array         = []
var electrons_l: Array         = []
var angles_k: Array            = []
var angles_l: Array            = []
var electrons_disponiveis: Array = []

var nucleus_center: Vector2    = Vector2.ZERO
var pecas_eletron: Array       = []
var pos_spawn: Vector2         = Vector2.ZERO
var travado:       bool        = false

var painel_mat: ShaderMaterial
var _tween_prompt_gaiola: Tween = null

@onready var root_control: Control            = $RootControl
@onready var zona_nucleo: Control             = $RootControl/ZonaNucleo
@onready var painel: TextureRect              = $RootControl/Painel
@onready var label_status_k: Label            = $RootControl/LabelStatusK
@onready var label_status_l: Label            = $RootControl/LabelStatusL
@onready var label_abrir_gaiola: Label        = $RootControl/LabelAbrirGaiola
@onready var audio_sucesso: AudioStreamPlayer = $AudioSucesso
@onready var audio_erro: AudioStreamPlayer    = $AudioErro
@onready var audio_drag: AudioStreamPlayer    = $AudioDrag
@onready var audio_pop: AudioStreamPlayer     = $AudioPop

func _ready():
	hide()
	set_process(false)
	painel_mat = ShaderMaterial.new()
	painel_mat.shader = load("res://shaders/painel_red_to_green.gdshader")
	painel.material = painel_mat
	for i in range(1, 9):
		var peca = root_control.get_node_or_null("PecaEletron%d" % i)
		if peca:
			pecas_eletron.append(peca)
	await get_tree().process_frame
	if pecas_eletron.size() > 0:
		pos_spawn = pecas_eletron[0].global_position


func abrir_puzzle():
	show()
	Interacao.marcar_tela_aberta(self, true)
	set_process(true)
	painel_mat.set_shader_parameter("progress", 0.0)
	travado = false
	if _tween_prompt_gaiola:
		_tween_prompt_gaiola.kill()
		_tween_prompt_gaiola = null
	label_abrir_gaiola.hide()
	label_abrir_gaiola.scale = Vector2.ONE
	label_abrir_gaiola.modulate = Color(1, 1, 1, 1)
	for lbl in [label_status_k, label_status_l]:
		lbl.scale = Vector2.ONE
	electrons_k.clear()
	electrons_l.clear()
	angles_k.clear()
	angles_l.clear()
	electrons_disponiveis = pecas_eletron.duplicate()
	for peca in pecas_eletron:
		peca.visible = false
		peca.global_position = pos_spawn
	_mostrar_spawn()
	nucleus_center = zona_nucleo.global_position + zona_nucleo.size / 2.0
	_atualizar_camadas()
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = false

func fechar_puzzle(resolvido: bool):
	hide()
	Interacao.marcar_tela_aberta(self, false)
	set_process(false)
	peca_arrastando = null
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = true
	if resolvido:
		puzzle_resolvido.emit()

func _mostrar_spawn():
	for peca in electrons_disponiveis:
		peca.visible = false
	if electrons_disponiveis.size() > 0:
		var prox = electrons_disponiveis[0]
		prox.global_position = pos_spawn
		prox.visible = true

func _process(delta: float):
	if peca_arrastando:
		peca_arrastando.global_position = get_viewport().get_mouse_position() - offset_arrasto

	for i in range(electrons_k.size()):
		angles_k[i] += ORBIT_SPEED_K * delta
		var peca: Control = electrons_k[i]
		peca.global_position = nucleus_center \
			+ Vector2(cos(angles_k[i]), sin(angles_k[i])) * ORBIT_RADIUS_K \
			- peca.size / 2.0

	for i in range(electrons_l.size()):
		angles_l[i] += ORBIT_SPEED_L * delta
		var peca: Control = electrons_l[i]
		peca.global_position = nucleus_center \
			+ Vector2(cos(angles_l[i]), sin(angles_l[i])) * ORBIT_RADIUS_L \
			- peca.size / 2.0

func _input(event: InputEvent):
	if not visible:
		return
	get_viewport().set_input_as_handled()
	# A tela está por cima de tudo: o E que fecha o puzzle não pode sobrar para
	# a gaiola/receptor que está logo atrás dela.
	if event.is_action_pressed(Interacao.ACAO):
		Interacao.consumir()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_iniciar_arrasto(event.position)
		else:
			_soltar_peca(event.position)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_L:
			# DEBUG: resolve o puzzle instantaneamente para agilizar testes
			fechar_puzzle(true)
			return
		if travado and event.keycode in [KEY_ESCAPE, KEY_E, KEY_SPACE, KEY_ENTER]:
			fechar_puzzle(true)
		elif not travado and event.keycode == KEY_ESCAPE:
			fechar_puzzle(false)

func _iniciar_arrasto(mouse_pos: Vector2):
	if travado:
		return
	# Elétron no spawn
	if electrons_disponiveis.size() > 0:
		var peca = electrons_disponiveis[0]
		if peca.get_global_rect().has_point(mouse_pos):
			peca_arrastando = peca
			offset_arrasto  = mouse_pos - peca.global_position
			origem_arrasto  = "spawn"
			root_control.move_child(peca, -1)
			audio_drag.play()
			return

	# Elétron na camada K
	for peca in electrons_k:
		if peca.get_global_rect().has_point(mouse_pos):
			_remover_de_shell(peca, electrons_k, angles_k)
			peca_arrastando = peca
			offset_arrasto  = mouse_pos - peca.global_position
			origem_arrasto  = "k"
			root_control.move_child(peca, -1)
			audio_drag.play()
			_atualizar_camadas()
			return

	# Elétron na camada L
	for peca in electrons_l:
		if peca.get_global_rect().has_point(mouse_pos):
			_remover_de_shell(peca, electrons_l, angles_l)
			peca_arrastando = peca
			offset_arrasto  = mouse_pos - peca.global_position
			origem_arrasto  = "l"
			root_control.move_child(peca, -1)
			audio_drag.play()
			_atualizar_camadas()
			return

func _remover_de_shell(peca: Control, shell: Array, angles: Array):
	var idx = shell.find(peca)
	if idx == -1:
		return
	shell.remove_at(idx)
	angles.remove_at(idx)
	_redistribuir(angles)

func _soltar_peca(mouse_pos: Vector2):
	if not peca_arrastando:
		return
	var peca       = peca_arrastando
	var foi_spawn  = (origem_arrasto == "spawn")
	peca_arrastando = null
	origem_arrasto  = ""

	var dist  = mouse_pos.distance_to(nucleus_center)
	var angle = atan2(mouse_pos.y - nucleus_center.y, mouse_pos.x - nucleus_center.x)
	var colocado := false

	if dist < ZONE_RADIUS_K:
		if foi_spawn:
			electrons_disponiveis.remove_at(0)
		electrons_k.append(peca)
		angles_k.append(angle)
		_redistribuir(angles_k)
		colocado = true
	elif dist < ZONE_RADIUS_L:
		if foi_spawn:
			electrons_disponiveis.remove_at(0)
		electrons_l.append(peca)
		angles_l.append(angle)
		_redistribuir(angles_l)
		colocado = true

	if colocado:
		_mostrar_spawn()
		_verificar_vitoria(dist < ZONE_RADIUS_K, dist >= ZONE_RADIUS_K)
	else:
		if foi_spawn:
			# Volta ao spawn animado
			var tween = create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(peca, "global_position", pos_spawn, 0.15)
		else:
			# Veio de camada: entra no final da fila do spawn
			electrons_disponiveis.push_back(peca)
			_mostrar_spawn()
		_atualizar_camadas()

	_tocar_som_solto()

# Som de "soltar" genérico (reaproveita o som de drag), usado quando nenhum
# outro som (erro, sucesso...) já está tocando para esse solte.
func _tocar_som_solto() -> void:
	if not (audio_erro.playing or audio_sucesso.playing):
		audio_drag.play()

func _redistribuir(angles: Array):
	var n = angles.size()
	for i in range(n):
		angles[i] = i * TAU / n

func _verificar_vitoria(foi_k: bool = false, foi_l: bool = false):
	var k_excedeu = foi_k and electrons_k.size() > MAX_K
	var l_excedeu = foi_l and electrons_l.size() > MAX_L
	_atualizar_camadas(k_excedeu, l_excedeu)
	if foi_k and electrons_k.size() == MAX_K:
		_celebrar_label(label_status_k)
	if foi_l and electrons_l.size() == MAX_L:
		_celebrar_label(label_status_l)
	if electrons_k.size() == MAX_K and electrons_l.size() == MAX_L:
		travado = true
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_method(
			func(v: float): painel_mat.set_shader_parameter("progress", v),
			0.0, 1.0, 0.6
		)
		if audio_sucesso:
			audio_sucesso.play()
		_mostrar_prompt_abrir_gaiola()

func _atualizar_camadas(k_excedeu: bool = false, l_excedeu: bool = false):
	var k = electrons_k.size()
	var l = electrons_l.size()
	var vermelho := Color(0.45, 0.01, 0.01, 1)
	var cor_k = Color.GREEN if k == MAX_K else (vermelho if k > MAX_K else Color(1, 0.85, 0, 1))
	var cor_l = Color.GREEN if l == MAX_L else (vermelho if l > MAX_L else Color(1, 0.85, 0, 1))
	if label_status_k:
		label_status_k.text = "CAMADA K:  %d e-" % k
		label_status_k.add_theme_color_override("font_color", cor_k)
	if label_status_l:
		label_status_l.text = "CAMADA L:  %d e-" % l
		label_status_l.add_theme_color_override("font_color", cor_l)
	if k_excedeu and label_status_k:
		if audio_erro:
			audio_erro.play()
		_shake(label_status_k)
	if l_excedeu and label_status_l:
		if not k_excedeu and audio_erro:
			audio_erro.play()
		_shake(label_status_l)

func _mostrar_prompt_abrir_gaiola():
	label_abrir_gaiola.pivot_offset = label_abrir_gaiola.size / 2.0
	label_abrir_gaiola.modulate = Color(1, 1, 1, 0)
	label_abrir_gaiola.scale = Vector2(0.6, 0.6)
	label_abrir_gaiola.show()

	if _tween_prompt_gaiola:
		_tween_prompt_gaiola.kill()

	var entrada := create_tween()
	entrada.set_parallel(true)
	entrada.tween_property(label_abrir_gaiola, "modulate:a", 1.0, 0.35)
	entrada.tween_property(label_abrir_gaiola, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrada.chain().tween_callback(_iniciar_pulso_prompt_gaiola)

func _iniciar_pulso_prompt_gaiola():
	_tween_prompt_gaiola = create_tween()
	_tween_prompt_gaiola.set_loops()
	_tween_prompt_gaiola.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_prompt_gaiola.tween_property(label_abrir_gaiola, "scale", Vector2(1.07, 1.07), 0.55)
	_tween_prompt_gaiola.tween_property(label_abrir_gaiola, "scale", Vector2.ONE, 0.55)

func _celebrar_label(label: Label):
	label.pivot_offset = label.size / 2.0
	audio_pop.play()
	var t1 := create_tween()
	t1.tween_property(label, "scale", Vector2(1.35, 1.35), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t1.tween_property(label, "scale", Vector2(1.0,  1.0),  0.3 ).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var t2 := create_tween()
	t2.tween_property(label, "theme_override_colors/font_color", Color(0.8, 1.0, 0.8, 1.0), 0.06)
	t2.tween_property(label, "theme_override_colors/font_color", Color.GREEN,                0.35)

func _shake(label: Label):
	var origem := label.position
	var tween  := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "position", origem + Vector2(6, 0),  0.05)
	tween.tween_property(label, "position", origem + Vector2(-6, 0), 0.05)
	tween.tween_property(label, "position", origem + Vector2(5, 0),  0.04)
	tween.tween_property(label, "position", origem + Vector2(-5, 0), 0.04)
	tween.tween_property(label, "position", origem + Vector2(3, 0),  0.03)
	tween.tween_property(label, "position", origem,                  0.03)
