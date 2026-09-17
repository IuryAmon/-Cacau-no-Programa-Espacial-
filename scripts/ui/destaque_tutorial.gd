class_name DestaqueTutorial
extends Control

# --- HOLOFOTE DO TUTORIAL (o "olha aqui" do cientista) ---
#
# Enquanto o Dr. Chico explica um passo, a tela escurece e só o que ele está
# comentando fica aceso, com uma moldura âmbar respirando em volta. Quando
# ele pede uma ação, o holofote vai para o botão certo e uma seta aponta para
# ele, marcando o clique.
#
# Três decisões que importam:
#
#   * ESCURECER, NÃO APAGAR. O resto da tela fica visível atrás do véu: a
#     pessoa não perde o contexto (a equação, as moléculas), só a atenção é
#     puxada para o furo.
#   * O FURO ANDA. Trocar de destaque desliza a moldura de um lugar para o
#     outro em vez de piscar — o olho acompanha o movimento e acha o alvo
#     novo sem procurar.
#   * CLIQUE ERRADO NÃO PUNE. Clicar fora do alvo só dá um cutucão na seta; é
#     tutorial, não prova.
#
# Os retângulos chegam em coordenadas de TELA (get_global_rect) e são
# convertidos aqui, então o nó pode morar dentro de uma tela escalada.

const COR := Color(1.0, 0.82, 0.25)
const VEU := Color(0.0, 0.0, 0.0, 0.62)
const DURACAO_MOVIMENTO := 0.35
const DURACAO_FADE := 0.25
## Chanfro dos cantos da moldura (mesma linguagem das peças do HUD).
const CORTE := 9.0

var _furos: Array[Rect2] = []
var _furos_de: Array[Rect2] = []
var _furos_para: Array[Rect2] = []
var _alvo_seta: Rect2 = Rect2()
## Detalhes DENTRO de um furo que merecem o olho primeiro (ex.: "O = 1" dentro
## do painel de produtos). O furo continua aceso inteiro, para não perder o
## contexto, e a ênfase ganha a moldura forte.
var _enfases: Array[Rect2] = []
var _com_seta: bool = false

## 0..1: o quanto o holofote está ligado (véu + moldura).
var _forca: float = 0.0
var _forca_alvo: float = 0.0
## 0..1: progresso do deslize entre dois destaques.
var _movimento: float = 1.0
var _tempo: float = 0.0
var _cutucao: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Os puzzles pausam a árvore; o holofote continua vivo.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_tempo += delta
	_forca = move_toward(_forca, _forca_alvo, delta / DURACAO_FADE)
	if _movimento < 1.0:
		_movimento = minf(_movimento + delta / DURACAO_MOVIMENTO, 1.0)
		var t := _movimento * _movimento * (3.0 - 2.0 * _movimento)
		for i in _furos.size():
			_furos[i] = Rect2(_furos_de[i].position.lerp(_furos_para[i].position, t),
				_furos_de[i].size.lerp(_furos_para[i].size, t))
	_cutucao = maxf(_cutucao - delta * 3.0, 0.0)
	queue_redraw()


## Acende o holofote nos retângulos (coordenadas de tela). Com "seta", marca
## o primeiro retângulo como o lugar do clique.
func focar(retangulos: Array[Rect2], seta: bool = false, enfases: Array[Rect2] = []) -> void:
	var locais: Array[Rect2] = []
	var para_local := get_global_transform().affine_inverse()
	for r in retangulos:
		locais.append(para_local * r)
	locais = _juntar_sobrepostos(locais)
	_enfases.clear()
	for r in enfases:
		_enfases.append(para_local * r)

	# Mesma quantidade de furos e o holofote já ligado: desliza. Senão, troca
	# de uma vez (o fade de entrada disfarça).
	if _forca > 0.05 and locais.size() == _furos.size() and not locais.is_empty():
		_furos_de = _furos.duplicate()
		_furos_para = locais
		_movimento = 0.0
	else:
		_furos = locais.duplicate()
		_furos_para = locais
		_movimento = 1.0
	_com_seta = seta and not locais.is_empty()
	_alvo_seta = locais[0] if _com_seta else Rect2()
	_forca_alvo = 1.0


## Desliga o holofote (com fade, ou na hora).
func limpar(imediato: bool = false) -> void:
	_forca_alvo = 0.0
	_com_seta = false
	if imediato:
		_forca = 0.0
		_furos.clear()


## Clique fora do alvo: a seta dá um tranco para chamar a atenção de volta.
func cutucar() -> void:
	_cutucao = 1.0


func esta_ativo() -> bool:
	return _forca_alvo > 0.0


func tem_seta() -> bool:
	return _com_seta


# Furos que se tocam viram um só: o véu é recortado em faixas, e faixas
# sobrepostas deixariam pedaços escuros dentro do destaque.
func _juntar_sobrepostos(retangulos: Array[Rect2]) -> Array[Rect2]:
	var saida: Array[Rect2] = retangulos.duplicate()
	var mudou := true
	while mudou:
		mudou = false
		for i in saida.size():
			for j in range(i + 1, saida.size()):
				if saida[i].intersects(saida[j], true):
					saida[i] = saida[i].merge(saida[j])
					saida.remove_at(j)
					mudou = true
					break
			if mudou:
				break
	return saida


