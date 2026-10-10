extends "res://tools/teste_de_tela.gd"

# Teste do menu principal (scenes/menu_principal.tscn), do menu do Laboratório
# (scenes/laboratorio/menu_laboratorio.tscn) e da cortina que troca as cenas
# (scripts/laboratorio/transicao_de_cena.gd), andando pelo jogo de verdade: as
# cenas são trocadas como quando alguém joga.
#
#   * o jogo abre pelo menu principal (a cena principal do projeto);
#   * o menu tem MODO HISTÓRIA, LABORATÓRIO e SAIR, o nome do jogo escrito com
#     as caixas dos elementos (Ca, Ca, U) e o céu do próprio jogo, preso no
#     entardecer sem mexer na hora da partida;
#   * o cenário do menu é feito só da arte do jogo (nenhuma imagem gerada por
#     I.A.): a Cacau e o Dr. Chico na animação de parado que têm no jogo, ela
#     no gramado e ele no piso da base, embaixo do poste aceso, sem ficar
#     atrás do nome nem dos botões;
#   * no menu, nada da história aparece nem responde: o caderno não abre, a
#     lista de objetivos não aparece, o jogo não está pausado;
#   * as setas e o WASD levam o foco, o mouse também; ENTER, ESPAÇO, E e o
#     clique entram; ESC não faz nada no menu principal;
#   * a cortina escurece, troca, clareia e some; dois pedidos seguidos trocam
#     uma vez só; ela solta o jogo se ele estava pausado;
#   * o menu do Laboratório tem um cartão para cada uma das cinco atividades,
#     todos alcançáveis pelas teclas; cada cartão abre a cena dele, e o ESC de
#     cada atividade volta ao menu do Laboratório; ESC no menu do Laboratório
#     volta ao principal;
#   * de controle, o direcional leva o foco um cartão por toque e o ✕ entra;
#   * MODO HISTÓRIA abre o world1 com a Cacau, os HUDs da história ligados e o
#     jogo andando; o botão que escolheu a história (o ESPAÇO, que também é o
#     pulo) não faz a Cacau pular na chegada.
#
# O SAIR não é apertado: ele fecharia o próprio teste.
#
#   godot --headless --path . res://tools/teste_menus.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma imagem de cada menu.

const CENA_MENU := "res://scenes/menu_principal.tscn"
const CENA_LABORATORIO := "res://scenes/laboratorio/menu_laboratorio.tscn"
const CENA_HISTORIA := "res://scenes/world1.tscn"
## As cortinas passam mais depressa enquanto o teste espera por elas.
const PRESSA := 4.0
## As imagens do projeto geradas por I.A.: nenhuma entra no menu.
const IMAGENS_DE_IA := [
	"res://Sprites Tiros (4).png",
	"res://assets/UI/Gemini_Generated_Image_nx8nocnx8nocnx8n.png",
]
## Os personagens do cenário do menu: o nó, e de que cena, nó e animação do
## jogo vem a animação de parado de cada um.
const PERSONAGENS := {
	"Cacau": {"cena": "res://scenes/player.tscn", "no": "AnimatedSprite2D", "animacao": &"idle"},
	"DrChico": {"cena": "res://scenes/cientista.tscn", "no": "AnimatedSprite2D", "animacao": &"default"},
}
## O lado do quadro das folhas dos personagens, em pixels da arte.
const LADO_DO_QUADRO := 96.0


func _ready() -> void:
	await _comecar()
	_testar_o_projeto()
	await _testar_o_menu_principal()
	await _testar_o_cenario_do_menu()
	await _testar_a_cortina()
	await _testar_o_menu_do_laboratorio()
	await _testar_as_atividades()
	await _testar_o_controle()
	await _testar_o_modo_historia()
	_terminar()


# ─────────────────────────────────────────────────────────────
# APOIO
# ─────────────────────────────────────────────────────────────

## Espera a cortina terminar e devolve a cena que chegou (sem desfazê-la).
func _esperar_a_cortina() -> Node:
	Engine.time_scale = PRESSA
	await _esperar_ate(func() -> bool: return not TransicaoDeCena.em_curso(), 20.0)
	Engine.time_scale = 1.0
	await _quadros(2)
	var cena := get_tree().current_scene
	if cena is TelaInterativa:
		_escutar(cena)
	return cena


func _caminho_da_cena() -> String:
	var cena := get_tree().current_scene
	return cena.scene_file_path if cena != null else ""


## Abre uma cena como cena atual (sem cortina) e passa a ouvir os sons dela.
func _ir_direto(caminho: String) -> TelaInterativa:
	var cena := await _trocar_de_cena(caminho) as TelaInterativa
	if cena != null:
		_escutar(cena)
	return cena


## Tudo o que a interface do menu principal cobre: as caixas do nome, a linha
## de baixo dele, os botões e a dica das teclas.
func _interface_do_menu(menu: TelaInterativa) -> Array[Rect2]:
	var pecas: Array[Rect2] = []
	for i in menu.ELEMENTOS_DO_NOME.size():
		pecas.append(menu.retangulo_da_caixa(i))
	var largura := PecasDoLaboratorio.largura(menu.SUBTITULO, menu.TAM_SUBTITULO)
	var sobe := FONTE.get_ascent(menu.TAM_SUBTITULO)
	pecas.append(Rect2(menu._meio_da_coluna() - largura * 0.5, menu._pe_do_subtitulo() - sobe,
		largura, sobe + FONTE.get_descent(menu.TAM_SUBTITULO)))
	for opcao: Dictionary in menu.OPCOES:
		pecas.append(menu.retangulo_do_alvo(String(opcao["chave"])))
	pecas.append(Rect2(menu._meio_da_coluna() - 200.0, menu.size.y - 34.0 - 18.0, 400.0, 36.0))
	return pecas


