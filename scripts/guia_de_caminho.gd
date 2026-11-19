extends CanvasLayer

# --- AUTOLOAD "GuiaDeCaminho": A SETA QUE APARECE QUANDO A CACAU SE PERDE ---
#
# A lista do canto diz O QUE fazer; o guia mostra PARA ONDE ir — mas só quando
# ela precisa. Enquanto a Cacau vai chegando mais perto do objetivo, o guia
# fica quieto. Se ela passa um tempo sem chegar mais perto (perdida, andando
# para o lado errado, parada sem saber o que fazer), entra a seta "POR AQUI" (a
# mesma SetaGo das setas da Oficina) apontando o caminho:
#
#   * objetivo em outra cena  -> a saída desta cena que leva até lá pelo
#     caminho mais curto (a porta, a ponta aberta do corredor, o elevador...);
#   * objetivo nesta cena     -> o próprio objeto (o cilindro, o baú, a coluna).
#
# Com o lugar na tela, a seta fica em cima dele, apontando para ele; fora da
# tela, ela gruda na borda, do lado em que ele fica (e diz "POR AQUI").
#
# A SETA SAI SOZINHA quando a Cacau anda um bom pedaço na direção certa
# (avanco_para_sumir), chega perto do lugar (raio_de_chegada), entra na cena
# certa ou cumpre o objetivo. Se ela empacar de novo no mesmo objetivo, a seta
# volta mais depressa (paciencia_depois_de_ajudar): ela já mostrou que precisa
# de ajuda. Entrar numa cena que NÃO é o caminho não zera o relógio: se a seta
# estava na tela, ela continua, agora apontando a saída de volta.
#
# O RELÓGIO SÓ CORRE COM A CACAU LIVRE: não conta com fala, ficha de item,
# puzzle, caderno aberto, jogo pausado, troca de cena ou cutscene (ela sem
# controle). E o guia nunca disputa com uma SetaGuia posta à mão numa fase
# (scripts/fases/seta_guia.gd): com uma delas na tela, ele fica quieto e o
# relógio volta ao zero.
#
# ONDE CADA OBJETIVO FICA
#   a cena    -> a do PlantaDoMapa.ONDE_FICA (a mesma que o mapa do caderno
#                aponta);
#   o objeto  -> ALVOS, aqui embaixo: o caminho do nó dentro da cena. Objetivo
#                fora de ALVOS se cumpre só de chegar à cena ("Entre na Ala de
#                Pirólise"): o guia leva até a porta dela e pronto.
# COMO AS CENAS SE LIGAM -> LIGACOES. A porta certa, o guia acha sozinho na
#   cena: qualquer nó com "cena_destino" (porta, ponta aberta, alçapão,
#   elevador) que leve à próxima cena do caminho. Saída feita por código, sem
#   nó (o elevador de carga do telhado), a fase declara numa função
#   saidas_para_o_guia() — ver fase2_telhado.gd.
#
# O teste tools/teste_guia_de_caminho.tscn confere tudo isso contra as cenas de
# verdade: renomeou um nó de ALVOS, criou uma porta nova ou um objetivo novo,
# ele avisa.
#
# PARA AJUSTAR: os números logo abaixo (paciencia e companhia). No jogo rodado
# pelo editor, F3 mostra a seta na hora, sem esperar (e escreve no Output o
# que o guia está pensando).

# ─────────────────────────────────────────────
#  PARA AJUSTAR
# ─────────────────────────────────────────────

