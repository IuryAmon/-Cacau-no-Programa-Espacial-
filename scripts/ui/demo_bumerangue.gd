class_name DemoBumerangue
extends Control

# --- O QUADRADINHO DO TUTORIAL: A CACAU ARREMESSANDO O BUMERANGUE ---
#
# A telinha animada que acompanha o tutorial do bumerangue (a ficha é o
# scripts/ui/tutorial_ferramenta.gd): a tecla afunda, a Cacau faz o gesto, o
# bumerangue vai até a caixa elétrica, a tampa arrebenta e ele volta para a
# mão — e ela volta a ficar parada, respirando, como no jogo. Depois a cena
# escurece, a caixa volta inteira e tudo recomeça.
#
# É um pedaço da fase: os tiles do cenário são os do mapa (a parede de placas
# rebitadas, o piso de faixa amarela e, em cima da caixa, as placas com os
# cabos dela subindo), a arte está nas escalas do jogo (Cacau 1,5×, caixa 2×,
# bumerangue 2,4×) e as faíscas são as da caixa de verdade.
#
# ONDE AJUSTAR CADA COISA (tudo é nó, na cena scenes/ui/demo_bumerangue.tscn):
#   o nó raiz      o quanto do cenário aparece (o Tamanho, 300×210) e a
#                  AMPLIAÇÃO com que ele vai para a ficha (a Escala: 2 = o dobro
#                  do tamanho do jogo). A ficha do tutorial se mede pelos dois
#   Mundo/Cenario  o fundo: um TileMapLayer com o tileset das fases, para
#                  pintar como se pinta o mapa (parede, cabos, piso). A
#                  colisão dele fica desligada — é só desenho
#   Mundo/Cacau    onde ela fica, e as animações dela ("idle" e
#                  "jogando_bumerangue", com a velocidade de cada uma). O filho
#                  Mao é de onde o bumerangue sai e para onde ele volta
#   Mundo/Caixa    onde a caixa fica. O filho Alvo é o ponto em que o
#                  bumerangue bate
#   Mundo/Bumerangue, Mundo/Rastro   a lâmina e a fita atrás dela
#   Mundo/FaiscasImpacto, Mundo/FaiscasArco   as da caixa elétrica
#   Tecla          onde a tecla (ou o botão do controle) aparece e de que
#                  tamanho: o desenho ocupa o nó inteiro. Hoje fica no alto, no
#                  meio do quadradinho, com 40×40 (2,5× o desenho da folha)
# Os TEMPOS do roteiro são as constantes logo abaixo.

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

## Ação do mapa de entrada que a telinha ensina: é dela que saem a tecla (F) e
## o botão do controle (□) desenhados no canto.
const ACAO := &"arremessar"

const ANIM_INTACTA := &"intacta"
const ANIM_QUEBRANDO := &"quebrando"
const ANIM_PARADA := &"idle"
const ANIM_ARREMESSO := &"jogando_bumerangue"

# --- Roteiro de uma volta (segundos) ---
## A tecla afunda e o braço sai. Antes disso ela só está parada: é o tempo de
## o olho achar a Cacau e a caixa.
const T_APERTAR := 0.75
## Quanto tempo a tecla fica afundada.
const TECLA_FUNDA := 0.28
## O bumerangue se solta da mão um instante depois do toque, no meio do gesto.
const T_SOLTAR := T_APERTAR + 0.08
## A ida perde força até a caixa, como no jogo; a volta acelera.
const DURACAO_IDA := 0.36
const T_ACERTO := T_SOLTAR + DURACAO_IDA
const PAUSA_NA_CAIXA := 0.10
const DURACAO_VOLTA := 0.34
const T_PEGAR := T_ACERTO + PAUSA_NA_CAIXA + DURACAO_VOLTA
## A caixa fica um tempo quebrada e estalando antes de a cena recomeçar.
const T_FIM := 3.9
## A cortina que escurece o fim de uma volta e abre a seguinte.
const DURACAO_CORTINA := 0.28

