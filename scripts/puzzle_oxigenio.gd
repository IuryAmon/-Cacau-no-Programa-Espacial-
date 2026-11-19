extends CanvasLayer

signal puzzle_resolvido

# --- O CIENTISTA EXPLICA (ver scripts/ui/explicacao_no_puzzle.gd) ---
#
# Na primeira vez, o cientista explica a eletrosfera: o Z da caixinha (8) dá os
# prótons e, no átomo neutro, os elétrons; eles ficam em camadas, a K (a de
# dentro, até 2) enche primeiro e o resto vai para a L (até 8). No passo da
# camada K, só o elétron da vez responde e só a K aceita. A primeira fala
# oferece "Já sei montar" para pular. No fim (ou ao pular) a conversa anota a
# nota "eletrosfera" no caderno, e daí em diante o puzzle abre sem explicação.

const NOTA := "eletrosfera"
# Durante as falas, o holofote fica longe dos contadores e das letras K e L
# lá de baixo: o nome de quem fala, em cima da caixa de diálogo, cobre os
# dois. Os anéis são marcados pelo alto ("anel_k", "anel_l"), e os
# contadores acendem no passo da pessoa, quando o diálogo já sumiu.
const ROTEIRO := [
	{
		"fala": "cientista_oxigenio_1",
		"sinais": {
			"z": {"mostrar": ["caixa"], "enfase": ["caixa_z"]},
			"camadas": {"mostrar": ["atomo"], "enfase": ["anel_k", "anel_l"]},
			"camada_k": {"mostrar": ["camada_k"], "enfase": ["anel_k"]},
		},
		"acao": "eletron_k",
		"meta": "k_cheia",
	},
	{
		"fala": "cientista_oxigenio_2",
		"mostrar": ["camada_k"],
		"sinais": {
			"camada_l": {"mostrar": ["atomo"], "enfase": ["anel_l"]},
			"faltam": {"mostrar": ["caixa", "camada_k"], "enfase": ["caixa_z"]},
		},
		"meta": "resolvido",
	},
	{
		"fala": "cientista_oxigenio_3",
		"mostrar": ["atomo"],
	},
]
## A caixa de ênfase em cima de cada anel (o pedaço do alto, que nada cobre).
const ANEL := Vector2(96, 30)
## Onde fica, dentro da caixinha (152 x 184), o número de cima (Z).
const CAIXA_Z := Rect2(10, 10, 38, 38)

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
## Onde está o ponteiro, lido dos eventos: o mouse de verdade ou o cursor do
## controle (que não move o mouse do sistema — ver cursor_virtual.gd).
var _ponteiro: Vector2 = Vector2.ZERO

## O holofote da explicação, por cima da tela (criado no _ready).
var destaque: DestaqueTutorial
var explicacao: ExplicacaoNoPuzzle

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
	# Controle: cursor nesta tela e as teclas dos textos viram botões. Os textos
	# moram na cena, com as marcas {fechar}/{interact} (ver BotoesControle).
	add_to_group(CursorVirtual.GRUPO)
	# A tecla do "para fechar" sai em escala 2: no texto miúdo do canto, o
	# desenho em escala 1 ficava ilegível.
	Controle.rotular($RootControl/Instrucoes, $RootControl/Instrucoes.text, 2.0)
	Controle.rotular(label_abrir_gaiola, label_abrir_gaiola.text)
	painel_mat = ShaderMaterial.new()
	painel_mat.shader = load("res://shaders/painel_red_to_green.gdshader")
	painel.material = painel_mat
	for i in range(1, 9):
		var peca = root_control.get_node_or_null("PecaEletron%d" % i)
		if peca:
			pecas_eletron.append(peca)
	destaque = DestaqueTutorial.new()
	destaque.name = "Destaque"
	destaque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(destaque)
	explicacao = ExplicacaoNoPuzzle.new(self, ROTEIRO)
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
	destaque.limpar(true)
	if not Caderno.tem_nota(NOTA):
		explicacao.comecar()

func fechar_puzzle(resolvido: bool):
	explicacao.cancelar()
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
		peca_arrastando.global_position = _ponteiro - offset_arrasto

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
	if explicacao.falando:
		# A fala do cientista está por cima: clique e teclas são dela.
		return
	get_viewport().set_input_as_handled()
	# A tela está por cima de tudo: o E que fecha o puzzle não pode sobrar para
	# a gaiola/receptor que está logo atrás dela.
	if event.is_action_pressed(Interacao.ACAO):
		Interacao.consumir()
	if event is InputEventMouse:
		_ponteiro = event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_iniciar_arrasto(event.position)
		else:
			_soltar_peca(event.position)
	if event is InputEventKey and event.pressed and event.keycode == KEY_L:
		# DEBUG: resolve o puzzle instantaneamente para agilizar testes
		fechar_puzzle(true)
		return
	if travado and _pediu_fechar(event):
		fechar_puzzle(true)
	elif not travado and _pediu_sair(event):
		fechar_puzzle(false)

