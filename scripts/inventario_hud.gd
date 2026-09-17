extends CanvasLayer

# --- A TELA DE COLETA (ficha + mochila) ---
#
# Este nó não desenha nada: ele conduz a cena de duas peças que desenham.
#
#   PopupItem  (scripts/ui/popup_item.gd)  — a ficha no centro da tela
#   Mochila    (scripts/ui/mochila_hud.gd) — a fileira no canto superior direito
#
# A coreografia de uma coleta é sempre a mesma:
#
#   1. o mundo pausa e escurece; a ficha se monta com o item, o nome, a
#      categoria, a explicação e — no rodapé — PARA ONDE aquilo vai;
#   2. no [E], o ícone se desprende do medalhão e voa até o alvéolo da mochila
#      (ou até o cinto, se for ferramenta), encolhendo no caminho;
#   3. só quando ele chega o alvéolo estoura, o item entra no inventário de
#      verdade e o mundo volta a andar.
#
# A ordem importa: "popup_fechado" só é emitido no fim de tudo, porque é nele
# que o FerramentasHUD se pendura para fazer o selo nascer no cinto — e o selo
# tem de nascer quando o ícone chega lá, não antes.
#
# A API pública é a mesma de sempre (exibir_popup, exibir_item_na_tela,
# remover_item_da_tela, popup_fechado): item_coletavel.gd, retorta.gd,
# Inventario.gd e ferramentas_hud.gd não precisaram mudar uma linha.

## Avisa quem abriu o popup que a pessoa já leu, fechou, e o item chegou ao
## destino. É por aqui que o FerramentasHUD sabe a hora de acender o selo.
signal popup_fechado(id: String)

## Tempo do voo do ícone até o destino.
const DURACAO_VOO := 0.52

@onready var _popup: PopupItem = $PopupItem
@onready var _mochila: MochilaHUD = $Mochila
@onready var _som_guardar: AudioStreamPlayer = $SomGuardar

## id -> índice do alvéolo. Mantido para quem consultava este dicionário.
var slots_ocupados: Dictionary = {}
## O item fica aqui até a pessoa fechar a ficha: quem não leu ainda não pegou.
var item_pendente: Dictionary = {}

var _id_no_popup: String = ""
var _fechando: bool = false
var _popup_apagado: bool = true

# Algumas cenas mantêm este HUD escondido (o laboratório, por exemplo). A
# ficha precisa aparecer mesmo assim, então ela acende a camada enquanto
# estiver aberta e devolve a visibilidade de antes no fim.
var _visibilidade_anterior: bool = true

# Mochila emprestada a um puzzle de arrastar (ver "emprestar_mochila").
var _mochila_emprestada: bool = false
var _posicao_mochila: Vector2 = Vector2.ZERO
var _escala_mochila: Vector2 = Vector2.ONE
var _visibilidade_antes_do_emprestimo: bool = true
var _tween_mochila: Tween = null


func _ready() -> void:
	Inventario.registrar_tela_inventario(self)
	_popup.visible = false
	_popup.fechado.connect(func() -> void: _popup_apagado = true)
	_repor_mochila()


## Este HUD mora no player.tscn, então cada cena nasce com uma mochila NOVA e
## vazia — mas o Inventario (autoload) continua com tudo o que a pessoa
## carrega. Sem repor aqui, trocar de cena (ir ao laboratório e voltar) fazia
## a lenha e os cilindros "sumirem" da tela, mesmo ainda estando no inventário.
func _repor_mochila() -> void:
	for item in Inventario.itens_coletados:
		var id := str(item.get("id", ""))
		var textura: Texture2D = item.get("textura")
		if id.is_empty() or textura == null:
			continue
		var indice := _mochila.restaurar(id, str(item.get("nome", id)), textura,
			EstiloHUD.cor_do_item(id))
		if indice >= 0:
			slots_ocupados[id] = indice


func _process(_delta: float) -> void:
	# "toque_de_tela" garante que a ficha só fecha com um E novo, apertado com
	# ela já aberta — e não com o mesmo toque que pegou o item e a abriu.
	if Inventario.popup_aberto and not _fechando and Interacao.toque_de_tela():
		fechar_popup()


# ─────────────────────────────────────────────
# A ficha
# ─────────────────────────────────────────────

