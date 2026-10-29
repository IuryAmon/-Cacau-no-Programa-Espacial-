extends "res://tools/teste_de_tela.gd"

# Teste do menu de pausa (scripts/pausa.gd e scripts/ui/tela_de_pausa.gd),
# andando pelo jogo de verdade, numa fase com a Cacau (a oficina da fase 1):
#
#   * ESC e START abrem a pausa e param o jogo; ESC, START, ○ e △ fecham, e o
#     toque que fecha não reabre nem vira ação da Cacau (o ✕ não pula);
#   * a tela tem CONTINUAR, REINICIAR e MENU INICIAL, e as teclas e o
#     direcional levam o foco entre eles;
#   * a pausa não abre sem a Cacau (o menu inicial), por cima do caderno (o ESC
#     que fecha o caderno não abre a pausa), com a Cacau morta, numa cutscene,
#     no congelamento do dash nem no meio da cortina de uma porta; um pedido
#     feito nessas horas abre a pausa se a hora passar logo;
#   * REINICIAR recomeça do último checkpoint, com o jogo andando;
#   * MENU INICIAL volta para a tela de título, sem os equipamentos da Cacau
#     no canto.
#
#   godot --headless --path . res://tools/teste_pausa.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva uma imagem da pausa.

const CENA_MENU := "res://scenes/menu_principal.tscn"
const FASE := "res://scenes/fases/fase1_oficina.tscn"
## As cortinas passam mais depressa enquanto o teste espera por elas.
const PRESSA := 4.0


func _ready() -> void:
	await _comecar()
	_testar_o_projeto()
	await _testar_sem_a_cacau()
	var fase := await _abrir_a_fase()
	if fase != null:
		await _testar_abrir_e_fechar()
		await _testar_o_foco()
		await _testar_quando_nao_abre()
		await _testar_reiniciar()
		await _testar_menu_inicial()
	_terminar()


# ─────────────────────────────────────────────────────────────
# APOIO
# ─────────────────────────────────────────────────────────────

func _cacau() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D


func _tela() -> TelaDePausa:
	return Pausa._tela if Pausa.aberta() else null


## Abre a fase como cena atual, com a Cacau livre (sem fala na tela).
func _abrir_a_fase() -> Node:
	var fase := await _trocar_de_cena(FASE)
	_calar_o_radio(fase)
	await _quadros(10)
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()
		await _quadros(5)
	var cacau := _cacau()
	_checar(fase != null and cacau != null and fase.is_ancestor_of(cacau), "a fase abriu com a Cacau")
	if cacau == null:
		return null
	await _esperar_ate(func() -> bool: return Pausa.pode_abrir(), 5.0)
	_checar(Pausa.pode_abrir(), "com a Cacau livre na fase, a pausa pode abrir")
	return fase


## O rádio do Dr. Chico chama sozinho pouco depois de ela chegar, e a fala
## seguraria a pausa no meio do teste. Ele tem o teste dele (teste_radio).
func _calar_o_radio(fase: Node) -> void:
	var nos: Array[Node] = [fase]
	while not nos.is_empty():
		var no: Node = nos.pop_back()
		if no is RadioComunicacao:
			no.queue_free()
		else:
			nos.append_array(no.get_children())


func _esperar_a_cortina() -> void:
	Engine.time_scale = PRESSA
	await _esperar_ate(func() -> bool: return not TransicaoDeCena.em_curso(), 20.0)
	Engine.time_scale = 1.0
	await _quadros(3)


# ─────────────────────────────────────────────────────────────
# OS TESTES
# ─────────────────────────────────────────────────────────────

func _testar_o_projeto() -> void:
	print("\n--- PROJETO ---")
	var tecla := false
	var start := false
	for evento in InputMap.action_get_events(Pausa.ACAO):
		tecla = tecla or (evento is InputEventKey and evento.keycode == KEY_ESCAPE)
		start = start or (evento is InputEventJoypadButton and evento.button_index == JOY_BUTTON_START)
	_checar(tecla and start, "a ação \"pausar\" é o ESC e o START")
	_checar(Pausa.ACAO in Interacao.ACOES_DO_MUNDO, "um ESC apertado em cima de uma tela fica preso a ela")
	var textos: Array = [TelaDePausa.TXT_TITULO]
	for opcao: Dictionary in TelaDePausa.OPCOES:
		textos.append(opcao["nome"])
		textos.append(opcao["descricao"])
	var faltando := _letras_que_faltam(textos)
	_checar(faltando.is_empty(), "a fonte do jogo tem todas as letras da pausa%s" % ("" if faltando.is_empty() else " (faltam: %s)" % faltando))


