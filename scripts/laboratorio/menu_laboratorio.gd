extends TelaInterativa

# --- O MENU DO LABORATÓRIO ---
#
# O Laboratório é o modo de jogo fora da história: os puzzles e as simulações
# dela, soltos, para brincar quantas vezes quiser. Este é o balcão dele: um
# CARTÃO para cada atividade, com um desenho feito da própria arte do jogo e o
# nome dela, que já diz o que se faz lá.
#
#   MONTE SEU ÁTOMO     o puzzle do bumerangue, com qualquer átomo
#   QUE ÁTOMO É ESSE?   o computador desenha o átomo, a pessoa diz o elemento
#   BALANCEAMENTO       o puzzle do foguete e o do maçarico, com muitas reações
#   COMPRESSOR DE AR    o compressor da fase do nitrogênio, virado simulador de
#                       gases: P · V = n · R · T
#   DESTILADOR          a coluna de destilação, com várias misturas
#   TABELA PERIÓDICA    os 118 elementos, na caixa do caderno da Cacau
#
# PARA PÔR UMA ATIVIDADE NOVA: acrescente uma linha em ATIVIDADES (a chave, o
# nome e a cena dela) e escreva o desenho do cartão em
# _desenhar_a_figura. Os cartões se arrumam sozinhos, em fileiras de até
# POR_FILEIRA, com a última centrada.
#
# CONTROLES: mouse (passar e clicar); setas ou WASD levam o foco de um cartão
# a outro e ENTER, ESPAÇO ou E entram; ESC volta ao menu principal. No
# controle: direcional (ou analógico), ✕ e △.

const ATIVIDADES := [
	{"chave": "monte", "nome": "MONTE SEU ÁTOMO",
		"cena": "res://scenes/laboratorio/monte_seu_atomo.tscn"},
	{"chave": "quiz", "nome": "QUE ÁTOMO É ESSE?",
		"cena": "res://scenes/laboratorio/que_atomo_e_esse.tscn"},
	{"chave": "balanceamento", "nome": "BALANCEAMENTO",
		"cena": "res://scenes/laboratorio/balanceamento.tscn"},
	{"chave": "compressor", "nome": "COMPRESSOR DE AR",
		"cena": "res://scenes/laboratorio/compressor.tscn"},
	{"chave": "destilador", "nome": "DESTILADOR",
		"cena": "res://scenes/laboratorio/destilador.tscn"},
	{"chave": "tabela", "nome": "TABELA PERIÓDICA",
		"cena": "res://scenes/laboratorio/tabela_periodica.tscn"},
]

# ── Os cartões (px da tela) ──
const TAMANHO_DO_CARTAO := Vector2(440, 276)
const POR_FILEIRA := 3
const ENTRE_CARTOES := Vector2(36, 28)
## A altura em que a primeira fileira começa.
const ALTO := 136.0
## A parte de cima do cartão, onde vai o desenho.
const ALTURA_DA_FIGURA := 196.0
const TAM_NOME := 33

const TINTA := Color8(0x3d, 0x2a, 0x22)
const TINTA_TITULO := Color8(0x8e, 0x3b, 0x2c)
const TINTA_FRACA := Color8(0x8a, 0x6d, 0x52)

## Os átomos que giram nos cartões: [prótons, nêutrons, elétrons].
const ATOMO_DO_MONTE := [3, 4, 3]
const ATOMO_DO_QUIZ := [6, 6, 6]

## O compressor do mapa da fase do nitrogênio, e as fichas das letras da
## equação, que são as da tela dele.
const ARTE_DO_COMPRESSOR := preload("res://assets/fase nitrogenio/compressor de ar.png")
const TELA_DO_COMPRESSOR := preload("res://scripts/laboratorio/compressor.gd")

## O átomo desenhado em cada cartão que tem um (chave -> AtomoCamadas).
var _atomos := {}

@onready var painel: Control = $Painel


func _ao_abrir() -> void:
	painel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	painel.draw.connect(_desenhar)
	for i in ATIVIDADES.size():
		var dados: Dictionary = ATIVIDADES[i]
		registrar_alvo(String(dados["chave"]), retangulo_do_cartao.bind(i), entrar.bind(String(dados["chave"])))
	_criar_o_atomo("monte", ATOMO_DO_MONTE, 168.0)
	_criar_o_atomo("quiz", ATOMO_DO_QUIZ, 168.0)
	focar(String(ATIVIDADES[0]["chave"]))
	_arrumar_os_atomos()


func _a_cada_quadro(_delta: float) -> void:
	_arrumar_os_atomos()
	# As teclas da dica afundam em loop: o painel se redesenha sempre.
	painel.queue_redraw()


func _ao_mudar_o_foco(_foco: String) -> void:
	painel.queue_redraw()


