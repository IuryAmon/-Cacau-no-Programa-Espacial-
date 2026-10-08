extends Node

# Teste do morcego (scenes/fases/componentes/morcego.tscn, scripts/fases/morcego.gd):
#
#   godot --headless --path . res://tools/teste_morcego.tscn
#
# (Roda como cena, e não com -s: o morcego.gd fala com a Interacao, e isso só
# compila com os autoloads já carregados. Com --fixed-fps 60 ele também passa,
# e termina em poucos segundos em vez de um minuto.)
#
# A primeira parte acontece numa salinha montada aqui — um chão e um teto, na
# mesma distância um do outro que nos corredores — com a Cacau de verdade e o
# bumerangue de verdade:
#   * a cena: as sete animações, o alvo do bumerangue, os sons;
#   * o ninho: solto abaixo do teto, ele se pendura sozinho e dorme; com a
#     Cacau longe continua dormindo, e com tela aberta nem com ela perto acorda;
#   * acordar: com ela perto ele acorda, solta do teto, vira e vai se postar na
#     diagonal dela; o vizinho acorda em seguida, e não no mesmo quadro;
#   * o bote: avisa antes (o preparo), tira uma vida de quem ficou parada, não
#     começa contra quem está sem o controle e não fere quem está no dash;
#   * o desvio: quem sai de baixo vê o morcego bater no chão e ficar tonto;
#   * o bumerangue: UM arremesso acerta na ida (tonto, jogado para trás) e na
#     volta (morto, com o corpo jogado para o lado dela); acertar no preparo
#     cancela o bote; com "vida" 1 ele morre no primeiro toque;
#   * o corpo: fecha o alvo, quica, some sozinho — e derruba o vizinho;
#   * desistir: com ela longe ele volta para o ninho e dorme de novo;
#   * "persistir": o morcego morto não volta na visita seguinte.
#
# A segunda parte abre os dois corredores de verdade: os morcegos estão lá,
# pendurados no teto, longe das pontas por onde ela chega, dormindo enquanto
# ela não chega perto — e acordam quando ela chega.

const PLAYER := "res://scenes/player.tscn"
const MORCEGO := "res://scenes/fases/componentes/morcego.tscn"
const CORREDORES := {
	"res://scenes/fases/corredor_torre.tscn": 3,
	"res://scenes/fases/corredor_patio.tscn": 2,
}

## A salinha: o topo do chão e a face de baixo do teto (384 px de vão, como
## nos corredores).
const CHAO := 500.0
const TETO := 116.0
## Onde a Cacau fica em pé (a origem dela é o meio do corpo).
const EM_PE := Vector2(0, CHAO - 36.0)

var _falhas := 0
var _player: CharacterBody2D = null
var _ferramentas: FerramentasPlayer = null
var _sinais: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _montar_sala()

	await _testar_cena()
	await _testar_ninho()
	await _testar_acordar()
	await _testar_bote()
	await _testar_desvio()
	await _testar_bumerangue()
	await _testar_corpo()
	await _testar_desistir()
	await _testar_persistir()
	await _desmontar_sala()
	await _testar_corredores()

	Progresso._habilidades.erase("bumerangue")
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


# ─────────────────────────────────────────────────────────────

