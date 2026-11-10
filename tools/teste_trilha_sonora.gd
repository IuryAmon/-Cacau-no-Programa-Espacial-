extends Node

# Teste da trilha sonora (scripts/trilha_sonora.gd):
#
#   godot --headless --path . res://tools/teste_trilha_sonora.tscn
#
# Casos:
#   * cada lugar com a sua música: o céu aberto (world1, pátio, rua da
#     torre, telhado) com a música da hora; a oficina com a da fase 1; os dois
#     corredores com a do esgoto; a torre por dentro com o SPY JAZZ; a
#     introdução com a intro1; o menu, o laboratório e as salas da rua em
#     silêncio;
#   * a mesma música não recomeça: morrer (a fase recarrega) e passar para
#     outra cena com a mesma música deixam ela seguir de onde estava; uma
#     música diferente entra e a que saiu some;
#   * a hora muda com a fase aberta: a música da hora nova entra enquanto a
#     velha some, em FADE_DA_HORA;
#   * pausar e continuar (o que a cena do mirante usa): a trilha some e espera
#     parada; volta de onde parou, ou já com a música nova se a hora mudou no
#     meio; trocar de cena solta a pausa;
#   * toda música toca em loop e segue tocando com o jogo pausado;
#   * a fase 1 abre sem erro de script: a plataforma que cai tem o som dela.

const MENU := "res://scenes/menu_principal.tscn"
const INTRODUCAO := "res://scenes/introducao.tscn"
const MUNDO := "res://scenes/world1.tscn"
const LAB := "res://scenes/laboratório_(world_2).tscn"
const OFICINA := "res://scenes/fases/fase1_oficina.tscn"
const CORREDOR_PATIO := "res://scenes/fases/corredor_patio.tscn"
const PATIO := "res://scenes/fases/fase1_2_exterior.tscn"
const CORREDOR_TORRE := "res://scenes/fases/corredor_torre.tscn"
const TORRE := "res://scenes/fases/fase2_torre.tscn"
const TORRE_POR_DENTRO := "res://scenes/fases/fase2_torre_interior.tscn"
const TELHADO := "res://scenes/fases/fase2_telhado.tscn"
const SALA_COMPRESSOR := "res://scenes/fases/fase2_sala_compressor.tscn"
const SALA_DESTILACAO := "res://scenes/fases/fase2_sala_destilacao.tscn"

const DA_TARDE := "res://sounds/Trilhas/bossa nova estilo stardew valley.mp3"
const DO_SOL_POSTO := "res://sounds/Trilhas/bossa nova estila stardew valley2.mp3"
const DA_NOITE := "res://sounds/Trilhas/jazz noite.mp3"
const DA_INTRODUCAO := "res://sounds/Trilhas/intro1.mp3"
const DA_FASE1 := "res://sounds/Trilhas/fase1.mp3"
const DO_ESGOTO := "res://sounds/Trilhas/esgoto ou algo assim.mp3"
const DA_TORRE := "res://sounds/Trilhas/SPY JAZZ - dentro da torre.mp3"
const SOM_DA_PLATAFORMA := "res://sounds/plataforma-caindo-som.mp3"

var _falhas := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# O teste sai de cena: as trocas de cena de verdade não o apagam.
	get_tree().current_scene = null
	_rodar()


func _rodar() -> void:
	await _testar_cada_lugar()
	await _testar_sem_recomecar()
	await _testar_a_hora_mudando()
	await _testar_pausar_e_continuar()
	await _testar_loop_e_jogo_pausado()
	await _testar_plataforma_da_fase1()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


## De tarde, sem cutscene pendente: o laboratório não abre na revelação e o
## mirante não dispara.
func _zerar_a_partida() -> void:
	EstadoMundo.anoiteceu = false
	EstadoMundo.sol_se_pos = false
	EstadoMundo.viu_o_foguete = true
	EstadoMundo.revelou_dr_chico = true
	EstadoMundo.abertura_pendente = false


# ─────────────────────────────────────────────────────────────

