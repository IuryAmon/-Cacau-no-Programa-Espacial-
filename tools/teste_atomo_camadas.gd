extends "res://tools/teste_de_tela.gd"

# Teste do desenho do átomo no modelo de camadas (scripts/ui/atomo_camadas.gd)
# e da notação do átomo (scripts/ui/notacao_do_atomo.gd): as duas peças que o
# "Monte seu átomo", o quiz e a ficha da tabela periódica usam.
#
#   * o nó nasce vazio, e mostrar_elemento() põe o átomo mais comum do elemento;
#   * para os 118 elementos: o núcleo tem os prótons e os nêutrons pedidos, os
#     elétrons ficam nas camadas da distribuição do elemento, o cacho de
#     partículas cabe dentro da linha do núcleo, as camadas crescem para fora e
#     a última cabe no quadro, com o elétron inteiro;
#   * o desenho se ajusta ao tamanho do átomo: partículas grandes num átomo
#     pequeno, pequenas num grande, sem nunca passar dos limites;
#   * nos íons, os elétrons saem (ou entram) na camada certa: Na+, Cl-, Fe2+,
#     Fe3+;
#   * pôr ou tirar UMA partícula não mexe nas outras do núcleo (quem monta
#     partícula por partícula vê cada uma ficar onde entrou);
#   * o núcleo grande, mostrado de uma vez, sai embaralhado sempre do mesmo
#     jeito, e não em braços de uma cor só;
#   * animando, os elétrons de uma camada se espalham por igual e giram; com
#     "girando" desligado, ficam parados;
#   * as miniaturas das partículas saem no tamanho pedido e são guardadas;
#   * a notação escreve A, Z e a carga com letras que a fonte tem, e os 118
#     átomos neutros cabem nela no tamanho cheio.
#
#   godot --headless --path . res://tools/teste_atomo_camadas.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma folha de átomos.


func _ready() -> void:
	await _comecar()
	await _testar_o_basico()
	await _testar_os_118()
	await _testar_os_ions()
	await _testar_uma_a_uma()
	await _testar_o_nucleo_grande()
	await _testar_o_movimento()
	_testar_as_miniaturas()
	await _testar_a_notacao()
	await _capturar()
	_terminar()


func _novo(lado: float = 400.0) -> AtomoCamadas:
	var atomo := AtomoCamadas.new()
	atomo.size = Vector2(lado, lado)
	add_child(atomo)
	return atomo


# ─────────────────────────────────────────────────────────────

func _testar_o_basico() -> void:
	print("\n--- O BÁSICO ---")
	var atomo := _novo()
	await _quadros(2)
	_checar(atomo.protons() == 0 and atomo.neutrons() == 0 and atomo.eletrons() == 0 \
		and atomo.eletrons_por_camada().is_empty(), "nasce vazio")
	_checar(atomo.mouse_filter == Control.MOUSE_FILTER_IGNORE, "não segura o clique de ninguém")

	atomo.mostrar_elemento(6, false)
	_checar(atomo.protons() == 6 and atomo.neutrons() == 6 and atomo.eletrons() == 6,
		"mostrar_elemento(6): o carbono-12, neutro (6 prótons, 6 nêutrons, 6 elétrons)")
	_checar(atomo.eletrons_por_camada() == PackedInt32Array([2, 4]), "com 2 elétrons na K e 4 na L")
	_checar(atomo.no_nucleo(AtomoCamadas.PROTON) == 6 and atomo.no_nucleo(AtomoCamadas.NEUTRON) == 6,
		"e 6 prótons e 6 nêutrons desenhados no núcleo")

	atomo.mostrar_elemento(1, false)
	_checar(atomo.neutrons() == 0 and atomo.eletrons_por_camada() == PackedInt32Array([1]),
		"o hidrogênio mais comum não tem nêutron")
	_checar(atomo._lugar_da_vaga(0, atomo.lado_da_particula()) == Vector2.ZERO,
		"uma partícula sozinha fica bem no meio do núcleo")

	atomo.mostrar_elemento(0, false)
	_checar(atomo.protons() == 0 and atomo.eletrons_por_camada().is_empty(), "mostrar_elemento(0) esvazia")
	atomo.mostrar_elemento(500, false)
	_checar(atomo.protons() == 0, "um elemento que não existe também")

	atomo.definir(-3, -1, 900, false)
	_checar(atomo.protons() == 0 and atomo.neutrons() == 0 and atomo.eletrons() == Elementos.TOTAL,
		"números absurdos são presos: nada negativo, no máximo 118 elétrons")
	_checar(atomo.eletrons_por_camada() == Elementos.camadas(Elementos.TOTAL),
		"elétrons sem núcleo se arrumam como no átomo neutro que tem esse tanto")

	# As medidas acompanham o tamanho do nó.
	atomo.mostrar_elemento(6, false)
	var raio_grande := atomo.raio_da_camada(1)
	_checar(is_equal_approx(atomo.raio_do_desenho(), 200.0 - atomo.margem), "o desenho vai até a margem do nó")
	atomo.size = Vector2(200, 200)
	await _quadros(1)
	_checar(is_equal_approx(atomo.raio_do_desenho(), 100.0 - atomo.margem) and atomo.raio_da_camada(1) < raio_grande,
		"num nó menor, o desenho encolhe junto")
	atomo.size = Vector2(300, 120)
	_checar(is_equal_approx(atomo.raio_do_desenho(), 60.0 - atomo.margem), "num nó que não é quadrado, vale o lado menor")
	atomo.queue_free()
	await _quadros(1)


