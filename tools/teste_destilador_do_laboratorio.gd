extends "res://tools/teste_de_tela.gd"

# Teste do simulador de destilação do Laboratório: as misturas
# (scripts/laboratorio/misturas_do_destilador.gd), a coluna
# (scripts/ui/coluna_do_simulador.gd), o termômetro (scripts/ui/termometro.gd)
# e a tela (scenes/laboratorio/destilador.tscn).
#
# A simulação é conferida passo a passo (avancar(1/60)), sem depender da
# velocidade da máquina: o mesmo teste dá sempre o mesmo resultado.
#
#   * OS DADOS: os pontos de ebulição são os de verdade (arredondados para o
#     grau); toda mistura tem substâncias que existem, com pontos de ebulição
#     diferentes, e um termômetro que alcança a separação; as temperaturas se
#     escrevem com vírgula só quando precisam (-0,5 °C);
#   * A COLUNA: começa com tudo líquido no fundo, na temperatura mínima; a
#     temperatura vai atrás do que foi pedido, sem pulo; os andares ficam cada
#     vez mais frios para cima, e o topo é o resfriador;
#   * A DESTILAÇÃO de cada uma das seis misturas, na temperatura certa: cada
#     substância acaba inteira no andar em que a conta manda (o primeiro que
#     está no ponto de ebulição dela ou abaixo), nenhuma molécula se perde e
#     nenhuma sai da coluna;
#   * o que não condensa nem no topo fica gás lá em cima (o neônio, o butano
#     do petróleo), e o que não ferve fica no fundo (o sal);
#   * esquentar demais mistura de novo duas substâncias no mesmo andar, e
#     esfriar não desfaz: só recomeçando;
#   * O TERMÔMETRO: a altura de cada temperatura e a volta (do ponto para os
#     graus) batem; as marcas são os pontos de ebulição da mistura;
#   * A TELA: as seis misturas na lista, as fichas das substâncias, as setas,
#     as teclas ↑ e ↓, o arrasto do ponteiro, RECOMEÇAR, o aviso MISTURA
#     SEPARADA; todo texto existe na fonte e cabe no lugar;
#   * de controle, mover o cursor não muda a temperatura; o ✕ nas setas muda;
#     segurando o ✕ no termômetro, o ponteiro vai com o cursor;
#   * ESC volta ao menu do Laboratório.
#
#   godot --headless --path . res://tools/teste_destilador_do_laboratorio.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma imagem de cada
# mistura separada.

const CENA := "res://scenes/laboratorio/destilador.tscn"
const PASSO := 1.0 / 60.0
const L := ColunaDoSimulador.LIQUIDO
const G := ColunaDoSimulador.GAS

## Os pontos de ebulição de verdade, a 1 atm (NIST Chemistry WebBook e CRC
## Handbook), para conferir os arredondados da lista.
const EBULICAO_DE_VERDADE := {
	"N2": -195.8, "O2": -183.0, "Ar": -185.8, "Ne": -246.0, "Kr": -153.4, "Xe": -108.1,
	"CH4": -161.5, "C2H6": -88.6, "C3H8": -42.1, "C4H10": -0.5, "C8H18": 125.6, "C12H26": 216.3, "C16H34": 286.9,
	"C2H6O": 78.4, "H2O": 100.0, "NaCl": 1465.0,
}

## Para cada mistura: a temperatura do fundo que a separa e onde cada
## substância tem de acabar (andar, fase). É a conta do topo de
## coluna_do_simulador.gd, feita à mão.
const SEPARACOES := {
	# Fundo a -183: andares a -183, -186,25, -189,5, -192,75 e -196.
	"ar": {"fundo": -183.0, "onde": {"O2": Vector2i(0, L), "Ar": Vector2i(1, L), "N2": Vector2i(4, L)}},
	# Fundo a -110: -110, -131,5, -153, -174,5 e -196. O neônio (-246) não condensa.
	"gases_nobres": {"fundo": -110.0,
		"onde": {"Xe": Vector2i(0, L), "Kr": Vector2i(2, L), "Ar": Vector2i(4, L), "Ne": Vector2i(4, G)}},
	# Fundo a -2: -2, -42, -82, -122 e -162.
	"gas_natural": {"fundo": -2.0,
		"onde": {"C4H10": Vector2i(0, L), "C3H8": Vector2i(1, L), "C2H6": Vector2i(3, L), "CH4": Vector2i(4, L)}},
	# Fundo a 280: 280, 216,25, 152,5, 88,75 e 25. O butano (-0,5) não condensa.
	"petroleo": {"fundo": 280.0,
		"onde": {"C16H34": Vector2i(0, L), "C12H26": Vector2i(2, L), "C8H18": Vector2i(3, L), "C4H10": Vector2i(4, G)}},
	# Fundo a 90: 90, 72,5, 55, 37,5 e 20.
	"cana": {"fundo": 90.0, "onde": {"H2O": Vector2i(0, L), "C2H6O": Vector2i(1, L)}},
	# Fundo a 110: 110, 87,5, 65, 42,5 e 20.
	"mar": {"fundo": 110.0, "onde": {"NaCl": Vector2i(0, L), "H2O": Vector2i(1, L)}},
}


func _ready() -> void:
	await _comecar()
	_testar_os_dados()
	await _testar_a_coluna()
	await _testar_as_separacoes()
	await _testar_o_calor_demais()
	await _testar_o_termometro()
	await _testar_a_tela()
	await _testar_os_comandos()
	await _testar_a_separacao_na_tela()
	await _testar_o_controle()
	await _testar_a_saida()
	_terminar()


# ─────────────────────────────────────────────────────────────
# APOIO
# ─────────────────────────────────────────────────────────────

## Uma coluna solta, que só anda quando o teste manda.
func _nova_coluna(chave: String) -> ColunaDoSimulador:
	var coluna := ColunaDoSimulador.new()
	add_child(coluna)
	coluna.set_process(false)
	coluna.definir_mistura(MisturasDoDestilador.mistura(chave))
	return coluna


## Anda a simulação até a condição valer (ou até o limite, em segundos do
## jogo). Devolve quanto tempo de jogo passou, ou -1 se não chegou.
func _andar_ate(coluna: ColunaDoSimulador, condicao: Callable, limite: float = 90.0) -> float:
	var tempo := 0.0
	while tempo < limite:
		if condicao.call():
			return tempo
		coluna.avancar(PASSO)
		tempo += PASSO
	return tempo if condicao.call() else -1.0


