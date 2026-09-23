extends Node

# Teste de fumaça da coleta: a ficha (scenes/ui/popup_item.tscn) e a mochila
# (scripts/ui/mochila_hud.gd), montadas dentro do HUD de sempre.
#
# O que este teste protege, agora que as duas peças são desenhadas em _draw e
# se medem sozinhas:
#
#   * a ficha NASCE DO TEXTO. Nada de offset ajustado no editor que um nome
#     mais comprido desmancha — texto maior faz a caixa crescer, e ela tem de
#     continuar dentro da tela.
#   * o caminho inteiro de uma coleta funciona: abrir, pausar, fechar, o ícone
#     voar, o alvéolo encher, "popup_fechado" sair e o jogo despausar — nessa
#     ordem, porque é dela que o FerramentasHUD depende.
#   * a mochila fica no canto SUPERIOR DIREITO, com a capacidade que promete.
#   * ferramenta não ocupa alvéolo (ela vai para o cinto).
#
#   godot --headless --path . res://tools/teste_popup_item.tscn

const POPUP := "res://scenes/ui/popup_item.tscn"
const HUD := "res://scenes/inventario_hud.tscn"

## Folga para a coreografia de fechamento (voo + apagar da ficha) terminar.
const ESPERA_FECHAMENTO := 1.4

var _falhas := 0


func _ready() -> void:
	# Sai do _ready da árvore antes de pendurar cenas na raiz (add_child direto
	# aqui dentro esbarra na raiz ainda ocupada montando os autoloads).
	await get_tree().process_frame
	_testar_estilo()
	await _testar_ficha_solta()
	await _testar_coleta_completa()
	await _testar_mochila()
	await _testar_ferramenta()
	await _testar_cinto()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


# ─────────────────────────────────────────────────────────────
# A linguagem visual compartilhada
# ─────────────────────────────────────────────────────────────

func _testar_estilo() -> void:
	print("\n--- ESTILO COMPARTILHADO (popup e mochila falam a mesma lingua) ---")

	# Nome com categoria entre parenteses vira titulo grande + etiqueta.
	var partes := EstiloHUD.separar_nome("Cilindro de Oxigênio (Comburente)")
	_checar(partes["titulo"] == "Cilindro de Oxigênio", "nome perde o parentese no titulo")
	_checar(partes["etiqueta"] == "COMBURENTE", "categoria vira etiqueta em caixa alta")
	_checar(EstiloHUD.separar_nome("Bumerangue")["etiqueta"] == "",
		"nome sem parentese nao inventa etiqueta")

	# Cor: ferramenta vem do catalogo, item do jogo vem da tabela, resto cai
	# no acento padrao.
	_checar(EstiloHUD.cor_do_item("bumerangue").is_equal_approx(
		CatalogoFerramentas.cor("bumerangue")), "ferramenta usa a cor do catalogo")
	_checar(not EstiloHUD.cor_do_item("Cilindro_de_Hidrogenio").is_equal_approx(
		EstiloHUD.cor_do_item("Cilindro_Oxigenio")), "H2 e O2 tem cores diferentes")
	_checar(EstiloHUD.cor_do_item("nao_existe").is_equal_approx(EstiloHUD.ACENTO_PADRAO),
		"item desconhecido cai no acento padrao")

	# Chapeu do popup separa ferramenta de item comum.
	_checar(EstiloHUD.chapeu_do_item("bumerangue") == "FERRAMENTA ADQUIRIDA",
		"ferramenta ganha chapeu de ferramenta")
	_checar(EstiloHUD.chapeu_do_item("carvao_vegetal") == "ITEM COLETADO",
		"item comum ganha chapeu de item")

	# Pixel art: acima de 2x so multiplo inteiro (16x16 numa caixa de 82 -> 5x,
	# e nao 5,125x, que esticaria uma coluna de pixels).
	var arte := ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	_checar(is_equal_approx(EstiloHUD.escala_pixel(arte, 82.0), 5.0),
		"16x16 em caixa de 82 encaixa em 5x inteiro")
	var largo := ImageTexture.create_from_image(Image.create(48, 48, false, Image.FORMAT_RGBA8))
	_checar(EstiloHUD.escala_pixel(largo, 82.0) < 2.0,
		"arte grande usa o ajuste fino (abaixo de 2x nao arredonda)")


# ─────────────────────────────────────────────────────────────
# A ficha, sozinha
# ─────────────────────────────────────────────────────────────

