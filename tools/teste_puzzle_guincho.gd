extends SceneTree

# Teste headless do elevador de carga da fase 1: a conta do puzzle (massa em
# quilos -> peso em newtons), os dois jeitos de errar, e o fio que sai do
# terminal e chega na plataforma.
#
#   godot --headless --script res://tools/teste_puzzle_guincho.gd

const CENA := "res://scenes/fases/fase1_oficina.tscn"

var _falhas := 0


func _initialize() -> void:
	var fase: Node2D = load(CENA).instantiate()
	root.add_child(fase)
	await process_frame
	await process_frame

	# Sem tipo estático de propósito: em "--script" a árvore de autoloads ainda
	# não existe quando o teste é compilado, e uma anotação ComputadorPuzzle
	# aqui derrubaria a compilação por causa do Interacao lá dentro.
	var terminal = fase.get_node("ElevadorCarga/TerminalGuincho")
	var plataforma: Path2D = fase.get_node("ElevadorCarga/PlataformaCarga")
	var trilho: PathFollow2D = plataforma.get_node("PathFollow2D")
	var puzzle: CanvasLayer = terminal._puzzle_ui

	_conferir(puzzle != null, "o terminal montou a tela do puzzle")
	if puzzle == null:
		_encerrar(fase)
		return

	# --- 1. O POÇO ---
	#
	# Nada aqui crava coordenada: arrastar e redimensionar a plataforma no
	# editor é trabalho de level design, e um teste que reprova por causa disso
	# só atrapalha. O que ele cobra é a RELAÇÃO — o poço é vertical, a ponta de
	# baixo é a de baixo mesmo, ela para perto do chão e o terminal fica ao
	# lado dela, alcançável a pé. (to_global, e não global_position + ponto,
	# porque o nó pode estar escalado.)
	var topo: Vector2 = plataforma.to_global(plataforma.curve.get_point_position(0))
	var base: Vector2 = plataforma.to_global(plataforma.curve.get_point_position(1))
	var chao := 512.0
	_conferir(absf(topo.x - base.x) < 8.0,
		"o poço é vertical (x %.0f em cima, %.0f embaixo)" % [topo.x, base.x])
	_conferir(base.y > topo.y and base.y > chao - 96.0 and base.y <= chao,
		"a ponta de baixo para logo acima do chão (y = %.0f) e o topo fica em %.0f" % [
			base.y, topo.y])
	_conferir(terminal.global_position.y == chao and absf(terminal.global_position.x - base.x) < 320.0,
		"o terminal fica no chão, ao lado da plataforma (%.0f px de distância)" % absf(
			terminal.global_position.x - base.x))
	_conferir(plataforma.comecar_no_fim and is_equal_approx(trilho.progress_ratio, 1.0),
		"ela começa no chão, e não pendurada lá em cima")
	_conferir(plataforma.duracao_trajeto <= 2.5,
		"o trajeto é rápido (%.1f s de uma ponta à outra)" % plataforma.duracao_trajeto)

	# --- 2. A CONTA: massa em quilos vira peso em newtons ---
	puzzle.abrir_puzzle()
	await process_frame
	_conferir(puzzle.visible, "a tela abre no E")
	_conferir(is_equal_approx(puzzle._peso(), puzzle.MASSA * puzzle.GRAVIDADE),
		"o peso é massa × gravidade (%d kg × %d = %d N)" % [
			puzzle.MASSA, puzzle.GRAVIDADE, puzzle._peso()])
	_conferir(is_equal_approx(puzzle._forca, 0.0), "o mostrador abre zerado")

	# Confundir quilo com newton (regular 45 em vez de 450) tem de reprovar:
	# é exatamente o erro que o puzzle existe para pegar.
	puzzle._forca = puzzle.MASSA
	puzzle._acionar()
	_conferir(not puzzle._travado and puzzle._preview.resultado == "fraca",
		"regular a MASSA no lugar do PESO não levanta a plataforma")

	puzzle._forca = puzzle._peso() + puzzle.PASSO_FINO
	puzzle._acionar()
	_conferir(not puzzle._travado and puzzle._preview.resultado == "forte",
		"força a mais faz ela arrancar e bater na viga")

	# Os passos do mostrador precisam alcançar a resposta em cheio.
	var alcancavel: bool = is_equal_approx(fmod(puzzle._peso(), puzzle.PASSO_FINO), 0.0) \
		and puzzle._peso() <= puzzle.FORCA_MAXIMA
	_conferir(alcancavel, "a resposta cai num passo do mostrador e cabe na escala")

	# --- 3. O FIO ATÉ A PLATAFORMA ---
	puzzle._forca = puzzle._peso()
	puzzle._acionar()
	_conferir(puzzle._travado, "a força certa libera o guincho")
	_conferir(puzzle._preview.resultado == "certa", "o desenho mostra a plataforma subindo")

	puzzle.fechar_puzzle(true)
	await process_frame

	_conferir(plataforma.ativa, "a plataforma foi acionada pelo terminal")
	_conferir(terminal._painel.animation == &"azul", "o painel do terminal ficou azul")
	_conferir(EstadoMundo.ja_feito(terminal), "o terminal lembra que foi resolvido")

	# Ela sai mesmo do lugar — do chão para cima, que é o sentido do trilho.
	var antes: float = trilho.progress_ratio
	for i in 40:
		await process_frame
	_conferir(trilho.progress_ratio < antes, "a plataforma subiu do chão")

	_encerrar(fase)


func _conferir(condicao: bool, descricao: String) -> void:
	if condicao:
		print("OK     ", descricao)
	else:
		print("FALHA  ", descricao)
		_falhas += 1


func _encerrar(fase: Node) -> void:
	fase.queue_free()
	await process_frame
	print("\n%s (%d falha(s))" % ["TUDO CERTO" if _falhas == 0 else "COM FALHAS", _falhas])
	quit(_falhas)
