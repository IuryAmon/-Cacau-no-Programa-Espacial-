class_name MorteDespedacada
extends Node2D

# --- MORTE DESPEDAÇADA (A LÂMINA PEGOU A PERSONAGEM) ---
#
# O efeito de morte das armadilhas de corte (a SERRA ELÉTRICA e os ESPINHOS DE
# LASER, que são a mesma armadilha com lâminas diferentes). Encostar na lâmina
# não faz mais a tela simplesmente reiniciar: a personagem é PICADA no lugar,
# em cacos do próprio sprite dela, e o sangue cai e mancha o chão.
#
# O efeito é 100% de runtime — não tem cena, não tem PNG novo, não precisa de
# nada montado no editor. Ele lê o QUADRO EXATO que a personagem estava
# mostrando no instante do golpe (pose, direção, animação) e recorta esse
# quadro numa grade. Ou seja: morreu correndo, os cacos voam na pose de
# corrida; morreu no ar, voam na pose do pulo.
#
# --- AS QUATRO CAMADAS (é a soma delas que dá o peso da morte) ---
#
#   1. CACOS      pedaços do sprite, cada um um Sprite2D com "region_rect" em
#                 cima da textura original. Voam para longe da lâmina (quem
#                 estava mais perto do disco sai mais rápido), giram, batem no
#                 chão de verdade (raycast na física da fase), quicam e param.
#   2. SPRAY      duas rajadas de partículas: o esguicho fino e rápido do
#                 talho, e uma névoa mais lenta que fica pairando um instante.
#   3. GOTAS      gotas grossas com física própria, que caem, ACHAM O CHÃO e
#                 viram uma mancha no ponto exato em que bateram.
#   4. MANCHAS    as poças. Nascem com um "pop" (crescem estourando) e ficam.
#                 A poça grande embaixo do corpo vem meio segundo depois, como
#                 se estivesse escorrendo.
#
# Mais dois toques que são o que separa "tem um efeito" de "dói de ver": um
# CONGELAMENTO de 90 ms no frame do impacto e o TREMOR da câmera.
#
# --- COMO USAR ---
#
#   MorteDespedacada.explodir(cena, sprite_da_personagem, posicao_da_lamina)
#
# Quem chama é o player, dentro da morte dele (ver "_morrer_a_pedacos" em
# scripts/player.gd). A armadilha só avisa, ANTES de aplicar o golpe, que
# aquela morte é de corte — ver "_avisar_que_e_corte" em espinhos_laser.gd.
#
# --- PARA REGULAR O EXAGERO ---
#
# Tudo que dá o gosto está nas constantes abaixo. Os três diais que mais mudam
# a cara do efeito: TAMANHO_CACO (cacos maiores = menos gore, mais "boneco
# quebrado"), GOTAS (quanto sangue voa) e ESCALA_SANGUE (o tamanho das poças).
# Zerando GOTAS e MANCHAS_DO_TALHO sobra só o despedaçamento, sem sangue.


# --- CACOS ---

## Lado que cada caco tenta ter, em pixels de ARTE (antes da escala do nó).
## É daqui que sai a grade: um desenho de 64x64 vira mais ou menos 7x7 cacos.
const TAMANHO_CACO := 9.0
const MIN_COLUNAS := 3
const MAX_COLUNAS := 7
const MIN_LINHAS := 4
const MAX_LINHAS := 9

## Empurrão dos cacos. Quem estava dentro de ALCANCE_DO_GOLPE da lâmina sai com
## IMPULSO_PERTO; o resto do corpo vai desandando até IMPULSO_LONGE. É essa
## diferença que faz o corpo parecer ARRANCADO de um lado, e não estourado por
## dentro como uma bomba.
const ALCANCE_DO_GOLPE := 90.0
const IMPULSO_PERTO := 520.0
const IMPULSO_LONGE := 190.0
## Quanto do empurrão é jogado para cima. Sem isto os cacos escorrem no chão.
const VIES_PRA_CIMA := 0.75
## Bagunça na direção de cada caco: 0 = leque perfeito, 1 = confete.
const ESPALHAMENTO := 0.38
const GIRO_MAX := 16.0

