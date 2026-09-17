extends Area2D

# --- PORTA DO SIMULADOR (estilo Guacamelee) ---
# O player entra na Area2D, aperta W: a porta abre, ele entra (ficando ATRÁS
# dela enquanto fecha) e, com a porta já fechada, ou:
#   - vai para outra cena, se "cena_destino" estiver preenchido; ou
#   - é teleportado para o ponto onde nasce na cena — o mesmo lugar em que ele
#     reaparece quando morre.
#
# A porta também funciona ao contrário: a porta da cena de destino marcada com
# "recebe_chegada" toca a mesma sequência de trás pra frente — ela abre, o
# player aparece no vão, desce e sai andando, e a porta fecha atrás dele.
#
# Cenas prontas com esta estrutura:
#   scenes/porta_simulador.tscn                        (sprites porta1..porta24)
#   scenes/fases/componentes/porta_ala_eletrolise.tscn (sprites do spritesheet
#     "porta ala de eletrolise.png": 12 quadros de 148x134; abrindo = 0->11,
#     fechando = os mesmos 12 ao contrário)
#
# Estrutura na cena:
#   PortaSimulador (Area2D, este script)
#   ├── CollisionShape2D   <- zona onde o W funciona
#   ├── SpritePorta        <- AnimatedSprite2D com "fechada"/"abrindo"/"fechando"
#   └── PontoDeSaida       <- Marker2D: onde fica a ORIGEM do player parado no vão

## Marcado por quem trocou de cena por uma porta. A porta da cena nova que
## estiver com "recebe_chegada" consome isso e faz a sequência de saída.
## Static var sobrevive à troca de cena.
static var chegando_por_porta: bool = false

## Tag da porta que deve receber o player na cena nova (o "tag_destino" de quem
## acabou de ser usada). Vazio quando a cena de destino só tem uma porta de
## chegada — é o caso das portas antigas, que nem preenchem tag nenhuma.
static var tag_chegada: String = ""

@export_group("Destino")
## Cena para onde a porta leva. Se ficar vazio, a porta continua só
## teleportando o player para o ponto de nascimento da própria cena.
@export_file("*.tscn") var cena_destino: String = ""
## Nome da porta da cena de destino que deve receber o player (o "tag_aqui"
## dela). Só é necessário quando a cena de destino tem MAIS DE UMA porta com
## "recebe_chegada" — aí a tag diz qual delas é a certa.
@export var tag_destino: String = ""
## Quanto tempo a tela leva para apagar antes de carregar a cena de destino.
@export var duracao_fade_cena: float = 0.7

@export_group("Chegada")
## True na porta que RECEBE o player vindo de outra cena.
@export var recebe_chegada: bool = false
## Apelido desta porta, comparado com o "tag_destino" de quem manda o player
## para cá. Deixe vazio na cena que tem só uma porta de chegada.
@export var tag_aqui: String = ""
## Se false, o W não faz nada e os indicadores nunca aparecem — a porta vira
## só cenário de onde o player sai.
@export var interativa: bool = true
## Para que lado o player anda ao sair da porta (1 = direita, -1 = esquerda).
@export var direcao_saida: float = 1.0
## Quantos pixels ele anda para longe da porta depois de sair do vão.
@export var distancia_saida: float = 0.0
## Respiro no silêncio, com a tela já clara, antes da porta começar a abrir.
@export var pausa_antes_de_sair: float = 0.25
## Quanto tempo a tela leva para clarear quando o player chega por esta porta.
@export var duracao_clarear_chegada: float = 0.7

@export_group("Movimento")
# Velocidade (px/s) com que o player corre até se alinhar com o centro da
# porta. É velocidade fixa (não tempo fixo), então perto ou longe ele sempre
# se move na mesma velocidade.
@export var velocidade_alinhamento: float = 260.0
# Tempo que o player leva correndo pra dentro do vão (com a porta já aberta)
@export var duracao_entrada: float = 0.4
# Quantos pixels o player sobe enquanto corre pra dentro do vão (só um pouco)
@export var subida_ao_entrar: float = 14.0
@export var z_index_porta_normal: int = 1
# Enquanto durar a sequência (e o player ainda estiver visível), ele fica
# nesse z_index — alto o bastante pra não ficar atrás de cenário/decoração
# no caminho até a porta. Ele só "desaparece" mesmo quando fica invisível.
@export var z_index_player_durante_sequencia: int = 20
# Duração do fade (fica transparente aos poucos) ao entrar na escuridão da porta
@export var duracao_fade_saida: float = 0.25
# Respiro extra depois que o player já entrou (some), antes da porta começar a fechar
@export var pausa_antes_de_fechar: float = 0.0
# Respiro entre a porta fechar e o teleporte acontecer
@export var pausa_antes_do_teleporte: float = 0.25

