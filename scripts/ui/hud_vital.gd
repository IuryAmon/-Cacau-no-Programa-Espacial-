@tool
class_name HudVital
extends Control

# --- A VIDA (canto superior esquerdo) ---
#
# Desenhada em código (_draw) com as fichas do EstiloHUD, e servindo os dois
# contextos do jogo:
#
#   Modo.PERSONAGEM -> a Cacau. A vida dela é o NOME dela, escrito com caixas
#                      da tabela periódica:  [Ca] [Ca] [U]  — cálcio, cálcio e
#                      urânio. Três vidas, três fichas. Levar dano arranca a
#                      última ficha do nome (ela racha, cai e deixa a casa
#                      vazia); curar faz a ficha brotar de volta. Não há barra,
#                      número nem rótulo: contar a vida é ler o nome.
#                      Do lado, o rosto dela ("cara do hud.png"): inteira,
#                      piscando em branco na hora da pancada e machucada quando
#                      só sobra uma ficha.
#
#   Modo.NAVE       -> o simulador da lua. A nave tem 100 de casco, que não
#                      cabem em fichas: aqui é o desenho da nave, o nome, a
#                      porcentagem e uma barra chapada. O trecho perdido fica
#                      claro por um instante antes de escorrer — é o que faz a
#                      pessoa sentir o tamanho do dano.

enum Modo { PERSONAGEM, NAVE }
enum Estado { OK, ALERTA, CRITICO }

# --- Medidas (em pixels de tela; a peça inteira cresce com o "scale" do nó) ---
## Respiro até o canto da tela. Fica DENTRO da peça porque o nó mora no canto
## (0, 0): o player.tscn o prende lá, e é assim em toda fase.
const RESPIRO := Vector2(28.0, 22.0)
## Lado de cada ficha de vida.
const LADO := 72.0
## Vão entre duas fichas.
const VAO := 6.0
## Onde as fichas (ou a barra da nave) começam: o rosto fica antes disso.
const X_FICHAS := 128.0
## Com as três fichas da Cacau. É o tamanho do nó nas cenas.
const TAMANHO_BASE := RESPIRO + Vector2(X_FICHAS + LADO * 3.0 + VAO * 2.0, LADO + EstiloHUD.QUEDA)

# --- O rosto da Cacau ---
## A folha tem três quadros de 96 px: inteira, o clarão branco e machucada.
const FOLHA_ROSTO := "res://assets/Cacau Assets/cara do hud.png"
## Só a cabeça de cada quadro (o cabelo ao vento incluído), do queixo para cima.
const ROSTO_INTEIRA := Rect2(22.0, 4.0, 40.0, 22.0)
const ROSTO_CLARAO := Rect2(118.0, 4.0, 40.0, 22.0)
const ROSTO_MACHUCADA := Rect2(214.0, 5.0, 40.0, 22.0)
## Cada pixel do rosto vira um quadrado de 3: o mesmo tamanho do símbolo.
const ESCALA_ROSTO := 3.0

# --- O nome dela na tabela periódica ---
## [símbolo, número atômico] de cada ficha, da esquerda para a direita.
const ELEMENTOS := [["Ca", 20], ["Ca", 20], ["U", 92]]
## Ficha a mais, se um dia a vida máxima passar do nome: mais cálcio.
const ELEMENTO_EXTRA := ["Ca", 20]
const TAM_SIMBOLO := 33
const TAM_NUMERO := 11

# --- A nave ---
const FOLHA_NAVE := "res://assets/simulador lua/nave/sprite_player_spaceship_up_down.png"
const QUADRO_NAVE := Rect2(0.0, 0.0, 350.0, 150.0)
const CAIXA_NAVE := Rect2(0.0, 0.0, 122.0, 52.0)
const BARRA := Rect2(X_FICHAS, 40.0, LADO * 3.0 + VAO * 2.0, 28.0)
const TAM_TITULO := 22
const TAM_SUBTITULO := 11

