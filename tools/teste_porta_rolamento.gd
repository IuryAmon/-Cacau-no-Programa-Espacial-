extends Node

# Teste do portão de rolamento da sala do compressor
# (scenes/fases/componentes/porta_rolamento.tscn), na rua da fase 2:
#
#   godot --headless --fixed-fps 60 --path . res://tools/teste_porta_rolamento.tscn
#
# Casos:
#   * A CENA: a porta da oficina (porta_simulador.gd) com o "porta de rolamento
#     .png": 11 quadros de 146x98 em fila, abrindo 0->10, fechando ao contrário
#     e fechada no quadro 0;
#   * O SOM CASADO COM OS QUADROS, lido do próprio .wav: o de abrir começa do
#     silêncio (o fade-in), nenhum dos dois estoura e os dois acabam em
#     silêncio; o quadro da trava (o último do abrindo) entra no clunk do som
#     de abrir e o da porta fechada (o último do fechando) na batida no chão do
#     som de fechar — na conta e rodando de verdade. Cortou o som de novo? Este
#     caso diz quanto os quadros têm de andar;
#   * O PAINEL: os quatro quadradinhos do painel ao lado acendem verdes um por
#     um enquanto o portão sobe (o último na trava) e voltam ao vermelho no
#     baque do portão fechando;
#   * NA RUA: o prédio escuro do compressor está no lugar do antigo prédio de
#     concreto (que saiu da rua), e o fim da rua voltou a ser terreno vazio; a
#     PortaCompressor é este portão, no vão da fachada, em pé no chão, sem o
#     portão e o painel pintados por baixo;
#   * A VIAGEM: rua -> sala do compressor -> rua. Na volta o portão abre, a
#     Cacau sai andando para a direita (o lado da destilação) e ele fecha
#     atrás dela;
#   * A SALA POR DENTRO: a mesma arte de fora (o Buildings.png) na estrutura e
#     na parede, nada do laboratório; a sala é fechada (chão, teto e paredes
#     com colisão), o chão soa como concreto e a porta é o mesmo portão.

const CENA_PORTA := "res://scenes/fases/componentes/porta_rolamento.tscn"
const FOLHA := "res://assets/fase nitrogenio/porta de rolamento .png"
const SCRIPT_PORTA := "res://scripts/porta_simulador.gd"
const SOM_ABRIR := "res://sounds/porta_rolamento_abrindo.wav"
const SOM_FECHAR := "res://sounds/porta_rolamento_fechando.wav"
const QUADROS := 11
const QUADRO := Vector2(146, 98)
const RUA := MissaoNitrogenio.CENA_RUA

## Onde começar a procurar o clunk em cada som (s): no de abrir, depois que o
## rolo morre; no de fechar, depois da emenda do rolo com a batida.
const PROCURA_CLUNK_ABRIR := 1.3
const PROCURA_BATIDA_FECHAR := 0.715
## Um clunk é o primeiro pico acima disto.
const LIMIAR_CLUNK_DB := -10.0
## Quanto o quadro pode errar o clunk: um quadro de jogo a 60 fps.
const TOLERANCIA := 1.0 / 60.0

## O vão do portão na fachada do prédio do compressor (colunas e fileiras do
## Cenario 2) e o portão de garagem pintado do Buildings.png, que não pode
## estar mais lá por baixo da porta.
const GARAGEM_COLUNAS := Vector2i(12, 19)
const GARAGEM_FILEIRAS := Vector2i(11, 15)
const GARAGEM_ATLAS := Rect2i(15, 0, 5, 3)
## O prédio do compressor na rua (colunas, sem o cano e a caçamba) e o
## terreno vazio do fim da rua, de onde ele saiu.
const PREDIO_COLUNAS := Vector2i(6, 26)
const TERRENO_VAZIO := Vector2i(122, 169)
## A parede verde do prédio e a de concreto do prédio antigo (Buildings.png).
const PAREDE_VERDE := Vector2i(8, 1)
const PAREDE_DE_CONCRETO := Rect2i(5, 1, 2, 3)
## O painel de luzes, que agora mora na cena do portão.
const PAINEL_PINTADO := Vector2i(11, 6)
## Do centro da cápsula da Cacau até a sola.
const ATE_A_SOLA := 36.0
## A fonte do Buildings.png no tileset_fases.
const FONTE_PREDIOS := 15
## O piso da sala por dentro (é nele que o portão põe a Cacau).
const PISO_DA_SALA := 512.0

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
	_testar_cena()
	await _testar_som()
	_testar_painel()
	await _testar_rua()
	await _testar_viagem()
	await _testar_sala()
	MissaoNitrogenio.esquecer()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


