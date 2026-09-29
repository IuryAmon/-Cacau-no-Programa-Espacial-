extends CanvasLayer

# --- AUTOLOAD "Caderno" ---
#
# O caderno de anotações da Cacau. Ela o tem desde o começo do jogo: o ícone
# fica no canto inferior esquerdo e M (△ no controle) abre e fecha.
# Três peças, como a lista de objetivos:
#
#   PaginasCaderno (scripts/paginas_caderno.gd)   O QUE está escrito
#   este autoload                                  QUANDO: o ícone aparece, o
#                                                  caderno abre, pausa e fecha
#   CadernoLivro (scripts/ui/caderno_livro.gd)     COMO: a arte e as folhas
#                                                  virando
#
# Aberto, o mundo pausa (como na ficha de coleta) e o caderno segura as teclas
# (Interacao.marcar_tela_aberta): o espaço ou o ○ apertados em cima dele não
# viram pulo nem dash quando ele fecha. Ele abre saindo do ícone e fecha
# voltando para dentro dele, e lembra a página em que ficou.
#
# COM O CADERNO ABERTO
#   A/D, ←/→, direcional, analógico   folheia (segurando, continua folheando)
#   clique na face direita/esquerda   folheia; a roda do mouse também
#   M, ESC, △, ○                      fecha; clicar fora do caderno também
#
# O ícone some junto com a lista de objetivos (fala, ficha de coleta, puzzle,
# pausa, cenas sem a Cacau), e o caderno só abre com o ícone na tela.

signal aberto_mudou(aberto: bool)

const ACAO := &"caderno"
const SOM_ABRIR := preload("res://sounds/caderno_abrir.wav")
const SOM_FECHAR := preload("res://sounds/caderno_fechar.wav")
const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

## O caderno aberto fica acima de tudo do jogo: puzzles (10-15), Dialogic (20),
## cinto (90) e mochila (95). O ícone mora na camada do autoload, a mesma da
## lista de objetivos (abaixo dos puzzles).
const CAMADA_ICONE := 4
const CAMADA_ABERTO := 100

const DURACAO_ABRIR := 0.34
const DURACAO_FECHAR := 0.22
## O ícone aparece e some neste tempo (quando uma fala abre, por exemplo).
const DURACAO_ICONE := 0.2
## Quanto o caderno passa do tamanho ao abrir, antes de assentar.
const EXAGERO_ABRIR := 1.4
const VEU := Color(0.035, 0.025, 0.03, 0.66)

# --- Rodapé (os comandos, no pé da tela) ---
const ALTURA_RODAPE := 64.0
const ALTURA_BARRA := 46.0
const TAM_DICA := 13
const ESPACO_DICA := 1.6
const ESCALA_BOTAO := 2.0

var _icone: CadernoIcone = null
var _camada: CanvasLayer = null
var _tela: Control = null
var _veu: ColorRect = null
var _livro: CadernoLivro = null
var _rodape: Control = null
var _som: AudioStreamPlayer = null

var _aberto: bool = false
## 0 = fechado dentro do ícone, 1 = aberto no meio da tela.
var _abertura: float = 0.0
var _alfa_icone: float = 0.0
## Foi o caderno que pausou o jogo (e é ele quem despausa).
var _pausou: bool = false


func _ready() -> void:
	layer = CAMADA_ICONE
	process_mode = Node.PROCESS_MODE_ALWAYS

	_icone = CadernoIcone.new()
	_icone.name = "Icone"
	add_child(_icone)

	_camada = CanvasLayer.new()
	_camada.name = "Aberto"
	_camada.layer = CAMADA_ABERTO
	add_child(_camada)

	_tela = Control.new()
	_tela.name = "Tela"
	_tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tela.mouse_filter = Control.MOUSE_FILTER_STOP
	_tela.visible = false
	_tela.gui_input.connect(_ao_clicar_fora)
	_camada.add_child(_tela)

	_veu = ColorRect.new()
	_veu.name = "Veu"
	_veu.color = VEU
	_veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.add_child(_veu)

	_livro = CadernoLivro.new()
	_livro.name = "Livro"
	_livro.pivot_offset = CadernoLivro.CAIXA_DESENHO.get_center()
	_livro.fora_clicado.connect(fechar)
	_tela.add_child(_livro)

	_rodape = Control.new()
	_rodape.name = "Rodape"
	_rodape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rodape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rodape.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rodape.draw.connect(_desenhar_rodape)
	_tela.add_child(_rodape)

	_som = AudioStreamPlayer.new()
	_som.name = "Som"
	add_child(_som)


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

