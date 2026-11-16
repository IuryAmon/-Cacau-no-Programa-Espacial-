extends FaseBase

# --- O TELHADO DA TORRE DE GASES (fase 2) ---
#
# O alto da torre, ao ar livre e de noite (o mesmo céu da rua, BG copiado de
# lá, com a serra mais baixa no horizonte). Chega-se pela PortaEscada, a
# portinha da casinha da escada, que é o par da porta do último andar da torre
# (fase2_torre_interior.tscn). Aqui estão:
#
#   CilindroDeAr     o cilindro de amostra VAZIO (componentes/
#                    cilindro_do_telhado.tscn): o E pega e ele vai para a
#                    mochila.
#
# O ELEVADOR DE CARGA leva do telhado para a rua (fase2_torre.tscn). A cabine é
# PINTADA nos tiles: tudo, de qualquer camada, dentro da "Area Do Elevador"
# (Inspector do nó raiz, hoje x 1024 a 1120 e y 480 a 608). Vale o CENTRO de
# cada célula, então a grade da Frente, 3 px para a direita, entra certinha.
# No jogo, essas células saem das camadas e viram o nó ElevadorDeCarga (ver
# bloco_de_tiles.gd). A Cacau entra na cabine (em qualquer ponto da faixa,
# entre as bordas dela), aperta E, anda até o meio e a cabine afunda levando
# ela: as duas somem na borda de baixo da área (o fundo do poço) e o lugar
# fica VAZIO — o que estiver pintado atrás, numa camada fora da área, aparece.
# A câmera fica parada; no fim a tela apaga e a rua abre com ela descendo na
# plataforma (fase2_torre.gd). Sem o cilindro, o E vira a mesma fala da
# escada. O E aparece logo acima da cabine.
#
# ANDA-SE PARA A FRENTE E PARA TRÁS (como em Final Fight): o nó FaixaDoChao (o
# retângulo azul-claro, só aparece no editor) é por onde os PÉS da Cacau
# andam — ←/→ para os lados, ↑/↓ para o fundo e para a frente (ver "ANDAR NA
# FAIXA" em player.gd). Arraste e estique ele para mudar a faixa. A Cacau é
# menor aqui (a escala do nó Player) e a câmera chega mais perto (o
# "Zoom Da Camera" dele). O pulo sobe e cai na mesma linha; as velocidades da
# faixa estão no Player ("Velocidade Na Faixa" e "Velocidade De Profundidade").
#
# Chegar aqui marca MissaoNitrogenio.subiu_a_torre. Na primeira chegada, com o
# cilindro ainda no lugar, a Cacau comenta ("fala_ao_chegar").
#
# SEM O CILINDRO, NÃO SE DESCE: enquanto ele estiver no suporte, a PortaEscada
# não leva para baixo. O E na porta vira a fala "fala_sem_cilindro" ("Eu
# preciso pegar o cilindro antes!"). É o mesmo jeito da rua com a amostra
# gelada na mão (fase2_torre.gd). No modo dev a porta fica livre.
#
# COMO EDITAR NO EDITOR, de trás para a frente:
#   Cenario       a casinha de tijolo, a grade do FUNDO da laje, o poço, os
#                 enfeites (tileset da cidade), atrás de tudo;
#   Terreno       o chão da laje e o telhado da casinha (tileset das fases);
#   (a Cacau)
#   Frente        a grade da FRENTE da laje (tileset da cidade), z_index 10:
#                 desenhada na frente da Cacau, sem colisão;
#   MuroDaFrente  o muro de tijolos embaixo da grade da frente (tileset das
#                 fases, na mesma grade do Terreno), também z_index 10 e sem
#                 colisão.
# A PortaEscada e o CilindroDeAr ficam com a origem no chão, na linha do fundo.
#
# O MURO NA FRENTE DELA começa em y = 564 (a base da grade da frente, a guia
# horizontal do editor): abaixo disso, NADA do sprite da Cacau é desenhado —
# andando até a beirada da faixa (os pés vão até 570), os pés passam por trás
# do muro. O valor é o "Topo Do Muro Da Frente", no Inspector do nó raiz
# (Fase2Telhado); quem esconde é o shader corte_abaixo.gdshader no sprite
# dela (esconder_abaixo_de, em player.gd).

