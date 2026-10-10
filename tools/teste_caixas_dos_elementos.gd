extends Node

# Teste da arte das caixas dos elementos (scripts/ui/caixas_dos_elementos.gd) e
# do nó que as mostra (scripts/ui/caixa_elemento.gd).
#
#   * a caixa montada do hidrogênio é IGUAL, pixel por pixel, à arte do caderno
#     ("Hidrogênio tabela periódica.png"), e a do oxigênio à do puzzle;
#   * as 118 têm o tamanho da arte (76 x 92), a mesma moldura e a mesma tinta
#     única, sem pixel meio transparente;
#   * em nenhuma das 118 o número, o símbolo ou a massa encosta na moldura, um
#     no outro, nem entra no vão do nome mais do que a perna de uma letra;
#   * o nome de todo elemento cabe no vão da caixa ampliada, no tamanho do
#     caderno (letra de 11 ampliada 1,5x na escala 2);
#   * a caixa "57-71" (a que aponta para a fileira de baixo) é só moldura e
#     texto;
#   * o nó CaixaElemento toma o tamanho da escala e aceita de 0 (vazia) a 118.
#
#   godot --headless --path . res://tools/teste_caixas_dos_elementos.tscn
#
# Com "-- --capturas=<pasta>" (e SEM --headless) salva a folha das 118 e uma
# fileira de caixas ampliadas, para conferir a olho.

const ARTE_H := "res://assets/caderno de anotaçõess/Hidrogênio tabela periódica.png"
const ARTE_O := "res://assets/caderno de anotaçõess/Oxigênio tabela periódica.png"

var _falhas := 0
var _pasta_capturas := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			_pasta_capturas = arg.trim_prefix("--capturas=")
	await get_tree().process_frame
	_testar_contra_a_arte()
	_testar_as_118()
	_testar_o_nome()
	_testar_o_no()
	await _capturar()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


## Quantos pixels diferem entre a caixa montada e a arte.
func _diferentes(z: int, caminho: String) -> int:
	var arte := (load(caminho) as Texture2D).get_image()
	if arte.is_compressed():
		arte.decompress()
	arte.convert(Image.FORMAT_RGBA8)
	var montada := CaixasDosElementos.imagem(z)
	if arte.get_size() != montada.get_size():
		return -1
	var conta := 0
	for y in arte.get_height():
		for x in arte.get_width():
			var a := arte.get_pixel(x, y)
			var b := montada.get_pixel(x, y)
			if (a.a > 0.5) != (b.a > 0.5) or (a.a > 0.5 and not a.is_equal_approx(b)):
				conta += 1
	return conta


func _testar_contra_a_arte() -> void:
	print("\n--- CONTRA A ARTE DO CADERNO ---")
	var h := _diferentes(1, ARTE_H)
	_checar(h == 0, "a caixa montada do hidrogênio é igual à arte do caderno (%d pixels diferentes)" % h)
	var o := _diferentes(8, ARTE_O)
	_checar(o == 0, "a do oxigênio é igual à arte do puzzle (%d pixels diferentes)" % o)
	_checar(CaixasDosElementos.TINTA == FaceCaderno.TINTA and CaixasDosElementos.TINTA == EstiloHUD.TINTA,
		"a tinta é a do caderno e a das fichas do HUD")
	_checar(CaixasDosElementos.VAO_DO_NOME == (PaginasCaderno.PAGINAS[3][0] as Dictionary)["vao_do_nome"],
		"o vão do nome é o mesmo da página do hidrogênio")


