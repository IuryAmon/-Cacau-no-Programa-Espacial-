extends Node2D

@export_group("Puzzle")
# Arraste aqui a cena do puzzle deste item (ex: puzzle_hidrogenio.tscn).
# Deixe vazio para uma gaiola SEM puzzle: só chegar perto e apertar E já
# abre (ex: o bumerangue).
@export var puzzle_cena: PackedScene
# Aponte para o ItemColetavel que esta gaiola está travando
@export var item_alvo: NodePath

@export_group("Sons")
@export var som_abertura: AudioStream

var jogador_na_area: bool = false
var puzzle_concluido: bool = false
var puzzle_ui: CanvasLayer = null
var _item: Node = null

@onready var gaiola_anim: AnimatedSprite2D     = $GaiolaAnimada
@onready var exclamacao: AnimatedSprite2D      = $ExclamacaoAnimada
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready():
	# Gaiola já aberta antes (a cena recarregou por morte ou por troca de fase):
	# nasce aberta, sem animação, sem som e sem puzzle nenhum para abrir.
	puzzle_concluido = EstadoMundo.ja_feito(self)

	# Instancia o puzzle dinamicamente
	if puzzle_cena and not puzzle_concluido:
		puzzle_ui = puzzle_cena.instantiate() as CanvasLayer
		add_child(puzzle_ui)
		puzzle_ui.puzzle_resolvido.connect(_on_puzzle_resolvido)

	# Desativa o item externo enquanto a gaiola está fechada
	if item_alvo:
		_item = get_node_or_null(item_alvo)
		# Pickup de habilidade que a personagem já tem se apaga sozinho no
		# próprio _ready; mexer no monitoring dele depois disso é erro certo.
		if _item and _item.is_queued_for_deletion():
			_item = null
		if _item and not puzzle_concluido:
			_item.set_deferred("monitoring", false)
			_item.set_deferred("monitorable", false)

	if gaiola_anim and gaiola_anim.sprite_frames:
		var animacao_inicial := "aberta" if puzzle_concluido else "fechada"
		if gaiola_anim.sprite_frames.has_animation(animacao_inicial):
			gaiola_anim.play(animacao_inicial)
		gaiola_anim.animation_finished.connect(_on_gaiola_animation_finished)

	if exclamacao:
		exclamacao.visible = false
		exclamacao.stop()

func _process(_delta: float):
	if jogador_na_area and not puzzle_concluido and Interacao.pediu():
		if puzzle_ui:
			puzzle_ui.abrir_puzzle()
		else:
			# Sem puzzle_cena: o E já abre a gaiola direto.
			_on_puzzle_resolvido()

func _on_puzzle_resolvido():
	puzzle_concluido = true
	EstadoMundo.marcar_feito(self)
	if exclamacao:
		PopupFX.esconder(exclamacao)
	if gaiola_anim and gaiola_anim.sprite_frames:
		if gaiola_anim.sprite_frames.has_animation("abrindo"):
			gaiola_anim.play("abrindo")
	if audio_player:
		if som_abertura:
			audio_player.stream = som_abertura
		await get_tree().create_timer(1.0).timeout
		audio_player.play()

func _on_gaiola_animation_finished():
	if not gaiola_anim:
		return
	if gaiola_anim.animation == "abrindo":
		if gaiola_anim.sprite_frames.has_animation("aberta"):
			gaiola_anim.play("aberta")
		# Reativa o item externo para que o jogador possa coletá-lo
		if _item:
			_item.set_deferred("monitoring", true)
			_item.set_deferred("monitorable", true)

func _on_zona_deteccao_body_entered(body: Node2D):
	if body.name == "Player" and not puzzle_concluido:
		jogador_na_area = true
		if exclamacao:
			PopupFX.mostrar(exclamacao)

func _on_zona_deteccao_body_exited(body: Node2D):
	if body.name == "Player":
		jogador_na_area = false
		if exclamacao and not puzzle_concluido:
			PopupFX.esconder(exclamacao)
