extends SceneTree

# --- GERADOR DOS SONS DO COMPRESSOR E DO CILINDRO ---
#
# Os sons do puzzle do compressor e da amostra de ar gelado (fase do
# nitrogênio) não são gravações: são SINTETIZADOS aqui, do zero, como os do
# morcego (tools/gerar_sons_morcego.gd, de onde vêm as matérias-primas). Para
# trocar um deles por uma gravação de verdade, é só soltar o arquivo novo no
# nó de som da cena; este gerador não precisa rodar de novo.
#
# Para refazer os arquivos depois de mexer num número:
#
#   godot --headless --path . -s res://tools/gerar_sons_compressor.gd
#   godot --headless --path . --import
#
# OS SONS (sounds/compressor/):
#   estrondo     o cilindro estourando. É uma explosão FÍSICA (o gás preso
#                rasgando o aço), sem fogo: o estalo seco da ruptura, o baque,
#                o ronco que rola, o ar escapando num sopro, e os cacos de
#                metal tilintando no chão.
#   chiado       o gás assobiando pelas rachaduras, logo antes.
#   rangido      o aço do cilindro rangendo sob pressão (o aviso do amarelo).
#   alarme       o bipe de duas notas do manômetro no vermelho.
#   gota         o ar líquido pingando no fundo do cilindro.
#   valvula      a válvula fechando: a catraca do volante e o baque da
#                comporta.
#   bip / bip_urgente   o cronômetro da amostra esquentando.
#   bomba        a bomba de ar do simulador de gases do Laboratório: o ar
#                empurrado pelo cano e o estalinho da válvula dela.
#   alivio       o "psss" do ar saindo pela válvula de alívio do simulador.
#
# Os sons novos entram SEMPRE no fim da lista de _initialize: o sorteio do
# ruído segue a ordem, e assim os de antes saem iguais, byte por byte.
#
# Tudo tem corpo ACIMA de 150 Hz: grave puro some em caixa de som pequena.

const PASTA := "res://sounds/compressor"
const TAXA := 44100
const PICO := 0.8

var _sorteio := RandomNumberGenerator.new()


func _initialize() -> void:
	_sorteio.seed = 4021
	DirAccess.make_dir_recursive_absolute(PASTA)
	_salvar("estrondo", _estrondo())
	_salvar("chiado", _chiado())
	_salvar("rangido", _rangido())
	_salvar("alarme", _alarme())
	_salvar("gota", _gota())
	_salvar("valvula", _valvula())
	_salvar("bip", _bip(0.07, 1650.0))
	_salvar("bip_urgente", _bip_duplo())
	_salvar("bomba", _bomba())
	_salvar("alivio", _alivio())
	quit()


# --- OS SONS ---

func _estrondo() -> PackedFloat32Array:
	var som := _silencio(3.2)
	# O estalo da ruptura: ruído aberto, cortado em 60 ms.
	_somar(som, 0.0, _sopro(0.09, [[0.0, 5000.0], [1.0, 1500.0]], 0.5,
		[[0.0, 1.0], [0.25, 0.7], [1.0, 0.0]], 1.6))
	# O baque: um tom grave que despenca, com harmônicos para se ouvir em
	# alto-falante pequeno.
	_somar(som, 0.004, _tom(0.9, [[0.0, 190.0], [0.15, 120.0], [1.0, 48.0]],
		[[0.0, 1.0], [0.12, 0.85], [1.0, 0.0]], 1.3, [1.0, 0.55, 0.35, 0.2]))
	# O ronco que rola pelo galpão.
	_somar(som, 0.02, _sopro(2.9, [[0.0, 900.0], [0.2, 420.0], [1.0, 180.0]], 0.9,
		[[0.0, 0.0], [0.02, 1.0], [0.25, 0.55], [1.0, 0.0]], 1.0))
	# O ar escapando: um sopro agudo que morre.
	_somar(som, 0.05, _sopro(1.4, [[0.0, 6200.0], [1.0, 2600.0]], 1.6,
		[[0.0, 0.9], [0.4, 0.4], [1.0, 0.0]], 0.45))
	# Os cacos tilintando, cada um numa nota.
	var instantes := [0.32, 0.46, 0.61, 0.7, 0.88, 1.05, 1.21, 1.4, 1.62, 1.9]
	for i in instantes.size():
		var nota := _sorteio.randf_range(2600.0, 5200.0)
		_somar(som, instantes[i], _tom(0.14, [[0.0, nota], [1.0, nota * 0.97]],
			[[0.0, 1.0], [1.0, 0.0]], 0.22 * (1.0 - i * 0.07), [1.0, 0.0, 0.4]))
	return som


func _chiado() -> PackedFloat32Array:
	# O gás escapando pela fresta: chiado agudo que treme (a fresta abre e
	# fecha) e vai subindo.
	var som := _sopro(1.3, [[0.0, 3800.0], [1.0, 6400.0]], 2.4,
		[[0.0, 0.0], [0.15, 0.7], [1.0, 1.0]], 1.0)
	for i in som.size():
		som[i] *= 0.65 + 0.35 * sin(TAU * 23.0 * i / TAXA + sin(TAU * 3.0 * i / TAXA) * 3.0)
	return som