func _testar_sem_a_cacau() -> void:
	print("\n--- SEM A CACAU ---")
	var menu := await _trocar_de_cena(CENA_MENU)
	await _quadros(3)
	await _teclar(KEY_ESCAPE)
	await _tocar_no_controle(JOY_BUTTON_START)
	_checar(not Pausa.aberta() and not get_tree().paused, "no menu inicial, ESC e START não abrem a pausa")
	await _voltar_ao_teclado()
	_checar(not FerramentasHUD._ancora.visible, "no menu inicial os equipamentos da Cacau não aparecem")
	if menu != null:
		menu.queue_free()
	await _quadros(3)


func _testar_abrir_e_fechar() -> void:
	print("\n--- ABRIR E FECHAR ---")
	var cacau := _cacau()
	_checar(FerramentasHUD._ancora.visible, "na fase os equipamentos aparecem")
	await _teclar(KEY_ESCAPE)
	_checar(Pausa.aberta() and get_tree().paused, "ESC abre a pausa e para o jogo")
	var tela := _tela()
	if tela == null:
		return
	_checar(Array(tela.nomes_dos_alvos()) == ["continuar", "reiniciar", "menu"],
		"os botões são CONTINUAR, REINICIAR e MENU INICIAL (%s)" % [tela.nomes_dos_alvos()])
	_checar(tela.alvo_em_foco() == "continuar", "o foco começa no CONTINUAR")
	_checar(tela.get_parent() is CanvasLayer and (tela.get_parent() as CanvasLayer).layer == Pausa.CAMADA,
		"a tela fica na camada dela, por cima do jogo")
	var onde := cacau.global_position
	await _quadros(10)
	_checar(cacau.global_position == onde, "com a pausa aberta, a Cacau não sai do lugar")
	await _quadros(12)
	await _foto("pausa")
	await _teclar(KEY_ESCAPE)
	_checar(not Pausa.aberta() and not get_tree().paused, "ESC de novo fecha a pausa e o jogo segue")
	await _quadros(4)
	_checar(not Pausa.aberta(), "o ESC que fechou não reabre a pausa")

	await _tocar_no_controle(JOY_BUTTON_START)
	_checar(Pausa.aberta(), "START abre a pausa")
	await _tocar_no_controle(JOY_BUTTON_START)
	_checar(not Pausa.aberta() and not get_tree().paused, "START de novo fecha")
	await _tocar_no_controle(JOY_BUTTON_START)
	await _tocar_no_controle(JOY_BUTTON_B)
	_checar(not Pausa.aberta(), "○ fecha a pausa")
	await _tocar_no_controle(JOY_BUTTON_START)
	await _tocar_no_controle(JOY_BUTTON_Y)
	_checar(not Pausa.aberta() and not Caderno.aberto(), "△ fecha a pausa e não abre o caderno")
	await _tocar_no_controle(JOY_BUTTON_START)
	_botao_do_controle(JOY_BUTTON_A, true)
	await _quadros(2)
	_checar(not Pausa.aberta(), "✕ em CONTINUAR fecha a pausa")
	_checar(Interacao.toque_preso(&"jump") and not Interacao.livre_para(&"jump"),
		"e o ✕ que apertou CONTINUAR não vira pulo")
	_botao_do_controle(JOY_BUTTON_A, false)
	await _quadros(3)
	await _voltar_ao_teclado()

	await _teclar(KEY_ESCAPE)
	var tela2 := _tela()
	if tela2 != null:
		await _clicar(tela2, "continuar")
	_checar(not Pausa.aberta() and not get_tree().paused, "o clique em CONTINUAR fecha a pausa")
	await _quadros(3)


func _testar_o_foco() -> void:
	print("\n--- O FOCO ---")
	await _teclar(KEY_ESCAPE)
	var tela := _tela()
	if tela == null:
		_checar(false, "a pausa abriu")
		return
	await _teclar(KEY_S)
	_checar(tela.alvo_em_foco() == "reiniciar", "S leva o foco para o REINICIAR")
	await _teclar(KEY_DOWN)
	_checar(tela.alvo_em_foco() == "menu", "↓ leva para o MENU INICIAL")
	await _teclar(KEY_W)
	_checar(tela.alvo_em_foco() == "reiniciar", "W volta para o REINICIAR")
	_botao_do_controle(JOY_BUTTON_DPAD_UP, true)
	await _quadros(3)
	_botao_do_controle(JOY_BUTTON_DPAD_UP, false)
	await _quadros(3)
	_checar(tela.alvo_em_foco() == "continuar", "o direcional para cima volta para o CONTINUAR")
	await _teclar(KEY_E)
	_checar(not Pausa.aberta() and not get_tree().paused, "E em CONTINUAR fecha a pausa")
	await _voltar_ao_teclado()
	await _quadros(3)


