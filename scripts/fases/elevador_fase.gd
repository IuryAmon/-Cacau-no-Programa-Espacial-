@tool
class_name ElevadorFase
extends Node2D

# --- ELEVADOR ENTRE FASES ---
#
# Uma cabine de carga que liga dois andares que são CENAS DIFERENTES. Ela fica
# sempre aberta (a rampa estendida, quadro 1 do sheet): é só entrar, apertar E
# e a viagem acontece sozinha.
#
# A VIAGEM, em quatro atos:
#   1. EMBARQUE   a Cacau anda até o meio da cabine (ela não viaja pendurada na
#                 beirada) e o controle sai da mão dela;
#   2. FECHAR     os 13 quadros do sheet de trás para a frente: a rampa recolhe
#                 até a cabine ficar fechada (quadro 13);
#   3. PERCURSO   a cabine anda "curso" pixels para o lado do poço, levando a
#                 passageira junto. A CÂMERA NÃO ACOMPANHA: ela fica congelada
#                 onde estava e o elevador sai de quadro, como num corte de
#                 cinema — é o que faz a viagem parecer longa numa tela só;
#   4. TROCA      a tela apaga e a fase de destino abre.
#
# A CHEGADA é a mesma cena ao contrário, e quem a encena é o elevador da fase
# de destino (o que estiver com "recebe_chegada" e a "tag_aqui" combinando):
# a tela clareia com a cabine ainda no poço e fechada, ela entra no lugar
# trazendo a passageira, a rampa se abre (a MESMA animação rodada ao
# contrário) e o controle volta. Ninguém pisca no ponto de nascimento da cena:
# o encaixe da personagem na cabine é feito com a tela ainda toda preta.
#
# COMO EDITAR NO EDITOR:
#   arraste o nó         -> a origem é o CHÃO DE FORA, no meio da cabine:
#                           encoste-a na linha do piso da fase e pronto
#   Cabine/Sprite        -> o sheet de 13 quadros (o quadro 1 é a cabine
#                           aberta e o 13 é a fechada)
#   Cabine/Piso/Colisao  -> o POLÍGONO em que se pisa: o estrado da cabine e a
#                           rampinha que sobe até ele. Edite os pontos à
#                           vontade (é o "Criar Polígono" normal do editor) —
#                           é ele que segura a personagem e é por ele que ela
#                           entra. Vem desenhado em cima da arte, mas o
#                           desenho é seu
#   AreaEmbarque/Colisao -> de onde dentro da cabine o E funciona. O script
#                           reposiciona essa caixa sozinho na altura do
#                           estrado, então reabra a cena depois de mexer muito
#                           no polígono
#   direcao              -> para que lado fica o POÇO: SOBE (o elevador sobe ao
#                           partir e desce ao chegar) ou DESCE (o contrário)
#   curso                -> quantos pixels a cabine anda. Deixe grande o
#                           bastante para ela sair inteira da tela
#   cena_destino         -> o .tscn do outro andar
#   tag_aqui/tag_destino -> o par que liga dois elevadores, igual ao das portas
#                           de fase: ao abrir uma cena, quem recebe a
#                           passageira é o elevador cuja "tag_aqui" bate com a
#                           "tag_destino" de quem a mandou para lá
#   recebe_chegada       -> desligue no elevador que só leva e nunca recebe
#   Tempos (Inspector)   -> a duração de cada ato
#
# NO EDITOR o elevador desenha o poço: uma linha tracejada até onde a cabine
# vai parar, com o contorno dela no fim. É só um rascunho de edição — não
# aparece no jogo.
#
# DESENHO: o z_index da cena do componente (3) deixa a cabine na FRENTE da
# personagem (que anda em z_index 2 nas fases), então ela aparece atrás da
# grade, como quem está dentro do elevador. Para a cabine sumir dentro do poço
# em vez de passar por cima do chão, é o CENÁRIO que tem de estar na frente:
# na fase1.2 o TileMapLayer do terreno está em z_index 10 justamente por isso.

const CENA := "res://scenes/fases/componentes/elevador_fase.tscn"
const GRUPO := "elevador_fase"

## Nome da animação do sheet no SpriteFrames. Quadro 0 = aberto, último =
## fechado; abrir é essa mesma animação rodada ao contrário.
const ANIM := &"portas"

