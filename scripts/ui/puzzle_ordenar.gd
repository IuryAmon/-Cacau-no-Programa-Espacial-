class_name PuzzleOrdenar
extends CanvasLayer

# --- PUZZLE GENÉRICO DE ARRASTAR E SOLTAR ---
#
# A reutilização pedida pelo plano: o mesmo sistema de arrastar do puzzle do
# foguete, agora genérico — muda só os dados. Serve o ciclo do nitrogênio
# (estufa), a cadeia do ATP (gerador) e a checagem do purificador de LiOH
# (plataforma da cápsula). Aceita peças-distrator: elas ficam na bandeja e
# não encaixam em lugar nenhum.
#
# config:
#   titulo, subtitulo:  textos do cabeçalho
#   slots:       [{aceita: "id", rotulo: "texto apagado no slot"}]
#   separadores: ["→", "+"] — desenhados entre os slots (size() - 1 itens)
#   pecas:       [{id: "id", texto: "texto da peça"}] — inclui distratores
#   texto_vitoria: mensagem final

signal resolvido

var titulo: String = "PUZZLE"
var subtitulo: String = ""
var slots: Array = []
var separadores: Array = []
var pecas: Array = []
var texto_vitoria: String = "Resolvido!"

const TAM_SLOT := Vector2(178, 78)
const TAM_PECA := Vector2(170, 62)

var _painel: Panel = null
var _status: Label = null
var _nos_slots: Array = []
var _nos_pecas: Array = []
var _arrastando: Panel = null
var _offset_arrasto: Vector2 = Vector2.ZERO
var _preenchidos: int = 0
var _vitoria: bool = false


static func nova(dono: Node, config: Dictionary) -> PuzzleOrdenar:
	var tela := PuzzleOrdenar.new()
	for chave in config:
		tela.set(chave, config[chave])
	tela.layer = 15
	tela.process_mode = Node.PROCESS_MODE_ALWAYS
	dono.get_tree().root.add_child(tela)
	return tela


func _ready() -> void:
	_montar_ui()
	Interacao.marcar_tela_aberta(self, true)
	get_tree().paused = true
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = false


