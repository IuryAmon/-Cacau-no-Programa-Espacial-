class_name PainelFornalha
extends CanvasLayer

# --- PAINEL DA FORNALHA (a pirólise: temperatura e entrada de ar) ---
#
# A tela que a retorta abre depois que o fogo pega. São duas etapas, na ordem
# em que o carvão é feito de verdade:
#
#   1. AQUECER   segurando E, o maçarico atiça o fogo e o líquido do
#                termômetro sobe; solto, ele esfria devagar. O fogo tem
#                inércia: não arranca nem apaga na hora. É preciso levar o
#                líquido até a marca (a seta amarela ao lado da escala) e
#                segurá-lo ali um instante — a seta vai se acendendo.
#   2. VEDAR     no ponto, a entrada de ar precisa ser fechada: segurando S, a
#                comporta desce sobre a grade. Enquanto ela está aberta, o O₂
#                que entra alimenta a queima e a temperatura dispara sozinha.
#                Vedada, a madeira carboniza e a tela fecha com sucesso.
#
# Líquido no topo do tubo por TEMPO_ATE_QUEIMAR (aquecer demais ou demorar a
# vedar): a carga queimou e virou cinza. O líquido fica cinza e a tela fecha
# com sucesso = false. ESC/△ desiste a qualquer momento (cancelado = true).
#
# TEXTO, SÓ O TÍTULO E OS CONTROLES. O resto se lê no desenho: o líquido, a
# seta da marca, as moléculas de O₂ passando pela grade e a comporta.
#
# A ARTE: o quadro e o termômetro são pixel art ampliada ESCALA vezes (inteira,
# para o pixel não entortar). A folha do termômetro tem dois sprites lado a
# lado, na mesma posição: o termômetro vazio e só as marcações. O líquido é
# desenhado entre os dois, por isso as marcações ficam por cima dele. O formato
# do líquido sai do próprio sprite (o vidro encolhido RECUO_VIDRO px): se o
# termômetro for redesenhado, só as LINHA_* precisam de ajuste. A seta, a
# grade, a comporta e as moléculas são desenhadas aqui, em pixels do quadro,
# com a paleta dele.
#
# O mundo NÃO pausa: a fornalha continua queimando atrás, e o quadro abre ao
# lado dela, no lado da tela com mais espaço, sem tapar a Cacau nem o fogo. O
# que trava é só o movimento da personagem.

signal terminado(sucesso: bool, cancelado: bool)
## A comporta acabou de fechar (a retorta abafa o fogo do cenário).
signal vedada

enum Etapa { AQUECER, VEDAR, VEDADA, CINZAS }

const QUADRO := preload("res://assets/Lab/fornalha/Quadro Puzzle.png")
const TERMOMETRO := preload("res://assets/Lab/fornalha/termometro e marcações.png")
const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")
const SOM_NO_PONTO := preload("res://sounds/check.mp3")
const SOM_COMPORTA := preload("res://sounds/somPorta_fechando.wav")
const SOM_SUCESSO := preload("res://sounds/PuzzleConcluido2.mp3")
const SOM_CINZAS := preload("res://sounds/AcessoNegado.mp3")

const TITULO := "Temperatura\nda Fornalha"
## {acao} vira a tecla desenhada no teclado e o botão no controle.
const CONTROLES_AQUECER := "{interact} Aquecer      {fechar} Sair"
const CONTROLES_VEDAR := "{ui_down:S} Vedar      {fechar} Sair"

# ── Layout (px do QUADRO, antes da escala) ──
const ESCALA := 3
const TAMANHO_TERMOMETRO := Vector2i(30, 131)
const POS_TERMOMETRO := Vector2i(14, 34)
## Linha do sprite do termômetro onde fica o topo do líquido em 0 e em 1. O 0 é
## o traço de baixo da escala; o 1 enche o tubo.
const LINHA_VAZIO := 101
const LINHA_CHEIO := 3
## A marca: o traço grande da escala que o líquido precisa alcançar, e quantos
## px acima ou abaixo dele ainda contam.
const LINHA_MARCA := 41
const FOLGA_MARCA := 5
## Traço grande da escala (px do sprite), repintado na cor da marca.
const TRACO_MARCA := Rect2i(17, 0, 4, 1)
## Coluna da ponta da seta, logo à direita do tubo.
const X_SETA := 22
const COLUNAS_SETA := 5
## Quanto o vidro tem de espessura: o líquido é o vidro encolhido disto.
const RECUO_VIDRO := 2

