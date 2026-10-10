class_name ExplicacaoDestilador
extends CanvasLayer

# --- A EXPLICAÇÃO DA COLUNA DE DESTILAÇÃO (fase do nitrogênio) ---
#
# A Cacau aperta E na coluna de destilação do mapa (scripts/fases/destilador.gd)
# e o Dr. Chico explica, pelo rádio, como ela separa o ar. É uma tela de
# DESENHO, com quase nada escrito: a fala dele é a única frase de cada vez, e o
# que ensina é o que se mexe.
#
#   à esquerda   a coluna, grande, em raio X (scripts/ui/coluna_destilacao.gd),
#                com a régua de temperatura colada nela: menos fria embaixo,
#                onde o líquido ganha calor do ambiente, e mais fria em cima,
#                onde fica o resfriador. Lá dentro o ar líquido ferve aos poucos e cada
#                substância para no andar que está no ponto de ebulição dela.
#   no meio      a legenda: uma ficha para cada substância do ar (N₂, Ar e
#                O₂), na ordem dos andares da coluna, cada uma com o seu ponto
#                de ebulição. Elas não saem do lugar.
#   à direita    o Dr. Chico e a caixa de fala, do jeito de sempre (Dialogic).
#
# A CONVERSA MANDA NO DESENHO. A timeline (timelines/cientista_destilador.dtl)
# tem um [signal arg="..."] antes de cada fala, e é ele que faz o desenho andar.
# Cada marca é UMA coisa acontecendo:
#
#   raio_x      a coluna de aço vira o desenho preto
#   ar          o ar líquido (-200 °C) enche o fundo; as três fichas aparecem
#   ebulicao    cada ficha mostra o ponto de ebulição da substância
#   ferver      o líquido vai ganhando calor do ambiente e fica menos frio:
#               passando de -196 °C o nitrogênio ferve, vira gás e sobe
#   esfriar     um sopro de geada no resfriador; no topo (-196 °C) o
#               nitrogênio vira líquido de novo
#   separar     o fundo chega a -183 °C: o argônio ferve e para
#               um andar acima; o oxigênio fica no fundo
#   fim         o título vira "DESTILAÇÃO FRACIONADA"
#
# Pode reescrever as falas à vontade no editor do Dialogic, tirar e juntar
# falas: cada marca só precisa continuar antes da fala que a comenta. Marca que
# faltar é feita junto com a seguinte. Se a pessoa passar as falas depressa, o
# desenho corre para alcançar. Sem timeline nenhuma (campo vazio, ou arquivo
# que não abriu) a tela passa o desenho sozinha, sem fala.
#
# A tela para o jogo enquanto está aberta. ESC (△ no controle) fecha a
# qualquer momento; acabando a conversa, ela fecha sozinha — o desenho se
# desfaz enquanto o retrato do Dr. Chico se despede (a saída de toda conversa
# do Dialogic leva uns 2 s), e o jogo volta quando os dois acabam. Abrir de
# novo recomeça do zero.
#
# COMO EDITAR NO EDITOR (scenes/explicacao_destilador.tscn):
#   Raiz/Coluna    onde a coluna fica. O tamanho é o da arte × 4; à esquerda
#                  dela vão a régua e as plaquinhas (uns 170 px).
#   Raiz/Fichas/*  as três fichas da legenda: posição, nome e porcentagem.
#   Raiz/Veu       a cor e a força do escuro por cima do jogo.
#   Raiz/Sair      o aviso do canto.
#   SomRadio       o chiado de abrir e fechar o canal do rádio (o mesmo do
#                  rádio da fase 1); SomPop, o estalo de cada substância que
#                  ferve e que vira líquido. O volume de cada um é no nó.
#   timeline, deslocamento_da_fala   no Inspector do nó raiz.

## O desenho acabou de pousar de volta em cima da coluna do mapa: é a hora de
## a coluna de lá reaparecer (o jogo ainda não voltou a andar).
signal pousou
## A tela acabou de sair (o jogo já voltou a andar).
signal fechou
## Uma marca da conversa chegou (ver a lista no topo do arquivo).
signal marco(nome: String)

