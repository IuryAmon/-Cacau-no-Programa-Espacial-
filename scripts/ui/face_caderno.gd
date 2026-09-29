class_name FaceCaderno
extends Control

# --- UMA FACE DO CADERNO (a tipografia) ---
#
# Desenha uma face de PaginasCaderno no papel. O tamanho do nó é o papel da
# face (CadernoLivro.FACE_ESQUERDA / FACE_DIREITA), e o texto fica dentro da
# MARGEM, longe do fio da borda.
#
# Tinta de caneta sobre o papel da arte, na fonte do jogo. A ari-w9500 tem
# todas as letras de largura igual (0,6 do tamanho): no TAM_VERSO, o verso mais
# comprido do poema (33 letras) ainda cabe na face mais estreita.
#
# O CadernoLivro espreme este nó (scale.x) e o apaga (modulate) enquanto ele
# vai na folha que vira; aqui nada disso importa.

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

const TAM_VERSO := 20
const TAM_TITULO := 40
const ENTRELINHA_VERSO := 36.0
const MARGEM := Vector2(24, 24)
## A estrofe fica um pouco acima do meio: o meio "de olho" de uma página é mais
## alto que o meio medido.
const SUBIDA_OPTICA := 14.0

const TINTA := Color8(0x3d, 0x2a, 0x22)
const TINTA_TITULO := Color8(0x8e, 0x3b, 0x2c)
const TINTA_FRACA := Color8(0x8a, 0x6d, 0x52)

## O que está escrito nesta face (ver PaginasCaderno). Vazio = folha em branco.
var dados: Dictionary = {}:
	set(valor):
		if valor == dados:
			return
		dados = valor
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Largura que o texto pode ocupar.
func largura_util() -> float:
	return size.x - MARGEM.x * 2.0


func _draw() -> void:
	match String(dados.get("tipo", "")):
		"rosto":
			_desenhar_rosto()
		"estrofe":
			_desenhar_estrofe()


func _desenhar_rosto() -> void:
	var meio := size.x * 0.5
	var y := size.y * 0.29
	_centrado(String(dados.get("titulo", "")), y, TAM_TITULO, TINTA_TITULO)
	_enfeite(Vector2(meio, y + 34.0), 96.0, TINTA_TITULO)
	y += 92.0
	_centrado(String(dados.get("autor", "")), y, TAM_VERSO, TINTA)

	y = size.y * 0.58
	for linha in dados.get("epigrafe", []):
		_centrado(String(linha), y, TAM_VERSO, TINTA_FRACA)
		y += ENTRELINHA_VERSO
	var autor_epigrafe := String(dados.get("autor_epigrafe", ""))
	if not autor_epigrafe.is_empty():
		_centrado("— " + autor_epigrafe, y + 6.0, TAM_VERSO, TINTA_FRACA)

	_centrado(String(dados.get("obra", "")), size.y - MARGEM.y - 12.0, TAM_VERSO, TINTA_FRACA)


func _desenhar_estrofe() -> void:
	var versos: Array = dados.get("versos", [])
	if versos.is_empty():
		return
	var mais_largo := 0.0
	for verso in versos:
		mais_largo = maxf(mais_largo, _largura(String(verso), TAM_VERSO))
	var ascendente := FONTE.get_ascent(TAM_VERSO)
	var altura := ENTRELINHA_VERSO * (versos.size() - 1) + ascendente

	# Bloco alinhado à esquerda, centrado pela linha mais larga — do jeito que
	# poema se imprime. O arremate do fim vai embaixo sem mexer no bloco: as
	# estrofes das duas faces ficam na mesma altura.
	var x := roundf((size.x - mais_largo) * 0.5)
	var y := roundf((size.y - altura) * 0.5 - SUBIDA_OPTICA + ascendente)
	for verso in versos:
		draw_string(FONTE, Vector2(x, y), String(verso), HORIZONTAL_ALIGNMENT_LEFT, -1,
			TAM_VERSO, TINTA)
		y += ENTRELINHA_VERSO
	if dados.get("fim", false):
		_enfeite(Vector2(size.x * 0.5, y + ENTRELINHA_VERSO * 0.25), 56.0, TINTA_FRACA)


func _centrado(texto: String, base: float, tamanho: int, cor: Color) -> void:
	if texto.is_empty():
		return
	var x := roundf((size.x - _largura(texto, tamanho)) * 0.5)
	draw_string(FONTE, Vector2(x, roundf(base)), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)


## Um fio com um losango no meio, no pixel da letra (2 px).
func _enfeite(centro: Vector2, meia_largura: float, cor: Color) -> void:
	centro = centro.round()
	var fio := 2.0
	var losango := 8.0
	draw_rect(Rect2(centro.x - meia_largura, centro.y - fio * 0.5,
		meia_largura - losango - 4.0, fio), cor)
	draw_rect(Rect2(centro.x + losango + 4.0, centro.y - fio * 0.5,
		meia_largura - losango - 4.0, fio), cor)
	draw_colored_polygon(PackedVector2Array([centro + Vector2(0, -losango),
		centro + Vector2(losango, 0), centro + Vector2(0, losango),
		centro + Vector2(-losango, 0)]), cor)


static func _largura(texto: String, tamanho: int) -> float:
	return FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