var _player: Node2D = null
var _player_dentro: bool = false
var _ocupada: bool = false
var _spawn_global: Vector2 = Vector2.ZERO
var _spawn_registrado: bool = false
# True quando apertou W no ar: assim que o player tocar o chão, usa a porta
var _pedido_pendente: bool = false

@onready var _sprite: AnimatedSprite2D = $SpritePorta
@onready var _som_abrindo: AudioStreamPlayer2D = $SomAbrindo
@onready var _som_fechando: AudioStreamPlayer2D = $SomFechando
@onready var _icone_w: AnimatedSprite2D = $IconeTeclaW
@onready var _direcional_controle: AnimatedSprite2D = $DirecionalControle
# Portas antigas montadas direto na cena podem não ter o marcador; ele só é
# obrigatório em quem recebe o player vindo de outra cena.
@onready var _ponto_saida: Marker2D = get_node_or_null("PontoDeSaida")

func _ready() -> void:
	z_index = z_index_porta_normal
	_sprite.play("fechada")
	# Garante que os indicadores começam escondidos, mesmo se alguém deixou
	# "visible = true" marcado sem querer no editor
	_mostrar_indicadores(false)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	# Guarda a posição inicial do player: é para onde ele volta ao morrer,
	# já que a morte recarrega a cena. Registra já neste frame porque, se ele
	# está chegando por esta porta, ele vai ser movido para o vão logo abaixo.
	_registrar_spawn(false)

	# A tag separa quem recebe quando a cena tem mais de uma porta de chegada:
	# a porta do simulador e a da ala de eletrólise convivem no laboratório.
	if recebe_chegada and chegando_por_porta and tag_chegada == tag_aqui:
		chegando_por_porta = false
		tag_chegada = ""
		_receber_jogador()
		return

	# Morreu antes de qualquer bandeira ou sala: a fase recarrega e ela renasce
	# nesta porta, repetindo a saída como na primeira entrada.
	if recebe_chegada and PontoDeRetorno.renasceu_em(self):
		_renascer_na_porta()
		return

	if not _spawn_registrado:
		await get_tree().process_frame
		_registrar_spawn()

func _registrar_spawn(avisar_se_faltar: bool = true) -> void:
	if _spawn_registrado:
		return
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		if avisar_se_faltar:
			push_warning("PortaSimulador: nenhum nó no grupo 'player' encontrado.")
		return
	_spawn_global = (players[0] as Node2D).global_position
	_spawn_registrado = true

# --- DETECÇÃO DO PLAYER NA ÁREA ---
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player = body
		_player_dentro = true
		_registrar_spawn()
		# Na chegada o player nasce dentro da área, ainda no vão: o "aperte W" só
		# pode aparecer quando ele já estiver com o controle de volta.
		if not _ocupada:
			_mostrar_indicadores(true)

func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player_dentro = false
		_pedido_pendente = false
		_mostrar_indicadores(false)

func _mostrar_indicadores(mostrar: bool) -> void:
	# Porta não-interativa (a que só recebe o player) nunca pisca o "aperte W".
	if not interativa:
		mostrar = false
	_icone_w.visible = mostrar
	_direcional_controle.visible = mostrar
	if mostrar:
		_icone_w.reiniciar()
		for filho in _direcional_controle.get_children():
			if filho.has_method("reiniciar"):
				filho.reiniciar()

