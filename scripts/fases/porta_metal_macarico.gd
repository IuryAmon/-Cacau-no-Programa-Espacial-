@tool
class_name PortaMetalMacarico
extends StaticBody2D

# --- PORTA DE METAL (a fechadura do maçarico oxídrico) ---
#
# Uma folha de aço fechando a passagem. Não tem maçaneta, não tem puzzle e não
# tem chave: a única forma de passar é DERRETER a porta, e para isso a Cacau
# precisa já estar com o maçarico oxídrico no cinto.
#
# COMO SE USA NO JOGO: chegue perto e aperte E. Sem o maçarico, o E só devolve
# um aviso; com ele, a personagem primeiro RECUA para fora do vão (senão a
# folha derretendo desceria por cima dela), trava na pose da chama e a porta
# faz o caminho inteiro sozinha.
#
# A CENA DO DERRETIMENTO, em três atos:
#   1. PRÉ-AQUECIMENTO  a folha ainda inteira passa de metal frio a brasa —
#                       é o shader metal_incandescente.gdshader subindo o
#                       "calor" de 0 a 1, com a luz laranja acendendo junto;
#   2. DERRETIMENTO     os 16 quadros do sheet: a folha escorre de cima para
#                       baixo e vira poça no chão. O gradiente do shader cai a
#                       zero no caminho, porque uma poça não tem "topo mais
#                       quente" — o calor se espalha por igual;
#   3. RESFRIAMENTO     o "calor" desce de volta a 0 e o metal RECUPERA a cor
#                       original. O shader não repinta nada quando está frio,
#                       então a poça termina exatamente com a paleta em que a
#                       arte foi desenhada.
#
# COMO EDITAR NO EDITOR:
#   Porta         -> Sprite2D da folha fechada (Porta_metal_maçarico_detalhada)
#   Derretimento  -> AnimatedSprite2D com o sheet de 16 quadros. O quadro 0
#                    dele é pixel a pixel a mesma arte do Sprite2D acima, por
#                    isso a troca de um para o outro não pisca
#   Colisao       -> a folha em pé. É o que barra a passagem, e some quando a
#                    porta cai
#   Sucata...     -> o monte de metal frio do último quadro. TODA colisão filha
#                    com nome começando em "Sucata" (Sucata, Sucata2,
#                    SucataTopo...) entra no monte: use quantas formas precisar.
#                    Elas vêm DESLIGADAS e só ligam quando a folha termina de
#                    escorrer — é nelas que a Cacau sobe em vez de atravessar o
#                    metal
#   (colisões suas) -> qualquer forma com OUTRO nome fica sólida PARA SEMPRE,
#                    antes e depois do corte
#   AreaInteracao -> de quão longe o E funciona
#   Luz/Fagulhas/Fumaca -> o efeito em volta; mexa à vontade
#   Tempos (Inspector)  -> a duração de cada um dos três atos
#   Encenação (Inspector) -> quanto ela recua da margem da porta antes do corte
#
# Os dois sprites dividem o MESMO ShaderMaterial (marcado como
# "resource_local_to_scene", então cada porta do mapa tem a brasa dela): mudar
# o calor em um muda nos dois de uma vez, e não há risco de a folha e a poça
# ficarem em temperaturas diferentes.
#
# SAIR DA FASE OU MORRER NÃO SOLDA A PORTA DE VOLTA: ela se anota no
# EstadoMundo e volta já como a poça fria. A anotação é feita no INÍCIO do
# derretimento, de propósito — se uma torreta acertar a Cacau no meio da
# animação (ela fica parada na pose), a fase recarrega com a porta aberta em
# vez de exigir o corte de novo.

const CENA := "res://scenes/fases/componentes/porta_metal_macarico.tscn"

## Nome da animação do sheet no SpriteFrames.
const ANIM := &"derretendo"

## Habilidade do Progresso que destranca a porta.
const HABILIDADE := "macarico"

## Começo do nome das colisões que formam o monte de metal frio no chão.
## Toda filha que comece assim só ganha corpo depois do corte — ver
## _travar_passagem().
const PREFIXO_SUCATA := "Sucata"

enum Estado { FRIA, DERRETENDO, ABERTA }

@export_group("Tempos")
## Ato 1: quanto tempo a folha inteira fica esquentando antes de começar a ceder.
@export var duracao_preaquecimento: float = 0.9
## Ato 2: os 16 quadros do sheet cabem exatamente neste tempo, seja qual for o
## FPS gravado no SpriteFrames.
@export var duracao_derretimento: float = 2.2
## Ato 3: quanto a poça leva para voltar à cor de metal frio.
@export var duracao_resfriamento: float = 1.6

