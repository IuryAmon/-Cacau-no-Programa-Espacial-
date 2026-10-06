extends Node

# Teste da parada do arremesso: no CHÃO, a Cacau fica parada enquanto o gesto
# de jogar o bumerangue roda; no AR, não (player.parar_ao_arremessar).
#
# Tudo com entrada de verdade (as ações do mapa de entrada), numa salinha com
# um chão só:
#
#   * correndo no chão e apertando F: o bumerangue sai com o momento da
#     corrida, e do quadro seguinte até o gesto acabar ela não sai do lugar,
#     mesmo com a tecla de andar ainda apertada; acabou o gesto, volta a andar;
#   * parada no gesto ela também não vira para o outro lado;
#   * no ar (no meio de um pulo), o arremesso não freia nada;
#   * pulando no meio do gesto, ela sai do chão e volta a se mexer na hora;
#   * com a chave desligada, vale o jeito antigo: ela segue correndo.
#
#   godot --headless --path . res://tools/teste_parada_no_arremesso.tscn

const PLAYER := "res://scenes/player.tscn"

## Topo do chão da salinha.
const CHAO := 500.0

var _falhas := 0
var _player: CharacterBody2D = null
var _sprite: AnimatedSprite2D = null
var _ferramentas: FerramentasPlayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _montar_sala()

	await _testar_no_chao()
	await _testar_sem_virar()
	await _testar_no_ar()
	await _testar_pulo_no_meio()
	await _testar_chave_desligada()

	_soltar_tudo()
	Progresso._habilidades.erase("bumerangue")
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


func _montar_sala() -> void:
	var chao := StaticBody2D.new()
	chao.name = "Chao"
	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = Vector2(40000, 40)
	forma.shape = retangulo
	chao.add_child(forma)
	chao.position = Vector2(0, CHAO + 20.0)
	add_child(chao)

	_player = (load(PLAYER) as PackedScene).instantiate()
	_player.position = Vector2(0, CHAO - 40.0)
	_player.limite_queda = 1.0e9
	add_child(_player)
	_sprite = _player.get_node("AnimatedSprite2D")
	_ferramentas = FerramentasPlayer.instalar(_player)
	# Direto na flag, sem passar pela ficha de coleta nem pelo tutorial.
	Progresso._habilidades["bumerangue"] = true
	await _esperar_ate(_player.is_on_floor)


# ─────────────────────────────────────────────────────────────

func _testar_no_chao() -> void:
	print("\n--- NO CHAO: PARADA ENQUANTO O GESTO RODA ---")
	_checar(_player.parar_ao_arremessar, "a parada no arremesso vem ligada")
	await _correr(1.0)
	_checar(_player.is_on_floor() and is_equal_approx(_player.velocity.x, _player.speed),
		"antes do arremesso ela esta correndo no chao (%.0f px/s)" % _player.velocity.x)

	await _arremessar()
	_checar(_ferramentas._bumerangue_no_ar and is_instance_valid(_ferramentas._bumerangue),
		"o F jogou o bumerangue")
	_checar(_ferramentas._bumerangue.forca > 0.0,
		"e ele saiu com o momento da corrida (forca %.2f): correr antes ainda vale" % _ferramentas._bumerangue.forca)
	_checar(_sprite.animation == &"jogando_bumerangue", "o gesto entrou no sprite")
	_checar(_player.parada_pelo_arremesso(), "o gesto esta segurando a personagem")

	await _fisica(2)
	var x_parada := _player.global_position.x
	var andou := 0.0
	var velocidade := 0.0
	var quadros := 0
	while _player.parada_pelo_arremesso():
		await get_tree().physics_frame
		if not _player.parada_pelo_arremesso():
			break
		andou = maxf(andou, absf(_player.global_position.x - x_parada))
		velocidade = maxf(velocidade, absf(_player.velocity.x))
		quadros += 1
	_checar(quadros >= 6, "a parada dura o gesto (%d quadros de fisica)" % quadros)
	_checar(andou < 0.5 and is_zero_approx(velocidade),
		"com a tecla de andar ainda apertada, ela nao sai do lugar (andou %.1f px)" % andou)

	await _fisica(3)
	_checar(is_equal_approx(_player.velocity.x, _player.speed) and _sprite.animation == &"run",
		"acabou o gesto, ela volta a correr (%.0f px/s, animacao %s)" % [_player.velocity.x, _sprite.animation])
	await _recolher()


func _testar_sem_virar() -> void:
	print("\n--- NO CHAO: NAO VIRA NO MEIO DO GESTO ---")
	await _correr(1.0)
	await _arremessar()
	_checar(not _sprite.flip_h, "ela jogou para a direita")
	Input.action_release("ui_right")
	Input.action_press("ui_left")
	await _fisica(3)
	_checar(_player.parada_pelo_arremesso() and not _sprite.flip_h and is_zero_approx(_player.velocity.x),
		"apertando para o outro lado no meio do gesto, ela nao vira nem anda")
	await _esperar_ate(func() -> bool: return not _player.parada_pelo_arremesso())
	await _fisica(3)
	_checar(_sprite.flip_h and is_equal_approx(_player.velocity.x, -_player.speed),
		"acabou o gesto, ai sim vira e anda para la")
	await _recolher()


