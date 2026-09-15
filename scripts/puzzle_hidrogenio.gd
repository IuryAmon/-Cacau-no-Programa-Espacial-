extends CanvasLayer

signal puzzle_resolvido

const ORBIT_SPEED := 2.0

var peca_arrastando: Control = null
var offset_arrasto: Vector2  = Vector2.ZERO
var origem_arrasto: String   = ""

var proton_colocado:   bool = false
var neutron_colocado:  bool = false
var eletron_colocado:  bool = false
var travado:           bool = false
var eletron_orbitando: bool = false
var angulo_eletron:   float = 0.0
var raio_orbita:      float = 0.0
var nucleus_center: Vector2 = Vector2.ZERO

var pos_inicial_proton:  Vector2 = Vector2.ZERO
var pos_inicial_neutron: Vector2 = Vector2.ZERO
var pos_inicial_eletron: Vector2 = Vector2.ZERO

var painel_mat: ShaderMaterial
var _tween_prompt_gaiola: Tween = null

@onready var root_control:   Control             = $RootControl
@onready var zona_nucleo:    Control             = $RootControl/ZonaNucleo
@onready var zona_orbita:    Control             = $RootControl/ZonaOrbita
@onready var peca_proton:    Control             = $RootControl/PecaProton
@onready var peca_neutron:   Control             = $RootControl/PecaNeutron
@onready var peca_eletron:   Control             = $RootControl/PecaEletron
@onready var label_proton:   Label               = $RootControl/LabelStatusProton
@onready var label_eletron:  Label               = $RootControl/LabelStatusEletron
@onready var label_neutron:  Label               = $RootControl/LabelStatusNeutron
@onready var painel:         TextureRect         = $RootControl/Painel
@onready var label_abrir_gaiola: Label           = $RootControl/LabelAbrirGaiola
@onready var audio_sucesso:  AudioStreamPlayer   = $AudioSucesso
@onready var audio_erro:     AudioStreamPlayer   = $AudioErro
@onready var audio_drag:     AudioStreamPlayer   = $AudioDrag
@onready var audio_pop:      AudioStreamPlayer   = $AudioPop

func _ready():
	hide()
	set_process(false)
	painel_mat = ShaderMaterial.new()
	painel_mat.shader = load("res://shaders/painel_red_to_green.gdshader")
	painel.material = painel_mat
	await get_tree().process_frame
	pos_inicial_proton  = peca_proton.global_position
	pos_inicial_neutron = peca_neutron.global_position
	pos_inicial_eletron = peca_eletron.global_position

func abrir_puzzle():
	show()
	Interacao.marcar_tela_aberta(self, true)
	set_process(true)
	proton_colocado   = false
	neutron_colocado  = false
	eletron_colocado  = false
	eletron_orbitando = false
	travado           = false
	painel_mat.set_shader_parameter("progress", 0.0)
	if _tween_prompt_gaiola:
		_tween_prompt_gaiola.kill()
		_tween_prompt_gaiola = null
	label_abrir_gaiola.hide()
	label_abrir_gaiola.scale = Vector2.ONE
	label_abrir_gaiola.modulate = Color(1, 1, 1, 1)
	for lbl in [label_proton, label_eletron, label_neutron]:
		lbl.scale = Vector2.ONE
	peca_proton.global_position  = pos_inicial_proton
	peca_neutron.global_position = pos_inicial_neutron
	peca_eletron.global_position = pos_inicial_eletron
	nucleus_center = zona_nucleo.global_position + zona_nucleo.size / 2.0
	var orbita_center = zona_orbita.global_position + zona_orbita.size / 2.0
	raio_orbita = nucleus_center.distance_to(orbita_center)
	_atualizar_labels()
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

func _process(delta: float):
	if peca_arrastando:
		peca_arrastando.global_position = get_viewport().get_mouse_position() - offset_arrasto

	if eletron_orbitando:
		angulo_eletron += ORBIT_SPEED * delta
		peca_eletron.global_position = nucleus_center \
			+ Vector2(cos(angulo_eletron), sin(angulo_eletron)) * raio_orbita \
			- peca_eletron.size / 2.0

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
	# Próton — sempre arrastável (permite remover do núcleo)
	if peca_proton.get_global_rect().has_point(mouse_pos):
		if proton_colocado:
			proton_colocado = false
			_atualizar_labels()
		peca_arrastando  = peca_proton
		offset_arrasto   = mouse_pos - peca_proton.global_position
		origem_arrasto   = "proton"
		root_control.move_child(peca_proton, -1)
		audio_drag.play()
		return

	# Nêutron — sempre arrastável; se estava no núcleo, remove
	if peca_neutron.get_global_rect().has_point(mouse_pos):
		if neutron_colocado:
			neutron_colocado = false
			_atualizar_labels()
		peca_arrastando  = peca_neutron
		offset_arrasto   = mouse_pos - peca_neutron.global_position
		origem_arrasto   = "neutron"
		root_control.move_child(peca_neutron, -1)
		audio_drag.play()
		return

	# Elétron — sempre arrastável (permite remover da órbita)
	if peca_eletron.get_global_rect().has_point(mouse_pos):
		if eletron_colocado:
			eletron_colocado  = false
			eletron_orbitando = false
			_atualizar_labels()
		peca_arrastando  = peca_eletron
		offset_arrasto   = mouse_pos - peca_eletron.global_position
		origem_arrasto   = "eletron"
		root_control.move_child(peca_eletron, -1)
		audio_drag.play()
		return

