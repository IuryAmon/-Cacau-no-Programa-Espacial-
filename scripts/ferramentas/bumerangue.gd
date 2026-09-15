class_name Bumerangue
extends Node2D

# --- BUMERANGUE DE FIBRA DE CARBONO ---
#
# Sai da mão na direção apontada, vai até o alcance, hesita e volta sozinho,
# ativando todo AlvoBumerangue que atravessar — na ida E na volta, que é o que
# torna possível o puzzle de "dois alvos num único arremesso".
#
# A IDA TROMBA, A VOLTA ATRAVESSA. Indo, ele bate em parede, chão, grade e
# barreira: a batida encerra a ida ali mesmo e ele já vira para casa, como se
# tivesse chegado ao fim do alcance. Voltando, ele passa por tudo — tem de
# passar, senão ficaria preso do outro lado da mesma parede que o parou.
#
# --- 1. O ARREMESSO HERDA O MOMENTO DA PERSONAGEM ---
#
# É a mesma física da granada de CS: quem arremessa correndo para a frente
# joga mais longe e mais rápido, quem arremessa correndo para TRÁS joga mais
# fraco. Só entra a componente da velocidade que está NO EIXO da mira
# (velocidade · direção): correr na horizontal não entorta um arremesso para
# cima, ele só não ganha nada com isso — e a ida continua sendo uma linha
# reta, que os alvos duplos das fases exigem.
#
# É daí que sai o que dá pra jogar na mecânica: parado ele alcança 320 px, em
# corrida ~400, saindo de um dash da mochila de N₂ passa dos 550. Alvo longe
# demais deixa de ser "impossível" e vira "corra antes de arremessar".
#
# --- 2. O VOO NÃO TEM VELOCIDADE CONSTANTE ---
#
# Sai rápido, perde força até o ponto mais distante, hesita um instante e
# volta acelerando — é essa curva que dá o peso de bumerangue; em velocidade
# fixa ele parece uma pedra que mudou de ideia. A perda é PARCIAL de
# propósito: quando chegava perto de parar no ápice o voo travava no ar, então
# a velocidade nunca cai abaixo do piso do ápice e a volta parte de lá.
#
# A VOLTA também é RETA: do ápice ele aponta direto para a mão e vem em linha,
# sem arco nenhum. Só entorta se a personagem se mexer — aí ele corrige a mira
# a cada frame, que é o que garante que a volta sempre chega.
#
# --- 3. CHAMAR DE VOLTA ---
#
# Apertar arremessar de novo com ele no ar não trava nada: ele vira na hora e
# volta correndo (chamar_de_volta()). O alcance deixa de ser um número fixo e
# vira decisão de quem joga — encurta o voo para pegar de novo mais rápido, ou
# deixa ir até o fim para varrer os alvos da sala.

## Impulso do arremesso com a personagem PARADA.
const VELOCIDADE_PARADA := 900.0
## Quanto da velocidade da personagem (no eixo da mira) entra no arremesso.
## Em 1.0 o arremesso saindo de um dash viraria um raio e passaria batido
## pelos alvos; em 0.0 correr não muda nada e a mecânica some. 0.55 é o meio
## em que a corrida se sente sem estragar a leitura do voo.
const HERANCA := 0.55
## Teto e piso do que a corrida pode emprestar (a queda livre bate em 1200 px/s
## e o dash em 1050 — sem trava, arremessar para baixo caindo seria absurdo).
const MOMENTO_MINIMO := -450.0
const MOMENTO_MAXIMO := 1100.0
const VELOCIDADE_MINIMA := 620.0
const VELOCIDADE_MAXIMA := 1500.0

## Alcance com a personagem parada — é a distância em que as salas já foram
## desenhadas, então ela é o piso da experiência, não a média.
const ALCANCE_PARADO := 320.0
const ALCANCE_POR_MOMENTO := 0.42
const ALCANCE_MINIMO := 200.0
const ALCANCE_MAXIMO := 620.0

## Sobra de velocidade no ponto mais distante (o arremesso forte chega lá
## ainda com corpo; o fraco chega arrastando).
const APICE_LENTO := 300.0
const APICE_RAPIDO := 430.0
## Respiro na virada. Curto de propósito: é leitura, não espera.
const PAUSA_CURTA := 0.035
const PAUSA_LONGA := 0.08

