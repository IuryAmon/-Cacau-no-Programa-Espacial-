class_name ZoomNoObjeto
extends Node

# --- A CÂMERA CHEGANDO PERTO DE UMA MÁQUINA (os puzzles no próprio mapa) ---
#
# Os puzzles do compressor e da destilação não abrem outra tela: a câmera
# chega perto da máquina e o puzzle nasce em cima dela, no mesmo lugar (ver
# scripts/ui/varredura_raio_x.gd). Este nó cuida da câmera e do resto do mundo
# enquanto isso:
#
#   CÂMERA   uma câmera só dele, que começa exatamente onde a da Cacau está e
#            desliza até enquadrar a máquina com o zoom pedido, presa aos
#            limites da fase (os mesmos da câmera da Cacau). Fechando, ela
#            volta pelo mesmo caminho e devolve a vez à câmera da Cacau.
#   VÉU      o resto da sala escurece; em volta da máquina, não
#            (shaders/veu_com_foco.gdshader).
#   HUD      os ícones da tela somem (FadeTela.esconder_huds) e voltam no fim.
#
# Quem usa (o Destilador e o CompressorDeAr) para o jogo antes e chama:
#     var zoom := ZoomNoObjeto.chegar_perto(self, recorte_no_mundo, 4.0)
#     await zoom.chegou
#     ... o puzzle ...
#     zoom.voltar()
#     await zoom.voltou      (o nó se apaga sozinho)
# "na_tela(recorte)" diz onde um retângulo do mundo fica na tela com o
# enquadramento final: é assim que o puzzle sabe onde a máquina está.

## A câmera chegou ao enquadramento da máquina.
signal chegou
## A câmera voltou para a Cacau (e este nó já vai se apagar).
signal voltou

const VEU := preload("res://shaders/veu_com_foco.gdshader")
## Acima do mundo e dos ícones da fase; abaixo da tela do puzzle (98).
const CAMADA_DO_VEU := 97
const DURACAO_DA_IDA := 0.8
const DURACAO_DA_VOLTA := 0.65
## Quanto o buraco do véu passa da máquina, para cada lado (px da tela).
const FOLGA_DO_FOCO := 26.0

## O zoom e o meio da tela no fim da chegada.
var zoom_final: float = 2.0
var centro_final: Vector2 = Vector2.ZERO

var _foco_no_mundo: Rect2 = Rect2()
var _camera: Camera2D = null
var _camera_da_cacau: Camera2D = null
var _zoom_de_antes: float = 1.0
var _centro_de_antes: Vector2 = Vector2.ZERO
var _camada: CanvasLayer = null
var _veu: ColorRect = null
var _material: ShaderMaterial = null
var _fade: FadeTela = null
var _forca_do_veu: float = 0.0
var _tween: Tween = null


## Começa a chegar perto: "foco_no_mundo" é o que fica fora do véu (a
## máquina), "zoom" o zoom final e "centro_pedido" o ponto do mundo que deve
## ficar no meio da tela (sem ele, o meio do foco). Perto da borda da fase o
## enquadramento para nela, como a câmera da Cacau.
static func chegar_perto(dono: Node, foco_no_mundo: Rect2, zoom: float,
		centro_pedido: Vector2 = Vector2.INF) -> ZoomNoObjeto:
	var no := ZoomNoObjeto.new()
	no.name = "ZoomNoObjeto"
	no.process_mode = Node.PROCESS_MODE_ALWAYS
	no._foco_no_mundo = foco_no_mundo
	no.zoom_final = zoom
	dono.get_tree().current_scene.add_child(no)
	no._comecar(foco_no_mundo.get_center() if centro_pedido == Vector2.INF else centro_pedido)
	return no


## Onde o retângulo do mundo fica na tela com o enquadramento final.
func na_tela(recorte: Rect2) -> Rect2:
	var canto := centro_final - _meia_tela() / zoom_final
	return Rect2((recorte.position - canto) * zoom_final, recorte.size * zoom_final)


## A câmera volta para a Cacau (o véu some e os ícones voltam). No fim, o sinal
## "voltou" e o nó se apaga.
func voltar() -> void:
	if _camera == null:
		voltou.emit()
		queue_free()
		return
	_matar_o_tween()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_camera, "global_position", _centro_de_antes, DURACAO_DA_VOLTA)
	_tween.tween_property(_camera, "zoom", Vector2.ONE * _zoom_de_antes, DURACAO_DA_VOLTA)
	_tween.tween_property(self, "_forca_do_veu", 0.0, DURACAO_DA_VOLTA * 0.8)
	await _tween.finished
	_devolver_a_camera()
	voltou.emit()
	queue_free()


