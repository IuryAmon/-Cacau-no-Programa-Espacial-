@tool
class_name AtomoCamadas
extends Control

# --- UM ÁTOMO NO MODELO DE CAMADAS (o desenho) ---
#
# O átomo como os puzzles do jogo o mostram: o núcleo no meio, com os prótons e
# os nêutrons amontoados, e os elétrons girando nas camadas em volta (K, L,
# M...). O puzzle do bumerangue desenha o carbono assim; este nó desenha
# QUALQUER átomo, do hidrogênio ao oganessônio, com as mesmas partículas
# ("particulas_atomo.png").
#
# Quem usa diz só quantas partículas há:
#
#   atomo.definir(6, 6, 6)      6 prótons, 6 nêutrons, 6 elétrons
#   atomo.mostrar_elemento(11)  o sódio como ele é mais comum na natureza
#
# e o nó resolve o resto:
#
#   * em que camada cada elétron fica (Elementos.camadas_com: a distribuição
#     do elemento, ou a do íon, quando os elétrons não batem com os prótons);
#   * o tamanho de tudo. Um átomo pequeno tem partículas grandes e camadas
#     folgadas; conforme ele cresce, o núcleo aperta as partículas e as camadas
#     se aproximam, para as sete caberem no mesmo quadro;
#   * o movimento: cada camada gira no seu passo, a partícula nova aparece com
#     um estalo e as vizinhas abrem espaço para ela.
#
# O núcleo enche do meio para fora, em espiral (a do girassol), como no puzzle
# do bumerangue. Montando partícula por partícula, cada uma fica onde entrou;
# trocando de átomo de uma vez, prótons e nêutrons saem misturados por igual.
#
# É o desenho do "Monte seu átomo", do quiz "Que átomo é esse?" e da ficha de
# cada elemento da tabela periódica do Laboratório.
#
# COMO EDITAR NO EDITOR: o átomo é desenhado no meio do nó e cresce com ele
# (use um nó quadrado). As cores estão no Inspector: sobre a tela do
# computador valem as do puzzle (as que vêm de fábrica); sobre papel, troque
# pela tinta do caderno.

const ARTE := preload("res://assets/UI/Computador receptor/particulas_atomo.png")
const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

## Onde cada partícula está na ARTE.
const RECORTES := {
	"proton": Rect2i(0, 0, 60, 60),
	"neutron": Rect2i(64, 0, 60, 60),
	"eletron": Rect2i(128, 16, 30, 30),
}
const VAZIO := 0
const PROTON := 1
const NEUTRON := 2

## O maior tamanho de um próton ou nêutron (o do puzzle do bumerangue) e o
## menor a que ele chega num núcleo cheio.
const LADO_MAXIMO := 30.0
const LADO_MINIMO := 5.0
## De quanto as partículas do núcleo se afastam: o lado dividido por isto. Um
## pouco menos que o lado inteiro, para elas se encostarem como um cacho.
const APERTO := 2.1
const ANGULO_DOURADO := 2.39996
## Até este tanto de partículas, o núcleo mostrado de uma vez alterna próton e
## nêutron; acima disso, embaralha (ver _remontar_o_nucleo).
const NUCLEO_ALTERNADO := 20
## Do cacho de partículas até a linha tracejada do núcleo.
const FOLGA_DO_NUCLEO := 12.0
## O núcleo ocupa no máximo esta fração do raio do desenho.
const NUCLEO_MAXIMO := 0.36
const NUCLEO_MINIMO := 0.17
## A distância entre uma camada e a seguinte nunca passa disto (com o desenho
## de 400 px; cresce junto com o nó).
const PASSO_MAXIMO := 80.0
## A primeira camada fica a esta fração de um passo do núcleo.
const PRIMEIRO_PASSO := 0.75
## O elétron tem esta fração do passo entre as camadas, dentro destes limites.
const ELETRON_NO_PASSO := 0.6
const ELETRON_MAXIMO := 18.0
const ELETRON_MINIMO := 9.0
## Quanto cada camada gira (radianos por segundo), da K para fora.
const VELOCIDADES := [1.8, 1.0, 0.78, 0.62, 0.5, 0.42, 0.36]
## A pressa com que o elétron alcança o lugar dele na camada e com que o
## desenho inteiro se ajusta ao tamanho novo.
const PRESSA_DO_ELETRON := 12.0
const PRESSA_DO_DESENHO := 9.0
## Quanto dura o estalo de uma partícula que aparece.
const DURACAO_DO_ESTALO := 0.22

