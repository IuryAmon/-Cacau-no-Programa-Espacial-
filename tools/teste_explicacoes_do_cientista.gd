extends Node

# Teste das explicações do cientista nos puzzles de átomo do world1
# (scripts/ui/explicacao_no_puzzle.gd, scripts/puzzle_hidrogenio.gd e
# scripts/puzzle_oxigenio.gd):
#
#   * as falas existem, estão registradas no Dialogic, não citam o "Dr. Chico"
#     (no world1 ele ainda é o Desconhecido) e a primeira de cada puzzle
#     pergunta, com "Já sei montar" como SEGUNDA opção; as duas pontas (a
#     explicação inteira e o pulo) anotam a nota no caderno;
#   * a explicação inteira do hidrogênio: o holofote na caixinha e no Z; no
#     passo do próton só ele responde e a seta aponta para ele; com o próton
#     no núcleo, a fala do A, dos nêutrons e do elétron; depois a pessoa
#     termina sozinha e a última fala anota "atomo";
#   * "Já sei montar" anota na hora, o roteiro acaba e o puzzle fica livre;
#   * fechar no meio não anota nada, e reabrir começa de novo;
#   * com a nota no caderno, o puzzle abre sem explicação;
#   * o mesmo para o oxigênio (no passo da camada K, a L não aceita).
#
#   godot --headless --path . res://tools/teste_explicacoes_do_cientista.tscn

const PUZZLE_H := "res://scenes/puzzle_hidrogenio.tscn"
const PUZZLE_O := "res://scenes/puzzle_oxigenio.tscn"
## Cada fala nova e a nota que ela anota ("" = não anota).
const FALAS := {
	"cientista_hidrogenio_1": "atomo",
	"cientista_hidrogenio_2": "",
	"cientista_hidrogenio_3": "atomo",
	"cientista_oxigenio_1": "eletrosfera",
	"cientista_oxigenio_2": "",
	"cientista_oxigenio_3": "eletrosfera",
}

var _falhas := 0


func _ready() -> void:
	# Sai do _ready da árvore antes de pendurar cenas na raiz.
	await get_tree().process_frame
	_testar_falas()
	await _testar_hidrogenio_explicado()
	await _testar_hidrogenio_pulado()
	await _testar_fechar_no_meio()
	await _testar_oxigenio_explicado()
	await _testar_oxigenio_pulado()
	PaginasCaderno.esquecer_notas()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	if condicao:
		print("  ok    ", descricao)
	else:
		_falhas += 1
		print("  FALHA ", descricao)


# ------------------------- AS FALAS -------------------------

func _testar_falas() -> void:
	print("\n--- as falas")
	var registro: Dictionary = ProjectSettings.get_setting("dialogic/directories/dtl_directory", {})
	for nome: String in FALAS:
		var caminho := "res://timelines/%s.dtl" % nome
		_checar(FileAccess.file_exists(caminho), "%s existe" % nome)
		_checar(registro.get(nome, "") == caminho, "%s está registrada no Dialogic" % nome)
		var texto := FileAccess.get_file_as_string(caminho)
		_checar(not texto.contains("Dr. Chico"), "%s não chama ele de Dr. Chico (no world1 ele é o Desconhecido)" % nome)
		var sem_parenteses := true
		for linha in texto.split("\n"):
			var fala := linha.strip_edges()
			if fala.begins_with("cientista") and fala.contains(": "):
				var dita := fala.substr(fala.find(": ") + 2)
				if dita.contains("(") or dita.contains(")"):
					sem_parenteses = false
		_checar(sem_parenteses, "%s: nada de parênteses no texto (o Dialogic leria como retrato)" % nome)
		var nota: String = FALAS[nome]
		if nota.is_empty():
			_checar(not texto.contains("Caderno.anotar"), "%s não anota nada" % nome)
			continue
		var anotar := "do Caderno.anotar(\"%s\")" % nota
		if not nome.ends_with("_1"):
			_checar(texto.contains(anotar), "%s anota \"%s\" no fim" % [nome, nota])
			continue
		var opcoes: Array[String] = []
		var ramo_de_pular := ""
		var no_pulo := false
		for linha in texto.split("\n"):
			if linha.begins_with("- "):
				opcoes.append(linha.substr(2).strip_edges())
				no_pulo = linha.begins_with("- Já sei")
			elif no_pulo and linha.begins_with("\t"):
				ramo_de_pular += linha.strip_edges() + "\n"
		_checar(opcoes.size() == 2, "%s pergunta com duas opções (%s)" % [nome, opcoes])
		_checar(opcoes.size() == 2 and opcoes[1].begins_with("Já sei"),
			"%s: a segunda opção é a de pular" % nome)
		_checar(ramo_de_pular.contains("[signal arg=\"%s\"]" % ExplicacaoNoPuzzle.SINAL_PULAR),
			"%s: pular avisa o roteiro" % nome)
		_checar(ramo_de_pular.contains(anotar), "%s: pular também anota \"%s\"" % [nome, nota])
		_checar(texto.count(anotar) == 1, "%s: a explicação continua na fala seguinte e não anota antes da hora" % nome)


