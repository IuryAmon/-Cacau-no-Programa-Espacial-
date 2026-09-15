extends Node2D

# Prévia da CaixaEletrica: abre uma janelinha, quebra a caixa e salva quadros
# em PNG para conferir o visual das faíscas sem abrir o editor.
#
#   godot --path . --resolution 480x270 res://tools/previa_caixa_eletrica.tscn -- <pasta_de_saida>

const CENA := "res://scenes/fases/componentes/caixa_eletrica.tscn"

var _destino := "user://previa"


func _ready() -> void:
	var argumentos := OS.get_cmdline_user_args()
	if argumentos.size() > 0:
		_destino = argumentos[0]
	DirAccess.make_dir_recursive_absolute(_destino)

	var fundo := ColorRect.new()
	fundo.color = Color(0.11, 0.12, 0.15)
	fundo.size = Vector2(2000, 2000)
	fundo.position = Vector2(-1000, -1000)
	fundo.z_index = -20
	add_child(fundo)

	var camera := Camera2D.new()
	camera.zoom = Vector2(3, 3)
	camera.position = Vector2(0, -10)
	add_child(camera)
	camera.make_current()

	var caixa: CaixaEletrica = (load(CENA) as PackedScene).instantiate()
	add_child(caixa)
	await get_tree().process_frame

	await _tirar("1_intacta")
	caixa.atingir_bumerangue()
	await _tirar("2_impacto")
	await _esperar(0.10)
	await _tirar("3_impacto_tarde")
	await _esperar(0.10)
	await _tirar("4_abrindo")

	# Espera o arco começar e fotografa o estalo quadro a quadro.
	var arco: CPUParticles2D = caixa.get_node("FaiscasArco")
	while not arco.emitting:
		await get_tree().process_frame
	for i in 6:
		await _tirar("5_arco_%d" % i)
		await _esperar(0.05)

	print("PNGs em: %s" % _destino)
	await _medir_ritmo(caixa, 12.0)
	get_tree().quit()


## Cronometra os estalos do arco por alguns segundos, para conferir no número
## o espaço entre um choque e outro.
func _medir_ritmo(caixa: CaixaEletrica, segundos: float) -> void:
	var som: AudioStreamPlayer2D = caixa.get_node("SomEletricidade")
	var fios: CPUParticles2D = caixa.get_node("FiosSoltos")
	var inicio := Time.get_ticks_msec()
	var ultimo := -1.0
	var tocando := som.playing
	print("\nRITMO DO ARCO (intervalo configurado: %.2fs a %.2fs)"
		% [caixa.intervalo_arco_min, caixa.intervalo_arco_max])
	while Time.get_ticks_msec() - inicio < segundos * 1000.0:
		await get_tree().process_frame
		if som.playing and not tocando:
			var agora := (Time.get_ticks_msec() - inicio) / 1000.0
			var gap := "primeiro" if ultimo < 0.0 else "+%.2fs desde o anterior" % (agora - ultimo)
			print("  estalo em %5.2fs  (%s)  fios chuviscando: %s"
				% [agora, gap, fios.emitting])
			ultimo = agora
		tocando = som.playing


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


func _tirar(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var imagem := get_viewport().get_texture().get_image()
	imagem.save_png("%s/%s.png" % [_destino, nome])