## A volta acelera até isto. Precisa passar da velocidade da personagem
## (350 px/s correndo) ou ele nunca alcançaria quem foge dele.
const VOLTA_BASE := 820.0
const VOLTA_FORTE := 1250.0
## Puxão extra por pixel de distância: quanto mais longe ele está, mais rápido
## vem. É o que garante que a volta SEMPRE chega, mesmo com a personagem
## correndo para o outro lado, sem precisar de velocidade absurda no caso comum.
const PUXAO_POR_DISTANCIA := 0.55
const VOLTA_TETO := 1900.0
const ACELERACAO_VOLTA := 2600.0

## Rotações por segundo do sprite, e o quanto esse giro acompanha a
## velocidade. A variação é pequena de propósito — o giro precisa continuar
## legível — mas ela existe porque é DELA que sai a cadência do zunido
## (ver som_bumerangue.gd): frear no ápice tem que se ouvir.
const GIRO_BASE := TAU * 4.2
const GIRO_VARIACAO := 0.32

## Camada física do cenário sólido (chão, paredes, grades, barreira). Os alvos
## são Area2D e ficam de fora de propósito: quem interrompe a ida é parede,
## não alvo — no alvo ele acerta e SEGUE, que é o que permite pegar dois num
## arremesso só.
const MASCARA_PAREDE := 1
## O quanto ele recua da parede ao bater, para a volta não começar grudada
## dentro dela.
const RECUO_BATIDA := 6.0

## Raio em que a personagem "pega" o bumerangue de volta.
const CAPTURA := 30.0
const TEMPO_MAXIMO := 5.0
## Chamar de volta antes disto é toque duplo sem querer, não intenção.
const TEMPO_MINIMO_CHAMADA := 0.1
## Altura da mão, em coordenadas do PLAYER — e a origem do player é o meio do
## corpo (a cápsula de colisão tem 72 de altura centrada nele), não o pé. Medir
## a partir do pé foi o que fazia o bumerangue sair do alto da cabeça: -34 daqui
## é a testa dela, não a mão.
##
## O número saiu da folha do arremesso (jogandoboomerang.png): o punho fica no
## pixel y≈67 do quadro de 96, e o AnimatedSprite2D do player está em y=-27 com
## escala 1.5 — ou seja, -27 + (67-48)*1.5 ≈ +2. Saída e retorno usam a mesma
## altura, então o bumerangue volta para a mesma mão que o soltou.
const ALTURA_MAO := Vector2(0, 2.0)
## Quanto ele já nasce à frente do punho, no eixo da mira: o punho está a ~14 px
## do centro do corpo, então 26 o coloca solto no ar em vez de dentro do peito.
const SAIDA_DA_MAO := 26.0

## Arte desenhada à mão (8x17 px); ESCALA aumenta o pixel art sem borrar
## porque o filtro de textura do projeto é nearest.
const TEXTURA := preload("res://assets/itens/Boomerangue.png")
const ESCALA := 2.4
const COR := Color(0.55, 0.85, 0.45)

## Quantas camadas ACIMA de quem arremessou o bumerangue voa.
##
## Ele nasce como filho da cena, não da personagem, então sem isto ficava no
## z_index 0 e sumia atrás de qualquer cenário desenhado mais à frente — as
## portas, por exemplo, que ficam no 1. Um objeto arremessado nunca passa por
## trás do cenário da sala: ele voa na frente de tudo, inclusive da própria
## personagem, que é como se lê um arremesso à altura do peito.
##
## A conta é feita em cima do z_index de quem arremessou (2, no player) em vez
## de um número fixo, para o bumerangue continuar acima dela mesmo se a camada
## da personagem mudar numa fase.
const Z_ACIMA_DO_DONO := 1

## Rastro: pontos guardados do caminho recente. É ele que deixa o voo legível
## quando o arremesso forte cruza a sala em meio segundo.
const RASTRO_PONTOS := 14
const RASTRO_LARGURA_MIN := 3.5
const RASTRO_LARGURA_MAX := 7.0

## Tremor de câmera e congelamento de impacto ao ativar um alvo.
const TREMOR_ACERTO := 3.0
const CONGELAMENTO_ACERTO := 0.035

enum Fase { IDA, APICE, VOLTA, ARREMATE }

## Quão forte foi este arremesso (0 = parado, 1 = no teto do momento). Quem
## arremessou lê isto para dosar o tremor de câmera e o coice.
var forca: float = 0.0

var _dono: Node2D = null
var _componente: Node = null
var _direcao: Vector2 = Vector2.RIGHT
var _fase: int = Fase.IDA

