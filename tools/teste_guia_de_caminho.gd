extends Node

# Teste do GuiaDeCaminho (scripts/guia_de_caminho.gd), a seta que aparece
# quando a Cacau passa tempo demais sem ir para onde deve:
#
#   godot --headless --fixed-fps 60 --path . res://tools/teste_guia_de_caminho.tscn
#
# (Roda como cena, e não com -s: o guia é um autoload e as fases usam os
# outros.)
#
# Casos:
#   * o mapa do guia bate com as cenas de verdade: toda saída (nó com
#     cena_destino, ou declarada em saidas_para_o_guia) é uma das LIGACOES,
#     toda LIGACAO tem a sua saída, e a ferramenta que a tabela pede é a mesma
#     que a porta pede;
#   * todo objetivo do roteiro tem lugar: a cena dele (PlantaDoMapa.ONDE_FICA)
#     dá para alcançar saindo do laboratório (menos as cenas de SEM_ENTRADA) e
#     o objeto dele (ALVOS) existe nela — ou ele é dos que se cumprem só de
#     chegar à cena;
#   * os caminhos: do laboratório à rua, pelo corredor; do telhado ao
#     compressor, pelo elevador de carga; o fosso, só com a mochila; a Torre
#     de Lançamento, sem caminho (está sem entrada);
#   * no corredor da torre, parada: depois da paciência a seta aparece na
#     borda direita, apontando a ponta do fundo, com o "POR AQUI";
#   * no laboratório: andando para a porta da oficina, ela não aparece nunca;
#     parada na porta, o relógio não corre; longe e parada, aparece na borda
#     esquerda; andando um bom pedaço para lá, some; empacando de novo, volta
#     mais depressa;
#   * entrando numa cena fora do caminho (o simulador), a seta continua, agora
#     apontando a porta de volta;
#   * com o jogo pausado, o relógio não corre;
#   * com uma SetaGuia da fase na tela, o guia fica quieto;
#   * o F3 do modo dev mostra a seta na hora.

const LAB := PlantaDoMapa.LAB
const WORLD1 := PlantaDoMapa.WORLD1
const SIMULADOR := PlantaDoMapa.SIMULADOR
const OFICINA := PlantaDoMapa.OFICINA
const CORREDOR_PATIO := PlantaDoMapa.CORREDOR_PATIO
const PATIO := PlantaDoMapa.PATIO
const CORREDOR := PlantaDoMapa.CORREDOR_TORRE
const RUA := PlantaDoMapa.RUA
const COMPRESSOR := PlantaDoMapa.COMPRESSOR
const TELHADO := PlantaDoMapa.TELHADO
const SUBSOLO := PlantaDoMapa.SUBSOLO

## Os objetivos que se cumprem só de chegar à cena: não precisam de objeto no
## ALVOS (o guia leva até a porta e pronto). Objetivo novo sem ALVO tem de
## entrar aqui de propósito.
const SO_DE_CHEGAR := ["entrar_lab", "entrar_oficina", "patio", "entrar_torre", "entrar_subsolo"]
## Cenas sem entrada, de propósito: os objetivos delas só aparecem com a Cacau
## lá dentro, e o guia não tem de achar caminho até elas. A Torre de Lançamento
## ficou sem porta em 2026-11-18 (a porta verde do laboratório saiu); quando
## ela ganhar uma entrada de novo, tire-a daqui.
const SEM_ENTRADA := [PlantaDoMapa.LANCAMENTO]

var _falhas := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# O teste sai de cena: as trocas de cena de verdade não o apagam.
	get_tree().current_scene = null
	_rodar()


func _rodar() -> void:
	EstadoMundo.revelou_dr_chico = true
	_testar_mapa_contra_as_cenas()
	_testar_objetivos()
	_testar_caminhos()
	await _testar_corredor()
	await _testar_laboratorio()
	await _testar_cena_errada()
	await _testar_pausa_e_seta_da_fase()
	await _testar_f3()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


# ─────────────────────────────────────────────────────────────
#  AS TABELAS
# ─────────────────────────────────────────────────────────────

