extends FaseBase

# --- FASE 1: OFICINA DO CARBONO (Mapa 2 do plano) ---
#
# Fluxo horizontal, side-scroller:
#   ① ENTRADA    bancada do Dr. Chico — monta o BUMERANGUE. É aqui também que
#                fica o ELEVADOR DE CARGA (Entrada/ElevadorPatio): entre nele e
#                aperte E para subir ao PÁTIO, que é a fase1.2
#                (scenes/fases/fase1_2_exterior.tscn) — a parte de fora do
#                laboratório, onde a FORNALHA de carbonização passou a morar
#   ② TREINO     escola do arremesso — em construção manual no editor; só a
#                caixa elétrica AlvoFixo1 ficou de placeholder
#   ②b PORTÃO    no meio do mapa, uma BARREIRA fecha a passagem e só cai com os
#                DOIS painéis quebrados a bumerangue (PortaoPaineis) — sem
#                janela de tempo: pode ser um arremesso para cada
#   ②c SERRAS    logo depois, três serras elétricas no chão (Serras/) — a
#                CaixaSerra desliga as três de uma vez; ligação feita na cena,
#                no export "caixa_eletrica" de cada serra
#   ③ CORREDORES passagem até o depósito e, no meio dela, o ELEVADOR DE CARGA
#                (ElevadorCarga/): a plataforma espera no chão e o terminal ao
#                lado dela só a libera depois do PuzzleGuincho — converter a
#                MASSA da Cacau (balança, em kg) na FORÇA do peso dela (o
#                guincho, em N). É a plataforma do world1, mas acionada por
#                entender a máquina em vez de conversar com o cientista; a
#                ligação terminal -> plataforma é o export "alvo" do
#                TerminalGuincho
#   ④ DEPÓSITO   coleta de cascas de babaçu
#   ⑤ PÁTIO      no fim do mapa, a gaiola de vidro do MAÇARICO: balancear a
#                queima do acetileno em duas etapas (puzzle_macarico) destranca
#                a ferramenta que a fornalha lá de cima vai pedir
#
#                A FORNALHA NÃO MORA MAIS AQUI: a pirólise (encher de lenha ->
#                acender -> segurar a temperatura) virou o clímax da fase1.2,
#                lá fora, junto com as três toras. Queimar madeira é coisa de
#                área aberta, não de galpão fechado — e a lenha vai no
#                inventário, então ela sobe no elevador com a Cacau
#   ⑤b PORTA DE METAL  logo depois da gaiola, uma folha de aço fecha o resto do
#                pátio (Patio/PortaMetal). É o primeiro uso "livre" do maçarico
#                recém-ganho: E na porta, e ela esquenta, derrete e escorre até
#                virar poça. Sem a ferramenta, o E só devolve um aviso
#
# ARMADILHAS SEM CAIXA (ArmadilhasFixas/)
#
# Fora dos conjuntos acima, o mapa tem quatro serras no chão e duas fileiras de
# espinhos no TETO que NÃO têm caixa elétrica nenhuma: ficam ativas e matando do
# começo ao fim da fase, como obstáculo de pulo em vez de puzzle. O que decide
# isso é só o export "caixa_eletrica" de cada uma: VAZIO = nunca desliga. Não
# existe um componente separado para isso — é a mesma serra e o mesmo espinho
# das seções ②b e ②c, sem o fio ligado em lugar nenhum.
#
# OS ESPINHOS DE TETO são espinhos comuns com "scale = (1, -1)" no NÓ, não com
# o flip_v do sprite. A diferença importa: o flip_v viraria só a arte e o hitbox
# continuaria ACIMA da origem (a fileira nasce para cima, ver espinhos_laser.gd),
# então as pontas desenhadas para baixo machucariam no lugar errado. Virando o
# nó inteiro, arte, colisão e som descem juntos — e a origem, que no chão era a
# linha do piso, passa a ser a linha do TETO: encoste o nó na face de baixo do
# tile e as pontas nascem penduradas dela.
#
# Todas vivem sob o nó ArmadilhasFixas, então arrastar ESSE nó move o conjunto
# inteiro de uma vez; para mudar uma só, arraste ela dentro do grupo. Ctrl+D em
# qualquer uma cria outra igual, já sem caixa.
#
# Este script só liga os componentes uns nos outros. Mover, trocar sprites,
# repintar tiles ou acrescentar salas é tudo feito no editor, na cena.

