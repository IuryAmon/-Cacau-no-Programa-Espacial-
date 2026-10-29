extends TelaInterativa

# --- QUE ÁTOMO É ESSE? (Laboratório) ---
#
# O contrário do "Monte seu átomo": a tela desenha um átomo no modelo de
# camadas (o AtomoCamadas) e a pessoa diz de que elemento ele é, escolhendo uma
# de quatro caixas da tabela periódica.
#
# A resposta sai de contar: o número de prótons do núcleo é o número atômico, e
# é ele que diz o elemento. No átomo neutro dá no mesmo contar os elétrons (um
# para cada próton), e é por aí que as primeiras perguntas se resolvem. As
# últimas tiram esse atalho:
#
#   NEUTRO    o átomo como ele é mais comum na natureza.
#   ISÓTOPO   o mesmo elemento com outro número de nêutrons (carbono-13,
#             oxigênio-18). Uma das caixas erradas é a do elemento que teria
#             aquele tanto de nêutrons: o nêutron não muda o elemento.
#   ÍON       o átomo ganhou ou perdeu elétrons (Na⁺, Cl⁻). Uma das caixas
#             erradas é a do elemento que teria aquele tanto de elétrons: o
#             elétron também não muda o elemento.
#
# São PERGUNTAS perguntas por partida, de átomos cada vez maiores (ver FASES),
# sem repetir elemento. Depois de cada resposta o rodapé explica (quantos prótons o
# núcleo tem, e que elemento é esse); um clique passa para a próxima.
# No fim, o placar.
#
# ONDE MEXER:
#   PERGUNTAS, FASES, IONS   quantas perguntas, de que tamanho e de que tipo.
#   os textos                logo abaixo.
#   scenes/laboratorio/que_atomo_e_esse.tscn   a tela.
#
# CONTROLES: clique na caixa; depois, clique em qualquer lugar (ou ENTER,
# ESPAÇO, E) para continuar; ESC volta. No controle: cursor, ✕ e △.

## Uma pergunta foi respondida.
signal respondeu(certo: bool)

const PERGUNTAS := 10
## De que tamanho e de que tipo são os átomos: até a pergunta "ate", o elemento
## tem no máximo "maior_z" prótons e a pergunta é de um dos "tipos".
const FASES := [
	{"ate": 3, "maior_z": 6, "tipos": ["neutro"]},
	{"ate": 6, "maior_z": 12, "tipos": ["neutro"]},
	{"ate": 8, "maior_z": 20, "tipos": ["neutro", "isotopo"]},
	{"ate": 10, "maior_z": 20, "tipos": ["ion", "isotopo"]},
]
## A carga do íon mais comum de cada elemento (número atômico -> carga).
const IONS := {3: 1, 4: 2, 7: -3, 8: -2, 9: -1, 11: 1, 12: 2, 13: 3, 15: -3, 16: -2, 17: -1, 19: 1, 20: 2}

const TXT_PERGUNTA := "PERGUNTA %d DE %d"
const TXT_ACERTOS := "ACERTOS: %d"
const TXT_DICA := "CONTE OS PRÓTONS DO NÚCLEO: É O NÚMERO DELES QUE DIZ QUAL É O ELEMENTO"
const TXT_DICA_NEUTRO := "ÁTOMO NEUTRO: TEM UM ELÉTRON PARA CADA PRÓTON. CONTE E DESCUBRA O ELEMENTO"
const TXT_DICA_ION := "ESTE É UM ÍON: OS ELÉTRONS NÃO BATEM COM OS PRÓTONS. CONTE OS PRÓTONS"
const TXT_CERTO := "CERTO! %d %s: %s"
const TXT_ERRADO := "NÃO É %s. O NÚCLEO TEM %d %s: É %s"
const TXT_CONTINUAR := "CLIQUE PARA CONTINUAR"
const TXT_VER_PLACAR := "CLIQUE PARA VER O PLACAR"
const TXT_PLACAR := "%d DE %d"
## O que a tela diz no fim, pelo tanto de acertos (do pior para o melhor).
const TXT_FINAIS := [
	[0, "CONTE OS PRÓTONS COM CALMA E TENTE DE NOVO"],
	[4, "BOM COMEÇO! MAIS UMA RODADA?"],
	[7, "MUITO BEM! VOCÊ JÁ RECONHECE OS ÁTOMOS"],
	[10, "PERFEITO! NENHUM ÁTOMO ESCAPOU"],
]

enum Estado { PERGUNTANDO, RESPONDIDA, FIM }

