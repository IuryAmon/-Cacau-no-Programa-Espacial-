class_name FadeTela
extends CanvasLayer

# Cortina preta que cobre a tela inteira, usada nas transições entre cenas
# (porta do laboratório, entrada e saída do simulador).
#
# Detalhe importante de ordem de desenho: esta camada fica em layer 0, ou seja,
# ACIMA do mundo 2D (que desenha no canvas padrão) mas ABAIXO do Dialogic, que
# monta seu layout em layer 1. É assim que o Dr. Chico consegue falar com a
# tela já escura — o balão aparece por cima do preto.
#
# HUDs (vida, inventário) são CanvasLayer em layer 1 e ficariam visíveis por
# cima do preto, então "esconder_huds()" apaga essas camadas durante a
# transição.

const COR_CORTINA := Color(0, 0, 0, 1)

## Marcado por quem troca de cena com a tela já apagada. A cena que abrir em
## seguida consome isso (via "clarear_na_chegada") para nascer preta e clarear,
## em vez de aparecer de estalo. Static var sobrevive à troca de cena.
static var chegada_escura: bool = false

var _cortina: ColorRect
var _camadas_escondidas: Array[CanvasLayer] = []


## Cria a cortina já dentro da cena de "dono". Se "comeca_preto" for true, a
## tela nasce totalmente escura (para depois clarear).
static func criar(dono: Node, comeca_preto: bool = false) -> FadeTela:
	var fade := FadeTela.new()
	fade.name = "FadeTela"
	fade.layer = 0
	# Continua animando mesmo com a árvore pausada (menu de pausa aberto).
	fade.process_mode = Node.PROCESS_MODE_ALWAYS

	var cortina := ColorRect.new()
	cortina.color = COR_CORTINA
	cortina.set_anchors_preset(Control.PRESET_FULL_RECT)
	cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cortina.modulate.a = 1.0 if comeca_preto else 0.0
	cortina.visible = comeca_preto
	fade._cortina = cortina
	fade.add_child(cortina)

	# Quando a cortina é criada de dentro do _ready() de um nó da cena, a raiz
	# ainda está montando os filhos e um add_child() direto falha.
	if dono.is_node_ready():
		dono.add_child(fade)
	else:
		dono.add_child.call_deferred(fade)
	return fade


## Apaga a tela e só então troca de cena, deixando marcado que a cena de
## destino deve nascer preta e clarear.
static func trocar_cena(no: Node, caminho: String, duracao: float = 0.7) -> void:
	# Saída por porta/passagem (a recarga de morte não passa por aqui): quem
	# guarda estado só ao sair anota agora, antes de a cena ser desmontada.
	no.get_tree().call_group(EstadoMundo.GRUPO_SALVAR_AO_SAIR, "salvar_ao_sair")
	var raiz := no.get_tree().current_scene
	var fade := criar(raiz, false)
	await fade.escurecer(duracao)
	fade.esconder_huds(raiz)
	chegada_escura = true
	no.get_tree().change_scene_to_file(caminho)


## Chamado no _ready() de quem recebe o jogador. Não faz nada se a cena não
## veio de uma transição apagada.
##
## "antes_de_clarear" é o último ajuste feito com a tela ainda toda preta, já
## depois do _ready() da cena inteira ter rodado. É onde quem recebe o jogador
## coloca ele (e a câmera, que é filha dele) no lugar definitivo: assim o
## mundo já aparece enquadrado, em vez de nascer no spawn da cena e a câmera
## deslizar até o lugar certo na frente do jogador.
static func clarear_na_chegada(raiz: Node, duracao: float = 0.7, espera: float = 0.15,
		antes_de_clarear: Callable = Callable()) -> void:
	if not chegada_escura:
		return
	chegada_escura = false

	var fade := criar(raiz, true)
	fade.esconder_huds(raiz)
	# Um respiro no preto antes do mundo novo aparecer.
	await raiz.get_tree().create_timer(espera).timeout
	if antes_de_clarear.is_valid():
		antes_de_clarear.call()
	await fade.clarear(duracao)
	fade.restaurar_huds()
	fade.queue_free()


func escurecer(duracao: float = 1.4) -> void:
	await _esperar_entrar_na_arvore()
	_cortina.visible = true
	var tween := create_tween()
	tween.tween_property(_cortina, "modulate:a", 1.0, duracao)
	await tween.finished


func clarear(duracao: float = 1.0) -> void:
	await _esperar_entrar_na_arvore()
	_cortina.visible = true
	var tween := create_tween()
	tween.tween_property(_cortina, "modulate:a", 0.0, duracao)
	await tween.finished
	_cortina.visible = false


# create_tween() só funciona com o nó já dentro da árvore; se a cortina foi
# adicionada de forma adiantada (call_deferred), espera ela entrar.
func _esperar_entrar_na_arvore() -> void:
	if not is_inside_tree():
		await tree_entered


## Esconde todo CanvasLayer da cena que ficaria por cima da cortina (HUD de
## vida, inventário, etc). Guarda quem foi escondido para poder restaurar.
func esconder_huds(raiz: Node) -> void:
	for camada in _listar_camadas(raiz):
		if camada == self or camada.layer < layer or not camada.visible:
			continue
		_camadas_escondidas.append(camada)
		camada.visible = false

	# O cinto de ferramentas (selo do maçarico etc.) é autoload — vive FORA da
	# cena, então não aparece na varredura acima, mas desenha por cima da
	# cortina igual aos outros HUDs, então também precisa sumir aqui.
	#
	# Ele NÃO entra na lista comum de propósito: ao contrário dos CanvasLayer
	# da cena (que morrem junto com ela), ele sobrevive à troca — e quem o
	# escondeu é o FadeTela da cena ANTIGA, que é destruído no meio do
	# change_scene_to_file antes de poder restaurar. O FadeTela da cena NOVA
	# nunca esconderia esse HUD de novo (já estava invisível), e por isso
	# nunca o devolveria — ele sumia para sempre depois da primeira porta.
	# É por isso que quem religa é sempre restaurar_huds(), incondicionalmente,
	# e não este método.
	var ferramentas := raiz.get_tree().root.get_node_or_null("FerramentasHUD")
	if ferramentas is CanvasLayer:
		ferramentas.visible = false


func restaurar_huds() -> void:
	for camada in _camadas_escondidas:
		if is_instance_valid(camada):
			camada.visible = true
	_camadas_escondidas.clear()

	# Sempre religa o cinto de ferramentas, mesmo que quem o escondeu tenha
	# sido outra instância de FadeTela (a da cena anterior — ver esconder_huds).
	if is_inside_tree():
		var ferramentas := get_tree().root.get_node_or_null("FerramentasHUD")
		if ferramentas is CanvasLayer:
			ferramentas.visible = true


func _listar_camadas(no: Node) -> Array[CanvasLayer]:
	var encontradas: Array[CanvasLayer] = []
	if no is CanvasLayer:
		encontradas.append(no)
	for filho in no.get_children():
		encontradas.append_array(_listar_camadas(filho))
	return encontradas
