@tool
extends Node2D

# --- A ANTENA DE AVISO, NO TETO DA CASINHA DA ESCADA (telhado da fase 2) ---
#
# Uma torre de treliça fininha com a luz vermelha de aviso para aviões na
# ponta, como as que ficam em cima dos prédios altos: acende, segura um
# instante e apaga devagar, sem parar, de dia e de noite.
#
# Desenhada aqui mesmo, em pixel art no tamanho do pixel do cenário (os tiles
# são 16 px em escala 2). A position é o PÉ da antena (o meio da base, em cima
# do teto). O mastro escurece com o horário como o resto do cenário; a lâmpada
# e o brilho dela não (têm luz própria). O brilho é uma LuzPontual vermelha,
# que também tinge o mastro e o teto quando acende.
#
# Quem cria é o fase2_telhado.gd (grupo "Antena" no Inspector da raiz).

## Tamanho do pixel de arte no mundo: 1, o mesmo detalhe dos personagens (o
## pixel dos tiles, 2, deixa a treliça grossa demais).
const PIXEL := 1.0

## Altura do mastro, em pixels do mundo (sem contar a haste da lâmpada).
@export_range(24, 120, 1) var altura := 62:
	set(v):
		altura = v
		_posicionar_a_luz()
		queue_redraw()
## Uma piscada a cada tantos segundos.
@export_range(0.4, 5.0, 0.05) var periodo := 1.6
## Quanto de cada piscada a lâmpada fica acesa (s).
@export_range(0.05, 3.0, 0.05) var aceso_por := 0.55
@export var cor_da_luz := Color(1.0, 0.13, 0.08):
	set(v):
		cor_da_luz = v
		queue_redraw()
## Força do brilho em volta da lâmpada.
@export_range(0.0, 3.0, 0.05) var forca_do_brilho := 1.3
## Alcance do brilho, em pixels do mundo.
@export_range(16.0, 300.0, 2.0) var alcance_do_brilho := 70.0

const COR_ESCURA := Color(0.13, 0.12, 0.14)
const COR_DO_METAL := Color(0.24, 0.23, 0.26)
const COR_DO_REFLEXO := Color(0.38, 0.36, 0.4)
## A lâmpada apagada: um vidro vermelho escuro.
const COR_APAGADA := Color(0.32, 0.06, 0.06)

var _relogio := 0.0
var _nivel := 0.0
var _lampada: Node2D
var _brilho: LuzPontual


func _ready() -> void:
	_lampada = Node2D.new()
	_lampada.name = "Lampada"
	# A lâmpada brilha por conta própria: o escuro da noite não a apaga.
	var sem_sombra := CanvasItemMaterial.new()
	sem_sombra.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_lampada.material = sem_sombra
	_lampada.draw.connect(_desenhar_a_lampada)
	add_child(_lampada, false, Node.INTERNAL_MODE_BACK)

	_brilho = LuzPontual.new()
	_brilho.name = "Brilho"
	_brilho.cor = cor_da_luz
	_brilho.raio = alcance_do_brilho
	_brilho.queda = 1.6
	_brilho.energia = 0.0
	_brilho.clarao = 0.0
	_brilho.tamanho_do_clarao = 0.45
	add_child(_brilho, false, Node.INTERNAL_MODE_BACK)
	_posicionar_a_luz()


func _process(delta: float) -> void:
	_relogio = fposmod(_relogio + delta, periodo)
	# Liga rápido e apaga devagar, como uma lâmpada de verdade.
	var acesa := _relogio < aceso_por
	_nivel = move_toward(_nivel, 1.0 if acesa else 0.0, delta * (14.0 if acesa else 3.2))
	if _brilho:
		_brilho.energia = forca_do_brilho * _nivel
		_brilho.clarao = 0.75 * _nivel
	if _lampada:
		_lampada.queue_redraw()


## O meio da lâmpada, em relação ao pé da antena.
func ponta() -> Vector2:
	return Vector2(0.0, -(float(altura) + 11.0) * PIXEL)


func _posicionar_a_luz() -> void:
	if _brilho:
		_brilho.position = ponta()