## Segundos com a Cacau livre e sem chegar mais perto do objetivo até a seta
## aparecer.
var paciencia: float = 25.0
## Depois que a seta já apareceu para um objetivo, ela volta mais depressa se
## a Cacau empacar de novo nele.
var paciencia_depois_de_ajudar: float = 10.0
## Objetivos com pressa (a amostra gelada esquenta no caminho), com paciência
## própria, em segundos.
var paciencia_com_pressa: Dictionary = {"levar_amostra": 6.0}
## Quanto ela precisa chegar mais perto (px do mundo) para contar como "indo
## para o lugar certo". Menos que isso é andar de um lado para o outro.
var passo_de_progresso: float = 48.0
## Com a seta na tela, andar isto (px do mundo) na direção certa basta: a seta
## sai de cena.
var avanco_para_sumir: float = 400.0
## A esta distância do lugar (px do mundo) a seta sai e o relógio não corre: o
## botão E do lugar já aparece.
var raio_de_chegada: float = 90.0
## Tamanho da seta (1 = o das SetaGuia das fases).
var escala_da_seta: float = 0.8
## O texto da seta quando o lugar está fora da tela (ou é uma ponta aberta).
## Em cima de um objeto que já aparece na tela, ela vai sem texto.
var texto_na_borda: String = "POR AQUI"

## Distância mínima da ponta da seta até cada borda da tela: esquerda, topo,
## direita, base (px de tela). Embaixo, à esquerda, ficam o caderno e o mapa.
const MARGENS := Vector4(34, 110, 34, 96)
## No canto de cima, à esquerda, mora a lista de objetivos: ali a seta desce
## até esta altura.
const TOPO_SOB_A_LISTA := 300.0
const LARGURA_DA_LISTA := 560.0
## Fora da tela, a seta só troca de deitada para em pé (e vice-versa) quando o
## outro lado ganha com esta folga: o lugar na diagonal não a faz girar.
const FOLGA_PARA_VIRAR := 1.25
## Quantas vezes por segundo o objetivo e o caminho são refeitos.
const CONSULTAS_POR_SEGUNDO := 4.0

# ─────────────────────────────────────────────
#  O MAPA DO GUIA
# ─────────────────────────────────────────────

const WORLD1 := PlantaDoMapa.WORLD1
const LAB := PlantaDoMapa.LAB
const SIMULADOR := PlantaDoMapa.SIMULADOR
const OFICINA := PlantaDoMapa.OFICINA
const CORREDOR_PATIO := PlantaDoMapa.CORREDOR_PATIO
const PATIO := PlantaDoMapa.PATIO
const CORREDOR_TORRE := PlantaDoMapa.CORREDOR_TORRE
const RUA := PlantaDoMapa.RUA
const COMPRESSOR := PlantaDoMapa.COMPRESSOR
const DESTILACAO := PlantaDoMapa.DESTILACAO
const TORRE := PlantaDoMapa.TORRE
const TELHADO := PlantaDoMapa.TELHADO
const SUBSOLO := PlantaDoMapa.SUBSOLO
const LANCAMENTO := PlantaDoMapa.LANCAMENTO
const FINAL_ORBITA := RoteiroObjetivos.FINAL_ORBITA

## Como as cenas se ligam. Cada linha é UM sentido: [de, para] ou [de, para,
## ferramenta que a passagem pede]. O fosso de ventilação só se desce com a
## mochila; subir de volta, qualquer um sobe.
const LIGACOES: Array = [
	# O prólogo, o laboratório e o simulador
	[WORLD1, LAB], [LAB, WORLD1],
	[LAB, SIMULADOR], [SIMULADOR, LAB],
	# Carbono: a oficina, o corredor do elevador e o pátio
	[LAB, OFICINA], [OFICINA, LAB],
	[OFICINA, CORREDOR_PATIO], [CORREDOR_PATIO, OFICINA],
	[CORREDOR_PATIO, PATIO], [PATIO, CORREDOR_PATIO],
	# Nitrogênio: a ponta direita do laboratório, o corredor e a rua
	[LAB, CORREDOR_TORRE], [CORREDOR_TORRE, LAB],
	[CORREDOR_TORRE, RUA], [RUA, CORREDOR_TORRE],
	[RUA, COMPRESSOR], [COMPRESSOR, RUA],
	[RUA, DESTILACAO], [DESTILACAO, RUA],
	[RUA, TORRE], [TORRE, RUA],
	[TORRE, TELHADO], [TELHADO, TORRE],
	# O elevador de carga do telhado só desce.
	[TELHADO, RUA],
	# Subsolo
	[LAB, SUBSOLO, "mochila"], [SUBSOLO, LAB],
	# Torre de Lançamento: sem entrada (a porta verde do laboratório saiu em
	# 2026-11-18). Quem está lá dentro (modo dev) ainda sai para o laboratório.
	[LANCAMENTO, LAB],
	[LANCAMENTO, FINAL_ORBITA],
]

