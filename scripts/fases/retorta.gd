@tool
class_name RetortaCarbonizacao
extends Node2D

# --- A FORNALHA DE CARBONIZAÇÃO (clímax da Fase 1) ---
#
# ONDE ELA MORA: no PÁTIO, a fase1.2 (scenes/fases/fase1_2_exterior.tscn), que
# é a parte de fora do laboratório — sobe-se até lá pelo elevador de carga da
# entrada da oficina. A lenha mora lá com ela, na copa da árvore do pátio (ver
# ArvoreLenha), de propósito: é na própria cena da fornalha que a lenha
# perdida volta quando uma queima falha (ver _repor_toras), então lenha e
# forno não podem ficar em fases diferentes.
#
# Pirólise de verdade: madeira aquecida SEM oxigênio vira carvão. O puzzle
# segue seis passos:
#   1. derrubar as três toras da árvore com o bumerangue (uma por arremesso)
#      e recolhê-las do chão (elas ficam no inventário);
#   2. abastecer a fornalha com E — uma tora por toque, até encher;
#   3. acender com o maçarico oxídrico (E na fornalha cheia);
#   4. no painel da fornalha (scripts/ui/painel_fornalha.gd): segurar E até o
#      líquido do termômetro entrar na região marcada e mantê-lo lá dentro um
#      instante — aquecer demais queima a madeira e ela vira cinza;
#   5. TAMPAR O FORNO. A temperatura está no ponto, mas a boca do forno segue
#      aberta e o ar entra: a fornalha fica pegando fogo, À ESPERA. A Cacau
#      apanha a porta encostada ao lado (o nó Porta, com E — vai para a
#      mochila) e, com ela na mochila, E na fornalha fecha a boca do forno.
#      Não há relógio correndo contra ninguém: enquanto a porta não fecha, O
#      TEMPO NÃO PASSA — a noite não cai e o carvão não sai. Se ela demorar,
#      a Cacau comenta sozinha que devia tampar o forno (`fala_da_porta`).
#      Fechada a porta, O TEMPO AVANÇA: com o fogo abafado lá dentro, o céu
#      escurece e a lua sobe (ver _cair_a_noite). Só acontece uma vez na
#      partida; quando a brasa apaga já é noite, a porta salta de volta para o
#      lugar dela e o carvão sai;
#   6. com o carvão pronto, E na fornalha novamente retira a célula C — que
#      a Cacau leva ao baú do painel CHONPS, no laboratório.
#
# QUEM GUIA A JOGADORA: a lista de objetivos (canto superior esquerdo, ver
# roteiro_objetivos.gd) pede a lenha da árvore, com a contagem; daí em diante
# é o "!" — na fornalha quando é a vez de pôr a lenha, de acender, de tampar e
# de retirar o carvão, e na porta encostada quando é a vez de apanhá-la (ver
# _atualizar_exclamacao). O "!" fica aceso de longe, não só com ela por perto.
#
# COMO EDITAR NO EDITOR:
#   Sprite            -> AnimatedSprite2D da fornalha, com as animações
#                        "desligada", "madeira1", "madeira2", "madeira3" e
#                        "ligada" (o placeholder some sozinho)
#   PosicaoDoMacarico -> onde a Cacau fica para acender a fornalha. Como na
#                        porta de metal, ao apertar E com a fornalha cheia ela
#                        anda sozinha até aqui e só então acende o maçarico,
#                        virada para o forno. Arraste o marcador para mudar o
#                        lugar (o x é o que vale; ela anda no chão)
#   Porta             -> a porta encostada ao lado do forno, que a Cacau
#                        apanha (ver porta_da_fornalha.gd). Arraste para mudar
#                        o lugar dela. Sem este nó a fornalha pula o passo 5:
#                        resolvido o painel, o tempo já avança
#   PortaFechada      -> a mesma porta, já na boca do forno (só aparece com o
#                        forno tampado). Se a arte da fornalha mudar, é este nó
#                        que tem de voltar a cobrir a boca
#   SomPorta          -> a batida da porta fechando
#   SomConcluido      -> o som de puzzle resolvido, logo depois da batida
#   Inspector         -> `espera_antes_da_dica` (segundos até a fala) e
#                        `fala_da_porta` (a timeline do Dialogic)
#
# As toras NÃO ficam dentro desta cena. No pátio quem as cria é a ArvoreLenha
# (arraste os marcadores Galho1..3 dela para mudar onde caem), e é para ela
# que a lenha volta se a carga virar cinza: a árvore devolve à copa só as
# toras que se perderam no fogo. Numa fase sem árvore, as toras são
# instâncias de madeira.tscn soltas no chão (grupo "madeira") e a fornalha
# anota onde estavam, para repô-las no mesmo lugar.
#
# NINGUÉM SAI COM O FORNO ACESO, NEM SEM O CARVÃO: do instante em que o fogo
# pega até a Cacau RETIRAR o carvão, a passagem do pátio não deixa ela ir
# embora — ela para na beirada e diz por quê: com o forno aceso, que precisa
# terminar o carvão (`fala_ao_sair`); com o carvão pronto no forno, que
# precisa pegá-lo antes (`fala_sem_carvao`). Ver segura_a_saida, lá embaixo.
# Com o fogo apagado e o forno sem carvão a saída é livre: antes de acender,
# depois de desistir no painel ou de a carga virar cinza, e com o carvão já
# na mochila.
#
# SAIR DA FASE NÃO PERDE NADA: a carga do forno e o carvão esperando para ser
# retirado ficam no EstadoMundo (cada tora também lembra que foi recolhida). O
# forno pegando fogo à espera da porta fica anotado do mesmo jeito, para o
# caso de a fase recarregar com ele assim (a porta apanhada segue na mochila).

