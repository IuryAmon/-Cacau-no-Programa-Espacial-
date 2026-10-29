class_name ExplosaoDoCilindro
extends Node2D

# --- O CILINDRO DE AR LÍQUIDO ESTOURANDO NAS COSTAS DA CACAU ---
#
# O fim da corrida da amostra (ContagemDaAmostra): o calor da sala ganhou, o
# líquido ferveu e a pressão passou do que o cilindro aguenta. É uma explosão
# FÍSICA, sem fogo: o gás rasga o aço de uma vez e se expande. Expandindo tão
# depressa ele esfria, e a umidade do ar vira uma nuvem branca — e os cacos do
# cilindro, ainda gelados, saem cobertos de geada.
#
# A CENA, em dois atos:
#   1. O AVISO (TEMPO_DO_AVISO): a Cacau para; a câmera aproxima dela; o
#      cilindro treme e incha cada vez mais; o gás assobia por frestas (riscos
#      brancos); o alarme toca.
#   2. O ESTRONDO: o clarão branco na tela inteira, a câmera lenta, a onda de
#      choque em dois anéis, os cacos voando (e caindo), a nuvem, as faíscas
#      do aço; a Cacau é jogada para o lado; a tela treme forte.
# Acabado, avisa "terminou" (quem chamou mostra o fim de jogo).
#
# Tudo é de runtime, como a MorteDespedacada: sem cena e sem PNG novo (os
# cacos são pedaços desenhados na cor do cilindro gelado).

signal terminou

const TEMPO_DO_AVISO := 1.3
const DURACAO := 3.4
const CAMERA_LENTA := 0.35
const DURACAO_DA_CAMERA_LENTA := 0.55

const SOM_ESTRONDO := preload("res://sounds/compressor/estrondo.wav")
const SOM_CHIADO := preload("res://sounds/compressor/chiado.wav")
const SOM_ALARME := preload("res://sounds/compressor/alarme.wav")
const SOM_RANGIDO := preload("res://sounds/compressor/rangido.wav")

const COR_GELO := Color(0.88, 0.95, 1.0)
const CORES_DOS_CACOS := [Color("5d79c9"), Color("34479e"), Color("a9c6ff"), Color("eaf6ff")]

var _cacau: CharacterBody2D = null
var _cilindro: Sprite2D = null
var _tempo: float = 0.0
var _estourou: bool = false
var _acabou: bool = false
var _jatos: Array[Dictionary] = []
var _cacos: Array[Dictionary] = []
var _nuvem: Array[Dictionary] = []
var _faiscas: Array[Dictionary] = []
var _clarao: ColorRect = null
var _camera_lenta: float = 0.0
var _sons: Array[AudioStreamPlayer] = []


## Começa a cena: o cilindro (nas costas da Cacau) incha e estoura.
func comecar(cacau: CharacterBody2D, cilindro: Sprite2D) -> void:
	_cacau = cacau
	_cilindro = cilindro
	z_index = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	global_position = _origem()
	if is_instance_valid(_cacau):
		_cacau.velocity = Vector2.ZERO
		_cacau.pode_se_mover = false
		var sprite := _cacau.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite:
			sprite.play("idle")
		var camera := _cacau.get_node_or_null("Camera2D")
		if camera and camera.has_method("aproximar"):
			camera.aproximar(_cacau, 2.0, 1.0)
	_tocar(SOM_ALARME, -6.0)
	_tocar(SOM_RANGIDO, -4.0)
	_tocar(SOM_CHIADO, -2.0)


func _origem() -> Vector2:
	if is_instance_valid(_cilindro):
		return _cilindro.global_position
	if is_instance_valid(_cacau):
		return _cacau.global_position + Vector2(0, -30)
	return global_position


func _process(delta: float) -> void:
	# A câmera lenta é feita aqui, no tempo do jogo inteiro.
	if _camera_lenta > 0.0:
		_camera_lenta -= delta / maxf(Engine.time_scale, 0.01)
		if _camera_lenta <= 0.0:
			Engine.time_scale = 1.0
	_tempo += delta
	if not _estourou:
		_avisar(delta)
		if _tempo >= TEMPO_DO_AVISO:
			_estrondo()
	else:
		_depois(delta)
	if _clarao:
		_clarao.color.a = move_toward(_clarao.color.a, 0.0, delta / 0.5)
	queue_redraw()
	if _estourou and _tempo >= DURACAO and not _acabou:
		_acabou = true
		Engine.time_scale = 1.0
		terminou.emit()


