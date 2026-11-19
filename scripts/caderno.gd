extends CanvasLayer

# --- AUTOLOAD "Caderno" ---
#
# O caderno de anotações da Cacau. Ela o tem desde o começo do jogo: o ícone
# (o caderninho e o mapinha) fica no canto inferior esquerdo e M (△ no
# controle) abre e fecha.
#
# Aberto, ele tem duas ABAS, no alto da tela: CADERNO (as anotações) e MAPA (a
# planta do Centro de Lançamento, com a Cacau onde ela está e o objetivo da
# vez). A primeira vez ele abre no MAPA; depois, sempre na aba em que a Cacau
# ficou da última vez. Nota nova não muda isso: ela acende a marca de nota
# nova no caderninho do ícone e na aba CADERNO, e o caderno já fica na página
# dela, para quando a pessoa trocar de aba.
#
#   PaginasCaderno (scripts/paginas_caderno.gd)    O QUE está escrito
#   PlantaDoMapa (scripts/planta_do_mapa.gd)       O QUE está no mapa
#   este autoload                                  QUANDO: o ícone aparece, o
#                                                  caderno abre, pausa, troca de
#                                                  aba e fecha
#   CadernoLivro (scripts/ui/caderno_livro.gd)     COMO: a arte e as folhas
#                                                  virando
#   FolhaDoMapa (scripts/ui/folha_do_mapa.gd)      COMO: o desenho do mapa
#   AbasDoCaderno (scripts/ui/abas_do_caderno.gd)  COMO: as abas
#
# Aberto, o mundo pausa (como na ficha de coleta) e o caderno segura as teclas
# (Interacao.marcar_tela_aberta): o espaço ou o ○ apertados em cima dele não
# viram pulo nem dash quando ele fecha. Ele abre saindo do ícone e fecha
# voltando para dentro dele, e lembra a página e a aba em que ficou.
#
# COM O CADERNO ABERTO
#   Q/E, L1/R1, clique na aba         troca de aba (as pontas se emendam)
#   A/D, ←/→, direcional, analógico   folheia, na aba CADERNO (segurando,
#                                     continua folheando)
#   clique na face direita/esquerda   folheia; a roda do mouse também
#   M, ESC, △, ○                      fecha; clicar fora do caderno (ou do
#                                     mapa) também
#
# O ícone some junto com a lista de objetivos (fala, ficha de coleta, puzzle,
# pausa, cenas sem a Cacau), e o caderno só abre com o ícone na tela.
#
# AS NOTAS. O caderno começa só até a página 3; as outras páginas a Cacau
# ANOTA quando o Dr. Chico explica alguma coisa: a conversa dele chama
# anotar() no fim (e também quando a pessoa escolhe pular a explicação). A
# página entra no caderno (quem guarda quais ele tem é o PaginasCaderno), o
# ícone pula e acende a marca de nota nova, e o aviso "NOTA ADICIONADA"
# (CadernoAviso) sobe em cima dele — assim que o ícone voltar para a tela,
# depois da fala e do puzzle. O caderno já fica aberto na página da nota: a
# aba CADERNO cai nela. A marca apaga quando a pessoa vê a aba CADERNO.
#
# Uma nota também pode ser uma folha solta no mapa (NotaCaderno,
# scripts/fases/nota_caderno.gd): a folha chama guardar_nota() e voa de onde
# estava até o ícone antes do aviso.

signal aberto_mudou(aberto: bool)
## Uma nota entrou no caderno (o nome dela nas PaginasCaderno.NOTAS).
signal nota_guardada(nota: String)
## Trocou de aba (Aba.CADERNO ou Aba.MAPA).
signal aba_mudou(aba: int)

## As abas, na ordem em que aparecem (a mesma das AbasDoCaderno.NOMES).
enum Aba {CADERNO, MAPA}

const ACAO := &"caderno"
const SOM_ABRIR := preload("res://sounds/caderno_abrir.wav")
const SOM_FECHAR := preload("res://sounds/caderno_fechar.wav")
## A folha saindo do chão e, depois do voo, entrando no caderno.
const SOM_PEGAR_NOTA := preload("res://sounds/CollectSound.mp3")
const SOM_NOTA_NO_CADERNO := preload("res://sounds/caderno_pagina.wav")
const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

