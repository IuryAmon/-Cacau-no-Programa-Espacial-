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
# que se chega à fase do nitrogênio: a ponta direita do laboratório
# (SaidaCorredor) dá na ponta esquerda do corredor da torre (EntradaLab, com
# "sentido" = -1), e a ponta do fundo do corredor (SaidaTorre) dá na ponta
# esquerda da fase 2 (PassagemCorredor): ela sai andando de uma cena e entra
# andando na outra, sem porta nenhuma no meio.
#
# COMO USAR NO EDITOR
#   * ponha o nó EM CIMA da linha de saída, em qualquer altura acima do piso (a
#     Cacau é assentada no chão que estiver embaixo dele);
#   * "sentido" diz para que lado fica o lado de fora (1 = direita);
#   * o piso tem de continuar depois da linha — ela ainda anda uns passos
#     enquanto a tela apaga — e o LimitesDaCamera pode acabar logo depois da
#     linha, para ela sair de quadro.
#
# QUANDO NÃO DÁ PARA SAIR
#
# Alguma coisa na cena pode segurar a Cacau lá dentro por um tempo — a fornalha
# do pátio, enquanto queima (ver retorta.gd). Quem segura entra no grupo
# GRUPO_DE_QUEM_SEGURA e responde a duas perguntas:
#   segura_a_saida() -> bool   está segurando agora?
#   ao_barrar_a_saida()        ela tentou sair: é a hora de dizer por quê
# Com alguém segurando, a linha vira parede: a Cacau para nela, ainda dentro do
# quadro, e a cena não troca. O aviso sai uma vez por tentativa — para ouvir de
# novo ela tem de se afastar da linha e voltar.

const PORTA := preload("res://scripts/porta_simulador.gd")

## Grupo de quem pode segurar a Cacau dentro da cena (ver o cabeçalho).
const GRUPO_DE_QUEM_SEGURA := &"segura_a_saida"
## Barrada, ela fica este tanto para DENTRO da linha.
const RECUO_AO_BARRAR := 1.0
## Depois de barrada, só há aviso de novo se ela se afastar isto da linha.
const DISTANCIA_PARA_AVISAR_DE_NOVO := 48.0

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
## Na caminhada (saída e chegada) a física dela fica parada, então é a própria
## caminhada que a põe de pé no chão a cada passo: ela sobe até este tanto de
## degrau — a sucata da porta de metal derretida, na ponta direita do
## laboratório, tem 22 px — e desce o que for preciso.
const DEGRAU_DA_CAMINHADA := 32.0

var _saindo: bool = false
var _chegando: bool = false
# A linha só arma depois de ver a Cacau do lado de dentro: assim ela nunca é
# mandada de volta no mesmo instante em que chega.
var _armada: bool = false
# Já avisou nesta tentativa de sair (ver _barrar).
var _avisou: bool = false


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
		if absf(player.global_position.x - global_position.x) > DISTANCIA_PARA_AVISAR_DE_NOVO:
			_avisou = false
	elif _armada:
		var quem_segura := _quem_segura()
		if quem_segura != null:
			_barrar(player, quem_segura)
		else:
			_sair(player)


func _do_lado_de_fora(x: float) -> bool:
	return (x - global_position.x) * sentido > 0.0


# --- BARRADA: ALGUÉM ESTÁ SEGURANDO A SAÍDA ---

## Quem está segurando a Cacau nesta cena agora (null = ninguém, pode sair).
func _quem_segura() -> Node:
	# Modo dev (ver modo_dev.gd): ninguém segura a saída.
	if ModoDev.ativo:
		return null
	for no in get_tree().get_nodes_in_group(GRUPO_DE_QUEM_SEGURA):
		if no.has_method("segura_a_saida") and no.segura_a_saida():
			return no
	return null


