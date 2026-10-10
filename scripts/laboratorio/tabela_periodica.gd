extends TelaInterativa

# --- TABELA PERIÓDICA (Laboratório) ---
#
# Os 118 elementos numa folha de papel, cada um na caixa dele: a mesma caixa do
# hidrogênio do caderno da Cacau (moldura de tinta, número atômico, símbolo e
# massa), montada para todos pelo CaixasDosElementos. São estas caixas que o
# "Monte seu átomo" e o quiz usam para mostrar um elemento.
#
# A FOLHA
#   As casas ficam encostadas, dividindo a moldura com a vizinha, como numa
#   tabela impressa. O papel de cada casa leva o tom da família dela (a legenda
#   fica no vão de cima, junto com o título). As casas "57-71" e "89-103"
#   apontam para as duas fileiras de baixo, a dos lantanídios e a dos
#   actinídios.
#   Com o ponteiro (ou o foco das teclas) em cima de uma casa, o vão de cima
#   diz o nome do elemento, o número atômico e a família.
#
# A FICHA
#   Clicar numa casa abre a ficha do elemento: a caixa ampliada com o nome
#   dentro, como na página do caderno, o ÁTOMO desenhado no modelo de camadas
#   (o AtomoCamadas, o mesmo desenho dos puzzles) e o que os números dizem:
#   prótons, nêutrons e elétrons, a distribuição nas camadas, a família, o
#   lugar na tabela e os isótopos que existem na natureza.
#   Com a ficha aberta, ← e → passam para o elemento de antes e o de depois.
#
# De onde vem cada dado: scripts/laboratorio/elementos.gd.
#
# ONDE MEXER:
#   CaixaElemento.TONS_DAS_FAMILIAS   a cor de cada família.
#   CANTO_DA_TABELA, PASSO    onde a tabela fica e o tamanho das casas.
#   scenes/laboratorio/tabela_periodica.tscn
#                             a ficha: onde ficam a caixa grande e o átomo
#                             (nós Ficha/Caixa e Ficha/Atomo).
#
# CONTROLES: mouse (passar e clicar); setas ou WASD levam o foco de casa em
# casa e ENTER, ESPAÇO ou E abrem a ficha; ESC fecha a ficha e, sem ficha,
# volta ao Laboratório. No controle: direcional, ✕ e △.

## A ficha de um elemento abriu (0 = fechou).
signal ficha_mudou(z: int)

const TINTA := Color8(0x3d, 0x2a, 0x22)
const TINTA_TITULO := Color8(0x8e, 0x3b, 0x2c)
const TINTA_FRACA := Color8(0x8a, 0x6d, 0x52)

## O canto de cima à esquerda da primeira casa (a do hidrogênio).
const CANTO_DA_TABELA := Vector2(167, 24)
## De uma casa à seguinte. É a caixa (76 x 92) menos a moldura e a folga dela:
## assim a moldura de uma casa cai em cima da moldura da vizinha.
const PASSO := Vector2(70, 86)
## O espaço entre o 7º período e as duas fileiras de baixo.
const VAO_DAS_FILEIRAS := 14.0
## Quanto a folha de papel passa da tabela, de cada lado.
const MARGEM_DA_FOLHA := 16.0

## O tom que o papel de cada casa ganha, pela família do elemento.
const TONS := CaixaElemento.TONS_DAS_FAMILIAS
## O aro em volta da casa em foco.
const COR_DO_FOCO := Color8(0x8e, 0x3b, 0x2c)

## As duas casas que apontam para as fileiras de baixo: onde ficam (coluna,
## linha), o que dizem e o primeiro elemento da fileira.
const FAIXAS := [
	{"casa": Vector2i(2, 5), "texto": "57-71", "primeiro": 57},
	{"casa": Vector2i(2, 6), "texto": "89-103", "primeiro": 89},
]