## Quanto a folha leva de onde estava até o ícone.
const DURACAO_VOO_DA_NOTA := 0.62

## O caderno aberto fica acima de tudo do jogo: puzzles (10-15), Dialogic (20),
## equipamentos (90) e mochila (95). O ícone mora na camada do autoload, a mesma da
## lista de objetivos (abaixo dos puzzles).
const CAMADA_ICONE := 4
const CAMADA_ABERTO := 100

const DURACAO_ABRIR := 0.34
const DURACAO_FECHAR := 0.22
## O ícone aparece e some neste tempo (quando uma fala abre, por exemplo).
const DURACAO_ICONE := 0.2
## Quanto o caderno passa do tamanho ao abrir, antes de assentar.
const EXAGERO_ABRIR := 1.4
const VEU := Color(0.035, 0.025, 0.03, 0.66)

# --- As abas ---
## As teclas e os botões que trocam de aba: um vai para a aba da esquerda, o
## outro para a da direita.
const TECLA_ABA_ANTERIOR := KEY_Q
const TECLA_ABA_SEGUINTE := KEY_E
const BOTAO_ABA_ANTERIOR := JOY_BUTTON_LEFT_SHOULDER
const BOTAO_ABA_SEGUINTE := JOY_BUTTON_RIGHT_SHOULDER
## A troca de aba: quanto leva e quanto as folhas deslizam (a que sai vai para
## um lado, a que entra vem do outro).
const DURACAO_TROCA := 0.28
const DESLIZE_TROCA := 56.0
## O alto da tela é das abas: o caderno (ou o mapa) fica no meio do que sobra
## entre elas e o rodapé.
const ALTURA_ABAS := 80.0
const TOPO_ABAS := 18.0

# --- Rodapé (os comandos, no pé da tela) ---
const ALTURA_RODAPE := 64.0
const ALTURA_BARRA := 46.0
const TAM_DICA := 13
const ESPACO_DICA := 1.6
const ESCALA_BOTAO := 2.0

var _icone: CadernoIcone = null
var _aviso: CadernoAviso = null
var _som_pegar_nota: AudioStreamPlayer = null
var _som_nota: AudioStreamPlayer = null
var _camada: CanvasLayer = null
var _tela: Control = null
var _veu: ColorRect = null
var _livro: CadernoLivro = null
var _mapa: FolhaDoMapa = null
var _abas: AbasDoCaderno = null
var _rodape: Control = null
var _som: AudioStreamPlayer = null
var _som_aba: AudioStreamPlayer = null

var _aberto: bool = false
## 0 = fechado dentro do ícone, 1 = aberto no meio da tela.
var _abertura: float = 0.0
var _alfa_icone: float = 0.0
## Foi o caderno que pausou o jogo (e é ele quem despausa).
var _pausou: bool = false

## A aba da vez: é nela que o caderno abre. Começa no MAPA (a primeira vez é
## sempre o mapa) e depois é a última que a Cacau viu.
var _aba: int = Aba.MAPA
## Na troca de aba: a que está saindo (-1 = nenhuma troca), de que lado a nova
## entra (1 = da direita) e o andamento (0 a 1).
var _aba_saindo: int = -1
var _sentido_troca: int = 1
var _troca: float = 1.0


