class_name PonteiroDoMouse
extends RefCounted

# --- O PONTEIRO DO MOUSE (os cursores de assets/UI/Roret_Cursor) ---
#
# O jogo não mostra nenhum cursor do sistema: cada forma de cursor do Godot
# ganha o seu desenho da pasta assets/UI/Roret_Cursor/png/. Quem instala é o
# autoload CursorVirtual, logo no começo do jogo; daí em diante cada tela só
# escolhe a FORMA, como sempre (Input.set_default_cursor_shape, ou o
# mouse_default_cursor_shape de um Control), e o desenho certo aparece sozinho
# — nos menus, no caderno e nos puzzles:
#
#   seta (ARROW)                 o normal
#   mão que aponta               o que dá para clicar; com o botão apertado,
#     (POINTING_HAND)            ela dobra o dedo (cursor_select_tap)
#   mão aberta (DRAG)            em cima do que dá para arrastar
#                                (MaoDoMouse.CURSOR_DE_PEGAR)
#   mão fechada (CAN_DROP)       arrastando (MaoDoMouse.CURSOR_SEGURANDO)
#   o resto                      proibido, mira, mover, redimensionar, ampulheta
#
# O cursor do controle (CursorVirtual) e a mão da DicaDeArrastar desenham estas
# mesmas imagens.
#
# TAMANHO: cada pixel do desenho vira um pixel da tela até 1080 de altura (a
# seta fica com 24 px), dois a partir de 2160 — sempre um número inteiro, que
# pixel art não estica pela metade.
#
# PARA TROCAR UM CURSOR: salve o PNG novo por cima, com o mesmo nome. Se o
# desenho mudar de lugar dentro do PNG, acerte o ponto quente dele em FORMAS: o
# pixel que "clica" (a ponta da seta, a ponta do dedo, o meio da palma).

const PASTA := "res://assets/UI/Roret_Cursor/png/%s.png"

## Cada forma do Godot -> [o PNG, o ponto quente em px do desenho].
const FORMAS := {
	Input.CURSOR_ARROW: ["cursor_default", Vector2(1, 1)],
	Input.CURSOR_IBEAM: ["cursor_pen", Vector2(1, 19)],
	Input.CURSOR_POINTING_HAND: ["cursor_select", Vector2(7, 1)],
	Input.CURSOR_CROSS: ["cursor_croshair", Vector2(12, 12)],
	Input.CURSOR_WAIT: ["cursor_work1", Vector2(11, 14)],
	Input.CURSOR_BUSY: ["cursor_progress1", Vector2(1, 1)],
	# A fechada é a aberta com os dedos dobrados, 2 px à esquerda e 7 acima no
	# PNG: com os pontos quentes assim, a mão não pula ao fechar.
	Input.CURSOR_DRAG: ["cursor_grab", Vector2(12, 15)],
	Input.CURSOR_CAN_DROP: ["cursor_grabbing", Vector2(10, 8)],
	Input.CURSOR_FORBIDDEN: ["cursor_unavailable", Vector2(11, 11)],
	Input.CURSOR_VSIZE: ["cursor_re_vertical", Vector2(4, 12)],
	Input.CURSOR_HSIZE: ["cursor_re_horizontal", Vector2(12, 4)],
	Input.CURSOR_BDIAGSIZE: ["cursor_r_diag2", Vector2(11, 11)],
	Input.CURSOR_FDIAGSIZE: ["cursor_r_diag1", Vector2(11, 11)],
	Input.CURSOR_MOVE: ["cursor_move", Vector2(12, 12)],
	Input.CURSOR_VSPLIT: ["cursor_row_r", Vector2(10, 13)],
	Input.CURSOR_HSPLIT: ["cursor_col_r", Vector2(13, 10)],
	Input.CURSOR_HELP: ["cursor_help", Vector2(8, 12)],
}
## A mão que aponta com o dedo dobrado, enquanto o botão está apertado. O
## ponto quente é o mesmo da cursor_select: a mão fica parada e só o dedo desce.
const CLICANDO := ["cursor_select_tap", Vector2(7, 1)]

## A cada tantos pixels de altura da tela, cada pixel do desenho cresce um.
const ALTURA_POR_PIXEL := 1080.0

## Os PNGs importados, pelo nome.
static var _texturas: Dictionary = {}
## As imagens já ampliadas para o cursor do sistema ("nome@escala"). Vão como
## Image, e não como textura: o sistema guarda o que recebe até o jogo fechar,
## e uma textura solta nessa hora, já sem o servidor de desenho, só dá erro.
static var _ampliadas: Dictionary = {}
## A escala com que as formas foram vestidas (0 = ainda não foram).
static var _escala_instalada: int = 0
static var _clicando: bool = false


## Veste todas as formas do mouse com os desenhos. Chamar de novo só refaz o
## trabalho se a escala mudou (a janela foi para uma tela de outro tamanho).
static func instalar() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var escala_agora := escala()
	if escala_agora == _escala_instalada:
		return
	_escala_instalada = escala_agora
	_clicando = false
	for forma: int in FORMAS:
		_vestir(forma, FORMAS[forma])


## Chamado a cada quadro (pelo CursorVirtual): com o botão esquerdo apertado, a
## mão que aponta dobra o dedo; solto, volta.
static func acompanhar_o_clique() -> void:
	if _escala_instalada == 0:
		return
	var apertado := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if apertado == _clicando:
		return
	_clicando = apertado
	_vestir(Input.CURSOR_POINTING_HAND, CLICANDO if apertado else FORMAS[Input.CURSOR_POINTING_HAND])


## O desenho da forma, do tamanho do PNG (quem desenha amplia); com
## "clicando", o da mão de dedo dobrado.
static func textura(forma: int, clicando: bool = false) -> Texture2D:
	return _textura(_dados(forma, clicando)[0])


## O ponto quente da forma, em px do desenho.
static func ponto_quente(forma: int, clicando: bool = false) -> Vector2:
	return _dados(forma, clicando)[1]


## Solta as texturas guardadas. O CursorVirtual chama ao sair de cena, com o
## jogo fechando: elas não podem sobrar para depois do servidor de desenho.
static func soltar_as_texturas() -> void:
	_texturas.clear()


## Quantos pixels da tela cada pixel do desenho ocupa.
static func escala() -> int:
	var tela := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	return maxi(1, roundi(tela.y / ALTURA_POR_PIXEL))


static func _dados(forma: int, clicando: bool) -> Array:
	if clicando and forma == Input.CURSOR_POINTING_HAND:
		return CLICANDO
	return FORMAS.get(forma, FORMAS[Input.CURSOR_ARROW])


static func _textura(nome: String) -> Texture2D:
	if not _texturas.has(nome):
		_texturas[nome] = load(PASTA % nome)
	return _texturas[nome]


## Põe o desenho na forma do cursor do sistema, ampliado pela escala.
static func _vestir(forma: int, dados: Array) -> void:
	var nome: String = dados[0]
	var chave := "%s@%d" % [nome, _escala_instalada]
	if not _ampliadas.has(chave):
		var imagem := _textura(nome).get_image()
		if imagem == null:
			return
		if imagem.is_compressed():
			imagem.decompress()
		imagem.convert(Image.FORMAT_RGBA8)
		if _escala_instalada > 1:
			imagem.resize(imagem.get_width() * _escala_instalada, imagem.get_height() * _escala_instalada,
				Image.INTERPOLATE_NEAREST)
		_ampliadas[chave] = imagem
	Input.set_custom_mouse_cursor(_ampliadas[chave], forma, (dados[1] as Vector2) * _escala_instalada)