const GRADE := Rect2i(54, 136, 24, 24)
const BARRAS_DA_GRADE := 3
const TOPO_TRILHOS := 104
const COMPORTA_ALTURA := 26
const COMPORTA_Y_ABERTA := 108
const COMPORTA_Y_FECHADA := 135
## As moléculas de O₂ (centro, px do quadro) nascem escondidas à direita do
## buraco da grade — só aparecem dali para a esquerda, como se o ar entrasse
## por ela — e somem perto do termômetro.
const O2_X_NASCE := 83.0
const O2_X_SOME := 45.0
const O2_FAIXA_Y := Vector2(143.0, 152.0)
const O2_METADE := Vector2(6.0, 5.0)

const Y_TITULO := 9
const Y_CONTROLES := 167
const TAM_TITULO := 20
const TAM_CONTROLES := 15

## Afastamento entre o quadro e o que ele não pode tapar, e da borda da tela
## (px de tela).
const AFASTAMENTO_DO_FOCO := 56.0
const MARGEM_DA_TELA := 24.0

# ── Temperatura (0 = vazio, 1 = tubo cheio), por segundo ──
const TEMPERATURA_INICIAL := 0.06
## Com o fogo no máximo (E segurado).
const AQUECIMENTO := 0.24
## Perda de calor: quanto mais quente, mais rápido esfria.
const PERDA_BASE := 0.03
const PERDA_PROPORCIONAL := 0.08
## Quão rápido o fogo acompanha a tecla (1 / segundos para ir de 0 a 1).
const RESPOSTA_DO_FOGO := 4.0
## Tempo com o líquido na marca para a temperatura contar como alcançada.
const TEMPO_NA_MARCA := 1.6
## Fora da marca a seta vai se apagando neste ritmo.
const DESCARGA_DA_MARCA := 0.6
## Etapa 2: com a entrada toda aberta, o ar faz a temperatura subir isto.
const SUBIDA_COM_AR := 0.12
## O ar entra aos poucos depois da marca (segundos até a força total).
const RAMPA_DO_AR := 0.6
## Segurando S, segundos da comporta aberta até fechada.
const TEMPO_DA_COMPORTA := 0.55
## Vedada, a temperatura se acomoda na marca neste ritmo.
const ACOMODACAO := 2.5
## Topo do tubo: ficar aqui por TEMPO_ATE_QUEIMAR queima a carga.
const LIMITE_DE_QUEIMA := 0.95
const TEMPO_ATE_QUEIMAR := 1.2

## Uma molécula a cada tanto (s): devagar enquanto aquece, ventando na etapa 2.
const INTERVALO_O2_AQUECER := 0.7
const INTERVALO_O2_VEDAR := 0.4
const VELOCIDADE_O2 := Vector2(16.0, 22.0)
const VELOCIDADE_O2_VEDAR := 1.4

# ── Paleta (a do quadro, mais o líquido, a marca e o O₂ da folha de moléculas) ──
const COR_CONTORNO := Color8(0x1c, 0x1b, 0x21)
const COR_METAL := Color8(0x57, 0x55, 0x5e)
const COR_METAL_ESCURO := Color8(0x49, 0x41, 0x48)
const COR_METAL_CLARO := Color8(0x7a, 0x6e, 0x5e)
const COR_METAL_BRILHO := Color8(0x9c, 0x8f, 0x7c)
const COR_BURACO := Color8(0x12, 0x10, 0x16)
const LIQUIDO := [Color8(0xd2, 0x3c, 0x2c), Color8(0xff, 0x8a, 0x66), Color8(0x8a, 0x1f, 0x26)]
const LIQUIDO_QUENTE := [Color8(0xff, 0x5a, 0x2a), Color8(0xff, 0xd4, 0x9a), Color8(0xc2, 0x30, 0x2a)]
const LIQUIDO_CINZA := [Color8(0x6e, 0x68, 0x72), Color8(0x9a, 0x95, 0xa0), Color8(0x4a, 0x45, 0x50)]
const COR_MARCA := Color8(0xf2, 0xc1, 0x4e)
const COR_MARCA_APAGADA := Color8(0x9a, 0x74, 0x2c)
const COR_MARCA_VAZIA := Color8(0x2b, 0x24, 0x22)
const O2_CORPO := Color8(0x4b, 0x32, 0xe6)
const O2_BRILHO := Color8(0x81, 0x9f, 0xff)
const O2_SOMBRA := Color8(0x24, 0x00, 0xb9)
const O2_CONTORNO := Color8(0x16, 0x00, 0x57)
const COR_TITULO := Color(0.92, 0.94, 0.98)
const COR_CONTROLES := Color(0.72, 0.74, 0.8)

enum Tom { CORPO, BRILHO, SOMBRA }

## O que o quadro não pode tapar (retângulo no MUNDO): a fornalha e a Cacau.
var foco: Rect2 = Rect2()