func _testar_no_ar() -> void:
	print("\n--- NO AR: O ARREMESSO NAO FREIA ---")
	await _correr(1.0)
	await _pular()
	_checar(not _player.is_on_floor(), "ela esta no ar")
	var x_antes := _player.global_position.x
	await _arremessar()
	_checar(_ferramentas._bumerangue_no_ar, "o F jogou o bumerangue no meio do pulo")
	_checar(not _player.parada_pelo_arremesso(), "no ar o gesto nao segura ninguem")
	var menor: float = _player.speed
	for i in 8:
		await get_tree().physics_frame
		if _player.is_on_floor():
			break
		menor = minf(menor, _player.velocity.x)
	_checar(is_equal_approx(menor, _player.speed) and _player.global_position.x > x_antes + 30.0,
		"ela segue na mesma velocidade, sem parar (%.0f px/s, andou %.0f px)"
			% [menor, _player.global_position.x - x_antes])
	_checar(_sprite.animation == &"jogando_bumerangue" or _player.is_on_floor(),
		"com o braco fazendo o gesto no ar")
	await _esperar_ate(_player.is_on_floor)
	await _fisica(3)
	_checar(is_equal_approx(_player.velocity.x, _player.speed) and not _player.parada_pelo_arremesso(),
		"e pousar com o gesto ainda rodando tambem nao a para")
	await _recolher()


func _testar_pulo_no_meio() -> void:
	print("\n--- NO CHAO: PULAR NO MEIO DO GESTO SOLTA ---")
	await _correr(1.0)
	await _arremessar()
	await _fisica(2)
	_checar(_player.parada_pelo_arremesso() and is_zero_approx(_player.velocity.x),
		"parada no gesto, no chao")
	await _pular()
	_checar(not _player.is_on_floor() and not _player.parada_pelo_arremesso(),
		"o pulo tira ela do chao e o gesto solta")
	await _fisica(2)
	_checar(is_equal_approx(_player.velocity.x, _player.speed) and _sprite.animation == &"jump",
		"no ar ela ja anda de novo (%.0f px/s, animacao %s)" % [_player.velocity.x, _sprite.animation])
	await _esperar_ate(_player.is_on_floor)
	await _recolher()


func _testar_chave_desligada() -> void:
	print("\n--- CHAVE DESLIGADA: O JEITO ANTIGO ---")
	_player.parar_ao_arremessar = false
	await _correr(1.0)
	await _arremessar()
	_checar(_ferramentas._bumerangue_no_ar and _sprite.animation == &"jogando_bumerangue",
		"o F joga o bumerangue e o gesto entra do mesmo jeito")
	_checar(not _player.parada_pelo_arremesso(), "mas nada segura a personagem")
	var menor: float = _player.speed
	for i in 8:
		await get_tree().physics_frame
		menor = minf(menor, _player.velocity.x)
	_checar(is_equal_approx(menor, _player.speed), "ela segue correndo com o braco no gesto (%.0f px/s)" % menor)
	_player.parar_ao_arremessar = true
	await _recolher()


# ─────────────────────────────────────────────────────────────

## Segura a tecla de andar para o lado pedido e espera ela pegar velocidade.
func _correr(lado: float) -> void:
	_soltar_tudo()
	Input.action_press("ui_right" if lado > 0.0 else "ui_left")
	await _fisica(4)


## Um toque de F, visto pela física (é lá que as ferramentas leem o botão).
func _arremessar() -> void:
	await get_tree().physics_frame
	Input.action_press("arremessar")
	await _fisica(2)
	Input.action_release("arremessar")


## Um toque de pulo, e espera ela sair do chão.
func _pular() -> void:
	await get_tree().physics_frame
	Input.action_press("jump")
	await _fisica(2)
	Input.action_release("jump")
	await _esperar_ate(func() -> bool: return not _player.is_on_floor(), 1.0)


## Solta as teclas, espera o bumerangue voltar para a mão e o gesto acabar:
## cada caso começa com ela livre e de mão cheia.
func _recolher() -> void:
	_soltar_tudo()
	await _esperar_ate(func() -> bool: return not _ferramentas._bumerangue_no_ar, 8.0)
	await _esperar_ate(func() -> bool: return _player._arremesso_restante <= 0.0)
	await _fisica(3)


func _soltar_tudo() -> void:
	for acao in ["ui_left", "ui_right", "jump", "arremessar"]:
		Input.action_release(acao)


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _esperar_ate(condicao: Callable, teto: float = 5.0) -> void:
	var inicio := Time.get_ticks_msec()
	while not condicao.call() and Time.get_ticks_msec() - inicio < teto * 1000.0:
		await get_tree().physics_frame
