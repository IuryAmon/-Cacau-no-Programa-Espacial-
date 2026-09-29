class_name RadioComunicacao
extends Node2D

# --- O RÁDIO DO DR. CHICO ---
#
# Por onde o Dr. Chico fala com a Cacau à distância. Pendure um na parede de
# qualquer fase, escolha a timeline e ele se vira sozinho:
#
#   1. CHAMANDO  a Cacau entrou na fase (a tela já clareou e ela já está com o
#                controle): um "bip-bip", e o rádio treme, o LED pisca e ondas
#                de sinal saem dele. Ela ainda pode se mexer.
#   2. NO AR     chiado de abrir o canal e a timeline do Dialogic começa, com o
#                retrato "cientistaradio" do mesmo lado das outras conversas
#                dele (direita). A Cacau para e se vira para o rádio, e a
#                câmera desliza e aproxima até o rádio ficar à esquerda do
#                retrato (senão o retrato o cobriria).
#                Enquanto o Dr. Chico FALA, o alto-falante trabalha: os quadros
#                1→3 rodam, ele pulsa, o LED acende e as ondas saem no ritmo da
#                voz. "Falar" dura o tempo da frase dita em voz alta (as letras
#                dela a LETRAS_POR_SEGUNDO), não só o da caixa escrevendo — o
#                Dialogic escreve a 100 letras por segundo, e uma frase curta
#                viraria uma piscada. Acabou a frase, ele volta ao quadro 1 e
#                fica escutando até o botão.
#   3. DESLIGA   a timeline acabou: chiado de fechar o canal, o rádio volta ao
#                quadro 1, a câmera volta ao normal e a Cacau volta a andar.
#
# É UMA VEZ SÓ (so_uma_vez): a transmissão fica anotada no EstadoMundo, então
# morrer ou sair e voltar para a fase não repete a conversa.
#
# COMO EDITAR NO EDITOR:
#   timeline         -> a conversa (timelines/*.dtl). O texto se edita lá.
#   falar_ao_entrar  -> desligado, o rádio só fala quando alguém chamar
#                       chamar() — uma área, um puzzle resolvido...
#   Sprite           -> a arte (3 quadros: 1 parado; 1→3 falando)
#   Luz              -> o brilho do LED na parede
#   SomChamada/SomChiado -> os sons; ajuste o volume_db por lá

## Emitido quando a transmissão termina (a timeline fechou).
signal transmissao_terminou

## Timeline do Dialogic que o rádio transmite.
@export var timeline: String = "radio_fase1"
## Personagem do Dialogic que fala pelo rádio: é a fala DELE que mexe o
## alto-falante (as respostas da Cacau não).
@export var personagem: String = "cientista"
## Chama sozinho quando a Cacau entra na fase.
@export var falar_ao_entrar: bool = true
## Respiro entre a Cacau ficar livre na fase e o rádio começar a chamar.
@export var espera_antes_de_chamar: float = 0.7
## Quanto tempo ele fica chamando antes de o canal abrir: um "bip-bip" só
## (o som tem 0,26 s) e um respiro curto antes do chiado. Passando do
## INTERVALO_BIPES, a chamada repete o bip-bip.
@export var duracao_da_chamada: float = 0.45
## Transmite uma vez só por jogo.
@export var so_uma_vez: bool = true
## No ar, a câmera desliza e aproxima para o rádio ficar à vista ao lado do
## retrato do Dr. Chico — o retrato entra pela direita e, sem isto, cobriria o
## rádio bem na hora em que ele fala.
@export var enquadrar_na_transmissao: bool = true
@export var zoom_na_transmissao: float = 2.2
## Onde o rádio fica na tela durante a fala, da esquerda (0) à direita (1).
## No meio (0,5) ele ainda fica livre: o retrato só começa lá pelos 60%.
@export_range(0.1, 0.9) var radio_na_tela: float = 0.5

