class_name TutorialFerramenta
extends Control

# --- A FICHA DE TUTORIAL (como se usa a ferramenta que acabou de chegar) ---
#
# Sobe logo depois da ficha de coleta (scripts/ui/popup_item.gd), quando o
# ícone da ferramenta já voou para o cinto: o mundo continua parado e uma
# ficha pequena mostra o que aquilo FAZ. É limpa de propósito — três coisas e
# mais nada:
#
#   a TELINHA   uma cena animada com a Cacau usando a ferramenta
#               (a do bumerangue é scenes/ui/demo_bumerangue.tscn);
#   a FRASE     uma só, embaixo da telinha;
#   a TECLA     que fecha, afundando no pé da ficha: o ESC (△ no controle).
#               O E (□) fecha também, só não aparece desenhado.
#
# Nada de título, etiqueta ou rodapé escrito: quem conta a história é a
# telinha, e a frase só diz para que serve.
#
# A frase e a cena da telinha de cada ferramenta ficam no campo "tutorial" do
# CatalogoFerramentas. A ficha se mede sozinha: a largura vem da telinha e a
# altura, de quantas linhas a frase ocupa.
#
# O TAMANHO da ficha sai da telinha: ela aparece ampliada pela Escala (Scale)
# do nó raiz da cena dela (a do bumerangue está em 2, o dobro do tamanho do
# jogo) e a ficha inteira cresce junto. A letra da frase é TAM_TEXTO.
#
# Quem abre, pausa o jogo e fecha é o FerramentasHUD — este nó só desenha,
# como a ficha de coleta.

## Emitido quando a ficha termina de sair da tela.
signal fechado

## A ação do mapa de entrada desenhada no pé da ficha: é dela que saem a tecla
## (ESC) e o botão do controle (△). É a mesma que fecha os puzzles.
const ACAO_FECHAR := &"fechar"

# --- Medidas (espaço de projeto, em pixels de tela) ---
const MARGEM := 32.0
const CORTE := 26.0
## Largura do texto quando a ferramenta não tem telinha.
const LARGURA_SEM_TELINHA := 360.0
## Vão entre a telinha e a frase, e entre a frase e a tecla.
const ESPACO_FRASE := 24.0
const ESPACO_TECLA := 20.0

const TAM_TEXTO := 26
const ENTRELINHA := 1.45
## A tecla que fecha é o desenho da folha do teclado (16 px) em 3×. O tamanho
## pedido ao EstiloHUD.tecla_da_acao é o que leva a essa ampliação.
const TAM_TECLA := 25
const ALTURA_TECLA := 48.0

# --- Tempos ---
## Respiro antes de a ficha subir: é o tempo de o alvéolo novo estourar no
## cinto, à vista, antes de a tela escurecer de novo.
const ATRASO := 0.35
const DURACAO_ENTRADA := 0.45
const DURACAO_SAIDA := 0.24
## A partir de quanto da entrada a ficha já fecha (a tecla já está na tela).
## Antes disso o toque é de quem estava só passando a ficha anterior.
const ENTRADA_PARA_FECHAR := 0.9
## A telinha só começa o roteiro com a ficha quase no lugar.
const ENTRADA_PARA_ANIMAR := 0.45

var fonte: Font:
	set(valor):
		fonte = valor
		_invalidar()

var _ficha: Dictionary = {}
var _telinha: Control = null
## A ampliação da telinha: a Escala escrita no nó raiz da cena dela.
var _escala_da_telinha := Vector2.ONE
var _telinha_animando: bool = false
var _espera: float = 0.0
var _entrada: float = 0.0
var _saida: float = 0.0
var _tempo: float = 0.0
var _aberto: bool = false
var _layout: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(_invalidar)
	visible = false
	set_process(false)


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

## Abre a ficha. "dados" é o que CatalogoFerramentas.tutorial() devolve:
## texto (a frase), cor e demo (o caminho da cena da telinha).
func abrir(dados: Dictionary) -> void:
	_ficha = {
		"texto": String(dados.get("texto", "")),
		"cor": dados.get("cor", EstiloHUD.ACENTO_PADRAO),
	}
	_montar_telinha(String(dados.get("demo", "")))
	_espera = ATRASO
	_entrada = 0.0
	_saida = 0.0
	_tempo = 0.0
	_aberto = true
	_invalidar()
	visible = true
	set_process(true)
	_posicionar_telinha()


## Fecha a ficha. Quem chamou ouve o sinal "fechado" quando ela sai da tela.
func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	_saida = 0.0
	set_process(true)


func esta_aberto() -> bool:
	return _aberto


## A ficha já está montada o bastante para fechar?
func pode_fechar() -> bool:
	return _aberto and _entrada >= ENTRADA_PARA_FECHAR


## Onde a ficha está e que tamanho ficou depois de se medir.
func retangulo_da_ficha() -> Rect2:
	var m := _medidas()
	var caixa: Rect2 = m["caixa"]
	return caixa


