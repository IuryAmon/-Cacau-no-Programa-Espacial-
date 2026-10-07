@tool
class_name Nuvens
extends ParallaxLayer
## Uma faixa de nuvens passando no céu.
##
## Sorteia as nuvens do pacote (cloud1 a cloud6, da menor para a maior), espalha
## numa faixa de altura e leva todas com o vento, cada uma num passo um pouco
## diferente — é o que impede o céu de parecer uma esteira rolando. Quem sai de
## um lado do quadro volta pelo outro, bem fora da vista.
##
## Para dar profundidade, use mais de uma faixa: uma de nuvens miúdas, lentas e
## desbotadas lá atrás, outra de nuvens grandes na frente. Cada nó Nuvens é uma
## faixa; a ordem delas dentro do BG é a ordem de desenho.
##
## A COR não é daqui: as nuvens trocam de tom com o horário, pelo [PerfilDeLuz]
## que a [Atmosfera] distribui (douradas ao entardecer, azul-escuras à noite).
##
## O sorteio é fixo pela [member semente]: a mesma semente dá sempre o mesmo
## céu, no editor e no jogo. Troque o número para embaralhar.

const SHADER := preload("res://shaders/nuvem.gdshader")
const PASTA := "res://assets/Area Aberta/GandalfHardcore Background layers/"
## Do cloud1.png (25 px) ao cloud6.png (165 px).
const ARQUIVOS := ["cloud1.png", "cloud2.png", "cloud3.png", "cloud4.png", "cloud5.png", "cloud6.png"]

@export_group("Nuvens")
## Quantas nuvens nesta faixa.
@export_range(0, 24, 1) var quantidade := 6:
	set(v):
		quantidade = v
		_sortear()
## A menor arte que entra no sorteio (1 = cloud1, a miúda).
@export_range(1, 6, 1) var menor := 1:
	set(v):
		menor = v
		_sortear()
## A maior arte que entra no sorteio (6 = cloud6, a montanha de nuvem).
@export_range(1, 6, 1) var maior := 4:
	set(v):
		maior = v
		_sortear()
## Escala do desenho. 2 = a mesma das camadas do fundo.
@export_range(0.5, 6.0, 0.5) var escala := 2.0:
	set(v):
		escala = v
		_sortear()
## Troque para embaralhar o céu.
@export var semente := 7:
	set(v):
		semente = v
		_sortear()

@export_group("Lugar")
## De que altura a que altura as nuvens ficam, em pixels da camada (topo, base).
@export var faixa := Vector2(-40, 170):
	set(v):
		faixa = v
		_sortear()
## Largura da volta: quem some de um lado reaparece do outro depois de andar
## isto. Tem de ser maior que a tela (1067) mais a maior nuvem.
@export_range(1200.0, 6000.0, 10.0) var volta := 1800.0:
	set(v):
		volta = v
		_sortear()

@export_group("Vento")
## Velocidade em pixels da camada por segundo. Negativo sopra para a esquerda.
@export_range(-60.0, 60.0, 0.5) var vento := 5.0
## Quanto cada nuvem foge do passo das outras (0 = todas juntas).
@export_range(0.0, 0.9, 0.01) var variacao := 0.35:
	set(v):
		variacao = v
		_sortear()

@export_group("Distância")
## Quanto estas nuvens desbotam na cor do céu (0 = perto, 1 = sumindo no ar).
@export_range(0.0, 1.0, 0.01) var distancia := 0.2:
	set(v):
		distancia = v
		_pintar()
@export_range(0.0, 1.0, 0.01) var opacidade := 1.0:
	set(v):
		opacidade = v
		_pintar()

var _material: ShaderMaterial
var _texturas: Array[Texture2D] = []
## Uma entrada por nuvem: {"item": RID, "x": float, "y": float, "passo": float,
## "espelho": float, "meia": float}.
var _nuvens: Array[Dictionary] = []
var _perfil: PerfilDeLuz
var _tempo := 0.0


