class_name AbasDoCaderno
extends Control

# --- AS ABAS DO CADERNO ABERTO (CADERNO | MAPA, no alto da tela) ---
#
# Uma ficha para cada aba, com o desenho e o nome dela, e nas pontas as teclas
# que trocam de aba: Q e E no teclado, L1 e R1 no controle (as pontas se
# emendam: com duas abas, qualquer uma das duas troca). A aba da vez é o papel
# do caderno com a moldura de tinta, um pouco mais alta que as outras; as
# outras são a plaquinha escura da barra de comandos. Clicar numa aba (ou numa
# das teclas desenhadas) também troca.
#
# Os desenhos das abas são os do ícone do HUD (CadernoIcone): o caderninho e o
# mapinha. Com nota nova esperando ser lida, a aba CADERNO tem a mesma marca
# piscando que o caderninho do ícone.
#
# Quem decide qual aba vale, e quando trocar, é o autoload Caderno: aqui só se
# desenha (e se avisa do clique).

## Clicaram nesta aba (ou na tecla que leva a ela).
signal aba_clicada(indice: int)

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

const NOMES := ["CADERNO", "MAPA"]
## Cada pixel do desenho vira um quadrado deste lado.
const PIXEL := 2.0
## A marca de nota nova na aba CADERNO: um pouco maior que o pixel do desenho,
## para se ver de longe.
const PIXEL_DA_MARCA := 3.0

const TAM_NOME := 22
const ESPACO_NOME := 2.0
const ALTURA_ABA := 44.0
## Da borda da aba ao desenho (e do nome à outra borda).
const RESPIRO := 16.0
const ENTRE_DESENHO_E_NOME := 10.0
const ENTRE_ABAS := 10.0
const ESCALA_TECLA := 2.0
const ENTRE_TECLA_E_ABA := 14.0
## A aba da vez fica isto acima das outras.
const SUBIDA := 6.0
## Quanto leva para uma aba acender e a outra apagar.
const DURACAO := 0.14

## A aba da vez (o índice em NOMES).
var atual: int = 0:
	set(valor):
		atual = clampi(valor, 0, NOMES.size() - 1)
		queue_redraw()

## O ícone do HUD: enquanto a marca de nota nova dele está acesa, ela aparece
## também na aba CADERNO.
var icone: CadernoIcone = null

## Onde a troca está: anda de uma aba à outra em DURACAO.
var _visual: float = 0.0
var _larguras: Array[float] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var total := (_lado_tecla() + ENTRE_TECLA_E_ABA) * 2.0 + ENTRE_ABAS * (NOMES.size() - 1)
	for i in NOMES.size():
		_larguras.append(RESPIRO * 2.0 + _tamanho_do_desenho(i).x + ENTRE_DESENHO_E_NOME \
			+ EstiloHUD.largura_texto(FONTE, NOMES[i], TAM_NOME, ESPACO_NOME))
		total += _larguras[i]
	size = Vector2(total, SUBIDA + ALTURA_ABA + EstiloHUD.QUEDA)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_visual = move_toward(_visual, atual, delta / DURACAO)
	# Redesenha sempre: pega também a troca de teclado para controle.
	queue_redraw()


## A aba da vez, sem animar (o caderno abrindo já nela).
func mostrar_na_hora(indice: int) -> void:
	atual = indice
	_visual = atual


## Onde fica a aba, na altura das que não estão na vez.
func caixa_da_aba(indice: int) -> Rect2:
	var x := _lado_tecla() + ENTRE_TECLA_E_ABA
	for i in indice:
		x += _larguras[i] + ENTRE_ABAS
	return Rect2(x, SUBIDA, _larguras[indice], ALTURA_ABA)


## A aba CADERNO está com a marca de nota nova?
func tem_nota_nova() -> bool:
	return icone != null and icone.novidade


## Os nomes (BotoesControle) das teclas das pontas: a que vai para a esquerda e
## a que vai para a direita.
func teclas() -> PackedStringArray:
	if BotoesControle.controle_em_uso():
		return PackedStringArray(["l1", "r1"])
	return PackedStringArray(["tecla_q", "tecla_e"])


