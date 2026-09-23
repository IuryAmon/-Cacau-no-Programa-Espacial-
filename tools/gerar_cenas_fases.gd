extends Node

# --- GERADOR DO BLOCKOUT DAS FASES ---
#
# Constrói (uma vez) as cenas .tscn das fases e dos componentes, já com
# TileMapLayer pintado, nós nomeados e slots de sprite vazios. Depois disso o
# trabalho é todo no editor: mover nós, trocar sprites, repintar tiles.
#
# Rodar de novo SOBRESCREVE as cenas — use só para recomeçar o blockout do
# zero. Como rodar:
#   godot --headless --path . res://tools/gerar_cenas_fases.tscn
#
# Detalhe técnico: as árvores são montadas FORA da SceneTree, então nenhum
# _ready() de componente roda durante a geração (senão os componentes se
# comportariam como no jogo — sumindo, conectando sinais — e isso entraria no
# arquivo salvo).

const DIR_COMPONENTES := "res://scenes/fases/componentes/"
const DIR_FASES := "res://scenes/fases/"
const CENA_PLAYER := "res://scenes/player.tscn"
const TILESET := "res://assets/tilesets/tileset_fases.tres"

# Tiles do tileset industrial já usado no laboratório (fonte 13) e do fundo
# (fonte 14). Os dois primeiros têm colisão.
const FONTE_TILES := 13
const TILE_TOPO := Vector2i(2, 0)
const TILE_CORPO := Vector2i(2, 2)
const FONTE_FUNDO := 14
## Lado do tile no mundo: 16px do atlas x escala 2 do TileMapLayer.
const CELULA := 32.0

var _tileset: TileSet = null


func _ready() -> void:
	_tileset = load(TILESET)
	if _tileset == null:
		push_error("Não achei o tileset em " + TILESET)
		get_tree().quit(1)
		return

	DirAccess.make_dir_recursive_absolute(DIR_COMPONENTES)

	_gerar_componentes()
	_gerar_hub_fases()
	_gerar_fase1()
	_gerar_fase2()
	_gerar_fase3()
	_gerar_fase_final()
	_gerar_final_orbita()

	print("\n>>> GERACAO CONCLUIDA <<<")
	get_tree().quit(0)


# ============================================================================
#  APOIO
# ============================================================================

func _salvar(raiz: Node, caminho: String) -> void:
	_atribuir_dono(raiz, raiz)
	var pacote := PackedScene.new()
	var erro := pacote.pack(raiz)
	if erro != OK:
		push_error("Falha ao empacotar %s (erro %d)" % [caminho, erro])
		return
	erro = ResourceSaver.save(pacote, caminho)
	print(("  ok  " if erro == OK else "  ERRO ") + caminho)
	raiz.free()


# Todo nó precisa de "owner" para ser salvo. Nós que são instâncias de outra
# cena (scene_file_path preenchido) não têm os filhos percorridos: eles
# pertencem à cena instanciada e continuam editáveis por lá.
func _atribuir_dono(no: Node, raiz: Node) -> void:
	for filho in no.get_children():
		filho.owner = raiz
		if filho.scene_file_path == "":
			_atribuir_dono(filho, raiz)


func _no(pai: Node, tipo, nome: String, pos: Vector2 = Vector2.ZERO) -> Node:
	var novo = tipo.new()
	novo.name = nome
	if novo is Node2D:
		novo.position = pos
	elif novo is Control:
		novo.position = pos
	pai.add_child(novo)
	return novo


func _rect(pai: Node, nome: String, tamanho: Vector2, cor: Color, centro: Vector2 = Vector2.ZERO, z: int = 0) -> ColorRect:
	var r := ColorRect.new()
	r.name = nome
	r.size = tamanho
	r.position = centro - tamanho / 2.0
	r.color = cor
	r.z_index = z
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(r)
	return r


func _colisao(pai: Node, tamanho: Vector2, centro: Vector2 = Vector2.ZERO, nome: String = "Colisao") -> CollisionShape2D:
	var c := CollisionShape2D.new()
	c.name = nome
	var forma := RectangleShape2D.new()
	forma.size = tamanho
	c.shape = forma
	c.position = centro
	pai.add_child(c)
	return c


func _label(pai: Node, nome: String, texto: String, centro: Vector2, largura: float = 260.0, tamanho_fonte: int = 12, cor: Color = Color(0.88, 0.9, 0.94)) -> Label:
	var l := Label.new()
	l.name = nome
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho_fonte)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size = Vector2(largura, 46)
	l.position = centro - l.size / 2.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(l)
	return l


func _particulas(pai: Node, nome: String, config: Dictionary) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = nome
	p.gravity = Vector2.ZERO
	for chave in config:
		p.set(chave, config[chave])
	pai.add_child(p)
	return p


func _marker(pai: Node, nome: String, pos: Vector2) -> Marker2D:
	var m := Marker2D.new()
	m.name = nome
	m.position = pos
	pai.add_child(m)
	return m


func _instanciar(pai: Node, cena: String, nome: String, pos: Vector2, props: Dictionary = {}) -> Node:
	var no: Node = load(cena).instantiate()
	no.name = nome
	if no is Node2D:
		no.position = pos
	for chave in props:
		no.set(chave, props[chave])
	pai.add_child(no)
	return no


# --- TILEMAP ---

func _camada_tiles(pai: Node, nome: String, z: int) -> TileMapLayer:
	var camada := TileMapLayer.new()
	camada.name = nome
	camada.tile_set = _tileset
	camada.scale = Vector2(2, 2)
	camada.z_index = z
	pai.add_child(camada)
	return camada


## Pinta um retângulo do mundo com chão sólido: a primeira linha usa o tile de
## topo, as de baixo o tile de corpo (os dois têm colisão).
func _pintar_solido(camada: TileMapLayer, rect: Rect2) -> void:
	var x0 := int(floor(rect.position.x / CELULA))
	var x1 := int(ceil(rect.end.x / CELULA))
	var y0 := int(floor(rect.position.y / CELULA))
	var y1 := int(ceil(rect.end.y / CELULA))
	for cy in range(y0, maxi(y1, y0 + 1)):
		for cx in range(x0, maxi(x1, x0 + 1)):
			var tile := TILE_TOPO if cy == y0 else TILE_CORPO
			camada.set_cell(Vector2i(cx, cy), FONTE_TILES, tile)


## Preenche um retângulo com o tile de fundo (sem colisão).
func _pintar_fundo(camada: TileMapLayer, rect: Rect2) -> void:
	var x0 := int(floor(rect.position.x / CELULA))
	var x1 := int(ceil(rect.end.x / CELULA))
	var y0 := int(floor(rect.position.y / CELULA))
	var y1 := int(ceil(rect.end.y / CELULA))
	for cy in range(y0, y1):
		for cx in range(x0, x1):
			var tile := Vector2i(posmod(cx, 2), posmod(cy, 2))
			camada.set_cell(Vector2i(cx, cy), FONTE_FUNDO, tile)


# --- ESTRUTURA COMUM DAS FASES ---

func _montar_fase(nome: String, script: String) -> Node2D:
	var raiz := Node2D.new()
	raiz.name = nome
	raiz.set_script(load(script))
	return raiz


func _fechar_fase(raiz: Node2D, spawn: Vector2, limites: Rect2) -> void:
	_marker(raiz, "SpawnPadrao", spawn)

	var ref := ReferenceRect.new()
	ref.name = "LimitesDaCamera"
	ref.position = limites.position
	ref.size = limites.size
	ref.editor_only = true
	ref.border_color = Color(1, 0.6, 0.2, 0.55)
	ref.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(ref)

	var player: Node = load(CENA_PLAYER).instantiate()
	player.name = "Player"
	player.position = spawn
	if "z_index" in player:
		player.z_index = 2
	raiz.add_child(player)


# ============================================================================
#  COMPONENTES
# ============================================================================

func _gerar_componentes() -> void:
	print("\n--- COMPONENTES ---")
	_comp_alvo_bumerangue()
	_comp_interruptor()
	_comp_bloco_alternavel()
	_comp_chapa_soldada()
	_comp_chama()
	_comp_corrente_vapor()
	_comp_piso_eletrificado()
	_comp_valvula_purga()
	_comp_pickup_habilidade()
	_comp_celula_chonps()
	_comp_porta_fase()
	_comp_mesa_puzzle()
	_comp_estacao_recarga()
	_comp_masseira()
	_comp_casca_babacu()
	_comp_retorta()


