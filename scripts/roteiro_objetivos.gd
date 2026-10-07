class_name RoteiroObjetivos
extends RefCounted

# --- O ROTEIRO DOS OBJETIVOS (o que aparece no canto superior esquerdo) ---
#
# Todo objetivo do jogo mora AQUI: o texto e a pergunta que diz se ele já foi
# cumprido. O autoload Objetivos (scripts/objetivos.gd) pergunta a este roteiro
# o que mostrar, e o ObjetivosHUD (scripts/ui/objetivos_hud.gd) desenha. Para
# reescrever um texto, mudar a ordem ou acrescentar um passo, é só mexer na
# lista de _init() — nenhum objeto do cenário precisa saber que objetivo existe.
#
# TRILHAS
#
# O jogo é um metroidvania: nada impede a Cacau de entrar na Torre de Gases
# antes de terminar a Oficina do Carbono. Por isso o roteiro não é uma fila
# única — são TRILHAS, uma por ala, cada uma com a sua fila de etapas:
#
#   prologo    world1 até a revelação do Dr. Chico
#   carbono    Ala de Pirólise + Pátio (fase 1 e 1.2)    -> entregar o C
#   nitrogenio o corredor da torre + a fase 2 (em branco) -> entregar o N
#   subsolo    Subsolo em blecaute                       -> entregar o P e o S
#   lancamento Torre de Lançamento                       -> embarque
#
# Dentro de uma cena da trilha (a fase 2, digamos), aparece a etapa atual DELA.
# Fora de qualquer trilha (laboratório, world1 depois do prólogo, simulador),
# aparece a etapa atual da primeira trilha ainda não terminada — é o "próximo
# passo" do jogo.
#
# ETAPAS
#
# Cada etapa tem um ou mais objetivos que aparecem JUNTOS (pegar o H₂ e o O₂,
# por exemplo, cada um com a sua caixinha). A etapa acaba quando todos acabam.
# Etapa sem objetivo visível é um PORTÃO: segura a trilha sem mostrar nada (é
# assim que nada aparece antes da primeira conversa com o cientista).
#
# Objetivo com "aparece" só entra na lista quando essa pergunta diz que sim, e
# NÃO segura a etapa: é uma dica que chega na hora certa (a caixa arrastável,
# quando a Cacau encosta nela) ou um objetivo adiantado (o maçarico, quando ela
# já tentou abrir a porta de metal). Objetivo com "pai" é SUBITEM: aparece
# recuado logo abaixo do objetivo pai.
#
# O mesmo id pode estar em mais de uma etapa (o maçarico adiantado e o
# maçarico da vez): na tela é uma linha só, que continua quando a etapa muda.
#
# A etapa atual de uma trilha é a seguinte à ÚLTIMA etapa cumprida — e não a
# primeira que falta. É isso que deixa a fila andar sozinha com os atalhos de
# teste (K, Ç, M) ou abrindo a fase direto no editor: pegar o maçarico prova
# que o bumerangue e os espinhos ficaram para trás, mesmo que nenhum deles
# tenha sido visto sendo cumprido.
#
# AS PERGUNTAS
#
# Nada aqui guarda estado: cada pergunta lê o que o jogo já guarda — Progresso
# (ferramentas e células), Inventario, e o EstadoMundo pelo CAMINHO do nó
# ("/root/Fase1Oficina/Patio/PortaMetal"). Renomear ou mover um desses nós na
# cena quebra a pergunta dele: o teste tools/teste_objetivos.tscn confere todos
# os caminhos usados aqui.

