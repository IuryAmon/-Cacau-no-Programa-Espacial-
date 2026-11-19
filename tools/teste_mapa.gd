extends Node

# Teste do mapa do caderno (scripts/planta_do_mapa.gd, scripts/ui/
# folha_do_mapa.gd, scripts/ui/abas_do_caderno.gd e as abas do scripts/
# caderno.gd):
#
#   * a planta: as salas não ficam umas em cima das outras, cada letra do
#     CHONPS está numa sala só, cada passagem liga duas salas vizinhas (lado a
#     lado ou uma em cima da outra) e do laboratório se chega a todas;
#   * as cenas: cada uma existe, o trilho dela fica dentro da sala e a Cacau
#     anda no mapa conforme anda na cena (da ponta esquerda à direita); o
#     subsolo atravessa três salas (a ala oeste, o átrio e a ala leste), e
#     cada sala em que ela pisa fica explorada;
#   * as portas de verdade: cada porta das cenas leva a uma cena que o mapa
#     conhece, salas diferentes ligadas por porta têm passagem na planta, e a
#     porta que pede uma habilidade ganha o cadeado dela;
#   * os objetivos: todo objetivo do roteiro diz em que cena se cumpre, e o
#     losango vai para lá, na cor da trilha;
#   * a folha: a planta cabe no quadriculado, os nomes cabem nas salas sem se
#     encostar, a plaquinha do rosto não sai da sala nem cobre nome, o carimbo
#     cabe no quadro com os objetivos de qualquer etapa e toda letra existe na
#     fonte;
#   * o que ele lê do jogo: o nome e o lugar da sala, as salas já visitadas, os
#     elementos, as habilidades e até onde a Cacau anda na cena;
#   * as abas: a primeira vez, M abre no MAPA, saindo do mapinha do ícone;
#     Q/E (L1/R1 no controle) e o clique trocam de aba, com a folha que sai
#     deslizando para um lado e a que entra vindo do outro; no mapa não se
#     folheia; depois o caderno abre sempre na última aba vista, e nota nova
#     não muda a aba: a marca dela aparece na aba CADERNO e só apaga quando a
#     pessoa vê o CADERNO, já na página da nota. O Q é tecla desenhada nova, no
#     fim da lista dos botões.
#
#   godot --headless --path . res://tools/teste_mapa.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva as abas e o mapa em
# alguns momentos do jogo, para conferir o desenho a olho.

## Aonde as portas podem levar fora do mapa: o simulador da nave e o
## encerramento em órbita (as cenas sem lista de objetivos).
const FORA_DO_MAPA := [
	"res://scenes/simulador/simulador_lua.tscn",
	"res://scenes/fases/final_orbita.tscn",
]

var _falhas := 0
var _pasta_capturas := ""
var _cacau: Node2D = null
var _folha: FolhaDoMapa = null
var _roteiro: RoteiroObjetivos = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			_pasta_capturas = arg.trim_prefix("--capturas=")
	_cacau = Node2D.new()
	_cacau.name = "Cacau"
	_cacau.add_to_group("player")
	add_child(_cacau)
	_folha = FolhaDoMapa.new()
	_folha.visible = false
	add_child(_folha)
	_roteiro = RoteiroObjetivos.new(func(_cena: String) -> bool: return false)
	await _quadros(2)

	# Primeiro: depois daqui o teste mexe no Progresso e nas cenas visitadas.
	_testar_objetivo_da_vez()
	_testar_salas()
	_testar_passagens()
	_testar_cenas()
	_testar_objetivos_do_roteiro()
	_testar_portas()
	_testar_folha()
	_testar_trilhos()
	_testar_carimbo()
	_testar_estado()
	_testar_limites()
	_testar_tecla_q()
	await _testar_salas_pisadas()
	await _testar_abas()
	await _testar_controle()
	await _testar_capturas()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


## Um "ok" se não houver problema; senão, uma FALHA para cada um.
func _checar_lista(problemas: PackedStringArray, descricao: String) -> void:
	if problemas.is_empty():
		_checar(true, descricao)
	for problema in problemas:
		_checar(false, "%s — %s" % [descricao, problema])


# ─────────────────────────────────────────────────────────────

func _testar_objetivo_da_vez() -> void:
	print("\n--- O OBJETIVO DA VEZ ---")
	var laser := EstadoMundo.passagem_laser_aberta
	var chico := EstadoMundo.revelou_dr_chico

	EstadoMundo.passagem_laser_aberta = true
	var estado := _folha.montar_estado("")
	_checar(_ids(estado["objetivos"]) == ["entrar_lab"],
		"com o laser aberto, o objetivo da vez é entrar no laboratório %s" % [_ids(estado["objetivos"])])
	var alvos: Array = estado["alvos"]
	_checar(alvos.size() == 1 and alvos[0]["ponto"] == PlantaDoMapa.ponto_no_mapa(PlantaDoMapa.LAB),
		"o losango fica no laboratório")
	_checar(estado["onde"] == PackedStringArray(["LABORATÓRIO"]), "o carimbo diz onde %s" % [estado["onde"]])
	if not alvos.is_empty():
		var objetivo: Dictionary = estado["objetivos"][0]
		_checar(objetivo["titulo"] == "COMBUSTÃO DO HIDROGÊNIO" and alvos[0]["cor"] == objetivo["cor"],
			"na cor da trilha do prólogo")

	EstadoMundo.revelou_dr_chico = true
	estado = _folha.montar_estado("")
	alvos = estado["alvos"]
	_checar(_ids(estado["objetivos"]) == ["entrar_oficina"] \
		and estado["objetivos"][0]["titulo"] == "CARBONO",
		"depois do Dr. Chico, a trilha do carbono: entrar na oficina %s" % [_ids(estado["objetivos"])])
	_checar(alvos.size() == 1 and alvos[0]["ponto"] == PlantaDoMapa.ponto_no_mapa(PlantaDoMapa.OFICINA) \
		and estado["onde"] == PackedStringArray(["FASE CARBONO"]), "e o losango vai para a FASE CARBONO")

	EstadoMundo.passagem_laser_aberta = laser
	EstadoMundo.revelou_dr_chico = chico


func _testar_salas() -> void:
	print("\n--- SALAS ---")
	var problemas := PackedStringArray()
	var ids := {}
	var letras := {}
	for sala in PlantaDoMapa.AREAS:
		var id := String(sala["id"])
		if ids.has(id):
			problemas.append("o id \"%s\" é de duas salas" % id)
		ids[id] = true
		var caixa: Rect2i = sala["caixa"]
		if caixa.position.x < 0 or caixa.position.y < 0 or caixa.size.x <= 0 or caixa.size.y <= 0:
			problemas.append("%s: caixa inválida %s" % [id, caixa])
		if not String(sala.get("nome_fora", "")) in ["", "cima", "direita", "esquerda"]:
			problemas.append("%s: nome_fora \"%s\"" % [id, sala["nome_fora"]])
		for letra: String in sala.get("elementos", []):
			letras[letra] = int(letras.get(letra, 0)) + 1
	var salas := PlantaDoMapa.AREAS
	for i in salas.size():
		for j in range(i + 1, salas.size()):
			if (salas[i]["caixa"] as Rect2i).intersects(salas[j]["caixa"]):
				problemas.append("%s em cima de %s" % [salas[i]["id"], salas[j]["id"]])
	_checar_lista(problemas, "as salas têm id próprio, caixa válida e não ficam umas em cima das outras")

	var letras_ruins := PackedStringArray()
	for letra: String in Progresso.CELULAS:
		if int(letras.get(letra, 0)) != 1:
			letras_ruins.append("%s em %d salas" % [letra, int(letras.get(letra, 0))])
	for letra: String in letras:
		if not letra in Progresso.CELULAS:
			letras_ruins.append("%s não é do CHONPS" % letra)
	_checar_lista(letras_ruins, "cada elemento do CHONPS se conquista numa sala só")