func _testar_cena() -> void:
	print("\n--- A CENA DO MORCEGO ---")
	var m := await _novo(Vector2(-3000, 300))
	_checar(m is Morcego and m is CharacterBody2D, "a raiz é um Morcego (CharacterBody2D)")
	_checar(m.collision_layer == 0 and m.collision_mask == 1,
		"esbarra no cenário, mas não empurra a Cacau nem segura o bumerangue (camada 0, máscara 1)")
	_checar(m.z_index > _player.z_index, "desenha por cima da Cacau")

	var visual := m.get_node("Visual") as AnimatedSprite2D
	var esperado := {&"dormindo": 1, &"voando": 4, &"preparando": 3, &"mergulho": 1,
		&"recuperando": 1, &"golpe": 4, &"morrendo": 3}
	var certas := 0
	for nome: StringName in esperado:
		if visual.sprite_frames.has_animation(nome) \
				and visual.sprite_frames.get_frame_count(nome) == esperado[nome]:
			certas += 1
	_checar(certas == esperado.size(), "as sete animações estão no Visual (%d de %d)" % [certas, esperado.size()])
	_checar(visual.material is ShaderMaterial and m._material != null,
		"com o shader do contorno e dos olhos")

	var alvo := m.get_node("AreaAlvo") as Area2D
	_checar(alvo is HitboxBumerangue and alvo.is_in_group(&"alvo_bumerangue"),
		"o AreaAlvo é uma HitboxBumerangue, à vista do bumerangue")
	var sons := [m.som_guincho, m.som_ameaca, m.som_mergulho, m.som_asa, m.som_golpe,
		m.som_morte, m.som_queda, m.som_pof]
	_checar(not sons.has(null), "os oito sons estão ligados")
	_checar(m.vida == 2 and m.vida_restante() == 2 and m.dorme_no_teto and not m.persistir,
		"de fábrica: 2 de vida, dorme no teto e volta a cada visita")
	await _limpar()


func _testar_ninho() -> void:
	print("\n--- O NINHO ---")
	_player.global_position = Vector2(-2000, EM_PE.y)
	var m := await _novo(Vector2(300, TETO + 70.0))
	_checar(m.estado == Morcego.Estado.DORMINDO, "ele nasce dormindo")
	_checar(absf(m.global_position.y - (TETO + Morcego.PENDURADO_ABAIXO_DO_TETO)) < 0.5
			and is_equal_approx(m.global_position.x, 300.0),
		"solto 70 px abaixo do teto, ele sobe e se pendura (y = %.1f, teto em %.0f)" % [m.global_position.y, TETO])
	var visual := m.get_node("Visual") as AnimatedSprite2D
	_checar(visual.animation == &"dormindo" and absf(angle_difference(visual.rotation, PI)) < 0.1,
		"de cabeça para baixo, com as asas fechadas")

	# Sem teto por perto ele se pendura onde foi deixado.
	var solto := await _novo(Vector2(600, TETO + 300.0), {"alcance_do_teto": 100.0})
	_checar(solto.estado == Morcego.Estado.DORMINDO and solto.global_position.is_equal_approx(Vector2(600, TETO + 300.0)),
		"sem teto ao alcance, fica pendurado exatamente onde foi posto")

	await _segundos(1.0)
	_checar(m.estado == Morcego.Estado.DORMINDO and not _sinais.has(m),
		"com a Cacau longe, continua dormindo")

	# Tela aberta: nem com ela embaixo ele acorda.
	var tela := Node.new()
	add_child(tela)
	Interacao.marcar_tela_aberta(tela, true)
	_player.global_position = Vector2(300, EM_PE.y)
	await _segundos(0.6)
	_checar(m.estado == Morcego.Estado.DORMINDO, "com uma tela aberta ele espera junto, mesmo com ela embaixo")
	Interacao.marcar_tela_aberta(tela, false)
	tela.queue_free()
	await _limpar()


