extends CanvasLayer

# --- PUZZLE DO BUMERANGUE (domo de vidro da entrada, fase 1) ---
#
# O bumerangue do Dr. Chico está trancado no domo de vidro da entrada da
# Oficina do Carbono. Para destravar, o computador pede o átomo de CARBONO
# montado, partícula por partícula. É a ideia do puzzle do hidrogênio do
# prólogo (próton, nêutron e elétron, cada um no lugar dele), agora com o
# carbono e na tela do computador da fase 1, a mesma do puzzle do maçarico. E,
# como nele, tudo se mexe pelas SETAS: a de cima põe uma partícula no átomo, a
# de baixo tira.
#
#   NÚCLEO        6 prótons (o número atômico da caixa do elemento, Z = 6) e
#                 6 nêutrons (a massa da caixa, 12, menos os 6 prótons:
#                 A = Z + n)
#   ELETROSFERA   6 elétrons (átomo neutro: e = p), 2 na camada K, que só
#                 comporta 2, e 4 na camada L
#
# São quatro seletores (scenes/ui/seletor_particula.tscn), cada um com as duas
# setas, a partícula e a conta dela: prótons, nêutrons, elétrons da camada K e
# elétrons da camada L. A partícula sai do seletor e vai para o lugar dela no
# átomo: próton e nêutron para o núcleo, elétron para a camada, onde fica
# girando. A seta de baixo a traz de volta.
#
#   conta amarela    ainda falta
#   conta verde      bate
#   conta vermelha   passou
#
# Dá para passar da conta (7 prótons, 5 elétrons na L): ela fica vermelha, o
# terminal diz o que sobrou e a seta de baixo tira. O que não cabe (o terceiro
# elétron na camada K) a seta de cima recusa, e o terminal diz por quê. Quando
# tudo bate, a tela mostra "BUMERANGUE LIBERADO!" e o rodapé pede o E que abre
# o domo.
#
# Fechar a tela no meio e voltar não desmonta o átomo.
#
# ONDE MEXER:
#   as constantes logo abaixo   o átomo pedido, os textos do terminal e os
#                               raios do desenho.
#   scenes/puzzle_carbono.tscn  a tela: posições, fontes, cores, sons, a caixa
#                               do elemento e os seletores. O átomo é
#                               desenhado no meio do nó Atomo; as partículas
#                               têm a arte e o tamanho do Icone do seletor
#                               de cada uma.
#   scenes/ui/seletor_particula.tscn
#                               a coluna de cada conta (setas, partícula,
#                               número e nome).
#   assets/UI/Computador receptor/particulas_atomo.png
#                               a arte das partículas.
#
# INTERFACE (a mesma que a GaiolaPuzzle espera de todo puzzle de gaiola):
#   sinal "puzzle_resolvido" e método "abrir_puzzle()".
# CONTROLES: mouse nas setas; ESC fecha.
#   No controle: o analógico leva o cursor, o direcional pula de seta em seta,
#   ✕ aperta, △ fecha e □ abre o domo no fim (ver cursor_virtual.gd).
# DEBUG: a tecla L resolve o puzzle na hora.

signal puzzle_resolvido

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

# ── O átomo pedido ──
const PROTONS := 6
const NEUTRONS := 6
const ELETRONS_K := 2
const ELETRONS_L := 4
## Quantos elétrons cada camada comporta, seja qual for o átomo.
const CABEM_NA_K := 2
const CABEM_NA_L := 8
## O núcleo aceita até isto de cada partícula: dá para errar para mais e
## corrigir. As vagas dele são o dobro disto.
const MAXIMO_DE_CADA := 8

