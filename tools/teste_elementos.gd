extends Node

# Teste dos dados dos 118 elementos (scripts/laboratorio/elementos.gd), de que
# saem a tabela periódica, o "Monte seu átomo" e o quiz do Laboratório.
#
#   * são 118, cada um com símbolo, nome, massa e isótopo, sem repetir;
#   * o que já está desenhado no jogo bate: o hidrogênio (1, H, 1,008) e o
#     oxigênio (8, O, 15,999) das caixas do caderno, o carbono do puzzle do
#     bumerangue (6, C, 12,011);
#   * a distribuição dos elétrons por camadas é a publicada, para os 118 (a
#     lista de CAMADAS_PUBLICADAS veio de uma base de referência, não da conta
#     que está sendo testada);
#   * nenhuma camada passa do que comporta, e a soma é o número atômico;
#   * grupo, período e família de cada um, e a casa de cada um no desenho da
#     tabela: 118 casas diferentes, 18 colunas, 7 períodos e as duas fileiras
#     de baixo;
#   * os íons: o cátion perde os elétrons de valência (Fe²⁺, Cu⁺, Eu³⁺, Pd²⁺) e
#     o ânion fica como o átomo neutro com aquele tanto de elétrons (Cl⁻, O²⁻);
#   * os isótopos da natureza: o mais abundante é o "isótopo" do elemento, e as
#     abundâncias de cada elemento somam 100%;
#   * toda letra de todo nome, símbolo e massa existe na fonte do jogo;
#   * a carga e os números se escrevem do jeito brasileiro.
#
#   godot --headless --path . res://tools/teste_elementos.tscn

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

## A distribuição por camadas de cada elemento, na ordem do número atômico,
## como está publicada (Wikipédia / Periodic-Table-JSON).
const CAMADAS_PUBLICADAS := [
	"1", "2", "2-1", "2-2", "2-3", "2-4", "2-5", "2-6", "2-7", "2-8", "2-8-1", "2-8-2", "2-8-3",
	"2-8-4", "2-8-5", "2-8-6", "2-8-7", "2-8-8", "2-8-8-1", "2-8-8-2", "2-8-9-2", "2-8-10-2",
	"2-8-11-2", "2-8-13-1", "2-8-13-2", "2-8-14-2", "2-8-15-2", "2-8-16-2", "2-8-18-1",
	"2-8-18-2", "2-8-18-3", "2-8-18-4", "2-8-18-5", "2-8-18-6", "2-8-18-7", "2-8-18-8",
	"2-8-18-8-1", "2-8-18-8-2", "2-8-18-9-2", "2-8-18-10-2", "2-8-18-12-1", "2-8-18-13-1",
	"2-8-18-13-2", "2-8-18-15-1", "2-8-18-16-1", "2-8-18-18", "2-8-18-18-1", "2-8-18-18-2",
	"2-8-18-18-3", "2-8-18-18-4", "2-8-18-18-5", "2-8-18-18-6", "2-8-18-18-7", "2-8-18-18-8",
	"2-8-18-18-8-1", "2-8-18-18-8-2", "2-8-18-18-9-2", "2-8-18-19-9-2", "2-8-18-21-8-2",
	"2-8-18-22-8-2", "2-8-18-23-8-2", "2-8-18-24-8-2", "2-8-18-25-8-2", "2-8-18-25-9-2",
	"2-8-18-27-8-2", "2-8-18-28-8-2", "2-8-18-29-8-2", "2-8-18-30-8-2", "2-8-18-31-8-2",
	"2-8-18-32-8-2", "2-8-18-32-9-2", "2-8-18-32-10-2", "2-8-18-32-11-2", "2-8-18-32-12-2",
	"2-8-18-32-13-2", "2-8-18-32-14-2", "2-8-18-32-15-2", "2-8-18-32-17-1", "2-8-18-32-18-1",
	"2-8-18-32-18-2", "2-8-18-32-18-3", "2-8-18-32-18-4", "2-8-18-32-18-5", "2-8-18-32-18-6",
	"2-8-18-32-18-7", "2-8-18-32-18-8", "2-8-18-32-18-8-1", "2-8-18-32-18-8-2",
	"2-8-18-32-18-9-2", "2-8-18-32-18-10-2", "2-8-18-32-20-9-2", "2-8-18-32-21-9-2",
	"2-8-18-32-22-9-2", "2-8-18-32-24-8-2", "2-8-18-32-25-8-2", "2-8-18-32-25-9-2",
	"2-8-18-32-27-8-2", "2-8-18-32-28-8-2", "2-8-18-32-29-8-2", "2-8-18-32-30-8-2",
	"2-8-18-32-31-8-2", "2-8-18-32-32-8-2", "2-8-18-32-32-8-3", "2-8-18-32-32-10-2",
	"2-8-18-32-32-11-2", "2-8-18-32-32-12-2", "2-8-18-32-32-13-2", "2-8-18-32-32-14-2",
	"2-8-18-32-32-15-2", "2-8-18-32-32-16-2", "2-8-18-32-32-17-2", "2-8-18-32-32-18-2",
	"2-8-18-32-32-18-3", "2-8-18-32-32-18-4", "2-8-18-32-32-18-5", "2-8-18-32-32-18-6",
	"2-8-18-32-32-18-7", "2-8-18-32-32-18-8",
]

