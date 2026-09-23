class_name ObjetivosHUD
extends Control

# --- A LISTA DE OBJETIVOS (canto superior esquerdo) ---
#
# Só desenho e tempo: quem decide o que entra e o que sai é o autoload
# Objetivos (scripts/objetivos.gd). Aqui cada objetivo vira uma linha que passa
# por quatro momentos:
#
#   ENTRANDO   desliza da esquerda aparecendo — um objetivo novo nunca surge de
#              estalo no meio da tela
#   ATIVA      branco com contorno preto, caixinha vazia; a contagem ("2/3")
#              pulsa quando anda
#   CUMPRIDA   check.mp3, a caixinha estoura em verde com o risco do check, o
#              texto fica verde e segura um instante para ser lido
#   SAINDO     some deslizando para a esquerda; as de baixo sobem no lugar
#
# Regras de ritmo, para a lista nunca atropelar a si mesma:
#   - nada anda com a lista escondida (fala, ficha de item, puzzle, pausa): o
#     check de um objetivo cumprido atrás de uma dessas telas espera ela fechar
#     para acontecer na frente da pessoa;
#   - dois checks no mesmo instante saem um depois do outro, cada um com o
#     seu som;
#   - objetivo novo espera o check anterior assentar antes de entrar.
#
# SUBITEM: um objetivo com "pai" entra logo abaixo do pai, recuado, um pouco
# menor e com um fio em "└" ligando os dois — é a dica que detalha o objetivo
# de cima ("Use a caixa arrastável" sob "Pegue o cilindro de O₂").
#
# Texto branco com contorno preto, sem painel atrás: é o pedido de leitura em
# qualquer fundo (céu claro do world1, subsolo escuro) sem tampar o cenário.
# Os índices químicos (H₂, CO₂) são desenhados menores e abaixo da linha — a
# fonte do HUD não tem os caracteres ₂/₃, então escrever "H₂" no roteiro já
# basta.

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")
const SOM_CHECK := preload("res://sounds/check.mp3")

# --- Posição ---
const MARGEM_ESQ := 40.0
## Topo da lista quando a barra de vida não está na tela.
const TOPO_LIVRE := 28.0
## Distância entre a barra de vida e a lista, quando a barra aparece.
const FOLGA_SOB_A_VIDA := 10.0

# --- Tipografia ---
## O contorno e o índice químico (o "2" do H₂, menor e abaixo da linha) saem
## proporcionais ao tamanho do texto — ver _estilo().
const TAM_TEXTO := 20
const TAM_SUBITEM := 17
const TAM_TITULO := 13
const CONTORNO_TITULO := 6
const ESPACO_TITULO := 2.6
## Largura máxima do texto de um objetivo antes de quebrar a linha.
const LARGURA_TEXTO := 560.0
const ENTRELINHA := 27.0
const ESPACO_ENTRE_OBJETIVOS := 9.0
## Entre um objetivo e o subitem logo abaixo dele.
const ESPACO_ANTES_DO_SUBITEM := 3.0
const ALTURA_TITULO := 30.0

# --- Caixinha ---
const CAIXA := 15.0
## Do começo da caixinha até o começo do texto.
const RECUO_TEXTO := 27.0
## Quanto o subitem anda para a direita: a caixinha dele fica embaixo do
## começo do texto do pai.
const RECUO_SUBITEM := 30.0

# --- Cores ---
const BRANCO := Color(1.0, 1.0, 1.0)
const PRETO := Color(0.0, 0.0, 0.0)
const VERDE := Color(0.38, 0.96, 0.46)
const CONTAGEM := Color(1.0, 0.86, 0.36)

