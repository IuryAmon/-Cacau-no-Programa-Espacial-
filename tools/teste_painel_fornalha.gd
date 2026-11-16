extends Node

# Teste do painel da fornalha (scripts/ui/painel_fornalha.gd), da retorta que
# o abre (scripts/fases/retorta.gd) e da porta do forno
# (scripts/fases/porta_da_fornalha.gd), apertando as teclas de verdade:
#
#   * o painel só tem dois textos (título e controles), na fonte dos puzzles,
#     e o título é "Temperatura da Fornalha" com só as iniciais maiúsculas;
#   * o E que acendeu a fornalha, se continuar apertado, não aquece: só vale
#     depois de solto;
#   * segurando E o líquido sobe, solto ele desce; mantido na região, a
#     temperatura está no ponto e o painel fecha sozinho, com sucesso — não
#     existe mais etapa de vedar: a porta do forno não é desta tela;
#   * segurando E direto, o líquido chega no topo e a carga vira cinza
#     (sucesso = false); ESC desiste (cancelado = true);
#   * na fase 1.2, acender a fornalha abre o painel ao lado da Cacau sem tapar
#     a fornalha, e queimar repõe as toras. Resolvido o painel, a fornalha
#     fica pegando fogo À ESPERA da porta: o tempo não passa e o carvão não
#     sai. A porta encostada ao lado só responde ao E nessa espera; apanhada,
#     vai para a mochila, e com ela na mochila o E na fornalha fecha a boca do
#     forno — aí a noite cai, a brasa apaga, a porta volta para o lugar dela e
#     o carvão sai;
#   * com o forno aceso ela não sai do pátio: a passagem da ponta esquerda a
#     segura na beirada e ela diz que precisa terminar o carvão primeiro; com o
#     carvão pronto no forno também não (ela diz que precisa pegá-lo); com o
#     fogo apagado (desistiu, queimou) ou o carvão na mochila, a saída é livre;
#   * o "!" da fornalha guia de longe: chama com lenha na mochila, com o forno
#     cheio e frio, com a porta na mochila e com o carvão pronto; à espera da
#     porta, quem chama é a porta;
#   * se a fase recarregar com o forno à espera (e a porta na mochila), acha
#     tudo como ficou;
#   * demorando para tampar, a Cacau comenta (no Dialogic) que devia tampar o
#     forno — uma vez só, sem mudar nada na espera.
#
#   godot --headless --path . res://tools/teste_painel_fornalha.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma imagem de cada etapa
# na pasta, para conferir o desenho a olho (e roda em tempo real).

const FASE := "res://scenes/fases/fase1_2_exterior.tscn"
const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")
const FALA_DA_PORTA := "Talvez eu deva tampar o forno, evita a entrada de oxigênio"
const FALA_AO_SAIR := "Preciso terminar de fazer o carvão primeiro"
const FALA_SEM_CARVAO := "Eu preciso pegar o carvão antes!"

var _falhas := 0
var _pasta_capturas := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			_pasta_capturas = arg.trim_prefix("--capturas=")
	# Sem capturas, o relógio corre mais rápido: as etapas levam segundos.
	Engine.time_scale = 1.0 if _capturando() else 3.0
	await get_tree().process_frame

	await _testar_textos()
	await _testar_e_ja_apertado()
	await _testar_a_regiao()
	await _testar_aquecer_ate_o_ponto()
	await _testar_superaquecer()
	await _testar_desistir()
	await _testar_na_fase()
	await _testar_a_saida()
	await _testar_recarregar()
	await _testar_a_fala_da_porta()
	Engine.time_scale = 1.0
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


# ─────────────────────────────────────────────────────────────

func _testar_textos() -> void:
	print("\n--- TEXTOS DO PAINEL ---")
	var painel := PainelFornalha.abrir(self)
	await _quadros(3)
	var labels := painel.find_children("*", "Label", true, false)
	_checar(labels.size() == 2, "só dois textos: título e controles (%d)" % labels.size())
	var titulo: Label = painel.find_child("Titulo", true, false)
	var controles: Label = painel.find_child("Controles", true, false)
	_checar(titulo != null and titulo.text.replace("\n", " ") == "Temperatura da Fornalha",
		"título com só as iniciais maiúsculas")
	for label in labels:
		_checar(label.get_theme_font("font") == FONTE, "%s na fonte dos puzzles" % label.name)
	var modelo: String = IconesNoTexto.acoplar(controles).modelo
	_checar(modelo.contains("{interact}") and modelo.contains("Aquecer") and modelo.contains("{fechar}"),
		"controles: E aquece, ESC sai")
	_checar(not modelo.to_lower().contains("frio") and not modelo.to_lower().contains("faixa"),
		"nada de frio/quente/faixa")
	_checar(not modelo.contains("Vedar") and not modelo.contains("ui_down")
		and not painel.has_signal("vedada"), "e nada de vedar: a porta do forno não é desta tela")
	_checar(Interacao.ocupada(), "o painel segura o E")
	await _capturar("1_abertura")
	await _desistir_e_esperar(painel)


