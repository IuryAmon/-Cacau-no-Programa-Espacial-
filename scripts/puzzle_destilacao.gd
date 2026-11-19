class_name TelaDaDestilacao
extends "res://scripts/laboratorio/destilador.gd"

# --- A DESTILAÇÃO DA AMOSTRA (fase do nitrogênio) ---
#
# O fim do caminho do nitrogênio. A amostra de ar líquido que a Cacau trouxe
# correndo do compressor entra na coluna de destilação, e agora é ELA quem
# manda no calor do fundo. É o simulador do Laboratório (scripts/laboratorio/
# destilador.gd) com uma mistura só — o ar da amostra — e um objetivo:
#
#   ENRIQUECER O TOPO   o ar ferve a uns -194 °C, e o vapor que sai é rico em
#                       nitrogênio (o que evapora mais fácil), mas leva um pouco
#                       de oxigênio e argônio junto. Subindo pelas bandejas ele
#                       condensa e evapora de novo, e chega ao topo cada vez
#                       mais rico. Esquentando o fundo, o nitrogênio vai saindo
#                       dele; quando quase todo já subiu e o topo tem pelo menos
#                       PUREZA_MINIMA de N₂, a amostra está pronta.
#   RETIRAR O N₂        o botão acende: o líquido do topo vai para o cilindro
#                       verde — a amostra do elemento N. Quase pura: o
#                       pouquinho de oxigênio e argônio que veio junto aparece
#                       na porcentagem.
#
# A conta é a da coluna do simulador (ColunaDoSimulador). Frio demais (abaixo
# de uns -190 °C), o nitrogênio fica no fundo: falta esquentar. Quente demais
# (acima dos -183 °C do oxigênio), o fundo ferve até secar: o oxigênio sobe
# todo, suja o topo e fica preso nas bandejas — aí só RECOMEÇAR desfaz.
#
# A TELA é a mesma do compressor, cada coisa num lugar só e o mínimo de texto:
#   embaixo do título   UMA frase do que fazer agora (com a temperatura em que
#                       o ar ferve, no começo; laranja quando passou do ponto,
#                       verde quando está pronta);
#   à esquerda          a amostra: o que tem nela, com a molécula de cada
#                       substância (a legenda das cores da coluna), quanto do ar
#                       ela é e onde ferve;
#   no meio             a coluna, só com a régua das temperaturas (o resfriador
#                       em cima, o calor embaixo), e o termômetro do fundo, com
#                       a marca de onde cada substância ferve;
#   à direita           o OBJETIVO — o nitrogênio no topo, com a barrinha de
#                       quanto falta, e a condição de o oxigênio ficar no
#                       fundo — e os botões;
#   no pé               as teclas.
# O que o Laboratório mostra a mais (as plaquinhas de cada andar, a marca do
# ponto de bolha que anda, as fichas com onde está cada substância, o aviso do
# modelo simplificado) fica só lá.
#
# NO MAPA: na história a tela não troca. Quem abre é o Destilador, na sala de
# destilação: a câmera chega perto da coluna (ZoomNoObjeto) e a tela nasce em
# cima dela ("coluna_no_mundo" é onde a coluna de aço está na tela). Sem fundo:
# a coluna em raio X cai exatamente em cima da arte do mapa (as duas são a
# mesma arte, 4 px da tela por pixel dela), e uma linha de luz desce trocando
# o aço pelo raio X (VarreduraRaioX); depois aparecem o termômetro, as setas e
# os painéis, do lado da sala que tiver mais espaço. Fechando, tudo some ao
# contrário. O ESC fecha (a amostra fica na coluna); na primeira vez, o Dr.
# Chico explica pelo rádio ("fala_de_abertura"). Sem "coluna_no_mundo" (os
# testes), é a tela inteira de sempre, com o fundo do laboratório.
#
# O MOUSE: o ponteiro do termômetro é o que se arrasta. Em cima dele, a seta do
# mouse vira a mãozinha (MaoDoMouse); e, até a pessoa arrastar pela primeira
# vez, uma mão desenhada mostra o gesto em cima dele (DicaDeArrastar).
#
# CONTROLES: o termômetro como no Laboratório (arrastar, as setas, W/S ou ↑/↓);
# E retira o nitrogênio quando a amostra fica pronta.
# DEBUG: a tecla L deixa pronta na hora.