## Rotações do bumerangue por segundo (a mesma do voo de verdade).
const GIRO := TAU * 4.2
## Estufão da lâmina no instante da batida.
const PANCADA := 0.4
const DURACAO_PANCADA := 0.2
## Tremor da cena na batida, em pixels, e por quanto tempo.
const TREMOR := 4.0
const DURACAO_TREMOR := 0.25
## Depois de quebrada, a caixa estala de tempos em tempos.
const PRIMEIRO_ARCO := 0.45
const INTERVALO_ARCO := 0.62
const RASTRO_PONTOS := 10

## O halo quente que respira em volta da caixa inteira (o aviso de alvo).
const BRILHO_MIN := 0.12
const BRILHO_MAX := 0.38
const RESPIRACAO := 1.4

const COR_TECLA := Color(0.55, 0.85, 0.45)
## Lado do desenho da tecla na folha, em pixels: o nó Tecla dividido por isto
## dá a ampliação.
const LADO_NA_FOLHA := 16.0

var _tempo: float = 0.0
## Onde o relógio estava no quadro anterior, para cada evento disparar uma vez.
var _anterior: float = -1.0
var _trilha := PackedVector2Array()
var _origem_do_mundo := Vector2.ZERO
var _escala_do_bumerangue := Vector2.ONE

@onready var _mundo: Node2D = $Mundo
@onready var _cacau: AnimatedSprite2D = $Mundo/Cacau
@onready var _mao: Marker2D = $Mundo/Cacau/Mao
@onready var _caixa: AnimatedSprite2D = $Mundo/Caixa
@onready var _alvo: Marker2D = $Mundo/Caixa/Alvo
@onready var _brilho: Sprite2D = $Mundo/BrilhoAlvo
@onready var _rastro: Line2D = $Mundo/Rastro
@onready var _bumerangue: Sprite2D = $Mundo/Bumerangue
@onready var _faiscas_impacto: CPUParticles2D = $Mundo/FaiscasImpacto
@onready var _faiscas_arco: CPUParticles2D = $Mundo/FaiscasArco
@onready var _cortina: ColorRect = $Cortina
@onready var _tecla: Control = $Tecla


func _ready() -> void:
	_origem_do_mundo = _mundo.position
	_escala_do_bumerangue = _bumerangue.scale
	# Quem escolhe o quadro da Cacau é o roteiro (ver _animar_cacau).
	_cacau.stop()
	_tecla.draw.connect(_desenhar_tecla)
	reiniciar()


## Volta ao começo do roteiro (a ficha chama quando termina de entrar, para o
## primeiro arremesso não acontecer com ela ainda subindo).
func reiniciar() -> void:
	_tempo = 0.0
	_recomecar()
	_atualizar()
	_anterior = _tempo


## A caixa já foi arrebentada nesta volta?
func caixa_quebrada() -> bool:
	return _tempo >= T_ACERTO


func bumerangue_no_ar() -> bool:
	return _tempo >= T_SOLTAR and _tempo < T_PEGAR


func tecla_apertada() -> bool:
	return _tempo >= T_APERTAR and _tempo < T_APERTAR + TECLA_FUNDA


func _process(delta: float) -> void:
	# Um quadro travado (a janela perdeu o foco) não pode pular o arremesso.
	_tempo += minf(delta, 0.1)
	if _tempo >= T_FIM:
		_tempo = fmod(_tempo, T_FIM)
		_recomecar()
	_atualizar()
	_anterior = _tempo


func _recomecar() -> void:
	_anterior = -1.0
	_trilha.clear()
	_rastro.clear_points()
	_bumerangue.visible = false
	_caixa.stop()
	_caixa.animation = ANIM_INTACTA
	_caixa.frame = 0
	# Só desliga: as últimas faíscas da volta anterior acabam de morrer atrás da
	# cortina. (restart() aqui soltaria uma rajada nova na caixa inteira.)
	_faiscas_impacto.emitting = false
	_faiscas_arco.emitting = false
	_mundo.position = _origem_do_mundo