func _testar_passagens() -> void:
	print("\n--- PASSAGENS ---")
	var problemas := PackedStringArray()
	for passagem in PlantaDoMapa.PASSAGENS:
		var nome := "%s ↔ %s" % [passagem["de"], passagem["para"]]
		if PlantaDoMapa.area(passagem["de"]).is_empty() or PlantaDoMapa.area(passagem["para"]).is_empty():
			problemas.append("%s: sala que não existe" % nome)
		elif PlantaDoMapa.traco(passagem).is_empty():
			problemas.append("%s: as salas não ficam lado a lado nem uma em cima da outra" % nome)
		var requer := String(passagem.get("requer", ""))
		if not requer.is_empty() and not requer in Progresso.HABILIDADES:
			problemas.append("%s: \"%s\" não é habilidade" % [nome, requer])
	_checar_lista(problemas, "cada passagem liga duas salas vizinhas")

	var vistas := {"laboratorio": true}
	var fila: Array[String] = ["laboratorio"]
	while not fila.is_empty():
		for vizinha in PlantaDoMapa.vizinhas(fila.pop_back()):
			if not vistas.has(vizinha):
				vistas[vizinha] = true
				fila.append(vizinha)
	var soltas := PackedStringArray()
	for sala in PlantaDoMapa.AREAS:
		if not vistas.has(sala["id"]):
			soltas.append(sala["id"])
	_checar_lista(soltas, "do laboratório se chega a todas as salas")

	var em_pe := PlantaDoMapa.traco({"de": "laboratorio", "para": "carbono", "em": 9.5})
	_checar(em_pe.get("de") == Vector2(9.5, 6) and em_pe.get("ate") == Vector2(9.5, 7) \
		and em_pe.get("deitado") == false, "uma em cima da outra: o corredor em pé no vão %s" % [em_pe])
	var deitado := PlantaDoMapa.traco({"de": "laboratorio", "para": "chegada"})
	_checar(deitado.get("de") == Vector2(7, 8.5) and deitado.get("ate") == Vector2(8, 8.5) \
		and deitado.get("deitado") == true, "lado a lado: o corredor deitado, no meio %s" % [deitado])
	var porta := PlantaDoMapa.traco({"de": "nitrogenio", "para": "torre"})
	_checar(porta.get("de") == Vector2(22.5, 7) and porta.get("ate") == porta.get("de"),
		"encostadas: o corredor vira a porta na parede %s" % [porta])
	_checar(PlantaDoMapa.traco({"de": "chegada", "para": "torre"}).is_empty() \
		and PlantaDoMapa.traco({"de": "laboratorio", "para": "carbono", "em": 20.0}).is_empty(),
		"salas longe uma da outra (ou \"em\" fora do trecho que elas dividem) não têm corredor")
	_checar(PlantaDoMapa.ligadas("subsolo", "laboratorio") and not PlantaDoMapa.ligadas("chegada", "carbono"),
		"ligadas() vale nos dois sentidos")


func _testar_cenas() -> void:
	print("\n--- CENAS ---")
	var problemas := PackedStringArray()
	for caminho: String in PlantaDoMapa.CENAS:
		if not ResourceLoader.exists(caminho):
			problemas.append("%s não existe" % caminho)
		var trechos := PlantaDoMapa.trechos(caminho)
		var entrada := PlantaDoMapa.area_da_cena(caminho)
		if not entrada.is_empty() and not entrada in PlantaDoMapa.areas_da_cena(caminho):
			problemas.append("%s: a sala de entrada não é de nenhum trecho" % caminho.get_file())
		for i in trechos.size():
			var id := String(trechos[i]["area"])
			if i > 0 and float(trechos[i]["ate"]) <= float(trechos[i - 1]["ate"]):
				problemas.append("%s: os trechos não vão da esquerda para a direita" % caminho.get_file())
			if id.is_empty():
				continue
			var sala := PlantaDoMapa.area(id)
			if sala.is_empty():
				problemas.append("%s: a sala \"%s\" não existe" % [caminho.get_file(), id])
			elif not Rect2(sala["caixa"]).encloses(trechos[i]["trilho"]):
				problemas.append("%s: o trilho sai da sala %s" % [caminho.get_file(), id])
	_checar_lista(problemas, "as cenas do mapa existem e o trilho de cada trecho fica dentro da sala dele")

	var lab := PlantaDoMapa.LAB
	var limites: Rect2 = PlantaDoMapa.CENAS[lab]["limites"]
	var porta := PlantaDoMapa.ponto_no_mapa(lab, Vector2(1023, 120), limites)
	_checar(porta.is_equal_approx(Vector2(8.75 + 5.5 * 1023.0 / limites.size.x, 9.1)),
		"a Cacau na porta do simulador (x = 1023) fica a 28%% do trilho do laboratório %s" % porta)
	_checar(absf(PlantaDoMapa.ponto_no_mapa(PlantaDoMapa.SIMULADOR).x - porta.x) < 0.1,
		"e o simulador fica no mapa onde a porta dele está")
	_checar(PlantaDoMapa.ponto_no_mapa(lab, Vector2(-500, 0), limites).is_equal_approx(Vector2(8.75, 9.1)) \
		and PlantaDoMapa.ponto_no_mapa(lab, Vector2(99999, 0), limites).is_equal_approx(Vector2(14.25, 9.1)),
		"fora da cena, o marcador para na ponta do trilho")
	_checar(PlantaDoMapa.ponto_no_mapa(lab).is_equal_approx(Vector2(11.5, 9.1)),
		"sem a posição, no meio do trilho")
	var oficina := Rect2(0, -1000, 2000, 1000)
	_checar(PlantaDoMapa.ponto_no_mapa(PlantaDoMapa.OFICINA, oficina.position, oficina) \
			.is_equal_approx(Vector2(8.75, 4.65)) \
		and PlantaDoMapa.ponto_no_mapa(PlantaDoMapa.OFICINA, oficina.end, oficina) \
			.is_equal_approx(Vector2(14.25, 5.5)),
		"na oficina o marcador sobe e desce também (o andar de cima)")
	_checar(not PlantaDoMapa.ponto_no_mapa(PlantaDoMapa.LANCAMENTO, Vector2(10, 10), Rect2(0, 0, 99, 99)) \
			.is_finite() and not PlantaDoMapa.ponto_no_mapa("res://nada.tscn").is_finite(),
		"fora da planta (ou em cena desconhecida), sem marcador")
	_checar(PlantaDoMapa.trilho_padrao("fosforo").is_equal_approx(Rect2(3.75, 12.4, 2.5, 0.0)) \
		and PlantaDoMapa.trilho_padrao("corredor_torre").is_equal_approx(Rect2(16.75, 8.5, 1.5, 0.0)),
		"o trilho padrão: deitado, embaixo do nome (no meio, na sala de uma linha)")

	# O subsolo atravessa três salas.
	var subsolo := PlantaDoMapa.SUBSOLO
	var areas := [320.0, 2450.0, 2800.0, 4450.0, 5450.0].map(
		func(x: float) -> String: return PlantaDoMapa.trecho(subsolo, x).get("area", ""))
	_checar(areas == ["fosforo", "subsolo", "subsolo", "enxofre", "enxofre"],
		"no subsolo: o fósforo (x = 320) na ala oeste, o fosso no átrio, a masseira e o enxofre na ala leste %s" % [areas])
	_checar(PlantaDoMapa.trecho(subsolo).get("area") == "subsolo" and PlantaDoMapa.area_da_cena(subsolo) == "subsolo",
		"sem a posição, a sala de entrada: o SUBSOLO")
	_checar(PlantaDoMapa.areas_da_cena(subsolo) == PackedStringArray(["fosforo", "subsolo", "enxofre"]) \
		and PlantaDoMapa.tem_trechos(subsolo) and not PlantaDoMapa.tem_trechos(lab),
		"e passa pelas três salas")
	var fundo := Rect2(0, -500, 5680, 1180)
	_checar(PlantaDoMapa.ponto_no_mapa(subsolo, Vector2(1000, 0), fundo).is_equal_approx(Vector2(5.0, 12.4)) \
		and PlantaDoMapa.ponto_no_mapa(subsolo, Vector2(2700, 0), fundo).is_equal_approx(Vector2(11.5, 12.4)) \
		and PlantaDoMapa.ponto_no_mapa(subsolo, Vector2(4540, 0), fundo).is_equal_approx(Vector2(18.0, 12.4)),
		"cada trecho cabe inteiro no trilho da sala dele (o meio do trecho, no meio do trilho)")


func _testar_objetivos_do_roteiro() -> void:
	print("\n--- OBJETIVOS DO ROTEIRO ---")
	var ids := {}
	var cenas_soltas := PackedStringArray()
	for trilha in _roteiro.trilhas:
		for cena: String in trilha["cenas"]:
			if not PlantaDoMapa.CENAS.has(cena) and not cena in FORA_DO_MAPA:
				cenas_soltas.append(cena)
		for etapa in trilha["etapas"]:
			for objetivo in etapa["objetivos"]:
				ids[objetivo["id"]] = true
	_checar_lista(cenas_soltas, "as cenas das trilhas estão no mapa")
	var sem_lugar := PackedStringArray()
	for id: String in ids:
		var lugar := PlantaDoMapa.lugar_do_objetivo(id)
		if lugar.is_empty() or not PlantaDoMapa.CENAS.has(lugar["cena"]):
			sem_lugar.append(id)
		elif not lugar["area"].is_empty() and not lugar["area"] in PlantaDoMapa.areas_da_cena(lugar["cena"]):
			sem_lugar.append("%s (a cena não passa pela sala %s)" % [id, lugar["area"]])
	_checar_lista(sem_lugar, "todo objetivo do roteiro diz em que cena do mapa ele se cumpre (ONDE_FICA)")
	var sobrando := PackedStringArray()
	for id: String in PlantaDoMapa.ONDE_FICA:
		if not ids.has(id):
			sobrando.append(id)
	_checar_lista(sobrando, "e o ONDE_FICA só tem objetivos do roteiro")


