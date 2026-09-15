extends CanvasLayer

# --- PUZZLE DA MISTURA DA CHAMA OXÍDRICA (gaiola do maçarico, fase 1) ---
#
# O maçarico do Dr. Chico está trancado na gaiola do pátio da oficina. Para
# soltar, é preciso regular a mistura que alimenta a chama.
#
# A lição é estequiometria de verdade: a reação 2 H₂ + O₂ -> 2 H₂O consome
# DOIS volumes de hidrogênio para cada UM de oxigênio. Por isso o puzzle não
# tem uma resposta só — 2:1, 4:2 e 6:3 acendem igual. O que importa é a
# PROPORÇÃO, não o quanto se abre. Errar para cada lado tem consequência
# própria e visível na chama:
#
#   H₂ demais -> sobra combustível sem queimar: chama amarela e fuliginosa
#   O₂ demais -> chama oxidante, que queima o metal em vez de cortar
#
# A TELA VIVE EM puzzle_macarico.tscn: posições, tamanhos, fontes e cores se
# ajustam lá, no editor. Aqui só entra o que é dinâmico — volumes, barras,
# chama, válvula ativa e o verde da vitória. As barras e os riscos de volume
# se adaptam ao tamanho que o Trilho tiver na cena.
#
# INTERFACE (a mesma que a GaiolaPuzzle espera de todo puzzle de gaiola):
#   sinal "puzzle_resolvido" e método "abrir_puzzle()".
#
# CONTROLES: A/D escolhem a válvula, W/S abrem e fecham, ESPAÇO acende,
# ESC desiste. O mouse também clica nos botões e no acendedor.

signal puzzle_resolvido

## Quantos volumes cabem em cada válvula.
const MAX_VOLUME := 6
## A reação: 2 volumes de H₂ para 1 de O₂.
const RAZAO_H2 := 2

const COR_H2 := Color(0.45, 0.72, 1.0)
const COR_O2 := Color(1.0, 0.55, 0.45)
const COR_OK := Color(0.5, 0.95, 0.6)
const COR_ERRO := Color(0.95, 0.6, 0.45)
const COR_APAGADO := Color(0.62, 0.66, 0.74)

var _volumes := {"h2": 0, "o2": 0}
var _valvula_ativa: String = "h2"
var _travado: bool = false
# Nome da válvula -> {caixa, trilho, barra, numero, mais, menos}
var _valvulas := {}

@onready var _painel: Control = $RootControl/Conteudo
# O mesmo shader do puzzle do hidrogênio: a placa vermelha do fundo fica
# verde quando a mistura acende certa.
@onready var _fundo_mat: ShaderMaterial = $RootControl/Painel.material
@onready var _chama: ChamaPreview = $RootControl/Conteudo/Chama
@onready var _razao: Label = $RootControl/Conteudo/Razao
@onready var _status: Label = $RootControl/Conteudo/Status
@onready var _diagnostico: Label = $RootControl/Conteudo/Diagnostico
@onready var _acendedor: Panel = $RootControl/Conteudo/Acendedor
@onready var _acendedor_texto: Label = $RootControl/Conteudo/Acendedor/Texto
@onready var _audio_sucesso: AudioStreamPlayer = $AudioSucesso
@onready var _audio_erro: AudioStreamPlayer = $AudioErro
@onready var _audio_clique: AudioStreamPlayer = $AudioClique


func _ready() -> void:
	layer = 15
	_valvulas = {
		"h2": _preparar_valvula($RootControl/Conteudo/ValvulaH2),
		"o2": _preparar_valvula($RootControl/Conteudo/ValvulaO2),
	}
	hide()
	set_process(false)


## Liga a caixa da válvula que está na cena ao dicionário que o resto do
## script usa, e desenha os riscos de volume por cima do trilho.
func _preparar_valvula(caixa: Panel) -> Dictionary:
	var trilho: ColorRect = caixa.get_node("Trilho")
	# Marcas de volume: é por elas que se compara uma coluna com a outra.
	for i in range(1, MAX_VOLUME):
		var risco := ColorRect.new()
		risco.color = Color(0.30, 0.33, 0.40)
		risco.size = Vector2(trilho.size.x, 1)
		risco.position = Vector2(0, trilho.size.y * (1.0 - float(i) / float(MAX_VOLUME)))
		risco.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trilho.add_child(risco)
	return {
		"caixa": caixa,
		"trilho": trilho,
		"barra": trilho.get_node("Barra"),
		"numero": caixa.get_node("Numero"),
		"mais": caixa.get_node("BotaoMais"),
		"menos": caixa.get_node("BotaoMenos"),
	}