var _etapa: int = Etapa.AQUECER
var _temperatura: float = TEMPERATURA_INICIAL
var _fogo: float = 0.0
var _soprando: bool = false
var _progresso_marca: float = 0.0
var _tempo_no_limite: float = 0.0
var _tempo_na_etapa: float = 0.0
var _comporta: float = 0.0
## O E que acendeu a fornalha pode chegar ainda apertado: só vale depois de
## solto uma vez.
var _e_liberado: bool = false
var _cinza: float = 0.0
var _clarao_marca: float = 0.0
var _relogio: float = 0.0
var _tremor: float = 0.0
var _deslocamento_tremor := Vector2i.ZERO
var _moleculas: Array[Dictionary] = []
var _proxima_molecula: float = 0.0
var _encerrando: bool = false
## 0 -> 1 na entrada do quadro (e de volta na saída).
var _entrada: float = 0.0

var _fundo: ColorRect = null
var _quadro: Control = null
var _arte: Control = null
var _controles: Label = null

# O líquido cheio, em faixas de uma linha: [linha, x0, largura, tom]. Sai do
# sprite do termômetro na primeira abertura e serve para as seguintes.
static var _faixas_liquido: Array = []
static var _linha_do_bulbo: int = 0
static var _textura_o2: Texture2D = null


static func abrir(dono: Node, foco_no_mundo: Rect2 = Rect2()) -> PainelFornalha:
	var painel := PainelFornalha.new()
	painel.foco = foco_no_mundo
	painel.layer = 15
	dono.get_tree().root.add_child(painel)
	return painel


func _ready() -> void:
	_preparar_desenhos()
	_montar()
	# Controle: a barra de botões aparece (sem cursor, ver usa_cursor).
	add_to_group(CursorVirtual.GRUPO)
	Interacao.marcar_tela_aberta(self, true)
	_e_liberado = not Input.is_action_pressed(Interacao.ACAO)
	_travar_personagem()
	_posicionar()
	create_tween().tween_property(self, "_entrada", 1.0, 0.22)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ─────────────────────────────────────────────────────────────
# O QUE A RETORTA PERGUNTA
# ─────────────────────────────────────────────────────────────

## A Cacau está atiçando o fogo agora? (a pose do maçarico segue isto)
func soprando() -> bool:
	return _soprando


func etapa() -> int:
	return _etapa


func temperatura() -> float:
	return _temperatura


# --- CONTROLE (ver cursor_virtual.gd) ---

## O controle opera o painel direto: nada de cursor, só a barra de botões.
func usa_cursor() -> bool:
	return false


func dicas_do_controle() -> Array:
	if _etapa == Etapa.AQUECER:
		return [[Interacao.ACAO, "AQUECER"], ["fechar", "DESISTIR"]]
	if _etapa == Etapa.VEDAR:
		return [["ui_down", "VEDAR"], ["fechar", "DESISTIR"]]
	return []


# ─────────────────────────────────────────────────────────────
# SIMULAÇÃO
# ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_relogio += delta
	_tremor = maxf(_tremor - delta, 0.0)
	_clarao_marca = maxf(_clarao_marca - delta * 2.5, 0.0)
	_posicionar()

	if not _encerrando:
		# Desistir só vale enquanto ainda há o que fazer: vedada, é carvão.
		if _em_jogo() and Input.is_action_just_pressed("fechar"):
			_fechar(false, true)
			return
		_travar_personagem()
		if not _e_liberado and not Input.is_action_pressed(Interacao.ACAO):
			_e_liberado = true
		_tempo_na_etapa += delta
		match _etapa:
			Etapa.AQUECER:
				_aquecer(delta)
			Etapa.VEDAR:
				_vedar(delta)
			Etapa.VEDADA:
				_temperatura = lerpf(_temperatura, _temperatura_da_marca(), 1.0 - exp(-ACOMODACAO * delta))
		if _em_jogo():
			_vigiar_queima(delta)

	_atualizar_moleculas(delta)
	if _tremor > 0.0 and int(_relogio * 30.0) != int((_relogio - delta) * 30.0):
		_deslocamento_tremor = Vector2i(randi_range(-1, 1), randi_range(-1, 1))
	elif _tremor <= 0.0:
		_deslocamento_tremor = Vector2i.ZERO
	_arte.queue_redraw()


func _aquecer(delta: float) -> void:
	_soprando = _e_liberado and Input.is_action_pressed(Interacao.ACAO)
	_fogo = move_toward(_fogo, 1.0 if _soprando else 0.0, delta * RESPOSTA_DO_FOGO)
	var perda := PERDA_BASE + PERDA_PROPORCIONAL * _temperatura
	_mudar_temperatura((_fogo * AQUECIMENTO - (1.0 - _fogo) * perda) * delta)

	if _na_marca():
		_progresso_marca = minf(_progresso_marca + delta / TEMPO_NA_MARCA, 1.0)
	else:
		_progresso_marca = maxf(_progresso_marca - delta * DESCARGA_DA_MARCA, 0.0)
	if _progresso_marca >= 1.0:
		_entrar_na_vedacao()


