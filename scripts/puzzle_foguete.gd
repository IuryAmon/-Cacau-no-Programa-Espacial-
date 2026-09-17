extends CanvasLayer

# --- PUZZLE DO COMPUTADOR RECEPTOR (combustão do hidrogênio) ---
#
# Aberto pelo receptor_item_geral (o painel com tubo de coleta, no mapa). A
# tela tem duas peças ligadas por uma mangueira: o TUBO RECEPTOR à esquerda e a
# TELA DO COMPUTADOR à direita (o trajeto da mangueira é editável na cena, no nó
# Cabo/Trajeto). Tudo o que o puzzle pede acontece dentro da tela:
#
#   1. COLETA         a tela mostra a vaga de cada cilindro (silhueta preta com
#                     fio branco). A mochila sai do canto e vai, maior, para o
#                     retângulo AreaMochila da cena; a pessoa arrasta cada
#                     cilindro da mochila para dentro do tubo. Um pulso corre
#                     pela mangueira e a vaga enche de cor, de baixo para cima.
#   2. MONTAGEM       com os dois acesos, a mochila apaga (e continua onde
#                     está: no canto ela cobriria a tela), os cilindros vão
#                     para o canto da tela e a planta do foguete aparece ao
#                     lado: cada cilindro é arrastado até o seu encaixe.
#   3. BALANCEAMENTO  some tudo e entra a equação — mesmas moléculas, mesmas
#                     falas do cientista —, agora dentro da mesma tela.
#   4. IGNIÇÃO        equação certa: o foguete volta à tela e acende.
#
# Os cilindros só saem do inventário quando o puzzle termina (quem consome é o
# receptor). Até lá eles são apenas RETIRADOS da mochila: fechar no meio do
# caminho devolve cada um ao alvéolo de onde saiu.

signal puzzle_resolvido

enum Etapa { COLETA, MONTAGEM, BALANCEAMENTO, IGNICAO }

# Coeficientes corretos da reação: 2 H2 + 1 O2 -> 2 H2O
const COEF_CORRETO := [2, 1, 2]
const COEF_MAX := 4

const ITEM_H2 := "Cilindro_de_Hidrogenio"
const ITEM_O2 := "Cilindro_Oxigenio"
const ITENS := [ITEM_H2, ITEM_O2]

const TIMELINE_DICA_EQUACAO_DOBRADA := "cientista_dica_equacao_dobrada"

# ── Balanceamento guiado ──
# Em vez de explicar tudo e depois soltar a pessoa, o Dr. Chico monta a
# equação JUNTO com ela, uma molécula por vez. Cada passo:
#   1. acende o que ele vai comentar ("mostrar"), com a contagem exata que
#      ele cita em evidência ("enfase"), e fala ("fala");
#   2. leva o holofote e a seta para o botão que ele pede ("botao") — só esse
#      botão responde; vazio = a pessoa decide sozinha;
#   3. espera os coeficientes [H2, O2, H2O] chegarem em "meta" e passa ao
#      próximo passo (meta vazia = o passo termina pelo próprio botão).
# O caminho é o raciocínio de quem balanceia de verdade: iguala H, o que
# desiguala O; iguala O (que só vem em dupla), o que desiguala H de novo.
const PASTA_FALAS := "res://timelines/"
const ROTEIRO := [
	{"fala": "cientista_balanceamento_1", "mostrar": ["reagentes", "produtos"], "enfase": [],
		"botao": "mais_h2", "meta": [1, 0, 0]},
	{"fala": "cientista_balanceamento_2", "mostrar": ["reagentes"], "enfase": ["reagentes_h"],
		"botao": "mais_h2o", "meta": [1, 0, 1]},
	{"fala": "cientista_balanceamento_3", "mostrar": ["produtos"], "enfase": ["produtos_o"],
		"botao": "mais_o2", "meta": [1, 1, 1]},
	{"fala": "cientista_balanceamento_4", "mostrar": ["reagentes", "produtos"],
		"enfase": ["reagentes_o", "produtos_o"], "botao": "mais_h2o", "meta": [1, 1, 2]},
	{"fala": "cientista_balanceamento_5", "mostrar": ["reagentes", "produtos"],
		"enfase": ["reagentes_h", "produtos_h"], "botao": "", "meta": [2, 1, 2]},
	{"fala": "cientista_balanceamento_6", "mostrar": ["reagentes", "produtos"], "enfase": [],
		"botao": "ignicao", "meta": []},
]
## Respiro entre o clique certo e a próxima fala: o tempo de as moléculas
## pularem na tela e a contagem mudar — é isso que o cientista vai comentar.
const PAUSA_ENTRE_PASSOS := 0.7

# Rodapé da tela do computador na coleta (as instruções moram só dentro da tela).
const TXT_RODAPE_COLETA := "INSIRA O COMBUSTÍVEL E O COMBURENTE NO TUBO"
const TXT_RODAPE_FALTAM_OS_DOIS := "CILINDROS DE HIDROGÊNIO E DE OXIGÊNIO NÃO ENCONTRADOS"
const TXT_RODAPE_FALTA_H2 := "CILINDRO DE HIDROGÊNIO NÃO ENCONTRADO"
const TXT_RODAPE_FALTA_O2 := "CILINDRO DE OXIGÊNIO NÃO ENCONTRADO"

const FONTE_EQUACAO := preload("res://assets/fonts/ari-w9500-display.ttf")

# ── Tubo receptor (medidas em texels de "tubo receptor.png") ──
## Boca do tubo: a área em que o item pode ser solto.
const BOCA_TUBO := Rect2(9, 9, 144, 112)
## Fundo da câmara: para onde o item afunda ao entrar.
const FUNDO_TUBO := Vector2(112, 58)
## Folga em volta da boca que ainda aceita o item (px de tela) — soltar um
## pouco fora não pode parecer erro de pontaria.
const FOLGA_SOLTAR := 36.0
## Tamanho da moldura da tela em que o miolo (Display, Led) foi montado. Para
## deixar a tela maior ou menor, use "scale" no nó Tela (ver
## _normalizar_tamanho_da_tela).
const TAMANHO_BASE_TELA := Vector2(870, 630)

# ── Vagas dos cilindros na tela ──
## Folga transparente em volta da arte: é onde o contorno da silhueta cabe.
const FOLGA_SILHUETA := 2
## Escala da arte na coleta. Na montagem o cartão encolhe para 0,8 — 4x, que
## continua inteiro (pixel art não estica pela metade).
const ESCALA_CILINDRO := 5.0
const ESCALA_CARTAO_MONTAGEM := 0.8
const POS_CARTAO_COLETA := {ITEM_H2: Vector2(263, 235), ITEM_O2: Vector2(523, 235)}
const POS_CARTAO_MONTAGEM := {ITEM_H2: Vector2(110, 262), ITEM_O2: Vector2(240, 262)}

# ── Foguete dentro da tela ──
const FOGUETE_POS_MONTAGEM := Vector2(384, 33)
const FOGUETE_ESCALA_MONTAGEM := 1.35
const FOGUETE_POS_IGNICAO := Vector2(70, 38)
const FOGUETE_ESCALA_IGNICAO := 1.1
## Onde cada cilindro está desenhado na arte do foguete (px do recorte
## AtlasTexture_foguete). Ao abrir, essa área é repintada com a cor do corpo
## do foguete e no lugar dela entra a vaga (a sombra do cilindro).
const DESENHO_CILINDRO := {ITEM_H2: Rect2i(161, 16, 33, 102), ITEM_O2: Rect2i(162, 122, 32, 100)}
const COR_CORPO_FOGUETE := Color8(155, 173, 183)
## Centro do corpo de cada cilindro desenhado, e a escala da arte do item que
## fica um pouco menor que ele (35 texels -> 91 px, o desenho tem 98), para
## as sombras dos dois não encostarem uma na outra.
const CENTRO_VAGA := {ITEM_H2: Vector2(177, 66.5), ITEM_O2: Vector2(178, 171.5)}
const ESCALA_VAGA := 2.6

## Opacidade da mochila depois que os dois cilindros entraram no tubo.
const ALFA_MOCHILA_USADA := 0.4

## Tamanho do ícone "na mão" enquanto é arrastado (cresce junto com a mochila).
const CAIXA_MAO := 72.0

const COR_ERRO := Color(1.0, 0.35, 0.3)
const COR_LED_TRAVADO := Color(0.9, 0.12, 0.1)
const COR_LED_LIBERADO := Color(0.3, 0.75, 1.0)
const COR_STATUS_ESPERA := Color(0.56, 0.69, 0.88, 0.9)
const COR_STATUS_AUSENTE := Color(0.8, 0.45, 0.45, 0.8)

var etapa: int = Etapa.COLETA
var travado: bool = false
var aguardando_fechamento: bool = false
var mostrando_dialogo_cientista: bool = false
# [H2, O2, H2O] — 0 pode significar "ainda não escolhido" (mostra "?") ou
# um valor zerado de propósito pelo jogador (mostra "0"), diferenciado por 'tocado'
var coeficientes := [0, 0, 0]
var tocado := [false, false, false]

var textura_h2:  Texture2D = null
var textura_o2:  Texture2D = null
var textura_h2o: Texture2D = null