func _draw() -> void:
	var meio := SUBIDA + ALTURA_ABA * 0.5
	var pontas := teclas()
	BotoesControle.desenhar(self, Vector2(_lado_tecla() * 0.5, meio), pontas[0], ESCALA_TECLA)
	BotoesControle.desenhar(self, Vector2(size.x - _lado_tecla() * 0.5, meio), pontas[1],
		ESCALA_TECLA)
	for i in NOMES.size():
		var acesa := clampf(1.0 - absf(_visual - i), 0.0, 1.0)
		var caixa := caixa_da_aba(i)
		caixa.position.y -= roundf(SUBIDA * acesa)
		EstiloHUD.barra(self, caixa, 1.0 - acesa)
		EstiloHUD.ficha(self, caixa, acesa)

		var desenho := _tamanho_do_desenho(i)
		var canto := Vector2(caixa.position.x + RESPIRO,
			roundf(caixa.get_center().y - desenho.y * 0.5))
		var tom := lerpf(0.82, 1.0, acesa)
		_desenhar_pixels(_desenho(i), canto + Vector2(0, PIXEL), CadernoIcone.COR_SOMBRA, true)
		_desenhar_pixels(_desenho(i), canto, Color(tom, tom, tom), false)
		# Nota nova: a marca no canto de cima do caderninho, como no ícone.
		if i == 0 and tem_nota_nova():
			CadernoIcone.desenhar_marca(self, Vector2(canto.x + desenho.x - PIXEL_DA_MARCA * 3.0,
				canto.y - PIXEL_DA_MARCA * 2.0), PIXEL_DA_MARCA)

		var cor := EstiloHUD.com_alfa(EstiloHUD.CLARO, 0.72).lerp(FaceCaderno.TINTA_TITULO, acesa)
		var base := roundf(caixa.get_center().y \
			+ (FONTE.get_ascent(TAM_NOME) - FONTE.get_descent(TAM_NOME)) * 0.5)
		EstiloHUD.texto(self, FONTE, Vector2(canto.x + desenho.x + ENTRE_DESENHO_E_NOME, base),
			NOMES[i], TAM_NOME, cor, ESPACO_NOME)


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion:
		var embaixo := _alvo_do_clique(evento.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND \
			if embaixo >= 0 and embaixo != atual else Control.CURSOR_ARROW
	elif evento is InputEventMouseButton and evento.pressed:
		if evento.button_index == MOUSE_BUTTON_LEFT:
			var indice := _alvo_do_clique(evento.position)
			if indice >= 0 and indice != atual:
				aba_clicada.emit(indice)
		accept_event()


## A aba que um clique neste ponto escolhe (-1 = nenhuma): a aba embaixo dele,
## ou a vizinha da vez, se ele cair numa das teclas das pontas.
func _alvo_do_clique(ponto: Vector2) -> int:
	if ponto.x < _lado_tecla() + ENTRE_TECLA_E_ABA * 0.5:
		return posmod(atual - 1, NOMES.size())
	if ponto.x > size.x - _lado_tecla() - ENTRE_TECLA_E_ABA * 0.5:
		return posmod(atual + 1, NOMES.size())
	for i in NOMES.size():
		var caixa := caixa_da_aba(i)
		if Rect2(caixa.position.x, 0.0, caixa.size.x, size.y).has_point(ponto):
			return i
	return -1


func _lado_tecla() -> float:
	return 16.0 * ESCALA_TECLA


func _desenho(indice: int) -> Array:
	return CadernoIcone.DESENHO if indice == 0 else CadernoIcone.DESENHO_MAPA


func _tamanho_do_desenho(indice: int) -> Vector2:
	var desenho := _desenho(indice)
	return Vector2(String(desenho[0]).length(), desenho.size()) * PIXEL


## O desenho com o canto em "canto"; com "uma_cor", todo de "cor" (a sombra),
## senão nas cores do caderninho multiplicadas por "cor".
func _desenhar_pixels(desenho: Array, canto: Vector2, cor: Color, uma_cor: bool) -> void:
	for y in desenho.size():
		var linha := String(desenho[y])
		for x in linha.length():
			if not CadernoIcone.CORES.has(linha[x]):
				continue
			var tinta: Color = cor if uma_cor else CadernoIcone.CORES[linha[x]] * cor
			draw_rect(Rect2(canto + Vector2(x, y) * PIXEL, Vector2(PIXEL, PIXEL)), tinta)