func _atualizar() -> void:
	var mao: Vector2 = _cacau.transform * _mao.position
	var alvo: Vector2 = _caixa.transform * _alvo.position

	_animar_cacau()

	# A batida: tampa, faíscas e tremor saem no mesmo quadro, como no jogo.
	if _passou(T_ACERTO):
		_caixa.play(ANIM_QUEBRANDO)
		_disparar(_faiscas_impacto)
	if _estalou():
		_disparar(_faiscas_arco)

	var voando := bumerangue_no_ar()
	_bumerangue.visible = voando
	if voando:
		_bumerangue.position = _posicao_do_voo(mao, alvo)
		_bumerangue.rotation = (_tempo - T_SOLTAR) * GIRO
		var pancada := 0.0
		if _tempo >= T_ACERTO:
			pancada = clampf(1.0 - (_tempo - T_ACERTO) / DURACAO_PANCADA, 0.0, 1.0)
		_bumerangue.scale = _escala_do_bumerangue * (1.0 + PANCADA * pancada)
	_marcar_rastro(voando)

	var tremor := 0.0
	if _tempo >= T_ACERTO:
		tremor = clampf(1.0 - (_tempo - T_ACERTO) / DURACAO_TREMOR, 0.0, 1.0)
	_mundo.position = _origem_do_mundo + (Vector2(randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)) * TREMOR * tremor).round()

	# O halo quente só existe na caixa inteira: apaga no instante da batida.
	var onda := (sin(_tempo * TAU / RESPIRACAO) + 1.0) * 0.5
	_brilho.modulate.a = 0.0 if caixa_quebrada() else lerpf(BRILHO_MIN, BRILHO_MAX, onda)

	_cortina.color.a = maxf(1.0 - smoothstep(0.0, DURACAO_CORTINA, _tempo),
		smoothstep(T_FIM - DURACAO_CORTINA, T_FIM, _tempo))
	_tecla.queue_redraw()


## Parada, ela roda a "idle"; no toque, o gesto do braço uma vez; acabou o
## gesto, a "idle" recomeça do primeiro quadro. O quadro sai do relógio do
## roteiro, e a velocidade de cada animação é a escrita no SpriteFrames dela
## (o gesto está mais lento que no jogo, para dar para ler num desenho pequeno).
func _animar_cacau() -> void:
	var gesto := _tempo - T_APERTAR
	if gesto >= 0.0 and gesto < duracao_do_gesto():
		_mostrar_cacau(ANIM_ARREMESSO, int(gesto * _velocidade(ANIM_ARREMESSO)))
		return
	var parada := _tempo if gesto < 0.0 else gesto - duracao_do_gesto()
	var quadros := _cacau.sprite_frames.get_frame_count(ANIM_PARADA)
	_mostrar_cacau(ANIM_PARADA, int(parada * _velocidade(ANIM_PARADA)) % maxi(quadros, 1))


## Quanto dura o gesto do arremesso, do toque até ela voltar a ficar parada.
func duracao_do_gesto() -> float:
	return _cacau.sprite_frames.get_frame_count(ANIM_ARREMESSO) / _velocidade(ANIM_ARREMESSO)


func _velocidade(animacao: StringName) -> float:
	return maxf(_cacau.sprite_frames.get_animation_speed(animacao), 1.0)


func _mostrar_cacau(animacao: StringName, quadro: int) -> void:
	if _cacau.animation != animacao:
		_cacau.animation = animacao
	_cacau.frame = quadro


