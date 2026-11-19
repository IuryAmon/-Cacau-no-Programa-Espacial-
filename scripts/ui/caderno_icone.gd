class_name CadernoIcone
extends Control

# --- O ÍCONE DO CADERNO (canto inferior esquerdo) ---
#
# As duas abas do caderno lado a lado — o caderninho (CADERNO) e o mapinha
# (MAPA), os mesmos desenhos das abas do caderno aberto — e, ao lado deles, a
# tecla que abre o caderno afundando em loop — M no teclado, o botão da ação
# "caderno" no controle (△) —, no mesmo ritmo das outras teclas desenhadas do
# jogo (BotoesControle).
#
# A ARTE DO ÍCONE AINDA NÃO EXISTE: enquanto ARTE_DO_CADERNO e ARTE_DO_MAPA
# estiverem vazios, os dois desenhos são feitos aqui mesmo, em pixel art no
# pixel do caderno grande (4 px), com as cores dele. Quando a arte chegar, é só
# pôr o caminho dela ali.
#
# Quem decide quando o ícone aparece é o autoload Caderno (pelo "alfa"). Ao
# abrir, a folha da aba da vez sai do desenho dela: o caderno sai do
# caderninho e o mapa, do mapinha.
#
# QUANDO UMA NOTA CHEGA (a folha que a Cacau pegou no mapa voa até aqui), o
# caderninho dá um pulo (pular) e ganha uma marca piscando no canto (novidade),
# que fica acesa até a pessoa ver a aba CADERNO.