const CENA := "res://scenes/fases/componentes/retorta.tscn"

## O fogo pega primeiro e o painel da fornalha só entra depois desta espera.
const ESPERA_ANTES_DO_PAINEL := 0.8

## Depois que a pirólise termina, a fornalha ainda fica acesa este tanto antes
## de apagar — e é só depois que ela apaga que dá pra retirar o carvão.
const BRASA_APOS_CONCLUIR := 4.0

## Na vez em que a noite cai com a fornalha queimando (ver _cair_a_noite), a
## brasa dura a noite caindo e mais este tanto, olhando a lua já no alto.
const BRASA_APOS_A_NOITE := 1.2

## Quantos estágios de enchimento o sprite "fornalhaComMadeira" tem.
const ESTAGIOS_DE_MADEIRA := 3

## Trecho do ColocandoMadeira.mp3 que toca a cada tora abastecida — o arquivo
## tem mais coisa em volta, só esse pedaço é o "toc" da lenha entrando.
const SOM_MADEIRA_INICIO := 9.61
const SOM_MADEIRA_FIM := 11.20

## Salto do carvão para fora da fornalha quando a pirólise termina (ver
## _saltar_carvao): sobe até POSICAO_CARVAO_FORA + o extra do pico e cai de
## volta com um quique, pousando ali — é onde ele fica esperando o E.
const POSICAO_CARVAO_DENTRO := Vector2(0, -65)
const POSICAO_CARVAO_FORA := Vector2(0, -85)
const PICO_SALTO_CARVAO := 20.0

## Boca da fornalha: de onde sobe a cinza quando a carga queima.
const POSICAO_DAS_CINZAS := Vector2(0, -100)
## Porta fechada: as chamas do sprite andam neste ritmo, o som do fogo baixa
## isto (dB) e a luz que escapa para o pátio cai para esta fração, até a brasa
## apagar.
const RITMO_DO_FOGO_ABAFADO := 0.5
const ABAFAMENTO_DO_SOM := 9.0
const LUZ_COM_A_PORTA := 0.5
## Da batida da porta ao som de puzzle resolvido, e dele até o tempo começar a
## andar (ver _fechar_a_porta).
const PAUSA_DEPOIS_DA_PORTA := 0.45
const PAUSA_ANTES_DE_CONCLUIR := 1.1
## A porta entra na boca do forno um pouco maior e assenta com um tranco.
const TRANCO_DA_PORTA := 1.3
const TREMOR_DA_PORTA := 2.0

## Arte e ficha do item que vai para a mochila (canto superior direito) ao
## retirar o carvão — mesma ficha de coleta dos cilindros de H₂/O₂.
const TEXTURA_CARVAO := preload("res://assets/itens/Carvão.png")
const ID_CARVAO := AmostraChonps.ID_CARVAO
const NOME_CARVAO := "Carvão Vegetal"
## Carvão vegetal NÃO é carbono puro (puro mesmo, só diamante e grafite — o
## rádio do Dr. Chico explica isso na entrada da fase 1): a ficha diz "rica em".
const DESCRICAO_CARVAO := "Amostra sólida rica em carbono, sobra da pirólise da madeira sem oxigênio."

@export var madeiras_necessarias: int = 3

@export_group("Porta")
## Segundos com a fornalha pegando fogo de boca aberta até a Cacau comentar
## que devia tampar o forno. Zero desliga a fala.
@export var espera_antes_da_dica: float = 12.0
## Timeline do Dialogic com a fala dela. Vazio desliga a fala.
@export var fala_da_porta: String = "cacau_tampar_forno"

