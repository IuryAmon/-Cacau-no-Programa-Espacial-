class_name ColunaDoSimulador
extends Control

# --- A COLUNA DO SIMULADOR DE DESTILAÇÃO (Laboratório) ---
#
# A coluna de destilação da fase do nitrogênio, em raio X, virada brinquedo: em
# vez de o Dr. Chico contar a história de uma mistura só (o ar, em
# scripts/ui/coluna_destilacao.gd), aqui entra a mistura que a pessoa escolher
# (MisturasDoDestilador) e quem manda na temperatura é ela, pelo termômetro.
#
# A CONTA É UMA SÓ, e é a de qualquer destilação:
#
#   * Quem manda é o PONTO DE EBULIÇÃO de cada substância: mais quente que ele,
#     ela é gás; mais fria, líquido.
#   * O termômetro diz a temperatura do FUNDO, onde a mistura líquida está. O
#     TOPO é segurado pelo RESFRIADOR, numa temperatura fixa. Os andares do
#     meio ficam repartidos por igual entre uma e outra: mais quente embaixo,
#     mais frio em cima. (Com o fundo mais frio que o resfriador, a coluna
#     inteira fica na temperatura do fundo: o resfriador só tira calor.)
#   * A molécula que está num andar mais quente que o ponto de ebulição dela
#     FERVE: vira gás e sobe pela fenda da bandeja.
#   * Subindo, ela passa por andares cada vez mais frios. No primeiro que está
#     no ponto de ebulição dela ou abaixo, CONDENSA: vira líquido e fica na
#     bandeja dali.
#   * A que nem o topo consegue condensar (o resfriador não é frio o bastante
#     para ela) fica gás lá em cima: é a que sai da coluna como gás.
#
# Nada disso é encenado: cada molécula decide sozinha, a cada instante, com a
# temperatura do andar em que está. Subir o termômetro faz ferver o que estava
# parado; subir demais esquenta os andares do meio e manda para o mesmo andar
# duas substâncias que estavam separadas. Baixar o termômetro esfria os
# andares, mas o que já virou líquido numa bandeja fica nela (para recomeçar,
# reiniciar()).
#
# É UM MODELO SIMPLIFICADO, e a tela diz isso: numa mistura de verdade a
# fervura não é tudo ou nada (o vapor sai mais rico na substância que ferve
# mais fácil, e as bandejas existem para repetir esse enriquecimento), e o
# líquido que sobra numa bandeja escorre para a de baixo.
#
# A MISTURA ESTÁ SEPARADA quando a coluna assentou (o fundo chegou à
# temperatura pedida e ninguém está subindo, descendo ou prestes a ferver),
# cada substância está inteira num lugar só (o líquido de um andar, ou o gás
# do topo) e nenhum lugar tem duas.
#
# A arte é a mesma da história ("coluna de destilação.png"), lida pela
# ArteDaColuna; as moléculas vêm de MoleculasDoDestilador.
#
# COMO USAR:
#   coluna.definir_mistura(MisturasDoDestilador.mistura("ar"))
#   coluna.pedir_temperatura(-183.0)     o que o termômetro pede
#   coluna.temperatura()                 a do fundo agora (ela vai atrás)
#   coluna.separada(), coluna.onde_esta("N2")...
#
# COMO EDITAR NO EDITOR: o canto do nó é o canto da coluna, que é desenhada no
# tamanho da arte vezes ESCALA. À esquerda dela vão a régua e as plaquinhas de
# temperatura (uns 180 px); embaixo, o nome de onde vem o calor.

## Uma substância começou a ferver (a primeira molécula dela virou gás).
signal ferveu(substancia: String)
## Uma molécula da substância virou líquido num andar.
signal condensou(substancia: String, andar: int)
## A mistura acabou de ficar separada.
signal separou
## Alguma molécula mudou de estado ou de andar: as fichas da tela se atualizam.
signal mudou

enum Estado { LIQUIDA, SUBINDO, MERGULHANDO, SOLTA }

## As duas fases em que uma substância pode ficar parada num andar, e o "lugar"
## de quem está mudando de andar (ver onde_esta).
const LIQUIDO := 0
const GAS := 1
const A_CAMINHO := Vector2i(-1, -1)

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")

## Quantos px de tela vale cada pixel da arte da coluna.
const ESCALA := 4.0
## Quanto tempo o fundo leva para ir de uma ponta à outra do termômetro.
const TEMPO_DE_PONTA_A_PONTA := 2.6
## Num andar que está fervendo, sai uma molécula a cada tanto.
const INTERVALO_DE_EMISSAO := 0.24
## De quanto em quanto o gás solto num andar confere se já pode virar líquido
## (ou se tem de subir mais).
const INTERVALO_DO_GAS_SOLTO := 0.4
## Velocidade do gás subindo e do gás solto (px de tela por segundo).
const VELOCIDADE_SUBINDO := 190.0
const VELOCIDADE_SOLTA := 96.0
## A folga mínima entre a temperatura e o ponto de ebulição para ferver: a
## molécula que está exatamente no ponto não ferve nem condensa de novo.
const FOLGA_DE_TEMPERATURA := 0.001

