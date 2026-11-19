@tool
class_name CilindrosDoTelhado
extends Node2D

# --- A ESTANTE DE CILINDROS DO TELHADO (fase 2) ---
#
# Os cilindros de amostra vazios, de pé no telhado em FILEIRAS (do fundo para
# a frente, na faixa por onde a Cacau anda) e COLUNAS (da esquerda para a
# direita). Cada lugar vira um CilindroDoTelhado (componentes/
# cilindro_do_telhado.tscn) quando o jogo abre — é ali que estão a regra de
# "um de cada vez" e o E do mais perto.
#
# COMO EDITAR NO EDITOR (Inspector deste nó):
#   posição do nó         -> y: a BASE da fileira do FUNDO; x: o meio do
#                            primeiro cilindro (à esquerda) da fileira da
#                            FRENTE (as de trás andam o desvio_por_fileira)
#   fileiras / colunas    -> quantos
#   entre_colunas         -> de um cilindro para o do lado (px)
#   entre_fileiras        -> de uma fileira para a da frente (px, para baixo:
#                            mais para a frente da faixa)
#   escala_dos_cilindros  -> o tamanho de cada um (0,6 = o do cilindro que
#                            ficava sozinho aqui)
#   desvio_por_fileira    -> quanto cada fileira mais do fundo anda para o lado
#                            (o cilindro de trás aparece entre os da frente).
#                            Negativo = para a esquerda, como o cenário do
#                            telhado: a fileira da frente fica mais à direita
#   tom_do_fundo          -> a sombra da fileira do fundo
# No editor, a estante aparece desenhada; os nós dos cilindros só existem com o
# jogo rodando. A fileira da frente precisa caber na FaixaDoChao (y até 570) e
# fica com os pés atrás da grade da frente, como a Cacau.
#
# O cilindro que ela pega some de vez (EstadoMundo pelo caminho do nó: o nome
# de cada um é "Fileira<f>Coluna<c>", então mudar fileiras/colunas pode trazer
# de volta, numa partida já começada, o que ela tinha pegado — só no editor).
#
# A LUZ: uma só, em cima da estante, pulsando enquanto ela ainda não pegou o
# dela (os cilindros daqui não trazem a luz de cada um).

const CILINDRO := preload("res://scenes/fases/componentes/cilindro_do_telhado.tscn")
const ARTE := preload("res://assets/fase nitrogenio/Cilindro de Ar.png")
## O Sprite do componente: escala 2, com a base na origem e o meio em x.
const ESCALA_DA_ARTE := 2.0

@export_range(1, 6, 1) var fileiras: int = 3:
	set(valor):
		fileiras = valor
		queue_redraw()
@export_range(1, 12, 1) var colunas: int = 6:
	set(valor):
		colunas = valor
		queue_redraw()
@export_range(16.0, 120.0, 1.0, "suffix:px") var entre_colunas: float = 40.0:
	set(valor):
		entre_colunas = valor
		queue_redraw()
@export_range(4.0, 40.0, 1.0, "suffix:px") var entre_fileiras: float = 16.0:
	set(valor):
		entre_fileiras = valor
		queue_redraw()
## O tamanho de cada cilindro (1 = o do componente, a arte em escala 2).
@export_range(0.2, 2.0, 0.05) var escala_dos_cilindros: float = 0.6:
	set(valor):
		escala_dos_cilindros = valor
		queue_redraw()
## Quanto cada fileira mais do fundo anda para o lado (px; negativo = para a
## esquerda, como no telhado, e positivo = para a direita): assim aparece o
## cilindro de trás, entre os da frente. 0 = todas alinhadas.
@export_range(-40.0, 40.0, 1.0, "suffix:px") var desvio_por_fileira: float = -6.0:
	set(valor):
		desvio_por_fileira = valor
		queue_redraw()
## O tom da fileira do FUNDO (a da frente fica com a cor da arte; as do meio,
## entre as duas): a sombra que dá a profundidade.
@export var tom_do_fundo: Color = Color(0.62, 0.62, 0.72):
	set(valor):
		tom_do_fundo = valor
		queue_redraw()

var _luz: LuzPontual = null
var _tempo: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Do fundo para a frente: a fileira da frente é desenhada por cima.
	for f in fileiras:
		for c in colunas:
			var cilindro := CILINDRO.instantiate() as CilindroDoTelhado
			cilindro.name = "Fileira%dColuna%d" % [f + 1, c + 1]
			cilindro.position = lugar(f, c)
			cilindro.scale = Vector2.ONE * escala_dos_cilindros
			cilindro.get_node("Sprite").modulate = tom(f)
			var luz := cilindro.get_node_or_null("Luz")
			if luz:
				cilindro.remove_child(luz)
				luz.free()
			add_child(cilindro)
	_luz = LuzPontual.new()
	_luz.name = "Luz"
	_luz.cor = Color(0.78, 0.88, 1, 1)
	_luz.raio = maxf(130.0, (colunas - 1) * entre_colunas * 0.75)
	_luz.position = Vector2((colunas - 1) * entre_colunas * 0.5, (fileiras - 1) * entre_fileiras * 0.5 - 40.0)
	add_child(_luz)


## Onde fica a base do cilindro da fileira "f" e coluna "c" (a partir de 0;
## a fileira 0 é a do fundo).
func lugar(f: int, c: int) -> Vector2:
	return Vector2(c * entre_colunas + (fileiras - 1 - f) * desvio_por_fileira, f * entre_fileiras)


## O tom da fileira "f": tom_do_fundo lá atrás, a cor da arte na frente.
func tom(f: int) -> Color:
	if fileiras <= 1:
		return Color.WHITE
	return tom_do_fundo.lerp(Color.WHITE, float(f) / float(fileiras - 1))


## Os cilindros que ainda estão de pé aqui.
func cilindros() -> Array[CilindroDoTelhado]:
	var lista: Array[CilindroDoTelhado] = []
	for filho in get_children():
		if filho is CilindroDoTelhado and (filho as CilindroDoTelhado).ainda_no_lugar():
			lista.append(filho)
	return lista


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _luz == null:
		return
	_tempo += delta
	var acesa := not CilindroDoTelhado.cacau_tem_um(get_tree())
	_luz.energia = move_toward(_luz.energia, (0.75 + 0.15 * sin(_tempo * 2.2)) if acesa else 0.0, delta * 2.0)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var tamanho := ARTE.get_size() * ESCALA_DA_ARTE * escala_dos_cilindros
	for f in fileiras:
		for c in colunas:
			var base := lugar(f, c)
			draw_texture_rect(ARTE, Rect2(base - Vector2(tamanho.x * 0.5, tamanho.y), tamanho), false, tom(f))