## Ela cruzou a linha com a saída segurada: volta para o lado de dentro,
## encostada na linha, e quem segura explica (uma vez por tentativa).
func _barrar(player: Node2D, quem_segura: Node) -> void:
	player.global_position.x = global_position.x - sentido * RECUO_AO_BARRAR
	if "velocity" in player:
		player.velocity.x = 0.0
	if _avisou:
		return
	_avisou = true
	if quem_segura.has_method("ao_barrar_a_saida"):
		quem_segura.ao_barrar_a_saida()


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
	var nasce_x := global_position.x + sentido * recuo_fora_da_tela
	player.global_position = Vector2(nasce_x, _de_pe_em(player, nasce_x, chao))
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	# A câmera é filha dela e tem amortecimento: sem o encaixe, o mundo clareia
	# com a câmera ainda vindo do spawn da cena.
	CameraJogador.encaixar(player)

	# Primeiro ponto de retorno da visita: é onde ela para depois de entrar.
	PontoDeRetorno.registrar(self, Vector2(destino_x, _de_pe_em(player, destino_x, chao)))

	var distancia := absf(destino_x - player.global_position.x)
	await _andar(player, destino_x, distancia / _velocidade_de(player))
	_soltar(player)
	_chegando = false


# --- AUXILIARES ---

## A altura da origem da Cacau quando ela está de pé no piso que fica embaixo
## deste nó. Sem piso nenhum (ou antes de a física existir), vale a altura do nó.
func _altura_de_pe(player: Node2D) -> float:
	return _de_pe_em(player, global_position.x, global_position.y)


## O mesmo, no piso embaixo de outro x (o raio sai da altura deste nó). Ali
## pode haver um degrau que embaixo da linha não há — a sucata da porta de
## metal, no laboratório, fica em cima da linha. Sem piso nenhum, "senao".
func _de_pe_em(player: Node2D, x: float, senao: float) -> float:
	var y := _de_pe_abaixo_de(player, Vector2(x, global_position.y), ALCANCE_DO_PISO)
	return senao if is_nan(y) else y


## A altura da origem da Cacau de pé no primeiro piso que um raio acha descendo
## "alcance" px a partir de "ponto". NAN se não achar nenhum.
func _de_pe_abaixo_de(player: Node2D, ponto: Vector2, alcance: float) -> float:
	var corpo := player as CollisionObject2D
	var raio := PhysicsRayQueryParameters2D.create(ponto, ponto + Vector2(0.0, alcance),
		corpo.collision_mask if corpo else 1, [corpo.get_rid()] if corpo else [])
	var achou := get_world_2d().direct_space_state.intersect_ray(raio)
	if achou.is_empty():
		return NAN
	return (achou.position as Vector2).y - _ate_a_sola(player)


## Do centro (a origem) da Cacau até a sola dela.
func _ate_a_sola(player: Node2D) -> float:
	var forma := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if forma and forma.shape:
		return forma.position.y + forma.shape.get_rect().end.y
	return ATE_A_SOLA_PADRAO


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


## Anda a Cacau até "destino_x" tocando a corrida. A física dela fica parada
## (ver _travar), então cada passo a põe de pé no chão que houver embaixo.
func _andar(player: Node2D, destino_x: float, duracao: float) -> void:
	var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.flip_h = destino_x < player.global_position.x
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("run"):
			sprite.play("run")
	var tween := create_tween()
	tween.tween_method(_passo.bind(player), player.global_position.x, destino_x, maxf(duracao, 0.01))
	await tween.finished


## Um passo da caminhada: o x do tween e, como a física dela está parada, o pé
## no chão que houver ali — até DEGRAU_DA_CAMINHADA acima da sola, ou abaixo.
## Sem chão nenhum (a física ainda nem existe), ela segue na mesma altura.
func _passo(x: float, player: Node2D) -> void:
	if not is_instance_valid(player):
		return
	player.global_position.x = x
	var sola := player.global_position.y + _ate_a_sola(player)
	var y := _de_pe_abaixo_de(player, Vector2(x, sola - DEGRAU_DA_CAMINHADA), ALCANCE_DO_PISO)
	if not is_nan(y):
		player.global_position.y = y


func _achar_player() -> Node2D:
	# Pelo nome também: no _ready() a passagem pode rodar antes do _ready() do
	# player, que é quem o coloca no grupo.
	var encontrado := get_tree().get_first_node_in_group("player")
	if encontrado == null and get_tree().current_scene:
		encontrado = get_tree().current_scene.get_node_or_null("Player")
	return encontrado as Node2D
