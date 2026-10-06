@tool
class_name NotaCaderno
extends Area2D

# --- NOTA DO CADERNO (uma folha solta pelo mapa) ---
#
# O caderno da Cacau não vem inteiro: ele começa só até a página 3, e as outras
# páginas estão espalhadas pelo mapa. Cada uma é uma cena destas. Chegando
# perto, o desenho do botão acende em cima da folha — a tecla E, ou o □ de
# controle (componentes/icone_interagir.tscn, o mesmo da cesta de maçãs).
# Apertando, a folha sai do chão, voa até o ícone do caderno, no canto da tela,
# e o aviso "NOTA ADICIONADA" diz qual foi e em que páginas ela está. Quem faz
# o voo, o som e o aviso é o autoload Caderno (Caderno.guardar_nota).
#
# É UMA VEZ SÓ. Quem lembra das notas achadas é o próprio caderno
# (PaginasCaderno), e não o lugar em que a folha estava: morrer, trocar de
# cena ou mudar a nota de lugar no editor não a traz de volta.
#
# A folha balança devagar e solta uns brilhos, para ser vista de longe. Ela
# desenha em z_index 1: atrás da Cacau (z_index 2) e na frente do chão.
#
# COMO EDITAR NO EDITOR:
#   posição do nó -> no CHÃO, embaixo da folha: ela flutua um pouco acima dele
#   nota          -> quais páginas do caderno esta folha devolve (a lista sai
#                    das NOTAS, em scripts/paginas_caderno.gd)
#   flutuar       -> desligue para a folha ficar parada (em cima de uma mesa)
#   Sprite        -> a arte da folha (assets/itens/notas diario.png)
#   Dica          -> o botão E/□ em cima da folha
#   Colisao       -> a área em que dá para pegar (maior que a folha, para não
#                    precisar parar exatamente em cima dela)

const CENA := "res://scenes/fases/componentes/nota_caderno.tscn"

## Quanto a folha sobe e desce (px) e quantas vezes por segundo.
const ALTURA_DO_BALANCO := 6.0
const BALANCOS_POR_SEGUNDO := 0.38

## Os brilhos em volta da folha: quantos, de quanto em quanto tempo cada um
## acende, quanto desse tempo ele fica aceso, e o tamanho do pixel deles (o da
## arte, que vai ampliada 2×).
const BRILHOS := 3
const CICLO_DO_BRILHO := 1.5
const BRILHO_ACESO := 0.42
const PIXEL_DO_BRILHO := 2.0
const COR_DO_BRILHO := Color(1.0, 0.97, 0.82)
## Quanto os brilhos passam da beira da folha.
const FOLGA_DO_BRILHO := 8.0

## Qual nota do caderno esta folha é (ver PaginasCaderno.NOTAS).
@export var nota: String = "atomo":
	set(valor):
		nota = valor
		update_configuration_warnings()
## Balanço suave para chamar o olho. Desligue para a folha ficar parada.
@export var flutuar: bool = true

## Emitido quando a Cacau pega a folha.
signal pega(nota: String)

var _jogador: Node2D = null
var _pega: bool = false
# Estado do botão, para o ícone só ser religado na virada.
var _dica_visivel: bool = false
var _tempo: float = 0.0
var _lugar_da_arte: Vector2 = Vector2.ZERO

@onready var _sprite: Sprite2D = $Sprite
## O desenho do botão que acende quando ela chega perto (ver IconeInteragir).
@onready var _dica: AnimatedSprite2D = get_node_or_null("Dica")


func _ready() -> void:
	_lugar_da_arte = _sprite.position
	if _dica:
		_dica.visible = false
	if Engine.is_editor_hint():
		return

	if not PaginasCaderno.NOTAS.has(nota):
		push_warning("NotaCaderno '%s': a nota \"%s\" não existe em PaginasCaderno.NOTAS" % [name, nota])
	if Caderno.tem_nota(nota):
		queue_free()
		return

	# Cada folha balança no seu tempo: duas na mesma tela não sobem juntas.
	_tempo = fposmod(global_position.x * 0.013, 1.0) / BALANCOS_POR_SEGUNDO
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## No inspetor, a nota é escolhida numa lista com as que existem.
func _validate_property(propriedade: Dictionary) -> void:
	if propriedade.name == "nota":
		propriedade.hint = PROPERTY_HINT_ENUM
		propriedade.hint_string = ",".join(PaginasCaderno.NOTAS.keys())


