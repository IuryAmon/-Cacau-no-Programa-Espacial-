class_name PlataformaQueCai
extends Node2D

# --- PLATAFORMA QUE CAI ---
#
# Um pedaço de chão que cede quando alguém pousa em cima: afunda de leve,
# treme soltando poeira, despenca, some e, depois de um tempo, se remonta no
# mesmo lugar.
#
# Não é montada à mão. O PlataformasQueCaem transforma os tiles pintados na
# área dele em plataformas destas quando a fase começa (ver
# plataformas_que_caem.gd) — os ajustes de tempo, força e som ficam no
# Inspetor daquele nó.
#
# CICLO
#   PARADA    esperando. Alguém pousou em cima -> afunda e começa o aviso.
#   AVISO     treme e solta poeira por "tempo_aviso": a janela para pular.
#             Uma vez disparada, cai mesmo que a personagem já tenha saído.
#   CAINDO    despenca acelerando (quem estiver em cima vai junto).
#   SUMIDA    sem colisão e invisível por "tempo_retorno".
#   VOLTANDO  pisca como um contorno fraco no lugar original e se solidifica
#             com um "pop". Volta SEMPRE no horário. Se alguém estiver
#             ocupando o espaço (embaixo, na frente), ela volta de MÃO ÚNICA:
#             não empurra nem prende quem está dentro, mas quem pula e cai
#             por cima pousa nela normalmente. Quando o espaço fica livre,
#             volta a ser sólida por todos os lados.
#
# ESTRUTURA (montada em código)
#   PlataformaQueCai (fica parada no lugar original)
#   ├─ Corpo (AnimatableBody2D, é ele que cai)
#   │  ├─ colisões (um retângulo por fileira de tiles quadrados)
#   │  ├─ Visual (sprites dos tiles; o tremor e o "pop" mexem só aqui)
#   │  └─ sons
#   ├─ SensorPouso (Area2D fina logo acima do topo)
#   ├─ VolumeRetorno (Area2D do tamanho da plataforma, para saber se está livre)
#   ├─ PoeiraAviso / PoeiraQueda (partículas na borda de baixo)
#   └─ Relogio (Timer do retorno)

signal caiu
signal voltou

enum Estado { PARADA, AVISO, CAINDO, SUMIDA, VOLTANDO }

## Camada de física em que ficam as personagens (a do Player é a 1).
const MASCARA_PERSONAGENS := 1
## Recuo do sensor nas laterais: encostar só a beirada da cápsula não dispara.
const RECUO_SENSOR := 6.0

# Ajustes — o PlataformasQueCaem preenche antes de chamar montar().
var tempo_aviso := 0.95
var afundamento := 3.0
var intensidade_tremor := 1.5
var aceleracao_queda := 1800.0
var velocidade_max_queda := 950.0
var tempo_ate_sumir := 0.6
var tempo_retorno := 2.5
var tremor_camera := 2.5
var som_aviso: AudioStream
var som_queda: AudioStream
var som_retorno: AudioStream

var estado := Estado.PARADA

var _corpo: AnimatableBody2D
var _visual: Node2D
var _formas: Array[Node2D] = []
var _sensor: Area2D
var _volume: Area2D
var _poeira_aviso: CPUParticles2D
var _poeira_queda: CPUParticles2D
var _relogio: Timer
var _som_aviso: AudioStreamPlayer2D
var _som_queda: AudioStreamPlayer2D
var _som_retorno: AudioStreamPlayer2D

var _t := 0.0
var _velocidade := 0.0
var _afundado := 0.0
var _sumindo := false
## Voltou com alguém dentro: fica de mão única até o espaço ficar livre.
var _modo_passagem := false
var _mao_unica_original: Array[bool] = []
var _margem_original: Array[float] = []

## No modo de passagem, até quantos px dentro do topo ainda conta como "pousar"
## (e empurra para cima). Mais fundo que isso, a pessoa atravessa.
const MARGEM_PASSAGEM := 8.0


