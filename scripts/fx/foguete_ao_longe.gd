extends ParallaxLayer

# --- O FOGUETE AO LONGE ---
#
# O lançamento que a Cacau e o Dr. Chico assistem do telhado da fase 2 (quem
# dirige a cena é scripts/fases/lancamento_no_telhado.gd, que cria esta camada
# dentro do BG na hora e a tira de lá no fim). Fica numa camada que não anda
# com a câmera (motion_scale 0, como a lua): o foguete sobe lá no horizonte,
# atrás do telhado.
#
# Não usa nenhuma imagem pronta: tudo é desenhado aqui em PIXELS DE ARTE de
# PIXEL px (o tamanho do pixel das camadas do fundo), célula por célula — o
# foguete (o VLS branco, com os propulsores e a bandeirinha), a chama, a coluna
# de fumaça, os holofotes da base e o clarão no horizonte. Para girar sem sair
# da grade, cada célula da tela pergunta ao DESENHO que cor tem ali.
#
# O LANÇAMENTO, a partir de decolar() (segundos):
#   0       ignição: o clarão acende atrás do telhado e os holofotes se apagam
#   SOLTURA o foguete solta da torre e sobe devagar, ainda escondido; a nuvem
#           da base sobe rolando por cima da beirada, acesa pela chama
#   ...     rompe a beirada do telhado (rompeu_o_horizonte), ganha velocidade e
#           vai deitando para a direita, rumo à lua
#   55%     os propulsores laterais se soltam e caem (separou_os_propulsores)
#   fim     só um ponto de luz, que apaga (sumiu); o rastro fica no céu,
#           desmanchando com o vento até dissipar()
#
# O caminho é uma curva (partida, curva, chegada) em px desta camada. Numa
# camada de motion_scale 0, o px da camada é o px do mundo contado do canto de
# cima da tela, no zoom em que a câmera estava (ver preparar()).

signal rompeu_o_horizonte
signal separou_os_propulsores
signal sumiu

## Pixel de arte, em px da camada (as camadas de arte do BG usam escala 2).
const PIXEL := 2.0
const SHADER_DO_BRILHO := preload("res://shaders/brilho_pixel.gdshader")

## O VLS de lado, da ponta (em cima) às tubeiras (embaixo). A luz da lua vem
## da direita: a coluna da esquerda de cada peça é a sombra.
##   W casco aceso   l casco na sombra   D faixa escura   G Y a bandeira
##   B propulsor aceso   b propulsor na sombra   N tubeira
const DESENHO: Array[String] = [
	"...W...",
	"..lWW..",
	"..lWW..",
	"..DDD..",
	"..lWW..",
	"..lGY..",
	"..lWW..",
	"..lWW..",
	"..DDD..",
	"..lWW..",
	"..lWW..",
	".BlWWb.",
	"bBlWWbB",
	"bBlWWbB",
	"bBlWWbB",
	"bBlWWbB",
	"bBlWWbB",
	"bBlWWbB",
	"bBlWWbB",
	"bBlWWbB",
	".N.N.N.",
]
## Um propulsor solto (o da direita do desenho).
const PROPULSOR: Array[String] = [
	"b.",
	"bB",
	"bB",
	"bB",
	"bB",
	"bB",
	"bB",
	"bB",
	"bB",
	".N",
]
const CORES := {
	"W": Color(0.94, 0.95, 1.0),
	"l": Color(0.64, 0.69, 0.8),
	"D": Color(0.3, 0.33, 0.42),
	"G": Color(0.15, 0.62, 0.3),
	"Y": Color(0.98, 0.84, 0.2),
	"B": Color(0.86, 0.88, 0.95),
	"b": Color(0.56, 0.61, 0.73),
	"N": Color(0.22, 0.22, 0.27),
}
## A noite pinta o casco: a parte de cima fica no luar.
const LUAR := Color(0.74, 0.8, 0.96)
## Da boca da tubeira (0) à ponta da chama (fim).
const CORES_DA_CHAMA: Array[Color] = [
	Color(1.0, 1.0, 0.94),
	Color(1.0, 0.95, 0.66),
	Color(1.0, 0.82, 0.36),
	Color(1.0, 0.62, 0.2),
	Color(0.96, 0.42, 0.13),
	Color(0.82, 0.25, 0.1),
]

