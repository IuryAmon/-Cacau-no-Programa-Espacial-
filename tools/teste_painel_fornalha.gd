extends Node

# Teste do painel da fornalha (scripts/ui/painel_fornalha.gd) e da retorta que
# o abre (scripts/fases/retorta.gd), apertando as teclas de verdade:
#
#   * o painel só tem dois textos (título e controles), na fonte dos puzzles,
#     e o título é "Temperatura da Fornalha" com só as iniciais maiúsculas;
#   * o E que acendeu a fornalha, se continuar apertado, não aquece: só vale
#     depois de solto;
#   * segurando E o líquido sobe, solto ele desce; na marca, a etapa passa a
#     ser vedar e os controles trocam para o S;
#   * na etapa de vedar a temperatura sobe sozinha (o ar entrando); S fecha a
#     comporta, emite "vedada" e o painel fecha com sucesso;
#   * sem vedar, ou segurando E direto, o líquido chega no topo e a carga vira
#     cinza (sucesso = false); ESC desiste (cancelado = true);
#   * na fase 1.2, acender a fornalha abre o painel ao lado da Cacau sem tapar
#     a fornalha; vedar deixa o carvão pronto e queimar repõe as toras.
#
#   godot --headless --path . res://tools/teste_painel_fornalha.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma imagem de cada etapa
# na pasta, para conferir o desenho a olho (e roda em tempo real).

const FASE := "res://scenes/fases/fase1_2_exterior.tscn"
const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

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
	await _testar_aquecer_e_vedar()
	await _testar_sem_vedar_vira_cinza()
	await _testar_superaquecer()
	await _testar_desistir()
	await _testar_na_fase()
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


func _testar_aquecer_e_vedar() -> void:
	print("\n--- AQUECER ATÉ A MARCA E VEDAR ---")
	var painel := PainelFornalha.abrir(self)
	var fim := [null, null]
	var vedou := [false]
	painel.terminado.connect(func(s: bool, c: bool) -> void: fim[0] = s; fim[1] = c)
	painel.vedada.connect(func() -> void: vedou[0] = true)
	await _quadros(2)

	var chegou := await _levar_ate_a_marca(painel, 20.0, "1b_na_marca")
	_checar(chegou, "segurando a temperatura na marca, passa para vedar")
	if not chegou:
		await _desistir_e_esperar(painel)
		return
	var controles: Label = painel.find_child("Controles", true, false)
	var modelo: String = IconesNoTexto.acoplar(controles).modelo
	_checar(modelo.contains("{ui_down:S}") and modelo.contains("Vedar"), "controles trocam para S vedar")
	_checar(not painel.soprando(), "a Cacau baixa o maçarico")
	_checar(painel.dicas_do_controle()[0][0] == "ui_down", "no controle, o direcional para baixo veda")

	var na_marca := painel.temperatura()
	await _esperar(1.0)
	_checar(painel.temperatura() > na_marca + 0.03,
		"com o ar entrando a temperatura sobe sozinha (%.2f -> %.2f)" % [na_marca, painel.temperatura()])
	await _capturar("2_vedar")

	Input.action_press("ui_down")
	await _esperar(0.25)
	await _capturar("3_comporta_descendo")
	var espera := 0.0
	while is_instance_valid(painel) and painel.etapa() == PainelFornalha.Etapa.VEDAR and espera < 3.0:
		await get_tree().process_frame
		espera += get_process_delta_time()
	Input.action_release("ui_down")
	_checar(vedou[0], "segurando S a comporta fecha e o painel avisa (vedada)")
	await _capturar("4_vedada")
	await _esperar_fim(painel, 5.0)
	_checar(fim[0] == true and fim[1] == false, "fecha com sucesso")
	_checar(not Interacao.ocupada(), "e devolve o E")


func _testar_sem_vedar_vira_cinza() -> void:
	print("\n--- SEM VEDAR, VIRA CINZA ---")
	var painel := PainelFornalha.abrir(self)
	var fim := [null, null]
	painel.terminado.connect(func(s: bool, c: bool) -> void: fim[0] = s; fim[1] = c)
	await _quadros(2)
	var chegou := await _levar_ate_a_marca(painel, 20.0)
	_checar(chegou, "chegou na marca")
	var espera := 0.0
	while is_instance_valid(painel) and painel.etapa() == PainelFornalha.Etapa.VEDAR and espera < 12.0:
		await get_tree().process_frame
		espera += get_process_delta_time()
	_checar(is_instance_valid(painel) and painel.etapa() == PainelFornalha.Etapa.CINZAS,
		"sem vedar, a temperatura dispara e a carga queima (%.1f s)" % espera)
	await _esperar(0.7)
	await _capturar("5_cinzas")
	await _esperar_fim(painel, 5.0)
	_checar(fim[0] == false and fim[1] == false, "fecha sem sucesso e sem ser desistência")