const GRAVIDADE := 1500.0
## Quanto da velocidade sobra depois de bater no chão (0 = cai morto).
const QUIQUE := 0.34
## Freio que o chão dá no deslizamento a cada batida. Baixo de propósito: os
## pedaços têm que ficar amontoados perto de onde a personagem morreu, e não
## patinar meia sala.
const ATRITO_CHAO := 0.42
## Abaixo desta velocidade o caco desiste e fica deitado onde parou.
const PARAR_ABAIXO_DE := 45.0

## Quantos cacos vão sangrando enquanto voam (deixam um rastro de gotinhas), de
## quanto em quanto tempo pinga e por quanto tempo. O rastro é curto de
## propósito: ele existe para desenhar o ARCO do pedaço no ar, não para pintar
## a sala — pingando o tempo todo vira confete vermelho e o efeito perde a
## leitura de "pedaço voando".
const CACOS_QUE_SANGRAM := 4
const INTERVALO_DO_RASTRO := 0.11
const DURACAO_DO_RASTRO := 0.5


# --- SANGUE ---

const COR_SANGUE := Color(0.58, 0.04, 0.06)
const COR_SANGUE_VIVO := Color(0.86, 0.13, 0.11)
const COR_SANGUE_SECO := Color(0.26, 0.02, 0.03)

## Gotas grossas que caem e viram mancha onde baterem.
const GOTAS := 18
const GOTA_IMPULSO_MIN := 140.0
const GOTA_IMPULSO_MAX := 560.0
const GOTA_RAIO_MIN := 1.6
const GOTA_RAIO_MAX := 3.4

## Manchas que o talho joga direto no chão em volta, sem esperar gota nenhuma.
const MANCHAS_DO_TALHO := 4
## Multiplicador geral do tamanho de toda mancha.
const ESCALA_SANGUE := 1.0
## O achatamento das poças: elas são desenhadas redondas e esmagadas contra o
## chão por esta escala em Y, o que dá a leitura de "está deitado no piso".
const ACHATAMENTO := 0.42
## Quanto a mancha afunda para DENTRO da superfície em que grudou (para baixo,
## num chão). Desenhada no ponto exato do impacto, metade dela fica acima da
## linha do piso e a poça parece pairar um dedo do chão; afundando um pouco ela
## assenta. O empurrão é proporcional à meia-altura da própria mancha — poça
## grande desce mais que respingo — mais um teco fixo para as menores.
const AFUNDAR := 0.55
const AFUNDAR_FIXO := 2.0
## Alcance do raycast que procura o piso embaixo do corpo, para a poça grande.
const ALCANCE_DO_CHAO := 420.0
## Teto de manchas na cena. Existe por dois motivos: o chão vira um tapete
## vermelho sem graça se todo pingo marcar, e cada mancha é um nó que desenha.
## Passou do teto, o sangue novo só não deixa marca.
const LIMITE_MANCHAS := 45


# --- TEMPO ---

## Congelamento do frame do impacto (em tempo real, alheio ao time_scale).
const CONGELAR_DURACAO := 0.09
const CONGELAR_ESCALA := 0.06
const TREMOR := 26.0
## Espera até a poça grande começar a se formar embaixo do corpo.
const ATRASO_DA_POCA := 0.45
## Quanto o rastro todo fica na cena antes de sumir. Na morte de verdade a fase
## reinicia bem antes disso — o fim aqui é só para o efeito não vazar se alguém
## usar ele fora de uma morte.
const VIDA_TOTAL := 6.0
const FADE_FINAL := 1.0

enum { CACO, GOTA }

## Preenchido pelo "explodir()" antes do nó entrar na árvore.
var _quadro: Dictionary = {}
var _origem: Vector2 = Vector2.ZERO
var _corpo_ignorado: RID = RID()

var _pecas: Array[Dictionary] = []
var _espaco: PhysicsDirectSpaceState2D = null
var _manchas: int = 0
## Textura das partículas: um pontinho redondo gerado na primeira morte e
## reaproveitado em todas as seguintes.
static var _ponto: ImageTexture = null


# --- ENTRADA ---

