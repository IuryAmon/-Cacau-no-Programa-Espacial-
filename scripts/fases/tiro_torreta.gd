class_name TiroTorreta
extends Area2D

# --- TIRO DA TORRETA ---
#
# Uma bala de energia que sai da boca do canhão, corre depressa no rumo em que
# foi solta e morre no primeiro corpo que encontrar: fere quem sabe levar dano
# e se apaga em qualquer parede, caixa ou obstáculo.
#
# Ela entorta um tiquinho atrás da personagem, e o tiquinho é de propósito: o
# desvio inteiro cabe em sete graus ("desvio_maximo_graus"), feitos devagar
# ("curvatura_graus"), o que a olho nu nem parece curva — parece que a torreta
# mirou bem. Serve só para fechar a fresta de quem desviou tarde demais; quem
# se mexe cedo escapa igual, porque a bala nunca vai atrás. É por isso que a
# torreta gasta dez quadros carregando antes de soltar: esse tempo é o aviso.
#
# COMO EDITAR NO EDITOR (tudo é nó ou export):
#   Sprite       slot da arte. Enquanto estiver vazio, o Placeholder aparece;
#                solte um PNG aqui e o retângulo some sozinho.
#   Placeholder  o desenho provisório — núcleo claro e rastro. O nó inteiro
#                gira junto com o tiro, então ele sempre aponta para frente.
#   Colisao      o hitbox. Arraste as alças à vontade.
#   Luz          o brilho que a bala espalha ao passar (o blecaute agradece).

const CENA := "res://scenes/fases/componentes/tiro_torreta.tscn"

@export var velocidade: float = 760.0
@export var dano: int = 1
## Distância máxima antes de o tiro se apagar sozinho — nenhuma bala fica
## viajando para sempre fora da tela.
@export var alcance: float = 1500.0
## Força do empurrão em quem leva o tiro. O sentido é o do próprio tiro.
@export var recuo: float = 0.9

@export_group("Curva")
## Quanto a bala consegue torcer o rumo por segundo, em graus. Vale 0 para tiro
## em linha reta pura, como era antes.
@export_range(0.0, 720.0, 5.0) var curvatura_graus: float = 30.0
## Teto do desvio em relação ao rumo de saída. É o que separa "leve curva" de
## míssil teleguiado: chegando nesse limite a bala desiste e segue reto. Sete
## graus é quase invisível a olho nu — o bastante para a bala fechar a fresta
## de quem se mexeu tarde, e de menos para perseguir alguém.
@export_range(0.0, 180.0, 1.0) var desvio_maximo_graus: float = 7.0
## A origem da personagem fica nos PÉS. A curva mira este tanto acima dela, na
## altura do peito — igual à torreta, senão a bala é puxada para o chão.
@export_range(0.0, 96.0, 1.0) var altura_do_alvo: float = 28.0

## Quem disparou. O tiro nunca acerta o próprio atirador.
var atirador: Node2D = null

var _direcao: Vector2 = Vector2.RIGHT
## Rumo com que a bala saiu do cano. O desvio máximo é medido a partir DELE, e
## não do rumo atual — medido do atual, a curva se somaria sem teto nenhum.
var _rumo_inicial: float = 0.0
var _percorrido: float = 0.0
var _morrendo: bool = false
var _player: Node2D = null


## Cria, aponta e solta um tiro no mundo.
##
## `pai` é quem segura o nó — use um nó da FASE, nunca a própria torreta: a
## bala tem que continuar viajando mesmo que a torreta seja desligada ou saia
## de cena no meio do caminho.
static func disparar(pai: Node2D, origem_global: Vector2, direcao: Vector2,
		config: Dictionary = {}) -> TiroTorreta:
	var tiro: TiroTorreta = load(CENA).instantiate()
	for chave in config:
		tiro.set(chave, config[chave])
	tiro.apontar(direcao)
	# Posição e giro em coordenadas do PAI, e não em global: a entrada na
	# árvore pode ser adiada (ver Blockout.adicionar) e um global_position
	# escrito antes disso se perderia no caminho.
	tiro.position = pai.to_local(origem_global)
	tiro.rotation = direcao.angle() - pai.global_rotation
	Blockout.adicionar(pai, tiro)
	return tiro


## Rumo de saída da bala — e o centro do cone em que ela pode curvar depois.
## Escreva ANTES de soltá-la.
func apontar(direcao: Vector2) -> void:
	if direcao.length_squared() > 0.0001:
		_direcao = direcao.normalized()
		_rumo_inicial = _direcao.angle()


func _ready() -> void:
	var sprite: Sprite2D = get_node_or_null("Sprite")
	var placeholder: Node2D = get_node_or_null("Placeholder")
	Blockout.aplicar_arte(sprite, placeholder)
	body_entered.connect(_ao_encostar)


func _physics_process(delta: float) -> void:
	if _morrendo:
		return
	# Tela de puzzle/diálogo aberta: a bala espera junto. Não é justo apanhar
	# de um tiro que atravessou a tela enquanto a jogadora lia.
	if Interacao.ocupada():
		return

	_curvar(delta)
	var passo := velocidade * delta
	global_position += _direcao * passo
	_percorrido += passo
	if _percorrido >= alcance:
		_apagar()


## Torce o rumo um tiquinho atrás da personagem, com dois freios: a bala vira
## no máximo "curvatura_graus" por segundo e nunca se afasta mais que
## "desvio_maximo_graus" do rumo com que saiu do cano.
func _curvar(delta: float) -> void:
	if curvatura_graus <= 0.0 or desvio_maximo_graus <= 0.0:
		return
	var alvo := _alvo()
	if alvo == null:
		return

	var desejado := alvo.global_position - Vector2(0, altura_do_alvo) - global_position
	if desejado.length_squared() < 1.0:
		return

	var giro := rotate_toward(_direcao.angle(), desejado.angle(),
		deg_to_rad(curvatura_graus) * delta)
	var limite := deg_to_rad(desvio_maximo_graus)
	var desvio := clampf(angle_difference(_rumo_inicial, giro), -limite, limite)
	_direcao = Vector2.RIGHT.rotated(_rumo_inicial + desvio)
	# O nó inteiro gira junto: rastro, núcleo e luz seguem apontando para frente.
	global_rotation = _direcao.angle()


## A personagem viva. Null enquanto ela não existir ou já tiver caído — a bala
## não fica corrigindo a mira atrás de um corpo no chão.
func _alvo() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return null
	if "current_health" in _player and _player.current_health <= 0:
		return null
	return _player


## Primeiro corpo no caminho: fere se der para ferir, e acaba ali de todo
## jeito. Uma parede, uma caixa empurrada para o lugar certo ou o próprio
## corpo da personagem — qualquer um deles come o tiro.
func _ao_encostar(corpo: Node2D) -> void:
	if _morrendo or corpo == atirador:
		return
	if corpo.has_method("take_damage"):
		corpo.take_damage(dano, _direcao * recuo)
	_apagar()


## Fim de linha: para de andar, para de colidir e some num estalo curto.
func _apagar() -> void:
	if _morrendo:
		return
	_morrendo = true
	set_deferred("monitoring", false)

	var estalo := create_tween().set_parallel()
	estalo.tween_property(self, "scale", scale * 1.8, 0.08)
	estalo.tween_property(self, "modulate:a", 0.0, 0.08)
	estalo.chain().tween_callback(queue_free)