## Barreira do meio do mapa e os dois painéis que a derrubam.
@onready var _painel_a: CaixaEletrica = $PortaoPaineis/PainelA
@onready var _painel_b: CaixaEletrica = $PortaoPaineis/PainelB
@onready var _barreira: Barreira = $PortaoPaineis/Barreira

## A barreira já caiu (nesta vida ou numa anterior). A própria barreira se
## lembra sozinha no _ready() dela; isto aqui é só para não mandar abrir de
## novo e repetir a animação.
var _barreira_aberta: bool = false


func _ready() -> void:
	super()

	# Os painéis guardam o próprio estado ("persistir"): quebrar um, morrer e
	# voltar não perde o progresso — a barreira continua esperando só o outro.
	_painel_a.mudou.connect(_ao_quebrar_painel)
	_painel_b.mudou.connect(_ao_quebrar_painel)
	_barreira_aberta = EstadoMundo.ja_feito(_barreira)
	_conferir_paineis()  # os dois já podiam estar quebrados de antes


func _process(_delta: float) -> void:
	# Atalho de teste: só existe com "Testar A Partir Daqui" ligado (ver
	# FaseBase), para não vazar num build de verdade.
	if testar_a_partir_daqui and Input.is_action_just_pressed("debug_coletar_tudo"):
		_debug_coletar_tudo()


# --- BARREIRA DOS DOIS PAINÉIS ---

func _ao_quebrar_painel(_ligado: bool) -> void:
	_conferir_paineis()


## A barreira só cai com os DOIS painéis quebrados. Como eles não desligam
## sozinhos, a ordem e o intervalo entre um arremesso e outro não importam.
##
## Olha o `ativo`, e NÃO o `quebrada`: o sinal "mudou" sai lá de dentro do
## atingir_bumerangue() da base, um passo ANTES de a CaixaEletrica marcar a
## tampa como arrebentada. Perguntando por `quebrada` aqui, o painel recém
## acertado ainda respondia "não" e a barreira nunca ouvia o segundo acerto.
func _conferir_paineis() -> void:
	if _barreira_aberta or not (_painel_a.ativo and _painel_b.ativo):
		return
	_barreira_aberta = true
	_barreira.abrir_passagem()


## M: recolhe de uma vez toda a madeira espalhada pela fase e destranca as duas
## ferramentas da oficina (maçarico oxídrico e bumerangue) — sem precisar
## visitar o depósito nem resolver as gaiolas de novo a cada teste.
func _debug_coletar_tudo() -> void:
	for tora in get_tree().get_nodes_in_group(Madeira.GRUPO):
		if tora is Madeira:
			tora.coletar()

	var liberadas := PackedStringArray()
	if _debug_liberar("macarico", "Patio/GaiolaMacarico", "Patio/PickupMacarico"):
		liberadas.append("maçarico")
	if _debug_liberar("bumerangue", "Entrada/GaiolaBumerangue", "Entrada/PickupBumerangue"):
		liberadas.append("bumerangue")

	var texto := "[TESTE] Madeira recolhida."
	if not liberadas.is_empty():
		texto = "[TESTE] Madeira recolhida e %s liberado(s)." % ", ".join(liberadas)
	Blockout.aviso_flutuante(self, player.global_position + Vector2(0, -120),
		texto, Color(0.6, 0.9, 1.0))


## Dá a habilidade e limpa a gaiola/pickup correspondentes.
## Devolve true se a habilidade ainda não tinha sido pega.
func _debug_liberar(habilidade: String, caminho_gaiola: String, caminho_pickup: String) -> bool:
	var era_nova := not Progresso.tem_habilidade(habilidade)
	if era_nova:
		Progresso.dar_habilidade(habilidade)

	# A gaiola e o pickup somem mesmo se a habilidade já existia: numa volta à
	# fase eles reaparecem na cena e ficariam ali de enfeite.
	var gaiola := get_node_or_null(caminho_gaiola)
	if gaiola:
		gaiola.queue_free()
	var pickup := get_node_or_null(caminho_pickup)
	if pickup:
		pickup.queue_free()
	return era_nova
