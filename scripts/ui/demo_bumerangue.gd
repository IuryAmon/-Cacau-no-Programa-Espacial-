class_name DemoBumerangue
extends DemoDeFerramenta

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
# Os TEMPOS do roteiro são as constantes logo abaixo. O relógio, a cortina, a
# tecla e o quadro da Cacau são os de toda telinha de tutorial
# (scripts/ui/demo_de_ferramenta.gd).

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

var _trilha := PackedVector2Array()
var _origem_do_mundo := Vector2.ZERO
var _escala_do_bumerangue := Vector2.ONE

@onready var _mao: Marker2D = $Mundo/Cacau/Mao
@onready var _caixa: AnimatedSprite2D = $Mundo/Caixa
@onready var _alvo: Marker2D = $Mundo/Caixa/Alvo
@onready var _brilho: Sprite2D = $Mundo/BrilhoAlvo
@onready var _rastro: Line2D = $Mundo/Rastro
@onready var _bumerangue: Sprite2D = $Mundo/Bumerangue
@onready var _faiscas_impacto: CPUParticles2D = $Mundo/FaiscasImpacto
@onready var _faiscas_arco: CPUParticles2D = $Mundo/FaiscasArco


func _ao_montar() -> void:
	_origem_do_mundo = _mundo.position
	_escala_do_bumerangue = _bumerangue.scale


func duracao_da_volta() -> float:
	return T_FIM


func instante_do_toque() -> float:
	return T_APERTAR


func acao() -> StringName:
	return ACAO


func cor_da_tecla() -> Color:
	return COR_TECLA


## A caixa já foi arrebentada nesta volta?
func caixa_quebrada() -> bool:
	return _tempo >= T_ACERTO


func bumerangue_no_ar() -> bool:
	return _tempo >= T_SOLTAR and _tempo < T_PEGAR


func _ao_recomecar() -> void:
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


func _ao_atualizar() -> void:
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


## Parada, ela roda a "idle"; no toque, o gesto do braço uma vez; acabou o
## gesto, a "idle" recomeça do primeiro quadro. O quadro sai do relógio do
## roteiro, e a velocidade de cada animação é a escrita no SpriteFrames dela
## (o gesto está mais lento que no jogo, para dar para ler num desenho pequeno).
func _animar_cacau() -> void:
	var gesto := _tempo - T_APERTAR
	if gesto >= 0.0 and gesto < duracao_do_gesto():
		_mostrar_cacau(ANIM_ARREMESSO, int(gesto * _velocidade(ANIM_ARREMESSO)))
		return
	_mostrar_parada(_tempo if gesto < 0.0 else gesto - duracao_do_gesto())


## Quanto dura o gesto do arremesso, do toque até ela voltar a ficar parada.
func duracao_do_gesto() -> float:
	return _duracao(ANIM_ARREMESSO)


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


## True no quadro de cada estalo da caixa quebrada (até a cortina fechar).
func _estalou() -> bool:
	var inicio := T_ACERTO + PRIMEIRO_ARCO
	if _tempo < inicio or _tempo > T_FIM - DURACAO_CORTINA:
		return false
	return floorf((_tempo - inicio) / INTERVALO_ARCO) > floorf((_anterior - inicio) / INTERVALO_ARCO)