# ------------------------- O HIDROGÊNIO -------------------------

func _testar_hidrogenio_explicado() -> void:
	print("\n--- hidrogênio: a explicação inteira")
	PaginasCaderno.esquecer_notas()
	var puzzle: CanvasLayer = await _montar(PUZZLE_H)
	puzzle.abrir_puzzle()
	_checar(await _esperar(func() -> bool: return Dialogic.current_timeline != null, 3.0),
		"sem a nota no caderno, abrir começa a explicação")
	_checar(puzzle.explicacao.falando, "o puzzle sabe que ele está falando")
	_checar(not puzzle.destaque.esta_ativo(), "a pergunta vem sem holofote")
	_checar(await _ate_a_pergunta(), "a primeira fala pergunta se quer a explicação")
	_checar(await _escolher(1), "escolheu \"Quero, me explica!\"")
	_checar(await _esperar_texto("caixinha"), "ele começa pela caixinha")
	_checar(_tem_furo(puzzle, "caixa"), "o holofote acende a caixinha")
	_checar(await _avancar_ate("número de cima"), "o número de cima é o Z")
	_checar(_tem_enfase(puzzle, "caixa_z"), "no Z, a ênfase vai no número de cima")

	# Enquanto ele fala, o puzzle não pega nada.
	var clique := InputEventMouseButton.new()
	clique.button_index = MOUSE_BUTTON_LEFT
	clique.pressed = true
	clique.position = _centro(puzzle.peca_proton)
	puzzle._input(clique)
	_checar(puzzle.peca_arrastando == null, "com a fala na tela, clicar no puzzle não pega a peça")

	_checar(await _passar_ate_acabar(puzzle), "a primeira fala acaba")
	_checar(puzzle.explicacao.ativa() and puzzle.explicacao.acao() == "proton", "o passo pede o próton")
	_checar(puzzle.destaque.tem_seta(), "a seta aponta para o próton")
	_checar(_tem_furo(puzzle, "nucleo"), "o núcleo, onde ele vai, fica aceso")
	var alvos: Array[Rect2] = puzzle.alvos_do_cursor()
	_checar(alvos.size() == 1 and alvos[0] == puzzle.peca_proton.get_global_rect(),
		"no controle, o cursor só oferece o próton")

	puzzle._iniciar_arrasto(_centro(puzzle.peca_neutron))
	_checar(puzzle.peca_arrastando == null, "no passo do próton, o nêutron não sai do lugar")
	puzzle._iniciar_arrasto(_centro(puzzle.peca_proton))
	_checar(puzzle.peca_arrastando == puzzle.peca_proton, "o próton responde")
	puzzle._soltar_peca(puzzle.nucleus_center)
	_checar(puzzle.proton_colocado, "próton no núcleo")

	_checar(await _esperar(func() -> bool: return puzzle.explicacao.falando and Dialogic.current_timeline != null, 3.0),
		"com o próton no núcleo, ele volta a falar")
	_checar(await _esperar_texto("1 próton no núcleo"), "ele comemora o próton")
	_checar(_tem_enfase(puzzle, "contagem_proton"), "a ênfase vai na contagem do próton")
	_checar(await _avancar_ate("massa atômica"), "o número de baixo é a massa, o A")
	_checar(_tem_enfase(puzzle, "caixa_a"), "na massa, a ênfase vai no número de baixo")
	_checar(await _avancar_ate("dá zero"), "nêutrons = massa - prótons = 0")
	_checar(_tem_enfase(puzzle, "contagem_neutron"), "nos nêutrons, a ênfase vai na contagem do nêutron")
	_checar(_longe_do_nome(puzzle), "a ênfase não fica embaixo do nome de quem fala")
	_checar(await _avancar_ate("elétrons"), "os elétrons: tantos quanto os prótons")
	_checar(_tem_furo(puzzle, "eletrosfera"), "nos elétrons, o holofote acende a eletrosfera")
	_checar(await _passar_ate_acabar(puzzle), "a segunda fala acaba")
	_checar(puzzle.explicacao.ativa() and puzzle.explicacao.acao() == "",
		"depois, a pessoa termina sozinha")
	_checar(not puzzle.destaque.esta_ativo(), "sem holofote na vez da pessoa")
	_checar(not Caderno.tem_nota("atomo"), "a nota ainda não foi anotada")

	puzzle._iniciar_arrasto(_centro(puzzle.peca_eletron))
	_checar(puzzle.peca_arrastando == puzzle.peca_eletron, "agora o elétron também responde")
	puzzle._soltar_peca(puzzle.nucleus_center + Vector2(puzzle.raio_orbita, 0.0))
	_checar(puzzle.travado, "próton + elétron, sem nêutron: resolvido")
	_checar(await _esperar(func() -> bool: return puzzle.explicacao.falando and Dialogic.current_timeline != null, 3.0),
		"resolvido, ele fala de novo")
	_checar(await _esperar_texto("Perfeito"), "ele confere o átomo")
	_checar(await _passar_ate_acabar(puzzle), "a última fala acaba")
	_checar(Caderno.tem_nota("atomo"), "a explicação inteira anota \"atomo\" no caderno")
	_checar(not puzzle.explicacao.ativa(), "o roteiro acabou")
	_checar(not puzzle.destaque.esta_ativo(), "o holofote apagou")

	puzzle.fechar_puzzle(true)
	puzzle.abrir_puzzle()
	await _esperar_segundos(0.5)
	_checar(Dialogic.current_timeline == null and not puzzle.explicacao.ativa(),
		"com a nota no caderno, o puzzle abre sem explicação")
	puzzle.fechar_puzzle(false)
	await _desmontar(puzzle)


