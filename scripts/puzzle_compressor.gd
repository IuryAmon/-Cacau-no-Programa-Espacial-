class_name TelaDoCompressor
extends TelaInterativa

# --- O PUZZLE DO COMPRESSOR DE AR (fase do nitrogênio) ---
#
# O cilindro de ar que a Cacau trouxe do telhado da torre é acoplado embaixo
# de uma câmara cheia de ar da sala. O objetivo: guardar NELE o máximo de ar —
# todo o ar da câmara —, e tão frio que vire AR LÍQUIDO, que é o que a coluna
# de destilação recebe. Sem estourar o cilindro: ele aguenta 4 atm.
#
#   O ÊMBOLO      desce dentro da câmara e diminui o volume: as moléculas ficam
#                 mais apertadas, batem mais nas paredes, e a PRESSÃO sobe (a
#                 lei de Boyle). Apertar também ESQUENTA o gás (o trabalho do
#                 êmbolo vira agitação das moléculas).
#   O RESFRIADOR  o termômetro da direita manda na serpentina. Mais frio, as
#                 moléculas andam mais devagar e batem mais fraco: a pressão
#                 cai (a lei de Gay-Lussac). Dá para aquecer também, para ver
#                 o contrário.
#   O MANÔMETRO   no gargalo do cilindro: verde até 3 atm, amarelo até 4,
#                 depois estoura.
#
# Diminuir o volume sem resfriar estoura o cilindro: na temperatura da sala,
# todo o ar no cilindro daria 8 atm. Resfriando, a pressão cai (P = nRT/V) e,
# abaixo de uns −183 °C, o ar apertado começa a VIRAR LÍQUIDO — a pressão para
# de subir, e as moléculas se juntam no fundo do cilindro. Com todo o ar no
# cilindro e pelo menos 20% dele líquido, a válvula pode ser fechada.
#
# Fechada a válvula, a máquina solta o cilindro e a tela diz quanto tempo a
# amostra aguenta esquentando (a física do GasFechado: quanto mais fria e
# líquida, mais tempo). Quem fecha a tela é quem leva a amostra (o
# CompressorDeAr, na sala do compressor).
#
# DOIS JEITOS DE USAR (export "modo_historia"):
#   história     aberta por cima da fase pelo CompressorDeAr. O ESC fecha a tela
#                (a máquina fica como estava). Estourar toca a explosão e avisa
#                "cilindro_estourou" — quem abriu mostra o fim de jogo.
#   laboratório  a tela inteira, sozinha, fora da história. Estourar só
#                mostra o que houve, e o RECOMEÇAR monta tudo de novo. (O
#                compressor do menu do Laboratório não é este puzzle: é o
#                simulador de gases, scripts/laboratorio/compressor.gd.)
#
# A TELA mostra cada coisa num lugar só, e o mínimo de texto:
#   embaixo do título   UMA frase do que fazer agora (laranja no perigo, verde
#                       quando está pronto);
#   à esquerda          o ar lá dentro, escrito na própria equação P·V = n·R·T,
#                       com o valor de agora embaixo de cada letra;
#   no meio             o aparelho, com o nome de cada controle junto dele (as
#                       setas do ÊMBOLO, o termômetro do RESFRIADOR, com a marca
#                       de onde o ar vira líquido);
#   à direita           o OBJETIVO — duas metas com a barrinha de quanto falta e
#                       a condição de não estourar — e o botão de fechar a
#                       válvula, com quanto a amostra aguentaria fechada agora;
#   no pé               as teclas.
#
# NO MAPA: na história a tela não troca. Quem abre é o CompressorDeAr, na sala
# do compressor: a câmera chega perto da máquina (ZoomNoObjeto, zoom 4) e a
# tela nasce em cima dela ("aparelho_no_mundo" é onde a arte da máquina está na
# tela). Sem fundo: a câmara em raio X é desenhada na grade da própria arte
# (CamaraDeCompressao.medidas_do_mapa, ArteDoCompressor) — o casco de aço vira
# a câmara por dentro, o cilindro preso no berço vira o cilindro com o ar, o
# cabo vermelho em cima é o cabo que se arrasta — e uma linha de luz desce
# trocando uma pela outra (VarreduraRaioX). Depois aparecem as setas do êmbolo
# e os painéis à esquerda, e o termômetro do resfriador à direita do armário.
# Fechando, tudo some ao contrário. Sem "aparelho_no_mundo" (o Laboratório, os
# testes), é a tela inteira de sempre.
#
# O MOUSE: o cabo do êmbolo e o ponteiro do termômetro são o que se arrasta.
# Em cima deles, a seta do mouse vira a mãozinha aberta (MaoDoMouse) e, segurando,
# a fechada; até a pessoa arrastar cada um pela primeira vez, uma mão desenhada
# mostra o gesto em cima dele (DicaDeArrastar): primeiro no cabo, depois no
# termômetro.
#
# CONTROLES: arraste o cabo do êmbolo (ou as setas ao lado da câmara; W/S ou
# ↑/↓); arraste o ponteiro do termômetro (ou as setas embaixo dele; A/D ou
# ←/→); o botão FECHAR A VÁLVULA (ou E). ESC fecha. No controle: o cursor, ✕
# (segurando, arrasta) e △.
# DEBUG: a tecla L deixa a amostra pronta na hora.
#
# ONDE MEXER:
#   scripts/laboratorio/maquina_de_compressao.gd   os números da máquina
#                                                  (volumes, pressões, o
#                                                  resfriador, o vazamento).
#   scripts/laboratorio/gas_fechado.gd             a física do ar.
#   scripts/ui/camara_de_compressao.gd             o desenho do aparelho.
#   as constantes e os textos logo abaixo          os painéis desta tela.
#   scenes/puzzle_compressor.tscn                  onde ficam a câmara, o
#                                                  termômetro, as setas e os
#                                                  sons.

## Todo o ar no cilindro, já líquido, válvula fechada: a amostra pronta (a
## física dela, para quem a leva) e quanto tempo ela aguenta.
signal amostra_fechada(amostra: GasFechado, segundos: float)
## O cilindro estourou e a cena da explosão acabou. "como" diz o que houve:
## {"pressao", "temperatura", "posicao", "volume"}.
signal cilindro_estourou(como: Dictionary)
## A tela fechou sem terminar (ESC).
signal fechou
## No mapa: o raio X acabou de cobrir a máquina (quem abriu esconde a arte dela,
## senão ela apareceria nas frestas do desenho) / vai começar a sair (a arte
## volta, por baixo).
signal revelada
signal escondendo