## Despedaça o quadro atual de `sprite` e sangra tudo em volta. `pai` é onde o
## rastro vive (a cena da fase, não a personagem — ela some) e
## `origem_do_golpe` é a posição da lâmina: é dela que os cacos fogem.
static func explodir(pai: Node, sprite: AnimatedSprite2D, origem_do_golpe: Vector2) -> MorteDespedacada:
	if pai == null or sprite == null:
		return null

	var fx := MorteDespedacada.new()
	fx.name = "MorteDespedacada"
	fx._quadro = _ler_quadro(sprite)
	fx._origem = origem_do_golpe
	fx._corpo_ignorado = _rid_do_corpo(sprite)
	Blockout.adicionar(pai, fx)
	return fx


func _ready() -> void:
	# Acima do cenário; os cacos ainda por cima das poças, que nascem com z
	# relativo negativo (ver _criar_mancha).
	z_index = 6
	_espaco = get_world_2d().direct_space_state

	_montar_cacos()
	_esguichar()
	_soltar_gotas()
	_sujar_o_chao_em_volta()
	_tremer_a_camera()
	_congelar_o_tempo()

	# A poça grande não nasce junto com o talho: ela escorre depois.
	var atraso := create_tween()
	atraso.tween_interval(ATRASO_DA_POCA)
	atraso.tween_callback(_poca_do_corpo)

	var fim := create_tween()
	fim.tween_interval(VIDA_TOTAL)
	fim.tween_property(self, "modulate:a", 0.0, FADE_FINAL)
	fim.tween_callback(queue_free)


# --- LEITURA DO QUADRO DA PERSONAGEM ---

## Tira uma "fotografia" do sprite no instante do golpe: a textura de origem, o
## retângulo do quadro dentro dela, a transformação no mundo e a imagem em CPU
## (usada para descobrir onde tem pixel de verdade). Precisa acontecer ANTES de
## a personagem ser escondida, por isso é separada do resto.
static func _ler_quadro(sprite: AnimatedSprite2D) -> Dictionary:
	var quadros: SpriteFrames = sprite.sprite_frames
	if quadros == null or not quadros.has_animation(sprite.animation):
		return {}

	var total: int = quadros.get_frame_count(sprite.animation)
	if total <= 0:
		return {}
	var indice: int = clampi(sprite.frame, 0, total - 1)
	var textura: Texture2D = quadros.get_frame_texture(sprite.animation, indice)
	if textura == null:
		return {}

	# Folhas de sprite chegam como AtlasTexture (um recorte da folha grande);
	# um PNG solto chega inteiro. Os dois viram "textura base + região".
	var base: Texture2D = textura
	var regiao := Rect2i(Vector2i.ZERO, Vector2i(textura.get_size()))
	if textura is AtlasTexture:
		var atlas := textura as AtlasTexture
		if atlas.atlas == null:
			return {}
		base = atlas.atlas
		regiao = Rect2i(atlas.region)

	# O recorte em CPU serve para dois cuidados que fazem toda a diferença:
	# ignorar a moldura transparente em volta do desenho (senão os cacos das
	# beiradas saem vazios e o "corpo" parece maior do que é) e pular as
	# células que não têm pixel nenhum.
	var imagem: Image = null
	var util := regiao
	var pixels: Image = base.get_image()
	if pixels and pixels.is_compressed() and pixels.decompress() != OK:
		pixels = null
	if pixels:
		regiao = regiao.intersection(Rect2i(Vector2i.ZERO, pixels.get_size()))
		if regiao.has_area():
			imagem = pixels.get_region(regiao)
			var usados := imagem.get_used_rect()
			if usados.has_area():
				util = Rect2i(regiao.position + usados.position, usados.size)

	if not util.has_area():
		return {}

	return {
		"textura": base,
		"regiao": regiao,     # o quadro inteiro (é o centro DELE que o nó desenha)
		"util": util,         # só a parte com desenho — é ela que é picada
		"imagem": imagem,     # o quadro em CPU, para testar transparência
		"transform": sprite.get_global_transform(),
		"offset": sprite.offset,
		"flip_h": sprite.flip_h,
		"flip_v": sprite.flip_v,
	}