# ── Medidas (px de tela) ──
## Meia molécula: o quanto ela se afasta de parede, teto e líquido.
const FOLGA := 13.0
const FOLGA_NA_FENDA := 8.0
## De uma fileira de moléculas do líquido à seguinte, e quantas cabem.
const ALTURA_DA_FILEIRA := 14.0
const FILEIRAS_NO_FUNDO := 4
const FILEIRAS_NA_BANDEJA := 3
## Entre uma molécula e a vizinha, na fileira.
const ENTRE_MOLECULAS := 2.0
## A régua de temperatura, colada na parede esquerda da coluna.
const LARGURA_DA_REGUA := 12.0
const DISTANCIA_DA_REGUA := 4.0
const DISTANCIA_DA_PLAQUINHA := 6.0
const LEGENDA_DO_RESFRIADOR := "RESFRIADOR"

## O líquido de um andar com mais de uma substância misturada.
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


class Particula:
	var tipo: String = ""
	var estado: int = 0
	## O meio dela, em px de tela a partir do canto da coluna.
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	## O andar em que ela está (ou, subindo, o andar para onde vai).
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
var _pulsos := PackedFloat32Array()
var _temperatura: float = 20.0
var _pedida: float = 20.0
var _relogio: float = 0.0
var _ja_ferveu := {}
var _estava_separada: bool = false
var _fumaca: Array[Dictionary] = []
var _respingos: Array[Dictionary] = []
var _bolhas: Array[Vector3] = []
var _proxima_bolha: float = 0.0
var _nevoa := PackedFloat32Array()
var _sorteio := RandomNumberGenerator.new()


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
	_pulsos.resize(andares)
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
	_fumaca.clear()
	_respingos.clear()
	_bolhas.clear()
	_ja_ferveu.clear()
	_estava_separada = false
	_relogio = 0.0
	if _mistura.is_empty():
		queue_redraw()
		return
	_temperatura = float(_mistura["minima"])
	_pedida = _temperatura
	# Sempre a mesma mistura embaralhada: recomeçar dá o mesmo desenho.
	_sorteio.seed = 828
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


## A temperatura do fundo agora.
func temperatura() -> float:
	return _temperatura


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


## Quantas moléculas estão subindo ou mergulhando agora.
func em_transito() -> int:
	var conta := 0
	for p in _particulas:
		if p.estado == Estado.SUBINDO or p.estado == Estado.MERGULHANDO:
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


## Cada substância inteira num lugar só, nenhum lugar com duas, e tudo parado:
## a temperatura já chegou onde foi pedida e ninguém está para mudar de andar.
func separada() -> bool:
	if _mistura.is_empty() or em_transito() > 0 or not parada():
		return false
	var ocupados := {}
	for chave: String in _mistura["substancias"]:
		var lugar := lugar_de(chave)
		if lugar == A_CAMINHO or ocupados.has(lugar):
			return false
		ocupados[lugar] = chave
	return true


## A coluna assentou? O fundo está na temperatura pedida, nenhum líquido está
## num andar mais quente que o ponto de ebulição dele (prestes a ferver) e
## nenhum gás solto está para subir ou virar líquido. Sem isto, a mistura
## pareceria separada no instante em que uma bandeja inteira ainda vai ferver.
func parada() -> bool:
	if _mistura.is_empty() or not is_equal_approx(_temperatura, _pedida) or em_transito() > 0:
		return false
	var topo := andares() - 1
	for p in _particulas:
		if _ferve(p):
			return false
		if p.estado == Estado.SOLTA and (p.andar < topo or _condensa_em(p.tipo, p.andar)) 				and not (_condensa_em(p.tipo, p.andar) and not _cabe_na_poca(p.andar, p)):
			return false
	return true