## Para que lado fica o poço: é para lá que a cabine parte, e é de lá que ela
## chega.
enum Direcao { SOBE, DESCE }

# --- MEDIDAS DA CABINE, EM PIXELS DO SHEET ---
# Só a cabine, sem a rampa: ela ocupa as colunas 1..66 e as linhas 2..40 de
# cada quadro de 104x44. É daqui que saem, multiplicadas pela "escala_da_arte",
# a zona de embarque, a altura do balão e o rascunho do poço no editor — mude o
# tamanho do elevador em um lugar só e o resto acompanha.
const CABINE_LARGURA := 66.0
const CABINE_ALTURA := 39.0

## Altura da caixa do E, em pixels de tela: é a personagem em pé no estrado.
## Não entra na escala da arte porque ela não muda de tamanho junto.
const ALTURA_DA_ZONA := 76.0

## Quem trocou de cena por um elevador marca isto. O elevador da cena nova que
## estiver com "recebe_chegada" consome e encena a chegada. Static var
## sobrevive ao change_scene_to_file().
static var chegando_de_elevador: bool = false
## "tag_aqui" do elevador que deve receber a passageira na cena nova.
static var tag_chegada: String = ""

@export_group("Destino")
## Para que lado o elevador leva — ou seja, de que lado fica o poço.
@export var direcao: Direcao = Direcao.SOBE:
	set(valor):
		direcao = valor
		queue_redraw()
## Fase do outro andar. Vazio deixa o elevador como cenário (o E só devolve um
## aviso).
@export_file("*.tscn") var cena_destino: String = ""
## Apelido DESTE elevador, comparado com o "tag_destino" de quem manda a
## passageira para cá.
@export var tag_aqui: String = ""
## "tag_aqui" do elevador que recebe a passageira na cena de destino.
@export var tag_destino: String = ""
## Desligue no elevador que só leva e nunca recebe ninguém.
@export var recebe_chegada: bool = true

@export_group("Tamanho")
## Quantas vezes o pixel do sheet é ampliado. O resto do jogo desenha em 2x (o
## tile de 16 px vira 32), mas o elevador em 2x fica quase da altura da Cacau —
## em 1,5x ele lê como o carrinho de carga que é. Mexer aqui reposiciona
## sozinho a zona de embarque, o balão e o rascunho do poço.
##
## Prefira números "inteiros de meio" (1, 1.5, 2): escala quebrada em arte de
## pixel deixa umas fileiras de pixel mais gordas que as outras.
@export_range(0.5, 4.0, 0.25) var escala_da_arte: float = 1.5:
	set(valor):
		escala_da_arte = valor
		if is_inside_tree():
			_aplicar_escala()

@export_group("Percurso")
## Quantos pixels a cabine anda até sumir no poço. Grande o bastante para ela
## sair inteira da tela: a câmera fica parada e o que sobrar em quadro fica
## boiando no fim da viagem.
@export_range(0.0, 2000.0, 1.0, "suffix:px") var curso: float = 560.0:
	set(valor):
		curso = valor
		queue_redraw()

@export_group("Tempos")
## Quanto o sheet inteiro leva para fechar (e para abrir), seja qual for o FPS
## gravado no SpriteFrames.
@export var duracao_das_portas: float = 0.8
## A subida/descida em si.
@export var duracao_do_percurso: float = 1.6
## Respiro entre a cabine fechar e ela sair do lugar.
@export var pausa_antes_de_partir: float = 0.3
## Respiro entre a cabine chegar e a rampa começar a abrir.
@export var pausa_antes_de_abrir: float = 0.35
## Quanto a tela leva para apagar antes de carregar a fase de destino.
@export var duracao_fade_cena: float = 0.7
## Quanto a tela leva para clarear quando a passageira chega por aqui.
@export var duracao_clarear_chegada: float = 0.7

@export_group("Texto")
## Deixe vazio para elevador livre, ou uma de: macarico, bumerangue, mochila,
## sinalizador, botas, lanterna.
@export var requer_habilidade: String = ""
@export_multiline var mensagem_trancada: String = "O painel está travado."
@export_multiline var mensagem_sem_destino: String = "(Ainda em construção)"

