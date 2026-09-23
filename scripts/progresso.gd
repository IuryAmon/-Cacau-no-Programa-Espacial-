extends Node

# --- AUTOLOAD "Progresso" ---
#
# O cérebro da progressão do Plano de Level Design v2: guarda as células do
# painel CHONPS e as habilidades permanentes (maçarico, bumerangue, mochila,
# sinalizador, botas). Toda trava do jogo — inclusive as duas do armário da
# mochila — apenas consulta este autoload, o que permite reordenar as fases
# no playtest sem refatorar nada.
#
# Assim como o EstadoMundo, vale enquanto o jogo estiver aberto: não existe
# sistema de save ainda.
#
# Cada elemento do CHONPS passa por dois momentos:
#   COLETADO  a Cacau pegou a amostra numa ala e está carregando
#             (coletar_celula / carrega_celula);
#   ENTREGUE  ela jogou a amostra no receptor do laboratório e a letra acendeu
#             no painel (dar_celula / tem_celula).
# As travas do jogo (portão da Torre de Lançamento, etc.) olham só o ENTREGUE:
# amostra que ainda está na mochila não conta.

signal celula_coletada(letra: String)
signal celula_entregue(letra: String)
signal habilidade_conquistada(nome: String)

## Ordem canônica do painel (e da sigla).
const CELULAS := ["C", "H", "O", "N", "P", "S"]

## Nomes válidos de habilidade, na ordem em que são conquistadas no jogo.
## ("lanterna" é a ferramenta do blecaute profundo — o feixe que congela as
## Sentinelas; ver scripts/ferramentas/lanterna.gd.)
const HABILIDADES := ["macarico", "bumerangue", "mochila", "sinalizador", "botas", "lanterna"]

## Letras já acesas no painel.
var _celulas: Dictionary = {}
## Amostras que a Cacau pegou e ainda não jogou no receptor.
var _amostras: Dictionary = {}
var _habilidades: Dictionary = {}

## Tag de porta consumida pela cena que abre: o player nasce na porta cuja
## "tag_aqui" bate com isto (ver porta_fase.gd).
var spawn_tag: String = ""

## O hub já acendeu as células H e O do prólogo no painel?
## (O maçarico NÃO vem daqui: ele está trancado na gaiola do pátio da Oficina
## do Carbono, e sai de lá com o puzzle da queima do acetileno.)
var hub_ja_apresentou: bool = false

## Visitou a ala de produção de lítio (world4)? Quem visitou resolve a
## checagem final do purificador de CO₂ com vantagem.
var visitou_ala_litio: bool = false

# --- SINALIZADOR QUIMIOLUMINESCENTE ---
## Carga de 0.0 a 1.0; drena enquanto aceso, recarrega nas estações de mistura.
var carga_sinalizador: float = 1.0
var sinalizador_aceso: bool = true


## A Cacau pegou a amostra do elemento: agora ela carrega até o receptor do
## laboratório. Não acende nada no painel ainda.
func coletar_celula(letra: String) -> void:
	if conquistou_celula(letra):
		return
	_amostras[letra] = true
	print("PROGRESSO: amostra ", letra, " coletada — falta entregar no receptor")
	celula_coletada.emit(letra)


## A amostra de "letra" está com a Cacau, esperando para ir ao receptor?
func carrega_celula(letra: String) -> bool:
	return _amostras.has(letra)


## As amostras que ela carrega, na ordem do CHONPS (é a ordem em que o
## receptor as recebe).
func amostras_na_mao() -> Array[String]:
	var lista: Array[String] = []
	for letra in CELULAS:
		if carrega_celula(letra):
			lista.append(letra)
	return lista


## Já pegou esse elemento, entregue ou não? É o que decide se a amostra ainda
## espera no cenário da fase.
func conquistou_celula(letra: String) -> bool:
	return carrega_celula(letra) or tem_celula(letra)


## A amostra entrou no receptor: a letra acende no painel. (Também serve para
## entregar direto, sem passar pela mão da Cacau — é o que o Dr. Chico faz com
## o H e o O do prólogo.)
func dar_celula(letra: String) -> void:
	if tem_celula(letra):
		return
	_amostras.erase(letra)
	_celulas[letra] = true
	print("PROGRESSO: célula ", letra, " entregue (", contar_celulas(), "/6)")
	celula_entregue.emit(letra)


## A letra já está acesa no painel?
func tem_celula(letra: String) -> bool:
	return _celulas.has(letra)


func contar_celulas() -> int:
	return _celulas.size()


func todas_as_celulas() -> bool:
	return contar_celulas() >= CELULAS.size()


func dar_habilidade(nome: String) -> void:
	if tem_habilidade(nome):
		return
	_habilidades[nome] = true
	print("PROGRESSO: habilidade conquistada -> ", nome)
	habilidade_conquistada.emit(nome)


func tem_habilidade(nome: String) -> bool:
	return _habilidades.has(nome)
