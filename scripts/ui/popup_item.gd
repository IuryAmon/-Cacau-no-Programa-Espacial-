@tool
class_name PopupItem
extends Control

# --- A FICHA DE COLETA ---
#
# O que aparece quando a Cacau pega alguma coisa: o mundo escurece e uma folha
# do caderno sobe no centro da tela com TRÊS coisas, e só elas:
#
#   o DESENHO do item, numa casa de tinta;
#   o NOME, grande;
#   o que aquilo É (a descrição que está escrita na cena ou no catálogo).
#
# A tecla de continuar fica presa na beirada de baixo da folha (a tecla
# desenhada, afundando; de controle na mão, o botão). No toque, o desenho sai
# da casa e VOA até onde o item vai ficar — a mochila, no canto de cima, ou os
# equipamentos, no de baixo. É o voo que diz para onde a coisa foi: a ficha não
# escreve "ferramenta adquirida", "item coletado" nem o destino.
#
# A única outra linha possível é a ETIQUETA, miúda, embaixo do nome: é o que
# vem entre parênteses no nome do item ("Cilindro de Oxigênio (Comburente)").
# "(Ferramenta)" não vira etiqueta.
#
# Tudo é desenhado (_draw) com as peças do EstiloHUD, e O LAYOUT SE MEDE
# SOZINHO: o nome cai para a letra menor (e quebra em linhas) se não couber, a
# descrição quebra em linhas, a altura da folha vem da soma e a largura
# encolhe até o texto (uma ficha de uma frase curta não vira uma faixa
# atravessando a tela). Qualquer texto escrito numa cena cabe sem ajuste no
# editor.

## Emitido quando o desenho de saída termina e a ficha já saiu da tela.
signal fechado

# --- Medidas da ficha (em pixels de tela) ---
## A largura vai do texto que a ficha tem: nunca passa da máxima, nunca fica
## abaixo da mínima.
const LARGURA := 720.0
const LARGURA_MINIMA := 440.0
const MARGEM := 28.0
## A casa do desenho do item, e a caixa em que ele é encaixado dentro dela.
const LADO_CASA := 112.0
const CAIXA_ICONE := 80.0
## Onde a coluna de texto começa, contada da borda esquerda da ficha.
const COLUNA_TEXTO := MARGEM + LADO_CASA + 24.0

# --- Tipografia (a fonte do jogo nos tamanhos inteiros dela: 11, 22, 33) ---
## O nome tenta o tamanho grande; se não couber numa linha, cai para o menor
## (e aí quebra em quantas linhas precisar).
const TAM_TITULO := 33
const TAM_TITULO_MENOR := 22
const TAM_ETIQUETA := 11
const TAM_DESCRICAO := 22
const ENTRELINHA := 1.36
## Entre o nome (com a etiqueta) e a descrição.
const ESPACO_DESCRICAO := 12.0

# --- Tempos ---
const DURACAO_ENTRADA := 0.3
const DURACAO_SAIDA := 0.2
## O véu demora mais que a ficha para apagar: o ícone ainda está voando, e é
## bom que ele voe sobre a tela escura. Casado com o tempo do voo
## (InventarioHud.DURACAO_VOO) para o mundo reacender no encaixe.
const DURACAO_SAIDA_VEU := 0.60

@export var fonte: Font:
	set(valor):
		fonte = valor
		_invalidar()

## Fonte do parágrafo. Vazia = usa a mesma do título.
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
			visible = previa_visivel
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

# --- Estado ---
var _ficha: Dictionary = {}
var _entrada: float = 0.0
var _saida: float = 0.0
var _veu_saida: float = 0.0
var _aberto: bool = false
## O ícone sai da casa quando alça voo.
var _icone_solto: bool = false
var _clarao_solta: float = 0.0
var _layout: Dictionary = {}
## Quadro da tecla no último desenho (ela afunda em loop).
var _quadro_da_tecla: int = -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pixel art: nada de suavizar o desenho do item ao ampliar.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(_invalidar)

	if Engine.is_editor_hint():
		# No editor a ficha é prévia parada. Com "previa_visivel" desligada (o
		# padrão), ela fica vazia e o _draw devolve na primeira linha: é o que
		# mantém o workspace das fases limpo.
		#
		# E ESCONDIDA, não só vazia: este Control ocupa a tela inteira, e no
		# editor das fases a HUD do Player é desenhada em cima do começo do
		# mapa. Visível, ele ganhava todo clique ali e selecionava o Player no
		# lugar do que estava embaixo (o rádio da entrada da fase 1). O
		# cadeado do nó na inventario_hud.tscn não vale nas cenas de fora.
		_ficha = _ficha_de_previa() if previa_visivel else {}
		visible = previa_visivel
		_entrada = 1.0
		set_process(false)
		queue_redraw()
		return

	visible = false
	set_process(false)


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

