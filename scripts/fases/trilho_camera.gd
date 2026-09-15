class_name TrilhoCamera
extends Line2D

# --- TRILHO DA CÂMERA ---
#
# Linha desenhada no editor que diz em que ALTURA fica o centro da câmera
# conforme a personagem anda para os lados. Serve para rampas, subidas e
# descidas: fora do trilho a câmera segue travada no LimitesDaCamera da fase;
# dentro dele, os limites de cima e de baixo passam a acompanhar a linha.
#
# COMO EDITAR: selecione o nó e arraste os pontos da linha no editor. Só a
# altura (y) de cada ponto em função do x importa — a ordem em que os pontos
# foram criados não. O começo e o fim do trilho devem ficar na mesma altura
# em que a câmera já está do lado de fora (no pé e no topo da rampa), assim a
# troca entre trilho e limites normais não dá tranco.
#
# A curva entre os pontos é suave e nunca passa do ponto (interpolação cúbica
# monótona): a câmera acelera e freia sozinha no começo e no fim da subida,
# sem o "degrau" de uma linha reta e sem balançar além da altura desenhada.
#
# A linha só aparece no editor; no jogo ela some.

const GRUPO := &"trilho_camera"

## Quanto a câmera pode se afastar da linha, para cima e para baixo, seguindo
## os pulos da personagem. 0 = presa na linha (o pulo não mexe a tela).
@export var folga_vertical: float = 0.0

## Rede de segurança: distância mínima entre a personagem e a borda de cima ou
## de baixo da tela. Se um pulo ou uma queda levar a personagem além disso, a
## câmera sai da linha para não perdê-la de vista.
@export var margem_personagem: float = 110.0

var _xs := PackedFloat32Array()
var _ys := PackedFloat32Array()
var _tangentes := PackedFloat32Array()


func _ready() -> void:
	add_to_group(GRUPO)
	visible = false
	_preparar_curva()


## True se a coordenada x (global) está dentro do trecho do trilho.
func cobre(x: float) -> bool:
	return _xs.size() >= 2 and x >= _xs[0] and x <= _xs[_xs.size() - 1]


## Altura (y global) do centro da câmera na coordenada x (global).
func altura_em(x: float) -> float:
	var n := _xs.size()
	if n == 0:
		return global_position.y
	if x <= _xs[0]:
		return _ys[0]
	if x >= _xs[n - 1]:
		return _ys[n - 1]

	var k := _xs.bsearch(x) - 1
	k = clampi(k, 0, n - 2)
	var h := _xs[k + 1] - _xs[k]
	var t := (x - _xs[k]) / h
	var t2 := t * t
	var t3 := t2 * t
	# Base de Hermite cúbica
	return (2.0 * t3 - 3.0 * t2 + 1.0) * _ys[k] \
		+ (t3 - 2.0 * t2 + t) * h * _tangentes[k] \
		+ (-2.0 * t3 + 3.0 * t2) * _ys[k + 1] \
		+ (t3 - t2) * h * _tangentes[k + 1]


# Pontos em coordenadas globais, ordenados por x, e as tangentes PCHIP
# (Fritsch–Carlson): monótona entre os pontos e plana nas duas pontas, para a
# câmera sair e voltar aos limites normais sem tranco.
func _preparar_curva() -> void:
	var pontos: Array[Vector2] = []
	for p in points:
		pontos.append(to_global(p))
	pontos.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	_xs.clear()
	_ys.clear()
	for p in pontos:
		# Dois pontos no mesmo x quebrariam a divisão; fica o primeiro.
		if not _xs.is_empty() and is_equal_approx(p.x, _xs[_xs.size() - 1]):
			continue
		_xs.append(p.x)
		_ys.append(p.y)

	var n := _xs.size()
	if n < 2:
		push_warning("%s: o trilho precisa de pelo menos 2 pontos." % name)
		return

	var inclinacoes := PackedFloat32Array()
	for k in n - 1:
		inclinacoes.append((_ys[k + 1] - _ys[k]) / (_xs[k + 1] - _xs[k]))

	_tangentes.resize(n)
	_tangentes[0] = 0.0
	_tangentes[n - 1] = 0.0
	for k in range(1, n - 1):
		var d0 := inclinacoes[k - 1]
		var d1 := inclinacoes[k]
		if d0 * d1 <= 0.0:
			_tangentes[k] = 0.0  # pico, vale ou trecho plano: para aqui
			continue
		var h0 := _xs[k] - _xs[k - 1]
		var h1 := _xs[k + 1] - _xs[k]
		var w1 := 2.0 * h1 + h0
		var w2 := h1 + 2.0 * h0
		_tangentes[k] = (w1 + w2) / (w1 / d0 + w2 / d1)
