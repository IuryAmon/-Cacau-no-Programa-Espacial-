extends Node

# Teste do que a fase 1 LEMBRA quando a Cacau morre (a cena recarrega) e quando
# ela sai e volta. Roda na Oficina do Carbono de verdade, com mortes de verdade
# (o mesmo _reiniciar_cena_seguro() do player), e nos corredores dos morcegos.
#
#   godot --headless --fixed-fps 60 --path . res://tools/teste_estado_da_fase1.tscn
#
# A REGRA: morrer nunca desfaz progresso. O que a Cacau quebrou, desligou,
# abriu, derreteu, comeu ou pegou continua assim na fase recarregada; só o
# que é desafio de reflexo recomeça.
#
# Casos:
#   * a fase nasce inteira: espinhos de pé, caixas fechadas, torretas vivas;
#   * depois da bandeira, ela desliga os espinhos da caixa, quebra as quatro
#     torretas, desliga as serras, derruba a barreira, abre os dois domos, pega
#     as duas ferramentas, derrete as portas, resolve o guincho e come as maçãs
#     — e MORRE: renasce na bandeira com tudo isso do jeito que deixou;
#   * a caixa de janela (AlvoFixo1) volta com a tampa arrebentada, e os
#     espinhos dela não sobem de novo quando a janela expira;
#   * o objetivo "Desative os espinhos" e a armadilha nunca discordam;
#   * morrer de novo não muda nada, e sair da fase e voltar também não;
#   * a etapa 1 do puzzle do maçarico não se perde numa morte;
#   * o que recomeça DE PROPÓSITO: a vida cheia, a plataforma de viagem parada
#     no começo e a caixa de empurrar no lugar dela;
#   * a ordem dos nós não importa: espinhos que vêm ANTES da caixa na árvore
#     nascem recolhidos do mesmo jeito; a passagem cronometrada volta de pé;
#   * alvo e torreta lembram por padrão (o "persistir" vem ligado);
#   * os morcegos dos corredores: o morto continua morto e o ferido continua
#     ferido enquanto ela não sai do corredor; na visita seguinte, o bando
#     volta inteiro.

const FASE := "res://scenes/fases/fase1_oficina.tscn"
const CORREDOR := "res://scenes/fases/corredor_patio.tscn"
const LAB := "res://scenes/laboratório_(world_2).tscn"
const CAIXA_ELETRICA := "res://scenes/fases/componentes/caixa_eletrica.tscn"
const ESPINHOS := "res://scenes/fases/componentes/espinhos_laser.tscn"
const TORRETA := "res://scenes/fases/componentes/torreta_laser.tscn"
const PUZZLE_MACARICO := "res://scenes/puzzle_macarico.tscn"

const RADIO := "/root/Fase1Oficina/Entrada/RadioDrChico"
const TORRETAS := ["Torretas/TorretaMeio", "Torretas/TorretaMeio2", "Torretas/TorretaMeio3", "Torretas/TorretaMeio4"]
const SERRAS := ["Serras/Serra4", "Serras/Serra5", "Serras/Serra6", "Serras/Serra7"]
const SERRAS_FIXAS := ["ArmadilhasFixas/SerraFixa1", "ArmadilhasFixas/EspinhosTeto1"]
const CESTAS := ["CestaMacas", "CestaMacas2", "CestaMacas3"]
const GAIOLAS := {
	"bumerangue": ["Entrada/GaiolaBumerangue", "Entrada/PickupBumerangue"],
	"macarico": ["Patio/GaiolaMacarico", "Patio/PickupMacarico"],
}

var _falhas := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# O teste sai de cena: as trocas e recargas de cena de verdade não o apagam.
	get_tree().current_scene = null
	await _rodar()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _rodar() -> void:
	_zerar()
	await _testar_fase_inteira()
	await _testar_progresso_do_puzzle()
	await _testar_ordem_dos_nos()
	await _testar_padroes()
	await _testar_morcegos()


# ─────────────────────────────────────────────────────────────
# A FASE 1, DE PONTA A PONTA
# ─────────────────────────────────────────────────────────────

