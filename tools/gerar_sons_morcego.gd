extends SceneTree

# --- GERADOR DOS SONS DO MORCEGO ---
#
# Os oito sons do morcego (sounds/morcego/*.wav) não são gravações: são
# SINTETIZADOS aqui, do zero, como os do rádio e os do caderno. Servem de
# ponto de partida — para trocar um deles por uma gravação de verdade, é só
# soltar o arquivo novo no campo correspondente do nó Morcego (grupo "Sons" no
# Inspetor); este gerador não precisa rodar de novo.
#
# Para refazer os arquivos depois de mexer num número:
#
#   godot --headless --path . -s res://tools/gerar_sons_morcego.gd
#   godot --headless --path . --import
#
# COMO CADA SOM É FEITO — duas matérias-primas só:
#   * um APITO: uma senoide cuja nota escorrega no tempo (é o guincho; morcego
#     guincha em notas que sobem e descem depressa), com um harmônico por cima
#     para não soar como bipe de aparelho;
#   * um SOPRO: ruído passado num filtro cuja nota também escorrega (é o ar: a
#     asa, o mergulho, a fumaça).
# As pancadas são as duas coisas juntas: um estalo de ruído e um apito grave
# que despenca.
#
# Tudo fica ACIMA de 500 Hz de propósito: grave puro some em caixa de som
# pequena (foi o que aconteceu com o primeiro passo no metal).

const PASTA := "res://sounds/morcego"
const TAXA := 44100
## Pico de cada arquivo, em fração do máximo. O volume de verdade é dosado no
## morcego (ver VOLUMES em morcego.gd); aqui só se garante que nenhum estoura.
const PICO := 0.7

var _sorteio := RandomNumberGenerator.new()


func _initialize() -> void:
	# Semente fixa: rodar de novo devolve exatamente os mesmos arquivos.
	_sorteio.seed = 828
	DirAccess.make_dir_recursive_absolute(PASTA)

	_salvar("morcego_guincho", _guincho())
	_salvar("morcego_ameaca", _ameaca())
	_salvar("morcego_mergulho", _mergulho())
	_salvar("morcego_asa", _asa())
	_salvar("morcego_golpe", _golpe())
	_salvar("morcego_morte", _morte())
	_salvar("morcego_queda", _queda())
	_salvar("morcego_pof", _pof())
	quit()


# --- OS OITO SONS ---

## Acordou e viu a Cacau: dois pios curtos, o segundo um tico mais agudo.
func _guincho() -> PackedFloat32Array:
	var som := _silencio(0.21)
	_somar(som, 0.0, _apito(0.07, [[0.0, 2500.0], [0.45, 3700.0], [1.0, 3000.0]], 0.9))
	_somar(som, 0.10, _apito(0.085, [[0.0, 2800.0], [0.4, 4100.0], [1.0, 3100.0]], 1.0))
	return som


## O aviso do bote: quatro pios cada vez mais agudos e mais juntos. É o som que
## diz "sai daí" — tem que ser inconfundível com o guincho de acordar.
func _ameaca() -> PackedFloat32Array:
	var som := _silencio(0.46)
	var inicios := [0.0, 0.13, 0.24, 0.33]
	for i in inicios.size():
		var nota: float = 2300.0 + i * 420.0
		_somar(som, inicios[i],
			_apito(0.075, [[0.0, nota], [0.5, nota * 1.45], [1.0, nota * 1.2]], 0.7 + i * 0.1))
	return som


## O mergulho: o ar rasgando (sopro que sobe e desce) com um fio de guincho.
func _mergulho() -> PackedFloat32Array:
	var som := _silencio(0.32)
	_somar(som, 0.0, _sopro(0.32, [[0.0, 900.0], [0.35, 2900.0], [1.0, 1100.0]], 2.2,
		[[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]], 1.0))
	_somar(som, 0.02, _apito(0.22, [[0.0, 4300.0], [1.0, 2700.0]], 0.22))
	return som


## Uma batida de asa: um sopro curto e macio. Toca baixinho, a cada batida.
func _asa() -> PackedFloat32Array:
	return _sopro(0.085, [[0.0, 1300.0], [1.0, 620.0]], 1.4,
		[[0.0, 0.0], [0.18, 1.0], [1.0, 0.0]], 1.0)


## O bumerangue pegou e ele aguentou: a pancada e um "ik!" de dor.
func _golpe() -> PackedFloat32Array:
	var som := _silencio(0.16)
	_somar(som, 0.0, _pancada(0.09, 1700.0, 720.0, 1.0))
	_somar(som, 0.02, _apito(0.07, [[0.0, 3900.0], [1.0, 2300.0]], 0.75))
	return som


## O golpe que mata: pancada mais cheia e o guincho que despenca tremendo.
func _morte() -> PackedFloat32Array:
	var som := _silencio(0.46)
	_somar(som, 0.0, _pancada(0.12, 1500.0, 640.0, 1.0))
	_somar(som, 0.03, _apito(0.4, [[0.0, 3800.0], [0.2, 3300.0], [1.0, 1250.0]], 0.8, 34.0, 0.055))
	return som


## O corpo batendo no chão (e o morcego que errou o bote e deu de cara no piso).
func _queda() -> PackedFloat32Array:
	return _pancada(0.075, 1300.0, 760.0, 1.0)


## O corpo virando fumaça: um sopro que afunda, com um estalinho na frente.
func _pof() -> PackedFloat32Array:
	var som := _silencio(0.26)
	_somar(som, 0.0, _sopro(0.26, [[0.0, 2600.0], [1.0, 600.0]], 0.9,
		[[0.0, 0.0], [0.06, 1.0], [1.0, 0.0]], 1.0))
	_somar(som, 0.0, _apito(0.045, [[0.0, 1500.0], [1.0, 700.0]], 0.5))
	return som


