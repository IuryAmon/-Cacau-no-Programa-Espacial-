class_name EstalosPixel
extends Node2D

# --- ESTALOS DE PIXEL (O GOLPE QUE SE VÊ) ---
#
# Os efeitos de impacto desenhados NA GRADE DE PIXELS da arte, do mesmo jeito
# que os brilhinhos da cura (scripts/fx/brilho_de_cura.gd): cor chapada, uma
# beirada escura de 1 pixel que recorta a peça em fundo claro, e nada de
# partícula borrada. Quem usa hoje é o morcego (scripts/fases/morcego.gd) — a
# estrela do acerto, os fiapos que voam dele, a fumaça em que o corpo some.
#
# O efeito é 100% de runtime: não tem cena, não tem PNG. Ele mora na FASE, e
# não em quem apanhou — o estalo fica onde o golpe aconteceu, mesmo que o
# morcego saia voando dali.
#
# --- AS TRÊS PEÇAS ---
#
#   ESTRELA   quatro pontas que já nascem abertas e fecham até virar ponto: é
#             o "pá!" do acerto.
#   FAÍSCA    um quadradinho arremessado, que voa, cai (se tiver gravidade) e
#             some: fiapos, lascas, poeira.
#   TUFO      um disco de pixel que estufa e murcha: fumaça.
#
# --- COMO USAR ---
#
#   EstalosPixel.criar(cena, ponto) \
#       .estrela(Vector2.ZERO, 4, 0.14, Color.WHITE) \
#       .faiscas(8, direcao, 50.0, Vector2(60, 150), Vector2(0.2, 0.4), [cor_a, cor_b])
#
# Cada chamada devolve o próprio efeito, então dá para encadear. Ele se desfaz
# sozinho quando a última peça some. TODAS AS MEDIDAS SÃO EM PIXELS DE ARTE
# (1 pixel de arte = ESCALA pixels do mundo): braço 4 é uma estrela de 9 pixels
# de ponta a ponta, velocidade 100 são 100 pixels de arte por segundo.

## Pixels do mundo por pixel de arte: o mesmo dos tiles das fases e do morcego.
const ESCALA := 2.0

## A beirada escura de 1 pixel em volta de cada peça.
const COR_BEIRADA := Color(0.05, 0.04, 0.09)
const BEIRADA_ALFA := 0.6
## A partir desta fração da vida a peça começa a ficar transparente.
const APAGA_A_PARTIR_DE := 0.7

enum { ESTRELA, FAISCA, TUFO }

var _pecas: Array[Dictionary] = []
var _tempo: float = 0.0
var _fim: float = 0.0


# --- ENTRADA ---

## Um efeito novo e vazio em `onde` (posição do mundo), pendurado em `pai` — a
## cena da fase. `z` é a camada: o padrão fica por cima da personagem.
static func criar(pai: Node, onde: Vector2, z: int = 4) -> EstalosPixel:
	var fx := EstalosPixel.new()
	fx.name = "EstalosPixel"
	fx.z_index = z
	fx.scale = Vector2(ESCALA, ESCALA)
	# Na grade de pixels do cenário: os tiles nascem do zero, de ESCALA em ESCALA.
	var ponto := onde.snappedf(ESCALA)
	# Em coordenadas do PAI, e não em global: a entrada na árvore pode ser
	# adiada (ver Blockout.adicionar) e um global_position escrito antes disso
	# se perderia no caminho.
	var pai_2d := pai as Node2D
	fx.position = pai_2d.to_local(ponto) if pai_2d else ponto
	Blockout.adicionar(pai, fx)
	return fx


## Uma estrela de quatro pontas. `braco` é o comprimento de cada ponta.
func estrela(pos: Vector2, braco: int, vida: float, cor: Color, atraso: float = 0.0) -> EstalosPixel:
	_guardar({"tipo": ESTRELA, "pos": pos, "vel": Vector2.ZERO, "gravidade": 0.0, "freio": 0.0,
		"nasce": atraso, "vida": vida, "tamanho": braco, "cor": cor})
	return self


