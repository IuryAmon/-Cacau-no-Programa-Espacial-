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
# todo, suja o topo e fica preso nas bandejas — aí só RECOMEÇAR desfaz. O
# termômetro tem a marca de cada substância e a de onde o fundo ferve agora.
#
# Na história a tela abre por cima da fase (quem abre é o Destilador, na sala
# de destilação). O ESC fecha (a amostra fica na coluna); na primeira vez, o
# Dr. Chico explica pelo rádio ("fala_de_abertura").
#
# DEBUG: a tecla L deixa pronta na hora.

## A pessoa retirou o nitrogênio (a tela vai fechar sozinha).
signal nitrogenio_retirado
## A tela fechou sem terminar (ESC).
signal fechou

## A conversa do Dr. Chico na primeira vez que a tela abre (vazio = sem fala).
@export var fala_de_abertura: String = ""

## Que fração do líquido do topo tem de ser nitrogênio para a amostra servir.
const PUREZA_MINIMA := 0.8
## Que fração de todo o nitrogênio da amostra tem de ter chegado ao topo.
const RECUPERACAO_MINIMA := 0.75

const TXT_A_AMOSTRA := "A AMOSTRA"
const TXT_AR_LIQUIDO := "AR LÍQUIDO DO COMPRESSOR"
const TXT_COMPOSICAO := "78% N₂  ·  21% O₂  ·  1% Ar"
const TXT_META := "ESQUENTE O FUNDO: O VAPOR SAI RICO EM N₂ E O TOPO SE ENCHE DE NITROGÊNIO QUASE PURO. QUENTE DEMAIS, O OXIGÊNIO FERVE TODO E SOBE JUNTO."
const TXT_RETIRAR := "RETIRAR O N₂"
const TXT_PRONTO := "N₂ NO TOPO: %d%%"
const TXT_PURO := "NITROGÊNIO QUASE PURO!"
const TXT_NO_CILINDRO := "O LÍQUIDO DO TOPO TEM %d%% DE N₂ E VAI PARA O CILINDRO VERDE: É A AMOSTRA DO ELEMENTO N. O RESTO É O POUQUINHO DE O₂ E Ar QUE EVAPOROU JUNTO."
const TXT_MISTUROU := "QUENTE DEMAIS: O FUNDO FERVEU ATÉ SECAR, E O OXIGÊNIO SUBIU JUNTO. ESFRIE O FUNDO E RECOMECE."
const TXT_FALTA := "AINDA FALTA NITROGÊNIO CHEGAR AO TOPO: ESQUENTE O FUNDO MAIS UM POUCO."
const TXT_SUBINDO := "O VAPOR SOBE RICO EM NITROGÊNIO E O TOPO VAI ENCHENDO. ESPERE A COLUNA ASSENTAR."
const TXT_SUJO := "O TOPO PEGOU OXIGÊNIO DEMAIS. ESFRIE O FUNDO E RECOMECE, ESQUENTANDO COM CUIDADO."

const CARTAO := Rect2(40, 118, 340, 300)
const BOTAO_RECOMECAR := Rect2(40, 436, 340, 52)
const BOTAO_RETIRAR := Rect2(40, 504, 340, 60)
const TEXTURA_AMOSTRA := preload("res://assets/fase nitrogenio/cilindro de ar liquido.png")
const TEXTURA_N2 := preload("res://assets/fase nitrogenio/cilindro de nitrogenio.png")

enum Estado { JOGANDO, FALANDO, RETIRANDO, FIM }

var _estado: Estado = Estado.JOGANDO
var _relogio: float = 0.0
## A pureza do topo na hora em que a amostra foi retirada (0..1).
var _pureza_retirada: float = 0.0
@onready var frente: Control = get_node_or_null("Frente")


func _ao_abrir() -> void:
	super._ao_abrir()
	# Uma mistura só: a lista do Laboratório sai.
	esquecer_alvos("mistura_")
	escolher_mistura("ar", false)
	registrar_alvo("retirar", func() -> Rect2: return BOTAO_RETIRAR, retirar_nitrogenio, pode_retirar)
	if frente:
		frente.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frente.draw.connect(_desenhar_a_frente)
	if not fala_de_abertura.is_empty():
		_falar(fala_de_abertura)


func retangulo_do_recomecar() -> Rect2:
	return BOTAO_RECOMECAR


func _a_cada_quadro(delta: float) -> void:
	_relogio += delta
	super._a_cada_quadro(delta)
	if frente:
		frente.queue_redraw()


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
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_L:
		coluna.reiniciar()
		coluna.pedir_temperatura(-186.0)
		for i in 60 * 90:
			coluna.avancar(1.0 / 60.0)
			if amostra_pronta():
				break
		return true
	return super._ao_receber(event)


func _ao_pedir_para_voltar() -> void:
	if _estado == Estado.RETIRANDO:
		_terminar()
		return
	if _estado == Estado.FIM:
		return
	_estado = Estado.FIM
	_fechar_a_tela()
	fechou.emit()


func _terminar() -> void:
	if _estado != Estado.RETIRANDO:
		return
	_estado = Estado.FIM
	tocar("botao")
	_fechar_a_tela()
	nitrogenio_retirado.emit()


func _fechar_a_tela() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	var camada := get_parent()
	if camada is CanvasLayer:
		camada.queue_free()
	else:
		queue_free()


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
# O DESENHO
# ─────────────────────────────────────────────────────────────

