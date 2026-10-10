extends TelaInterativa

# --- BALANCEAMENTO DE EQUAÇÕES (Laboratório) ---
#
# O puzzle do foguete e o do maçarico, soltos da história e com muitas reações.
# A regra é a mesma: as setas sobem e descem o coeficiente de cada substância
# até os átomos de cada elemento baterem dos dois lados, e o botão confere. O
# que muda de um NÍVEL para o outro é quanta ajuda a tela dá:
#
#   FÁCIL     igual aos puzzles da história: as moléculas aparecem conforme o
#             coeficiente (scenes/ui/termo_equacao.tscn) e a tela conta os
#             átomos dos reagentes e dos produtos, que ficam verdes quando
#             batem.
#   MÉDIO     as moléculas aparecem, mas a contagem não: quem conta é a pessoa,
#             e nada na tela muda de cor antes de confirmar.
#   DIFÍCIL   sem moléculas: só a equação escrita, com as setas em cada
#             coeficiente (scenes/ui/seletor_coeficiente.tscn).
#
# As reações de cada nível estão em scripts/laboratorio/equacoes_do_laboratorio.gd
# e a conta (quantos átomos há em cada fórmula) em equacao_quimica.gd.
#
# VALE QUALQUER RESPOSTA BALANCEADA, como no puzzle do maçarico: com os
# coeficientes em dobro a equação passa do mesmo jeito, e o terminal mostra a
# forma mais simples. Errando, ele diz que elemento não bate.
#
# Um nível é uma fila de equações. Resolvida uma, entra a seguinte; "PULAR"
# passa adiante sem resolver. No fim, o terminal diz quantas foram balanceadas
# e quantas confirmações saíram erradas.
#
# ONDE MEXER:
#   COEF_MAX e os textos   logo abaixo.
#   scenes/laboratorio/balanceamento.tscn   a tela: posições, letras, cores.
#   scenes/ui/termo_equacao.tscn            a coluna de cada substância.
#
# CONTROLES: mouse nas setas e nos botões; ENTER confirma; ESC volta à escolha
# do nível e, de lá, ao Laboratório. No controle: cursor, ✕ e △.

## Uma equação foi balanceada (a posição dela no nível, de 0 em diante).
signal equacao_resolvida(indice: int)
## A fila do nível acabou.
signal nivel_concluido

const TERMO := preload("res://scenes/ui/termo_equacao.tscn")
const SELETOR := preload("res://scenes/ui/seletor_coeficiente.tscn")

## Até quanto cada coeficiente vai. Passando, volta a zero (como nos puzzles).
const COEF_MAX := 9

const TXT_CABECALHO := "%s: EQUAÇÃO %d DE %d"
const TXT_ESCOLHA := "EM TODOS OS NÍVEIS VALE QUALQUER RESPOSTA BALANCEADA"
const TXT_INSTRUCAO := "BALANCEIE: %s"
const TXT_QUANTAS := "%d EQUAÇÕES"
const TXT_FALTA_DEFINIR := "DEFINA TODOS OS COEFICIENTES"
const TXT_UM_ELEMENTO := "ELEMENTO %s DESBALANCEADO"
const TXT_VARIOS_ELEMENTOS := "ELEMENTOS %s E %s DESBALANCEADOS"
const TXT_BALANCEADA := "BALANCEADA!"
const TXT_FORMA_SIMPLES := "BALANCEADA! FORMA MAIS SIMPLES: %s"
const TXT_PULADA := "A RESPOSTA ERA: %s"
const TXT_FIM := "NÍVEL %s CONCLUÍDO"
const TXT_RESUMO := "%d DE %d EQUAÇÕES BALANCEADAS"
const TXT_ERROS := "CONFIRMAÇÕES ERRADAS: %d"
const TXT_RODAPE_DO_FIM := "ESCOLHA OUTRO NÍVEL OU VOLTE AO LABORATÓRIO"

# ── Montagem da linha de termos (px do vidro) ──
const LARGURA_MAIS := 40.0
const LARGURA_SETA := 64.0
## A letra da equação escrita no alto (níveis com moléculas): encolhe se não couber.
const FONTE_EQUACAO := 30
const FONTE_EQUACAO_MIN := 18
## A letra da equação do nível difícil, que é a tela inteira.
const FONTE_ESCRITA := 33
const FONTE_ESCRITA_MIN := 22
## A altura de uma fileira do nível difícil (a do seletor de coeficiente).
const ALTURA_DA_FILEIRA := 110.0
const FOLGA_DA_FORMULA := 4.0
## No nível difícil: a altura (no vidro) em que a escrita pode começar e o vão
## entre uma fileira e a outra, quando a equação precisa de duas.
const ALTO_DA_ESCRITA := 64.0
const ENTRE_FILEIRAS := 50.0