## Segundos entre a ignição e o foguete soltar da torre.
const SOLTURA := 0.6
## Em que fração do caminho os propulsores se soltam.
const SEPARACAO := 0.55
## Segundos que o último ponto de luz leva para apagar.
const APAGAR := 1.2
## Quadros por segundo da chama (ela tremula em quadros secos, como sprite).
const QUADROS_DA_CHAMA := 14.0
## O maior rolo de fumaça, em pixels de arte de raio.
const RAIO_MAXIMO := 12
## Teto de rolos de fumaça vivos.
const MAXIMO_DE_ROLOS := 520
## Segundos, depois da soltura, em que a nuvem da base ainda cresce.
const BASE_DURA := 2.6
## Segundos que os holofotes levam para apagar na ignição e para voltar depois
## que o foguete some.
const HOLOFOTES_APAGAM := 1.6
const HOLOFOTES_VOLTAM := 3.5

## Segundos da soltura até o foguete virar um ponto que apaga.
var duracao_do_voo := 11.0

var _partida := Vector2.ZERO
var _curva := Vector2.ZERO
var _chegada := Vector2.ZERO
## A beirada do telhado, em px desta camada: acima dela o céu aparece.
var _horizonte := 0.0

var _relogio := 0.0
var _t := 0.0
var _preparado := false
var _ligado := false
var _u := 0.0
var _pos := Vector2.ZERO
var _angulo := 0.0
var _forca := 0.0
var _chama := 0
var _largura_da_chama := 2.6
var _corpo := 1.0
var _clarao := 0.0
var _holofotes := 0.0
var _holofotes_alvo := 0.0
var _com_propulsores := true
var _rompeu := false
var _apagando := 0.0
var _sumiu := false
var _quadro := 0
var _presenca := 1.0
var _dissipar_em := 0.0
var _ultimo_rastro := Vector2.INF
var _tempo_da_base := 0.0
var _fumaca: Array[Dictionary] = []
var _propulsores: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

var _cor_fria := Color(0.56, 0.62, 0.83)
const COR_QUENTE := Color(1.0, 0.76, 0.48)

var _no_holofotes: Node2D
var _no_fumaca: Node2D
var _no_clarao: Node2D
var _no_foguete: Node2D
var _no_brilho: Node2D
var _material_do_clarao: ShaderMaterial
var _material_do_brilho: ShaderMaterial
var _raio_do_clarao := 1.0
var _raio_do_brilho := 1.0
var _texturas_da_fumaca: Array[ImageTexture] = []


func _init() -> void:
	name = "FogueteAoLonge"
	motion_scale = Vector2.ZERO
	_rng.seed = 2026


