extends Node

# Teste da fase do nitrogênio por inteiro (a rua, as salas, o telhado e a torre):
#
#   godot --headless --path . res://tools/teste_fase2.tscn
#
# (Sem --fixed-fps: o congelamento de impacto do dash conta tempo de verdade.)
#
# Casos:
#   * AS CENAS: as cinco abrem; todas são fases (FaseBase), com a Cacau de um
#     pulo só (max_jumps 1), câmera limitada e ponto de nascimento;
#   * OS PARES: toda porta, passagem e elevador da fase leva a uma cena que tem
#     quem receba a tag dela — e o elevador da rua e o do telhado se respondem;
#   * A RUA: a cabine do elevador de carga começa lá no telhado (o poço da rua
#     fica vazio, sem estrado, e o E nele só dá a fala); descendo nela, a cabine
#     chega junto e fica onde a Cacau a deixou; com a amostra gelada na mão, a
#     saída para o corredor, a porta da torre e o elevador barram;
#   * O TELHADO: chegar marca a subida e a Cacau comenta; a cabine está lá, no
#     meio de um poço igual ao da fachada da rua; o cilindro de amostra vai
#     para a mochila e não volta mais; com a cabine lá na rua, o poço do
#     telhado fica vazio;
#   * A TORRE: sem a mochila, a Cacau comenta o degrau alto — e o pulo duplo
#     não chega nele; com a mochila, pulo + jato chega; o ventilador desliga o
#     vapor; a caixa elétrica recolhe as serras da chaminé; as plataformas
#     laranja viram plataformas que caem; as janelas são do tamanho das da
#     sala do compressor e nenhuma fica atrás de uma placa ou de uma porta;
#   * AS SALAS: o compressor na sala dele; a mochila, a coluna e o cilindro de
#     nitrogênio (ligado à coluna) na sala de destilação — que é a sala do
#     compressor tile por tile: as quatro camadas (Terreno, Fundo, Cenario e
#     Janelas) com os mesmos tiles nas mesmas posições e a mesma câmera; fechada
#     e com chão de concreto.

const RUA := MissaoNitrogenio.CENA_RUA
const CENAS := [
	MissaoNitrogenio.CENA_RUA,
	MissaoNitrogenio.CENA_COMPRESSOR,
	MissaoNitrogenio.CENA_DESTILACAO,
	MissaoNitrogenio.CENA_TORRE,
	MissaoNitrogenio.CENA_TELHADO,
]
const SCRIPT_PORTA := "res://scripts/porta_simulador.gd"
## O topo do primeiro degrau da torre (y do piso dele) e a beirada esquerda.
const DEGRAU_Y := 256.0
const DEGRAU_X := 704.0
## As camadas de tiles que a sala de destilação copia da sala do compressor.
const CAMADAS_DA_SALA := ["Terreno", "Fundo", "Cenario", "Janelas"]
## A janela do Buildings.png: o canto de cima à esquerda no atlas e o tamanho,
## em tiles.
const JANELA_CANTO := Vector2i(9, 0)
const JANELA_TAMANHO := Vector2i(2, 3)
## O piso da sala de destilação e, do centro da cápsula da Cacau, a sola.
const PISO_DA_DESTILACAO := 512.0
const ATE_A_SOLA := 36.0

var _falhas := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# O teste sai de cena: as trocas de cena de verdade não o apagam.
	get_tree().current_scene = null
	_rodar()


func _rodar() -> void:
	EstadoMundo.revelou_dr_chico = true
	MissaoNitrogenio.esquecer()
	# Ferramentas dadas pelo teste vão direto para os equipamentos, sem a ficha
	# de coleta parando o jogo.
	FerramentasHUD.apresentar_ferramentas = false
	_testar_cenas()
	_testar_pares()
	await _testar_rua()
	await _testar_telhado()
	await _testar_torre()
	await _testar_salas()
	MissaoNitrogenio.esquecer()
	FerramentasHUD.apresentar_ferramentas = true
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


# ─────────────────────────────────────────────────────────────

func _testar_cenas() -> void:
	print("\n--- AS CENAS ---")
	for caminho in CENAS:
		var cena: Node = (load(caminho) as PackedScene).instantiate()
		var nome: String = caminho.get_file()
		var player := cena.get_node_or_null("Player")
		_checar(cena is FaseBase, "%s é uma fase (FaseBase)" % nome)
		_checar(player != null and player.max_jumps == 1, "   a Cacau com um pulo só (max_jumps 1)")
		_checar(cena.get_node_or_null("LimitesDaCamera") is ReferenceRect
			and cena.get_node_or_null("SpawnPadrao") is Marker2D, "   com LimitesDaCamera e SpawnPadrao")
		cena.free()