const COR_AMARELO := ComputadorDoLaboratorio.COR_AMARELO
const COR_CERTO := ComputadorDoLaboratorio.COR_CERTO
const COR_ERRO := ComputadorDoLaboratorio.COR_ERRO
const COR_TEXTO := ComputadorDoLaboratorio.COR_TEXTO

enum Estado { ESCOLHA, RESOLVENDO, PASSANDO, FIM }

var estado: Estado = Estado.ESCOLHA
var nivel: EquacoesDoLaboratorio.Nivel = EquacoesDoLaboratorio.Nivel.FACIL
## A equação da vez na fila do nível (de 0 em diante).
var indice: int = 0
var coeficientes: Array[int] = []
var tocado: Array[bool] = []
## Neste nível: quantas equações foram balanceadas e quantas confirmações
## saíram erradas.
var resolvidas: int = 0
var erros: int = 0

# Cada equação montada é uma sessão: a corrotina que acorda em outra desiste.
var _sessao: int = 0
var _termos: Array[TermoEquacao] = []
var _seletores: Array[SeletorCoeficiente] = []
var _largura_do_termo: float = 110.0

@onready var computador: ComputadorDoLaboratorio = $Computador
@onready var grupo_escolha: Control = $Computador/Display/Conteudo/GrupoEscolha
@onready var grupo_equacao: Control = $Computador/Display/Conteudo/GrupoEquacao
@onready var linha_equacao: HBoxContainer = $Computador/Display/Conteudo/GrupoEquacao/LinhaEquacao
@onready var reagentes_titulo: Label = $Computador/Display/Conteudo/GrupoEquacao/LabelReagentesTitulo
@onready var reagentes_valor: RichTextLabel = $Computador/Display/Conteudo/GrupoEquacao/LabelReagentesValor
@onready var produtos_titulo: Label = $Computador/Display/Conteudo/GrupoEquacao/LabelProdutosTitulo
@onready var produtos_valor: RichTextLabel = $Computador/Display/Conteudo/GrupoEquacao/LabelProdutosValor
@onready var termos: Control = $Computador/Display/Conteudo/GrupoEquacao/Termos
@onready var botao_confirmar: Panel = $Computador/Display/Conteudo/GrupoEquacao/BotaoConfirmar
@onready var botao_pular: Panel = $Computador/Display/Conteudo/GrupoEquacao/BotaoPular
@onready var grupo_fim: Control = $Computador/Display/Conteudo/GrupoFim
@onready var titulo_do_fim: Label = $Computador/Display/Conteudo/GrupoFim/Titulo
@onready var resumo_do_fim: Label = $Computador/Display/Conteudo/GrupoFim/Resumo
@onready var erros_do_fim: Label = $Computador/Display/Conteudo/GrupoFim/Erros
@onready var botao_outro_nivel: Panel = $Computador/Display/Conteudo/GrupoFim/BotaoOutroNivel
@onready var botao_sair: Panel = $Computador/Display/Conteudo/GrupoFim/BotaoSair
## O botão de cada nível, na tela de escolha.
@onready var botoes_de_nivel := {
	EquacoesDoLaboratorio.Nivel.FACIL: $Computador/Display/Conteudo/GrupoEscolha/BotaoFacil as Panel,
	EquacoesDoLaboratorio.Nivel.MEDIO: $Computador/Display/Conteudo/GrupoEscolha/BotaoMedio as Panel,
	EquacoesDoLaboratorio.Nivel.DIFICIL: $Computador/Display/Conteudo/GrupoEscolha/BotaoDificil as Panel,
}


