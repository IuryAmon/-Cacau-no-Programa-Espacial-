@tool
class_name ArvoreLenha
extends Area2D

# --- A ÁRVORE DA LENHA (pátio da Fase 1) ---
#
# De onde sai a lenha da fornalha. As toras não ficam largadas no chão: estão
# lá em cima, na copa do salgueiro, e descem no BUMERANGUE. Cada arremesso que
# acerta a árvore sacode a copa — ela verga para longe da pancada e volta
# balançando, pisca, farfalha e solta folhas — e derruba UMA tora, até o total
# do ciclo (toras_por_ciclo, 3). Depois disso a árvore continua apanhando e
# soltando folha, mas lenha não cai mais.
#
# A LENHA SÓ VOLTA QUANDO SE PERDE. Se a queima na fornalha falhar (a carga
# vira cinza), a fornalha chama repor_toras_perdidas() (ver
# RetortaCarbonizacao._repor_toras) e cada tora que virou cinza volta para a
# copa — aí, e só aí, o bumerangue derruba lenha de novo. Tora que ainda está
# no chão ou no inventário não se perdeu e não volta: nunca existem mais que
# três toras ao mesmo tempo.
#
# UMA TORA POR ARREMESSO, não por passada. O bumerangue atinge alvos na ida E
# na volta (ver bumerangue.gd), e a copa é grande o bastante para ele cruzar a
# árvore duas vezes no mesmo voo. A árvore reconhece o arremesso pelo próprio
# nó do bumerangue em voo: a segunda passada ainda sacode a copa, mais fraco,
# mas não derruba nada.
#
# COMO EDITAR NO EDITOR:
#   posição do nó -> no PÉ do tronco, rente ao chão. É o ponto que fica parado
#                    quando a copa verga (o resto balança em volta dele), e a
#                    linha em que as folhas pousam
#   arvore        -> o desenho que balança: aqui, o TileMapLayer Terreno/Arvore.
#                    Vazio, a árvore só solta folha e lenha, sem vergar. Tudo
#                    que for filho dele verga e pisca junto — é assim que a
#                    parte da frente da copa (o Sprite2D Frente, que passa na
#                    frente da personagem) acompanha a pancada
#   Copa, Tronco  -> as formas que o bumerangue precisa cruzar. O tronco
#                    existe para o arremesso reto, na altura da mão, também
#                    valer — ninguém precisa pular para acertar uma árvore
#   Galho1..3     -> de onde as toras despencam. A tora cai reto até o que
#                    houver de sólido embaixo do marcador, então é o X dele
#                    que decide onde ela pousa (no editor, a linha tracejada
#                    mostra a queda e o retângulo, o pouso). Cada tora sai do
#                    galho livre mais perto de onde o bumerangue bateu
#   SomFolhas     -> o farfalhar de cada pancada (sounds/FolhasArvore.wav)
#
# SAIR DA FASE NÃO PERDE NADA: quantas toras já caíram e onde cada uma pousou
# ficam no EstadoMundo. Ao voltar, as que estavam no chão reaparecem no mesmo
# lugar, e as recolhidas continuam recolhidas (cada tora lembra sozinha, pelo
# nome — ver Madeira).

const CENA := "res://scenes/fases/componentes/arvore_lenha.tscn"

## Grupo pelo qual a fornalha acha a árvore para devolver a lenha perdida.
const GRUPO := &"arvore_lenha"

## Nome das toras que a árvore derruba ("ToraDaArvore1", 2, 3). O nome é a
## chave com que a tora lembra no EstadoMundo se já foi recolhida, e vira o id
## dela no inventário (Madeira.PREFIXO_ID + nome em minúsculas).
const PREFIXO_TORA := "ToraDaArvore"

# --- A VERGADA DA COPA ---
#
# A copa não treme no lugar: ela VERGA. O desenho da árvore é cisalhado em
# volta do pé do tronco (o pé fica parado, o alto anda), e o quanto ele anda
# segue a resposta de um galho elástico a uma pancada — sen(ωt)·e^(−βt): sai
# do repouso, vai até o pico para longe da pancada, volta passando do ponto e
# assenta. Pancadas seguidas SOMAM, como num galho de verdade, em vez de uma
# cortar a outra no meio (o que faria o desenho pular).

