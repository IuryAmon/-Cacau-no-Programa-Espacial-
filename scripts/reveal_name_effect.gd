extends Node

## Autoload that watches for the "reveal_name" Dialogic variable and plays a
## flashy animation on the speaker name label when it changes (e.g. when the
## cientista is revealed to be Dr. Chico).
##
## Also keeps the speaker name label aligned to the right whenever the
## cientista/Dr. Chico is talking, and to the left for everyone else — except
## in the rocket scene at the mirante (TIMELINES_A_DIREITA), where Cacau's
## portrait is on the right and her name goes with it. The "Uau..." line is
## the exception (FALAS_SO_COM_O_RETRATO): only the portrait is on the right.

## Timelines em que o retrato de quem fala fica à direita, e o nome junto.
const TIMELINES_A_DIREITA: Array[String] = ["cacau_ve_foguete", "cacau_anoitecendo"]
## Falas dessas timelines em que só o retrato vai para a direita: o nome fica
## no lugar de sempre, à esquerda.
const FALAS_SO_COM_O_RETRATO: Array[String] = ["Uau..."]

func _ready() -> void:
	call_deferred("_connect_to_dialogic")


func _connect_to_dialogic() -> void:
	Dialogic.VAR.variable_was_set.connect(_on_variable_was_set)
	Dialogic.Text.speaker_updated.connect(_on_speaker_updated)
	# O speaker_updated só avisa quando MUDA quem fala; o lado do nome também
	# pode mudar de uma fala para outra da mesma personagem.
	Dialogic.Text.about_to_show_text.connect(func(info: Dictionary) -> void:
		_on_speaker_updated(info.get("character")))


func _on_speaker_updated(character: DialogicCharacter) -> void:
	var alinhar_direita := character != null and character.resource_path.get_file().get_basename() == "cientista"
	if Dialogic.current_timeline != null \
			and Dialogic.current_timeline.resource_path.get_file().get_basename() in TIMELINES_A_DIREITA:
		alinhar_direita = not _fala_atual() in FALAS_SO_COM_O_RETRATO

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


## O texto da fala que está entrando agora ("" se o evento não for uma fala).
func _fala_atual() -> String:
	var eventos: Array = Dialogic.current_timeline_events
	var i: int = Dialogic.current_event_idx
	if i < 0 or i >= eventos.size() or not "text" in eventos[i]:
		return ""
	return str(eventos[i].text).strip_edges()


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