func _testar_mapa_contra_as_cenas() -> void:
	print("\n--- O MAPA DO GUIA CONTRA AS CENAS ---")
	var cenas := {}
	for ligacao: Array in GuiaDeCaminho.LIGACOES:
		cenas[ligacao[0]] = true
	for caminho: String in cenas.keys():
		var cena := (load(caminho) as PackedScene).instantiate()
		var saidas := GuiaDeCaminho.saidas_de(cena)
		var problemas := PackedStringArray()
		for saida: Dictionary in saidas:
			var nome := str(cena.get_path_to(saida["no"])) if saida.has("no") else "saída declarada"
			var ligacao := _ligacao(caminho, String(saida["cena"]))
			if ligacao.is_empty():
				problemas.append("%s -> %s não está nas LIGACOES" % [nome, String(saida["cena"]).get_file()])
				continue
			if saida.has("no"):
				var no: Node = saida["no"]
				var pede := String(no.get("requer_habilidade")) if "requer_habilidade" in no else ""
				var na_tabela := String(ligacao[2]) if ligacao.size() > 2 else ""
				if pede != na_tabela:
					problemas.append("%s pede \"%s\", a tabela diz \"%s\"" % [nome, pede, na_tabela])
		for ligacao: Array in GuiaDeCaminho.LIGACOES:
			if ligacao[0] != caminho:
				continue
			var tem := saidas.any(func(s: Dictionary) -> bool: return s["cena"] == ligacao[1])
			if not tem:
				problemas.append("a LIGACAO para %s não tem saída na cena" % String(ligacao[1]).get_file())
		_checar(problemas.is_empty(), "%s: %d saída(s), todas no mapa do guia%s"
			% [caminho.get_file(), saidas.size(), "" if problemas.is_empty() else " — " + "; ".join(problemas)])
		cena.free()


func _ligacao(de: String, para: String) -> Array:
	for ligacao: Array in GuiaDeCaminho.LIGACOES:
		if ligacao[0] == de and ligacao[1] == para:
			return ligacao
	return []


func _testar_objetivos() -> void:
	print("\n--- TODO OBJETIVO TEM LUGAR ---")
	var roteiro := RoteiroObjetivos.new(func(_cena: String) -> bool: return false)
	var ids := {}
	var por_cena := {}
	var sem_lugar := PackedStringArray()
	var sem_caminho := PackedStringArray()
	var sem_alvo := PackedStringArray()
	# O caminho até cada objetivo com todas as ferramentas (o modo dev não
	# respeita trava nenhuma).
	ModoDev.ativo = true
	for trilha: Dictionary in roteiro.trilhas:
		for etapa: Dictionary in trilha["etapas"]:
			for objetivo: Dictionary in etapa["objetivos"]:
				var id := String(objetivo["id"])
				ids[id] = true
				var lugar := PlantaDoMapa.lugar_do_objetivo(id)
				if lugar.is_empty():
					sem_lugar.append(id)
					continue
				if GuiaDeCaminho.caminho(LAB, String(lugar["cena"])) == null \
						and not String(lugar["cena"]) in SEM_ENTRADA:
					sem_caminho.append(id)
				if GuiaDeCaminho.ALVOS.has(id):
					if not por_cena.has(lugar["cena"]):
						por_cena[lugar["cena"]] = []
					if not id in por_cena[lugar["cena"]]:
						por_cena[lugar["cena"]].append(id)
				elif not id in SO_DE_CHEGAR:
					sem_alvo.append(id)
	ModoDev.ativo = false
	_checar(sem_lugar.is_empty(), "todo objetivo tem cena no PlantaDoMapa.ONDE_FICA %s" % [sem_lugar])
	_checar(sem_caminho.is_empty(), "e dá para chegar a ela saindo do laboratório %s" % [sem_caminho])
	_checar(sem_alvo.is_empty(), "e tem objeto no ALVOS, ou é dos que se cumprem só de chegar %s" % [sem_alvo])
	var sobrando := PackedStringArray()
	for id: String in GuiaDeCaminho.ALVOS:
		if not ids.has(id):
			sobrando.append(id)
	_checar(sobrando.is_empty(), "nenhum ALVO de objetivo que não existe mais %s" % [sobrando])

	for caminho: String in por_cena:
		var cena := (load(caminho) as PackedScene).instantiate()
		var faltando := PackedStringArray()
		for id: String in por_cena[caminho]:
			if not cena.get_node_or_null(String(GuiaDeCaminho.ALVOS[id])) is Node2D:
				faltando.append("%s (%s)" % [id, GuiaDeCaminho.ALVOS[id]])
		_checar(faltando.is_empty(), "%s: os objetos de %s existem%s" % [caminho.get_file(),
			", ".join(PackedStringArray(por_cena[caminho])), "" if faltando.is_empty() else " — faltam " + ", ".join(faltando)])
		cena.free()