func _enter_tree() -> void:
	add_to_group(Atmosfera.GRUPO_DE_CLIENTES)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	if _texturas.is_empty():
		for arquivo in ARQUIVOS:
			_texturas.append(load(PASTA + arquivo) as Texture2D)
	_sortear()


func _exit_tree() -> void:
	_soltar()


func _process(delta: float) -> void:
	_tempo += delta
	_mover()


## Chamado pela Atmosfera: as cores do horário.
func receber_perfil(perfil: PerfilDeLuz) -> void:
	_perfil = perfil
	_pintar()


func _soltar() -> void:
	for nuvem in _nuvens:
		RenderingServer.free_rid(nuvem["item"])
	_nuvens.clear()


func _sortear() -> void:
	if not is_inside_tree() or _material == null:
		return
	_soltar()

	var primeira := clampi(mini(menor, maior), 1, ARQUIVOS.size()) - 1
	var ultima := clampi(maxi(menor, maior), 1, ARQUIVOS.size()) - 1
	var sorte := RandomNumberGenerator.new()
	sorte.seed = hash(semente)

	for i in quantidade:
		var textura := _texturas[sorte.randi_range(primeira, ultima)]
		if textura == null:
			continue
		var tamanho := textura.get_size()
		var item := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(item, get_canvas_item())
		RenderingServer.canvas_item_set_material(item, _material.get_rid())
		RenderingServer.canvas_item_set_default_texture_filter(item,
			RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
		RenderingServer.canvas_item_add_texture_rect(item,
			Rect2(-tamanho * 0.5, tamanho), textura.get_rid())
		# As de trás da própria faixa ficam um nada mais apagadas.
		RenderingServer.canvas_item_set_modulate(item, Color(1, 1, 1, sorte.randf_range(0.82, 1.0)))

		# Espalhadas por igual na volta, com uma folga sorteada: sem isso o
		# sorteio puro amontoa três num canto e deixa o resto do céu vazio.
		var fatia := volta / maxf(1.0, float(quantidade))
		_nuvens.append({
			"item": item,
			"x": fatia * (float(i) + sorte.randf_range(0.1, 0.9)),
			"y": lerpf(faixa.x, faixa.y, sorte.randf()),
			"passo": 1.0 + sorte.randf_range(-variacao, variacao),
			"espelho": -1.0 if sorte.randf() < 0.5 else 1.0,
			"meia": tamanho.x * 0.5 * escala,
		})
	_pintar()
	_mover()


func _mover() -> void:
	if _nuvens.is_empty():
		return
	# A beirada esquerda do que a câmera mostra, em coordenadas desta camada.
	# No editor não há câmera de jogo: as nuvens ficam em volta do quadro.
	var esquerda := 0.0
	if not Engine.is_editor_hint():
		esquerda = (get_global_transform_with_canvas().affine_inverse() * Vector2.ZERO).x
	for nuvem in _nuvens:
		var margem: float = nuvem["meia"] + 8.0
		var x: float = esquerda - margem + fposmod(
			nuvem["x"] + vento * nuvem["passo"] * _tempo - esquerda, volta)
		# Um pixel de tela de cada vez (a câmera do jogo tem zoom 1,5).
		x = snappedf(x, 2.0 / 3.0)
		RenderingServer.canvas_item_set_transform(nuvem["item"], Transform2D(
			Vector2(escala * nuvem["espelho"], 0.0), Vector2(0.0, escala), Vector2(x, nuvem["y"])))


func _pintar() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"neblina", distancia)
	if _perfil == null:
		_material.set_shader_parameter(&"opacidade", opacidade)
		return
	_material.set_shader_parameter(&"cor_luz", _perfil.nuvem_luz)
	_material.set_shader_parameter(&"cor_sombra", _perfil.nuvem_sombra)
	_material.set_shader_parameter(&"ar", _perfil.ceu_baixo)
	_material.set_shader_parameter(&"opacidade", opacidade * _perfil.nuvem_opacidade)
