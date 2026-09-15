@tool
class_name CaixaEletrica
extends AlvoBumerangue

# --- CAIXA ELÉTRICA (ALVO DA OFICINA DE CARBONO) ---
#
# É o AlvoBumerangue de sempre — mesma lógica de alvo (janela de tempo, alvo
# duplo, "persistir", sinal `mudou`) — só que vestido de caixa de força: o
# bumerangue arrebenta a tampa, os fios ficam expostos e a caixa passa a
# estalar sozinha.
#
# LINHA DO TEMPO DE UM ACERTO
#   frame do acerto  "metal hit" + rajada de faíscas + clarão da luz, tudo no
#                    MESMO frame (é o que faz o som parecer vir da caixa)
#   0,0s -> ~0,35s   o nó Visual toca "quebrando": CAIXA ELETRICA 0 -> 3
#   fim da animação  trava no último quadro e o ARCO começa: "eletricidade" +
#                    faíscas azuis + fumaça + luz tremulando, em estalos que se
#                    repetem (som e faíscas sempre no mesmo frame)
#
# ONDE AJUSTAR CADA COISA (nada aqui é criado por código — tudo é nó):
#   Visual           SpriteFrames com "intacta" e "quebrando". Troque os PNGs e
#                    a velocidade (FPS) direto no inspetor.
#   Colisao          O HITBOX. Arraste as alças na viewport.
#   FaiscasImpacto   estilhaço branco/laranja do metal apanhando.
#   FaiscasArco      rajada azul que sai junto com cada "eletricidade.mp3".
#   FiosSoltos       chuvisco de faíscas que acompanha cada estalo (dura o
#                    tempo do export "duracao_estalo" e para até o próximo).
#   Fumaca           fumacinha que sobe o tempo todo depois da quebra.
#   BrilhoAlvo       halo quente da caixa INTEIRA (o aviso silencioso de que
#                    ali cabe uma bumerangada). Cor e tamanho aqui; a
#                    respiração vem dos exports do grupo "Aviso de alvo".
#   FaiscaAviso      a faísca solta que escapa da fresta da tampa fechada.
#   TempoFaisca      relógio entre uma faísca de espera e a outra.
#   LuzArco          cor, alcance e textura do brilho (a INTENSIDADE é animada
#                    pelos exports do grupo "Luz do arco", abaixo).
#   SomImpacto       "metal hit.mp3"     — volume/atenuação no próprio nó.
#   SomEletricidade  "eletricidade.mp3"  — volume/atenuação no próprio nó.
#                    Os exports "attenuation" (curva de queda) e
#                    "max_distance" (onde vira silêncio) do próprio
#                    AudioStreamPlayer2D controlam o quanto o choque some
#                    conforme o jogador se afasta.
#   TempoArco        relógio entre um estalo e outro.
#   TempoEstalo      relógio que fecha o chuvisco no fim de cada estalo.

const ANIM_INTACTA := &"intacta"
const ANIM_QUEBRANDO := &"quebrando"

@export_group("Caixa elétrica")
## Ligado: quando a janela do alvo fecha, a caixa "conserta" e volta à arte
## intacta — útil para reaproveitar o mesmo alvo várias vezes.
## Desligado (padrão): uma vez quebrada, fica quebrada.
@export var restaurar_ao_desligar: bool = false

@export_group("Arco elétrico")
## Depois de quebrada, os fios continuam estalando de tempos em tempos.
@export var repetir_arco: bool = true
## Intervalo entre um estalo e o outro (sorteado dentro da faixa).
@export_range(0.05, 10.0, 0.05) var intervalo_arco_min: float = 1.5
@export_range(0.05, 10.0, 0.05) var intervalo_arco_max: float = 3.2
## Quanto tempo o chuvisco dos FiosSoltos acompanha cada estalo. Depois disso
## ele para e a caixa fica quieta até o próximo — é o que faz a imagem
## respeitar a mesma pausa do áudio.
@export_range(0.05, 5.0, 0.05) var duracao_estalo: float = 0.6

@export_group("Áudio")
## Variação aleatória de tom, para o mesmo arquivo não soar repetitivo.
@export_range(0.0, 0.5, 0.01) var variacao_pitch: float = 0.12

