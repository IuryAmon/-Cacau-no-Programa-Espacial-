@tool
class_name PortaFase
extends Area2D

# --- PORTA ENTRE FASES ---
#
# Toda viagem entre o hub e as fases passa por aqui. A porta só consulta o
# autoload Progresso: se falta a habilidade, ela não abre — a placa é a
# fechadura visível.
#
# ENTRAR é igual em toda entrada de fase (e igual às portas da oficina e do
# simulador, porta_simulador.gd): de pé na frente dela, para CIMA — W no
# teclado, direcional ou analógico para cima no controle. O desenho do botão
# (IndicadorEntrada) só aparece com a Cacau perto, e só o do dispositivo em
# uso. Porta trancada não mostra botão nenhum.
#
# COMO EDITAR NO EDITOR:
#   Sprite            -> PNG da porta (o placeholder some sozinho)
#   rotulo            -> nome mostrado acima
#   IndicadorEntrada  -> o W / direcional (a posição é ajustada pelo formato)
#   cena_destino      -> arquivo .tscn para onde ela leva
#   tag_aqui/destino  -> o par que liga duas portas: ao chegar numa cena, o
#                        player nasce na porta cuja tag_aqui bate com a
#                        tag_destino da porta de origem
#   requer_habilidade -> deixa a porta trancada até a habilidade existir
#   no_piso           -> porta deitada no chão (o fosso de ventilação)

const CENA := "res://scenes/fases/componentes/porta_fase.tscn"
const GRUPO := "porta_fase"

@export var rotulo: String = "PORTA":
	set(valor):
		rotulo = valor
		if is_inside_tree():
			_atualizar_rotulo()
@export_file("*.tscn") var cena_destino: String = ""
@export var tag_aqui: String = ""
@export var tag_destino: String = ""
## Deixe vazio para porta livre, ou uma de: macarico, bumerangue, mochila,
## sinalizador, botas.
@export var requer_habilidade: String = ""
@export var requer_todas_celulas: bool = false
@export_multiline var mensagem_trancada: String = "Está trancada."
@export var cor_porta: Color = Color(0.45, 0.55, 0.65):
	set(valor):
		cor_porta = valor
		if is_inside_tree():
			_aplicar_cor()
## Porta deitada no chão (o fosso de ventilação do hub).
@export var no_piso: bool = false:
	set(valor):
		no_piso = valor
		if is_inside_tree():
			_aplicar_formato()

var _jogador_na_area: bool = false
var _jogador: CharacterBody2D = null
## Apertou para cima no ar: entra assim que pisar no chão (ainda na área).
var _pedido_pendente: bool = false
## Já apertou e a tela está apagando: o aviso some e um segundo toque não
## pede a troca de cena de novo.
var _entrando: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _placeholder: ColorRect = $Placeholder
@onready var _miolo: ColorRect = $Placeholder/Miolo
@onready var _colisao: CollisionShape2D = $Colisao
@onready var _label: Label = $Rotulo
@onready var _indicador: IndicadorEntrada = $IndicadorEntrada


static func criar(pai: Node, nome: String, pos_pe: Vector2, config: Dictionary) -> PortaFase:
	var porta: PortaFase = load(CENA).instantiate()
	porta.name = nome
	porta.position = pos_pe
	for chave in config:
		porta.set(chave, config[chave])
	Blockout.adicionar(pai, porta)
	return porta