func _ao_abrir() -> void:
	var modelo := TERMO.instantiate() as Control
	_largura_do_termo = modelo.custom_minimum_size.x
	modelo.free()
	for chave: int in botoes_de_nivel:
		var qual := chave as EquacoesDoLaboratorio.Nivel
		var botao: Panel = botoes_de_nivel[qual]
		(botao.get_node("Nome") as Label).text = EquacoesDoLaboratorio.NOMES[qual]
		(botao.get_node("Descricao") as Label).text = EquacoesDoLaboratorio.DESCRICOES[qual]
		(botao.get_node("Quantas") as Label).text = TXT_QUANTAS % EquacoesDoLaboratorio.do_nivel(qual).size()
		registrar_alvo(nome_do_nivel(qual), botao.get_global_rect, escolher_nivel.bind(qual),
			func() -> bool: return estado == Estado.ESCOLHA)
	registrar_alvo("confirmar", botao_confirmar.get_global_rect, confirmar, _pode_mexer)
	registrar_alvo("pular", botao_pular.get_global_rect, pular, _pode_mexer)
	registrar_alvo("outro_nivel", botao_outro_nivel.get_global_rect, mostrar_escolha,
		func() -> bool: return estado == Estado.FIM)
	registrar_alvo("sair", botao_sair.get_global_rect, voltar,
		func() -> bool: return estado == Estado.FIM)
	for no: Control in [grupo_equacao, botao_confirmar]:
		no.set_meta("pos_base", no.position)
	computador.ligar()
	mostrar_escolha()


func _ao_receber(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_ENTER, KEY_KP_ENTER] and _pode_mexer():
		confirmar()
		return true
	return false


## ESC no meio de um nível volta à escolha do nível; na escolha, ao Laboratório.
func _ao_pedir_para_voltar() -> void:
	if estado == Estado.ESCOLHA:
		voltar()
	else:
		tocar("tirar")
		mostrar_escolha()


func _ao_mudar_o_foco(_foco: String) -> void:
	var aceso := Color(1.35, 1.35, 1.35)
	for chave: int in botoes_de_nivel:
		var botao: Panel = botoes_de_nivel[chave]
		botao.self_modulate = aceso if alvo_em_foco() == nome_do_nivel(chave as EquacoesDoLaboratorio.Nivel) \
			else Color.WHITE
	botao_confirmar.self_modulate = aceso if alvo_em_foco() == "confirmar" else Color.WHITE
	botao_pular.self_modulate = aceso if alvo_em_foco() == "pular" else Color.WHITE
	botao_outro_nivel.self_modulate = aceso if alvo_em_foco() == "outro_nivel" else Color.WHITE
	botao_sair.self_modulate = aceso if alvo_em_foco() == "sair" else Color.WHITE


func dicas_do_controle() -> Array:
	if estado == Estado.ESCOLHA or estado == Estado.FIM:
		return [["analogico_esquerdo", "MOVER"], ["cruz", "ESCOLHER"], ["fechar", "VOLTAR"]]
	return [["analogico_esquerdo", "MOVER"], ["direcional", "ESCOLHER"], ["cruz", "APERTAR"],
		["fechar", "NÍVEIS"]]


static func nome_do_nivel(qual: EquacoesDoLaboratorio.Nivel) -> String:
	return "nivel_" + String(EquacoesDoLaboratorio.CHAVES[qual])


# ─────────────────────────────────────────────────────────────
# OS NÍVEIS
# ─────────────────────────────────────────────────────────────

## A tela de escolha do nível.
func mostrar_escolha() -> void:
	_sessao += 1
	matar_tweens()
	estado = Estado.ESCOLHA
	_esvaziar_os_termos()
	grupo_equacao.hide()
	grupo_fim.hide()
	grupo_escolha.show()
	computador.definir_cabecalho("BALANCEAMENTO DE EQUAÇÕES")
	computador.definir_rodape(TXT_ESCOLHA)
	computador.definir_led(ComputadorDoLaboratorio.COR_LED_PARADO, true)


## Começa a fila de equações de um nível.
func escolher_nivel(qual: EquacoesDoLaboratorio.Nivel) -> void:
	nivel = qual
	indice = 0
	resolvidas = 0
	erros = 0
	tocar("botao")
	grupo_escolha.hide()
	grupo_fim.hide()
	grupo_equacao.show()
	_montar_equacao()


## As equações do nível em jogo.
func fila() -> Array:
	return EquacoesDoLaboratorio.do_nivel(nivel)


## A equação da vez ({"nome", "reagentes", "produtos", "resposta"}).
func equacao() -> Dictionary:
	return fila()[indice]


func formulas() -> Array:
	return equacao()["reagentes"] + equacao()["produtos"]


func _pode_mexer() -> bool:
	return estado == Estado.RESOLVENDO


