extends TelaInterativa

# --- COMPRESSOR DE AR (Laboratório): o simulador de gases ---
#
# O compressor de ar da fase do nitrogênio, solto da história e sem o
# cilindro — o ar fica todo numa caixa com um êmbolo —, para ver
# P · V = n · R · T funcionando. Não há objetivo: é um brinquedo para o
# professor apresentar os gases ideais (e para quem quiser estourar a caixa de
# propósito).
#
# Quatro letras, quatro cores, e cada letra é uma peça da máquina, marcada
# com a FICHA da cor dela:
#
#   V  o ÊMBOLO      arraste o cabo (ou use as setas ao lado da caixa). O
#                    cadeado na haste solta o êmbolo: solto, ele anda sozinho
#                    e a PRESSÃO fica a mesma — esquente e veja ele subir.
#   n  a BOMBA       ligada no fundo da caixa: cada bombada põe 0,1 mol de ar
#                    (5 bolinhas); a válvula vermelha no cano da direita (ou a
#                    seta de baixo) tira.
#   T  o TERMÔMETRO  o ponteiro é o termostato, de −150 °C a 1000 °C; a
#                    coluna é o gás, que vai atrás dele.
#   P  o MANÔMETRO   é a consequência das outras três. Passou de 4 atm, a
#                    caixa estoura (o êmbolo sai voando), e RECOMEÇAR monta a
#                    máquina de novo.
#
# Embaixo, a EQUAÇÃO com os números de agora, cada letra na ficha dela. Ao
# lado de cada ficha, uma setinha diz se aquele número está subindo ou
# descendo: é por ela que se vê, sem ler nada, que apertar o êmbolo faz V
# descer e P subir. Com o ponteiro numa peça, a ficha da letra dela acende, na
# máquina e na equação. A temperatura da equação é em KELVIN; a do termômetro,
# em °C — lado a lado, as duas mostram a conta.
#
# Texto escrito, só o que não dá para desenhar: as letras, os números, as
# unidades e o RECOMEÇAR. Quem explica é a máquina.
#
# A física está em MaquinaDoSimulador (scripts/laboratorio/
# maquina_do_simulador.gd), sobre a do compressor da fase (GasFechado); o
# desenho, em CamaraDoSimulador (scripts/ui/camara_do_simulador.gd).
#
# CONTROLES: mouse (arrastar o cabo do êmbolo e o ponteiro do termômetro;
# clicar nas setas, na bomba, no alívio e no cadeado). Teclado: W/S ou ↑/↓ o
# êmbolo, A/D ou ←/→ a temperatura, E ou + bombeia, Q ou − solta ar, ESPAÇO o
# cadeado, R recomeça, ESC volta. Controle: o cursor, ✕ (segurando, arrasta)
# e △.
#
# ONDE MEXER:
#   as cores, as medidas e os textos logo abaixo   as fichas, a equação, os
#                                                  botões.
#   scripts/laboratorio/maquina_do_simulador.gd    os números da máquina.
#   scripts/ui/camara_do_simulador.gd              o desenho da bomba, do
#                                                  alívio e da trava.
#   scenes/laboratorio/compressor.tscn             onde ficam a câmara, o
#                                                  termômetro, as setas e os
#                                                  sons.

## A cor de cada letra: a da ficha dela, na peça e na equação.
const CORES := {
	"P": Color("e8463a"),
	"V": Color("5fb8ff"),
	"n": Color("3ecf72"),
	"T": Color("f4a259"),
}

const TXT_RECOMECAR := "RECOMEÇAR"
const TXT_ESTOUROU := "ESTOUROU!"
const TXT_PASSOU := "A PRESSÃO PASSOU DE %d atm"
const TXT_R := "0,082"
const TXT_UNIDADE_DO_R := "atm·L/mol·K"
const TXT_OPERADORES := ["·", "="]

# ── As fichas das letras ──
## Na máquina (ao lado de cada peça) e na equação: o lado e o tamanho da letra.
const LADO_DA_FICHA := 48.0
const LETRA_DA_FICHA := 33
const LADO_DA_FICHA_DA_EQUACAO := 60.0
const LETRA_DA_FICHA_DA_EQUACAO := 44
## A fonte do jogo desenha a letra mais alta que o "ascent" dela: medido na
## tela, a maiúscula ocupa 86% do tamanho, o "n" 70%, e o meio do "=" e do "·"
## fica a 39% acima da linha de base. É por isto que cada letra é posta no
## meio da ficha pela TINTA, e não pelas medidas da fonte.
const MEIO_DA_TINTA := {"n": 0.35, "=": 0.39, "·": 0.39}
const MEIO_DA_MAIUSCULA := 0.43

