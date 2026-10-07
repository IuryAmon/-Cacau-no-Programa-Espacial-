@tool
class_name Atmosfera
extends Node
## O horário da fase, e tudo o que ele acende e apaga.
##
## Uma fase ao ar livre tem UM nó destes. Ele guarda que horas são, escolhe o
## [PerfilDeLuz] daquela hora (ou a mistura de dois, no meio de uma transição) e
## distribui para quem desenha:
##
## [codeblock]
## o céu             BG/Ceu      (CeuPixel)     degradê, estrelas, clarão do astro
## o sol e a lua     BG/Astros/* (AstroPixel)   quem aparece, com que tinta
## as nuvens         BG/Nuvens*  (Nuvens)       cor da luz e da sombra
## o parallax        o resto do BG              luz do horário + ar comendo o longe
## o mundo           (um CanvasModulate dele)   a luz ambiente
## os postes         grupo "luz_artificial"     fracos de dia, com tudo à noite
## [/codeblock]
##
## Céu, astros e nuvens entram sozinhos (eles se inscrevem no grupo
## [constant GRUPO_DE_CLIENTES]). As camadas de arte do fundo também: toda
## camada do BG que não tenha material próprio é vestida aqui com o
## `camada_de_fundo.gdshader`, e a profundidade dela sai do `motion_scale` (quem
## anda menos está mais longe) — ou do metadado [code]profundidade[/code] da
## ParallaxLayer, de 0 (perto) a 1 (longe), quando for preciso mandar na mão.
##
## [b]Nada disto é gravado na cena.[/b] As cores vão direto para o render: no
## .tscn fica só o que está neste Inspector. Dá para olhar a noite numa fase que
## começa de dia ([code]previa_no_editor[/code], aqui embaixo) e salvar sem medo.
##
## [b]Interface do mundo.[/b] Balão de emote, tecla de dica e texto solto não
## podem escurecer junto com o cenário. No jogo, tudo o que desenha uma arte de
## [code]res://assets/UI/[/code], todo Label e todo nó do grupo
## [constant GRUPO_LUZ_PROPRIA] fica fora da luz ambiente. Para o contrário (uma
## placa de estrada que é da UI mas mora no mundo), use o grupo
## [constant GRUPO_RECEBE_LUZ].

enum Momento { ENTARDECER, CREPUSCULO, NOITE }

const GRUPO := &"atmosfera"
## Quem tem `receber_perfil(perfil)` e quer saber da hora.
const GRUPO_DE_CLIENTES := &"atmosfera_clientes"
## As lâmpadas: quem tem a propriedade `intensidade`.
const GRUPO_DE_LUZES := &"luz_artificial"
## Não escurece com o ambiente (ele e os filhos).
const GRUPO_LUZ_PROPRIA := &"luz_propria"
## Escurece mesmo sendo arte da pasta da interface.
const GRUPO_RECEBE_LUZ := &"recebe_luz"

const SHADER_DO_FUNDO := preload("res://shaders/camada_de_fundo.gdshader")
const PASTA_DA_INTERFACE := "res://assets/UI/"
const PREVIA_COMO_NO_JOGO := -1

## A hora mudou (inclusive a cada passo de uma transição).
signal perfil_mudou(perfil: PerfilDeLuz)
## A noite caiu (fim do anoitecer, ou a fase já abriu de noite).
signal anoiteceu

## A hora que o EDITOR mostra nesta fase — e a hora em que ela abre se
## [member segue_a_partida] estiver desligado. No jogo, com ele ligado, quem
## manda é a hora da partida.
@export var momento := Momento.ENTARDECER:
	set(v):
		momento = v
		if Engine.is_editor_hint() and is_inside_tree():
			_mostrar_previa()
## Ligado (o normal), a fase está sempre na HORA DA PARTIDA, que é uma só para
## o jogo inteiro: entardecer até o sol se pôr (a cena do mirante), crepúsculo
## até a noite cair (a fornalha do pátio), noite daí em diante. Toda fase abre
## nessa hora, e um pôr do sol ou um anoitecer que aconteça aqui vale para
## todas as outras. Desligue só para uma fase presa numa hora (um sonho, uma
## lembrança): ela abre em [member momento] e não mexe na hora de ninguém.
@export var segue_a_partida := true