func _testar_as_118() -> void:
	print("\n--- AS 118 ---")
	var tamanhos_errados := PackedStringArray()
	var cores_erradas := PackedStringArray()
	var molduras_erradas := PackedStringArray()
	var apertadas := PackedStringArray()
	var miolo := CaixasDosElementos.MIOLO
	var modelo := CaixasDosElementos.imagem(1)
	var maior_simbolo := 0
	var simbolo_mais_largo := ""
	for z in range(1, 119):
		var s := Elementos.simbolo(z)
		var textura := CaixasDosElementos.textura(z)
		var img := CaixasDosElementos.imagem(z)
		if textura == null or Vector2i(textura.get_size()) != CaixasDosElementos.TAMANHO \
				or img.get_size() != CaixasDosElementos.TAMANHO:
			tamanhos_errados.append(s)
			continue
		var moldura_igual := true
		var so_tinta := true
		for y in img.get_height():
			for x in img.get_width():
				var p := img.get_pixel(x, y)
				if p.a > 0.0 and (p.a < 1.0 or not p.is_equal_approx(CaixasDosElementos.TINTA)):
					so_tinta = false
				if not miolo.has_point(Vector2i(x, y)) and not p.is_equal_approx(modelo.get_pixel(x, y)):
					moldura_igual = false
		if not so_tinta:
			cores_erradas.append(s)
		if not moldura_igual:
			molduras_erradas.append(s)

		# Cada escrita no lugar dela, com 1 px de respiro da moldura.
		var tintas := CaixasDosElementos.tintas(z)
		var respiro := miolo.grow(-1)
		var numero: Rect2i = tintas["numero"]
		var simbolo: Rect2i = tintas["simbolo"]
		var massa: Rect2i = tintas["massa"]
		if simbolo.size.x > maior_simbolo:
			maior_simbolo = simbolo.size.x
			simbolo_mais_largo = s
		var problema := ""
		for nome: String in tintas:
			if not respiro.encloses(tintas[nome]):
				problema += " %s fora %s" % [nome, tintas[nome]]
		if numero.intersects(simbolo) or simbolo.intersects(massa) or numero.intersects(massa):
			problema += " uma em cima da outra"
		# O símbolo começa na linha 22 (o topo da letra maiúscula); só o pingo
		# do i sobe mais, até a 19. A perna de um g ou de um y não desce mais
		# que 7 px além do pé.
		if simbolo.position.y < 19 or simbolo.end.y > CaixasDosElementos.PE_SIMBOLO + 7:
			problema += " símbolo %s" % simbolo
		# E o pingo do i não encosta no número atômico, que acaba na linha 18.
		for x in range(miolo.position.x, miolo.end.x):
			if img.get_pixel(x, 19).a > 0.5 and (img.get_pixel(x - 1, 18).a > 0.5 \
					or img.get_pixel(x, 18).a > 0.5 or img.get_pixel(x + 1, 18).a > 0.5):
				problema += " o símbolo encosta no número"
				break
		if numero.position.x != CaixasDosElementos.X_NUMERO or numero.position.y != 10:
			problema += " número %s" % numero
		if massa.position.y < 72 or massa.end.y > 86:
			problema += " massa %s" % massa
		if not problema.is_empty():
			apertadas.append(s + ":" + problema)
	_checar(tamanhos_errados.is_empty(), "as 118 têm 76 x 92 px %s" % [tamanhos_errados])
	_checar(cores_erradas.is_empty(), "todas numa tinta só, sem pixel meio transparente %s" % [cores_erradas])
	_checar(molduras_erradas.is_empty(), "todas com a moldura da caixa do hidrogênio %s" % [molduras_erradas])
	_checar(apertadas.is_empty(), "número, símbolo e massa cabem no lugar, sem encostar em nada %s" % [apertadas])
	print("  .     o símbolo mais largo: %s (%d px de %d)" % [simbolo_mais_largo, maior_simbolo, miolo.size.x])
	_checar(CaixasDosElementos.textura(0) == null and CaixasDosElementos.textura(119) == null,
		"fora de 1 a 118 não há caixa")
	_checar(CaixasDosElementos.textura(26) == CaixasDosElementos.textura(26), "cada caixa é montada uma vez só")

	var faixa := CaixasDosElementos.textura_da_faixa("57-71")
	var img_faixa := faixa.get_image()
	var tinta_no_miolo := 0
	for y in range(miolo.position.y, miolo.end.y):
		for x in range(miolo.position.x, miolo.end.x):
			if img_faixa.get_pixel(x, y).a > 0.5:
				tinta_no_miolo += 1
	_checar(Vector2i(faixa.get_size()) == CaixasDosElementos.TAMANHO and tinta_no_miolo > 20 and tinta_no_miolo < 200,
		"a caixa \"57-71\" é a moldura com o texto no meio")


