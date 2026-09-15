class_name VooDeItem
extends Control

# --- O ÍCONE INDO DA FICHA PARA A MOCHILA ---
#
# O pedaço que amarra as duas telas. Quando a pessoa fecha o popup, o desenho
# do item não some do centro para reaparecer num slot: ele se desprende do
# medalhão, faz uma curva pelo alto e encaixa no alvéolo, encolhendo até o
# tamanho de lá. O anel do slot só estoura quando o ícone chega.
#
# É a diferença entre "o jogo guardou alguma coisa em algum lugar" e "eu vi
# onde isso foi parar" — e é por isso que a mochila precisa ter a mesma forma
# hexagonal do medalhão: o voo termina num encaixe, não numa caixinha.
#
# Serve tanto para a mochila quanto para o cinto de ferramentas (que fica no
# canto de baixo): quem chama diz de onde para onde, e em que tamanho começa e
# termina.

signal chegou

## Rastro: quantas posições anteriores continuam desenhadas atrás do ícone.
const RASTRO := 14
const FAISCAS := 7

var textura: Texture2D = null
var cor: Color = EstiloHUD.ACENTO_PADRAO
var duracao: float = 0.52
## O ícone chega inteiro ou vai apagando no caminho (usado pelo cinto, que
## acende o próprio selo na chegada).
var apagar_ao_chegar: bool = false

var _inicio: Vector2 = Vector2.ZERO
var _fim: Vector2 = Vector2.ZERO
var _controle: Vector2 = Vector2.ZERO
var _caixa_inicio: float = 80.0
var _caixa_fim: float = 48.0
var _tempo: float = 0.0
var _trilha: Array[Vector2] = []


## Cria o voo já pendurado em "pai" (a camada do HUD) e o dispara. Os pontos
## são em coordenadas de tela — os mesmos que PopupItem.centro_do_medalhao() e
## MochilaHUD.centro_do_slot() devolvem.
static func lancar(pai: Node, arte: Texture2D, tinta: Color, de: Vector2, para: Vector2,
		caixa_de: float, caixa_para: float, tempo: float = 0.52) -> VooDeItem:
	var voo := VooDeItem.new()
	voo.name = "VooDeItem"
	voo.textura = arte
	voo.cor = tinta
	voo.duracao = maxf(tempo, 0.05)
	voo._caixa_inicio = caixa_de
	voo._caixa_fim = caixa_para
	pai.add_child(voo)
	voo._definir_rota(de, para)
	return voo


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# O popup pausa a árvore; o voo é parte da mesma cena e precisa continuar.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Acima da ficha e da mochila, que são irmãs na mesma camada — o ícone
	# passa por cima do véu enquanto ele apaga.
	z_index = 100


func _definir_rota(de: Vector2, para: Vector2) -> void:
	_inicio = de
	_fim = para
	# Ponto de controle acima da reta: a curva sobe antes de cair no slot, que
	# é como a mão joga alguma coisa dentro de uma mochila — reta seria
	# transporte de arquivo, não gesto.
	var meio := de.lerp(para, 0.5)
	var altura := absf(para.x - de.x) * 0.22 + absf(para.y - de.y) * 0.18 + 70.0
	_controle = meio - Vector2(0.0, altura)
	# Trajetos longos jogariam o ponto de controle para fora da tela e o arco
	# sairia por cima da borda. O topo é o teto do gesto.
	_controle.y = maxf(_controle.y, 40.0)
	_trilha.clear()


func _process(delta: float) -> void:
	_tempo += delta
	var t := clampf(_tempo / duracao, 0.0, 1.0)

	var p := _posicao(t)
	_trilha.push_front(p)
	while _trilha.size() > RASTRO:
		_trilha.pop_back()

	queue_redraw()

	if t >= 1.0:
		set_process(false)
		chegou.emit()
		queue_free()


## Curva do tempo: um recuo curtinho (antecipação) e depois a saída, freando
## na chegada. É o que dá peso ao gesto — sair direto em velocidade constante
## faz o ícone parecer um cursor.
func _andamento(t: float) -> float:
	if t < 0.18:
		return -0.06 * sin(t / 0.18 * PI)
	var u := (t - 0.18) / 0.82
	return u * u * (3.0 - 2.0 * u)


func _posicao(t: float) -> Vector2:
	var u := _andamento(t)
	var iu := 1.0 - u
	return _inicio * (iu * iu) + _controle * (2.0 * iu * u) + _fim * (u * u)


func _draw() -> void:
	if _trilha.is_empty():
		return

	var t := clampf(_tempo / duracao, 0.0, 1.0)
	var u := clampf(_andamento(t), 0.0, 1.0)
	var caixa := lerpf(_caixa_inicio, _caixa_fim, u * u * (3.0 - 2.0 * u))
	var local := get_global_transform().affine_inverse()
	var ponta: Vector2 = local * _trilha[0]

	# Rastro: pontos da cor do item que vão sumindo atrás da ponta.
	for i in range(1, _trilha.size()):
		var f := 1.0 - float(i) / float(_trilha.size())
		draw_circle(local * _trilha[i], caixa * 0.075 * f + 1.5,
			EstiloHUD.com_alfa(cor, f * f * 0.60), true, -1.0, true)

	# Faíscas espalhadas em volta do rastro, para o traço não virar um risco só.
	for i in FAISCAS:
		var atraso := 2 + i * 2
		if atraso >= _trilha.size():
			break
		var s := float(i)
		var f := 1.0 - float(atraso) / float(_trilha.size())
		var desvio := Vector2(sin(_tempo * 9.0 + s * 2.1), cos(_tempo * 7.3 + s * 1.7)) \
			* (6.0 + s * 2.0) * (1.0 - f)
		draw_circle(local * _trilha[atraso] + desvio, 1.0 + f * 1.6,
			EstiloHUD.com_alfa(cor, f * 0.35), true, -1.0, true)

	# Halo à frente e o desenho do item.
	var vida := 1.0 - (u * u if apagar_ao_chegar else 0.0)
	EstiloHUD.halo(self, ponta, caixa * 0.8, cor, 6, 0.9 * vida)
	EstiloHUD.icone(self, textura, ponta, caixa,
		EstiloHUD.com_alfa(Color.WHITE, vida))