var _falhas := 0


func _ready() -> void:
	await get_tree().process_frame
	_testar_caixas()
	_testar_camadas()
	_testar_tabela()
	_testar_ions()
	_testar_isotopos()
	_testar_escrita()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


func _testar_caixas() -> void:
	print("\n--- O QUE ESTÁ NA CAIXA ---")
	_checar(Elementos.DADOS.size() == 118 and Elementos.TOTAL == 118, "são 118 elementos")
	var simbolos := {}
	var nomes := {}
	var incompletos := PackedStringArray()
	var maior_nome := ""
	for z in range(1, 119):
		var s := Elementos.simbolo(z)
		var n := Elementos.nome(z)
		simbolos[s] = true
		nomes[n] = true
		if s.is_empty() or s.length() > 2 or s[0] != s[0].to_upper() or n.length() < 4 \
				or Elementos.massa(z).is_empty() or Elementos.isotopo(z) < z:
			incompletos.append(str(z))
		if n.length() > maior_nome.length():
			maior_nome = n
	_checar(incompletos.is_empty(), "cada um tem símbolo, nome, massa e isótopo %s" % [incompletos])
	_checar(simbolos.size() == 118 and nomes.size() == 118, "sem símbolo nem nome repetido")
	_checar(Elementos.simbolo(1) == "H" and Elementos.nome(1) == "Hidrogênio" and Elementos.massa(1) == "1,008",
		"o hidrogênio é o da caixa do caderno: 1, H, 1,008")
	_checar(Elementos.simbolo(8) == "O" and Elementos.nome(8) == "Oxigênio" and Elementos.massa(8) == "15,999",
		"o oxigênio é o da caixa do puzzle: 8, O, 15,999")
	_checar(Elementos.simbolo(6) == "C" and Elementos.nome(6) == "Carbono" and Elementos.massa(6) == "12,011",
		"o carbono é o do puzzle do bumerangue: 6, C, 12,011")
	_checar(Elementos.simbolo(79) == "Au" and Elementos.nome(79) == "Ouro" and Elementos.massa(79) == "196,97",
		"o ouro: 79, Au, 196,97")
	_checar(Elementos.simbolo(118) == "Og" and Elementos.massa(118) == "[294]" and Elementos.massa(43) == "[97]",
		"quem não tem massa padrão vem com o número de massa entre colchetes")
	_checar(Elementos.numero("Fe") == 26 and Elementos.numero("U") == 92 and Elementos.numero("Xx") == 0,
		"dá para achar o elemento pelo símbolo")
	_checar(not Elementos.existe(0) and not Elementos.existe(119) and Elementos.simbolo(0) == "" \
		and Elementos.nome(119) == "" and Elementos.camadas(0).is_empty(),
		"fora de 1 a 118 não existe elemento (e nada quebra)")

	var faltando := ""
	for z in range(1, 119):
		for texto: String in [Elementos.simbolo(z), Elementos.nome(z), Elementos.massa(z)]:
			for c in texto:
				if not FONTE.has_char(c.unicode_at(0)) and not faltando.contains(c):
					faltando += c
	for qual in Elementos.FAMILIAS:
		for texto: String in Elementos.FAMILIAS[qual]:
			for c in texto:
				if c != " " and not FONTE.has_char(c.unicode_at(0)) and not faltando.contains(c):
					faltando += c
	_checar(faltando.is_empty(), "toda letra dos nomes, símbolos, massas e famílias existe na fonte [%s]" % faltando)
	print("  .     o nome mais comprido: %s" % maior_nome)