func _testar_os_118() -> void:
	print("\n--- OS 118 ELEMENTOS ---")
	var atomo := _novo()
	await _quadros(1)
	var escala := atomo.raio_do_desenho() / 200.0
	var errados := PackedStringArray()
	var menor_lado := INF
	var maior_lado := 0.0
	var menor_passo := INF
	for z in range(1, Elementos.TOTAL + 1):
		atomo.mostrar_elemento(z, false)
		var s := Elementos.simbolo(z)
		var problema := ""
		if atomo.no_nucleo(AtomoCamadas.PROTON) != z or atomo.no_nucleo(AtomoCamadas.NEUTRON) != Elementos.neutrons(z):
			problema += " núcleo"
		if atomo.eletrons_por_camada() != Elementos.camadas(z):
			problema += " camadas %s" % [atomo.eletrons_por_camada()]
		# O cacho de partículas cabe dentro da linha tracejada do núcleo.
		var lado := atomo.lado_da_particula()
		var cacho := 0.0
		for i in atomo._vagas.size():
			cacho = maxf(cacho, atomo._lugar_da_vaga(i, lado).length() + lado * 0.5)
		if cacho > atomo.raio_do_nucleo() + 0.5:
			problema += " cacho %.1f > núcleo %.1f" % [cacho, atomo.raio_do_nucleo()]
		if lado < AtomoCamadas.LADO_MINIMO - 0.01 or lado > AtomoCamadas.LADO_MAXIMO * escala + 0.01:
			problema += " lado %.1f" % lado
		# As camadas: fora do núcleo, cada uma mais longe que a anterior, e a
		# última dentro do quadro com o elétron inteiro.
		var camadas := atomo.eletrons_por_camada().size()
		var anterior := atomo.raio_do_nucleo()
		for c in camadas:
			var raio := atomo.raio_da_camada(c)
			if raio <= anterior + 1.0:
				problema += " camada %d não cresce" % c
			if c > 0:
				menor_passo = minf(menor_passo, raio - anterior)
			anterior = raio
		if atomo.raio_da_camada(camadas - 1) > atomo.raio_do_desenho() + 0.5:
			problema += " última camada fora do quadro"
		if atomo.raio_da_camada(camadas - 1) + atomo.lado_do_eletron() * 0.5 > minf(atomo.size.x, atomo.size.y) * 0.5 + 0.5:
			problema += " elétron fora do nó"
		if not problema.is_empty():
			errados.append(s + ":" + problema)
		menor_lado = minf(menor_lado, lado)
		maior_lado = maxf(maior_lado, lado)
	_checar(errados.is_empty(), "do hidrogênio ao oganessônio: núcleo, camadas e medidas certos %s" % [errados])
	_checar(is_equal_approx(maior_lado, AtomoCamadas.LADO_MAXIMO * escala) and menor_lado < maior_lado * 0.5,
		"o átomo pequeno tem partículas grandes (%.0f px) e o grande, pequenas (%.1f px)" % [maior_lado, menor_lado])
	_checar(menor_passo >= atomo.lado_do_eletron() * 0.9,
		"mesmo com as 7 camadas, um elétron não encosta na camada vizinha (%.1f px entre elas)" % menor_passo)
	atomo.queue_free()
	await _quadros(1)