# --- Cores de estado ---
## A cura, na Cacau e na ficha que volta (o brilho_de_cura.gd usa esta mesma).
const ACENTO_PERSONAGEM := Color(0.24, 0.94, 0.60)
const ACENTO_NAVE := Color("92e8c0")
const ACENTO_ALERTA := Color("ffae70")
const ACENTO_CRITICO := Color("e64539")
## O papel da última ficha, quando ela é a única que resta.
const PAPEL_PERIGO := Color("f2a184")
const TRILHO := Color("2c354d")

# --- Tempos (segundos) ---
const T_QUEDA := 0.62
## Antes de cair, a ficha fica branca este pedaço da queda.
const QUEDA_BRANCA := 0.16
const T_BROTAR := 0.36
## Entre duas fichas que mudam no mesmo golpe.
const ESCALONAR := 0.07

@export var modo: Modo = Modo.PERSONAGEM:
	set(valor):
		modo = valor
		_acertar_filtro()
		queue_redraw()

## Nome escrito embaixo do desenho. Só no modo NAVE: a Cacau é as fichas.
@export var titulo: String = "CACAU":
	set(valor):
		titulo = valor
		queue_redraw()

## O que a barra mede, escrito em cima dela. Só no modo NAVE.
@export var subtitulo: String = "VITAL":
	set(valor):
		subtitulo = valor
		queue_redraw()

## Quantas fichas a Cacau tem (o player acerta sozinho pela vida máxima).
## 0 = barra contínua, que é a da nave.
@export_range(0, 12) var segmentos: int = 3:
	set(valor):
		segmentos = valor
		_acertar_tamanho()
		queue_redraw()

## Mostra "87%" em vez de "3 / 3". Só no modo NAVE.
@export var mostrar_porcentagem: bool = false:
	set(valor):
		mostrar_porcentagem = valor
		queue_redraw()

@export var fonte: Font:
	set(valor):
		fonte = valor
		queue_redraw()

## Outro desenho no lugar do rosto da Cacau (ou da nave). Vazio = o do jogo.
@export var retrato: Texture2D:
	set(valor):
		retrato = valor
		queue_redraw()

@export_group("Prévia no editor")
## Deixa a peça se desenhar dentro do editor, para enquadrá-la sem rodar o jogo.
##
## Nasce DESLIGADA porque este HUD está pendurado no player.tscn, que está
## instanciado em toda fase: com a prévia ligada, a vida ficava plantada na
## origem do mapa em todo workspace 2D. Ligue aqui no Inspector enquanto
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
var _iniciado: bool = false
## Uma por ficha de vida: cheia ou não, e a animação em que ela está.
var _fichas: Array[Dictionary] = []
var _folha_rosto: Texture2D = null
var _folha_nave: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_acertar_filtro()
	_acertar_tamanho()
	_acertar_fichas(false)
	if Engine.is_editor_hint():
		# No editor o HUD fica parado, só como prévia — nada de gastar CPU.
		set_process(false)
		queue_redraw()


func _process(delta: float) -> void:
	_tempo += delta
	var andando := false

	# A barra da nave: alcança o alvo rápido, mas com desaceleração, e o trecho
	# perdido segura um instante antes de escorrer.
	if not is_equal_approx(_fracao_exibida, _fracao):
		_fracao_exibida = lerpf(_fracao_exibida, _fracao, 1.0 - pow(0.001, delta))
		if absf(_fracao_exibida - _fracao) < 0.001:
			_fracao_exibida = _fracao
		andando = true
	if _fracao_fantasma > _fracao_exibida:
		if _espera_fantasma > 0.0:
			_espera_fantasma -= delta
		else:
			_fracao_fantasma = maxf(_fracao_exibida, _fracao_fantasma - delta * 0.55)
		andando = true
	else:
		_fracao_fantasma = _fracao_exibida

	for ficha in _fichas:
		if ficha["atraso"] > 0.0:
			ficha["atraso"] = maxf(ficha["atraso"] - delta, 0.0)
			andando = true
			continue
		if ficha["queda"] >= 0.0:
			ficha["queda"] += delta / T_QUEDA
			if ficha["queda"] >= 1.0:
				ficha["queda"] = -1.0
			andando = true
		if ficha["brota"] >= 0.0:
			ficha["brota"] += delta / T_BROTAR
			if ficha["brota"] >= 1.0:
				ficha["brota"] = -1.0
			andando = true

	if _clarao > 0.0 or _clarao_cura > 0.0 or _tremor > 0.0:
		_clarao = maxf(0.0, _clarao - delta * 3.2)
		_clarao_cura = maxf(0.0, _clarao_cura - delta * 2.2)
		_tremor = maxf(0.0, _tremor - delta * 3.6)
		andando = true

	# Parada e fora de perigo, a peça não muda: não há o que redesenhar.
	if andando or _estado() == Estado.CRITICO:
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
		_acertar_fichas(false)
		queue_redraw()
		return

	if _fracao < anterior - 0.0001:
		_espera_fantasma = 0.45
		_clarao = 1.0
		_tremor = 1.0
	elif _fracao > anterior + 0.0001:
		_fracao_fantasma = _fracao
		_clarao_cura = 1.0

	_acertar_fichas(true)
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