func _ready() -> void:
	layer = CAMADA_ICONE
	process_mode = Node.PROCESS_MODE_ALWAYS

	_icone = CadernoIcone.new()
	_icone.name = "Icone"
	add_child(_icone)

	_aviso = CadernoAviso.new()
	_aviso.name = "Aviso"
	_aviso.icone = _icone
	add_child(_aviso)

	_som_pegar_nota = AudioStreamPlayer.new()
	_som_pegar_nota.name = "SomPegarNota"
	_som_pegar_nota.stream = SOM_PEGAR_NOTA
	_som_pegar_nota.volume_db = -6.0
	add_child(_som_pegar_nota)

	_som_nota = AudioStreamPlayer.new()
	_som_nota.name = "SomNota"
	_som_nota.stream = SOM_NOTA_NO_CADERNO
	_som_nota.volume_db = -2.0
	add_child(_som_nota)

	_camada = CanvasLayer.new()
	_camada.name = "Aberto"
	_camada.layer = CAMADA_ABERTO
	add_child(_camada)

	_tela = Control.new()
	_tela.name = "Tela"
	_tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tela.mouse_filter = Control.MOUSE_FILTER_STOP
	_tela.visible = false
	_tela.gui_input.connect(_ao_clicar_fora)
	_camada.add_child(_tela)

	_veu = ColorRect.new()
	_veu.name = "Veu"
	_veu.color = VEU
	_veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.add_child(_veu)

	_livro = CadernoLivro.new()
	_livro.name = "Livro"
	_livro.pivot_offset = CadernoLivro.CAIXA_DESENHO.get_center()
	_livro.fora_clicado.connect(fechar)
	_tela.add_child(_livro)

	_mapa = FolhaDoMapa.new()
	_mapa.name = "Mapa"
	_mapa.pivot_offset = FolhaDoMapa.TAMANHO * 0.5
	_mapa.visible = false
	_tela.add_child(_mapa)

	_abas = AbasDoCaderno.new()
	_abas.name = "Abas"
	_abas.icone = _icone
	_abas.aba_clicada.connect(mostrar_aba)
	_tela.add_child(_abas)
	_abas.mostrar_na_hora(_aba)

	_rodape = Control.new()
	_rodape.name = "Rodape"
	_rodape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rodape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rodape.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rodape.draw.connect(_desenhar_rodape)
	_tela.add_child(_rodape)

	_som = AudioStreamPlayer.new()
	_som.name = "Som"
	add_child(_som)

	_som_aba = AudioStreamPlayer.new()
	_som_aba.name = "SomAba"
	_som_aba.stream = SOM_NOTA_NO_CADERNO
	_som_aba.volume_db = -6.0
	add_child(_som_aba)


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

func aberto() -> bool:
	return _aberto


func livro() -> CadernoLivro:
	return _livro


func mapa() -> FolhaDoMapa:
	return _mapa


func abas() -> AbasDoCaderno:
	return _abas


## A aba da vez (Aba.CADERNO ou Aba.MAPA).
func aba() -> int:
	return _aba


## Dá para abrir agora? Só com o ícone na tela e a camada do autoload visível
## (a cortina das portas a apaga no meio da troca de cena).
func pode_abrir() -> bool:
	return not _aberto and _pode_aparecer() and visible and _alfa_icone >= 1.0


func abrir() -> void:
	if not pode_abrir():
		return
	_aberto = true
	_tela.visible = true
	_aba_saindo = -1
	_troca = 1.0
	# Na aba em que ficou (da primeira vez, no mapa).
	_abas.mostrar_na_hora(_aba)
	_mapa.ler_o_jogo()
	_aviso.dispensar()
	_ver_a_aba()
	Interacao.marcar_tela_aberta(_tela, true)
	if not get_tree().paused:
		get_tree().paused = true
		_pausou = true
	_tocar(SOM_ABRIR)
	aberto_mudou.emit(true)


## O jogo volta quando o caderno termina de voltar para o ícone (_process).
func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	_tocar(SOM_FECHAR)
	aberto_mudou.emit(false)


## Troca para a aba (Aba.CADERNO ou Aba.MAPA). Fechado, só escolhe em qual o
## caderno vai abrir. "sentido" é de que lado a aba nova entra (1 = da
## direita); 0 = pela ordem das abas.
func mostrar_aba(nova: int, sentido: int = 0) -> void:
	nova = clampi(nova, 0, Aba.size() - 1)
	if nova == _aba:
		return
	if nova == Aba.MAPA:
		_mapa.ler_o_jogo()
	if _aberto:
		_aba_saindo = _aba
		_troca = 0.0
		_sentido_troca = sentido if sentido != 0 else signi(nova - _aba)
		_som_aba.pitch_scale = randf_range(1.18, 1.3)
		_som_aba.play()
		_aba = nova
		_abas.atual = _aba
	else:
		_aba = nova
		_abas.mostrar_na_hora(_aba)
	aba_mudou.emit(_aba)
	if _aberto:
		_ver_a_aba()


