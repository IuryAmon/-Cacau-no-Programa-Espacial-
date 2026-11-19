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
#     quem receba a tag dela;
#   * A RUA: com a amostra gelada na mão, a saída para o corredor e a porta da
#     torre barram; a plataforma do elevador de carga espera lá no alto até a
#     Cacau descer do telhado nela, e depois fica parada no chão, com o tubo
#     recolhido;
#   * O TELHADO: chegar marca a subida e a Cacau comenta; os cilindros de
#     amostra ficam em fileiras e colunas; o que ela pega vai para a mochila e
#     não volta mais, e os outros ficam (um de cada vez: o E num deles vira a
#     fala) — antes disso, a escada não desce (a Cacau diz que precisa pegar
#     um); anda-se para a frente e para trás: a
#     Cacau, menor e com a câmera mais perto, pisa só dentro da FaixaDoChao
#     (←/→ e ↑/↓ param nas bordas, o pulo cai na mesma linha), e a grade e o
#     muro da frente ficam na frente dela; O ELEVADOR: a cabine pintada sai
#     das camadas de tile; sem o cilindro, o E nela é a fala da escada; com
#     ele, a cabine afunda levando a Cacau e a rua abre com ela descendo na
#     plataforma, do alto até o chão, com o tubo sumindo por cima;
#   * A TORRE: sem a mochila, a Cacau comenta o degrau alto — e o pulo duplo
#     não chega nele; com a mochila, pulo + jato chega; o ventilador desliga o
#     vapor; a caixa elétrica recolhe as serras da chaminé; as plataformas
#     laranja viram plataformas que caem; as janelas são do tamanho das da
#     sala do compressor e nenhuma fica atrás de uma porta;
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


func _testar_rua() -> void:
	print("\n--- A RUA ---")
	await _abrir(RUA)
	await _segundos(1.0)
	var rua := get_tree().current_scene
	var porta_torre := rua.get_node("PortaTorre")
	_checar(not rua.segura_a_saida() and porta_torre.interativa, "sem a amostra, a rua deixa ir para todo lado")

	MissaoNitrogenio.amostra = GasFechado.new(1.0, 3.0, 80.0)
	await _quadros(2)
	_checar(rua.segura_a_saida(), "com a amostra gelada na mão, a saída para o corredor barra")
	_checar(not porta_torre.interativa, "   e a porta da torre não abre")
	MissaoNitrogenio.amostra = null

	var plataforma: BlocoDeTiles = rua.plataforma_do_elevador()
	var tubo: BlocoDeTiles = rua.tubo_do_elevador()
	_checar(plataforma != null and plataforma.celulas() > 0 and tubo != null and tubo.celulas() > 0,
		"o elevador de carga da rua: a plataforma e o tubo saem do Cenario 2")
	if plataforma == null:
		return
	var no_alto := plataforma.area_agora(rua.area_do_elevador)
	_checar(is_equal_approx(no_alto.position.y, rua.topo_do_percurso)
			and is_equal_approx(tubo.corte_acima(), no_alto.end.y),
		"   antes de ela descer do telhado, ele espera lá no alto (topo em y = %.0f), com o tubo esticado"
		% no_alto.position.y)
	_checar(plataforma.get_node_or_null("Piso") is StaticBody2D, "   e dá para pisar nela")

	# Depois da primeira descida, a rua abre com ele parado no chão.
	MissaoNitrogenio.elevador_desceu = true
	await _abrir(RUA)
	rua = get_tree().current_scene
	plataforma = rua.plataforma_do_elevador()
	tubo = rua.tubo_do_elevador()
	var area_agora := plataforma.area_agora(rua.area_do_elevador)
	_checar(is_equal_approx(area_agora.end.y, rua.chao_do_elevador)
			and is_equal_approx(tubo.corte_acima(), rua.chao_do_elevador),
		"   depois que desceu, a base dele fica no chão (y = %.0f) e o tubo, recolhido" % area_agora.end.y)
	MissaoNitrogenio.elevador_desceu = false