func _andar(coluna: ColunaDoSimulador, segundos: float) -> void:
	for i in roundi(segundos / PASSO):
		coluna.avancar(PASSO)


## Onde cada substância da mistura está, numa linha (para a mensagem do teste).
func _retrato(coluna: ColunaDoSimulador) -> String:
	var partes := PackedStringArray()
	for chave: String in coluna.mistura()["substancias"]:
		partes.append("%s: %s" % [chave, coluna.onde_esta(chave)])
	return "; ".join(partes)


## A conta do topo de coluna_do_simulador.gd, refeita aqui: o andar em que a
## substância fica com o fundo nesta temperatura, e em que fase.
func _lugar_pela_conta(coluna: ColunaDoSimulador, chave: String, fundo: float) -> Vector2i:
	var ebulicao := MisturasDoDestilador.ebulicao(chave)
	if ebulicao >= fundo:
		return Vector2i(0, L)
	for andar in range(1, coluna.andares()):
		if coluna.temperatura_do_andar_com(andar, fundo) <= ebulicao:
			return Vector2i(andar, L)
	return Vector2i(coluna.andares() - 1, G)


# ─────────────────────────────────────────────────────────────
# OS DADOS
# ─────────────────────────────────────────────────────────────

func _testar_os_dados() -> void:
	print("\n--- AS MISTURAS E AS SUBSTÂNCIAS ---")
	var longe := PackedStringArray()
	for chave: String in MisturasDoDestilador.SUBSTANCIAS:
		if not EBULICAO_DE_VERDADE.has(chave):
			longe.append("%s sem valor de referência" % chave)
		elif absf(MisturasDoDestilador.ebulicao(chave) - float(EBULICAO_DE_VERDADE[chave])) > 0.5:
			longe.append("%s: %s (de verdade %s)" % [chave, MisturasDoDestilador.ebulicao(chave), EBULICAO_DE_VERDADE[chave]])
	_checar(longe.is_empty(), "os %d pontos de ebulição são os de verdade, arredondados para o grau %s" \
		% [MisturasDoDestilador.SUBSTANCIAS.size(), longe])
	_checar(MisturasDoDestilador.ebulicao("N2") == -196.0 and MisturasDoDestilador.ebulicao("Ar") == -186.0 \
		and MisturasDoDestilador.ebulicao("O2") == -183.0, "os do ar são os da coluna da história: -196, -186 e -183")
	_checar(MisturasDoDestilador.graus(-196.0) == "-196 °C" and MisturasDoDestilador.graus(78.0) == "78 °C" \
		and MisturasDoDestilador.graus(-0.5) == "-0,5 °C" and MisturasDoDestilador.graus(1465.0) == "1465 °C" \
		and MisturasDoDestilador.graus(0.0) == "0 °C", "as temperaturas por escrito: -196 °C, 78 °C, -0,5 °C, 1465 °C")

	var problemas := PackedStringArray()
	var textos: Array = []
	var chaves := {}
	for dados: Dictionary in MisturasDoDestilador.MISTURAS:
		var chave := String(dados["chave"])
		var nome := String(dados["nome"])
		textos.append_array([nome, dados["nota"], dados["calor"]])
		if chaves.has(chave):
			problemas.append("%s: chave repetida" % chave)
		chaves[chave] = true
		if MisturasDoDestilador.mistura(chave) != dados:
			problemas.append("%s: mistura() não acha" % chave)
		var minima := float(dados["minima"])
		var maxima := float(dados["maxima"])
		var resfriador := float(dados["resfriador"])
		if minima >= maxima or resfriador < minima or resfriador > maxima:
			problemas.append("%s: escala do termômetro" % nome)
		var substancias: Dictionary = dados["substancias"]
		if substancias.size() < 2:
			problemas.append("%s: menos de duas substâncias" % nome)
		var pontos := {}
		var fervem := 0
		for substancia: String in substancias:
			if not MisturasDoDestilador.SUBSTANCIAS.has(substancia):
				problemas.append("%s: %s não existe" % [nome, substancia])
				continue
			if int(substancias[substancia]) < 3:
				problemas.append("%s: pouco %s para se ver" % [nome, substancia])
			var ebulicao := MisturasDoDestilador.ebulicao(substancia)
			if pontos.has(ebulicao):
				problemas.append("%s: dois pontos de ebulição iguais" % nome)
			pontos[ebulicao] = true
			if ebulicao < maxima:
				fervem += 1
		# Dá para separar: tudo menos (no máximo) uma ferve dentro da escala.
		if fervem < substancias.size() - 1:
			problemas.append("%s: o termômetro não alcança a separação" % nome)
		var em_ordem := MisturasDoDestilador.em_ordem_de_ebulicao(dados)
		for i in range(1, em_ordem.size()):
			if MisturasDoDestilador.ebulicao(em_ordem[i - 1]) >= MisturasDoDestilador.ebulicao(em_ordem[i]):
				problemas.append("%s: fora de ordem" % nome)
		if em_ordem.size() != substancias.size():
			problemas.append("%s: ordem incompleta" % nome)
		if not SEPARACOES.has(chave):
			problemas.append("%s: o teste não sabe separá-la" % nome)
	_checar(problemas.is_empty(), "as %d misturas: substâncias que existem, pontos de ebulição diferentes, termômetro que alcança %s" \
		% [MisturasDoDestilador.MISTURAS.size(), problemas])
	_checar(MisturasDoDestilador.MISTURAS.size() >= 6 and MisturasDoDestilador.mistura("ar")["nome"] == "AR LÍQUIDO" \
		and MisturasDoDestilador.mistura("nada").is_empty(), "são seis, a começar pelo ar líquido da história")

	var sem_desenho := PackedStringArray()
	for chave: String in MisturasDoDestilador.SUBSTANCIAS:
		var dados: Dictionary = MisturasDoDestilador.SUBSTANCIAS[chave]
		textos.append_array([dados["nome"], dados["formula"], MisturasDoDestilador.graus(float(dados["ebulicao"]))])
		if MisturasDoDestilador.substancia(chave) != dados or String(dados["formula"]) != chave:
			sem_desenho.append("%s: dados" % chave)
		var textura := MoleculasDoDestilador.textura(chave)
		var celula := MoleculasDoDestilador.celula(chave)
		if textura == null or celula.x <= 0 or celula.y <= 0 or MoleculasDoDestilador.largura_deitada(chave) <= 0.0:
			sem_desenho.append(chave)
		elif textura.get_width() != celula.x * MoleculasDoDestilador.QUADROS:
			sem_desenho.append("%s: tira de %d px para %d quadros de %d" % [chave, textura.get_width(),
				MoleculasDoDestilador.QUADROS, celula.x])
		if (dados["cores"] as Array).size() != 3 or not dados.has("liquido") or not dados.has("tona"):
			sem_desenho.append("%s: cores" % chave)
	_checar(sem_desenho.is_empty(), "toda substância tem molécula desenhada (uma tira de quadros) e cores %s" % [sem_desenho])
	var sem_dono := PackedStringArray()
	for chave: String in MisturasDoDestilador.APELIDOS:
		textos.append(MisturasDoDestilador.APELIDOS[chave])
		if not MisturasDoDestilador.SUBSTANCIAS.has(chave):
			sem_dono.append(chave)
	_checar(sem_dono.is_empty() and MisturasDoDestilador.APELIDOS["C8H18"] == "gasolina", "os apelidos são de substâncias que existem %s" % [sem_dono])
	_checar(_letras_que_faltam(textos).is_empty(), "toda letra dos nomes, das fórmulas e das notas existe na fonte [%s]" \
		% _letras_que_faltam(textos))


