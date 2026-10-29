class_name DemoDeFerramenta
extends Control

# --- A BASE DAS TELINHAS DOS TUTORIAIS DE FERRAMENTA ---
#
# A telinha animada da ficha de tutorial (scripts/ui/tutorial_ferramenta.gd) é
# um pedaço de fase em miniatura, com a Cacau usando a ferramenta que acabou
# de ganhar: o bumerangue (demo_bumerangue), a mochila de N₂ (demo_mochila) e
# o maçarico (demo_macarico). As três têm o mesmo esqueleto, que mora aqui:
#
#   o RELÓGIO   _tempo anda de 0 até duracao_da_volta() e recomeça. Cada
#               telinha escreve os instantes do roteiro dela em constantes T_...,
#               e _passou(t) diz se o relógio cruzou um deles neste quadro (é
#               assim que uma faísca dispara uma vez só);
#   a CORTINA   (nó Cortina) escurece o fim de uma volta e abre a seguinte;
#   a TECLA     (nó Tecla) a tecla da ação — ou, de controle na mão, o botão —
#               no alto da telinha. Ela não afunda em loop: afunda UMA vez, no
#               instante em que a Cacau age. É o que liga "apertei isto" a "ela
#               fez aquilo";
#   a CACAU     (nó Mundo/Cacau) o quadro de cada animação sai do relógio, e
#               não do AnimatedSprite2D tocando sozinho, na velocidade escrita
#               no SpriteFrames dela.
#
# Quem estende não escreve _ready nem _process: escreve os ganchos
# _ao_montar(), _ao_recomecar() e _ao_atualizar(), e diz duracao_da_volta(),
# instante_do_toque(), acao() e cor_da_tecla().

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

## A cortina que escurece o fim de uma volta e abre a seguinte.
const DURACAO_CORTINA := 0.28
## Quanto tempo a tecla fica afundada.
const TECLA_FUNDA := 0.28
## Lado do desenho da tecla na folha, em pixels: o nó Tecla dividido por isto
## dá a ampliação.
const LADO_NA_FOLHA := 16.0
## Tecla escrita (SHIFT, ESPAÇO): o tamanho da letra quando o nome tem mais de
## uma letra — com a letra do tamanho da tecla, a palavra não caberia.
const TAM_TECLA_ESCRITA := 15

var _tempo: float = 0.0
## Onde o relógio estava no quadro anterior, para cada evento disparar uma vez.
var _anterior: float = -1.0

@onready var _mundo: Node2D = $Mundo
@onready var _cacau: AnimatedSprite2D = $Mundo/Cacau
@onready var _cortina: ColorRect = $Cortina
@onready var _tecla: Control = $Tecla


func _ready() -> void:
	# Quem escolhe o quadro da Cacau é o relógio (ver _mostrar_cacau).
	_cacau.stop()
	_tecla.draw.connect(_desenhar_tecla)
	_ao_montar()
	reiniciar()


## Volta ao começo do roteiro (a ficha chama quando termina de entrar, para a
## Cacau não agir com ela ainda subindo).
func reiniciar() -> void:
	_tempo = 0.0
	_recomecar()
	_atualizar()
	_anterior = _tempo


func tecla_apertada() -> bool:
	return _tempo >= instante_do_toque() and _tempo < instante_do_toque() + TECLA_FUNDA


func _process(delta: float) -> void:
	# Um quadro travado (a janela perdeu o foco) não pode pular o roteiro.
	_tempo += minf(delta, 0.1)
	if _tempo >= duracao_da_volta():
		_tempo = fmod(_tempo, duracao_da_volta())
		_recomecar()
	_atualizar()
	_anterior = _tempo


func _recomecar() -> void:
	_anterior = -1.0
	_ao_recomecar()


func _atualizar() -> void:
	_ao_atualizar()
	var fim := duracao_da_volta()
	_cortina.color.a = maxf(1.0 - smoothstep(0.0, DURACAO_CORTINA, _tempo),
		smoothstep(fim - DURACAO_CORTINA, fim, _tempo))
	_tecla.queue_redraw()


# ─────────────────────────────────────────────────────────────
# OS GANCHOS (o que cada telinha escreve)
# ─────────────────────────────────────────────────────────────

## Uma vez, ao abrir: guardar posições e escalas de partida.
func _ao_montar() -> void:
	pass


## O começo de cada volta: o cenário como era antes de a Cacau agir.
func _ao_recomecar() -> void:
	pass