@export_group("Calor")
## Quanto o topo da folha esquenta antes da base (a chama entra por cima).
## Vai caindo sozinho até zero conforme a porta vira poça.
@export_range(0.0, 1.0) var gradiente_inicial: float = 0.35
## Força da luz laranja que a porta derrama no cenário no auge do calor.
@export var energia_da_luz: float = 2.2

@export_group("Encenação")
## Quanto a Cacau recua antes do primeiro sopro, contado da MARGEM da arte da
## porta até o corpo dela. A folha derretendo é alta e larga: quem aperta E
## coladinho na porta assiste à animação por cima da própria cabeça.
## Zero desliga o recuo e ela derrete de onde estiver.
@export var recuo_do_jogador: float = 26.0

@export_group("Texto")
@export var mensagem_sem_macarico: String = "Aço maciço. Só a chama do maçarico oxídrico passa daqui."

var _estado: int = Estado.FRIA
var _jogador_perto: bool = false
# Estado do balão, para o PopupFX só ser chamado na virada.
var _aviso_visivel: bool = false

## Temperatura da porta, de 0 (metal frio) a 1 (fusão). É isto que os dois
## tweens do derretimento animam; o setter repassa para o shader e para a luz.
var calor: float = 0.0:
	set(valor):
		calor = valor
		_aplicar_calor()

@onready var _porta: Sprite2D = $Porta
@onready var _derretimento: AnimatedSprite2D = $Derretimento
## A folha de aço em pé: é ela que barra a passagem, e some quando a porta cai
## — ver _travar_passagem().
@onready var _colisao: CollisionShape2D = $Colisao
## As formas do monte de metal frio: TODA colisão filha cujo nome comece com
## "Sucata" (Sucata, Sucata2, SucataRampa...). Ao contrário da folha, elas
## nascem DESLIGADAS e só ganham corpo quando a porta termina de escorrer —
## ver _travar_passagem().
@onready var _sucata: Array[Node] = _formas_da_sucata()
@onready var _area: Area2D = $AreaInteracao
@onready var _luz: PointLight2D = $Luz
@onready var _fagulhas: CPUParticles2D = $Fagulhas
@onready var _fumaca: CPUParticles2D = $Fumaca
@onready var _som_metal: AudioStreamPlayer2D = $SomMetal
@onready var _exclamacao: AnimatedSprite2D = get_node_or_null("ExclamacaoAnimada")
@onready var _tinta: ShaderMaterial = $Porta.material as ShaderMaterial


static func criar(pai: Node, nome: String, pos_base: Vector2, config: Dictionary = {}) -> PortaMetalMacarico:
	var porta: PortaMetalMacarico = load(CENA).instantiate()
	porta.name = nome
	porta.position = pos_base
	for chave in config:
		porta.set(chave, config[chave])
	Blockout.adicionar(pai, porta)
	return porta


func _ready() -> void:
	# No editor a porta é só a arte fria: nada de brasa, partículas ou balão.
	if Engine.is_editor_hint():
		return

	_aplicar_calor()
	if _exclamacao:
		_exclamacao.visible = false

	# A porta começa inteira: folha sólida, sucata sem corpo. Vale mesmo que
	# alguém esqueça de marcar "disabled" na forma nova do monte — a porta em
	# pé nunca tem poça no chão.
	_travar_passagem(true)

	if EstadoMundo.ja_feito(self):
		_nascer_derretida()
		return

	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	match _estado:
		Estado.FRIA:
			_atualizar_aviso()
			# Interacao.pediu() queima o toque de E, então fica por ÚLTIMO.
			if _jogador_perto and Interacao.pediu():
				_tentar_derreter()
		Estado.DERRETENDO:
			_acompanhar_calor()


# --- A INTERAÇÃO ---

func _tentar_derreter() -> void:
	if not Progresso.tem_habilidade(HABILIDADE):
		Blockout.aviso_flutuante(get_parent(), global_position + Vector2(0, -230),
			mensagem_sem_macarico)
		return
	_derreter()