# Cada abertura é uma sessão nova. Toda corrotina anota a sua e desiste se,
# ao acordar, a tela já tiver sido fechada (ou fechada e reaberta).
var _sessao: int = 0
var _em_transicao: bool = false
var _tweens: Array = []
var _tween_prompt_acesso: Tween = null
var _tempo: float = 0.0
var _ponteiro: Vector2 = Vector2.ZERO

var _hud: Node = null
var _mochila: MochilaHUD = null

var _inseridos := {}
var _acesos := {}
var _instalados := {}
var _piscando := {}

# Item arrastado da mochila (coleta)
var _mao: ItemArrastado = null
var _mao_id: String = ""
# Cilindro arrastado dentro da tela (montagem)
var _peca: Control = null
var _peca_id: String = ""
var _offset_arrasto: Vector2 = Vector2.ZERO

var _luz_tubo: float = 0.0
var _clarao_tubo: float = 0.0
var _cor_clarao_tubo: Color = Color.WHITE
var _rodape_texto: String = ""
var _rodape_padrao: String = ""
var _rodape_cursor: bool = false
var _pos_foguete_base: Vector2 = Vector2.ZERO
var _pos_tubo_base: Vector2 = Vector2.ZERO
## Passo atual do ROTEIRO (-1 = balanceamento ainda não começou).
var _passo: int = -1
## Único botão que responde no passo atual (null = todos respondem).
var _botao_do_passo: Control = null

@onready var root_control:    Control        = $RootControl
@onready var cabo:            CaboDeDados    = $RootControl/Cabo
@onready var tubo:            TextureRect    = $RootControl/Tubo
@onready var luz_tubo:        Control        = $RootControl/Tubo/LuzTubo
@onready var guia:            Control        = $RootControl/Guia
@onready var area_mochila:    Control        = $RootControl/AreaMochila
@onready var tela:            TextureRect    = $RootControl/Tela
@onready var led:             ColorRect      = $RootControl/Tela/Led
@onready var display:         Control        = $RootControl/Tela/Display
@onready var cabecalho:       Label          = $RootControl/Tela/Display/Cabecalho
@onready var rodape:          Label          = $RootControl/Tela/Display/Rodape
@onready var aura:            ColorRect      = $RootControl/Tela/Display/Aura
@onready var destaque:        DestaqueTutorial = $RootControl/Tela/Display/Destaque
@onready var grupo_montagem:  Control        = $RootControl/Tela/Display/GrupoMontagem
@onready var foguete:         Control        = $RootControl/Tela/Display/GrupoMontagem/Foguete
@onready var fogo:            CPUParticles2D = $RootControl/Tela/Display/GrupoMontagem/Foguete/FogoFoguete
@onready var vaga_h2:         TextureRect    = $RootControl/Tela/Display/GrupoMontagem/Foguete/VagaH2
@onready var vaga_o2:         TextureRect    = $RootControl/Tela/Display/GrupoMontagem/Foguete/VagaO2
@onready var cartao_h2:       Control        = $RootControl/Tela/Display/CartaoH2
@onready var cartao_o2:       Control        = $RootControl/Tela/Display/CartaoO2
@onready var grupo_equacao:   Control        = $RootControl/Tela/Display/GrupoEquacao
@onready var painel_equacao:  Panel          = $RootControl/Tela/Display/GrupoEquacao/EquacaoPanel
@onready var linha_equacao:   HBoxContainer  = $RootControl/Tela/Display/GrupoEquacao/EquacaoPanel/PainelEquacaoEscrita/LinhaEquacao
@onready var botao_mais_h2:   Panel          = $RootControl/Tela/Display/GrupoEquacao/EquacaoPanel/BotaoMaisH2
@onready var botao_menos_h2:  Panel          = $RootControl/Tela/Display/GrupoEquacao/EquacaoPanel/BotaoMenosH2
@onready var botao_mais_o2:   Panel          = $RootControl/Tela/Display/GrupoEquacao/EquacaoPanel/BotaoMaisO2
@onready var botao_menos_o2:  Panel          = $RootControl/Tela/Display/GrupoEquacao/EquacaoPanel/BotaoMenosO2
@onready var botao_mais_h2o:  Panel          = $RootControl/Tela/Display/GrupoEquacao/EquacaoPanel/BotaoMaisH2O
@onready var botao_menos_h2o: Panel          = $RootControl/Tela/Display/GrupoEquacao/EquacaoPanel/BotaoMenosH2O
@onready var moleculas_h2:    Control        = $RootControl/Tela/Display/GrupoEquacao/EquacaoPanel/MoleculasH2
@onready var moleculas_o2:    Control        = $RootControl/Tela/Display/GrupoEquacao/EquacaoPanel/MoleculasO2
@onready var moleculas_h2o:   Control        = $RootControl/Tela/Display/GrupoEquacao/EquacaoPanel/MoleculasH2O
@onready var label_reagentes_titulo: Label   = $RootControl/Tela/Display/GrupoEquacao/EquacaoPanel/LabelReagentesTitulo
@onready var label_reagentes_valor:  RichTextLabel = $RootControl/Tela/Display/GrupoEquacao/EquacaoPanel/LabelReagentesValor
@onready var label_produtos_titulo:  Label   = $RootControl/Tela/Display/GrupoEquacao/EquacaoPanel/LabelProdutosTitulo
@onready var label_produtos_valor:   RichTextLabel = $RootControl/Tela/Display/GrupoEquacao/EquacaoPanel/LabelProdutosValor
@onready var linha_dica_ignicao: HBoxContainer = $RootControl/Tela/Display/GrupoEquacao/EquacaoPanel/LinhaDicaIgnicao
@onready var botao_ignicao:   Panel          = $RootControl/Tela/Display/GrupoEquacao/EquacaoPanel/BotaoIgnicao
@onready var grupo_ignicao:   Control        = $RootControl/Tela/Display/GrupoIgnicao
@onready var label_liberar_acesso: Label     = $RootControl/Tela/Display/GrupoIgnicao/LabelLiberarAcesso
@onready var camada_arrasto:  CanvasLayer    = $CamadaArrasto
@onready var audio_sucesso:   AudioStreamPlayer = $AudioSucesso
@onready var audio_erro:      AudioStreamPlayer = $AudioErro
@onready var audio_colocar:   AudioStreamPlayer = $AudioColocar
@onready var audio_ignicao:   AudioStreamPlayer = $AudioIgnicao
@onready var audio_drag:      AudioStreamPlayer = $AudioDrag
@onready var audio_pop:       AudioStreamPlayer = $AudioPop
@onready var audio_acender:   AudioStreamPlayer = $AudioAcender

func _ready():
	hide()
	set_process(false)
	# Controle: cursor nesta tela e as teclas dos textos viram botões. Os textos
	# moram na cena, com as marcas {ui_cancel}/{interact} (ver BotoesControle).
	add_to_group(CursorVirtual.GRUPO)
	Controle.rotular($RootControl/Instrucoes, $RootControl/Instrucoes.text)
	Controle.rotular(label_liberar_acesso, label_liberar_acesso.text)
	# Mesma folha de átomos e moléculas do puzzle do maçarico (ver
	# scripts/ui/folha_moleculas.gd).
	textura_h2 = FolhaMoleculas.textura("H2")
	textura_o2 = FolhaMoleculas.textura("O2")
	textura_h2o = FolhaMoleculas.textura("H2O")

	# A arte do cilindro vem recortada rente ao desenho; a silhueta precisa de
	# folga em volta para o contorno não ser cortado na borda do retângulo.
	for id in ITENS:
		var arte := _arte(id)
		arte.texture = _com_folga(arte.texture, FOLGA_SILHUETA)
		arte.size = arte.texture.get_size() * ESCALA_CILINDRO
		arte.position = -arte.size * 0.5
		arte.pivot_offset = arte.size * 0.5
		# A vaga no foguete usa a mesma arte com folga, na escala do cilindro
		# desenhado na planta, centrada em cima dele.
		var vaga := _vaga(id)
		vaga.texture = arte.texture
		vaga.size = vaga.texture.get_size() * ESCALA_VAGA
		# +1 texel: o desenho do cilindro não é centrado no próprio recorte.
		vaga.position = CENTRO_VAGA[id] - vaga.size * 0.5 + Vector2.ONE * ESCALA_VAGA
		vaga.pivot_offset = vaga.size * 0.5
	_apagar_cilindros_da_planta()

	_pos_tubo_base = tubo.position
	_normalizar_tamanho_da_tela()
	# O retângulo da mochila e a etiqueta dele só servem para posicionar no
	# editor.
	area_mochila.get_node("Etiqueta").hide()

	var brilho_aditivo := CanvasItemMaterial.new()
	brilho_aditivo.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	luz_tubo.material = brilho_aditivo
	luz_tubo.draw.connect(_desenhar_luz_tubo)
	guia.draw.connect(_desenhar_guia)
	# As setas só existem em jogo (são desenhadas na hora); esconder o nó no
	# editor para enxergar a cena não pode apagá-las do puzzle.
	guia.show()

func abrir_puzzle():
	_sessao += 1
	show()
	Interacao.marcar_tela_aberta(self, true)
	set_process(true)
	_resetar()

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = false
	get_tree().paused = true

	_ligar_tela()
	_emprestar_mochila()