func _testar_e_ja_apertado() -> void:
	print("\n--- O E QUE ACENDEU NÃO AQUECE ---")
	Input.action_press("interact")
	var painel := PainelFornalha.abrir(self)
	var inicial := painel.temperatura()
	await _esperar(0.8)
	_checar(painel.temperatura() <= inicial, "E ainda apertado da abertura não esquenta")
	_checar(not painel.soprando(), "e a Cacau não sopra")
	Input.action_release("interact")
	await _quadros(2)
	Input.action_press("interact")
	await _esperar(0.9)
	var subiu := painel.temperatura()
	_checar(subiu > inicial + 0.05, "apertado de novo, sobe (%.2f -> %.2f)" % [inicial, subiu])
	_checar(painel.soprando(), "e a Cacau sopra")
	Input.action_release("interact")
	await _esperar(1.0)
	_checar(painel.temperatura() < subiu, "solto, esfria")
	await _desistir_e_esperar(painel)


## O alvo do termômetro é uma REGIÃO (uma faixa pintada no tubo), não uma
## linha: qualquer altura dentro dela enche a barra.
func _testar_a_regiao() -> void:
	print("\n--- A REGIÃO DO TERMÔMETRO ---")
	var painel := PainelFornalha.abrir(self)
	await _quadros(3)
	var linhas := painel._linhas_da_regiao()
	var altura := linhas.y - linhas.x + 1
	_checar(altura >= 9, "o alvo é uma região, não uma linha (%d linhas do termômetro)" % altura)

	# O que vale é exatamente o que está pintado: cada linha da faixa, e só elas.
	var dentro := true
	for linha in range(linhas.x, linhas.y + 1):
		painel._temperatura = _temperatura_na_linha(linha)
		dentro = dentro and painel._na_regiao()
	_checar(dentro, "qualquer altura dentro dela conta (linhas %d a %d)" % [linhas.x, linhas.y])
	painel._temperatura = _temperatura_na_linha(linhas.x - 1)
	var acima := painel._na_regiao()
	painel._temperatura = _temperatura_na_linha(linhas.y + 1)
	var abaixo := painel._na_regiao()
	_checar(not acima and not abaixo, "uma linha acima ou abaixo dela já não conta")
	var tracos := 0
	for traco in PainelFornalha._tracos:
		if traco[0] >= linhas.x and traco[0] <= linhas.y:
			tracos += 1
	_checar(tracos >= 3, "ela pega vários traços da escala (%d), pintados na cor dela" % tracos)
	var bordas_no_tubo := 0
	for faixa in PainelFornalha._faixas_liquido:
		if (faixa[0] == linhas.x or faixa[0] == linhas.y) and faixa[0] < PainelFornalha._linha_do_bulbo:
			bordas_no_tubo += 1
	_checar(bordas_no_tubo >= 2, "e as duas bordas dela caem no tubo, não no bulbo")
	await _capturar("1a_regiao_vazia")

	# Parado fora dela (logo abaixo), a barra não enche.
	var espera := 0.0
	while espera < 1.2:
		painel._temperatura = _temperatura_na_linha(linhas.y + 2)
		await get_tree().process_frame
		espera += get_process_delta_time()
	_checar(is_zero_approx(painel._progresso_regiao) and painel.etapa() == PainelFornalha.Etapa.AQUECER,
		"com o líquido parado logo abaixo dela, a barra não enche")

	# Parado na BORDA de cima dela — longe do meio —, a barra enche até o fim.
	espera = 0.0
	var capturou := false
	while espera < 5.0 and painel.etapa() == PainelFornalha.Etapa.AQUECER:
		painel._temperatura = _temperatura_na_linha(linhas.x)
		if not capturou and painel._progresso_regiao >= 0.5:
			capturou = true
			await _capturar("1b_na_borda_da_regiao")
		await get_tree().process_frame
		espera += get_process_delta_time()
	_checar(painel.etapa() == PainelFornalha.Etapa.NO_PONTO,
		"com o líquido na borda de cima dela, a barra enche e a temperatura chega no ponto (%.1f s)" % espera)
	await _esperar_fim(painel, 5.0)

	# Passado dela (quente demais), a região continua à vista por cima do líquido.
	painel = PainelFornalha.abrir(self)
	await _quadros(3)
	espera = 0.0
	while espera < 0.6:
		painel._temperatura = _temperatura_na_linha(linhas.x - 12)
		await get_tree().process_frame
		espera += get_process_delta_time()
	_checar(not painel._na_regiao() and painel._nivel() < linhas.x, "acima dela, o líquido cobre a faixa inteira")
	await _capturar("1c_acima_da_regiao")
	await _desistir_e_esperar(painel)


## A temperatura que deixa o topo do líquido numa linha do sprite do termômetro.
func _temperatura_na_linha(linha: int) -> float:
	return float(PainelFornalha.LINHA_VAZIO - linha) \
		/ float(PainelFornalha.LINHA_VAZIO - PainelFornalha.LINHA_CHEIO)