func _testar_fase_inteira() -> void:
	print("\n--- A FASE NASCE INTEIRA ---")
	var fase := await _abrir(FASE)
	var caixa_do_treino := fase.get_node("Treino/AlvoFixo1") as CaixaEletrica
	var espinhos := fase.get_node("Treino/EspinhosCaixa") as EspinhosLaser
	_checar(espinhos.perigoso, "os espinhos da caixa nascem de pé")
	_checar(not caixa_do_treino.quebrada, "a caixa que os alimenta nasce fechada")
	for caminho: String in TORRETAS:
		_checar(not (fase.get_node(caminho) as TorretaLaser).quebrada, "%s nasce inteira" % caminho)
	for caminho: String in SERRAS:
		_checar((fase.get_node(caminho) as EspinhosLaser).perigoso, "%s nasce girando" % caminho)
	_checar(not _barreira_aberta(fase), "a barreira dos dois painéis nasce fechada")
	for nome: String in GAIOLAS:
		_checar(not fase.get_node(GAIOLAS[nome][0]).puzzle_concluido, "o domo do %s nasce trancado" % nome)
	_checar(not (fase.get_node("ElevadorCarga/TerminalGuincho") as ComputadorPuzzle)._resolvido,
		"o terminal do guincho nasce trancado")
	for caminho: String in CESTAS:
		_checar(not (fase.get_node(caminho) as CestaMacas).esta_vazia(), "%s nasce cheia" % caminho)
	var lugar_da_caixa: Vector2 = (fase.get_node("Caixa") as Node2D).global_position

	print("\n--- ELA PASSA PELA BANDEIRA E RESOLVE A FASE ---")
	var bandeira := fase.get_node("Checkpoint") as Checkpoint
	bandeira.ativar()
	var renasce_em := bandeira.global_position + Vector2(0, -bandeira.altura_do_respawn)
	await _resolver_tudo(fase)
	_checar(not espinhos.perigoso, "acertar a caixa recolhe os espinhos")
	(fase.get_node("Caixa") as Caixa).global_position += Vector2(160, 0)
	_player(fase).current_health = 1

	print("\n--- ELA MORRE: NADA VOLTA ATRÁS ---")
	fase = await _morrer(fase)
	_perto(_player(fase).global_position, renasce_em, "ela renasce na bandeira")
	_checar((fase.get_node("Checkpoint") as Checkpoint).ativada, "a bandeira continua tremulando")
	await _conferir_tudo_resolvido(fase, "depois da morte")

	# A caixa do treino é de JANELA (2 s): ela volta desligada, e os espinhos
	# não podem subir quando esse tempo passa — nem ouvir um "desligou" que
	# nunca aconteceu nesta vida.
	espinhos = fase.get_node("Treino/EspinhosCaixa") as EspinhosLaser
	await _esperar(3.0)
	_checar(not espinhos.perigoso, "os espinhos continuam recolhidos depois que a janela da caixa passa")
	_checar(espinhos._travado, "e travados: outro acerto na caixa não os religa nem recolhe de novo")
	(fase.get_node("Treino/AlvoFixo1") as CaixaEletrica).atingir_bumerangue()
	await _esperar(3.0)
	_checar(not espinhos.perigoso, "acertar a caixa de novo e esperar a janela também não os religa")

	print("\n--- O QUE RECOMEÇA DE PROPÓSITO ---")
	var player := _player(fase)
	_checar(player.current_health == player.max_health, "ela renasce com a vida cheia")
	for nome: String in ["PlataformaDeViagem", "PlataformaDeViagem2"]:
		var viagem := fase.get_node(nome) as PlataformaDeViagem
		_checar(viagem.estado == PlataformaDeViagem.Estado.ESPERANDO, "%s volta parada no começo" % nome)
	# Volta para onde foi posta na cena (empurrada 160 px antes da morte). Ela pode
	# estar posta um pouco acima do chão: aí cai até ele, e só a altura muda.
	var caixa_agora: Vector2 = (fase.get_node("Caixa") as Node2D).global_position
	_checar(absf(caixa_agora.x - lugar_da_caixa.x) <= 2.0 and absf(caixa_agora.y - lugar_da_caixa.y) <= 40.0,
		"a caixa de empurrar volta para o lugar dela (%s vs %s)" % [caixa_agora, lugar_da_caixa])
	for caminho: String in SERRAS_FIXAS:
		_checar((fase.get_node(caminho) as EspinhosLaser).perigoso,
			"%s (sem caixa elétrica) continua ligada" % caminho)

	print("\n--- MORRER DE NOVO, E SAIR E VOLTAR ---")
	fase = await _morrer(fase)
	await _conferir_tudo_resolvido(fase, "depois da segunda morte")
	await _abrir(LAB)
	fase = await _abrir(FASE)
	await _conferir_tudo_resolvido(fase, "saindo da fase e voltando")
	_checar(not (fase.get_node("Checkpoint") as Checkpoint).ativada,
		"a bandeira é a única que recomeça com a visita (o ponto de retorno é da visita)")