@export_group("Saída")
## Timeline do Dialogic com o que a Cacau diz quando tenta sair da fase com o
## forno aceso. Vazio = ela é barrada do mesmo jeito, só que calada.
@export var fala_ao_sair: String = "cacau_terminar_carvao"
## Timeline do Dialogic com o que a Cacau diz quando tenta sair da fase com o
## carvão pronto ainda no forno. Vazio = barrada do mesmo jeito, calada.
@export var fala_sem_carvao: String = "cacau_pegar_carvao"

var _madeiras_no_forno: int = 0
var _acesa: bool = false
var _carbono_pronto: bool = false
var _jogador_perto: bool = false
var _resolvida: bool = false
var _painel_aberto: bool = false
var _macarico_na_mao: bool = false
var _painel: PainelFornalha = null
var _volume_do_fogo: float = 0.0

# A temperatura chegou no ponto e a fornalha segue pegando fogo, de boca
# aberta: enquanto a porta não fecha, o tempo não passa e o carvão não sai.
var _esperando_porta: bool = false
# A porta está na boca do forno, com a carga carbonizando lá dentro.
var _porta_fechada: bool = false
# Há quanto tempo o forno espera pela porta, e se a Cacau já comentou.
var _tempo_esperando: float = 0.0
var _dica_dada: bool = false
# A luz do fogo e a porta na boca do forno como estão na cena (ver _abafar_fogo
# e _encaixar_a_porta, que mexem nelas e depois devolvem).
var _energia_do_fogo: float = 0.0
var _clarao_do_fogo: float = 0.0
var _escala_da_porta: Vector2 = Vector2.ONE

# As toras da fase como estavam quando ela abriu (nome, posição e caminho),
# para repô-las depois de uma queima malsucedida — com o MESMO nome, que é a
# chave com que cada tora lembra no EstadoMundo se já foi recolhida.
var _toras_originais: Array[Dictionary] = []
var _pai_das_toras: Node = null

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _placeholder: Node2D = $Placeholder
@onready var _area: Area2D = $AreaInteracao
@onready var _posicao_macarico: Marker2D = $PosicaoDoMacarico
@onready var _exclamacao: AnimatedSprite2D = $ExclamacaoAnimada
@onready var _som_madeira: AudioStreamPlayer2D = $SomColocarMadeira
@onready var _sprite_carvao: Sprite2D = $SpriteCarvao
@onready var _som_carvao: AudioStreamPlayer2D = $SomCarvaoPronto
@onready var _som_fogo: AudioStreamPlayer2D = $SomFogo
## O clarão do fogo no pátio (scripts/luz/luz_pontual.gd). A fornalha queima de
## noite: sem isto as chamas apareceriam no sprite e não iluminariam nada.
@onready var _luz_do_fogo: LuzPontual = get_node_or_null("LuzDoFogo")
## A porta encostada ao lado do forno (a que a Cacau apanha) e a mesma porta já
## na boca dele. Sem o nó Porta a fornalha funciona sem o passo de tampar.
@onready var _porta := get_node_or_null("Porta") as PortaDaFornalha
@onready var _porta_na_boca: Sprite2D = get_node_or_null("PortaFechada")
@onready var _som_porta: AudioStreamPlayer = get_node_or_null("SomPorta")
@onready var _som_concluido: AudioStreamPlayer = get_node_or_null("SomConcluido")

# O "!" da fornalha está na tela (ver _atualizar_exclamacao): o PopupFX só
# dispara quando isto muda, senão a animação reiniciaria a cada quadro.
var _exclamacao_visivel: bool = false


static func criar(pai: Node, pos: Vector2, config: Dictionary = {}) -> RetortaCarbonizacao:
	var retorta: RetortaCarbonizacao = load(CENA).instantiate()
	retorta.name = "Retorta"
	retorta.position = pos
	for chave in config:
		retorta.set(chave, config[chave])
	Blockout.adicionar(pai, retorta)
	return retorta


