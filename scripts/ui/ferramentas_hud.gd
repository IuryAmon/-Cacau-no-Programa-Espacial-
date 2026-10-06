extends CanvasLayer

# --- AUTOLOAD "FerramentasHUD" ---
#
# O cinto de ferramentas na tela. Três responsabilidades:
#
#   1. APRESENTAR a ferramenta quando ela é conquistada, com o mesmo ritual
#      dos cilindros de H₂ e O₂: a ficha de coleta no centro, o mundo pausado,
#      [E] para fechar, e o ícone voando do medalhão até o canto. A diferença é
#      que ferramenta não ocupa alvéolo da mochila — ela vira habilidade
#      permanente no Progresso e mora no cinto.
#   2. GUARDAR o cinto no canto inferior direito (scripts/ui/cinto_hud.gd),
#      para a personagem sempre saber o que carrega e com que tecla usa.
#   3. ENSINAR a ferramenta que tem tutorial no catálogo (hoje, o bumerangue):
#      assim que a ficha de coleta fecha e o ícone chega no cinto, sobe a ficha
#      de tutorial (scripts/ui/tutorial_ferramenta.gd): uma telinha animada e
#      uma frase. O mundo continua parado até o ESC (ou o E).
#
# É autoload porque habilidade atravessa fase: o cinto precisa continuar na
# tela depois de uma troca de cena ou de uma morte, sem ninguém remontar.
# Quem quiser destacar uma ferramenta em uso chama FerramentasHUD.destacar().

## A pessoa leu o tutorial da ferramenta e fechou a ficha.
signal tutorial_fechado(habilidade: String)

## Respiro entre ganhar a ferramenta e a ficha subir — só o suficiente para o
## pickup sumir da tela antes de a ficha tomar o centro.
const ESPERA_APRESENTACAO := 0.25

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

## O tutorial tem camada própria, acima da mochila (95): o véu dele escurece a
## tela inteira, como o da ficha de coleta.
const CAMADA_TUTORIAL := 96

var _cinto: CintoHUD = null
var _tutorial: TutorialFerramenta = null
var _habilidade_no_tutorial: String = ""
var _fechando_tutorial: bool = false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

	var raiz := Control.new()
	raiz.name = "Ancora"
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)

	_cinto = CintoHUD.new()
	_cinto.name = "Cinto"
	_cinto.fonte = FONTE
	raiz.add_child(_cinto)

	var camada := CanvasLayer.new()
	camada.name = "CamadaTutorial"
	camada.layer = CAMADA_TUTORIAL
	add_child(camada)
	_tutorial = TutorialFerramenta.new()
	_tutorial.name = "Tutorial"
	_tutorial.fonte = FONTE
	camada.add_child(_tutorial)

	Progresso.habilidade_conquistada.connect(_on_habilidade_conquistada)
	# Trocou de teclado para controle (ou o contrário): as tampas embaixo das
	# ferramentas trocam a tecla pelo botão.
	Controle.mudou.connect(func(_em_uso: bool) -> void: _cinto.queue_redraw())

	# Rede de segurança: se por algum caminho a personagem já tiver ferramenta
	# antes deste nó existir, o cinto nasce pronto, sem apresentação.
	for habilidade in Progresso.HABILIDADES:
		if Progresso.tem_habilidade(habilidade):
			_pendurar(habilidade, false)


# --- APRESENTAÇÃO DA FERRAMENTA NOVA ---

func _on_habilidade_conquistada(habilidade: String) -> void:
	var ficha := CatalogoFerramentas.dados(habilidade)
	if ficha.is_empty():
		return  # Ferramenta ainda sem arte: nada a mostrar.
	_apresentar(habilidade, ficha)


func _apresentar(habilidade: String, ficha: Dictionary) -> void:
	await get_tree().create_timer(ESPERA_APRESENTACAO).timeout

	# Nunca por cima de uma fala do Dialogic nem de outra ficha de coleta.
	while Dialogic.current_timeline != null or Inventario.popup_aberto:
		await get_tree().process_frame

	var hud = Inventario.tela_hud_referencia
	if hud != null and is_instance_valid(hud) and hud.has_method("exibir_popup"):
		# O alvéolo só nasce depois que a pessoa lê e fecha a ficha — e o
		# "popup_fechado" só sai quando o ícone termina o voo até aqui, então
		# o alvéolo estoura no frame em que o desenho chega no canto.
		var ao_fechar := func(_id: String) -> void:
			_pendurar(habilidade, true)
			# Com a ferramenta já no cinto, a explicação de como se usa.
			ensinar(habilidade)
		hud.popup_fechado.connect(ao_fechar, CONNECT_ONE_SHOT)
		hud.exibir_popup(ficha["nome"], ficha["textura"], ficha["descricao"],
			habilidade, false)
	else:
		_pendurar(habilidade, true)


