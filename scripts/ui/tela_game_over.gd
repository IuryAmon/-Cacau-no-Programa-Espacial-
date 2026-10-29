class_name TelaGameOver
extends TelaInterativa

# --- O FIM DE JOGO (o cilindro estourou) ---
#
# Aparece quando o cilindro da fase do nitrogênio estoura — no puzzle do
# compressor (apertado demais, ou aquecido demais) ou na corrida até a coluna
# de destilação (a amostra esquentou). Não é só um "perdeu": a tela EXPLICA a
# física do que aconteceu, com a pressão em que ele estourou, e oferece tentar
# de novo.
#
#   GAME OVER            letra por letra, caindo e quicando, com um baque na
#                        tela a cada uma;
#   O CILINDRO ESTOUROU! logo embaixo;
#   O QUE ACONTECEU      a ficha de papel com a explicação (muda com o motivo)
#                        e o manômetro parado no vermelho, na pressão final;
#   TENTAR DE NOVO       o botão (E, ENTER, ESPAÇO, ✕ ou o clique).
#
# Ela é posta por cima de tudo (camada CAMADA), pausa o jogo e só sai pelo
# botão. O que "tentar de novo" faz é de quem a chamou (o puzzle recomeça na
# hora; a corrida volta para o compressor).
#
#   TelaGameOver.mostrar(get_tree(), {"motivo": "compressao", "pressao": 4.4},
#       func() -> void: ...)
#
# Motivos: "compressao" (apertou sem resfriar), "aquecimento" (aqueceu o gás
# preso) e "amostra" (a amostra esquentou no caminho).

const CAMADA := 120

const TXT_GAME_OVER := "GAME OVER"
const TXT_ESTOUROU := "O CILINDRO ESTOUROU!"
const TXT_O_QUE := "O QUE ACONTECEU"
const TXT_TENTAR := "TENTAR DE NOVO"
const TXT_PRESSAO_FINAL := "PRESSÃO FINAL"
const TXT_EXPLICACOES := {
	"compressao": "A pressão chegou a %s atm, e o cilindro só aguenta 4. Apertar o ar diminui o volume: as moléculas batem mais vezes nas paredes. E apertar também ESQUENTA o gás, então elas batem mais forte. Resfrie o ar antes de apertar!",
	"aquecimento": "A pressão chegou a %s atm, e o cilindro só aguenta 4. Esquentar o gás preso faz as moléculas correrem mais e baterem mais forte nas paredes: a pressão sobe junto com a temperatura.",
	"amostra": "O calor da sala foi entrando no cilindro: o ar líquido ferveu, virou gás de novo e a pressão passou de 4 atm (chegou a %s). Quanto mais fria e líquida a amostra sai do compressor, mais tempo ela aguenta. Corra direto para a coluna de destilação!",
}

const BOTAO := Rect2(600, 690, 400, 66)
const FICHA := Rect2(380, 352, 840, 262)

var dados: Dictionary = {}
var ao_tentar_de_novo: Callable = Callable()

var _tempo: float = 0.0
var _saindo: bool = false
var _desenho: Control


## Põe a tela por cima de tudo, para o jogo e espera o botão.
static func mostrar(arvore: SceneTree, dados_do_fim: Dictionary, tentar_de_novo: Callable) -> TelaGameOver:
	var camada := CanvasLayer.new()
	camada.name = "FimDeJogo"
	camada.layer = CAMADA
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	var tela := TelaGameOver.new()
	tela.name = "TelaGameOver"
	tela.dados = dados_do_fim
	tela.ao_tentar_de_novo = tentar_de_novo
	tela.texto_de_voltar = ""
	tela.navegar_com_teclas = true
	tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tela.mouse_filter = Control.MOUSE_FILTER_STOP
	camada.add_child(tela)
	var raiz: Node = arvore.current_scene if arvore.current_scene != null else arvore.root
	raiz.add_child(camada)
	arvore.paused = true
	Engine.time_scale = 1.0
	return tela


func _ao_abrir() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_desenho = Control.new()
	_desenho.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desenho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desenho.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_desenho.draw.connect(_desenhar)
	add_child(_desenho)
	move_child(_desenho, 0)
	registrar_alvo("tentar_de_novo", func() -> Rect2: return BOTAO, tentar_de_novo,
		func() -> bool: return _tempo > 1.2 and not _saindo)
	tocar("erro")


