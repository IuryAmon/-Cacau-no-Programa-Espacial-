extends Node2D

signal finalizou_fala

var label = null
var audio_player = null
var fundo = null 
var esta_escrevendo : bool = false
var pulou_fala : bool = false
var texto_completo : String = ""
var pode_receber_input : bool = false # Trava de segurança contra o clique inicial

func _ready() -> void:
	hide()
	add_to_group("grupo_caixa_player")
	label = find_child("Label", true, false)
	audio_player = find_child("AudioStreamPlayer2D", true, false)
	fundo = find_child("NinePatchRect", true, false)
	if not fundo: fundo = find_child("Panel", true, false)

func exibir_fala(texto: String) -> void:
	if label:
		texto_completo = texto
		label.text = texto
		label.visible_characters = 0
		
		esta_escrevendo = true
		pulou_fala = false
		pode_receber_input = false # Bloqueia o input por um instante
		show()
		Interacao.marcar_tela_aberta(self, true)
		
		# Espera um frame do jogo para ignorar o clique que abriu a caixa
		await get_tree().process_frame
		pode_receber_input = true
		
		_processar_escrita(texto)

func _processar_escrita(texto: String) -> void:
	for i in range(texto.length()):
		if not is_visible(): 
			esta_escrevendo = false
			return
		
		# Se o jogador apertou E de novo, sai do loop e mostra tudo
		if pulou_fala:
			label.visible_characters = texto.length()
			break
			
		label.visible_characters = i + 1
		
		var char_atual = texto[i]
		if char_atual != " " and char_atual != "\n" and audio_player:
			audio_player.pitch_scale = randf_range(0.8, 1.2)
			audio_player.play()

		await get_tree().create_timer(0.09).timeout

	esta_escrevendo = false

func _input(event: InputEvent) -> void:
	# Só aceita o clique se a caixa estiver aberta e a trava de segurança liberada
	if not is_visible() or not pode_receber_input:
		return
		
	if event.is_action_pressed("interact"):
		# Consome o input para não dar loop nas áreas. O set_input_as_handled()
		# só segura quem escuta _unhandled_input; quem olha o Input direto no
		# _process (gaiolas, itens, NPCs) é barrado pelo Interacao.
		get_viewport().set_input_as_handled()
		Interacao.consumir()

		if esta_escrevendo:
			# Se ainda está digitando, pula para o final
			pulou_fala = true
		else:
			# Se já acabou de digitar tudo, fecha a caixa
			esconder()

func esconder() -> void:
	esta_escrevendo = false
	pulou_fala = false
	pode_receber_input = false
	hide()
	Interacao.marcar_tela_aberta(self, false)
	finalizou_fala.emit()
