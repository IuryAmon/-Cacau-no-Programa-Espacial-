class_name MissaoNitrogenio
extends RefCounted

# --- O QUE A FASE DO NITROGÊNIO LEMBRA (entre as salas) ---
#
# A fase 2 é uma rua com três prédios, e cada prédio é uma cena: a sala do
# compressor, a torre (com o telhado) e a sala de destilação. O caminho do
# nitrogênio passa por todas, e o que a Cacau já fez em cada uma precisa valer
# nas outras — inclusive o RELÓGIO da amostra gelada, que continua correndo
# enquanto ela atravessa a rua. Mesmo truque do EstadoMundo: "static var" vive
# no script e sobrevive à troca de cena (e à recarga de uma morte). Fechar o
# jogo esquece tudo, como o resto do jogo.
#
# O CAMINHO, em ordem:
#   1. o cilindro VAZIO, no telhado da torre (item "cilindro_de_ar");
#   2. ACOPLADO no compressor (sai da mochila, fica na máquina);
#   3. o puzzle do compressor: a máquina (MaquinaDeCompressao) fica guardada
#      aqui, então sair da sala no meio e voltar encontra o êmbolo e o
#      resfriador onde estavam;
#   4. a AMOSTRA: fechada a válvula, a Cacau leva o cilindro de ar líquido
#      (item "cilindro_de_ar_liquido") — e ele esquenta (ver
#      ContagemDaAmostra, que mostra o relógio e o põe nas costas dela);
#   5. ENTREGUE na coluna de destilação, o relógio para;
#   6. DESTILADO: o nitrogênio sai da coluna (quase puro) num cilindro verde,
#      a amostra do elemento N (AmostraChonps), que vai para o painel CHONPS.
#
# Estourar (no puzzle ou no caminho) é FIM DE JOGO (TelaGameOver). Tentar de
# novo devolve o cilindro VAZIO, acoplado no compressor, com a máquina do
# começo (recomecar_depois_da_explosao).

## As cenas da fase.
const CENA_RUA := "res://scenes/fases/fase2_torre.tscn"
const CENA_COMPRESSOR := "res://scenes/fases/fase2_sala_compressor.tscn"
const CENA_DESTILACAO := "res://scenes/fases/fase2_sala_destilacao.tscn"
const CENA_TORRE := "res://scenes/fases/fase2_torre_interior.tscn"
const CENA_TELHADO := "res://scenes/fases/fase2_telhado.tscn"

## Os itens da mochila.
const ID_CILINDRO_VAZIO := "cilindro_de_ar"
const ID_AMOSTRA := "cilindro_de_ar_liquido"

const NOME_CILINDRO_VAZIO := "Cilindro de Ar (Vazio)"
const DESCRICAO_CILINDRO_VAZIO := "Um cilindro de amostra, vazio e leve. No compressor, dá para enchê-lo com o ar da sala."
const TEXTURA_CILINDRO_VAZIO := preload("res://assets/fase nitrogenio/Cilindro de Ar.png")

const NOME_AMOSTRA := "Cilindro de Ar Líquido (Amostra)"
const DESCRICAO_AMOSTRA := "Ar apertado e gelado até virar líquido. Fechado, o calor da sala vai entrando e a pressão sobe: leve à coluna de destilação antes que ele estoure!"
const TEXTURA_AMOSTRA := preload("res://assets/fase nitrogenio/cilindro de ar liquido.png")

## O cilindro vazio está preso no compressor.
static var cilindro_acoplado: bool = false
## A amostra gelada que a Cacau carrega (null = nenhuma). É a física de
## verdade dela: a ContagemDaAmostra esquenta este gás a cada quadro.
static var amostra: GasFechado = null
## A amostra já está dentro da coluna de destilação.
static var amostra_na_coluna: bool = false
## A coluna já separou o ar: o cilindro de nitrogênio está pronto (ou já foi).
static var nitrogenio_destilado: bool = false
## O Dr. Chico já explicou o compressor (a fala da primeira vez).
static var explicou_o_compressor: bool = false
## A explicação da coluna já passou pelo menos uma vez com a amostra.
static var explicou_a_destilacao: bool = false
## A Cacau já chegou ao telhado (só a primeira chegada tem a fala dela).
static var subiu_a_torre: bool = false
## Onde está a cabine do elevador de carga da torre. Ela começa PARADA lá no
## telhado e fica no andar em que a Cacau a deixou: a rua só a mostra depois
## que ela desce nela (ver posicionar_cabine).
static var elevador_no_telhado: bool = true

