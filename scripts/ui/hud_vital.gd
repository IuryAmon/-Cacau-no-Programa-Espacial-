@tool
class_name HudVital
extends Control

# HUD de vitalidade do jogo — desenhado 100% em código (_draw), sem depender de
# nenhum sprite. Isso mantém tudo nítido em qualquer resolução e deixa a mesma
# peça servir para os dois contextos do jogo:
#
#   Modo.PERSONAGEM -> a Cacau no laboratório. Vida baixa e discreta (3 pontos),
#                      medalhão com um traçado de eletrocardiograma que acelera
#                      conforme ela se machuca. Paleta verde-menta.
#
#   Modo.NAVE       -> o simulador da lua. Mesma moldura, mesma barra, mesma
#                      tipografia — mas o medalhão vira a silhueta da nave sendo
#                      escaneada, com avarias acendendo no casco. Paleta ciano.
#
# A leitura de dano segue o padrão dos jogos comerciais: a barra principal cai
# na hora, uma "barra fantasma" mais clara segura o valor antigo por um instante
# e só então escorre — é isso que faz o jogador *sentir* o quanto perdeu.

enum Modo { PERSONAGEM, NAVE }
enum Estado { OK, ALERTA, CRITICO }

## Tamanho de projeto do HUD. Todo o desenho é feito nessas coordenadas; para
## deixar maior ou menor basta mexer no "scale" do nó.
const TAMANHO_BASE := Vector2(452.0, 120.0)

# --- Medalhão (hexágono da esquerda) ---
const HEX_CENTRO := Vector2(60.0, 62.0)
const HEX_RAIO := 46.0

# --- Painel (paralelogramo da direita) ---
const PAINEL_TOPO := 28.0
const PAINEL_BASE := 98.0
const PAINEL_ESQ := 74.0
const PAINEL_DIR := 432.0
const PAINEL_INCLINACAO := 16.0

# --- Barra ---
const BARRA_TOPO := 62.0
const BARRA_BASE := 88.0
const BARRA_ESQ := 126.0
const BARRA_DIR := 414.0
const BARRA_INCLINACAO := 6.0

const TEXTO_BASE_Y := 52.0

# --- Cores neutras (iguais nos dois modos: é isso que dá a identidade única) ---
const COR_PAINEL_TOPO := Color(0.086, 0.110, 0.180, 0.88)
const COR_PAINEL_BASE := Color(0.027, 0.036, 0.066, 0.90)
const COR_TRILHO := Color(0.012, 0.018, 0.038, 0.95)
const COR_BORDA := Color(0.64, 0.80, 1.0, 0.22)
const COR_TEXTO := Color(0.90, 0.95, 1.0, 0.95)
const COR_TEXTO_FRACO := Color(0.56, 0.69, 0.88, 0.60)
const COR_SOMBRA := Color(0.0, 0.0, 0.0, 0.40)

# --- Acentos por estado ---
const ACENTO_PERSONAGEM := Color(0.24, 0.94, 0.60)
const ACENTO_NAVE := Color(0.30, 0.82, 1.0)
const ACENTO_ALERTA := Color(1.0, 0.70, 0.22)
const ACENTO_CRITICO := Color(0.98, 0.19, 0.26)

@export var modo: Modo = Modo.PERSONAGEM:
	set(valor):
		modo = valor
		queue_redraw()

## Nome exibido em caixa alta à esquerda do painel.
@export var titulo: String = "CACAU":
	set(valor):
		titulo = valor
		queue_redraw()

## Rótulo pequeno que aparece antes do número, à direita.
@export var subtitulo: String = "VITAL":
	set(valor):
		subtitulo = valor
		queue_redraw()

## Quantas células a barra tem. 0 = barra contínua (usada pela nave, que tem 100
## de vida e ficaria ilegível picotada em 100 pedaços).
@export_range(0, 12) var segmentos: int = 3:
	set(valor):
		segmentos = valor
		queue_redraw()

## Mostra "87%" em vez de "3 / 3". Ligado no modo nave.
@export var mostrar_porcentagem: bool = false:
	set(valor):
		mostrar_porcentagem = valor
		queue_redraw()

@export var fonte: Font:
	set(valor):
		fonte = valor
		queue_redraw()

