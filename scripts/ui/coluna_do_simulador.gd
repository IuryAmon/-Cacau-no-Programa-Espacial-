class_name ColunaDoSimulador
extends Control

# --- A COLUNA DO SIMULADOR DE DESTILAÇÃO (Laboratório) ---
#
# A coluna de destilação da fase do nitrogênio, em raio X, virada brinquedo: em
# vez de o Dr. Chico contar a história de uma mistura só (o ar, em
# scripts/ui/coluna_destilacao.gd), aqui entra a mistura que a pessoa escolher
# (MisturasDoDestilador) e quem manda na temperatura é ela, pelo termômetro. É
# também a coluna do puzzle da fase (scripts/puzzle_destilacao.gd).
#
# A FÍSICA é a do EquilibrioLiquidoVapor (scripts/laboratorio/
# equilibrio_liquido_vapor.gd): toda substância evapora um pouco em qualquer
# temperatura, e numa mistura o vapor leva de tudo, só que mais da que evapora
# mais fácil. Daí as regras da coluna, molécula por molécula:
#
#   * AS TEMPERATURAS. O termômetro diz até onde o fundo pode esquentar. O
#     TOPO é segurado pelo RESFRIADOR, numa temperatura fixa; os andares do
#     meio ficam repartidos por igual entre o fundo e o topo. (Com o fundo mais
#     frio que o resfriador, a coluna inteira fica na temperatura do fundo.)
#   * O FUNDO FERVE quando o calor o leva ao ponto de ebulição DA MISTURA que
#     está lá (o "ponto de bolha": a pressão de vapor do líquido chega a
#     1 atm). Fervendo, ele não esquenta mais: o calor vai todo para virar
#     vapor. Mas o vapor leva mais da substância que evapora mais fácil, o
#     líquido que fica é cada vez mais "difícil", e o ponto de bolha dele SOBE:
#     a temperatura do fundo vai subindo junto, até a pedida.
#   * CADA MOLÉCULA QUE EVAPORA é escolhida na proporção do vapor daquele
#     líquido (yᵢ, lei de Raoult). Do ar líquido saem umas 9 de nitrogênio para
#     cada uma de oxigênio ou argônio: os três evaporam, mesmo abaixo do ponto
#     de ebulição deles.
#   * O VAPOR SOBE pela fenda das bandejas. Passando por uma, parte dele encosta
#     no líquido dela (EFICIENCIA_DA_BANDEJA) e condensa; o resto segue. Numa
#     bandeja seca, só condensa a substância para a qual aquele andar já está no
#     ponto de ebulição dela ou abaixo.
#   * UMA BANDEJA COM LÍQUIDO ACIMA DO PONTO DE BOLHA DELE FERVE (o andar é
#     quente demais para aquela mistura) e solta, de novo na proporção do
#     vapor, as moléculas mais fáceis de evaporar. É o coração da destilação
#     fracionada: em cada bandeja o vapor condensa e evapora de novo, e a cada
#     vez fica mais rico na substância mais volátil.
#   * A BANDEJA QUE PASSA DO QUE SEGURA TRANSBORDA: o excesso escorre pela
#     fenda para a de baixo (é o REFLUXO, que devolve para baixo o que
#     condensou cedo demais). A de cima, junto do resfriador, é a que guarda o
#     que a coluna destila (como o frasco do fim de uma destilação de
#     laboratório): segura bem mais.
#   * NO TOPO o resfriador condensa o que dá para condensar. A substância que
#     nem lá vira líquido (o neônio, o butano do petróleo) fica GÁS no topo —
#     ou se dissolve um pouco no líquido de lá, até o ponto de bolha dele.
#   * O VAI-E-VOLTA. Em qualquer temperatura, de vez em quando uma molécula da
#     superfície pula para fora e volta: é a evaporação e a condensação
#     acontecendo juntas, no mesmo ritmo (o equilíbrio). O ritmo é o da pressão
#     de vapor do líquido: quanto mais quente, mais pulam; o sal não pula. Não
#     muda nada na conta — é para se ver que evaporar não é só ferver.
#
# Ninguém escolhe por sorteio: as escolhas (qual substância evapora, qual
# transborda, qual molécula de vapor encosta no líquido) são "justas" (ver
# EquilibrioLiquidoVapor.escolher): na proporção certa, e a coluna faz sempre a
# mesma coisa com a mesma mistura e a mesma temperatura.
#
# NADA SAI 100% PURO. O topo fica rico na substância mais volátil, o fundo na
# menos volátil, e as do meio se espalham — quanto mais perto os pontos de
# ebulição (o argônio e o oxigênio, só 3 °C), mais misturadas ficam. É o que a
# destilação de verdade faz: as fábricas usam dezenas de bandejas para chegar
# perto do puro.
#
# O QUE É SIMPLIFICAÇÃO (e a tela diz): a pressão é sempre 1 atm; a temperatura
# de cada andar é imposta (numa coluna de verdade ela é a do ponto de bolha do
# líquido de cada bandeja, que acaba sendo quase a mesma coisa); as moléculas
# são poucas, então uma a mais ou a menos muda muito a porcentagem.
#
# A COLUNA PAROU quando o fundo chegou à temperatura pedida, nada está fervendo,
# subindo, descendo ou transbordando. A MISTURA ESTÁ SEPARADA quando, parada,
# cada substância é a maioria num lugar só dela (as que são só um pouquinho da
# mistura, como o argônio do ar, não precisam: não têm como ficar sozinhas).
#
# A arte é a mesma da história ("coluna de destilação.png"), lida pela
# ArteDaColuna; as moléculas vêm de MoleculasDoDestilador.
#
# COMO USAR:
#   coluna.definir_mistura(MisturasDoDestilador.mistura("ar"))
#   coluna.pedir_temperatura(-185.0)     o que o termômetro pede
#   coluna.temperatura()                 a do fundo agora (ela vai atrás)
#   coluna.parada(), coluna.separada(), coluna.contas_do_andar(4)...
#
# COMO EDITAR NO EDITOR: o canto do nó é o canto da coluna, que é desenhada no
# tamanho da arte vezes ESCALA. À esquerda dela vão a régua e as plaquinhas de
# temperatura (uns 180 px); embaixo, o nome de onde vem o calor.

## Uma substância começou a evaporar de verdade (a primeira molécula dela saiu
## de um líquido como vapor).
signal ferveu(substancia: String)
## Uma molécula de vapor da substância virou líquido num andar.
signal condensou(substancia: String, andar: int)
## A mistura acabou de ficar separada.
signal separou
## Alguma molécula mudou de estado ou de andar: as fichas da tela se atualizam.
signal mudou

enum Estado { LIQUIDA, SUBINDO, MERGULHANDO, SOLTA, PINGANDO }

## As duas fases em que uma substância pode ficar parada num andar, e o "lugar"
## de quem está mudando de andar (ver onde_esta).
const LIQUIDO := 0
const GAS := 1
const A_CAMINHO := Vector2i(-1, -1)

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

## Quantos px de tela vale cada pixel da arte da coluna.
const ESCALA := 4.0
## Quanto tempo o aquecimento leva para ir de uma ponta à outra do termômetro
## (sem nada fervendo no caminho).
const TEMPO_DE_PONTA_A_PONTA := 2.6
## Num lugar que está fervendo, sai uma molécula a cada tanto.
const INTERVALO_DE_EMISSAO := 0.24
## Que fração do vapor que passa por uma bandeja encosta no líquido dela (a
## "eficiência" do prato). O vapor sobe pela fenda, por cima do líquido: só
## parte dele chega a trocar.
const EFICIENCIA_DA_BANDEJA := 0.5
## Quantas moléculas uma bandeja do meio segura antes de transbordar.
const CAPACIDADE_DA_BANDEJA := 3
## De quanto em quanto o gás solto no topo confere se já pode virar líquido.
const INTERVALO_DO_GAS_SOLTO := 0.4
## O vai-e-volta da superfície: quantos pulos por segundo um líquido dá com a
## pressão de vapor em 1 atm (proporcional a ela), e como é o pulo.
const PULOS_POR_SEGUNDO := 1.3
const DURACAO_DO_PULO := 0.7
const ALTURA_DO_PULO := 34.0
## Velocidade do gás subindo, do gás solto e do líquido escorrendo (px de tela
## por segundo).
const VELOCIDADE_SUBINDO := 190.0
const VELOCIDADE_SOLTA := 96.0
const VELOCIDADE_PINGANDO := 170.0
## A folga para dizer que a temperatura chegou onde foi pedida.
const FOLGA_DE_TEMPERATURA := 0.01

