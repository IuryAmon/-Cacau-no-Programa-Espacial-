@tool
class_name RetortaCarbonizacao
extends Node2D

# --- A FORNALHA DE CARBONIZAÇÃO (clímax da Fase 1) ---
#
# ONDE ELA MORA: no PÁTIO, a fase1.2 (scenes/fases/fase1_2_exterior.tscn), que
# é a parte de fora do laboratório — sobe-se até lá pelo elevador de carga da
# entrada da oficina. A lenha mora lá com ela, na copa da árvore do pátio (ver
# ArvoreLenha), de propósito: é na própria cena da fornalha que a lenha
# perdida volta quando uma queima falha (ver _repor_toras), então lenha e
# forno não podem ficar em fases diferentes.
#
# Pirólise de verdade: madeira aquecida SEM oxigênio vira carvão. O puzzle
# segue cinco passos:
#   1. derrubar as três toras da árvore com o bumerangue (uma por arremesso)
#      e recolhê-las do chão (elas ficam no inventário);
#   2. abastecer a fornalha com E — uma tora por toque, até encher;
#   3. acender com o maçarico oxídrico (E na fornalha cheia);
#   4. no painel da fornalha (scripts/ui/painel_fornalha.gd): segurar E até o
#      termômetro chegar na marca e, no ponto, vedar a entrada de ar (S) —
#      se o ar continuar entrando, a madeira queima e vira cinza;
#   5. com o carvão pronto, E na fornalha novamente retira a célula C.
#
# COMO EDITAR NO EDITOR:
#   Sprite            -> AnimatedSprite2D da fornalha, com as animações
#                        "desligada", "madeira1", "madeira2", "madeira3" e
#                        "ligada" (o placeholder some sozinho)
#   PosicaoDoMacarico -> onde a Cacau fica para acender a fornalha. Como na
#                        porta de metal, ao apertar E com a fornalha cheia ela
#                        anda sozinha até aqui e só então acende o maçarico,
#                        virada para o forno. Arraste o marcador para mudar o
#                        lugar (o x é o que vale; ela anda no chão)
#
# As toras NÃO ficam dentro desta cena. No pátio quem as cria é a ArvoreLenha
# (arraste os marcadores Galho1..3 dela para mudar onde caem), e é para ela
# que a lenha volta se a carga virar cinza: a árvore devolve à copa só as
# toras que se perderam no fogo. Numa fase sem árvore, as toras são
# instâncias de madeira.tscn soltas no chão (grupo "madeira") e a fornalha
# anota onde estavam, para repô-las no mesmo lugar.
#
# SAIR DA FASE NÃO PERDE NADA: a carga do forno e o carvão esperando para ser
# retirado ficam no EstadoMundo (cada tora também lembra que foi recolhida).
# Só o fogo aceso no meio da temperatura não sobrevive — é uma tela na frente,
# não dá para sair por uma porta com ela aberta.

const CENA := "res://scenes/fases/componentes/retorta.tscn"

## O fogo pega primeiro e o painel da fornalha só entra depois desta espera.
const ESPERA_ANTES_DO_PAINEL := 0.8

## Depois que a pirólise termina, a fornalha ainda fica acesa este tanto antes
## de apagar — e é só depois que ela apaga que dá pra retirar o carvão.
const BRASA_APOS_CONCLUIR := 4.0

## Quantos estágios de enchimento o sprite "fornalhaComMadeira" tem.
const ESTAGIOS_DE_MADEIRA := 3

## Trecho do ColocandoMadeira.mp3 que toca a cada tora abastecida — o arquivo
## tem mais coisa em volta, só esse pedaço é o "toc" da lenha entrando.
const SOM_MADEIRA_INICIO := 9.61
const SOM_MADEIRA_FIM := 11.20

## Salto do carvão para fora da fornalha quando a pirólise termina (ver
## _saltar_carvao): sobe até POSICAO_CARVAO_FORA + o extra do pico e cai de
## volta com um quique, pousando ali — é onde ele fica esperando o E.
const POSICAO_CARVAO_DENTRO := Vector2(0, -65)
const POSICAO_CARVAO_FORA := Vector2(0, -85)
const PICO_SALTO_CARVAO := 20.0

## Boca da fornalha: de onde sobe a cinza quando a carga queima.
const POSICAO_DAS_CINZAS := Vector2(0, -100)
## Comporta fechada: as chamas do sprite andam neste ritmo e o som do fogo
## baixa isto (dB) até a brasa apagar.
const RITMO_DO_FOGO_ABAFADO := 0.5
const ABAFAMENTO_DO_SOM := 9.0