## Os quatro seletores: a partícula que cada um põe, quantas dela o átomo pede
## ali e quantas cabem.
const SELETORES := {
	"protons": {"tipo": "proton", "pedido": PROTONS, "cabem": MAXIMO_DE_CADA},
	"neutrons": {"tipo": "neutron", "pedido": NEUTRONS, "cabem": MAXIMO_DE_CADA},
	"camada_k": {"tipo": "eletron", "pedido": ELETRONS_K, "cabem": CABEM_NA_K},
	"camada_l": {"tipo": "eletron", "pedido": ELETRONS_L, "cabem": CABEM_NA_L},
}

# ── O que o terminal diz ──
const TXT_INSTRUCAO := "USE AS SETAS PARA PÔR E TIRAR PARTÍCULAS DO ÁTOMO"
const TXT_MONTADO := "ÁTOMO DE CARBONO MONTADO"
## Rodapé da tela final. {interact} vira "E" no teclado e □ no controle.
const TXT_ABRIR_DOMO := "APERTE {interact} PARA ABRIR O DOMO"
const TXT_NUCLEO_CHEIO := "O NÚCLEO NÃO COMPORTA MAIS %s"
const TXT_CAMADA_CHEIA := "A CAMADA %s SÓ COMPORTA %d ELÉTRONS"
const TXT_PROTONS_DEMAIS := "PRÓTONS DEMAIS: O CARBONO TEM NÚMERO ATÔMICO %d"
const TXT_NEUTRONS_DEMAIS := "NÊUTRONS DEMAIS: PRÓTONS + NÊUTRONS = %d"
const TXT_ELETRONS_DEMAIS := "ELÉTRONS DEMAIS: NO ÁTOMO NEUTRO, ELÉTRONS = PRÓTONS"

# ── O desenho do átomo (px da tela do computador, a partir do meio do Atomo) ──
const RAIO_NUCLEO := 74.0
const RAIO_K := 118.0
const RAIO_L := 178.0
## As vagas do núcleo saem do meio para fora, em espiral (a do girassol): a
## vaga i fica a PASSO_DO_NUCLEO * raiz(i + 0,5) do meio.
const PASSO_DO_NUCLEO := 14.0
const ANGULO_DOURADO := 2.39996
## Quanto cada camada gira (radianos por segundo) e a pressa com que o elétron
## alcança o lugar dele nela.
const VELOCIDADE_K := 1.8
const VELOCIDADE_L := 1.0
const PRESSA_DO_ELETRON := 18.0
## Quanto a partícula leva do seletor até a vaga do núcleo, e de volta.
const DURACAO_DA_IDA := 0.22
const DURACAO_DA_VOLTA := 0.18

const COR_AMARELO := Color(1, 0.85, 0)
const COR_CERTO := Color.GREEN
const COR_ERRO := Color(1.0, 0.35, 0.3)
const COR_ANEL := Color(0.56, 0.78, 1.0, 0.6)
const COR_LED_TRAVADO := Color(0.9, 0.12, 0.1)
const COR_LED_MONTADO := Color(0.35, 0.95, 0.45)
const COR_LED_LIBERADO := Color(0.3, 0.75, 1.0)

var travado: bool = false
var aguardando_fechamento: bool = false

# Cada abertura é uma sessão nova. Toda corrotina anota a sua e desiste se,
# ao acordar, a tela já tiver sido fechada (ou fechada e reaberta).
var _sessao: int = 0
var _tweens: Array = []
var _tempo: float = 0.0
var _rodape_texto: String = ""
var _rodape_padrao: String = ""
var _rodape_cursor: bool = false

## As vagas do núcleo: a partícula em cada uma, ou null.
var _nucleo: Array[TextureRect] = []
var _camada_k: Array[TextureRect] = []
var _camada_l: Array[TextureRect] = []
var _fase_k: float = 0.0
var _fase_l: float = 0.0

