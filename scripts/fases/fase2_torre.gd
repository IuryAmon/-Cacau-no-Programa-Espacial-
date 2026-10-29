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
#   ElevadorDeCarga   o elevador de carga que sobe pelo poço na fachada da torre
#                     até o telhado (fase2_telhado.tscn). A cabine começa
#                     PARADA lá em cima: o poço aqui embaixo fica vazio, e o E
#                     nele só dá a fala "cacau_elevador_parado", até a Cacau
#                     subir a torre pela escada e descer nela. Daí em diante a
#                     cabine fica no andar em que ela a deixou
#                     (MissaoNitrogenio.posicionar_cabine) — é o atalho de ida
#                     e volta.
#   PortaDestilacao   o prédio verde: a SALA DE DESTILAÇÃO
#                     (fase2_sala_destilacao.tscn, montada igual à sala do
#                     compressor), com a MOCHILA DE N₂ (que alcança o primeiro
#                     degrau da torre) e a coluna que separa o nitrogênio do ar.
#
# O CAMINHO: mochila (destilação) -> torre até o telhado (cilindro vazio) ->
# elevador para baixo -> compressor (o puzzle) -> correndo com a amostra gelada
# -> destilação (o cilindro verde de N₂) -> laboratório, pelo corredor.
#
# COM A AMOSTRA NA MÃO (o relógio dela correndo, ContagemDaAmostra), a rua só
# deixa ir para a destilação (ou voltar ao compressor): a saída para o
# corredor, a porta da torre e o elevador barram, e a Cacau diz por quê
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
#              o vão das colunas 12 a 19), a torre de tijolo (48 a 69, subindo
#              até a fileira -70) e o prédio verde da destilação (88 a 108),
#              com uns 600 px de rua entre um e outro. Em "Cenario 2", por
#              cima: janelas, painéis e o poço do elevador (os trilhos nas
#              colunas 63 e 67). O prédio do compressor ficou no lugar do
#              antigo prédio de concreto (colunas 9 a 27), que saiu da rua.
#              Depois da garagem (colunas 110 a 121) fica um terreno VAZIO
#              (colunas 122 a 169). A ParedeDireita e o LimitesDaCamera vão
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
# Para mexer nas portas e no elevador: arraste o nó (a porta pelo meio, o
# elevador pelo chão no meio da cabine). As tags ligam cada um ao par dele na
# outra cena e não precisam mudar.

## A Cacau, quando a amostra gelada não pode esperar.
@export var fala_amostra_com_pressa: String = "cacau_amostra_pressa"
## A Cacau, apertando o E no poço vazio: a cabine está lá no telhado.
@export var fala_elevador_parado: String = "cacau_elevador_parado"

@onready var _elevador: ElevadorFase = get_node_or_null("ElevadorDeCarga")
@onready var _porta_torre: Area2D = get_node_or_null("PortaTorre")


func _ready() -> void:
	add_to_group(PassagemDeCena.GRUPO_DE_QUEM_SEGURA)
	super._ready()
	MissaoNitrogenio.posicionar_cabine(_elevador, false)
	_atualizar_travas()


func _process(_delta: float) -> void:
	_atualizar_travas()
	_vigiar_porta_da_torre()


func _atualizar_travas() -> void:
	var com_amostra := MissaoNitrogenio.carregando_amostra()
	if _elevador:
		# Sem a cabine aqui, o elevador já não parte (cabine_aqui): a fala é a
		# do poço vazio — a não ser que a amostra nem dê tempo de tentar.
		_elevador.liberado = not com_amostra
		_elevador.fala_trancada = fala_amostra_com_pressa if com_amostra else fala_elevador_parado
	if _porta_torre and "interativa" in _porta_torre:
		# Modo dev (ver modo_dev.gd): a porta abre mesmo com a amostra.
		_porta_torre.interativa = not com_amostra or ModoDev.ativo


## Com a amostra, a porta da torre não abre: o W em frente a ela vira a fala.
func _vigiar_porta_da_torre() -> void:
	if _porta_torre == null or player == null or not MissaoNitrogenio.carregando_amostra() \
			or ModoDev.ativo:
		return
	if Interacao.ocupada() or not Input.is_action_just_pressed("ui_up"):
		return
	if _porta_torre.overlaps_body(player):
		DialogicBridge.falar(fala_amostra_com_pressa)


# --- A SAÍDA PARA O CORREDOR (ver passagem_de_cena.gd) ---

func segura_a_saida() -> bool:
	return MissaoNitrogenio.carregando_amostra()


func ao_barrar_a_saida() -> void:
	DialogicBridge.falar(fala_amostra_com_pressa)