## A pessoa retirou o nitrogênio (a tela fechou).
signal nitrogenio_retirado
## A tela fechou sem terminar (ESC).
signal fechou
## No mapa: o raio X acabou de cobrir a coluna de aço (ela pode sumir) / vai
## começar a sair (ela tem de voltar a aparecer por baixo).
signal revelada
signal escondendo

## A conversa do Dr. Chico na primeira vez que a tela abre (vazio = sem fala).
@export var fala_de_abertura: String = ""

## No mapa: onde a coluna de aço está na tela (o Destilador diz, antes de pôr a
## tela na árvore). Sem área, a tela inteira de sempre.
var coluna_no_mundo: Rect2 = Rect2()

## A pessoa já arrastou o ponteiro do termômetro alguma vez (a mão que mostra o
## gesto não volta mais).
static var arrastou_o_termometro: bool = false

## Que fração do líquido do topo tem de ser nitrogênio para a amostra servir.
const PUREZA_MINIMA := 0.8
## Que fração de todo o nitrogênio da amostra tem de ter chegado ao topo.
const RECUPERACAO_MINIMA := 0.75

const TXT_A_AMOSTRA := "A AMOSTRA"
const TXT_AR_LIQUIDO := "AR LÍQUIDO"
const TXT_DO_COMPRESSOR := "DO COMPRESSOR"
## Quanto do ar é cada substância (o ar de verdade; a coluna tem poucas
## moléculas, com o argônio aumentado para aparecer).
const PORCENTAGEM_NO_AR := {"N2": 78, "O2": 21, "Ar": 1}
const TXT_PORCENTAGEM := "%d%%"
const TXT_FERVE_A := "FERVE A %s"
const TXT_TEMPERATURA_DO_FUNDO := "TEMPERATURA DO FUNDO"
const TXT_TECLA_TEMPERATURA := "TEMPERATURA"
const TXT_O_OBJETIVO := "OBJETIVO"
const TXT_META_1 := "NITROGÊNIO NO TOPO"
const TXT_META_2 := "OXIGÊNIO FICA NO FUNDO (ATÉ %s)"
const TXT_RETIRAR := "RETIRAR O N₂"

## A frase do que fazer, embaixo do título — uma só, a mais urgente agora.
const TXT_COMECAR := "SUBA A TEMPERATURA DO FUNDO: O AR FERVE A %s."
const TXT_SUBINDO := "O VAPOR SOBE RICO EM NITROGÊNIO. ESPERE A COLUNA ASSENTAR."
const TXT_FALTA := "AINDA TEM NITROGÊNIO NO FUNDO: ESQUENTE MAIS UM POUCO."
const TXT_PRONTO := "PRONTO! O TOPO TEM %d%% DE NITROGÊNIO: RETIRE O N₂."
const TXT_MISTUROU := "QUENTE DEMAIS: O OXIGÊNIO FERVEU E SUBIU JUNTO. RECOMECE."
const TXT_SUJO := "O TOPO PEGOU OXIGÊNIO DEMAIS. RECOMECE, ESQUENTANDO MENOS."

## A comemoração.
const TXT_PURO := "NITROGÊNIO QUASE PURO!"
const TXT_NO_CILINDRO := "%d%% DE NITROGÊNIO NO CILINDRO"
const TXT_O_RESTO := "O RESTO É O POUQUINHO DE O₂ E Ar QUE EVAPOROU JUNTO: NA DESTILAÇÃO, NADA SAI PURO DE TUDO."

## As cores da frase do que fazer.
const COR_DA_DICA_PERIGO := Color("ffb347")
const COR_DA_DICA_PRONTA := Color("9be28a")

