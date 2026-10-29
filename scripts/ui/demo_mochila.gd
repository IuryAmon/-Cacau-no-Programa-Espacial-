class_name DemoMochila
extends DemoDeFerramenta

# --- O QUADRADINHO DO TUTORIAL: O JATO DA MOCHILA DE N₂ ---
#
# A telinha que acompanha o tutorial da mochila (a ficha é o
# scripts/ui/tutorial_ferramenta.gd): a Cacau parada na beirada de um vão, a
# tecla do dash afunda (SHIFT; o R2, de controle na mão) e o jato de N₂ a
# arranca por cima do buraco — esticada, gelada de azul, largando os
# fantasmas do dash para trás, igual ao jogo — e ela freia do outro lado.
# Depois a cena escurece e recomeça.
#
# É um pedaço da fase, nas escalas do jogo (Cacau 1,5×, tiles 2×): o arranco
# tem o tamanho do de verdade, e o vão é um que ela atravessa no jogo.
#
# ONDE AJUSTAR CADA COISA (tudo é nó, na cena scenes/ui/demo_mochila.tscn):
#   o nó raiz       o quanto do cenário aparece (300×210) e a ampliação na
#                   ficha (a Escala: 2 = o dobro do tamanho do jogo)
#   Mundo/Cenario   a parede e as duas beiradas do piso (tiles das fases, sem
#                   colisão); o vão é o buraco entre elas
#   Mundo/Fosso     o escuro do fundo do vão
#   Mundo/Cacau     onde ela começa, e as animações: "idle" e "dash" (a pose do
#                   arranco, que no jogo é o último quadro da corrida)
#   Mundo/Jato      o jato de N₂ que sai das costas dela no arranco
#   Mundo/Poeira    a poeira da freada
#   Tecla           onde a tecla (ou o botão do controle) aparece
# Os TEMPOS e o tamanho do arranco são as constantes logo abaixo; a pose, a
# cor e os fantasmas são os do dash do jogo (FerramentasPlayer).

## Ação do mapa de entrada que a telinha ensina: SHIFT no teclado, R2 no controle.
const ACAO := &"dash"
## O azul da mochila (o do CatalogoFerramentas).
const COR_TECLA := Color(0.5, 0.75, 1.0)

const ANIM_PARADA := &"idle"
const ANIM_DASH := &"dash"

# --- Roteiro de uma volta (segundos) ---
## A tecla afunda e ela já entra na pose — mas o mundo congela um instante
## antes do arranco (o hitstop do jogo).
const T_APERTAR := 0.75
const T_ARRANCAR := T_APERTAR + FerramentasPlayer.DASH_CONGELAMENTO
const T_FREAR := T_ARRANCAR + FerramentasPlayer.DASH_DURACAO
## Acabado o arranco, sobra embalo: ela escorrega mais um pouco e para.
const DURACAO_SOBRA := 0.16
const T_PARADA := T_FREAR + DURACAO_SOBRA
const T_FIM := 2.9

## O arranco (a 1000 px/s, quase o do jogo) e o que ela escorrega depois.
const DISTANCIA_DASH := 180.0
const DISTANCIA_SOBRA := 12.0

## A pose esticada no sentido do arranco (a mesma do jogo, na horizontal).
const ESTICADA := Vector2(1.3, 0.75)
## Os fantasmas: a cor, quanto encolhem até sumir e quantos cabem num arranco.
const COR_FANTASMA := Color(0.65, 0.85, 1.0, 0.6)
const ENCOLHE_FANTASMA := 0.88
const FANTASMAS := 10
## Na freada ela achata um tiquinho e volta.
const ACHATADA := Vector2(1.1, 0.92)
const DURACAO_ACHATADA := 0.14
## Tremor da cena no arranco, em pixels, e por quanto tempo.
const TREMOR := 2.0
const DURACAO_TREMOR := 0.12
## Onde o jato sai, a partir do meio dela (as costas, na altura da mochila).
const BOCAL := Vector2(-14, -2)

var _origem_do_mundo := Vector2.ZERO
var _partida := Vector2.ZERO
var _escala := Vector2.ONE
var _fantasmas: Array[Sprite2D] = []

@onready var _jato: CPUParticles2D = $Mundo/Jato
@onready var _poeira: CPUParticles2D = $Mundo/Poeira
@onready var _pasta_dos_fantasmas: Node2D = $Mundo/Fantasmas


