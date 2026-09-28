@tool
class_name Madeira
extends Area2D

# --- TORA DE MADEIRA (combustível da fornalha) ---
#
# A matéria-prima da carbonização. No pátio da Fase 1 ela não fica largada no
# chão: está lá em cima, na copa do salgueiro, e cai quando o bumerangue
# sacode a árvore (ver ArvoreLenha, que cria a tora e chama cair()). Cada tora
# apanhada vai para o INVENTÁRIO; é de lá que a fornalha tira a lenha quando a
# pessoa abastece o forno.
#
# COMO EDITAR NO EDITOR:
#   Sprite -> PNG da tora (madeira.png; o placeholder marrom some sozinho)
#   icone  -> imagem que aparece no slot do inventário
#
# Sem texto no mapa: quem avisa que dá para recolher a tora é o balão de
# exclamação (ExclamacaoAnimada), o mesmo dos cientistas e dos terminais.
#
# A QUEDA (cair()) tem três tempos, e cada um existe para ser LIDO:
#   1. solta do galho — ela aparece presa na copa e dá uma sacudida antes de
#      despencar: é a antecipação que liga a pancada do bumerangue à tora;
#   2. despenca — aceleração constante (gravidade de verdade, não um deslize
#      linear) e girando: sai de pé do galho e chega deitada;
#   3. bate no chão — poeira, o "toc" da lenha, tremor de câmera e um quique
#      curto com um segundo toque mais fraco.
# Enquanto cai, não dá para recolher e o "!" não aparece: tora no ar não é
# tora no chão.

const CENA := "res://scenes/fases/componentes/madeira.tscn"

## Prefixo dos ids no inventário. Cada tora entra com um id próprio porque o
## inventário guarda um item por id — é assim que ele consegue mostrar as três.
const PREFIXO_ID := "madeira_"

## Grupo de toda tora espalhada pela fase — é assim que a fornalha as encontra.
const GRUPO := "madeira"

const ICONE_PADRAO := "res://assets/Lab/fornalha/madeira.png"

# --- A QUEDA DA ÁRVORE ---

## Gravidade da queda (px/s²). Mais forte que a real de propósito: a tora é
## pesada, e uma queda lenta leria como pena, não como lenha.
const GRAVIDADE_DA_QUEDA := 2200.0
## Quanto ela gira no ar: sai de pé do galho (3/4 de volta) e chega deitada.
const GIRO_DA_QUEDA := PI * 1.5
## O "soltar do galho": quanto dura a sacudida antes de despencar, e o ângulo.
const TEMPO_SOLTANDO := 0.14
const SACUDIDA_NO_GALHO := 0.28
## O quique depois da batida: altura (px) e duração de cada metade (s).
const ALTURA_DO_QUIQUE := 9.0
const TEMPO_DO_QUIQUE := 0.1
## Amassada da batida (escala da arte no impacto) e quanto leva para voltar.
const AMASSADA := Vector2(1.18, 0.6)
const TEMPO_DA_AMASSADA := 0.32
const TREMOR_DA_QUEDA := 2.0
## Caindo, a tora passa NA FRENTE da árvore (o Terreno e a parte da frente da
## copa estão no z_index 10): senão ela nasceria escondida atrás das folhas. No
## chão ela volta para a camada normal dela.
const Z_CAINDO := 11

## O "toc" da tora no chão: o mesmo ColocandoMadeira.mp3 da fornalha, cortado
## numa batida só. Medido, não chutado — o envelope em 9,5–11,4 s é:
##   9,77  a batida sobe (−43 dB)
##   9,85–9,93  O PICO (−15 a −20 dB)
##   até 10,6  a cauda morrendo (−55 dB)
##   10,7–11,0  um chocalho de lenha mexendo, que numa queda soaria errado
const SOM_DA_QUEDA := preload("res://sounds/ColocandoMadeira.mp3")
const SOM_DA_QUEDA_INICIO := 9.76
const SOM_DA_QUEDA_FIM := 10.6
## O arquivo é baixo (a fornalha também toca ele em +12 dB).
const VOLUME_DA_BATIDA := 10.0
const VOLUME_DO_QUIQUE := 1.0

## Ícone do slot do inventário. Deixe vazio para usar a arte da própria tora.
@export var icone: Texture2D

## Emitido quando a tora termina de cair e assenta no chão (ver cair()).
signal pousou

var _jogador_perto: bool = false
# Estado do balão, para o PopupFX só ser chamado na virada.
var _aviso_visivel: bool = false
var _caindo: bool = false
var _escala_da_arte: Vector2 = Vector2.ONE

