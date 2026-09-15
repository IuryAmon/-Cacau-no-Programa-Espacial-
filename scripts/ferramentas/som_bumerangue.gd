class_name SomBumerangue
extends AudioStreamPlayer2D

# --- O ZUNIDO DO BUMERANGUE ---
#
# res://sounds/bomerangue.mp3 tem UM woosh só. Um bumerangue girando não faz
# um woosh: faz uma metralhada deles, um por pá que passa pelo ar. Então este
# nó não "toca o arquivo" — ele dispara FATIAS curtas do woosh, sobrepostas,
# uma a cada meia volta do giro.
#
# Sobrepostas é a palavra: cada sopro é cortado por volta dos 0,2 s enquanto o
# seguinte já entrou por cima. Esperar o anterior terminar daria um "woosh...
# woosh... woosh"; cortar e encavalar dá o "wshwshwshwsh" contínuo de coisa
# girando rápido.
#
# A polifonia é um AudioStreamPolyphonic: UM nó de áudio segurando várias
# vozes ao mesmo tempo, em vez de uma penca de AudioStreamPlayer2D
# revezando. É a ferramenta que a engine tem exatamente para isto.
#
# Tudo é dirigido pela FÍSICA do voo (ver bumerangue.gd): quanto mais rápido
# ele passa, mais agudos, mais altos e mais juntos ficam os sopros; no ápice,
# quando ele quase para, o zunido cai de tom e rareia sozinho. Ninguém
# programa essa curva aqui — ela é só a velocidade do voo, ouvida.

const WOOSH: AudioStream = preload("res://sounds/bomerangue.mp3")

## ONDE CORTAR O ARQUIVO. Medido, não chutado — o envelope de bomerangue.mp3
## (RMS a cada 50 ms) é assim:
##
##   0,00–0,25  silêncio
##   0,25–0,40  a subida do woosh (−73 dB → −8 dB)
##   0,40–0,45  O PICO
##   0,45–1,60  cauda de reverberação, caindo de −32 dB até −48 dB
##   1,60–6,02  rabo inaudível (−50 dB para baixo)
##
## Daí o INICIO em 0,32 e não em 0,25: começar no silêncio gastaria 150 ms de
## subida antes de cada woosh soar, e com um woosh a cada ~120 ms eles
## viravam um borrão sem ataque nenhum. Em 0,32 sobra a ponta da subida (o
## bastante para o corte não estalar) e o PICO chega ~90 ms depois — que é o
## que faz cada pá passando ter batida própria.
const INICIO := 0.32
## Fim do que ainda é audível: nenhuma fatia passa daqui.
const FIM := 1.60

## Vozes simultâneas. Em velocidade de arremesso saem ~8 sopros por segundo,
## cada um vivendo ~0,25 s: 2 ou 3 no ar ao mesmo tempo. As 8 são folga para o
## acento do arremesso e o do acerto caírem por cima sem cortar ninguém.
const VOZES := 8

## Quanto de arquivo cada sopro toca antes de ser cortado. Voando rápido a
## fatia é curta (subida + pico, quase nada de cauda); devagar ela abre e o
## zunido fica mais arrastado. Nenhuma delas pode ser menor que os ~100 ms que
## o pico leva para chegar, ou o corte comeria justamente o miolo do som.
const CORTE_RAPIDO := 0.24
const CORTE_LENTO := 0.42
## Rampa de saída de cada fatia. Sem ela o corte estala.
const FADE := 0.06
const SILENCIO_DB := -34.0

const VOLUME_MIN_DB := -15.0
const VOLUME_MAX_DB := -4.0
const TOM_MIN := 0.86
const TOM_MAX := 1.34

## Trava de segurança: por mais que o giro acelere, nunca mais que um sopro a
## cada 55 ms (~18 por segundo). Acima disso vira ruído branco, não zunido.
const INTERVALO_MINIMO := 0.055

var _playback: AudioStreamPlaybackPolyphonic = null
## Fatias no ar: {id, db, tempo, corte}. Envelhecem no _process e saem sozinhas.
var _vozes: Array[Dictionary] = []
## Giro acumulado desde o último sopro — a cada meia volta (PI) sai um novo.
var _fase: float = 0.0
var _desde_ultimo: float = 999.0