func _testar_ficha_solta() -> void:
	print("\n--- A FICHA SE MEDE PELO TEXTO ---")
	var ficha: PopupItem = (load(POPUP) as PackedScene).instantiate()
	get_tree().root.add_child(ficha)
	await get_tree().process_frame

	_checar(ficha is PopupItem, "a cena do popup e um PopupItem desenhado em _draw")
	_checar(ficha.fonte != null, "a fonte de display esta ligada na cena")
	_checar(not ficha.visible, "a ficha nasce escondida")

	var curta := {"id": "Cilindro_Oxigenio", "nome": "Cilindro de Oxigênio (Comburente)",
		"descricao": "Uma linha só.", "icone": null, "destino": "MOCHILA · SLOT 1"}
	ficha.abrir(curta)
	await get_tree().process_frame
	var caixa_curta: Rect2 = ficha.retangulo_da_ficha()

	var longa := curta.duplicate()
	longa["descricao"] = "Hidrogênio queimando em oxigênio puro: a mesma reação do " \
		+ "foguete, agora na mão dela. A chama passa dos 2000 °C e corta o que está " \
		+ "soldado, e ainda sobra texto para forçar mais uma linha na caixa."
	ficha.abrir(longa)
	await get_tree().process_frame
	var caixa_longa: Rect2 = ficha.retangulo_da_ficha()

	_checar(caixa_longa.size.y > caixa_curta.size.y,
		"descricao mais longa faz a caixa crescer (%.0f -> %.0f)"
			% [caixa_curta.size.y, caixa_longa.size.y])
	_checar(is_equal_approx(caixa_longa.size.x, caixa_curta.size.x),
		"a largura da ficha e fixa: so a altura responde ao texto")

	var tela := ficha.size
	_checar(caixa_longa.position.x >= 0.0 and caixa_longa.end.x <= tela.x,
		"a ficha cabe na largura da tela")
	_checar(caixa_longa.position.y >= 0.0 and caixa_longa.end.y <= tela.y,
		"a ficha cabe na altura da tela mesmo com texto longo")
	_checar(absf(caixa_longa.get_center().x - tela.x * 0.5) < 1.0,
		"a ficha fica centrada na horizontal")

	# O nome mais comprido do jogo nao pode estourar a coluna de texto: o
	# titulo encolhe sozinho ate caber.
	var enorme := curta.duplicate()
	enorme["nome"] = "Maçarico Oxídrico De Precisão Para Corte De Chapa (Ferramenta)"
	ficha.abrir(enorme)
	await get_tree().process_frame
	_checar(is_equal_approx(ficha.retangulo_da_ficha().size.x, PopupItem.LARGURA),
		"nome enorme nao alarga a ficha (o titulo e que encolhe)")

	# O medalhao e o ponto de partida do voo: tem de cair dentro da ficha.
	var centro := ficha.centro_do_medalhao()
	var quadro := ficha.retangulo_da_ficha()
	_checar(quadro.has_point(centro), "o medalhao esta dentro da ficha")
	_checar(centro.x < quadro.get_center().x, "o medalhao fica na coluna da esquerda")

	ficha.queue_free()
	await get_tree().process_frame


# ─────────────────────────────────────────────────────────────
# O caminho inteiro de uma coleta
# ─────────────────────────────────────────────────────────────