# ─────────────────────────────────────────────────────────────
# A COLUNA
# ─────────────────────────────────────────────────────────────

func _testar_a_coluna() -> void:
	print("\n--- A COLUNA ---")
	var coluna := _nova_coluna("ar")
	await _quadros(1)
	var dados := MisturasDoDestilador.mistura("ar")
	_checar(coluna.andares() == 5, "a coluna tem cinco andares: o fundo e as quatro bandejas")
	_checar(coluna.size == coluna.tamanho_da_coluna() and coluna.size.x > 200.0, "o nó toma o tamanho da arte ampliada %s" % coluna.size)
	_checar(coluna.total_de_moleculas() == 9 + 4 + 6 and coluna.quantas_em(ColunaDoSimulador.Estado.LIQUIDA) == 19,
		"começa com as 19 moléculas do ar líquidas")
	_checar(coluna.lugar_de("N2") == Vector2i(0, L) and coluna.lugar_de("Ar") == Vector2i(0, L) and coluna.lugar_de("O2") == Vector2i(0, L),
		"todas no fundo")
	_checar(coluna.situacao_de("N2") == "LÍQUIDO NO FUNDO" and coluna.situacao_de("nada") == "", "a ficha diz LÍQUIDO NO FUNDO")
	_checar(not coluna.separada() and coluna.substancia_do_andar(0) == "", "misturadas: a mistura não está separada")
	_checar(coluna.temperatura() == -200.0 and coluna.temperatura_pedida() == -200.0, "na temperatura mínima do termômetro (-200)")
	var iguais := true
	for andar in coluna.andares():
		if not is_equal_approx(coluna.temperatura_do_andar(andar), -200.0):
			iguais = false
	_checar(iguais and coluna.temperatura_do_topo() == -200.0,
		"com o fundo mais frio que o resfriador, a coluna inteira está na temperatura do fundo")
	_andar(coluna, 3.0)
	_checar(coluna.quantas_em(ColunaDoSimulador.Estado.LIQUIDA) == 19 and coluna.temperatura() == -200.0,
		"sem mexer no termômetro, nada acontece")

	# O termômetro pede; a temperatura vai atrás.
	coluna.pedir_temperatura(999.0)
	_checar(coluna.temperatura_pedida() == float(dados["maxima"]), "o pedido é preso à escala (máximo -170)")
	coluna.pedir_temperatura(-999.0)
	_checar(coluna.temperatura_pedida() == float(dados["minima"]), "e ao mínimo (-200)")
	coluna.pedir_temperatura(-170.0)
	_checar(coluna.temperatura() == -200.0, "pedir não muda a temperatura na hora")
	_andar(coluna, ColunaDoSimulador.TEMPO_DE_PONTA_A_PONTA * 0.5)
	_checar(absf(coluna.temperatura() - (-185.0)) < 0.3, "na metade do tempo, metade do caminho (%.1f)" % coluna.temperatura())
	_andar(coluna, ColunaDoSimulador.TEMPO_DE_PONTA_A_PONTA * 0.5 + 0.1)
	_checar(coluna.temperatura() == -170.0, "em %.1f s o fundo vai de uma ponta à outra do termômetro" \
		% ColunaDoSimulador.TEMPO_DE_PONTA_A_PONTA)
	var descendo := true
	for andar in range(1, coluna.andares()):
		if coluna.temperatura_do_andar(andar) >= coluna.temperatura_do_andar(andar - 1):
			descendo = false
	_checar(descendo and is_equal_approx(coluna.temperatura_do_andar(4), -196.0) and is_equal_approx(coluna.temperatura_do_andar(0), -170.0),
		"cada andar mais frio que o de baixo: do fundo (-170) ao resfriador (-196)")
	_checar(is_equal_approx(coluna.temperatura_do_andar(2), -183.0) and is_equal_approx(coluna.temperatura_do_andar_com(1, -183.0), -186.25),
		"os do meio repartem por igual (o do meio a -183; com o fundo a -183, o 1º a -186,25)")
	_checar(coluna.cor_da_temperatura(-200.0) == ColunaDoSimulador.RAMPA[0] and coluna.cor_da_temperatura(-170.0) == ColunaDoSimulador.RAMPA[-1] \
		and coluna.cor_da_temperatura(-185.0) != ColunaDoSimulador.RAMPA[0], "a cor vai do azul do mínimo ao laranja do máximo")

	coluna.reiniciar()
	_checar(coluna.temperatura() == -200.0 and coluna.temperatura_pedida() == -200.0 \
		and coluna.quantas_em(ColunaDoSimulador.Estado.LIQUIDA) == 19 and coluna.lugar_de("N2") == Vector2i(0, L),
		"reiniciar() devolve tudo ao fundo e o termômetro ao mínimo")
	coluna.queue_free()

	# Sem mistura, a coluna não quebra.
	var vazia := ColunaDoSimulador.new()
	add_child(vazia)
	vazia.set_process(false)
	vazia.avancar(1.0)
	vazia.pedir_temperatura(50.0)
	_checar(vazia.total_de_moleculas() == 0 and not vazia.separada() and vazia.mistura().is_empty(), "sem mistura, a coluna fica vazia e quieta")
	vazia.queue_free()
	await _quadros(1)


