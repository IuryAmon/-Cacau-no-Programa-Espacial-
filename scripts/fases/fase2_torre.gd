extends FaseBase

# --- FASE 2: A RUA DA TORRE DE GASES (o nitrogênio) ---
#
# A fase do nitrogênio é uma rua ao ar livre, de noite, com três prédios — e
# cada prédio é uma cena (ver missao_nitrogenio.gd, que guarda o que já foi
# feito entre elas). Da esquerda para a direita:
#
#   PortaCompressor   o portão de rolamento do prédio escuro: a SALA DO
#                     COMPRESSOR (fase2_sala_compressor.tscn, o mesmo prédio
#                     por dentro), onde o ar é apertado e gelado até virar
#                     líquido dentro do cilindro. É a cena
#                     componentes/porta_rolamento.tscn: o portão sobe com o som
#                     (o último quadro, a trava, cai no clunk) e o painel ao
#                     lado acende verde; a Cacau entra e ele desce atrás dela.
#                     Na volta ela sai andando para a direita, o lado da
#                     destilação.
#   PortaTorre        a TORRE DE GASES (fase2_torre_interior.tscn): oito andares
#                     de subida até o telhado, onde está o cilindro de amostra.
#   PortaDestilacao   o prédio verde: a SALA DE DESTILAÇÃO
#                     (fase2_sala_destilacao.tscn, montada igual à sala do
#                     compressor), com a MOCHILA DE N₂ (que alcança o primeiro
#                     degrau da torre) e a coluna que separa o nitrogênio do ar.
#
# O ELEVADOR DE CARGA (do telhado para a rua), visto de lado. É PINTADO no
# "Cenario 2": a plataforma com a grade dentro da "Area Do Elevador"
# (Inspector do nó raiz; hoje x 1792 a 1888, y 128 a 192 — pintada no meio do
# caminho só para dar para ver) e, embaixo dela até o chão, o TUBO que a
# empurra (colunas 56 e 58). No jogo, a plataforma vira o nó ElevadorDeCarga
# e o tubo, o TuboDoElevador (ver bloco_de_tiles.gd):
#   - parada, a plataforma fica lá embaixo, com a base no "Chao Do Elevador"
#     (y = 512), e dá para pisar nela (o piso fica "Altura Do Piso" abaixo do
#     topo dela). O tubo fica todo recolhido;
#   - chegando do telhado (MissaoNitrogenio.chegando_de_elevador), a rua abre
#     com a Cacau em cima da plataforma, lá no alto ("Topo Do Percurso", acima
#     do que a câmera mostra), e ela desce até o chão. O tubo vai até onde a
#     plataforma começa (o pintado é repetido para cima) e some por cima
#     conforme ela desce sobre ele, como se recolhesse.
# Por enquanto ele só desce: não há volta pela rua.
#
# O CAMINHO: mochila (destilação) -> torre até o telhado (cilindro vazio) ->
# escada para baixo -> compressor (o puzzle) -> correndo com a amostra gelada
# -> destilação (o cilindro verde de N₂) -> laboratório, pelo corredor.
#
# COM A AMOSTRA NA MÃO (o relógio dela correndo, ContagemDaAmostra), a rua só
# deixa ir para a destilação (ou voltar ao compressor): a saída para o
# corredor e a porta da torre barram, e a Cacau diz por quê
# ("cacau_amostra_pressa"). A saída é barrada pelo próprio script, que entra no
# grupo de quem segura a PassagemDeCena (ver passagem_de_cena.gd).
#
# O CENÁRIO
#   BG/        o céu de camadas da área aberta; o céu e a lua presos na tela,
#              a serra, os morros e as matas em paralaxe (repetem a cada
#              4096 px).
#   Atmosfera  a hora da fase (segue a hora da partida: de noite, com a lua).
#   Postes     os seis postes da rua (um de cada lado do prédio do compressor,
#              um antes da torre, um antes da destilação e dois no terreno
#              vazio do fim da rua), cada um a cena PosteDeLuz
#              (scenes/luz/poste_de_luz.tscn, com a luz dentro): arraste pelo
#              pé, que fica no chão (y = 512).
#   PostesDeLuz  acende sozinho poste PINTADO no TileMap (hoje a rua não tem).
#   Terreno    o chão de grama (topo em y = 512), começando antes da beirada
#              esquerda (x = -448), onde a Cacau chega e sai andando.
#   Cenario    os prédios (tileset da cidade): o prédio escuro do compressor
#              (colunas 6 a 26, com o cano na 27 e a caçamba até a 29; o
#              portão, PortaCompressor, no meio do térreo, onde a fachada tem
#              o vão das colunas 12 a 19), a torre de tijolo (40 a 61, subindo
#              até a fileira -70) e o prédio verde da destilação (75 a 95),
#              perto um do outro: uns 320 px de rua entre a caçamba e a torre
#              e uns 400 px entre a torre e a destilação (com o pilarete e o
#              banco, colunas 63 a 67). Em "Cenario 2", por cima: janelas,
#              painéis e o poço do elevador (os trilhos nas colunas 55 e 59).
#              O prédio do compressor ficou no lugar do antigo prédio de
#              concreto (colunas 9 a 27), que saiu da rua. Depois da garagem
#              (colunas 97 a 108) fica um terreno VAZIO (colunas 109 a 169). A ParedeDireita e o LimitesDaCamera vão
#              até x = 5504.
#              As duas faixas de cornija do prédio do compressor (a do meio,
#              fileira 9, e a do telhado, fileira 2) não são do Cenario: ficam
#              na camada Lajes (abaixo).
#   Lajes      as lajes em que dá para subir, com colisão: as duas faixas do
#              prédio do compressor, na faixa VAZADA do tileset das fases (a
#              alternativa 1) — a Cacau passa por baixo pulando, pisa em cima e
#              desce com S + espaço. Ficam fora do Terreno porque ele é só o
#              chão de grama. As faixas giradas das quinas da torre e dos
#              trilhos do elevador continuam no Cenario, sem colisão: com
#              colisão, a torre virava uma escada por fora.
#              Terreno, Cenario e Cenario 2 usam rendering_quadrant_size = 256
#              (a rua inteira num bloco só). Com o padrão de 16, cada bloco de
#              16 tiles é desenhado à parte e, longe da origem (x = 4608, no
#              prédio da direita), o arredondamento abria às vezes uma fresta
#              de 1 px entre dois blocos, deixando ver o céu atrás.
#   JanelasAcesas  acende sozinho, à noite, toda janela pintada nos prédios
#              (scripts/luz/janelas_acesas.gd): o vidro amarelo da casa acesa
#              lá dentro e a luz que sai dele. Fica logo depois do Cenario na
#              árvore, para as janelas ficarem atrás dos postes e da Cacau.
#   Paredes/  os dois corpos invisíveis das pontas.
#   PassagemCorredor  a ponta esquerda, sem porta: andando para fora, a cena
#              troca para o fundo do corredor da torre (corredor_torre.tscn).
#
# Para mexer nas portas: arraste o nó pelo meio. As tags ligam cada uma ao par
# dela na outra cena e não precisam mudar.

