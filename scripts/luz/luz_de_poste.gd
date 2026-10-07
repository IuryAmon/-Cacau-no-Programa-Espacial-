@tool
class_name LuzDePoste
extends Node2D
## A luz de uma lâmpada de rua: o tubo aceso, o clarão em volta dele, o feixe
## descendo no ar e a poça de luz no que estiver embaixo.
##
## O ponto do nó é o CENTRO DO TUBO da lâmpada. Quem pinta poste no TileMap não
## precisa pôr isto na mão — o [PostesDeLuz] da cena acha os postes pintados e
## põe uma destas em cada um. Para acender outra coisa (uma luminária de
## parede, um holofote), instancie `scenes/luz/luz_de_poste.tscn` em cima dela.
##
## São quatro peças, e cada uma faz uma coisa que as outras não fazem:
##
## [codeblock]
## tubo      o risco claro da lâmpada. Não recebe sombra: é ele que emite.
## clarão    o brilho da lâmpada no ar, somado por cima do que está atrás.
## feixe     o cone de luz descendo, bem fraco — é o que se vê contra o céu.
## poça      uma PointLight2D: ilumina de verdade o chão, o poste e quem passa.
## [/codeblock]
##
## As três de luz usam texturas em degraus e pontilhado ([TexturaDeLuz]), com o
## pixel do tamanho do pixel do cenário.
##
## A [Atmosfera] regula a força pela hora ([member intensidade]): fraca ao
## entardecer, com tudo à noite.

const GRUPO := &"luz_artificial"
## Tamanho do pixel de arte no mundo (os tiles são 16 px em escala 2).
const PIXEL := 2.0

@export_group("Luz")
@export var cor := Color(1.0, 0.8, 0.5):
	set(v):
		cor = v
		_aplicar()
## Força da poça de luz no auge (à noite).
@export_range(0.0, 4.0, 0.01) var energia := 1.0:
	set(v):
		energia = v
		_aplicar()
## Largura do tubo, em pixels do mundo.
@export_range(8.0, 400.0, 2.0) var largura := 92.0:
	set(v):
		largura = v
		_montar()
## Até onde a luz desce, em pixels do mundo.
@export_range(40.0, 900.0, 2.0) var alcance := 400.0:
	set(v):
		alcance = v
		_montar()
## Abertura do cone (0 = quase reto para baixo, 1 = bem aberto).
@export_range(0.0, 1.0, 0.01) var abertura := 0.5:
	set(v):
		abertura = v
		_montar()

@export_group("Pixel art")
## Em quantos degraus a luz cai.
@export_range(2, 16, 1) var degraus := 6:
	set(v):
		degraus = v
		_montar()
## Quanto de cada degrau é pontilhado na emenda.
@export_range(0.0, 1.0, 0.01) var pontilhado := 0.5:
	set(v):
		pontilhado = v
		_montar()

@export_group("Ar")
## Força do clarão em volta da lâmpada.
@export_range(0.0, 1.0, 0.01) var clarao := 0.5:
	set(v):
		clarao = v
		_aplicar()
## Força do feixe visível no ar.
@export_range(0.0, 1.0, 0.01) var feixe := 0.12:
	set(v):
		feixe = v
		_aplicar()

@export_group("Vida")
## Quanto a luz treme (0 = parada).
@export_range(0.0, 0.3, 0.005) var tremor := 0.025
## Mariposas rodando a lâmpada quando ela está com tudo.
@export_range(0, 8, 1) var mariposas := 3:
	set(v):
		mariposas = v
		_sortear_mariposas()

## Força pedida pelo horário, de 0 (apagada) a 1. Quem escreve é a Atmosfera.
var intensidade := 1.0:
	set(v):
		intensidade = clampf(v, 0.0, 1.0)
		_aplicar()

var _poca: PointLight2D
var _clarao: Sprite2D
var _feixe: Sprite2D
var _material_do_ar: CanvasItemMaterial
var _material_do_tubo: CanvasItemMaterial
## Chave de liga/desliga da piscada ao acender, de 0 a 1.
var _chave := 1.0
var _tremida := 1.0
var _alvo_da_tremida := 1.0
var _ate_a_proxima := 0.0
var _relogio := 0.0
var _bichos: Array[Dictionary] = []
var _piscada := 0


func _enter_tree() -> void:
	add_to_group(GRUPO)


func _ready() -> void:
	_material_do_ar = CanvasItemMaterial.new()
	_material_do_ar.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_material_do_ar.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_material_do_tubo = CanvasItemMaterial.new()
	_material_do_tubo.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	# O tubo e as mariposas são desenhados por este nó; o material vai direto
	# para o render, para não virar propriedade salva na cena.
	RenderingServer.canvas_item_set_material(get_canvas_item(), _material_do_tubo.get_rid())

	_feixe = _novo_sprite("Feixe")
	_clarao = _novo_sprite("Clarao")
	_poca = PointLight2D.new()
	_poca.name = "Poca"
	_poca.blend_mode = Light2D.BLEND_MODE_ADD
	_poca.texture_scale = PIXEL
	_poca.set_meta(&"_edit_lock_", true)
	add_child(_poca, false, Node.INTERNAL_MODE_BACK)

	_sortear_mariposas()
	_montar()

	# Nasceu depois de a Atmosfera já ter distribuído o horário (os postes são
	# achados um quadro depois da cena abrir): pergunta a ela.
	var regente := get_tree().get_first_node_in_group(&"atmosfera")
	if regente != null and regente.has_method(&"nivel_dos_postes"):
		intensidade = regente.nivel_dos_postes()