# ── Medidas (px de tela) ──
## Meia molécula: o quanto ela se afasta de parede, teto e líquido.
const FOLGA := 13.0
const FOLGA_NA_FENDA := 8.0
## De uma fileira de moléculas do líquido à seguinte, e quantas cabem.
const ALTURA_DA_FILEIRA := 14.0
const FILEIRAS_NO_FUNDO := 4
## A bandeja de cima guarda o que a coluna destila: cabem mais fileiras nela.
const FILEIRAS_NO_TOPO := 3
const FILEIRAS_NA_BANDEJA := 1
## Entre uma molécula e a vizinha, na fileira.
const ENTRE_MOLECULAS := 2.0
## A régua de temperatura, colada na parede esquerda da coluna.
const LARGURA_DA_REGUA := 12.0
const DISTANCIA_DA_REGUA := 4.0
const DISTANCIA_DA_PLAQUINHA := 6.0
const LEGENDA_DO_RESFRIADOR := "RESFRIADOR"

## O líquido de um andar com mais de uma substância misturada, quando nenhuma
## manda (as cores se misturam na proporção de cada uma).
const COR_MISTURA := Color("1b3350")
const COR_TONA_MISTURA := Color("8fc1e8")
## As cores da régua (e do gás), do mais frio ao mais quente do termômetro.
const RAMPA := [Color("5fb8ff"), Color("8fd8ff"), Color("d9dcc8"), Color("f1c27d"), Color("f4a259")]
const COR_DO_CALOR := Color("ff9f1c")
const COR_DO_CALOR_CLARA := Color("ffd166")
const COR_SERPENTINA := Color("8fd8ff")
const COR_SERPENTINA_CLARA := Color("f2fbff")
const NEVOA_PONTILHADA := 0.16
const NEVOA_FRACA := 0.34
const NEVOA_FORTE := 0.95
## Abaixo desta fração da mistura, a substância é "um pouquinho" e não precisa
## ser a maioria em lugar nenhum para a mistura contar como separada.
const POUQUINHO := 0.15


class Particula:
	var tipo: String = ""
	var estado: int = 0
	## O meio dela, em px de tela a partir do canto da coluna.
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	## O andar em que ela está (ou, a caminho, o andar para onde vai).
	var andar: int = 0
	var caminho := PackedVector2Array()
	var passo: int = 0
	var relogio: float = 0.0
	## Giros por segundo (quadros) enquanto é gás.
	var giro: float = 5.0
	## 0..1: o estalo de quando ela aparece.
	var tamanho: float = 1.0
	## O lugar dela no líquido do andar.
	var alvo := Vector2.ZERO
	var proxima_fumaca: float = 0.0
	var proxima_conferida: float = 0.0
	## O vai-e-volta da superfície: quanto falta do pulo (0 = parada).
	var pulo: float = 0.0
	## Veio de vapor (condensou) — e não escorrendo de cima.
	var do_vapor: bool = false


var _arte: ArteDaColuna
var _mistura: Dictionary = {}
var _particulas: Array[Particula] = []
## Uma lista por andar: as moléculas que são (ou estão virando) líquido ali.
var _pocas: Array[Array] = []
## Por andar: quantas fileiras o líquido tem agora (para desenhá-lo) e quanto
## dele já se vê (0..1).
var _fileiras := PackedInt32Array()
var _niveis := PackedFloat32Array()
var _proxima_emissao := PackedFloat32Array()
var _proximo_pulo := PackedFloat32Array()
var _pulsos := PackedFloat32Array()
## As escolhas justas de cada andar (ver EquilibrioLiquidoVapor.escolher).
var _credito_vapor: Array[Dictionary] = []
var _credito_pulo: Array[Dictionary] = []
var _credito_transbordo: Array[Dictionary] = []
var _credito_contato := PackedFloat32Array()
## Até onde o aquecimento já levaria o fundo (vai atrás do pedido); a
## temperatura do fundo é ela, ou o ponto de bolha do líquido de lá se ele
## ferve antes.
var _aquecimento: float = 20.0
var _temperatura: float = 20.0
var _pedida: float = 20.0
var _bolha_do_fundo: float = EquilibrioLiquidoVapor.SEM_EBULICAO
var _relogio: float = 0.0
var _ja_ferveu := {}
var _estava_separada: bool = false
var _fumaca: Array[Dictionary] = []
var _respingos: Array[Dictionary] = []
var _bolhas: Array[Vector3] = []
var _proxima_bolha: float = 0.0
var _nevoa := PackedFloat32Array()
## Dois sorteios: o da conta (por onde o vapor sobe, a altura de voo) e o do
## enfeite (fumaça, respingos, bolhas, a hora dos pulos). Separados, o enfeite
## não muda nada na conta: a mesma mistura com as mesmas temperaturas dá
## sempre o mesmo resultado, aconteça o que acontecer na tela.
var _sorteio := RandomNumberGenerator.new()
var _enfeite := RandomNumberGenerator.new()

## Quantos graus por segundo o aquecimento anda (0 = o padrão: a escala do
## termômetro inteira em TEMPO_DE_PONTA_A_PONTA). A explicação do Dr. Chico
## usa mais devagar.
var graus_por_segundo: float = 0.0
## Multiplica o ritmo do vai-e-volta da superfície (a explicação aumenta na hora
## de mostrar que tudo evapora um pouco).
var ritmo_dos_pulos: float = 1.0
## A eficiência das bandejas desta coluna (ver EFICIENCIA_DA_BANDEJA). Vale a
## partir do próximo reiniciar().
var eficiencia: float = EFICIENCIA_DA_BANDEJA


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preparar()
	custom_minimum_size = tamanho_da_coluna()
	size = custom_minimum_size


func _process(delta: float) -> void:
	avancar(delta)


func _preparar() -> void:
	if _arte != null:
		return
	_arte = ArteDaColuna.ler()
	var andares := _arte.andares()
	_pocas.resize(andares)
	for i in andares:
		_pocas[i] = []
	_fileiras.resize(andares)
	_niveis.resize(andares)
	_proxima_emissao.resize(andares)
	_proximo_pulo.resize(andares)
	_pulsos.resize(andares)
	_credito_contato.resize(andares)
	_credito_vapor.resize(andares)
	_credito_pulo.resize(andares)
	_credito_transbordo.resize(andares)
	_nevoa.resize(_arte.tamanho().x * _arte.tamanho().y)


# ─────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────

## Põe uma mistura na coluna (um item de MisturasDoDestilador.MISTURAS): tudo
## volta ao começo, com ela líquida no fundo e o termômetro no mínimo.
func definir_mistura(dados: Dictionary) -> void:
	_preparar()
	_mistura = dados
	reiniciar()


## A mesma mistura de novo: líquida no fundo, termômetro no mínimo.
func reiniciar() -> void:
	_preparar()
	_particulas.clear()
	for poca in _pocas:
		poca.clear()
	_fileiras.fill(0)
	_niveis.fill(0.0)
	_proxima_emissao.fill(0.0)
	_pulsos.fill(0.0)
	# O primeiro pulo de cada andar sai logo, mas não todos juntos.
	for andar in _proximo_pulo.size():
		_proximo_pulo[andar] = 0.3 + 0.17 * andar
	# Crédito do meio: a primeira molécula de vapor a passar por cada bandeja
	# já encosta no líquido.
	_credito_contato.fill(1.0 - eficiencia)
	for andar in _credito_vapor.size():
		_credito_vapor[andar] = {}
		_credito_pulo[andar] = {}
		_credito_transbordo[andar] = {}
	_fumaca.clear()
	_respingos.clear()
	_bolhas.clear()
	_ja_ferveu.clear()
	_estava_separada = false
	_relogio = 0.0
	if _mistura.is_empty():
		queue_redraw()
		return
	_aquecimento = float(_mistura["minima"])
	_pedida = _aquecimento
	# Sempre a mesma mistura embaralhada: recomeçar dá o mesmo desenho.
	_sorteio.seed = 828
	_enfeite.seed = 829
	var tipos: Array[String] = []
	var quantas: Dictionary = _mistura["substancias"]
	for chave: String in quantas:
		for i in int(quantas[chave]):
			tipos.append(chave)
	for i in range(tipos.size() - 1, 0, -1):
		var j := _sorteio.randi_range(0, i)
		var troca := tipos[i]
		tipos[i] = tipos[j]
		tipos[j] = troca
	for tipo in tipos:
		var p := Particula.new()
		p.tipo = tipo
		p.estado = Estado.LIQUIDA
		p.andar = 0
		p.relogio = _sorteio.randf() * 10.0
		p.giro = _sorteio.randf_range(3.0, 6.0)
		_particulas.append(p)
		_pocas[0].append(p)
	_arrumar_a_poca(0)
	for p in _particulas:
		p.pos = p.alvo
	_niveis[0] = 1.0
	_atualizar_a_temperatura()
	mudou.emit()
	queue_redraw()