@onready var led: ColorRect = $RootControl/Tela/Led
@onready var display: Control = $RootControl/Tela/Display
@onready var cabecalho: Label = $RootControl/Tela/Display/Cabecalho
@onready var rodape: Label = $RootControl/Tela/Display/Rodape
@onready var grupo_atomo: Control = $RootControl/Tela/Display/GrupoAtomo
@onready var atomo: Control = $RootControl/Tela/Display/GrupoAtomo/Atomo
@onready var particulas: Control = $RootControl/Tela/Display/GrupoAtomo/Particulas
## Os seletores da tela, com os nomes dos SELETORES.
@onready var seletores := {
	"protons": $RootControl/Tela/Display/GrupoAtomo/Seletores/SeletorProtons as SeletorParticula,
	"neutrons": $RootControl/Tela/Display/GrupoAtomo/Seletores/SeletorNeutrons as SeletorParticula,
	"camada_k": $RootControl/Tela/Display/GrupoAtomo/Seletores/SeletorCamadaK as SeletorParticula,
	"camada_l": $RootControl/Tela/Display/GrupoAtomo/Seletores/SeletorCamadaL as SeletorParticula,
}
@onready var grupo_liberado: Control = $RootControl/Tela/Display/GrupoLiberado
@onready var label_liberado: Label = $RootControl/Tela/Display/GrupoLiberado/LabelLiberado
@onready var audio_sucesso: AudioStreamPlayer = $AudioSucesso
@onready var audio_erro: AudioStreamPlayer = $AudioErro
@onready var audio_drag: AudioStreamPlayer = $AudioDrag
@onready var audio_pop: AudioStreamPlayer = $AudioPop


func _ready() -> void:
	hide()
	set_process(false)
	# Controle: cursor nesta tela e as teclas dos textos viram botões. O texto do
	# canto mora na cena, com a marca {fechar}; o do rodapé é escrito aqui (ver
	# _mostrar_liberado).
	add_to_group(CursorVirtual.GRUPO)
	# A tecla do "para fechar" sai em escala 2: no texto miúdo do canto, o
	# desenho em escala 1 ficava ilegível.
	Controle.rotular($RootControl/Instrucoes, $RootControl/Instrucoes.text, 2.0)
	IconesNoTexto.acoplar(rodape)
	Controle.mudou.connect(_ao_trocar_controle)
	atomo.draw.connect(_desenhar_atomo)
	_nucleo.resize(MAXIMO_DE_CADA * 2)
	# Onde cada conta fica em repouso: tremer duas vezes seguidas não pode
	# deixá-la fora do lugar.
	for qual: String in seletores:
		var conta := _conta(qual)
		conta.set_meta("pos_base", conta.position)
	_atualizar_contagem()


# ------------------------- ABRIR E FECHAR -------------------------

func abrir_puzzle() -> void:
	_sessao += 1
	show()
	Interacao.marcar_tela_aberta(self, true)
	set_process(true)
	_resetar()

	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = false
	get_tree().paused = true
	_ligar_tela()


func fechar_puzzle(resolvido: bool) -> void:
	_sessao += 1
	hide()
	Interacao.marcar_tela_aberta(self, false)
	set_process(false)
	_matar_tweens()
	_limpar_soltas()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	get_tree().paused = false
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = true
	if resolvido:
		puzzle_resolvido.emit()


## O átomo montado até aqui fica: só o que é do momento volta ao começo.
func _resetar() -> void:
	_matar_tweens()
	_limpar_soltas()
	# Reabrir depois de resolvido (um teste): começa do zero.
	if travado:
		_esvaziar()
	travado = false
	aguardando_fechamento = false
	_tempo = 0.0

	display.scale = Vector2.ONE
	display.modulate = Color.WHITE
	led.color = COR_LED_TRAVADO
	grupo_atomo.show()
	grupo_atomo.modulate = Color.WHITE
	grupo_liberado.hide()
	grupo_liberado.modulate = Color.WHITE
	for qual: String in seletores:
		var conta := _conta(qual)
		conta.scale = Vector2.ONE
		conta.position = conta.get_meta("pos_base", conta.position)
	# As partículas do núcleo de volta na vaga, caso um tween tenha morrido no
	# meio do caminho.
	for i in _nucleo.size():
		if _nucleo[i] != null:
			_nucleo[i].position = _lugar_da_vaga(i, _nucleo[i])

	_definir_rodape(TXT_INSTRUCAO, true)
	_atualizar_contagem()
	atomo.queue_redraw()


