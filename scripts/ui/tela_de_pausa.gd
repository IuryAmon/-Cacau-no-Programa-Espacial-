class_name TelaDePausa
extends TelaInterativa

# --- A TELA DE PAUSA ---
#
# O jogo parado atrás de um véu escuro, o nome PAUSA e três botões de papel,
# os mesmos do menu principal:
#
#   CONTINUAR      volta para o jogo do jeito que estava. ESC, START, ○ e △
#                  fazem o mesmo de qualquer botão em foco;
#   REINICIAR      recomeça do último checkpoint. É a mesma volta de quando a
#                  Cacau morre (PontoDeRetorno): a bandeira ou a sala de
#                  retorno continua valendo, e nada do que ela já fez na fase
#                  se desfaz (o EstadoMundo lembra);
#   MENU INICIAL   volta para a tela de título.
#
# Quem abre e fecha é o autoload Pausa (scripts/pausa.gd), que também sabe
# quando ela pode abrir. As teclas são as dos menus: setas, W/S, o direcional
# ou o analógico levam o foco; E, ENTER, ESPAÇO ou ✕ apertam.

const OPCOES := [
	{"chave": "continuar", "nome": "CONTINUAR", "descricao": "VOLTA PARA O JOGO"},
	{"chave": "reiniciar", "nome": "REINICIAR", "descricao": "RECOMEÇA DO ÚLTIMO CHECKPOINT"},
	{"chave": "menu", "nome": "MENU INICIAL", "descricao": "VOLTA PARA A TELA DE TÍTULO"},
]

const TXT_TITULO := "PAUSA"
const TAM_TITULO := 72
const CONTORNO_DO_TITULO := 12
## A linha de base do título e o alto do primeiro botão (px da tela).
const BASE_DO_TITULO := 286.0
const TOPO_DOS_BOTOES := 336.0
const TAMANHO_DO_BOTAO := Vector2(480, 84)
const ENTRE_BOTOES := 22.0
const TAM_NOME := 33
const TAM_DESCRICAO := 11

## O véu por cima do jogo parado (o mesmo tom do fim de jogo, mais leve).
const VEU := Color(0.04, 0.03, 0.07, 0.74)
## A tela inteira aparece neste tempo; os botões sobem um atrás do outro.
const ENTRADA := 0.12
const SUBIDA_DOS_BOTOES := 0.18
const ATRASO_ENTRE_BOTOES := 0.04
const ALTURA_DA_SUBIDA := 16.0

var _tempo: float = 0.0
var _desenho: Control


func _init() -> void:
	cena_de_volta = ""
	texto_de_voltar = ""
	navegar_com_teclas = true


func _ao_abrir() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_desenho = Control.new()
	_desenho.name = "Desenho"
	_desenho.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desenho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desenho.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_desenho.modulate.a = 0.0
	_desenho.draw.connect(_desenhar)
	add_child(_desenho)
	move_child(_desenho, 0)
	for i in OPCOES.size():
		var chave := String(OPCOES[i]["chave"])
		registrar_alvo(chave, retangulo_do_botao.bind(i), escolher.bind(chave))
	focar("continuar")


func _a_cada_quadro(delta: float) -> void:
	_tempo += delta
	_desenho.modulate.a = clampf(_tempo / ENTRADA, 0.0, 1.0)
	# As teclas da dica afundam em loop: o desenho se refaz sempre.
	_desenho.queue_redraw()


## O START (e o ESC, que também é "pausar") fecha a pausa, como abriu.
func _ao_receber(event: InputEvent) -> bool:
	if event.is_action_pressed(Pausa.ACAO) and not event.is_echo():
		continuar()
		return true
	return false


func _ao_pedir_para_voltar() -> void:
	continuar()


func escolher(chave: String) -> void:
	match chave:
		"continuar":
			continuar()
		"reiniciar":
			reiniciar()
		"menu":
			voltar_ao_menu()


func continuar() -> void:
	if de_saida():
		return
	Pausa.continuar()


## Recomeça do último checkpoint: a mesma volta da morte.
func reiniciar() -> void:
	var cena := get_tree().current_scene
	if cena == null or cena.scene_file_path.is_empty():
		return
	PontoDeRetorno.marcar_morte(get_tree())
	ir_para(cena.scene_file_path)


func voltar_ao_menu() -> void:
	# É uma saída da cena, como por uma porta: quem guarda algo ao sair (a
	# caixa empurrada) anota agora. E a próxima fase abre no ponto de
	# nascimento dela, não na porta por onde a Cacau tinha entrado.
	get_tree().call_group(EstadoMundo.GRUPO_SALVAR_AO_SAIR, "salvar_ao_sair")
	Progresso.spawn_tag = ""
	ir_para(TransicaoDeCena.CENA_MENU)


## Onde fica o botão número "i" (na ordem das OPCOES).
func retangulo_do_botao(i: int) -> Rect2:
	var y := TOPO_DOS_BOTOES + i * (TAMANHO_DO_BOTAO.y + ENTRE_BOTOES)
	return Rect2(roundf(size.x * 0.5 - TAMANHO_DO_BOTAO.x * 0.5), y, TAMANHO_DO_BOTAO.x, TAMANHO_DO_BOTAO.y)


func dicas_do_controle() -> Array:
	return [["direcional", "ESCOLHER"], ["cruz", "ENTRAR"], ["options", "CONTINUAR"]]


# ─────────────────────────────────────────────────────────────
# O DESENHO
# ─────────────────────────────────────────────────────────────

func _desenhar() -> void:
	_desenho.draw_rect(Rect2(Vector2.ZERO, size), VEU)

	var largura := PecasDoLaboratorio.largura(TXT_TITULO, TAM_TITULO)
	var queda := (1.0 - ease(clampf(_tempo / SUBIDA_DOS_BOTOES, 0.0, 1.0), 0.4)) * ALTURA_DA_SUBIDA
	EstiloHUD.rotulo(_desenho, FONTE, Vector2(size.x * 0.5 - largura * 0.5, BASE_DO_TITULO - queda).round(),
		TXT_TITULO, TAM_TITULO, EstiloHUD.CLARO, 1.0, CONTORNO_DO_TITULO)

	for i in OPCOES.size():
		var dados: Dictionary = OPCOES[i]
		var chave := String(dados["chave"])
		var t := clampf((_tempo - i * ATRASO_ENTRE_BOTOES) / SUBIDA_DOS_BOTOES, 0.0, 1.0)
		var caixa := retangulo_do_botao(i)
		caixa.position.y += roundf((1.0 - ease(t, 0.4)) * ALTURA_DA_SUBIDA)
		var ficha := PecasDoLaboratorio.ficha_de_botao(_desenho, caixa, alvo_em_foco() == chave,
			alvo_segurado() == chave)
		PecasDoLaboratorio.escrever_no_meio(_desenho, Vector2(ficha.get_center().x, ficha.position.y + 32.0),
			String(dados["nome"]), TAM_NOME, EstiloHUD.TINTA)
		PecasDoLaboratorio.escrever_no_meio(_desenho, Vector2(ficha.get_center().x, ficha.end.y - 22.0),
			String(dados["descricao"]), TAM_DESCRICAO, EstiloHUD.TINTA_FRACA)

	PecasDoLaboratorio.dicas_de_teclado(_desenho, Vector2(size.x * 0.5, size.y - 34.0),
		[[["tecla_w", "tecla_s"], "ESCOLHER"], [["tecla_e"], "ENTRAR"], [["tecla_esc"], "CONTINUAR"]])
