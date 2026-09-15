@tool
class_name PopupItem
extends Control

# --- A FICHA DE AQUISIÇÃO (popup de coleta) ---
#
# O que aparece quando a Cacau pega alguma coisa: o mundo escurece, uma ficha
# de equipamento monta-se no centro da tela com o desenho do item, o nome, a
# categoria e o que aquilo é; o rodapé diz PARA ONDE o item foi e como
# continuar. No [E], o ícone se desprende do medalhão e VOA até o slot da
# mochila — quem fecha o popup vê o item chegar no canto, e não some no ar
# para reaparecer do nada.
#
# Três decisões que valem ser ditas, porque foram elas que sumiram com os
# problemas da versão anterior:
#
#   1. TUDO É DESENHADO (_draw), como no hud_vital.gd e no cinto_hud.gd.
#      Nada de PanelContainer com tema padrão do Godot, nada de partícula com
#      gradiente tingido em tempo de execução. A ficha é nítida em qualquer
#      resolução e a paleta vem inteira do EstiloHUD.
#
#   2. O LAYOUT SE MEDE SOZINHO. A caixa nasce do texto que recebeu: o título
#      encolhe até caber, a descrição quebra em linhas e a altura da ficha vem
#      da soma. Antes o enquadramento era ajustado no olho, no editor, com
#      offsets fixos — e qualquer nome mais comprido escrito numa cena o
#      desmanchava (havia até teste cobrando que o texto do catálogo fosse
#      igual, letra por letra, ao texto da cena; não é mais preciso).
#
#   3. O NOME É SEPARADO DA CATEGORIA. "Cilindro de Oxigênio (Comburente)"
#      vira título grande + etiqueta pequena. Ver EstiloHUD.separar_nome().
#
# Como ajustar: as constantes abaixo são o "guia de estilo" da ficha (largura,
# respiros, tamanhos de fonte, tempos). Mexer em uma delas muda a peça inteira
# de forma coerente — não existe mais posição solta para desalinhar.

## Emitido quando o desenho de saída termina e a ficha já saiu da tela.
signal fechado

# --- Medidas da ficha (espaço de projeto, em pixels de tela) ---
const LARGURA := 720.0
const MARGEM := 32.0
## Corte fundo do chanfro (canto superior-esquerdo e inferior-direito).
const CORTE := 26.0
const RAIO_MEDALHAO := 66.0
const CAIXA_ICONE := 82.0
const ALTURA_RODAPE := 54.0
## Onde a coluna de texto começa, contada da borda esquerda da ficha.
const COLUNA_TEXTO := 200.0

# --- Tipografia ---
const TAM_CHAPEU := 13
const ESPACO_CHAPEU := 3.4
const TAM_ETIQUETA := 12
const ESPACO_ETIQUETA := 2.6
const TAM_TITULO_MAX := 34
const TAM_TITULO_MIN := 20
const ESPACO_TITULO := 1.8
const TAM_DESCRICAO := 18
const ENTRELINHA := 1.52
const TAM_RODAPE := 12
const ESPACO_RODAPE := 2.8
const LARGURA_REGUA := 116.0

# --- Tempos ---
const DURACAO_ENTRADA := 0.55
const DURACAO_SAIDA := 0.24
## O véu demora mais que a ficha para apagar: o ícone ainda está voando para a
## mochila, e é bom que ele voe sobre a tela escura. Casado com o tempo do voo
## (InventarioHud.DURACAO_VOO) para o mundo reacender no encaixe.
const DURACAO_SAIDA_VEU := 0.60

# --- Faíscas ---
const ORBITANTES := 9
const ASCENDENTES := 11

@export var fonte: Font:
	set(valor):
		fonte = valor
		_invalidar()

## Fonte do parágrafo. Vazia = usa a mesma do título; existe para o dia em que
## alguém quiser uma face mais leve no corpo de texto sem tocar em código.
@export var fonte_texto: Font:
	set(valor):
		fonte_texto = valor
		_invalidar()

