@tool
class_name EquipamentosHUD
extends Control

# --- OS EQUIPAMENTOS (canto inferior direito) ---
#
# O que a Cacau SABE FAZER, para sempre: o maçarico, o bumerangue e o que vier.
# Cada equipamento é uma ficha (EstiloHUD.ficha: o papel do caderno com moldura
# de tinta, a mesma peça da vida e da mochila) com o desenho dele dentro e,
# embaixo, a TECLA que o aciona — a tecla desenhada da folha do teclado,
# afundando em loop, ou o botão do controle.
#
# Não há painel atrás nem casa vazia: o equipamento que ela ainda não tem não
# se anuncia. Em cima das fichas vai só a etiqueta EQUIPAMENTOS.
#
# A DIFERENÇA PARA A MOCHILA (canto de cima) é de propósito:
#
#   MOCHILA      -> o que ela CARREGA para um puzzle. Três casas, as vazias à
#                   mostra, e o item some quando é usado.
#   EQUIPAMENTOS -> o que fica com ela. Só as fichas que existem, cada uma com
#                   a sua tecla.
#
# A ficha nova sempre nasce encostada no canto; as antigas escorregam para a
# esquerda para dar lugar. Quando um equipamento é usado no mundo (o maçarico
# cortando a chapa), a ficha dele dá um pulinho.

## Distância das fichas até o canto da tela.
const MARGEM := Vector2(26.0, 22.0)

## Lado de cada ficha e o vão entre duas.
const LADO := 64.0
const VAO := 8.0
## Caixa em que o desenho do equipamento é encaixado dentro da ficha.
const CAIXA_ICONE := 52.0

## Faixa do rótulo, em cima das fichas.
const ALTURA_ROTULO := 22.0
## Faixa das teclas, embaixo. Cabe a tecla desenhada (32 px) inteira.
const ALTURA_TECLA := 38.0
const ALTURA_TOTAL := ALTURA_ROTULO + LADO + ALTURA_TECLA

const ROTULO := "EQUIPAMENTOS"
const TAM_ROTULO := 11
const TAM_TECLA := 13

## Quanto a ficha leva para brotar, e a velocidade com que as antigas
## escorregam para o lado (pixels por segundo).
const T_SURGIR := 0.3
const VELOCIDADE := 420.0

@export var fonte: Font:
	set(valor):
		fonte = valor
		queue_redraw()

@export_group("Prévia no editor")
## Desenha a peça com os equipamentos que já têm arte, para dar para
## enquadrá-la sem rodar o jogo e conquistar nada.
@export var previa: bool = true:
	set(valor):
		previa = valor
		queue_redraw()

var _equipamentos: Array[Dictionary] = []
## Quadro da animação das teclas no último desenho: elas afundam em loop, e a
## peça só se redesenha quando o quadro vira (5 vezes por segundo).
var _quadro_das_teclas: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	_reposicionar()

	if Engine.is_editor_hint():
		set_process(false)
		queue_redraw()
		return

	visible = false
	set_process(false)


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

## Põe o equipamento na fileira. "anunciar" false monta a ficha já pronta, sem
## estouro — é o caminho de quem carrega um jogo salvo, ou troca de cena com a
## habilidade já na mão.
func equipar(ficha: Dictionary, anunciar: bool = true) -> void:
	var id := String(ficha.get("id", ""))
	if id.is_empty() or indice_de(id) >= 0:
		return

	_equipamentos.append({
		"id": id,
		"rotulo": String(ficha.get("rotulo", "")),
		"tecla": String(ficha.get("tecla", "")),
		"acao": String(ficha.get("acao", "")),
		"textura": ficha.get("textura", null),
		"cor": ficha.get("cor", EstiloHUD.ACENTO_PADRAO),
		"surgir": 0.0 if anunciar else 1.0,
		"clarao": 1.0 if anunciar else 0.0,
		"pulso": 0.0,
		# Distância do centro da ficha até a borda direita da peça.
		"recuo": LADO * 0.5,
	})
	visible = true
	_reposicionar()

	if not anunciar:
		# Sem anúncio todas já nascem no lugar (nada de escorregar quando a
		# fase só está recompondo o que ela já tinha).
		for i in _equipamentos.size():
			_equipamentos[i]["recuo"] = _recuo_alvo(i, _equipamentos.size())
	_animar()