func _ao_montar() -> void:
	_origem_do_mundo = _mundo.position
	_partida = _cacau.position
	_escala = _cacau.scale
	# Os fantasmas do arranco: um a cada DASH_FANTASMA_INTERVALO, cada um com o
	# quadro da pose, parado onde ela estava.
	var pose := _cacau.sprite_frames.get_frame_texture(ANIM_DASH, 0)
	for i in FANTASMAS:
		var fantasma := Sprite2D.new()
		fantasma.texture = pose
		fantasma.visible = false
		_pasta_dos_fantasmas.add_child(fantasma)
		_fantasmas.append(fantasma)


func duracao_da_volta() -> float:
	return T_FIM


func instante_do_toque() -> float:
	return T_APERTAR


func acao() -> StringName:
	return ACAO


func cor_da_tecla() -> Color:
	return COR_TECLA


## Ela está no arranco (na pose, do toque até a freada)?
func no_dash() -> bool:
	return _tempo >= T_APERTAR and _tempo < T_FREAR


## Já passou para o outro lado do vão?
func atravessou() -> bool:
	return _tempo >= T_FREAR


## Onde ela está (o meio do desenho) no instante "t" do roteiro.
func posicao_em(t: float) -> Vector2:
	var x := _partida.x
	if t >= T_ARRANCAR:
		x += DISTANCIA_DASH * clampf((t - T_ARRANCAR) / FerramentasPlayer.DASH_DURACAO, 0.0, 1.0)
	if t >= T_FREAR:
		var sobra := clampf((t - T_FREAR) / DURACAO_SOBRA, 0.0, 1.0)
		x += DISTANCIA_SOBRA * (1.0 - (1.0 - sobra) * (1.0 - sobra))
	return Vector2(x, _partida.y)


func _ao_recomecar() -> void:
	_cacau.position = _partida
	_cacau.scale = _escala
	_cacau.modulate = Color.WHITE
	_jato.emitting = false
	_poeira.emitting = false
	for fantasma in _fantasmas:
		fantasma.visible = false
	_mundo.position = _origem_do_mundo


func _ao_atualizar() -> void:
	_cacau.position = posicao_em(_tempo)
	if no_dash():
		_mostrar_cacau(ANIM_DASH, 0)
		_cacau.scale = _escala * ESTICADA
		_cacau.modulate = FerramentasPlayer.COR_DASH
	else:
		_mostrar_parada(_tempo if _tempo < T_APERTAR else _tempo - T_PARADA)
		_cacau.scale = _escala
		_cacau.modulate = Color.WHITE
		if _tempo >= T_FREAR:
			var achata := clampf(1.0 - (_tempo - T_FREAR) / DURACAO_ACHATADA, 0.0, 1.0)
			_cacau.scale = _escala * Vector2.ONE.lerp(ACHATADA, achata)

	# O jato sopra das costas enquanto ela é arrancada.
	_jato.position = _cacau.position + BOCAL
	_jato.emitting = _tempo >= T_ARRANCAR and _tempo < T_FREAR
	if _passou(T_FREAR):
		_poeira.position = Vector2(_cacau.position.x, _poeira.position.y)
		_disparar(_poeira)

	_atualizar_fantasmas()

	var tremor := 0.0
	if _tempo >= T_ARRANCAR:
		tremor = clampf(1.0 - (_tempo - T_ARRANCAR) / DURACAO_TREMOR, 0.0, 1.0)
	_mundo.position = _origem_do_mundo + (Vector2(randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)) * TREMOR * tremor).round()


## Os fantasmas saem do relógio: o fantasma "i" nasceu no instante em que ela
## passou por ali, e some (encolhendo) em DASH_FANTASMA_VIDA.
func _atualizar_fantasmas() -> void:
	var intervalo := FerramentasPlayer.DASH_FANTASMA_INTERVALO
	var vida := FerramentasPlayer.DASH_FANTASMA_VIDA
	for i in _fantasmas.size():
		var fantasma := _fantasmas[i]
		var nasceu := T_ARRANCAR + i * intervalo
		var idade := _tempo - nasceu
		fantasma.visible = nasceu < T_FREAR and idade >= 0.0 and idade < vida
		if not fantasma.visible:
			continue
		var t := idade / vida
		fantasma.position = posicao_em(nasceu)
		fantasma.scale = _escala * ESTICADA * lerpf(1.0, ENCOLHE_FANTASMA, t)
		fantasma.modulate = Color(COR_FANTASMA, COR_FANTASMA.a * (1.0 - t))