## O corpo físico dono do sprite (a personagem). Os raycasts dos cacos ignoram
## ele: senão o primeiro caco bate na cápsula de colisão da própria vítima e
## para no ar.
static func _rid_do_corpo(no: Node) -> RID:
	var atual: Node = no
	while atual:
		if atual is CollisionObject2D:
			return (atual as CollisionObject2D).get_rid()
		atual = atual.get_parent()
	return RID()


# --- OS CACOS ---

func _montar_cacos() -> void:
	if _quadro.is_empty():
		return

	var util: Rect2i = _quadro["util"]
	var regiao: Rect2i = _quadro["regiao"]
	var imagem: Image = _quadro["imagem"]
	var t: Transform2D = _quadro["transform"]
	var escala: Vector2 = t.get_scale().abs()
	var giro_do_sprite: float = t.get_rotation()

	# A grade se ajusta ao tamanho do desenho: personagem miúda não vira pó,
	# personagem grande não vira dois blocos.
	var colunas: int = clampi(roundi(util.size.x / TAMANHO_CACO), MIN_COLUNAS, MAX_COLUNAS)
	var linhas: int = clampi(roundi(util.size.y / TAMANHO_CACO), MIN_LINHAS, MAX_LINHAS)
	var centro_do_quadro := Vector2(regiao.size) * 0.5

	var sorteio: Array[int] = []
	for i in colunas * linhas:
		sorteio.append(i)
	sorteio.shuffle()
	var sangradores: Array = sorteio.slice(0, CACOS_QUE_SANGRAM)

	for lin in linhas:
		for col in colunas:
			# Divisão inteira acumulada: nenhum pixel sobra nem se repete entre
			# células vizinhas.
			var x0: int = util.position.x + (util.size.x * col) / colunas
			var x1: int = util.position.x + (util.size.x * (col + 1)) / colunas
			var y0: int = util.position.y + (util.size.y * lin) / linhas
			var y1: int = util.position.y + (util.size.y * (lin + 1)) / linhas
			var celula := Rect2i(x0, y0, maxi(x1 - x0, 1), maxi(y1 - y0, 1))
			if not _tem_desenho(imagem, celula, regiao.position):
				continue

			var caco := Sprite2D.new()
			caco.texture = _quadro["textura"]
			caco.region_enabled = true
			caco.region_rect = Rect2(celula)
			caco.flip_h = _quadro["flip_h"]
			caco.flip_v = _quadro["flip_v"]
			caco.scale = escala
			caco.rotation = giro_do_sprite

			# Onde este pedaço estava na tela: o centro da célula, medido a
			# partir do centro do quadro (é ali que o sprite desenha a origem
			# dele), espelhado se a personagem estava virada, e então passado
			# pela transformação do nó.
			var local := Vector2(celula.position) + Vector2(celula.size) * 0.5 \
				- Vector2(regiao.position) - centro_do_quadro
			if _quadro["flip_h"]:
				local.x = -local.x
			if _quadro["flip_v"]:
				local.y = -local.y
			caco.global_position = t * (_quadro["offset"] + local)
			add_child(caco)

			var indice: int = lin * colunas + col
			_pecas.append({
				"no": caco,
				"vel": _impulso(caco.global_position),
				"giro": randf_range(-GIRO_MAX, GIRO_MAX),
				"tipo": CACO,
				"parado": false,
				"sangra": sangradores.has(indice),
				"proxima_gota": 0.0,
				"rastro_restante": DURACAO_DO_RASTRO,
			})


## Existe pixel opaco nesta célula? `origem` é o canto do recorte em CPU dentro
## da textura, para converter as coordenadas.
static func _tem_desenho(imagem: Image, celula: Rect2i, origem: Vector2i) -> bool:
	if imagem == null:
		return true  # sem imagem em CPU, aceita tudo (é só um caco a mais)
	var local := Rect2i(celula.position - origem, celula.size)
	local = local.intersection(Rect2i(Vector2i.ZERO, imagem.get_size()))
	if not local.has_area():
		return false
	return imagem.get_region(local).get_used_rect().has_area()


