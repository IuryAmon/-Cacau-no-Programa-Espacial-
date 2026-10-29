extends CanvasLayer

# --- AUTOLOAD "ModoDev": O MODO DE DESENVOLVEDOR ---
#
# Para andar pelo jogo inteiro sem precisar jogar tudo de novo. Só existe no
# jogo rodado pelo editor (build de debug), como as outras teclas de teste (K,
# O, P, Ç): no jogo exportado as teclas não fazem nada.
#
#   F1   liga/desliga o modo. Ligando, a Cacau ganha todas as ferramentas e já
#        sai voando. Desligar não tira as ferramentas.
#   V    voar/andar (só com o modo ligado).
#   F2   menu de cenas: escolhe uma e vai direto para ela (vale mesmo com o
#        modo desligado). Setas/WASD escolhem, Enter vai, Esc ou F2 fecham.
#
# COM O MODO LIGADO
#   * nada machuca: nem dano, nem queda no buraco (ela volta a voar) — ver
#     player.gd;
#   * nenhuma trava segura: porta de fase sem a ferramenta (porta_fase.gd),
#     elevador parado (elevador_fase.gd), saída barrada (passagem_de_cena.gd)
#     e as travas da rua da fase 2 com a amostra na mão (fase2_torre.gd);
#   * a amostra gelada da fase 2 não esquenta (contagem_da_amostra.gd).
#
# VOANDO
#   * WASD/setas em 8 direções, Shift mais rápido. Ela atravessa parede, chão,
#     porta de metal e barreira: a colisão dela com o mundo some, mas as áreas
#     (portas, elevadores, gatilhos) continuam vendo ela;
#   * a câmera se solta dos limites da cena e vai aonde ela for; a roda do
#     mouse (ou - e +) afasta e aproxima (camera_2d.gd);
#   * porta: E na frente dela, porque o W é subir (porta_fase.gd e
#     porta_simulador.gd). Elevador: E, como sempre;
#   * V de novo: ela volta a cair e a andar de onde estiver.

## As cenas do menu (F2), na ordem do jogo.
const CENAS := [
	["Mundo 1 (prólogo)", "res://scenes/world1.tscn"],
	["Laboratório", "res://scenes/laboratório_(world_2).tscn"],
	["Simulador", "res://scenes/simulador_(world_3).tscn"],
	["Fase 1 · Oficina", "res://scenes/fases/fase1_oficina.tscn"],
	["Fase 1 · Corredor do pátio", "res://scenes/fases/corredor_patio.tscn"],
	["Fase 1 · Pátio", "res://scenes/fases/fase1_2_exterior.tscn"],
	["Fase 2 · Corredor da torre", "res://scenes/fases/corredor_torre.tscn"],
	["Fase 2 · Rua", "res://scenes/fases/fase2_torre.tscn"],
	["Fase 2 · Sala do compressor", "res://scenes/fases/fase2_sala_compressor.tscn"],
	["Fase 2 · Torre (escada)", "res://scenes/fases/fase2_torre_interior.tscn"],
	["Fase 2 · Telhado", "res://scenes/fases/fase2_telhado.tscn"],
	["Fase 2 · Sala de destilação", "res://scenes/fases/fase2_sala_destilacao.tscn"],
	["Fase 3 · Subsolo", "res://scenes/fases/fase3_subsolo.tscn"],
	["Final · Torre de lançamento", "res://scenes/fases/fase_final.tscn"],
]

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

## Quanto cada toque da roda (ou do - e +) muda o zoom, e até onde vai.
const PASSO_DO_ZOOM := 1.15
const ZOOM_MINIMO := 0.15
const ZOOM_MAXIMO := 4.0

const COR_FUNDO := Color(0.05, 0.06, 0.12, 0.88)
const COR_DESTAQUE := Color(1.0, 0.78, 0.25)

## O modo está ligado.
var ativo: bool = false
## A Cacau está voando (só com o modo ligado).
var voando: bool = false

var _faixa: Label
## O menu de cenas: um CenterContainer do tamanho da tela, com o painel no meio.
var _menu: CenterContainer
var _lista: VBoxContainer
## Foi o menu que pausou o jogo (então é ele que despausa ao fechar).
var _menu_pausou: bool = false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar_faixa()
	_montar_menu()
	_atualizar_faixa()


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	var tecla := event as InputEventKey
	if tecla != null:
		if not tecla.pressed or tecla.echo:
			return
		match tecla.physical_keycode:
			KEY_F1:
				alternar()
			KEY_F2:
				if _menu.visible:
					fechar_menu()
				else:
					abrir_menu()
			KEY_ESCAPE:
				if not _menu.visible:
					return
				fechar_menu()
			KEY_V:
				if not ativo or _menu.visible:
					return
				voar(not voando)
			KEY_MINUS, KEY_KP_SUBTRACT:
				if not voando:
					return
				_mudar_zoom(1.0 / PASSO_DO_ZOOM)
			KEY_EQUAL, KEY_KP_ADD:
				if not voando:
					return
				_mudar_zoom(PASSO_DO_ZOOM)
			_:
				return
		get_viewport().set_input_as_handled()
		return

	var botao := event as InputEventMouseButton
	if botao != null and botao.pressed and voando and not _menu.visible:
		if botao.button_index == MOUSE_BUTTON_WHEEL_UP:
			_mudar_zoom(PASSO_DO_ZOOM)
		elif botao.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_mudar_zoom(1.0 / PASSO_DO_ZOOM)