func _process(delta: float) -> void:
	_relogio += delta
	if tremor > 0.0:
		# A tremida troca de alvo algumas vezes por segundo e desliza até ele:
		# sorteada todo quadro, a luz vira estrobo.
		_ate_a_proxima -= delta
		if _ate_a_proxima <= 0.0:
			_ate_a_proxima = randf_range(0.07, 0.16)
			_alvo_da_tremida = 1.0 + randf_range(-tremor, tremor)
		_tremida = lerpf(_tremida, _alvo_da_tremida, minf(1.0, delta * 14.0))
		_aplicar()
	if not _bichos.is_empty():
		queue_redraw()


func _draw() -> void:
	var nivel := _nivel()
	if nivel <= 0.01:
		return
	# O tubo: uma linha de pixel de arte, mais clara que a cor da luz.
	var claro := cor.lerp(Color.WHITE, 0.72)
	claro.a = clampf(nivel * 1.6, 0.0, 1.0)
	draw_rect(Rect2(-largura * 0.5, -PIXEL * 0.5, largura, PIXEL), claro)

	# Mariposas: só com a lâmpada forte, que é quando elas vêm.
	var chamada := clampf((nivel - 0.55) / 0.3, 0.0, 1.0)
	if chamada <= 0.0:
		return
	for bicho in _bichos:
		var t: float = _relogio * bicho["ritmo"] + bicho["fase"]
		var p := Vector2(
			cos(t) * bicho["raio"] + sin(t * 2.7 + bicho["fase"]) * 5.0,
			sin(t * 1.3) * bicho["raio"] * 0.45 + bicho["altura"])
		p = (p / PIXEL).round() * PIXEL
		# Bate asa: some por um quadro de vez em quando.
		if fmod(t * 3.1, 1.0) < 0.2:
			continue
		draw_rect(Rect2(p, Vector2(PIXEL, PIXEL)), Color(1.0, 0.96, 0.82, 0.85 * chamada))


## Acende piscando — o estalo de uma lâmpada de rua pegando. [param atraso] é
## quanto esperar antes da primeira piscada (para os postes não acenderem todos
## no mesmo quadro).
func acender_piscando(atraso: float = 0.0) -> void:
	_piscada += 1
	var esta := _piscada
	if atraso > 0.0:
		await get_tree().create_timer(atraso).timeout
	# Liga, falha, liga, falha, firma.
	for passo: Array in [[0.25, 0.05], [0.0, 0.09], [0.7, 0.06], [0.0, 0.05], [1.25, 0.08], [1.0, 0.0]]:
		if esta != _piscada or not is_inside_tree():
			return
		_chave = passo[0]
		_aplicar()
		if passo[1] > 0.0:
			await get_tree().create_timer(passo[1]).timeout


## Força que a lâmpada está entregando agora, já com a piscada.
func _nivel() -> float:
	return intensidade * _chave


func _novo_sprite(nome: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = nome
	s.material = _material_do_ar
	s.scale = Vector2(PIXEL, PIXEL)
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.set_meta(&"_edit_lock_", true)
	add_child(s, false, Node.INTERNAL_MODE_BACK)
	return s


func _montar() -> void:
	if _poca == null:
		return
	var tubo := maxi(int(round(largura / PIXEL)), 2)
	var fundo := maxi(int(round(alcance / PIXEL)), 8)

	var poca := TexturaDeLuz.cone(tubo, fundo, abertura, degraus, pontilhado)
	var textura: Texture2D = poca["textura"]
	var fonte: Vector2 = poca["fonte"]
	_poca.texture = textura
	# O "offset" da luz conta do centro da textura; a fonte fica no nó.
	_poca.offset = (textura.get_size() * 0.5 - fonte) * PIXEL

	# O feixe no ar é o mesmo cone com menos degraus: lê como luz atravessando
	# o ar, em faixas, e não como um plástico amarelo.
	var ar := TexturaDeLuz.cone(tubo, fundo, abertura, 4, 0.4)
	_feixe.texture = ar["textura"]
	_feixe.position = -(ar["fonte"] as Vector2) * PIXEL

	var brilho := TexturaDeLuz.halo(tubo, 22, 5, 0.35)
	_clarao.texture = brilho["textura"]
	_clarao.position = -(brilho["fonte"] as Vector2) * PIXEL

	_aplicar()


func _aplicar() -> void:
	if _poca == null:
		return
	var nivel := _nivel() * _tremida
	_poca.color = cor
	_poca.energy = energia * nivel
	_poca.enabled = nivel > 0.01
	_clarao.modulate = Color(cor.r, cor.g, cor.b, clampf(clarao * nivel, 0.0, 1.0))
	_clarao.visible = nivel > 0.01
	# O feixe só aparece de verdade com o céu escuro; de dia o ar já é claro.
	_feixe.modulate = Color(cor.r, cor.g, cor.b, clampf(feixe * nivel * nivel, 0.0, 1.0))
	_feixe.visible = nivel > 0.01
	queue_redraw()


func _sortear_mariposas() -> void:
	_bichos.clear()
	for i in mariposas:
		_bichos.append({
			"raio": randf_range(10.0, 30.0),
			"ritmo": randf_range(1.6, 3.4) * (1.0 if i % 2 == 0 else -1.0),
			"fase": randf() * TAU,
			"altura": randf_range(4.0, 22.0),
		})
	queue_redraw()
