extends Node

# Teste da porta modelo (scenes/fases/componentes/porta_modelo.tscn) nas
# entradas das fases que ainda não tinham arte:
#
#   godot --headless --fixed-fps 60 --path . res://tools/teste_porta_modelo.tscn
#
# (Roda como cena, e não com -s: o alçapão é uma PortaFase, e o porta_fase.gd
# só compila com os autoloads já carregados.)
#
# Casos:
#   * a cena é a porta da ala de eletrólise com o "porta modelo.png": 12
#     quadros de 148x134, abrindo 0->11 e fechando ao contrário;
#   * Torre de Gases, Torre de Lançamento, as voltas ao laboratório (fases 2, 3
#     e final) e a cápsula usam a porta modelo; só o alçapão do fosso continua
#     PortaFase;
#   * toda porta com destino acha, na outra cena, a porta que a recebe (ou a
#     passagem: a ponta do corredor da torre é uma PassagemDeCena);
#   * cada porta nova fica em pé no chão (o vão dela na altura do piso);
#   * a viagem de verdade: laboratório -> corredor -> Torre e a volta pelo
#     mesmo caminho (o corredor tem um teste só dele, teste_corredor_torre),
#     alçapão do fosso -> subsolo -> alçapão, e a cápsula não deixa a volta da
#     órbita sair pela porta do simulador.

const LAB := "res://scenes/laboratório_(world_2).tscn"
const FASE1 := "res://scenes/fases/fase1_oficina.tscn"
const CORREDOR := "res://scenes/fases/corredor_torre.tscn"
const FASE2 := "res://scenes/fases/fase2_torre.tscn"
const FASE3 := "res://scenes/fases/fase3_subsolo.tscn"
const FASE_FINAL := "res://scenes/fases/fase_final.tscn"
const ORBITA := "res://scenes/fases/final_orbita.tscn"
const SIMULADOR := "res://scenes/simulador_(world_3).tscn"

const MODELO := "res://scenes/fases/componentes/porta_modelo.tscn"
const FOLHA := "res://assets/porta/porta modelo.png"
const SCRIPT_PORTA := "res://scripts/porta_simulador.gd"

## As portas que ganharam a porta modelo.
const PORTAS_MODELO := {
	LAB: ["PortaTorre", "PortaLancamento"],
	CORREDOR: ["PortaLab"],
	FASE2: ["PortaHub"],
	FASE3: ["Atrio/PortaFosso"],
	FASE_FINAL: ["Portao/PortaHub", "Plataforma/Capsula/PortaCapsula"],
}
## Do centro da cápsula da Cacau até a sola.
const ATE_A_SOLA := 36.0

var _falhas := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# O teste sai de cena: as trocas de cena de verdade não o apagam.
	get_tree().current_scene = null
	_rodar()


func _rodar() -> void:
	EstadoMundo.revelou_dr_chico = true
	_testar_cena_modelo()
	await _testar_portas_nas_cenas()
	await _testar_torre_ida_e_volta()
	await _testar_fosso_ida_e_volta()
	await _testar_capsula()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


# ─────────────────────────────────────────────────────────────

func _testar_cena_modelo() -> void:
	print("\n--- A PORTA MODELO ---")
	var porta := (load(MODELO) as PackedScene).instantiate()
	_checar(porta.get_script() == load(SCRIPT_PORTA), "usa o script das portas da oficina (porta_simulador.gd)")
	var sprite := porta.get_node("SpritePorta") as AnimatedSprite2D
	var quadros := sprite.sprite_frames
	var abrindo := quadros.get_frame_count(&"abrindo")
	_checar(abrindo == 12 and quadros.get_frame_count(&"fechando") == 12, "abrindo e fechando com 12 quadros")
	var em_ordem := true
	for i in abrindo:
		var q := quadros.get_frame_texture(&"abrindo", i) as AtlasTexture
		var volta := quadros.get_frame_texture(&"fechando", abrindo - 1 - i) as AtlasTexture
		em_ordem = em_ordem and q.atlas.resource_path == FOLHA and q.region == Rect2(148 * i, 0, 148, 134) \
			and volta.region == q.region
	_checar(em_ordem, "os quadros saem do \"porta modelo.png\", 148x134 em fila, e o fechando é o abrindo ao contrário")
	var textura := load(FOLHA) as Texture2D
	_checar(textura.get_size() == Vector2(148 * 12, 134), "a folha tem 12 quadros de 148x134 (%s)" % textura.get_size())
	var ala := (load("res://scenes/fases/componentes/porta_ala_eletrolise.tscn") as PackedScene).instantiate()
	_checar(_mesma_estrutura(porta, ala), "o resto é igual à porta da ala de eletrólise")
	porta.free()
	ala.free()