func _testar_telhado() -> void:
	print("\n--- O TELHADO ---")
	# A cena do lançamento (no meio do telhado) tem teste próprio:
	# teste_lancamento. Aqui ela já foi vista, senão pararia os testes do
	# elevador no meio.
	MissaoNitrogenio.viu_o_lancamento = true
	Inventario.remover_item(MissaoNitrogenio.ID_CILINDRO_VAZIO)
	await _abrir(MissaoNitrogenio.CENA_TELHADO)
	var telhado := get_tree().current_scene
	_checar(MissaoNitrogenio.subiu_a_torre, "chegar ao telhado marca a subida da torre")
	var estante := telhado.get_node_or_null("CilindrosDeAr") as CilindrosDoTelhado
	var todos: Array[CilindroDoTelhado] = estante.cilindros() if estante else ([] as Array[CilindroDoTelhado])
	_checar(estante != null and todos.size() == estante.fileiras * estante.colunas and todos.size() > 1,
		"os cilindros de amostra estão lá, em %d fileiras e %d colunas"
		% [estante.fileiras if estante else 0, estante.colunas if estante else 0])
	var cilindro: CilindroDoTelhado = todos[0] if not todos.is_empty() else null
	if estante and estante.fileiras >= 3:
		await _testar_cilindros_atras_da_sola(estante)
	await _esperar(func() -> bool: return Dialogic.current_timeline != null, 4.0)
	_checar(Dialogic.current_timeline != null, "e a Cacau comenta ao chegar")
	await _encerrar_fala()
	if cilindro == null:
		return

	# Sem o cilindro, a escada não desce.
	var porta_escada := telhado.get_node("PortaEscada") as Area2D
	_checar(not porta_escada.interativa, "com o cilindro no suporte, a porta da escada não abre")
	var player := _player()
	_pousar(player, porta_escada.get_node("PontoDeSaida").global_position)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _quadros(2)
	Input.action_press("interact")
	await _esperar(func() -> bool: return Dialogic.current_timeline != null, 1.0)
	Input.action_release("interact")
	_checar(Dialogic.current_timeline != null
			and Dialogic.current_timeline.resource_path.contains("cacau_pegar_cilindro_antes"),
		"   o E na porta da escada vira a fala do cilindro")
	await _encerrar_fala()
	_checar(get_tree().current_scene == telhado, "   e ela continua no telhado")
	# Nem pelo elevador.
	player.global_position.x = telhado.area_do_elevador.get_center().x - 20.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _quadros(2)
	Input.action_press("interact")
	await _esperar(func() -> bool: return Dialogic.current_timeline != null, 1.0)
	Input.action_release("interact")
	_checar(Dialogic.current_timeline != null
			and Dialogic.current_timeline.resource_path.contains("cacau_pegar_cilindro_antes")
			and telhado.cabine_do_elevador().deslocamento == 0.0,
		"   e o E no elevador também (a cabine não sai do lugar)")
	await _encerrar_fala()
	var nome_do_pego := String(cilindro.name)
	cilindro._pegar()
	await _esperar(func() -> bool: return Inventario.popup_aberto, 3.0)
	_checar(Inventario.popup_aberto, "pegar abre a ficha do cilindro")
	if Inventario.tela_hud_referencia:
		await Inventario.tela_hud_referencia.fechar_popup()
	await _esperar(func() -> bool: return MissaoNitrogenio.tem_cilindro_vazio(), 3.0)
	_checar(MissaoNitrogenio.tem_cilindro_vazio(), "e ele vai para a mochila")
	# A fala de quem pegou vem um instante depois da ficha fechar.
	await _esperar(func() -> bool: return Dialogic.current_timeline != null, 2.0)
	await _encerrar_fala()
	_checar(porta_escada.interativa, "com o cilindro na mochila, a escada volta a descer")

	# Um de cada vez: com o dela na mochila, o E no do lado vira a fala.
	var outro: CilindroDoTelhado = todos[1]
	_pousar(player, outro.global_position + Vector2(0.0, -2.0))
	# A área do cilindro leva uns quadros de física para ver a Cacau teleportada.
	for i in 10:
		await get_tree().physics_frame
	await _quadros(2)
	Input.action_press("interact")
	await _esperar(func() -> bool: return Dialogic.current_timeline != null, 1.0)
	Input.action_release("interact")
	_checar(Dialogic.current_timeline != null
			and Dialogic.current_timeline.resource_path.contains("cacau_um_cilindro_basta")
			and outro.ainda_no_lugar() and estante.cilindros().size() == todos.size() - 1,
		"   um de cada vez: com o dela na mochila, o E no do lado vira a fala e ele fica lá (fala: %s, de pé: %d)"
		% [Dialogic.current_timeline.resource_path.get_file() if Dialogic.current_timeline else "nenhuma", estante.cilindros().size()])
	await _encerrar_fala()

	await _abrir(MissaoNitrogenio.CENA_TELHADO)
	await _quadros(3)
	var de_volta := get_tree().current_scene.get_node_or_null("CilindrosDeAr") as CilindrosDoTelhado
	_checar(de_volta != null and de_volta.get_node_or_null(nome_do_pego) == null
			and de_volta.cilindros().size() == todos.size() - 1,
		"voltando ao telhado, o que ela pegou não está mais lá e os outros %d continuam"
		% (de_volta.cilindros().size() if de_volta else 0))
	await _encerrar_fala()
	await _testar_faixa_do_telhado()
	await _testar_elevador_do_telhado()


