extends Sprite2D

# --- O PAINEL AO LADO DO PORTÃO DE ROLAMENTO ---
#
# Os quatro quadradinhos vermelhos do painel (o tile 11,6 do Buildings.png)
# ficam verdes, um por um de cima para baixo, enquanto o portão sobe — o último
# no clunk da trava — e voltam todos ao vermelho no baque do portão fechando.
# O verde é o do painel vizinho na mesma folha (tile 12,6): cada Luz é o
# recorte de um quadradinho verde posto em cima de um vermelho.
#
# Quem manda é o SpritePorta do portão (a porta irmã deste nó): o painel só
# escuta as trocas de animação e de quadro dele, então acompanha sozinho a
# entrada, a chegada pela porta e qualquer mudança no tempo dos quadros.

## Em que quadro do "abrindo" cada luz acende, de cima para baixo.
@export var quadros_que_acendem: PackedInt32Array = [0, 4, 7, 10]

@onready var _porta: AnimatedSprite2D = get_node_or_null(^"../SpritePorta")
@onready var _luzes: Array = get_children().filter(func(n: Node) -> bool: return n is Sprite2D)


func _ready() -> void:
	if _porta == null:
		push_warning("PainelDoPortao: falta o SpritePorta ao lado do painel.")
		return
	_porta.animation_changed.connect(_atualizar)
	_porta.frame_changed.connect(_atualizar)
	_atualizar()


## Quantas luzes estão verdes agora.
func acesas() -> int:
	var total := 0
	for luz in _luzes:
		total += 1 if (luz as Sprite2D).visible else 0
	return total


func _atualizar() -> void:
	var verdes := 0
	match _porta.animation:
		&"abrindo":
			for quadro in quadros_que_acendem:
				if _porta.frame >= quadro:
					verdes += 1
		&"fechando":
			# Destrancado enquanto desce; tranca no quadro do baque, o último.
			var ultimo := _porta.sprite_frames.get_frame_count(&"fechando") - 1
			verdes = 0 if _porta.frame >= ultimo else quadros_que_acendem.size()
	for i in _luzes.size():
		(_luzes[i] as Sprite2D).visible = i < verdes