## Onde a telinha fica dentro da ficha (vazio para tutorial sem telinha).
func retangulo_da_telinha() -> Rect2:
	if _telinha == null:
		return Rect2()
	var m := _medidas()
	var canto: Vector2 = m["canto_telinha"]
	return Rect2(canto, _tamanho_da_telinha())


## A cena animada (null se a ferramenta não tem uma).
func telinha() -> Control:
	return _telinha


## A frase, já quebrada nas linhas em que é desenhada.
func linhas_do_texto() -> PackedStringArray:
	return _medidas()["linhas"]


## Largura em que a frase tem de caber (a da telinha).
func largura_do_texto() -> float:
	return _medidas()["largura_texto"]


# ─────────────────────────────────────────────────────────────
# Animação
# ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_tempo += delta

	if _aberto:
		if _espera > 0.0:
			_espera -= delta
		else:
			_entrada = minf(_entrada + delta / DURACAO_ENTRADA, 1.0)
	else:
		_saida = minf(_saida + delta / DURACAO_SAIDA, 1.0)
		if _saida >= 1.0:
			visible = false
			set_process(false)
			_soltar_telinha()
			fechado.emit()
			return

	if _telinha != null and not _telinha_animando and _entrada >= ENTRADA_PARA_ANIMAR:
		_telinha_animando = true
		_telinha.set_process(true)
		if _telinha.has_method("reiniciar"):
			_telinha.reiniciar()

	_posicionar_telinha()
	queue_redraw()