## A cada quadro: cada coisa no lugar em que ela está no instante _tempo.
func _ao_atualizar() -> void:
	pass


## Quanto dura uma volta do roteiro, da cortina abrindo à cortina fechada.
func duracao_da_volta() -> float:
	return 4.0


## Quando a tecla afunda (e a Cacau age).
func instante_do_toque() -> float:
	return 0.75


## A ação do mapa de entrada que a telinha ensina: é dela que saem a tecla e o
## botão do controle desenhados no alto.
func acao() -> StringName:
	return &""


func cor_da_tecla() -> Color:
	return EstiloHUD.ACENTO_PADRAO


# ─────────────────────────────────────────────────────────────
# APOIO
# ─────────────────────────────────────────────────────────────

## True no quadro em que o relógio cruza o instante "t".
func _passou(t: float) -> bool:
	return _anterior < t and _tempo >= t


func _mostrar_cacau(animacao: StringName, quadro: int) -> void:
	if _cacau.animation != animacao:
		_cacau.animation = animacao
	_cacau.frame = quadro


## Quadros por segundo da animação (a escrita no SpriteFrames).
func _velocidade(animacao: StringName) -> float:
	return maxf(_cacau.sprite_frames.get_animation_speed(animacao), 1.0)


## Quanto dura a animação inteira, na velocidade dela.
func _duracao(animacao: StringName) -> float:
	return _cacau.sprite_frames.get_frame_count(animacao) / _velocidade(animacao)


## Parada, respirando: a "idle" em loop, contada a partir de "desde".
func _mostrar_parada(desde: float) -> void:
	var quadros := maxi(_cacau.sprite_frames.get_frame_count(&"idle"), 1)
	_mostrar_cacau(&"idle", int(maxf(desde, 0.0) * _velocidade(&"idle")) % quadros)


func _disparar(particulas: CPUParticles2D) -> void:
	particulas.restart()
	particulas.emitting = true


# ─────────────────────────────────────────────────────────────
# A TECLA NO ALTO
# ─────────────────────────────────────────────────────────────

## A mesma tecla desenhada dos equipamentos (o F, o E da folha do teclado) —
## ou, de controle na mão, o botão da ação — do tamanho do nó Tecla.
func _desenhar_tecla() -> void:
	var centro := _tecla.size * 0.5
	var lado := minf(_tecla.size.x, _tecla.size.y)
	var desde := _tempo - instante_do_toque()
	var funda := tecla_apertada()
	var cor := cor_da_tecla()

	# Anel que se abre a partir da tecla no toque.
	if desde >= 0.0 and desde < 0.45:
		var onda := desde / 0.45
		var anel := Rect2(centro - Vector2(lado, lado) * 0.5, Vector2(lado, lado)).grow(1.0 + onda * 11.0)
		EstiloHUD.aro(_tecla, anel, EstiloHUD.com_alfa(cor, (1.0 - onda) * 0.9), 2.0)

	var texto := BotoesControle.tecla_da_acao(acao())
	var desenho := EstiloHUD.desenho_da_tecla(texto, acao())
	if desenho != "":
		# Solta no quadro 0; no toque, os três quadros de apertar da folha. O
		# botão sem esses quadros (o R2) desce dois pixels e acende.
		var quadro := 0
		var tom := Color.WHITE
		if funda:
			if BotoesControle.anima(desenho):
				quadro = 1 + mini(int(desde / TECLA_FUNDA * 3.0), 2)
			else:
				centro.y += 2.0
				tom = Color(0.8, 0.9, 1.0)
		BotoesControle.desenhar(_tecla, centro, desenho, lado / LADO_NA_FOLHA, tom, quadro)
		return

	# Tecla sem desenho na folha: a tampa escrita, que desce dois pixels e acende.
	if funda:
		centro.y += 2.0
	var tampa_cor := cor.lightened(0.45) if funda else cor
	var tamanho := maxi(int(lado) - 11, 8) if texto.length() <= 1 else TAM_TECLA_ESCRITA
	var largura := EstiloHUD.tecla(_tecla, FONTE, centro, texto, tampa_cor, 1.0, tamanho)
	if funda:
		var tampa := Vector2(largura, lado)
		EstiloHUD.bloco(_tecla, Rect2(centro - tampa * 0.5, tampa), EstiloHUD.com_alfa(cor, 0.30))