## Deslocamento do topo por pixel de altura no pico do balanço (0.035 num
## salgueiro de ~380 px de altura na tela são ~13 px de copa andando).
const VERGA := 0.035
## A pancada que não derruba nada (árvore vazia, ou a segunda passada do
## mesmo arremesso) balança menos: é leitura de "acertou, mas acabou".
const VERGA_FRACA := 0.018
## Ritmo do balanço (vaivéns por segundo) e o quão rápido ele morre (1/s).
const VERGA_RITMO := 2.6
const VERGA_AMORTECIMENTO := 3.4
## Daqui para frente o balanço já é invisível e a pancada sai da conta.
const VERGA_DURACAO := 1.5

## O clarão da pancada: o desenho da árvore acende e volta.
const CLARAO := Color(1.3, 1.24, 1.14)
const CLARAO_DURACAO := 0.2

# --- AS FOLHAS ---

## A paleta do próprio salgueiro (Weeping Willow2.png), da luz para a sombra.
const PALETA_FOLHAS: Array[Color] = [
	Color("e0bc5a"), Color("de9e50"), Color("d47e42"), Color("d47e42"),
	Color("b3512b"), Color("943522"),
]
## Folhas que espirram do ponto da pancada, e as que se soltam pela copa
## inteira — com e sem tora caindo.
const FOLHAS_NA_PANCADA := 12
const FOLHAS_NA_PANCADA_FRACA := 6
const FOLHAS_PELA_COPA := 10
const FOLHAS_PELA_COPA_FRACA := 3
## Quanto a pancada nunca sai de baixo da copa: bumerangue batendo no tronco
## solta folha dos galhos mais baixos, não do meio da madeira.
const MARGEM_DA_COPA := 14.0

# --- A QUEDA DAS TORAS ---

## Até onde procurar chão embaixo de um galho, e em que camada física.
const ALCANCE_DO_CHAO := 1500.0
const MASCARA_DO_CHAO := 1

## Quantas toras a árvore dá por ciclo — o mesmo que a fornalha pede.
@export var toras_por_ciclo: int = 3
## O desenho que verga quando o bumerangue acerta (o TileMapLayer da árvore).
@export var arvore: Node2D

# Uma entrada por tora do ciclo: {} enquanto ela está na copa, ou
# {"repouso": Vector2, "galho": String} depois que caiu — onde ela pousou
# (global) e de que galho saiu. Espelhado no EstadoMundo a cada mudança.
var _quedas: Array = []
# O bumerangue que derrubou a última tora: a segunda passada do mesmo voo não
# derruba outra.
var _ultimo_arremesso: int = 0

var _transform_da_arvore: Transform2D = Transform2D.IDENTITY
var _cor_da_arvore: Color = Color.WHITE
# O pé do tronco nas coordenadas do desenho da árvore: o eixo da vergada.
var _pe_na_arvore: Vector2 = Vector2.ZERO
# Pancadas ainda balançando: x = tempo desde a pancada, y = força com sinal
# (positiva empurra a copa para a direita).
var _pancadas: Array[Vector2] = []
var _tween_clarao: Tween = null

@onready var _copa: CollisionShape2D = get_node_or_null("Copa")
@onready var _som_folhas: AudioStreamPlayer2D = get_node_or_null("SomFolhas")


static func criar(pai: Node, pos: Vector2, config: Dictionary = {}) -> ArvoreLenha:
	var no: ArvoreLenha = load(CENA).instantiate()
	no.name = "ArvoreLenha"
	no.position = pos
	for chave in config:
		no.set(chave, config[chave])
	Blockout.adicionar(pai, no)
	return no


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(&"alvo_bumerangue")
	add_to_group(GRUPO)

	_quedas = (EstadoMundo.ler(self, "quedas", []) as Array).duplicate(true)
	_quedas.resize(toras_por_ciclo)
	for i in _quedas.size():
		if not (_quedas[i] is Dictionary):
			_quedas[i] = {}

	if is_instance_valid(arvore):
		_transform_da_arvore = arvore.transform
		_cor_da_arvore = arvore.modulate
		_pe_na_arvore = arvore.to_local(global_position)

	_repor_toras_no_chao()
	set_process(false)


func _exit_tree() -> void:
	# Saindo no meio de um balanço, o desenho não pode ficar torto para trás.
	if not Engine.is_editor_hint() and is_instance_valid(arvore) and not _pancadas.is_empty():
		arvore.transform = _transform_da_arvore
		arvore.modulate = _cor_da_arvore


# --- API ---