func _testar_portas() -> void:
	print("\n--- AS PORTAS DAS CENAS ---")
	var problemas := PackedStringArray()
	var cadeados_das_portas := {}
	var portas := 0
	for caminho: String in PlantaDoMapa.CENAS:
		var pacote := load(caminho) as PackedScene
		if pacote == null:
			problemas.append("%s não abre" % caminho.get_file())
			continue
		var raiz := pacote.instantiate()
		# O marcador só anda se o mapa souber até onde a cena vai.
		if not PlantaDoMapa.area_da_cena(caminho).is_empty() \
				and (PlantaDoMapa.trilho_da_cena(caminho).size != Vector2.ZERO or PlantaDoMapa.tem_trechos(caminho)) \
				and not PlantaDoMapa.CENAS[caminho].has("limites") \
				and raiz.get_node_or_null(^"LimitesDaCamera") == null:
			problemas.append("%s: sem \"limites\" na planta e sem LimitesDaCamera" % caminho.get_file())
		for porta in _portas(raiz):
			portas += 1
			var destino := String(porta.get("cena_destino"))
			var nome := "%s/%s" % [caminho.get_file().get_basename(), porta.name]
			if not PlantaDoMapa.CENAS.has(destino) and not destino in FORA_DO_MAPA:
				problemas.append("%s leva a %s, que o mapa não conhece" % [nome, destino])
				continue
			# Na cena com trechos, a sala é a do trecho em que a porta está.
			var de := String(PlantaDoMapa.trecho(caminho, _x_na_cena(porta)).get("area", ""))
			var para := PlantaDoMapa.area_da_cena(destino)
			if de.is_empty() or para.is_empty() or de == para:
				continue
			if not PlantaDoMapa.ligadas(de, para):
				problemas.append("%s liga %s a %s, e a planta não tem passagem" % [nome, de, para])
				continue
			var requer := String(porta.get("requer_habilidade")) if "requer_habilidade" in porta else ""
			if requer.is_empty():
				continue
			cadeados_das_portas[_par(de, para)] = requer
			if String(_passagem(de, para).get("requer", "")) != requer:
				problemas.append("%s pede %s, e a passagem %s ↔ %s não tem o cadeado" % [nome, requer, de, para])
		raiz.free()
	_checar(portas >= 20, "as cenas têm portas (%d)" % portas)
	_checar_lista(problemas, "cada porta leva a uma cena do mapa, por uma passagem da planta")
	var sem_porta := PackedStringArray()
	for passagem in PlantaDoMapa.PASSAGENS:
		var requer := String(passagem.get("requer", ""))
		if not requer.is_empty() and cadeados_das_portas.get(_par(passagem["de"], passagem["para"]), "") != requer:
			sem_porta.append("%s ↔ %s (%s)" % [passagem["de"], passagem["para"], requer])
	_checar_lista(sem_porta, "e cada cadeado do mapa é de uma porta que pede a habilidade")


func _testar_folha() -> void:
	print("\n--- A FOLHA ---")
	_folha.estado = _folha.montar_estado(PlantaDoMapa.LAB, Vector2.INF, Rect2(), [])
	var c := FolhaDoMapa.celula()
	_checar(c >= 30.0, "a célula tem %d px" % c)
	var planta := Rect2(FolhaDoMapa.origem(), Vector2(PlantaDoMapa.tamanho()) * c)
	_checar(FolhaDoMapa.QUADRICULADO.grow(-c * 0.5).encloses(planta) and planta.position == planta.position.round(),
		"a planta cabe no quadriculado, com folga, no pixel inteiro %s" % planta)
	var papel := FolhaDoMapa.PAPEL_DA_FOLHA
	_checar(papel.encloses(FolhaDoMapa.QUADRICULADO) and papel.encloses(FolhaDoMapa.CARIMBO) \
		and not FolhaDoMapa.QUADRICULADO.intersects(FolhaDoMapa.CARIMBO),
		"o quadriculado e o carimbo ficam lado a lado no papel")

	var salas := {}
	for sala in PlantaDoMapa.AREAS:
		salas[sala["id"]] = FolhaDoMapa.caixa_da_sala(sala["id"])
	var textos := _textos(_folha.rotulos())
	var problemas := PackedStringArray()
	for item in textos:
		var caixa := FolhaDoMapa.caixa_do_texto(item)
		var id := String(item["sala"])
		var de_fora := id.is_empty() or not String(PlantaDoMapa.area(id).get("nome_fora", "")).is_empty()
		if not de_fora:
			if not (salas[id] as Rect2).grow(-FolhaDoMapa.MOLDURA_SALA).encloses(caixa):
				problemas.append("\"%s\" sai da sala" % item["texto"])
			continue
		if not FolhaDoMapa.QUADRICULADO.grow(-4.0).encloses(caixa):
			problemas.append("\"%s\" sai do quadriculado" % item["texto"])
		for outra: String in salas:
			if caixa.intersects(salas[outra]):
				problemas.append("\"%s\" em cima da sala %s" % [item["texto"], outra])
	for i in textos.size():
		for j in range(i + 1, textos.size()):
			if FolhaDoMapa.caixa_do_texto(textos[i]).intersects(FolhaDoMapa.caixa_do_texto(textos[j])):
				problemas.append("\"%s\" encosta em \"%s\"" % [textos[i]["texto"], textos[j]["texto"]])
	_checar_lista(problemas,
		"cada nome cabe na sala dele (o de fora e o título, sem cobrir sala), sem encostar em outro")
	var grandes := PackedStringArray()
	for item in textos:
		if item["tam"] == FolhaDoMapa.TAM_NOME:
			grandes.append(item["texto"])
	_checar("LABORATÓRIO" in grandes and "FASE CARBONO" in grandes and "FASE NITROGÊNIO" in grandes \
		and "ÁREA 1" in grandes, "as salas grandes têm o nome na letra grande %s" % [grandes])

	var fichinhas := 0
	var fichas_ruins := PackedStringArray()
	for sala in PlantaDoMapa.AREAS:
		var id := String(sala["id"])
		var topo: float = (salas[id] as Rect2).position.y
		for caixa in FolhaDoMapa.caixas_das_fichinhas(id):
			fichinhas += 1
			if caixa.position.y >= topo or caixa.end.y <= topo:
				fichas_ruins.append("%s: não fica em pé na parede de cima" % id)
			if not FolhaDoMapa.QUADRICULADO.encloses(caixa):
				fichas_ruins.append("%s: sai do quadriculado" % id)
			for outra: String in salas:
				if outra != id and caixa.intersects(salas[outra]):
					fichas_ruins.append("%s: em cima da sala %s" % [id, outra])
			for item in textos:
				if caixa.intersects(FolhaDoMapa.caixa_do_texto(item)):
					fichas_ruins.append("%s: em cima de \"%s\"" % [id, item["texto"]])
	_checar(fichinhas == Progresso.CELULAS.size(), "uma fichinha por elemento (%d)" % fichinhas)
	_checar_lista(fichas_ruins, "as fichinhas ficam em pé em cima da sala, sem cobrir nada")

	var conferir := PackedStringArray([FolhaDoMapa.TITULO, "FORA DO MAPA", "fora do mapa",
		"Nenhum objetivo agora. Explore o mapa!", "→ · 0123456789/ NO PAINEL",
		"VOCÊ ESTÁ EM", "OBJETIVO", "ELEMENTOS", "EXPLORAÇÃO", "SALAS", "LEGENDA"])
	conferir.append_array(AbasDoCaderno.NOMES)
	for legenda in FolhaDoMapa.LEGENDA:
		conferir.append(legenda[1])
	for sala in PlantaDoMapa.AREAS:
		conferir.append(sala["nome"])
		conferir.append(sala.get("detalhe", ""))
	for caminho: String in PlantaDoMapa.CENAS:
		conferir.append(FolhaDoMapa.nome_do_lugar(caminho))
		conferir.append(PlantaDoMapa.CENAS[caminho].get("lugar", ""))
	for trilha in _roteiro.trilhas:
		conferir.append(trilha["titulo"])
		for etapa in trilha["etapas"]:
			for objetivo in etapa["objetivos"]:
				conferir.append(objetivo["texto"])
	var faltando := ""
	for texto in conferir:
		for i in texto.length():
			var codigo := texto.unicode_at(i)
			# O índice (₂) sai em algarismo normal, menor.
			if codigo == 32 or (codigo >= 0x2080 and codigo <= 0x2089):
				continue
			if not FolhaDoMapa.FONTE.has_char(codigo) and not faltando.contains(texto[i]):
				faltando += texto[i]
	_checar(faltando.is_empty(), "toda letra do mapa existe na fonte (faltam: \"%s\")" % faltando)