# --- AS MATÉRIAS-PRIMAS ---

## Senoide com a nota escorregando pelos pontos de `notas` ([fração do tempo,
## Hz]). `tremor_hz` e `tremor` dão o vibrato do guincho de morte. O volume
## sobe em 4 ms e cai em curva até o fim — é o que faz soar como pio, não bipe.
func _apito(duracao: float, notas: Array, volume: float,
		tremor_hz: float = 0.0, tremor: float = 0.0) -> PackedFloat32Array:
	var som := _silencio(duracao)
	var fase := 0.0
	for i in som.size():
		var t: float = float(i) / som.size()
		var nota: float = _curva(notas, t)
		if tremor_hz > 0.0:
			nota *= 1.0 + sin(TAU * tremor_hz * i / TAXA) * tremor
		fase += TAU * nota / TAXA
		var ataque: float = minf(float(i) / (0.004 * TAXA), 1.0)
		var queda: float = pow(1.0 - t, 1.6)
		# O segundo harmônico (uma oitava acima, fraco) dá o "arranhado" do pio.
		som[i] = (sin(fase) + 0.28 * sin(fase * 2.0)) * ataque * queda * volume
	return som


## Ruído filtrado em banda. `notas` é o centro do filtro ao longo do tempo,
## `largura` o quanto ele deixa passar em volta (maior = mais fechado, mais
## "assobiado") e `forma` o volume ao longo do tempo.
func _sopro(duracao: float, notas: Array, largura: float, forma: Array,
		volume: float) -> PackedFloat32Array:
	var som := _silencio(duracao)
	var baixo := 0.0
	var banda := 0.0
	var baixo_2 := 0.0
	var banda_2 := 0.0
	for i in som.size():
		var t: float = float(i) / som.size()
		# Filtro de estado variável (o de Chamberlin): barato e estável enquanto
		# a nota ficar bem abaixo de um sexto da taxa — e fica. São DOIS em
		# fila: um só deixa escapar chiado de sobra acima da nota, e o sopro
		# vira "tsss" de chiado em vez de ar passando.
		var f: float = 2.0 * sin(PI * _curva(notas, t) / TAXA)
		var ruido: float = _sorteio.randf_range(-1.0, 1.0)
		var alto: float = ruido - baixo - banda / largura
		banda += f * alto
		baixo += f * banda
		var alto_2: float = banda - baixo_2 - banda_2 / largura
		banda_2 += f * alto_2
		baixo_2 += f * banda_2
		som[i] = banda_2 * _curva(forma, t) * volume
	return som


## Pancada: um estalo de ruído (a batida em si) em cima de um apito grave que
## despenca (o corpo do golpe). `centro` é a cor do estalo, `grave` de onde o
## apito começa a cair.
func _pancada(duracao: float, centro: float, grave: float, volume: float) -> PackedFloat32Array:
	# O estalo morre quase todo no primeiro terço: ruído que demora a sumir soa
	# como prato de bateria, não como batida.
	var som := _sopro(duracao, [[0.0, centro * 1.5], [1.0, centro * 0.6]], 0.8,
		[[0.0, 1.0], [0.1, 0.55], [0.32, 0.12], [1.0, 0.0]], 1.0)
	var maior := 0.0001
	for amostra in som:
		maior = maxf(maior, absf(amostra))
	var corpo := _apito(duracao, [[0.0, grave], [1.0, grave * 0.72]], 0.9)
	for i in som.size():
		som[i] = (som[i] / maior * 0.9 + corpo[i]) * volume
	return som


# --- APOIO ---

## Valor de uma curva de pontos [fração do tempo, valor] no instante `t`.
func _curva(pontos: Array, t: float) -> float:
	if t <= pontos[0][0]:
		return pontos[0][1]
	for i in range(1, pontos.size()):
		if t <= pontos[i][0]:
			var trecho: float = pontos[i][0] - pontos[i - 1][0]
			var k: float = (t - pontos[i - 1][0]) / maxf(trecho, 0.00001)
			return lerpf(pontos[i - 1][1], pontos[i][1], k)
	return pontos[-1][1]


func _silencio(duracao: float) -> PackedFloat32Array:
	var som := PackedFloat32Array()
	som.resize(int(duracao * TAXA))
	return som


func _somar(destino: PackedFloat32Array, inicio: float, trecho: PackedFloat32Array) -> void:
	var de := int(inicio * TAXA)
	for i in trecho.size():
		if de + i >= destino.size():
			return
		destino[de + i] += trecho[i]


## Nivela pelo pico, fecha as duas pontas (5 ms, para o corte não estalar) e
## grava em 16 bits mono.
func _salvar(nome: String, som: PackedFloat32Array) -> void:
	var maior := 0.0001
	for amostra in som:
		maior = maxf(maior, absf(amostra))
	var borda := int(0.005 * TAXA)
	var bytes := PackedByteArray()
	bytes.resize(som.size() * 2)
	for i in som.size():
		var fecho: float = minf(1.0, minf(float(i), float(som.size() - 1 - i)) / borda)
		bytes.encode_s16(i * 2, int(clampf(som[i] / maior * PICO * fecho, -1.0, 1.0) * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = TAXA
	wav.stereo = false
	wav.data = bytes
	var caminho := "%s/%s.wav" % [PASTA, nome]
	var erro := wav.save_to_wav(caminho)
	print("%s  %.2f s  %s" % [caminho, float(som.size()) / TAXA, "ok" if erro == OK else "ERRO %d" % erro])
