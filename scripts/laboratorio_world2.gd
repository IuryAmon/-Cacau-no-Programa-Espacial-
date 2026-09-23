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

@onready var _camera: Camera2D = $Player/Camera2D
@onready var _dialog_box_player: Node2D = $Player/dialog_box_player
@onready var _health_hud: CanvasLayer = $Player/CanvasLayer/HealthHUD
@onready var _inventario_hud: CanvasLayer = $Player/InventarioHud
@onready var _cutscene_revelacao: Node = get_node_or_null("ColisaoFinalFase")
@onready var _painel_chonps: Node2D = get_node_or_null("PainelChonps")

func _ready() -> void:
	_camera.limit_left = 142
	_camera.limit_bottom = 250

	_dialog_box_player.visible = false
	_health_hud.visible = false
	_inventario_hud.visible = false

	_montar_conteudo_de_fases()


# --- O HUB DO PLANO v2 ---
#
# O laboratório é a base central: painel do CHONPS ao centro e os acessos às
# fases (oficina, base da torre, fosso de ventilação no piso e torre de
# lançamento). Esses nós NÃO nascem por código e NÃO vivem mais numa cena
# separada: eles são filhos diretos do laboratório (PainelChonps, PortaOficina,
# PortaTorre, FossoVentilacao, PortaLancamento). Abra
# scenes/laboratório_(world_2).tscn e arraste cada um na viewport, com o
# cenário da sala em volta — antes eles estavam dentro de hub_fases.tscn e só
# dava para posicioná-los no vazio, sem ver onde caíam de verdade.
func _montar_conteudo_de_fases() -> void:
	FerramentasPlayer.instalar($Player)

	# O pacote do prólogo: as células de H e O vêm dos cilindros que a Cacau
	# pôs na máquina do laser. Na cutscene da revelação o Dr. Chico as joga no
	# receptor embaixo do painel (ReceptorChonps) e elas acendem ali, na frente
	# dela; o _apresentar_hub() só garante as duas se a cutscene não rodar.
	#
	# O MAÇARICO NÃO É ENTREGUE AQUI. Ele é a recompensa do pátio da Oficina do
	# Carbono: está trancado numa gaiola de vidro e só sai de lá com a queima
	# do acetileno balanceada (ver scripts/puzzle_macarico.gd). O Dr. Chico só aponta o
	# caminho — as travas do jogo continuam olhando só o Progresso.
	#
	# Isso só acontece depois da revelação: o recado do maçarico é do Dr. Chico,
	# e na primeira entrada ele ainda nem chegou (a cutscene é que o traz).
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
	# Sai em cima do painel, onde quer que ele esteja: a posição vem do nó,
	# para o aviso continuar certo depois de você arrastar o painel.
	var onde_avisar := Vector2(1080, 40)
	if _painel_chonps:
		onde_avisar = _painel_chonps.global_position + Vector2(0, 20)
	Blockout.aviso_flutuante(self, onde_avisar,
		"\"Deixei o maçarico oxídrico trancado no pátio da oficina.\nSe você já controla essa reação, sabe destravar.\"",
		Color(0.5, 1.0, 0.6))