func _rangido() -> PackedFloat32Array:
	# Metal rangendo: o atrito "gruda e solta" — uma fileira de estalinhos num
	# ritmo que muda, passados por um ressonador de metal.
	var duracao := 0.75
	var som := _silencio(duracao)
	var t := 0.0
	while t < duracao:
		var ritmo := lerpf(70.0, 140.0, sin(PI * t / duracao))
		_somar(som, t, _sopro(0.012, [[0.0, 900.0], [1.0, 700.0]], 3.0,
			[[0.0, 1.0], [1.0, 0.0]], 0.8))
		t += 1.0 / ritmo * _sorteio.randf_range(0.8, 1.2)
	# O corpo do metal: um tom que treme por cima.
	_somar(som, 0.0, _tom(duracao, [[0.0, 260.0], [0.5, 340.0], [1.0, 210.0]],
		[[0.0, 0.0], [0.2, 0.6], [0.8, 0.5], [1.0, 0.0]], 0.35, [1.0, 0.5, 0.3]))
	return som


func _alarme() -> PackedFloat32Array:
	var som := _silencio(1.0)
	for i in 4:
		var nota := 1300.0 if i % 2 == 0 else 980.0
		_somar(som, i * 0.25, _tom(0.2, [[0.0, nota], [1.0, nota]],
			[[0.0, 1.0], [0.85, 0.9], [1.0, 0.0]], 0.6, [1.0, 0.0, 0.25]))
	return som


func _gota() -> PackedFloat32Array:
	# O "plim" de uma gota: um tom que sobe depressa (a bolha que a gota prende
	# na superfície) e some.
	return _tom(0.13, [[0.0, 900.0], [0.35, 2100.0], [1.0, 1700.0]],
		[[0.0, 0.0], [0.05, 1.0], [1.0, 0.0]], 0.7, [1.0, 0.3])


func _valvula() -> PackedFloat32Array:
	var som := _silencio(0.75)
	# A catraca do volante: seis cliques.
	for i in 6:
		_somar(som, i * 0.07, _sopro(0.02, [[0.0, 3200.0], [1.0, 2200.0]], 1.2,
			[[0.0, 1.0], [1.0, 0.0]], 0.7))
	# A comporta assentando: um baque metálico.
	_somar(som, 0.44, _tom(0.3, [[0.0, 420.0], [1.0, 300.0]],
		[[0.0, 1.0], [0.3, 0.5], [1.0, 0.0]], 0.9, [1.0, 0.6, 0.0, 0.35]))
	_somar(som, 0.44, _sopro(0.08, [[0.0, 2400.0], [1.0, 900.0]], 0.8,
		[[0.0, 1.0], [1.0, 0.0]], 0.6))
	return som


func _bip(duracao: float, nota: float) -> PackedFloat32Array:
	return _tom(duracao, [[0.0, nota], [1.0, nota]], [[0.0, 1.0], [0.8, 1.0], [1.0, 0.0]],
		0.7, [1.0, 0.0, 0.2])


func _bip_duplo() -> PackedFloat32Array:
	var som := _silencio(0.2)
	_somar(som, 0.0, _bip(0.07, 2100.0))
	_somar(som, 0.1, _bip(0.07, 2100.0))
	return som


func _bomba() -> PackedFloat32Array:
	# A bombada: o ar espremido no corpo da bomba e empurrado pelo cano (um
	# sopro que sobe de tom) e, no fim, o estalinho da válvula abrindo.
	var som := _silencio(0.26)
	_somar(som, 0.0, _sopro(0.2, [[0.0, 650.0], [1.0, 1800.0]], 1.4,
		[[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]], 1.0))
	_somar(som, 0.17, _tom(0.05, [[0.0, 1500.0], [1.0, 950.0]],
		[[0.0, 1.0], [1.0, 0.0]], 0.3, [1.0, 0.5]))
	return som


func _alivio() -> PackedFloat32Array:
	# O ar escapando pela válvula de alívio: um "psss" curto e agudo, que abre
	# de uma vez e vai murchando.
	return _sopro(0.3, [[0.0, 5200.0], [1.0, 3600.0]], 2.0,
		[[0.0, 0.0], [0.08, 1.0], [0.5, 0.6], [1.0, 0.0]], 1.0)


# --- AS MATÉRIAS-PRIMAS ---

## Tom com a nota escorregando por `notas` ([fração do tempo, Hz]), o volume
## por `forma` e os `harmonicos` (o peso de cada múltiplo da nota).
func _tom(duracao: float, notas: Array, forma: Array, volume: float,
		harmonicos: Array) -> PackedFloat32Array:
	var som := _silencio(duracao)
	var fase := 0.0
	for i in som.size():
		var t: float = float(i) / som.size()
		fase += TAU * _curva(notas, t) / TAXA
		var amostra := 0.0
		for h in harmonicos.size():
			amostra += float(harmonicos[h]) * sin(fase * (h + 1))
		som[i] = amostra * _curva(forma, t) * volume
	return som


## Ruído filtrado em banda (dois filtros de estado variável em fila).
func _sopro(duracao: float, notas: Array, largura: float, forma: Array,
		volume: float) -> PackedFloat32Array:
	var som := _silencio(duracao)
	var baixo := 0.0
	var banda := 0.0
	var baixo_2 := 0.0
	var banda_2 := 0.0
	for i in som.size():
		var t: float = float(i) / som.size()
		var f: float = 2.0 * sin(PI * minf(_curva(notas, t), TAXA / 7.0) / TAXA)
		var ruido: float = _sorteio.randf_range(-1.0, 1.0)
		var alto: float = ruido - baixo - banda / largura
		banda += f * alto
		baixo += f * banda
		var alto_2: float = banda - baixo_2 - banda_2 / largura
		banda_2 += f * alto_2
		baixo_2 += f * banda_2
		som[i] = banda_2 * _curva(forma, t) * volume
	return som


# --- APOIO ---

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


## Nivela pelo pico, fecha as duas pontas (5 ms) e grava em 16 bits mono.
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