## Quantas fichas de vida estão cheias agora (as que estão caindo já não contam).
func fichas_cheias() -> int:
	var cheias := 0
	for ficha in _fichas:
		if ficha["cheia"]:
			cheias += 1
	return cheias


## O símbolo escrito em cada ficha, da esquerda para a direita.
func simbolos() -> PackedStringArray:
	var lista := PackedStringArray()
	for i in _fichas.size():
		lista.append(String(_elemento(i)[0]))
	return lista


## Onde a ficha "indice" fica, nas coordenadas deste nó.
func retangulo_da_ficha(indice: int) -> Rect2:
	var casa := _casa(indice)
	casa.position += RESPIRO
	return casa


## A casa da ficha, contada do canto do desenho (sem o respiro da tela).
func _casa(indice: int) -> Rect2:
	return Rect2(X_FICHAS + indice * (LADO + VAO), 0.0, LADO, LADO)


# ---------------------------------------------------------------------------
# As fichas de vida
# ---------------------------------------------------------------------------

func _quantas_fichas() -> int:
	return segmentos if modo == Modo.PERSONAGEM else 0


## Põe cada ficha no estado que a vida pede. Com "animar", a que esvazia cai e
## a que enche brota; sem, elas já aparecem como devem estar.
func _acertar_fichas(animar: bool) -> void:
	var total := _quantas_fichas()
	while _fichas.size() < total:
		_fichas.append({"cheia": true, "queda": -1.0, "brota": -1.0, "atraso": 0.0})
	while _fichas.size() > total:
		_fichas.pop_back()

	var cheias := int(ceilf(_vida - 0.0001))
	var na_fila := 0
	# As que caem saem da ponta do nome para dentro; as que voltam, de dentro
	# para a ponta.
	for i in range(total - 1, -1, -1):
		var ficha := _fichas[i]
		if ficha["cheia"] and i >= cheias:
			ficha["cheia"] = false
			ficha["brota"] = -1.0
			ficha["queda"] = 0.0 if animar else -1.0
			ficha["atraso"] = na_fila * ESCALONAR if animar else 0.0
			na_fila += 1
	na_fila = 0
	for i in total:
		var ficha := _fichas[i]
		if not ficha["cheia"] and i < cheias:
			ficha["cheia"] = true
			ficha["queda"] = -1.0
			ficha["brota"] = 0.0 if animar else -1.0
			ficha["atraso"] = na_fila * ESCALONAR if animar else 0.0
			na_fila += 1


func _elemento(indice: int) -> Array:
	return ELEMENTOS[indice] if indice < ELEMENTOS.size() else ELEMENTO_EXTRA


func _acertar_tamanho() -> void:
	var fichas := maxi(segmentos if modo == Modo.PERSONAGEM else 3, 3)
	custom_minimum_size = RESPIRO + Vector2(X_FICHAS + fichas * LADO + (fichas - 1) * VAO,
		LADO + EstiloHUD.QUEDA)


