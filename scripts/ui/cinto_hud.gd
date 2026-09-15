@tool
class_name CintoHUD
extends Control

# --- O CINTO DE FERRAMENTAS (canto inferior direito) ---
#
# A terceira peça do mesmo aparelho: barra de vida (hud_vital), mochila
# (mochila_hud) e cinto. Mesmo painel de vidro chanfrado, mesmo contorno frio,
# mesmos alvéolos hexagonais, mesma tipografia em caixa alta — trocar uma cor
# no EstiloHUD troca as três de uma vez.
#
# Antes o cinto era outra coisa: discos redondos soltos na tela, sem painel,
# com o nome flutuando por cima do cenário. Funcionava, mas não pertencia ao
# resto — parecia selo de outro jogo colado no canto.
#
# A DIFERENÇA ENTRE MOCHILA E CINTO é de propósito, e o desenho conta isso:
#
#   MOCHILA -> o que ela CARREGA para um puzzle. Capacidade fixa (3 alvéolos,
#              os vazios à mostra), nome do item embaixo, some quando é usado.
#   CINTO   -> o que ela SABE FAZER, para sempre. Não tem alvéolo vazio (a
#              ferramenta que não existe ainda não se anuncia), e embaixo de
#              cada uma vai a TECLA que a aciona, não o nome.
#
# A tecla é o que faz o cinto valer alguma coisa em jogo: o painel deixa de ser
# troféu e vira consulta ("o que eu aperto para o maçarico?"). É a mesma tampa
# de tecla do rodapé da ficha de coleta (EstiloHUD.tecla).
#
# O CABEÇALHO é a linha de status: normalmente diz CINTO; quando uma ferramenta
# é conquistada ou usada no mundo, ele vira o nome dela, na cor dela, e volta
# sozinho. Assim o nome não precisa de espaço próprio nem flutua sobre o jogo.

## Distância do painel até o canto da tela.
const MARGEM := Vector2(26.0, 22.0)

const RAIO_CELULA := 36.0
const SEPARACAO := 14.0
## Caixa em que o desenho da ferramenta é encaixado dentro do alvéolo.
const CAIXA_ICONE := 42.0

const PADDING := Vector2(16.0, 10.0)
const PADDING_BASE := 12.0
const ALTURA_CABECALHO := 24.0
## Faixa das tampas de tecla, embaixo dos alvéolos.
const ALTURA_TECLA := 30.0
const CORTE := 16.0

const TAM_CABECALHO := 11
const ESPACO_CABECALHO := 3.2
const TAM_TECLA := 13
const TAM_PASSIVA := 9

const ALTURA_CELULA := RAIO_CELULA * 1.7320508
const ALTURA_TOTAL := PADDING.y + ALTURA_CABECALHO + ALTURA_CELULA + ALTURA_TECLA \
	+ PADDING_BASE

## Quanto tempo o cabeçalho segura o nome da ferramenta antes de voltar a
## dizer "CINTO".
const TEMPO_STATUS := 2.6

@export var fonte: Font:
	set(valor):
		fonte = valor
		queue_redraw()

@export_group("Prévia no editor")
## Desenha o cinto com três ferramentas, para dar para enquadrar a peça sem
## rodar o jogo e conquistar nada.
@export var previa: bool = true:
	set(valor):
		previa = valor
		queue_redraw()

var _ferramentas: Array[Dictionary] = []
## A largura do painel acompanha a quantidade de ferramentas; ela é animada
## para o painel ABRIR quando uma nova entra, em vez de saltar de tamanho.
var _largura_atual: float = 0.0
var _status_texto: String = ""
var _status_cor: Color = EstiloHUD.TEXTO_FRACO
var _status_tempo: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	if Engine.is_editor_hint():
		_largura_atual = _largura_alvo()
		_reposicionar()
		set_process(false)
		queue_redraw()
		return

	visible = false
	set_process(false)


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