## Os quadros de animação que um personagem tem no jogo, lidos da cena dele sem
## pôr a cena de pé (o nó "no", propriedade sprite_frames).
func _quadros_do_jogo(cena: String, no: String) -> SpriteFrames:
	var estado := (load(cena) as PackedScene).get_state()
	for i in estado.get_node_count():
		if estado.get_node_name(i) != no:
			continue
		for p in estado.get_node_property_count(i):
			if estado.get_node_property_name(i, p) == &"sprite_frames":
				return estado.get_node_property_value(i, p) as SpriteFrames
	return null


## A animação que o sprite está tocando é igual à do jogo? Mesma folha, mesmos
## recortes na mesma ordem, mesma velocidade.
func _mesma_animacao(sprite: AnimatedSprite2D, cena: String, no: String, animacao: StringName) -> bool:
	var do_jogo := _quadros_do_jogo(cena, no)
	var do_menu := sprite.sprite_frames
	var tocando := sprite.animation
	if do_jogo == null or do_menu == null or not do_jogo.has_animation(animacao) or not do_menu.has_animation(tocando):
		return false
	if do_menu.get_frame_count(tocando) != do_jogo.get_frame_count(animacao) \
			or not is_equal_approx(do_menu.get_animation_speed(tocando), do_jogo.get_animation_speed(animacao)) \
			or do_menu.get_animation_loop(tocando) != do_jogo.get_animation_loop(animacao):
		return false
	for i in do_jogo.get_frame_count(animacao):
		var um := do_menu.get_frame_texture(tocando, i) as AtlasTexture
		var outro := do_jogo.get_frame_texture(animacao, i) as AtlasTexture
		if um == null or outro == null or um.atlas != outro.atlas or um.region != outro.region \
				or not is_equal_approx(do_menu.get_frame_duration(tocando, i), do_jogo.get_frame_duration(animacao, i)):
			return false
	return true


## O que o personagem ocupa na tela: a união do que cada quadro da animação
## desenha (as folhas têm muito vazio em volta do desenho).
func _corpo(sprite: AnimatedSprite2D) -> Rect2:
	var quadros := sprite.sprite_frames
	var usado := Rect2i()
	for i in quadros.get_frame_count(sprite.animation):
		var desenhado := quadros.get_frame_texture(sprite.animation, i).get_image().get_used_rect()
		usado = desenhado if i == 0 else usado.merge(desenhado)
	var canto := Vector2(usado.position)
	if sprite.flip_h:
		canto.x = LADO_DO_QUADRO - float(usado.end.x)
	var escala := sprite.global_scale
	return Rect2(sprite.global_position + (canto - Vector2(LADO_DO_QUADRO, LADO_DO_QUADRO) * 0.5) * escala,
		Vector2(usado.size) * escala)


## O chão embaixo de um ponto do pé: de que arte é o tile ("" = sem chão),
## quanto o pé afunda nele (px da tela) e se o tile de cima está vazio.
func _chao_sob(menu: TelaInterativa, pe: Vector2) -> Dictionary:
	var chao := menu.get_node_or_null("Cenario/Chao") as TileMapLayer
	if chao == null or chao.tile_set == null:
		return {"arte": "", "afunda": 0.0, "livre_em_cima": false}
	var celula := chao.local_to_map(chao.to_local(pe - Vector2(0.0, 2.0)))
	var fonte: TileSetAtlasSource = null
	if chao.get_cell_source_id(celula) >= 0:
		fonte = chao.tile_set.get_source(chao.get_cell_source_id(celula)) as TileSetAtlasSource
	var topo := chao.to_global(chao.map_to_local(celula) - Vector2(chao.tile_set.tile_size) * 0.5).y
	return {
		"arte": fonte.texture.resource_path.get_file() if fonte != null and fonte.texture != null else "",
		"afunda": pe.y - topo,
		"livre_em_cima": chao.get_cell_source_id(celula + Vector2i.UP) < 0,
	}


# ─────────────────────────────────────────────────────────────

func _testar_o_projeto() -> void:
	print("\n--- O PROJETO ---")
	var principal := String(ProjectSettings.get_setting("application/run/main_scene"))
	_checar(principal == CENA_MENU, "a cena principal do projeto é o menu principal (%s)" % principal)
	_checar(TransicaoDeCena.CENA_MENU == CENA_MENU and TransicaoDeCena.CENA_LABORATORIO == CENA_LABORATORIO \
		and TransicaoDeCena.CENA_HISTORIA == CENA_HISTORIA, "a cortina conhece o menu, o Laboratório e o começo da história")
	var faltando := PackedStringArray()
	for caminho: String in [CENA_MENU, CENA_LABORATORIO, CENA_HISTORIA]:
		if not ResourceLoader.exists(caminho):
			faltando.append(caminho)
	_checar(faltando.is_empty(), "as três cenas existem %s" % [faltando])


