@tool
class_name MochilaHUD
extends Control

# --- A MOCHILA (fileira de slots, canto superior direito) ---
#
# O outro lado da ficha de coleta. O popup apresenta o item em um MEDALHÃO
# hexagonal; a mochila é a mesma forma, menor, repetida — então o ícone que
# voa do centro da tela até aqui parece uma peça se encaixando no lugar dela,
# e não um desenho teletransportado para uma caixinha cinza.
#
# Tudo desenhado (_draw) com o EstiloHUD, igual ao hud_vital e ao popup: mesma
# paleta de vidro escuro, mesmo contorno frio, mesmo rótulo em caixa alta com
# espaçamento largo. Trocar uma cor no EstiloHUD troca as três peças juntas.
#
# Decisões de design que valem registro:
#
#   * SLOT VAZIO APARECE. Antes o slot só existia depois de ganhar conteúdo
#     (modulate.a = 0), então ninguém sabia quantos cabiam. Alvéolo vazio e
#     apagado mostra a capacidade sem competir com o jogo.
#   * O NOME FICA, MAS RECUADO. Ele acende por uns segundos quando o item
#     chega e depois volta a um cinza fraco: legível quando a pessoa procura,
#     invisível quando ela está jogando.
#   * O NOME PERDE O PARÊNTESE. "Cilindro de Oxigênio (Comburente)" vira
#     "Cilindro de Oxigênio" — a categoria já foi dita na ficha, aqui ela só
#     roubaria a linha (ver EstiloHUD.separar_nome).

const CAPACIDADE := 3
const RAIO_CELULA := 42.0
const SEPARACAO := 16.0
## Caixa em que o desenho do item é encaixado dentro do alvéolo.
const CAIXA_ICONE := 48.0
const ALTURA_CABECALHO := 24.0
const ALTURA_ROTULO := 30.0

## Respiro entre o painel e o que ele guarda.
const PADDING := Vector2(16.0, 10.0)
## Um pouco maior que o respiro de cima: é aqui que caem os nomes de duas
## linhas, e eles não podem encostar no chanfro de baixo do painel.
const PADDING_BASE := 15.0
## Chanfro dos cantos — o mesmo desenho da ficha, na escala desta peça.
const CORTE := 16.0

const TAM_CABECALHO := 11
const ESPACO_CABECALHO := 3.2
const TAM_ROTULO := 10
const ESPACO_ROTULO := 0.4
## Duas linhas bastam para qualquer nome do jogo; a terceira seria ruído.
const LINHAS_ROTULO := 2

## Quanto tempo o nome do item fica aceso depois de chegar (segundos).
const TEMPO_DESTAQUE := 3.2

const ALTURA_CELULA := RAIO_CELULA * 1.7320508
const LARGURA_FILEIRA := CAPACIDADE * RAIO_CELULA * 2.0 + (CAPACIDADE - 1) * SEPARACAO
const LARGURA_TOTAL := LARGURA_FILEIRA + PADDING.x * 2.0
const ALTURA_TOTAL := PADDING.y + ALTURA_CABECALHO + ALTURA_CELULA + ALTURA_ROTULO \
	+ PADDING_BASE

@export var fonte: Font:
	set(valor):
		fonte = valor
		queue_redraw()

@export_group("Prévia no editor")
## Deixa a peça se desenhar dentro do editor, para enquadrá-la sem rodar o jogo.
##
## Nasce DESLIGADA porque este nó mora no inventario_hud.tscn, que mora no
## player.tscn, que está instanciado em toda fase: com a prévia ligada, o painel
## da mochila ficava plantado na origem do mapa em todo workspace 2D. Ligue aqui
## no Inspector enquanto estiver mexendo na peça, e desligue depois.
@export var previa_visivel: bool = false:
	set(valor):
		previa_visivel = valor
		queue_redraw()

## Com a prévia ligada, preenche alguns alvéolos com itens do catálogo — sem
## isto a fileira aparece vazia e não dá para conferir o alinhamento do rótulo.
@export var previa_cheia: bool = true:
	set(valor):
		previa_cheia = valor
		queue_redraw()

var _slots: Array[Dictionary] = []


func _ready() -> void:
	custom_minimum_size = Vector2(LARGURA_TOTAL, ALTURA_TOTAL)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in CAPACIDADE:
		_slots.append(_slot_vazio())
	set_process(false)
	queue_redraw()


func _slot_vazio() -> Dictionary:
	return {
		"id": "",
		"titulo": "",
		"textura": null,
		"cor": EstiloHUD.ACENTO_PADRAO,
		"cheio": false,
		# 0..1: o quanto o conteúdo do slot está "montado" (entra e sai por aqui).
		"surgir": 0.0,
		"alvo": 0.0,
		# 1 no instante da chegada, cai a zero: é o anel que se abre.
		"clarao": 0.0,
		# 1 logo depois de guardar, cai devagar: acende o nome.
		"destaque": 0.0,
	}


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