# --- ABRIR E FECHAR (contrato da GaiolaPuzzle) ---

func abrir_puzzle() -> void:
	show()
	set_process(true)
	Interacao.marcar_tela_aberta(self, true)

	_volumes = {"h2": 0, "o2": 0}
	_valvula_ativa = "h2"
	_travado = false
	_fundo_mat.set_shader_parameter("progress", 0.0)
	_status.text = "W/S abrem e fecham   ·   ESPAÇO acende   ·   ESC sai"
	_status.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
	_diagnostico.text = ""
	_atualizar()

	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = false


func fechar_puzzle(resolvido: bool) -> void:
	hide()
	set_process(false)
	Interacao.marcar_tela_aberta(self, false)

	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = true
	if resolvido:
		puzzle_resolvido.emit()


# --- ENTRADA ---

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# A tela está por cima de tudo: nada do que acontece aqui pode sobrar para
	# a gaiola que está logo atrás.
	get_viewport().set_input_as_handled()

	if event.is_action_pressed(Interacao.ACAO):
		Interacao.consumir()
		if _travado:
			fechar_puzzle(true)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_clique(event.position)
		return

	if not (event is InputEventKey and event.pressed):
		return

	if _travado:
		if event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
			fechar_puzzle(true)
		return

	match event.keycode:
		KEY_ESCAPE:
			fechar_puzzle(false)
		KEY_SPACE, KEY_ENTER:
			_acender()
		KEY_A, KEY_LEFT:
			_trocar_valvula("h2")
		KEY_D, KEY_RIGHT:
			_trocar_valvula("o2")
		KEY_W, KEY_UP:
			_girar(_valvula_ativa, 1)
		KEY_S, KEY_DOWN:
			_girar(_valvula_ativa, -1)
		KEY_L:
			# DEBUG: resolve na hora, para não regular a mistura a cada teste.
			fechar_puzzle(true)


func _clique(pos: Vector2) -> void:
	if _travado:
		fechar_puzzle(true)
		return
	if _acendedor.get_global_rect().has_point(pos):
		_acender()
		return
	for nome in _valvulas:
		var v: Dictionary = _valvulas[nome]
		if v["mais"].get_global_rect().has_point(pos):
			_trocar_valvula(nome)
			_girar(nome, 1)
			return
		if v["menos"].get_global_rect().has_point(pos):
			_trocar_valvula(nome)
			_girar(nome, -1)
			return
		if v["caixa"].get_global_rect().has_point(pos):
			_trocar_valvula(nome)
			return


func _trocar_valvula(nome: String) -> void:
	if _valvula_ativa == nome:
		return
	_valvula_ativa = nome
	_atualizar()


func _girar(nome: String, passo: int) -> void:
	var novo: int = clampi(_volumes[nome] + passo, 0, MAX_VOLUME)
	if novo == _volumes[nome]:
		return
	_volumes[nome] = novo
	if _audio_clique.stream:
		_audio_clique.play()
	_diagnostico.text = ""
	_atualizar()


# --- A QUÍMICA ---

## A mistura está na proporção da reação? (dois volumes de H₂ para um de O₂)
func _mistura_certa() -> bool:
	var o2: int = _volumes["o2"]
	return o2 > 0 and _volumes["h2"] == o2 * RAZAO_H2


## Que chama esta mistura produz agora.
func _estado_da_chama() -> String:
	var h2: int = _volumes["h2"]
	var o2: int = _volumes["o2"]
	if h2 == 0 or o2 == 0:
		return "apagada"
	if _mistura_certa():
		return "ideal"
	return "fuliginosa" if h2 > o2 * RAZAO_H2 else "oxidante"


