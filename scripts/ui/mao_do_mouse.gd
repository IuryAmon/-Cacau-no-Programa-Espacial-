class_name MaoDoMouse
extends RefCounted

# --- A MÃOZINHA DO MOUSE (o que dá para arrastar) ---
#
# Nos puzzles, o que se arrasta com o mouse (o cabo do êmbolo, o ponteiro do
# termômetro, as peças do foguete) troca a seta do mouse por uma mão: ABERTA
# quando o ponteiro está em cima, FECHADA enquanto segura. É a mesma mão que a
# DicaDeArrastar desenha mostrando o gesto antes da primeira vez.
#
# O Godot não tem cursor de mão de pegar: ela vai nas formas DRAG e CAN_DROP,
# que o PonteiroDoMouse veste com a cursor_grab e a cursor_grabbing do
# Roret_Cursor (assets/UI/Roret_Cursor/png/) — junto com todas as outras
# formas, no começo do jogo. Aqui ficam só os nomes das duas formas e o
# desenho da mão para quem a desenha na tela.

## As formas do cursor que viram a mão.
const CURSOR_DE_PEGAR := Input.CURSOR_DRAG
const CURSOR_SEGURANDO := Input.CURSOR_CAN_DROP


## O desenho da mão, do tamanho do PNG (quem desenha amplia).
static func textura(fechada: bool) -> Texture2D:
	return PonteiroDoMouse.textura(CURSOR_SEGURANDO if fechada else CURSOR_DE_PEGAR)


## O meio da palma, onde a mão "pega" (px do desenho).
static func palma(fechada: bool) -> Vector2:
	return PonteiroDoMouse.ponto_quente(CURSOR_SEGURANDO if fechada else CURSOR_DE_PEGAR)