## Retrato opcional. Se preenchido, substitui o ícone procedural do medalhão —
## fica aqui para o dia em que existir uma arte de rosto que valha a pena.
@export var retrato: Texture2D:
	set(valor):
		retrato = valor
		queue_redraw()

@export_group("Prévia no editor")
## Deixa a peça se desenhar dentro do editor, para enquadrá-la sem rodar o jogo.
##
## Nasce DESLIGADA porque este HUD está pendurado no player.tscn, que está
## instanciado em toda fase: com a prévia ligada, a barra de vida ficava plantada
## na origem do mapa em todo workspace 2D. Ligue aqui no Inspector enquanto
## estiver mexendo na peça, e desligue depois.
@export var previa_visivel: bool = false:
	set(valor):
		previa_visivel = valor
		queue_redraw()

var _vida: float = 3.0
var _vida_max: float = 3.0
var _fracao: float = 1.0
var _fracao_exibida: float = 1.0
var _fracao_fantasma: float = 1.0
var _espera_fantasma: float = 0.0
var _clarao: float = 0.0
var _clarao_cura: float = 0.0
var _tremor: float = 0.0
var _tempo: float = 0.0
var _fase_batida: float = 0.0
var _iniciado: bool = false


func _ready() -> void:
	custom_minimum_size = TAMANHO_BASE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Engine.is_editor_hint():
		# No editor o HUD fica parado, só como prévia — nada de gastar CPU.
		set_process(false)
		queue_redraw()


func _process(delta: float) -> void:
	_tempo += delta

	# O eletrocardiograma/scanner acelera junto com o perigo.
	_fase_batida += delta * lerpf(2.2, 1.0, clampf(_fracao_exibida, 0.0, 1.0))

	# Preenchimento principal: alcança o alvo rápido, mas com desaceleração.
	_fracao_exibida = lerpf(_fracao_exibida, _fracao, 1.0 - pow(0.001, delta))

	# Barra fantasma: segura o valor antigo e depois escorre.
	if _fracao_fantasma > _fracao_exibida:
		if _espera_fantasma > 0.0:
			_espera_fantasma -= delta
		else:
			_fracao_fantasma = maxf(_fracao_exibida, _fracao_fantasma - delta * 0.55)
	else:
		_fracao_fantasma = _fracao_exibida

	_clarao = maxf(0.0, _clarao - delta * 3.2)
	_clarao_cura = maxf(0.0, _clarao_cura - delta * 2.2)
	_tremor = maxf(0.0, _tremor - delta * 3.6)

	queue_redraw()


# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

## Define vida atual e máxima de uma vez. Na primeira chamada o HUD já nasce no
## valor certo, sem animar de zero.
func definir_vida(vida: float, vida_maxima: float = -1.0) -> void:
	if vida_maxima > 0.0:
		_vida_max = vida_maxima

	var anterior := _fracao
	_vida = clampf(vida, 0.0, _vida_max)
	_fracao = _vida / maxf(_vida_max, 0.001)

	if not _iniciado:
		_iniciado = true
		_fracao_exibida = _fracao
		_fracao_fantasma = _fracao
		queue_redraw()
		return

	if _fracao < anterior - 0.0001:
		_espera_fantasma = 0.45
		_clarao = 1.0
		_tremor = 1.0
	elif _fracao > anterior + 0.0001:
		_fracao_fantasma = _fracao
		_clarao_cura = 1.0

	queue_redraw()


## Só a vida máxima (útil para configurar o HUD antes do primeiro dano).
func definir_vida_maxima(vida_maxima: float) -> void:
	_vida_max = maxf(vida_maxima, 0.001)
	if segmentos > 0:
		segmentos = int(round(_vida_max))
	definir_vida(_vida_max)


## Assinatura antiga usada pelo player — mantida para não quebrar a conexão do
## sinal "health_changed".
func update_health(vida_atual: int) -> void:
	definir_vida(float(vida_atual))


# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------

