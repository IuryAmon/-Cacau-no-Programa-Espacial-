extends TelaInterativa

# --- MONTE SEU ÁTOMO (Laboratório) ---
#
# O puzzle do bumerangue pede o carbono; aqui a pessoa monta o átomo que
# quiser. São três seletores, com as mesmas setas do puzzle
# (scenes/ui/seletor_particula.tscn): prótons, nêutrons e elétrons. A cada
# partícula que entra ou sai, a tela responde NA HORA:
#
#   QUE ÁTOMO É    quem diz é o número de prótons. A caixa do elemento (a da
#                  tabela periódica) e o nome trocam no mesmo instante:
#                  "CARBONO-12" é o carbono com 12 partículas no núcleo.
#   Z              número atômico: os prótons.
#   A              número de massa: prótons mais nêutrons.
#   CARGA          prótons menos elétrons. Zero é o átomo neutro; sobrando
#                  próton é cátion (+), sobrando elétron é ânion (-).
#   O SÍMBOLO      escrito como nos livros, com A, Z e a carga em volta
#                  (scripts/ui/notacao_do_atomo.gd).
#   NA NATUREZA    de cada 100 átomos desse elemento, quantos têm esse tanto de
#                  nêutrons (Elementos.abundancia). Isótopo que não aparece lá
#                  é instável.
#   SEM PRÓTONS    não há elemento, por mais nêutrons e elétrons que haja: a
#                  caixa fica em branco e o quadro ao lado dela explica.
#
# O desenho é o do AtomoCamadas: os elétrons vão sozinhos para a camada certa,
# inclusive nos íons (ver Elementos.camadas_com).
#
# Não há resposta certa nem errada: é um brinquedo. Os limites são os da
# natureza conhecida (118 prótons, 177 nêutrons, 118 elétrons), e o rodapé
# explica cada um quando a pessoa bate nele.
#
# ONDE MEXER:
#   as constantes logo abaixo            os limites e o que o rodapé diz.
#   scenes/laboratorio/monte_seu_atomo.tscn
#                                        a tela: posições, letras e cores. As
#                                        peças ficam dentro de
#                                        Painel/Display/Conteudo.
#
# CONTROLES: mouse nas setas (segurando, a seta repete cada vez mais rápido);
# a roda do mouse em cima de um seletor também põe e tira; ESC volta.
# No controle: o analógico leva o cursor, o direcional pula de seta em seta,
# ✕ aperta (segurando, repete) e △ volta.

const MAXIMO_DE_PROTONS := Elementos.TOTAL
## O núcleo mais pesado já observado (o do tennesso-294 e o do livermório-293).
const MAXIMO_DE_NEUTRONS := 177
const MAXIMO_DE_ELETRONS := Elementos.TOTAL

const TXT_INSTRUCAO := "USE AS SETAS PARA PÔR E TIRAR PARTÍCULAS (SEGURE PARA IR MAIS DEPRESSA)"
const TXT_ELEMENTO := "%d %s: %s"
const TXT_PROTONS_DEMAIS := "O MAIOR ELEMENTO CONHECIDO, O OGANESSÔNIO, TEM 118 PRÓTONS"
const TXT_NEUTRONS_DEMAIS := "O NÚCLEO MAIS PESADO JÁ OBSERVADO TEM 177 NÊUTRONS"
const TXT_ELETRONS_DEMAIS := "AS SETE CAMADAS COMPORTAM, JUNTAS, 118 ELÉTRONS"
const TXT_VAZIO := "MONTE UM ÁTOMO"
const TXT_SEM_PROTONS := "NENHUM ELEMENTO"
## O que o quadro ao lado da caixa explica enquanto há partículas sem próton.
const TXT_EXPLICA_SEM_PROTONS := "SEM PRÓTONS NÃO HÁ ELEMENTO: É O NÚMERO DELES QUE DIZ QUAL É"
const TXT_NEUTRO := "ÁTOMO NEUTRO"
const TXT_CATION := "CÁTION"
const TXT_ANION := "ÂNION"
const TXT_TODOS_ASSIM := "NA NATUREZA, TODOS OS ÁTOMOS DE %s SÃO ASSIM"
const TXT_PARTE_ASSIM := "NA NATUREZA, %s%% DOS ÁTOMOS DE %s SÃO ASSIM"
const TXT_INSTAVEL := "ISÓTOPO INSTÁVEL: UM NÚCLEO ASSIM NÃO DURA"
const TXT_APELIDO := "É O %s. "

## Os três seletores: a partícula de cada um e até quanto ela vai.
const SELETORES := {
	"protons": {"maximo": MAXIMO_DE_PROTONS, "demais": TXT_PROTONS_DEMAIS},
	"neutrons": {"maximo": MAXIMO_DE_NEUTRONS, "demais": TXT_NEUTRONS_DEMAIS},
	"eletrons": {"maximo": MAXIMO_DE_ELETRONS, "demais": TXT_ELETRONS_DEMAIS},
}