## Faz tudo o que a jogadora faz na fase, pelos mesmos métodos que o bumerangue
## e a tecla E chamam.
func _resolver_tudo(fase: Node) -> void:
	(fase.get_node("Treino/AlvoFixo1") as CaixaEletrica).atingir_bumerangue()
	for caminho: String in TORRETAS:
		(fase.get_node(caminho + "/Base/AreaAlvo") as HitboxBumerangue).atingir_bumerangue()
	(fase.get_node("Serras/CaixaSerra") as CaixaEletrica).atingir_bumerangue()
	(fase.get_node("PortaoPaineis/PainelA") as CaixaEletrica).atingir_bumerangue()
	(fase.get_node("PortaoPaineis/PainelB") as CaixaEletrica).atingir_bumerangue()
	for nome: String in GAIOLAS:
		fase.get_node(GAIOLAS[nome][0])._on_puzzle_resolvido()
		Progresso.dar_habilidade(nome)
		fase.get_node(GAIOLAS[nome][1]).queue_free()
	(fase.get_node("ElevadorCarga/TerminalGuincho") as ComputadorPuzzle)._ao_resolver()
	for caminho: String in CESTAS:
		(fase.get_node(caminho) as CestaMacas).comer()
	# A porta anota que derreteu no primeiro instante do corte: morrer no meio
	# da animação já a encontra no chão.
	(fase.get_node("Patio/PortaMetal") as PortaMetalMacarico)._derreter()
	(fase.get_node("Patio/PortaMetal2") as PortaMetalMacarico)._derreter()
	await _esperar(0.5)


func _conferir_tudo_resolvido(fase: Node, quando: String) -> void:
	await _quadros(4)
	var espinhos := fase.get_node("Treino/EspinhosCaixa") as EspinhosLaser
	var caixa_do_treino := fase.get_node("Treino/AlvoFixo1") as CaixaEletrica
	_checar(not espinhos.perigoso and espinhos._recolhido, "%s: os espinhos da caixa continuam recolhidos" % quando)
	_checar(caixa_do_treino.quebrada, "%s: a caixa deles continua arrebentada" % quando)
	_checar(not caixa_do_treino.ativo, "%s: ... e desligada, que a janela dela já passou" % quando)
	_checar(EstadoMundo.ja_feito_caminho(RoteiroObjetivos.ESPINHOS_TREINO) == (not espinhos.perigoso),
		"%s: o objetivo dos espinhos e a armadilha dizem a mesma coisa" % quando)
	for caminho: String in TORRETAS:
		var torreta := fase.get_node(caminho) as TorretaLaser
		_checar(torreta.quebrada, "%s: %s continua estragada" % [quando, caminho])
	var caixa_da_serra := fase.get_node("Serras/CaixaSerra") as CaixaEletrica
	_checar(caixa_da_serra.quebrada and caixa_da_serra.ativo, "%s: a caixa das serras continua arrebentada" % quando)
	for caminho: String in SERRAS:
		_checar(not (fase.get_node(caminho) as EspinhosLaser).perigoso, "%s: %s continua parada" % [quando, caminho])
	_checar(_barreira_aberta(fase), "%s: a barreira dos painéis continua aberta" % quando)
	for nome: String in GAIOLAS:
		var gaiola := fase.get_node(GAIOLAS[nome][0])
		_checar(gaiola.puzzle_concluido and gaiola.gaiola_anim.animation == &"aberta",
			"%s: o domo do %s continua aberto" % [quando, nome])
		_checar(_sumiu(fase.get_node_or_null(GAIOLAS[nome][1])), "%s: o %s não volta para o domo" % [quando, nome])
		_checar(Progresso.tem_habilidade(nome), "%s: ela continua com o %s" % [quando, nome])
	for nome: String in ["Patio/PortaMetal", "Patio/PortaMetal2"]:
		var porta := fase.get_node(nome) as PortaMetalMacarico
		_checar(porta._estado == PortaMetalMacarico.Estado.ABERTA, "%s: %s continua derretida" % [quando, nome])
	var terminal := fase.get_node("ElevadorCarga/TerminalGuincho") as ComputadorPuzzle
	_checar(terminal._resolvido, "%s: o terminal do guincho continua resolvido" % quando)
	_checar(fase.get_node("ElevadorCarga/PlataformaCarga").ativa, "%s: e o elevador de carga volta a andar sozinho" % quando)
	for caminho: String in CESTAS:
		_checar((fase.get_node(caminho) as CestaMacas).esta_vazia(), "%s: %s continua vazia" % [quando, caminho])