const ARTE_DO_CADERNO := ""
const ARTE_DO_MAPA := ""

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
## O mapinha, nas mesmas cores: o mapa dobrado em três, com o caminho
## tracejado até o X.
const DESENHO_MAPA := [
	"KKKKKKKKKKKKKKKKK",
	"KPPPPPGBBBBGPPPPK",
	"KPPPPPGBBBBGPRPRK",
	"KPPPPPGBBBBGPPRPK",
	"KPPPPPGBBBRGPRPRK",
	"KPPPPPGBBRBGPPPPK",
	"KPPPPPGRBBBGPPPPK",
	"KPPPPRGBBBBGPPPPK",
	"KPPPRPGBBBBGPPPPK",
	"KPRPPPGBBBBGPPPPK",
	"KPPPPPGBBBBGPPPPK",
	"KKKKKKKKKKKKKKKKK",
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
## Entre o caderninho e o mapinha.
const ENTRE_DESENHOS := 8.0

## A tecla ao lado do mapinha, da altura dele.
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

var _arte_caderno: Texture2D = null
var _arte_mapa: Texture2D = null
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
	if not ARTE_DO_CADERNO.is_empty():
		_arte_caderno = load(ARTE_DO_CADERNO)
	if not ARTE_DO_MAPA.is_empty():
		_arte_mapa = load(ARTE_DO_MAPA)
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
	# Com nota nova a tecla afunda em loop: redesenha junto com o relógio dos
	# botões. Sem ela, redesenhar ainda pega a troca de teclado para controle.
	if visible:
		queue_redraw()


## Uma nota chegou: o caderninho pula.
func pular() -> void:
	_pulo = 1.0


## O caderninho está no meio do pulo?
func pulando() -> bool:
	return _pulo > 0.0


## Centro do caderninho na tela: é dele que o caderno grande sai ao abrir, e é
## nele que as notas entram.
func centro_do_caderno() -> Vector2:
	return get_global_rect().position + caixa_do_caderno().get_center()


## Centro do mapinha na tela: é dele que o mapa sai ao abrir.
func centro_do_mapa() -> Vector2:
	return get_global_rect().position + caixa_do_mapa().get_center()


## Onde fica o caderninho, dentro do ícone.
func caixa_do_caderno() -> Rect2:
	return Rect2(Vector2.ZERO, _tamanho_do_desenho(_arte_caderno, DESENHO))


## Onde fica o mapinha, dentro do ícone: à direita do caderninho, com o pé na
## mesma linha.
func caixa_do_mapa() -> Rect2:
	var caderno := caixa_do_caderno()
	var tamanho := _tamanho_do_desenho(_arte_mapa, DESENHO_MAPA)
	return Rect2(Vector2(caderno.end.x + ENTRE_DESENHOS, caderno.end.y - tamanho.y), tamanho)


## Nome (BotoesControle) da tecla ou do botão que aparece ao lado.
func nome_da_tecla() -> String:
	if BotoesControle.controle_em_uso():
		var botao := BotoesControle.nome_da_acao(Caderno.ACAO)
		if botao != "":
			return botao
	return "tecla_m"


## A marca de nota nova (4 × 4 pixels de "pixel"), com o canto de cima à
## esquerda em "canto". É a mesma no ícone e na aba CADERNO do caderno aberto.
static func desenhar_marca(no: CanvasItem, canto: Vector2, pixel: float) -> void:
	var piscada := sin(Time.get_ticks_msec() * 0.001 * PISCADAS_POR_SEGUNDO * TAU) * 0.5 + 0.5
	no.draw_rect(Rect2(canto, Vector2.ONE * pixel * 4.0), CORES["K"])
	no.draw_rect(Rect2(canto + Vector2.ONE * pixel, Vector2.ONE * pixel * 2.0),
		COR_NOVIDADE.lerp(COR_NOVIDADE_ACESA, piscada))


func _draw() -> void:
	var caderno := caixa_do_caderno()
	var mapa := caixa_do_mapa()
	_desenhar(_arte_mapa, DESENHO_MAPA, mapa)

	# O pulo: o caderninho cresce rápido e volta, com o pé no lugar (e por cima
	# do mapinha).
	var escala := 1.0
	if _pulo > 0.0:
		var p := 1.0 - _pulo
		escala = 1.0 + CRESCE_NO_PULO * sin(p * PI) * (1.0 - p * 0.5)
	var pe := Vector2(caderno.get_center().x, caderno.end.y)
	draw_set_transform(pe * (1.0 - escala), 0.0, Vector2(escala, escala))
	_desenhar(_arte_caderno, DESENHO, caderno)
	# A marca: saindo um pouco do canto de cima à direita do caderninho.
	if novidade:
		desenhar_marca(self, Vector2(caderno.end.x - PIXEL * 3.0, caderno.position.y - PIXEL * 2.0), PIXEL)
	draw_set_transform(Vector2.ZERO)

	# A tecla fica parada; só afunda em loop com nota nova esperando ser lida.
	var nome := nome_da_tecla()
	var centro := Vector2(mapa.end.x + RESPIRO_TECLA + 8.0 * ESCALA_TECLA, mapa.get_center().y)
	BotoesControle.desenhar(self, centro, nome, ESCALA_TECLA, Color.WHITE,
		BotoesControle.quadro_atual() if novidade else 0)


## Um dos desenhos na caixa dele: a arte, se tiver, ou os pixels com a sombra.
func _desenhar(arte: Texture2D, desenho: Array, caixa: Rect2) -> void:
	if arte != null:
		draw_texture_rect(arte, caixa, false)
		return
	_desenhar_pixels(desenho, caixa.position + Vector2(0.0, PIXEL), COR_SOMBRA)
	_desenhar_pixels(desenho, caixa.position)


func _desenhar_pixels(desenho: Array, deslocamento: Vector2, cor_unica: Color = Color(0, 0, 0, 0)) -> void:
	for y in desenho.size():
		var linha: String = desenho[y]
		for x in linha.length():
			var cor: Color = CORES.get(linha[x], Color(0, 0, 0, 0))
			if cor.a <= 0.0:
				continue
			if cor_unica.a > 0.0:
				cor = cor_unica
			draw_rect(Rect2(deslocamento + Vector2(x, y) * PIXEL, Vector2(PIXEL, PIXEL)), cor)


func _tamanho_do_desenho(arte: Texture2D, desenho: Array) -> Vector2:
	if arte != null:
		return arte.get_size()
	return Vector2(String(desenho[0]).length(), desenho.size()) * PIXEL


## Caderninho + mapinha + tecla (e a sombra embaixo).
func _tamanho_total() -> Vector2:
	var caderno := caixa_do_caderno()
	var mapa := caixa_do_mapa()
	return Vector2(mapa.end.x + RESPIRO_TECLA + 16.0 * ESCALA_TECLA,
		maxf(caderno.end.y, mapa.end.y) + PIXEL)
