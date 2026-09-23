class_name ReceptorChonps
extends Node2D

# --- RECEPTOR DE AMOSTRAS DO PAINEL CHONPS ---
#
# O baú embaixo do painel do laboratório, onde a Cacau entrega os elementos.
# Funciona como a caixa de envio do Stardew Valley: chegou perto com uma
# amostra na mochila, o baú abre (a luz fica verde e a tampa levanta) e pede
# o botão; apertou E (□ no controle), a amostra pula da mão dela num arco para
# dentro do baú, e um brilho sobe do baú até a letra do elemento, que acende
# no painel. Ela se afastou ou acabaram as amostras, o baú fecha. O que entra
# não sai mais: não existe "pegar de volta".
#
# Com mais de uma amostra na mochila, cada toque entrega uma, na ordem do
# CHONPS. Sem nenhuma, o baú fica fechado e nem pede o botão (e o E fica livre
# para o Dr. Chico, que patrulha aqui do lado).
#
# O Dr. Chico usa a mesma entrada na cutscene da revelação, para jogar lá
# dentro o H e o O do prólogo (ver "receber" e cutscene_final_fase.gd): o baú
# abre para ele do mesmo jeito.
#
# COMO EDITAR NO EDITOR:
#   Corpo/Sprite -> o baú. É um AnimatedSprite2D com a animação "abrir", que
#                   vai do fechado ao aberto e NÃO repete: abrir é tocar a
#                   animação (ela para no último quadro e o baú fica aberto),
#                   fechar é tocá-la de trás para a frente. Hoje os quadros
#                   são os do Retro Chest (Pixel Chest Pack); para a arte
#                   final é só trocar os quadros da animação. A velocidade de
#                   abrir e fechar é o FPS dela. O tamanho é a escala do
#                   Sprite, com a base do desenho no chão (y = 0).
#   Boca         -> a borda da frente do baú aberto, onde a amostra mergulha.
#                   Ela é uma MÁSCARA: tudo o que passa abaixo desta linha
#                   some, e é isso que faz a amostra parecer entrar lá dentro.
#                   Mudou a arte ou a escala, acerte a altura dela na borda.
#   Faiscas      -> o estouro na cor do elemento quando a amostra cai lá dentro
#   AreaInteracao -> de quão longe o E funciona
#   Dica         -> o desenho do botão (E / □), que acende quando ela chega
#                   perto com alguma amostra. Fica baixo, logo acima do baú,
#                   para não cobrir o painel. (Sem balão "!": o Dr. Chico, que
#                   patrulha ao lado, já usa o dele. Se quiser o balão, é só
#                   pôr uma ExclamacaoAnimada filha do baú — o script a acende
#                   junto.)
#   painel (Inspector) -> o PainelChonps que acende. Sem ele a letra acende
#                   do mesmo jeito, só sem o brilho subindo.
#
# A origem do nó é o chão, no meio do baú: é só pousá-lo no piso.

## Uma amostra terminou de entrar e a letra dela já acendeu no painel.
signal amostra_recebida(letra: String)

const CENA := "res://scenes/fases/componentes/receptor_chonps.tscn"

## A animação do Corpo/Sprite que vai do baú fechado ao aberto.
const ANIM_ABRIR := &"abrir"

## O PainelChonps cuja letra acende a cada entrega.
@export var painel: NodePath

@export_group("Tampa")
## Quanto o baú segue aberto depois que uma amostra cai lá dentro, antes de
## fechar (se ninguém mais for entregar nada). É o que o deixa aberto entre o
## H e o O que o Dr. Chico joga na cutscene.
@export var segurar_aberto: float = 0.8

@export_group("Arremesso")
## Quanto o voo da amostra, da mão até a boca do baú, leva.
@export var duracao_voo: float = 0.55
## Quanto o arco sobe acima da linha reta entre a mão e a boca.
@export var altura_arco: float = 64.0
## Altura da amostra no ar, em pixels, seja qual for o tamanho da arte dela.
@export var altura_amostra: float = 28.0
## Onde a amostra termina o arco, acima da borda da Boca, antes de mergulhar.
@export var altura_sobre_a_boca: float = 14.0
## De onde a amostra sai da Cacau, a partir da origem da personagem (acima da
## cabeça, como quem ergue o item antes de jogar).
@export var saida_da_cacau: Vector2 = Vector2(0, -52)

@export_group("Painel")
## Quanto o brilho leva do baú até a letra do painel.
@export var duracao_brilho: float = 0.6