## Na frente ou atrás: com a sola desenhada da Cacau (a última linha do sprite)
## 3 px abaixo da base da terceira fileira — e a base da colisão dela ACIMA
## dessa base —, as três fileiras do fundo passam por trás dela e as da frente,
## na frente.
func _testar_cilindros_atras_da_sola(estante: CilindrosDoTelhado) -> void:
	var player := _player()
	var posicao_antes := player.global_position
	var pes_antes: float = player.altura_dos_pes()
	var base_da_terceira: float = estante.global_position.y + estante.lugar(2, 0).y
	var sola := base_da_terceira + 3.0
	var da_colisao_a_sola: float = player._da_colisao_a_sola()
	var pes := sola - da_colisao_a_sola
	_pousar(player, Vector2(estante.global_position.x - 60.0, player.global_position.y + pes - player.altura_dos_pes()))
	player._pisar_na_linha(pes)
	for i in 4:
		await get_tree().physics_frame
	await _quadros(2)
	var errados: Array[String] = []
	for c in estante.cilindros():
		var atras: bool = c.global_position.y < player.sola_no_chao()
		if (c.z_index < player.z_index) != atras:
			errados.append(String(c.name))
	_checar(da_colisao_a_sola > 0.0 and pes < base_da_terceira and errados.is_empty(),
		"   os cilindros com a base acima do pé desenhado dela passam por trás (sola em y = %.1f, colisão em %.1f; errados: %s)"
		% [player.sola_no_chao(), player.altura_dos_pes(), ", ".join(errados) if not errados.is_empty() else "nenhum"])
	# De volta para onde ela estava, com o chão da faixa junto.
	_pousar(player, posicao_antes)
	player._pisar_na_linha(pes_antes)
	for i in 4:
		await get_tree().physics_frame