func _testar_aquecer_ate_o_ponto() -> void:
	print("\n--- AQUECER ATÉ A REGIÃO: NO PONTO ---")
	var painel := PainelFornalha.abrir(self)
	var fim := [null, null]
	painel.terminado.connect(func(s: bool, c: bool) -> void: fim[0] = s; fim[1] = c)
	await _quadros(2)
	await _esperar(1.2)
	_checar(not painel._moleculas.is_empty(), "o ar entra pela grade enquanto ela aquece (moléculas de O₂)")

	var chegou := await _levar_ate_a_regiao(painel, 20.0, "1b_na_regiao")
	_checar(chegou, "segurando a temperatura dentro da região, ela chega no ponto")
	if not chegou:
		await _desistir_e_esperar(painel)
		return
	_checar(not painel.soprando(), "a Cacau baixa o maçarico")
	_checar(painel.dicas_do_controle().is_empty(), "no ponto não há mais botão para apertar")
	var no_ponto := painel.temperatura()
	await _capturar("2_no_ponto")

	# Ninguém precisa correr nem apertar mais nada: a tela fecha sozinha.
	var quente_demais := false
	var espera := 0.0
	while is_instance_valid(painel) and espera < 5.0:
		quente_demais = quente_demais or painel.temperatura() > no_ponto + 0.03
		await get_tree().process_frame
		espera += get_process_delta_time()
	_checar(not quente_demais, "no ponto a temperatura não dispara: não há relógio contra a jogadora")
	_checar(fim[0] == true and fim[1] == false, "o painel fecha sozinho, com sucesso (%.1f s)" % espera)
	_checar(not Interacao.ocupada(), "e devolve o E")


func _testar_superaquecer() -> void:
	print("\n--- E SEGURADO DIRETO: QUEIMA ---")
	var painel := PainelFornalha.abrir(self)
	var fim := [null, null]
	var chegou_no_ponto := [false]
	painel.terminado.connect(func(s: bool, c: bool) -> void: fim[0] = s; fim[1] = c)
	await _quadros(2)
	Input.action_press("interact")
	var espera := 0.0
	var virou_cinza := false
	while is_instance_valid(painel) and fim[0] == null and espera < 15.0:
		if painel.etapa() == PainelFornalha.Etapa.NO_PONTO:
			chegou_no_ponto[0] = true
		if painel.etapa() == PainelFornalha.Etapa.CINZAS and not virou_cinza:
			virou_cinza = true
			Input.action_release("interact")
			await _esperar(0.7)
			await _capturar("5_cinzas")
		await get_tree().process_frame
		espera += get_process_delta_time()
	Input.action_release("interact")
	_checar(not chegou_no_ponto[0], "passar direto pela região não conta")
	_checar(virou_cinza and fim[0] == false and fim[1] == false, "o líquido no topo queima a carga")


func _testar_desistir() -> void:
	print("\n--- ESC DESISTE ---")
	var painel := PainelFornalha.abrir(self)
	var fim := [null, null]
	painel.terminado.connect(func(s: bool, c: bool) -> void: fim[0] = s; fim[1] = c)
	await _quadros(3)
	Input.action_press("fechar")
	await _quadros(2)
	Input.action_release("fechar")
	await _esperar_fim(painel, 2.0)
	_checar(fim[0] == false and fim[1] == true, "ESC/△ desiste")


