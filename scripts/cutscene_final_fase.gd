extends Area2D

# Cutscene da revelação, no laboratório: na primeira vez que a Cacau entra
# (vindo do world1 pelo laser) e passa por esta área, o cientista
# ("Desconhecido") grita "ESPERA AÍ!!!", chega andando até ela e revela que é
# o Dr. Chico. Depois roda a timeline do Dialogic.
#
# Quem chega é o próprio Dr. Chico que mora no laboratório (o nó apontado em
# "cientista"): até aqui ele fica fora do mapa (ver apos_revelacao no
# cientista.gd), e quando a conversa acaba ele fica na sala como o NPC dela.
#
# No meio da conversa, quando ele começa a falar do CHONPS, os dois vão até o
# painel principal: ele na frente, ela atrás. Lá ele mostra o receptor onde as
# amostras são entregues e joga dentro dele os cilindros de H e O do prólogo —
# as duas primeiras letras acendem na frente dela. Ele termina a fala ao lado
# do painel e fica patrulhando ali. A timeline chama esses dois momentos com
# eventos "do" (DialogicBridge.levar_ao_painel / entregar_h_e_o), e o Dialogic
# espera cada um acabar antes da próxima fala.
#
# O ponto em que o Dr. Chico para no painel é a própria posição dele na cena:
# arraste o nó Cientista para mudar onde ele fica (e patrulha) depois.

signal terminou

const TIMELINE_FINAL = "cientista_final_fase"
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
## Onde o balão do "ESPERA AÍ!!!" aparece: x a partir do ponto em que o
## cientista vai surgir, y a partir da altura da personagem.
@export var posicao_grito : Vector2 = Vector2(140.0, -130.0)
## O Dr. Chico do laboratório, que entra em cena aqui.
@export var cientista : NodePath

@export_group("Ida ao painel")
## O receptor de amostras, embaixo do painel CHONPS: é para lá que os dois vão.
@export var receptor : NodePath
## Velocidade da caminhada até o painel (px/s).
@export var velocidade_ida : float = 210.0
## Quanto tempo ela espera antes de ir atrás dele: ele sai na frente.
@export var atraso_cacau : float = 0.9
## Onde ela para, contado do receptor (negativo = à esquerda dele).
@export var parada_cacau : float = -78.0
## Zoom da câmera enquadrando o painel, o receptor e os dois.
@export var zoom_no_painel : float = 2.5
## Ponto que a câmera enquadra, contado do receptor (sobe para o painel caber).
@export var enquadramento_painel : Vector2 = Vector2(0.0, -108.0)
## Respiro entre uma amostra e outra quando ele joga o H e o O.
@export var pausa_entre_amostras : float = 0.35
@export_group("")

var ja_aconteceu : bool = false
var player_ref : Node = null
var cientista_ator : Node2D = null
var caixa_grito : Node2D = null
# Onde o Dr. Chico foi posto na cena: é onde ele para ao chegar no painel.
var _posto_cientista : Vector2 = Vector2.ZERO


func _ready() -> void:
	# Os eventos "do" da timeline chegam por aqui (ver dialogic_bridge.gd).
	add_to_group("cutscene_revelacao")

	# Lido antes de a cutscene mexer nele: é o lugar dele na cena.
	var no_cientista := get_node_or_null(cientista) as Node2D
	if no_cientista:
		_posto_cientista = no_cientista.global_position

	# Voltando ao laboratório depois, a revelação já aconteceu: a cutscene não
	# pode acontecer de novo.
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
		player_ref.global_position.x - distancia_spawn + posicao_grito.x,
		player_ref.global_position.y + posicao_grito.y
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

	# O Dr. Chico da sala entra em cena. Até o fim da conversa ele fica sem
	# física nem interação (o cientista.gd o deixou assim), então quem o move
	# são só os tweens daqui.
	cientista_ator = get_node_or_null(cientista) as Node2D
	if cientista_ator == null:
		push_error("CutsceneFinalFase: aponte o export 'cientista' para o Dr. Chico da cena.")
		player_ref.pode_se_mover = true
		return
	cientista_ator.entrar_em_cena()

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


# ─────────────────────────────────────────────
#  No meio da conversa (eventos "do" da timeline)
# ─────────────────────────────────────────────