func mistura() -> Dictionary:
	return _mistura


## O que o termômetro pede para o fundo. A temperatura vai atrás aos poucos.
func pedir_temperatura(graus: float) -> void:
	if _mistura.is_empty():
		return
	_pedida = clampf(graus, float(_mistura["minima"]), float(_mistura["maxima"]))


func temperatura_pedida() -> float:
	return _pedida


## A temperatura do fundo agora: a que o aquecimento já alcançou ou, se o
## líquido de lá ferve antes, o ponto de bolha dele.
func temperatura() -> float:
	return _temperatura


## A temperatura em que o líquido do fundo ferve agora (o ponto de bolha da
## mistura que está lá). Sobe conforme as substâncias mais voláteis saem.
## EquilibrioLiquidoVapor.SEM_EBULICAO se não há nada lá que evapore.
func bolha_do_fundo() -> float:
	return _bolha_do_fundo


## A temperatura em que o resfriador segura o topo.
func temperatura_do_resfriador() -> float:
	return float(_mistura.get("resfriador", 20.0))


## A temperatura do topo agora: a do resfriador, ou a do fundo, se ele estiver
## ainda mais frio.
func temperatura_do_topo() -> float:
	return minf(_temperatura, temperatura_do_resfriador())


func andares() -> int:
	_preparar()
	return _arte.andares()


## A temperatura do andar agora (0 = o fundo).
func temperatura_do_andar(andar: int) -> float:
	return lerpf(_temperatura, temperatura_do_topo(), _altura_relativa(andar))


## A temperatura que o andar teria com o fundo em "do_fundo" (para os testes e
## para as dicas).
func temperatura_do_andar_com(andar: int, do_fundo: float) -> float:
	return lerpf(do_fundo, minf(do_fundo, temperatura_do_resfriador()), _altura_relativa(andar))


func _altura_relativa(andar: int) -> float:
	var total := andares()
	return float(clampi(andar, 0, total - 1)) / float(maxi(total - 1, 1))


func tamanho_da_coluna() -> Vector2:
	_preparar()
	return Vector2(_arte.tamanho()) * ESCALA


## As moléculas do líquido do andar, por substância (as que estão chegando
## nele já contam).
func contas_do_andar(andar: int) -> Dictionary:
	var contas := {}
	for p: Particula in _pocas[andar]:
		contas[p.tipo] = int(contas.get(p.tipo, 0)) + 1
	return contas


## As moléculas de gás solto no topo, por substância.
func contas_do_gas() -> Dictionary:
	var contas := {}
	for p in _particulas:
		if p.estado == Estado.SOLTA:
			contas[p.tipo] = int(contas.get(p.tipo, 0)) + 1
	return contas


## Que fração do líquido do andar é desta substância (0..1; 0 sem líquido).
func fracao(andar: int, substancia: String) -> float:
	var total := _pocas[andar].size()
	if total == 0:
		return 0.0
	return float(contas_do_andar(andar).get(substancia, 0)) / float(total)


## A substância que é a maioria (mais da metade) do líquido do andar, ou "".
func dono_do_andar(andar: int) -> String:
	var contas := contas_do_andar(andar)
	var total := _pocas[andar].size()
	for chave: String in contas:
		if int(contas[chave]) * 2 > total:
			return chave
	return ""


## O líquido do andar está fervendo (o fundo, com o calor passando do ponto de
## bolha dele; uma bandeja, num andar mais quente que o ponto de bolha do
## líquido dela)?
func fervendo(andar: int) -> bool:
	if _pocas[andar].is_empty():
		return false
	if andar == 0:
		return _aquecimento > _bolha_do_fundo + FOLGA_DE_TEMPERATURA
	return EquilibrioLiquidoVapor.ferve(contas_do_andar(andar), temperatura_do_andar(andar))


## A pressão de vapor do líquido do andar agora, em atm (passou de 1, ferve).
func pressao_do_andar(andar: int) -> float:
	return EquilibrioLiquidoVapor.pressao_da_mistura(contas_do_andar(andar), temperatura_do_andar(andar))


## Quantas moléculas da substância estão em cada lugar. Um lugar é
## Vector2i(andar, fase): a fase é LIQUIDO ou GAS. O que está subindo ou
## descendo conta no lugar A_CAMINHO.
func onde_esta(substancia: String) -> Dictionary:
	var lugares := {}
	for p in _particulas:
		if p.tipo != substancia:
			continue
		var lugar := A_CAMINHO
		if p.estado == Estado.LIQUIDA:
			lugar = Vector2i(p.andar, LIQUIDO)
		elif p.estado == Estado.SOLTA:
			lugar = Vector2i(p.andar, GAS)
		lugares[lugar] = int(lugares.get(lugar, 0)) + 1
	return lugares


## Quantas moléculas estão subindo, mergulhando ou escorrendo agora.
func em_transito() -> int:
	var conta := 0
	for p in _particulas:
		if p.estado == Estado.SUBINDO or p.estado == Estado.MERGULHANDO or p.estado == Estado.PINGANDO:
			conta += 1
	return conta


func total_de_moleculas() -> int:
	return _particulas.size()


## Quantas moléculas da substância estão neste estado (Estado.*).
func quantas_em(estado: Estado, substancia: String = "") -> int:
	var conta := 0
	for p in _particulas:
		if p.estado == estado and (substancia == "" or p.tipo == substancia):
			conta += 1
	return conta


## O lugar em que a substância está inteira (Vector2i(andar, fase)), ou
## A_CAMINHO se ela está espalhada ou mudando de andar.
func lugar_de(substancia: String) -> Vector2i:
	var lugares := onde_esta(substancia)
	if lugares.size() != 1:
		return A_CAMINHO
	return lugares.keys()[0]


## O lugar em que está a maior parte da substância (Vector2i(andar, fase); entre
## dois com o mesmo tanto, o mais alto), ou A_CAMINHO se nenhuma está parada.
func lugar_principal(substancia: String) -> Vector2i:
	var lugares := onde_esta(substancia)
	var melhor := A_CAMINHO
	for lugar: Vector2i in lugares:
		if lugar == A_CAMINHO:
			continue
		if melhor == A_CAMINHO or int(lugares[lugar]) > int(lugares[melhor]) \
				or (int(lugares[lugar]) == int(lugares[melhor]) and lugar.x * 2 + lugar.y > melhor.x * 2 + melhor.y):
			melhor = lugar
	return melhor


## Quantas moléculas há num lugar (Vector2i(andar, fase)), de todas as
## substâncias.
func moleculas_no_lugar(lugar: Vector2i) -> int:
	if lugar.y == GAS:
		var conta := 0
		for p in _particulas:
			if p.estado == Estado.SOLTA and p.andar == lugar.x:
				conta += 1
		return conta
	var conta := 0
	for p: Particula in _pocas[lugar.x]:
		if p.estado == Estado.LIQUIDA:
			conta += 1
	return conta


## A coluna assentou: o fundo está na temperatura pedida, nada ferve, nada está
## subindo, descendo ou transbordando, e nenhum gás do topo está para virar
## líquido.
func parada() -> bool:
	if _mistura.is_empty() or absf(_temperatura - _pedida) > FOLGA_DE_TEMPERATURA or em_transito() > 0:
		return false
	for andar in _pocas.size():
		if fervendo(andar) or _pocas[andar].size() > _capacidade(andar):
			return false
	for p in _particulas:
		if p.estado == Estado.SOLTA and _cabe_no_topo(p.tipo):
			return false
	return true


## Parada, e cada substância é a maioria num lugar só dela (fora as que são
## só um pouquinho da mistura).
func separada() -> bool:
	if not parada():
		return false
	var total := float(_particulas.size())
	var ocupados := {}
	for chave: String in _mistura["substancias"]:
		var quantas := float(int(_mistura["substancias"][chave]))
		if quantas / total < POUQUINHO:
			continue
		var lugar := _lugar_onde_manda(chave)
		if lugar == A_CAMINHO or ocupados.has(lugar):
			return false
		ocupados[lugar] = chave
	return true