func _comp_alvo_bumerangue() -> void:
	var raiz := Area2D.new()
	raiz.name = "AlvoBumerangue"
	raiz.set_script(load("res://scripts/fases/alvo_bumerangue.gd"))
	_no(raiz, Sprite2D, "Sprite")
	var ativo := _no(raiz, Sprite2D, "SpriteAtivo") as Sprite2D
	ativo.visible = false
	var ph := _rect(raiz, "Placeholder", Vector2(34, 34), Color(0.12, 0.12, 0.15))
	_rect(ph, "Miolo", Vector2(24, 24), Color(0.85, 0.3, 0.3), Vector2(17, 17))
	_colisao(raiz, Vector2(44, 44))
	_label(raiz, "Rotulo", "", Vector2(0, -46), 220, 11)
	_salvar(raiz, DIR_COMPONENTES + "alvo_bumerangue.tscn")


func _comp_interruptor() -> void:
	var raiz := Area2D.new()
	raiz.name = "Interruptor"
	raiz.set_script(load("res://scripts/fases/interruptor.gd"))
	_no(raiz, Sprite2D, "Sprite")
	var ativo := _no(raiz, Sprite2D, "SpriteAtivo") as Sprite2D
	ativo.visible = false
	var ph := _rect(raiz, "Placeholder", Vector2(30, 40), Color(0.14, 0.15, 0.18))
	_rect(ph, "Miolo", Vector2(18, 26), Color(0.8, 0.35, 0.3), Vector2(15, 20))
	_colisao(raiz, Vector2(90, 100))
	_label(raiz, "Rotulo", "", Vector2(0, -56), 230, 11)
	_salvar(raiz, DIR_COMPONENTES + "interruptor.tscn")


func _comp_bloco_alternavel() -> void:
	var raiz := StaticBody2D.new()
	raiz.name = "BlocoAlternavel"
	raiz.set_script(load("res://scripts/fases/bloco_alternavel.gd"))
	_no(raiz, Sprite2D, "Sprite")
	_rect(raiz, "Placeholder", Vector2(120, 20), Color(0.55, 0.35, 0.3))
	_colisao(raiz, Vector2(120, 20))
	_salvar(raiz, DIR_COMPONENTES + "bloco_alternavel.tscn")


func _comp_chapa_soldada() -> void:
	var raiz := StaticBody2D.new()
	raiz.name = "ChapaSoldada"
	raiz.set_script(load("res://scripts/fases/chapa_soldada.gd"))
	_no(raiz, Sprite2D, "Sprite")
	var ph := _rect(raiz, "Placeholder", Vector2(28, 120), Color(0.40, 0.42, 0.48))
	_no(ph, Node2D, "Soldas")
	_colisao(raiz, Vector2(28, 120))
	var area := _no(raiz, Area2D, "AreaInteracao") as Area2D
	_colisao(area, Vector2(148, 180))
	_label(raiz, "Rotulo", "CHAPA SOLDADA", Vector2(0, -94), 200, 11)
	_particulas(raiz, "Fagulhas", {
		"amount": 40, "lifetime": 0.5, "one_shot": true, "emitting": false,
		"explosiveness": 0.7, "direction": Vector2(0, -1), "spread": 70.0,
		"initial_velocity_min": 120.0, "initial_velocity_max": 320.0,
		"gravity": Vector2(0, 700), "scale_amount_min": 2.0,
		"scale_amount_max": 4.0, "color": Color(1.0, 0.75, 0.3),
	})
	_salvar(raiz, DIR_COMPONENTES + "chapa_soldada.tscn")


func _comp_chama() -> void:
	var raiz := Area2D.new()
	raiz.name = "Chama"
	raiz.set_script(load("res://scripts/fases/chama.gd"))
	var sprite := _no(raiz, AnimatedSprite2D, "Sprite", Vector2(0, -32)) as AnimatedSprite2D
	sprite.visible = false
	_colisao(raiz, Vector2(48, 64), Vector2(0, -32))

	var rampa := Gradient.new()
	rampa.colors = PackedColorArray([Color(1.0, 0.85, 0.3, 0.9), Color(1.0, 0.4, 0.1, 0.7), Color(0.4, 0.1, 0.05, 0.0)])
	rampa.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_particulas(raiz, "Fogo", {
		"position": Vector2(0, -8), "amount": 26, "lifetime": 0.55,
		"direction": Vector2(0, -1), "spread": 16.0,
		"initial_velocity_min": 60.0, "initial_velocity_max": 130.0,
		"scale_amount_min": 4.0, "scale_amount_max": 9.0, "color_ramp": rampa,
	})
	_particulas(raiz, "Fumaca", {
		"position": Vector2(0, -20), "amount": 18, "lifetime": 0.7,
		"one_shot": true, "emitting": false, "explosiveness": 0.8,
		"direction": Vector2(0, -1), "spread": 40.0,
		"initial_velocity_min": 40.0, "initial_velocity_max": 110.0,
		"gravity": Vector2(0, -60), "scale_amount_min": 3.0,
		"scale_amount_max": 7.0, "color": Color(0.7, 0.7, 0.75, 0.6),
	})
	_salvar(raiz, DIR_COMPONENTES + "chama.tscn")


func _comp_corrente_vapor() -> void:
	var raiz := Area2D.new()
	raiz.name = "CorrenteVapor"
	raiz.set_script(load("res://scripts/fases/corrente_vapor.gd"))
	_colisao(raiz, Vector2(400, 200))
	_rect(raiz, "Faixa", Vector2(400, 200), Color(0.75, 0.80, 0.88, 0.16), Vector2.ZERO, -2)
	_particulas(raiz, "Vapor", {
		"position": Vector2(-200, 0), "amount": 40, "lifetime": 1.4,
		"direction": Vector2(1, 0), "spread": 8.0,
		"initial_velocity_min": 224.0, "initial_velocity_max": 308.0,
		"scale_amount_min": 2.0, "scale_amount_max": 5.0,
		"color": Color(0.85, 0.9, 0.95, 0.5),
		"emission_shape": CPUParticles2D.EMISSION_SHAPE_RECTANGLE,
		"emission_rect_extents": Vector2(8, 100),
	})
	_salvar(raiz, DIR_COMPONENTES + "corrente_vapor.tscn")


func _comp_piso_eletrificado() -> void:
	var raiz := Area2D.new()
	raiz.name = "PisoEletrificado"
	raiz.set_script(load("res://scripts/fases/piso_eletrificado.gd"))
	_no(raiz, Sprite2D, "Sprite")
	var ph := _rect(raiz, "Placeholder", Vector2(300, 24), Color(0.2, 0.2, 0.1))
	_no(ph, Node2D, "Listras")
	_colisao(raiz, Vector2(300, 24))
	_salvar(raiz, DIR_COMPONENTES + "piso_eletrificado.tscn")


func _comp_valvula_purga() -> void:
	var raiz := Area2D.new()
	raiz.name = "ValvulaPurga"
	raiz.set_script(load("res://scripts/fases/valvula_purga.gd"))
	_no(raiz, Sprite2D, "Sprite")
	var ph := _rect(raiz, "Placeholder", Vector2(26, 26), Color(0.3, 0.5, 0.85))
	_rect(ph, "Miolo", Vector2(14, 14), Color(0.65, 0.8, 1.0), Vector2(13, 13))
	_colisao(raiz, Vector2(90, 90))
	_label(raiz, "Rotulo", "N₂", Vector2(0, -34), 80, 12)
	_particulas(raiz, "Puff", {
		"amount": 14, "lifetime": 0.4, "one_shot": true, "emitting": false,
		"explosiveness": 1.0, "spread": 180.0,
		"initial_velocity_min": 60.0, "initial_velocity_max": 160.0,
		"scale_amount_min": 2.0, "scale_amount_max": 5.0,
		"color": Color(0.7, 0.85, 1.0, 0.8),
	})
	_salvar(raiz, DIR_COMPONENTES + "valvula_purga.tscn")


func _comp_pickup_habilidade() -> void:
	var raiz := Area2D.new()
	raiz.name = "PickupHabilidade"
	raiz.set_script(load("res://scripts/fases/pickup_habilidade.gd"))
	_no(raiz, Sprite2D, "Sprite")
	var ph := _rect(raiz, "Placeholder", Vector2(40, 40), Color(0.58, 0.45, 0.15))
	_rect(ph, "Miolo", Vector2(30, 30), Color(0.95, 0.75, 0.25), Vector2(20, 20))
	_colisao(raiz, Vector2(90, 90))
	_label(raiz, "Rotulo", "FERRAMENTA\n[E]", Vector2(0, -66), 260, 12)
	_salvar(raiz, DIR_COMPONENTES + "pickup_habilidade.tscn")