static func instalar(pai: Node) -> SomBumerangue:
	var som := SomBumerangue.new()
	som.name = "Woosh"
	pai.add_child(som)
	return som


func _ready() -> void:
	var polifonico := AudioStreamPolyphonic.new()
	polifonico.polyphony = VOZES
	stream = polifonico
	# O zunido acompanha o bumerangue pela sala: ele se afasta da personagem
	# até 600 px e volta, e é bom que isso se ouça no volume e no estéreo.
	max_distance = 1400.0
	attenuation = 0.9
	panning_strength = 0.8
	play()
	# Com driver de áudio dummy (--headless) isto pode vir nulo: daí o nó vira
	# um no-op silencioso em vez de derrubar o teste de fumaça das fases.
	_playback = get_stream_playback() as AudioStreamPlaybackPolyphonic


## Um sopro por meia volta da pá. Quem voa chama isto com o giro do frame já
## em radianos; a cadência sai da própria rotação, então acelerar o giro
## acelera o zunido sem nenhuma conta a mais.
func girar(radianos: float, intensidade: float, delta: float) -> void:
	_desde_ultimo += delta
	_fase += absf(radianos)
	if _fase < PI or _desde_ultimo < INTERVALO_MINIMO:
		return
	_fase = fmod(_fase, PI)
	soprar(intensidade)


## Um woosh avulso, fora da cadência do giro. `ganho_db` empurra o volume (o
## arremesso sai mais alto que o voo), `afinacao` desloca o tom (o arremate na
## mão desce, o chamado sobe) e `corte_forcado`, quando vem, ignora a fatia da
## intensidade — é como os sopros de acento pegam a cauda inteira do woosh,
## que o zunido do voo corta fora.
func soprar(intensidade: float, ganho_db: float = 0.0, afinacao: float = 1.0,
		corte_forcado: float = 0.0) -> void:
	if _playback == null:
		return

	var i := clampf(intensidade, 0.0, 1.0)
	var db := lerpf(VOLUME_MIN_DB, VOLUME_MAX_DB, i) + ganho_db
	# O desafino miúdo é o que impede a repetição de virar um bipe mecânico:
	# nenhum dos sopros sai idêntico ao anterior.
	var tom := lerpf(TOM_MIN, TOM_MAX, i) * afinacao * randf_range(0.96, 1.04)
	var corte := lerpf(CORTE_LENTO, CORTE_RAPIDO, i)
	if corte_forcado > 0.0:
		corte = corte_forcado
	corte = minf(corte, FIM - INICIO)

	var id := _playback.play_stream(WOOSH, INICIO, db, tom)
	if id == AudioStreamPlaybackPolyphonic.INVALID_ID:
		return  # todas as vozes ocupadas: este sopro simplesmente não sai

	_desde_ultimo = 0.0
	# "corte" está em segundos DE ARQUIVO; tocando mais agudo o arquivo corre
	# mais rápido, então em tempo de relógio a mesma fatia dura menos.
	_vozes.append({
		"id": id,
		"db": db,
		"tempo": 0.0,
		"corte": corte / maxf(tom, 0.1),
	})


func _process(delta: float) -> void:
	if _playback == null:
		return
	# De trás para frente: a lista encolhe no meio do laço.
	for i in range(_vozes.size() - 1, -1, -1):
		var voz: Dictionary = _vozes[i]
		voz["tempo"] = float(voz["tempo"]) + delta
		var sobra: float = float(voz["tempo"]) - float(voz["corte"])
		if sobra <= 0.0:
			continue
		if sobra >= FADE:
			_playback.stop_stream(int(voz["id"]))
			_vozes.remove_at(i)
		else:
			_playback.set_stream_volume(int(voz["id"]),
				lerpf(float(voz["db"]), SILENCIO_DB, sobra / FADE))


## Quanto tempo ainda falta para o último sopro escoar. Quem for se destruir
## (o bumerangue ao ser apanhado) espera isto antes do queue_free(), senão o
## zunido morre num corte seco no meio.
func tempo_de_cauda() -> float:
	var maior := 0.0
	for voz in _vozes:
		maior = maxf(maior, float(voz["corte"]) + FADE - float(voz["tempo"]))
	return maxf(maior, 0.0)