func _entrar_na_vedacao() -> void:
	_etapa = Etapa.VEDAR
	_tempo_na_etapa = 0.0
	_soprando = false
	_fogo = 0.0
	_clarao_marca = 1.0
	_tocar(SOM_NO_PONTO)
	Controle.rotular(_controles, CONTROLES_VEDAR, 2.0)


func _vedar(delta: float) -> void:
	if Input.is_action_pressed("ui_down"):
		_comporta = move_toward(_comporta, 1.0, delta / TEMPO_DA_COMPORTA)
	# O ar que passa pela fresta alimenta a queima: a temperatura dispara.
	var rampa := clampf(_tempo_na_etapa / RAMPA_DO_AR, 0.0, 1.0)
	_mudar_temperatura(SUBIDA_COM_AR * (1.0 - _comporta) * rampa * delta)
	if _comporta >= 1.0:
		_concluir()


func _vigiar_queima(delta: float) -> void:
	if _temperatura < LIMITE_DE_QUEIMA:
		_tempo_no_limite = 0.0
		return
	_tempo_no_limite += delta
	_tremor = maxf(_tremor, 0.1)
	if _tempo_no_limite >= TEMPO_ATE_QUEIMAR:
		_queimar()


func _mudar_temperatura(variacao: float) -> void:
	_temperatura = clampf(_temperatura + variacao, 0.0, 1.0)


func _concluir() -> void:
	_etapa = Etapa.VEDADA
	_soprando = false
	_tremor = 0.12
	_tocar(SOM_COMPORTA)
	vedada.emit()
	_esconder_controles()
	await get_tree().create_timer(0.45, false).timeout
	if not is_instance_valid(self) or _encerrando:
		return
	_clarao_marca = 1.0
	_tocar(SOM_SUCESSO, 2.0)
	_fechar(true, false, 1.1)


func _queimar() -> void:
	_etapa = Etapa.CINZAS
	_soprando = false
	_tremor = 0.5
	_tocar(SOM_CINZAS, 2.0)
	_esconder_controles()
	create_tween().tween_property(self, "_cinza", 1.0, 0.5)
	_fechar(false, false, 1.3)


func _esconder_controles() -> void:
	create_tween().tween_property(_controles, "modulate:a", 0.0, 0.2)


func _fechar(sucesso: bool, cancelado: bool, espera: float = 0.0) -> void:
	if _encerrando:
		return
	_encerrando = true
	_soprando = false
	if espera > 0.0:
		await get_tree().create_timer(espera, false).timeout
		if not is_instance_valid(self):
			return
	var saida := create_tween()
	saida.tween_property(self, "_entrada", 0.0, 0.12 if cancelado else 0.18)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await saida.finished
	if not is_instance_valid(self):
		return

	Interacao.marcar_tela_aberta(self, false)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = true
	terminado.emit(sucesso, cancelado)
	queue_free()


# ─────────────────────────────────────────────────────────────
# APOIO
# ─────────────────────────────────────────────────────────────

## A personagem fica presa durante todo o painel. É reafirmado a cada quadro
## porque largar a pose do maçarico devolveria o controle sozinho.
func _travar_personagem() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = false


func _em_jogo() -> bool:
	return _etapa == Etapa.AQUECER or _etapa == Etapa.VEDAR


func _nivel() -> int:
	return roundi(lerpf(LINHA_VAZIO, LINHA_CHEIO, _temperatura))


func _na_marca() -> bool:
	return absi(_nivel() - LINHA_MARCA) <= FOLGA_MARCA


func _temperatura_da_marca() -> float:
	return float(LINHA_VAZIO - LINHA_MARCA) / float(LINHA_VAZIO - LINHA_CHEIO)


func _y_comporta() -> int:
	return roundi(lerpf(COMPORTA_Y_ABERTA, COMPORTA_Y_FECHADA, _comporta))


## Som solto na raiz: continua tocando depois que o painel fecha.
func _tocar(som: AudioStream, volume_db: float = 0.0) -> void:
	var tocador := AudioStreamPlayer.new()
	tocador.stream = som
	tocador.volume_db = volume_db
	get_tree().root.add_child(tocador)
	tocador.finished.connect(tocador.queue_free)
	tocador.play()


# ─────────────────────────────────────────────────────────────
# MONTAGEM E POSIÇÃO
# ─────────────────────────────────────────────────────────────

