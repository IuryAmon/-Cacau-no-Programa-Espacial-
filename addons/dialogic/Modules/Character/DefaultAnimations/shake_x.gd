extends DialogicAnimation

func animate() -> void:
	var tween := (node.create_tween() as Tween)
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	var strength: float = node.get_viewport().size.x/250
	var bound_multitween := DialogicUtil.multitween.bind(node, "position", "animation_shake_x")

	# Number of snaps (left/right) packed into `time`. Higher = more shakes per second.
	var oscillations := 10
	var segment_time: float = time / oscillations
	for i in oscillations:
		var direction := 1 if i % 2 == 0 else -1
		var is_last := i == oscillations - 1
		var target := Vector2() if is_last else Vector2(direction, 0) * strength
		tween.tween_method(bound_multitween, Vector2(), target, segment_time)

	tween.finished.connect(emit_signal.bind('finished_once'))

func _get_named_variations() -> Dictionary:
	return {
		"shake x": {"type": AnimationType.ACTION},
	}