func _testar_camadas() -> void:
	print("\n--- AS CAMADAS ---")
	_checar(CAMADAS_PUBLICADAS.size() == 118, "a lista publicada tem os 118")
	var diferentes := PackedStringArray()
	var estouradas := PackedStringArray()
	for z in range(1, 119):
		var camadas := Elementos.camadas(z)
		var escrita := "-".join(Array(camadas).map(func(n: int) -> String: return str(n)))
		if escrita != CAMADAS_PUBLICADAS[z - 1]:
			diferentes.append("%s %s x %s" % [Elementos.simbolo(z), escrita, CAMADAS_PUBLICADAS[z - 1]])
		var soma := 0
		for i in camadas.size():
			soma += camadas[i]
			if camadas[i] > Elementos.CABEM_NAS_CAMADAS[i] or camadas[i] <= 0:
				estouradas.append(Elementos.simbolo(z))
		if soma != z:
			estouradas.append(Elementos.simbolo(z) + " soma")
	_checar(diferentes.is_empty(), "as camadas dos 118 são as publicadas %s" % [diferentes])
	_checar(estouradas.is_empty(), "nenhuma camada passa do que comporta, e a soma é o número atômico %s" % [estouradas])
	_checar(Array(Elementos.camadas(6)) == [2, 4] and Array(Elementos.camadas(8)) == [2, 6] \
		and Array(Elementos.camadas(1)) == [1], "os dos puzzles: carbono 2-4, oxigênio 2-6, hidrogênio 1")
	_checar(Array(Elementos.camadas(24)) == [2, 8, 13, 1] and Array(Elementos.camadas(29)) == [2, 8, 18, 1] \
		and Array(Elementos.camadas(46)) == [2, 8, 18, 18] and Array(Elementos.camadas(79)) == [2, 8, 18, 32, 18, 1],
		"as exceções saem certas: crômio 2-8-13-1, cobre 2-8-18-1, paládio 2-8-18-18, ouro ...-18-1")
	_checar(Elementos.texto_das_camadas(Elementos.camadas(11)) == "2 - 8 - 1", "e se escrevem \"2 - 8 - 1\"")
	_checar(Elementos.LETRAS_DAS_CAMADAS.size() == 7 and Elementos.CABEM_NAS_CAMADAS.size() == 7 \
		and Elementos.camadas(118).size() == 7, "são sete camadas, de K a Q")