func _testar_pares() -> void:
	print("\n--- OS PARES (portas, passagens e elevadores) ---")
	var script_porta := load(SCRIPT_PORTA)
	var recebe := {}   # cena -> {tag: tipo}
	var saidas: Array[Dictionary] = []
	for caminho in CENAS:
		var cena: Node = (load(caminho) as PackedScene).instantiate()
		recebe[caminho] = {}
		for no in cena.find_children("*", "", true, false):
			var tipo := ""
			if no.get_script() == script_porta:
				tipo = "porta"
			elif no is PassagemDeCena:
				tipo = "porta"  # porta e passagem conversam pelas mesmas tags
			elif no is ElevadorFase:
				tipo = "elevador"
			if tipo == "":
				continue
			# A passagem sempre recebe quem chega pela tag dela.
			var recebe_aqui: bool = true if no is PassagemDeCena else no.recebe_chegada
			if recebe_aqui and no.tag_aqui != "":
				recebe[caminho][no.tag_aqui] = tipo
			if no.cena_destino != "":
				saidas.append({"de": caminho, "no": str(no.name), "para": no.cena_destino,
					"tag": no.tag_destino, "tipo": tipo})
		cena.free()
	for s in saidas:
		if not s.para in CENAS:
			continue
		var tipo: String = recebe[s.para].get(s.tag, "")
		_checar(tipo == s.tipo, "%s/%s -> %s: recebe \"%s\" (%s)" % [s.de.get_file(), s.no, s.para.get_file(),
			s.tag, tipo if tipo != "" else "ninguém"])
	_checar(recebe[RUA].get("rua", "") == "elevador" and recebe[MissaoNitrogenio.CENA_TELHADO].get("telhado", "") == "elevador",
		"os elevadores da rua e do telhado recebem um do outro")


func _testar_rua() -> void:
	print("\n--- A RUA ---")
	await _abrir(RUA)
	await _segundos(1.0)
	var rua := get_tree().current_scene
	var elevador := rua.get_node("ElevadorDeCarga") as ElevadorFase
	var porta_torre := rua.get_node("PortaTorre")
	_checar(not elevador.cabine_aqui and not elevador.get_node("Cabine").visible
		and elevador.get_node("Cabine/Piso").process_mode == Node.PROCESS_MODE_DISABLED,
		"a cabine do elevador de carga começa lá no telhado: o poço da rua fica vazio")
	var player := _player()
	_pousar(player, elevador.global_position + Vector2(0.0, -60.0))
	await _segundos(0.6)
	var pes: float = player.global_position.y + elevador._altura_dos_pes(player)
	_checar(player.is_on_floor() and absf(pes - elevador.global_position.y) < 3.0,
		"   no poço vazio a Cacau pisa no chão da rua (o estrado sumiu junto)")
	elevador._partir()
	await _quadros(3)
	_checar(get_tree().current_scene == rua and Dialogic.current_timeline != null
		and elevador.fala_trancada == "cacau_elevador_parado",
		"   e o E nele só dá a fala de que ele está parado lá em cima")
	await _encerrar_fala()
	_checar(not rua.segura_a_saida() and porta_torre.interativa, "sem a amostra, a rua deixa ir para todo lado")

	# Descendo do telhado nele: a cabine chega com a Cacau e fica na rua.
	ElevadorFase.chegando_de_elevador = true
	ElevadorFase.tag_chegada = "rua"
	await _abrir(RUA)
	elevador = get_tree().current_scene.get_node("ElevadorDeCarga") as ElevadorFase
	_checar(elevador.cabine_aqui and elevador.get_node("Cabine").visible
		and not MissaoNitrogenio.elevador_no_telhado,
		"descendo nele, a cabine chega junto com a Cacau")
	await _esperar(func() -> bool: return elevador._estado == ElevadorFase.Estado.PARADO, 8.0)
	_checar(elevador.liberado, "   e daí em diante é o atalho de volta para cima")
	await _abrir(RUA)
	rua = get_tree().current_scene
	elevador = rua.get_node("ElevadorDeCarga") as ElevadorFase
	porta_torre = rua.get_node("PortaTorre")
	_checar(elevador.cabine_aqui, "   voltando à rua a pé, a cabine continua onde ela a deixou")

	MissaoNitrogenio.amostra = GasFechado.new(1.0, 3.0, 80.0)
	await _quadros(2)
	_checar(rua.segura_a_saida(), "com a amostra gelada na mão, a saída para o corredor barra")
	_checar(not porta_torre.interativa, "   a porta da torre não abre")
	_checar(not elevador.liberado and elevador.fala_trancada == "cacau_amostra_pressa",
		"   e o elevador também não (a Cacau diz que não dá tempo)")
	MissaoNitrogenio.amostra = null
	MissaoNitrogenio.elevador_no_telhado = true