# ── A equação (px da tela) ──
const EQUACAO := Rect2(340, 736, 920, 140)
## As colunas, da esquerda para a direita: [o que vai nela, a largura].
const COLUNAS_DA_EQUACAO := [["P", 160.0], ["·", 30.0], ["V", 140.0], ["=", 46.0], ["n", 160.0],
	["·", 30.0], ["R", 120.0], ["·", 30.0], ["T", 140.0]]
## Do alto da ficha da equação até o meio das fichas, até o meio dos números
## e até a unidade do R.
const ALTURA_DAS_FICHAS := 46.0
const ALTURA_DOS_NUMEROS := 102.0
const ALTURA_DA_UNIDADE := 124.0
const TAM_DOS_NUMEROS := 22

## A setinha de subindo e descendo: a partir de quanto (por segundo) cada
## número conta como mudando.
const MUDANDO := {"P": 0.03, "V": 0.15, "n": 0.02, "T": 1.5}
## De que letra é cada peça: com o ponteiro numa delas, a ficha da letra
## acende na máquina e na equação.
const LETRA_DO_ALVO := {
	"embolo": "V", "trava": "V", "embolo_sobe": "V", "embolo_desce": "V",
	"bomba": "n", "alivio": "n", "mais_ar": "n", "menos_ar": "n",
	"termometro": "T", "mais_quente": "T", "mais_frio": "T",
}

# ── Os botões ──
const BOTAO_RECOMECAR := Rect2(1300, 800, 250, 56)
const CARTAO_DO_ESTOURO := Rect2(470, 290, 520, 240)

# ── O que cada toque e cada tecla mexe ──
## As setas do êmbolo: 1/50 do curso por toque.
const PASSO_DO_EMBOLO := 0.02
## As setas do termômetro: 1 °C por toque; segurando, o passo cresce (5 °C e
## depois 10 °C, sempre em números redondos), que a escala é grande.
const PASSOS_DO_TERMOSTATO := [1.0, 5.0, 10.0]
## Quantos repetecos seguidos com cada passo antes de passar ao próximo.
const REPETECOS_POR_PASSO := 10
## As teclas seguradas: o curso do êmbolo e os graus por segundo.
const EMBOLO_POR_SEGUNDO := 0.35
const GRAUS_POR_SEGUNDO := 150.0

## A câmera lenta logo depois do estrondo (como no puzzle da fase).
const CAMERA_LENTA := 0.3
const DURACAO_DA_CAMERA_LENTA := 0.7

enum Estado { BRINCANDO, EXPLODINDO, ESTOURADO }

var maquina: MaquinaDoSimulador

var _estado: Estado = Estado.BRINCANDO
var _arrastando: String = ""
var _pegada_do_embolo: float = 0.0
var _relogio_do_estado: float = 0.0
var _clarao: float = 0.0
var _tremor_da_tela: float = 0.0
var _camera_lenta: float = 0.0
## A setinha de cada letra: o quanto o número está mudando (positivo subindo),
## e o valor do quadro anterior.
var _tendencias := {}
var _antes := {}
## Os repetecos seguidos das setas do termômetro (para o passo crescer).
var _repetecos: int = 0
var _ultimo_toque_no_termostato: float = -INF
var _ultimo_sentido: int = 0
var _relogio: float = 0.0

@onready var camara: CamaraDoSimulador = $Camara
@onready var termometro: Termometro = $Termometro
@onready var setas_embolo: SeletorCoeficiente = $SetasEmbolo
@onready var setas_ar: SeletorCoeficiente = $SetasAr
@onready var setas_termometro: SeletorCoeficiente = $SetasTermometro
@onready var painel: Control = $Painel
## A camada de cima de tudo: o clarão do estrondo e o cartão do estouro.
@onready var frente: Control = $Frente
@onready var _som_rangido: AudioStreamPlayer = get_node_or_null("SomRangido")
@onready var _som_alarme: AudioStreamPlayer = get_node_or_null("SomAlarme")
@onready var _som_estrondo: AudioStreamPlayer = get_node_or_null("SomEstrondo")
@onready var _som_chiado: AudioStreamPlayer = get_node_or_null("SomChiado")
@onready var _som_bomba: AudioStreamPlayer = get_node_or_null("SomBomba")
@onready var _som_alivio: AudioStreamPlayer = get_node_or_null("SomAlivio")