# ─────────────────────────────────────────────────────────────

func _testar_cena() -> void:
	print("\n--- A CENA ---")
	var porta := (load(CENA_PORTA) as PackedScene).instantiate()
	_checar(porta.get_script() == load(SCRIPT_PORTA), "usa o script das portas da oficina (porta_simulador.gd)")
	var quadros := (porta.get_node("SpritePorta") as AnimatedSprite2D).sprite_frames
	_checar(quadros.get_frame_count(&"abrindo") == QUADROS and quadros.get_frame_count(&"fechando") == QUADROS,
		"abrindo e fechando com %d quadros" % QUADROS)
	var em_ordem := true
	for i in QUADROS:
		var q := quadros.get_frame_texture(&"abrindo", i) as AtlasTexture
		var volta := quadros.get_frame_texture(&"fechando", QUADROS - 1 - i) as AtlasTexture
		em_ordem = em_ordem and q.atlas.resource_path == FOLHA \
			and q.region == Rect2(Vector2(QUADRO.x * i, 0), QUADRO) and volta.region == q.region
	_checar(em_ordem, "os quadros saem da folha, 146x98 em fila, e o fechando é o abrindo ao contrário")
	var fechada := quadros.get_frame_texture(&"fechada", 0) as AtlasTexture
	_checar(quadros.get_frame_count(&"fechada") == 1 and fechada.region.position == Vector2.ZERO,
		"fechada é o quadro 0")
	var textura := load(FOLHA) as Texture2D
	_checar(textura.get_size() == Vector2(QUADRO.x * QUADROS, QUADRO.y),
		"a folha tem %d quadros de 146x98 (%s)" % [QUADROS, textura.get_size()])
	_checar(not quadros.get_animation_loop(&"abrindo") and not quadros.get_animation_loop(&"fechando"),
		"abrindo e fechando tocam uma vez só")
	var painel := porta.get_node_or_null("Painel") as Sprite2D
	var recorte := Rect2(Vector2(PAINEL_PINTADO * 16), Vector2(16, 16))
	_checar(painel != null and (painel.texture as AtlasTexture).region == recorte and painel.get_child_count() == 4,
		"ao lado, o painel de quatro luzes (tile 11,6 do Buildings.png)")
	porta.free()