# A tela "liga" como monitor de tubo: uma linha que abre na vertical.
func _ligar_tela() -> void:
	display.scale = Vector2(1.0, 0.02)
	display.modulate.a = 0.0
	var tween := _tween()
	tween.set_parallel(true)
	tween.tween_property(display, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(display, "modulate:a", 1.0, 0.16)


# ------------------------- ENTRADA -------------------------

func _process(delta: float) -> void:
	_tempo += delta
	if not travado:
		led.modulate.a = 1.0 if fmod(_tempo, 1.1) >= 0.5 else 0.55
	else:
		led.modulate.a = 1.0
	var cursor_visivel := _rodape_cursor and fmod(_tempo, 1.0) < 0.5
	var texto := _rodape_texto + ("_" if cursor_visivel else "")
	if rodape.text != texto:
		rodape.text = texto

	_fase_k += VELOCIDADE_K * delta
	_fase_l += VELOCIDADE_L * delta
	_girar(_camada_k, RAIO_K, _fase_k, delta)
	_girar(_camada_l, RAIO_L, _fase_l, delta)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	# A tela está por cima de tudo: o E que fecha o puzzle não pode sobrar para
	# o domo que está logo atrás dela.
	if event.is_action_pressed(Interacao.ACAO):
		Interacao.consumir()

	if event is InputEventMouseMotion:
		_atualizar_cursor(event.position)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if aguardando_fechamento:
			fechar_puzzle(true)
			return
		_clicar(event.position)
		_atualizar_cursor(event.position)

	var tecla: bool = event is InputEventKey and event.pressed and not event.echo
	if tecla and event.keycode == KEY_L:
		# DEBUG: resolve o puzzle na hora, para não montar o átomo a cada teste.
		fechar_puzzle(true)
		return
	# As teclas de sempre e, pelas ações do mapa, △/□/✕ do controle.
	if aguardando_fechamento:
		if (tecla and event.keycode in [KEY_ESCAPE, KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]) \
				or event.is_action_pressed("fechar") or event.is_action_pressed("ui_accept") \
				or event.is_action_pressed(Interacao.ACAO):
			fechar_puzzle(true)
		return
	if (tecla and event.keycode == KEY_ESCAPE) or event.is_action_pressed("fechar"):
		if not travado:
			fechar_puzzle(false)


func _pode_mexer() -> bool:
	return not travado and grupo_atomo.visible


func _clicar(pos: Vector2) -> void:
	if not _pode_mexer():
		return
	for qual: String in seletores:
		var sentido: int = seletores[qual].botao_no_ponto(pos)
		if sentido != 0:
			alterar(qual, sentido)
			return


func _atualizar_cursor(pos: Vector2) -> void:
	var sobre := aguardando_fechamento
	if _pode_mexer():
		for qual: String in seletores:
			if seletores[qual].botao_no_ponto(pos) != 0:
				sobre = true
				break
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if sobre else Input.CURSOR_ARROW)


# ------------------------- CONTROLE (ver cursor_virtual.gd) -------------------------

## As duas setas de cada seletor.
func alvos_do_cursor() -> Array[Rect2]:
	var alvos: Array[Rect2] = []
	if not _pode_mexer():
		return alvos
	for qual: String in seletores:
		alvos.append(seletores[qual].retangulo_do_botao(1))
		alvos.append(seletores[qual].retangulo_do_botao(-1))
	return alvos


func dicas_do_controle() -> Array:
	if aguardando_fechamento:
		return [[Interacao.ACAO, "ABRIR O DOMO"]]
	return [
		["analogico_esquerdo", "MOVER"],
		["direcional", "ESCOLHER"],
		["cruz", "APERTAR"],
		["fechar", "SAIR"],
	]


