class_name CadernoLivro
extends Control

# --- O CADERNO ABERTO: A ARTE, AS FOLHAS VIRANDO E AS FITAS ---
#
# A arte é uma folha de 10 quadros lado a lado (caderno.png, 1396 × 832 cada,
# pixel art ampliada 4×). O quadro 1 é o caderno aberto e parado — é nele que
# o texto mora. Do 2 ao 9 a folha da direita descola, passa pela lombada e
# deita à esquerda; o 10 é igual ao 1. Voltar uma página é a mesma animação de
# trás para a frente.
#
# O TEXTO ANDA COM A FOLHA. A arte não tem texto: cada face é desenhada por
# cima (FaceCaderno), dentro de um recorte. Durante a virada entre a página A
# e a seguinte, B, cada quadro tem sempre a mesma composição — indo ou
# voltando:
#
#   embaixo, à esquerda   A.esquerda, só até onde a folha que vira ainda não
#                         chegou (a folha é opaca: vai cobrindo)
#   embaixo, à direita    B.direita, só depois da borda da folha que vira:
#                         aparece por trás dela conforme ela passa
#   a folha que vira      na frente (quadros 2 a 5) leva A.direita; no verso
#                         (7 a 9), B.esquerda — espremidas na largura que a
#                         folha tem naquele quadro, apagando enquanto ela
#                         entorta. No 6 a folha está de lado: sem texto.
#
# Onde a folha que vira está em cada quadro (VIRANDO) foi medido na própria
# arte: são as colunas em que o quadro difere do quadro 1. Se a animação da
# arte mudar, é só medir de novo.
#
# AS FITAS: as quatro fitas da borda são as quatro páginas. A da página aberta
# fica puxada para fora, e clicar numa fita folheia até ela.
#
# Tudo aqui está em px do quadro (o nó tem o tamanho de um quadro). Quem põe o
# caderno na tela, amplia e anima a abertura é o autoload Caderno.

## Clique fora do desenho do caderno (na borda transparente do quadro).
signal fora_clicado
## Terminou de virar e parou nesta página.
signal pagina_mudou(pagina: int)

const FOLHA := preload("res://assets/caderno de anotaçõess/caderno.png")
const SOM_PAGINA := preload("res://sounds/caderno_pagina.wav")

const QUADROS := 10
const TAMANHO_QUADRO := Vector2(1396, 832)
## Onde está o desenho dentro do quadro (o resto é transparente), com as fitas.
const CAIXA_DESENHO := Rect2(172, 64, 1136, 732)
## O papel de cada face, por dentro do fio da borda.
const FACE_ESQUERDA := Rect2(236, 160, 456, 548)
const FACE_DIREITA := Rect2(736, 160, 452, 548)

## Colunas (x inicial, x final) da folha que vira em cada quadro; ZERO = sem
## folha no ar (quadros 1 e 10).
const VIRANDO := [Vector2.ZERO, Vector2(720, 1172), Vector2(712, 1140), Vector2(692, 1092),
	Vector2(624, 1024), Vector2(580, 820), Vector2(456, 712), Vector2(340, 712),
	Vector2(252, 700), Vector2.ZERO]
## Quanto do texto ainda se lê na folha que vira: na frente ele apaga conforme
## a folha descola; no verso, acende conforme ela deita.
const TINTA_NA_FOLHA := [0.0, 0.9, 0.7, 0.45, 0.2, 0.0, 0.25, 0.55, 0.85, 0.0]
## Até este quadro (contando do 0) a folha que vira mostra a frente.
const ULTIMO_QUADRO_DA_FRENTE := 4

## Segundos em cada quadro da virada, na ordem em que aparecem (do 2 ao 9 indo,
## do 9 ao 2 voltando). Devagar ao descolar e ao assentar, rápido no meio.
const TEMPOS := [0.06, 0.055, 0.05, 0.05, 0.045, 0.05, 0.06, 0.075]
## Com mais viradas na fila (fita clicada, tecla segurada), folheia mais rápido.
const ACELERACAO_FOLHEANDO := 1.7