## A Cacau, na primeira vez que sai da escada para o telhado.
@export var fala_ao_chegar: String = "cacau_torre_telhado"
## A Cacau, tentando descer pela escada com o cilindro ainda no suporte.
@export var fala_sem_cilindro: String = "cacau_pegar_cilindro_antes"
## O muro que fica na frente dela: abaixo desta altura (y do mundo, a guia de
## 564 no editor) nada do sprite da Cacau aparece. 0 desliga.
@export var topo_do_muro_da_frente: float = 564.0

@export_group("Elevador")
## Onde a cabine está pintada (retângulo do mundo, em px: x, y, largura,
## altura). Toda célula de qualquer camada de tile com o CENTRO aqui dentro é
## da cabine. A borda de baixo é o fundo do poço: ali ela some ao descer.
@export var area_do_elevador := Rect2(1024, 480, 96, 128)
## Quanto tempo a cabine leva para afundar (s).
@export var duracao_da_descida: float = 1.8

## Das bordas da cabine para dentro, quanto o meio da Cacau precisa estar para
## o E aparecer (px).
const MARGEM_DA_CABINE := 12.0

@onready var _porta_escada: Area2D = get_node_or_null("PortaEscada")
@onready var _cilindro: CilindroDoTelhado = get_node_or_null("CilindroDeAr")

var _cabine: BlocoDeTiles = null
var _e_da_cabine: IndicadorEntrada = null
var _descendo: bool = false


func _ready() -> void:
	super._ready()
	if player and player.has_method("esconder_abaixo_de") and topo_do_muro_da_frente > 0.0:
		player.esconder_abaixo_de(topo_do_muro_da_frente)
	_montar_elevador()
	_atualizar_travas()
	var primeira_vez := not MissaoNitrogenio.subiu_a_torre
	MissaoNitrogenio.subiu_a_torre = true
	if primeira_vez and cilindro_no_lugar() and not fala_ao_chegar.is_empty():
		_falar_quando_livre()


func _process(_delta: float) -> void:
	_atualizar_travas()
	_vigiar_porta_da_escada()
	_vigiar_elevador()


## O cilindro ainda está no suporte (o nó some quando já foi pego antes).
func cilindro_no_lugar() -> bool:
	return is_instance_valid(_cilindro) and _cilindro.ainda_no_lugar()


func _atualizar_travas() -> void:
	var sem_cilindro := cilindro_no_lugar()
	if _porta_escada and "interativa" in _porta_escada:
		_porta_escada.interativa = not sem_cilindro or ModoDev.ativo


## Porta trancada não reage ao E sozinha: a fala sai daqui. Só com a Cacau
## livre — um E apertado enquanto ela ainda sai da porta, chegando, não conta.
func _vigiar_porta_da_escada() -> void:
	if _porta_escada == null or player == null or not cilindro_no_lugar() or ModoDev.ativo:
		return
	if not player.pode_se_mover or not _porta_escada.overlaps_body(player):
		return
	# Interacao.pediu() queima o toque, então fica por último.
	if Interacao.pediu():
		DialogicBridge.falar(fala_sem_cilindro)


## A fala espera a Cacau terminar de sair pela porta (o controle volta) e
## nenhuma outra tela estar aberta.
func _falar_quando_livre() -> void:
	await get_tree().create_timer(0.6).timeout
	while is_inside_tree() and player != null \
			and (not player.pode_se_mover or Interacao.ocupada()):
		await get_tree().process_frame
	if is_inside_tree():
		DialogicBridge.falar(fala_ao_chegar)


# --- O ELEVADOR DE CARGA ---

## Tira a cabine das camadas de tile (ver bloco_de_tiles.gd) e põe o E acima
## dela.
func _montar_elevador() -> void:
	var camadas: Array = []
	for no in find_children("*", "TileMapLayer", true, false):
		if no.owner == self:
			camadas.append(no)
	_cabine = BlocoDeTiles.recortar(self, "ElevadorDeCarga", camadas, area_do_elevador)
	if _cabine.celulas() == 0:
		push_warning("Fase2Telhado: nenhum tile dentro da Area Do Elevador.")
	_cabine.cortar_abaixo_de(area_do_elevador.end.y)
	_e_da_cabine = load(IndicadorEntrada.CENA).instantiate() as IndicadorEntrada
	_e_da_cabine.name = "EDoElevador"
	_e_da_cabine.position = Vector2(area_do_elevador.get_center().x, area_do_elevador.position.y - 40.0)
	add_child(_e_da_cabine)