## Os mesmos nós, nas mesmas posições.
func _mesma_estrutura(a: Node, b: Node) -> bool:
	var nomes_a := a.get_children().map(func(n: Node) -> String: return n.name)
	var nomes_b := b.get_children().map(func(n: Node) -> String: return n.name)
	if nomes_a != nomes_b:
		return false
	for filho in a.get_children():
		var outro := b.get_node(NodePath(filho.name))
		if filho is Node2D and (filho as Node2D).transform != (outro as Node2D).transform:
			return false
	return true


func _testar_portas_nas_cenas() -> void:
	print("\n--- AS PORTAS NAS CENAS ---")
	# Quem recebe em cada cena: tag_aqui -> porta.
	var recebe := {}
	var saidas: Array[Dictionary] = []
	for caminho in [LAB, FASE1, CORREDOR, FASE2, FASE3, FASE_FINAL, SIMULADOR]:
		await _abrir(caminho)
		var cena := get_tree().current_scene
		recebe[caminho] = {}
		for porta in _portas(cena):
			var eh_fase := porta is PortaFase
			if eh_fase or porta.recebe_chegada:
				recebe[caminho][porta.tag_aqui] = porta.name
			if porta.cena_destino != "":
				saidas.append({"de": caminho, "porta": str(cena.get_path_to(porta)), "para": porta.cena_destino,
					"tag": porta.tag_destino})
		# As pontas abertas (PassagemDeCena) entram no mesmo jogo de tags.
		for passagem in _passagens(cena):
			if passagem.tag_aqui != "":
				recebe[caminho][passagem.tag_aqui] = passagem.name
			if passagem.cena_destino != "":
				saidas.append({"de": caminho, "porta": str(cena.get_path_to(passagem)),
					"para": passagem.cena_destino, "tag": passagem.tag_destino})
		for nome in PORTAS_MODELO.get(caminho, []):
			var porta := cena.get_node(NodePath(nome))
			_checar(porta.scene_file_path == MODELO, "%s/%s é a porta modelo" % [caminho.get_file(), nome])
			var sola := (porta.get_node("PontoDeSaida") as Marker2D).global_position.y + ATE_A_SOLA
			var chao := _chao_abaixo(cena, (porta as Node2D).global_position)
			_checar(absf(sola - chao) <= 5.0, "   em pé no chão (vão em %.0f, chão em %.0f)" % [sola, chao])
		var fase_restantes := _portas(cena).filter(func(p: Node) -> bool: return p is PortaFase)
		var nomes := fase_restantes.map(func(p: Node) -> String: return str(p.name))
		var esperado := ["FossoVentilacao"] if caminho == LAB else []
		_checar(nomes == esperado, "%s: PortaFase que sobrou: %s" % [caminho.get_file(), nomes])

	for s in saidas:
		if s.para == ORBITA:
			continue
		var achou: String = recebe.get(s.para, {}).get(s.tag, "")
		_checar(achou != "", "%s %s -> %s: quem recebe \"%s\" é %s" % [s.de.get_file(), s.porta, s.para.get_file(), s.tag, achou])


func _testar_torre_ida_e_volta() -> void:
	print("\n--- LABORATÓRIO -> CORREDOR -> TORRE -> CORREDOR -> LABORATÓRIO ---")
	# A porta da Torre dá num corredor, e é o fundo dele que leva à fase.
	await _abrir(LAB)
	await _usar(get_tree().current_scene.get_node("PortaTorre"))
	await _esperar_cena(CORREDOR)
	await _conferir_saida(get_tree().current_scene.get_node("PortaLab"), "chegou no corredor saindo pela porta dele")

	# Cruzou a linha do fundo, a cena troca sozinha.
	var saida := get_tree().current_scene.get_node("SaidaTorre") as PassagemDeCena
	await _quadros(2)
	_player().global_position.x = saida.global_position.x + 4.0
	await _esperar_cena(FASE2)
	await _conferir_saida(get_tree().current_scene.get_node("PortaHub"), "chegou na Torre saindo pela PortaHub")

	await _usar(get_tree().current_scene.get_node("PortaHub"))
	await _esperar_cena(CORREDOR)
	saida = get_tree().current_scene.get_node("SaidaTorre") as PassagemDeCena
	for i in 300:
		if not saida._chegando:
			break
		await get_tree().process_frame
	_checar(not saida._chegando and _player().pode_se_mover
		and _player().global_position.x < saida.global_position.x,
		"voltou pelo fundo do corredor e entrou andando")

	await _usar(get_tree().current_scene.get_node("PortaLab"))
	await _esperar_cena(LAB)
	await _conferir_saida(get_tree().current_scene.get_node("PortaTorre"), "voltou ao laboratório saindo pela porta da Torre")


