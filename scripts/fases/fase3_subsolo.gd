extends FaseBase

# --- FASE 3: SUBSOLO EM BLECAUTE — Fósforo + Enxofre (Mapa 4 do plano) ---
#
# BLECAUTE PERMANENTE: a rede elétrica do subsolo não volta. Não existe
# interruptor, setor religável nem "luz geral" — aqui embaixo, a luz é a que
# a personagem carrega: a LANTERNA DE FOCO (lanterna.gd), pega no armário de
# manutenção da chegada do fosso. Acesa ela drena a bateria; apagada, a
# bateria se recupera — o feixe é recurso, não farol.
#
# As SENTINELAS (sentinela.gd) moram no escuro: monstros que ANDAM, um por
# trecho do mapa, cada um espreitando parado até a personagem entrar no raio
# de perseguição. O feixe da lanterna congela quem ele alcançar — e SÓ o
# feixe: nenhuma luz ambiente conta.
#
#   FOSSO (chegada)  armário de manutenção com a lanterna + placa
#   ① ÁTRIO          o vão central entre as duas alas
#   ② ALA OESTE (P)  galpões escuros; gerador -> puzzle do ATP -> célula P
#   ③ ALA LESTE (S)  linha de borracha: masseira -> botas; o corredor
#                    eletrificado guarda a célula S na sala do fim
#
# COMO EDITAR NO EDITOR: o escuro é o nó Blecaute (CanvasModulate). O armário
# do fosso e as sentinelas são montados por código aqui embaixo — as posições
# ficam em POSICOES_SENTINELAS.

@onready var _mesa_gerador: MesaPuzzle = $AlaOeste/MesaGerador
@onready var _ponto_celula_p: Marker2D = $AlaOeste/PontoDaCelulaP
@onready var _ponto_celula_s: Marker2D = $AlaLeste/PontoDaCelulaS
@onready var _esteiras: Node2D = $AlaLeste/Esteiras


func _ready() -> void:
	super()

	# --- ALA OESTE: o gerador entrega a célula P (nenhuma luz religa) ---
	_mesa_gerador.resolvido.connect(_on_gerador_resolvido)
	if _mesa_gerador.ja_resolvida and not Progresso.tem_celula("P"):
		CelulaChonps.criar(self, _ponto_celula_p.global_position, "P")

	# --- ALA LESTE: esteiras acionadas pelo bumerangue ---
	for esteira in _esteiras.get_children():
		var alvo: AlvoBumerangue = esteira.get_node_or_null("Alvo")
		var bloco: BlocoAlternavel = esteira.get_node_or_null("Bloco")
		if alvo == null or bloco == null:
			continue
		bloco.definir_solido(alvo.ativo)
		alvo.mudou.connect(func(ativo: bool) -> void:
			if ativo:
				bloco.definir_solido(true))

	# --- CÉLULA S: sem disjuntores. A "fechadura" é o caminho até ela —
	# o corredor eletrificado (pede as botas da masseira) e as sentinelas
	# do trecho leste. A célula espera na sala do fim, no escuro. ---
	if not Progresso.tem_celula("S"):
		CelulaChonps.criar(self, _ponto_celula_s.global_position, "S")

	_montar_fosso_de_ventilacao()


func _on_gerador_resolvido() -> void:
	CelulaChonps.criar(self, _ponto_celula_p.global_position, "P")


# --- FOSSO DE VENTILAÇÃO: a lanterna e as Sentinelas do subsolo ---
#
# O fosso é por onde a personagem CHEGA (a porta no piso do hub cai na
# PortaFosso do átrio) — e foi do duto dele que as SENTINELAS se espalharam
# pelo subsolo. O armário de manutenção ao lado da porta guarda a LANTERNA
# DE FOCO: o feixe congela quem ele alcançar.
#
# Montado por código (mesmo padrão das portas do hub no laboratório) para não
# mexer no .tscn; quando a área ganhar forma final, migrar para a cena.

## Posições X das moradoras do subsolo (todas no chão, y=512) — uma por
## trecho, para cada caminhada ter o seu encontro. AJUSTE NO PLAYTEST:
## nenhuma perto da chegada (2450): o raio de perseguição delas (sentinela.gd)
## só acorda quem sai explorando. A da sala da célula S (5350) é o "chefe de
## porta": dá para congelá-la e passar, ou atravessar correndo no escuro.
const POSICOES_SENTINELAS: Array[float] = [700.0, 1350.0, 1950.0, 3250.0, 3800.0, 4350.0, 5350.0]

func _montar_fosso_de_ventilacao() -> void:
	var chao := 512.0
	var fosso := Node2D.new()
	fosso.name = "FossoVentilacao"

	# A boca do duto sobre a porta — a origem das sentinelas, na ambientação.
	Blockout.fundo(fosso, "BocaDoDuto", Rect2(2402, -448, 96, 560), Color(0.09, 0.10, 0.13), -3)

	# Armário de manutenção colado na chegada, com a única luz fixa do átrio.
	Blockout.fundo(fosso, "ArmarioManutencao", Rect2(2210, chao - 160, 120, 160), Color(0.26, 0.30, 0.38), -3)
	var luz_armario := Blockout.luz_radial(Color(1.0, 0.85, 0.5), 1.1, 0.9)
	luz_armario.name = "LuzArmarioManutencao"
	luz_armario.position = Vector2(2270, chao - 130)
	fosso.add_child(luz_armario)

	PickupHabilidade.criar(fosso, "PickupLanterna", Vector2(2270, chao - 80), {
		"habilidade": "lanterna",
		"rotulo": "LANTERNA DE FOCO",
		"mensagem": "Lanterna de foco na mão!\nR ou botão direito liga; o feixe aponta para o lado\nque você está olhando (L alterna para mira livre no\nmouse). CONGELA as sentinelas. Acesa drena a bateria;\napagada, a bateria se recupera.",
		"cor": Color(1.0, 0.9, 0.55),
	})

	Blockout.placa(fosso, "PlacaSentinelas", Vector2(2270, chao - 300),
		"SENTINELAS À SOLTA — só se movem no escuro, e só\nperseguem quem chega perto. O feixe da lanterna paralisa\nquem ele alcançar; quem ficou FORA do cone continua vindo.", 12)

	for i in POSICOES_SENTINELAS.size():
		# 30 px acima do chão: o corpo assenta sozinho no primeiro passo.
		Sentinela.criar(fosso, "Sentinela%d" % (i + 1),
			Vector2(POSICOES_SENTINELAS[i], chao - 30.0))

	Blockout.adicionar(self, fosso)
