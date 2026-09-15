@tool
class_name AlvoBumerangue
extends Area2D

# --- ALVO DE BUMERANGUE ---
#
# A escola do arremesso inteira usa este nó: alvos fixos, interruptores
# temporizados e o puzzle de ida e volta. O bumerangue chama
# atingir_bumerangue() ao passar.
#
# COMO EDITAR NO EDITOR:
#   Sprite        -> solte aqui o PNG do alvo desligado (o placeholder some)
#   SpriteAtivo   -> PNG opcional do alvo aceso; sem ele, o alvo só muda de cor
#   Rotulo        -> texto que aparece acima (deixe vazio para esconder)
#   permanece_ativo -> ligado para sempre (ventilador, alavanca) ou por "janela"

const CENA := "res://scenes/fases/componentes/alvo_bumerangue.tscn"

signal mudou(ativo: bool)

@export var permanece_ativo: bool = true
@export var janela: float = 3.5
@export var persistir: bool = false
@export var rotulo: String = "":
	set(valor):
		rotulo = valor
		if is_inside_tree():
			_atualizar_rotulo()

var ativo: bool = false
var _tempo_restante: float = 0.0

# Todos os slots visuais são OPCIONAIS: quem herda deste nó — a CaixaEletrica
# da Oficina, por exemplo — troca o par Sprite+Placeholder por arte própria e
# simplesmente não traz estes filhos. Por isso get_node_or_null() no lugar de $.
@onready var _sprite: Sprite2D = get_node_or_null("Sprite")
@onready var _sprite_ativo: Sprite2D = get_node_or_null("SpriteAtivo")
@onready var _placeholder: ColorRect = get_node_or_null("Placeholder")
@onready var _miolo: ColorRect = get_node_or_null("Placeholder/Miolo")
@onready var _label: Label = get_node_or_null("Rotulo")


static func criar(pai: Node, nome: String, pos: Vector2, config: Dictionary = {}) -> AlvoBumerangue:
	var alvo: AlvoBumerangue = load(CENA).instantiate()
	alvo.name = nome
	alvo.position = pos
	for chave in config:
		alvo.set(chave, config[chave])
	Blockout.adicionar(pai, alvo)
	return alvo


func _ready() -> void:
	_atualizar_rotulo()
	if Engine.is_editor_hint():
		Blockout.aplicar_arte(_sprite, _placeholder)
		return

	add_to_group("alvo_bumerangue")
	if persistir and EstadoMundo.ja_feito(self):
		ativo = true
	_atualizar_visual()


func _atualizar_rotulo() -> void:
	if _label:
		_label.text = rotulo
		_label.visible = rotulo != ""


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if ativo and not permanece_ativo:
		_tempo_restante -= delta
		if _tempo_restante <= 0.0:
			ativo = false
			_atualizar_visual()
			mudou.emit(false)


func atingir_bumerangue() -> void:
	if ativo and permanece_ativo:
		return
	ativo = true
	_tempo_restante = janela
	if persistir:
		EstadoMundo.marcar_feito(self)
	_atualizar_visual()
	mudou.emit(true)


func _atualizar_visual() -> void:
	# Pode ser chamado antes do _ready() (um alvo atingido no mesmo frame em
	# que a cena nasce), quando os @onready ainda estão nulos.
	if _sprite == null or _sprite_ativo == null:
		return
	Blockout.aplicar_arte(_sprite, _placeholder)
	# Com arte: troca para o sprite aceso, se houver. Sem arte: muda a cor do
	# miolo do placeholder.
	if _sprite.texture and _sprite_ativo.texture:
		_sprite.visible = not ativo
		_sprite_ativo.visible = ativo
	else:
		_sprite_ativo.visible = false
		if _sprite.texture:
			_sprite.modulate = Color(0.6, 1.3, 0.7) if ativo else Color.WHITE
	if _miolo:
		_miolo.color = Color(0.35, 0.9, 0.45) if ativo else Color(0.85, 0.3, 0.3)