func _mostrar_o_fim() -> void:
	_sessao += 1
	estado = Estado.FIM
	_esvaziar_os_termos()
	grupo_equacao.hide()
	grupo_fim.show()
	titulo_do_fim.text = TXT_FIM % EquacoesDoLaboratorio.NOMES[nivel]
	resumo_do_fim.text = TXT_RESUMO % [resolvidas, fila().size()]
	erros_do_fim.text = TXT_ERROS % erros
	computador.definir_cabecalho("FIM DO NÍVEL")
	computador.definir_rodape(TXT_RODAPE_DO_FIM)
	computador.definir_led(ComputadorDoLaboratorio.COR_LED_AZUL)
	tocar("sucesso")
	nivel_concluido.emit()


# ─────────────────────────────────────────────────────────────
# MONTAGEM DE UMA EQUAÇÃO
# ─────────────────────────────────────────────────────────────

func _montar_equacao() -> void:
	_sessao += 1
	matar_tweens()
	estado = Estado.RESOLVENDO
	var todas := formulas()
	coeficientes.clear()
	tocado.clear()
	for i in todas.size():
		coeficientes.append(0)
		tocado.append(false)
	_esvaziar_os_termos()

	grupo_equacao.modulate = Color.WHITE
	grupo_equacao.scale = Vector2.ONE
	grupo_equacao.position = grupo_equacao.get_meta("pos_base", Vector2.ZERO)
	botao_confirmar.position = botao_confirmar.get_meta("pos_base", botao_confirmar.position)

	var com_moleculas := EquacoesDoLaboratorio.com_moleculas(nivel)
	var com_contagem := EquacoesDoLaboratorio.com_contagem(nivel)
	linha_equacao.visible = com_moleculas
	for no: Control in [reagentes_titulo, produtos_titulo]:
		no.visible = com_moleculas
		no.add_theme_color_override("font_color", COR_AMARELO if com_contagem else COR_TEXTO)
	for no: Control in [reagentes_valor, produtos_valor]:
		no.visible = com_contagem
	if com_moleculas:
		_montar_com_moleculas()
	else:
		_montar_escrita()

	for i in todas.size():
		registrar_alvo("mais_%d" % i, _retangulo_da_seta.bind(i, 1), alterar.bind(i, 1), _pode_mexer)
		registrar_alvo("menos_%d" % i, _retangulo_da_seta.bind(i, -1), alterar.bind(i, -1), _pode_mexer)

	computador.definir_cabecalho(TXT_CABECALHO % [EquacoesDoLaboratorio.NOMES[nivel], indice + 1, fila().size()])
	computador.definir_rodape(TXT_INSTRUCAO % equacao()["nome"])
	computador.definir_led(ComputadorDoLaboratorio.COR_LED_PARADO, true)
	_atualizar()


func _esvaziar_os_termos() -> void:
	esquecer_alvos("mais_")
	esquecer_alvos("menos_")
	for filho in termos.get_children():
		filho.free()
	_termos.clear()
	_seletores.clear()


## Fácil e médio: uma coluna por substância, com as setas e as moléculas, como
## nos puzzles da história.
func _montar_com_moleculas() -> void:
	var reagentes: Array = equacao()["reagentes"]
	var todas := formulas()
	var pecas: Array = []
	for i in todas.size():
		if i > 0:
			pecas.append("->" if i == reagentes.size() else "+")
		pecas.append(todas[i])
	var total := 0.0
	for peca: String in pecas:
		total += _largura_da_peca(peca)
	var x := (termos.size.x - total) * 0.5
	var inicio_dos_reagentes := x
	var fim_dos_reagentes := x
	var inicio_dos_produtos := x
	for peca: String in pecas:
		var largura := _largura_da_peca(peca)
		if peca == "+" or peca == "->":
			if peca == "->":
				fim_dos_reagentes = x
				inicio_dos_produtos = x + largura
			termos.add_child(_criar_operador(peca, Rect2(x, 0, largura, termos.size.y), 33))
		else:
			var termo := TERMO.instantiate() as TermoEquacao
			termo.formula = peca
			termo.encolher_para_caber = true
			termo.position = Vector2(x, 0)
			termos.add_child(termo)
			termo.molecula_apareceu.connect(tocar.bind("pop"))
			_termos.append(termo)
		x += largura
	# "Reagentes" e "Produtos" centrados em cima dos termos de cada lado.
	_centralizar(reagentes_titulo, reagentes_valor, inicio_dos_reagentes, fim_dos_reagentes)
	_centralizar(produtos_titulo, produtos_valor, inicio_dos_produtos, x)


func _largura_da_peca(peca: String) -> float:
	match peca:
		"+":
			return LARGURA_MAIS
		"->":
			return LARGURA_SETA
	return _largura_do_termo


