extends FaseBase

# --- FASE 2: TORRE DE GASES E ESTUFA (Mapa 3 do plano) ---
#
# Fluxo vertical. A novidade estrutural: a MOCHILA DE N₂ é pega na BASE, mas
# trancada por duas fechaduras que exigem as habilidades anteriores — a grade
# (bumerangue) e a chapa soldada (maçarico).
#
#   ① BASE        armário da mochila (2 travas)
#   ② SUBIDA 1    plataformas + chamas (jato de N₂ apaga)
#   ③ SUBIDA 2    correntes de vapor + ventiladores (bumerangue)
#   ④ TUBULAÇÕES  atalhos soldados e válvulas de purga
#   ⑤ ESTUFA      ciclo do nitrogênio + carta de Johanna Döbereiner

@onready var _alavanca: AlvoBumerangue = $Base/AlavancaArmario
@onready var _chapa: ChapaSoldada = $Base/ChapaArmario
@onready var _porta_armario: BlocoAlternavel = $Base/PortaArmario
@onready var _ponto_mochila: Marker2D = $Base/PontoDaMochila

@onready var _ventilador1: AlvoBumerangue = $Subida2/Ventilador1
@onready var _corrente1: CorrenteVapor = $Subida2/Corrente1
@onready var _ventilador2: AlvoBumerangue = $Subida2/Ventilador2
@onready var _corrente2: CorrenteVapor = $Subida2/Corrente2

@onready var _mesa_ciclo: MesaPuzzle = $Estufa/MesaCicloN
@onready var _ponto_celula: Marker2D = $Estufa/PontoDaCelula

var _armario_aberto: bool = false


func _ready() -> void:
	super()

	_ligar_ventilador(_ventilador1, _corrente1)
	_ligar_ventilador(_ventilador2, _corrente2)

	_mesa_ciclo.resolvido.connect(_on_ciclo_resolvido)
	# Puzzle já resolvido mas célula não coletada (morte no meio): ela volta.
	if _mesa_ciclo.ja_resolvida and not Progresso.tem_celula("N"):
		CelulaChonps.criar(self, _ponto_celula.global_position, "N")


func _ligar_ventilador(ventilador: AlvoBumerangue, corrente: CorrenteVapor) -> void:
	if ventilador.ativo:
		corrente.desligar()
		return
	ventilador.mudou.connect(func(ativo: bool) -> void:
		if ativo:
			corrente.desligar())


func _on_ciclo_resolvido() -> void:
	CelulaChonps.criar(self, _ponto_celula.global_position, "N")


func _process(_delta: float) -> void:
	# O armário vigia as duas travas: alavanca puxada E chapa cortada.
	if _armario_aberto:
		return
	var chapa_cortada := not is_instance_valid(_chapa)
	if _alavanca.ativo and chapa_cortada:
		_abrir_armario()


func _abrir_armario() -> void:
	_armario_aberto = true
	_porta_armario.definir_solido(false)

	if Progresso.tem_habilidade("mochila"):
		return

	PickupHabilidade.criar(self, "PickupMochila", _ponto_mochila.global_position, {
		"habilidade": "mochila",
		"rotulo": "MOCHILA PROPULSORA DE N₂",
		"mensagem": "Mochila equipada!\nShift + direção: dash em 8 direções com jato de N₂ (no chão ou no ar).",
		"cor": Color(0.3, 0.6, 0.9),
	})
	Blockout.aviso_flutuante(self, _ponto_mochila.global_position + Vector2(0, -170),
		"As duas travas cederam — o armário abriu!", Color(0.5, 1.0, 0.6))