## A conversa do Dr. Chico. Vazio = só o desenho, sem fala.
@export var timeline: String = "cientista_destilador"
## Quanto a caixa de fala anda para a direita, para não cobrir o pé da coluna.
@export var deslocamento_da_fala: float = 110.0

## As marcas da conversa, na ordem em que o desenho acontece.
const MARCOS: Array[String] = ["raio_x", "ar", "ebulicao", "ferver", "esfriar", "separar", "fim"]
## Sem conversa, a hora (em segundos) em que cada marca acontece.
const HORA_SEM_FALA := {"raio_x": 0.0, "ar": 1.6, "ebulicao": 4.6, "ferver": 7.2,
	"esfriar": 13.5, "separar": 21.0, "fim": 26.5}

const TITULO := "COLUNA DE DESTILAÇÃO"
const TITULO_FINAL := "DESTILAÇÃO FRACIONADA"
## Em duas linhas, para caber em cima da plaquinha.
const LEGENDA_DA_EBULICAO := "PONTO DE\nEBULIÇÃO"

const DURACAO_DA_CHEGADA := 0.5
const DURACAO_DA_VOLTA := 0.4

var _aberta: bool = false
var _fechando: bool = false
# Cada abertura é uma sessão: corrotina que acorda em outra sessão desiste.
var _sessao: int = 0
var _tweens: Array[Tween] = []
## Onde a coluna do mapa está na tela (é de lá que o desenho sai e para lá que volta).
var _origem := Rect2()
var _lugar_da_coluna := Vector2.ZERO
var _forca_do_veu: float = 0.95
## Onde cada ficha fica (substância -> posição).
var _lugares: Dictionary = {}
var _ultimo_marco: int = -1
var _titulo: String = TITULO
var _titulo_a_vista: float = 0.0
var _pulo_do_titulo: float = 0.0
var _legenda_a_vista: float = 0.0
## O sopro de geada foi pedido com a coluna ainda sem o resfriador ligado
## (falas passadas depressa): sai quando ele ligar.
var _sopro_pendente: bool = false
## Quantos estalos já tocaram nesta abertura (cada um um pouco mais agudo).
var _estalos: int = 0
## Sem conversa: o desenho já passou inteiro e o E fecha.
var _esperando_fechar: bool = false
## A timeline que está no ar (null sem conversa): quando o Dialogic troca
## dela para a despedida, ou a encerra, a tela começa a fechar.
var _conversa: Resource = null

@onready var _veu: ColorRect = $Raiz/Veu
@onready var _desenho: Control = $Raiz/Desenho
@onready var _coluna: ColunaDestilacao = $Raiz/Coluna
@onready var _fichas: Control = $Raiz/Fichas
@onready var _sair: Label = $Raiz/Sair
@onready var _som: AudioStreamPlayer = get_node_or_null("SomPop")
@onready var _som_radio: AudioStreamPlayer = get_node_or_null("SomRadio")


func _ready() -> void:
	hide()
	set_process(false)
	_lugar_da_coluna = _coluna.position
	_forca_do_veu = _veu.color.a
	for ficha in _todas_as_fichas():
		_lugares[ficha.substancia] = ficha.position
	_desenho.draw.connect(_desenhar)
	_coluna.ferveu.connect(_ao_ferver)
	_coluna.assentou.connect(_ao_assentar)
	# A tecla do aviso sai desenhada (ESC, ou △ de controle na mão).
	Controle.rotular(_sair, _sair.text, 2.0)


# ─────────────────────────────────────────────────────────────
# ABRIR E FECHAR
# ─────────────────────────────────────────────────────────────

