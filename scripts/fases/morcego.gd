@tool
class_name Morcego
extends CharacterBody2D

# --- MORCEGO (INIMIGO DE CORREDOR) ---
#
# Dorme de cabeça para baixo no teto. Quando a Cacau chega perto ele acorda,
# solta do teto e vem voando atrás dela — e de tempos em tempos dá um BOTE: um
# mergulho em linha reta que tira uma vida. Morre no bumerangue.
#
# --- A LUTA, DO PONTO DE VISTA DE QUEM JOGA ---
#
# Ele foi desenhado em volta de UMA pergunta: o que faz ser gostoso matá-lo?
#
#   1. DÁ PARA ACERTAR. Voando, ele não fica em qualquer lugar: ele se posta na
#      DIAGONAL da Cacau ("posto": 115 px para o lado e 115 para cima). Quem
#      joga no teclado só consegue mirar em 8 direções — e a diagonal é uma
#      delas. Ele balança em volta desse ponto, então ainda é preciso escolher
#      a hora, mas nunca fica num ângulo impossível. E dois do mesmo lado
#      fazem FILA nessa mesma diagonal, um atrás do outro: como o bumerangue
#      atravessa os alvos, um arremesso bem mirado pega a fila inteira.
#   2. O BOTE AVISA. Antes de mergulhar ele para no ar, se encolhe, o contorno
#      pisca em vermelho cada vez mais rápido e ele solta quatro pios subindo
#      ("tempo_de_preparo"). É meio segundo para decidir: sair de baixo, ou
#      acertá-lo ali mesmo, parado — o que CANCELA o bote. É o mesmo prêmio da
#      torreta: quem arremessa na hora certa desarma o golpe que já vinha.
#   3. ERRAR CUSTA PARA ELE. O mergulho é uma linha reta travada no instante em
#      que começa: quem saiu de baixo vê o morcego dar de cara no chão e ficar
#      tonto, com estrelinhas, do lado dela — a deixa para o arremesso.
#   4. IDA E VOLTA. Ele aguenta DOIS acertos ("vida"), e o bumerangue acerta
#      na ida e na volta. O primeiro o joga para trás, tonto, na linha do voo;
#      se a Cacau ficar onde está, a volta passa por ele de novo e mata. Um
#      arremesso bem dado resolve — "tum... TUM!" — e um arremesso torto pede
#      outro. Com "vida" = 1 ele morre no primeiro toque.
#   5. A MORTE TEM PESO. No golpe final o jogo trava um instante, o morcego
#      fica branco, a câmera treme e o corpo sai ARREMESSADO no rumo do
#      bumerangue (mais longe se o arremesso foi em corrida), girando, quica no
#      chão e some numa fumaça. No caminho ele ainda derruba outro morcego que
#      estiver na frente.
#
# --- OS ESTADOS ---
#
#   DORMINDO     pendurado no teto, olhos apagados. Acorda com a Cacau dentro
#                do "raio_de_alerta" e à vista — ou levando um acerto, ou
#                quando um vizinho acorda (o bando acorda em fila).
#   ACORDANDO    acende os olhos, treme, solta do teto e vira de cabeça para cima.
#   PAIRANDO     o "dormindo" de quem não tem teto ("dorme_no_teto" desligado):
#                fica voando em volta do lugar em que foi posto.
#   VOANDO       atrás da Cacau, até o posto na diagonal dela.
#   PREPARANDO   o aviso do bote (item 2).
#   MERGULHANDO  o bote. Só AQUI ele machuca: encostar num morcego voando não
#                tira vida nenhuma.
#   RECUPERANDO  o respiro depois do bote, subindo de volta.
#   ATORDOADO    tonto: levou um acerto e sobreviveu, ou errou o bote e bateu
#                no cenário. Não ataca, não foge e cai devagar.
#   VOLTANDO     a Cacau foi embora ("raio_de_desistencia"): volta para o
#                ninho e dorme de novo. É o que impede o bando de seguir a
#                jogadora até a saída do corredor.
#   MORTO        o corpo voando, quicando e sumindo.
#
# Só um morcego do bando dá o bote por vez: enquanto um prepara ou mergulha, os
# outros esperam. Dois ou três em cima dela ao mesmo tempo viram uma fila de
# botes para desviar, e não um golpe só que ninguém consegue ler.
#
# Com diálogo, puzzle ou card na tela, ele espera junto (Interacao.ocupada) —
# não é justo apanhar enquanto a jogadora lê. E ele não morde quem está sem o
# controle (cutscene, chegada andando, recuo de outro dano) nem quem está no
# dash da mochila: o dash atravessa o bote.
#
# COMO EDITAR NO EDITOR (tudo é nó ou export — nada é criado escondido):
#   ONDE POR   solte o morcego um pouco ABAIXO do teto (até "alcance_do_teto",
#              200 px): no jogo ele sobe e se pendura sozinho, com os pés na
#              face do tile. Onde não houver teto com colisão em cima, ele se
#              pendura exatamente onde você deixou — serve para uma viga ou um
#              cano de enfeite. No editor ele já aparece de cabeça para baixo.
#   Visual     a arte: as sete animações (dormindo, voando, preparando,
#              mergulho, recuperando, golpe, morrendo). Velocidade e quadros se
#              mudam aqui, no painel SpriteFrames. O material dele é o shader do
#              contorno e dos olhos (shaders/morcego.gdshader).
#   Colisao    o corpo contra PAREDE, CHÃO E TETO. Pequeno de propósito: é ele
#              que não deixa o morcego atravessar o cenário.
#   AreaAlvo   onde o bumerangue pega (uma HitboxBumerangue). Arraste as alças
#              para deixar mais fácil ou mais difícil de acertar.
#   Voz        o alto-falante. Volume e alcance de TODOS os sons dele são deste
#              nó; os arquivos ficam no grupo "Sons" do Inspetor do Morcego.
#
# Física: camada 0 / máscara 1, como a Sentinela — esbarra no cenário, mas não
# empurra a Cacau nem é empurrado por ela, e não segura o bumerangue (que só
# para em parede).

## Acordou (ou, pairando, viu a Cacau). É o instante em que ele vira ameaça.
signal acordou
## O bumerangue acertou e ele aguentou. `vida_restante` é o que sobrou.
signal levou_golpe(vida_restante: int)
## O golpe final. O corpo ainda voa e some sozinho depois disto.
signal morreu

enum Estado { DORMINDO, ACORDANDO, PAIRANDO, VOANDO, PREPARANDO, MERGULHANDO,
	RECUPERANDO, ATORDOADO, VOLTANDO, MORTO }

const CENA := "res://scenes/fases/componentes/morcego.tscn"
const GRUPO := &"morcego"
const GRUPO_ALVO := &"alvo_bumerangue"

const ANIM_DORMINDO := &"dormindo"
const ANIM_VOANDO := &"voando"
const ANIM_PREPARANDO := &"preparando"
const ANIM_MERGULHO := &"mergulho"
const ANIM_RECUPERANDO := &"recuperando"
const ANIM_GOLPE := &"golpe"
const ANIM_MORRENDO := &"morrendo"

# --- NINHO ---

## Da face do teto até a origem do morcego pendurado. No quadro "dormindo",
## virado de cabeça para baixo, os pés ficam 10 pixels de arte acima do meio do
## quadro — vezes a escala 2 do Visual.
const PENDURADO_ABAIXO_DO_TETO := 20.0
## O raio que procura o teto sai um pouco ABAIXO de onde o morcego foi posto:
## assim ele acha o teto mesmo que tenha sido solto encostado (ou um tico
## dentro) do tile.
const FOLGA_DO_RAIO_DO_TETO := 40.0
## Quantos quadros de física ele insiste em achar o teto. A colisão dos tiles
## nasce junto com a cena: no primeiro quadro ela pode ainda não existir.
const TENTATIVAS_DE_TETO := 3
## O AreaAlvo sobe este tanto com ele pendurado: de cabeça para baixo o corpo
## fica acima do meio do quadro.
const ALVO_PENDURADO := Vector2(0, -8)
## Balanço de quem dorme pendurado (radianos).
const BALANCO_DORMINDO := 0.045

# --- ACORDAR ---

const TEMPO_ACORDAR := 0.42
## Instante, dentro do acordar, em que ele solta do teto e vira.
const TEMPO_DE_SOLTAR := 0.26
const QUEDA_AO_SOLTAR := 95.0
## Os vizinhos acordam em fila, e não todos no mesmo quadro: a espera de cada
## um é sorteada nesta faixa.
const ATRASO_DO_BANDO := Vector2(0.15, 0.45)