const WORLD1 := "res://scenes/world1.tscn"
const LAB := "res://scenes/laboratório_(world_2).tscn"
const FASE1 := "res://scenes/fases/fase1_oficina.tscn"
const FASE1_2 := "res://scenes/fases/fase1_2_exterior.tscn"
## O corredor entre o laboratório e a fase 2: já é o caminho do nitrogênio.
const CORREDOR_TORRE := "res://scenes/fases/corredor_torre.tscn"
const FASE2 := "res://scenes/fases/fase2_torre.tscn"
const FASE3 := "res://scenes/fases/fase3_subsolo.tscn"
const FASE_FINAL := "res://scenes/fases/fase_final.tscn"
const FINAL_ORBITA := "res://scenes/fases/final_orbita.tscn"

# Nós do cenário que o roteiro consulta no EstadoMundo.
const CIENTISTA_WORLD1 := "/root/World/Cientista"
const ITEM_H2 := "/root/World/ItemColetavel"
const ITEM_O2 := "/root/World/ItemColetavel2"
## A caixa arrastável do telhado: é ela que leva a Cacau ao alto do mirante.
const CAIXA_WORLD1 := "/root/World/Caixa"
## Os espinhos de laser da escola do arremesso, alimentados pela AlvoFixo1.
const ESPINHOS_TREINO := "/root/Fase1Oficina/Treino/EspinhosCaixa"
const PORTA_METAL := "/root/Fase1Oficina/Patio/PortaMetal"
const PORTA_METAL_ELEVADOR := "/root/Fase1Oficina/Patio/PortaMetal2"
const MESA_PURIFICADOR := "/root/FaseFinal/Plataforma/MesaPurificador"

## Todos os caminhos acima, para o teste conferir se ainda existem nas cenas.
const CAMINHOS_POR_CENA := {
	WORLD1: [CIENTISTA_WORLD1, ITEM_H2, ITEM_O2, CAIXA_WORLD1],
	FASE1: [ESPINHOS_TREINO, PORTA_METAL, PORTA_METAL_ELEVADOR],
	FASE_FINAL: [MESA_PURIFICADOR],
}

const TEXTO_MACARICO := "Pegue o maçarico no domo de vidro"

## As trilhas, na ordem do jogo. Cada uma:
##   id, titulo (cabeçalho do HUD), cor (losango do cabeçalho),
##   cenas (onde ela é a trilha "da casa") e etapas.
## Cada etapa: {"objetivos": [...], "portao": Callable (só nas etapas sem
## objetivo)}. Cada objetivo: {"id", "texto", "feito": Callable,
## "contagem": Callable opcional que devolve Vector2i(atual, total),
## "aparece": Callable opcional (ver o topo), "pai": id do objetivo pai ou ""}.
var trilhas: Array[Dictionary] = []

## Quem responde "a Cacau já entrou nesta cena?" (o autoload Objetivos).
var _visitou: Callable


