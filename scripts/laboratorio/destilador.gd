extends TelaInterativa

# --- DESTILADOR (Laboratório): o simulador de destilação ---
#
# A coluna de destilação da fase do nitrogênio, solta da história: a pessoa
# escolhe uma MISTURA, mexe no TERMÔMETRO e vê o que acontece lá dentro.
#
#   à esquerda   a lista de misturas (MisturasDoDestilador) e o botão de
#                recomeçar. Embaixo, o que essa destilação é no mundo.
#   no meio      a coluna em raio X (scripts/ui/coluna_do_simulador.gd), com a
#                régua e a temperatura de cada andar: mais quente embaixo, mais
#                fria em cima, onde está o resfriador.
#   ao lado dela o termômetro (scripts/ui/termometro.gd). O ponteiro é o que a
#                pessoa pede para o fundo; a coluna colorida é o que o fundo já
#                tem. Cada substância tem uma marca na altura do ponto de
#                ebulição dela PURA; e uma marca escrita, "O FUNDO FERVE",
#                anda junto com o ponto de ebulição da mistura que está no
#                fundo agora — é nela que o fundo começa a ferver, e ela sobe
#                conforme as substâncias mais voláteis vão embora.
#   à direita    uma ficha por substância: a molécula, o nome, o ponto de
#                ebulição e onde ela está agora (líquido no fundo, gás no
#                topo, ou onde está a maior parte dela: "16 DE 18 NO TOPO").
#                É a legenda da coluna, e ela se atualiza sozinha.
#
# Não há resposta para acertar: é um brinquedo. Mas há um objetivo à vista:
# quando a coluna para e cada substância é a maioria num lugar diferente, a
# tela avisa MISTURA SEPARADA. Pura, quase nunca fica nenhuma: o vapor leva de
# tudo um pouco (ver EquilibrioLiquidoVapor).
#
# A conta que a coluna faz, e o que nela é simplificação, estão explicados no
# topo de coluna_do_simulador.gd.
#
# ONDE MEXER:
#   scripts/laboratorio/misturas_do_destilador.gd   as misturas, as substâncias
#                                                   e os pontos de ebulição.
#   as medidas e os textos logo abaixo              a lista, as fichas, o aviso.
#   scenes/laboratorio/destilador.tscn              onde ficam a coluna, o
#                                                   termômetro e as setas.
#
# CONTROLES: arraste o ponteiro do termômetro (ou clique no tubo); as setas
# sobem e descem um grau (segurando, repetem); ↑ e ↓ do teclado também; ESC
# volta. No controle: cursor, ✕ (segurando no tubo, arrasta) e △.

## A mistura na coluna trocou (a chave dela).
signal mistura_trocada(chave: String)

## Quantos graus cada toque nas setas (ou nas teclas) sobe ou desce.
const PASSO := 1.0

const TXT_MISTURAS := "MISTURAS"
const TXT_SUBSTANCIAS := "O QUE TEM NA MISTURA"
const TXT_RECOMECAR := "RECOMEÇAR"
const TXT_FERVE := "ferve a %s"
const TXT_SEPARADA := "MISTURA SEPARADA!"
const TXT_SEPARADA_MAS := "CADA SUBSTÂNCIA FICOU MAIS RICA NUM LUGAR DA COLUNA. VEJA NAS FICHAS: QUASE NENHUMA FICOU PURA."
const TXT_COMECO := "SUBA O TERMÔMETRO. TUDO EVAPORA UM POUCO, MAS O FUNDO SÓ FERVE NA MARCA \"O FUNDO FERVE\": ENTRE OS PONTOS DE EBULIÇÃO DAS SUBSTÂNCIAS."
const TXT_OBJETIVO := "A MISTURA ESTÁ SEPARADA QUANDO CADA SUBSTÂNCIA É A MAIORIA NUM LUGAR DIFERENTE DA COLUNA."
const TXT_MODELO := "MODELO SIMPLIFICADO: POUCAS MOLÉCULAS, SEMPRE A 1 ATM. MAS QUANTO CADA SUBSTÂNCIA EVAPORA É A CONTA DE VERDADE (LEI DE RAOULT)."
const TXT_TERMOMETRO := "TEMPERATURA\nDO FUNDO"
## A marca do termômetro que anda com o ponto de ebulição da mistura do fundo.
const TXT_MARCA_DO_FUNDO := "O FUNDO\nFERVE"
const COR_MARCA_DO_FUNDO := Color("ffd166")