## Abre a ficha. "dados" traz nome, descricao, icone e id.
func abrir(dados: Dictionary) -> void:
	_ficha = _normalizar(dados)
	_entrada = 0.0
	_saida = 0.0
	_veu_saida = 0.0
	_icone_solto = false
	_clarao_solta = 0.0
	_aberto = true
	_invalidar()
	visible = true
	set_process(true)


## Fecha a ficha. Não espera nada: quem chamou continua a coreografia (o voo do
## ícone) enquanto a folha apaga, e ouve o sinal "fechado" no fim.
func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	_saida = 0.0
	_veu_saida = 0.0
	set_process(true)


## Onde o desenho do item está, em coordenadas de tela — é daqui que ele parte
## quando voa para a mochila ou para os equipamentos.
func centro_do_icone() -> Vector2:
	var m := _medidas()
	var origem: Vector2 = m["origem"]
	var casa: Rect2 = m["casa"]
	return get_global_transform() * (origem + casa.get_center())


## Tamanho aparente do ícone na ficha, para o voo começar exatamente do
## tamanho que a pessoa está vendo e ir diminuindo até o da casa de destino.
func caixa_do_icone() -> float:
	return CAIXA_ICONE


## Onde a ficha está e que tamanho ficou depois de se medir pelo texto. Serve
## para conferir enquadramento (inclusive no teste headless, que não desenha).
func retangulo_da_ficha() -> Rect2:
	var m := _medidas()
	var origem: Vector2 = m["origem"]
	var caixa: Rect2 = m["caixa"]
	return Rect2(origem, caixa.size)


## O que a ficha escreve, de cima para baixo: as linhas do nome, a etiqueta (se
## houver) e as linhas da descrição. Não há mais nada escrito nela.
func textos() -> PackedStringArray:
	var m := _medidas()
	var lista := PackedStringArray(m["linhas_titulo"])
	if not String(_ficha.get("etiqueta", "")).is_empty():
		lista.append(String(_ficha["etiqueta"]))
	lista.append_array(m["linhas"])
	return lista


## O ícone saiu da casa (virou o voo). Deixa um clarão no lugar, para a saída
## não parecer que o desenho simplesmente sumiu.
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
	var mudou := false

	if _aberto:
		if _entrada < 1.0:
			_entrada = minf(_entrada + delta / DURACAO_ENTRADA, 1.0)
			mudou = true
	else:
		_saida = minf(_saida + delta / DURACAO_SAIDA, 1.0)
		_veu_saida = minf(_veu_saida + delta / DURACAO_SAIDA_VEU, 1.0)
		mudou = true
		if _veu_saida >= 1.0:
			visible = false
			set_process(false)
			fechado.emit()

	if _clarao_solta > 0.0:
		_clarao_solta = maxf(_clarao_solta - delta * 3.0, 0.0)
		mudou = true

	# Parada, a ficha só muda quando a tecla troca de quadro.
	var quadro := BotoesControle.quadro_atual()
	if mudou or quadro != _quadro_da_tecla:
		_quadro_da_tecla = quadro
		queue_redraw()