enum Estado { PARADO, EM_USO }

var _estado: int = Estado.PARADO
var _jogador_dentro: bool = false
# Estado do balão, para o PopupFX só ser chamado na virada.
var _aviso_visivel: bool = false
# Último y local da cabine, para repassar o passo à passageira.
var _y_da_cabine: float = 0.0

# --- CÂMERA CONGELADA ---
# A câmera é FILHA da personagem: levá-la para cima levaria a câmera junto. A
# viagem guarda onde ela estava no mundo e devolve isso a cada passo, mexendo
# só no deslocamento local — os limites da fase, o tremor e o zoom continuam
# valendo normalmente.
var _camera: Camera2D = null
var _camera_no_mundo: Vector2 = Vector2.ZERO
var _camera_local: Vector2 = Vector2.ZERO
var _camera_suavizava: bool = false

@onready var _cabine: Node2D = $Cabine
@onready var _sprite: AnimatedSprite2D = $Cabine/Sprite
## O estrado em que se pisa. É AnimatableBody2D porque ele ANDA: um
## StaticBody2D avisaria a física de que nunca sai do lugar.
@onready var _piso: AnimatableBody2D = $Cabine/Piso
@onready var _colisao_piso: CollisionPolygon2D = $Cabine/Piso/Colisao
@onready var _area: Area2D = $AreaEmbarque
@onready var _forma_embarque: CollisionShape2D = $AreaEmbarque/Colisao
@onready var _exclamacao: AnimatedSprite2D = get_node_or_null("ExclamacaoAnimada")
@onready var _som: AudioStreamPlayer2D = get_node_or_null("SomElevador")


static func criar(pai: Node, nome: String, pos_do_piso: Vector2, config: Dictionary = {}) -> ElevadorFase:
	var elevador: ElevadorFase = load(CENA).instantiate()
	elevador.name = nome
	elevador.position = pos_do_piso
	for chave in config:
		elevador.set(chave, config[chave])
	Blockout.adicionar(pai, elevador)
	return elevador


func _ready() -> void:
	_aplicar_escala()
	_mostrar_quadro(0)
	if Engine.is_editor_hint():
		return

	add_to_group(GRUPO)
	if _exclamacao:
		_exclamacao.visible = false
		_exclamacao.stop()

	_area.body_entered.connect(_ao_entrar)
	_area.body_exited.connect(_ao_sair)

	# A tag separa quem recebe quando a cena tem mais de um elevador.
	if recebe_chegada and chegando_de_elevador and tag_chegada == tag_aqui:
		chegando_de_elevador = false
		tag_chegada = ""
		_receber_passageira()


## Reajusta tudo o que depende do tamanho da arte: o sprite, a zona em que o E
## funciona, a altura do balão e o rascunho do poço.
func _aplicar_escala() -> void:
	if _cabine == null:
		return
	# A escala vive na CABINE inteira, não só no sprite: assim o polígono do
	# estrado é desenhado em pixels da arte e cresce junto com ela.
	_cabine.scale = Vector2(escala_da_arte, escala_da_arte)
	var piso := _altura_do_piso()
	if _forma_embarque and _forma_embarque.shape is RectangleShape2D:
		# Um tiquinho mais estreita que a cabine: encostar na quina de fora não
		# conta como estar dentro do elevador. A altura é a da personagem, e a
		# caixa fica EM CIMA do estrado — quem está no chão, ao pé da rampa,
		# está longe demais no eixo x para encostar nela.
		var caixa := Vector2((CABINE_LARGURA - 8.0) * escala_da_arte, ALTURA_DA_ZONA)
		(_forma_embarque.shape as RectangleShape2D).size = caixa
		_forma_embarque.position = Vector2(0.0, piso - caixa.y * 0.5 + 6.0)
	if _exclamacao:
		_exclamacao.position = Vector2(0.0, piso - 62.0)
	queue_redraw()