func _testar_o_menu_principal() -> void:
	print("\n--- O MENU PRINCIPAL ---")
	var hora_antes := Atmosfera.hora_da_partida()
	var menu := await _ir_direto(CENA_MENU)
	await _esperar(0.5)
	_checar(menu != null and menu.navegar_com_teclas and not menu.usa_cursor(), "o menu anda pelas teclas (sem cursor do controle)")
	_checar(menu.cena_de_volta.is_empty() and menu.titulo.is_empty() and menu.get_node_or_null("Moldura/AvisoDeVoltar") == null,
		"é a primeira tela: sem plaquinha de título e sem aviso de voltar")
	var chaves: Array = []
	for opcao: Dictionary in menu.OPCOES:
		chaves.append(opcao["chave"])
	_checar(chaves == ["historia", "laboratorio", "sair"] and menu.nomes_dos_alvos() == PackedStringArray(chaves),
		"três opções: MODO HISTÓRIA, LABORATÓRIO e SAIR")
	_checar(menu.OPCOES[0]["nome"] == "MODO HISTÓRIA" and menu.OPCOES[1]["nome"] == "LABORATÓRIO" and menu.OPCOES[2]["nome"] == "SAIR",
		"com esses nomes")
	_checar(menu.alvo_em_foco() == "historia", "abre com o foco no MODO HISTÓRIA")

	# O nome do jogo, com as caixas dos elementos.
	var simbolos := ""
	for z: int in menu.ELEMENTOS_DO_NOME:
		simbolos += Elementos.simbolo(z)
	_checar(simbolos == "CaCaU" and menu.SUBTITULO == "NO PROGRAMA ESPACIAL", "o nome é escrito com a tabela periódica: Ca, Ca, U")

	# Onde fica cada coisa.
	var tela_inteira := Rect2(Vector2.ZERO, menu.size)
	var no_lugar := true
	var botoes: Array[Rect2] = []
	for chave: String in chaves:
		var botao: Rect2 = menu.retangulo_do_alvo(chave)
		if not botao.has_area() or not tela_inteira.grow(-8.0).encloses(botao):
			no_lugar = false
		for outro in botoes:
			if outro.intersects(botao.grow(4.0)):
				no_lugar = false
		botoes.append(botao)
	var caixas: Array[Rect2] = []
	for i in menu.ELEMENTOS_DO_NOME.size():
		var caixa: Rect2 = menu.retangulo_da_caixa(i)
		if not tela_inteira.grow(-8.0).encloses(caixa) or caixa.end.y >= botoes[0].position.y:
			no_lugar = false
		for outra in caixas:
			if outra.intersects(caixa):
				no_lugar = false
		caixas.append(caixa)
	_checar(no_lugar, "as caixas do nome em cima, os três botões embaixo, tudo dentro da tela e sem se cobrir")
	_checar(botoes[2].end.y + 12.0 < menu.size.y - 34.0 - 16.0, "sobra lugar, embaixo do SAIR, para a dica das teclas")
	var subtitulo := PecasDoLaboratorio.largura(menu.SUBTITULO, menu.TAM_SUBTITULO)
	_checar(subtitulo <= menu.largura_do_nome() + 80.0 and menu._pe_do_subtitulo() < botoes[0].position.y - 20.0,
		"a linha NO PROGRAMA ESPACIAL fica entre o nome e os botões")

	var textos: Array = [menu.SUBTITULO]
	var apertados := PackedStringArray()
	for i in menu.OPCOES.size():
		var opcao: Dictionary = menu.OPCOES[i]
		textos.append_array([opcao["nome"], opcao["descricao"]])
		var cabem: float = botoes[i].size.x - 24.0
		var tamanho: int = menu.TAM_NOME if not String(opcao["descricao"]).is_empty() else 22
		if PecasDoLaboratorio.largura(String(opcao["nome"]), tamanho) > cabem \
				or PecasDoLaboratorio.largura(String(opcao["descricao"]), menu.TAM_DESCRICAO) > cabem:
			apertados.append(opcao["nome"])
	_checar(_letras_que_faltam(textos).is_empty(), "toda letra do menu existe na fonte [%s]" % _letras_que_faltam(textos))
	_checar(apertados.is_empty(), "o nome e a descrição de cada opção cabem no botão %s" % [apertados])

	# O céu é o do jogo, e o menu não mexe na hora da partida. (O resto do
	# cenário tem a parte dele: _testar_o_cenario_do_menu.)
	var ceu := menu.get_node_or_null("BG/Ceu")
	var sol := menu.get_node_or_null("BG/CamadaDoSol/Sol")
	var atmosfera := menu.get_node_or_null("Atmosfera") as Atmosfera
	_checar(ceu is CeuPixel and sol is AstroPixel, "o céu e o sol são os do jogo")
	_checar(atmosfera != null and not atmosfera.segue_a_partida and atmosfera.momento == Atmosfera.Momento.ENTARDECER,
		"aceso pela Atmosfera, presa no entardecer")
	_checar(Atmosfera.hora_da_partida() == hora_antes, "sem mexer na hora da partida")
	_checar((menu.get_node("Interface") as CanvasLayer).layer > 0 and menu.painel.get_parent() == menu.get_node("Interface"),
		"a interface fica numa camada por cima do fundo")

	# Nada da história aparece nem responde.
	_checar(not get_tree().paused, "o jogo não está pausado")
	_checar(get_tree().get_first_node_in_group("player") == null, "a Cacau não está no menu")
	_checar(not Caderno.pode_abrir() and not Objetivos._pode_aparecer(), "o caderno e a lista de objetivos não aparecem")
	await _teclar(KEY_M)
	await _quadros(3)
	_checar(not Caderno.aberto() and not get_tree().paused, "M não abre o caderno no menu")
	_checar(Interacao.ocupada(), "o menu segura as teclas: nada delas vaza para o mundo")
	await _foto("menu_1_principal")

	# As teclas e o mouse levam o foco.
	await _teclar(KEY_S)
	_checar(menu.alvo_em_foco() == "laboratorio" and _tocou(menu, "passo"), "S desce o foco para o LABORATÓRIO")
	await _teclar(KEY_DOWN)
	await _teclar(KEY_DOWN)
	_checar(menu.alvo_em_foco() == "sair", "↓ desce ao SAIR e para ali")
	await _teclar(KEY_W)
	await _teclar(KEY_UP)
	await _teclar(KEY_UP)
	_checar(menu.alvo_em_foco() == "historia", "W e ↑ sobem de volta e param no MODO HISTÓRIA")
	await _teclar(KEY_A)
	await _teclar(KEY_RIGHT)
	_checar(menu.alvo_em_foco() == "historia", "para os lados não há para onde ir")
	await _passar_por(menu, "sair")
	_checar(menu.alvo_em_foco() == "sair", "o mouse em cima do SAIR põe o foco nele")
	_mover_o_mouse(Vector2(1500, 300))
	await _quadros(1)
	_checar(menu.alvo_em_foco() == "sair", "tirar o mouse de cima não apaga o foco")
	await _teclar(KEY_ESCAPE)
	await _quadros(2)
	_checar(not menu.de_saida() and not TransicaoDeCena.em_curso() and _caminho_da_cena() == CENA_MENU,
		"ESC não faz nada no menu principal")
	await _foto("menu_2_principal_sair")

	# Entrar no Laboratório, pelo teclado.
	menu.focar("laboratorio")
	await _teclar(KEY_ENTER)
	_checar(menu.de_saida() and TransicaoDeCena.em_curso() and _tocou(menu, "botao"), "ENTER no LABORATÓRIO começa a troca de cena")
	var cena := await _esperar_a_cortina()
	_checar(_caminho_da_cena() == CENA_LABORATORIO and cena is TelaInterativa, "e a cena que chega é o menu do Laboratório")
	_checar(not is_instance_valid(menu), "o menu principal foi embora")