func _testar_os_ions() -> void:
	print("\n--- OS ÍONS ---")
	var atomo := _novo()
	var casos := [
		[11, 12, 10, [2, 8], "Na+ perde o elétron da camada M"],
		[17, 18, 18, [2, 8, 8], "Cl- ganha um elétron na camada M"],
		[8, 8, 10, [2, 8], "O2- fica com a camada L cheia"],
		[20, 20, 18, [2, 8, 8], "Ca2+ perde os dois da camada N"],
		[26, 30, 24, [2, 8, 14], "Fe2+ perde os dois da camada N (e não os da M)"],
		[26, 30, 23, [2, 8, 13], "Fe3+ perde mais um, agora da M"],
		[1, 0, 0, [], "H+ é só o próton"],
		[1, 0, 2, [2], "H- tem a camada K cheia"],
	]
	for caso: Array in casos:
		atomo.definir(caso[0], caso[1], caso[2], false)
		_checar(atomo.eletrons_por_camada() == PackedInt32Array(caso[3]),
			"%s %s" % [caso[4], atomo.eletrons_por_camada()])
	atomo.queue_free()
	await _quadros(1)


func _testar_uma_a_uma() -> void:
	print("\n--- PARTÍCULA POR PARTÍCULA ---")
	var atomo := _novo()
	# Monta o lítio-7 clicando: p, n, p, n, n, p, n.
	var p := 0
	var n := 0
	var ordem := [AtomoCamadas.PROTON, AtomoCamadas.NEUTRON, AtomoCamadas.PROTON, AtomoCamadas.NEUTRON,
		AtomoCamadas.NEUTRON, AtomoCamadas.PROTON, AtomoCamadas.NEUTRON]
	for tipo: int in ordem:
		if tipo == AtomoCamadas.PROTON:
			p += 1
		else:
			n += 1
		atomo.definir(p, n, 0)
	_checar(Array(atomo._vagas) == ordem, "cada partícula fica na vaga em que entrou, do meio para fora")

	var antes := atomo._vagas.duplicate()
	atomo.definir(4, 4, 0)
	_checar(atomo._vagas.slice(0, 7) == antes and atomo._vagas[7] == AtomoCamadas.PROTON,
		"pôr um próton não mexe nas outras: ele entra na primeira vaga livre")
	_checar(atomo._idade_das_vagas[7] == 0.0, "e nasce agora (é ele que dá o estalo)")

	# Tirar um nêutron: sai o de fora (a vaga 6), e a vaga fica aberta.
	atomo.definir(4, 3, 0)
	_checar(atomo._vagas[6] == AtomoCamadas.VAZIO and atomo._vagas[7] == AtomoCamadas.PROTON \
		and atomo.no_nucleo(AtomoCamadas.NEUTRON) == 3, "tirar um nêutron tira o mais de fora e deixa a vaga")
	atomo.definir(4, 4, 0)
	_checar(atomo._vagas[6] == AtomoCamadas.NEUTRON and atomo._vagas.size() == 8,
		"o próximo que entra ocupa a vaga que ficou aberta")
	atomo.definir(3, 4, 0)
	_checar(atomo._vagas.size() == 7, "tirando a partícula da ponta, as vagas vazias do fim somem")

	# Elétron a elétron: 2 na K e depois a L.
	for e in range(1, 5):
		atomo.definir(3, 4, e)
	_checar(atomo.eletrons_por_camada() == PackedInt32Array([2, 2]), "elétron por elétron: a K enche com 2, o resto vai para a L")
	atomo.definir(3, 4, 3)
	_checar(atomo.eletrons_por_camada() == PackedInt32Array([2, 1]), "e tirar um elétron tira da camada de fora")
	atomo.queue_free()
	await _quadros(1)


