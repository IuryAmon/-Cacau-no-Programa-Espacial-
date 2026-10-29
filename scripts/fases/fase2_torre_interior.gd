extends FaseBase

# --- A TORRE DE GASES, POR DENTRO (fase 2) ---
#
# A subida até o telhado, onde está o cilindro de amostra. Oito andares
# empilhados (34 células de largura, 20 fileiras cada); a laje entre dois
# andares tem um buraco, e passar por ele é chegar ao andar de cima:
#
#   Andar0_Terreo      a porta da rua e o PRIMEIRO DEGRAU, alto demais para o
#                      pulo duplo: só sobe quem tem a mochila de N₂ (pulo +
#                      jato). Sem ela, a Cacau comenta (AvisoDegrauAlto).
#   Andar1_Espinhos    o piso inteiro de laser, vigas em escada por cima.
#   Andar2_Serras      a chaminé de serras e a CaixaDasSerras: o bumerangue na
#                      caixa recolhe as serras dela (as do piso continuam).
#   Andar3_Quedas      plataformas laranja que caem (PlataformasQueCaem) e as
#                      válvulas de purga, que recarregam o jato no ar.
#   Andar4_Morcegos    o bando dormindo nos tetos; uma cesta de maçãs.
#   Andar5_Torretas    três torretas quebráveis (um acerto de bumerangue).
#   Andar6_FogoEVapor  chamas (o jato de N₂ apaga: nitrogênio não alimenta o
#                      fogo) e o PuzzleDoVapor: acertar o Ventilador desliga a
#                      corrente de vapor.
#   Andar7_Topo        o laser a meia altura, a plataforma móvel por baixo dos
#                      espinhos e a PortaTelhado, a portinha que sai lá em cima.
#
# Cada andar tem uma bandeira de checkpoint perto de onde se chega nele.
#
# A CÂMERA: a ZonaDaTorre trava o meio na horizontal e só sobe quando a Cacau
# pousa (zona_camera.gd). O PlataformasQueCaem cobre a torre inteira e só
# transforma os tiles laranja (fonte 0).
#
# OS PUZZLES: todo nó cujo nome começa com "Puzzle" junta ALVOS (os
# AlvoBumerangue filhos dele — uma CaixaEletrica também é um) e EFEITOS (os
# outros filhos). Com todos os alvos acesos, cada CorrenteVapor desliga, cada
# Barreira se abre e cada BlocoAlternavel some; um alvo de janela que apaga faz
# o bloco voltar. Para um puzzle novo, é só montar outro grupo "Puzzle...".
#
# COMO EDITAR NO EDITOR: Terreno (lajes, paredes e vigas, tileset das fases —
# a fonte 0, laranja, é a das plataformas que caem), Fundo (o tijolo de dentro
# da fachada), Janelas (as janelas da fachada em escala 3, como nas salas do
# compressor e da destilação: células de 48 px) e Cenario (luminárias e
# enfeites, tileset da cidade). Os componentes de cada andar ficam no grupo
# dele, em Andares/.

## A fala de quando a Cacau, ainda sem a mochila, chega embaixo do degrau.
@export var fala_degrau_alto: String = "cacau_degrau_alto"

var _avisou_do_degrau: bool = false

@onready var _aviso_do_degrau: ReferenceRect = get_node_or_null("Andares/Andar0_Terreo/AvisoDegrauAlto")


func _ready() -> void:
	super._ready()
	_ligar_puzzles(self)


func _process(_delta: float) -> void:
	_vigiar_o_degrau()


## Sem a mochila, pisando embaixo do primeiro degrau: a Cacau diz que é alto
## demais (uma vez por visita).
func _vigiar_o_degrau() -> void:
	if _avisou_do_degrau or _aviso_do_degrau == null or player == null:
		return
	if Progresso.tem_habilidade("mochila"):
		_avisou_do_degrau = true
		return
	if not player.is_on_floor() or Interacao.ocupada():
		return
	var zona := Rect2(_aviso_do_degrau.global_position, _aviso_do_degrau.size)
	if zona.has_point(player.global_position):
		_avisou_do_degrau = true
		DialogicBridge.falar(fala_degrau_alto)


func _ligar_puzzles(no: Node) -> void:
	for filho in no.get_children():
		if String(filho.name).begins_with("Puzzle"):
			_ligar_puzzle(filho)
		else:
			_ligar_puzzles(filho)


func _ligar_puzzle(puzzle: Node) -> void:
	var alvos: Array[AlvoBumerangue] = []
	for filho in puzzle.get_children():
		if filho is AlvoBumerangue:
			alvos.append(filho)
	if alvos.is_empty():
		return
	var aplicar := func(_ativo: bool = false) -> void:
		var todos := alvos.all(func(alvo: AlvoBumerangue) -> bool: return alvo.ativo)
		for filho in puzzle.get_children():
			if filho is CorrenteVapor and todos:
				(filho as CorrenteVapor).desligar()
			elif filho is Barreira and todos:
				(filho as Barreira).abrir_passagem()
			elif filho is BlocoAlternavel:
				(filho as BlocoAlternavel).definir_solido(not todos)
	for alvo in alvos:
		alvo.mudou.connect(aplicar)
	# Alvo que já tinha sido acertado (ele lembra: "persistir") vale de saída.
	aplicar.call()