@onready var _sprite: Sprite2D = $Sprite
@onready var _placeholder: ColorRect = $Placeholder
@onready var _exclamacao: AnimatedSprite2D = get_node_or_null("ExclamacaoAnimada")


static func criar(pai: Node, nome: String, pos_local: Vector2) -> Madeira:
	var tora: Madeira = load(CENA).instantiate()
	tora.name = nome
	tora.position = pos_local
	Blockout.adicionar(pai, tora)
	return tora


## Quantas toras a pessoa está carregando.
static func quantidade_no_inventario() -> int:
	var total := 0
	for item in Inventario.itens_coletados:
		if str(item["id"]).begins_with(PREFIXO_ID):
			total += 1
	return total


## Tira uma tora do inventário. Devolve false se não havia nenhuma.
static func consumir_do_inventario() -> bool:
	for item in Inventario.itens_coletados:
		var id := str(item["id"])
		if id.begins_with(PREFIXO_ID):
			Inventario.remover_item(id)
			return true
	return false


func _ready() -> void:
	Blockout.aplicar_arte(_sprite, _placeholder)
	_escala_da_arte = _sprite.scale
	if Engine.is_editor_hint():
		return

	# Já recolhida numa visita anterior (a lenha está no inventário ou dentro
	# da fornalha): não reaparece no depósito ao voltar para a fase.
	if EstadoMundo.ja_feito(self):
		queue_free()
		return

	body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_jogador_perto = true)
	body_exited.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_jogador_perto = false)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_atualizar_aviso()
	if _jogador_perto and not _caindo and Interacao.pediu():
		coletar()


## True do instante em que ela se solta do galho até assentar no chão.
func esta_caindo() -> bool:
	return _caindo


## Metade da altura da tora deitada: o quanto o centro dela fica acima do
## chão. É com isto que a árvore calcula onde a tora pousa.
func meia_altura() -> float:
	if _sprite and _sprite.texture:
		return _sprite.texture.get_height() * absf(_escala_da_arte.y) * 0.5
	if _placeholder:
		return _placeholder.size.y * 0.5
	return 0.0


## Despenca de onde ela está (o galho) até `repouso`: a posição GLOBAL do
## centro dela deitada no chão. Recolher só vale depois que ela assenta.
func cair(repouso: Vector2) -> void:
	_caindo = true
	_atualizar_aviso()
	var z_original := z_index
	var z_relativo := z_as_relative
	z_as_relative = false
	z_index = Z_CAINDO

	var pai := get_parent() as Node2D
	var destino := pai.to_local(repouso) if pai else repouso
	var altura := maxf(destino.y - position.y, 1.0)
	var tempo_de_queda := sqrt(2.0 * altura / GRAVIDADE_DA_QUEDA)
	# O lado do giro é sorteado: três toras girando igual pareceriam carimbo.
	var lado := 1.0 if randf() < 0.5 else -1.0
	var giro_inicial := lado * (GIRO_DA_QUEDA + randf_range(-0.3, 0.3))
	rotation = giro_inicial
	modulate.a = 0.0

	var tween := create_tween()
	# 1. Solta do galho: aparece e dá uma sacudida no lugar.
	tween.tween_property(self, "modulate:a", 1.0, 0.05)
	tween.parallel().tween_property(self, "rotation", giro_inicial + lado * SACUDIDA_NO_GALHO,
		TEMPO_SOLTANDO * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", giro_inicial, TEMPO_SOLTANDO * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 2. Despenca: QUAD + EASE_IN é aceleração constante partindo do repouso,
	# que é exatamente o que a gravidade faz. Gira até deitar no impacto.
	tween.tween_property(self, "position:y", destino.y, tempo_de_queda)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "position:x", destino.x, tempo_de_queda)
	tween.parallel().tween_property(self, "rotation", 0.0, tempo_de_queda)
	# 3. Bate, quica e assenta.
	tween.tween_callback(_bater_no_chao)
	tween.tween_property(self, "position:y", destino.y - ALTURA_DO_QUIQUE, TEMPO_DO_QUIQUE)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "rotation", -lado * 0.1, TEMPO_DO_QUIQUE)
	tween.tween_property(self, "position:y", destino.y, TEMPO_DO_QUIQUE)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "rotation", 0.0, TEMPO_DO_QUIQUE)
	tween.tween_callback(_assentar.bind(z_original, z_relativo))


