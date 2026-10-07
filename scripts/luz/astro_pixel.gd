@tool
class_name AstroPixel
extends Sprite2D
## O sol ou a lua: um sprite comum (o disco) com um brilho em volta.
##
## O disco é a `Texture` do próprio nó — troque a arte por qualquer PNG, mude a
## escala, arraste no editor: é um Sprite2D como outro qualquer. O que este
## script acrescenta é o HALO (ver `shaders/brilho_pixel.gdshader`), que sai de
## dois jeitos:
##
##   liso      um degradê contínuo, que respira devagar. É o padrão (a lua).
##   pixelado  anéis chapados, com a emenda em pontilhado, que respiram em
##             quadros secos ([member brilho_pixelado] — é o do sol do world1).
##
## Tudo dele se mexe aqui no Inspector, nos grupos Brilho, Pixel art, Pontas e
## Animação.
##
## As medidas do brilho são em PIXELS DA ARTE do disco (texels), não da tela:
## aumentar a escala do nó aumenta o halo junto.
##
## A [Atmosfera] da cena acende e apaga o astro conforme o horário (o sol some à
## noite, a lua só aparece nela) e tinge o sol quando ele desce. Ela faz isso
## por baixo, no render, sem mexer nas propriedades do nó — o que está salvo na
## cena é sempre o que você deixou.

enum Tipo { SOL, LUA }

const SHADER := preload("res://shaders/brilho_pixel.gdshader")

## Quem é este astro. É o que diz à Atmosfera quando ele aparece.
@export var tipo := Tipo.SOL

@export_group("Brilho")
## Raio do disco, em pixels da arte. 0 = metade da largura da textura.
@export_range(0.0, 256.0, 0.5) var raio_do_disco := 0.0:
	set(v):
		raio_do_disco = v
		_atualizar()
## Até onde o brilho chega, contando do centro, em pixels da arte.
@export_range(4.0, 400.0, 1.0) var alcance := 84.0:
	set(v):
		alcance = v
		_atualizar()
## Cor do brilho colado no disco.
@export var cor_interna := Color(1.0, 0.95, 0.66):
	set(v):
		cor_interna = v
		_atualizar()
## Cor do brilho na beirada de fora.
@export var cor_externa := Color(1.0, 0.56, 0.38):
	set(v):
		cor_externa = v
		_atualizar()
@export_range(0.0, 2.0, 0.01) var intensidade := 0.9:
	set(v):
		intensidade = v
		_atualizar()
## Como o brilho entra no céu: 0 soma (só clareia — bom em céu escuro, é o da
## lua), 1 cobre (uma tinta por cima — bom em céu claro, onde somar estoura no
## branco; é o do sol).
@export_range(0.0, 1.0, 0.01) var cobertura := 1.0:
	set(v):
		cobertura = v
		_atualizar()
## Curva da queda: maior aperta o brilho contra o disco.
@export_range(0.3, 4.0, 0.05) var queda := 1.3:
	set(v):
		queda = v
		_atualizar()
## Achata o halo na vertical (1 = redondo, maior que 1 = deitado).
@export_range(0.3, 3.0, 0.05) var achatamento := 1.0:
	set(v):
		achatamento = v
		_atualizar()

@export_group("Pixel art")
## Desligado (o padrão), o brilho é um degradê liso. Ligado, ele vira anéis
## chapados com a emenda pontilhada, no tamanho do pixel da arte do disco.
@export var brilho_pixelado := false:
	set(v):
		brilho_pixelado = v
		_atualizar()
## Quantos anéis de luz. Só vale com [member brilho_pixelado] ligado.
@export_range(1, 12, 1) var aneis := 5:
	set(v):
		aneis = v
		_atualizar()
## Quanto de cada anel é pontilhado na emenda (0 = anéis secos). Só vale com
## [member brilho_pixelado] ligado.
@export_range(0.0, 1.0, 0.01) var pontilhado := 0.5:
	set(v):
		pontilhado = v
		_atualizar()

@export_group("Pontas")
## Quantas pontas de luz saem do halo. 0 = sem pontas.
@export_range(0, 24, 1) var pontas := 0:
	set(v):
		pontas = v
		_atualizar()
## Quanto elas avançam além do halo.
@export_range(0.0, 1.0, 0.01) var alcance_das_pontas := 0.35:
	set(v):
		alcance_das_pontas = v
		_atualizar()
@export_range(0.05, 1.0, 0.01) var largura_das_pontas := 0.42:
	set(v):
		largura_das_pontas = v
		_atualizar()

@export_group("Animação")
## Ritmo da respiração do brilho: quadros por segundo no pixelado, e o mesmo
## compasso, em onda, no liso. 0 = parado.
@export_range(0.0, 12.0, 0.1) var quadros_por_segundo := 2.0:
	set(v):
		quadros_por_segundo = v
		_atualizar()