func _ao_abrir() -> void:
	maquina = MaquinaDoSimulador.new()
	painel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	painel.draw.connect(_desenhar_o_painel)
	frente.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frente.draw.connect(_desenhar_a_frente)
	camara.maquina = maquina
	camara.estourando.connect(_ao_estourar)
	camara.estrondo.connect(_ao_estrondo)
	camara.explosao_terminou.connect(_ao_terminar_a_explosao)
	camara.rangeu.connect(_tocar.bind("rangido"))
	camara.bombeou.connect(_tocar.bind("bomba"))
	camara.aliviou.connect(_tocar.bind("alivio"))

	termometro.definir_faixa(MaquinaDoSimulador.TERMOSTATO_MINIMO, MaquinaDoSimulador.TERMOSTATO_MAXIMO)
	termometro.cor_da_temperatura = _cor_do_termometro
	for setas: SeletorCoeficiente in [setas_embolo, setas_ar, setas_termometro]:
		setas.numero.text = ""

	# A ordem conta: onde dois alvos se cobrem, vale o registrado depois (o
	# cadeado fica em cima da haste do êmbolo).
	registrar_alvo("embolo", camara.retangulo_de_pegar_o_embolo_na_tela, _pegar_o_embolo, _pode_mexer)
	registrar_alvo("trava", camara.retangulo_da_trava_na_tela, alternar_trava, _pode_mexer)
	registrar_alvo("embolo_sobe", setas_embolo.retangulo_do_botao.bind(1), mover_embolo.bind(-1),
		_embolo_pode_ir.bind(-1), true)
	registrar_alvo("embolo_desce", setas_embolo.retangulo_do_botao.bind(-1), mover_embolo.bind(1),
		_embolo_pode_ir.bind(1), true)
	registrar_alvo("bomba", camara.retangulo_da_bomba_na_tela, bombear, _pode_bombear, true)
	registrar_alvo("alivio", camara.retangulo_do_alivio_na_tela, soltar_ar, _pode_soltar, true)
	registrar_alvo("mais_ar", setas_ar.retangulo_do_botao.bind(1), bombear, _pode_bombear, true)
	registrar_alvo("menos_ar", setas_ar.retangulo_do_botao.bind(-1), soltar_ar, _pode_soltar, true)
	registrar_alvo("termometro", termometro.retangulo_de_pegar_na_tela, _pegar_o_ponteiro, _pode_mexer)
	registrar_alvo("mais_quente", setas_termometro.retangulo_do_botao.bind(1), mudar_temperatura.bind(1),
		_termostato_pode_ir.bind(1), true)
	registrar_alvo("mais_frio", setas_termometro.retangulo_do_botao.bind(-1), mudar_temperatura.bind(-1),
		_termostato_pode_ir.bind(-1), true)
	registrar_alvo("recomecar", retangulo_do_recomecar, recomecar)


# ─────────────────────────────────────────────────────────────
# O QUE A PESSOA FAZ
# ─────────────────────────────────────────────────────────────

func _pode_mexer() -> bool:
	return _estado == Estado.BRINCANDO and not maquina.estourado


## Dá para levar o êmbolo para esse lado (+1 desce, −1 sobe)? Solto, sempre:
## o toque trava ele onde está e anda dali.
func _embolo_pode_ir(sentido: int) -> bool:
	if not _pode_mexer():
		return false
	if maquina.embolo_solto:
		return true
	return maquina.alvo < 1.0 if sentido > 0 else maquina.alvo > 0.0


func _termostato_pode_ir(sentido: int) -> bool:
	if not _pode_mexer():
		return false
	var graus := GasFechado.para_celsius(maquina.temperatura_pedida)
	return graus < MaquinaDoSimulador.TERMOSTATO_MAXIMO - 0.01 if sentido > 0 \
		else graus > MaquinaDoSimulador.TERMOSTATO_MINIMO + 0.01


func _pode_bombear() -> bool:
	return _pode_mexer() and camara.pode_bombear()