func _testar_acordar() -> void:
	print("\n--- ACORDAR ---")
	# O vizinho fica fora do alerta dele, mas dentro do raio do bando do primeiro.
	var m := await _novo(Vector2(120, TETO + 40.0))
	var vizinho := await _novo(Vector2(330, TETO + 40.0), {"raio_de_alerta": 0.0})
	_player.global_position = EM_PE
	await _fisica(3)
	_checar(m.estado == Morcego.Estado.ACORDANDO and _sinais.get(m, {}).get("acordou", 0) == 1,
		"com a Cacau dentro do raio e à vista, ele acorda")
	_checar(vizinho.estado == Morcego.Estado.DORMINDO, "o vizinho não acorda no mesmo quadro")
	_checar(m.global_position.y < TETO + 21.0, "ele ainda treme pendurado um instante antes de soltar")

	await _esperar_ate(func() -> bool: return m.estado == Morcego.Estado.VOANDO, 1.0)
	var visual := m.get_node("Visual") as AnimatedSprite2D
	_checar(m.estado == Morcego.Estado.VOANDO and visual.animation == &"voando",
		"solta do teto e sai voando")
	await _segundos(0.2)
	_checar(vizinho.estado != Morcego.Estado.DORMINDO, "e o vizinho acordou atrás dele, em fila")

	# Segura os botes para ver só o voo.
	m._espera_do_bote = 99.0
	vizinho._espera_do_bote = 99.0
	await _segundos(2.6)
	_checar(absf(angle_difference(visual.rotation, 0.0)) < 0.1, "já de cabeça para cima")
	var ate: Vector2 = m.global_position - _player.global_position
	_checar(absf(absf(ate.x) - m.posto.x) < 45.0 and absf(ate.y + m.posto.y) < 35.0,
		"e se posta na diagonal dela (a %.0f px para o lado e %.0f para cima)" % [absf(ate.x), -ate.y])
	# O vizinho, do mesmo lado, entra na fila: na mesma diagonal, um lugar atrás.
	var ate_vizinho: Vector2 = vizinho.global_position - _player.global_position
	_checar(signf(ate_vizinho.x) == signf(ate.x) and absf(absf(ate_vizinho.x) + ate_vizinho.y) < 50.0
			and ate_vizinho.length() > ate.length() + 25.0,
		"o vizinho faz fila atrás dele na mesma diagonal (a %.0f px dela, contra %.0f)"
			% [ate_vizinho.length(), ate.length()])
	# Um arremesso reto na diagonal passa pelos dois.
	var diagonal := Vector2(signf(ate.x), -1.0).normalized()
	var mao: Vector2 = _player.global_position + Bumerangue.ALTURA_MAO
	var fora := maxf(absf((m.global_position - mao).cross(diagonal)), absf((vizinho.global_position - mao).cross(diagonal)))
	_checar(fora < 40.0, "os dois ao alcance de um mesmo arremesso na diagonal (o mais torto a %.0f px da linha)" % fora)
	await _limpar()


func _testar_bote() -> void:
	print("\n--- O BOTE ---")
	_player.global_position = EM_PE
	var m := await _novo(Vector2(140, TETO + 40.0))
	await _esperar_ate(func() -> bool: return m.estado != Morcego.Estado.DORMINDO, 0.5)

	# Sem o controle (cutscene, chegada andando) ela não vira alvo.
	_player.pode_se_mover = false
	await _segundos(3.0)
	_checar(m.estado == Morcego.Estado.VOANDO and is_zero_approx(m._espera_do_bote),
		"contra quem está sem o controle ele nem arma o bote, por mais que espere")
	_player.pode_se_mover = true

	await _esperar_ate(func() -> bool: return m.estado == Morcego.Estado.PREPARANDO, 1.0)
	_checar(m.estado == Morcego.Estado.PREPARANDO, "com ela parada ao alcance, ele arma o bote")
	_checar((m.get_node("Visual") as AnimatedSprite2D).animation == &"preparando",
		"com a animação do preparo")
	var preparo := 0
	while m.estado == Morcego.Estado.PREPARANDO and preparo < 300:
		await get_tree().physics_frame
		preparo += 1
	_checar(preparo / 60.0 >= m.tempo_de_preparo - 0.05 and _player.current_health == _player.max_health,
		"o aviso dura o preparo inteiro (%.2f s) e não machuca ninguém" % (preparo / 60.0))
	_checar(m.estado == Morcego.Estado.MERGULHANDO, "depois ele mergulha")
	await _esperar_ate(func() -> bool: return m.estado != Morcego.Estado.MERGULHANDO, 1.5)
	_checar(_player.current_health == _player.max_health - 1,
		"e tira uma vida de quem ficou parada (%d de %d)" % [_player.current_health, _player.max_health])
	_checar(m.estado == Morcego.Estado.RECUPERANDO, "mordeu e quica para trás, recuperando")
	await _esperar_ate(func() -> bool: return m.estado == Morcego.Estado.VOANDO, 1.0)
	_checar(m.estado == Morcego.Estado.VOANDO and m._espera_do_bote > 0.3,
		"volta a voar, com o próximo bote só daqui a pouco (%.1f s)" % m._espera_do_bote)
	await _limpar()

	# Do acordar ao primeiro aviso passa um bom segundo: dá tempo de ver o
	# morcego descer do teto antes de ele ameaçar.
	_player.global_position = EM_PE
	m = await _novo(Vector2(140, TETO + 40.0))
	await _esperar_ate(func() -> bool: return m.estado != Morcego.Estado.DORMINDO, 0.5)
	var ate_o_aviso := 0
	while m.estado != Morcego.Estado.PREPARANDO and ate_o_aviso < 600:
		await get_tree().physics_frame
		ate_o_aviso += 1
	_checar(m.estado == Morcego.Estado.PREPARANDO and ate_o_aviso / 60.0 >= Morcego.ESPERA_DO_PRIMEIRO_BOTE - 0.1
			and ate_o_aviso / 60.0 < 4.0,
		"do acordar ao primeiro aviso de bote passa %.1f s" % (ate_o_aviso / 60.0))

	# No dash da mochila ela atravessa o bote.
	await _esperar_ate(func() -> bool: return m.estado == Morcego.Estado.MERGULHANDO, 2.0)
	_player.esta_invencivel_dash = true
	await _esperar_ate(func() -> bool: return m.estado != Morcego.Estado.MERGULHANDO, 1.5)
	_player.esta_invencivel_dash = false
	_checar(_player.current_health == _player.max_health and m.estado == Morcego.Estado.ATORDOADO,
		"no dash o bote passa por dentro dela sem ferir, e ele vai dar no chão")
	await _limpar()