func _testar_telhado() -> void:
	print("\n--- O TELHADO ---")
	Inventario.remover_item(MissaoNitrogenio.ID_CILINDRO_VAZIO)
	await _abrir(MissaoNitrogenio.CENA_TELHADO)
	var telhado := get_tree().current_scene
	_checar(MissaoNitrogenio.subiu_a_torre, "chegar ao telhado marca a subida da torre")
	var elevador := telhado.get_node("ElevadorDeCarga") as ElevadorFase
	_checar(elevador.cabine_aqui and elevador.get_node("Cabine").visible,
		"a cabine do elevador de carga está parada lá em cima")
	_checar(_poco_embaixo_da_cabine(telhado, elevador),
		"   no meio do poço, igual ao da fachada da rua: trilhos e faixa escura embaixo da laje")
	var cilindro := telhado.get_node_or_null("CilindroDeAr") as CilindroDoTelhado
	_checar(cilindro != null, "o cilindro de amostra está lá")
	await _esperar(func() -> bool: return Dialogic.current_timeline != null, 4.0)
	_checar(Dialogic.current_timeline != null, "e a Cacau comenta ao chegar")
	await _encerrar_fala()
	if cilindro == null:
		return
	cilindro._pegar()
	await _esperar(func() -> bool: return Inventario.popup_aberto, 3.0)
	_checar(Inventario.popup_aberto, "pegar abre a ficha do cilindro")
	if Inventario.tela_hud_referencia:
		await Inventario.tela_hud_referencia.fechar_popup()
	await _esperar(func() -> bool: return MissaoNitrogenio.tem_cilindro_vazio(), 3.0)
	_checar(MissaoNitrogenio.tem_cilindro_vazio(), "e ele vai para a mochila")
	await _encerrar_fala()
	await _abrir(MissaoNitrogenio.CENA_TELHADO)
	await _quadros(3)
	_checar(get_tree().current_scene.get_node_or_null("CilindroDeAr") == null, "voltando ao telhado, ele não está mais lá")
	await _encerrar_fala()

	# Desceu nele e subiu de novo pela escada: a cabine ficou lá na rua.
	MissaoNitrogenio.elevador_no_telhado = false
	await _abrir(MissaoNitrogenio.CENA_TELHADO)
	elevador = get_tree().current_scene.get_node("ElevadorDeCarga") as ElevadorFase
	_checar(not elevador.cabine_aqui and elevador.fala_trancada == "cacau_elevador_la_embaixo",
		"com a cabine lá na rua, o poço do telhado fica vazio (e a Cacau diz por quê)")
	await _encerrar_fala()
	MissaoNitrogenio.elevador_no_telhado = true