## O impacto: é aqui que a queda ganha peso.
func _bater_no_chao() -> void:
	_tocar_batida(VOLUME_DA_BATIDA, randf_range(0.92, 1.02))
	_amassar(1.0)
	_levantar_poeira()
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("disparar_tremor"):
		camera.disparar_tremor(TREMOR_DA_QUEDA)


## O fim do quique: um segundo toque mais fraco e mais agudo, e a tora já é
## uma tora normal no chão, que se recolhe com E.
func _assentar(z_original: int, z_relativo: bool) -> void:
	_tocar_batida(VOLUME_DO_QUIQUE, randf_range(1.12, 1.22))
	_amassar(0.4)
	z_as_relative = z_relativo
	z_index = z_original
	_caindo = false
	_atualizar_aviso()
	pousou.emit()


## Achata a arte e deixa ela voltar num elástico curto. `forca` 1 é a batida
## cheia, menos que isso é o toque do quique.
func _amassar(forca: float) -> void:
	if _sprite == null:
		return
	var amassada := Vector2.ONE.lerp(AMASSADA, forca)
	_sprite.scale = _escala_da_arte * amassada
	create_tween().tween_property(_sprite, "scale", _escala_da_arte, TEMPO_DA_AMASSADA)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## O som mora no PAI, não na tora: quem recolhe a lenha logo depois de ela
## assentar apagaria a tora (e o som junto) no meio do "toc".
func _tocar_batida(volume_db: float, tom: float) -> void:
	var pai := get_parent()
	if pai == null:
		return
	var som := AudioStreamPlayer2D.new()
	som.name = "SomQuedaMadeira"
	som.stream = SOM_DA_QUEDA
	som.volume_db = volume_db
	som.pitch_scale = tom
	pai.add_child(som)
	som.global_position = global_position
	som.play(SOM_DA_QUEDA_INICIO)
	get_tree().create_timer((SOM_DA_QUEDA_FIM - SOM_DA_QUEDA_INICIO) / tom).timeout\
		.connect(som.queue_free)


## Poeira baixa espirrando para os lados, na linha do chão embaixo da tora.
func _levantar_poeira() -> void:
	var pai := get_parent()
	if pai == null:
		return
	var poeira := CPUParticles2D.new()
	poeira.name = "PoeiraDaQueda"
	poeira.z_as_relative = false
	poeira.z_index = Z_CAINDO
	poeira.amount = 14
	poeira.lifetime = 0.55
	poeira.one_shot = true
	poeira.explosiveness = 1.0
	poeira.local_coords = false
	poeira.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	poeira.emission_rect_extents = Vector2(maxf(meia_altura() * 3.5, 16.0), 2.0)
	poeira.direction = Vector2.UP
	poeira.spread = 80.0
	poeira.initial_velocity_min = 35.0
	poeira.initial_velocity_max = 95.0
	poeira.gravity = Vector2(0, -12)
	poeira.damping_min = 110.0
	poeira.damping_max = 170.0
	poeira.scale_amount_min = 2.0
	poeira.scale_amount_max = 4.5
	var rampa := Gradient.new()
	rampa.set_color(0, Color(0.8, 0.72, 0.6, 0.8))
	rampa.set_color(1, Color(0.62, 0.56, 0.48, 0.0))
	poeira.color_ramp = rampa
	pai.add_child(poeira)
	poeira.global_position = global_position + Vector2(0, meia_altura())
	poeira.emitting = true
	poeira.finished.connect(poeira.queue_free)


## Guarda a tora no inventário e some com ela — usado tanto pela interação
## normal (E por perto) quanto por atalhos de teste que recolhem tudo de vez.
func coletar() -> void:
	_guardar()
	EstadoMundo.marcar_feito(self)
	queue_free()


func _guardar() -> void:
	var textura := icone
	if textura == null and _sprite:
		textura = _sprite.texture
	if textura == null:
		textura = load(ICONE_PADRAO)
	Inventario.adicionar_item(PREFIXO_ID + name.to_lower(), "Madeira", textura,
		"Lenha seca, derrubada da árvore do pátio. A fornalha aceita três cargas.")


## O balão de exclamação no lugar do "madeira [E]" que ficava escrito em cima
## da tora: aparece quando a jogadora chega perto e some quando ela se afasta.
func _atualizar_aviso() -> void:
	if _exclamacao == null:
		return
	var mostrar := _jogador_perto and not _caindo
	if mostrar == _aviso_visivel:
		return
	_aviso_visivel = mostrar
	if mostrar:
		PopupFX.mostrar(_exclamacao)
	else:
		PopupFX.esconder(_exclamacao)