func _barreira_aberta(fase: Node) -> bool:
	var barreira := fase.get_node("PortaoPaineis/Barreira") as Barreira
	return barreira.colisor.disabled


# ─────────────────────────────────────────────────────────────
# O PUZZLE DO MAÇARICO PELA METADE
# ─────────────────────────────────────────────────────────────

func _testar_progresso_do_puzzle() -> void:
	print("\n--- A ETAPA 1 DO MAÇARICO NÃO SE PERDE ---")
	_zerar()
	var fase := await _abrir(FASE)
	var puzzle := fase.get_node("Patio/GaiolaMacarico").puzzle_ui as CanvasLayer
	puzzle.abrir_puzzle()
	await _quadros(3)
	_checar(puzzle.etapa == 0, "o puzzle abre na etapa 1")
	puzzle.coeficientes.assign([1, 1, 2, 1])
	puzzle.tocado.assign([true, true, true, true])
	puzzle._confirmar()
	await _esperar(0.4)
	_checar(puzzle._etapa_liberada == 1, "balancear a etapa 1 libera a etapa 2")
	puzzle.fechar_puzzle(false)
	await _quadros(2)

	fase = await _morrer(fase)
	puzzle = fase.get_node("Patio/GaiolaMacarico").puzzle_ui as CanvasLayer
	_checar(puzzle._etapa_liberada == 1, "depois da morte o puzzle continua na etapa 2")
	puzzle.abrir_puzzle()
	await _quadros(3)
	_checar(puzzle.etapa == 1, "e reabre nela")
	_checar(puzzle.resumo.visible, "com a etapa 1 resolvida escrita no alto")
	puzzle.fechar_puzzle(false)
	await _quadros(2)

	# Um puzzle solto (fora de uma gaiola) não herda nada de ninguém.
	var solto := (load(PUZZLE_MACARICO) as PackedScene).instantiate() as CanvasLayer
	add_child(solto)
	await _quadros(2)
	_checar(solto._etapa_liberada == 0, "um puzzle novo, fora da gaiola, começa da etapa 1")
	solto.queue_free()
	await _quadros(2)

	print("\n--- O ÁTOMO DE CARBONO PELA METADE TAMBÉM NÃO ---")
	var montado := {"protons": 3, "neutrons": 2, "camada_k": 1, "camada_l": 2}
	var atomo := fase.get_node("Entrada/GaiolaBumerangue").puzzle_ui as CanvasLayer
	atomo.abrir_puzzle()
	await _quadros(3)
	for qual: String in montado:
		for i in int(montado[qual]):
			atomo.alterar(qual, 1)
	await _quadros(2)
	_checar(_contas_do_atomo(atomo) == montado, "ela monta o átomo pela metade")
	atomo.fechar_puzzle(false)
	await _quadros(2)

	fase = await _morrer(fase)
	atomo = fase.get_node("Entrada/GaiolaBumerangue").puzzle_ui as CanvasLayer
	_checar(_contas_do_atomo(atomo) == {"protons": 0, "neutrons": 0, "camada_k": 0, "camada_l": 0},
		"depois da morte o puzzle novo ainda está fechado e vazio")
	atomo.abrir_puzzle()
	await _esperar(0.6)
	_checar(_contas_do_atomo(atomo) == montado, "ao abrir, as partículas voltam para o átomo")
	_checar(not atomo.travado and not atomo.aguardando_fechamento, "e o puzzle continua aberto, sem concluir")
	_checar((atomo.particulas as Node).get_child_count() == 8, "nenhuma partícula sobrando ou faltando na tela (8)")
	atomo.alterar("protons", -1)
	await _quadros(2)
	atomo.fechar_puzzle(false)
	await _quadros(2)
	fase = await _morrer(fase)
	atomo = fase.get_node("Entrada/GaiolaBumerangue").puzzle_ui as CanvasLayer
	atomo.abrir_puzzle()
	await _esperar(0.6)
	montado["protons"] = 2
	_checar(_contas_do_atomo(atomo) == montado, "tirar uma partícula também fica anotado")
	atomo.fechar_puzzle(false)
	await _quadros(2)


