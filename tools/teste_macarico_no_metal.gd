extends Node

# --- O MAÇARICO SÓ ACENDE ENCOSTADO NO METAL ---
#
# Roda com:
#   godot --headless --path . res://tools/teste_macarico_no_metal.tscn
#
# O que este teste guarda (as três regras da ferramenta):
#   1. o maçarico NÃO tem botão solto. Não existe ação "usar_macarico" no mapa
#      de entrada, então não dá para sair queimando o ar pelo mapa;
#   2. chegando na chapa/porta de metal, o cenário PEDE o botão: acende o
#      desenho da tecla E, que vira o desenho do □ de controle na mão;
#   3. apertando sem a ferramenta no cinto, a Cacau FALA na caixa do Dialogic
#      (a mesma do resto do jogo, com o retrato dela) — e o metal continua
#      inteiro. A fala CONSTATA o obstáculo sem entregar a solução: se ela
#      passar a citar maçarico/chama/corte, este teste falha de propósito.

const PORTA := "res://scenes/fases/componentes/porta_metal_macarico.tscn"
const CHAPA := "res://scenes/fases/componentes/chapa_soldada.tscn"
const PLAYER := "res://scenes/player.tscn"

## A timeline que os dois obstáculos falam.
const FALA := "cacau_metal_bloqueado"

## Palavras que a fala NÃO pode conter: o quebra-cabeça é descobrir que a
## resposta é o maçarico, e a própria Cacau não pode entregar isso.
const PROIBIDAS := ["maçarico", "macarico", "chama", "derreter", "cortar", "soldar"]

var _falhas := 0


func _ready() -> void:
	await get_tree().process_frame
	await _testar_porta()
	await _testar_chapa()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok    " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


func _testar_porta() -> void:
	print("\n--- PORTA DE METAL ---")
	_checar(not InputMap.has_action("usar_macarico"),
		"o maçarico não tem botão solto no mapa de entrada")

	var porta: Node2D = _instanciar(PORTA)
	var player := _instanciar(PLAYER)
	player.global_position = porta.global_position + Vector2(70, -60)
	await _assentar()

	var dica: AnimatedSprite2D = porta.get_node_or_null("Dica")
	_checar(dica != null and dica.visible, "chegando perto, a porta pede o botão")
	_checar(dica != null and dica.animation == IconeInteragir.ANIM_TECLADO,
		"no teclado, o desenho é o da tecla E")

	# De controle na mão o MESMO ícone troca para o □.
	Controle.call("_definir", true)
	await get_tree().process_frame
	_checar(dica != null and dica.animation == IconeInteragir.ANIM_CONTROLE,
		"de controle, o mesmo ícone vira o desenho do □")
	_checar(dica != null and dica.is_playing(), "e continua pulsando")
	Controle.call("_definir", false)
	await get_tree().process_frame
	_checar(dica != null and dica.animation == IconeInteragir.ANIM_TECLADO,
		"voltando ao teclado, o E volta")

	# Sem o maçarico no cinto: ela fala, e a folha continua em pé.
	Progresso._habilidades.erase("macarico")
	porta.call("_tentar_derreter")
	await _assentar()
	_checar(Dialogic.current_timeline != null,
		"sem o maçarico, a Cacau fala na caixa do Dialogic")
	_checar(porta.get("fala_sem_macarico") == FALA, "e é a timeline do metal bloqueado")
	_checar(porta.get("_estado") == 0, "a porta continua fria")

	Dialogic.end_timeline()
	await _assentar()
	porta.queue_free()
	player.queue_free()
	await get_tree().process_frame


func _testar_chapa() -> void:
	print("\n--- CHAPA SOLDADA ---")
	var chapa: Node2D = _instanciar(CHAPA)
	var player := _instanciar(PLAYER)
	player.global_position = chapa.global_position
	await _assentar()

	var dica: AnimatedSprite2D = chapa.get_node_or_null("Dica")
	_checar(dica != null and dica.visible, "perto da chapa, o botão acende")
	_checar(dica != null and dica.animation == IconeInteragir.ANIM_TECLADO,
		"e no teclado é o desenho da tecla E")

	Progresso._habilidades.erase("macarico")
	chapa.call("_reclamar")
	await _assentar()
	_checar(Dialogic.current_timeline != null,
		"sem o maçarico, a Cacau fala na caixa do Dialogic")
	_checar(chapa.get("fala_sem_macarico") == FALA, "e é a mesma timeline da porta")
	Dialogic.end_timeline()
	await _assentar()

	_testar_texto_da_fala()


## A fala existe, tem o retrato da Cacau do lado e não entrega a solução.
func _testar_texto_da_fala() -> void:
	print("
--- A FALA ---")
	var caminho := "res://timelines/%s.dtl" % FALA
	_checar(ResourceLoader.exists(caminho), "a timeline está no projeto")
	var bruto := FileAccess.get_file_as_string(caminho)
	_checar(bruto.contains("join cacau"), "a Cacau entra em cena (o retrato aparece)")
	for palavra in PROIBIDAS:
		_checar(not bruto.to_lower().contains(palavra),
			"a fala não entrega a solução ('%s' não aparece)" % palavra)


# --- APOIO ---

func _instanciar(cena: String) -> Node2D:
	var no: Node2D = (load(cena) as PackedScene).instantiate()
	add_child(no)
	return no


## As áreas de interação são físicas e os rótulos se remontam no _process:
## os dois precisam de alguns quadros de cada tipo para assentar.
func _assentar() -> void:
	for i in 3:
		await get_tree().physics_frame
	for i in 3:
		await get_tree().process_frame