## As fitas no quadro, de cima para baixo: uma para cada página.
const FITAS := [Rect2(1212, 268, 96, 68), Rect2(1212, 356, 96, 68),
	Rect2(1212, 440, 96, 68), Rect2(1212, 524, 96, 68)]
## Quanto a fita da página aberta sai para fora, e a que está sob o mouse. Anda
## de 4 em 4 px — o pixel da arte.
const FITA_ABERTA := 12.0
const FITA_SOB_O_MOUSE := 4.0
const VELOCIDADE_FITA := 90.0
const PIXEL_DA_ARTE := 4.0

## Empurrãozinho quando não há mais página para aquele lado (mola: rigidez e
## amortecimento).
const EMPURRAO_VELOCIDADE := 420.0
const MOLA_RIGIDEZ := 900.0
const MOLA_AMORTECIMENTO := 30.0

var _pagina: int = 0
## Página onde a pessoa quer chegar. Diferente de _pagina = tem virada na fila.
var _alvo: int = 0
var _virando: bool = false
## A virada em andamento é entre a página _a e a _a + 1; _sentido 1 vai, -1 volta.
var _a: int = 0
var _sentido: int = 1
var _tempo: float = 0.0
var _quadro: int = 0

var _fitas_saida: Array[float] = []
var _fita_sob_mouse: int = -1
var _empurrao: float = 0.0
var _velocidade_empurrao: float = 0.0

var _arte: Control = null
## [embaixo à esquerda, embaixo à direita, a folha que vira]
var _recortes: Array[Control] = []
var _faces: Array[FaceCaderno] = []
var _som: AudioStreamPlayer = null


func _ready() -> void:
	size = TAMANHO_QUADRO
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_arte = Control.new()
	_arte.name = "Arte"
	_arte.size = TAMANHO_QUADRO
	_arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arte.draw.connect(_desenhar_arte)
	add_child(_arte)

	for nome in ["Esquerda", "Direita", "Virando"]:
		var recorte := Control.new()
		recorte.name = nome
		recorte.clip_contents = true
		recorte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face := FaceCaderno.new()
		face.name = "Face"
		recorte.add_child(face)
		_arte.add_child(recorte)
		_recortes.append(recorte)
		_faces.append(face)

	_som = AudioStreamPlayer.new()
	_som.name = "SomPagina"
	_som.stream = SOM_PAGINA
	_som.volume_db = -4.0
	add_child(_som)

	for i in FITAS.size():
		_fitas_saida.append(FITA_ABERTA if i == _pagina else 0.0)
	_compor()


func _process(delta: float) -> void:
	if _virando:
		_avancar_virada(delta)
	_animar_fitas(delta)
	_animar_empurrao(delta)


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

## A página aberta (a de destino só conta quando a virada termina).
func pagina() -> int:
	return _pagina


func virando() -> bool:
	return _virando


## Quadro da folha na tela agora (0 a 9).
func quadro() -> int:
	return _quadro


## Uma página adiante. Se já estiver virando, entra na fila. Devolve false (e o
## caderno dá um empurrãozinho) se não houver mais página.
func proxima() -> bool:
	if _alvo >= PaginasCaderno.quantas() - 1:
		_empurrar(1)
		return false
	ir_para(_alvo + 1)
	return true


func anterior() -> bool:
	if _alvo <= 0:
		_empurrar(-1)
		return false
	ir_para(_alvo - 1)
	return true


## Folheia até a página, uma folha de cada vez.
func ir_para(pagina_pedida: int) -> void:
	_alvo = clampi(pagina_pedida, 0, PaginasCaderno.quantas() - 1)
	if not _virando and _alvo != _pagina:
		_comecar_virada(signi(_alvo - _pagina))


## Abre direto na página, sem virar folha nenhuma.
func ir_para_na_hora(pagina_pedida: int) -> void:
	_pagina = clampi(pagina_pedida, 0, PaginasCaderno.quantas() - 1)
	_alvo = _pagina
	_virando = false
	_quadro = 0
	for i in _fitas_saida.size():
		_fitas_saida[i] = FITA_ABERTA if i == _pagina else 0.0
	_compor()


## Onde estão as fitas agora (px do quadro), já puxadas para fora.
func area_da_fita(i: int) -> Rect2:
	var fita: Rect2 = FITAS[i]
	return Rect2(fita.position, fita.size + Vector2(_saida_da_fita(i), 0.0))


