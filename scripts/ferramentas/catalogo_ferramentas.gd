class_name CatalogoFerramentas
extends RefCounted

# --- FICHA DE CADA FERRAMENTA PERMANENTE ---
#
# O Progresso guarda só o "tem ou não tem" de cada habilidade. Quem quiser
# MOSTRAR a ferramenta (a ficha de coleta, o alvéolo do cinto no canto, o
# sprite do pickup no chão) pergunta aqui — assim o nome, a descrição, a cor
# e a arte vivem em um lugar só.
#
# COMO ADICIONAR ARTE: solte o PNG em res://assets/itens/ e escreva o caminho
# em "icone". Ferramenta sem ícone continua funcionando normalmente; ela só
# não ganha ficha nem alvéolo (do mesmo jeito que o blockout espera a arte).

static var FERRAMENTAS := {
	"macarico": {
		"nome": "Maçarico Oxídrico (Ferramenta)",
		"rotulo": "MAÇARICO",
		"tecla": "Q",
		"descricao": "Hidrogênio queimando em oxigênio puro: a mesma reação do foguete, agora na mão dela. A chama passa dos 2000 °C e corta o que está soldado.",
		"icone": "res://assets/itens/maçarico.png",
		"cor": Color(1.0, 0.62, 0.22),
	},
	"bumerangue": {
		# NOME e DESCRIÇÃO podem ser reescritos à vontade: a ficha de coleta
		# (scripts/ui/popup_item.gd) se mede pelo texto que recebe — o título
		# encolhe até caber e a descrição quebra em linhas, com a altura da
		# caixa saindo da soma. Antes o enquadramento era ajustado no olho no
		# editor e qualquer texto mais longo o desmanchava.
		"nome": "Bumerangue",
		"rotulo": "BUMERANGUE",
		"tecla": "F",
		"descricao": "Vai e volta sozinho...",
		"icone": "res://assets/itens/Boomerangue.png",
		# Desenho pequeno (8x17 px), então o pickup no chão precisa de zoom
		# (ver escala_mapa()). Na ficha de coleta e na mochila não precisa: lá
		# o EstiloHUD.escala_pixel() encaixa qualquer arte na caixa sozinho,
		# em múltiplo inteiro, para o pixel não sair esticado.
		"escala_mapa": 3.0,
		"cor": Color(0.55, 0.85, 0.45),
	},
	"mochila": {
		"nome": "Mochila de N₂ (Ferramenta)",
		"rotulo": "MOCHILA N₂",
		"tecla": "SHIFT",
		"descricao": "Nitrogênio comprimido em jato curto: empurra a Cacau no ar e apaga chamas, porque N₂ não alimenta combustão.",
		"icone": "",
		"cor": Color(0.5, 0.75, 1.0),
	},
	"sinalizador": {
		"nome": "Sinalizador Quimioluminescente (Ferramenta)",
		"rotulo": "SINALIZADOR",
		"tecla": "T",
		"descricao": "Luz sem calor: a reação química libera energia direto como fóton. Dura enquanto houver carga.",
		"icone": "",
		"cor": Color(0.7, 0.95, 0.5),
	},
	"botas": {
		"nome": "Botas Isolantes (Ferramenta)",
		"rotulo": "BOTAS",
		"descricao": "Sola de polímero: elétron nenhum atravessa. O piso eletrificado vira chão comum.",
		"icone": "",
		"cor": Color(0.85, 0.8, 0.6),
	},
	"lanterna": {
		"nome": "Lanterna de Foco (Ferramenta)",
		"rotulo": "LANTERNA",
		"tecla": "R",
		"descricao": "Feixe dirigido de luz fria: a Sentinela que ele alcança congela no lugar. A bateria drena — o feixe é recurso, não farol.",
		"icone": "",
		"cor": Color(1.0, 0.9, 0.55),
	},
}


## Ficha completa da ferramenta, já com o ícone carregado em "textura".
## Devolve {} para habilidade desconhecida ou ainda sem arte — quem chama
## trata isso como "não há o que mostrar".
static func dados(habilidade: String) -> Dictionary:
	if not FERRAMENTAS.has(habilidade):
		return {}
	var ficha: Dictionary = FERRAMENTAS[habilidade].duplicate()
	var textura := icone(habilidade)
	if textura == null:
		return {}
	ficha["textura"] = textura
	ficha["id"] = habilidade
	return ficha


## Cache dos ícones já recortados (chave: nome da habilidade).
static var _icones_recortados: Dictionary = {}

## Só a arte da ferramenta (null enquanto o PNG não existir), já recortada
## pelos pixels realmente desenhados.
##
## Sem esse recorte, um PNG com respiro desigual em volta do desenho — o caso
## do maçarico, que tem mais moldura transparente à direita e embaixo — some
## puxado para um lado sempre que algo centraliza pela IMAGEM INTEIRA em vez
## do desenho: é o que deixava o ícone grande do popup de conquista fora do
## centro da caixa.
static func icone(habilidade: String) -> Texture2D:
	if not FERRAMENTAS.has(habilidade):
		return null
	if _icones_recortados.has(habilidade):
		return _icones_recortados[habilidade]

	var caminho: String = FERRAMENTAS[habilidade].get("icone", "")
	if caminho == "" or not ResourceLoader.exists(caminho):
		return null

	var bruta := load(caminho) as Texture2D
	var recortada := _recortar_pixels_opacos(bruta)
	_icones_recortados[habilidade] = recortada
	return recortada


static func _recortar_pixels_opacos(bruta: Texture2D) -> Texture2D:
	var img := bruta.get_image()
	if img == null:
		return bruta
	if img.is_compressed():
		img.decompress()
	var usado := img.get_used_rect()
	if usado.size.x <= 0 or usado.size.y <= 0 or Vector2i(usado.size) == img.get_size():
		return bruta  # já ocupa a imagem inteira: não há o que recortar

	var recorte := AtlasTexture.new()
	recorte.atlas = bruta
	recorte.region = Rect2(usado)
	return recorte


## Cor de destaque da ferramenta (anel do alvéolo, faíscas da ficha).
static func cor(habilidade: String) -> Color:
	if not FERRAMENTAS.has(habilidade):
		return Color(0.95, 0.75, 0.25)
	return FERRAMENTAS[habilidade].get("cor", Color(0.95, 0.75, 0.25))


## Tecla que USA a ferramenta, para o cinto mostrar embaixo do alvéolo. Vazia
## em ferramenta passiva (as botas isolantes, que não têm botão: o piso
## eletrificado simplesmente para de machucar).
##
## Confere com o mapa de entrada do projeto: "usar_macarico" (Q),
## "arremessar" (F), "dash" (Shift), "luz" (T), "lanterna" (R).
static func tecla(habilidade: String) -> String:
	if not FERRAMENTAS.has(habilidade):
		return ""
	return FERRAMENTAS[habilidade].get("tecla", "")


## Escala do ícone no Sprite do pickup (chão). 1.0 por padrão — só ferramentas
## com PNG pequeno (bumerangue) precisam de mais.
static func escala_mapa(habilidade: String) -> float:
	if not FERRAMENTAS.has(habilidade):
		return 1.0
	return FERRAMENTAS[habilidade].get("escala_mapa", 1.0)