# ── A lista de misturas (px da tela) ──
const LISTA := Rect2(40, 118, 340, 0)
const ALTURA_DO_BOTAO := 52.0
const ENTRE_BOTOES := 12.0
## O papel do botão da mistura que está na coluna.
const PAPEL_ESCOLHIDO := Color("f2c84b")
# ── As fichas das substâncias ──
const FICHAS := Rect2(1310, 118, 274, 0)
const ALTURA_DA_FICHA := 96.0
const ENTRE_FICHAS := 10.0
## A largura reservada para o desenho da molécula, à esquerda da ficha.
const LARGURA_DO_DESENHO := 76.0
const COR_DE_LIQUIDO := Color("1f5f9e")
const COR_DE_GAS := Color("b0531f")

var chave_da_mistura: String = ""
var _arrastando: bool = false
var _pulo_do_aviso: float = 0.0
var _estalos: int = 0
## O ponto de ebulição do fundo que a marca do termômetro mostra agora (para
## só refazer as marcas quando ele muda).
var _marca_do_fundo: float = NAN

@onready var coluna: ColunaDoSimulador = $Coluna
@onready var termometro: Termometro = $Termometro
@onready var setas: SeletorCoeficiente = $Setas
@onready var painel: Control = $Painel


func _ao_abrir() -> void:
	painel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	painel.draw.connect(_desenhar_o_painel)
	setas.numero.text = ""
	termometro.cor_da_temperatura = coluna.cor_da_temperatura
	coluna.ferveu.connect(_ao_ferver)
	coluna.separou.connect(_ao_separar)

	for i in MisturasDoDestilador.MISTURAS.size():
		var chave := String(MisturasDoDestilador.MISTURAS[i]["chave"])
		registrar_alvo("mistura_" + chave, retangulo_da_mistura.bind(i), escolher_mistura.bind(chave))
	registrar_alvo("recomecar", retangulo_do_recomecar, recomecar)
	registrar_alvo("termometro", termometro.retangulo_de_pegar_na_tela, _pegar_o_ponteiro)
	registrar_alvo("mais_quente", setas.retangulo_do_botao.bind(1), mudar_temperatura.bind(1), Callable(), true)
	registrar_alvo("mais_frio", setas.retangulo_do_botao.bind(-1), mudar_temperatura.bind(-1), Callable(), true)
	escolher_mistura(String(MisturasDoDestilador.MISTURAS[0]["chave"]), false)


func _a_cada_quadro(delta: float) -> void:
	termometro.pedida = coluna.temperatura_pedida()
	termometro.medida = coluna.temperatura()
	termometro.em_foco = _arrastando or alvo_em_foco() == "termometro"
	_atualizar_as_marcas()
	_pulo_do_aviso = move_toward(_pulo_do_aviso, 0.0, delta / 0.45)
	painel.queue_redraw()


