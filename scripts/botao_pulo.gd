@tool
extends Node2D

# --- "ESPAÇO OU ✕ PARA PULAR" (o primeiro vão do world1) ---
#
# O irmão do BotaoMoviment ("Pressione WASD ou o direcional para
# movimentar-se"): escrito no cenário, em cima do primeiro vão, com a barra de
# ESPAÇO e o ✕ do controle desenhados. A linha de cima ("texto_de_cima") está
# vazia; escrevendo algo nela no Inspetor, ela volta.
#
#   [ ESPAÇO ]  ou  (✕)
#   para pular
#
# A barra de espaço sai da mesma folha das outras teclas
# (assets/UI/gdb-keyboard-2.png, ver BotoesControle) e o ✕, da folha do
# controle. Como no BotaoMoviment, elas reagem ao jogador: apertou, afundam e
# ficam afundadas enquanto ele segura; soltou, voltam.
#
# A frase só aparece com a Cacau por perto: chegando, ela surge num fade in;
# indo embora (para os lados, ou bem mais para cima ou para baixo), some num
# fade out. No editor ela fica sempre à vista.
#
# PARA MEXER: arraste o nó (a posição é o meio do bloco). Os números abaixo
# aparecem no Inspetor; no editor o bloco já aparece como fica no jogo.

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

## A barra de espaço na folha do teclado (com 4 px de folga de cada lado,
## como as teclas de 16 px). Os quadros de apertar descem 112 px.
const REGIAO_ESPACO := Rect2(96, 96, 112, 16)
## Quadro em que a tecla/botão fica afundado e o de "soltando".
const QUADRO_APERTADO := 2
const QUADRO_SOLTANDO := 3
const DURACAO_SOLTANDO := 0.08

@export var texto_de_cima: String = "":
	set(valor):
		texto_de_cima = valor
		queue_redraw()
@export var texto_de_baixo: String = "para pular":
	set(valor):
		texto_de_baixo = valor
		queue_redraw()
## O mesmo tamanho dos textos do BotaoMoviment.
@export var tamanho_da_letra: int = 22:
	set(valor):
		tamanho_da_letra = valor
		queue_redraw()
@export var escala_da_barra: float = 1.4:
	set(valor):
		escala_da_barra = valor
		queue_redraw()
@export var escala_do_botao: float = 2.75:
	set(valor):
		escala_do_botao = valor
		queue_redraw()
## Distância entre as linhas (px do mundo).
@export var entrelinha: float = 52.0:
	set(valor):
		entrelinha = valor
		queue_redraw()

@export_group("Aparecer")
## A Cacau a menos disto do meio da frase, na horizontal (px do mundo), e a
## frase aparece (ver AparecerPerto).
@export var distancia_para_aparecer: float = AparecerPerto.DISTANCIA
## Ela some só depois de a Cacau se afastar um pouco mais que isso: parada
## bem no limite, a frase não fica piscando.
@export var folga_para_sumir: float = AparecerPerto.FOLGA
## Mais longe que isto na vertical (outro andar do mapa), não aparece.
@export var altura_para_aparecer: float = AparecerPerto.ALTURA
## Duração do fade in e do fade out (segundos).
@export var duracao_do_fade: float = AparecerPerto.DURACAO
@export_group("")

var _quadro_espaco := 0
var _quadro_cruz := 0
var _soltando_espaco := 0.0
var _soltando_cruz := 0.0
var _a_vista := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not Engine.is_editor_hint():
		# Começa apagada mesmo com a Cacau perto: ela surge num fade in.
		modulate.a = 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_a_vista = AparecerPerto.cacau_perto(get_tree(), global_position, distancia_para_aparecer,
		altura_para_aparecer, folga_para_sumir, _a_vista)
	modulate.a = AparecerPerto.alfa(modulate.a, _a_vista, delta, duracao_do_fade)
	var espaco := _quadro(Input.is_physical_key_pressed(KEY_SPACE), _quadro_espaco, delta, true)
	var cruz := _quadro(Input.is_joy_button_pressed(0, JOY_BUTTON_A), _quadro_cruz, delta, false)
	if espaco != _quadro_espaco or cruz != _quadro_cruz:
		_quadro_espaco = espaco
		_quadro_cruz = cruz
		queue_redraw()


## Segurando: afundada. Acabou de soltar: um instante no quadro de "soltando"
## e de volta ao solto.
func _quadro(apertado: bool, atual: int, delta: float, e_espaco: bool) -> int:
	if apertado:
		_set_soltando(e_espaco, DURACAO_SOLTANDO)
		return QUADRO_APERTADO
	if atual == QUADRO_APERTADO:
		return QUADRO_SOLTANDO
	if atual == QUADRO_SOLTANDO:
		var resta := (_soltando_espaco if e_espaco else _soltando_cruz) - delta
		_set_soltando(e_espaco, resta)
		return QUADRO_SOLTANDO if resta > 0.0 else 0
	return 0


func _set_soltando(e_espaco: bool, valor: float) -> void:
	if e_espaco:
		_soltando_espaco = valor
	else:
		_soltando_cruz = valor


func _draw() -> void:
	_texto_no_meio(texto_de_cima, -entrelinha)
	_texto_no_meio(texto_de_baixo, entrelinha)

	# A linha do meio: [ESPAÇO]  ou  (✕), centrada.
	var barra := REGIAO_ESPACO.size * escala_da_barra
	var botao := Vector2(16, 16) * escala_do_botao
	var ou := "ou"
	var largura_ou := FONTE.get_string_size(ou, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho_da_letra).x
	var folga := 18.0
	var total := barra.x + folga + largura_ou + folga + botao.x
	var x := -total * 0.5

	var regiao := Rect2(REGIAO_ESPACO.position + Vector2(0, 112) * _quadro_espaco, REGIAO_ESPACO.size)
	draw_texture_rect_region(BotoesControle.FOLHA_TECLADO, Rect2(Vector2(x, -barra.y * 0.5), barra), regiao)
	x += barra.x + folga
	draw_string(FONTE, Vector2(x, _linha_de_base(0.0)), ou, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho_da_letra)
	x += largura_ou + folga
	var cruz := BotoesControle.icone("cruz", _quadro_cruz)
	if cruz != null:
		draw_texture_rect(cruz, Rect2(Vector2(x, -botao.y * 0.5), botao), false)


func _texto_no_meio(texto: String, centro_y: float) -> void:
	var largura := FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho_da_letra).x
	draw_string(FONTE, Vector2(-largura * 0.5, _linha_de_base(centro_y)), texto,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho_da_letra)


## A linha de base que deixa o texto com o meio em "centro_y".
func _linha_de_base(centro_y: float) -> float:
	return centro_y + (FONTE.get_ascent(tamanho_da_letra) - FONTE.get_descent(tamanho_da_letra)) * 0.5
