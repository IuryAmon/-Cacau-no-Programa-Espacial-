@tool
extends Node2D
## Rig de iluminação solar.
##
## Toda a luz da fase nasce de um nó só: o sprite do sol (`BG/sol/Sprite2D`).
## A cada quadro este script projeta o sol na tela e distribui essa posição para
## quem precisa dela — o contraluz, os feixes crepusculares, o grading da
## atmosfera, a névoa aérea das camadas de parallax e a poeira no ar. Arrastar o
## sol no editor move a iluminação inteira junto, sem tocar em mais nada.
##
## O acoplamento é feito por uniforme, não por lista fixa: qualquer material
## desta cena que declare um uniforme `sol_uv` entra no rig automaticamente.
## Para acrescentar um efeito novo, basta dar a ele um shader com esse uniforme.
##
## [b]O sol está atrás de tudo.[/b] Essa é a regra que governa o rig inteiro e a
## razão de ele não ter uma luz solar no mundo. O sol vive na camada mais funda
## do parallax; tudo que o jogador vê está entre ele e a câmera, então a face
## virada para nós é justamente a que fica em sombra. Uma `PointLight2D` na
## posição do sol acenderia essa face — o erro clássico, e o que este rig
## substituiu. O que o sol devolve para a cena é outra coisa:
##
## [codeblock]
## chave          BG/sol/LuzSol       só o parallax (range_layer < 0), onde o
##                                    sol de fato bate de frente no que vemos
## fio            Overlay/Contraluz   rim quente na borda virada para o sol
## ar             Overlay/Raios       feixes recortados por quem está na frente
## graduação      Overlay/Atmosfera   véu quente, sombra fria, lente
## preenchimento  LuzDoCeu            abóbada azul, de cima — nunca do sol
## [/codeblock]
##
## A ordem dos passes do overlay importa e está travada pelo `z_index`: o
## contraluz lê a cena crua para achar as silhuetas, os feixes leem a cena já
## recortada, e a atmosfera fecha graduando tudo.

## Uniforme obrigatório: quem o declara entra no rig.
const UNIFORME_ANCORA := "sol_uv"
## Uniformes de geometria que o rig alimenta, quando o shader os declara.
const CAMPOS_DIRIGIDOS: PackedStringArray = ["sol_uv", "aspecto", "visibilidade"]
## Nomes que os shaders dão à cor da luz-chave. Unificados por `cor_do_sol`.
const CAMPOS_DE_LUZ: PackedStringArray = ["cor_luz", "cor_sol"]
## Nomes que os shaders dão à cor da sombra aberta. Unificados por `cor_da_sombra`.
const CAMPOS_DE_SOMBRA: PackedStringArray = ["cor_sombra"]

@export_node_path("Node2D") var caminho_do_sol := NodePath("../BG/sol/Sprite2D")

@export_group("Intensidade")
## Multiplicador mestre — mexa aqui para clarear ou apagar a fase inteira.
@export_range(0.0, 2.0, 0.01) var energia := 1.0:
	set(v):
		energia = v
		_pedir_repintura()
## Amplitude da respiração do sol (0 congela o brilho). Só o halo e o brilho
## atmosférico respiram; as luzes ficam firmes, senão o cenário parece piscar.
@export_range(0.0, 0.15, 0.005) var pulsacao := 0.02
## Quanto o sol precisa sair da tela para o contraluz e o flare sumirem de vez.
@export_range(0.05, 1.5, 0.05) var margem_de_saida := 0.5

@export_group("Cor")
## Cor da luz-chave. Propagada para todos os shaders e para a luz do parallax,
## para a fase inteira concordar sobre a cor do sol.
@export var cor_do_sol := Color(1.0, 0.87, 0.64):
	set(v):
		cor_do_sol = v
		_pedir_repintura()
## Cor da sombra aberta — o azul da abóbada, complemento frio da luz-chave.
@export var cor_da_sombra := Color(0.6, 0.7, 0.95):
	set(v):
		cor_da_sombra = v
		_pedir_repintura()
## Desligue para dar cor a cada material na mão, sem o rig por cima.
@export var propagar_cor := true:
	set(v):
		propagar_cor = v
		_pedir_repintura()

@export_group("Preenchimento do céu")
## A abóbada azul que ilumina a sombra aberta. É o que dá volume ao primeiro
## plano agora que o sol não bate mais nele de frente.
@export_range(0.0, 2.0, 0.01) var energia_do_ceu := 1.0
## Altura da luz de preenchimento na tela (0 = topo, 1 = base).
@export_range(-0.5, 1.0, 0.01) var altura_do_ceu := 0.05

@export_group("Nós do rig")
@export_node_path("PointLight2D") var caminho_da_luz_do_ceu := NodePath("LuzDoCeu")
@export_node_path("PointLight2D") var caminho_da_luz_do_parallax := NodePath("../BG/sol/LuzSol")
@export_node_path("Node2D") var caminho_do_halo := NodePath("../BG/sol/Halo")
@export_node_path("Node2D") var caminho_do_overlay := NodePath("Overlay")
@export_node_path("GPUParticles2D") var caminho_da_poeira := NodePath("Poeira")