func _testar_som() -> void:
	print("\n--- O SOM CASADO COM OS QUADROS ---")
	var porta := (load(CENA_PORTA) as PackedScene).instantiate()
	var sprite := porta.get_node("SpritePorta") as AnimatedSprite2D
	var quadros := sprite.sprite_frames
	_checar((porta.get_node("SomAbrindo") as AudioStreamPlayer2D).stream.resource_path == SOM_ABRIR
		and (porta.get_node("SomFechando") as AudioStreamPlayer2D).stream.resource_path == SOM_FECHAR,
		"abre e fecha com os sons do portão")
	_checar(is_zero_approx(porta.inicio_som_fechando), "o som de fechar toca do começo (já vem cortado)")

	var abrir := _ler_wav(SOM_ABRIR)
	var fechar := _ler_wav(SOM_FECHAR)
	_checar(abrir.taxa == 44100 and fechar.taxa == 44100, "os dois .wav são mono, 16 bits, 44,1 kHz")
	var a: PackedFloat32Array = abrir.amostras
	var f: PackedFloat32Array = fechar.amostras
	var inicio := _rms(a, 0.0, 0.02)
	var cheio := _rms(a, 0.15, 0.25)
	_checar(inicio < cheio * 0.25, "o de abrir começa do silêncio, no fade-in (%.1f dB abaixo do rolo)"
		% (20.0 * log(cheio / maxf(inicio, 0.000001)) / log(10.0)))
	var pico := maxf(_pico(a, 0.0, 99.0), _pico(f, 0.0, 99.0))
	_checar(pico <= 0.81, "nenhum dos dois estoura (pico em %.1f dBFS)" % (20.0 * log(pico) / log(10.0)))
	_checar(_pico(a, abrir.duracao - 0.01, 99.0) < 0.004 and _pico(f, fechar.duracao - 0.01, 99.0) < 0.004,
		"os dois acabam em silêncio")

	var clunk := _primeiro_pico(a, PROCURA_CLUNK_ABRIR)
	var trava := _inicio_do_quadro(quadros, &"abrindo", QUADROS - 1)
	_checar(absf(trava - clunk) <= TOLERANCIA,
		"o quadro da trava entra no clunk (quadro em %.3f s, clunk em %.3f s)" % [trava, clunk])
	var batida := _primeiro_pico(f, PROCURA_BATIDA_FECHAR)
	var no_chao := _inicio_do_quadro(quadros, &"fechando", QUADROS - 1)
	_checar(absf(no_chao - batida) <= TOLERANCIA,
		"o quadro da porta fechada entra na batida no chão (quadro em %.3f s, batida em %.3f s)"
		% [no_chao, batida])
	var fim_abrir := _inicio_do_quadro(quadros, &"abrindo", QUADROS)
	_checar(fim_abrir > clunk and fim_abrir < abrir.duracao,
		"a Cacau entra logo depois do clunk (%.2f s), com o resto do som tocando" % fim_abrir)

	# Rodando de verdade (a 60 fps fixos): os quadros trocam na hora da conta.
	# A porta procura a Cacau ao entrar na árvore; uma substituta basta.
	var substituta := Node2D.new()
	substituta.add_to_group("player")
	add_child(substituta)
	add_child(porta)
	var painel := porta.get_node("Painel")
	var trava_rodando := await _quando_mostra(sprite, &"abrindo", QUADROS - 1)
	_checar(absf(trava_rodando - clunk) <= 2.0 * TOLERANCIA,
		"rodando, a trava aparece em %.3f s, com o painel todo verde (%d de 4)"
		% [trava_rodando, painel.acesas()])
	await sprite.animation_finished
	var chao_rodando := await _quando_mostra(sprite, &"fechando", QUADROS - 1)
	_checar(absf(chao_rodando - batida) <= 2.0 * TOLERANCIA and painel.acesas() == 0,
		"rodando, a porta fecha em %.3f s e o painel volta ao vermelho" % chao_rodando)
	porta.queue_free()
	substituta.queue_free()
	await get_tree().process_frame


func _testar_painel() -> void:
	print("\n--- O PAINEL ---")
	var porta := (load(CENA_PORTA) as PackedScene).instantiate()
	var substituta := Node2D.new()
	substituta.add_to_group("player")
	add_child(substituta)
	add_child(porta)
	var sprite := porta.get_node("SpritePorta") as AnimatedSprite2D
	var painel := porta.get_node("Painel")
	_checar(painel.acesas() == 0, "com o portão fechado, as quatro luzes estão vermelhas")
	# Quadro a quadro: quantas verdes em cada quadro do abrindo.
	sprite.play(&"abrindo")
	var por_quadro := PackedInt32Array()
	for i in QUADROS:
		sprite.frame = i
		por_quadro.append(painel.acesas())
	sprite.pause()
	var crescendo := true
	for i in range(1, QUADROS):
		crescendo = crescendo and por_quadro[i] >= por_quadro[i - 1]
	_checar(por_quadro[0] == 1 and crescendo and por_quadro[QUADROS - 1] == 4 and por_quadro[QUADROS - 2] == 3,
		"subindo, acendem uma por uma, a última na trava %s" % [por_quadro])
	sprite.play(&"fechando")
	sprite.frame = QUADROS - 2
	var descendo: int = painel.acesas()
	sprite.frame = QUADROS - 1
	_checar(descendo == 4 and painel.acesas() == 0,
		"descendo, ficam verdes até o baque, e aí voltam ao vermelho")
	sprite.play(&"fechada")
	_checar(painel.acesas() == 0, "fechada, vermelhas")
	porta.queue_free()
	substituta.queue_free()