# --- VOO ---

## px/s² com que ele muda de velocidade. É o que dá a preguiça do voo: ele não
## gruda no posto, ele CHEGA nele.
const ACELERACAO := 560.0
## A esta distância do alvo ele começa a frear.
const DISTANCIA_DE_CHEGADA := 70.0
## O balanço em volta do posto (px): largo para os lados, curto na altura.
const ONDA := Vector2(22, 12)
const ONDA_RITMO := Vector2(1.3, 2.1)
## Só troca de lado quando a Cacau passa este tanto para o outro lado dele —
## sem a folga ele ficaria trocando a cada passo dela.
const FOLGA_DE_LADO := 24.0
## Com mais de um do mesmo lado, cada um se posta este tanto mais longe que o
## da frente, na mesma diagonal (0.33 = um terço do "posto" a mais por lugar).
const FILA_NA_DIAGONAL := 0.33
## Morcegos mais juntos que isto se empurram, para o bando não empilhar.
const DISTANCIA_DO_BANDO := 46.0
const EMPURRAO_DO_BANDO := 150.0
## Tempo com a Cacau além do "raio_de_desistencia" antes de largar dela.
const TEMPO_PARA_DESISTIR := 0.6
## A esta distância do ninho ele dá o voo de volta por terminado.
const CHEGOU_NO_NINHO := 6.0
## Quadro da animação "voando" em que as asas descem: é nele que a batida soa.
const QUADRO_DA_BATIDA := 2
## Faixa (sorteada, uma vez por morcego) da velocidade das animações dele.
const RITMO_DAS_ASAS := Vector2(0.88, 1.14)

# --- BOTE ---

## Recém-saído de outro estado, ele espera isto antes de pensar em bote.
const TEMPO_MINIMO_VOANDO := 0.5
## Do instante em que acorda até o primeiro aviso de bote. É o tempo de a
## jogadora ver o morcego descer do teto e se postar antes de ele ameaçar.
const ESPERA_DO_PRIMEIRO_BOTE := 1.1
## Só mergulha de CIMA: precisa estar pelo menos isto acima do meio dela.
const ALTURA_MINIMA_DO_BOTE := 30.0
## No preparo ele recua um pouco, para longe dela — a encolhida antes do salto.
const RECUO_NO_PREPARO := 34.0
## Enquanto um prepara ou mergulha, os outros esperam pelo menos isto.
const FOLGA_ENTRE_BOTES := 0.7
## O mergulho passa este tanto do ponto mirado: é o que leva quem errou até o
## chão.
const PASSAGEM_DO_MERGULHO := 80.0
## Para onde a arte do quadro "mergulho" aponta, virada para a direita: da
## ponta da asa (15, 12) à cabeça (28, 22). O Visual gira a diferença entre
## isto e o rumo de verdade do bote.
const RUMO_DA_ARTE_DO_MERGULHO := 0.656
## O quanto o Visual pode girar atrás do rumo, para os dois lados.
const GIRO_MAXIMO_DO_MERGULHO := 1.0
## A mordida: um ponto à frente do corpo e o raio dele. Pequeno de propósito —
## a hitbox de quem MACHUCA a jogadora é sempre a sovina.
const BOCA_A_FRENTE := 12.0
const RAIO_DA_MORDIDA := 8.0
## O corpo da Cacau, do jeito que a mordida o enxerga: a cápsula de colisão
## dela (raio 13, altura 72, com a origem no meio).
const RAIO_DO_CORPO := 13.0
const MEIO_CORPO := 23.0
## Empurrão que a mordida dá nela (multiplica o recuo do próprio player).
const RECUO_DA_MORDIDA := 0.7
const TEMPO_RECUPERANDO := 0.34
## Intervalo entre os fantasmas do rastro do mergulho, e quanto cada um dura.
const FANTASMA_INTERVALO := 0.04
const FANTASMA_VIDA := 0.2

# --- APANHANDO ---

## Depois de um acerto, o bumerangue não pega de novo por este tempo. Sem isto
## o mesmo passe poderia contar duas vezes (ele e o morcego andam para o mesmo
## lado). Curto o bastante para a VOLTA do mesmo arremesso ainda valer.
const IMUNIDADE := 0.15
## Quanto tempo o corpo fica branco depois do golpe (fora o congelamento).
const CLARAO := 0.07
## Velocidade com que ele é jogado para trás, do arremesso parado ao arremesso
## no teto da força.
const RECUO_MIN := 330.0
const RECUO_MAX := 620.0
## Tonto, ele perde velocidade assim (por segundo) e cai com esta gravidade: é
## um empurrão que morre em ~60 px, e um morcego que vai perdendo altura.
const FREIO_TONTO := 6.0
const GRAVIDADE_TONTO := 260.0
## Quanto dura a tontura de quem errou o bote e bateu no cenário.
const TEMPO_TONTO_DA_BATIDA := 0.75
const QUIQUE_DA_BATIDA := 130.0
## O congelamento do golpe FINAL. O bumerangue já congela 0,035 s em todo
## acerto; este pedido chega antes do dele e vale no lugar (ver _congelar).
const CONGELAMENTO_DA_MORTE := 0.085
const TREMOR_DA_MORTE := 6.0
const TREMOR_DA_BATIDA := 2.0

# --- O CORPO ---

## Velocidade com que o corpo sai, do arremesso parado ao mais forte, e o
## repuxo para cima que faz dele um arco em vez de uma reta.
const LANCE_MIN := 460.0
const LANCE_MAX := 820.0
const LANCE_PARA_CIMA := 190.0
const GIRO_DO_CORPO := 15.0
const GRAVIDADE_DO_CORPO := 1150.0
## O ar freia o corpo (por segundo). É o que faz o arremesso parado deixar o
## corpo cair uns 250 px adiante, ainda dentro da tela: a fumaça do fim é
## metade da graça, e fora do quadro ninguém vê.
const FREIO_DO_CORPO := 1.2
## Quanto da velocidade sobra em cada batida: contra a superfície e ao longo
## dela.
const QUIQUE_DO_CORPO := 0.42
const ATRITO_DO_CORPO := 0.55
## Abaixo disto, no chão, ele desiste de quicar.
const PARAR_ABAIXO_DE := 75.0
const QUIQUES_MAXIMOS := 3
## Batida mais fraca que isto não faz barulho nem levanta poeira.
const BATIDA_AUDIVEL := 90.0
## O corpo voando derruba outro morcego que estiver a esta distância, enquanto
## estiver mais rápido que isto.
const RAIO_DO_ATROPELO := 26.0
const VELOCIDADE_DO_ATROPELO := 220.0
## Deitado, espera isto, pisca e vira fumaça.
const TEMPO_DEITADO := 0.4
const PISCADAS := 3
const TEMPO_DA_PISCADA := 0.06
## Por mais que quique (ou caia num buraco), o corpo some depois disto.
const TEMPO_MAXIMO_DO_CORPO := 2.8
## Depois da fumaça o nó ainda vive isto, para o som dela não ser cortado.
const CAUDA_DO_SOM := 0.45

# --- A CARA DELE ---

## Força do contorno com ele dormindo: mal dá para ver — é para quem presta
## atenção notar o morcego no teto antes de ele acordar.
const CONTORNO_DORMINDO := 0.4
## O contorno do aviso do bote, e quantas vezes por segundo ele pisca do
## começo ao fim do preparo.
const COR_DE_AMEACA := Color(1.0, 0.25, 0.28)
const PISCA_AMEACA := Vector2(5.0, 13.0)
const COR_DO_RASTRO := Color(0.74, 0.3, 0.5)
## Quão depressa o Visual gira até a pose do estado (maior = mais seco).
const RAPIDEZ_DO_GIRO := 16.0
## Estrelinhas da tontura: quantas, a que altura (px do mundo, acima da
## origem), o tamanho da órbita (pixels de arte) e as voltas por segundo.
const ESTRELAS := 3
const ALTURA_DAS_ESTRELAS := -18.0
const ORBITA_DAS_ESTRELAS := Vector2(9, 3)
const VOLTAS_DAS_ESTRELAS := 1.1
const COR_DAS_ESTRELAS := Color(1.0, 0.9, 0.45)