const TITULO_DA_FOLHA := "Tabela Periódica"
const TXT_CONVITE := ["Clique num elemento", "para ver o átomo dele."]
const TXT_NUMERO := "número atômico %d"
const TXT_LUGAR := "grupo %d, período %d"
const TXT_LUGAR_EMBAIXO := "período %d, fileira dos %s"
const TXT_PARTICULAS := {"proton": ["próton", "prótons"], "neutron": ["nêutron", "nêutrons"],
	"eletron": ["elétron", "elétrons"]}
const TXT_ISOTOPO_COMUM := "ISÓTOPO MAIS COMUM"
const TXT_ISOTOPO_ESTAVEL := "ISÓTOPO QUE MAIS DURA"
const TXT_SEM_ESTAVEL := "nenhum isótopo estável"
const TXT_UM_ISOTOPO := "todo átomo é %s"
const TXT_VARIOS_ISOTOPOS := "%d isótopos; %s%% é %s"
const TXT_ANTERIOR := "← ANTERIOR"
const TXT_PROXIMO := "PRÓXIMO →"

# ── A ficha (medidas a partir do canto dela) ──
const TAM_TITULO := 44
const TAM_TEXTO := 22
const TAM_MIUDO := 11
## Onde começam as três linhas de partículas, ao lado da caixa grande.
const X_DAS_PARTICULAS := 300.0
const Y_DAS_PARTICULAS := 100.0
const PASSO_DAS_PARTICULAS := 46.0
const LADO_DO_ICONE := 26.0
## As linhas de "nome: valor", embaixo da caixa.
const X_DOS_ROTULOS := 40.0
const X_DOS_VALORES := 208.0
const Y_DAS_LINHAS := 404.0
const PASSO_DAS_LINHAS := 40.0
const BOTAO_ANTERIOR := Rect2(40, 588, 190, 44)
const BOTAO_PROXIMO := Rect2(250, 588, 190, 44)

## O elemento com a ficha aberta (0 = nenhuma).
var na_ficha: int = 0

@onready var folha: Control = $Folha
@onready var veu: ColorRect = $Veu
@onready var ficha: Control = $Ficha
@onready var caixa_grande: CaixaElemento = $Ficha/Caixa
@onready var atomo: AtomoCamadas = $Ficha/Atomo


func _ao_abrir() -> void:
	folha.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	folha.draw.connect(_desenhar_a_folha)
	ficha.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ficha.draw.connect(_desenhar_a_ficha)
	veu.hide()
	ficha.hide()
	for z in range(1, Elementos.TOTAL + 1):
		registrar_alvo(nome_da_casa(z), retangulo_da_casa.bind(z), abrir_ficha.bind(z), _sem_ficha)
	registrar_alvo("anterior", _botao_na_tela.bind(BOTAO_ANTERIOR), passar.bind(-1),
		func() -> bool: return na_ficha > 1)
	registrar_alvo("proximo", _botao_na_tela.bind(BOTAO_PROXIMO), passar.bind(1),
		func() -> bool: return na_ficha > 0 and na_ficha < Elementos.TOTAL)


func _ao_mudar_o_foco(_foco: String) -> void:
	folha.queue_redraw()
	ficha.queue_redraw()


## Com a ficha aberta, os passos são dela: para os lados, o elemento de antes e
## o de depois; para cima e para baixo, nada (o foco da tabela, que está
## coberta, não sai do lugar).
func _ao_dar_passo(direcao: Vector2) -> bool:
	if na_ficha <= 0:
		return false
	if not is_zero_approx(direcao.x):
		passar(signi(roundi(direcao.x)))
	return true


## Com a ficha aberta, ENTER, ESPAÇO, E (✕ no controle) ou um clique fora dela
## a fecham.
func _ao_receber(event: InputEvent) -> bool:
	if na_ficha <= 0:
		return false
	if event.is_action_pressed("ui_accept") or event.is_action_pressed(Interacao.ACAO):
		fechar_ficha()
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and not ficha.get_global_rect().has_point(event.position):
		fechar_ficha()
		return true
	return false