func _testar_cada_lugar() -> void:
	print("\n--- CADA LUGAR COM A SUA MÚSICA (DE TARDE) ---")
	_zerar_a_partida()
	var lugares := [
		[MENU, "", "o menu (por enquanto sem música, mesmo de céu aberto)"],
		[INTRODUCAO, DA_INTRODUCAO, "a introdução"],
		[MUNDO, DA_TARDE, "o world1"],
		[LAB, "", "o laboratório"],
		[OFICINA, DA_FASE1, "a oficina (fase 1)"],
		[CORREDOR_PATIO, DO_ESGOTO, "o corredor do pátio"],
		[PATIO, DA_TARDE, "o pátio da fornalha"],
		[CORREDOR_TORRE, DO_ESGOTO, "o corredor da torre"],
		[TORRE, DA_TARDE, "a rua da torre"],
		[TORRE_POR_DENTRO, DA_TORRE, "a torre por dentro"],
		[TELHADO, DA_TARDE, "o telhado da torre"],
		[SALA_COMPRESSOR, "", "a sala do compressor"],
		[SALA_DESTILACAO, "", "a sala de destilação"],
	]
	for lugar: Array in lugares:
		await _abrir(lugar[0])
		var esperada: String = lugar[1]
		var tocando := _musica_tocando()
		var certo := tocando == esperada
		if not esperada.is_empty():
			certo = certo and TrilhaSonora._tocador != null and TrilhaSonora._tocador.playing
		_checar(certo, "%s: %s%s" % [lugar[2], _nome(esperada), "" if certo else " (tocou %s)" % _nome(tocando)])


func _testar_sem_recomecar() -> void:
	print("\n--- A MESMA MÚSICA NÃO RECOMEÇA ---")
	_zerar_a_partida()
	await _abrir(TORRE)
	await _segundos(0.6)
	var tocador := TrilhaSonora._tocador
	var antes := tocador.get_playback_position()
	# Morrer recarrega a fase (player.gd).
	get_tree().reload_current_scene()
	await _quadros(3)
	_checar(TrilhaSonora._tocador == tocador and antes > 0.0 and tocador.get_playback_position() >= antes,
		"morrer (a fase recarrega) não recomeça a música (%.1f s -> %.1f s)" % [antes, tocador.get_playback_position()])
	await _abrir(TELHADO)
	_checar(TrilhaSonora._tocador == tocador, "da rua para o telhado, com a mesma música, ela só segue")

	await _abrir(TORRE_POR_DENTRO)
	var nova := TrilhaSonora._tocador
	_checar(nova != tocador and _musica_tocando() == DA_TORRE, "entrando na torre, outra música entra")
	await _segundos(TrilhaSonora.FADE_PADRAO + 0.2)
	_checar(not is_instance_valid(tocador), "e a que saiu sumiu (em %.1f s)" % TrilhaSonora.FADE_PADRAO)
	var volume: float = get_tree().current_scene.volume_da_musica_db
	_checar(is_equal_approx(nova.volume_db, volume), "a nova chegou ao volume da cena (%.1f dB)" % nova.volume_db)


func _testar_a_hora_mudando() -> void:
	print("\n--- A HORA MUDA COM A FASE ABERTA ---")
	_zerar_a_partida()
	await _abrir(TORRE)
	await _segundos(TrilhaSonora.FADE_PADRAO + 0.2)
	var cena := get_tree().current_scene
	var atm := Atmosfera.da_cena(cena)
	var da_tarde := TrilhaSonora._tocador
	Atmosfera.definir_hora_da_partida(cena, Atmosfera.Momento.CREPUSCULO)
	var do_sol_posto := TrilhaSonora._tocador
	_checar(_musica_tocando() == DO_SOL_POSTO and do_sol_posto != da_tarde,
		"o sol se pôs: entra a bossa do sol posto")
	await _segundos(TrilhaSonora.FADE_DA_HORA * 0.5)
	_checar(is_instance_valid(da_tarde) and da_tarde.volume_db < atm.volume_da_musica_db - 3.0
		and do_sol_posto.volume_db > TrilhaSonora.MUDO_DB + 3.0,
		"no meio da troca, a da tarde vai sumindo e a outra crescendo")
	await _segundos(TrilhaSonora.FADE_DA_HORA * 0.5 + 0.3)
	_checar(not is_instance_valid(da_tarde) and is_equal_approx(do_sol_posto.volume_db, atm.volume_da_musica_db),
		"em %.0f s a troca termina" % TrilhaSonora.FADE_DA_HORA)
	Atmosfera.definir_hora_da_partida(cena, Atmosfera.Momento.NOITE)
	_checar(_musica_tocando() == DA_NOITE, "a noite caiu: entra o jazz")