## O lugar em que a substância é a maioria (mais da metade das moléculas de
## lá), ou A_CAMINHO.
func _lugar_onde_manda(substancia: String) -> Vector2i:
	var lugares := onde_esta(substancia)
	for lugar: Vector2i in lugares:
		if lugar == A_CAMINHO:
			continue
		if int(lugares[lugar]) * 2 > moleculas_no_lugar(lugar):
			return lugar
	return A_CAMINHO


## O nome de um lugar, para as frases ("NO FUNDO", "NO 2º ANDAR", "GÁS NO TOPO").
func nome_do_lugar(lugar: Vector2i) -> String:
	var topo := andares() - 1
	if lugar.y == GAS:
		return "GÁS NO TOPO" if lugar.x == topo else "GÁS NO %dº ANDAR" % lugar.x
	if lugar.x == 0:
		return "NO FUNDO"
	return "NO TOPO" if lugar.x == topo else "NO %dº ANDAR" % lugar.x


## O que a substância está fazendo, numa frase curta (para a ficha dela).
func situacao_de(substancia: String) -> String:
	var lugares := onde_esta(substancia)
	if lugares.is_empty():
		return ""
	var total := 0
	for lugar: Vector2i in lugares:
		total += int(lugares[lugar])
	if lugares.size() == 1:
		var lugar: Vector2i = lugares.keys()[0]
		if lugar == A_CAMINHO:
			return "MUDANDO DE ANDAR"
		if lugar.y == GAS:
			return nome_do_lugar(lugar)
		return _estado_no_andar(substancia, lugar.x) + " " + nome_do_lugar(lugar)
	var principal := lugar_principal(substancia)
	if principal == A_CAMINHO:
		return "MUDANDO DE ANDAR"
	return "%d DE %d %s" % [int(lugares[principal]), total, nome_do_lugar(principal)]


## Como a substância está no líquido do andar: "LÍQUIDO" — ou, abaixo do ponto
## de fusão dela (o sal), "DISSOLVIDO" se ela cabe toda na água de lá, e
## "SÓLIDO" se não (o que não dissolve fica no fundo, sólido).
func _estado_no_andar(substancia: String, andar: int) -> String:
	var fusao := float(MisturasDoDestilador.substancia(substancia).get("fusao", -INF))
	if temperatura_do_andar(andar) >= fusao:
		return "LÍQUIDO"
	var contas := contas_do_andar(andar)
	if substancia == "NaCl" and EquilibrioLiquidoVapor.sal_dissolvido(contas) >= float(contas.get(substancia, 0)):
		return "DISSOLVIDO"
	return "SÓLIDO"


## Onde fica a plaquinha de temperatura do andar (o meio do lado direito dela).
func lugar_da_plaquinha(andar: int) -> Vector2:
	return Vector2(-(DISTANCIA_DA_REGUA + LARGURA_DA_REGUA + DISTANCIA_DA_PLAQUINHA),
		roundf(_arte.meio_do_andar(andar) * ESCALA))


## A cor de uma temperatura na régua: do azul do mínimo do termômetro ao
## laranja do máximo.
func cor_da_temperatura(graus: float) -> Color:
	if _mistura.is_empty():
		return RAMPA[0]
	var t := clampf(inverse_lerp(float(_mistura["minima"]), float(_mistura["maxima"]), graus), 0.0, 1.0) \
		* (RAMPA.size() - 1)
	var i := mini(int(t), RAMPA.size() - 2)
	return (RAMPA[i] as Color).lerp(RAMPA[i + 1], t - i)


# ─────────────────────────────────────────────────────────────
# PARA QUEM DESENHA A COLUNA DE OUTRO JEITO
# ─────────────────────────────────────────────────────────────
# A explicação do Dr. Chico (scripts/ui/coluna_destilacao.gd) usa esta coluna
# como motor, escondida, e desenha as moléculas com a arte dela. Estas são as
# peças que ela lê (tudo em px de tela a partir do canto da coluna).

## Todas as moléculas.
func particulas() -> Array[Particula]:
	return _particulas


## Onde a molécula aparece agora: a posição dela, mais o pulo do vai-e-volta.
func onde_desenhar(p: Particula) -> Vector2:
	if p.estado != Estado.LIQUIDA or p.pulo <= 0.0:
		return p.pos
	var t := 1.0 - p.pulo / DURACAO_DO_PULO
	return p.pos - Vector2(0.0, ALTURA_DO_PULO * 4.0 * t * (1.0 - t))


## A molécula está girando como gás (subindo, solta ou no meio de um pulo)?
func girando(p: Particula) -> bool:
	return p.estado == Estado.SUBINDO or p.estado == Estado.SOLTA \
		or (p.estado == Estado.LIQUIDA and p.pulo > 0.0)


## O retângulo do líquido do andar agora (sem área se não há líquido).
func caixa_do_liquido(andar: int) -> Rect2:
	if _niveis[andar] <= 0.0 or _fileiras[andar] <= 0:
		return Rect2()
	var poca := _largura_da_poca(andar)
	var altura := roundf(_altura_do_liquido(andar) * _niveis[andar])
	return Rect2(poca.x, _arte.chao_do_andar(andar) * ESCALA - altura, poca.y - poca.x, altura)


## Os fiapos de vapor ({"pos", "vel", "idade", "vida"}), os respingos ({"pos",
## "cor", ...}) e as bolhas (x, y, velocidade) de agora.
func fumaca() -> Array[Dictionary]:
	return _fumaca


func respingos() -> Array[Dictionary]:
	return _respingos


func bolhas() -> Array[Vector3]:
	return _bolhas


# ─────────────────────────────────────────────────────────────
# A SIMULAÇÃO
# ─────────────────────────────────────────────────────────────

## Um passo da simulação. O _process chama sozinho; os testes chamam direto.
func avancar(delta: float) -> void:
	if _mistura.is_empty() or _arte == null:
		return
	# Em passos curtos: um quadro demorado não pode atravessar parede.
	var resto := delta
	while resto > 0.0:
		var fatia := minf(resto, 1.0 / 60.0)
		resto -= fatia
		_passo(fatia)
	queue_redraw()


func _passo(delta: float) -> void:
	_relogio += delta
	var faixa := float(_mistura["maxima"]) - float(_mistura["minima"])
	var velocidade := graus_por_segundo if graus_por_segundo > 0.0 else faixa / TEMPO_DE_PONTA_A_PONTA
	_aquecimento = move_toward(_aquecimento, _pedida, velocidade * delta)
	_atualizar_a_temperatura()

	for andar in _pocas.size():
		_ferver(andar, delta)
		_pular(andar, delta)
		_niveis[andar] = move_toward(_niveis[andar], 1.0 if _tem_liquida(andar) else 0.0, delta / 0.3)
		_pulsos[andar] = move_toward(_pulsos[andar], 0.0, delta / 0.5)
	for andar in range(_pocas.size() - 1, 0, -1):
		if _pocas[andar].size() > _capacidade(andar):
			_transbordar(andar)
	for p in _particulas:
		_mover(p, delta)
	_passo_das_bolhas(delta)
	_passo_da_fumaca(delta)
	_passo_dos_respingos(delta)

	var agora := separada()
	if agora and not _estava_separada:
		separou.emit()
	_estava_separada = agora


## O fundo fica na temperatura que o aquecimento alcançou — ou no ponto de
## bolha do líquido de lá, se ele ferve antes: fervendo, ele não esquenta.
func _atualizar_a_temperatura() -> void:
	_bolha_do_fundo = EquilibrioLiquidoVapor.temperatura_de_bolha(contas_do_andar(0))
	_temperatura = minf(_aquecimento, _bolha_do_fundo)


## A cada INTERVALO_DE_EMISSAO, um lugar que ferve solta uma molécula, da
## substância que o vapor dele pede.
func _ferver(andar: int, delta: float) -> void:
	_proxima_emissao[andar] = maxf(_proxima_emissao[andar] - delta, 0.0)
	if _proxima_emissao[andar] > 0.0 or not fervendo(andar):
		return
	var escolhida := _escolher_quem_evapora(andar, _credito_vapor[andar])
	if escolhida == null:
		return
	_proxima_emissao[andar] = INTERVALO_DE_EMISSAO
	_soltar(escolhida)