func _comp_celula_chonps() -> void:
	var raiz := Area2D.new()
	raiz.name = "CelulaChonps"
	raiz.set_script(load("res://scripts/fases/celula_chonps.gd"))
	_no(raiz, Sprite2D, "Sprite")
	var ph := _rect(raiz, "Placeholder", Vector2(46, 46), Color(0.25, 0.25, 0.27))
	_rect(ph, "Miolo", Vector2(36, 36), Color(0.35, 0.35, 0.38), Vector2(23, 23))
	_colisao(raiz, Vector2(70, 70))
	_label(raiz, "Letra", "C", Vector2.ZERO, 46, 26, Color(0.05, 0.05, 0.08))
	_salvar(raiz, DIR_COMPONENTES + "celula_chonps.tscn")


# O painel do CHONPS saiu do gerador: ele já tem a arte final (tela animada,
# título e as letras acesas/apagadas), montada à mão em
# scenes/fases/componentes/painel_chonps.tscn. As fases só o instanciam.


func _comp_porta_fase() -> void:
	var raiz := Area2D.new()
	raiz.name = "PortaFase"
	raiz.set_script(load("res://scripts/fases/porta_fase.gd"))
	_no(raiz, Sprite2D, "Sprite")
	var ph := _rect(raiz, "Placeholder", Vector2(64, 110), Color(0.45, 0.55, 0.65), Vector2(0, -55))
	_rect(ph, "Miolo", Vector2(48, 94), Color(0.29, 0.36, 0.42), Vector2(32, 55))
	_colisao(raiz, Vector2(110, 140), Vector2(0, -60))
	_label(raiz, "Rotulo", "PORTA\n[E]", Vector2(0, -190), 300, 13)
	_salvar(raiz, DIR_COMPONENTES + "porta_fase.tscn")


func _comp_mesa_puzzle() -> void:
	var raiz := Area2D.new()
	raiz.name = "MesaPuzzle"
	raiz.set_script(load("res://scripts/fases/mesa_puzzle.gd"))
	_no(raiz, Sprite2D, "Sprite")
	var ph := _rect(raiz, "Placeholder", Vector2(120, 80), Color(0.15, 0.28, 0.20), Vector2(0, -40))
	_rect(ph, "Miolo", Vector2(100, 60), Color(0.3, 0.55, 0.4), Vector2(60, 40))
	_colisao(raiz, Vector2(200, 140), Vector2(0, -40))
	_label(raiz, "Rotulo", "PAINEL\n[E]", Vector2(0, -130), 300, 12)
	_salvar(raiz, DIR_COMPONENTES + "mesa_puzzle.tscn")


func _comp_estacao_recarga() -> void:
	var raiz := Area2D.new()
	raiz.name = "EstacaoRecarga"
	raiz.set_script(load("res://scripts/fases/estacao_recarga.gd"))
	_no(raiz, Sprite2D, "Sprite")
	var ph := _rect(raiz, "Placeholder", Vector2(70, 90), Color(0.2, 0.3, 0.25), Vector2(0, -45))
	_rect(ph, "FrascoA", Vector2(22, 40), Color(0.55, 0.9, 0.5), Vector2(21, 35))
	_rect(ph, "FrascoB", Vector2(22, 40), Color(0.4, 0.7, 0.95), Vector2(49, 35))
	_colisao(raiz, Vector2(150, 130), Vector2(0, -45))
	_label(raiz, "Rotulo", "ESTAÇÃO DE MISTURA\nrecarga do sinalizador [E]", Vector2(0, -140), 260, 11)

	var luz := Blockout.luz_radial(Color(0.6, 0.95, 0.7), 1.4, 0.9)
	luz.name = "Luz"
	luz.position = Vector2(0, -55)
	raiz.add_child(luz)
	_salvar(raiz, DIR_COMPONENTES + "estacao_recarga.tscn")


func _comp_masseira() -> void:
	var raiz := Area2D.new()
	raiz.name = "Masseira"
	raiz.set_script(load("res://scripts/fases/masseira.gd"))
	_no(raiz, Sprite2D, "Sprite")
	var ph := _rect(raiz, "Placeholder", Vector2(160, 110), Color(0.4, 0.38, 0.2), Vector2(0, -55))
	_rect(ph, "Miolo", Vector2(130, 80), Color(0.55, 0.5, 0.25), Vector2(80, 55))
	_colisao(raiz, Vector2(220, 160), Vector2(0, -55))
	_label(raiz, "Rotulo", "MASSEIRA DE VULCANIZAÇÃO\ndosar o enxofre [E]", Vector2(0, -160), 300, 12)
	_salvar(raiz, DIR_COMPONENTES + "masseira.tscn")


func _comp_casca_babacu() -> void:
	var raiz := Area2D.new()
	raiz.name = "CascaBabacu"
	raiz.set_script(load("res://scripts/fases/casca_babacu.gd"))
	_no(raiz, Sprite2D, "Sprite")
	var ph := _rect(raiz, "Placeholder", Vector2(34, 22), Color(0.45, 0.32, 0.2))
	_rect(ph, "Miolo", Vector2(22, 12), Color(0.58, 0.42, 0.26), Vector2(17, 11))
	_colisao(raiz, Vector2(80, 70))
	_label(raiz, "Rotulo", "cascas de babaçu [E]", Vector2(0, -36), 200, 11)
	_salvar(raiz, DIR_COMPONENTES + "casca_babacu.tscn")


func _comp_retorta() -> void:
	var raiz := Node2D.new()
	raiz.name = "Retorta"
	raiz.set_script(load("res://scripts/fases/retorta.gd"))
	_no(raiz, Sprite2D, "Sprite", Vector2(0, -85))

	var ph := _no(raiz, Node2D, "Placeholder") as Node2D
	_rect(ph, "Corpo", Vector2(150, 170), Color(0.22, 0.20, 0.24), Vector2(0, -85))
	_rect(ph, "Camara", Vector2(120, 130), Color(0.30, 0.26, 0.30), Vector2(0, -85))
	_rect(ph, "Chamine", Vector2(30, 60), Color(0.22, 0.20, 0.24), Vector2(90, -140))

	var base := _no(raiz, StaticBody2D, "Base") as StaticBody2D
	_colisao(base, Vector2(180, 30), Vector2(0, -15))
	_rect(base, "Visual", Vector2(180, 30), Color(0.18, 0.17, 0.20), Vector2(0, -15))

	_label(raiz, "Rotulo", "RETORTA DE CARBONIZAÇÃO\n[E]", Vector2(0, -226), 320, 13)
	_label(raiz, "Status", "", Vector2(0, -262), 320, 12, Color(0.85, 0.75, 0.45))

	var area := _no(raiz, Area2D, "AreaInteracao") as Area2D
	_colisao(area, Vector2(240, 200), Vector2(0, -80))

	_instanciar(raiz, DIR_COMPONENTES + "interruptor.tscn", "JuntaEsquerda", Vector2(-150, -40),
		{"rotulo": "junta de vedação"})
	_instanciar(raiz, DIR_COMPONENTES + "interruptor.tscn", "JuntaDireita", Vector2(150, -40),
		{"rotulo": "junta de vedação"})
	_instanciar(raiz, DIR_COMPONENTES + "alvo_bumerangue.tscn", "JuntaAlta", Vector2(0, -290),
		{"permanece_ativo": true, "persistir": true, "rotulo": "junta alta — só o bumerangue"})

	var pontos := _no(raiz, Node2D, "PontosDeCascas") as Node2D
	_marker(pontos, "Ponto1", Vector2(-1450, -24))
	_marker(pontos, "Ponto2", Vector2(-1150, -154))
	_marker(pontos, "Ponto3", Vector2(-800, -24))
	_marker(raiz, "PontoDaCelula", Vector2(0, -360))
	_salvar(raiz, DIR_COMPONENTES + "retorta.tscn")