## Na história, a tela se fecha por cima da fase; no Laboratório, é a cena.
@export var modo_historia: bool = true
## A conversa do Dr. Chico na primeira vez que a tela abre (vazio = sem fala).
@export var fala_de_abertura: String = ""
## Onde a arte da máquina do mapa está na tela (ver "NO MAPA", no topo). Sem
## área, a tela inteira de sempre.
var aparelho_no_mundo: Rect2 = Rect2()

## A pessoa já arrastou o cabo / o ponteiro do termômetro alguma vez (aí a mão
## que mostra o gesto não aparece mais).
static var arrastou_o_embolo: bool = false
static var arrastou_o_termometro: bool = false

const TXT_TITULO := "COMPRESSOR DE AR"
const TXT_OBJETIVO := "OBJETIVO"
const TXT_META_1 := "TODO O AR NO CILINDRO"
const TXT_META_2 := "AR VIRANDO LÍQUIDO"
const TXT_META_3 := "SEM PASSAR DE 4 atm"
const TXT_FECHAR := "FECHAR A VÁLVULA"
const TXT_RECOMECAR := "RECOMEÇAR"
const TXT_AGUENTA := "FECHADO, AGUENTA %d s"
const TXT_EMBOLO := "ÊMBOLO"
const TXT_RESFRIADOR := "RESFRIADOR"
const TXT_O_AR := "O AR LÁ DENTRO"
## A equação, um símbolo por coluna (com os sinais entre eles), e embaixo de
## cada um o valor de agora e a unidade.
const TXT_SIMBOLOS := ["P", "V", "n", "R", "T"]
const TXT_SINAIS := ["·", "=", "·", "·"]
const TXT_UNIDADES := ["atm", "L", "mol", "", "K"]
const TXT_PRONTA := "AR LÍQUIDO NO CILINDRO!"
const TXT_DA_AMOSTRA := "%s  ·  %d%% LÍQUIDO"
const TXT_AGUENTA_NA_CORRIDA := "O CALOR DA SALA VAI ENTRANDO: AGUENTA %d s."
const TXT_LEVE := "LEVE AO DESTILADOR, DEPRESSA!"
const TXT_ESTOUROU := "O CILINDRO ESTOUROU!"
const TXT_O_QUE_HOUVE := "A PRESSÃO CHEGOU A %s atm, E O CILINDRO SÓ AGUENTA 4. RESFRIE O AR ANTES DE APERTAR."
const TXT_PINGA := "AR VIRA\nLÍQUIDO"

## A frase do que fazer, embaixo do título — uma só, a mais urgente agora.
const TXT_DICA_COMECO := "DESÇA O ÊMBOLO PARA EMPURRAR O AR DA CÂMARA PARA O CILINDRO."
const TXT_DICA_PERIGO := "PRESSÃO ALTA! RESFRIE O AR OU SUBA O ÊMBOLO."
const TXT_DICA_ESQUENTOU := "APERTAR ESQUENTA O AR, E O AR QUENTE EMPURRA MAIS."
const TXT_DICA_QUENTE := "QUENTE, AS MOLÉCULAS BATEM MAIS FORTE: A PRESSÃO SOBE."
const TXT_DICA_FRIO := "FRIO, AS MOLÉCULAS BATEM MAIS FRACO: DÁ PARA APERTAR MAIS."
const TXT_DICA_LIQUIDO := "O AR ESTÁ VIRANDO LÍQUIDO!"
const TXT_DICA_RESFRIE_MAIS := "AGORA RESFRIE: NESTA PRESSÃO O AR VIRA LÍQUIDO ABAIXO DE %s."
const TXT_DICA_PRONTA := "PRONTO! FECHE A VÁLVULA."
const TXT_DICA_FECHANDO := "VÁLVULA FECHADA. SOLTANDO O CILINDRO..."

## As cores da frase do que fazer.
const COR_DA_DICA_PERIGO := Color("ffb347")
const COR_DA_DICA_PRONTA := Color("9be28a")
const COR_PRESSAO := [Color("1f7a3d"), Color("a8740b"), Color("c0392b")]

## Onde ficam os painéis (px da tela): à esquerda, o ar (a equação); à
## direita, o objetivo e, embaixo dele, o botão.
const PAINEL_EQUACAO := Rect2(40, 118, 344, 150)
const PAINEL_OBJETIVO := Rect2(1300, 118, 270, 200)
const BOTAO_FECHAR := Rect2(1300, 338, 270, 56)
const BOTAO_RECOMECAR := Rect2(1300, 448, 270, 46)
## A altura da frase do que fazer (logo embaixo do título) e a das teclas.
const ALTURA_DA_DICA := 76.0
const ALTURA_DAS_TECLAS := 866.0

## No mapa (ver _montar_no_mundo): sem a plaquinha do título, a frase sobe; o
## termômetro fica a este vão da beirada da arte (a plaquinha do ponteiro, à
## esquerda dele, não encosta no armário); as setas do êmbolo, a este vão do
## casco; e os painéis, empilhados à esquerda, com este espaço entre eles.
const ALTURA_DA_DICA_NO_MAPA := 44.0
const VAO_ATE_O_TERMOMETRO := 80.0
const VAO_ATE_AS_SETAS := 24.0
const MARGEM_NO_MAPA := 24.0
const ENTRE_OS_PAINEIS := 16.0
const DURACAO_DOS_PAINEIS := 0.3

## A cada toque nas setas: o êmbolo anda 1/50 do curso; o resfriador, 1 °C.
const PASSO_DO_EMBOLO := 0.02
const PASSO_DO_RESFRIADOR := 1.0
## Segurando as teclas: quanto o êmbolo anda (curso por segundo) e quantos
## graus por segundo o resfriador muda.
const EMBOLO_POR_SEGUNDO := 0.35
const GRAUS_POR_SEGUNDO := 70.0

## Quanto a explosão fica em câmera lenta logo depois do estrondo.
const CAMERA_LENTA := 0.3
const DURACAO_DA_CAMERA_LENTA := 0.7

enum Estado { JOGANDO, FALANDO, FECHANDO, PRONTA, EXPLODINDO, FIM }