func _ready() -> void:
	if _sprite and _placeholder:
		_placeholder.visible = _sprite.sprite_frames == null
		_sprite.visible = _sprite.sprite_frames != null
	_atualizar_sprite()
	if Engine.is_editor_hint():
		return

	if _som_fogo:
		_volume_do_fogo = _som_fogo.volume_db
	if _luz_do_fogo:
		_energia_do_fogo = _luz_do_fogo.energia
		_clarao_do_fogo = _luz_do_fogo.clarao
	if _porta_na_boca:
		_escala_da_porta = _porta_na_boca.scale
	# É por este grupo que a passagem da fase pergunta se pode deixar a Cacau
	# sair (ver segura_a_saida).
	add_to_group(PassagemDeCena.GRUPO_DE_QUEM_SEGURA)
	_resolvida = EstadoMundo.ja_feito(self)
	# O que estava dentro da fornalha na última visita: sair da fase não
	# esvazia a carga nem some com o carvão que esperava ser retirado.
	_madeiras_no_forno = EstadoMundo.ler(self, "madeiras_no_forno", 0)
	_carbono_pronto = EstadoMundo.ler(self, "carbono_pronto", false)
	# Ela saiu com o forno no ponto e de boca aberta: ele continua pegando
	# fogo, do jeito que ficou, à espera da porta.
	_esperando_porta = _porta != null and not _resolvida and not _carbono_pronto and _cheia() \
		and EstadoMundo.ler(self, "esperando_porta", false)
	_acesa = _esperando_porta
	_memorizar_toras()
	_atualizar_sprite()
	_atualizar_porta()
	if _porta:
		_porta.apanhada.connect(_atualizar_exclamacao)
	if _carbono_pronto and _sprite_carvao:
		_sprite_carvao.position = POSICAO_CARVAO_FORA
		_sprite_carvao.visible = true

	if _exclamacao:
		_exclamacao.visible = false
		_exclamacao.stop()

	_area.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_jogador_perto = true)
	_area.body_exited.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_jogador_perto = false)

	if _resolvida:
		_limpar_toras()


## Anota as toras que a fase trouxe — inclusive as já recolhidas numa visita
## anterior, que ainda estão na árvore neste frame (o queue_free delas só
## acontece no fim do quadro) —, para saber repô-las depois.
func _memorizar_toras() -> void:
	_toras_originais.clear()
	for tora in get_tree().get_nodes_in_group(Madeira.GRUPO):
		if tora is Node2D:
			_toras_originais.append({
				"nome": tora.name,
				"posicao": tora.global_position,
				"caminho": str(tora.get_path()),
			})
			if _pai_das_toras == null:
				_pai_das_toras = tora.get_parent()


func _limpar_toras() -> void:
	for tora in get_tree().get_nodes_in_group(Madeira.GRUPO):
		tora.queue_free()


## Devolve a lenha depois de uma queima perdida. Com a ArvoreLenha na fase, as
## toras perdidas voltam para a copa dela. Sem árvore, voltam aos lugares de
## origem no chão, com o nome original e "desrecolhidas" no EstadoMundo: quem
## sair e voltar para a fase depois disso continua achando as toras lá.
func _repor_toras() -> void:
	# Com a árvore do pátio na fase, a lenha não reaparece no chão: a que virou
	# cinza volta para a copa, e é o bumerangue que a derruba de novo.
	var arvore := get_tree().get_first_node_in_group(ArvoreLenha.GRUPO) as ArvoreLenha
	if arvore:
		arvore.repor_toras_perdidas()
		return
	var pai: Node2D = null
	if is_instance_valid(_pai_das_toras):
		pai = _pai_das_toras as Node2D
	if pai == null:
		pai = get_parent() as Node2D
	if pai == null:
		return
	for tora in get_tree().get_nodes_in_group(Madeira.GRUPO):
		# Sai da árvore JÁ: a tora nova precisa do mesmo nome livre.
		tora.get_parent().remove_child(tora)
		tora.queue_free()
	for dados in _toras_originais:
		EstadoMundo.desmarcar_caminho(dados["caminho"])
		Madeira.criar(pai, dados["nome"], pai.to_local(dados["posicao"]))


## Anota a carga e o carvão no EstadoMundo, para sobreviverem a sair da fase.
func _guardar_carga() -> void:
	EstadoMundo.guardar(self, "madeiras_no_forno", _madeiras_no_forno)
	EstadoMundo.guardar(self, "carbono_pronto", _carbono_pronto)


func _cheia() -> bool:
	return _madeiras_no_forno >= madeiras_necessarias


## Escolhe o quadro da fornalha: apagada, enchendo (3 estágios) ou em chamas.
func _atualizar_sprite() -> void:
	if _luz_do_fogo:
		_luz_do_fogo.acesa = _acesa
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if _acesa:
		if _sprite.animation != &"ligada":
			_tocar_som_fogo()
		_sprite.play("ligada")
		return
	# Apagada, as chamas voltam ao ritmo normal para a próxima queima.
	_sprite.speed_scale = 1.0
	if _madeiras_no_forno <= 0:
		_parar_som_fogo()
		_sprite.play("desligada")
	else:
		# Vale para qualquer "madeiras_necessarias": a carga é distribuída
		# entre os estágios que o sprite tem.
		_parar_som_fogo()
		var fracao := float(_madeiras_no_forno) / float(maxi(madeiras_necessarias, 1))
		var estagio := clampi(int(ceil(fracao * ESTAGIOS_DE_MADEIRA)), 1, ESTAGIOS_DE_MADEIRA)
		_sprite.play("madeira%d" % estagio)