func _draw() -> void:
	# A trava mora no _draw, e não no _ready, porque o editor recarrega o script
	# sem re-executar o _ready: no _ready a peça continuaria desenhada por cima
	# da fase até alguém fechar e reabrir a cena.
	if Engine.is_editor_hint() and not previa_visivel:
		return

	var acento := _cor_acento()
	var estado := _estado()
	var pulso := 0.0
	if estado == Estado.CRITICO:
		pulso = 0.5 + 0.5 * sin(_tempo * 7.5)

	# Trepidação curta ao levar dano.
	var abalo := Vector2.ZERO
	if _tremor > 0.0:
		var f := _tremor * _tremor
		abalo = Vector2(sin(_tempo * 74.0) * 4.5, cos(_tempo * 61.0) * 2.2) * f
	draw_set_transform(abalo, 0.0, Vector2.ONE)

	_desenhar_painel(acento, pulso)
	_desenhar_textos(acento, estado)
	_desenhar_barra(acento, pulso)
	_desenhar_medalhao(acento, estado, pulso)

	# Clarões por cima de tudo (dano branco-quente, cura na cor do acento).
	if _clarao > 0.02:
		var a := _clarao * _clarao * 0.20
		draw_colored_polygon(_poligono_painel(), Color(1.0, 0.92, 0.92, a))
		draw_colored_polygon(_poligono_hexagono(HEX_CENTRO, HEX_RAIO), Color(1.0, 0.92, 0.92, a))
	if _clarao_cura > 0.02:
		var ac := _clarao_cura * _clarao_cura * 0.16
		draw_colored_polygon(_poligono_painel(), Color(acento.r, acento.g, acento.b, ac))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Painel -----------------------------------------------------------------

func _desenhar_painel(acento: Color, pulso: float) -> void:
	var corpo := _poligono_painel()

	# Sombra projetada: dá o descolamento do cenário.
	var sombra := PackedVector2Array()
	for p in corpo:
		sombra.append(p + Vector2(0.0, 5.0))
	draw_colored_polygon(sombra, COR_SOMBRA)

	# Vidro escuro com gradiente vertical.
	draw_polygon(corpo, PackedColorArray([
		COR_PAINEL_TOPO, COR_PAINEL_TOPO, COR_PAINEL_BASE, COR_PAINEL_BASE
	]))

	# Contorno + fio de luz no topo (o que faz parecer vidro e não um retângulo).
	var contorno := _fechar(corpo)
	draw_polyline(contorno, COR_BORDA, 1.5, true)
	draw_line(corpo[0], corpo[1], Color(0.85, 0.93, 1.0, 0.30), 1.5, true)

	# Fio de acento embaixo, com brilho reagindo ao estado crítico. Nada de
	# cantoneira decorativa à direita: ela encostava no número e era lida como
	# se fosse mais um dígito.
	var brilho_base := 0.45 + pulso * 0.45
	draw_line(corpo[3], corpo[2], Color(acento.r, acento.g, acento.b, brilho_base * 0.5), 3.0, true)
	draw_line(corpo[3], corpo[2], Color(acento.r, acento.g, acento.b, brilho_base), 1.5, true)


func _desenhar_textos(acento: Color, estado: Estado) -> void:
	var f := _fonte()
	if f == null:
		return

	# A direita manda no layout: primeiro o número, depois o rótulo, e o nome
	# ocupa o que sobrar.
	var valor := _texto_valor()
	var cor_valor := COR_TEXTO if estado == Estado.OK else acento
	var larg_valor := _largura_texto(f, valor, 21, 1.0)
	var x_valor := BARRA_DIR + BARRA_INCLINACAO - larg_valor
	_texto(f, Vector2(x_valor, TEXTO_BASE_Y), valor, 21, cor_valor, 1.0)

	var limite := x_valor
	if not subtitulo.is_empty():
		var rotulo := subtitulo.to_upper()
		limite = x_valor - _largura_texto(f, rotulo, 12, 2.2) - 12.0
		_texto(f, Vector2(limite, TEXTO_BASE_Y - 1.0), rotulo, 12, COR_TEXTO_FRACO, 2.2)

	# Nome em caixa alta com espaçamento largo, encolhendo até caber: assim
	# qualquer título que se escreva no inspetor continua legível e sem colisão.
	var x_titulo := BARRA_ESQ + BARRA_INCLINACAO + 4.0
	var disponivel := limite - 14.0 - x_titulo
	var nome := titulo.to_upper()
	var tamanho := 19
	while tamanho > 12 and _largura_texto(f, nome, tamanho, 2.6) > disponivel:
		tamanho -= 1
	_texto(f, Vector2(x_titulo, TEXTO_BASE_Y), nome, tamanho, COR_TEXTO, 2.6)