func _testar_o_cenario_do_menu() -> void:
	print("\n--- O CENÁRIO DO MENU PRINCIPAL ---")
	var menu := await _ir_direto(CENA_MENU)
	await _esperar(0.5)
	var tela_inteira := Rect2(Vector2.ZERO, menu.size)
	var pecas_da_interface := _interface_do_menu(menu)
	var atmosfera := menu.get_node_or_null("Atmosfera") as Atmosfera

	# Só a arte do jogo.
	var de_ia := PackedStringArray()
	for dependencia in ResourceLoader.get_dependencies(CENA_MENU):
		for imagem: String in IMAGENS_DE_IA:
			if dependencia.contains(imagem):
				de_ia.append(imagem)
	for sprite: Sprite2D in menu.find_children("*", "Sprite2D", true, false):
		if sprite.texture != null and sprite.texture.resource_path in IMAGENS_DE_IA:
			de_ia.append(sprite.texture.resource_path)
	_checar(de_ia.is_empty(), "o menu não usa nenhuma imagem gerada por I.A. %s" % [de_ia])

	# Os dois personagens, na animação de parado que têm no jogo.
	var sprites := {}
	var corpos := {}
	for no: String in PERSONAGENS:
		var dados: Dictionary = PERSONAGENS[no]
		var sprite := menu.get_node_or_null("Cenario/" + no) as AnimatedSprite2D
		_checar(sprite != null and sprite.is_visible_in_tree() and sprite.is_playing(),
			"Cenario/%s está no cenário, com a animação tocando" % no)
		if sprite == null:
			continue
		_checar(_mesma_animacao(sprite, dados["cena"], dados["no"], dados["animacao"]),
			"Cenario/%s toca a animação de parado do jogo: a mesma folha, os mesmos quadros, a mesma velocidade (\"%s\" de %s)" \
			% [no, dados["animacao"], String(dados["cena"]).get_file()])
		sprites[no] = sprite
		corpos[no] = _corpo(sprite)
	if sprites.size() < PERSONAGENS.size():
		return
	var cacau: AnimatedSprite2D = sprites["Cacau"]
	var chico: AnimatedSprite2D = sprites["DrChico"]
	var corpo_da_cacau: Rect2 = corpos["Cacau"]
	var corpo_do_chico: Rect2 = corpos["DrChico"]
	var quadros_antes := [cacau.frame, chico.frame]
	await _esperar(0.25)
	_checar(cacau.frame != quadros_antes[0] and chico.frame != quadros_antes[1], "as duas animações andam (um quarto de segundo depois, outro quadro)")

	# Onde cada um está.
	var grama := _chao_sob(menu, Vector2(corpo_da_cacau.get_center().x, corpo_da_cacau.end.y))
	var pedra := _chao_sob(menu, Vector2(corpo_do_chico.get_center().x, corpo_do_chico.end.y))
	_checar(grama["arte"] == "Floor Tiles1.png" and grama["livre_em_cima"] and grama["afunda"] > 0.0 and grama["afunda"] <= 24.0,
		"a Cacau pisa no gramado (o pé afunda %d px na grama)" % roundi(grama["afunda"]))
	_checar(pedra["arte"] == "level_tileset.png" and pedra["livre_em_cima"] and pedra["afunda"] > 0.0 and pedra["afunda"] <= 24.0,
		"o Dr. Chico pisa no piso de pedra da base (o pé afunda %d px)" % roundi(pedra["afunda"]))
	var escondidos := PackedStringArray()
	for no: String in corpos:
		var corpo: Rect2 = corpos[no]
		if not tela_inteira.encloses(corpo):
			escondidos.append("%s sai da tela" % no)
		for peca in pecas_da_interface:
			if peca.grow(8.0).intersects(corpo):
				escondidos.append("%s atrás da interface" % no)
	_checar(escondidos.is_empty(), "os dois aparecem inteiros: dentro da tela e sem nome nem botão na frente %s" % [escondidos])
	_checar(corpo_da_cacau.end.x < corpo_do_chico.position.x and not cacau.flip_h and not chico.flip_h,
		"a Cacau à esquerda e o Dr. Chico à direita, um de frente para o outro")

	# O poste pintado acende sozinho, em cima do Dr. Chico.
	var postes := menu.get_node_or_null("PostesDeLuz") as PostesDeLuz
	var luzes: Array[LuzDePoste] = []
	if postes != null:
		luzes = postes.luzes()
	_checar(luzes.size() == 1, "o poste pintado no cenário ganha a luz dele (%d)" % luzes.size())
	if luzes.size() == 1:
		var luz := luzes[0]
		_checar(luz.global_position.y < corpo_do_chico.position.y \
			and absf(luz.global_position.x - corpo_do_chico.get_center().x) <= luz.largura * 0.5, "a lâmpada fica em cima do Dr. Chico")
		_checar(luz.intensidade > 0.0 and is_equal_approx(luz.intensidade, atmosfera.entardecer.postes),
			"acesa na força do entardecer, como os postes do world1")

	# O fundo: a serra e os pinheiros, mais desbotados quanto mais longe.
	var profundidades: Array = []
	for camada: Dictionary in atmosfera._camadas:
		profundidades.append(camada["profundidade"])
	var do_longe_ao_perto := profundidades.size() == 4
	for i in range(1, profundidades.size()):
		if profundidades[i] >= profundidades[i - 1]:
			do_longe_ao_perto = false
	_checar(do_longe_ao_perto and profundidades[0] > 0.5, "a serra e as três fileiras de pinheiros desbotam com a distância, da mais longe à mais perto %s" % [profundidades])
	var para_a_esquerda := true
	for no: String in ["BG/NuvensDoFundo", "BG/Nuvens"]:
		var nuvens := menu.get_node_or_null(no) as Nuvens
		if nuvens == null or nuvens.vento >= 0.0:
			para_a_esquerda = false
	_checar(para_a_esquerda, "as nuvens vão para a esquerda, para onde o vento leva o cabelo da Cacau")
	var sol := menu.get_node_or_null("BG/CamadaDoSol/Sol") as AstroPixel
	var disco := Rect2(sol.global_position, Vector2.ZERO).grow(sol.raio_efetivo() * sol.global_scale.x)
	var sol_a_vista := tela_inteira.encloses(disco)
	for peca in pecas_da_interface:
		if peca.intersects(disco):
			sol_a_vista = false
	_checar(sol_a_vista, "o sol aparece inteiro, fora do nome e dos botões")
	await _foto("menu_1b_cenario")


