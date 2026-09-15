@tool
class_name MasseiraVulcanizacao
extends Area2D

# --- MASSEIRA DE VULCANIZAÇÃO (Fase 3, ala leste) ---
#
# Dosagem com feedback físico imediato: pouco enxofre e a amostra afunda
# mole; demais e ela estilhaça; no ponto, quica alto — e vira as botas
# vulcanizadas da personagem.
#
# COMO EDITAR NO EDITOR:
#   Sprite -> PNG da masseira (o placeholder some sozinho)

const CENA := "res://scenes/fases/componentes/masseira.tscn"

signal botas_conquistadas

var _jogador_perto: bool = false
var _aberta: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _placeholder: ColorRect = $Placeholder


static func criar(pai: Node, nome: String, pos: Vector2, config: Dictionary = {}) -> MasseiraVulcanizacao:
	var masseira: MasseiraVulcanizacao = load(CENA).instantiate()
	masseira.name = nome
	masseira.position = pos
	for chave in config:
		masseira.set(chave, config[chave])
	Blockout.adicionar(pai, masseira)
	return masseira


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
	if Engine.is_editor_hint() or Progresso.tem_habilidade("botas"):
		return
	if _jogador_perto and not _aberta and Interacao.pediu():
		_aberta = true
		var dosagem := Dosagem.abrir(self, {
			"titulo": "VULCANIZAÇÃO — DOSAR O ENXOFRE",
			"modo": "parar",
			"acertos_necessarios": 3,
			"faixa_centro": 0.6,
			"faixa_largura": 0.15,
			"rotulo_esq": "POUCO S (afunda mole)",
			"rotulo_dir": "MUITO S (estilhaça)",
			"msg_falha_fraca": "Pouco enxofre — a amostra afundou, mole.",
			"msg_falha_forte": "Enxofre demais — a amostra estilhaçou!",
			"dica": "No ponto certo, a amostra QUICA alto.\n3 acertos na faixa viram as botas da personagem.  [ESC desiste]",
		})
		dosagem.terminado.connect(_on_dosagem_terminada)


func _on_dosagem_terminada(sucesso: bool, cancelado: bool) -> void:
	_aberta = false
	if cancelado or not sucesso:
		return
	Progresso.dar_habilidade("botas")
	Blockout.aviso_flutuante(get_parent(), global_position + Vector2(0, -180),
		"A amostra quicou alto — BOTAS VULCANIZADAS equipadas!\nBorracha isolante: o corredor eletrificado agora tem travessia.",
		Color(0.5, 1.0, 0.6))
	botas_conquistadas.emit()