func _testar_pausar_e_continuar() -> void:
	print("\n--- PAUSAR E CONTINUAR ---")
	_zerar_a_partida()
	await _abrir(MUNDO)
	await _segundos(TrilhaSonora.FADE_PADRAO + 0.2)
	var tocador := TrilhaSonora._tocador
	var volume := tocador.volume_db
	TrilhaSonora.pausar(0.1)
	await _segundos(0.3)
	var onde_parou := tocador.get_playback_position()
	await _segundos(0.4)
	_checar(TrilhaSonora.esta_pausada() and tocador.stream_paused
		and absf(tocador.get_playback_position() - onde_parou) < 0.05,
		"pausar: a trilha some e espera, parada em %.1f s" % onde_parou)
	TrilhaSonora.continuar(0.1)
	await _segundos(0.3)
	_checar(TrilhaSonora._tocador == tocador and not TrilhaSonora.esta_pausada() and not tocador.stream_paused
		and tocador.get_playback_position() >= onde_parou and tocador.get_playback_position() < onde_parou + 1.0
		and is_equal_approx(tocador.volume_db, volume),
		"continuar: ela volta de onde tinha parado (%.1f s)" % tocador.get_playback_position())

	TrilhaSonora.pausar(0.1)
	await _segundos(0.3)
	Atmosfera.definir_hora_da_partida(get_tree().current_scene, Atmosfera.Momento.CREPUSCULO)
	_checar(TrilhaSonora._tocador == tocador and tocador.stream_paused and _musica_tocando() == DA_TARDE,
		"com a trilha pausada, a hora que muda espera")
	TrilhaSonora.continuar(0.1)
	_checar(_musica_tocando() == DO_SOL_POSTO and TrilhaSonora._tocador != tocador and not TrilhaSonora.esta_pausada(),
		"e no continuar já entra a bossa do sol posto")

	TrilhaSonora.pausar(0.1)
	await _abrir(OFICINA)
	_checar(not TrilhaSonora.esta_pausada() and _musica_tocando() == DA_FASE1
		and TrilhaSonora._tocador.playing and not TrilhaSonora._tocador.stream_paused,
		"trocar de cena solta a pausa: a cena nova toca a dela")


func _testar_loop_e_jogo_pausado() -> void:
	print("\n--- EM LOOP, E COM O JOGO PAUSADO ---")
	_zerar_a_partida()
	await _abrir(CORREDOR_TORRE)
	var tocador := TrilhaSonora._tocador
	_checar(tocador != null and tocador.stream.get("loop") == true, "a música toca em loop")
	get_tree().paused = true
	var antes := tocador.get_playback_position()
	await _segundos(0.4)
	var depois := tocador.get_playback_position()
	get_tree().paused = false
	_checar(depois > antes + 0.1 and tocador.playing and not tocador.stream_paused,
		"com o jogo pausado (caderno, mochila, puzzles) ela segue tocando (%.1f s -> %.1f s)" % [antes, depois])


func _testar_plataforma_da_fase1() -> void:
	print("\n--- A FASE 1 ABRE SEM ERRO DE SCRIPT ---")
	_zerar_a_partida()
	await _abrir(OFICINA)
	var plataformas := get_tree().current_scene.find_children("*", "PlataformasQueCaem", true, false)
	var com_som := not plataformas.is_empty() and plataformas.all(func(p: Node) -> bool:
		return p.som_queda != null and p.som_queda.resource_path == SOM_DA_PLATAFORMA)
	_checar(com_som, "a plataforma que cai carrega, com o som de queda (%d na oficina)" % plataformas.size())


# ─────────────────────────────────────────────────────────────

## O arquivo da música que a TrilhaSonora está tocando ("" no silêncio).
func _musica_tocando() -> String:
	var musica := TrilhaSonora.musica_atual()
	return musica.resource_path if musica != null else ""


func _nome(caminho: String) -> String:
	return caminho.get_file() if not caminho.is_empty() else "silêncio"


func _abrir(caminho: String) -> void:
	get_tree().change_scene_to_file(caminho)
	await _quadros(3)
	# (O rádio do Dr. Chico pode chamar na chegada: o teste não é dele.)
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()
		await _quadros(2)


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _segundos(s: float) -> void:
	var resta := s
	while resta > 0.0:
		await get_tree().process_frame
		resta -= get_process_delta_time()


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1