func _suave(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


## Fatia da entrada: 0 antes de "inicio", 1 depois de "fim".
func _etapa(inicio: float, fim: float) -> float:
	return _suave(clampf((_entrada - inicio) / maxf(fim - inicio, 0.001), 0.0, 1.0))


func _alfa_da_ficha() -> float:
	return clampf(_entrada * 1.8, 0.0, 1.0) * (1.0 - _suave(_saida))


## A ficha entra e sai como um bloco: sobe 22 px na entrada, escorre 16 px na
## saída, com um respiro de escala em torno do centro dela. A telinha é um nó
## filho e recebe a mesma conta em _posicionar_telinha().
func _transformacao(m: Dictionary) -> Transform2D:
	var caixa: Rect2 = m["caixa"]
	var e := _suave(_entrada)
	var centro := caixa.get_center()
	var deslocamento := Vector2(0.0, (1.0 - e) * 22.0 + _suave(_saida) * 16.0)
	var escala := lerpf(0.965, 1.0, e) * lerpf(1.0, 0.975, _suave(_saida))
	return Transform2D(0.0, Vector2(escala, escala), 0.0, centro + deslocamento - centro * escala)


# ─────────────────────────────────────────────────────────────
# A telinha
# ─────────────────────────────────────────────────────────────

func _montar_telinha(caminho: String) -> void:
	_soltar_telinha()
	if caminho.is_empty() or not ResourceLoader.exists(caminho):
		return
	var cena := load(caminho) as PackedScene
	if cena == null:
		return
	_telinha = cena.instantiate() as Control
	if _telinha == null:
		return
	_escala_da_telinha = _telinha.scale
	_telinha.modulate.a = 0.0
	add_child(_telinha)
	# Parada até a ficha chegar (ver ENTRADA_PARA_ANIMAR).
	_telinha.set_process(false)
	_telinha_animando = false


func _soltar_telinha() -> void:
	if _telinha != null and is_instance_valid(_telinha):
		_telinha.queue_free()
	_telinha = null
	_telinha_animando = false


## O espaço que a telinha ocupa na ficha, já ampliada.
func _tamanho_da_telinha() -> Vector2:
	if _telinha == null:
		return Vector2.ZERO
	return _telinha.size * _escala_da_telinha


func _posicionar_telinha() -> void:
	if _telinha == null:
		return
	var m := _medidas()
	var canto: Vector2 = m["canto_telinha"]
	var xf := _transformacao(m)
	_telinha.position = xf * canto
	_telinha.scale = xf.get_scale() * _escala_da_telinha
	_telinha.modulate.a = _alfa_da_ficha() * _etapa(0.2, 0.6)


# ─────────────────────────────────────────────────────────────
# Layout (medido uma vez, reaproveitado)
# ─────────────────────────────────────────────────────────────

func _invalidar() -> void:
	_layout.clear()
	queue_redraw()


## Tudo em uma coluna, centrada: telinha, frase, tecla.
func _medidas() -> Dictionary:
	if not _layout.is_empty():
		return _layout

	var tela := _tamanho_da_telinha()
	var largura_texto := tela.x if _telinha != null else LARGURA_SEM_TELINHA
	var linhas := EstiloHUD.quebrar(_fonte(), String(_ficha.get("texto", "")), TAM_TEXTO,
		largura_texto)
	var entrelinha := TAM_TEXTO * ENTRELINHA

	var largura := largura_texto + MARGEM * 2.0
	var topo_frase := MARGEM
	if _telinha != null:
		topo_frase += tela.y + ESPACO_FRASE
	var topo_tecla := topo_frase + linhas.size() * entrelinha + ESPACO_TECLA
	var altura := topo_tecla + ALTURA_TECLA + MARGEM - 6.0

	# Um pouco acima do meio da tela, como a ficha de coleta.
	var origem := Vector2(
		roundf((size.x - largura) * 0.5),
		roundf(size.y * 0.46 - altura * 0.5))

	_layout = {
		"caixa": Rect2(origem, Vector2(largura, altura)),
		"canto_telinha": origem + Vector2(MARGEM, MARGEM),
		"topo_frase": origem.y + topo_frase,
		"centro_tecla": Vector2(origem.x + largura * 0.5,
			roundf(origem.y + topo_tecla + ALTURA_TECLA * 0.5)),
		"largura_texto": largura_texto,
		"linhas": linhas,
		"entrelinha": entrelinha,
	}
	return _layout


# ─────────────────────────────────────────────────────────────
# Desenho
# ─────────────────────────────────────────────────────────────

func _draw() -> void:
	if _ficha.is_empty():
		return

	var m := _medidas()
	var acento: Color = _ficha["cor"]
	var alfa := _alfa_da_ficha()

	# O véu só apaga o cenário, sem auréola: a ficha é pequena e a telinha já
	# é o ponto de luz dela.
	var alfa_veu := clampf(_entrada * 2.2, 0.0, 1.0) * (1.0 - _suave(_saida))
	if alfa_veu > 0.003:
		draw_rect(Rect2(Vector2.ZERO, size), EstiloHUD.com_alfa(EstiloHUD.VEU, alfa_veu))
	if alfa <= 0.003:
		return

	draw_set_transform_matrix(_transformacao(m))
	_desenhar_ficha(m, acento, alfa)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _desenhar_ficha(m: Dictionary, acento: Color, alfa: float) -> void:
	var caixa: Rect2 = m["caixa"]
	var corpo := EstiloHUD.chanfro(caixa, CORTE)

	EstiloHUD.sombra(self, corpo, 7.0, alfa)
	EstiloHUD.vidro(self, corpo, alfa)
	EstiloHUD.moldura(self, corpo, EstiloHUD.com_alfa(EstiloHUD.BORDA, alfa), 1.5,
		_etapa(0.06, 0.5))
	draw_line(corpo[0], corpo[1], EstiloHUD.com_alfa(EstiloHUD.FIO_LUZ, alfa * _etapa(0.2, 0.5)),
		1.5, true)

	# Um fio só em volta da telinha, na cor da ferramenta (a cena em si é um nó
	# filho, desenhado por cima).
	if _telinha != null:
		var canto: Vector2 = m["canto_telinha"]
		draw_rect(Rect2(canto, _tamanho_da_telinha()).grow(2.0),
			EstiloHUD.com_alfa(acento, alfa * 0.8 * _etapa(0.2, 0.6)), false, 2.0)

	_desenhar_frase(m, alfa)
	_desenhar_tecla(m, acento, alfa)


## A frase, centrada embaixo da telinha, linha por linha.
func _desenhar_frase(m: Dictionary, alfa: float) -> void:
	var f := _fonte()
	if f == null:
		return
	var caixa: Rect2 = m["caixa"]
	var linhas: PackedStringArray = m["linhas"]
	var entrelinha: float = m["entrelinha"]
	var topo: float = m["topo_frase"]
	var a_frase := alfa * _etapa(0.4, 0.8)
	if a_frase <= 0.004:
		return
	for i in linhas.size():
		var largura := f.get_string_size(linhas[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_TEXTO).x
		var x := roundf(caixa.get_center().x - largura * 0.5)
		draw_string(f, Vector2(x, topo + f.get_ascent(TAM_TEXTO) + i * entrelinha), linhas[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_TEXTO, EstiloHUD.com_alfa(EstiloHUD.TEXTO, a_frase))


## A tecla que fecha, sozinha e afundando em loop: o ESC da folha do teclado
## (de controle na mão, o △).
func _desenhar_tecla(m: Dictionary, acento: Color, alfa: float) -> void:
	var f := _fonte()
	if f == null:
		return
	var a_tecla := alfa * _etapa(0.62, 0.92)
	if a_tecla <= 0.004:
		return
	var pulso := 0.55 + 0.45 * (0.5 + 0.5 * sin(_tempo * 3.0))
	EstiloHUD.tecla_da_acao(self, f, m["centro_tecla"], BotoesControle.tecla_da_acao(ACAO_FECHAR),
		ACAO_FECHAR, EstiloHUD.com_alfa(acento, pulso), a_tecla, TAM_TECLA)


# ─────────────────────────────────────────────────────────────

func _fonte() -> Font:
	if fonte != null:
		return fonte
	return get_theme_default_font()