func _testar_a_cortina() -> void:
	print("\n--- A CORTINA ---")
	var menu := await _ir_direto(CENA_MENU)
	await _esperar(0.2)
	get_tree().paused = true
	var terminou := [0]
	var cortina := TransicaoDeCena.ir_para(get_tree(), CENA_LABORATORIO)
	_checar(cortina != null and TransicaoDeCena.em_curso(), "ir_para() devolve a cortina e marca a troca em curso")
	cortina.terminou.connect(func() -> void: terminou[0] += 1)
	_checar(cortina.layer == TransicaoDeCena.CAMADA and TransicaoDeCena.CAMADA > CursorVirtual.CAMADA \
		and TransicaoDeCena.CAMADA > Caderno.CAMADA_ABERTO, "ela fica acima de tudo: do caderno aberto e do cursor do controle")
	_checar(cortina.get_parent() == get_tree().root and cortina.process_mode == Node.PROCESS_MODE_ALWAYS,
		"pendurada na raiz, andando mesmo com o jogo pausado")
	_checar(TransicaoDeCena.ir_para(get_tree(), CENA_MENU) == null, "um segundo pedido no meio da troca é recusado")
	# No meio da troca, o menu que está saindo não responde.
	await _clicar(menu, "historia")
	await _teclar(KEY_ENTER)
	_checar(not menu.de_saida(), "enquanto a cortina passa, o menu que sai não aceita clique nem tecla")
	await _esperar_a_cortina()
	_checar(_caminho_da_cena() == CENA_LABORATORIO, "a cena trocou para a que foi pedida primeiro (o Laboratório)")
	_checar(not get_tree().paused, "e o jogo, que estava pausado, foi solto")
	await _quadros(3)
	_checar(terminou[0] == 1 and not TransicaoDeCena.em_curso() and not is_instance_valid(cortina) \
		and get_tree().root.get_node_or_null("TransicaoDeCena") == null, "a cortina avisa que terminou, uma vez, e some")
	_checar(TransicaoDeCena.ir_para(null, CENA_MENU) == null and not TransicaoDeCena.em_curso(), "sem árvore, ir_para() não faz nada")

	# Dois cliques seguidos no mesmo botão trocam de cena uma vez só.
	menu = await _ir_direto(CENA_MENU)
	await _esperar(0.2)
	var saidas := [0]
	menu.saindo.connect(func() -> void: saidas[0] += 1)
	await _clicar(menu, "laboratorio")
	await _clicar(menu, "laboratorio")
	await _clicar(menu, "historia")
	_checar(saidas[0] == 1 and TransicaoDeCena.em_curso(), "três cliques seguidos: uma troca só")
	await _esperar_a_cortina()
	_checar(_caminho_da_cena() == CENA_LABORATORIO, "para o Laboratório, o primeiro clique")


