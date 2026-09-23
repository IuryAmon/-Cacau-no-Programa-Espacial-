extends CharacterBody2D

signal health_changed(new_health)

@export var speed: float = 350.0
## Desaceleração (px/s²) aplicada só à velocidade que passa de "speed" —
## a sobra de inércia com que o dash termina. Ver ferramentas_player.gd.
@export var atrito_excesso: float = 1400.0
@export var jump_velocity: float = -475.0
@export var max_health: int = 3

# --- FORÇA DO RECUO (KNOCKBACK) ---
@export var knockback_forca_x: float = 480.0   # Força do empurrão horizontal
@export var knockback_forca_y: float = -320.0  # Salto vertical ao ser atingido
var esta_no_knockback: bool = false

# --- VARIÁVEIS DE ÁUDIO DO PLAYER ---
@export var som_pulo_arquivo: AudioStream
@export var som_dano_arquivo: AudioStream
@export var som_macarico_arquivo: AudioStream

# --- VARIÁVEIS DO PULO DUPLO ---
@export var max_jumps: int = 5
var jumps_left: int = 5

# --- VARIÁVEIS DE OTIMIZAÇÃO (COIOTE E BUFFER) ---
@export var coyote_duration: float = 0.15     
@export var jump_buffer_duration: float = 0.15 

# --- VARIÁVEIS DE INVENCIBILIDADE ---
@export var invencibilidade_duracao: float = 1.0
var esta_invencivel: bool = false

# Invulnerabilidade do DASH da mochila de N₂ — flag PRÓPRIA, separada de
# esta_invencivel, porque as duas janelas têm donos diferentes: esta_invencivel
# é o autoload de "acabei de apanhar" (some sozinha num timer e faz a
# personagem piscar); esta_invencivel_dash é ligada/desligada pelo dash em
# ferramentas_player.gd. Se fossem a mesma variável, um dash dado DENTRO da
# janela de invencibilidade pós-hit desligaria essa janela cedo demais ao
# terminar. As duas se somam em OU nas checagens de dano abaixo.
var esta_invencivel_dash: bool = false

# --- DEBUG: TECLA K (coleta automática dos cilindros H2/O2 para testar o puzzle) ---
var _tecla_k_estava_pressionada: bool = false

# --- CUTSCENE CONTEMPLATIVA DO FOGUETE (disparada pela Area2D "ColisaoCenaFoguete") ---
const TIMELINE_FOGUETE := "cacau_ve_foguete"
var _fala_foguete_feita: bool = false
var _foguete_destino_x: float = 0.0

# --- MORTE DESPEDAÇADA (SERRA E ESPINHOS DE LASER) ---
#
# As armadilhas de corte não matam como o resto do jogo. Antes de aplicar o
# golpe elas chamam "marcar_morte_de_corte()" com a posição da lâmina, e a
# morte lá embaixo troca o "some e reinicia" pelo despedaçamento: a personagem
# vira cacos do próprio sprite e o sangue mancha o chão (ver
# scripts/fx/morte_despedacada.gd). Só isso muda — vida, HUD e reinício da fase
# continuam iguais.
#
# A marca vale para UM golpe: quem morre afogado/caindo depois disso morre do
# jeito normal.
var _morte_de_corte: bool = false
var _lamina_que_matou: Vector2 = Vector2.ZERO
## Tempo entre o talho e o reinício da fase: o bastante para os cacos caírem,
## quicarem e a poça se formar embaixo do corpo.
const ESPERA_DA_MORTE_DE_CORTE := 1.9

# --- VARIÁVEIS DE DANO DE QUEDA ---
@export var velocidade_limite_queda: float = 1200.0 
@export var dano_por_queda: int = 1                
var maior_velocidade_queda: float = 0.0          

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var estava_no_chao: bool = false
## Para que lado o controle manda andar neste quadro: -1, 0 ou 1 (ver
## Controle.lado_de_andar). Guarda o valor do quadro anterior, que é o que dá
## folga nas divisas do analógico.
var _lado_de_andar: float = 0.0

var current_health: int = 3
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var global_dialog_box = null 

# Variável de controle para paralisar o jogador (Usada no Diálogo e agora no Stun de Dano!)
var pode_se_mover : bool = true