## Uma molécula do líquido do andar, de uma substância escolhida na proporção
## do vapor dele: a de cima (e, entre as de cima, a mais à esquerda). null se
## não há. Só o lugar dela na fileira conta: quem está no meio de um pulo conta
## igual (o vai-e-volta não muda nada na conta).
func _escolher_quem_evapora(andar: int, creditos: Dictionary) -> Particula:
	var paradas := _liquidas_paradas(andar)
	if paradas.is_empty():
		return null
	var tipo := EquilibrioLiquidoVapor.escolher(
		EquilibrioLiquidoVapor.vapor(_contar(paradas), temperatura_do_andar(andar)), creditos)
	var escolhida: Particula = null
	for p in paradas:
		if p.tipo != tipo:
			continue
		if escolhida == null or p.alvo.y < escolhida.alvo.y - 1.0 \
				or (absf(p.alvo.y - escolhida.alvo.y) <= 1.0 and p.alvo.x < escolhida.alvo.x):
			escolhida = p
	return escolhida


## Quem dá o próximo pulo do vai-e-volta: a substância na proporção do vapor
## (como numa evaporação de verdade), a molécula sorteada entre as da
## superfície. É só enfeite: usa o sorteio do enfeite.
func _escolher_quem_pula(andar: int) -> Particula:
	var paradas := _liquidas_paradas(andar)
	if paradas.is_empty():
		return null
	var tipo := EquilibrioLiquidoVapor.escolher(
		EquilibrioLiquidoVapor.vapor(_contar(paradas), temperatura_do_andar(andar)), _credito_pulo[andar])
	var de_cima := INF
	for p in paradas:
		if p.tipo == tipo:
			de_cima = minf(de_cima, p.alvo.y)
	var candidatas: Array[Particula] = []
	for p in paradas:
		if p.tipo == tipo and p.alvo.y <= de_cima + 1.0 and p.pulo <= 0.0:
			candidatas.append(p)
	if candidatas.is_empty():
		return null
	return candidatas[_enfeite.randi_range(0, candidatas.size() - 1)]


func _liquidas_paradas(andar: int) -> Array[Particula]:
	var paradas: Array[Particula] = []
	for p: Particula in _pocas[andar]:
		if p.estado == Estado.LIQUIDA:
			paradas.append(p)
	return paradas


func _contar(particulas: Array[Particula]) -> Dictionary:
	var contas := {}
	for p in particulas:
		contas[p.tipo] = int(contas.get(p.tipo, 0)) + 1
	return contas


## O vai-e-volta da superfície: no ritmo da pressão de vapor do líquido, uma
## molécula pula para fora e volta (a evaporação e a condensação juntas).
func _pular(andar: int, delta: float) -> void:
	_proximo_pulo[andar] -= delta
	if _proximo_pulo[andar] > 0.0:
		return
	var pressao := minf(pressao_do_andar(andar), 2.0)
	if pressao < 0.02 or _pocas[andar].is_empty():
		_proximo_pulo[andar] = 0.5
		return
	# Um pouco irregular, para não marcar compasso.
	_proximo_pulo[andar] = _enfeite.randf_range(0.7, 1.3) / (PULOS_POR_SEGUNDO * maxf(ritmo_dos_pulos, 0.01) * pressao)
	var p := _escolher_quem_pula(andar)
	if p != null:
		p.pulo = DURACAO_DO_PULO


## A molécula sai do líquido do andar e sobe para o de cima (ou, no topo, vira
## gás solto ali mesmo).
func _soltar(p: Particula) -> void:
	var de_onde := p.andar
	_pocas[de_onde].erase(p)
	_arrumar_a_poca(de_onde)
	if not _ja_ferveu.has(p.tipo):
		_ja_ferveu[p.tipo] = true
		_pulsos[de_onde] = 1.0
		ferveu.emit(p.tipo)
	for i in 3:
		_soltar_fumaca(p.pos + Vector2(0.0, -6.0), Vector2(0.0, -30.0))
	p.tamanho = 1.0
	p.pulo = 0.0
	# Sai do lugar dela na fileira (e o balanço do voo começa do zero): o
	# caminho não depende de onde o enfeite a deixou.
	p.pos = p.alvo
	p.relogio = 0.0
	if de_onde >= andares() - 1:
		_ficar_solta(p, de_onde)
	else:
		_subir_para(p, de_onde + 1)
	mudou.emit()


## Manda a molécula, que está no andar de baixo, para o andar "destino": até
## debaixo da fenda, por dentro dela, e até uma altura de voo lá em cima.
func _subir_para(p: Particula, destino: int) -> void:
	var de := destino - 1
	var fenda := _arte.meio_da_fenda(de) * ESCALA + _sorteio.randf_range(-FOLGA_NA_FENDA, FOLGA_NA_FENDA)
	var pontos := PackedVector2Array()
	pontos.append(Vector2(fenda, _altura_de_voo(de)))
	pontos.append(Vector2(fenda, _altura_de_voo(destino)))
	p.caminho = pontos
	p.passo = 0
	p.andar = destino
	p.estado = Estado.SUBINDO
	p.vel = Vector2(0.0, -VELOCIDADE_SUBINDO * 0.5)
	p.proxima_fumaca = 0.0


## Uma altura para atravessar o andar: acima do líquido, abaixo do teto.
func _altura_de_voo(andar: int) -> float:
	var teto := _arte.teto_do_andar(andar) * ESCALA + FOLGA + 4.0
	var tona := _tona_do_andar(andar) - FOLGA - 6.0
	if andar >= andares() - 1:
		# No andar de cima, perto da bandeja: é ali que ela pode virar líquido.
		teto = maxf(teto, tona - 70.0)
	return _sorteio.randf_range(minf(teto, tona), tona)


## A altura da tona do líquido do andar agora (ou do chão, sem líquido).
func _tona_do_andar(andar: int) -> float:
	return _arte.chao_do_andar(andar) * ESCALA - _altura_do_liquido(andar)


func _altura_do_liquido(andar: int) -> float:
	return float(_fileiras[andar]) * ALTURA_DA_FILEIRA + (2.0 if _fileiras[andar] > 0 else 0.0)


## Chegou no andar para onde subia. No topo, o resfriador a condensa se ela
## cabe no líquido de lá; senão fica gás. Numa bandeja, se ela encosta no
## líquido, condensa nele (e, se a bandeja passar do ponto de bolha, ela ferve
## de novo, soltando a mais volátil); numa bandeja seca, só condensa se o andar
## está no ponto de ebulição dela ou abaixo. Não condensando, segue subindo.
func _chegar(p: Particula) -> void:
	var andar := p.andar
	if andar >= andares() - 1:
		if _cabe_no_topo(p.tipo):
			_mergulhar(p)
		else:
			_ficar_solta(p, andar)
	elif _encosta(andar, p.tipo) and (not _pocas[andar].is_empty() \
			or EquilibrioLiquidoVapor.cabe({}, p.tipo, temperatura_do_andar(andar))):
		_mergulhar(p)
	else:
		_subir_para(p, andar + 1)
	mudou.emit()


## O vapor que passa pela bandeja condensa nela? Perto do ponto de ebulição
## dele, só a fração "eficiencia" (a que encosta no líquido); num andar
## bem mais frio que o ponto de ebulição dele, quase sempre (ele esfria na
## passagem e vira gota de qualquer jeito). Sem sorteio: na proporção certa.
func _encosta(andar: int, tipo: String) -> bool:
	var vontade := clampf(EquilibrioLiquidoVapor.volatilidade(tipo, temperatura_do_andar(andar)), 0.0, 1.0)
	_credito_contato[andar] += 1.0 - (1.0 - eficiencia) * vontade
	if _credito_contato[andar] >= 1.0 - 0.0001:
		_credito_contato[andar] -= 1.0
		return true
	return false


## O líquido do topo, na temperatura do topo, recebe mais esta molécula sem
## ferver?
func _cabe_no_topo(tipo: String) -> bool:
	var topo := andares() - 1
	return EquilibrioLiquidoVapor.cabe(contas_do_andar(topo), tipo, temperatura_do_andar(topo))


func _mergulhar(p: Particula, do_vapor: bool = true) -> void:
	_pocas[p.andar].append(p)
	p.estado = Estado.MERGULHANDO
	p.vel = Vector2.ZERO
	p.do_vapor = do_vapor
	p.pulo = 0.0
	_arrumar_a_poca(p.andar)