## A pessoa está vendo a aba da vez. Se é o CADERNO, a nota nova foi vista (ele
## já está na página dela) e a marca apaga — no ícone e na aba.
func _ver_a_aba() -> void:
	if _aba == Aba.CADERNO:
		_icone.novidade = false


# ─────────────────────────────────────────────────────────────
# AS NOTAS
# ─────────────────────────────────────────────────────────────

## A Cacau já achou esta nota (o nome dela nas PaginasCaderno.NOTAS)?
func tem_nota(nota: String) -> bool:
	return PaginasCaderno.tem_nota(nota)


func aviso() -> CadernoAviso:
	return _aviso


## Põe a nota no caderno e avisa na tela. "de" é onde a folha estava, na tela,
## e "tamanho" o lado maior dela ali: a folha voa de lá até o ícone, e o aviso
## só sobe quando ela chega. Sem "de" (a nota não veio do mapa), o aviso sobe
## direto. Devolve false se a nota não existe ou já estava no caderno.
func guardar_nota(nota: String, de: Vector2 = Vector2.INF, tamanho: float = 72.0) -> bool:
	if not PaginasCaderno.guardar_nota(nota):
		return false
	# O caderno já fica na página da nota: a aba CADERNO cai nela. A aba em que
	# ele abre não muda (é a última que a Cacau viu); a marca de nota nova é
	# que chama para o CADERNO.
	_livro.ir_para_na_hora(PaginasCaderno.lugar_da_nota(nota))
	nota_guardada.emit(nota)
	if not de.is_finite():
		_ao_chegar_a_nota(nota)
		return true
	_som_pegar_nota.play()
	var voo := VooDeItem.lancar(self, CadernoAviso.ARTE, CadernoAviso.ACENTO, de,
		_icone.centro_do_caderno(), tamanho, _icone.size.y, DURACAO_VOO_DA_NOTA)
	voo.chegou.connect(_ao_chegar_a_nota.bind(nota))
	return true


## A Cacau anota no caderno o que o Dr. Chico acabou de explicar: a nota entra
## sem folha voando, e o aviso sobe quando o ícone voltar para a tela (depois
## da fala e do puzzle). É o que as conversas chamam:
##   do Caderno.anotar("atomo")
## Anotar de novo uma nota que já está no caderno não faz nada.
func anotar(nota: String) -> void:
	if not PaginasCaderno.NOTAS.has(nota):
		push_warning("Caderno.anotar(): não existe nota \"%s\" nas PaginasCaderno.NOTAS" % nota)
		return
	guardar_nota(nota)


## Atalho de teste (tecla P e o F1 do ModoDev, em qualquer mapa): o caderno
## inteiro de uma vez, com todas as notas que faltavam. Sem aviso — seriam cinco
## em fila —, só a marca de nota nova no ícone. Devolve as notas que eram novas.
func anotar_todas() -> PackedStringArray:
	var novas := PackedStringArray()
	for nota in PaginasCaderno.NOTAS:
		if PaginasCaderno.guardar_nota(nota):
			novas.append(nota)
			nota_guardada.emit(nota)
	if not novas.is_empty():
		# O livro lê as páginas na hora: só precisa se recompor (na mesma página).
		_livro.ir_para_na_hora(_livro.pagina())
		_icone.novidade = true
	return novas


## A folha entrou no caderno: o ícone pula e o aviso sobe.
func _ao_chegar_a_nota(nota: String) -> void:
	_som_nota.pitch_scale = randf_range(0.96, 1.06)
	_som_nota.play()
	_icone.pular()
	_icone.novidade = true
	_aviso.mostrar(PaginasCaderno.titulo_da_nota(nota), PaginasCaderno.numeros_da_nota(nota))