# ============================================================================
#  HUB — O QUE O LABORATÓRIO GANHOU
# ============================================================================
#
# ATENÇÃO — ESTE GERADOR ESTÁ APOSENTADO.
#
# O hub não é mais uma cena separada: o painel do CHONPS e as quatro portas
# foram movidos para DENTRO de scenes/laboratório_(world_2).tscn, como filhos
# diretos, para poderem ser arrastados na viewport com o cenário da sala em
# volta. hub_fases.tscn continua no disco, mas ninguém mais o carrega.
#
# Rodar isto de novo só reescreve esse arquivo órfão — as posições reais das
# portas NÃO mudam. Mexa nelas na cena do laboratório.

func _gerar_hub_fases() -> void:
	print("\n--- HUB ---")
	var raiz := Node2D.new()
	raiz.name = "HubFases"

	_instanciar(raiz, DIR_COMPONENTES + "painel_chonps.tscn", "PainelChonps", Vector2(1150, 20))

	_instanciar(raiz, DIR_COMPONENTES + "porta_fase.tscn", "PortaOficina", Vector2(1400, 118), {
		"rotulo": "OFICINA DO CARBONO",
		"cena_destino": DIR_FASES + "fase1_oficina.tscn",
		"tag_aqui": "volta_da_oficina", "tag_destino": "entrada",
		"cor_porta": Color(0.42, 0.42, 0.48),
	})
	_instanciar(raiz, DIR_COMPONENTES + "porta_fase.tscn", "PortaTorre", Vector2(1560, 118), {
		"rotulo": "TORRE DE GASES E ESTUFA",
		"cena_destino": DIR_FASES + "fase2_torre.tscn",
		"tag_aqui": "volta_da_torre", "tag_destino": "entrada",
		"cor_porta": Color(0.35, 0.6, 0.45),
	})
	_instanciar(raiz, DIR_COMPONENTES + "porta_fase.tscn", "FossoVentilacao", Vector2(980, 118), {
		"rotulo": "FOSSO DE VENTILAÇÃO (subsolo)",
		"cena_destino": DIR_FASES + "fase3_subsolo.tscn",
		"tag_aqui": "volta_do_fosso", "tag_destino": "entrada",
		"no_piso": true,
		"requer_habilidade": "mochila",
		"mensagem_trancada": "Fundo demais para descer no pulo.\nSó com a mochila propulsora de N₂.",
		"cor_porta": Color(0.4, 0.42, 0.5),
	})
	_instanciar(raiz, DIR_COMPONENTES + "porta_fase.tscn", "PortaLancamento", Vector2(1720, 118), {
		"rotulo": "TORRE DE LANÇAMENTO",
		"cena_destino": DIR_FASES + "fase_final.tscn",
		"tag_aqui": "volta_do_lancamento", "tag_destino": "entrada",
		"cor_porta": Color(0.7, 0.45, 0.5),
	})

	_salvar(raiz, DIR_FASES + "hub_fases.tscn")


# ============================================================================
#  FASE 1 — OFICINA DO CARBONO
# ============================================================================

func _gerar_fase1() -> void:
	print("\n--- FASE 1 ---")
	var chao := 512.0
	var raiz := _montar_fase("Fase1Oficina", "res://scripts/fases/fase1_oficina.gd")

	var fundo := _camada_tiles(raiz, "Fundo", -20)
	var terreno := _camada_tiles(raiz, "Terreno", -5)
	_pintar_fundo(fundo, Rect2(0, -416, 5440, 928))
	_pintar_solido(terreno, Rect2(0, chao, 5440, 96))
	_pintar_solido(terreno, Rect2(-64, -416, 64, 992))
	_pintar_solido(terreno, Rect2(5440, -416, 64, 992))

	# Plataformas fixas (repinte à vontade no editor)
	for r in [
		Rect2(1248, chao - 128, 160, 32), Rect2(1632, chao - 192, 160, 32),
		Rect2(2240, chao - 128, 192, 32), Rect2(2528, chao - 224, 192, 32),
		Rect2(3584, chao - 128, 192, 32), Rect2(448, chao - 64, 192, 64),
	]:
		_pintar_solido(terreno, r)

	var salas := _no(raiz, Node2D, "Salas")
	var nomes := [
		[448, "① ENTRADA — bancada do Dr. Chico"],
		[1500, "② TREINO — escola do arremesso"],
		[2650, "③ CORREDORES — interruptores distantes"],
		[3750, "④ DEPÓSITO — cascas de babaçu"],
		[4850, "⑤ PÁTIO DA RETORTA"],
	]
	for n in nomes:
		_label(salas, "Sala%d" % n[0], n[1], Vector2(n[0], -80), 420, 16, Color(0.6, 0.63, 0.7))

	# ① ENTRADA
	var entrada := _no(raiz, Node2D, "Entrada")
	_instanciar(entrada, DIR_COMPONENTES + "porta_fase.tscn", "PortaHub", Vector2(140, chao), {
		"rotulo": "VOLTAR AO LABORATÓRIO",
		"cena_destino": "res://scenes/laboratório_(world_2).tscn",
		"tag_aqui": "entrada", "tag_destino": "volta_da_oficina",
	})
	_instanciar(entrada, DIR_COMPONENTES + "pickup_habilidade.tscn", "PickupBumerangue", Vector2(544, chao - 110), {
		"habilidade": "bumerangue",
		"rotulo": "BUMERANGUE DE FIBRA DE CARBONO",
		"mensagem": "Bumerangue montado!\nAperte F para arremessar — ele volta sozinho.",
		"cor": Color(0.25, 0.25, 0.3),
	})
	_label(entrada, "PlacaFibra", "PAINEL: a fibra de carbono das carenagens é leve e resistente —\npor isso o bumerangue voa longe e volta inteiro.", Vector2(544, chao - 250), 420, 12, Color(0.7, 0.72, 0.8))

	# ② TREINO
	var treino := _no(raiz, Node2D, "Treino")
	_instanciar(treino, DIR_COMPONENTES + "alvo_bumerangue.tscn", "AlvoFixo1", Vector2(1150, chao - 150),
		{"permanece_ativo": false, "janela": 2.0, "rotulo": "alvo fixo"})
	_instanciar(treino, DIR_COMPONENTES + "alvo_bumerangue.tscn", "AlvoFixo2", Vector2(1330, chao - 300),
		{"permanece_ativo": false, "janela": 2.0, "rotulo": "alvo alto"})
	_instanciar(treino, DIR_COMPONENTES + "bloco_alternavel.tscn", "Vidro", Vector2(1508, chao - 110),
		{"tamanho": Vector2(16, 220), "cor": Color(0.6, 0.8, 0.9, 0.35)})
	_instanciar(treino, DIR_COMPONENTES + "alvo_bumerangue.tscn", "AlvoVidro", Vector2(1600, chao - 140),
		{"permanece_ativo": true, "persistir": true, "rotulo": "interruptor atrás do vidro"})
	_instanciar(treino, DIR_COMPONENTES + "bloco_alternavel.tscn", "PlataformaVidro", Vector2(1695, chao - 171),
		{"tamanho": Vector2(150, 18), "cor": Color(0.45, 0.5, 0.42), "solido": false})
	_instanciar(treino, DIR_COMPONENTES + "alvo_bumerangue.tscn", "AlvoTemporizado", Vector2(1760, chao - 260),
		{"permanece_ativo": false, "janela": 3.5, "rotulo": "interruptor temporizado"})
	_instanciar(treino, DIR_COMPONENTES + "bloco_alternavel.tscn", "PortaTemporizada", Vector2(1968, chao - 120),
		{"tamanho": Vector2(36, 240), "cor": Color(0.55, 0.35, 0.3)})
	_label(treino, "DicaTreino", "O arremesso ativa alvos na IDA e na VOLTA do bumerangue.", Vector2(1400, 120), 420, 12, Color(0.7, 0.72, 0.8))

	# ③ CORREDORES
	var corredores := _no(raiz, Node2D, "Corredores")
	_instanciar(corredores, DIR_COMPONENTES + "alvo_bumerangue.tscn", "AlvoDuploA", Vector2(2860, chao - 290),
		{"permanece_ativo": false, "janela": 1.6, "rotulo": "alvo duplo A"})
	_instanciar(corredores, DIR_COMPONENTES + "alvo_bumerangue.tscn", "AlvoDuploB", Vector2(3060, chao - 290),
		{"permanece_ativo": false, "janela": 1.6, "rotulo": "alvo duplo B"})
	_instanciar(corredores, DIR_COMPONENTES + "bloco_alternavel.tscn", "GradeDupla", Vector2(3178, chao - 120),
		{"tamanho": Vector2(36, 240), "cor": Color(0.55, 0.35, 0.3)})
	_label(corredores, "DicaDuplo", "A grade só abre com os DOIS alvos acesos ao mesmo tempo —\num único arremesso resolve.", Vector2(2950, 120), 420, 12, Color(0.7, 0.72, 0.8))
	_label(corredores, "NichoCarta", "NICHO: carta colecionável (em breve)", Vector2(2600, chao - 380), 300, 11, Color(0.5, 0.52, 0.6))

	# ④⑤ DEPÓSITO E PÁTIO
	var patio := _no(raiz, Node2D, "Patio")
	_instanciar(patio, DIR_COMPONENTES + "retorta.tscn", "Retorta", Vector2(4850, chao))
	_label(patio, "PlacaPirolise", "CARBONIZAÇÃO: calor SEM oxigênio expulsa os voláteis e sobra carvão.\nSe entrar O₂, a mesma regra do prólogo age — a carga queima e vira cinza.", Vector2(4550, 60), 460, 12, Color(0.7, 0.72, 0.8))

	_fechar_fase(raiz, Vector2(180, chao - 10), Rect2(0, -420, 5440, 1100))
	_salvar(raiz, DIR_FASES + "fase1_oficina.tscn")


