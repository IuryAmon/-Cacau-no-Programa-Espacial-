extends CanvasLayer

signal puzzle_resolvido

# Coeficientes corretos da reação: 2 H2 + 1 O2 -> 2 H2O
const COEF_CORRETO := [2, 1, 2]
const COEF_MAX := 4

const ITEM_H2 := "Cilindro_de_Hidrogenio"
const ITEM_O2 := "Cilindro_Oxigenio"

const TIMELINE_DICA_EQUACAO_DOBRADA := "cientista_dica_equacao_dobrada"
const TIMELINE_DICA_BALANCEAMENTO := "cientista_dica_balanceamento"

const TXT_TITULO_FASE1 := "PLANTA DO FOGUETE
INSTALE O COMBUSTÍVEL E O COMBURENTE NOS ENCAIXES"
const TXT_TITULO_FASE2 := "CILINDROS INSTALADOS!
BALANCEIE A REAÇÃO PARA INICIAR A COMBUSTÃO"
const TXT_TITULO_FASE3 := "IGNIÇÃO! A COMBUSTÃO DO HIDROGÊNIO LIBEROU ENERGIA!"

const FONTE_EQUACAO := preload("res://assets/fonts/ari-w9500-display.ttf")

var peca_arrastando: Control = null
var offset_arrasto: Vector2  = Vector2.ZERO
var origem_arrasto: String   = ""

var fase:         int  = 1
var h2_colocado:  bool = false
var o2_colocado:  bool = false
var travado:      bool = false
var aguardando_fechamento: bool = false
var mostrando_dialogo_cientista: bool = false
var _tween_prompt_acesso: Tween = null
# [H2, O2, H2O] — 0 pode significar "ainda não escolhido" (mostra "?") ou
# um valor zerado de propósito pelo jogador (mostra "0"), diferenciado por 'tocado'
var coeficientes := [0, 0, 0]
var tocado := [false, false, false]

var pos_inicial_h2:   Vector2 = Vector2.ZERO
var pos_inicial_o2:   Vector2 = Vector2.ZERO
var pos_foguete_base: Vector2 = Vector2.ZERO
var textura_h2:       Texture2D = null
var textura_o2:       Texture2D = null
var textura_h2o:      Texture2D = null
var textura_painel_vermelha: Texture2D = null
var textura_painel_azul:     Texture2D = null

