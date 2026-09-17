class_name Lanterna
extends Node2D

# --- LANTERNA DE FOCO (componente anexado ao Player) ---
#
# A ferramenta do blecaute profundo: um FEIXE dirigido, não um brilho em volta
# como o sinalizador. A referência de comportamento é o Boo do Mario — a
# Sentinela (sentinela.gd) só anda quando NÃO está dentro deste cone.
#
# MIRA: dois modos, alternados pela jogadora — nunca os dois ao mesmo tempo.
#   PRESA (padrão)  -> aponta para o lado que a personagem está olhando, o
#                      mesmo flip_h que o dash e o bumerangue usam (ver
#                      _facing() em ferramentas_player.gd). Vira sozinha.
#   LIVRE           -> mouse (ou o analógico direito, se empurrado) — mira em
#                      qualquer ângulo, inclusive parada ou andando para trás.
# L / clique do analógico esquerdo alterna entre os dois (ação "alternar_mira").
# Presa é o padrão porque é a leitura mais simples e mais coerente com o resto
# do jogo (nenhuma outra ferramenta usa mouse); livre existe para quem quiser
# precisão — mirar para cima, ficar parado mirando ao lado, etc.
#
# Segue o padrão das ferramentas: cena própria anexada ao player, ativada pela
# flag "lanterna" do Progresso. A FaseBase instala em toda fase
# (Lanterna.instalar(player)); sem a flag o componente fica inerte.
#
#   R / botão direito -> liga/desliga (ação "lanterna")
#
# ECONOMIA DA BATERIA: acesa drena (drain_rate), apagada recupera sozinha
# (regen_rate) — não existem estações de recarga. Ao esgotar, a lanterna se
# DESLIGA e religar é decisão manual: sem piscar sozinha no primeiro ponto
# recuperado. É esse ciclo aceso/apagado que faz o feixe ser recurso.
#
# INVARIÁVEL CENTRAL: o visual do feixe e a detecção usam OS MESMOS alcance e
# abertura. A textura do cone é gerada por código a partir desses números e o
# DetectorConeLuz recebe exatamente os mesmos — nunca ajuste um sem o outro,
# nunca troque a textura por um PNG "parecido".

signal bateria_esgotada

const CENA := "res://scenes/ferramentas/lanterna.tscn"
const HABILIDADE := "lanterna"
## Lado da textura procedural do feixe; o raio útil é a metade (128 px) e o
## texture_scale estica esse raio até "alcance" px de mundo.
const LADO_TEXTURA := 256
## Altura do peito da personagem — mesma da luz do sinalizador (ver
## ferramentas_player.gd), para as duas luzes nascerem do mesmo ponto.
const ALTURA_PEITO := Vector2(0, -30)

# --- AJUSTE FINO NO PLAYTEST ---
# Alcance e abertura definem o dilema da fase: cone curto/estreito congela
# menos Sentinelas por vez e aperta a escolha de quem parar.
@export var alcance: float = 320.0
@export var abertura_graus: float = 45.0
@export var intensidade: float = 1.35
@export var cor: Color = Color(1.0, 0.93, 0.76)
## true: mira livre (mouse / analógico direito). false (padrão): presa ao
## lado para onde o sprite olha. A jogadora alterna com L em tempo real —
## isto aqui é só o valor inicial ao entrar na fase.
@export var mira_livre: bool = false

# --- BATERIA (0–100; sem UI ainda, só a variável e o sinal) ---
@export_range(0.0, 100.0) var bateria: float = 100.0
## Pontos de bateria por segundo com o feixe aceso (2.0 => ~50 s de luz).
## AJUSTE NO PLAYTEST: drain e regen juntos definem o ritmo aceso/apagado —
## é este par que transforma a lanterna em recurso.
@export var drain_rate: float = 2.0
## Pontos por segundo recuperados com o feixe APAGADO (4.0 => ~25 s do zero
## ao cheio). Não há estação de recarga: o descanso do feixe é a recarga.
@export var regen_rate: float = 4.0

