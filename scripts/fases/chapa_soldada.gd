@tool
class_name ChapaSoldada
extends StaticBody2D

# --- CHAPA METÁLICA SOLDADA ---
#
# A fechadura do maçarico oxídrico: bloqueia o caminho até alguém com a chama
# de H₂ + O₂ chegar perto e apertar E.
#
# COMO EDITAR NO EDITOR:
#   Sprite   -> PNG da chapa (o placeholder cinza some sozinho)
#   tamanho  -> redimensiona colisão, placeholder e área de interação
#   Fagulhas -> partículas do corte; troque cor/quantidade à vontade

const CENA := "res://scenes/fases/componentes/chapa_soldada.tscn"

@export var tamanho: Vector2 = Vector2(28, 120):
	set(valor):
		tamanho = valor
		if is_inside_tree():
			_aplicar_tamanho()
@export var rotulo: String = "CHAPA SOLDADA":
	set(valor):
		rotulo = valor
		if is_inside_tree():
			_atualizar_rotulo()

var _jogador_perto: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _placeholder: ColorRect = $Placeholder
@onready var _colisao: CollisionShape2D = $Colisao
@onready var _area: Area2D = $AreaInteracao
@onready var _area_colisao: CollisionShape2D = $AreaInteracao/Colisao
@onready var _label: Label = $Rotulo
@onready var _fagulhas: CPUParticles2D = $Fagulhas
@onready var _soldas: Node2D = $Placeholder/Soldas


static func criar(pai: Node, nome: String, pos_centro: Vector2, config: Dictionary = {}) -> ChapaSoldada:
	var chapa: ChapaSoldada = load(CENA).instantiate()
	chapa.name = nome
	chapa.position = pos_centro
	for chave in config:
		chapa.set(chave, config[chave])
	Blockout.adicionar(pai, chapa)
	return chapa


func _ready() -> void:
	_aplicar_tamanho()
	_atualizar_rotulo()
	Blockout.aplicar_arte(_sprite, _placeholder)
	if Engine.is_editor_hint():
		return

	if EstadoMundo.ja_feito(self):
		queue_free()
		return

	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)


func _aplicar_tamanho() -> void:
	if _colisao and _colisao.shape is RectangleShape2D:
		(_colisao.shape as RectangleShape2D).size = tamanho
	if _placeholder:
		_placeholder.size = tamanho
		_placeholder.position = -tamanho / 2.0
	if _area_colisao and _area_colisao.shape is RectangleShape2D:
		(_area_colisao.shape as RectangleShape2D).size = tamanho + Vector2(120, 60)
	if _label:
		_label.position = Vector2(-_label.size.x / 2.0, -tamanho.y / 2.0 - 34)
	_desenhar_soldas()


# Os cordões de solda do placeholder: as marcas que o maçarico corta. Só
# aparecem enquanto não há arte no slot Sprite.
func _desenhar_soldas() -> void:
	if _soldas == null:
		return
	for filho in _soldas.get_children():
		filho.free()
	var vertical := tamanho.y > tamanho.x
	var passo := 22.0
	var total := int((tamanho.y if vertical else tamanho.x) / passo)
	for i in total:
		var pos := Vector2(4, 10 + i * passo) if vertical else Vector2(10 + i * passo, 4)
		var ponto := ColorRect.new()
		ponto.color = Color(0.95, 0.55, 0.2)
		ponto.size = Vector2(6, 6)
		ponto.position = pos
		ponto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_soldas.add_child(ponto)


func _atualizar_rotulo() -> void:
	if _label:
		_label.text = rotulo
		_label.visible = rotulo != ""


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _jogador_perto and Interacao.pediu():
		if Progresso.tem_habilidade("macarico"):
			_cortar()
		else:
			Blockout.aviso_flutuante(get_parent(), global_position, "Soldada. Só um maçarico corta isto.")


func _cortar() -> void:
	EstadoMundo.marcar_feito(self)
	set_process(false)
	_colisao.set_deferred("disabled", true)
	_fagulhas.emitting = true

	# A personagem segura a pose do maçarico pelo tempo exato do corte
	# (0.25 + 0.45 + 0.4 das etapas do tween abaixo), virada para a chapa.
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("usar_macarico"):
		player.usar_macarico(1.1, global_position.x)
	FerramentasHUD.destacar("macarico")

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.6, 1.1, 0.7), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	tween.tween_interval(0.4)
	tween.tween_callback(queue_free)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_jogador_perto = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_jogador_perto = false
