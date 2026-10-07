extends Node

# Teste automático de fumaça das fases: carrega cada cena, confere que os nós
# esperados existem e simula o essencial (arremesso do bumerangue, corte da
# chapa, dosagem) para garantir que a fiação continua de pé depois de mexer
# nas cenas no editor.
#
#   godot --headless --path . res://tools/teste_fases.tscn

var _falhas := 0


func _ready() -> void:
	await _testar_fase1()
	await _testar_fase1_2()
	await _testar_fase2()
	await _testar_dash()
	await _testar_fase3()
	await _testar_final()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok   " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


func _abrir(caminho: String) -> Node:
	var cena: PackedScene = load(caminho)
	var raiz := cena.instantiate()
	# call_deferred: no primeiro _ready() a raiz da árvore ainda está montando
	# os filhos e um add_child() direto é recusado.
	get_tree().root.add_child.call_deferred(raiz)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	return raiz


func _fechar(raiz: Node) -> void:
	raiz.queue_free()
	await get_tree().process_frame


func _testar_fase1() -> void:
	print("\n--- FASE 1: OFICINA DO CARBONO ---")
	var f := await _abrir("res://scenes/fases/fase1_oficina.tscn")

	var player := f.get_node_or_null("Player")
	_checar(player != null, "player na cena")
	_checar(player.get_node_or_null("Ferramentas") != null, "componente de ferramentas instalado")

	# A grade dupla saiu do mapa no editor; o teste dela só roda se ela voltar.
	var grade := f.get_node_or_null("Corredores/GradeDupla")
	if grade:
		_checar(grade.solido, "grade dupla comeca fechada")

	# O treino (escola do arremesso) fica agora por conta do editor — só a
	# caixa elétrica de placeholder continua de pé.
	_checar(f.get_node_or_null("Treino/AlvoFixo1") != null, "caixa eletrica de treino na cena")

	# Bumerangue no domo de vidro, igual ao maçarico: chegar perto e apertar E
	# abre o puzzle do carbono, e resolver o puzzle abre o domo.
	var gaiola_bumerangue := f.get_node_or_null("Entrada/GaiolaBumerangue")
	var pickup_bumerangue := f.get_node_or_null("Entrada/PickupBumerangue")
	_checar(gaiola_bumerangue != null, "gaiola do bumerangue na entrada")
	_checar(pickup_bumerangue != null, "pickup do bumerangue na entrada")
	if gaiola_bumerangue and pickup_bumerangue:
		_checar(gaiola_bumerangue.puzzle_cena != null \
			and gaiola_bumerangue.puzzle_cena.resource_path == "res://scenes/puzzle_carbono.tscn",
			"gaiola do bumerangue abre o puzzle do carbono")
		_checar(not pickup_bumerangue.monitoring, "bumerangue comeca trancado na gaiola")
		gaiola_bumerangue._on_zona_deteccao_body_entered(player)
		Input.action_press("interact")
		await get_tree().process_frame
		Input.action_release("interact")
		await get_tree().process_frame
		var puzzle_bumerangue: CanvasLayer = gaiola_bumerangue.puzzle_ui
		_checar(puzzle_bumerangue.visible and not gaiola_bumerangue.puzzle_concluido,
			"E abriu o puzzle, e a gaiola continua fechada")
		puzzle_bumerangue.fechar_puzzle(true)
		_checar(gaiola_bumerangue.puzzle_concluido, "puzzle resolvido abriu a gaiola")
		# A animação "abrindo" da gaiola de vidro (12 quadros a 10 fps, 1.2s)
		# precisa terminar antes do pickup destravar — dá a folga pra isso.
		await get_tree().create_timer(2.2).timeout
		await get_tree().process_frame
		_checar(pickup_bumerangue.monitoring, "bumerangue liberado para coleta depois da gaiola abrir")

	# Alvo duplo: os dois acesos ao mesmo tempo abrem a grade.
	if grade:
		f.get_node("Corredores/AlvoDuploA").atingir_bumerangue()
		f.get_node("Corredores/AlvoDuploB").atingir_bumerangue()
		await get_tree().process_frame
		await get_tree().process_frame
		_checar(not grade.solido, "alvo duplo abriu a grade")

	# A carbonização mudou de endereço: a fornalha e a lenha moraram no pátio
	# desta fase até virarem a fase1.2, lá em cima, do outro lado do elevador.
	_checar(f.get_node_or_null("Patio/Retorta") == null, "fornalha nao esta mais na oficina")
	var elevador := f.get_node_or_null("Entrada/ElevadorPatio")
	_checar(elevador != null, "elevador de carga na entrada")
	if elevador:
		_checar(elevador.cena_destino == "res://scenes/fases/fase1_2_exterior.tscn",
			"o elevador leva para o patio (fase1.2)")

	await _fechar(f)


