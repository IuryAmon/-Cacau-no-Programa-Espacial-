@tool
class_name SerraEletrica
extends EspinhosLaser

# --- SERRA ELÉTRICA (ARMADILHA DE CHÃO) ---
#
# É a MESMA armadilha dos espinhos de laser, com outra lâmina: a serra sobe do
# piso girando, mata quem encosta e recolhe quando a CAIXA ELÉTRICA que a
# alimenta é arrebentada com o bumerangue. Toda a lógica — corrente, atraso,
# animações, som em loop, dano letal, barrar caixas empurráveis — vem de
# EspinhosLaser; aqui só muda a arte:
#
#   "ativando"     saw_activate    (13 quadros, a lâmina saindo do chão)
#   "armado"       saw_idle        (6 quadros em loop, a lâmina girando)
#   "desativando"  saw_deactivate  (13 quadros, recolhendo; o último quadro é
#                                   a pose de descanso, quase toda escondida)
#
# A ARTE VEM EM PÉ (lâmina saindo de uma parede, para a direita) e o nó Visual
# a deita com uma rotação de +90°: o disco passa a apontar para BAIXO e a base
# reta fica por cima, na altura em que o nó estiver.
#
# --- O SOM DA SERRA (três camadas, três nós) ---
#
#   SomLaser    "SerraRodando.mp3" em loop — o motor. Quem liga e desliga é o
#               pai, junto com a lâmina subindo e recolhendo (o nome do nó é do
#               pai; é por ele que o EspinhosLaser acha o player).
#               O VOLUME É BAIXO (-22 dB) e a queda é curta (700 px, atenuação
#               2.0) de propósito: serras andam em banco de três ou quatro lado
#               a lado, e cada uma toca o loop inteiro. O que se ouve é a soma
#               de todas — no nível de uma só, um banco de quatro abafa a fase.
#   SomParando  "SerraParando.mp3" do segundo 7,00 ao 8,40: a desaceleração,
#               disparada quando a serra começa a recolher.
#   SomCorte    "SerraHit.mp3" do 1,70 ao 2,07: a lâmina pegando alguém, por
#               cima do gritinho que o player já toca sozinho.
#
# Os dois trechos terminam com um fade curto porque são recortes no meio de um
# arquivo maior — cortar seco no meio da onda estala.
#
# COMO EDITAR NO EDITOR: ver o cabeçalho de espinhos_laser.gd — os nós e os
# exports são exatamente os mesmos. E "segmentos" enfileira serras lado a lado
# (64 px cada, com escala 2); a cena vem com 1, que é o normal para uma serra.
#
# Herdar traz junto o `criar()` de EspinhosLaser, que instancia a cena dos
# ESPINHOS (a constante CENA é do pai e o GDScript não deixa redefinir). Para
# soltar uma serra por código, instancie CENA_SERRA na mão.

const CENA_SERRA := "res://scenes/fases/componentes/serra_eletrica.tscn"

## Trecho de "SerraParando.mp3" que vale como a serra desacelerando.
const PARANDO_INICIO := 7.0
const PARANDO_FIM := 8.4
## Trecho de "SerraHit.mp3" que vale como a lâmina pegando alguém.
const CORTE_INICIO := 1.7
const CORTE_FIM := 2.07
## Fade no finalzinho de cada trecho.
const FADE_TRECHO := 0.2

## Volumes que os nós têm no editor: o fade mexe no volume_db, então o valor
## de cada um fica guardado para o próximo disparo começar no nível certo.
var _volume_parando: float = 0.0
var _volume_corte: float = 0.0
var _fade_parando: Tween = null
var _fade_corte: Tween = null

@onready var _som_parando: AudioStreamPlayer2D = get_node_or_null("SomParando")
@onready var _som_corte: AudioStreamPlayer2D = get_node_or_null("SomCorte")


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	if _som_parando:
		_volume_parando = _som_parando.volume_db
	if _som_corte:
		_volume_corte = _som_corte.volume_db


## Recolher a serra troca o motor pela desaceleração: o loop de "SerraRodando"
## sai de cena num fade curto e o trecho de "SerraParando" assume, por cima da
## animação de recolhimento.
func desarmar(com_animacao: bool = true) -> void:
	var estava_girando: bool = not _recolhido
	super(com_animacao)
	if not estava_girando:
		return
	_desligar_som()  # sem espera: o motor cala já, quem termina é o outro som
	_fade_parando = _tocar_trecho(_som_parando, _volume_parando, _fade_parando,
		PARANDO_INICIO, PARANDO_FIM)


## A lâmina pegou alguém (gancho do EspinhosLaser).
func _ao_ferir(_corpo: Node2D) -> void:
	_fade_corte = _tocar_trecho(_som_corte, _volume_corte, _fade_corte,
		CORTE_INICIO, CORTE_FIM)


## Toca um pedaço do arquivo: começa em `inicio`, segura o volume cheio e some
## no finalzinho, parando em `fim`. Devolve o tween para quem chamou guardar —
## é ele que cancela um disparo anterior que ainda esteja no ar.
func _tocar_trecho(player: AudioStreamPlayer2D, volume: float, fade_atual: Tween,
		inicio: float, fim: float) -> Tween:
	if player == null or player.stream == null or Engine.is_editor_hint():
		return null
	if fade_atual and fade_atual.is_valid():
		fade_atual.kill()

	player.volume_db = volume
	player.play(inicio)

	var duracao: float = maxf(fim - inicio, 0.05)
	var fade: float = minf(FADE_TRECHO, duracao)
	var fade_novo := create_tween()
	if duracao > fade:
		fade_novo.tween_interval(duracao - fade)
	fade_novo.tween_property(player, "volume_db", volume - 30.0, fade)
	fade_novo.tween_callback(player.stop)
	return fade_novo