# --- Barra ------------------------------------------------------------------

func _desenhar_barra(acento: Color, pulso: float) -> void:
	# Trilho escuro afundado.
	var trilho := _paralelogramo(BARRA_ESQ - 3.0, BARRA_DIR + 3.0, BARRA_TOPO - 3.0, BARRA_BASE + 3.0)
	draw_colored_polygon(trilho, COR_TRILHO)
	draw_polyline(_fechar(trilho), Color(0.60, 0.76, 1.0, 0.16), 1.0, true)

	if segmentos > 0:
		_desenhar_barra_segmentada(acento, pulso)
	else:
		_desenhar_barra_continua(acento, pulso)


func _desenhar_barra_segmentada(acento: Color, pulso: float) -> void:
	var vao := 5.0
	var largura_total := BARRA_DIR - BARRA_ESQ
	var largura_celula := (largura_total - vao * (segmentos - 1)) / float(segmentos)

	for i in segmentos:
		var x0 := BARRA_ESQ + i * (largura_celula + vao)
		var x1 := x0 + largura_celula

		# Alvéolo vazio.
		var vazio := _paralelogramo(x0, x1, BARRA_TOPO, BARRA_BASE)
		draw_colored_polygon(vazio, Color(0.10, 0.13, 0.20, 0.75))

		# Quanto desta célula está preenchido (0..1) — permite meia-célula
		# durante a animação, o que suaviza a perda.
		var cheio := clampf(_fracao_exibida * segmentos - i, 0.0, 1.0)
		var fantasma := clampf(_fracao_fantasma * segmentos - i, 0.0, 1.0)

		if fantasma > cheio + 0.01:
			var xf := x0 + largura_celula * fantasma
			draw_colored_polygon(
				_paralelogramo(x0 + largura_celula * cheio, xf, BARRA_TOPO, BARRA_BASE),
				Color(0.93, 0.63, 0.61, 0.92)
			)

		if cheio > 0.01:
			var xc := x0 + largura_celula * cheio
			_preencher_faixa(x0, xc, acento, pulso)

		draw_polyline(_fechar(vazio), Color(0.62, 0.78, 1.0, 0.22), 1.0, true)

	_desenhar_lustro(BARRA_ESQ, BARRA_ESQ + largura_total * _fracao_exibida, acento)


func _desenhar_barra_continua(acento: Color, pulso: float) -> void:
	var largura := BARRA_DIR - BARRA_ESQ
	var x_cheio := BARRA_ESQ + largura * _fracao_exibida
	var x_fantasma := BARRA_ESQ + largura * _fracao_fantasma

	if x_fantasma > x_cheio + 0.5:
		draw_colored_polygon(
			_paralelogramo(x_cheio, x_fantasma, BARRA_TOPO, BARRA_BASE),
			Color(0.93, 0.63, 0.61, 0.92)
		)

	if _fracao_exibida > 0.001:
		_preencher_faixa(BARRA_ESQ, x_cheio, acento, pulso)

	# Marcas de subdivisão: dão escala à barra do casco sem picotá-la.
	for i in range(1, 10):
		var x := BARRA_ESQ + largura * (i / 10.0)
		var alto := 6.0 if i % 5 == 0 else 3.5
		draw_line(
			Vector2(x + BARRA_INCLINACAO, BARRA_TOPO),
			Vector2(x + BARRA_INCLINACAO * (1.0 - alto / (BARRA_BASE - BARRA_TOPO)), BARRA_TOPO + alto),
			Color(0.02, 0.04, 0.08, 0.55), 1.5, true
		)
		draw_line(
			Vector2(x, BARRA_BASE),
			Vector2(x + BARRA_INCLINACAO * (alto / (BARRA_BASE - BARRA_TOPO)), BARRA_BASE - alto),
			Color(0.02, 0.04, 0.08, 0.55), 1.5, true
		)

	draw_polyline(_fechar(_paralelogramo(BARRA_ESQ, BARRA_DIR, BARRA_TOPO, BARRA_BASE)), Color(0.62, 0.78, 1.0, 0.22), 1.0, true)
	_desenhar_lustro(BARRA_ESQ, x_cheio, acento)


