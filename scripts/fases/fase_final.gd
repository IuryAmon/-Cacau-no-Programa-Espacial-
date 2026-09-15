extends FaseBase

# --- FINAL: TORRE DE LANÇAMENTO (Mapa 5 do plano) ---
#
# Fase-síntese sem mecânica nova: uma seção por habilidade, com contagem
# regressiva diegética (T-6 ... T-1).
#
#   T-6 PORTÃO      painel CHONPS completo + pisos eletrificados (botas)
#   T-5 GUINDASTES  interruptores à distância (bumerangue)
#   T-4 TRAVAS      chapas soldadas (maçarico oxídrico)
#   T-3 VÃOS        vãos da estrutura (mochila de N₂)
#   T-2 GALERIA     galeria interna escura (lanterna de foco)
#   T-1 PLATAFORMA  checagem de suporte de vida: purificador de CO₂ (LiOH)

@onready var _portao: BlocoAlternavel = $Portao/PortaoCHONPS
@onready var _placa_portao: Label = $Portao/PlacaPortao
@onready var _guindastes: Node2D = $Guindastes/Conjuntos
@onready var _sombra_galeria: ColorRect = $Galeria/SombraGaleria
@onready var _mesa_purificador: MesaPuzzle = $Plataforma/MesaPurificador
@onready var _capsula: Node2D = $Plataforma/Capsula

var _lanterna: Lanterna = null


func _ready() -> void:
	super()

	# O portão só cede com o painel completo — a última fechadura química.
	var completo := Progresso.todas_as_celulas()
	_portao.definir_solido(not completo)
	_placa_portao.visible = not completo
	if not completo:
		_placa_portao.text = "O portão pede o painel CHONPS completo:\n%d/6 células." % Progresso.contar_celulas()

	# Cada guindaste estende a própria lança quando o alvo é atingido.
	for conjunto in _guindastes.get_children():
		var alvo: AlvoBumerangue = conjunto.get_node_or_null("Alvo")
		var lanca: BlocoAlternavel = conjunto.get_node_or_null("Lanca")
		if alvo == null or lanca == null:
			continue
		lanca.definir_solido(alvo.ativo)
		alvo.mudou.connect(func(ativo: bool) -> void:
			if ativo:
				lanca.definir_solido(true))

	# A cápsula só aparece depois da checagem de suporte de vida.
	_capsula.visible = _mesa_purificador.ja_resolvida
	_mesa_purificador.resolvido.connect(_on_purificador_resolvido)

	# Quem visitou a ala de lítio da oficina chega com a equação na mão.
	if Progresso.visitou_ala_litio and _mesa_purificador.puzzle_config.has("subtitulo"):
		_mesa_purificador.puzzle_config["subtitulo"] = \
			"Você viu a produção de lítio na ala da oficina — a equação já é conhecida. Monte o purificador."


func _on_purificador_resolvido() -> void:
	_capsula.visible = true
	Blockout.aviso_flutuante(self, _capsula.global_position + Vector2(0, -180),
		"Checagem de suporte de vida CONCLUÍDA.\nA cápsula está liberada para embarque!", Color(0.5, 1.0, 0.6))


func _process(_delta: float) -> void:
	# A galeria escura responde à LANTERNA trazida do subsolo: feixe aceso,
	# dá para ver. (O sinalizador saiu do fluxo do jogo junto com a
	# reformulação da fase 3 — a lanterna assumiu o papel de luz.)
	if _lanterna == null and player:
		_lanterna = player.get_node_or_null("Lanterna")
	var iluminado: bool = _lanterna != null and _lanterna.acesa()
	_sombra_galeria.color.a = 0.25 if iluminado else 0.93