func _testar_torre() -> void:
	print("\n--- A TORRE ---")
	Progresso._habilidades.erase("mochila")
	await _abrir(MissaoNitrogenio.CENA_TORRE)
	await _segundos(0.8)
	var torre := get_tree().current_scene
	var player := _player()

	# O comentário do degrau alto.
	var aviso := torre.get_node("Andares/Andar0_Terreo/AvisoDegrauAlto") as ReferenceRect
	_pousar(player, Vector2(aviso.global_position.x + aviso.size.x * 0.5, 476))
	await _esperar(func() -> bool: return Dialogic.current_timeline != null, 3.0)
	_checar(Dialogic.current_timeline != null, "sem a mochila, embaixo do degrau a Cacau diz que é alto demais")
	await _encerrar_fala()

	# Sem a mochila: o pulo duplo não chega no degrau.
	await _pular_para_o_degrau(player, false)
	_checar(player.global_position.y > DEGRAU_Y + 40.0,
		"o pulo duplo não chega no primeiro degrau (ela ficou em y = %.0f)" % player.global_position.y)

	# Com a mochila: pulo + jato para cima chega.
	Progresso._habilidades["mochila"] = true
	await _pular_para_o_degrau(player, true)
	_checar(player.is_on_floor() and absf(player.global_position.y - (DEGRAU_Y - 36.0)) < 4.0
			and player.global_position.x > DEGRAU_X,
		"com a mochila, pulo + jato chega no degrau (ela está em %s)" % player.global_position.round())

	# O puzzle do vapor: o ventilador é um alvo do bumerangue.
	var vapor := torre.get_node("Andares/Andar6_FogoEVapor/PuzzleDoVapor/Vapor") as CorrenteVapor
	var ventilador := torre.get_node("Andares/Andar6_FogoEVapor/PuzzleDoVapor/Ventilador") as AlvoBumerangue
	_checar(vapor.ativa, "o vapor do andar 6 começa ligado")
	ventilador.atingir_bumerangue()
	await _quadros(2)
	_checar(not vapor.ativa, "acertar o ventilador desliga o vapor")

	# A caixa elétrica da chaminé de serras.
	var serra := torre.get_node("Andares/Andar2_Serras/SerraPilar1") as EspinhosLaser
	var serra_do_piso := torre.get_node("Andares/Andar2_Serras/SerraDoPiso1") as EspinhosLaser
	var caixa := torre.get_node("Andares/Andar2_Serras/CaixaDasSerras") as AlvoBumerangue
	caixa.atingir_bumerangue()
	await _esperar(func() -> bool: return not serra.perigoso, 4.0)
	_checar(not serra.perigoso, "acertar a caixa recolhe as serras da chaminé")
	_checar(serra_do_piso.perigoso, "   e as do piso continuam (não são dela)")

	# As plataformas laranja viram plataformas que caem.
	var terreno := torre.get_node("Terreno") as TileMapLayer
	_checar(terreno.get_used_cells_by_id(0).is_empty(), "as plataformas laranja saíram do mapa de tiles")
	var quedas := torre.find_children("*", "Node2D", false, false).filter(func(n: Node) -> bool:
		return n is PlataformaQueCai)
	_checar(quedas.size() == 5, "   e viraram as cinco plataformas que caem (%d)" % quedas.size())

	# As janelas: do tamanho das da sala do compressor, e nenhuma atrás de uma
	# placa de andar ou de uma porta.
	var janelas := torre.get_node("Janelas") as TileMapLayer
	var escala := _escala_das_janelas_do_compressor()
	var retangulos := _janelas(janelas)
	_checar(janelas.scale == escala and retangulos.size() == 24,
		"as 24 janelas da torre na escala das do compressor (%s, a do compressor %s)" % [janelas.scale, escala])
	var na_frente: Array[Rect2] = []
	for placa: Label in torre.find_children("Placa", "Label", true, false):
		na_frente.append(placa.get_global_rect())
	for porta in ["Andares/Andar0_Terreo/PortaRua", "Andares/Andar7_Topo/PortaTelhado"]:
		na_frente.append(_retangulo_do_desenho(torre.get_node(porta + "/SpritePorta") as AnimatedSprite2D))
	var atras := retangulos.filter(func(janela: Rect2) -> bool:
		return na_frente.any(func(coisa: Rect2) -> bool: return janela.intersects(coisa)))
	_checar(atras.is_empty(), "   nenhuma atrás das %d placas e portas %s" % [na_frente.size(), atras])