## O empurrão que um pedaço leva: para longe da lâmina, com um viés para cima e
## uma bagunçada, mais forte em quem estava no caminho do disco.
func _impulso(pos: Vector2) -> Vector2:
	var fuga: Vector2 = pos - _origem
	if fuga.length() < 1.0:
		fuga = Vector2(randf_range(-1.0, 1.0), -1.0)
	var distancia: float = fuga.length()
	fuga = fuga.normalized()

	var direcao: Vector2 = (fuga \
		+ Vector2.UP * VIES_PRA_CIMA \
		+ Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * ESPALHAMENTO).normalized()

	var perto: float = 1.0 - clampf(distancia / ALCANCE_DO_GOLPE, 0.0, 1.0)
	var forca: float = lerpf(IMPULSO_LONGE, IMPULSO_PERTO, perto * perto)
	return direcao * forca * randf_range(0.75, 1.25)


# --- FÍSICA DOS CACOS E DAS GOTAS ---

func _physics_process(delta: float) -> void:
	if _pecas.is_empty():
		return

	var restantes: Array[Dictionary] = []
	for peca in _pecas:
		var no: Node2D = peca["no"]
		if not is_instance_valid(no):
			continue
		if peca["parado"]:
			restantes.append(peca)
			continue

		var vel: Vector2 = peca["vel"]
		vel.y += GRAVIDADE * delta
		var de: Vector2 = no.global_position
		var para: Vector2 = de + vel * delta

		var batida := _bater(de, para)
		if batida.is_empty():
			no.global_position = para
			if peca["tipo"] == CACO:
				no.rotation += peca["giro"] * delta
			else:
				# A gota se estica na direção em que está caindo — é o que dá a
				# leitura de velocidade num pingo de três pixels.
				no.rotation = vel.angle()
				no.scale.x = 1.0 + minf(vel.length() / 700.0, 2.2)
			peca["vel"] = vel
			_pingar(peca, delta)
			restantes.append(peca)
			continue

		# Bateu em alguma coisa (chão, parede, caixa).
		var ponto: Vector2 = batida["ponto"]
		var normal: Vector2 = batida["normal"]

		# Normal zerada = o raio já NASCEU dentro do cenário (o pedaço quicou
		# para dentro de um canto de tile). Sem isto ele sairia pelo chão: uma
		# vez enfiado na geometria, todo raio seguinte também nasceria lá
		# dentro e nunca mais acharia superfície nenhuma. Então ele para onde
		# estava, deitado, como se tivesse encaixado no canto.
		var enterrado: bool = normal.is_zero_approx()
		if enterrado:
			ponto = de
			normal = Vector2.UP

		if peca["tipo"] == GOTA:
			# A gota morre no impacto e vira mancha, deitada na superfície.
			_criar_mancha(ponto + normal * 0.5, normal,
				randf_range(2.2, 4.8) * ESCALA_SANGUE, randi_range(1, 3))
			no.queue_free()
			continue

		no.global_position = ponto + normal * 2.5
		# Quica com perda: a componente contra a superfície volta reduzida e o
		# deslizamento sofre o atrito do chão.
		var contra: Vector2 = normal * vel.dot(normal)
		var desliza: Vector2 = vel - contra
		vel = desliza * ATRITO_CHAO - contra * QUIQUE
		if enterrado:
			vel = Vector2.ZERO
		peca["giro"] = peca["giro"] * 0.45
		no.rotation += peca["giro"] * delta

		if vel.length() < PARAR_ABAIXO_DE:
			peca["parado"] = true
			vel = Vector2.ZERO
			# Todo caco que assenta deixa a marca de onde caiu.
			if randf() < 0.40:
				_criar_mancha(no.global_position, normal,
					randf_range(2.5, 5.0) * ESCALA_SANGUE, randi_range(0, 2))
		elif peca["sangra"]:
			_criar_mancha(ponto, normal, randf_range(3.0, 5.5) * ESCALA_SANGUE, randi_range(1, 2))

		peca["vel"] = vel
		restantes.append(peca)

	_pecas = restantes