func _pode_soltar() -> bool:
	return _pode_mexer() and camara.pode_soltar()


## Uma seta do êmbolo: +1 desce (aperta), −1 sobe.
func mover_embolo(sentido: int) -> void:
	if not _embolo_pode_ir(sentido):
		return
	var de := maquina.posicao if maquina.embolo_solto else maquina.alvo
	maquina.mandar_embolo(de + sentido * PASSO_DO_EMBOLO)
	setas_embolo.animar_seta(-sentido)
	tocar("passo", 1.0 + sentido * 0.05)


## O cadeado: fechado, o êmbolo fica onde está; aberto, ele segura a pressão.
func alternar_trava() -> void:
	if not _pode_mexer():
		return
	if maquina.embolo_solto:
		maquina.travar_embolo()
	else:
		maquina.soltar_embolo()
	tocar("botao", 1.15 if maquina.embolo_solto else 0.9)


## Uma seta do termômetro: +1 mais quente, −1 mais frio. Toques seguidos (a
## seta segurada) vão de passo maior em passo maior.
func mudar_temperatura(sentido: int) -> void:
	if not _termostato_pode_ir(sentido):
		return
	if _relogio - _ultimo_toque_no_termostato > 0.4 or sentido != _ultimo_sentido:
		_repetecos = 0
	_ultimo_toque_no_termostato = _relogio
	_ultimo_sentido = sentido
	var passo: float = PASSOS_DO_TERMOSTATO[mini(floori(float(_repetecos) / REPETECOS_POR_PASSO),
		PASSOS_DO_TERMOSTATO.size() - 1)]
	_repetecos += 1
	var graus := GasFechado.para_celsius(maquina.temperatura_pedida)
	# O próximo número redondo para aquele lado (de 25 °C, de 5 em 5: 30).
	var depois := (floorf(graus / passo + 0.001) + 1.0) * passo if sentido > 0 \
		else (ceilf(graus / passo - 0.001) - 1.0) * passo
	pedir_celsius(depois)
	setas_termometro.animar_seta(sentido)
	tocar("passo", 1.0 + sentido * 0.04)


func pedir_celsius(graus: float) -> void:
	maquina.pedir_celsius(roundf(graus))


## Uma bombada (a bomba ou a seta de cima do n).
func bombear() -> void:
	if not _pode_bombear():
		return
	if camara.bombear():
		setas_ar.animar_seta(1)


## Um sopro do alívio (a válvula ou a seta de baixo do n).
func soltar_ar() -> void:
	if not _pode_soltar():
		return
	if camara.soltar_ar():
		setas_ar.animar_seta(-1)


func _pegar_o_embolo() -> void:
	if maquina.embolo_solto:
		maquina.travar_embolo()
	_arrastando = "embolo"
	# A distância entre o ponteiro e o cabo fica a mesma o arrasto inteiro (o
	# cabo não pula para debaixo do ponteiro).
	_pegada_do_embolo = camara.global_position.y + camara.retangulo_do_cabo().get_center().y - ponteiro().y


func _pegar_o_ponteiro() -> void:
	_arrastando = "termometro"
	_levar_o_ponteiro(ponteiro())


func _levar_o_ponteiro(ponto: Vector2) -> void:
	pedir_celsius(termometro.graus_no_ponto(ponto.y - termometro.global_position.y))


## A máquina de novo, como no começo: 1 mol de ar da sala, 25 °C, câmara
## cheia, êmbolo travado.
func recomecar() -> void:
	maquina.reiniciar()
	camara.reiniciar()
	_estado = Estado.BRINCANDO
	_arrastando = ""
	_clarao = 0.0
	_tremor_da_tela = 0.0
	_camera_lenta = 0.0
	position = Vector2.ZERO
	_tendencias.clear()
	_antes.clear()
	for som in [_som_alarme, _som_chiado, _som_estrondo]:
		if som:
			som.stop()
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
	# As teclas (só do TECLADO: o direcional do controle leva o cursor). O
	# êmbolo e a temperatura andam enquanto a tecla está segurada
	# (_teclas_seguradas); aqui ficam as de toque.
	if not event is InputEventKey or not event.pressed:
		return false
	match (event as InputEventKey).physical_keycode:
		KEY_E, KEY_EQUAL, KEY_KP_ADD:
			bombear()
			return true
		KEY_Q, KEY_MINUS, KEY_KP_SUBTRACT:
			soltar_ar()
			return true
		KEY_SPACE:
			if not event.echo:
				alternar_trava()
			return true
		KEY_R:
			if not event.echo:
				recomecar()
			return true
	return false