func _contas_do_atomo(puzzle: CanvasLayer) -> Dictionary:
	var contas := {}
	for qual: String in ["protons", "neutrons", "camada_k", "camada_l"]:
		contas[qual] = puzzle.quantas(qual)
	return contas


# ─────────────────────────────────────────────────────────────
# A ORDEM DOS NÓS E A PASSAGEM CRONOMETRADA
# ─────────────────────────────────────────────────────────────

func _testar_ordem_dos_nos() -> void:
	print("\n--- A ORDEM DOS NÓS NÃO IMPORTA ---")
	_zerar()
	# Espinhos ANTES da caixa na árvore: quando eles acordam, a caixa ainda não
	# rodou o _ready() dela.
	var sala := await _montar_sala("SalaAoContrario", true, {}, {})
	var espinhos := sala.get_node("Espinhos") as EspinhosLaser
	var caixa := sala.get_node("Caixa") as CaixaEletrica
	_checar(espinhos.perigoso, "sala nova: os espinhos nascem de pé")
	caixa.atingir_bumerangue()
	await _quadros(2)
	_checar(not espinhos.perigoso, "o acerto na caixa recolhe")
	sala.free()
	sala = await _montar_sala("SalaAoContrario", true, {}, {})
	espinhos = sala.get_node("Espinhos") as EspinhosLaser
	_checar(not espinhos.perigoso and espinhos._recolhido,
		"remontada com os espinhos antes da caixa, eles nascem recolhidos")
	_checar((sala.get_node("Caixa") as CaixaEletrica).quebrada, "e a caixa, arrebentada")
	sala.free()

	# Mesmo que os espinhos tivessem esquecido (a anotação é deles), a caixa
	# que acorda depois avisa.
	EstadoMundo._feitos.erase(str(get_path()) + "/SalaAoContrario/Espinhos")
	sala = await _montar_sala("SalaAoContrario", true, {}, {})
	espinhos = sala.get_node("Espinhos") as EspinhosLaser
	_checar(not espinhos.perigoso and espinhos._recolhido,
		"sem a anotação deles, a caixa que acorda depois ainda os recolhe")
	sala.free()

	print("\n--- A PASSAGEM CRONOMETRADA VOLTA DE PÉ ---")
	# Caixa de janela + espinhos que religam: a cada vida a passagem recomeça
	# fechada, mesmo com a tampa da caixa já arrebentada.
	var janela := {"permanece_ativo": false, "janela": 0.3}
	var religam := {"desligar_para_sempre": false}
	sala = await _montar_sala("SalaCronometrada", false, janela, religam)
	espinhos = sala.get_node("Espinhos") as EspinhosLaser
	caixa = sala.get_node("Caixa") as CaixaEletrica
	caixa.atingir_bumerangue()
	await _quadros(2)
	_checar(not espinhos.perigoso, "o acerto abre a passagem")
	await _esperar(1.6)
	_checar(espinhos.perigoso, "e a janela fechando a fecha de novo")
	sala.free()
	sala = await _montar_sala("SalaCronometrada", false, janela, religam)
	espinhos = sala.get_node("Espinhos") as EspinhosLaser
	caixa = sala.get_node("Caixa") as CaixaEletrica
	_checar(espinhos.perigoso, "remontada, a passagem cronometrada nasce fechada")
	_checar(caixa.quebrada and not caixa.ativo, "com a caixa arrebentada e desligada")
	caixa.atingir_bumerangue()
	await _quadros(2)
	_checar(not espinhos.perigoso, "e o acerto volta a abri-la")
	sala.free()
	await _quadros(2)