## Quadros da folha (contados do 0): o 0 é o rádio parado; falando, roda do 0
## ao 2. O 2 é o que tem o LED vermelho aceso — é ele que pisca na chamada.
const QUADRO_PARADO := 0
const QUADRO_LED := 2
const QUADROS_FALANDO := 3
const FPS_FALANDO := 10.0
## Pisca-pisca do LED na chamada, e os trancos de tremer (liga/desliga).
const PISCA_CHAMADA := 0.12
const TREMOR_LIGADO := 0.3
const TREMOR_DESLIGADO := 0.2
## Segundos de bipe a bipe durante a chamada.
const INTERVALO_BIPES := 0.8
## Ritmo de fala corrida, para estimar quanto tempo a frase leva sendo dita.
const LETRAS_POR_SEGUNDO := 16.0
## Nenhuma fala é mais curta que isto — "Oi." também tem que se ver.
const FALA_MINIMA := 0.6

## As ondas de sinal: arcos dos dois lados do rádio que crescem e somem.
const ONDA_VIDA := 0.75
const ONDA_RAIO_INICIAL := 30.0
const ONDA_RAIO_FINAL := 78.0
const ONDA_ABERTURA := deg_to_rad(38.0)
const ONDA_ESPESSURA := 2.0
const ONDA_COR := Color(0.72, 0.95, 1.0)
const ONDA_INTERVALO_CHAMANDO := 0.4
const ONDA_INTERVALO_FALANDO := 0.22
## Do centro do sprite até o meio do corpo do rádio (a arte não é centrada
## no quadro de 32 px: o corpo ocupa x 4..26, y 7..23).
const CENTRO_DO_CORPO := Vector2(-2, -2)

enum Estado { PARADO, CHAMANDO, NO_AR }

@onready var _sprite: Sprite2D = $Sprite
@onready var _luz: PointLight2D = $Luz
@onready var _som_chamada: AudioStreamPlayer2D = $SomChamada
@onready var _som_chiado: AudioStreamPlayer2D = $SomChiado

var estado: Estado = Estado.PARADO
## O Dr. Chico está falando agora (a caixa escrevendo a fala dele, ou a voz
## estimada da frase ainda não acabou).
var falando: bool:
	get:
		return estado == Estado.NO_AR and (_escrevendo or _voz_restante > 0.0)

var _base_sprite := Vector2.ZERO
var _escala_sprite := Vector2.ONE
var _energia_luz := 1.0
var _relogio := 0.0          # tempo no estado atual
var _relogio_quadro := 0.0   # troca de quadro falando
var _escrevendo := false     # a caixa está escrevendo a fala dele
var _voz_restante := 0.0     # quanto ainda falta da frase "dita"
var _proxima_onda := 0.0
var _proximo_bipe := 0.0
var _pulso := 0.0            # 1 = acabou de bater, decai para 0
var _ondas: Array[float] = []  # idade de cada onda no ar
var _tinha_ondas := false


func _ready() -> void:
	_base_sprite = _sprite.position
	_escala_sprite = _sprite.scale
	_energia_luz = _luz.energy
	_mostrar_parado()
	if timeline == "" or not falar_ao_entrar:
		return
	if so_uma_vez and EstadoMundo.ja_feito(self):
		return
	_chamar_quando_ela_chegar()


## Começa a chamada agora (e depois abre o canal). Não faz nada se ele já
## estiver chamando ou no ar.
func chamar() -> void:
	if estado != Estado.PARADO:
		return
	estado = Estado.CHAMANDO
	_relogio = 0.0
	_proximo_bipe = 0.0
	_proxima_onda = 0.0
	await get_tree().create_timer(duracao_da_chamada).timeout
	if not is_inside_tree():
		return
	# Outra conversa abriu no meio da chamada: espera ela acabar.
	while Dialogic.current_timeline != null:
		await get_tree().process_frame
	_abrir_canal()


# --- A HORA DE CHAMAR ---
#
# A fase abre no escuro e clareia (FadeTela), e a chegada pode estar encenada
# (a cabine do elevador trazendo a Cacau, uma porta). O rádio só chama quando
# tudo isso passou: tela limpa, a Cacau com o controle e nenhum outro diálogo.