func _testar_caminhos() -> void:
	print("\n--- OS CAMINHOS ---")
	_checar(GuiaDeCaminho.caminho(LAB, RUA) == [CORREDOR, RUA],
		"do laboratório à rua: pela ponta direita, o corredor (%s)" % [_nomes(GuiaDeCaminho.caminho(LAB, RUA))])
	_checar(GuiaDeCaminho.caminho(WORLD1, PATIO) == [LAB, OFICINA, CORREDOR_PATIO, PATIO],
		"do world1 ao pátio: laboratório, oficina, corredor do elevador (%s)"
		% [_nomes(GuiaDeCaminho.caminho(WORLD1, PATIO))])
	_checar(GuiaDeCaminho.caminho(TELHADO, COMPRESSOR) == [RUA, COMPRESSOR],
		"do telhado ao compressor, o atalho é o elevador de carga (%s)"
		% [_nomes(GuiaDeCaminho.caminho(TELHADO, COMPRESSOR))])
	_checar(GuiaDeCaminho.caminho(RUA, RUA) == [], "já na cena: caminho vazio")
	_checar(GuiaDeCaminho.caminho(LAB, PlantaDoMapa.LANCAMENTO) == null,
		"a Torre de Lançamento está sem entrada: a porta verde do laboratório saiu")
	_checar(GuiaDeCaminho.caminho(LAB, SUBSOLO) == null, "sem a mochila, o fosso não é caminho")
	_checar(GuiaDeCaminho.caminho(SUBSOLO, LAB) == [LAB], "   mas subir de volta, qualquer um sobe")
	# (Direto no Progresso, sem o sinal de ferramenta nova: a ficha dela
	# seguraria o resto do teste.)
	Progresso._habilidades["mochila"] = true
	_checar(GuiaDeCaminho.caminho(LAB, SUBSOLO) == [SUBSOLO], "com a mochila, o fosso é o caminho")
	Progresso._habilidades.erase("mochila")
	_checar(GuiaDeCaminho.caminho("res://scenes/menu_principal.tscn", LAB) == null,
		"cena fora do mapa do guia: sem caminho (e sem seta)")


func _nomes(caminho: Variant) -> String:
	if caminho == null:
		return "null"
	var lista := PackedStringArray()
	for cena in caminho:
		lista.append(String(cena).get_file())
	return ", ".join(lista)


# ─────────────────────────────────────────────────────────────
#  A SETA NO JOGO
# ─────────────────────────────────────────────────────────────

func _testar_corredor() -> void:
	print("\n--- NO CORREDOR DA TORRE, PARADA ---")
	await _abrir(CORREDOR)
	await _segundos(0.3)
	_zerar(1.5, 1.0)
	await _quadros(3)
	var estado := GuiaDeCaminho.estado()
	_checar(estado.objetivo == "entrar_torre" and estado.caminho == [RUA] and estado.ponto == "SaidaTorre",
		"o objetivo é chegar à rua: a seta apontaria a ponta do fundo (%s, %s)" % [estado.objetivo, estado.ponto])
	await _segundos(1.0)
	_checar(not _seta().mostrando(), "antes da paciência acabar, nada na tela")
	await _segundos(0.8)
	var tela := get_viewport().get_visible_rect().size
	_checar(_seta().mostrando() and _seta().direcao == SetaGo.Direcao.DIREITA
		and _seta().ponta.x > tela.x - 250.0 and _seta().texto == GuiaDeCaminho.texto_na_borda,
		"parada, depois da paciência: a seta na borda direita, apontando o fundo (%s, ponta em %s)"
		% [_seta().texto, _seta().ponta.round()])


