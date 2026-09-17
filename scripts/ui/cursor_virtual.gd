extends CanvasLayer

# --- O CURSOR DO CONTROLE NOS PUZZLES (autoload "CursorVirtual") ---
#
# Os puzzles nasceram para o mouse: arrastar o cilindro até o tubo, o elétron
# até a órbita, clicar nas setas da equação. De controle na mão não havia como
# fazer nada disso. Em vez de reescrever cada puzzle, o controle aprende a ser
# mouse — do jeito dos jogos de PC que chegam ao console:
#
#   ANALÓGICO ESQUERDO  move o cursor. Pouco empurrado = devagar e preciso; no
#                       talo, depois de um instante, ele acelera para cruzar a
#                       tela.
#   ANALÓGICO DIREITO   ajuste fino (bem devagar).
#   DIRECIONAL          pula de alvo em alvo (peça, seta, encaixe) na direção
#                       apertada.
#   ✕                   é o botão do mouse: toque clica, SEGURAR arrasta e
#                       soltar larga.
#   ○ / □               continuam "sair" e "interagir" — cada puzzle os lê pelo
#                       mapa de entrada (ui_cancel e interact).
#
# Em cima de um alvo o cursor fica pegajoso (anda mais devagar) e, largado o
# analógico, escorrega sozinho para o centro dele: é isso que torna fácil
# acertar uma seta de 20 px com o polegar. Uma moldura de cantos marca o alvo
# sob o cursor e a barra no pé da tela diz o que cada botão faz ali.
#
# O clique é de verdade: os eventos de mouse vão por Input.parse_input_event,
# na posição do cursor. O puzzle não sabe (nem precisa saber) que não é um
# mouse. Eles saem com o dispositivo Controle.DISPOSITIVO_VIRTUAL, para o
# Controle não achar que alguém mexeu no mouse.
#
# --- COMO LIGAR UMA TELA NO CONTROLE ---
#
# Basta a tela entrar no grupo GRUPO (no _ready). A barra e o cursor aparecem
# enquanto ela estiver aberta (Interacao.marcar_tela_aberta) e visível, com o
# controle em uso e sem fala do Dialogic por cima. O resto é opcional — métodos
# que a tela PODE ter:
#
#   alvos_do_cursor() -> Array[Rect2]
#       retângulos (coordenadas de tela) do que dá para pegar ou clicar AGORA;
#       com algo na mão, onde dá para soltar. Liga a moldura, o pegajoso, o ímã
#       e os pulos do direcional.
#   dicas_do_controle() -> Array
#       [[botão, "TEXTO"], ...] para a barra. "botão" é uma ação do mapa de
#       entrada ("ui_cancel") ou um nome de BotoesControle ("cruz").
#   usa_cursor() -> bool
#       false nas telas que o controle opera direto (guincho, dosagem): elas
#       ganham só a barra.
#
# A tela deve ler a posição do ponteiro nos EVENTOS (event.position), e não em
# get_viewport().get_mouse_position(): esta lê o mouse do sistema, que o cursor
# do controle não move.

const GRUPO := "tela_com_controle"

# --- MOVIMENTO ---
const ZONA_MORTA := 0.2
## px de tela por segundo com o analógico no talo (a tela tem 1600 x 900).
const VELOCIDADE := 760.0
## Curva do analógico: acima de 1, o começo do curso fica mais fino.
const CURVA := 1.8
## Segurando o analógico no talo, a velocidade cresce até este fator...
const TURBO := 2.0
## ...começando depois deste tempo no talo...
const TURBO_ATRASO := 0.3
## ...e chegando no máximo ao longo deste.
const TURBO_RAMPA := 0.5
const FATOR_FINO := 0.3
## Por cima de um alvo o cursor anda a esta fração da velocidade (o pegajoso).
const ATRITO_ALVO := 0.45
## Força do ímã que leva o cursor ao centro do alvo com o analógico solto.
const IMA_FORCA := 12.0
## Alvo maior que isto não puxa: uma área de soltar inteira não pode sequestrar
## o cursor de quem só está passando.
const IMA_TAMANHO_MAX := 280.0
## Folga em volta do alvo que ainda conta como "em cima".
const FOLGA_ALVO := 8.0
const PULO_DURACAO := 0.12
## A tela abre com o cursor no meio; parado, ele vai sozinho ao alvo mais perto
## depois deste tempo.
const ESPERA_PRIMEIRO_ALVO := 0.45
## Quando sobra UM alvo só (o botão que o cientista pede), o cursor vai até ele
## depois deste tempo parado.
const ESPERA_ALVO_UNICO := 0.3

