class_name ExplicacaoNoPuzzle
extends RefCounted

# --- O DR. CHICO EXPLICANDO DENTRO DE UM PUZZLE (os átomos do world1) ---
#
# O mesmo jeito do balanceamento guiado do puzzle do foguete
# (scripts/puzzle_foguete.gd): ele fala pelo Dialogic por cima da tela, o
# holofote (DestaqueTutorial) acende o que ele está citando e, quando ele pede
# uma ação, a seta aponta a peça certa e só ela responde. O puzzle que usa
# isto tem:
#
#   destaque                    o DestaqueTutorial, por cima da tela
#   retangulos_para(nomes)      os lugares da tela que o holofote acende, pelo
#                               nome (Array[Rect2], coordenadas de tela)
#   retangulos_da_acao(acao)    a peça da ação (a seta vai nela) e o lugar
#                               para onde ela vai
#   meta_cumprida(meta)         a condição que encerra um passo já vale?
#
# e chama conferir() a cada mudança (peça posta, puzzle resolvido) e
# cancelar() ao fechar.
#
# O ROTEIRO é uma lista de passos. Cada passo:
#   "fala"     a timeline (o nome do arquivo em timelines/, sem o .dtl) dita
#              no começo do passo; vazia = sem fala
#   "mostrar" / "enfase"  o que o holofote acende quando a fala abre (os
#              nomes do retangulos_para); os dois vazios = sem holofote
#   "sinais"   {nome: {"mostrar", "enfase"}}: um [signal arg="nome"] na
#              timeline leva o holofote para lá no meio da fala, na frase
#              que comenta aquilo
#   "acao"     o nome da ação que a pessoa faz, com a seta na peça (só ela
#              responde); vazia = a pessoa decide sozinha
#   "meta"     a condição que encerra o passo (meta_cumprida); vazia = o
#              passo acaba com a fala
#
# PULAR. A primeira fala pergunta se a pessoa quer a explicação; a segunda
# opção ("Já sei...") solta [signal arg="pular_explicacao"] e acaba a
# conversa: o roteiro para ali e o puzzle fica livre. QUEM ANOTA NO CADERNO É
# A CONVERSA (do Caderno.anotar("...")), no fim da explicação e no caminho de
# quem pula.

signal acabou

const PASTA_DAS_FALAS := "res://timelines/"
const SINAL_PULAR := "pular_explicacao"
## O Dialogic vai por cima do puzzle (que desenha na camada 10).
const CAMADA_DA_FALA := 20
## Depois da ação certa, um respiro antes da próxima fala: o tempo de a peça
## assentar e a contagem mudar — é isso que ele vai comentar.
const PAUSA_ENTRE_PASSOS := 0.35
## Do holofote acendendo no lugar novo até a fala abrir.
const ESPERA_ANTES_DA_FALA := 0.1

## O Dr. Chico está falando agora (a tela do puzzle não responde).
var falando: bool = false

var _puzzle: Node = null
var _roteiro: Array = []
var _passo: int = -1
var _acao: String = ""
var _pulou: bool = false
## Cada começo e cada cancelamento troca a sessão: o que ainda estava
## esperando (uma pausa, uma fala) de uma sessão velha não continua.
var _sessao: int = 0


func _init(puzzle: Node, roteiro: Array) -> void:
	_puzzle = puzzle
	_roteiro = roteiro


## Está explicando (falando, ou esperando a pessoa num passo)?
func ativa() -> bool:
	return _passo >= 0 and _passo < _roteiro.size()


## A ação que o passo de agora pede ("" = nenhuma: a pessoa decide).
func acao() -> String:
	return _acao if ativa() and not falando else ""


## A pessoa escolheu "Já sei..."?
func pulou() -> bool:
	return _pulou


func comecar() -> void:
	_sessao += 1
	_pulou = false
	_executar(0, _sessao)


## O puzzle fechou no meio: tudo para, o holofote apaga e a fala (se houver)
## acaba.
func cancelar() -> void:
	_sessao += 1
	_passo = -1
	_acao = ""
	if falando:
		falando = false
		if Dialogic.current_timeline != null:
			Dialogic.end_timeline(true)
	if is_instance_valid(_puzzle):
		_puzzle.destaque.limpar(true)


## Chamado a cada mudança no puzzle: chegou na meta do passo, avança.
func conferir() -> void:
	if not ativa() or falando:
		return
	var meta := String(_roteiro[_passo].get("meta", ""))
	if not meta.is_empty() and _puzzle.meta_cumprida(meta):
		_executar(_passo + 1, _sessao)