func _testar_hidrogenio_pulado() -> void:
	print("\n--- hidrogênio: \"Já sei montar\"")
	PaginasCaderno.esquecer_notas()
	var puzzle: CanvasLayer = await _montar(PUZZLE_H)
	puzzle.abrir_puzzle()
	_checar(await _ate_a_pergunta(), "a primeira fala pergunta")
	_checar(await _escolher(2), "escolheu \"Já sei montar\"")
	_checar(await _passar_ate_acabar(puzzle), "a fala de quem pulou acaba")
	_checar(Caderno.tem_nota("atomo"), "pular também anota \"atomo\" no caderno")
	_checar(puzzle.explicacao.pulou() and not puzzle.explicacao.ativa(), "o roteiro acabou ali")
	_checar(not puzzle.destaque.esta_ativo(), "sem holofote")
	puzzle._iniciar_arrasto(_centro(puzzle.peca_neutron))
	_checar(puzzle.peca_arrastando == puzzle.peca_neutron, "o puzzle fica livre (o nêutron responde)")
	puzzle._soltar_peca(Vector2.ZERO)
	puzzle.fechar_puzzle(false)
	await _desmontar(puzzle)


func _testar_fechar_no_meio() -> void:
	print("\n--- fechar no meio da explicação")
	PaginasCaderno.esquecer_notas()
	var puzzle: CanvasLayer = await _montar(PUZZLE_H)
	puzzle.abrir_puzzle()
	_checar(await _ate_a_pergunta(), "a primeira fala pergunta")
	_checar(await _escolher(1), "escolheu a explicação")
	_checar(await _esperar_texto("caixinha"), "ele começou a explicar")
	puzzle.fechar_puzzle(false)
	await _esperar_segundos(0.3)
	_checar(Dialogic.current_timeline == null, "fechar o puzzle acaba a fala")
	_checar(not puzzle.explicacao.ativa() and not puzzle.explicacao.falando, "o roteiro parou")
	_checar(not puzzle.destaque.esta_ativo(), "o holofote apagou")
	_checar(not Caderno.tem_nota("atomo"), "sem a explicação inteira, nada foi anotado")
	puzzle.abrir_puzzle()
	_checar(await _esperar(func() -> bool: return Dialogic.current_timeline != null, 3.0),
		"reabrir começa a explicação de novo")
	puzzle.fechar_puzzle(false)
	await _desmontar(puzzle)