## Abre a explicação. "origem" é onde a coluna do mapa aparece na tela: o
## desenho sai de cima dela. Sem origem, ele só clareia no lugar.
func abrir(origem: Rect2 = Rect2()) -> void:
	if _aberta:
		return
	_aberta = true
	_fechando = false
	_sessao += 1
	var sessao := _sessao
	_origem = origem
	_arrumar_o_palco()
	show()
	set_process(true)
	Interacao.marcar_tela_aberta(self, true)
	_parar_o_jogo(true)

	var chegada := _tween()
	chegada.set_parallel(true)
	chegada.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	chegada.tween_property(_coluna, "position", _lugar_da_coluna, DURACAO_DA_CHEGADA)
	chegada.tween_property(_coluna, "scale", Vector2.ONE, DURACAO_DA_CHEGADA)
	chegada.tween_property(_coluna, "modulate", Color.WHITE, DURACAO_DA_CHEGADA)
	chegada.tween_property(_veu, "color:a", _forca_do_veu, DURACAO_DA_CHEGADA)
	chegada.tween_property(_sair, "modulate:a", 1.0, DURACAO_DA_CHEGADA)
	await chegada.finished
	if sessao != _sessao:
		return
	_comecar_a_conversa()


## Fecha a explicação no meio (o ESC): corta a conversa e desfaz o desenho.
func fechar() -> void:
	_fechar(true)


## Some o que tem dentro da coluna, o aço volta e o desenho pousa de novo em
## cima da coluna do mapa. A conversa é cortada na hora, ou — quando foi ela
## que acabou — termina de se despedir por conta própria.
func _fechar(cortar_a_conversa: bool) -> void:
	if not _aberta or _fechando:
		return
	_fechando = true
	_sessao += 1
	var sessao := _sessao
	if _conversa != null:
		# O "tchk" de fechar o canal: o mesmo chiado, mais grave.
		_chiar(0.8)
	_largar_a_conversa(cortar_a_conversa)
	_matar_tweens()
	_coluna.ritmo = 1.0
	_coluna.fechar()

	var some := _tween()
	some.set_parallel(true)
	for ficha in _todas_as_fichas():
		some.tween_property(ficha, "modulate:a", 0.0, 0.2)
	some.tween_property(self, "_titulo_a_vista", 0.0, 0.2)
	some.tween_property(self, "_legenda_a_vista", 0.0, 0.2)
	some.tween_property(_sair, "modulate:a", 0.0, 0.2)

	while not _coluna.esta_fechada():
		await get_tree().process_frame
		if sessao != _sessao:
			return

	var volta := _tween()
	volta.set_parallel(true)
	volta.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if _origem.has_area():
		volta.tween_property(_coluna, "position", _origem.position, DURACAO_DA_VOLTA)
		volta.tween_property(_coluna, "scale", _origem.size / _coluna.tamanho_da_coluna(), DURACAO_DA_VOLTA)
		volta.tween_property(_coluna, "modulate", _cor_do_mundo(), DURACAO_DA_VOLTA)
	else:
		volta.tween_property(_coluna, "modulate:a", 0.0, DURACAO_DA_VOLTA)
	volta.tween_property(_veu, "color:a", 0.0, DURACAO_DA_VOLTA)
	await volta.finished
	if sessao != _sessao:
		return
	# Pousou: a coluna do mapa assume o lugar. A daqui ficaria por cima da
	# Cacau, que está na frente da de lá.
	_coluna.visible = false
	pousou.emit()
	# Conversa cortada logo ao abrir pode ter começado só depois do corte.
	if cortar_a_conversa and Dialogic.current_timeline != null:
		Dialogic.end_timeline(true)
	# O retrato do Dr. Chico ainda pode estar saindo: o jogo só volta depois.
	while Dialogic.current_timeline != null:
		await get_tree().process_frame
		if sessao != _sessao:
			return

	hide()
	set_process(false)
	_aberta = false
	_fechando = false
	Interacao.marcar_tela_aberta(self, false)
	_parar_o_jogo(false)
	fechou.emit()


func esta_aberta() -> bool:
	return _aberta


## A coluna desenhada (para os testes olharem lá dentro).
func coluna() -> ColunaDestilacao:
	return _coluna


## A ficha de uma substância ("N2", "O2", "Ar"), ou null.
func ficha_de(substancia: String) -> FichaSubstancia:
	for ficha in _todas_as_fichas():
		if ficha.substancia == substancia:
			return ficha
	return null