@export_group("Cores")
## As camadas (os anéis) e as letras delas.
@export var cor_das_camadas: Color = Color(0.56, 0.78, 1.0, 0.6):
	set(valor):
		cor_das_camadas = valor
		queue_redraw()
## A linha tracejada do núcleo e a palavra NÚCLEO.
@export var cor_do_nucleo: Color = Color(1.0, 0.85, 0.0, 0.6):
	set(valor):
		cor_do_nucleo = valor
		queue_redraw()
## Um fio em volta de cada elétron. Na tela escura do computador ele não faz
## falta (transparente); no papel, é o que segura o elétron amarelo, que some
## no bege.
@export var cor_do_fio_do_eletron: Color = Color(0, 0, 0, 0):
	set(valor):
		cor_do_fio_do_eletron = valor
		queue_redraw()
@export_group("Desenho")
## Escreve a letra de cada camada (K, L, M...) ao lado dela.
@export var com_letras: bool = true:
	set(valor):
		com_letras = valor
		queue_redraw()
## Escreve NÚCLEO no meio enquanto ele está vazio.
@export var com_legenda_do_nucleo: bool = true:
	set(valor):
		com_legenda_do_nucleo = valor
		queue_redraw()
## Parado, os elétrons não giram (para uma figura de caderno).
@export var girando: bool = true
## Folga entre o desenho e a borda do nó.
@export var margem: float = 16.0:
	set(valor):
		margem = valor
		queue_redraw()

@export_group("No editor")
## O átomo que o editor mostra, para posicionar (número atômico).
@export_range(0, 118, 1) var previa: int = 6:
	set(valor):
		previa = valor
		if Engine.is_editor_hint() and is_inside_tree():
			mostrar_elemento(previa, false)

static var _miniaturas := {}

var _protons: int = 0
var _neutrons: int = 0
var _eletrons: int = 0
## As vagas do núcleo, do meio para fora: VAZIO, PROTON ou NEUTRON.
var _vagas := PackedByteArray()
## Há quanto tempo a partícula de cada vaga apareceu.
var _idade_das_vagas := PackedFloat32Array()
## Uma lista por camada; cada elétron é {"angulo", "raio", "idade"}.
var _camadas: Array[Array] = []
var _fases := PackedFloat32Array()

# ── O tamanho de tudo agora (vai atrás do tamanho pedido, sem pulo) ──
var _lado: float = LADO_MAXIMO
var _raio_do_nucleo: float = 40.0
var _raios := PackedFloat32Array()
var _lado_do_eletron: float = ELETRON_MAXIMO
## Quanto de cada camada já apareceu (0 a 1).
var _a_vista := PackedFloat32Array()


func _init() -> void:
	# Já no _init: quem cria o nó por código pode chamar definir() antes de ele
	# entrar na árvore.
	var camadas := Elementos.LETRAS_DAS_CAMADAS.size()
	_fases.resize(camadas)
	_raios.resize(camadas)
	_a_vista.resize(camadas)
	_camadas.resize(camadas)
	for i in camadas:
		_camadas[i] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# As partículas são miniaturas já no tamanho da tela (ver miniatura): com o
	# filtro liso elas não ganham dente quando a conta não fecha em pixel
	# inteiro. O filtro de pixel art do projeto é para a arte em escala inteira.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(_ao_mudar_de_tamanho)
	if Engine.is_editor_hint():
		mostrar_elemento(previa, false)
	else:
		_assentar()


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

