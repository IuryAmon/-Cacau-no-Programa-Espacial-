extends Node

# Teste automático do RECEPTOR DE AMOSTRAS do painel CHONPS
# (scripts/fases/receptor_chonps.gd) e da ida ao painel na cutscene da
# revelação (scripts/cutscene_final_fase.gd).
#
#   godot --headless --path . res://tools/teste_receptor_chonps.tscn
#
# Confere: o Progresso separando amostra COLETADA de letra ENTREGUE, a caixa
# pedindo o E só com amostra na mochila, o toque de E levando a amostra para
# dentro e acendendo a letra, e a cutscene levando os dois até o painel com o
# Dr. Chico jogando o H e o O no receptor e ficando de posto ali.
#
# A conversa do Dialogic em si fica de fora (ela pede escolhas e toques): o
# teste chama direto os dois passos que a timeline chama pelos eventos "do", e
# só confere que a timeline ainda chama esses passos.

const CENA_LAB := "res://scenes/laboratório_(world_2).tscn"

var _falhas := 0


func _ready() -> void:
	_testar_progresso()
	_testar_amostras()
	_testar_timeline()
	await _testar_entrega_da_cacau()
	await _testar_cutscene()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok   " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


func _abrir(caminho: String) -> Node:
	var raiz: Node = (load(caminho) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(raiz)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	return raiz


func _fechar(raiz: Node) -> void:
	raiz.queue_free()
	await get_tree().process_frame


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


## Um toque de E, do jeito que o jogo lê (Interacao.pediu no _process).
func _apertar_e() -> void:
	await get_tree().process_frame
	Input.action_press(Interacao.ACAO)
	await get_tree().process_frame
	Input.action_release(Interacao.ACAO)
	await get_tree().process_frame


func _zerar_progresso() -> void:
	Progresso._celulas.clear()
	Progresso._amostras.clear()


# --- PROGRESSO: COLETADA x ENTREGUE ---

func _testar_progresso() -> void:
	print("\n--- PROGRESSO ---")
	_zerar_progresso()

	Progresso.coletar_celula("N")
	_checar(Progresso.carrega_celula("N"), "coletar deixa a amostra na mao")
	_checar(not Progresso.tem_celula("N"), "coletar NAO acende a letra")
	_checar(Progresso.conquistou_celula("N"), "coletada conta como conquistada")
	_checar(Progresso.contar_celulas() == 0, "painel continua zerado")

	Progresso.coletar_celula("C")
	var esperadas: Array[String] = ["C", "N"]
	_checar(Progresso.amostras_na_mao() == esperadas, "amostras na mao seguem a ordem do CHONPS")

	Progresso.dar_celula("N")
	_checar(Progresso.tem_celula("N") and not Progresso.carrega_celula("N"),
		"entregar acende e tira da mao")
	Progresso.coletar_celula("N")
	_checar(not Progresso.carrega_celula("N"), "letra ja acesa nao volta para a mao")
	_zerar_progresso()


# --- AMOSTRAS ---

func _testar_amostras() -> void:
	print("\n--- AMOSTRAS ---")
	_checar(AmostraChonps.id_no_inventario("C") == "carvao_vegetal", "carbono e o carvao da retorta")
	_checar(AmostraChonps.id_no_inventario("N") == "amostra_N", "id da amostra de N")
	_checar(AmostraChonps.e_amostra("amostra_S") and AmostraChonps.e_amostra("carvao_vegetal"),
		"reconhece amostras na mochila")
	_checar(not AmostraChonps.e_amostra("Cilindro_Oxigenio"), "cilindro nao e amostra")
	for letra in Progresso.CELULAS:
		var tex := AmostraChonps.textura(letra)
		_checar(tex != null and tex.get_height() > 0, "amostra %s tem icone" % letra)
	var frasco := AmostraChonps.textura("P")
	_checar(frasco.get_width() == AmostraChonps.LARGURA_FRASCO
		and frasco.get_height() == AmostraChonps.ALTURA_FRASCO, "frasco provisorio do P no tamanho")
	_checar(EstiloHUD.chapeu_do_item("amostra_N") == "AMOSTRA DO CHONPS", "ficha chama de amostra")
	_checar(EstiloHUD.cor_do_item("amostra_N") == AmostraChonps.cor("N"), "mochila usa a cor do N")


# --- TIMELINE ---

func _testar_timeline() -> void:
	print("\n--- TIMELINE DA REVELACAO ---")
	var texto := FileAccess.get_file_as_string("res://timelines/cientista_final_fase.dtl")
	var ida := texto.find("do DialogicBridge.levar_ao_painel()")
	var entrega := texto.find("do DialogicBridge.entregar_h_e_o()")
	var chonps := texto.find("O famoso CHONPS")
	_checar(ida >= 0 and ida < chonps, "vai ao painel antes de explicar o CHONPS")
	_checar(entrega > chonps, "joga H e O depois de explicar")
	_checar(DialogicBridge.has_method("levar_ao_painel") and DialogicBridge.has_method("entregar_h_e_o"),
		"a ponte tem os dois passos")


# --- A CACAU ENTREGANDO ---

func _testar_entrega_da_cacau() -> void:
	print("\n--- ENTREGA DA CACAU ---")
	_zerar_progresso()
	var lab := await _abrir(CENA_LAB)
	var receptor := lab.get_node_or_null("ReceptorChonps") as ReceptorChonps
	var painel := lab.get_node_or_null("PainelChonps") as PainelChonps
	_checar(receptor != null, "receptor no laboratorio")
	_checar(painel != null and receptor.get_node_or_null(receptor.painel) == painel,
		"receptor ligado ao painel")
	_checar(absf(receptor.global_position.x - painel.global_position.x) < 1.0,
		"receptor centralizado embaixo do painel")
	if receptor == null or painel == null:
		await _fechar(lab)
		return

	var player: CharacterBody2D = lab.get_node("Player")
	player.global_position = receptor.global_position + Vector2(-60, -40)
	for _i in 6:
		await get_tree().physics_frame
	await get_tree().process_frame

	var bau := receptor.get_node("Corpo/Sprite") as AnimatedSprite2D
	var ultimo := bau.sprite_frames.get_frame_count(ReceptorChonps.ANIM_ABRIR) - 1
	_checar(ultimo == 3, "bau tem a animacao de abrir com 4 quadros")
	_checar(not bau.sprite_frames.get_animation_loop(ReceptorChonps.ANIM_ABRIR),
		"animacao de abrir nao repete (trava aberta)")
	_checar(receptor.get_node("Boca").clip_children == CanvasItem.CLIP_CHILDREN_ONLY,
		"boca recorta a amostra que entra")
	_checar(receptor._jogador_perto, "caixa sente a Cacau por perto")
	_checar(not receptor._convidando, "sem amostra a caixa nao pede o E")
	_checar(bau.frame == 0 and not bau.is_playing(), "sem amostra o bau fica fechado")
	await _apertar_e()
	_checar(not receptor._ocupado and Progresso.contar_celulas() == 0,
		"E sem amostra nao faz nada")

	Progresso.coletar_celula("N")
	Inventario.adicionar_item("amostra_N", "Amostra de Nitrogênio", AmostraChonps.textura("N"))
	await get_tree().process_frame
	await get_tree().process_frame
	_checar(receptor._convidando and receptor._aviso_visivel, "com amostra a caixa pede o E")
	_checar(bau.is_playing() and bau.get_playing_speed() > 0.0,
		"com amostra o bau toca a animacao de abrir")
	await _esperar(0.6)
	_checar(bau.frame == ultimo and not bau.is_playing(), "bau abre e trava no ultimo quadro")

	await _apertar_e()
	_checar(receptor._ocupado, "E manda a amostra para a caixa")
	_checar(not Inventario.tem_item("amostra_N"), "amostra sai da mochila no arremesso")
	_checar(not Progresso.tem_celula("N"), "letra so acende quando a amostra chega")
	_checar(receptor.get_node("Boca").get_child_count() == 1, "amostra no ar, dentro da mascara")
	_checar(bau.frame == ultimo, "bau segue aberto com a amostra no ar")

	await receptor.amostra_recebida
	_checar(Progresso.tem_celula("N") and not Progresso.carrega_celula("N"), "letra N acesa")
	var sprite_n := painel.get_node("Letras/N") as Sprite2D
	await _esperar(receptor.segurar_aberto + 0.6)
	_checar(sprite_n.frame == Progresso.CELULAS.find("N") * 2, "painel mostra o N aceso")
	_checar(not receptor._convidando, "sem mais amostras a caixa para de pedir")
	_checar(bau.frame == 0 and not bau.is_playing(), "sem mais amostras o bau fecha")

	# Duas na mão: cada toque entrega uma, na ordem do CHONPS.
	Progresso.coletar_celula("S")
	Progresso.coletar_celula("P")
	await _esperar(0.6)
	await _apertar_e()
	await receptor.amostra_recebida
	_checar(Progresso.tem_celula("P") and Progresso.carrega_celula("S"), "primeiro toque entrega o P")
	await _esperar(receptor.segurar_aberto + 0.3)
	_checar(bau.frame == ultimo, "ainda com o S, o bau segue aberto")
	await _apertar_e()
	await receptor.amostra_recebida
	_checar(Progresso.tem_celula("S"), "segundo toque entrega o S")

	await _fechar(lab)
	_zerar_progresso()


# --- A CUTSCENE: IDA AO PAINEL E O H/O DO DR. CHICO ---

func _testar_cutscene() -> void:
	print("\n--- CUTSCENE: IDA AO PAINEL ---")
	_zerar_progresso()
	EstadoMundo.revelou_dr_chico = false
	var lab := await _abrir(CENA_LAB)
	var cutscene := lab.get_node("ColisaoFinalFase")
	var cientista := lab.get_node("Cientista")
	var receptor := lab.get_node("ReceptorChonps") as ReceptorChonps
	var player: CharacterBody2D = lab.get_node("Player")
	var posto: Vector2 = cutscene._posto_cientista

	_checar(not cientista.visible, "Dr. Chico fora do mapa antes da revelacao")
	_checar(absf(posto.x - receptor.global_position.x) < 200.0, "posto dele fica ao lado do painel")
	_checar(cutscene.get_node_or_null(cutscene.receptor) == receptor, "cutscene aponta o receptor")

	# Como no fim da queda: ele parado à esquerda dela, os dois travados.
	for _i in 30:
		await get_tree().physics_frame
	player.global_position.x = 1450.0
	player.pode_se_mover = false
	cientista.entrar_em_cena()
	cientista.global_position = Vector2(player.global_position.x - 90.0, player.global_position.y - 21.0)
	cutscene.player_ref = player
	cutscene.cientista_ator = cientista
	var y_player := player.global_position.y

	await DialogicBridge.levar_ao_painel()
	_checar(absf(cientista.global_position.x - posto.x) < 1.0, "ele para no posto dele")
	var parada: float = receptor.global_position.x + cutscene.parada_cacau
	_checar(absf(player.global_position.x - parada) < 1.0, "ela para do outro lado do receptor")
	_checar(absf(player.global_position.y - y_player) < 1.0, "ela anda no chao, sem cair")
	_checar(not player.animacao_controlada_externamente, "fisica dela devolvida")
	_checar(not player.pode_se_mover, "continua travada para o resto da fala")
	var sprite_c := cientista.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var sprite_p := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_checar(sprite_c.flip_h == false and sprite_p.flip_h == false, "os dois de frente um para o outro")
	var camera := player.get_node("Camera2D") as Camera2D
	_checar(camera.zoom.x > 2.0, "camera abre no painel")

	var bau := receptor.get_node("Corpo/Sprite") as AnimatedSprite2D
	_checar(bau.frame == 0, "bau fechado antes de ele jogar")
	await DialogicBridge.entregar_h_e_o()
	_checar(bau.frame == 3, "bau abriu para ele jogar o H e o O")
	_checar(Progresso.tem_celula("H") and Progresso.tem_celula("O"), "H e O acesos pelo Dr. Chico")
	_checar(Progresso.contar_celulas() == 2, "so os dois")
	_checar(sprite_c.flip_h == false, "volta a olhar para ela")

	cutscene._on_dialogo_terminou()
	await get_tree().process_frame
	_checar(EstadoMundo.revelou_dr_chico, "revelacao registrada")
	_checar(absf(cientista._origem_x - posto.x) < 1.0, "patrulha em volta do painel")
	_checar(player.pode_se_mover, "Cacau livre no fim")

	await _fechar(lab)
	EstadoMundo.revelou_dr_chico = false
	_zerar_progresso()