func _montar() -> void:
	_fundo = ColorRect.new()
	_fundo.color = Color(0, 0, 0, 0.25)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fundo)

	_quadro = Control.new()
	_quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quadro.size = QUADRO.get_size() * ESCALA
	add_child(_quadro)

	# A arte é desenhada em px do quadro e ampliada; os textos ficam fora da
	# escala, para a fonte sair nítida.
	_arte = Control.new()
	_arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arte.size = QUADRO.get_size()
	_arte.scale = Vector2(ESCALA, ESCALA)
	_arte.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_arte.draw.connect(_desenhar)
	_quadro.add_child(_arte)

	var titulo := _novo_label(TAM_TITULO, COR_TITULO)
	titulo.name = "Titulo"
	titulo.text = TITULO
	titulo.position = Vector2(0, Y_TITULO * ESCALA)
	titulo.size = Vector2(_quadro.size.x, (POS_TERMOMETRO.y - Y_TITULO) * ESCALA)
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quadro.add_child(titulo)

	_controles = _novo_label(TAM_CONTROLES, COR_CONTROLES)
	_controles.name = "Controles"
	_controles.position = Vector2(0, Y_CONTROLES * ESCALA)
	_controles.size = Vector2(_quadro.size.x, (QUADRO.get_height() - 5 - Y_CONTROLES) * ESCALA)
	_controles.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quadro.add_child(_controles)
	# Tecla desenhada no teclado, botão no controle (troca sozinho).
	Controle.rotular(_controles, CONTROLES_AQUECER, 2.0)


func _novo_label(tamanho: int, cor: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONTE)
	label.add_theme_font_size_override("font_size", tamanho)
	label.add_theme_color_override("font_color", cor)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("outline_size", 3)
	return label


## O quadro fica ao lado do foco (fornalha + Cacau), no lado da tela com mais
## espaço, e no meio da altura. Refeito a cada quadro: se a câmera se mexer,
## ele acompanha.
func _posicionar() -> void:
	var tela := get_viewport().get_visible_rect().size
	var tamanho := _quadro.size
	var x := (tela.x - tamanho.x) * 0.5
	if foco.has_area():
		var na_tela := get_viewport().get_canvas_transform() * foco
		var espaco_esquerda := na_tela.position.x
		var espaco_direita := tela.x - na_tela.end.x
		if espaco_esquerda >= espaco_direita:
			x = na_tela.position.x - AFASTAMENTO_DO_FOCO - tamanho.x
		else:
			x = na_tela.end.x + AFASTAMENTO_DO_FOCO
	x = clampf(x, MARGEM_DA_TELA, tela.x - tamanho.x - MARGEM_DA_TELA)
	var y := (tela.y - tamanho.y) * 0.5 + (1.0 - _entrada) * 18.0
	# O quadro inteiro só treme no baque da comporta e na queima; no limite de
	# temperatura quem treme é o termômetro (ver _desenhar).
	var tremor := Vector2.ZERO if _em_jogo() else Vector2(_deslocamento_tremor * ESCALA)
	_quadro.position = (Vector2(x, y) + tremor).round()
	_quadro.modulate.a = _entrada
	_fundo.modulate.a = _entrada


# ─────────────────────────────────────────────────────────────
# MOLÉCULAS DE O₂
# ─────────────────────────────────────────────────────────────

func _atualizar_moleculas(delta: float) -> void:
	_proxima_molecula -= delta
	if _em_jogo() and _proxima_molecula <= 0.0:
		var vedando := _etapa == Etapa.VEDAR
		_proxima_molecula = INTERVALO_O2_VEDAR if vedando else INTERVALO_O2_AQUECER
		_moleculas.append({
			"x": O2_X_NASCE,
			"y": randf_range(O2_FAIXA_Y.x, O2_FAIXA_Y.y),
			"v": randf_range(VELOCIDADE_O2.x, VELOCIDADE_O2.y) * (VELOCIDADE_O2_VEDAR if vedando else 1.0),
			"fase": randf() * TAU,
		})

	# A comporta barra quem ainda não entrou e está na altura dela: essa
	# molécula nem chega a aparecer (ver _desenhar_grade).
	var fundo_comporta := float(_y_comporta() + COMPORTA_ALTURA)
	var entrada := float(_x_do_buraco_direita())
	var seguem: Array[Dictionary] = []
	for m in _moleculas:
		var ainda_fora: bool = m["x"] - O2_METADE.x >= entrada
		m["x"] -= m["v"] * delta
		if ainda_fora and m["x"] - O2_METADE.x < entrada and m["y"] < fundo_comporta:
			continue
		if m["x"] > O2_X_SOME:
			seguem.append(m)
	_moleculas = seguem


## Borda direita do buraco da grade: é daí para a esquerda que o ar aparece.
func _x_do_buraco_direita() -> int:
	return GRADE.end.x - 2


# ─────────────────────────────────────────────────────────────
# DESENHO (px do quadro; o _arte amplia)
# ─────────────────────────────────────────────────────────────