# ------------------------- O OXIGÊNIO -------------------------

func _testar_oxigenio_explicado() -> void:
	print("\n--- oxigênio: a explicação inteira")
	PaginasCaderno.esquecer_notas()
	var puzzle: CanvasLayer = await _montar(PUZZLE_O)
	puzzle.abrir_puzzle()
	_checar(await _ate_a_pergunta(), "a primeira fala pergunta se quer a explicação")
	_checar(await _escolher(1), "escolheu \"Quero, me explica!\"")
	_checar(await _esperar_texto("número de cima"), "ele começa pelo Z da caixinha")
	_checar(_tem_enfase(puzzle, "caixa_z"), "no Z, a ênfase vai no número de cima")
	_checar(await _avancar_ate("camadas"), "os elétrons ficam em camadas")
	_checar(_tem_furo(puzzle, "atomo") and _tem_enfase(puzzle, "anel_k") and _tem_enfase(puzzle, "anel_l"),
		"nas camadas, o holofote acende o átomo e marca os dois anéis")
	_checar(await _avancar_ate("a menor"), "a camada K é a menor")
	_checar(_tem_furo(puzzle, "camada_k") and _tem_enfase(puzzle, "anel_k"),
		"na camada K, o holofote vai só nela")
	_checar(_longe_do_nome(puzzle), "nada do que ele acende fica embaixo do nome de quem fala")
	_checar(await _passar_ate_acabar(puzzle), "a primeira fala acaba")
	_checar(puzzle.explicacao.acao() == "eletron_k", "o passo pede elétrons na camada K")
	_checar(puzzle.destaque.tem_seta(), "a seta aponta para o elétron")
	_checar(_tem_furo(puzzle, "contagem_k"), "sem fala na tela, o contador da K acende junto")

	var na_k: Vector2 = puzzle.nucleus_center + Vector2(puzzle.ORBIT_RADIUS_K, 0.0)
	var na_l: Vector2 = puzzle.nucleus_center + Vector2(puzzle.ORBIT_RADIUS_L, 0.0)
	puzzle._iniciar_arrasto(_centro(puzzle.electrons_disponiveis[0]))
	_checar(puzzle.peca_arrastando != null, "o elétron da vez responde")
	puzzle._soltar_peca(na_l)
	_checar(puzzle.electrons_l.is_empty(), "no passo da camada K, a L não aceita")
	await _esperar_segundos(0.3)
	for i in 2:
		puzzle._iniciar_arrasto(_centro(puzzle.electrons_disponiveis[0]))
		puzzle._soltar_peca(na_k)
		await _esperar_segundos(0.05)
	_checar(puzzle.electrons_k.size() == 2, "dois elétrons na camada K")

	_checar(await _esperar(func() -> bool: return puzzle.explicacao.falando and Dialogic.current_timeline != null, 3.0),
		"com a K cheia, ele volta a falar")
	_checar(await _esperar_texto("Camada K cheia"), "ele comemora a camada K")
	_checar(_tem_furo(puzzle, "camada_k"), "o holofote mostra os dois elétrons na K")
	_checar(await _avancar_ate("camada L"), "o resto vai para a camada L")
	_checar(_tem_enfase(puzzle, "anel_l"), "na camada L, a ênfase vai no anel de fora")
	_checar(await _avancar_ate("Quantos faltam"), "8 ao todo, 2 na K: quantos faltam?")
	_checar(_tem_enfase(puzzle, "caixa_z") and _tem_furo(puzzle, "camada_k"),
		"o 8 da caixinha e os 2 da K ficam acesos")
	_checar(_longe_do_nome(puzzle), "nada do que ele acende fica embaixo do nome de quem fala")
	_checar(await _passar_ate_acabar(puzzle), "a segunda fala acaba")
	_checar(puzzle.explicacao.ativa() and puzzle.explicacao.acao() == "", "depois, a pessoa termina sozinha")

	for i in 6:
		puzzle._iniciar_arrasto(_centro(puzzle.electrons_disponiveis[0]))
		puzzle._soltar_peca(na_l)
		await _esperar_segundos(0.05)
	_checar(puzzle.travado, "2 na K e 6 na L: resolvido")
	_checar(await _esperar(func() -> bool: return puzzle.explicacao.falando and Dialogic.current_timeline != null, 3.0),
		"resolvido, ele fala de novo")
	_checar(await _passar_ate_acabar(puzzle), "a última fala acaba")
	_checar(Caderno.tem_nota("eletrosfera"), "a explicação inteira anota \"eletrosfera\" no caderno")
	_checar(not puzzle.explicacao.ativa() and not puzzle.destaque.esta_ativo(), "o roteiro acabou")

	puzzle.fechar_puzzle(true)
	puzzle.abrir_puzzle()
	await _esperar_segundos(0.5)
	_checar(Dialogic.current_timeline == null and not puzzle.explicacao.ativa(),
		"com a nota no caderno, o puzzle abre sem explicação")
	puzzle.fechar_puzzle(false)
	await _desmontar(puzzle)