## O objeto de cada objetivo, pelo caminho do nó dentro da cena dele.
const ALVOS: Dictionary = {
	# Prólogo (world1)
	"h2": "ItemColetavel",
	"o2": "ItemColetavel2",
	"caixa": "Caixa",
	"computador": "ReceptorItemGeral",
	# Carbono
	"bumerangue": "Entrada/GaiolaBumerangue",
	"espinhos": "Treino/AlvoFixo1",
	"macarico": "Patio/GaiolaMacarico",
	"porta_metal": "Patio/PortaMetal",
	"porta_elevador": "Patio/PortaMetal2",
	"carvao": "Patio/Retorta",
	"lenha": "Patio/ArvoreLenha",
	"retirar_carvao": "Patio/Retorta",
	"entregar_c": "ReceptorChonps",
	# Nitrogênio (a porta de metal fica no fim do laboratório)
	"porta_torre": "PortaMetalTorre",
	"mochila": "Mochila",
	"cilindro": "CilindrosDeAr",
	"comprimir": "CompressorDeAr",
	"levar_amostra": "Destilador",
	"destilar": "Destilador",
	"pegar_n": "CilindroDeNitrogenio",
	"entregar_n": "ReceptorChonps",
	# Enxofre e fósforo
	"pegar_p": "AlaOeste/MesaGerador",
	"botas": "AlaLeste/Masseira",
	"pegar_s": "AlaLeste/PontoDaCelulaS",
	"entregar_ps": "ReceptorChonps",
	# Torre de Lançamento
	"purificador": "Plataforma/MesaPurificador",
	"embarque": "Plataforma/Capsula/PortaCapsula",
}

## Objetivos em que o guia nunca aparece: o caminho até lá é uma linha só e a
## seta não ajuda ninguém (o maçarico: subir do corredor das torretas até o
## domo, pedido do usuário em 2026-11-18).
const SEM_SETA: Array[String] = ["macarico"]

## O que fica de fora da caixa de um objeto (ver _visuais_de): os botões e os
## "!" que flutuam em cima dele.
const FORA_DA_CAIXA: Array[String] = ["IconeInteragir", "ExclamacaoAnimada", "IndicadorEntrada",
	"Rotulo", "EDoElevador"]

var _seta: SetaGo = null

## O objetivo que o guia acompanha ("" = nenhum).
var _id: String = ""
## As cenas que faltam até a do objetivo (sem a atual; vazio = já está nela).
var _caminho: Array = []
## A próxima cena do caminho ("" = já está na do objetivo).
var _proxima: String = ""
## A cena para a qual o ponto foi achado (instance id).
var _id_da_cena: int = 0
## Para onde a seta aponta nesta cena: {"no"} (um objeto ou uma saída, com
## "sentido" se for ponta aberta) ou {"posicao"} (saída sem nó). {} = nada.
var _ponto: Dictionary = {}
## A menor distância até o ponto desde que ele virou o ponto da vez.
var _melhor: float = INF
## Segundos sem chegar mais perto.
var _parado: float = 0.0
## A seta já apareceu para o objetivo da vez.
var _ajudou: bool = false
var _mostrando: bool = false
## A distância até o ponto quando a seta apareceu (ou quando a cena trocou com
## ela na tela): é dali que se mede o avanço que a faz sumir.
var _distancia_ao_aparecer: float = 0.0
var _forcar: bool = false
var _espera_consulta: float = 0.0
## As saídas da cena atual (ver saidas_de), achadas uma vez por cena.
var _saidas: Array[Dictionary] = []
var _saidas_da_cena: int = 0