## O rosto e as fichas são pixel art (o filtro do projeto); a nave é desenho
## grande, reduzido, e pede o filtro suave.
func _acertar_filtro() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if modo == Modo.NAVE \
		else CanvasItem.TEXTURE_FILTER_PARENT_NODE


# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------

func _draw() -> void:
	# A trava mora no _draw, e não no _ready, porque o editor recarrega o script
	# sem re-executar o _ready: no _ready a peça continuaria desenhada por cima
	# da fase até alguém fechar e reabrir a cena.
	if Engine.is_editor_hint() and not previa_visivel:
		return

	# Tudo é desenhado a partir do respiro da tela, mais a trepidação curta de
	# quando ela leva dano (em pixels inteiros).
	var abalo := RESPIRO
	if _tremor > 0.0:
		var f := _tremor * _tremor
		abalo += (Vector2(sin(_tempo * 74.0) * 5.0, cos(_tempo * 61.0) * 3.0) * f).round()

	if modo == Modo.NAVE:
		_desenhar_nave(abalo)
	else:
		_desenhar_rosto(abalo)
		if _fichas.size() != _quantas_fichas():
			_acertar_fichas(false)
		for i in _fichas.size():
			_desenhar_casa(i, abalo)
		# As que caem passam por cima das vizinhas.
		for i in _fichas.size():
			_desenhar_queda(i, abalo)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- A Cacau ------------------------------------------------------------------

func _desenhar_rosto(abalo: Vector2) -> void:
	var folha := retrato if retrato != null else _rosto()
	if folha == null:
		return

	var recorte := ROSTO_INTEIRA
	if _vida <= 0.0 or _estado() == Estado.CRITICO:
		recorte = ROSTO_MACHUCADA
	# Duas piscadas brancas na pancada.
	var piscando := _clarao > 0.0 and int(_clarao * 4.0) % 2 == 1
	if piscando:
		recorte = ROSTO_CLARAO

	var tamanho := recorte.size * ESCALA_ROSTO
	# Um pulinho quando ela se cura.
	var pulo := -roundf(sin(clampf(_clarao_cura, 0.0, 1.0) * PI) * 5.0)
	var canto := Vector2(0.0, roundf((LADO - tamanho.y) * 0.5) + pulo) + abalo

	if retrato != null:
		draw_texture_rect(folha, Rect2(canto, Vector2(tamanho.y, tamanho.y)), false)
		return

	# A sombra dura é a própria silhueta (o quadro do clarão), escurecida.
	draw_texture_rect_region(folha, Rect2(canto + Vector2(0.0, EstiloHUD.QUEDA), tamanho),
		Rect2(ROSTO_CLARAO.position, recorte.size), EstiloHUD.SOMBRA_DURA * Color(0, 0, 0, 1))
	draw_texture_rect_region(folha, Rect2(canto, tamanho), recorte)


## A casa da ficha: o papel com o elemento, se a vida está lá, ou o furo vazio.
func _desenhar_casa(indice: int, abalo: Vector2) -> void:
	var ficha := _fichas[indice]
	var casa := _casa(indice)
	casa.position += abalo
	var elemento := _elemento(indice)

	if not ficha["cheia"]:
		# Enquanto a ficha ainda está branca (antes de cair), a casa espera.
		if ficha["queda"] >= 0.0 and (ficha["atraso"] > 0.0 or ficha["queda"] < QUEDA_BRANCA):
			return
		EstiloHUD.casa_vazia(self, casa)
		_escrever_elemento(casa, elemento, EstiloHUD.com_alfa(EstiloHUD.CLARO, 0.22))
		return

	var papel := EstiloHUD.PAPEL
	# A última ficha, sozinha, pulsa: é o aviso de perigo.
	if _estado() == Estado.CRITICO:
		papel = papel.lerp(PAPEL_PERIGO, 0.45 + 0.55 * (0.5 + 0.5 * sin(_tempo * 7.5)))

	var brota: float = ficha["brota"]
	if brota < 0.0 or ficha["atraso"] > 0.0:
		if ficha["atraso"] > 0.0:
			EstiloHUD.casa_vazia(self, casa)
			return
		EstiloHUD.ficha(self, casa, 1.0, papel)
		_escrever_elemento(casa, elemento, EstiloHUD.TINTA)
		return

	# Brotando: cresce passando um tico do tamanho, branca, e assenta.
	var escala := _passar_e_voltar(brota)
	var centro := casa.get_center()
	EstiloHUD.casa_vazia(self, casa, 1.0 - brota)
	draw_set_transform(centro, 0.0, Vector2(escala, escala))
	var local := Rect2(-casa.size * 0.5, casa.size)
	EstiloHUD.ficha(self, local, 1.0, papel.lerp(Color.WHITE, pow(1.0 - brota, 2.0)))
	_escrever_elemento(local, elemento, EstiloHUD.TINTA)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# O aro verde que abre em volta: é a cor da cura na Cacau.
	EstiloHUD.aro(self, casa.grow(roundf(brota * 14.0)),
		EstiloHUD.com_alfa(ACENTO_PERSONAGEM, 1.0 - brota), EstiloHUD.MOLDURA)


