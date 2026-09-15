extends Node2D

# --- CENA DE TESTE: LANTERNA + SENTINELAS ---
#
# Sala escura de blockout para validar TUDO da lanterna abrindo só esta cena:
#
#   - feixe em cone com sombras (occluders nas paredes), nos dois modos de
#     mira — PRESA (padrão: lado para onde a personagem olha) e LIVRE
#     (mouse/analógico direito), alternados com L;
#   - 3 Sentinelas (monstros que ANDAM e espreitam paradas até a personagem
#     entrar no raio): uma no corredor do feixe, uma numa plataforma alta
#     (fora do cone em mira PRESA — a mira nunca sobe sozinha; alcançável
#     mirando para cima em mira LIVRE; bordas com lábios a seguram lá) e uma
#     ATRÁS da parede central — essa não pode congelar enquanto a parede
#     cortar a linha de visão, mesmo de frente;
#   - bateria drenando acesa e recuperando apagada, com desligamento
#     automático e descongelamento geral ao zerar;
#   - painel de debug com estado de cada Sentinela, ângulo até a mira e
#     nível de bateria.
#
#   A / D (ou setas)  -> vira a personagem (mira PRESA acompanha)
#   L                 -> alterna mira PRESA / LIVRE
#   R / botão direito -> liga/desliga o feixe
#   B / N             -> DEBUG: derruba a bateria para 5 / recarrega cheia
#
# A cena também entrega mochila e bumerangue (não é só sobre a lanterna, mas
# dá pra validar junto o dash atravessando/imune às Sentinelas):
#   Shift + direção -> dash da mochila; INVULNERÁVEL a dano enquanto dura, e
#                      atravessa qualquer Sentinela (nunca colidem com o
#                      player, dash ou não — a garantia extra do dash é só a
#                      invulnerabilidade a dano)
#   F / clique esq. -> arremessa o bumerangue (8 direções / mirado no cursor)
#
# A geometria segue a fase 3 (chão em y=512, tiles da fonte 13, célula 32).

const CELULA := 32.0
const FONTE_TILES := 13
const TILE_TOPO := Vector2i(2, 0)
const TILE_CORPO := Vector2i(2, 2)
const FONTE_FUNDO := 14

const CHAO := 512.0
const LARGURA := 2560.0

var _lanterna: Lanterna = null
var _painel: Label = null
var _b_antes := false
var _n_antes := false


func _ready() -> void:
	# A cena de teste entrega as flags sozinha — no jogo elas vêm de um
	# pickup_habilidade, como as outras ferramentas.
	Progresso.dar_habilidade("lanterna")
	Progresso.dar_habilidade("mochila")
	Progresso.dar_habilidade("bumerangue")

	var blecaute := CanvasModulate.new()
	blecaute.name = "Blecaute"
	blecaute.color = Color(0.10, 0.11, 0.16)  # mesmo escuro da fase 3
	add_child(blecaute)

	_montar_sala()

	var player: CharacterBody2D = load("res://scenes/player.tscn").instantiate()
	player.name = "Player"
	player.position = Vector2(280, CHAO)
	player.z_index = 2
	add_child(player)
	_lanterna = Lanterna.instalar(player)
	FerramentasPlayer.instalar(player)

	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if camera:
		camera.limit_left = -64
		camera.limit_top = -512
		camera.limit_right = int(LARGURA + 64)
		camera.limit_bottom = 704
		camera.reset_smoothing()

	# --- AS TRÊS SENTINELAS DO ROTEIRO DE TESTE ---
	Sentinela.criar(self, "SentinelaCorredor", Vector2(820, CHAO - 30))
	Sentinela.criar(self, "SentinelaAlta", Vector2(1250, 240))
	# Atrás da parede central: entra no alcance quando o player encosta na
	# parede, mas a linha de visão está cortada — NÃO pode congelar.
	Sentinela.criar(self, "SentinelaAtrasDaParede", Vector2(1840, CHAO - 30))

	Blockout.placa(self, "PlacaTeste", Vector2(620, 150),
		"A/D viram · L mira presa/livre · R liga/desliga a lanterna\nF/clique arremessa · Shift+direção dash (imune a dano)\nB derruba a bateria · N recarrega", 14)

	_montar_painel_debug()


# --- SALA (TileMap + occluders) ---