func _unhandled_input(event: InputEvent) -> void:
	if not interativa or _ocupada or not _player_dentro or _player == null:
		return
	# Diálogo, popup ou puzzle na tela: o mundo não recebe comando nenhum.
	if Interacao.ocupada():
		return
	# W já está mapeado em "ui_up"; KEY_W fica como reserva
	var apertou_w = event.is_action_pressed("ui_up") \
		or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_W)
	if not apertou_w:
		return
	# No analógico só vale "para cima" de verdade: andar na diagonal perto da
	# porta (agora em velocidade cheia) não pode entrar nela sem querer.
	if event is InputEventJoypadMotion and not Controle.aponta_para_cima():
		return

	# No chão, usa a porta na hora. No ar, guarda o pedido e usa assim que
	# o player pisar no chão (_process fica de olho nisso).
	if _player.has_method("is_on_floor") and not _player.is_on_floor():
		_pedido_pendente = true
	else:
		_usar_porta()

func _process(_delta: float) -> void:
	if not interativa or not _pedido_pendente or _ocupada or not _player_dentro or _player == null:
		return
	if not _player.has_method("is_on_floor") or _player.is_on_floor():
		_pedido_pendente = false
		_usar_porta()

# --- CHEGADA: O PLAYER VEM DE OUTRA CENA POR ESTA PORTA ---
# Chamado ainda no _ready(), antes de qualquer coisa ser desenhada, para o
# player não piscar no ponto de nascimento da cena.
func _receber_jogador() -> void:
	var player := _preparar_player_no_vao()
	if player == null:
		return

	# A entrada é o primeiro ponto de retorno da visita: morrer antes de
	# qualquer bandeira ou sala faz renascer aqui e sair pela porta de novo
	# (ver _renascer_na_porta), e não no lugar onde o player está salvo no
	# arquivo da cena. O ponto é o VÃO, onde a animação de saída começa: assim
	# a fase já renasce com a câmera enquadrada no lugar certo.
	PontoDeRetorno.registrar(self, _posicao_no_vao())

	# A tela chega apagada da cena anterior: clareia mostrando a porta fechada.
	#
	# O encaixe no vão vai como "antes_de_clarear" de propósito: se ele ficasse
	# só no começo de sair_da_porta(), o mundo clarearia com a câmera ainda no
	# spawn da cena (o _ready() da fase acabou de arrastar o player para lá) e
	# só depois ela deslizaria até a porta — o ajuste rápido que se vê no canto
	# do olho. Feito aqui, com a tela ainda toda preta, o mundo já aparece
	# enquadrado na porta.
	await FadeTela.clarear_na_chegada(get_tree().current_scene, duracao_clarear_chegada,
		0.15, _encaixar_no_vao.bind(player))
	await sair_da_porta(player)

# --- RENASCER: MORREU E A FASE RECARREGOU COM O PONTO DE RETORNO NESTA PORTA ---
# Sem cortina (a morte recarrega de estalo): o player some, fica no vão e sai
# pela porta. O PontoDeRetorno.aplicar() da fase já o coloca no vão; o
# sair_da_porta() vai adiado para rodar depois do _ready() da fase inteira.
func _renascer_na_porta() -> void:
	var player := _preparar_player_no_vao()
	if player == null:
		return
	_encaixar_no_vao(player)
	sair_da_porta.call_deferred(player)


## Esconde e trava o player para a sequência de saída. Devolve null (e avisa)
## se falta o player ou o PontoDeSaida.
func _preparar_player_no_vao() -> Node2D:
	# Busca pelo nome também: a porta pode estar ANTES do player na árvore (para
	# desenhar atrás dele), e aí o _ready() dele — que entra no grupo — ainda
	# não rodou.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		player = get_tree().current_scene.get_node_or_null("Player") as Node2D
	if player == null:
		push_warning("PortaSimulador: chegada pedida, mas não há player na cena.")
		return null
	if _ponto_saida == null:
		push_error("PortaSimulador: 'recebe_chegada' ligado numa porta sem o nó PontoDeSaida.")
		return null

	_ocupada = true
	player.visible = false
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	if "pode_se_mover" in player:
		player.pode_se_mover = false
	# Sem isso a gravidade continua correndo e ele "cai" ao reaparecer.
	if "animacao_controlada_externamente" in player:
		player.animacao_controlada_externamente = true
	return player


func _posicao_no_vao() -> Vector2:
	return _ponto_saida.global_position - Vector2(0.0, subida_ao_entrar)

# --- COLOCA O PLAYER (E A CÂMERA, QUE É FILHA DELE) PARADO DENTRO DO VÃO ---
func _encaixar_no_vao(player: Node2D) -> void:
	if not is_instance_valid(player) or _ponto_saida == null:
		return
	player.global_position = _posicao_no_vao()
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	# A câmera tem position_smoothing ligado: sem o encaixe ela sai de onde
	# estava e vai andando até aqui, em vez de já nascer no lugar.
	CameraJogador.encaixar(player)