## A máquina desta tela. Quem abre a tela pode entregar a sua (a da sala do
## compressor guarda o que a pessoa já fez); sem isso, a tela monta uma.
var maquina: MaquinaDeCompressao = null

var _estado: Estado = Estado.JOGANDO
var _arrastando: String = ""
var _pegada_do_embolo: float = 0.0
var _amostra: GasFechado = null
var _segundos_da_amostra: float = 0.0
var _previsao: float = INF
var _proxima_previsao: float = 0.0
var _relogio_do_estado: float = 0.0
var _clarao: float = 0.0
var _tremor_da_tela: float = 0.0
var _camera_lenta: float = 0.0
var _como_estourou: Dictionary = {}
var _ja_condensou: bool = false
var _pulo_da_meta: Array[float] = [0.0, 0.0, 0.0]
var _metas: Array[bool] = [false, false, false]
## Onde os painéis estão (os de sempre; no mapa, ver _montar_no_mundo).
var _painel_equacao: Rect2 = PAINEL_EQUACAO
var _painel_objetivo: Rect2 = PAINEL_OBJETIVO
var _botao_fechar: Rect2 = BOTAO_FECHAR
var _botao_recomecar: Rect2 = BOTAO_RECOMECAR
var _altura_da_dica: float = ALTURA_DA_DICA
var _varredura: VarreduraRaioX = null
var _dica_do_mouse: DicaDeArrastar = null
## Em que a mão da dica está ("embolo", "termometro" ou "").
var _dica_no_alvo: String = ""

@onready var camara: CamaraDeCompressao = $Camara
@onready var termometro: Termometro = $Termometro
@onready var setas_resfriador: SeletorCoeficiente = $SetasResfriador
@onready var setas_embolo: SeletorCoeficiente = $SetasEmbolo
@onready var painel: Control = $Painel
## A camada de cima de tudo: a comemoração, o clarão do estrondo.
@onready var frente: Control = $Frente
@onready var _som_rangido: AudioStreamPlayer = get_node_or_null("SomRangido")
@onready var _som_gota: AudioStreamPlayer = get_node_or_null("SomGota")
@onready var _som_valvula: AudioStreamPlayer = get_node_or_null("SomValvula")
@onready var _som_alarme: AudioStreamPlayer = get_node_or_null("SomAlarme")
@onready var _som_estrondo: AudioStreamPlayer = get_node_or_null("SomEstrondo")
@onready var _som_chiado: AudioStreamPlayer = get_node_or_null("SomChiado")
@onready var _som_sucesso: AudioStreamPlayer = get_node_or_null("SomSucesso")


func _ao_abrir() -> void:
	if maquina == null:
		maquina = MaquinaDeCompressao.new()
	# No mapa, as medidas da câmara mudam antes de ela receber a máquina (é
	# aí que ela espalha as moléculas).
	if no_mundo():
		_montar_no_mundo()
	painel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	painel.draw.connect(_desenhar_o_painel)
	frente.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frente.draw.connect(_desenhar_a_frente)
	camara.maquina = maquina
	camara.estourando.connect(_ao_estourar)
	camara.estrondo.connect(_ao_estrondo)
	camara.explosao_terminou.connect(_ao_terminar_a_explosao)
	camara.rangeu.connect(_tocar.bind("rangido"))
	camara.gotejou.connect(_ao_gotejar)
	camara.valvula_fechou.connect(_tocar.bind("valvula"))
	maquina.comecou_a_condensar.connect(func() -> void: _ja_condensou = true)

	termometro.definir_faixa(GasFechado.para_celsius(MaquinaDeCompressao.RESFRIADOR_MINIMO),
		GasFechado.para_celsius(MaquinaDeCompressao.RESFRIADOR_MAXIMO))
	termometro.cor_da_temperatura = _cor_do_termometro
	setas_resfriador.numero.text = ""
	setas_embolo.numero.text = ""

	registrar_alvo("embolo", camara.retangulo_de_pegar_o_embolo_na_tela, _pegar_o_embolo, _pode_mexer)
	registrar_alvo("embolo_sobe", setas_embolo.retangulo_do_botao.bind(1), mover_embolo.bind(-1), _pode_mexer, true)
	registrar_alvo("embolo_desce", setas_embolo.retangulo_do_botao.bind(-1), mover_embolo.bind(1), _pode_mexer, true)
	registrar_alvo("termometro", termometro.retangulo_de_pegar_na_tela, _pegar_o_ponteiro, _pode_mexer)
	registrar_alvo("mais_quente", setas_resfriador.retangulo_do_botao.bind(1), mudar_resfriador.bind(1), _pode_mexer, true)
	registrar_alvo("mais_frio", setas_resfriador.retangulo_do_botao.bind(-1), mudar_resfriador.bind(-1), _pode_mexer, true)
	registrar_alvo("fechar_valvula", func() -> Rect2: return _botao_fechar, fechar_valvula, pode_fechar)
	if not modo_historia:
		registrar_alvo("recomecar", func() -> Rect2: return _botao_recomecar, recomecar)
	# O cabo e o ponteiro se arrastam: em cima deles, a mãozinha.
	marcar_arrastavel("embolo")
	marcar_arrastavel("termometro")

	_ja_condensou = maquina.gas.fracao_liquida > 0.0
	_metas = [_meta(0), _meta(1), _meta(2)]
	_estado = Estado.JOGANDO
	_dica_do_mouse = DicaDeArrastar.new()
	_dica_do_mouse.name = "DicaDoMouse"
	add_child(_dica_do_mouse)
	if no_mundo():
		_entrar_no_mundo()
		return
	if modo_historia and not fala_de_abertura.is_empty():
		_falar(fala_de_abertura)
	_mostrar_a_dica_do_mouse()


## Aberta em cima da máquina do mapa?
func no_mundo() -> bool:
	return aparelho_no_mundo.has_area()


# ─────────────────────────────────────────────────────────────
# NO MAPA (em cima da arte da máquina)
# ─────────────────────────────────────────────────────────────