@export_group("Prévia no editor")
## Desenha a ficha parada dentro do editor, para ajustar enquadramento e texto
## sem rodar o jogo.
##
## Nasce DESLIGADA de propósito: este nó mora dentro do player.tscn, e o player
## está instanciado em toda cena de fase — com a prévia ligada, a ficha cobria
## o nível inteiro no workspace 2D de cada fase. Ligue aqui no Inspector
## enquanto estiver mexendo na ficha, e desligue depois.
@export var previa_visivel: bool = false:
	set(valor):
		previa_visivel = valor
		if Engine.is_editor_hint():
			_ficha = _ficha_de_previa() if previa_visivel else {}
		_invalidar()
@export var previa_nome: String = "Cilindro de Oxigênio (Comburente)":
	set(valor):
		previa_nome = valor
		_invalidar()
@export_multiline var previa_descricao: String = "Quando combinado ao hidrogênio, libera a força bruta que impulsiona o foguete.":
	set(valor):
		previa_descricao = valor
		_invalidar()
@export var previa_id: String = "Cilindro_Oxigenio":
	set(valor):
		previa_id = valor
		_invalidar()
@export var previa_icone: Texture2D:
	set(valor):
		previa_icone = valor
		_invalidar()
@export var previa_destino: String = "MOCHILA · SLOT 1":
	set(valor):
		previa_destino = valor
		_invalidar()

# --- Estado ---
var _ficha: Dictionary = {}
var _entrada: float = 0.0
var _saida: float = 0.0
var _veu_saida: float = 0.0
var _tempo: float = 0.0
var _aberto: bool = false
## O ícone sai do medalhão quando alça voo para a mochila.
var _icone_solto: bool = false
var _clarao_solta: float = 0.0
var _layout: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pixel art: nada de suavizar o desenho do item ao ampliar.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(_invalidar)

	if Engine.is_editor_hint():
		# No editor a ficha é prévia parada — dá para ver e ajustar sem gastar
		# CPU animando dentro da janela do editor. Com "previa_visivel"
		# desligada (o padrão), a ficha fica vazia e o _draw devolve na
		# primeira linha: é o que mantém o workspace das fases limpo.
		_ficha = _ficha_de_previa() if previa_visivel else {}
		_entrada = 1.0
		_tempo = 0.7
		set_process(false)
		queue_redraw()
		return

	visible = false
	set_process(false)


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

## Abre a ficha. "dados" traz nome, descricao, icone, id e destino (o texto do
## rodapé, que diz para onde o item foi).
func abrir(dados: Dictionary) -> void:
	_ficha = _normalizar(dados)
	_entrada = 0.0
	_saida = 0.0
	_veu_saida = 0.0
	_tempo = 0.0
	_icone_solto = false
	_clarao_solta = 0.0
	_aberto = true
	_invalidar()
	visible = true
	set_process(true)


## Fecha a ficha. Não espera nada: quem chamou continua a coreografia (o voo do
## ícone) enquanto a caixa apaga, e ouve o sinal "fechado" no fim.
func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	_saida = 0.0
	_veu_saida = 0.0
	set_process(true)


## Onde o ícone está, em coordenadas de tela — é daqui que ele parte quando
## voa para a mochila ou para o cinto.
func centro_do_medalhao() -> Vector2:
	var m := _medidas()
	var origem: Vector2 = m["origem"]
	var centro: Vector2 = m["centro_medalhao"]
	return get_global_transform() * (origem + centro)


## Tamanho aparente do ícone na ficha, para o voo começar exatamente do
## tamanho que a pessoa está vendo e ir diminuindo até o do slot.
func caixa_do_icone() -> float:
	return CAIXA_ICONE