func _testar_na_fase() -> void:
	print("\n--- NA FASE 1.2 ---")
	_zerar_a_partida()
	var fase := await _abrir_fase()
	var retorta: RetortaCarbonizacao = fase.get_node("Patio/Retorta")
	var player: CharacterBody2D = fase.get_node("Player")
	var porta: PortaDaFornalha = retorta.get_node_or_null("Porta")
	var porta_na_boca: Sprite2D = retorta.get_node_or_null("PortaFechada")
	var arvore: ArvoreLenha = fase.get_node("Patio/ArvoreLenha")
	var atmosfera := Atmosfera.da_cena(retorta)
	# A fala da espera tem um teste só dela (mais abaixo).
	retorta.espera_antes_da_dica = 0.0

	_checar(not retorta._exclamacao_visivel, "sem lenha na mochila, a fornalha não chama (quem guia é a lista)")
	_checar(porta != null and porta_na_boca != null, "a fornalha tem a porta encostada ao lado e a porta da boca do forno")
	if porta == null or porta_na_boca == null:
		fase.queue_free()
		await _quadros(2)
		return
	var lugar_da_porta := porta.position
	var meia_fornalha: float = retorta._sprite.sprite_frames.get_frame_texture(&"desligada", 0).get_width() \
		* retorta._sprite.scale.x * 0.5
	_checar(porta.visible and not porta_na_boca.visible and absf(porta.position.x) > meia_fornalha * 0.6,
		"fria, a porta fica AO LADO do forno, não na boca dele (x = %.0f)" % porta.position.x)
	_checar(porta.textura() == porta_na_boca.texture and porta.textura() != null,
		"a porta encostada e a da boca do forno são a mesma arte")
	# A porta da boca fica em cima do fogo (a luz dele mora no meio da boca).
	var chapa := Rect2(porta_na_boca.position - porta_na_boca.texture.get_size() * porta_na_boca.scale * 0.5,
		porta_na_boca.texture.get_size() * porta_na_boca.scale)
	_checar(chapa.has_point(retorta._luz_do_fogo.position) and chapa.size.x >= 40.0,
		"e a da boca cobre a boca do forno, onde fica o fogo %s" % chapa)

	# Antes da hora a porta é só cenário: o E ao lado dela não faz nada.
	await _ficar_em(player, porta.global_position.x)
	_checar(not porta.disponivel and not porta._aviso_visivel, "antes da hora a porta não chama (sem balão)")
	await _apertar_e()
	_checar(porta.visible and not PortaDaFornalha.na_mochila(), "e o E ao lado dela não a apanha")

	for tentativa in 2:
		var queimar := tentativa == 0
		if queimar:
			# A carga que vai virar cinza é lenha de verdade, derrubada da árvore.
			await _abastecer_com_a_arvore(arvore, retorta)
		else:
			retorta._madeiras_no_forno = retorta.madeiras_necessarias
		retorta._atualizar_sprite()
		retorta._tentar_acender()
		var painel := await _esperar_painel(6.0)
		_checar(painel != null, "acender abre o painel da fornalha")
		if painel == null:
			break
		await _esperar(0.4)
		var quadro := Rect2(painel._quadro.position, painel._quadro.size)
		var foco: Rect2 = get_viewport().get_canvas_transform() * painel.foco
		_checar(not quadro.intersects(foco), "o quadro não tapa a fornalha nem a Cacau")
		_checar(quadro.position.y >= 0.0 and quadro.end.y <= 900.0 and quadro.position.x >= 0.0
			and quadro.end.x <= 1600.0, "e cabe na tela")
		var porta_na_tela: Vector2 = get_viewport().get_canvas_transform() * porta.global_position
		_checar(not quadro.has_point(porta_na_tela), "nem tapa a porta encostada ao lado")
		if not queimar:
			await _capturar("6_fase_aquecendo")

		if queimar:
			# Segurando E direto: passa da região, chega no topo e queima.
			Input.action_press("interact")
			await _esperar_fim(painel, 15.0)
			Input.action_release("interact")
			_checar(not retorta._acesa and retorta._madeiras_no_forno == 0, "queimou: forno apagado e vazio")
			_checar(retorta.get_node_or_null("Cinzas") != null, "a cinza sobe da boca do forno")
			_checar(arvore.toras_na_copa() == arvore.toras_por_ciclo
				and get_tree().get_nodes_in_group(Madeira.GRUPO).is_empty(),
				"a lenha queimada volta para a copa da árvore, não para o chão")
			_checar(not retorta._esperando_porta and not porta.disponivel and porta.visible,
				"e a porta continua encostada, sem chamar")
			await _quadros(2)
			continue

		var chegou := await _levar_ate_a_regiao(painel, 20.0)
		_checar(chegou, "chega na região e fica")
		await _esperar_fim(painel, 5.0)

		# No ponto: a fornalha fica pegando fogo, de boca aberta, à espera.
		_checar(retorta._acesa and retorta._esperando_porta and not retorta._carbono_pronto,
			"no ponto, a fornalha segue pegando fogo à espera da porta")
		_checar(is_equal_approx(retorta._sprite.speed_scale, 1.0) and not porta_na_boca.visible,
			"de boca aberta, com as chamas vivas")
		_checar(player.pode_se_mover, "e a Cacau fica solta")
		await _capturar("7_esperando_a_porta")
		await _esperar(4.0)
		_checar(atmosfera != null and atmosfera.pode_anoitecer()
			and atmosfera.momento != Atmosfera.Momento.NOITE and not EstadoMundo.anoiteceu,
			"enquanto a porta não fecha, o tempo não passa")
		_checar(retorta._acesa and not retorta._carbono_pronto
			and retorta._madeiras_no_forno == retorta.madeiras_necessarias,
			"e o carvão não sai: a lenha continua lá dentro, queimando")

		# Sem a porta, o E na fornalha não faz nada — nem reabre o painel.
		await _ficar_em(player, retorta.global_position.x - 90.0)
		_checar(retorta._jogador_perto and not retorta._exclamacao.visible and porta._aviso_visivel,
			"sem a porta na mochila, a fornalha não chama: quem chama é a porta, já de longe")
		await _apertar_e()
		var reabriu := await _esperar_painel(0.4)
		_checar(reabriu == null and retorta._esperando_porta, "e o E nela não faz nada")

		# A porta, agora, chama e se deixa apanhar.
		await _ficar_em(player, porta.global_position.x)
		await _esperar(0.4)
		_checar(porta.disponivel and porta._aviso_visivel, "ao lado da porta, o balão dela aparece")
		await _capturar("8_perto_da_porta")
		await _apertar_e()
		_checar(PortaDaFornalha.na_mochila() and not porta.visible, "E ao lado dela: a porta vai para a mochila")
		var no_icone := false
		for item in Inventario.itens_coletados:
			if item["id"] == PortaDaFornalha.ID and item["textura"] == porta.textura():
				no_icone = true
		_checar(no_icone, "com o desenho dela no ícone")
		_checar(retorta._esperando_porta and not retorta._porta_fechada and retorta._acesa,
			"apanhar a porta ainda não fecha o forno")
		await _esperar(0.4)
		_checar(retorta._exclamacao.visible, "com a porta na mochila, é a fornalha que chama")
		await _capturar("9_porta_na_mochila")

		# Com a porta na mochila, o E na fornalha fecha a boca do forno.
		await _ficar_em(player, retorta.global_position.x - 90.0)
		await _apertar_e()
		_checar(retorta._porta_fechada and not retorta._esperando_porta and not PortaDaFornalha.na_mochila(),
			"com a porta na mochila, E na fornalha tampa o forno")
		await _esperar(0.8)
		_checar(porta_na_boca.visible and porta_na_boca.scale.is_equal_approx(retorta._escala_da_porta)
			and not porta.visible, "a porta está na boca do forno")
		_checar(retorta._acesa and retorta._sprite.speed_scale < 1.0, "tampado, o fogo segue aceso, abafado")
		_checar(retorta._luz_do_fogo.energia < retorta._energia_do_fogo, "e escapa menos luz para o pátio")
		await _capturar("10_tampada")

		# Agora sim o tempo anda: no pátio, a primeira queima que dá certo é a
		# noite caindo — a Cacau olha, parada, e a brasa só apaga com a lua no alto.
		var limite := 6.0
		while limite > 0.0 and player.pode_se_mover:
			await get_tree().process_frame
			limite -= get_process_delta_time()
		_checar(not player.pode_se_mover and atmosfera != null and not atmosfera.pode_anoitecer(),
			"com o forno tampado, a noite cai e a Cacau fica olhando")
		_checar(porta_na_boca.visible and retorta._acesa, "o forno fica tampado enquanto a noite cai")
		limite = 30.0
		while limite > 0.0 and not retorta._carbono_pronto:
			await get_tree().process_frame
			limite -= get_process_delta_time()
		_checar(atmosfera.momento == Atmosfera.Momento.NOITE, "a brasa apaga já de noite")
		_checar(retorta._carbono_pronto, "e o carvão fica pronto para retirar")
		await _quadros(2)
		_checar(retorta._exclamacao_visivel, "e o \"!\" da fornalha chama para retirá-lo")
		_checar(player.pode_se_mover, "a Cacau volta a andar")
		_checar(retorta._sprite.speed_scale == 1.0, "apagada, as chamas voltam ao ritmo normal")
		_checar(not porta_na_boca.visible and porta.visible, "a porta saiu da boca do forno")
		await _esperar(1.0)
		_checar(porta.position.is_equal_approx(lugar_da_porta) and not porta._no_ar
			and is_equal_approx(porta._sprite.rotation, porta._inclinacao),
			"e voltou para o lugar dela, ao lado do forno")
		_checar(not porta.disponivel and retorta._luz_do_fogo.energia == retorta._energia_do_fogo,
			"sem chamar mais, e com a luz do fogo como era")
		await _capturar("11_carvao_pronto")

	await _fechar_fase(fase)


