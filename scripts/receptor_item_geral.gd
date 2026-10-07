extends Area2D

# O SINAL MÁGICO: Ele avisa o resto do jogo que o puzzle foi feito!
signal puzzle_resolvido

@export_group("Configurações do Puzzle")
# Qual ID de item abre esse receptor? (Ex: "pacote_pregos", "cartao_fase2")
@export var item_necessario: String = "item_padrao"
# Segundo item obrigatório (deixe vazio para não exigir)
@export var item_necessario_2: String = ""

# Se marcado, o item some do inventário (ex: fusível/chave).
# Se desmarcado, o jogador guarda o item (ex: um pé de cabra ou alicate).
@export var consumir_item_ao_usar: bool = true

# Cena de puzzle (CanvasLayer com abrir_puzzle/puzzle_resolvido) aberta quando
# o jogador tem os itens. Deixe vazio para resolver direto como antes.
@export var puzzle_cena: PackedScene

@export_group("Sons do Receptor (v7.2)")
# Arraste aqui o arquivo de som para quando der certo
@export var som_sucesso: AudioStream
# Arraste aqui o arquivo de som para quando der errado
@export var som_erro: AudioStream

var jogador_na_area: bool = false
var ja_foi_resolvido: bool = false
var puzzle_ui: CanvasLayer = null

# Referências aos nós filhos
@onready var audio_player = $AudioStreamPlayer
@onready var computador_anim = $ComputadorAnimado
## O brilho da tela no escuro (scripts/luz/luz_pontual.gd): vermelho trancado,
## azul liberado, como a própria tela.
@onready var _luz_da_tela: LuzPontual = get_node_or_null("LuzDaTela")
const COR_DA_TELA_TRANCADA := Color(1.0, 0.24, 0.2)
const COR_DA_TELA_LIBERADA := Color(0.3, 0.62, 1.0)

# --- Garante que o computador comece em vermelho e a exclamação escondida ---
func _ready():
	# Quem precisa achar um receptor sem saber o caminho dele na cena (ex: o
	# atalho de debug da tecla K no player) procura por este grupo.
	add_to_group("receptor_item")

	# Painel já resolvido antes: nasce azul e trancado no estado final, sem
	# puzzle para abrir de novo quando a cena recarrega.
	ja_foi_resolvido = EstadoMundo.ja_feito(self)

	if has_node("ComputadorAnimado"):
		computador_anim.play("azul" if ja_foi_resolvido else "vermelho")
	_pintar_luz_da_tela()

	if has_node("ExclamacaoAnimada"):
		get_node("ExclamacaoAnimada").visible = false
		get_node("ExclamacaoAnimada").stop()

	# Instancia a tela de puzzle dinamicamente (igual à gaiola)
	if puzzle_cena and not ja_foi_resolvido:
		puzzle_ui = puzzle_cena.instantiate() as CanvasLayer
		add_child(puzzle_ui)
		puzzle_ui.puzzle_resolvido.connect(_on_puzzle_ui_resolvido)

func _process(_delta):
	# Se o jogador apertar "E" perto do receptor e o puzzle ainda estiver trancado
	if jogador_na_area and not ja_foi_resolvido and Interacao.pediu():
		verificar_puzzle()

func verificar_puzzle():
	# Com uma tela de puzzle própria, o jogador pode interagir mesmo sem os itens —
	# a tela mostra a vaga do que falta, e os itens são arrastados da mochila.
	if puzzle_ui:
		puzzle_ui.abrir_puzzle()
		return

	var tem_primeiro = Inventario.tem_item(item_necessario)
	var tem_segundo = item_necessario_2 == "" or Inventario.tem_item(item_necessario_2)
	if tem_primeiro and tem_segundo:
		sucesso_no_puzzle()
	else:
		erro_no_puzzle()

func _on_puzzle_ui_resolvido():
	# O puzzle já tocou os próprios sons de vitória
	sucesso_no_puzzle(false)

func sucesso_no_puzzle(tocar_som: bool = true):
	ja_foi_resolvido = true
	EstadoMundo.marcar_feito(self)
	print("Puzzle resolvido com o item: ", item_necessario)
	
	# Toca o som de Sucesso
	if tocar_som and som_sucesso and audio_player:
		audio_player.stream = som_sucesso
		audio_player.play()
	
	# --- NOVO: Muda a tela do computador para Azul imediatamente ---
	if has_node("ComputadorAnimado"):
		computador_anim.play("azul")
	_pintar_luz_da_tela()
	
	# Se estiver configurado para sumir com o item, remove do inventário
	if consumir_item_ao_usar:
		Inventario.remover_item(item_necessario)
		if item_necessario_2 != "":
			Inventario.remover_item(item_necessario_2)
	
	# Desativa a exclamação se ela existir
	if has_node("ExclamacaoAnimada"):
		PopupFX.esconder(get_node("ExclamacaoAnimada"))

	# DISPARA O SINAL! Qualquer objeto conectado a este receptor vai acordar agora
	puzzle_resolvido.emit()

func _pintar_luz_da_tela() -> void:
	if _luz_da_tela:
		_luz_da_tela.cor = COR_DA_TELA_LIBERADA if ja_foi_resolvido else COR_DA_TELA_TRANCADA


func erro_no_puzzle():
	print("Você não tem o item necessário: ", item_necessario)
	
	# Toca o som de Erro/Trancado
	if som_erro and audio_player:
		audio_player.stream = som_erro
		audio_player.play()

# --- CONEXÃO DE SINAIS (Seus gatilhos de entrada e saída) ---

func _on_body_entered(body):
	if body.name == "Player" and not ja_foi_resolvido:
		jogador_na_area = true
		if has_node("ExclamacaoAnimada"):
			PopupFX.mostrar(get_node("ExclamacaoAnimada"))

func _on_body_exited(body):
	if body.name == "Player":
		jogador_na_area = false
		# Só esconde ao sair se o puzzle ainda NÃO tiver sido resolvido
		if has_node("ExclamacaoAnimada") and not ja_foi_resolvido:
			PopupFX.esconder(get_node("ExclamacaoAnimada"))
