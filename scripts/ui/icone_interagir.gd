@tool
class_name IconeInteragir
extends AnimatedSprite2D

# --- O BOTÃO DE INTERAGIR DESENHADO NO CENÁRIO ---
#
# O mesmo desenho de tecla que a samambaia e o jaleco já usam (a folha
# gdb-keyboard-2 / gdb-playstation-2, pulsando em 4 quadros), mas trocando
# sozinho conforme quem está jogando:
#
#   teclado e mouse  ->  a tecla E
#   controle na mão  ->  o botão □
#
# Quem usa: a porta de metal e a chapa soldada. Antes elas escreviam "[E]" em
# um Label; o desenho lê melhor e é o mesmo da samambaia, então o jogo inteiro
# pede o botão do mesmo jeito.
#
# COMO USAR: instancie a cena componentes/icone_interagir.tscn onde o aviso
# deve aparecer e ligue/desligue o "visible" dela como faria com qualquer
# sprite — a troca teclado/controle se vira sozinha.
#
# A ESCALA: os dois desenhos moram em quadros de 16 px, mas a tecla ocupa mais
# quadro que o botão redondo. Por isso o controle ganha um empurrãozinho a
# mais — senão o □ aparece visivelmente menor que o E no mesmo lugar. É a
# mesma proporção que a samambaia usa no world1 (2,625 e 3,17).

const CENA := "res://scenes/fases/componentes/icone_interagir.tscn"

const ANIM_TECLADO := &"teclado"
const ANIM_CONTROLE := &"controle"

## Quanto o desenho do controle é ampliado a mais que o do teclado, para os
## dois ocuparem o mesmo tanto de tela.
const COMPENSACAO_DO_CONTROLE := 1.208

## Tamanho do desenho no teclado (o do controle sai daqui vezes a compensação).
@export var escala_do_icone: float = 2.625:
	set(valor):
		escala_do_icone = valor
		_aplicar()


func _ready() -> void:
	_aplicar()
	if Engine.is_editor_hint():
		return
	var controle := get_node_or_null(^"/root/Controle")
	if controle:
		controle.mudou.connect(_ao_trocar_dispositivo)


func _ao_trocar_dispositivo(_em_uso: bool) -> void:
	_aplicar()


## Redesenha do zero — quem esconde e mostra o ícone chama isto para a pulsação
## recomeçar do primeiro quadro em vez de continuar de onde parou.
func reiniciar() -> void:
	_aplicar()
	frame = 0


func _aplicar() -> void:
	if sprite_frames == null:
		return
	var no_controle := _controle_em_uso()
	var anim := ANIM_CONTROLE if no_controle else ANIM_TECLADO
	if not sprite_frames.has_animation(anim):
		return
	var fator := COMPENSACAO_DO_CONTROLE if no_controle else 1.0
	scale = Vector2.ONE * escala_do_icone * fator
	if animation != anim or not is_playing():
		play(anim)


## Sempre falso no editor: o autoload Controle não existe lá.
func _controle_em_uso() -> bool:
	if Engine.is_editor_hint():
		return false
	var controle := get_node_or_null(^"/root/Controle")
	return controle != null and controle.em_uso