func _ready() -> void:
	# Na altura da lista de objetivos e das SetaGuia: abaixo dos puzzles, das
	# fichas e da cortina das portas (que o esconde, ver FadeTela.HUDS_AUTOLOAD).
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	_seta = SetaGo.new()
	_seta.name = "Seta"
	_seta.escala = escala_da_seta
	_seta.texto = ""
	add_child(_seta)


func _process(delta: float) -> void:
	_seta.escala = escala_da_seta
	var player := get_tree().get_first_node_in_group("player") as Node2D

	_espera_consulta -= delta
	var cena := get_tree().current_scene
	if _espera_consulta <= 0.0 or (cena != null and cena.get_instance_id() != _id_da_cena):
		_espera_consulta = 1.0 / CONSULTAS_POR_SEGUNDO
		_consultar(player)

	if player == null or not _ponto_valido():
		# Sem a Cacau (o quadro da troca de cena) ou sem lugar para apontar: a
		# seta sai da frente, mas o guia não esquece que ela estava na tela —
		# entrar na cena errada não pode apagar a ajuda.
		_forcar = false
		_seta.esconder()
		return
	if not _livre(player):
		# Fala, puzzle, caderno, pausa, troca de cena, cutscene: o relógio para
		# e a seta sai da frente (e volta, se ainda for a hora dela).
		_seta.esconder()
		return
	if _setas_a_mao_na_tela():
		# Uma SetaGuia posta à mão já está mostrando o caminho.
		_parado = 0.0
		_mostrando = false
		_seta.esconder()
		return

	var distancia := _distancia_ate(player, _ponto)
	if distancia < _melhor - passo_de_progresso:
		_melhor = distancia
		if not _mostrando:
			_parado = 0.0

	if _forcar:
		_aparecer(distancia)
	elif distancia <= raio_de_chegada:
		# Chegou: o botão do lugar já aparece, e o relógio não corre.
		_parado = 0.0
		_mostrando = false
	elif _mostrando:
		if _distancia_ao_aparecer - distancia >= avanco_para_sumir:
			# Pegou o rumo: a seta sai. Se ela empacar de novo, volta.
			_mostrando = false
			_parado = 0.0
	else:
		_parado += delta
		if _parado >= _paciencia_da_vez():
			_aparecer(distancia)
	_forcar = false

	if _mostrando:
		_posicionar(player)
		_seta.mostrar()
	else:
		_seta.esconder()


# ─────────────────────────────────────────────
#  PARA OS TESTES E O MODO DEV
# ─────────────────────────────────────────────

## F3 do modo dev: a seta aparece já, sem esperar a paciência acabar.
func mostrar_agora() -> void:
	_espera_consulta = 0.0
	_forcar = true
	print("DEBUG [GuiaDeCaminho]: ", descrever())


## O que o guia está pensando agora.
func estado() -> Dictionary:
	return {"objetivo": _id, "caminho": _caminho.duplicate(), "ponto": _nome_do_ponto(),
		"parado": _parado, "mostrando": _mostrando, "ajudou": _ajudou}


func descrever() -> String:
	if _id.is_empty():
		return "nenhum objetivo com lugar conhecido na lista agora."
	var lugar := PlantaDoMapa.lugar_do_objetivo(_id)
	var texto := "objetivo \"%s\" (em %s)" % [_id, String(lugar.get("cena", "?")).get_file()]
	if not _ponto_valido():
		return texto + ": nenhum ponto para apontar nesta cena (sem caminho até lá, ou já basta estar aqui)."
	var rota := PackedStringArray()
	for cena in _caminho:
		rota.append(String(cena).get_file())
	return texto + ", caminho %s, apontando para %s; parado há %.1f s de %.1f" \
		% [rota, _nome_do_ponto(), _parado, _paciencia_da_vez()]


## A seta do guia (a SetaGo).
func seta() -> SetaGo:
	return _seta