func _ready() -> void:
	_aplicar_formato()
	_aplicar_cor()
	_atualizar_rotulo()
	Blockout.aplicar_arte(_sprite, _placeholder)
	if Engine.is_editor_hint():
		return

	add_to_group(GRUPO)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _aplicar_formato() -> void:
	if _placeholder == null:
		return
	var tamanho := Vector2(96, 18) if no_piso else Vector2(64, 110)
	var centro := Vector2(0, -9) if no_piso else Vector2(0, -55)
	_placeholder.size = tamanho
	_placeholder.position = centro - tamanho / 2.0
	if _miolo:
		var miolo_tam := Vector2(80, 6) if no_piso else Vector2(48, 94)
		_miolo.size = miolo_tam
		_miolo.position = (tamanho - miolo_tam) / 2.0
	if _colisao and _colisao.shape is RectangleShape2D:
		(_colisao.shape as RectangleShape2D).size = Vector2(120, 60) if no_piso else Vector2(110, 140)
		_colisao.position = Vector2(0, -20) if no_piso else Vector2(0, -60)
	# De baixo para cima: a porta, o botão de entrar e o nome. O botão fica na
	# mesma altura também no fosso: deitado no chão, a Cacau fica em pé em cima
	# dele, e o botão tem de passar da cabeça dela. O nome do fosso continua
	# baixo (logo acima dele fica o painel CHONPS no laboratório).
	if _indicador:
		_indicador.position = Vector2(0, -142)
	if _label:
		_label.position = Vector2(-_label.size.x / 2.0, -80 if no_piso else -222)


func _aplicar_cor() -> void:
	if _placeholder:
		_placeholder.color = cor_porta
	if _miolo:
		_miolo.color = cor_porta.darkened(0.35)


func _atualizar_rotulo() -> void:
	if _label:
		_label.text = rotulo


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# A habilidade pode chegar com ela parada aqui (e a porta destrancar).
	_indicador.mostrar(_jogador_na_area and _pode_entrar() and not _entrando)
	if _pedido_pendente and _jogador_na_area and _jogador != null and _jogador.is_on_floor():
		_pedido_pendente = false
		_tentar_entrar()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _jogador_na_area or _jogador == null or _entrando:
		return
	# Diálogo, popup ou puzzle na tela: o mundo não recebe comando nenhum.
	if Interacao.ocupada():
		return
	# O mesmo gesto das portas do simulador (ver porta_simulador.gd).
	var para_cima: bool = event.is_action_pressed("ui_up") \
		or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_W)
	if not para_cima:
		return
	# No analógico só vale "para cima" de verdade: andar na diagonal perto da
	# porta não entra nela sem querer.
	if event is InputEventJoypadMotion and not Controle.aponta_para_cima():
		return
	if _jogador.is_on_floor():
		_tentar_entrar()
	else:
		_pedido_pendente = true


func _pode_entrar() -> bool:
	if requer_habilidade != "" and not Progresso.tem_habilidade(requer_habilidade):
		return false
	if requer_todas_celulas and not Progresso.todas_as_celulas():
		return false
	return cena_destino != ""


func _tentar_entrar() -> void:
	if _entrando or not _pode_entrar():
		return
	_entrando = true
	Progresso.spawn_tag = tag_destino
	FadeTela.trocar_cena(self, cena_destino)


## Chamado no _ready() das fases: posiciona o player na porta de chegada.
static func posicionar_player_no_spawn(raiz: Node) -> void:
	if Progresso.spawn_tag == "":
		return
	var player := raiz.get_tree().get_first_node_in_group("player")
	if player == null:
		return
	for porta in raiz.get_tree().get_nodes_in_group(GRUPO):
		if porta.tag_aqui == Progresso.spawn_tag:
			player.global_position = porta.global_position + Vector2(0, -4)
			player.velocity = Vector2.ZERO
			# A câmera é filha do player e tem amortecimento ligado: sem o
			# encaixe, a cena clareia com a câmera ainda no ponto onde o player
			# estava no arquivo da cena e só depois ela desliza até a porta.
			CameraJogador.encaixar(player)
			# Primeiro ponto de retorno da visita: morrer antes de qualquer
			# bandeira ou sala renasce aqui, na porta por onde ela entrou.
			PontoDeRetorno.registrar(porta, player.global_position)
			break
	Progresso.spawn_tag = ""


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_jogador_na_area = true
		_jogador = body as CharacterBody2D


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_jogador_na_area = false
		_pedido_pendente = false
