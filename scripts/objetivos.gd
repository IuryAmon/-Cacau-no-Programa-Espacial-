extends CanvasLayer

# --- AUTOLOAD "Objetivos" ---
#
# A lista de objetivos do canto superior esquerdo. Três peças:
#
#   RoteiroObjetivos (scripts/roteiro_objetivos.gd)  O QUE mostrar: os textos e
#                                                   as perguntas de "já foi?"
#   este autoload                                   QUANDO: qual trilha/etapa
#                                                   vale agora e quando a lista
#                                                   pode aparecer
#   ObjetivosHUD (scripts/ui/objetivos_hud.gd)      COMO: desenho, entrada,
#                                                   check verde, som e saída
#
# Ninguém avisa este nó de nada: ele pergunta ao roteiro algumas vezes por
# segundo, e o roteiro lê o estado que o jogo já guarda (Progresso, Inventario,
# EstadoMundo). Um objetivo que deixou de estar na lista por ter sido cumprido
# ganha o check; um que saiu por outro motivo (a queima da fornalha deu errado
# e as toras voltaram ao pátio) só some, sem check.
#
# É autoload porque a lista atravessa as cenas — o objetivo "Entre no
# laboratório" começa no world1 e é cumprido na cena seguinte.

## Cenas onde a lista não aparece: o simulador (a tela é da nave) e o
## encerramento em órbita.
const CENAS_SEM_OBJETIVOS: Array[String] = [
	"res://scenes/simulador/simulador_lua.tscn",
	"res://scenes/fases/final_orbita.tscn",
]

## A barra de vida da Cacau mora no mesmo canto: quando ela está na tela, a
## lista desce para baixo dela.
const CAMINHO_BARRA_DE_VIDA := "Player/CanvasLayer/HealthHUD/HudVital"

## Quantas vezes por segundo o roteiro é consultado.
const CONSULTAS_POR_SEGUNDO := 10.0

var _roteiro: RoteiroObjetivos
var _hud: ObjetivosHUD
## Cenas em que a Cacau já esteve (caminho -> true). Vale o jogo inteiro.
var _visitadas: Dictionary = {}
var _cena_atual: String = ""
var _espera_consulta: float = 0.0
## id do objetivo -> [índice da trilha, índice da etapa, dados do objetivo].
var _por_id: Dictionary = {}


func _ready() -> void:
	# Abaixo dos puzzles (10+), do cinto (90) e da mochila (95); acima do HUD
	# de vida (1). A cortina das portas (FadeTela, 0) esconde esta camada como
	# esconde o cinto.
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS

	_roteiro = RoteiroObjetivos.new(visitou)
	for t in _roteiro.trilhas.size():
		var etapas: Array[Dictionary] = _roteiro.trilhas[t]["etapas"]
		for e in etapas.size():
			for objetivo in etapas[e]["objetivos"]:
				_por_id[objetivo["id"]] = [t, e, objetivo]

	_hud = ObjetivosHUD.new()
	_hud.name = "Lista"
	add_child(_hud)


## A Cacau já entrou nesta cena alguma vez?
func visitou(cena: String) -> bool:
	return _visitadas.has(cena)


func _process(delta: float) -> void:
	_registrar_cena()
	_hud.definir_visivel(_pode_aparecer())
	_hud.definir_topo(_topo_livre())

	_espera_consulta -= delta
	if _espera_consulta > 0.0:
		return
	_espera_consulta = 1.0 / CONSULTAS_POR_SEGUNDO
	_atualizar_lista()


func _registrar_cena() -> void:
	var cena := get_tree().current_scene
	if cena == null or cena.scene_file_path == _cena_atual:
		return
	_cena_atual = cena.scene_file_path
	_visitadas[_cena_atual] = true
	# Cena nova: consulta já, sem esperar a próxima rodada.
	_espera_consulta = 0.0


# ─────────────────────────────────────────────
#  O que mostrar
# ─────────────────────────────────────────────