func _testar_coleta_completa() -> void:
	print("\n--- COLETA COMPLETA: ABRIR, FECHAR, VOAR, GUARDAR ---")
	var hud: CanvasLayer = (load(HUD) as PackedScene).instantiate()
	get_tree().root.add_child(hud)
	await get_tree().process_frame

	var ficha: PopupItem = hud.get_node("PopupItem")
	var mochila: MochilaHUD = hud.get_node("Mochila")
	_checar(ficha != null and mochila != null, "o HUD traz a ficha e a mochila")

	# A mochila mora no canto superior direito.
	var tela := hud.get_viewport().get_visible_rect().size
	var quadro_mochila := Rect2(mochila.global_position, mochila.size)
	_checar(quadro_mochila.get_center().x > tela.x * 0.5,
		"a mochila fica na metade direita da tela")
	_checar(quadro_mochila.get_center().y < tela.y * 0.5,
		"a mochila fica na metade de cima da tela")
	_checar(quadro_mochila.end.x <= tela.x and quadro_mochila.position.y >= 0.0,
		"a mochila cabe inteira dentro da tela")
	_checar(mochila.ocupados() == 0 and not mochila.esta_cheia(),
		"a mochila comeca vazia, com os %d alveolos a mostra" % MochilaHUD.CAPACIDADE)

	var arte := _arte(16)
	hud.exibir_popup("Cilíndro de Hidrogênio (Combustível)", arte,
		"Quando encontra oxigênio nas condições certas, vira água.",
		"Cilindro_de_Hidrogenio")
	await get_tree().process_frame

	_checar(ficha.visible and ficha.esta_aberto(), "exibir_popup abriu a ficha")
	_checar(Inventario.popup_aberto, "o Interacao sabe que a tela esta com a tecla E")
	_checar(get_tree().paused, "o mundo pausa enquanto a pessoa le")
	_checar(mochila.ocupados() == 0, "o item ainda NAO entrou: quem nao leu nao pegou")

	# O destino aparece no rodape antes de a pessoa fechar.
	_checar(hud._texto_do_destino("Cilindro_de_Hidrogenio", true) == "MOCHILA · SLOT 1",
		"o rodape diz para qual alveolo o item vai")

	# Fecha e acompanha a coreografia ate o fim.
	var chegou := []
	hud.popup_fechado.connect(func(id: String) -> void: chegou.append(id))
	await hud.fechar_popup()

	_checar(chegou.size() == 1 and chegou[0] == "Cilindro_de_Hidrogenio",
		"popup_fechado saiu uma vez, com o id do item")
	_checar(not Inventario.popup_aberto, "a tecla E voltou para o mundo")
	_checar(not get_tree().paused, "o mundo voltou a andar")
	_checar(not ficha.visible, "a ficha saiu da tela")
	_checar(mochila.ocupados() == 1, "o item chegou no alveolo")
	_checar(mochila.indice_de("Cilindro_de_Hidrogenio") == 0, "e chegou no primeiro alveolo")
	_checar(Inventario.tem_item("Cilindro_de_Hidrogenio"),
		"o inventario de verdade so recebeu o item depois da leitura")

	# O alveolo pega a cor do item (e por isso que o voo e a chegada combinam).
	_checar(mochila._slots[0]["cor"].is_equal_approx(
		EstiloHUD.cor_do_item("Cilindro_de_Hidrogenio")),
		"o alveolo acende na cor do item")
	_checar(mochila._slots[0]["titulo"] == "Cilíndro de Hidrogênio",
		"o rotulo do alveolo perde o parentese da categoria")

	_limpar(hud)
	await get_tree().process_frame


# ─────────────────────────────────────────────────────────────
# A mochila
# ─────────────────────────────────────────────────────────────

func _testar_mochila() -> void:
	print("\n--- A MOCHILA (capacidade, entrada direta e saida) ---")
	var hud: CanvasLayer = (load(HUD) as PackedScene).instantiate()
	get_tree().root.add_child(hud)
	await get_tree().process_frame
	var mochila: MochilaHUD = hud.get_node("Mochila")

	# Caminho sem ficha: Inventario.adicionar_item() cai aqui.
	for i in MochilaHUD.CAPACIDADE:
		hud.exibir_item_na_tela("item_%d" % i, "Item %d" % i, _arte(16))
	_checar(mochila.ocupados() == MochilaHUD.CAPACIDADE, "os tres alveolos encheram")
	_checar(mochila.esta_cheia() and mochila.proximo_livre() == -1,
		"mochila cheia se reconhece como cheia")

	# Cheia, o rodape da ficha avisa em vez de mentir um numero de slot.
	_checar(hud._texto_do_destino("novo", true) == "MOCHILA CHEIA",
		"com a mochila cheia o rodape avisa, e nao inventa alveolo")
	hud.exibir_item_na_tela("sobra", "Sobra", _arte(16))
	_checar(mochila.ocupados() == MochilaHUD.CAPACIDADE,
		"item a mais nao entra nem quebra a fileira")

	# Item repetido nao ocupa dois alveolos.
	hud.exibir_item_na_tela("item_1", "Item 1", _arte(16))
	_checar(mochila.ocupados() == MochilaHUD.CAPACIDADE and mochila.indice_de("item_1") == 1,
		"item repetido continua no alveolo dele")

	# Saida: o receptor consumiu o item.
	hud.remover_item_da_tela("item_1")
	await get_tree().create_timer(0.5).timeout
	_checar(not mochila.tem("item_1"), "o alveolo esvaziou quando o item foi usado")
	_checar(mochila.proximo_livre() == 1, "o alveolo liberado volta a ser o proximo da fila")

	# Cada alveolo tem um centro proprio, para o voo saber onde encaixar.
	var a := mochila.centro_do_slot(0)
	var b := mochila.centro_do_slot(2)
	_checar(b.x > a.x and is_equal_approx(a.y, b.y),
		"os alveolos estao numa fileira horizontal, da esquerda para a direita")

	_limpar(hud)
	await get_tree().process_frame


# ─────────────────────────────────────────────────────────────
# Ferramenta
# ─────────────────────────────────────────────────────────────