## Pendura a ferramenta no cinto. "anunciar" false monta o alvéolo já pronto,
## sem estouro — é o caminho de quem carrega um jogo salvo, ou troca de cena
## com a habilidade já na mão.
func pendurar(ficha: Dictionary, anunciar: bool = true) -> void:
	var id := String(ficha.get("id", ""))
	if id.is_empty() or indice_de(id) >= 0:
		return

	_ferramentas.append({
		"id": id,
		"rotulo": String(ficha.get("rotulo", "")),
		"tecla": String(ficha.get("tecla", "")),
		"textura": ficha.get("textura", null),
		"cor": ficha.get("cor", EstiloHUD.ACENTO_PADRAO),
		"surgir": 0.0 if anunciar else 1.0,
		"clarao": 1.0 if anunciar else 0.0,
		"pulso": 0.0,
	})
	visible = true

	if anunciar:
		_anunciar(_ferramentas[-1])
	else:
		# Sem anúncio o painel já nasce do tamanho certo (nada de abrir
		# sozinho quando a fase só está recompondo o que ela já tinha).
		_largura_atual = _largura_alvo()
		_reposicionar()
	_animar()


## Pulsa a ferramenta que acabou de ser usada no mundo (corte de chapa,
## acender a retorta) e acende o nome dela no cabeçalho. Silencioso se a
## ferramenta não estiver no cinto.
func destacar(id: String) -> void:
	var i := indice_de(id)
	if i < 0:
		return
	_ferramentas[i]["clarao"] = 1.0
	_ferramentas[i]["pulso"] = 1.0
	_anunciar(_ferramentas[i])
	_animar()


func indice_de(id: String) -> int:
	for i in _ferramentas.size():
		if _ferramentas[i]["id"] == id:
			return i
	return -1


func tem(id: String) -> bool:
	return indice_de(id) >= 0


func quantidade() -> int:
	return _ferramentas.size()


## Onde o PRÓXIMO alvéolo vai nascer, em coordenadas de tela.
##
## O painel é ancorado pela direita e os alvéolos são medidos a partir da
## borda direita, então este ponto NÃO depende de quantas ferramentas já
## existem — o que permite a ficha de coleta mirar o voo do ícone aqui antes
## mesmo de o alvéolo existir.
func ponto_de_entrada() -> Vector2:
	var tela := get_viewport_rect().size
	return Vector2(
		tela.x - MARGEM.x - PADDING.x - RAIO_CELULA,
		tela.y - MARGEM.y - PADDING_BASE - ALTURA_TECLA - ALTURA_CELULA * 0.5)


# ─────────────────────────────────────────────────────────────
# Animação
# ─────────────────────────────────────────────────────────────

func _anunciar(ferramenta: Dictionary) -> void:
	_status_texto = String(ferramenta["rotulo"])
	_status_cor = ferramenta["cor"]
	_status_tempo = TEMPO_STATUS


func _animar() -> void:
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var ativo := false

	var alvo := _largura_alvo()
	if not is_equal_approx(_largura_atual, alvo):
		_largura_atual = move_toward(_largura_atual, alvo, delta * 620.0)
		_reposicionar()
		ativo = true

	for f in _ferramentas:
		if f["surgir"] < 1.0:
			f["surgir"] = minf(f["surgir"] + delta / 0.28, 1.0)
			ativo = true
		if f["clarao"] > 0.0:
			f["clarao"] = maxf(f["clarao"] - delta * 1.6, 0.0)
			ativo = true
		if f["pulso"] > 0.0:
			f["pulso"] = maxf(f["pulso"] - delta * 2.4, 0.0)
			ativo = true

	if _status_tempo > 0.0:
		_status_tempo = maxf(_status_tempo - delta, 0.0)
		ativo = true

	queue_redraw()
	if not ativo:
		set_process(false)


## Largura mínima do painel. Com uma ferramenta só, a largura dos alvéolos
## daria uma tira de 104 px — estreita demais para o cabeçalho caber (o nome
## da ferramenta é o que aparece ali) e com cara de peça cortada pela metade.
## Neste tamanho ela lê como estante com lugar sobrando, que é o que é.
const LARGURA_MINIMA := 210.0