## Os três atos, em sequência. Cada "await" é o fim de um deles.
func _derreter() -> void:
	_estado = Estado.DERRETENDO
	_esconder_aviso()
	EstadoMundo.marcar_feito(self)

	# A personagem segura a pose da chama, virada para a porta, do primeiro
	# sopro até a folha cair. O maçarico_sound e a luz azul da ponta vêm junto.
	var player := get_tree().get_first_node_in_group("player")

	# Primeiro ela sai de baixo da porta: a folha escorrendo é alta e larga, e
	# quem apertou E coladinho assistiria ao derretimento por cima da própria
	# cabeça. Só quando ela chega ao lugar é que a chama acende.
	await _abrir_espaco(player)
	if not _ainda_na_cena():
		return

	var na_pose: bool = is_instance_valid(player) and player.has_method("iniciar_uso_macarico")
	if na_pose:
		player.iniciar_uso_macarico(global_position.x)
	FerramentasHUD.destacar(HABILIDADE)

	_luz.enabled = true
	_fagulhas.emitting = true
	_fumaca.emitting = true

	# ATO 1 — a folha inteira esquentando.
	var esquentar := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	esquentar.tween_property(self, "calor", 1.0, duracao_preaquecimento)
	await esquentar.finished
	if not _ainda_na_cena():
		return

	# ATO 2 — o aço cedendo. A troca de sprite não pisca: o quadro 0 do sheet
	# é a mesma arte que o Sprite2D estava mostrando.
	_porta.visible = false
	_derretimento.visible = true
	_derretimento.speed_scale = _velocidade_da_animacao()
	_derretimento.play(ANIM)
	await _derretimento.animation_finished
	if not _ainda_na_cena():
		return

	# A folha caiu: a passagem abre no instante em que o último quadro fecha.
	_travar_passagem(false)
	_fagulhas.emitting = false
	if _som_metal.stream:
		_som_metal.play()
	if na_pose and is_instance_valid(player):
		player.encerrar_uso_macarico()

	# ATO 3 — a poça esfriando de volta para a cor de metal.
	var esfriar := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	esfriar.tween_property(self, "calor", 0.0, duracao_resfriamento)
	await esfriar.finished
	if not _ainda_na_cena():
		return

	_fumaca.emitting = false
	_luz.enabled = false
	_estado = Estado.ABERTA
	set_process(false)


# --- ESPAÇO PARA A CENA ---

## Tira a Cacau de baixo da porta antes do corte: ela recua, pelo lado em que
## já estava, até ficar a "recuo_do_jogador" pixels da margem da arte.
##
## Quem já está longe o bastante não se mexe — e se houver parede atrás dela, o
## próprio recuo para encostado nela (ver Player.recuar_ate_x).
func _abrir_espaco(player: Node) -> void:
	if recuo_do_jogador <= 0.0 or not is_instance_valid(player):
		return
	var corpo := player as Node2D
	if corpo == null or not corpo.has_method("recuar_ate_x"):
		return

	# O lado em que ela já está: o recuo nunca a faz contornar a porta.
	var lado := signf(corpo.global_position.x - global_position.x)
	if lado == 0.0:
		lado = -1.0
	var destino := _margem_x(lado) + lado * recuo_do_jogador
	# Ela já está mais longe do que o pedido: ninguém empurra ninguém PARA
	# PERTO da porta.
	if (destino - corpo.global_position.x) * lado <= 0.0:
		return

	await corpo.recuar_ate_x(destino)


## X global da margem da porta do lado pedido (-1 esquerda, +1 direita).
##
## É a ARTE que conta aqui, e não o "Colisao": o retângulo que barra a passagem
## é bem mais estreito que a folha desenhada, e quem cobre a personagem é a
## folha. Os dois sprites entram na conta porque o do derretimento é um
## tiquinho deslocado em relação ao da porta fechada.
func _margem_x(lado: float) -> float:
	var borda := 0.0
	if _porta.texture:
		borda = maxf(borda, _avanco(lado, _porta.position.x + _porta.offset.x * _porta.scale.x,
			_porta.texture.get_width(), _porta.scale.x))
	var quadro := _primeiro_quadro()
	if quadro:
		borda = maxf(borda, _avanco(lado, _derretimento.position.x + _derretimento.offset.x * _derretimento.scale.x,
			quadro.get_width(), _derretimento.scale.x))
	return to_global(Vector2(lado * borda, 0.0)).x


## Quanto a arte de um sprite avança para o lado pedido, contado do eixo da
## porta. Some dos dois lados, então o maior valor entre os sprites é sempre o
## que se estende mais longe daquele lado.
func _avanco(lado: float, centro: float, largura: float, escala: float) -> float:
	return lado * centro + largura * 0.5 * absf(escala)


## O quadro 0 do sheet, que é a mesma arte da porta fechada.
func _primeiro_quadro() -> Texture2D:
	if _derretimento.sprite_frames == null:
		return null
	if _derretimento.sprite_frames.get_frame_count(ANIM) <= 0:
		return null
	return _derretimento.sprite_frames.get_frame_texture(ANIM, 0)