## y local da superfície em que se pisa dentro da cabine, tirado do PONTO MAIS
## ALTO do polígono do estrado — redesenhe a rampa e o embarque acompanha.
## Sem polígono, vale o próprio chão de fora (a origem do nó).
func _altura_do_piso() -> float:
	if _colisao_piso == null or _colisao_piso.polygon.size() < 3:
		return 0.0
	var topo := INF
	for ponto in _colisao_piso.polygon:
		topo = minf(topo, ponto.y)
	# Do espaço do polígono para o do elevador, descontando o quanto a cabine
	# já andou (o estrado é medido em relação ao repouso dela).
	return to_local(_colisao_piso.to_global(Vector2(0.0, topo))).y - _cabine.position.y


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _estado != Estado.PARADO:
		return
	_atualizar_aviso()
	# Interacao.pediu() queima o toque de E, então fica por ÚLTIMO.
	if _jogador_dentro and Interacao.pediu():
		_partir()


# --- PARTIDA ---

func _partir() -> void:
	if requer_habilidade != "" and not Progresso.tem_habilidade(requer_habilidade):
		_avisar(mensagem_trancada)
		return
	if cena_destino == "":
		_avisar(mensagem_sem_destino)
		return

	var passageira := _passageira()
	if passageira == null:
		return

	_estado = Estado.EM_USO
	_esconder_aviso()

	# 1) ATO DO EMBARQUE — ela caminha até o meio da cabine. Quem já está no
	# lugar não se mexe (o recuar_ate_x devolve na hora).
	if passageira.has_method("recuar_ate_x"):
		await passageira.recuar_ate_x(global_position.x)
	if not _ainda_na_cena():
		return

	_travar_passageira(passageira)
	# De pé no meio da cabine, exatamente onde a chegada a coloca do outro
	# lado: quem apertou E no meio de um pulo assenta no piso em vez de viajar
	# pendurado no ar.
	_encaixar_na_cabine(passageira)
	_tocar_som()

	# 2) ATO DA PORTA — a rampa recolhe.
	await _animar_portas(false)
	if not _ainda_na_cena():
		return
	await _esperar(pausa_antes_de_partir)
	if not _ainda_na_cena():
		return

	# 3) ATO DO PERCURSO — a cabine some no poço levando ela junto.
	await _percorrer(0.0, _passo_do_poco(), passageira)
	if not _ainda_na_cena():
		return

	# 4) ATO DA TROCA — o outro andar é outra cena.
	chegando_de_elevador = true
	tag_chegada = tag_destino
	FadeTela.trocar_cena(self, cena_destino, duracao_fade_cena)


# --- CHEGADA ---
#
# Chamado ainda no _ready(), antes de qualquer coisa ser desenhada: a cabine já
# nasce fechada e no fundo do poço, para a passageira não piscar no ponto de
# nascimento da fase.
func _receber_passageira() -> void:
	var passageira := _passageira()
	if passageira == null:
		return

	_estado = Estado.EM_USO
	_esconder_aviso()
	_mostrar_quadro(_ultimo_quadro())
	_cabine.position.y = _passo_do_poco()
	_y_da_cabine = _cabine.position.y
	_travar_passageira(passageira)

	# Primeiro ponto de retorno da visita: morrer antes de qualquer bandeira ou
	# sala renasce aqui, em pé na cabine já aberta.
	PontoDeRetorno.registrar(self, _ponto_de_embarque(passageira))

	# A tela chega apagada da fase anterior. O encaixe na cabine vai como
	# "antes_de_clarear" de propósito: feito aqui, com a tela ainda toda preta,
	# o mundo já aparece enquadrado no elevador em vez de a câmera deslizar do
	# ponto de nascimento da cena até ele na frente do jogador.
	await FadeTela.clarear_na_chegada(get_tree().current_scene,
		duracao_clarear_chegada, 0.15, _encaixar_na_cabine.bind(passageira))
	if not _ainda_na_cena():
		return
	# Rede de segurança: sem cortina na frente (um teste automático, ou alguém
	# chegando aqui sem passar pelo fade) o clarear_na_chegada devolve na hora e
	# nunca chama o encaixe. Repetir não custa nada — ela não saiu do lugar.
	_encaixar_na_cabine(passageira)

	_tocar_som()
	await _percorrer(_passo_do_poco(), 0.0, passageira)
	if not _ainda_na_cena():
		return
	await _esperar(pausa_antes_de_abrir)
	if not _ainda_na_cena():
		return
	await _animar_portas(true)
	if not _ainda_na_cena():
		return

	_soltar_passageira(passageira)
	_estado = Estado.PARADO