func _init(visitou: Callable) -> void:
	_visitou = visitou
	trilhas = [
		_trilha("prologo", "COMBUSTÃO DO HIDROGÊNIO", Color(1.0, 0.36, 0.38), [WORLD1], [
			# Nada aparece antes do cientista dar a missão.
			_portao(_missao_aceita),
			[
				_obj("h2", "Pegue o cilindro de H₂ no telhado do laboratório", _pegou_h2),
				_obj("o2", "Pegue o cilindro de O₂ no alto do mirante", _pegou_o2),
				# A dica chega quando ela encosta na caixa — ou quando já pegou
				# o H₂ lá em cima, ao lado dela.
				_sub("o2", _obj("caixa", "Use a caixa arrastável", _pegou_o2,
					Callable(), _dica_da_caixa)),
			],
			[_obj("computador", "Coloque os cilindros no computador", _laser_aberto)],
			[_obj("entrar_lab", "Entre no laboratório", _chegou_ao_lab)],
			# A revelação acontece logo na entrada: o próximo objetivo só
			# aparece depois que o Dr. Chico explica o painel CHONPS.
			_portao(_revelou_dr_chico),
		]),

		_trilha("carbono", "CARBONO", AmostraChonps.CORES["C"], [FASE1, FASE1_2], [
			[_obj("entrar_oficina", "Entre na Ala de Pirólise", _visitou.bind(FASE1))],
			[
				_obj("bumerangue", "Pegue o bumerangue no domo de vidro", _tem.bind("bumerangue")),
				_macarico_adiantado(),
			],
			[
				_obj("espinhos", "Desative os espinhos de laser acertando a caixa de energia que os alimenta",
					_feito.bind(ESPINHOS_TREINO)),
				_macarico_adiantado(),
			],
			[_obj("macarico", TEXTO_MACARICO, _tem.bind("macarico"))],
			[_obj("porta_metal", "Derreta a porta de metal com o maçarico", _feito.bind(PORTA_METAL))],
			[_obj("porta_elevador", "Volte ao início da oficina e derreta a porta de metal",
				_feito.bind(PORTA_METAL_ELEVADOR))],
			[_obj("patio", "Suba até o pátio", _visitou.bind(FASE1_2))],
			[_obj("carvao", "Faça carvão a partir das madeiras", _pegou.bind("C"))],
			[_obj("entregar_c", "Leve o carvão ao receptor do painel CHONPS, no laboratório",
				_entregou.bind("C"))],
		]),

		# A fase do nitrogênio está em branco, sendo refeita do zero: os passos
		# que dependiam dos objetos da antiga Torre (a alavanca atrás da grade,
		# a chapa soldada do armário, o ciclo do nitrogênio na estufa) saíram
		# junto com eles. Ficaram só os que não consultam nenhum nó da cena —
		# os passos novos entram aqui conforme a fase for sendo montada.
		_trilha("nitrogenio", "NITROGÊNIO", AmostraChonps.CORES["N"], [CORREDOR_TORRE, FASE2], [
			[_obj("entrar_torre", "Entre na Torre de Gases e Estufa", _visitou.bind(FASE2))],
			[_obj("mochila", "Pegue a mochila propulsora de N₂", _tem.bind("mochila"))],
			[_obj("pegar_n", "Pegue a amostra de nitrogênio (N)", _pegou.bind("N"))],
			[_obj("entregar_n", "Leve o nitrogênio ao receptor do painel CHONPS, no laboratório",
				_entregou.bind("N"))],
		]),

		_trilha("subsolo", "ENXOFRE E FÓSFORO", AmostraChonps.CORES["S"], [FASE3], [
			[_obj("entrar_subsolo", "Entre no subsolo pelo fosso de ventilação", _visitou.bind(FASE3))],
			[_obj("lanterna", "Pegue a lanterna no armário de manutenção", _tem.bind("lanterna"))],
			[
				_obj("pegar_p", "Ala oeste: pegue a amostra de fósforo (P) no gerador", _pegou.bind("P")),
				_obj("botas", "Ala leste: vulcanize as botas na masseira", _tem.bind("botas")),
			],
			[_obj("pegar_s", "Atravesse o corredor eletrificado e pegue a amostra de enxofre (S)",
				_pegou.bind("S"))],
			[_obj("entregar_ps", "Leve o fósforo e o enxofre ao receptor do painel CHONPS",
				_entregou_p_e_s, _contar_p_e_s)],
		]),

		_trilha("lancamento", "TORRE DE LANÇAMENTO", Color(0.95, 0.55, 0.65), [FASE_FINAL, FINAL_ORBITA], [
			[_obj("entrar_lancamento", "Entre na Torre de Lançamento", _visitou.bind(FASE_FINAL))],
			[_obj("purificador", "Suba a torre e monte o purificador de CO₂", _feito.bind(MESA_PURIFICADOR))],
			[_obj("embarque", "Embarque na cápsula", _visitou.bind(FINAL_ORBITA))],
		]),
	]


# ─────────────────────────────────────────────
#  Montagem
# ─────────────────────────────────────────────