func _testar_desvio() -> void:
	print("\n--- O DESVIO ---")
	_player.global_position = EM_PE
	var m := await _novo(Vector2(140, TETO + 40.0))
	await _esperar_ate(func() -> bool: return m.estado == Morcego.Estado.MERGULHANDO, 5.0)
	# Ela sai de baixo no instante em que ele solta: o rumo já estava travado.
	var rumo: Vector2 = m._rumo_do_mergulho
	_player.global_position = EM_PE + Vector2(-260.0 * signf(rumo.x), 0)
	await _fisica(4)
	_checar(m._rumo_do_mergulho.is_equal_approx(rumo), "o mergulho não corrige a mira atrás dela")
	await _esperar_ate(func() -> bool: return m.estado != Morcego.Estado.MERGULHANDO, 1.5)
	_checar(m.estado == Morcego.Estado.ATORDOADO and _player.current_health == _player.max_health,
		"quem saiu de baixo não apanha: ele dá de cara no cenário e fica tonto")
	_checar(m.global_position.y > CHAO - 40.0, "caído perto do chão (y = %.0f)" % m.global_position.y)
	_checar(m.vida_restante() == m.vida, "a batida não tira vida dele")
	_checar(m.get_node("AreaAlvo").is_in_group(&"alvo_bumerangue"), "e tonto ele continua à vista do bumerangue")
	await _esperar_ate(func() -> bool: return m.estado != Morcego.Estado.ATORDOADO, 1.5)
	_checar(m.estado == Morcego.Estado.VOANDO, "passada a tontura, volta para a briga")
	await _limpar()