func _estilo(cor_fundo: Color, cor_borda: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor_fundo
	estilo.border_color = cor_borda
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	return estilo


func _montar_ui() -> void:
	var escurecer := ColorRect.new()
	escurecer.color = Color(0, 0, 0, 0.55)
	escurecer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(escurecer)

	_painel = Panel.new()
	_painel.add_theme_stylebox_override("panel", _estilo(Color(0.12, 0.13, 0.17), Color(0.35, 0.38, 0.45)))
	_painel.set_anchors_preset(Control.PRESET_CENTER)
	_painel.offset_left = -490
	_painel.offset_top = -280
	_painel.offset_right = 490
	_painel.offset_bottom = 280
	add_child(_painel)

	var lbl_titulo := Label.new()
	lbl_titulo.text = titulo
	lbl_titulo.add_theme_font_size_override("font_size", 24)
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_titulo.position = Vector2(0, 16)
	lbl_titulo.size = Vector2(980, 34)
	_painel.add_child(lbl_titulo)

	var lbl_sub := Label.new()
	lbl_sub.text = subtitulo
	lbl_sub.add_theme_font_size_override("font_size", 14)
	lbl_sub.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_sub.position = Vector2(60, 52)
	lbl_sub.size = Vector2(860, 44)
	_painel.add_child(lbl_sub)

	# --- FILEIRA DE SLOTS (com separadores entre eles) ---
	var largura_sep := 44.0
	var n := slots.size()
	var largura_total := n * TAM_SLOT.x + maxf(n - 1, 0) * largura_sep
	var x := (980.0 - largura_total) / 2.0
	var y_slots := 150.0

	for i in n:
		var slot := Panel.new()
		slot.add_theme_stylebox_override("panel", _estilo(Color(0.08, 0.09, 0.12), Color(0.45, 0.48, 0.55)))
		slot.position = Vector2(x, y_slots)
		slot.size = TAM_SLOT
		slot.set_meta("aceita", slots[i].get("aceita", ""))
		slot.set_meta("preenchido", false)
		_painel.add_child(slot)
		_nos_slots.append(slot)

		var rotulo := Label.new()
		rotulo.text = slots[i].get("rotulo", "?")
		rotulo.add_theme_font_size_override("font_size", 13)
		rotulo.add_theme_color_override("font_color", Color(0.45, 0.48, 0.55))
		rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rotulo.size = TAM_SLOT
		rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(rotulo)

		x += TAM_SLOT.x
		if i < n - 1:
			var sep := Label.new()
			sep.text = separadores[i] if i < separadores.size() else "→"
			sep.add_theme_font_size_override("font_size", 30)
			sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sep.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			sep.position = Vector2(x, y_slots)
			sep.size = Vector2(largura_sep, TAM_SLOT.y)
			_painel.add_child(sep)
			x += largura_sep

	# --- BANDEJA DE PEÇAS (embaralhadas, com distratores) ---
	var lista := pecas.duplicate()
	lista.shuffle()
	var por_linha := 5
	var gap := 18.0
	var y_peca := 320.0
	for i in lista.size():
		var col := i % por_linha
		@warning_ignore("integer_division")
		var linha := i / por_linha
		var na_linha: int = mini(lista.size() - linha * por_linha, por_linha)
		var largura_linha := na_linha * TAM_PECA.x + (na_linha - 1) * gap
		var x0 := (980.0 - largura_linha) / 2.0

		var peca := Panel.new()
		peca.add_theme_stylebox_override("panel", _estilo(Color(0.2, 0.32, 0.45), Color(0.5, 0.65, 0.8)))
		peca.position = Vector2(x0 + col * (TAM_PECA.x + gap), y_peca + linha * (TAM_PECA.y + 14))
		peca.size = TAM_PECA
		peca.set_meta("id", lista[i].get("id", ""))
		peca.set_meta("origem", peca.position)
		peca.set_meta("travada", false)
		_painel.add_child(peca)
		_nos_pecas.append(peca)

		var texto := Label.new()
		texto.text = lista[i].get("texto", "?")
		texto.add_theme_font_size_override("font_size", 14)
		texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto.size = TAM_PECA
		texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		peca.add_child(texto)

	_status = Label.new()
	_status.text = "Arraste as peças para os encaixes.  [ESC desiste]"
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.position = Vector2(0, 516)
	_status.size = Vector2(980, 26)
	_painel.add_child(_status)


func _process(_delta: float) -> void:
	if _arrastando:
		_arrastando.global_position = get_viewport().get_mouse_position() - _offset_arrasto


func _input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if event.is_action_pressed(Interacao.ACAO):
		Interacao.consumir()
		if _vitoria:
			_fechar(true)
			return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not _vitoria:
		_fechar(false)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pegar(event.position)
		else:
			_soltar(event.position)


func _pegar(pos: Vector2) -> void:
	if _vitoria:
		return
	# Da última para a primeira, para pegar a peça desenhada por cima.
	for i in range(_nos_pecas.size() - 1, -1, -1):
		var peca: Panel = _nos_pecas[i]
		if not peca.get_meta("travada") and peca.get_global_rect().has_point(pos):
			_arrastando = peca
			_offset_arrasto = pos - peca.global_position
			peca.move_to_front()
			return


func _soltar(pos: Vector2) -> void:
	if _arrastando == null:
		return
	var peca := _arrastando
	_arrastando = null

	for slot in _nos_slots:
		if slot.get_meta("preenchido"):
			continue
		if slot.get_global_rect().grow(16).has_point(pos):
			if slot.get_meta("aceita") == peca.get_meta("id"):
				_encaixar(peca, slot)
			else:
				_status.text = "Essa peça não encaixa aí. Olhe o rótulo do encaixe."
				_voltar(peca, true)
			return

	_voltar(peca, false)


func _encaixar(peca: Panel, slot: Panel) -> void:
	peca.set_meta("travada", true)
	slot.set_meta("preenchido", true)
	peca.add_theme_stylebox_override("panel", _estilo(Color(0.18, 0.42, 0.28), Color(0.4, 0.85, 0.55)))
	var destino := slot.global_position + (TAM_SLOT - TAM_PECA) / 2.0
	var tween := create_tween()
	tween.tween_property(peca, "global_position", destino, 0.12).set_ease(Tween.EASE_OUT)

	_preenchidos += 1
	if _preenchidos >= slots.size():
		_vitoria = true
		_status.text = texto_vitoria + "   [E para continuar]"
		_status.add_theme_color_override("font_color", Color(0.5, 0.95, 0.6))
		_status.add_theme_font_size_override("font_size", 16)


func _voltar(peca: Panel, tremer: bool) -> void:
	var origem: Vector2 = peca.get_meta("origem")
	var tween := create_tween()
	if tremer:
		var atual := peca.position
		tween.tween_property(peca, "position", atual + Vector2(7, 0), 0.04)
		tween.tween_property(peca, "position", atual + Vector2(-7, 0), 0.04)
	tween.tween_property(peca, "position", origem, 0.18).set_ease(Tween.EASE_OUT)


func _fechar(sucesso: bool) -> void:
	Interacao.marcar_tela_aberta(self, false)
	get_tree().paused = false
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = true
	if sucesso:
		resolvido.emit()
	queue_free()