var _jogador_perto: bool = false
var _player: Node2D = null
## Uma amostra está no ar ou entrando: o baú não recebe outra até acabar.
var _ocupado: bool = false
## Ela está perto, com amostra, e nada na tela segurando o E.
var _convidando: bool = false
var _aviso_visivel: bool = false
## O baú está aberto (ou abrindo). Quem decide é o _process.
var _aberto: bool = false
## Segundos que ele ainda segura aberto depois da última amostra.
var _segurando: float = 0.0

static var _textura_brilho: GradientTexture2D = null

@onready var _corpo: Node2D = $Corpo
@onready var _sprite: AnimatedSprite2D = $Corpo/Sprite
@onready var _boca: Node2D = $Boca
@onready var _faiscas: CPUParticles2D = $Faiscas
@onready var _area: Area2D = $AreaInteracao
@onready var _exclamacao: AnimatedSprite2D = get_node_or_null("ExclamacaoAnimada")
@onready var _dica: AnimatedSprite2D = get_node_or_null("Dica")
@onready var _som_pop: AudioStreamPlayer2D = $SomPop
@onready var _som_tampa: AudioStreamPlayer2D = $SomTampa
@onready var _som_acende: AudioStreamPlayer2D = $SomAcende


static func criar(pai: Node, pos_chao: Vector2, config: Dictionary = {}) -> ReceptorChonps:
	var receptor: ReceptorChonps = load(CENA).instantiate()
	receptor.name = "ReceptorChonps"
	receptor.position = pos_chao
	for chave in config:
		receptor.set(chave, config[chave])
	Blockout.adicionar(pai, receptor)
	return receptor


func _ready() -> void:
	# A máscara da Boca: um retângulo enorme que termina na linha dela. Com o
	# clip_children ligado ele não aparece — só recorta as amostras (filhas da
	# Boca), que somem ao passar para baixo da borda da frente do baú.
	_boca.draw.connect(func() -> void:
		_boca.draw_rect(Rect2(-2000.0, -2000.0, 4000.0, 2000.0), Color.WHITE))
	_boca.queue_redraw()

	if _exclamacao:
		_exclamacao.visible = false
	if _dica:
		_dica.visible = false

	# Nasce fechado: parado no primeiro quadro da animação de abrir.
	_sprite.animation = ANIM_ABRIR
	_sprite.stop()
	_sprite.frame = 0
	_sprite.animation_finished.connect(_ao_terminar_animacao)

	# Pergunta pelo E antes de quem estiver em volta (o Dr. Chico patrulha
	# aqui do lado): com uma amostra na mão, o toque é da entrega. Sem amostra
	# o baú nem pergunta, e o toque segue para ele.
	process_priority = -1

	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	var convidar := _jogador_perto and not _ocupado and not Interacao.ocupada() \
		and not Progresso.amostras_na_mao().is_empty()
	if convidar != _convidando:
		_convidando = convidar
		_mostrar_aviso(convidar)

	# Aberto enquanto há o que receber: ela chegou com amostra, uma amostra
	# está entrando, ou acabou de entrar uma (e pode vir outra logo atrás).
	if _segurando > 0.0:
		_segurando -= delta
	var querer_aberto := _convidando or _ocupado or _segurando > 0.0
	if querer_aberto != _aberto:
		if querer_aberto:
			_abrir()
		else:
			_fechar()

	# Interacao.pediu() queima o toque de E, então fica por ÚLTIMO.
	if _convidando and Interacao.pediu():
		_entregar_da_cacau()


# ─────────────────────────────────────────────
#  A entrega
# ─────────────────────────────────────────────

func _entregar_da_cacau() -> void:
	var na_mao := Progresso.amostras_na_mao()
	if na_mao.is_empty() or _player == null:
		return
	var letra: String = na_mao[0]

	# Sai da mochila na hora do arremesso: dali em diante ela está no ar, e o
	# que entra no baú não volta.
	Inventario.remover_item(AmostraChonps.id_no_inventario(letra))

	# Ela se vira para o baú antes de jogar.
	var sprite := _player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.flip_h = global_position.x < _player.global_position.x

	await receber(letra, _player.global_position + saida_da_cacau, true)