## Diz quantas partículas o átomo tem. Com "animar", as que entram aparecem
## com um estalo e o desenho se ajusta aos poucos; sem, ele já nasce pronto.
func definir(protons: int, neutrons: int, eletrons: int, animar: bool = true) -> void:
	protons = maxi(protons, 0)
	neutrons = maxi(neutrons, 0)
	eletrons = clampi(eletrons, 0, Elementos.TOTAL)
	var mexeu_no_nucleo := absi(protons - _protons) + absi(neutrons - _neutrons)
	if mexeu_no_nucleo == 1:
		# Uma partícula a mais ou a menos: as outras ficam onde estão.
		if protons != _protons:
			_mexer_no_nucleo(PROTON, protons - _protons)
		else:
			_mexer_no_nucleo(NEUTRON, neutrons - _neutrons)
	elif mexeu_no_nucleo > 1:
		_remontar_o_nucleo(protons, neutrons, animar)
	_protons = protons
	_neutrons = neutrons
	_eletrons = eletrons
	_arrumar_os_eletrons(animar)
	if not animar:
		_assentar()
	queue_redraw()


## O elemento como ele é mais comum na natureza: neutro e com os nêutrons do
## isótopo mais abundante. 0 = nada.
func mostrar_elemento(z: int, animar: bool = true) -> void:
	if Elementos.existe(z):
		definir(z, Elementos.neutrons(z), z, animar)
	else:
		definir(0, 0, 0, animar)


func protons() -> int:
	return _protons


func neutrons() -> int:
	return _neutrons


func eletrons() -> int:
	return _eletrons


## Quantos elétrons há em cada camada agora, de dentro para fora.
func eletrons_por_camada() -> PackedInt32Array:
	var lista := PackedInt32Array()
	for camada in _camadas:
		lista.append(camada.size())
	while not lista.is_empty() and lista[lista.size() - 1] == 0:
		lista.remove_at(lista.size() - 1)
	return lista


## Quantas partículas de cada tipo o desenho do núcleo tem (para os testes).
func no_nucleo(tipo: int) -> int:
	return _vagas.count(tipo)


## O raio da camada (0 = K) e o da linha do núcleo, em px do nó, já no tamanho
## em que o desenho vai assentar.
func raio_da_camada(camada: int) -> float:
	return _medidas()["raios"][camada]


func raio_do_nucleo() -> float:
	return _medidas()["nucleo"]


## O lado de um próton (ou nêutron) e o de um elétron, assentados.
func lado_da_particula() -> float:
	return _medidas()["lado"]


func lado_do_eletron() -> float:
	return _medidas()["eletron"]


## O raio do desenho inteiro: até onde a última camada pode chegar.
func raio_do_desenho() -> float:
	return maxf(minf(size.x, size.y) * 0.5 - margem, 20.0)


## Leva o desenho ao tamanho pedido de uma vez, sem a transição.
func assentar() -> void:
	_assentar()
	queue_redraw()


# ─────────────────────────────────────────────────────────────
# O NÚCLEO
# ─────────────────────────────────────────────────────────────

## Põe (quantas > 0) ou tira (quantas < 0) partículas de um tipo.
func _mexer_no_nucleo(tipo: int, quantas: int) -> void:
	for i in absi(quantas):
		if quantas > 0:
			# Na primeira vaga livre: o núcleo enche do meio para fora.
			var vaga := _vagas.find(VAZIO)
			if vaga < 0:
				vaga = _vagas.size()
				_vagas.append(VAZIO)
				_idade_das_vagas.append(0.0)
			_vagas[vaga] = tipo
			_idade_das_vagas[vaga] = 0.0
		else:
			# Sai a de fora: a última vaga ocupada por uma do tipo.
			var vaga := _vagas.rfind(tipo)
			if vaga >= 0:
				_vagas[vaga] = VAZIO
	# As vagas vazias do fim não fazem falta.
	while not _vagas.is_empty() and _vagas[_vagas.size() - 1] == VAZIO:
		_vagas.remove_at(_vagas.size() - 1)
		_idade_das_vagas.remove_at(_idade_das_vagas.size() - 1)


## O núcleo inteiro de uma vez, com prótons e nêutrons misturados do meio até
## a beirada. Num núcleo pequeno eles se alternam por igual; num grande são
## embaralhados (sempre do mesmo jeito para o mesmo núcleo): alternados, a
## espiral das vagas formava braços de uma cor só, um desenho que não existe.
func _remontar_o_nucleo(protons: int, neutrons: int, animar: bool) -> void:
	var total := protons + neutrons
	_vagas.resize(total)
	_idade_das_vagas.resize(total)
	for i in total:
		@warning_ignore("integer_division")
		var e_proton := (i + 1) * protons / total > i * protons / total
		_vagas[i] = PROTON if e_proton else NEUTRON
		# Aparecem em cascata, do meio para fora (tudo em menos de meio segundo).
		_idade_das_vagas[i] = -0.4 * float(i) / float(maxi(total, 1)) if animar else DURACAO_DO_ESTALO
	if total > NUCLEO_ALTERNADO:
		var sorteio := RandomNumberGenerator.new()
		sorteio.seed = protons * 1000 + neutrons
		for i in range(total - 1, 0, -1):
			var j := sorteio.randi_range(0, i)
			var troca := _vagas[i]
			_vagas[i] = _vagas[j]
			_vagas[j] = troca