func _testar_tabela() -> void:
	print("\n--- O LUGAR NA TABELA ---")
	var casas := {}
	var fora := PackedStringArray()
	var por_linha := {}
	for z in range(1, 119):
		var casa := Elementos.casa(z)
		casas[casa] = z
		por_linha[casa.y] = int(por_linha.get(casa.y, 0)) + 1
		if casa.x < 0 or casa.x > 17 or casa.y < 0 or casa.y > 8:
			fora.append(Elementos.simbolo(z))
	_checar(casas.size() == 118 and fora.is_empty(), "118 casas diferentes, em 18 colunas e 9 linhas %s" % [fora])
	_checar(por_linha == {0: 2, 1: 8, 2: 8, 3: 18, 4: 18, 5: 17, 6: 17, 7: 15, 8: 15},
		"os períodos têm 2, 8, 8, 18, 18, 17 e 17 casas, e as fileiras de baixo, 15 cada %s" % [por_linha])
	_checar(Elementos.casa(1) == Vector2i(0, 0) and Elementos.casa(2) == Vector2i(17, 0) \
		and Elementos.casa(6) == Vector2i(13, 1) and Elementos.casa(26) == Vector2i(7, 3) \
		and Elementos.casa(57) == Vector2i(2, 7) and Elementos.casa(71) == Vector2i(16, 7) \
		and Elementos.casa(89) == Vector2i(2, 8) and Elementos.casa(103) == Vector2i(16, 8) \
		and Elementos.casa(72) == Vector2i(3, 5) and Elementos.casa(118) == Vector2i(17, 6),
		"H no canto, He no outro, C no grupo 14, lantanídios e actinídios embaixo")
	_checar(Elementos.na_casa(13, 1) == 6 and Elementos.na_casa(5, 0) == 0 and Elementos.na_casa(2, 5) == 0,
		"dá para perguntar quem mora numa casa (e as vazias respondem 0)")
	_checar(Elementos.grupo(1) == 1 and Elementos.grupo(2) == 18 and Elementos.grupo(6) == 14 \
		and Elementos.grupo(17) == 17 and Elementos.grupo(26) == 8 and Elementos.grupo(79) == 11 \
		and Elementos.grupo(64) == 0 and Elementos.grupo(92) == 0 and Elementos.grupo(118) == 18,
		"os grupos: H 1, He 18, C 14, Cl 17, Fe 8, Au 11, e 0 nas fileiras de baixo")
	_checar(Elementos.periodo(1) == 1 and Elementos.periodo(10) == 2 and Elementos.periodo(11) == 3 \
		and Elementos.periodo(36) == 4 and Elementos.periodo(54) == 5 and Elementos.periodo(64) == 6 \
		and Elementos.periodo(118) == 7, "os períodos: H 1, Ne 2, Na 3, Kr 4, Xe 5, Gd 6, Og 7")
	# O período é a quantidade de camadas com elétron.
	var sem_bater := PackedStringArray()
	for z in range(1, 119):
		if Elementos.camadas(z).size() != Elementos.periodo(z) and z != 46:
			sem_bater.append(Elementos.simbolo(z))
	_checar(sem_bater.is_empty(), "o período é o número de camadas (só o paládio foge) %s" % [sem_bater])

	var familias := {}
	for z in range(1, 119):
		var f := Elementos.familia(z)
		familias[f] = int(familias.get(f, 0)) + 1
	_checar(familias.size() == 10 and Elementos.FAMILIAS.size() == 10, "dez famílias, todas com nome")
	_checar(familias[Elementos.Familia.GAS_NOBRE] == 7 and familias[Elementos.Familia.HALOGENIO] == 6 \
		and familias[Elementos.Familia.METAL_ALCALINO] == 6 and familias[Elementos.Familia.METAL_ALCALINOTERROSO] == 6 \
		and familias[Elementos.Familia.LANTANIDIO] == 15 and familias[Elementos.Familia.ACTINIDIO] == 15 \
		and familias[Elementos.Familia.SEMIMETAL] == 7 and familias[Elementos.Familia.NAO_METAL] == 7 \
		and familias[Elementos.Familia.METAL_DE_TRANSICAO] == 38 and familias[Elementos.Familia.OUTRO_METAL] == 11,
		"7 gases nobres, 6 halogênios, 6 alcalinos, 6 alcalinoterrosos, 15 + 15 embaixo, 7 semimetais, 7 não metais, 38 de transição e 11 outros metais %s" % [familias])
	_checar(Elementos.familia(1) == Elementos.Familia.NAO_METAL and Elementos.familia(11) == Elementos.Familia.METAL_ALCALINO \
		and Elementos.familia(14) == Elementos.Familia.SEMIMETAL and Elementos.familia(17) == Elementos.Familia.HALOGENIO \
		and Elementos.familia(18) == Elementos.Familia.GAS_NOBRE and Elementos.familia(26) == Elementos.Familia.METAL_DE_TRANSICAO \
		and Elementos.familia(13) == Elementos.Familia.OUTRO_METAL and Elementos.familia(92) == Elementos.Familia.ACTINIDIO,
		"H não metal, Na alcalino, Si semimetal, Cl halogênio, Ar gás nobre, Fe de transição, Al outro metal, U actinídio")
	_checar(Elementos.nome_da_familia(Elementos.Familia.GAS_NOBRE) == "gás nobre" \
		and Elementos.nome_da_familia(Elementos.Familia.GAS_NOBRE, true) == "gases nobres",
		"cada família tem o nome de um e o de todos")