@export_group("Perfis")
@export var entardecer: PerfilDeLuz = preload("res://assets/luz/entardecer.tres")
## O instante em que o sol toca a serra — o meio do caminho do pôr do sol.
@export var crepusculo: PerfilDeLuz = preload("res://assets/luz/crepusculo.tres")
@export var noite: PerfilDeLuz = preload("res://assets/luz/noite.tres")

@export_group("Cena")
## O ParallaxBackground da fase.
@export_node_path("ParallaxBackground") var fundo := NodePath("../BG")

@export_group("Pôr do sol")
## Quanto dura a descida do sol, em segundos.
@export_range(1.0, 30.0, 0.1) var duracao_do_por_do_sol := 7.5
## Quanto o sol desce, em pixels da camada dele. Tem de bastar para ele sumir
## atrás da serra.
@export_range(0.0, 600.0, 1.0) var descida_do_sol := 190.0
## Em que ponto da descida (0 a 1) os postes dão a piscada e ganham força.
@export_range(0.0, 1.0, 0.01) var hora_dos_postes := 0.5

@export_group("Anoitecer")
## Quanto dura a noite caindo (do crepúsculo à noite, com a lua subindo), em
## segundos. No pátio ela cai com a fornalha queimando, depois do painel.
@export_range(1.0, 30.0, 0.1) var duracao_do_anoitecer := 7.0
## De quantos pixels abaixo do lugar dela a lua sobe. Tem de bastar para ela
## sair de trás da serra.
@export_range(0.0, 600.0, 1.0) var subida_da_lua := 280.0

var _perfil: PerfilDeLuz
var _ambiente: CanvasModulate
## Uma entrada por desenho do fundo vestido: {"item": CanvasItem,
## "material": ShaderMaterial, "profundidade": float}.
var _camadas: Array[Dictionary] = []
var _material_da_interface: CanvasItemMaterial
var _em_transicao := false
var _descida: Tween
var _andamento := 0.0
var _postes_piscaram := false
var _previa := PREVIA_COMO_NO_JOGO
var _vestir_pedido := false
var _ate_a_previa := 0.0


# ───────────────────────────────────────────────────────────── vida do nó

func _enter_tree() -> void:
	add_to_group(GRUPO)


func _ready() -> void:
	_ambiente = CanvasModulate.new()
	_ambiente.name = "Ambiente"
	add_child(_ambiente, false, Node.INTERNAL_MODE_BACK)

	var bg := _fundo()
	if bg != null and Engine.is_editor_hint():
		# No editor as camadas mudam enquanto a cena está aberta.
		bg.child_order_changed.connect(_pedir_vestir)

	if not Engine.is_editor_hint():
		if segue_a_partida:
			momento = hora_da_partida()
		_material_da_interface = CanvasItemMaterial.new()
		_material_da_interface.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		get_tree().node_added.connect(_ao_entrar_um_no)

	# Um quadro depois: os irmãos (céu, astros, postes) ainda estão entrando.
	_arrumar_a_cena.call_deferred()


func _exit_tree() -> void:
	_despir_o_fundo()
	if not Engine.is_editor_hint() and get_tree().node_added.is_connected(_ao_entrar_um_no):
		get_tree().node_added.disconnect(_ao_entrar_um_no)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		# No editor a prévia é refeita algumas vezes por segundo: é o que faz ela
		# acompanhar as cores de um perfil sendo mexidas no Inspector (e o
		# desfazer), sem depender de sinal nenhum.
		_ate_a_previa -= delta
		if _ate_a_previa <= 0.0:
			_ate_a_previa = 0.15
			_mostrar_previa()
	_levar_o_astro_ao_ceu()


func _arrumar_a_cena() -> void:
	if not is_inside_tree():
		return
	_vestir_o_fundo()
	if not Engine.is_editor_hint():
		_soltar_a_interface(_raiz_da_cena())
		aplicar(perfil_de(momento))
		_por_os_astros_no_lugar()
		if momento == Momento.NOITE:
			anoiteceu.emit()
	else:
		_mostrar_previa()