@export_group("Aviso de alvo")
## O aviso silencioso de que ali cabe uma bumerangada, no lugar de um rótulo
## escrito no mapa: um halo quente que respira devagar em volta da caixa e,
## de vez em quando, uma faísca solta saindo da fresta da tampa. Sem texto e
## sem som — é periférico de propósito, para o olho achar a caixa sem que o
## jogo precise apontar o dedo.
##
## A gramática é a mesma do resto da caixa, só em outra chave: o aviso é
## QUENTE, lento e regular (equipamento de pé, esperando); o arco depois de
## quebrada é FRIO, rápido e irregular (equipamento arrebentado). Por isso o
## aviso apaga no instante em que a tampa abre.
##
## NÃO existe condição nenhuma para o aviso além desta chave e da caixa estar
## inteira: ele acende no primeiro frame da fase, com ou sem bumerangue na
## mochila, e só apaga quando a tampa é arrebentada. A caixa é um lugar
## interessante antes de ser um alvo resolvível — ver ela piscando sem poder
## fazer nada é o que ensina a procurar a ferramenta.
##
## (Já existiu um "avisar_so_com_bumerangue" aqui. Foi removido de propósito:
## o Godot grava o valor do export dentro das cenas ao salvar, então mudar o
## padrão no script não mudava as caixas já colocadas no mapa — elas ficavam
## presas no comportamento antigo sem aviso nenhum.)
@export var avisar_alvo: bool = true
## Opacidade do halo no fundo e no alto da respiração. Mantenha baixo: a graça
## é quase não dar para dizer que tem alguma coisa piscando ali.
@export_range(0.0, 1.0, 0.01) var brilho_aviso_min: float = 0.10
@export_range(0.0, 1.0, 0.01) var brilho_aviso_max: float = 0.32
## Ciclo completo da respiração do halo, em segundos. Lento o bastante para
## não competir com nada que se mexa na tela.
@export_range(0.5, 12.0, 0.1) var respiracao_aviso: float = 2.8
## Faixa de tempo entre uma faísca de espera e a outra (sorteada).
@export_range(0.2, 30.0, 0.1) var intervalo_faisca_min: float = 2.6
@export_range(0.2, 30.0, 0.1) var intervalo_faisca_max: float = 5.4

@export_group("Luz do arco")
## Brilho constante enquanto a caixa está quebrada.
@export_range(0.0, 8.0, 0.05) var energia_base: float = 0.45
## Pico do clarão em cada estalo (e no baque do bumerangue).
@export_range(0.0, 8.0, 0.05) var energia_pico: float = 2.2
## Quanto a luz "respira" entre um estalo e outro. 0 = luz parada.
@export_range(0.0, 1.0, 0.01) var tremulacao: float = 0.35

## True depois que a tampa foi arrebentada. Fica separado de `ativo` de
## propósito: `ativo` é o estado do PUZZLE (pode fechar quando a janela expira),
## `quebrada` é o estado da CAIXA (não desfaz sozinho).
var quebrada: bool = false

var _arco_ligado: bool = false
var _clarao: float = 0.0
var _fase_tremor: float = 0.0
var _aviso_ligado: bool = false
var _fase_aviso: float = 0.0

@onready var _visual: AnimatedSprite2D = get_node_or_null("Visual")
@onready var _faiscas_impacto: CPUParticles2D = get_node_or_null("FaiscasImpacto")
@onready var _faiscas_arco: CPUParticles2D = get_node_or_null("FaiscasArco")
@onready var _fios_soltos: CPUParticles2D = get_node_or_null("FiosSoltos")
@onready var _fumaca: CPUParticles2D = get_node_or_null("Fumaca")
@onready var _luz: PointLight2D = get_node_or_null("LuzArco")
@onready var _som_impacto: AudioStreamPlayer2D = get_node_or_null("SomImpacto")
@onready var _som_eletricidade: AudioStreamPlayer2D = get_node_or_null("SomEletricidade")
@onready var _tempo_arco: Timer = get_node_or_null("TempoArco")
@onready var _tempo_estalo: Timer = get_node_or_null("TempoEstalo")
@onready var _brilho_aviso: Sprite2D = get_node_or_null("BrilhoAlvo")
@onready var _faisca_aviso: CPUParticles2D = get_node_or_null("FaiscaAviso")
@onready var _tempo_faisca: Timer = get_node_or_null("TempoFaisca")