## Raycast do ponto anterior para o novo. Devolve {} se o caminho estava livre.
func _bater(de: Vector2, para: Vector2) -> Dictionary:
	if _espaco == null or de.is_equal_approx(para):
		return {}
	var consulta := PhysicsRayQueryParameters2D.create(de, para)
	consulta.collide_with_areas = false
	# Também acusa quando o raio começa DENTRO de um corpo (o pedaço se enfiou
	# num canto de tile). Nesse caso a engine devolve normal zerada — quem
	# trata é _physics_process.
	consulta.hit_from_inside = true
	if _corpo_ignorado.is_valid():
		consulta.exclude = [_corpo_ignorado]
	var res := _espaco.intersect_ray(consulta)
	if res.is_empty():
		return {}
	return {"ponto": res["position"], "normal": res["normal"]}


## Rastro de sangue dos cacos marcados: uma gotinha a cada tantos milésimos,
## herdando parte da velocidade de quem está sangrando.
func _pingar(peca: Dictionary, delta: float) -> void:
	if peca["tipo"] != CACO or not peca["sangra"]:
		return
	peca["rastro_restante"] = peca["rastro_restante"] - delta
	if peca["rastro_restante"] <= 0.0:
		peca["sangra"] = false  # já desenhou o arco dele no ar; agora só voa
		return
	peca["proxima_gota"] = peca["proxima_gota"] - delta
	if peca["proxima_gota"] > 0.0:
		return
	peca["proxima_gota"] = INTERVALO_DO_RASTRO
	var no: Node2D = peca["no"]
	_nova_gota(no.global_position,
		peca["vel"] * 0.35 + Vector2(randf_range(-40.0, 40.0), 0.0),
		randf_range(GOTA_RAIO_MIN, GOTA_RAIO_MIN + 1.0))


# --- SANGUE: PARTÍCULAS, GOTAS E MANCHAS ---

## As duas rajadas do talho. A primeira é o esguicho: rápido, fino, quase
## instantâneo. A segunda é a névoa que sobra pairando meio segundo — é ela que
## faz o corte parecer molhado em vez de um estouro de confete.
func _esguichar() -> void:
	var direcao: Vector2 = (_media_dos_cacos() - _origem).normalized()
	if direcao == Vector2.ZERO:
		direcao = Vector2.UP

	# Os tamanhos são pequenos de propósito. O "ponto" tem 8 px, então
	# tamanho 1.0 já é uma bola de 8 px de arte — do tamanho da cabeça da
	# personagem. Acima disso o sangue vira tinta e engole os cacos, que são o
	# assunto principal da cena.
	_criar_particulas({
		"quantidade": 85,
		"vida": 0.75,
		"direcao": direcao,
		"abertura": 58.0,
		"vel_min": 220.0,
		"vel_max": 780.0,
		"tamanho_min": 0.35,
		"tamanho_max": 0.95,
		"gravidade": 1500.0,
		"amortecimento": 60.0,
	})
	_criar_particulas({
		"quantidade": 30,
		"vida": 1.15,
		"direcao": direcao.rotated(randf_range(-0.3, 0.3)),
		"abertura": 105.0,
		"vel_min": 40.0,
		"vel_max": 240.0,
		"tamanho_min": 0.6,
		"tamanho_max": 1.6,
		"gravidade": 760.0,
		"amortecimento": 55.0,
	})


func _criar_particulas(cfg: Dictionary) -> void:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	# Em coordenadas do mundo: as partículas ficam onde foram cuspidas, não
	# grudadas no nó.
	p.local_coords = false
	p.amount = cfg["quantidade"]
	p.lifetime = cfg["vida"]
	p.lifetime_randomness = 0.4
	p.texture = _textura_do_ponto()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	p.direction = cfg["direcao"]
	p.spread = cfg["abertura"]
	p.initial_velocity_min = cfg["vel_min"]
	p.initial_velocity_max = cfg["vel_max"]
	p.gravity = Vector2(0.0, cfg["gravidade"])
	p.damping_min = cfg["amortecimento"] * 0.5
	p.damping_max = cfg["amortecimento"]
	p.scale_amount_min = cfg["tamanho_min"]
	p.scale_amount_max = cfg["tamanho_max"]
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0

	# Vivo ao sair, escurecendo e sumindo: sangue no ar clareia, sangue parado
	# escurece.
	var rampa := Gradient.new()
	rampa.set_color(0, COR_SANGUE_VIVO)
	rampa.set_color(1, Color(COR_SANGUE_SECO, 0.0))
	rampa.add_point(0.45, COR_SANGUE)
	p.color_ramp = rampa

	p.position = to_local(_origem)
	add_child(p)
	p.emitting = true