## Voltar à fase (ou morrer e recarregar) não solda a porta de novo: ela nasce
## como a poça fria do último quadro, sem colisão e sem brasa.
func _nascer_derretida() -> void:
	_estado = Estado.ABERTA
	calor = 0.0
	_porta.visible = false
	_derretimento.visible = true
	_derretimento.animation = ANIM
	_derretimento.frame = maxi(_derretimento.sprite_frames.get_frame_count(ANIM) - 1, 0)
	_travar_passagem(false)
	_luz.enabled = false
	_fagulhas.emitting = false
	_fumaca.emitting = false
	set_process(false)


## A troca de corpo da porta: sai a FOLHA DE AÇO em pé, entra a SUCATA no chão.
##
## Os dois lados vêm dentro do componente e se revezam:
##   Colisao   -> o retângulo da porta em pé. Barra a passagem enquanto ela é
##                porta, e acaba junto com ela;
##   Sucata*   -> o monte de metal frio do último quadro. QUALQUER colisão
##                filha com nome começando em "Sucata" entra aqui, então o
##                monte pode ser feito de quantas formas você quiser (um
##                polígono para a rampa, um retângulo para o topo...). Todas
##                nascem DESLIGADAS — a porta em pé não tem poça nenhuma no
##                chão — e ligam juntas quando a folha termina de escorrer, que
##                é quando a Cacau passa a subir no metal em vez de atravessar.
##
## Formas com OUTROS nomes ficam sólidas para sempre, antes e depois do corte:
## a varredura NÃO é genérica de propósito.
func _travar_passagem(travada: bool) -> void:
	if _colisao:
		_colisao.set_deferred("disabled", not travada)
	for forma in _sucata:
		forma.set_deferred("disabled", travada)


## As formas do monte de sucata, procuradas pelo nome (ver _travar_passagem).
## Colher uma vez no _ready basta: o monte não muda de forma durante a fase.
func _formas_da_sucata() -> Array[Node]:
	var formas: Array[Node] = []
	for filho in get_children():
		if not String(filho.name).begins_with(PREFIXO_SUCATA):
			continue
		if filho is CollisionShape2D or filho is CollisionPolygon2D:
			formas.append(filho)
	return formas


# --- CALOR ---

## Repassa a temperatura para quem a desenha: o shader dos dois sprites (é o
## mesmo material nos dois) e a luz derramada no cenário.
func _aplicar_calor() -> void:
	if _tinta:
		_tinta.set_shader_parameter("calor", calor)
	if _luz:
		_luz.energy = energia_da_luz * calor


## Enquanto derrete: a brasa treme na luz (o shader já treme na cor) e o
## gradiente vertical some conforme a folha em pé vira poça deitada — poça não
## tem topo mais quente que a base.
func _acompanhar_calor() -> void:
	if _luz and _luz.enabled:
		_luz.energy = energia_da_luz * calor * randf_range(0.85, 1.12)
	if _tinta == null or _derretimento.sprite_frames == null:
		return
	var quadros := _derretimento.sprite_frames.get_frame_count(ANIM)
	var progresso := 0.0 if quadros <= 1 else float(_derretimento.frame) / float(quadros - 1)
	_tinta.set_shader_parameter("gradiente_vertical", lerpf(gradiente_inicial, 0.0, progresso))


## Faz os quadros do sheet caberem exatamente em "duracao_derretimento",
## qualquer que seja o FPS gravado no SpriteFrames.
func _velocidade_da_animacao() -> float:
	if _derretimento.sprite_frames == null or duracao_derretimento <= 0.0:
		return 1.0
	var quadros := _derretimento.sprite_frames.get_frame_count(ANIM)
	var fps: float = _derretimento.sprite_frames.get_animation_speed(ANIM)
	if quadros <= 0 or fps <= 0.0:
		return 1.0
	return (float(quadros) / duracao_derretimento) / fps


# --- BALÃO DE "DÁ PARA INTERAGIR" ---

func _atualizar_aviso() -> void:
	if _exclamacao == null or _jogador_perto == _aviso_visivel:
		return
	_aviso_visivel = _jogador_perto
	if _jogador_perto:
		PopupFX.mostrar(_exclamacao)
	else:
		PopupFX.esconder(_exclamacao)


func _esconder_aviso() -> void:
	if _exclamacao and _aviso_visivel:
		_aviso_visivel = false
		PopupFX.esconder(_exclamacao)


# --- ARREDORES ---

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_jogador_perto = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_jogador_perto = false


## Cada ato espera um tween ou uma animação; entre um e outro a fase pode ter
## sido trocada ou recarregada (morte). Sem esta guarda o resto da sequência
## mexeria em nós já apagados.
func _ainda_na_cena() -> bool:
	return is_instance_valid(self) and is_inside_tree()