## O rodapé final diz a tecla (ou o botão) que abre o domo: trocou de
## teclado para controle com ele na tela, ele se reescreve.
func _ao_trocar_controle(_em_uso: bool) -> void:
	if aguardando_fechamento:
		_definir_rodape(Controle.texto(TXT_ABRIR_DOMO, true), true)


# ------------------------- AS SETAS -------------------------

## A seta de um seletor ("protons", "neutrons", "camada_k" ou "camada_l"): a de
## cima (+1) põe uma partícula no átomo, a de baixo (-1) tira.
func alterar(qual: String, sentido: int) -> void:
	if not _pode_mexer():
		return
	seletores[qual].animar_seta(sentido)
	# Mexeu de novo: o aviso de antes já não vale.
	_voltar_rodape()
	if sentido > 0:
		_por(qual)
	else:
		_tirar(qual)
	_atualizar_contagem()
	atomo.queue_redraw()
	if montado():
		_concluir()


## Quantas partículas o seletor já pôs no átomo.
func quantas(qual: String) -> int:
	match qual:
		"camada_k":
			return _camada_k.size()
		"camada_l":
			return _camada_l.size()
	return no_nucleo(SELETORES[qual]["tipo"])


func _por(qual: String) -> void:
	var conta := _conta(qual)
	if quantas(qual) >= SELETORES[qual]["cabem"]:
		_errar(_aviso_de_cheio(qual), conta)
		return
	var peca := _nova_peca(qual)
	match qual:
		"camada_k":
			_por_na_camada(peca, _camada_k, _fase_k)
		"camada_l":
			_por_na_camada(peca, _camada_l, _fase_l)
		_:
			_por_no_nucleo(peca)

	var pedido: int = SELETORES[qual]["pedido"]
	if quantas(qual) > pedido:
		_errar(_aviso_de_sobra(qual), conta)
		return
	audio_pop.play()
	if quantas(qual) == pedido:
		_celebrar(conta)


func _tirar(qual: String) -> void:
	var peca := _a_que_sai(qual)
	if peca == null:
		return
	_tirar_do_atomo(peca)
	audio_drag.play()
	var tween := _tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(peca, "position", _lugar_no_seletor(qual), DURACAO_DA_VOLTA)
	tween.tween_callback(peca.queue_free)
	if quantas(qual) == SELETORES[qual]["pedido"]:
		_celebrar(_conta(qual))


func _aviso_de_cheio(qual: String) -> String:
	match qual:
		"protons":
			return TXT_NUCLEO_CHEIO % "PRÓTONS"
		"neutrons":
			return TXT_NUCLEO_CHEIO % "NÊUTRONS"
		"camada_k":
			return TXT_CAMADA_CHEIA % ["K", CABEM_NA_K]
	return TXT_CAMADA_CHEIA % ["L", CABEM_NA_L]


func _aviso_de_sobra(qual: String) -> String:
	match qual:
		"protons":
			return TXT_PROTONS_DEMAIS % PROTONS
		"neutrons":
			return TXT_NEUTRONS_DEMAIS % (PROTONS + NEUTRONS)
	return TXT_ELETRONS_DEMAIS


## O número do seletor: é ele que muda de cor, pula e treme.
func _conta(qual: String) -> Label:
	return seletores[qual].quantos


# ------------------------- ONDE FICA CADA COISA -------------------------
#
# As partículas moram no nó Particulas, e é nas medidas dele que tudo aqui é
# pensado: o meio do átomo e a partícula de cada seletor são trazidos para ele.

func _na_tela_do_computador(ponto_na_tela: Vector2) -> Vector2:
	return particulas.get_global_transform().affine_inverse() * ponto_na_tela


func _centro() -> Vector2:
	return _na_tela_do_computador(atomo.get_global_transform() * (atomo.size * 0.5))


