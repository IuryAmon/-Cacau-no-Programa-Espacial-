class_name PopupFX
extends RefCounted

# Efeito de "pop" (aparece crescendo com leve estouro, some encolhendo) para os
# balões de emote (AnimatedSprite2D) usados no jogo (Exclamação, Coração, etc).

static func mostrar(sprite: AnimatedSprite2D, animacao: String = "default") -> void:
	if not sprite:
		return

	var escala_alvo = _obter_escala_base(sprite)
	_matar_tween_ativo(sprite)

	sprite.scale = Vector2.ZERO
	sprite.visible = true
	sprite.play(animacao)

	var tween = sprite.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sprite.set_meta("_popupfx_tween", tween)
	tween.tween_property(sprite, "scale", escala_alvo, 0.3)
	await tween.finished

static func esconder(sprite: AnimatedSprite2D) -> void:
	if not sprite or not sprite.visible:
		return

	var escala_base = _obter_escala_base(sprite)
	_matar_tween_ativo(sprite)

	var tween = sprite.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	sprite.set_meta("_popupfx_tween", tween)
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.25)
	await tween.finished

	sprite.visible = false
	sprite.stop()
	sprite.scale = escala_base

# Guarda (uma única vez) a escala "normal" do sprite, para que mostrar/esconder
# sempre animem em relação a esse valor fixo — e não à escala atual, que pode
# estar no meio de uma animação anterior (ex: jogador sai e volta rápido da área).
static func _obter_escala_base(sprite: AnimatedSprite2D) -> Vector2:
	if sprite.has_meta("_popupfx_escala_base"):
		return sprite.get_meta("_popupfx_escala_base")

	var escala = sprite.scale
	if escala == Vector2.ZERO:
		escala = Vector2.ONE
	sprite.set_meta("_popupfx_escala_base", escala)
	return escala

# Cancela qualquer tween de escala ainda em andamento antes de iniciar um novo,
# evitando que "mostrar" e "esconder" concorram entre si.
static func _matar_tween_ativo(sprite: AnimatedSprite2D) -> void:
	if sprite.has_meta("_popupfx_tween"):
		var tween_ativo = sprite.get_meta("_popupfx_tween")
		if tween_ativo and tween_ativo.is_valid():
			tween_ativo.kill()