func _ficar_solta(p: Particula, andar: int) -> void:
	p.andar = andar
	p.estado = Estado.SOLTA
	p.vel = Vector2.from_angle(_sorteio.randf_range(PI * 0.75, PI * 1.25)) * VELOCIDADE_SOLTA
	p.proxima_conferida = INTERVALO_DO_GAS_SOLTO


## Quantas moléculas o líquido do andar segura antes de transbordar.
func _capacidade(andar: int) -> int:
	if andar == 0:
		return 1 << 30
	if andar >= andares() - 1:
		return _quantas_cabem(andar, FILEIRAS_NO_TOPO)
	return CAPACIDADE_DA_BANDEJA


## O líquido do andar passou do que ele segura: uma molécula (na proporção do
## líquido) escorre pela borda, cai pela fenda e vai para o andar de baixo.
func _transbordar(andar: int) -> void:
	var paradas: Array[Particula] = []
	for p: Particula in _pocas[andar]:
		if p.estado == Estado.LIQUIDA:
			paradas.append(p)
	if paradas.is_empty():
		return
	var contas := {}
	for p in paradas:
		contas[p.tipo] = int(contas.get(p.tipo, 0)) + 1
	var tipo := EquilibrioLiquidoVapor.escolher(contas, _credito_transbordo[andar])
	# A que está mais perto da borda (o lado da fenda) é a que escorre.
	var beira := _beira_da_bandeja(andar)
	var escolhida: Particula = null
	for p in paradas:
		if p.tipo == tipo and (escolhida == null or absf(p.alvo.x - beira) < absf(escolhida.alvo.x - beira)):
			escolhida = p
	if escolhida == null:
		return
	escolhida.pulo = 0.0
	escolhida.pos = escolhida.alvo
	escolhida.relogio = 0.0
	_pocas[andar].erase(escolhida)
	_arrumar_a_poca(andar)
	var de_baixo := andar - 1
	var fenda := _arte.meio_da_fenda(de_baixo) * ESCALA
	var pontos := PackedVector2Array()
	pontos.append(Vector2(beira, _tona_do_andar(andar) - 4.0))
	pontos.append(Vector2(fenda, _arte.chao_do_andar(andar) * ESCALA + FOLGA))
	pontos.append(Vector2(fenda, _altura_de_voo(de_baixo)))
	escolhida.caminho = pontos
	escolhida.passo = 0
	escolhida.andar = de_baixo
	escolhida.estado = Estado.PINGANDO
	escolhida.vel = Vector2.ZERO
	mudou.emit()


## O x (px de tela) da borda solta da bandeja que é o chão do andar: a ponta
## do lado da fenda, por onde o líquido escorre.
func _beira_da_bandeja(andar: int) -> float:
	var poca := _largura_da_poca(andar)
	var bandeja: Dictionary = _arte.bandejas[mini(andar, _arte.bandejas.size()) - 1]
	return poca.x + FOLGA if int(bandeja["lado"]) < 0 else poca.y - FOLGA


func _mover(p: Particula, delta: float) -> void:
	p.relogio += delta
	p.tamanho = minf(p.tamanho + delta / 0.16, 1.0)
	match p.estado:
		Estado.LIQUIDA:
			p.pos.x = lerpf(p.pos.x, p.alvo.x, 1.0 - exp(-5.0 * delta))
			p.pos.y = lerpf(p.pos.y, p.alvo.y + sin(p.relogio * 2.6), 1.0 - exp(-10.0 * delta))
			if p.pulo > 0.0:
				p.pulo = maxf(p.pulo - delta, 0.0)
				if p.pulo <= 0.0:
					_respingar(Vector2(p.pos.x, _tona_do_andar(p.andar)),
						MisturasDoDestilador.substancia(p.tipo)["tona"])
		Estado.SUBINDO:
			_avancar_no_caminho(p, delta, VELOCIDADE_SUBINDO, true)
		Estado.PINGANDO:
			_avancar_no_caminho(p, delta, VELOCIDADE_PINGANDO, false)
		Estado.MERGULHANDO:
			var distancia := p.pos.distance_to(p.alvo)
			p.pos = p.pos.move_toward(p.alvo, maxf(60.0, distancia * 4.5) * delta)
			if distancia < 1.5:
				p.estado = Estado.LIQUIDA
				_respingar(Vector2(p.pos.x, _tona_do_andar(p.andar)),
					MisturasDoDestilador.substancia(p.tipo)["tona"])
				_pulsos[p.andar] = 1.0
				if p.do_vapor:
					condensou.emit(p.tipo, p.andar)
				mudou.emit()
		Estado.SOLTA:
			_quicar(p, delta)
			p.proxima_conferida -= delta
			if p.proxima_conferida <= 0.0:
				p.proxima_conferida = INTERVALO_DO_GAS_SOLTO
				_conferir_a_solta(p)


## Segue o caminho da molécula (subindo como gás, ou escorrendo como líquido).
## No fim dele: o gás chega no andar; o líquido mergulha no andar de baixo.
func _avancar_no_caminho(p: Particula, delta: float, velocidade: float, gas: bool) -> void:
	var alvo := p.caminho[p.passo]
	var para_la := alvo - p.pos
	if para_la.length() < 10.0:
		p.passo += 1
		if p.passo >= p.caminho.size():
			if gas:
				_chegar(p)
			else:
				_mergulhar(p, false)
			return
		alvo = p.caminho[p.passo]
		para_la = alvo - p.pos
	var direcao := para_la.normalized()
	if not gas:
		p.vel = p.vel.lerp(direcao * velocidade, 1.0 - exp(-12.0 * delta))
		p.pos += p.vel * delta
		return
	# O gás não anda em linha reta: balança de um lado para o outro do rumo.
	var balanco := direcao.orthogonal() * sin(p.relogio * 7.0) * 26.0
	p.vel = p.vel.lerp(direcao * velocidade + balanco, 1.0 - exp(-9.0 * delta))
	p.pos += p.vel * delta
	p.proxima_fumaca -= delta
	if p.proxima_fumaca <= 0.0:
		p.proxima_fumaca = 0.09
		_soltar_fumaca(p.pos, p.vel * 0.25)


## Gás solto num andar: anda reto e bate nas paredes, no teto e no líquido.
func _quicar(p: Particula, delta: float) -> void:
	p.pos += p.vel * delta
	var teto := _arte.teto_do_andar(p.andar) * ESCALA + FOLGA
	var chao := _tona_do_andar(p.andar) - FOLGA
	if p.pos.y < teto:
		p.pos.y = teto
		p.vel.y = absf(p.vel.y)
	elif p.pos.y > chao:
		p.pos.y = chao
		p.vel.y = -absf(p.vel.y)
	var paredes := _arte.paredes_em((p.pos.y - FOLGA * 0.6) / ESCALA) * ESCALA
	if paredes.y - paredes.x < FOLGA * 2.5:
		# Lá no alto da cúpula não cabe: volta para baixo.
		p.vel.y = absf(p.vel.y)
		paredes = _arte.paredes_em((p.pos.y + FOLGA) / ESCALA) * ESCALA
	if p.pos.x < paredes.x + FOLGA:
		p.pos.x = paredes.x + FOLGA
		p.vel.x = absf(p.vel.x)
	elif p.pos.x > paredes.y - FOLGA:
		p.pos.x = paredes.y - FOLGA
		p.vel.x = -absf(p.vel.x)


## O gás solto do topo confere se o líquido de lá já o recebe.
func _conferir_a_solta(p: Particula) -> void:
	if _cabe_no_topo(p.tipo):
		_mergulhar(p)
		mudou.emit()


# ─────────────────────────────────────────────────────────────
# AS POÇAS (o líquido de cada andar)
# ─────────────────────────────────────────────────────────────

func _tem_liquida(andar: int) -> bool:
	for p: Particula in _pocas[andar]:
		if p.estado == Estado.LIQUIDA:
			return true
	return false


func _fileiras_que_cabem(andar: int) -> int:
	if andar == 0:
		return FILEIRAS_NO_FUNDO
	return FILEIRAS_NO_TOPO if andar >= andares() - 1 else FILEIRAS_NA_BANDEJA


## De que x a que x vai a poça do andar, em px de tela.
func _largura_da_poca(andar: int) -> Vector2:
	return _arte.poca_do_andar(andar) * ESCALA