# ─────────────────────────────────────────────────────────────
# AS ATIVIDADES
# ─────────────────────────────────────────────────────────────

## Entra na atividade com esta chave.
func entrar(chave: String) -> void:
	var dados := atividade(chave)
	if not dados.is_empty():
		ir_para(String(dados["cena"]))


static func atividade(chave: String) -> Dictionary:
	for dados: Dictionary in ATIVIDADES:
		if dados["chave"] == chave:
			return dados
	return {}


## Onde fica o cartão número "i": em fileiras de POR_FILEIRA, cada uma
## centrada na tela.
func retangulo_do_cartao(i: int) -> Rect2:
	@warning_ignore("integer_division")
	var fileira := i / POR_FILEIRA
	var nesta := mini(POR_FILEIRA, ATIVIDADES.size() - fileira * POR_FILEIRA)
	var largura := nesta * TAMANHO_DO_CARTAO.x + (nesta - 1) * ENTRE_CARTOES.x
	return Rect2((size.x - largura) * 0.5 + (i % POR_FILEIRA) * (TAMANHO_DO_CARTAO.x + ENTRE_CARTOES.x),
		ALTO + fileira * (TAMANHO_DO_CARTAO.y + ENTRE_CARTOES.y), TAMANHO_DO_CARTAO.x, TAMANHO_DO_CARTAO.y)


## Onde o cartão é desenhado de verdade: ele sobe em foco e afunda no clique.
func _cartao_desenhado(i: int) -> Rect2:
	var chave := String(ATIVIDADES[i]["chave"])
	return PecasDoLaboratorio.caixa_do_botao(retangulo_do_cartao(i), alvo_em_foco() == chave,
		alvo_segurado() == chave)


# ─────────────────────────────────────────────────────────────
# OS ÁTOMOS DOS CARTÕES
# ─────────────────────────────────────────────────────────────

func _criar_o_atomo(chave: String, particulas: Array, lado: float) -> void:
	var atomo := AtomoCamadas.new()
	atomo.name = "Atomo" + chave.capitalize()
	atomo.size = Vector2(lado, lado)
	atomo.margem = 8.0
	atomo.com_letras = false
	atomo.com_legenda_do_nucleo = false
	# No papel: as camadas em tinta e um fio em volta de cada elétron.
	atomo.cor_das_camadas = Color(TINTA, 0.9)
	atomo.cor_do_nucleo = Color(TINTA_TITULO, 0.9)
	atomo.cor_do_fio_do_eletron = TINTA
	painel.add_child(atomo)
	atomo.definir(int(particulas[0]), int(particulas[1]), int(particulas[2]), false)
	_atomos[chave] = atomo


## Cada átomo no meio da figura do cartão dele (que sobe e desce com o foco).
func _arrumar_os_atomos() -> void:
	for i in ATIVIDADES.size():
		var chave := String(ATIVIDADES[i]["chave"])
		var atomo: AtomoCamadas = _atomos.get(chave)
		if atomo == null:
			continue
		var figura := _figura(_cartao_desenhado(i))
		var meio := figura.get_center()
		if chave == "quiz":
			# No quiz o átomo divide a figura com a caixa da pergunta.
			meio.x -= 62.0
		atomo.position = (meio - atomo.size * 0.5).round()


# ─────────────────────────────────────────────────────────────
# DESENHO
# ─────────────────────────────────────────────────────────────

func _figura(cartao: Rect2) -> Rect2:
	return Rect2(cartao.position + Vector2(16, 14), Vector2(cartao.size.x - 32.0, ALTURA_DA_FIGURA - 14.0))


func _desenhar() -> void:
	for i in ATIVIDADES.size():
		var dados: Dictionary = ATIVIDADES[i]
		var chave := String(dados["chave"])
		var cartao := PecasDoLaboratorio.ficha_de_botao(painel, retangulo_do_cartao(i), alvo_em_foco() == chave,
			alvo_segurado() == chave)
		_desenhar_a_figura(chave, _figura(cartao))
		# Um fio de tinta separa a figura do nome.
		painel.draw_rect(Rect2(cartao.position.x + 24.0, cartao.position.y + ALTURA_DA_FIGURA + 6.0,
			cartao.size.x - 48.0, 2.0), TINTA_FRACA)
		# Só o nome, no meio da faixa de baixo: ele e o desenho já dizem o que se
		# faz lá.
		PecasDoLaboratorio.escrever_no_meio(painel,
			Vector2(cartao.get_center().x, cartao.position.y + (ALTURA_DA_FIGURA + 8.0 + cartao.size.y) * 0.5),
			String(dados["nome"]), TAM_NOME, TINTA_TITULO)
	PecasDoLaboratorio.dicas_de_teclado(painel, Vector2(size.x * 0.5, size.y - 40.0),
		[[["tecla_w", "tecla_a", "tecla_s", "tecla_d"], "ESCOLHER"], [["tecla_e"], "ENTRAR"]])


