extends TelaInterativa

# --- O MENU PRINCIPAL ---
#
# A primeira tela do jogo. Dois modos:
#
#   MODO HISTÓRIA   a aventura da Cacau: abre com a introdução (o acidente de
#                   2003 em Alcântara, scenes/introducao.tscn), que segue
#                   sozinha para o world1.
#   LABORATÓRIO     os puzzles e as simulações da história, soltos, para
#                   brincar e treinar (scenes/laboratorio/menu_laboratorio.tscn).
#
# e SAIR, que fecha o jogo.
#
# O CENÁRIO é um pedaço do próprio jogo, montado como uma fase: a entrada da
# base do world1 ao entardecer, que é onde e quando a história começa. O céu, o
# sol, as nuvens, a serra e os pinheiros são os do world1; o gramado, o piso de
# pedra, o pilarete e o poste são tiles pintados, e a luz do poste acende
# sozinha (PostesDeLuz), como nas fases. Na frente, a Cacau e o Dr. Chico, cada
# um na animação de parado que tem no jogo. Quem acende tudo é o mesmo nó
# Atmosfera das fases, preso no entardecer (ele não segue a hora da partida: o
# menu não é uma fase).
#
# A tela não tem câmera: tudo fica em pixels da tela (1600 x 900), e a arte do
# cenário está em escala 4 (nas fases é escala 2, com o zoom da câmera por cima).
#
# O NOME do jogo é escrito com a tabela periódica, como a vida da Cacau no HUD:
# Ca, Ca e U (cálcio, cálcio e urânio), nas caixas dos elementos
# (CaixasDosElementos), e "no Programa Espacial" embaixo.
#
# ONDE MEXER:
#   OPCOES e os textos logo abaixo   os botões e o que cada um diz.
#   scenes/menu_principal.tscn       o cenário, nó por nó:
#       BG/...                       o céu, o sol, as nuvens, a serra e as três
#                                    fileiras de pinheiros;
#       Cenario/Chao e Detalhes      o chão, o poste e os enfeites: são tiles,
#                                    pinta-se como numa fase;
#       Cenario/Cacau e DrChico      os dois personagens: arraste para mudar de
#                                    lugar (Flip H vira para o outro lado);
#       Interface/Painel             o nome e os botões, que este script
#                                    desenha por cima de tudo.
#
# CONTROLES: mouse; setas ou W/S levam o foco e ENTER, ESPAÇO ou E entram. No
# controle: direcional (ou analógico) e ✕.

const OPCOES := [
	{"chave": "historia", "nome": "MODO HISTÓRIA", "descricao": "A AVENTURA DA CACAU NO CENTRO DE LANÇAMENTO"},
	{"chave": "laboratorio", "nome": "LABORATÓRIO", "descricao": "OS PUZZLES E AS SIMULAÇÕES, PARA BRINCAR"},
	{"chave": "sair", "nome": "SAIR", "descricao": ""},
]

## O menu, por enquanto, fica sem música (a TrilhaSonora olha isto): sem isto,
## o céu aberto dele tocaria a música da hora. Com false, ela volta.
var sem_musica := true

## O nome do jogo: os elementos das três caixas (Ca, Ca, U) e a linha de baixo.
const ELEMENTOS_DO_NOME := [20, 20, 92]
const SUBTITULO := "NO PROGRAMA ESPACIAL"

# ── Onde fica cada coisa (px da tela) ──
const CANTO_DO_NOME := Vector2(104, 60)
const ESCALA_DO_NOME := 3
const ENTRE_CAIXAS := 14.0
const TAM_SUBTITULO := 44
## O contorno escuro do subtítulo, que é escrito direto em cima do céu.
const CONTORNO_DO_SUBTITULO := 8
## Do pé das caixas até o subtítulo, e dele até o primeiro botão.
const ATE_O_SUBTITULO := 52.0
const ATE_OS_BOTOES := 70.0
const TAMANHO_DO_BOTAO := Vector2(480, 84)
const TAMANHO_DO_SAIR := Vector2(220, 56)
const ENTRE_BOTOES := 22.0
const TAM_NOME := 33
const TAM_DESCRICAO := 11

@onready var painel: Control = $Interface/Painel


func _ao_abrir() -> void:
	painel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	painel.draw.connect(_desenhar)
	for i in OPCOES.size():
		var chave := String(OPCOES[i]["chave"])
		registrar_alvo(chave, retangulo_do_botao.bind(i), escolher.bind(chave))
	focar("historia")