## As fileiras em que as moléculas da poça se arrumam: cada uma é a lista das
## que cabem lado a lado. "mais" é uma molécula a mais, para conferir se cabe.
func _em_fileiras(andar: int, mais: Particula = null) -> Array:
	var poca := _largura_da_poca(andar)
	var cabe := poca.y - poca.x
	var todas: Array = _pocas[andar].duplicate()
	if mais != null:
		todas.append(mais)
	var fileiras: Array = [[]]
	var ocupado := 0.0
	for p: Particula in todas:
		var largura := MoleculasDoDestilador.largura_deitada(p.tipo) + ENTRE_MOLECULAS
		if ocupado + largura > cabe and not (fileiras[-1] as Array).is_empty():
			fileiras.append([])
			ocupado = 0.0
		(fileiras[-1] as Array).append(p)
		ocupado += largura
	return fileiras


## Quantas moléculas cabem em "fileiras" fileiras da poça do andar, com as
## moléculas que ela tem agora (as mais largas ocupam mais).
func _quantas_cabem(andar: int, fileiras: int) -> int:
	var poca := _largura_da_poca(andar)
	var cabe := poca.y - poca.x
	var mais_larga := 12.0
	for p: Particula in _pocas[andar]:
		mais_larga = maxf(mais_larga, MoleculasDoDestilador.largura_deitada(p.tipo))
	return maxi(1, int(cabe / (mais_larga + ENTRE_MOLECULAS))) * fileiras


## O lugar de cada molécula no líquido do andar: em fileiras, de baixo para
## cima, espalhadas por igual de parede a parede.
func _arrumar_a_poca(andar: int) -> void:
	var poca := _largura_da_poca(andar)
	var base := _arte.chao_do_andar(andar) * ESCALA
	var fileiras := _em_fileiras(andar)
	var com_gente := 0
	for i in fileiras.size():
		var fileira: Array = fileiras[i]
		if fileira.is_empty():
			continue
		com_gente += 1
		# Da esquerda para a direita, na ordem em que já estão: ninguém passa por
		# cima de ninguém para se arrumar.
		fileira.sort_custom(func(a: Particula, b: Particula) -> bool: return a.pos.x < b.pos.x)
		for j in fileira.size():
			var p: Particula = fileira[j]
			p.alvo = Vector2(poca.x + (j + 0.5) * (poca.y - poca.x) / fileira.size(),
				base - ALTURA_DA_FILEIRA * (i + 0.5))
	_fileiras[andar] = com_gente


## A substância do líquido do andar, se for uma só ("" misturado ou vazio).
func substancia_do_andar(andar: int) -> String:
	var achada := ""
	for p: Particula in _pocas[andar]:
		if p.estado != Estado.LIQUIDA:
			continue
		if achada != "" and achada != p.tipo:
			return ""
		achada = p.tipo
	return achada


## A cor do líquido do andar: a de cada substância, misturadas na proporção
## delas ("liquido" ou "tona"). Um líquido rico em nitrogênio é quase verde.
func cor_do_liquido(andar: int, campo: String) -> Color:
	var contas := {}
	var total := 0
	for p: Particula in _pocas[andar]:
		if p.estado == Estado.LIQUIDA:
			contas[p.tipo] = int(contas.get(p.tipo, 0)) + 1
			total += 1
	if total == 0:
		return COR_MISTURA if campo == "liquido" else COR_TONA_MISTURA
	var cor := Color(0, 0, 0, 0)
	for chave: String in contas:
		var dela: Color = MisturasDoDestilador.substancia(chave)[campo]
		var peso := float(contas[chave]) / float(total)
		cor += Color(dela.r * peso, dela.g * peso, dela.b * peso, dela.a * peso)
	return cor


# ─────────────────────────────────────────────────────────────
# BOLHAS, FUMAÇA E RESPINGOS
# ─────────────────────────────────────────────────────────────

func _passo_das_bolhas(delta: float) -> void:
	var tona := _tona_do_andar(0)
	var fervendo_agora := fervendo(0)
	for i in range(_bolhas.size() - 1, -1, -1):
		var bolha := _bolhas[i]
		bolha.y -= bolha.z * delta
		if bolha.y <= tona + 3.0:
			if fervendo_agora:
				_soltar_fumaca(Vector2(bolha.x, tona - 4.0), Vector2(0.0, -34.0))
			_bolhas.remove_at(i)
		else:
			_bolhas[i] = bolha
	if not fervendo_agora or _altura_do_liquido(0) < 8.0:
		return
	_proxima_bolha -= delta
	if _proxima_bolha <= 0.0:
		_proxima_bolha = _enfeite.randf_range(0.07, 0.16)
		var largura := tamanho_da_coluna().x
		_bolhas.append(Vector3(_enfeite.randf_range(ESCALA * 2.0, largura - ESCALA * 3.0),
			_arte.chao_do_andar(0) * ESCALA - 4.0, _enfeite.randf_range(42.0, 70.0)))


func _soltar_fumaca(pos: Vector2, vel: Vector2) -> void:
	if _fumaca.size() > 220:
		return
	_fumaca.append({"pos": pos + Vector2(_enfeite.randf_range(-4.0, 4.0), _enfeite.randf_range(-4.0, 4.0)),
		"vel": vel + Vector2(_enfeite.randf_range(-10.0, 10.0), _enfeite.randf_range(-16.0, -4.0)),
		"idade": 0.0, "vida": _enfeite.randf_range(0.9, 1.4)})


func _passo_da_fumaca(delta: float) -> void:
	for i in range(_fumaca.size() - 1, -1, -1):
		var f := _fumaca[i]
		f["idade"] += delta
		if f["idade"] >= f["vida"]:
			_fumaca.remove_at(i)
			continue
		f["pos"] += f["vel"] * delta
		f["vel"] *= exp(-1.4 * delta)


func _respingar(pos: Vector2, cor: Color) -> void:
	for lado: float in [-1.0, 0.0, 1.0]:
		_respingos.append({"pos": pos + Vector2(lado * 6.0, 0.0),
			"vel": Vector2(lado * _enfeite.randf_range(26.0, 44.0), _enfeite.randf_range(-95.0, -70.0)),
			"idade": 0.0, "cor": cor})


func _passo_dos_respingos(delta: float) -> void:
	for i in range(_respingos.size() - 1, -1, -1):
		var r := _respingos[i]
		r["idade"] += delta
		if r["idade"] >= 0.38:
			_respingos.remove_at(i)
			continue
		r["vel"] += Vector2(0.0, 420.0) * delta
		r["pos"] += r["vel"] * delta


# ─────────────────────────────────────────────────────────────
# DESENHO
# ─────────────────────────────────────────────────────────────

func _draw() -> void:
	if _arte == null or _arte.textura == null:
		return
	var tamanho := tamanho_da_coluna()
	draw_texture_rect_region(_arte.textura, Rect2(Vector2.ZERO, tamanho), Rect2(_arte.recorte_do_raio_x))
	if _mistura.is_empty():
		return
	_desenhar_o_calor()
	_desenhar_a_serpentina()
	_desenhar_os_liquidos()
	_desenhar_as_bolhas()
	_desenhar_a_fumaca()
	_desenhar_as_moleculas()
	for r in _respingos:
		var pos: Vector2 = r["pos"]
		draw_rect(Rect2((pos / 2.0).floor() * 2.0, Vector2(4, 4)), r["cor"])
	# Paredes e bandejas por cima: nada passa na frente delas.
	if _arte.linhas != null:
		draw_texture_rect(_arte.linhas, Rect2(Vector2.ZERO, tamanho), false)
	_desenhar_a_regua()
	_desenhar_as_plaquinhas()


## O calor entrando por baixo: setinhas laranja entre os pés. Quando o
## termômetro pede mais do que o fundo tem (esquentando, ou fervendo), elas
## sobem um pixel e voltam.
func _desenhar_o_calor() -> void:
	var esquentando := _pedida > _temperatura + FOLGA_DE_TEMPERATURA
	var sobe := int(_relogio * 3.0) % 2 if esquentando else 0
	var cor := COR_DO_CALOR_CLARA if sobe == 1 else COR_DO_CALOR
	if not esquentando:
		cor = Color(cor, 0.45)
	var y := float(_arte.piso + 3 - sobe) * ESCALA
	for vao in _arte.vaos_dos_pes:
		var x := vao.x + 1
		while x + 2 <= vao.y:
			draw_rect(Rect2((x + 1) * ESCALA, y, ESCALA, ESCALA), cor)
			draw_rect(Rect2(x * ESCALA, y + ESCALA, ESCALA, ESCALA), cor)
			draw_rect(Rect2((x + 2) * ESCALA, y + ESCALA, ESCALA, ESCALA), cor)
			x += 5


