extends Node

# --- TECLADO OU CONTROLE? (autoload "Controle") ---
#
# O jogo fala de dois jeitos: "aperte E" para quem está no teclado e "aperte □"
# para quem está de controle na mão. Este nó descobre qual dos dois vale AGORA
# pelo último toque de verdade:
#
#   botão ou analógico do controle    -> controle
#   tecla, clique ou mouse andando    -> teclado e mouse
#
# Ninguém escolhe nada num menu: pegou o controle, a tela vira controle;
# encostou no mouse, volta. Quem mostra tecla na tela escuta o sinal "mudou"
# (ou usa "rotular", que já cuida disso).
#
# O MAPA DO CONTROLE (PlayStation) mora no mapa de entrada do projeto:
#   ✕  pular              □  interagir / bumerangue (interagir tem prioridade)
#   ○  dash / sair
#   L1 sinalizador        R1 lanterna        L3 alterna a mira da lanterna
# O maçarico não tem botão próprio: ele acende no □ da interação, e só
# encostado no que precisa ser cortado.
# Nos puzzles o analógico vira cursor (ver scripts/ui/cursor_virtual.gd).
#
# Também é aqui que o ponteiro do mouse some enquanto o controle está em uso:
# ele ficava parado no meio da tela, por cima do jogo.
#
# A escuta é no "window_input" da janela, e não num _input: esse sinal chega
# ANTES de qualquer nó, então nenhum puzzle que marque o evento como tratado
# esconde o toque daqui.

signal mudou(em_uso: bool)

## Dispositivo dos eventos de mouse que o CursorVirtual fabrica (o clique do ✕
## nos puzzles). Eles não contam como "mexeu no mouse".
const DISPOSITIVO_VIRTUAL := 90
## Quanto o mouse precisa andar (px da janela, somados em pouco tempo) para a
## tela voltar ao teclado: esbarrar na mesa não pode arrancar o controle.
const DISTANCIA_MOUSE := 24.0

## Direcional segurado: o primeiro passo sai na hora, os seguintes depois do
## atraso, um a cada intervalo (como numa lista de menu).
const REPETICAO_ATRASO := 0.38
const REPETICAO_INTERVALO := 0.11
## Quanto o analógico precisa estar empurrado para contar como direcional.
const LIMIAR_ANALOGICO := 0.6

# --- O ANALÓGICO NO MUNDO (andar, dash, mira, descer, portas) ---
#
# As ações ui_* do mapa de entrada têm zona morta de 0,5 POR EIXO, e a força de
# cada eixo é o que sobra depois dela. Com o analógico todo na diagonal cada
# eixo vale só 0,707 — sobrava 0,41 de força, e a Cacau andava a 41% da
# velocidade. O dash sofria do mesmo jeito: a diagonal só era reconhecida numa
# faixa de ~5° em volta dos 45°.
#
# Aqui o analógico é lido como um CÍRCULO (zona morta radial, a diagonal vale o
# mesmo que o reto) e repartido em 8 fatias iguais de 45°, a receita dos
# plataformas de console (Celeste, Hollow Knight):
#   andar   -> velocidade cheia em qualquer fatia com lado; só as fatias de cima
#              e de baixo (±22,5° da vertical) não andam — igual a W+D no teclado
#   dash    -> a direção da fatia
#   descer / entrar em porta -> analógico até 45° da vertical
# Teclado e direcional passam pelas mesmas contas e continuam iguais.

## A partir de quanto o analógico empurrado conta, medido no círculo.
const ZONA_MORTA_ANALOGICO := 0.25
## Meia abertura da fatia vertical, a que não anda (8 fatias de 45°).
const FATIA_VERTICAL_GRAUS := 22.5
## Folga nas divisas do andar (zona morta e borda da fatia): com o polegar
## parado bem em cima de uma divisa, o passo não pisca liga/desliga.
const FOLGA_ZONA := 0.05
const FOLGA_ANGULO_GRAUS := 3.0
## Até quantos graus da vertical o analógico ainda é "para baixo" ou "para
## cima". 45° inclui a diagonal exata, que é o S+D do teclado.
const VERTICAL_GRAUS := 45.0