func aberto() -> bool:
	return _aberto


func livro() -> CadernoLivro:
	return _livro


## Dá para abrir agora? Só com o ícone na tela e a camada do autoload visível
## (a cortina das portas a apaga no meio da troca de cena).
func pode_abrir() -> bool:
	return not _aberto and _pode_aparecer() and visible and _alfa_icone >= 1.0


func abrir() -> void:
	if not pode_abrir():
		return
	_aberto = true
	_tela.visible = true
	Interacao.marcar_tela_aberta(_tela, true)
	if not get_tree().paused:
		get_tree().paused = true
		_pausou = true
	_tocar(SOM_ABRIR)
	aberto_mudou.emit(true)


## O jogo volta quando o caderno termina de voltar para o ícone (_process).
func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	_tocar(SOM_FECHAR)
	aberto_mudou.emit(false)


# ─────────────────────────────────────────────────────────────
# A CADA QUADRO
# ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Fala ou ficha de coleta por cima, ou a Cacau saiu de cena: o caderno fecha
	# sozinho para não esconder nada.
	if _aberto and (Dialogic.current_timeline != null or Inventario.popup_aberto \
			or not _pode_aparecer()):
		fechar()

	if _aberto and _abertura >= 0.5:
		var passo := Controle.passo_navegacao()
		if passo.x > 0:
			_livro.proxima()
		elif passo.x < 0:
			_livro.anterior()

	var duracao := DURACAO_ABRIR if _aberto else DURACAO_FECHAR
	_abertura = move_toward(_abertura, 1.0 if _aberto else 0.0, delta / duracao)
	if _tela.visible:
		_posicionar()
		_rodape.queue_redraw()
	if not _aberto and _abertura <= 0.0 and _tela.visible:
		_terminar_de_fechar()

	var alvo_icone := 1.0 if _pode_aparecer() else 0.0
	_alfa_icone = move_toward(_alfa_icone, alvo_icone, delta / DURACAO_ICONE)
	# O caderno sai do ícone: o ícone some enquanto ele está fora.
	_icone.alfa = _alfa_icone * (1.0 - _abertura)


func _terminar_de_fechar() -> void:
	_tela.visible = false
	Interacao.marcar_tela_aberta(_tela, false)
	if _pausou and not Inventario.popup_aberto:
		get_tree().paused = false
	_pausou = false


## Mesmas regras da lista de objetivos (Objetivos._pode_aparecer). Com o
## caderno na tela (aberto ou voltando para o ícone) a pausa e a tela ocupada
## são dele mesmo, e não contam.
func _pode_aparecer() -> bool:
	var cena := get_tree().current_scene
	if cena == null or cena.scene_file_path in Objetivos.CENAS_SEM_OBJETIVOS:
		return false
	if get_tree().get_first_node_in_group("player") == null:
		return false
	if _aberto or _tela.visible:
		return true
	if get_tree().paused or Interacao.ocupada():
		return false
	return true


## O caderno sai do ícone crescendo e vai para o meio da tela (acima do
## rodapé); fechando, faz o caminho de volta. A curva é a mesma nos dois
## sentidos — rápida perto do ícone, mansa perto do meio —, e só a abertura
## passa um pouco do tamanho antes de assentar.
func _posicionar() -> void:
	var t := _abertura
	var caminho := 1.0 - pow(1.0 - t, 3.0)
	var crescimento := _passar_e_voltar(t) if _aberto else caminho
	var tela := _tela.size
	var destino := Vector2(tela.x * 0.5, (tela.y - ALTURA_RODAPE) * 0.5).round()
	var origem := _icone.centro_do_caderno()
	var escala_minima := _icone.size.y / CadernoLivro.CAIXA_DESENHO.size.y
	var escala := lerpf(escala_minima, 1.0, crescimento)
	_livro.scale = Vector2(escala, escala)
	_livro.position = origem.lerp(destino, caminho) - _livro.pivot_offset
	if t >= 1.0:
		_livro.position = _livro.position.round()
	_livro.modulate.a = clampf(t * 4.0, 0.0, 1.0)
	_veu.color = Color(VEU.r, VEU.g, VEU.b, VEU.a * t)


## Curva que passa de 1 e volta (o "back" das animações).
func _passar_e_voltar(t: float) -> float:
	var c := EXAGERO_ABRIR
	return 1.0 + (c + 1.0) * pow(t - 1.0, 3.0) + c * pow(t - 1.0, 2.0)


# ─────────────────────────────────────────────────────────────
# ENTRADA
# ─────────────────────────────────────────────────────────────