# ============================================================================
#  FASE 2 — TORRE DE GASES E ESTUFA
# ============================================================================

func _gerar_fase2() -> void:
	print("\n--- FASE 2 ---")
	var chao := 512.0
	var raiz := _montar_fase("Fase2Torre", "res://scripts/fases/fase2_torre.gd")

	var fundo := _camada_tiles(raiz, "Fundo", -20)
	var terreno := _camada_tiles(raiz, "Terreno", -5)
	_pintar_fundo(fundo, Rect2(0, -2912, 1408, 3424))
	_pintar_solido(terreno, Rect2(0, chao, 1408, 96))
	_pintar_solido(terreno, Rect2(-64, -2912, 64, 3520))
	_pintar_solido(terreno, Rect2(1408, -2912, 64, 3520))
	_pintar_solido(terreno, Rect2(-64, -2976, 1536, 64))

	# Subida 1 e 2 — plataformas
	for r in [
		Rect2(192, 384, 192, 32), Rect2(512, 224, 192, 32), Rect2(864, 96, 192, 32),
		Rect2(512, -64, 192, 32), Rect2(192, -192, 192, 32), Rect2(544, -352, 192, 32),
		Rect2(896, -512, 192, 32), Rect2(544, -672, 192, 32), Rect2(224, -832, 192, 32),
		Rect2(224, -992, 192, 32), Rect2(608, -1120, 192, 32), Rect2(992, -1248, 192, 32),
		Rect2(608, -1376, 192, 32), Rect2(224, -1504, 192, 32), Rect2(704, -1632, 192, 32),
	]:
		_pintar_solido(terreno, r)

	# Tubulações — canos estreitos
	for r in [
		Rect2(160, -1792, 256, 32), Rect2(640, -1888, 224, 32),
		Rect2(1088, -1984, 224, 32), Rect2(640, -2112, 224, 32),
		Rect2(160, -2208, 224, 32), Rect2(704, -2336, 256, 32),
	]:
		_pintar_solido(terreno, r)

	# Chão da estufa
	_pintar_solido(terreno, Rect2(0, -2464, 1408, 32))

	var secoes := _no(raiz, Node2D, "Secoes")
	for s in [
		[-150, "① BASE — armário da mochila"],
		[-900, "② SUBIDA 1 — chamas (jato de N₂ apaga)"],
		[-1700, "③ SUBIDA 2 — correntes de vapor"],
		[-2400, "④ TUBULAÇÕES — atalhos soldados"],
		[-2860, "⑤ ESTUFA DE HIDROPONIA"],
	]:
		_label(secoes, "Secao%d" % absi(s[0]), s[1], Vector2(700, s[0]), 420, 15, Color(0.6, 0.63, 0.7))

	# ① BASE
	var base := _no(raiz, Node2D, "Base")
	_instanciar(base, DIR_COMPONENTES + "porta_fase.tscn", "PortaHub", Vector2(140, chao), {
		"rotulo": "VOLTAR AO LABORATÓRIO",
		"cena_destino": "res://scenes/laboratório_(world_2).tscn",
		"tag_aqui": "entrada", "tag_destino": "volta_da_torre",
	})
	_rect(base, "ArmarioFundo", Vector2(160, 200), Color(0.20, 0.22, 0.27), Vector2(960, chao - 100), -6)
	_instanciar(base, DIR_COMPONENTES + "bloco_alternavel.tscn", "PortaArmario", Vector2(960, chao - 95),
		{"tamanho": Vector2(140, 190), "cor": Color(0.33, 0.36, 0.42)})
	_marker(base, "PontoDaMochila", Vector2(960, chao - 90))

	# TRAVA 1: grade de vãos estreitos; a alavanca fica do outro lado
	var grade := _no(base, Node2D, "GradeVisual", Vector2(1195, chao - 90)) as Node2D
	for i in 5:
		_rect(grade, "Barra%d" % i, Vector2(6, 180), Color(0.55, 0.58, 0.65), Vector2(-40 + i * 18, 0), -1)
	_instanciar(base, DIR_COMPONENTES + "alvo_bumerangue.tscn", "AlavancaArmario", Vector2(1310, chao - 90),
		{"permanece_ativo": true, "persistir": true, "rotulo": "TRAVA 1: alavanca atrás da grade"})

	# TRAVA 2: chapa de manutenção soldada
	_instanciar(base, DIR_COMPONENTES + "chapa_soldada.tscn", "ChapaArmario", Vector2(820, chao - 80),
		{"tamanho": Vector2(26, 160), "rotulo": "TRAVA 2: chapa soldada"})
	_label(base, "DicaTravas", "MOCHILA PROPULSORA DE N₂ — igual à SAFER dos astronautas.\nDuas travas: uma pede o arremesso, a outra pede o corte.", Vector2(700, chao - 350), 460, 12, Color(0.7, 0.72, 0.8))

	# ② SUBIDA 1 — chamas
	var subida1 := _no(raiz, Node2D, "Subida1")
	_instanciar(subida1, DIR_COMPONENTES + "chama.tscn", "Chama1", Vector2(620, 224))
	_instanciar(subida1, DIR_COMPONENTES + "chama.tscn", "Chama2", Vector2(280, -192))
	_instanciar(subida1, DIR_COMPONENTES + "chama.tscn", "Chama3", Vector2(660, -672))
	_label(subida1, "DicaChama", "Shift: o dash solta o jato de N₂ —\no nitrogênio desloca o comburente e a chama apaga.", Vector2(1080, 300), 420, 12, Color(0.7, 0.72, 0.8))

	# ③ SUBIDA 2 — correntes de vapor
	var subida2 := _no(raiz, Node2D, "Subida2")
	_instanciar(subida2, DIR_COMPONENTES + "corrente_vapor.tscn", "Corrente1", Vector2(700, -1180),
		{"tamanho": Vector2(900, 240), "direcao": -1})
	_instanciar(subida2, DIR_COMPONENTES + "alvo_bumerangue.tscn", "Ventilador1", Vector2(1240, -1120),
		{"permanece_ativo": true, "persistir": true, "rotulo": "ventilador (trave com o bumerangue)"})
	_instanciar(subida2, DIR_COMPONENTES + "corrente_vapor.tscn", "Corrente2", Vector2(650, -1560),
		{"tamanho": Vector2(1000, 220), "direcao": 1})
	_instanciar(subida2, DIR_COMPONENTES + "alvo_bumerangue.tscn", "Ventilador2", Vector2(180, -1640),
		{"permanece_ativo": true, "persistir": true, "rotulo": "ventilador (trave com o bumerangue)"})

	# ④ TUBULAÇÕES
	var tubos := _no(raiz, Node2D, "Tubulacoes")
	_instanciar(tubos, DIR_COMPONENTES + "chapa_soldada.tscn", "ChapaTubo1", Vector2(540, -1860),
		{"tamanho": Vector2(24, 140), "rotulo": "atalho soldado"})
	_instanciar(tubos, DIR_COMPONENTES + "chapa_soldada.tscn", "ChapaTubo2", Vector2(430, -2280),
		{"tamanho": Vector2(24, 140), "rotulo": "atalho soldado"})
	_instanciar(tubos, DIR_COMPONENTES + "valvula_purga.tscn", "Valvula1", Vector2(950, -1950))
	_instanciar(tubos, DIR_COMPONENTES + "valvula_purga.tscn", "Valvula2", Vector2(420, -2160))
	_label(tubos, "DicaValvula", "Válvulas de purga: o uso real do N₂ em foguetes —\nencostar recarrega o dash em pleno ar.", Vector2(1120, -2260), 420, 12, Color(0.7, 0.72, 0.8))

	# ⑤ ESTUFA
	var estufa := _no(raiz, Node2D, "Estufa")
	for i in 4:
		_rect(estufa, "Canteiro%d" % i, Vector2(160, 80), Color(0.25, 0.45, 0.3), Vector2(230 + i * 250, -2504), -3)
		_rect(estufa, "Planta%d" % i, Vector2(80, 60), Color(0.35, 0.65, 0.4), Vector2(230 + i * 250, -2574), -3)
	_instanciar(estufa, DIR_COMPONENTES + "mesa_puzzle.tscn", "MesaCicloN", Vector2(700, -2464), {
		"rotulo": "SISTEMA DO CICLO DO NITROGÊNIO",
		"cor": Color(0.3, 0.55, 0.4),
		"puzzle_config": {
			"titulo": "REMONTAR O CICLO DO NITROGÊNIO",
			"subtitulo": "A estufa parou porque o ciclo foi desmontado. Arraste cada etapa para o seu lugar.",
			"slots": [
				{"aceita": "n2", "rotulo": "1. no ar"},
				{"aceita": "fixacao", "rotulo": "2. entra no solo"},
				{"aceita": "sais", "rotulo": "3. vira nutriente"},
				{"aceita": "planta", "rotulo": "4. vira vida"},
				{"aceita": "decomposicao", "rotulo": "5. volta ao começo"},
			],
			"separadores": ["→", "→", "→", "→"],
			"pecas": [
				{"id": "n2", "texto": "N₂ atmosférico"},
				{"id": "fixacao", "texto": "Fixação biológica\n(bactérias)"},
				{"id": "sais", "texto": "Amônio e nitrato"},
				{"id": "planta", "texto": "Planta\n(proteínas)"},
				{"id": "decomposicao", "texto": "Decomposição"},
				{"id": "co2", "texto": "CO₂ (não é daqui!)"},
			],
			"texto_vitoria": "O ciclo girou — a estufa voltou à vida!",
		},
	})
	_marker(estufa, "PontoDaCelula", Vector2(700, -2620))
	_label(estufa, "CartaJohanna", "CARTA: Johanna Döbereiner — a fixação biológica do nitrogênio\nque transformou a agricultura brasileira.", Vector2(320, -2700), 420, 12, Color(0.85, 0.8, 0.6))
	_label(estufa, "VistaFosso", "Do alto da torre dá para ver o FOSSO DE VENTILAÇÃO no piso do\nlaboratório — com a mochila, agora dá para descer.", Vector2(1100, -2700), 420, 12, Color(0.7, 0.72, 0.8))

	_fechar_fase(raiz, Vector2(180, chao - 10), Rect2(0, -2960, 1440, 3540))
	_salvar(raiz, DIR_FASES + "fase2_torre.tscn")