func _testar_as_separacoes() -> void:
	print("\n--- A DESTILAÇÃO DE CADA MISTURA ---")
	for chave: String in SEPARACOES:
		var dados := MisturasDoDestilador.mistura(chave)
		var nome := String(dados["nome"])
		var fundo := float(SEPARACOES[chave]["fundo"])
		var onde: Dictionary = SEPARACOES[chave]["onde"]
		var coluna := _nova_coluna(chave)
		print("  . %s, com o fundo a %s" % [nome, MisturasDoDestilador.graus(fundo)])

		# O que o teste espera é o que a conta manda.
		var pela_conta := true
		for substancia: String in onde:
			if _lugar_pela_conta(coluna, substancia, fundo) != onde[substancia]:
				pela_conta = false
		_checar(pela_conta and onde.size() == (dados["substancias"] as Dictionary).size(),
			"pela conta, cada substância tem o seu andar (e nenhum andar tem duas)")

		var ferveram: Array = []
		var condensaram := {}
		var separou := [0]
		coluna.ferveu.connect(func(substancia: String) -> void: ferveram.append(substancia))
		coluna.condensou.connect(func(substancia: String, andar: int) -> void: condensaram[substancia] = andar)
		coluna.separou.connect(func() -> void: separou[0] += 1)
		var inicial := {}
		for substancia: String in dados["substancias"]:
			inicial[substancia] = int(dados["substancias"][substancia])

		coluna.pedir_temperatura(fundo)
		# Enquanto anda: ninguém some, ninguém sai da coluna.
		var tempo := 0.0
		var perdidas := false
		var fora := false
		var limites := Rect2(Vector2.ZERO, coluna.tamanho_da_coluna()).grow(2.0)
		while tempo < 120.0 and not (coluna.separada() and is_equal_approx(coluna.temperatura(), fundo)):
			coluna.avancar(PASSO)
			tempo += PASSO
			if int(tempo / PASSO) % 30 == 0:
				for substancia: String in inicial:
					var contadas := 0
					for lugar: Vector2i in coluna.onde_esta(substancia):
						contadas += int(coluna.onde_esta(substancia)[lugar])
					if contadas != inicial[substancia]:
						perdidas = true
				for p in coluna._particulas:
					if not limites.has_point(p.pos):
						fora = true
		_checar(coluna.separada(), "a mistura se separa (em %.0f s de jogo): %s" % [tempo, _retrato(coluna)])
		_checar(not perdidas and coluna.total_de_moleculas() == inicial.values().reduce(func(a: int, b: int) -> int: return a + b, 0),
			"nenhuma molécula se perde no caminho")
		_checar(not fora, "nem sai de dentro da coluna")
		var no_lugar := true
		for substancia: String in onde:
			if coluna.lugar_de(substancia) != onde[substancia]:
				no_lugar = false
		_checar(no_lugar, "cada substância inteira no andar da conta")
		_checar(separou[0] == 1, "o sinal de separada sai uma vez só")
		# Ferveu tudo o que saiu do fundo (cada substância avisa uma vez só), a
		# começar pela que ferve mais fácil.
		var esperadas: Array = []
		for substancia in MisturasDoDestilador.em_ordem_de_ebulicao(dados):
			if onde[substancia] != Vector2i(0, L):
				esperadas.append(substancia)
		var ferveram_em_ordem := ferveram.duplicate()
		ferveram_em_ordem.sort_custom(func(a: String, b: String) -> bool:
			return MisturasDoDestilador.ebulicao(a) < MisturasDoDestilador.ebulicao(b))
		_checar(ferveram_em_ordem == esperadas and ferveram[0] == esperadas[0],
			"ferveu o que saiu do fundo, a começar pelo que ferve mais fácil: %s" % [ferveram])
		var condensou_certo := true
		for substancia: String in onde:
			var lugar: Vector2i = onde[substancia]
			if lugar.y == L and lugar.x > 0 and int(condensaram.get(substancia, -1)) != lugar.x:
				condensou_certo = false
			if lugar.y == G and coluna.quantas_em(ColunaDoSimulador.Estado.SOLTA, substancia) != inicial[substancia]:
				condensou_certo = false
		_checar(condensou_certo, "cada uma condensou no andar dela (e o que não condensa ficou gás)")
		# As fichas.
		var topo := coluna.andares() - 1
		var frases := true
		for substancia: String in onde:
			var lugar: Vector2i = onde[substancia]
			var esperada := "LÍQUIDO NO FUNDO"
			if lugar.y == G:
				esperada = "GÁS NO TOPO"
			elif lugar.x == topo:
				esperada = "LÍQUIDO NO TOPO"
			elif lugar.x > 0:
				esperada = "LÍQUIDO NO %dº ANDAR" % lugar.x
			if coluna.situacao_de(substancia) != esperada:
				frases = false
			if lugar.y == L and coluna.substancia_do_andar(lugar.x) != substancia:
				frases = false
		_checar(frases, "e a ficha de cada uma diz onde ela está")
		# Parada ali, continua separada.
		_andar(coluna, 5.0)
		_checar(coluna.separada() and separou[0] == 1, "deixada quieta, continua separada")
		coluna.queue_free()
	await _quadros(1)


