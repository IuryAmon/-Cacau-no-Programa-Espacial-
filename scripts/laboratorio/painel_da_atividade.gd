class_name PainelDaAtividade
extends Control

# --- O PAINEL DAS ATIVIDADES DO LABORATÓRIO ---
#
# O Laboratório não acontece dentro de um computador do jogo: a tela de quem
# joga já é a tela. O "Monte seu átomo", o quiz e o balanceamento põem o
# conteúdo deles direto no fundo quadriculado do Laboratório, como o
# Destilador e a Tabela periódica — e esta peça é só o que os três têm em
# comum: a área do conteúdo, a linha miúda de cima (o cabeçalho: em que
# pergunta ou equação se está) e a linha de baixo (o rodapé: o que fazer, e os
# avisos de certo e errado).
#
# O RODAPÉ tem um texto de sempre (definir_rodape) e pode dar um aviso
# (avisar): o aviso toma o lugar do texto por alguns segundos, na cor pedida, e
# o texto de sempre volta.
#
# COMO EDITAR NO EDITOR (na cena de cada atividade, com "Filhos Editáveis"):
#   Display/Conteudo   é aqui dentro que a atividade põe as peças dela. As
#                      medidas são as da área: 786 x 525.
#   Display/Cabecalho e Display/Rodape   a posição, a letra e a cor.
# O painel inteiro é ampliado 1,4x (a escala do nó) e fica no meio da tela,
# abaixo da plaquinha do título.

const COR_AMARELO := Color(1.0, 0.85, 0.0)
const COR_CERTO := Color.GREEN
const COR_ERRO := Color(1.0, 0.35, 0.3)
const COR_TEXTO := Color(0.9, 0.95, 1.0)
const COR_CABECALHO := Color(0.56, 0.78, 1.0, 0.9)

## Quanto um aviso fica no rodapé antes de o texto de sempre voltar.
const DURACAO_DO_AVISO := 3.2

var _texto_de_sempre: String = ""
var _texto: String = ""
## Quanto falta para o aviso sair (0 = não há aviso).
var _aviso: float = 0.0

@onready var display: Control = $Display
@onready var cabecalho: Label = $Display/Cabecalho
@onready var conteudo: Control = $Display/Conteudo
@onready var rodape: Label = $Display/Rodape


func _ready() -> void:
	_texto_de_sempre = rodape.text
	_texto = rodape.text


func _process(delta: float) -> void:
	if _aviso > 0.0:
		_aviso -= delta
		if _aviso <= 0.0:
			voltar_rodape()


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

func definir_cabecalho(texto: String) -> void:
	cabecalho.text = texto


## O texto de sempre do rodapé. Um aviso que estiver na tela sai.
func definir_rodape(texto: String) -> void:
	_texto_de_sempre = texto
	voltar_rodape()


## Um aviso no rodapé, na cor pedida; depois de "duracao" o texto de sempre
## volta. Com duração 0 ou menos, o aviso fica até o próximo definir_rodape.
func avisar(texto: String, cor: Color = COR_ERRO, duracao: float = DURACAO_DO_AVISO) -> void:
	_texto = texto
	_aviso = duracao if duracao > 0.0 else -1.0
	rodape.add_theme_color_override("font_color", cor)
	rodape.text = texto


func voltar_rodape() -> void:
	_aviso = 0.0
	_texto = _texto_de_sempre
	rodape.remove_theme_color_override("font_color")
	rodape.text = _texto


## O que o rodapé está dizendo agora.
func texto_do_rodape() -> String:
	return _texto


## Há um aviso no rodapé agora?
func avisando() -> bool:
	return _aviso != 0.0


## A entrada da atividade: o conteúdo aparece subindo um pouco.
func aparecer() -> void:
	display.position.y = 12.0
	display.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(display, "position:y", 0.0, 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(display, "modulate:a", 1.0, 0.2)


## A área do conteúdo, na tela do jogo.
func retangulo_do_conteudo() -> Rect2:
	return display.get_global_rect()