func _testar_rua() -> void:
	print("\n--- NA RUA ---")
	await _abrir(RUA)
	var cena := get_tree().current_scene
	var porta := cena.get_node_or_null("PortaCompressor") as Area2D
	_checar(porta != null and porta.scene_file_path == CENA_PORTA, "a PortaCompressor é o portão de rolamento")
	if porta == null:
		return
	_checar(porta.cena_destino == MissaoNitrogenio.CENA_COMPRESSOR and porta.tag_destino == "compressor",
		"leva à sala do compressor")
	_checar(porta.recebe_chegada and porta.tag_aqui == "porta_compressor" and porta.direcao_saida > 0.0,
		"recebe quem volta de lá, que sai andando para a direita (a destilação)")

	# O prédio do compressor no lugar do antigo, e o fim da rua vazio de novo.
	var predios := cena.get_node("Cenario") as TileMapLayer
	var cenario := cena.get_node("Cenario/Cenario 2") as TileMapLayer
	var parede_verde := 0
	var concreto := 0
	for x in range(PREDIO_COLUNAS.x, PREDIO_COLUNAS.y + 1):
		for y in range(GARAGEM_FILEIRAS.x, GARAGEM_FILEIRAS.y + 1):
			var atlas := predios.get_cell_atlas_coords(Vector2i(x, y))
			parede_verde += 1 if atlas == PAREDE_VERDE else 0
			concreto += 1 if PAREDE_DE_CONCRETO.has_point(atlas) else 0
	_checar(parede_verde > 0 and concreto == 0,
		"o prédio escuro está no lugar do antigo prédio de concreto (%d tiles da parede verde, %d de concreto)"
		% [parede_verde, concreto])
	var no_fim := 0
	for camada: TileMapLayer in [predios, cenario]:
		for celula in camada.get_used_cells():
			if celula.x >= TERRENO_VAZIO.x and celula.x <= TERRENO_VAZIO.y:
				no_fim += 1
	_checar(no_fim == 0, "o fim da rua voltou a ser terreno vazio (%d tiles lá)" % no_fim)

	var largura := float(cenario.tile_set.tile_size.x) * cenario.global_scale.x
	var meio := (GARAGEM_COLUNAS.x + GARAGEM_COLUNAS.y + 1) * 0.5 * largura
	_checar(absf(porta.global_position.x - meio) < 1.0,
		"o portão está no vão da fachada (x = %.0f, vão em %.0f)" % [porta.global_position.x, meio])
	var sobrou := 0
	for x in range(GARAGEM_COLUNAS.x, GARAGEM_COLUNAS.y + 1):
		for y in range(GARAGEM_FILEIRAS.x, GARAGEM_FILEIRAS.y + 1):
			if cenario.get_cell_source_id(Vector2i(x, y)) == 0 \
					and GARAGEM_ATLAS.has_point(cenario.get_cell_atlas_coords(Vector2i(x, y))):
				sobrou += 1
	var paineis_pintados := 0
	for celula in cenario.get_used_cells():
		if cenario.get_cell_source_id(celula) == 0 and cenario.get_cell_atlas_coords(celula) == PAINEL_PINTADO:
			paineis_pintados += 1
	_checar(sobrou == 0 and paineis_pintados == 0,
		"sem o portão nem o painel pintados por baixo (%d e %d tiles)" % [sobrou, paineis_pintados])

	var sola := (porta.get_node("PontoDeSaida") as Marker2D).global_position.y + ATE_A_SOLA
	var chao := _chao_abaixo(cena, porta.global_position)
	_checar(absf(sola - chao) <= 1.0, "a Cacau sai em pé no chão (sola em %.0f, chão em %.0f)" % [sola, chao])
	# A folha tem 1 px transparente em volta do desenho.
	var sprite := porta.get_node("SpritePorta") as AnimatedSprite2D
	var pe_do_desenho := sprite.global_position.y + (QUADRO.y * 0.5 - 1.0) * sprite.global_scale.y
	_checar(absf(pe_do_desenho - chao) <= 1.0,
		"o portão está em pé no chão (pé do desenho em %.1f, chão em %.0f)" % [pe_do_desenho, chao])

	var no_predio := _portas(cena).filter(func(p: Node) -> bool:
		var x := (p as Node2D).global_position.x
		return x >= PREDIO_COLUNAS.x * largura and x <= (PREDIO_COLUNAS.y + 1) * largura)
	_checar(no_predio == [porta], "o portão é a única porta do prédio")