## Um punhado de quadradinhos arremessados em leque em volta de `direcao`.
## `velocidade` e `vida` são faixas (x = mínimo, y = máximo) e cada faísca
## sorteia uma das `cores`. `freio` é o quanto elas perdem de velocidade por
## segundo (0 = nada, 4 = param quase na hora).
func faiscas(quantidade: int, direcao: Vector2, abertura_graus: float, velocidade: Vector2,
		vida: Vector2, cores: Array, gravidade: float = 0.0, tamanho: int = 1,
		freio: float = 2.0, raio_de_origem: float = 2.0) -> EstalosPixel:
	var rumo := direcao.normalized() if direcao.length_squared() > 0.0001 else Vector2.UP
	var meia_abertura := deg_to_rad(abertura_graus) * 0.5
	for i in quantidade:
		var dir := rumo.rotated(randf_range(-meia_abertura, meia_abertura))
		_guardar({"tipo": FAISCA,
			"pos": Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * raio_de_origem,
			"vel": dir * randf_range(velocidade.x, velocidade.y),
			"gravidade": gravidade, "freio": freio,
			"nasce": 0.0, "vida": randf_range(vida.x, vida.y),
			"tamanho": tamanho if i % 2 == 0 else maxi(tamanho - 1, 1),
			"cor": cores[randi() % cores.size()]})
	return self


## Tufos de fumaça espalhados em volta do centro. `raio` é uma faixa (x = menor,
## y = maior), `espalhar` é o quanto eles se afastam do centro ao longo da vida
## (0 = ficam no meio) e `subida` é o quanto sobem por segundo.
func tufos(quantidade: int, raio: Vector2, espalhar: float, vida: Vector2, cor: Color,
		subida: float = 14.0) -> EstalosPixel:
	for i in quantidade:
		var angulo := TAU * (i + randf() * 0.6) / quantidade
		var para_fora := Vector2.RIGHT.rotated(angulo)
		_guardar({"tipo": TUFO,
			"pos": para_fora * randf_range(0.0, espalhar * 0.4),
			"vel": para_fora * espalhar / maxf(vida.y, 0.05) + Vector2(0.0, -subida),
			"gravidade": 0.0, "freio": 3.0,
			# O miolo estoura primeiro e a beirada vem um instante depois.
			"nasce": randf_range(0.0, 0.05), "vida": randf_range(vida.x, vida.y),
			"tamanho": randf_range(raio.x, raio.y), "cor": cor})
	return self


func _guardar(peca: Dictionary) -> void:
	_pecas.append(peca)
	_fim = maxf(_fim, peca["nasce"] + peca["vida"])


func _ready() -> void:
	# Luz própria: o estalo de um golpe não escurece no blecaute.
	var luz_propria := CanvasItemMaterial.new()
	luz_propria.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = luz_propria


func _process(delta: float) -> void:
	_tempo += delta
	if _tempo >= _fim:
		queue_free()
		return
	for peca in _pecas:
		if _tempo < peca["nasce"]:
			continue
		var vel: Vector2 = peca["vel"]
		vel.y += peca["gravidade"] * delta
		vel *= maxf(1.0 - peca["freio"] * delta, 0.0)
		peca["vel"] = vel
		peca["pos"] = peca["pos"] + vel * delta
	queue_redraw()


# --- DESENHO ---

func _draw() -> void:
	# Duas passadas, todas as beiradas antes: assim a beirada de uma peça nunca
	# escurece a vizinha.
	for beirada: bool in [true, false]:
		for peca in _pecas:
			var idade: float = _tempo - peca["nasce"]
			if idade < 0.0 or idade >= peca["vida"]:
				continue
			var k: float = idade / peca["vida"]
			var alfa: float = 1.0 - smoothstep(APAGA_A_PARTIR_DE, 1.0, k)
			# floor(): cada peça cai inteira na grade de pixels da arte.
			var p: Vector2 = (peca["pos"] as Vector2).floor()
			var cor := Color(COR_BEIRADA, alfa * BEIRADA_ALFA) if beirada \
				else Color(peca["cor"] as Color, (peca["cor"] as Color).a * alfa)
			match peca["tipo"]:
				ESTRELA:
					_desenhar_estrela(p, roundi(peca["tamanho"] * _estalar(k)), cor, beirada)
				FAISCA:
					# No último terço a faísca gorda afina antes de sumir.
					var lado: int = peca["tamanho"] if k < 0.66 else 1
					_desenhar_quadrado(p, lado, cor, beirada)
				TUFO:
					# A beirada do tufo desbota desde o começo: murchando, os tufos
					# se separam, e duas beiradas cheias uma em cima da outra
					# viravam um borrão escuro no meio da nuvem.
					if beirada:
						cor.a *= 1.0 - k
					_desenhar_disco(p, roundi(peca["tamanho"] * _estufar(k)), cor, beirada)