## Coloca a passageira de pé dentro da cabine, onde quer que ela esteja no
## percurso — e a câmera junto, já que ela é filha da personagem.
func _encaixar_na_cabine(passageira: Node2D) -> void:
	if not is_instance_valid(passageira):
		return
	passageira.global_position = _ponto_de_embarque(passageira) + Vector2(0.0, _cabine.position.y)
	if "velocity" in passageira:
		passageira.velocity = Vector2.ZERO
	CameraJogador.encaixar(passageira)
	_congelar_camera(passageira)


# --- O PERCURSO ---

## Anda a cabine de "de" até "ate" (y local) levando a passageira junto, com a
## câmera parada onde estava.
func _percorrer(de: float, ate: float, passageira: Node2D) -> void:
	_cabine.position.y = de
	_y_da_cabine = de
	if is_equal_approx(de, ate) or duracao_do_percurso <= 0.0:
		_cabine.position.y = ate
		return

	var viagem := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	viagem.tween_method(_passo_da_cabine.bind(passageira), de, ate, duracao_do_percurso)
	await viagem.finished


func _passo_da_cabine(y: float, passageira: Node2D) -> void:
	var passo := y - _y_da_cabine
	_y_da_cabine = y
	_cabine.position.y = y
	if is_instance_valid(passageira):
		passageira.global_position.y += passo
	_manter_camera()


## Deslocamento (em y local) da cabine parada no fundo do poço.
func _passo_do_poco() -> float:
	return -curso if direcao == Direcao.SOBE else curso


# --- A PORTA (os 13 quadros) ---

## Roda o sheet inteiro dentro de "duracao_das_portas". Abrir é a MESMA
## animação ao contrário (play_backwards), como o sheet foi desenhado.
func _animar_portas(abrir: bool) -> void:
	var ultimo := _ultimo_quadro()
	if ultimo <= 0:
		return

	var fps: float = maxf(_sprite.sprite_frames.get_animation_speed(ANIM), 0.001)
	var quadros := float(ultimo + 1)
	_sprite.speed_scale = quadros / (maxf(duracao_das_portas, 0.05) * fps)
	_sprite.animation = ANIM
	if abrir:
		_sprite.frame = ultimo
		_sprite.play_backwards(ANIM)
	else:
		_sprite.frame = 0
		_sprite.play(ANIM)
	await _sprite.animation_finished

	_sprite.speed_scale = 1.0
	_mostrar_quadro(0 if abrir else ultimo)


func _mostrar_quadro(indice: int) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(ANIM):
		return
	_sprite.stop()
	_sprite.animation = ANIM
	_sprite.frame = clampi(indice, 0, _ultimo_quadro())


func _ultimo_quadro() -> int:
	if _sprite == null or _sprite.sprite_frames == null:
		return 0
	if not _sprite.sprite_frames.has_animation(ANIM):
		return 0
	return _sprite.sprite_frames.get_frame_count(ANIM) - 1


# --- A PASSAGEIRA ---

func _passageira() -> Node2D:
	# Busca pelo nome também: o elevador pode estar ANTES do player na árvore e
	# aí o _ready() dele — que entra no grupo — ainda não rodou.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null and get_tree().current_scene:
		player = get_tree().current_scene.get_node_or_null("Player") as Node2D
	if player == null:
		push_warning("%s: não há player na cena para viajar de elevador." % name)
	return player


## Tira o controle da mão dela e desliga a física: a gravidade não pode correr
## por baixo do percurso, senão ela "cai" tudo de uma vez ao ser solta.
func _travar_passageira(passageira: Node2D) -> void:
	if not is_instance_valid(passageira):
		return
	if "velocity" in passageira:
		passageira.velocity = Vector2.ZERO
	if "pode_se_mover" in passageira:
		passageira.pode_se_mover = false
	if "animacao_controlada_externamente" in passageira:
		passageira.animacao_controlada_externamente = true
	var anim := passageira.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("idle"):
		anim.play("idle")


func _soltar_passageira(passageira: Node2D) -> void:
	_soltar_camera(passageira)
	if not is_instance_valid(passageira):
		return
	if "animacao_controlada_externamente" in passageira:
		passageira.animacao_controlada_externamente = false
	if "pode_se_mover" in passageira:
		passageira.pode_se_mover = true