func _largura_alvo() -> float:
	var n := _quantidade_desenhada()
	if n <= 0:
		return 0.0
	return maxf(LARGURA_MINIMA,
		PADDING.x * 2.0 + n * RAIO_CELULA * 2.0 + (n - 1) * SEPARACAO)


func _reposicionar() -> void:
	var tam := Vector2(_largura_atual, ALTURA_TOTAL)
	custom_minimum_size = tam
	offset_left = -MARGEM.x - tam.x
	offset_top = -MARGEM.y - tam.y
	offset_right = -MARGEM.x
	offset_bottom = -MARGEM.y


# ─────────────────────────────────────────────────────────────
# Desenho
# ─────────────────────────────────────────────────────────────

## Os alvéolos são medidos a partir da borda DIREITA do painel — a que está
## presa no canto da tela. Assim a ferramenta nova sempre nasce no mesmo lugar
## e são as antigas que escorregam para a esquerda enquanto o painel abre.
func _centro_local(indice: int, total: int) -> Vector2:
	var da_direita := total - 1 - indice
	return Vector2(
		_largura_atual - PADDING.x - da_direita * (RAIO_CELULA * 2.0 + SEPARACAO)
			- RAIO_CELULA,
		PADDING.y + ALTURA_CABECALHO + ALTURA_CELULA * 0.5)


func _draw() -> void:
	var lista := _lista_para_desenho()
	if lista.is_empty() or _largura_atual <= 1.0:
		return

	_desenhar_painel()
	_desenhar_cabecalho()
	for i in lista.size():
		_desenhar_alveolo(lista[i], _centro_local(i, lista.size()))


func _desenhar_painel() -> void:
	var quadro := Rect2(Vector2.ZERO, Vector2(_largura_atual, ALTURA_TOTAL))
	var corpo := EstiloHUD.chanfro(quadro, CORTE)
	EstiloHUD.sombra(self, corpo, 5.0)
	EstiloHUD.vidro(self, corpo, 0.90)
	EstiloHUD.moldura(self, corpo, EstiloHUD.BORDA, 1.5)
	draw_line(corpo[0], corpo[1], EstiloHUD.FIO_LUZ, 1.5, true)


## O cabeçalho é a linha de status: normalmente CINTO, e o nome da ferramenta
## quando uma é conquistada ou usada. Alinhado à ESQUERDA como o "MOCHILA" do
## painel de cima — os dois rótulos ficam na borda interna, longe do canto da
## tela, e é isso que faz as duas peças parecerem irmãs.
func _desenhar_cabecalho() -> void:
	var f := _fonte()
	if f == null:
		return
	var base := PADDING.y + ALTURA_CABECALHO - 12.0
	var mostrando_status := _status_tempo > 0.0
	var texto := _status_texto if mostrando_status else "CINTO"
	var cor := _status_cor if mostrando_status else EstiloHUD.TEXTO_FRACO
	# Últimos 0,5 s: o nome apaga e o "CINTO" volta sem piscar.
	var alfa := 1.0 if not mostrando_status else clampf(_status_tempo / 0.5, 0.35, 1.0)

	EstiloHUD.texto(self, f, Vector2(PADDING.x, base), texto, TAM_CABECALHO,
		EstiloHUD.com_alfa(cor, alfa), ESPACO_CABECALHO)

	var y := PADDING.y + ALTURA_CABECALHO - 6.0
	draw_line(Vector2(PADDING.x, y), Vector2(_largura_atual - PADDING.x, y),
		EstiloHUD.com_alfa(EstiloHUD.BORDA, 0.85), 1.0)