## Onde a ficha está e que tamanho ficou depois de se medir pelo texto. Serve
## para conferir enquadramento (inclusive no teste headless, que não desenha).
func retangulo_da_ficha() -> Rect2:
	var m := _medidas()
	var origem: Vector2 = m["origem"]
	var altura: float = m["altura"]
	return Rect2(origem, Vector2(LARGURA, altura))


## O ícone saiu do medalhão (virou o voo). Deixa um clarão no lugar, para a
## saída não parecer que o desenho simplesmente sumiu.
func soltar_icone() -> void:
	_icone_solto = true
	_clarao_solta = 1.0
	queue_redraw()


func esta_aberto() -> bool:
	return _aberto


# ─────────────────────────────────────────────────────────────
# Animação
# ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_tempo += delta

	if _aberto:
		_entrada = minf(_entrada + delta / DURACAO_ENTRADA, 1.0)
	else:
		_saida = minf(_saida + delta / DURACAO_SAIDA, 1.0)
		_veu_saida = minf(_veu_saida + delta / DURACAO_SAIDA_VEU, 1.0)
		if _veu_saida >= 1.0:
			visible = false
			set_process(false)
			fechado.emit()

	_clarao_solta = maxf(_clarao_solta - delta * 2.6, 0.0)
	queue_redraw()