# ───────────────────────────────────────────────────────────── uso

## A Atmosfera da cena onde [param no] está (ou null).
static func da_cena(no: Node) -> Atmosfera:
	if no == null or not no.is_inside_tree():
		return null
	return no.get_tree().get_first_node_in_group(GRUPO) as Atmosfera


## Que horas são no jogo (ver [member segue_a_partida]).
static func hora_da_partida() -> Momento:
	if EstadoMundo.anoiteceu:
		return Momento.NOITE
	if EstadoMundo.sol_se_pos:
		return Momento.CREPUSCULO
	return Momento.ENTARDECER


## O perfil de um momento.
func perfil_de(m: Momento) -> PerfilDeLuz:
	match m:
		Momento.CREPUSCULO:
			return crepusculo
		Momento.NOITE:
			return noite
	return entardecer


## O perfil que está valendo agora (pode ser uma mistura).
func perfil_atual() -> PerfilDeLuz:
	return _perfil


## Força que o horário pede dos postes, de 0 a 1.
func nivel_dos_postes() -> float:
	return _perfil.postes if _perfil != null else 1.0


## O sol ainda está no céu para se pôr aqui? (Só uma vez.)
func pode_por_o_sol() -> bool:
	return momento == Momento.ENTARDECER and not _em_transicao


## Ainda dá para anoitecer aqui? (Só uma vez, e só se a fase não abriu de noite.)
func pode_anoitecer() -> bool:
	return momento != Momento.NOITE and not _em_transicao


## Troca a hora na hora, sem transição. Se o sol ainda estava descendo (ou a
## lua subindo), o movimento para ali.
func definir_momento(m: Momento) -> void:
	if _descida != null and _descida.is_valid():
		_descida.kill()
	_descida = null
	_em_transicao = false
	momento = m
	aplicar(perfil_de(m))
	_por_os_astros_no_lugar()
	_anotar_a_hora()
	if m == Momento.NOITE:
		anoiteceu.emit()


## O sol se põe: ele desce atrás da serra enquanto o céu, o fundo e o mundo
## passam do entardecer ao crepúsculo, e os postes dão a piscada e firmam.
## Devolve quando a descida termina — e a fase FICA no crepúsculo: um pouco
## mais escura, ainda sem lua. A noite é outra cena ([method anoitecer]).
func por_do_sol(duracao: float = -1.0) -> void:
	if _em_transicao or Engine.is_editor_hint():
		return
	_em_transicao = true
	_postes_piscaram = false
	_andamento = 0.0
	_descida = create_tween()
	_descida.tween_method(_passo_do_por_do_sol, 0.0, 1.0,
		duracao if duracao > 0.0 else duracao_do_por_do_sol)
	await _descida.finished
	momento = Momento.CREPUSCULO
	_em_transicao = false
	_anotar_a_hora()


## A noite cai: o céu, o fundo e o mundo vão da hora que está valendo até a
## noite, as estrelas acendem, os postes firmam e a lua sobe de trás da serra
## até o lugar em que foi deixada na cena. Devolve quando termina, já de noite.
func anoitecer(duracao: float = -1.0) -> void:
	if not pode_anoitecer() or Engine.is_editor_hint():
		return
	_em_transicao = true
	_descida = create_tween()
	_descida.tween_method(_passo_do_anoitecer.bind(_perfil), 0.0, 1.0,
		duracao if duracao > 0.0 else duracao_do_anoitecer)
	await _descida.finished
	definir_momento(Momento.NOITE)


## Quanto do pôr do sol já passou, de 0 a 1, em TEMPO (1 = o sol sumiu). Quem
## dirige a cena usa isto para entrar com a cortina no ponto certo da descida,
## em vez de contar segundos por fora.
func andamento_do_por_do_sol() -> float:
	return _andamento


