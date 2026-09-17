class_name Dosagem
extends CanvasLayer

# --- COMPONENTE DE DOSAGEM (barra com faixa-alvo) ---
#
# O mesmo componente serve os três puzzles de dosagem do plano, mudando só
# os dados:
#   retorta     -> modo "segurar": manter a agulha na faixa por alguns
#                  segundos (D aquece, A esfria; passar do limite racha)
#   sinalizador -> modo "parar": travar a agulha em movimento dentro da faixa
#   masseira    -> modo "parar" com 3 acertos (pouco S afunda, muito estilhaça)
#
# Emite terminado(sucesso, cancelado). NÃO pausa a árvore: o cenário continua
# animando atrás do painel (a fornalha pegando fogo, por exemplo). O que trava
# é só o movimento da personagem, enquanto o painel está na tela.

signal terminado(sucesso: bool, cancelado: bool)

## Quanto o painel sobe em relação ao centro da tela, para não tapar o objeto
## que está sendo operado (a fornalha, a masseira...).
const DESLOCAMENTO_VERTICAL := 130.0

## Fator de escala do painel inteiro (1.0 = tamanho original de 760x340).
const ESCALA_PAINEL := 0.8

## Ritmo do modo "segurar", em unidades da barra por segundo. Quanto menores,
## mais devagar a agulha anda — e menos a pessoa precisa martelar a tecla.
const AQUECIMENTO_D := 0.16
const RESFRIAMENTO_A := 0.20
const QUEDA_NATURAL := 0.08
const TREMOR := 0.02

## Segundos no vermelho (acima de 0.96) até a peça rachar.
const TEMPO_ATE_RACHAR := 1.6

var titulo: String = "DOSAGEM"
var modo: String = "parar"
var dica: String = ""
var rotulo_esq: String = "POUCO"
var rotulo_dir: String = "MUITO"
var faixa_centro: float = 0.62
var faixa_largura: float = 0.16
var duracao_alvo: float = 4.0
var acertos_necessarios: int = 3
var msg_falha_fraca: String = "Ficou aquém do ponto."
var msg_falha_forte: String = "Passou do ponto!"

var _agulha_valor: float = 0.1
var _agulha_direcao: float = 1.0
var _velocidade: float = 0.85
var _progresso: float = 0.0
var _tempo_superaquecido: float = 0.0
var _acertos: int = 0
var _encerrando: bool = false

var _painel: Panel = null
var _barra: Control = null
var _agulha: ColorRect = null
var _barra_progresso: ColorRect = null
var _status: Label = null


static func abrir(dono: Node, config: Dictionary) -> Dosagem:
	var tela := Dosagem.new()
	for chave in config:
		tela.set(chave, config[chave])
	tela.layer = 15
	tela.process_mode = Node.PROCESS_MODE_ALWAYS
	dono.get_tree().root.add_child(tela)
	return tela


func _ready() -> void:
	_montar_ui()
	# Controle: a barra de botões aparece (sem cursor — ver usa_cursor).
	add_to_group(CursorVirtual.GRUPO)
	Interacao.marcar_tela_aberta(self, true)
	# O mundo NÃO pausa: a fornalha continua animando atrás do painel. Só a
	# personagem é travada, para o A/D irem todos para a dosagem.
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = false