## Quantas toras ainda estão na copa esperando o bumerangue.
func toras_na_copa() -> int:
	var total := 0
	for queda in _quedas:
		if (queda as Dictionary).is_empty():
			total += 1
	return total


## A carga da fornalha virou cinza: cada tora que se perdeu no fogo volta para
## a copa, pronta para cair de novo. Perdida = já caiu, já foi recolhida e não
## está mais no inventário — ou seja, foi para dentro da fornalha. Devolve
## quantas voltaram.
func repor_toras_perdidas() -> int:
	var devolvidas := 0
	for i in _quedas.size():
		# Na copa, ou reservada por uma pancada e nascendo neste quadro.
		if not (_quedas[i] as Dictionary).has("repouso"):
			continue
		var nome := _nome_da_tora(i)
		if _tora_no_chao(nome) or _tora_no_inventario(nome):
			continue
		# "Desrecolhida": ao cair de novo, a tora nasce com o mesmo nome e não
		# pode se achar já recolhida.
		EstadoMundo.desmarcar_caminho(str(get_path()) + "/" + nome)
		_quedas[i] = {}
		devolvidas += 1
	_guardar()
	return devolvidas


## Chamado pelo bumerangue ao passar pela copa ou pelo tronco (na ida e na
## volta).
func atingir_bumerangue() -> void:
	if Engine.is_editor_hint():
		return
	var bumerangue := _bumerangue_em_voo()
	var ponto := bumerangue.global_position if bumerangue else _centro_da_copa()
	# Chamada sem bumerangue nenhum no ar (um teste, um atalho) vale como um
	# arremesso novo.
	var arremesso_novo := bumerangue == null or bumerangue.get_instance_id() != _ultimo_arremesso
	var derruba := arremesso_novo and toras_na_copa() > 0
	if derruba and bumerangue:
		_ultimo_arremesso = bumerangue.get_instance_id()

	var lado := _lado_da_pancada(ponto)
	_vergar(lado * (VERGA if derruba else VERGA_FRACA))
	_piscar()
	_soltar_folhas(ponto, lado, derruba)
	_farfalhar(derruba)
	if derruba:
		# A tora é reservada JÁ (a próxima pancada tem de saber que ela saiu da
		# copa), mas nasce no fim do quadro: quem chama isto é o area_entered
		# do bumerangue, no meio do passo de física, e ali o motor não aceita
		# área nova nem consulta de raio.
		var i := _proxima_tora_na_copa()
		var galho := _galho_livre_mais_perto(ponto)
		_quedas[i] = {"galho": String(galho.name) if galho else ""}
		_derrubar_tora.call_deferred(i, galho, ponto)


# --- A PANCADA ---

## O bumerangue que está batendo agora. Ele nasce como filho da cena atual
## (ver Bumerangue.lancar) e só voa um por vez; o que já foi apanhado desliga
## o physics_process (ver Bumerangue._terminar) e fica de fora.
func _bumerangue_em_voo() -> Bumerangue:
	var cena := get_tree().current_scene
	if cena == null:
		return null
	var mais_perto: Bumerangue = null
	var menor := INF
	for filho in cena.get_children():
		if filho is Bumerangue and filho.is_physics_processing():
			var distancia := global_position.distance_squared_to(filho.global_position)
			if distancia < menor:
				menor = distancia
				mais_perto = filho
	return mais_perto


## +1 empurra a copa para a direita, -1 para a esquerda: sempre para longe de
## quem arremessou.
func _lado_da_pancada(ponto: Vector2) -> float:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var de := player.global_position.x if player else global_position.x
	var lado := signf(ponto.x - de)
	return lado if lado != 0.0 else 1.0


