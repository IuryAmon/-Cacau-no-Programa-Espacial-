@tool
class_name MesaPuzzle
extends Area2D

# --- MESA DE PUZZLE DE ARRASTAR ---
#
# O ponto do mundo que abre um PuzzleOrdenar: a bancada do ciclo do
# nitrogênio, o gerador da cadeia do ATP, o purificador de CO₂.
#
# COMO EDITAR NO EDITOR:
#   Sprite         -> PNG da bancada (o placeholder some sozinho)
#   rotulo         -> nome mostrado acima
#   puzzle_config  -> os dados do puzzle (slots, peças, textos). O gerador já
#                     preenche; dá para ajustar no Inspector como Dictionary.

const CENA := "res://scenes/fases/componentes/mesa_puzzle.tscn"

signal resolvido

@export var rotulo: String = "PAINEL":
	set(valor):
		rotulo = valor
		if is_inside_tree():
			_atualizar_rotulo()
@export var cor: Color = Color(0.3, 0.55, 0.4):
	set(valor):
		cor = valor
		if is_inside_tree():
			_aplicar_cor()
@export var puzzle_config: Dictionary = {}

var ja_resolvida: bool = false
var _jogador_perto: bool = false
var _aberta: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _placeholder: ColorRect = $Placeholder
@onready var _miolo: ColorRect = $Placeholder/Miolo
@onready var _label: Label = $Rotulo


static func criar(pai: Node, nome: String, pos: Vector2, config: Dictionary) -> MesaPuzzle:
	var mesa: MesaPuzzle = load(CENA).instantiate()
	mesa.name = nome
	mesa.position = pos
	for chave in config:
		mesa.set(chave, config[chave])
	Blockout.adicionar(pai, mesa)
	return mesa


func _ready() -> void:
	_aplicar_cor()
	_atualizar_rotulo()
	Blockout.aplicar_arte(_sprite, _placeholder)
	if Engine.is_editor_hint():
		return

	ja_resolvida = EstadoMundo.ja_feito(self)
	_atualizar_rotulo()
	if ja_resolvida and _miolo:
		_miolo.color = cor.lightened(0.3)

	body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_jogador_perto = true)
	body_exited.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_jogador_perto = false)


func _aplicar_cor() -> void:
	if _placeholder:
		_placeholder.color = cor.darkened(0.5)
	if _miolo:
		_miolo.color = cor


func _atualizar_rotulo() -> void:
	if _label:
		# {interact}: E no teclado, □ desenhado no controle.
		BotoesControle.rotular(_label, rotulo + ("\n(concluído)" if ja_resolvida else "\n[{interact}]"))


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _jogador_perto and not ja_resolvida and not _aberta and Interacao.pediu():
		_aberta = true
		var puzzle := PuzzleOrdenar.nova(self, puzzle_config)
		puzzle.resolvido.connect(_on_resolvido)
		puzzle.tree_exited.connect(func() -> void: _aberta = false)


func _on_resolvido() -> void:
	ja_resolvida = true
	EstadoMundo.marcar_feito(self)
	_atualizar_rotulo()
	if _miolo:
		_miolo.color = cor.lightened(0.3)
	resolvido.emit()