# ── O aviso ──

func _avisar(delta: float) -> void:
	var t := _tempo / TEMPO_DO_AVISO
	global_position = _origem()
	if is_instance_valid(_cilindro):
		var forca := 1.0 + t * 3.5
		_cilindro.offset = Vector2(randf_range(-forca, forca), randf_range(-forca, forca)).round()
		var inchaco := 1.0 + ease(t, 2.4) * 0.35
		_cilindro.scale = Vector2(inchaco, 1.0 + ease(t, 2.4) * 0.12)
		_cilindro.modulate = Color.WHITE.lerp(Color(1.0, 0.75, 0.7), t * 0.6)
	if t > 0.25 and randf() < delta * (10.0 + t * 30.0):
		var rumo := Vector2.from_angle(randf() * TAU)
		_jatos.append({"pos": rumo * 6.0, "vel": rumo * randf_range(120, 240), "vida": 0.0,
			"duracao": randf_range(0.25, 0.5)})
	_animar_jatos(delta)


func _animar_jatos(delta: float) -> void:
	for i in range(_jatos.size() - 1, -1, -1):
		var j: Dictionary = _jatos[i]
		j["vida"] = float(j["vida"]) + delta
		j["pos"] = (j["pos"] as Vector2) + (j["vel"] as Vector2) * delta
		if float(j["vida"]) >= float(j["duracao"]):
			_jatos.remove_at(i)


# ── O estrondo ──

func _estrondo() -> void:
	_estourou = true
	_tempo = 0.0
	for som in _sons:
		if is_instance_valid(som):
			som.stop()
	_tocar(SOM_ESTRONDO, 3.0)
	if is_instance_valid(_cilindro):
		_cilindro.visible = false
	# O clarão da tela inteira.
	var camada := CanvasLayer.new()
	camada.layer = 110
	add_child(camada)
	_clarao = ColorRect.new()
	_clarao.color = Color(1, 1, 1, 1)
	_clarao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clarao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(_clarao)
	# Câmera lenta e tremor.
	Engine.time_scale = CAMERA_LENTA
	_camera_lenta = DURACAO_DA_CAMERA_LENTA
	if is_instance_valid(_cacau):
		var camera := _cacau.get_node_or_null("Camera2D")
		if camera and camera.has_method("disparar_tremor"):
			camera.disparar_tremor(26.0)
		# A Cacau é jogada para o lado (para longe de onde estava o cilindro).
		var sprite := _cacau.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		var olhando := -1.0 if sprite and sprite.flip_h else 1.0
		_cacau.esta_no_knockback = true
		_cacau.velocity = Vector2(olhando * 420.0, -360.0)
		if sprite:
			sprite.play("jump")
	# Os cacos, gelados.
	for i in 22:
		var rumo := Vector2.from_angle(randf() * TAU)
		_cacos.append({"pos": rumo * randf_range(2, 10), "vel": rumo * randf_range(260, 620) + Vector2(0, -220),
			"giro": randf() * TAU, "velocidade_do_giro": randf_range(-16, 16),
			"tamanho": Vector2(randf_range(3, 9), randf_range(2, 6)).round(),
			"cor": CORES_DOS_CACOS[i % CORES_DOS_CACOS.size()]})
	# A nuvem branca (e um pouco de poeira).
	for i in 24:
		var branca := i % 5 != 0
		_nuvem.append({"pos": Vector2(randf_range(-10, 10), randf_range(-14, 14)),
			"vel": Vector2.from_angle(randf() * TAU) * randf_range(60, 240), "raio": randf_range(8, 18),
			"vida": 0.0, "duracao": randf_range(1.6, 2.8),
			"cor": COR_GELO if branca else Color(0.5, 0.52, 0.58)})
	for i in 26:
		_faiscas.append({"pos": Vector2.ZERO, "vel": Vector2.from_angle(randf() * TAU) * randf_range(240, 640),
			"vida": 0.0, "duracao": randf_range(0.2, 0.5)})