## Pulsa o equipamento que acabou de ser usado no mundo (corte de chapa,
## acender a retorta). Silencioso se ela ainda não o tiver.
func destacar(id: String) -> void:
	var i := indice_de(id)
	if i < 0:
		return
	_equipamentos[i]["pulso"] = 1.0
	_animar()


func indice_de(id: String) -> int:
	for i in _equipamentos.size():
		if _equipamentos[i]["id"] == id:
			return i
	return -1


func tem(id: String) -> bool:
	return indice_de(id) >= 0


func quantidade() -> int:
	return _equipamentos.size()


## Onde a PRÓXIMA ficha vai nascer, em coordenadas de tela.
##
## A peça é ancorada pela direita e a ficha nova nasce sempre encostada no
## canto, então este ponto NÃO depende de quantos equipamentos já existem — o
## que permite a ficha de coleta mirar o voo do ícone aqui antes mesmo de a
## ficha existir.
func ponto_de_entrada() -> Vector2:
	var tela := get_viewport_rect().size
	return Vector2(
		tela.x - MARGEM.x - LADO * 0.5,
		tela.y - MARGEM.y - ALTURA_TECLA - LADO * 0.5)


## Tamanho em que o desenho do equipamento aparece dentro da ficha: o voo do
## ícone termina exatamente neste tamanho.
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
	var total := _equipamentos.size()

	for i in total:
		var e := _equipamentos[i]
		var alvo := _recuo_alvo(i, total)
		if not is_equal_approx(e["recuo"], alvo):
			e["recuo"] = move_toward(e["recuo"], alvo, delta * VELOCIDADE)
			ativo = true
		if e["surgir"] < 1.0:
			e["surgir"] = minf(e["surgir"] + delta / T_SURGIR, 1.0)
			ativo = true
		if e["clarao"] > 0.0:
			e["clarao"] = maxf(e["clarao"] - delta * 1.8, 0.0)
			ativo = true
		if e["pulso"] > 0.0:
			e["pulso"] = maxf(e["pulso"] - delta * 3.0, 0.0)
			ativo = true

	# Parada, a peça só precisa de um desenho novo quando as teclas embaixo dos
	# equipamentos mudam de quadro. Sem equipamento nenhum, ela dorme.
	var quadro := BotoesControle.quadro_atual()
	if ativo or quadro != _quadro_das_teclas:
		_quadro_das_teclas = quadro
		queue_redraw()
	if not ativo and _equipamentos.is_empty():
		set_process(false)


## A ficha mais nova fica encostada na direita; cada uma antes dela, um passo
## para a esquerda.
func _recuo_alvo(indice: int, total: int) -> float:
	return (total - 1 - indice) * (LADO + VAO) + LADO * 0.5


func _largura() -> float:
	var n := _lista_para_desenho().size()
	var fichas := n * LADO + maxi(n - 1, 0) * VAO
	# A etiqueta tem 6 px de respiro de cada lado do texto.
	return maxf(fichas, EstiloHUD.largura_texto(_fonte(), ROTULO, TAM_ROTULO) + 12.0)


func _reposicionar() -> void:
	var tam := Vector2(_largura(), ALTURA_TOTAL)
	custom_minimum_size = tam
	offset_left = -MARGEM.x - tam.x
	offset_top = -MARGEM.y - tam.y
	offset_right = -MARGEM.x
	offset_bottom = -MARGEM.y


# ─────────────────────────────────────────────────────────────
# Desenho
# ─────────────────────────────────────────────────────────────

func _draw() -> void:
	var lista := _lista_para_desenho()
	if lista.is_empty():
		return

	_desenhar_rotulo()
	for equipamento in lista:
		_desenhar_ficha(equipamento)


