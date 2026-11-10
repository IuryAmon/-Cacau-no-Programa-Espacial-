extends Control

# --- O NOME DO JOGO ---
#
# As caixas Ca, Ca, U e o NO PROGRAMA ESPACIAL embaixo, desenhados como no menu
# principal (os elementos, a escala, os vãos e o subtítulo vêm de lá): mudou o
# nome no menu, muda aqui. O desenho fica no meio deste Control, um pouco
# acima ("subida"), e acende e apaga pelo "alfa".
#
# Quem usa: a abertura da história (abertura_da_historia.gd), que mostra o
# nome no céu do world1 antes de a câmera descer até a Cacau.

const MENU := preload("res://scripts/menu_principal.gd")
const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

## O quanto o nome aparece (0 = nada, 1 = inteiro).
@export_range(0.0, 1.0, 0.01) var alfa := 1.0:
	set(v):
		alfa = v
		queue_redraw()
## Quanto o meio do nome fica acima do meio da tela, em frações da altura.
@export_range(-0.5, 0.5, 0.01) var subida := 0.08:
	set(v):
		subida = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	desenhar(self, Vector2(size.x * 0.5, size.y * (0.5 - subida)), alfa)


## O tamanho do nome inteiro: as caixas e o subtítulo embaixo delas.
static func tamanho() -> Vector2:
	var caixa := CaixaElemento.tamanho_na_escala(MENU.ESCALA_DO_NOME)
	var n: int = MENU.ELEMENTOS_DO_NOME.size()
	return Vector2(caixa.x * n + MENU.ENTRE_CAIXAS * (n - 1), caixa.y + MENU.ATE_O_SUBTITULO)


## Desenha o nome em "ci", com o meio em "meio".
static func desenhar(ci: CanvasItem, meio: Vector2, alfa: float) -> void:
	if alfa <= 0.0:
		return
	var caixa := CaixaElemento.tamanho_na_escala(MENU.ESCALA_DO_NOME)
	var total := tamanho()
	var canto := (meio - total * 0.5).round()
	for i in MENU.ELEMENTOS_DO_NOME.size():
		var x := canto.x + i * (caixa.x + MENU.ENTRE_CAIXAS)
		CaixaElemento.desenhar(ci, Vector2(x, canto.y), int(MENU.ELEMENTOS_DO_NOME[i]), MENU.ESCALA_DO_NOME,
			true, true, EstiloHUD.PAPEL, Color(0, 0, 0, 0), Color(0, 0, 0, 0), alfa, true)
	var subtitulo: String = MENU.SUBTITULO
	var tam: int = MENU.TAM_SUBTITULO
	var largura := FONTE.get_string_size(subtitulo, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	EstiloHUD.rotulo(ci, FONTE, Vector2(roundf(meio.x - largura * 0.5), canto.y + caixa.y + MENU.ATE_O_SUBTITULO),
		subtitulo, tam, EstiloHUD.CLARO, alfa, MENU.CONTORNO_DO_SUBTITULO)