## Na hora, sem deslizar (a fase está sendo trocada, por exemplo).
func desfazer_na_hora() -> void:
	_matar_o_tween()
	_devolver_a_camera()
	queue_free()


func _comecar(centro_pedido: Vector2) -> void:
	_camera_da_cacau = get_viewport().get_camera_2d()
	if _camera_da_cacau:
		_zoom_de_antes = _camera_da_cacau.zoom.x
		_centro_de_antes = _camera_da_cacau.get_screen_center_position()
	else:
		_zoom_de_antes = zoom_final
		_centro_de_antes = centro_pedido
	centro_final = _centro_preso(centro_pedido)

	# Os ícones somem antes de o véu existir (senão ele sumiria junto).
	var cena := get_tree().current_scene
	_fade = FadeTela.criar(cena)
	_fade.esconder_huds(cena)

	_camera = Camera2D.new()
	_camera.name = "CameraDoZoom"
	_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	_camera.position_smoothing_enabled = false
	add_child(_camera)
	_camera.global_position = _centro_de_antes
	_camera.zoom = Vector2.ONE * _zoom_de_antes
	_camera.make_current()

	_camada = CanvasLayer.new()
	_camada.name = "Veu"
	_camada.layer = CAMADA_DO_VEU
	_camada.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_camada)
	_veu = ColorRect.new()
	_veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = VEU
	_veu.material = _material
	_camada.add_child(_veu)
	_atualizar_o_veu()

	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_camera, "global_position", centro_final, DURACAO_DA_IDA)
	_tween.tween_property(_camera, "zoom", Vector2.ONE * zoom_final, DURACAO_DA_IDA)
	_tween.tween_property(self, "_forca_do_veu", 1.0, DURACAO_DA_IDA * 0.7)
	_tween.finished.connect(chegou.emit)


func _process(_delta: float) -> void:
	_atualizar_o_veu()


func _exit_tree() -> void:
	# Saiu da árvore sem voltar (a fase foi trocada no meio): devolve tudo.
	if _fade and is_instance_valid(_fade):
		_fade.restaurar_huds()


func _atualizar_o_veu() -> void:
	if _material == null or _camera == null:
		return
	var zoom := _camera.zoom.x
	# O deslocamento entra: no estrondo da explosão a tela treme (TelaDoCompressor).
	var canto := _camera.global_position + _camera.offset - _meia_tela() / zoom
	var buraco := Rect2((_foco_no_mundo.position - canto) * zoom, _foco_no_mundo.size * zoom).grow(FOLGA_DO_FOCO)
	_material.set_shader_parameter("buraco", Vector4(buraco.position.x, buraco.position.y, buraco.size.x, buraco.size.y))
	_material.set_shader_parameter("forca", _forca_do_veu)


func _devolver_a_camera() -> void:
	if _camera_da_cacau and is_instance_valid(_camera_da_cacau):
		_camera_da_cacau.make_current()
	if _fade and is_instance_valid(_fade):
		_fade.restaurar_huds()
		_fade.queue_free()
	_fade = null
	if _camera and is_instance_valid(_camera):
		_camera.queue_free()
	_camera = null
	if _camada and is_instance_valid(_camada):
		_camada.queue_free()
	_camada = null
	_material = null


func _matar_o_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


## O meio da tela que mostra "ponto" no meio, preso aos limites da câmera da
## Cacau, e acertado para cada pixel da arte cair num pixel inteiro da tela.
func _centro_preso(ponto: Vector2) -> Vector2:
	var meia := _meia_tela() / zoom_final
	var centro := ponto
	if _camera_da_cacau:
		var esquerda := float(_camera_da_cacau.limit_left) + meia.x
		var direita := float(_camera_da_cacau.limit_right) - meia.x
		var cima := float(_camera_da_cacau.limit_top) + meia.y
		var baixo := float(_camera_da_cacau.limit_bottom) - meia.y
		centro.x = (esquerda + direita) * 0.5 if esquerda > direita else clampf(centro.x, esquerda, direita)
		centro.y = (cima + baixo) * 0.5 if cima > baixo else clampf(centro.y, cima, baixo)
	var canto := ((centro - meia) * zoom_final).round() / zoom_final
	return canto + meia


func _meia_tela() -> Vector2:
	return get_viewport().get_visible_rect().size * 0.5
