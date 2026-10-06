class_name BrilhoDeCura
extends Node2D

# --- BRILHO DE CURA (A VIDA VOLTOU) ---
#
# O que acontece EM CIMA DA CACAU quando ela recupera vida (hoje, a cesta de
# maçãs): ela acende no verde da barra de vida e solta brilhinhos que sobem em
# volta do corpo. É o par do clarão que o HUD dá no mesmo instante — a barra
# diz QUANTO voltou, a personagem diz que foi NELA.
#
# O efeito é 100% de runtime — não tem cena, não tem PNG novo, não precisa de
# nada montado no editor. Ele mora dentro do player, logo depois do sprite, e
# anda, vira e pula junto com ela.
#
# --- AS DUAS CAMADAS ---
#
#   1. CLARÃO      uma cópia do quadro que ela está mostrando, pintada só na
#                  silhueta (shaders/brilho_de_cura.gdshader): o corpo inteiro
#                  acende e apaga rápido, e fica um fio de luz em volta dela
#                  por mais um instante.
#   2. BRILHINHOS  estrelinhas de pixel que estalam em volta do corpo, dos pés
#                  para a cabeça, sobem um pouco e somem. São desenhadas na
#                  grade de pixels da arte dela (nada de partícula borrada),
#                  com uma beirada escura que as recorta em fundo claro.
#
# Os dois têm luz própria: não escurecem no blecaute nem pegam o tom do céu.
#
# --- COMO USAR ---
#
#   BrilhoDeCura.tocar(sprite_da_personagem)
#
# Quem chama é o player, quando a vida entra de verdade (ver "curar" em
# scripts/player.gd). O efeito se desfaz sozinho quando termina.
#
# --- PARA REGULAR ---
#
# BRILHINHOS (quantos são), CORPO_FORCA (o quanto ela some atrás do verde no
# primeiro instante) e CONTORNO_DURACAO (por quanto tempo o fio de luz fica).

const SHADER := preload("res://shaders/brilho_de_cura.gdshader")

## O verde é o do acento da barra de vida: a personagem e o HUD acendem juntos,
## na mesma cor.
const COR := HudVital.ACENTO_PERSONAGEM
## O miolo das estrelinhas, quase branco.
const COR_MIOLO := Color(0.92, 1.0, 0.95)
## A beirada escura de 1 pixel em volta de cada estrelinha. Num fundo escuro
## ela nem aparece; num fundo claro (céu, parede branca) é ela que recorta o
## brilho, que sozinho sumiria ali.
const COR_BEIRADA := Color(0.03, 0.26, 0.2)
const BEIRADA_ALFA := 0.55


# --- CLARÃO ---

## Quanto do desenho o verde cobre no primeiro instante (1 = silhueta chapada)
## e em quanto tempo ele some.
const CORPO_FORCA := 0.7
const CORPO_DURACAO := 0.3
## O fio de luz em volta dela: fica inteiro até CONTORNO_FIRME e termina de
## apagar em CONTORNO_DURACAO.
const CONTORNO_FIRME := 0.25
const CONTORNO_DURACAO := 0.75


# --- BRILHINHOS ---

const BRILHINHOS := 12
## Os tamanhos se revezam nesta ordem — o número é o comprimento do braço da
## estrelinha, em pixels de arte.
const TAMANHOS: Array[int] = [3, 1, 2, 1, 2, 1]
## O último brilhinho nasce até este instante: é a onda subindo pelo corpo.
const NASCEM_ATE := 0.4
const VIDA_MIN := 0.45
const VIDA_MAX := 0.7
## Quanto cada um sobe ao longo da vida, em pixels de arte.
const SUBIDA_MIN := 10.0
const SUBIDA_MAX := 22.0
## Folga para os lados do desenho, para eles nascerem EM VOLTA dela e não só
## em cima do jaleco.
const FOLGA_LATERAL := 5.0
## A partir desta fração da vida o brilhinho começa a ficar transparente.
const APAGA_A_PARTIR_DE := 0.7

## Preenchido pelo "tocar()" antes do nó entrar na árvore.
var _sprite: AnimatedSprite2D = null