var protons: int = 0
var neutrons: int = 0
var eletrons: int = 0

@onready var painel: PainelDaAtividade = $Painel
@onready var atomo: AtomoCamadas = $Painel/Display/Conteudo/Atomo
@onready var caixa: CaixaElemento = $Painel/Display/Conteudo/Caixa
@onready var nome: Label = $Painel/Display/Conteudo/Nome
@onready var notacao: NotacaoDoAtomo = $Painel/Display/Conteudo/Notacao
@onready var na_natureza: Label = $Painel/Display/Conteudo/NaNatureza
@onready var numero_atomico: Label = $Painel/Display/Conteudo/Propriedades/NumeroAtomico
@onready var numero_de_massa: Label = $Painel/Display/Conteudo/Propriedades/NumeroDeMassa
@onready var carga: Label = $Painel/Display/Conteudo/Propriedades/Carga
@onready var legenda_da_carga: Label = $Painel/Display/Conteudo/Propriedades/LegendaCarga
@onready var botao_limpar: Panel = $Painel/Display/Conteudo/BotaoLimpar
## Os seletores da tela, com os nomes dos SELETORES.
@onready var seletores := {
	"protons": $Painel/Display/Conteudo/Seletores/SeletorProtons as SeletorParticula,
	"neutrons": $Painel/Display/Conteudo/Seletores/SeletorNeutrons as SeletorParticula,
	"eletrons": $Painel/Display/Conteudo/Seletores/SeletorEletrons as SeletorParticula,
}


func _ao_abrir() -> void:
	for qual: String in seletores:
		var seletor: SeletorParticula = seletores[qual]
		registrar_alvo("mais_" + qual, seletor.retangulo_do_botao.bind(1), alterar.bind(qual, 1),
			Callable(), true)
		registrar_alvo("menos_" + qual, seletor.retangulo_do_botao.bind(-1), alterar.bind(qual, -1),
			Callable(), true)
		# Onde cada conta fica em repouso: tremer duas vezes seguidas não pode
		# deixá-la fora do lugar.
		seletor.quantos.set_meta("pos_base", seletor.quantos.position)
	registrar_alvo("limpar", botao_limpar.get_global_rect, limpar, _tem_particula)
	painel.definir_rodape(TXT_INSTRUCAO)
	painel.aparecer()
	_atualizar(false)


## A roda do mouse em cima de um seletor põe e tira partículas dele.
func _ao_receber(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton and event.pressed):
		return false
	var sentido := 0
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		sentido = 1
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		sentido = -1
	if sentido == 0:
		return false
	for qual: String in seletores:
		if (seletores[qual] as Control).get_global_rect().has_point(event.position):
			alterar(qual, sentido)
			return true
	return false


func _ao_mudar_o_foco(_foco: String) -> void:
	botao_limpar.self_modulate = Color(1.35, 1.35, 1.35) if alvo_em_foco() == "limpar" else Color.WHITE


# ─────────────────────────────────────────────────────────────
# PÔR E TIRAR
# ─────────────────────────────────────────────────────────────

## A seta de um seletor ("protons", "neutrons" ou "eletrons"): a de cima (+1)
## põe uma partícula no átomo, a de baixo (-1) tira.
func alterar(qual: String, sentido: int) -> void:
	if not SELETORES.has(qual) or sentido == 0:
		return
	var seletor: SeletorParticula = seletores[qual]
	seletor.animar_seta(sentido)
	var agora := quantas(qual)
	var depois := agora + signi(sentido)
	if depois < 0:
		return
	if depois > int(SELETORES[qual]["maximo"]):
		_recusar(String(SELETORES[qual]["demais"]), seletor.quantos)
		return
	match qual:
		"protons":
			protons = depois
		"neutrons":
			neutrons = depois
		"eletrons":
			eletrons = depois
	atomo.definir(protons, neutrons, eletrons)
	if sentido > 0:
		# Cada partícula a mais, um pouco mais agudo: enchendo o átomo, o som sobe.
		tocar("pop", 0.9 + 0.5 * float(depois) / float(SELETORES[qual]["maximo"]))
	else:
		tocar("tirar")
	_atualizar(qual == "protons")


## Quantas partículas de cada tipo o átomo tem agora.
func quantas(qual: String) -> int:
	match qual:
		"protons":
			return protons
		"neutrons":
			return neutrons
		"eletrons":
			return eletrons
	return 0


