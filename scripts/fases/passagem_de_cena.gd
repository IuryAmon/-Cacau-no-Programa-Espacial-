class_name PassagemDeCena
extends Node2D

# --- PASSAGEM DE CENA (a ponta aberta de um corredor) ---
#
# Uma linha vertical no mapa: a Cacau anda para fora por ela e o jogo troca de
# cena sozinho, sem apertar nada — ela continua andando enquanto a tela apaga.
# Vindo da outra cena, ela entra andando por esta mesma ponta.
#
# É o par das portas (porta_simulador.gd) para quando não existe porta: as tags
# são as mesmas ("tag_destino" de quem manda = "tag_aqui" de quem recebe), então
# uma porta pode mandar para uma passagem e uma passagem para uma porta. É assim
# que o corredor da torre funciona: a porta de dentro dele leva ao laboratório e
# a ponta do fundo, esta passagem, leva à fase do nitrogênio.
#
# COMO USAR NO EDITOR
#   * ponha o nó EM CIMA da linha de saída, em qualquer altura acima do piso (a
#     Cacau é assentada no chão que estiver embaixo dele);
#   * "sentido" diz para que lado fica o lado de fora (1 = direita);
#   * o piso tem de continuar depois da linha — ela ainda anda uns passos
#     enquanto a tela apaga — e o LimitesDaCamera pode acabar logo depois da
#     linha, para ela sair de quadro.

const PORTA := preload("res://scripts/porta_simulador.gd")

@export_group("Destino")
## Cena do outro lado da passagem.
@export_file("*.tscn") var cena_destino: String = ""
## A "tag_aqui" da porta (ou passagem) que recebe a Cacau na cena de destino.
@export var tag_destino: String = ""
## Quanto a tela leva para apagar; ela segue andando esse tempo todo.
@export var duracao_fade: float = 0.5

@export_group("Chegada")
## Apelido desta ponta, comparado com o "tag_destino" de quem manda para cá.
@export var tag_aqui: String = ""
## Quanto ela anda para dentro do mapa, a partir da linha, antes de o controle
## voltar.
@export var distancia_entrada: float = 150.0
## De quão longe, do lado de fora da linha, ela vem andando (fora do quadro).
@export var recuo_fora_da_tela: float = 70.0
## Quanto a tela leva para clarear na chegada.
@export var duracao_clarear: float = 0.5

@export_group("Limite")
## Para que lado fica o lado de FORA (1 = sai pela direita, -1 = pela esquerda).
@export var sentido: float = 1.0

## Do centro da cápsula da Cacau até a sola, se ela não tiver forma de colisão.
const ATE_A_SOLA_PADRAO := 36.0
## Até onde o raio procura o piso abaixo do nó.
const ALCANCE_DO_PISO := 600.0

var _saindo: bool = false
var _chegando: bool = false
# A linha só arma depois de ver a Cacau do lado de dentro: assim ela nunca é
# mandada de volta no mesmo instante em que chega.
var _armada: bool = false


func _ready() -> void:
	# Quem mandou para cá foi uma porta (as duas estáticas dela) ou outra
	# passagem / o alçapão (só a tag no Progresso).
	var veio_por_porta: bool = PORTA.chegando_por_porta and PORTA.tag_chegada == tag_aqui
	var veio_pela_tag := Progresso.spawn_tag != "" and Progresso.spawn_tag == tag_aqui
	if tag_aqui == "" or not (veio_por_porta or veio_pela_tag):
		return
	PORTA.chegando_por_porta = false
	PORTA.tag_chegada = ""
	Progresso.spawn_tag = ""
	_receber_jogador()


func _process(_delta: float) -> void:
	if _saindo or _chegando or cena_destino.is_empty():
		return
	var player := _achar_player()
	if player == null:
		return
	if not _do_lado_de_fora(player.global_position.x):
		_armada = true
	elif _armada:
		_sair(player)


func _do_lado_de_fora(x: float) -> bool:
	return (x - global_position.x) * sentido > 0.0


# --- SAÍDA: ELA CRUZOU A LINHA ---
func _sair(player: Node2D) -> void:
	_saindo = true
	_travar(player)

	# Segue andando para fora, no passo dela, até a tela terminar de apagar.
	var velocidade := _velocidade_de(player)
	_andar(player, player.global_position.x + sentido * velocidade * (duracao_fade + 0.2),
		duracao_fade + 0.2)

	PORTA.chegando_por_porta = true
	PORTA.tag_chegada = tag_destino
	Progresso.spawn_tag = tag_destino
	await FadeTela.trocar_cena(self, cena_destino, duracao_fade)