func _acender() -> void:
	match _estado_da_chama():
		"ideal":
			_vencer()
		"apagada":
			if _volumes["h2"] == 0 and _volumes["o2"] == 0:
				_falhar("Válvulas fechadas: nada para queimar.")
			elif _volumes["h2"] == 0:
				_falhar("O₂ sozinho não queima — ele faz o outro queimar.")
			else:
				_falhar("Sem O₂, o H₂ não tem com o que reagir.")
		"fuliginosa":
			_falhar("H₂ demais: chama amarela e fuliginosa, não corta.")
		"oxidante":
			_falhar("O₂ demais: a chama oxida o metal em vez de cortar.")


func _falhar(motivo: String) -> void:
	_diagnostico.text = motivo
	_diagnostico.add_theme_color_override("font_color", COR_ERRO)
	if _audio_erro.stream:
		_audio_erro.play()

	var origem := _painel.position
	var tween := create_tween()
	tween.tween_property(_painel, "position", origem + Vector2(9, 0), 0.04)
	tween.tween_property(_painel, "position", origem + Vector2(-9, 0), 0.04)
	tween.tween_property(_painel, "position", origem, 0.06)


func _vencer() -> void:
	_travado = true
	_diagnostico.text = "Chama azul e firme: é a mistura da reação."
	_diagnostico.add_theme_color_override("font_color", COR_OK)
	_status.text = "APERTE E PARA ABRIR A GAIOLA"
	_status.add_theme_color_override("font_color", COR_OK)
	# A tela fica verde igual ao puzzle do hidrogênio.
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(v: float): _fundo_mat.set_shader_parameter("progress", v),
		0.0, 1.0, 0.6)
	if _audio_sucesso.stream:
		_audio_sucesso.play()
	_atualizar()


# --- DESENHO DA TELA ---

func _atualizar() -> void:
	for nome in _valvulas:
		var v: Dictionary = _valvulas[nome]
		var volume: int = _volumes[nome]
		var cor: Color = COR_H2 if nome == "h2" else COR_O2
		var ativa: bool = nome == _valvula_ativa and not _travado

		v["numero"].text = str(volume)
		# O preenchimento cresce de baixo para cima, na proporção do trilho —
		# seja qual for o tamanho que ele tenha na cena.
		var trilho: ColorRect = v["trilho"]
		var barra: ColorRect = v["barra"]
		var altura: float = trilho.size.y * (float(volume) / float(MAX_VOLUME))
		barra.size = Vector2(trilho.size.x, altura)
		barra.position = Vector2(0, trilho.size.y - altura)
		v["caixa"].add_theme_stylebox_override("panel", _estilo(
			Color(0.10, 0.11, 0.15),
			cor if ativa else Color(0.30, 0.33, 0.40),
			3 if ativa else 2))

	_chama.estado = _estado_da_chama()
	_razao.text = _texto_da_razao()
	_razao.add_theme_color_override("font_color", COR_OK if _mistura_certa() else COR_APAGADO)

	var pronto := _mistura_certa()
	_acendedor_texto.text = "PRONTO" if _travado else "ACENDER"
	_acendedor.add_theme_stylebox_override("panel", _estilo(
		Color(0.16, 0.30, 0.20) if pronto else Color(0.16, 0.17, 0.22),
		COR_OK if pronto else Color(0.40, 0.43, 0.50)))


# "H₂ : O₂ = 4 : 2 = 2 : 1" — mostrar a fração simplificada é o que faz cair a
# ficha de que 2:1, 4:2 e 6:3 são a mesma mistura.
func _texto_da_razao() -> String:
	var h2: int = _volumes["h2"]
	var o2: int = _volumes["o2"]
	var texto := "H₂ : O₂   =   %d : %d" % [h2, o2]
	if h2 == 0 and o2 == 0:
		return texto
	var divisor := _mdc(h2, o2)
	if divisor > 1:
		texto += "   =   %d : %d" % [h2 / divisor, o2 / divisor]
	return texto


func _mdc(a: int, b: int) -> int:
	while b != 0:
		var resto := a % b
		a = b
		b = resto
	return maxi(a, 1)


func _estilo(fundo: Color, borda: Color, largura: int = 2) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fundo
	estilo.border_color = borda
	estilo.set_border_width_all(largura)
	estilo.set_corner_radius_all(8)
	return estilo
