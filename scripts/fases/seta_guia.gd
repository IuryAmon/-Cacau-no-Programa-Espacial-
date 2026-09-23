@tool
class_name SetaGuia
extends Node2D

# --- SETA DE CAMINHO ("GO!" do Metal Slug) ---
#
# Um ponto do mapa para onde a Cacau precisa ir, e a regra de quando apontar
# para ele. A seta em si é a SetaGo (scripts/ui/seta_go.gd), desenhada na tela.
#
# COMO FUNCIONA
#   - O PRÓPRIO NÓ é o alvo: a ponta da seta aponta para a posição dele.
#     Arraste-o para onde a seta deve apontar.
#   - Alvo dentro da tela: a seta fica em cima dele, apontando na `direcao`.
#     Alvo fora da tela: a seta gruda na borda da tela, na altura do alvo, e
#     pisca ali — o "GO!" de quando o Metal Slug manda andar. Conforme a câmera
#     chega perto, ela escorrega da borda até o alvo sozinha.
#   - A filha "Gatilho" (ReferenceRect, só visível no editor) é a área em que a
#     Cacau precisa estar para a seta acordar. Sem Gatilho, vale o mapa todo.
#
# QUANDO APARECE (Inspetor)
#   requer_habilidade        ferramenta que ela já precisa ter (vazio = tanto faz)
#   depois_de                nó que já precisa ter sido feito (EstadoMundo) —
#                            uma porta derretida, um painel resolvido
#   ate                      nó que, feito, aposenta a seta de vez — a porta que
#                            ela manda derreter
#   espera                   segundos dentro do Gatilho antes de aparecer
#                            ("parou em cima da plataforma e não sabe o que
#                            fazer")
#   so_no_chao               a espera só corre com os pés no chão
#   manter_fora_do_gatilho   depois de acender, continua valendo fora do Gatilho
#                            (até ela chegar ou o "ate" acontecer)
#   raio_de_chegada          chegou a essa distância do alvo, a seta some
#
# Na Oficina do Carbono há duas: SetaDescer (em cima do pilar do corredor das
# torretas, manda cair) e SetaVoltarAoInicio (no chão lá embaixo, manda voltar
# até a porta de metal do elevador). Ver fase1_oficina.gd.

@export var direcao: SetaGo.Direcao = SetaGo.Direcao.DIREITA:
	set(valor):
		direcao = valor
		queue_redraw()
@export var texto: String = "GO!":
	set(valor):
		texto = valor
		queue_redraw()
@export_range(0.5, 2.0, 0.05) var escala: float = 1.0

@export_group("Quando aparece")
@export var requer_habilidade: String = ""
@export var depois_de: NodePath
@export var ate: NodePath
@export_range(0.0, 10.0, 0.1, "suffix:s") var espera: float = 0.0
@export var so_no_chao: bool = true
@export var manter_fora_do_gatilho: bool = false
@export_range(0.0, 2000.0, 10.0, "suffix:px") var raio_de_chegada: float = 0.0

@export_group("Borda da tela")
## Distância mínima da ponta até cada borda da tela quando o alvo está fora
## dela: esquerda, topo, direita, base (em pixels de tela). O topo fica bem
## abaixo do canto superior esquerdo, que é da lista de objetivos.
@export var margens_da_tela: Vector4 = Vector4(34, 300, 34, 90)
@export_group("")

var _seta: SetaGo = null
var _gatilho: ReferenceRect = null
var _caminho_depois_de: String = ""
var _caminho_ate: String = ""
var _tempo_no_gatilho: float = 0.0
var _armada: bool = false
var _aposentada: bool = false