# --- Tempos (segundos) ---
const T_APARECER_LISTA := 0.22
const T_ENTRAR := 0.45
const T_VERDE := 0.14
const T_RISCO_CHECK := 0.26
const T_ESTOURO := 0.34
## Quanto o objetivo cumprido fica verde na tela antes de sair.
const T_SEGURAR_VERDE := 1.9
const T_SAIR := 0.45
## Um objetivo novo espera o check anterior este tanto antes de entrar.
const ESPERA_APOS_CHECK := 0.8
## Entre dois checks que acontecem juntos.
const ESPACO_ENTRE_CHECKS := 0.32
## Entre dois objetivos que entram juntos.
const ESCALONAR_ENTRADA := 0.14
const DESLIZE_ENTRADA := 26.0
const DESLIZE_SAIDA := 20.0

enum Estado { ESPERANDO, ENTRANDO, ATIVA, CUMPRIDA, SAINDO }


class Linha:
	var id: String = ""
	var texto: String = ""
	## Cabeçalho da ala a que o objetivo pertence (e a cor do losango).
	var titulo: String = ""
	var cor_titulo: Color = Color.WHITE
	## id do objetivo pai ("" = objetivo comum).
	var pai: String = ""
	## Tamanho do texto (o subitem é menor).
	var tam: int = TAM_TEXTO
	var quebras: PackedStringArray = PackedStringArray()
	var contagem: Vector2i = Vector2i(-1, -1)
	var estado: int = Estado.ESPERANDO
	## Tempo no estado atual.
	var t: float = 0.0
	## Espera antes de entrar (escalonamento).
	var atraso: float = 0.0
	## Cumprida enquanto não dava para mostrar: o check fica na fila.
	var cumprir_na_fila: bool = false
	## Já ganhou o check (sai verde, e não branca).
	var cumprida: bool = false
	var y: float = 0.0
	var posicionada: bool = false
	## Pulso da contagem (1 -> 0).
	var pulso: float = 0.0

	func altura() -> float:
		return maxf(1.0, float(quebras.size())) * entrelinha()

	func entrelinha() -> float:
		return ENTRELINHA * tam / TAM_TEXTO

	func recuo() -> float:
		return RECUO_SUBITEM if pai != "" else 0.0


var _linhas: Array[Linha] = []
var _visivel: bool = false
var _alfa_lista: float = 0.0
## Topo pedido pelo autoload e o topo animado (a lista escorrega até ele).
var _topo_alvo: float = TOPO_LIVRE
var _topo: float = -1.0
## Cabeçalho: o nome da ala do primeiro objetivo da lista.
var _titulo: String = ""
var _cor_titulo: Color = BRANCO
## Troca de ala com a lista na tela: o título velho some, o novo entra.
var _titulo_novo: String = ""
var _cor_titulo_nova: Color = BRANCO
var _troca_titulo: float = 0.0
var _alfa_titulo: float = 0.0
## Tempo desde o último check (para espaçar checks e entradas).
var _desde_ultimo_check: float = 999.0
var _som: AudioStreamPlayer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

	_som = AudioStreamPlayer.new()
	_som.name = "SomCheck"
	_som.stream = SOM_CHECK
	_som.volume_db = -3.0
	_som.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_som)


# ─────────────────────────────────────────────
#  O que o autoload Objetivos pede
# ─────────────────────────────────────────────

func tem(id: String) -> bool:
	return _achar(id) != null


## Os objetivos na tela que ainda contam (os que estão saindo já não contam).
func ids() -> PackedStringArray:
	var lista := PackedStringArray()
	for linha in _linhas:
		if linha.estado != Estado.SAINDO:
			lista.append(linha.id)
	return lista