## O tamanho da estrela ao longo da vida. Ela já NASCE quase aberta (80%), cresce
## mais um tico e fecha até virar ponto. Nascer aberta é de propósito: o golpe
## congela o jogo no próprio quadro em que acontece (ver congelar_impacto em
## ferramentas_player.gd), e é esse quadro parado que se vê — uma estrela que
## começasse do zero ficaria invisível justamente durante o congelamento.
static func _estalar(k: float) -> float:
	return pow(sin((0.25 + 0.75 * k) * PI), 0.6)


## O tamanho do tufo ao longo da vida: estufa num quinto do tempo e murcha
## devagar até sumir.
static func _estufar(k: float) -> float:
	if k < 0.2:
		return k / 0.2
	var resto := (k - 0.2) / 0.8
	return 1.0 - resto * resto


func _desenhar_quadrado(p: Vector2, lado: int, cor: Color, beirada: bool) -> void:
	var folga := 1 if beirada else 0
	draw_rect(Rect2(p.x - folga, p.y - folga, lado + folga * 2, lado + folga * 2), cor)


## Uma cruz com o pixel `p` no meio. A beirada é a mesma cruz 1 pixel mais
## gorda; a barra de pé vai em duas metades para não passar duas vezes pelo
## miolo (onde a transparência somaria e ficaria mais escuro).
func _desenhar_estrela(p: Vector2, braco: int, cor: Color, beirada: bool) -> void:
	if beirada:
		draw_rect(Rect2(p.x - braco - 1, p.y - 1, braco * 2 + 3, 3), cor)
		if braco > 0:
			draw_rect(Rect2(p.x - 1, p.y - braco - 1, 3, braco), cor)
			draw_rect(Rect2(p.x - 1, p.y + 2, 3, braco), cor)
		return
	if braco <= 0:
		draw_rect(Rect2(p, Vector2.ONE), cor)
		return
	draw_rect(Rect2(p.x - braco, p.y, braco * 2 + 1, 1), cor)
	draw_rect(Rect2(p.x, p.y - braco, 1, braco), cor)
	draw_rect(Rect2(p.x, p.y + 1, 1, braco), cor)
	if braco >= 3:
		# A maior ganha corpo: as diagonais do miolo também acendem.
		draw_rect(Rect2(p.x - 1, p.y - 1, 1, 1), cor)
		draw_rect(Rect2(p.x + 1, p.y - 1, 1, 1), cor)
		draw_rect(Rect2(p.x - 1, p.y + 1, 1, 1), cor)
		draw_rect(Rect2(p.x + 1, p.y + 1, 1, 1), cor)


## Um disco de pixel: uma tira por linha, do jeito que se desenha círculo em
## pixel art. O meio pixel a mais no raio é o que achata o topo e a base — sem
## ele o disco termina num pixel só e vira losango.
func _desenhar_disco(p: Vector2, raio: int, cor: Color, beirada: bool) -> void:
	if beirada:
		raio += 1
	if raio <= 0:
		draw_rect(Rect2(p, Vector2.ONE), cor)
		return
	var raio_cheio := (raio + 0.5) * (raio + 0.5)
	for dy in range(-raio, raio + 1):
		var meia := int(sqrt(raio_cheio - dy * dy))
		draw_rect(Rect2(p.x - meia, p.y + dy, meia * 2 + 1, 1), cor)