## Guarda o item no primeiro alvéolo livre. Devolve o índice usado, ou -1 se a
## mochila estiver cheia (aí quem chamou decide o que dizer à pessoa).
func guardar(id: String, nome: String, textura: Texture2D, cor: Color = Color(0, 0, 0, 0)) -> int:
	if id.is_empty():
		return -1
	var existente := indice_de(id)
	if existente >= 0:
		destacar(id)
		return existente

	var i := proximo_livre()
	if i < 0:
		return -1

	var slot := _slots[i]
	slot["id"] = id
	slot["titulo"] = String(EstiloHUD.separar_nome(nome)["titulo"])
	slot["textura"] = textura
	slot["cor"] = cor if cor.a > 0.0 else EstiloHUD.cor_do_item(id)
	slot["cheio"] = true
	slot["surgir"] = 0.0
	slot["alvo"] = 1.0
	slot["clarao"] = 1.0
	slot["destaque"] = 1.0
	_animar()
	return i


## Põe o item no alvéolo JÁ montado, sem clarão, sem nome aceso e sem som —
## para a mochila que nasce numa cena nova e repõe o que a pessoa já carregava
## (não é uma coleta, então não pode parecer uma).
func restaurar(id: String, nome: String, textura: Texture2D, cor: Color = Color(0, 0, 0, 0)) -> int:
	if id.is_empty() or tem(id):
		return indice_de(id)
	var i := proximo_livre()
	if i < 0:
		return -1
	var slot := _slots[i]
	slot["id"] = id
	slot["titulo"] = String(EstiloHUD.separar_nome(nome)["titulo"])
	slot["textura"] = textura
	slot["cor"] = cor if cor.a > 0.0 else EstiloHUD.cor_do_item(id)
	slot["cheio"] = true
	slot["surgir"] = 1.0
	slot["alvo"] = 1.0
	slot["clarao"] = 0.0
	slot["destaque"] = 0.0
	queue_redraw()
	return i


## Esvazia o alvéolo do item (usado quando um receptor consome o item).
func remover(id: String) -> void:
	var i := indice_de(id)
	if i < 0:
		return
	_slots[i]["alvo"] = 0.0
	_slots[i]["destaque"] = 0.0
	_animar()


## Pisca o alvéolo e reacende o nome — para quando o jogo quiser lembrar a
## pessoa de que aquele item está com ela.
func destacar(id: String) -> void:
	var i := indice_de(id)
	if i < 0:
		return
	_slots[i]["clarao"] = 1.0
	_slots[i]["destaque"] = 1.0
	_animar()


func indice_de(id: String) -> int:
	for i in _slots.size():
		if _slots[i]["cheio"] and _slots[i]["id"] == id:
			return i
	return -1


func tem(id: String) -> bool:
	return indice_de(id) >= 0


## Primeiro alvéolo livre, ou -1. Um slot que está esvaziando ainda conta como
## ocupado — o item novo não entra por cima da animação do que está saindo.
func proximo_livre() -> int:
	for i in _slots.size():
		if not _slots[i]["cheio"]:
			return i
	return -1


func esta_cheia() -> bool:
	return proximo_livre() < 0


func ocupados() -> int:
	var n := 0
	for slot in _slots:
		if slot["cheio"]:
			n += 1
	return n


## Centro do alvéolo em coordenadas de tela — é o alvo do voo do ícone.
func centro_do_slot(indice: int) -> Vector2:
	return get_global_transform() * _centro_local(indice)


## Onde o próximo item vai parar. Cai no último alvéolo se a mochila está
## cheia, para o voo ainda ter um destino coerente com o aviso do rodapé.
func centro_do_proximo() -> Vector2:
	var i := proximo_livre()
	return centro_do_slot(i if i >= 0 else CAPACIDADE - 1)


## Tamanho aparente do ícone dentro do alvéolo — o voo termina exatamente
## neste tamanho, então a chegada não "salta".
func caixa_do_icone() -> float:
	return CAIXA_ICONE


# ─────────────────────────────────────────────────────────────
# Animação
# ─────────────────────────────────────────────────────────────