func _ready() -> void:
	# A base cuida do rótulo, do grupo "alvo_bumerangue" e de restaurar o
	# estado quando `persistir` está ligado — e já chama _atualizar_visual().
	super()
	if Engine.is_editor_hint():
		return

	if _luz:
		_luz.energy = 0.0
	if _visual and not _visual.animation_finished.is_connected(_ao_fim_da_animacao):
		_visual.animation_finished.connect(_ao_fim_da_animacao)
	if _tempo_arco and not _tempo_arco.timeout.is_connected(_pulsar_arco):
		_tempo_arco.timeout.connect(_pulsar_arco)
	if _tempo_estalo and not _tempo_estalo.timeout.is_connected(_fim_do_estalo):
		_tempo_estalo.timeout.connect(_fim_do_estalo)
	if _tempo_faisca and not _tempo_faisca.timeout.is_connected(_soltar_faisca_de_aviso):
		_tempo_faisca.timeout.connect(_soltar_faisca_de_aviso)
	# Nasce apagado: quem acende é _atualizar_aviso(), no primeiro frame em que
	# a caixa estiver inteira e o bumerangue já na mão.
	if _brilho_aviso:
		_brilho_aviso.modulate.a = 0.0

	# Alvo que voltou ligado de uma morte/recarga (persistir): a caixa já nasce
	# arrebentada e estalando, mas sem o baque do metal — aquele acerto
	# aconteceu numa vida anterior.
	if ativo:
		_quebrar(false)


func _process(delta: float) -> void:
	super._process(delta)  # a janela de tempo do alvo continua sendo da base
	if Engine.is_editor_hint():
		return

	_atualizar_aviso(delta)
	if _luz == null:
		return

	# O clarão de cada estalo decai sozinho; o resto é o tremor do arco.
	_clarao = move_toward(_clarao, 0.0, delta * 6.0)
	if not _arco_ligado:
		_luz.energy = _clarao * energia_pico
		return
	_fase_tremor += delta * 23.0
	var tremor: float = 1.0 + sin(_fase_tremor) * tremulacao * 0.5 + randf_range(-tremulacao, tremulacao) * 0.5
	_luz.energy = maxf(0.0, energia_base * tremor) + _clarao * energia_pico


# --- ACERTO ---

func atingir_bumerangue() -> void:
	# Guardado ANTES do super(): a base zera essa condição ao ligar o alvo.
	var ja_resolvida: bool = ativo and permanece_ativo
	super.atingir_bumerangue()
	if ja_resolvida:
		return
	if quebrada:
		_estalo()  # já estava aberta: só mais um baque, sem repetir a animação
		return
	_quebrar()


## `com_impacto = false` monta o estado final sem barulho de metal nem
## animação — é o caminho da restauração de estado.
func _quebrar(com_impacto: bool = true) -> void:
	quebrada = true
	# A tampa abriu: o convite já foi aceito, o halo quente sai de cena antes
	# de o arco frio entrar. Os dois nunca aparecem juntos.
	_desligar_aviso()
	if com_impacto:
		_estalo()
		if _tem_animacao(ANIM_QUEBRANDO):
			_visual.animation = ANIM_QUEBRANDO
			_visual.frame = 0
			_visual.play(ANIM_QUEBRANDO)
			return  # o arco só entra quando a tampa terminar de abrir
	_mostrar_quebrada()
	_ligar_arco()


func _ao_fim_da_animacao() -> void:
	if _visual == null or _visual.animation != ANIM_QUEBRANDO:
		return
	_mostrar_quebrada()
	_ligar_arco()


## O baque do metal: som e faíscas disparados no mesmo frame.
func _estalo() -> void:
	_tocar(_som_impacto)
	_disparar(_faiscas_impacto)
	_clarao = 1.0


# --- AVISO DE ALVO (a caixa inteira, esperando a bumerangada) ---

## O halo respira e a faísca cai de tempos em tempos enquanto a caixa estiver
## INTEIRA. Nada mais entra nessa conta: acende no primeiro frame da fase e só
## apaga quando a tampa abre — inclusive na caixa que já nasce quebrada por
## causa do "persistir", que nunca chega a acender.
func _atualizar_aviso(delta: float) -> void:
	if _brilho_aviso == null:
		return

	if not (avisar_alvo and not quebrada):
		if _aviso_ligado:
			_desligar_aviso()
		return

	if not _aviso_ligado:
		_aviso_ligado = true
		_fase_aviso = 0.0
		_agendar_faisca_de_aviso()

	# Respiração no seno: sobe e desce no mesmo ritmo, sem começo nem fim
	# marcados, que é o que faz o brilho passar por "ambiente" e não por
	# "pisca-pisca de tutorial".
	_fase_aviso += delta * TAU / maxf(0.1, respiracao_aviso)
	var onda: float = (sin(_fase_aviso) + 1.0) * 0.5
	_brilho_aviso.modulate.a = lerpf(brilho_aviso_min, brilho_aviso_max, onda)


