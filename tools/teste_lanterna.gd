extends Node

# Teste de fumaça da lanterna + sentinelas, no mesmo espírito do
# tools/teste_fases.gd: primeiro o DetectorConeLuz puro (distância, ângulo,
# linha de visão), depois a fase 3 real, depois a cena de teste inteira
# (congelamento em um frame, mira fixa ao flip_h, parede cortando a visão,
# bateria, contato).
#
#   godot --headless --path . res://tools/teste_lanterna.tscn

var _falhas := 0


func _ready() -> void:
	await _testar_detector()
	await _testar_colisao_atravessa_player()
	await _testar_fase3_fosso()
	await _testar_cena_completa()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok   " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


func _abrir(caminho: String) -> Node:
	var cena: PackedScene = load(caminho)
	var raiz := cena.instantiate()
	get_tree().root.add_child.call_deferred(raiz)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	return raiz


func _fechar(raiz: Node) -> void:
	raiz.queue_free()
	await get_tree().process_frame


## Espera a ficha de coleta da ferramenta aparecer e a fecha. Enquanto ela está
## na tela o mundo fica pausado e o E é dela (Interacao.ocupada), então nada do
## roteiro anda — é a apresentação do bumerangue que a cena de teste dispara
## sozinha ao entregar a habilidade.
func _fechar_ficha_de_coleta(player: Node) -> void:
	var espera := 0.0
	while not Inventario.popup_aberto and espera < 1.5:
		await get_tree().create_timer(0.05).timeout
		espera += 0.05
	var hud = player.get_node_or_null("InventarioHud")
	if hud != null and Inventario.popup_aberto:
		await hud.fechar_popup()
	get_tree().paused = false


# ---------------------------------------------------------------------------

func _testar_detector() -> void:
	print("\n--- DETECTOR DE CONE (distancia / angulo / linha de visao) ---")
	var mundo := Node2D.new()
	get_tree().root.add_child.call_deferred(mundo)
	await get_tree().process_frame

	var det := DetectorConeLuz.new()
	det.alcance = 320.0
	det.abertura_graus = 45.0
	det.direcao = Vector2.RIGHT
	mundo.add_child(det)
	await get_tree().physics_frame

	_checar(det.is_point_lit(Vector2(150, 0)), "ponto a frente, dentro do alcance")
	_checar(det.is_point_lit(Vector2(300, 0)), "ponto perto do limite do alcance")
	_checar(not det.is_point_lit(Vector2(400, 0)), "alem do alcance NAO ilumina")
	_checar(det.is_point_lit(Vector2.ZERO), "a propria origem conta como iluminada")
	_checar(det.is_point_lit(Vector2.from_angle(deg_to_rad(20.0)) * 150.0),
		"20 graus: dentro da metade da abertura (22.5)")
	_checar(not det.is_point_lit(Vector2.from_angle(deg_to_rad(25.0)) * 150.0),
		"25 graus: fora da metade da abertura")
	_checar(not det.is_point_lit(Vector2(0, 150)), "90 graus: fora do cone")

	det.ativo = false
	_checar(not det.is_point_lit(Vector2(150, 0)), "detector desligado nao ilumina nada")
	det.ativo = true

	# Parede entre a origem e o ponto: mesmo dentro do alcance e do angulo,
	# a linha de visao cortada significa NAO iluminado.
	var parede := StaticBody2D.new()
	parede.position = Vector2(200, 0)
	mundo.add_child(parede)
	Blockout.forma_ret(parede, Vector2(24, 240))
	await get_tree().physics_frame
	await get_tree().physics_frame

	_checar(not det.is_point_lit(Vector2(300, 0)), "parede corta a linha de visao")
	_checar(det.is_point_lit(Vector2(150, 0)), "antes da parede segue iluminado")
	det.excluir = [parede.get_rid()]
	_checar(det.is_point_lit(Vector2(300, 0)), "corpo na lista 'excluir' nao faz sombra")
	det.excluir = []

	mundo.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------