func _testar_bumerangue() -> void:
	print("\n--- O BUMERANGUE ---")
	# Parado no ar, na altura da mão dela, a 150 px: o arremesso reto passa por
	# ele na ida e na volta.
	var parado := {"dorme_no_teto": false, "velocidade_de_voo": 0.0, "raio_de_alerta": 0.0}
	_player.global_position = EM_PE
	(_player.get_node("AnimatedSprite2D") as AnimatedSprite2D).flip_h = false
	await _fisica(4)
	var m := await _novo(EM_PE + Vector2(150, 2), parado)
	var x_antes := m.global_position.x
	await _arremessar()
	await _esperar_ate(func() -> bool: return m.vida_restante() < 2, 1.0)
	_checar(m.vida_restante() == 1 and m.estado == Morcego.Estado.ATORDOADO,
		"na IDA o bumerangue acerta: sobra 1 de vida e ele fica tonto")
	_checar(_sinais.get(m, {}).get("levou_golpe", 0) == 1, "o sinal levou_golpe sai uma vez só")
	_checar(not m.get_node("AreaAlvo").is_in_group(&"alvo_bumerangue"),
		"por um instante o mesmo passe não pega de novo")
	# (Esperando o alvo voltar, e não um número fixo de quadros: o acerto
	# congela o jogo por um instante, e quadro congelado não conta tempo.)
	var voltou := await _esperar_ate(func() -> bool:
		return m.get_node("AreaAlvo").is_in_group(&"alvo_bumerangue"), 0.5)
	_checar(voltou and m.estado == Morcego.Estado.ATORDOADO, "e logo volta a estar à vista, ainda tonto")
	_checar(m.global_position.x > x_antes + 20.0,
		"ele é jogado para trás, no rumo do bumerangue (%.0f px)" % (m.global_position.x - x_antes))

	await _esperar_ate(func() -> bool: return m.estado == Morcego.Estado.MORTO, 2.0)
	_checar(m.estado == Morcego.Estado.MORTO and _sinais.get(m, {}).get("morreu", 0) == 1,
		"na VOLTA do mesmo arremesso ele morre: um arremesso, dois acertos")
	_checar(m.velocity.x < -100.0, "o corpo sai no rumo em que o bumerangue vinha: para o lado dela (%.0f px/s)" % m.velocity.x)
	await _recolher()
	await _limpar()

	# Acertar durante o aviso cancela o bote.
	_player.global_position = EM_PE
	m = await _novo(Vector2(140, TETO + 40.0))
	await _esperar_ate(func() -> bool: return m.estado == Morcego.Estado.PREPARANDO, 5.0)
	m.levar_golpe(Vector2.RIGHT, 0.0)
	_checar(m.estado == Morcego.Estado.ATORDOADO, "um acerto no meio do preparo cancela o bote")
	await _segundos(0.7)
	_checar(_player.current_health == _player.max_health and m.estado == Morcego.Estado.ATORDOADO,
		"e o mergulho que já vinha não acontece")
	await _limpar()

	# Com 1 de vida, morre no primeiro toque — e o golpe sem rumo (ninguém
	# arremessou nada) joga para longe dela.
	_player.global_position = EM_PE
	m = await _novo(EM_PE + Vector2(150, -60), {"dorme_no_teto": false, "velocidade_de_voo": 0.0,
		"raio_de_alerta": 0.0, "vida": 1})
	(m.get_node("AreaAlvo") as HitboxBumerangue).atingir_bumerangue()
	_checar(m.estado == Morcego.Estado.MORTO, "com \"vida\" 1 ele morre no primeiro acerto")
	_checar(m.velocity.x > 100.0, "e um golpe sem rumo o joga para longe dela")
	await _limpar()


func _testar_corpo() -> void:
	print("\n--- O CORPO ---")
	var parado := {"dorme_no_teto": false, "velocidade_de_voo": 0.0, "raio_de_alerta": 0.0}
	_player.global_position = Vector2(-600, EM_PE.y)
	var m := await _novo(Vector2(0, 300), parado)
	var vizinho := await _novo(Vector2(70, 285), parado)
	m.levar_golpe(Vector2.RIGHT, 0.0)
	m.levar_golpe(Vector2.RIGHT, 0.0)
	_checar(m.vida_restante() == 1, "dois golpes no mesmo instante contam como um só")
	await _fisica(12)
	m.levar_golpe(Vector2.RIGHT, 1.0)
	_checar(m.estado == Morcego.Estado.MORTO, "o segundo golpe mata")
	var alvo := m.get_node("AreaAlvo") as Area2D
	_checar(not alvo.is_in_group(&"alvo_bumerangue"), "o corpo sai da vista do bumerangue")
	_checar(m.velocity.x > 600.0 and m.velocity.y < 0.0,
		"e sai arremessado em arco, mais forte no arremesso forte (%.0f px/s)" % m.velocity.length())

	await _esperar_ate(func() -> bool: return vizinho.vida_restante() < 2, 1.0)
	_checar(vizinho.vida_restante() == 1 and vizinho.estado == Morcego.Estado.ATORDOADO,
		"no caminho o corpo derruba o vizinho")

	var quicou := await _esperar_ate(func() -> bool: return m._quiques > 0, 2.0)
	_checar(quicou and not alvo.is_in_group(&"alvo_bumerangue"), "ele bate no cenário e quica (continua fora da vista)")
	# (Pela referência fraca: o próprio "m" deixa de existir no meio da espera.)
	var corpo: WeakRef = weakref(m)
	var sumiu := await _esperar_ate(func() -> bool: return corpo.get_ref() == null, 5.0)
	_checar(sumiu, "e some sozinho")
	await _limpar()