func _testar_trilhos() -> void:
	print("\n--- A CACAU NO MAPA ---")
	_folha.estado = _folha.montar_estado(PlantaDoMapa.LAB, Vector2.INF, Rect2(), [])
	var nomes: Array[Rect2] = []
	for item in _textos(_folha.rotulos()):
		nomes.append(FolhaDoMapa.caixa_do_texto(item))
	var problemas := PackedStringArray()
	for caminho: String in PlantaDoMapa.CENAS:
		for pedaco in PlantaDoMapa.trechos(caminho):
			var id := String(pedaco["area"])
			if id.is_empty():
				continue
			var trilho: Rect2 = pedaco["trilho"]
			var dentro := FolhaDoMapa.caixa_da_sala(id).grow(-FolhaDoMapa.MOLDURA_SALA)
			for ponta: Vector2 in [trilho.position, trilho.end, Vector2(trilho.position.x, trilho.end.y),
					Vector2(trilho.end.x, trilho.position.y)]:
				var placa := _folha._placa_do_rosto(FolhaDoMapa.no_papel(ponta).round())
				if not dentro.encloses(placa):
					problemas.append("%s: sai da sala %s em %s" % [caminho.get_file(), id, ponta])
				for nome in nomes:
					if placa.intersects(nome):
						problemas.append("%s: cobre um nome em %s" % [caminho.get_file(), ponta])
						break
	_checar_lista(problemas, "nas pontas de cada trilho, o rosto fica dentro da sala sem cobrir nome")

	# O losango de um objetivo bem embaixo da Cacau vai para o lado da
	# plaquinha dela: também sem sair da sala nem cobrir nome.
	var meia := Vector2(FolhaDoMapa.LOSANGO + 2.0, FolhaDoMapa.LOSANGO + 2.0 + FolhaDoMapa.BALANCO)
	var alvos: Array[Dictionary] = []
	for id: String in PlantaDoMapa.ONDE_FICA:
		var lugar := PlantaDoMapa.lugar_do_objetivo(id)
		var ponto := PlantaDoMapa.meio_do_trilho(lugar["cena"], lugar["area"])
		if ponto.is_finite():
			alvos.append({"id": id, "area": lugar["area"], "ponto": ponto})
	var ao_lado := PackedStringArray()
	var mudou_de_lugar := 0
	for caminho: String in PlantaDoMapa.CENAS:
		for pedaco in PlantaDoMapa.trechos(caminho):
			var id := String(pedaco["area"])
			if id.is_empty():
				continue
			var trilho: Rect2 = pedaco["trilho"]
			var dentro := FolhaDoMapa.caixa_da_sala(id).grow(-FolhaDoMapa.MOLDURA_SALA)
			for fracao: Vector2 in [Vector2.ZERO, Vector2(0.5, 0.5), Vector2.ONE]:
				var cacau := trilho.position + trilho.size * fracao
				_folha.estado = {"area": id, "ponto": cacau}
				for alvo in alvos:
					if alvo["area"] != id:
						continue
					var centro := _folha.centro_do_alvo(alvo["ponto"])
					if centro != FolhaDoMapa.no_papel(alvo["ponto"]).round():
						mudou_de_lugar += 1
					var caixa := Rect2(centro - meia, meia * 2.0)
					if not dentro.encloses(caixa):
						ao_lado.append("%s com a Cacau em %s: sai da sala" % [alvo["id"], cacau])
					for nome in nomes:
						if caixa.intersects(nome):
							ao_lado.append("%s com a Cacau em %s: cobre um nome" % [alvo["id"], cacau])
							break
	_checar(mudou_de_lugar > 0, "com a Cacau em cima do objetivo, o losango sai de baixo dela (%d vezes)" % mudou_de_lugar)
	_checar_lista(ao_lado, "e, ao lado do rosto, ele fica dentro da sala sem cobrir nome")

	var padrao := PackedStringArray()
	for sala in PlantaDoMapa.AREAS:
		var id := String(sala["id"])
		var trilho := PlantaDoMapa.trilho_padrao(id)
		var dentro := FolhaDoMapa.caixa_da_sala(id).grow(-FolhaDoMapa.MOLDURA_SALA)
		for ponta: Vector2 in [trilho.position, trilho.end]:
			if not dentro.encloses(_folha._placa_do_rosto(FolhaDoMapa.no_papel(ponta).round())):
				padrao.append("%s em %s" % [id, ponta])
	_checar_lista(padrao, "o trilho padrão (cena nova sem trilho) também cabe em toda sala")

	var losangos := PackedStringArray()
	for alvo in alvos:
		var caixa := Rect2(FolhaDoMapa.no_papel(alvo["ponto"]).round() - meia, meia * 2.0)
		for nome in nomes:
			if caixa.intersects(nome):
				losangos.append(alvo["id"])
				break
	_checar_lista(losangos, "o losango de nenhum objetivo cobre o nome de uma sala")


func _testar_carimbo() -> void:
	print("\n--- O CARIMBO ---")
	var problemas := PackedStringArray()
	var fora_do_pe := PackedStringArray()
	var na_pequena := PackedStringArray()
	var pe := FolhaDoMapa.CARIMBO.end.y - FolhaDoMapa.MARGEM_CARIMBO
	var etapas := 0
	for trilha in _roteiro.trilhas:
		for etapa in trilha["etapas"]:
			if etapa["objetivos"].is_empty():
				continue
			etapas += 1
			var ids: Array = []
			for objetivo in etapa["objetivos"]:
				ids.append(objetivo["id"])
			# Na sala de nome mais comprido, com o lugar embaixo.
			var objetivos := _objetivos(ids)
			_folha.estado = _folha.montar_estado(PlantaDoMapa.RUA, Vector2.INF, Rect2(), objetivos)
			if not is_equal_approx(_folha._fim_do_carimbo, pe):
				fora_do_pe.append("%s: termina em y = %d" % [ids, _folha._fim_do_carimbo])
			# A primeira linha do primeiro objetivo diz em que letra ele foi.
			for item in _textos(_folha.carimbo()):
				if String(objetivos[0]["texto"]).begins_with(item["texto"]):
					if item["tam"] != FolhaDoMapa.TAM_NOME:
						na_pequena.append(ids[0])
					break
			var problema := _problema_no_carimbo()
			if not problema.is_empty():
				problemas.append("%s: %s" % [ids, problema])
	_checar_lista(problemas, "com os objetivos de cada uma das %d etapas, o carimbo cabe no quadro sem nada se encostar" % etapas)
	_checar_lista(fora_do_pe, "e a legenda fica no pé do carimbo")
	print("  info  na letra pequena (não couberam na grande): %s" % [na_pequena])

	_folha.estado = _folha.montar_estado(PlantaDoMapa.LAB, Vector2.INF, Rect2(), [])
	_checar(not _item_com_texto(_folha.carimbo(), "1/%d SALAS" % PlantaDoMapa.AREAS.size()).is_empty(),
		"a régua de EXPLORAÇÃO conta as salas pisadas (1/%d)" % PlantaDoMapa.AREAS.size())

	_folha.estado = _folha.montar_estado(PlantaDoMapa.LAB, Vector2.INF, Rect2(), _objetivos(["entrar_lab"]))
	var item := _item_com_texto(_folha.carimbo(), "Entre no laboratório")
	_checar(item.get("tam") == FolhaDoMapa.TAM_NOME, "objetivo curto, na letra do caderno (%s)" % item.get("tam"))
	_checar(not _item_com_texto(_folha.carimbo(), "→ LABORATÓRIO").is_empty(), "com \"→ LABORATÓRIO\" embaixo")

	_folha.estado = _folha.montar_estado(PlantaDoMapa.LAB, Vector2.INF, Rect2(), [])
	var juntos := _texto_do_carimbo()
	_checar(juntos.contains("Nenhum objetivo agora."), "sem objetivo, o carimbo manda explorar")
	_checar_lista(_problemas_no_carimbo(), "e cabe no quadro")

	_folha.estado = _folha.montar_estado(PlantaDoMapa.LANCAMENTO, Vector2.INF, Rect2(), _objetivos(["purificador"]))
	juntos = _texto_do_carimbo()
	_checar(juntos.contains("LANÇAMENTO") and juntos.contains("fora do mapa"),
		"na Torre de Lançamento, o nome dela e \"fora do mapa\"")
	_checar_lista(_problemas_no_carimbo(), "e cabe no quadro")


