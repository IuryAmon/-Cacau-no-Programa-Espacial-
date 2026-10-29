class_name DemoMacarico
extends DemoDeFerramenta

# --- O QUADRADINHO DO TUTORIAL: A CACAU DERRETENDO A PORTA DE METAL ---
#
# A telinha que acompanha o tutorial do maçarico (a ficha é o
# scripts/ui/tutorial_ferramenta.gd): a Cacau parada diante de uma porta de
# metal, a tecla da interação afunda (E; o □, de controle na mão), ela acende
# o maçarico e baixa a máscara, e a porta faz o mesmo caminho da de verdade
# (scripts/fases/porta_metal_macarico.gd): esquenta até virar brasa, escorre
# de cima para baixo até virar poça e esfria de volta à cor de metal. Ela
# guarda o maçarico, a cena escurece e recomeça.
#
# A porta é a do jogo, na mesma escala (2×), com o mesmo shader de metal
# incandescente; só os tempos dos três atos estão um pouco mais curtos, para
# a volta caber numa telinha.
#
# ONDE AJUSTAR CADA COISA (tudo é nó, na cena scenes/ui/demo_macarico.tscn):
#   o nó raiz       o quanto do cenário aparece (300×240: a porta é alta) e a
#                   ampliação na ficha (a Escala: 2 = o dobro do tamanho do jogo)
#   Mundo/Cenario   a parede e o piso (tiles das fases, sem colisão)
#   Mundo/Porta, Mundo/Derretimento   a folha fechada e os 16 quadros do
#                   derretimento (os dois com o mesmo material de brasa)
#   Mundo/BrilhoPorta   o clarão laranja da brasa na parede
#   Mundo/Fagulhas, Mundo/Fumaca      as da porta de verdade
#   Mundo/Cacau     onde ela fica, e as animações ("idle" e "usando_macarico").
#                   O filho Chama é a ponta do maçarico, onde acende o
#                   Mundo/BrilhoChama (o azul da luz do maçarico do jogo)
#   Tecla           onde a tecla (ou o botão do controle) aparece
# Os TEMPOS são as constantes logo abaixo.

## Ação do mapa de entrada que a telinha ensina: o maçarico não tem botão
## próprio, acende no E da interação (□ no controle).
const ACAO := &"interact"
## O laranja do maçarico (o do CatalogoFerramentas).
const COR_TECLA := Color(1.0, 0.62, 0.22)

const ANIM_PARADA := &"idle"
const ANIM_MACARICO := &"usando_macarico"
const ANIM_PORTA := &"derretendo"

# --- Roteiro de uma volta (segundos) ---
## A tecla afunda e ela começa o gesto (os 3 quadros da pose, a 20 por segundo).
const T_APERTAR := 0.75
const DURACAO_GESTO := 0.15
## Máscara baixada e chama acesa: a porta começa a esquentar.
const T_ACESO := T_APERTAR + DURACAO_GESTO
## Os três atos da porta de verdade, mais curtos.
const DURACAO_PREAQUECIMENTO := 0.7
const DURACAO_DERRETIMENTO := 1.8
const DURACAO_RESFRIAMENTO := 1.2
const T_DERRETER := T_ACESO + DURACAO_PREAQUECIMENTO
## A folha caiu: ela guarda o maçarico e a poça esfria.
const T_CAIU := T_DERRETER + DURACAO_DERRETIMENTO
const T_FRIO := T_CAIU + DURACAO_RESFRIAMENTO
const T_FIM := T_FRIO + 0.4

## O quanto o topo da folha esquenta antes da base (o da porta de verdade).
const GRADIENTE_INICIAL := 0.35
## O clarão da brasa e o da chama, no máximo.
const BRILHO_PORTA := 0.5
const BRILHO_CHAMA := 0.6

var _calor: float = 0.0

@onready var _porta: Sprite2D = $Mundo/Porta
@onready var _derretimento: AnimatedSprite2D = $Mundo/Derretimento
@onready var _tinta: ShaderMaterial = $Mundo/Porta.material as ShaderMaterial
@onready var _brilho_porta: Sprite2D = $Mundo/BrilhoPorta
@onready var _fagulhas: CPUParticles2D = $Mundo/Fagulhas
@onready var _fumaca: CPUParticles2D = $Mundo/Fumaca
@onready var _chama: Marker2D = $Mundo/Cacau/Chama
@onready var _brilho_chama: Sprite2D = $Mundo/BrilhoChama