# --- CHEGADA: ELA VEM DA OUTRA CENA POR ESTA PONTA ---
# Roda ainda no _ready(), antes de qualquer coisa ser desenhada: ela já nasce
# travada, e o lugar certo vem logo depois — a fase ainda vai arrastá-la para o
# SpawnPadrao no _ready() dela, que roda depois do nosso.
func _receber_jogador() -> void:
	var player := _achar_player()
	if player == null:
		push_warning("PassagemDeCena: chegada pedida, mas não há player na cena.")
		return
	_chegando = true
	_travar(player)

	if FadeTela.chegada_escura:
		# Com a tela ainda preta: põe no lugar, enquadra e ela já entra andando
		# enquanto o mundo clareia.
		FadeTela.clarear_na_chegada(get_tree().current_scene, duracao_clarear, 0.15,
			_entrar.bind(player))
	else:
		_entrar.call_deferred(player)


func _entrar(player: Node2D) -> void:
	if not is_instance_valid(player):
		return
	var chao := _altura_de_pe(player)
	var destino_x := global_position.x - sentido * distancia_entrada
	player.global_position = Vector2(global_position.x + sentido * recuo_fora_da_tela, chao)
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	# A câmera é filha dela e tem amortecimento: sem o encaixe, o mundo clareia
	# com a câmera ainda vindo do spawn da cena.
	CameraJogador.encaixar(player)

	# Primeiro ponto de retorno da visita: é onde ela para depois de entrar.
	PontoDeRetorno.registrar(self, Vector2(destino_x, chao))

	var distancia := absf(destino_x - player.global_position.x)
	await _andar(player, destino_x, distancia / _velocidade_de(player))
	_soltar(player)
	_chegando = false


# --- AUXILIARES ---

## A altura da origem da Cacau quando ela está de pé no piso que fica embaixo
## deste nó. Sem piso nenhum (ou antes de a física existir), vale a altura do nó.
func _altura_de_pe(player: Node2D) -> float:
	var ate_a_sola := ATE_A_SOLA_PADRAO
	var forma := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if forma and forma.shape:
		ate_a_sola = forma.position.y + forma.shape.get_rect().end.y

	var corpo := player as CollisionObject2D
	var raio := PhysicsRayQueryParameters2D.create(global_position,
		global_position + Vector2(0.0, ALCANCE_DO_PISO),
		corpo.collision_mask if corpo else 1, [corpo.get_rid()] if corpo else [])
	var achou := get_world_2d().direct_space_state.intersect_ray(raio)
	if achou.is_empty():
		return global_position.y
	return (achou.position as Vector2).y - ate_a_sola


func _velocidade_de(player: Node2D) -> float:
	var velocidade: float = player.speed if "speed" in player else 350.0
	return maxf(velocidade, 1.0)


func _travar(player: Node2D) -> void:
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	if "pode_se_mover" in player:
		player.pode_se_mover = false
	# Sem isso o _physics_process dela força "idle" todo quadro por cima da
	# corrida.
	if "animacao_controlada_externamente" in player:
		player.animacao_controlada_externamente = true


func _soltar(player: Node2D) -> void:
	if not is_instance_valid(player):
		return
	var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	if "animacao_controlada_externamente" in player:
		player.animacao_controlada_externamente = false
	if "pode_se_mover" in player:
		player.pode_se_mover = true


## Anda a Cacau até "destino_x" tocando a corrida. Só o x: a gravidade dela
## continua valendo, então ela segue pisando no chão.
func _andar(player: Node2D, destino_x: float, duracao: float) -> void:
	var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.flip_h = destino_x < player.global_position.x
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("run"):
			sprite.play("run")
	var tween := create_tween()
	tween.tween_property(player, "global_position:x", destino_x, maxf(duracao, 0.01))
	await tween.finished


func _achar_player() -> Node2D:
	# Pelo nome também: no _ready() a passagem pode rodar antes do _ready() do
	# player, que é quem o coloca no grupo.
	var encontrado := get_tree().get_first_node_in_group("player")
	if encontrado == null and get_tree().current_scene:
		encontrado = get_tree().current_scene.get_node_or_null("Player")
	return encontrado as Node2D