## O "!" da fornalha aponta o PASSO DA VEZ, e fica aceso de longe (o pátio é
## uma tela só: dá para ver de onde ela estiver). Aparece quando o E na
## fornalha é o que falta fazer agora:
##   abastecer  ela tem lenha na mochila e o forno ainda não encheu;
##   acender    o forno está cheio, ainda frio (o E acende com o maçarico);
##   tampar     o forno espera pela porta e a porta já está na mochila — antes
##              disso o "!" é o da PORTA, encostada ao lado (porta_da_fornalha.gd);
##   retirar    a brasa apagou e o carvão está esperando.
## Some com o painel na tela, com o forno tampado carbonizando e depois que o
## carvão sai. Sem lenha na mochila e com o forno por encher, quem guia é a
## lista de objetivos (derrubar a lenha da árvore com o bumerangue).
func _atualizar_exclamacao() -> void:
	if _exclamacao == null:
		return
	var mostrar := _passo_da_vez_e_aqui()
	if mostrar == _exclamacao_visivel:
		return
	_exclamacao_visivel = mostrar
	if mostrar:
		PopupFX.mostrar(_exclamacao)
	else:
		PopupFX.esconder(_exclamacao)


func _passo_da_vez_e_aqui() -> bool:
	if _resolvida or _painel_aberto or _porta_fechada:
		return false
	if _carbono_pronto:
		return not _acesa
	if _esperando_porta:
		return PortaDaFornalha.na_mochila()
	if _acesa:
		return false
	if _cheia():
		return Progresso.tem_habilidade("macarico")
	return Madeira.quantidade_no_inventario() > 0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _resolvida:
		return
	_atualizar_exclamacao()
	if _painel_aberto:
		# Com o painel na tela, a pose segue o fogo: atiçando (E) ela aponta o
		# maçarico para o forno, largando ela volta ao idle. Enquanto o painel
		# não abriu (o fogo pegando), a chama fica acesa direto.
		if is_instance_valid(_painel):
			_segurar_macarico(_painel.soprando(), 1.0)
		return
	if _esperando_porta:
		_vigiar_a_porta(delta)
		return
	if _porta_fechada:
		# Tampado e carbonizando: não há nada para fazer aqui até a brasa
		# apagar (ver _concluir).
		return
	if _carbono_pronto:
		# A pirólise terminou: em vez de pular em cima de um item flutuante,
		# a célula sai com o mesmo E usado para abastecer e acender.
		if _jogador_perto and Interacao.pediu():
			_retirar_carbono()
		return
	if _jogador_perto and Interacao.pediu():
		if _cheia():
			_tentar_acender()
		else:
			_abastecer()


func _abastecer() -> void:
	if not Madeira.consumir_do_inventario():
		return
	_madeiras_no_forno += 1
	_guardar_carga()
	_atualizar_sprite()
	_tocar_som_madeira()


## Recorte de ColocandoMadeira.mp3 (ver SOM_MADEIRA_INICIO/FIM) — uma tora
## abastecida, um toque.
func _tocar_som_madeira() -> void:
	if _som_madeira == null or _som_madeira.stream == null:
		return
	_som_madeira.play(SOM_MADEIRA_INICIO)
	await get_tree().create_timer(SOM_MADEIRA_FIM - SOM_MADEIRA_INICIO).timeout
	if is_instance_valid(_som_madeira) and _som_madeira.playing:
		_som_madeira.stop()


## Toca res://sounds/FOGO.mp3 no instante em que a fornalha entra na animação
## "ligada" (o fogo pegando, ao acender com o maçarico).
func _tocar_som_fogo() -> void:
	if _som_fogo and _som_fogo.stream:
		_som_fogo.volume_db = _volume_do_fogo
		_som_fogo.play()


## Corta o som do fogo assim que a fornalha sai da animação "ligada" (apagou,
## desistiu ou a queima falhou).
func _parar_som_fogo() -> void:
	if _som_fogo and _som_fogo.playing:
		_som_fogo.stop()


func _tentar_acender() -> void:
	if not Progresso.tem_habilidade("macarico"):
		return

	_painel_aberto = true

	# Como na porta de metal: ela vai sozinha até o lugar de acender (o
	# marcador PosicaoDoMacarico) e só então a chama sai. O _painel_aberto
	# já ligado segura o E enquanto ela anda.
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("recuar_ate_x"):
		await player.recuar_ate_x(_posicao_macarico.global_position.x)
		if not is_instance_valid(self) or not is_inside_tree():
			return

	_acesa = true
	_atualizar_sprite()
	# Acendendo: a chama fica na mão dela até o painel abrir. Dali em diante a
	# pose acompanha o E (ver _process).
	_segurar_macarico(true)
	FerramentasHUD.destacar("macarico")

	# O fogo pega primeiro: o mundo continua rodando (o painel não pausa
	# nada), então dá para ver a fornalha pegando antes dele.
	await get_tree().create_timer(ESPERA_ANTES_DO_PAINEL).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return

	_painel = PainelFornalha.abrir(self, _area_da_cena())
	_painel.terminado.connect(_on_painel_terminado)