## Esquece o objetivo da vez e o relógio (os testes começam do zero).
func esquecer() -> void:
	_trocar_de_objetivo("")
	_saidas_da_cena = 0
	_seta.esconder()


# ─────────────────────────────────────────────
#  O CAMINHO
# ─────────────────────────────────────────────

## O caminho mais curto, em cenas, de "de" até "ate" (sem a "de"): [] se já
## está lá; null se não dá para chegar (cena fora do mapa do guia, ou uma
## passagem que pede uma ferramenta que a Cacau ainda não tem).
func caminho(de: String, ate: String) -> Variant:
	if de == ate:
		return []
	var veio_de := {de: ""}
	var fila: Array[String] = [de]
	while not fila.is_empty():
		var atual: String = fila.pop_front()
		for ligacao: Array in LIGACOES:
			if ligacao[0] != atual or veio_de.has(ligacao[1]):
				continue
			if ligacao.size() > 2 and not _pode_passar(String(ligacao[2])):
				continue
			veio_de[ligacao[1]] = atual
			if ligacao[1] == ate:
				var lista: Array = []
				var passo: String = ate
				while passo != de:
					lista.push_front(passo)
					passo = veio_de[passo]
				return lista
			fila.append(ligacao[1])
	return null


## As saídas de uma cena: cada nó com "cena_destino" (porta, ponta aberta,
## alçapão, elevador), com o "sentido" das pontas abertas, e as que a fase
## declara em saidas_para_o_guia() ({"cena", "posicao"}). Serve também para a
## cena fora da árvore (o teste instancia as cenas e confere as LIGACOES).
func saidas_de(cena: Node) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for no in cena.find_children("*", "Node2D", true, false):
		if not "cena_destino" in no:
			continue
		var destino := String(no.get("cena_destino"))
		if destino.is_empty():
			continue
		var saida := {"cena": destino, "no": no}
		if "sentido" in no:
			saida["sentido"] = float(no.get("sentido"))
		lista.append(saida)
	if cena.has_method("saidas_para_o_guia"):
		for extra: Dictionary in cena.saidas_para_o_guia():
			lista.append(extra)
	return lista


func _pode_passar(ferramenta: String) -> bool:
	return ferramenta.is_empty() or Progresso.tem_habilidade(ferramenta) or ModoDev.ativo


# ─────────────────────────────────────────────
#  O OBJETIVO DA VEZ E O PONTO
# ─────────────────────────────────────────────

func _consultar(player: Node2D) -> void:
	var cena := get_tree().current_scene
	if cena == null or player == null:
		_ponto = {}
		return
	var objetivo := _escolher_objetivo(cena.scene_file_path, player)
	var id := String(objetivo.get("id", ""))
	if id != _id:
		_trocar_de_objetivo(id)
	if _id.is_empty():
		_ponto = {}
		_id_da_cena = cena.get_instance_id()
		return

	var rota: Variant = caminho(cena.scene_file_path, String(PlantaDoMapa.lugar_do_objetivo(_id)["cena"]))
	if rota == null:
		_ponto = {}
		_caminho = []
		_id_da_cena = cena.get_instance_id()
		return
	var proxima: String = String(rota[0]) if not rota.is_empty() else ""
	var trocou_de_cena := cena.get_instance_id() != _id_da_cena

	if trocou_de_cena and _id_da_cena != 0 and rota.size() < _caminho.size():
		# Entrou numa cena do caminho: isso é ir para o lugar certo.
		_parado = 0.0
		_mostrando = false
	_caminho = rota

	if trocou_de_cena or proxima != _proxima or not _ponto_valido():
		_id_da_cena = cena.get_instance_id()
		_proxima = proxima
		_ponto = _ponto_da_vez(cena, proxima, player)
		if not _ponto.is_empty():
			_melhor = _distancia_ate(player, _ponto)
			# Com a seta na tela, o avanço que a faz sumir conta daqui.
			_distancia_ao_aparecer = _melhor