## As cores dos estalos: o branco é o do quadro de golpe da própria folha; os
## fiapos são o lilás do contorno e um tom mais fundo dele.
const COR_DO_ESTALO := Color(0.925, 0.831, 0.816)
const COR_DO_FIAPO := Color(0.62, 0.54, 0.78)
const COR_DO_FIAPO_FUNDO := Color(0.36, 0.29, 0.47)
const COR_DA_FUMACA := Color(0.80, 0.77, 0.87)
const COR_DA_POEIRA := Color(0.66, 0.67, 0.72)

# --- VOLUMES (dB em cima do volume do nó Voz) ---

const VOLUME_GUINCHO := -9.0
const VOLUME_AMEACA := -7.0
const VOLUME_MERGULHO := -9.0
const VOLUME_ASA := -22.0
const VOLUME_GOLPE := -5.0
const VOLUME_MORTE := -4.0
const VOLUME_QUEDA := -10.0
const VOLUME_POF := -9.0
## Quantos sons do mesmo morcego cabem ao mesmo tempo.
const VOZES := 6

@export_group("Vida")
## Quantos acertos de bumerangue ele aguenta. Com 2 (o padrão), um arremesso
## que pega na ida e na volta mata; com 1, ele morre no primeiro toque.
@export_range(1, 9, 1) var vida: int = 2
## Ligado, ele continua morto depois de a fase recarregar (a Cacau morreu, ou
## saiu e voltou). Desligado (o padrão), todo morcego volta ao teto a cada
## visita — tem sempre um bando para matar no corredor.
@export var persistir: bool = false

@export_group("Ninho")
## Ligado (o padrão), ele dorme pendurado e só acorda com a Cacau por perto.
## Desligado, fica voando em volta do lugar em que foi posto.
@export var dorme_no_teto: bool = true:
	set(valor):
		dorme_no_teto = valor
		if is_node_ready():
			_pose_inicial()
## Até onde, para cima, ele procura um teto para se pendurar.
@export_range(0.0, 600.0, 8.0) var alcance_do_teto: float = 200.0

@export_group("Vigia")
## Distância em que ele nota a Cacau. Do teto do corredor até ela no chão já
## são uns 330 px: com 400, ele acorda quando ela está a ~230 px para o lado.
@export_range(0.0, 2000.0, 8.0) var raio_de_alerta: float = 400.0
## Além disto ele desiste dela e volta para o ninho.
@export_range(0.0, 3000.0, 8.0) var raio_de_desistencia: float = 760.0
## Quem acorda acorda os vizinhos que estiverem até esta distância.
@export_range(0.0, 1000.0, 8.0) var raio_do_bando: float = 260.0
## Camadas que tapam a visão dele. O projeto inteiro usa a camada 1, então
## parede de TileMap e caixa empurrável já escondem a Cacau.
@export_flags_2d_physics var mascara_visao: int = 1

@export_group("Voo")
## px/s atrás da Cacau. Ela corre a 350: dá para fugir dele, e é de propósito —
## quem não quer briga atravessa o corredor correndo.
@export_range(20.0, 600.0, 5.0) var velocidade_de_voo: float = 180.0
## Onde ele se posta em relação a ela: x para o lado, y para CIMA. Os dois
## iguais = na diagonal, que é onde o arremesso em 8 direções alcança.
@export var posto: Vector2 = Vector2(115, 115)

@export_group("Bote")
@export var dano: int = 1
## O aviso: quanto tempo ele fica parado, piscando, antes de mergulhar.
@export_range(0.1, 2.0, 0.05) var tempo_de_preparo: float = 0.5
@export_range(100.0, 1500.0, 10.0) var velocidade_do_mergulho: float = 540.0
## Distância máxima de um mergulho — e até onde ele precisa estar dela para
## começar um.
@export_range(60.0, 800.0, 10.0) var alcance_do_mergulho: float = 280.0
## Faixa (sorteada) de espera entre um bote e o próximo.
@export_range(0.2, 10.0, 0.1) var intervalo_min: float = 1.3
@export_range(0.2, 10.0, 0.1) var intervalo_max: float = 2.2
## O quanto ele mira ADIANTE de quem está correndo: 0 = onde ela está, 1 = onde
## ela vai estar quando ele chegar. Baixo de propósito: correr sempre escapa,
## ficar parada nunca.
@export_range(0.0, 1.0, 0.05) var antecipacao: float = 0.3

@export_group("Apanhando")
## Quanto tempo ele fica tonto depois de um acerto que não matou. Precisa
## cobrir a volta do bumerangue — até uns 0,9 s para quem foi acertado logo no
## começo do voo —, senão ele sacode a cabeça e sai da linha antes de o
## segundo golpe do mesmo arremesso chegar.
@export_range(0.1, 3.0, 0.05) var tempo_atordoado: float = 1.0

@export_group("Arte")
## O fio de luz em volta dele. É o que o recorta da parede escura.
@export var cor_do_contorno: Color = Color(0.62, 0.54, 0.78)
@export var cor_dos_olhos: Color = Color(1.0, 0.45, 0.5)

@export_group("Sons")
@export var som_guincho: AudioStream
@export var som_ameaca: AudioStream
@export var som_mergulho: AudioStream
@export var som_asa: AudioStream
@export var som_golpe: AudioStream
@export var som_morte: AudioStream
@export var som_queda: AudioStream
@export var som_pof: AudioStream

var estado: Estado = Estado.DORMINDO

var _vida: int = 2
var _player: CharacterBody2D = null
## Onde ele dorme (ou em volta de onde paira), em coordenadas do mundo.
var _ninho: Vector2 = Vector2.ZERO
var _ninho_pronto: bool = false
var _tentativas_de_teto: int = 0

var _tempo_no_estado: float = 0.0
## Tempo de vida, e uma fase sorteada: cada morcego balança no seu compasso.
var _relogio: float = 0.0
var _compasso: float = 0.0
var _lado: float = 1.0
var _longe_ha: float = 0.0
## Acordar marcado para daqui a pouco (o bando em fila). Negativo = nada marcado.
var _despertar_em: float = -1.0
var _soltou_do_teto: bool = false

var _espera_do_bote: float = 0.0
var _rumo_do_mergulho: Vector2 = Vector2.DOWN
var _mergulho_restante: float = 0.0
var _fantasma: float = 0.0

var _atordoado_restante: float = 0.0
var _imune: float = 0.0
var _clarao_restante: float = 0.0

var _giro_do_corpo: float = 0.0
var _quiques: int = 0
var _deitado: bool = false
## Morcegos que este corpo já derrubou no caminho (cada um só uma vez).
var _atropelados: Array[Node] = []

# O Visual: para onde ele quer girar, o quanto treme e o quanto está esticado.
var _giro_alvo: float = 0.0
var _tremor: float = 0.0
var _esticada: Vector2 = Vector2.ONE
var _tween_esticada: Tween = null
var _escala_base: Vector2 = Vector2(2, 2)
var _material: ShaderMaterial = null
var _material_do_rastro: ShaderMaterial = null
var _estrelas: Tonteira = null
var _vozes: AudioStreamPlaybackPolyphonic = null

@onready var _visual: AnimatedSprite2D = get_node_or_null("Visual")
@onready var _hitbox: Area2D = get_node_or_null("AreaAlvo")
@onready var _voz: AudioStreamPlayer2D = get_node_or_null("Voz")


static func criar(pai: Node, nome: String, pos: Vector2, config: Dictionary = {}) -> Morcego:
	var morcego: Morcego = load(CENA).instantiate()
	morcego.name = nome
	morcego.position = pos
	for chave in config:
		morcego.set(chave, config[chave])
	Blockout.adicionar(pai, morcego)
	return morcego


func _ready() -> void:
	_pose_inicial()
	if Engine.is_editor_hint():
		return

	# Já tinha sido morto numa visita anterior (ver "persistir").
	if persistir and EstadoMundo.ja_feito(self):
		queue_free()
		return

	add_to_group(GRUPO)
	_vida = vida
	_ninho = global_position
	_compasso = randf() * TAU
	estado = Estado.DORMINDO if dorme_no_teto else Estado.PAIRANDO

	_preparar_material()
	_preparar_voz()
	_estrelas = Tonteira.new()
	_estrelas.name = "Tonteira"
	_estrelas.position = Vector2(0, ALTURA_DAS_ESTRELAS)
	_estrelas.visible = false
	add_child(_estrelas)

	if _visual:
		_escala_base = _visual.scale
		# Cada um bate as asas num ritmo um tico diferente: no mesmo ritmo, o
		# bando inteiro abre e fecha as asas junto e parece um morcego só.
		_visual.speed_scale = randf_range(RITMO_DAS_ASAS.x, RITMO_DAS_ASAS.y)
		_visual.frame_changed.connect(_ao_trocar_quadro)
		if not dorme_no_teto:
			_visual.play(ANIM_VOANDO)
	if _hitbox and _hitbox.has_signal("atingida_com_rumo"):
		_hitbox.atingida_com_rumo.connect(levar_golpe)