@onready var root_control:    Control        = $RootControl
@onready var titulo:          Label          = $RootControl/Titulo
@onready var painel_grande:   TextureRect    = $RootControl/PainelGrande
@onready var foguete:         TextureRect    = $RootControl/Foguete
@onready var fogo:            CPUParticles2D = $RootControl/FogoFoguete
@onready var cover_h2:        Panel          = $RootControl/CoverH2
@onready var cover_o2:        Panel          = $RootControl/CoverO2
@onready var grupo_tray:      Control        = $RootControl/GrupoTray
@onready var peca_h2:         TextureRect    = $RootControl/GrupoTray/PecaH2
@onready var peca_o2:         TextureRect    = $RootControl/GrupoTray/PecaO2
@onready var grupo_equacao:   Control        = $RootControl/GrupoEquacao
@onready var painel_equacao:  Panel          = $RootControl/GrupoEquacao/EquacaoPanel
@onready var linha_equacao:   HBoxContainer  = $RootControl/GrupoEquacao/EquacaoPanel/PainelEquacaoEscrita/LinhaEquacao
@onready var botao_mais_h2:   Panel          = $RootControl/GrupoEquacao/EquacaoPanel/BotaoMaisH2
@onready var botao_menos_h2:  Panel          = $RootControl/GrupoEquacao/EquacaoPanel/BotaoMenosH2
@onready var botao_mais_o2:   Panel          = $RootControl/GrupoEquacao/EquacaoPanel/BotaoMaisO2
@onready var botao_menos_o2:  Panel          = $RootControl/GrupoEquacao/EquacaoPanel/BotaoMenosO2
@onready var botao_mais_h2o:  Panel          = $RootControl/GrupoEquacao/EquacaoPanel/BotaoMaisH2O
@onready var botao_menos_h2o: Panel          = $RootControl/GrupoEquacao/EquacaoPanel/BotaoMenosH2O
@onready var moleculas_h2:    Control        = $RootControl/GrupoEquacao/EquacaoPanel/MoleculasH2
@onready var moleculas_o2:    Control        = $RootControl/GrupoEquacao/EquacaoPanel/MoleculasO2
@onready var moleculas_h2o:   Control        = $RootControl/GrupoEquacao/EquacaoPanel/MoleculasH2O
@onready var label_reagentes_titulo: Label   = $RootControl/GrupoEquacao/EquacaoPanel/LabelReagentesTitulo
@onready var label_reagentes_valor:  RichTextLabel = $RootControl/GrupoEquacao/EquacaoPanel/LabelReagentesValor
@onready var label_produtos_titulo:  Label   = $RootControl/GrupoEquacao/EquacaoPanel/LabelProdutosTitulo
@onready var label_produtos_valor:   RichTextLabel = $RootControl/GrupoEquacao/EquacaoPanel/LabelProdutosValor
@onready var linha_dica_ignicao: HBoxContainer = $RootControl/GrupoEquacao/EquacaoPanel/LinhaDicaIgnicao
@onready var botao_ignicao:   Panel          = $RootControl/GrupoEquacao/EquacaoPanel/BotaoIgnicao
@onready var label_liberar_acesso: Label     = $RootControl/GrupoEquacao/EquacaoPanel/LabelLiberarAcesso
@onready var audio_sucesso:   AudioStreamPlayer = $AudioSucesso
@onready var audio_erro:      AudioStreamPlayer = $AudioErro
@onready var audio_colocar:   AudioStreamPlayer = $AudioColocar
@onready var audio_ignicao:   AudioStreamPlayer = $AudioIgnicao
@onready var audio_drag:      AudioStreamPlayer = $AudioDrag
@onready var audio_pop:       AudioStreamPlayer = $AudioPop

func _ready():
	hide()
	set_process(false)
	var folha := load("res://assets/puzzle combustão do hidrogênio/atomos H2 O2 H2O.png")
	var atlas_h2 := AtlasTexture.new()
	atlas_h2.atlas = folha
	atlas_h2.region = Rect2(11, 11, 49, 45)
	textura_h2 = atlas_h2
	var atlas_o2 := AtlasTexture.new()
	atlas_o2.atlas = folha
	atlas_o2.region = Rect2(74, 1, 73, 75)
	textura_o2 = atlas_o2
	var atlas_h2o := AtlasTexture.new()
	atlas_h2o.atlas = folha
	atlas_h2o.region = Rect2(31, 86, 71, 60)
	textura_h2o = atlas_h2o

	textura_painel_vermelha = painel_grande.texture
	var folha_azul := load("res://assets/puzzle combustão do hidrogênio/UI do puzzle azul.png")
	var atlas_painel_azul := AtlasTexture.new()
	atlas_painel_azul.atlas = folha_azul
	atlas_painel_azul.region = Rect2(327, 0, 567, 492)
	textura_painel_azul = atlas_painel_azul

	await get_tree().process_frame
	pos_inicial_h2   = peca_h2.global_position
	pos_inicial_o2   = peca_o2.global_position
	pos_foguete_base = foguete.position

