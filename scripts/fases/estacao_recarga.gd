@tool
class_name EstacaoRecarga
extends Area2D

# --- ESTAÇÃO DE MISTURA DO SINALIZADOR ---
#
# Recarga do bastão de luz química: dosar bem os dois reagentes rende luz
# mais duradoura — proporção como micro-mecânica, preparando a estequiometria
# sem dizer o nome.
#
# COMO EDITAR NO EDITOR:
#   Sprite -> PNG da estação (o placeholder com os dois frascos some sozinho)
#   Luz    -> brilho próprio, para a estação ser achável no blecaute

const CENA := "res://scenes/fases/componentes/estacao_recarga.tscn"

var _jogador_perto: bool = false
var _aberta: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _placeholder: ColorRect = $Placeholder


static func criar(pai: Node, nome: String, pos: Vector2, config: Dictionary = {}) -> EstacaoRecarga:
	var estacao: EstacaoRecarga = load(CENA).instantiate()
	estacao.name = nome
	estacao.position = pos
	for chave in config:
		estacao.set(chave, config[chave])
	Blockout.adicionar(pai, estacao)
	return estacao


func _ready() -> void:
	Blockout.aplicar_arte(_sprite, _placeholder)
	if Engine.is_editor_hint():
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
	if not _jogador_perto or _aberta or not Interacao.pediu():
		return
	if not Progresso.tem_habilidade("sinalizador"):
		Blockout.aviso_flutuante(get_parent(), global_position, "Você ainda não tem o sinalizador.")
		return

	_aberta = true
	var dosagem := Dosagem.abrir(self, {
		"titulo": "MISTURA DOS REAGENTES",
		"modo": "parar",
		"acertos_necessarios": 1,
		"faixa_centro": 0.55,
		"faixa_largura": 0.15,
		"rotulo_esq": "REAGENTE A DEMAIS",
		"rotulo_dir": "REAGENTE B DEMAIS",
		"msg_falha_fraca": "Mistura desequilibrada — rendeu pouca luz.",
		"msg_falha_forte": "Mistura desequilibrada — rendeu pouca luz.",
		"dica": "A luz química nasce da PROPORÇÃO certa entre os dois reagentes.\nAperte E na faixa verde.  [ESC desiste]",
	})
	dosagem.terminado.connect(_on_dosagem_terminada)


func _on_dosagem_terminada(sucesso: bool, cancelado: bool) -> void:
	_aberta = false
	if cancelado:
		return
	if sucesso:
		Progresso.carga_sinalizador = 1.0
		Blockout.aviso_flutuante(get_parent(), global_position, "Proporção perfeita — carga cheia!", Color(0.5, 1.0, 0.6))
	else:
		Progresso.carga_sinalizador = maxf(Progresso.carga_sinalizador, 0.5)
