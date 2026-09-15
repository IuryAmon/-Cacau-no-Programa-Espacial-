extends CanvasLayer

# --- AUTOLOAD "FerramentasHUD" ---
#
# O cinto de ferramentas na tela. Duas responsabilidades:
#
#   1. APRESENTAR a ferramenta quando ela é conquistada, com o mesmo ritual
#      dos cilindros de H₂ e O₂: a ficha de coleta no centro, o mundo pausado,
#      [E] para fechar, e o ícone voando do medalhão até o canto. A diferença é
#      que ferramenta não ocupa alvéolo da mochila — ela vira habilidade
#      permanente no Progresso e mora no cinto.
#   2. GUARDAR o cinto no canto inferior direito (scripts/ui/cinto_hud.gd),
#      para a personagem sempre saber o que carrega e com que tecla usa.
#
# É autoload porque habilidade atravessa fase: o cinto precisa continuar na
# tela depois de uma troca de cena ou de uma morte, sem ninguém remontar.
# Quem quiser destacar uma ferramenta em uso chama FerramentasHUD.destacar().

## Respiro entre ganhar a ferramenta e a ficha subir — só o suficiente para o
## pickup sumir da tela antes de a ficha tomar o centro.
const ESPERA_APRESENTACAO := 0.25

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

var _cinto: CintoHUD = null


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

	Progresso.habilidade_conquistada.connect(_on_habilidade_conquistada)

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
		hud.popup_fechado.connect(
			func(_id: String) -> void: _pendurar(habilidade, true),
			CONNECT_ONE_SHOT)
		hud.exibir_popup(ficha["nome"], ficha["textura"], ficha["descricao"],
			habilidade, false)
	else:
		_pendurar(habilidade, true)


# --- O CINTO ---

func _pendurar(habilidade: String, anunciar: bool) -> void:
	if _cinto == null or not is_instance_valid(_cinto):
		return
	var ficha := CatalogoFerramentas.dados(habilidade)
	if ficha.is_empty():
		return
	ficha["tecla"] = CatalogoFerramentas.tecla(habilidade)
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