## A última marca da conversa que o desenho já fez ("" antes da primeira).
func marco_atual() -> String:
	return MARCOS[_ultimo_marco] if _ultimo_marco >= 0 else ""


func titulo() -> String:
	return _titulo


# Tudo de volta ao começo: a coluna de aço em cima da do mapa, sem véu, sem
# fichas, sem título.
func _arrumar_o_palco() -> void:
	_matar_tweens()
	_ultimo_marco = -1
	_esperando_fechar = false
	_sopro_pendente = false
	_estalos = 0
	_conversa = null
	_titulo = TITULO
	_titulo_a_vista = 0.0
	_pulo_do_titulo = 0.0
	_legenda_a_vista = 0.0
	_sair.modulate.a = 0.0
	_veu.color.a = 0.0
	_coluna.reiniciar()
	_coluna.ritmo = 1.0
	_coluna.visible = true
	if _origem.has_area():
		_coluna.position = _origem.position
		_coluna.scale = _origem.size / _coluna.tamanho_da_coluna()
		# No mapa a coluna está na luz da hora (de noite, escura): o desenho
		# começa nessa mesma cor, para não se ver a troca.
		_coluna.modulate = _cor_do_mundo()
	else:
		_coluna.position = _lugar_da_coluna
		_coluna.scale = Vector2.ONE
		_coluna.modulate = Color(1, 1, 1, 0)
	for ficha in _todas_as_fichas():
		ficha.position = _lugares.get(ficha.substancia, ficha.position)
		ficha.modulate.a = 0.0
		ficha.ebulicao_a_vista = 0.0
	_desenho.queue_redraw()


func _parar_o_jogo(sim: bool) -> void:
	get_tree().paused = sim
	var cacau := get_tree().get_first_node_in_group("player")
	if cacau and "pode_se_mover" in cacau:
		cacau.pode_se_mover = not sim


## A luz ambiente da fase (o CanvasModulate da Atmosfera), ou branco.
func _cor_do_mundo() -> Color:
	# A fase é o nó mais alto acima desta tela, logo abaixo da raiz da árvore.
	var fase: Node = self
	while fase.get_parent() != null and fase.get_parent() != get_tree().root:
		fase = fase.get_parent()
	for no in fase.find_children("*", "CanvasModulate", true, false):
		if (no as CanvasModulate).visible:
			return (no as CanvasModulate).color
	return Color.WHITE


# ─────────────────────────────────────────────────────────────
# A CONVERSA
# ─────────────────────────────────────────────────────────────

func _comecar_a_conversa() -> void:
	var sessao := _sessao
	if timeline.is_empty():
		_passar_sem_fala()
		return
	# O jogo está parado: o Dialogic precisa andar mesmo assim.
	Dialogic.process_mode = Node.PROCESS_MODE_ALWAYS
	Dialogic.signal_event.connect(_ao_sinal)
	var palco: Node = Dialogic.start(timeline)
	if palco != null:
		# A caixa de fala e o retrato por cima desta tela.
		palco.set("layer", layer + 10)
		palco.process_mode = Node.PROCESS_MODE_ALWAYS

	# Timeline que não abriu (nome errado, erro no arquivo) não avisa nem
	# termina nunca: o desenho passa sozinho.
	for i in 3:
		await get_tree().process_frame
	if sessao != _sessao:
		return
	if Dialogic.current_timeline == null:
		push_warning("ExplicacaoDestilador: a timeline '%s' não abriu; passando só o desenho." % timeline)
		_largar_a_conversa(true)
		_passar_sem_fala()
		return
	_conversa = Dialogic.current_timeline
	_chiar(1.0)
	_deslocar_a_fala(palco)


## A caixa de fala fica embaixo, no meio — em cima do pé da coluna. Ela anda
## para a direita só nesta tela (o Dialogic monta o palco de novo a cada
## conversa, então não sobra nada para as outras).
func _deslocar_a_fala(palco: Node) -> void:
	if palco == null or not is_instance_valid(palco) or is_zero_approx(deslocamento_da_fala):
		return
	var ancora := palco.find_child("Anchor", true, false) as Control
	if ancora != null:
		ancora.position.x += deslocamento_da_fala