func abrir_puzzle():
	show()
	Interacao.marcar_tela_aberta(self, true)
	set_process(true)
	fase         = 1
	travado      = false
	h2_colocado  = false
	o2_colocado  = false
	coeficientes = [0, 0, 0]
	tocado       = [false, false, false]
	peca_arrastando = null
	aguardando_fechamento = false
	mostrando_dialogo_cientista = false
	if _tween_prompt_acesso:
		_tween_prompt_acesso.kill()
		_tween_prompt_acesso = null
	label_liberar_acesso.hide()
	label_liberar_acesso.scale = Vector2.ONE
	label_liberar_acesso.modulate = Color(1, 1, 1, 1)
	botao_ignicao.show()

	titulo.text = TXT_TITULO_FASE1
	foguete.position = pos_foguete_base
	fogo.emitting = false
	painel_grande.texture = textura_painel_vermelha

	if Inventario.tem_item(ITEM_H2):
		peca_h2.show()
		peca_h2.global_position = pos_inicial_h2
	else:
		peca_h2.hide()

	if Inventario.tem_item(ITEM_O2):
		peca_o2.show()
		peca_o2.global_position = pos_inicial_o2
	else:
		peca_o2.hide()

	for cover in [cover_h2, cover_o2]:
		cover.show()
		cover.modulate = Color.WHITE

	grupo_tray.show()
	grupo_equacao.hide()
	linha_dica_ignicao.hide()
	_atualizar_equacao()

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = false
	get_tree().paused = true

func fechar_puzzle(resolvido: bool):
	hide()
	Interacao.marcar_tela_aberta(self, false)
	set_process(false)
	peca_arrastando = null
	fogo.emitting = false
	audio_sucesso.stop()
	audio_erro.stop()
	audio_colocar.stop()
	audio_ignicao.stop()
	get_tree().paused = false
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = true
	if resolvido:
		audio_sucesso.play()
		puzzle_resolvido.emit()

func _process(_delta: float):
	if peca_arrastando:
		peca_arrastando.global_position = get_viewport().get_mouse_position() - offset_arrasto

func _input(event: InputEvent):
	if not visible or mostrando_dialogo_cientista:
		return
	get_viewport().set_input_as_handled()
	# A tela está por cima de tudo: o E que fecha o puzzle não pode sobrar para
	# o receptor que está logo atrás dela.
	if event.is_action_pressed(Interacao.ACAO):
		Interacao.consumir()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if fase == 1:
				_iniciar_arrasto(event.position)
			elif fase == 2:
				_clicar_fase2(event.position)
		else:
			_soltar_peca(event.position)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_L:
			# DEBUG: resolve o puzzle instantaneamente para agilizar testes
			fechar_puzzle(true)
			return
		if aguardando_fechamento and event.keycode in [KEY_ESCAPE, KEY_E, KEY_SPACE, KEY_ENTER]:
			fechar_puzzle(true)
		elif not travado and event.keycode == KEY_ESCAPE:
			fechar_puzzle(false)

# ------------------------- FASE 1: DRAG AND DROP -------------------------

func _iniciar_arrasto(mouse_pos: Vector2):
	if travado:
		return
	if not h2_colocado and peca_h2.visible and peca_h2.get_global_rect().has_point(mouse_pos):
		peca_arrastando = peca_h2
		offset_arrasto  = mouse_pos - peca_h2.global_position
		origem_arrasto  = "h2"
		grupo_tray.move_child(peca_h2, -1)
		audio_drag.play()
		return
	if not o2_colocado and peca_o2.visible and peca_o2.get_global_rect().has_point(mouse_pos):
		peca_arrastando = peca_o2
		offset_arrasto  = mouse_pos - peca_o2.global_position
		origem_arrasto  = "o2"
		grupo_tray.move_child(peca_o2, -1)
		audio_drag.play()
		return