## A Cacau, quando a amostra gelada não pode esperar.
@export var fala_amostra_com_pressa: String = "cacau_amostra_pressa"

@export_group("Elevador")
## Onde a plataforma está pintada no "Cenario 2" (retângulo do mundo, em px:
## x, y, largura, altura). Toda célula com o CENTRO aqui dentro é dela; o que
## estiver pintado embaixo, na mesma largura, até o "Chao Do Elevador", é o tubo.
@export var area_do_elevador := Rect2(1792, 128, 96, 64)
## A camada em que a plataforma e o tubo estão pintados.
@export var camada_do_elevador: NodePath = ^"Cenario/Cenario 2"
## Até onde a BASE da plataforma desce (y do mundo): o chão da rua.
@export var chao_do_elevador: float = 512.0
## De onde ela vem descendo quando a Cacau chega do telhado: o TOPO da
## plataforma (y do mundo). A câmera não sobe além de y = -20, então ela entra
## pelo alto da tela.
@export var topo_do_percurso: float = -96.0
## Do topo da plataforma até onde a Cacau pisa (px).
@export var altura_do_piso: float = 32.0
## Quanto tempo a descida leva (s).
@export var duracao_da_descida: float = 3.0

@onready var _porta_torre: Area2D = get_node_or_null("PortaTorre")

var _plataforma: BlocoDeTiles = null
var _tubo: BlocoDeTiles = null


func _ready() -> void:
	var de_elevador := MissaoNitrogenio.chegando_de_elevador
	MissaoNitrogenio.chegando_de_elevador = false
	add_to_group(PassagemDeCena.GRUPO_DE_QUEM_SEGURA)
	super._ready()
	_montar_elevador()
	if de_elevador:
		_chegar_de_elevador()
	_atualizar_travas()


func _process(_delta: float) -> void:
	_atualizar_travas()
	_vigiar_porta_da_torre()


func _atualizar_travas() -> void:
	var com_amostra := MissaoNitrogenio.carregando_amostra()
	if _porta_torre and "interativa" in _porta_torre:
		# Modo dev (ver modo_dev.gd): a porta abre mesmo com a amostra.
		_porta_torre.interativa = not com_amostra or ModoDev.ativo