# ============================================================================
#  FASE 3 — SUBSOLO EM BLECAUTE
# ============================================================================

func _gerar_fase3() -> void:
	print("\n--- FASE 3 ---")
	var chao := 512.0
	var raiz := _montar_fase("Fase3Subsolo", "res://scripts/fases/fase3_subsolo.gd")

	var blecaute := CanvasModulate.new()
	blecaute.name = "Blecaute"
	blecaute.color = Color(0.10, 0.11, 0.16)
	raiz.add_child(blecaute)

	var fundo := _camada_tiles(raiz, "Fundo", -20)
	var terreno := _camada_tiles(raiz, "Terreno", -5)
	_pintar_fundo(fundo, Rect2(0, -448, 5632, 960))
	_pintar_solido(terreno, Rect2(0, chao, 5632, 96))
	_pintar_solido(terreno, Rect2(-64, -448, 64, 1056))
	_pintar_solido(terreno, Rect2(5632, -448, 64, 1056))
	_pintar_solido(terreno, Rect2(-64, -512, 5760, 64))
	for r in [
		Rect2(1760, chao - 128, 192, 32), Rect2(1152, chao - 128, 192, 32),
		Rect2(512, chao - 128, 192, 32), Rect2(3456, chao - 160, 320, 32),
		Rect2(3968, chao - 256, 320, 32),
	]:
		_pintar_solido(terreno, r)

	var areas := _no(raiz, Node2D, "Areas")
	_label(areas, "AreaOeste", "② ALA OESTE — o Fósforo, portador de luz", Vector2(1150, -300), 460, 15, Color(0.6, 0.63, 0.7))
	_label(areas, "AreaAtrio", "① ÁTRIO CENTRAL", Vector2(2800, -300), 420, 15, Color(0.6, 0.63, 0.7))
	_label(areas, "AreaLeste", "③ ALA LESTE — o Enxofre", Vector2(4450, -300), 420, 15, Color(0.6, 0.63, 0.7))

	# ① ÁTRIO
	var atrio := _no(raiz, Node2D, "Atrio")
	_instanciar(atrio, DIR_COMPONENTES + "porta_fase.tscn", "PortaFosso", Vector2(2450, chao), {
		"rotulo": "FOSSO DE VENTILAÇÃO — SUBIR AO LABORATÓRIO",
		"cena_destino": "res://scenes/laboratório_(world_2).tscn",
		"tag_aqui": "entrada", "tag_destino": "volta_do_fosso",
	})
	_rect(atrio, "ArmarioEmergencia", Vector2(120, 160), Color(0.45, 0.25, 0.22), Vector2(2680, chao - 80), -3)
	_instanciar(atrio, DIR_COMPONENTES + "pickup_habilidade.tscn", "PickupSinalizador", Vector2(2680, chao - 80), {
		"habilidade": "sinalizador",
		"rotulo": "SINALIZADOR QUIMIOLUMINESCENTE",
		"mensagem": "Bastão de luz química aceso!\nT liga/desliga. A carga drena — recarregue nas estações de mistura.",
		"cor": Color(0.6, 0.95, 0.5),
	})
	var luz_armario := Blockout.luz_radial(Color(0.9, 0.5, 0.4), 1.2, 1.0)
	luz_armario.name = "LuzArmario"
	luz_armario.position = Vector2(2680, chao - 120)
	atrio.add_child(luz_armario)

	_instanciar(atrio, DIR_COMPONENTES + "estacao_recarga.tscn", "EstacaoAtrio", Vector2(2950, chao))

	var luz_atrio := Blockout.luz_radial(Color(0.9, 0.85, 0.7), 4.0, 1.1)
	luz_atrio.name = "LuzAtrio"
	luz_atrio.position = Vector2(2800, chao - 200)
	luz_atrio.enabled = false
	atrio.add_child(luz_atrio)
	_label(atrio, "PlacaAtrio", "BLECAUTE GERAL. O gerador fica na ala OESTE.\nA luz definitiva depende dos disjuntores, na ala LESTE.", Vector2(2800, chao - 380), 460, 12, Color(0.7, 0.72, 0.8))

	# ② ALA OESTE — Fósforo
	var oeste := _no(raiz, Node2D, "AlaOeste")
	var setores := _no(oeste, Node2D, "Setores")
	var dados_setores := [[1900.0, "setor 1"], [1100.0, "setor 2"]]
	for i in dados_setores.size():
		var cx: float = dados_setores[i][0]
		var setor := _no(setores, Node2D, "Setor%d" % (i + 1)) as Node2D
		var luz := Blockout.luz_radial(Color(0.9, 0.85, 0.7), 4.5, 1.1)
		luz.name = "Luz"
		luz.position = Vector2(cx, chao - 220)
		luz.enabled = false
		setor.add_child(luz)
		_instanciar(setor, DIR_COMPONENTES + "interruptor.tscn", "Interruptor", Vector2(cx + 150, chao - 40),
			{"rotulo": "religar " + dados_setores[i][1]})

	_rect(oeste, "SalaGerador", Vector2(520, 260), Color(0.13, 0.13, 0.17), Vector2(320, chao - 130), -3)
	_instanciar(oeste, DIR_COMPONENTES + "mesa_puzzle.tscn", "MesaGerador", Vector2(320, chao), {
		"rotulo": "GERADOR — CADEIA DO ATP",
		"cor": Color(0.7, 0.5, 0.25),
		"puzzle_config": {
			"titulo": "A CADEIA DO ATP",
			"subtitulo": "Arraste os grupos fosfato: cada P adicionado guarda mais energia — o ATP é a moeda energética da célula.",
			"slots": [
				{"aceita": "amp", "rotulo": "1 fosfato"},
				{"aceita": "adp", "rotulo": "2 fosfatos"},
				{"aceita": "atp", "rotulo": "3 fosfatos\n(carregado!)"},
			],
			"separadores": ["+ P →", "+ P →"],
			"pecas": [
				{"id": "amp", "texto": "AMP"},
				{"id": "adp", "texto": "ADP"},
				{"id": "atp", "texto": "ATP"},
				{"id": "sal", "texto": "NaCl (não é daqui!)"},
			],
			"texto_vitoria": "Energia parcial restaurada — o átrio acendeu!",
		},
	})
	_marker(oeste, "PontoDaCelulaP", Vector2(320, chao - 300))
	_label(oeste, "PlacaFosforo", "FÓSFORO, o portador de luz: o vermelho na lixa da caixinha,\no P do NPK dos fertilizantes — e o ATP, a moeda de energia da célula.", Vector2(1500, 0), 460, 12, Color(0.7, 0.72, 0.8))

	# ③ ALA LESTE — Enxofre
	var leste := _no(raiz, Node2D, "AlaLeste")
	_label(leste, "PlacaBorracha", "LINHA DE PRODUÇÃO DE BORRACHA — vulcanização:\no enxofre cria pontes entre as cadeias e a borracha ganha firmeza.", Vector2(3800, 0), 460, 12, Color(0.7, 0.72, 0.8))

	var esteiras := _no(leste, Node2D, "Esteiras")
	var dados_esteiras := [
		[Vector2(3550, chao - 260), Vector2(3610, chao - 170), Vector2(320, 22)],
		[Vector2(4050, chao - 340), Vector2(4110, chao - 250), Vector2(320, 22)],
	]
	for i in dados_esteiras.size():
		var conjunto := _no(esteiras, Node2D, "Esteira%d" % (i + 1)) as Node2D
		_instanciar(conjunto, DIR_COMPONENTES + "alvo_bumerangue.tscn", "Alvo", dados_esteiras[i][0],
			{"permanece_ativo": true, "persistir": true, "rotulo": "liga a esteira %d" % (i + 1)})
		_instanciar(conjunto, DIR_COMPONENTES + "bloco_alternavel.tscn", "Bloco", dados_esteiras[i][1],
			{"tamanho": dados_esteiras[i][2], "cor": Color(0.35, 0.32, 0.28), "solido": false})

	var luz_linha := Blockout.luz_radial(Color(0.7, 0.7, 0.8), 3.0, 0.5)
	luz_linha.name = "LuzLinha"
	luz_linha.position = Vector2(4000, chao - 240)
	leste.add_child(luz_linha)

	_instanciar(leste, DIR_COMPONENTES + "masseira.tscn", "Masseira", Vector2(4450, chao))
	_instanciar(leste, DIR_COMPONENTES + "piso_eletrificado.tscn", "CorredorEletrificado", Vector2(4900, chao - 12),
		{"tamanho": Vector2(560, 24)})
	_label(leste, "PlacaCorredor", "CORREDOR ELETRIFICADO — borracha vulcanizada isola.", Vector2(4900, chao - 200), 420, 12, Color(0.7, 0.72, 0.8))

	_rect(leste, "SalaDisjuntores", Vector2(350, 260), Color(0.13, 0.13, 0.17), Vector2(5425, chao - 130), -3)
	_instanciar(leste, DIR_COMPONENTES + "interruptor.tscn", "Disjuntores", Vector2(5450, chao - 40),
		{"rotulo": "DISJUNTORES GERAIS"})
	_marker(leste, "PontoDaCelulaS", Vector2(5450, chao - 300))
	_label(leste, "PlacaDissulfeto", "O mesmo enxofre que veda o foguete forma as pontes dissulfeto\nque estruturam proteínas — o S da engenharia e o S da vida\nsão o mesmo átomo.", Vector2(5400, 0), 460, 12, Color(0.85, 0.8, 0.6))

	_fechar_fase(raiz, Vector2(2800, chao - 10), Rect2(0, -500, 5680, 1180))
	_salvar(raiz, DIR_FASES + "fase3_subsolo.tscn")