## Onde ficam as coisas na tela inteira (px da tela): à esquerda a amostra; à
## direita o objetivo e, embaixo dele, os botões. No mapa eles vão para o lado
## da coluna com mais espaço (ver _montar_no_mundo).
const CARTAO := Rect2(40, 118, 340, 284)
const PAINEL_OBJETIVO := Rect2(1300, 118, 270, 0)
const BOTAO_RETIRAR := Rect2(1300, 290, 270, 56)
const BOTAO_RECOMECAR := Rect2(1300, 364, 270, 44)
const ALTURA_DA_DICA := 76.0
const ALTURA_DAS_TECLAS := 866.0
## No mapa: o vão entre a coluna e o termômetro (o ponteiro mora nele); o que
## a régua e os nomes dela ocupam à esquerda da coluna; e, à direita dela, até
## onde vão o vão, o termômetro e as setas. (A Cacau sai de cima disso antes
## de a câmera chegar perto: ver Destilador.)
const VAO_ATE_O_TERMOMETRO := 90.0
const LARGURA_DA_REGUA_E_NOMES := 150.0
const ALCANCE_A_DIREITA := VAO_ATE_O_TERMOMETRO + 130.0
## No mapa, a frase do que fazer sobe para o lugar do título (que não aparece).
const ALTURA_DA_DICA_NO_MAPA := 44.0
## Quanto tempo os painéis levam para aparecer e sumir, no mapa.
const DURACAO_DOS_PAINEIS := 0.3
## Na ficha da amostra: onde começa a lista das substâncias e a altura de cada
## uma.
const COMECO_DA_LISTA := 132.0
const ALTURA_DA_SUBSTANCIA := 50.0
const TEXTURA_AMOSTRA := preload("res://assets/fase nitrogenio/cilindro de ar liquido.png")
const TEXTURA_N2 := preload("res://assets/fase nitrogenio/cilindro de nitrogenio.png")

enum Estado { JOGANDO, FALANDO, RETIRANDO, FIM }

var _estado: Estado = Estado.JOGANDO
var _relogio: float = 0.0
## A pureza do topo na hora em que a amostra foi retirada (0..1).
var _pureza_retirada: float = 0.0
## As duas metas do OBJETIVO (para o quadradinho inchar quando uma se cumpre).
var _metas: Array[bool] = [false, true]
var _pulo_da_meta: Array[float] = [0.0, 0.0]
## Onde os painéis estão agora (os da tela inteira, ou os do mapa).
var _cartao: Rect2 = CARTAO
var _painel_objetivo: Rect2 = PAINEL_OBJETIVO
var _botao_retirar: Rect2 = BOTAO_RETIRAR
var _botao_recomecar: Rect2 = BOTAO_RECOMECAR
var _altura_da_dica: float = ALTURA_DA_DICA
var _varredura: VarreduraRaioX = null
var _dica_do_mouse: DicaDeArrastar = null
@onready var frente: Control = get_node_or_null("Frente")


func _ao_abrir() -> void:
	# Só a régua ao lado da coluna: a temperatura do fundo está no termômetro.
	coluna.com_plaquinhas = false
	if no_mundo():
		_montar_no_mundo()
	super._ao_abrir()
	# Uma mistura só: a lista do Laboratório sai.
	esquecer_alvos("mistura_")
	escolher_mistura("ar", false)
	registrar_alvo("retirar", func() -> Rect2: return _botao_retirar, retirar_nitrogenio, pode_retirar)
	_metas = [_meta(0), _meta(1)]
	if frente:
		frente.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frente.draw.connect(_desenhar_a_frente)
	_dica_do_mouse = DicaDeArrastar.new()
	_dica_do_mouse.name = "DicaDoMouse"
	add_child(_dica_do_mouse)
	if no_mundo():
		_entrar_no_mundo()
		return
	if not fala_de_abertura.is_empty():
		_falar(fala_de_abertura)
	_mostrar_a_dica_do_mouse()


## Aberta em cima da coluna do mapa?
func no_mundo() -> bool:
	return coluna_no_mundo.has_area()


func retangulo_do_recomecar() -> Rect2:
	return _botao_recomecar