func _chiar(tom: float) -> void:
	if _som_radio != null:
		_som_radio.pitch_scale = tom
		_som_radio.play()


func _ao_sinal(argumento: Variant) -> void:
	if argumento is String:
		_marcar(argumento)


## Para de ouvir a conversa. "cortar" a encerra na hora, sem a despedida.
func _largar_a_conversa(cortar: bool) -> void:
	_conversa = null
	if Dialogic.signal_event.is_connected(_ao_sinal):
		Dialogic.signal_event.disconnect(_ao_sinal)
	if cortar and Dialogic.current_timeline != null:
		Dialogic.end_timeline(true)


## Sem conversa: as marcas acontecem na hora marcada e, no fim, o E fecha.
func _passar_sem_fala() -> void:
	var sessao := _sessao
	var relogio := 0.0
	for nome in MARCOS:
		while relogio < float(HORA_SEM_FALA[nome]):
			await get_tree().process_frame
			if sessao != _sessao:
				return
			relogio += get_process_delta_time()
		_marcar(nome)
	while not _coluna.separado():
		await get_tree().process_frame
		if sessao != _sessao:
			return
	_esperando_fechar = true


# ─────────────────────────────────────────────────────────────
# AS MARCAS (o que cada parte da conversa faz no desenho)
# ─────────────────────────────────────────────────────────────

## Faz a marca e todas as anteriores que ainda não tinham sido feitas.
func _marcar(nome: String) -> void:
	var qual := MARCOS.find(nome)
	if qual < 0 or not _aberta or _fechando:
		return
	for i in range(_ultimo_marco + 1, qual + 1):
		_ultimo_marco = i
		_fazer(MARCOS[i])
		marco.emit(MARCOS[i])


func _fazer(nome: String) -> void:
	match nome:
		"raio_x":
			_coluna.ir_para(ColunaDestilacao.Etapa.RAIO_X)
			_tween().tween_property(self, "_titulo_a_vista", 1.0, 0.3)
		"ar":
			_coluna.ir_para(ColunaDestilacao.Etapa.AR_LIQUIDO)
			_mostrar_as_fichas()
		"ebulicao":
			_mostrar_os_pontos_de_ebulicao()
		"ferver":
			_coluna.ir_para(ColunaDestilacao.Etapa.FERVER)
		"esfriar":
			_sopro_pendente = true
		"separar":
			_coluna.ir_para(ColunaDestilacao.Etapa.SEPARAR)
		"fim":
			_titulo = TITULO_FINAL
			_pulo_do_titulo = 1.0
			_tween().tween_property(self, "_pulo_do_titulo", 0.0, 0.45)


func _process(_delta: float) -> void:
	_desenho.queue_redraw()
	if _fechando:
		return
	# A última fala foi passada: o Dialogic trocou a conversa pela despedida
	# dele (ou já encerrou). O desenho começa a se desfazer junto.
	if _conversa != null and Dialogic.current_timeline != _conversa:
		_fechar(false)
		return
	if _sopro_pendente and _coluna.etapa_atual() >= ColunaDestilacao.Etapa.FERVER:
		_sopro_pendente = false
		_coluna.soprar_frio()
	# Se a pessoa passou as falas depressa, o desenho corre para alcançar o
	# que a fala da vez está dizendo.
	var pressa := 1.0
	match marco_atual():
		"esfriar":
			# A fala é sobre o gás virando líquido no topo: ele tem de chegar lá.
			if not _alguma_assentou():
				pressa = 3.0
		"fim":
			if not _coluna.separado():
				pressa = 3.0
	_coluna.ritmo = pressa