@export_group("Editor")
## Desenha a iluminação também na viewport do editor.
@export var previa_no_editor := true

var _sol: Node2D
var _luz_ceu: PointLight2D
var _luz_parallax: PointLight2D
var _halo: Node2D
var _overlay: Node2D
var _poeira: GPUParticles2D

## Os passes do overlay, na ordem em que desenham.
var _passes: Array[Control] = []

## Um item por material atendido: {"mat": ShaderMaterial, "campos": PackedStringArray}.
var _alvos: Array[Dictionary] = []

var _energia_do_ceu_base := 1.0
var _energia_do_parallax_base := 1.0
var _escala_do_halo := Vector2.ONE
var _alfa_do_halo := 1.0
var _alfa_da_poeira := 1.0
var _tela_da_poeira := Vector2.ZERO
var _paleta_suja := true


func _ready() -> void:
	_resolver_nos()
	_coletar_materiais()
	set_process(true)


func _resolver_nos() -> void:
	_sol = get_node_or_null(caminho_do_sol) as Node2D
	_luz_ceu = get_node_or_null(caminho_da_luz_do_ceu) as PointLight2D
	_luz_parallax = get_node_or_null(caminho_da_luz_do_parallax) as PointLight2D
	_halo = get_node_or_null(caminho_do_halo) as Node2D
	_overlay = get_node_or_null(caminho_do_overlay) as Node2D
	_poeira = get_node_or_null(caminho_da_poeira) as GPUParticles2D

	_passes.clear()
	if _overlay != null:
		for filho in _overlay.get_children():
			var passe := filho as Control
			if passe != null:
				_passes.append(passe)

	if _luz_ceu != null:
		_energia_do_ceu_base = _luz_ceu.energy
	if _luz_parallax != null:
		_energia_do_parallax_base = _luz_parallax.energy
	if _halo != null:
		_escala_do_halo = _halo.scale
		_alfa_do_halo = _halo.self_modulate.a
	if _poeira != null:
		_alfa_da_poeira = _poeira.modulate.a


## Varre a cena atrás de todo material que saiba o que fazer com a posição do
## sol. Feito uma vez; a lista não muda durante o jogo.
func _coletar_materiais() -> void:
	_alvos.clear()
	_paleta_suja = true
	var raiz: Node = owner if owner != null else get_parent()
	if raiz == null:
		return
	_varrer(raiz, {})


func _varrer(no: Node, vistos: Dictionary) -> void:
	var item := no as CanvasItem
	if item != null:
		var mat := item.material as ShaderMaterial
		if mat != null and mat.shader != null and not vistos.has(mat):
			vistos[mat] = true
			var campos := _campos_de(mat.shader)
			if campos.has(UNIFORME_ANCORA):
				_alvos.append({"mat": mat, "campos": campos})
	for filho in no.get_children():
		_varrer(filho, vistos)


## Só escrevemos uniformes que o shader realmente declara — mandar um nome
## desconhecido para um ShaderMaterial não dá erro, mas fica guardado nele e
## acaba sujando a cena no próximo salvamento do editor.
func _campos_de(shader: Shader) -> PackedStringArray:
	var declarados := PackedStringArray()
	for uniforme in shader.get_shader_uniform_list(true):
		var nome: String = uniforme.get("name", "")
		if CAMPOS_DIRIGIDOS.has(nome) or CAMPOS_DE_LUZ.has(nome) or CAMPOS_DE_SOMBRA.has(nome):
			declarados.append(nome)
	return declarados


## A paleta é reescrita só quando alguém mexe nela no inspetor.
func _pedir_repintura() -> void:
	_paleta_suja = true


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and not previa_no_editor:
		return
	_atualizar()


func _atualizar() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var tela: Vector2 = vp.get_visible_rect().size
	if tela.x < 1.0 or tela.y < 1.0:
		return

	# `canvas_transform` leva o mundo para a tela; a inversa leva a tela para o
	# mundo. Colando o overlay nessa inversa, um filho em (0,0) cai no canto da
	# tela e um filho em `tela` cai no canto oposto — cobertura exata, sem
	# depender de achar a câmera nem de saber o zoom dela.
	var para_mundo := vp.get_canvas_transform().affine_inverse()
	var aspecto := tela.x / tela.y

	if _overlay != null:
		_overlay.global_transform = para_mundo
	for passe in _passes:
		passe.position = Vector2.ZERO
		passe.size = tela

	var sol_na_tela := Vector2(tela.x * 0.74, tela.y * 0.22)
	if is_instance_valid(_sol):
		sol_na_tela = _sol.get_global_transform_with_canvas().origin
	var sol_uv := sol_na_tela / tela

	var visibilidade := _visibilidade(sol_uv) * energia
	var respiro := _respiro()

	_alimentar_materiais(sol_uv, aspecto, visibilidade * respiro)
	_atualizar_luzes(para_mundo, tela, respiro)
	_atualizar_halo(respiro)
	_atualizar_poeira(para_mundo, tela, sol_uv, aspecto, visibilidade)
	_paleta_suja = false