## "pai": id do objetivo de que este é subitem ("" = objetivo comum).
func adicionar(id: String, texto: String, contagem: Vector2i, titulo: String, cor_titulo: Color,
		pai: String = "") -> void:
	if tem(id):
		return
	var linha := Linha.new()
	linha.id = id
	linha.texto = texto
	linha.titulo = titulo
	linha.cor_titulo = cor_titulo
	linha.pai = pai
	linha.tam = TAM_SUBITEM if pai != "" else TAM_TEXTO
	linha.contagem = contagem
	linha.quebras = _quebrar(linha)
	# Quem chega junto entra em fila, um logo depois do outro.
	var esperando := 0
	for outra in _linhas:
		if outra.estado == Estado.ESPERANDO:
			esperando += 1
	linha.atraso = esperando * ESCALONAR_ENTRADA
	_linhas.insert(_lugar_na_lista(pai), linha)


## Onde a linha nova entra: no fim da lista, ou — subitem — logo depois do pai
## e dos outros subitens dele.
func _lugar_na_lista(pai: String) -> int:
	if pai == "":
		return _linhas.size()
	var lugar := -1
	for i in _linhas.size():
		var linha := _linhas[i]
		if linha.estado == Estado.SAINDO:
			continue
		if linha.id == pai or (lugar >= 0 and linha.pai == pai):
			lugar = i + 1
	return lugar if lugar >= 0 else _linhas.size()


func atualizar(id: String, texto: String, contagem: Vector2i) -> void:
	var linha := _achar(id)
	if linha == null:
		return
	if contagem.x > linha.contagem.x and linha.contagem.x >= 0:
		linha.pulso = 1.0
	if texto != linha.texto or contagem != linha.contagem:
		linha.texto = texto
		linha.contagem = contagem
		linha.quebras = _quebrar(linha)


## Objetivo cumprido: check, verde, e sai sozinho depois.
func concluir(id: String) -> void:
	var linha := _achar(id)
	if linha == null or linha.estado == Estado.CUMPRIDA or linha.cumprir_na_fila:
		return
	if linha.estado == Estado.ESPERANDO:
		# Cumprido antes de chegar a aparecer: não há o que comemorar.
		_linhas.erase(linha)
		return
	if linha.contagem.x >= 0 and linha.contagem.x < linha.contagem.y:
		linha.contagem.x = linha.contagem.y
		linha.pulso = 1.0
	linha.cumprir_na_fila = true


## Objetivo que deixou de valer sem ter sido cumprido: só sai.
func remover(id: String) -> void:
	var linha := _achar(id)
	if linha == null:
		return
	if linha.estado == Estado.ESPERANDO:
		_linhas.erase(linha)
		return
	_sair(linha)


func definir_visivel(visivel: bool) -> void:
	_visivel = visivel


func definir_topo(topo: float) -> void:
	_topo_alvo = topo


# ─────────────────────────────────────────────
#  Tempo
# ─────────────────────────────────────────────

func _process(delta: float) -> void:
	var alvo_lista := 1.0 if (_visivel and _camada_visivel()) else 0.0
	_alfa_lista = move_toward(_alfa_lista, alvo_lista, delta / T_APARECER_LISTA)

	# Com a lista (mesmo que parcialmente) escondida nada anda: a pessoa não
	# perde um check nem a entrada de um objetivo novo.
	if _alfa_lista >= 1.0:
		_andar(delta)

	_andar_cabecalho(delta)
	_posicionar(delta)
	queue_redraw()


func _andar(delta: float) -> void:
	_desde_ultimo_check += delta

	# Um check por vez, espaçados — e só depois que a linha terminou de entrar.
	if _desde_ultimo_check >= ESPACO_ENTRE_CHECKS:
		for linha in _linhas:
			if linha.cumprir_na_fila and linha.estado == Estado.ATIVA:
				_cumprir(linha)
				break

	var check_recente := _desde_ultimo_check < ESPERA_APOS_CHECK or _tem_check_na_fila()

	for linha in _linhas.duplicate():
		linha.t += delta
		linha.pulso = maxf(0.0, linha.pulso - delta / 0.35)
		match linha.estado:
			Estado.ESPERANDO:
				# O objetivo novo espera o check do anterior assentar.
				if check_recente:
					linha.t = 0.0
				elif linha.t >= linha.atraso:
					_mudar(linha, Estado.ENTRANDO)
			Estado.ENTRANDO:
				if linha.t >= T_ENTRAR:
					_mudar(linha, Estado.ATIVA)
			Estado.CUMPRIDA:
				if linha.t >= T_SEGURAR_VERDE:
					_sair(linha)
			Estado.SAINDO:
				if linha.t >= T_SAIR:
					_linhas.erase(linha)