func _testar_desistir() -> void:
	print("\n--- DESISTIR E VOLTAR A DORMIR ---")
	_player.global_position = EM_PE
	var m := await _novo(Vector2(140, TETO + 40.0))
	var ninho := m.global_position
	await _esperar_ate(func() -> bool: return m.estado == Morcego.Estado.VOANDO, 1.5)
	m._espera_do_bote = 99.0
	await _segundos(1.0)
	_player.global_position = Vector2(-2500, EM_PE.y)
	await _esperar_ate(func() -> bool: return m.estado == Morcego.Estado.VOLTANDO, 2.0)
	_checar(m.estado == Morcego.Estado.VOLTANDO, "com a Cacau longe, ele desiste e volta para o ninho")
	await _esperar_ate(func() -> bool: return m.estado == Morcego.Estado.DORMINDO, 6.0)
	_checar(m.estado == Morcego.Estado.DORMINDO and m.global_position.distance_to(ninho) < 1.0,
		"chega no mesmo lugar do teto e dorme de novo")
	await _segundos(0.6)
	var visual := m.get_node("Visual") as AnimatedSprite2D
	_checar(visual.animation == &"dormindo" and absf(angle_difference(visual.rotation, PI)) < 0.15,
		"pendurado de cabeça para baixo outra vez")
	_player.global_position = EM_PE
	await _fisica(3)
	_checar(m.estado == Morcego.Estado.ACORDANDO, "e acorda de novo quando ela volta")
	await _limpar()


func _testar_persistir() -> void:
	print("\n--- PERSISTIR ---")
	_player.global_position = Vector2(-2000, EM_PE.y)
	var m := await _novo(Vector2(0, 300), {"persistir": true, "vida": 1}, "MorcegoQueFica")
	m.levar_golpe(Vector2.RIGHT, 0.0)
	_checar(EstadoMundo.ja_feito(m), "o morcego de \"persistir\" ligado anota a própria morte")
	await _limpar()
	var de_novo: Morcego = (load(MORCEGO) as PackedScene).instantiate()
	de_novo.name = "MorcegoQueFica"
	de_novo.position = Vector2(0, 300)
	de_novo.persistir = true
	add_child(de_novo)
	await _fisica(3)
	_checar(not is_instance_valid(de_novo), "e não volta na visita seguinte")
	EstadoMundo._feitos.erase(str(get_path()) + "/MorcegoQueFica")

	var comum := await _novo(Vector2(0, 300), {"vida": 1}, "MorcegoComum")
	comum.levar_golpe(Vector2.RIGHT, 0.0)
	_checar(not EstadoMundo.ja_feito(comum), "o morcego comum não anota nada: ele volta a cada visita")
	await _limpar()