# ============================================================================
#  FINAL — TORRE DE LANÇAMENTO
# ============================================================================

func _gerar_fase_final() -> void:
	print("\n--- FASE FINAL ---")
	var chao := 512.0
	var raiz := _montar_fase("FaseFinal", "res://scripts/fases/fase_final.gd")

	var fundo := _camada_tiles(raiz, "Fundo", -20)
	var terreno := _camada_tiles(raiz, "Terreno", -5)
	_pintar_fundo(fundo, Rect2(0, -3296, 1408, 3808))
	_pintar_solido(terreno, Rect2(0, chao, 1408, 96))
	_pintar_solido(terreno, Rect2(-64, -3296, 64, 3904))
	_pintar_solido(terreno, Rect2(1408, -3296, 64, 3904))
	_pintar_solido(terreno, Rect2(-64, -3360, 1536, 64))

	for r in [
		Rect2(1120, 256, 256, 32), Rect2(160, 384, 256, 32),
		Rect2(544, -256, 288, 32), Rect2(992, -416, 288, 32),
		Rect2(480, -608, 288, 32), Rect2(128, -768, 288, 32),
		Rect2(512, -960, 384, 32), Rect2(928, -1088, 352, 32),
		Rect2(416, -1248, 352, 32), Rect2(128, -1376, 256, 32),
		Rect2(128, -1568, 224, 32), Rect2(704, -1632, 192, 32),
		Rect2(1184, -1728, 192, 32), Rect2(512, -1888, 192, 32),
		Rect2(128, -2016, 224, 32), Rect2(384, -2176, 256, 32),
		Rect2(800, -2304, 256, 32), Rect2(384, -2464, 256, 32),
		Rect2(128, -2592, 224, 32), Rect2(0, -2688, 1408, 32),
	]:
		_pintar_solido(terreno, r)

	var secoes := _no(raiz, Node2D, "Secoes")
	for s in [
		[-160, "T-6  PORTÃO — pisos eletrificados (botas)"],
		[-860, "T-5  GUINDASTES — interruptores à distância (bumerangue)"],
		[-1460, "T-4  TRAVAS SOLDADAS (maçarico oxídrico)"],
		[-2060, "T-3  VÃOS DA ESTRUTURA (mochila de N₂)"],
		[-2660, "T-2  GALERIA INTERNA ESCURA (sinalizador)"],
		[-3100, "T-1  PLATAFORMA DA CÁPSULA"],
	]:
		_label(secoes, "Secao%d" % absi(s[0]), s[1], Vector2(700, s[0]), 460, 15, Color(0.75, 0.62, 0.68))

	# T-6 PORTÃO
	var portao := _no(raiz, Node2D, "Portao")
	_instanciar(portao, DIR_COMPONENTES + "porta_fase.tscn", "PortaHub", Vector2(140, chao), {
		"rotulo": "VOLTAR AO LABORATÓRIO",
		"cena_destino": "res://scenes/laboratório_(world_2).tscn",
		"tag_aqui": "entrada", "tag_destino": "volta_do_lancamento",
	})
	_instanciar(portao, DIR_COMPONENTES + "painel_chonps.tscn", "PainelChonps", Vector2(450, chao - 220))
	_instanciar(portao, DIR_COMPONENTES + "bloco_alternavel.tscn", "PortaoCHONPS", Vector2(672, chao - 150),
		{"tamanho": Vector2(44, 300), "cor": Color(0.6, 0.3, 0.35)})
	_label(portao, "PlacaPortao", "O portão pede o painel CHONPS completo.", Vector2(672, chao - 360), 340, 12, Color(0.9, 0.7, 0.7))
	_instanciar(portao, DIR_COMPONENTES + "piso_eletrificado.tscn", "PisoPortao1", Vector2(880, chao - 12),
		{"tamanho": Vector2(300, 24)})
	_instanciar(portao, DIR_COMPONENTES + "piso_eletrificado.tscn", "PisoPortao2", Vector2(1250, chao - 12),
		{"tamanho": Vector2(220, 24)})

	# T-5 GUINDASTES
	var guindastes := _no(raiz, Node2D, "Guindastes")
	var conjuntos := _no(guindastes, Node2D, "Conjuntos")
	var dados_guindastes := [
		[Vector2(1300, 60), Vector2(880, 150), Vector2(360, 20)],
		[Vector2(120, -100), Vector2(500, -30), Vector2(360, 20)],
	]
	for i in dados_guindastes.size():
		var conjunto := _no(conjuntos, Node2D, "Guindaste%d" % (i + 1)) as Node2D
		_instanciar(conjunto, DIR_COMPONENTES + "alvo_bumerangue.tscn", "Alvo", dados_guindastes[i][0],
			{"permanece_ativo": true, "persistir": true, "rotulo": "guindaste %d" % (i + 1)})
		_instanciar(conjunto, DIR_COMPONENTES + "bloco_alternavel.tscn", "Lanca", dados_guindastes[i][1],
			{"tamanho": dados_guindastes[i][2], "cor": Color(0.55, 0.5, 0.3), "solido": false})

	# T-4 TRAVAS
	var travas := _no(raiz, Node2D, "Travas")
	_instanciar(travas, DIR_COMPONENTES + "chapa_soldada.tscn", "ChapaFinal1", Vector2(920, -1020),
		{"tamanho": Vector2(26, 160), "rotulo": "trava soldada"})
	_instanciar(travas, DIR_COMPONENTES + "chapa_soldada.tscn", "ChapaFinal2", Vector2(400, -1310),
		{"tamanho": Vector2(26, 160), "rotulo": "trava soldada"})

	# T-3 VÃOS
	var vaos := _no(raiz, Node2D, "Vaos")
	_instanciar(vaos, DIR_COMPONENTES + "valvula_purga.tscn", "ValvulaFinal", Vector2(1000, -1790))

	# T-2 GALERIA
	var galeria := _no(raiz, Node2D, "Galeria")
	var sombra := _rect(galeria, "SombraGaleria", Vector2(1408, 600), Color(0.02, 0.02, 0.05, 0.93), Vector2(704, -2400), 20)
	sombra.z_index = 20

	# T-1 PLATAFORMA DA CÁPSULA
	var plataforma := _no(raiz, Node2D, "Plataforma")
	_instanciar(plataforma, DIR_COMPONENTES + "mesa_puzzle.tscn", "MesaPurificador", Vector2(500, -2688), {
		"rotulo": "SUPORTE DE VIDA — PURIFICADOR DE CO₂",
		"cor": Color(0.5, 0.55, 0.7),
		"puzzle_config": {
			"titulo": "CHECAGEM FINAL: O AR QUE VOCÊ VAI RESPIRAR",
			"subtitulo": "Monte a reação que limpa o CO₂ do ar da cabine. Cuidado com os coeficientes.",
			"slots": [
				{"aceita": "lioh", "rotulo": "absorvedor"},
				{"aceita": "co2", "rotulo": "gás expirado"},
				{"aceita": "li2co3", "rotulo": "sal formado"},
				{"aceita": "h2o", "rotulo": "vapor d'água"},
			],
			"separadores": ["+", "→", "+"],
			"pecas": [
				{"id": "lioh", "texto": "2 LiOH"},
				{"id": "co2", "texto": "CO₂"},
				{"id": "li2co3", "texto": "Li₂CO₃"},
				{"id": "h2o", "texto": "H₂O"},
				{"id": "lioh1", "texto": "1 LiOH (não balanceia!)"},
				{"id": "o2", "texto": "O₂ (não é daqui!)"},
			],
			"texto_vitoria": "2LiOH + CO₂ → Li₂CO₃ + H₂O — o ar da cabine está garantido.",
		},
	})

	var capsula := _no(plataforma, Node2D, "Capsula", Vector2(1150, -2890)) as Node2D
	_rect(capsula, "Corpo", Vector2(200, 320), Color(0.75, 0.55, 0.6), Vector2.ZERO, -3)
	_rect(capsula, "Bico", Vector2(120, 80), Color(0.6, 0.4, 0.48), Vector2(0, -200), -3)
	_instanciar(capsula, DIR_COMPONENTES + "porta_fase.tscn", "PortaCapsula", Vector2(0, 202), {
		"rotulo": "EMBARCAR NA CÁPSULA",
		"cena_destino": DIR_FASES + "final_orbita.tscn",
		"tag_aqui": "capsula", "tag_destino": "",
		"cor_porta": Color(0.85, 0.65, 0.7),
	})
	_label(plataforma, "PlacaApollo", "Dr. Chico: \"Na Apollo 13, foi um filtro assim que trouxe\ntodo mundo para casa. Capricha na conta.\"", Vector2(950, -2960), 440, 12, Color(0.85, 0.8, 0.6))

	_fechar_fase(raiz, Vector2(180, chao - 10), Rect2(0, -3340, 1440, 3940))
	_salvar(raiz, DIR_FASES + "fase_final.tscn")