## Uma salinha de teste: uma caixa elétrica e os espinhos que ela alimenta.
func _montar_sala(nome: String, espinhos_antes: bool, da_caixa: Dictionary, dos_espinhos: Dictionary) -> Node2D:
	var sala := Node2D.new()
	sala.name = nome
	var caixa := (load(CAIXA_ELETRICA) as PackedScene).instantiate() as CaixaEletrica
	caixa.name = "Caixa"
	for chave: String in da_caixa:
		caixa.set(chave, da_caixa[chave])
	var espinhos := (load(ESPINHOS) as PackedScene).instantiate() as EspinhosLaser
	espinhos.name = "Espinhos"
	espinhos.position = Vector2(0, 200)
	espinhos.caixa_eletrica = NodePath("../Caixa")
	for chave: String in dos_espinhos:
		espinhos.set(chave, dos_espinhos[chave])
	if espinhos_antes:
		sala.add_child(espinhos)
		sala.add_child(caixa)
	else:
		sala.add_child(caixa)
		sala.add_child(espinhos)
	sala.position = Vector2(-9000, -9000)
	add_child(sala)
	await _quadros(3)
	return sala


# ─────────────────────────────────────────────────────────────
# OS PADRÕES DOS COMPONENTES
# ─────────────────────────────────────────────────────────────

func _testar_padroes() -> void:
	print("\n--- LEMBRAR É O PADRÃO ---")
	_zerar()
	var caixa := (load(CAIXA_ELETRICA) as PackedScene).instantiate() as CaixaEletrica
	_checar(caixa.persistir, "caixa elétrica nova já vem com \"persistir\" ligado")
	caixa.free()
	var torreta := (load(TORRETA) as PackedScene).instantiate() as TorretaLaser
	_checar(torreta.persistir, "torreta nova já vem com \"persistir\" ligado")
	_checar(not torreta.quebravel, "e continua imortal por padrão (\"quebravel\" desligado)")
	torreta.free()

	# Nenhuma caixa e nenhuma torreta quebrável da fase 1 tem o "persistir"
	# desligado na cena.
	var estado := (load(FASE) as PackedScene).get_state()
	for i in estado.get_node_count():
		for p in estado.get_node_property_count(i):
			if estado.get_node_property_name(i, p) == "persistir":
				_checar(bool(estado.get_node_property_value(i, p)),
					"%s não desliga o \"persistir\" na cena da fase 1" % estado.get_node_name(i))

	# Torreta quebrável solta: estragada, continua estragada quando remontada.
	var solta := await _montar_torreta()
	(solta.get_node("Base/AreaAlvo") as HitboxBumerangue).atingir_bumerangue()
	await _quadros(2)
	_checar(solta.quebrada, "o acerto estraga a torreta quebrável")
	solta.free()
	solta = await _montar_torreta()
	_checar(solta.quebrada, "remontada, ela nasce estragada")
	_checar((solta.get_node("Base/Fumaca") as CPUParticles2D).emitting, "e fumegando")
	solta.free()
	await _quadros(2)


func _montar_torreta() -> TorretaLaser:
	var torreta := (load(TORRETA) as PackedScene).instantiate() as TorretaLaser
	torreta.name = "TorretaSolta"
	torreta.quebravel = true
	torreta.position = Vector2(-9000, -8000)
	add_child(torreta)
	await _quadros(3)
	return torreta


# ─────────────────────────────────────────────────────────────
# OS MORCEGOS DOS CORREDORES
# ─────────────────────────────────────────────────────────────

