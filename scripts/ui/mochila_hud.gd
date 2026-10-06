@tool
class_name MochilaHUD
extends Control

# --- A MOCHILA (fileira de casas, canto superior direito) ---
#
# O que a Cacau CARREGA para um puzzle: os cilindros, o carvão, as amostras.
# São três casas, e as vazias ficam à mostra — é assim que a pessoa sabe quanto
# cabe. Casa cheia é uma ficha (EstiloHUD.ficha: o papel do caderno com moldura
# de tinta, a mesma peça da vida e dos equipamentos) com o desenho do item;
# casa vazia é o furo escuro com o aro claro.
#
# Não há painel atrás, contagem nem nome embaixo de cada item. A etiqueta, em
# cima, diz MOCHILA; ela vira o NOME do item em dois momentos, e só neles:
#
#   * quando o item acaba de chegar (uns segundos, e volta sozinho);
#   * enquanto o ponteiro está em cima dele num puzzle de arrastar.
#
# O nome perde o parêntese: "Cilindro de Oxigênio (Comburente)" vira "CILINDRO
# DE OXIGÊNIO" (ver EstiloHUD.separar_nome).

const CAPACIDADE := 3
## Lado de cada casa e o vão entre duas.
const LADO := 64.0
const VAO := 8.0
## Caixa em que o desenho do item é encaixado dentro da casa.
const CAIXA_ICONE := 52.0
## Faixa do rótulo, em cima da fileira.
const ALTURA_ROTULO := 22.0

const ROTULO := "MOCHILA"
const TAM_ROTULO := 11

## Quanto tempo o rótulo mostra o nome do item que acabou de chegar (segundos).
const TEMPO_DESTAQUE := 2.6

const LARGURA_TOTAL := CAPACIDADE * LADO + (CAPACIDADE - 1) * VAO
const ALTURA_TOTAL := ALTURA_ROTULO + LADO + EstiloHUD.QUEDA

@export var fonte: Font:
	set(valor):
		fonte = valor
		queue_redraw()

@export_group("Prévia no editor")
## Deixa a peça se desenhar dentro do editor, para enquadrá-la sem rodar o jogo.
##
## Nasce DESLIGADA porque este nó mora no inventario_hud.tscn, que mora no
## player.tscn, que está instanciado em toda fase: com a prévia ligada, a
## mochila ficava plantada na origem do mapa em todo workspace 2D. Ligue aqui
## no Inspector enquanto estiver mexendo na peça, e desligue depois.
@export var previa_visivel: bool = false:
	set(valor):
		previa_visivel = valor
		queue_redraw()

## Com a prévia ligada, preenche algumas casas com itens do catálogo — sem isto
## a fileira aparece vazia e não dá para conferir o encaixe dos desenhos.
@export var previa_cheia: bool = true:
	set(valor):
		previa_cheia = valor
		queue_redraw()

var _slots: Array[Dictionary] = []

## Casa sob o ponteiro enquanto a mochila está servindo um puzzle de arrastar
## (-1 = nenhuma). Só muda o desenho: quem mede o ponteiro é o puzzle.
var foco: int = -1:
	set(valor):
		if foco != valor:
			foco = valor
			queue_redraw()


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
		# 0..1: o quanto a ficha da casa está "montada" (entra e sai por aqui).
		"surgir": 0.0,
		"alvo": 0.0,
		# 1 no instante da chegada, cai a zero: o branco e o aro que se abre.
		"clarao": 0.0,
		# 1 logo depois de guardar, cai devagar: o nome no rótulo.
		"destaque": 0.0,
		# O item saiu da mão (arrastado para um puzzle) mas ainda é da pessoa:
		# a casa esvazia na tela e continua reservada para ele voltar.
		"retirado": false,
	}


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

## Guarda o item na primeira casa livre. Devolve o índice usado, ou -1 se a
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
	slot["retirado"] = false
	slot["surgir"] = 0.0
	slot["alvo"] = 1.0
	slot["clarao"] = 1.0
	slot["destaque"] = 1.0
	_animar()
	return i


## Põe o item na casa JÁ montado, sem clarão, sem nome no rótulo e sem som —
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
	slot["retirado"] = false
	slot["surgir"] = 1.0
	slot["alvo"] = 1.0
	slot["clarao"] = 0.0
	slot["destaque"] = 0.0
	queue_redraw()
	return i


## Esvazia a casa do item (usado quando um receptor consome o item).
func remover(id: String) -> void:
	var i := indice_de(id)
	if i < 0:
		return
	_slots[i]["retirado"] = false
	_slots[i]["alvo"] = 0.0
	_slots[i]["destaque"] = 0.0
	_animar()