var _velocidade_saida: float = VELOCIDADE_PARADA
var _velocidade_apice: float = APICE_LENTO
var _velocidade: float = VELOCIDADE_PARADA
var _alcance: float = ALCANCE_PARADO
var _percorrido: float = 0.0
var _espera_apice: float = 0.0
var _tempo_vida: float = 0.0
var _giro_sinal: float = 1.0

var _visual: Sprite2D = null
var _rastro: Line2D = null
var _area: Area2D = null
var _som: SomBumerangue = null
var _tween_pancada: Tween = null


## `velocidade_do_dono` é o que faz o arremesso em corrida sair mais forte:
## quem chama passa player.velocity e a projeção no eixo da mira acontece
## aqui dentro.
static func lancar(dono: Node2D, componente: Node, direcao: Vector2,
		velocidade_do_dono: Vector2 = Vector2.ZERO) -> Bumerangue:
	var b := Bumerangue.new()
	b.name = "Bumerangue"
	b._dono = dono
	b._componente = componente
	b._direcao = direcao.normalized()
	b._preparar_arremesso(velocidade_do_dono)
	b.global_position = dono.global_position + ALTURA_MAO + b._direcao * SAIDA_DA_MAO
	b.z_index = dono.z_index + Z_ACIMA_DO_DONO
	dono.get_tree().current_scene.add_child(b)
	return b


## Toda a física do arremesso sai daqui: o momento herdado vira velocidade,
## alcance, sobra no ápice e tempo de hesitação.
func _preparar_arremesso(velocidade_do_dono: Vector2) -> void:
	var momento := clampf(velocidade_do_dono.dot(_direcao), MOMENTO_MINIMO, MOMENTO_MAXIMO)

	_velocidade_saida = clampf(VELOCIDADE_PARADA + momento * HERANCA,
		VELOCIDADE_MINIMA, VELOCIDADE_MAXIMA)
	_velocidade = _velocidade_saida
	_alcance = clampf(ALCANCE_PARADO + momento * ALCANCE_POR_MOMENTO,
		ALCANCE_MINIMO, ALCANCE_MAXIMO)

	forca = clampf(
		inverse_lerp(VELOCIDADE_PARADA, VELOCIDADE_MAXIMA, _velocidade_saida), 0.0, 1.0)
	_velocidade_apice = lerpf(APICE_LENTO, APICE_RAPIDO, forca)

	# Arremesso para a esquerda gira ao contrário: a mão que solta é a que
	# manda no sentido do giro.
	_giro_sinal = -1.0 if _direcao.x < 0.0 else 1.0


func _ready() -> void:
	_visual = Sprite2D.new()
	_visual.name = "Visual"
	_visual.texture = TEXTURA
	_visual.scale = Vector2(ESCALA, ESCALA)
	add_child(_visual)

	_rastro = Line2D.new()
	_rastro.name = "Rastro"
	# top_level: os pontos do rastro são posições do MUNDO, não do bumerangue —
	# se acompanhassem o nó, a fita voaria junto e não sobraria rastro nenhum.
	_rastro.top_level = true
	_rastro.width = lerpf(RASTRO_LARGURA_MIN, RASTRO_LARGURA_MAX, forca)
	# top_level desliga a herança do z também, então não adianta pedir "uma
	# camada abaixo do bumerangue" por z relativo: a conta é feita na mão a
	# partir do z que "lancar" já deixou pronto. A fita fica logo atrás da
	# lâmina, mas na frente do mesmo cenário que a lâmina cruza — senão ela
	# sumiria atrás da porta enquanto o bumerangue passa na frente.
	_rastro.z_as_relative = false
	_rastro.z_index = z_index - 1
	_rastro.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_rastro.end_cap_mode = Line2D.LINE_CAP_ROUND
	_rastro.joint_mode = Line2D.LINE_JOINT_ROUND
	# Ponto 0 é o mais VELHO: a fita nasce fina e transparente na cauda e
	# engorda até a lâmina.
	var afinamento := Curve.new()
	afinamento.add_point(Vector2(0.0, 0.05))
	afinamento.add_point(Vector2(1.0, 1.0))
	_rastro.width_curve = afinamento
	var desbote := Gradient.new()
	desbote.set_color(0, Color(COR.r, COR.g, COR.b, 0.0))
	desbote.set_color(1, Color(COR.r, COR.g, COR.b, 0.5))
	_rastro.gradient = desbote
	add_child(_rastro)

	_som = SomBumerangue.instalar(self)

	_area = Blockout.area_retangular(self, "AreaAcerto", Vector2(40, 40))
	_area.area_entered.connect(_on_area_entered)

	# Acento do arremesso: um woosh mais alto e um tom abaixo do voo, para o
	# impulso ter ataque próprio antes de o zunido do giro assumir.
	_som.soprar(forca * 0.6 + 0.4, 2.0, 0.82, 0.62)


