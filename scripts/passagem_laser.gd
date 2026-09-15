extends Node2D

# --- PASSAGEM DO LASER (world1 <-> laboratório) ---
#
# Depois que o cientista se revela como Dr. Chico, no fim do world1, os dois
# lasers do jogo viram as duas pontas da MESMA porta:
#
#   world1 .............|LASER|          |LASER|............. laboratório
#            (x ~6266) ->                <- (x ~155)
#
# O mapa de cada cena acaba na linha do seu laser. Andar para fora por ela
# carrega a outra cena e devolve o player na saída do laser de lá — indo para a
# direita no world1 ele entra no laboratório, indo para a esquerda no
# laboratório ele volta para o world1.
#
# Enquanto o Dr. Chico não se revelou, este nó não faz absolutamente nada: o
# laser continua sendo só o obstáculo que a fase pede para abrir.
#
# A linha só vale na altura do chão. Em cima do telhado do laboratório o mapa
# continua para os dois lados, então lá ela não existe e a câmera volta a
# seguir livre — senão andar no telhado puxava o player para dentro da outra
# cena sem ele ter entrado por porta nenhuma.
#
# Estrutura na cena:
#   PassagemLaser (Node2D, este script)  <- posicione-o EM CIMA do laser: a
#   │                                       linha da porta é o X dele
#   ├── PontoDeEntrada   <- Marker2D: onde o player nasce ao CHEGAR nesta cena
#   └── LimiteDeAltura   <- Marker2D opcional: acima dele a passagem não existe

@export_group("Destino")
## Cena do outro lado da passagem.
@export_file("*.tscn") var cena_destino: String = ""
@export var duracao_fade: float = 0.7

@export_group("Limite")
## Para que lado o player SAI desta cena (1 = pela direita, -1 = pela esquerda).
@export var sentido: float = 1.0
## Quanto a câmera ainda pode mostrar depois da linha, para o laser não ficar
## cortado na beirada da tela. Deixe 0 para não mexer na câmera.
@export var margem_camera: float = 0.0

@export_group("Laser")
## O laser desta cena. Enquanto a passagem existe ele nasce liberado — senão o
## player fica preso do lado errado da porta.
@export var barreira: NodePath

var _saindo: bool = false
# A linha só arma depois de ver o player do lado de dentro dela: assim ele nunca
# é mandado de volta no mesmo instante em que chega.
var _armada: bool = false

var _camera: Camera2D = null
var _camera_presa: bool = false
# Até onde a câmera podia ir antes da passagem existir, para devolver esse
# valor quando o player sobe acima do limite de altura.
var _limite_camera_solto: int = 0

@onready var _ponto_entrada: Marker2D = get_node_or_null("PontoDeEntrada")
@onready var _limite_altura: Marker2D = get_node_or_null("LimiteDeAltura")


func _ready() -> void:
	# Sem a revelação não existe passagem nenhuma: o laser é obstáculo comum.
	if not EstadoMundo.revelou_dr_chico:
		set_process(false)
		return

	# O laser precisa nascer aberto, e sem tocar a animação de abertura: aqui
	# ele já está aberto desde antes, não é o momento de abrir.
	_liberar_laser.call_deferred()
	_preparar_camera.call_deferred()

	if not EstadoMundo.chegando_pelo_laser:
		return
	EstadoMundo.chegando_pelo_laser = false
	_receber_player()
	FadeTela.clarear_na_chegada(get_tree().current_scene, duracao_fade)


func _process(_delta: float) -> void:
	if _saindo:
		return
	var player := _achar_player()
	if player == null:
		return

	# Em cima do telhado o mapa continua: a linha não existe lá e a câmera
	# volta a seguir livre.
	var na_altura_da_porta := _na_altura_da_porta(player)
	_prender_camera(na_altura_da_porta)
	if not na_altura_da_porta:
		return

	# "Dentro" é o lado do mapa em que esta cena continua existindo.
	var dentro := player.global_position.x < global_position.x if sentido > 0.0 \
		else player.global_position.x > global_position.x
	if dentro:
		_armada = true
		return
	if _armada:
		_sair(player)


## False quando o player está acima do limite de altura (no telhado), onde a
## passagem não vale.
func _na_altura_da_porta(player: Node2D) -> bool:
	if _limite_altura == null:
		return true
	return player.global_position.y > _limite_altura.global_position.y


# --- SAÍDA: ELE CRUZOU A LINHA DO LASER ---
func _sair(player: Node2D) -> void:
	_saindo = true

	if "pode_se_mover" in player:
		player.pode_se_mover = false
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	var sprite: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

	EstadoMundo.chegando_pelo_laser = true
	await FadeTela.trocar_cena(self, cena_destino, duracao_fade)


# --- CHEGADA: ELE VEM DA OUTRA CENA ---
# Roda ainda no _ready(), antes de qualquer coisa ser desenhada, para o player
# não piscar no ponto de nascimento da cena.
func _receber_player() -> void:
	if _ponto_entrada == null:
		push_error("PassagemLaser: falta o nó PontoDeEntrada.")
		return

	var player := _achar_player()
	if player == null:
		return

	player.global_position = _ponto_entrada.global_position
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	# A câmera é filha do player e tem amortecimento ligado: sem zerar ele, a
	# cena clareia com a câmera ainda no ponto onde o player estava no arquivo
	# da cena e só depois ela desliza até aqui.
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.reset_smoothing()
		camera.force_update_scroll()
	# Ele chega de costas para o laser, olhando para dentro do mapa novo.
	var sprite: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.flip_h = sentido > 0.0


# --- AUXILIARES ---
func _liberar_laser() -> void:
	var laser := get_node_or_null(barreira)
	if laser == null:
		return
	var colisor := laser.get_node_or_null("CollisionShape2D")
	if colisor:
		colisor.set_deferred("disabled", true)
	var anim: AnimatedSprite2D = laser.get_node_or_null("AnimatedSprite2D")
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("desativado"):
		anim.play("desativado")


func _preparar_camera() -> void:
	if margem_camera <= 0.0:
		return
	var player := _achar_player()
	if player == null:
		return
	_camera = player.get_node_or_null("Camera2D")
	if _camera == null:
		return
	_limite_camera_solto = _camera.limit_right if sentido > 0.0 else _camera.limit_left
	_prender_camera(true)


## O mapa acaba na linha: a câmera não mostra o vazio depois dela. Mas isso só
## vale na altura da porta — no telhado ela volta a seguir o player livremente.
func _prender_camera(prender: bool) -> void:
	if _camera == null or prender == _camera_presa:
		return
	_camera_presa = prender

	var borda := _limite_camera_solto
	if prender:
		borda = int(global_position.x + sentido * margem_camera)
	if sentido > 0.0:
		_camera.limit_right = borda
	else:
		_camera.limit_left = borda


func _achar_player() -> Node2D:
	# Busca pelo nome também: no _ready() a passagem pode rodar antes do
	# _ready() do player, que é quem o coloca no grupo.
	var encontrado := get_tree().get_first_node_in_group("player")
	if encontrado == null:
		encontrado = get_tree().current_scene.get_node_or_null("Player")
	return encontrado as Node2D
