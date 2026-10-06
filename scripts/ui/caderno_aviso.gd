class_name CadernoAviso
extends Control

# --- O AVISO DE NOTA ADICIONADA (em cima do ícone do caderno) ---
#
# Quando a folha que a Cacau pegou chega no ícone do caderno, este aviso sobe
# logo acima dele: a arte da folha, "NOTA ADICIONADA AO CADERNO", o título da
# nota e as páginas em que ela foi parar. É uma ficha de papel (EstiloHUD.ficha),
# a mesma peça da vida, da mochila e da ficha de coleta.
#
#   ENTRANDO   desliza da esquerda aparecendo
#   NA TELA    segura alguns segundos para ser lido
#   SAINDO     some deslizando de volta
#
# Regras de ritmo, as mesmas da lista de objetivos:
#   - nada anda com o ícone do caderno escondido (fala, ficha de item, puzzle,
#     pausa): o aviso espera a tela fechar para acontecer na frente da pessoa;
#   - duas notas seguidas saem uma depois da outra;
#   - abrir o caderno dispensa o aviso: a pessoa já foi ler.
#
# Quem manda mostrar é o autoload Caderno (Caderno.guardar_nota), que também
# diz, a cada quadro, quanto do ícone está na tela (alfa_do_hud).

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")
const ARTE := preload("res://assets/itens/notas diario.png")

const CHAPEU := "NOTA ADICIONADA AO CADERNO"
## A cor do papel do caderno: o rastro da folha que voa até o ícone.
const ACENTO := Color(0.96, 0.84, 0.60)

# --- Medidas ---
const ALTURA := 68.0
const MARGEM := 14.0
const CORTE := 12.0
## A arte da folha vai ampliada assim (pixel inteiro).
const ESCALA_ARTE := 2.0
const RESPIRO_ARTE := 14.0
## Do topo do ícone até o pé do aviso.
const ACIMA_DO_ICONE := 14.0

# --- Tipografia ---
const TAM_CHAPEU := 13
const ESPACO_CHAPEU := 1.6
const TAM_TITULO := 22
const TAM_PAGINAS := 13
## Linhas de base do chapéu e do título, contadas do topo do aviso.
const BASE_CHAPEU := 26.0
const BASE_TITULO := 52.0
## Do fim do título até as páginas, na mesma linha.
const RESPIRO_PAGINAS := 12.0

# --- Tempos (segundos) ---
const T_ENTRAR := 0.38
const T_SEGURAR := 3.6
const T_SAIR := 0.3
const DESLIZE_ENTRADA := 28.0
const DESLIZE_SAIDA := 18.0

enum Estado { PARADO, ENTRANDO, NA_TELA, SAINDO }

## O ícone do caderno: o aviso fica em cima dele.
var icone: Control = null
## Quanto do ícone está na tela (0 a 1). O aviso aparece e some junto com ele,
## e só anda com ele inteiro na tela.
var alfa_do_hud: float = 0.0

## Os avisos que ainda vão aparecer: [{"titulo", "paginas"}].
var _fila: Array[Dictionary] = []
var _atual: Dictionary = {}
var _estado: int = Estado.PARADO
## Tempo no estado atual.
var _t: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


# ─────────────────────────────────────────────────────────────
# O que o autoload Caderno pede
# ─────────────────────────────────────────────────────────────

## Uma nota entrou no caderno: o título dela e os números da primeira e da
## última face que ela traz.
func mostrar(titulo: String, paginas: Vector2i) -> void:
	_fila.append({"titulo": titulo, "paginas": paginas})


## Tira o aviso da tela (e os que estavam na fila): o caderno foi aberto.
func dispensar() -> void:
	_fila.clear()
	if _estado == Estado.ENTRANDO or _estado == Estado.NA_TELA:
		_mudar(Estado.SAINDO)


## Tem aviso na tela ou esperando para aparecer?
func ocupado() -> bool:
	return _estado != Estado.PARADO or not _fila.is_empty()


## O aviso está na tela, parado, para ser lido?
func na_tela() -> bool:
	return _estado == Estado.NA_TELA


## O título do aviso que está na tela ("" = nenhum).
func titulo_atual() -> String:
	return String(_atual.get("titulo", ""))


## O que o aviso diz das páginas: "páginas 4 e 5" para uma página dupla só,
## "páginas 4 a 7" para mais de uma.
func texto_das_paginas() -> String:
	if _atual.is_empty():
		return ""
	var paginas: Vector2i = _atual["paginas"]
	return "páginas %d %s %d" % [paginas.x, "a" if paginas.y - paginas.x > 1 else "e", paginas.y]