# ─────────────────────────────────────────────────────────────
# NO MAPA (em cima da coluna de aço)
# ─────────────────────────────────────────────────────────────

## A coluna em cima da do mapa, o termômetro e as setas à direita dela (como na
## cena), e os painéis empilhados do lado com mais espaço. Sem fundo e sem a
## plaquinha do título: a sala aparece em volta (escurecida pelo véu do
## ZoomNoObjeto).
func _montar_no_mundo() -> void:
	titulo = ""
	var fundo := get_node_or_null("Fundo") as CanvasItem
	if fundo:
		fundo.visible = false
	coluna.position = coluna_no_mundo.position.round()
	coluna.size = coluna_no_mundo.size.round()
	termometro.position = Vector2(coluna.position.x + coluna.size.x + VAO_ATE_O_TERMOMETRO, coluna.position.y + 16.0)
	termometro.size = Vector2(termometro.size.x, roundf(coluna.size.y * 0.75))
	setas.position = Vector2(roundf(termometro.position.x + (termometro.size.x - setas.size.x) * 0.5),
		termometro.position.y + termometro.size.y + 12.0)

	# Os painéis: a ficha da amostra, o objetivo e os botões, um embaixo do
	# outro, do lado em que sobra mais tela.
	var largura := CARTAO.size.x
	var sobra_na_esquerda := coluna.position.x - LARGURA_DA_REGUA_E_NOMES
	var sobra_na_direita := size.x - (termometro.position.x + termometro.size.x + 110.0)
	var x := 40.0 if sobra_na_esquerda >= sobra_na_direita else size.x - 40.0 - largura
	# Sem espaço para a largura toda, eles encolhem até o que couber.
	var cabe := maxf(sobra_na_esquerda, sobra_na_direita) - 60.0
	if cabe < largura:
		largura = maxf(cabe, 260.0)
		if x > 40.0:
			x = size.x - 40.0 - largura
	var y := coluna.position.y
	_cartao = Rect2(x, y, largura, CARTAO.size.y)
	_painel_objetivo = Rect2(x, _cartao.end.y + 24.0, largura, 0.0)
	var fim_do_objetivo := _painel_objetivo.position.y + PecasDoLaboratorio.altura_da_lista_de_metas(2)
	_botao_retirar = Rect2(x, fim_do_objetivo + 22.0, largura, BOTAO_RETIRAR.size.y)
	_botao_recomecar = Rect2(x, _botao_retirar.end.y + 16.0, largura, BOTAO_RECOMECAR.size.y)
	_altura_da_dica = ALTURA_DA_DICA_NO_MAPA

	# A linha do raio X passa pela coluna e pela régua dela, de cima a baixo.
	_varredura = VarreduraRaioX.new()
	_varredura.name = "Varredura"
	coluna.add_sibling(_varredura)
	# (Começa um pouco acima: o contorno da régua passa 2 px do alto da coluna.)
	_varredura.preparar(coluna, -8.0, coluna.size.y, -LARGURA_DA_REGUA_E_NOMES, coluna.size.x)


## A entrada: a linha desce trocando o aço pelo raio X, e só então aparecem o
## termômetro, as setas e os painéis. Enquanto isso, a tela não responde.
func _entrar_no_mundo() -> void:
	bloqueada = true
	_varredura.esconder_na_hora()
	_mostrar_os_paineis(0.0)
	await get_tree().process_frame
	_varredura.revelar()
	await _varredura.terminou
	revelada.emit()
	var aparecer := novo_tween()
	aparecer.tween_method(_mostrar_os_paineis, 0.0, 1.0, DURACAO_DOS_PAINEIS)
	await aparecer.finished
	bloqueada = false
	if not fala_de_abertura.is_empty():
		_falar(fala_de_abertura)
	_mostrar_a_dica_do_mouse()