func _testar_fase1_2() -> void:
	print("\n--- FASE 1.2: PATIO DA OFICINA (tela unica) ---")
	var f := await _abrir("res://scenes/fases/fase1_2_exterior.tscn")

	_checar(f.get_node_or_null("Player") != null, "player na cena")
	_checar(f.get_node_or_null("Patio/Retorta") != null, "fornalha mudou para o patio")
	var arvore: ArvoreLenha = f.get_node_or_null("Patio/ArvoreLenha")
	_checar(arvore != null and arvore.toras_na_copa() == 3,
		"as tres toras estao na copa da arvore (caem no bumerangue)")
	_checar(f.get_node_or_null("Elevador") != null, "elevador de volta para a oficina")

	# A câmera parada é o LimitesDaCamera do tamanho de um quadro; a mecânica
	# miúda do elevador tem teste próprio (tools/teste_elevador.tscn).
	var camera: Camera2D = f.get_node("Player/Camera2D")
	_checar(camera.limit_right - camera.limit_left <= ceili(1600.0 / camera.zoom.x) + 1,
		"camera travada em uma tela so")

	await _fechar(f)


## A fase do nitrogênio está em branco, sendo refeita do zero: só o palco (o
## céu e o chão da área aberta) e o que faz a cena abrir e a Cacau entrar e
## sair. Quando a fase nova ganhar objetos, os testes deles entram aqui.
func _testar_fase2() -> void:
	print("\n--- FASE 2: NITROGENIO (em branco) ---")
	var f := await _abrir("res://scenes/fases/fase2_torre.tscn")

	# Nada da antiga Torre de Gases ficou.
	var sobras := PackedStringArray()
	for nome in ["Fundo", "Secoes", "Base", "Subida1", "Subida2", "Tubulacoes", "Estufa"]:
		if f.get_node_or_null(nome) != null:
			sobras.append(nome)
	_checar(sobras.is_empty(), "nada da antiga Torre sobrou na cena %s" % [sobras])
	# A fase está sendo montada no editor, então o que mora nela muda de um dia
	# para o outro — o que não pode faltar é o que a faz abrir e funcionar.
	var faltando := PackedStringArray()
	for nome in ["Atmosfera", "BG", "LimitesDaCamera", "Paredes", "Player", "PortaHub",
			"PostesDeLuz", "SpawnPadrao", "Terreno"]:
		if f.get_node_or_null(nome) == null:
			faltando.append(nome)
	_checar(faltando.is_empty(), "o palco e o que faz a cena funcionar estao la %s" % [faltando])

	# O fundo: o céu de camadas da área aberta, o mesmo do pátio da fase 1.2 —
	# as mesmas quatro camadas de arte, na mesma ordem e no mesmo lugar. (O céu,
	# a lua e as nuvens são do sistema de luz: quem confere é o teste_atmosfera.)
	var bg := f.get_node_or_null("BG") as ParallaxBackground
	_checar(bg != null, "o fundo e o ceu de camadas (ParallaxBackground)")
	if bg != null:
		var patio: Node = (load("res://scenes/fases/fase1_2_exterior.tscn") as PackedScene).instantiate()
		var iguais := true
		var camadas := PackedStringArray()
		for nome in ["Serra", "Morros", "MataDistante", "Mata"]:
			camadas.append(nome)
			var camada := patio.get_node("BG").get_node_or_null(nome)
			var aqui := bg.get_node_or_null(nome)
			if camada == null or aqui == null or aqui.get_child_count() != camada.get_child_count():
				iguais = false
				continue
			for i in camada.get_child_count():
				var a := camada.get_child(i) as Sprite2D
				var b := aqui.get_child(i) as Sprite2D
				if (a.texture.resource_path != b.texture.resource_path or a.position != b.position
						or a.scale != b.scale or a.region_rect != b.region_rect
						or (a.material == null) != (b.material == null)):
					iguais = false
		var ordem_do_patio: Array = patio.get_node("BG").get_children().map(
			func(n: Node) -> String: return str(n.name))
		var ordem_daqui: Array = bg.get_children().map(func(n: Node) -> String: return str(n.name))
		patio.free()
		_checar(iguais, "com as mesmas camadas e a mesma arte do patio %s" % [camadas])
		_checar(ordem_daqui == ordem_do_patio, "e o fundo empilhado na mesma ordem %s" % [ordem_daqui])
		var anda := true
		for nome in ["Serra", "Morros", "MataDistante", "Mata"]:
			var camada := bg.get_node(nome) as ParallaxLayer
			if (camada.motion_scale.x <= 0.0 or camada.motion_scale.y != 0.0
					or camada.motion_mirroring != Vector2(4096, 0)):
				anda = false
		_checar(anda and (bg.get_node("Ceu") as ParallaxLayer).motion_scale == Vector2.ZERO,
			"as matas e os morros andam com a camera (so na horizontal) e se repetem; o ceu fica parado")

	# O chão: a grama da área aberta, reta, de ponta a ponta.
	var terreno := f.get_node("Terreno") as TileMapLayer
	var limites := f.get_node("LimitesDaCamera") as ReferenceRect
	var fonte := terreno.tile_set.get_source(3) as TileSetAtlasSource
	var so_grama := true
	var topo := 999999
	for celula in terreno.get_used_cells():
		if terreno.get_cell_source_id(celula) != 3:
			so_grama = false
		topo = mini(topo, celula.y)
	_checar(so_grama and fonte.texture.resource_path.ends_with("Area Aberta/GandalfHardcore Background layers/Floor Tiles1.png"),
		"o chao e so a grama da area aberta")
	var passo := float(terreno.tile_set.tile_size.x) * terreno.scale.x
	var furos := 0
	for x in range(int(limites.position.x / passo) - 1, int((limites.position.x + limites.size.x) / passo) + 1):
		if terreno.get_cell_source_id(Vector2i(x, topo)) != 3:
			furos += 1
	_checar(furos == 0 and limites.size.x >= 3000.0,
		"reto e sem furo por toda a largura da fase (%d px)" % limites.size.x)

	# A Cacau nasce em pé no chão e não sai do mapa pelas pontas.
	var player: CharacterBody2D = f.get_node("Player")
	get_tree().paused = false
	for i in 30:
		await get_tree().physics_frame
	_checar(player.is_on_floor() and absf(player.global_position.y + 36.0 - topo * passo) < 6.0,
		"a Cacau nasce em pe na grama (pe em %.0f, chao em %.0f)" % [player.global_position.y + 36.0, topo * passo])
	var paredes := f.get_node("Paredes")
	_checar(paredes.get_node("ParedeEsquerda").position.x < limites.position.x
		and paredes.get_node("ParedeDireita").position.x > limites.position.x + limites.size.x,
		"com uma parede invisivel em cada ponta, fora do quadro")

	# A porta continua sendo a chegada da fase; a volta agora passa pelo
	# corredor da torre (ela dá no fundo dele) antes do laboratório.
	var porta := f.get_node("PortaHub")
	_checar(porta.cena_destino == "res://scenes/fases/corredor_torre.tscn" and porta.tag_destino == "fundo"
		and porta.recebe_chegada and porta.tag_aqui == "entrada",
		"a porta continua de pe: chegada da fase e volta pelo corredor da torre")

	await _fechar(f)