## Arte e ficha do item que vai para a mochila (canto superior direito) ao
## retirar o carvão — mesma ficha de coleta dos cilindros de H₂/O₂.
const TEXTURA_CARVAO := preload("res://assets/itens/Carvão.png")
const ID_CARVAO := AmostraChonps.ID_CARVAO
const NOME_CARVAO := "Carvão Vegetal"
const DESCRICAO_CARVAO := "Amostra sólida de carbono, sobra da pirólise da madeira sem oxigênio, o que faltava para acender o C no painel CHONPS."

@export var madeiras_necessarias: int = 3

var _madeiras_no_forno: int = 0
var _acesa: bool = false
var _carbono_pronto: bool = false
var _jogador_perto: bool = false
var _resolvida: bool = false
var _painel_aberto: bool = false
var _macarico_na_mao: bool = false
var _painel: PainelFornalha = null
var _volume_do_fogo: float = 0.0

# As toras da fase como estavam quando ela abriu (nome, posição e caminho),
# para repô-las depois de uma queima malsucedida — com o MESMO nome, que é a
# chave com que cada tora lembra no EstadoMundo se já foi recolhida.
var _toras_originais: Array[Dictionary] = []
var _pai_das_toras: Node = null

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _placeholder: Node2D = $Placeholder
@onready var _area: Area2D = $AreaInteracao
@onready var _posicao_macarico: Marker2D = $PosicaoDoMacarico
@onready var _exclamacao: AnimatedSprite2D = $ExclamacaoAnimada
@onready var _popup_madeira: AnimatedSprite2D = $PopupMadeira
@onready var _som_madeira: AudioStreamPlayer2D = $SomColocarMadeira
@onready var _sprite_carvao: Sprite2D = $SpriteCarvao
@onready var _som_carvao: AudioStreamPlayer2D = $SomCarvaoPronto
@onready var _som_fogo: AudioStreamPlayer2D = $SomFogo

var _popup_madeira_visivel: bool = false


static func criar(pai: Node, pos: Vector2, config: Dictionary = {}) -> RetortaCarbonizacao:
	var retorta: RetortaCarbonizacao = load(CENA).instantiate()
	retorta.name = "Retorta"
	retorta.position = pos
	for chave in config:
		retorta.set(chave, config[chave])
	Blockout.adicionar(pai, retorta)
	return retorta


func _ready() -> void:
	if _sprite and _placeholder:
		_placeholder.visible = _sprite.sprite_frames == null
		_sprite.visible = _sprite.sprite_frames != null
	_atualizar_sprite()
	if Engine.is_editor_hint():
		return

	if _som_fogo:
		_volume_do_fogo = _som_fogo.volume_db
	_resolvida = EstadoMundo.ja_feito(self)
	# O que estava dentro da fornalha na última visita: sair da fase não
	# esvazia a carga nem some com o carvão que esperava ser retirado.
	_madeiras_no_forno = EstadoMundo.ler(self, "madeiras_no_forno", 0)
	_carbono_pronto = EstadoMundo.ler(self, "carbono_pronto", false)
	_memorizar_toras()
	_atualizar_sprite()
	if _carbono_pronto and _sprite_carvao:
		_sprite_carvao.position = POSICAO_CARVAO_FORA
		_sprite_carvao.visible = true

	if _exclamacao:
		_exclamacao.visible = false
		_exclamacao.stop()
	if _popup_madeira:
		_popup_madeira.visible = false
		_popup_madeira.stop()

	_area.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_jogador_perto = true
			_atualizar_exclamacao())
	_area.body_exited.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_jogador_perto = false
			_atualizar_exclamacao())

	if _resolvida:
		_limpar_toras()


## Anota as toras que a fase trouxe — inclusive as já recolhidas numa visita
## anterior, que ainda estão na árvore neste frame (o queue_free delas só
## acontece no fim do quadro) —, para saber repô-las depois.
func _memorizar_toras() -> void:
	_toras_originais.clear()
	for tora in get_tree().get_nodes_in_group(Madeira.GRUPO):
		if tora is Node2D:
			_toras_originais.append({
				"nome": tora.name,
				"posicao": tora.global_position,
				"caminho": str(tora.get_path()),
			})
			if _pai_das_toras == null:
				_pai_das_toras = tora.get_parent()


