extends AnimatedSprite2D

# Ícone de tecla/botão: usa "autoplay" e a animação "default" em loop
# (configurados direto no nó, no Inspector) para ficar animando sozinho o
# tempo todo. Este script só garante que ela está tocando quando o ícone
# aparece (chamado por quem controla a visibilidade, ex: porta_simulador.gd).

func reiniciar() -> void:
	if sprite_frames and sprite_frames.has_animation("default"):
		play("default")