func _testar_superaquecer() -> void:
	print("\n--- E SEGURADO DIRETO: QUEIMA ---")
	var painel := PainelFornalha.abrir(self)
	var fim := [null, null]
	var passou_para_vedar := [false]
	painel.terminado.connect(func(s: bool, c: bool) -> void: fim[0] = s; fim[1] = c)
	await _quadros(2)
	Input.action_press("interact")
	var espera := 0.0
	while is_instance_valid(painel) and fim[0] == null and espera < 15.0:
		if painel.etapa() == PainelFornalha.Etapa.VEDAR:
			passou_para_vedar[0] = true
		await get_tree().process_frame
		espera += get_process_delta_time()
	Input.action_release("interact")
	_checar(not passou_para_vedar[0], "passar direto pela marca não conta")
	_checar(fim[0] == false and fim[1] == false, "o líquido no topo queima a carga")


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
	var fase: Node = (load(FASE) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(fase)
	await _quadros(2)
	await get_tree().physics_frame
	await _esperar(0.5)

	var retorta: RetortaCarbonizacao = fase.get_node("Patio/Retorta")
	var player: Node2D = fase.get_node("Player")
	# Direto no dicionário: o dar_habilidade abre a ficha de coleta, que pausa
	# o jogo esperando um E.
	Progresso._habilidades["macarico"] = true
	var arvore: ArvoreLenha = fase.get_node("Patio/ArvoreLenha")
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
		if not queimar:
			await _capturar("6_fase_aquecendo")

		var chegou := await _levar_ate_a_marca(painel, 20.0)
		_checar(chegou, "chega na marca")
		if queimar:
			await _esperar_fim(painel, 12.0)
			_checar(not retorta._acesa and retorta._madeiras_no_forno == 0, "queimou: forno apagado e vazio")
			_checar(retorta.get_node_or_null("Cinzas") != null, "a cinza sobe da boca do forno")
			_checar(arvore.toras_na_copa() == arvore.toras_por_ciclo
				and get_tree().get_nodes_in_group(Madeira.GRUPO).is_empty(),
				"a lenha queimada volta para a copa da árvore, não para o chão")
			await _quadros(2)
			continue

		await _capturar("7_fase_vedar")
		Input.action_press("ui_down")
		await _esperar_fim(painel, 5.0)
		Input.action_release("ui_down")
		_checar(retorta._acesa, "vedada: a brasa continua acesa um tempo")
		_checar(retorta._sprite.speed_scale < 1.0, "com as chamas abafadas")
		_checar(player.pode_se_mover, "a Cacau volta a andar")
		await _esperar(RetortaCarbonizacao.BRASA_APOS_CONCLUIR + 0.5)
		_checar(retorta._carbono_pronto, "e o carvão fica pronto para retirar")
		_checar(retorta._sprite.speed_scale == 1.0, "apagada, as chamas voltam ao ritmo normal")

	fase.queue_free()
	await _quadros(2)


# ─────────────────────────────────────────────────────────────

## Segura E enquanto o líquido está abaixo da marca e solta acima dela, até a
## etapa virar "vedar" (ou o tempo acabar).
func _levar_ate_a_marca(painel: PainelFornalha, limite: float, captura: String = "") -> bool:
	var alvo := painel._temperatura_da_marca()
	var espera := 0.0
	while is_instance_valid(painel) and painel.etapa() == PainelFornalha.Etapa.AQUECER and espera < limite:
		if captura != "" and painel._progresso_marca >= 0.5:
			await _capturar(captura)
			captura = ""
		if painel.temperatura() < alvo - 0.025:
			Input.action_press("interact")
		else:
			Input.action_release("interact")
		await get_tree().process_frame
		espera += get_process_delta_time()
	Input.action_release("interact")
	return is_instance_valid(painel) and painel.etapa() == PainelFornalha.Etapa.VEDAR


## Derruba as toras da árvore do pátio, recolhe e põe todas na fornalha.
func _abastecer_com_a_arvore(arvore: ArvoreLenha, retorta: RetortaCarbonizacao) -> void:
	for i in arvore.toras_por_ciclo:
		arvore.atingir_bumerangue()
		await _esperar(0.25)
	await _esperar(1.0)
	for tora in get_tree().get_nodes_in_group(Madeira.GRUPO):
		tora.coletar()
	for i in retorta.madeiras_necessarias:
		retorta._abastecer()
	_checar(retorta._cheia() and arvore.toras_na_copa() == 0,
		"a fornalha enche com a lenha que caiu da árvore")


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