## Com o forno aceso ninguém sai do pátio: a passagem da ponta esquerda segura
## a Cacau na beirada da tela e ela diz por quê — e o carvão pronto também, até
## ela retirá-lo. Com o fogo apagado (antes de acender, depois de desistir ou
## queimar a carga) ou o carvão na mochila, a saída é livre.
func _testar_a_saida() -> void:
	print("\n--- COM O FORNO ACESO NINGUÉM SAI DO PÁTIO ---")
	_zerar_a_partida()
	var fase := await _abrir_fase()
	var retorta: RetortaCarbonizacao = fase.get_node("Patio/Retorta")
	var passagem: PassagemDeCena = fase.get_node("PassagemCorredor")
	var player: CharacterBody2D = fase.get_node("Player")
	var camera: Camera2D = player.get_node("Camera2D")
	var linha: float = passagem.global_position.x
	# A outra fala (a de tampar o forno) não entra na frente desta.
	retorta.espera_antes_da_dica = 0.0

	_checar(retorta.is_in_group(PassagemDeCena.GRUPO_DE_QUEM_SEGURA) and not retorta.segura_a_saida()
		and passagem._quem_segura() == null, "com o forno apagado, nada segura a saída")
	retorta._madeiras_no_forno = retorta.madeiras_necessarias
	retorta._atualizar_sprite()
	_checar(not retorta.segura_a_saida(), "cheio de lenha mas apagado, também não")

	# No ponto e à espera da porta: o fogo está aceso.
	retorta._acesa = true
	retorta._atualizar_sprite()
	retorta._on_painel_terminado(true, false)
	_checar(retorta.segura_a_saida() and passagem._quem_segura() == retorta,
		"aceso (aqui, à espera da porta), o forno segura a saída")

	# Ela anda de verdade para a esquerda, até a beirada.
	await _ficar_em(player, linha + 120.0)
	var fala := await _andar_ate_falar(player, 4.0)
	_checar(not passagem._saindo and is_instance_valid(fase) and fase.is_inside_tree(),
		"andando para a esquerda com o forno aceso, a cena não troca")
	_checar(player.global_position.x >= linha and player.global_position.x < linha + 4.0,
		"ela para na linha da passagem (x = %.1f, linha em %.0f)" % [player.global_position.x, linha])
	_checar(player.global_position.x - 13.0 >= camera.limit_left,
		"ainda inteira dentro da tela")
	_checar(str(fala["texto"]).begins_with(FALA_AO_SAIR), "e fala: \"%s\"" % fala["texto"])
	_checar(fala["retrato"] == "cacau_superneutro", "pensativa (retrato %s)" % fala["retrato"])
	_checar(fala["presa"], "parada enquanto fala")
	await _capturar("13_barrada_na_saida")
	await _passar_as_falas()
	_checar(player.pode_se_mover and not passagem._saindo, "acabou a fala, o controle volta — e ela continua no pátio")
	_checar(retorta._esperando_porta and retorta._acesa, "a fala não muda nada no forno")

	# Insistindo sem se afastar: continua barrada, mas não repete a fala.
	Input.action_press("ui_left")
	await _esperar(1.2)
	Input.action_release("ui_left")
	_checar(Dialogic.current_timeline == null and not passagem._saindo
		and player.global_position.x >= linha, "insistindo ali mesmo, segue barrada, calada")

	# Afastou e voltou: é outra tentativa, e ela explica de novo.
	await _ficar_em(player, linha + 200.0)
	fala = await _andar_ate_falar(player, 4.0)
	_checar(str(fala["texto"]).begins_with(FALA_AO_SAIR) and not passagem._saindo,
		"afastando e tentando de novo, ela fala de novo")
	await _passar_as_falas()

	# Sem a fala configurada ela é barrada do mesmo jeito, calada.
	retorta.fala_ao_sair = ""
	await _ficar_em(player, linha + 200.0)
	Input.action_press("ui_left")
	await _esperar(1.5)
	Input.action_release("ui_left")
	_checar(Dialogic.current_timeline == null and not passagem._saindo
		and player.global_position.x >= linha and player.pode_se_mover,
		"com a fala vazia no Inspector, é barrada calada")
	retorta.fala_ao_sair = "cacau_terminar_carvao"

	# Com a porta fechada o fogo segue aceso lá dentro: ainda não sai.
	retorta._porta.apanhar()
	retorta._fechar_a_porta()
	_checar(retorta._porta_fechada and retorta.segura_a_saida(),
		"com o forno tampado e a brasa ainda acesa, continua sem sair")
	var limite := 40.0
	while limite > 0.0 and not retorta._carbono_pronto:
		await get_tree().process_frame
		limite -= get_process_delta_time()
	_checar(retorta._carbono_pronto and retorta.segura_a_saida() and passagem._quem_segura() == retorta,
		"a brasa apagou e o carvão saiu, mas está no forno: sem ele, ainda não sai")
	await _ficar_em(player, linha + 200.0)
	fala = await _andar_ate_falar(player, 4.0)
	_checar(str(fala["texto"]).begins_with(FALA_SEM_CARVAO) and not passagem._saindo,
		"e ela diz que precisa pegar o carvão: \"%s\"" % fala["texto"])
	await _passar_as_falas()
	# A ficha do carvão (a que pausa esperando um E) fica de fora.
	var hud_do_inventario := Inventario.tela_hud_referencia
	Inventario.tela_hud_referencia = null
	retorta._retirar_carbono()
	Inventario.tela_hud_referencia = hud_do_inventario
	_checar(not retorta.segura_a_saida() and passagem._quem_segura() == null,
		"com o carvão na mochila, a saída está livre de novo")
	await _fechar_fase(fase)

	# Desistir no painel ou queimar a carga apaga o fogo: a saída volta.
	_zerar_a_partida()
	fase = await _abrir_fase()
	retorta = fase.get_node("Patio/Retorta")
	retorta._madeiras_no_forno = retorta.madeiras_necessarias
	retorta._acesa = true
	retorta._atualizar_sprite()
	_checar(retorta.segura_a_saida(), "com o fogo aceso no meio da temperatura, não sai")
	retorta._on_painel_terminado(false, true)
	_checar(not retorta.segura_a_saida(), "desistindo no painel o fogo apaga, e a saída fica livre")
	retorta._acesa = true
	retorta._on_painel_terminado(false, false)
	_checar(not retorta.segura_a_saida(), "queimando a carga também")
	await _fechar_fase(fase)