func _teclas_seguradas(delta: float) -> void:
	if not _pode_mexer():
		return
	var embolo := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		embolo -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		embolo += 1.0
	if embolo != 0.0:
		var de := maquina.posicao if maquina.embolo_solto else maquina.alvo
		maquina.mandar_embolo(de + embolo * EMBOLO_POR_SEGUNDO * delta)
	var calor := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		calor -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		calor += 1.0
	if calor != 0.0:
		maquina.pedir_celsius(GasFechado.para_celsius(maquina.temperatura_pedida) + calor * GRAUS_POR_SEGUNDO * delta)


func dicas_do_controle() -> Array:
	return [["analogico_esquerdo", "MOVER"], ["direcional", "ESCOLHER"],
		["cruz", "APERTAR (SEGURE PARA ARRASTAR)"], ["fechar", "VOLTAR"]]


# ─────────────────────────────────────────────────────────────
# A CADA QUADRO
# ─────────────────────────────────────────────────────────────

func _a_cada_quadro(delta: float) -> void:
	_relogio += delta
	_relogio_do_estado += delta
	_teclas_seguradas(delta)

	var passo := delta
	if _camera_lenta > 0.0:
		_camera_lenta = maxf(_camera_lenta - delta, 0.0)
		passo *= CAMERA_LENTA
	camara.avancar(passo)

	termometro.pedida = GasFechado.para_celsius(maquina.temperatura_pedida)
	termometro.medida = maquina.gas.celsius()
	termometro.em_foco = _arrastando == "termometro" or alvo_em_foco() == "termometro"
	var foco := alvo_em_foco()
	camara.cabo_em_foco = _arrastando == "embolo" or foco == "embolo"
	camara.trava_em_foco = foco == "trava"
	camara.bomba_em_foco = foco == "bomba"
	camara.alivio_em_foco = foco == "alivio"
	_apagar_as_setas_que_nao_valem()
	if _estado == Estado.BRINCANDO:
		_acompanhar_as_tendencias(delta)

	if _estado == Estado.EXPLODINDO:
		_clarao = move_toward(_clarao, 0.0, delta / 0.55)
		_tremor_da_tela = move_toward(_tremor_da_tela, 0.0, delta * 30.0)
		position = Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * _tremor_da_tela

	painel.queue_redraw()
	frente.queue_redraw()


## A seta que não vale agora (no fim do curso, sem ar para tirar...) fica
## apagada.
func _apagar_as_setas_que_nao_valem() -> void:
	var setas := [[setas_embolo, "embolo_sobe", "embolo_desce"], [setas_ar, "mais_ar", "menos_ar"],
		[setas_termometro, "mais_quente", "mais_frio"]]
	for linha: Array in setas:
		var seletor: SeletorCoeficiente = linha[0]
		seletor.botao_mais.modulate.a = 1.0 if alvo_disponivel(String(linha[1])) else 0.3
		seletor.botao_menos.modulate.a = 1.0 if alvo_disponivel(String(linha[2])) else 0.3


## Os números da equação agora: P em atm, V em L, n em mol, T em K.
func valores() -> Dictionary:
	var gas := maquina.gas
	return {"P": gas.pressao(), "V": gas.volume, "n": gas.mols, "T": gas.temperatura}


func _acompanhar_as_tendencias(delta: float) -> void:
	var agora := valores()
	for letra: String in agora:
		var antes := float(_antes.get(letra, agora[letra]))
		var ritmo := (float(agora[letra]) - antes) / maxf(delta, 0.0001) / float(MUDANDO[letra])
		_tendencias[letra] = lerpf(float(_tendencias.get(letra, 0.0)), ritmo, 1.0 - exp(-delta / 0.15))
	_antes = agora


## A letra da peça sob o ponteiro (ou sendo arrastada); "" se nenhuma.
func letra_em_foco() -> String:
	if _estado != Estado.BRINCANDO:
		return ""
	var alvo := _arrastando if not _arrastando.is_empty() else alvo_em_foco()
	return String(LETRA_DO_ALVO.get(alvo, ""))