## O que a substância está fazendo, numa frase curta (para a ficha dela).
func situacao_de(substancia: String) -> String:
	var lugares := onde_esta(substancia)
	if lugares.is_empty():
		return ""
	if lugares.has(A_CAMINHO):
		return "MUDANDO DE ANDAR"
	if lugares.size() > 1:
		return "ESPALHADA"
	var lugar: Vector2i = lugares.keys()[0]
	var topo := andares() - 1
	if lugar.y == GAS:
		return "GÁS NO TOPO" if lugar.x == topo else "GÁS NO %dº ANDAR" % lugar.x
	if lugar.x == 0:
		return "LÍQUIDO NO FUNDO"
	return "LÍQUIDO NO TOPO" if lugar.x == topo else "LÍQUIDO NO %dº ANDAR" % lugar.x


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
	_temperatura = move_toward(_temperatura, _pedida, faixa / TEMPO_DE_PONTA_A_PONTA * delta)

	for andar in _pocas.size():
		_ferver(andar, delta)
		_niveis[andar] = move_toward(_niveis[andar], 1.0 if _tem_liquida(andar) else 0.0, delta / 0.3)
		_pulsos[andar] = move_toward(_pulsos[andar], 0.0, delta / 0.5)
	for p in _particulas:
		_mover(p, delta)
	_passo_das_bolhas(delta)
	_passo_da_fumaca(delta)
	_passo_dos_respingos(delta)

	var agora := separada()
	if agora and not _estava_separada:
		separou.emit()
	_estava_separada = agora


## A molécula ferve quando o andar em que ela é líquido está mais quente que o
## ponto de ebulição dela.
func _ferve(p: Particula) -> bool:
	return p.estado == Estado.LIQUIDA \
		and MisturasDoDestilador.ebulicao(p.tipo) < temperatura_do_andar(p.andar) - FOLGA_DE_TEMPERATURA


## Neste andar a substância já é líquido (ele está no ponto de ebulição dela ou
## abaixo)?
func _condensa_em(tipo: String, andar: int) -> bool:
	return temperatura_do_andar(andar) <= MisturasDoDestilador.ebulicao(tipo) + FOLGA_DE_TEMPERATURA


func _ferver(andar: int, delta: float) -> void:
	_proxima_emissao[andar] -= delta
	if _proxima_emissao[andar] > 0.0:
		return
	var prontas: Array[Particula] = []
	for p: Particula in _pocas[andar]:
		if _ferve(p):
			prontas.append(p)
	if prontas.is_empty():
		return
	_proxima_emissao[andar] = INTERVALO_DE_EMISSAO
	# Sai uma das de cima: a que está mais alto no líquido.
	var escolhida := prontas[0]
	for p in prontas:
		if p.alvo.y < escolhida.alvo.y - 1.0 \
				or (absf(p.alvo.y - escolhida.alvo.y) <= 1.0 and _sorteio.randf() < 0.3):
			escolhida = p
	_soltar(escolhida)


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


## Chegou no andar para onde subia: se ele já é frio o bastante, vira líquido;
## senão, segue para o de cima; no topo, fica gás.
func _chegar(p: Particula) -> void:
	if _condensa_em(p.tipo, p.andar) and _cabe_na_poca(p.andar, p):
		_mergulhar(p)
	elif p.andar < andares() - 1 and not _condensa_em(p.tipo, p.andar):
		_subir_para(p, p.andar + 1)
	else:
		_ficar_solta(p, p.andar)
	mudou.emit()


func _mergulhar(p: Particula) -> void:
	_pocas[p.andar].append(p)
	p.estado = Estado.MERGULHANDO
	p.vel = Vector2.ZERO
	_arrumar_a_poca(p.andar)


func _ficar_solta(p: Particula, andar: int) -> void:
	p.andar = andar
	p.estado = Estado.SOLTA
	p.vel = Vector2.from_angle(_sorteio.randf_range(PI * 0.75, PI * 1.25)) * VELOCIDADE_SOLTA
	p.proxima_conferida = INTERVALO_DO_GAS_SOLTO


func _mover(p: Particula, delta: float) -> void:
	p.relogio += delta
	p.tamanho = minf(p.tamanho + delta / 0.16, 1.0)
	match p.estado:
		Estado.LIQUIDA:
			p.pos.x = lerpf(p.pos.x, p.alvo.x, 1.0 - exp(-5.0 * delta))
			p.pos.y = lerpf(p.pos.y, p.alvo.y + sin(p.relogio * 2.6), 1.0 - exp(-10.0 * delta))
		Estado.SUBINDO:
			_avancar_subindo(p, delta)
		Estado.MERGULHANDO:
			var distancia := p.pos.distance_to(p.alvo)
			p.pos = p.pos.move_toward(p.alvo, maxf(60.0, distancia * 4.5) * delta)
			if distancia < 1.5:
				p.estado = Estado.LIQUIDA
				_respingar(Vector2(p.pos.x, _tona_do_andar(p.andar)),
					MisturasDoDestilador.substancia(p.tipo)["tona"])
				_pulsos[p.andar] = 1.0
				condensou.emit(p.tipo, p.andar)
				mudou.emit()
		Estado.SOLTA:
			_quicar(p, delta)
			p.proxima_conferida -= delta
			if p.proxima_conferida <= 0.0:
				p.proxima_conferida = INTERVALO_DO_GAS_SOLTO
				_conferir_a_solta(p)