func _limpar_toras() -> void:
	for tora in get_tree().get_nodes_in_group(Madeira.GRUPO):
		tora.queue_free()


## Devolve a lenha depois de uma queima perdida. Com a ArvoreLenha na fase, as
## toras perdidas voltam para a copa dela. Sem árvore, voltam aos lugares de
## origem no chão, com o nome original e "desrecolhidas" no EstadoMundo: quem
## sair e voltar para a fase depois disso continua achando as toras lá.
func _repor_toras() -> void:
	# Com a árvore do pátio na fase, a lenha não reaparece no chão: a que virou
	# cinza volta para a copa, e é o bumerangue que a derruba de novo.
	var arvore := get_tree().get_first_node_in_group(ArvoreLenha.GRUPO) as ArvoreLenha
	if arvore:
		arvore.repor_toras_perdidas()
		return
	var pai: Node2D = null
	if is_instance_valid(_pai_das_toras):
		pai = _pai_das_toras as Node2D
	if pai == null:
		pai = get_parent() as Node2D
	if pai == null:
		return
	for tora in get_tree().get_nodes_in_group(Madeira.GRUPO):
		# Sai da árvore JÁ: a tora nova precisa do mesmo nome livre.
		tora.get_parent().remove_child(tora)
		tora.queue_free()
	for dados in _toras_originais:
		EstadoMundo.desmarcar_caminho(dados["caminho"])
		Madeira.criar(pai, dados["nome"], pai.to_local(dados["posicao"]))


## Anota a carga e o carvão no EstadoMundo, para sobreviverem a sair da fase.
func _guardar_carga() -> void:
	EstadoMundo.guardar(self, "madeiras_no_forno", _madeiras_no_forno)
	EstadoMundo.guardar(self, "carbono_pronto", _carbono_pronto)


func _cheia() -> bool:
	return _madeiras_no_forno >= madeiras_necessarias


## Escolhe o quadro da fornalha: apagada, enchendo (3 estágios) ou em chamas.
func _atualizar_sprite() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if _acesa:
		if _sprite.animation != &"ligada":
			_tocar_som_fogo()
		_sprite.play("ligada")
		return
	# Apagada, as chamas voltam ao ritmo normal para a próxima queima.
	_sprite.speed_scale = 1.0
	if _madeiras_no_forno <= 0:
		_parar_som_fogo()
		_sprite.play("desligada")
	else:
		# Vale para qualquer "madeiras_necessarias": a carga é distribuída
		# entre os estágios que o sprite tem.
		_parar_som_fogo()
		var fracao := float(_madeiras_no_forno) / float(maxi(madeiras_necessarias, 1))
		var estagio := clampi(int(ceil(fracao * ESTAGIOS_DE_MADEIRA)), 1, ESTAGIOS_DE_MADEIRA)
		_sprite.play("madeira%d" % estagio)


## Mostra o "!" na fornalha quando dá pra retirar o carvão: só depois que a
## brasa apaga (fornalha desligada) E o jogador está por perto.
func _atualizar_exclamacao() -> void:
	if _exclamacao == null:
		return
	if _jogador_perto and _carbono_pronto and not _acesa:
		PopupFX.mostrar(_exclamacao)
	else:
		PopupFX.esconder(_exclamacao)


## Mostra o balão de fogo (o mesmo do puzzle de combustão do foguete) ANTES
## do "!": indica que é aqui que a madeira entra, enquanto a fornalha ainda
## não está cheia, acesa ou resolvida. Chamada todo frame — só dispara o
## PopupFX de verdade quando o estado muda, senão a animação reiniciaria a
## cada chamada.
func _atualizar_popup_madeira() -> void:
	if _popup_madeira == null:
		return
	var deveria_mostrar := _jogador_perto and not _resolvida and not _carbono_pronto \
		and not _acesa and not _cheia()
	if deveria_mostrar == _popup_madeira_visivel:
		return
	_popup_madeira_visivel = deveria_mostrar
	if deveria_mostrar:
		PopupFX.mostrar(_popup_madeira)
	else:
		PopupFX.esconder(_popup_madeira)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _resolvida:
		return
	_atualizar_popup_madeira()
	if _painel_aberto:
		# Com o painel na tela, a pose segue o fogo: atiçando (E) ela aponta o
		# maçarico para o forno, largando ela volta ao idle — e na hora de
		# vedar o ar ela já baixou o maçarico. Enquanto o painel não abriu (o
		# fogo pegando), a chama fica acesa direto.
		if is_instance_valid(_painel):
			_segurar_macarico(_painel.soprando(), 1.0)
		return
	if _carbono_pronto:
		# A pirólise terminou: em vez de pular em cima de um item flutuante,
		# a célula sai com o mesmo E usado para abastecer e acender.
		if _jogador_perto and Interacao.pediu():
			_retirar_carbono()
		return
	if _jogador_perto and Interacao.pediu():
		if _cheia():
			_tentar_acender()
		else:
			_abastecer()