func _testar_corredores() -> void:
	for caminho: String in CORREDORES:
		print("\n--- %s ---" % caminho.get_file().get_basename().to_upper())
		get_tree().change_scene_to_file(caminho)
		await _fisica(8)
		var cena := get_tree().current_scene
		var player := cena.get_node("Player") as CharacterBody2D
		var bando := get_tree().get_nodes_in_group(Morcego.GRUPO)
		_checar(bando.size() == CORREDORES[caminho], "tem %d morcegos no corredor (esperado %d)"
			% [bando.size(), CORREDORES[caminho]])
		if bando.is_empty():
			continue

		var limites := cena.get_node("LimitesDaCamera") as ReferenceRect
		var pendurados := 0
		var no_quadro := 0
		var em_cima_do_teto := 0
		for m: Morcego in bando:
			if m.estado == Morcego.Estado.DORMINDO:
				pendurados += 1
			var p := m.global_position
			if p.x > limites.position.x and p.x < limites.position.x + limites.size.x \
					and p.y > limites.position.y and p.y < limites.position.y + limites.size.y:
				no_quadro += 1
			# Os pés na face do teto: logo acima da cabeça dele tem tile sólido.
			var raio := PhysicsRayQueryParameters2D.create(p, p - Vector2(0, Morcego.PENDURADO_ABAIXO_DO_TETO + 4.0), 1)
			var teto := (cena as Node2D).get_world_2d().direct_space_state.intersect_ray(raio)
			if not teto.is_empty() and absf(p.y - (teto.position as Vector2).y - Morcego.PENDURADO_ABAIXO_DO_TETO) < 1.0:
				em_cima_do_teto += 1
		_checar(pendurados == bando.size(), "todos dormindo quando ela chega (%d de %d)" % [pendurados, bando.size()])
		_checar(em_cima_do_teto == bando.size(), "pendurados com os pés na face do teto (%d de %d)" % [em_cima_do_teto, bando.size()])
		_checar(no_quadro == bando.size(), "dentro do que a câmera mostra")

		# Longe das duas pontas: quem chega pela porta, pelo elevador ou andando
		# pelo fundo tem tempo de ver o corredor antes de qualquer um acordar.
		var pontas: Array[float] = [(cena.get_node("SpawnPadrao") as Marker2D).global_position.x]
		for no in cena.get_children():
			if no.has_node("PontoDeSaida"):
				pontas.append((no.get_node("PontoDeSaida") as Node2D).global_position.x)
			if no is PassagemDeCena:
				pontas.append((no as Node2D).global_position.x - (no as PassagemDeCena).sentido * (no as PassagemDeCena).distancia_entrada)
		var mais_perto := INF
		for m: Morcego in bando:
			for ponta in pontas:
				mais_perto = minf(mais_perto, absf(m.global_position.x - ponta))
		_checar(mais_perto > 300.0, "nenhum a menos de 300 px de onde ela chega (o mais perto está a %.0f)" % mais_perto)

		await _segundos(1.2)
		var ainda := 0
		for m: Morcego in bando:
			if m.estado == Morcego.Estado.DORMINDO:
				ainda += 1
		_checar(ainda == bando.size() and player.current_health == player.max_health,
			"parada na chegada, ninguém acorda")

		# Ela vai até embaixo do primeiro: ele acorda.
		bando.sort_custom(func(a: Morcego, b: Morcego) -> bool: return a.global_position.x < b.global_position.x)
		var primeiro: Morcego = bando[0]
		player.global_position.x = primeiro.global_position.x - 60.0
		player.velocity = Vector2.ZERO
		var acordou := await _esperar_ate(func() -> bool: return primeiro.estado != Morcego.Estado.DORMINDO, 1.0)
		_checar(acordou, "ela chega embaixo do primeiro e ele acorda")
		await _esperar_ate(func() -> bool: return primeiro.estado == Morcego.Estado.VOANDO, 1.5)
		await _segundos(1.5)
		_checar(primeiro.estado != Morcego.Estado.DORMINDO
				and primeiro.global_position.y > limites.position.y + 80.0
				and primeiro.global_position.y < player.global_position.y,
			"e desce para o meio do corredor, acima dela (y = %.0f)" % primeiro.global_position.y)


# ─────────────────────────────────────────────────────────────

func _montar_sala() -> void:
	_bloco("Chao", CHAO + 20.0)
	_bloco("Teto", TETO - 20.0)

	_player = (load(PLAYER) as PackedScene).instantiate()
	_player.position = EM_PE
	_player.limite_queda = 1.0e9
	add_child(_player)
	_ferramentas = FerramentasPlayer.instalar(_player)
	# Direto na flag, sem passar pela ficha de coleta nem pelo tutorial.
	Progresso._habilidades["bumerangue"] = true
	await _esperar_ate(_player.is_on_floor, 2.0)


