extends Area2D

# Cutscene do final da fase: o cientista ("Desconhecido") chega andando
# até o player e revela que é o Dr. Chico. Depois roda a timeline do Dialogic.

const TIMELINE_FINAL = "cientista_final_fase"
const CIENTISTA_SCENE = preload("res://scenes/cientista.tscn")
const DIALOG_BOX_SCENE = preload("res://scenes/dialog_box.tscn")

# Velocidade (px/s) em que a animação de andar bate certo com o chão no
# speed_scale 1.0. Mexer em `velocidade` acelera a animação junto, então os
# pés continuam sem patinar.
const VELOCIDADE_NATURAL := 120.0

@export var distancia_spawn : float = 650.0   # distância (à esquerda do player) onde o cientista aparece
@export var distancia_parada : float = 90.0   # distância do player em que ele para
@export var velocidade : float = 140.0        # pixels por segundo da caminhada
@export var espera_camera : float = 0.8       # segundos até a câmera parar antes do balão surgir
@export var altura_queda : float = 400.0      # altura de onde o cientista cai
@export var duracao_queda : float = 0.6       # tempo da queda
@export var espera_apos_texto : float = 1.4   # segundos que o balão fica parado (já digitado) antes de sumir sozinho
@export var espera_troca_de_cena : float = 0.8 # respiro (com a câmera voltando) antes da tela apagar rumo ao laboratório
@export var duracao_fade_laboratorio : float = 1.0 # tempo que a tela leva para apagar na ida ao laboratório

var ja_aconteceu : bool = false
var player_ref : Node = null
var cientista_ator : Node2D = null
var caixa_grito : Node2D = null


func _ready() -> void:
	# Voltando ao world1 pela passagem do laser, a revelação já aconteceu: a
	# cutscene não pode acontecer de novo.
	ja_aconteceu = EstadoMundo.revelou_dr_chico
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if ja_aconteceu or body.name != "Player":
		return
	ja_aconteceu = true
	player_ref = body

	# Só trava o player e começa a cutscene quando ele estiver no chão —
	# senão a animação de pulo congela no meio do ar.
	while player_ref.has_method("is_on_floor") and not player_ref.is_on_floor():
		await get_tree().process_frame

	_iniciar_cutscene()


func _iniciar_cutscene() -> void:
	# Trava o player e deixa ele parado na animação idle
	player_ref.pode_se_mover = false
	player_ref.velocity = Vector2.ZERO
	var sprite_player = player_ref.get_node_or_null("AnimatedSprite2D")
	if sprite_player:
		sprite_player.play("idle")

	# Espera a câmera parar de seguir o player antes de mostrar o balão
	await get_tree().create_timer(espera_camera).timeout

	# Caixa de diálogo do "Espera aí!!!" — some sozinha depois de um tempo
	caixa_grito = DIALOG_BOX_SCENE.instantiate()
	get_parent().add_child(caixa_grito)
	caixa_grito.global_position = Vector2(
		player_ref.global_position.x - distancia_spawn + 150.0 - 30.0,
		player_ref.global_position.y - 130.0
	)
	var margem_grito = caixa_grito.get_node_or_null("MarginContainer/MarginContainer")
	if margem_grito:
		margem_grito.add_theme_constant_override("margin_left", 25)
	var label_grito = caixa_grito.get_node_or_null("MarginContainer/MarginContainer/Label")
	if label_grito:
		label_grito.add_theme_font_size_override("font_size", 22)

	const TEXTO_GRITO := "ESPERA AÍ!!!"
	caixa_grito.mostrar(TEXTO_GRITO)

	# Espera o texto terminar de digitar (mesma velocidade do dialog_box.gd) e
	# mais um tempo parado, depois some sozinho e prossegue a cutscene.
	var duracao_texto = max(0.3, TEXTO_GRITO.length() / 25.0)
	await get_tree().create_timer(duracao_texto + espera_apos_texto).timeout
	_prosseguir_apos_grito()