# --- SEQUÊNCIA INVERSA: ABRE -> APARECE NO VÃO -> DESCE -> SAI ANDANDO -> FECHA ---
func sair_da_porta(player: Node2D) -> void:
	_ocupada = true
	_player = player
	_mostrar_indicadores(false)

	var anim_sprite: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")
	var z_index_original_player: int = player.z_index

	# 1) Ele começa invisível, encaixado no vão — exatamente onde some ao entrar.
	# Na chegada de outra cena ele já está aqui desde antes da tela clarear
	# (ver _receber_jogador); a chamada abaixo é o que garante o encaixe quando
	# sair_da_porta() é usada sozinha.
	player.z_index = z_index_player_durante_sequencia
	_encaixar_no_vao(player)
	player.modulate.a = 0.0
	player.visible = true
	if anim_sprite:
		anim_sprite.flip_h = direcao_saida < 0.0
		if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("idle"):
			anim_sprite.play("idle")

	if pausa_antes_de_sair > 0.0:
		await get_tree().create_timer(pausa_antes_de_sair).timeout

	# 2) Porta abrindo (porta1 -> porta12)
	_sprite.play("abrindo")
	_som_abrindo.play()
	await _sprite.animation_finished

	# 3) Ele aparece em fade dentro do vão iluminado
	var tween_fade := create_tween()
	tween_fade.tween_property(player, "modulate:a", 1.0, duracao_fade_saida)
	await tween_fade.finished

	# 4) Desce do vão e pisa no chão da cena
	await _mover_player(_ponto_saida.global_position, duracao_entrada, anim_sprite)

	# 5) A porta fecha atrás dele. Com "distancia_saida" em 0 ele apenas fica
	# parado na frente da porta; com um valor maior, ele ainda anda para longe
	# enquanto ela fecha.
	_sprite.play("fechando")
	_som_fechando.play(0.46)

	if distancia_saida > 0.0:
		var destino := _ponto_saida.global_position + Vector2(direcao_saida * distancia_saida, 0.0)
		var duracao := distancia_saida / velocidade_alinhamento if velocidade_alinhamento > 0.0 else 0.0
		await _mover_player(destino, duracao, anim_sprite)

	# Ele já chegou onde ia: para de correr agora, e não só quando a porta
	# terminar de fechar — senão fica "correndo parado" esse tempo todo.
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("idle"):
		anim_sprite.play("idle")

	if _sprite.animation == "fechando" and _sprite.is_playing():
		await _sprite.animation_finished
	_sprite.play("fechada")

	# 6) Devolve o controle
	player.z_index = z_index_original_player
	player.modulate.a = 1.0
	if "animacao_controlada_externamente" in player:
		player.animacao_controlada_externamente = false
	if "pode_se_mover" in player:
		player.pode_se_mover = true

	z_index = z_index_porta_normal
	_ocupada = false

	# Ele terminou de sair em cima da própria porta: se ela também leva a algum
	# lugar, o "aperte W" aparece agora, para poder voltar por onde veio.
	_mostrar_indicadores(_player_dentro)