func _testar_oxigenio_pulado() -> void:
	print("\n--- oxigênio: \"Já sei montar\"")
	PaginasCaderno.esquecer_notas()
	var puzzle: CanvasLayer = await _montar(PUZZLE_O)
	puzzle.abrir_puzzle()
	_checar(await _ate_a_pergunta(), "a primeira fala pergunta")
	_checar(await _escolher(2), "escolheu \"Já sei montar\"")
	_checar(await _passar_ate_acabar(puzzle), "a fala de quem pulou acaba")
	_checar(Caderno.tem_nota("eletrosfera"), "pular também anota \"eletrosfera\" no caderno")
	_checar(not Caderno.tem_nota("atomo"), "e só ela")
	_checar(puzzle.explicacao.pulou() and not puzzle.explicacao.ativa(), "o roteiro acabou ali")
	var na_l: Vector2 = puzzle.nucleus_center + Vector2(puzzle.ORBIT_RADIUS_L, 0.0)
	puzzle._iniciar_arrasto(_centro(puzzle.electrons_disponiveis[0]))
	puzzle._soltar_peca(na_l)
	_checar(puzzle.electrons_l.size() == 1, "o puzzle fica livre (a camada L aceita)")
	puzzle.fechar_puzzle(false)
	await _desmontar(puzzle)


# ------------------------- AJUDANTES -------------------------

func _montar(cena: String) -> CanvasLayer:
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline(true)
	var puzzle: CanvasLayer = (load(cena) as PackedScene).instantiate()
	get_tree().root.add_child(puzzle)
	# O _ready guarda as posições de partida um quadro depois.
	for i in 5:
		await get_tree().process_frame
	return puzzle


func _desmontar(puzzle: CanvasLayer) -> void:
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline(true)
	puzzle.queue_free()
	for i in 3:
		await get_tree().process_frame


func _centro(peca: Control) -> Vector2:
	return peca.get_global_rect().get_center()


## O holofote tem um furo que cobre este lugar (pelo nome do ROTEIRO)?
func _tem_furo(puzzle: CanvasLayer, nome: String) -> bool:
	var destaque: DestaqueTutorial = puzzle.destaque
	var na_tela: Rect2 = puzzle.retangulos_para([nome])[0]
	var esperado: Rect2 = destaque.get_global_transform().affine_inverse() * na_tela
	for furo: Rect2 in destaque._furos_para:
		if furo.grow(1.0).encloses(esperado):
			return destaque.esta_ativo()
	return false


## O holofote tem a caixa de ênfase neste lugar (pelo nome do ROTEIRO)?
func _tem_enfase(puzzle: CanvasLayer, nome: String) -> bool:
	var destaque: DestaqueTutorial = puzzle.destaque
	var na_tela: Rect2 = puzzle.retangulos_para([nome])[0]
	var esperado: Rect2 = destaque.get_global_transform().affine_inverse() * na_tela
	for enfase: Rect2 in destaque._enfases:
		if enfase.position.distance_to(esperado.position) < 2.0 and enfase.size.distance_to(esperado.size) < 2.0:
			return destaque.esta_ativo()
	return false