# Quando true, algo externo (ex: a porta do simulador) está tocando a animação
# do player manualmente — a trava de movimento não deve forçar "idle" nesse caso.
var animacao_controlada_externamente : bool = false

# Quando true, uma ferramenta anexada (ex: o dash da mochila de N₂) está
# dirigindo a velocity — o input normal e a gravidade ficam suspensos até ela
# soltar. Ver scripts/ferramentas/ferramentas_player.gd.
var ferramenta_controla_movimento : bool = false

# --- POSE DO MAÇARICO OXÍDRICO ---
# Cortar uma chapa soldada, derreter a porta de metal ou acender a retorta tem
# animação própria. Enquanto ela roda, a personagem fica parada mas a física
# continua normal (ela não flutua se estiver caindo) — só o "volta pro idle" da
# trava de movimento é que fica suspenso, por isso a flag separada.
#
# NÃO EXISTE BOTÃO SOLTO DE MAÇARICO. A chama não acende no ar: ela só aparece
# encostada no que precisa ser cortado, e quem a acende é o próprio obstáculo
# (chapa soldada, porta de metal, retorta) quando a Cacau aperta o E ali.
const ANIM_MACARICO := "usando_macarico"
var usando_ferramenta : bool = false
# Duas coisas acesas ao mesmo tempo não podem desligar a pose uma da outra.
var _travas_macarico : int = 0
var _audio_macarico : AudioStreamPlayer = null
# A rebobinagem (guardar o maçarico) espera a animação terminar. Se a pose
# recomeçar no meio dela, a espera velha não pode mais mexer na animação nova
# — cada pose ganha um número e a espera só age se o dela ainda for o atual.
var _macarico_geracao : int = 0
## Ponta do maçarico em coordenadas do Player, com a personagem virada para a
## direita — é daqui que sai a luz azul. Espelha sozinho quando ela vira.
@export var luz_macarico_offset := Vector2(54, -21)
@export var luz_macarico_energia := 1.6

# --- POSE DO ARREMESSO DO BUMERANGUE ---
# Os 7 quadros do gesto de arremessar. Ao contrário da pose do maçarico, esta
# NÃO trava o movimento: arremessar em corrida é a mecânica (o voo herda o
# momento da personagem), então ela continua andando enquanto o braço faz o
# gesto — o gesto toma conta só do sprite.
#
# A pose é contada em TEMPO, não em "await animation_finished": qualquer coisa
# que troque a animação por baixo (knockback, dash, morte) deixaria uma espera
# pendurada segurando a flag para sempre. Com um contador, o pior caso é o
# gesto acabar sozinho um quadro depois.
const ANIM_BUMERANGUE := "jogando_bumerangue"
var _arremesso_restante : float = 0.0
# Estado de chão em que o gesto começou: sair do chão (ou pisar nele) no meio
# encerra a pose — pulo e queda mandam mais na leitura do que o braço.
var _arremesso_no_chao : bool = false

@onready var _animated_sprite = $AnimatedSprite2D
@onready var _luz_macarico: PointLight2D = get_node_or_null("LuzMacarico")
@onready var _exclamacao_foguete = $ExclamacaoFoguete
@onready var _coracao_foguete = $CoracaoFoguete

func _ready() -> void:
	current_health = max_health
	add_to_group("player")
	print("DIAGNÓSTICO [Player]: Iniciado.")
	
	# 1. Conexão do HUD de vida
	var hud = find_child("HealthHUD", true, false)
	if hud and hud.has_method("update_health"):
		hud.definir_vida_maxima(max_health)
		health_changed.connect(hud.update_health)
	
	# 2. Busca a caixa de diálogo
	await get_tree().process_frame
	global_dialog_box = get_tree().root.find_child("DialogBox", true, false)
	
	if global_dialog_box:
		print("DIAGNÓSTICO [Player]: Caixa encontrada com sucesso!")
	else:
		print("ERRO [Player]: Não achei 'DialogBox'.")

	health_changed.emit(current_health)