# --- DESENHO ---
## Acima de tudo: puzzles (10-15), Dialogic (20) e o cinto (90).
const CAMADA := 110
const COR_ACENTO := Color(0.42, 0.78, 1.0)
const COR_TRACO := Color(0.03, 0.05, 0.10)
const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")
const TAM_DICA := 13
const ESPACO_DICA := 1.6
const ALTURA_BARRA := 46.0
## A seta do ponteiro, com a ponta na origem.
const SETA := [Vector2(0, 0), Vector2(0, 19), Vector2(4.5, 15), Vector2(8, 22.5),
	Vector2(11.2, 21), Vector2(7.8, 13.8), Vector2(13.6, 13.8)]
const ESCALA_SETA := 1.3

var _tela: Node = null
var _ativo: bool = false
var _com_cursor: bool = false
var _pos: Vector2 = Vector2.ZERO
var _ultima_enviada: Vector2 = Vector2(-1.0, -1.0)
var _segurando: bool = false
var _cruz_antes: bool = false
var _tempo_no_talo: float = 0.0
var _parado: float = 0.0
var _alvos: Array[Rect2] = []
var _assinatura_alvos: String = ""
## Contagem para ir sozinho até um alvo (< 0 = desarmado).
var _ir_ao_alvo_em: float = -1.0
var _pulo_de: Vector2 = Vector2.ZERO
var _pulo_para: Vector2 = Vector2.ZERO
var _pulo_t: float = 1.0

var _alfa: float = 0.0
var _clique: float = 0.0
var _moldura: Rect2 = Rect2()
var _moldura_alfa: float = 0.0
var _tempo: float = 0.0
var _desenho: Control = null


func _ready() -> void:
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS
	_desenho = Control.new()
	_desenho.name = "Desenho"
	_desenho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desenho.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desenho.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_desenho.draw.connect(_desenhar)
	add_child(_desenho)
	visible = false


## True enquanto o cursor (ou só a barra) está na tela.
func ativo() -> bool:
	return _ativo


func _process(delta: float) -> void:
	_tempo += delta
	var tela := _tela_aberta()
	var deve := tela != null and Controle.em_uso and Dialogic.current_timeline == null \
		and not Inventario.popup_aberto
	if not deve:
		if _ativo:
			_desligar()
	else:
		if not _ativo or tela != _tela:
			_ligar(tela)
		_atualizar(delta)

	_alfa = move_toward(_alfa, 1.0 if _ativo else 0.0, delta * 8.0)
	visible = _alfa > 0.0
	if visible:
		_desenho.queue_redraw()


# ─────────────────────────────────────────────────────────────
# LIGAR E DESLIGAR
# ─────────────────────────────────────────────────────────────

func _tela_aberta() -> Node:
	var achada: Node = null
	for tela in get_tree().get_nodes_in_group(GRUPO):
		if not tela.is_inside_tree() or tela.is_queued_for_deletion():
			continue
		if not tela.is_in_group(Interacao.GRUPO_TELA):
			continue
		if "visible" in tela and not tela.visible:
			continue
		achada = tela
	return achada


func _ligar(tela: Node) -> void:
	if _segurando:
		_enviar_botao(false)
	var mesma_tela := tela == _tela
	_tela = tela
	_ativo = true
	_com_cursor = not tela.has_method("usa_cursor") or tela.usa_cursor()
	# Um ✕ que já vinha segurado de antes da tela abrir não vira clique.
	_cruz_antes = _cruz_apertada()
	_segurando = false
	_tempo_no_talo = 0.0
	_parado = 0.0
	_pulo_t = 1.0
	_moldura_alfa = 0.0
	_assinatura_alvos = ""
	if not _com_cursor:
		return
	# Reabrir a mesma tela devolve o cursor onde ele estava.
	if not mesma_tela:
		_pos = get_viewport().get_visible_rect().size * 0.5
	_ir_ao_alvo_em = ESPERA_PRIMEIRO_ALVO
	_ultima_enviada = Vector2(-1.0, -1.0)
	_enviar_movimento()