## Preenche um trecho da barra com gradiente e a aresta luminosa de ponta.
func _preencher_faixa(x0: float, x1: float, acento: Color, pulso: float) -> void:
	if x1 - x0 < 0.5:
		return

	var claro := acento.lightened(0.18 + pulso * 0.16)
	var escuro := acento.darkened(0.48)
	var quad := _paralelogramo(x0, x1, BARRA_TOPO, BARRA_BASE)

	# Halo por baixo, para o preenchimento parecer emitir luz.
	draw_colored_polygon(
		_paralelogramo(x0 - 2.0, x1 + 2.0, BARRA_TOPO - 2.5, BARRA_BASE + 2.5),
		Color(acento.r, acento.g, acento.b, 0.16 + pulso * 0.14)
	)
	draw_polygon(quad, PackedColorArray([claro, claro, escuro, escuro]))

	# Faixa espelhada na metade de cima — o "verniz" clássico de barra de HUD.
	var meio := BARRA_TOPO + (BARRA_BASE - BARRA_TOPO) * 0.42
	draw_colored_polygon(
		_paralelogramo(x0, x1, BARRA_TOPO, meio),
		Color(1.0, 1.0, 1.0, 0.07)
	)

	# Aresta de ponta bem clara: mostra exatamente onde a vida termina.
	draw_colored_polygon(
		_paralelogramo(maxf(x0, x1 - 2.5), x1, BARRA_TOPO, BARRA_BASE),
		Color(1.0, 1.0, 1.0, 0.75)
	)


## Reflexo diagonal que cruza a barra de tempos em tempos.
func _desenhar_lustro(x0: float, x1: float, acento: Color) -> void:
	if x1 - x0 < 12.0:
		return

	var ciclo := fmod(_tempo * 0.42, 1.0)
	if ciclo > 0.55:
		return

	var percurso := (x1 - x0 + 90.0)
	var centro := x0 - 45.0 + percurso * (ciclo / 0.55)
	var a := clampf(minf(centro - x0, x1 - centro) / 24.0, 0.0, 1.0)
	var lx0 := clampf(centro - 9.0, x0, x1)
	var lx1 := clampf(centro + 9.0, x0, x1)
	if lx1 - lx0 < 1.0:
		return

	draw_colored_polygon(
		_paralelogramo(lx0, lx1, BARRA_TOPO, BARRA_BASE),
		Color(1.0, 1.0, 1.0, 0.13 * a)
	)


# --- Medalhão ---------------------------------------------------------------

func _desenhar_medalhao(acento: Color, estado: Estado, pulso: float) -> void:
	var c := HEX_CENTRO
	var hex := _poligono_hexagono(c, HEX_RAIO)

	draw_colored_polygon(_poligono_hexagono(c + Vector2(0.0, 5.0), HEX_RAIO), COR_SOMBRA)

	# Halo externo pulsando quando a coisa aperta.
	var halo := 0.10 + pulso * 0.22
	for i in range(3, 0, -1):
		draw_polyline(
			_fechar(_poligono_hexagono(c, HEX_RAIO + i * 2.5)),
			Color(acento.r, acento.g, acento.b, halo / float(i * 2)),
			3.0, true
		)

	# Miolo escuro com gradiente radial "falso" (dois hexágonos sobrepostos).
	draw_colored_polygon(hex, COR_PAINEL_BASE)
	draw_colored_polygon(_poligono_hexagono(c, HEX_RAIO * 0.92), Color(0.055, 0.075, 0.125, 0.95))

	_desenhar_riscas(c)

	if retrato != null:
		var lado := HEX_RAIO * 1.25
		draw_texture_rect(retrato, Rect2(c - Vector2(lado, lado) * 0.5, Vector2(lado, lado)), false)
	elif modo == Modo.NAVE:
		_desenhar_nave(c, acento, pulso)
	else:
		_desenhar_eletrocardiograma(c, acento, estado, pulso)

	# Aro do medalhão.
	draw_polyline(_fechar(hex), Color(0.66, 0.80, 1.0, 0.35), 2.0, true)

	# Ponteiro de vida percorrendo a borda do hexágono.
	_desenhar_aro_vida(c, acento, pulso)

	# Rebites nos vértices — detalhe pequeno que vende o acabamento.
	for p in _poligono_hexagono(c, HEX_RAIO):
		draw_circle(p, 2.6, Color(0.05, 0.07, 0.12, 1.0))
		draw_circle(p, 1.5, Color(acento.r, acento.g, acento.b, 0.85))