func _ready() -> void:
	_gerar_fumaca()
	var aditivo := CanvasItemMaterial.new()
	aditivo.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_no_holofotes = _novo_no("Holofotes", _desenhar_holofotes)
	_no_holofotes.material = aditivo
	_no_fumaca = _novo_no("Fumaca", _desenhar_fumaca)
	_no_fumaca.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_no_clarao = _novo_no("Clarao", _desenhar_clarao)
	_material_do_clarao = _novo_brilho(_no_clarao)
	_material_do_clarao.set_shader_parameter(&"raio_do_disco", 0.0)
	_material_do_clarao.set_shader_parameter(&"cor_interna", Color(1.0, 0.8, 0.52))
	_material_do_clarao.set_shader_parameter(&"cor_externa", Color(0.92, 0.36, 0.18))
	_material_do_clarao.set_shader_parameter(&"intensidade", 0.95)
	_material_do_clarao.set_shader_parameter(&"queda", 1.7)
	_material_do_clarao.set_shader_parameter(&"achatamento", 1.8)
	_material_do_clarao.set_shader_parameter(&"quadros_por_segundo", 0.0)
	_no_foguete = _novo_no("Foguete", _desenhar_foguete)
	_no_brilho = _novo_no("Brilho", _desenhar_brilho)
	_material_do_brilho = _novo_brilho(_no_brilho)
	_material_do_brilho.set_shader_parameter(&"raio_do_disco", 1.5)
	_material_do_brilho.set_shader_parameter(&"cor_interna", Color(1.0, 0.93, 0.72))
	_material_do_brilho.set_shader_parameter(&"cor_externa", Color(1.0, 0.5, 0.18))
	_material_do_brilho.set_shader_parameter(&"intensidade", 1.15)
	_material_do_brilho.set_shader_parameter(&"queda", 1.4)
	_material_do_brilho.set_shader_parameter(&"pixelado", 1.0)
	_material_do_brilho.set_shader_parameter(&"aneis", 4.0)
	_material_do_brilho.set_shader_parameter(&"pontilhado", 0.6)
	_material_do_brilho.set_shader_parameter(&"quadros_por_segundo", 10.0)
	_material_do_brilho.set_shader_parameter(&"respiro", 0.35)

	# A fumaça é da cor das nuvens da noite, um pouco mais clara.
	var regente := get_tree().get_first_node_in_group(&"atmosfera")
	if regente != null and regente.has_method(&"perfil_atual"):
		receber_perfil(regente.perfil_atual())


## A Atmosfera pula as camadas que têm isto (não veste o foguete com a luz do
## horário); a cor da fumaça sai das nuvens da hora.
func receber_perfil(perfil: Resource) -> void:
	if perfil == null or not "nuvem_luz" in perfil:
		return
	var nuvem: Color = perfil.nuvem_luz
	var cor := nuvem.lerp(Color(0.66, 0.68, 0.74), 0.45) * 1.15
	_cor_fria = Color(minf(cor.r, 1.0), minf(cor.g, 1.0), minf(cor.b, 1.0))


# ───────────────────────────────────────────────────────────── uso

## O caminho do foguete, em px desta camada: de onde ele parte (escondido
## atrás do telhado), o ponto que puxa a curva e onde ele some. "horizonte" é a
## beirada do telhado. Os holofotes da base acendem.
func preparar(partida: Vector2, curva: Vector2, chegada: Vector2, horizonte: float) -> void:
	_partida = partida
	_curva = curva
	_chegada = chegada
	_horizonte = horizonte
	_pos = partida
	_holofotes_alvo = 1.0
	_preparado = true


## Ignição.
func decolar() -> void:
	_ligado = true
	_t = 0.0


## O rastro some em "duracao" segundos e a camada vai embora.
func dissipar(duracao: float) -> void:
	_dissipar_em = maxf(duracao, 0.01)


## Quanto o lançamento ilumina o mundo agora (0 a 1): o clarão no horizonte.
func luz() -> float:
	return clampf(_clarao, 0.0, 1.0)


## Fração do caminho já feita (0 a 1).
func andamento() -> float:
	return _u


## O foguete já apagou (só o rastro ficou).
func ja_sumiu() -> bool:
	return _sumiu


# ───────────────────────────────────────────────────────────── o voo

func _process(delta: float) -> void:
	_relogio += delta
	_quadro = int(_relogio * QUADROS_DA_CHAMA)
	if _ligado:
		_t += delta
		_voar(delta)
		_soltar_fumaca(delta)
	else:
		_holofotes = move_toward(_holofotes, _holofotes_alvo,
			delta / (HOLOFOTES_VOLTAM if _sumiu else 1.5))
	_mexer_a_fumaca(delta)
	_mexer_os_propulsores(delta)
	if _dissipar_em > 0.0:
		_presenca = move_toward(_presenca, 0.0, delta / _dissipar_em)
		if _presenca <= 0.0:
			queue_free()
			return
	_posicionar_os_brilhos()
	_no_holofotes.queue_redraw()
	_no_fumaca.queue_redraw()
	_no_clarao.queue_redraw()
	_no_foguete.queue_redraw()
	_no_brilho.queue_redraw()