func _suave(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


## 0 -> 1 passando um pouco de 1 no caminho: a folha é posta na mesa.
func _passar_e_voltar(t: float) -> float:
	var u := clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + 2.2 * u * u * u + 1.2 * u * u


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

	# O nome: grande se couber numa linha; senão a letra menor, quebrando.
	var titulo: String = String(_ficha.get("titulo", "")).to_upper()
	var tam_titulo := TAM_TITULO
	var linhas_titulo := PackedStringArray([titulo])
	if f != null and f.get_string_size(titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_TITULO).x \
			> largura_texto:
		tam_titulo = TAM_TITULO_MENOR
		linhas_titulo = EstiloHUD.quebrar(f, titulo, TAM_TITULO_MENOR, largura_texto)
	var passo_titulo := float(tam_titulo) + 4.0
	var altura_titulo := linhas_titulo.size() * passo_titulo

	var tem_etiqueta := not String(_ficha.get("etiqueta", "")).is_empty()
	var altura_etiqueta := float(TAM_ETIQUETA) + 8.0 if tem_etiqueta else 0.0

	var linhas := EstiloHUD.quebrar(ft, String(_ficha.get("descricao", "")),
		TAM_DESCRICAO, largura_texto)
	var entrelinha := TAM_DESCRICAO * ENTRELINHA
	var altura_desc := 0.0
	if not linhas.is_empty():
		altura_desc = ESPACO_DESCRICAO + (linhas.size() - 1) * entrelinha + float(TAM_DESCRICAO)

	var altura_texto := altura_titulo + altura_etiqueta + altura_desc
	var altura := maxf(altura_texto, LADO_CASA) + MARGEM * 2.0

	# A largura: a da linha mais comprida que a ficha escreve.
	var mais_larga := 0.0
	if f != null:
		for linha in linhas_titulo:
			mais_larga = maxf(mais_larga,
				f.get_string_size(linha, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_titulo).x)
		mais_larga = maxf(mais_larga, f.get_string_size(String(_ficha.get("etiqueta", "")),
			HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_ETIQUETA).x)
	if ft != null:
		for linha in linhas:
			mais_larga = maxf(mais_larga,
				ft.get_string_size(linha, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_DESCRICAO).x)
	# Em número par, para a ficha centrada cair em pixel inteiro.
	var largura := clampf(ceilf((COLUNA_TEXTO + mais_larga + MARGEM) * 0.5) * 2.0,
		LARGURA_MINIMA, LARGURA)

	# A ficha fica um pouco acima do meio da tela: é onde o olho já está.
	var origem := Vector2(
		roundf((size.x - largura) * 0.5),
		roundf(size.y * 0.46 - altura * 0.5))

	_layout = {
		"origem": origem,
		"altura": altura,
		"caixa": Rect2(Vector2.ZERO, Vector2(largura, altura)),
		# A casa do desenho fica no alto da coluna da esquerda.
		"casa": Rect2(Vector2(MARGEM, MARGEM), Vector2(LADO_CASA, LADO_CASA)),
		# Texto mais baixo que a casa fica centrado na altura dela.
		"topo_texto": roundf(MARGEM + maxf(LADO_CASA - altura_texto, 0.0) * 0.5),
		"largura_texto": largura_texto,
		"tam_titulo": tam_titulo,
		"linhas_titulo": linhas_titulo,
		"passo_titulo": passo_titulo,
		"altura_titulo": altura_titulo,
		"altura_etiqueta": altura_etiqueta,
		"linhas": linhas,
		"entrelinha": entrelinha,
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
	var alfa_ficha := clampf(_entrada * 3.0, 0.0, 1.0) * (1.0 - _suave(_saida))
	# O véu SEGURA e só então apaga (a ficha é que sai depressa): o ícone voa
	# sobre a tela ainda escura, e o mundo volta exatamente quando ele encaixa.
	var alfa_veu := clampf(_entrada * 3.0, 0.0, 1.0) \
		* (1.0 - smoothstep(0.38, 1.0, _veu_saida))
	if alfa_veu > 0.003:
		draw_rect(Rect2(Vector2.ZERO, size), EstiloHUD.com_alfa(EstiloHUD.VEU, alfa_veu))
	if alfa_ficha <= 0.003:
		return

	# A folha entra crescendo um tico além do tamanho e assenta; sai descendo.
	var caixa: Rect2 = m["caixa"]
	var origem: Vector2 = m["origem"]
	var centro := origem + caixa.size * 0.5
	var escala := _passar_e_voltar(_entrada) * lerpf(1.0, 0.96, _suave(_saida))
	var deslocamento := Vector2(0.0, roundf(_suave(_saida) * 14.0))
	# draw_set_transform faz ponto_final = origem + escala·ponto: para escalar em
	# torno do centro da ficha, origem = C - escala·C.
	draw_set_transform(centro + deslocamento - centro * escala, 0.0, Vector2(escala, escala))
	_desenhar_ficha(m, Rect2(origem, caixa.size), alfa_ficha)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _desenhar_ficha(m: Dictionary, quadro: Rect2, alfa: float) -> void:
	EstiloHUD.ficha(self, quadro, alfa, EstiloHUD.PAPEL, EstiloHUD.TINTA, EstiloHUD.MOLDURA, 8.0)
	_desenhar_casa(m, quadro, alfa)
	_desenhar_texto(m, quadro, alfa)
	_desenhar_tecla(quadro, alfa)


## A casa do desenho: um quadrado de tinta com o papel mais escuro dentro.
func _desenhar_casa(m: Dictionary, quadro: Rect2, alfa: float) -> void:
	var local: Rect2 = m["casa"]
	var casa := Rect2(quadro.position + local.position, local.size)
	EstiloHUD.ficha(self, casa, alfa, EstiloHUD.PAPEL_DOBRA, EstiloHUD.TINTA,
		EstiloHUD.MOLDURA, 0.0)

	if not _icone_solto:
		EstiloHUD.icone(self, _ficha.get("icone", null), casa.get_center(), CAIXA_ICONE,
			EstiloHUD.com_alfa(Color.WHITE, alfa))

	# O instante em que o desenho se solta e vira voo.
	if _clarao_solta > 0.0:
		draw_rect(casa.grow(-EstiloHUD.MOLDURA),
			EstiloHUD.com_alfa(Color.WHITE, _clarao_solta * _clarao_solta * 0.8))


func _desenhar_texto(m: Dictionary, quadro: Rect2, alfa: float) -> void:
	var f := _fonte()
	var ft := _fonte_texto()
	if f == null:
		return

	var x := quadro.position.x + COLUNA_TEXTO
	var y: float = quadro.position.y + m["topo_texto"]

	# O nome.
	var tam_titulo: int = m["tam_titulo"]
	var passo: float = m["passo_titulo"]
	var linhas_titulo: PackedStringArray = m["linhas_titulo"]
	for i in linhas_titulo.size():
		draw_string(f, Vector2(x, roundf(y + i * passo + _altura_da_letra(f, tam_titulo))),
			linhas_titulo[i], HORIZONTAL_ALIGNMENT_LEFT, -1, tam_titulo,
			EstiloHUD.com_alfa(EstiloHUD.TINTA, alfa))
	y += m["altura_titulo"]

	# A etiqueta (o parêntese do nome), miúda.
	var etiqueta := String(_ficha.get("etiqueta", ""))
	if not etiqueta.is_empty():
		draw_string(f, Vector2(x, roundf(y + 3.0 + _altura_da_letra(f, TAM_ETIQUETA))), etiqueta,
			HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_ETIQUETA,
			EstiloHUD.com_alfa(EstiloHUD.TINTA_FRACA, alfa))
		y += m["altura_etiqueta"]

	# A descrição, linha por linha.
	var linhas: PackedStringArray = m["linhas"]
	var entrelinha: float = m["entrelinha"]
	y += ESPACO_DESCRICAO
	for i in linhas.size():
		draw_string(ft, Vector2(x, roundf(y + i * entrelinha + _altura_da_letra(ft, TAM_DESCRICAO))),
			linhas[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_DESCRICAO,
			EstiloHUD.com_alfa(EstiloHUD.TINTA_FRACA, alfa))


## A tecla de continuar, presa na beirada de baixo da folha, no canto direito
## (EstiloHUD.tecla_da_folha: a mesma do tutorial das ferramentas).
func _desenhar_tecla(quadro: Rect2, alfa: float) -> void:
	EstiloHUD.tecla_da_folha(self, _fonte(), quadro,
		alfa * clampf((_entrada - 0.6) / 0.4, 0.0, 1.0))


## O centro da tecla de continuar, para uma ficha no retângulo dado.
func centro_da_tecla(quadro: Rect2) -> Vector2:
	return EstiloHUD.centro_da_tecla_da_folha(quadro)


## Altura das maiúsculas da fonte neste tamanho: onde a linha de base fica
## para o topo da letra encostar no topo do bloco.
func _altura_da_letra(f: Font, tamanho: int) -> float:
	return roundf(f.get_ascent(tamanho) * 0.86)


# ─────────────────────────────────────────────────────────────
# Ficha
# ─────────────────────────────────────────────────────────────

## Recebe o que o HUD passou e completa o que faltar: separa o nome da
## etiqueta. Assim quem chama só precisa saber o que sabe hoje (nome, textura,
## descrição, id).
func _normalizar(dados: Dictionary) -> Dictionary:
	var id := String(dados.get("id", ""))
	var partes := EstiloHUD.separar_nome(String(dados.get("nome", "")))
	var etiqueta := String(partes["etiqueta"])
	# Ferramenta não leva etiqueta: é o voo até os equipamentos que conta isso.
	if CatalogoFerramentas.FERRAMENTAS.has(id) or etiqueta == "FERRAMENTA":
		etiqueta = ""
	return {
		"id": id,
		"nome": String(dados.get("nome", "")),
		"titulo": partes["titulo"],
		"etiqueta": etiqueta,
		"descricao": String(dados.get("descricao", "")),
		"icone": dados.get("icone", null),
	}


func _ficha_de_previa() -> Dictionary:
	return _normalizar({
		"id": previa_id,
		"nome": previa_nome,
		"descricao": previa_descricao,
		"icone": previa_icone,
	})


func _fonte() -> Font:
	if fonte != null:
		return fonte
	return get_theme_default_font()


func _fonte_texto() -> Font:
	if fonte_texto != null:
		return fonte_texto
	return _fonte()