## Nenhuma caixa de ênfase fica embaixo do nome de quem fala (o Dialogic o
## desenha por cima do puzzle, e ele cobre o que estiver ali).
func _longe_do_nome(puzzle: CanvasLayer) -> bool:
	var destaque: DestaqueTutorial = puzzle.destaque
	var achou_o_nome := false
	for rotulo: DialogicNode_NameLabel in get_tree().get_nodes_in_group("dialogic_name_label"):
		var caixa: Control = rotulo.name_label_root if rotulo.name_label_root is Control else rotulo
		if not caixa.is_visible_in_tree():
			continue
		achou_o_nome = true
		var nome: Rect2 = caixa.get_global_rect()
		for enfase: Rect2 in destaque._enfases:
			if enfase.intersects(destaque.get_global_transform().affine_inverse() * nome):
				return false
	return achou_o_nome


## O texto da fala na tela agora ("" sem fala).
func _texto_da_fala() -> String:
	var evento = Dialogic.current_timeline_events[Dialogic.current_event_idx] \
		if Dialogic.current_timeline != null and Dialogic.current_event_idx >= 0 \
			and Dialogic.current_event_idx < Dialogic.current_timeline_events.size() else null
	return evento.text if evento is DialogicTextEvent else ""


func _esperar_texto(trecho: String) -> bool:
	return await _esperar(func() -> bool: return _texto_da_fala().contains(trecho), 4.0)


## Avança a fala, como quem joga (um toque termina de escrever, o seguinte
## passa adiante), até aparecer a frase com esse trecho.
func _avancar_ate(trecho: String) -> bool:
	var toques := 0
	while not _texto_da_fala().contains(trecho) and toques < 40 and Dialogic.current_timeline != null:
		Dialogic.Inputs.handle_input()
		await _esperar_segundos(0.2)
		toques += 1
	return _texto_da_fala().contains(trecho)


## Avança até a pergunta (as opções na tela).
func _ate_a_pergunta() -> bool:
	if not await _esperar(func() -> bool: return Dialogic.current_timeline != null, 3.0):
		return false
	var toques := 0
	while Dialogic.current_state != Dialogic.States.AWAITING_CHOICE and toques < 40 \
			and Dialogic.current_timeline != null:
		Dialogic.Inputs.handle_input()
		await _esperar_segundos(0.2)
		toques += 1
	return Dialogic.current_state == Dialogic.States.AWAITING_CHOICE


## Escolhe a opção (1 = a primeira). O Dialogic segura as opções um instante
## depois de mostrar, para um clique atrasado não escolher sem querer.
func _escolher(opcao: int) -> bool:
	for tentativa in 10:
		await _esperar_segundos(0.25)
		Dialogic.Choices.select_choice(opcao)
		await get_tree().process_frame
		if Dialogic.current_state != Dialogic.States.AWAITING_CHOICE:
			return true
	return false


## Avança até a fala acabar e o roteiro seguir.
func _passar_ate_acabar(puzzle: CanvasLayer) -> bool:
	var toques := 0
	while puzzle.explicacao.falando and toques < 60:
		if Dialogic.current_timeline != null:
			Dialogic.Inputs.handle_input()
		await _esperar_segundos(0.2)
		toques += 1
	# O roteiro anda um respiro depois da fala (a pausa entre passos).
	await _esperar_segundos(ExplicacaoNoPuzzle.PAUSA_ENTRE_PASSOS + ExplicacaoNoPuzzle.ESPERA_ANTES_DA_FALA + 0.2)
	return not puzzle.explicacao.falando or Dialogic.current_timeline != null


func _esperar(condicao: Callable, limite: float) -> bool:
	var t := 0.0
	while not condicao.call() and t < limite:
		await get_tree().process_frame
		t += get_process_delta_time()
	return condicao.call()


func _esperar_segundos(segundos: float) -> void:
	await get_tree().create_timer(segundos, true).timeout