## A ficha arrancada: fica branca um instante, e então cai girando e apagando,
## com as lascas de papel espirrando do lugar onde ela estava.
func _desenhar_queda(indice: int, abalo: Vector2) -> void:
	var ficha := _fichas[indice]
	var queda: float = ficha["queda"]
	if queda < 0.0:
		return
	var casa := _casa(indice)
	casa.position += abalo
	var elemento := _elemento(indice)

	if ficha["atraso"] > 0.0 or queda < QUEDA_BRANCA:
		EstiloHUD.ficha(self, casa, 1.0, Color.WHITE, EstiloHUD.TINTA)
		_escrever_elemento(casa, elemento, EstiloHUD.TINTA)
		return

	var p := (queda - QUEDA_BRANCA) / (1.0 - QUEDA_BRANCA)
	var lado := -1.0 if indice % 2 == 0 else 1.0
	var centro := casa.get_center() + Vector2(lado * 26.0 * p, -34.0 * p + 190.0 * p * p)
	var alfa := 1.0 - p * p
	draw_set_transform(centro.round(), lado * 1.1 * p, Vector2.ONE)
	var local := Rect2(-casa.size * 0.5, casa.size)
	EstiloHUD.ficha(self, local, alfa, EstiloHUD.PAPEL, EstiloHUD.TINTA, EstiloHUD.MOLDURA, 0.0)
	_escrever_elemento(local, elemento, EstiloHUD.com_alfa(EstiloHUD.TINTA, alfa))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Lascas: seis quadradinhos de papel, cada um para um lado.
	for i in 6:
		var s := float(i) + indice * 1.7
		var direcao := Vector2(cos(s * 2.4), -absf(sin(s * 1.3)) - 0.35)
		var lasca := casa.get_center() + direcao * (72.0 + 24.0 * fmod(s, 2.0)) * p \
			+ Vector2(0.0, 210.0 * p * p)
		var tam := 6.0 if i % 2 == 0 else 4.0
		draw_rect(Rect2((lasca - Vector2(tam, tam) * 0.5).round(), Vector2(tam, tam)),
			EstiloHUD.com_alfa(EstiloHUD.PAPEL if i % 3 != 0 else EstiloHUD.TINTA, alfa))


