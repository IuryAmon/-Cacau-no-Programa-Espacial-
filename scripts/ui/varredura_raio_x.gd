class_name VarreduraRaioX
extends Control

# --- A LINHA DO RAIO X (o puzzle nascendo em cima da máquina do mapa) ---
#
# Nos puzzles do compressor e da destilação a tela não troca: a câmera chega
# perto da máquina (ZoomNoObjeto) e uma linha de luz desce por ela, deixando
# para trás o desenho de raio X do puzzle — o "aparelho" (a coluna, a câmara do
# compressor), que nasce exatamente em cima da arte de aço do mapa. Fechando, a
# linha sobe apagando o raio X, e a arte de aço volta a aparecer por baixo.
#
# Quem usa põe este nó (do tamanho da tela) logo depois do aparelho, chama
# preparar() e depois revelar() / esconder() — os dois avisam "terminou". O
# aparelho ganha, enquanto a linha anda, um material que corta tudo o que está
# abaixo dela (shaders/raio_x_revelando.gdshader); parado, fica sem material,
# para nada dele ser cortado.

signal terminou

const SHADER := preload("res://shaders/raio_x_revelando.gdshader")
const DURACAO_DE_REVELAR := 0.75
const DURACAO_DE_ESCONDER := 0.45
## A linha: o miolo, o brilho em volta e o halo largo.
const COR_DO_MIOLO := Color("f2ffff")
const COR_DO_BRILHO := Color(0.55, 0.95, 1.0, 0.55)
const COR_DO_HALO := Color(0.45, 0.85, 1.0, 0.16)

## O nó desenhado em raio X.
var aparelho: Control = null
## Por onde a linha passa, em px do aparelho: do alto ao pé do desenho, e de
## um lado ao outro.
var de_cima: float = 0.0
var ate_embaixo: float = 0.0
var esquerda: float = 0.0
var direita: float = 0.0

## 0 = nada do raio X à mostra, 1 = ele todo.
var revelado: float = 1.0:
	set(valor):
		revelado = valor
		_aplicar()
var _luz: float = 0.0:
	set(valor):
		_luz = valor
		_aplicar()
var _material: ShaderMaterial = null
var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Diz qual é o aparelho e por onde a linha passa (px dele).
func preparar(no: Control, topo: float, pe: float, x_de: float, x_ate: float) -> void:
	aparelho = no
	de_cima = topo
	ate_embaixo = pe
	esquerda = x_de
	direita = x_ate
	_material = ShaderMaterial.new()
	_material.shader = SHADER


## Esconde o raio X na hora (para começar a revelar).
func esconder_na_hora() -> void:
	_matar_o_tween()
	_ligar_o_corte(true)
	revelado = 0.0


## A linha desce, e o raio X fica para trás dela.
func revelar(duracao: float = DURACAO_DE_REVELAR) -> void:
	_andar(1.0, duracao, Tween.EASE_IN_OUT)


## A linha sobe, apagando o raio X.
func esconder(duracao: float = DURACAO_DE_ESCONDER) -> void:
	_andar(0.0, duracao, Tween.EASE_IN_OUT)


## A linha está andando?
func andando() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


func _andar(destino: float, duracao: float, jeito: Tween.EaseType) -> void:
	_matar_o_tween()
	_ligar_o_corte(true)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "revelado", destino, duracao).set_trans(Tween.TRANS_SINE).set_ease(jeito)
	# A luz acende logo e apaga no fim do caminho.
	_tween.tween_property(self, "_luz", 1.0, minf(0.12, duracao * 0.3))
	_tween.chain().tween_property(self, "_luz", 0.0, 0.14)
	await _tween.finished
	_tween = null
	# Todo à mostra, o aparelho fica sem o corte (nada dele some, nem o que
	# passar do pé, como os cacos da explosão).
	if revelado >= 1.0:
		_ligar_o_corte(false)
	terminou.emit()


func _ligar_o_corte(ligado: bool) -> void:
	if aparelho == null or _material == null:
		return
	aparelho.material = _material if ligado else null
	_aplicar()


func _aplicar() -> void:
	if _material:
		_material.set_shader_parameter("corte", lerpf(de_cima, ate_embaixo, revelado))
		_material.set_shader_parameter("forca_da_luz", _luz * 0.85)
	queue_redraw()


func _matar_o_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _draw() -> void:
	if aparelho == null or _luz <= 0.01:
		return
	var y := roundf(aparelho.position.y + lerpf(de_cima, ate_embaixo, revelado))
	var x0 := aparelho.position.x + esquerda - 10.0
	var largura := direita - esquerda + 20.0
	draw_rect(Rect2(x0, y - 9.0, largura, 18.0), Color(COR_DO_HALO, COR_DO_HALO.a * _luz))
	draw_rect(Rect2(x0 + 4.0, y - 4.0, largura - 8.0, 8.0), Color(COR_DO_BRILHO, COR_DO_BRILHO.a * _luz))
	draw_rect(Rect2(x0 + 8.0, y - 1.0, largura - 16.0, 2.0), Color(COR_DO_MIOLO, _luz))
	# As pontas: dois pontinhos mais fortes, como o feixe batendo na borda.
	for x: float in [x0 + 6.0, x0 + largura - 10.0]:
		draw_rect(Rect2(x, y - 3.0, 4.0, 6.0), Color(COR_DO_MIOLO, _luz))