## Gotas grossas: são elas que "caem no chão" de verdade, porque cada uma
## procura o piso e vira mancha onde bate (ver _physics_process).
func _soltar_gotas() -> void:
	for i in GOTAS:
		var direcao: Vector2 = Vector2.UP.rotated(randf_range(-PI * 0.75, PI * 0.75))
		var vel: Vector2 = direcao * randf_range(GOTA_IMPULSO_MIN, GOTA_IMPULSO_MAX)
		vel.y -= randf_range(60.0, 260.0)  # todas nascem com um repuxo pra cima
		_nova_gota(_origem + Vector2(randf_range(-14.0, 14.0), randf_range(-26.0, 10.0)),
			vel, randf_range(GOTA_RAIO_MIN, GOTA_RAIO_MAX))


func _nova_gota(pos: Vector2, vel: Vector2, raio: float) -> void:
	var gota := Gota.new()
	gota.raio = raio
	gota.cor = COR_SANGUE_VIVO.lerp(COR_SANGUE, randf())
	gota.z_index = 1
	add_child(gota)
	gota.global_position = pos
	_pecas.append({
		"no": gota,
		"vel": vel,
		"giro": 0.0,
		"tipo": GOTA,
		"parado": false,
		"sangra": false,
		"proxima_gota": 0.0,
		"rastro_restante": 0.0,
	})


## O talho joga sangue no chão em volta na hora, sem esperar as gotas caírem:
## são as marcas que já aparecem no frame do impacto.
func _sujar_o_chao_em_volta() -> void:
	for i in MANCHAS_DO_TALHO:
		var lado: float = signf(randf() - 0.5)
		var alvo: Vector2 = _origem + Vector2(lado * randf_range(20.0, 130.0), randf_range(-30.0, 20.0))
		var chao := _procurar_chao(alvo)
		if chao.is_empty():
			continue
		_criar_mancha(chao["ponto"], chao["normal"],
			randf_range(3.0, 7.0) * ESCALA_SANGUE, randi_range(1, 4))


## A poça embaixo do corpo: a maior de todas, e a única que cresce devagar,
## como se estivesse escorrendo e se juntando.
func _poca_do_corpo() -> void:
	var chao := _procurar_chao(_origem)
	if chao.is_empty():
		return
	_criar_mancha(chao["ponto"], chao["normal"], 18.0 * ESCALA_SANGUE, 6, 0.9, true)

	# Um segundo derrame por cima, um pouco depois e deslocado: a poça ganha
	# borda irregular em vez de virar um círculo perfeito.
	var atraso := create_tween()
	atraso.tween_interval(0.5)
	atraso.tween_callback(func() -> void:
		_criar_mancha(chao["ponto"] + Vector2(randf_range(-16.0, 16.0), 0.0), chao["normal"],
			13.0 * ESCALA_SANGUE, 3, 1.1, true))


## Procura o piso abaixo de um ponto. A normal volta sempre utilizável: se o
## ponto já estava dentro do cenário, a engine devolve normal zerada e aqui ela
## vira "para cima" — uma poça deitada é sempre melhor do que uma em pé.
func _procurar_chao(de: Vector2) -> Dictionary:
	var chao := _bater(de, de + Vector2(0.0, ALCANCE_DO_CHAO))
	if not chao.is_empty() and (chao["normal"] as Vector2).is_zero_approx():
		chao["normal"] = Vector2.UP
	return chao


