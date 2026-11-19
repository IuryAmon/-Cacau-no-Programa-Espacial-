extends Node2D

# --- CONFIGURAÇÕES DO PLAYER ESPECÍFICAS DESTA CENA (Laboratório / world2) ---
# Antes isso vivia como overrides de "Editable Children" no Player, mas esse
# recurso apaga os overrides (câmera, visibilidade dos HUDs) sempre que você
# desmarca a opção. Aplicando aqui por código, a configuração fica garantida
# mesmo com "Editable Children" desligado.
#
# Esta cena também é onde o cientista se revela como Dr. Chico: na primeira vez
# que a Cacau entra (vinda do world1 pelo laser), a área ColisaoFinalFase roda a
# cutscene da revelação (cutscene_final_fase.gd). Quem chega pelo laser é a
# PassagemLaser que posiciona.

## Quanto a tela leva para clarear na chegada.
@export var duracao_clarear: float = 1.0
## Onde a sala acaba à direita: o fim do chão e da parede do fundo, depois do
## fosso de ventilação. A câmera não passa daqui (senão mostra o vazio). Logo
## antes desta linha fica a SaidaCorredor: andando para fora por ela, a Cacau
## vai para o corredor da torre (ver o HUB, mais abaixo).
@export var fim_da_sala: int = 3564

@onready var _camera: Camera2D = $Player/Camera2D
@onready var _dialog_box_player: Node2D = $Player/dialog_box_player
@onready var _health_hud: CanvasLayer = $Player/CanvasLayer/HealthHUD
@onready var _inventario_hud: CanvasLayer = $Player/InventarioHud
@onready var _cutscene_revelacao: Node = get_node_or_null("ColisaoFinalFase")

func _ready() -> void:
	_camera.limit_left = 142
	_camera.limit_right = fim_da_sala
	_camera.limit_bottom = 250

	_dialog_box_player.visible = false
	_health_hud.visible = false
	_inventario_hud.visible = false

	_montar_conteudo_de_fases()


# --- O HUB DO PLANO v2 ---
#
# O laboratório é a base central: painel do CHONPS ao centro e os acessos às
# fases (a porta da oficina, o fosso de ventilação no piso e, na ponta direita,
# a saída para a torre de gases). Esses nós NÃO nascem por código e NÃO vivem
# mais numa cena separada: eles são filhos diretos do laboratório
# (PainelChonps, PortaOficina, FossoVentilacao, PortaMetalTorre,
# SaidaCorredor). Abra scenes/laboratório_(world_2).tscn e arraste cada um na
# viewport, com o cenário da sala em volta — antes eles estavam dentro de
# hub_fases.tscn e só dava para posicioná-los no vazio, sem ver onde caíam de
# verdade.
#
# Da esquerda para a direita: PortaOficina (a Ala de Pirólise, fase 1), o
# PainelChonps com o ReceptorChonps embaixo, PortaSimulador, o FossoVentilacao
# no piso e, na ponta, a PlacaDestilador, a PortaMetalTorre e a SaidaCorredor.
# A porta da Torre de Lançamento (a porta verde, entre o painel e o simulador)
# saiu em 2026-11-18: daqui não se vai mais ao final do jogo.
#
# A PONTA DIREITA É UMA PAREDE COM PORTA DE METAL, o espelho da ponta esquerda
# (lá, a parede tem a porta de laser embaixo). A parede são tiles da camada
# TileMap/Detalhes — a mesma coluna da esquerda, espelhada e uma linha mais
# alta, para o pé dela encostar no alto da porta — e a PortaMetalTorre
# (componentes/porta_metal_macarico.tscn) fecha o vão: só passa quem a derreter
# com o maçarico. Como o world1 fica à esquerda (pelo laser), a torre de gases
# fica à DIREITA — é o que o mapa do caderno mostra. A SaidaCorredor (uma
# PassagemDeCena, passagem_de_cena.gd) fica 24 px antes de fim_da_sala, por
# trás da porta: derretida a porta, cruzou a linha, a Cacau sai andando e
# chega andando no corredor da torre, pela ponta esquerda dele; na volta ela
# entra andando por aqui, por cima da sucata da porta, e para embaixo da placa
# (a "distancia_entrada" dela é curta de propósito: com a padrão, ela pararia
# em cima do alçapão do fosso, com o botão E aceso). Depois da linha há o
# PisoDaSaida (um chão invisível, fora do quadro, para ela seguir andando
# enquanto a tela apaga) e, no fim dele, a ParedeDireita.
func _montar_conteudo_de_fases() -> void:
	FerramentasPlayer.instalar($Player)

	# O pacote do prólogo: as células de H e O vêm dos cilindros que a Cacau
	# pôs na máquina do laser. Na cutscene da revelação o Dr. Chico as joga no
	# receptor embaixo do painel (ReceptorChonps) e elas acendem ali, na frente
	# dela; o _apresentar_hub() só garante as duas se a cutscene não rodar.
	#
	# O MAÇARICO NÃO É ENTREGUE AQUI. Ele é a recompensa do pátio da Oficina do
	# Carbono: está trancado numa gaiola de vidro e só sai de lá com a queima
	# do acetileno balanceada (ver scripts/puzzle_macarico.gd).
	#
	# Na primeira entrada isso espera a cutscene acabar: quem entrega o H e o O
	# é o Dr. Chico, e ele ainda nem chegou (a cutscene é que o traz).
	if not Progresso.hub_ja_apresentou:
		if EstadoMundo.revelou_dr_chico or _cutscene_revelacao == null:
			_apresentar_hub()
		else:
			_cutscene_revelacao.terminou.connect(_apresentar_hub, CONNECT_ONE_SHOT)

	# Chegou de alguma fase? Nasce na porta correspondente.
	PortaFase.posicionar_player_no_spawn(self)
	FadeTela.clarear_na_chegada(self, duracao_clarear)


func _apresentar_hub() -> void:
	Progresso.hub_ja_apresentou = true
	Progresso.dar_celula("H")
	Progresso.dar_celula("O")