func _animar() -> void:
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var ativo := false
	for slot in _slots:
		if not is_equal_approx(slot["surgir"], slot["alvo"]):
			slot["surgir"] = move_toward(slot["surgir"], slot["alvo"], delta / 0.26)
			ativo = true
		if slot["clarao"] > 0.0:
			slot["clarao"] = maxf(slot["clarao"] - delta * 1.7, 0.0)
			ativo = true
		if slot["destaque"] > 0.0:
			slot["destaque"] = maxf(slot["destaque"] - delta / TEMPO_DESTAQUE, 0.0)
			ativo = true
		# Terminou de encolher: o alvéolo volta a ser um furo vazio.
		if slot["cheio"] and slot["alvo"] <= 0.0 and slot["surgir"] <= 0.0:
			slot["cheio"] = false
			slot["id"] = ""
			slot["titulo"] = ""
			slot["textura"] = null

	queue_redraw()
	if not ativo:
		set_process(false)


# ─────────────────────────────────────────────────────────────
# Desenho
# ─────────────────────────────────────────────────────────────

## A fileira é encostada na direita da própria caixa: assim a peça fica colada
## na margem da tela mesmo que alguém dê a ela um retângulo mais largo no
## editor.
func _origem() -> Vector2:
	return Vector2(maxf(size.x - LARGURA_TOTAL, 0.0), 0.0)


func _centro_local(indice: int) -> Vector2:
	var o := _origem()
	return o + Vector2(
		PADDING.x + indice * (RAIO_CELULA * 2.0 + SEPARACAO) + RAIO_CELULA,
		PADDING.y + ALTURA_CABECALHO + ALTURA_CELULA * 0.5)


func _draw() -> void:
	# A trava mora no _draw, e não no _ready, porque o editor recarrega o script
	# sem re-executar o _ready: no _ready a peça continuaria desenhada por cima
	# da fase até alguém fechar e reabrir a cena.
	if Engine.is_editor_hint() and (not previa_visivel or _slots.is_empty()):
		return

	_desenhar_painel()
	_desenhar_cabecalho()
	for i in _slots.size():
		_desenhar_slot(i, _dados_para_desenho(i))


## O painel de vidro atrás da fileira — é ele que faz a mochila e a ficha de
## coleta parecerem a mesma peça de equipamento, e é ele que garante que o
## rótulo do item continue legível por cima de qualquer cenário (sem painel, o
## texto branco sumia num fundo claro e o alvéolo virava um borrão escuro).
func _desenhar_painel() -> void:
	var quadro := Rect2(_origem(), Vector2(LARGURA_TOTAL, ALTURA_TOTAL))
	var corpo := EstiloHUD.chanfro(quadro, CORTE)
	EstiloHUD.sombra(self, corpo, 5.0)
	# Um pouco mais transparente que a ficha: esta peça fica na tela o tempo
	# todo e não pode virar um tampão no canto.
	EstiloHUD.vidro(self, corpo, 0.90)
	EstiloHUD.moldura(self, corpo, EstiloHUD.BORDA, 1.5)
	draw_line(corpo[0], corpo[1], EstiloHUD.FIO_LUZ, 1.5, true)


## No editor os slots ficam preenchidos com o catálogo, para a peça poder ser
## enquadrada sem rodar o jogo.
func _dados_para_desenho(indice: int) -> Dictionary:
	if not Engine.is_editor_hint() or not previa_cheia:
		return _slots[indice]
	const PREVIA := ["Cilindro_de_Hidrogenio", "Cilindro_Oxigenio", "bumerangue"]
	if indice >= PREVIA.size():
		return _slots[indice]
	var id: String = PREVIA[indice]
	var textura: Texture2D = CatalogoFerramentas.icone(id)
	return {
		"id": id, "titulo": id.capitalize(), "textura": textura,
		"cor": EstiloHUD.cor_do_item(id), "cheio": true,
		"surgir": 1.0, "alvo": 1.0, "clarao": 0.0, "destaque": 0.0,
	}


func _desenhar_cabecalho() -> void:
	var f := _fonte()
	if f == null:
		return
	var o := _origem() + Vector2(PADDING.x, PADDING.y)
	var base := o.y + ALTURA_CABECALHO - 12.0

	EstiloHUD.texto(self, f, Vector2(o.x, base), "MOCHILA", TAM_CABECALHO,
		EstiloHUD.TEXTO_FRACO, ESPACO_CABECALHO)

	# Contagem colada na direita: é o canto da tela, o olho já vai lá.
	var cheios := ocupados()
	if Engine.is_editor_hint() and previa_cheia:
		cheios = CAPACIDADE
	var total := "/%d" % CAPACIDADE
	var largura_total := EstiloHUD.largura_texto(f, total, TAM_CABECALHO, ESPACO_CABECALHO)
	var texto_cheios := str(cheios)
	var largura_cheios := EstiloHUD.largura_texto(f, texto_cheios, TAM_CABECALHO, ESPACO_CABECALHO)
	var x := o.x + LARGURA_FILEIRA - largura_total - largura_cheios
	EstiloHUD.texto(self, f, Vector2(x, base), texto_cheios, TAM_CABECALHO,
		EstiloHUD.TEXTO if cheios > 0 else EstiloHUD.TEXTO_FRACO, ESPACO_CABECALHO)
	EstiloHUD.texto(self, f, Vector2(x + largura_cheios, base), total, TAM_CABECALHO,
		EstiloHUD.TEXTO_FRACO, ESPACO_CABECALHO)

	# Fio separando o rótulo da fileira.
	var y := o.y + ALTURA_CABECALHO - 6.0
	draw_line(Vector2(o.x, y), Vector2(o.x + LARGURA_FILEIRA, y),
		EstiloHUD.com_alfa(EstiloHUD.BORDA, 0.85), 1.0)


