class_name ComputadorDoLaboratorio
extends TextureRect

# --- A TELA DE COMPUTADOR DAS ATIVIDADES DO LABORATÓRIO ---
#
# O mesmo monitor dos puzzles da fase 1 (o do maçarico e o do bumerangue):
# a moldura "tela_computador.png", o vidro com as linhas de varredura por cima,
# o cabeçalho miúdo no alto, o rodapé em que o terminal fala e o LED do canto.
# Nos puzzles da história cada cena monta isso de novo; no Laboratório, o
# "Monte seu átomo", o quiz e o balanceamento usam esta peça pronta
# (scenes/laboratorio/computador.tscn) e põem só o conteúdo deles dentro.
#
# O RODAPÉ é a voz do terminal. Ele tem um texto de sempre (definir_rodape), com
# o cursor piscando no fim, e pode dar um aviso (avisar): o aviso toma o lugar
# do texto por alguns segundos, na cor pedida, e o texto de sempre volta.
#
# COMO EDITAR NO EDITOR (na cena de cada atividade, com "Filhos Editáveis"):
#   Display/Conteudo   é aqui dentro que a atividade põe as peças dela. As
#                      medidas são as do vidro: 786 x 525.
#   Display/Cabecalho e Display/Rodape   a posição, a letra e a cor.
#   Display/Aura       o tom do vidro.
#   Led                a luzinha do canto da moldura.
# O monitor inteiro é ampliado 1,2x (a escala do nó), como nos puzzles.

const COR_AMARELO := Color(1.0, 0.85, 0.0)
const COR_CERTO := Color.GREEN
const COR_ERRO := Color(1.0, 0.35, 0.3)
const COR_TEXTO := Color(0.9, 0.95, 1.0)
const COR_CABECALHO := Color(0.56, 0.78, 1.0, 0.9)
const COR_LED_PARADO := Color(0.9, 0.12, 0.1)
const COR_LED_ATENCAO := Color(1.0, 0.8, 0.1)
const COR_LED_CERTO := Color(0.35, 0.95, 0.45)
const COR_LED_AZUL := Color(0.3, 0.75, 1.0)

## Quanto um aviso fica no rodapé antes de o texto de sempre voltar.
const DURACAO_DO_AVISO := 3.2

## O LED pisca (como o dos puzzles enquanto esperam resposta) ou fica aceso.
var led_piscando: bool = true

var _tempo: float = 0.0
var _texto_de_sempre: String = ""
var _cursor_de_sempre: bool = true
var _texto: String = ""
var _com_cursor: bool = true
## Quanto falta para o aviso sair (0 = não há aviso).
var _aviso: float = 0.0

@onready var display: Control = $Display
@onready var cabecalho: Label = $Display/Cabecalho
@onready var conteudo: Control = $Display/Conteudo
@onready var rodape: Label = $Display/Rodape
@onready var aura: ColorRect = $Display/Aura
@onready var led: ColorRect = $Led


func _ready() -> void:
	_texto_de_sempre = rodape.text
	_texto = rodape.text


func _process(delta: float) -> void:
	_tempo += delta
	led.modulate.a = 1.0 if not led_piscando or fmod(_tempo, 1.1) >= 0.5 else 0.55
	if _aviso > 0.0:
		_aviso -= delta
		if _aviso <= 0.0:
			voltar_rodape()
	var escrito := _texto + ("_" if _com_cursor and fmod(_tempo, 1.0) < 0.5 else "")
	if rodape.text != escrito:
		rodape.text = escrito


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

func definir_cabecalho(texto: String) -> void:
	cabecalho.text = texto


## O texto de sempre do rodapé. Um aviso que estiver na tela sai.
func definir_rodape(texto: String, com_cursor: bool = true) -> void:
	_texto_de_sempre = texto
	_cursor_de_sempre = com_cursor
	voltar_rodape()


## Um aviso no rodapé, na cor pedida; depois de "duracao" o texto de sempre
## volta. Com duração 0 ou menos, o aviso fica até o próximo definir_rodape.
func avisar(texto: String, cor: Color = COR_ERRO, duracao: float = DURACAO_DO_AVISO) -> void:
	_texto = texto
	_com_cursor = false
	_aviso = duracao if duracao > 0.0 else -1.0
	rodape.add_theme_color_override("font_color", cor)
	rodape.text = texto


func voltar_rodape() -> void:
	_aviso = 0.0
	_texto = _texto_de_sempre
	_com_cursor = _cursor_de_sempre
	rodape.remove_theme_color_override("font_color")


## O que o rodapé está dizendo agora (sem o cursor que pisca).
func texto_do_rodape() -> String:
	return _texto


## Há um aviso no rodapé agora?
func avisando() -> bool:
	return _aviso != 0.0


func definir_led(cor: Color, piscando: bool = false) -> void:
	led.color = cor
	led_piscando = piscando


## A tela "liga" como monitor de tubo: uma linha que abre na vertical.
func ligar() -> void:
	display.scale = Vector2(1.0, 0.02)
	display.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(display, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(display, "modulate:a", 1.0, 0.16)


## O retângulo do vidro, na tela do jogo.
func retangulo_do_vidro() -> Rect2:
	return display.get_global_rect()