func _ao_pedir_para_voltar() -> void:
	if na_ficha > 0:
		fechar_ficha()
	else:
		voltar()


func dicas_do_controle() -> Array:
	if na_ficha > 0:
		return [["direcional_horizontal", "OUTRO ELEMENTO"], ["cruz", "FECHAR"]]
	return [["direcional", "ESCOLHER"], ["cruz", "VER O ÁTOMO"], ["fechar", "VOLTAR"]]


# ─────────────────────────────────────────────────────────────
# AS CASAS
# ─────────────────────────────────────────────────────────────

static func nome_da_casa(z: int) -> String:
	return "elemento_%d" % z


## O número atômico da casa com este nome de alvo (0 se não é uma casa).
static func elemento_da_casa(nome: String) -> int:
	return int(nome.trim_prefix("elemento_")) if nome.begins_with("elemento_") else 0


## O canto de cima à esquerda da casa (coluna, linha) na tela.
func canto_da_casa(casa: Vector2i) -> Vector2:
	var canto := CANTO_DA_TABELA + Vector2(casa) * PASSO
	if casa.y >= 7:
		canto.y += VAO_DAS_FILEIRAS
	return canto


## Onde a caixa do elemento fica na tela.
func retangulo_da_casa(z: int) -> Rect2:
	return Rect2(canto_da_casa(Elementos.casa(z)), Vector2(CaixasDosElementos.TAMANHO))


## A tabela inteira (da primeira à última casa) e a folha de papel em volta.
func retangulo_da_tabela() -> Rect2:
	var fim := canto_da_casa(Vector2i(17, 8)) + Vector2(CaixasDosElementos.TAMANHO)
	return Rect2(CANTO_DA_TABELA, fim - CANTO_DA_TABELA)


func retangulo_da_folha() -> Rect2:
	return retangulo_da_tabela().grow(MARGEM_DA_FOLHA)


## O elemento em foco na tabela (0 = nenhum).
func elemento_em_foco() -> int:
	return elemento_da_casa(alvo_em_foco())


func _sem_ficha() -> bool:
	return na_ficha <= 0


# ─────────────────────────────────────────────────────────────
# A FICHA
# ─────────────────────────────────────────────────────────────