func _depois(delta: float) -> void:
	for c in _cacos:
		c["vel"] = (c["vel"] as Vector2) + Vector2(0, 980) * delta
		c["pos"] = (c["pos"] as Vector2) + (c["vel"] as Vector2) * delta
		c["giro"] = float(c["giro"]) + float(c["velocidade_do_giro"]) * delta
	for i in range(_nuvem.size() - 1, -1, -1):
		var n: Dictionary = _nuvem[i]
		n["vida"] = float(n["vida"]) + delta
		n["pos"] = (n["pos"] as Vector2) + (n["vel"] as Vector2) * delta
		n["vel"] = (n["vel"] as Vector2) * pow(0.12, delta)
		n["raio"] = float(n["raio"]) + delta * lerpf(60.0, 10.0, clampf(float(n["vida"]) / 0.6, 0.0, 1.0))
		if float(n["vida"]) >= float(n["duracao"]):
			_nuvem.remove_at(i)
	for i in range(_faiscas.size() - 1, -1, -1):
		var s: Dictionary = _faiscas[i]
		s["vida"] = float(s["vida"]) + delta
		s["vel"] = (s["vel"] as Vector2) + Vector2(0, 700) * delta
		s["pos"] = (s["pos"] as Vector2) + (s["vel"] as Vector2) * delta
		if float(s["vida"]) >= float(s["duracao"]):
			_faiscas.remove_at(i)
	_animar_jatos(delta)


func _tocar(som: AudioStream, volume: float) -> void:
	var tocador := AudioStreamPlayer.new()
	tocador.stream = som
	tocador.volume_db = volume
	tocador.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(tocador)
	tocador.play()
	_sons.append(tocador)


func _exit_tree() -> void:
	# Trocar de cena no meio da câmera lenta não pode deixar o jogo devagar.
	Engine.time_scale = 1.0


# ── O desenho ──

func _draw() -> void:
	for j in _jatos:
		var t := float(j["vida"]) / float(j["duracao"])
		var pos: Vector2 = j["pos"]
		var rastro: Vector2 = (j["vel"] as Vector2).normalized() * lerpf(4.0, 16.0, t)
		draw_line(pos - rastro, pos, Color(COR_GELO, (1.0 - t) * 0.9), lerpf(1.5, 3.5, t))
		draw_circle(pos, 1.5 + t * 5.0, Color(COR_GELO, (1.0 - t) * 0.4))
	if not _estourou:
		return
	var t := _tempo
	if t < 0.2:
		var u := t / 0.2
		draw_circle(Vector2.ZERO, lerpf(20.0, 140.0, ease(u, 0.35)), Color(1, 1, 1, (1.0 - u) * 0.95))
	for k in 2:
		var tk := t - k * 0.06
		if tk > 0.0 and tk < 0.7:
			var u := tk / 0.7
			draw_arc(Vector2.ZERO, lerpf(10.0, 360.0, ease(u, 0.45)), 0.0, TAU, 64,
				Color(0.86, 0.94, 1.0, (1.0 - u) * (0.9 - k * 0.35)), lerpf(8.0 - k * 3.0, 1.0, u))
	for n in _nuvem:
		var u := float(n["vida"]) / float(n["duracao"])
		var cor: Color = n["cor"]
		var alfa := (1.0 - u) * (0.75 if cor.r > 0.8 else 0.45)
		draw_circle(n["pos"], n["raio"], Color(cor, alfa))
		draw_circle((n["pos"] as Vector2) - Vector2.ONE * float(n["raio"]) * 0.25, float(n["raio"]) * 0.5,
			Color(1, 1, 1, alfa * 0.5))
	for c in _cacos:
		var tamanho: Vector2 = c["tamanho"]
		draw_set_transform(c["pos"], float(c["giro"]))
		draw_rect(Rect2(-tamanho * 0.5 - Vector2.ONE, tamanho + Vector2.ONE * 2.0), Color("101425"))
		draw_rect(Rect2(-tamanho * 0.5, tamanho), c["cor"])
	draw_set_transform(Vector2.ZERO)
	for s in _faiscas:
		var u := float(s["vida"]) / float(s["duracao"])
		var pos: Vector2 = s["pos"]
		var rastro: Vector2 = (s["vel"] as Vector2).normalized() * 6.0
		draw_line(pos - rastro, pos, Color(1.0, lerpf(0.95, 0.55, u), 0.35, 1.0 - u), 2.0)