## A Cacau, livre e no chão, com o meio dela entre as bordas da cabine.
func esta_na_cabine() -> bool:
	if _cabine == null or player == null or _descendo:
		return false
	if not player.pode_se_mover or not player.is_on_floor():
		return false
	var meia := area_do_elevador.size.x * 0.5 - MARGEM_DA_CABINE
	return absf(player.global_position.x - area_do_elevador.get_center().x) <= meia


func _vigiar_elevador() -> void:
	if _cabine == null or _descendo:
		return
	var dentro := esta_na_cabine()
	if _e_da_cabine:
		_e_da_cabine.mostrar(dentro and not Interacao.ocupada())
	# Interacao.pediu() queima o toque, então fica por último.
	if not dentro or not Interacao.pediu():
		return
	if cilindro_no_lugar() and not ModoDev.ativo:
		DialogicBridge.falar(fala_sem_cilindro)
		return
	descer_de_elevador()


## A viagem inteira: ela anda até o meio da cabine, a cabine afunda levando ela
## (a câmera parada) e, sumidas as duas no fundo do poço, a rua abre.
func descer_de_elevador() -> void:
	if _descendo or _cabine == null or player == null:
		return
	_descendo = true
	if _e_da_cabine:
		_e_da_cabine.mostrar(false)
	var cacau := player
	cacau.velocity = Vector2.ZERO
	cacau.pode_se_mover = false
	# A física dela fica parada: nem gravidade, nem o chão da faixa puxando.
	cacau.animacao_controlada_externamente = true

	await _andar_ate_o_meio(cacau)
	if not is_inside_tree():
		return
	_tocar(cacau, &"idle")

	var camera := cacau.get_node_or_null("Camera2D") as Camera2D
	var camera_no_mundo := Vector2.ZERO
	if camera:
		camera_no_mundo = camera.global_position
		camera.position_smoothing_enabled = false
	await get_tree().create_timer(0.25).timeout
	if not is_inside_tree():
		return

	var viagem := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	viagem.tween_method(_passo_da_descida.bind(cacau, cacau.global_position.y, camera, camera_no_mundo),
		0.0, _curso_da_descida(cacau), duracao_da_descida)
	await viagem.finished
	if not is_inside_tree():
		return

	MissaoNitrogenio.chegando_de_elevador = true
	FadeTela.trocar_cena(self, MissaoNitrogenio.CENA_RUA)


func _andar_ate_o_meio(cacau: CharacterBody2D) -> void:
	var meio := area_do_elevador.get_center().x
	var passo := meio - cacau.global_position.x
	if absf(passo) < 1.0:
		return
	var sprite := cacau.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.flip_h = passo < 0.0
	_tocar(cacau, &"run")
	var rapidez: float = cacau.velocidade_na_faixa if cacau.velocidade_na_faixa > 0.0 else cacau.speed
	var andar := create_tween()
	andar.tween_property(cacau, "global_position:x", meio, absf(passo) / rapidez)
	await andar.finished


## Um quadro da descida: a cabine "d" px abaixo do lugar e ela junto. O corte
## do sprite dela desce com a cabine (ela continua atrás da beirada da frente)
## até o fundo do poço, onde a cabine também some.
func _passo_da_descida(d: float, cacau: CharacterBody2D, y_de_partida: float,
		camera: Camera2D, camera_no_mundo: Vector2) -> void:
	_cabine.deslocamento = d
	cacau.global_position.y = y_de_partida + d
	var fundo := area_do_elevador.end.y
	var muro := topo_do_muro_da_frente if topo_do_muro_da_frente > 0.0 else fundo
	cacau.esconder_abaixo_de(minf(muro + d, fundo))
	if is_instance_valid(camera):
		camera.global_position = camera_no_mundo


## Quanto a cabine desce: até ela sumir inteira — e a Cacau também, que no
## fundo da faixa passa com a cabeça acima da cabine.
func _curso_da_descida(cacau: CharacterBody2D) -> float:
	var curso := area_do_elevador.size.y
	var sprite := cacau.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.sprite_frames:
		var textura := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if textura:
			var escala := sprite.global_scale.abs()
			var topo := sprite.global_position.y + sprite.offset.y * escala.y
			if sprite.centered:
				topo -= textura.get_size().y * escala.y * 0.5
			curso = maxf(curso, area_do_elevador.end.y - topo)
	return curso + 2.0


func _tocar(cacau: CharacterBody2D, animacao: StringName) -> void:
	var sprite := cacau.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(animacao):
		sprite.play(animacao)


## A cabine (para o teste e o modo dev).
func cabine_do_elevador() -> BlocoDeTiles:
	return _cabine