func _testar_fosso_ida_e_volta() -> void:
	print("\n--- ALÇAPÃO DO FOSSO -> SUBSOLO -> ALÇAPÃO ---")
	await _abrir(LAB)
	var alcapao := get_tree().current_scene.get_node("FossoVentilacao") as PortaFase
	alcapao.requer_habilidade = ""  # a mochila não é o assunto aqui
	alcapao._tentar_entrar()
	await _esperar_cena(FASE3)
	await _conferir_saida(get_tree().current_scene.get_node("Atrio/PortaFosso"),
		"desceu pelo alçapão e saiu pela porta do átrio (PortaFase -> porta modelo)")
	_checar(Progresso.spawn_tag == "", "a tag do Progresso foi consumida")

	await _usar(get_tree().current_scene.get_node("Atrio/PortaFosso"))
	await _esperar_cena(LAB)
	await _quadros(5)
	var player := _player()
	alcapao = get_tree().current_scene.get_node("FossoVentilacao") as PortaFase
	# A PortaFase põe o centro da Cacau dentro do piso e a física a tira de lá
	# de lado (uns 18 px): é o jeito antigo dela, que o alçapão mantém.
	_checar(absf(player.global_position.x - alcapao.global_position.x) < 24.0,
		"voltou ao laboratório no alçapão (x = %.0f, alçapão em %.0f)" % [player.global_position.x, alcapao.global_position.x])
	_checar(Progresso.spawn_tag == "", "e a tag foi consumida")
	await _segundos(1.5)  # o laboratório termina de clarear


func _testar_capsula() -> void:
	print("\n--- A CÁPSULA ---")
	await _abrir(FASE_FINAL)
	await _usar(get_tree().current_scene.get_node("Plataforma/Capsula/PortaCapsula"))
	await _esperar_cena(ORBITA)
	_checar(true, "embarcou e chegou à órbita")
	await _segundos(2.0)  # a órbita clareia antes de a Cacau poder seguir
	# O que a órbita faz ao apertar para continuar (final_orbita.gd).
	Progresso.spawn_tag = ""
	FadeTela.trocar_cena(get_tree().current_scene, EstadoMundo.CENA_WORLD2)
	await _esperar_cena(LAB)
	await _segundos(0.5)
	var simulador := get_tree().current_scene.get_node("PortaSimulador")
	_checar(not simulador._ocupada and _player().pode_se_mover and _player().visible,
		"de volta ao laboratório, ninguém sai pela porta do simulador")


# ─────────────────────────────────────────────────────────────

## Portas desta cena: as da oficina/simulador (porta_simulador.gd) e as PortaFase.
func _portas(cena: Node) -> Array:
	var script_porta := load(SCRIPT_PORTA)
	return cena.find_children("*", "Area2D", true, false).filter(func(n: Node) -> bool:
		return n is PortaFase or n.get_script() == script_porta)


## As pontas abertas desta cena (passagem_de_cena.gd).
func _passagens(cena: Node) -> Array:
	return cena.find_children("*", "Node2D", true, false).filter(func(n: Node) -> bool:
		return n is PassagemDeCena)


func _chao_abaixo(cena: Node, ponto: Vector2) -> float:
	var espaco := (cena as Node2D).get_world_2d().direct_space_state
	var raio := PhysicsRayQueryParameters2D.create(ponto, ponto + Vector2(0, 400), 1)
	var achou := espaco.intersect_ray(raio)
	return (achou.position as Vector2).y if not achou.is_empty() else INF


## A Cacau, parada um pouco ao lado do vão, aperta para cima.
func _usar(porta: Node) -> void:
	var player := _player()
	await _segundos(0.3)
	player.global_position = (porta.get_node("PontoDeSaida") as Marker2D).global_position + Vector2(60, -2)
	player.velocity = Vector2.ZERO
	porta._player = player
	porta._player_dentro = true
	porta._usar_porta()


## Espera a sequência de chegada acabar e confere onde ela terminou.
func _conferir_saida(porta: Node, descricao: String) -> void:
	var sprite := porta.get_node("SpritePorta") as AnimatedSprite2D
	var abriu := false
	for i in 400:
		await get_tree().process_frame
		abriu = abriu or sprite.animation == &"abrindo"
		if abriu and not porta._ocupada:
			break
	var player := _player()
	var saida := (porta.get_node("PontoDeSaida") as Marker2D).global_position
	_checar(abriu and not porta._ocupada, descricao)
	_checar(player.visible and player.pode_se_mover and sprite.animation == &"fechada",
		"   ela aparece, anda e a porta fecha atrás dela")
	_checar(player.global_position.distance_to(saida) < 8.0,
		"   na frente da porta (%s, vão em %s)" % [player.global_position.round(), saida.round()])


func _esperar_cena(caminho: String) -> void:
	for i in 900:
		if get_tree().current_scene and get_tree().current_scene.scene_file_path == caminho:
			await _quadros(2)
			return
		await get_tree().process_frame
	_checar(false, "a cena %s não abriu" % caminho.get_file())


func _abrir(caminho: String) -> void:
	get_tree().change_scene_to_file(caminho)
	await _quadros(3)


func _player() -> CharacterBody2D:
	return get_tree().current_scene.get_node("Player") as CharacterBody2D


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _segundos(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1
