class_name ComputadorPuzzle
extends Area2D

# --- TERMINAL DE COMANDO (o computador que aciona uma máquina da fase) ---
#
# É o irmão de mundo da GaiolaPuzzle: um ponto do mapa que abre uma tela de
# puzzle e, quando ela é resolvida, ACIONA alguma coisa. A diferença é o que
# está do outro lado — a gaiola destranca um item, o terminal liga uma
# máquina que já estava lá, parada.
#
# É por isso que ele existe em vez de mais uma conversa com o cientista: a
# plataforma do world1 sobe porque alguém MANDOU ela subir; esta sobe porque a
# Cacau ENTENDEU como o guincho funciona. A porta é a mesma, a chave é outra.
#
# COMO EDITAR NO EDITOR:
#   puzzle_cena  -> a tela do puzzle (CanvasLayer com "abrir_puzzle()" e o
#                   sinal "puzzle_resolvido"). Vazia = o E aciona direto,
#                   útil para testar o resto da cena sem resolver nada.
#   alvo/metodo  -> quem é acionado e por qual método. O padrão é "acionar()",
#                   que é o que a plataforma (plataforma.gd) espera.
#   rotulo       -> o nome que aparece flutuando acima do terminal.
#   ComputadorAnimado -> as duas animações do painel: "vermelho" (trancado) e
#                   "azul" (liberado). Troque os PNGs no próprio nó.
#
# O sinal "resolvido" continua saindo daqui para quem quiser ouvir na cena —
# o "alvo" é só o atalho para o caso comum de um terminal, uma máquina.

signal resolvido

@export_group("Puzzle")
## Tela do puzzle que este terminal abre. Vazio: o E aciona direto.
@export var puzzle_cena: PackedScene
## Nome mostrado acima do terminal.
@export var rotulo: String = "TERMINAL"
## Vira o painel para o outro lado.
@export var flip_h: bool = false:
	set(valor):
		flip_h = valor
		if _painel:
			_painel.flip_h = flip_h

@export_group("O que ele aciona")
## A máquina que este terminal liga (a plataforma, no caso da fase 1).
@export var alvo: NodePath
## Método chamado no alvo quando o puzzle é resolvido.
@export var metodo: StringName = &"acionar"

@export_group("Sons")
@export var som_sucesso: AudioStream

var _resolvido: bool = false
var _jogador_perto: bool = false
var _puzzle_ui: CanvasLayer = null

@onready var _painel: AnimatedSprite2D = $ComputadorAnimado
@onready var _exclamacao: AnimatedSprite2D = $ExclamacaoAnimada
@onready var _label: Label = $Rotulo
@onready var _audio: AudioStreamPlayer2D = $AudioStreamPlayer2D


func _ready() -> void:
	_resolvido = EstadoMundo.ja_feito(self)
	_painel.flip_h = flip_h
	_atualizar_visual()

	if _exclamacao:
		_exclamacao.visible = false
		_exclamacao.stop()

	# A tela só é montada se ainda houver o que resolver.
	if puzzle_cena and not _resolvido:
		_puzzle_ui = puzzle_cena.instantiate() as CanvasLayer
		add_child(_puzzle_ui)
		_puzzle_ui.puzzle_resolvido.connect(_ao_resolver)

	body_entered.connect(_ao_entrar)
	body_exited.connect(_ao_sair)

	# Cena recarregada com o terminal já resolvido: a máquina precisa voltar a
	# funcionar sozinha, senão morrer depois de acionar a plataforma deixaria
	# ela parada para sempre. Adiado porque o alvo pode não ter rodado o
	# _ready() dele ainda — a plataforma monta o PathFollow2D lá dentro.
	if _resolvido:
		_acionar_alvo.call_deferred()


func _process(_delta: float) -> void:
	if _jogador_perto and not _resolvido and Interacao.pediu():
		if _puzzle_ui:
			_puzzle_ui.abrir_puzzle()
		else:
			# Sem puzzle_cena o terminal é só um botão.
			_ao_resolver()


func _ao_resolver() -> void:
	_resolvido = true
	EstadoMundo.marcar_feito(self)
	_atualizar_visual()
	if _exclamacao:
		PopupFX.esconder(_exclamacao)
	if _audio and som_sucesso:
		_audio.stream = som_sucesso
		_audio.play()
	_acionar_alvo()
	resolvido.emit()


func _acionar_alvo() -> void:
	if alvo.is_empty():
		return  # terminal sem máquina: só o sinal "resolvido" sai daqui
	var maquina := get_node_or_null(alvo)
	if maquina == null:
		push_warning("%s: não achei o alvo em '%s'." % [name, alvo])
		return
	if maquina.has_method(metodo):
		maquina.call(metodo)
	else:
		push_warning("%s: o alvo '%s' não tem o método '%s'." % [name, maquina.name, metodo])


func _atualizar_visual() -> void:
	if _painel and _painel.sprite_frames:
		var animacao := &"azul" if _resolvido else &"vermelho"
		if _painel.sprite_frames.has_animation(animacao):
			_painel.play(animacao)
	if _label:
		_label.text = rotulo + ("\n(acionado)" if _resolvido else "\n[E]")


func _ao_entrar(corpo: Node2D) -> void:
	if not corpo.is_in_group("player"):
		return
	_jogador_perto = true
	if _exclamacao and not _resolvido:
		PopupFX.mostrar(_exclamacao)


func _ao_sair(corpo: Node2D) -> void:
	if not corpo.is_in_group("player"):
		return
	_jogador_perto = false
	if _exclamacao:
		PopupFX.esconder(_exclamacao)