func _testar_laboratorio() -> void:
	print("\n--- NO LABORATÓRIO: SÓ QUANDO ELA SE PERDE ---")
	await _abrir(LAB)
	await _segundos(1.0)  # o laboratório clareia
	_zerar(1.5, 1.0)
	var player := _player()
	var porta := get_tree().current_scene.get_node("PortaOficina") as Node2D
	player.global_position.x = 3000.0
	await _quadros(4)
	var estado := GuiaDeCaminho.estado()
	_checar(estado.objetivo == "entrar_oficina" and estado.caminho == [OFICINA] and estado.ponto == "PortaOficina",
		"o objetivo é a Ala de Pirólise: o ponto é a porta dela (%s, %s)" % [estado.objetivo, estado.ponto])

	# Andando para a porta: o relógio nunca chega à paciência.
	Input.action_press(&"ui_left")
	var quadros := 0
	var apareceu := false
	while player.global_position.x > porta.global_position.x + 30.0 and quadros < 900:
		await get_tree().process_frame
		quadros += 1
		apareceu = apareceu or _seta().mostrando()
	Input.action_release(&"ui_left")
	_checar(not apareceu and quadros / 60.0 > 2.0 * GuiaDeCaminho.paciencia,
		"andando para a porta (%.1f s de caminhada, paciência de %.1f s), a seta não aparece"
		% [quadros / 60.0, GuiaDeCaminho.paciencia])
	await _segundos(2.5)
	_checar(not _seta().mostrando() and GuiaDeCaminho.estado().parado < 0.05,
		"parada na frente da porta, o relógio não corre (o E da porta já aparece)")

	# Longe e parada.
	player.global_position.x = 3000.0
	await _segundos(1.0)
	_checar(not _seta().mostrando(), "levada para longe e parada: com 1 s, ainda nada")
	await _segundos(0.8)
	_checar(_seta().mostrando() and _seta().direcao == SetaGo.Direcao.ESQUERDA and _seta().ponta.x < 250.0
		and _seta().texto == GuiaDeCaminho.texto_na_borda,
		"depois da paciência, a seta na borda esquerda, do lado da porta (ponta em %s)" % [_seta().ponta.round()])

	# Pegou o rumo: um bom pedaço para lá e a seta sai.
	var partida := player.global_position.x
	Input.action_press(&"ui_left")
	quadros = 0
	while _seta().mostrando() and quadros < 600:
		await get_tree().process_frame
		quadros += 1
	Input.action_release(&"ui_left")
	var andou := partida - player.global_position.x
	_checar(not _seta().mostrando() and andou >= GuiaDeCaminho.avanco_para_sumir - 10.0
		and andou < GuiaDeCaminho.avanco_para_sumir + 60.0,
		"andando %.0f px na direção certa, a seta sai (avanço para sumir: %.0f)" % [andou, GuiaDeCaminho.avanco_para_sumir])

	# Empacou de novo: volta mais depressa.
	quadros = 0
	while not _seta().mostrando() and quadros < 300:
		await get_tree().process_frame
		quadros += 1
	_checar(_seta().mostrando() and quadros / 60.0 < GuiaDeCaminho.paciencia,
		"empacou de novo: a seta volta mais depressa (%.1f s; a paciência é de %.1f)"
		% [quadros / 60.0, GuiaDeCaminho.paciencia])