func _cumprir(linha: Linha) -> void:
	linha.cumprir_na_fila = false
	linha.cumprida = true
	_mudar(linha, Estado.CUMPRIDA)
	_desde_ultimo_check = 0.0
	_som.play()


func _sair(linha: Linha) -> void:
	linha.cumprir_na_fila = false
	_mudar(linha, Estado.SAINDO)


func _mudar(linha: Linha, estado: int) -> void:
	linha.estado = estado
	linha.t = 0.0


func _tem_check_na_fila() -> bool:
	for linha in _linhas:
		if linha.cumprir_na_fila:
			return true
	return false


## O cabeçalho é o nome da ala do primeiro objetivo na tela. Some junto com a
## última linha; troca (apagando e acendendo) quando a lista passa de uma ala
## para outra.
func _andar_cabecalho(delta: float) -> void:
	var primeira: Linha = null
	for linha in _linhas:
		if linha.estado != Estado.ESPERANDO and linha.estado != Estado.SAINDO:
			primeira = linha
			break
	var tem_linhas := false
	for linha in _linhas:
		if linha.estado != Estado.ESPERANDO:
			tem_linhas = true
			break
	_alfa_titulo = move_toward(_alfa_titulo, 1.0 if tem_linhas else 0.0, delta / 0.3)

	if primeira != null:
		var destino := _titulo_novo if not _titulo_novo.is_empty() else _titulo
		if primeira.titulo != destino:
			if _titulo.is_empty() or _alfa_titulo <= 0.01:
				_titulo = primeira.titulo
				_cor_titulo = primeira.cor_titulo
				_titulo_novo = ""
			else:
				_titulo_novo = primeira.titulo
				_cor_titulo_nova = primeira.cor_titulo
				_troca_titulo = 0.0

	if not _titulo_novo.is_empty() and _alfa_lista >= 1.0:
		_troca_titulo += delta / 0.5
		if _troca_titulo >= 0.5 and _titulo != _titulo_novo:
			_titulo = _titulo_novo
			_cor_titulo = _cor_titulo_nova
		if _troca_titulo >= 1.0:
			_titulo_novo = ""
			_troca_titulo = 0.0


## As linhas escorregam para o lugar novo quando uma sai (ou quando a barra de
## vida aparece e empurra a lista para baixo).
func _posicionar(delta: float) -> void:
	var suave := 1.0 - exp(-13.0 * delta)
	_topo = _topo_alvo if _topo < 0.0 else lerpf(_topo, _topo_alvo, suave)
	var y := _topo + ALTURA_TITULO
	var primeira := true
	for linha in _linhas:
		if linha.estado == Estado.ESPERANDO:
			continue
		if not primeira:
			y += ESPACO_ANTES_DO_SUBITEM if linha.pai != "" else ESPACO_ENTRE_OBJETIVOS
		primeira = false
		if not linha.posicionada:
			linha.y = y
			linha.posicionada = true
		else:
			linha.y = lerpf(linha.y, y, suave)
		y += linha.altura()


# ─────────────────────────────────────────────
#  Desenho
# ─────────────────────────────────────────────

func _draw() -> void:
	if _alfa_lista <= 0.0:
		return
	_desenhar_cabecalho()
	for linha in _linhas:
		if linha.estado != Estado.ESPERANDO:
			_desenhar_linha(linha)