## Segura a tecla de andar para a esquerda até a Cacau começar a falar (ou o
## tempo acabar). Devolve o texto, o retrato e se ela ficou parada falando.
func _andar_ate_falar(player: CharacterBody2D, limite: float) -> Dictionary:
	var cacau := load("res://timelines/cacau.dch") as DialogicCharacter
	var fala := {"texto": "", "retrato": "", "presa": false}
	Input.action_press("ui_left")
	var espera := 0.0
	while espera < limite and str(fala["texto"]) == "":
		await get_tree().process_frame
		espera += get_process_delta_time()
		if Dialogic.current_timeline == null:
			continue
		fala["presa"] = not player.pode_se_mover
		fala["texto"] = str(Dialogic.current_state_info.get("text", ""))
		if Dialogic.Portraits.is_character_joined(cacau):
			fala["retrato"] = str(Dialogic.current_state_info["portraits"][cacau.resource_path].get("portrait", ""))
	Input.action_release("ui_left")
	return fala


## Passa as falas que estiverem no ar até a conversa acabar.
func _passar_as_falas() -> void:
	var espera := 0.0
	while Dialogic.current_timeline != null and espera < 8.0:
		Dialogic.Inputs.handle_input()
		await get_tree().process_frame
		espera += get_process_delta_time()
	await _quadros(3)