func _testar_o_nucleo_grande() -> void:
	print("\n--- O NÚCLEO GRANDE ---")
	var um := _novo()
	var outro := _novo()
	um.mostrar_elemento(92, false)
	outro.mostrar_elemento(92, false)
	_checar(um._vagas == outro._vagas, "o mesmo núcleo sai sempre embaralhado do mesmo jeito")
	_checar(um.no_nucleo(AtomoCamadas.PROTON) == 92 and um.no_nucleo(AtomoCamadas.NEUTRON) == 146,
		"o urânio-238: 92 prótons e 146 nêutrons no desenho")
	# Embaralhado de verdade: há prótons vizinhos e nêutrons vizinhos nas vagas
	# (alternado, os prótons cairiam de 2,6 em 2,6 vagas, sem nunca se tocar).
	var protons_vizinhos := 0
	for i in range(1, um._vagas.size()):
		if um._vagas[i] == AtomoCamadas.PROTON and um._vagas[i - 1] == AtomoCamadas.PROTON:
			protons_vizinhos += 1
	_checar(protons_vizinhos >= 10, "os prótons não ficam em fila certinha (%d pares vizinhos)" % protons_vizinhos)
	# Misturado do meio até a beirada: a metade de dentro tem perto de metade
	# dos prótons.
	var dentro := 0
	for i in 119:
		if um._vagas[i] == AtomoCamadas.PROTON:
			dentro += 1
	_checar(dentro >= 34 and dentro <= 58, "e ficam misturados do meio à beirada (%d dos 92 na metade de dentro)" % dentro)

	um.mostrar_elemento(8, false)
	var alternado := true
	for i in range(1, um._vagas.size()):
		if um._vagas[i] == um._vagas[i - 1]:
			alternado = false
	_checar(alternado, "o núcleo pequeno (oxigênio-16) alterna próton e nêutron")
	um.queue_free()
	outro.queue_free()
	await _quadros(1)


func _testar_o_movimento() -> void:
	print("\n--- O MOVIMENTO ---")
	var atomo := _novo()
	atomo.set_process(false)
	atomo.definir(8, 8, 8)
	_checar(is_nan(float(atomo._camadas[0][0]["raio"])) and float(atomo._camadas[0][0]["idade"]) == 0.0,
		"animando, o elétron novo acabou de nascer")
	for i in 120:
		atomo.avancar(1.0 / 60.0)
	# Cada elétron corre atrás do lugar dele na camada (que gira): o que se
	# confere é o vão entre um e o seguinte, igual para todos.
	var por_igual := true
	for c in 2:
		var camada: Array = atomo._camadas[c]
		for i in camada.size():
			var seguinte: Dictionary = camada[(i + 1) % camada.size()]
			var vao := fposmod(float(seguinte["angulo"]) - float(camada[i]["angulo"]), TAU)
			if absf(vao - TAU / camada.size()) > 0.02:
				por_igual = false
			if absf(float(camada[i]["raio"]) - atomo.raio_da_camada(c)) > 0.5:
				por_igual = false
	_checar(por_igual, "em 2 segundos cada elétron está no raio da camada dele, espalhados por igual")
	_checar(atomo._a_vista[0] == 1.0 and atomo._a_vista[1] == 1.0 and atomo._a_vista[2] == 0.0,
		"as camadas com elétron aparecem; as vazias, não")

	var fase := atomo._fases[0]
	atomo.avancar(0.1)
	_checar(not is_equal_approx(atomo._fases[0], fase), "girando, a camada anda")
	_checar(float(AtomoCamadas.VELOCIDADES[0]) > float(AtomoCamadas.VELOCIDADES[1]),
		"a camada K gira mais depressa que a L")
	atomo.girando = false
	fase = atomo._fases[0]
	atomo.avancar(0.5)
	_checar(is_equal_approx(atomo._fases[0], fase), "com \"girando\" desligado, ela para")

	# Trocar de átomo de uma vez: o desenho vai ao tamanho novo aos poucos.
	atomo.girando = true
	var lado_antes := atomo._lado
	atomo.definir(92, 146, 92)
	atomo.avancar(1.0 / 60.0)
	_checar(atomo._lado < lado_antes and atomo._lado > atomo.lado_da_particula() + 1.0,
		"trocando de átomo, as partículas encolhem aos poucos, sem pulo")
	for i in 120:
		atomo.avancar(1.0 / 60.0)
	_checar(absf(atomo._lado - atomo.lado_da_particula()) < 0.1, "e chegam ao tamanho certo")
	atomo.definir(1, 0, 1)
	atomo.assentar()
	_checar(is_equal_approx(atomo._lado, atomo.lado_da_particula()), "assentar() leva ao tamanho certo de uma vez")
	atomo.queue_free()
	await _quadros(1)