func _desligar_aviso() -> void:
	_aviso_ligado = false
	if _brilho_aviso:
		_brilho_aviso.modulate.a = 0.0
	if _faisca_aviso:
		_faisca_aviso.emitting = false
	if _tempo_faisca:
		_tempo_faisca.stop()


func _agendar_faisca_de_aviso() -> void:
	if _tempo_faisca == null:
		return
	var teto: float = maxf(intervalo_faisca_min, intervalo_faisca_max)
	_tempo_faisca.start(randf_range(intervalo_faisca_min, teto))


func _soltar_faisca_de_aviso() -> void:
	if not _aviso_ligado:
		return
	_disparar(_faisca_aviso)
	_agendar_faisca_de_aviso()


# --- ARCO ELÉTRICO ---

func _ligar_arco() -> void:
	if _arco_ligado:
		return
	_arco_ligado = true
	# A fumaça é a única camada constante: sai da caixa aberta o tempo todo.
	# Faísca e som andam juntos, em estalos.
	if _fumaca:
		_fumaca.emitting = true
	_pulsar_arco()


## Um estalo do arco. O som de eletricidade, a rajada de faíscas, o chuvisco
## dos fios e o clarão saem todos na MESMA chamada, de propósito: é isso que
## faz o barulho parecer vir dos fios, e é o que mantém a imagem no mesmo
## compasso do áudio quando você mexe no intervalo.
func _pulsar_arco() -> void:
	if not _arco_ligado:
		return
	_tocar(_som_eletricidade)
	_disparar(_faiscas_arco)
	_clarao = 1.0
	if _fios_soltos:
		_fios_soltos.emitting = true
	if _tempo_estalo:
		_tempo_estalo.start(duracao_estalo)
	if repetir_arco and _tempo_arco:
		var teto: float = maxf(intervalo_arco_min, intervalo_arco_max)
		_tempo_arco.start(randf_range(intervalo_arco_min, teto))


## Fim do estalo: os fios param de chuviscar e a caixa fica quieta (só a
## fumaça e o brilho baixo) até o próximo.
func _fim_do_estalo() -> void:
	if _fios_soltos:
		_fios_soltos.emitting = false


func _desligar_arco() -> void:
	_arco_ligado = false
	_clarao = 0.0
	if _tempo_arco:
		_tempo_arco.stop()
	if _tempo_estalo:
		_tempo_estalo.stop()
	if _fios_soltos:
		_fios_soltos.emitting = false
	if _fumaca:
		_fumaca.emitting = false
	if _som_eletricidade and _som_eletricidade.playing:
		_som_eletricidade.stop()
	if _luz:
		_luz.energy = 0.0


# --- APRESENTAÇÃO ---

## Chamado pela base no _ready() e a cada mudança de estado do alvo. Aqui só
## mora a arte PARADA; barulho e faísca são sempre disparados pelo acerto.
func _atualizar_visual() -> void:
	if _visual == null:
		return
	if not quebrada:
		_mostrar_intacta()
		return
	if restaurar_ao_desligar and not ativo:
		_restaurar()


func _restaurar() -> void:
	quebrada = false
	_desligar_arco()
	_mostrar_intacta()


func _mostrar_intacta() -> void:
	if not _tem_animacao(ANIM_INTACTA):
		return
	_visual.stop()
	_visual.animation = ANIM_INTACTA
	_visual.frame = 0


func _mostrar_quebrada() -> void:
	if not _tem_animacao(ANIM_QUEBRANDO):
		return
	_visual.stop()
	_visual.animation = ANIM_QUEBRANDO
	_visual.frame = _visual.sprite_frames.get_frame_count(ANIM_QUEBRANDO) - 1


func _tem_animacao(nome: StringName) -> bool:
	return _visual != null and _visual.sprite_frames != null and _visual.sprite_frames.has_animation(nome)


# --- FERRAMENTAS ---

func _tocar(player: AudioStreamPlayer2D) -> void:
	if player == null or player.stream == null:
		return
	player.pitch_scale = 1.0 + randf_range(-variacao_pitch, variacao_pitch)
	player.play()


func _disparar(particulas: CPUParticles2D) -> void:
	if particulas == null:
		return
	particulas.restart()
	particulas.emitting = true