func _desenhar_cabecalho() -> void:
	var alfa := _alfa_lista * _alfa_titulo
	if _titulo_novo != "":
		# Some o título velho, entra o novo.
		alfa *= absf(1.0 - _troca_titulo * 2.0)
	if alfa <= 0.0 or _titulo.is_empty():
		return

	var base := Vector2(MARGEM_ESQ, _topo + 16.0)
	# Losango na cor da ala.
	var centro := base + Vector2(6.0, -5.0)
	var losango := PackedVector2Array([
		centro + Vector2(0, -7), centro + Vector2(7, 0),
		centro + Vector2(0, 7), centro + Vector2(-7, 0)])
	draw_colored_polygon(_inflar(losango, 3.0), _com_alfa(PRETO, alfa))
	draw_colored_polygon(losango, _com_alfa(_cor_titulo, alfa))

	var x_texto := base.x + RECUO_TEXTO - 4.0
	_texto_espacado(Vector2(x_texto, base.y), _titulo, TAM_TITULO, ESPACO_TITULO,
		_com_alfa(BRANCO, alfa), CONTORNO_TITULO, alfa)

	# Fio que sai do título e se apaga para a direita.
	var fim_texto := x_texto + _largura_espacada(_titulo, TAM_TITULO, ESPACO_TITULO)
	var y_fio := base.y - 5.0
	var ini := fim_texto + 12.0
	var fim := ini + 90.0
	draw_line(Vector2(ini - 1.0, y_fio), Vector2(fim + 1.0, y_fio), _com_alfa(PRETO, alfa * 0.9), 5.0)
	var cores := PackedColorArray([_com_alfa(BRANCO, alfa * 0.85), _com_alfa(BRANCO, 0.0)])
	draw_polyline_colors(PackedVector2Array([Vector2(ini, y_fio), Vector2(fim, y_fio)]), cores, 2.0)


func _desenhar_linha(linha: Linha) -> void:
	var alfa := _alfa_lista
	var deslize := 0.0
	var verde := 0.0
	var risco := 0.0
	var estouro := -1.0

	match linha.estado:
		Estado.ENTRANDO:
			var p := clampf(linha.t / T_ENTRAR, 0.0, 1.0)
			alfa *= _suave(p)
			deslize = -DESLIZE_ENTRADA * pow(1.0 - p, 3.0)
		Estado.CUMPRIDA:
			verde = clampf(linha.t / T_VERDE, 0.0, 1.0)
			risco = _suave(clampf((linha.t - 0.04) / T_RISCO_CHECK, 0.0, 1.0))
			estouro = clampf(linha.t / T_ESTOURO, 0.0, 1.0)
		Estado.SAINDO:
			var p := clampf(linha.t / T_SAIR, 0.0, 1.0)
			alfa *= 1.0 - _suave(p)
			deslize = -DESLIZE_SAIDA * p * p
			# Quem sai depois de cumprido continua verde e com o check.
			if linha.cumprida:
				verde = 1.0
				risco = 1.0
	if alfa <= 0.0:
		return

	var x := MARGEM_ESQ + linha.recuo() + deslize
	var cor_texto := BRANCO.lerp(VERDE, verde)
	var proporcao := float(linha.tam) / TAM_TEXTO
	var centro_caixa := Vector2(x, linha.y + linha.entrelinha() * 0.5 - 1.0)
	if linha.pai != "":
		_desenhar_fio_do_subitem(linha, centro_caixa, CAIXA * proporcao, alfa)
	_desenhar_caixa(centro_caixa, verde, risco, estouro, alfa, CAIXA * proporcao)

	var x_texto := x + RECUO_TEXTO * proporcao
	var ascendente := FONTE.get_ascent(linha.tam)
	for i in linha.quebras.size():
		var base := Vector2(x_texto, linha.y + ascendente + i * linha.entrelinha() + 1.0)
		var largura := _desenhar_texto(base, linha.quebras[i], cor_texto, alfa, linha.tam)
		# A contagem vai no fim da última linha.
		if i == linha.quebras.size() - 1 and linha.contagem.x >= 0:
			_desenhar_contagem(Vector2(base.x + largura + 12.0, base.y), linha, verde, alfa)