## Com a amostra, a porta da torre não abre: o E em frente a ela vira a fala.
func _vigiar_porta_da_torre() -> void:
	if _porta_torre == null or player == null or not MissaoNitrogenio.carregando_amostra() \
			or ModoDev.ativo:
		return
	# Interacao.pediu() queima o toque, então fica por último.
	if _porta_torre.overlaps_body(player) and Interacao.pediu():
		DialogicBridge.falar(fala_amostra_com_pressa)


# --- A SAÍDA PARA O CORREDOR (ver passagem_de_cena.gd) ---

func segura_a_saida() -> bool:
	return MissaoNitrogenio.carregando_amostra()


func ao_barrar_a_saida() -> void:
	DialogicBridge.falar(fala_amostra_com_pressa)


# --- O ELEVADOR DE CARGA ---

## Tira a plataforma e o tubo do "Cenario 2" (ver bloco_de_tiles.gd), põe o
## piso em que se pisa e deixa a plataforma parada lá embaixo.
func _montar_elevador() -> void:
	var camada := get_node_or_null(camada_do_elevador) as TileMapLayer
	if camada == null:
		return
	# O tubo antes: assim a plataforma é desenhada por cima dele.
	var area_do_tubo := Rect2(area_do_elevador.position.x, area_do_elevador.end.y,
		area_do_elevador.size.x, chao_do_elevador - area_do_elevador.end.y)
	_tubo = BlocoDeTiles.recortar(self, "TuboDoElevador", [camada], area_do_tubo)
	_tubo.estender_colunas_para_cima(minf(topo_do_percurso + area_do_elevador.size.y,
		area_do_elevador.end.y))
	_plataforma = BlocoDeTiles.recortar(self, "ElevadorDeCarga", [camada], area_do_elevador)
	if _plataforma.celulas() == 0:
		push_warning("Fase2Torre: nenhum tile do elevador dentro da Area Do Elevador.")

	# O piso: só segura por cima (dá para subir nele pulando de baixo).
	var piso := StaticBody2D.new()
	piso.name = "Piso"
	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = Vector2(area_do_elevador.size.x, 8.0)
	forma.shape = retangulo
	forma.one_way_collision = true
	forma.position = Vector2(area_do_elevador.get_center().x,
		area_do_elevador.position.y + altura_do_piso + retangulo.size.y * 0.5)
	piso.add_child(forma)
	_plataforma.add_child(piso)

	_por_elevador_em(_deslocamento_embaixo())


## A rua abrindo com a Cacau em cima da plataforma, lá no alto: ela desce até
## o chão e o controle volta.
func _chegar_de_elevador() -> void:
	if _plataforma == null or player == null:
		return
	var cacau := player
	var em_cima := topo_do_percurso - area_do_elevador.position.y
	var embaixo := _deslocamento_embaixo()
	cacau.velocity = Vector2.ZERO
	cacau.pode_se_mover = false
	cacau.animacao_controlada_externamente = true
	var sprite := cacau.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")
	_passo_da_chegada(em_cima, cacau)
	CameraJogador.encaixar(cacau)
	# Morrer antes de qualquer bandeira renasce em pé na plataforma, já no chão.
	PontoDeRetorno.registrar(_plataforma, _onde_ela_fica(cacau, embaixo))

	# Um respiro com a tela clareando antes de a plataforma aparecer.
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	var viagem := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	viagem.tween_method(_passo_da_chegada.bind(cacau), em_cima, embaixo, duracao_da_descida)
	await viagem.finished
	if not is_inside_tree() or not is_instance_valid(cacau):
		return
	cacau.animacao_controlada_externamente = false
	cacau.pode_se_mover = true


## A plataforma "d" px abaixo de onde foi pintada, com ela de pé no piso.
func _passo_da_chegada(d: float, cacau: CharacterBody2D) -> void:
	_por_elevador_em(d)
	cacau.global_position = _onde_ela_fica(cacau, d)


func _por_elevador_em(d: float) -> void:
	_plataforma.deslocamento = d
	# O tubo só aparece da base da plataforma para baixo.
	_tubo.cortar_acima_de(area_do_elevador.end.y + d)


## Parada: a base da plataforma no chão.
func _deslocamento_embaixo() -> float:
	return chao_do_elevador - area_do_elevador.end.y


## Onde fica a ORIGEM da Cacau com os pés no piso da plataforma, no meio dela.
func _onde_ela_fica(cacau: CharacterBody2D, d: float) -> Vector2:
	var piso := area_do_elevador.position.y + altura_do_piso + d
	var dos_pes: float = cacau.global_position.y - cacau.altura_dos_pes()
	return Vector2(area_do_elevador.get_center().x, piso + dos_pes)


## O elevador da rua: a plataforma e o tubo (para o teste e o modo dev).
func plataforma_do_elevador() -> BlocoDeTiles:
	return _plataforma


func tubo_do_elevador() -> BlocoDeTiles:
	return _tubo
