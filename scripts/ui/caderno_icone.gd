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
#
# QUANDO UMA NOTA CHEGA (a folha que a Cacau pegou no mapa voa até aqui), o
# caderninho dá um pulo (pular) e ganha uma marca piscando no canto (novidade),
# que fica acesa até o caderno ser aberto.

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

## O pulo de quando uma nota chega: quanto o caderninho cresce e em quanto
## tempo assenta.
const CRESCE_NO_PULO := 0.32
const T_PULO := 0.45
## A marca de nota nova, no canto de cima do caderninho: um quadradinho da cor
## do papel aceso, com a borda do caderno, piscando.
const COR_NOVIDADE := Color8(0xf6, 0xc9, 0x52)
const COR_NOVIDADE_ACESA := Color8(0xff, 0xf2, 0xc4)
const PISCADAS_POR_SEGUNDO := 1.6

var _arte: Texture2D = null
## O pulo em andamento (1 = acabou de começar, 0 = assentado).
var _pulo: float = 0.0

## Tem nota nova que ainda não foi lida: acende a marca no canto.
var novidade: bool = false:
	set(valor):
		novidade = valor
		queue_redraw()

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


func _process(delta: float) -> void:
	_pulo = maxf(0.0, _pulo - delta / T_PULO)
	# A tecla afunda em loop: redesenha junto com o relógio dos botões.
	if visible:
		queue_redraw()


## Uma nota chegou: o caderninho pula.
func pular() -> void:
	_pulo = 1.0


## O caderninho está no meio do pulo?
func pulando() -> bool:
	return _pulo > 0.0


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
	# O pulo: cresce rápido e volta, com o pé do caderninho no lugar.
	var escala := 1.0
	if _pulo > 0.0:
		var p := 1.0 - _pulo
		escala = 1.0 + CRESCE_NO_PULO * sin(p * PI) * (1.0 - p * 0.5)
	var pe := Vector2(caderno.x * 0.5, caderno.y)
	draw_set_transform(pe * (1.0 - escala), 0.0, Vector2(escala, escala))
	if _arte != null:
		draw_texture_rect(_arte, Rect2(Vector2.ZERO, caderno), false)
	else:
		_desenhar_caderninho(Vector2(0.0, PIXEL), COR_SOMBRA)
		_desenhar_caderninho(Vector2.ZERO)
	if novidade:
		_desenhar_novidade(caderno)
	draw_set_transform(Vector2.ZERO)

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


## A marca de nota nova: 4 × 4 pixels do caderninho, saindo um pouco do canto
## de cima à direita.
func _desenhar_novidade(caderno: Vector2) -> void:
	var canto := Vector2(caderno.x - PIXEL * 3.0, -PIXEL * 2.0)
	var piscada := sin(Time.get_ticks_msec() * 0.001 * PISCADAS_POR_SEGUNDO * TAU) * 0.5 + 0.5
	draw_rect(Rect2(canto, Vector2.ONE * PIXEL * 4.0), CORES["K"])
	draw_rect(Rect2(canto + Vector2.ONE * PIXEL, Vector2.ONE * PIXEL * 2.0),
		COR_NOVIDADE.lerp(COR_NOVIDADE_ACESA, piscada))


func _tamanho_caderno() -> Vector2:
	if _arte != null:
		return _arte.get_size()
	return Vector2(String(DESENHO[0]).length(), DESENHO.size()) * PIXEL


## Caderninho + tecla.
func _tamanho_total() -> Vector2:
	var caderno := _tamanho_caderno()
	return Vector2(caderno.x + RESPIRO_TECLA + 16.0 * ESCALA_TECLA, caderno.y + PIXEL)