func _testar_salas() -> void:
	print("\n--- AS SALAS ---")
	await _abrir(MissaoNitrogenio.CENA_COMPRESSOR)
	var compressor := get_tree().current_scene
	_checar(compressor.get_node_or_null("CompressorDeAr") != null, "a sala do compressor tem o compressor")
	await _abrir(MissaoNitrogenio.CENA_DESTILACAO)
	var destilacao := get_tree().current_scene
	var mochila := destilacao.get_node_or_null("Mochila") as PickupHabilidade
	_checar(mochila == null or mochila.habilidade == "mochila", "a sala de destilação tem a mochila de N₂ (já pega no teste: some)")
	var coluna := destilacao.get_node_or_null("Destilador")
	var cilindro := destilacao.get_node_or_null("CilindroDeNitrogenio") as CilindroDeNitrogenio
	_checar(coluna != null, "   a coluna de destilação")
	_checar(cilindro != null and cilindro.get_node_or_null(cilindro.destilador) == coluna,
		"   e o cilindro de nitrogênio, ligado à coluna")

	# Por dentro, a sala do compressor tile por tile: as mesmas camadas, com os
	# mesmos tiles nas mesmas posições, e a mesma câmera. Só os objetos são dela.
	var modelo: Node = (load(MissaoNitrogenio.CENA_COMPRESSOR) as PackedScene).instantiate()
	for nome: String in CAMADAS_DA_SALA:
		var dela := destilacao.get_node_or_null(nome) as TileMapLayer
		var do_compressor := modelo.get_node(nome) as TileMapLayer
		var diferentes := _celulas_diferentes(dela, do_compressor)
		_checar(diferentes == 0 and dela.transform == do_compressor.transform,
			"%s da sala de destilação: os tiles da sala do compressor, nas mesmas posições (%d diferentes)"
			% [nome, diferentes])
	var limites := destilacao.get_node("LimitesDaCamera") as ReferenceRect
	var limites_do_compressor := modelo.get_node("LimitesDaCamera") as ReferenceRect
	var area := Rect2(limites.position, limites.size)
	var zoom: float = _player().get("zoom_da_camera")
	var zoom_do_compressor: float = modelo.get_node("Player").get("zoom_da_camera")
	_checar(area == Rect2(limites_do_compressor.position, limites_do_compressor.size)
			and is_equal_approx(zoom, zoom_do_compressor),
		"   e a mesma câmera: limites %s, zoom %s" % [area, zoom])
	modelo.free()

	# Fechada e com chão de concreto: saindo do meio, de pé no chão, o corpo da
	# Cacau para em alguma coisa antes de sair da área da câmera, para qualquer
	# lado (para cima, a laje vazada do meio não segura: quem segura é o teto).
	var no_chao := Transform2D(0.0, Vector2(area.get_center().x, PISO_DA_DESTILACAO - ATE_A_SOLA - 2.0))
	var presa := true
	var paradas := []
	for direcao in [Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
		var colisao := KinematicCollision2D.new()
		var bateu := _player().test_move(no_chao, direcao * 3000.0, colisao)
		var parou := no_chao.origin + colisao.get_travel()
		paradas.append(parou.round())
		presa = presa and bateu and area.grow(ATE_A_SOLA * 2.0).has_point(parou)
	_checar(presa, "   fechada: paredes, teto e chão seguram a Cacau na área da câmera %s" % [paradas])
	var espaco := (destilacao as Node2D).get_world_2d().direct_space_state
	var piso := espaco.intersect_ray(PhysicsRayQueryParameters2D.create(no_chao.origin,
		no_chao.origin + Vector2.DOWN * 200.0, 1, [_player().get_rid()]))
	_checar(not piso.is_empty() and SomPassos.superficie_do_chao(piso.collider, piso.position) == &"concreto",
		"   e o chão soa como concreto")


# ─────────────────────────────────────────────────────────────
# A ARTE DOS PRÉDIOS
# ─────────────────────────────────────────────────────────────

## Quantas células diferem entre duas camadas: tile, fonte ou alternativa
## diferente, ou pintada numa e vazia na outra (-1 se faltar uma camada ou se
## os tilesets não forem os mesmos).
func _celulas_diferentes(a: TileMapLayer, b: TileMapLayer) -> int:
	if a == null or b == null or a.tile_set.resource_path != b.tile_set.resource_path:
		return -1
	var celulas := {}
	for celula in a.get_used_cells() + b.get_used_cells():
		celulas[celula] = true
	var diferentes := 0
	for celula: Vector2i in celulas:
		if a.get_cell_source_id(celula) != b.get_cell_source_id(celula) \
				or a.get_cell_atlas_coords(celula) != b.get_cell_atlas_coords(celula) \
				or a.get_cell_alternative_tile(celula) != b.get_cell_alternative_tile(celula):
			diferentes += 1
	return diferentes


func _escala_das_janelas_do_compressor() -> Vector2:
	var cena: Node = (load(MissaoNitrogenio.CENA_COMPRESSOR) as PackedScene).instantiate()
	var escala := (cena.get_node("Janelas") as Node2D).scale
	cena.free()
	return escala


## Onde fica cada janela da camada, no mundo — vazio se a camada tiver outra
## coisa além de janelas inteiras.
func _janelas(camada: TileMapLayer) -> Array[Rect2]:
	var retangulos: Array[Rect2] = []
	var tile := Vector2(camada.tile_set.tile_size)
	var pedacos := 0
	for celula in camada.get_used_cells():
		var atlas := camada.get_cell_atlas_coords(celula) - JANELA_CANTO
		if atlas.x < 0 or atlas.y < 0 or atlas.x >= JANELA_TAMANHO.x or atlas.y >= JANELA_TAMANHO.y:
			return []
		pedacos += 1
		if atlas == Vector2i.ZERO:
			var canto := camada.to_global(camada.map_to_local(celula) - tile * 0.5)
			retangulos.append(Rect2(canto, tile * Vector2(JANELA_TAMANHO) * camada.global_scale))
	if pedacos != retangulos.size() * JANELA_TAMANHO.x * JANELA_TAMANHO.y:
		return []
	return retangulos


func _retangulo_do_desenho(sprite: AnimatedSprite2D) -> Rect2:
	var tamanho := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_size() * sprite.global_scale
	return Rect2(sprite.global_position + sprite.offset * sprite.global_scale - tamanho * 0.5, tamanho)


# ─────────────────────────────────────────────────────────────
# O PULO DO PRIMEIRO DEGRAU
# ─────────────────────────────────────────────────────────────

## Da esquerda do degrau: pulo; no alto, o segundo pulo (sem a mochila) ou o
## jato para cima (com ela); e anda para a direita até pousar.
func _pular_para_o_degrau(player: CharacterBody2D, com_jato: bool) -> void:
	_pousar(player, Vector2(DEGRAU_X - 40.0, 476))
	await _segundos(0.4)
	Input.action_press("ui_right")
	await _quadros(1)
	Input.action_release("ui_right")
	await _toque("jump")
	if com_jato:
		await _segundos(0.12)
		Input.action_press("ui_up")
		await _toque("dash")
		await _segundos(0.3)
		Input.action_release("ui_up")
	else:
		await _esperar(func() -> bool: return player.velocity.y >= 0.0, 1.5)
		await _toque("jump")
	Input.action_press("ui_right")
	await _esperar(func() -> bool: return player.is_on_floor(), 3.0)
	await _segundos(0.3)
	Input.action_release("ui_right")
	await _segundos(0.2)


## O poço do telhado é o da fachada da rua: no Cenario, os trilhos nas pontas e
## a faixa escura (7/8/7 do Buildings.png) no meio, nas cinco colunas centradas
## na cabine e nas fileiras logo abaixo da laje; no Terreno, o vão sem tijolo
## ali — e a laje inteira por cima, para o chão não ter buraco.
func _poco_embaixo_da_cabine(cena: Node, elevador: ElevadorFase) -> bool:
	var cenario := cena.get_node("Cenario") as TileMapLayer
	var terreno := cena.get_node("Terreno") as TileMapLayer
	var meio := cenario.local_to_map(cenario.to_local(elevador.global_position))
	if not is_equal_approx(cenario.to_global(cenario.map_to_local(meio)).x, elevador.global_position.x):
		return false
	for dx in range(-2, 3):
		if terreno.get_cell_source_id(Vector2i(meio.x + dx, meio.y)) == -1:
			return false
		for y in range(meio.y + 1, meio.y + 4):
			var celula := Vector2i(meio.x + dx, y)
			var atlas := cenario.get_cell_atlas_coords(celula)
			var esperado := 1 if absi(dx) == 2 else (8 if dx == 0 else 7)
			if cenario.get_cell_source_id(celula) != 0 or atlas.x != esperado \
					or terreno.get_cell_source_id(celula) != -1:
				return false
	return true


func _pousar(player: CharacterBody2D, onde: Vector2) -> void:
	player.global_position = onde
	player.velocity = Vector2.ZERO


func _toque(acao: String) -> void:
	Input.action_press(acao)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(acao)


# ─────────────────────────────────────────────────────────────

func _encerrar_fala() -> void:
	for i in 3:
		if Dialogic.current_timeline != null:
			Dialogic.end_timeline()
		await _quadros(5)
	get_tree().paused = false


func _esperar(condicao: Callable, limite: float) -> void:
	var t := 0.0
	while t < limite and not condicao.call():
		await get_tree().process_frame
		t += get_process_delta_time()


func _abrir(caminho: String) -> void:
	get_tree().change_scene_to_file(caminho)
	for i in 600:
		await get_tree().process_frame
		var cena := get_tree().current_scene
		if cena and cena.scene_file_path == caminho and cena.is_node_ready():
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