func _bloco(nome: String, y: float) -> void:
	var corpo := StaticBody2D.new()
	corpo.name = nome
	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = Vector2(40000, 40)
	forma.shape = retangulo
	corpo.add_child(forma)
	corpo.position = Vector2(0, y)
	add_child(corpo)


## A salinha sai e o teste também sai de cena: as trocas de cena de verdade da
## segunda parte não o apagam.
func _desmontar_sala() -> void:
	await _limpar()
	for filho in get_children():
		filho.queue_free()
	_player = null
	await _fisica(3)
	get_tree().current_scene = null


## Um morcego novo na salinha, já com o ninho achado.
func _novo(pos: Vector2, config: Dictionary = {}, nome: String = "") -> Morcego:
	var m: Morcego = (load(MORCEGO) as PackedScene).instantiate()
	if nome != "":
		m.name = nome
	m.position = pos
	for chave in config:
		m.set(chave, config[chave])
	add_child(m)
	for sinal: String in ["acordou", "levou_golpe", "morreu"]:
		m.connect(sinal, _contar.bind(m, sinal))
	await _fisica(4)
	return m


## Conta as emissões de cada sinal, por morcego. (O levou_golpe traz um
## argumento antes dos que o bind acrescenta.)
func _contar(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
	var sinal: String = c if c != null else b
	var m: Variant = b if c != null else a
	if not _sinais.has(m):
		_sinais[m] = {}
	_sinais[m][sinal] = _sinais[m].get(sinal, 0) + 1


## Tira os morcegos da sala e devolve a Cacau inteira, livre e de mão cheia.
func _limpar() -> void:
	for m in get_tree().get_nodes_in_group(Morcego.GRUPO):
		m.queue_free()
	_sinais.clear()
	_soltar_tudo()
	if _player == null:
		await _fisica(2)
		return
	await _recolher()
	# A invencibilidade de um dano anterior escoa em relógio próprio do player.
	await _esperar_ate(func() -> bool: return not _player.esta_invencivel and _player.pode_se_mover, 3.0)
	_player.current_health = _player.max_health
	_player.velocity = Vector2.ZERO
	_player.global_position = Vector2(-2000, EM_PE.y)
	await _fisica(3)


## Um toque de F, visto pela física (é lá que as ferramentas leem o botão).
func _arremessar() -> void:
	await get_tree().physics_frame
	Input.action_press("arremessar")
	await _fisica(2)
	Input.action_release("arremessar")


func _recolher() -> void:
	_soltar_tudo()
	await _esperar_ate(func() -> bool: return not _ferramentas._bumerangue_no_ar, 8.0)
	await _esperar_ate(func() -> bool: return _player._arremesso_restante <= 0.0, 2.0)


func _soltar_tudo() -> void:
	for acao in ["ui_left", "ui_right", "jump", "arremessar"]:
		Input.action_release(acao)


## Espera `n` quadros de física de JOGO. Quadro com o jogo congelado (o
## congelamento de impacto dura um tempo de RELÓGIO, e com --fixed-fps cabem
## centenas de quadros parados dentro dele) não conta: nele o tempo não andou.
func _fisica(n: int) -> void:
	var contados := 0
	while contados < n:
		await get_tree().physics_frame
		if Engine.time_scale > 0.0:
			contados += 1


## Espera em tempo de JOGO (quadros de física), e não no relógio.
func _segundos(s: float) -> void:
	await _fisica(ceili(s * 60.0))


## Espera a condição valer, no máximo `teto` segundos de jogo. Devolve se valeu.
func _esperar_ate(condicao: Callable, teto: float = 5.0) -> bool:
	var contados := 0
	while contados < ceili(teto * 60.0):
		if condicao.call():
			return true
		await get_tree().physics_frame
		if Engine.time_scale > 0.0:
			contados += 1
	return condicao.call()