func _physics_process(delta: float) -> void:
	_tempo_vida += delta
	if _tempo_vida > TEMPO_MAXIMO:
		_terminar()
		return

	match _fase:
		Fase.IDA:
			_avancar(delta)
		Fase.APICE:
			_pairar(delta)
		Fase.VOLTA:
			_retornar(delta)

	if _fase == Fase.ARREMATE:
		return  # foi apanhado neste mesmo frame

	_girar(delta)
	_marcar_rastro()


## Ida: perde força suavemente até a sobra do ápice, em linha reta — até o fim
## do alcance ou até bater em alguma coisa, o que vier primeiro.
func _avancar(delta: float) -> void:
	var t: float = clampf(_percorrido / _alcance, 0.0, 1.0)
	_velocidade = lerpf(_velocidade_saida, _velocidade_apice, smoothstep(0.0, 1.0, t))

	var passo := _velocidade * delta
	var destino: Vector2 = global_position + _direcao * passo

	# Parede no meio do passo deste frame: a ida morre no ponto da batida.
	var batida := _parede_ate(destino)
	if not batida.is_empty():
		var ponto: Vector2 = batida["position"]
		var normal: Vector2 = batida["normal"]
		global_position = ponto + normal * RECUO_BATIDA
		_virar(lerpf(PAUSA_CURTA, PAUSA_LONGA, forca))
		return

	global_position = destino
	_percorrido += passo

	if _percorrido >= _alcance:
		_virar(lerpf(PAUSA_CURTA, PAUSA_LONGA, forca))


## O que o trecho da ida atravessaria neste frame. Só a IDA pergunta isto: na
## volta o bumerangue passa por tudo (ver cabeçalho). Devolve o dicionário do
## intersect_ray, vazio quando o caminho está livre.
func _parede_ate(destino: Vector2) -> Dictionary:
	var espaco := get_world_2d().direct_space_state
	var consulta := PhysicsRayQueryParameters2D.create(global_position, destino, MASCARA_PAREDE)
	# Alvos são Area2D e não podem parar o voo; quem arremessou também não,
	# senão o próprio corpo da personagem devolveria o bumerangue na saída.
	consulta.collide_with_areas = false
	if _dono is CollisionObject2D:
		consulta.exclude = [(_dono as CollisionObject2D).get_rid()]
	return espaco.intersect_ray(consulta)


## Hesitação no ponto mais distante: ele fica girando no lugar por uns poucos
## frames. É o respiro que faz a volta parecer decisão, e não ricochete.
func _pairar(delta: float) -> void:
	if not is_instance_valid(_dono):
		_terminar()
		return
	_velocidade = _velocidade_apice
	_espera_apice -= delta
	if _espera_apice <= 0.0:
		_fase = Fase.VOLTA


## Volta: retoma do ápice e acelera em LINHA RETA para a mão da personagem —
## que pode ter se mexido, então a mira é refeita a cada frame.
func _retornar(delta: float) -> void:
	if not is_instance_valid(_dono):
		_terminar()
		return

	var ate_mao: Vector2 = _mao() - global_position
	var distancia := ate_mao.length()

	# Quanto mais longe, mais rápido ele vem: é o que garante que a volta
	# alcança até quem está fugindo dela.
	var teto := minf(
		lerpf(VOLTA_BASE, VOLTA_FORTE, forca) + distancia * PUXAO_POR_DISTANCIA,
		VOLTA_TETO)
	_velocidade = move_toward(_velocidade, teto, ACELERACAO_VOLTA * delta)
	var passo := _velocidade * delta

	# Pega quando chega perto OU quando o passo deste frame passaria direto —
	# sem isso ele orbita a personagem na velocidade alta do fim da volta.
	if distancia <= maxf(CAPTURA, passo):
		_terminar()
		return

	global_position += ate_mao / distancia * passo