# ─────────────────────────────────────────────────────────────
# A CADA QUADRO
# ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Fala ou ficha de coleta por cima, ou a Cacau saiu de cena: o caderno fecha
	# sozinho para não esconder nada.
	if _aberto and (Dialogic.current_timeline != null or Inventario.popup_aberto \
			or not _pode_aparecer()):
		fechar()

	if _aberto and _abertura >= 0.5 and _aba == Aba.CADERNO:
		var passo := Controle.passo_navegacao()
		if passo.x > 0:
			_livro.proxima()
		elif passo.x < 0:
			_livro.anterior()

	var duracao := DURACAO_ABRIR if _aberto else DURACAO_FECHAR
	_abertura = move_toward(_abertura, 1.0 if _aberto else 0.0, delta / duracao)
	if _aba_saindo >= 0:
		_troca = move_toward(_troca, 1.0, delta / DURACAO_TROCA)
		if _troca >= 1.0:
			_aba_saindo = -1
	if _tela.visible:
		_posicionar()
		_rodape.queue_redraw()
	if not _aberto and _abertura <= 0.0 and _tela.visible:
		_terminar_de_fechar()

	var alvo_icone := 1.0 if _pode_aparecer() else 0.0
	_alfa_icone = move_toward(_alfa_icone, alvo_icone, delta / DURACAO_ICONE)
	# O caderno sai do ícone: o ícone some enquanto ele está fora.
	_icone.alfa = _alfa_icone * (1.0 - _abertura)
	_aviso.alfa_do_hud = _icone.alfa


func _terminar_de_fechar() -> void:
	_tela.visible = false
	_aba_saindo = -1
	_troca = 1.0
	Interacao.marcar_tela_aberta(_tela, false)
	if _pausou and not Inventario.popup_aberto:
		get_tree().paused = false
	_pausou = false


## Mesmas regras da lista de objetivos (Objetivos._pode_aparecer). Com o
## caderno na tela (aberto ou voltando para o ícone) a pausa e a tela ocupada
## são dele mesmo, e não contam.
func _pode_aparecer() -> bool:
	var cena := get_tree().current_scene
	if cena == null or cena.scene_file_path in Objetivos.CENAS_SEM_OBJETIVOS:
		return false
	if get_tree().get_first_node_in_group("player") == null:
		return false
	if _aberto or _tela.visible:
		return true
	if get_tree().paused or Interacao.ocupada():
		return false
	return true


## A folha da aba da vez sai do desenho dela no ícone (o caderno do
## caderninho, o mapa do mapinha) crescendo e vai para o meio da tela (entre as
## abas e o rodapé); fechando, faz o caminho de volta. A curva é a mesma nos
## dois sentidos — rápida perto do ícone, mansa perto do meio —, e só a
## abertura passa um pouco do tamanho antes de assentar. As abas descem do
## alto junto. Na troca de aba, a folha que sai desliza e apaga, e a que entra
## vem do outro lado acendendo.
func _posicionar() -> void:
	var t := _abertura
	var caminho := 1.0 - pow(1.0 - t, 3.0)
	var crescimento := _passar_e_voltar(t) if _aberto else caminho
	var centro := _centro_do_conteudo()
	var parado := t >= 1.0 and _aba_saindo < 0
	for i in Aba.size():
		var folha := _folha(i)
		var presenca := _presenca(i)
		folha.visible = presenca > 0.0
		if not folha.visible:
			continue
		var origem := _icone.centro_do_mapa() if i == Aba.MAPA else _icone.centro_do_caderno()
		var meio := origem.lerp(centro, caminho)
		var escala := lerpf(_icone.size.y / _altura_da_folha(i), 1.0, crescimento)
		folha.scale = Vector2(escala, escala)
		folha.position = meio - folha.pivot_offset + Vector2(_deslize(i), 0.0)
		if parado:
			folha.position = folha.position.round()
		folha.modulate.a = clampf(t * 4.0, 0.0, 1.0) * presenca
		# Só a folha da vez ouve o mouse (a outra ainda pode estar saindo).
		folha.mouse_filter = Control.MOUSE_FILTER_STOP if i == _aba else Control.MOUSE_FILTER_IGNORE
	_abas.position = Vector2(roundf((_tela.size.x - _abas.size.x) * 0.5),
		roundf(lerpf(-_abas.size.y, TOPO_ABAS, caminho)))
	_abas.modulate.a = clampf(t * 2.0 - 0.6, 0.0, 1.0)
	_veu.color = Color(VEU.r, VEU.g, VEU.b, VEU.a * t)