## Para onde a setinha da letra aponta: +1 subindo, −1 descendo, 0 parado.
func tendencia(letra: String) -> int:
	var t := float(_tendencias.get(letra, 0.0))
	if absf(t) < 1.0:
		return 0
	return 1 if t > 0.0 else -1


func _cor_do_termometro(graus: float) -> Color:
	return camara.cor_da_temperatura(graus)


# ─────────────────────────────────────────────────────────────
# O ESTOURO
# ─────────────────────────────────────────────────────────────

func _ao_estourar() -> void:
	_estado = Estado.EXPLODINDO
	_relogio_do_estado = 0.0
	_arrastando = ""
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
	_estado = Estado.ESTOURADO
	_relogio_do_estado = 0.0
	position = Vector2.ZERO


func estourou() -> bool:
	return _estado != Estado.BRINCANDO


## A explosão acabou e o cartão do estouro está na tela.
func cartao_aberto() -> bool:
	return _estado == Estado.ESTOURADO


# ─────────────────────────────────────────────────────────────
# SONS
# ─────────────────────────────────────────────────────────────

func _tocar(nome: String) -> void:
	var tocador: AudioStreamPlayer = null
	match nome:
		"rangido":
			tocador = _som_rangido
		"alarme":
			tocador = _som_alarme
		"estrondo":
			tocador = _som_estrondo
		"chiado":
			tocador = _som_chiado
		"bomba":
			tocador = _som_bomba
		"alivio":
			tocador = _som_alivio
	if tocador and tocador.stream:
		tocador.pitch_scale = randf_range(0.92, 1.08) if nome in ["rangido", "bomba", "alivio"] else 1.0
		tocador.play()


# ─────────────────────────────────────────────────────────────
# ONDE FICA CADA COISA
# ─────────────────────────────────────────────────────────────

## O RECOMEÇAR: no canto; estourado, dentro do cartão do estouro.
func retangulo_do_recomecar() -> Rect2:
	if _estado == Estado.ESTOURADO:
		return Rect2(CARTAO_DO_ESTOURO.get_center().x - 125.0, CARTAO_DO_ESTOURO.end.y - 88.0, 250.0, 56.0)
	return BOTAO_RECOMECAR


## O meio da ficha de cada letra na máquina: em cima das setas do êmbolo e
## do ar, em cima do termômetro e ao lado do manômetro.
func meio_da_ficha_na_maquina(letra: String) -> Vector2:
	match letra:
		"V":
			return _acima_de(setas_embolo.get_global_rect())
		"n":
			return _acima_de(setas_ar.get_global_rect())
		"T":
			return _acima_de(termometro.get_global_rect())
	var manometro := camara.retangulo_do_manometro_na_tela()
	return Vector2(manometro.end.x + 14.0 + LADO_DA_FICHA * 0.5, manometro.get_center().y).round()


func _acima_de(caixa: Rect2) -> Vector2:
	return Vector2(caixa.get_center().x, caixa.position.y - 8.0 - LADO_DA_FICHA * 0.5).round()


## O meio de cada coluna da equação, na ordem de COLUNAS_DA_EQUACAO.
func _meios_das_colunas() -> Array[float]:
	var total := 0.0
	for coluna: Array in COLUNAS_DA_EQUACAO:
		total += float(coluna[1])
	var meios: Array[float] = []
	var x := EQUACAO.get_center().x - total * 0.5
	for coluna: Array in COLUNAS_DA_EQUACAO:
		meios.append(roundf(x + float(coluna[1]) * 0.5))
		x += float(coluna[1])
	return meios


## Onde fica a ficha da letra na equação.
func retangulo_da_ficha_na_equacao(letra: String) -> Rect2:
	var meios := _meios_das_colunas()
	for i in COLUNAS_DA_EQUACAO.size():
		if COLUNAS_DA_EQUACAO[i][0] == letra:
			var meio := Vector2(meios[i], EQUACAO.position.y + ALTURA_DAS_FICHAS)
			return Rect2(meio - Vector2.ONE * LADO_DA_FICHA_DA_EQUACAO * 0.5, Vector2.ONE * LADO_DA_FICHA_DA_EQUACAO)
	return Rect2()