## O desenho de cada cartão, feito da arte do jogo. (Os átomos do "monte" e do
## "quiz" são nós de verdade, que giram: ver _criar_o_atomo.)
func _desenhar_a_figura(chave: String, figura: Rect2) -> void:
	var meio := figura.get_center().round()
	match chave:
		"quiz":
			# A caixa sem elemento, com o ponto de interrogação: a pergunta.
			CaixaElemento.desenhar(painel, meio + Vector2(34, -46), 0, 1, false, false)
		"balanceamento":
			_desenhar_a_reacao(meio)
		"compressor":
			_desenhar_o_compressor(figura)
		"destilador":
			_desenhar_a_coluna(figura)
		"tabela":
			_desenhar_a_tabelinha(meio)


## H₂ + O₂ → H₂O, com as moléculas da folha dos puzzles.
func _desenhar_a_reacao(meio: Vector2) -> void:
	var pecas: Array = ["H2", "+", "O2", "→", "H2O"]
	var escala := 0.8
	var larguras: Array[float] = []
	var total := 0.0
	for peca: String in pecas:
		var largura := 34.0
		if FolhaMoleculas.tem(peca):
			largura = FolhaMoleculas.textura(peca).get_size().x * escala
		larguras.append(largura)
		total += largura + 10.0
	var x := meio.x - (total - 10.0) * 0.5
	for i in pecas.size():
		var peca := String(pecas[i])
		if FolhaMoleculas.tem(peca):
			var textura := FolhaMoleculas.textura(peca)
			var tamanho := textura.get_size() * escala
			painel.draw_texture_rect(textura, Rect2(Vector2(x, meio.y - tamanho.y * 0.5).round(), tamanho.round()), false)
		else:
			PecasDoLaboratorio.escrever_no_meio(painel, Vector2(x + larguras[i] * 0.5, meio.y), peca, 33, TINTA)
		x += larguras[i] + 10.0


## O compressor de ar do mapa (em escala 2, assentado no fio do cartão) e, ao
## lado, as fichas de P, V, n e T.
func _desenhar_o_compressor(figura: Rect2) -> void:
	var tamanho := ARTE_DO_COMPRESSOR.get_size() * 2.0
	var canto := Vector2(figura.get_center().x - tamanho.x * 0.5 - 52.0, figura.end.y + 2.0 - tamanho.y).round()
	painel.draw_texture_rect(ARTE_DO_COMPRESSOR, Rect2(canto, tamanho), false)
	var grade := Vector2(canto.x + tamanho.x + 48.0, figura.get_center().y - 22.0)
	var letras := ["P", "V", "n", "T"]
	for i in letras.size():
		var meio := grade + Vector2((i % 2) * 48.0, floorf(i / 2.0) * 48.0)
		TELA_DO_COMPRESSOR.desenhar_ficha(painel, meio, letras[i], 40.0, 22)


## A coluna de aço da fase do nitrogênio, com três moléculas do ar ao lado.
func _desenhar_a_coluna(figura: Rect2) -> void:
	var arte := ArteDaColuna.ler()
	if arte.textura == null:
		return
	var tamanho := Vector2(arte.recorte_do_aco.size)
	var canto := Vector2(figura.get_center().x - tamanho.x * 0.5 - 40.0, figura.end.y - tamanho.y).round()
	painel.draw_texture_rect_region(arte.textura, Rect2(canto, tamanho), Rect2(arte.recorte_do_aco))
	var x := canto.x + tamanho.x + 46.0
	var y := figura.position.y + 46.0
	for chave: String in ["N2", "Ar", "O2"]:
		MoleculasDoDestilador.desenhar(painel, chave, Vector2(x, y), 0, 2.0)
		y += 50.0


## A tabela periódica em miniatura: um quadradinho por elemento, na cor da
## família dele.
func _desenhar_a_tabelinha(meio: Vector2) -> void:
	var passo := 12.0
	var canto := (meio - Vector2(18.0 * passo, 9.0 * passo + 6.0) * 0.5).round()
	for z in range(1, Elementos.TOTAL + 1):
		var casa := Elementos.casa(z)
		var onde := canto + Vector2(casa) * passo + Vector2(0.0, 6.0 if casa.y >= 7 else 0.0)
		painel.draw_rect(Rect2(onde, Vector2(passo - 1.0, passo - 1.0)), TINTA)
		painel.draw_rect(Rect2(onde + Vector2.ONE, Vector2(passo - 3.0, passo - 3.0)), EstiloHUD.PAPEL)
		painel.draw_rect(Rect2(onde + Vector2.ONE, Vector2(passo - 3.0, passo - 3.0)),
			Color(CaixaElemento.TONS_DAS_FAMILIAS[Elementos.familia(z)] as Color, 0.75))