func duracao_da_volta() -> float:
	return T_FIM


func instante_do_toque() -> float:
	return T_APERTAR


func acao() -> StringName:
	return ACAO


func cor_da_tecla() -> Color:
	return COR_TECLA


## A chama está acesa (da máscara baixada até a folha cair)?
func chama_acesa() -> bool:
	return _tempo >= T_ACESO and _tempo < T_CAIU


## A folha já escorreu inteira e virou poça?
func porta_derretida() -> bool:
	return _tempo >= T_CAIU


## A temperatura da porta agora, de 0 (metal frio) a 1 (fusão).
func calor() -> float:
	return _calor


func _ao_recomecar() -> void:
	_porta.visible = true
	_derretimento.visible = false
	_derretimento.animation = ANIM_PORTA
	_derretimento.frame = 0
	_fagulhas.emitting = false
	_fumaca.emitting = false
	_aplicar_calor(0.0, GRADIENTE_INICIAL)


func _ao_atualizar() -> void:
	_animar_cacau()

	# A brasa: sobe no pré-aquecimento, fica no auge enquanto escorre e desce
	# no resfriamento (as curvas dos tweens da porta de verdade).
	var calor_agora := 0.0
	if _tempo >= T_ACESO and _tempo < T_DERRETER:
		calor_agora = 1.0 - cos(clampf((_tempo - T_ACESO) / DURACAO_PREAQUECIMENTO, 0.0, 1.0) * PI * 0.5)
	elif _tempo >= T_DERRETER and _tempo < T_CAIU:
		calor_agora = 1.0
	elif _tempo >= T_CAIU and _tempo < T_FRIO:
		calor_agora = 1.0 - sin(clampf((_tempo - T_CAIU) / DURACAO_RESFRIAMENTO, 0.0, 1.0) * PI * 0.5)

	# A folha escorrendo: os 16 quadros cabem no derretimento, e o "topo mais
	# quente" some no caminho (poça não tem topo).
	var derretendo := _tempo >= T_DERRETER
	_porta.visible = not derretendo
	_derretimento.visible = derretendo
	var gradiente := GRADIENTE_INICIAL
	if derretendo:
		var quadros := _derretimento.sprite_frames.get_frame_count(ANIM_PORTA)
		var andamento := clampf((_tempo - T_DERRETER) / DURACAO_DERRETIMENTO, 0.0, 1.0)
		_derretimento.frame = mini(int(andamento * quadros), quadros - 1)
		gradiente = lerpf(GRADIENTE_INICIAL, 0.0, float(_derretimento.frame) / float(maxi(quadros - 1, 1)))
	_aplicar_calor(calor_agora, gradiente)

	_fagulhas.emitting = chama_acesa()
	_fumaca.emitting = _tempo >= T_ACESO and _tempo < T_FRIO

	# O azul da ponta do maçarico, tremendo como a luz dele no jogo.
	_brilho_chama.position = _cacau.transform * _chama.position
	_brilho_chama.modulate.a = BRILHO_CHAMA * randf_range(0.82, 1.12) if chama_acesa() else 0.0


## Parada até o toque; no toque, o gesto de acender, e a pose segura até a
## folha cair; depois o gesto ao contrário (guardando) e a "idle" de novo.
func _animar_cacau() -> void:
	var quadros := _cacau.sprite_frames.get_frame_count(ANIM_MACARICO)
	var por_segundo := _velocidade(ANIM_MACARICO)
	if _tempo < T_APERTAR:
		_mostrar_parada(_tempo)
	elif _tempo < T_CAIU:
		_mostrar_cacau(ANIM_MACARICO, mini(int((_tempo - T_APERTAR) * por_segundo), quadros - 1))
	elif _tempo < T_CAIU + DURACAO_GESTO:
		_mostrar_cacau(ANIM_MACARICO, maxi(quadros - 1 - int((_tempo - T_CAIU) * por_segundo), 0))
	else:
		_mostrar_parada(_tempo - T_CAIU - DURACAO_GESTO)


func _aplicar_calor(valor: float, gradiente: float) -> void:
	_calor = valor
	if _tinta:
		_tinta.set_shader_parameter("calor", valor)
		_tinta.set_shader_parameter("gradiente_vertical", gradiente)
	_brilho_porta.modulate.a = BRILHO_PORTA * valor * (randf_range(0.85, 1.12) if valor > 0.0 else 1.0)