func _testar_colisao_atravessa_player() -> void:
	print("\n--- COLISAO: PLAYER E SENTINELA NUNCA SE EMPURRAM ---")
	var mundo := Node2D.new()
	get_tree().root.add_child.call_deferred(mundo)
	await get_tree().process_frame

	# Chao largo; o player cai de cima e assenta sozinho — evita eu ter que
	# calcular na mao o offset exato da CapsuleShape2D dele.
	Blockout.bloco(mundo, "Chao", Rect2(200, 600, 700, 200))

	var player: CharacterBody2D = load("res://scenes/player.tscn").instantiate()
	player.name = "Player"
	player.global_position = Vector2(500, 300)
	mundo.add_child(player)

	# Tempo real (nao pausa por hitstop nenhum aqui, mas segue o mesmo idioma
	# usado no resto do arquivo) ate o player cair e assentar no chao.
	await get_tree().create_timer(0.8, true, false, true).timeout
	await get_tree().physics_frame
	_checar(player.is_on_floor(), "player caiu e assentou no chao (setup do teste)")

	# Nasce SOBREPOSTA ao player de proposito: se a excecao de colisao nao
	# tivesse sido aplicada, o recuo automatico do move_and_slide() da propria
	# Sentinela (que precisa continuar vendo parede, mesma camada do player)
	# ia empurra-la pra longe so por estarem coladas, mesmo com velocidade 0.
	var x_spawn := player.global_position.x
	var sentinela := Sentinela.criar(mundo, "SentinelaColada", player.global_position)
	sentinela.velocidade = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	# So o eixo X importa aqui: os dois tem alturas diferentes (capsula do
	# player x retangulo da Sentinela), entao um pequeno acerto vertical ao
	# assentar é esperado — o que NAO pode acontecer é ser empurrada de lado.
	_checar(absf(sentinela.global_position.x - x_spawn) < 4.0,
		"sobreposta ao player (parada), a sentinela NAO e empurrada para o lado")

	# E o inverso: o player tambem nao sente a sentinela no caminho. Sem
	# await entre o move_and_slide manual e a leitura — um frame do
	# _physics_process normal do player.gd já reaplicaria o atrito de idle
	# e mascararia o resultado.
	var x_antes := player.global_position.x
	player.velocity = Vector2(300, 0)
	player.move_and_slide()
	_checar(player.global_position.x > x_antes + 1.0, "o player atravessa a sentinela sem ser freado")

	mundo.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------

func _testar_fase3_fosso() -> void:
	print("\n--- FASE 3: SUBSOLO REFEITO (blecaute permanente) ---")
	var f := await _abrir("res://scenes/fases/fase3_subsolo.tscn")
	get_tree().paused = false

	var player: CharacterBody2D = f.get_node("Player")
	var lanterna: Lanterna = player.get_node_or_null("Lanterna")
	_checar(lanterna != null, "fase base instala a lanterna no player")

	# Coesao do blecaute: nenhuma outra luz alem da que ela carrega.
	_checar(f.get_node_or_null("Atrio/PickupSinalizador") == null, "sinalizador saiu da fase")
	_checar(f.get_node_or_null("Atrio/EstacaoAtrio") == null, "estacao de recarga saiu da fase")
	_checar(f.get_node_or_null("AlaOeste/Setores") == null, "interruptores de setor sairam da fase")
	_checar(f.get_node_or_null("AlaLeste/Disjuntores") == null, "disjuntores gerais sairam da fase")

	var fosso := f.get_node_or_null("FossoVentilacao")
	_checar(fosso != null, "area do fosso montada na fase")
	_checar(fosso != null and fosso.get_node_or_null("PickupLanterna") != null,
		"lanterna espera no armario de manutencao do fosso")
	_checar(get_tree().get_nodes_in_group("sentinela").size() >= 6,
		"sentinelas espalhadas pelo mapa inteiro")
	_checar(f.get_node_or_null("CelulaS") != null or Progresso.tem_celula("S"),
		"celula S espera na sala atras do corredor eletrificado")

	# As moradoras ficam paradas durante as checagens de feixe.
	for s: Sentinela in get_tree().get_nodes_in_group("sentinela"):
		s.velocidade = 0.0

	# O feixe funciona DENTRO da fase real, com o TileMap dela no caminho.
	# Mira fixa ao flip_h (default false = olhando para a direita): a prova
	# fica à direita do player de propósito, sem precisar virar ninguém.
	Progresso.dar_habilidade("lanterna")
	lanterna.ligada = true
	var prova := Sentinela.criar(f, "SentinelaProva", player.global_position + Vector2(240, -28))
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_checar(prova.estado == Sentinela.Estado.CONGELADO, "sentinela congela no feixe dentro da fase 3")
	prova.queue_free()

	await _fechar(f)