## EQUIPAMENTOS, alinhado pela direita com as fichas.
func _desenhar_rotulo() -> void:
	var f := _fonte()
	if f == null:
		return
	EstiloHUD.etiqueta(self, f, Vector2(size.x, 0.0), ROTULO, TAM_ROTULO)


func _desenhar_ficha(equipamento: Dictionary) -> void:
	var cor: Color = equipamento["cor"]
	var surgir: float = equipamento["surgir"]
	var clarao: float = equipamento["clarao"]
	# O pulinho de "acabei de ser usado".
	var pulo := roundf(sin(equipamento["pulso"] * PI) * 7.0)
	var centro := Vector2(roundf(size.x - equipamento["recuo"]),
		ALTURA_ROTULO + LADO * 0.5 - pulo)
	var casa := Rect2(centro - Vector2(LADO, LADO) * 0.5, Vector2(LADO, LADO))

	# Brotando: cresce passando um tico do tamanho e assenta, branca na chegada.
	var escala := _passar_e_voltar(surgir)
	var papel := EstiloHUD.PAPEL.lerp(Color.WHITE, clarao * clarao)
	draw_set_transform(centro, 0.0, Vector2(escala, escala))
	EstiloHUD.ficha(self, Rect2(-casa.size * 0.5, casa.size), minf(surgir * 3.0, 1.0), papel)
	EstiloHUD.icone(self, equipamento["textura"], Vector2.ZERO, CAIXA_ICONE,
		EstiloHUD.com_alfa(Color.WHITE, minf(surgir * 3.0, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# O aro que abre em volta quando o equipamento chega, na cor dele.
	if clarao > 0.0:
		EstiloHUD.aro(self, casa.grow(roundf((1.0 - clarao) * 16.0)),
			EstiloHUD.com_alfa(cor, clarao), EstiloHUD.MOLDURA)

	_desenhar_tecla(equipamento, centro.x, surgir)


func _desenhar_tecla(equipamento: Dictionary, x: float, surgir: float) -> void:
	var f := _fonte()
	var tecla := String(equipamento["tecla"])
	# Equipamento passivo (as botas) não tem botão: embaixo dele não vai nada.
	if f == null or tecla.is_empty():
		return
	# A tecla desenhada (F, E...); de controle na mão vira o botão da ação (□).
	EstiloHUD.tecla_da_acao(self, f,
		Vector2(x, ALTURA_ROTULO + LADO + ALTURA_TECLA * 0.5 + 2.0), tecla,
		String(equipamento.get("acao", "")), equipamento["cor"], surgir, TAM_TECLA)


## 0 -> 1 passando um pouco de 1 no caminho.
func _passar_e_voltar(t: float) -> float:
	var u := clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + 2.2 * u * u * u + 1.2 * u * u


# ─────────────────────────────────────────────────────────────

## No editor a peça aparece com os equipamentos que já têm arte, para poder
## ser enquadrada sem rodar o jogo.
func _lista_para_desenho() -> Array[Dictionary]:
	if not Engine.is_editor_hint() or not previa:
		return _equipamentos
	var falsa: Array[Dictionary] = []
	var ids := ["macarico", "bumerangue"]
	for i in ids.size():
		var id: String = ids[i]
		var ficha := CatalogoFerramentas.dados(id)
		if ficha.is_empty():
			continue
		falsa.append({
			"id": id, "rotulo": ficha.get("rotulo", ""),
			"tecla": CatalogoFerramentas.tecla(id), "acao": CatalogoFerramentas.acao(id),
			"textura": ficha["textura"], "cor": ficha.get("cor", EstiloHUD.ACENTO_PADRAO),
			"surgir": 1.0, "clarao": 0.0, "pulso": 0.0,
			"recuo": _recuo_alvo(i, ids.size()),
		})
	return falsa


func _fonte() -> Font:
	if fonte != null:
		return fonte
	return get_theme_default_font()