func _abastecer() -> void:
	if not Madeira.consumir_do_inventario():
		return
	_madeiras_no_forno += 1
	_guardar_carga()
	_atualizar_sprite()
	_tocar_som_madeira()


## Recorte de ColocandoMadeira.mp3 (ver SOM_MADEIRA_INICIO/FIM) — uma tora
## abastecida, um toque.
func _tocar_som_madeira() -> void:
	if _som_madeira == null or _som_madeira.stream == null:
		return
	_som_madeira.play(SOM_MADEIRA_INICIO)
	await get_tree().create_timer(SOM_MADEIRA_FIM - SOM_MADEIRA_INICIO).timeout
	if is_instance_valid(_som_madeira) and _som_madeira.playing:
		_som_madeira.stop()


## Toca res://sounds/FOGO.mp3 no instante em que a fornalha entra na animação
## "ligada" (o fogo pegando, ao acender com o maçarico).
func _tocar_som_fogo() -> void:
	if _som_fogo and _som_fogo.stream:
		_som_fogo.volume_db = _volume_do_fogo
		_som_fogo.play()


## Corta o som do fogo assim que a fornalha sai da animação "ligada" (apagou,
## desistiu ou a queima falhou).
func _parar_som_fogo() -> void:
	if _som_fogo and _som_fogo.playing:
		_som_fogo.stop()


func _tentar_acender() -> void:
	if not Progresso.tem_habilidade("macarico"):
		return

	_painel_aberto = true

	# Como na porta de metal: ela vai sozinha até o lugar de acender (o
	# marcador PosicaoDoMacarico) e só então a chama sai. O _painel_aberto
	# já ligado segura o E enquanto ela anda.
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("recuar_ate_x"):
		await player.recuar_ate_x(_posicao_macarico.global_position.x)
		if not is_instance_valid(self) or not is_inside_tree():
			return

	_acesa = true
	_atualizar_sprite()
	# Acendendo: a chama fica na mão dela até o painel abrir. Dali em diante a
	# pose acompanha o E (ver _process).
	_segurar_macarico(true)
	FerramentasHUD.destacar("macarico")

	# O fogo pega primeiro: o mundo continua rodando (o painel não pausa
	# nada), então dá para ver a fornalha pegando antes dele.
	await get_tree().create_timer(ESPERA_ANTES_DO_PAINEL).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return

	_painel = PainelFornalha.abrir(self, _area_da_cena())
	_painel.terminado.connect(_on_painel_terminado)
	_painel.vedada.connect(_abafar_fogo)


## O que o painel não pode tapar: a fornalha e a Cacau parada na frente dela.
func _area_da_cena() -> Rect2:
	var area := Rect2(global_position, Vector2.ZERO)
	if _sprite and _sprite.sprite_frames:
		var textura := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
		if textura:
			var tamanho := textura.get_size() * _sprite.global_scale.abs()
			area = Rect2(_sprite.global_position - tamanho * 0.5, tamanho)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		area = area.expand(player.global_position + Vector2(-40, -110))\
			.expand(player.global_position + Vector2(40, 10))
	return area


## Liga/desliga a pose do maçarico na personagem (ela fica virada para o forno).
## som_offset só importa ao ligar: de onde tocar o maçarico_sound dessa vez.
func _segurar_macarico(ligado: bool, som_offset: float = 0.1) -> void:
	if ligado == _macarico_na_mao:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("iniciar_uso_macarico"):
		return
	_macarico_na_mao = ligado
	if ligado:
		player.iniciar_uso_macarico(global_position.x, som_offset)
	else:
		player.encerrar_uso_macarico()
		if _painel_aberto:
			# A tela ainda está na frente: largar a pose não devolve o passeio.
			player.pode_se_mover = false