## Ida em linha reta perdendo força, um respiro na caixa, volta acelerando.
func _posicao_do_voo(mao: Vector2, alvo: Vector2) -> Vector2:
	if _tempo < T_ACERTO:
		var ida := clampf((_tempo - T_SOLTAR) / DURACAO_IDA, 0.0, 1.0)
		return mao.lerp(alvo, 1.0 - (1.0 - ida) * (1.0 - ida))
	var volta := clampf((_tempo - T_ACERTO - PAUSA_NA_CAIXA) / DURACAO_VOLTA, 0.0, 1.0)
	return alvo.lerp(mao, volta * volta)


func _marcar_rastro(voando: bool) -> void:
	if voando:
		var ultimo := _trilha.size() - 1
		if ultimo < 0 or _trilha[ultimo].distance_squared_to(_bumerangue.position) >= 1.0:
			_trilha.append(_bumerangue.position)
		while _trilha.size() > RASTRO_PONTOS:
			_trilha.remove_at(0)
	elif not _trilha.is_empty():
		# Apanhado: a fita escoa pela cauda em vez de sumir de uma vez.
		_trilha.remove_at(0)
	_rastro.points = _trilha


## True no quadro em que o relógio cruza o instante "t".
func _passou(t: float) -> bool:
	return _anterior < t and _tempo >= t


## True no quadro de cada estalo da caixa quebrada (até a cortina fechar).
func _estalou() -> bool:
	var inicio := T_ACERTO + PRIMEIRO_ARCO
	if _tempo < inicio or _tempo > T_FIM - DURACAO_CORTINA:
		return false
	return floorf((_tempo - inicio) / INTERVALO_ARCO) > floorf((_anterior - inicio) / INTERVALO_ARCO)


func _disparar(particulas: CPUParticles2D) -> void:
	particulas.restart()
	particulas.emitting = true


# --- A tecla no canto -----------------------------------------------------------

## A mesma tecla desenhada dos equipamentos (o F da folha do teclado) — ou, de controle
## na mão, o botão da ação — do tamanho do nó Tecla. Aqui ela não afunda em
## loop: afunda UMA vez, no instante em que a Cacau arremessa. É o que liga
## "apertei isto" a "ela fez aquilo".
func _desenhar_tecla() -> void:
	var centro := _tecla.size * 0.5
	var lado := minf(_tecla.size.x, _tecla.size.y)
	var desde := _tempo - T_APERTAR
	var funda := tecla_apertada()

	# Anel que se abre a partir da tecla no toque.
	if desde >= 0.0 and desde < 0.45:
		var onda := desde / 0.45
		var anel := Rect2(centro - Vector2(lado, lado) * 0.5, Vector2(lado, lado)).grow(1.0 + onda * 11.0)
		EstiloHUD.aro(_tecla, anel, EstiloHUD.com_alfa(COR_TECLA, (1.0 - onda) * 0.9), 2.0)

	var texto := BotoesControle.tecla_da_acao(ACAO)
	var desenho := EstiloHUD.desenho_da_tecla(texto, ACAO)
	if desenho != "":
		# Solta no quadro 0; no toque, os três quadros de apertar da folha.
		var quadro := 0
		if funda:
			quadro = 1 + mini(int(desde / TECLA_FUNDA * 3.0), 2)
		BotoesControle.desenhar(_tecla, centro, desenho, lado / LADO_NA_FOLHA, Color.WHITE, quadro)
		return

	# Tecla sem desenho na folha: a tampa escrita, que desce dois pixels e acende.
	if funda:
		centro.y += 2.0
	var cor := COR_TECLA.lightened(0.45) if funda else COR_TECLA
	var tamanho := maxi(int(lado) - 11, 8)
	var largura := EstiloHUD.tecla(_tecla, FONTE, centro, texto, cor, 1.0, tamanho)
	if funda:
		var tampa := Vector2(largura, lado)
		EstiloHUD.bloco(_tecla, Rect2(centro - tampa * 0.5, tampa),
			EstiloHUD.com_alfa(COR_TECLA, 0.30))