func _testar_o_calor_demais() -> void:
	print("\n--- ESQUENTAR DEMAIS, ESFRIAR, RECOMEÇAR ---")
	var coluna := _nova_coluna("ar")
	coluna.pedir_temperatura(-183.0)
	_checar(_andar_ate(coluna, coluna.separada) >= 0.0, "o ar separado a -183")
	# Fundo a -176: andares a -176, -181, -186, -191 e -196. O oxigênio (-183) e o
	# argônio (-186) param os dois no 2º andar.
	coluna.pedir_temperatura(-176.0)
	_andar_ate(coluna, func() -> bool: return coluna.em_transito() == 0 and is_equal_approx(coluna.temperatura(), -176.0) \
		and coluna.lugar_de("O2") != ColunaDoSimulador.A_CAMINHO and coluna.lugar_de("Ar") != ColunaDoSimulador.A_CAMINHO)
	_andar(coluna, 3.0)
	_checar(coluna.lugar_de("O2") == Vector2i(2, L) and coluna.lugar_de("Ar") == Vector2i(2, L),
		"com o fundo a -176, o oxigênio e o argônio vão parar no mesmo andar: %s" % _retrato(coluna))
	_checar(not coluna.separada() and coluna.substancia_do_andar(2) == "", "a mistura deixa de estar separada")
	_checar(coluna.lugar_de("N2") == Vector2i(4, L), "o nitrogênio continua no topo")

	# Esfriar não desfaz: o líquido de uma bandeja fica nela.
	coluna.pedir_temperatura(-200.0)
	_andar(coluna, 8.0)
	_checar(coluna.temperatura() == -200.0 and coluna.lugar_de("O2") == Vector2i(2, L) and coluna.lugar_de("Ar") == Vector2i(2, L) \
		and not coluna.separada(), "esfriar tudo de novo não desmistura: o que virou líquido numa bandeja fica nela")
	coluna.reiniciar()
	coluna.pedir_temperatura(-183.0)
	_checar(_andar_ate(coluna, coluna.separada) >= 0.0, "recomeçando, dá para separar de novo")
	coluna.queue_free()

	# O que nunca ferve na escala e o que nunca condensa.
	var mar := _nova_coluna("mar")
	mar.pedir_temperatura(float(MisturasDoDestilador.mistura("mar")["maxima"]))
	_andar(mar, 40.0)
	_checar(mar.lugar_de("NaCl") == Vector2i(0, L) and mar.quantas_em(ColunaDoSimulador.Estado.LIQUIDA, "NaCl") == 6,
		"água do mar no máximo do termômetro: o sal não ferve, fica no fundo")
	_checar(mar.onde_esta("H2O").keys().all(func(lugar: Vector2i) -> bool: return lugar.x > 0),
		"e a água saiu toda do fundo, sem o sal: %s" % _retrato(mar))
	mar.queue_free()
	var nobres := _nova_coluna("gases_nobres")
	_andar(nobres, 12.0)
	_checar(nobres.lugar_de("Ne") == Vector2i(4, G) and nobres.situacao_de("Ne") == "GÁS NO TOPO",
		"gases nobres, sem mexer em nada: a -200 o neônio já é gás, sobe e fica gás no topo")
	_checar(nobres.lugar_de("Ar") == Vector2i(0, L) and nobres.lugar_de("Xe") == Vector2i(0, L), "os outros continuam líquidos no fundo")
	nobres.queue_free()
	var petroleo := _nova_coluna("petroleo")
	_andar(petroleo, 12.0)
	_checar(petroleo.lugar_de("C4H10") == Vector2i(4, G), "petróleo a 25 °C: o butano já sai como gás pelo topo")
	petroleo.queue_free()
	await _quadros(1)


# ─────────────────────────────────────────────────────────────
# O TERMÔMETRO
# ─────────────────────────────────────────────────────────────

func _testar_o_termometro() -> void:
	print("\n--- O TERMÔMETRO ---")
	var termometro := Termometro.new()
	termometro.size = Vector2(120, 540)
	add_child(termometro)
	await _quadros(1)
	termometro.definir_faixa(-200.0, -170.0)
	_checar(termometro.altura_de(-200.0) > termometro.altura_de(-170.0), "o frio embaixo, o quente em cima")
	_checar(is_equal_approx(termometro.altura_de(-200.0), 540.0 - Termometro.FOLGA_DE_BAIXO) \
		and is_equal_approx(termometro.altura_de(-170.0), Termometro.FOLGA_DE_CIMA), "a escala vai de ponta a ponta do tubo")
	_checar(is_equal_approx(termometro.altura_de(-999.0), termometro.altura_de(-200.0)) \
		and is_equal_approx(termometro.altura_de(999.0), termometro.altura_de(-170.0)), "fora da escala, a altura é a do extremo")
	var ida_e_volta := true
	for graus in range(-200, -169):
		if not is_equal_approx(termometro.graus_no_ponto(termometro.altura_de(graus)), float(graus)):
			ida_e_volta = false
	_checar(ida_e_volta, "a altura de cada grau, lida de volta, dá o mesmo grau")
	_checar(termometro.graus_no_ponto(-50.0) == -170.0 and termometro.graus_no_ponto(5000.0) == -200.0,
		"um ponto fora do tubo dá o extremo da escala")
	# Um grau é mais que um pixel em todas as misturas (dá para acertar o grau arrastando)?
	var finos := PackedStringArray()
	for dados: Dictionary in MisturasDoDestilador.MISTURAS:
		termometro.definir_faixa(float(dados["minima"]), float(dados["maxima"]))
		var por_grau := absf(termometro.altura_de(float(dados["minima"])) - termometro.altura_de(float(dados["minima"]) + 1.0))
		if por_grau < 1.0:
			finos.append("%s (%.2f px por grau)" % [dados["nome"], por_grau])
	_checar(finos.is_empty(), "em toda mistura, um grau vale pelo menos 1 px do tubo %s" % [finos])
	var pegar := termometro.retangulo_de_pegar()
	_checar(pegar.encloses(termometro.retangulo_do_tubo().grow_individual(0, -14, 0, -14)) and pegar.size.x >= Termometro.LARGURA_DA_FICHA,
		"a área de pegar cobre o tubo e o lugar do ponteiro")
	termometro.definir_faixa(5.0, 5.0)
	_checar(termometro.maxima > termometro.minima, "uma escala sem tamanho é alargada, para não dividir por zero")
	termometro.queue_free()
	await _quadros(1)


# ─────────────────────────────────────────────────────────────
# A TELA
# ─────────────────────────────────────────────────────────────