## Onde fica o meio da vaga i, a partir do meio do núcleo.
func _lugar_da_vaga(i: int, lado: float) -> Vector2:
	if _vagas.size() == 1:
		return Vector2.ZERO
	return Vector2.from_angle(i * ANGULO_DOURADO) * (lado / APERTO) * sqrt(i + 0.5)


# ─────────────────────────────────────────────────────────────
# OS ELÉTRONS
# ─────────────────────────────────────────────────────────────

func _arrumar_os_eletrons(animar: bool) -> void:
	var pedidas := Elementos.camadas_com(_protons, _eletrons)
	for c in _camadas.size():
		var camada: Array = _camadas[c]
		var quantos := pedidas[c] if c < pedidas.size() else 0
		while camada.size() > quantos:
			camada.pop_back()
		while camada.size() < quantos:
			camada.append({"angulo": _maior_vao(camada, _fases[c]),
				"raio": NAN, "idade": 0.0 if animar else DURACAO_DO_ESTALO})


## O ângulo do meio do maior vão entre os elétrons da camada: é por ali que o
## próximo entra, sem passar por cima de ninguém.
func _maior_vao(camada: Array, fase: float) -> float:
	if camada.is_empty():
		return fase - PI * 0.5
	var angulos: Array[float] = []
	for eletron: Dictionary in camada:
		angulos.append(fposmod(float(eletron["angulo"]), TAU))
	angulos.sort()
	var melhor := 0.0
	var maior := -1.0
	for i in angulos.size():
		var seguinte := angulos[(i + 1) % angulos.size()] + (TAU if i == angulos.size() - 1 else 0.0)
		if seguinte - angulos[i] > maior:
			maior = seguinte - angulos[i]
			melhor = angulos[i] + maior * 0.5
	return melhor


# ─────────────────────────────────────────────────────────────
# AS MEDIDAS
# ─────────────────────────────────────────────────────────────

## O tamanho em que o desenho assenta com as partículas que tem agora:
## {"lado", "nucleo", "raios", "eletron", "passo"}.
func _medidas() -> Dictionary:
	var raio_total := raio_do_desenho()
	var particulas := _vagas.size()
	var nucleo_maximo := raio_total * NUCLEO_MAXIMO
	# O cacho de N partículas de lado L tem raio L x (raiz(N) / APERTO + 0,5).
	var fator := sqrt(float(particulas)) / APERTO + 0.5
	var lado_maximo := LADO_MAXIMO * raio_total / 200.0
	var lado := lado_maximo
	if particulas > 0:
		lado = clampf((nucleo_maximo - FOLGA_DO_NUCLEO) / fator, LADO_MINIMO, lado_maximo)
	var nucleo := raio_total * NUCLEO_MINIMO
	if particulas > 0:
		nucleo = maxf(nucleo, lado * fator + FOLGA_DO_NUCLEO)

	var com_eletron := 0
	for c in _camadas.size():
		if not _camadas[c].is_empty():
			com_eletron = c + 1
	var passo := PASSO_MAXIMO * raio_total / 200.0
	if com_eletron > 0:
		passo = minf(passo, (raio_total - nucleo) / (float(com_eletron) - 1.0 + PRIMEIRO_PASSO))
	var raios := PackedFloat32Array()
	for c in _camadas.size():
		raios.append(nucleo + passo * (PRIMEIRO_PASSO + c))
	return {"lado": lado, "nucleo": nucleo, "raios": raios, "passo": passo,
		"eletron": clampf(passo * ELETRON_NO_PASSO, ELETRON_MINIMO, ELETRON_MAXIMO * raio_total / 200.0)}


