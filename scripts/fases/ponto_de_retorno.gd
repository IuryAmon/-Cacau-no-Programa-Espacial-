class_name PontoDeRetorno
extends RefCounted

# --- PONTO DE RETORNO (para onde a personagem volta quando morre) ---
#
# É a ÚNICA memória de respawn do jogo. Três coisas escrevem nela:
#   * a PORTA por onde a personagem chegou na fase (porta_simulador.gd e
#     porta_fase.gd) — o primeiro ponto da visita; ao renascer nela, a
#     PortaSimulador repete a animação de saída;
#   * a BANDEIRA de checkpoint (checkpoint.gd), quando a personagem passa;
#   * a SALA de retorno (sala_de_retorno.gd), quando a personagem entra nela.
#
# Como todas gravam no mesmo lugar, elas nunca brigam: vale sempre a última
# que foi registrada. Passou pela bandeira e depois entrou numa sala? Volta na
# sala. Entrou na sala e depois tocou numa bandeira lá dentro? Volta na
# bandeira. Voltou para trás, para uma sala antiga? Volta nela — é onde ela
# estava de verdade.
#
# QUANTO TEMPO A MEMÓRIA DURA: só enquanto a personagem continua na MESMA visita
# à fase. Morrer recarrega a cena (reload_current_scene) e mantém o ponto; sair
# por uma porta, passagem ou qualquer outra troca de cena apaga, e entrar de
# novo recomeça da entrada. A diferença é detectada sozinha: o player avisa
# aqui (marcar_morte) antes de recarregar, e toda cena que abre sem esse aviso
# é tratada como visita nova.
#
# Tudo é "static var" — sobrevive à troca de cena, igual ao EstadoMundo.

## Cena (arquivo .tscn) em que o ponto foi gravado.
static var _cena: String = ""
static var _posicao: Vector2 = Vector2.ZERO
static var _tem_ponto: bool = false
## Caminho do nó que gravou por último ("/root/Fase1Oficina/SalaPatio").
static var _origem: String = ""
## Caminho da última BANDEIRA tocada — é ela que fica tremulando. Separado de
## _origem de propósito: entrar numa sala depois não enrola a bandeira.
static var _bandeira: String = ""

## Cena que o player mandou recarregar ao morrer (vazio = nenhuma morte pendente).
static var _cena_da_morte: String = ""
## Instância da cena já conferida — cada recarga cria uma instância nova.
static var _instancia_vista: int = 0
## True se a cena atual abriu por morte com um ponto de retorno valendo nela.
static var _renasceu: bool = false


## Grava o ponto de retorno. "fonte" é quem grava (bandeira ou sala).
static func registrar(fonte: Node, posicao_global: Vector2, eh_bandeira: bool = false) -> void:
	if fonte == null or not fonte.is_inside_tree():
		return
	_sincronizar(fonte.get_tree())
	var cena := fonte.get_tree().current_scene
	if cena == null:
		return
	_cena = cena.scene_file_path
	_posicao = posicao_global
	_tem_ponto = true
	_origem = str(fonte.get_path())
	if eh_bandeira:
		_bandeira = _origem


## Chamado pelo player logo antes de recarregar a cena por morte.
static func marcar_morte(tree: SceneTree) -> void:
	var cena := tree.current_scene
	_cena_da_morte = cena.scene_file_path if cena else ""


## Chamado no _ready() das fases, depois do spawn normal (SpawnPadrao/porta).
## Se esta cena abriu por causa de uma morte e há ponto gravado nela, leva a
## personagem até lá e encaixa a câmera. Devolve true se levou.
static func aplicar(player: CharacterBody2D) -> bool:
	if player == null or not player.is_inside_tree():
		return false
	_sincronizar(player.get_tree())
	if not _tem_ponto:
		return false

	player.global_position = _posicao
	player.velocity = Vector2.ZERO
	CameraJogador.encaixar(player)
	return true


## True se a cena atual abriu por uma MORTE e o ponto de retorno é de "no" —
## é assim que a porta de entrada sabe que precisa repetir a animação de saída.
static func renasceu_em(no: Node) -> bool:
	return eh_origem_atual(no) and _renasceu


## True se "no" foi o último a gravar o ponto.
static func eh_origem_atual(no: Node) -> bool:
	if no == null or not no.is_inside_tree():
		return false
	_sincronizar(no.get_tree())
	return _tem_ponto and str(no.get_path()) == _origem


## True se "bandeira" é a última bandeira tocada nesta visita.
static func eh_bandeira_ativa(bandeira: Node) -> bool:
	if bandeira == null or not bandeira.is_inside_tree():
		return false
	_sincronizar(bandeira.get_tree())
	return str(bandeira.get_path()) == _bandeira


static func esquecer() -> void:
	_cena = ""
	_posicao = Vector2.ZERO
	_tem_ponto = false
	_origem = ""
	_bandeira = ""


# Na primeira consulta de cada cena aberta, decide se o ponto continua valendo:
# só se a cena abriu por morte E o ponto é desta mesma cena. Roda de novo só
# quando a instância da cena muda, então a ordem de _ready() entre bandeiras,
# salas e a fase não importa — quem perguntar primeiro faz a conferência.
static func _sincronizar(tree: SceneTree) -> void:
	var cena := tree.current_scene
	if cena == null:
		return
	var id := cena.get_instance_id()
	if id == _instancia_vista:
		return
	_instancia_vista = id

	var voltou_de_morte := not _cena_da_morte.is_empty() and _cena_da_morte == cena.scene_file_path
	_cena_da_morte = ""
	_renasceu = voltou_de_morte and _tem_ponto and _cena == cena.scene_file_path
	if not _renasceu:
		esquecer()