# ============================================================================
#  ENCERRAMENTO — EM ÓRBITA
# ============================================================================

func _gerar_final_orbita() -> void:
	print("\n--- FINAL ORBITA ---")
	var raiz := Node2D.new()
	raiz.name = "FinalOrbita"
	raiz.set_script(load("res://scripts/fases/final_orbita.gd"))

	_rect(raiz, "Espaco", Vector2(1600, 900), Color(0.02, 0.03, 0.08), Vector2(800, 450), -20)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260818
	var estrelas := _no(raiz, Node2D, "Estrelas")
	for i in 90:
		var lado := rng.randf_range(1.0, 3.0)
		var e := _rect(estrelas, "Estrela%d" % i, Vector2(lado, lado), Color(1, 1, 1, rng.randf_range(0.3, 0.9)),
			Vector2(rng.randf_range(0, 1600), rng.randf_range(0, 900)), -19)
		e.z_index = -19

	var terra := _no(raiz, Node2D, "Terra", Vector2(1150, 700)) as Node2D
	_disco(terra, "Halo", 340.0, Color(0.15, 0.35, 0.7), Vector2.ZERO, -15)
	_disco(terra, "Oceano", 330.0, Color(0.2, 0.45, 0.8), Vector2.ZERO, -14)
	var manchas := [Vector2(-120, -140), Vector2(60, -60), Vector2(-40, 90), Vector2(160, -180)]
	for i in manchas.size():
		_disco(terra, "Continente%d" % i, 60.0 + i * 12.0, Color(0.25, 0.55, 0.3), manchas[i], -13)

	var moldura := _no(raiz, Node2D, "Moldura")
	_rect(moldura, "Topo", Vector2(1600, 90), Color(0.10, 0.10, 0.13), Vector2(800, 45), -5)
	_rect(moldura, "Baixo", Vector2(1600, 90), Color(0.10, 0.10, 0.13), Vector2(800, 855), -5)
	_rect(moldura, "Esquerda", Vector2(110, 900), Color(0.10, 0.10, 0.13), Vector2(55, 450), -5)
	_rect(moldura, "Direita", Vector2(110, 900), Color(0.10, 0.10, 0.13), Vector2(1545, 450), -5)

	var gotas := _no(raiz, Node2D, "Gotas")
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 2
	for i in 26:
		_disco(gotas, "Gota%d" % i, rng2.randf_range(4.0, 11.0), Color(0.75, 0.88, 1.0, 0.5),
			Vector2(rng2.randf_range(160, 1440), rng2.randf_range(140, 760)), -8)

	_label(raiz, "Texto", "Em órbita.\n\nNo vidro, gotículas de água — o produto da primeira reação de todas:\n2H₂ + O₂ → 2H₂O\n\nC · H · O · N · P · S\nSeis elementos, uma missão.",
		Vector2(800, 360), 1200, 24)
	_label(raiz, "Rodape", "FIM DO PROTÓTIPO — obrigado por jogar!\n[E] volta ao laboratório",
		Vector2(800, 730), 1200, 16, Color(0.7, 0.72, 0.8))

	_salvar(raiz, DIR_FASES + "final_orbita.tscn")


func _disco(pai: Node, nome: String, raio: float, cor: Color, centro: Vector2, z: int) -> Polygon2D:
	var poligono := Polygon2D.new()
	poligono.name = nome
	var pontos := PackedVector2Array()
	for i in 32:
		var angulo := TAU * i / 32.0
		pontos.append(Vector2(cos(angulo), sin(angulo)) * raio)
	poligono.polygon = pontos
	poligono.color = cor
	poligono.position = centro
	poligono.z_index = z
	pai.add_child(poligono)
	return poligono