## O meio do espaço entre as abas e o rodapé.
func _centro_do_conteudo() -> Vector2:
	var tela := _tela.size
	return Vector2(tela.x * 0.5, ALTURA_ABAS + (tela.y - ALTURA_RODAPE - ALTURA_ABAS) * 0.5).round()


func _folha(i: int) -> Control:
	return _mapa if i == Aba.MAPA else _livro


## A altura do que se vê da folha (a arte do caderno tem borda transparente).
func _altura_da_folha(i: int) -> float:
	return FolhaDoMapa.TAMANHO.y if i == Aba.MAPA else CadernoLivro.CAIXA_DESENHO.size.y


## Quanto da folha da aba está na tela (0 a 1). Na troca, a que sai apaga na
## primeira metade, e a que entra acende logo depois de ela começar a sair.
func _presenca(i: int) -> float:
	if i == _aba:
		return 1.0 if _aba_saindo < 0 else _entrada()
	if i == _aba_saindo:
		return 1.0 - _saida()
	return 0.0


func _deslize(i: int) -> float:
	if _aba_saindo < 0:
		return 0.0
	if i == _aba:
		return roundf(DESLIZE_TROCA * _sentido_troca * (1.0 - _entrada()))
	return roundf(-DESLIZE_TROCA * _sentido_troca * _saida())


## O andamento da folha que entra e da que sai, já com a curva (a que entra
## freia chegando; a que sai acelera saindo).
func _entrada() -> float:
	var p := clampf((_troca - 0.25) / 0.75, 0.0, 1.0)
	return 1.0 - pow(1.0 - p, 3.0)


func _saida() -> float:
	var p := clampf(_troca / 0.5, 0.0, 1.0)
	return p * p


## Curva que passa de 1 e volta (o "back" das animações).
func _passar_e_voltar(t: float) -> float:
	var c := EXAGERO_ABRIR
	return 1.0 + (c + 1.0) * pow(t - 1.0, 3.0) + c * pow(t - 1.0, 2.0)


# ─────────────────────────────────────────────────────────────
# ENTRADA
# ─────────────────────────────────────────────────────────────

func _input(evento: InputEvent) -> void:
	if not _aberto:
		if evento.is_action_pressed(ACAO) and pode_abrir():
			get_viewport().set_input_as_handled()
			abrir()
		return

	# O mouse segue para a interface: é do CadernoLivro, da FolhaDoMapa, das
	# abas e da tela (_gui_input), que cobrem a tela inteira e não o deixam
	# passar para o jogo.
	if evento is InputEventMouse:
		return
	# Aberto, nenhuma tecla passa para o jogo parado atrás dele.
	get_viewport().set_input_as_handled()
	if evento.is_action_pressed(ACAO) or evento.is_action_pressed(&"fechar") \
			or evento.is_action_pressed(&"ui_cancel"):
		fechar()
		return
	var passo := _passo_de_aba(evento)
	if passo != 0:
		mostrar_aba(posmod(_aba + passo, Aba.size()), passo)
		return
	# O resto é folhear, e só o caderno folheia.
	if _aba != Aba.CADERNO:
		return
	# Direcional e analógico são lidos no _process, com a repetição do Controle.
	if evento is InputEventJoypadButton or evento is InputEventJoypadMotion:
		return
	# Tecla segurada repete (echo): continua folheando.
	if evento.is_action_pressed(&"ui_right", true):
		_livro.proxima()
	elif evento.is_action_pressed(&"ui_left", true):
		_livro.anterior()