func _a_cada_quadro(_delta: float) -> void:
	# As teclas da dica afundam em loop: o painel se redesenha sempre.
	painel.queue_redraw()


# ─────────────────────────────────────────────────────────────
# AS OPÇÕES
# ─────────────────────────────────────────────────────────────

func escolher(chave: String) -> void:
	match chave:
		"historia":
			ir_para(TransicaoDeCena.CENA_INTRODUCAO)
		"laboratorio":
			ir_para(TransicaoDeCena.CENA_LABORATORIO)
		"sair":
			get_tree().quit()


## O meio (em x) da coluna do nome e dos botões.
func _meio_da_coluna() -> float:
	return CANTO_DO_NOME.x + largura_do_nome() * 0.5


## A largura das três caixas do nome, com os vãos.
func largura_do_nome() -> float:
	var caixa := CaixaElemento.tamanho_na_escala(ESCALA_DO_NOME)
	return caixa.x * ELEMENTOS_DO_NOME.size() + ENTRE_CAIXAS * (ELEMENTOS_DO_NOME.size() - 1)


## Onde fica a caixa número "i" do nome.
func retangulo_da_caixa(i: int) -> Rect2:
	var caixa := CaixaElemento.tamanho_na_escala(ESCALA_DO_NOME)
	return Rect2(CANTO_DO_NOME + Vector2(i * (caixa.x + ENTRE_CAIXAS), 0.0), caixa)


func _pe_do_subtitulo() -> float:
	return retangulo_da_caixa(0).end.y + ATE_O_SUBTITULO


## Onde fica o botão número "i" (na ordem das OPCOES).
func retangulo_do_botao(i: int) -> Rect2:
	var y := _pe_do_subtitulo() + ATE_OS_BOTOES
	for k in i:
		y += _tamanho_do_botao(k).y + ENTRE_BOTOES
	var tamanho := _tamanho_do_botao(i)
	return Rect2(roundf(_meio_da_coluna() - tamanho.x * 0.5), y, tamanho.x, tamanho.y)


func _tamanho_do_botao(i: int) -> Vector2:
	return TAMANHO_DO_SAIR if OPCOES[i]["chave"] == "sair" else TAMANHO_DO_BOTAO


# ─────────────────────────────────────────────────────────────
# DESENHO
# ─────────────────────────────────────────────────────────────

func _desenhar() -> void:
	# O nome: Ca, Ca, U.
	for i in ELEMENTOS_DO_NOME.size():
		CaixaElemento.desenhar(painel, retangulo_da_caixa(i).position, int(ELEMENTOS_DO_NOME[i]), ESCALA_DO_NOME,
			true, true, EstiloHUD.PAPEL, Color(0, 0, 0, 0), Color(0, 0, 0, 0), 1.0, true)
	var largura := PecasDoLaboratorio.largura(SUBTITULO, TAM_SUBTITULO)
	EstiloHUD.rotulo(painel, FONTE, Vector2(roundf(_meio_da_coluna() - largura * 0.5), _pe_do_subtitulo()), SUBTITULO,
		TAM_SUBTITULO, EstiloHUD.CLARO, 1.0, CONTORNO_DO_SUBTITULO)

	for i in OPCOES.size():
		var dados: Dictionary = OPCOES[i]
		var chave := String(dados["chave"])
		var caixa := PecasDoLaboratorio.ficha_de_botao(painel, retangulo_do_botao(i), alvo_em_foco() == chave,
			alvo_segurado() == chave)
		var descricao := String(dados["descricao"])
		if descricao.is_empty():
			PecasDoLaboratorio.escrever_no_meio(painel, caixa.get_center() - Vector2(0, 1), String(dados["nome"]),
				22, EstiloHUD.TINTA)
			continue
		PecasDoLaboratorio.escrever_no_meio(painel, Vector2(caixa.get_center().x, caixa.position.y + 32.0),
			String(dados["nome"]), TAM_NOME, EstiloHUD.TINTA)
		PecasDoLaboratorio.escrever_no_meio(painel, Vector2(caixa.get_center().x, caixa.end.y - 22.0), descricao,
			TAM_DESCRICAO, EstiloHUD.TINTA_FRACA)

	PecasDoLaboratorio.dicas_de_teclado(painel, Vector2(_meio_da_coluna(), size.y - 34.0),
		[[["tecla_w", "tecla_s"], "ESCOLHER"], [["tecla_e"], "ENTRAR"]])
