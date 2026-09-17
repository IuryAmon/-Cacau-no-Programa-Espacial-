class_name FaseBase
extends Node2D

# --- BASE COMUM DAS FASES ---
#
# A geometria de cada fase vive no .tscn (TileMapLayer + nós de componente,
# tudo editável no editor). O script cuida só do que é lógica: anexar as
# ferramentas ao player, travar a câmera e colocar a personagem na porta por
# onde ela chegou.
#
# COMO EDITAR NO EDITOR: os limites da câmera saem do nó LimitesDaCamera
# (um ReferenceRect) — arraste/redimensione ele para mudar até onde a câmera
# acompanha. O ponto de nascimento padrão é o Marker2D "SpawnPadrao".
#
# TESTANDO A FASE: ligue "Testar A Partir Daqui" no Inspector, arraste o nó
# Player para onde quiser dentro da cena e dê o Play — a personagem nasce
# ali, livre, em vez de ser puxada para o SpawnPadrao/porta de entrada.
# Desligue de novo antes de exportar o jogo de verdade.
@export var testar_a_partir_daqui: bool = false

@onready var player: CharacterBody2D = get_node_or_null("Player")


func _ready() -> void:
	_preparar_fase()


func _preparar_fase() -> void:
	if player == null:
		push_warning("%s: falta o nó Player na cena." % name)
		return

	FerramentasPlayer.instalar(player)
	Lanterna.instalar(player)

	# Os limites da fase vêm ANTES de mexer na personagem: o encaixe da câmera
	# (CameraJogador.encaixar) guarda estes limites como os "da fase" para
	# voltar a eles ao sair de um andar/zona/trilho.
	var limites: ReferenceRect = get_node_or_null("LimitesDaCamera")
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if camera and limites:
		camera.limit_left = int(limites.position.x)
		camera.limit_top = int(limites.position.y)
		camera.limit_right = int(limites.position.x + limites.size.x)
		camera.limit_bottom = int(limites.position.y + limites.size.y)

	if not testar_a_partir_daqui:
		var spawn: Marker2D = get_node_or_null("SpawnPadrao")
		if spawn:
			player.global_position = spawn.global_position
		PortaFase.posicionar_player_no_spawn(self)

	# Morreu: volta no último ponto de retorno (bandeira ou sala, o que tiver
	# sido registrado por último). Fica fora do "if" acima para valer também
	# testando com "Testar A Partir Daqui".
	PontoDeRetorno.aplicar(player)

	# Seja qual for o lugar em que ela ficou, a câmera já começa enquadrada nele.
	CameraJogador.encaixar(player)

	FadeTela.clarear_na_chegada(self, 0.5)