func _testar_a_tela() -> void:
	print("\n--- A TELA ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	_checar(tela.titulo == "DESTILADOR" and tela.cena_de_volta == TransicaoDeCena.CENA_LABORATORIO,
		"o título é DESTILADOR, e ESC leva ao Laboratório")
	_checar(tela.chave_da_mistura == "ar" and tela.mistura()["chave"] == "ar", "abre com o ar líquido, a mistura da história")
	_checar(tela.substancias() == ["N2", "Ar", "O2"], "as fichas vêm na ordem em que as substâncias fervem: N2, Ar, O2")
	_checar(tela.termometro.minima == -200.0 and tela.termometro.maxima == -170.0 and tela.termometro.marcas.size() == 3,
		"o termômetro vai de -200 a -170, com uma marca para cada substância")
	var marcas_certas := true
	for marca: Dictionary in tela.termometro.marcas:
		if float(marca["graus"]) != MisturasDoDestilador.ebulicao(String(marca["chave"])):
			marcas_certas = false
	_checar(marcas_certas, "cada marca na altura do ponto de ebulição da substância")
	await _quadros(2)
	_checar(tela.termometro.pedida == -200.0 and tela.termometro.medida == -200.0, "o ponteiro e a coluna colorida começam no mínimo")

	# Tudo o que se clica: dentro da tela, sem um cobrir o outro.
	var tela_inteira := Rect2(Vector2.ZERO, tela.size)
	var alvos := {}
	for nome: String in tela.nomes_dos_alvos():
		alvos[nome] = tela.retangulo_do_alvo(nome)
	var esperados: Array = ["recomecar", "termometro", "mais_quente", "mais_frio"]
	for dados: Dictionary in MisturasDoDestilador.MISTURAS:
		esperados.append("mistura_" + String(dados["chave"]))
	var faltando := esperados.filter(func(nome: String) -> bool: return not alvos.has(nome))
	_checar(faltando.is_empty() and alvos.size() == esperados.size(), "os alvos: as seis misturas, RECOMEÇAR, o termômetro e as duas setas %s" \
		% [faltando])
	var mal_postos := PackedStringArray()
	var nomes := alvos.keys()
	for i in nomes.size():
		var caixa: Rect2 = alvos[nomes[i]]
		if not caixa.has_area() or not tela_inteira.encloses(caixa):
			mal_postos.append("%s fora da tela" % nomes[i])
		for j in range(i + 1, nomes.size()):
			if caixa.intersects(alvos[nomes[j]]):
				mal_postos.append("%s em cima de %s" % [nomes[i], nomes[j]])
	_checar(mal_postos.is_empty(), "todos dentro da tela, nenhum em cima do outro %s" % [mal_postos])

	# As peças não se cobrem: lista, coluna (com a régua e as plaquinhas), termômetro, fichas.
	var coluna: Rect2 = tela.coluna.get_global_rect()
	var com_regua := coluna.grow_individual(180.0, 0.0, 0.0, 0.0)
	var lista := Rect2(tela.LISTA.position, Vector2(tela.LISTA.size.x, tela.retangulo_do_recomecar().end.y - tela.LISTA.position.y))
	var termometro: Rect2 = tela.termometro.get_global_rect()
	_checar(tela_inteira.encloses(coluna) and not lista.intersects(com_regua) and not com_regua.intersects(termometro) \
		and lista.end.x < com_regua.position.x, "a lista, a coluna com a régua e o termômetro ficam lado a lado")
	_checar(tela.retangulo_do_titulo().end.y <= coluna.position.y + 4.0 and not tela.retangulo_do_titulo().intersects(lista),
		"e a plaquinha do título fica acima de tudo")

	# As fichas, as listas e os textos de TODAS as misturas.
	var textos := _textos_do_script(tela)
	textos.append_array(["LÍQUIDO NO FUNDO", "LÍQUIDO NO TOPO", "LÍQUIDO NO 3º ANDAR", "GÁS NO TOPO", "GÁS NO 2º ANDAR",
		"MUDANDO DE ANDAR", "ESPALHADA", ColunaDoSimulador.LEGENDA_DO_RESFRIADOR, "↑ 1465 °C", "↓ -246 °C"])
	_checar(_letras_que_faltam(textos).is_empty(), "toda letra da tela existe na fonte [%s]" % _letras_que_faltam(textos))
	var apertados := PackedStringArray()
	for i in MisturasDoDestilador.MISTURAS.size():
		var dados: Dictionary = MisturasDoDestilador.MISTURAS[i]
		if PecasDoLaboratorio.largura(String(dados["nome"]), 22) > tela.retangulo_da_mistura(i).size.x - 16.0:
			apertados.append("botão %s" % dados["nome"])
		await _clicar(tela, "mistura_" + String(dados["chave"]))
		if tela.chave_da_mistura != dados["chave"]:
			apertados.append("%s não entrou" % dados["nome"])
		var substancias: Array[String] = tela.substancias()
		for k in substancias.size():
			var ficha: Rect2 = tela.retangulo_da_ficha(k)
			if not tela_inteira.encloses(ficha) or ficha.intersects(termometro.grow_individual(0, 0, 110.0, 0)) \
					or (k > 0 and ficha.intersects(tela.retangulo_da_ficha(k - 1))):
				apertados.append("ficha %d de %s fora do lugar" % [k, dados["nome"]])
			var substancia := MisturasDoDestilador.substancia(substancias[k])
			var x: float = ficha.position.x + tela.LARGURA_DO_DESENHO + 8.0
			var cabem: float = ficha.end.x - 8.0 - x
			var linhas: Array = [[String(substancia["nome"]), 22],
				[String(MisturasDoDestilador.APELIDOS.get(substancias[k], "")), 11],
				[tela.TXT_FERVE % MisturasDoDestilador.graus(float(substancia["ebulicao"])), 11],
				["LÍQUIDO NO 3º ANDAR", 11], ["MUDANDO DE ANDAR", 11]]
			for linha: Array in linhas:
				if PecasDoLaboratorio.largura(String(linha[0]), int(linha[1])) > cabem:
					apertados.append("%s: \"%s\" não cabe na ficha" % [dados["nome"], linha[0]])
			# O desenho da molécula cabe no canto dele.
			var lado := float(MoleculasDoDestilador.celula(substancias[k]).x) * MoleculasDoDestilador.ESCALA
			var ampliacao := 2.0 if lado * 2.0 <= tela.LARGURA_DO_DESENHO - 8.0 else 1.0
			if lado * ampliacao > tela.LARGURA_DO_DESENHO + 4.0:
				apertados.append("%s: a molécula de %s não cabe no canto (%.0f px)" % [dados["nome"], substancias[k], lado * ampliacao])
		# O aviso de baixo das fichas (o objetivo, ou MISTURA SEPARADA) cabe na tela.
		var pe_das_fichas: float = tela.retangulo_da_ficha(substancias.size()).position.y + 34.0
		var linhas_do_aviso := EstiloHUD.quebrar(FONTE, tela.TXT_OBJETIVO, 11, tela.FICHAS.size.x).size()
		if pe_das_fichas - 22.0 + linhas_do_aviso * 17.0 > tela.size.y - 60.0:
			apertados.append("%s: o aviso de baixo das fichas não cabe" % dados["nome"])
		# A nota e o aviso do modelo, embaixo da lista.
		var y: float = tela.retangulo_do_recomecar().end.y + 34.0
		y += EstiloHUD.quebrar(FONTE, String(dados["nota"]), 11, tela.LISTA.size.x).size() * 17.0 + 22.0
		y += EstiloHUD.quebrar(FONTE, tela.TXT_MODELO, 11, tela.LISTA.size.x).size() * 17.0
		if y > tela.size.y - 60.0:
			apertados.append("%s: a nota e o aviso do modelo passam do pé da tela (%.0f)" % [dados["nome"], y])
		# As marcas do termômetro (molécula + número) cabem até as fichas.
		for marca: Dictionary in tela.termometro.marcas:
			var texto := MisturasDoDestilador.graus(float(marca["graus"]))
			if float(marca["graus"]) > tela.termometro.maxima or float(marca["graus"]) < tela.termometro.minima:
				texto = "↑ " + texto
			var largura := float(MoleculasDoDestilador.celula(String(marca["chave"])).x) * MoleculasDoDestilador.ESCALA
			var fim: float = tela.termometro.global_position.x + tela.termometro.retangulo_da_ficha().end.x + 2.0 + 30.0 + largura \
				+ PecasDoLaboratorio.largura(texto, 11)
			if fim > tela.FICHAS.position.x - 6.0:
				apertados.append("%s: a marca de %s encosta nas fichas (%.0f)" % [dados["nome"], marca["chave"], fim])
	_checar(apertados.is_empty(), "nas seis misturas: botões, fichas, notas e marcas do termômetro no lugar %s" % [apertados.slice(0, 6)])
	await _foto("dest_1_tela")
	await _fechar(tela)