func _testar_quando_nao_abre() -> void:
	print("\n--- QUANDO A PAUSA NÃO ABRE ---")
	var cacau := _cacau()

	# O ícone do caderno some com a pausa aberta e volta aos poucos.
	await _esperar_ate(func() -> bool: return Caderno.pode_abrir(), 5.0)
	await _teclar(KEY_M)
	_checar(Caderno.aberto(), "M abre o caderno")
	await _teclar(KEY_ESCAPE)
	await _quadros(4)
	_checar(not Caderno.aberto() and not Pausa.aberta(), "o ESC que fecha o caderno não abre a pausa")
	await _esperar_ate(func() -> bool: return not get_tree().paused and Caderno._abertura <= 0.0, 3.0)
	await _quadros(3)

	cacau.current_health = 0
	await _teclar(KEY_ESCAPE)
	await _quadros(3)
	_checar(not Pausa.aberta(), "com a Cacau morta a pausa não abre")
	cacau.current_health = cacau.max_health
	await _quadros(3)
	_checar(not Pausa.aberta(), "e o pedido feito na morte cai (renascer não abre a pausa)")

	cacau.pode_se_mover = false
	await _teclar(KEY_ESCAPE)
	await _quadros(3)
	_checar(not Pausa.aberta(), "numa cutscene (a Cacau sem se mexer) a pausa não abre")
	cacau.pode_se_mover = true
	await _quadros(3)
	_checar(Pausa.aberta(), "mas abre se a cutscene acaba logo depois do pedido")
	await _teclar(KEY_ESCAPE)
	await _quadros(3)

	Engine.time_scale = FerramentasPlayer.ESCALA_CONGELADO
	await _teclar(KEY_ESCAPE)
	await _quadros(2)
	_checar(not Pausa.aberta(), "no congelamento do dash a pausa espera")
	Engine.time_scale = 1.0
	await _quadros(3)
	_checar(Pausa.aberta() and is_equal_approx(Engine.time_scale, 1.0),
		"e abre quando o tempo volta a andar")
	await _teclar(KEY_ESCAPE)
	await _quadros(3)

	var cortina := FadeTela.criar(get_tree().current_scene, true)
	await _quadros(2)
	await _teclar(KEY_ESCAPE)
	await _quadros(2)
	_checar(not Pausa.aberta(), "com a cortina de uma porta na tela a pausa não abre")
	await _esperar(Pausa.ESPERA_DO_PEDIDO + 0.2)
	cortina.queue_free()
	await _quadros(3)
	_checar(not Pausa.aberta(), "e um pedido velho não abre a pausa quando a cortina sai")


func _testar_reiniciar() -> void:
	print("\n--- REINICIAR ---")
	var fase := get_tree().current_scene
	var cacau := _cacau()
	# Um checkpoint longe de onde ela nasce: é lá que o REINICIAR a põe.
	var ponto := cacau.global_position + Vector2(240.0, -200.0)
	PontoDeRetorno.registrar(fase, ponto, false)
	await _teclar(KEY_ESCAPE)
	var tela := _tela()
	if tela == null:
		_checar(false, "a pausa abriu")
		return
	tela.focar("reiniciar")
	await _teclar(KEY_ENTER)
	_checar(TransicaoDeCena.em_curso(), "ENTER no REINICIAR começa a troca de cena")
	await _esperar_a_cortina()
	var nova := get_tree().current_scene
	if nova != null:
		_calar_o_radio(nova)
	_checar(nova != null and nova != fase and nova.scene_file_path == FASE, "a fase abre de novo")
	var renascida := _cacau()
	_checar(renascida != null and absf(renascida.global_position.x - ponto.x) < 4.0,
		"com a Cacau no último checkpoint (%s, esperado x = %d)" % [renascida.global_position.round() if renascida else null, ponto.x])
	_checar(not get_tree().paused and not Pausa.aberta(), "e o jogo andando, sem a pausa")
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()
	await _quadros(5)


func _testar_menu_inicial() -> void:
	print("\n--- MENU INICIAL ---")
	await _esperar_ate(func() -> bool: return Pausa.pode_abrir(), 5.0)
	await _teclar(KEY_ESCAPE)
	var tela := _tela()
	if tela == null:
		_checar(false, "a pausa abriu")
		return
	await _clicar(tela, "menu")
	_checar(TransicaoDeCena.em_curso(), "o clique em MENU INICIAL começa a troca de cena")
	await _esperar_a_cortina()
	_checar(get_tree().current_scene != null and get_tree().current_scene.scene_file_path == CENA_MENU,
		"e a tela de título chega")
	_checar(not get_tree().paused and not Pausa.aberta(), "com o jogo andando e sem a pausa")
	_checar(not FerramentasHUD._ancora.visible, "sem os equipamentos da Cacau no canto")
	await _teclar(KEY_ESCAPE)
	_checar(not Pausa.aberta(), "e ali o ESC não pausa nada")
	var menu := get_tree().current_scene
	if menu != null:
		menu.queue_free()
	await _quadros(3)