var estado: Estado = Estado.PERGUNTANDO
## A pergunta da vez, de 1 a PERGUNTAS.
var numero: int = 0
var acertos: int = 0
## O átomo da vez: {"z", "neutrons", "eletrons", "tipo"}.
var atual: Dictionary = {}
## Os quatro elementos oferecidos, na ordem das caixas.
var opcoes: Array[int] = []
## A caixa escolhida (-1 = nenhuma ainda).
var escolhida: int = -1

var _sorteio := RandomNumberGenerator.new()
## Os elementos que já saíram nesta partida.
var _ja_sairam: Array[int] = []
var _tempo: float = 0.0

@onready var painel: PainelDaAtividade = $Painel
@onready var grupo_jogo: Control = $Painel/Display/Conteudo/GrupoJogo
@onready var atomo: AtomoCamadas = $Painel/Display/Conteudo/GrupoJogo/Atomo
@onready var placar: Label = $Painel/Display/Conteudo/GrupoJogo/Placar
@onready var continuar: Label = $Painel/Display/Conteudo/GrupoJogo/Continuar
@onready var grupo_fim: Control = $Painel/Display/Conteudo/GrupoFim
@onready var placar_final: Label = $Painel/Display/Conteudo/GrupoFim/Placar
@onready var mensagem_final: Label = $Painel/Display/Conteudo/GrupoFim/Mensagem
@onready var botao_de_novo: Panel = $Painel/Display/Conteudo/GrupoFim/BotaoDeNovo
@onready var botao_sair: Panel = $Painel/Display/Conteudo/GrupoFim/BotaoSair
## As quatro caixas das alternativas.
@onready var caixas: Array[CaixaElemento] = [
	$Painel/Display/Conteudo/GrupoJogo/Opcoes/Opcao1 as CaixaElemento,
	$Painel/Display/Conteudo/GrupoJogo/Opcoes/Opcao2 as CaixaElemento,
	$Painel/Display/Conteudo/GrupoJogo/Opcoes/Opcao3 as CaixaElemento,
	$Painel/Display/Conteudo/GrupoJogo/Opcoes/Opcao4 as CaixaElemento,
]


func _ao_abrir() -> void:
	_sorteio.randomize()
	for i in caixas.size():
		caixas[i].set_meta("pos_base", caixas[i].position)
		registrar_alvo("opcao_%d" % (i + 1), caixas[i].get_global_rect, responder.bind(i),
			func() -> bool: return estado == Estado.PERGUNTANDO)
	registrar_alvo("de_novo", botao_de_novo.get_global_rect, recomecar,
		func() -> bool: return estado == Estado.FIM)
	registrar_alvo("sair", botao_sair.get_global_rect, voltar,
		func() -> bool: return estado == Estado.FIM)
	# Respondida, o clique em qualquer lugar da área da atividade continua.
	registrar_alvo("continuar", painel.retangulo_do_conteudo, avancar,
		func() -> bool: return estado == Estado.RESPONDIDA)
	painel.aparecer()
	recomecar()


func _a_cada_quadro(delta: float) -> void:
	_tempo += delta
	# O "clique para continuar" pisca devagar.
	continuar.modulate.a = 1.0 if fmod(_tempo, 1.0) < 0.6 else 0.35