## O número de cada letra como a equação escreve (com a unidade).
func texto_do_valor(letra: String) -> String:
	var v := valores()
	match letra:
		"P":
			return _num(float(v["P"]), 2) + " atm"
		"V":
			return _num(float(v["V"]), 1) + " L"
		"n":
			return _num(float(v["n"]), 2) + " mol"
		"T":
			return "%d K" % roundi(float(v["T"]))
		"R":
			return TXT_R
	return ""


static func _num(valor: float, casas: int) -> String:
	return (("%." + str(casas) + "f") % valor).replace(".", ",")


# ─────────────────────────────────────────────────────────────
# DESENHO
# ─────────────────────────────────────────────────────────────

## A ficha de uma letra: um quadrado da cor dela, com a moldura escura e a
## letra no meio. Acesa, ela ganha o aro claro dos botões em foco. Devolve
## onde ficou.
static func desenhar_ficha(ci: CanvasItem, meio: Vector2, letra: String, lado: float, tamanho: int,
		alfa: float = 1.0, acesa: bool = false) -> Rect2:
	var caixa := Rect2((meio - Vector2.ONE * lado * 0.5).round(), Vector2.ONE * lado)
	var cor: Color = CORES[letra]
	if acesa:
		EstiloHUD.bloco(ci, caixa.grow(4.0), EstiloHUD.com_alfa(EstiloHUD.CLARO, alfa))
	EstiloHUD.bloco(ci, Rect2(caixa.position + Vector2(0.0, EstiloHUD.QUEDA), caixa.size),
		EstiloHUD.com_alfa(EstiloHUD.SOMBRA_DURA, alfa))
	EstiloHUD.bloco(ci, caixa, EstiloHUD.com_alfa(EstiloHUD.CONTORNO, alfa))
	var miolo := caixa.grow(-3.0)
	ci.draw_rect(miolo, EstiloHUD.com_alfa(cor, alfa))
	ci.draw_rect(Rect2(miolo.position.x, miolo.end.y - 4.0, miolo.size.x, 4.0), EstiloHUD.com_alfa(cor.darkened(0.2), alfa))
	ci.draw_rect(Rect2(miolo.position.x, miolo.position.y, miolo.size.x, 2.0), EstiloHUD.com_alfa(cor.lightened(0.3), alfa))
	# A letra no meio do papel colorido (a faixa escura de baixo é a dobra).
	escrever_pela_tinta(ci, meio + Vector2(0.0, -1.0), letra, tamanho, EstiloHUD.com_alfa(EstiloHUD.CONTORNO, alfa))
	return caixa


## Escreve uma letra (ou um "=", um "·") com o meio da TINTA dela em "meio".
static func escrever_pela_tinta(ci: CanvasItem, meio: Vector2, letra: String, tamanho: int, cor: Color) -> void:
	var pe := meio.y + float(MEIO_DA_TINTA.get(letra, MEIO_DA_MAIUSCULA)) * tamanho
	ci.draw_string(FONTE, Vector2(meio.x - PecasDoLaboratorio.largura(letra, tamanho) * 0.5, pe).round(), letra,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)


func _desenhar_o_painel() -> void:
	var alfa := 1.0 if _estado == Estado.BRINCANDO else 0.4
	var acesa := letra_em_foco()
	for letra: String in ["V", "n", "T", "P"]:
		desenhar_ficha(painel, meio_da_ficha_na_maquina(letra), letra, LADO_DA_FICHA, LETRA_DA_FICHA, alfa,
			letra == acesa)
	_desenhar_a_equacao()
	if _estado != Estado.ESTOURADO:
		PecasDoLaboratorio.botao(painel, BOTAO_RECOMECAR, TXT_RECOMECAR, alvo_em_foco() == "recomecar",
			alvo_segurado() == "recomecar", true, 22, Color("d9b99b"))