## Curva de entrada: sai rápido e freia — sem "back", sem "bounce". A caixa é
## um aparelho ligando, não um brinquedo pulando.
func _suave(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


## Fatia da entrada: 0 antes de "inicio", 1 depois de "fim". É com isto que os
## elementos entram em ordem (chapéu, título, régua, linhas do parágrafo) em
## vez de aparecerem todos juntos.
func _etapa(inicio: float, fim: float) -> float:
	return _suave(clampf((_entrada - inicio) / maxf(fim - inicio, 0.001), 0.0, 1.0))


# ─────────────────────────────────────────────────────────────
# Layout (medido uma vez, reaproveitado)
# ─────────────────────────────────────────────────────────────

func _invalidar() -> void:
	_layout.clear()
	queue_redraw()


func _medidas() -> Dictionary:
	if not _layout.is_empty():
		return _layout

	var f := _fonte()
	var ft := _fonte_texto()
	var largura_texto := LARGURA - COLUNA_TEXTO - MARGEM

	var titulo: String = String(_ficha.get("titulo", "")).to_upper()
	var tam_titulo := EstiloHUD.tamanho_que_cabe(f, titulo, largura_texto, ESPACO_TITULO,
		TAM_TITULO_MAX, TAM_TITULO_MIN)
	var linhas := EstiloHUD.quebrar(ft, String(_ficha.get("descricao", "")),
		TAM_DESCRICAO, largura_texto)
	var entrelinha := TAM_DESCRICAO * ENTRELINHA

	# Altura da coluna de texto, bloco a bloco.
	var altura_chapeu := float(TAM_CHAPEU) + 16.0
	var altura_titulo := float(tam_titulo) + 14.0
	var altura_regua := 24.0
	var altura_desc := linhas.size() * entrelinha
	var altura_texto := altura_chapeu + altura_titulo + altura_regua + altura_desc

	var altura_medalhao := RAIO_MEDALHAO * 1.7320508
	var altura_conteudo := maxf(altura_texto, altura_medalhao) + MARGEM * 2.0
	var altura := altura_conteudo + ALTURA_RODAPE

	# A ficha fica um pouco acima do meio da tela: é onde o olho já está, e
	# sobra caminho para o ícone subir até a mochila no canto de cima.
	var origem := Vector2(
		roundf((size.x - LARGURA) * 0.5),
		roundf(size.y * 0.46 - altura * 0.5))

	_layout = {
		"origem": origem,
		"altura": altura,
		"caixa": Rect2(Vector2.ZERO, Vector2(LARGURA, altura)),
		"centro_medalhao": Vector2(MARGEM + RAIO_MEDALHAO, altura_conteudo * 0.5),
		"topo_texto": (altura_conteudo - altura_texto) * 0.5,
		"largura_texto": largura_texto,
		"tam_titulo": tam_titulo,
		"titulo": titulo,
		"linhas": linhas,
		"entrelinha": entrelinha,
		"altura_chapeu": altura_chapeu,
		"altura_titulo": altura_titulo,
		"altura_regua": altura_regua,
	}
	return _layout


# ─────────────────────────────────────────────────────────────
# Desenho
# ─────────────────────────────────────────────────────────────

func _draw() -> void:
	# A trava da prévia mora AQUI, e não só no _ready, porque o editor recarrega
	# o script sem re-executar o _ready: sem esta linha, a ficha antiga continua
	# desenhada por cima da fase até alguém fechar e reabrir a cena.
	if Engine.is_editor_hint() and not previa_visivel:
		return
	if _ficha.is_empty():
		return

	var m := _medidas()
	var acento: Color = _ficha.get("cor", EstiloHUD.ACENTO_PADRAO)
	var e := _suave(_entrada)
	var alfa_ficha := clampf(_entrada * 1.8, 0.0, 1.0) * (1.0 - _suave(_saida))
	# O véu SEGURA e só então apaga (a ficha é que sai depressa): o ícone voa
	# para a mochila sobre a tela ainda escura, e o mundo volta exatamente
	# quando ele encaixa. Com a mesma curva da ficha, o cenário reacendia no
	# meio do voo e o gesto se perdia.
	var alfa_veu := clampf(_entrada * 2.2, 0.0, 1.0) \
		* (1.0 - smoothstep(0.38, 1.0, _veu_saida))

	_desenhar_veu(m, acento, alfa_veu)

	if alfa_ficha <= 0.003:
		return

	# A ficha inteira entra e sai como um bloco: sobe 26 px na entrada, escorre
	# 18 px na saída, com um respiro de escala. O transform é aplicado em torno
	# do centro da caixa para nada "crescer a partir do canto".
	var caixa: Rect2 = m["caixa"]
	var origem: Vector2 = m["origem"]
	var centro := origem + caixa.size * 0.5
	var deslocamento := Vector2(0.0, (1.0 - e) * 26.0 + _suave(_saida) * 18.0)
	var escala := lerpf(0.965, 1.0, e) * lerpf(1.0, 0.975, _suave(_saida))
	# Escalar em torno do centro da ficha: draw_set_transform faz
	# ponto_final = origem + escala·ponto, logo origem = C - escala·C.
	draw_set_transform(centro + deslocamento - centro * escala, 0.0, Vector2(escala, escala))

	_desenhar_ficha(m, Rect2(origem, caixa.size), acento, alfa_ficha)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Véu: apaga o cenário e acende uma auréola na cor do item atrás da ficha.
##
## A auréola segue a SILHUETA da ficha, em três camadas. Feita com círculos
## concêntricos (o caminho óbvio) ela desenhava anéis visíveis no fundo do
## jogo — banding de manual. Acompanhando a forma da caixa, o mesmo brilho
## some no escuro e ainda ajuda a descolar a peça do cenário.
func _desenhar_veu(m: Dictionary, acento: Color, alfa: float) -> void:
	if alfa <= 0.003:
		return
	draw_rect(Rect2(Vector2.ZERO, size), EstiloHUD.com_alfa(EstiloHUD.VEU, alfa))

	var origem: Vector2 = m["origem"]
	var altura: float = m["altura"]
	var quadro := Rect2(origem, Vector2(LARGURA, altura))
	for i in 3:
		var cresce := 68.0 - i * 26.0
		draw_colored_polygon(EstiloHUD.chanfro(quadro.grow(cresce), CORTE + cresce * 0.5),
			EstiloHUD.com_alfa(acento, alfa * (0.022 + i * 0.014)))


func _desenhar_ficha(m: Dictionary, quadro: Rect2, acento: Color, alfa: float) -> void:
	var corpo := EstiloHUD.chanfro(quadro, CORTE)

	EstiloHUD.sombra(self, corpo, 7.0, alfa)
	EstiloHUD.vidro(self, corpo, alfa)

	# Banho leve do acento no vidro: o painel não é preto morto, ele tem a cor
	# do que está lá dentro.
	draw_colored_polygon(corpo, EstiloHUD.com_alfa(acento, alfa * 0.05))

	_desenhar_rodape(m, quadro, acento, alfa)

	# Contorno que se desenha na entrada, fio de luz no topo, acento na base.
	EstiloHUD.moldura(self, corpo, EstiloHUD.com_alfa(EstiloHUD.BORDA, alfa), 1.5,
		_etapa(0.06, 0.48))
	draw_line(corpo[0], corpo[1], EstiloHUD.com_alfa(EstiloHUD.FIO_LUZ, alfa * _etapa(0.2, 0.5)),
		1.5, true)
	var brilho_base := alfa * _etapa(0.25, 0.6)
	draw_line(corpo[4], corpo[5], EstiloHUD.com_alfa(acento, brilho_base * 0.35), 3.0, true)
	draw_line(corpo[4], corpo[5], EstiloHUD.com_alfa(acento, brilho_base * 0.85), 1.5, true)

	_desenhar_medalhao(m, quadro, acento, alfa)
	_desenhar_texto(m, quadro, acento, alfa)


# --- Medalhão -----------------------------------------------------------------

func _desenhar_medalhao(m: Dictionary, quadro: Rect2, acento: Color, alfa: float) -> void:
	var centro: Vector2 = quadro.position + m["centro_medalhao"]
	var hexa := EstiloHUD.hexagono(centro, RAIO_MEDALHAO)
	var pulso := 0.5 + 0.5 * sin(_tempo * 1.9)

	EstiloHUD.halo(self, centro, RAIO_MEDALHAO * 1.5, acento, 8,
		alfa * (0.55 + pulso * 0.45) * _etapa(0.15, 0.6))

	EstiloHUD.vidro(self, hexa, alfa, EstiloHUD.ALVEOLO,
		Color(0.015, 0.020, 0.040, 0.96))
	draw_colored_polygon(hexa, EstiloHUD.com_alfa(acento, alfa * 0.10))

	# Anel: entra riscando a volta do hexágono, como mira travando no alvo.
	var volta := _etapa(0.12, 0.62)
	EstiloHUD.moldura(self, hexa, EstiloHUD.com_alfa(acento, alfa * 0.85), 2.5, volta)
	# Segundo anel, mais aberto e mais fraco — profundidade sem peso.
	EstiloHUD.moldura(self, EstiloHUD.hexagono(centro, RAIO_MEDALHAO + 7.0),
		EstiloHUD.com_alfa(acento, alfa * 0.22 * volta), 1.0)

	_desenhar_faiscas(centro, acento, alfa)

	# Linha de varredura descendo pelo hexágono durante a entrada: é a mesma
	# ideia do scanner da nave no hud_vital — o aparelho está LENDO o item.
	var varredura := clampf((_entrada - 0.18) / 0.55, 0.0, 1.0)
	if varredura > 0.0 and varredura < 1.0:
		var limite := RAIO_MEDALHAO * 0.8660254
		var y := lerpf(-limite, limite, varredura)
		var meia := _meia_largura_hexagono(y, RAIO_MEDALHAO)
		var forca := sin(varredura * PI)
		draw_line(centro + Vector2(-meia, y), centro + Vector2(meia, y),
			EstiloHUD.com_alfa(acento, alfa * forca * 0.9), 2.0, true)

	if not _icone_solto:
		var flutuar := sin(_tempo * 1.6) * 2.5 * _etapa(0.5, 1.0)
		var surgir := _etapa(0.28, 0.68)
		EstiloHUD.icone(self, _ficha.get("icone", null), centro + Vector2(0.0, flutuar),
			CAIXA_ICONE, EstiloHUD.com_alfa(Color.WHITE, alfa * surgir),
			lerpf(0.84, 1.0, surgir))

	# Clarão do instante em que o ícone se solta e vira voo.
	if _clarao_solta > 0.0:
		var f := _clarao_solta * _clarao_solta
		draw_colored_polygon(hexa, EstiloHUD.com_alfa(Color(1.0, 1.0, 1.0), f * 0.35))
		EstiloHUD.moldura(self, EstiloHUD.hexagono(centro, RAIO_MEDALHAO + (1.0 - f) * 22.0),
			EstiloHUD.com_alfa(acento, f * 0.8), 2.5)


## Meia-largura do hexágono de topo plano a uma altura dy do centro — é o que
## permite cortar a linha de varredura exatamente na silhueta.
func _meia_largura_hexagono(dy: float, raio: float) -> float:
	var limite := raio * 0.8660254
	if absf(dy) >= limite:
		return 0.0
	return raio * (1.0 - 0.5 * absf(dy) / limite)


## Faíscas desenhadas (não são partículas): um punhado orbitando o medalhão e
## outro subindo por dentro dele. Desenhadas à mão porque assim a cor vem
## direto do item, sem tingir gradiente de material em tempo de execução, e
## porque o conjunto todo custa umas vinte circunferências.
func _desenhar_faiscas(centro: Vector2, acento: Color, alfa: float) -> void:
	var forca := alfa * _etapa(0.22, 0.7)
	if forca <= 0.01:
		return

	for i in ORBITANTES:
		var s := float(i)
		var fase := _tempo * (0.5 + fmod(s * 0.37, 1.0) * 0.45) + s * 2.399963
		var raio := RAIO_MEDALHAO * (1.04 + fmod(s * 0.61, 1.0) * 0.30)
		var p := centro + Vector2(cos(fase) * raio, sin(fase) * raio * 0.66)
		var brilho := 0.35 + 0.65 * (0.5 + 0.5 * sin(_tempo * 2.4 + s))
		draw_circle(p, 1.4 + fmod(s * 0.29, 1.0) * 1.5,
			EstiloHUD.com_alfa(acento, forca * brilho * 0.7), true, -1.0, true)

	var limite := RAIO_MEDALHAO * 0.8660254
	for i in ASCENDENTES:
		var s := float(i)
		var ciclo := fmod(_tempo * (0.22 + fmod(s * 0.17, 1.0) * 0.18) + s * 0.0909, 1.0)
		var y := lerpf(limite, -limite, ciclo)
		var meia := _meia_largura_hexagono(y, RAIO_MEDALHAO) * 0.86
		var x := sin(_tempo * 0.8 + s * 1.7) * meia * 0.75
		var vida := sin(ciclo * PI)
		draw_circle(centro + Vector2(x, y), 1.0 + fmod(s * 0.41, 1.0) * 1.2,
			EstiloHUD.com_alfa(acento, forca * vida * 0.55), true, -1.0, true)


# --- Coluna de texto ----------------------------------------------------------

func _desenhar_texto(m: Dictionary, quadro: Rect2, acento: Color, alfa: float) -> void:
	var f := _fonte()
	var ft := _fonte_texto()
	if f == null:
		return

	var x := quadro.position.x + COLUNA_TEXTO
	var y: float = quadro.position.y + m["topo_texto"]

	# Chapéu ("ITEM COLETADO") + etiqueta da categoria ("COMBUSTÍVEL").
	var a_chapeu := alfa * _etapa(0.3, 0.6)
	var chapeu := String(_ficha.get("chapeu", ""))
	var base_chapeu := y + f.get_ascent(TAM_CHAPEU)
	EstiloHUD.texto(self, f, Vector2(x, base_chapeu), chapeu, TAM_CHAPEU,
		EstiloHUD.com_alfa(acento, a_chapeu), ESPACO_CHAPEU)

	var etiqueta := String(_ficha.get("etiqueta", ""))
	if not etiqueta.is_empty():
		var x_etiqueta := x + EstiloHUD.largura_texto(f, chapeu, TAM_CHAPEU, ESPACO_CHAPEU) + 30.0
		# Divisor entre chapéu e etiqueta: um losango pequeno, não um "·" solto.
		# O respiro dos dois lados dele é grande de propósito — encostado, o
		# losango era lido como mais uma letra do chapéu.
		var cy := base_chapeu - f.get_ascent(TAM_CHAPEU) * 0.42
		var cx := x_etiqueta - 15.0
		draw_colored_polygon(PackedVector2Array([
				Vector2(cx, cy - 3.5), Vector2(cx + 3.5, cy),
				Vector2(cx, cy + 3.5), Vector2(cx - 3.5, cy)]),
			EstiloHUD.com_alfa(EstiloHUD.TEXTO_FRACO, a_chapeu))
		EstiloHUD.texto(self, f, Vector2(x_etiqueta, base_chapeu), etiqueta, TAM_ETIQUETA,
			EstiloHUD.com_alfa(EstiloHUD.TEXTO_FRACO, a_chapeu), ESPACO_ETIQUETA)

	# Título.
	y += m["altura_chapeu"]
	var tam_titulo: int = m["tam_titulo"]
	var a_titulo := alfa * _etapa(0.36, 0.68)
	EstiloHUD.texto(self, f, Vector2(x, y + f.get_ascent(tam_titulo)), m["titulo"],
		tam_titulo, EstiloHUD.com_alfa(EstiloHUD.TEXTO, a_titulo), ESPACO_TITULO)

	# Régua: abre da esquerda para a direita, separando nome de explicação.
	y += m["altura_titulo"]
	var abertura := _etapa(0.46, 0.78)
	if abertura > 0.0:
		var y_regua := roundf(y + 2.0)
		draw_line(Vector2(x, y_regua), Vector2(x + LARGURA_REGUA * abertura, y_regua),
			EstiloHUD.com_alfa(acento, alfa * 0.9), 2.0)
		draw_line(Vector2(x + LARGURA_REGUA * abertura, y_regua),
			Vector2(x + m["largura_texto"], y_regua),
			EstiloHUD.com_alfa(EstiloHUD.BORDA, alfa * abertura), 1.0)

	# Parágrafo, linha por linha, entrando em cascata.
	y += m["altura_regua"]
	var linhas: PackedStringArray = m["linhas"]
	var entrelinha: float = m["entrelinha"]
	for i in linhas.size():
		var a_linha := alfa * _etapa(0.56 + i * 0.05, 0.86 + i * 0.05)
		if a_linha <= 0.004:
			continue
		var desliza := (1.0 - _etapa(0.56 + i * 0.05, 0.86 + i * 0.05)) * 6.0
		draw_string(ft, Vector2(x + desliza, y + ft.get_ascent(TAM_DESCRICAO) + i * entrelinha),
			linhas[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_DESCRICAO,
			EstiloHUD.com_alfa(EstiloHUD.TEXTO_FRACO.lightened(0.18), a_linha))


# --- Rodapé -------------------------------------------------------------------

func _desenhar_rodape(m: Dictionary, quadro: Rect2, acento: Color, alfa: float) -> void:
	var f := _fonte()
	if f == null:
		return

	var x0 := quadro.position.x
	var x1 := quadro.end.x
	var y1 := quadro.end.y
	var yr := y1 - ALTURA_RODAPE
	var raso := CORTE * 0.42

	# Faixa mais escura, encaixada nos chanfros de baixo.
	draw_colored_polygon(PackedVector2Array([
			Vector2(x0, yr), Vector2(x1, yr),
			Vector2(x1, y1 - CORTE), Vector2(x1 - CORTE, y1),
			Vector2(x0 + raso, y1), Vector2(x0, y1 - raso)]),
		EstiloHUD.com_alfa(Color(0.012, 0.018, 0.038, 0.55), alfa))
	draw_line(Vector2(x0, yr), Vector2(x1, yr),
		EstiloHUD.com_alfa(EstiloHUD.BORDA, alfa * 0.9), 1.0)

	var a_rodape := alfa * _etapa(0.62, 0.92)
	if a_rodape <= 0.004:
		return
	var meio := yr + ALTURA_RODAPE * 0.5
	var base := meio + f.get_ascent(TAM_RODAPE) * 0.5 - 1.0

	# Esquerda: para onde o item foi. O hexágono miúdo é o mesmo do slot da
	# mochila — quem lê a frase já viu a forma que vai piscar no canto.
	var x := x0 + MARGEM
	draw_colored_polygon(EstiloHUD.hexagono(Vector2(x + 5.0, meio), 5.5),
		EstiloHUD.com_alfa(acento, a_rodape * 0.9))
	EstiloHUD.texto(self, f, Vector2(x + 20.0, base), String(_ficha.get("destino", "")),
		TAM_RODAPE, EstiloHUD.com_alfa(EstiloHUD.TEXTO_FRACO, a_rodape), ESPACO_RODAPE)

	# Direita: a tecla. É a MESMA tampa que aparece embaixo de cada ferramenta
	# no cinto (EstiloHUD.tecla) — a pessoa aprende a forma uma vez. Pulsa
	# devagar: é convite, não alarme.
	var rotulo := "CONTINUAR"
	var largura_rotulo := EstiloHUD.largura_texto(f, rotulo, TAM_RODAPE, ESPACO_RODAPE)
	var pulso := 0.62 + 0.38 * (0.5 + 0.5 * sin(_tempo * 3.0))
	var centro_tecla := Vector2(x1 - MARGEM - largura_rotulo - 12.0 - 15.0, meio)
	EstiloHUD.tecla(self, f, centro_tecla, "E",
		EstiloHUD.com_alfa(acento, pulso), a_rodape)
	EstiloHUD.texto(self, f, Vector2(centro_tecla.x + 27.0, base), rotulo, TAM_RODAPE,
		EstiloHUD.com_alfa(EstiloHUD.TEXTO_FRACO, a_rodape), ESPACO_RODAPE)


# ─────────────────────────────────────────────────────────────
# Ficha
# ─────────────────────────────────────────────────────────────

## Recebe o que o HUD passou e completa o que faltar: separa nome de
## categoria, escolhe o chapéu e a cor pelo id. Assim quem chama só precisa
## saber o que sabe hoje (nome, textura, descrição, id).
func _normalizar(dados: Dictionary) -> Dictionary:
	var id := String(dados.get("id", ""))
	var partes := EstiloHUD.separar_nome(String(dados.get("nome", "")))
	var chapeu := String(dados.get("chapeu", EstiloHUD.chapeu_do_item(id)))
	var etiqueta := String(partes["etiqueta"])
	# "FERRAMENTA ADQUIRIDA · FERRAMENTA" seria eco; a etiqueta cai fora.
	if not etiqueta.is_empty() and chapeu.contains(etiqueta):
		etiqueta = ""
	return {
		"id": id,
		"nome": String(dados.get("nome", "")),
		"titulo": partes["titulo"],
		"etiqueta": etiqueta,
		"chapeu": chapeu,
		"descricao": String(dados.get("descricao", "")),
		"icone": dados.get("icone", null),
		"cor": dados.get("cor", EstiloHUD.cor_do_item(id)),
		"destino": String(dados.get("destino", "")),
	}


func _ficha_de_previa() -> Dictionary:
	return _normalizar({
		"id": previa_id,
		"nome": previa_nome,
		"descricao": previa_descricao,
		"icone": previa_icone,
		"destino": previa_destino,
	})


func _fonte() -> Font:
	if fonte != null:
		return fonte
	return get_theme_default_font()


func _fonte_texto() -> Font:
	if fonte_texto != null:
		return fonte_texto
	return _fonte()