## A pose de quem ainda não fez nada: pendurado ou de asa aberta. Roda também
## no editor, para o morcego já aparecer do jeito que vai estar no jogo.
func _pose_inicial() -> void:
	var visual: AnimatedSprite2D = get_node_or_null("Visual")
	var hitbox: Node2D = get_node_or_null("AreaAlvo")
	if hitbox:
		hitbox.position = ALVO_PENDURADO if dorme_no_teto else Vector2.ZERO
	if visual == null or visual.sprite_frames == null:
		return
	var anim: StringName = ANIM_DORMINDO if dorme_no_teto else ANIM_VOANDO
	if not visual.sprite_frames.has_animation(anim):
		return
	visual.stop()
	visual.animation = anim
	visual.frame = 0
	visual.rotation = PI if dorme_no_teto else 0.0
	_giro_alvo = visual.rotation


# --- O QUADRO DE FÍSICA ---

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_achar_player()

	# O corpo não espera ninguém: ele não ameaça mais nada, só termina de cair.
	if estado == Estado.MORTO:
		_cair_morto(delta)
		return

	if not _ninho_pronto:
		_achar_ninho()

	# Tela de puzzle/diálogo aberta: a caçada espera junto — não é justo
	# apanhar enquanto a jogadora lê.
	if Interacao.ocupada():
		return

	_relogio += delta
	_tempo_no_estado += delta
	_espera_do_bote = maxf(_espera_do_bote - delta, 0.0)
	_escoar_imunidade(delta)

	match estado:
		Estado.DORMINDO:
			_dormir(delta)
		Estado.ACORDANDO:
			_acordando(delta)
		Estado.PAIRANDO:
			_pairar(delta)
		Estado.VOANDO:
			_perseguir(delta)
		Estado.PREPARANDO:
			_preparando(delta)
		Estado.MERGULHANDO:
			_mergulhando(delta)
		Estado.RECUPERANDO:
			_recuperando(delta)
		Estado.ATORDOADO:
			_atordoado(delta)
		Estado.VOLTANDO:
			_voltando(delta)


func _trocar_estado(novo: Estado) -> void:
	estado = novo
	_tempo_no_estado = 0.0
	if _estrelas:
		_estrelas.visible = novo == Estado.ATORDOADO
	if _hitbox:
		_hitbox.position = ALVO_PENDURADO if novo == Estado.DORMINDO else Vector2.ZERO


func _achar_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _player == null:
		return
	# A camada 0 já garante que a Cacau não esbarra nele; o inverso é isto aqui
	# (o chão e ela moram na mesma camada 1 — ver sentinela.gd): sem a exceção
	# o corpo dela empurraria o morcego, e o corpo dele quicaria nela.
	add_collision_exception_with(_player)


## A Cacau está aí e está viva?
func _player_vale() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	return not ("current_health" in _player) or _player.current_health > 0


## A Cacau está dentro de `raio` e sem nada tapando a vista?
func _ve_o_player(raio: float) -> bool:
	if not _player_vale():
		return false
	var ate: Vector2 = _player.global_position - global_position
	if ate.length() > raio:
		return false
	return _caminho_livre(_player.global_position)


func _caminho_livre(ate: Vector2) -> bool:
	var consulta := PhysicsRayQueryParameters2D.create(global_position, ate, mascara_visao)
	var ignorar: Array[RID] = [get_rid()]
	if _player != null and is_instance_valid(_player):
		ignorar.append(_player.get_rid())
	consulta.exclude = ignorar
	return get_world_2d().direct_space_state.intersect_ray(consulta).is_empty()


# --- NINHO ---

## Procura o teto em cima de onde ele foi posto e se pendura nele. Sem teto com
## colisão por perto, o ninho é o próprio lugar em que ele está.
func _achar_ninho() -> void:
	_tentativas_de_teto += 1
	_ninho_pronto = _tentativas_de_teto >= TENTATIVAS_DE_TETO
	if not dorme_no_teto or alcance_do_teto <= 0.0:
		_ninho_pronto = true
		return

	var de := _ninho + Vector2(0, FOLGA_DO_RAIO_DO_TETO)
	var consulta := PhysicsRayQueryParameters2D.create(de,
		_ninho - Vector2(0, alcance_do_teto), mascara_visao)
	var ignorar: Array[RID] = [get_rid()]
	if _player != null and is_instance_valid(_player):
		ignorar.append(_player.get_rid())
	consulta.exclude = ignorar
	var teto := get_world_2d().direct_space_state.intersect_ray(consulta)
	if teto.is_empty():
		return

	_ninho_pronto = true
	_ninho = (teto["position"] as Vector2) + Vector2(0, PENDURADO_ABAIXO_DO_TETO)
	# Só se ainda estiver quieto: quem já acordou no primeiro quadro não é
	# puxado de volta para o teto.
	if estado == Estado.DORMINDO:
		global_position = _ninho


# --- DORMINDO, ACORDANDO E PAIRANDO ---

func _dormir(delta: float) -> void:
	velocity = Vector2.ZERO
	if _despertar_em >= 0.0:
		_despertar_em -= delta
		if _despertar_em <= 0.0:
			_acordar()
		return
	if _ve_o_player(raio_de_alerta):
		_acordar()


## Acorda este morcego — na hora, ou daqui a `atraso` segundos (é assim que o
## bando acorda em fila). Quem já está acordado não faz nada.
func despertar(atraso: float = 0.0) -> void:
	match estado:
		Estado.DORMINDO:
			if atraso <= 0.0:
				_acordar()
			elif _despertar_em < 0.0:
				_despertar_em = atraso
		Estado.PAIRANDO:
			_notar_a_cacau()
		Estado.VOLTANDO:
			_partir_para_cima()


func _acordar() -> void:
	_despertar_em = -1.0
	_soltou_do_teto = false
	_espera_do_bote = maxf(_espera_do_bote, ESPERA_DO_PRIMEIRO_BOTE)
	_trocar_estado(Estado.ACORDANDO)
	_tremor = 3.0
	_tocar(som_guincho, VOLUME_GUINCHO)
	_alertar_o_bando()
	acordou.emit()


func _acordando(delta: float) -> void:
	if not _soltou_do_teto:
		velocity = Vector2.ZERO
		if _tempo_no_estado < TEMPO_DE_SOLTAR:
			return
		# Solta: cai um palmo enquanto vira de cabeça para cima e abre as asas.
		_soltou_do_teto = true
		_giro_alvo = 0.0
		velocity = Vector2(0, QUEDA_AO_SOLTAR)
		_tocar_animacao(ANIM_VOANDO)
		_esticar(Vector2(0.8, 1.25))

	velocity = velocity.move_toward(Vector2.ZERO, ACELERACAO * 0.5 * delta)
	move_and_slide()
	if _tempo_no_estado >= TEMPO_ACORDAR:
		_trocar_estado(Estado.VOANDO)


## Quem não dorme no teto fica em volta do ninho até a Cacau aparecer.
func _pairar(delta: float) -> void:
	_voar_para(_ninho + _onda(), velocidade_de_voo * 0.5, delta)
	if _ve_o_player(raio_de_alerta):
		_notar_a_cacau()
		_alertar_o_bando()


## O "acordar" de quem já estava voando: guincha e parte para cima dela.
func _notar_a_cacau() -> void:
	_espera_do_bote = maxf(_espera_do_bote, ESPERA_DO_PRIMEIRO_BOTE)
	_tocar(som_guincho, VOLUME_GUINCHO)
	_partir_para_cima()
	acordou.emit()


## Sai de onde estiver (pairando ou voltando ao ninho) direto para a caçada.
func _partir_para_cima() -> void:
	_longe_ha = 0.0
	_trocar_estado(Estado.VOANDO)
	_tocar_animacao(ANIM_VOANDO)
	_giro_alvo = 0.0


