class_name Barreira
extends StaticBody2D

# Referências aos nós filhos
@onready var anim = $AnimatedSprite2D
@onready var colisor = $CollisionShape2D
## O clarão vermelho do campo de energia (scripts/luz/luz_pontual.gd): acende
## com o escuro da fase e apaga junto com o laser.
@onready var _luz: LuzPontual = get_node_or_null("LuzDoLaser")

func _ready():
	# Já foi desligada antes (a cena recarregou por morte ou por troca de fase):
	# nasce desligada, sem repetir a animação de abertura. O sinal do receptor
	# não volta a ser emitido numa cena nova, então ela se lembra sozinha.
	if EstadoMundo.ja_feito(self):
		if colisor:
			colisor.set_deferred("disabled", true)
		if anim and anim.sprite_frames and anim.sprite_frames.has_animation("desativado"):
			anim.play("desativado")
		if _luz:
			_luz.acesa = false
		return

	# Assim que o jogo começa, garante que a barreira está na animação "ativado"
	anim.play("ativado")

# Só o campo de energia (o CollisionShape2D) machuca. Outras formas de colisão
# postas na barreira — como o CollisionPolygon2D do degrau do asset — são só
# chão/parede: o player encosta e sobe sem levar dano.
func causa_dano(forma: Object) -> bool:
	return forma == colisor

# Essa função será chamada pelo sinal do seu Receptor
func abrir_passagem():
	print("Barreira: Recebi o sinal! Iniciando animação de abertura...")
	EstadoMundo.marcar_feito(self)

	# 1. Desativa o colisor imediatamente para o jogador já conseguir passar
	if colisor:
		colisor.set_deferred("disabled", true)
	
	# 2. Toca a animação de transição
	if anim:
		anim.play("desativando")
	if _luz:
		_luz.acesa = false

func _on_animated_sprite_2d_animation_finished():
	# Quando a animação de transição ("desativando") chegar ao fim...
	if anim.animation == "desativando":
		# Muda para a animação final de "desativado" (pode ser o rastro ou sumiço total)
		anim.play("desativado")
		
		# Opcional: se na animação "desativado" você quiser que ela suma para sempre do mapa, 
		# você pode descomentar a linha abaixo tirando o '#':
		# queue_free()