func _testar_o_menu_do_laboratorio() -> void:
	print("\n--- O MENU DO LABORATÓRIO ---")
	var menu := await _ir_direto(CENA_LABORATORIO)
	await _esperar(0.5)
	_checar(menu.titulo == "LABORATÓRIO" and menu.retangulo_do_titulo().has_area(), "o título é LABORATÓRIO")
	_checar(menu.cena_de_volta == CENA_MENU and menu.texto_de_voltar == "menu" and menu.get_node_or_null("Moldura/AvisoDeVoltar") != null,
		"ESC volta ao menu principal, e o aviso do canto diz isso")
	_checar(menu.navegar_com_teclas and not menu.usa_cursor(), "anda pelas teclas (sem cursor do controle)")
	var chaves: Array = []
	var faltando := PackedStringArray()
	var textos: Array = [menu.titulo, menu.texto_de_voltar]
	for dados: Dictionary in menu.ATIVIDADES:
		chaves.append(dados["chave"])
		textos.append_array([dados["nome"], dados["descricao"]])
		if not ResourceLoader.exists(String(dados["cena"])):
			faltando.append(dados["cena"])
	_checar(chaves == ["monte", "quiz", "balanceamento", "destilador", "tabela"] and menu.nomes_dos_alvos() == PackedStringArray(chaves),
		"cinco atividades: monte seu átomo, que átomo é esse?, balanceamento, destilador e tabela periódica")
	_checar(faltando.is_empty(), "a cena de cada uma existe %s" % [faltando])
	_checar(menu.atividade("tabela")["nome"] == "TABELA PERIÓDICA" and menu.atividade("monte")["nome"] == "MONTE SEU ÁTOMO" \
		and menu.atividade("quiz")["nome"] == "QUE ÁTOMO É ESSE?" and menu.atividade("nada").is_empty(),
		"com os nomes: MONTE SEU ÁTOMO, QUE ÁTOMO É ESSE?, TABELA PERIÓDICA")
	_checar(_letras_que_faltam(textos).is_empty(), "toda letra do menu existe na fonte [%s]" % _letras_que_faltam(textos))
	_checar(menu.alvo_em_foco() == "monte", "abre com o foco no primeiro cartão")

	# Os cartões: na tela, sem se cobrir, abaixo do título, acima da dica das teclas.
	var tela_inteira := Rect2(Vector2.ZERO, menu.size)
	var cartoes: Array[Rect2] = []
	var no_lugar := true
	for i in chaves.size():
		var cartao: Rect2 = menu.retangulo_do_cartao(i)
		if cartao != menu.retangulo_do_alvo(String(chaves[i])) or not tela_inteira.grow(-8.0).encloses(cartao) \
				or cartao.position.y < menu.retangulo_do_titulo().end.y + 8.0 or cartao.end.y > menu.size.y - 40.0 - 24.0:
			no_lugar = false
		for outro in cartoes:
			if outro.grow(8.0).intersects(cartao):
				no_lugar = false
		cartoes.append(cartao)
	_checar(no_lugar, "os cinco cartões cabem na tela, entre o título e a dica das teclas, sem se cobrir")
	_checar(is_equal_approx(cartoes[0].position.y, cartoes[2].position.y) and is_equal_approx(cartoes[3].position.y, cartoes[4].position.y) \
		and cartoes[3].position.y > cartoes[0].end.y \
		and is_equal_approx(cartoes[0].position.x + cartoes[2].end.x, menu.size.x) \
		and is_equal_approx(cartoes[3].position.x + cartoes[4].end.x, menu.size.x),
		"três em cima e dois embaixo, as duas fileiras centradas")
	var aviso: Label = menu.get_node("Moldura/AvisoDeVoltar")
	_checar(not aviso.get_global_rect().intersects(cartoes[0]) and not aviso.get_global_rect().intersects(menu.retangulo_do_titulo()),
		"o aviso de voltar não encosta em cartão nem no título")
	var apertados := PackedStringArray()
	for dados: Dictionary in menu.ATIVIDADES:
		# A descrição quebra na largura do fio que separa a figura do nome (24 px
		# de cada lado); o nome, numa linha só, precisa de 16 px de respiro.
		var cabem: float = menu.TAMANHO_DO_CARTAO.x - 48.0
		if PecasDoLaboratorio.largura(String(dados["nome"]), menu.TAM_NOME) > menu.TAMANHO_DO_CARTAO.x - 32.0:
			apertados.append("%s: o nome" % dados["chave"])
		var linhas := PecasDoLaboratorio.contar_linhas(String(dados["descricao"]), menu.TAM_DESCRICAO, cabem)
		var pe: float = menu.ALTURA_DA_FIGURA + 62.0 + PecasDoLaboratorio.altura_das_linhas(linhas, menu.TAM_DESCRICAO, menu.ENTRELINHA)
		if pe > menu.TAMANHO_DO_CARTAO.y - 10.0:
			apertados.append("%s: a descrição (%d linhas)" % [dados["chave"], linhas])
	_checar(apertados.is_empty(), "o nome e a descrição de cada atividade cabem no cartão %s" % [apertados])

	# Os átomos que giram nos cartões.
	var atomos_certos := true
	for chave: String in ["monte", "quiz"]:
		var atomo: AtomoCamadas = menu._atomos.get(chave)
		var cartao: Rect2 = menu.retangulo_do_alvo(chave)
		if atomo == null or atomo.protons() <= 0 or not cartao.grow(4.0).encloses(atomo.get_global_rect()) \
				or atomo.get_global_rect().end.y > cartao.position.y + menu.ALTURA_DA_FIGURA + 8.0:
			atomos_certos = false
	_checar(atomos_certos, "os cartões do átomo têm um átomo de verdade girando, dentro da figura")
	await _foto("menu_3_laboratorio")

	# O foco, pelas teclas.
	await _teclar(KEY_D)
	_checar(menu.alvo_em_foco() == "quiz" and _tocou(menu, "passo"), "D vai do primeiro cartão ao segundo")
	await _teclar(KEY_RIGHT)
	await _teclar(KEY_RIGHT)
	_checar(menu.alvo_em_foco() == "balanceamento", "→ vai ao terceiro e para na ponta")
	await _teclar(KEY_DOWN)
	_checar(menu.alvo_em_foco() == "tabela", "↓ desce ao cartão de baixo mais próximo (a tabela periódica)")
	await _teclar(KEY_A)
	_checar(menu.alvo_em_foco() == "destilador", "A vai ao destilador")
	await _teclar(KEY_W)
	_checar(menu.alvo_em_foco() in ["monte", "quiz"], "W sobe a um dos cartões de cima (%s)" % menu.alvo_em_foco())
	var alcancados := {"monte": true}
	var fila: Array[String] = ["monte"]
	while not fila.is_empty():
		var de: String = fila.pop_front()
		for direcao: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var vizinho: String = menu._vizinho(de, direcao)
			if vizinho != "" and not alcancados.has(vizinho):
				alcancados[vizinho] = true
				fila.append(vizinho)
	_checar(alcancados.size() == chaves.size(), "pelas teclas se chega aos cinco cartões (%d)" % alcancados.size())
	await _passar_por(menu, "destilador")
	_checar(menu.alvo_em_foco() == "destilador", "o mouse em cima de um cartão põe o foco nele")
	await _foto("menu_4_laboratorio_foco")

	# ESC volta ao menu principal.
	await _teclar(KEY_ESCAPE)
	_checar(menu.de_saida() and TransicaoDeCena.em_curso(), "ESC pede para voltar")
	await _esperar_a_cortina()
	_checar(_caminho_da_cena() == CENA_MENU, "e a cena que chega é o menu principal")


