@tool
class_name Madeira
extends Area2D

# --- TORA DE MADEIRA (combustível da fornalha) ---
#
# A matéria-prima da carbonização, recolhida no depósito da oficina. Cada tora
# apanhada vai para o INVENTÁRIO; é de lá que a fornalha tira a lenha quando a
# pessoa abastece o forno.
#
# COMO EDITAR NO EDITOR:
#   Sprite -> PNG da tora (madeira.png; o placeholder marrom some sozinho)
#   icone  -> imagem que aparece no slot do inventário
#
# Sem texto no mapa: quem avisa que dá para recolher a tora é o balão de
# exclamação (ExclamacaoAnimada), o mesmo dos cientistas e dos terminais.

const CENA := "res://scenes/fases/componentes/madeira.tscn"

## Prefixo dos ids no inventário. Cada tora entra com um id próprio porque o
## inventário guarda um item por id — é assim que ele consegue mostrar as três.
const PREFIXO_ID := "madeira_"

## Grupo de toda tora espalhada pela fase — é assim que a fornalha as encontra.
const GRUPO := "madeira"

const ICONE_PADRAO := "res://assets/Lab/fornalha/madeira.png"

## Ícone do slot do inventário. Deixe vazio para usar a arte da própria tora.
@export var icone: Texture2D

var _jogador_perto: bool = false
# Estado do balão, para o PopupFX só ser chamado na virada.
var _aviso_visivel: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _placeholder: ColorRect = $Placeholder
@onready var _exclamacao: AnimatedSprite2D = get_node_or_null("ExclamacaoAnimada")


static func criar(pai: Node, nome: String, pos_local: Vector2) -> Madeira:
	var tora: Madeira = load(CENA).instantiate()
	tora.name = nome
	tora.position = pos_local
	Blockout.adicionar(pai, tora)
	return tora


## Quantas toras a pessoa está carregando.
static func quantidade_no_inventario() -> int:
	var total := 0
	for item in Inventario.itens_coletados:
		if str(item["id"]).begins_with(PREFIXO_ID):
			total += 1
	return total


## Tira uma tora do inventário. Devolve false se não havia nenhuma.
static func consumir_do_inventario() -> bool:
	for item in Inventario.itens_coletados:
		var id := str(item["id"])
		if id.begins_with(PREFIXO_ID):
			Inventario.remover_item(id)
			return true
	return false


func _ready() -> void:
	Blockout.aplicar_arte(_sprite, _placeholder)
	if Engine.is_editor_hint():
		return

	# Já recolhida numa visita anterior (a lenha está no inventário ou dentro
	# da fornalha): não reaparece no depósito ao voltar para a fase.
	if EstadoMundo.ja_feito(self):
		queue_free()
		return

	body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_jogador_perto = true)
	body_exited.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_jogador_perto = false)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_atualizar_aviso()
	if _jogador_perto and Interacao.pediu():
		coletar()


## Guarda a tora no inventário e some com ela — usado tanto pela interação
## normal (E por perto) quanto por atalhos de teste que recolhem tudo de vez.
func coletar() -> void:
	_guardar()
	EstadoMundo.marcar_feito(self)
	queue_free()


func _guardar() -> void:
	var textura := icone
	if textura == null and _sprite:
		textura = _sprite.texture
	if textura == null:
		textura = load(ICONE_PADRAO)
	Inventario.adicionar_item(PREFIXO_ID + name.to_lower(), "Madeira", textura,
		"Lenha seca do depósito. A fornalha aceita três cargas.")


## O balão de exclamação no lugar do "madeira [E]" que ficava escrito em cima
## da tora: aparece quando a jogadora chega perto e some quando ela se afasta.
func _atualizar_aviso() -> void:
	if _exclamacao == null:
		return
	if _jogador_perto == _aviso_visivel:
		return
	_aviso_visivel = _jogador_perto
	if _jogador_perto:
		PopupFX.mostrar(_exclamacao)
	else:
		PopupFX.esconder(_exclamacao)