## O elevador de carga: a cabine pintada afunda levando a Cacau e a rua abre
## com ela descendo na plataforma, do alto até o chão.
func _testar_elevador_do_telhado() -> void:
	var telhado := get_tree().current_scene
	var player := _player()
	var cabine: BlocoDeTiles = telhado.cabine_do_elevador()
	var area: Rect2 = telhado.area_do_elevador
	var nomes := cabine.copias().map(func(c: TileMapLayer) -> String: return str(c.name))
	_checar(cabine.celulas() > 0 and nomes.has("Cenario") and nomes.has("Terreno") and nomes.has("Frente"),
		"o elevador do telhado: a cabine sai das camadas de tile (%d tiles: %s)" % [cabine.celulas(), ", ".join(nomes)])
	var sobrou := 0
	for camada in telhado.find_children("*", "TileMapLayer", true, false):
		if camada.owner != telhado:
			continue
		for celula in camada.get_used_cells():
			if area.has_point(camada.to_global(camada.map_to_local(celula))):
				sobrou += 1
	_checar(sobrou == 0, "   e nenhum tile dela fica para trás nas camadas")
	for copia in cabine.copias():
		if copia.name == "Frente":
			_checar(copia.z_index > player.z_index, "   a grade da frente da cabine continua na frente da Cacau")

	player.global_position.x = area.get_center().x + 25.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _quadros(2)
	_checar(telhado.esta_na_cabine(), "   em cima da cabine, o E vale")
	Input.action_press("interact")
	await _esperar(func() -> bool: return cabine.deslocamento > 10.0, 3.0)
	Input.action_release("interact")
	_checar(not player.pode_se_mover and cabine.deslocamento > 0.0
			and absf(player.global_position.x - area.get_center().x) < 1.0,
		"   com o cilindro na mochila, ela vai para o meio e a cabine afunda com ela")
	_checar(player.altura_do_corte() > telhado.topo_do_muro_da_frente,
		"   o corte do sprite dela desce junto com a cabine (y = %.0f)" % player.altura_do_corte())
	await _esperar(func() -> bool:
		var cena := get_tree().current_scene
		return cena != null and cena.scene_file_path == RUA and cena.is_node_ready(), 8.0)
	var rua := get_tree().current_scene
	_checar(rua.scene_file_path == RUA, "   sumidas as duas no fundo do poço, a rua abre")
	if rua.scene_file_path != RUA:
		return
	await _quadros(2)
	var plataforma: BlocoDeTiles = rua.plataforma_do_elevador()
	var tubo: BlocoDeTiles = rua.tubo_do_elevador()
	var cacau := _player()
	var no_alto := plataforma.area_agora(rua.area_do_elevador)
	_checar(not cacau.pode_se_mover and no_alto.position.y < rua.area_do_elevador.position.y,
		"   ela chega em cima da plataforma, lá no alto (topo em y = %.0f)" % no_alto.position.y)
	_checar(is_equal_approx(tubo.corte_acima(), no_alto.end.y),
		"   com o tubo esticado até a base dela (y = %.0f)" % tubo.corte_acima())
	await _esperar(func() -> bool: return cacau.pode_se_mover, 8.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var piso: float = rua.chao_do_elevador - rua.area_do_elevador.size.y + rua.altura_do_piso
	_checar(cacau.pode_se_mover and absf(cacau.altura_dos_pes() - piso) < 1.5 and cacau.is_on_floor(),
		"   a plataforma desce até o chão e ela fica de pé nela, livre (pés em y = %.1f; o piso, %.0f)"
		% [cacau.altura_dos_pes(), piso])
	_checar(is_equal_approx(tubo.corte_acima(), rua.chao_do_elevador), "   e o tubo some inteiro, recolhido")
	_checar(MissaoNitrogenio.elevador_desceu, "   e daqui em diante a rua abre com ele no chão")
	await _segundos(0.5)


## Anda-se para a frente e para trás: os pés da Cacau só pisam dentro da
## FaixaDoChao, e a grade e o muro da frente passam na frente dela.
func _testar_faixa_do_telhado() -> void:
	var telhado := get_tree().current_scene
	var player := _player()
	var no_da_faixa := telhado.get_node_or_null("FaixaDoChao") as ReferenceRect
	_checar(no_da_faixa != null and player.esta_na_faixa(), "no telhado anda-se para a frente e para trás (FaixaDoChao)")
	if no_da_faixa == null:
		return
	var faixa := no_da_faixa.get_global_rect()
	_checar(player.scale.x < 1.0 and player.zoom_da_camera > 1.5,
		"   a Cacau menor (escala %.2f) e a câmera mais perto (zoom %.1f)" % [player.scale.x, player.zoom_da_camera])
	_checar(player.velocidade_de_profundidade < player.velocidade_na_faixa * 0.5,
		"   para o fundo e para a frente ela anda bem mais devagar que para os lados (%.0f e %.0f)"
		% [player.velocidade_de_profundidade, player.velocidade_na_faixa])
	var corte: float = player.altura_do_corte()
	_checar(is_equal_approx(corte, telhado.topo_do_muro_da_frente) and corte > faixa.position.y
			and corte < faixa.end.y,
		"   o sprite some abaixo do topo do muro da frente (y = %.0f), dentro da faixa: os pés passam por trás dele" % corte)
	await _esperar(func() -> bool: return player.pode_se_mover, 3.0)
	await _segurar("ui_down", 0.8)
	var pes: float = player._altura_dos_pes()
	_checar(player.is_on_floor() and absf(pes - faixa.end.y) < 1.0,
		"   ↓ leva os pés até a borda da frente da faixa (%.1f; a borda, %.0f)" % [pes, faixa.end.y])
	await _segurar("ui_up", 0.8)
	pes = player._altura_dos_pes()
	_checar(player.is_on_floor() and absf(pes - faixa.position.y) < 1.0,
		"   ↑ leva até a borda do fundo (%.1f; a borda, %.0f)" % [pes, faixa.position.y])
	await _segurar("ui_down", 0.15)
	var linha: float = player._altura_dos_pes()
	await _toque("jump")
	await _esperar(func() -> bool: return player._altura_dos_pes() < linha - 20.0, 0.6)
	var subiu: bool = player._altura_dos_pes() < linha - 20.0
	await _esperar(func() -> bool: return player.is_on_floor(), 2.0)
	_checar(subiu and player.is_on_floor() and absf(player._altura_dos_pes() - linha) < 1.0,
		"   o pulo sobe e cai de volta na mesma linha (%.1f)" % linha)
	var ponta: float = faixa.position.x + player._meia_largura()
	Input.action_press("ui_left")
	await _esperar(func() -> bool: return player.global_position.x <= ponta + 0.5, 6.0)
	await _segundos(0.2)
	Input.action_release("ui_left")
	_checar(absf(player.global_position.x - ponta) < 0.5,
		"   e a ponta da faixa segura para os lados (x = %.1f)" % player.global_position.x)

	# A grade e o muro da frente: na frente da Cacau, sem colisão, e o muro
	# nas células que eram do Terreno (sem tile repetido), logo abaixo da faixa.
	var terreno := telhado.get_node("Terreno") as TileMapLayer
	var frente := telhado.get_node_or_null("Frente") as TileMapLayer
	var muro := telhado.get_node_or_null("MuroDaFrente") as TileMapLayer
	_checar(frente != null and muro != null and not muro.get_used_cells().is_empty()
			and frente.z_index > player.z_index and muro.z_index > player.z_index
			and not frente.collision_enabled and not muro.collision_enabled,
		"a grade (Frente) e o muro (MuroDaFrente) ficam na frente da Cacau, sem colisão")
	if muro == null:
		return
	var repetidos := muro.get_used_cells().filter(func(celula: Vector2i) -> bool:
		return terreno.get_cell_source_id(celula) != -1)
	var topo := INF
	for celula in muro.get_used_cells():
		topo = minf(topo, muro.to_global(muro.map_to_local(celula) - Vector2(muro.tile_set.tile_size) * 0.5).y)
	_checar(repetidos.is_empty() and muro.transform == terreno.transform and topo >= faixa.end.y,
		"   o muro na grade do Terreno, sem tile repetido, começando logo abaixo da faixa (y = %.0f)" % topo)


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
	# porta.
	var janelas := torre.get_node("Janelas") as TileMapLayer
	var escala := _escala_das_janelas_do_compressor()
	var retangulos := _janelas(janelas)
	_checar(janelas.scale == escala and retangulos.size() == 24,
		"as 24 janelas da torre na escala das do compressor (%s, a do compressor %s)" % [janelas.scale, escala])
	var na_frente: Array[Rect2] = []
	for porta in ["Andares/Andar0_Terreo/PortaRua", "Andares/Andar7_Topo/PortaTelhado"]:
		na_frente.append(_retangulo_do_desenho(torre.get_node(porta + "/SpritePorta") as AnimatedSprite2D))
	var atras := retangulos.filter(func(janela: Rect2) -> bool:
		return na_frente.any(func(coisa: Rect2) -> bool: return janela.intersects(coisa)))
	_checar(atras.is_empty(), "   nenhuma atrás das %d portas %s" % [na_frente.size(), atras])


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


func _pousar(player: CharacterBody2D, onde: Vector2) -> void:
	player.global_position = onde
	player.velocity = Vector2.ZERO


func _toque(acao: String) -> void:
	Input.action_press(acao)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(acao)


func _segurar(acao: String, segundos: float) -> void:
	Input.action_press(acao)
	await _segundos(segundos)
	Input.action_release(acao)
	await get_tree().physics_frame
	await get_tree().physics_frame


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