func _trilha(id: String, titulo: String, cor: Color, cenas: Array, etapas: Array) -> Dictionary:
	var lista: Array[Dictionary] = []
	for etapa in etapas:
		lista.append(etapa if etapa is Dictionary else {"objetivos": etapa})
	return {"id": id, "titulo": titulo, "cor": cor, "cenas": cenas, "etapas": lista}


func _portao(condicao: Callable) -> Dictionary:
	return {"objetivos": [], "portao": condicao}


func _obj(id: String, texto: String, feito: Callable, contagem: Callable = Callable(),
		aparece: Callable = Callable()) -> Dictionary:
	return {"id": id, "texto": texto, "feito": feito, "contagem": contagem,
		"aparece": aparece, "pai": ""}


## O objetivo vira subitem de "pai" (recuado, logo abaixo dele).
func _sub(pai: String, objetivo: Dictionary) -> Dictionary:
	objetivo["pai"] = pai
	return objetivo


## "Pegue o maçarico" antes da hora: a Cacau apertou E numa das portas de
## metal sem ter com o que derretê-la. A mesma linha continua quando a etapa
## do maçarico chega de verdade.
func _macarico_adiantado() -> Dictionary:
	return _obj("macarico", TEXTO_MACARICO, _tem.bind("macarico"), Callable(), _tentou_porta_de_metal)


# ─────────────────────────────────────────────
#  Perguntas — prólogo
# ─────────────────────────────────────────────

## O cientista deu a missão (o sinal "missao_aceita" da primeira conversa).
## Dizer "Não." encerra a conversa sem missão, e aí nada aparece ainda.
func _missao_aceita() -> bool:
	return EstadoMundo.ja_feito_caminho(CIENTISTA_WORLD1, "plataforma") or _laser_aberto()


func _pegou_h2() -> bool:
	return Inventario.tem_item("Cilindro_de_Hidrogenio") or EstadoMundo.ja_feito_caminho(ITEM_H2)


func _pegou_o2() -> bool:
	return Inventario.tem_item("Cilindro_Oxigenio") or EstadoMundo.ja_feito_caminho(ITEM_O2)


func _dica_da_caixa() -> bool:
	return EstadoMundo.ja_feito_caminho(CAIXA_WORLD1, Caixa.MARCA_EMPURRADA) or _pegou_h2()


func _laser_aberto() -> bool:
	return EstadoMundo.passagem_laser_aberta


func _chegou_ao_lab() -> bool:
	return _visitou.call(LAB) or EstadoMundo.revelou_dr_chico


func _revelou_dr_chico() -> bool:
	return EstadoMundo.revelou_dr_chico


# ─────────────────────────────────────────────
#  Perguntas — gerais
# ─────────────────────────────────────────────

func _tem(habilidade: String) -> bool:
	return Progresso.tem_habilidade(habilidade)


func _feito(caminho: String) -> bool:
	return EstadoMundo.ja_feito_caminho(caminho)


## A amostra já saiu da ala (na mão ou já no painel).
func _pegou(letra: String) -> bool:
	return Progresso.conquistou_celula(letra)


## A letra já acendeu no painel.
func _entregou(letra: String) -> bool:
	return Progresso.tem_celula(letra)


# ─────────────────────────────────────────────
#  Perguntas — Ala de Pirólise
# ─────────────────────────────────────────────

func _tentou_porta_de_metal() -> bool:
	return EstadoMundo.ja_feito_caminho(PORTA_METAL, PortaMetalMacarico.MARCA_TENTOU) \
		or EstadoMundo.ja_feito_caminho(PORTA_METAL_ELEVADOR, PortaMetalMacarico.MARCA_TENTOU)


# ─────────────────────────────────────────────
#  Perguntas — Subsolo
# ─────────────────────────────────────────────

func _contar_p_e_s() -> Vector2i:
	return Vector2i(int(_entregou("P")) + int(_entregou("S")), 2)


func _entregou_p_e_s() -> bool:
	return _contar_p_e_s().x >= 2