func _voar(delta: float) -> void:
	var t := _t
	_holofotes = move_toward(_holofotes, 0.0, delta / HOLOFOTES_APAGAM)

	var voo := clampf((t - SOLTURA) / duracao_do_voo, 0.0, 1.0)
	_u = ease(voo, -2.2) if t > SOLTURA else 0.0
	_pos = _bezier(_u)
	var tangente := _tangente(_u)
	_angulo = atan2(tangente.x, -tangente.y)

	# O clarão: acende de estalo, assenta e vai embora com o foguete.
	var acende := smoothstep(0.0, 0.12, t)
	var assenta := lerpf(1.0, 0.78, smoothstep(0.12, 0.7, t))
	var vai_embora := 1.0 - smoothstep(0.1, 0.62, _u)
	var tremida := 1.0 + 0.07 * sin(t * 37.0) + 0.05 * sin(t * 61.0 + 1.3)
	_clarao = acende * assenta * vai_embora * tremida

	# A chama: cresce na ignição, encolhe com a distância e apaga no fim.
	var ignicao := smoothstep(0.0, 0.3, t)
	if voo >= 1.0:
		_apagando += delta
		_forca = 0.45 * maxf(0.0, 1.0 - _apagando / APAGAR)
	else:
		_forca = ignicao * lerpf(1.0, 0.45, smoothstep(0.75, 1.0, _u))
	var comprimento: float
	if _u < SEPARACAO:
		comprimento = lerpf(10.0, 6.0, smoothstep(0.0, SEPARACAO, _u))
		_largura_da_chama = lerpf(2.6, 1.6, smoothstep(0.0, SEPARACAO, _u))
	else:
		comprimento = lerpf(4.0, 1.0, smoothstep(SEPARACAO, 1.0, _u))
		_largura_da_chama = lerpf(1.0, 0.0, smoothstep(SEPARACAO, 0.95, _u))
	comprimento *= ignicao
	if _forca > 0.01:
		_chama = maxi(1, roundi(comprimento + float(_sorteio(_quadro, 7) % 3) - 1.0))
	else:
		_chama = 0
	_corpo = 1.0 - smoothstep(0.38, 0.68, _u)

	_raio_do_brilho = lerpf(17.0, 5.0, smoothstep(0.0, 1.0, _u))
	_raio_do_clarao = 135.0 * lerpf(0.7, 1.0, smoothstep(0.0, 0.5, t))

	if not _rompeu and _pos.y - float(DESENHO.size()) * PIXEL * cos(_angulo) < _horizonte:
		_rompeu = true
		rompeu_o_horizonte.emit()
	if _com_propulsores and _u >= SEPARACAO:
		_separar()
	if voo >= 1.0 and _apagando >= APAGAR and not _sumiu:
		_sumiu = true
		_ligado = false
		_forca = 0.0
		_chama = 0
		_clarao = 0.0
		sumiu.emit()


func _bezier(u: float) -> Vector2:
	var a := _partida.lerp(_curva, u)
	var b := _curva.lerp(_chegada, u)
	return a.lerp(b, u)


func _tangente(u: float) -> Vector2:
	var d := 2.0 * (1.0 - u) * (_curva - _partida) + 2.0 * u * (_chegada - _curva)
	return d.normalized() if d.length_squared() > 0.0001 else Vector2.UP