## P · V = n · R · T, cada letra na ficha dela, com o número de agora embaixo.
func _desenhar_a_equacao() -> void:
	EstiloHUD.ficha(painel, EQUACAO)
	var meios := _meios_das_colunas()
	var y_fichas := EQUACAO.position.y + ALTURA_DAS_FICHAS
	var y_numeros := EQUACAO.position.y + ALTURA_DOS_NUMEROS
	for i in COLUNAS_DA_EQUACAO.size():
		var peca := String(COLUNAS_DA_EQUACAO[i][0])
		var x := meios[i]
		if peca in TXT_OPERADORES:
			escrever_pela_tinta(painel, Vector2(x, y_fichas), peca, 44, EstiloHUD.TINTA)
			continue
		if peca == "R":
			escrever_pela_tinta(painel, Vector2(x, y_fichas), peca, 44, EstiloHUD.TINTA)
			PecasDoLaboratorio.escrever_no_meio(painel, Vector2(x, y_numeros), TXT_R, TAM_DOS_NUMEROS, EstiloHUD.TINTA)
			PecasDoLaboratorio.escrever_no_meio(painel, Vector2(x, EQUACAO.position.y + ALTURA_DA_UNIDADE),
				TXT_UNIDADE_DO_R, 11, EstiloHUD.TINTA_FRACA)
			continue
		var ficha := desenhar_ficha(painel, Vector2(x, y_fichas), peca, LADO_DA_FICHA_DA_EQUACAO,
			LETRA_DA_FICHA_DA_EQUACAO, 1.0, peca == letra_em_foco())
		var cor := EstiloHUD.TINTA
		if peca == "P" and maquina.faixa_da_pressao() >= 1:
			cor = Color("a8740b") if maquina.faixa_da_pressao() == 1 else Color("c0392b")
		PecasDoLaboratorio.escrever_no_meio(painel, Vector2(x, y_numeros), texto_do_valor(peca), TAM_DOS_NUMEROS, cor)
		var sentido := tendencia(peca) if _estado == Estado.BRINCANDO else 0
		if sentido != 0:
			_desenhar_a_setinha(Vector2(ficha.end.x + 18.0, ficha.get_center().y), sentido, CORES[peca])


## A setinha de subindo (+1) ou descendo (−1): a ponta em degraus de pixel e
## a haste, com o contorno escuro.
func _desenhar_a_setinha(meio: Vector2, sentido: int, cor: Color) -> void:
	var faixas: Array[Rect2] = []
	for i in 5:
		var largura := 2.0 + i * 4.0
		faixas.append(Rect2(meio.x - largura * 0.5, meio.y - 12.0 + i * 3.0, largura, 3.0))
	faixas.append(Rect2(meio.x - 3.0, meio.y + 3.0, 6.0, 9.0))
	if sentido < 0:
		# Descendo: o mesmo desenho, de ponta-cabeça.
		for i in faixas.size():
			var faixa := faixas[i]
			faixas[i] = Rect2(faixa.position.x, 2.0 * meio.y - faixa.end.y, faixa.size.x, faixa.size.y)
	for faixa in faixas:
		painel.draw_rect(faixa.grow(2.0), EstiloHUD.CONTORNO)
	for faixa in faixas:
		painel.draw_rect(faixa, cor)


func _desenhar_a_frente() -> void:
	if _estado == Estado.ESTOURADO:
		_desenhar_o_estouro()
	if _clarao > 0.0:
		frente.draw_rect(Rect2(-position - Vector2(40, 40), size + Vector2(80, 80)), Color(1, 1, 1, _clarao))


## Depois da explosão: o cartão com o que houve e o RECOMEÇAR.
func _desenhar_o_estouro() -> void:
	var t := clampf(_relogio_do_estado / 0.35, 0.0, 1.0)
	frente.draw_rect(Rect2(Vector2.ZERO, size), Color(EstiloHUD.VEU, 0.45 * t))
	var caixa := CARTAO_DO_ESTOURO
	caixa.position.y += roundf((1.0 - ease(t, 0.3)) * 30.0)
	EstiloHUD.ficha(frente, caixa, t)
	var meio_x := caixa.get_center().x
	PecasDoLaboratorio.escrever_no_meio(frente, Vector2(meio_x, caixa.position.y + 52.0), TXT_ESTOUROU, 33,
		EstiloHUD.com_alfa(Color("c0392b"), t))
	PecasDoLaboratorio.escrever_no_meio(frente, Vector2(meio_x, caixa.position.y + 104.0),
		TXT_PASSOU % roundi(MaquinaDeCompressao.PRESSAO_DE_RUPTURA), 22, EstiloHUD.com_alfa(EstiloHUD.TINTA, t))
	if t >= 1.0:
		PecasDoLaboratorio.botao(frente, retangulo_do_recomecar(), TXT_RECOMECAR, alvo_em_foco() == "recomecar",
			alvo_segurado() == "recomecar", true, 22, Color("d9b99b"))