func _testar_estado() -> void:
	print("\n--- O QUE ELE LÊ DO JOGO ---")
	var guardado := _guardar_progresso()
	var lab := _folha.montar_estado(PlantaDoMapa.LAB, Vector2.INF, Rect2(), [])
	_checar(lab["area"] == "laboratorio" and lab["nome"] == "LABORATÓRIO" and lab["lugar"] == "",
		"no laboratório: LABORATÓRIO")
	var oficina := _folha.montar_estado(PlantaDoMapa.OFICINA, Vector2.INF, Rect2(), [])
	_checar(oficina["nome"] == "FASE CARBONO" and oficina["lugar"] == "Oficina do Carbono",
		"na oficina: FASE CARBONO, e o lugar embaixo")
	var chegada := _folha.montar_estado(PlantaDoMapa.WORLD1, Vector2.INF, Rect2(), [])
	_checar(chegada["nome"] == "ÁREA 1" and chegada["lugar"] == "CHEGADA",
		"no world1: ÁREA 1, com o detalhe da sala de lugar")
	var torre := _folha.montar_estado(PlantaDoMapa.LANCAMENTO, Vector2.INF, Rect2(), [])
	var ponto: Vector2 = torre["ponto"]
	_checar(torre["area"] == "" and torre["nome"] == "TORRE DE LANÇAMENTO" \
		and torre["lugar"] == "fora do mapa" and not ponto.is_finite(),
		"na Torre de Lançamento (fora da planta): o nome dela, sem marcador")
	var nada := _folha.montar_estado("res://nada.tscn", Vector2(10, 10), Rect2(0, 0, 99, 99), [])
	ponto = nada["ponto"]
	_checar(nada["nome"] == "FORA DO MAPA" and nada["lugar"] == "" and not ponto.is_finite(),
		"em cena desconhecida: FORA DO MAPA")

	_checar(lab["exploradas"].has("laboratorio") and not lab["exploradas"].has("carbono"),
		"a sala em que ela está conta como explorada; a que ela nunca pisou, não")
	var visitadas: Dictionary = Objetivos._visitadas.duplicate()
	Objetivos._visitadas[PlantaDoMapa.OFICINA] = true
	_checar(_folha.montar_estado(PlantaDoMapa.LAB, Vector2.INF, Rect2(), [])["exploradas"].has("carbono"),
		"depois de visitar a oficina, a FASE CARBONO fica explorada")
	Objetivos._visitadas = visitadas

	var nitrogenio := _folha.montar_estado(PlantaDoMapa.LAB, Vector2.INF, Rect2(),
		_objetivos(["destilar", "pegar_n"]))
	_checar(nitrogenio["alvos"].size() == 1 and nitrogenio["onde"] == PackedStringArray(["FASE NITROGÊNIO"]),
		"dois objetivos na mesma cena: um losango só %s" % [nitrogenio["onde"]])
	var dois := _folha.montar_estado(PlantaDoMapa.LAB, Vector2.INF, Rect2(), _objetivos(["h2", "entrar_lab"]))
	_checar(dois["alvos"].size() == 2 and dois["onde"] == PackedStringArray(["ÁREA 1", "LABORATÓRIO"]),
		"em cenas diferentes: um em cada, na ordem %s" % [dois["onde"]])
	var fora := _folha.montar_estado(PlantaDoMapa.LAB, Vector2.INF, Rect2(), _objetivos(["purificador"]))
	_checar(fora["alvos"].is_empty() and fora["onde"] == PackedStringArray(["TORRE DE LANÇAMENTO"]),
		"objetivo fora da planta: sem losango, mas o carimbo diz onde")

	# O subsolo: a sala é a do trecho em que ela está.
	var fundo := Rect2(0, -500, 5680, 1180)
	var oeste := _folha.montar_estado(PlantaDoMapa.SUBSOLO, Vector2(320, 0), fundo, [])
	_checar(oeste["area"] == "fosforo" and oeste["nome"] == "FASE FÓSFORO" \
		and oeste["lugar"] == "Ala oeste do subsolo", "na ala oeste do subsolo: FASE FÓSFORO")
	var atrio := _folha.montar_estado(PlantaDoMapa.SUBSOLO, Vector2(2800, 0), fundo, [])
	_checar(atrio["area"] == "subsolo" and atrio["nome"] == "SUBSOLO" and atrio["lugar"] == "Átrio central",
		"no átrio: SUBSOLO")
	var areas: Dictionary = Objetivos._areas_visitadas.duplicate()
	Objetivos._areas_visitadas = {}
	_checar(oeste["exploradas"].has("fosforo") and not oeste["exploradas"].has("enxofre"),
		"a ala em que ela está conta como explorada; a outra, não")
	Objetivos._areas_visitadas = {"enxofre": true}
	_checar(_folha.montar_estado(PlantaDoMapa.LAB, Vector2.INF, Rect2(), [])["exploradas"].has("enxofre"),
		"a ala em que ela já pisou fica explorada")
	Objetivos._areas_visitadas = areas
	var alas := _folha.montar_estado(PlantaDoMapa.LAB, Vector2.INF, Rect2(),
		_objetivos(["pegar_p", "botas", "pegar_s"]))
	_checar(alas["alvos"].size() == 2 and alas["onde"] == PackedStringArray(["FASE FÓSFORO", "FASE ENXOFRE"]) \
		and alas["alvos"][0]["ponto"] == PlantaDoMapa.meio_do_trilho(PlantaDoMapa.SUBSOLO, "fosforo"),
		"os objetivos das alas apontam cada um a sua sala %s" % [alas["onde"]])

	Progresso._habilidades = {}
	_checar(not _folha.montar_estado("", Vector2.INF, Rect2(), [])["habilidades"].has("mochila"),
		"sem a mochila, o fosso fica trancado")
	Progresso.dar_habilidade("mochila")
	_checar(_folha.montar_estado("", Vector2.INF, Rect2(), [])["habilidades"].has("mochila"),
		"com ela, o cadeado sai")

	Progresso._celulas = {}
	Progresso._amostras = {}
	var elementos: Dictionary = _folha.montar_estado("", Vector2.INF, Rect2(), [])["elementos"]
	_checar(elementos.keys() == Progresso.CELULAS and elementos.values().all(func(n: int) -> bool: return n == 0),
		"os elementos vêm na ordem do CHONPS, todos faltando %s" % [elementos])
	Progresso.coletar_celula("C")
	_checar(_folha.montar_estado("", Vector2.INF, Rect2(), [])["elementos"]["C"] == 1,
		"a amostra na mão da Cacau: 1")
	Progresso.dar_celula("C")
	_checar(_folha.montar_estado("", Vector2.INF, Rect2(), [])["elementos"]["C"] == 2, "no painel: 2")
	_voltar_progresso(guardado)


func _testar_limites() -> void:
	print("\n--- ATÉ ONDE A CENA VAI ---")
	var cena := Node2D.new()
	add_child(cena)
	var limites := ReferenceRect.new()
	limites.name = "LimitesDaCamera"
	limites.position = Vector2(0, -20)
	limites.size = Vector2(1000, 600)
	cena.add_child(limites)
	var andar := ReferenceRect.new()
	andar.position = Vector2(300, -900)
	andar.size = Vector2(500, 400)
	andar.add_to_group(AndarCamera.GRUPO)
	cena.add_child(andar)
	var zona := Polygon2D.new()
	zona.polygon = PackedVector2Array([Vector2(1200, 0), Vector2(1400, 0), Vector2(1400, 300)])
	zona.add_to_group(ZonaCamera.GRUPO)
	cena.add_child(zona)
	# De outra cena: não conta.
	var de_fora := ReferenceRect.new()
	de_fora.position = Vector2(-5000, -5000)
	de_fora.size = Vector2(10, 10)
	de_fora.add_to_group(AndarCamera.GRUPO)
	add_child(de_fora)

	var total := FolhaDoMapa.limites_da_cena("res://nada.tscn", cena)
	_checar(total.is_equal_approx(Rect2(0, -900, 1400, 1480)),
		"os limites da câmera, os andares e as zonas da cena, somados %s" % total)
	var lab := PlantaDoMapa.LAB
	_checar(FolhaDoMapa.limites_da_cena(lab, cena) == PlantaDoMapa.CENAS[lab]["limites"],
		"o \"limites\" da planta vale mais")
	_checar(FolhaDoMapa.limites_da_cena("res://nada.tscn", null) == Rect2(), "sem cena, nada")
	cena.free()
	de_fora.free()