## O que o painel não pode tapar: a fornalha e a Cacau parada na frente dela.
func _area_da_cena() -> Rect2:
	var area := Rect2(global_position, Vector2.ZERO)
	if _sprite and _sprite.sprite_frames:
		var textura := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
		if textura:
			var tamanho := textura.get_size() * _sprite.global_scale.abs()
			area = Rect2(_sprite.global_position - tamanho * 0.5, tamanho)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		area = area.expand(player.global_position + Vector2(-40, -110))\
			.expand(player.global_position + Vector2(40, 10))
	return area


## A pirólise deu certo e a fornalha continua pegando fogo: o tempo avança. O
## céu vai do crepúsculo à noite, as estrelas acendem e a lua sobe de trás da
## serra (Atmosfera.anoitecer); a Cacau fica parada e o HUD sai de cena
## enquanto isso. Daí em diante é noite pelo resto da partida. Devolve se a
## noite caiu agora — numa fase sem Atmosfera, ou onde já é noite, não
## acontece nada.
func _cair_a_noite() -> bool:
	var atmosfera := Atmosfera.da_cena(self)
	if atmosfera == null or not atmosfera.pode_anoitecer():
		return false
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.pode_se_mover = false
	var cena := get_tree().current_scene
	# Sem apagar a tela: a cortina está aqui só para tirar o HUD de cena.
	var cortina := FadeTela.criar(cena)
	cortina.esconder_huds(cena)

	await atmosfera.anoitecer()
	await get_tree().create_timer(BRASA_APOS_A_NOITE).timeout

	cortina.restaurar_huds()
	cortina.queue_free()
	if is_instance_valid(player):
		player.pode_se_mover = true
	return true


# --- NINGUÉM SAI COM O FORNO ACESO, NEM SEM O CARVÃO ---

## A passagem da fase pergunta isto antes de deixar a Cacau sair (ver "QUANDO
## NÃO DÁ PARA SAIR" em passagem_de_cena.gd). Do instante em que o fogo pega
## até ela RETIRAR o carvão, ela fica no pátio: o carvão é a amostra que vai
## para o baú do painel CHONPS, e não pode ficar esquecido no forno. Desistir no
## painel ou deixar a carga virar cinza apaga o fogo — e aí a saída volta a ser
## livre.
func segura_a_saida() -> bool:
	return _acesa or _carbono_pronto


## Ela tentou sair antes da hora: a Cacau diz por que não vai — o forno ainda
## aceso ("fala_ao_sair") ou o carvão esperando no forno ("fala_sem_carvao").
## (Com outra conversa já no ar, a fala simplesmente não abre — ela é barrada
## calada.)
func ao_barrar_a_saida() -> void:
	var fala := fala_sem_carvao if _carbono_pronto and not _acesa else fala_ao_sair
	if not fala.is_empty():
		DialogicBridge.falar(fala)


## Liga/desliga a pose do maçarico na personagem (ela fica virada para o forno).
## som_offset só importa ao ligar: de onde tocar o maçarico_sound dessa vez.
func _segurar_macarico(ligado: bool, som_offset: float = 0.1) -> void:
	if ligado == _macarico_na_mao:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("iniciar_uso_macarico"):
		return
	_macarico_na_mao = ligado
	if ligado:
		player.iniciar_uso_macarico(global_position.x, som_offset)
	else:
		player.encerrar_uso_macarico()
		if _painel_aberto:
			# A tela ainda está na frente: largar a pose não devolve o passeio.
			player.pode_se_mover = false


func _on_painel_terminado(sucesso: bool, cancelado: bool) -> void:
	_painel_aberto = false
	_painel = null
	_segurar_macarico(false)
	if cancelado:
		# Desistiu: o fogo apaga, mas a carga continua lá dentro.
		_acesa = false
		_atualizar_sprite()
		return
	if sucesso:
		if _porta != null:
			_esperar_pela_porta()
		else:
			_concluir()
	else:
		# Feedback honesto e imediato: cinzas, e lenha nova logo ali.
		_acesa = false
		_madeiras_no_forno = 0
		_guardar_carga()
		_atualizar_sprite()
		_soltar_cinzas()
		_repor_toras()