func _chamar_quando_ela_chegar() -> void:
	await get_tree().process_frame
	while not _hora_de_chamar():
		await get_tree().process_frame
	await get_tree().create_timer(espera_antes_de_chamar).timeout
	if is_inside_tree():
		chamar()


func _hora_de_chamar() -> bool:
	if Dialogic.current_timeline != null:
		return false
	if get_tree().root.find_child("FadeTela", true, false) != null:
		return false
	var cacau := _cacau()
	if cacau == null:
		return false
	if "pode_se_mover" in cacau and not cacau.pode_se_mover:
		return false
	if "animacao_controlada_externamente" in cacau and cacau.animacao_controlada_externamente:
		return false
	return true


# --- NO AR ---

func _abrir_canal() -> void:
	if not DialogicBridge.falar(timeline):
		estado = Estado.PARADO
		_mostrar_parado()
		return
	estado = Estado.NO_AR
	_relogio = 0.0
	_som_chiado.pitch_scale = 1.0
	_som_chiado.play()
	_olhar_para_o_radio()
	_enquadrar_camera()
	Dialogic.Text.text_started.connect(_ao_comecar_fala)
	Dialogic.Text.text_finished.connect(_ao_terminar_fala)
	Dialogic.timeline_ended.connect(_ao_fechar_canal, CONNECT_ONE_SHOT)


func _ao_comecar_fala(info: Dictionary) -> void:
	var quem = info.get("character")
	var e_ele: bool = quem is DialogicCharacter \
			and (quem as DialogicCharacter).get_identifier() == personagem
	# Fala de outro (a resposta da Cacau): o rádio escuta.
	_escrevendo = e_ele
	_voz_restante = 0.0
	if e_ele:
		_voz_restante = maxf(FALA_MINIMA, _letras(str(info.get("text", ""))) / LETRAS_POR_SEGUNDO)
		_relogio_quadro = 0.0
		_proxima_onda = 0.0
		_bater()


func _ao_terminar_fala(_info: Dictionary) -> void:
	_escrevendo = false


## Letras que se veem na fala (as tags [b], [font_size=14]... não se dizem).
static func _letras(texto: String) -> int:
	var sem_tags := RegEx.create_from_string("\\[[^\\]]*\\]").sub(texto, "", true)
	return sem_tags.strip_edges().length()


func _ao_fechar_canal() -> void:
	if Dialogic.Text.text_started.is_connected(_ao_comecar_fala):
		Dialogic.Text.text_started.disconnect(_ao_comecar_fala)
	if Dialogic.Text.text_finished.is_connected(_ao_terminar_fala):
		Dialogic.Text.text_finished.disconnect(_ao_terminar_fala)
	_escrevendo = false
	_voz_restante = 0.0
	estado = Estado.PARADO
	_mostrar_parado()
	# O "tchk" de fechar é o mesmo chiado, mais curto e mais grave.
	_som_chiado.pitch_scale = 0.8
	_som_chiado.play()
	var camera := _camera()
	if enquadrar_na_transmissao and camera:
		camera.restaurar()
	if so_uma_vez:
		EstadoMundo.marcar_feito(self)
	transmissao_terminou.emit()


## Leva a câmera até o rádio, deixando-o no ponto "radio_na_tela" da largura.
## Os limites da fase continuam valendo (ver CameraJogador.enquadrar).
func _enquadrar_camera() -> void:
	var camera := _camera()
	if not enquadrar_na_transmissao or camera == null:
		return
	var largura := camera.get_viewport_rect().size.x / zoom_na_transmissao
	var centro := global_position + Vector2(largura * (0.5 - radio_na_tela), 0.0)
	camera.enquadrar(centro, zoom_na_transmissao, 0.8)


func _camera() -> CameraJogador:
	var cacau := _cacau()
	return cacau.get_node_or_null("Camera2D") as CameraJogador if cacau else null


func _olhar_para_o_radio() -> void:
	var cacau := _cacau()
	var sprite_dela := cacau.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D if cacau else null
	if sprite_dela:
		sprite_dela.flip_h = global_position.x < cacau.global_position.x


# --- O QUE SE VÊ ---

