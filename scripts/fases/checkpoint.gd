@tool
class_name Checkpoint
extends Area2D

# --- BANDEIRA DE CHECKPOINT ---
#
# Dois estados: DESATIVADA (bandeira enrolada no mastro) e ATIVADA (bandeira
# tremulando). A personagem passar por ela ativa — e só UMA fica ativa por vez:
# tocar numa bandeira nova apaga a anterior.
#
# Morrer recarrega a fase do zero (reload_current_scene), então quem lembra da
# bandeira ativa é uma "static var" — mesmo truque do EstadoMundo. No _ready()
# da FaseBase a personagem é levada até ela em vez de nascer no SpawnPadrao.
#
# A memória só vale para mortes: sair da fase por uma porta (FadeTela) esquece
# o checkpoint, e entrar de novo recomeça do começo.
#
# COMO EDITAR NO EDITOR: arraste o nó para onde quiser. A ORIGEM é a base do
# mastro — encoste ela no chão. Ctrl+D cria outra bandeira.

const GRUPO := &"checkpoint"
const ANIM_ATIVADA := &"ativada"
const ANIM_DESATIVADA := &"desativada"

## Quanto acima da base do mastro a personagem reaparece: metade da cápsula de
## colisão dela, para nascer com o pé no chão em vez de enterrada nele.
@export var altura_do_respawn: float = 37.0

## Vira a bandeira para o outro lado. O mastro continua em cima da origem do
## nó, então virar não tira a bandeira do lugar onde ela foi posta.
@export var flip_h: bool = false:
	set(valor):
		flip_h = valor
		_aplicar_flip()

## Coluna do mastro dentro do quadro de 96px do spritesheet.
const COLUNA_MASTRO := 62
const LARGURA_QUADRO := 96

## Caminho do nó da bandeira ativa ("/root/Fase1Oficina/Checkpoint"). É estável
## entre recargas e já separa uma fase da outra.
static var _caminho_ativo: String = ""

var ativada: bool = false

@onready var _visual: AnimatedSprite2D = $Visual
## Toca só ao ativar — voltar da bandeira depois de uma morte fica em silêncio.
@onready var _som_ativar: AudioStreamPlayer = get_node_or_null("SomAtivar")

# --- LETREIRO "CHECKPOINT" ---
# Sobe acima do mastro só no instante em que a bandeira é ativada — voltar dela
# depois de uma morte não repete o letreiro. Texto, fonte, cores e altura ficam
# no nó Aviso da cena; a animação é daqui.
@onready var _aviso: Node2D = get_node_or_null("Aviso")
@onready var _texto_aviso: Label = get_node_or_null("Aviso/Texto")
var _aviso_y: float = 0.0
var _tween_aviso: Tween


func _ready() -> void:
	_aplicar_flip()
	# @tool só para o flip aparecer no editor — o resto é coisa do jogo rodando.
	if Engine.is_editor_hint():
		return

	if _aviso:
		_aviso_y = _aviso.position.y
		_aviso.visible = false
	add_to_group(GRUPO)
	add_to_group(EstadoMundo.GRUPO_SALVAR_AO_SAIR)
	body_entered.connect(_on_body_entered)
	# Voltando de uma morte: a bandeira que estava ativa já nasce tremulando.
	_mostrar_estado(str(get_path()) == _caminho_ativo)


## Espelha o sprite e reposiciona ele para o mastro não pular de lado: sem
## flip a coluna do mastro fica logo à direita da origem; com flip, a coluna
## espelhada precisa cair exatamente no mesmo lugar. A posição sai sempre da
## conta (e não da posição atual), então aplicar duas vezes não desloca nada.
func _aplicar_flip() -> void:
	var visual := get_node_or_null("Visual") as AnimatedSprite2D
	if visual == null:
		return
	var escala := visual.scale.x
	var meio := LARGURA_QUADRO / 2.0
	visual.flip_h = flip_h
	if flip_h:
		visual.position.x = (COLUNA_MASTRO + 1 - meio) * escala
	else:
		visual.position.x = (meio - COLUNA_MASTRO) * escala


func _on_body_entered(body: Node2D) -> void:
	if ativada or not body.is_in_group("player"):
		return
	ativar()


func ativar() -> void:
	_caminho_ativo = str(get_path())
	for bandeira in get_tree().get_nodes_in_group(GRUPO):
		if bandeira != self and bandeira is Checkpoint:
			bandeira._mostrar_estado(false)
	_mostrar_estado(true)
	_mostrar_aviso()
	if _som_ativar:
		_som_ativar.play()


## Entrada: o letreiro sobe de perto do topo da bandeira, aparece e "estala" no
## tamanho certo. Segura um instante e sai subindo até sumir.
func _mostrar_aviso() -> void:
	if _aviso == null or _texto_aviso == null:
		return
	if _tween_aviso:
		_tween_aviso.kill()

	_aviso.visible = true
	_aviso.position.y = _aviso_y + 24.0
	_aviso.modulate.a = 0.0
	_texto_aviso.scale = Vector2(0.6, 0.6)

	_tween_aviso = create_tween().set_parallel(true)
	_tween_aviso.tween_property(_aviso, "position:y", _aviso_y, 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_aviso.tween_property(_aviso, "modulate:a", 1.0, 0.25)
	_tween_aviso.tween_property(_texto_aviso, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_tween_aviso.chain().tween_property(_aviso, "position:y", _aviso_y - 24.0, 0.3) \
		.set_delay(0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween_aviso.tween_property(_aviso, "modulate:a", 0.0, 0.3).set_delay(0.4)
	_tween_aviso.chain().tween_callback(func() -> void: _aviso.visible = false)


func _mostrar_estado(ligada: bool) -> void:
	ativada = ligada
	if _visual:
		_visual.play(ANIM_ATIVADA if ligada else ANIM_DESATIVADA)


## Saída por porta/passagem: a próxima entrada na fase começa do início.
func salvar_ao_sair() -> void:
	_caminho_ativo = ""


## Chamado no _ready() das fases, depois do spawn normal. Se houver uma bandeira
## ativa nesta cena, leva a personagem até ela. Devolve true se levou.
static func posicionar_player_no_checkpoint(player: CharacterBody2D) -> bool:
	if _caminho_ativo.is_empty() or player == null:
		return false
	var bandeira := player.get_tree().root.get_node_or_null(NodePath(_caminho_ativo)) as Checkpoint
	if bandeira == null:
		return false

	player.global_position = bandeira.global_position + Vector2(0, -bandeira.altura_do_respawn)
	player.velocity = Vector2.ZERO
	# Mesmo cuidado da PortaFase: sem isso a câmera nasce no ponto antigo e
	# desliza até a bandeira na frente do jogador.
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.reset_smoothing()
		camera.force_update_scroll()
	return true