func _assentar() -> void:
	var medidas := _medidas()
	_lado = medidas["lado"]
	_raio_do_nucleo = medidas["nucleo"]
	_raios = medidas["raios"]
	_lado_do_eletron = medidas["eletron"]
	for c in _camadas.size():
		var camada: Array = _camadas[c]
		_a_vista[c] = 0.0 if camada.is_empty() else 1.0
		for i in camada.size():
			camada[i]["angulo"] = _fases[c] + i * TAU / camada.size()
			camada[i]["raio"] = _raios[c]
			camada[i]["idade"] = DURACAO_DO_ESTALO
	for i in _idade_das_vagas.size():
		_idade_das_vagas[i] = DURACAO_DO_ESTALO


func _ao_mudar_de_tamanho() -> void:
	_assentar()
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	avancar(delta)


## Um passo da animação (o _process chama sozinho; os testes chamam direto).
func avancar(delta: float) -> void:
	var medidas := _medidas()
	var peso := 1.0 - exp(-PRESSA_DO_DESENHO * delta)
	_lado = lerpf(_lado, medidas["lado"], peso)
	_raio_do_nucleo = lerpf(_raio_do_nucleo, medidas["nucleo"], peso)
	_lado_do_eletron = lerpf(_lado_do_eletron, medidas["eletron"], peso)
	var raios: PackedFloat32Array = medidas["raios"]
	for i in _idade_das_vagas.size():
		_idade_das_vagas[i] += delta
	var peso_do_eletron := 1.0 - exp(-PRESSA_DO_ELETRON * delta)
	for c in _camadas.size():
		_raios[c] = lerpf(_raios[c], raios[c], peso)
		if girando:
			_fases[c] = fposmod(_fases[c] + float(VELOCIDADES[c]) * delta, TAU)
		var camada: Array = _camadas[c]
		_a_vista[c] = move_toward(_a_vista[c], 0.0 if camada.is_empty() else 1.0, delta / 0.2)
		for i in camada.size():
			var eletron: Dictionary = camada[i]
			eletron["angulo"] = lerp_angle(float(eletron["angulo"]), _fases[c] + i * TAU / camada.size(),
				peso_do_eletron)
			# O elétron novo nasce já na camada dele.
			eletron["raio"] = _raios[c] if is_nan(float(eletron["raio"])) \
				else lerpf(float(eletron["raio"]), _raios[c], peso_do_eletron)
			eletron["idade"] = float(eletron["idade"]) + delta
	queue_redraw()


# ─────────────────────────────────────────────────────────────
# DESENHO
# ─────────────────────────────────────────────────────────────

func _draw() -> void:
	var meio := (size * 0.5).round()
	_desenhar_camadas(meio)
	_desenhar_nucleo(meio)
	_desenhar_eletrons(meio)


func _desenhar_camadas(meio: Vector2) -> void:
	var passo := _raios[1] - _raios[0] if _raios.size() > 1 else PASSO_MAXIMO
	for c in _camadas.size():
		if _a_vista[c] <= 0.0:
			continue
		var cor := EstiloHUD.com_alfa(cor_das_camadas, _a_vista[c])
		draw_arc(meio, _raios[c], 0.0, TAU, 96, cor, 2.0)
		if com_letras:
			# A letra da camada, por fora dela, em cima e à direita: grande
			# enquanto há folga entre as camadas, pequena quando elas apertam.
			var tamanho := 22 if passo >= 44.0 else 11
			var afastada := minf(passo * 0.5, 15.0 if tamanho == 22 else 9.0)
			_escrever_no_meio(meio + Vector2.from_angle(-PI * 0.25) * (_raios[c] + afastada),
				String(Elementos.LETRAS_DAS_CAMADAS[c]), tamanho, Color(cor, cor.a * 1.4))