## True enquanto quem joga está de controle na mão.
var em_uso: bool = false
## Controle que mandou o último toque (é dele que o cursor lê o analógico).
var dispositivo: int = 0

var _mouse_andado: float = 0.0
var _estado_direcional := {"dir": Vector2i.ZERO, "tempo": 0.0}
var _estado_navegacao := {"dir": Vector2i.ZERO, "tempo": 0.0}
var _passo_direcional := Vector2i.ZERO
var _passo_navegacao := Vector2i.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.window_input.connect(_ao_receber_entrada)
	Input.joy_connection_changed.connect(_ao_mudar_conexao)
	var conectados := Input.get_connected_joypads()
	if not conectados.is_empty():
		dispositivo = conectados[0]
		_definir(true)


func _process(delta: float) -> void:
	_mouse_andado = move_toward(_mouse_andado, 0.0, DISTANCIA_MOUSE * 2.0 * delta)
	_passo_direcional = _avancar(_estado_direcional, _direcao(false), delta)
	_passo_navegacao = _avancar(_estado_navegacao, _direcao(true), delta)


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

## Troca as marcas {acao} do texto pela tecla (teclado) ou pelo botão
## (controle) — ver as marcas em BotoesControle.
func texto(modelo: String) -> String:
	return BotoesControle.traduzir(modelo, em_uso)


## Escreve o modelo no Label e o mantém certo sozinho: trocou de teclado para
## controle, o Label se reescreve. O botão aparece desenhado (IconesNoTexto).
func rotular(label: Label, modelo: String) -> void:
	BotoesControle.rotular(label, modelo)


## Passo do DIRECIONAL neste quadro (com repetição ao segurar), ou zero.
func passo_direcional() -> Vector2i:
	return _passo_direcional


## Passo do direcional OU do analógico esquerdo neste quadro, ou zero — para
## telas que o controle opera sem cursor (o mostrador do guincho).
func passo_navegacao() -> Vector2i:
	return _passo_navegacao


# ─────────────────────────────────────────────────────────────
# O ANALÓGICO NO MUNDO (ver o topo do arquivo)
# ─────────────────────────────────────────────────────────────

## As setas do mapa de entrada como vetor. Teclado e direcional valem 0 ou 1 em
## cada eixo; o analógico vale o ângulo e a força de verdade (Input.get_vector
## usa a força BRUTA, sem a zona morta de 0,5 por eixo, e aplica esta zona morta
## no círculo).
func vetor_direcional(zona_morta: float = ZONA_MORTA_ANALOGICO) -> Vector2:
	return Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down", zona_morta)


## Uma das 8 direções (vetor unitário), por fatias iguais de 45°, ou zero.
func direcao_8(zona_morta: float = ZONA_MORTA_ANALOGICO) -> Vector2:
	var vetor := vetor_direcional(zona_morta)
	if vetor.is_zero_approx():
		return Vector2.ZERO
	var angulo := snappedf(vetor.angle(), PI / 4.0)
	return Vector2(roundf(cos(angulo)), roundf(sin(angulo))).normalized()


## Para que lado andar: -1, 0 ou 1 — sempre em velocidade cheia. Não anda só na
## fatia de cima e na de baixo. Passe o valor do quadro anterior em "anterior":
## é ele que dá a folga nas divisas (quem está andando só para ao entrar bem na
## fatia vertical ou quase soltar o analógico, e vice-versa).
func lado_de_andar(anterior: float = 0.0) -> float:
	var vetor := vetor_direcional(0.0)
	var andando := anterior != 0.0
	var zona := ZONA_MORTA_ANALOGICO - (FOLGA_ZONA if andando else 0.0)
	if vetor.length() <= zona or is_zero_approx(vetor.x):
		return 0.0
	var fatia := FATIA_VERTICAL_GRAUS + (-FOLGA_ANGULO_GRAUS if andando else FOLGA_ANGULO_GRAUS)
	if _graus_da_vertical(vetor) <= fatia:
		return 0.0
	return signf(vetor.x)


## Apontando para baixo (até VERTICAL_GRAUS da vertical) — o "S" de descer da
## plataforma. Correndo com o polegar um pouco para baixo não conta.
func aponta_para_baixo() -> bool:
	var vetor := vetor_direcional()
	return vetor.y > 0.0 and _graus_da_vertical(vetor) <= VERTICAL_GRAUS + 0.01