## Arco de vida acompanhando o perímetro do hexágono, começando no topo.
func _desenhar_aro_vida(centro: Vector2, acento: Color, pulso: float) -> void:
	var borda := _poligono_hexagono(centro, HEX_RAIO)
	# Reordena para o traçado nascer no topo e correr no sentido horário.
	var caminho := PackedVector2Array()
	for i in 7:
		caminho.append(borda[(i + 4) % 6])

	var total := 0.0
	var trechos: Array[float] = []
	for i in 6:
		var d := caminho[i].distance_to(caminho[i + 1])
		trechos.append(d)
		total += d

	var alvo := total * clampf(_fracao_exibida, 0.0, 1.0)
	if alvo <= 0.5:
		return

	var traco := PackedVector2Array([caminho[0]])
	var andado := 0.0
	for i in 6:
		if andado + trechos[i] <= alvo:
			andado += trechos[i]
			traco.append(caminho[i + 1])
		else:
			var t := (alvo - andado) / trechos[i]
			traco.append(caminho[i].lerp(caminho[i + 1], t))
			break

	if traco.size() < 2:
		return

	draw_polyline(traco, Color(acento.r, acento.g, acento.b, 0.22 + pulso * 0.2), 8.0, true)
	draw_polyline(traco, Color(acento.r, acento.g, acento.b, 0.85 + pulso * 0.15), 3.0, true)
	draw_circle(traco[traco.size() - 1], 3.0, Color(1.0, 1.0, 1.0, 0.9))


## Riscas horizontais tênues + varredura, para o miolo parecer uma tela.
func _desenhar_riscas(centro: Vector2) -> void:
	var alcance := HEX_RAIO * 0.78
	var y := -alcance
	while y < alcance:
		var meia := _meia_largura_hexagono(y, HEX_RAIO) - 4.0
		if meia > 2.0:
			draw_line(
				centro + Vector2(-meia, y), centro + Vector2(meia, y),
				Color(0.55, 0.75, 1.0, 0.045), 1.0
			)
		y += 4.0

	var yv := sin(_tempo * 1.6) * alcance * 0.85
	var meia_v := _meia_largura_hexagono(yv, HEX_RAIO) - 4.0
	if meia_v > 2.0:
		draw_line(
			centro + Vector2(-meia_v, yv), centro + Vector2(meia_v, yv),
			Color(0.70, 0.90, 1.0, 0.10), 3.0
		)


## Palavra de status ao estilo dos jogos de survival horror antigos ("FINE",
## "CAUTION", "DANGER"), só que em português.
const _PALAVRA_ESTADO := {
	Estado.OK: "BEM",
	Estado.ALERTA: "CUIDADO",
	Estado.CRITICO: "PERIGO",
}


## Traçado de ECG rolando — o "sinal vital" da Cacau.
func _desenhar_eletrocardiograma(centro: Vector2, acento: Color, estado: Estado, pulso: float) -> void:
	var meia_largura := HEX_RAIO * 0.62
	var amplitude := HEX_RAIO * 0.42
	var pontos := PackedVector2Array()
	var passos := 56

	for i in passos + 1:
		var t := float(i) / passos
		var x := -meia_largura + meia_largura * 2.0 * t
		var fase := fposmod(t + _fase_batida, 1.0)
		# Some nas pontas para o traçado não bater na borda do hexágono.
		var borda := clampf(minf(t, 1.0 - t) / 0.12, 0.0, 1.0)
		pontos.append(centro + Vector2(x, _onda_ecg(fase) * amplitude * borda))

	draw_polyline(pontos, Color(acento.r, acento.g, acento.b, 0.22), 6.0, true)
	draw_polyline(pontos, Color(acento.r, acento.g, acento.b, 0.95), 2.0, true)

	# Cabeça de leitura na ponta direita, brilhando mais forte a cada batida.
	var brilho := clampf(absf(_onda_ecg(fposmod(_fase_batida, 1.0))), 0.0, 1.0)
	draw_circle(pontos[pontos.size() - 1], 2.0 + brilho * 2.5, Color(1.0, 1.0, 1.0, 0.35 + brilho * 0.5))

	var f := _fonte()
	if f != null:
		var palavra: String = _PALAVRA_ESTADO[estado]
		# No crítico a palavra pisca junto com o halo do medalhão, como o
		# "DANGER" vermelho piscante dos jogos antigos.
		var alfa := 0.72 if estado != Estado.CRITICO else 0.45 + pulso * 0.55
		var larg := _largura_texto(f, palavra, 11, 1.6)
		_texto(f, centro + Vector2(-larg * 0.5, HEX_RAIO * 0.58), palavra, 11, Color(acento.r, acento.g, acento.b, alfa), 1.6)