# ─────────────────────────────────────────────────────────────
# A VIRADA
# ─────────────────────────────────────────────────────────────

func _comecar_virada(sentido: int) -> void:
	_sentido = sentido
	_a = _pagina if sentido > 0 else _pagina - 1
	_virando = true
	_tempo = 0.0
	_mostrar_quadro(_quadro_do_passo(0))
	_som.pitch_scale = randf_range(0.92, 1.08)
	_som.play()


func _avancar_virada(delta: float) -> void:
	var destino := _destino()
	_tempo += delta * (ACELERACAO_FOLHEANDO if _alvo != destino else 1.0)
	var acumulado := 0.0
	for passo in TEMPOS.size():
		acumulado += TEMPOS[passo]
		if _tempo < acumulado:
			_mostrar_quadro(_quadro_do_passo(passo))
			return
	_terminar_virada()


func _terminar_virada() -> void:
	_virando = false
	_pagina = _destino()
	_mostrar_quadro(0)
	pagina_mudou.emit(_pagina)
	if _alvo != _pagina:
		_comecar_virada(signi(_alvo - _pagina))


## Página em que a virada atual termina.
func _destino() -> int:
	return _a + 1 if _sentido > 0 else _a


## Indo, os quadros saem do 2 ao 9 (índices 1 a 8); voltando, do 9 ao 2.
func _quadro_do_passo(passo: int) -> int:
	return 1 + passo if _sentido > 0 else TEMPOS.size() - passo


func _mostrar_quadro(novo: int) -> void:
	if novo == _quadro and novo != 0:
		return
	_quadro = novo
	_compor()
	_arte.queue_redraw()


## Põe cada face no seu recorte para o quadro atual (ver o topo do arquivo).
func _compor() -> void:
	if _recortes.is_empty():
		return
	var par_a := _a if _virando else _pagina
	var par_b := _a + 1 if _virando else _pagina
	var faces_a := PaginasCaderno.faces(par_a)
	var faces_b := PaginasCaderno.faces(par_b)
	var folha: Vector2 = VIRANDO[_quadro] if _virando else Vector2.ZERO
	var tem_folha := folha != Vector2.ZERO

	var fim_esquerda := minf(FACE_ESQUERDA.end.x, folha.x) if tem_folha else FACE_ESQUERDA.end.x
	_por_embaixo(0, faces_a[0], FACE_ESQUERDA, FACE_ESQUERDA.position.x, fim_esquerda)
	var inicio_direita := maxf(FACE_DIREITA.position.x, folha.y) if tem_folha \
		else FACE_DIREITA.position.x
	_por_embaixo(1, faces_b[1], FACE_DIREITA, inicio_direita, FACE_DIREITA.end.x)

	var tinta: float = TINTA_NA_FOLHA[_quadro] if tem_folha else 0.0
	if tinta <= 0.0:
		_recortes[2].visible = false
		return
	var frente := _quadro <= ULTIMO_QUADRO_DA_FRENTE
	_por_na_folha(faces_a[1] if frente else faces_b[0],
		FACE_DIREITA if frente else FACE_ESQUERDA, folha, tinta)


func _por_embaixo(i: int, dados: Dictionary, papel: Rect2, x0: float, x1: float) -> void:
	var recorte := _recortes[i]
	recorte.visible = x1 > x0 and not dados.is_empty()
	if not recorte.visible:
		return
	recorte.position = Vector2(x0, papel.position.y)
	recorte.size = Vector2(x1 - x0, papel.size.y)
	var face := _faces[i]
	face.dados = dados
	face.size = papel.size
	face.scale = Vector2.ONE
	face.position = papel.position - recorte.position
	face.modulate.a = 1.0


## A face vai espremida na largura da folha que vira.
func _por_na_folha(dados: Dictionary, papel: Rect2, folha: Vector2, tinta: float) -> void:
	var recorte := _recortes[2]
	recorte.visible = not dados.is_empty()
	if not recorte.visible:
		return
	recorte.position = Vector2(folha.x, papel.position.y)
	recorte.size = Vector2(folha.y - folha.x, papel.size.y)
	var face := _faces[2]
	face.dados = dados
	face.size = papel.size
	face.position = Vector2.ZERO
	face.scale = Vector2((folha.y - folha.x) / papel.size.x, 1.0)
	face.modulate.a = tinta