func _desenhar_slot(indice: int, slot: Dictionary) -> void:
	var centro := _centro_local(indice)
	var hexa := EstiloHUD.hexagono(centro, RAIO_CELULA)
	var cheio: bool = slot["cheio"]
	var surgir: float = slot["surgir"]
	var cor: Color = slot["cor"]

	EstiloHUD.sombra(self, hexa, 3.0, 0.9)
	EstiloHUD.vidro(self, hexa, 1.0, EstiloHUD.ALVEOLO, Color(0.018, 0.024, 0.046, 0.94))

	if cheio:
		# Banho da cor do item + halo: o alvéolo ocupado tem temperatura.
		draw_colored_polygon(hexa, EstiloHUD.com_alfa(cor, 0.10 * surgir))
		EstiloHUD.halo(self, centro, RAIO_CELULA * 1.15, cor, 6, surgir * 0.8)
		EstiloHUD.moldura(self, hexa, EstiloHUD.com_alfa(cor, 0.30 + 0.55 * surgir), 2.0)
		EstiloHUD.icone(self, slot["textura"], centro, CAIXA_ICONE,
			EstiloHUD.com_alfa(Color.WHITE, surgir), lerpf(0.6, 1.0, surgir))
	else:
		EstiloHUD.moldura(self, hexa, EstiloHUD.com_alfa(EstiloHUD.BORDA, 0.75), 1.0)
		# Marca miúda no meio: o furo vazio precisa parecer um encaixe à espera,
		# não um buraco esquecido.
		EstiloHUD.moldura(self, EstiloHUD.hexagono(centro, RAIO_CELULA * 0.30),
			EstiloHUD.com_alfa(EstiloHUD.BORDA, 0.45), 1.0)

	# Fio de luz na aresta de cima do hexágono — o mesmo do topo dos painéis.
	draw_line(hexa[4], hexa[5], EstiloHUD.com_alfa(EstiloHUD.FIO_LUZ,
		0.5 + 0.5 * surgir), 1.0, true)

	# Anel de chegada: abre para fora e apaga.
	var clarao: float = slot["clarao"]
	if clarao > 0.0:
		var f := clarao * clarao
		draw_colored_polygon(hexa, EstiloHUD.com_alfa(Color.WHITE, f * 0.20))
		EstiloHUD.moldura(self, EstiloHUD.hexagono(centro, RAIO_CELULA + (1.0 - f) * 20.0),
			EstiloHUD.com_alfa(cor, f * 0.85), 2.5)

	_desenhar_rotulo(indice, slot, centro)


func _desenhar_rotulo(_indice: int, slot: Dictionary, centro: Vector2) -> void:
	var f := _fonte()
	if f == null or not slot["cheio"]:
		return
	var titulo: String = slot["titulo"]
	if titulo.is_empty():
		return

	# A linha quebra dentro da largura do alvéolo: com mais folga que isso, os
	# nomes de dois slots vizinhos encostam um no outro.
	var largura := RAIO_CELULA * 2.0 - 4.0
	var linhas := EstiloHUD.quebrar(f, titulo, TAM_ROTULO, largura)
	var alfa: float = slot["surgir"] * (0.42 + 0.58 * slot["destaque"])
	var y := centro.y + ALTURA_CELULA * 0.5 + 14.0

	for i in mini(linhas.size(), LINHAS_ROTULO):
		var linha: String = linhas[i]
		# Estourou as duas linhas: a última ganha reticências em vez de cortar
		# a palavra no meio.
		if i == LINHAS_ROTULO - 1 and linhas.size() > LINHAS_ROTULO:
			linha += "…"
		var largura_linha := EstiloHUD.largura_texto(f, linha, TAM_ROTULO, ESPACO_ROTULO)
		EstiloHUD.texto(self, f, Vector2(centro.x - largura_linha * 0.5, y + i * 13.0),
			linha, TAM_ROTULO, EstiloHUD.com_alfa(EstiloHUD.TEXTO, alfa), ESPACO_ROTULO)


func _fonte() -> Font:
	if fonte != null:
		return fonte
	return get_theme_default_font()