func _input(evento: InputEvent) -> void:
	if not _aberto:
		if evento.is_action_pressed(ACAO) and pode_abrir():
			get_viewport().set_input_as_handled()
			abrir()
		return

	# O mouse segue para a interface: é do CadernoLivro e da tela (_gui_input),
	# que cobrem a tela inteira e não o deixam passar para o jogo.
	if evento is InputEventMouse:
		return
	# Aberto, nenhuma tecla passa para o jogo parado atrás dele.
	get_viewport().set_input_as_handled()
	if evento.is_action_pressed(ACAO) or evento.is_action_pressed(&"fechar") \
			or evento.is_action_pressed(&"ui_cancel"):
		fechar()
		return
	# Direcional e analógico são lidos no _process, com a repetição do Controle.
	if evento is InputEventJoypadButton or evento is InputEventJoypadMotion:
		return
	# Tecla segurada repete (echo): continua folheando.
	if evento.is_action_pressed(&"ui_right", true):
		_livro.proxima()
	elif evento.is_action_pressed(&"ui_left", true):
		_livro.anterior()


func _ao_clicar_fora(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed \
			and evento.button_index == MOUSE_BUTTON_LEFT:
		fechar()


func _tocar(som: AudioStream) -> void:
	_som.stream = som
	_som.play()


# ─────────────────────────────────────────────────────────────
# RODAPÉ
# ─────────────────────────────────────────────────────────────

## [botões, texto]. No teclado, as teclas desenhadas; no controle, os botões.
## Sem contador de página: o número já está no canto de cada página.
func _dicas() -> Array:
	if BotoesControle.controle_em_uso():
		var fechar_com := BotoesControle.nome_da_acao(ACAO)
		return [[["direcional_horizontal"], "FOLHEAR"],
			[[fechar_com if fechar_com != "" else "triangulo"], "FECHAR"]]
	return [[["tecla_a", "tecla_d"], "FOLHEAR"], [["tecla_m"], "FECHAR"]]


## A barra de vidro dos puzzles (a do CursorVirtual), com as dicas do caderno.
func _desenhar_rodape() -> void:
	var alfa := clampf((_abertura - 0.5) * 2.0, 0.0, 1.0)
	if alfa <= 0.0:
		return
	var dicas := _dicas()
	var lado := 16.0 * ESCALA_BOTAO
	var respiro_icone := 8.0
	var respiro_itens := 26.0
	var margem := 18.0
	var larguras: Array[float] = []
	var total := 0.0
	for dica in dicas:
		var largura := EstiloHUD.largura_texto(FONTE, String(dica[1]), TAM_DICA, ESPACO_DICA)
		var botoes: Array = dica[0]
		largura += (lado + 4.0) * botoes.size()
		if not botoes.is_empty():
			largura += respiro_icone - 4.0
		larguras.append(largura)
		total += largura
	total += respiro_itens * (dicas.size() - 1)

	var tela := _rodape.size
	var caixa := Rect2(Vector2((tela.x - total) * 0.5 - margem, tela.y - ALTURA_BARRA - 10.0),
		Vector2(total + margem * 2.0, ALTURA_BARRA))
	var corpo := EstiloHUD.chanfro(caixa, 12.0)
	EstiloHUD.sombra(_rodape, corpo, 4.0, alfa)
	EstiloHUD.vidro(_rodape, corpo, 0.92 * alfa)
	EstiloHUD.moldura(_rodape, corpo, EstiloHUD.com_alfa(EstiloHUD.BORDA, alfa), 1.5)
	_rodape.draw_line(corpo[0], corpo[1], EstiloHUD.com_alfa(EstiloHUD.FIO_LUZ, alfa), 1.5, true)

	var x := caixa.position.x + margem
	var meio := caixa.get_center().y
	var base := meio + FONTE.get_ascent(TAM_DICA) * 0.5 - 1.0
	for i in dicas.size():
		var inicio := x
		var botoes: Array = dicas[i][0]
		for nome in botoes:
			BotoesControle.desenhar(_rodape, Vector2(x + lado * 0.5, meio), nome,
				ESCALA_BOTAO, Color(1, 1, 1, alfa))
			x += lado + 4.0
		if not botoes.is_empty():
			x += respiro_icone - 4.0
		var cor := EstiloHUD.TEXTO if not botoes.is_empty() else EstiloHUD.TEXTO_FRACO
		EstiloHUD.texto(_rodape, FONTE, Vector2(x, base), String(dicas[i][1]), TAM_DICA,
			EstiloHUD.com_alfa(cor, alfa), ESPACO_DICA)
		x = inicio + larguras[i] + respiro_itens