## O "└" que liga o subitem ao objetivo de cima: desce de baixo da caixinha do
## pai e vira para a caixinha do subitem.
func _desenhar_fio_do_subitem(linha: Linha, centro_caixa: Vector2, lado: float, alfa: float) -> void:
	var x_fio := centro_caixa.x - RECUO_SUBITEM
	var topo := centro_caixa.y - ENTRELINHA * 0.5
	var pai := _achar(linha.pai)
	if pai != null and pai.posicionada:
		# Logo abaixo da caixinha do pai, mesmo que o texto dele quebre linha.
		topo = minf(topo, pai.y + pai.entrelinha() * 0.5 + CAIXA * 0.5 + 4.0)
	var pontos := PackedVector2Array([
		Vector2(x_fio, topo),
		Vector2(x_fio, centro_caixa.y),
		Vector2(centro_caixa.x - lado * 0.5 - 5.0, centro_caixa.y),
	])
	draw_polyline(pontos, _com_alfa(PRETO, alfa), 5.0)
	draw_polyline(pontos, _com_alfa(BRANCO, alfa * 0.85), 2.0)


## A caixinha: vazia enquanto vale, estoura em verde com o check ao cumprir.
func _desenhar_caixa(centro: Vector2, verde: float, risco: float, estouro: float, alfa: float,
		lado_base: float = CAIXA) -> void:
	var escala := 1.0
	if estouro >= 0.0 and estouro < 1.0:
		# Cresce rápido e volta com um leve quique.
		escala = 1.0 + 0.45 * sin(estouro * PI) * (1.0 - estouro * 0.5)
		# Anel que se espalha a partir da caixinha.
		var raio := lerpf(lado_base * 0.6, lado_base * 1.9, _suave(estouro))
		var anel := _com_alfa(VERDE, alfa * (1.0 - estouro) * 0.9)
		draw_arc(centro, raio, 0.0, TAU, 32, _com_alfa(PRETO, anel.a * 0.5), 5.0, true)
		draw_arc(centro, raio, 0.0, TAU, 32, anel, 2.5, true)

	var lado := lado_base * escala
	var caixa := Rect2(centro - Vector2(lado, lado) * 0.5, Vector2(lado, lado))
	draw_rect(caixa.grow(3.0), _com_alfa(PRETO, alfa))
	if verde > 0.0:
		draw_rect(caixa, _com_alfa(VERDE, alfa * verde))
	draw_rect(caixa.grow(-1.0), _com_alfa(BRANCO.lerp(VERDE, verde), alfa), false, 2.0)

	if risco > 0.0:
		var pontos := PackedVector2Array([
			caixa.position + Vector2(0.18, 0.52) * lado,
			caixa.position + Vector2(0.42, 0.76) * lado,
			caixa.position + Vector2(0.86, 0.22) * lado,
		])
		var parcial := _trecho_do_caminho(pontos, risco)
		draw_polyline(parcial, _com_alfa(PRETO, alfa), 6.0, true)
		draw_polyline(parcial, _com_alfa(BRANCO, alfa), 3.0, true)


func _desenhar_contagem(base: Vector2, linha: Linha, verde: float, alfa: float) -> void:
	var texto := "%d/%d" % [linha.contagem.x, linha.contagem.y]
	var cor := CONTAGEM.lerp(VERDE, verde)
	var tam := linha.tam
	if linha.pulso > 0.0:
		# A contagem andou: salta e acende em branco por um instante.
		tam = int(round(linha.tam * (1.0 + 0.3 * linha.pulso)))
		cor = cor.lerp(BRANCO, linha.pulso * 0.7)
		base.y += (tam - linha.tam) * 0.35
	draw_string_outline(FONTE, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam,
		_estilo(linha.tam)["contorno"], _com_alfa(PRETO, alfa))
	draw_string(FONTE, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, _com_alfa(cor, alfa))


