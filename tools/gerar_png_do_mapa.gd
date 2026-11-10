extends Node

# --- O MAPA EM PNG: SÓ A PLANTA, SEM O PAPEL ---
#
# Desenha a planta do mapa do caderno num PNG de fundo transparente: as salas e
# os corredores, todos como já explorados, nas cores do esquema das fases — sem
# o papel, o quadriculado, o título, o carimbo, a Cacau, os objetivos, as
# fichinhas dos elementos e os cadeados. O desenho é o mesmo da aba MAPA
# (FolhaDoMapa), recortado rente à planta, em ESCALA vezes o tamanho do jogo
# (cada pixel repetido, sem borrar). Saem dois arquivos:
#
#   mapa.png             as salas, os corredores e os nomes das salas
#   mapa_sem_nomes.png   só as salas e os corredores
#
# Para refazer depois de mexer na planta (scripts/planta_do_mapa.gd):
#
#   godot --path . --windowed --resolution 800x450 res://tools/gerar_png_do_mapa.tscn
#
# Sai em docs/; "-- <pasta>" no fim do comando salva em outra pasta. Precisa
# abrir a janela: em --headless nada é desenhado e o PNG sairia vazio.

const PASTA_PADRAO := "res://docs"
## Quantas vezes o tamanho do mapa no jogo.
const ESCALA := 2


## A FolhaDoMapa sem o papel: só as salas, os corredores e, se pedir, os nomes
## das salas (o título do mapa fica de fora).
class PlantaSemPapel extends FolhaDoMapa:
	## Os lados para onde o contorno do nome se espalha (vezes a grossura).
	const CONTORNO := [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0),
		Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]

	var com_nomes := true

	func _draw() -> void:
		for sala in PlantaDoMapa.AREAS:
			_desenhar_sala(sala)
		for passagem in PlantaDoMapa.PASSAGENS:
			_desenhar_passagem(passagem)
		if not com_nomes:
			return
		for item in rotulos():
			var id := String(item.get("sala", ""))
			if not item.has("texto") or id.is_empty():
				continue
			# O nome do lado de fora da sala (a torre, o corredor) não tem mais o
			# papel atrás: ganha um contorno da cor dele, para ler em qualquer
			# fundo. 1 px na letra pequena, 2 na grande.
			if PlantaDoMapa.area(id).has("nome_fora"):
				var grossura := maxf(1.0, roundf(item["tam"] / float(TAM_PEQUENO)))
				for lado: Vector2 in CONTORNO:
					_escrever(item["pos"] + lado * grossura, item["texto"], item["tam"], PAPEL)
			_desenhar_item(item, 0.0)


func _ready() -> void:
	var argumentos := OS.get_cmdline_user_args()
	var destino: String = argumentos[0] if argumentos.size() > 0 else PASTA_PADRAO
	DirAccess.make_dir_recursive_absolute(destino)
	for com_nomes: bool in [true, false]:
		var imagem := await _desenhar(com_nomes)
		var caminho := destino.path_join("mapa.png" if com_nomes else "mapa_sem_nomes.png")
		var erro := imagem.save_png(caminho)
		if erro == OK:
			print("salvo: %s (%d x %d)" % [ProjectSettings.globalize_path(caminho),
				imagem.get_width(), imagem.get_height()])
		else:
			printerr("não deu para salvar %s (erro %d)" % [caminho, erro])
	get_tree().quit()


## A planta desenhada numa tela transparente, recortada rente ao desenho.
func _desenhar(com_nomes: bool) -> Image:
	var tela := SubViewport.new()
	tela.size = Vector2i(FolhaDoMapa.TAMANHO)
	tela.transparent_bg = true
	tela.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(tela)
	var planta := PlantaSemPapel.new()
	planta.com_nomes = com_nomes
	tela.add_child(planta)
	var todas := {}
	for sala in PlantaDoMapa.AREAS:
		todas[sala["id"]] = true
	planta.estado = {"exploradas": todas}

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagem := tela.get_texture().get_image()
	tela.queue_free()
	imagem = imagem.get_region(imagem.get_used_rect())
	_cor_inteira(imagem)
	imagem.resize(imagem.get_width() * ESCALA, imagem.get_height() * ESCALA, Image.INTERPOLATE_NEAREST)
	return imagem


## A tela transparente guarda a cor do que é meio transparente (a sombra das
## salas) já multiplicada pela opacidade, e no PNG ela sairia quase preta: aqui
## ela volta a ser a cor inteira.
static func _cor_inteira(imagem: Image) -> void:
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor := imagem.get_pixel(x, y)
			if cor.a > 0.0 and cor.a < 1.0:
				imagem.set_pixel(x, y, Color(cor.r / cor.a, cor.g / cor.a, cor.b / cor.a, cor.a))