func _a_cada_quadro(delta: float) -> void:
	_tempo += delta
	if _tempo > 1.2 and alvo_em_foco().is_empty():
		focar("tentar_de_novo")
	_desenho.queue_redraw()


func _ao_pedir_para_voltar() -> void:
	tentar_de_novo()


## O botão: quem chamou decide o que é tentar de novo.
func tentar_de_novo() -> void:
	if _saindo or _tempo < 1.2:
		return
	_saindo = true
	tocar("botao")
	get_tree().paused = false
	var acao := ao_tentar_de_novo
	var camada := get_parent()
	if acao.is_valid():
		acao.call()
	if is_instance_valid(camada):
		camada.queue_free()


func dicas_do_controle() -> Array:
	return [["cruz", "TENTAR DE NOVO"]]


# ─────────────────────────────────────────────────────────────
# O DESENHO
# ─────────────────────────────────────────────────────────────

func _desenhar() -> void:
	var tela := size
	# O véu: escurece o jogo parado atrás, com a borda puxando para o vermelho.
	var veu := clampf(_tempo / 0.6, 0.0, 1.0)
	_desenho.draw_rect(Rect2(Vector2.ZERO, tela), Color(0.04, 0.03, 0.07, 0.86 * veu))
	for i in 8:
		var borda := 20.0 + i * 22.0
		var cor := Color(0.55, 0.04, 0.04, 0.09 * veu * (1.0 - i / 8.0))
		_desenho.draw_rect(Rect2(0, 0, tela.x, borda), cor)
		_desenho.draw_rect(Rect2(0, tela.y - borda, tela.x, borda), cor)
		_desenho.draw_rect(Rect2(0, 0, borda, tela.y), cor)
		_desenho.draw_rect(Rect2(tela.x - borda, 0, borda, tela.y), cor)

	_desenhar_o_titulo()

	var sub := clampf((_tempo - 0.9) / 0.3, 0.0, 1.0)
	if sub > 0.0:
		PecasDoLaboratorio.escrever_no_meio(_desenho, Vector2(tela.x * 0.5, 302.0 - (1.0 - sub) * 10.0),
			TXT_ESTOUROU, 30, Color(Color("e8463a"), sub))

	var ficha := clampf((_tempo - 1.1) / 0.35, 0.0, 1.0)
	if ficha > 0.0:
		_desenhar_a_ficha(ficha)

	if _tempo > 1.2:
		var a := clampf((_tempo - 1.2) / 0.3, 0.0, 1.0)
		var foco := alvo_em_foco() == "tentar_de_novo"
		var caixa := PecasDoLaboratorio.botao(_desenho, BOTAO, TXT_TENTAR, foco,
			alvo_segurado() == "tentar_de_novo", true, 26)
		if a < 1.0:
			_desenho.draw_rect(caixa.grow(8.0), Color(0.04, 0.03, 0.07, 0.86 * (1.0 - a)))
		EstiloHUD.tecla_da_folha(_desenho, FONTE, caixa, a)


## As letras caem uma a uma, com um quique; cada uma dá um baque na tela.
func _desenhar_o_titulo() -> void:
	var tamanho := 104
	var largura := PecasDoLaboratorio.largura(TXT_GAME_OVER, tamanho)
	var x := size.x * 0.5 - largura * 0.5
	var base := 236.0
	for i in TXT_GAME_OVER.length():
		var letra := TXT_GAME_OVER[i]
		var largura_letra := PecasDoLaboratorio.largura(letra, tamanho)
		var t := clampf((_tempo - 0.15 - i * 0.07) / 0.35, 0.0, 1.0)
		if t > 0.0:
			# Cai de cima e quica (o "back" do ease).
			var queda := (1.0 - _quique(t)) * -160.0
			var pos := Vector2(x, base + queda).round()
			var alfa := clampf(t * 3.0, 0.0, 1.0)
			_desenho.draw_string_outline(FONTE, pos + Vector2(6, 8), letra, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, 16,
				Color(0.5, 0.03, 0.03, alfa))
			_desenho.draw_string(FONTE, pos + Vector2(6, 8), letra, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho,
				Color(0.5, 0.03, 0.03, alfa))
			_desenho.draw_string_outline(FONTE, pos, letra, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, 16,
				Color(EstiloHUD.CONTORNO, alfa))
			_desenho.draw_string(FONTE, pos, letra, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, Color(EstiloHUD.CLARO, alfa))
		x += largura_letra