func _desligar() -> void:
	# Arrasto no meio: o botão do mouse não pode ficar "preso" apertado.
	if _segurando:
		_segurando = false
		_enviar_botao(false)
	_ativo = false
	_moldura_alfa = 0.0


# ─────────────────────────────────────────────────────────────
# A CADA QUADRO
# ─────────────────────────────────────────────────────────────

func _atualizar(delta: float) -> void:
	_alvos = _ler_alvos()
	if not _com_cursor:
		return
	_vigiar_alvos()
	_clique = move_toward(_clique, 0.0, delta * 6.0)

	_ler_cruz()
	# O clique pode ter fechado a tela (o botão "abrir a gaiola"): daqui em
	# diante nada pode ir parar no mundo atrás dela.
	if _tela_aberta() != _tela:
		return
	_mover(delta)
	_ler_direcional()
	_atualizar_moldura(delta)


func _ler_alvos() -> Array[Rect2]:
	var alvos: Array[Rect2] = []
	if not is_instance_valid(_tela) or not _tela.has_method("alvos_do_cursor"):
		return alvos
	for alvo in _tela.alvos_do_cursor():
		if alvo is Rect2 and alvo.has_area():
			alvos.append(alvo)
	return alvos


## Quando o conjunto de alvos muda para UM só (o cientista pediu um botão), o
## cursor se oferece para ir até ele. Tamanhos, e não posições, formam a
## assinatura: o elétron em órbita anda todo quadro sem "mudar" de alvo.
func _vigiar_alvos() -> void:
	var assinatura := ""
	for alvo in _alvos:
		assinatura += "%d,%d;" % [roundi(alvo.size.x), roundi(alvo.size.y)]
	if assinatura == _assinatura_alvos:
		return
	var primeira_leitura := _assinatura_alvos == ""
	_assinatura_alvos = assinatura
	if not primeira_leitura and _alvos.size() == 1 and not _segurando \
			and _alvo_sob(_pos) < 0:
		_ir_ao_alvo_em = ESPERA_ALVO_UNICO


func _cruz_apertada() -> bool:
	return Input.is_joy_button_pressed(Controle.dispositivo, JOY_BUTTON_A)


func _ler_cruz() -> void:
	var apertada := _cruz_apertada()
	if apertada and not _cruz_antes:
		_terminar_pulo()
		_ir_ao_alvo_em = -1.0
		_segurando = true
		_clique = 1.0
		_enviar_botao(true)
	elif not apertada and _segurando:
		_segurando = false
		_enviar_botao(false)
	_cruz_antes = apertada