func _testar_as_atividades() -> void:
	print("\n--- DO LABORATÓRIO A CADA ATIVIDADE, E DE VOLTA ---")
	var menu := await _ir_direto(CENA_LABORATORIO)
	await _esperar(0.2)
	var atividades: Array = menu.ATIVIDADES
	for i in atividades.size():
		var dados: Dictionary = atividades[i]
		var chave := String(dados["chave"])
		# Uma entra pelo clique, a seguinte pelo teclado, e assim por diante.
		if i % 2 == 0:
			await _clicar(menu, chave)
		else:
			menu.focar(chave)
			await _teclar(KEY_E if i == 1 else KEY_SPACE)
		var saiu: bool = menu.de_saida()
		var cena := await _esperar_a_cortina()
		var chegou := _caminho_da_cena() == String(dados["cena"])
		var e_tela := cena is TelaInterativa
		# Lá dentro: nada da história, e o ESC traz de volta.
		var quieto: bool = not get_tree().paused and not Caderno.pode_abrir() and get_tree().get_first_node_in_group("player") == null
		await _esperar(0.3)
		await _teclar(KEY_ESCAPE)
		# A tabela periódica e a escolha do nível saem no primeiro ESC, como as outras.
		var pediu_para_voltar := e_tela and (cena as TelaInterativa).de_saida()
		var volta := await _esperar_a_cortina()
		_checar(saiu and chegou and e_tela and quieto and pediu_para_voltar and _caminho_da_cena() == CENA_LABORATORIO,
			"%s: o cartão abre %s, e o ESC de lá volta ao Laboratório" % [dados["nome"], String(dados["cena"]).get_file()])
		menu = volta as TelaInterativa
		await _esperar(0.2)
	_checar(get_tree().get_nodes_in_group(CursorVirtual.GRUPO).size() == 1, "de volta, só o menu do Laboratório está na tela")