func _desenhar() -> void:
	var a := _arte
	a.draw_texture(QUADRO, Vector2.ZERO)

	var pos := Vector2(POS_TERMOMETRO)
	if _em_jogo() and _tempo_no_limite > 0.0:
		pos += Vector2(_deslocamento_tremor)
	var tamanho := Vector2(TAMANHO_TERMOMETRO)
	a.draw_texture_rect_region(TERMOMETRO, Rect2(pos, tamanho), Rect2(Vector2.ZERO, tamanho))
	_desenhar_liquido(a, pos)
	a.draw_texture_rect_region(TERMOMETRO, Rect2(pos, tamanho),
		Rect2(Vector2(TAMANHO_TERMOMETRO.x, 0), tamanho))
	_desenhar_marca(a, pos)

	_desenhar_grade(a)
	_desenhar_comporta(a)


func _desenhar_liquido(a: Control, pos: Vector2) -> void:
	var cores := _cores_do_liquido()
	var nivel := _nivel()
	for faixa in _faixas_liquido:
		var linha: int = faixa[0]
		if linha < nivel:
			continue
		var tom: int = faixa[3]
		# A linha de cima do líquido no tubo é o menisco: mais clara.
		if linha == nivel and linha < _linha_do_bulbo:
			tom = Tom.BRILHO
		a.draw_rect(Rect2(pos.x + faixa[1], pos.y + linha, faixa[2], 1), cores[tom])


func _cores_do_liquido() -> Array:
	var quente := smoothstep(0.72, 0.97, _temperatura)
	var cores := []
	for i in 3:
		var cor: Color = (LIQUIDO[i] as Color).lerp(LIQUIDO_QUENTE[i], quente)
		if _tempo_no_limite > 0.0 and _etapa != Etapa.CINZAS:
			cor = cor.lerp(Color.WHITE, 0.3 * (0.5 + 0.5 * sin(_relogio * 22.0)))
		cores.append(cor.lerp(LIQUIDO_CINZA[i], _cinza))
	return cores


## A seta amarela à direita do tubo, apontando o traço da marca. Começa vazada
## e vai se enchendo, da base para a ponta, enquanto o líquido fica na marca;
## na marca, ela pulsa.
func _desenhar_marca(a: Control, pos: Vector2) -> void:
	var centro := pos + Vector2(X_SETA, LINHA_MARCA)
	# Só as colunas de dentro enchem: a ponta e a base são borda.
	var miolo := COLUNAS_SETA - 2
	var cheias := miolo if _etapa != Etapa.AQUECER else ceili(_progresso_marca * miolo - 0.001)
	var cor := COR_MARCA
	if _etapa == Etapa.AQUECER and _na_marca():
		cor = COR_MARCA.lerp(Color.WHITE, 0.3 * (0.5 + 0.5 * sin(_relogio * 12.0)))
	cor = cor.lerp(Color.WHITE, _clarao_marca)
	if _etapa == Etapa.CINZAS:
		cor = cor.lerp(COR_MARCA_APAGADA, _cinza)

	# Contorno: a seta inteira 1 px maior, em volta.
	for i in range(-1, COLUNAS_SETA + 1):
		var meia := clampi(i, -1, COLUNAS_SETA - 1) + 1
		a.draw_rect(Rect2(centro.x + i, centro.y - meia, 1, meia * 2 + 1), COR_CONTORNO)
	for i in COLUNAS_SETA:
		var coluna := Rect2(centro.x + i, centro.y - i, 1, i * 2 + 1)
		var borda := i == 0 or i == COLUNAS_SETA - 1
		if borda or i >= COLUNAS_SETA - 1 - cheias:
			a.draw_rect(coluna, cor)
		else:
			a.draw_rect(coluna, COR_MARCA_VAZIA)
			a.draw_rect(Rect2(coluna.position, Vector2.ONE), cor)
			a.draw_rect(Rect2(coluna.position.x, coluna.end.y - 1.0, 1, 1), cor)
	# O traço da escala que é a marca, na cor dela.
	a.draw_rect(Rect2(pos + Vector2(TRACO_MARCA.position.x, LINHA_MARCA), Vector2(TRACO_MARCA.size)), cor)