# ───────────────────────────────────────────────────────────── o desenho

func _px(x: float, y: float, cor: Color, w := 1.0, h := 1.0) -> void:
	draw_rect(Rect2(x * PIXEL, y * PIXEL, w * PIXEL, h * PIXEL), cor)


func _draw() -> void:
	var h := altura
	# A sapata chumbada no teto.
	_px(-9, -3, COR_ESCURA, 19, 3)
	_px(-8, -4, COR_DO_METAL, 17, 1)
	# A treliça: duas pernas que afinam de 15 px de largura no pé para 5 na
	# ponta, um degrau a cada 6 px e um X em cada vão (o desenho que diz "torre
	# de metal"). A perna da direita pega o reflexo do céu.
	var pe := 5
	var topo := h + 4
	var vao := 6
	var y := pe
	while y < topo:
		var fim := mini(y + vao, topo)
		var meia_baixo := _meia_largura(y, pe, topo)
		var meia_cima := _meia_largura(fim, pe, topo)
		_px(-meia_baixo, -y, COR_DO_METAL, 2.0 * meia_baixo + 1.0, 1)
		for k in range(y, fim):
			var t := float(k - y) / float(maxi(fim - y - 1, 1))
			var meia := _meia_largura(k, pe, topo)
			_px(-meia, -k, COR_ESCURA)
			_px(meia, -k, COR_DO_REFLEXO)
			if meia >= 3.0:
				var x := roundf(lerpf(-meia_baixo + 1.0, meia_cima - 1.0, t))
				_px(x, -k, COR_DO_METAL)
				_px(-x, -k, COR_ESCURA)
		y = fim
	_px(-_meia_largura(topo, pe, topo), -topo, COR_DO_METAL, 2.0 * _meia_largura(topo, pe, topo) + 1.0, 1)
	# Os braços com as antenas de rádio, a dois terços da altura.
	var braco := pe + int(float(h) * 0.64)
	_px(-11, -braco, COR_DO_METAL, 23, 1)
	_px(-11, -braco - 6, COR_ESCURA, 1, 6)
	_px(11, -braco - 6, COR_DO_REFLEXO, 1, 6)
	_px(-7, -braco - 4, COR_ESCURA, 1, 4)
	_px(7, -braco - 4, COR_DO_REFLEXO, 1, 4)
	# Um prato pequeno de lado, mais embaixo.
	var prato := pe + int(float(h) * 0.3)
	_px(-_meia_largura(prato, pe, topo) - 2.0, -prato - 2, COR_DO_METAL, 2, 1)
	_px(-_meia_largura(prato, pe, topo) - 4.0, -prato - 5, COR_DO_REFLEXO, 1, 7)
	_px(-_meia_largura(prato, pe, topo) - 3.0, -prato - 6, COR_DO_METAL, 1, 9)
	# A haste fina que segura a lâmpada.
	_px(0, -(topo + 5), COR_DO_REFLEXO, 1, 5)


func _meia_largura(y: int, pe: int, topo: int) -> float:
	var t := float(y - pe) / float(maxi(topo - pe, 1))
	return roundf(lerpf(7.0, 2.0, pow(t, 0.85)))


func _desenhar_a_lampada() -> void:
	var meio := ponta()
	var cor := COR_APAGADA.lerp(cor_da_luz, _nivel)
	# Um globinho redondo de 5 px, com o miolo branco-quente quando acende.
	_lampada.draw_rect(Rect2(meio + Vector2(-1.5, -2.5), Vector2(3.0, 5.0)), cor)
	_lampada.draw_rect(Rect2(meio + Vector2(-2.5, -1.5), Vector2(5.0, 3.0)), cor)
	if _nivel > 0.05:
		var miolo := Color(1.0, 0.78, 0.7, _nivel)
		_lampada.draw_rect(Rect2(meio + Vector2(-0.5, -1.5), Vector2(1.0, 2.0)), miolo)
		_lampada.draw_rect(Rect2(meio + Vector2(-1.5, -0.5), Vector2(1.0, 1.0)), miolo)