## O Objetivos anota as salas em que ela pisa nas cenas com trechos.
func _testar_salas_pisadas() -> void:
	print("\n--- AS SALAS EM QUE ELA PISOU ---")
	var cena := get_tree().current_scene
	var caminho := cena.scene_file_path
	var visitadas: Dictionary = Objetivos._visitadas.duplicate()
	var areas: Dictionary = Objetivos._areas_visitadas.duplicate()
	Objetivos._areas_visitadas = {}
	cena.scene_file_path = PlantaDoMapa.SUBSOLO
	_cacau.global_position = Vector2(2800, 500)
	await _esperar(0.3)
	_checar(Objetivos.visitou_area("subsolo") and not Objetivos.visitou_area("fosforo") \
		and not Objetivos.visitou_area("enxofre"), "chegando ao átrio do subsolo, só o SUBSOLO fica pisado")
	_cacau.global_position = Vector2(320, 500)
	await _esperar(0.3)
	_checar(Objetivos.visitou_area("fosforo") and not Objetivos.visitou_area("enxofre"),
		"andando até a ala oeste, a FASE FÓSFORO também")
	cena.scene_file_path = caminho
	_cacau.global_position = Vector2.ZERO
	await _esperar(0.2)
	Objetivos._visitadas = visitadas
	Objetivos._areas_visitadas = areas


## O Q das abas é tecla desenhada nova (BotoesControle), como o E e o F do
## tutorial do bumerangue: os 4 quadros de apertar estão na folha do teclado,
## o desenho não repete o de uma vizinha, e ela entrou no fim da lista, sem
## mudar o código dos botões que já existiam.
func _testar_tecla_q() -> void:
	print("\n--- A TECLA Q ---")
	var folha: Texture2D = BotoesControle.FOLHA_TECLADO
	var imagem := folha.get_image()
	var canto := Vector2(64, 48)
	var certos := 0
	var desenhados := 0
	for quadro in BotoesControle.QUADROS_APERTANDO:
		var arte := BotoesControle.icone("tecla_q", quadro) as AtlasTexture
		var esperado := Rect2(canto + BotoesControle.PASSO_QUADRO_TECLADO * quadro, Vector2(16, 16))
		if arte != null and arte.atlas == folha and arte.region == esperado:
			certos += 1
		if imagem.get_region(Rect2i(esperado)).get_used_rect().size.x >= 12:
			desenhados += 1
	_checar(BotoesControle.existe("tecla_q") and BotoesControle.anima("tecla_q")
		and certos == BotoesControle.QUADROS_APERTANDO and desenhados == certos,
		"o Q está na folha do teclado, com os 4 quadros de apertar")
	var q := Rect2i(Rect2(canto, Vector2(16, 16)))
	var iguais := PackedStringArray()
	for vizinha in ["tecla_w", "tecla_e", "tecla_a"]:
		var regiao: Rect2 = BotoesControle.TECLAS[vizinha]
		if imagem.get_region(q).get_data() == imagem.get_region(Rect2i(regiao)).get_data():
			iguais.append(vizinha)
	_checar(iguais.is_empty(), "e o desenho do Q não é o de uma vizinha %s" % iguais)
	_checar(BotoesControle.caractere("tecla_f").unicode_at(0) == BotoesControle.PRIMEIRO_CODIGO + 27
		and BotoesControle.caractere("tecla_q").unicode_at(0) == BotoesControle.PRIMEIRO_CODIGO + 28,
		"o Q entrou no fim da lista, depois do F: os botões dos textos já montados não mudaram de código")


func _testar_abas() -> void:
	print("\n--- AS ABAS ---")
	var trocas: Array[int] = []
	Caderno.aba_mudou.connect(func(aba: int) -> void: trocas.append(aba))
	await _esperar(0.35)
	var tela := get_viewport().get_visible_rect()
	var abas := Caderno.abas()
	var livro := Caderno.livro()
	var mapa := Caderno.mapa()
	var icone: CadernoIcone = Caderno.get_node("Icone")
	var do_mapinha := icone.centro_do_mapa()
	_checar(do_mapinha.x > icone.centro_do_caderno().x + 40.0 \
		and icone.get_global_rect().has_point(do_mapinha), "o ícone tem o caderninho e, ao lado, o mapinha")
	_tecla(KEY_M)
	await _quadros(2)
	# A folha anda em linha reta do desenho dela no ícone até o meio da tela
	# (e, da do caderninho, ficaria a dezenas de px desta linha).
	var meio_da_folha := mapa.position + mapa.pivot_offset
	var no_caminho := Geometry2D.get_closest_point_to_segment(meio_da_folha, do_mapinha,
		Caderno._centro_do_conteudo())
	_checar(Caderno.aberto() and Caderno.aba() == Caderno.Aba.MAPA and mapa.visible and not livro.visible \
		and meio_da_folha.distance_to(no_caminho) < 2.0,
		"a primeira vez, M abre no MAPA, que sai do mapinha do ícone (%s)" % meio_da_folha)
	await _esperar(Caderno.DURACAO_ABRIR + 0.1)
	_checar(Caderno.aba() == Caderno.Aba.MAPA and mapa.visible and not livro.visible and trocas.is_empty(),
		"aberto no MAPA, sem o caderno")
	var faixa := abas.get_global_rect()
	_checar(abas.visible and tela.encloses(faixa) and absf(faixa.get_center().x - tela.get_center().x) <= 1.0,
		"as abas aparecem inteiras, no meio do alto da tela %s" % faixa)
	_checar(abas.atual == Caderno.Aba.MAPA and abas.teclas() == PackedStringArray(["tecla_q", "tecla_e"]),
		"a aba MAPA acesa, com Q e E nas pontas")
	var caixa := Rect2(mapa.position, FolhaDoMapa.TAMANHO)
	_checar(mapa.scale.is_equal_approx(Vector2.ONE) and mapa.position == mapa.position.round() \
		and is_equal_approx(mapa.modulate.a, 1.0), "em tamanho natural, no pixel inteiro, aceso")
	_checar(tela.encloses(caixa) and caixa.position.y >= faixa.end.y \
		and caixa.end.y <= tela.size.y - Caderno.ALTURA_BARRA - 10.0,
		"cabe entre as abas e a barra de comandos %s" % caixa)
	var dicas: Array = Caderno._dicas().map(func(d: Array) -> String: return d[1])
	_checar(dicas == ["FECHAR"], "no mapa, o rodapé só diz FECHAR %s" % [dicas])
	var estado := mapa.estado
	var ponto: Vector2 = estado.get("ponto", Vector2.ZERO)
	_checar(estado.get("nome") == "FORA DO MAPA" and not ponto.is_finite(),
		"numa cena fora do mapa, o carimbo diz FORA DO MAPA, sem marcador")
	_checar(mapa.mouse_filter == Control.MOUSE_FILTER_STOP, "o mapa segura o clique (não fecha o caderno)")

	var pagina := livro.pagina()
	_tecla(KEY_D)
	await _quadros(3)
	_checar(not livro.virando() and livro.pagina() == pagina, "no mapa, D não folheia")

	_tecla(KEY_E)
	await _quadros(1)
	_checar(Caderno.aba() == Caderno.Aba.CADERNO and trocas == [Caderno.Aba.CADERNO],
		"E troca para o CADERNO (as pontas se emendam)")
	var as_duas := false
	var sai_pela_esquerda := false
	var entra_pela_direita := false
	var inicio := Time.get_ticks_msec()
	while Caderno._aba_saindo >= 0 and Time.get_ticks_msec() - inicio < 2000:
		if livro.visible and mapa.visible:
			as_duas = true
			sai_pela_esquerda = sai_pela_esquerda or Caderno._deslize(Caderno.Aba.MAPA) < 0
			entra_pela_direita = entra_pela_direita or Caderno._deslize(Caderno.Aba.CADERNO) > 0
		await _quadros(1)
	_checar(as_duas and sai_pela_esquerda and entra_pela_direita,
		"na troca, o mapa sai pela esquerda enquanto o caderno entra pela direita")
	await _quadros(2)
	_checar(livro.visible and not mapa.visible and abas.atual == Caderno.Aba.CADERNO,
		"depois, só o caderno, com a aba CADERNO acesa")
	var desenho := Rect2(livro.position + CadernoLivro.CAIXA_DESENHO.position, CadernoLivro.CAIXA_DESENHO.size)
	_checar(desenho.position.y >= faixa.end.y, "o caderno fica abaixo das abas %s" % desenho)
	await _capturar("1_abas_caderno")

	_tecla(KEY_M)
	await _esperar(Caderno.DURACAO_FECHAR + 0.1)
	_checar(not Caderno.aberto() and not get_tree().paused, "M fecha")
	await _esperar(0.3)
	_tecla(KEY_M)
	await _esperar(Caderno.DURACAO_ABRIR + 0.1)
	_checar(Caderno.aba() == Caderno.Aba.CADERNO and livro.visible and not mapa.visible,
		"e abre de novo no CADERNO, onde ficou (o mapa é só a primeira vez)")
	_tecla(KEY_Q)
	await _quadros(1)
	_checar(Caderno.aba() == Caderno.Aba.MAPA, "Q também troca")
	await _esperar(Caderno.DURACAO_TROCA + 0.05)

	_tecla(KEY_M)
	await _esperar(Caderno.DURACAO_FECHAR + 0.1)
	_checar(not Caderno.aberto() and not get_tree().paused, "M fecha, também no mapa")
	await _esperar(0.3)
	_tecla(KEY_M)
	await _esperar(Caderno.DURACAO_ABRIR + 0.1)
	_checar(Caderno.aba() == Caderno.Aba.MAPA and mapa.visible and not livro.visible,
		"e abre de novo no MAPA, onde ficou")

	_clicar_nas_abas(abas.caixa_da_aba(Caderno.Aba.CADERNO).get_center())
	await _quadros(1)
	_checar(Caderno.aba() == Caderno.Aba.CADERNO, "clicar na aba CADERNO troca")
	await _esperar(Caderno.DURACAO_TROCA + 0.05)
	_clicar_nas_abas(Vector2(4, abas.size.y * 0.5))
	await _quadros(1)
	_checar(Caderno.aba() == Caderno.Aba.MAPA, "clicar na tecla desenhada na ponta também")
	await _esperar(Caderno.DURACAO_TROCA + 0.05)

	# Trocar para o mapa lê o jogo de novo: a Cacau no laboratório, na porta do
	# simulador.
	_tecla(KEY_Q)
	await _esperar(Caderno.DURACAO_TROCA + 0.05)
	var cena := get_tree().current_scene
	var caminho := cena.scene_file_path
	var visitadas: Dictionary = Objetivos._visitadas.duplicate()
	cena.scene_file_path = PlantaDoMapa.LAB
	_cacau.global_position = Vector2(1023, 120)
	_tecla(KEY_E)
	await _esperar(Caderno.DURACAO_TROCA + 0.05)
	estado = mapa.estado
	ponto = estado.get("ponto", Vector2.INF)
	var esperado := PlantaDoMapa.ponto_no_mapa(PlantaDoMapa.LAB, Vector2(1023, 120),
		PlantaDoMapa.CENAS[PlantaDoMapa.LAB]["limites"])
	_checar(estado.get("area") == "laboratorio" and estado.get("nome") == "LABORATÓRIO" \
		and ponto.is_equal_approx(esperado),
		"ao trocar para o mapa, ele lê o jogo: a Cacau no laboratório, onde ela está %s" % ponto)
	cena.scene_file_path = caminho
	_tecla(KEY_M)
	await _esperar(Caderno.DURACAO_FECHAR + 0.1)
	Objetivos._visitadas = visitadas

	Caderno.mostrar_aba(Caderno.Aba.CADERNO)
	_checar(Caderno.aba() == Caderno.Aba.CADERNO and abas.atual == Caderno.Aba.CADERNO and not Caderno.aberto(),
		"fechado, mostrar_aba() só escolhe a aba em que ele vai abrir")
	Caderno.mostrar_aba(Caderno.Aba.MAPA)
	var nota: String = PaginasCaderno.NOTAS.keys()[0]
	_checar(Caderno.guardar_nota(nota) and Caderno.aba() == Caderno.Aba.MAPA and icone.novidade,
		"nota nova não muda a aba (continua no MAPA): só acende a marca no ícone")
	await _esperar(0.3)
	_tecla(KEY_M)
	await _esperar(Caderno.DURACAO_ABRIR + 0.1)
	_checar(Caderno.aba() == Caderno.Aba.MAPA and mapa.visible and not livro.visible,
		"com a nota esperando, o caderno abre no MAPA, onde ficou")
	_checar(icone.novidade and abas.tem_nota_nova(),
		"e a marca de nota nova aparece na aba CADERNO (no mapa a nota não foi vista)")
	await _capturar("1b_nota_nova_na_aba")
	_tecla(KEY_Q)
	await _esperar(Caderno.DURACAO_TROCA + 0.05)
	_checar(Caderno.aba() == Caderno.Aba.CADERNO and livro.visible and not mapa.visible \
		and livro.pagina() == PaginasCaderno.lugar_da_nota(nota),
		"trocando para o CADERNO, ele já está na página da nota")
	_checar(not icone.novidade and not abas.tem_nota_nova(), "e a marca apaga, no ícone e na aba")
	_tecla(KEY_M)
	await _esperar(Caderno.DURACAO_FECHAR + 0.1)


