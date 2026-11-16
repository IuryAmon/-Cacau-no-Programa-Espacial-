@tool
class_name IndicadorEntrada
extends Node2D

# --- O "APERTE PARA ENTRAR" DA PORTA DE FASE ---
#
# Entrar numa porta é o mesmo gesto de qualquer outra coisa do cenário: a ação
# "interact" — E no teclado, □ no controle. O desenho é o IconeInteragir de
# sempre (o da cesta, da porta de metal, do elevador), que já mostra só o do
# dispositivo em uso e troca sozinho.
#
# Quem usa: porta_fase.gd instancia esta cena (componentes/indicador_entrada.tscn)
# e chama mostrar() quando a Cacau chega perto. As portas do simulador e das
# fases (porta_simulador.gd) usam o IconeInteragir direto, sem este invólucro.
#
# @tool só para a PortaFase (que roda no editor) enxergar o tipo.

const CENA := "res://scenes/fases/componentes/indicador_entrada.tscn"

var _pedido: bool = false

@onready var _icone: IconeInteragir = $IconeInteragir


func _ready() -> void:
	# No editor o botão fica à mostra, para dar para posicionar.
	_icone.visible = Engine.is_editor_hint()


## Liga ou desliga o aviso. Ao ligar, a pulsação recomeça do primeiro quadro.
func mostrar(sim: bool) -> void:
	if sim and not _pedido:
		_icone.reiniciar()
	_pedido = sim
	_icone.visible = sim


func mostrando() -> bool:
	return _pedido