func _mover(delta: float) -> void:
	var grosso := _analogico(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	var fino := _analogico(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y) * FATOR_FINO
	var entrada := grosso if grosso.length() >= fino.length() else fino

	if entrada == Vector2.ZERO:
		_tempo_no_talo = 0.0
		_parado += delta
		if _pulo_t < 1.0:
			_avancar_pulo(delta)
		else:
			_repousar(delta)
		return

	_parado = 0.0
	_pulo_t = 1.0
	_ir_ao_alvo_em = -1.0
	if grosso.length() >= 0.98:
		_tempo_no_talo += delta
	else:
		_tempo_no_talo = 0.0
	var turbo := clampf((_tempo_no_talo - TURBO_ATRASO) / TURBO_RAMPA, 0.0, 1.0)
	var velocidade := VELOCIDADE * lerpf(1.0, TURBO, turbo)
	# O pegajoso some conforme o turbo entra: atravessar a tela no talo não
	# pode engasgar em cada seta do caminho.
	if _alvo_sob(_pos) >= 0:
		velocidade *= lerpf(ATRITO_ALVO, 1.0, turbo)
	_pos = _limitar(_pos + entrada * velocidade * delta)
	_enviar_movimento()


func _analogico(eixo_x: JoyAxis, eixo_y: JoyAxis) -> Vector2:
	var bruto := Vector2(Input.get_joy_axis(Controle.dispositivo, eixo_x),
		Input.get_joy_axis(Controle.dispositivo, eixo_y))
	var forca := bruto.length()
	if forca < ZONA_MORTA:
		return Vector2.ZERO
	var t := clampf((forca - ZONA_MORTA) / (1.0 - ZONA_MORTA), 0.0, 1.0)
	return bruto / forca * pow(t, CURVA)


## Analógico solto: o ímã puxa para o centro do alvo sob o cursor, ou o cursor
## vai sozinho ao alvo que a tela está oferecendo.
func _repousar(delta: float) -> void:
	var sob := _alvo_sob(_pos)
	if sob >= 0:
		_ir_ao_alvo_em = -1.0
		var alvo := _alvos[sob]
		if alvo.size.x <= IMA_TAMANHO_MAX and alvo.size.y <= IMA_TAMANHO_MAX:
			var centro := alvo.get_center()
			if _pos.distance_to(centro) > 0.5:
				_pos = _pos.lerp(centro, 1.0 - exp(-IMA_FORCA * delta))
				_enviar_movimento()
		return
	if _ir_ao_alvo_em < 0.0 or _alvos.is_empty() or _segurando:
		return
	_ir_ao_alvo_em -= delta
	if _ir_ao_alvo_em <= 0.0:
		_ir_ao_alvo_em = -1.0
		_pular_para(_mais_perto(_pos))


func _ler_direcional() -> void:
	var passo := Controle.passo_direcional()
	if passo == Vector2i.ZERO or _alvos.is_empty():
		return
	_ir_ao_alvo_em = -1.0
	_pular_para(_alvo_na_direcao(Vector2(passo)))


# ─────────────────────────────────────────────────────────────
# ALVOS
# ─────────────────────────────────────────────────────────────

## O alvo sob o ponto (o menor, se vários se sobrepõem), ou -1.
func _alvo_sob(ponto: Vector2) -> int:
	var melhor := -1
	var menor_area := INF
	for i in _alvos.size():
		if not _alvos[i].grow(FOLGA_ALVO).has_point(ponto):
			continue
		var area := _alvos[i].get_area()
		if area < menor_area:
			menor_area = area
			melhor = i
	return melhor


func _mais_perto(ponto: Vector2) -> int:
	var melhor := -1
	var menor := INF
	for i in _alvos.size():
		var distancia := _alvos[i].get_center().distance_squared_to(ponto)
		if distancia < menor:
			menor = distancia
			melhor = i
	return melhor


## O próximo alvo na direção do direcional: o que está mais à frente e menos
## de lado. Partindo de um alvo, conta a partir do centro dele — assim o pulo
## é sempre de alvo em alvo, esteja o cursor na borda ou no meio.
func _alvo_na_direcao(direcao: Vector2) -> int:
	var dir := direcao.normalized()
	var atual := _alvo_sob(_pos)
	var origem := _alvos[atual].get_center() if atual >= 0 else _pos
	var melhor := -1
	var melhor_nota := INF
	for i in _alvos.size():
		if i == atual:
			continue
		var d := _alvos[i].get_center() - origem
		var frente := d.dot(dir)
		if frente <= 2.0:
			continue
		var nota := frente + absf(d.cross(dir)) * 2.2
		if nota < melhor_nota:
			melhor_nota = nota
			melhor = i
	return melhor


func _pular_para(indice: int) -> void:
	if indice < 0 or indice >= _alvos.size():
		return
	_pulo_de = _pos
	_pulo_para = _alvos[indice].get_center()
	_pulo_t = 0.0


func _avancar_pulo(delta: float) -> void:
	_pulo_t = minf(_pulo_t + delta / PULO_DURACAO, 1.0)
	var t := 1.0 - pow(1.0 - _pulo_t, 3.0)
	_pos = _limitar(_pulo_de.lerp(_pulo_para, t))
	_enviar_movimento()


## Clicar no meio de um pulo vale para onde o pulo ia.
func _terminar_pulo() -> void:
	if _pulo_t >= 1.0:
		return
	_pulo_t = 1.0
	_pos = _limitar(_pulo_para)
	_enviar_movimento()


func _limitar(ponto: Vector2) -> Vector2:
	var tela := get_viewport().get_visible_rect().size
	return ponto.clamp(Vector2.ZERO, tela - Vector2.ONE)


# ─────────────────────────────────────────────────────────────
# EVENTOS DE MOUSE
# ─────────────────────────────────────────────────────────────

func _enviar_movimento() -> void:
	if _pos.is_equal_approx(_ultima_enviada):
		return
	var evento := InputEventMouseMotion.new()
	_preparar(evento)
	evento.button_mask = MOUSE_BUTTON_MASK_LEFT if _segurando else 0
	if _ultima_enviada.x >= 0.0:
		evento.relative = get_viewport().get_screen_transform().basis_xform(_pos - _ultima_enviada)
		evento.screen_relative = evento.relative
	_ultima_enviada = _pos
	_emitir(evento)


func _enviar_botao(apertado: bool) -> void:
	_enviar_movimento()
	var evento := InputEventMouseButton.new()
	_preparar(evento)
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = apertado
	evento.button_mask = MOUSE_BUTTON_MASK_LEFT if apertado else 0
	_emitir(evento)


## O evento vai em coordenadas da JANELA: é a janela que converte para a tela
## do jogo (1600 x 900), como faz com o mouse de verdade em qualquer resolução.
func _preparar(evento: InputEventMouse) -> void:
	evento.device = Controle.DISPOSITIVO_VIRTUAL
	var na_janela := get_viewport().get_screen_transform() * _pos
	evento.position = na_janela
	evento.global_position = na_janela


func _emitir(evento: InputEvent) -> void:
	Input.parse_input_event(evento)
	# Entrega já, e não no começo do próximo quadro: o _process do puzzle ainda
	# vai rodar neste quadro e a peça na mão tem de acompanhar o cursor sem
	# atraso.
	Input.flush_buffered_events()


# ─────────────────────────────────────────────────────────────
# DESENHO
# ─────────────────────────────────────────────────────────────

func _atualizar_moldura(delta: float) -> void:
	var sob := _alvo_sob(_pos)
	if sob < 0:
		_moldura_alfa = move_toward(_moldura_alfa, 0.0, delta * 8.0)
		return
	var destino := _alvos[sob].grow(6.0)
	if _moldura_alfa <= 0.01:
		_moldura = destino
	else:
		# A moldura DESLIZA de um alvo para o outro, em vez de piscar.
		var k := 1.0 - exp(-22.0 * delta)
		_moldura = Rect2(_moldura.position.lerp(destino.position, k),
			_moldura.size.lerp(destino.size, k))
	_moldura_alfa = move_toward(_moldura_alfa, 1.0, delta * 10.0)


func _desenhar() -> void:
	if _alfa <= 0.0:
		return
	if _com_cursor:
		if _moldura_alfa > 0.0:
			_desenhar_moldura(_alfa * _moldura_alfa)
		_desenhar_seta(_alfa)
	_desenhar_barra(_alfa)


## Cantos que respiram em volta do alvo, com um véu de cor bem leve dentro.
func _desenhar_moldura(alfa: float) -> void:
	var caixa := _moldura.grow(1.5 * sin(_tempo * 5.0))
	_desenho.draw_rect(caixa, EstiloHUD.com_alfa(COR_ACENTO, 0.08 * alfa), true)
	var perna := clampf(minf(caixa.size.x, caixa.size.y) * 0.3, 6.0, 18.0)
	var cantos := [
		[caixa.position, Vector2(1, 0), Vector2(0, 1)],
		[Vector2(caixa.end.x, caixa.position.y), Vector2(-1, 0), Vector2(0, 1)],
		[caixa.end, Vector2(-1, 0), Vector2(0, -1)],
		[Vector2(caixa.position.x, caixa.end.y), Vector2(1, 0), Vector2(0, -1)],
	]
	for canto in cantos:
		var ponta: Vector2 = canto[0]
		var pontos := PackedVector2Array([ponta + canto[1] * perna, ponta, ponta + canto[2] * perna])
		_desenho.draw_polyline(pontos, EstiloHUD.com_alfa(COR_TRACO, 0.8 * alfa), 6.0, true)
		_desenho.draw_polyline(pontos, EstiloHUD.com_alfa(COR_ACENTO, alfa), 3.0, true)


func _desenhar_seta(alfa: float) -> void:
	var escala := ESCALA_SETA * (1.0 - 0.14 * _clique)
	if _segurando:
		escala *= 0.92
	var sobre_alvo := _alvo_sob(_pos) >= 0 \
		or Input.get_current_cursor_shape() == Input.CURSOR_POINTING_HAND

	if sobre_alvo or _segurando:
		var raio := 11.0 + 2.0 * sin(_tempo * 6.0)
		_desenho.draw_arc(_pos, raio, 0.0, TAU, 28, EstiloHUD.com_alfa(COR_TRACO, 0.7 * alfa), 5.0, true)
		_desenho.draw_arc(_pos, raio, 0.0, TAU, 28, EstiloHUD.com_alfa(COR_ACENTO, alfa), 2.5, true)

	var pontos := PackedVector2Array()
	var sombra := PackedVector2Array()
	for p: Vector2 in SETA:
		pontos.append(_pos + p * escala)
		sombra.append(_pos + p * escala + Vector2(2.0, 3.0))
	_desenho.draw_colored_polygon(sombra, Color(0, 0, 0, 0.35 * alfa))
	var recheio := Color.WHITE.lerp(COR_ACENTO, 0.6) if _segurando else Color.WHITE
	_desenho.draw_colored_polygon(pontos, EstiloHUD.com_alfa(recheio, alfa))
	_desenho.draw_polyline(EstiloHUD.fechar(pontos), EstiloHUD.com_alfa(COR_TRACO, alfa), 2.0, true)


## A barra de comandos no pé da tela: botão desenhado + o que ele faz ali.
func _desenhar_barra(alfa: float) -> void:
	var dicas := _dicas()
	if dicas.is_empty():
		return
	var lado := 32.0
	var respiro_icone := 8.0
	var respiro_itens := 26.0
	var margem := 18.0
	var larguras: Array[float] = []
	var total := 0.0
	for dica in dicas:
		var largura: float = lado + respiro_icone \
			+ EstiloHUD.largura_texto(FONTE, String(dica[1]), TAM_DICA, ESPACO_DICA)
		larguras.append(largura)
		total += largura
	total += respiro_itens * (dicas.size() - 1)

	var tela := _desenho.get_viewport_rect().size
	var caixa := Rect2(Vector2((tela.x - total) * 0.5 - margem, tela.y - ALTURA_BARRA - 10.0),
		Vector2(total + margem * 2.0, ALTURA_BARRA))
	var corpo := EstiloHUD.chanfro(caixa, 12.0)
	EstiloHUD.sombra(_desenho, corpo, 4.0, alfa)
	EstiloHUD.vidro(_desenho, corpo, 0.92 * alfa)
	EstiloHUD.moldura(_desenho, corpo, EstiloHUD.com_alfa(EstiloHUD.BORDA, alfa), 1.5)
	_desenho.draw_line(corpo[0], corpo[1], EstiloHUD.com_alfa(EstiloHUD.FIO_LUZ, alfa), 1.5, true)

	var x := caixa.position.x + margem
	var meio := caixa.get_center().y
	var base := meio + FONTE.get_ascent(TAM_DICA) * 0.5 - 1.0
	for i in dicas.size():
		var nome := BotoesControle.nome_para_dica(String(dicas[i][0]))
		BotoesControle.desenhar(_desenho, Vector2(x + lado * 0.5, meio), nome, 2.0,
			Color(1, 1, 1, alfa))
		EstiloHUD.texto(_desenho, FONTE, Vector2(x + lado + respiro_icone, base),
			String(dicas[i][1]), TAM_DICA, EstiloHUD.com_alfa(EstiloHUD.TEXTO, alfa), ESPACO_DICA)
		x += larguras[i] + respiro_itens


func _dicas() -> Array:
	if is_instance_valid(_tela) and _tela.has_method("dicas_do_controle"):
		return _tela.dicas_do_controle()
	if not _com_cursor:
		return [["ui_cancel", "SAIR"]]
	var dicas: Array = [["analogico_esquerdo", "MOVER"]]
	if not _alvos.is_empty():
		dicas.append(["direcional", "ESCOLHER"])
	dicas.append(["cruz", "SOLTE PARA COLOCAR" if _segurando else "SELECIONAR"])
	dicas.append(["ui_cancel", "SAIR"])
	return dicas