## Tira o item da mão SEM tirá-lo do inventário: o desenho sai da casa (a
## pessoa o está arrastando, ou já o entregou a um puzzle que ainda não
## terminou) e a casa fica reservada, com o aro na cor do item. Se o puzzle
## for abandonado, "devolver" põe tudo de volta no mesmo lugar; se ele
## terminar, "remover" libera a casa de vez.
func retirar(id: String) -> void:
	var i := indice_de(id)
	if i < 0:
		return
	_slots[i]["retirado"] = true
	_slots[i]["alvo"] = 0.0
	_slots[i]["destaque"] = 0.0
	_animar()


## Devolve à casa um item retirado, com o aro de chegada.
func devolver(id: String) -> void:
	var i := indice_de(id)
	if i < 0 or not _slots[i]["retirado"]:
		return
	_slots[i]["retirado"] = false
	_slots[i]["alvo"] = 1.0
	_slots[i]["clarao"] = 1.0
	_animar()


func esta_retirado(id: String) -> bool:
	var i := indice_de(id)
	return i >= 0 and _slots[i]["retirado"]


## Casa com item à mão sob o ponto (coordenadas de tela), ou -1.
func slot_no_ponto(ponto: Vector2) -> int:
	var local := get_global_transform().affine_inverse() * ponto
	for i in _slots.size():
		var slot := _slots[i]
		if not slot["cheio"] or slot["retirado"]:
			continue
		if _casa(i).has_point(local):
			return i
	return -1


## O que a casa guarda ({} se estiver vazia) — para quem vai desenhar o item
## fora da mochila enquanto ele é arrastado.
func dados_do_slot(indice: int) -> Dictionary:
	if indice < 0 or indice >= _slots.size() or not _slots[indice]["cheio"]:
		return {}
	var slot := _slots[indice]
	return {"id": slot["id"], "titulo": slot["titulo"], "textura": slot["textura"],
		"cor": slot["cor"]}


## A peça inteira (rótulo e fileira) em coordenadas de tela.
func retangulo_do_painel() -> Rect2:
	return get_global_transform() * Rect2(_origem(), Vector2(LARGURA_TOTAL, ALTURA_TOTAL))


## Pisca a casa e põe o nome do item no rótulo — para quando o jogo quiser
## lembrar a pessoa de que aquele item está com ela.
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


## Primeira casa livre, ou -1. Uma casa que está esvaziando ainda conta como
## ocupada — o item novo não entra por cima da animação do que está saindo.
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


## Centro da casa em coordenadas de tela — é o alvo do voo do ícone.
func centro_do_slot(indice: int) -> Vector2:
	return get_global_transform() * _centro_local(indice)


## Onde o próximo item vai parar. Cai na última casa se a mochila está cheia,
## para o voo ainda ter um destino.
func centro_do_proximo() -> Vector2:
	var i := proximo_livre()
	return centro_do_slot(i if i >= 0 else CAPACIDADE - 1)


## Tamanho aparente do ícone dentro da casa — o voo termina exatamente neste
## tamanho, então a chegada não "salta".
func caixa_do_icone() -> float:
	return CAIXA_ICONE


## O que o rótulo está dizendo agora: MOCHILA, ou o nome do item em destaque.
func texto_do_rotulo() -> String:
	var i := _slot_no_rotulo()
	return ROTULO if i < 0 else String(_slots[i]["titulo"]).to_upper()


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
			slot["clarao"] = maxf(slot["clarao"] - delta * 1.8, 0.0)
			ativo = true
		if slot["destaque"] > 0.0:
			slot["destaque"] = maxf(slot["destaque"] - delta / TEMPO_DESTAQUE, 0.0)
			ativo = true
		# Terminou de encolher: a casa volta a ser um furo vazio. O item
		# retirado não conta — ele ainda é da pessoa e pode voltar.
		if slot["cheio"] and slot["alvo"] <= 0.0 and slot["surgir"] <= 0.0 \
				and not slot["retirado"]:
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


func _casa(indice: int) -> Rect2:
	return Rect2(_origem() + Vector2(indice * (LADO + VAO), ALTURA_ROTULO), Vector2(LADO, LADO))


func _centro_local(indice: int) -> Vector2:
	return _casa(indice).get_center()


