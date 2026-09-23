class_name PainelChonps
extends Node2D

# --- PAINEL DO CHONPS ---
#
# O centro visual do hub: a tela do painel com o título "PAINEL" e as seis
# letras do CHONPS, uma por elemento da vida, acesas conforme o Progresso
# entrega as células.
#
# COMO EDITAR NO EDITOR:
#   Tela    -> a tela animada (assets/Lab2/Painel Principal.png, 6 quadros na
#              vertical). A velocidade da varredura fica no SpriteFrames dela.
#   Titulo  -> o "PAINEL", em BoldPixels 44 com o Label em escala 0.5 (o
#              espaçamento entre as letras é o spacing_glyph da fonte dele).
#   Letras  -> um Sprite2D por elemento, recortando a folha
#              assets/Lab2/letras do painel principal CHONPS.png: 12 quadros
#              na horizontal, cada letra acesa e depois apagada (C aceso,
#              C apagado, H aceso, ...). O quadro que está na cena é só a
#              prévia do editor: no jogo quem decide é o Progresso.
#
# O nó do painel fica no centro do corpo da tela (a sombra da esquerda não
# conta), então as letras ficam simétricas em volta da origem.

const CENA := "res://scenes/fases/componentes/painel_chonps.tscn"

## Quadros da animação da Tela em que a arte pisca mais escura. Título e
## letras escurecem junto, para parecer tudo a mesma tela.
@export var quadros_escuros: PackedInt32Array = [1, 4]
## Quanto título e letras escurecem nesses quadros (a arte cai uns 10%).
@export_range(0.0, 1.0) var brilho_nos_quadros_escuros: float = 0.9

var _letras: Dictionary = {}
var _piscando: Dictionary = {}

@onready var _tela: AnimatedSprite2D = $Tela
@onready var _titulo: CanvasItem = $Titulo
@onready var _grupo_letras: CanvasItem = $Letras


static func criar(pai: Node, pos: Vector2) -> PainelChonps:
	var painel: PainelChonps = load(CENA).instantiate()
	painel.name = "PainelChonps"
	painel.position = pos
	Blockout.adicionar(pai, painel)
	return painel


func _ready() -> void:
	for letra in Progresso.CELULAS:
		var sprite := get_node_or_null("Letras/" + letra) as Sprite2D
		if sprite:
			_letras[letra] = sprite

	_tela.frame_changed.connect(_acompanhar_brilho_da_tela)
	_tela.play()

	_atualizar()
	Progresso.celula_entregue.connect(_on_celula_entregue)


func _atualizar() -> void:
	for letra in _letras:
		if not _piscando.has(letra):
			_acender(letra, Progresso.tem_celula(letra))


## Na folha, cada letra ocupa dois quadros seguidos: aceso e apagado.
func _acender(letra: String, aceso: bool) -> void:
	var sprite: Sprite2D = _letras.get(letra)
	if sprite:
		sprite.frame = Progresso.CELULAS.find(letra) * 2 + (0 if aceso else 1)


# A letra nova liga como lâmpada velha: falha umas vezes antes de firmar.
func _on_celula_entregue(letra: String) -> void:
	if not _letras.has(letra):
		return
	var anterior: Tween = _piscando.get(letra)
	if anterior:
		anterior.kill()

	var tween := create_tween()
	_piscando[letra] = tween
	for intervalo in [0.08, 0.14, 0.06, 0.2, 0.1]:
		tween.tween_callback(_acender.bind(letra, true))
		tween.tween_interval(intervalo)
		tween.tween_callback(_acender.bind(letra, false))
		tween.tween_interval(intervalo)
	tween.tween_callback(_acender.bind(letra, true))
	tween.finished.connect(func() -> void:
		_piscando.erase(letra)
		_atualizar())


func _acompanhar_brilho_da_tela() -> void:
	var brilho := brilho_nos_quadros_escuros if _tela.frame in quadros_escuros else 1.0
	var cor := Color(brilho, brilho, brilho)
	_titulo.modulate = cor
	_grupo_letras.modulate = cor