func _soltar_peca(mouse_pos: Vector2):
	if not peca_arrastando:
		return
	var peca   = peca_arrastando
	var origem = origem_arrasto
	peca_arrastando = null
	origem_arrasto  = ""

	var zona_h2 = cover_h2.get_global_rect().grow(30)
	var zona_o2 = cover_o2.get_global_rect().grow(30)

	match origem:
		"h2":
			if zona_h2.has_point(mouse_pos):
				_encaixar_cilindro(peca, cover_h2)
				h2_colocado = true
				_verificar_fase1()
			elif zona_o2.has_point(mouse_pos):
				# Encaixe errado: o hidrogênio vai no encaixe de cima
				audio_erro.play()
				_rejeitar(peca, pos_inicial_h2)
			else:
				_animar_para(peca, pos_inicial_h2)
				_tocar_som_solto()
		"o2":
			if zona_o2.has_point(mouse_pos):
				_encaixar_cilindro(peca, cover_o2)
				o2_colocado = true
				_verificar_fase1()
			elif zona_h2.has_point(mouse_pos):
				audio_erro.play()
				_rejeitar(peca, pos_inicial_o2)
			else:
				_animar_para(peca, pos_inicial_o2)
				_tocar_som_solto()

# Som de "soltar" genérico (reaproveita o som de drag), usado quando nenhum
# outro som (colocar, erro, sucesso...) já está tocando para esse solte.
func _tocar_som_solto() -> void:
	if not (audio_colocar.playing or audio_erro.playing or audio_sucesso.playing or audio_ignicao.playing):
		audio_drag.play()

func _encaixar_cilindro(peca: Control, cover: Panel):
	peca.hide()
	audio_colocar.play()
	# O encaixe vazio some, revelando o cilindro desenhado na planta do foguete
	var tween = create_tween()
	tween.tween_property(cover, "modulate:a", 0.0, 0.35)
	tween.tween_callback(cover.hide)

func _verificar_fase1():
	if h2_colocado and o2_colocado:
		fase = 2
		_ir_para_fase2()

func _ir_para_fase2():
	titulo.text = TXT_TITULO_FASE2
	await get_tree().create_timer(0.8).timeout
	if not visible or fase != 2:
		return
	grupo_tray.hide()
	grupo_equacao.show()
	painel_equacao.pivot_offset = painel_equacao.size / 2.0
	painel_equacao.scale = Vector2(0.7, 0.7)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(painel_equacao, "scale", Vector2.ONE, 0.35)
	_atualizar_equacao()

	await tween.finished
	if visible and fase == 2:
		_falar_cientista(TIMELINE_DICA_BALANCEAMENTO)

# ------------------------- FASE 2: BALANCEAMENTO -------------------------

func _clicar_fase2(mouse_pos: Vector2):
	if travado:
		return
	var botoes_mais  = [botao_mais_h2, botao_mais_o2, botao_mais_h2o]
	var botoes_menos = [botao_menos_h2, botao_menos_o2, botao_menos_h2o]
	for i in botoes_mais.size():
		if botoes_mais[i].get_global_rect().has_point(mouse_pos):
			_alterar_coeficiente(i, 1, botoes_mais[i])
			return
		if botoes_menos[i].get_global_rect().has_point(mouse_pos):
			_alterar_coeficiente(i, -1, botoes_menos[i])
			return
	if botao_ignicao.get_global_rect().has_point(mouse_pos):
		_verificar_equacao()

func _alterar_coeficiente(i: int, delta: int, alvo_pop: Control):
	var atual = coeficientes[i] + delta
	if atual > COEF_MAX:
		atual = 0
	elif atual < 0:
		atual = COEF_MAX
	coeficientes[i] = atual
	tocado[i] = true
	_pop(alvo_pop)
	_tocar_seta(alvo_pop)
	_atualizar_equacao(i)

func _tocar_seta(botao: Control) -> void:
	var seta = botao.get_node_or_null("LabelBotao")
	if seta and seta is AnimatedSprite2D:
		seta.frame = 0
		seta.play("default")