func _trocar_de_objetivo(id: String) -> void:
	_id = id
	_ajudou = false
	_parado = 0.0
	_mostrando = false
	_ponto = {}
	_caminho = []
	_proxima = ""
	_id_da_cena = 0
	_melhor = INF


## Qual dos objetivos da lista o guia acompanha. O pai cede a vez aos subitens
## (são eles o próximo passo: a lenha antes do carvão); o que não é dica
## ("aparece" no roteiro) vem antes da dica; depois, o de menos cenas até lá;
## depois, o mais perto. O da vez continua sendo o da vez enquanto estiver na
## lista — a seta não pula de um objetivo para outro com a Cacau no meio dos
## dois.
func _escolher_objetivo(cena_atual: String, player: Node2D) -> Dictionary:
	var conhecidos: Array[Dictionary] = []
	for objetivo: Dictionary in Objetivos.atuais():
		if String(objetivo["id"]) in SEM_SETA:
			continue
		if not PlantaDoMapa.lugar_do_objetivo(String(objetivo["id"])).is_empty():
			conhecidos.append(objetivo)
	var pais := {}
	for objetivo in conhecidos:
		if not String(objetivo.get("pai", "")).is_empty():
			pais[objetivo["pai"]] = true

	var escolhido := {}
	var menor := INF
	for objetivo in conhecidos:
		var id := String(objetivo["id"])
		if pais.has(id):
			continue
		var rota: Variant = caminho(cena_atual, String(PlantaDoMapa.lugar_do_objetivo(id)["cena"]))
		if rota == null:
			continue
		var nota: float = (1.0e9 if objetivo.get("opcional", false) else 0.0) + (rota as Array).size() * 1.0e6
		if id == _id:
			nota -= 0.5e6
		elif (rota as Array).is_empty():
			nota += minf(_distancia_ao_alvo(id, player), 0.4e6)
		if nota < menor:
			menor = nota
			escolhido = objetivo
	return escolhido


func _distancia_ao_alvo(id: String, player: Node2D) -> float:
	if not ALVOS.has(id):
		return 0.0
	var no := get_tree().current_scene.get_node_or_null(String(ALVOS[id])) as Node2D
	if no == null:
		return 0.0
	return player.global_position.distance_to(no.global_position)


## O ponto da vez nesta cena: o objeto do objetivo (já na cena dele) ou, entre
## as saídas que levam à próxima cena do caminho, a mais perto dela.
func _ponto_da_vez(cena: Node, proxima: String, player: Node2D) -> Dictionary:
	if proxima.is_empty():
		if not ALVOS.has(_id):
			return {}
		var no := cena.get_node_or_null(String(ALVOS[_id])) as Node2D
		if no == null:
			return {}
		return {"no": no, "visuais": _visuais_de(no)}
	if _saidas_da_cena != cena.get_instance_id():
		_saidas_da_cena = cena.get_instance_id()
		_saidas = saidas_de(cena)
	var melhor := {}
	var menor := INF
	for saida in _saidas:
		if saida["cena"] != proxima:
			continue
		if saida.has("no") and not is_instance_valid(saida["no"]):
			continue
		var ponto := saida.duplicate()
		if ponto.has("no") and not ponto.has("sentido"):
			ponto["visuais"] = _visuais_de(ponto["no"])
		var d := _distancia_ate(player, ponto)
		if d < menor:
			menor = d
			melhor = ponto
	return melhor


func _ponto_valido() -> bool:
	if _ponto.has("no"):
		return is_instance_valid(_ponto["no"])
	return _ponto.has("posicao")


func _nome_do_ponto() -> String:
	if _ponto.has("no") and is_instance_valid(_ponto["no"]):
		var cena := get_tree().current_scene
		var no := _ponto["no"] as Node
		return str(cena.get_path_to(no)) if cena != null and cena.is_ancestor_of(no) else str(no.name)
	if _ponto.has("posicao"):
		return "posição %s" % [_ponto["posicao"]]
	return ""