func _vergar(forca: float) -> void:
	if not is_instance_valid(arvore):
		return
	_pancadas.append(Vector2(0.0, forca))
	set_process(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		# No editor o _process só redesenha a prévia das quedas (ver _draw).
		queue_redraw()
		return
	if not is_instance_valid(arvore):
		_pancadas.clear()
		set_process(false)
		return

	var verga := 0.0
	var i := _pancadas.size() - 1
	while i >= 0:
		var pancada := _pancadas[i]
		pancada.x += delta
		if pancada.x >= VERGA_DURACAO:
			_pancadas.remove_at(i)
		else:
			_pancadas[i] = pancada
			verga += pancada.y * exp(-pancada.x * VERGA_AMORTECIMENTO) \
				* sin(TAU * VERGA_RITMO * pancada.x)
		i -= 1

	if _pancadas.is_empty():
		arvore.transform = _transform_da_arvore
		set_process(false)
		return
	# Cisalhamento horizontal em volta do pé: um ponto na altura y do desenho
	# anda verga × (altura do pé − y). O pé (y do pé) não anda nada.
	var cisalha := Transform2D(Vector2(1.0, 0.0), Vector2(-verga, 1.0),
		Vector2(verga * _pe_na_arvore.y, 0.0))
	arvore.transform = _transform_da_arvore * cisalha


func _piscar() -> void:
	if not is_instance_valid(arvore):
		return
	if _tween_clarao and _tween_clarao.is_valid():
		_tween_clarao.kill()
	arvore.modulate = _cor_da_arvore * CLARAO
	_tween_clarao = create_tween()
	_tween_clarao.tween_property(arvore, "modulate", _cor_da_arvore, CLARAO_DURACAO)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _farfalhar(forte: bool) -> void:
	if _som_folhas == null or _som_folhas.stream == null:
		return
	# Cada pancada num tom um pouco diferente: o mesmo farfalhar repetido
	# três vezes seguidas soaria gravado.
	_som_folhas.pitch_scale = randf_range(0.9, 1.12) if forte else randf_range(1.1, 1.25)
	_som_folhas.volume_db = 0.0 if forte else -6.0
	_som_folhas.play()


func _soltar_folhas(ponto: Vector2, lado: float, forte: bool) -> void:
	var folhas := FolhasCaindo.criar(self, global_position.y)
	var copa := _retangulo_da_copa()

	# O punhado que espirra de onde o bumerangue bateu, para longe dele.
	var origem := ponto
	if copa.has_area():
		origem.x = clampf(origem.x, copa.position.x, copa.end.x)
		origem.y = clampf(origem.y, copa.position.y, copa.end.y - MARGEM_DA_COPA)
	for _n in (FOLHAS_NA_PANCADA if forte else FOLHAS_NA_PANCADA_FRACA):
		var direcao := Vector2(lado, -0.55).normalized()\
			.rotated(randf_range(-1.1, 1.1))
		folhas.soltar(origem + Vector2(randf_range(-16, 16), randf_range(-12, 12)),
			direcao * randf_range(90.0, 220.0), _cor_de_folha())

	# As que se soltam pela copa inteira com o tranco, espalhadas no tempo.
	# Sorteadas numa elipse dentro da Copa: os cantos do retângulo são céu.
	if not copa.has_area():
		return
	var centro := copa.get_center()
	var raio := copa.size * 0.5
	for _n in (FOLHAS_PELA_COPA if forte else FOLHAS_PELA_COPA_FRACA):
		var angulo := randf() * TAU
		var alcance := sqrt(randf())
		var pos := centro + Vector2(cos(angulo) * raio.x, sin(angulo) * raio.y) * alcance
		folhas.soltar(pos, Vector2(lado * randf_range(10.0, 50.0), randf_range(-20.0, 10.0)),
			_cor_de_folha(), randf_range(0.0, 0.45))


func _cor_de_folha() -> Color:
	return PALETA_FOLHAS[randi() % PALETA_FOLHAS.size()]


# --- AS TORAS ---

## Faz a tora `i` (já reservada em atingir_bumerangue) nascer no galho e cair.
func _derrubar_tora(i: int, galho: Marker2D, ponto: Vector2) -> void:
	if not is_inside_tree():
		return
	var origem: Vector2 = galho.global_position if is_instance_valid(galho) else ponto
	var nome := _nome_da_tora(i)

	# Rede de segurança: uma tora recolhida neste mesmo quadro ainda está na
	# árvore (queue_free só no fim do quadro) e tomaria o nome da nova.
	var antiga := get_node_or_null(nome)
	if antiga:
		remove_child(antiga)
		antiga.queue_free()

	var tora := Madeira.criar(self, nome, to_local(origem))
	var repouso := Vector2(origem.x, _chao_embaixo(origem) - tora.meia_altura())
	_quedas[i]["repouso"] = repouso
	# Anotado já, antes de ela pousar: quem sair da fase no meio da queda
	# volta e acha a tora no chão.
	_guardar()
	tora.cair(repouso)


## Recria, no lugar em que pousaram, as toras que já tinham caído numa visita
## anterior. As que foram recolhidas se apagam sozinhas no _ready() delas.
func _repor_toras_no_chao() -> void:
	for i in _quedas.size():
		var queda: Dictionary = _quedas[i]
		if queda.has("repouso"):
			Madeira.criar(self, _nome_da_tora(i), to_local(queda["repouso"]))
		elif not queda.is_empty():
			# Reservada, mas a fase fechou antes de ela nascer: continua na copa.
			_quedas[i] = {}


func _proxima_tora_na_copa() -> int:
	for i in _quedas.size():
		if (_quedas[i] as Dictionary).is_empty():
			return i
	return -1


## O galho ainda sem tora caída mais perto (na horizontal) da pancada. Se os
## galhos acabarem antes das toras, repete o mais perto.
func _galho_livre_mais_perto(ponto: Vector2) -> Marker2D:
	var usados: Array[String] = []
	for queda in _quedas:
		if not (queda as Dictionary).is_empty():
			usados.append(queda.get("galho", ""))
	var livre: Marker2D = null
	var qualquer: Marker2D = null
	for galho in _galhos():
		var distancia := absf(galho.global_position.x - ponto.x)
		if qualquer == null or distancia < absf(qualquer.global_position.x - ponto.x):
			qualquer = galho
		if String(galho.name) in usados:
			continue
		if livre == null or distancia < absf(livre.global_position.x - ponto.x):
			livre = galho
	return livre if livre else qualquer


func _galhos() -> Array[Marker2D]:
	var galhos: Array[Marker2D] = []
	for filho in get_children():
		if filho is Marker2D and String(filho.name).begins_with("Galho"):
			galhos.append(filho)
	return galhos


## A altura (global) do chão embaixo de `origem`: o primeiro sólido que um
## raio reto para baixo encontra. Sem nada embaixo, o pé da árvore.
func _chao_embaixo(origem: Vector2) -> float:
	var consulta := PhysicsRayQueryParameters2D.create(origem,
		origem + Vector2(0.0, ALCANCE_DO_CHAO), MASCARA_DO_CHAO)
	consulta.collide_with_areas = false
	# A lenha cai no chão, não na cabeça de quem está embaixo da árvore.
	var excluir: Array[RID] = []
	for corpo in get_tree().get_nodes_in_group("player"):
		if corpo is CollisionObject2D:
			excluir.append((corpo as CollisionObject2D).get_rid())
	consulta.exclude = excluir
	var batida := get_world_2d().direct_space_state.intersect_ray(consulta)
	if batida.is_empty():
		return global_position.y
	return (batida["position"] as Vector2).y


func _tora_no_chao(nome: String) -> bool:
	var tora := get_node_or_null(nome)
	return tora != null and not tora.is_queued_for_deletion()


func _tora_no_inventario(nome: String) -> bool:
	var id := Madeira.PREFIXO_ID + nome.to_lower()
	for item in Inventario.itens_coletados:
		if str(item["id"]) == id:
			return true
	return false


func _nome_da_tora(i: int) -> String:
	return PREFIXO_TORA + str(i + 1)


func _guardar() -> void:
	EstadoMundo.guardar(self, "quedas", _quedas.duplicate(true))


# --- GEOMETRIA ---

## O retângulo (global) da forma "Copa".
func _retangulo_da_copa() -> Rect2:
	if _copa == null or not (_copa.shape is RectangleShape2D):
		return Rect2()
	var tamanho: Vector2 = (_copa.shape as RectangleShape2D).size * _copa.global_scale.abs()
	return Rect2(_copa.global_position - tamanho * 0.5, tamanho)


func _centro_da_copa() -> Vector2:
	var copa := _retangulo_da_copa()
	return copa.get_center() if copa.has_area() else global_position


# --- PRÉVIA NO EDITOR ---

## No editor: de cada galho, a linha da queda até a altura do pé da árvore e o
## retângulo de onde a tora vai pousar — para arrastar os galhos sabendo onde
## a lenha vai parar. (É uma prévia: no jogo quem decide o chão é o raio.)
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var cor := Color(0.95, 0.7, 0.3, 0.85)
	var tora := Vector2(78, 18)
	for galho in _galhos():
		var de := galho.position
		var ate := Vector2(de.x, -tora.y * 0.5)
		draw_dashed_line(de, ate, cor, 2.0, 8.0)
		draw_rect(Rect2(ate - tora * 0.5, tora), cor, false, 2.0)