## A entrada de ar: moldura, buraco escuro, as moléculas passando e as barras
## da grade por cima delas (é isso que as faz "atravessar" a grade). Barras em
## pé, e não aletas deitadas: a molécula anda de lado e continua inteira à
## vista entre uma barra e outra.
func _desenhar_grade(a: Control) -> void:
	var g := Rect2(GRADE)
	a.draw_rect(g, COR_CONTORNO)
	a.draw_rect(Rect2(g.position + Vector2(1, 1), g.size - Vector2(2, 2)), COR_METAL_ESCURO)
	a.draw_rect(Rect2(g.position + Vector2(1, 1), Vector2(g.size.x - 2, 1)), COR_METAL)
	a.draw_rect(Rect2(g.position + Vector2(1, 1), Vector2(1, g.size.y - 2)), COR_METAL)
	var buraco := Rect2(g.position + Vector2(2, 2), g.size - Vector2(4, 4))
	a.draw_rect(buraco, COR_BURACO)

	# Cada molécula só aparece da borda direita do buraco para a esquerda: o
	# pedaço que ainda está "lá fora" é cortado.
	var entrada := float(_x_do_buraco_direita())
	var tamanho_o2 := _textura_o2.get_size()
	for m in _moleculas:
		var y: float = m["y"] + sin(_relogio * 3.0 + m["fase"]) * 0.7
		var canto := (Vector2(m["x"], y) - O2_METADE).round()
		var largura := clampf(entrada - canto.x, 0.0, tamanho_o2.x)
		if largura <= 0.0:
			continue
		var alfa := clampf((m["x"] - O2_X_SOME) / 6.0, 0.0, 1.0)
		a.draw_texture_rect_region(_textura_o2, Rect2(canto, Vector2(largura, tamanho_o2.y)),
			Rect2(Vector2.ZERO, Vector2(largura, tamanho_o2.y)), Color(1, 1, 1, alfa))

	for i in BARRAS_DA_GRADE:
		var x := buraco.position.x + roundf(buraco.size.x * (i + 1) / (BARRAS_DA_GRADE + 1)) - 1.0
		a.draw_rect(Rect2(x, buraco.position.y, 1, buraco.size.y), COR_METAL)
		a.draw_rect(Rect2(x + 1.0, buraco.position.y, 1, buraco.size.y), COR_CONTORNO)


## A comporta: uma chapa rebitada que desce pelos trilhos até cobrir a grade.
## Na etapa de vedar, o contorno pisca na cor da marca, chamando o S.
func _desenhar_comporta(a: Control) -> void:
	var esquerda := float(GRADE.position.x)
	var largura := float(GRADE.size.x)
	var altura_trilho := float(COMPORTA_Y_FECHADA + COMPORTA_ALTURA - TOPO_TRILHOS)
	for x in [esquerda - 3.0, esquerda + largura]:
		a.draw_rect(Rect2(x, TOPO_TRILHOS, 3, altura_trilho), COR_CONTORNO)
		a.draw_rect(Rect2(x + 1.0, TOPO_TRILHOS + 1, 1, altura_trilho - 2.0), COR_METAL)
	# Travessa no alto dos trilhos.
	a.draw_rect(Rect2(esquerda - 3.0, TOPO_TRILHOS, largura + 6.0, 3), COR_CONTORNO)
	a.draw_rect(Rect2(esquerda - 2.0, TOPO_TRILHOS + 1, largura + 4.0, 1), COR_METAL)

	var y := float(_y_comporta())
	var contorno := COR_CONTORNO
	if _etapa == Etapa.VEDAR and fmod(_tempo_na_etapa, 0.6) < 0.36:
		contorno = COR_MARCA
	a.draw_rect(Rect2(esquerda, y, largura, COMPORTA_ALTURA), contorno)
	a.draw_rect(Rect2(esquerda + 1, y + 1, largura - 2, COMPORTA_ALTURA - 2), COR_METAL_CLARO)
	a.draw_rect(Rect2(esquerda + 1, y + 1, largura - 2, 1), COR_METAL_BRILHO)
	a.draw_rect(Rect2(esquerda + 1, y + COMPORTA_ALTURA - 2, largura - 2, 1), COR_METAL_ESCURO)
	for nervura in [9.0, 16.0]:
		a.draw_rect(Rect2(esquerda + 3, y + nervura, largura - 6, 1), COR_METAL_ESCURO)
		a.draw_rect(Rect2(esquerda + 3, y + nervura + 1.0, largura - 6, 1), COR_METAL_BRILHO)
	for rebite in [Vector2(2, 3), Vector2(largura - 3, 3), Vector2(2, COMPORTA_ALTURA - 4),
			Vector2(largura - 3, COMPORTA_ALTURA - 4)]:
		a.draw_rect(Rect2(Vector2(esquerda, y) + rebite, Vector2.ONE), COR_CONTORNO)


# ─────────────────────────────────────────────────────────────
# DESENHOS FEITOS UMA VEZ (líquido e molécula)
# ─────────────────────────────────────────────────────────────

static func _preparar_desenhos() -> void:
	if _faixas_liquido.is_empty():
		_montar_liquido()
	if _textura_o2 == null:
		_textura_o2 = _montar_o2()


