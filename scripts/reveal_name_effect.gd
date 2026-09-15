extends Node

## Autoload that watches for the "reveal_name" Dialogic variable and plays a
## flashy animation on the speaker name label when it changes (e.g. when the
## cientista is revealed to be Dr. Chico).
##
## Also keeps the speaker name label aligned to the right whenever the
## cientista/Dr. Chico is talking, and to the left for everyone else.

func _ready() -> void:
	call_deferred("_connect_to_dialogic")


func _connect_to_dialogic() -> void:
	Dialogic.VAR.variable_was_set.connect(_on_variable_was_set)
	Dialogic.Text.speaker_updated.connect(_on_speaker_updated)


func _on_speaker_updated(character: DialogicCharacter) -> void:
	var alinhar_direita := character != null and character.resource_path.get_file().get_basename() == "cientista"

	for name_label in get_tree().get_nodes_in_group("dialogic_name_label"):
		var panel := name_label.get_parent()
		if not (panel is Control):
			continue
		if alinhar_direita:
			panel.anchor_left = 1.0
			panel.anchor_right = 1.0
			panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		else:
			panel.anchor_left = 0.0
			panel.anchor_right = 0.0
			panel.grow_horizontal = Control.GROW_DIRECTION_END


func _on_variable_was_set(info: Dictionary) -> void:
	if info.get("variable") != "reveal_name":
		return

	for name_label in get_tree().get_nodes_in_group("dialogic_name_label"):
		_play_reveal_effect(name_label)


func _play_reveal_effect(name_label: Control) -> void:
	name_label.pivot_offset = name_label.size / 2.0

	var base_color: Color = name_label.self_modulate
	var flash_color := Color(1.0, 0.9, 0.3, 1.0)

	var tween := name_label.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(name_label, "scale", Vector2(1.4, 1.4), 0.35).from(Vector2.ONE)
	tween.chain().tween_property(name_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)

	tween.tween_property(name_label, "self_modulate", flash_color, 0.15).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_property(name_label, "self_modulate", base_color, 0.5).set_trans(Tween.TRANS_SINE)