func _testar_controle() -> void:
	print("\n--- CONTROLE ---")
	await _esperar(0.3)
	_botao(JOY_BUTTON_Y, true)
	await _quadros(2)
	_botao(JOY_BUTTON_Y, false)
	_checar(Controle.em_uso and Caderno.aberto(), "△ abre o caderno")
	await _esperar(Caderno.DURACAO_ABRIR + 0.1)
	_checar(Caderno.abas().teclas() == PackedStringArray(["l1", "r1"]), "com o controle, L1 e R1 nas pontas das abas")
	var antes := Caderno.aba()
	_botao(JOY_BUTTON_RIGHT_SHOULDER, true)
	await _quadros(2)
	_botao(JOY_BUTTON_RIGHT_SHOULDER, false)
	_checar(Caderno.aba() == posmod(antes + 1, Caderno.Aba.size()), "R1 troca de aba")
	await _esperar(Caderno.DURACAO_TROCA + 0.05)
	if Caderno.aba() == Caderno.Aba.MAPA:
		var dicas: Array = Caderno._dicas()
		_checar(dicas.size() == 1 and dicas[0][0] == ["triangulo"], "no mapa, só o △ FECHAR no rodapé")
		await _capturar("6_abas_controle")
	_botao(JOY_BUTTON_LEFT_SHOULDER, true)
	await _quadros(2)
	_botao(JOY_BUTTON_LEFT_SHOULDER, false)
	_checar(Caderno.aba() == antes, "L1 volta")
	await _esperar(Caderno.DURACAO_TROCA + 0.05)
	_botao(JOY_BUTTON_Y, true)
	await _quadros(2)
	_botao(JOY_BUTTON_Y, false)
	_checar(not Caderno.aberto(), "△ fecha")
	await _esperar(Caderno.DURACAO_FECHAR + 0.1)
	_tecla(KEY_F10)  # volta para o teclado
	await _quadros(2)


## Alguns momentos do jogo, com o estado montado à mão.
func _testar_capturas() -> void:
	if not _capturando():
		return
	print("\n--- CAPTURAS ---")
	var guardado := _guardar_progresso()
	var visitadas: Dictionary = Objetivos._visitadas.duplicate()
	var areas: Dictionary = Objetivos._areas_visitadas.duplicate()
	await _esperar(0.3)
	if Caderno.aba() != Caderno.Aba.MAPA:
		Caderno.mostrar_aba(Caderno.Aba.MAPA)
	_tecla(KEY_M)
	await _esperar(Caderno.DURACAO_ABRIR + 0.1)
	var mapa := Caderno.mapa()
	var p := PlantaDoMapa

	_visitar([])
	_progresso([], [], [])
	mapa.estado = mapa.montar_estado(p.WORLD1, Vector2(1700, 0), p.CENAS[p.WORLD1]["limites"],
		_objetivos(["h2", "o2", "caixa"]))
	await _capturar("2_mapa_comeco")

	_visitar([p.WORLD1, p.LAB, p.OFICINA, p.CORREDOR_PATIO, p.PATIO])
	_progresso(["H", "O"], [], ["bumerangue", "macarico"])
	mapa.estado = mapa.montar_estado(p.PATIO, Vector2(700, 300), Rect2(0, -87, 1185, 667),
		_objetivos(["carvao"]))
	await _capturar("3_mapa_patio")

	_visitar([p.WORLD1, p.LAB, p.OFICINA, p.CORREDOR_PATIO, p.PATIO, p.CORREDOR_TORRE, p.RUA,
		p.DESTILACAO, p.TORRE])
	_progresso(["H", "O", "C"], [], ["bumerangue", "macarico", "mochila"])
	mapa.estado = mapa.montar_estado(p.TORRE, Vector2(500, -2600), Rect2(0, -4668, 1088, 5288),
		_objetivos(["cilindro"]))
	await _capturar("4_mapa_torre")

	_visitar([p.WORLD1, p.LAB, p.SIMULADOR, p.OFICINA, p.CORREDOR_PATIO, p.PATIO, p.CORREDOR_TORRE,
		p.RUA, p.COMPRESSOR, p.DESTILACAO, p.TORRE, p.TELHADO])
	_progresso(["H", "O", "C"], ["N"], ["bumerangue", "macarico", "mochila"])
	mapa.estado = mapa.montar_estado(p.LAB, Vector2(1900, 0), p.CENAS[p.LAB]["limites"],
		_objetivos(["entregar_n"]))
	await _capturar("5_mapa_lab")

	_visitar(p.CENAS.keys(), ["subsolo", "fosforo", "enxofre"])
	_progresso(Progresso.CELULAS, [], Progresso.HABILIDADES)
	mapa.estado = mapa.montar_estado(p.LANCAMENTO, Vector2.INF, Rect2(), _objetivos(["purificador"]))
	await _capturar("7_mapa_fora")

	_visitar(p.CENAS.keys().filter(func(c: String) -> bool: return c != p.LANCAMENTO), ["subsolo", "fosforo"])
	_progresso(["H", "O", "C", "N"], [], ["bumerangue", "macarico", "mochila"])
	mapa.estado = mapa.montar_estado(p.SUBSOLO, Vector2(700, 500), Rect2(0, -500, 5680, 1180),
		_objetivos(["pegar_p", "botas"]))
	await _capturar("8_mapa_subsolo")

	_tecla(KEY_M)
	await _esperar(Caderno.DURACAO_FECHAR + 0.1)
	_voltar_progresso(guardado)
	Objetivos._visitadas = visitadas
	Objetivos._areas_visitadas = areas