func fechar_puzzle(resolvido: bool):
	_sessao += 1
	hide()
	Interacao.marcar_tela_aberta(self, false)
	set_process(false)
	_largar_tudo()
	_matar_tweens()
	fogo.emitting = false
	cabo.parar()
	audio_sucesso.stop()
	audio_erro.stop()
	audio_colocar.stop()
	audio_ignicao.stop()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	get_tree().paused = false
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = true

	if resolvido:
		audio_sucesso.play()
		# É aqui que o receptor consome os cilindros do inventário.
		puzzle_resolvido.emit()

	# O que continuou só retirado (puzzle abandonado, ou receptor que não
	# consome) volta para o alvéolo de onde saiu.
	if _mochila != null and is_instance_valid(_mochila):
		_mochila.foco = -1
		_esmaecer_mochila(1.0)
		for id in ITENS:
			if _mochila.esta_retirado(id):
				_mochila.devolver(id)
	if _hud != null and is_instance_valid(_hud):
		_hud.devolver_mochila()
	_hud = null
	_mochila = null

func _resetar():
	_matar_tweens()
	_largar_tudo()
	etapa        = Etapa.COLETA
	travado      = false
	_em_transicao = false
	aguardando_fechamento = false
	mostrando_dialogo_cientista = false
	coeficientes = [0, 0, 0]
	tocado       = [false, false, false]
	_tempo       = 0.0
	_luz_tubo    = 0.0
	_clarao_tubo = 0.0
	_passo       = -1
	_botao_do_passo = null
	destaque.limpar(true)
	if _tween_prompt_acesso:
		_tween_prompt_acesso.kill()
		_tween_prompt_acesso = null

	var faltando: Array = []
	for id in ITENS:
		_inseridos[id] = false
		_acesos[id] = false
		_instalados[id] = false
		var tem := Inventario.tem_item(id)
		if not tem:
			faltando.append(id)
		_resetar_cartao(id, tem)

	display.scale = Vector2.ONE
	display.modulate = Color.WHITE
	cabecalho.text = "> RECEPTOR DE COMBUSTÍVEL"
	cabecalho.modulate = Color.WHITE
	rodape.modulate = Color.WHITE
	match faltando.size():
		0:
			_definir_rodape(TXT_RODAPE_COLETA, true)
		2:
			_definir_rodape(TXT_RODAPE_FALTAM_OS_DOIS, true)
		_:
			_definir_rodape(TXT_RODAPE_FALTA_H2 if faltando[0] == ITEM_H2 else TXT_RODAPE_FALTA_O2, true)

	grupo_montagem.hide()
	grupo_montagem.modulate = Color.WHITE
	foguete.position = FOGUETE_POS_MONTAGEM
	foguete.scale = Vector2.ONE * FOGUETE_ESCALA_MONTAGEM
	fogo.emitting = false
	for id in ITENS:
		var vaga := _vaga(id)
		vaga.show()
		vaga.scale = Vector2.ONE
		(vaga.material as ShaderMaterial).set_shader_parameter("aceso", 0.0)
		(vaga.material as ShaderMaterial).set_shader_parameter("clarao", 0.0)
		_rotulo_vaga(id).modulate.a = 1.0

	grupo_equacao.hide()
	grupo_equacao.modulate = Color.WHITE
	painel_equacao.position = Vector2.ZERO
	painel_equacao.scale = Vector2.ONE
	linha_dica_ignicao.hide()
	botao_ignicao.show()
	_atualizar_equacao()

	grupo_ignicao.hide()
	grupo_ignicao.modulate = Color.WHITE
	label_liberar_acesso.hide()
	label_liberar_acesso.scale = Vector2.ONE
	label_liberar_acesso.modulate = Color(1, 1, 1, 1)
	# O brilho da tela (o tom esverdeado do vidro) fica aceso em todas as
	# etapas, não só na ignição.
	aura.modulate.a = 1.0
	led.color = COR_LED_TRAVADO

	tubo.position = _pos_tubo_base

func _resetar_cartao(id: String, tem_item: bool):
	var cartao := _cartao(id)
	cartao.show()
	cartao.position = POS_CARTAO_COLETA[id]
	cartao.scale = Vector2.ONE
	cartao.modulate = Color.WHITE
	var arte := _arte(id)
	arte.show()
	arte.position = -arte.size * 0.5
	arte.scale = Vector2.ONE
	var material := arte.material as ShaderMaterial
	material.set_shader_parameter("aceso", 0.0)
	material.set_shader_parameter("clarao", 0.0)
	material.set_shader_parameter("cor_acesa", EstiloHUD.cor_do_item(id))
	_pintar_formula(id, Color.WHITE)
	var status := _status(id)
	status.modulate = Color.WHITE
	if tem_item:
		status.text = "AGUARDANDO"
		status.add_theme_color_override("font_color", COR_STATUS_ESPERA)
	else:
		status.text = "NÃO ENCONTRADO"
		status.add_theme_color_override("font_color", COR_STATUS_AUSENTE)
	_piscando[id] = tem_item

# A tela "liga" como monitor de tubo: uma linha que abre na vertical.
func _ligar_tela():
	display.scale = Vector2(1.0, 0.02)
	display.modulate.a = 0.0
	var tween := _tween()
	tween.set_parallel(true)
	tween.tween_property(display, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(display, "modulate:a", 1.0, 0.16)

func _emprestar_mochila():
	var hud = Inventario.tela_hud_referencia
	if hud == null or not is_instance_valid(hud) or not hud.has_method("emprestar_mochila"):
		return
	_hud = hud
	_mochila = hud.emprestar_mochila(_area_mochila(), 0.55)

	# Quando ela chega, os cilindros piscam no alvéolo: "é isto que vai no tubo".
	var sessao := _sessao
	await get_tree().create_timer(0.55).timeout
	if sessao != _sessao or _mochila == null:
		return
	for id in ITENS:
		if _mochila.tem(id) and not _mochila.esta_retirado(id):
			_mochila.destacar(id)

func _process(delta: float):
	_tempo += delta
	if _mao:
		_mao.position = _ponteiro
	if _peca:
		_peca.global_position = _ponteiro - _offset_arrasto

	var sobre := 1.0 if (_mao != null and _sobre_tubo(_ponteiro)) else 0.0
	_luz_tubo = move_toward(_luz_tubo, sobre, delta * 7.0)
	_clarao_tubo = maxf(_clarao_tubo - delta * 2.2, 0.0)
	luz_tubo.queue_redraw()
	guia.queue_redraw()

	for id in ITENS:
		if _piscando.get(id, false):
			_status(id).modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_tempo * 4.0))

	if not travado:
		led.modulate.a = 1.0 if fmod(_tempo, 1.1) >= 0.5 else 0.55
	else:
		led.modulate.a = 1.0

	var cursor_visivel := _rodape_cursor and fmod(_tempo, 1.0) < 0.5
	var texto := _rodape_texto + ("_" if cursor_visivel else "")
	if rodape.text != texto:
		rodape.text = texto