# ─────────────────────────────────────────────────────────────
# Tempo
# ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	var a_vista := alfa_do_hud >= 1.0
	match _estado:
		Estado.PARADO:
			if not _fila.is_empty() and a_vista:
				_atual = _fila.pop_front()
				_mudar(Estado.ENTRANDO)
		Estado.ENTRANDO:
			if a_vista:
				_t += delta
			if _t >= T_ENTRAR:
				_mudar(Estado.NA_TELA)
		Estado.NA_TELA:
			if a_vista:
				_t += delta
			if _t >= T_SEGURAR:
				_mudar(Estado.SAINDO)
		Estado.SAINDO:
			_t += delta
			if _t >= T_SAIR:
				_atual = {}
				_mudar(Estado.PARADO)
	visible = _estado != Estado.PARADO
	if visible:
		queue_redraw()


func _mudar(estado: int) -> void:
	_estado = estado
	_t = 0.0


# ─────────────────────────────────────────────────────────────
# Desenho
# ─────────────────────────────────────────────────────────────

## Onde o aviso fica quando está parado: em cima do ícone, alinhado à esquerda
## com ele.
func caixa() -> Rect2:
	var pe := icone.get_global_rect().position if icone != null else Vector2(28.0, size.y - 78.0)
	return Rect2(Vector2(pe.x, pe.y - ACIMA_DO_ICONE - ALTURA).round(), Vector2(_largura(), ALTURA))


func _largura() -> float:
	var chapeu := EstiloHUD.largura_texto(FONTE, CHAPEU, TAM_CHAPEU, ESPACO_CHAPEU)
	var linha := _largura_de(titulo_atual(), TAM_TITULO) + RESPIRO_PAGINAS \
		+ _largura_de(texto_das_paginas(), TAM_PAGINAS)
	return ceilf(MARGEM + ARTE.get_width() * ESCALA_ARTE + RESPIRO_ARTE + maxf(chapeu, linha)
		+ MARGEM + CORTE * 0.5)


func _draw() -> void:
	if _estado == Estado.PARADO or _atual.is_empty():
		return
	var alfa := alfa_do_hud
	var deslize := 0.0
	match _estado:
		Estado.ENTRANDO:
			var p := clampf(_t / T_ENTRAR, 0.0, 1.0)
			alfa *= _suave(p)
			deslize = -DESLIZE_ENTRADA * pow(1.0 - p, 3.0)
		Estado.SAINDO:
			var p := clampf(_t / T_SAIR, 0.0, 1.0)
			alfa *= 1.0 - _suave(p)
			deslize = -DESLIZE_SAIDA * p * p
	if alfa <= 0.0:
		return

	var parada := caixa()
	var area := Rect2(parada.position + Vector2(roundf(deslize), 0.0), parada.size)
	EstiloHUD.ficha(self, area, alfa)

	var tamanho_arte := Vector2(ARTE.get_size()) * ESCALA_ARTE
	var canto_arte := Vector2(area.position.x + MARGEM,
		area.position.y + (ALTURA - tamanho_arte.y) * 0.5).round()
	draw_texture_rect(ARTE, Rect2(canto_arte, tamanho_arte), false, Color(1, 1, 1, alfa))

	var x := canto_arte.x + tamanho_arte.x + RESPIRO_ARTE
	EstiloHUD.texto(self, FONTE, Vector2(x, area.position.y + BASE_CHAPEU), CHAPEU, TAM_CHAPEU,
		EstiloHUD.com_alfa(EstiloHUD.TINTA_FRACA, alfa), ESPACO_CHAPEU)
	var base := Vector2(x, area.position.y + BASE_TITULO)
	var titulo := titulo_atual()
	draw_string(FONTE, base, titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_TITULO,
		EstiloHUD.com_alfa(EstiloHUD.TINTA, alfa))
	draw_string(FONTE, base + Vector2(_largura_de(titulo, TAM_TITULO) + RESPIRO_PAGINAS, 0.0),
		texto_das_paginas(), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_PAGINAS,
		EstiloHUD.com_alfa(EstiloHUD.TINTA_FRACA, alfa))


func _largura_de(texto: String, tamanho: int) -> float:
	return FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x


func _suave(p: float) -> float:
	return 1.0 - pow(1.0 - p, 3.0)