func _prosseguir_apos_grito() -> void:
	var sprite_player = player_ref.get_node_or_null("AnimatedSprite2D")

	caixa_grito.esconder()
	caixa_grito.queue_free()
	caixa_grito = null

	# Cria o cientista só como "ator" (sem o script de interação dele)
	cientista_ator = CIENTISTA_SCENE.instantiate()
	cientista_ator.set_script(null)
	get_parent().add_child(cientista_ator)

	# Sem o script de interação, a exceção de colisão com o player nunca é
	# registrada sozinha (era feita no _ready do cientista.gd) — sem isso o
	# corpo físico dele empurra/trava o player. Registra manualmente.
	cientista_ator.add_collision_exception_with(player_ref)

	var exclamacao = cientista_ator.get_node_or_null("ExclamacaoAnimada")
	if exclamacao:
		exclamacao.queue_free()

	# Aparece à esquerda do player, caindo de cima até o chão
	var destino_x = player_ref.global_position.x - distancia_parada
	var chao_y = player_ref.global_position.y - 21.0
	var spawn_x = player_ref.global_position.x - distancia_spawn
	cientista_ator.global_position = Vector2(spawn_x, chao_y - altura_queda)

	# Vira o cientista na direção do player (ele vem da esquerda, então olha pra direita)
	var sprite_cientista = cientista_ator.get_node_or_null("AnimatedSprite2D")
	if sprite_cientista:
		sprite_cientista.flip_h = true

	# Player olha para o cientista chegando (que vem da esquerda)
	if sprite_player:
		sprite_player.flip_h = true

	# Queda com aceleração (efeito de gravidade) até o chão
	var tween_queda = create_tween()
	tween_queda.tween_property(cientista_ator, "global_position:y", chao_y, duracao_queda).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween_queda.finished

	# Depois de cair, anda até parar perto do player
	# E vem andando de verdade: o desenho dele olha para a esquerda e aqui
	# ele anda para a direita, então o flip_h ligado acima já o deixa virado
	# certo. O speed_scale acompanha a velocidade para os pés não patinarem.
	if sprite_cientista:
		sprite_cientista.speed_scale = clampf(velocidade / VELOCIDADE_NATURAL, 0.5, 2.0)
		sprite_cientista.play("andando")

	var duracao = abs(cientista_ator.global_position.x - destino_x) / velocidade
	var tween = create_tween()
	tween.tween_property(cientista_ator, "global_position:x", destino_x, duracao)
	tween.finished.connect(_iniciar_dialogo)


func _iniciar_dialogo() -> void:
	# Chegou: para de andar e volta para a pose parada, ainda virado para ela.
	if cientista_ator:
		var sprite_chegada = cientista_ator.get_node_or_null("AnimatedSprite2D")
		if sprite_chegada:
			sprite_chegada.speed_scale = 1.0
			sprite_chegada.play("default")

	# Aproxima a câmera dos personagens para o momento da revelação
	if player_ref:
		var camera = player_ref.get_viewport().get_camera_2d()
		if camera and camera.has_method("aproximar"):
			camera.aproximar(cientista_ator)

	Dialogic.timeline_ended.connect(_on_dialogo_terminou, CONNECT_ONE_SHOT)
	Dialogic.start(TIMELINE_FINAL)


func _on_dialogo_terminou() -> void:
	# "Bem-vinda ao laboratório!" — e ela vai mesmo. Daqui em diante o world1 e
	# o laboratório viram um mapa só, ligado pelos dois lasers (PassagemLaser).
	EstadoMundo.registrar_revelacao()

	# Volta a câmera ao normal antes de apagar a tela
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("restaurar"):
		camera.restaurar()
	await get_tree().create_timer(espera_troca_de_cena).timeout

	# O laboratório abre com os dois lado a lado, exatamente como pararam aqui:
	# a conversa não terminou, só mudou de lugar.
	EstadoMundo.chegando_da_revelacao = true
	await FadeTela.trocar_cena(self, EstadoMundo.CENA_WORLD2, duracao_fade_laboratorio)