func _testar_ions() -> void:
	print("\n--- OS ÍONS ---")
	_checar(Array(Elementos.camadas_com(6, 6)) == [2, 4] and Array(Elementos.camadas_com(79, 79)) == Array(Elementos.camadas(79)),
		"com tantos elétrons quanto prótons, é o átomo neutro")
	_checar(Array(Elementos.camadas_com(11, 10)) == [2, 8] and Array(Elementos.camadas_com(12, 10)) == [2, 8] \
		and Array(Elementos.camadas_com(13, 10)) == [2, 8], "Na⁺, Mg²⁺ e Al³⁺ ficam 2-8")
	_checar(Array(Elementos.camadas_com(26, 24)) == [2, 8, 14] and Array(Elementos.camadas_com(26, 23)) == [2, 8, 13],
		"o ferro perde primeiro os da camada N: Fe²⁺ 2-8-14, Fe³⁺ 2-8-13")
	_checar(Array(Elementos.camadas_com(29, 28)) == [2, 8, 18] and Array(Elementos.camadas_com(29, 27)) == [2, 8, 17] \
		and Array(Elementos.camadas_com(30, 28)) == [2, 8, 18], "Cu⁺ 2-8-18, Cu²⁺ 2-8-17, Zn²⁺ 2-8-18")
	_checar(Array(Elementos.camadas_com(46, 44)) == [2, 8, 18, 16] and Array(Elementos.camadas_com(47, 46)) == [2, 8, 18, 18],
		"Pd²⁺ 2-8-18-16 (o paládio não tem a camada O) e Ag⁺ 2-8-18-18")
	_checar(Array(Elementos.camadas_com(63, 61)) == [2, 8, 18, 25, 8] and Array(Elementos.camadas_com(63, 60)) == [2, 8, 18, 24, 8] \
		and Array(Elementos.camadas_com(58, 54)) == [2, 8, 18, 18, 8],
		"os lantanídios perdem a camada P e depois o subnível f: Eu²⁺, Eu³⁺, Ce⁴⁺")
	_checar(Array(Elementos.camadas_com(82, 80)) == [2, 8, 18, 32, 18, 2] and Array(Elementos.camadas_com(22, 18)) == [2, 8, 8],
		"Pb²⁺ fica com os dois da camada P; Ti⁴⁺ fica 2-8-8")
	_checar(Array(Elementos.camadas_com(17, 18)) == [2, 8, 8] and Array(Elementos.camadas_com(8, 10)) == [2, 8] \
		and Array(Elementos.camadas_com(1, 2)) == [2], "os ânions ficam como o gás nobre: Cl⁻ 2-8-8, O²⁻ 2-8, H⁻ 2")
	_checar(Elementos.camadas_com(1, 0).is_empty() and Elementos.camadas_com(92, 0).is_empty(),
		"sem elétron nenhum não há camada")
	_checar(Array(Elementos.camadas_com(0, 3)) == [2, 1] and Elementos.camadas_com(0, 0).is_empty(),
		"elétrons sem núcleo se arrumam como no átomo com aquele tanto")
	var erradas := PackedStringArray()
	for z in [1, 3, 11, 20, 26, 29, 47, 57, 64, 79, 92, 103, 118]:
		for eletrons in range(0, 119):
			var soma := 0
			var camadas := Elementos.camadas_com(z, eletrons)
			for i in camadas.size():
				soma += camadas[i]
				if camadas[i] > Elementos.CABEM_NAS_CAMADAS[i] or camadas[i] < 0:
					erradas.append("%d/%d camada" % [z, eletrons])
			if soma != eletrons:
				erradas.append("%d/%d soma %d" % [z, eletrons, soma])
	_checar(erradas.is_empty(), "qualquer tanto de elétrons, de 0 a 118, cabe nas camadas e soma certo %s" % [erradas.slice(0, 6)])
	_checar(Array(Elementos.camadas_com(6, 500)) == Array(Elementos.camadas(118)), "mais de 118 elétrons não cabem: param em 118")


