extends Node

# --- BASE DOS TESTES DAS TELAS DO MENU E DO LABORATÓRIO ---
#
# O menu principal, o menu do Laboratório e as atividades dele são telas de
# cena cheia (scripts/ui/tela_interativa.gd). Os testes delas estendem este
# script, que guarda o que todos repetem:
#
#   _comecar() e _terminar()   leem "--capturas=<pasta>", tiram o teste do lugar
#                              de "cena atual" (assim uma troca de cena de
#                              verdade não o leva junto) e, no fim, dizem
#                              TUDO OK ou quantas falhas houve.
#   _checar()                  uma linha "ok" ou "FALHA" por coisa conferida.
#   _abrir()                   põe uma tela na árvore e espera ela montar.
#   _clicar(), _teclar()...    o mouse, o teclado e o controle de verdade: os
#                              eventos entram pelo Input, como no jogo.
#   _tocou()                   a tela pediu o som? (pelo sinal som_tocado: um
#                              estalo curto já acabou um quadro depois.)
#   _letras_que_faltam()       toda letra escrita precisa existir na fonte do
#                              jogo (ela não tem, por exemplo, o sinal "−").
#   _foto()                    com --capturas (e sem --headless), salva a tela.
#
# Não é um teste: é só a base. Os testes são as cenas tools/teste_*.tscn.

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

var _falhas := 0
var _pasta_capturas := ""
## Os sons que cada tela pediu desde a última pergunta (ver _tocou).
var _sons := {}


func _comecar() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			_pasta_capturas = arg.trim_prefix("--capturas=")
	if not _pasta_capturas.is_empty():
		DirAccess.make_dir_recursive_absolute(_pasta_capturas)
	# O teste continua na raiz, mas deixa de ser a cena atual: quando uma tela
	# troca de cena (TransicaoDeCena), quem sai é ela, e o teste fica.
	get_tree().current_scene = null
	await get_tree().process_frame


func _terminar() -> void:
	Engine.time_scale = 1.0
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


# ─────────────────────────────────────────────────────────────
# AS TELAS
# ─────────────────────────────────────────────────────────────

## Põe a tela na árvore (filha do teste) e espera ela montar.
func _abrir(caminho: String) -> TelaInterativa:
	var tela := (load(caminho) as PackedScene).instantiate() as TelaInterativa
	_escutar(tela)
	add_child(tela)
	await _quadros(3)
	return tela


## Passa a anotar os sons que a tela pedir (o _abrir já faz isto).
func _escutar(tela: TelaInterativa) -> void:
	var lista: Array = []
	_sons[tela.get_instance_id()] = lista
	tela.som_tocado.connect(func(nome: String) -> void: lista.append(nome))


## A tela pediu este som desde a última vez que se perguntou por algum? Quem
## pergunta esquece os sons já ouvidos: a próxima pergunta só vale para o que
## tocar daqui em diante.
func _tocou(tela: TelaInterativa, nome: String) -> bool:
	var lista: Array = _sons.get(tela.get_instance_id(), [])
	var sim := nome in lista
	lista.clear()
	return sim


func _fechar(tela: Node) -> void:
	if is_instance_valid(tela):
		tela.queue_free()
	await _quadros(2)


## Troca a cena atual de verdade (sem cortina) e devolve a que chegou.
func _trocar_de_cena(caminho: String) -> Node:
	get_tree().change_scene_to_file(caminho)
	await _esperar_ate(func() -> bool:
		var cena := get_tree().current_scene
		return cena != null and cena.scene_file_path == caminho and cena.is_node_ready(), 10.0)
	await _quadros(2)
	return get_tree().current_scene


## Espera a cortina (TransicaoDeCena) terminar e devolve o caminho da cena que
## chegou ("" se não chegou nenhuma). A cena que chegou é desfeita em seguida:
## o teste segue sem ela.
func _esperar_a_troca() -> String:
	await _esperar_ate(func() -> bool: return not TransicaoDeCena.em_curso(), 10.0)
	await _quadros(2)
	var cena := get_tree().current_scene
	var caminho := cena.scene_file_path if cena != null else ""
	if cena != null:
		cena.queue_free()
		await _quadros(2)
	return caminho


func _quadros(quantos: int) -> void:
	for i in quantos:
		await get_tree().process_frame