## ENTER, ESPAÇO ou E continuam. Só as TECLAS: o ✕ do controle está na mesma
## ação, mas ele já é o clique do cursor (que continua pelo alvo "continuar").
## Valendo aqui também, o mesmo toque passaria a pergunta e responderia a
## seguinte com a caixa que estivesse debaixo do cursor.
func _ao_receber(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	if event.is_action_pressed("ui_accept") or event.is_action_pressed(Interacao.ACAO):
		if estado == Estado.RESPONDIDA:
			avancar()
			return true
		if estado == Estado.FIM:
			recomecar()
			return true
	return false


func _ao_mudar_o_foco(_foco: String) -> void:
	_pintar_as_caixas()
	botao_de_novo.self_modulate = Color(1.35, 1.35, 1.35) if alvo_em_foco() == "de_novo" else Color.WHITE
	botao_sair.self_modulate = Color(1.35, 1.35, 1.35) if alvo_em_foco() == "sair" else Color.WHITE


func dicas_do_controle() -> Array:
	match estado:
		Estado.RESPONDIDA:
			return [["cruz", "CONTINUAR"], ["fechar", "VOLTAR"]]
		Estado.FIM:
			return [["cruz", "ESCOLHER"], ["fechar", "VOLTAR"]]
	return super.dicas_do_controle()


# ─────────────────────────────────────────────────────────────
# A PARTIDA
# ─────────────────────────────────────────────────────────────

## Começa uma partida nova, do zero.
func recomecar() -> void:
	numero = 0
	acertos = 0
	_ja_sairam.clear()
	grupo_fim.hide()
	grupo_jogo.show()
	_proxima()


## Depois de respondida: a próxima pergunta, ou o placar.
func avancar() -> void:
	if estado != Estado.RESPONDIDA:
		return
	tocar("passo")
	if numero >= PERGUNTAS:
		_mostrar_o_fim()
	else:
		_proxima()


func _proxima() -> void:
	numero += 1
	atual = sortear(numero)
	_ja_sairam.append(int(atual["z"]))
	opcoes = alternativas(atual)
	_perguntar()


## Põe na tela uma pergunta escolhida de fora (os testes usam para saber o que
## está sendo perguntado). "novas_opcoes" são os quatro elementos das caixas.
func perguntar(atomo_pedido: Dictionary, novas_opcoes: Array[int]) -> void:
	atual = atomo_pedido
	opcoes = novas_opcoes
	_perguntar()


func _perguntar() -> void:
	estado = Estado.PERGUNTANDO
	escolhida = -1
	matar_tweens()
	for i in caixas.size():
		caixas[i].numero_atomico = opcoes[i]
		caixas[i].position = caixas[i].get_meta("pos_base", caixas[i].position)
		caixas[i].scale = Vector2.ONE
	_pintar_as_caixas()
	atomo.definir(int(atual["z"]), int(atual["neutrons"]), int(atual["eletrons"]))
	continuar.hide()
	painel.definir_cabecalho(TXT_PERGUNTA % [numero, PERGUNTAS])
	placar.text = TXT_ACERTOS % acertos
	painel.definir_rodape(dica_da_pergunta())


## O que o rodapé diz enquanto espera a resposta.
func dica_da_pergunta() -> String:
	match String(atual.get("tipo", "neutro")):
		"ion":
			return TXT_DICA_ION
		"neutro":
			return TXT_DICA_NEUTRO
	return TXT_DICA


## A pessoa escolheu a caixa "qual" (0 a 3).
func responder(qual: int) -> void:
	if estado != Estado.PERGUNTANDO or qual < 0 or qual >= opcoes.size():
		return
	estado = Estado.RESPONDIDA
	escolhida = qual
	var z := int(atual["z"])
	var certo := opcoes[qual] == z
	var palavra := "PRÓTON" if z == 1 else "PRÓTONS"
	if certo:
		acertos += 1
		tocar("certo")
		painel.avisar(TXT_CERTO % [z, palavra, Elementos.nome(z).to_upper()],
			PainelDaAtividade.COR_CERTO, -1.0)
		_pular(caixas[qual])
	else:
		tocar("erro")
		painel.avisar(TXT_ERRADO % [Elementos.nome(opcoes[qual]).to_upper(), z, palavra,
			Elementos.nome(z).to_upper()], PainelDaAtividade.COR_ERRO, -1.0)
		_tremer(caixas[qual])
	placar.text = TXT_ACERTOS % acertos
	continuar.text = TXT_VER_PLACAR if numero >= PERGUNTAS else TXT_CONTINUAR
	continuar.show()
	_pintar_as_caixas()
	respondeu.emit(certo)


func _mostrar_o_fim() -> void:
	estado = Estado.FIM
	grupo_jogo.hide()
	grupo_fim.show()
	placar_final.text = TXT_PLACAR % [acertos, PERGUNTAS]
	mensagem_final.text = mensagem_do_fim(acertos)
	painel.definir_cabecalho("FIM DA PARTIDA")
	painel.definir_rodape("ESCOLHA: OUTRA PARTIDA OU VOLTAR AO LABORATÓRIO")
	tocar("sucesso")


## O que a tela diz com este tanto de acertos.
static func mensagem_do_fim(quantos: int) -> String:
	var texto := String(TXT_FINAIS[0][1])
	for faixa: Array in TXT_FINAIS:
		if quantos >= int(faixa[0]):
			texto = String(faixa[1])
	return texto


# ─────────────────────────────────────────────────────────────
# O SORTEIO
# ─────────────────────────────────────────────────────────────

## A fase em que a pergunta "qual" (de 1 em diante) cai.
static func fase_da_pergunta(qual: int) -> Dictionary:
	for fase: Dictionary in FASES:
		if qual <= int(fase["ate"]):
			return fase
	return FASES[FASES.size() - 1]


## Um átomo para a pergunta "qual": {"z", "neutrons", "eletrons", "tipo"}.
func sortear(qual: int) -> Dictionary:
	var fase := fase_da_pergunta(qual)
	var tipos: Array = fase["tipos"]
	var tipo := String(tipos[_sorteio.randi_range(0, tipos.size() - 1)])
	# Só os elementos que servem ao tipo e ainda não saíram.
	var candidatos: Array[int] = []
	for z in range(1, int(fase["maior_z"]) + 1):
		if z in _ja_sairam:
			continue
		if tipo == "ion" and not IONS.has(z):
			continue
		if tipo == "isotopo" and outros_isotopos(z).is_empty():
			continue
		candidatos.append(z)
	if candidatos.is_empty():
		# Acabaram os elementos para esse tipo: um neutro qualquer que não saiu.
		tipo = "neutro"
		for z in range(1, int(fase["maior_z"]) + 1):
			if not z in _ja_sairam:
				candidatos.append(z)
	if candidatos.is_empty():
		candidatos.append(_sorteio.randi_range(1, int(fase["maior_z"])))
	return montar_atomo(candidatos[_sorteio.randi_range(0, candidatos.size() - 1)], tipo)


## O átomo do elemento "z" para uma pergunta deste tipo.
func montar_atomo(z: int, tipo: String) -> Dictionary:
	var neutrons := Elementos.neutrons(z)
	var eletrons := z
	match tipo:
		"isotopo":
			var outros := outros_isotopos(z)
			if outros.is_empty():
				tipo = "neutro"
			else:
				neutrons = outros[_sorteio.randi_range(0, outros.size() - 1)] - z
		"ion":
			if IONS.has(z):
				eletrons = z - int(IONS[z])
			else:
				tipo = "neutro"
	return {"z": z, "neutrons": neutrons, "eletrons": eletrons, "tipo": tipo}


## Os números de massa dos outros isótopos do elemento que existem na natureza
## (sem o mais comum).
static func outros_isotopos(z: int) -> Array[int]:
	var lista: Array[int] = []
	var naturais: Dictionary = Elementos.ISOTOPOS_NATURAIS.get(z, {})
	for massa: int in naturais:
		if massa != Elementos.isotopo(z):
			lista.append(massa)
	return lista


## As quatro caixas: a certa e três erradas, embaralhadas. As erradas saem,
## primeiro, das contas trocadas (o elemento que teria aquele tanto de elétrons,
## de nêutrons ou de partículas no núcleo) e, depois, dos vizinhos de número
## atômico.
func alternativas(atomo_da_vez: Dictionary) -> Array[int]:
	var z := int(atomo_da_vez["z"])
	var erradas: Array[int] = []
	var tentar := func(candidato: int) -> void:
		if Elementos.existe(candidato) and candidato != z and not candidato in erradas and erradas.size() < 3:
			erradas.append(candidato)
	tentar.call(int(atomo_da_vez["eletrons"]))
	tentar.call(int(atomo_da_vez["neutrons"]))
	tentar.call(z + int(atomo_da_vez["neutrons"]))
	var vizinhos: Array[int] = [z + 1, z - 1, z + 2, z - 2, z + 3, z - 3, z + 4, z + 5]
	# A ordem dos dois vizinhos mais próximos troca de vez em quando, para a
	# certa não ser sempre "a do meio".
	if _sorteio.randf() < 0.5:
		vizinhos[0] = z - 1
		vizinhos[1] = z + 1
	for vizinho in vizinhos:
		tentar.call(vizinho)
	var todas: Array[int] = [z]
	todas.append_array(erradas)
	for i in range(todas.size() - 1, 0, -1):
		var j := _sorteio.randi_range(0, i)
		var troca := todas[i]
		todas[i] = todas[j]
		todas[j] = troca
	return todas


# ─────────────────────────────────────────────────────────────
# AS CAIXAS
# ─────────────────────────────────────────────────────────────

## Em foco, a caixa ganha um aro claro; respondida a pergunta, a certa fica
## verde, a escolhida errada vermelha e as outras se apagam.
func _pintar_as_caixas() -> void:
	for i in caixas.size():
		var caixa := caixas[i]
		caixa.apagada = false
		caixa.destaque = Color(0, 0, 0, 0)
		if estado == Estado.PERGUNTANDO:
			if alvo_em_foco() == "opcao_%d" % (i + 1):
				caixa.destaque = EstiloHUD.CLARO
		elif opcoes[i] == int(atual["z"]):
			caixa.destaque = PainelDaAtividade.COR_CERTO
		elif i == escolhida:
			caixa.destaque = PainelDaAtividade.COR_ERRO
		else:
			caixa.apagada = true


func _pular(caixa: Control) -> void:
	caixa.pivot_offset = caixa.size * 0.5
	var tween := novo_tween()
	tween.tween_property(caixa, "scale", Vector2(1.1, 1.1), 0.09) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(caixa, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _tremer(caixa: Control) -> void:
	var origem: Vector2 = caixa.get_meta("pos_base", caixa.position)
	var tween := novo_tween()
	tween.set_trans(Tween.TRANS_SINE)
	for desvio: float in [6.0, -6.0, 5.0, -5.0, 0.0]:
		tween.tween_property(caixa, "position", origem + Vector2(desvio, 0.0), 0.045)