## Uma poça: um punhado de círculos sobrepostos, achatados contra o chão e
## alinhados com a inclinação dele, que nascem estourando (o "pop" é o que faz
## a mancha parecer respingada, e não desenhada).
func _criar_mancha(pos: Vector2, normal: Vector2, raio: float, respingos: int,
		duracao: float = 0.22, essencial: bool = false) -> Mancha:
	# A poça do corpo é "essencial": ela é o desenho principal da morte e não
	# pode ser barrada pelo teto por causa de um punhado de respingos que
	# chegaram antes.
	if _manchas >= LIMITE_MANCHAS and not essencial:
		return null
	_manchas += 1
	var mancha := Mancha.new()
	mancha.cor = COR_SANGUE
	mancha.cor_borda = COR_SANGUE_SECO
	mancha.bolhas = _desenhar_poca(raio, respingos)
	# Abaixo dos cacos: o corpo cai POR CIMA do próprio sangue.
	mancha.z_index = -2
	add_child(mancha)
	# Afunda na superfície em vez de ficar centrada na linha dela (ver AFUNDAR).
	mancha.global_position = pos - normal * (raio * ACHATAMENTO * AFUNDAR + AFUNDAR_FIXO)
	mancha.rotation = normal.angle() + PI * 0.5

	var cheia := Vector2(1.0, ACHATAMENTO)
	mancha.scale = cheia * 0.15
	var pop := create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	pop.tween_property(mancha, "scale", cheia, duracao)
	return mancha


## O miolo da poça (círculos grandes embolados) mais os respingos soltos em
## volta, que são o que tira a cara de "bolha" da mancha.
static func _desenhar_poca(raio: float, respingos: int) -> Array[Vector3]:
	var bolhas: Array[Vector3] = []
	for i in randi_range(3, 5):
		var deslocamento := Vector2(randf_range(-raio, raio), randf_range(-raio, raio)) * 0.55
		bolhas.append(Vector3(deslocamento.x, deslocamento.y, raio * randf_range(0.55, 1.0)))
	for i in respingos:
		var longe := Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * raio * randf_range(1.3, 2.8)
		bolhas.append(Vector3(longe.x, longe.y, raio * randf_range(0.14, 0.34)))
	return bolhas


## Centro de massa dos cacos: serve para saber para que lado o corpo foi
## arrancado, e mirar o esguicho nessa direção.
func _media_dos_cacos() -> Vector2:
	if _pecas.is_empty():
		return _origem + Vector2.UP * 30.0
	var soma := Vector2.ZERO
	for peca in _pecas:
		soma += (peca["no"] as Node2D).global_position
	return soma / _pecas.size()


## O pontinho das partículas, gerado uma vez só: um disco de borda macia, que
## em qualquer tamanho continua parecendo uma gota e não um quadrado.
static func _textura_do_ponto() -> ImageTexture:
	if _ponto != null:
		return _ponto
	var lado := 8
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	var centro := Vector2(lado - 1, lado - 1) * 0.5
	for y in lado:
		for x in lado:
			var d: float = Vector2(x, y).distance_to(centro) / (lado * 0.5)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(1.0 - d * d, 0.0, 1.0)))
	_ponto = ImageTexture.create_from_image(img)
	return _ponto


# --- CÂMERA E TEMPO ---

func _tremer_a_camera() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("disparar_tremor"):
		camera.disparar_tremor(TREMOR)


## Segura o frame do impacto por um instante. O timer é de TEMPO REAL (o último
## argumento), senão ele mesmo entraria em câmera lenta e o jogo travaria por um
## segundo e meio em vez de 90 ms.
func _congelar_o_tempo() -> void:
	if CONGELAR_DURACAO <= 0.0:
		return
	Engine.time_scale = CONGELAR_ESCALA
	await get_tree().create_timer(CONGELAR_DURACAO, true, false, true).timeout
	Engine.time_scale = 1.0


# --- DESENHOS ---

## Uma gota no ar. É desenhada redonda e esticada na direção do voo pelo
## scale.x que a física ajusta a cada frame.
class Gota extends Node2D:
	var raio: float = 2.0
	var cor: Color = Color(0.7, 0.05, 0.07)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, raio, cor)


## Uma mancha no chão: os círculos do miolo e os respingos, cada um com um fio
## de contorno escuro por baixo para a poça ter borda.
class Mancha extends Node2D:
	var bolhas: Array[Vector3] = []
	var cor: Color = Color(0.58, 0.04, 0.06)
	var cor_borda: Color = Color(0.26, 0.02, 0.03)

	func _draw() -> void:
		for b in bolhas:
			draw_circle(Vector2(b.x, b.y), b.z + 1.2, cor_borda)
		for b in bolhas:
			draw_circle(Vector2(b.x, b.y), b.z, cor)