# --- SEQUÊNCIA COMPLETA: ALINHA -> ABRE -> ENTRA (sobe um pouco) -> FECHA -> TELEPORTA ---
func _usar_porta() -> void:
	if _ocupada or not is_instance_valid(_player):
		return
	_ocupada = true
	_mostrar_indicadores(false)

	# Trava o player durante toda a animação
	if "pode_se_mover" in _player:
		_player.pode_se_mover = false
	if "velocity" in _player:
		_player.velocity = Vector2.ZERO
	# Sem isso, o _physics_process do player força "idle" todo frame enquanto
	# pode_se_mover é false, e a animação de corrida nunca aparece.
	if "animacao_controlada_externamente" in _player:
		_player.animacao_controlada_externamente = true

	# Enquanto estiver visível e se movendo até a porta, ele fica acima de
	# qualquer cenário/decoração — só deve "sumir" atrás da própria porta,
	# nunca atrás do resto do cenário.
	var z_index_original_player: int = _player.z_index
	_player.z_index = z_index_player_durante_sequencia

	var anim_sprite: AnimatedSprite2D = _player.get_node_or_null("AnimatedSprite2D")

	# 1) Antes de tudo: player corre até ficar exatamente alinhado ao centro da
	# porta, sempre na mesma velocidade (o tempo varia com a distância, não o contrário)
	var alvo_alinhamento := Vector2(_sprite.global_position.x, _player.global_position.y)
	var distancia_alinhamento := absf(alvo_alinhamento.x - _player.global_position.x)
	var duracao_alinhamento := distancia_alinhamento / velocidade_alinhamento if velocidade_alinhamento > 0.0 else 0.0
	await _mover_player(alvo_alinhamento, duracao_alinhamento, anim_sprite)

	# Player parou: volta pro "idle" enquanto a porta abre (senão fica "correndo parado")
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("idle"):
		anim_sprite.play("idle")

	# 2) Porta abrindo (porta1 -> porta12)
	_sprite.play("abrindo")
	_som_abrindo.play()
	await _sprite.animation_finished

	# 3) Com a porta já totalmente aberta, o player corre pra dentro do vão
	# (sobe um pouco) e só desaparece quando termina de entrar
	var destino_entrada := _player.global_position + Vector2(0, -subida_ao_entrar)
	await _mover_player(destino_entrada, duracao_entrada, anim_sprite)

	# Some em fade (a animação de corrida continua rodando enquanto ela
	# desaparece, em vez de congelar num frame só)
	var tween_fade := create_tween()
	tween_fade.tween_property(_player, "modulate:a", 0.0, duracao_fade_saida)
	await tween_fade.finished
	_player.visible = false
	if anim_sprite:
		anim_sprite.stop()

	if pausa_antes_de_fechar > 0.0:
		await get_tree().create_timer(pausa_antes_de_fechar).timeout

	# 4) Só agora, com o player já dentro, a porta fecha
	_sprite.play("fechando")
	_som_fechando.play(0.46)
	await _sprite.animation_finished

	if pausa_antes_do_teleporte > 0.0:
		await get_tree().create_timer(pausa_antes_do_teleporte).timeout

	# 5) A porta leva para outra cena: a viagem acaba aqui. A tela apaga com a
	# porta já fechada e o jogo carrega o destino (que clareia sozinho).
	if not cena_destino.is_empty():
		chegando_por_porta = true
		tag_chegada = tag_destino
		await FadeTela.trocar_cena(self, cena_destino, duracao_fade_cena)
		return

	# 6) Sem destino: teleporte para o ponto de nascimento do player
	if is_instance_valid(_player):
		if _spawn_registrado:
			_player.global_position = _spawn_global
		if "velocity" in _player:
			_player.velocity = Vector2.ZERO
		_player.z_index = z_index_original_player
		_player.modulate.a = 1.0
		_player.visible = true
		if "animacao_controlada_externamente" in _player:
			_player.animacao_controlada_externamente = false
		if "pode_se_mover" in _player:
			_player.pode_se_mover = true

	# 7) Porta volta ao estado normal (porta1, fechada)
	z_index = z_index_porta_normal
	_sprite.play("fechada")
	_player_dentro = false
	_ocupada = false

# --- ANDA O PLAYER ATÉ "destino" TOCANDO A ANIMAÇÃO DE CORRIDA ---
func _mover_player(destino: Vector2, duracao: float, anim_sprite: AnimatedSprite2D) -> void:
	if not is_instance_valid(_player):
		return

	if anim_sprite:
		var diferenca_x := destino.x - _player.global_position.x
		if diferenca_x != 0.0:
			anim_sprite.flip_h = diferenca_x < 0.0
		if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("run"):
			anim_sprite.play("run")

	var tween := create_tween()
	tween.tween_property(_player, "global_position", destino, duracao)
	await tween.finished

# --- DURAÇÃO REAL (em segundos) DE UMA ANIMAÇÃO DO SPRITE DA PORTA ---
func _duracao_animacao(nome: String) -> float:
	if not _sprite.sprite_frames or not _sprite.sprite_frames.has_animation(nome):
		return 0.0
	var velocidade := _sprite.sprite_frames.get_animation_speed(nome)
	if velocidade <= 0.0:
		return 0.0
	return _sprite.sprite_frames.get_frame_count(nome) / velocidade
