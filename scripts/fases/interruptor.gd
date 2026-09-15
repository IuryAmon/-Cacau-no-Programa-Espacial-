@tool
class_name Interruptor
extends Area2D

# --- INTERRUPTOR DE PAREDE (tecla E) ---
#
# O botão genérico das fases: religa setores no subsolo, liga a sala de
# disjuntores, abre comportas.
#
# COMO EDITAR NO EDITOR:
#   Sprite / SpriteAtivo -> PNGs do botão desligado e ligado
#   Rotulo               -> texto acima do botão
#   uma_vez              -> depois de acionado, não responde mais

const CENA := "res://scenes/fases/componentes/interruptor.tscn"

signal acionado

@export var rotulo: String = "":
	set(valor):
		rotulo = valor
		if is_inside_tree():
			_atualizar_rotulo()
@export var uma_vez: bool = true
@export var persistir: bool = true

var ligado: bool = false
var _jogador_perto: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _sprite_ativo: Sprite2D = $SpriteAtivo
@onready var _placeholder: ColorRect = $Placeholder
@onready var _miolo: ColorRect = $Placeholder/Miolo
@onready var _label: Label = $Rotulo


static func criar(pai: Node, nome: String, pos: Vector2, config: Dictionary = {}) -> Interruptor:
	var botao: Interruptor = load(CENA).instantiate()
	botao.name = nome
	botao.position = pos
	for chave in config:
		botao.set(chave, config[chave])
	Blockout.adicionar(pai, botao)
	return botao


func _ready() -> void:
	_atualizar_rotulo()
	if Engine.is_editor_hint():
		Blockout.aplicar_arte(_sprite, _placeholder)
		return

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if persistir and EstadoMundo.ja_feito(self):
		ligado = true
	_atualizar_visual()


func _atualizar_rotulo() -> void:
	if _label:
		_label.text = rotulo
		_label.visible = rotulo != ""


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _jogador_perto and not (ligado and uma_vez) and Interacao.pediu():
		acionar()


func acionar() -> void:
	ligado = true
	if persistir:
		EstadoMundo.marcar_feito(self)
	_atualizar_visual()
	acionado.emit()


func _atualizar_visual() -> void:
	Blockout.aplicar_arte(_sprite, _placeholder)
	if _sprite.texture and _sprite_ativo.texture:
		_sprite.visible = not ligado
		_sprite_ativo.visible = ligado
	else:
		_sprite_ativo.visible = false
	if _miolo:
		_miolo.color = Color(0.35, 0.85, 0.45) if ligado else Color(0.8, 0.35, 0.3)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_jogador_perto = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_jogador_perto = false