## A câmara em cima da arte do mapa, na grade dela; as setas do êmbolo à
## esquerda do casco e, à esquerda delas, os painéis empilhados (a equação, o
## objetivo e o botão); o termômetro do resfriador à direita do armário, com as
## setas embaixo. Sem fundo e sem a plaquinha do título: a sala aparece em
## volta (escurecida pelo véu do ZoomNoObjeto).
func _montar_no_mundo() -> void:
	titulo = ""
	var fundo := get_node_or_null("Fundo") as CanvasItem
	if fundo:
		fundo.visible = false
	var A := ArteDoCompressor
	var pixel := aparelho_no_mundo.size.x / float(A.TAMANHO.x)
	camara.position = aparelho_no_mundo.position.round()
	camara.size = aparelho_no_mundo.size.round()
	camara.medidas = CamaraDeCompressao.medidas_do_mapa(pixel)
	var canto := camara.position

	# O resfriador, do lado do armário, de cima para baixo: o termômetro (da
	# altura do casco), as setas e, rente ao pé da máquina, o botão de fechar a
	# válvula — o último passo fica no fim do caminho, e a coluna da esquerda
	# termina acima da cabeça da Cacau (ela fica ali, ao lado da máquina).
	var topo := canto.y + A.CASCO.position.y * pixel
	var chao := canto.y + A.TAMANHO.y * pixel
	var meio_do_termometro := roundf(canto.x + A.TAMANHO.x * pixel + VAO_ATE_O_TERMOMETRO + termometro.size.x * 0.5)
	_botao_fechar = Rect2(roundf(meio_do_termometro - BOTAO_FECHAR.size.x * 0.5), chao - BOTAO_FECHAR.size.y,
		BOTAO_FECHAR.size.x, BOTAO_FECHAR.size.y)
	setas_resfriador.position = Vector2(roundf(meio_do_termometro - setas_resfriador.size.x * 0.5),
		_botao_fechar.position.y - ENTRE_OS_PAINEIS - setas_resfriador.size.y)
	termometro.position = Vector2(roundf(meio_do_termometro - termometro.size.x * 0.5), roundf(topo))
	termometro.size = Vector2(termometro.size.x, setas_resfriador.position.y - 12.0 - termometro.position.y)

	# O êmbolo: as setas do lado do casco, na altura do meio da câmara.
	var meio_da_camara := canto.y + (A.CAMARA.position.y + A.CAMARA.size.y * 0.5) * pixel
	setas_embolo.position = Vector2(roundf(canto.x + A.CASCO.position.x * pixel - VAO_ATE_AS_SETAS - setas_embolo.size.x),
		roundf(meio_da_camara - setas_embolo.size.y * 0.5))

	# A equação e o objetivo, um embaixo do outro, entre a beirada da tela e as
	# setas. (O RECOMEÇAR é só do Laboratório: no mapa não aparece.)
	var x := MARGEM_NO_MAPA
	var largura := setas_embolo.position.x - VAO_ATE_AS_SETAS - x
	_painel_equacao = Rect2(x, canto.y, largura, PAINEL_EQUACAO.size.y)
	_painel_objetivo = Rect2(x, _painel_equacao.end.y + ENTRE_OS_PAINEIS, largura, PAINEL_OBJETIVO.size.y)
	_altura_da_dica = ALTURA_DA_DICA_NO_MAPA

	# A linha do raio X passa pela máquina de cima (o cabo) até o chão, do casco
	# até o armário (os canos do resfriador também mudam).
	_varredura = VarreduraRaioX.new()
	_varredura.name = "Varredura"
	camara.add_sibling(_varredura)
	_varredura.preparar(camara, 0.0, A.BASE_DO_CHAO * pixel, (A.CASCO.position.x - 1) * pixel,
		(A.ARMARIO.position.x + 1) * pixel)


## A entrada: a linha desce trocando o aço pelo raio X, e só então aparecem as
## setas, o termômetro e os painéis. Enquanto isso, a tela não responde.
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
	if modo_historia and not fala_de_abertura.is_empty():
		_falar(fala_de_abertura)
	_mostrar_a_dica_do_mouse()


## A saída: os painéis somem, a linha sobe apagando o raio X e a arte da
## máquina volta a aparecer por baixo.
func _sair_do_mundo() -> void:
	bloqueada = true
	_dica_do_mouse.parar()
	var sumir := novo_tween()
	sumir.tween_method(_mostrar_os_paineis, painel.modulate.a, 0.0, DURACAO_DOS_PAINEIS * 0.6)
	await sumir.finished
	escondendo.emit()
	_varredura.esconder()
	await _varredura.terminou


## O quanto aparecem (0 a 1) as coisas que não são a máquina.
func _mostrar_os_paineis(alfa: float) -> void:
	for no: CanvasItem in [painel, termometro, setas_resfriador, setas_embolo, _moldura, frente, _dica_do_mouse]:
		if no:
			no.modulate.a = alfa


# ─────────────────────────────────────────────────────────────
# A MÃO QUE MOSTRA O GESTO (até a primeira vez que a pessoa arrasta)
# ─────────────────────────────────────────────────────────────

## Primeiro o cabo do êmbolo (para baixo: o começo é apertar o ar); depois de
## a pessoa arrastar o cabo e soltar, o ponteiro do termômetro (para baixo:
## resfriar).
func _mostrar_a_dica_do_mouse() -> void:
	if _dica_do_mouse == null:
		return
	var alvo := ""
	if not arrastou_o_embolo:
		alvo = "embolo"
	elif not arrastou_o_termometro:
		alvo = "termometro"
	# Já está mostrando esse: não recomeça o gesto.
	if alvo == _dica_no_alvo and _dica_do_mouse.mostrando():
		return
	_dica_no_alvo = alvo
	match alvo:
		"embolo":
			_dica_do_mouse.mostrar(camara.retangulo_do_cabo_na_tela, Vector2.DOWN, 48.0)
		"termometro":
			# A mão pega pela ponta da plaquinha (a seta), para o número ficar à vista.
			_dica_do_mouse.mostrar(termometro.retangulo_do_ponteiro_na_tela, Vector2.DOWN, 44.0, Vector2(0.86, 0.5))
		_:
			_dica_do_mouse.parar()


## O alvo que a mão está mostrando agora ("" = nenhum).
func _alvo_da_dica() -> String:
	if _dica_do_mouse == null or not _dica_do_mouse.mostrando():
		return ""
	return _dica_no_alvo


# ─────────────────────────────────────────────────────────────
# O QUE A PESSOA FAZ
# ─────────────────────────────────────────────────────────────