func _testar_o_nome() -> void:
	print("\n--- O NOME DENTRO DA CAIXA ---")
	var encolhidos := PackedStringArray()
	var maior := 0.0
	var mais_largo := ""
	for z in range(1, 119):
		var nome := Elementos.nome(z)
		var fator := CaixaElemento.escala_do_nome(nome, 2.0)
		var largura := CaixaElemento.FONTE.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, CaixaElemento.TAM_NOME).x * fator
		if largura > maior:
			maior = largura
			mais_largo = nome
		if not is_equal_approx(fator, 1.5):
			encolhidos.append(nome)
	_checar(encolhidos.is_empty(), "todo nome cabe no vão no tamanho do caderno (11 ampliada 1,5x) %s" % [encolhidos])
	_checar(maior <= CaixasDosElementos.VAO_DO_NOME.size.x * 2.0 - 4.0,
		"o mais largo é %s: %.1f px num vão de %.0f" % [mais_largo, maior, CaixasDosElementos.VAO_DO_NOME.size.x * 2.0])
	_checar(is_equal_approx(CaixaElemento.escala_do_nome("Hidrogênio", 2.0), FaceCaderno.ESCALA_NOME),
		"o hidrogênio sai com o nome do tamanho que tem na página do caderno")
	_checar(CaixaElemento.escala_do_nome("Um Nome Comprido Demais", 2.0) < 1.5, "um nome que não coubesse encolheria")


func _testar_o_no() -> void:
	print("\n--- O NÓ ---")
	var caixa := CaixaElemento.new()
	add_child(caixa)
	_checar(caixa.size == Vector2(152, 184) and caixa.numero_atomico == 1 and caixa.escala == 2,
		"nasce como a do caderno: o hidrogênio, ampliado 2x (152 x 184)")
	caixa.escala = 1
	_checar(caixa.size == Vector2(76, 92) and caixa.custom_minimum_size == Vector2(76, 92), "na escala 1 tem o tamanho da arte")
	caixa.escala = 3
	_checar(caixa.size == Vector2(228, 276), "na escala 3, o triplo")
	caixa.numero_atomico = 500
	_checar(caixa.numero_atomico == 118, "o número atômico não passa de 118")
	caixa.numero_atomico = -3
	_checar(caixa.numero_atomico == 0, "nem desce de 0 (a caixa vazia)")
	_checar(caixa.mouse_filter == Control.MOUSE_FILTER_STOP or caixa.mouse_filter == Control.MOUSE_FILTER_PASS \
		or caixa.mouse_filter == Control.MOUSE_FILTER_IGNORE, "é um Control comum")
	caixa.queue_free()
	await get_tree().process_frame


# ─────────────────────────────────────────────────────────────

func _capturar() -> void:
	if _pasta_capturas.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_pasta_capturas)
	var fundo := ColorRect.new()
	fundo.color = Color("14182e")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	# As 118 na escala 1, em 12 colunas.
	var z := 1
	for linha in 10:
		for coluna in 20:
			if z > 118:
				break
			var caixa := CaixaElemento.new()
			caixa.numero_atomico = z
			caixa.escala = 1
			caixa.position = Vector2(20 + coluna * 78, 10 + linha * 94)
			fundo.add_child(caixa)
			z += 1
	await _foto("caixas_118")
	for filho in fundo.get_children():
		filho.queue_free()
	await get_tree().process_frame
	var x := 30.0
	for numero: int in [1, 8, 6, 12, 80, 104, 110, 0]:
		var caixa := CaixaElemento.new()
		caixa.numero_atomico = numero
		caixa.escala = 2
		caixa.com_sombra = true
		caixa.position = Vector2(x, 60)
		fundo.add_child(caixa)
		x += 166.0
	x = 30.0
	for numero: int in [92, 26, 118]:
		var caixa := CaixaElemento.new()
		caixa.numero_atomico = numero
		caixa.escala = 3
		caixa.position = Vector2(x, 300)
		fundo.add_child(caixa)
		x += 250.0
	var do_caderno := TextureRect.new()
	do_caderno.texture = load(ARTE_H)
	do_caderno.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	do_caderno.position = Vector2(900, 300)
	do_caderno.scale = Vector2(3, 3)
	fundo.add_child(do_caderno)
	await _foto("caixas_ampliadas")


func _foto(nome: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_pasta_capturas.path_join(nome + ".png"))
	print("  .     foto: ", nome)