func _testar_os_comandos() -> void:
	print("\n--- AS SETAS, AS TECLAS E O ARRASTO ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	var trocas: Array = []
	tela.mistura_trocada.connect(func(chave: String) -> void: trocas.append(chave))
	# A coluna só anda quando o teste manda.
	tela.coluna.set_process(false)

	await _clicar(tela, "mais_quente")
	_checar(tela.coluna.temperatura_pedida() == -199.0 and _tocou(tela, "passo"), "a seta de cima pede um grau a mais (-199)")
	await _quadros(2)
	_checar(tela.termometro.pedida == -199.0 and tela.termometro.medida == -200.0,
		"o ponteiro vai na hora; a coluna colorida (o que o fundo tem) vai atrás")
	await _clicar(tela, "mais_frio", 2)
	_checar(tela.coluna.temperatura_pedida() == -200.0, "a de baixo, um a menos; no mínimo, ela para (-200)")
	_tocou(tela, "passo")
	await _clicar(tela, "mais_frio")
	_checar(not _tocou(tela, "passo"), "no mínimo, a seta de baixo não faz mais nada")

	# Segurando a seta, repete.
	var seta: Vector2 = tela.retangulo_do_alvo("mais_quente").get_center()
	_mover_o_mouse(seta)
	_botao_do_mouse(seta, true)
	await _esperar(1.2)
	_botao_do_mouse(seta, false)
	var segurando: float = tela.coluna.temperatura_pedida()
	await _esperar(0.3)
	_checar(segurando >= -195.0 and tela.coluna.temperatura_pedida() == segurando, "segurando a seta, a temperatura sobe sozinha (até %s)" \
		% MisturasDoDestilador.graus(segurando))

	# As teclas.
	tela.pedir_temperatura(-190.0)
	await _teclar(KEY_UP)
	await _teclar(KEY_W)
	_checar(tela.coluna.temperatura_pedida() == -188.0, "↑ e W sobem um grau cada")
	await _teclar(KEY_DOWN)
	await _teclar(KEY_S)
	await _teclar(KEY_S)
	_checar(tela.coluna.temperatura_pedida() == -191.0, "↓ e S descem")
	await _teclar(KEY_LEFT)
	await _teclar(KEY_ENTER)
	_checar(tela.coluna.temperatura_pedida() == -191.0 and tela.chave_da_mistura == "ar", "as outras teclas não mexem em nada")
	tela.pedir_temperatura(-185.4)
	tela.mudar_temperatura(1)
	_checar(tela.coluna.temperatura_pedida() == -184.0, "a seta sempre acerta um grau inteiro")

	# O arrasto do ponteiro.
	var termometro: Termometro = tela.termometro
	var no_tubo := termometro.global_position.x + termometro.size.x * 0.5
	var ponto := func(graus: float) -> Vector2: return Vector2(no_tubo, termometro.global_position.y + termometro.altura_de(graus))
	_mover_o_mouse(ponto.call(-183.0))
	_checar(tela.alvo_em_foco() == "termometro", "o mouse em cima do tubo põe o foco no termômetro")
	_botao_do_mouse(ponto.call(-183.0), true)
	_checar(tela.coluna.temperatura_pedida() == -183.0, "clicar no tubo, na altura dos -183, pede -183")
	_mover_o_mouse(ponto.call(-176.0))
	_checar(tela.coluna.temperatura_pedida() == -176.0, "arrastando, o ponteiro vai junto (-176)")
	_mover_o_mouse(ponto.call(-176.0) + Vector2(260, -900))
	_checar(tela.coluna.temperatura_pedida() == -170.0, "arrastando para fora, por cima, ele para no máximo (-170)")
	_mover_o_mouse(ponto.call(-181.0) + Vector2(-300, 0))
	_checar(tela.coluna.temperatura_pedida() == -181.0, "e continua valendo com o mouse longe do tubo, enquanto o botão está apertado")
	_botao_do_mouse(ponto.call(-181.0) + Vector2(-300, 0), false)
	_mover_o_mouse(ponto.call(-195.0))
	_checar(tela.coluna.temperatura_pedida() == -181.0, "soltou o botão: o ponteiro fica onde foi deixado")
	await _quadros(2)
	_checar(tela.termometro.pedida == -181.0, "e o termômetro mostra o que foi pedido")
	var graus_inteiros := true
	_botao_do_mouse(ponto.call(-190.0), true)
	for i in 40:
		_mover_o_mouse(ponto.call(-190.0) + Vector2(0, -i * 1.7))
		if not is_equal_approx(tela.coluna.temperatura_pedida(), roundf(tela.coluna.temperatura_pedida())):
			graus_inteiros = false
	_botao_do_mouse(ponto.call(-190.0), false)
	_checar(graus_inteiros, "arrastando, o pedido anda de grau em grau")

	# Trocar de mistura e recomeçar.
	await _clicar(tela, "mistura_petroleo")
	_checar(tela.chave_da_mistura == "petroleo" and trocas == ["petroleo"] and _tocou(tela, "botao"),
		"clicar em PETRÓLEO troca a mistura")
	_checar(tela.termometro.minima == 25.0 and tela.termometro.maxima == 350.0 and tela.termometro.marcas.size() == 4 \
		and tela.coluna.temperatura_pedida() == 25.0 and tela.coluna.total_de_moleculas() == 18,
		"com a escala dela (25 a 350), as quatro marcas e as moléculas dela, do começo")
	_checar(tela.substancias() == ["C4H10", "C8H18", "C12H26", "C16H34"], "e as fichas dela: butano, octano, dodecano, hexadecano")
	tela.pedir_temperatura(300.0)
	for i in 600:
		tela.coluna.avancar(PASSO)
	_checar(tela.coluna.quantas_em(ColunaDoSimulador.Estado.LIQUIDA) < 18 or tela.coluna.lugar_de("C8H18") != Vector2i(0, L),
		"esquentando, as moléculas saem do fundo")
	await _clicar(tela, "recomecar")
	_checar(tela.coluna.temperatura_pedida() == 25.0 and tela.coluna.temperatura() == 25.0 \
		and tela.coluna.lugar_de("C16H34") == Vector2i(0, L) and tela.coluna.lugar_de("C4H10") == Vector2i(0, L) \
		and tela.chave_da_mistura == "petroleo" and _tocou(tela, "tirar"),
		"RECOMEÇAR devolve a mesma mistura ao começo")
	await _fechar(tela)


func _testar_a_separacao_na_tela() -> void:
	print("\n--- SEPARANDO NA TELA ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	tela.coluna.set_process(false)
	for chave: String in SEPARACOES:
		await _clicar(tela, "mistura_" + chave)
		_tocou(tela, "certo")
		# Leva o ponteiro com as setas do teclado até a temperatura da separação
		# (o caminho que a pessoa faria), e deixa a coluna andar.
		var fundo := float(SEPARACOES[chave]["fundo"])
		tela.pedir_temperatura(fundo - 3.0)
		for i in 3:
			await _teclar(KEY_UP)
		var pediu: bool = tela.coluna.temperatura_pedida() == fundo
		var tempo := _andar_ate(tela.coluna, tela.coluna.separada, 120.0)
		await _quadros(2)
		var onde: Dictionary = SEPARACOES[chave]["onde"]
		var no_lugar := true
		for substancia: String in onde:
			if tela.coluna.lugar_de(substancia) != onde[substancia]:
				no_lugar = false
		_checar(pediu and tempo >= 0.0 and no_lugar and _tocou(tela, "certo"),
			"%s separada a %s, com o som de acerto" % [MisturasDoDestilador.mistura(chave)["nome"], MisturasDoDestilador.graus(fundo)])
		await _esperar(0.3)
		await _foto("dest_2_%s" % chave)
	await _fechar(tela)


func _testar_o_controle() -> void:
	print("\n--- NO CONTROLE ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	tela.coluna.set_process(false)
	_checar(tela.usa_cursor() and tela.alvos_do_cursor().size() == tela.nomes_dos_alvos().size(), "o cursor do controle para em todos os alvos")
	await _tocar_no_controle(JOY_BUTTON_DPAD_UP)
	_checar(Controle.em_uso and CursorVirtual.ativo(), "um toque no controle liga o cursor")
	_checar(tela.coluna.temperatura_pedida() == -200.0, "o direcional pula de alvo em alvo: não mexe na temperatura")
	# O analógico leva o cursor, e só.
	await _levar_o_cursor(Vector2(800, 600))
	_eixo_do_controle(JOY_AXIS_LEFT_Y, -1.0)
	await _esperar(0.3)
	_eixo_do_controle(JOY_AXIS_LEFT_Y, 0.0)
	await _quadros(3)
	_checar(CursorVirtual._pos.y < 560.0 and tela.coluna.temperatura_pedida() == -200.0,
		"o analógico para cima leva o cursor para cima, e a temperatura não muda")
	# ✕ na seta.
	await _levar_o_cursor(tela.retangulo_do_alvo("mais_quente").get_center())
	await _tocar_no_controle(JOY_BUTTON_A)
	await _tocar_no_controle(JOY_BUTTON_A)
	_checar(tela.coluna.temperatura_pedida() == -198.0, "✕ na seta de cima: um grau por toque (-198)")
	# Segurando o ✕ no termômetro, o ponteiro vai com o cursor.
	var termometro: Termometro = tela.termometro
	var no_tubo := termometro.global_position.x + termometro.size.x * 0.5
	await _levar_o_cursor(Vector2(no_tubo, termometro.global_position.y + termometro.altura_de(-190.0)))
	_botao_do_controle(JOY_BUTTON_A, true)
	await _quadros(3)
	_checar(tela.coluna.temperatura_pedida() == -190.0, "✕ em cima do tubo, na altura dos -190, pede -190")
	# Com o ✕ segurado, o analógico leva o cursor para cima e o ponteiro vai junto.
	_eixo_do_controle(JOY_AXIS_LEFT_Y, -1.0)
	await _esperar(0.2)
	_eixo_do_controle(JOY_AXIS_LEFT_Y, 0.0)
	await _quadros(3)
	var arrastado: float = tela.coluna.temperatura_pedida()
	var no_cursor := roundf(termometro.graus_no_ponto(CursorVirtual._pos.y - termometro.global_position.y))
	_checar(arrastado > -190.0 and arrastado == no_cursor, "segurando o ✕ e subindo o cursor, o ponteiro vai junto (%s)" 		% MisturasDoDestilador.graus(arrastado))
	_botao_do_controle(JOY_BUTTON_A, false)
	await _quadros(3)
	_eixo_do_controle(JOY_AXIS_LEFT_Y, 1.0)
	await _esperar(0.2)
	_eixo_do_controle(JOY_AXIS_LEFT_Y, 0.0)
	await _quadros(3)
	_checar(tela.coluna.temperatura_pedida() == arrastado, "soltando o ✕, o ponteiro fica onde foi deixado")
	await _voltar_ao_teclado()
	await _fechar(tela)


func _testar_a_saida() -> void:
	print("\n--- SAIR ---")
	var tela := await _abrir(CENA)
	await _esperar(0.3)
	await _teclar(KEY_ESCAPE)
	_checar(tela.de_saida() and TransicaoDeCena.em_curso(), "ESC pede para sair")
	await _clicar(tela, "mistura_mar")
	_checar(tela.chave_da_mistura == "ar", "de saída, a tela não responde a mais nada")
	var chegou := await _esperar_a_troca()
	_checar(chegou == TransicaoDeCena.CENA_LABORATORIO, "e a cena que chega é o menu do Laboratório")
	await _fechar(tela)