## Quanto o brilho cresce e encolhe a cada compasso.
@export_range(0.0, 1.0, 0.01) var respiro := 0.18:
	set(v):
		respiro = v
		_atualizar()

## Quanto o astro desceu da posição em que foi deixado na cena, em pixels da
## camada. É a Atmosfera que anima isto no pôr do sol; só vale no jogo.
var descida := 0.0:
	set(v):
		descida = v
		if _tem_base:
			position = _base + Vector2(0.0, descida)

var _item: RID
var _material: ShaderMaterial
var _peso := 1.0
var _tinta := Color.WHITE
var _modulacao_enviada := Color(-1, -1, -1, -1)
var _base := Vector2.ZERO
var _tem_base := false


func _enter_tree() -> void:
	add_to_group(Atmosfera.GRUPO_DE_CLIENTES)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_item, get_canvas_item())
	RenderingServer.canvas_item_set_draw_behind_parent(_item, true)
	RenderingServer.canvas_item_set_material(_item, _material.get_rid())
	_modulacao_enviada = Color(-1, -1, -1, -1)
	_atualizar()


func _ready() -> void:
	if not Engine.is_editor_hint():
		_base = position
		_tem_base = true
	if not texture_changed.is_connected(_atualizar):
		texture_changed.connect(_atualizar)


func _exit_tree() -> void:
	if _item.is_valid():
		RenderingServer.free_rid(_item)
		_item = RID()


func _process(_delta: float) -> void:
	_enviar_presenca()


## Chamado pela Atmosfera: quanto deste astro existe agora, e com que tinta.
func receber_perfil(perfil: PerfilDeLuz) -> void:
	if tipo == Tipo.SOL:
		_peso = perfil.sol
		_tinta = perfil.tinta_do_sol
	else:
		_peso = perfil.lua
		_tinta = Color.WHITE
	_enviar_presenca()


## Presença de 0 a 1 no horário atual (0 = fora do céu).
func presenca() -> float:
	return _peso


## Raio do disco em pixels da arte — o exportado, ou o que a textura tiver.
func raio_efetivo() -> float:
	if raio_do_disco > 0.0:
		return raio_do_disco
	if texture == null:
		return 16.0
	var tamanho := region_rect.size if region_enabled else texture.get_size()
	return minf(tamanho.x, tamanho.y) * 0.5


# A presença e a tinta vão direto para o render, por cima do `modulate` do nó:
# nada disso é propriedade salva, então o editor não suja a cena ao mostrar a
# noite numa fase que começa de dia.
func _enviar_presenca() -> void:
	if not is_inside_tree():
		return
	var m := modulate
	var alvo := Color(m.r * _tinta.r, m.g * _tinta.g, m.b * _tinta.b, m.a * clampf(_peso, 0.0, 1.0))
	if alvo.is_equal_approx(_modulacao_enviada):
		return
	_modulacao_enviada = alvo
	RenderingServer.canvas_item_set_modulate(get_canvas_item(), alvo)


func _atualizar() -> void:
	if not _item.is_valid():
		return
	var disco := raio_efetivo()
	var fora := maxf(alcance, disco + 1.0)
	var borda := ceilf(disco + (fora - disco) * (1.0 + alcance_das_pontas)) + 2.0
	RenderingServer.canvas_item_clear(_item)
	RenderingServer.canvas_item_add_rect(_item,
		Rect2(-borda, -borda / achatamento, borda * 2.0, borda * 2.0 / achatamento), Color.WHITE)

	_material.set_shader_parameter(&"raio_do_disco", disco)
	_material.set_shader_parameter(&"raio", fora)
	_material.set_shader_parameter(&"pixelado", 1.0 if brilho_pixelado else 0.0)
	_material.set_shader_parameter(&"aneis", float(aneis))
	_material.set_shader_parameter(&"cor_interna", cor_interna)
	_material.set_shader_parameter(&"cor_externa", cor_externa)
	_material.set_shader_parameter(&"intensidade", intensidade)
	_material.set_shader_parameter(&"cobertura", cobertura)
	_material.set_shader_parameter(&"queda", queda)
	_material.set_shader_parameter(&"pontilhado", pontilhado)
	_material.set_shader_parameter(&"achatamento", achatamento)
	_material.set_shader_parameter(&"pontas", float(pontas))
	_material.set_shader_parameter(&"alcance_das_pontas", alcance_das_pontas)
	_material.set_shader_parameter(&"largura_das_pontas", largura_das_pontas)
	_material.set_shader_parameter(&"quadros_por_segundo", quadros_por_segundo)
	_material.set_shader_parameter(&"respiro", respiro)