# ─────────────────────────────────────────────
#  O RELÓGIO
# ─────────────────────────────────────────────

func _paciencia_da_vez() -> float:
	var segundos := paciencia_depois_de_ajudar if _ajudou else paciencia
	if paciencia_com_pressa.has(_id):
		segundos = minf(segundos, float(paciencia_com_pressa[_id]))
	return segundos


func _aparecer(distancia: float) -> void:
	_mostrando = true
	_ajudou = true
	_parado = 0.0
	_distancia_ao_aparecer = distancia


## A Cacau está jogando: nada na frente dela e ela no controle.
func _livre(player: Node2D) -> bool:
	if get_tree().paused or Interacao.ocupada() or Caderno.aberto():
		return false
	if FadeTela.cobrindo(get_tree()):
		return false
	if "pode_se_mover" in player and not player.pode_se_mover:
		return false
	return true


func _setas_a_mao_na_tela() -> bool:
	for seta_da_fase in get_tree().get_nodes_in_group(SetaGuia.GRUPO):
		if seta_da_fase.has_method("guiando") and seta_da_fase.guiando():
			return true
	return false


## Quanto falta até o ponto (px do mundo). Numa ponta aberta, o que conta é
## chegar à linha; num objeto, chegar à caixa dele (zero dentro dela).
func _distancia_ate(player: Node2D, ponto: Dictionary) -> float:
	var pos := player.global_position
	if ponto.has("sentido") and ponto.has("no"):
		return absf((ponto["no"] as Node2D).global_position.x - pos.x)
	var caixa := _caixa_do_ponto(ponto)
	var mais_perto := Vector2(clampf(pos.x, caixa.position.x, caixa.end.x),
		clampf(pos.y, caixa.position.y, caixa.end.y))
	return pos.distance_to(mais_perto)


# ─────────────────────────────────────────────
#  A SETA NA TELA
# ─────────────────────────────────────────────

func _posicionar(player: Node2D) -> void:
	var tela := get_viewport().get_visible_rect().size
	var para_a_tela := get_viewport().get_canvas_transform()
	var direcao: int
	var alvo: Vector2
	var com_texto := true

	if _ponto.has("sentido"):
		# Ponta aberta: a seta aponta para fora, na altura da Cacau.
		var linha := (_ponto["no"] as Node2D).global_position.x
		alvo = para_a_tela * Vector2(linha, player.global_position.y - 24.0)
		direcao = SetaGo.Direcao.DIREITA if float(_ponto["sentido"]) > 0.0 else SetaGo.Direcao.ESQUERDA
	else:
		var caixa := para_a_tela * _caixa_do_ponto(_ponto)
		alvo = Vector2(caixa.get_center().x, caixa.position.y)
		var area := Rect2(Vector2(MARGENS.x, MARGENS.y),
			tela - Vector2(MARGENS.x + MARGENS.z, MARGENS.y + MARGENS.w))
		if area.intersects(caixa.grow(1.0)):
			# Na tela: em cima do objeto, apontando para ele.
			direcao = SetaGo.Direcao.BAIXO
			com_texto = false
		else:
			direcao = _direcao_para_fora(alvo, tela)

	_seta.virar(direcao)
	_seta.texto = texto_na_borda if com_texto else ""
	_seta.ponta = _prender_na_tela(alvo, direcao, tela)


## Para que lado da tela fica um ponto fora dela.
func _direcao_para_fora(alvo: Vector2, tela: Vector2) -> int:
	var d := (alvo - tela * 0.5) / (tela * 0.5)
	var deitada_agora := _seta.direcao == SetaGo.Direcao.DIREITA or _seta.direcao == SetaGo.Direcao.ESQUERDA
	var deitada: bool
	if deitada_agora:
		deitada = absf(d.y) <= absf(d.x) * FOLGA_PARA_VIRAR
	else:
		deitada = absf(d.x) > absf(d.y) * FOLGA_PARA_VIRAR
	if deitada:
		return SetaGo.Direcao.DIREITA if d.x > 0.0 else SetaGo.Direcao.ESQUERDA
	return SetaGo.Direcao.BAIXO if d.y > 0.0 else SetaGo.Direcao.CIMA