func _soltar_peca(mouse_pos: Vector2):
	if not peca_arrastando:
		return
	var peca   = peca_arrastando
	var origem = origem_arrasto
	peca_arrastando = null
	origem_arrasto  = ""

	var zona_nucleo_rect = zona_nucleo.get_global_rect().grow(30)

	match origem:
		"neutron":
			if zona_nucleo_rect.has_point(mouse_pos):
				var centro = zona_nucleo.global_position + zona_nucleo.size / 2.0 - peca.size / 2.0
				var destino = centro + Vector2(10, 8)
				_animar_para(peca, destino)
				neutron_colocado = true
				audio_erro.play()
				_atualizar_labels()
				_shake(label_neutron)
			else:
				_animar_para(peca, pos_inicial_neutron)
				_atualizar_labels()
				_verificar_vitoria()

		"proton":
			if zona_nucleo_rect.has_point(mouse_pos):
				var centro = zona_nucleo.global_position + zona_nucleo.size / 2.0 - peca.size / 2.0
				var destino = centro + Vector2(-10, -8)
				_animar_para(peca, destino)
				proton_colocado = true
				_atualizar_labels()
				_celebrar_label(label_proton)
				_verificar_vitoria()
			else:
				_animar_para(peca, pos_inicial_proton)
				_atualizar_labels()

		"eletron":
			var dist = mouse_pos.distance_to(nucleus_center)
			if not zona_nucleo_rect.has_point(mouse_pos) and dist <= raio_orbita + 50.0:
				angulo_eletron    = atan2(mouse_pos.y - nucleus_center.y, mouse_pos.x - nucleus_center.x)
				eletron_colocado  = true
				eletron_orbitando = true
				_atualizar_labels()
				_celebrar_label(label_eletron)
				_verificar_vitoria()
			else:
				_animar_para(peca, pos_inicial_eletron)
				_atualizar_labels()

	_tocar_som_solto()

# Som de "soltar" genérico (reaproveita o som de drag), usado quando nenhum
# outro som (erro, sucesso...) já está tocando para esse solte.
func _tocar_som_solto() -> void:
	if not (audio_erro.playing or audio_sucesso.playing):
		audio_drag.play()

func _animar_para(peca: Control, destino: Vector2):
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(peca, "global_position", destino, 0.15)

func _rejeitar(peca: Control, destino: Vector2):
	var start = peca.global_position
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(peca, "global_position", start + Vector2(8, 0),  0.04)
	tween.tween_property(peca, "global_position", start + Vector2(-8, 0), 0.04)
	tween.tween_property(peca, "global_position", start + Vector2(6, 0),  0.04)
	tween.tween_property(peca, "global_position", start + Vector2(-6, 0), 0.04)
	tween.tween_property(peca, "global_position", start,                  0.03)
	tween.tween_property(peca, "global_position", destino,                0.2).set_ease(Tween.EASE_OUT)

func _verificar_vitoria():
	if proton_colocado and eletron_colocado and not neutron_colocado:
		travado = true
		_atualizar_labels()
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_method(
			func(v: float): painel_mat.set_shader_parameter("progress", v),
			0.0, 1.0, 0.6
		)
		if audio_sucesso:
			audio_sucesso.play()
		_mostrar_prompt_abrir_gaiola()


func _atualizar_labels():
	var amarelo := Color(1, 0.85, 0, 1)
	var cor_p = Color.GREEN if proton_colocado  else amarelo
	var cor_e = Color.GREEN if eletron_colocado else amarelo
	if label_proton:
		label_proton.text = "PRÓTON:   %d" % (1 if proton_colocado  else 0)
		label_proton.add_theme_color_override("font_color", cor_p)
	if label_eletron:
		label_eletron.text = "ELÉTRON:  %d" % (1 if eletron_colocado else 0)
		label_eletron.add_theme_color_override("font_color", cor_e)
	if label_neutron:
		label_neutron.text = "NÊUTRON:  %d" % (1 if neutron_colocado else 0)
		label_neutron.add_theme_color_override("font_color", Color.RED if neutron_colocado else Color.GREEN)

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