func _testar_morcegos() -> void:
	print("\n--- OS MORCEGOS DO CORREDOR ---")
	_zerar()
	var corredor := await _abrir(CORREDOR)
	var ferido := corredor.get_node("Morcegos/Morcego1") as Morcego
	var morto := corredor.get_node("Morcegos/Morcego2") as Morcego
	_checar(ferido.vida_restante() == ferido.vida and morto.vida_restante() == morto.vida,
		"o bando nasce com a vida cheia")
	var cheia := ferido.vida
	ferido.levar_golpe(Vector2.RIGHT, 0.0)
	for i in morto.vida:
		morto._imune = 0.0
		morto.levar_golpe(Vector2.RIGHT, 0.0)
	_checar(ferido.vida_restante() == cheia - 1, "um golpe tira uma vida do primeiro")
	_checar(morto.vida_restante() == 0, "e o segundo morre")

	corredor = await _morrer(corredor)
	ferido = corredor.get_node_or_null("Morcegos/Morcego1") as Morcego
	_checar(ferido != null and ferido.vida_restante() == cheia - 1,
		"ela morre: o morcego ferido continua ferido")
	_checar(_sumiu(corredor.get_node_or_null("Morcegos/Morcego2")), "e o morto continua morto")

	corredor = await _morrer(corredor)
	ferido = corredor.get_node_or_null("Morcegos/Morcego1") as Morcego
	_checar(ferido != null and ferido.vida_restante() == cheia - 1 \
		and _sumiu(corredor.get_node_or_null("Morcegos/Morcego2")), "morrer de novo não muda nada")

	await _abrir(LAB)
	corredor = await _abrir(CORREDOR)
	ferido = corredor.get_node_or_null("Morcegos/Morcego1") as Morcego
	morto = corredor.get_node_or_null("Morcegos/Morcego2") as Morcego
	_checar(ferido != null and morto != null and not _sumiu(morto), "na visita seguinte o bando está inteiro")
	_checar(ferido != null and ferido.vida_restante() == cheia, "e com a vida cheia de novo")


# ─────────────────────────────────────────────────────────────
# APOIO
# ─────────────────────────────────────────────────────────────

## Tudo o que o jogo lembra volta ao zero.
func _zerar() -> void:
	EstadoMundo._feitos.clear()
	EstadoMundo._valores.clear()
	EstadoMundo.esquecer_a_visita()
	EstadoMundo.revelou_dr_chico = true
	# O rádio da entrada já falou: a conversa dele não é o assunto aqui.
	EstadoMundo._feitos[RADIO] = true
	Progresso._habilidades.clear()
	PontoDeRetorno.esquecer()


func _abrir(caminho: String) -> Node:
	get_tree().change_scene_to_file(caminho)
	return await _cena_pronta(caminho)


## Morre de verdade: a mesma recarga que o player pede ao zerar a vida.
func _morrer(cena: Node) -> Node:
	var caminho := cena.scene_file_path
	_player(cena)._reiniciar_cena_seguro()
	# A cena antiga sai no fim do quadro; só depois disso a nova é a "atual".
	await _quadros(2)
	return await _cena_pronta(caminho)


func _cena_pronta(caminho: String) -> Node:
	for i in 600:
		var cena := get_tree().current_scene
		if cena != null and cena.scene_file_path == caminho and cena.is_node_ready():
			break
		await get_tree().process_frame
	await _quadros(3)
	var chegou := get_tree().current_scene
	_estacionar(_player(chegou))
	return chegou


func _player(cena: Node) -> CharacterBody2D:
	return cena.get_node("Player") as CharacterBody2D


## A Cacau fica onde a fase a pôs, sem física e sem corpo: o teste não depende
## de onde o nó Player está salvo na cena, nem de uma armadilha por perto.
func _estacionar(player: CharacterBody2D) -> void:
	if player == null:
		return
	player.set_physics_process(false)
	var forma := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if forma:
		forma.set_deferred("disabled", true)


func _sumiu(no: Node) -> bool:
	return no == null or not is_instance_valid(no) or no.is_queued_for_deletion()


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Espera em tempo de JOGO (o relógio que as janelas e as animações usam).
func _esperar(segundos: float) -> void:
	var passou := 0.0
	while passou < segundos:
		await get_tree().process_frame
		passou += get_process_delta_time()


func _perto(a: Vector2, b: Vector2, nome: String, tolerancia: float = 1.0) -> void:
	_checar(a.distance_to(b) <= tolerancia, "%s (%s vs %s)" % [nome, a, b])


func _checar(ok: bool, nome: String) -> void:
	print(("  ok    " if ok else "  FALHA ") + nome)
	if not ok:
		_falhas += 1
