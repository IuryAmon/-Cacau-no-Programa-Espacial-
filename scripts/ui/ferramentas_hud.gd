extends CanvasLayer

# --- AUTOLOAD "FerramentasHUD" ---
#
# Os equipamentos da Cacau na tela. Três responsabilidades:
#
#   1. APRESENTAR a ferramenta quando ela é conquistada, com o mesmo ritual
#      dos cilindros de H₂ e O₂: a ficha de coleta no centro, o mundo pausado,
#      [E] para fechar, e o ícone voando da ficha até o canto. A diferença é
#      que ferramenta não ocupa casa da mochila — ela vira habilidade
#      permanente no Progresso e mora nos equipamentos.
#   2. GUARDAR os equipamentos no canto inferior direito
#      (scripts/ui/equipamentos_hud.gd), para a personagem sempre saber o que
#      tem e com que tecla usa.
#   3. ENSINAR a ferramenta que tem tutorial no catálogo (hoje, o bumerangue):
#      assim que a ficha de coleta fecha e o ícone chega no canto, sobe a ficha
#      de tutorial (scripts/ui/tutorial_ferramenta.gd): uma telinha animada e
#      uma frase. O mundo continua parado até uma tecla de ação qualquer.
#
# É autoload porque habilidade atravessa fase: os equipamentos precisam
# continuar na tela depois de uma troca de cena ou de uma morte, sem ninguém
# remontar.
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

var _equipamentos: EquipamentosHUD = null
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

	_equipamentos = EquipamentosHUD.new()
	_equipamentos.name = "Equipamentos"
	_equipamentos.fonte = FONTE
	raiz.add_child(_equipamentos)

	var camada := CanvasLayer.new()
	camada.name = "CamadaTutorial"
	camada.layer = CAMADA_TUTORIAL
	add_child(camada)
	_tutorial = TutorialFerramenta.new()
	_tutorial.name = "Tutorial"
	_tutorial.fonte = FONTE
	camada.add_child(_tutorial)

	Progresso.habilidade_conquistada.connect(_on_habilidade_conquistada)
	# Trocou de teclado para controle (ou o contrário): as teclas embaixo dos
	# equipamentos viram o botão.
	Controle.mudou.connect(func(_em_uso: bool) -> void: _equipamentos.queue_redraw())

	# Rede de segurança: se por algum caminho a personagem já tiver ferramenta
	# antes deste nó existir, a ficha dela nasce pronta, sem apresentação.
	for habilidade in Progresso.HABILIDADES:
		if Progresso.tem_habilidade(habilidade):
			_equipar(habilidade, false)


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
		# A ficha do equipamento só nasce depois que a pessoa lê e fecha a de
		# coleta — e o "popup_fechado" só sai quando o ícone termina o voo até
		# aqui, então ela brota no frame em que o desenho chega no canto.
		var ao_fechar := func(_id: String) -> void:
			_equipar(habilidade, true)
			# Com a ferramenta já equipada, a explicação de como se usa.
			ensinar(habilidade)
		hud.popup_fechado.connect(ao_fechar, CONNECT_ONE_SHOT)
		hud.exibir_popup(ficha["nome"], ficha["textura"], ficha["descricao"],
			habilidade, false)
	else:
		_equipar(habilidade, true)


# --- O TUTORIAL DA FERRAMENTA ---

## Sobe a ficha de tutorial da ferramenta e para o mundo até a pessoa fechar.
## Não faz nada se ela não tiver tutorial no catálogo.
func ensinar(habilidade: String) -> void:
	var dados := CatalogoFerramentas.tutorial(habilidade)
	if dados.is_empty() or tutorial_aberto():
		return
	_habilidade_no_tutorial = habilidade
	_tutorial.abrir(dados)
	# As teclas são da ficha enquanto ela estiver na tela: a que a fecha (o F,
	# o espaço, o □ do controle...) não arremessa, não pula nem dá dash depois.
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
#   Qualquer tecla de AÇÃO do jogo: espaço, enter, ESC, shift, F, E... e, no
#   controle, ✕ ○ □ △. A ficha mostra o E no canto (o □, de controle), como
#   a ficha de coleta, mas a pessoa pode apertar o que tiver na mão. Só as
#   teclas de ANDAR não fecham (WASD, setas, direcional e analógico), nem
#   tecla que não faz nada no jogo.
# Nenhuma fecha com a ficha ainda subindo.

func _input(evento: InputEvent) -> void:
	if not tutorial_aberto() or not _e_tecla_de_acao(evento):
		return
	# Com a ficha na tela a tecla é dela — inclusive a apertada cedo demais, que
	# só não fecha — e não passa para o jogo parado atrás.
	get_viewport().set_input_as_handled()
	if _tutorial.pode_fechar():
		fechar_tutorial()


## O toque (novo, não o de tecla segurada) é de alguma ação do jogo? Vale
## qualquer ação do mapa de entrada do projeto — as que existem hoje e as que
## vierem. Ficam de fora só as "ui_*" da engine: é com elas que a Cacau anda, e
## as teclas das outras (enter, espaço, ESC) já são de ações do jogo.
func _e_tecla_de_acao(evento: InputEvent) -> bool:
	for acao in InputMap.get_actions():
		if not String(acao).begins_with("ui_") and evento.is_action_pressed(acao):
			return true
	return false


# --- OS EQUIPAMENTOS ---

func _equipar(habilidade: String, anunciar: bool) -> void:
	if _equipamentos == null or not is_instance_valid(_equipamentos):
		return
	var ficha := CatalogoFerramentas.dados(habilidade)
	if ficha.is_empty():
		return
	ficha["tecla"] = CatalogoFerramentas.tecla(habilidade)
	ficha["acao"] = CatalogoFerramentas.acao(habilidade)
	_equipamentos.equipar(ficha, anunciar)


## Onde a ficha do próximo equipamento vai nascer, em coordenadas de tela.
##
## A ficha de coleta usa isto como destino do voo do ícone: quando a
## ferramenta é apresentada, o desenho sai do centro da tela e cai exatamente
## aqui, no instante em que a ficha dela brota.
func ponto_de_entrada() -> Vector2:
	if _equipamentos == null or not is_instance_valid(_equipamentos):
		return Vector2.ZERO
	return _equipamentos.ponto_de_entrada()


## Tamanho do desenho dentro da ficha do equipamento (é onde o voo termina).
func caixa_do_icone() -> float:
	return EquipamentosHUD.CAIXA_ICONE


## Faz a ficha do equipamento que acabou de ser usado no mundo dar um pulinho
## (corte de chapa, acender a retorta). Silencioso se ela ainda não o tiver.
func destacar(habilidade: String) -> void:
	if _equipamentos != null and is_instance_valid(_equipamentos):
		_equipamentos.destacar(habilidade)


## True se a ferramenta já tem ficha na tela.
func tem_equipamento(habilidade: String) -> bool:
	return _equipamentos != null and is_instance_valid(_equipamentos) 		and _equipamentos.tem(habilidade)
