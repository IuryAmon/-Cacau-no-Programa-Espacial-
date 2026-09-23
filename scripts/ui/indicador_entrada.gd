@tool
class_name IndicadorEntrada
extends Node2D

# --- O "APERTE PARA ENTRAR" DAS PORTAS ---
#
# Toda entrada de fase pede o mesmo gesto — apertar para cima — e mostra o
# mesmo desenho, só de quem está jogando:
#
#   teclado e mouse  ->  a tecla W afundando
#   controle na mão  ->  o direcional com o braço de cima piscando
#
# Nunca os dois juntos ("W ou ↑"): trocou de teclado para controle com o aviso
# na tela, ele troca sozinho (sinal "mudou" do autoload Controle).
#
# Quem usa:
#   porta_fase.gd       instancia esta cena (componentes/indicador_entrada.tscn)
#                       e chama mostrar() quando a Cacau chega perto;
#   porta_simulador.gd  já tem os dois desenhos na própria cena e usa só a
#                       regra, com escolher().
#
# @tool só para a PortaFase (que roda no editor) enxergar o tipo: no editor o
# W fica à mostra, para dar para posicionar.

const CENA := "res://scenes/fases/componentes/indicador_entrada.tscn"

var _pedido: bool = false

@onready var _tecla: AnimatedSprite2D = $TeclaW
@onready var _direcional: AnimatedSprite2D = $Direcional


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var controle := get_node_or_null(^"/root/Controle")
	if controle:
		controle.mudou.connect(_ao_trocar_dispositivo)
	_aplicar()


## Liga ou desliga o aviso. Ao ligar, a animação recomeça do primeiro quadro.
func mostrar(sim: bool) -> void:
	if sim and not _pedido:
		reiniciar_animacoes(self)
	_pedido = sim
	_aplicar()


func mostrando() -> bool:
	return _pedido


func _ao_trocar_dispositivo(_em_uso: bool) -> void:
	_aplicar()


func _aplicar() -> void:
	escolher(_tecla, _direcional, _pedido)


## A regra: com o aviso ligado, aparece SÓ o desenho do dispositivo em uso.
static func escolher(tecla: CanvasItem, direcional: CanvasItem, mostrar_aviso: bool) -> void:
	var no_controle := BotoesControle.controle_em_uso()
	tecla.visible = mostrar_aviso and not no_controle
	direcional.visible = mostrar_aviso and no_controle


## Recomeça do primeiro quadro todo sprite animado do nó e dos filhos.
static func reiniciar_animacoes(no: Node) -> void:
	if no is AnimatedSprite2D:
		var sprite := no as AnimatedSprite2D
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(&"default") \
				and sprite.sprite_frames.get_frame_count(&"default") > 1:
			sprite.play(&"default")
			sprite.frame = 0
	for filho in no.get_children():
		reiniciar_animacoes(filho)