## Sair andando com o forno aceso não dá mais (ver _testar_a_saida), mas a fase
## ainda pode recarregar com ele no ponto e de boca aberta — inclusive com a
## porta já na mochila. Na volta o forno continua pegando fogo à espera.
func _testar_recarregar() -> void:
	print("\n--- A FASE RECARREGA COM O FORNO À ESPERA ---")
	_zerar_a_partida()
	var fase := await _abrir_fase()
	var retorta: RetortaCarbonizacao = fase.get_node("Patio/Retorta")
	var porta: PortaDaFornalha = retorta.get_node("Porta")
	retorta.espera_antes_da_dica = 0.0
	retorta._madeiras_no_forno = retorta.madeiras_necessarias
	retorta._guardar_carga()
	retorta._acesa = true
	retorta._atualizar_sprite()
	retorta._on_painel_terminado(true, false)
	porta.apanhar()
	await _fechar_fase(fase)

	fase = await _abrir_fase()
	retorta = fase.get_node("Patio/Retorta")
	porta = retorta.get_node("Porta")
	var player: CharacterBody2D = fase.get_node("Player")
	retorta.espera_antes_da_dica = 0.0
	_checar(retorta._esperando_porta and retorta._acesa and retorta._sprite.animation == &"ligada",
		"na volta, o forno continua pegando fogo à espera da porta")
	_checar(not porta.visible and PortaDaFornalha.na_mochila(),
		"e a porta, que foi com ela na mochila, não está mais encostada")
	await _ficar_em(player, retorta.global_position.x - 90.0)
	await _apertar_e()
	_checar(retorta._porta_fechada and not PortaDaFornalha.na_mochila(), "ela tampa o forno com a porta que trouxe")
	await _fechar_fase(fase)

	# Fechou e a fase recarregou antes de a brasa apagar: o carvão espera, a
	# porta no lugar.
	fase = await _abrir_fase()
	retorta = fase.get_node("Patio/Retorta")
	porta = retorta.get_node("Porta")
	_checar(retorta._carbono_pronto and not retorta._esperando_porta and not retorta._acesa,
		"recarregando com o forno já tampado, na volta o carvão está esperando")
	_checar(porta.visible and not porta.disponivel and not retorta.get_node("PortaFechada").visible,
		"e a porta está de volta ao lugar")
	await _fechar_fase(fase)


func _testar_a_fala_da_porta() -> void:
	print("\n--- DEMOROU PARA TAMPAR: A CACAU FALA ---")
	_zerar_a_partida()
	var fase := await _abrir_fase()
	var retorta: RetortaCarbonizacao = fase.get_node("Patio/Retorta")
	var player: CharacterBody2D = fase.get_node("Player")
	_checar(retorta.espera_antes_da_dica >= 8.0, "a fala só vem depois de um bom tempo (%.0f s)" % retorta.espera_antes_da_dica)
	retorta.espera_antes_da_dica = 3.0

	# Antes do ponto ninguém fala nada, por mais que o fogo fique aceso.
	retorta._madeiras_no_forno = retorta.madeiras_necessarias
	retorta._acesa = true
	retorta._atualizar_sprite()
	await _esperar(4.0)
	_checar(Dialogic.current_timeline == null, "com o fogo aceso mas fora do ponto, ela não fala")

	retorta._on_painel_terminado(true, false)
	await _esperar(1.5)
	_checar(Dialogic.current_timeline == null and player.pode_se_mover, "no ponto, antes de demorar, ela ainda não fala")

	var falou := false
	var texto := ""
	var retrato := ""
	var presa := true
	var cacau := load("res://timelines/cacau.dch") as DialogicCharacter
	var espera := 0.0
	var capturou := false
	while espera < 12.0 and not (falou and Dialogic.current_timeline == null):
		await get_tree().process_frame
		espera += get_process_delta_time()
		if Dialogic.current_timeline == null:
			continue
		falou = true
		presa = presa and not player.pode_se_mover
		if str(Dialogic.current_state_info.get("text", "")) != "":
			texto = str(Dialogic.current_state_info.get("text", ""))
			if Dialogic.Portraits.is_character_joined(cacau):
				retrato = str(Dialogic.current_state_info["portraits"][cacau.resource_path].get("portrait", ""))
			if not capturou and _capturando():
				capturou = true
				await _esperar(2.0)
				await _capturar("12_fala_da_porta")
		Dialogic.Inputs.handle_input()
	_checar(falou and Dialogic.current_timeline == null, "demorando, a Cacau fala sozinha (%.1f s)" % espera)
	_checar(texto.begins_with(FALA_DA_PORTA), "a fala: \"%s\"" % texto)
	_checar(retrato == "cacau_superneutro", "pensativa (retrato %s)" % retrato)
	_checar(presa, "parada enquanto fala")
	await _quadros(3)
	_checar(player.pode_se_mover, "e o controle volta")
	_checar(retorta._esperando_porta and retorta._acesa and not retorta._carbono_pronto,
		"a fala não muda nada: o forno segue à espera")

	await _esperar(5.0)
	_checar(Dialogic.current_timeline == null, "ela fala uma vez só")
	await _fechar_fase(fase)


