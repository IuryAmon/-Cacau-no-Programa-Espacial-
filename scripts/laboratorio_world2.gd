extends Node2D

# --- CONFIGURAÇÕES DO PLAYER ESPECÍFICAS DESTA CENA (Laboratório / world2) ---
# Antes isso vivia como overrides de "Editable Children" no Player, mas esse
# recurso apaga os overrides (câmera, visibilidade dos HUDs) sempre que você
# desmarca a opção. Aplicando aqui por código, a configuração fica garantida
# mesmo com "Editable Children" desligado.
#
# Esta cena também recebe o corte que vem logo depois da revelação do Dr. Chico,
# no fim do world1: nele a Cacau não entra pela porta do laser, ela já aparece
# ao lado dele, do jeito que os dois pararam na conversa. Quem chega pelo laser
# (indo e voltando depois) é a PassagemLaser que posiciona.

## Quanto a tela leva para clarear no corte que vem da revelação.
@export var duracao_clarear: float = 1.0

@onready var _camera: Camera2D = $Player/Camera2D
@onready var _dialog_box_player: Node2D = $Player/dialog_box_player
@onready var _health_hud: CanvasLayer = $Player/CanvasLayer/HealthHUD
@onready var _inventario_hud: CanvasLayer = $Player/InventarioHud
@onready var _chegada_revelacao: Marker2D = get_node_or_null("ChegadaDaRevelacao")
@onready var _painel_chonps: Node2D = get_node_or_null("PainelChonps")

func _ready() -> void:
	_camera.limit_left = 142
	_camera.limit_bottom = 250

	_dialog_box_player.visible = false
	_health_hud.visible = false
	_inventario_hud.visible = false

	if EstadoMundo.chegando_da_revelacao:
		EstadoMundo.chegando_da_revelacao = false
		_receber_da_revelacao()
		FadeTela.clarear_na_chegada(self, duracao_clarear)

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

	# O pacote do prólogo: ao abrir a porta dos lasers, a personagem recebeu
	# as células de H e O, e elas acendem no painel do CHONPS aqui.
	#
	# O MAÇARICO NÃO É ENTREGUE AQUI. Ele é a recompensa do pátio da Oficina do
	# Carbono: está trancado numa gaiola de vidro e só sai de lá com a queima
	# do acetileno balanceada (ver scripts/puzzle_macarico.gd). O Dr. Chico só aponta o
	# caminho — as travas do jogo continuam olhando só o Progresso.
	if not Progresso.hub_ja_apresentou:
		Progresso.hub_ja_apresentou = true
		Progresso.dar_celula("H")
		Progresso.dar_celula("O")
		# Sai em cima do painel, onde quer que ele esteja: a posição vem do nó,
		# para o aviso continuar certo depois de você arrastar o painel.
		var onde_avisar := Vector2(1080, 40)
		if _painel_chonps:
			onde_avisar = _painel_chonps.global_position + Vector2(0, 20)
		Blockout.aviso_flutuante(self, onde_avisar,
			"H e O acesos no painel do CHONPS.\n\"Deixei o maçarico oxídrico trancado no pátio da oficina.\nSe você já controla essa reação, sabe destravar.\"",
			Color(0.5, 1.0, 0.6))

	# Chegou de alguma fase? Nasce na porta correspondente.
	PortaFase.posicionar_player_no_spawn(self)
	FadeTela.clarear_na_chegada(self, duracao_clarear)


# A cena abre com os dois parados como no fim da fala: o Dr. Chico à esquerda
# dela (é a posição dele aqui na cena) e ela virada para ele.
func _receber_da_revelacao() -> void:
	if _chegada_revelacao == null:
		push_error("Laboratório: falta o nó ChegadaDaRevelacao.")
		return

	var player: Node2D = $Player
	player.global_position = _chegada_revelacao.global_position
	player.velocity = Vector2.ZERO

	var sprite: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.flip_h = true
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