## Distribui um perfil para a cena inteira.
func aplicar(perfil: PerfilDeLuz) -> void:
	if perfil == null:
		return
	_perfil = perfil

	for cliente in _da_minha_cena(GRUPO_DE_CLIENTES):
		if cliente.has_method(&"receber_perfil"):
			cliente.receber_perfil(perfil)

	for camada in _camadas:
		var material: ShaderMaterial = camada["material"]
		material.set_shader_parameter(&"luz", perfil.luz_do_fundo)
		material.set_shader_parameter(&"ar", perfil.cor_do_ar)
		material.set_shader_parameter(&"neblina",
			clampf(float(camada["profundidade"]) * perfil.neblina, 0.0, 1.0))

	if _ambiente != null:
		_ambiente.color = perfil.ambiente

	for luz in _da_minha_cena(GRUPO_DE_LUZES):
		luz.set(&"intensidade", perfil.postes)

	_levar_o_astro_ao_ceu()
	perfil_mudou.emit(perfil)


# ───────────────────────────────────────────────────────────── pôr do sol

## [param t] é o tempo da descida, de 0 a 1.
func _passo_do_por_do_sol(t: float) -> void:
	_andamento = t
	# O sol sai devagar, anda e chega devagar.
	var descido := t * t * (3.0 - 2.0 * t)
	# A cor chega ao crepúsculo um pouco antes de o sol sumir: o céu mais
	# bonito é o dos últimos instantes, com o disco já mordido pela serra.
	var perfil := PerfilDeLuz.misturar(entardecer, crepusculo, smoothstep(0.0, 0.85, t))
	aplicar(perfil)
	for astro in _astros():
		if astro.tipo == AstroPixel.Tipo.SOL:
			astro.descida = descida_do_sol * descido
	if not _postes_piscaram and t >= hora_dos_postes:
		_postes_piscaram = true
		_piscar_os_postes()


## Cada poste pega num instante: uma onda curta, não um interruptor só.
func _piscar_os_postes() -> void:
	var luzes := _da_minha_cena(GRUPO_DE_LUZES)
	var i := 0
	for luz in luzes:
		if luz.has_method(&"acender_piscando"):
			luz.acender_piscando(0.11 * i + randf_range(0.0, 0.08))
			i += 1


## [param t] é o tempo do anoitecer, de 0 a 1; [param de] é o perfil de onde
## ele partiu.
func _passo_do_anoitecer(t: float, de: PerfilDeLuz) -> void:
	var andado := t * t * (3.0 - 2.0 * t)
	var perfil := PerfilDeLuz.misturar(de, noite, andado)
	if perfil != de and perfil != noite:
		# A lua já aparece inteira cedo: ela nasce atrás da serra, não do nada
		# no meio do céu.
		perfil.lua = maxf(perfil.lua, smoothstep(0.0, 0.3, t))
	aplicar(perfil)
	for astro in _astros():
		if astro.tipo == AstroPixel.Tipo.LUA:
			astro.descida = subida_da_lua * (1.0 - andado)


## Sol e lua onde a hora da fase manda, sem movimento: o sol posto de quem não
## está mais no entardecer, a lua embaixo da serra de quem ainda não anoiteceu.
func _por_os_astros_no_lugar() -> void:
	_andamento = 0.0 if momento == Momento.ENTARDECER else 1.0
	if Engine.is_editor_hint():
		return
	for astro in _astros():
		if astro.tipo == AstroPixel.Tipo.SOL:
			astro.descida = 0.0 if momento == Momento.ENTARDECER else descida_do_sol
		else:
			astro.descida = 0.0 if momento == Momento.NOITE else subida_da_lua


## A hora que passou aqui passa a ser a da partida (ver [member segue_a_partida]).
func _anotar_a_hora() -> void:
	if not segue_a_partida:
		return
	if momento != Momento.ENTARDECER:
		EstadoMundo.sol_se_pos = true
	if momento == Momento.NOITE:
		EstadoMundo.anoiteceu = true


# ───────────────────────────────────────────────────────────── céu e astros

func _astros() -> Array[AstroPixel]:
	var lista: Array[AstroPixel] = []
	for cliente in _da_minha_cena(GRUPO_DE_CLIENTES):
		if cliente is AstroPixel:
			lista.append(cliente)
	return lista