## O resfriador: um fio em zigue-zague dentro da cúpula, piscando em azul de gelo.
func _desenhar_a_serpentina() -> void:
	var s := _arte.serpentina
	if not s.has_area():
		return
	var zigue: Array[int] = [0, 1, 2, 1]
	for x in range(s.position.x, s.end.x):
		var pisca := (x + int(_relogio * 9.0)) % 3 == 0
		draw_rect(Rect2(x * ESCALA, (s.position.y + zigue[(x - s.position.x) % 4]) * ESCALA, ESCALA, ESCALA),
			COR_SERPENTINA_CLARA if pisca else COR_SERPENTINA)


func _desenhar_os_liquidos() -> void:
	for andar in _pocas.size():
		if _niveis[andar] <= 0.0 or _fileiras[andar] <= 0:
			continue
		var poca := _largura_da_poca(andar)
		var altura := roundf(_altura_do_liquido(andar) * _niveis[andar])
		var cor := cor_do_liquido(andar, "liquido")
		var tona := cor_do_liquido(andar, "tona")
		var caixa := Rect2(poca.x, _arte.chao_do_andar(andar) * ESCALA - altura, poca.y - poca.x, altura)
		draw_rect(caixa, cor)
		# A tona em ondinhas de 2 px que andam.
		var onda := int(_relogio * 3.0)
		var x := caixa.position.x
		var i := 0
		while x < caixa.end.x:
			var sobe := 2.0 if (i + onda) % 3 == 0 else 0.0
			draw_rect(Rect2(x, caixa.position.y - sobe, minf(8.0, caixa.end.x - x), 2.0), tona)
			x += 8.0
			i += 1


func _desenhar_as_bolhas() -> void:
	var cor := Color(COR_TONA_MISTURA, 0.85)
	for bolha in _bolhas:
		var canto := Vector2(roundf(bolha.x), roundf(bolha.y))
		draw_rect(Rect2(canto + Vector2(2, 0), Vector2(4, 2)), cor)
		draw_rect(Rect2(canto + Vector2(2, 6), Vector2(4, 2)), cor)
		draw_rect(Rect2(canto + Vector2(0, 2), Vector2(2, 4)), cor)
		draw_rect(Rect2(canto + Vector2(6, 2), Vector2(2, 4)), cor)


## O gás, como na coluna da história: cada fiapo de fumaça soma névoa nos
## pixels da arte em volta dele, e a névoa vira desenho em dois tons chapados
## com a beirada pontilhada, na cor da temperatura do andar.
func _desenhar_a_fumaca() -> void:
	if _fumaca.is_empty():
		return
	var largura := _arte.tamanho().x
	var altura := _arte.tamanho().y
	_nevoa.fill(0.0)
	var topo := altura
	var base := -1
	for f in _fumaca:
		var t: float = f["idade"] / f["vida"]
		var raio := lerpf(1.5, 3.3, t)
		var forca := minf(t * 8.0, 1.0) * (1.0 - t * t)
		var meio: Vector2 = f["pos"] / ESCALA
		var y0 := maxi(0, floori(meio.y - raio))
		var y1 := mini(altura - 1, ceili(meio.y + raio))
		topo = mini(topo, y0)
		base = maxi(base, y1)
		for y in range(y0, y1 + 1):
			for x in range(maxi(0, floori(meio.x - raio)), mini(largura - 1, ceili(meio.x + raio)) + 1):
				var d := (Vector2(x + 0.5, y + 0.5) - meio).length_squared() / (raio * raio)
				if d < 1.0:
					_nevoa[y * largura + x] += forca * (1.0 - d)
	var andar_da_cor := -1
	var fraco := Color()
	var forte := Color()
	for y in range(topo, base + 1):
		if _arte.andar_da_linha[y] != andar_da_cor:
			andar_da_cor = _arte.andar_da_linha[y]
			var cor := cor_da_temperatura(temperatura_do_andar(andar_da_cor)).lightened(0.3)
			fraco = Color(cor, 0.24)
			forte = Color(cor, 0.46)
		var x := 0
		while x < largura:
			var tom := _tom_da_nevoa(x, y, largura)
			if tom == 0:
				x += 1
				continue
			var x0 := x
			while x < largura and _tom_da_nevoa(x, y, largura) == tom:
				x += 1
			draw_rect(Rect2(x0 * ESCALA, y * ESCALA, (x - x0) * ESCALA, ESCALA), forte if tom == 2 else fraco)


func _tom_da_nevoa(x: int, y: int, largura: int) -> int:
	var i := y * largura + x
	if _arte.e_miolo[i] == 0:
		return 0
	var n := _nevoa[i]
	if n >= NEVOA_FORTE:
		return 2
	if n >= NEVOA_FRACA:
		return 1
	if n >= NEVOA_PONTILHADA and (x + y) % 2 == 0:
		return 1
	return 0


func _desenhar_as_moleculas() -> void:
	for p in _particulas:
		var quadro := 0
		var onde := p.pos
		if p.estado == Estado.SUBINDO or p.estado == Estado.SOLTA:
			quadro = int(p.relogio * p.giro) % MoleculasDoDestilador.QUADROS
		elif p.estado == Estado.LIQUIDA and p.pulo > 0.0:
			# No pulo ela é vapor por um instante: sobe girando e cai de volta.
			var t := 1.0 - p.pulo / DURACAO_DO_PULO
			onde.y -= ALTURA_DO_PULO * 4.0 * t * (1.0 - t)
			quadro = int(p.relogio * p.giro) % MoleculasDoDestilador.QUADROS
		MoleculasDoDestilador.desenhar(self, p.tipo, onde, quadro)


## A régua de temperatura, colada na parede esquerda: um trecho por andar, da
## cor da temperatura dele agora.
func _desenhar_a_regua() -> void:
	var x := -(DISTANCIA_DA_REGUA + LARGURA_DA_REGUA)
	var de_cima := _arte.trecho_da_regua(andares() - 1).x * ESCALA
	var de_baixo := _arte.trecho_da_regua(0).y * ESCALA
	draw_rect(Rect2(x - 2.0, de_cima - 2.0, LARGURA_DA_REGUA + 4.0, de_baixo - de_cima + 4.0), EstiloHUD.CONTORNO)
	for andar in andares():
		var trecho := _arte.trecho_da_regua(andar) * ESCALA
		var folga := 0.0 if andar == 0 else 2.0
		draw_rect(Rect2(x, trecho.x, LARGURA_DA_REGUA, trecho.y - trecho.x - folga),
			cor_da_temperatura(temperatura_do_andar(andar)))


## Uma plaquinha de temperatura por andar, à esquerda da régua. A do andar em
## que uma substância é a maioria toma a cor dela; em cima da do topo vai o
## nome do resfriador, e embaixo da do fundo, de onde vem o calor.
func _desenhar_as_plaquinhas() -> void:
	var topo := andares() - 1
	for andar in andares():
		var texto := MisturasDoDestilador.graus(roundf(temperatura_do_andar(andar)))
		var dona := dono_do_andar(andar)
		var papel: Color = MisturasDoDestilador.substancia(dona)["tona"] if dona != "" else EstiloHUD.PAPEL
		var lugar := lugar_da_plaquinha(andar)
		var largura := PecasDoLaboratorio.retangulo_da_plaquinha(Vector2.ZERO, texto).size.x
		var caixa := PecasDoLaboratorio.plaquinha(self, Vector2(lugar.x - largura * 0.5, lugar.y), texto, 22,
			papel, 1.0, sin(_pulsos[andar] * PI) * 5.0)
		if andar == topo and topo > 0:
			_legenda(Vector2(caixa.get_center().x, caixa.position.y), LEGENDA_DO_RESFRIADOR, false)
		elif andar == 0:
			_legenda(Vector2(caixa.get_center().x, caixa.end.y), String(_mistura.get("calor", "")), true)


## Letra miúda e clara, com contorno, centrada em cima de um ponto (ou embaixo).
func _legenda(meio: Vector2, texto: String, embaixo: bool) -> void:
	var linhas := texto.split("\n")
	for i in linhas.size():
		var largura := FONTE.get_string_size(linhas[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var y := meio.y + 18.0 + i * 15.0 if embaixo else meio.y - 9.0 - (linhas.size() - 1 - i) * 15.0
		EstiloHUD.rotulo(self, FONTE, Vector2(roundf(meio.x - largura * 0.5), y), linhas[i], 11, EstiloHUD.CLARO)