## Os dois propulsores de lado soltam do corpo, ainda em brasa, e caem
## girando devagar para os lados.
func _separar() -> void:
	_com_propulsores = false
	var velocidade := _tangente(_u) * 26.0
	for lado in [-1.0, 1.0]:
		var encaixe := Vector2(2.5 * lado, -3.0).rotated(_angulo) * PIXEL
		_propulsores.append({
			"p": _pos + encaixe,
			"v": velocidade * 0.55 + Vector2(9.0 * lado, 3.0).rotated(_angulo),
			"ang": _angulo,
			"giro": lado * _rng.randf_range(0.5, 1.0),
			"vida": 0.0,
			"rastro": _pos + encaixe,
		})
	# O estalo da separação: um rolo quente e claro.
	_nova_fumaca(_pos, Vector2.ZERO, 3.5, 0.8, 1.0, false, 1.2)
	separou_os_propulsores.emit()


func _mexer_os_propulsores(delta: float) -> void:
	for i in range(_propulsores.size() - 1, -1, -1):
		var p: Dictionary = _propulsores[i]
		p["vida"] += delta
		var v: Vector2 = p["v"]
		v.y += 11.0 * delta
		p["v"] = v
		p["p"] += v * delta
		p["ang"] += float(p["giro"]) * delta
		var brasa := 1.0 - clampf(float(p["vida"]) / 1.8, 0.0, 1.0)
		if brasa > 0.25 and (p["p"] as Vector2).distance_to(p["rastro"]) >= 3.0:
			p["rastro"] = p["p"]
			_nova_fumaca(p["p"], Vector2.ZERO, 1.4, 1.6, 0.8, false, 0.55)
		if float(p["vida"]) > 4.0:
			_propulsores.remove_at(i)


# ───────────────────────────────────────────────────────────── a fumaça

func _soltar_fumaca(delta: float) -> void:
	if _forca < 0.12 or _sumiu:
		return
	# A nuvem da base, da ignição até ele já ir alto: o escape bate no chão da
	# base e sobe rolando para os lados. O pé dela fica atrás do telhado; o que
	# aparece por cima da beirada é a cúpula, acesa pela chama (calor do
	# clarão) — e, quando o clarão vai embora, cinza de luar.
	if _t < SOLTURA + BASE_DURA:
		_tempo_da_base -= delta
		while _tempo_da_base <= 0.0:
			_tempo_da_base += 0.05
			var aberta := smoothstep(0.0, SOLTURA + BASE_DURA, _t)
			var lado := _rng.randf_range(-1.0, 1.0)
			# Rolos de vários tamanhos e velocidades: uns abrem para os lados,
			# outros sobem quase parados no meio — a cúpula fica cheia, sem
			# virar dois blocos.
			_nova_fumaca(Vector2(_partida.x + lado * lerpf(4.0, 14.0, aberta),
					_horizonte + _rng.randf_range(4.0, 14.0)),
				Vector2(lado * _rng.randf_range(5.0, 34.0), _rng.randf_range(-18.0, -3.0)),
				_rng.randf_range(6.0, 12.0), 1.7, 1.0, true, 1.0, 3.0)
	if _t < SOLTURA:
		return
	# O rastro: um rolo a cada poucos px que a tubeira anda.
	if _ultimo_rastro == Vector2.INF:
		_ultimo_rastro = _pos
	var passo := 2.3
	var falta := _pos.distance_to(_ultimo_rastro)
	while falta >= passo:
		_ultimo_rastro = _ultimo_rastro.move_toward(_pos, passo)
		falta -= passo
		var grossura := lerpf(5.5, 1.3, smoothstep(0.15, 0.95, _u)) + _rng.randf_range(-0.6, 0.6)
		var densidade := lerpf(1.0, 0.6, smoothstep(0.55, 1.0, _u))
		_nova_fumaca(_ultimo_rastro + Vector2(_rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.8, 0.8)),
			Vector2(_rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.5, 0.5)),
			maxf(grossura, 1.0), 2.4, 1.0, false, densidade)


