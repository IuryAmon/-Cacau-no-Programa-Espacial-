extends Node

# --- A TRILHA SONORA ---
#
# A música do jogo toca aqui, neste autoload, e não dentro da cena: assim ela
# atravessa a troca de cena sem recomeçar. Da rua da torre para o telhado, ou
# morrendo e voltando no checkpoint, a música segue de onde estava; ela só
# muda quando a cena nova pede OUTRA.
#
# QUEM ESCOLHE é a cena que abriu, nesta ordem:
#
#   1. a raiz da cena tem "musica" preenchida   toca ela. Toda fase (FaseBase)
#                                               tem, no grupo Música do
#                                               Inspector da raiz; a introdução
#                                               também
#   2. a cena tem céu aberto: uma Atmosfera     a música da HORA, a mesma em
#      que não é de interior                    todo lugar ao ar livre: tarde
#                                               com sol, sol posto, noite (grupo
#                                               Música da Atmosfera)
#   3. nenhum dos dois                          silêncio
#
# A HORA MUDOU com a cena aberta (o pôr do sol no mirante, a noite caindo no
# pátio, a tecla Ç): a música troca junto, devagar (FADE_DA_HORA).
#
# UMA CENA COM MÚSICA PRÓPRIA por cima da trilha (a do mirante, com o piano e
# "vendo foguete") chama pausar() quando começa e continuar() quando acaba. Se
# a hora mudou nesse meio-tempo, o continuar() já entra com a música da hora
# nova.
#
# Toda música toca em loop e continua tocando com o jogo pausado (caderno,
# mochila, puzzles).

## O volume de uma música quando ninguém diz outro.
const VOLUME_PADRAO_DB := -6.0
## Segundos de uma troca de música: a que sai some enquanto a nova cresce.
const FADE_PADRAO := 1.0
## A troca quando a hora muda com a cena aberta.
const FADE_DA_HORA := 3.0
## Volume de "sem som" para os fades.
const MUDO_DB := -60.0

## A música pedida agora (null = silêncio).
var _musica: AudioStream
var _volume_db := VOLUME_PADRAO_DB
## Quem está tocando (null no silêncio) e o quê: enquanto a trilha espera
## pausada, a música pedida pode já ser outra.
var _tocador: AudioStreamPlayer
var _musica_do_tocador: AudioStream
var _pausada := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().scene_changed.connect(_ao_trocar_de_cena)
	# A primeira cena (o menu, ou a que o editor abriu) não passa pelo
	# scene_changed: um quadro depois ela já está pronta.
	_ao_trocar_de_cena.call_deferred()


# ───────────────────────────────────────────────────────────── uso

## Toca [param musica] no lugar da que está tocando: a que sai some enquanto a
## nova cresce, em [param fade] segundos. Se for a mesma, ela só segue (no
## volume novo). Null é silêncio.
func tocar(musica: AudioStream, volume_db: float = VOLUME_PADRAO_DB, fade: float = FADE_PADRAO) -> void:
	_musica = musica
	_volume_db = volume_db
	if not _pausada:
		_atualizar(fade)


## A música some em [param fade] segundos e fica o silêncio.
func parar(fade: float = FADE_PADRAO) -> void:
	tocar(null, _volume_db, fade)


## A trilha some em [param fade] segundos e espera, pausada, onde parou: uma
## cena vai tocar a música dela por cima. Até o [method continuar], quem pedir
## outra música (a hora que mudou) só é atendido lá.
func pausar(fade: float = 0.2) -> void:
	if _pausada:
		return
	_pausada = true
	if _tocador != null:
		var tocador := _tocador
		_levar(tocador, MUDO_DB, fade).tween_callback(func() -> void: tocador.stream_paused = true)


## A trilha volta, crescendo em [param fade] segundos: de onde tinha parado,
## ou já com a música nova, se a cena pediu outra enquanto ela esperava.
func continuar(fade: float = FADE_PADRAO) -> void:
	if not _pausada:
		return
	_pausada = false
	_atualizar(fade)


## A música que a trilha está tocando (ou esperando, pausada), ou null.
func musica_atual() -> AudioStream:
	return _musica_do_tocador


func esta_pausada() -> bool:
	return _pausada


# ───────────────────────────────────────────────────────────── a cena

func _ao_trocar_de_cena() -> void:
	# Quem tinha pausado a trilha era da cena que saiu.
	_pausada = false
	var atmosfera := Atmosfera.da_cena(get_tree().current_scene)
	if atmosfera != null and not atmosfera.momento_mudou.is_connected(_ao_mudar_a_hora):
		atmosfera.momento_mudou.connect(_ao_mudar_a_hora)
	_seguir_a_cena(FADE_PADRAO)


func _ao_mudar_a_hora(_momento: Atmosfera.Momento) -> void:
	_seguir_a_cena(FADE_DA_HORA)


func _seguir_a_cena(fade: float) -> void:
	var pedido := _pedido_da_cena()
	tocar(pedido[0], pedido[1], fade)


## O que a cena aberta pede (ver o topo): [música, volume]. Música null é
## silêncio.
func _pedido_da_cena() -> Array:
	var cena := get_tree().current_scene
	if cena == null:
		return [null, VOLUME_PADRAO_DB]
	var musica = cena.get(&"musica")
	if musica is AudioStream:
		var volume = cena.get(&"volume_da_musica_db")
		return [musica, float(volume) if volume != null else VOLUME_PADRAO_DB]
	var atmosfera := Atmosfera.da_cena(cena)
	if atmosfera != null and not atmosfera.e_interior():
		return [atmosfera.musica_da_hora(), atmosfera.volume_da_musica_db]
	return [null, VOLUME_PADRAO_DB]


# ───────────────────────────────────────────────────────────── os tocadores

## Põe a música pedida para tocar (ou o silêncio, se ela for null).
func _atualizar(fade: float) -> void:
	if _tocador != null and _musica_do_tocador == _musica:
		# A mesma: segue de onde está.
		_tocador.stream_paused = false
		_levar(_tocador, _volume_db, fade)
		return
	_soltar(fade)
	if _musica == null:
		return
	# Uma cópia em loop: o arquivo importado pode não estar.
	var musica := _musica.duplicate()
	if "loop" in musica:
		musica.loop = true
	_tocador = AudioStreamPlayer.new()
	_tocador.stream = musica
	_tocador.volume_db = MUDO_DB
	add_child(_tocador)
	_tocador.play()
	_musica_do_tocador = _musica
	_levar(_tocador, _volume_db, fade)


## O tocador da vez sai: some em [param fade] segundos e é apagado.
func _soltar(fade: float) -> void:
	if _tocador == null:
		return
	var velho := _tocador
	_tocador = null
	_musica_do_tocador = null
	if velho.stream_paused:
		velho.queue_free()
		return
	_levar(velho, MUDO_DB, fade).tween_callback(velho.queue_free)


## Leva o volume de [param tocador] a [param volume_db] em [param fade]
## segundos, no lugar de outro fade que ele estivesse fazendo.
func _levar(tocador: AudioStreamPlayer, volume_db: float, fade: float) -> Tween:
	if tocador.has_meta(&"fade"):
		var anterior := tocador.get_meta(&"fade") as Tween
		if anterior != null and anterior.is_valid():
			anterior.kill()
	var tween := tocador.create_tween()
	tween.tween_property(tocador, "volume_db", volume_db, maxf(fade, 0.0))
	tocador.set_meta(&"fade", tween)
	return tween