## A saída: os painéis somem, a linha sobe apagando o raio X e a coluna de aço
## volta a aparecer por baixo.
func _sair_do_mundo() -> void:
	bloqueada = true
	_dica_do_mouse.parar()
	var sumir := novo_tween()
	sumir.tween_method(_mostrar_os_paineis, painel.modulate.a, 0.0, DURACAO_DOS_PAINEIS * 0.6)
	await sumir.finished
	escondendo.emit()
	_varredura.esconder()
	await _varredura.terminou


## O quanto aparecem (0 a 1) as coisas que não são a coluna.
func _mostrar_os_paineis(alfa: float) -> void:
	for no: CanvasItem in [painel, termometro, setas, _moldura, frente, _dica_do_mouse]:
		if no:
			no.modulate.a = alfa


# ─────────────────────────────────────────────────────────────
# A MÃO QUE MOSTRA O GESTO (até a primeira vez que a pessoa arrasta)
# ─────────────────────────────────────────────────────────────

func _mostrar_a_dica_do_mouse() -> void:
	if arrastou_o_termometro or _dica_do_mouse == null:
		return
	# Para cima: o começo é sempre esquentar o fundo. A mão pega pela ponta da
	# plaquinha (a seta), para o número continuar à vista.
	_dica_do_mouse.mostrar(termometro.retangulo_do_ponteiro_na_tela, Vector2.UP, 44.0, Vector2(0.86, 0.5))


func _pegar_o_ponteiro() -> void:
	super._pegar_o_ponteiro()
	arrastou_o_termometro = true
	if _dica_do_mouse:
		_dica_do_mouse.parar()


func _a_cada_quadro(delta: float) -> void:
	_relogio += delta
	super._a_cada_quadro(delta)
	for i in _metas.size():
		var agora := _meta(i)
		if agora and not _metas[i]:
			_pulo_da_meta[i] = 1.0
		_metas[i] = agora
		_pulo_da_meta[i] = move_toward(_pulo_da_meta[i], 0.0, delta / 0.4)
	if frente:
		frente.queue_redraw()
	if _dica_do_mouse:
		_dica_do_mouse.pausada = _estado != Estado.JOGANDO or bloqueada
		_dica_do_mouse.ponteiro_em_cima = alvo_sob_o_ponteiro() == "termometro"


## No termômetro, só as marcas de onde cada substância ferve. (A do ponto de
## bolha do fundo, que anda, é do Laboratório: aqui, quem diz em que
## temperatura o ar ferve é a frase do que fazer.)
func _atualizar_as_marcas() -> void:
	# Quem troca a mistura apaga o _marca_do_fundo: só então refaz.
	if not is_nan(_marca_do_fundo):
		return
	_marca_do_fundo = 0.0
	var marcas: Array[Dictionary] = []
	for substancia in substancias():
		marcas.append({"chave": substancia, "graus": MisturasDoDestilador.ebulicao(substancia)})
	termometro.definir_marcas(marcas)


# ─────────────────────────────────────────────────────────────
# O OBJETIVO
# ─────────────────────────────────────────────────────────────

## O andar de cima, onde o nitrogênio se junta.
func _topo() -> int:
	return coluna.andares() - 1


## Que fração do líquido do topo é nitrogênio (0..1).
func pureza_do_topo() -> float:
	return coluna.fracao(_topo(), "N2")


## Que fração de todo o nitrogênio da amostra já está no topo (0..1).
func recuperacao() -> float:
	var total := int(mistura()["substancias"].get("N2", 0))
	if total <= 0:
		return 0.0
	return float(coluna.contas_do_andar(_topo()).get("N2", 0)) / float(total)


## O fundo ferveu até secar: até o oxigênio subiu (só recomeçando).
func secou() -> bool:
	return coluna.contas_do_andar(0).is_empty()


## A coluna parou, o fundo ficou com o oxigênio (é a maioria lá) e o topo
## juntou quase todo o nitrogênio, rico o bastante.
func amostra_pronta() -> bool:
	return coluna.parada() and not secou() and coluna.dono_do_andar(0) == "O2" \
		and recuperacao() >= RECUPERACAO_MINIMA and pureza_do_topo() >= PUREZA_MINIMA


