@tool
class_name LuzPontual
extends Node2D
## Uma luz redonda em pixel art, para o que brilha por conta própria: o fogo da
## fornalha, um laser, a tela de um painel, um farol.
##
## São duas peças: a POÇA (uma PointLight2D, que ilumina de verdade o que está
## em volta) e o CLARÃO (um brilho somado no ar, que é o que se vê contra o
## escuro). As duas caem em degraus com emenda pontilhada ([TexturaDeLuz]), no
## tamanho do pixel do cenário.
##
## [b]Sozinha ou com o horário.[/b] Com [member segue_o_horario] desligado ela
## brilha sempre que estiver [member acesa] — é o caso do fogo. Ligado, ela
## entra no grupo das luzes artificiais e a [Atmosfera] regula a força pela
## hora: fraca ao entardecer, com tudo à noite, e APAGADA numa cena que não tem
## Atmosfera nenhuma. É o que deixa um mesmo objeto (o laser, que existe ao ar
## livre e dentro do laboratório) acender só onde está escuro.

const GRUPO := &"luz_artificial"
## Tamanho do pixel de arte no mundo (os tiles são 16 px em escala 2).
const PIXEL := 2.0

## Liga e desliga. A troca desliza por um instante em vez de estalar.
@export var acesa := true
## Ligado, a força vem do horário (e é zero sem Atmosfera na cena).
@export var segue_o_horario := false

@export_group("Luz")
@export var cor := Color(1.0, 0.6, 0.28):
	set(v):
		cor = v
		_aplicar()
## Força da poça de luz.
@export_range(0.0, 4.0, 0.01) var energia := 1.0:
	set(v):
		energia = v
		_aplicar()
## Raio da poça, em pixels do mundo.
@export_range(8.0, 900.0, 2.0) var raio := 180.0:
	set(v):
		raio = v
		_montar()
## Curva da queda: maior aperta a luz contra a fonte.
@export_range(0.3, 4.0, 0.05) var queda := 1.5:
	set(v):
		queda = v
		_montar()

@export_group("Pixel art")
@export_range(2, 16, 1) var degraus := 6:
	set(v):
		degraus = v
		_montar()
@export_range(0.0, 1.0, 0.01) var pontilhado := 0.5:
	set(v):
		pontilhado = v
		_montar()

@export_group("Ar")
## Força do clarão somado no ar em volta da fonte.
@export_range(0.0, 1.0, 0.01) var clarao := 0.35:
	set(v):
		clarao = v
		_aplicar()
## Tamanho do clarão, como fração do raio da poça.
@export_range(0.05, 1.0, 0.01) var tamanho_do_clarao := 0.4:
	set(v):
		tamanho_do_clarao = v
		_montar()

@export_group("Vida")
## Quanto a luz treme (fogo: 0,15 a 0,25; lâmpada: perto de 0).
@export_range(0.0, 0.5, 0.005) var tremor := 0.0
## Piscadas por segundo, para farol e alarme (0 = luz firme).
@export_range(0.0, 10.0, 0.05) var piscar := 0.0
## Fração de cada ciclo em que o farol fica aceso.
@export_range(0.05, 1.0, 0.01) var fatia_acesa := 0.35

## Força pedida pelo horário, de 0 a 1. Quem escreve é a Atmosfera (só quando
## segue_o_horario está ligado).
var intensidade := 1.0:
	set(v):
		intensidade = clampf(v, 0.0, 1.0)
		_aplicar()

var _poca: PointLight2D
var _clarao: Sprite2D
var _material_do_ar: CanvasItemMaterial
var _nivel := 0.0
var _tremida := 1.0
var _alvo_da_tremida := 1.0
var _ate_a_proxima := 0.0
var _relogio := 0.0


func _enter_tree() -> void:
	if segue_o_horario:
		add_to_group(GRUPO)


func _ready() -> void:
	_material_do_ar = CanvasItemMaterial.new()
	_material_do_ar.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_material_do_ar.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	_clarao = Sprite2D.new()
	_clarao.name = "Clarao"
	_clarao.material = _material_do_ar
	_clarao.scale = Vector2(PIXEL, PIXEL)
	_clarao.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_clarao.set_meta(&"_edit_lock_", true)
	add_child(_clarao, false, Node.INTERNAL_MODE_BACK)

	_poca = PointLight2D.new()
	_poca.name = "Poca"
	_poca.blend_mode = Light2D.BLEND_MODE_ADD
	_poca.texture_scale = PIXEL
	_poca.set_meta(&"_edit_lock_", true)
	add_child(_poca, false, Node.INTERNAL_MODE_BACK)

	if segue_o_horario:
		# Sem Atmosfera na cena não há escuro para ela acender.
		var regente := get_tree().get_first_node_in_group(&"atmosfera")
		intensidade = regente.nivel_dos_postes() \
			if regente != null and regente.has_method(&"nivel_dos_postes") else 0.0
	_nivel = 1.0 if acesa else 0.0
	_montar()


func _process(delta: float) -> void:
	_relogio += delta
	# Acender e apagar deslizam: um fogo não liga como interruptor.
	_nivel = move_toward(_nivel, 1.0 if acesa else 0.0, delta * 4.0)
	if tremor > 0.0:
		_ate_a_proxima -= delta
		if _ate_a_proxima <= 0.0:
			_ate_a_proxima = randf_range(0.05, 0.13)
			_alvo_da_tremida = 1.0 + randf_range(-tremor, tremor)
		_tremida = lerpf(_tremida, _alvo_da_tremida, minf(1.0, delta * 16.0))
	else:
		_tremida = 1.0
	_aplicar()


func _montar() -> void:
	if _poca == null:
		return
	var poca := TexturaDeLuz.ponto(maxi(int(round(raio / PIXEL)), 4), degraus, pontilhado, queda)
	_poca.texture = poca["textura"]
	var brilho := TexturaDeLuz.ponto(
		maxi(int(round(raio * tamanho_do_clarao / PIXEL)), 3), maxi(degraus - 2, 2), pontilhado, 1.2)
	_clarao.texture = brilho["textura"]
	_aplicar()


func _aplicar() -> void:
	if _poca == null:
		return
	var nivel := _nivel * _tremida
	if segue_o_horario:
		nivel *= intensidade
	if piscar > 0.0 and fposmod(_relogio * piscar, 1.0) > fatia_acesa:
		nivel = 0.0
	_poca.color = cor
	_poca.energy = energia * nivel
	_poca.enabled = energia > 0.0 and nivel > 0.01
	_clarao.modulate = Color(cor.r, cor.g, cor.b, clampf(clarao * nivel, 0.0, 1.0))
	_clarao.visible = clarao > 0.0 and nivel > 0.01