## Monta de uma vez um átomo com este tanto de cada partícula (dentro dos
## limites).
func montar(novos_protons: int, novos_neutrons: int, novos_eletrons: int) -> void:
	protons = clampi(novos_protons, 0, MAXIMO_DE_PROTONS)
	neutrons = clampi(novos_neutrons, 0, MAXIMO_DE_NEUTRONS)
	eletrons = clampi(novos_eletrons, 0, MAXIMO_DE_ELETRONS)
	atomo.definir(protons, neutrons, eletrons)
	_atualizar(true)


## Tira tudo: o átomo volta a ficar vazio.
func limpar() -> void:
	if not _tem_particula():
		return
	tocar("tirar")
	montar(0, 0, 0)
	painel.voltar_rodape()


func _tem_particula() -> bool:
	return protons + neutrons + eletrons > 0


## Bateu num limite: a conta treme e o rodapé diz por quê. Com a seta
## segurada o aviso é o mesmo, então ele não se repete (nem o som).
func _recusar(texto: String, conta: Label) -> void:
	if painel.avisando() and painel.texto_do_rodape() == texto:
		return
	tocar("erro")
	painel.avisar(texto, PainelDaAtividade.COR_ERRO)
	var origem: Vector2 = conta.get_meta("pos_base", conta.position)
	var tween := novo_tween()
	tween.set_trans(Tween.TRANS_SINE)
	for desvio: float in [6.0, -6.0, 5.0, -5.0, 0.0]:
		tween.tween_property(conta, "position", origem + Vector2(desvio, 0.0), 0.045)


# ─────────────────────────────────────────────────────────────
# O QUE O COMPUTADOR DIZ
# ─────────────────────────────────────────────────────────────

## O número de massa do átomo montado: prótons mais nêutrons.
func massa() -> int:
	return protons + neutrons


## A carga elétrica: prótons menos elétrons.
func carga_do_atomo() -> int:
	return protons - eletrons


## "CARBONO-12", ou o que dizer enquanto não há elemento: partículas sem
## próton nenhum não são átomo de elemento algum.
func nome_do_atomo() -> String:
	if protons > 0:
		return Elementos.nome_do_isotopo(protons, massa()).to_upper()
	return TXT_SEM_PROTONS if _tem_particula() else TXT_VAZIO


## O que o átomo montado é: neutro, cátion ou ânion ("" sem prótons).
func tipo_de_carga() -> String:
	if protons <= 0:
		return ""
	var diferenca := carga_do_atomo()
	return TXT_NEUTRO if diferenca == 0 else (TXT_CATION if diferenca > 0 else TXT_ANION)


## O que o quadro ao lado da caixa diz: quanto desse isótopo existe na
## natureza ou, sem prótons, por que aquilo não é elemento ("" com tudo vazio).
func texto_da_natureza() -> String:
	if protons <= 0:
		return TXT_EXPLICA_SEM_PROTONS if _tem_particula() else ""
	var texto := ""
	var apelido := Elementos.apelido_do_isotopo(protons, massa())
	if not apelido.is_empty():
		texto = TXT_APELIDO % apelido.to_upper()
	var quanto := Elementos.abundancia(protons, massa())
	if quanto < 0.0:
		return texto + TXT_INSTAVEL
	if quanto >= 99.9999:
		return texto + TXT_TODOS_ASSIM % Elementos.nome(protons).to_upper()
	return texto + TXT_PARTE_ASSIM % [Elementos.numero_com_virgula(quanto), Elementos.nome(protons).to_upper()]


func _atualizar(mudou_o_elemento: bool) -> void:
	for qual: String in seletores:
		(seletores[qual] as SeletorParticula).quantos.text = str(quantas(qual))
	numero_atomico.text = "Z = %d" % protons
	numero_de_massa.text = "A = %d" % massa()
	carga.text = "CARGA %s" % Elementos.carga_escrita(carga_do_atomo())
	legenda_da_carga.text = tipo_de_carga()

	nome.text = nome_do_atomo()
	caixa.numero_atomico = protons
	notacao.visible = protons > 0
	if protons > 0:
		notacao.definir(Elementos.simbolo(protons), massa(), protons, carga_do_atomo())
	na_natureza.text = texto_da_natureza()

	if mudou_o_elemento:
		_pulsar(caixa)
		if protons > 0:
			# O rodapé diz que átomo é, na hora.
			painel.avisar(TXT_ELEMENTO % [protons, "PRÓTON" if protons == 1 else "PRÓTONS",
				Elementos.nome(protons).to_upper()], PainelDaAtividade.COR_CERTO, 2.4)
		else:
			painel.voltar_rodape()


## A caixa do elemento dá um pulo quando o elemento troca.
func _pulsar(alvo: Control) -> void:
	alvo.pivot_offset = alvo.size * 0.5
	alvo.scale = Vector2(1.12, 1.12)
	var tween := novo_tween()
	tween.tween_property(alvo, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