func _testar_ferramenta() -> void:
	print("\n--- FERRAMENTA: MESMA FICHA, OUTRO DESTINO ---")
	var hud: CanvasLayer = (load(HUD) as PackedScene).instantiate()
	get_tree().root.add_child(hud)
	await get_tree().process_frame
	var mochila: MochilaHUD = hud.get_node("Mochila")

	var dados := CatalogoFerramentas.dados("bumerangue")
	_checar(not dados.is_empty(), "o catalogo entrega a ficha do bumerangue")

	_checar(hud._texto_do_destino("bumerangue", false) == "CINTO DE FERRAMENTAS",
		"o rodape manda a ferramenta para o cinto, nao para a mochila")

	var chegou := []
	hud.popup_fechado.connect(func(id: String) -> void: chegou.append(id))
	hud.exibir_popup(dados["nome"], dados["textura"], dados["descricao"], "bumerangue", false)
	await get_tree().process_frame
	_checar(hud.get_node("PopupItem").visible, "a ferramenta ganha a mesma ficha dos itens")

	await hud.fechar_popup()
	_checar(chegou.size() == 1 and chegou[0] == "bumerangue",
		"popup_fechado saiu com o id da ferramenta (e o selo do cinto nasce nele)")
	_checar(mochila.ocupados() == 0, "ferramenta nao ocupa alveolo da mochila")
	_checar(not get_tree().paused, "o mundo voltou a andar depois da ferramenta")

	# O ponto de chegada do voo existe e fica no canto de baixo a direita.
	var cinto := FerramentasHUD.ponto_de_entrada()
	var tela := hud.get_viewport().get_visible_rect().size
	_checar(cinto.x > tela.x * 0.5 and cinto.y > tela.y * 0.5,
		"o cinto (destino do voo) esta no canto inferior direito")

	_limpar(hud)
	await get_tree().process_frame


func _testar_cinto() -> void:
	print("\n--- O CINTO (canto inferior direito) ---")
	var hud: CanvasLayer = (load(HUD) as PackedScene).instantiate()
	get_tree().root.add_child(hud)
	await get_tree().process_frame

	# A tecla que USA a ferramenta vem do catalogo e bate com o mapa de entrada.
	_checar(CatalogoFerramentas.tecla("bumerangue") == "F", "bumerangue anuncia F")
	# O maçarico não tem botão próprio: ele acende no mesmo E/□ da interação,
	# encostado na chapa soldada ou na porta de metal.
	_checar(CatalogoFerramentas.tecla("macarico") == "E", "macarico anuncia E")
	_checar(CatalogoFerramentas.tecla("botas") == "",
		"ferramenta passiva (botas) nao promete tecla nenhuma")
	var acoes := {"bumerangue": "arremessar", "macarico": "interact",
		"mochila": "dash", "sinalizador": "luz", "lanterna": "lanterna"}
	for h in acoes:
		var acao: String = acoes[h]
		_checar(InputMap.has_action(acao),
			"a acao '%s' (tecla do %s) existe no mapa de entrada" % [acao, h])

	# O destino do voo NAO pode depender de quantas ferramentas ja estao no
	# cinto: a ficha mira nele antes de o alveolo existir.
	var antes := FerramentasHUD.ponto_de_entrada()

	# Caminho de verdade: conquistar a habilidade, ler a ficha, fechar.
	_checar(not FerramentasHUD.tem_no_cinto("bumerangue"),
		"o cinto comeca sem o bumerangue")
	Progresso.dar_habilidade("bumerangue")
	var espera := 0.0
	while not Inventario.popup_aberto and espera < 1.5:
		await get_tree().create_timer(0.05).timeout
		espera += 0.05
	_checar(Inventario.popup_aberto, "conquistar a ferramenta abriu a ficha sozinha")
	await hud.fechar_popup()
	await get_tree().process_frame

	_checar(FerramentasHUD.tem_no_cinto("bumerangue"),
		"fechar a ficha pendurou a ferramenta no cinto")
	_checar(FerramentasHUD.ponto_de_entrada().is_equal_approx(antes),
		"o ponto de entrada do cinto nao se mexe quando uma ferramenta entra")

	# Usar a ferramenta no mundo pulsa o alveolo (nao pode explodir se a
	# ferramenta nem estiver no cinto).
	FerramentasHUD.destacar("bumerangue")
	FerramentasHUD.destacar("nao_existe")
	_checar(true, "destacar() aceita ferramenta ausente sem quebrar")

	_limpar(hud)
	await get_tree().process_frame


# ─────────────────────────────────────────────────────────────

func _arte(lado: int) -> Texture2D:
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)


func _limpar(hud: Node) -> void:
	get_tree().paused = false
	Inventario.popup_aberto = false
	Inventario.itens_coletados.clear()
	hud.queue_free()