func _on_painel_terminado(sucesso: bool, cancelado: bool) -> void:
	_painel_aberto = false
	_painel = null
	_segurar_macarico(false)
	if cancelado:
		# Desistiu: o fogo apaga, mas a carga continua lá dentro.
		_acesa = false
		_atualizar_sprite()
		return
	if sucesso:
		_concluir()
	else:
		# Feedback honesto e imediato: cinzas, e lenha nova logo ali.
		_acesa = false
		_madeiras_no_forno = 0
		_guardar_carga()
		_atualizar_sprite()
		_soltar_cinzas()
		_repor_toras()


## Comporta fechada: sem ar, as chamas baixam e o fogo fica abafado até a
## brasa apagar (ver _concluir).
func _abafar_fogo() -> void:
	var tween := create_tween().set_parallel()
	if _sprite:
		tween.tween_property(_sprite, "speed_scale", RITMO_DO_FOGO_ABAFADO, 0.6)
	if _som_fogo:
		tween.tween_property(_som_fogo, "volume_db", _volume_do_fogo - ABAFAMENTO_DO_SOM, 0.6)


## A carga queimou: um punhado de cinza sobe da boca do forno.
func _soltar_cinzas() -> void:
	var cinzas := CPUParticles2D.new()
	cinzas.name = "Cinzas"
	cinzas.position = POSICAO_DAS_CINZAS
	cinzas.z_index = 1
	cinzas.amount = 26
	cinzas.lifetime = 1.8
	cinzas.one_shot = true
	cinzas.explosiveness = 0.8
	cinzas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	cinzas.emission_rect_extents = Vector2(30, 8)
	cinzas.direction = Vector2.UP
	cinzas.spread = 40.0
	cinzas.initial_velocity_min = 30.0
	cinzas.initial_velocity_max = 80.0
	cinzas.gravity = Vector2(0, -15)
	cinzas.damping_min = 25.0
	cinzas.damping_max = 45.0
	cinzas.scale_amount_min = 3.0
	cinzas.scale_amount_max = 6.0
	var rampa := Gradient.new()
	rampa.set_color(0, Color(0.62, 0.6, 0.64, 1.0))
	rampa.set_color(1, Color(0.35, 0.33, 0.37, 0.0))
	cinzas.color_ramp = rampa
	add_child(cinzas)
	cinzas.emitting = true
	cinzas.finished.connect(cinzas.queue_free)


func _concluir() -> void:
	_madeiras_no_forno = 0
	# Anotado já, antes da brasa apagar: quem sair da fase nesses segundos
	# volta com o carvão esperando para ser retirado.
	EstadoMundo.guardar(self, "madeiras_no_forno", 0)
	EstadoMundo.guardar(self, "carbono_pronto", true)

	# A célula só pode ser retirada depois que a brasa apaga: a fornalha
	# continua queimando um tempo antes de o sprite voltar ao forno frio.
	await get_tree().create_timer(BRASA_APOS_CONCLUIR).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_acesa = false
	_carbono_pronto = true
	_atualizar_sprite()
	_atualizar_exclamacao()
	_saltar_carvao()


## O carvão pula para fora da fornalha assim que a brasa apaga: som "POP" e
## um salto com quique — o mesmo instante em que o "!" de retirar aparece.
func _saltar_carvao() -> void:
	if _sprite_carvao == null:
		return
	if _som_carvao and _som_carvao.stream:
		_som_carvao.play()
	_sprite_carvao.position = POSICAO_CARVAO_DENTRO
	_sprite_carvao.visible = true
	var tween := create_tween()
	tween.tween_property(_sprite_carvao, "position",
		POSICAO_CARVAO_FORA + Vector2(0, -PICO_SALTO_CARVAO), 0.16)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite_carvao, "position", POSICAO_CARVAO_FORA, 0.28)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Chamado quando a pessoa aperta E na fornalha com o carvão pronto.
func _retirar_carbono() -> void:
	_carbono_pronto = false
	_guardar_carga()
	_atualizar_exclamacao()
	if _sprite_carvao:
		_sprite_carvao.visible = false
	_resolvida = true
	EstadoMundo.marcar_feito(self)
	# O carvão É a amostra de carbono: vai na mochila e só acende o C no painel
	# quando a Cacau o joga no receptor do laboratório.
	Progresso.coletar_celula("C")
	if Inventario.tela_hud_referencia != null:
		Inventario.tela_hud_referencia.exibir_popup(
			NOME_CARVAO, TEXTURA_CARVAO, DESCRICAO_CARVAO, ID_CARVAO)
