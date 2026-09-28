class_name FolhasCaindo
extends Node2D

# --- FOLHAS QUE A PANCADA ARRANCA DA COPA ---
#
# O punhado de folhas secas que se solta quando o bumerangue acerta a árvore
# do pátio (ver ArvoreLenha). Não é um CPUParticles2D por um motivo só:
# partícula não sabe onde fica o chão. Aqui cada folha cai PLANANDO — o ar
# segura a queda, ela vai de um lado para o outro e vira de face enquanto
# desce —, pousa no chão, fica deitada um instante e só então some. Com
# partícula ela atravessaria o terreno, que no pátio é desenhado por cima de
# tudo (z_index 10).
#
# Um nó por pancada, desenhado inteiro num _draw() só, que se apaga sozinho
# quando a última folha some. top_level: as posições das folhas são do MUNDO,
# então o nó fica parado na origem e a árvore que o criou pode balançar à
# vontade sem arrastar as folhas junto.

## Puxão para baixo (px/s²) e o arrasto do ar (1/s). Juntos dão a velocidade
## de planar: GRAVIDADE / ARRASTO ≈ 95 px/s — folha não despenca, desce.
const GRAVIDADE := 300.0
const ARRASTO := 3.2
## O vaivém de folha caindo: um empurrão lateral que troca de lado num ritmo
## próprio de cada folha (px/s² de pico e voltas por segundo).
const BALANCO := 150.0
const BALANCO_RITMO_MIN := 0.35
const BALANCO_RITMO_MAX := 0.65
## Quanto tempo ela fica deitada no chão antes de começar a sumir, e quanto
## leva sumindo. Folha que ainda não pousou some mesmo assim em VIDA_MAXIMA.
const TEMPO_NO_CHAO := 1.1
const TEMPO_SUMINDO := 0.45
const VIDA_MAXIMA := 5.0

## A arte da folha é pixel art de 4x3, ampliada no mesmo 2x do resto do pátio.
const ESCALA := 2.0

## Acima do terreno e da árvore (o Terreno e a parte da frente da copa moram
## no z_index 10).
const Z_FOLHAS := 11

static var _textura: Texture2D = null

var _folhas: Array[Dictionary] = []
var _chao_y: float = 0.0


## Cria o nó das folhas. `chao_y` é a altura (global) em que elas pousam.
static func criar(pai: Node, chao_y: float) -> FolhasCaindo:
	var folhas := FolhasCaindo.new()
	folhas.name = "Folhas"
	folhas.top_level = true
	folhas.z_as_relative = false
	folhas.z_index = Z_FOLHAS
	folhas._chao_y = chao_y
	pai.add_child(folhas)
	folhas.global_position = Vector2.ZERO
	return folhas


## Solta uma folha em `posicao` (global) com um empurrão inicial. `espera`
## atrasa a saída dela — é o que espalha a chuva de folhas no tempo.
func soltar(posicao: Vector2, velocidade: Vector2, cor: Color, espera: float = 0.0) -> void:
	_folhas.append({
		"pos": posicao,
		"vel": velocidade,
		"cor": cor,
		"espera": espera,
		"tempo": 0.0,
		"ritmo": randf_range(BALANCO_RITMO_MIN, BALANCO_RITMO_MAX) * TAU,
		"fase": randf() * TAU,
		"angulo": randf() * TAU,
		"giro": randf_range(-5.0, 5.0),
		"virada": randf() * TAU,
		"giro_virada": randf_range(6.0, 11.0),
		"pousada": false,
		"no_chao": 0.0,
		# Nem toda folha pousa na mesma linha: o chão de grama tem relevo.
		"chao": _chao_y - randf_range(0.0, 3.0),
	})


func _process(delta: float) -> void:
	var i := _folhas.size() - 1
	while i >= 0:
		if not _atualizar(_folhas[i], delta):
			_folhas.remove_at(i)
		i -= 1
	queue_redraw()
	if _folhas.is_empty():
		queue_free()


## Um passo de uma folha. Devolve false quando ela terminou de sumir.
func _atualizar(folha: Dictionary, delta: float) -> bool:
	if folha["espera"] > 0.0:
		folha["espera"] -= delta
		return true
	folha["tempo"] += delta

	if folha["pousada"]:
		folha["no_chao"] += delta
		return folha["no_chao"] < TEMPO_NO_CHAO + TEMPO_SUMINDO

	var vel: Vector2 = folha["vel"]
	vel.y += GRAVIDADE * delta
	vel.x += sin(folha["tempo"] * folha["ritmo"] + folha["fase"]) * BALANCO * delta
	vel *= maxf(0.0, 1.0 - ARRASTO * delta)
	var pos: Vector2 = folha["pos"] + vel * delta
	folha["vel"] = vel
	folha["angulo"] += folha["giro"] * delta
	folha["virada"] += folha["giro_virada"] * delta

	if pos.y >= folha["chao"]:
		# Pousou: deita quase reta e para de virar de face.
		pos.y = folha["chao"]
		folha["pousada"] = true
		folha["angulo"] = randf_range(-0.35, 0.35)
		folha["virada"] = 0.0
	folha["pos"] = pos
	return folha["tempo"] < VIDA_MAXIMA


func _draw() -> void:
	var textura := _textura_da_folha()
	var meio := textura.get_size() * 0.5
	for folha in _folhas:
		if folha["espera"] > 0.0:
			continue
		var cor: Color = folha["cor"]
		cor.a *= _opacidade(folha)
		# Virar de face é achatar a folha no eixo dela: vista de lado, a folha
		# girando no ar some e volta — é o que vende que ela está caindo solta.
		var face := maxf(absf(cos(folha["virada"])), 0.25)
		draw_set_transform(folha["pos"], folha["angulo"], Vector2(ESCALA, ESCALA * face))
		draw_texture(textura, -meio, cor)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _opacidade(folha: Dictionary) -> float:
	var sobra: float
	if folha["pousada"]:
		sobra = TEMPO_NO_CHAO + TEMPO_SUMINDO - folha["no_chao"]
	else:
		sobra = VIDA_MAXIMA - folha["tempo"]
	return clampf(sobra / TEMPO_SUMINDO, 0.0, 1.0)


## Folha de 4x3 pixels, branca: a cor de cada uma vem da paleta da árvore na
## hora de desenhar. As pontas mais escuras dão o volume de folha curvada.
static func _textura_da_folha() -> Texture2D:
	if _textura:
		return _textura
	var imagem := Image.create(4, 3, false, Image.FORMAT_RGBA8)
	var borda := Color(0.78, 0.78, 0.78)
	for x in [1, 2]:
		imagem.set_pixel(x, 0, borda)
		imagem.set_pixel(x, 2, borda)
	for x in 4:
		imagem.set_pixel(x, 1, Color.WHITE if x in [1, 2] else borda)
	_textura = ImageTexture.create_from_image(imagem)
	return _textura