# ─────────────────────────────────────────────────────────────
# LIGAR, DESLIGAR E VOAR
# ─────────────────────────────────────────────────────────────

func alternar() -> void:
	ativo = not ativo
	voando = ativo
	if ativo:
		var pegas := dar_todas_as_ferramentas()
		print("DEBUG [ModoDev]: ligado. Ferramentas novas -> ", pegas if not pegas.is_empty() else "nenhuma (já tinha todas)")
	else:
		print("DEBUG [ModoDev]: desligado.")
	_atualizar_faixa()


## Liga ou desliga o voo livre. A personagem (player.gd) e a câmera
## (camera_2d.gd) acompanham sozinhas no quadro seguinte.
func voar(sim: bool) -> void:
	voando = sim and ativo
	_atualizar_faixa()


## Todas as ferramentas de uma vez, direto nos equipamentos, sem ficha de
## coleta nem tutorial. Devolve as que eram novas. (A tecla P usa também.)
func dar_todas_as_ferramentas() -> PackedStringArray:
	var pegas := PackedStringArray()
	FerramentasHUD.apresentar_ferramentas = false
	for habilidade in Progresso.HABILIDADES:
		if not Progresso.tem_habilidade(habilidade):
			Progresso.dar_habilidade(habilidade)
			pegas.append(habilidade)
	FerramentasHUD.apresentar_ferramentas = true
	return pegas


func _mudar_zoom(fator: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var z := clampf(camera.zoom.x * fator, ZOOM_MINIMO, ZOOM_MAXIMO)
	camera.zoom = Vector2(z, z)


# ─────────────────────────────────────────────────────────────
# A FAIXA (o aviso no alto da tela)
# ─────────────────────────────────────────────────────────────

func _montar_faixa() -> void:
	_faixa = Label.new()
	_faixa.name = "Faixa"
	_faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faixa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_faixa.add_theme_font_override("font", FONTE)
	_faixa.add_theme_font_size_override("font_size", 15)
	_faixa.add_theme_color_override("font_color", COR_DESTAQUE)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = COR_FUNDO
	fundo.set_corner_radius_all(4)
	fundo.content_margin_left = 12
	fundo.content_margin_right = 12
	fundo.content_margin_top = 4
	fundo.content_margin_bottom = 4
	_faixa.add_theme_stylebox_override("normal", fundo)
	_faixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_faixa)


func _atualizar_faixa() -> void:
	_faixa.visible = ativo
	if not ativo:
		return
	if voando:
		_faixa.text = "MODO DEV · VOANDO   WASD voa · Shift rápido · roda/−+ zoom · E porta · V andar · F2 cenas · F1 sair"
	else:
		_faixa.text = "MODO DEV · ANDANDO   V voar · F2 cenas · F1 sair"
	# Recentraliza no meio do topo: o texto mudou de largura.
	_faixa.reset_size()
	_faixa.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 8)


# ─────────────────────────────────────────────────────────────
# O MENU DE CENAS (F2)
# ─────────────────────────────────────────────────────────────

func _montar_menu() -> void:
	_menu = CenterContainer.new()
	_menu.name = "MenuDeCenas"
	_menu.visible = false
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)

	var painel := PanelContainer.new()
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = COR_FUNDO
	fundo.set_corner_radius_all(6)
	fundo.set_border_width_all(2)
	fundo.border_color = COR_DESTAQUE
	fundo.set_content_margin_all(16)
	painel.add_theme_stylebox_override("panel", fundo)
	_menu.add_child(painel)

	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 4)
	painel.add_child(_lista)

	var titulo := Label.new()
	titulo.text = "IR PARA A CENA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_override("font", FONTE)
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", COR_DESTAQUE)
	_lista.add_child(titulo)

	for cena in CENAS:
		var botao := Button.new()
		botao.text = cena[0]
		botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
		botao.custom_minimum_size = Vector2(360, 0)
		botao.add_theme_font_override("font", FONTE)
		botao.add_theme_font_size_override("font_size", 17)
		botao.set_meta("caminho", cena[1])
		botao.pressed.connect(_ir_para.bind(cena[1]))
		_lista.add_child(botao)

	var dica := Label.new()
	dica.text = "↑↓ escolhe · Enter vai · Esc fecha"
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.add_theme_font_override("font", FONTE)
	dica.add_theme_font_size_override("font_size", 13)
	dica.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_lista.add_child(dica)


func abrir_menu() -> void:
	if _menu.visible:
		return
	_menu.visible = true
	_menu_pausou = not get_tree().paused
	get_tree().paused = true
	# O foco começa na cena aberta (ou na primeira, se ela não está na lista).
	var atual := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	var foco: Button = null
	for filho in _lista.get_children():
		if filho is Button:
			if foco == null or filho.get_meta("caminho") == atual:
				foco = filho
	if foco:
		foco.grab_focus()


func fechar_menu() -> void:
	if not _menu.visible:
		return
	_menu.visible = false
	var com_foco := get_viewport().gui_get_focus_owner()
	if com_foco and _menu.is_ancestor_of(com_foco):
		com_foco.release_focus()
	if _menu_pausou:
		get_tree().paused = false
	_menu_pausou = false


func _ir_para(caminho: String) -> void:
	fechar_menu()
	get_tree().paused = false
	# Chega no ponto de nascimento da cena, não numa porta.
	Progresso.spawn_tag = ""
	print("DEBUG [ModoDev]: indo para ", caminho)
	FadeTela.trocar_cena(get_tree().current_scene, caminho, 0.3)