## Toggle da jogadora (tecla T). O feixe acende DE VERDADE só com bateria.
## Começa DESLIGADA: a lanterna é instalada de novo (Lanterna.instalar) toda
## vez que uma fase carrega, então "true" aqui faria o feixe acender sozinho
## ao entrar em qualquer fase — inclusive fora do blecaute — assim que a
## habilidade já estivesse conquistada. Ligar é sempre gesto da jogadora (R).
var ligada: bool = false

var _luz: PointLight2D = null
var _detector: DetectorConeLuz = null
var _player: CharacterBody2D = null
var _sprite: AnimatedSprite2D = null
var _mira: Vector2 = Vector2.RIGHT
var _abertura_da_textura: float = -1.0
var _avisou_esgotada: bool = false
## Ação do liga/desliga: "lanterna" (R / botão direito). Cai no "luz" (T) só
## se a ação não existir no input map — cópias antigas do projeto.
var _acao_toggle: String = "lanterna"
## Ação do alterna-mira: "alternar_mira" (L / clique do analógico esquerdo).
## Sem fallback — cópias antigas do projeto simplesmente não ganham o botão
## (o InputMap.has_action abaixo protege contra isso).
const _ACAO_ALTERNAR_MIRA := "alternar_mira"


static func instalar(no_player: Node) -> Lanterna:
	var existente := no_player.get_node_or_null("Lanterna")
	if existente:
		return existente as Lanterna
	var lanterna: Lanterna = load(CENA).instantiate()
	lanterna.name = "Lanterna"
	lanterna.position = ALTURA_PEITO
	Blockout.adicionar(no_player, lanterna)
	return lanterna


func _ready() -> void:
	# É por este grupo que as Sentinelas (e futuros interruptores
	# fotossensíveis) descobrem as fontes de luz — sem referência direta.
	add_to_group("fonte_de_luz")

	if not InputMap.has_action(_acao_toggle):
		_acao_toggle = "luz"

	_player = get_parent() as CharacterBody2D
	if _player:
		_sprite = _player.get_node_or_null("AnimatedSprite2D")

	_luz = PointLight2D.new()
	_luz.name = "Feixe"
	# Sombras ligadas: é o LightOccluder2D das paredes que corta o feixe no
	# visual, do mesmo jeito que o raycast corta na detecção.
	_luz.shadow_enabled = true
	add_child(_luz)

	_detector = DetectorConeLuz.new()
	_detector.name = "Detector"
	add_child(_detector)
	if _player:
		_detector.excluir = [_player.get_rid()]

	_sincronizar()


func _physics_process(delta: float) -> void:
	var tem := Progresso.tem_habilidade(HABILIDADE)

	if tem and not Interacao.ocupada():
		# livre_para: o botão apertado para fechar uma tela não liga a lanterna.
		if Input.is_action_just_pressed(_acao_toggle) and Interacao.livre_para(_acao_toggle):
			ligada = not ligada
		if InputMap.has_action(_ACAO_ALTERNAR_MIRA) and Input.is_action_just_pressed(_ACAO_ALTERNAR_MIRA) \
				and Interacao.livre_para(_ACAO_ALTERNAR_MIRA):
			mira_livre = not mira_livre

	if acesa():
		bateria = maxf(bateria - drain_rate * delta, 0.0)
		if bateria <= 0.0:
			# Apagou de vez: religar é decisão manual (R) — sem piscar
			# sozinha assim que a recarga pingar o primeiro ponto.
			ligada = false
			if not _avisou_esgotada:
				_avisou_esgotada = true
				bateria_esgotada.emit()
	elif tem and bateria < 100.0:
		bateria = minf(bateria + regen_rate * delta, 100.0)
		if bateria > 0.0:
			_avisou_esgotada = false

	_atualizar_mira()
	_sincronizar()


# --- API PÚBLICA (mesmo contrato do DetectorConeLuz) ---

## O feixe está de fato aceso? (flag do Progresso + toggle + bateria)
func acesa() -> bool:
	return Progresso.tem_habilidade(HABILIDADE) and ligada and bateria > 0.0


func is_point_lit(ponto_global: Vector2) -> bool:
	return acesa() and _detector != null and _detector.is_point_lit(ponto_global)