# 'index_alterado' indica qual coeficiente mudou (0=H2, 1=O2, 2=H2O), para que
# o pop de entrada das moléculas apareça só no conjunto que realmente mudou.
# -1 (padrão) reconstrói os três conjuntos, usado na abertura da fase 2.
func _atualizar_equacao(index_alterado: int = -1):
	if index_alterado == -1 or index_alterado == 0:
		_popular_moleculas(moleculas_h2, "h2", coeficientes[0])
	if index_alterado == -1 or index_alterado == 1:
		_popular_moleculas(moleculas_o2, "o2", coeficientes[1])
	if index_alterado == -1 or index_alterado == 2:
		_popular_moleculas(moleculas_h2o, "h2o", coeficientes[2])

	var coef_h2_txt  = str(coeficientes[0]) if tocado[0] else "?"
	var coef_o2_txt  = str(coeficientes[1]) if tocado[1] else "?"
	var coef_h2o_txt = str(coeficientes[2]) if tocado[2] else "?"

	# Contagem de átomos em cada lado da equação
	var reag_h = 2 * coeficientes[0]
	var reag_o = 2 * coeficientes[1]
	var prod_h = 2 * coeficientes[2]
	var prod_o = coeficientes[2]

	var amarelo := Color(1, 0.85, 0)
	# H e O ficam verdes de forma independente: cada um só depende de bater
	# a contagem dos dois lados, mesmo que o outro elemento ainda esteja errado.
	var h_bate = tocado[0] and tocado[2] and reag_h == prod_h
	var o_bate = tocado[1] and tocado[2] and reag_o == prod_o
	var cor_h = Color.GREEN if h_bate else amarelo
	var cor_o = Color.GREEN if o_bate else amarelo

	var reag_h_txt = str(reag_h) if tocado[0] else "?"
	var reag_o_txt = str(reag_o) if tocado[1] else "?"
	var prod_h_txt = str(prod_h) if tocado[2] else "?"
	var prod_o_txt = str(prod_o) if tocado[2] else "?"

	label_reagentes_valor.text = _bbcode_valor_atomos(
		reag_h_txt, cor_h,
		reag_o_txt, cor_o,
	)
	label_produtos_valor.text = _bbcode_valor_atomos(
		prod_h_txt, cor_h,
		prod_o_txt, cor_o,
	)

	var todos_definidos = tocado.all(func(t): return t)
	var cor := amarelo
	if todos_definidos:
		cor = Color.GREEN if (reag_h == prod_h and reag_o == prod_o) else Color(1, 0.35, 0.3)
	_reconstruir_equacao_escrita(coef_h2_txt, coef_o2_txt, coef_h2o_txt, cor)
	label_reagentes_titulo.add_theme_color_override("font_color", cor)
	label_produtos_titulo.add_theme_color_override("font_color", cor)

func _bbcode_valor_atomos(h_txt: String, cor_h: Color, o_txt: String, cor_o: Color) -> String:
	return "[color=#%s]H = %s[/color]    [color=#%s]O = %s[/color]" % [
		cor_h.to_html(false), h_txt, cor_o.to_html(false), o_txt,
	]

# Monta "N H2 + N O2 -> N H2O + ENERGIA" com os números "2" em subscrito de verdade
# (menores e rebaixados), já que o BBCode do RichTextLabel não tem tag de subscrito.
func _reconstruir_equacao_escrita(coef_h2_txt: String, coef_o2_txt: String, coef_h2o_txt: String, cor: Color):
	for filho in linha_equacao.get_children():
		filho.free()
	_add_texto_sub(linha_equacao, coef_h2_txt + " H", false, cor, 33, 11)
	_add_texto_sub(linha_equacao, "2", true, cor, 33, 11)
	_add_texto_sub(linha_equacao, "  +  " + coef_o2_txt + " O", false, cor, 33, 11)
	_add_texto_sub(linha_equacao, "2", true, cor, 33, 11)
	_add_texto_sub(linha_equacao, "   →   " + coef_h2o_txt + " H", false, cor, 33, 11)
	_add_texto_sub(linha_equacao, "2", true, cor, 33, 11)
	_add_texto_sub(linha_equacao, "O  +  ENERGIA", false, cor, 33, 11)