## O meio do átomo, em px da tela do jogo.
func centro_na_tela() -> Vector2:
	return atomo.get_global_transform() * (atomo.size * 0.5)


## O canto em que a partícula do seletor está (o de uma nova, igual a ela).
func _lugar_no_seletor(qual: String) -> Vector2:
	return _na_tela_do_computador(seletores[qual].icone.global_position)


## O canto da partícula quando ela está na vaga i do núcleo.
func _lugar_da_vaga(i: int, peca: Control) -> Vector2:
	var do_meio := Vector2.from_angle(i * ANGULO_DOURADO) * PASSO_DO_NUCLEO * sqrt(i + 0.5)
	return (_centro() + do_meio - peca.size * 0.5).round()


# ------------------------- AS PARTÍCULAS -------------------------

func _tipo(peca: Control) -> String:
	return String(peca.get_meta("tipo", ""))


## Quantas partículas deste tipo ("proton" ou "neutron") estão no núcleo.
func no_nucleo(tipo: String) -> int:
	var conta := 0
	for peca in _nucleo:
		if peca != null and _tipo(peca) == tipo:
			conta += 1
	return conta


## Todas as que estão no átomo, na ordem em que são desenhadas.
func _no_atomo() -> Array[TextureRect]:
	var todas: Array[TextureRect] = []
	for peca in _nucleo:
		if peca != null:
			todas.append(peca)
	todas.append_array(_camada_k)
	todas.append_array(_camada_l)
	return todas


## Uma partícula nova, igual à do seletor e em cima dela.
func _nova_peca(qual: String) -> TextureRect:
	var icone: TextureRect = seletores[qual].icone
	var peca := TextureRect.new()
	peca.texture = icone.texture
	peca.expand_mode = icone.expand_mode
	peca.stretch_mode = icone.stretch_mode
	peca.mouse_filter = Control.MOUSE_FILTER_IGNORE
	peca.size = icone.size
	peca.set_meta("tipo", SELETORES[qual]["tipo"])
	particulas.add_child(peca)
	peca.position = _lugar_no_seletor(qual)
	return peca


## Na primeira vaga livre do núcleo: ele enche do meio para fora.
func _por_no_nucleo(peca: TextureRect) -> void:
	var vaga := _nucleo.find(null)
	_nucleo[vaga] = peca
	# As de fora por cima das de dentro, sempre na mesma ordem.
	var ordem := 0
	for outra in _nucleo:
		if outra != null:
			particulas.move_child(outra, ordem)
			ordem += 1
	var tween := _tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(peca, "position", _lugar_da_vaga(vaga, peca), DURACAO_DA_IDA)
	peca.set_meta("indo", tween)


## Na camada, o elétron entra na roda e gira com os outros (ver _girar). Ele
## entra entre os dois vizinhos do lado por onde chega: ninguém passa por cima
## de ninguém para abrir o lugar dele.
func _por_na_camada(peca: TextureRect, camada: Array[TextureRect], fase: float) -> void:
	var do_meio := peca.position + peca.size * 0.5 - _centro()
	peca.set_meta("onde", Vector2(do_meio.angle(), do_meio.length()))
	camada.append(peca)
	camada.sort_custom(func(a: TextureRect, b: TextureRect) -> bool:
		return fposmod(a.get_meta("onde").x - fase, TAU) < fposmod(b.get_meta("onde").x - fase, TAU))


## Os elétrons da camada, espalhados por igual e girando. Cada um persegue o
## lugar dele em volta do núcleo (o "onde" de cada um é o ângulo e a distância
## do meio em que ele está): quem acabou de chegar, ou perdeu o vizinho,
## desliza até lá sem cortar caminho por dentro do átomo.
func _girar(camada: Array[TextureRect], raio: float, fase: float, delta: float) -> void:
	var centro := _centro()
	var peso := 1.0 - exp(-PRESSA_DO_ELETRON * delta)
	for i in camada.size():
		var peca := camada[i]
		var onde: Vector2 = peca.get_meta("onde")
		onde.x = lerp_angle(onde.x, fase + i * TAU / camada.size(), peso)
		onde.y = lerpf(onde.y, raio, peso)
		peca.set_meta("onde", onde)
		peca.position = centro + Vector2.from_angle(onde.x) * onde.y - peca.size * 0.5