func _montar_ui() -> void:
	var escurecer := ColorRect.new()
	escurecer.color = Color(0, 0, 0, 0.3)
	escurecer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(escurecer)

	_painel = Panel.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.12, 0.13, 0.17)
	estilo.border_color = Color(0.35, 0.38, 0.45)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(10)
	_painel.add_theme_stylebox_override("panel", estilo)
	_painel.set_anchors_preset(Control.PRESET_CENTER)
	_painel.offset_left = -380
	_painel.offset_top = -170 - DESLOCAMENTO_VERTICAL
	_painel.offset_right = 380
	_painel.offset_bottom = 170 - DESLOCAMENTO_VERTICAL
	# O conteúdo interno é montado sempre no tamanho original (760x340); a
	# escala encolhe o painel inteiro em volta do próprio centro.
	_painel.pivot_offset = Vector2(380, 170)
	_painel.scale = Vector2(ESCALA_PAINEL, ESCALA_PAINEL)
	add_child(_painel)

	var lbl_titulo := Label.new()
	lbl_titulo.text = titulo
	lbl_titulo.add_theme_font_size_override("font_size", 24)
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_titulo.position = Vector2(0, 18)
	lbl_titulo.size = Vector2(760, 34)
	_painel.add_child(lbl_titulo)

	# --- BARRA COM FAIXA-ALVO ---
	_barra = Control.new()
	_barra.position = Vector2(100, 120)
	_barra.size = Vector2(560, 44)
	_painel.add_child(_barra)

	var fundo_barra := ColorRect.new()
	fundo_barra.color = Color(0.05, 0.05, 0.08)
	fundo_barra.size = _barra.size
	_barra.add_child(fundo_barra)

	var faixa := ColorRect.new()
	faixa.color = Color(0.25, 0.75, 0.35, 0.85)
	faixa.size = Vector2(560 * faixa_largura, 44)
	faixa.position = Vector2(560 * (faixa_centro - faixa_largura / 2.0), 0)
	_barra.add_child(faixa)

	_agulha = ColorRect.new()
	_agulha.color = Color.WHITE
	_agulha.size = Vector2(5, 56)
	_agulha.position = Vector2(0, -6)
	_barra.add_child(_agulha)

	var lbl_esq := Label.new()
	lbl_esq.text = rotulo_esq
	lbl_esq.add_theme_font_size_override("font_size", 13)
	lbl_esq.position = Vector2(100, 172)
	_painel.add_child(lbl_esq)

	var lbl_dir := Label.new()
	lbl_dir.text = rotulo_dir
	lbl_dir.add_theme_font_size_override("font_size", 13)
	lbl_dir.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_dir.position = Vector2(460, 172)
	lbl_dir.size = Vector2(200, 20)
	_painel.add_child(lbl_dir)

	# --- PROGRESSO (modo segurar) / ACERTOS (modo parar) ---
	if modo == "segurar":
		var fundo_prog := ColorRect.new()
		fundo_prog.color = Color(0.05, 0.05, 0.08)
		fundo_prog.position = Vector2(100, 205)
		fundo_prog.size = Vector2(560, 14)
		_painel.add_child(fundo_prog)

		_barra_progresso = ColorRect.new()
		_barra_progresso.color = Color(0.95, 0.75, 0.25)
		_barra_progresso.position = Vector2(100, 205)
		_barra_progresso.size = Vector2(0, 14)
		_painel.add_child(_barra_progresso)

	_status = Label.new()
	_status.text = ""
	_status.add_theme_font_size_override("font_size", 16)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.position = Vector2(0, 232)
	_status.size = Vector2(760, 26)
	_painel.add_child(_status)

	var lbl_dica := Label.new()
	lbl_dica.add_theme_font_size_override("font_size", 13)
	lbl_dica.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
	lbl_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_dica.position = Vector2(0, 288)
	lbl_dica.size = Vector2(760, 40)
	_painel.add_child(lbl_dica)
	# A dica pode trazer marcas {acao}: vira tecla no teclado e botão no controle.
	Controle.rotular(lbl_dica, dica if dica != "" else _dica_padrao())


func _dica_padrao() -> String:
	if modo == "segurar":
		return "Segure {ui_right:D} para aquecer e {ui_left:A} para esfriar. Mantenha a agulha na faixa verde.  [{ui_cancel} desiste]"
	return "Aperte {interact} para travar a agulha dentro da faixa verde (%d acertos).  [{ui_cancel} desiste]" % acertos_necessarios


# --- CONTROLE (ver cursor_virtual.gd) ---

## O controle opera a dosagem direto: nada de cursor, só a barra de botões.
func usa_cursor() -> bool:
	return false