## Onde fica a ORIGEM da personagem com os pés no piso da cabine. A conta sai
## da forma de colisão dela, então trocar a altura do personagem não desregula
## o elevador.
func _ponto_de_embarque(passageira: Node2D) -> Vector2:
	return global_position + Vector2(0.0, _altura_do_piso() - _altura_dos_pes(passageira))


func _altura_dos_pes(passageira: Node2D) -> float:
	var forma := passageira.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if forma == null or forma.shape == null:
		return 36.0
	var altura := 0.0
	if forma.shape is CapsuleShape2D:
		altura = (forma.shape as CapsuleShape2D).height
	elif forma.shape is RectangleShape2D:
		altura = (forma.shape as RectangleShape2D).size.y
	elif forma.shape is CircleShape2D:
		altura = (forma.shape as CircleShape2D).radius * 2.0
	return (forma.position.y + altura * 0.5) * absf(forma.scale.y)


# --- A CÂMERA PARADA ---

func _congelar_camera(passageira: Node2D) -> void:
	_soltar_camera(null)
	if not is_instance_valid(passageira):
		return
	_camera = passageira.get_node_or_null("Camera2D") as Camera2D
	if _camera == null:
		return
	_camera_local = _camera.position
	_camera_no_mundo = _camera.global_position
	_camera_suavizava = _camera.position_smoothing_enabled
	_camera.position_smoothing_enabled = false


func _manter_camera() -> void:
	if is_instance_valid(_camera):
		_camera.global_position = _camera_no_mundo


func _soltar_camera(passageira: Node2D) -> void:
	if not is_instance_valid(_camera):
		_camera = null
		return
	_camera.position = _camera_local
	_camera.position_smoothing_enabled = _camera_suavizava
	_camera = null
	if is_instance_valid(passageira):
		CameraJogador.encaixar(passageira)


# --- AVISOS E BALÃO ---

func _ao_entrar(corpo: Node2D) -> void:
	if corpo.is_in_group("player"):
		_jogador_dentro = true


func _ao_sair(corpo: Node2D) -> void:
	if corpo.is_in_group("player"):
		_jogador_dentro = false
		_esconder_aviso()


func _atualizar_aviso() -> void:
	var mostrar := _jogador_dentro and cena_destino != ""
	if mostrar == _aviso_visivel:
		return
	_aviso_visivel = mostrar
	if _exclamacao == null:
		return
	if mostrar:
		PopupFX.mostrar(_exclamacao)
	else:
		PopupFX.esconder(_exclamacao)


func _esconder_aviso() -> void:
	if _aviso_visivel and _exclamacao:
		PopupFX.esconder(_exclamacao)
	_aviso_visivel = false


func _avisar(texto: String) -> void:
	Blockout.aviso_flutuante(get_parent(), global_position + Vector2(0.0, -120.0), texto)


func _tocar_som() -> void:
	if _som and _som.stream:
		_som.play()


# --- APOIO ---

func _esperar(segundos: float) -> void:
	if segundos > 0.0:
		await get_tree().create_timer(segundos).timeout


func _ainda_na_cena() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


# --- RASCUNHO DO POÇO (só no editor) ---

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var fim := Vector2(0.0, _passo_do_poco())
	var cor := Color(0.45, 0.75, 1.0, 0.75)
	# Tracejado à mão: o draw_dashed_line não deixa o traço curto o bastante
	# para ler bem num curso de meio quadrado de tela.
	var passo := 14.0
	var total := absf(fim.y)
	var sentido := signf(fim.y)
	var andado := 0.0
	while andado < total:
		var a := Vector2(0.0, sentido * andado)
		var b := Vector2(0.0, sentido * minf(andado + passo * 0.55, total))
		draw_line(a, b, cor, 2.0)
		andado += passo
	# Contorno de onde a cabine vai parar.
	var tamanho := Vector2(CABINE_LARGURA, CABINE_ALTURA) * escala_da_arte
	draw_rect(Rect2(fim + Vector2(-tamanho.x * 0.5, -tamanho.y), tamanho), cor, false, 2.0)