func _alimentar_materiais(sol_uv: Vector2, aspecto: float, visibilidade: float) -> void:
	var pintar := propagar_cor and _paleta_suja
	for alvo in _alvos:
		var mat: ShaderMaterial = alvo["mat"]
		var campos: PackedStringArray = alvo["campos"]
		mat.set_shader_parameter(UNIFORME_ANCORA, sol_uv)
		if campos.has("aspecto"):
			mat.set_shader_parameter("aspecto", aspecto)
		if campos.has("visibilidade"):
			mat.set_shader_parameter("visibilidade", visibilidade)
		# A paleta não muda todo quadro: só reescrevemos quando o inspetor mexe
		# nela, senão cada material seria sujo 60 vezes por segundo à toa.
		if not pintar:
			continue
		for campo in CAMPOS_DE_LUZ:
			if campos.has(campo):
				mat.set_shader_parameter(campo, cor_do_sol)
		for campo in CAMPOS_DE_SOMBRA:
			if campos.has(campo):
				mat.set_shader_parameter(campo, cor_da_sombra)


func _atualizar_luzes(para_mundo: Transform2D, tela: Vector2, respiro: float) -> void:
	# Preenchimento: a abóbada do céu, sempre de cima e sempre fria. Não segue o
	# sol de propósito — se seguisse, voltaríamos a acender o primeiro plano
	# pelo lado errado. Ela mora no canvas do mundo, então não toca no parallax.
	if _luz_ceu != null:
		_luz_ceu.global_position = para_mundo * Vector2(tela.x * 0.5, tela.y * altura_do_ceu)
		_luz_ceu.energy = _energia_do_ceu_base * energia_do_ceu * energia
		if _paleta_suja and propagar_cor:
			_luz_ceu.color = cor_da_sombra

	# Chave: vive dentro do parallax, junto do sprite do sol, e o `range_layer`
	# dela já a prende às camadas de fundo — o único lugar onde o sol de fato
	# bate de frente no que a câmera vê.
	if _luz_parallax != null:
		_luz_parallax.energy = _energia_do_parallax_base * energia * respiro
		if _paleta_suja and propagar_cor:
			_luz_parallax.color = cor_do_sol


func _atualizar_halo(respiro: float) -> void:
	if _halo == null:
		return
	_halo.scale = _escala_do_halo * (1.0 + (respiro - 1.0) * 1.2)
	var alfa := clampf(_alfa_do_halo * energia * respiro, 0.0, 1.0)
	if propagar_cor:
		_halo.self_modulate = Color(cor_do_sol.r, cor_do_sol.g, cor_do_sol.b, alfa)
	else:
		_halo.self_modulate.a = alfa


func _atualizar_poeira(
		para_mundo: Transform2D, tela: Vector2, sol_uv: Vector2,
		aspecto: float, visibilidade: float) -> void:
	if _poeira == null:
		return
	_poeira.global_position = para_mundo * (tela * 0.5)
	_poeira.modulate.a = clampf(_alfa_da_poeira * visibilidade, 0.0, 1.0)

	var proc := _poeira.process_material as ParticleProcessMaterial
	if proc == null:
		return

	# A poeira desce da direção do sol: são as partículas que o feixe acende ao
	# atravessar o ar. Direção e caixa só são reescritas quando mudam de verdade
	# — `ParticleProcessMaterial` é um recurso, e reescrevê-lo todo quadro suja
	# a cena inteira no editor.
	var d := Vector2((sol_uv.x - 0.5) * aspecto, sol_uv.y - 0.5)
	var rumo := d.normalized() if d.length() > 0.001 else Vector2(1.0, -1.0).normalized()
	var alvo := Vector3(-rumo.x, -rumo.y, 0.0)
	if proc.direction.distance_to(alvo) > 0.02:
		proc.direction = alvo

	# A caixa de emissão cobre a tela com folga, senão a poeira aparece só num
	# retângulo no meio e some antes de chegar às bordas.
	if not tela.is_equal_approx(_tela_da_poeira):
		_tela_da_poeira = tela
		proc.emission_box_extents = Vector3(tela.x * 0.62, tela.y * 0.62, 1.0)


## 1 com o sol na tela, caindo suave conforme ele escapa pelas bordas.
func _visibilidade(sol_uv: Vector2) -> float:
	var fora := Vector2(
		maxf(0.0, maxf(-sol_uv.x, sol_uv.x - 1.0)),
		maxf(0.0, maxf(-sol_uv.y, sol_uv.y - 1.0)))
	var v := clampf(1.0 - fora.length() / margem_de_saida, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


## Duas senoides incomensuráveis: o brilho respira sem nunca repetir o ciclo.
func _respiro() -> float:
	if is_zero_approx(pulsacao):
		return 1.0
	var t := float(Time.get_ticks_msec()) * 0.001
	return 1.0 + pulsacao * (sin(t * 0.63) * 0.6 + sin(t * 1.71) * 0.4)