func _atualizar_lista() -> void:
	var trilhas := _roteiro.trilhas
	var ultimas: Array[int] = []
	for trilha in trilhas:
		ultimas.append(_ultima_etapa_cumprida(trilha))

	var t := _trilha_da_vez(ultimas)
	var desejados: Array[Dictionary] = []
	if t >= 0:
		var atual: int = ultimas[t] + 1
		for objetivo in trilhas[t]["etapas"][atual]["objetivos"]:
			if not objetivo["feito"].call() and _aparece(objetivo):
				desejados.append(objetivo)

	var ids_desejados := {}
	for objetivo in desejados:
		ids_desejados[objetivo["id"]] = true

	# O que já está na tela: cumpriu, saiu de cena ou só mudou a contagem.
	for id in _hud.ids():
		var dados: Array = _por_id.get(id, [])
		if dados.is_empty():
			_hud.remover(id)
			continue
		var objetivo: Dictionary = dados[2]
		var superado: bool = dados[1] <= ultimas[dados[0]]
		if superado or objetivo["feito"].call():
			_hud.concluir(id)
		elif not ids_desejados.has(id):
			_hud.remover(id)
		else:
			_hud.atualizar(id, objetivo["texto"], _contagem(objetivo))

	# O que ainda não está. O índice da trilha é o grupo: a lista mantém cada
	# trilha junta, sob o cabeçalho dela, na ordem do jogo.
	for objetivo in desejados:
		if not _hud.tem(objetivo["id"]):
			_hud.adicionar(objetivo["id"], objetivo["texto"], _contagem(objetivo),
				trilhas[t]["titulo"], trilhas[t]["cor"], objetivo["pai"], t)


## Índice da última etapa cumprida da trilha (-1 = nenhuma). Olha de trás para
## a frente: uma etapa lá adiante cumprida prova que as anteriores ficaram
## para trás, mesmo que alguma delas tenha sido pulada (atalho de teste,
## começar a fase direto no editor).
func _ultima_etapa_cumprida(trilha: Dictionary) -> int:
	var etapas: Array[Dictionary] = trilha["etapas"]
	for i in range(etapas.size() - 1, -1, -1):
		if _etapa_cumprida(etapas[i]):
			return i
	return -1


## Os objetivos com "aparece" não seguram a etapa: são dicas ou adiantamentos
## (ver roteiro_objetivos.gd).
func _etapa_cumprida(etapa: Dictionary) -> bool:
	if etapa.has("portao"):
		return etapa["portao"].call()
	for objetivo in etapa["objetivos"]:
		if not objetivo["aparece"].is_valid() and not objetivo["feito"].call():
			return false
	return true


func _aparece(objetivo: Dictionary) -> bool:
	var aparece: Callable = objetivo["aparece"]
	return not aparece.is_valid() or aparece.call()


## Qual trilha aparece: a da cena em que a Cacau está, se ainda não acabou; senão
## a primeira não terminada do jogo — uma de cada vez, na ordem do roteiro
## (carbono, depois nitrogênio, depois enxofre e fósforo). -1 = o jogo acabou.
func _trilha_da_vez(ultimas: Array[int]) -> int:
	var trilhas := _roteiro.trilhas
	for t in trilhas.size():
		if _cena_atual in trilhas[t]["cenas"] and _trilha_aberta(t, ultimas):
			return t
	for t in trilhas.size():
		if _trilha_aberta(t, ultimas):
			return t
	return -1


func _trilha_aberta(t: int, ultimas: Array[int]) -> bool:
	return ultimas[t] < _roteiro.trilhas[t]["etapas"].size() - 1


func _contagem(objetivo: Dictionary) -> Vector2i:
	var contar: Callable = objetivo["contagem"]
	return contar.call() if contar.is_valid() else Vector2i(-1, -1)


# ─────────────────────────────────────────────
#  Quando mostrar
# ─────────────────────────────────────────────

## A lista some com fala, ficha de item ou puzzle na tela (as mesmas telas que
## seguram a tecla E), com o jogo pausado e nas cenas sem a Cacau.
func _pode_aparecer() -> bool:
	var cena := get_tree().current_scene
	if cena == null or _cena_atual in CENAS_SEM_OBJETIVOS:
		return false
	if get_tree().get_first_node_in_group("player") == null:
		return false
	if get_tree().paused or Interacao.ocupada():
		return false
	return true


## Onde a lista começa, na vertical: logo abaixo da barra de vida, se ela
## estiver na tela; no alto do canto, se não (o laboratório esconde a barra).
func _topo_livre() -> float:
	var cena := get_tree().current_scene
	if cena == null:
		return ObjetivosHUD.TOPO_LIVRE
	var barra := cena.get_node_or_null(CAMINHO_BARRA_DE_VIDA) as Control
	if barra == null or not barra.is_visible_in_tree():
		return ObjetivosHUD.TOPO_LIVRE
	return barra.get_global_rect().end.y + ObjetivosHUD.FOLGA_SOB_A_VIDA
