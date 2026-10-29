extends Area2D

# --- A CENA DO MIRANTE ---
#
# A Cacau pisa na plataforma do mirante e vê o foguete pela primeira vez. A
# parte dela — o susto, a fala, o balão de coração — é do player.gd
# (reagir_ao_avistar_foguete). Aqui fica quem DIRIGE a cena e o que vem depois
# da fala: o pôr do sol.
#
#   fala termina ──> o coração sobe e fica batendo até a fala do anoitecer
#                    o sol desce atrás da serra: o céu vai do dourado ao
#                    crepúsculo, o fundo e o mundo escurecem um pouco com ele,
#                    os postes dão a piscada e firmam         (Atmosfera.por_do_sol)
#                    com o sol posto, ela fala: "Está anoitecendo, amei essa
#                    paisagem mas preciso ir..."     (timelines/cacau_anoitecendo.dtl)
#                    o controle volta
#
# A Cacau fica parada do começo ao fim, e o HUD some junto: é para olhar.
#
# NÃO fica de noite aqui: a fase só escurece de leve e continua no crepúsculo
# (EstadoMundo.sol_se_pos — é assim que o world1 abre quando ela volta, e a
# cena não repete, nem se ela morrer antes de chegar ao laboratório). A noite
# cai depois, no pátio, com a fornalha queimando o carvão (ver retorta.gd).
#
# Numa cena sem Atmosfera (ou em que o sol já se pôs) nada disso acontece: a
# fala e o coração tocam como antes e o controle volta na hora.
#
# A MÚSICA da cena também é daqui:
#
#   balão de exclamação ──> toca o piano G e a trilha some (TrilhaSonora.pausar)
#   o piano termina     ──> um respiro em silêncio, e entra "vendo foguete2",
#                           em loop, até a cena acabar
#   controle volta      ──> "vendo foguete2" some e a trilha volta
#                           (TrilhaSonora.continuar): com o sol posto, já é a
#                           música do crepúsculo; sem pôr do sol, a mesma de
#                           antes, de onde tinha parado
#
# Sem pôr do sol, a cena acaba quando o coração some.

## Segundos entre o coração aparecer e o sol começar a descer.
@export var respiro_antes_do_sol := 0.8
## Segundos olhando o crepúsculo, com o sol já posto, antes de ela falar.
@export var respiro_depois_do_sol := 1.2

@export_group("Música")
## A nota de piano que toca junto com o balão de exclamação.
@export var som_do_susto: AudioStream = preload("res://sounds/Trilhas/piano G.mp3")
@export var volume_do_susto_db := -8.0
## A música da cena, no lugar da trilha (toca em loop).
@export var musica_do_foguete: AudioStream = preload("res://sounds/Trilhas/vendo foguete2.mp3")
@export var volume_da_musica_db := -6.0
## Segundos em silêncio entre o piano acabar e a música da cena entrar.
@export var espera_antes_da_musica := 1.0
## Segundos para a trilha sumir quando o balão aparece.
@export var fade_da_trilha := 0.2
## Segundos para "vendo foguete2" sumir e para a trilha voltar.
@export var fade_de_volta := 1.5

## A fala dela depois que o sol se põe.
const TIMELINE_ANOITECENDO := "cacau_anoitecendo"
## Volume de "sem som" para os fades.
const MUDO_DB := -60.0

var _disparado: bool = false
var _susto: AudioStreamPlayer
var _musica: AudioStreamPlayer
var _cena_acabou: bool = false

func _ready() -> void:
	# Ela já viu o foguete (nesta volta ao world1 ou antes de morrer): a cena
	# de avistar não repete.
	_disparado = EstadoMundo.revelou_dr_chico or EstadoMundo.viu_o_foguete
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _disparado:
		return
	if body.name != "Player":
		return
	_disparado = true
	if not body.has_method("reagir_ao_avistar_foguete"):
		return
	# O tocador do piano já fica pronto aqui, para a nota sair no mesmo quadro
	# do balão.
	if som_do_susto:
		_susto = _novo_tocador(som_do_susto, volume_do_susto_db)

	body.avistou_o_foguete.connect(_trocar_a_musica, CONNECT_ONE_SHOT)
	var atmosfera := Atmosfera.da_cena(self)
	if atmosfera != null and atmosfera.pode_por_o_sol():
		body.segurar_apos_o_foguete = true
		body.segurar_coracao_do_foguete = true
		body.fala_do_foguete_terminou.connect(_por_o_sol.bind(body, atmosfera), CONNECT_ONE_SHOT)
	else:
		body.fala_do_foguete_terminou.connect(_registrar, CONNECT_ONE_SHOT)
		body.cena_do_foguete_terminou.connect(_voltar_a_musica, CONNECT_ONE_SHOT)
	body.reagir_ao_avistar_foguete($CollisionShape2D)


func _registrar() -> void:
	EstadoMundo.viu_o_foguete = true


## O pôr do sol, da descida ao controle de volta.
func _por_o_sol(player: Node2D, atmosfera: Atmosfera) -> void:
	_registrar()
	var cena := get_tree().current_scene
	# Sem apagar a tela: a cortina está aqui só para tirar o HUD de cena.
	var cortina := FadeTela.criar(cena)

	# O coração ainda está no ar quando o sol começa a descer.
	await _esperar(respiro_antes_do_sol)
	cortina.esconder_huds(cena)

	await atmosfera.por_do_sol()
	await _esperar(respiro_depois_do_sol)

	if is_instance_valid(player):
		await player.soltar_coracao_do_foguete()
	Dialogic.start(TIMELINE_ANOITECENDO)
	await Dialogic.timeline_ended

	cortina.restaurar_huds()
	cortina.queue_free()
	if is_instance_valid(player):
		player.segurar_apos_o_foguete = false
		player.pode_se_mover = true
	_voltar_a_musica()


## O balão pulou: o piano G toca, a trilha some e, um respiro depois de o
## piano terminar, entra "vendo foguete2".
func _trocar_a_musica() -> void:
	TrilhaSonora.pausar(fade_da_trilha)

	if _susto:
		_susto.play()
		await _susto.finished
		_susto.queue_free()
	await _esperar(espera_antes_da_musica)
	if _cena_acabou or musica_do_foguete == null:
		return

	# Uma cópia em loop: a cena pode durar mais que a música.
	var musica := musica_do_foguete.duplicate()
	if "loop" in musica:
		musica.loop = true
	_musica = _novo_tocador(musica, volume_da_musica_db)
	_musica.play()


## A cena acabou: "vendo foguete2" some e a trilha volta (a do crepúsculo, se
## o sol se pôs).
func _voltar_a_musica() -> void:
	_cena_acabou = true
	if _musica:
		var musica := _musica
		_musica = null
		var some := create_tween()
		some.tween_property(musica, "volume_db", MUDO_DB, fade_de_volta)
		some.tween_callback(musica.queue_free)
	TrilhaSonora.continuar(fade_de_volta)


## "Vendo foguete2" está tocando no lugar da trilha.
func tocando_a_musica_do_foguete() -> bool:
	return _musica != null and _musica.playing


func _novo_tocador(som: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var tocador := AudioStreamPlayer.new()
	tocador.stream = som
	tocador.volume_db = volume_db
	add_child(tocador)
	return tocador


## Espera em tempo de JOGO (o mesmo relógio dos tweens da cena).
func _esperar(segundos: float) -> void:
	var resta := segundos
	while resta > 0.0:
		await get_tree().process_frame
		resta -= get_process_delta_time()