func _testar_cena_errada() -> void:
	print("\n--- PARA O LADO ERRADO: O SIMULADOR ---")
	# Com a seta na tela, ela entra numa cena que não é o caminho: a seta
	# continua, agora apontando a porta de volta.
	_checar(_seta().mostrando(), "a seta está na tela no laboratório")
	# No simulador ela nasce colada na porta de volta, e colada no lugar a seta
	# sai (o E da porta já está lá): sem o raio de chegada, dá para ver só a
	# troca de cena.
	var raio := GuiaDeCaminho.raio_de_chegada
	GuiaDeCaminho.raio_de_chegada = -1.0
	await _abrir(SIMULADOR)
	await _segundos(0.6)
	var estado := GuiaDeCaminho.estado()
	_checar(estado.objetivo == "entrar_oficina" and estado.caminho == [LAB, OFICINA],
		"no simulador, o caminho da oficina passa pelo laboratório (%s)" % [_nomes(estado.caminho)])
	_checar(estado.mostrando and estado.ponto == "PortaSimulador",
		"e a seta continua na tela, apontando a porta de volta (%s)" % estado.ponto)
	GuiaDeCaminho.raio_de_chegada = raio
	await _quadros(3)
	_checar(not GuiaDeCaminho.estado().mostrando and not _seta().mostrando(),
		"colada na porta de volta, a seta sai: o E da porta já está lá")
	await _abrir(LAB)
	await _segundos(1.0)


func _testar_pausa_e_seta_da_fase() -> void:
	print("\n--- PAUSA E SETA DA FASE ---")
	var player := _player()
	var porta := get_tree().current_scene.get_node("PortaOficina") as Node2D
	_zerar(1.5, 1.0)
	player.global_position.x = 3000.0
	await _quadros(2)
	get_tree().paused = true
	await _segundos(2.5)
	_checar(GuiaDeCaminho.estado().parado < 0.1 and not _seta().mostrando(),
		"com o jogo pausado, o relógio não corre (%.2f s)" % GuiaDeCaminho.estado().parado)
	get_tree().paused = false
	await _segundos(1.8)
	_checar(_seta().mostrando(), "despausado, ele volta a contar e a seta aparece")

	# Uma SetaGuia da fase acende: o guia sai da frente e não conta.
	var da_fase := SetaGuia.new()
	da_fase.name = "SetaDoTeste"
	da_fase.texto = "TESTE"
	da_fase.position = Vector2(player.global_position.x - 200.0, player.global_position.y)
	get_tree().current_scene.add_child(da_fase)
	await _segundos(2.5)
	_checar(da_fase.mostrando() and not _seta().mostrando() and GuiaDeCaminho.estado().parado < 0.05,
		"com uma SetaGuia da fase na tela, o guia fica quieto e não conta")
	da_fase.queue_free()
	await _segundos(1.8)
	_checar(_seta().mostrando(), "sem ela, o guia volta a contar e aparece")
	player.global_position.x = porta.global_position.x
	await _quadros(4)


func _testar_f3() -> void:
	print("\n--- F3 DO MODO DEV ---")
	_zerar(25.0, 10.0)
	_player().global_position.x = 2900.0
	await _quadros(4)
	_checar(not _seta().mostrando(), "com a paciência de verdade, nada ainda")
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_F3
	tecla.keycode = KEY_F3
	tecla.pressed = true
	Input.parse_input_event(tecla)
	await _quadros(3)
	_checar(_seta().mostrando(), "o F3 mostra a seta na hora")


# ─────────────────────────────────────────────────────────────

func _zerar(paciencia: float, depois_de_ajudar: float) -> void:
	GuiaDeCaminho.paciencia = paciencia
	GuiaDeCaminho.paciencia_depois_de_ajudar = depois_de_ajudar
	GuiaDeCaminho.esquecer()


func _seta() -> SetaGo:
	return GuiaDeCaminho.seta()


func _abrir(caminho: String) -> void:
	get_tree().change_scene_to_file(caminho)
	for i in 600:
		await get_tree().process_frame
		if get_tree().current_scene and get_tree().current_scene.scene_file_path == caminho:
			break
	await _quadros(3)


func _player() -> CharacterBody2D:
	return get_tree().current_scene.get_node("Player") as CharacterBody2D


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _segundos(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1