func _testar_fase3() -> void:
	print("\n--- FASE 3: SUBSOLO (blecaute permanente) ---")
	var f := await _abrir("res://scenes/fases/fase3_subsolo.tscn")

	# Nada de religar luz: sinalizador, estacao, setores e disjuntores sairam.
	_checar(f.get_node_or_null("Atrio/PickupSinalizador") == null, "sinalizador saiu da fase")
	_checar(f.get_node_or_null("Atrio/EstacaoAtrio") == null, "estacao de recarga saiu da fase")
	_checar(f.get_node_or_null("AlaOeste/Setores") == null, "interruptores de setor sairam da fase")
	_checar(f.get_node_or_null("AlaLeste/Disjuntores") == null, "disjuntores gerais sairam da fase")

	# A luz da fase e a lanterna do armario do fosso; as sentinelas andam.
	var player := f.get_node("Player")
	_checar(player.get_node_or_null("Lanterna") != null, "lanterna instalada no player")
	_checar(f.get_node_or_null("FossoVentilacao/PickupLanterna") != null,
		"lanterna espera no armario do fosso")
	_checar(get_tree().get_nodes_in_group("sentinela").size() >= 6,
		"sentinelas espalhadas pelo subsolo")

	var esteira := f.get_node("AlaLeste/Esteiras/Esteira1/Bloco")
	_checar(not esteira.solido, "esteira comeca desligada")
	f.get_node("AlaLeste/Esteiras/Esteira1/Alvo").atingir_bumerangue()
	await get_tree().process_frame
	_checar(esteira.solido, "bumerangue ligou a esteira")

	# A celula S nao depende mais de interruptor: espera na sala do fim,
	# atras do corredor eletrificado.
	_checar(Progresso.conquistou_celula("S") or f.get_node_or_null("CelulaS") != null,
		"celula S espera atras do corredor eletrificado")

	await _fechar(f)