## Diz ao céu onde está o astro que manda nele agora (o mais presente), para o
## clarão abrir no lugar certo. Roda todo quadro: no editor o sol é arrastado,
## no jogo ele desce.
func _levar_o_astro_ao_ceu() -> void:
	if not is_inside_tree():
		return
	var dono: AstroPixel = null
	for astro in _astros():
		if not astro.is_visible_in_tree():
			continue
		if dono == null or astro.presenca() > dono.presenca():
			dono = astro
	if dono == null:
		return
	for cliente in _da_minha_cena(GRUPO_DE_CLIENTES):
		if cliente is CeuPixel:
			var ceu := cliente as CeuPixel
			ceu.definir_astro(ceu.get_global_transform().affine_inverse() * dono.global_position)


# ───────────────────────────────────────────────────────────── o fundo

func _fundo() -> ParallaxBackground:
	return get_node_or_null(fundo) as ParallaxBackground


func _pedir_vestir() -> void:
	if _vestir_pedido or not is_inside_tree():
		return
	_vestir_pedido = true
	_revestir.call_deferred()


func _revestir() -> void:
	_vestir_pedido = false
	if not is_inside_tree():
		return
	_vestir_o_fundo()
	if _perfil != null:
		aplicar(_perfil)


## Veste com o material do horário todo desenho das camadas de arte do fundo.
## O material vai direto para o render (por cima do `material` vazio do nó):
## não é propriedade do nó, não aparece no Inspector e não é gravado na cena.
func _vestir_o_fundo() -> void:
	_despir_o_fundo()
	var bg := _fundo()
	if bg == null:
		return

	# Camada de arte é a que tem desenho para vestir. Céu e nuvens se pintam
	# sozinhos, e a camada de um astro só tem o astro: essas ficam de fora, e
	# nem contam na ordem que dá a profundidade.
	var camadas_de_arte: Array[ParallaxLayer] = []
	var arte_de_cada: Array[Array] = []
	for filho in bg.get_children():
		var camada := filho as ParallaxLayer
		if camada == null or camada.has_method(&"receber_perfil"):
			continue
		var arte: Array[CanvasItem] = []
		_juntar_arte(camada, arte)
		if not arte.is_empty():
			camadas_de_arte.append(camada)
			arte_de_cada.append(arte)

	for i in camadas_de_arte.size():
		var profundidade := _profundidade_de(camadas_de_arte[i], i, camadas_de_arte.size())
		for item: CanvasItem in arte_de_cada[i]:
			var material := ShaderMaterial.new()
			material.shader = SHADER_DO_FUNDO
			RenderingServer.canvas_item_set_material(item.get_canvas_item(), material.get_rid())
			_camadas.append({"item": item, "material": material, "profundidade": profundidade})


## Os desenhos de uma camada que recebem o material do horário: tudo o que não
## tem material próprio e não é (nem está dentro de) alguém que se pinta sozinho.
func _juntar_arte(no: Node, arte: Array[CanvasItem]) -> void:
	for filho in no.get_children():
		if filho.has_method(&"receber_perfil"):
			continue
		var item := filho as CanvasItem
		if item != null and item.material == null and not item.use_parent_material:
			arte.append(item)
		_juntar_arte(filho, arte)


func _despir_o_fundo() -> void:
	for camada in _camadas:
		var item: CanvasItem = camada["item"]
		if is_instance_valid(item) and item.material == null:
			RenderingServer.canvas_item_set_material(item.get_canvas_item(), RID())
	_camadas.clear()


## De 0 (colada na câmera) a 1 (no horizonte).
func _profundidade_de(camada: ParallaxLayer, indice: int, total: int) -> float:
	if camada.has_meta(&"profundidade"):
		return clampf(float(camada.get_meta(&"profundidade")), 0.0, 1.0)
	if camada.motion_scale.x > 0.001:
		return clampf(1.0 - camada.motion_scale.x, 0.0, 1.0)
	# Câmera parada (todas as camadas em 0): vale a ordem, de trás para a frente.
	if total <= 1:
		return 0.5
	return lerpf(0.8, 0.2, float(indice) / float(total - 1))