func abrir_ficha(z: int) -> void:
	if not Elementos.existe(z):
		return
	var ja_estava := na_ficha > 0
	na_ficha = z
	caixa_grande.numero_atomico = z
	atomo.mostrar_elemento(z, ja_estava)
	if not ja_estava:
		tocar("pop")
		veu.show()
		ficha.show()
		veu.modulate.a = 0.0
		ficha.modulate.a = 0.0
		ficha.pivot_offset = ficha.size * 0.5
		ficha.scale = Vector2(0.94, 0.94)
		var entra := novo_tween()
		entra.set_parallel(true)
		entra.tween_property(veu, "modulate:a", 1.0, 0.14)
		entra.tween_property(ficha, "modulate:a", 1.0, 0.14)
		entra.tween_property(ficha, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# O foco da tabela acompanha: fechando a ficha, ele está no elemento visto.
	_em_foco = ""
	folha.queue_redraw()
	ficha.queue_redraw()
	ficha_mudou.emit(z)


func fechar_ficha() -> void:
	if na_ficha <= 0:
		return
	var estava := na_ficha
	na_ficha = 0
	matar_tweens()
	veu.hide()
	ficha.hide()
	tocar("tirar")
	focar(nome_da_casa(estava))
	folha.queue_redraw()
	ficha_mudou.emit(0)


## Com a ficha aberta: o elemento de antes (-1) ou o de depois (+1).
func passar(sentido: int) -> void:
	var destino := na_ficha + signi(sentido)
	if na_ficha <= 0 or not Elementos.existe(destino):
		return
	tocar("passo")
	abrir_ficha(destino)


func _botao_na_tela(botao: Rect2) -> Rect2:
	# Pelo transform da ficha: enquanto ela abre, crescendo, o botão cresce junto.
	return ficha.get_global_transform() * botao


# ─────────────────────────────────────────────────────────────
# O QUE A FICHA DIZ
# ─────────────────────────────────────────────────────────────

## "K 2 · L 4": quantos elétrons em cada camada.
static func texto_das_camadas(z: int) -> String:
	var partes := PackedStringArray()
	var camadas := Elementos.camadas(z)
	for i in camadas.size():
		partes.append("%s %d" % [Elementos.LETRAS_DAS_CAMADAS[i], camadas[i]])
	return " · ".join(partes)


## "grupo 14, período 2" (ou, nas fileiras de baixo, "período 6, fileira dos
## lantanídios").
static func texto_do_lugar(z: int) -> String:
	if Elementos.grupo(z) > 0:
		return TXT_LUGAR % [Elementos.grupo(z), Elementos.periodo(z)]
	return TXT_LUGAR_EMBAIXO % [Elementos.periodo(z), Elementos.nome_da_familia(Elementos.familia(z), true)]


## Quantos isótopos do elemento existem na natureza, e qual é o mais comum.
static func texto_da_natureza(z: int) -> String:
	var naturais: Dictionary = Elementos.ISOTOPOS_NATURAIS.get(z, {})
	var mais_comum := Elementos.nome_do_isotopo(z, Elementos.isotopo(z)).to_lower()
	match naturais.size():
		0:
			return TXT_SEM_ESTAVEL
		1:
			return TXT_UM_ISOTOPO % mais_comum
	return TXT_VARIOS_ISOTOPOS % [naturais.size(),
		Elementos.numero_com_virgula(Elementos.abundancia(z, Elementos.isotopo(z))), mais_comum]


## As linhas "nome: valor" da ficha, na ordem em que aparecem.
static func linhas_da_ficha(z: int) -> Array:
	return [
		["camadas", texto_das_camadas(z)],
		["família", Elementos.nome_da_familia(Elementos.familia(z))],
		["lugar", texto_do_lugar(z)],
		["na natureza", texto_da_natureza(z)],
	]


# ─────────────────────────────────────────────────────────────
# DESENHO DA FOLHA
# ─────────────────────────────────────────────────────────────

func _desenhar_a_folha() -> void:
	EstiloHUD.ficha(folha, retangulo_da_folha())
	_desenhar_o_alto()
	# Primeiro o tom de todas as casas, depois a tinta: a moldura que duas casas
	# dividem fica por cima dos dois tons.
	for z in range(1, Elementos.TOTAL + 1):
		_pintar_o_tom(retangulo_da_casa(z), Elementos.familia(z))
	for faixa: Dictionary in FAIXAS:
		_pintar_o_tom(Rect2(canto_da_casa(faixa["casa"]), Vector2(CaixasDosElementos.TAMANHO)),
			Elementos.familia(int(faixa["primeiro"])))
	for z in range(1, Elementos.TOTAL + 1):
		folha.draw_texture_rect(CaixasDosElementos.textura(z), retangulo_da_casa(z), false)
	for faixa: Dictionary in FAIXAS:
		folha.draw_texture_rect(CaixasDosElementos.textura_da_faixa(String(faixa["texto"])),
			Rect2(canto_da_casa(faixa["casa"]), Vector2(CaixasDosElementos.TAMANHO)), false)

	# A casa em foco por cima de tudo: sombra dura, aro e a caixa de novo.
	var z_do_foco := elemento_em_foco()
	if z_do_foco > 0 and na_ficha <= 0:
		var casa := retangulo_da_casa(z_do_foco).grow(-float(CaixasDosElementos.FOLGA))
		folha.draw_rect(Rect2(casa.position + Vector2(0, 4), casa.size).grow(3.0), EstiloHUD.SOMBRA_DURA)
		folha.draw_rect(casa.grow(3.0), COR_DO_FOCO)
		folha.draw_rect(casa, PecasDoLaboratorio.PAPEL_ACESO)
		folha.draw_rect(casa, Color(TONS[Elementos.familia(z_do_foco)] as Color, 0.3))
		folha.draw_texture_rect(CaixasDosElementos.textura(z_do_foco), retangulo_da_casa(z_do_foco), false)


func _pintar_o_tom(casa: Rect2, familia: Elementos.Familia) -> void:
	folha.draw_rect(casa.grow(-float(CaixasDosElementos.FOLGA)), TONS[familia])


## O vão de cima da tabela: o título, o elemento em foco e a legenda.
func _desenhar_o_alto() -> void:
	var fonte := FONTE
	var tabela := retangulo_da_tabela()
	# O título, sublinhado à mão como os do caderno.
	var largura := PecasDoLaboratorio.largura(TITULO_DA_FOLHA, TAM_TITULO)
	var x := roundf(tabela.get_center().x - largura * 0.5)
	var base := CANTO_DA_TABELA.y + 52.0
	folha.draw_string(fonte, Vector2(x, base), TITULO_DA_FOLHA, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_TITULO,
		TINTA_TITULO)
	folha.draw_rect(Rect2(x, base + 12.0, largura, 2.0), TINTA_TITULO)

	# O elemento em foco (ou o convite), à esquerda do vão.
	var vao := retangulo_do_vao()
	var z := elemento_em_foco()
	if z > 0:
		folha.draw_string(fonte, vao.position + Vector2(0, 30), Elementos.nome(z), HORIZONTAL_ALIGNMENT_LEFT,
			-1, 33, TINTA)
		folha.draw_string(fonte, vao.position + Vector2(0, 66), TXT_NUMERO % z, HORIZONTAL_ALIGNMENT_LEFT, -1,
			TAM_TEXTO, TINTA_FRACA)
		folha.draw_string(fonte, vao.position + Vector2(0, 98), Elementos.nome_da_familia(Elementos.familia(z)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_TEXTO, TINTA_FRACA)
		folha.draw_string(fonte, vao.position + Vector2(0, 130), texto_do_lugar(z), HORIZONTAL_ALIGNMENT_LEFT, -1,
			TAM_TEXTO, TINTA_FRACA)
	else:
		for i in TXT_CONVITE.size():
			folha.draw_string(fonte, vao.position + Vector2(0, 50 + i * 32), String(TXT_CONVITE[i]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_TEXTO, TINTA_FRACA)

	# A legenda das famílias, à direita.
	var legenda := retangulo_da_legenda()
	var y := legenda.position.y
	var familia_em_foco := int(Elementos.familia(z)) if z > 0 else -1
	for chave: int in Elementos.FAMILIAS:
		var familia := chave as Elementos.Familia
		var quadrado := Rect2(legenda.position.x, y, 12, 12)
		folha.draw_rect(quadrado.grow(2.0), TINTA)
		folha.draw_rect(quadrado, EstiloHUD.PAPEL)
		folha.draw_rect(quadrado, TONS[familia])
		folha.draw_string(fonte, Vector2(legenda.position.x + 22.0, y + 10.0),
			Elementos.nome_da_familia(familia, true), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_MIUDO,
			TINTA if familia == familia_em_foco else TINTA_FRACA)
		y += 15.5


## O vão de cima, entre o berílio e o boro: onde o elemento em foco é descrito.
func retangulo_do_vao() -> Rect2:
	var de := canto_da_casa(Vector2i(2, 1)) + Vector2(14, 12)
	var ate := canto_da_casa(Vector2i(12, 3)) - Vector2(6, 8)
	return Rect2(de, Vector2(ate.x - de.x - 250.0, ate.y - de.y))


func retangulo_da_legenda() -> Rect2:
	var vao := retangulo_do_vao()
	return Rect2(vao.end.x + 14.0, vao.position.y - 2.0, 236.0, vao.size.y)


# ─────────────────────────────────────────────────────────────
# DESENHO DA FICHA
# ─────────────────────────────────────────────────────────────

func _desenhar_a_ficha() -> void:
	if na_ficha <= 0:
		return
	var z := na_ficha
	var fonte := FONTE
	var papel := Rect2(Vector2.ZERO, ficha.size)
	EstiloHUD.ficha(ficha, papel)

	# O nome, sublinhado.
	var nome := Elementos.nome(z)
	ficha.draw_string(fonte, Vector2(40, 64), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_TITULO, TINTA_TITULO)
	ficha.draw_rect(Rect2(40, 76, PecasDoLaboratorio.largura(nome, TAM_TITULO), 2), TINTA_TITULO)

	# As partículas, ao lado da caixa.
	var contagem := {"proton": z, "neutron": Elementos.neutrons(z), "eletron": z}
	var y := Y_DAS_PARTICULAS
	for tipo: String in ["proton", "neutron", "eletron"]:
		var lado := LADO_DO_ICONE if tipo != "eletron" else LADO_DO_ICONE * 0.6
		# A miniatura já no tamanho em que vai aparecer na janela.
		var arte := AtomoCamadas.miniatura(tipo,
			roundi(lado * get_viewport().get_final_transform().get_scale().x))
		ficha.draw_texture_rect(arte, Rect2(X_DAS_PARTICULAS + (LADO_DO_ICONE - lado) * 0.5,
			y + (LADO_DO_ICONE - lado) * 0.5, lado, lado), false)
		var quantas := int(contagem[tipo])
		ficha.draw_string(fonte, Vector2(X_DAS_PARTICULAS + LADO_DO_ICONE + 12.0, y + 21.0),
			"%d %s" % [quantas, TXT_PARTICULAS[tipo][0 if quantas == 1 else 1]], HORIZONTAL_ALIGNMENT_LEFT, -1,
			TAM_TEXTO, TINTA)
		y += PASSO_DAS_PARTICULAS
	# De que isótopo são esses nêutrons.
	var estavel := Elementos.ISOTOPOS_NATURAIS.has(z)
	ficha.draw_string(fonte, Vector2(X_DAS_PARTICULAS, y + 22.0),
		TXT_ISOTOPO_COMUM if estavel else TXT_ISOTOPO_ESTAVEL, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_MIUDO,
		TINTA_FRACA)
	ficha.draw_string(fonte, Vector2(X_DAS_PARTICULAS, y + 50.0),
		Elementos.nome_do_isotopo(z, Elementos.isotopo(z)).to_lower(), HORIZONTAL_ALIGNMENT_LEFT, -1,
		TAM_TEXTO, TINTA)

	# As linhas de baixo: nome em tinta fraca, valor em tinta.
	y = Y_DAS_LINHAS
	for linha: Array in linhas_da_ficha(z):
		ficha.draw_string(fonte, Vector2(X_DOS_ROTULOS, y + 18.0), String(linha[0]), HORIZONTAL_ALIGNMENT_LEFT,
			-1, TAM_TEXTO, TINTA_FRACA)
		ficha.draw_string(fonte, Vector2(X_DOS_VALORES, y + 18.0), String(linha[1]), HORIZONTAL_ALIGNMENT_LEFT,
			-1, TAM_TEXTO, TINTA)
		y += PASSO_DAS_LINHAS

	PecasDoLaboratorio.botao(ficha, BOTAO_ANTERIOR, TXT_ANTERIOR, alvo_em_foco() == "anterior",
		alvo_segurado() == "anterior", alvo_disponivel("anterior"))
	PecasDoLaboratorio.botao(ficha, BOTAO_PROXIMO, TXT_PROXIMO, alvo_em_foco() == "proximo",
		alvo_segurado() == "proximo", alvo_disponivel("proximo"))
	# A tecla de fechar, presa na beirada de baixo como nas outras folhas do jogo.
	EstiloHUD.tecla_da_folha(ficha, fonte, papel)


func _a_cada_quadro(_delta: float) -> void:
	# A tecla da beirada da ficha afunda em loop: ela precisa ser redesenhada.
	if na_ficha > 0:
		ficha.queue_redraw()