## Forma de onda PQRST aproximada por gaussianas. Negativo = para cima.
func _onda_ecg(t: float) -> float:
	var y := 0.0
	y -= 0.14 * exp(-pow((t - 0.16) / 0.040, 2.0))
	y += 0.16 * exp(-pow((t - 0.29) / 0.016, 2.0))
	y -= 1.00 * exp(-pow((t - 0.335) / 0.013, 2.0))
	y += 0.42 * exp(-pow((t - 0.385) / 0.020, 2.0))
	y -= 0.24 * exp(-pow((t - 0.54) / 0.050, 2.0))
	return y


## Silhueta da nave vista de cima, com propulsores acesos e avarias no casco.
func _desenhar_nave(centro: Vector2, acento: Color, pulso: float) -> void:
	# Tudo é desenhado em unidades de um hexágono de raio 46 e reescalado — a
	# silhueta cabe folgada dentro do medalhão em qualquer tamanho.
	var k := HEX_RAIO / 46.0
	var eixo := centro + Vector2(0.0, -2.0) * k
	var casco := Color(0.64, 0.79, 0.96, 0.94)
	var casco_escuro := Color(0.24, 0.34, 0.50, 0.95)

	# Propulsores primeiro, para ficarem atrás do casco.
	var tremula := 0.70 + 0.30 * sin(_tempo * 24.0) + 0.10 * sin(_tempo * 41.0)
	for lado in [-1.0, 1.0]:
		var base := eixo + Vector2(lado * 5.0, 24.0) * k
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-3.4, 0.0) * k,
			base + Vector2(3.4, 0.0) * k,
			base + Vector2(0.0, 7.0 + 6.0 * tremula) * k,
		]), Color(acento.r, acento.g, acento.b, 0.55))
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-1.6, 0.0) * k,
			base + Vector2(1.6, 0.0) * k,
			base + Vector2(0.0, 4.5 + 4.0 * tremula) * k,
		]), Color(1.0, 1.0, 1.0, 0.75))

	# Asas enflechadas.
	for lado in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			eixo + Vector2(lado * 6.0, -3.0) * k,
			eixo + Vector2(lado * 26.0, 16.0) * k,
			eixo + Vector2(lado * 22.0, 24.0) * k,
			eixo + Vector2(lado * 8.0, 18.0) * k,
		]), casco_escuro)

	# Fuselagem.
	var fuselagem := PackedVector2Array([
		eixo + Vector2(0.0, -30.0) * k,
		eixo + Vector2(6.8, -13.0) * k,
		eixo + Vector2(8.2, 12.0) * k,
		eixo + Vector2(5.4, 24.0) * k,
		eixo + Vector2(-5.4, 24.0) * k,
		eixo + Vector2(-8.2, 12.0) * k,
		eixo + Vector2(-6.8, -13.0) * k,
	])
	draw_colored_polygon(fuselagem, casco)
	draw_polyline(_fechar(fuselagem), Color(0.90, 0.96, 1.0, 0.55), 1.2, true)

	# Cabine iluminada na cor do acento — o "olho" da nave.
	draw_circle(eixo + Vector2(0.0, -9.0) * k, 5.4 * k, Color(acento.r, acento.g, acento.b, 0.30 + pulso * 0.3))
	draw_circle(eixo + Vector2(0.0, -9.0) * k, 4.2 * k, Color(acento.r, acento.g, acento.b, 0.95))
	draw_circle(eixo + Vector2(0.0, -10.2) * k, 1.9 * k, Color(1.0, 1.0, 1.0, 0.85))

	# Avarias: acendem uma a uma conforme o casco se perde.
	var pontos_avaria: Array[Vector2] = [
		Vector2(-20.0, 18.0), Vector2(19.0, 19.0), Vector2(0.0, -22.0)
	]
	var quantas := mini(int(floor((1.0 - _fracao_exibida) * 3.0 + 0.02)), pontos_avaria.size())
	var piscada := 0.45 + 0.55 * absf(sin(_tempo * 6.0))
	for i in quantas:
		var p := eixo + pontos_avaria[i] * k
		draw_circle(p, 4.2 * k, Color(ACENTO_CRITICO.r, ACENTO_CRITICO.g, ACENTO_CRITICO.b, 0.22 * piscada))
		draw_circle(p, 2.0 * k, Color(1.0, 0.45, 0.40, piscada))