# ─────────────────────────────────────────────
#  Texto com índice químico
# ─────────────────────────────────────────────

## "H₂O" -> [["H", false], ["2", true], ["O", false]]. O true é índice.
func _segmentos(texto: String) -> Array:
	var saida: Array = []
	var atual := ""
	var atual_indice := false
	for i in texto.length():
		var codigo := texto.unicode_at(i)
		var indice := codigo >= 0x2080 and codigo <= 0x2089
		var c := char(codigo - 0x2080 + 48) if indice else texto[i]
		if indice != atual_indice and not atual.is_empty():
			saida.append([atual, atual_indice])
			atual = ""
		atual += c
		atual_indice = indice
	if not atual.is_empty():
		saida.append([atual, atual_indice])
	return saida


## Contorno e índice químico proporcionais ao tamanho do texto. No tamanho
## cheio (20): índice 13, contornos 7 e 5, índice descendo 5 px.
func _estilo(tam: int) -> Dictionary:
	return {
		"indice": roundi(tam * 0.65),
		"contorno": roundi(tam * 0.35),
		"contorno_indice": roundi(tam * 0.25),
		"descida": tam * 0.25,
	}


func _medir(texto: String, tam: int = TAM_TEXTO) -> float:
	var estilo := _estilo(tam)
	var largura := 0.0
	for seg in _segmentos(texto):
		var tam_seg: int = estilo["indice"] if seg[1] else tam
		largura += FONTE.get_string_size(seg[0], HORIZONTAL_ALIGNMENT_LEFT, -1, tam_seg).x
	return largura


## Desenha uma linha (contornos primeiro, depois o preenchimento, para o
## contorno de uma letra nunca cobrir a vizinha). Devolve a largura.
func _desenhar_texto(base: Vector2, texto: String, cor: Color, alfa: float,
		tam: int = TAM_TEXTO) -> float:
	var estilo := _estilo(tam)
	var segs := _segmentos(texto)
	for passada in 2:
		var x := base.x
		for seg in segs:
			var indice: bool = seg[1]
			var tam_seg: int = estilo["indice"] if indice else tam
			var pos := Vector2(x, base.y + (estilo["descida"] if indice else 0.0))
			if passada == 0:
				draw_string_outline(FONTE, pos, seg[0], HORIZONTAL_ALIGNMENT_LEFT, -1, tam_seg,
					estilo["contorno_indice"] if indice else estilo["contorno"], _com_alfa(PRETO, alfa))
			else:
				draw_string(FONTE, pos, seg[0], HORIZONTAL_ALIGNMENT_LEFT, -1, tam_seg, _com_alfa(cor, alfa))
			x += FONTE.get_string_size(seg[0], HORIZONTAL_ALIGNMENT_LEFT, -1, tam_seg).x
	return _medir(texto, tam)