func _quique(t: float) -> float:
	# Sobe até passar um pouco do lugar e volta: um "pulo" no pouso.
	if t < 0.7:
		return ease(t / 0.7, 0.35)
	var u := (t - 0.7) / 0.3
	return 1.0 + sin(u * PI) * 0.06


func _desenhar_a_ficha(alfa: float) -> void:
	var caixa := FICHA
	caixa.position.y += roundf((1.0 - ease(alfa, 0.3)) * 24.0)
	EstiloHUD.ficha(_desenho, caixa, alfa)
	PecasDoLaboratorio.escrever(_desenho, caixa.position + Vector2(28, 22), TXT_O_QUE, 13,
		EstiloHUD.com_alfa(EstiloHUD.TINTA_FRACA, alfa))
	var motivo := String(dados.get("motivo", "compressao"))
	var pressao := float(dados.get("pressao", MaquinaDeCompressao.PRESSAO_DE_RUPTURA))
	var texto := String(TXT_EXPLICACOES.get(motivo, TXT_EXPLICACOES["compressao"])) \
		% String.num(pressao, 1).replace(".", ",")
	PecasDoLaboratorio.escrever_em_linhas(_desenho, Rect2(caixa.position.x + 28, caixa.position.y + 56, 560, 190),
		texto, 18, EstiloHUD.com_alfa(EstiloHUD.TINTA, alfa), 28.0, false)
	# O manômetro parado no vermelho.
	var centro := Vector2(caixa.end.x - 116, caixa.position.y + 126)
	_manometro(centro, 70.0, pressao, alfa)
	PecasDoLaboratorio.escrever_no_meio(_desenho, centro + Vector2(0, 98), TXT_PRESSAO_FINAL, 11,
		EstiloHUD.com_alfa(EstiloHUD.TINTA_FRACA, alfa))
	PecasDoLaboratorio.escrever_no_meio(_desenho, centro + Vector2(0, 120),
		String.num(pressao, 2).replace(".", ",") + " atm", 22, EstiloHUD.com_alfa(Color("c0392b"), alfa))


func _manometro(centro: Vector2, raio: float, p: float, alfa: float) -> void:
	_desenho.draw_circle(centro, raio + 6.0, EstiloHUD.com_alfa(EstiloHUD.CONTORNO, alfa))
	_desenho.draw_circle(centro, raio + 3.0, EstiloHUD.com_alfa(Color("8a93b8"), alfa))
	_desenho.draw_circle(centro, raio, EstiloHUD.com_alfa(Color("f4ead3"), alfa))
	var inicio := deg_to_rad(135.0)
	var volta := deg_to_rad(270.0)
	var escala := 5.0
	var faixas := [[0.0, MaquinaDeCompressao.PRESSAO_DE_TRABALHO, Color("3ecf72")],
		[MaquinaDeCompressao.PRESSAO_DE_TRABALHO, MaquinaDeCompressao.PRESSAO_DE_RUPTURA, Color("f2c84b")],
		[MaquinaDeCompressao.PRESSAO_DE_RUPTURA, escala, Color("e8463a")]]
	for faixa in faixas:
		_desenho.draw_arc(centro, raio - 9.0, inicio + volta * float(faixa[0]) / escala,
			inicio + volta * float(faixa[1]) / escala, 16, EstiloHUD.com_alfa(faixa[2], alfa), 8.0)
	for i in 6:
		var a := inicio + volta * i / 5.0
		var onde := centro + Vector2.from_angle(a) * (raio - 28.0)
		PecasDoLaboratorio.escrever_no_meio(_desenho, onde, str(i), 13, EstiloHUD.com_alfa(EstiloHUD.TINTA, alfa))
	# O vidro trincado.
	for i in 3:
		var a := 0.9 + i * 2.1
		_desenho.draw_line(centro + Vector2.from_angle(a) * 8.0, centro + Vector2.from_angle(a + 0.35) * (raio - 2.0),
			Color(1, 1, 1, 0.7 * alfa), 2.0)
	var angulo := inicio + volta * clampf(p / escala, 0.0, 1.06)
	_desenho.draw_line(centro, centro + Vector2.from_angle(angulo) * (raio - 12.0), EstiloHUD.com_alfa(Color("1b1b24"), alfa), 6.0)
	_desenho.draw_line(centro, centro + Vector2.from_angle(angulo) * (raio - 12.0), EstiloHUD.com_alfa(Color("e8463a"), alfa), 3.0)
	_desenho.draw_circle(centro, 7.0, EstiloHUD.com_alfa(EstiloHUD.CONTORNO, alfa))