func _desenhar_alveolo(ferramenta: Dictionary, centro: Vector2) -> void:
	var cor: Color = ferramenta["cor"]
	var surgir: float = ferramenta["surgir"]
	var pulso: float = ferramenta["pulso"]
	# O pulso engorda o hexágono um tico — é o "acabei de ser usada".
	var raio := RAIO_CELULA * (lerpf(0.72, 1.0, surgir) + pulso * 0.10)
	var hexa := EstiloHUD.hexagono(centro, raio)

	EstiloHUD.sombra(self, hexa, 3.0, 0.9)
	EstiloHUD.vidro(self, hexa, 1.0, EstiloHUD.ALVEOLO, Color(0.018, 0.024, 0.046, 0.94))
	draw_colored_polygon(hexa, EstiloHUD.com_alfa(cor, (0.10 + pulso * 0.12) * surgir))
	EstiloHUD.halo(self, centro, raio * 1.15, cor, 6, surgir * (0.8 + pulso * 0.6))
	EstiloHUD.moldura(self, hexa, EstiloHUD.com_alfa(cor, 0.30 + 0.55 * surgir), 2.0)

	EstiloHUD.icone(self, ferramenta["textura"], centro, CAIXA_ICONE,
		EstiloHUD.com_alfa(Color.WHITE, surgir), lerpf(0.7, 1.0, surgir))

	draw_line(hexa[4], hexa[5],
		EstiloHUD.com_alfa(EstiloHUD.FIO_LUZ, 0.5 + 0.5 * surgir), 1.0, true)

	var clarao: float = ferramenta["clarao"]
	if clarao > 0.0:
		var c := clarao * clarao
		draw_colored_polygon(hexa, EstiloHUD.com_alfa(Color.WHITE, c * 0.20))
		EstiloHUD.moldura(self, EstiloHUD.hexagono(centro, raio + (1.0 - c) * 20.0),
			EstiloHUD.com_alfa(cor, c * 0.85), 2.5)

	_desenhar_tecla(ferramenta, centro, surgir)


func _desenhar_tecla(ferramenta: Dictionary, centro: Vector2, surgir: float) -> void:
	var f := _fonte()
	if f == null:
		return
	var y := centro.y + ALTURA_CELULA * 0.5 + ALTURA_TECLA * 0.5 - 4.0
	var tecla := String(ferramenta["tecla"])

	if tecla.is_empty():
		# Ferramenta passiva (as botas): não há botão para anunciar, e uma
		# tampa de tecla vazia seria uma promessa falsa.
		var rotulo := "PASSIVA"
		var largura := EstiloHUD.largura_texto(f, rotulo, TAM_PASSIVA, 1.6)
		EstiloHUD.texto(self, f, Vector2(centro.x - largura * 0.5, y + 3.0), rotulo,
			TAM_PASSIVA, EstiloHUD.com_alfa(EstiloHUD.TEXTO_FRACO, surgir * 0.8), 1.6)
		return

	EstiloHUD.tecla(self, f, Vector2(centro.x, y), tecla,
		ferramenta["cor"], surgir, TAM_TECLA)


# ─────────────────────────────────────────────────────────────

func _quantidade_desenhada() -> int:
	return _lista_para_desenho().size()


## No editor o cinto aparece com as ferramentas que já têm arte, para a peça
## poder ser enquadrada sem rodar o jogo.
func _lista_para_desenho() -> Array[Dictionary]:
	if not Engine.is_editor_hint() or not previa:
		return _ferramentas
	var falsa: Array[Dictionary] = []
	for id in ["macarico", "bumerangue"]:
		var ficha := CatalogoFerramentas.dados(id)
		if ficha.is_empty():
			continue
		falsa.append({
			"id": id, "rotulo": ficha.get("rotulo", ""),
			"tecla": CatalogoFerramentas.tecla(id), "textura": ficha["textura"],
			"cor": ficha.get("cor", EstiloHUD.ACENTO_PADRAO),
			"surgir": 1.0, "clarao": 0.0, "pulso": 0.0,
		})
	return falsa


func _fonte() -> Font:
	if fonte != null:
		return fonte
	return get_theme_default_font()