func _physics_process(delta: float) -> void:
	# --- TRAVA DE SEGURANÇA 1 ---
	if not is_inside_tree() or is_queued_for_deletion() or current_health <= 0:
		return

	# O gesto do arremesso escoa aqui em cima, antes de qualquer return: se
	# ficasse lá embaixo, um diálogo, um dash ou uma cena scriptada abrindo no
	# meio congelariam a pose e ela ainda estaria segurando a animação normal
	# quando o controle voltasse.
	if _arremesso_restante > 0.0:
		_arremesso_restante = maxf(_arremesso_restante - delta, 0.0)

	# Enquanto algo externo (ex: a porta) está movendo o player na mão,
	# a física normal (gravidade, chão, colisão) fica totalmente pausada —
	# senão a gravidade acumula escondida e ele "cai" ao reaparecer.
	if animacao_controlada_externamente:
		return

	if ferramenta_controla_movimento:
		move_and_slide()
		return

	if position.y > limite_queda:
		current_health = 0
		velocity = Vector2.ZERO
		pode_se_mover = false
		health_changed.emit(current_health)
		call_deferred("_reiniciar_cena_seguro")
		return

	_atualizar_luz_macarico()

	# --- APLICAÇÃO DA GRAVIDADE ---
	if is_on_floor():
		if maior_velocidade_queda > velocidade_limite_queda:
			print("DIAGNÓSTICO [Queda]: Impacto forte detectado! Velocidade: ", maior_velocidade_queda)
			take_damage(dano_por_queda, Vector2.ZERO) 
			
			if current_health <= 0:
				velocity = Vector2.ZERO
				return
		
		maior_velocidade_queda = 0.0
		coyote_timer = coyote_duration 
		jumps_left = max_jumps         
		estava_no_chao = true
		
		if esta_no_knockback:
			esta_no_knockback = false
	else:
		coyote_timer -= delta         
		
		if estava_no_chao and coyote_timer <= 0.0:
			if jumps_left == max_jumps:
				jumps_left = max_jumps - 1
			estava_no_chao = false

		velocity.y += gravity * delta
		
		if velocity.y > 0.0 and velocity.y > maior_velocidade_queda:
			maior_velocidade_queda = velocity.y

	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta


	# --- TRAVA DE CONTROLE (CAIXAS DE DIÁLOGO OU STUN DE DANO) ---
	if not pode_se_mover:
		if esta_no_knockback:
			velocity.x = move_toward(velocity.x, 0, speed * delta * 2.0)
		else:
			velocity.x = 0
			
		move_and_slide()
		_verificar_colisoes_estaticas()
		
		if _animated_sprite and not esta_no_knockback \
				and not animacao_controlada_externamente and not usando_ferramenta \
				and _arremesso_restante <= 0.0:
			_animated_sprite.play("idle")
		return

	# --- CONTROLE DE INPUTS NORMAL ---

	# O ✕ (ou ESPAÇO) que acabou de passar a última fala ou de fechar um puzzle
	# pertence àquela tela, não ao mundo: sem isto a Cacau pulava ao sair dela.
	var apertou_pulo := Input.is_action_just_pressed("jump") and Interacao.livre_para(&"jump")

	# Lado de andar lido do analógico como círculo, em velocidade cheia até na
	# diagonal (ver "O ANALÓGICO NO MUNDO" em controle.gd). Uma leitura por
	# quadro serve ao andar, à animação e ao empurrão das caixas.
	_lado_de_andar = Controle.lado_de_andar(_lado_de_andar)

	# PULO PARA BAIXO: S + ESPAÇO (analógico apontado para baixo + ✕)
	if Controle.aponta_para_baixo() and apertou_pulo:
		position.y += 5.0 # Empurra o personagem levemente para baixo da plataforma
		return # Interrompe para não disparar o pulo normal

	if apertou_pulo:
		jump_buffer_timer = jump_buffer_duration

	if jump_buffer_timer > 0.0:
		if coyote_timer > 0.0 and jumps_left == max_jumps:
			velocity.y = jump_velocity
			jumps_left -= 1
			coyote_timer = 0.0        
			jump_buffer_timer = 0.0   
			estava_no_chao = false
			maior_velocidade_queda = 0.0
			_instanciar_som_pulo_completo()
			
		elif jumps_left > 0 and jumps_left < max_jumps:
			velocity.y = jump_velocity
			jumps_left -= 1
			jump_buffer_timer = 0.0   
			maior_velocidade_queda = 0.0
			_instanciar_som_pulo_completo()
			
			if _animated_sprite:
				_animated_sprite.stop()
				_animated_sprite.play("jump")

	var direction := _lado_de_andar
	if direction:
		_animated_sprite.flip_h = direction < 0
		# Acima da velocidade normal (só dá pra chegar lá saindo de um dash)
		# o excesso escoa aos poucos em vez de sumir num frame — é essa
		# derrapada que faz o dash "escoar" em vez de bater num muro.
		if absf(velocity.x) > speed and signf(velocity.x) == signf(direction):
			velocity.x = move_toward(velocity.x, direction * speed, atrito_excesso * delta)
		else:
			velocity.x = direction * speed
	elif absf(velocity.x) > speed:
		velocity.x = move_toward(velocity.x, 0.0, atrito_excesso * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	# --- EXECUÇÃO DO MOVIMENTO HORIZONTAL PADRÃO ---
	if current_health > 0:
		move_and_slide()
		_verificar_colisoes_estaticas()
		_empurrar_caixas()
		
		_atualizar_animacoes(_lado_de_andar)

	if Input.is_key_pressed(KEY_K) and Input.is_action_just_pressed("jump"):
		take_damage(1, Vector2.ZERO)

	if Input.is_key_pressed(KEY_K) and not _tecla_k_estava_pressionada:
		_debug_coletar_cilindros_puzzle()
	_tecla_k_estava_pressionada = Input.is_key_pressed(KEY_K)

# --- POSE DO MAÇARICO ---
#
# Quem usa: a chapa soldada (corte) e a retorta (acender o forno). Os dois
# chamam pelo grupo "player", então nenhum deles precisa saber o caminho da
# personagem na cena.

## Trava a personagem na animação do maçarico e faz ela olhar para o alvo.
## Cada chamada precisa de um "encerrar_uso_macarico()" correspondente.
## som_offset: de onde tocar o maçarico_sound — 0.1s no aceso inicial, 1.0s
## nas seguradas seguintes (ex: segurando D na dosagem da retorta).
func iniciar_uso_macarico(olhar_para_x: float = INF, som_offset: float = 0.1) -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	if not _animated_sprite.sprite_frames.has_animation(ANIM_MACARICO):
		return

	var primeira_trava := _travas_macarico == 0
	if primeira_trava:
		_macarico_geracao += 1
		_tocar_som_macarico(som_offset)
	_travas_macarico += 1
	if olhar_para_x != INF:
		_animated_sprite.flip_h = olhar_para_x < global_position.x

	usando_ferramenta = true
	pode_se_mover = false
	velocity.x = 0.0
	# A animação não dá loop: ela roda os 4 frames e para no último, que é a
	# pose de "maçarico aceso". Só rebobina quando a pose começa de verdade —
	# uma trava aninhada não pode reiniciar o gesto no meio.
	if primeira_trava:
		_animated_sprite.play(ANIM_MACARICO)
		_animated_sprite.frame = 0
	elif _animated_sprite.animation != ANIM_MACARICO:
		_animated_sprite.play(ANIM_MACARICO)


## Devolve o controle. Só solta de verdade quando a última trava sai.
## O movimento volta na hora, mas os 4 frames ainda rodam ao contrário (a
## personagem guardando o maçarico) antes do idle — quem chama não precisa
## esperar por isso.
func encerrar_uso_macarico() -> void:
	if _travas_macarico <= 0:
		return
	_travas_macarico -= 1
	if _travas_macarico > 0:
		return

	pode_se_mover = true
	_parar_som_macarico()
	_rebobinar_macarico()


## Roda a pose de trás para frente e só então volta para o idle.
## "usando_ferramenta" continua ligado até o fim para o andar/pular não
## atropelarem a animação no meio do caminho.
func _rebobinar_macarico() -> void:
	if _animated_sprite == null or _animated_sprite.animation != ANIM_MACARICO:
		usando_ferramenta = false
		if _animated_sprite:
			_animated_sprite.play("idle")
		return

	var geracao := _macarico_geracao
	_animated_sprite.play_backwards(ANIM_MACARICO)
	await _animated_sprite.animation_finished

	# A pose recomeçou enquanto isto esperava: quem manda agora é a nova.
	if geracao != _macarico_geracao:
		return

	usando_ferramenta = false
	_animated_sprite.play("idle")


## A luz azul da ponta. Fica acesa enquanto a pose durar (inclusive na
## rebobinagem) e acompanha o lado para onde a personagem está virada.
func _atualizar_luz_macarico() -> void:
	if _luz_macarico == null:
		return

	if not usando_ferramenta:
		_luz_macarico.enabled = false
		return

	var x: float = luz_macarico_offset.x
	if _animated_sprite and _animated_sprite.flip_h:
		# Espelha em torno do eixo do sprite, não do centro do Player.
		var eixo: float = _animated_sprite.position.x
		x = 2.0 * eixo - x
	_luz_macarico.position = Vector2(x, luz_macarico_offset.y)

	# Tremida do maço aceso — sem isso a luz fica com cara de lâmpada parada.
	_luz_macarico.energy = luz_macarico_energia * randf_range(0.82, 1.12)
	_luz_macarico.enabled = true


## Pose do maçarico por um tempo fixo — para quem só quer o gesto do corte e
## não tem um "fim" próprio para esperar.
func usar_macarico(duracao: float = 1.0, olhar_para_x: float = INF) -> void:
	iniciar_uso_macarico(olhar_para_x)
	await get_tree().create_timer(duracao).timeout
	encerrar_uso_macarico()


## Chiado do maçarico acendendo — toca junto com a pose, a partir do offset
## pedido (pula silêncio/ataque do arquivo conforme o contexto).
## O arquivo original grava alto demais perto de outros sons do jogo — este
## corte compensa isso sem precisar reexportar o mp3.
const VOLUME_MACARICO_DB := -14.0

func _tocar_som_macarico(offset: float) -> void:
	if not som_macarico_arquivo:
		return
	_audio_macarico = AudioStreamPlayer.new()
	_audio_macarico.stream = som_macarico_arquivo
	_audio_macarico.volume_db = VOLUME_MACARICO_DB
	add_child(_audio_macarico)
	_audio_macarico.play(offset)


func _parar_som_macarico() -> void:
	if _audio_macarico and is_instance_valid(_audio_macarico):
		_audio_macarico.queue_free()
	_audio_macarico = null


# --- RECUO PARA ABRIR ESPAÇO A UMA CENA ---
#
# Quem chama: as coisas que acontecem GRANDES em cima da personagem e a
# cobririam se ela apertasse E coladinha nelas — a porta de metal derretendo é
# a primeira. Ela dá os passos para trás sozinha e a cena só começa depois.

## Anda a personagem até "destino_x" (coordenada do mundo) tocando a corrida, e
## só devolve quando ela chega. Quem chama pode dar "await".
##
## O caminho é conferido com a colisão dela ANTES de andar: se houver parede, a
## personagem para encostada nela em vez de entrar dentro — o tween mexe na
## posição direto, sem passar pela física.
func recuar_ate_x(destino_x: float, velocidade: float = 0.0) -> void:
	if current_health <= 0:
		return

	var passo := destino_x - global_position.x
	if absf(passo) < 1.0:
		return

	# test_only = só pergunta "esbarraria em quê?", sem sair do lugar.
	var obstaculo := move_and_collide(Vector2(passo, 0.0), true)
	if obstaculo:
		passo = obstaculo.get_travel().x
		if absf(passo) < 1.0:
			return

	var duracao := absf(passo) / (velocidade if velocidade > 0.0 else speed)

	velocity = Vector2.ZERO
	pode_se_mover = false
	# Sem isto o _physics_process força "idle" todo frame por cima da corrida —
	# e a gravidade continuaria correndo escondida por baixo do tween.
	animacao_controlada_externamente = true
	if _animated_sprite:
		_animated_sprite.flip_h = passo < 0.0
		if _animated_sprite.sprite_frames and _animated_sprite.sprite_frames.has_animation("run"):
			_animated_sprite.play("run")

	var tween := create_tween()
	tween.tween_property(self, "global_position:x", global_position.x + passo, duracao)
	await tween.finished

	animacao_controlada_externamente = false
	pode_se_mover = true
	if _animated_sprite and _animated_sprite.sprite_frames and _animated_sprite.sprite_frames.has_animation("idle"):
		_animated_sprite.play("idle")


# --- MOMENTO CONTEMPLATIVO: primeira vez que ela vê o foguete ao fundo ---
# Chamada pela Area2D "ColisaoCenaFoguete" quando o personagem pisa no último
# degrau: balão de exclamação, vira pra esquerda e dispara UMA timeline única
# do Dialogic (Uau -> anda 200px -> fala contemplativa), sem fechar e reabrir
# o diálogo no meio do caminho.
func reagir_ao_avistar_foguete(colisao_shape: CollisionShape2D) -> void:
	if _fala_foguete_feita:
		return
	_fala_foguete_feita = true

	# Ponto mais à esquerda da área de colisão (ela anda até esse limite, não um valor fixo)
	var meia_largura = colisao_shape.shape.size.x / 2.0
	_foguete_destino_x = colisao_shape.global_position.x - meia_largura
	pode_se_mover = false
	velocity = Vector2.ZERO
	if _animated_sprite:
		_animated_sprite.play("idle")

	# Ela cai e fica parada um instante antes de qualquer reação
	await get_tree().create_timer(1.0).timeout

	# Só então o balão de exclamação pisca acima da cabeça
	if _exclamacao_foguete:
		PopupFX.mostrar(_exclamacao_foguete)

	await get_tree().create_timer(1.1).timeout

	# Vira para a esquerda, independente do lado que estava olhando
	if _animated_sprite:
		_animated_sprite.flip_h = true

	# Um respiro depois de virar, com o balão ainda visível, antes dele sumir
	await get_tree().create_timer(0.4).timeout

	if _exclamacao_foguete:
		await PopupFX.esconder(_exclamacao_foguete)

	# Um respiro depois do balão sumir, antes de soltar o "Uau"
	await get_tree().create_timer(0.5).timeout

	Dialogic.timeline_ended.connect(_on_fala_foguete_terminou, CONNECT_ONE_SHOT)
	Dialogic.start(TIMELINE_FOGUETE)

func _on_fala_foguete_terminou() -> void:
	pode_se_mover = true
	if _coracao_foguete:
		await PopupFX.mostrar(_coracao_foguete)
		await _coracao_foguete.animation_finished
		await PopupFX.esconder(_coracao_foguete)

# Chamada de dentro da timeline do Dialogic (via DialogicBridge, evento "do")
# para andar sem fechar o diálogo — o Dialogic aguarda esse await antes de
# seguir para as próximas falas.
func andar_ate_foguete() -> void:
	set_physics_process(false)

	if _animated_sprite:
		_animated_sprite.flip_h = true
		_animated_sprite.play("run")

	var distancia = global_position.x - _foguete_destino_x
	var duracao = distancia / speed
	var tween = create_tween()
	tween.tween_property(self, "global_position:x", _foguete_destino_x, duracao)
	await tween.finished

	if _animated_sprite:
		_animated_sprite.play("idle")

	set_physics_process(true)

# --- DETECTA IMPACTOS COM OBJETOS SÓLIDOS (StaticBody2D) ---
func _verificar_colisoes_estaticas() -> void:
	if esta_invencivel or esta_invencivel_dash:
		return
		
	for i in range(get_slide_collision_count()):
		var colisao = get_slide_collision(i)
		var objeto_colidido = colisao.get_collider()
		
		if objeto_colidido and objeto_colidido.is_in_group("barreira"):
			# A barreira pode ter partes sólidas que não machucam (o degrau do
			# asset); ela é quem diz se a forma tocada dá dano.
			if objeto_colidido.has_method("causa_dano") \
					and not objeto_colidido.causa_dano(colisao.get_collider_shape()):
				continue
			var direcao_impacto = colisao.get_normal()
			
			if direcao_impacto.x == 0:
				direcao_impacto.x = -1.0 if global_position.x < objeto_colidido.global_position.x else 1.0
				
			take_damage(1, direcao_impacto)
			break 

# --- POSE DO ARREMESSO DO BUMERANGUE ---
#
# Quem chama: ferramentas_player.gd, no instante em que o bumerangue sai da
# mão. Não trava nada — a personagem continua correndo, pulando e podendo
# levar dano no meio do gesto.

## Toca o gesto do arremesso por cima da animação atual.
## `olhar_para_x` é a componente X da mira: o braço tem que sair para o lado
## em que o bumerangue foi jogado.
func tocar_arremesso_bumerangue(olhar_para_x: float = 0.0) -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	if not _animated_sprite.sprite_frames.has_animation(ANIM_BUMERANGUE):
		return
	# A pose do maçarico é trava de verdade (a personagem está presa no gesto
	# de cortar/acender): o arremesso não passa por cima dela.
	if usando_ferramenta or animacao_controlada_externamente:
		return

	if olhar_para_x != 0.0:
		_animated_sprite.flip_h = olhar_para_x < 0.0

	var quadros: int = _animated_sprite.sprite_frames.get_frame_count(ANIM_BUMERANGUE)
	var fps: float = maxf(_animated_sprite.sprite_frames.get_animation_speed(ANIM_BUMERANGUE), 1.0)
	_arremesso_restante = float(quadros) / fps
	_arremesso_no_chao = is_on_floor()

	_animated_sprite.play(ANIM_BUMERANGUE)
	_animated_sprite.frame = 0


## Corta o gesto na hora. Quem toma o sprite para si no meio do arremesso (o
## dash da mochila é o caso real) chama isto, senão a pose seguraria a
## animação normal por mais alguns quadros depois de o dash acabar.
func cancelar_arremesso_bumerangue() -> void:
	_arremesso_restante = 0.0


func _atualizar_animacoes(direction: float) -> void:
	# A rebobinagem do maçarico devolve o movimento antes de a animação acabar
	# — andar nesse meio tempo não pode cortar o gesto de guardar a ferramenta.
	if usando_ferramenta:
		return
	# Gesto do arremesso em cima: ele segura o sprite até acabar, mas perde o
	# lugar na hora em que a personagem sai do chão ou aterrissa.
	if _arremesso_restante > 0.0:
		if is_on_floor() == _arremesso_no_chao:
			return
		_arremesso_restante = 0.0
	if _animated_sprite:
		if not is_on_floor():
			if _animated_sprite.animation != "jump":
				_animated_sprite.play("jump")
		elif direction != 0:
			_animated_sprite.play("run")
		else:
			_animated_sprite.play("idle")

# --- FUNÇÃO DO ÁUDIO DO PULO ---
func _instanciar_som_pulo_completo() -> void:
	if not som_pulo_arquivo:
		return
	var novo_audio = AudioStreamPlayer.new()
	novo_audio.stream = som_pulo_arquivo
	add_child(novo_audio)
	novo_audio.play(13.4)
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(novo_audio):
		novo_audio.queue_free()

# --- RECORTE DO ÁUDIO DE DANO ---
func _instanciar_som_dano() -> void:
	if not som_dano_arquivo:
		return
	var audio_dano = AudioStreamPlayer.new()
	audio_dano.stream = som_dano_arquivo
	add_child(audio_dano)
	audio_dano.play(3.6)
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(audio_dano):
		audio_dano.queue_free()

# --- FUNÇÃO DO PISCADO ---
func _executar_efeito_piscado() -> void:
	if not _animated_sprite:
		return
	while esta_invencivel:
		_animated_sprite.modulate.a = 0.2  
		await get_tree().create_timer(0.08).timeout  
		if not esta_invencivel: break
		_animated_sprite.modulate.a = 1.0  
		await get_tree().create_timer(0.08).timeout
	if _animated_sprite:
		_animated_sprite.modulate.a = 1.0

func _reiniciar_cena_seguro() -> void:
	# Avisa que esta recarga é uma morte: só assim o ponto de retorno (bandeira
	# ou sala) continua valendo na cena que abrir.
	PontoDeRetorno.marcar_morte(get_tree())
	get_tree().reload_current_scene()

# --- FUNÇÃO DE DANO E KNOCKBACK COM STUN ---
func take_damage(amount: int, direcao_recuo: Vector2 = Vector2.ZERO) -> void:
	if esta_invencivel or esta_invencivel_dash or current_health <= 0:
		# O golpe não entrou: a marca da lâmina morre aqui, senão ela sobraria
		# guardada e a PRÓXIMA morte (uma queda, por exemplo) viria despedaçada.
		_morte_de_corte = false
		return

	current_health -= amount
	current_health = clampi(current_health, 0, max_health)
	health_changed.emit(current_health)
	
	_instanciar_som_dano()
	
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("disparar_tremor"):
		camera.disparar_tremor(12.0)
		
	if current_health > 0:
		# Sobreviveu ao golpe: a marca não fica pendurada para a morte seguinte.
		_morte_de_corte = false
		esta_invencivel = true
		esta_no_knockback = true
		pode_se_mover = false 
		
		if direcao_recuo != Vector2.ZERO:
			velocity.x = direcao_recuo.x * knockback_forca_x
			velocity.y = knockback_forca_y
		else:
			velocity.x = knockback_forca_x if _animated_sprite.flip_h else -knockback_forca_x
			velocity.y = knockback_forca_y

		move_and_slide()

		if _animated_sprite and _animated_sprite.sprite_frames.has_animation("jump"):
			_animated_sprite.play("jump")

		_executar_efeito_piscado() 
		
		await get_tree().create_timer(0.60).timeout
		pode_se_mover = true       
		esta_no_knockback = false  
		
		await get_tree().create_timer(invencibilidade_duracao - 0.2).timeout
		esta_invencivel = false 
	else:
		velocity = Vector2.ZERO
		pode_se_mover = false
		if _morte_de_corte:
			await _morrer_a_pedacos()
		else:
			await get_tree().create_timer(0.4).timeout
		call_deferred("_reiniciar_cena_seguro")


# --- MORTE DESPEDAÇADA ---

## Avisa que o PRÓXIMO golpe é de lâmina. Quem chama é a armadilha, no frame do
## corte e ANTES do take_damage() — a morte lá em cima consulta esta marca.
func marcar_morte_de_corte(posicao_da_lamina: Vector2) -> void:
	_morte_de_corte = true
	_lamina_que_matou = posicao_da_lamina


## Some com a personagem e joga os cacos dela no lugar. O efeito não pode ser
## filho do player: a personagem fica invisível e imóvel (é a câmera dela que
## continua enquadrando a cena), mas o rastro precisa viver na FASE, senão ele
## herdaria qualquer coisa que aconteça com o corpo.
func _morrer_a_pedacos() -> void:
	_morte_de_corte = false

	var arena: Node = get_tree().current_scene
	if arena == null:
		arena = get_parent()

	if _animated_sprite:
		MorteDespedacada.explodir(arena, _animated_sprite, _lamina_que_matou)
		_animated_sprite.visible = false
		_animated_sprite.stop()

	# O corpo some junto: sem colisão ele não segura mais caixa nenhuma, e sem
	# física ele não desliza nem cai enquanto os cacos voam.
	var forma: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if forma:
		forma.set_deferred("disabled", true)
	set_physics_process(false)

	await get_tree().create_timer(ESPERA_DA_MORTE_DE_CORTE).timeout

# --- DEBUG: COLETA AUTOMÁTICA DOS CILINDROS DE H2/O2 (tecla K) ---
func _debug_coletar_cilindros_puzzle() -> void:
	var ids_alvo = ["Cilindro_de_Hidrogenio", "Cilindro_Oxigenio"]
	for item in get_tree().get_nodes_in_group("item_coletavel"):
		if item.id_do_item in ids_alvo and not Inventario.tem_item(item.id_do_item):
			Inventario.adicionar_item(item.id_do_item, item.nome_do_item, item.textura_do_item, item.descricao_do_item)
			EstadoMundo.marcar_feito(item)
			item.queue_free()
			print("DEBUG [Player]: Coletado via tecla K -> ", item.nome_do_item)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == self:
		if global_dialog_box:
			if global_dialog_box.has_method("mostrar"):
				global_dialog_box.mostrar("Corri 10Km... Não faz sentido voltar agora")
			else:
				global_dialog_box.exibir_fala("Corri 10Km... Não faz sentido voltar agora")

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == self and global_dialog_box:
		global_dialog_box.esconder()

# --- EMPURRAR (LATERAL) E SURFAR (EM CIMA) A CAIXA ---
@export var velocidade_empurrao: float = 180.0  # Velocidade da caixa ao empurrar pela lateral
@export var velocidade_surfar: float = 80.0     # Velocidade da caixa quando o player surfa em cima
@export var limite_queda: float = 900.0

func _empurrar_caixas() -> void:
	var input_dir := _lado_de_andar
	if input_dir == 0:
		return

	for i in range(get_slide_collision_count()):
		var colisao = get_slide_collision(i)
		var objeto = colisao.get_collider()

		if objeto.is_in_group("empurravel"):
			var normal = colisao.get_normal()

			if normal.y < -0.7:
				objeto.empurrar(input_dir * velocidade_surfar)
			else:
				var player_direita = global_position.x > objeto.global_position.x
				if (input_dir > 0 and not player_direita) or (input_dir < 0 and player_direita):
					objeto.empurrar(input_dir * velocidade_empurrao)