func _pode_mexer() -> bool:
	return _estado == Estado.JOGANDO and not bloqueada and maquina.valvula_aberta and not maquina.estourado


## Uma seta do êmbolo: +1 desce (aperta), -1 sobe.
func mover_embolo(sentido: int) -> void:
	if not _pode_mexer():
		return
	maquina.mandar_embolo(maquina.alvo + sentido * PASSO_DO_EMBOLO)
	setas_embolo.animar_seta(-sentido)
	tocar("passo", 1.0 + sentido * 0.05)


## Uma seta do resfriador: +1 mais quente, -1 mais frio.
func mudar_resfriador(sentido: int) -> void:
	if not _pode_mexer():
		return
	pedir_celsius(GasFechado.para_celsius(maquina.temperatura_pedida) + sentido * PASSO_DO_RESFRIADOR)
	setas_resfriador.animar_seta(sentido)
	tocar("passo", 1.0 + sentido * 0.04)


func pedir_celsius(graus: float) -> void:
	maquina.pedir_celsius(roundf(graus))


func _pegar_o_embolo() -> void:
	_arrastando = "embolo"
	# A distância entre o ponteiro e o cabo fica a mesma o arrasto inteiro (o
	# cabo não pula para debaixo do ponteiro).
	var cabo := camara.retangulo_do_cabo()
	_pegada_do_embolo = camara.global_position.y + cabo.get_center().y - ponteiro().y
	# Achou o cabo: a mão que mostrava o gesto some (a do termômetro vem quando
	# ela soltar).
	if not arrastou_o_embolo:
		arrastou_o_embolo = true
		if _dica_do_mouse:
			_dica_do_mouse.parar()


func _pegar_o_ponteiro() -> void:
	_arrastando = "termometro"
	_levar_o_ponteiro(ponteiro())
	if not arrastou_o_termometro:
		arrastou_o_termometro = true
		if _dica_do_mouse:
			_dica_do_mouse.parar()


## A pessoa soltou o que arrastava: se ainda falta mostrar o gesto de alguma
## coisa, a mão aparece nela.
func _soltar() -> void:
	_arrastando = ""
	_mostrar_a_dica_do_mouse()


func _levar_o_ponteiro(ponto: Vector2) -> void:
	var local_y := ponto.y - termometro.global_position.y
	pedir_celsius(termometro.graus_no_ponto(local_y))


func pode_fechar() -> bool:
	return _estado == Estado.JOGANDO and maquina.amostra_pronta()


## Fecha a válvula: a máquina solta o cilindro com a amostra.
func fechar_valvula() -> void:
	if not pode_fechar():
		tocar("erro")
		return
	_amostra = maquina.fechar_valvula()
	if _amostra == null:
		return
	_segundos_da_amostra = MaquinaDeCompressao.tempo_ate_estourar(_amostra)
	_estado = Estado.FECHANDO
	_relogio_do_estado = 0.0
	_arrastando = ""
	tocar("botao")


## Laboratório: tudo de volta ao começo.
func recomecar() -> void:
	maquina.reiniciar()
	camara.reiniciar()
	_amostra = null
	_estado = Estado.JOGANDO
	_ja_condensou = false
	_clarao = 0.0
	_tremor_da_tela = 0.0
	_tremer(Vector2.ZERO)
	tocar("tirar")