func dicas_do_controle() -> Array:
	if modo == "segurar":
		return [["ui_right", "AQUECER"], ["ui_left", "ESFRIAR"], ["ui_cancel", "DESISTIR"]]
	return [[Interacao.ACAO, "TRAVAR A AGULHA"], ["ui_cancel", "DESISTIR"]]


func _process(delta: float) -> void:
	if _encerrando:
		return

	# ESC no teclado, ○ no controle.
	if Input.is_key_pressed(KEY_ESCAPE) or Input.is_action_pressed("ui_cancel"):
		_fechar(false, true)
		return

	# A personagem fica presa durante todo o painel. Isto é reafirmado a cada
	# frame porque largar a pose do maçarico devolveria o controle sozinho.
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = false

	if modo == "segurar":
		_processo_segurar(delta)
	else:
		_processo_parar(delta)

	_agulha.position.x = 560.0 * _agulha_valor - 2.5


func _na_faixa() -> bool:
	return absf(_agulha_valor - faixa_centro) <= faixa_largura / 2.0


func _processo_segurar(delta: float) -> void:
	# D alimenta o forno, A abafa; sem input a temperatura cai sozinha.
	var aquecimento := -QUEDA_NATURAL
	if Input.is_action_pressed("ui_right"):
		aquecimento = AQUECIMENTO_D
	elif Input.is_action_pressed("ui_left"):
		aquecimento = -RESFRIAMENTO_A
	aquecimento += randf_range(-TREMOR, TREMOR)
	_agulha_valor = clampf(_agulha_valor + aquecimento * delta, 0.0, 1.0)

	if _na_faixa():
		_progresso += delta / duracao_alvo
		_status.text = "Na faixa... %d%%" % int(_progresso * 100)
		_status.add_theme_color_override("font_color", Color(0.5, 0.95, 0.6))
	else:
		_progresso = maxf(_progresso - delta * 0.10, 0.0)
		_status.text = "Fora da faixa" if _agulha_valor < faixa_centro else "Quente demais!"
		_status.add_theme_color_override("font_color", Color(0.95, 0.7, 0.4))

	if _barra_progresso:
		_barra_progresso.size.x = 560.0 * clampf(_progresso, 0.0, 1.0)

	# Aquecer demais por tempo contínuo racha a retorta.
	if _agulha_valor > 0.96:
		_tempo_superaquecido += delta
		if _tempo_superaquecido > TEMPO_ATE_RACHAR:
			_status.text = msg_falha_forte
			_fechar(false, false)
			return
	else:
		_tempo_superaquecido = 0.0

	if _progresso >= 1.0:
		_status.text = "Ponto perfeito!"
		_fechar(true, false)


func _processo_parar(delta: float) -> void:
	_agulha_valor += _agulha_direcao * _velocidade * delta
	if _agulha_valor >= 1.0:
		_agulha_valor = 1.0
		_agulha_direcao = -1.0
	elif _agulha_valor <= 0.0:
		_agulha_valor = 0.0
		_agulha_direcao = 1.0

	_status.text = "Acertos: %d / %d" % [_acertos, acertos_necessarios]

	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump"):
		if _na_faixa():
			_acertos += 1
			_velocidade += 0.35
			_flash(Color(0.4, 0.95, 0.5))
			if _acertos >= acertos_necessarios:
				_status.text = "No ponto!"
				_fechar(true, false)
		else:
			_status.text = msg_falha_fraca if _agulha_valor < faixa_centro else msg_falha_forte
			_flash(Color(0.95, 0.4, 0.35))
			_fechar(false, false)


func _flash(cor: Color) -> void:
	_agulha.color = cor
	var tween := create_tween()
	tween.tween_property(_agulha, "color", Color.WHITE, 0.4)


func _fechar(sucesso: bool, cancelado: bool) -> void:
	_encerrando = true
	await get_tree().create_timer(0.9 if not cancelado else 0.0).timeout

	Interacao.marcar_tela_aberta(self, false)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = true
	terminado.emit(sucesso, cancelado)
	queue_free()