## A ponta presa dentro da tela, com a seta inteira cabendo atrás dela.
func _prender_na_tela(alvo: Vector2, direcao: int, tela: Vector2) -> Vector2:
	var minimo := Vector2(MARGENS.x, MARGENS.y)
	var maximo := tela - Vector2(MARGENS.z, MARGENS.w)
	var corpo := SetaGo.comprimento() * escala_da_seta
	match direcao:
		SetaGo.Direcao.DIREITA:
			minimo.x += corpo
		SetaGo.Direcao.ESQUERDA:
			maximo.x -= corpo
		SetaGo.Direcao.BAIXO:
			minimo.y += corpo
		SetaGo.Direcao.CIMA:
			maximo.y -= corpo
	var ponta := alvo.clamp(minimo, maximo)
	if ponta.x < LARGURA_DA_LISTA:
		var topo := TOPO_SOB_A_LISTA + (corpo if direcao == SetaGo.Direcao.BAIXO else 0.0)
		ponta.y = maxf(ponta.y, minf(topo, maximo.y))
	return ponta


# ─────────────────────────────────────────────
#  A CAIXA DE UM OBJETO
# ─────────────────────────────────────────────

## Onde o ponto está no mundo: a caixa dos desenhos do objeto (o sprite da
## porta, do cilindro, do baú) ou, sem desenho, o ponto do nó.
func _caixa_do_ponto(ponto: Dictionary) -> Rect2:
	var caixa := Rect2()
	var achou := false
	for visual in ponto.get("visuais", []):
		if not is_instance_valid(visual) or not (visual as CanvasItem).is_visible_in_tree():
			continue
		var retangulo := _retangulo_no_mundo(visual)
		if retangulo.size == Vector2.ZERO:
			continue
		caixa = caixa.merge(retangulo) if achou else retangulo
		achou = true
	if achou:
		return caixa
	if ponto.has("no") and is_instance_valid(ponto["no"]):
		return Rect2((ponto["no"] as Node2D).global_position, Vector2.ZERO)
	return Rect2(ponto.get("posicao", Vector2.ZERO), Vector2.ZERO)


## Os desenhos de um objeto: sprites e retângulos dele e dos filhos (até 4
## níveis), fora os botões e os "!" que flutuam em cima (FORA_DA_CAIXA) e o
## que mora numa CanvasLayer.
func _visuais_de(no: Node) -> Array:
	var lista: Array = []
	_juntar_visuais(no, 0, lista)
	return lista


func _juntar_visuais(no: Node, profundidade: int, lista: Array) -> void:
	if profundidade > 4 or lista.size() >= 24:
		return
	if no is CanvasLayer or String(no.name) in FORA_DA_CAIXA:
		return
	if no is Sprite2D or no is AnimatedSprite2D or no is TextureRect or no is ColorRect:
		lista.append(no)
	for filho in no.get_children():
		_juntar_visuais(filho, profundidade + 1, lista)


static func _retangulo_no_mundo(visual: CanvasItem) -> Rect2:
	if visual is Sprite2D:
		var sprite := visual as Sprite2D
		if sprite.texture == null:
			return Rect2()
		return sprite.get_global_transform() * sprite.get_rect()
	if visual is AnimatedSprite2D:
		var animado := visual as AnimatedSprite2D
		if animado.sprite_frames == null or not animado.sprite_frames.has_animation(animado.animation):
			return Rect2()
		var textura := animado.sprite_frames.get_frame_texture(animado.animation, animado.frame)
		if textura == null:
			return Rect2()
		var tamanho := textura.get_size()
		var local := Rect2(animado.offset - (tamanho * 0.5 if animado.centered else Vector2.ZERO), tamanho)
		return animado.get_global_transform() * local
	if visual is Control:
		return (visual as Control).get_global_rect()
	return Rect2()
