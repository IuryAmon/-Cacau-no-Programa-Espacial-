@tool
class_name PickupHabilidade
extends Area2D

# --- PICKUP DE HABILIDADE PERMANENTE ---
#
# O momento em que uma ferramenta vira da personagem: bumerangue na bancada,
# mochila no armário da torre, sinalizador no armário de emergência.
#
# COMO EDITAR NO EDITOR:
#   Sprite      -> PNG da ferramenta (o placeholder colorido some sozinho).
#                  Deixando vazio, a arte vem do CatalogoFerramentas.
#   habilidade  -> macarico | bumerangue | mochila | sinalizador | botas
#   rotulo      -> nome da ferramenta. NÃO aparece mais no mapa: o Rotulo fica
#                  escondido e quem avisa que dá para pegar é o balão de
#                  exclamação (ExclamacaoAnimada), o mesmo dos cientistas e
#                  dos terminais. O texto só sobrou como nome no editor.
#   flutuar     -> desligue para um item preso (ex: dentro de uma gaiola)
#                  ficar parado no chão em vez de balançar

const CENA := "res://scenes/fases/componentes/pickup_habilidade.tscn"

@export_enum("macarico", "bumerangue", "mochila", "sinalizador", "botas", "lanterna")
var habilidade: String = "bumerangue"
@export var rotulo: String = "FERRAMENTA":
	set(valor):
		rotulo = valor
		if is_inside_tree():
			_atualizar_rotulo()
@export_multiline var mensagem: String = ""
@export var cor: Color = Color(0.95, 0.75, 0.25):
	set(valor):
		cor = valor
		if is_inside_tree():
			_aplicar_cor()
## Balanço vertical suave para chamar o olho. Desligue para itens presos (uma
## gaiola, um encaixe) que devem ficar quietos no lugar deles.
@export var flutuar: bool = true

var _jogador_perto: bool = false
# Espelha o "monitoring" para o rótulo só ser reescrito quando a trava muda.
var _rotulo_liberado: bool = true
# Estado do balão de exclamação, para o PopupFX só ser chamado na virada e não
# reiniciar a animação todo frame.
var _aviso_visivel: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _placeholder: ColorRect = $Placeholder
@onready var _miolo: ColorRect = $Placeholder/Miolo
@onready var _label: Label = $Rotulo
@onready var _exclamacao: AnimatedSprite2D = get_node_or_null("ExclamacaoAnimada")


static func criar(pai: Node, nome: String, pos: Vector2, config: Dictionary) -> PickupHabilidade:
	var pickup: PickupHabilidade = load(CENA).instantiate()
	pickup.name = nome
	pickup.position = pos
	for chave in config:
		pickup.set(chave, config[chave])
	Blockout.adicionar(pai, pickup)
	return pickup


func _ready() -> void:
	_puxar_arte_do_catalogo()
	_atualizar_rotulo()
	_aplicar_cor()
	Blockout.aplicar_arte(_sprite, _placeholder)
	if Engine.is_editor_hint():
		return

	if Progresso.tem_habilidade(habilidade):
		queue_free()
		return

	if _exclamacao:
		_exclamacao.visible = false

	body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_jogador_perto = true)
	body_exited.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_jogador_perto = false)

	# Flutua devagar para chamar o olho — a menos que esteja preso no lugar.
	if flutuar:
		var tween := create_tween()
		tween.set_loops()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(self, "position:y", position.y - 8.0, 0.8)
		tween.tween_property(self, "position:y", position.y, 0.8)


# Se o slot Sprite estiver vazio, a arte vem do CatalogoFerramentas — é assim
# que o PNG do maçarico aparece sem precisar arrastar nada no editor. Soltar
# uma textura no slot continua tendo prioridade.
func _puxar_arte_do_catalogo() -> void:
	if _sprite == null or _sprite.texture != null:
		return
	var textura := CatalogoFerramentas.icone(habilidade)
	if textura != null:
		_sprite.texture = textura
		var escala := CatalogoFerramentas.escala_mapa(habilidade)
		_sprite.scale = Vector2(escala, escala)


func _aplicar_cor() -> void:
	if _placeholder:
		_placeholder.color = cor.darkened(0.4)
	if _miolo:
		_miolo.color = cor


func _atualizar_rotulo() -> void:
	if _label == null:
		return
	# O "[E]" só aparece quando a ferramenta realmente pode ser pega. Trancada
	# na gaiola, o pickup fica com o monitoring desligado (ver gaiola_puzzle) —
	# e prometer o E ali seria mentira para quem está lendo o rótulo.
	_label.text = rotulo + "\n[E]" if monitoring else rotulo


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Destrancou a gaiola? O rótulo passa a oferecer o E.
	if monitoring != _rotulo_liberado:
		_rotulo_liberado = monitoring
		_atualizar_rotulo()

	_atualizar_aviso()

	if _jogador_perto and Interacao.pediu():
		Progresso.dar_habilidade(habilidade)
		# Ferramenta com arte já ganha o popup de apresentação (nome, descrição
		# e o selo indo para o canto): o aviso flutuante seria feedback dobrado.
		if mensagem != "" and CatalogoFerramentas.dados(habilidade).is_empty():
			Blockout.aviso_flutuante(get_parent(), global_position, mensagem, Color(0.5, 1.0, 0.6))
		queue_free()


## O balão de exclamação no lugar do texto: aparece quando a jogadora chega
## perto E a ferramenta pode mesmo ser pega. Trancada na gaiola o pickup fica
## com o "monitoring" desligado — e o balão ali seria a mesma promessa falsa
## que o "[E]" escrito era.
func _atualizar_aviso() -> void:
	if _exclamacao == null:
		return
	var deve: bool = _jogador_perto and monitoring
	if deve == _aviso_visivel:
		return
	_aviso_visivel = deve
	if deve:
		PopupFX.mostrar(_exclamacao)
	else:
		PopupFX.esconder(_exclamacao)