func _desenhar_nucleo(meio: Vector2) -> void:
	var tracos := 24
	for i in tracos:
		var de := TAU * i / tracos
		draw_arc(meio, _raio_do_nucleo, de, de + TAU / tracos * 0.55, 6, cor_do_nucleo, 2.0)
	if _vagas.is_empty():
		if com_legenda_do_nucleo:
			_escrever_no_meio(meio, "NÚCLEO", 11, Color(cor_do_nucleo, minf(cor_do_nucleo.a * 1.4, 1.0)))
		return
	# As de fora por cima das de dentro, sempre na mesma ordem.
	var proton := miniatura("proton", _em_pixels_da_tela(_lado))
	var neutron := miniatura("neutron", _em_pixels_da_tela(_lado))
	for i in _vagas.size():
		if _vagas[i] == VAZIO or _idade_das_vagas[i] <= 0.0:
			continue
		_desenhar_particula(proton if _vagas[i] == PROTON else neutron,
			meio + _lugar_da_vaga(i, _lado), _lado, _idade_das_vagas[i])


func _desenhar_eletrons(meio: Vector2) -> void:
	var arte_do_eletron := miniatura("eletron", _em_pixels_da_tela(_lado_do_eletron))
	for c in _camadas.size():
		for eletron: Dictionary in _camadas[c]:
			var raio := float(eletron["raio"])
			if is_nan(raio):
				raio = _raios[c]
			var onde := meio + Vector2.from_angle(float(eletron["angulo"])) * raio
			if cor_do_fio_do_eletron.a > 0.0 and float(eletron["idade"]) >= DURACAO_DO_ESTALO:
				draw_circle(onde.round(), roundf(_lado_do_eletron) * 0.5 + 1.0, cor_do_fio_do_eletron)
			_desenhar_particula(arte_do_eletron, onde, _lado_do_eletron, float(eletron["idade"]))


## A partícula com o meio em "onde". Nova, ela dá um estalo: passa um pouco do
## tamanho e volta.
func _desenhar_particula(textura: Texture2D, onde: Vector2, lado: float, idade: float) -> void:
	var medida := roundf(lado)
	if idade < DURACAO_DO_ESTALO:
		var t := clampf(idade / DURACAO_DO_ESTALO, 0.0, 1.0)
		medida = roundf(lado * t * (1.0 + 0.45 * sin(t * PI)))
	if medida < 1.0:
		return
	var metade := Vector2(medida, medida) * 0.5
	draw_texture_rect(textura, Rect2((onde - metade).round(), Vector2(medida, medida)), false)


func _escrever_no_meio(ponto: Vector2, texto: String, tamanho: int, cor: Color) -> void:
	var medida := FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho)
	var sobe := FONTE.get_ascent(tamanho)
	var desce := FONTE.get_descent(tamanho)
	draw_string(FONTE, (ponto + Vector2(-medida.x * 0.5, (sobe - desce) * 0.5)).round(), texto,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)


## Quantos pixels da JANELA a medida ocupa, contando a escala de quem está em
## volta (a tela do computador é ampliada 1,2x) e a da janela inteira. É nesse
## tamanho que a miniatura da partícula é feita, para ela chegar à tela sem
## ser esticada de novo.
func _em_pixels_da_tela(medida: float) -> int:
	var escala := 1.0
	if is_inside_tree():
		escala = get_global_transform().get_scale().x * get_viewport().get_final_transform().get_scale().x
	return clampi(roundi(medida * escala), 2, 240)


## A arte da partícula ("proton", "neutron" ou "eletron") reduzida para "lado"
## pixels. Reduzir na hora de desenhar, com o filtro de pixel art do projeto,
## serrilha a bolinha; aqui ela é reduzida uma vez, com capricho, e guardada.
static func miniatura(tipo: String, lado: int) -> Texture2D:
	lado = maxi(lado, 2)
	var chave := "%s/%d" % [tipo, lado]
	if _miniaturas.has(chave):
		return _miniaturas[chave]
	var recorte: Rect2i = RECORTES[tipo]
	var textura: Texture2D
	if lado >= recorte.size.x:
		var inteira := AtlasTexture.new()
		inteira.atlas = ARTE
		inteira.region = Rect2(recorte)
		textura = inteira
	else:
		var folha := ARTE.get_image()
		if folha.is_compressed():
			folha.decompress()
		folha.convert(Image.FORMAT_RGBA8)
		var pequena := folha.get_region(recorte)
		# Sem isto, a beirada da bolinha puxa o preto dos pixels transparentes.
		pequena.fix_alpha_edges()
		pequena.resize(lado, lado, Image.INTERPOLATE_LANCZOS)
		textura = ImageTexture.create_from_image(pequena)
	_miniaturas[chave] = textura
	return textura
