@tool
class_name CeuPixel
extends ParallaxLayer
## O céu da fase: degradê em faixas, estrelas e o clarão do astro, tudo em
## pixel art (ver `shaders/ceu_pixel.gdshader`).
##
## Não tem textura nem filho nenhum: o céu é uma conta, desenhada direto no
## servidor de render. Por isso ele não aparece como nó clicável no editor, não
## rouba clique de ninguém e não grava nada na cena além do que está aqui no
## Inspector.
##
## As CORES não ficam aqui — vêm do [PerfilDeLuz] que a [Atmosfera] da cena
## estiver usando (entardecer, noite...). Aqui fica só o desenho: onde o degradê
## começa e termina, quantas faixas, o tamanho do pixel, as estrelas.
##
## [b]Paralaxe:[/b] dê a esta camada o mesmo `motion_scale.y` da serra do fundo.
## Assim o horizonte do degradê sobe e desce junto com a serra quando a câmera
## muda de altura, em vez de ficar pregado na tela.

const SHADER := preload("res://shaders/ceu_pixel.gdshader")

@export_group("Degradê")
## Altura (em pixels da camada) onde o céu já é a cor do zênite.
@export var y_do_zenite := -180.0:
	set(v):
		y_do_zenite = v
		_atualizar()
## Altura onde o céu chega à cor do horizonte — ponha na linha da serra.
@export var y_do_horizonte := 300.0:
	set(v):
		y_do_horizonte = v
		_atualizar()
## Onde ficam as duas cores do meio, de 0 (zênite) a 1 (horizonte).
@export_range(0.05, 0.9, 0.01) var parada_alto := 0.42:
	set(v):
		parada_alto = v
		_atualizar()
@export_range(0.1, 0.98, 0.01) var parada_baixo := 0.78:
	set(v):
		parada_baixo = v
		_atualizar()

@export_group("Pixel art")
## Tamanho do pixel de arte, em pixels da camada. 2 = o mesmo das camadas do
## fundo (que estão em escala 2).
@export_range(1.0, 8.0, 0.5) var pixel := 2.0:
	set(v):
		pixel = v
		_atualizar()
## Quantas faixas de cor o degradê tem.
@export_range(2, 48, 1) var degraus := 16:
	set(v):
		degraus = v
		_atualizar()
## Quanto de cada faixa é pontilhado na emenda com a próxima. 0 = faixas secas.
@export_range(0.0, 1.0, 0.01) var pontilhado := 0.6:
	set(v):
		pontilhado = v
		_atualizar()
## Desenho do pontilhado.
@export_enum("Xadrez", "Linhas") var trama := 0:
	set(v):
		trama = v
		_atualizar()

@export_group("Estrelas")
## Fração das células do céu que tem estrela. As grandes (em cruz) rareiam
## junto com as miúdas.
@export_range(0.0, 0.1, 0.001) var densidade := 0.002:
	set(v):
		densidade = v
		_atualizar()
## Tamanho do pixel das estrelas, em pixels da camada. Menor que o `pixel` do
## céu, elas ficam mais finas que a granulação dele; a quantidade não muda.
@export_range(0.5, 8.0, 0.5) var tamanho_das_estrelas := 1.0:
	set(v):
		tamanho_das_estrelas = v
		_atualizar()
@export var cor_das_estrelas := Color(0.75, 0.79, 1.0):
	set(v):
		cor_das_estrelas = v
		_atualizar()
## Velocidade do pisca-pisca (0 = paradas).
@export_range(0.0, 2.0, 0.05) var cintilar := 1.0:
	set(v):
		cintilar = v
		_atualizar()

@export_group("Clarão do astro")
## Tamanho da mancha clara que o sol (ou a lua) abre no céu em volta dele.
@export var raio_do_clarao := Vector2(360, 150):
	set(v):
		raio_do_clarao = v
		_atualizar()

var _item: RID
var _material: ShaderMaterial
var _perfil: PerfilDeLuz
var _astro := Vector2.ZERO


func _enter_tree() -> void:
	add_to_group(Atmosfera.GRUPO_DE_CLIENTES)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_item, get_canvas_item())
	RenderingServer.canvas_item_set_material(_item, _material.get_rid())
	_atualizar()


func _exit_tree() -> void:
	if _item.is_valid():
		RenderingServer.free_rid(_item)
		_item = RID()


## Chamado pela Atmosfera: as cores do horário.
func receber_perfil(perfil: PerfilDeLuz) -> void:
	_perfil = perfil
	_pintar()


## Chamado pela Atmosfera: onde está o astro que manda no céu agora, em
## coordenadas desta camada.
func definir_astro(posicao: Vector2) -> void:
	if posicao.is_equal_approx(_astro):
		return
	_astro = posicao
	if _material:
		_material.set_shader_parameter(&"astro", _astro)


func _atualizar() -> void:
	if not _item.is_valid():
		return
	RenderingServer.canvas_item_clear(_item)
	RenderingServer.canvas_item_add_rect(_item, _area(), Color.WHITE)

	_material.set_shader_parameter(&"y_zenite", y_do_zenite)
	_material.set_shader_parameter(&"y_horizonte", y_do_horizonte)
	_material.set_shader_parameter(&"parada_alto", parada_alto)
	_material.set_shader_parameter(&"parada_baixo", maxf(parada_baixo, parada_alto + 0.02))
	_material.set_shader_parameter(&"pixel", pixel)
	_material.set_shader_parameter(&"degraus", float(degraus))
	_material.set_shader_parameter(&"pontilhado", pontilhado)
	_material.set_shader_parameter(&"trama", float(trama))
	_material.set_shader_parameter(&"densidade", densidade)
	_material.set_shader_parameter(&"pixel_das_estrelas", tamanho_das_estrelas)
	_material.set_shader_parameter(&"cor_das_estrelas", cor_das_estrelas)
	_material.set_shader_parameter(&"cintilar", cintilar)
	_material.set_shader_parameter(&"raio_do_clarao", raio_do_clarao)
	_material.set_shader_parameter(&"astro", _astro)
	_pintar()


func _pintar() -> void:
	if _material == null or _perfil == null:
		return
	_material.set_shader_parameter(&"cor_zenite", _perfil.ceu_zenite)
	_material.set_shader_parameter(&"cor_alto", _perfil.ceu_alto)
	_material.set_shader_parameter(&"cor_baixo", _perfil.ceu_baixo)
	_material.set_shader_parameter(&"cor_horizonte", _perfil.ceu_horizonte)
	_material.set_shader_parameter(&"estrelas", _perfil.estrelas)
	_material.set_shader_parameter(&"clarao", _perfil.clarao)


## No jogo o céu cobre o que a câmera puder ver, com folga de sobra. No editor
## ele fica só em volta do quadro, para não forrar a viewport inteira.
func _area() -> Rect2:
	if Engine.is_editor_hint():
		return Rect2(-1200.0, y_do_zenite - 240.0, 4200.0, (y_do_horizonte - y_do_zenite) + 700.0)
	return Rect2(-40000.0, -40000.0, 80000.0, 80000.0)