func _testar_viagem() -> void:
	print("
--- RUA -> SALA DO COMPRESSOR -> RUA ---")
	await _abrir(RUA)
	var porta := get_tree().current_scene.get_node("PortaCompressor")
	var sprite := porta.get_node("SpritePorta") as AnimatedSprite2D
	_usar(porta)
	# Na ida o portão não fecha: abre, ela entra e a tela apaga com ele aberto.
	var abriu := false
	var fechou_depois := false
	for i in 600:
		await get_tree().process_frame
		if not is_instance_valid(sprite):
			break
		abriu = abriu or sprite.animation == &"abrindo"
		fechou_depois = fechou_depois or (abriu and sprite.animation == &"fechando")
	_checar(abriu and not fechou_depois, "o portão abre, ela entra e a cena troca com ele aberto")
	await _esperar_cena(MissaoNitrogenio.CENA_COMPRESSOR)
	var porta_da_sala := get_tree().current_scene.get_node("PortaRua")
	var chegada := await _esperar_chegada_aberta(porta_da_sala)
	_checar(chegada[0] and chegada[1], "na sala, o portão já está aberto, ela sai e ele fecha atrás dela")
	_checar(_player().visible and _player().pode_se_mover, "chegou na sala do compressor pela porta da rua")

	_usar(porta_da_sala)
	await _esperar_cena(RUA)
	porta = get_tree().current_scene.get_node("PortaCompressor")
	var chegada_na_volta := await _esperar_chegada_aberta(porta)
	var player := _player()
	var saida := (porta.get_node("PontoDeSaida") as Marker2D).global_position
	var esperado := saida + Vector2(porta.direcao_saida * porta.distancia_saida, 0.0)
	_checar(chegada_na_volta[0] and chegada_na_volta[1] and player.visible and player.pode_se_mover,
		"de volta à rua: o portão já está aberto, ela aparece, anda e ele fecha atrás dela")
	_checar(player.global_position.distance_to(esperado) < 8.0 and esperado.x > saida.x,
		"   saiu andando para a direita (%s, esperado %s)" % [player.global_position.round(), esperado.round()])


func _testar_sala() -> void:
	print("\n--- A SALA POR DENTRO ---")
	await _abrir(MissaoNitrogenio.CENA_COMPRESSOR)
	var cena := get_tree().current_scene
	var porta := cena.get_node("PortaRua") as Area2D
	_checar(porta.scene_file_path == CENA_PORTA and porta.tag_aqui == "compressor"
		and porta.tag_destino == "porta_compressor", "a porta da sala é o mesmo portão, par da PortaCompressor")
	var terreno := cena.get_node("Terreno") as TileMapLayer
	var fundo := cena.get_node("Fundo") as TileMapLayer
	var fontes := {}
	for camada: TileMapLayer in [terreno, fundo]:
		for celula in camada.get_used_cells():
			fontes[camada.get_cell_source_id(celula)] = true
	_checar(fontes.keys() == [FONTE_PREDIOS],
		"a estrutura e a parede são do Buildings.png, a arte de fora (fontes %s)" % [fontes.keys()])
	var verde := 0
	for celula in fundo.get_used_cells():
		verde += 1 if fundo.get_cell_atlas_coords(celula) == PAREDE_VERDE else 0
	_checar(verde * 2 > fundo.get_used_cells().size(),
		"a parede do fundo é a parede verde do prédio (%d de %d tiles)" % [verde, fundo.get_used_cells().size()])
	var do_laboratorio := 0
	var cenario := cena.get_node("Cenario") as TileMapLayer
	for celula in cenario.get_used_cells():
		# A fonte 3 do tileset da cidade é o decor do laboratório.
		do_laboratorio += 1 if cenario.get_cell_source_id(celula) == 3 else 0
	_checar(do_laboratorio == 0, "nada do decor do laboratório nos enfeites")

	# Fechada: saindo do meio da sala, de pé no chão, o corpo da Cacau para em
	# alguma coisa — parede, teto, chão — antes de sair da área da câmera, para
	# qualquer lado. É o corpo, e não um raio, porque ele sabe que a laje vazada
	# do meio não segura o pulo: para cima, quem segura é o teto.
	var limites := cena.get_node("LimitesDaCamera") as ReferenceRect
	var area := Rect2(limites.position, limites.size)
	var no_chao := Transform2D(0.0, Vector2(area.get_center().x, PISO_DA_SALA - ATE_A_SOLA - 2.0))
	var presa := true
	var paradas := []
	for direcao in [Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
		var colisao := KinematicCollision2D.new()
		var bateu := _player().test_move(no_chao, direcao * 3000.0, colisao)
		var parou := no_chao.origin + colisao.get_travel()
		paradas.append(parou.round())
		presa = presa and bateu and area.grow(ATE_A_SOLA * 2.0).has_point(parou)
	_checar(presa, "a sala é fechada: paredes, teto e chão seguram a Cacau na área da câmera %s" % [paradas])
	var espaco := (cena as Node2D).get_world_2d().direct_space_state
	var meio := no_chao.origin
	var piso := espaco.intersect_ray(PhysicsRayQueryParameters2D.create(meio, meio + Vector2.DOWN * 200.0, 1,
		[_player().get_rid()]))
	_checar(not piso.is_empty() and SomPassos.superficie_do_chao(piso.collider, piso.position) == &"concreto",
		"o chão soa como concreto")
	var sola := (porta.get_node("PontoDeSaida") as Marker2D).global_position.y + ATE_A_SOLA
	_checar(absf(sola - PISO_DA_SALA) <= 1.0, "a Cacau sai do portão em pé no chão (sola em %.0f)" % sola)


# ─────────────────────────────────────────────────────────────

## Lê um .wav PCM de 16 bits mono direto do arquivo de origem.
func _ler_wav(caminho: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(caminho)
	var resultado := {"taxa": 0, "amostras": PackedFloat32Array(), "duracao": 0.0}
	var i := 12
	var formato_ok := false
	while i + 8 <= bytes.size():
		var id := bytes.slice(i, i + 4).get_string_from_ascii()
		var tamanho := bytes.decode_u32(i + 4)
		if id == "fmt ":
			formato_ok = bytes.decode_u16(i + 8) == 1 and bytes.decode_u16(i + 10) == 1 \
				and bytes.decode_u16(i + 22) == 16
			resultado.taxa = bytes.decode_u32(i + 12) if formato_ok else 0
		elif id == "data" and formato_ok:
			var amostras := PackedFloat32Array()
			amostras.resize(tamanho / 2)
			for k in amostras.size():
				amostras[k] = bytes.decode_s16(i + 8 + k * 2) / 32768.0
			resultado.amostras = amostras
			resultado.duracao = float(amostras.size()) / resultado.taxa
			break
		i += 8 + tamanho + (tamanho & 1)
	return resultado


func _rms(amostras: PackedFloat32Array, de: float, ate: float) -> float:
	var soma := 0.0
	var a := int(de * 44100.0)
	var b := mini(int(ate * 44100.0), amostras.size())
	for k in range(a, b):
		soma += amostras[k] * amostras[k]
	return sqrt(soma / maxi(b - a, 1))


func _pico(amostras: PackedFloat32Array, de: float, ate: float) -> float:
	var pico := 0.0
	for k in range(maxi(int(de * 44100.0), 0), mini(int(ate * 44100.0), amostras.size())):
		pico = maxf(pico, absf(amostras[k]))
	return pico


## O primeiro pico acima do limiar do clunk, a partir de "de" (s).
func _primeiro_pico(amostras: PackedFloat32Array, de: float) -> float:
	var limiar := pow(10.0, LIMIAR_CLUNK_DB / 20.0)
	for k in range(int(de * 44100.0), amostras.size()):
		if absf(amostras[k]) > limiar:
			return k / 44100.0
	return INF


## Em que segundo o quadro "indice" da animação começa (indice = total: o fim).
func _inicio_do_quadro(quadros: SpriteFrames, animacao: StringName, indice: int) -> float:
	var t := 0.0
	for i in indice:
		t += quadros.get_frame_duration(animacao, i)
	return t / quadros.get_animation_speed(animacao)


## Toca a animação e conta quanto tempo de jogo leva até o quadro aparecer.
func _quando_mostra(sprite: AnimatedSprite2D, animacao: StringName, indice: int) -> float:
	sprite.play(animacao)
	var t := 0.0
	while sprite.frame != indice and t < 5.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	return t


## Portas desta cena (porta_simulador.gd).
func _portas(cena: Node) -> Array:
	var script_porta := load(SCRIPT_PORTA)
	return cena.find_children("*", "Area2D", true, false).filter(func(n: Node) -> bool:
		return n.get_script() == script_porta)


func _chao_abaixo(cena: Node, ponto: Vector2) -> float:
	var espaco := (cena as Node2D).get_world_2d().direct_space_state
	var raio := PhysicsRayQueryParameters2D.create(ponto, ponto + Vector2(0, 400), 1)
	var achou := espaco.intersect_ray(raio)
	return (achou.position as Vector2).y if not achou.is_empty() else INF


## A Cacau, parada um pouco ao lado do vão, aperta para cima.
func _usar(porta: Node) -> void:
	var player := _player()
	player.global_position = (porta.get_node("PontoDeSaida") as Marker2D).global_position + Vector2(60, -2)
	player.velocity = Vector2.ZERO
	porta._player = player
	porta._player_dentro = true
	porta._usar_porta()


## Espera a sequência de chegada da porta acabar. Devolve se ela abriu.
## Espera a chegada por uma porta que veio aberta da outra cena. Devolve
## [ela já estava aberta no primeiro quadro, terminou fechada sem reabrir].
func _esperar_chegada_aberta(porta: Node) -> Array:
	var sprite := porta.get_node("SpritePorta") as AnimatedSprite2D
	var ultimo := sprite.sprite_frames.get_frame_count(&"abrindo") - 1
	var comecou_aberta := sprite.animation == &"abrindo" and sprite.frame == ultimo
	var reabriu := false
	var fechou := false
	for i in 600:
		await get_tree().process_frame
		fechou = fechou or sprite.animation == &"fechando"
		reabriu = reabriu or (sprite.animation == &"abrindo" and sprite.frame < ultimo)
		if fechou and not porta._ocupada:
			break
	return [comecou_aberta, fechou and not reabriu and sprite.animation == &"fechada"]


func _esperar_cena(caminho: String) -> void:
	for i in 900:
		if get_tree().current_scene and get_tree().current_scene.scene_file_path == caminho:
			await _quadros(2)
			return
		await get_tree().process_frame
	_checar(false, "a cena %s não abriu" % caminho.get_file())


func _abrir(caminho: String) -> void:
	get_tree().change_scene_to_file(caminho)
	await _quadros(3)


func _player() -> CharacterBody2D:
	return get_tree().current_scene.get_node("Player") as CharacterBody2D


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1