func _input(event: InputEvent) -> void:
	if not _aberta or _fechando:
		return
	if event.is_action_pressed("fechar") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		fechar()
	elif _esperando_fechar and (event.is_action_pressed(Interacao.ACAO) or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		Interacao.consumir()
		fechar()


func _alguma_assentou() -> bool:
	for ficha in _todas_as_fichas():
		if _coluna.ja_assentou(ficha.substancia):
			return true
	return false


# ─────────────────────────────────────────────────────────────
# AS FICHAS
# ─────────────────────────────────────────────────────────────

func _todas_as_fichas() -> Array[FichaSubstancia]:
	var saida: Array[FichaSubstancia] = []
	for no in _fichas.get_children():
		if no is FichaSubstancia:
			saida.append(no)
	return saida


## As três aparecem uma depois da outra, subindo um pouco.
func _mostrar_as_fichas() -> void:
	var fichas := _todas_as_fichas()
	for i in fichas.size():
		var ficha := fichas[i]
		var lugar: Vector2 = _lugares[ficha.substancia]
		ficha.position = lugar + Vector2(0.0, 16.0)
		var entra := _tween()
		entra.set_parallel(true)
		entra.tween_property(ficha, "modulate:a", 1.0, 0.2).set_delay(i * 0.14)
		entra.tween_property(ficha, "position", lugar, 0.3).set_delay(i * 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## De cima para baixo, cada ficha mostra a plaquinha do ponto de ebulição; a
## legenda aparece em cima da primeira.
func _mostrar_os_pontos_de_ebulicao() -> void:
	var fichas := _todas_as_fichas()
	for i in fichas.size():
		_tween().tween_property(fichas[i], "ebulicao_a_vista", 1.0, 0.3).set_delay(i * 0.22)
	_tween().tween_property(self, "_legenda_a_vista", 1.0, 0.3)


## O fundo da coluna passou do ponto de ebulição da substância: a plaquinha da
## ficha dela dá um pulo, com um estalo.
func _ao_ferver(substancia: String) -> void:
	if not _aberta or _fechando:
		return
	var ficha := ficha_de(substancia)
	if ficha != null:
		ficha.pulsar()
	_estalar()


## A substância chegou no andar dela: outro estalo (a plaquinha do andar, na
## coluna, toma a cor dela).
func _ao_assentar(_substancia: String) -> void:
	if not _aberta or _fechando:
		return
	_estalar()


func _estalar() -> void:
	if _som != null:
		_som.pitch_scale = 1.0 + 0.08 * _estalos
		_som.play()
	_estalos += 1


# ─────────────────────────────────────────────────────────────
# O DESENHO EM VOLTA (título e legenda)
# ─────────────────────────────────────────────────────────────

func _desenhar() -> void:
	# O título, em cima da coluna.
	if _titulo_a_vista > 0.004:
		var meio := _lugar_da_coluna.x + _coluna.tamanho_da_coluna().x * 0.5
		var largura := ColunaDestilacao.retangulo_da_plaquinha(Vector2.ZERO, _titulo).size.x
		ColunaDestilacao.plaquinha(_desenho,
			Vector2(roundf(meio + largura * 0.5), roundf(_lugar_da_coluna.y - 30.0)),
			_titulo, EstiloHUD.PAPEL, _titulo_a_vista, sin(_pulo_do_titulo * PI) * 6.0)

	# "PONTO DE EBULIÇÃO", uma vez só, em cima da plaquinha da ficha mais alta.
	if _legenda_a_vista > 0.004:
		var topo := Rect2()
		for ficha in _todas_as_fichas():
			var caixa := ficha.retangulo_da_plaquinha()
			caixa.position += ficha.position
			if not topo.has_area() or caixa.position.y < topo.position.y:
				topo = caixa
		if topo.has_area():
			ColunaDestilacao.legenda(_desenho, Vector2(topo.get_center().x, topo.position.y),
				LEGENDA_DA_EBULICAO, _legenda_a_vista)


# ─────────────────────────────────────────────────────────────
# APOIO
# ─────────────────────────────────────────────────────────────

func _tween() -> Tween:
	var tween := create_tween()
	_tweens.append(tween)
	if _tweens.size() > 48:
		_tweens = _tweens.filter(func(t: Tween) -> bool: return is_instance_valid(t) and t.is_valid())
	return tween


func _matar_tweens() -> void:
	for tween in _tweens:
		if is_instance_valid(tween) and tween.is_valid():
			tween.kill()
	_tweens.clear()