## O elemento na ficha, como na caixa do caderno: o número atômico no canto de
## cima e o símbolo grande no meio.
func _escrever_elemento(casa: Rect2, elemento: Array, tinta: Color) -> void:
	var f := _fonte()
	if f == null:
		return
	var simbolo := String(elemento[0])
	draw_string(f, casa.position + Vector2(9.0, 18.0), str(elemento[1]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_NUMERO, tinta)
	var largura := f.get_string_size(simbolo, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_SIMBOLO).x
	draw_string(f, Vector2(roundf(casa.get_center().x - largura * 0.5), casa.position.y + 55.0),
		simbolo, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_SIMBOLO, tinta)


## 0 -> 1 passando um pouco de 1 no caminho (a ficha que brota).
func _passar_e_voltar(t: float) -> float:
	var u := clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + 2.2 * u * u * u + 1.2 * u * u


# --- A nave -------------------------------------------------------------------

func _desenhar_nave(abalo: Vector2) -> void:
	var acento := _cor_acento()
	var pisca := _estado() == Estado.CRITICO and sin(_tempo * 7.5) > 0.0

	var arte := retrato if retrato != null else _nave()
	if arte != null:
		var caixa := CAIXA_NAVE
		caixa.position += abalo
		var cor := Color.WHITE
		if _clarao > 0.0 and int(_clarao * 4.0) % 2 == 1:
			cor = Color(1.0, 0.55, 0.5)
		if retrato != null:
			draw_texture_rect(arte, caixa, false, cor)
		else:
			draw_texture_rect_region(arte, caixa, QUADRO_NAVE, cor)

	var f := _fonte()
	if f != null:
		# O nome da nave, miúdo, embaixo do desenho dela.
		var nome := titulo.to_upper()
		var larg_nome := f.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_SUBTITULO).x
		EstiloHUD.rotulo(self, f, abalo + Vector2(
			roundf(CAIXA_NAVE.get_center().x - larg_nome * 0.5), 68.0), nome, TAM_SUBTITULO)
		# Em cima da barra: o que ela mede, e quanto resta.
		EstiloHUD.rotulo(self, f, abalo + Vector2(BARRA.position.x, 26.0), subtitulo.to_upper(),
			TAM_TITULO)
		var valor := _texto_valor()
		var cor_valor := EstiloHUD.CLARO if _estado() == Estado.OK else acento
		var largura := f.get_string_size(valor, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_TITULO).x
		EstiloHUD.rotulo(self, f, abalo + Vector2(BARRA.end.x - largura, 26.0), valor,
			TAM_TITULO, cor_valor)

	# A barra: trilho escuro, o casco que resta e o trecho recém-perdido.
	var barra := BARRA
	barra.position += abalo
	EstiloHUD.bloco(self, Rect2(barra.position + Vector2(0.0, EstiloHUD.QUEDA), barra.size),
		EstiloHUD.SOMBRA_DURA)
	EstiloHUD.bloco(self, barra, EstiloHUD.CONTORNO)
	var miolo := barra.grow(-EstiloHUD.MOLDURA)
	draw_rect(miolo, TRILHO)
	var x_cheio := roundf(miolo.size.x * clampf(_fracao_exibida, 0.0, 1.0))
	var x_fantasma := roundf(miolo.size.x * clampf(_fracao_fantasma, 0.0, 1.0))
	if x_fantasma > x_cheio:
		draw_rect(Rect2(miolo.position.x + x_cheio, miolo.position.y, x_fantasma - x_cheio,
			miolo.size.y), EstiloHUD.CLARO)
	if x_cheio > 0.0:
		var cheio := Rect2(miolo.position, Vector2(x_cheio, miolo.size.y))
		draw_rect(cheio, acento.lerp(Color.WHITE, 0.55) if pisca else acento)
		# A beirada de baixo, um tom abaixo: a mesma dobra das fichas.
		draw_rect(Rect2(cheio.position.x, cheio.end.y - 4.0, cheio.size.x, 4.0),
			acento.darkened(0.22))
	# Um risco a cada quarto, para dar escala à barra.
	for i in range(1, 4):
		var x := miolo.position.x + roundf(miolo.size.x * i / 4.0)
		draw_rect(Rect2(x - 1.0, miolo.position.y, 2.0, miolo.size.y),
			EstiloHUD.com_alfa(EstiloHUD.CONTORNO, 0.5))


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
		# Com poucas fichas a leitura é por unidade, não por porcentagem.
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


func _rosto() -> Texture2D:
	if _folha_rosto == null and ResourceLoader.exists(FOLHA_ROSTO):
		_folha_rosto = load(FOLHA_ROSTO) as Texture2D
	return _folha_rosto


func _nave() -> Texture2D:
	if _folha_nave == null and ResourceLoader.exists(FOLHA_NAVE):
		_folha_nave = load(FOLHA_NAVE) as Texture2D
	return _folha_nave