func _avancar_subindo(p: Particula, delta: float) -> void:
	var alvo := p.caminho[p.passo]
	var para_la := alvo - p.pos
	if para_la.length() < 10.0:
		p.passo += 1
		if p.passo >= p.caminho.size():
			_chegar(p)
			return
		alvo = p.caminho[p.passo]
		para_la = alvo - p.pos
	var direcao := para_la.normalized()
	# O gás não anda em linha reta: balança de um lado para o outro do rumo.
	var balanco := direcao.orthogonal() * sin(p.relogio * 7.0) * 26.0
	p.vel = p.vel.lerp(direcao * VELOCIDADE_SUBINDO + balanco, 1.0 - exp(-9.0 * delta))
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


## O gás solto confere o andar em que está: se esfriou o bastante, vira
## líquido; se ainda está quente demais e há andar em cima, sobe.
func _conferir_a_solta(p: Particula) -> void:
	if _condensa_em(p.tipo, p.andar):
		if _cabe_na_poca(p.andar, p):
			_mergulhar(p)
			mudou.emit()
	elif p.andar < andares() - 1:
		_subir_para(p, p.andar + 1)
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
	return FILEIRAS_NO_FUNDO if andar == 0 else FILEIRAS_NA_BANDEJA


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


func _cabe_na_poca(andar: int, p: Particula) -> bool:
	return _em_fileiras(andar, p).size() <= _fileiras_que_cabem(andar)


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


# ─────────────────────────────────────────────────────────────
# BOLHAS, FUMAÇA E RESPINGOS
# ─────────────────────────────────────────────────────────────

func _passo_das_bolhas(delta: float) -> void:
	var tona := _tona_do_andar(0)
	var fervendo := false
	for p: Particula in _pocas[0]:
		if _ferve(p):
			fervendo = true
			break
	for i in range(_bolhas.size() - 1, -1, -1):
		var bolha := _bolhas[i]
		bolha.y -= bolha.z * delta
		if bolha.y <= tona + 3.0:
			if fervendo:
				_soltar_fumaca(Vector2(bolha.x, tona - 4.0), Vector2(0.0, -34.0))
			_bolhas.remove_at(i)
		else:
			_bolhas[i] = bolha
	if not fervendo or _altura_do_liquido(0) < 8.0:
		return
	_proxima_bolha -= delta
	if _proxima_bolha <= 0.0:
		_proxima_bolha = _sorteio.randf_range(0.07, 0.16)
		var largura := tamanho_da_coluna().x
		_bolhas.append(Vector3(_sorteio.randf_range(ESCALA * 2.0, largura - ESCALA * 3.0),
			_arte.chao_do_andar(0) * ESCALA - 4.0, _sorteio.randf_range(42.0, 70.0)))


func _soltar_fumaca(pos: Vector2, vel: Vector2) -> void:
	if _fumaca.size() > 220:
		return
	_fumaca.append({"pos": pos + Vector2(_sorteio.randf_range(-4.0, 4.0), _sorteio.randf_range(-4.0, 4.0)),
		"vel": vel + Vector2(_sorteio.randf_range(-10.0, 10.0), _sorteio.randf_range(-16.0, -4.0)),
		"idade": 0.0, "vida": _sorteio.randf_range(0.9, 1.4)})


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
			"vel": Vector2(lado * _sorteio.randf_range(26.0, 44.0), _sorteio.randf_range(-95.0, -70.0)),
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
## termômetro pede mais do que o fundo tem, elas sobem um pixel e voltam.
func _desenhar_o_calor() -> void:
	var esquentando := _pedida > _temperatura + 0.01
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
		var cor := COR_MISTURA
		var tona := COR_TONA_MISTURA
		var dona := substancia_do_andar(andar)
		if dona != "":
			cor = MisturasDoDestilador.substancia(dona)["liquido"]
			tona = MisturasDoDestilador.substancia(dona)["tona"]
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
		if p.estado == Estado.SUBINDO or p.estado == Estado.SOLTA:
			quadro = int(p.relogio * p.giro) % MoleculasDoDestilador.QUADROS
		MoleculasDoDestilador.desenhar(self, p.tipo, p.pos, quadro)


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
## que uma substância ficou toma a cor dela; em cima da do topo vai o nome do
## resfriador, e embaixo da do fundo, de onde vem o calor.
func _desenhar_as_plaquinhas() -> void:
	var topo := andares() - 1
	for andar in andares():
		var texto := MisturasDoDestilador.graus(roundf(temperatura_do_andar(andar)))
		var dona := substancia_do_andar(andar)
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