func _testar_final() -> void:
	print("\n--- FINAL: TORRE DE LANCAMENTO ---")
	# Com o painel incompleto, o portao continua fechado.
	var f := await _abrir("res://scenes/fases/fase_final.tscn")
	var portao := f.get_node("Portao/PortaoCHONPS")
	_checar(portao.solido == (not Progresso.todas_as_celulas()), "portao respeita o painel CHONPS")
	_checar(f.get_node("Plataforma/Capsula").visible == false, "capsula escondida antes da checagem de LiOH")

	var painel := f.get_node("Portao/PainelChonps")
	for letra in Progresso.CELULAS:
		_checar(painel.get_node_or_null("Letras/" + letra) is Sprite2D, "painel tem a letra " + letra)

	await _fechar(f)


func _testar_dash() -> void:
	print("\n--- DASH DA MOCHILA ---")
	var f := await _abrir("res://scenes/fases/fase2_torre.tscn")
	var player: CharacterBody2D = f.get_node("Player")
	var ferramentas = player.get_node("Ferramentas")
	# O teste anterior deixa a arvore pausada (dialogo/dosagem); sem despausar,
	# nenhum frame de fisica roda e o dash nunca avanca.
	get_tree().paused = false
	Progresso.dar_habilidade("mochila")

	# A direcao sai do input em 8 direcoes, nao so do lado que ela olha.
	Input.action_press("ui_left")
	Input.action_press("ui_up")
	var dir: Vector2 = ferramentas._ler_direcao_input()
	Input.action_release("ui_left")
	Input.action_release("ui_up")
	_checar(dir.is_equal_approx(Vector2(-1, -1).normalized()), "dash le a diagonal do input")

	_checar(not player.esta_invencivel_dash, "fora do dash, esta_invencivel_dash comeca desligada")
	ferramentas._iniciar_dash(Vector2.UP)
	_checar(player.ferramenta_controla_movimento, "dash assume o controle do movimento")
	_checar(player.esta_invencivel_dash, "dash liga esta_invencivel_dash")
	_checar(is_equal_approx(player.velocity.y, -FerramentasPlayer.DASH_VELOCIDADE),
		"dash sobe na velocidade cheia")
	_checar(is_zero_approx(Engine.time_scale), "congelamento de impacto parou o jogo")
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	_checar(sprite.animation == "run" and sprite.frame == sprite.sprite_frames.get_frame_count("run") - 1,
		"pose do dash trava no ultimo frame do run")
	_checar(not ferramentas._dash_disponivel, "o dash gasta a carga")
	_checar(ferramentas.resetar_dash(), "valvula de purga recarrega o dash no ar")

	# O congelamento para a fisica: a espera precisa ser em tempo real.
	await get_tree().create_timer(0.5, true, false, true).timeout
	_checar(is_equal_approx(Engine.time_scale, 1.0), "o tempo volta ao normal sozinho")
	_checar(not player.ferramenta_controla_movimento, "dash devolve o controle no fim")
	_checar(not player.esta_invencivel_dash, "dash desliga esta_invencivel_dash no fim")
	_checar(not ferramentas._jato.monitoring, "jato de N2 desliga junto com o dash")
	_checar(sprite.modulate.is_equal_approx(Color.WHITE),
		"cor volta ao normal quando o dash acaba, sem esperar o chao")

	# Bumerangue tambem sai nas 8 direcoes (mesma mira do dash).
	Progresso.dar_habilidade("bumerangue")
	var b := Bumerangue.lancar(player, ferramentas, Vector2.UP)
	var y_inicial := b.global_position.y
	await get_tree().physics_frame
	await get_tree().physics_frame
	_checar(b.global_position.y < y_inicial - 5.0, "bumerangue arremessado para cima sobe")
	b.queue_free()

	# Heranca de momento (a fisica da granada de CS): o MESMO arremesso feito
	# em corrida no eixo da mira sai mais rapido e vai mais longe; feito
	# correndo para tras sai fraco. So a componente no eixo conta.
	var parado := Bumerangue.lancar(player, ferramentas, Vector2.RIGHT)
	var correndo := Bumerangue.lancar(player, ferramentas, Vector2.RIGHT, Vector2(600, 0))
	var de_re := Bumerangue.lancar(player, ferramentas, Vector2.RIGHT, Vector2(-400, 0))
	var de_lado := Bumerangue.lancar(player, ferramentas, Vector2.RIGHT, Vector2(0, -600))
	_checar(correndo._velocidade_saida > parado._velocidade_saida, "em corrida o arremesso sai mais rapido")
	_checar(correndo._alcance > parado._alcance, "em corrida o arremesso vai mais longe")
	_checar(de_re._velocidade_saida < parado._velocidade_saida, "correndo para tras o arremesso sai fraco")
	_checar(is_equal_approx(de_lado._velocidade_saida, parado._velocidade_saida),
		"velocidade fora do eixo da mira nao entra no arremesso")
	_checar(is_zero_approx(parado.forca) and correndo.forca > 0.0, "forca do arremesso acompanha o momento")

	# Chamado de volta: cedo demais e toque duplo sem querer, e ignorado.
	_checar(not parado.chamar_de_volta(), "chamado no mesmo frame do arremesso e ignorado")
	for _quadro in 10:
		await get_tree().physics_frame
	_checar(parado.chamar_de_volta(), "com ele no ar, o segundo toque chama de volta")
	_checar(not parado.chamar_de_volta(), "chamar de volta duas vezes nao faz nada")

	parado.queue_free()
	correndo.queue_free()
	de_re.queue_free()
	de_lado.queue_free()

	await _fechar(f)
