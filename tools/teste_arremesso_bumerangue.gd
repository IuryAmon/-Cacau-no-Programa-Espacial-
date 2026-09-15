extends SceneTree

# Teste headless do gesto de arremesso: confere que a animação existe, que ela
# entra no sprite quando o bumerangue é jogado e que ele nasce na ALTURA DA MÃO
# (e não da cabeça). Rodar com:
#   godot --headless --script res://tools/teste_arremesso_bumerangue.gd

const CENA_PLAYER := "res://scenes/player.tscn"


func _initialize() -> void:
	var falhas := 0

	var player: CharacterBody2D = load(CENA_PLAYER).instantiate()
	root.add_child(player)
	await process_frame
	await process_frame

	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")

	# 1. A animação chegou no SpriteFrames?
	if sprite.sprite_frames.has_animation("jogando_bumerangue"):
		var n := sprite.sprite_frames.get_frame_count("jogando_bumerangue")
		print("OK  animação 'jogando_bumerangue' presente, %d quadros" % n)
		if n != 7:
			print("FALHA  esperava 7 quadros da folha 672x96, veio %d" % n)
			falhas += 1
	else:
		print("FALHA  animação 'jogando_bumerangue' não existe no player")
		falhas += 1

	# 2. O gesto toma conta do sprite quando é chamado.
	player.tocar_arremesso_bumerangue(1.0)
	if sprite.animation == "jogando_bumerangue" and sprite.frame == 0:
		print("OK  o gesto entrou no sprite a partir do quadro 0")
	else:
		print("FALHA  sprite ficou em '%s' quadro %d" % [sprite.animation, sprite.frame])
		falhas += 1

	# Mirando para a esquerda o braço tem que virar junto.
	player.cancelar_arremesso_bumerangue()
	player.tocar_arremesso_bumerangue(-1.0)
	if sprite.flip_h:
		print("OK  arremesso para a esquerda espelhou a personagem")
	else:
		print("FALHA  arremesso para a esquerda não espelhou")
		falhas += 1

	# 3. Onde o bumerangue nasce: tem que ser na mão, e não no alto da cabeça.
	# Referências em coordenadas locais do player (origem = meio do corpo):
	# topo da cabeça ~-51, punho ~+2, pé ~+43 (ver bumerangue.gd).
	var altura: float = Bumerangue.ALTURA_MAO.y
	print("ALTURA_MAO.y = %.1f  (punho medido na folha: ~+2, cabeça: -51..-36)" % altura)
	if altura > -20.0:
		print("OK  a saída está na altura do tronco/mão, não da cabeça")
	else:
		print("FALHA  a saída ainda está na cabeça (%.1f)" % altura)
		falhas += 1

	player.queue_free()
	await process_frame
	print("\n%s (%d falha(s))" % ["TUDO CERTO" if falhas == 0 else "COM FALHAS", falhas])
	quit(falhas)
