@tool
class_name ArteIluminada
extends Node2D
## A arte do fundo acesa por luz artificial, de noite.
##
## Ponha este nó como FILHO do Sprite2D de uma camada do parallax, na posição
## (0, 0). Ele redesenha a arte do pai nas cores originais, só dentro dos focos
## de luz (os nós [FocoDeLuz] filhos dele) — por cima da versão escurecida que
## a [Atmosfera] pinta à noite. É assim que o foguete lá no fundo ganha
## holofote, o hangar ganha portão iluminado e a antena ganha farol, sem
## ninguém pintar uma segunda arte "de noite".
##
## Para acender outro ponto: duplique um FocoDeLuz e arraste. Cabem até 8.
##
## A força acompanha o horário, pela mesma régua dos postes
## ([member PerfilDeLuz.postes]): quase nada ao entardecer, com tudo à noite.

const SHADER := preload("res://shaders/arte_iluminada.gdshader")
const MAXIMO := 8

@export_group("Pixel art")
## Em quantos degraus cada foco cai.
@export_range(2, 12, 1) var degraus := 5:
	set(v):
		degraus = v
		_atualizar()
## Quanto de cada degrau é pontilhado na emenda.
@export_range(0.0, 1.0, 0.01) var pontilhado := 0.5:
	set(v):
		pontilhado = v
		_atualizar()
## Tamanho do pixel de arte, em pixels da textura do pai. O padrão compensa a
## escala da arte da base, para o pontilhado sair do tamanho do resto do fundo.
@export_range(1.0, 12.0, 0.5) var pixel := 3.0:
	set(v):
		pixel = v
		_atualizar()

@export_group("Horário")
## A partir de que força dos postes (0 a 1) estas luzes começam a aparecer. Com
## 0,5 elas ficam apagadas ao entardecer e acendem no pôr do sol.
@export_range(0.0, 1.0, 0.01) var acende_a_partir_de := 0.5

var _item: RID
var _material: ShaderMaterial
var _intensidade := 0.0
var _relogio := 0.0
var _textura_desenhada: Texture2D


func _enter_tree() -> void:
	add_to_group(Atmosfera.GRUPO_DE_CLIENTES)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_item, get_canvas_item())
	RenderingServer.canvas_item_set_material(_item, _material.get_rid())
	_textura_desenhada = null
	_atualizar()


func _exit_tree() -> void:
	if _item.is_valid():
		RenderingServer.free_rid(_item)
		_item = RID()


func _process(delta: float) -> void:
	_relogio += delta
	_redesenhar_se_preciso()
	_enviar_focos()


## Chamado pela Atmosfera: a hora decide quanto estas luzes aparecem.
func receber_perfil(perfil: PerfilDeLuz) -> void:
	var folga := maxf(1.0 - acende_a_partir_de, 0.001)
	_intensidade = clampf((perfil.postes - acende_a_partir_de) / folga, 0.0, 1.0)
	if _material:
		_material.set_shader_parameter(&"intensidade", _intensidade)


func _atualizar() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"degraus", float(degraus))
	_material.set_shader_parameter(&"pontilhado", pontilhado)
	_material.set_shader_parameter(&"pixel", pixel)
	_material.set_shader_parameter(&"intensidade", _intensidade)


# A arte é a do Sprite2D pai, no mesmo retângulo em que ele a desenha.
func _redesenhar_se_preciso() -> void:
	var pai := get_parent() as Sprite2D
	var textura: Texture2D = pai.texture if pai != null else null
	if textura == _textura_desenhada or not _item.is_valid():
		return
	_textura_desenhada = textura
	RenderingServer.canvas_item_clear(_item)
	if textura == null:
		return
	var tamanho := textura.get_size()
	var origem := -tamanho * 0.5 if pai.centered else Vector2.ZERO
	RenderingServer.canvas_item_add_texture_rect(_item, Rect2(origem + pai.offset - position, tamanho),
		textura.get_rid())


func _enviar_focos() -> void:
	if _material == null:
		return
	var focos := PackedVector4Array()
	var cores := PackedColorArray()
	for filho in get_children():
		var foco := filho as FocoDeLuz
		if foco == null or not foco.visible:
			continue
		if focos.size() >= MAXIMO:
			break
		focos.append(Vector4(foco.position.x, foco.position.y, foco.raio, foco.forca_agora(_relogio)))
		cores.append(foco.cor)
	var quantidade := focos.size()
	# O shader espera as listas sempre do mesmo tamanho.
	while focos.size() < MAXIMO:
		focos.append(Vector4.ZERO)
		cores.append(Color.BLACK)
	_material.set_shader_parameter(&"focos", focos)
	_material.set_shader_parameter(&"cores", cores)
	_material.set_shader_parameter(&"quantidade", quantidade)