func _process(delta: float) -> void:
	_relogio += delta
	_pulso = move_toward(_pulso, 0.0, delta * 7.0)
	_envelhecer_ondas(delta)

	match estado:
		Estado.CHAMANDO:
			_animar_chamada(delta)
		Estado.NO_AR:
			_animar_no_ar(delta)

	# O alto-falante "bate" a cada sílaba: incha um pouco e volta.
	var inchado := 1.0 + 0.07 * _pulso
	_sprite.scale = _escala_sprite * Vector2(inchado, inchado)
	# Redesenha enquanto houver onda (e uma vez depois, para apagar a última).
	if not _ondas.is_empty() or _tinha_ondas:
		queue_redraw()
	_tinha_ondas = not _ondas.is_empty()


func _animar_chamada(delta: float) -> void:
	# Pisca: quadro do LED aceso / apagado.
	var aceso := int(_relogio / PISCA_CHAMADA) % 2 == 0
	_sprite.frame = QUADRO_LED if aceso else QUADRO_PARADO
	_luz.enabled = aceso
	_luz.energy = _energia_luz

	# Treme em trancos, como aparelho vibrando em cima da mesa.
	var ciclo := fmod(_relogio, TREMOR_LIGADO + TREMOR_DESLIGADO)
	var tremendo := ciclo < TREMOR_LIGADO
	_sprite.position = _base_sprite + (Vector2(randi_range(-1, 1), 0) if tremendo else Vector2.ZERO)

	_proximo_bipe -= delta
	if _proximo_bipe <= 0.0:
		_proximo_bipe = INTERVALO_BIPES
		_som_chamada.play()
		_bater()

	_soltar_ondas(delta, ONDA_INTERVALO_CHAMANDO)


func _animar_no_ar(delta: float) -> void:
	_sprite.position = _base_sprite
	_voz_restante = maxf(_voz_restante - delta, 0.0)
	if not falando:
		_mostrar_parado()
		return

	_relogio_quadro += delta
	var quadro := int(_relogio_quadro * FPS_FALANDO) % QUADROS_FALANDO
	if quadro != _sprite.frame:
		_sprite.frame = quadro
		_bater()
	# O LED segue a voz, com uma tremida para não parecer lâmpada.
	_luz.enabled = true
	_luz.energy = _energia_luz * (0.55 + 0.45 * _pulso) * randf_range(0.85, 1.1)
	_soltar_ondas(delta, ONDA_INTERVALO_FALANDO)


func _mostrar_parado() -> void:
	_sprite.frame = QUADRO_PARADO
	_sprite.position = _base_sprite
	_luz.enabled = false


func _bater() -> void:
	_pulso = 1.0


func _soltar_ondas(delta: float, intervalo: float) -> void:
	_proxima_onda -= delta
	if _proxima_onda <= 0.0:
		_proxima_onda = intervalo
		_ondas.append(0.0)


func _envelhecer_ondas(delta: float) -> void:
	for i in range(_ondas.size() - 1, -1, -1):
		_ondas[i] += delta
		if _ondas[i] >= ONDA_VIDA:
			_ondas.remove_at(i)


## Quantas ondas estão no ar (para quem quiser saber se ele está transmitindo).
func ondas_no_ar() -> int:
	return _ondas.size()


func _draw() -> void:
	var centro := _sprite.position + CENTRO_DO_CORPO
	for idade in _ondas:
		var t := idade / ONDA_VIDA
		# Sai rápido e freia; some no fim do caminho.
		var raio := lerpf(ONDA_RAIO_INICIAL, ONDA_RAIO_FINAL, 1.0 - pow(1.0 - t, 2.0))
		var cor := ONDA_COR
		cor.a = pow(1.0 - t, 1.4) * 0.9
		# Sem antialias: fica com cara de pixel art, como o resto do jogo.
		draw_arc(centro, raio, -ONDA_ABERTURA, ONDA_ABERTURA, 12, cor, ONDA_ESPESSURA, false)
		draw_arc(centro, raio, PI - ONDA_ABERTURA, PI + ONDA_ABERTURA, 12, cor, ONDA_ESPESSURA, false)


func _cacau() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D