## Um rolo de fumaça em "p" (px desta camada), que cresce de "raio_inicial" a
## "raio" (pixels de arte) em uns "demora" segundos.
func _nova_fumaca(p: Vector2, v: Vector2, raio: float, demora: float, calor: float,
		da_base: bool, densidade: float = 1.0, raio_inicial: float = 1.2) -> void:
	if _fumaca.size() >= MAXIMO_DE_ROLOS:
		return
	_fumaca.append({
		"p": p, "v": v, "nasc": _relogio, "r0": minf(raio_inicial, raio), "r": raio,
		"tau": demora, "calor": calor, "base": da_base, "dens": densidade,
	})


func _mexer_a_fumaca(delta: float) -> void:
	var atrito := exp(-delta * 0.9)
	for f in _fumaca:
		var p: Vector2 = f["p"]
		var v: Vector2 = f["v"]
		f["p"] = p + (v + _vento(p)) * delta
		f["v"] = v * atrito


## O vento lá no alto é mais forte: a coluna vai entortando para a direita.
func _vento(p: Vector2) -> Vector2:
	var alto := clampf((_horizonte - p.y) / 320.0, 0.0, 1.0)
	return Vector2(lerpf(0.35, 1.9, alto) + sin(_relogio * 0.35 + p.y * 0.02) * 0.25, -0.1)


func _gerar_fumaca() -> void:
	_texturas_da_fumaca.clear()
	_texturas_da_fumaca.append(null)
	# A lua está no alto, à direita: o lado de lá do rolo é o claro.
	var luz := Vector2(0.62, -0.78).normalized()
	for r in range(1, RAIO_MAXIMO + 1):
		var lado := 2 * r + 1
		var imagem := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
		imagem.fill(Color(0, 0, 0, 0))
		for y in lado:
			for x in lado:
				var d := Vector2(x - r, y - r)
				if d.length_squared() > r * r + r * 0.8:
					continue
				var s := (d / float(r)).dot(luz)
				var tom := 0.8
				if s > 0.38:
					tom = 1.0
				elif s < -0.42:
					tom = 0.62
				imagem.set_pixel(x, y, Color(tom, tom, tom, 1.0))
		_texturas_da_fumaca.append(ImageTexture.create_from_image(imagem))


# ───────────────────────────────────────────────────────────── o desenho

func _novo_no(nome: String, desenho: Callable) -> Node2D:
	var no := Node2D.new()
	no.name = nome
	no.draw.connect(desenho)
	add_child(no)
	return no