# ---------------------------------------------------------------------------
# Auxiliares
# ---------------------------------------------------------------------------

func _cor_acento() -> Color:
	match _estado():
		Estado.CRITICO:
			return ACENTO_CRITICO
		Estado.ALERTA:
			return ACENTO_ALERTA
		_:
			return ACENTO_NAVE if modo == Modo.NAVE else ACENTO_PERSONAGEM


func _estado() -> Estado:
	if segmentos > 0:
		# Com poucas células a leitura é por unidade, não por porcentagem.
		if _vida <= 1.0:
			return Estado.CRITICO
		if _vida <= ceilf(_vida_max * 0.5):
			return Estado.ALERTA
		return Estado.OK

	if _fracao <= 0.22:
		return Estado.CRITICO
	if _fracao <= 0.5:
		return Estado.ALERTA
	return Estado.OK


func _texto_valor() -> String:
	if mostrar_porcentagem:
		return "%d%%" % int(round(_fracao * 100.0))
	return "%d / %d" % [int(round(_vida)), int(round(_vida_max))]


func _fonte() -> Font:
	if fonte != null:
		return fonte
	return get_theme_default_font()


func _poligono_painel() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(PAINEL_ESQ + PAINEL_INCLINACAO, PAINEL_TOPO),
		Vector2(PAINEL_DIR + PAINEL_INCLINACAO, PAINEL_TOPO),
		Vector2(PAINEL_DIR, PAINEL_BASE),
		Vector2(PAINEL_ESQ, PAINEL_BASE),
	])


## Paralelogramo com a mesma inclinação do painel (topo deslocado à direita).
func _paralelogramo(x0: float, x1: float, y0: float, y1: float) -> PackedVector2Array:
	var altura := BARRA_BASE - BARRA_TOPO
	var incl_topo := BARRA_INCLINACAO * ((BARRA_BASE - y0) / altura)
	var incl_base := BARRA_INCLINACAO * ((BARRA_BASE - y1) / altura)
	return PackedVector2Array([
		Vector2(x0 + incl_topo, y0),
		Vector2(x1 + incl_topo, y0),
		Vector2(x1 + incl_base, y1),
		Vector2(x0 + incl_base, y1),
	])


func _poligono_hexagono(centro: Vector2, raio: float) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i)
		pontos.append(centro + Vector2(cos(a), sin(a)) * raio)
	return pontos


## Meia-largura do hexágono de topo plano a uma dada altura em relação ao centro.
func _meia_largura_hexagono(dy: float, raio: float) -> float:
	var limite := raio * 0.8660254
	if absf(dy) >= limite:
		return 0.0
	return raio * (1.0 - 0.5 * absf(dy) / limite)


func _fechar(pontos: PackedVector2Array) -> PackedVector2Array:
	var saida := PackedVector2Array(pontos)
	if saida.size() > 0:
		saida.append(saida[0])
	return saida


## draw_string não tem controle de espaçamento, então o texto vai caractere a
## caractere — é o que dá o "tracking" largo dos rótulos.
func _texto(f: Font, pos: Vector2, txt: String, tamanho: int, cor: Color, espaco: float) -> void:
	var x := pos.x
	for i in txt.length():
		var c := txt[i]
		draw_string(f, Vector2(x, pos.y), c, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)
		x += f.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x + espaco


func _largura_texto(f: Font, txt: String, tamanho: int, espaco: float) -> float:
	if txt.is_empty():
		return 0.0
	var w := 0.0
	for i in txt.length():
		w += f.get_string_size(txt[i], HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x + espaco
	return maxf(0.0, w - espaco)