## A amostra está pronta: dá para tirar o nitrogênio do topo.
func pode_retirar() -> bool:
	return _estado == Estado.JOGANDO and amostra_pronta()


## Que fração do líquido retirado é nitrogênio (0..1): a porcentagem que a
## comemoração mostra. 0 enquanto nada foi retirado.
func pureza_retirada() -> float:
	return _pureza_retirada


func retirar_nitrogenio() -> void:
	if not pode_retirar():
		tocar("erro")
		return
	_pureza_retirada = pureza_do_topo()
	_estado = Estado.RETIRANDO
	_relogio = 0.0
	tocar("sucesso")


## O fundo ferveu até secar e o oxigênio subiu: na coluna, o que virou líquido
## numa bandeja fica nela — só recomeçando. (Também quando o topo, parado,
## ficou sujo demais para servir.)
func misturou() -> bool:
	if secou():
		return true
	return coluna.parada() and recuperacao() >= RECUPERACAO_MINIMA and pureza_do_topo() < PUREZA_MINIMA


## Ainda não subiu nada: todo o ar está no fundo.
func _nada_subiu() -> bool:
	return coluna.contas_do_andar(0).values().reduce(func(soma: int, n: int) -> int: return soma + n, 0) \
		== coluna.total_de_moleculas()


## As metas do OBJETIVO: 0 o nitrogênio chegou ao topo (quase todo), 1 o
## oxigênio ficou no fundo (vale até o fundo ferver o oxigênio, ou o topo
## sujar).
func _meta(i: int) -> bool:
	if i == 0:
		return recuperacao() >= RECUPERACAO_MINIMA
	return not misturou()


func _ao_receber(event: InputEvent) -> bool:
	if _estado == Estado.RETIRANDO:
		if (event.is_action_pressed(Interacao.ACAO) or event.is_action_pressed("ui_accept")) and _relogio > 0.6:
			_terminar()
			return true
		if event is InputEventMouseButton and event.pressed and _relogio > 0.6:
			_terminar()
			return true
		return false
	if _estado != Estado.JOGANDO:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		if OS.is_debug_build() and (event as InputEventKey).physical_keycode == KEY_L:
			coluna.reiniciar()
			coluna.pedir_temperatura(-186.0)
			for i in 60 * 90:
				coluna.avancar(1.0 / 60.0)
				if amostra_pronta():
					break
			return true
		# O E retira (só do TECLADO: o ✕ do controle clica no botão).
		if event.is_action_pressed(Interacao.ACAO) and pode_retirar():
			retirar_nitrogenio()
			return true
	return super._ao_receber(event)


func _ao_pedir_para_voltar() -> void:
	if _estado == Estado.RETIRANDO:
		_terminar()
		return
	if _estado == Estado.FIM:
		return
	_estado = Estado.FIM
	_fechar_a_tela(fechou)


func _terminar() -> void:
	if _estado != Estado.RETIRANDO:
		return
	_estado = Estado.FIM
	tocar("botao")
	_fechar_a_tela(nitrogenio_retirado)


## Fecha a tela e, depois, dá o sinal (no mapa, depois de o raio X sair).
func _fechar_a_tela(sinal: Signal) -> void:
	arrastando_com_o_mouse = false
	_arrastando = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if no_mundo() and is_inside_tree():
		await _sair_do_mundo()
	var camada := get_parent()
	if camada is CanvasLayer:
		camada.queue_free()
	else:
		queue_free()
	sinal.emit()


func _falar(timeline: String) -> void:
	if Dialogic.current_timeline != null:
		return
	_estado = Estado.FALANDO
	Dialogic.process_mode = Node.PROCESS_MODE_ALWAYS
	var palco: Node = Dialogic.start(timeline)
	if palco != null:
		var camada := get_parent()
		palco.set("layer", (camada as CanvasLayer).layer + 10 if camada is CanvasLayer else 20)
		palco.process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 3:
		await get_tree().process_frame
	while Dialogic.current_timeline != null and is_inside_tree():
		await get_tree().process_frame
	if is_inside_tree() and _estado == Estado.FALANDO:
		_estado = Estado.JOGANDO