func _novo_brilho(no: Node2D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER_DO_BRILHO
	material.set_shader_parameter(&"cobertura", 0.0)
	no.material = material
	# O shader conta em unidades do nó: na escala do pixel de arte, os raios
	# (e os anéis do pixelado) ficam na grade do resto.
	no.scale = Vector2(PIXEL, PIXEL)
	return material


func _desenhar_holofotes() -> void:
	var forca := _holofotes * _presenca
	if forca <= 0.005:
		return
	var base := Vector2(_partida.x, _horizonte + 30.0)
	for i in 2:
		var lado := -1.0 if i == 0 else 1.0
		var giro := lado * (0.13 + 0.05 * sin(_relogio * 0.45 + float(i) * 2.1))
		var direcao := Vector2(sin(giro), -cos(giro))
		var normal := Vector2(-direcao.y, direcao.x)
		var pe := base + Vector2(lado * 12.0, 0.0)
		var ponta := pe + direcao * 360.0
		var cor := Color(0.78, 0.86, 1.0, 0.13 * forca)
		var some := Color(0.78, 0.86, 1.0, 0.0)
		_no_holofotes.draw_polygon(
			PackedVector2Array([pe - normal * 2.0, pe + normal * 2.0, ponta + normal * 22.0, ponta - normal * 22.0]),
			PackedColorArray([cor, cor, some, some]))


func _desenhar_fumaca() -> void:
	for f in _fumaca:
		var idade: float = _relogio - float(f["nasc"])
		var r0: float = f["r0"]
		var r := r0 + (float(f["r"]) - r0) * (1.0 - exp(-idade / float(f["tau"])))
		var ri := clampi(roundi(r), 1, RAIO_MAXIMO)
		var p: Vector2 = f["p"]
		var calor: float = float(f["calor"]) * exp(-idade / 0.6)
		if f["base"]:
			# A nuvem da base é acesa por baixo, pela chama: mais quente no pé e
			# no meio, mais fria no alto e nas pontas.
			var alto := clampf((_horizonte - p.y) / 34.0, 0.0, 1.0)
			var longe := clampf(absf(p.x - _partida.x) / 56.0, 0.0, 1.0)
			calor = maxf(calor, _clarao * 0.9 * (1.0 - 0.55 * alto) * (1.0 - 0.45 * longe))
		# A chama acende a fumaça que está perto dela.
		var perto := 1.0 - clampf(p.distance_to(_pos) / 26.0, 0.0, 1.0)
		calor = maxf(calor, perto * _forca * 0.9)
		var cor := _cor_fria.lerp(COR_QUENTE, clampf(calor, 0.0, 1.0))
		cor.a = float(f["dens"]) * lerpf(0.92, 0.5, smoothstep(0.0, 50.0, idade)) * _presenca
		var celula := (p / PIXEL).floor()
		var lado := float(2 * ri + 1)
		_no_fumaca.draw_texture_rect(_texturas_da_fumaca[ri],
			Rect2((celula - Vector2(ri, ri)) * PIXEL, Vector2(lado, lado) * PIXEL), false, cor)


## O clarão fica na base (um pouco abaixo da beirada, para só a cúpula dele
## aparecer) e o brilho da chama, logo abaixo da tubeira.
func _posicionar_os_brilhos() -> void:
	_no_clarao.position = Vector2(_partida.x, _horizonte + 26.0)
	_material_do_clarao.set_shader_parameter(&"raio", _raio_do_clarao)
	_no_brilho.position = _pos + Vector2(0.0, float(_chama) * 0.35).rotated(_angulo) * PIXEL
	_raio_do_brilho_agora = _raio_do_brilho * lerpf(0.92, 1.08, float(_sorteio(_quadro, 3) % 5) / 4.0)
	_material_do_brilho.set_shader_parameter(&"raio", _raio_do_brilho_agora)


var _raio_do_brilho_agora := 1.0


func _desenhar_clarao() -> void:
	var forca := _clarao * _presenca
	if forca <= 0.005:
		return
	var borda := _raio_do_clarao + 2.0
	var achatamento := 1.8
	_no_clarao.draw_rect(Rect2(-borda, -borda / achatamento, borda * 2.0, borda * 2.0 / achatamento),
		Color(1, 1, 1, clampf(forca, 0.0, 1.0)))


func _desenhar_foguete() -> void:
	if not _preparado:
		return
	if not _ligado and not _sumiu:
		# Antes da ignição ele ainda está na torre, escondido atrás do telhado.
		_pintar_peca(DESENHO, _partida, 0.0, 1.0, 0, 0.0, 0.0)
		return
	if not _sumiu:
		var desenho := DESENHO if _com_propulsores else _sem_propulsores()
		_pintar_peca(desenho, _pos, _angulo, _corpo, _chama, _largura_da_chama, _forca)
	for p in _propulsores:
		var brasa := 1.0 - clampf(float(p["vida"]) / 1.8, 0.0, 1.0)
		var some := 1.0 - clampf((float(p["vida"]) - 2.0) / 2.0, 0.0, 1.0)
		var chama := 2 if brasa > 0.5 else (1 if brasa > 0.12 else 0)
		_pintar_peca(PROPULSOR, p["p"], p["ang"], 0.55 * some * _presenca, chama, 0.0, brasa)


func _desenhar_brilho() -> void:
	var forca := _forca * _presenca
	if forca <= 0.01:
		return
	var borda := _raio_do_brilho_agora * 1.5 + 2.0
	_no_brilho.draw_rect(Rect2(-borda, -borda, borda * 2.0, borda * 2.0), Color(1, 1, 1, clampf(forca, 0.0, 1.0)))


var _desenho_sem_propulsores: Array[String] = []

func _sem_propulsores() -> Array[String]:
	if _desenho_sem_propulsores.is_empty():
		for i in DESENHO.size():
			var linha := DESENHO[i]
			if i >= 11:
				linha = ".." + linha.substr(2, 3) + ".."
				if i == DESENHO.size() - 1:
					linha = "...N..."
			_desenho_sem_propulsores.append(linha)
	return _desenho_sem_propulsores


## Desenha uma peça (o foguete, ou um propulsor solto) girada em "angulo", com
## a base dela (a linha das tubeiras) em "base" (px desta camada). Cada pixel
## de arte em volta pergunta ao desenho que cor tem ali — é assim que a peça
## gira sem sair da grade. Abaixo da base vem a chama: "chama" pixels de
## comprido e "largura" de meia largura na boca; "calor" esquenta o casco
## perto dela.
func _pintar_peca(desenho: Array[String], base: Vector2, angulo: float, alfa: float,
		chama: int, largura: float, calor: float) -> void:
	alfa *= _presenca
	if alfa <= 0.01 and chama <= 0:
		return
	var altura := desenho.size()
	var largura_do_desenho := desenho[0].length()
	var meio := float(largura_do_desenho) * 0.5
	var origem := base / PIXEL
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	for canto: Vector2 in [Vector2(-meio, -altura), Vector2(meio, -altura),
			Vector2(-meio, chama), Vector2(meio, chama)]:
		var girado := canto.rotated(angulo)
		minimo = minimo.min(girado)
		maximo = maximo.max(girado)
	var de := (origem + minimo).floor() - Vector2.ONE
	var ate := (origem + maximo).ceil() + Vector2.ONE
	var cos_a := cos(-angulo)
	var sin_a := sin(-angulo)
	var tamanho := Vector2(PIXEL, PIXEL)
	for cy in range(int(de.y), int(ate.y) + 1):
		for cx in range(int(de.x), int(ate.x) + 1):
			var d := Vector2(float(cx) + 0.5, float(cy) + 0.5) - origem
			var q := Vector2(d.x * cos_a - d.y * sin_a, d.x * sin_a + d.y * cos_a)
			var cor: Color
			if q.y < 0.0:
				if alfa <= 0.01:
					continue
				var linha := int(floor(q.y + float(altura)))
				var coluna := int(floor(q.x + meio))
				if linha < 0 or linha >= altura or coluna < 0 or coluna >= largura_do_desenho:
					continue
				var letra := desenho[linha][coluna]
				if letra == ".":
					continue
				cor = CORES[letra] * LUAR
				var embaixo := float(linha) / float(altura)
				cor = cor.lerp(Color(1.0, 0.72, 0.45), calor * embaixo * embaixo * 0.75)
				cor.a = alfa
			else:
				if chama <= 0:
					continue
				var k := int(floor(q.y))
				if k >= chama:
					continue
				var f := float(k) / float(chama)
				var meia := largura * pow(1.0 - f, 0.6)
				if absf(q.x) > meia + 0.5:
					continue
				# A ponta da chama se desfaz em pixels soltos.
				if f > 0.55 and float(_sorteio(_quadro * 131 + cx * 17, cy) % 100) < 35.0:
					continue
				cor = CORES_DA_CHAMA[clampi(int(f * CORES_DA_CHAMA.size()), 0, CORES_DA_CHAMA.size() - 1)]
				cor.a = _presenca
			_no_foguete.draw_rect(Rect2(Vector2(cx, cy) * PIXEL, tamanho), cor)


## Um número "sorteado" sempre igual para o mesmo par (a chama tremula sem
## piscar diferente a cada redesenho do mesmo quadro).
static func _sorteio(a: int, b: int) -> int:
	var h := (a * 73856093) ^ (b * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))