## "Vem comigo!": ele sai andando na frente até o posto dele, ao lado do
## painel, e ela vai atrás até parar do outro lado do receptor. Chegando, a
## câmera abre no painel e os dois se viram um para o outro.
func levar_ao_painel() -> void:
	var caixa := get_node_or_null(receptor) as Node2D
	if caixa == null or cientista_ator == null or player_ref == null:
		push_error("CutsceneFinalFase: aponte o export 'receptor' para o ReceptorChonps da cena.")
		return

	# A caminhada é sem caixa de fala: só os dois atravessando o laboratório.
	await Dialogic.Text.hide_textbox()
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("restaurar"):
		camera.restaurar()

	var sprite_cientista := cientista_ator.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var sprite_player := player_ref.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var destino_dele := _posto_cientista.x
	var destino_dela := caixa.global_position.x + parada_cacau
	var tempo_dele := absf(destino_dele - cientista_ator.global_position.x) / velocidade_ida
	var tempo_dela := absf(destino_dela - player_ref.global_position.x) / velocidade_ida

	# Durante a caminhada quem move a Cacau é o tween: a física dela fica
	# parada (senão ela força o "idle" por cima da corrida).
	player_ref.animacao_controlada_externamente = true
	player_ref.velocity = Vector2.ZERO

	var ida := create_tween().set_parallel(true)
	ida.tween_callback(_andar.bind(sprite_cientista, destino_dele - cientista_ator.global_position.x,
		&"andando", VELOCIDADE_NATURAL, true))
	ida.tween_property(cientista_ator, "global_position:x", destino_dele, tempo_dele)
	ida.tween_callback(_parar.bind(sprite_cientista, &"default")).set_delay(tempo_dele)
	ida.tween_callback(_andar.bind(sprite_player, destino_dela - player_ref.global_position.x,
		&"run", player_ref.speed, false)).set_delay(atraso_cacau)
	ida.tween_property(player_ref, "global_position:x", destino_dela, tempo_dela).set_delay(atraso_cacau)
	ida.tween_callback(_parar.bind(sprite_player, &"idle")).set_delay(atraso_cacau + tempo_dela)
	await ida.finished

	player_ref.animacao_controlada_externamente = false
	player_ref.velocity = Vector2.ZERO

	# Um de frente para o outro, com o receptor entre os dois.
	if sprite_cientista:
		sprite_cientista.flip_h = player_ref.global_position.x > cientista_ator.global_position.x
	if sprite_player:
		sprite_player.flip_h = cientista_ator.global_position.x < player_ref.global_position.x

	if camera and camera.has_method("enquadrar"):
		camera.enquadrar(caixa.global_position + enquadramento_painel, zoom_no_painel)
		await get_tree().create_timer(0.8).timeout


## "Olha só!": ele joga no receptor os cilindros de H e O que sobraram da
## máquina do laser, um de cada vez, e as duas letras acendem no painel.
func entregar_h_e_o() -> void:
	var caixa := get_node_or_null(receptor) as ReceptorChonps
	if caixa == null or cientista_ator == null:
		Progresso.dar_celula("H")
		Progresso.dar_celula("O")
		return

	await Dialogic.Text.hide_textbox()

	var sprite_cientista := cientista_ator.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var lado := 1.0 if caixa.global_position.x > cientista_ator.global_position.x else -1.0
	if sprite_cientista:
		# O desenho dele olha para a esquerda: flip_h = virado para a direita.
		sprite_cientista.flip_h = lado > 0.0

	for letra in ["H", "O"]:
		await _gesto_de_arremesso(sprite_cientista)
		var mao := cientista_ator.global_position + Vector2(14.0 * lado, -22.0)
		await caixa.receber(letra, mao)
		await get_tree().create_timer(pausa_entre_amostras).timeout

	# Volta a olhar para ela para continuar a conversa.
	if sprite_cientista and player_ref:
		sprite_cientista.flip_h = player_ref.global_position.x > cientista_ator.global_position.x


## Começa a animação de andar virada para o lado do passo, com os pés no ritmo
## da velocidade (sem patinar). "desenho_olha_esquerda" é o caso do Dr. Chico,
## cujo desenho original olha para a esquerda (o da Cacau olha para a direita).
func _andar(sprite: AnimatedSprite2D, passo: float, animacao: StringName,
		velocidade_natural: float, desenho_olha_esquerda: bool) -> void:
	if sprite == null:
		return
	var indo_para_direita := passo > 0.0
	sprite.flip_h = indo_para_direita if desenho_olha_esquerda else not indo_para_direita
	sprite.speed_scale = clampf(velocidade_ida / maxf(velocidade_natural, 1.0), 0.5, 2.0)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(animacao):
		sprite.play(animacao)


func _parar(sprite: AnimatedSprite2D, animacao: StringName) -> void:
	if sprite == null:
		return
	sprite.speed_scale = 1.0
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(animacao):
		sprite.play(animacao)


## O "impulso" de quem joga: encolhe um pouco e estica para cima, rápido. É o
## que faz a amostra parecer sair da mão dele, e não surgir do nada.
func _gesto_de_arremesso(sprite: AnimatedSprite2D) -> void:
	if sprite == null:
		return
	var base := sprite.scale
	var gesto := create_tween()
	gesto.tween_property(sprite, "scale", Vector2(base.x * 1.08, base.y * 0.9), 0.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	gesto.tween_property(sprite, "scale", Vector2(base.x * 0.96, base.y * 1.06), 0.08)
	gesto.tween_property(sprite, "scale", base, 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.14).timeout


func _on_dialogo_terminou() -> void:
	# "Bem-vinda à seleção!" — daqui em diante o Dr. Chico é o do laboratório.
	EstadoMundo.registrar_revelacao()

	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("restaurar"):
		camera.restaurar()

	if cientista_ator and cientista_ator.has_method("assumir_o_posto"):
		cientista_ator.assumir_o_posto()
	if player_ref:
		player_ref.pode_se_mover = true

	terminou.emit()