func _testar_o_controle() -> void:
	print("\n--- NO CONTROLE ---")
	var menu := await _ir_direto(CENA_LABORATORIO)
	await _esperar(0.3)
	await _tocar_no_controle(JOY_BUTTON_DPAD_RIGHT)
	_checar(Controle.em_uso and menu.alvo_em_foco() == "quiz", "um toque no direcional leva o foco UM cartão (monte -> quiz)")
	_checar(CursorVirtual.ativo() and not CursorVirtual._com_cursor, "aparece a barra de comandos, sem o cursor")
	_checar(menu.dicas_do_controle() == [["direcional", "ESCOLHER"], ["cruz", "ENTRAR"], ["fechar", "MENU"]],
		"a barra diz: direcional ESCOLHER, ✕ ENTRAR, △ MENU")
	_eixo_do_controle(JOY_AXIS_LEFT_X, 1.0)
	await _quadros(4)
	for i in 5:
		_eixo_do_controle(JOY_AXIS_LEFT_X, 0.9 + 0.02 * i)
		await _quadros(1)
	_checar(menu.alvo_em_foco() == "balanceamento", "o analógico empurrado (e tremendo) dá um passo só")
	_eixo_do_controle(JOY_AXIS_LEFT_X, 0.0)
	await _quadros(3)
	await _tocar_no_controle(JOY_BUTTON_DPAD_DOWN)
	_checar(menu.alvo_em_foco() == "tabela", "o direcional para baixo desce à tabela periódica")
	await _tocar_no_controle(JOY_BUTTON_A)
	_checar(menu.de_saida(), "✕ entra no cartão em foco")
	await _esperar_a_cortina()
	_checar(_caminho_da_cena() == "res://scenes/laboratorio/tabela_periodica.tscn", "a tabela periódica abre")
	await _tocar_no_controle(JOY_BUTTON_Y)
	await _esperar_a_cortina()
	_checar(_caminho_da_cena() == CENA_LABORATORIO, "△ volta ao menu do Laboratório")
	await _tocar_no_controle(JOY_BUTTON_B)
	await _esperar_a_cortina()
	_checar(_caminho_da_cena() == CENA_MENU, "○ também volta: do Laboratório ao menu principal")
	menu = get_tree().current_scene as TelaInterativa
	_checar(menu.dicas_do_controle() == [["direcional", "ESCOLHER"], ["cruz", "ENTRAR"]], "no menu principal a barra não oferece voltar")
	await _tocar_no_controle(JOY_BUTTON_DPAD_DOWN)
	_checar(menu.alvo_em_foco() == "laboratorio", "o direcional desce ao LABORATÓRIO")
	await _tocar_no_controle(JOY_BUTTON_Y)
	await _quadros(3)
	_checar(not menu.de_saida() and not Caderno.aberto(), "△ no menu principal não volta para lugar nenhum nem abre o caderno")
	await _voltar_ao_teclado()


func _testar_o_modo_historia() -> void:
	print("\n--- MODO HISTÓRIA ---")
	var menu := await _ir_direto(CENA_MENU)
	await _esperar(0.3)
	_checar(menu.alvo_em_foco() == "historia", "o menu abre com o foco no MODO HISTÓRIA")
	# O ESPAÇO escolhe (e é também a tecla de pular): fica apertado até a fase chegar.
	_tecla(KEY_SPACE, true)
	await _quadros(2)
	_checar(menu.de_saida() and TransicaoDeCena.em_curso(), "ESPAÇO no MODO HISTÓRIA começa a troca de cena")
	_checar(Interacao.toque_preso(&"jump"), "o ESPAÇO que escolheu fica preso ao menu: não vale como pulo")
	var cena := await _esperar_a_cortina()
	_checar(_caminho_da_cena() == CENA_HISTORIA, "a cena que chega é o world1 (%s)" % _caminho_da_cena())
	var cacau := get_tree().get_first_node_in_group("player")
	_checar(cacau != null and cena.is_ancestor_of(cacau), "com a Cacau")
	_checar(get_tree().get_nodes_in_group(CursorVirtual.GRUPO).filter(func(no: Node) -> bool: return no is TelaInterativa).is_empty(),
		"nenhuma tela do menu ficou para trás")
	_checar(not get_tree().paused, "o jogo está andando")
	_checar(Caderno.visible and Objetivos.visible and FerramentasHUD.visible, "os HUDs da história estão ligados (a cortina não os apaga)")
	_checar(Interacao.toque_preso(&"jump") and not Interacao.livre_para(&"jump"),
		"com o ESPAÇO ainda apertado na chegada, a Cacau não pula")
	_tecla(KEY_SPACE, false)
	await _quadros(3)
	_checar(not Interacao.toque_preso(&"jump"), "soltando o ESPAÇO, o pulo volta a valer")
	_checar(Atmosfera.da_cena(cena) != null and Atmosfera.da_cena(cena).segue_a_partida, "e a fase está na hora da partida")
	await _foto("menu_5_historia")
	# Arruma a casa: a fase vai embora antes de o teste fechar.
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()
	cena.queue_free()
	await _quadros(3)