## Constrói a plataforma a partir de células de uma TileMapLayer (as células
## não são apagadas aqui — isso é com quem chamou). Precisa estar na árvore.
func montar(camada: TileMapLayer, celulas: Array[Vector2i]) -> void:
	var ts := camada.tile_set
	var tam_tile := Vector2(ts.tile_size) * camada.global_scale

	var caixa := Rect2()
	for i in celulas.size():
		var r := Rect2(_centro_celula(camada, celulas[i]) - tam_tile * 0.5, tam_tile)
		caixa = r if i == 0 else caixa.merge(r)
	# A origem fica no centro: o "pop" de retorno cresce a partir do meio.
	global_position = caixa.get_center()

	_corpo = AnimatableBody2D.new()
	_corpo.name = "Corpo"
	_corpo.sync_to_physics = true
	if ts.get_physics_layers_count() > 0:
		_corpo.collision_layer = ts.get_physics_layer_collision_layer(0)
		_corpo.collision_mask = ts.get_physics_layer_collision_mask(0)
	add_child(_corpo)

	_visual = Node2D.new()
	_visual.name = "Visual"
	_visual.z_index = camada.z_index
	_visual.z_as_relative = camada.z_as_relative
	_visual.light_mask = camada.light_mask
	_visual.texture_filter = camada.texture_filter
	_visual.material = camada.material
	_visual.modulate = camada.modulate
	_corpo.add_child(_visual)

	_montar_sprites(camada, celulas)
	_montar_colisoes(camada, celulas)

	var meia := caixa.size * 0.5

	_sensor = _criar_area("SensorPouso",
		Vector2(maxf(caixa.size.x - RECUO_SENSOR * 2.0, 4.0), 10.0), Vector2(0.0, -meia.y - 4.0))
	_volume = _criar_area("VolumeRetorno", caixa.size + Vector2(8.0, 8.0), Vector2.ZERO)

	_poeira_aviso = _criar_poeira("PoeiraAviso", caixa.size.x, meia.y, camada.z_index + 1, false)
	_poeira_queda = _criar_poeira("PoeiraQueda", caixa.size.x, meia.y, camada.z_index + 1, true)

	_som_aviso = _criar_som("SomAviso", som_aviso, -8.0)
	_som_queda = _criar_som("SomQueda", som_queda, -6.0)
	_som_retorno = _criar_som("SomRetorno", som_retorno, -12.0)

	_relogio = Timer.new()
	_relogio.name = "Relogio"
	_relogio.one_shot = true
	_relogio.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_relogio.timeout.connect(_tentar_voltar)
	add_child(_relogio)


func _physics_process(delta: float) -> void:
	if _corpo == null:
		return

	if _modo_passagem and not _espaco_ocupado():
		_definir_passagem(false)

	match estado:
		Estado.PARADA:
			if _alguem_pousou():
				_comecar_aviso()

		Estado.AVISO:
			_t += delta
			# O tremor cresce ao longo do aviso: começa sutil e fica urgente.
			var forca := intensidade_tremor * lerpf(0.4, 1.0, clampf(_t / tempo_aviso, 0.0, 1.0))
			_visual.position = Vector2(
				roundf(randf_range(-forca, forca)),
				roundf(randf_range(-forca, forca) * 0.5) + _afundado)
			if _t >= tempo_aviso:
				_comecar_queda()

		Estado.CAINDO:
			_t += delta
			_velocidade = minf(_velocidade + aceleracao_queda * delta, velocidade_max_queda)
			_corpo.position.y += _velocidade * delta
			if _t >= tempo_ate_sumir and not _sumindo:
				_sumir()


# --- CICLO ---