# ─────────────────────────────────────────────────────────────

## Segura E enquanto o líquido está abaixo do meio da região e solta acima, até a
## temperatura chegar no ponto (ou o tempo acabar).
func _levar_ate_a_regiao(painel: PainelFornalha, limite: float, captura: String = "") -> bool:
	var alvo := painel._temperatura_da_regiao()
	var espera := 0.0
	while is_instance_valid(painel) and painel.etapa() == PainelFornalha.Etapa.AQUECER and espera < limite:
		if captura != "" and painel._progresso_regiao >= 0.5:
			await _capturar(captura)
			captura = ""
		if painel.temperatura() < alvo - 0.025:
			Input.action_press("interact")
		else:
			Input.action_release("interact")
		await get_tree().process_frame
		espera += get_process_delta_time()
	Input.action_release("interact")
	return is_instance_valid(painel) and painel.etapa() == PainelFornalha.Etapa.NO_PONTO


## Derruba as toras da árvore do pátio, recolhe e põe todas na fornalha.
func _abastecer_com_a_arvore(arvore: ArvoreLenha, retorta: RetortaCarbonizacao) -> void:
	for i in arvore.toras_por_ciclo:
		arvore.atingir_bumerangue()
		await _esperar(0.25)
	await _esperar(1.0)
	for tora in get_tree().get_nodes_in_group(Madeira.GRUPO):
		tora.coletar()
	await _quadros(2)
	_checar(retorta._exclamacao_visivel, "com lenha na mochila, o \"!\" da fornalha chama para pôr a lenha")
	for i in retorta.madeiras_necessarias:
		retorta._abastecer()
	_checar(retorta._cheia() and arvore.toras_na_copa() == 0,
		"a fornalha enche com a lenha que caiu da árvore")
	await _quadros(2)
	_checar(retorta._exclamacao_visivel, "cheia e fria, o \"!\" segue lá: agora é acender")


## A partida do zero: nada na mochila, nada lembrado, antes de anoitecer.
func _zerar_a_partida() -> void:
	for item in Inventario.itens_coletados.duplicate():
		Inventario.remover_item(str(item["id"]))
	EstadoMundo._feitos.clear()
	EstadoMundo._valores.clear()
	EstadoMundo.sol_se_pos = true
	EstadoMundo.anoiteceu = false
	# Direto no dicionário: o dar_habilidade abre a ficha de coleta, que pausa
	# o jogo esperando um E.
	Progresso._habilidades["macarico"] = true
	# O carvão de uma rodada anterior (ver _testar_a_saida) não fica na mochila.
	Progresso._amostras.erase("C")
	Progresso._celulas.erase("C")


func _abrir_fase() -> Node:
	var fase: Node = (load(FASE) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(fase)
	await _quadros(2)
	await get_tree().physics_frame
	await _esperar(0.5)
	return fase


func _fechar_fase(fase: Node) -> void:
	fase.queue_free()
	await _quadros(2)


## Põe a Cacau de pé no chão em `x` e espera as áreas perceberem.
func _ficar_em(player: CharacterBody2D, x: float) -> void:
	player.global_position.x = x
	player.velocity = Vector2.ZERO
	for i in 4:
		await get_tree().physics_frame
	await get_tree().process_frame


## Um toque de E de verdade (o mesmo caminho do teclado: Interacao.pediu()).
func _apertar_e() -> void:
	await get_tree().process_frame
	Input.action_press("interact")
	await _quadros(2)
	Input.action_release("interact")
	await _quadros(2)


func _esperar_painel(limite: float) -> PainelFornalha:
	var espera := 0.0
	while espera < limite:
		for filho in get_tree().root.get_children():
			if filho is PainelFornalha:
				return filho
		await get_tree().process_frame
		espera += get_process_delta_time()
	return null


func _esperar_fim(painel: PainelFornalha, limite: float) -> void:
	var espera := 0.0
	while is_instance_valid(painel) and espera < limite:
		await get_tree().process_frame
		espera += get_process_delta_time()


func _desistir_e_esperar(painel: PainelFornalha) -> void:
	painel._fechar(false, true)
	await _esperar_fim(painel, 2.0)


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos, true).timeout


func _capturando() -> bool:
	return not _pasta_capturas.is_empty() and DisplayServer.get_name() != "headless"


func _capturar(nome: String) -> void:
	if not _capturando():
		return
	await RenderingServer.frame_post_draw
	var imagem := get_viewport().get_texture().get_image()
	imagem.save_png(_pasta_capturas.path_join(nome + ".png"))