## Abre a ficha do item.
##
## "guardar_no_inventario" é false para o que não ocupa alvéolo: as ferramentas
## permanentes (maçarico, bumerangue...) viram habilidade no Progresso, mas
## ganham a mesma apresentação dos cilindros — e o ícone voa para o cinto, no
## canto de baixo, em vez de para a mochila.
func exibir_popup(nome: String, textura: Texture2D, descricao: String, id: String,
		guardar_no_inventario: bool = true) -> void:
	item_pendente = {}
	if guardar_no_inventario:
		item_pendente = {"id": id, "nome": nome, "textura": textura}

	_id_no_popup = id
	_popup_apagado = false

	# Cena que esconde o HUD (o laboratório) não pode engolir a ficha.
	_visibilidade_anterior = visible
	visible = true

	_popup.abrir({
		"id": id,
		"nome": nome,
		"descricao": descricao,
		"icone": textura,
		"cor": EstiloHUD.cor_do_item(id),
		"destino": _texto_do_destino(id, guardar_no_inventario),
	})

	Inventario.popup_aberto = true
	get_tree().paused = true


## O rodapé da ficha responde "para onde isso foi?" antes de a pessoa fechar —
## é o que faz o voo do ícone ser confirmação, e não surpresa.
func _texto_do_destino(id: String, guardar_no_inventario: bool) -> String:
	if not guardar_no_inventario:
		return "CINTO DE FERRAMENTAS"
	if _mochila.tem(id):
		return "JÁ ESTAVA NA MOCHILA"
	if _mochila.esta_cheia():
		return "MOCHILA CHEIA"
	return "MOCHILA · SLOT %d" % (_mochila.proximo_livre() + 1)


func fechar_popup() -> void:
	if _fechando or not Inventario.popup_aberto:
		return
	_fechando = true

	# O ponto de partida do voo é lido ANTES de a ficha começar a apagar.
	var partida := _popup.centro_do_medalhao()
	var caixa_partida := _popup.caixa_do_icone()
	var id := _id_no_popup
	var cor := EstiloHUD.cor_do_item(id)

	_popup.fechar()

	if item_pendente.size() > 0:
		await _entregar_na_mochila(partida, caixa_partida, cor)
	elif CatalogoFerramentas.FERRAMENTAS.has(id):
		await _entregar_no_cinto(id, partida, caixa_partida, cor)

	# A ficha pode ter terminado de apagar antes do voo; por isso a espera é
	# por um estado, e não por um "await" no sinal (que já teria passado).
	while not _popup_apagado:
		await get_tree().process_frame

	_fechando = false
	Inventario.popup_aberto = false
	get_tree().paused = false
	visible = _visibilidade_anterior

	popup_fechado.emit(id)
	_id_no_popup = ""


## Item comum: entra no inventário de verdade e o ícone voa até o alvéolo.
func _entregar_na_mochila(partida: Vector2, caixa_partida: float, cor: Color) -> void:
	var id: String = item_pendente["id"]
	var nome: String = item_pendente["nome"]
	var textura: Texture2D = item_pendente["textura"]
	item_pendente = {}

	if not Inventario.tem_item(id):
		Inventario.itens_coletados.append({"id": id, "nome": nome, "textura": textura})

	if _mochila.tem(id):
		_mochila.destacar(id)
		return

	if _mochila.esta_cheia():
		push_warning("Mochila cheia: '%s' entrou no inventário sem alvéolo na tela." % nome)
		return

	await _voar(textura, cor, partida, caixa_partida,
		_mochila.centro_do_proximo(), _mochila.caixa_do_icone(), false)
	_guardar_no_alveolo(id, nome, textura, cor)


## Ferramenta: não ocupa alvéolo, mas o ícone ainda precisa ir para algum
## lugar — vai para o cinto, e apaga chegando, porque quem acende o selo lá é
## o FerramentasHUD assim que "popup_fechado" sai.
func _entregar_no_cinto(id: String, partida: Vector2, caixa_partida: float,
		cor: Color) -> void:
	var ficha := CatalogoFerramentas.dados(id)
	if ficha.is_empty():
		return
	var destino := _ponto_do_cinto()
	if destino == Vector2.ZERO:
		return
	await _voar(ficha["textura"], cor, partida, caixa_partida, destino, 42.0, true)


func _voar(textura: Texture2D, cor: Color, de: Vector2, caixa_de: float,
		para: Vector2, caixa_para: float, apagar: bool) -> void:
	if textura == null:
		return
	_popup.soltar_icone()
	var voo := VooDeItem.lancar(self, textura, cor, de, para, caixa_de, caixa_para,
		DURACAO_VOO)
	voo.apagar_ao_chegar = apagar
	await voo.chegou


func _ponto_do_cinto() -> Vector2:
	var cinto := get_node_or_null("/root/FerramentasHUD")
	if cinto != null and cinto.has_method("ponto_de_entrada"):
		return cinto.ponto_de_entrada()
	return Vector2.ZERO


# ─────────────────────────────────────────────
# A mochila
# ─────────────────────────────────────────────