func _get_configuration_warnings() -> PackedStringArray:
	if PaginasCaderno.NOTAS.has(nota):
		return PackedStringArray()
	return PackedStringArray(["A nota \"%s\" não existe em PaginasCaderno.NOTAS." % nota])


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _pega:
		return

	_tempo += delta
	if flutuar:
		# No pixel inteiro: balanço quebrado borra a pixel art.
		var subida := (sin(_tempo * BALANCOS_POR_SEGUNDO * TAU) * 0.5 + 0.5) * ALTURA_DO_BALANCO
		_sprite.position = _lugar_da_arte - Vector2(0.0, roundf(subida))
	queue_redraw()

	var perto := _jogador != null
	if perto != _dica_visivel:
		_dica_visivel = perto
		_atualizar_dica()

	# pediu() por último: ele queima o toque, e só pode queimar quando a folha
	# vai mesmo ser pega.
	if perto and Interacao.pediu():
		pegar()


## A Cacau pega a folha: ela vai para o caderno e some do mapa.
func pegar() -> void:
	if _pega:
		return
	_pega = true
	_dica_visivel = false
	_atualizar_dica()
	set_deferred("monitoring", false)

	# De onde a folha sai e de que tamanho, na tela: o voo começa em cima dela.
	var na_tela := _sprite.get_global_transform_with_canvas()
	var arte := _sprite.get_rect()
	Caderno.guardar_nota(nota, na_tela * arte.get_center(),
		maxf(arte.size.x, arte.size.y) * na_tela.get_scale().y)
	pega.emit(nota)
	queue_free()


## Onde a arte está agora, no espaço do nó (com o balanço).
func caixa_da_arte() -> Rect2:
	var arte := _sprite.get_rect()
	return Rect2(_sprite.position + arte.position * _sprite.scale, arte.size * _sprite.scale)


## Os brilhos: cruzinhas de pixel que acendem e apagam em volta da folha, cada
## uma num canto diferente a cada vez. (O Sprite tem "show_behind_parent": é
## assim que eles saem por cima da folha.)
func _draw() -> void:
	if Engine.is_editor_hint() or _pega or _sprite == null:
		return
	var area := caixa_da_arte().grow(FOLGA_DO_BRILHO)
	for i in BRILHOS:
		var fase := _tempo / CICLO_DO_BRILHO + float(i) / BRILHOS
		var vez := floorf(fase)
		var p := (fase - vez) / BRILHO_ACESO
		if p >= 1.0:
			continue
		var forca := sin(p * PI)
		var centro := (area.position + area.size * Vector2(_sorteio(vez, i), _sorteio(vez + 0.5, i))) \
			.snappedf(PIXEL_DO_BRILHO)
		var cor := Color(COR_DO_BRILHO, forca)
		var px := Vector2.ONE * PIXEL_DO_BRILHO
		draw_rect(Rect2(centro, px), cor)
		# Os braços da cruz só no auge do brilho.
		if forca > 0.6:
			var fraca := Color(COR_DO_BRILHO, forca * 0.7)
			for braco in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_rect(Rect2(centro + braco * PIXEL_DO_BRILHO, px), fraca)


## Um número de 0 a 1 que é sempre o mesmo para a mesma vez do mesmo brilho.
func _sorteio(vez: float, i: int) -> float:
	return fposmod(sin(vez * 12.9898 + i * 78.233) * 43758.5453, 1.0)


## O botão só é prometido quando ela está por perto.
func _atualizar_dica() -> void:
	if _dica == null:
		return
	_dica.visible = _dica_visivel
	if _dica_visivel and _dica.has_method("reiniciar"):
		_dica.reiniciar()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_jogador = body


func _on_body_exited(body: Node2D) -> void:
	if body == _jogador:
		_jogador = null