# ─────────────────────────────────────────────────────────────
# FITAS E EMPURRÃO
# ─────────────────────────────────────────────────────────────

func _animar_fitas(delta: float) -> void:
	var mudou := false
	for i in _fitas_saida.size():
		var alvo := 0.0
		if i == _alvo:
			alvo = FITA_ABERTA
		elif i == _fita_sob_mouse:
			alvo = FITA_SOB_O_MOUSE
		var antes := _saida_da_fita(i)
		_fitas_saida[i] = move_toward(_fitas_saida[i], alvo, VELOCIDADE_FITA * delta)
		mudou = mudou or _saida_da_fita(i) != antes
	if mudou:
		_arte.queue_redraw()


func _saida_da_fita(i: int) -> float:
	return snappedf(_fitas_saida[i], PIXEL_DA_ARTE)


func _empurrar(sentido: int) -> void:
	_velocidade_empurrao = EMPURRAO_VELOCIDADE * sentido


func _animar_empurrao(delta: float) -> void:
	if is_zero_approx(_empurrao) and is_zero_approx(_velocidade_empurrao):
		return
	_velocidade_empurrao += (-_empurrao * MOLA_RIGIDEZ - _velocidade_empurrao * MOLA_AMORTECIMENTO) * delta
	_empurrao += _velocidade_empurrao * delta
	if absf(_empurrao) < 0.25 and absf(_velocidade_empurrao) < 4.0:
		_empurrao = 0.0
		_velocidade_empurrao = 0.0
	_arte.position.x = roundf(_empurrao)


# ─────────────────────────────────────────────────────────────
# DESENHO
# ─────────────────────────────────────────────────────────────

func _desenhar_arte() -> void:
	var origem := Vector2(TAMANHO_QUADRO.x * _quadro, 0.0)
	_arte.draw_texture_rect_region(FOLHA, Rect2(Vector2.ZERO, TAMANHO_QUADRO),
		Rect2(origem, TAMANHO_QUADRO))
	# A fita puxada é a mesma fita redesenhada mais à direita: o pedaço dela que
	# fica para trás continua lá, e ela parece mais comprida.
	for i in FITAS.size():
		var saida := _saida_da_fita(i)
		if saida <= 0.0:
			continue
		var fita: Rect2 = FITAS[i]
		_arte.draw_texture_rect_region(FOLHA, Rect2(fita.position + Vector2(saida, 0.0), fita.size),
			Rect2(fita.position + origem, fita.size))


# ─────────────────────────────────────────────────────────────
# MOUSE
# ─────────────────────────────────────────────────────────────

func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion:
		_passar_mouse(evento.position)
	elif evento is InputEventMouseButton and evento.pressed:
		match evento.button_index:
			MOUSE_BUTTON_LEFT:
				_clicar(evento.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				proxima()
			MOUSE_BUTTON_WHEEL_UP:
				anterior()
		accept_event()


func _clicar(ponto: Vector2) -> void:
	var fita := _fita_em(ponto)
	if fita >= 0:
		ir_para(fita)
	elif FACE_DIREITA.has_point(ponto):
		proxima()
	elif FACE_ESQUERDA.has_point(ponto):
		anterior()
	elif not CAIXA_DESENHO.has_point(ponto):
		fora_clicado.emit()


func _passar_mouse(ponto: Vector2) -> void:
	_fita_sob_mouse = _fita_em(ponto)
	var clicavel := (_fita_sob_mouse >= 0 and _fita_sob_mouse != _alvo) \
		or (FACE_DIREITA.has_point(ponto) and _alvo < PaginasCaderno.quantas() - 1) \
		or (FACE_ESQUERDA.has_point(ponto) and _alvo > 0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clicavel else Control.CURSOR_ARROW


func _fita_em(ponto: Vector2) -> int:
	for i in FITAS.size():
		if area_da_fita(i).has_point(ponto):
			return i
	return -1
