class_name TransicaoDeCena
extends CanvasLayer

# --- A CORTINA ENTRE O MENU, O LABORATÓRIO E O JOGO ---
#
# Troca de cena com a tela escurecendo e clareando, para as telas do menu
# principal e do Laboratório:
#
#   TransicaoDeCena.ir_para(get_tree(), TransicaoDeCena.CENA_LABORATORIO)
#
# A cortina não mora em cena nenhuma: ela se pendura na raiz da árvore, escurece,
# troca a cena, espera a nova ficar pronta, clareia e some sozinha. Por isso a
# cena que chega não precisa fazer nada para aparecer clareando. É assim que o
# world1 abre vindo do menu sem ter sido mexido.
#
# POR QUE NÃO A FadeTela, a cortina das portas do jogo: ela apaga os HUDs que
# são autoload (equipamentos, objetivos, caderno) e conta com a cena de destino
# para religá-los (FadeTela.clarear_na_chegada). O world1, que é por onde a
# história começa, nunca chega por porta e não faz isso: os HUDs ficariam
# apagados. Aqui ninguém apaga HUD: a cortina fica numa camada acima de todos
# eles e os cobre enquanto está escura.
#
# Enquanto uma troca está em curso, um segundo pedido é ignorado (dois cliques
# seguidos num botão do menu não trocam de cena duas vezes) e a cortina segura
# os cliques, para nada da tela que está saindo ser apertado.

## Uma troca acabou: a cena nova já está clara e a cortina sumiu.
signal terminou

const CENA_MENU := "res://scenes/menu_principal.tscn"
const CENA_LABORATORIO := "res://scenes/laboratorio/menu_laboratorio.tscn"
## Onde o modo história começa.
const CENA_HISTORIA := "res://scenes/world1.tscn"

## Acima de tudo: do caderno aberto (100) e do cursor do controle (110).
const CAMADA := 120
const COR := Color(0.047, 0.055, 0.110)
const DURACAO := 0.3

static var _em_curso: bool = false

var _caminho: String = ""
var _duracao: float = DURACAO
var _cortina: ColorRect


## Escurece, troca para a cena de "caminho" e clareia. Devolve a cortina (para
## quem quiser esperar o "terminou"), ou null se já havia uma troca em curso.
static func ir_para(arvore: SceneTree, caminho: String, duracao: float = DURACAO) -> TransicaoDeCena:
	if _em_curso or arvore == null:
		return null
	if not ResourceLoader.exists(caminho):
		push_error("TransicaoDeCena: não existe a cena '%s'." % caminho)
		return null
	_em_curso = true
	var cortina := TransicaoDeCena.new()
	cortina.name = "TransicaoDeCena"
	cortina._caminho = caminho
	cortina._duracao = maxf(duracao, 0.01)
	arvore.root.add_child(cortina)
	return cortina


## Há uma troca de cena acontecendo agora?
static func em_curso() -> bool:
	return _em_curso


func _ready() -> void:
	layer = CAMADA
	# A cena que sai pode ter parado o jogo: a cortina anda mesmo assim.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cortina = ColorRect.new()
	_cortina.color = Color(COR, 0.0)
	_cortina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cortina.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_cortina)
	_trocar()


func _exit_tree() -> void:
	# Se a cortina for tirada da árvore no meio (o jogo fechando), a trava solta.
	_em_curso = false


func _trocar() -> void:
	var escurece := create_tween()
	escurece.tween_property(_cortina, "color:a", 1.0, _duracao)
	await escurece.finished

	# Nenhuma tela do menu ou do Laboratório deixa o jogo parado para trás.
	get_tree().paused = false
	var erro := get_tree().change_scene_to_file(_caminho)
	if erro != OK:
		push_error("TransicaoDeCena: não consegui abrir '%s' (erro %d)." % [_caminho, erro])
	# A troca acontece no fim do quadro: dois quadros e a cena nova já montou.
	for i in 2:
		await get_tree().process_frame

	var clareia := create_tween()
	clareia.tween_property(_cortina, "color:a", 0.0, _duracao)
	await clareia.finished
	_em_curso = false
	terminou.emit()
	queue_free()