func _ao_receber(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_arrastando = false
		return false
	if event is InputEventMouseMotion and _arrastando:
		_levar_o_ponteiro(event.position)
		return true
	# ↑ e ↓ (ou W e S) só do TECLADO: o direcional e o analógico do controle
	# estão nas mesmas ações, mas aqui eles levam o cursor; valendo também para
	# a temperatura, ela mudaria toda vez que o cursor subisse ou descesse.
	if not event is InputEventKey:
		return false
	if event.is_action_pressed("ui_up", true):
		mudar_temperatura(1)
		return true
	if event.is_action_pressed("ui_down", true):
		mudar_temperatura(-1)
		return true
	return false


func dicas_do_controle() -> Array:
	return [["analogico_esquerdo", "MOVER"], ["direcional", "ESCOLHER"],
		["cruz", "APERTAR (SEGURE NO TERMÔMETRO)"], ["fechar", "VOLTAR"]]


# ─────────────────────────────────────────────────────────────
# A MISTURA
# ─────────────────────────────────────────────────────────────

## Põe na coluna a mistura com esta chave, líquida no fundo e com o termômetro
## no mínimo.
func escolher_mistura(chave: String, com_som: bool = true) -> void:
	var dados := MisturasDoDestilador.mistura(chave)
	if dados.is_empty():
		return
	chave_da_mistura = chave
	_estalos = 0
	_arrastando = false
	coluna.definir_mistura(dados)
	termometro.definir_faixa(float(dados["minima"]), float(dados["maxima"]))
	_marca_do_fundo = NAN
	_atualizar_as_marcas()
	if com_som:
		tocar("botao")
	mistura_trocada.emit(chave)


## As marcas do termômetro: o ponto de ebulição de cada substância pura e, se
## o fundo tem líquido que evapora, a temperatura em que ELE ferve agora (a da
## mistura que está lá). Só refaz quando essa muda.
func _atualizar_as_marcas() -> void:
	var fundo := coluna.bolha_do_fundo()
	var visivel := is_finite(fundo) and fundo <= termometro.maxima
	var agora := roundf(fundo * 10.0) / 10.0 if visivel else INF
	if is_equal_approx(agora, _marca_do_fundo) or (is_inf(agora) and is_inf(_marca_do_fundo)):
		return
	_marca_do_fundo = agora
	var marcas: Array[Dictionary] = []
	for substancia in MisturasDoDestilador.em_ordem_de_ebulicao(mistura()):
		marcas.append({"chave": substancia, "graus": MisturasDoDestilador.ebulicao(substancia)})
	if visivel:
		marcas.append({"chave": "fundo", "graus": agora, "texto": TXT_MARCA_DO_FUNDO, "cor": COR_MARCA_DO_FUNDO})
	termometro.definir_marcas(marcas)


## A mesma mistura, do começo.
func recomecar() -> void:
	tocar("tirar")
	_estalos = 0
	_arrastando = false
	coluna.reiniciar()


## A mistura que está na coluna (um item de MisturasDoDestilador.MISTURAS).
func mistura() -> Dictionary:
	return coluna.mistura()


## As substâncias da mistura, na ordem das fichas: a que ferve mais fácil (a
## que vai mais alto na coluna) em cima.
func substancias() -> Array[String]:
	return MisturasDoDestilador.em_ordem_de_ebulicao(mistura())


# ─────────────────────────────────────────────────────────────
# O TERMÔMETRO
# ─────────────────────────────────────────────────────────────

## As setas (e as teclas): um PASSO para cima (+1) ou para baixo (-1).
func mudar_temperatura(sentido: int) -> void:
	var antes := coluna.temperatura_pedida()
	# Em graus inteiros: depois de arrastar, a seta acerta o número.
	var depois := roundf(antes) + PASSO * signi(sentido)
	coluna.pedir_temperatura(depois)
	setas.animar_seta(sentido)
	if not is_equal_approx(coluna.temperatura_pedida(), antes):
		tocar("passo", 1.0 + 0.25 * signi(sentido))


## Pede esta temperatura para o fundo (presa à escala do termômetro).
func pedir_temperatura(graus: float) -> void:
	coluna.pedir_temperatura(graus)


func _pegar_o_ponteiro() -> void:
	_arrastando = true
	_levar_o_ponteiro(ponteiro())


## Leva o ponteiro do termômetro para a altura do ponto (da tela), de grau em
## grau.
func _levar_o_ponteiro(ponto: Vector2) -> void:
	var graus := termometro.graus_no_ponto(ponto.y - termometro.global_position.y)
	coluna.pedir_temperatura(roundf(graus))


func _ao_ferver(_substancia: String) -> void:
	# Cada substância que começa a ferver, um estalo um pouco mais agudo.
	tocar("pop", 1.0 + 0.1 * _estalos)
	_estalos += 1


func _ao_separar() -> void:
	tocar("certo")
	_pulo_do_aviso = 1.0


# ─────────────────────────────────────────────────────────────
# ONDE FICA CADA COISA
# ─────────────────────────────────────────────────────────────

## O botão da mistura número "i" da lista.
func retangulo_da_mistura(i: int) -> Rect2:
	return Rect2(LISTA.position.x, LISTA.position.y + i * (ALTURA_DO_BOTAO + ENTRE_BOTOES),
		LISTA.size.x, ALTURA_DO_BOTAO)


func retangulo_do_recomecar() -> Rect2:
	var depois_da_lista := retangulo_da_mistura(MisturasDoDestilador.MISTURAS.size())
	return Rect2(depois_da_lista.position + Vector2(0, 14), Vector2(LISTA.size.x, 46))


## A ficha da substância número "i" (na ordem de substancias()).
func retangulo_da_ficha(i: int) -> Rect2:
	return Rect2(FICHAS.position.x, FICHAS.position.y + i * (ALTURA_DA_FICHA + ENTRE_FICHAS),
		FICHAS.size.x, ALTURA_DA_FICHA)


# ─────────────────────────────────────────────────────────────
# DESENHO
# ─────────────────────────────────────────────────────────────

func _desenhar_o_painel() -> void:
	var fonte := FONTE
	# A lista de misturas.
	EstiloHUD.etiqueta(painel, fonte, Vector2(LISTA.position.x + PecasDoLaboratorio.largura(TXT_MISTURAS, 11) + 12.0,
		LISTA.position.y - 30.0), TXT_MISTURAS)
	for i in MisturasDoDestilador.MISTURAS.size():
		var dados: Dictionary = MisturasDoDestilador.MISTURAS[i]
		var nome := "mistura_" + String(dados["chave"])
		PecasDoLaboratorio.botao(painel, retangulo_da_mistura(i), String(dados["nome"]), alvo_em_foco() == nome,
			alvo_segurado() == nome, true, 22,
			PAPEL_ESCOLHIDO if dados["chave"] == chave_da_mistura else EstiloHUD.PAPEL)
	PecasDoLaboratorio.botao(painel, retangulo_do_recomecar(), TXT_RECOMECAR, alvo_em_foco() == "recomecar",
		alvo_segurado() == "recomecar", true, 22, EstiloHUD.PAPEL_DOBRA)

	# O que essa destilação é no mundo, e o aviso de que o modelo é simplificado.
	var nota := Rect2(LISTA.position.x, retangulo_do_recomecar().end.y + 34.0, LISTA.size.x, 200.0)
	var altura := _escrever_claro(nota, String(mistura().get("nota", "")), EstiloHUD.CLARO)
	nota.position.y += altura + 22.0
	_escrever_claro(nota, TXT_MODELO, Color(EstiloHUD.TECLA_TAMPA))

	# O nome do que as setas mexem, embaixo delas.
	var linhas := TXT_TERMOMETRO.split("\n")
	for i in linhas.size():
		var largura := PecasDoLaboratorio.largura(linhas[i], 11)
		EstiloHUD.rotulo(painel, fonte, Vector2(roundf(setas.global_position.x + setas.size.x * 0.5 - largura * 0.5),
			setas.global_position.y + setas.size.y + 22.0 + i * 15.0), linhas[i], 11)

	# As fichas das substâncias.
	EstiloHUD.etiqueta(painel, fonte, Vector2(FICHAS.position.x + PecasDoLaboratorio.largura(TXT_SUBSTANCIAS, 11) + 12.0,
		FICHAS.position.y - 30.0), TXT_SUBSTANCIAS)
	var lista := substancias()
	for i in lista.size():
		_desenhar_a_ficha(retangulo_da_ficha(i), lista[i])

	# O aviso: separada, ou o que fazer.
	var meio := Vector2(FICHAS.position.x + FICHAS.size.x * 0.5,
		retangulo_da_ficha(lista.size()).position.y + 34.0)
	if coluna.separada():
		var placa := PecasDoLaboratorio.plaquinha(painel, meio, TXT_SEPARADA, 22, Color("9be28a"), 1.0,
			sin(_pulo_do_aviso * PI) * 6.0)
		_escrever_claro(Rect2(FICHAS.position.x, placa.end.y + 6.0, FICHAS.size.x, 120.0), TXT_SEPARADA_MAS,
			EstiloHUD.CLARO)
	else:
		var comecou := coluna.quantas_em(ColunaDoSimulador.Estado.LIQUIDA) < coluna.total_de_moleculas() \
			or coluna.temperatura_pedida() > float(mistura().get("minima", 0.0))
		_escrever_claro(Rect2(FICHAS.position.x, meio.y - 22.0, FICHAS.size.x, 120.0),
			TXT_OBJETIVO if comecou else TXT_COMECO, EstiloHUD.CLARO)


## A ficha de uma substância: a molécula, o nome, o ponto de ebulição (dela
## pura) e onde ela está agora.
func _desenhar_a_ficha(caixa: Rect2, chave: String) -> void:
	var dados := MisturasDoDestilador.substancia(chave)
	EstiloHUD.ficha(painel, caixa)
	# A molécula, do tamanho que couber no canto dela (2x a da coluna, ou 1x
	# para as cadeias compridas).
	var lado := float(MoleculasDoDestilador.celula(chave).x) * MoleculasDoDestilador.ESCALA
	var ampliacao := 2.0 if lado * 2.0 <= LARGURA_DO_DESENHO - 8.0 else 1.0
	MoleculasDoDestilador.desenhar(painel, chave,
		Vector2(caixa.position.x + LARGURA_DO_DESENHO * 0.5 + 4.0, caixa.get_center().y - 2.0), 0, ampliacao)

	# O nome e, embaixo, as linhas miúdas: o que ela é no dia a dia (quando tem
	# apelido), o ponto de ebulição e onde ela está agora.
	var x := caixa.position.x + LARGURA_DO_DESENHO + 8.0
	var apelido := String(MisturasDoDestilador.APELIDOS.get(chave, ""))
	var y := caixa.position.y + (30.0 if not apelido.is_empty() else 36.0)
	painel.draw_string(FONTE, Vector2(x, y), String(dados["nome"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
		EstiloHUD.TINTA)
	if not apelido.is_empty():
		y += 17.0
		painel.draw_string(FONTE, Vector2(x, y), apelido, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, EstiloHUD.TINTA_FRACA)
	y += 17.0 if not apelido.is_empty() else 20.0
	painel.draw_string(FONTE, Vector2(x, y), TXT_FERVE % MisturasDoDestilador.graus(float(dados["ebulicao"])),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, EstiloHUD.TINTA_FRACA)
	y += 17.0
	# Onde ela está: em azul se é (quase toda) líquido parado, em laranja se é
	# gás, e apagado se está a caminho.
	var situacao := coluna.situacao_de(chave)
	var lugar := coluna.lugar_principal(chave)
	var cor := EstiloHUD.TINTA_FRACA
	if lugar != ColunaDoSimulador.A_CAMINHO:
		cor = COR_DE_GAS if lugar.y == ColunaDoSimulador.GAS else COR_DE_LIQUIDO
	painel.draw_string(FONTE, Vector2(x, y), situacao, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, cor)


## Texto miúdo e claro, com contorno, quebrado na largura da caixa (escrito
## direto em cima do fundo). Devolve a altura escrita.
func _escrever_claro(caixa: Rect2, texto: String, cor: Color) -> float:
	var linhas := EstiloHUD.quebrar(FONTE, texto, 11, caixa.size.x)
	for i in linhas.size():
		EstiloHUD.rotulo(painel, FONTE, Vector2(caixa.position.x, caixa.position.y + 10.0 + i * 17.0), linhas[i], 11,
			cor)
	return linhas.size() * 17.0
