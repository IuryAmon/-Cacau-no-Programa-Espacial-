extends CanvasLayer

# Menu que aparece quando o jogador aperta ESC dentro do simulador.
# Duas opções: voltar para a simulação ou desligar tudo e sair do foguete.

signal saida_pedida

## Enquanto false o ESC é ignorado (transições de entrada e de fim de rodada).
var pode_pausar: bool = false

@onready var _botao_continuar: Button = $Centro/Opcoes/Continuar
@onready var _botao_sair: Button = $Centro/Opcoes/Sair
@onready var _label_pontos: Label = $Centro/Opcoes/Pontuacao
@onready var _som: AudioStreamPlayer = $SomBotao


func _ready() -> void:
	visible = false
	_botao_continuar.pressed.connect(_on_continuar_pressionado)
	_botao_sair.pressed.connect(_on_sair_pressionado)


func _unhandled_input(evento: InputEvent) -> void:
	if not evento.is_action_pressed("ui_cancel"):
		return
	if visible:
		_on_continuar_pressionado()
		get_viewport().set_input_as_handled()
	elif pode_pausar:
		abrir()
		get_viewport().set_input_as_handled()


func atualizar_pontuacao(pontos: int, alvo: int) -> void:
	_label_pontos.text = "%d / %d pontos" % [pontos, alvo]


func abrir() -> void:
	visible = true
	get_tree().paused = true
	_botao_continuar.grab_focus()
	_tocar_som()


func fechar() -> void:
	_botao_continuar.release_focus()
	_botao_sair.release_focus()
	visible = false
	get_tree().paused = false


func _on_continuar_pressionado() -> void:
	_tocar_som()
	fechar()


func _on_sair_pressionado() -> void:
	_tocar_som()
	pode_pausar = false
	fechar()
	saida_pedida.emit()


func _tocar_som() -> void:
	if _som:
		_som.stop()
		_som.play()
