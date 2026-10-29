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

## Na história, a tela se fecha por cima da fase; no Laboratório, é a cena.
@export var modo_historia: bool = true
## A conversa do Dr. Chico na primeira vez que a tela abre (vazio = sem fala).
@export var fala_de_abertura: String = ""

const TXT_TITULO := "COMPRESSOR DE AR"
const TXT_OBJETIVO := "OBJETIVO"
const TXT_META_1 := "TODO O AR NO CILINDRO"
const TXT_META_2 := "AR VIRANDO LÍQUIDO"
const TXT_META_3 := "SEM ESTOURAR (ATÉ 4 atm)"
const TXT_FECHAR := "FECHAR A VÁLVULA"
const TXT_RECOMECAR := "RECOMEÇAR"
const TXT_AGUENTA := "FECHADO, AGUENTA"
const TXT_EMBOLO := "ÊMBOLO"
const TXT_RESFRIADOR := "RESFRIADOR"
const TXT_O_AR := "O AR LÁ DENTRO"
const TXT_EQUACAO := "P · V = n · R · T"
const TXT_PRONTA := "AR LÍQUIDO NO CILINDRO!"
const TXT_LEVE := "LEVE AO DESTILADOR, DEPRESSA!"
const TXT_ESTOUROU := "O CILINDRO ESTOUROU!"
const TXT_PINGA := "AR VIRA\nLÍQUIDO"

## As dicas do rodapé, da mais urgente para a mais calma.
const DICA_COMECO := "EMPURRE O ÊMBOLO PARA LEVAR O AR DA CÂMARA PARA O CILINDRO."
const DICA_PERIGO := "CUIDADO! O CILINDRO SÓ AGUENTA 4 atm. RESFRIE O AR OU SUBA O ÊMBOLO."
const DICA_ESQUENTOU := "APERTAR ESQUENTA O GÁS: AS MOLÉCULAS SAEM MAIS RÁPIDAS DO ÊMBOLO."
const DICA_QUENTE := "MAIS QUENTE, AS MOLÉCULAS CORREM E BATEM MAIS FORTE: A PRESSÃO SOBE."
const DICA_FRIO := "MAIS FRIO, AS MOLÉCULAS FICAM LENTAS E A PRESSÃO CAI. AGORA DÁ PARA APERTAR MAIS."
const DICA_LIQUIDO := "O AR ESTÁ VIRANDO LÍQUIDO! NO LÍQUIDO AS MOLÉCULAS FICAM COLADINHAS."
const DICA_RESFRIE_MAIS := "TODO O AR ESTÁ NO CILINDRO. NESTA PRESSÃO ELE SÓ VIRA LÍQUIDO ABAIXO DE %s."
const DICA_PRONTA := "PRONTO! FECHE A VÁLVULA PARA SOLTAR O CILINDRO."
const DICA_FECHANDO := "VÁLVULA FECHADA. SOLTANDO O CILINDRO..."

## Onde ficam os painéis (px da tela).
const PAINEL_AR := Rect2(40, 108, 360, 330)
const PAINEL_EQUACAO := Rect2(40, 456, 360, 128)
const PAINEL_OBJETIVO := Rect2(1300, 108, 270, 196)
const PAINEL_AGUENTA := Rect2(1300, 320, 270, 92)
const BOTAO_FECHAR := Rect2(1300, 430, 270, 56)
const BOTAO_RECOMECAR := Rect2(1300, 500, 270, 52)
const RODAPE := Rect2(200, 800, 1200, 40)

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
	registrar_alvo("fechar_valvula", func() -> Rect2: return BOTAO_FECHAR, fechar_valvula, pode_fechar)
	if not modo_historia:
		registrar_alvo("recomecar", func() -> Rect2: return BOTAO_RECOMECAR, recomecar)

	_ja_condensou = maquina.gas.fracao_liquida > 0.0
	_metas = [_meta(0), _meta(1), _meta(2)]
	_estado = Estado.JOGANDO
	if modo_historia and not fala_de_abertura.is_empty():
		_falar(fala_de_abertura)


# ─────────────────────────────────────────────────────────────
# O QUE A PESSOA FAZ
# ─────────────────────────────────────────────────────────────

func _pode_mexer() -> bool:
	return _estado == Estado.JOGANDO and maquina.valvula_aberta and not maquina.estourado


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


func _pegar_o_ponteiro() -> void:
	_arrastando = "termometro"
	_levar_o_ponteiro(ponteiro())


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
	position = Vector2.ZERO
	tocar("tirar")