## Quebra por palavras, reservando no fim o espaço da contagem. Quando precisa
## de mais de uma linha, as linhas saem EQUILIBRADAS (a menor largura que ainda
## cabe no mesmo número de linhas): nada de uma palavra sozinha embaixo.
func _quebrar(linha: Linha) -> PackedStringArray:
	var texto := linha.texto
	var tam := linha.tam
	var reserva := 0.0
	if linha.contagem.x >= 0:
		reserva = FONTE.get_string_size("%d/%d" % [linha.contagem.y, linha.contagem.y],
			HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + 14.0
	var largura_max := LARGURA_TEXTO - linha.recuo()
	var linhas := _quebrar_em(texto, largura_max, reserva, tam)
	if linhas.size() < 2:
		return linhas
	var estreita := 0.0
	var larga := largura_max
	for i in 10:
		var meio := (estreita + larga) * 0.5
		if _quebrar_em(texto, meio, reserva, tam).size() <= linhas.size():
			larga = meio
		else:
			estreita = meio
	return _quebrar_em(texto, larga, reserva, tam)


func _quebrar_em(texto: String, largura: float, reserva: float, tam: int) -> PackedStringArray:
	var linhas := PackedStringArray()
	var atual := ""
	for palavra in texto.split(" ", false):
		var teste := palavra if atual.is_empty() else atual + " " + palavra
		if atual.is_empty() or _medir(teste, tam) <= largura:
			atual = teste
		else:
			linhas.append(atual)
			atual = palavra
	if not atual.is_empty():
		linhas.append(atual)
	# A contagem não coube na última linha: a última palavra desce.
	if reserva > 0.0 and linhas.size() > 0 and _medir(linhas[-1], tam) + reserva > largura:
		var palavras := linhas[-1].split(" ", false)
		if palavras.size() > 1:
			var ultima := palavras[-1]
			palavras.remove_at(palavras.size() - 1)
			linhas[-1] = " ".join(palavras)
			linhas.append(ultima)
	return linhas


func _texto_espacado(base: Vector2, texto: String, tam: int, espaco: float, cor: Color,
		contorno: int, alfa: float) -> void:
	for passada in 2:
		var x := base.x
		for i in texto.length():
			var c := texto[i]
			if passada == 0:
				draw_string_outline(FONTE, Vector2(x, base.y), c, HORIZONTAL_ALIGNMENT_LEFT, -1,
					tam, contorno, _com_alfa(PRETO, alfa))
			else:
				draw_string(FONTE, Vector2(x, base.y), c, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
			x += FONTE.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + espaco


func _largura_espacada(texto: String, tam: int, espaco: float) -> float:
	var largura := 0.0
	for i in texto.length():
		largura += FONTE.get_string_size(texto[i], HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + espaco
	return maxf(0.0, largura - espaco)


# ─────────────────────────────────────────────
#  Auxiliares
# ─────────────────────────────────────────────

func _achar(id: String) -> Linha:
	for linha in _linhas:
		if linha.id == id and linha.estado != Estado.SAINDO:
			return linha
	return null


## A camada do autoload pode ser apagada pela cortina das portas (FadeTela).
func _camada_visivel() -> bool:
	var camada := get_parent() as CanvasLayer
	return is_visible_in_tree() and (camada == null or camada.visible)


func _suave(p: float) -> float:
	return 1.0 - pow(1.0 - p, 3.0)


func _com_alfa(cor: Color, alfa: float) -> Color:
	return Color(cor.r, cor.g, cor.b, cor.a * alfa)


## Contorno de um polígono convexo empurrado para fora (o preto atrás do losango).
func _inflar(pontos: PackedVector2Array, quanto: float) -> PackedVector2Array:
	var inflados := Geometry2D.offset_polygon(pontos, quanto, Geometry2D.JOIN_MITER)
	return inflados[0] if not inflados.is_empty() else pontos


## Os primeiros "p" (0..1) do comprimento de uma polilinha — o risco do check
## sendo desenhado.
func _trecho_do_caminho(pontos: PackedVector2Array, p: float) -> PackedVector2Array:
	var total := 0.0
	for i in range(1, pontos.size()):
		total += pontos[i - 1].distance_to(pontos[i])
	var falta := total * clampf(p, 0.0, 1.0)
	var saida := PackedVector2Array([pontos[0]])
	for i in range(1, pontos.size()):
		var trecho := pontos[i - 1].distance_to(pontos[i])
		if falta >= trecho:
			saida.append(pontos[i])
			falta -= trecho
		else:
			saida.append(pontos[i - 1].lerp(pontos[i], falta / maxf(trecho, 0.001)))
			break
	if saida.size() == 1:
		saida.append(pontos[0])
	return saida