func _ao_receber(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_soltar()
		return false
	if event is InputEventMouseMotion and not _arrastando.is_empty():
		if not _pode_mexer():
			_arrastando = ""
			return false
		if _arrastando == "embolo":
			maquina.mandar_embolo(camara.posicao_no_ponto_da_tela(event.position.y, _pegada_do_embolo))
		else:
			_levar_o_ponteiro(event.position)
		return true
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	# DEBUG: a amostra pronta na hora.
	if OS.is_debug_build() and (event as InputEventKey).physical_keycode == KEY_L and _estado == Estado.JOGANDO:
		maquina.resolver_na_hora()
		camara.reiniciar()
		return true
	if event.is_action_pressed(Interacao.ACAO) or event.is_action_pressed("ui_accept"):
		match _estado:
			Estado.JOGANDO:
				if pode_fechar():
					fechar_valvula()
					return true
			Estado.PRONTA:
				_entregar()
				return true
	return false


## As teclas seguradas mexem sem parar (só do TECLADO: o direcional e o
## analógico do controle levam o cursor).
func _teclas_seguradas(delta: float) -> void:
	if not _pode_mexer():
		return
	var embolo := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		embolo -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		embolo += 1.0
	if embolo != 0.0:
		maquina.mandar_embolo(maquina.alvo + embolo * EMBOLO_POR_SEGUNDO * delta)
	var frio := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		frio -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		frio += 1.0
	if frio != 0.0:
		maquina.pedir_celsius(GasFechado.para_celsius(maquina.temperatura_pedida) + frio * GRAUS_POR_SEGUNDO * delta)


func _ao_pedir_para_voltar() -> void:
	if not modo_historia:
		voltar()
		return
	if _estado == Estado.EXPLODINDO or _estado == Estado.FIM or _estado == Estado.FECHANDO:
		return
	if _estado == Estado.PRONTA:
		_entregar()
		return
	_estado = Estado.FIM
	_fechar_a_tela(func() -> void: fechou.emit())


func dicas_do_controle() -> Array:
	return [["analogico_esquerdo", "MOVER"], ["direcional", "ESCOLHER"],
		["cruz", "APERTAR (SEGURE PARA ARRASTAR)"], ["fechar", "FECHAR"]]


# ─────────────────────────────────────────────────────────────
# A CADA QUADRO
# ─────────────────────────────────────────────────────────────

func _a_cada_quadro(delta: float) -> void:
	_relogio_do_estado += delta
	_teclas_seguradas(delta)

	var passo := delta
	if _camera_lenta > 0.0:
		_camera_lenta = maxf(_camera_lenta - delta, 0.0)
		passo *= CAMERA_LENTA
	# No mapa, enquanto a linha do raio X passa (entrando ou saindo), a máquina
	# fica parada: o desenho tem de bater com a arte da sala na hora da troca.
	if _estado != Estado.FALANDO and not bloqueada:
		camara.avancar(passo)

	termometro.pedida = GasFechado.para_celsius(maquina.temperatura_pedida)
	termometro.medida = maquina.gas.celsius()
	termometro.em_foco = _arrastando == "termometro" or alvo_em_foco() == "termometro"
	termometro.definir_marcas(_marcas_do_termometro())
	camara.cabo_em_foco = _arrastando == "embolo" or alvo_em_foco() == "embolo"
	arrastando_com_o_mouse = not _arrastando.is_empty()
	if _dica_do_mouse:
		_dica_do_mouse.pausada = _estado != Estado.JOGANDO or bloqueada or not _arrastando.is_empty()
		var alvo_da_dica := _alvo_da_dica()
		_dica_do_mouse.ponteiro_em_cima = alvo_da_dica != "" and alvo_sob_o_ponteiro() == alvo_da_dica

	_proxima_previsao -= delta
	if _proxima_previsao <= 0.0 and _estado == Estado.JOGANDO:
		_proxima_previsao = 0.4
		_previsao = maquina.tempo_ate_estourar_se_fechar() if maquina.embolo_no_fim() else INF

	for i in 3:
		var agora := _meta(i)
		if agora and not _metas[i]:
			_pulo_da_meta[i] = 1.0
			tocar("certo")
		_metas[i] = agora
		_pulo_da_meta[i] = move_toward(_pulo_da_meta[i], 0.0, delta / 0.4)

	match _estado:
		Estado.FECHANDO:
			# A válvula gira, as garras abrem; aí a tela comemora.
			if _relogio_do_estado > 1.4:
				_estado = Estado.PRONTA
				_relogio_do_estado = 0.0
				_tocar("sucesso")
		Estado.EXPLODINDO:
			_clarao = move_toward(_clarao, 0.0, delta / 0.55)
			_tremor_da_tela = move_toward(_tremor_da_tela, 0.0, delta * 30.0)
			_tremer(Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * _tremor_da_tela)

	painel.queue_redraw()
	frente.queue_redraw()


## As metas da lista: 0 todo o ar no cilindro, 1 ar virando líquido, 2 sem
## estourar (vale enquanto a pressão está abaixo da ruptura).
func _meta(i: int) -> bool:
	match i:
		0:
			return maquina.embolo_no_fim()
		1:
			return maquina.gas.fracao_liquida >= MaquinaDeCompressao.FRACAO_LIQUIDA_DA_AMOSTRA \
				and maquina.embolo_no_fim()
		2:
			return not maquina.estourado and maquina.pressao() < MaquinaDeCompressao.PRESSAO_DE_RUPTURA
	return false


## A marca do termômetro: em que temperatura o ar começa a pingar NESTA
## pressão (o ponto de orvalho). Ela anda com a pressão — apertar o ar faz ele
## virar líquido mais "quente".
func _marcas_do_termometro() -> Array[Dictionary]:
	var pinga := GasFechado.para_celsius(maquina.gas.temperatura_de_condensacao())
	var marcas: Array[Dictionary] = [
		{"chave": "", "graus": roundf(pinga), "texto": TXT_PINGA, "cor": Color("8fd8ff")},
	]
	return marcas


func _cor_do_termometro(graus: float) -> Color:
	if graus <= 20.0:
		return Color("5fb8ff").lerp(Color("d9dcc8"), clampf(inverse_lerp(-190.0, 20.0, graus), 0.0, 1.0))
	return Color("d9dcc8").lerp(Color("f4a259"), clampf(inverse_lerp(20.0, 150.0, graus), 0.0, 1.0))


func _ao_gotejar() -> void:
	if _som_gota and randf() < 0.5:
		_som_gota.pitch_scale = randf_range(1.6, 2.4)
		_som_gota.play()


# ─────────────────────────────────────────────────────────────
# A EXPLOSÃO E O FIM
# ─────────────────────────────────────────────────────────────

func _ao_estourar() -> void:
	_estado = Estado.EXPLODINDO
	_arrastando = ""
	_como_estourou = {"pressao": maquina.pressao(), "temperatura": maquina.gas.celsius(),
		"posicao": maquina.posicao, "volume": maquina.volume(),
		"resfriador": GasFechado.para_celsius(maquina.temperatura_pedida)}
	_tocar("alarme")
	_tocar("chiado")


## A tela treme (o estrondo). No mapa, a câmera treme junto, para a sala e a
## máquina não se desencontrarem do raio X.
func _tremer(deslocamento: Vector2) -> void:
	position = deslocamento
	if not no_mundo():
		return
	var camera := get_viewport().get_camera_2d()
	if camera:
		camera.offset = -deslocamento / maxf(camera.zoom.x, 0.001)


func _ao_estrondo() -> void:
	_clarao = 1.0
	_tremor_da_tela = 22.0
	_camera_lenta = DURACAO_DA_CAMERA_LENTA
	if _som_alarme:
		_som_alarme.stop()
	if _som_chiado:
		_som_chiado.stop()
	_tocar("estrondo")


func _ao_terminar_a_explosao() -> void:
	_estado = Estado.FIM
	_tremer(Vector2.ZERO)
	cilindro_estourou.emit(_como_estourou)


## A amostra pronta vai embora com quem abriu a tela.
func _entregar() -> void:
	if _estado != Estado.PRONTA or _amostra == null:
		return
	_estado = Estado.FIM
	tocar("botao")
	var amostra := _amostra
	var segundos := _segundos_da_amostra
	var avisar := func() -> void: amostra_fechada.emit(amostra, segundos)
	if modo_historia:
		_fechar_a_tela(avisar)
	else:
		avisar.call()


## Fecha a tela e, depois, avisa quem abriu (no mapa, depois de o raio X sair).
func _fechar_a_tela(depois: Callable) -> void:
	_arrastando = ""
	arrastando_com_o_mouse = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if no_mundo() and is_inside_tree():
		await _sair_do_mundo()
	var camada := get_parent()
	if camada is CanvasLayer:
		camada.queue_free()
	else:
		queue_free()
	depois.call()


# ─────────────────────────────────────────────────────────────
# A FALA DO DR. CHICO (por cima da tela)
# ─────────────────────────────────────────────────────────────

func _falar(timeline: String) -> void:
	if Dialogic.current_timeline != null:
		return
	_estado = Estado.FALANDO
	Dialogic.process_mode = Node.PROCESS_MODE_ALWAYS
	var palco: Node = Dialogic.start(timeline)
	if palco != null:
		var camada := get_parent()
		var acima := (camada as CanvasLayer).layer + 10 if camada is CanvasLayer else 20
		palco.set("layer", acima)
		palco.process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 3:
		await get_tree().process_frame
	while Dialogic.current_timeline != null and is_inside_tree():
		await get_tree().process_frame
	if is_inside_tree() and _estado == Estado.FALANDO:
		_estado = Estado.JOGANDO


# ─────────────────────────────────────────────────────────────
# SONS
# ─────────────────────────────────────────────────────────────

func _tocar(nome: String) -> void:
	var tocador: AudioStreamPlayer = null
	match nome:
		"rangido":
			tocador = _som_rangido
		"valvula":
			tocador = _som_valvula
		"alarme":
			tocador = _som_alarme
		"estrondo":
			tocador = _som_estrondo
		"chiado":
			tocador = _som_chiado
		"sucesso":
			tocador = _som_sucesso
	if tocador and tocador.stream:
		tocador.pitch_scale = randf_range(0.9, 1.1) if nome == "rangido" else 1.0
		tocador.play()


# ─────────────────────────────────────────────────────────────
# O PAINEL (desenhado)
# ─────────────────────────────────────────────────────────────

## A tela tem três lugares, e cada informação aparece num só:
##   embaixo do título   a frase do que fazer agora (só uma);
##   à esquerda          o ar lá dentro, na própria equação dos gases;
##   no meio             o aparelho, com o nome de cada controle junto dele;
##   à direita           o OBJETIVO, com uma barrinha para cada meta, e o botão.
func _desenhar_o_painel() -> void:
	_desenhar_a_dica()
	_desenhar_a_equacao()
	_desenhar_o_objetivo()
	_desenhar_os_botoes()
	_desenhar_os_nomes_dos_controles()
	PecasDoLaboratorio.dicas_de_teclado(painel, Vector2(800, ALTURA_DAS_TECLAS), [
		[["tecla_w", "tecla_s"], TXT_EMBOLO],
		[["tecla_a", "tecla_d"], TXT_RESFRIADOR],
		[["tecla_e"], TXT_FECHAR],
	])


func _desenhar_a_frente() -> void:
	if _estado == Estado.PRONTA:
		_desenhar_a_comemoracao()
	if _estado == Estado.FIM and not modo_historia and maquina.estourado:
		_desenhar_o_que_houve()
	if _clarao > 0.0:
		frente.draw_rect(Rect2(-position - Vector2(40, 40), size + Vector2(80, 80)), Color(1, 1, 1, _clarao))


## O número com as casas fixas (a largura não pula enquanto ele muda) e vírgula.
func _num(valor: float, casas: int) -> String:
	return (("%." + str(casas) + "f") % valor).replace(".", ",")


## A frase do que fazer, embaixo do título: em laranja quando é perigo, em
## verde quando está pronto.
func _desenhar_a_dica() -> void:
	var texto := _dica()
	var cor := EstiloHUD.CLARO
	if texto == TXT_DICA_PERIGO or texto == TXT_ESTOUROU:
		cor = COR_DA_DICA_PERIGO
	elif texto == TXT_DICA_PRONTA:
		cor = COR_DA_DICA_PRONTA
	PecasDoLaboratorio.escrever_claro_no_meio(painel, Vector2(size.x * 0.5, _altura_da_dica), texto, 15, cor)


## O ar lá dentro, na própria equação dos gases: cada letra com o valor de
## agora embaixo, e a unidade. A pressão tem a cor do manômetro. O "n" é todo o
## ar da máquina e NÃO MUDA: o sistema é fechado (nada entra, nada sai), e o ar
## que vira líquido continua lá dentro. (Com líquido no fundo, a pressão é a do
## vapor por cima dele, e a conta P·V = n·R·T deixa de fechar — ver
## GasFechado.)
func _desenhar_a_equacao() -> void:
	var caixa := _painel_equacao
	EstiloHUD.ficha(painel, caixa)
	PecasDoLaboratorio.escrever(painel, caixa.position + Vector2(18, 16), TXT_O_AR, 13, EstiloHUD.TINTA_FRACA)
	var gas := maquina.gas
	var p := gas.pressao()
	var valores := [_num(p, 2), _num(gas.volume_do_gas(), 1), _num(gas.mols, 2),
		_num(GasFechado.R, 3), str(roundi(gas.temperatura))]
	var cores := [COR_PRESSAO[maquina.faixa_da_pressao(p)], EstiloHUD.TINTA, EstiloHUD.TINTA,
		EstiloHUD.TINTA_FRACA, EstiloHUD.TINTA]
	# Cinco colunas de letra e quatro estreitas de sinal, de ponta a ponta.
	var coluna := 52.0
	var sinal := (caixa.size.x - 28.0 - coluna * 5.0) / 4.0
	var x := caixa.position.x + 14.0
	var y_letra := caixa.position.y + 70.0
	for i in TXT_SIMBOLOS.size():
		var meio := x + coluna * 0.5
		PecasDoLaboratorio.escrever_no_meio(painel, Vector2(meio, y_letra), TXT_SIMBOLOS[i], 28, EstiloHUD.TINTA)
		PecasDoLaboratorio.escrever_no_meio(painel, Vector2(meio, y_letra + 40.0), valores[i], 15, cores[i])
		PecasDoLaboratorio.escrever_no_meio(painel, Vector2(meio, y_letra + 60.0), TXT_UNIDADES[i], 11,
			EstiloHUD.TINTA_FRACA)
		x += coluna
		if i < TXT_SINAIS.size():
			PecasDoLaboratorio.escrever_no_meio(painel, Vector2(x + sinal * 0.5, y_letra), TXT_SINAIS[i], 22,
				EstiloHUD.TINTA_FRACA)
			x += sinal


## O OBJETIVO: as duas metas com a barrinha de quanto falta, e a condição.
func _desenhar_o_objetivo() -> void:
	var metas := [
		{"texto": TXT_META_1, "feita": _metas[0], "pulo": _pulo_da_meta[0],
			"progresso": maquina.fracao_no_cilindro()},
		{"texto": TXT_META_2, "feita": _metas[1], "pulo": _pulo_da_meta[1],
			"progresso": maquina.gas.fracao_liquida / MaquinaDeCompressao.FRACAO_LIQUIDA_DA_AMOSTRA},
		{"texto": TXT_META_3, "feita": _metas[2], "pulo": _pulo_da_meta[2]},
	]
	var caixa := _painel_objetivo
	caixa.size.y = PecasDoLaboratorio.altura_da_lista_de_metas(metas.size())
	PecasDoLaboratorio.lista_de_metas(painel, caixa, TXT_OBJETIVO, metas)


func _desenhar_os_botoes() -> void:
	var foco := alvo_em_foco()
	PecasDoLaboratorio.botao(painel, _botao_fechar, TXT_FECHAR, foco == "fechar_valvula",
		alvo_segurado() == "fechar_valvula", pode_fechar(), 20,
		Color("bfe8c8") if pode_fechar() else EstiloHUD.PAPEL)
	# Quanto a amostra aguentaria se a válvula fechasse agora: só aparece com
	# todo o ar no cilindro, e é o que diz se vale a pena esfriar mais.
	if maquina.embolo_no_fim() and _estado == Estado.JOGANDO and _previsao != INF:
		var cor := COR_DA_DICA_PRONTA
		if _previsao < 25.0:
			cor = Color("ff8a80")
		elif _previsao < 35.0:
			cor = COR_DA_DICA_PERIGO
		PecasDoLaboratorio.escrever_claro_no_meio(painel, Vector2(_botao_fechar.get_center().x, _botao_fechar.end.y + 26.0),
			TXT_AGUENTA % roundi(_previsao), 13, cor)
	if not modo_historia:
		PecasDoLaboratorio.botao(painel, _botao_recomecar, TXT_RECOMECAR, foco == "recomecar",
			alvo_segurado() == "recomecar", true, 18, EstiloHUD.PAPEL_DOBRA)


func _desenhar_os_nomes_dos_controles() -> void:
	var setas := setas_embolo.get_global_rect()
	PecasDoLaboratorio.escrever_claro_no_meio(painel, Vector2(setas.get_center().x, setas.end.y + 16.0), TXT_EMBOLO, 11)
	var termo := termometro.get_global_rect()
	PecasDoLaboratorio.escrever_claro_no_meio(painel, Vector2(termo.get_center().x, termo.position.y - 14.0),
		TXT_RESFRIADOR, 11)


func _dica() -> String:
	match _estado:
		Estado.EXPLODINDO, Estado.FIM:
			return TXT_ESTOUROU if maquina.estourado else ""
		Estado.FECHANDO:
			return TXT_DICA_FECHANDO
		Estado.PRONTA:
			return ""
	if maquina.amostra_pronta():
		return TXT_DICA_PRONTA
	var faixa := maquina.faixa_da_pressao()
	if faixa >= 1:
		return TXT_DICA_PERIGO
	var gas_c := maquina.gas.celsius()
	var serpentina_c := GasFechado.para_celsius(maquina.temperatura_da_serpentina)
	if maquina.gas.fracao_liquida > 0.0:
		return TXT_DICA_LIQUIDO
	if gas_c - serpentina_c > 25.0 and maquina.posicao > 0.05 and not is_equal_approx(maquina.posicao, maquina.alvo):
		return TXT_DICA_ESQUENTOU
	if maquina.embolo_no_fim():
		var pinga := MisturasDoDestilador.graus(roundf(GasFechado.para_celsius(maquina.gas.temperatura_de_condensacao())))
		return TXT_DICA_RESFRIE_MAIS % pinga
	if serpentina_c > 60.0:
		return TXT_DICA_QUENTE
	if gas_c < -60.0:
		return TXT_DICA_FRIO
	return TXT_DICA_COMECO


func _desenhar_a_comemoracao() -> void:
	var t := clampf(_relogio_do_estado / 0.35, 0.0, 1.0)
	frente.draw_rect(Rect2(Vector2.ZERO, size), Color(EstiloHUD.VEU, 0.55 * t))
	var caixa := Rect2(480, 270, 640, 300)
	caixa.position.y += roundf((1.0 - ease(t, 0.3)) * 40.0)
	EstiloHUD.ficha(frente, caixa, t)
	var meio_x := caixa.get_center().x
	PecasDoLaboratorio.escrever_no_meio(frente, Vector2(meio_x, caixa.position.y + 54.0), TXT_PRONTA, 30,
		EstiloHUD.com_alfa(Color("1f5f9e"), t))
	var amostra := _amostra
	if amostra != null:
		var linha := TXT_DA_AMOSTRA % [MisturasDoDestilador.graus(roundf(amostra.celsius())),
			roundi(amostra.fracao_liquida * 100.0)]
		PecasDoLaboratorio.escrever_no_meio(frente, Vector2(meio_x, caixa.position.y + 112.0), linha, 18,
			EstiloHUD.com_alfa(EstiloHUD.TINTA, t))
		PecasDoLaboratorio.escrever_em_linhas(frente, Rect2(caixa.position.x + 50.0, caixa.position.y + 146.0,
			caixa.size.x - 100.0, 60.0), TXT_AGUENTA_NA_CORRIDA % roundi(_segundos_da_amostra), 15,
			EstiloHUD.com_alfa(EstiloHUD.TINTA_FRACA, t), 22.0)
	PecasDoLaboratorio.escrever_no_meio(frente, Vector2(meio_x, caixa.position.y + 228.0), TXT_LEVE, 22,
		EstiloHUD.com_alfa(Color("c0392b"), t * (0.75 + 0.25 * sin(_relogio_do_estado * 8.0))))
	# A tecla de continuar das folhas (a ficha de coleta), presa na beirada.
	if _relogio_do_estado > 0.6:
		EstiloHUD.tecla_da_folha(frente, FONTE, caixa, t)


## Laboratório: o que houve, depois que o cilindro estourou.
func _desenhar_o_que_houve() -> void:
	var caixa := Rect2(500, 300, 600, 200)
	EstiloHUD.ficha(frente, caixa)
	PecasDoLaboratorio.escrever_no_meio(frente, Vector2(caixa.get_center().x, caixa.position.y + 46.0), TXT_ESTOUROU, 28,
		Color("c0392b"))
	var texto := TXT_O_QUE_HOUVE % _num(float(_como_estourou.get("pressao", 4.0)), 1)
	PecasDoLaboratorio.escrever_em_linhas(frente, Rect2(caixa.position.x + 30.0, caixa.position.y + 84.0, caixa.size.x - 60.0, 90.0),
		texto, 15, EstiloHUD.TINTA, 22.0)
