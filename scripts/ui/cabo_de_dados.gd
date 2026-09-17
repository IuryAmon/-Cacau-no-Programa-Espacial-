class_name CaboDeDados
extends Control

# --- A MANGUEIRA ENTRE O TUBO RECEPTOR E O COMPUTADOR ---
#
# Uma mangueira deitada que sai do chão, sobe, corre para a direita e volta
# para o chão:  /------\
#
# O TRAJETO É EDITÁVEL NO EDITOR: é o Line2D filho "Trajeto". Selecione ele e
# arraste os pontos (ou mova o nó inteiro) — o primeiro ponto é a ponta do
# tubo, o último é a ponta do computador. No editor o Line2D já aparece como
# prévia da mangueira; no jogo ele some e quem desenha é este nó, com contorno,
# gomos de borracha e as bocas no chão.
#
# Quando um item cai no tubo, um pulso de luz na cor do item corre pela
# mangueira até o computador — e só quando ele chega a vaga do item acende. É a
# ligação de causa e efeito entre as duas metades do puzzle. Vários pulsos
# podem correr ao mesmo tempo, cada um com a própria cor.

const ESPESSURA := 16.0
const COR_CONTORNO := Color(0.0, 0.0, 0.0)
const COR_BORRACHA := Color(0.165, 0.188, 0.255)
const COR_GOMO := Color(0.12, 0.137, 0.188)
const COR_BRILHO := Color(0.26, 0.30, 0.40)
## Luz de repouso dentro da mangueira: indica que ela está ligada.
const COR_NUCLEO := Color(0.42, 0.72, 1.0, 0.16)
## Distância entre dois gomos da borracha.
const PASSO_GOMO := 10.0
## Tamanho da boca no chão, de onde a mangueira sai.
const BOCA := Vector2(36.0, 10.0)
const COR_BOCA := Color(0.10, 0.115, 0.16)

var _pulsos: Array[Dictionary] = []
var _tempo: float = 0.0

@onready var trajeto: Line2D = get_node_or_null("Trajeto")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Os puzzles pausam a árvore; a mangueira continua viva.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if trajeto:
		trajeto.hide()


func _process(delta: float) -> void:
	_tempo += delta
	for pulso in _pulsos:
		pulso["t"] = minf(pulso["t"] + delta / pulso["duracao"], 1.0)
	queue_redraw()


## Corre um pulso do tubo ao computador. É uma corrotina: "await
## cabo.pulsar(cor)" volta quando o pulso chega (ou quando a mangueira é parada).
func pulsar(cor: Color, duracao: float = 0.5) -> void:
	var pulso := {"t": 0.0, "cor": cor, "duracao": maxf(duracao, 0.05)}
	_pulsos.append(pulso)
	while pulso["t"] < 1.0 and is_inside_tree():
		await get_tree().process_frame
	_pulsos.erase(pulso)


## Apaga todos os pulsos em andamento (quem estava esperando é liberado).
func parar() -> void:
	for pulso in _pulsos:
		pulso["t"] = 1.0
	_pulsos.clear()


## Pontos do trajeto em coordenadas deste nó (respeita se o Line2D foi movido).
func caminho() -> PackedVector2Array:
	var pontos := PackedVector2Array()
	if trajeto == null:
		return pontos
	var xform := trajeto.transform
	for p in trajeto.points:
		pontos.append(xform * p)
	return pontos


func _comprimento(pontos: PackedVector2Array) -> float:
	var total := 0.0
	for i in pontos.size() - 1:
		total += pontos[i].distance_to(pontos[i + 1])
	return total


## Ponto e direção a "d" pixels do começo do caminho.
func _amostra(pontos: PackedVector2Array, d: float) -> Array:
	var resto := maxf(d, 0.0)
	for i in pontos.size() - 1:
		var trecho := pontos[i].distance_to(pontos[i + 1])
		if resto <= trecho or i == pontos.size() - 2:
			var direcao := (pontos[i + 1] - pontos[i]).normalized()
			return [pontos[i].lerp(pontos[i + 1], clampf(resto / maxf(trecho, 0.001), 0.0, 1.0)),
				direcao]
		resto -= trecho
	return [pontos[pontos.size() - 1], Vector2.RIGHT]


func _draw() -> void:
	var pontos := caminho()
	if pontos.size() < 2:
		return
	var total := _comprimento(pontos)
	if total <= 0.0:
		return

	# Bocas no chão: a mangueira entra e sai de uma peça, não do nada.
	for ponta in [pontos[0], pontos[pontos.size() - 1]]:
		var caixa := Rect2(ponta - Vector2(BOCA.x * 0.5, BOCA.y * 0.5), BOCA)
		draw_rect(caixa.grow(2.0), COR_CONTORNO)
		draw_rect(caixa, COR_BOCA)

	_tracar(pontos, COR_CONTORNO, ESPESSURA + 4.0)
	_tracar(pontos, COR_BORRACHA, ESPESSURA)

	# Gomos da borracha: riscos transversais, o que faz o traço ler "mangueira"
	# e não "cano".
	var d := PASSO_GOMO * 0.5
	while d < total:
		var amostra := _amostra(pontos, d)
		var lado: Vector2 = (amostra[1] as Vector2).orthogonal() * (ESPESSURA * 0.5 - 1.5)
		draw_line(amostra[0] - lado, amostra[0] + lado, COR_GOMO, 2.0)
		d += PASSO_GOMO

	# Fio de luz no lado de cima da borracha.
	var brilho := PackedVector2Array()
	for p in pontos:
		brilho.append(p + Vector2(0.0, -(ESPESSURA * 0.5 - 3.0)))
	draw_polyline(brilho, COR_BRILHO, 2.0)

	var nucleo := COR_NUCLEO
	nucleo.a *= 0.75 + 0.25 * sin(_tempo * 2.4)
	draw_polyline(pontos, nucleo, 3.0)

	for pulso in _pulsos:
		# Acelera saindo do tubo e chega com força no computador.
		var t: float = pulso["t"]
		var andado := t * t * total
		var cor: Color = pulso["cor"]
		for i in 6:
			var f := 1.0 - float(i) / 6.0
			draw_circle(_amostra(pontos, andado - 0.06 * total * i)[0], 3.0 + 3.0 * f,
				EstiloHUD.com_alfa(cor, 0.55 * f), true, -1.0, true)
		var ponto: Vector2 = _amostra(pontos, andado)[0]
		EstiloHUD.halo(self, ponto, 26.0, cor, 6, 1.4)
		draw_circle(ponto, 5.0, Color(1.0, 1.0, 1.0, 0.95), true, -1.0, true)


# draw_polyline não arredonda as dobras: um círculo em cada junta fecha o canto.
func _tracar(pontos: PackedVector2Array, cor: Color, largura: float) -> void:
	draw_polyline(pontos, cor, largura)
	for i in range(1, pontos.size() - 1):
		draw_circle(pontos[i], largura * 0.5, cor)