func _input(event: InputEvent):
	if not visible or mostrando_dialogo_cientista:
		return
	get_viewport().set_input_as_handled()
	# A tela está por cima de tudo: o E que fecha o puzzle não pode sobrar para
	# o receptor que está logo atrás dela.
	if event.is_action_pressed(Interacao.ACAO):
		Interacao.consumir()
	if event is InputEventMouse:
		_ponteiro = event.position
	if event is InputEventMouseMotion:
		_atualizar_foco(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			match etapa:
				Etapa.COLETA:
					_pegar_da_mochila(event.position)
				Etapa.MONTAGEM:
					_pegar_peca(event.position)
				Etapa.BALANCEAMENTO:
					_clicar_fase2(event.position)
		elif _mao:
			_soltar_da_mochila(event.position)
		elif _peca:
			_soltar_peca(event.position)
		_atualizar_foco(event.position)
	if event is InputEventKey and event.pressed and event.keycode == KEY_L:
		# DEBUG: resolve o puzzle instantaneamente para agilizar testes
		fechar_puzzle(true)
		return
	if aguardando_fechamento and _pediu_fechar(event):
		fechar_puzzle(true)
	elif not travado and _pediu_sair(event):
		fechar_puzzle(false)

## ESC/E/ESPAÇO/ENTER no teclado; ○, □ e ✕ no controle (pelas ações do mapa).
func _pediu_fechar(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed \
			and event.keycode in [KEY_ESCAPE, KEY_E, KEY_SPACE, KEY_ENTER]:
		return true
	return event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") \
		or event.is_action_pressed(Interacao.ACAO)

## ESC no teclado; ○ no controle.
func _pediu_sair(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		return true
	return event.is_action_pressed("ui_cancel")

# ------------------------- CONTROLE (ver cursor_virtual.gd) -------------------------

## O que dá para pegar ou apertar em cada etapa; com algo na mão, onde soltar.
func alvos_do_cursor() -> Array[Rect2]:
	var alvos: Array[Rect2] = []
	if travado or _em_transicao:
		return alvos
	match etapa:
		Etapa.COLETA:
			if _mao != null:
				alvos.append(_boca_global())
			elif _mochila != null and is_instance_valid(_mochila):
				# O hexágono do alvéolo, na escala em que a mochila está agora.
				var lado := MochilaHUD.RAIO_CELULA * 1.6 * _mochila.get_global_transform().get_scale().x
				for i in MochilaHUD.CAPACIDADE:
					var centro := _mochila.centro_do_slot(i)
					if _mochila.slot_no_ponto(centro) == i:
						alvos.append(Rect2(centro - Vector2(lado, lado) * 0.5, Vector2(lado, lado)))
		Etapa.MONTAGEM:
			if _peca != null:
				alvos.append(vaga_h2.get_global_rect())
				alvos.append(vaga_o2.get_global_rect())
			else:
				for id in ITENS:
					if not _instalados[id] and _arte(id).is_visible_in_tree():
						alvos.append(_arte(id).get_global_rect())
		Etapa.BALANCEAMENTO:
			if grupo_equacao.visible:
				for botao in [botao_mais_h2, botao_mais_o2, botao_mais_h2o,
						botao_menos_h2, botao_menos_o2, botao_menos_h2o, botao_ignicao]:
					# Num passo guiado só o botão pedido responde.
					if botao.visible and (_botao_do_passo == null or botao == _botao_do_passo):
						alvos.append(_retangulo_do_botao(botao))
	return alvos

func dicas_do_controle() -> Array:
	if aguardando_fechamento:
		return [[Interacao.ACAO, "LIBERAR O ACESSO"]]
	var dicas: Array = [["analogico_esquerdo", "MOVER"], ["direcional", "ESCOLHER"]]
	match etapa:
		Etapa.COLETA:
			dicas.append(["cruz", "SOLTE NO TUBO" if _mao != null else "SEGURE PARA ARRASTAR"])
		Etapa.MONTAGEM:
			dicas.append(["cruz", "SOLTE NO ENCAIXE" if _peca != null else "SEGURE PARA ARRASTAR"])
		_:
			dicas.append(["cruz", "APERTAR"])
	if not travado:
		dicas.append(["ui_cancel", "SAIR"])
	return dicas

# Cursor de mão sobre o que dá para pegar/clicar; o alvéolo da mochila acende.
func _atualizar_foco(pos: Vector2):
	var mao_livre := _mao == null and _peca == null
	var cursor := Input.CURSOR_ARROW
	var foco := -1
	if not mao_livre:
		cursor = Input.CURSOR_DRAG
	elif etapa == Etapa.COLETA and _mochila != null:
		foco = _mochila.slot_no_ponto(pos)
		if foco >= 0:
			cursor = Input.CURSOR_POINTING_HAND
	elif etapa == Etapa.MONTAGEM and not _em_transicao and _peca_no_ponto(pos) != "":
		cursor = Input.CURSOR_POINTING_HAND
	elif etapa == Etapa.BALANCEAMENTO and _botao_fase2_no_ponto(pos) != null:
		cursor = Input.CURSOR_POINTING_HAND
	if _mochila != null:
		_mochila.foco = foco
	Input.set_default_cursor_shape(cursor)

# ------------------------- ETAPA 1: COLETA (MOCHILA -> TUBO) -------------------------

func _pegar_da_mochila(pos: Vector2):
	if _mochila == null or _mao != null:
		return
	var indice := _mochila.slot_no_ponto(pos)
	if indice < 0:
		return
	var dados := _mochila.dados_do_slot(indice)
	if dados.is_empty() or dados["textura"] == null:
		return
	_mao_id = dados["id"]
	_mao = ItemArrastado.criar(camada_arrasto, dados["textura"], dados["cor"], pos,
		CAIXA_MAO * _mochila.get_global_transform().get_scale().x)
	_mao.scale = Vector2(0.7, 0.7)
	var tween := _tween()
	tween.tween_property(_mao, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_mochila.retirar(_mao_id)
	_mochila.foco = -1
	audio_drag.play()

func _soltar_da_mochila(pos: Vector2):
	var mao := _mao
	var id := _mao_id
	_mao = null
	_mao_id = ""
	if not _sobre_tubo(pos):
		_devolver_a_mochila(mao, id)
		_tocar_som_solto()
		return
	if id in ITENS and not _inseridos[id]:
		_entregar_no_tubo(mao, id)
	else:
		_recusar_no_tubo(mao, id)

func _entregar_no_tubo(mao: ItemArrastado, id: String):
	_inseridos[id] = true
	_piscando[id] = false
	var sessao := _sessao
	var cor := EstiloHUD.cor_do_item(id)
	audio_pop.play()

	# O item afunda na câmara: vai para o fundo, encolhe e escurece.
	var tween := _tween()
	tween.set_parallel(true)
	tween.tween_property(mao, "position", _ponto_do_tubo(FUNDO_TUBO), 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(mao, "scale", Vector2(0.3, 0.3), 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(mao, "modulate", Color(0.3, 0.3, 0.4, 0.0), 0.3) \
		.set_ease(Tween.EASE_IN)
	await tween.finished
	if is_instance_valid(mao):
		mao.queue_free()
	if sessao != _sessao:
		return

	_clarao_tubo = 1.0
	_cor_clarao_tubo = cor
	_status(id).text = "LENDO..."
	await cabo.pulsar(cor)
	if sessao != _sessao:
		return
	await _acender_vaga(id)
	if sessao != _sessao:
		return
	if etapa == Etapa.COLETA and _acesos.values().all(func(aceso): return aceso):
		_ir_para_montagem()

func _acender_vaga(id: String):
	var arte := _arte(id)
	var material := arte.material as ShaderMaterial
	var cor := EstiloHUD.cor_do_item(id)
	audio_acender.play()

	var status := _status(id)
	status.text = "RECEBIDO"
	status.add_theme_color_override("font_color", cor)
	status.modulate.a = 1.0
	_pintar_formula(id, cor)

	var pop := _tween()
	pop.tween_property(arte, "scale", Vector2(1.1, 1.1), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(arte, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var enche := _tween()
	enche.tween_property(material, "shader_parameter/aceso", 1.0, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	enche.tween_property(material, "shader_parameter/clarao", 0.85, 0.05)
	enche.tween_property(material, "shader_parameter/clarao", 0.0, 0.3)
	await enche.finished
	_acesos[id] = true

func _recusar_no_tubo(mao: ItemArrastado, id: String):
	audio_erro.play()
	_clarao_tubo = 1.0
	_cor_clarao_tubo = COR_ERRO
	_tremer(tubo, _pos_tubo_base)
	_mostrar_aviso("ITEM INCOMPATÍVEL COM O RECEPTOR", COR_ERRO)
	_devolver_a_mochila(mao, id)

# O item volta voando para o alvéolo e só então reaparece lá.
func _devolver_a_mochila(mao: ItemArrastado, id: String):
	var sessao := _sessao
	if _mochila == null or _mochila.indice_de(id) < 0:
		mao.queue_free()
		return
	var destino := _mochila.centro_do_slot(_mochila.indice_de(id))
	var escala := _mochila.caixa_do_icone() / CAIXA_MAO
	var tween := _tween()
	tween.set_parallel(true)
	tween.tween_property(mao, "position", destino, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mao, "scale", Vector2(escala, escala), 0.22)
	await tween.finished
	if is_instance_valid(mao):
		mao.queue_free()
	if sessao == _sessao and _mochila != null:
		_mochila.devolver(id)

# ------------------------- ETAPA 2: MONTAGEM NO FOGUETE -------------------------

func _ir_para_montagem():
	etapa = Etapa.MONTAGEM
	_em_transicao = true
	var sessao := _sessao
	_definir_rodape("CILINDROS RECEBIDOS", false)
	audio_colocar.play()
	# A mochila cumpriu o papel e apaga. Ela só volta para o canto quando o
	# puzzle fecha: lá em cima ela ficaria por cima da tela do computador.
	_esmaecer_mochila(ALFA_MOCHILA_USADA)

	await get_tree().create_timer(0.5).timeout
	if sessao != _sessao:
		return

	cabecalho.text = "> PLANTA DO FOGUETE"
	var move := _tween()
	move.set_parallel(true)
	for id in ITENS:
		var cartao := _cartao(id)
		move.tween_property(cartao, "position", POS_CARTAO_MONTAGEM[id], 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		move.tween_property(cartao, "scale", Vector2.ONE * ESCALA_CARTAO_MONTAGEM, 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		move.tween_property(_status(id), "modulate:a", 0.0, 0.25)

	grupo_montagem.show()
	grupo_montagem.modulate.a = 0.0
	foguete.position = FOGUETE_POS_MONTAGEM + Vector2(40, 0)
	move.tween_property(grupo_montagem, "modulate:a", 1.0, 0.35).set_delay(0.25)
	move.tween_property(foguete, "position", FOGUETE_POS_MONTAGEM, 0.45).set_delay(0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await move.finished
	if sessao != _sessao:
		return
	_definir_rodape("INSTALE CADA CILINDRO NO SEU ENCAIXE", true)
	_em_transicao = false

func _pegar_peca(pos: Vector2):
	if _em_transicao or _peca != null:
		return
	var id := _peca_no_ponto(pos)
	if id == "":
		return
	_peca = _arte(id)
	_peca_id = id
	_offset_arrasto = pos - _peca.global_position
	# O cartão arrastado passa por cima do outro.
	var cartao := _cartao(id)
	display.move_child(cartao, maxi(cartao_h2.get_index(), cartao_o2.get_index()))
	audio_drag.play()

func _peca_no_ponto(pos: Vector2) -> String:
	for id in ITENS:
		if _instalados[id]:
			continue
		var arte := _arte(id)
		if arte.is_visible_in_tree() and arte.get_global_rect().has_point(pos):
			return id
	return ""

func _soltar_peca(pos: Vector2):
	var peca := _peca
	var id := _peca_id
	_peca = null
	_peca_id = ""

	var vaga_certa := _vaga(id)
	var vaga_errada := _vaga(ITEM_O2 if id == ITEM_H2 else ITEM_H2)
	if vaga_certa.get_global_rect().grow(24).has_point(pos):
		_instalar(id)
	elif vaga_errada.get_global_rect().grow(24).has_point(pos):
		# Encaixe errado: o hidrogênio vai no encaixe de cima
		audio_erro.play()
		_mostrar_aviso("ENCAIXE ERRADO PARA ESTE CILINDRO", COR_ERRO)
		_rejeitar(peca, -peca.size * 0.5)
	else:
		_animar_para(peca, -peca.size * 0.5)
		_tocar_som_solto()

func _instalar(id: String):
	_instalados[id] = true
	_arte(id).hide()
	_pintar_formula(id, EstiloHUD.com_alfa(EstiloHUD.cor_do_item(id), 0.35))
	audio_colocar.play()
	# A sombra do encaixe enche com o cilindro, de baixo para cima, e o
	# contorno branco vira o traço preto do resto da planta: o cilindro passa
	# a fazer parte do desenho do foguete.
	var vaga := _vaga(id)
	var material := vaga.material as ShaderMaterial
	var enche := _tween()
	enche.tween_property(material, "shader_parameter/aceso", 1.0, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	enche.tween_property(material, "shader_parameter/clarao", 0.8, 0.05)
	enche.tween_property(material, "shader_parameter/clarao", 0.0, 0.3)
	# O nome do compartimento some: o cilindro colorido já diz o que é.
	_tween().tween_property(_rotulo_vaga(id), "modulate:a", 0.0, 0.3)
	var pop := _tween()
	pop.tween_property(vaga, "scale", Vector2(1.12, 1.12), 0.1) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(vaga, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if _instalados.values().all(func(feito): return feito):
		_ir_para_fase2()

# Som de "soltar" genérico (reaproveita o som de drag), usado quando nenhum
# outro som (colocar, erro, sucesso...) já está tocando para esse solte.
func _tocar_som_solto() -> void:
	if not (audio_colocar.playing or audio_erro.playing or audio_sucesso.playing or audio_ignicao.playing):
		audio_drag.play()

# ------------------------- ETAPA 3: BALANCEAMENTO -------------------------

func _ir_para_fase2():
	etapa = Etapa.BALANCEAMENTO
	_em_transicao = true
	var sessao := _sessao
	_definir_rodape("CILINDROS INSTALADOS", false)
	await get_tree().create_timer(0.8).timeout
	if sessao != _sessao:
		return

	# Some tudo o que era da montagem: a tela inteira passa a ser da equação.
	var sai := _tween()
	sai.set_parallel(true)
	for no in [grupo_montagem, cartao_h2, cartao_o2, cabecalho, rodape]:
		sai.tween_property(no, "modulate:a", 0.0, 0.3)
	await sai.finished
	if sessao != _sessao:
		return
	grupo_montagem.hide()
	cartao_h2.hide()
	cartao_o2.hide()

	grupo_equacao.show()
	painel_equacao.pivot_offset = painel_equacao.size / 2.0
	painel_equacao.scale = Vector2(0.7, 0.7)
	var entra := _tween()
	entra.set_trans(Tween.TRANS_BACK)
	entra.set_ease(Tween.EASE_OUT)
	entra.tween_property(painel_equacao, "scale", Vector2.ONE, 0.35)
	_atualizar_equacao()

	await entra.finished
	if sessao != _sessao:
		return
	_em_transicao = false
	_executar_passo(0)

func _clicar_fase2(mouse_pos: Vector2):
	if travado or _em_transicao or not grupo_equacao.visible:
		return
	var botao := _botao_fase2_no_ponto(mouse_pos)
	if botao == null:
		# Clique fora do botão pedido num passo guiado: a seta chama de volta.
		if _botao_do_passo != null:
			destaque.cutucar()
		return
	if botao == botao_ignicao:
		_verificar_equacao()
		return
	var mais := [botao_mais_h2, botao_mais_o2, botao_mais_h2o]
	var menos := [botao_menos_h2, botao_menos_o2, botao_menos_h2o]
	if botao in mais:
		_alterar_coeficiente(mais.find(botao), 1, botao)
	else:
		_alterar_coeficiente(menos.find(botao), -1, botao)

## Botão da equação sob o ponto. Num passo guiado só o botão pedido conta —
## os outros nem mostram a mãozinha do cursor.
func _botao_fase2_no_ponto(pos: Vector2) -> Control:
	if travado or _em_transicao or not grupo_equacao.visible:
		return null
	for botao in [botao_mais_h2, botao_mais_o2, botao_mais_h2o,
			botao_menos_h2, botao_menos_o2, botao_menos_h2o, botao_ignicao]:
		if botao.visible and _retangulo_do_botao(botao).has_point(pos):
			if _botao_do_passo != null and botao != _botao_do_passo:
				return null
			return botao
	return null

func _alterar_coeficiente(i: int, delta: int, alvo_pop: Control):
	var atual = coeficientes[i] + delta
	if atual > COEF_MAX:
		atual = 0
	elif atual < 0:
		atual = COEF_MAX
	coeficientes[i] = atual
	tocado[i] = true
	_pop(alvo_pop)
	_tocar_seta(alvo_pop)
	_atualizar_equacao(i)
	_conferir_roteiro()

func _tocar_seta(botao: Control) -> void:
	var seta = botao.get_node_or_null("LabelBotao")
	if seta and seta is AnimatedSprite2D:
		seta.frame = 0
		seta.play("default")

# 'index_alterado' indica qual coeficiente mudou (0=H2, 1=O2, 2=H2O), para que
# o pop de entrada das moléculas apareça só no conjunto que realmente mudou.
# -1 (padrão) reconstrói os três conjuntos, usado na abertura da fase 2.
func _atualizar_equacao(index_alterado: int = -1):
	if index_alterado == -1 or index_alterado == 0:
		_popular_moleculas(moleculas_h2, "h2", coeficientes[0])
	if index_alterado == -1 or index_alterado == 1:
		_popular_moleculas(moleculas_o2, "o2", coeficientes[1])
	if index_alterado == -1 or index_alterado == 2:
		_popular_moleculas(moleculas_h2o, "h2o", coeficientes[2])

	var coef_h2_txt  = str(coeficientes[0]) if tocado[0] else "?"
	var coef_o2_txt  = str(coeficientes[1]) if tocado[1] else "?"
	var coef_h2o_txt = str(coeficientes[2]) if tocado[2] else "?"

	# Contagem de átomos em cada lado da equação
	var reag_h = 2 * coeficientes[0]
	var reag_o = 2 * coeficientes[1]
	var prod_h = 2 * coeficientes[2]
	var prod_o = coeficientes[2]

	var amarelo := Color(1, 0.85, 0)
	# H e O ficam verdes de forma independente: cada um só depende de bater
	# a contagem dos dois lados, mesmo que o outro elemento ainda esteja errado.
	var h_bate = tocado[0] and tocado[2] and reag_h == prod_h
	var o_bate = tocado[1] and tocado[2] and reag_o == prod_o
	var cor_h = Color.GREEN if h_bate else amarelo
	var cor_o = Color.GREEN if o_bate else amarelo

	var reag_h_txt = str(reag_h) if tocado[0] else "?"
	var reag_o_txt = str(reag_o) if tocado[1] else "?"
	var prod_h_txt = str(prod_h) if tocado[2] else "?"
	var prod_o_txt = str(prod_o) if tocado[2] else "?"

	label_reagentes_valor.text = _bbcode_valor_atomos(
		reag_h_txt, cor_h,
		reag_o_txt, cor_o,
	)
	label_produtos_valor.text = _bbcode_valor_atomos(
		prod_h_txt, cor_h,
		prod_o_txt, cor_o,
	)

	var todos_definidos = tocado.all(func(t): return t)
	var cor := amarelo
	if todos_definidos:
		cor = Color.GREEN if (reag_h == prod_h and reag_o == prod_o) else Color(1, 0.35, 0.3)
	_reconstruir_equacao_escrita(coef_h2_txt, coef_o2_txt, coef_h2o_txt, cor)
	label_reagentes_titulo.add_theme_color_override("font_color", cor)
	label_produtos_titulo.add_theme_color_override("font_color", cor)

func _bbcode_valor_atomos(h_txt: String, cor_h: Color, o_txt: String, cor_o: Color) -> String:
	return "[color=#%s]H = %s[/color]    [color=#%s]O = %s[/color]" % [
		cor_h.to_html(false), h_txt, cor_o.to_html(false), o_txt,
	]

# Monta "N H2 + N O2 -> N H2O + ENERGIA" com os números "2" em subscrito de verdade
# (menores e rebaixados), já que o BBCode do RichTextLabel não tem tag de subscrito.
func _reconstruir_equacao_escrita(coef_h2_txt: String, coef_o2_txt: String, coef_h2o_txt: String, cor: Color):
	for filho in linha_equacao.get_children():
		filho.free()
	_add_texto_sub(linha_equacao, coef_h2_txt + " H", false, cor, 33, 11)
	_add_texto_sub(linha_equacao, "2", true, cor, 33, 11)
	_add_texto_sub(linha_equacao, "  +  " + coef_o2_txt + " O", false, cor, 33, 11)
	_add_texto_sub(linha_equacao, "2", true, cor, 33, 11)
	_add_texto_sub(linha_equacao, "   →   " + coef_h2o_txt + " H", false, cor, 33, 11)
	_add_texto_sub(linha_equacao, "2", true, cor, 33, 11)
	_add_texto_sub(linha_equacao, "O  +  ENERGIA", false, cor, 33, 11)

func _add_texto_sub(container: Control, texto: String, subscrito: bool, cor: Color, tamanho_normal: int, tamanho_sub: int):
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_theme_font_override("font", FONTE_EQUACAO)
	lbl.add_theme_font_size_override("font_size", tamanho_sub if subscrito else tamanho_normal)
	lbl.add_theme_color_override("font_color", cor)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_END if subscrito else Control.SIZE_SHRINK_CENTER
	container.add_child(lbl)

func _verificar_equacao():
	if coeficientes.has(0):
		audio_erro.play()
		_shake(botao_ignicao)
		return

	if coeficientes == COEF_CORRETO:
		_iniciar_ignicao()
		return

	# Balanceada quimicamente (H e O batem dos dois lados), mas não está
	# representada com os menores números inteiros possíveis (ex.: 4/2/4).
	var balanceada = (2 * coeficientes[0] == 2 * coeficientes[2]) \
		and (2 * coeficientes[1] == coeficientes[2])
	if balanceada:
		_falar_cientista(TIMELINE_DICA_EQUACAO_DOBRADA)
		return

	audio_erro.play()
	_shake(painel_equacao)

# ------------------------- ROTEIRO DO CIENTISTA -------------------------

func _executar_passo(indice: int):
	if indice < 0 or indice >= ROTEIRO.size():
		return
	var sessao := _sessao
	var passo: Dictionary = ROTEIRO[indice]
	_passo = indice
	_botao_do_passo = null
	_em_transicao = true

	# Depois de um clique certo, a tela fica livre por um instante: é quando as
	# moléculas pulam e a contagem muda — exatamente o que ele vai comentar.
	if indice > 0:
		destaque.limpar()
		await get_tree().create_timer(PAUSA_ENTRE_PASSOS).timeout
		if sessao != _sessao:
			return

	# O holofote acende ANTES da fala, para a pessoa já estar olhando para o
	# lugar certo quando o texto chegar nele.
	destaque.focar(_retangulos_para(passo["mostrar"]), false, _retangulos_para(passo["enfase"]))
	await get_tree().create_timer(0.3).timeout
	if sessao != _sessao:
		return
	await _falar_cientista(PASTA_FALAS + passo["fala"] + ".dtl")
	if sessao != _sessao:
		return

	var botao := _botao_por_nome(passo["botao"])
	_botao_do_passo = botao
	if botao != null:
		destaque.focar([_retangulo_do_botao(botao)], true)
	else:
		destaque.limpar()
	_em_transicao = false

## Chamado a cada mudança de coeficiente: chegou na meta do passo, avança.
func _conferir_roteiro():
	if _passo < 0 or _passo >= ROTEIRO.size():
		return
	var meta: Array = ROTEIRO[_passo]["meta"]
	if meta.is_empty() or coeficientes != meta:
		return
	_executar_passo(_passo + 1)

func _botao_por_nome(nome: String) -> Control:
	match nome:
		"mais_h2":
			return botao_mais_h2
		"mais_o2":
			return botao_mais_o2
		"mais_h2o":
			return botao_mais_h2o
		"ignicao":
			return botao_ignicao
	return null

func _retangulos_para(nomes: Array) -> Array[Rect2]:
	var saida: Array[Rect2] = []
	for nome in nomes:
		match nome:
			"reagentes":
				saida.append(_retangulo_do_painel(label_reagentes_titulo, label_reagentes_valor))
			"produtos":
				saida.append(_retangulo_do_painel(label_produtos_titulo, label_produtos_valor))
			"reagentes_h":
				saida.append(_retangulo_da_contagem(label_reagentes_valor, "H"))
			"reagentes_o":
				saida.append(_retangulo_da_contagem(label_reagentes_valor, "O"))
			"produtos_h":
				saida.append(_retangulo_da_contagem(label_produtos_valor, "H"))
			"produtos_o":
				saida.append(_retangulo_da_contagem(label_produtos_valor, "O"))
	return saida

# Só o pedaço "H = x" ou "O = y" do valor de um painel. O texto é centrado no
# RichTextLabel, então a posição sai da largura medida de cada pedaço com a
# própria fonte do label.
func _retangulo_da_contagem(valor: RichTextLabel, elemento: String) -> Rect2:
	var texto := valor.get_parsed_text()
	var fonte := valor.get_theme_font("normal_font")
	var tamanho := valor.get_theme_font_size("normal_font_size")
	var medir := func(trecho: String) -> float:
		return fonte.get_string_size(trecho, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
	var inicio := texto.find(elemento + " =")
	if inicio < 0:
		return _retangulo_do_painel(label_reagentes_titulo, valor)
	var fim := texto.find(" ", texto.find("=", inicio) + 2)
	if fim < 0:
		fim = texto.length()
	var largura_total: float = medir.call(texto)
	var x0: float = medir.call(texto.substr(0, inicio))
	var largura: float = medir.call(texto.substr(inicio, fim - inicio))

	var caixa := valor.get_global_rect()
	var escala := valor.get_global_transform().get_scale()
	var esquerda := caixa.get_center().x - largura_total * escala.x * 0.5 + x0 * escala.x
	var folga := Vector2(10.0, 4.0) * escala
	return Rect2(esquerda - folga.x, caixa.position.y - folga.y,
		largura * escala.x + folga.x * 2.0, float(tamanho) * 1.25 * escala.y + folga.y * 2.0)

# O painel de contagem, justo em volta do TEXTO (título + "H = x  O = y"). As
# caixas dos Labels são bem mais largas que o texto, e as de Reagentes e
# Produtos encostam uma na outra: medir pela caixa juntaria os dois destaques.
func _retangulo_do_painel(titulo: Label, valor: RichTextLabel) -> Rect2:
	var fonte := titulo.get_theme_font("font")
	var largura_titulo := fonte.get_string_size(titulo.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		titulo.get_theme_font_size("font_size")).x
	var largura := maxf(largura_titulo, float(valor.get_content_width())) + 36.0
	var caixa_titulo := titulo.get_global_rect()
	var caixa_valor := valor.get_global_rect()
	var escala := titulo.get_global_transform().get_scale().x
	var centro_x := caixa_titulo.get_center().x
	var topo := caixa_titulo.position.y - 8.0 * escala
	var base := caixa_valor.end.y + 10.0 * escala
	return Rect2(centro_x - largura * escala * 0.5, topo, largura * escala, base - topo)

# Área clicável e destacável de um botão da equação. Os de seta são um Panel
# pequeno com o sprite da seta (2x) saindo por cima e por baixo dele: a área
# acompanha o desenho, não o Panel.
func _retangulo_do_botao(botao: Control) -> Rect2:
	var caixa := botao.get_global_rect()
	if botao == botao_ignicao:
		return caixa.grow(6.0 * botao.get_global_transform().get_scale().x)
	var escala := botao.get_global_transform().get_scale()
	return caixa.grow_individual(6.0 * escala.x, 15.0 * escala.y, 6.0 * escala.x, 15.0 * escala.y)

## Fala do cientista. É uma corrotina: "await _falar_cientista(...)" volta
## quando a pessoa termina de ler.
func _falar_cientista(timeline: String) -> void:
	mostrando_dialogo_cientista = true
	# O cientista entra no canto esquerdo, onde está a mochila — e a mochila
	# mora numa camada acima do Dialogic. Ela some durante a fala.
	_esmaecer_mochila(0.0)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	# Faz o autoload do Dialogic (e seus subsistemas) processar mesmo com a
	# árvore pausada, para o world1 continuar pausado durante a fala em vez
	# de despausar tudo (como era feito antes com 'get_tree().paused = false').
	Dialogic.process_mode = Node.PROCESS_MODE_ALWAYS
	Dialogic.timeline_ended.connect(_on_fala_cientista_terminou, CONNECT_ONE_SHOT)
	var comecou := [false]
	var ao_comecar := func() -> void: comecou[0] = true
	Dialogic.timeline_started.connect(ao_comecar, CONNECT_ONE_SHOT)
	var layout_dialogic = Dialogic.start(timeline)
	if layout_dialogic:
		# O puzzle desenha no CanvasLayer 10 — sem isso o diálogo (layer padrão 1)
		# fica escondido atrás dele e os cliques nem chegam a avançar a fala.
		layout_dialogic.set("layer", 20)
		layout_dialogic.process_mode = Node.PROCESS_MODE_ALWAYS

	# Rede de segurança: fala que não carregou (arquivo renomeado, erro de
	# sintaxe) não emite timeline_ended nunca — e o roteiro ficaria travado
	# esperando. O Dialogic só avisa no console, então a checagem é aqui.
	for i in 3:
		await get_tree().process_frame
	if Dialogic.timeline_started.is_connected(ao_comecar):
		Dialogic.timeline_started.disconnect(ao_comecar)
	if mostrando_dialogo_cientista and not comecou[0]:
		push_warning("Fala do cientista não carregou: %s" % timeline)
		Dialogic.end_timeline(true)

	while mostrando_dialogo_cientista:
		await get_tree().process_frame

func _on_fala_cientista_terminou():
	_esmaecer_mochila(ALFA_MOCHILA_USADA)
	mostrando_dialogo_cientista = false

# ------------------------- ETAPA 4: IGNIÇÃO -------------------------

func _iniciar_ignicao():
	travado = true
	etapa = Etapa.IGNICAO
	var sessao := _sessao
	botao_ignicao.hide()
	_botao_do_passo = null
	_passo = ROTEIRO.size()
	destaque.limpar()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_reconstruir_equacao_escrita(str(COEF_CORRETO[0]), str(COEF_CORRETO[1]), str(COEF_CORRETO[2]), Color.GREEN)

	await get_tree().create_timer(1.0).timeout
	if sessao != _sessao:
		return

	# A equação sai e o foguete, já abastecido, volta para a tela.
	var sai := _tween()
	sai.tween_property(grupo_equacao, "modulate:a", 0.0, 0.3)
	await sai.finished
	if sessao != _sessao:
		return
	grupo_equacao.hide()

	cabecalho.text = "> SEQUÊNCIA DE IGNIÇÃO"
	_pos_foguete_base = FOGUETE_POS_IGNICAO
	foguete.position = _pos_foguete_base
	foguete.scale = Vector2.ONE * FOGUETE_ESCALA_IGNICAO
	grupo_montagem.show()
	grupo_ignicao.show()
	grupo_ignicao.modulate.a = 0.0
	var entra := _tween()
	entra.set_parallel(true)
	for no in [grupo_montagem, grupo_ignicao, cabecalho]:
		entra.tween_property(no, "modulate:a", 1.0, 0.3)
	led.color = COR_LED_LIBERADO

	fogo.emitting = true
	audio_ignicao.play()
	_tremer_foguete()

	await get_tree().create_timer(2.9).timeout
	if sessao != _sessao:
		return
	aguardando_fechamento = true
	_mostrar_prompt_liberar_acesso()

func _mostrar_prompt_liberar_acesso():
	label_liberar_acesso.pivot_offset = label_liberar_acesso.size / 2.0
	label_liberar_acesso.modulate = Color(1, 1, 1, 0)
	label_liberar_acesso.scale = Vector2(0.6, 0.6)
	label_liberar_acesso.show()

	if _tween_prompt_acesso:
		_tween_prompt_acesso.kill()

	var entrada := _tween()
	entrada.set_parallel(true)
	entrada.tween_property(label_liberar_acesso, "modulate:a", 1.0, 0.35)
	entrada.tween_property(label_liberar_acesso, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrada.chain().tween_callback(_iniciar_pulso_prompt_acesso)

func _iniciar_pulso_prompt_acesso():
	_tween_prompt_acesso = _tween()
	_tween_prompt_acesso.set_loops()
	_tween_prompt_acesso.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_prompt_acesso.tween_property(label_liberar_acesso, "scale", Vector2(1.07, 1.07), 0.55)
	_tween_prompt_acesso.tween_property(label_liberar_acesso, "scale", Vector2.ONE, 0.55)

func _tremer_foguete():
	var tween = _tween()
	tween.set_trans(Tween.TRANS_SINE)
	for i in range(16):
		var deslocamento = Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 1.0))
		tween.tween_property(foguete, "position", _pos_foguete_base + deslocamento, 0.06)
	tween.tween_property(foguete, "position", _pos_foguete_base, 0.06)

# ------------------------- MOLÉCULAS DA EQUAÇÃO -------------------------

func _criar_molecula(parent: Control, pos: Vector2, tamanho: Vector2, textura: Texture2D, index: int = 0):
	var sprite := TextureRect.new()
	sprite.texture = textura
	sprite.position = pos
	sprite.size = tamanho
	sprite.pivot_offset = tamanho / 2.0
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.scale = Vector2.ZERO
	sprite.rotation = deg_to_rad(randf_range(-6.0, 6.0))
	parent.add_child(sprite)

	# Pop elástico de entrada, em cascata (cada molécula entra um pouco depois da anterior)
	var tween_entrada := create_tween()
	tween_entrada.tween_interval(index * 0.03)
	tween_entrada.tween_callback(audio_pop.play)
	tween_entrada.tween_property(sprite, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Balancinho contínuo e sutil pra dar vida às moléculas depois que aparecem
	var duracao_bob := randf_range(0.55, 0.75)
	var tween_idle := create_tween()
	tween_idle.tween_interval(index * 0.03 + 0.35)
	tween_idle.set_loops()
	tween_idle.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_idle.tween_property(sprite, "position:y", pos.y - 3.0, duracao_bob)
	tween_idle.tween_property(sprite, "position:y", pos.y, duracao_bob)

func _popular_moleculas(container: Control, tipo: String, quantidade: int):
	for filho in container.get_children():
		filho.free()
	if quantidade <= 0:
		return

	var tamanho: Vector2 = Vector2(24.0, 20.0) if tipo == "h2o" else Vector2(18.0, 18.0)
	var textura: Texture2D = textura_h2
	match tipo:
		"o2":
			textura = textura_o2
		"h2o":
			textura = textura_h2o
	var gap := 16.0

	var colunas = 1 if quantidade == 1 else 2
	var linhas  = ceili(float(quantidade) / colunas)
	var tamanho_grade = Vector2(
		colunas * tamanho.x + (colunas - 1) * gap,
		linhas * tamanho.y + (linhas - 1) * gap
	)
	var origem_grade = (container.size - tamanho_grade) / 2.0

	for i in quantidade:
		var col = i % colunas
		@warning_ignore("integer_division")
		var row = i / colunas
		var origem = origem_grade + Vector2(col * (tamanho.x + gap), row * (tamanho.y + gap))
		_criar_molecula(container, origem, tamanho, textura, i)

# ------------------------- TUBO, GUIA E RODAPÉ -------------------------

# O tubo pode ser movido, redimensionado e escalado à vontade no editor: tudo
# o que é medido nele sai do texel do sprite, passa pelo tamanho do nó e depois
# pela transformação global (que já inclui "scale").
func _escala_tubo() -> Vector2:
	return tubo.size / Vector2(tubo.texture.get_size())

## Boca do tubo em coordenadas LOCAIS do nó Tubo (é onde a LuzTubo desenha).
func _boca_do_tubo() -> Rect2:
	var escala := _escala_tubo()
	return Rect2(BOCA_TUBO.position * escala, BOCA_TUBO.size * escala)

func _boca_global() -> Rect2:
	return tubo.get_global_transform() * _boca_do_tubo()

func _sobre_tubo(pos: Vector2) -> bool:
	return _boca_global().grow(FOLGA_SOLTAR).has_point(pos)

func _ponto_do_tubo(texel: Vector2) -> Vector2:
	return tubo.get_global_transform() * (texel * _escala_tubo())

## Centro da boca do tubo, na tela — onde o item deve ser solto.
func centro_da_boca() -> Vector2:
	return _boca_global().get_center()

# A Tela tem o miolo (Display, Led) montado em pixels do tamanho base. Se ela
# for redimensionada pelas alças no editor, o tamanho vira escala aqui — assim
# o conteúdo cresce junto em vez de ficar torto dentro da moldura.
func _normalizar_tamanho_da_tela():
	var ajuste := tela.size / TAMANHO_BASE_TELA
	if ajuste.is_equal_approx(Vector2.ONE):
		return
	tela.scale *= ajuste
	tela.size = TAMANHO_BASE_TELA

# O tween é da própria mochila, e não do puzzle: ele precisa sobreviver ao
# fechamento (que mata os tweens do puzzle) para ela reacender no caminho de
# volta ao canto.
func _esmaecer_mochila(alfa: float):
	if _mochila == null or not is_instance_valid(_mochila):
		return
	var tween := _mochila.create_tween()
	tween.tween_property(_mochila, "modulate:a", alfa, 0.35)

## Onde a mochila fica durante o puzzle: o retângulo AreaMochila da cena.
func _area_mochila() -> Rect2:
	return area_mochila.get_global_rect()

# Brilho na boca do tubo (desenhado em modo aditivo): contorno fraco que
# respira enquanto espera, acende na cor do item quando ele passa por cima e
# estoura num clarão quando algo entra (ou é recusado).
func _desenhar_luz_tubo():
	if not visible:
		return
	var boca := _boca_do_tubo()
	var esperando := etapa == Etapa.COLETA and not _inseridos.values().all(func(i): return i)
	var cor_mao := EstiloHUD.cor_do_item(_mao_id) if _mao != null else EstiloHUD.ACENTO_PADRAO
	if esperando:
		var alfa := 0.10 + 0.06 * sin(_tempo * 3.0)
		if _mao != null:
			alfa = 0.22 + 0.10 * sin(_tempo * 8.0)
		luz_tubo.draw_rect(boca.grow(-3.0), EstiloHUD.com_alfa(cor_mao, alfa + 0.45 * _luz_tubo),
			false, 2.0 + 2.0 * _luz_tubo)
	if _luz_tubo > 0.0:
		luz_tubo.draw_rect(boca, EstiloHUD.com_alfa(cor_mao, 0.12 * _luz_tubo), true)
	if _clarao_tubo > 0.0:
		luz_tubo.draw_rect(boca, EstiloHUD.com_alfa(_cor_clarao_tubo,
			0.5 * _clarao_tubo * _clarao_tubo), true)

# Setas da mochila até a boca do tubo: o caminho do arrasto. Várias setas
# marcham da base da mochila até a borda de cima da boca, sempre apontando
# para o tubo — seguem a reta entre as duas peças, então continuam certas onde
# quer que elas estejam na cena. Com um item na mão, elas ficam na cor dele.
func _desenhar_guia():
	if not visible or etapa != Etapa.COLETA or _mochila == null:
		return
	if _inseridos.values().all(func(i): return i):
		return
	# Aparece só depois que a mochila chegou.
	var entrada := clampf((_tempo - 0.5) / 0.3, 0.0, 1.0)
	if entrada <= 0.0:
		return
	var painel := _mochila.retangulo_do_painel()
	var boca := _boca_global()
	var ate := Vector2(boca.get_center().x, boca.position.y)
	# Boca embaixo da mochila: as setas descem RETAS na linha da boca (seta
	# inclinada por uns pixels de desalinho parece erro). Só quando as peças
	# estão de lado uma da outra é que a trilha vira diagonal.
	var de := Vector2(painel.get_center().x, painel.end.y)
	if ate.x > painel.position.x + 30.0 and ate.x < painel.end.x - 30.0:
		de.x = ate.x
	var distancia := de.distance_to(ate)
	if distancia < 40.0:
		return
	var direcao := (ate - de) / distancia
	var lado := direcao.orthogonal()
	# Folga nas duas pontas: a primeira seta não nasce grudada no painel e a
	# última para em cima da borda da boca.
	de += direcao * 16.0
	ate -= direcao * 4.0
	var percurso := de.distance_to(ate)

	var para_local := guia.get_global_transform().affine_inverse()
	var cor := EstiloHUD.cor_do_item(_mao_id) if _mao != null else EstiloHUD.TEXTO
	var abertura := 18.0
	var altura := 11.0
	var quantidade := clampi(int(percurso / 34.0), 2, 6)
	var ritmo := 0.9 if _mao == null else 1.6
	for k in quantidade:
		var fase := fmod(_tempo * ritmo + float(k) / quantidade, 1.0)
		var ponta := de.lerp(ate, fase)
		# Acende entrando, apaga chegando: o fluxo parece contínuo.
		var alfa := sin(fase * PI) * entrada
		var pontos := PackedVector2Array([
			para_local * (ponta - direcao * altura + lado * abertura),
			para_local * ponta,
			para_local * (ponta - direcao * altura - lado * abertura)])
		guia.draw_polyline(pontos, EstiloHUD.com_alfa(Color.BLACK, alfa * 0.7), 9.0, true)
		guia.draw_polyline(pontos, EstiloHUD.com_alfa(cor, alfa), 5.0, true)

func _definir_rodape(texto: String, com_cursor: bool):
	_rodape_texto = texto
	_rodape_padrao = texto
	_rodape_cursor = com_cursor
	rodape.remove_theme_color_override("font_color")

# Mensagem curta no rodapé da tela; depois volta ao texto da etapa.
func _mostrar_aviso(texto: String, cor: Color, duracao: float = 1.6):
	var sessao := _sessao
	var padrao := _rodape_padrao
	var cursor := _rodape_cursor
	_rodape_texto = texto
	_rodape_cursor = false
	rodape.add_theme_color_override("font_color", cor)
	await get_tree().create_timer(duracao).timeout
	if sessao != _sessao or _rodape_texto != texto:
		return
	_rodape_texto = padrao
	_rodape_cursor = cursor
	rodape.remove_theme_color_override("font_color")

# ------------------------- APOIO -------------------------

func _cartao(id: String) -> Control:
	return cartao_h2 if id == ITEM_H2 else cartao_o2

func _vaga(id: String) -> TextureRect:
	return vaga_h2 if id == ITEM_H2 else vaga_o2

## "COMBUSTÍVEL" / "COMBURENTE", escrito em pé ao longo do compartimento.
func _rotulo_vaga(id: String) -> Label:
	return foguete.get_node("RotuloH2" if id == ITEM_H2 else "RotuloO2") as Label

# A planta do foguete vem com os cilindros já desenhados. Eles são repintados
# com a cor do corpo (uma vez, ao carregar), para a vaga vazia mostrar só a
# sombra — e o cilindro "aparecer" quando é encaixado.
func _apagar_cilindros_da_planta():
	var arte := foguete.get_node("Arte") as TextureRect
	if arte.texture == null:
		return
	var imagem := arte.texture.get_image()
	if imagem == null or imagem.is_empty():
		return
	if imagem.is_compressed():
		imagem.decompress()
	imagem.convert(Image.FORMAT_RGBA8)
	for id in ITENS:
		imagem.fill_rect(DESENHO_CILINDRO[id], COR_CORPO_FOGUETE)
	arte.texture = ImageTexture.create_from_image(imagem)

func _arte(id: String) -> TextureRect:
	return _cartao(id).get_node("Arte") as TextureRect

func _status(id: String) -> Label:
	return _cartao(id).get_node("Status") as Label

func _pintar_formula(id: String, cor: Color):
	for label in _cartao(id).get_node("Formula").get_children():
		label.add_theme_color_override("font_color", cor)

# Copia a arte com "folga" texels transparentes em volta.
static func _com_folga(textura: Texture2D, folga: int) -> Texture2D:
	if textura == null:
		return textura
	var imagem := textura.get_image()
	if imagem == null or imagem.is_empty():
		return textura
	if imagem.is_compressed():
		imagem.decompress()
	imagem.convert(Image.FORMAT_RGBA8)
	var saida := Image.create(imagem.get_width() + folga * 2, imagem.get_height() + folga * 2,
		false, Image.FORMAT_RGBA8)
	saida.blit_rect(imagem, Rect2i(Vector2i.ZERO, imagem.get_size()), Vector2i(folga, folga))
	return ImageTexture.create_from_image(saida)

# Solta o que estiver na mão (sem animação) — usado ao fechar e reabrir.
func _largar_tudo():
	for filho in camada_arrasto.get_children():
		filho.queue_free()
	_mao = null
	_mao_id = ""
	if _peca != null:
		_peca.position = -_peca.size * 0.5
	_peca = null
	_peca_id = ""

func _tween() -> Tween:
	var tween := create_tween()
	_tweens.append(tween)
	if _tweens.size() > 48:
		_tweens = _tweens.filter(func(t): return is_instance_valid(t) and t.is_valid())
	return tween

func _matar_tweens():
	for tween in _tweens:
		if is_instance_valid(tween) and tween.is_valid():
			tween.kill()
	_tweens.clear()

func _animar_para(peca: Control, destino_local: Vector2):
	var tween = _tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(peca, "position", destino_local, 0.15)

func _rejeitar(peca: Control, destino_local: Vector2):
	var start = peca.position
	var tween = _tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(peca, "position", start + Vector2(8, 0),  0.04)
	tween.tween_property(peca, "position", start + Vector2(-8, 0), 0.04)
	tween.tween_property(peca, "position", start + Vector2(6, 0),  0.04)
	tween.tween_property(peca, "position", start + Vector2(-6, 0), 0.04)
	tween.tween_property(peca, "position", destino_local, 0.2).set_ease(Tween.EASE_OUT)

func _tremer(alvo: Control, origem: Vector2):
	var tween := _tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(alvo, "position", origem + Vector2(7, 0),  0.04)
	tween.tween_property(alvo, "position", origem + Vector2(-7, 0), 0.04)
	tween.tween_property(alvo, "position", origem + Vector2(4, 0),  0.04)
	tween.tween_property(alvo, "position", origem, 0.04)

func _pop(caixa: Control):
	caixa.pivot_offset = caixa.size / 2.0
	var tween = create_tween()
	tween.tween_property(caixa, "scale", Vector2(1.18, 1.18), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(caixa, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	audio_pop.play()

func _shake(alvo: Control):
	var origem := alvo.position
	var tween  := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(alvo, "position", origem + Vector2(6, 0),  0.05)
	tween.tween_property(alvo, "position", origem + Vector2(-6, 0), 0.05)
	tween.tween_property(alvo, "position", origem + Vector2(5, 0),  0.04)
	tween.tween_property(alvo, "position", origem + Vector2(-5, 0), 0.04)
	tween.tween_property(alvo, "position", origem, 0.03)