func _desenhar_o_painel() -> void:
	var fonte := FONTE
	# A amostra, à esquerda (no lugar da lista de misturas do Laboratório).
	EstiloHUD.etiqueta(painel, fonte, Vector2(CARTAO.position.x + PecasDoLaboratorio.largura(TXT_A_AMOSTRA, 11) + 12.0,
		CARTAO.position.y - 30.0), TXT_A_AMOSTRA)
	EstiloHUD.ficha(painel, CARTAO)
	EstiloHUD.icone(painel, TEXTURA_AMOSTRA, CARTAO.position + Vector2(52, 74), 96.0)
	PecasDoLaboratorio.escrever_em_linhas(painel, Rect2(CARTAO.position.x + 104, CARTAO.position.y + 30, 216, 60),
		TXT_AR_LIQUIDO, 15, EstiloHUD.TINTA, 20.0, false)
	PecasDoLaboratorio.escrever(painel, CARTAO.position + Vector2(104, 82), TXT_COMPOSICAO, 13, EstiloHUD.TINTA_FRACA)
	var cor_da_meta := Color("1f7a3d") if amostra_pronta() else EstiloHUD.TINTA
	PecasDoLaboratorio.escrever_em_linhas(painel, Rect2(CARTAO.position.x + 22, CARTAO.position.y + 140, 296, 150),
		TXT_META, 15, cor_da_meta, 21.0, false)

	PecasDoLaboratorio.botao(painel, BOTAO_RECOMECAR, TXT_RECOMECAR, alvo_em_foco() == "recomecar",
		alvo_segurado() == "recomecar", _estado == Estado.JOGANDO, 22, EstiloHUD.PAPEL_DOBRA)
	PecasDoLaboratorio.botao(painel, BOTAO_RETIRAR, TXT_RETIRAR, alvo_em_foco() == "retirar",
		alvo_segurado() == "retirar", pode_retirar(), 24, Color("bfe8c8") if pode_retirar() else EstiloHUD.PAPEL)

	# O aviso de que o modelo é simplificado (o mesmo do Laboratório).
	_escrever_claro(Rect2(CARTAO.position.x, BOTAO_RETIRAR.end.y + 30.0, CARTAO.size.x, 120.0), TXT_MODELO,
		Color(EstiloHUD.TECLA_TAMPA))

	# O nome do que as setas mexem, embaixo delas.
	var linhas := TXT_TERMOMETRO.split("\n")
	for i in linhas.size():
		var largura := PecasDoLaboratorio.largura(linhas[i], 11)
		EstiloHUD.rotulo(painel, fonte, Vector2(roundf(setas.global_position.x + setas.size.x * 0.5 - largura * 0.5),
			setas.global_position.y + setas.size.y + 22.0 + i * 15.0), linhas[i], 11)

	# As fichas das substâncias, à direita (as do Laboratório).
	EstiloHUD.etiqueta(painel, fonte, Vector2(FICHAS.position.x + PecasDoLaboratorio.largura(TXT_SUBSTANCIAS, 11) + 12.0,
		FICHAS.position.y - 30.0), TXT_SUBSTANCIAS)
	var lista := substancias()
	for i in lista.size():
		_desenhar_a_ficha(retangulo_da_ficha(i), lista[i])

	var meio := Vector2(FICHAS.position.x + FICHAS.size.x * 0.5, retangulo_da_ficha(lista.size()).position.y + 34.0)
	if amostra_pronta():
		PecasDoLaboratorio.plaquinha(painel, meio, aviso(), 22, Color("9be28a"), 1.0, sin(_pulo_do_aviso * PI) * 6.0)
	else:
		_escrever_claro(Rect2(FICHAS.position.x, meio.y - 22.0, FICHAS.size.x, 120.0), aviso(),
			Color("ffb3a8") if misturou() else EstiloHUD.CLARO)


## O aviso embaixo das fichas: pronta (a plaquinha verde, com a pureza), quente
## demais, falta esquentar, subindo, ou como começar.
func aviso() -> String:
	if amostra_pronta():
		return TXT_PRONTO % roundi(pureza_do_topo() * 100.0)
	if misturou():
		return TXT_MISTUROU if secou() else TXT_SUJO
	if coluna.parada() and coluna.temperatura_pedida() > float(mistura().get("minima", 0.0)):
		# Assentou sem ficar pronta nem passar do ponto: o nitrogênio ainda não
		# subiu o bastante (ou o fundo nem chegou a ferver).
		return TXT_FALTA
	if coluna.fervendo(0) or coluna.em_transito() > 0:
		return TXT_SUBINDO
	return TXT_COMECO


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
	EstiloHUD.icone(frente, TEXTURA_N2, Vector2(meio_x, caixa.position.y + 160.0 + pulo), 140.0, Color(1, 1, 1, t))
	PecasDoLaboratorio.escrever_em_linhas(frente, Rect2(caixa.position.x + 40.0, caixa.position.y + 250.0, caixa.size.x - 80.0, 100.0),
		TXT_NO_CILINDRO % roundi(_pureza_retirada * 100.0), 15, EstiloHUD.com_alfa(EstiloHUD.TINTA, t), 21.0)
	if _relogio > 0.6:
		EstiloHUD.tecla_da_folha(frente, FONTE, caixa, t)