func _comecar_aviso() -> void:
	estado = Estado.AVISO
	_t = 0.0
	_tocar(_som_aviso, randf_range(0.95, 1.08))
	_poeira_aviso.emitting = true

	# Afunda rápido com o peso e fica levemente cedida durante o aviso.
	var tw := create_tween()
	tw.tween_method(_definir_afundado, 0.0, afundamento, 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(_definir_afundado, afundamento, afundamento * 0.35, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _comecar_queda() -> void:
	estado = Estado.CAINDO
	_t = 0.0
	_velocidade = 0.0
	_visual.position = Vector2.ZERO
	_poeira_aviso.emitting = false
	_poeira_queda.restart()
	_som_aviso.stop()
	_tocar(_som_queda, randf_range(0.9, 1.05))

	if tremor_camera > 0.0:
		var camera := get_viewport().get_camera_2d()
		if camera and camera.has_method("disparar_tremor"):
			camera.disparar_tremor(tremor_camera)
	caiu.emit()


func _sumir() -> void:
	_sumindo = true
	var tw := create_tween()
	tw.tween_property(_visual, "modulate:a", 0.0, 0.18)
	tw.tween_callback(_esconder)


func _esconder() -> void:
	estado = Estado.SUMIDA
	_sumindo = false
	_ligar_colisao(false)
	_corpo.visible = false
	_relogio.start(tempo_retorno)


func _tentar_voltar() -> void:
	estado = Estado.VOLTANDO
	_corpo.position = Vector2.ZERO
	_corpo.visible = true
	_visual.position = Vector2.ZERO
	_visual.scale = Vector2.ONE
	_visual.modulate.a = 0.0

	# Contorno piscando no lugar: avisa que o chão vai voltar ali.
	var tw := create_tween()
	for i in 2:
		tw.tween_property(_visual, "modulate:a", 0.35, 0.12)
		tw.tween_property(_visual, "modulate:a", 0.1, 0.12)
	tw.tween_callback(_solidificar)


func _solidificar() -> void:
	# Tem alguém no espaço dela: volta de mão única, para não empurrar nem
	# prender — e ainda assim dá para pousar em cima.
	if _espaco_ocupado():
		_definir_passagem(true)

	_ligar_colisao(true)
	_tocar(_som_retorno, randf_range(0.95, 1.05))

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_visual, "modulate:a", 1.0, 0.15)
	tw.tween_property(_visual, "scale", Vector2.ONE, 0.3) \
		.from(Vector2(0.9, 0.9)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(_ficar_parada)


func _ficar_parada() -> void:
	estado = Estado.PARADA
	voltou.emit()


# --- CONSULTAS ---

## Alguém (personagem) está de pé em cima dela — não vale encostar por baixo
## nem pelos lados, nem estar subindo no meio de um pulo.
func _alguem_pousou() -> bool:
	for corpo in _sensor.get_overlapping_bodies():
		if corpo is CharacterBody2D \
				and (corpo as CharacterBody2D).is_on_floor() \
				and (corpo as CharacterBody2D).velocity.y >= 0.0 \
				and corpo.global_position.y < global_position.y:
			return true
	return false


func _espaco_ocupado() -> bool:
	for corpo in _volume.get_overlapping_bodies():
		if corpo is CharacterBody2D:
			return true
	return false


## Liga/desliga a mão única temporária. Desligando, cada colisão volta a ser
## como o TileSet definiu.
func _definir_passagem(ligado: bool) -> void:
	if _mao_unica_original.is_empty():
		for forma in _formas:
			_mao_unica_original.append(forma.get("one_way_collision"))
			_margem_original.append(forma.get("one_way_collision_margin"))
	_modo_passagem = ligado
	for i in _formas.size():
		var forma := _formas[i]
		if ligado:
			forma.set_deferred("one_way_collision", true)
			forma.set_deferred("one_way_collision_margin", maxf(_margem_original[i], MARGEM_PASSAGEM))
		else:
			forma.set_deferred("one_way_collision", _mao_unica_original[i])
			forma.set_deferred("one_way_collision_margin", _margem_original[i])


func _ligar_colisao(ligada: bool) -> void:
	for forma in _formas:
		forma.set_deferred("disabled", not ligada)


func _definir_afundado(valor: float) -> void:
	_afundado = valor


func _tocar(som: AudioStreamPlayer2D, tom: float) -> void:
	if som.stream:
		som.pitch_scale = tom
		som.play()


# --- MONTAGEM ---

func _centro_celula(camada: TileMapLayer, c: Vector2i) -> Vector2:
	return camada.to_global(camada.map_to_local(c))


func _montar_sprites(camada: TileMapLayer, celulas: Array[Vector2i]) -> void:
	var ts := camada.tile_set
	for c in celulas:
		var fonte := ts.get_source(camada.get_cell_source_id(c)) as TileSetAtlasSource
		if fonte == null or fonte.texture == null:
			continue
		var atlas := camada.get_cell_atlas_coords(c)
		var textura := AtlasTexture.new()
		textura.atlas = fonte.texture
		textura.region = fonte.get_tile_texture_region(atlas)

		var sprite := Sprite2D.new()
		sprite.texture = textura
		sprite.scale = camada.global_scale
		sprite.position = to_local(_centro_celula(camada, c))
		var td := camada.get_cell_tile_data(c)
		if td:
			sprite.flip_h = td.flip_h
			sprite.flip_v = td.flip_v
			sprite.modulate = td.modulate
			sprite.offset = -Vector2(td.texture_origin)
		_visual.add_child(sprite)


# Fileiras contíguas de tiles quadrados viram UM retângulo: sem as "costuras"
# entre tiles em que a cápsula da personagem pode enganchar. Tiles com outro
# formato (rampa, meio-tile) mantêm o polígono do TileSet.
func _montar_colisoes(camada: TileMapLayer, celulas: Array[Vector2i]) -> void:
	var ts := camada.tile_set
	if ts.get_physics_layers_count() == 0:
		return

	var fileiras := {}
	for c in celulas:
		if not fileiras.has(c.y):
			fileiras[c.y] = []
		fileiras[c.y].append(c)

	for y in fileiras:
		var lista: Array = fileiras[y]
		lista.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)

		var em_fileira := false
		var ini := Vector2i.ZERO
		var fim := Vector2i.ZERO
		var mao_unica := false
		var margem := 1.0
		for c: Vector2i in lista:
			var td := camada.get_cell_tile_data(c)
			var quadrado := td != null and _eh_quadrado_cheio(td, ts.tile_size)
			if quadrado:
				var ow := td.is_collision_polygon_one_way(0, 0)
				if em_fileira and c.x == fim.x + 1 and ow == mao_unica:
					fim = c
					continue
				if em_fileira:
					_adicionar_retangulo(camada, ini, fim, mao_unica, margem)
				em_fileira = true
				ini = c
				fim = c
				mao_unica = ow
				margem = td.get_collision_polygon_one_way_margin(0, 0)
			else:
				if em_fileira:
					_adicionar_retangulo(camada, ini, fim, mao_unica, margem)
					em_fileira = false
				if td:
					for i in td.get_collision_polygons_count(0):
						_adicionar_poligono(camada, c, td, i)
		if em_fileira:
			_adicionar_retangulo(camada, ini, fim, mao_unica, margem)


func _eh_quadrado_cheio(td: TileData, tam: Vector2i) -> bool:
	if td.get_collision_polygons_count(0) != 1:
		return false
	var pontos := td.get_collision_polygon_points(0, 0)
	if pontos.size() != 4:
		return false
	var meia := Vector2(tam) * 0.5
	for p in pontos:
		if not (is_equal_approx(absf(p.x), meia.x) and is_equal_approx(absf(p.y), meia.y)):
			return false
	return true


func _adicionar_retangulo(camada: TileMapLayer, ini: Vector2i, fim: Vector2i, mao_unica: bool, margem: float) -> void:
	var tam := Vector2(camada.tile_set.tile_size) * camada.global_scale
	var a := to_local(_centro_celula(camada, ini))
	var b := to_local(_centro_celula(camada, fim))
	var retangulo := RectangleShape2D.new()
	retangulo.size = Vector2(b.x - a.x + tam.x, tam.y)
	var forma := CollisionShape2D.new()
	forma.shape = retangulo
	forma.position = (a + b) * 0.5
	forma.one_way_collision = mao_unica
	forma.one_way_collision_margin = margem
	_corpo.add_child(forma)
	_formas.append(forma)


func _adicionar_poligono(camada: TileMapLayer, c: Vector2i, td: TileData, i: int) -> void:
	var centro := to_local(_centro_celula(camada, c))
	var pontos := PackedVector2Array()
	for p in td.get_collision_polygon_points(0, i):
		pontos.append(centro + p * camada.global_scale)
	var forma := CollisionPolygon2D.new()
	forma.polygon = pontos
	forma.one_way_collision = td.is_collision_polygon_one_way(0, i)
	forma.one_way_collision_margin = td.get_collision_polygon_one_way_margin(0, i)
	_corpo.add_child(forma)
	_formas.append(forma)


func _criar_area(nome: String, tamanho: Vector2, posicao: Vector2) -> Area2D:
	var area := Area2D.new()
	area.name = nome
	area.collision_layer = 0
	area.collision_mask = MASCARA_PERSONAGENS
	area.monitorable = false
	area.position = posicao
	var retangulo := RectangleShape2D.new()
	retangulo.size = tamanho
	var forma := CollisionShape2D.new()
	forma.shape = retangulo
	area.add_child(forma)
	add_child(area)
	return area


func _criar_poeira(nome: String, largura: float, meia_altura: float, z: int, explosiva: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = nome
	p.emitting = false
	p.one_shot = explosiva
	p.explosiveness = 1.0 if explosiva else 0.0
	p.amount = 18 if explosiva else 8
	p.lifetime = 0.8 if explosiva else 0.55
	p.local_coords = false
	p.position = Vector2(0.0, meia_altura)  # borda de baixo
	p.z_index = z
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(maxf(largura * 0.5 - 4.0, 1.0), 2.0)
	p.direction = Vector2.DOWN
	p.spread = 40.0 if explosiva else 12.0
	p.gravity = Vector2(0.0, 320.0)
	p.initial_velocity_min = 20.0 if explosiva else 5.0
	p.initial_velocity_max = 80.0 if explosiva else 25.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0 if explosiva else 3.0

	var cores := Gradient.new()
	cores.set_color(0, Color(0.72, 0.7, 0.66, 0.9))
	cores.set_color(1, Color(0.45, 0.43, 0.42, 0.0))
	p.color_ramp = cores
	add_child(p)
	return p


func _criar_som(nome: String, stream: AudioStream, volume: float) -> AudioStreamPlayer2D:
	var som := AudioStreamPlayer2D.new()
	som.name = nome
	som.stream = stream
	som.volume_db = volume
	som.max_distance = 900.0
	som.attenuation = 1.6
	_corpo.add_child(som)
	return som