## Apontando para cima (até VERTICAL_GRAUS da vertical) — o "W" das portas.
func aponta_para_cima() -> bool:
	var vetor := vetor_direcional()
	return vetor.y < 0.0 and _graus_da_vertical(vetor) <= VERTICAL_GRAUS + 0.01


## 0° = vertical pura, 90° = horizontal.
static func _graus_da_vertical(vetor: Vector2) -> float:
	return rad_to_deg(atan2(absf(vetor.x), absf(vetor.y)))


# ─────────────────────────────────────────────────────────────
# DETECÇÃO
# ─────────────────────────────────────────────────────────────

func _ao_receber_entrada(evento: InputEvent) -> void:
	if evento.device == DISPOSITIVO_VIRTUAL:
		return
	if evento is InputEventJoypadButton:
		if evento.pressed:
			_usar_controle(evento.device)
	elif evento is InputEventJoypadMotion:
		# Analógico parado treme um pouco em todo controle: só empurrão conta.
		if absf(evento.axis_value) >= 0.5:
			_usar_controle(evento.device)
	elif evento is InputEventKey:
		if evento.pressed and not evento.echo:
			_definir(false)
	elif evento is InputEventMouseButton:
		if evento.pressed:
			_definir(false)
	elif evento is InputEventMouseMotion:
		_mouse_andado += evento.relative.length()
		if _mouse_andado >= DISTANCIA_MOUSE:
			_mouse_andado = 0.0
			_definir(false)


func _usar_controle(qual: int) -> void:
	dispositivo = qual
	_definir(true)


func _ao_mudar_conexao(qual: int, conectado: bool) -> void:
	if not conectado and qual == dispositivo:
		var restantes := Input.get_connected_joypads()
		if restantes.is_empty():
			_definir(false)
		else:
			dispositivo = restantes[0]


func _definir(valor: bool) -> void:
	if valor == em_uso:
		return
	em_uso = valor
	_atualizar_ponteiro_do_mouse()
	mudou.emit(em_uso)


## Só alterna entre VISÍVEL e ESCONDIDO: quem capturou ou confinou o mouse por
## outro motivo continua mandando nele.
func _atualizar_ponteiro_do_mouse() -> void:
	if em_uso and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	elif not em_uso and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ─────────────────────────────────────────────────────────────
# DIRECIONAL COM REPETIÇÃO
# ─────────────────────────────────────────────────────────────

func _direcao(com_analogico: bool) -> Vector2i:
	var d := Vector2i.ZERO
	if Input.is_joy_button_pressed(dispositivo, JOY_BUTTON_DPAD_LEFT):
		d.x -= 1
	if Input.is_joy_button_pressed(dispositivo, JOY_BUTTON_DPAD_RIGHT):
		d.x += 1
	if Input.is_joy_button_pressed(dispositivo, JOY_BUTTON_DPAD_UP):
		d.y -= 1
	if Input.is_joy_button_pressed(dispositivo, JOY_BUTTON_DPAD_DOWN):
		d.y += 1
	if d != Vector2i.ZERO or not com_analogico:
		return d
	var eixo := Vector2(Input.get_joy_axis(dispositivo, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(dispositivo, JOY_AXIS_LEFT_Y))
	if eixo.length() < LIMIAR_ANALOGICO:
		return Vector2i.ZERO
	# Só o eixo dominante: analógico na diagonal não pode mexer nos dois.
	if absf(eixo.x) >= absf(eixo.y):
		return Vector2i(1 if eixo.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if eixo.y > 0.0 else -1)


func _avancar(estado: Dictionary, direcao: Vector2i, delta: float) -> Vector2i:
	if direcao == Vector2i.ZERO:
		estado["dir"] = Vector2i.ZERO
		return Vector2i.ZERO
	if direcao != estado["dir"]:
		estado["dir"] = direcao
		estado["tempo"] = REPETICAO_ATRASO
		return direcao
	estado["tempo"] -= delta
	if estado["tempo"] <= 0.0:
		estado["tempo"] += REPETICAO_INTERVALO
		return direcao
	return Vector2i.ZERO