func _centralizar(titulo_do_lado: Label, valor: RichTextLabel, de: float, ate: float) -> void:
	var centro := termos.position.x + (de + ate) * 0.5
	var largura := maxf(ate - de + 60.0, 300.0)
	for no: Control in [titulo_do_lado, valor]:
		no.position.x = centro - largura * 0.5
		no.size.x = largura


## Difícil: a equação escrita, grande, com um seletor em cada coeficiente. Se
## não couber numa fileira só, os reagentes vão em cima (com a seta no fim) e
## os produtos embaixo.
func _montar_escrita() -> void:
	var reagentes: Array = equacao()["reagentes"]
	var produtos: Array = equacao()["produtos"]
	var limite := termos.size.x - 24.0
	var fileiras: Array = [reagentes + ["->"] + produtos]
	var tamanho := FONTE_ESCRITA
	if _largura_da_fileira(fileiras[0], tamanho) > limite:
		fileiras = [reagentes + ["->"], produtos]
	while tamanho > FONTE_ESCRITA_MIN and _mais_larga(fileiras, tamanho) > limite:
		tamanho -= 11
	# Sem a equação do alto nem a contagem, a escrita tem o vidro quase inteiro:
	# as fileiras se espalham do alto dele até o botão, e não só no retângulo
	# dos termos (as setas de uma fileira não encostam nas da outra).
	var alto := ALTO_DA_ESCRITA - termos.position.y
	var espaco := termos.size.y - alto
	var passo := ALTURA_DA_FILEIRA + ENTRE_FILEIRAS
	var y := alto + (espaco - ALTURA_DA_FILEIRA - passo * (fileiras.size() - 1)) * 0.5
	for fileira: Array in fileiras:
		var x := (termos.size.x - _largura_da_fileira(fileira, tamanho)) * 0.5
		for i in fileira.size():
			var peca := String(fileira[i])
			if peca == "->":
				termos.add_child(_criar_operador(peca, Rect2(x, y, LARGURA_SETA, ALTURA_DA_FILEIRA), tamanho))
				x += LARGURA_SETA
				continue
			if i > 0 and String(fileira[i - 1]) != "->":
				termos.add_child(_criar_operador("+", Rect2(x, y, LARGURA_MAIS, ALTURA_DA_FILEIRA), tamanho))
				x += LARGURA_MAIS
			var seletor := SELETOR.instantiate() as SeletorCoeficiente
			seletor.position = Vector2(x, y)
			termos.add_child(seletor)
			_seletores.append(seletor)
			x += seletor.custom_minimum_size.x + FOLGA_DA_FORMULA
			# A fórmula numa caixa da altura da letra, no meio da fileira: os
			# índices se apoiam no pé dela, e não no pé da fileira.
			var altura := ceilf(FONTE.get_height(tamanho)) + 4.0
			var escrita := HBoxContainer.new()
			escrita.add_theme_constant_override("separation", 0)
			escrita.mouse_filter = Control.MOUSE_FILTER_IGNORE
			escrita.position = Vector2(x, roundf(y + (ALTURA_DA_FILEIRA - altura) * 0.5))
			escrita.size = Vector2(_largura_da_formula(peca, tamanho), altura)
			termos.add_child(escrita)
			for pedaco: Array in EquacaoQuimica.pedacos(peca):
				_por_texto(escrita, pedaco[0], pedaco[1], COR_TEXTO, tamanho)
			x += escrita.size.x
		y += passo


## A largura de uma fileira do nível difícil com esta letra.
func _largura_da_fileira(fileira: Array, tamanho: int) -> float:
	var largura := 0.0
	for i in fileira.size():
		var peca := String(fileira[i])
		if peca == "->":
			largura += LARGURA_SETA
			continue
		if i > 0 and String(fileira[i - 1]) != "->":
			largura += LARGURA_MAIS
		largura += 60.0 + FOLGA_DA_FORMULA + _largura_da_formula(peca, tamanho)
	return largura


func _mais_larga(fileiras: Array, tamanho: int) -> float:
	var maior := 0.0
	for fileira: Array in fileiras:
		maior = maxf(maior, _largura_da_fileira(fileira, tamanho))
	return maior


func _largura_da_formula(formula: String, tamanho: int) -> float:
	var largura := 0.0
	for pedaco: Array in EquacaoQuimica.pedacos(formula):
		largura += _medir(pedaco[0], tamanho_do_indice(tamanho) if pedaco[1] else tamanho)
	return largura