# --- A PORTA ---

## A temperatura está no ponto, mas a boca do forno continua aberta e o ar
## entra. A fornalha fica pegando fogo À ESPERA da porta: não há relógio
## correndo contra a jogadora — enquanto a porta não fecha, o tempo não passa
## (a noite não cai) e o carvão não sai.
func _esperar_pela_porta() -> void:
	_esperando_porta = true
	_tempo_esperando = 0.0
	_dica_dada = false
	EstadoMundo.guardar(self, "esperando_porta", true)
	_atualizar_porta()
	_atualizar_exclamacao()


## Um quadro do forno à espera: fecha a porta se a Cacau a trouxe e, se ela
## estiver demorando, solta a fala (uma vez por espera).
func _vigiar_a_porta(delta: float) -> void:
	# Interacao.pediu() queima o toque de E, então fica por ÚLTIMO: sem a porta
	# na mochila o E é de quem estiver por perto (a própria porta, no chão).
	if _jogador_perto and PortaDaFornalha.na_mochila() and Interacao.pediu():
		_fechar_a_porta()
		return
	if _dica_dada or espera_antes_da_dica <= 0.0 or fala_da_porta.is_empty():
		return
	# O relógio da fala só anda com a Cacau solta no pátio, sem tela na frente.
	if Interacao.ocupada():
		return
	_tempo_esperando += delta
	# Se já houver outra conversa no ar, a fala fica para o quadro em que couber.
	if _tempo_esperando >= espera_antes_da_dica and DialogicBridge.falar(fala_da_porta):
		_dica_dada = true


## A Cacau põe a porta na boca do forno. Sem ar o fogo abafa — e é AGORA que a
## madeira vira carvão e o tempo anda (ver _concluir).
func _fechar_a_porta() -> void:
	if not PortaDaFornalha.tirar_da_mochila():
		return
	_esperando_porta = false
	_porta_fechada = true
	# Anotado já: quem sair da fase nestes segundos volta com o carvão
	# esperando para ser retirado, e não com o forno de boca aberta.
	_anotar_carvao()
	_atualizar_porta()
	_atualizar_exclamacao()
	_encaixar_a_porta()
	_abafar_fogo()

	await get_tree().create_timer(PAUSA_DEPOIS_DA_PORTA).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if _som_concluido and _som_concluido.stream:
		_som_concluido.play()
	await get_tree().create_timer(PAUSA_ANTES_DE_CONCLUIR).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_concluir()


## A porta entra na boca do forno com um tranco: chega um pouco maior, assenta,
## bate (som) e sacode a câmera.
func _encaixar_a_porta() -> void:
	if _som_porta and _som_porta.stream:
		_som_porta.play()
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("disparar_tremor"):
		camera.disparar_tremor(TREMOR_DA_PORTA)
	if _porta_na_boca == null:
		return
	_porta_na_boca.scale = _escala_da_porta * TRANCO_DA_PORTA
	_porta_na_boca.modulate.a = 0.0
	_porta_na_boca.visible = true
	var tween := create_tween().set_parallel()
	tween.tween_property(_porta_na_boca, "scale", _escala_da_porta, 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_porta_na_boca, "modulate:a", 1.0, 0.06)


## A brasa apagou: a porta salta da boca do forno de volta para o lugar dela —
## é por ali que o carvão sai logo atrás (ver _saltar_carvao).
func _abrir_a_porta() -> void:
	if not _porta_fechada:
		return
	_porta_fechada = false
	var boca := _porta_na_boca.global_position if _porta_na_boca else global_position
	_atualizar_porta()
	if _porta:
		_porta.voltar_de(boca)


## Quem manda na porta é o estado da fornalha: só dá para apanhá-la enquanto o
## forno espera por ela, e na boca do forno ela é outro desenho (PortaFechada).
func _atualizar_porta() -> void:
	if _porta_na_boca:
		_porta_na_boca.visible = _porta_fechada
		_porta_na_boca.scale = _escala_da_porta
		_porta_na_boca.modulate.a = 1.0
	if _porta:
		_porta.disponivel = _esperando_porta


## Porta fechada: sem ar, as chamas baixam, o fogo soa abafado e escapa menos
## luz para o pátio, até a brasa apagar (ver _concluir).
func _abafar_fogo() -> void:
	var tween := create_tween().set_parallel()
	if _sprite:
		tween.tween_property(_sprite, "speed_scale", RITMO_DO_FOGO_ABAFADO, 0.6)
	if _som_fogo:
		tween.tween_property(_som_fogo, "volume_db", _volume_do_fogo - ABAFAMENTO_DO_SOM, 0.6)
	if _luz_do_fogo:
		tween.tween_property(_luz_do_fogo, "energia", _energia_do_fogo * LUZ_COM_A_PORTA, 0.6)
		tween.tween_property(_luz_do_fogo, "clarao", _clarao_do_fogo * LUZ_COM_A_PORTA, 0.6)