func _ao_receber(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_arrastando = ""
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
	_fechar_a_tela()
	fechou.emit()


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
	if _estado != Estado.FALANDO:
		camara.avancar(passo)

	termometro.pedida = GasFechado.para_celsius(maquina.temperatura_pedida)
	termometro.medida = maquina.gas.celsius()
	termometro.em_foco = _arrastando == "termometro" or alvo_em_foco() == "termometro"
	termometro.definir_marcas(_marcas_do_termometro())
	camara.cabo_em_foco = _arrastando == "embolo" or alvo_em_foco() == "embolo"

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
			position = Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * _tremor_da_tela

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
	position = Vector2.ZERO
	cilindro_estourou.emit(_como_estourou)


## A amostra pronta vai embora com quem abriu a tela.
func _entregar() -> void:
	if _estado != Estado.PRONTA or _amostra == null:
		return
	_estado = Estado.FIM
	tocar("botao")
	if modo_historia:
		_fechar_a_tela()
	amostra_fechada.emit(_amostra, _segundos_da_amostra)


func _fechar_a_tela() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	var camada := get_parent()
	if camada is CanvasLayer:
		camada.queue_free()
	else:
		queue_free()


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

func _desenhar_o_painel() -> void:
	_desenhar_o_ar()
	_desenhar_a_equacao()
	_desenhar_o_objetivo()
	_desenhar_o_aguenta()
	_desenhar_os_botoes()
	_desenhar_os_nomes_dos_controles()
	_desenhar_o_rodape()


func _desenhar_a_frente() -> void:
	if _estado == Estado.PRONTA:
		_desenhar_a_comemoracao()
	if _estado == Estado.FIM and not modo_historia and maquina.estourado:
		_desenhar_o_que_houve()
	if _clarao > 0.0:
		frente.draw_rect(Rect2(-position - Vector2(40, 40), size + Vector2(80, 80)), Color(1, 1, 1, _clarao))


func _num(valor: float, casas: int) -> String:
	return String.num(valor, casas).replace(".", ",")


## Uma linha "NOME ........ valor" num painel.
func _linha(caixa: Rect2, y: float, nome: String, valor: String, cor_valor: Color = EstiloHUD.TINTA) -> void:
	PecasDoLaboratorio.escrever(painel, Vector2(caixa.position.x + 18.0, y), nome, 13, EstiloHUD.TINTA_FRACA)
	var largura := PecasDoLaboratorio.largura(valor, 20)
	PecasDoLaboratorio.escrever(painel, Vector2(caixa.end.x - 18.0 - largura, y - 4.0), valor, 20, cor_valor)


func _desenhar_o_ar() -> void:
	var caixa := PAINEL_AR
	EstiloHUD.ficha(painel, caixa)
	PecasDoLaboratorio.escrever(painel, caixa.position + Vector2(18, 16), TXT_O_AR, 13, EstiloHUD.TINTA_FRACA)
	var p := maquina.pressao()
	var faixa := maquina.faixa_da_pressao(p)
	var cor_p: Color = [Color("1f7a3d"), Color("a8740b"), Color("c0392b")][faixa]
	var y := caixa.position.y + 52.0
	var passo := 44.0
	_linha(caixa, y, "PRESSÃO", _num(p, 2) + " atm", cor_p)
	_linha(caixa, y + passo, "VOLUME", _num(maquina.gas.volume_do_gas(), 1) + " L")
	_linha(caixa, y + passo * 2.0, "TEMPERATURA", MisturasDoDestilador.graus(roundf(maquina.gas.celsius())))
	_linha(caixa, y + passo * 3.0, "GÁS", _num(maquina.gas.mols_de_gas(), 2) + " mol")
	_linha(caixa, y + passo * 4.0, "LÍQUIDO", "%d%%" % roundi(maquina.gas.fracao_liquida * 100.0),
		Color("1f5f9e") if maquina.gas.fracao_liquida > 0.0 else EstiloHUD.TINTA)
	_linha(caixa, y + passo * 5.0, "NO CILINDRO", "%d%%" % roundi(maquina.fracao_no_cilindro() * 100.0))
	# Uma bolinha vale 0,01 mol (6 × 10²¹ moléculas).
	PecasDoLaboratorio.escrever(painel, Vector2(caixa.position.x + 18.0, caixa.end.y - 30.0),
		"CADA BOLINHA = 0,01 mol", 11, EstiloHUD.TINTA_FRACA)


## A equação dos gases com os números de agora: os dois lados batem (para o
## gás; o líquido não entra na conta).
func _desenhar_a_equacao() -> void:
	var caixa := PAINEL_EQUACAO
	EstiloHUD.ficha(painel, caixa)
	PecasDoLaboratorio.escrever_no_meio(painel, Vector2(caixa.get_center().x, caixa.position.y + 30.0),
		TXT_EQUACAO, 22, EstiloHUD.TINTA)
	var gas := maquina.gas
	var p := gas.pressao()
	var v := gas.volume_do_gas()
	var n := gas.mols_de_gas()
	var t := gas.temperatura
	var esquerda := _num(p, 2) + " × " + _num(v, 1)
	var direita := _num(n, 2) + " × 0,082 × " + str(roundi(t))
	PecasDoLaboratorio.escrever_no_meio(painel, Vector2(caixa.get_center().x, caixa.position.y + 66.0),
		esquerda + "  =  " + direita, 13, EstiloHUD.TINTA)
	PecasDoLaboratorio.escrever_no_meio(painel, Vector2(caixa.get_center().x, caixa.position.y + 96.0),
		_num(p * v, 2) + "  =  " + _num(n * GasFechado.R * t, 2) + "   (T EM KELVIN)", 11, EstiloHUD.TINTA_FRACA)


func _desenhar_o_objetivo() -> void:
	var caixa := PAINEL_OBJETIVO
	EstiloHUD.ficha(painel, caixa)
	PecasDoLaboratorio.escrever(painel, caixa.position + Vector2(18, 16), TXT_OBJETIVO, 13, EstiloHUD.TINTA_FRACA)
	var textos := [TXT_META_1, TXT_META_2, TXT_META_3]
	for i in 3:
		var y := caixa.position.y + 52.0 + i * 46.0
		var quadrado := Rect2(caixa.position.x + 18.0, y - 2.0, 22.0, 22.0).grow(roundf(_pulo_da_meta[i] * 3.0))
		EstiloHUD.bloco(painel, quadrado, EstiloHUD.TINTA)
		painel.draw_rect(quadrado.grow(-3.0), Color("3ecf72") if _metas[i] else EstiloHUD.PAPEL_DOBRA)
		if _metas[i]:
			# O visto, em pixels.
			var c := quadrado.get_center()
			for k in 3:
				painel.draw_rect(Rect2(c + Vector2(-6 + k * 2, -1 + k * 2), Vector2(3, 3)), EstiloHUD.TINTA)
			for k in 4:
				painel.draw_rect(Rect2(c + Vector2(0 + k * 2, 3 - k * 3), Vector2(3, 3)), EstiloHUD.TINTA)
		PecasDoLaboratorio.escrever_em_linhas(painel, Rect2(caixa.position.x + 50.0, y - 2.0, caixa.size.x - 66.0, 40.0),
			String(textos[i]), 13, EstiloHUD.TINTA, 16.0, false)


## Quanto a amostra aguentaria se a válvula fechasse agora (com o êmbolo no
## fim): é o que diz se vale a pena esfriar mais.
func _desenhar_o_aguenta() -> void:
	var caixa := PAINEL_AGUENTA
	var alfa := 1.0 if maquina.embolo_no_fim() and _estado == Estado.JOGANDO else 0.45
	EstiloHUD.ficha(painel, caixa, alfa)
	PecasDoLaboratorio.escrever(painel, caixa.position + Vector2(18, 14), TXT_AGUENTA, 13,
		EstiloHUD.com_alfa(EstiloHUD.TINTA_FRACA, alfa))
	var texto := "--"
	var cor := EstiloHUD.TINTA
	if maquina.embolo_no_fim() and _estado == Estado.JOGANDO:
		if _previsao == INF:
			texto = "SEM LIMITE"
		else:
			texto = "%d s ATÉ ESTOURAR" % roundi(_previsao)
			cor = Color("c0392b") if _previsao < 25.0 else (Color("a8740b") if _previsao < 35.0 else Color("1f7a3d"))
	elif _amostra != null:
		texto = "%d s ATÉ ESTOURAR" % roundi(_segundos_da_amostra)
	PecasDoLaboratorio.escrever(painel, caixa.position + Vector2(18, 44), texto, 20, EstiloHUD.com_alfa(cor, alfa))


func _desenhar_os_botoes() -> void:
	var foco := alvo_em_foco()
	PecasDoLaboratorio.botao(painel, BOTAO_FECHAR, TXT_FECHAR, foco == "fechar_valvula",
		alvo_segurado() == "fechar_valvula", pode_fechar(), 20,
		Color("bfe8c8") if pode_fechar() else EstiloHUD.PAPEL)
	if not modo_historia:
		PecasDoLaboratorio.botao(painel, BOTAO_RECOMECAR, TXT_RECOMECAR, foco == "recomecar",
			alvo_segurado() == "recomecar", true, 20, Color("d9b99b"))


func _desenhar_os_nomes_dos_controles() -> void:
	var setas := setas_embolo.get_global_rect()
	PecasDoLaboratorio.escrever_no_meio(painel, Vector2(setas.get_center().x, setas.end.y + 14.0), TXT_EMBOLO, 11, EstiloHUD.CLARO)
	var termo := termometro.get_global_rect()
	PecasDoLaboratorio.escrever_no_meio(painel, Vector2(termo.get_center().x, termo.position.y - 12.0), TXT_RESFRIADOR, 11, EstiloHUD.CLARO)


func _dica() -> String:
	match _estado:
		Estado.EXPLODINDO, Estado.FIM:
			return TXT_ESTOUROU if maquina.estourado else ""
		Estado.FECHANDO:
			return DICA_FECHANDO
		Estado.PRONTA:
			return ""
	if maquina.amostra_pronta():
		return DICA_PRONTA
	var faixa := maquina.faixa_da_pressao()
	if faixa >= 1:
		return DICA_PERIGO
	var gas_c := maquina.gas.celsius()
	var serpentina_c := GasFechado.para_celsius(maquina.temperatura_da_serpentina)
	if maquina.gas.fracao_liquida > 0.0:
		return DICA_LIQUIDO
	if gas_c - serpentina_c > 25.0 and maquina.posicao > 0.05 and not is_equal_approx(maquina.posicao, maquina.alvo):
		return DICA_ESQUENTOU
	if maquina.embolo_no_fim():
		var pinga := MisturasDoDestilador.graus(roundf(GasFechado.para_celsius(maquina.gas.temperatura_de_condensacao())))
		return DICA_RESFRIE_MAIS % pinga
	if serpentina_c > 60.0:
		return DICA_QUENTE
	if gas_c < -60.0:
		return DICA_FRIO
	return DICA_COMECO


func _desenhar_o_rodape() -> void:
	var texto := _dica()
	if not texto.is_empty():
		PecasDoLaboratorio.escrever_no_meio(painel, RODAPE.get_center(), texto, 15, EstiloHUD.CLARO)
	PecasDoLaboratorio.dicas_de_teclado(painel, Vector2(800, 866), [
		[["tecla_w", "tecla_s"], "ÊMBOLO"],
		[["tecla_a", "tecla_d"], "RESFRIADOR"],
		[["tecla_e"], "FECHAR A VÁLVULA"],
	])


func _desenhar_a_comemoracao() -> void:
	var t := clampf(_relogio_do_estado / 0.35, 0.0, 1.0)
	frente.draw_rect(Rect2(Vector2.ZERO, size), Color(EstiloHUD.VEU, 0.55 * t))
	var caixa := Rect2(460, 250, 680, 330)
	caixa.position.y += roundf((1.0 - ease(t, 0.3)) * 40.0)
	EstiloHUD.ficha(frente, caixa, t)
	var meio_x := caixa.get_center().x
	PecasDoLaboratorio.escrever_no_meio(frente, Vector2(meio_x, caixa.position.y + 52.0), TXT_PRONTA, 30,
		EstiloHUD.com_alfa(Color("1f5f9e"), t))
	var amostra := _amostra
	if amostra != null:
		var linha := "%s mol de ar  ·  %d%% líquido  ·  %s" % [_num(amostra.mols, 2),
			roundi(amostra.fracao_liquida * 100.0), MisturasDoDestilador.graus(roundf(amostra.celsius()))]
		PecasDoLaboratorio.escrever_no_meio(frente, Vector2(meio_x, caixa.position.y + 112.0), linha, 18,
			EstiloHUD.com_alfa(EstiloHUD.TINTA, t))
		var aguenta := "FECHADO, O CALOR DA SALA VAI ENTRANDO: AGUENTA %d s ATÉ ESTOURAR." % roundi(_segundos_da_amostra)
		PecasDoLaboratorio.escrever_em_linhas(frente, Rect2(caixa.position.x + 40.0, caixa.position.y + 150.0, caixa.size.x - 80.0, 60.0),
			aguenta, 15, EstiloHUD.com_alfa(EstiloHUD.TINTA_FRACA, t), 22.0)
	PecasDoLaboratorio.escrever_no_meio(frente, Vector2(meio_x, caixa.position.y + 236.0), TXT_LEVE, 22,
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
	var texto := "A PRESSÃO CHEGOU A %s atm, E O CILINDRO SÓ AGUENTA 4. RESFRIE O AR ANTES DE APERTAR." \
		% _num(float(_como_estourou.get("pressao", 4.0)), 1)
	PecasDoLaboratorio.escrever_em_linhas(frente, Rect2(caixa.position.x + 30.0, caixa.position.y + 84.0, caixa.size.x - 60.0, 90.0),
		texto, 15, EstiloHUD.TINTA, 22.0)