## A partícula que a seta de baixo tira: do núcleo, a de fora (a última vaga
## ocupada por uma do tipo); da camada, o elétron mais perto do seletor.
func _a_que_sai(qual: String) -> TextureRect:
	if qual == "camada_k" or qual == "camada_l":
		var camada := _camada_k if qual == "camada_k" else _camada_l
		var destino := _lugar_no_seletor(qual)
		var mais_perto: TextureRect = null
		for peca in camada:
			if mais_perto == null \
					or peca.position.distance_squared_to(destino) < mais_perto.position.distance_squared_to(destino):
				mais_perto = peca
		return mais_perto
	for i in range(_nucleo.size() - 1, -1, -1):
		if _nucleo[i] != null and _tipo(_nucleo[i]) == SELETORES[qual]["tipo"]:
			return _nucleo[i]
	return null


func _tirar_do_atomo(peca: TextureRect) -> void:
	# Tirada ainda a caminho da vaga: ela para de ir para lá.
	if peca.has_meta("indo"):
		var indo: Tween = peca.get_meta("indo")
		if indo.is_valid():
			indo.kill()
	var vaga := _nucleo.find(peca)
	if vaga >= 0:
		_nucleo[vaga] = null
	_camada_k.erase(peca)
	_camada_l.erase(peca)


## Tira da tela as partículas que estavam voltando para o seletor.
func _limpar_soltas() -> void:
	var ficam := _no_atomo()
	for peca in particulas.get_children():
		if not peca in ficam:
			peca.queue_free()


func _esvaziar() -> void:
	_nucleo.fill(null)
	_camada_k.clear()
	_camada_l.clear()
	for peca in particulas.get_children():
		peca.queue_free()


# ------------------------- CONFERIR -------------------------

func montado() -> bool:
	for qual: String in SELETORES:
		if quantas(qual) != SELETORES[qual]["pedido"]:
			return false
	return true


func _atualizar_contagem() -> void:
	for qual: String in seletores:
		var agora := quantas(qual)
		var pedido: int = SELETORES[qual]["pedido"]
		var conta := _conta(qual)
		conta.text = str(agora)
		var cor := COR_AMARELO
		if agora == pedido:
			cor = COR_CERTO
		elif agora > pedido:
			cor = COR_ERRO
		conta.add_theme_color_override("font_color", cor)


func _concluir() -> void:
	travado = true
	var sessao := _sessao
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	audio_sucesso.play()
	led.color = COR_LED_MONTADO
	_definir_rodape(TXT_MONTADO, false)
	rodape.add_theme_color_override("font_color", COR_CERTO)
	atomo.queue_redraw()

	# O átomo fica um instante girando inteiro antes de a tela trocar.
	await get_tree().create_timer(1.6).timeout
	if sessao != _sessao:
		return
	_mostrar_liberado()


# ------------------------- BUMERANGUE LIBERADO -------------------------

## Tela final: só "BUMERANGUE LIBERADO!" e a foto do bumerangue, parada. O
## rodapé diz como abrir o domo.
func _mostrar_liberado() -> void:
	var sessao := _sessao
	var sai := _tween()
	sai.tween_property(grupo_atomo, "modulate:a", 0.0, 0.3)
	await sai.finished
	if sessao != _sessao:
		return
	grupo_atomo.hide()

	grupo_liberado.show()
	grupo_liberado.modulate.a = 0.0
	led.color = COR_LED_LIBERADO
	var entra := _tween()
	entra.tween_property(grupo_liberado, "modulate:a", 1.0, 0.3)
	_definir_rodape(Controle.texto(TXT_ABRIR_DOMO, true), true)
	aguardando_fechamento = true