func _criar_operador(texto: String, onde: Rect2, tamanho: int) -> Label:
	var rotulo := Label.new()
	rotulo.text = "→" if texto == "->" else texto
	rotulo.add_theme_font_override("font", FONTE)
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", Color.WHITE)
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.position = onde.position
	rotulo.size = onde.size
	return rotulo


## Onde está a seta do termo "i" na tela (a de cima, +1, ou a de baixo, -1).
func _retangulo_da_seta(i: int, sentido: int) -> Rect2:
	if i < _termos.size():
		return _termos[i].retangulo_do_botao(sentido)
	if i < _seletores.size():
		return _seletores[i].retangulo_do_botao(sentido)
	return Rect2()


# ─────────────────────────────────────────────────────────────
# COEFICIENTES E CONTAGEM
# ─────────────────────────────────────────────────────────────

## A seta do termo "i": a de cima (+1) soma um ao coeficiente, a de baixo (-1)
## tira. Passando de COEF_MAX volta a zero, e abaixo de zero vai a COEF_MAX.
func alterar(i: int, sentido: int) -> void:
	if not _pode_mexer() or i < 0 or i >= coeficientes.size():
		return
	var novo := coeficientes[i] + signi(sentido)
	if novo > COEF_MAX:
		novo = 0
	elif novo < 0:
		novo = COEF_MAX
	coeficientes[i] = novo
	tocado[i] = true
	if i < _termos.size():
		_termos[i].animar_seta(sentido)
		_dar_tranco(sentido, _termos[i])
		_termos[i].mostrar_quantidade(novo)
	elif i < _seletores.size():
		_seletores[i].animar_seta(sentido)
		tocar("passo")
	# Mexeu de novo: o aviso de erro de antes já não vale.
	computador.voltar_rodape()
	_atualizar()


## Põe os coeficientes de uma vez (os testes e o "pular").
func definir_coeficientes(valores: Array) -> void:
	for i in mini(valores.size(), coeficientes.size()):
		coeficientes[i] = clampi(int(valores[i]), 0, COEF_MAX)
		tocado[i] = true
		if i < _termos.size():
			_termos[i].mostrar_quantidade(coeficientes[i], false)
	_atualizar()


func esta_balanceada() -> bool:
	return EquacaoQuimica.balanceada(equacao()["reagentes"], equacao()["produtos"], coeficientes)


func _todos_definidos() -> bool:
	return tocado.all(func(t: bool) -> bool: return t)


func _atualizar() -> void:
	var reagentes: Array = equacao()["reagentes"]
	var produtos: Array = equacao()["produtos"]
	var todas := formulas()
	var com_contagem := EquacoesDoLaboratorio.com_contagem(nivel)

	# A cor de tudo: só o nível fácil avisa, antes de confirmar, se bateu.
	var cor_geral := COR_AMARELO
	if com_contagem and _todos_definidos():
		cor_geral = COR_CERTO if esta_balanceada() else COR_ERRO

	if com_contagem:
		var dos_reagentes := EquacaoQuimica.contar(reagentes, coeficientes.slice(0, reagentes.size()))
		var dos_produtos := EquacaoQuimica.contar(produtos, coeficientes.slice(reagentes.size()))
		var textos_dos_reagentes := PackedStringArray()
		var textos_dos_produtos := PackedStringArray()
		for elemento in EquacaoQuimica.elementos(todas):
			var de_um := _lado_definido(elemento, 0, reagentes.size())
			var de_outro := _lado_definido(elemento, reagentes.size(), todas.size())
			var bate: bool = de_um and de_outro \
				and int(dos_reagentes.get(elemento, 0)) == int(dos_produtos.get(elemento, 0))
			var cor := COR_CERTO if bate else COR_AMARELO
			textos_dos_reagentes.append(_contagem_colorida(elemento,
				str(int(dos_reagentes.get(elemento, 0))) if de_um else "?", cor))
			textos_dos_produtos.append(_contagem_colorida(elemento,
				str(int(dos_produtos.get(elemento, 0))) if de_outro else "?", cor))
		reagentes_valor.text = "   ".join(textos_dos_reagentes)
		produtos_valor.text = "   ".join(textos_dos_produtos)
		reagentes_titulo.add_theme_color_override("font_color", cor_geral)
		produtos_titulo.add_theme_color_override("font_color", cor_geral)

	if EquacoesDoLaboratorio.com_moleculas(nivel):
		# A equação escrita no alto, que encolhe até caber na largura da tela.
		for filho in linha_equacao.get_children():
			filho.free()
		var textos := textos_dos_coeficientes()
		var tamanho := FONTE_EQUACAO
		while tamanho > FONTE_EQUACAO_MIN and _largura_da_equacao(textos, tamanho) > linha_equacao.size.x - 20.0:
			tamanho -= 2
		_escrever_equacao(linha_equacao, textos, cor_geral, tamanho)
	else:
		for i in _seletores.size():
			_seletores[i].numero.text = str(coeficientes[i]) if tocado[i] else "?"


