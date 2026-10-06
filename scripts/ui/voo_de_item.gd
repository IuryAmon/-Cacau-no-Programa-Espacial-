class_name VooDeItem
extends Control

# --- O ÍCONE INDO DA FICHA PARA A MOCHILA ---
#
# O pedaço que amarra as duas telas. Quando a pessoa fecha a ficha de coleta,
# o desenho do item não some do centro para reaparecer numa casa: ele se solta
# da ficha, faz uma curva pelo alto e cai na casa dele, encolhendo até o
# tamanho de lá. A casa só acende quando o ícone chega.
#
# É a diferença entre "o jogo guardou alguma coisa em algum lugar" e "eu vi
# onde isso foi parar" — e é por isso que a ficha de coleta não precisa
# escrever o destino.
#
# Serve tanto para a mochila quanto para os equipamentos (que ficam no canto
# de baixo): quem chama diz de onde para onde, e em que tamanho começa e
# termina.
#
# O rastro é de quadradinhos chapados na cor do item, que diminuem para trás:
# pixel, como o resto do HUD.

signal chegou

## Rastro: quantas posições anteriores continuam desenhadas atrás do ícone.
const RASTRO := 12

var textura: Texture2D = null
var cor: Color = EstiloHUD.ACENTO_PADRAO
var duracao: float = 0.52
## O ícone chega inteiro ou vai apagando no caminho (usado pelos equipamentos,
## que fazem a própria ficha brotar na chegada).
var apagar_ao_chegar: bool = false

var _inicio: Vector2 = Vector2.ZERO
var _fim: Vector2 = Vector2.ZERO
var _controle: Vector2 = Vector2.ZERO
var _caixa_inicio: float = 80.0
var _caixa_fim: float = 48.0
var _tempo: float = 0.0
var _trilha: Array[Vector2] = []


## Cria o voo já pendurado em "pai" (a camada do HUD) e o dispara. Os pontos
## são em coordenadas de tela — os mesmos que PopupItem.centro_do_icone() e
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
	# Ponto de controle acima da reta: a curva sobe antes de cair na casa, que
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

	# Rastro: quadradinhos na cor do item, um sim, um não, diminuindo para trás.
	for i in range(2, _trilha.size(), 2):
		var f := 1.0 - float(i) / float(_trilha.size())
		var lado := maxf(roundf(caixa * 0.16 * f), 2.0)
		draw_rect(Rect2((local * _trilha[i] - Vector2(lado, lado) * 0.5).round(),
			Vector2(lado, lado)), EstiloHUD.com_alfa(cor, f))

	# O desenho do item, com a sombra dura caída embaixo dele.
	var vida := 1.0 - (u * u if apagar_ao_chegar else 0.0)
	EstiloHUD.icone(self, textura, ponta + Vector2(0.0, EstiloHUD.QUEDA), caixa,
		EstiloHUD.com_alfa(Color(0.0, 0.0, 0.0, EstiloHUD.SOMBRA_DURA.a), vida))
	EstiloHUD.icone(self, textura, ponta, caixa,
		EstiloHUD.com_alfa(Color.WHITE, vida))