# ------------------------- O DESENHO DO ÁTOMO -------------------------

## O núcleo tracejado e as duas camadas, no meio do nó Atomo.
func _desenhar_atomo() -> void:
	var meio := atomo.size * 0.5
	var cor_nucleo := COR_CERTO if travado else Color(COR_AMARELO, 0.6)
	var tracos := 24
	for i in tracos:
		var de := TAU * i / tracos
		atomo.draw_arc(meio, RAIO_NUCLEO, de, de + TAU / tracos * 0.55, 6, cor_nucleo, 2.0)
	if _nucleo.all(func(p: TextureRect) -> bool: return p == null):
		_escrever_no_meio(meio, "NÚCLEO", 11, Color(COR_AMARELO, 0.8))

	var cor_camada := COR_CERTO if travado else COR_ANEL
	for camada: Array in [[RAIO_K, "K"], [RAIO_L, "L"]]:
		atomo.draw_arc(meio, camada[0], 0.0, TAU, 96, cor_camada, 2.0)
		# A letra da camada, por fora dela, em cima e à direita.
		_escrever_no_meio(meio + Vector2.from_angle(-PI * 0.25) * (camada[0] + 13.0), camada[1], 15,
			cor_camada)


func _escrever_no_meio(ponto: Vector2, texto: String, tamanho: int, cor: Color) -> void:
	var medida := FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho)
	var sobe := FONTE.get_ascent(tamanho)
	var desce := FONTE.get_descent(tamanho)
	atomo.draw_string(FONTE, (ponto + Vector2(-medida.x * 0.5, (sobe - desce) * 0.5)).round(), texto,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)


# ------------------------- RODAPÉ -------------------------

func _definir_rodape(texto: String, com_cursor: bool) -> void:
	_rodape_texto = texto
	_rodape_padrao = texto
	_rodape_cursor = com_cursor
	rodape.remove_theme_color_override("font_color")


## Mensagem no rodapé; depois de "duracao" volta ao texto de sempre.
func _mostrar_aviso(texto: String, cor: Color, duracao: float = 3.2) -> void:
	var sessao := _sessao
	_rodape_texto = texto
	_rodape_cursor = false
	rodape.add_theme_color_override("font_color", cor)
	await get_tree().create_timer(duracao).timeout
	if sessao != _sessao or _rodape_texto != texto or travado:
		return
	_voltar_rodape()


func _voltar_rodape() -> void:
	if travado or _rodape_texto == _rodape_padrao:
		return
	_rodape_texto = _rodape_padrao
	_rodape_cursor = true
	rodape.remove_theme_color_override("font_color")


# ------------------------- APOIO -------------------------

func _tween() -> Tween:
	var tween := create_tween()
	_tweens.append(tween)
	if _tweens.size() > 48:
		_tweens = _tweens.filter(func(t): return is_instance_valid(t) and t.is_valid())
	return tween


func _matar_tweens() -> void:
	for tween in _tweens:
		if is_instance_valid(tween) and tween.is_valid():
			tween.kill()
	_tweens.clear()


## Não cabe, ou a conta passou: o número treme e o terminal diz por quê.
func _errar(texto: String, conta: Label) -> void:
	audio_erro.play()
	_mostrar_aviso(texto, COR_ERRO)
	var origem: Vector2 = conta.get_meta("pos_base", conta.position)
	var tween := _tween()
	tween.set_trans(Tween.TRANS_SINE)
	for desvio: float in [6.0, -6.0, 5.0, -5.0, 0.0]:
		tween.tween_property(conta, "position", origem + Vector2(desvio, 0.0), 0.045)


## A conta bateu: o número dá um pulo.
func _celebrar(conta: Label) -> void:
	conta.pivot_offset = conta.size * 0.5
	var tween := _tween()
	tween.tween_property(conta, "scale", Vector2(1.35, 1.35), 0.09) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(conta, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