## Faz a amostra de "letra" pular de "origem" (posição no mundo) para dentro
## do baú e acende a letra no painel. Quem chama pode dar "await": devolve
## quando a letra já acendeu.
##
## "com_aviso" liga o letreiro flutuante com a contagem ("3/6") — a entrega da
## Cacau usa; a do Dr. Chico na cutscene, que ele mesmo narra, não.
func receber(letra: String, origem: Vector2, com_aviso: bool = false) -> void:
	_ocupado = true
	_convidando = false
	_mostrar_aviso(false)
	# Já aberto quando ela chega perto; na cutscene abre agora, enquanto a
	# amostra ainda está no ar.
	_abrir()

	var amostra := Sprite2D.new()
	amostra.texture = AmostraChonps.textura(letra)
	var escala := altura_amostra / maxf(float(amostra.texture.get_height()), 1.0)
	_boca.add_child(amostra)
	amostra.global_position = origem
	amostra.scale = Vector2.ZERO
	if _som_pop.stream:
		_som_pop.play()

	# 1. PULA DA MÃO: surge crescendo com um estalo e dá um impulso para cima.
	var pulo := create_tween().set_parallel(true)
	pulo.tween_property(amostra, "scale", Vector2.ONE * escala, 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulo.tween_property(amostra, "global_position:y", origem.y - 12.0, 0.16)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await pulo.finished
	if not _ainda_na_cena(amostra):
		return

	# 2. O ARCO: dá uma volta no ar, no sentido em que está indo.
	var de := amostra.global_position
	var ate := _boca.global_position + Vector2(0.0, -altura_sobre_a_boca)
	var sentido := 1.0 if ate.x >= de.x else -1.0
	var voo := create_tween()
	voo.tween_method(_posicionar_no_arco.bind(amostra, de, ate, TAU * sentido),
		0.0, 1.0, duracao_voo)
	await voo.finished
	if not _ainda_na_cena(amostra):
		return

	# Só mergulha com a tampa em cima: se o baú ainda está abrindo, a amostra
	# espera o último quadro.
	if _sprite.is_playing():
		await _sprite.animation_finished
		if not _ainda_na_cena(amostra):
			return

	# 3. O MERGULHO: desce pela boca e a máscara da borda a engole.
	var mergulho := create_tween().set_parallel(true)
	mergulho.tween_property(amostra, "position:y", amostra.position.y + altura_sobre_a_boca + altura_amostra, 0.14)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	mergulho.tween_property(amostra, "scale", Vector2.ONE * escala * 0.8, 0.14)
	await mergulho.finished
	amostra.queue_free()

	# 4. CAIU LÁ DENTRO.
	_caiu_dentro(letra)

	# 5. O BRILHO SOBE até a letra do painel, e ela acende.
	await _subir_brilho(letra)
	if not is_inside_tree():
		return
	Progresso.dar_celula(letra)
	if com_aviso:
		Blockout.aviso_flutuante(get_parent(), global_position + Vector2(0, -40),
			"%s NO PAINEL · %d/%d" % [AmostraChonps.nome(letra).to_upper(),
				Progresso.contar_celulas(), Progresso.CELULAS.size()],
			AmostraChonps.cor(letra))

	# O baú segue aberto mais um pouco (pode vir outra logo atrás) e só fecha
	# depois, sozinho, se ninguém mais entregar nada.
	_segurando = segurar_aberto
	_ocupado = false
	amostra_recebida.emit(letra)


func _posicionar_no_arco(t: float, amostra: Sprite2D, de: Vector2, ate: Vector2, giro: float) -> void:
	amostra.global_position = de.lerp(ate, t) + Vector2(0.0, -altura_arco * 4.0 * t * (1.0 - t))
	amostra.rotation = giro * ease(t, -1.6)


## A amostra bateu no fundo: o baú dá um tranco e volta, com faíscas na cor
## do elemento saindo pela boca.
func _caiu_dentro(letra: String) -> void:
	if _som_tampa.stream:
		_som_tampa.pitch_scale = 1.15
		_som_tampa.play()

	_faiscas.color = AmostraChonps.cor(letra)
	_faiscas.restart()

	_corpo.scale = Vector2(1.08, 0.9)
	var mola := create_tween()
	mola.tween_property(_corpo, "scale", Vector2.ONE, 0.45)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## O brilho sai da boca do baú e sobe, fazendo uma curva, até a letra no
## painel. Devolve quando chega (é aí que a letra acende).
func _subir_brilho(letra: String) -> void:
	var no_painel := get_node_or_null(painel) as PainelChonps
	if no_painel == null:
		return

	var orbe := _criar_orbe(AmostraChonps.cor(letra))
	get_parent().add_child(orbe)
	var de := _boca.global_position + Vector2(0, -6)
	var ate := no_painel.posicao_da_letra(letra)
	orbe.global_position = de

	var subida := create_tween()
	subida.tween_method(_posicionar_orbe.bind(orbe, de, ate), 0.0, 1.0, duracao_brilho)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await subida.finished
	if not is_instance_valid(orbe):
		return

	# Estoura em cima da letra e some.
	if _som_acende.stream:
		_som_acende.play()
	var rastro := orbe.get_node_or_null("Rastro") as CPUParticles2D
	if rastro:
		rastro.emitting = false
	var estouro := orbe.create_tween().set_parallel(true)
	estouro.tween_property(orbe, "scale", Vector2.ONE * 2.6, 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	estouro.tween_property(orbe, "modulate:a", 0.0, 0.3)
	estouro.chain().tween_callback(orbe.queue_free)


func _posicionar_orbe(t: float, orbe: Node2D, de: Vector2, ate: Vector2) -> void:
	if not is_instance_valid(orbe):
		return
	# Barriga para o lado de onde a letra está: fica uma curva, e não uma reta.
	var lado := 1.0 if ate.x >= de.x else -1.0
	orbe.global_position = de.lerp(ate, t) + Vector2(sin(t * PI) * 26.0 * lado, 0.0)


func _criar_orbe(cor: Color) -> Node2D:
	var orbe := Node2D.new()
	orbe.name = "BrilhoAmostra"
	orbe.z_index = 20

	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var halo := Sprite2D.new()
	halo.texture = _brilho()
	halo.modulate = cor
	halo.scale = Vector2.ONE * 1.1
	halo.material = soma
	orbe.add_child(halo)

	var miolo := Sprite2D.new()
	miolo.texture = _brilho()
	miolo.scale = Vector2.ONE * 0.4
	miolo.material = soma
	orbe.add_child(miolo)

	var rastro := CPUParticles2D.new()
	rastro.name = "Rastro"
	rastro.amount = 28
	rastro.lifetime = 0.4
	rastro.local_coords = false
	rastro.direction = Vector2(0, 1)
	rastro.spread = 180.0
	rastro.gravity = Vector2.ZERO
	rastro.initial_velocity_min = 4.0
	rastro.initial_velocity_max = 18.0
	rastro.scale_amount_min = 1.5
	rastro.scale_amount_max = 3.0
	rastro.color = cor
	var some := Gradient.new()
	some.set_color(0, Color(1, 1, 1, 1))
	some.set_color(1, Color(1, 1, 1, 0))
	rastro.color_ramp = some
	orbe.add_child(rastro)
	return orbe


static func _brilho() -> GradientTexture2D:
	if _textura_brilho == null:
		var gradiente := Gradient.new()
		gradiente.set_color(0, Color(1, 1, 1, 1))
		gradiente.set_color(1, Color(1, 1, 1, 0))
		_textura_brilho = GradientTexture2D.new()
		_textura_brilho.gradient = gradiente
		_textura_brilho.width = 32
		_textura_brilho.height = 32
		_textura_brilho.fill = GradientTexture2D.FILL_RADIAL
		_textura_brilho.fill_from = Vector2(0.5, 0.5)
		_textura_brilho.fill_to = Vector2(1.0, 0.5)
	return _textura_brilho


## O baú (ou a cena) pode sumir no meio de um tween — trocar de cena pela
## porta do lado, por exemplo. Aí a entrega simplesmente não termina.
func _ainda_na_cena(amostra: Node) -> bool:
	if is_inside_tree() and is_instance_valid(amostra):
		return true
	_ocupado = false
	return false


# ─────────────────────────────────────────────
#  Tampa
# ─────────────────────────────────────────────

## Toca a animação de abrir; como ela não repete, para no último quadro e o
## baú fica aberto. Chamado no meio de um fechamento, volta dali mesmo.
func _abrir() -> void:
	if _aberto:
		return
	_aberto = true
	_sprite.play(ANIM_ABRIR)


## A mesma animação de trás para a frente, até o baú fechado.
func _fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	_sprite.play_backwards(ANIM_ABRIR)


## Fechou de vez (chegou ao primeiro quadro tocando para trás): a tampa bate.
func _ao_terminar_animacao() -> void:
	if not _aberto and _sprite.frame == 0 and _som_tampa.stream:
		_som_tampa.pitch_scale = 0.85
		_som_tampa.play()


# ─────────────────────────────────────────────
#  Aviso e proximidade
# ─────────────────────────────────────────────

func _mostrar_aviso(mostrar: bool) -> void:
	if mostrar == _aviso_visivel:
		return
	_aviso_visivel = mostrar
	if _dica:
		_dica.visible = mostrar
		if mostrar and _dica.has_method("reiniciar"):
			_dica.reiniciar()
	if _exclamacao:
		if mostrar:
			PopupFX.mostrar(_exclamacao)
		else:
			PopupFX.esconder(_exclamacao)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_jogador_perto = true
		_player = body


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_jogador_perto = false