## Vira o voo para casa. Serve tanto para o fim do alcance quanto para o
## chamado de volta no meio do caminho.
func _virar(pausa: float) -> void:
	if not is_instance_valid(_dono):
		_terminar()
		return
	_fase = Fase.APICE
	_espera_apice = pausa
	# A volta continua da velocidade em que a ida terminou: recomeçar do zero
	# fazia o bumerangue parecer que morria no ar e era rebocado.
	_velocidade = maxf(_velocidade, _velocidade_apice)


## Apertar arremessar de novo com ele no ar: vira na hora, sem esperar o
## alcance. Devolve false se ainda é cedo demais (toque duplo sem querer).
func chamar_de_volta() -> bool:
	if _fase != Fase.IDA or _tempo_vida < TEMPO_MINIMO_CHAMADA:
		return false
	_virar(PAUSA_CURTA)
	if _fase != Fase.APICE:
		return false  # o dono sumiu no meio da virada: o voo já se encerrou
	# O chamado tem voz própria: um sopro curto e agudo marca a virada.
	_som.soprar(0.9, 1.0, 1.18, 0.30)
	return true


func _girar(delta: float) -> void:
	var intensidade := _intensidade()
	var giro := _giro_sinal * GIRO_BASE \
		* lerpf(1.0 - GIRO_VARIACAO, 1.0 + GIRO_VARIACAO, intensidade) * delta
	_visual.rotation += giro
	# O zunido é a MESMA rotação, ouvida: uma pá passando = um woosh.
	_som.girar(giro, intensidade, delta)


## Velocidade normalizada (0 = rastejando no ápice, 1 = arremesso no teto).
## Manda no tom, no volume e na cadência do zunido, e na variação do giro.
func _intensidade() -> float:
	return clampf(inverse_lerp(APICE_LENTO, VELOCIDADE_MAXIMA, _velocidade), 0.0, 1.0)


func _mao() -> Vector2:
	return _dono.global_position + ALTURA_MAO


func _marcar_rastro() -> void:
	# Parado no ápice ele empilharia pontos em cima do mesmo lugar — nada a
	# desenhar e um segmento degenerado a cada frame. A fita fica onde está.
	var ultimo := _rastro.get_point_count() - 1
	if ultimo >= 0 and _rastro.get_point_position(ultimo).distance_squared_to(global_position) < 1.0:
		return
	_rastro.add_point(global_position)
	while _rastro.get_point_count() > RASTRO_PONTOS:
		_rastro.remove_point(0)


func _on_area_entered(area: Area2D) -> void:
	if not (area.is_in_group("alvo_bumerangue") and area.has_method("atingir_bumerangue")):
		return
	area.atingir_bumerangue()
	_impacto()


## Peso do acerto: o mundo trava por dois frames, a câmera treme e a lâmina dá
## um estufão. São três coisas baratas que juntas fazem o alvo parecer BATIDO,
## em vez de apenas detectado.
func _impacto() -> void:
	if is_instance_valid(_componente) and _componente.has_method("congelar_impacto"):
		_componente.congelar_impacto(CONGELAMENTO_ACERTO)

	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("disparar_tremor"):
		camera.disparar_tremor(TREMOR_ACERTO)

	if _tween_pancada and _tween_pancada.is_valid():
		_tween_pancada.kill()
	_visual.scale = Vector2(ESCALA, ESCALA) * 1.4
	_tween_pancada = create_tween()
	_tween_pancada.tween_property(_visual, "scale", Vector2(ESCALA, ESCALA), 0.22) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _terminar() -> void:
	if _fase == Fase.ARREMATE:
		return
	_fase = Fase.ARREMATE
	set_physics_process(false)

	# A mão fica livre na hora — quem arremessou já pode arremessar de novo,
	# mesmo com o nó ainda vivo escoando som e rastro.
	if is_instance_valid(_componente) and _componente.has_method("bumerangue_voltou"):
		_componente.bumerangue_voltou()

	# Arremate: o woosh mais grave da série, o som de fechar a mão em cima dele.
	_som.soprar(0.55, 1.0, 0.74, 0.45)

	_visual.visible = false
	_area.set_deferred("monitoring", false)

	# O nó ainda vive o tempo do zunido escoar: matá-lo agora daria um corte
	# seco no áudio bem no frame mais audível do voo.
	var cauda := maxf(_som.tempo_de_cauda(), 0.18)
	var saida := create_tween()
	saida.tween_property(_rastro, "modulate:a", 0.0, minf(cauda, 0.25))
	saida.tween_interval(maxf(cauda - 0.25, 0.0))
	saida.tween_callback(queue_free)