## Espera o tempo do JOGO (anda mais depressa com Engine.time_scale).
func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos, true, false, false).timeout


## Espera até a condição valer, olhando a cada quadro. Devolve false se o
## limite (em segundos de relógio) passar antes.
func _esperar_ate(condicao: Callable, limite: float = 5.0) -> bool:
	var inicio := Time.get_ticks_msec()
	while not condicao.call():
		if Time.get_ticks_msec() - inicio > limite * 1000.0:
			return false
		await get_tree().process_frame
	return true


# ─────────────────────────────────────────────────────────────
# O MOUSE, O TECLADO E O CONTROLE
# ─────────────────────────────────────────────────────────────
# Os eventos vão pelo caminho de verdade (Input -> janela -> _input das telas),
# e não chamando o _input da tela direto: assim o teste também vê se alguma
# outra coisa do jogo come o clique, e o Input fica sabendo onde o mouse está
# (é ele que reenvia a posição quando o ponteiro vira mãozinha).

## Manda um evento e o entrega já, sem esperar o próximo quadro.
func _mandar(evento: InputEvent) -> void:
	Input.parse_input_event(evento)
	Input.flush_buffered_events()


## Um ponto da tela do jogo (1600 x 900) em coordenadas da janela, que é como
## os eventos de mouse chegam.
func _na_janela(ponto: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * ponto


func _mover_o_mouse(ponto: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _na_janela(ponto)
	ev.global_position = ev.position
	_mandar(ev)


func _botao_do_mouse(ponto: Vector2, apertado: bool, botao: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = botao
	ev.pressed = apertado
	ev.position = _na_janela(ponto)
	ev.global_position = ev.position
	_mandar(ev)


## Um "dente" da roda do mouse em cima do ponto.
func _rodar_o_mouse(ponto: Vector2, para_cima: bool) -> void:
	var botao := MOUSE_BUTTON_WHEEL_UP if para_cima else MOUSE_BUTTON_WHEEL_DOWN
	_mover_o_mouse(ponto)
	_botao_do_mouse(ponto, true, botao)
	_botao_do_mouse(ponto, false, botao)


## Leva o mouse até o ponto e clica (aperta e solta).
func _clicar_em(ponto: Vector2) -> void:
	_mover_o_mouse(ponto)
	_botao_do_mouse(ponto, true)
	_botao_do_mouse(ponto, false)
	await get_tree().process_frame


## Clica no meio de um alvo da tela (o nome que ela deu em registrar_alvo).
func _clicar(tela: TelaInterativa, alvo: String, vezes: int = 1) -> void:
	for k in vezes:
		await _clicar_em(tela.retangulo_do_alvo(alvo).get_center())


## Leva o mouse até o meio do alvo, sem clicar.
func _passar_por(tela: TelaInterativa, alvo: String) -> void:
	_mover_o_mouse(tela.retangulo_do_alvo(alvo).get_center())
	await get_tree().process_frame


func _tecla(codigo: Key, apertada: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = codigo
	ev.physical_keycode = codigo
	ev.pressed = apertada
	_mandar(ev)


## Aperta e solta uma tecla.
func _teclar(codigo: Key) -> void:
	_tecla(codigo, true)
	_tecla(codigo, false)
	await get_tree().process_frame


## Um toque num botão do controle (aperta, espera uns quadros e solta), como em
## tools/teste_controle.gd.
func _tocar_no_controle(botao: JoyButton, quadros_apertado: int = 3) -> void:
	_botao_do_controle(botao, true)
	await _quadros(quadros_apertado)
	_botao_do_controle(botao, false)
	await _quadros(3)


func _botao_do_controle(botao: JoyButton, apertado: bool) -> void:
	var evento := InputEventJoypadButton.new()
	evento.device = 0
	evento.button_index = botao
	evento.pressed = apertado
	evento.pressure = 1.0 if apertado else 0.0
	_mandar(evento)


func _eixo_do_controle(eixo: JoyAxis, valor: float) -> void:
	var evento := InputEventJoypadMotion.new()
	evento.device = 0
	evento.axis = eixo
	evento.axis_value = valor
	_mandar(evento)


## Põe o cursor do controle num ponto da tela, parado (como em
## tools/teste_controle.gd).
func _levar_o_cursor(ponto: Vector2) -> void:
	CursorVirtual._pos = ponto
	CursorVirtual._pulo_t = 1.0
	CursorVirtual._ir_ao_alvo_em = -1.0
	await _quadros(2)


## Larga o controle: uma tecla devolve a tela ao teclado e ao mouse.
func _voltar_ao_teclado() -> void:
	_tecla(KEY_SHIFT, true)
	_tecla(KEY_SHIFT, false)
	await _quadros(3)


# ─────────────────────────────────────────────────────────────
# LETRAS E CAIXAS
# ─────────────────────────────────────────────────────────────

## As letras destes textos que a fonte do jogo não tem ("" = tem todas). As
## marcas {acao} e os códigos das teclas desenhadas não são letra.
func _letras_que_faltam(textos: Array) -> String:
	var faltando := ""
	var marca := RegEx.create_from_string("\\{[^}]*\\}")
	for texto in textos:
		for c in marca.sub(String(texto), "", true):
			if c == " " or c == "\n" or c.unicode_at(0) >= BotoesControle.PRIMEIRO_CODIGO:
				continue
			if not FONTE.has_char(c.unicode_at(0)) and not faltando.contains(c):
				faltando += c
	return faltando


## Os textos que o script do nó guarda nas constantes TXT_... (é o costume das
## telas: tudo o que elas escrevem está numa constante com esse começo),
## inclusive os que estão dentro de listas e dicionários.
func _textos_do_script(no: Object) -> Array:
	var textos: Array = []
	var constantes: Dictionary = (no.get_script() as Script).get_script_constant_map()
	for nome: String in constantes:
		if nome.begins_with("TXT_"):
			_juntar_textos(constantes[nome], textos)
	return textos


func _juntar_textos(valor: Variant, textos: Array) -> void:
	if valor is String or valor is StringName:
		textos.append(String(valor))
	elif valor is Array:
		for item: Variant in valor:
			_juntar_textos(item, textos)
	elif valor is Dictionary:
		for chave: Variant in valor:
			_juntar_textos(valor[chave], textos)


## O texto de todo Label e RichTextLabel debaixo do nó (visível ou não).
func _textos_dos_labels(raiz: Node) -> Array:
	var textos: Array = []
	for label: Label in raiz.find_children("*", "Label", true, false):
		textos.append(label.text)
	for rico: RichTextLabel in raiz.find_children("*", "RichTextLabel", true, false):
		textos.append(rico.get_parsed_text())
	return textos


## O texto do Label (que quebra em linhas) aparece inteiro na altura dele?
## A ordem importa: get_line_count() refaz as linhas do texto novo, e
## get_visible_line_count() só conta nas que já estão feitas.
func _cabe_inteiro(label: Label) -> bool:
	var linhas := label.get_line_count()
	return label.get_visible_line_count() >= linhas


## Os Labels visíveis debaixo de "raiz" cujo texto não cabe na caixa deles ou
## que saem de "limite" (o vidro do computador). Vazio = tudo no lugar.
func _labels_fora_do_lugar(raiz: Node, limite: Rect2) -> PackedStringArray:
	var fora := PackedStringArray()
	for label: Label in raiz.find_children("*", "Label", true, false):
		if not label.is_visible_in_tree() or label.text.is_empty():
			continue
		var caixa := label.get_global_rect()
		var escala := label.get_global_transform().get_scale().x
		var fonte := label.get_theme_font("font")
		var tamanho := label.get_theme_font_size("font_size")
		var sobra := 0.0
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			for linha in label.text.split("\n"):
				sobra = maxf(sobra, fonte.get_string_size(linha, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x * escala
					- caixa.size.x)
		if sobra > 1.0 or not limite.grow(1.0).encloses(caixa):
			fora.append("%s \"%s\" %s (+%d px)" % [label.name, label.text.left(24), caixa, roundi(sobra)])
	return fora


# ─────────────────────────────────────────────────────────────
# FOTOS
# ─────────────────────────────────────────────────────────────

func _foto(nome: String) -> void:
	if _pasta_capturas.is_empty() or DisplayServer.get_name() == "headless":
		return
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_pasta_capturas.path_join(nome + ".png"))
	print("  .     foto: ", nome)