## A carga queimou: um punhado de cinza sobe da boca do forno.
func _soltar_cinzas() -> void:
	var cinzas := CPUParticles2D.new()
	cinzas.name = "Cinzas"
	cinzas.position = POSICAO_DAS_CINZAS
	cinzas.z_index = 1
	cinzas.amount = 26
	cinzas.lifetime = 1.8
	cinzas.one_shot = true
	cinzas.explosiveness = 0.8
	cinzas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	cinzas.emission_rect_extents = Vector2(30, 8)
	cinzas.direction = Vector2.UP
	cinzas.spread = 40.0
	cinzas.initial_velocity_min = 30.0
	cinzas.initial_velocity_max = 80.0
	cinzas.gravity = Vector2(0, -15)
	cinzas.damping_min = 25.0
	cinzas.damping_max = 45.0
	cinzas.scale_amount_min = 3.0
	cinzas.scale_amount_max = 6.0
	var rampa := Gradient.new()
	rampa.set_color(0, Color(0.62, 0.6, 0.64, 1.0))
	rampa.set_color(1, Color(0.35, 0.33, 0.37, 0.0))
	cinzas.color_ramp = rampa
	add_child(cinzas)
	cinzas.emitting = true
	cinzas.finished.connect(cinzas.queue_free)


## A carga já é carvão, ainda dentro do forno. Anotado antes de a brasa apagar:
## quem sair da fase nesses segundos volta com o carvão esperando para ser
## retirado.
func _anotar_carvao() -> void:
	_madeiras_no_forno = 0
	EstadoMundo.guardar(self, "madeiras_no_forno", 0)
	EstadoMundo.guardar(self, "carbono_pronto", true)
	EstadoMundo.guardar(self, "esperando_porta", false)


## A pirólise deu certo (o forno foi tampado no ponto): o tempo anda, a brasa
## apaga e o carvão sai.
func _concluir() -> void:
	_esperando_porta = false
	_anotar_carvao()

	# A célula só pode ser retirada depois que a brasa apaga: a fornalha
	# continua queimando um tempo antes de o sprite voltar ao forno frio. Na
	# primeira vez esse tempo é a noite caindo.
	if not await _cair_a_noite():
		await get_tree().create_timer(BRASA_APOS_CONCLUIR).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_acesa = false
	_carbono_pronto = true
	_atualizar_sprite()
	_abrir_a_porta()
	_atualizar_exclamacao()
	_saltar_carvao()
	# A luz do fogo volta ao que era para a próxima queima — depois de apagar,
	# senão ela daria um clarão na saída.
	if _luz_do_fogo:
		var devolver := create_tween()
		devolver.tween_interval(0.5)
		devolver.tween_callback(func() -> void:
			_luz_do_fogo.energia = _energia_do_fogo
			_luz_do_fogo.clarao = _clarao_do_fogo)


## O carvão pula para fora da fornalha assim que a brasa apaga: som "POP" e
## um salto com quique — o mesmo instante em que o "!" de retirar aparece.
func _saltar_carvao() -> void:
	if _sprite_carvao == null:
		return
	if _som_carvao and _som_carvao.stream:
		_som_carvao.play()
	_sprite_carvao.position = POSICAO_CARVAO_DENTRO
	_sprite_carvao.visible = true
	var tween := create_tween()
	tween.tween_property(_sprite_carvao, "position",
		POSICAO_CARVAO_FORA + Vector2(0, -PICO_SALTO_CARVAO), 0.16)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite_carvao, "position", POSICAO_CARVAO_FORA, 0.28)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Chamado quando a pessoa aperta E na fornalha com o carvão pronto.
func _retirar_carbono() -> void:
	_carbono_pronto = false
	_guardar_carga()
	if _sprite_carvao:
		_sprite_carvao.visible = false
	_resolvida = true
	EstadoMundo.marcar_feito(self)
	# Só agora, com ela resolvida: antes disso o forno (ainda cheio) pediria o
	# "!" de acender.
	_atualizar_exclamacao()
	# O carvão É a amostra de carbono: vai na mochila e só acende o C no painel
	# quando a Cacau o joga no receptor do laboratório.
	Progresso.coletar_celula("C")
	if Inventario.tela_hud_referencia != null:
		Inventario.tela_hud_referencia.exibir_popup(
			NOME_CARVAO, TEXTURA_CARVAO, DESCRICAO_CARVAO, ID_CARVAO)
