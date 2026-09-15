extends Node2D

# "Simulador ligado": o shoot'em up que roda dentro do foguete pousado do
# world3. O objetivo é fazer 1000 pontos neutralizando as moléculas certas.
#
# Fluxo da cena:
#   nasce escura -> clareia com o jogo já rodando -> jogador faz os pontos
#   (ou morre, ou sai pelo ESC) -> tela escurece -> Dr. Chico comenta ->
#   volta para o world3, no ponto exato em que ele entrou.

const TIMELINE_VITORIA := "simulador_vitoria"
const TIMELINE_DERROTA := "simulador_derrota"
const TIMELINE_SAIDA := "simulador_saida"
const CENA_PADRAO_DE_RETORNO := "res://scenes/simulador_(world_3).tscn"

@export var explosao_da_nave: PackedScene
@export var duracao_clarear: float = 1.2
@export var duracao_escurecer: float = 1.2

var _fade: FadeTela
var _encerrando: bool = false

@onready var _nave: CharacterBody2D = $Nave
@onready var _spawner: Node2D = $Spawner
@onready var _menu: CanvasLayer = $MenuSimulador
@onready var _musica: AudioStreamPlayer = $Musica
@onready var _hud: Control = %HudRaiz
@onready var _label_pontos: Label = %PontuacaoLabel
@onready var _hud_nave: HudVital = %HudNave


func _ready() -> void:
	_fade = FadeTela.criar(self, true)

	# A nave já emitiu os sinais iniciais no _ready() dela (filhos ficam prontos
	# antes do pai), então o primeiro valor do HUD é lido direto dela.
	_nave.pontuacao_mudou.connect(_on_pontuacao_mudou)
	_nave.vida_mudou.connect(_on_vida_mudou)
	_nave.morreu.connect(_on_nave_morreu)
	_menu.saida_pedida.connect(_on_saida_pedida)

	_on_vida_mudou(_nave.vida, _nave.vida_maxima)
	_on_pontuacao_mudou(_nave.pontos)

	_hud.modulate.a = 0.0
	_ligar()


# --- ABERTURA ---
func _ligar() -> void:
	# Música entra subindo, como se o sistema estivesse ganhando energia.
	# O mp3 não foi importado em loop, então a repetição é feita na mão.
	_musica.finished.connect(_repetir_musica)
	_musica.volume_db = -80.0
	_musica.play()
	_musica.seek(3.0)
	create_tween().tween_property(_musica, "volume_db", 0.0, 1.5)

	await _fade.clarear(duracao_clarear)

	create_tween().tween_property(_hud, "modulate:a", 1.0, 0.5)
	_menu.pode_pausar = true


# --- HUD ---
func _on_pontuacao_mudou(pontos: int) -> void:
	var alvo := SimuladorEstado.PONTUACAO_ALVO
	_label_pontos.text = "%d / %d" % [pontos, alvo]
	_menu.atualizar_pontuacao(pontos, alvo)

	if pontos >= alvo and not _encerrando:
		_vencer()


func _on_vida_mudou(vida: int, vida_maxima: int) -> void:
	_hud_nave.definir_vida(float(vida), float(vida_maxima))


# --- FINAIS ---
func _vencer() -> void:
	_encerrando = true
	SimuladorEstado.ja_completou = true
	_encerrar_rodada()

	await get_tree().create_timer(0.8).timeout
	await _apagar()
	await _falar(TIMELINE_VITORIA)
	_voltar_para_o_foguete()


func _on_nave_morreu() -> void:
	if _encerrando:
		return
	_encerrando = true
	_encerrar_rodada()

	if explosao_da_nave:
		var explosao := explosao_da_nave.instantiate()
		add_child(explosao)
		explosao.global_position = _nave.global_position
	_nave.visible = false

	await get_tree().create_timer(1.0).timeout
	await _apagar()
	await _falar(TIMELINE_DERROTA)
	# Perdeu: a simulação recomeça do zero, sem sair do foguete.
	get_tree().reload_current_scene()


func _on_saida_pedida() -> void:
	if _encerrando:
		return
	_encerrando = true
	_encerrar_rodada()

	await _apagar()
	await _falar(TIMELINE_SAIDA)
	_voltar_para_o_foguete()


## Congela tudo que estava acontecendo e limpa a tela de moléculas e tiros.
func _encerrar_rodada() -> void:
	_menu.pode_pausar = false
	_spawner.parar()
	_nave.desligar()

	for grupo in ["enemy", "blue_bullet", "green_bullet"]:
		for no in get_tree().get_nodes_in_group(grupo):
			no.queue_free()


func _apagar() -> void:
	create_tween().tween_property(_musica, "volume_db", -60.0, duracao_escurecer)
	await _fade.escurecer(duracao_escurecer)
	_musica.stop()
	# Some com o HUD para o Dr. Chico falar numa tela totalmente preta.
	_fade.esconder_huds(self)


func _repetir_musica() -> void:
	if not _encerrando:
		_musica.play()


func _falar(timeline: String) -> void:
	Dialogic.VAR.set_variable("reveal_name", "Dr. Chico")
	Dialogic.start(timeline)
	await Dialogic.timeline_ended


func _voltar_para_o_foguete() -> void:
	SimuladorEstado.registrar_saida()
	# A tela já está preta desde o "_apagar()": o world3 clareia na chegada.
	FadeTela.chegada_escura = true
	var destino := SimuladorEstado.cena_de_retorno
	if destino.is_empty():
		destino = CENA_PADRAO_DE_RETORNO
	get_tree().change_scene_to_file(destino)