var _clarao: Sprite2D = null
var _material: ShaderMaterial = null
var _brilhinhos: Array[Dictionary] = []
var _tempo: float = 0.0
var _fim: float = CONTORNO_DURACAO


# --- ENTRADA ---

## Acende o brilho de cura em cima de `sprite`. O efeito vira irmão dele (filho
## da personagem), logo depois na árvore: desenha por cima do sprite e segue
## junto com ela.
static func tocar(sprite: AnimatedSprite2D) -> BrilhoDeCura:
	if sprite == null or sprite.get_parent() == null:
		return null

	var fx := BrilhoDeCura.new()
	fx.name = "BrilhoDeCura"
	fx._sprite = sprite
	sprite.add_sibling(fx)
	return fx


func _ready() -> void:
	var luz_propria := CanvasItemMaterial.new()
	luz_propria.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = luz_propria

	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("cor", COR)
	_clarao = Sprite2D.new()
	_clarao.material = _material
	# Os brilhinhos são o _draw deste nó, e um filho desenha por cima do pai:
	# sem isto o clarão cobriria as estrelinhas.
	_clarao.show_behind_parent = true
	add_child(_clarao)

	_acompanhar()
	_semear_brilhinhos(_ler_corpo())
	_acender()


func _process(delta: float) -> void:
	_tempo += delta
	if _tempo >= _fim or not is_instance_valid(_sprite):
		queue_free()
		return
	_acompanhar()
	_acender()
	queue_redraw()


# --- O CLARÃO ---

## Cola o efeito no sprite: mesma posição e escala (o dash estica o sprite),
## mesmo quadro, mesmo lado. Se ela some (a morte despedaçada esconde o
## sprite), o brilho some junto.
func _acompanhar() -> void:
	transform = _sprite.transform
	visible = _sprite.visible
	_clarao.texture = _quadro_atual()
	_clarao.centered = _sprite.centered
	_clarao.offset = _sprite.offset
	_clarao.flip_h = _sprite.flip_h
	_clarao.flip_v = _sprite.flip_v


func _acender() -> void:
	# O corpo apaga rápido no começo e devagar no fim; o fio em volta segura um
	# instante antes de ir embora.
	var corpo := 1.0 - clampf(_tempo / CORPO_DURACAO, 0.0, 1.0)
	_material.set_shader_parameter("corpo", CORPO_FORCA * corpo * corpo)
	_material.set_shader_parameter("contorno",
		1.0 - smoothstep(CONTORNO_FIRME, CONTORNO_DURACAO, _tempo))


func _quadro_atual() -> Texture2D:
	var quadros: SpriteFrames = _sprite.sprite_frames
	if quadros == null or not quadros.has_animation(_sprite.animation):
		return null
	var total: int = quadros.get_frame_count(_sprite.animation)
	if total <= 0:
		return null
	return quadros.get_frame_texture(_sprite.animation, clampi(_sprite.frame, 0, total - 1))


# --- OS BRILHINHOS ---

## Onde está o DESENHO dentro do quadro, nas coordenadas do sprite (pixels de
## arte, medidos do ponto em que o nó desenha). O quadro tem uma moldura
## transparente larga em volta da personagem: sem este recorte os brilhinhos
## nasceriam espalhados no vazio.
func _ler_corpo() -> Rect2:
	var textura := _quadro_atual()
	if textura == null:
		return Rect2(-12.0, -24.0, 24.0, 48.0)

	var tamanho := textura.get_size()
	var canto := _sprite.offset - (tamanho * 0.5 if _sprite.centered else Vector2.ZERO)
	# Sem a imagem em CPU, vale o miolo do quadro.
	var corpo := Rect2(canto + tamanho * 0.25, tamanho * 0.5)

	var imagem: Image = textura.get_image()
	if imagem and imagem.is_compressed() and imagem.decompress() != OK:
		imagem = null
	if imagem:
		var usados := imagem.get_used_rect()
		if usados.has_area():
			var inicio := Vector2(usados.position)
			if _sprite.flip_h:
				inicio.x = tamanho.x - usados.end.x
			if _sprite.flip_v:
				inicio.y = tamanho.y - usados.end.y
			corpo = Rect2(canto + inicio, usados.size)
	return corpo