# ─────────────────────────────────────────────────────────────

func _ids(objetivos: Array) -> Array:
	return objetivos.map(func(o: Dictionary) -> String: return o["id"])


## Os objetivos do roteiro com estes ids, como o Objetivos.atuais() os dá.
func _objetivos(ids: Array) -> Array:
	var lista: Array = []
	for id in ids:
		var achou := false
		for trilha in _roteiro.trilhas:
			for etapa in trilha["etapas"]:
				for objetivo in etapa["objetivos"]:
					if objetivo["id"] == id and not achou:
						achou = true
						lista.append({"id": id, "texto": objetivo["texto"], "pai": objetivo["pai"],
							"titulo": trilha["titulo"], "cor": trilha["cor"]})
	return lista


func _textos(itens: Array) -> Array[Dictionary]:
	var textos: Array[Dictionary] = []
	for item: Dictionary in itens:
		if item.has("texto"):
			textos.append(item)
	return textos


func _item_com_texto(itens: Array, texto: String) -> Dictionary:
	for item: Dictionary in itens:
		if item.get("texto") == texto:
			return item
	return {}


## Os textos do carimbo, um atrás do outro.
func _texto_do_carimbo() -> String:
	var juntos := PackedStringArray()
	for item in _textos(_folha.carimbo()):
		juntos.append(item["texto"])
	return " ".join(juntos)


## O que está errado no carimbo montado agora ("" = nada): peça fora do quadro,
## ou texto encostando em outra peça.
func _problema_no_carimbo() -> String:
	var quadro := FolhaDoMapa.CARIMBO.grow(-FolhaDoMapa.MARGEM_CARIMBO * 0.5)
	var itens := _folha.carimbo()
	var caixas: Array[Rect2] = []
	for item: Dictionary in itens:
		var caixa := _caixa_do_item(item)
		caixas.append(caixa)
		if not quadro.encloses(caixa):
			return "%s sai do quadro %s" % [_nome_do_item(item), caixa]
	for i in itens.size():
		if not itens[i].has("texto"):
			continue
		for j in itens.size():
			if j != i and caixas[i].intersects(caixas[j]):
				return "%s encosta em %s" % [_nome_do_item(itens[i]), _nome_do_item(itens[j])]
	return ""


## O mesmo, em lista (vazia = nada errado), para o _checar_lista.
func _problemas_no_carimbo() -> PackedStringArray:
	var problema := _problema_no_carimbo()
	return PackedStringArray() if problema.is_empty() else PackedStringArray([problema])


func _caixa_do_item(item: Dictionary) -> Rect2:
	if item.has("texto"):
		return FolhaDoMapa.caixa_do_texto(item)
	for chave in ["faixa", "ficha", "tracejado", "elemento", "caixinha"]:
		if item.has(chave):
			return item[chave]
	if item.has("losango"):
		var r: float = item["raio"] + 2.0
		return Rect2(item["losango"] - Vector2(r, r), Vector2(r, r) * 2.0)
	if item.has("rosto"):
		var tamanho := FolhaDoMapa.RECORTE_ROSTO.size
		return Rect2(item["rosto"] - tamanho * 0.5, tamanho)
	if item.has("cadeado"):
		var lado := Vector2(String(FolhaDoMapa.CADEADO[0]).length(), FolhaDoMapa.CADEADO.size()) \
			* FolhaDoMapa.PIXEL_CADEADO
		return Rect2(item["cadeado"] - lado * 0.5, lado)
	return Rect2()


func _nome_do_item(item: Dictionary) -> String:
	return "\"%s\"" % item["texto"] if item.has("texto") else String(item.keys()[0])


## O x do nó na cena (a soma dos "position" dos pais): a cena instanciada não
## está na árvore, e o global_position não vale.
func _x_na_cena(no: Node) -> float:
	var x := 0.0
	while no != null:
		if no is Node2D:
			x += (no as Node2D).position.x
		no = no.get_parent()
	return x


## Os nós da cena com porta para outra cena (o "cena_destino" preenchido).
func _portas(no: Node) -> Array[Node]:
	var lista: Array[Node] = []
	if "cena_destino" in no and not String(no.get("cena_destino")).is_empty():
		lista.append(no)
	for filho in no.get_children():
		lista.append_array(_portas(filho))
	return lista


func _passagem(a: String, b: String) -> Dictionary:
	for passagem in PlantaDoMapa.PASSAGENS:
		if _par(passagem["de"], passagem["para"]) == _par(a, b):
			return passagem
	return {}


func _par(a: String, b: String) -> String:
	return "%s|%s" % ([a, b] if a < b else [b, a])


func _guardar_progresso() -> Array:
	return [Progresso._celulas.duplicate(), Progresso._amostras.duplicate(),
		Progresso._habilidades.duplicate()]


func _voltar_progresso(copia: Array) -> void:
	Progresso._celulas = copia[0]
	Progresso._amostras = copia[1]
	Progresso._habilidades = copia[2]


## O Progresso das capturas: as letras no painel, as na mão e as habilidades.
func _progresso(no_painel: Array, na_mao: Array, habilidades: Array) -> void:
	Progresso._celulas = {}
	Progresso._amostras = {}
	Progresso._habilidades = {}
	for letra in no_painel:
		Progresso._celulas[letra] = true
	for letra in na_mao:
		Progresso._amostras[letra] = true
	for habilidade in habilidades:
		Progresso._habilidades[habilidade] = true


## As cenas visitadas e as salas pisadas das capturas.
func _visitar(cenas: Array, areas: Array = []) -> void:
	Objetivos._visitadas = {}
	Objetivos._areas_visitadas = {}
	for cena in cenas:
		Objetivos._visitadas[cena] = true
	for area in areas:
		Objetivos._areas_visitadas[area] = true


func _tecla(codigo: Key) -> void:
	_apertar(codigo, true)
	_apertar(codigo, false)


func _apertar(codigo: Key, apertada: bool) -> void:
	var evento := InputEventKey.new()
	evento.keycode = codigo
	evento.physical_keycode = codigo
	evento.pressed = apertada
	Input.parse_input_event(evento)


func _botao(botao: JoyButton, apertado: bool) -> void:
	var evento := InputEventJoypadButton.new()
	evento.device = 0
	evento.button_index = botao
	evento.pressed = apertado
	Input.parse_input_event(evento)


## Clique nas abas (px delas). Vai direto para o _gui_input: sem janela
## (headless) o mouse nunca "entra" nela.
func _clicar_nas_abas(ponto: Vector2) -> void:
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = true
	evento.position = ponto
	Caderno.abas()._gui_input(evento)


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos, true, false, true).timeout


func _capturando() -> bool:
	return not _pasta_capturas.is_empty() and DisplayServer.get_name() != "headless"


func _capturar(nome: String) -> void:
	if not _capturando():
		return
	await RenderingServer.frame_post_draw
	var imagem := get_viewport().get_texture().get_image()
	imagem.save_png(_pasta_capturas.path_join(nome + ".png"))