func _testar_as_miniaturas() -> void:
	print("\n--- AS MINIATURAS ---")
	var pequena := AtomoCamadas.miniatura("proton", 12)
	_checar(pequena.get_size() == Vector2(12, 12), "a miniatura sai no tamanho pedido (12 px)")
	_checar(AtomoCamadas.miniatura("proton", 12) == pequena, "e é feita uma vez só")
	_checar(AtomoCamadas.miniatura("neutron", 12) != pequena, "o nêutron tem a dele")
	var img := pequena.get_image()
	var meio := img.get_pixel(6, 6)
	_checar(meio.a > 0.9 and img.get_pixel(0, 0).a < 0.1, "é uma bolinha: cheia no meio, vazia no canto")
	var inteira := AtomoCamadas.miniatura("eletron", 200)
	_checar(inteira is AtlasTexture and (inteira as AtlasTexture).region == Rect2(AtomoCamadas.RECORTES["eletron"]),
		"maior que a arte, usa a arte inteira, sem ampliar")
	_checar(AtomoCamadas.miniatura("proton", 0).get_size() == Vector2(2, 2), "nunca menor que 2 px")


func _testar_a_notacao() -> void:
	print("\n--- A NOTAÇÃO DO ÁTOMO ---")
	var notacao := NotacaoDoAtomo.new()
	notacao.size = Vector2(202, 80)
	add_child(notacao)
	await _quadros(1)
	notacao.definir("Na", 23, 11, 1)
	_checar(notacao.simbolo == "Na" and notacao.massa == 23 and notacao.numero_atomico == 11 and notacao.carga == 1,
		"definir() guarda o símbolo, A, Z e a carga")
	var com_carga := notacao.largura_do_conjunto()
	notacao.carga = 0
	_checar(notacao.largura_do_conjunto() < com_carga, "o átomo neutro não escreve carga")
	_checar(Elementos.carga_no_simbolo(0) == "" and Elementos.carga_no_simbolo(1) == "+" \
		and Elementos.carga_no_simbolo(-1) == "-" and Elementos.carga_no_simbolo(3) == "3+" \
		and Elementos.carga_no_simbolo(-2) == "2-", "a carga em cima do símbolo: +, -, 3+, 2-")
	_checar(Elementos.carga_escrita(0) == "0" and Elementos.carga_escrita(2) == "+2" and Elementos.carga_escrita(-1) == "-1",
		"a carga por extenso: 0, +2, -1")
	var textos: Array = ["0123456789+-"]
	for z in range(1, Elementos.TOTAL + 1):
		textos.append(Elementos.simbolo(z))
	_checar(_letras_que_faltam(textos).is_empty(), "todo símbolo, número e sinal existe na fonte [%s]" % _letras_que_faltam(textos))

	# O mais largo que o "Monte seu átomo" consegue montar: o núcleo mais pesado
	# sem elétron nenhum (carga de três algarismos). Se passar do nó, a notação
	# encolhe até caber; aqui só se mede o quanto.
	var mais_largo := 0.0
	var qual := ""
	for z in range(1, Elementos.TOTAL + 1):
		notacao.definir(Elementos.simbolo(z), z + 177, z, z)
		if notacao.largura_do_conjunto() > mais_largo:
			mais_largo = notacao.largura_do_conjunto()
			qual = Elementos.simbolo(z)
	print("  .     o caso mais largo: %s sem elétrons, %.0f px num nó de %.0f (%s)" % [qual, mais_largo,
		notacao.size.x, "encolhe" if mais_largo > notacao.size.x - 2.0 else "cabe inteiro"])
	var cabem := 0
	for z in range(1, Elementos.TOTAL + 1):
		notacao.definir(Elementos.simbolo(z), Elementos.isotopo(z), z, 0)
		if notacao.largura_do_conjunto() <= notacao.size.x - 2.0:
			cabem += 1
	_checar(cabem == Elementos.TOTAL, "os 118 átomos neutros cabem no tamanho cheio (%d de 118)" % cabem)
	notacao.queue_free()
	await _quadros(1)


# ─────────────────────────────────────────────────────────────

func _capturar() -> void:
	if _pasta_capturas.is_empty():
		return
	var fundo := ColorRect.new()
	fundo.color = Color("0a1420")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var casos := [[1, 0, 1], [6, 6, 6], [11, 12, 10], [26, 30, 26], [92, 146, 92], [118, 176, 118]]
	for i in casos.size():
		var atomo := AtomoCamadas.new()
		atomo.size = Vector2(400, 400)
		atomo.position = Vector2(60 + (i % 3) * 500, 30 + int(i / 3.0) * 430)
		fundo.add_child(atomo)
		atomo.definir(casos[i][0], casos[i][1], casos[i][2], false)
	await _foto("atomos")