func _alertar_o_bando() -> void:
	for outro in get_tree().get_nodes_in_group(GRUPO):
		if outro == self or not (outro is Morcego):
			continue
		if (outro as Morcego).global_position.distance_to(global_position) <= raio_do_bando:
			(outro as Morcego).despertar(randf_range(ATRASO_DO_BANDO.x, ATRASO_DO_BANDO.y))


# --- VOO ---

## Atrás da Cacau: até o posto na diagonal dela, e de lá decide o bote.
func _perseguir(delta: float) -> void:
	if not _player_vale():
		_voltar_ao_ninho()
		return

	if global_position.distance_to(_player.global_position) > raio_de_desistencia:
		_longe_ha += delta
		if _longe_ha >= TEMPO_PARA_DESISTIR:
			_voltar_ao_ninho()
			return
	else:
		_longe_ha = 0.0

	_voar_para(_posto_de_voo(), velocidade_de_voo, delta)
	_olhar_para(_player.global_position.x)
	if _pode_dar_o_bote():
		_preparar()


## O ponto em que ele quer ficar: ao lado e acima dela, do lado em que já
## está, balançando em volta.
##
## Vários do mesmo lado fazem FILA na mesma diagonal, um atrás do outro (cada
## um "FILA_NA_DIAGONAL" mais longe que o da frente), em vez de se espalhar. É
## de propósito: o bumerangue atravessa alvos, então um arremesso bem mirado
## na diagonal pega a fila inteira — na ida e na volta.
func _posto_de_voo() -> Vector2:
	var dx: float = global_position.x - _player.global_position.x
	if absf(dx) > FOLGA_DE_LADO:
		_lado = signf(dx)

	# Quem vem antes na árvore de cena fica na frente: a ordem é estável, e
	# quando o da frente morre os de trás avançam um lugar.
	var lugar := 0
	for outro in get_tree().get_nodes_in_group(GRUPO):
		if outro == self:
			break
		var vizinho := outro as Morcego
		if vizinho != null and vizinho.esta_na_cacada() and vizinho._lado == _lado:
			lugar += 1

	var afastamento: float = 1.0 + lugar * FILA_NA_DIAGONAL
	return _player.global_position + Vector2(_lado * posto.x, -posto.y) * afastamento + _onda()


func _onda() -> Vector2:
	return Vector2(cos(_relogio * ONDA_RITMO.x + _compasso) * ONDA.x,
		sin(_relogio * ONDA_RITMO.y + _compasso) * ONDA.y)


## Um passo de voo até `alvo`: acelera para lá, freia ao chegar e não empilha
## nos outros do bando.
func _voar_para(alvo: Vector2, velocidade: float, delta: float) -> void:
	var ate: Vector2 = alvo - global_position
	var distancia: float = ate.length()
	var desejada := Vector2.ZERO
	if distancia > 0.5:
		desejada = ate / distancia * velocidade * minf(distancia / DISTANCIA_DE_CHEGADA, 1.0)
	desejada += _empurrao_do_bando()
	velocity = velocity.move_toward(desejada, ACELERACAO * delta)
	move_and_slide()


func _empurrao_do_bando() -> Vector2:
	var empurrao := Vector2.ZERO
	for outro in get_tree().get_nodes_in_group(GRUPO):
		var vizinho := outro as Morcego
		if vizinho == null or vizinho == self or not vizinho.esta_no_ar():
			continue
		var de_la: Vector2 = global_position - vizinho.global_position
		var distancia: float = de_la.length()
		if distancia >= DISTANCIA_DO_BANDO:
			continue
		if distancia < 0.5:
			# Um em cima do outro: cada um escapa para um lado, pelo compasso.
			de_la = Vector2.RIGHT.rotated(_compasso)
			distancia = 1.0
		empurrao += de_la / distancia * (1.0 - distancia / DISTANCIA_DO_BANDO) * EMPURRAO_DO_BANDO
	return empurrao


func _olhar_para(x: float) -> void:
	if _visual and absf(x - global_position.x) > 2.0:
		_visual.flip_h = x < global_position.x


func _voltar_ao_ninho() -> void:
	_trocar_estado(Estado.VOLTANDO)
	_tocar_animacao(ANIM_VOANDO)
	_giro_alvo = 0.0


func _voltando(delta: float) -> void:
	# Ela voltou para perto antes de ele chegar em casa: a caçada recomeça.
	if _ve_o_player(raio_de_alerta):
		_partir_para_cima()
		return

	_voar_para(_ninho, velocidade_de_voo * 0.8, delta)
	_olhar_para(_ninho.x)
	if global_position.distance_to(_ninho) > CHEGOU_NO_NINHO:
		return
	if not dorme_no_teto:
		_trocar_estado(Estado.PAIRANDO)
		return
	# Pendura de novo: encosta no ninho, vira de cabeça para baixo e fecha as asas.
	global_position = _ninho
	velocity = Vector2.ZERO
	_trocar_estado(Estado.DORMINDO)
	_tocar_animacao(ANIM_DORMINDO)
	_giro_alvo = PI


## Voando (e não pendurado, tonto ou morto): é quem conta para o bando não
## empilhar.
func esta_no_ar() -> bool:
	return estado in [Estado.PAIRANDO, Estado.VOANDO, Estado.PREPARANDO, Estado.VOLTANDO,
		Estado.RECUPERANDO]


## Atrás da Cacau agora (voando até o posto, armando o bote ou voltando dele):
## é quem ocupa lugar na fila da diagonal.
func esta_na_cacada() -> bool:
	return estado in [Estado.VOANDO, Estado.PREPARANDO, Estado.MERGULHANDO, Estado.RECUPERANDO]


# --- BOTE ---

## Preparando ou mergulhando: é a vez dele, e os outros esperam.
func esta_no_bote() -> bool:
	return estado == Estado.PREPARANDO or estado == Estado.MERGULHANDO


func _pode_dar_o_bote() -> bool:
	if _espera_do_bote > 0.0 or _tempo_no_estado < TEMPO_MINIMO_VOANDO:
		return false
	# Quem está sem o controle (cutscene, chegada andando, recuo de outro dano)
	# não vira alvo: o bote só começa contra quem pode desviar dele.
	if "pode_se_mover" in _player and not _player.pode_se_mover:
		return false
	var ate: Vector2 = _player.global_position - global_position
	if ate.length() > alcance_do_mergulho or ate.y < ALTURA_MINIMA_DO_BOTE:
		return false
	if not _caminho_livre(_player.global_position):
		return false
	for outro in get_tree().get_nodes_in_group(GRUPO):
		if outro != self and outro is Morcego and (outro as Morcego).esta_no_bote():
			return false
	return true


func _preparar() -> void:
	_trocar_estado(Estado.PREPARANDO)
	_tocar_animacao(ANIM_PREPARANDO)
	_tocar(som_ameaca, VOLUME_AMEACA)
	# A vez é dele: os outros esperam um pouco mais, mesmo que este bote acabe
	# cedo (é o que impede o segundo de mergulhar em cima do primeiro).
	for outro in get_tree().get_nodes_in_group(GRUPO):
		if outro != self and outro is Morcego:
			(outro as Morcego)._espera_do_bote = maxf((outro as Morcego)._espera_do_bote,
				tempo_de_preparo + FOLGA_ENTRE_BOTES)


func _preparando(delta: float) -> void:
	if not _player_vale():
		_partir_para_cima()
		return
	# A encolhida antes do salto: freia e recua um pouco, para longe dela.
	var para_longe: Vector2 = (global_position - _player.global_position).normalized()
	velocity = velocity.move_toward(para_longe * RECUO_NO_PREPARO, ACELERACAO * delta)
	move_and_slide()
	_olhar_para(_player.global_position.x)
	# No finalzinho ele treme de tão armado.
	if _tempo_no_estado > tempo_de_preparo * 0.6:
		_tremor = maxf(_tremor, 1.6)
	if _tempo_no_estado >= tempo_de_preparo:
		_mergulhar()