## O coeficiente de cada termo como se escreve: o número, ou "?" enquanto a
## pessoa não mexeu nele.
func textos_dos_coeficientes() -> PackedStringArray:
	var textos := PackedStringArray()
	for i in coeficientes.size():
		textos.append(str(coeficientes[i]) if tocado[i] else "?")
	return textos


## O lado só tem contagem para o elemento quando todo termo dele que contém
## esse elemento já teve o coeficiente escolhido.
func _lado_definido(elemento: String, de: int, ate: int) -> bool:
	var todas := formulas()
	for i in range(de, ate):
		if EquacaoQuimica.composicao(String(todas[i])).has(elemento) and not tocado[i]:
			return false
	return true


func _contagem_colorida(elemento: String, valor: String, cor: Color) -> String:
	return "[color=#%s]%s = %s[/color]" % [cor.to_html(false), elemento, valor]


# ─────────────────────────────────────────────────────────────
# EQUAÇÃO ESCRITA
# ─────────────────────────────────────────────────────────────

## Escreve "c₁ R₁ + c₂ R₂ → c₃ P₁ + ..." com os índices em subscrito de verdade
## (menores e rebaixados).
func _escrever_equacao(onde: Control, textos: PackedStringArray, cor: Color, tamanho: int) -> void:
	var reagentes: Array = equacao()["reagentes"]
	var todas := formulas()
	for i in todas.size():
		if i == reagentes.size():
			_por_texto(onde, "   →   ", false, cor, tamanho)
		elif i > 0:
			_por_texto(onde, "  +  ", false, cor, tamanho)
		_por_texto(onde, textos[i] + " ", false, cor, tamanho)
		for pedaco: Array in EquacaoQuimica.pedacos(String(todas[i])):
			_por_texto(onde, pedaco[0], pedaco[1], cor, tamanho)


func _largura_da_equacao(textos: PackedStringArray, tamanho: int) -> float:
	var reagentes: Array = equacao()["reagentes"]
	var todas := formulas()
	var largura := 0.0
	for i in todas.size():
		if i == reagentes.size():
			largura += _medir("   →   ", tamanho)
		elif i > 0:
			largura += _medir("  +  ", tamanho)
		largura += _medir(textos[i] + " ", tamanho) + _largura_da_formula(String(todas[i]), tamanho)
	return largura


func _medir(texto: String, tamanho: int) -> float:
	return FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x


## O tamanho da letra dos índices de uma fórmula escrita na letra "tamanho".
static func tamanho_do_indice(tamanho: int) -> int:
	return maxi(8, roundi(tamanho * 0.36))