static var _maquina: MaquinaDeCompressao = null


## A máquina do compressor, do jeito que a pessoa deixou.
static func maquina() -> MaquinaDeCompressao:
	if _maquina == null:
		_maquina = MaquinaDeCompressao.new()
	return _maquina


# ─────────────────────────────────────────────────────────────
# PERGUNTAS
# ─────────────────────────────────────────────────────────────

static func tem_cilindro_vazio() -> bool:
	return Inventario.tem_item(ID_CILINDRO_VAZIO)


static func carregando_amostra() -> bool:
	return amostra != null


## A amostra já saiu do compressor (na mão, na coluna ou já destilada): a
## máquina já fez a parte dela.
static func compressor_concluido() -> bool:
	return carregando_amostra() or amostra_na_coluna or nitrogenio_destilado \
		or Progresso.conquistou_celula("N")


# ─────────────────────────────────────────────────────────────
# O CAMINHO
# ─────────────────────────────────────────────────────────────

## O cilindro vazio sai da mochila e fica preso na máquina.
static func acoplar_cilindro() -> void:
	cilindro_acoplado = true
	Inventario.remover_item(ID_CILINDRO_VAZIO)


## A válvula fechou: a Cacau pega a amostra gelada. A ficha de coleta sobe (o
## relógio espera ela fechar) e o relógio é posto na cena.
static func comecar_amostra(gas: GasFechado, cena: Node) -> void:
	amostra = gas
	cilindro_acoplado = false
	if Inventario.tela_hud_referencia != null:
		Inventario.tela_hud_referencia.exibir_popup(NOME_AMOSTRA, TEXTURA_AMOSTRA, DESCRICAO_AMOSTRA, ID_AMOSTRA)
	else:
		Inventario.adicionar_item(ID_AMOSTRA, NOME_AMOSTRA, TEXTURA_AMOSTRA, DESCRICAO_AMOSTRA)
	if cena != null:
		instalar_na_fase(cena)


## A amostra entrou na coluna: o relógio para.
static func entregar_amostra_na_coluna() -> void:
	amostra = null
	amostra_na_coluna = true
	Inventario.remover_item(ID_AMOSTRA)


## A coluna separou o ar e o cilindro verde de nitrogênio está pronto.
static func concluir_destilacao() -> void:
	nitrogenio_destilado = true
	amostra_na_coluna = false


## Fim de jogo, tentar de novo: o cilindro vazio volta preso no compressor e a
## máquina volta ao começo (o ar da sala, o êmbolo no alto).
static func recomecar_depois_da_explosao() -> void:
	amostra = null
	cilindro_acoplado = true
	Inventario.remover_item(ID_AMOSTRA)
	Inventario.remover_item(ID_CILINDRO_VAZIO)
	maquina().reiniciar()


## A rua e o telhado chamam isto ao abrir, com o elevador de carga deles: a
## cabine só aparece no andar em que está. Quem chegou NELA a trouxe junto;
## quem chegou a pé encontra o poço como a Cacau o deixou.
static func posicionar_cabine(elevador: ElevadorFase, no_telhado: bool) -> void:
	if elevador == null:
		return
	if elevador.chegou_com_passageira:
		elevador_no_telhado = no_telhado
	elevador.cabine_aqui = elevador_no_telhado == no_telhado


## Toda fase chama isto ao abrir (FaseBase): carregando a amostra, a cena
## ganha o relógio (e a Cacau, o cilindro nas costas).
static func instalar_na_fase(cena: Node) -> void:
	if not carregando_amostra() or cena == null:
		return
	if cena.get_node_or_null(ContagemDaAmostra.NOME) != null:
		return
	var contagem := ContagemDaAmostra.new()
	contagem.name = ContagemDaAmostra.NOME
	if cena.is_node_ready():
		cena.add_child(contagem)
	else:
		cena.add_child.call_deferred(contagem)


## DEBUG: esquece tudo (para os testes começarem do zero).
static func esquecer() -> void:
	cilindro_acoplado = false
	amostra = null
	amostra_na_coluna = false
	nitrogenio_destilado = false
	explicou_o_compressor = false
	explicou_a_destilacao = false
	subiu_a_torre = false
	elevador_no_telhado = true
	_maquina = null