## Coloca o item na fileira sem passar pela ficha — é por aqui que o
## Inventario.adicionar_item() entra quando alguma coisa é dada de mão beijada
## (sem popup) para a personagem.
func exibir_item_na_tela(id_do_item: String, nome_do_item: String,
		textura: Texture2D) -> void:
	if textura == null:
		push_warning("Item '%s' não tem textura definida no Inspector." % nome_do_item)
		return
	_guardar_no_alveolo(id_do_item, nome_do_item, textura, EstiloHUD.cor_do_item(id_do_item))


func remover_item_da_tela(id_do_item: String) -> void:
	_mochila.remover(id_do_item)
	slots_ocupados.erase(id_do_item)


# ─────────────────────────────────────────────
# Mochila emprestada (puzzles de arrastar item)
# ─────────────────────────────────────────────
#
# Num puzzle em que a pessoa entrega um item arrastando-o (o tubo receptor do
# computador do foguete), a mochila sai do canto e desliza (crescendo) até
# ficar perto do lugar onde o item deve cair. O caminho do arrasto fica curto
# e óbvio — ninguém precisa descobrir que dá para pegar coisas lá do canto.
#
# Quem pede recebe a própria MochilaHUD, para medir alvéolos e retirar itens;
# a mochila continua morando aqui, e volta para o canto em "devolver_mochila".

## Leva a mochila para dentro de "area" (coordenadas de tela): o painel fica
## centrado nela e na maior escala que cabe sem distorcer. É assim que o puzzle
## decide onde e de que tamanho ela aparece — ver o retângulo AreaMochila da
## cena do puzzle. A camada acende mesmo em cena que esconde o HUD.
func emprestar_mochila(area: Rect2, duracao: float = 0.5) -> MochilaHUD:
	if not _mochila_emprestada:
		_mochila_emprestada = true
		# Pedida de novo enquanto ainda voltava para o canto (fechou e reabriu
		# o puzzle rápido): a casa e a visibilidade continuam as de antes, e
		# não o ponto do meio do caminho.
		if _tween_mochila == null or not _tween_mochila.is_valid():
			_posicao_mochila = _mochila.global_position
			_escala_mochila = _mochila.scale
			_visibilidade_antes_do_emprestimo = visible
	visible = true

	# Painel sem escala, em coordenadas locais da mochila (o pivô é o canto de
	# cima à esquerda, então escala e posição se compõem direto).
	var painel := Rect2(Vector2(maxf(_mochila.size.x - MochilaHUD.LARGURA_TOTAL, 0.0), 0.0),
		Vector2(MochilaHUD.LARGURA_TOTAL, MochilaHUD.ALTURA_TOTAL))
	var escala := minf(area.size.x / painel.size.x, area.size.y / painel.size.y)
	if escala <= 0.0:
		escala = 1.0
	var canto_do_painel := area.get_center() - painel.size * escala * 0.5
	_mover_mochila(canto_do_painel - painel.position * escala, Vector2.ONE * escala, duracao)
	return _mochila


## Manda a mochila de volta ao canto. Seguro de chamar mesmo sem empréstimo.
func devolver_mochila(duracao: float = 0.45) -> void:
	if not _mochila_emprestada:
		return
	_mochila_emprestada = false
	_mochila.foco = -1
	var tween := _mover_mochila(_posicao_mochila, _escala_mochila, duracao)
	var visibilidade := _visibilidade_antes_do_emprestimo
	if tween == null:
		visible = visibilidade
		return
	tween.finished.connect(func() -> void:
		# Uma coleta aberta no meio do caminho cuida da própria visibilidade.
		if not _mochila_emprestada and not Inventario.popup_aberto:
			visible = visibilidade)


func mochila_emprestada() -> bool:
	return _mochila_emprestada


func _mover_mochila(destino: Vector2, escala: Vector2, duracao: float) -> Tween:
	if _tween_mochila != null and _tween_mochila.is_valid():
		_tween_mochila.kill()
	_tween_mochila = null
	if duracao <= 0.0:
		_mochila.scale = escala
		_mochila.global_position = destino
		return null
	_tween_mochila = create_tween()
	_tween_mochila.set_parallel(true)
	_tween_mochila.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween_mochila.tween_property(_mochila, "global_position", destino, duracao)
	_tween_mochila.tween_property(_mochila, "scale", escala, duracao)
	return _tween_mochila


func _guardar_no_alveolo(id: String, nome: String, textura: Texture2D, cor: Color) -> void:
	var indice := _mochila.guardar(id, nome, textura, cor)
	if indice < 0:
		push_warning("Mochila cheia: '%s' não coube na tela." % nome)
		return
	slots_ocupados[id] = indice
	if _som_guardar != null and _som_guardar.stream != null:
		_som_guardar.play()