func _testar_isotopos() -> void:
	print("\n--- OS ISÓTOPOS ---")
	_checar(Elementos.isotopo(1) == 1 and Elementos.neutrons(1) == 0 and Elementos.isotopo(6) == 12 \
		and Elementos.neutrons(6) == 6 and Elementos.isotopo(8) == 16 and Elementos.isotopo(92) == 238 \
		and Elementos.neutrons(92) == 146, "o mais comum: hidrogênio-1 (sem nêutron), carbono-12, oxigênio-16, urânio-238")
	_checar(Elementos.isotopo(29) == 63 and Elementos.isotopo(35) == 79 and Elementos.isotopo(47) == 107 \
		and Elementos.isotopo(30) == 64, "é o mais abundante, e não a massa arredondada: cobre-63, bromo-79, prata-107, zinco-64")
	var sem_bater := PackedStringArray()
	var naturais := 0
	for z: int in Elementos.ISOTOPOS_NATURAIS:
		var soma := 0.0
		var maior := -1
		var do_elemento: Dictionary = Elementos.ISOTOPOS_NATURAIS[z]
		for a: int in do_elemento:
			naturais += 1
			soma += float(do_elemento[a])
			if maior < 0 or float(do_elemento[a]) > float(do_elemento[maior]):
				maior = a
			if a < z:
				sem_bater.append("%s-%d" % [Elementos.simbolo(z), a])
		if absf(soma - 100.0) > 0.02 or maior != Elementos.isotopo(z):
			sem_bater.append("%s soma %.3f mais comum %d" % [Elementos.simbolo(z), soma, maior])
	_checar(sem_bater.is_empty(), "as abundâncias de cada elemento somam 100%% e a maior é a do isótopo dele %s" % [sem_bater])
	_checar(naturais == 288 and Elementos.ISOTOPOS_NATURAIS.size() == 84, "288 isótopos de 84 elementos existem na natureza")
	_checar(is_equal_approx(Elementos.abundancia(6, 12), 98.93) and is_equal_approx(Elementos.abundancia(6, 13), 1.07) \
		and Elementos.abundancia(6, 14) < 0.0 and Elementos.abundancia(43, 98) < 0.0 and Elementos.abundancia(0, 1) < 0.0,
		"carbono-12 é 98,93%% do carbono, o 13 é 1,07%%, e o 14 não está na lista")
	for z in [43, 61, 84, 86, 94, 118]:
		if Elementos.massa(z) != "[%d]" % Elementos.isotopo(z):
			sem_bater.append(Elementos.simbolo(z))
	_checar(sem_bater.is_empty(), "quem não existe na natureza tem por isótopo o do colchete %s" % [sem_bater])
	_checar(Elementos.nome_do_isotopo(6, 14) == "Carbono-14" and Elementos.apelido_do_isotopo(1, 2) == "deutério" \
		and Elementos.apelido_do_isotopo(1, 3) == "trítio" and Elementos.apelido_do_isotopo(6, 12) == "",
		"o isótopo se chama Carbono-14; os do hidrogênio têm apelido")


func _testar_escrita() -> void:
	print("\n--- COMO SE ESCREVE ---")
	_checar(Elementos.carga_no_simbolo(0) == "" and Elementos.carga_no_simbolo(1) == "+" \
		and Elementos.carga_no_simbolo(2) == "2+" and Elementos.carga_no_simbolo(-1) == "-" \
		and Elementos.carga_no_simbolo(-3) == "3-", "a carga em cima do símbolo: +, 2+, -, 3-")
	_checar(Elementos.carga_escrita(0) == "0" and Elementos.carga_escrita(2) == "+2" and Elementos.carga_escrita(-1) == "-1",
		"e por extenso: 0, +2, -1")
	_checar(FONTE.has_char("-".unicode_at(0)) and FONTE.has_char("+".unicode_at(0)), "o sinal de menos existe na fonte")
	_checar(Elementos.numero_com_virgula(98.93) == "98,93" and Elementos.numero_com_virgula(100.0) == "100" \
		and Elementos.numero_com_virgula(0.0115) == "0,0115" and Elementos.numero_com_virgula(0.000134) == "0,000134" \
		and Elementos.numero_com_virgula(99.9885) == "99,99" and Elementos.numero_com_virgula(0.0) == "0" \
		and Elementos.numero_com_virgula(7.59) == "7,59",
		"os números vão com vírgula e sem zero sobrando")