## Trava o rumo AGORA e solta. Daqui em diante ele não corrige mais a mira —
## é por isso que sair de baixo funciona.
func _mergulhar() -> void:
	var alvo: Vector2 = _player.global_position
	var distancia: float = global_position.distance_to(alvo)
	# Um tico adiante de quem está correndo (ver "antecipacao").
	alvo += _player.velocity * (distancia / maxf(velocidade_do_mergulho, 1.0)) * antecipacao
	var ate: Vector2 = alvo - global_position
	_rumo_do_mergulho = ate.normalized() if ate.length_squared() > 1.0 else Vector2.DOWN
	_mergulho_restante = minf(ate.length() + PASSAGEM_DO_MERGULHO, alcance_do_mergulho + PASSAGEM_DO_MERGULHO)
	_fantasma = 0.0

	_trocar_estado(Estado.MERGULHANDO)
	_tocar_animacao(ANIM_MERGULHO)
	_tocar(som_mergulho, VOLUME_MERGULHO)
	_apontar_o_visual(_rumo_do_mergulho)
	_esticar(Vector2(1.25, 0.8))
	_espera_do_bote = randf_range(intervalo_min, maxf(intervalo_min, intervalo_max))


## Gira (e espelha) o Visual para o quadro do mergulho apontar no rumo do bote.
func _apontar_o_visual(rumo: Vector2) -> void:
	if _visual == null:
		return
	_visual.flip_h = rumo.x < 0.0
	var arte: float = PI - RUMO_DA_ARTE_DO_MERGULHO if _visual.flip_h else RUMO_DA_ARTE_DO_MERGULHO
	_giro_alvo = clampf(angle_difference(arte, rumo.angle()),
		-GIRO_MAXIMO_DO_MERGULHO, GIRO_MAXIMO_DO_MERGULHO)
	# Seco: o bote não tem tempo de girar aos poucos.
	_visual.rotation = _giro_alvo


func _mergulhando(delta: float) -> void:
	var passo: float = velocidade_do_mergulho * delta
	velocity = _rumo_do_mergulho * velocidade_do_mergulho
	var batida := move_and_collide(_rumo_do_mergulho * passo)
	_mergulho_restante -= passo

	_fantasma -= delta
	if _fantasma <= 0.0:
		_fantasma = FANTASMA_INTERVALO
		_soltar_fantasma()

	if _morder():
		_recuperar(true)
	elif batida:
		_bater_no_cenario(batida)
	elif _mergulho_restante <= 0.0:
		_recuperar(false)


## A mordida: a boca encostou no corpo da Cacau? Devolve true se o golpe entrou.
func _morder() -> bool:
	if not _player_vale():
		return false
	if "pode_se_mover" in _player and not _player.pode_se_mover:
		return false
	var boca: Vector2 = global_position + _rumo_do_mergulho * BOCA_A_FRENTE
	var meio: Vector2 = _player.global_position
	var perto := Geometry2D.get_closest_point_to_segment(boca,
		meio - Vector2(0, MEIO_CORPO), meio + Vector2(0, MEIO_CORPO))
	if boca.distance_to(perto) > RAIO_DO_CORPO + RAIO_DA_MORDIDA:
		return false
	# Invencível (acabou de apanhar, ou está no dash da mochila): o bote passa
	# por dentro dela e segue — atravessar o mergulho no dash é desvio válido.
	if ("esta_invencivel" in _player and _player.esta_invencivel) \
			or ("esta_invencivel_dash" in _player and _player.esta_invencivel_dash):
		return false
	if not _player.has_method("take_damage"):
		return false

	var lado: float = signf(_rumo_do_mergulho.x)
	if is_zero_approx(lado):
		lado = signf(_player.global_position.x - global_position.x)
	_player.take_damage(dano, Vector2((lado if lado != 0.0 else 1.0) * RECUO_DA_MORDIDA, 0))
	return true


## O respiro depois do bote: quem mordeu quica para trás e para cima; quem só
## passou segue no embalo, já arredondando para subir.
func _recuperar(mordeu: bool) -> void:
	_trocar_estado(Estado.RECUPERANDO)
	_tocar_animacao(ANIM_RECUPERANDO)
	_giro_alvo = 0.0
	if mordeu:
		velocity = Vector2(-_rumo_do_mergulho.x * 150.0, -210.0)
		_esticar(Vector2(0.8, 1.2))
	else:
		velocity = _rumo_do_mergulho * velocidade_do_mergulho * 0.4


func _recuperando(delta: float) -> void:
	velocity = velocity.move_toward(Vector2(0, -velocidade_de_voo * 0.6), ACELERACAO * 1.6 * delta)
	move_and_slide()
	if _tempo_no_estado >= TEMPO_RECUPERANDO:
		_trocar_estado(Estado.VOANDO)
		_tocar_animacao(ANIM_VOANDO)


## Errou e deu de cara no cenário: fica tonto ali mesmo, à mercê do bumerangue.
func _bater_no_cenario(batida: KinematicCollision2D) -> void:
	var normal: Vector2 = batida.get_normal()
	_tocar(som_queda, VOLUME_QUEDA + 4.0)
	_poeira(batida.get_position(), normal, 6)
	_tremer_a_camera(TREMOR_DA_BATIDA)
	_esticar(Vector2(1.3, 0.7))
	_atordoar(TEMPO_TONTO_DA_BATIDA, normal * QUIQUE_DA_BATIDA)


# --- APANHANDO ---

## Um golpe nele. `rumo` é para onde o golpe ia (é para lá que ele voa) e
## `forca` vai de 0 a 1 — as duas coisas vêm do bumerangue (ver
## HitboxBumerangue.atingida_com_rumo). Sem rumo, ele é jogado para longe da
## Cacau. É público de propósito: qualquer coisa que um dia bata num morcego
## chama isto.
func levar_golpe(rumo: Vector2 = Vector2.ZERO, forca: float = 0.0, dano_do_golpe: int = 1) -> void:
	if Engine.is_editor_hint() or estado == Estado.MORTO or _imune > 0.0:
		return

	if rumo.length_squared() < 0.0001:
		rumo = Vector2.UP
		if _player_vale() and global_position.distance_squared_to(_player.global_position) > 1.0:
			rumo = (global_position - _player.global_position).normalized()
	else:
		rumo = rumo.normalized()
	forca = clampf(forca, 0.0, 1.0)

	var estava_quieto: bool = estado == Estado.DORMINDO or estado == Estado.PAIRANDO
	_vida -= maxi(dano_do_golpe, 1)
	_clarao_restante = CLARAO
	_fechar_o_alvo(IMUNIDADE)
	_estalo_do_golpe(rumo, _vida <= 0)

	if _vida <= 0:
		_morrer(rumo, forca)
		return

	_tocar(som_golpe, VOLUME_GOLPE)
	_esticar(Vector2(0.7, 1.35))
	_atordoar(tempo_atordoado, rumo * lerpf(RECUO_MIN, RECUO_MAX, forca))
	if estava_quieto:
		# Apanhou dormindo: o bando acorda com o barulho.
		_alertar_o_bando()
		acordou.emit()
	levou_golpe.emit(_vida)


## Tonto por `duracao` segundos, saindo com o `impulso`. É o estado de quem
## apanhou e de quem errou o bote: qualquer coisa que ele estivesse fazendo
## (inclusive um bote já armado) acaba aqui.
func _atordoar(duracao: float, impulso: Vector2) -> void:
	_atordoado_restante = duracao
	velocity = impulso
	_despertar_em = -1.0
	_giro_alvo = 0.0
	_trocar_estado(Estado.ATORDOADO)
	_tocar_animacao(ANIM_GOLPE)
	# Quem acabou de apanhar não dá o bote logo que sacode a cabeça.
	_espera_do_bote = maxf(_espera_do_bote, duracao + intervalo_min * 0.5)


func _atordoado(delta: float) -> void:
	velocity.y += GRAVIDADE_TONTO * delta
	velocity *= exp(-FREIO_TONTO * delta)
	var batida := move_and_collide(velocity * delta)
	if batida:
		velocity = velocity.bounce(batida.get_normal()) * 0.35

	_atordoado_restante -= delta
	if _atordoado_restante > 0.0:
		return
	# Sacode a cabeça e volta para a briga (ou para casa, se ela sumiu).
	_esticar(Vector2(1.2, 0.85))
	if _player_vale():
		_partir_para_cima()
	else:
		_voltar_ao_ninho()


## Tira o AreaAlvo da vista do bumerangue por `tempo` segundos. É fora do GRUPO
## (e não só ignorando o acerto) para o bumerangue passar batido de verdade:
## dentro do grupo ele ainda travaria o jogo e tremeria a câmera num golpe que
## não valeu.
func _fechar_o_alvo(tempo: float) -> void:
	_imune = tempo
	if _hitbox and _hitbox.is_in_group(GRUPO_ALVO):
		_hitbox.remove_from_group(GRUPO_ALVO)