## O líquido cheio, tirado do sprite vazio: o vidro encolhido RECUO_VIDRO px
## (num disco, para o bulbo continuar redondo). No tubo, uma coluna de brilho
## à esquerda e sombra à direita; no bulbo, um reflexo no alto à esquerda e
## sombra na borda de baixo à direita.
static func _montar_liquido() -> void:
	var imagem := TERMOMETRO.get_image()
	if imagem.is_compressed():
		imagem.decompress()
	var w := TAMANHO_TERMOMETRO.x
	var h := TAMANHO_TERMOMETRO.y
	var vidro := PackedByteArray()
	vidro.resize(w * h)
	for y in h:
		for x in w:
			vidro[y * w + x] = 1 if imagem.get_pixel(x, y).a > 0.5 else 0

	var r := RECUO_VIDRO
	var miolo := PackedByteArray()
	miolo.resize(w * h)
	for y in h:
		for x in w:
			if vidro[y * w + x] == 0:
				continue
			var dentro := true
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if dx * dx + dy * dy > r * r:
						continue
					var vx := x + dx
					var vy := y + dy
					if vx < 0 or vy < 0 or vx >= w or vy >= h or vidro[vy * w + vx] == 0:
						dentro = false
			miolo[y * w + x] = 1 if dentro else 0

	# O tubo tem a largura da linha mais alta do miolo; o bulbo começa na
	# primeira linha mais larga que isso.
	var largura_tubo := -1
	_linha_do_bulbo = h
	var caixa_bulbo := Rect2i()
	for y in h:
		var n := 0
		for x in w:
			n += miolo[y * w + x]
		if n == 0:
			continue
		if largura_tubo < 0:
			largura_tubo = n
		elif n > largura_tubo and _linha_do_bulbo == h:
			_linha_do_bulbo = y
	for y in range(_linha_do_bulbo, h):
		for x in w:
			if miolo[y * w + x] == 1:
				var p := Rect2i(x, y, 1, 1)
				caixa_bulbo = p if caixa_bulbo.size == Vector2i.ZERO else caixa_bulbo.merge(p)
	var centro := Vector2(caixa_bulbo.position) + Vector2(caixa_bulbo.size) * 0.5
	var raio := maxf(caixa_bulbo.size.x * 0.5, 1.0)

	_faixas_liquido.clear()
	for y in h:
		var x0 := -1
		var x1 := -1
		for x in w:
			if miolo[y * w + x] == 1:
				if x0 < 0:
					x0 = x
				x1 = x
		if x0 < 0:
			continue
		var tons: Array[int] = []
		for x in range(x0, x1 + 1):
			tons.append(_tom_do_liquido(x, y, x0, x1, centro, raio))
		# Junta pixels vizinhos do mesmo tom numa faixa só.
		var inicio := 0
		for i in range(1, tons.size() + 1):
			if i == tons.size() or tons[i] != tons[inicio]:
				_faixas_liquido.append([y, x0 + inicio, i - inicio, tons[inicio]])
				inicio = i


static func _tom_do_liquido(x: int, y: int, x0: int, x1: int, centro: Vector2, raio: float) -> int:
	if y < _linha_do_bulbo:
		if x == x0 + 1:
			return Tom.BRILHO
		if x == x1:
			return Tom.SOMBRA
		return Tom.CORPO
	var n := (Vector2(x, y) + Vector2(0.5, 0.5) - centro) / raio
	if n.distance_to(Vector2(-0.42, -0.42)) < 0.22:
		return Tom.BRILHO
	if n.length() > 0.72 and n.dot(Vector2(0.7071, 0.7071)) > 0.35:
		return Tom.SOMBRA
	return Tom.CORPO


## A molécula de O₂ em pixel art: duas esferas azuis (as cores do oxigênio na
## folha de moléculas), a de trás mais baixa, com contorno escuro.
static func _montar_o2() -> Texture2D:
	var imagem := Image.create(13, 11, false, Image.FORMAT_RGBA8)
	var raio := 3.4
	for centro in [Vector2(4.5, 6.5), Vector2(8.5, 4.5)]:
		for y in imagem.get_height():
			for x in imagem.get_width():
				var n: Vector2 = (Vector2(x + 0.5, y + 0.5) - centro) / raio
				if n.length() > 1.0:
					continue
				var cor := O2_CORPO
				if n.distance_to(Vector2(-0.35, -0.4)) < 0.34:
					cor = O2_BRILHO
				elif n.dot(Vector2(0.6, 0.8)) > 0.4:
					cor = O2_SOMBRA
				imagem.set_pixel(x, y, cor)
	var contorno: Array[Vector2i] = []
	for y in imagem.get_height():
		for x in imagem.get_width():
			if imagem.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var v: Vector2i = Vector2i(x, y) + d
				if v.x >= 0 and v.y >= 0 and v.x < imagem.get_width() and v.y < imagem.get_height() \
						and imagem.get_pixelv(v).a > 0.0 and imagem.get_pixelv(v) != O2_CONTORNO:
					contorno.append(Vector2i(x, y))
					break
	for p in contorno:
		imagem.set_pixelv(p, O2_CONTORNO)
	return ImageTexture.create_from_image(imagem)