# ───────────────────────────────────────────────────────────── interface do mundo

func _ao_entrar_um_no(no: Node) -> void:
	var raiz := _raiz_da_cena()
	if raiz == null or not (no == raiz or raiz.is_ancestor_of(no)):
		return
	# Nasceu dentro de algo que já tem luz própria: herda.
	var herdou := false
	var pai := no.get_parent()
	while pai != null and pai != raiz:
		if pai is CanvasLayer:
			return
		if pai.is_in_group(GRUPO_LUZ_PROPRIA):
			herdou = true
			break
		pai = pai.get_parent()
	_soltar_a_interface(no, herdou)


## Tira da luz ambiente o que é interface (ver o cabeçalho). Como no fundo, o
## material vai para o render sem tocar na propriedade do nó.
func _soltar_a_interface(no: Node, herdou: bool = false) -> void:
	if no == null or no is CanvasLayer:
		return  # outro canvas: o ambiente daqui nem chega lá
	var solto := herdou or no.is_in_group(GRUPO_LUZ_PROPRIA)
	if no.is_in_group(GRUPO_RECEBE_LUZ):
		solto = false
	var item := no as CanvasItem
	if item != null and item.material == null and not item.use_parent_material:
		if solto or (_e_interface(item) and not no.is_in_group(GRUPO_RECEBE_LUZ)):
			RenderingServer.canvas_item_set_material(item.get_canvas_item(),
				_material_da_interface.get_rid())
	for filho in no.get_children():
		_soltar_a_interface(filho, solto)


func _e_interface(item: CanvasItem) -> bool:
	if item is Label or item is RichTextLabel:
		return true
	var textura := _textura_de(item)
	return textura != null and textura.resource_path.begins_with(PASTA_DA_INTERFACE)


func _textura_de(item: CanvasItem) -> Texture2D:
	var textura: Texture2D = null
	if item is Sprite2D:
		textura = (item as Sprite2D).texture
	elif item is AnimatedSprite2D:
		var quadros := (item as AnimatedSprite2D).sprite_frames
		if quadros != null:
			for animacao in quadros.get_animation_names():
				if quadros.get_frame_count(animacao) > 0:
					textura = quadros.get_frame_texture(animacao, 0)
					break
	elif item is NinePatchRect:
		textura = (item as NinePatchRect).texture
	elif item is TextureRect:
		textura = (item as TextureRect).texture
	# Recorte de uma folha: o que interessa é de que arquivo a folha veio.
	while textura is AtlasTexture and (textura as AtlasTexture).atlas != null:
		textura = (textura as AtlasTexture).atlas
	return textura


# ───────────────────────────────────────────────────────────── editor

func _mostrar_previa() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var m: Momento = momento if _previa == PREVIA_COMO_NO_JOGO else (_previa as Momento)
	aplicar(perfil_de(m))


# "previa_no_editor" aparece no Inspector mas não é gravada: é só o que o
# editor está mostrando, não o que a fase é.
func _get_property_list() -> Array[Dictionary]:
	return [{
		"name": "previa_no_editor",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Como a fase começa:-1,Entardecer:0,Crepúsculo:1,Noite:2",
	}]


func _get(propriedade: StringName) -> Variant:
	if propriedade == &"previa_no_editor":
		return _previa
	return null


func _set(propriedade: StringName, valor: Variant) -> bool:
	if propriedade == &"previa_no_editor":
		_previa = int(valor)
		_mostrar_previa()
		return true
	return false


# ───────────────────────────────────────────────────────────── apoio

func _raiz_da_cena() -> Node:
	return owner if owner != null else get_parent()


## Os nós de um grupo que são desta cena (no editor pode haver mais de uma
## cena na árvore; no jogo, autoloads).
func _da_minha_cena(grupo: StringName) -> Array[Node]:
	var lista: Array[Node] = []
	if not is_inside_tree():
		return lista
	var raiz := _raiz_da_cena()
	for no in get_tree().get_nodes_in_group(grupo):
		if raiz == null or no == raiz or raiz.is_ancestor_of(no):
			lista.append(no)
	return lista