func _add_texto_sub(container: Control, texto: String, subscrito: bool, cor: Color, tamanho_normal: int, tamanho_sub: int):
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_theme_font_override("font", FONTE_EQUACAO)
	lbl.add_theme_font_size_override("font_size", tamanho_sub if subscrito else tamanho_normal)
	lbl.add_theme_color_override("font_color", cor)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_END if subscrito else Control.SIZE_SHRINK_CENTER
	container.add_child(lbl)

func _verificar_equacao():
	if coeficientes.has(0):
		audio_erro.play()
		_shake(botao_ignicao)
		return

	if coeficientes == COEF_CORRETO:
		_iniciar_ignicao()
		return

	# Balanceada quimicamente (H e O batem dos dois lados), mas não está
	# representada com os menores números inteiros possíveis (ex.: 4/2/4).
	var balanceada = (2 * coeficientes[0] == 2 * coeficientes[2]) \
		and (2 * coeficientes[1] == coeficientes[2])
	if balanceada:
		_falar_cientista(TIMELINE_DICA_EQUACAO_DOBRADA)
		return

	audio_erro.play()
	_shake(painel_equacao)

func _falar_cientista(timeline: String):
	mostrando_dialogo_cientista = true
	# Faz o autoload do Dialogic (e seus subsistemas) processar mesmo com a
	# árvore pausada, para o world1 continuar pausado durante a fala em vez
	# de despausar tudo (como era feito antes com 'get_tree().paused = false').
	Dialogic.process_mode = Node.PROCESS_MODE_ALWAYS
	Dialogic.timeline_ended.connect(_on_fala_cientista_terminou, CONNECT_ONE_SHOT)
	var layout_dialogic = Dialogic.start(timeline)
	if layout_dialogic:
		# O puzzle desenha no CanvasLayer 10 — sem isso o diálogo (layer padrão 1)
		# fica escondido atrás dele e os cliques nem chegam a avançar a fala.
		layout_dialogic.set("layer", 20)
		layout_dialogic.process_mode = Node.PROCESS_MODE_ALWAYS

func _on_fala_cientista_terminou():
	mostrando_dialogo_cientista = false

# ------------------------- FASE 3: IGNIÇÃO -------------------------

func _iniciar_ignicao():
	travado = true
	fase = 3
	titulo.text = TXT_TITULO_FASE3
	botao_ignicao.hide()
	_reconstruir_equacao_escrita(str(COEF_CORRETO[0]), str(COEF_CORRETO[1]), str(COEF_CORRETO[2]), Color.GREEN)

	await get_tree().create_timer(1.0).timeout
	if not visible:
		return
	fogo.emitting = true
	painel_grande.texture = textura_painel_azul
	audio_ignicao.play()
	_tremer_foguete()

	await get_tree().create_timer(3.2).timeout
	if not visible:
		return
	aguardando_fechamento = true
	_mostrar_prompt_liberar_acesso()

func _mostrar_prompt_liberar_acesso():
	label_liberar_acesso.pivot_offset = label_liberar_acesso.size / 2.0
	label_liberar_acesso.modulate = Color(1, 1, 1, 0)
	label_liberar_acesso.scale = Vector2(0.6, 0.6)
	label_liberar_acesso.show()

	if _tween_prompt_acesso:
		_tween_prompt_acesso.kill()

	var entrada := create_tween()
	entrada.set_parallel(true)
	entrada.tween_property(label_liberar_acesso, "modulate:a", 1.0, 0.35)
	entrada.tween_property(label_liberar_acesso, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrada.chain().tween_callback(_iniciar_pulso_prompt_acesso)

func _iniciar_pulso_prompt_acesso():
	_tween_prompt_acesso = create_tween()
	_tween_prompt_acesso.set_loops()
	_tween_prompt_acesso.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_prompt_acesso.tween_property(label_liberar_acesso, "scale", Vector2(1.07, 1.07), 0.55)
	_tween_prompt_acesso.tween_property(label_liberar_acesso, "scale", Vector2.ONE, 0.55)

func _tremer_foguete():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	for i in range(16):
		var deslocamento = Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 1.0))
		tween.tween_property(foguete, "position", pos_foguete_base + deslocamento, 0.06)
	tween.tween_property(foguete, "position", pos_foguete_base, 0.06)