func _por_texto(onde: Control, texto: String, indice_da_formula: bool, cor: Color, tamanho: int) -> void:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_override("font", FONTE)
	rotulo.add_theme_font_size_override("font_size", tamanho_do_indice(tamanho) if indice_da_formula else tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.size_flags_vertical = Control.SIZE_SHRINK_END if indice_da_formula else Control.SIZE_SHRINK_CENTER
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	onde.add_child(rotulo)


# ─────────────────────────────────────────────────────────────
# CONFERIR A RESPOSTA
# ─────────────────────────────────────────────────────────────

func confirmar() -> void:
	if not _pode_mexer():
		return
	if not _todos_definidos() or coeficientes.has(0):
		_errar(TXT_FALTA_DEFINIR, botao_confirmar)
		return
	if not esta_balanceada():
		var fora := EquacaoQuimica.desbalanceados(equacao()["reagentes"], equacao()["produtos"], coeficientes)
		var texto := TXT_UM_ELEMENTO % fora[0]
		if fora.size() > 1:
			texto = TXT_VARIOS_ELEMENTOS % [", ".join(PackedStringArray(fora.slice(0, -1))), fora[-1]]
		erros += 1
		_errar(texto, grupo_equacao)
		return
	# Todos os átomos batem: qualquer combinação assim é uma resposta certa.
	_concluir()


func _errar(texto: String, tremer: Control) -> void:
	tocar("erro")
	computador.avisar(texto, COR_ERRO, 2.6)
	var origem: Vector2 = tremer.get_meta("pos_base", tremer.position)
	var tween := novo_tween()
	tween.set_trans(Tween.TRANS_SINE)
	for desvio: float in [6.0, -6.0, 5.0, -5.0, 0.0]:
		tween.tween_property(tremer, "position", origem + Vector2(desvio, 0.0), 0.045)


func _concluir() -> void:
	estado = Estado.PASSANDO
	var sessao := _sessao
	resolvidas += 1
	tocar("sucesso")
	computador.definir_led(ComputadorDoLaboratorio.COR_LED_CERTO)
	_pintar_de_certo()
	# Certa, mas dava para simplificar: passa do mesmo jeito, e o rodapé mostra
	# a forma mais simples (com um pouco mais de tempo na tela para ler).
	var simples := EquacaoQuimica.forma_mais_simples(coeficientes)
	var tem_dica := simples != coeficientes
	if tem_dica:
		computador.avisar(TXT_FORMA_SIMPLES % _numeros_ligados(simples), COR_CERTO, -1.0)
	else:
		computador.avisar(TXT_BALANCEADA, COR_CERTO, -1.0)
	equacao_resolvida.emit(indice)
	await get_tree().create_timer(2.8 if tem_dica else 1.6).timeout
	if sessao != _sessao:
		return
	_seguir_adiante()


## Passa para a próxima equação sem resolver esta (e mostra a resposta dela).
func pular() -> void:
	if not _pode_mexer():
		return
	estado = Estado.PASSANDO
	var sessao := _sessao
	tocar("tirar")
	definir_coeficientes(equacao()["resposta"])
	computador.avisar(TXT_PULADA % _numeros_ligados(equacao()["resposta"]), COR_AMARELO, -1.0)
	await get_tree().create_timer(1.8).timeout
	if sessao != _sessao:
		return
	_seguir_adiante()


func _seguir_adiante() -> void:
	if indice + 1 >= fila().size():
		_mostrar_o_fim()
		return
	indice += 1
	_montar_equacao()
	# A equação nova entra com um "pulo", como a segunda etapa do maçarico.
	grupo_equacao.pivot_offset = grupo_equacao.size * 0.5
	grupo_equacao.scale = Vector2(0.8, 0.8)
	grupo_equacao.modulate.a = 0.0
	var entra := novo_tween()
	entra.set_parallel(true)
	entra.tween_property(grupo_equacao, "modulate:a", 1.0, 0.2)
	entra.tween_property(grupo_equacao, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tocar("passo")


## Balanceada: a equação fica verde (em qualquer nível).
func _pintar_de_certo() -> void:
	if EquacoesDoLaboratorio.com_moleculas(nivel):
		for filho in linha_equacao.get_children():
			filho.free()
		var textos := textos_dos_coeficientes()
		var tamanho := FONTE_EQUACAO
		while tamanho > FONTE_EQUACAO_MIN and _largura_da_equacao(textos, tamanho) > linha_equacao.size.x - 20.0:
			tamanho -= 2
		_escrever_equacao(linha_equacao, textos, COR_CERTO, tamanho)
		reagentes_titulo.add_theme_color_override("font_color", COR_CERTO)
		produtos_titulo.add_theme_color_override("font_color", COR_CERTO)
		return
	for filho in termos.get_children():
		if filho is Label:
			filho.add_theme_color_override("font_color", COR_CERTO)
		elif filho is HBoxContainer:
			for letra: Label in filho.get_children():
				letra.add_theme_color_override("font_color", COR_CERTO)
	for seletor in _seletores:
		seletor.numero.add_theme_color_override("font_color", COR_CERTO)


static func _numeros_ligados(valores: Array) -> String:
	var numeros := PackedStringArray()
	for valor in valores:
		numeros.append(str(int(valor)))
	return "-".join(numeros)


## A seta clicada dá um "tranco" nas moléculas do termo, na direção do clique.
func _dar_tranco(sentido: int, termo: Control) -> void:
	var monte: Control = termo.get_node("Moleculas")
	if not monte.has_meta("y_base"):
		monte.set_meta("y_base", monte.position.y)
	var base: float = monte.get_meta("y_base")
	var tween := novo_tween()
	tween.tween_property(monte, "position:y", base - 4.0 * sentido, 0.06) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(monte, "position:y", base, 0.18) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