func is_body_lit(corpo: Node2D) -> bool:
	return acesa() and _detector != null and _detector.is_body_lit(corpo)


## Direção atual da mira (para depuração e para quem quiser desenhar em cima).
func direcao_atual() -> Vector2:
	return _mira


## Recarga instantânea — a passiva (regen_rate) é o caminho normal; esta API
## fica para eventos pontuais (checkpoint, item raro) e para os testes.
func recarregar(quanto: float = 100.0) -> void:
	bateria = clampf(bateria + quanto, 0.0, 100.0)
	if bateria > 0.0:
		_avisou_esgotada = false


# --- MIRA ---

func _atualizar_mira() -> void:
	var dir := _mira
	if mira_livre:
		# Analógico direito empurrado vence; senão vale o mouse. Sem os dois,
		# mantém a última direção válida em vez de saltar para a origem.
		# Do controle que está em uso — não necessariamente o de número 0.
		var stick := Vector2(
			Input.get_joy_axis(Controle.dispositivo, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(Controle.dispositivo, JOY_AXIS_RIGHT_Y))
		if stick.length() > 0.4:
			dir = stick.normalized()
		elif not Controle.em_uso:
			# De controle na mão o mouse está escondido e parado num canto
			# qualquer: soltar o analógico mantém a última mira, e não pula
			# para o lado dele.
			var ate_mouse := get_global_mouse_position() - global_position
			if ate_mouse.length_squared() > 1.0:
				dir = ate_mouse.normalized()
	else:
		# Presa: o lado para onde a personagem está olhando — mesma leitura
		# de flip_h que o dash e o bumerangue usam.
		dir = Vector2.LEFT if (_sprite and _sprite.flip_h) else Vector2.RIGHT

	_mira = dir
	# O nó gira inteiro: a textura do feixe (filha) acompanha e o detector
	# recebe o mesmo vetor — visual e lógica nunca divergem.
	rotation = dir.angle()
	_detector.direcao = dir


# --- SINCRONIA VISUAL <-> DETECÇÃO ---

func _sincronizar() -> void:
	if _luz == null:
		return
	var lig := acesa()
	_luz.enabled = lig
	_detector.ativo = lig
	visible = Progresso.tem_habilidade(HABILIDADE)

	if _abertura_da_textura != abertura_graus:
		_abertura_da_textura = abertura_graus
		_luz.texture = _textura_cone()

	_luz.texture_scale = maxf(alcance, 1.0) / (LADO_TEXTURA * 0.5)
	_luz.energy = intensidade
	_luz.color = cor
	_detector.alcance = alcance
	_detector.abertura_graus = abertura_graus


## Textura do feixe gerada por código a partir da MESMA abertura da detecção:
## ápice no centro da imagem (o nó é o ápice), cone apontando para +X.
## A borda angular amacia PARA DENTRO e o brilho morre EXATAMENTE no raio —
## a luz nunca vaza além do que o detector considera iluminado.
func _textura_cone() -> ImageTexture:
	var raio := LADO_TEXTURA * 0.5
	var meia := deg_to_rad(clampf(abertura_graus, 2.0, 180.0)) * 0.5
	var img := Image.create(LADO_TEXTURA, LADO_TEXTURA, false, Image.FORMAT_RGBA8)
	for y in LADO_TEXTURA:
		for x in LADO_TEXTURA:
			var d := Vector2(x + 0.5 - raio, y + 0.5 - raio)
			var dist := d.length()
			if dist > raio:
				continue
			var alfa: float
			if dist < 3.0:
				alfa = 1.0  # o "bulbo" no ápice
			else:
				var ang := absf(atan2(d.y, d.x))
				if ang > meia:
					continue
				# Corpo do feixe: forte perto do ápice, zero no alcance.
				# O expoente muda o "corpo" da luz — AJUSTE NO PLAYTEST.
				var radial := pow(1.0 - dist / raio, 0.55)
				var angular := 1.0 - smoothstep(meia * 0.78, meia, ang)
				alfa = radial * angular
			img.set_pixel(x, y, Color(1, 1, 1, alfa))
	return ImageTexture.create_from_image(img)