# ------------------------- MOLÉCULAS DA EQUAÇÃO -------------------------

func _criar_molecula(parent: Control, pos: Vector2, tamanho: Vector2, textura: Texture2D, index: int = 0):
	var sprite := TextureRect.new()
	sprite.texture = textura
	sprite.position = pos
	sprite.size = tamanho
	sprite.pivot_offset = tamanho / 2.0
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.scale = Vector2.ZERO
	sprite.rotation = deg_to_rad(randf_range(-6.0, 6.0))
	parent.add_child(sprite)

	# Pop elástico de entrada, em cascata (cada molécula entra um pouco depois da anterior)
	var tween_entrada := create_tween()
	tween_entrada.tween_interval(index * 0.03)
	tween_entrada.tween_callback(audio_pop.play)
	tween_entrada.tween_property(sprite, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Balancinho contínuo e sutil pra dar vida às moléculas depois que aparecem
	var duracao_bob := randf_range(0.55, 0.75)
	var tween_idle := create_tween()
	tween_idle.tween_interval(index * 0.03 + 0.35)
	tween_idle.set_loops()
	tween_idle.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_idle.tween_property(sprite, "position:y", pos.y - 3.0, duracao_bob)
	tween_idle.tween_property(sprite, "position:y", pos.y, duracao_bob)

func _popular_moleculas(container: Control, tipo: String, quantidade: int):
	for filho in container.get_children():
		filho.free()
	if quantidade <= 0:
		return

	var tamanho: Vector2 = Vector2(24.0, 20.0) if tipo == "h2o" else Vector2(18.0, 18.0)
	var textura: Texture2D = textura_h2
	match tipo:
		"o2":
			textura = textura_o2
		"h2o":
			textura = textura_h2o
	var gap := 16.0

	var colunas = 1 if quantidade == 1 else 2
	var linhas  = ceili(float(quantidade) / colunas)
	var tamanho_grade = Vector2(
		colunas * tamanho.x + (colunas - 1) * gap,
		linhas * tamanho.y + (linhas - 1) * gap
	)
	var origem_grade = (container.size - tamanho_grade) / 2.0

	for i in quantidade:
		var col = i % colunas
		@warning_ignore("integer_division")
		var row = i / colunas
		var origem = origem_grade + Vector2(col * (tamanho.x + gap), row * (tamanho.y + gap))
		_criar_molecula(container, origem, tamanho, textura, i)

# ------------------------- ANIMAÇÕES DE APOIO -------------------------

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
	tween.tween_property(peca, "global_position", destino, 0.2).set_ease(Tween.EASE_OUT)

func _pop(caixa: Control):
	caixa.pivot_offset = caixa.size / 2.0
	var tween = create_tween()
	tween.tween_property(caixa, "scale", Vector2(1.18, 1.18), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(caixa, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	audio_pop.play()

func _shake(alvo: Control):
	var origem := alvo.position
	var tween  := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(alvo, "position", origem + Vector2(6, 0),  0.05)
	tween.tween_property(alvo, "position", origem + Vector2(-6, 0), 0.05)
	tween.tween_property(alvo, "position", origem + Vector2(5, 0),  0.04)
	tween.tween_property(alvo, "position", origem + Vector2(-5, 0), 0.04)
	tween.tween_property(alvo, "position", origem, 0.03)