func _executar(indice: int, sessao: int) -> void:
	_passo = indice
	_acao = ""
	if indice >= _roteiro.size():
		_terminar()
		return
	var passo: Dictionary = _roteiro[indice]
	var destaque: DestaqueTutorial = _puzzle.destaque
	var arvore := _puzzle.get_tree()

	if indice > 0:
		destaque.limpar()
		await arvore.create_timer(PAUSA_ENTRE_PASSOS, true).timeout
		if sessao != _sessao or not is_instance_valid(_puzzle):
			return

	var fala := String(passo.get("fala", ""))
	if not fala.is_empty():
		var mostrar: Array = passo.get("mostrar", [])
		var enfase: Array = passo.get("enfase", [])
		if not (mostrar.is_empty() and enfase.is_empty()):
			# O holofote acende ANTES da fala: a pessoa já está olhando para o
			# lugar certo quando o texto chega nele.
			destaque.focar(_puzzle.retangulos_para(mostrar), false, _puzzle.retangulos_para(enfase))
			await arvore.create_timer(ESPERA_ANTES_DA_FALA, true).timeout
			if sessao != _sessao or not is_instance_valid(_puzzle):
				return
		var sinais: Dictionary = passo.get("sinais", {})
		var ao_sinal := func(argumento: Variant) -> void:
			if sessao != _sessao or not is_instance_valid(_puzzle) or not argumento is String:
				return
			if argumento == SINAL_PULAR:
				_pulou = true
				destaque.limpar()
			elif sinais.has(argumento):
				var foco: Dictionary = sinais[argumento]
				destaque.focar(_puzzle.retangulos_para(foco.get("mostrar", [])), false,
					_puzzle.retangulos_para(foco.get("enfase", [])))
		Dialogic.signal_event.connect(ao_sinal)
		await _falar(PASTA_DAS_FALAS + fala + ".dtl", sessao)
		if Dialogic.signal_event.is_connected(ao_sinal):
			Dialogic.signal_event.disconnect(ao_sinal)
		if sessao != _sessao or not is_instance_valid(_puzzle):
			return
		if _pulou:
			_terminar()
			return

	var meta := String(passo.get("meta", ""))
	if meta.is_empty():
		_executar(indice + 1, sessao)
		return
	_acao = String(passo.get("acao", ""))
	if _acao.is_empty():
		destaque.limpar()
	else:
		destaque.focar(_puzzle.retangulos_da_acao(_acao), true)
	# A meta pode já valer (a pessoa adiantou o que ele ia pedir).
	conferir()


func _terminar() -> void:
	_passo = _roteiro.size()
	_acao = ""
	if is_instance_valid(_puzzle):
		_puzzle.destaque.limpar()
	acabou.emit()


## Para o retangulos_para() dos puzzles: só o pedaço do Label que tem texto
## (os contadores das telas são bem mais largos que o que está escrito neles),
## com folga dos lados e quase nada em cima e embaixo (os contadores vêm
## empilhados, colados uns nos outros).
static func retangulo_do_texto(label: Label) -> Rect2:
	var fonte := label.get_theme_font("font")
	var tamanho := label.get_theme_font_size("font_size")
	var caixa := label.get_global_rect()
	var largura := 0.0
	for linha in label.text.split("\n"):
		largura = maxf(largura, fonte.get_string_size(linha, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x)
	largura *= label.get_global_transform().get_scale().x
	var x := caixa.position.x
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x += (caixa.size.x - largura) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			x += caixa.size.x - largura
	return Rect2(x, caixa.position.y, largura, caixa.size.y).grow_individual(6.0, 1.0, 6.0, 1.0)


## Uma fala do Dr. Chico por cima do puzzle. Volta quando ela acaba.
func _falar(timeline: String, sessao: int) -> void:
	falando = true
	var arvore := _puzzle.get_tree()
	# O Dialogic anda com o jogo pausado (o puzzle pausa o mundo).
	Dialogic.process_mode = Node.PROCESS_MODE_ALWAYS
	var fim := [false]
	var ao_acabar := func() -> void: fim[0] = true
	Dialogic.timeline_ended.connect(ao_acabar, CONNECT_ONE_SHOT)
	var comecou := [false]
	var ao_comecar := func() -> void: comecou[0] = true
	Dialogic.timeline_started.connect(ao_comecar, CONNECT_ONE_SHOT)
	var palco = Dialogic.start(timeline)
	if palco:
		# O puzzle desenha na camada 10: sem isto o diálogo (camada 1) fica
		# atrás dele e os cliques nem chegam na fala.
		palco.set("layer", CAMADA_DA_FALA)
		palco.process_mode = Node.PROCESS_MODE_ALWAYS

	# Rede de segurança: uma timeline que não carregou (arquivo renomeado,
	# erro de sintaxe) nunca acaba, e o roteiro ficaria preso esperando.
	for i in 3:
		await arvore.process_frame
	if Dialogic.timeline_started.is_connected(ao_comecar):
		Dialogic.timeline_started.disconnect(ao_comecar)
	if not comecou[0] and not fim[0]:
		push_warning("Fala do Dr. Chico não carregou: %s" % timeline)
		if Dialogic.timeline_ended.is_connected(ao_acabar):
			Dialogic.timeline_ended.disconnect(ao_acabar)
		Dialogic.end_timeline(true)
		fim[0] = true

	while not fim[0] and sessao == _sessao:
		await arvore.process_frame
	if Dialogic.timeline_ended.is_connected(ao_acabar):
		Dialogic.timeline_ended.disconnect(ao_acabar)
	if sessao == _sessao:
		falando = false
