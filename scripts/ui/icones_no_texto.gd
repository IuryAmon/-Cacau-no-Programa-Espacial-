class_name IconesNoTexto
extends Control

# --- BOTÕES DO CONTROLE DENTRO DE UM LABEL ---
#
# A fonte do jogo não tem □, ○, △ nem ✕ — e, mesmo que tivesse, o botão que a
# pessoa reconhece é o desenhado da folha do tutorial. Este nó mora dentro de
# um Label: quando o texto dele traz um botão (os caracteres especiais que o
# Controle.texto() põe no lugar de "{interact}"), ele apaga o texto do próprio
# Label e o redesenha com o botão no meio, na mesma fonte, cor, contorno e
# alinhamento. No teclado vale o mesmo para as teclas que têm desenho (ESC, E,
# WASD — ver BotoesControle.TECLAS). Sem botão nem tecla desenhada no texto,
# ele some e o Label volta a se desenhar sozinho. As teclas e os botões ✕ ○ □ △
# ficam afundando em loop, como o E do cenário (BotoesControle.quadro_atual).
#
# Como o nó é filho do Label, tudo o que o puzzle já faz com o Label continua
# valendo: mostrar/esconder, piscar com "modulate", pulsar com "scale".
#
# LIMITE: a quebra de linha é só onde o texto tiver "\n" (autowrap não é
# refeito aqui).

## Folga dos dois lados do botão, em frações do tamanho dele.
const FOLGA := 0.2

## Escala mínima do botão. Normalmente ele acompanha a altura do texto; num
## texto miúdo (o "ESC para fechar" do canto dos puzzles), 2 deixa o desenho
## da tecla legível.
var escala_minima: float = 1.0

## Texto com marcas ({interact}...). Preenchido pelo Controle.rotular(): quando
## a pessoa troca de teclado para controle, o Label é reescrito a partir daqui.
## Vazio = quem escreve o Label é o dono dele (o rodapé que digita, por exemplo).
var modelo: String = ""

var _label: Label = null


## Põe (uma vez só) o desenhista de botões dentro do Label e o devolve.
static func acoplar(label: Label) -> IconesNoTexto:
	for filho in label.get_children(true):
		if filho is IconesNoTexto:
			return filho
	var no := IconesNoTexto.new()
	no.name = "IconesNoTexto"
	# Interno: quem percorre os filhos do Label não tropeça nele.
	label.add_child(no, false, Node.INTERNAL_MODE_BACK)
	return no


func _ready() -> void:
	_label = get_parent() as Label
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _label:
		# O Label redesenha sempre que o texto muda: é nessa hora que dá para
		# apagá-lo antes de o quadro ir para a tela, sem piscar o texto cru.
		_label.draw.connect(_sincronizar)
	var controle := get_node_or_null("/root/Controle")
	if controle:
		controle.mudou.connect(_ao_trocar_dispositivo)
	_sincronizar()


func _ao_trocar_dispositivo(em_uso: bool) -> void:
	if modelo != "" and _label != null:
		_label.text = BotoesControle.traduzir(modelo, em_uso, true)
	_sincronizar()


func _process(_delta: float) -> void:
	_sincronizar()


func _sincronizar() -> void:
	if _label == null:
		return
	var com_botao := BotoesControle.tem_icone(_label.text)
	var alfa := 0.0 if com_botao else 1.0
	if _label.self_modulate.a != alfa:
		_label.self_modulate.a = alfa
	if visible != com_botao:
		visible = com_botao
	if com_botao:
		queue_redraw()


func _draw() -> void:
	if _label == null:
		return
	var fonte := _label.get_theme_font(&"font")
	if fonte == null:
		return
	var tamanho := _label.get_theme_font_size(&"font_size")
	var cor := _label.get_theme_color(&"font_color")
	var cor_contorno := _label.get_theme_color(&"font_outline_color")
	var contorno := _label.get_theme_constant(&"outline_size")
	var cor_sombra := _label.get_theme_color(&"font_shadow_color")
	var sombra := Vector2(_label.get_theme_constant(&"shadow_offset_x"),
		_label.get_theme_constant(&"shadow_offset_y"))
	var entrelinha := float(_label.get_theme_constant(&"line_spacing")) \
		+ float(_label.get_theme_constant(&"paragraph_spacing"))

	var altura_linha := fonte.get_height(tamanho)
	var escala_natural := BotoesControle.escala_para(altura_linha)
	var escala := maxf(escala_minima, escala_natural)
	var lado := 16.0 * escala
	var folga := roundf(lado * FOLGA)
	var quadro := BotoesControle.quadro_atual()
	# Botão ampliado pela escala mínima (o ESC do "para fechar"): a linha dele
	# cresce até caber o desenho, para a linha de baixo não passar por cima.
	var altura_linha_icone := maxf(altura_linha, lado) if escala > escala_natural else altura_linha

	var linhas := _label.text.split("\n")
	var alturas: Array[float] = []
	var altura_total := (linhas.size() - 1) * entrelinha
	for linha in linhas:
		alturas.append(altura_linha_icone if BotoesControle.tem_icone(linha) else altura_linha)
		altura_total += alturas[-1]
	var y := 0.0
	match _label.vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER:
			y = (size.y - altura_total) * 0.5
		VERTICAL_ALIGNMENT_BOTTOM:
			y = size.y - altura_total

	for n in linhas.size():
		var linha := linhas[n]
		var altura_desta := alturas[n]
		var pedacos := _pedacos(linha)
		var largura := 0.0
		for pedaco in pedacos:
			if pedaco is int:
				largura += lado + folga * 2.0
			else:
				largura += fonte.get_string_size(pedaco, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x

		var x := 0.0
		match _label.horizontal_alignment:
			HORIZONTAL_ALIGNMENT_CENTER:
				x = (size.x - largura) * 0.5
			HORIZONTAL_ALIGNMENT_RIGHT:
				x = size.x - largura
		# O texto fica no meio da linha (que só é mais alta que ele quando tem
		# um botão ampliado).
		var base := y + (altura_desta - altura_linha) * 0.5 + fonte.get_ascent(tamanho)

		for pedaco in pedacos:
			if pedaco is int:
				var nome := BotoesControle.nome_do_caractere(pedaco)
				var centro := Vector2(x + folga + lado * 0.5, y + altura_desta * 0.5)
				BotoesControle.desenhar(self, centro, nome, escala, Color(1, 1, 1, cor.a), quadro)
				x += lado + folga * 2.0
				continue
			var ponto := Vector2(x, base)
			if cor_sombra.a > 0.0 and sombra != Vector2.ZERO:
				draw_string(fonte, ponto + sombra, pedaco, HORIZONTAL_ALIGNMENT_LEFT, -1,
					tamanho, cor_sombra)
			if contorno > 0 and cor_contorno.a > 0.0:
				draw_string_outline(fonte, ponto, pedaco, HORIZONTAL_ALIGNMENT_LEFT, -1,
					tamanho, contorno, cor_contorno)
			draw_string(fonte, ponto, pedaco, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)
			x += fonte.get_string_size(pedaco, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x

		y += altura_desta + entrelinha


## "APERTE  PARA" -> ["APERTE ", 0xE002, " PARA"]: texto e códigos de botão.
func _pedacos(linha: String) -> Array:
	var saida: Array = []
	var atual := ""
	for i in linha.length():
		var codigo := linha.unicode_at(i)
		if BotoesControle.eh_icone(codigo):
			if atual != "":
				saida.append(atual)
				atual = ""
			saida.append(codigo)
		else:
			atual += linha[i]
	if atual != "":
		saida.append(atual)
	return saida