## Sorteia os brilhinhos de uma vez. Eles sobem em ONDA: o primeiro nasce nos
## pés, o último na cabeça, alternando os lados do corpo.
func _semear_brilhinhos(corpo: Rect2) -> void:
	var meio := corpo.get_center().x
	var meia_largura := corpo.size.x * 0.5 + FOLGA_LATERAL
	for i in BRILHINHOS:
		var altura := (i + randf()) / BRILHINHOS
		var lado := -1.0 if i % 2 == 0 else 1.0
		var nasce := altura * NASCEM_ATE
		var vida := randf_range(VIDA_MIN, VIDA_MAX)
		_brilhinhos.append({
			"pos": Vector2(
				meio + lado * randf_range(0.3, 1.0) * meia_largura,
				lerpf(corpo.end.y - 3.0, corpo.position.y + 3.0, altura)),
			"nasce": nasce,
			"vida": vida,
			"subida": randf_range(SUBIDA_MIN, SUBIDA_MAX),
			"tamanho": TAMANHOS[i % TAMANHOS.size()],
		})
		_fim = maxf(_fim, nasce + vida)


func _draw() -> void:
	# Duas passadas, todas as beiradas antes: assim a beirada de uma estrelinha
	# nunca escurece a vizinha.
	for beirada: bool in [true, false]:
		for b in _brilhinhos:
			var idade: float = _tempo - b["nasce"]
			if idade < 0.0 or idade >= b["vida"]:
				continue
			var k: float = idade / b["vida"]

			# Estala e encolhe: o braço abre rápido, segura e fecha até virar
			# ponto.
			var braco: int = roundi(b["tamanho"] * pow(sin(k * PI), 0.6))
			# Sobe freando.
			var subiu: float = b["subida"] * (1.0 - (1.0 - k) * (1.0 - k))
			var alfa: float = 1.0 - smoothstep(APAGA_A_PARTIR_DE, 1.0, k)
			# floor(): cada estrelinha cai inteira na grade de pixels da arte.
			var p: Vector2 = (b["pos"] - Vector2(0.0, subiu)).floor()
			if beirada:
				_desenhar_beirada(p, braco, alfa)
			else:
				_desenhar_brilhinho(p, braco, alfa)


## A beirada escura: a mesma cruz da estrelinha, 1 pixel mais gorda para todos
## os lados. A barra de pé vai em duas metades para não passar duas vezes pelo
## miolo (onde a transparência somaria e ficaria mais escuro).
func _desenhar_beirada(p: Vector2, braco: int, alfa: float) -> void:
	var escuro := Color(COR_BEIRADA, alfa * BEIRADA_ALFA)
	draw_rect(Rect2(p.x - braco - 1, p.y - 1, braco * 2 + 3, 3), escuro)
	if braco > 0:
		draw_rect(Rect2(p.x - 1, p.y - braco - 1, 3, braco), escuro)
		draw_rect(Rect2(p.x - 1, p.y + 2, 3, braco), escuro)


## Uma estrelinha de quatro pontas com o pixel `p` no meio: os braços no verde
## e o miolo claro. Com braço 0 ela é só um ponto.
func _desenhar_brilhinho(p: Vector2, braco: int, alfa: float) -> void:
	var verde := Color(COR, alfa)
	if braco <= 0:
		draw_rect(Rect2(p, Vector2.ONE), verde)
		return

	draw_rect(Rect2(p.x - braco, p.y, braco * 2 + 1, 1), verde)
	draw_rect(Rect2(p.x, p.y - braco, 1, braco * 2 + 1), verde)
	if braco >= 3:
		# A maior ganha corpo: as diagonais do miolo também acendem.
		draw_rect(Rect2(p.x - 1, p.y - 1, 3, 3), verde)

	var miolo := braco - 1
	var claro := Color(COR_MIOLO, alfa)
	draw_rect(Rect2(p.x - miolo, p.y, miolo * 2 + 1, 1), claro)
	draw_rect(Rect2(p.x, p.y - miolo, 1, miolo * 2 + 1), claro)