func _escoar_imunidade(delta: float) -> void:
	if _imune <= 0.0:
		return
	_imune = maxf(_imune - delta, 0.0)
	if _imune <= 0.0 and _hitbox and estado != Estado.MORTO:
		_hitbox.add_to_group(GRUPO_ALVO)


func vida_restante() -> int:
	return _vida


# --- MORTE ---

func _morrer(rumo: Vector2, forca: float) -> void:
	_vida = 0
	_trocar_estado(Estado.MORTO)
	if persistir:
		EstadoMundo.marcar_feito(self)

	# O corpo sai no rumo do bumerangue, com um repuxo para cima: é o arco que
	# faz dele uma coisa arremessada, e não uma coisa que parou de voar.
	velocity = rumo * lerpf(LANCE_MIN, LANCE_MAX, forca) + Vector2(0, -LANCE_PARA_CIMA)
	_giro_do_corpo = GIRO_DO_CORPO * (signf(rumo.x) if absf(rumo.x) > 0.05 else 1.0)
	_despertar_em = -1.0
	_tocar_animacao(ANIM_MORRENDO)
	_tocar(som_morte, VOLUME_MORTE)
	_esticar(Vector2(0.65, 1.4))
	_congelar(CONGELAMENTO_DA_MORTE)
	_tremer_a_camera(TREMOR_DA_MORTE)
	morreu.emit()


func _cair_morto(delta: float) -> void:
	_tempo_no_estado += delta
	if _deitado:
		return
	if _tempo_no_estado >= TEMPO_MAXIMO_DO_CORPO:
		_virar_fumaca()
		return

	velocity *= exp(-FREIO_DO_CORPO * delta)
	velocity.y += GRAVIDADE_DO_CORPO * delta
	var batida := move_and_collide(velocity * delta)
	if _visual:
		_visual.rotation += _giro_do_corpo * delta
	_atropelar_o_bando()
	if batida == null:
		return

	# Quica com perda: o que vinha CONTRA a superfície volta reduzido, e o que
	# deslizava por ela sofre o atrito.
	var normal: Vector2 = batida.get_normal()
	var pancada: float = -velocity.dot(normal)
	var contra: Vector2 = normal * velocity.dot(normal)
	velocity = (velocity - contra) * ATRITO_DO_CORPO - contra * QUIQUE_DO_CORPO
	_giro_do_corpo *= 0.5
	_quiques += 1
	if pancada > BATIDA_AUDIVEL:
		_tocar(som_queda, VOLUME_QUEDA + clampf(pancada / 400.0, 0.0, 1.0) * 6.0)
		_poeira(batida.get_position(), normal, 4)

	var no_chao: bool = normal.y < -0.6
	if no_chao and (velocity.length() < PARAR_ABAIXO_DE or _quiques >= QUIQUES_MAXIMOS):
		_deitar()


## O corpo voando derruba quem estiver na frente: cada morcego do caminho leva
## um golpe, no rumo em que o corpo vinha.
func _atropelar_o_bando() -> void:
	if velocity.length() < VELOCIDADE_DO_ATROPELO:
		return
	for outro in get_tree().get_nodes_in_group(GRUPO):
		var vizinho := outro as Morcego
		if vizinho == null or vizinho == self or vizinho.estado == Estado.MORTO \
				or _atropelados.has(vizinho):
			continue
		if vizinho.global_position.distance_to(global_position) > RAIO_DO_ATROPELO:
			continue
		_atropelados.append(vizinho)
		vizinho.levar_golpe(velocity.normalized(), 0.3)


## Parou de quicar: fica deitado um instante, pisca e vira fumaça.
func _deitar() -> void:
	_deitado = true
	velocity = Vector2.ZERO
	if _visual:
		_visual.pause()
		_visual.rotation = 0.0
	var fim := create_tween()
	fim.tween_interval(TEMPO_DEITADO)
	for i in PISCADAS:
		fim.tween_callback(_mostrar_o_corpo.bind(false))
		fim.tween_interval(TEMPO_DA_PISCADA)
		fim.tween_callback(_mostrar_o_corpo.bind(true))
		fim.tween_interval(TEMPO_DA_PISCADA)
	fim.tween_callback(_virar_fumaca)


func _mostrar_o_corpo(visivel: bool) -> void:
	if _visual:
		_visual.visible = visivel


func _virar_fumaca() -> void:
	_deitado = true
	velocity = Vector2.ZERO
	_mostrar_o_corpo(false)
	_tocar(som_pof, VOLUME_POF)
	var cena := _cena_dos_efeitos()
	if cena:
		# O tufo do meio vem primeiro: sem ele o anel dos outros seis deixa um
		# furo no centro da nuvem.
		EstalosPixel.criar(cena, global_position, z_index + 1) \
			.tufos(1, Vector2(3.5, 4.0), 0.0, Vector2(0.32, 0.4), COR_DA_FUMACA) \
			.tufos(6, Vector2(2.0, 4.0), 5.0, Vector2(0.28, 0.42), COR_DA_FUMACA) \
			.estrela(Vector2(0, -1), 2, 0.2, COR_DO_ESTALO, 0.04) \
			.faiscas(4, Vector2.UP, 150.0, Vector2(20, 45), Vector2(0.25, 0.4),
				[COR_DO_FIAPO, COR_DO_FIAPO_FUNDO], 60.0, 1, 2.5)
	# O nó ainda vive o tempo do som escoar: matá-lo agora cortaria a fumaça no
	# meio.
	var saida := create_tween()
	saida.tween_interval(CAUDA_DO_SOM)
	saida.tween_callback(queue_free)


# --- O QUE SE VÊ ---

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _visual == null:
		return

	_clarao_restante = maxf(_clarao_restante - delta, 0.0)
	_pintar()

	# O tremor anda de pixel em pixel da arte: tremido liso borraria o desenho.
	var passo: float = _escala_base.x
	_visual.position = Vector2(randf_range(-_tremor, _tremor),
		randf_range(-_tremor, _tremor)).snappedf(passo) if _tremor > 0.05 else Vector2.ZERO
	_tremor = move_toward(_tremor, 0.0, 12.0 * delta)
	_visual.scale = _escala_base * _esticada

	# O corpo morto gira por conta própria (ver _cair_morto).
	if estado == Estado.MORTO:
		return
	var giro: float = _giro_alvo
	if estado == Estado.DORMINDO:
		giro += sin(_relogio * 1.3 + _compasso) * BALANCO_DORMINDO
	_visual.rotation = lerp_angle(_visual.rotation, giro, 1.0 - exp(-RAPIDEZ_DO_GIRO * delta))


## Contorno, olhos e clarão: o estado dele, dito pelo shader.
func _pintar() -> void:
	if _material == null:
		return
	var contorno := 1.0
	var olhos := 1.0
	var cor := cor_do_contorno
	match estado:
		Estado.DORMINDO:
			contorno = CONTORNO_DORMINDO
			olhos = 0.0
		Estado.ACORDANDO:
			contorno = lerpf(CONTORNO_DORMINDO, 1.0, clampf(_tempo_no_estado / TEMPO_DE_SOLTAR, 0.0, 1.0))
		Estado.PREPARANDO:
			# Pisca seco, ligado ou desligado, e cada vez mais depressa: é o
			# relógio do bote, lido de relance.
			var k: float = clampf(_tempo_no_estado / maxf(tempo_de_preparo, 0.01), 0.0, 1.0)
			var piscadas: float = _tempo_no_estado * lerpf(PISCA_AMEACA.x, PISCA_AMEACA.y, k)
			if fmod(piscadas, 1.0) < 0.5:
				cor = COR_DE_AMEACA
		Estado.MERGULHANDO:
			cor = COR_DE_AMEACA
		Estado.ATORDOADO, Estado.MORTO:
			olhos = 0.0
	_material.set_shader_parameter(&"contorno", contorno)
	_material.set_shader_parameter(&"olhos", olhos)
	_material.set_shader_parameter(&"cor_contorno", cor)
	_material.set_shader_parameter(&"clarao", 1.0 if _clarao_restante > 0.0 else 0.0)


