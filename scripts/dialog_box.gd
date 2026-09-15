extends Node2D

@onready var label = $MarginContainer/MarginContainer/Label
@onready var audio_player = $AudioStreamPlayer2D

func _ready() -> void:
	hide()
	print("DIAGNÓSTICO [Caixa]: Pronta no cenário.")

const CARACTERES_POR_SEGUNDO := 25.0  # velocidade da digitação (chars/seg)

func mostrar(texto: String) -> void:
	print("DIAGNÓSTICO [Caixa]: Recebi comando para mostrar: ", texto)
	if label:
		label.text = texto
		label.visible_ratio = 0.0
		show()

		# Duração proporcional ao tamanho do texto, para a velocidade de
		# digitação ser sempre a mesma independente do texto ser curto ou longo.
		var duracao = max(0.3, texto.length() / CARACTERES_POR_SEGUNDO)

		var tween = create_tween()
		tween.tween_property(label, "visible_ratio", 1.0, duracao).set_trans(Tween.TRANS_LINEAR)

		if audio_player:
			_tocar_sons_datilografia()
	else:
		print("ERRO [Caixa]: Label não encontrado!")

func _tocar_sons_datilografia() -> void:
	while label.visible_ratio < 1.0:
		if not is_visible(): break
		if audio_player:
			audio_player.pitch_scale = randf_range(0.9, 1.1)
			audio_player.play()
		await get_tree().create_timer(0.08).timeout

func esconder() -> void:
	hide()
	if audio_player:
		audio_player.stop()