# ─────────────────────────────────────────────────────────────
# A FRASE DO QUE FAZER
# ─────────────────────────────────────────────────────────────

## A frase embaixo do título: pronta (com a pureza do topo), quente demais,
## subindo, como começar (com a temperatura em que o ar ferve) ou falta
## esquentar.
func aviso() -> String:
	if amostra_pronta():
		return TXT_PRONTO % roundi(pureza_do_topo() * 100.0)
	if misturou():
		return TXT_MISTUROU if secou() else TXT_SUJO
	if coluna.fervendo(0) or coluna.em_transito() > 0:
		return TXT_SUBINDO
	if _nada_subiu():
		return TXT_COMECAR % MisturasDoDestilador.graus(roundf(coluna.bolha_do_fundo()))
	if coluna.parada():
		# Assentou sem ficar pronta nem passar do ponto: o nitrogênio ainda não
		# subiu o bastante.
		return TXT_FALTA
	return TXT_SUBINDO


func _cor_do_aviso() -> Color:
	if amostra_pronta():
		return COR_DA_DICA_PRONTA
	if misturou():
		return COR_DA_DICA_PERIGO
	return EstiloHUD.CLARO


# ─────────────────────────────────────────────────────────────
# O DESENHO
# ─────────────────────────────────────────────────────────────

func _desenhar_o_painel() -> void:
	if _estado == Estado.JOGANDO or _estado == Estado.FALANDO:
		PecasDoLaboratorio.escrever_claro_no_meio(painel, Vector2(size.x * 0.5, _altura_da_dica), aviso(), 15,
			_cor_do_aviso())
	_desenhar_a_amostra()

	# O nome do termômetro, em cima dele.
	var termo := termometro.get_global_rect()
	PecasDoLaboratorio.escrever_claro_no_meio(painel, Vector2(termo.get_center().x, termo.position.y - 14.0),
		TXT_TEMPERATURA_DO_FUNDO, 11)

	# O objetivo e os botões, à direita.
	var metas := [
		{"texto": TXT_META_1, "feita": _metas[0], "pulo": _pulo_da_meta[0],
			"progresso": recuperacao() / RECUPERACAO_MINIMA},
		{"texto": TXT_META_2 % MisturasDoDestilador.graus(MisturasDoDestilador.ebulicao("O2")), "feita": _metas[1],
			"pulo": _pulo_da_meta[1]},
	]
	var caixa := _painel_objetivo
	caixa.size.y = PecasDoLaboratorio.altura_da_lista_de_metas(metas.size())
	PecasDoLaboratorio.lista_de_metas(painel, caixa, TXT_O_OBJETIVO, metas)
	PecasDoLaboratorio.botao(painel, _botao_retirar, TXT_RETIRAR, alvo_em_foco() == "retirar",
		alvo_segurado() == "retirar", pode_retirar(), 22, Color("bfe8c8") if pode_retirar() else EstiloHUD.PAPEL)
	PecasDoLaboratorio.botao(painel, _botao_recomecar, TXT_RECOMECAR, alvo_em_foco() == "recomecar",
		alvo_segurado() == "recomecar", _estado == Estado.JOGANDO, 18, EstiloHUD.PAPEL_DOBRA)

	PecasDoLaboratorio.dicas_de_teclado(painel, Vector2(size.x * 0.5, ALTURA_DAS_TECLAS), [
		[["tecla_w", "tecla_s"], TXT_TECLA_TEMPERATURA],
		[["tecla_e"], TXT_RETIRAR],
	])