func _montar_sala() -> void:
	var tileset: TileSet = load("res://assets/tilesets/tileset_fases.tres")

	var fundo := TileMapLayer.new()
	fundo.name = "Fundo"
	fundo.tile_set = tileset
	fundo.scale = Vector2(2, 2)
	fundo.z_index = -20
	add_child(fundo)
	_pintar_fundo(fundo, Rect2(0, -448, LARGURA, 960))

	var terreno := TileMapLayer.new()
	terreno.name = "Terreno"
	terreno.tile_set = tileset
	terreno.scale = Vector2(2, 2)
	terreno.z_index = -5
	add_child(terreno)

	var chao_rect := Rect2(0, CHAO, LARGURA, 96)
	var parede_esq := Rect2(-64, -448, 64, 1056)
	var parede_dir := Rect2(LARGURA, -448, 64, 1056)
	var teto := Rect2(-64, -512, LARGURA + 128, 64)
	# A parede que corta a linha de visão: 9 tiles de altura (o pulo múltiplo
	# atravessa por cima; a luz e a Sentinela, não).
	var parede_central := Rect2(1600, CHAO - 288, 64, 288)
	# Plataforma da sentinela alta, com lábios nas pontas — ela anda, e sem
	# as bordas desceria atrás do player e estragaria o caso "fora do ângulo".
	var plataforma := Rect2(1088, 272, 320, 32)
	var labio_esq := Rect2(1088, 240, 32, 32)
	var labio_dir := Rect2(1376, 240, 32, 32)

	for r in [chao_rect, parede_esq, parede_dir, teto, parede_central,
			plataforma, labio_esq, labio_dir]:
		_pintar_solido(terreno, r)

	# Occluders SÓ nas paredes e no teto: o chão fica sem, para o feixe poder
	# "lamber" o piso em vez de morrer na primeira fileira de tiles.
	var oclusores := Node2D.new()
	oclusores.name = "Oclusores"
	add_child(oclusores)
	for r in [parede_esq, parede_dir, teto, parede_central]:
		Blockout.oclusor_ret(oclusores, r.size, r.get_center())


## Cópias locais dos pintores do gerador de blockout
## (tools/gerar_cenas_fases.gd) — mesmos tiles, mesma célula de 32 px.
func _pintar_solido(camada: TileMapLayer, rect: Rect2) -> void:
	var x0 := int(floor(rect.position.x / CELULA))
	var x1 := int(ceil(rect.end.x / CELULA))
	var y0 := int(floor(rect.position.y / CELULA))
	var y1 := int(ceil(rect.end.y / CELULA))
	for cy in range(y0, maxi(y1, y0 + 1)):
		for cx in range(x0, maxi(x1, x0 + 1)):
			var tile := TILE_TOPO if cy == y0 else TILE_CORPO
			camada.set_cell(Vector2i(cx, cy), FONTE_TILES, tile)


func _pintar_fundo(camada: TileMapLayer, rect: Rect2) -> void:
	var x0 := int(floor(rect.position.x / CELULA))
	var x1 := int(ceil(rect.end.x / CELULA))
	var y0 := int(floor(rect.position.y / CELULA))
	var y1 := int(ceil(rect.end.y / CELULA))
	for cy in range(y0, y1):
		for cx in range(x0, x1):
			camada.set_cell(Vector2i(cx, cy), FONTE_FUNDO, Vector2i(posmod(cx, 2), posmod(cy, 2)))


# --- PAINEL DE DEBUG ---

func _montar_painel_debug() -> void:
	var camada := CanvasLayer.new()
	camada.name = "Debug"
	camada.layer = 10
	add_child(camada)

	_painel = Label.new()
	_painel.position = Vector2(16, 16)
	_painel.add_theme_font_size_override("font_size", 15)
	_painel.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	_painel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_painel.add_theme_constant_override("outline_size", 5)
	camada.add_child(_painel)


func _process(_delta: float) -> void:
	_teclas_de_debug()
	if _painel == null or _lanterna == null:
		return

	var linhas := PackedStringArray()
	linhas.append("LANTERNA  bateria %3.0f%%  %s  mira %s (L)" % [
		_lanterna.bateria,
		"ACESA" if _lanterna.acesa() else ("apagada" if _lanterna.ligada else "DESLIGADA (R)"),
		"LIVRE (mouse)" if _lanterna.mira_livre else "PRESA ao sprite",
	])
	for s: Sentinela in get_tree().get_nodes_in_group("sentinela"):
		var vetor := s.global_position - _lanterna.global_position
		var ang := rad_to_deg(absf(_lanterna.direcao_atual().angle_to(vetor)))
		linhas.append("%-22s %-12s ang %5.1f°  dist %4.0f  %s" % [
			s.name, s.nome_do_estado(), ang, vetor.length(),
			"ILUMINADA" if _lanterna.is_body_lit(s) else "—",
		])
	_painel.text = "\n".join(linhas)


func _teclas_de_debug() -> void:
	var b := Input.is_physical_key_pressed(KEY_B)
	if b and not _b_antes:
		_lanterna.bateria = 5.0
		print("DEBUG [TestLanterna]: bateria derrubada para 5.")
	_b_antes = b

	var n := Input.is_physical_key_pressed(KEY_N)
	if n and not _n_antes:
		_lanterna.recarregar()
		print("DEBUG [TestLanterna]: bateria recarregada.")
	_n_antes = n