## -1 (a aba da esquerda), 1 (a da direita) ou 0 (o evento não troca de aba).
## Pela tecla física, como o resto do mapa de entrada do jogo.
func _passo_de_aba(evento: InputEvent) -> int:
	if evento is InputEventKey and evento.pressed and not evento.echo:
		var tecla: Key = evento.physical_keycode if evento.physical_keycode != KEY_NONE \
			else evento.keycode
		if tecla == TECLA_ABA_ANTERIOR:
			return -1
		if tecla == TECLA_ABA_SEGUINTE:
			return 1
	elif evento is InputEventJoypadButton and evento.pressed:
		if evento.button_index == BOTAO_ABA_ANTERIOR:
			return -1
		if evento.button_index == BOTAO_ABA_SEGUINTE:
			return 1
	return 0


func _ao_clicar_fora(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed \
			and evento.button_index == MOUSE_BUTTON_LEFT:
		fechar()


func _tocar(som: AudioStream) -> void:
	_som.stream = som
	_som.play()


# ─────────────────────────────────────────────────────────────
# RODAPÉ
# ─────────────────────────────────────────────────────────────

## [botões, texto]. No teclado, as teclas desenhadas; no controle, os botões.
## Sem contador de página: o número já está no canto de cada página. No mapa
## não há o que folhear. As teclas de trocar de aba ficam nas pontas das abas.
func _dicas() -> Array:
	var folhear := [["tecla_a", "tecla_d"], "FOLHEAR"]
	var fechar_dica := [["tecla_m"], "FECHAR"]
	if BotoesControle.controle_em_uso():
		var fechar_com := BotoesControle.nome_da_acao(ACAO)
		folhear = [["direcional_horizontal"], "FOLHEAR"]
		fechar_dica = [[fechar_com if fechar_com != "" else "triangulo"], "FECHAR"]
	if _aba == Aba.MAPA:
		return [fechar_dica]
	return [folhear, fechar_dica]


## A barra de comandos dos puzzles (a do CursorVirtual), com as dicas do caderno.
func _desenhar_rodape() -> void:
	var alfa := clampf((_abertura - 0.5) * 2.0, 0.0, 1.0)
	if alfa <= 0.0:
		return
	var dicas := _dicas()
	var lado := 16.0 * ESCALA_BOTAO
	var respiro_icone := 8.0
	var respiro_itens := 26.0
	var margem := 18.0
	var larguras: Array[float] = []
	var total := 0.0
	for dica in dicas:
		var largura := EstiloHUD.largura_texto(FONTE, String(dica[1]), TAM_DICA, ESPACO_DICA)
		var botoes: Array = dica[0]
		largura += (lado + 4.0) * botoes.size()
		if not botoes.is_empty():
			largura += respiro_icone - 4.0
		larguras.append(largura)
		total += largura
	total += respiro_itens * (dicas.size() - 1)

	var tela := _rodape.size
	var caixa := Rect2(Vector2((tela.x - total) * 0.5 - margem, tela.y - ALTURA_BARRA - 10.0),
		Vector2(total + margem * 2.0, ALTURA_BARRA))
	EstiloHUD.barra(_rodape, caixa, alfa)

	var x := caixa.position.x + margem
	var meio := caixa.get_center().y
	var base := meio + FONTE.get_ascent(TAM_DICA) * 0.5 - 1.0
	for i in dicas.size():
		var inicio := x
		var botoes: Array = dicas[i][0]
		for nome in botoes:
			BotoesControle.desenhar(_rodape, Vector2(x + lado * 0.5, meio), nome,
				ESCALA_BOTAO, Color(1, 1, 1, alfa))
			x += lado + 4.0
		if not botoes.is_empty():
			x += respiro_icone - 4.0
		var cor := EstiloHUD.CLARO if not botoes.is_empty() else EstiloHUD.TECLA_TAMPA
		EstiloHUD.texto(_rodape, FONTE, Vector2(x, base), String(dicas[i][1]), TAM_DICA,
			EstiloHUD.com_alfa(cor, alfa), ESPACO_DICA)
		x = inicio + larguras[i] + respiro_itens