## Cada morcego precisa do PRÓPRIO material: com um só, o bando inteiro
## piscaria junto quando um deles fosse dar o bote.
func _preparar_material() -> void:
	if _visual == null or not (_visual.material is ShaderMaterial):
		return
	_material = (_visual.material as ShaderMaterial).duplicate() as ShaderMaterial
	_visual.material = _material
	_material.set_shader_parameter(&"cor_dos_olhos", cor_dos_olhos)
	_material.set_shader_parameter(&"cor_clarao", COR_DO_ESTALO)

	# O do rastro: a mesma silhueta, chapada numa cor só e sem contorno.
	_material_do_rastro = _material.duplicate() as ShaderMaterial
	_material_do_rastro.set_shader_parameter(&"cor_clarao", COR_DO_RASTRO)
	_material_do_rastro.set_shader_parameter(&"clarao", 1.0)
	_material_do_rastro.set_shader_parameter(&"contorno", 0.0)
	_material_do_rastro.set_shader_parameter(&"olhos", 0.0)


func _tocar_animacao(nome: StringName) -> void:
	if _visual == null or _visual.sprite_frames == null \
			or not _visual.sprite_frames.has_animation(nome):
		return
	_visual.play(nome)
	_visual.frame = 0


## Espreme ou estica o Visual e solta em elástico — o mesmo gesto do arremesso
## da Cacau (ver _pancada_arremesso em ferramentas_player.gd).
func _esticar(fator: Vector2) -> void:
	if _tween_esticada and _tween_esticada.is_valid():
		_tween_esticada.kill()
	_esticada = fator
	_tween_esticada = create_tween()
	_tween_esticada.tween_property(self, "_esticada", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Cópia chapada do quadro atual, que fica para trás e desbota: é o rastro que
## deixa o mergulho legível mesmo durando um terço de segundo.
func _soltar_fantasma() -> void:
	var pai := get_parent()
	if _visual == null or pai == null or _visual.sprite_frames == null:
		return
	var textura := _visual.sprite_frames.get_frame_texture(_visual.animation, _visual.frame)
	if textura == null:
		return
	var fantasma := Sprite2D.new()
	fantasma.texture = textura
	fantasma.flip_h = _visual.flip_h
	fantasma.material = _material_do_rastro
	fantasma.z_index = z_index - 1
	fantasma.modulate.a = 0.6
	pai.add_child(fantasma)
	fantasma.global_transform = _visual.global_transform

	var some := fantasma.create_tween()
	some.tween_property(fantasma, "modulate:a", 0.0, FANTASMA_VIDA)
	some.tween_callback(fantasma.queue_free)


# --- ESTALOS, CÂMERA E TEMPO ---

## O "pá!" do acerto: a estrela no ponto do golpe, as lascas voando no rumo
## dele e os fiapos que caem. O golpe final é a mesma coisa, maior.
func _estalo_do_golpe(rumo: Vector2, final: bool) -> void:
	var cena := _cena_dos_efeitos()
	if cena == null:
		return
	var fx := EstalosPixel.criar(cena, global_position, z_index + 1)
	fx.estrela(Vector2.ZERO, 6 if final else 4, 0.16 if final else 0.13, COR_DO_ESTALO)
	fx.faiscas(9 if final else 5, rumo, 70.0, Vector2(80, 190), Vector2(0.14, 0.26),
		[COR_DO_ESTALO], 0.0, 1, 4.0)
	fx.faiscas(10 if final else 5, rumo + Vector2(0, -0.6), 150.0, Vector2(30, 95),
		Vector2(0.3, 0.55), [COR_DO_FIAPO, COR_DO_FIAPO_FUNDO, cor_dos_olhos], 260.0, 2, 1.2)
	if final:
		fx.estrela(Vector2(5, -4), 2, 0.14, COR_DO_ESTALO, 0.05)
		fx.estrela(Vector2(-4, 5), 2, 0.14, COR_DO_ESTALO, 0.09)


func _poeira(onde: Vector2, normal: Vector2, quantidade: int) -> void:
	var cena := _cena_dos_efeitos()
	if cena == null:
		return
	EstalosPixel.criar(cena, onde + normal * 2.0, z_index + 1) \
		.faiscas(quantidade, normal, 150.0, Vector2(25, 70), Vector2(0.2, 0.4),
			[COR_DA_POEIRA], 120.0, 2, 2.0) \
		.tufos(2, Vector2(1.0, 2.0), 4.0, Vector2(0.2, 0.3), COR_DA_POEIRA, 6.0)


## Onde os efeitos moram: na fase, não no morcego — ele sai voando dali.
func _cena_dos_efeitos() -> Node:
	if not is_inside_tree():
		return null
	var cena := get_tree().current_scene
	return cena if cena != null else get_parent()


## Congelamento de impacto, pelo mesmo caminho do bumerangue (ver
## congelar_impacto em ferramentas_player.gd). Quem pede primeiro leva: o
## bumerangue avisa o alvo ANTES de pedir o dele, então o pedido que sai daqui
## — mais longo, no golpe final — é o que vale.
func _congelar(segundos: float) -> void:
	if not _player_vale():
		return
	var ferramentas := _player.get_node_or_null("Ferramentas")
	if ferramentas and ferramentas.has_method("congelar_impacto"):
		ferramentas.congelar_impacto(segundos)


## Adiado de propósito: o bumerangue dispara o tremor dele (mais fraco) logo
## depois de avisar o alvo, e o tremor da câmera é "o último que pediu".
func _tremer_a_camera(intensidade: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("disparar_tremor"):
		camera.disparar_tremor.call_deferred(intensidade)


# --- SOM ---

## Um alto-falante só, segurando várias vozes ao mesmo tempo (o guincho por
## cima da batida de asa, a queda por cima do guincho de morte) — o mesmo
## AudioStreamPolyphonic do zunido do bumerangue.
func _preparar_voz() -> void:
	if _voz == null:
		return
	var polifonico := AudioStreamPolyphonic.new()
	polifonico.polyphony = VOZES
	_voz.stream = polifonico
	_voz.play()
	# Com driver de áudio dummy (--headless) isto pode vir nulo: daí o morcego
	# só fica mudo.
	_vozes = _voz.get_stream_playback() as AudioStreamPlaybackPolyphonic


func _tocar(som: AudioStream, volume_db: float = 0.0) -> void:
	if som == null or _vozes == null:
		return
	# O desafino miúdo é o que impede o bando de soar como um morcego só,
	# repetido.
	_vozes.play_stream(som, 0.0, volume_db, randf_range(0.93, 1.08))


## A batida de asa sai do próprio quadro em que as asas descem: mexer na
## velocidade da animação muda o compasso do som junto.
func _ao_trocar_quadro() -> void:
	if _visual.animation == ANIM_VOANDO and _visual.frame == QUADRO_DA_BATIDA and esta_no_ar():
		_tocar(som_asa, VOLUME_ASA)


# --- A TONTURA ---

## As estrelinhas que giram em cima da cabeça de quem está tonto. Desenhadas na
## grade de pixels da arte, como os brilhinhos da cura; as que passam "por
## trás" da cabeça encolhem para um ponto, e é isso que dá a volta.
class Tonteira extends Node2D:
	var _tempo: float = 0.0

	func _ready() -> void:
		scale = Vector2(EstalosPixel.ESCALA, EstalosPixel.ESCALA)
		var luz_propria := CanvasItemMaterial.new()
		luz_propria.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = luz_propria

	func _process(delta: float) -> void:
		if not visible:
			return
		_tempo += delta
		queue_redraw()

	func _draw() -> void:
		for beirada: bool in [true, false]:
			for i in ESTRELAS:
				var angulo: float = _tempo * TAU * VOLTAS_DAS_ESTRELAS + TAU * i / ESTRELAS
				var p := Vector2(cos(angulo) * ORBITA_DAS_ESTRELAS.x,
					sin(angulo) * ORBITA_DAS_ESTRELAS.y).floor()
				var na_frente: bool = sin(angulo) > -0.2
				var cor := Color(EstalosPixel.COR_BEIRADA, EstalosPixel.BEIRADA_ALFA) if beirada \
					else COR_DAS_ESTRELAS
				var folga := 1 if beirada else 0
				if not na_frente:
					draw_rect(Rect2(p.x - folga, p.y - folga, 1 + folga * 2, 1 + folga * 2), cor)
					continue
				draw_rect(Rect2(p.x - 1 - folga, p.y - folga, 3 + folga * 2, 1 + folga * 2), cor)
				draw_rect(Rect2(p.x - folga, p.y - 1 - folga, 1 + folga * 2, 3 + folga * 2), cor)