## ESC/E/ESPAÇO/ENTER no teclado; △, □ e ✕ no controle (pelas ações do mapa).
func _pediu_fechar(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed \
			and event.keycode in [KEY_ESCAPE, KEY_E, KEY_SPACE, KEY_ENTER]:
		return true
	return event.is_action_pressed("fechar") or event.is_action_pressed("ui_accept") \
		or event.is_action_pressed(Interacao.ACAO)

## ESC no teclado; △ no controle (a ação "fechar").
func _pediu_sair(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		return true
	return event.is_action_pressed("fechar")

# ------------------------- CONTROLE (ver cursor_virtual.gd) -------------------------

## Os elétrons que dá para pegar (o da vez e os que já orbitam, para
## corrigir); com um na mão, um ponto de cada camada para soltar.
func alvos_do_cursor() -> Array[Rect2]:
	var alvos: Array[Rect2] = []
	if travado:
		return alvos
	# Na explicação, o passo da camada K: só o elétron da vez, e só a K.
	var so_na_k := explicacao.acao() == "eletron_k"
	if peca_arrastando:
		var raios := [ORBIT_RADIUS_K] if so_na_k else [ORBIT_RADIUS_K, ORBIT_RADIUS_L]
		for raio in raios:
			var ponto: Vector2 = nucleus_center + Vector2(0.0, -raio)
			alvos.append(Rect2(ponto - Vector2(36.0, 36.0), Vector2(72.0, 72.0)))
		return alvos
	if electrons_disponiveis.size() > 0 and electrons_disponiveis[0].visible:
		alvos.append(electrons_disponiveis[0].get_global_rect())
	if so_na_k:
		return alvos
	for peca in electrons_k + electrons_l:
		alvos.append(peca.get_global_rect())
	return alvos

func dicas_do_controle() -> Array:
	if travado:
		return [[Interacao.ACAO, "ABRIR A GAIOLA"]]
	return [
		["analogico_esquerdo", "MOVER"],
		["direcional", "ESCOLHER"],
		["cruz", "SOLTE PARA COLOCAR" if peca_arrastando else "SEGURE PARA ARRASTAR"],
		["fechar", "SAIR"],
	]

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

	# Na explicação, o passo da camada K: só o elétron da vez responde.
	if explicacao.acao() == "eletron_k":
		destaque.cutucar()
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
	# Na explicação, o passo da camada K: a L ainda não aceita.
	var so_na_k := explicacao.acao() == "eletron_k"

	if dist < ZONE_RADIUS_K:
		if foi_spawn:
			electrons_disponiveis.remove_at(0)
		electrons_k.append(peca)
		angles_k.append(angle)
		_redistribuir(angles_k)
		colocado = true
	elif dist < ZONE_RADIUS_L and not so_na_k:
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
		if so_na_k:
			destaque.cutucar()
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
	explicacao.conferir()

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


# ------------------------- A EXPLICAÇÃO (ver explicacao_no_puzzle.gd) -------------------------

## Os lugares da tela que o holofote acende, pelos nomes do ROTEIRO.
func retangulos_para(nomes: Array) -> Array[Rect2]:
	var caixa: Rect2 = $RootControl/CaixaOxigenio.get_global_rect()
	var retangulos: Array[Rect2] = []
	for nome in nomes:
		match nome:
			"caixa":
				retangulos.append(caixa)
			"caixa_z":
				retangulos.append(Rect2(caixa.position + CAIXA_Z.position, CAIXA_Z.size))
			"nucleo":
				retangulos.append(zona_nucleo.get_global_rect().grow(18))
			"camada_k":
				retangulos.append(_quadrado_em_volta(ORBIT_RADIUS_K + 18.0))
			"atomo":
				retangulos.append(_quadrado_em_volta(ORBIT_RADIUS_L + 16.0))
			"anel_k":
				retangulos.append(_alto_do_anel(ORBIT_RADIUS_K))
			"anel_l":
				retangulos.append(_alto_do_anel(ORBIT_RADIUS_L))
			"contagem_k":
				retangulos.append(ExplicacaoNoPuzzle.retangulo_do_texto(label_status_k))
			"eletron":
				# O elétron da vez, no lugar de partida, com o nome embaixo.
				var tamanho: Vector2 = pecas_eletron[0].get_global_rect().size if not pecas_eletron.is_empty() \
					else Vector2(35, 35)
				retangulos.append(Rect2(pos_spawn, tamanho)
					.merge(ExplicacaoNoPuzzle.retangulo_do_texto($RootControl/LabelEletrons)).grow(6))
			_:
				push_warning("PuzzleOxigenio: lugar \"%s\" desconhecido" % nome)
	return retangulos


## O passo pede para levar uma peça: a seta vai nela, e o lugar de soltar fica
## aceso junto.
func retangulos_da_acao(acao: String) -> Array[Rect2]:
	match acao:
		"eletron_k":
			# Sem fala na tela, o contador da K aparece inteiro: 0, 1, 2.
			return retangulos_para(["eletron", "camada_k", "contagem_k"])
	return []


func meta_cumprida(meta: String) -> bool:
	match meta:
		"k_cheia":
			return electrons_k.size() >= MAX_K
		"resolvido":
			return travado
	return false


## Um quadrado com o meio no núcleo (o holofote de uma camada).
func _quadrado_em_volta(raio: float) -> Rect2:
	return Rect2(nucleus_center - Vector2(raio, raio), Vector2(raio, raio) * 2.0)


## O pedaço de cima do anel desse raio.
func _alto_do_anel(raio: float) -> Rect2:
	return Rect2(nucleus_center + Vector2(-ANEL.x * 0.5, -raio - ANEL.y * 0.5), ANEL)