## A ficha da amostra: o cilindro de ar líquido e, embaixo, uma linha por
## substância — a molécula (é a legenda das cores da coluna), o nome, quanto
## do ar ela é e onde ferve (a mesma marca do termômetro).
func _desenhar_a_amostra() -> void:
	var caixa := _cartao
	EstiloHUD.ficha(painel, caixa)
	PecasDoLaboratorio.escrever(painel, caixa.position + Vector2(18, 16), TXT_A_AMOSTRA, 13, EstiloHUD.TINTA_FRACA)
	EstiloHUD.icone(painel, TEXTURA_AMOSTRA, caixa.position + Vector2(44, 84), 64.0)
	PecasDoLaboratorio.escrever(painel, caixa.position + Vector2(84, 58), TXT_AR_LIQUIDO, 22, EstiloHUD.TINTA)
	PecasDoLaboratorio.escrever(painel, caixa.position + Vector2(84, 88), TXT_DO_COMPRESSOR, 11, EstiloHUD.TINTA_FRACA)
	# O fio que separa o cilindro da lista.
	painel.draw_rect(Rect2(caixa.position.x + 18.0, caixa.position.y + COMECO_DA_LISTA - 14.0, caixa.size.x - 36.0, 2.0),
		Color(EstiloHUD.TINTA_FRACA, 0.35))
	var lista := substancias()
	for i in lista.size():
		var chave := lista[i]
		var y := caixa.position.y + COMECO_DA_LISTA + i * ALTURA_DA_SUBSTANCIA
		var lado := float(MoleculasDoDestilador.celula(chave).x) * MoleculasDoDestilador.ESCALA
		MoleculasDoDestilador.desenhar(painel, chave, Vector2(caixa.position.x + 44.0, y + 18.0), 0,
			2.0 if lado * 2.0 <= 56.0 else 1.0)
		PecasDoLaboratorio.escrever(painel, Vector2(caixa.position.x + 84.0, y), String(MisturasDoDestilador.substancia(chave)["nome"]),
			18, EstiloHUD.TINTA)
		PecasDoLaboratorio.escrever(painel, Vector2(caixa.position.x + 84.0, y + 24.0),
			TXT_FERVE_A % MisturasDoDestilador.graus(MisturasDoDestilador.ebulicao(chave)), 11, EstiloHUD.TINTA_FRACA)
		var parte := TXT_PORCENTAGEM % int(PORCENTAGEM_NO_AR.get(chave, 0))
		PecasDoLaboratorio.escrever(painel, Vector2(caixa.end.x - 18.0 - PecasDoLaboratorio.largura(parte, 18), y), parte,
			18, EstiloHUD.TINTA)


## A comemoração: o cilindro verde, cheio de nitrogênio (quase puro).
func _desenhar_a_frente() -> void:
	if _estado != Estado.RETIRANDO:
		return
	var t := clampf(_relogio / 0.35, 0.0, 1.0)
	frente.draw_rect(Rect2(Vector2.ZERO, size), Color(EstiloHUD.VEU, 0.55 * t))
	var caixa := Rect2(500, 230, 600, 380)
	caixa.position.y += roundf((1.0 - ease(t, 0.3)) * 40.0)
	EstiloHUD.ficha(frente, caixa, t)
	var meio_x := caixa.get_center().x
	PecasDoLaboratorio.escrever_no_meio(frente, Vector2(meio_x, caixa.position.y + 50.0), TXT_PURO, 32,
		EstiloHUD.com_alfa(Color("1f7a3d"), t))
	var pulo := sin(_relogio * 3.0) * 4.0
	EstiloHUD.icone(frente, TEXTURA_N2, Vector2(meio_x, caixa.position.y + 154.0 + pulo), 130.0, Color(1, 1, 1, t))
	PecasDoLaboratorio.escrever_no_meio(frente, Vector2(meio_x, caixa.position.y + 252.0),
		TXT_NO_CILINDRO % roundi(_pureza_retirada * 100.0), 20, EstiloHUD.com_alfa(EstiloHUD.TINTA, t))
	PecasDoLaboratorio.escrever_em_linhas(frente, Rect2(caixa.position.x + 50.0, caixa.position.y + 284.0, caixa.size.x - 100.0, 60.0),
		TXT_O_RESTO, 13, EstiloHUD.com_alfa(EstiloHUD.TINTA_FRACA, t), 19.0)
	if _relogio > 0.6:
		EstiloHUD.tecla_da_folha(frente, FONTE, caixa, t)