func _draw() -> void:
	# A trava mora no _draw, e não no _ready, porque o editor recarrega o script
	# sem re-executar o _ready: no _ready a peça continuaria desenhada por cima
	# da fase até alguém fechar e reabrir a cena.
	if Engine.is_editor_hint() and (not previa_visivel or _slots.is_empty()):
		return

	_desenhar_rotulo()
	for i in _slots.size():
		_desenhar_casa(i, _dados_para_desenho(i))


## No editor as casas ficam preenchidas com o catálogo, para a peça poder ser
## enquadrada sem rodar o jogo.
func _dados_para_desenho(indice: int) -> Dictionary:
	if not Engine.is_editor_hint() or not previa_cheia:
		return _slots[indice]
	const PREVIA := ["macarico", "bumerangue"]
	if indice >= PREVIA.size():
		return _slots[indice]
	var id: String = PREVIA[indice]
	var textura: Texture2D = CatalogoFerramentas.icone(id)
	return {
		"id": id, "titulo": id.capitalize(), "textura": textura,
		"cor": EstiloHUD.cor_do_item(id), "cheio": true,
		"surgir": 1.0, "alvo": 1.0, "clarao": 0.0, "destaque": 0.0, "retirado": false,
	}


## A casa de que o rótulo fala: a que está sob o ponteiro, ou a do item que
## acabou de chegar. -1 = o rótulo diz MOCHILA.
func _slot_no_rotulo() -> int:
	if foco >= 0 and foco < _slots.size() and _slots[foco]["cheio"] \
			and not _slots[foco]["retirado"]:
		return foco
	var escolhido := -1
	var maior := 0.0
	for i in _slots.size():
		if _slots[i]["cheio"] and _slots[i]["destaque"] > maior:
			maior = _slots[i]["destaque"]
			escolhido = i
	return escolhido


## MOCHILA (ou o nome do item em destaque), alinhado pela direita da fileira.
func _desenhar_rotulo() -> void:
	var f := _fonte()
	if f == null:
		return
	EstiloHUD.etiqueta(self, f, Vector2(_origem().x + LARGURA_TOTAL, 0.0), texto_do_rotulo(),
		TAM_ROTULO)


func _desenhar_casa(indice: int, slot: Dictionary) -> void:
	var casa := _casa(indice)
	var cor: Color = slot["cor"]
	var surgir: float = slot["surgir"]
	var clarao: float = slot["clarao"]
	var retirado: bool = slot.get("retirado", false)

	# O furo fica por baixo: é ele que aparece enquanto a ficha entra ou sai, e
	# é ele (com o aro na cor do item) que guarda o lugar do item retirado.
	if surgir < 1.0:
		if slot["cheio"] and retirado:
			EstiloHUD.casa_vazia(self, casa, 1.0, cor, 0.75)
		else:
			EstiloHUD.casa_vazia(self, casa)

	if slot["cheio"] and surgir > 0.0:
		# Sob o ponteiro num puzzle de arrastar a ficha se levanta: é o "isto
		# aqui dá para pegar".
		var em_foco: bool = indice == foco and not retirado
		var erguida := 4.0 if em_foco else 0.0
		var centro := casa.get_center() - Vector2(0.0, erguida)
		var escala := _passar_e_voltar(surgir)
		var alfa := minf(surgir * 3.0, 1.0)
		draw_set_transform(centro, 0.0, Vector2(escala, escala))
		EstiloHUD.ficha(self, Rect2(-casa.size * 0.5, casa.size), alfa,
			EstiloHUD.PAPEL.lerp(Color.WHITE, clarao * clarao), EstiloHUD.TINTA,
			EstiloHUD.MOLDURA, EstiloHUD.QUEDA + erguida)
		EstiloHUD.icone(self, slot["textura"], Vector2.ZERO, CAIXA_ICONE,
			EstiloHUD.com_alfa(Color.WHITE, alfa))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if em_foco:
			EstiloHUD.aro(self, Rect2(centro - casa.size * 0.5, casa.size).grow(4.0),
				EstiloHUD.CLARO, 2.0)

	# O aro de chegada: abre para fora, na cor do item, e apaga.
	if clarao > 0.0:
		EstiloHUD.aro(self, casa.grow(roundf((1.0 - clarao) * 16.0)),
			EstiloHUD.com_alfa(cor, clarao), EstiloHUD.MOLDURA)


## 0 -> 1 passando um pouco de 1 no caminho.
func _passar_e_voltar(t: float) -> float:
	var u := clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + 2.2 * u * u * u + 1.2 * u * u


func _fonte() -> Font:
	if fonte != null:
		return fonte
	return get_theme_default_font()