func _draw() -> void:
	if _forca <= 0.0:
		return
	_desenhar_veu()
	# Com ênfase, a moldura do painel recua e a força vai para o detalhe.
	var forca_furo := 0.45 if not _enfases.is_empty() else 1.0
	for furo in _furos:
		_desenhar_moldura(furo, forca_furo)
	for enfase in _enfases:
		_desenhar_enfase(enfase)
	if _com_seta:
		_desenhar_seta(_alvo_seta)


# O véu cobre a tela inteira menos os furos. Como draw_* não recorta
# polígono, ele é montado com retângulos: uma faixa acima de todos os furos,
# uma abaixo, e na altura deles os vãos entre um furo e outro.
func _desenhar_veu() -> void:
	var cor := EstiloHUD.com_alfa(VEU, _forca)
	var tela := Rect2(Vector2.ZERO, size)
	if _furos.is_empty():
		draw_rect(tela, cor)
		return
	var ordenados: Array[Rect2] = _furos.duplicate()
	ordenados.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	var topo := ordenados[0].position.y
	var base := ordenados[0].end.y
	for f in ordenados:
		topo = minf(topo, f.position.y)
		base = maxf(base, f.end.y)
	_retangulo(Rect2(0.0, 0.0, size.x, topo), cor)
	_retangulo(Rect2(0.0, base, size.x, size.y - base), cor)
	var x := 0.0
	for f in ordenados:
		_retangulo(Rect2(x, topo, f.position.x - x, base - topo), cor)
		_retangulo(Rect2(f.position.x, topo, f.size.x, f.position.y - topo), cor)
		_retangulo(Rect2(f.position.x, f.end.y, f.size.x, base - f.end.y), cor)
		x = maxf(x, f.end.x)
	_retangulo(Rect2(x, topo, size.x - x, base - topo), cor)


func _retangulo(r: Rect2, cor: Color) -> void:
	if r.size.x > 0.0 and r.size.y > 0.0:
		draw_rect(r, cor)


func _desenhar_moldura(furo: Rect2, forca: float = 1.0) -> void:
	var respiro := 0.5 + 0.5 * sin(_tempo * 4.0)
	# Brilho: contornos cada vez maiores e mais fracos por fora da moldura.
	for camada in 3:
		var folga := 3.0 + camada * 3.5 + respiro * 2.0
		EstiloHUD.moldura(self, EstiloHUD.chanfro(furo.grow(folga), CORTE + folga),
			EstiloHUD.com_alfa(COR, (0.28 - camada * 0.08) * _forca * forca), 3.0)
	EstiloHUD.moldura(self, EstiloHUD.chanfro(furo, CORTE),
		EstiloHUD.com_alfa(COR, (0.75 + 0.25 * respiro) * _forca * forca), 3.0)


# Caixa do detalhe: moldura cheia, um banho leve de cor por dentro e um pulso
# que "respira" para fora — é a primeira coisa que o olho encontra.
func _desenhar_enfase(caixa: Rect2) -> void:
	var pulso := fmod(_tempo * 1.4, 1.0)
	draw_rect(caixa, EstiloHUD.com_alfa(COR, 0.12 * _forca))
	EstiloHUD.moldura(self, EstiloHUD.chanfro(caixa.grow(pulso * 10.0), 6.0 + pulso * 10.0),
		EstiloHUD.com_alfa(COR, (1.0 - pulso) * 0.6 * _forca), 2.0)
	EstiloHUD.moldura(self, EstiloHUD.chanfro(caixa, 6.0), EstiloHUD.com_alfa(COR, _forca), 3.0)


# Seta âmbar à ESQUERDA do alvo, apontando para ele e indo e voltando na
# direção do clique. Do lado, e não em cima: em cima ela cobriria o texto que
# costuma ficar logo acima dos botões. Sem espaço à esquerda, vai para a
# direita, apontando de volta.
func _desenhar_seta(alvo: Rect2) -> void:
	const ESCALA := 1.5
	var quique := absf(sin(_tempo * 5.0)) * 9.0
	var tranco := sin(_cutucao * PI * 6.0) * 8.0 * _cutucao
	var pela_esquerda := alvo.position.x > 90.0
	var angulo := -PI * 0.5 if pela_esquerda else PI * 0.5
	var recuo := 8.0 + quique + tranco
	var ponta := Vector2(alvo.position.x - recuo if pela_esquerda else alvo.end.x + recuo,
		alvo.get_center().y)

	# Desenho base aponta para BAIXO com a ponta em (0,0); o ângulo gira para
	# o lado certo.
	var forma := [Vector2(0, 0), Vector2(17, -19), Vector2(7, -19), Vector2(7, -40),
		Vector2(-7, -40), Vector2(-7, -19), Vector2(-17, -19)]
	var pontos := PackedVector2Array()
	for p in forma:
		pontos.append(ponta + (p * ESCALA).rotated(angulo))

	var alfa := _forca
	draw_colored_polygon(EstiloHUD.deslocar(pontos, Vector2(3, 4)),
		EstiloHUD.com_alfa(Color.BLACK, 0.45 * alfa))
	draw_colored_polygon(pontos, EstiloHUD.com_alfa(COR, alfa))
	draw_polyline(EstiloHUD.fechar(pontos), EstiloHUD.com_alfa(Color.BLACK, alfa), 3.0, true)
	# Fio de luz no corpo da seta, para ela ter volume.
	var brilho_de := ponta + (Vector2(-4, -22) * ESCALA).rotated(angulo)
	var brilho_ate := ponta + (Vector2(-4, -37) * ESCALA).rotated(angulo)
	draw_line(brilho_de, brilho_ate, EstiloHUD.com_alfa(Color(1, 1, 1, 0.55), alfa), 2.0)
