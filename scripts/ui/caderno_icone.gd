class_name CadernoIcone
extends Control

# --- O ÍCONE DO CADERNO (canto inferior esquerdo) ---
#
# Um caderninho e, ao lado dele, a tecla que abre o caderno afundando em loop
# — M no teclado, o botão da ação "caderno" no controle (△) —, no
# mesmo ritmo das outras teclas desenhadas do jogo (BotoesControle).
#
# A ARTE DO ÍCONE AINDA NÃO EXISTE: enquanto ARTE_DO_ICONE estiver vazio, o
# caderninho é desenhado aqui mesmo, em pixel art no pixel do caderno grande
# (4 px), com as cores dele. Quando a arte chegar, é só pôr o caminho dela ali.
#
# Quem decide quando o ícone aparece é o autoload Caderno (pelo "alfa").

const ARTE_DO_ICONE := ""

## O caderninho, um caractere por pixel da arte (ver CORES; "." = vazio).
const DESENHO := [
	".KKKKKKK.KKKKKKK.",
	"KPPPPPPPGPPPPPPPK",
	"KPSSSSSPGPSSSSSPK",
	"KPPPPPPPGPPPPPPPK",
	"KPSSSSPPGPSSSSPPK",
	"KPPPPPPPGPPPPPPPK",
	"KPSSSSSPGPSSSPPPK",
	"KPPPPPPPGPPPPPPPK",
	"KBBBBBBBGBBBBBBBK",
	"KCCRCCCCKCCCCCCCK",
	".KKRKKKKKKKKKKKK.",
	"...R.............",
]
const CORES := {
	"K": Color8(0x2a, 0x1a, 0x16),
	"P": Color8(0xe7, 0xd5, 0xb3),
	"S": Color8(0xb8, 0x96, 0x72),
	"G": Color8(0xc9, 0xa8, 0x82),
	"B": Color8(0xd4, 0xb8, 0x8e),
	"C": Color8(0x7a, 0x3e, 0x2a),
	"R": Color8(0xa5, 0x30, 0x30),
}
const PIXEL := 4.0
const COR_SOMBRA := Color(0.0, 0.0, 0.0, 0.35)

## A tecla ao lado do caderninho, da altura dele.
const ESCALA_TECLA := 3.0
const RESPIRO_TECLA := 6.0
const MARGEM := Vector2(28.0, 26.0)

var _arte: Texture2D = null

## 0 = escondido, 1 = inteiro na tela.
var alfa: float = 0.0:
	set(valor):
		alfa = clampf(valor, 0.0, 1.0)
		modulate.a = alfa
		visible = alfa > 0.0


func _ready() -> void:
	if not ARTE_DO_ICONE.is_empty():
		_arte = load(ARTE_DO_ICONE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tamanho := _tamanho_total()
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = MARGEM.x
	offset_right = MARGEM.x + tamanho.x
	offset_top = -MARGEM.y - tamanho.y
	offset_bottom = -MARGEM.y
	alfa = 0.0


func _process(_delta: float) -> void:
	# A tecla afunda em loop: redesenha junto com o relógio dos botões.
	if visible:
		queue_redraw()


## Centro do caderninho na tela: é dele que o caderno grande sai ao abrir.
func centro_do_caderno() -> Vector2:
	return get_global_rect().position + _tamanho_caderno() * 0.5


## Nome (BotoesControle) da tecla ou do botão que aparece ao lado.
func nome_da_tecla() -> String:
	if BotoesControle.controle_em_uso():
		var botao := BotoesControle.nome_da_acao(Caderno.ACAO)
		if botao != "":
			return botao
	return "tecla_m"


func _draw() -> void:
	var caderno := _tamanho_caderno()
	if _arte != null:
		draw_texture_rect(_arte, Rect2(Vector2.ZERO, caderno), false)
	else:
		_desenhar_caderninho(Vector2(0.0, PIXEL), COR_SOMBRA)
		_desenhar_caderninho(Vector2.ZERO)

	var nome := nome_da_tecla()
	var centro := Vector2(caderno.x + RESPIRO_TECLA + 8.0 * ESCALA_TECLA, caderno.y * 0.5)
	BotoesControle.desenhar(self, centro, nome, ESCALA_TECLA, Color.WHITE,
		BotoesControle.quadro_atual())


func _desenhar_caderninho(deslocamento: Vector2, cor_unica: Color = Color(0, 0, 0, 0)) -> void:
	for y in DESENHO.size():
		var linha: String = DESENHO[y]
		for x in linha.length():
			var cor: Color = CORES.get(linha[x], Color(0, 0, 0, 0))
			if cor.a <= 0.0:
				continue
			if cor_unica.a > 0.0:
				cor = cor_unica
			draw_rect(Rect2(deslocamento + Vector2(x, y) * PIXEL, Vector2(PIXEL, PIXEL)), cor)


func _tamanho_caderno() -> Vector2:
	if _arte != null:
		return _arte.get_size()
	return Vector2(String(DESENHO[0]).length(), DESENHO.size()) * PIXEL


## Caderninho + tecla.
func _tamanho_total() -> Vector2:
	var caderno := _tamanho_caderno()
	return Vector2(caderno.x + RESPIRO_TECLA + 16.0 * ESCALA_TECLA, caderno.y + PIXEL)