# --- O TUTORIAL DA FERRAMENTA ---

## Sobe a ficha de tutorial da ferramenta e para o mundo até a pessoa fechar.
## Não faz nada se ela não tiver tutorial no catálogo.
func ensinar(habilidade: String) -> void:
	var dados := CatalogoFerramentas.tutorial(habilidade)
	if dados.is_empty() or tutorial_aberto():
		return
	_habilidade_no_tutorial = habilidade
	_tutorial.abrir(dados)
	# O E é da ficha enquanto ela estiver na tela (e o □, que no controle
	# também é o do bumerangue, não arremessa nada ao fechá-la).
	Interacao.marcar_tela_aberta(_tutorial, true)
	get_tree().paused = true


func fechar_tutorial() -> void:
	if not tutorial_aberto() or _fechando_tutorial:
		return
	_fechando_tutorial = true
	_tutorial.fechar()
	await _tutorial.fechado
	_fechando_tutorial = false

	Interacao.marcar_tela_aberta(_tutorial, false)
	get_tree().paused = false
	var habilidade := _habilidade_no_tutorial
	_habilidade_no_tutorial = ""
	tutorial_fechado.emit(habilidade)


## True enquanto a ficha de tutorial está na tela (inclusive saindo).
func tutorial_aberto() -> bool:
	return _habilidade_no_tutorial != ""


# QUEM FECHA A FICHA
#   ESC / △   a tecla desenhada no pé dela (a ação "fechar", a dos puzzles);
#   E / □     também fecha, para quem vem apertando E desde a ficha de coleta.
# Nenhum dos dois fecha com a ficha ainda subindo.

func _input(evento: InputEvent) -> void:
	if not tutorial_aberto() or not evento.is_action_pressed(TutorialFerramenta.ACAO_FECHAR):
		return
	# Com a ficha na tela o ESC é dela — inclusive o apertado cedo demais, que
	# só não fecha — e não passa para o jogo parado atrás.
	get_viewport().set_input_as_handled()
	if _tutorial.pode_fechar():
		fechar_tutorial()


func _process(_delta: float) -> void:
	# "toque_de_tela": só um E novo, apertado com a ficha já montada, fecha —
	# e não o toque que acabou de passar a ficha de coleta.
	if tutorial_aberto() and _tutorial.pode_fechar() and Interacao.toque_de_tela():
		fechar_tutorial()


# --- O CINTO ---

func _pendurar(habilidade: String, anunciar: bool) -> void:
	if _cinto == null or not is_instance_valid(_cinto):
		return
	var ficha := CatalogoFerramentas.dados(habilidade)
	if ficha.is_empty():
		return
	ficha["tecla"] = CatalogoFerramentas.tecla(habilidade)
	ficha["acao"] = CatalogoFerramentas.acao(habilidade)
	_cinto.pendurar(ficha, anunciar)


## Onde o próximo alvéolo do cinto vai nascer, em coordenadas de tela.
##
## A ficha de coleta usa isto como destino do voo do ícone: quando a
## ferramenta é apresentada, o desenho sai do medalhão no centro da tela e cai
## exatamente aqui, no instante em que o alvéolo estoura.
func ponto_de_entrada() -> Vector2:
	if _cinto == null or not is_instance_valid(_cinto):
		return Vector2.ZERO
	return _cinto.ponto_de_entrada()


## Pulsa a ferramenta que acabou de ser usada no mundo (corte de chapa,
## acender a retorta) e acende o nome dela no cabeçalho do cinto. Silencioso
## se a ferramenta não estiver no cinto.
func destacar(habilidade: String) -> void:
	if _cinto != null and is_instance_valid(_cinto):
		_cinto.destacar(habilidade)


## True se a ferramenta já tem alvéolo na tela.
func tem_no_cinto(habilidade: String) -> bool:
	return _cinto != null and is_instance_valid(_cinto) and _cinto.tem(habilidade)