# ---------------------------------------------------------------------------

func _testar_cena_completa() -> void:
	print("\n--- CENA DE TESTE: LANTERNA + SENTINELAS ---")
	var f := await _abrir("res://tools/test_lanterna.tscn")
	get_tree().paused = false

	var player: CharacterBody2D = f.get_node_or_null("Player")
	_checar(player != null, "player na cena")

	# A cena de teste entrega bumerangue de saída, e o FerramentasHUD apresenta
	# a ferramenta um quarto de segundo depois — com o mundo PAUSADO e a tecla
	# presa pela ficha de coleta. Isso caía no meio do roteiro e travava tudo
	# dali para a frente. Espera a ficha subir e fecha antes de começar.
	await _fechar_ficha_de_coleta(player)

	var lanterna: Lanterna = player.get_node_or_null("Lanterna")
	_checar(lanterna != null, "lanterna instalada no player")
	_checar(Progresso.tem_habilidade("lanterna"), "cena de teste entrega a flag 'lanterna'")
	_checar(lanterna.is_in_group("fonte_de_luz"), "lanterna no grupo fonte_de_luz")
	_checar(not lanterna.ligada, "comeca DESLIGADA (jogadora precisa acender na mao)")
	# O resto do roteiro (congelamento, bateria etc.) testa com o feixe aceso.
	lanterna.ligada = true

	# As tres sentinelas do roteiro ficam paradas durante o teste automatico,
	# senao elas atravessam a sala no meio das esperas e mordem o player.
	for s: Sentinela in get_tree().get_nodes_in_group("sentinela"):
		s.velocidade = 0.0

	# Invariavel visual == deteccao: os mesmos numeros dos dois lados.
	await get_tree().physics_frame
	var det: DetectorConeLuz = lanterna.get_node("Detector")
	_checar(det.alcance == lanterna.alcance and det.abertura_graus == lanterna.abertura_graus,
		"detector usa os MESMOS alcance e abertura do visual")
	var luz: PointLight2D = lanterna.get_node("Feixe")
	_checar(is_equal_approx(luz.texture_scale * (Lanterna.LADO_TEXTURA * 0.5), lanterna.alcance),
		"textura do feixe escala exatamente ate o alcance")

	# Mira PRESA (padrão) ao flip_h do sprite — sem input próprio, então
	# deterministica no headless: o player nasce olhando para a direita.
	await get_tree().physics_frame
	_checar(not lanterna.mira_livre, "cena de teste comeca em mira presa (padrao)")
	_checar(lanterna.direcao_atual().is_equal_approx(Vector2.RIGHT), "mira presa aponta para a direita")

	# --- BOTAO ALTERNA MIRA (L): presa <-> livre ---
	_checar(InputMap.has_action("alternar_mira"), "acao 'alternar_mira' existe no input map")
	Input.action_press("alternar_mira")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("alternar_mira")
	_checar(lanterna.mira_livre, "L liga a mira livre")

	# Em mira livre, o analogico direito vence o mouse: simula olhar para
	# CIMA — bem diferente da horizontal fixa que a mira presa daria aqui.
	var eixo_cima := InputEventJoypadMotion.new()
	eixo_cima.device = 0
	eixo_cima.axis = JOY_AXIS_RIGHT_Y
	eixo_cima.axis_value = -1.0
	Input.parse_input_event(eixo_cima)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_checar(lanterna.direcao_atual().dot(Vector2.UP) > 0.9,
		"mira livre segue o analogico direito (aqui, para cima)")
	# Zera o eixo antes de seguir: outro teste nao pode herdar este estado.
	eixo_cima.axis_value = 0.0
	Input.parse_input_event(eixo_cima)

	Input.action_press("alternar_mira")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("alternar_mira")
	await get_tree().physics_frame
	_checar(not lanterna.mira_livre, "L de novo volta para mira presa")
	_checar(lanterna.direcao_atual().is_equal_approx(Vector2.RIGHT),
		"e a mira presa volta a apontar para a direita")

	# --- CONGELA NO FRAME EM QUE A LUZ BATE ---
	var pegou_congelou := [false]
	var pegou_descongelou := [false]
	var s_frente := Sentinela.criar(f, "SentinelaTesteFrente", player.global_position + Vector2(240, -28))
	s_frente.congelou.connect(func() -> void: pegou_congelou[0] = true)
	s_frente.descongelou.connect(func() -> void: pegou_descongelou[0] = true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_checar(s_frente.estado == Sentinela.Estado.CONGELADO, "sentinela no feixe congela de imediato")
	_checar(pegou_congelou[0], "sinal 'congelou' disparou")
	_checar(s_frente.velocity.is_zero_approx(), "congelada fica com velocity zerada")
	_checar(lanterna.is_body_lit(s_frente), "is_body_lit confirma a sentinela no feixe")

	# --- BATERIA ZERADA: LANTERNA APAGA SOZINHA, TODO MUNDO DESCONGELA ---
	var pegou_esgotada := [false]
	lanterna.bateria_esgotada.connect(func() -> void: pegou_esgotada[0] = true)
	lanterna.bateria = 0.4  # com drain_rate 2.0, esgota em ~0.2 s
	await get_tree().create_timer(0.5).timeout
	_checar(pegou_esgotada[0], "sinal 'bateria_esgotada' disparou")
	_checar(not lanterna.acesa(), "bateria zerada apaga o feixe")
	_checar(not lanterna.ligada, "esgotar DESLIGA a lanterna (religar e manual)")
	_checar(not luz.enabled, "PointLight2D desliga junto")
	await get_tree().create_timer(0.4).timeout  # > delay_retomada (0.15)
	_checar(s_frente.estado == Sentinela.Estado.PERSEGUINDO, "sem luz, a sentinela volta a andar")
	_checar(pegou_descongelou[0], "sinal 'descongelou' disparou")
	_checar(lanterna.bateria > 0.0, "apagada, a bateria se recupera sozinha")

	lanterna.recarregar()
	_checar(lanterna.bateria == 100.0 and not lanterna.acesa(),
		"recarga cheia continua apagada ate a jogadora religar")
	lanterna.ligada = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_checar(lanterna.acesa(), "religada na mao, o feixe volta")
	_checar(s_frente.estado == Sentinela.Estado.CONGELADO, "feixe de volta congela de novo")

	# --- FORA DO CONE (as costas) MAS DENTRO DO RAIO: continua vindo ---
	var s_tras := Sentinela.criar(f, "SentinelaTesteTras", player.global_position + Vector2(-240, -28))
	await get_tree().physics_frame
	var dist0: float = s_tras.global_position.distance_to(player.global_position)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_checar(s_tras.estado == Sentinela.Estado.PERSEGUINDO, "sentinela as costas (fora do cone) nao congela")
	_checar(s_tras.global_position.distance_to(player.global_position) < dist0 - 2.0,
		"e continua avancando na direcao do player")

	# --- FORA DO RAIO DE PERSEGUICAO: espreita parada ---
	var s_longe := Sentinela.criar(f, "SentinelaTesteLonge", player.global_position + Vector2(700, -28))
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_checar(s_longe.estado == Sentinela.Estado.PERSEGUINDO and absf(s_longe.velocity.x) < 1.0,
		"fora do raio de perseguicao, espreita parada")
	s_longe.queue_free()

	# --- PAREDE CORTA A LINHA DE VISAO (dentro do angulo e do alcance) ---
	player.global_position = Vector2(1480, 512)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var s_parede := Sentinela.criar(f, "SentinelaTesteParede", Vector2(1750, 470))
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_checar(not lanterna.is_body_lit(s_parede), "atras da parede central: NAO iluminada")
	_checar(s_parede.estado == Sentinela.Estado.PERSEGUINDO, "e por isso nao congela")
	_checar(lanterna.is_point_lit(lanterna.global_position + Vector2(80, 0)),
		"antes da parede o feixe segue valendo")

	# --- CONTATO: dano por distancia + sinal ---
	lanterna.ligada = false  # apaga para o alvo continuar PERSEGUINDO
	# Espera MAIOR que o delay_retomada: congelada nao machuca (por design),
	# entao o toque so vale depois que ela voltou a perseguir.
	await get_tree().create_timer(0.3).timeout
	_checar(s_frente.estado == Sentinela.Estado.PERSEGUINDO, "apagar a lanterna solta o alvo do contato")
	var pegou_toque := [false]
	s_frente.tocou_player.connect(func() -> void: pegou_toque[0] = true)
	var vida0: int = player.current_health
	s_frente.global_position = player.global_position + Vector2(8, -8)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_checar(pegou_toque[0], "sinal 'tocou_player' disparou no contato")
	_checar(player.current_health == vida0 - 1, "contato tirou 1 de vida")

	# Trava TODAS as sentinelas paradas daqui pra frente: s_tras e s_parede
	# nunca tiveram a velocidade zerada (os testes delas dependiam de
	# perseguir de verdade) e, se continuassem andando, podiam alcancar o
	# player e reiniciar o stun de knockback bem na hora dos testes seguintes.
	s_frente.velocidade = 0.0
	s_tras.velocidade = 0.0
	s_parede.velocidade = 0.0

	# Espera a invencibilidade DESSE hit acabar de vez (0.6s de knockback +
	# 0.8s de i-frames = 1.4s) antes do teste do dash, para os dois sistemas
	# de invulnerabilidade nao se confundirem um com o outro.
	await get_tree().create_timer(1.6).timeout
	_checar(not player.esta_invencivel, "invencibilidade do hit anterior ja acabou")

	# --- DASH: invulneravel a dano, mesmo colada numa sentinela ---
	var ferramentas: FerramentasPlayer = player.get_node("Ferramentas")
	s_frente.velocidade = 0.0
	s_frente.global_position = player.global_position + Vector2(6, -6)  # colada
	await get_tree().physics_frame
	_checar(not player.esta_invencivel_dash, "fora do dash, esta_invencivel_dash comeca desligada")
	var vida_antes_dash: int = player.current_health
	ferramentas._iniciar_dash(Vector2.RIGHT)
	_checar(player.esta_invencivel_dash, "iniciar o dash liga esta_invencivel_dash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_checar(player.current_health == vida_antes_dash,
		"colada no player, a sentinela NAO tira vida durante o dash")
	# O congelamento de impacto pausa o Engine.time_scale — espera em tempo real.
	await get_tree().create_timer(0.4, true, false, true).timeout
	_checar(not player.esta_invencivel_dash, "o dash termina e a invulnerabilidade some")

	# --- BUMERANGUE VIA CLIQUE (a mesma acao do teclado, so que pela acao nova) ---
	_checar(InputMap.has_action("arremessar_mouse"), "acao 'arremessar_mouse' existe no input map")
	# A conquista do bumerangue, la em cima, abriu o popup de item — e enquanto
	# ele esta na tela o E e as ferramentas pertencem a ela (Interacao.ocupada),
	# entao o clique nao chegaria no componente. Fecha antes de testar.
	var hud_item = player.get_node_or_null("InventarioHud")
	if hud_item and Inventario.popup_aberto:
		await hud_item.fechar_popup()
	_checar(not Interacao.ocupada(), "nenhuma tela segurando as ferramentas antes do clique")
	_checar(not ferramentas._bumerangue_no_ar, "nenhum bumerangue no ar antes do clique")
	Input.action_press("arremessar_mouse")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("arremessar_mouse")
	_checar(ferramentas._bumerangue_no_ar, "clique esquerdo arremessou o bumerangue")

	# Tira os inimigos de cena e espera o take_damage do player terminar os
	# awaits internos (knockback + invencibilidade) antes de fechar tudo.
	s_frente.queue_free()
	s_tras.queue_free()
	s_parede.queue_free()
	await get_tree().create_timer(2.0).timeout

	await _fechar(f)