func _ready() -> void:
	_gatilho = get_node_or_null("Gatilho") as ReferenceRect
	if Engine.is_editor_hint():
		return

	_caminho_depois_de = _caminho_de(depois_de)
	_caminho_ate = _caminho_de(ate)

	var camada := CanvasLayer.new()
	camada.name = "Tela"
	# Na altura da lista de objetivos: abaixo dos puzzles e das fichas.
	camada.layer = 4
	add_child(camada)
	_seta = SetaGo.new()
	_seta.name = "SetaGo"
	_seta.direcao = direcao
	_seta.texto = texto
	_seta.escala = escala
	camada.add_child(_seta)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or _aposentada:
		_seta.esconder()
		return

	if not _caminho_ate.is_empty() and EstadoMundo.ja_feito_caminho(_caminho_ate):
		# O que ela mandava fazer foi feito: não volta nunca mais.
		_aposentada = true
		_seta.esconder()
		return

	if not _liberada():
		_tempo_no_gatilho = 0.0
		_armada = false
		_seta.esconder()
		return

	var dentro := _gatilho == null or _gatilho.get_global_rect().has_point(player.global_position)
	if dentro:
		var no_chao: bool = not so_no_chao or not player.has_method("is_on_floor") or player.is_on_floor()
		if no_chao:
			_tempo_no_gatilho += delta
		if _tempo_no_gatilho >= espera:
			_armada = true
	else:
		_tempo_no_gatilho = 0.0
		if not manter_fora_do_gatilho:
			_armada = false

	var chegou := raio_de_chegada > 0.0 \
		and player.global_position.distance_to(global_position) <= raio_de_chegada
	if _armada and not chegou:
		_seta.ponta = _ponta_na_tela()
		_seta.mostrar()
	else:
		_seta.esconder()


## As condições de "já pode": ferramenta e o que precisa ter sido feito antes.
func _liberada() -> bool:
	if not requer_habilidade.is_empty() and not Progresso.tem_habilidade(requer_habilidade):
		return false
	if not _caminho_depois_de.is_empty() and not EstadoMundo.ja_feito_caminho(_caminho_depois_de):
		return false
	return true


## Onde a ponta fica na tela: em cima do alvo se ele aparece, ou presa na borda
## (na direção em que ele está) se não.
func _ponta_na_tela() -> Vector2:
	var alvo := get_global_transform_with_canvas().origin
	var tela := get_viewport().get_visible_rect().size
	var minimo := Vector2(margens_da_tela.x, margens_da_tela.y)
	var maximo := tela - Vector2(margens_da_tela.z, margens_da_tela.w)
	# A seta cresce para trás da ponta: do lado de onde ela vem, a borda
	# precisa caber a seta inteira.
	var corpo := SetaGo.comprimento() * escala
	match direcao:
		SetaGo.Direcao.DIREITA:
			minimo.x += corpo
		SetaGo.Direcao.ESQUERDA:
			maximo.x -= corpo
		SetaGo.Direcao.BAIXO:
			minimo.y += corpo
		SetaGo.Direcao.CIMA:
			maximo.y -= corpo
	return alvo.clamp(minimo, maximo)


func _caminho_de(caminho: NodePath) -> String:
	if caminho.is_empty():
		return ""
	var no := get_node_or_null(caminho)
	if no == null:
		push_warning("SetaGuia %s: não achei o nó '%s'." % [name, caminho])
		return ""
	return str(no.get_path())


# ─────────────────────────────────────────────
#  Prévia no editor
# ─────────────────────────────────────────────

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	# A seta no tamanho em que vai aparecer no jogo (a câmera do player tem
	# zoom 1,5: 1 px de tela = 1/1,5 px de mundo).
	var tamanho := escala / 1.5
	var sentido := SetaGo.vetor(direcao)
	var forma := Transform2D(SetaGo.angulo(direcao), Vector2(tamanho, tamanho), 0.0,
		-sentido * SetaGo.FOLGA_DA_PONTA * tamanho) * SetaGo.contorno_seta()
	for inflado in Geometry2D.offset_polygon(forma, SetaGo.CONTORNO * tamanho, Geometry2D.JOIN_MITER):
		draw_colored_polygon(inflado, Color(0, 0, 0, 0.85))
	draw_colored_polygon(forma, Color(SetaGo.AMARELO, 0.9))
	draw_circle(Vector2.ZERO, 3.0, Color(1, 0.3, 0.2))
	if not texto.is_empty():
		var fonte := SetaGo.FONTE
		var tam := int(round(SetaGo.TAM_TEXTO * tamanho))
		var caixa := Rect2(forma[0], Vector2.ZERO)
		for p in forma:
			caixa = caixa.expand(p)
		draw_string(fonte, caixa.position + Vector2(0, -6), texto, HORIZONTAL_ALIGNMENT_LEFT, -1,
			tam, SetaGo.AMARELO)
