class_name CamaraDoSimulador
extends CamaraDeCompressao

# --- O COMPRESSOR DO LABORATÓRIO, DESENHADO ---
#
# A câmara do compressor da fase (CamaraDeCompressao) SEM O CILINDRO: no
# Laboratório o ar fica todo numa caixa só, a câmara com o êmbolo, apoiada num
# suporte de quatro pés. As moléculas, o êmbolo, a serpentina, o manômetro e
# o clarão da explosão são os da fase; o que este desenho troca e acrescenta
# (para a MaquinaDoSimulador):
#
#   A CAIXA      o vão do gás é só a câmara, abaixo do êmbolo. O êmbolo anda na
#                proporção do volume: no alto, 24,47 L; no fim do curso, para
#                com MaquinaDoSimulador.VOLUME_MINIMO ainda embaixo dele (ele
#                nunca encosta no fundo).
#   O FUNDO      tudo o que fala com o gás entra pelo fundo da caixa, que está
#                sempre em contato com ele (as paredes, não: o êmbolo passa por
#                elas). Da esquerda para a direita:
#     a BOMBA    uma bomba de pé, como a de encher pneu, pintada como o
#                cilindro de nitrogênio da fase. Cada bombada empurra
#                BOLINHAS_POR_BOMBADA moléculas do ar da sala pelo cano, que
#                sobe até o fundo; cada uma que passa pelo furo é ar a mais na
#                máquina (MaquinaDoSimulador.mudar_bolinhas). As novas são de
#                N₂, O₂ ou Ar, a que estiver mais em falta na proporção do ar.
#     o MANÔMETRO pendurado no meio, por um cano curto.
#     o ALÍVIO   a válvula vermelha no cano da direita. Aberta, as moléculas
#                mais perto do furo de saída vão embora pela boca de baixo, num
#                sopro (o ar a menos conta quando elas passam pelo furo).
#                Os dois canos são em raio X, como a caixa: dá para ver as
#                moléculas passando.
#   A TRAVA      o cadeado na haste do êmbolo. Fechado, o êmbolo fica onde a
#                pessoa o deixa; aberto, ele anda sozinho para a pressão não
#                mudar (MaquinaDoSimulador.embolo_solto).
#   O ESTOURO    sem o cilindro, o ponto fraco é a tampa: a caixa range, as
#                paredes racham perto do êmbolo, o gás assobia pelas frestas e
#                o êmbolo começa a ceder; no estrondo ele SAI VOANDO para cima e
#                o gás escapa pela boca aberta (com o clarão, a onda de choque,
#                a nuvem e as faíscas da fase, ali na boca da caixa).
#   O CALOR      o termostato vai até 1000 °C: a serpentina passa do laranja
#                ao vermelho-brasa, e o vão do gás fica avermelhado.
#
# Sem nomes escritos nas peças: quem dá nome a elas é a tela, com as fichas
# das letras da equação (scripts/laboratorio/compressor.gd).
#
# ONDE MEXER: as medidas do suporte, da bomba, dos canos, do manômetro e do
# alívio (em px do nó, nas mesmas coordenadas da CamaraDeCompressao) e as
# cores estão logo abaixo.

## Uma bombada empurrou ar para o cano (para quem toca o som).
signal bombeou
## O alívio abriu e o ar está saindo.
signal aliviou

## Quantas moléculas cada bombada empurra (0,1 mol) e quantas cada toque no
## alívio solta.
const BOLINHAS_POR_BOMBADA := 5
const BOLINHAS_POR_ALIVIO := 5
## A bombada: o cabo desce neste tempo e volta neste (s). Dá para bombear de
## novo quando ele já voltou boa parte do caminho (PRONTA_PARA_OUTRA).
const DESCIDA_DA_BOMBA := 0.1
const SUBIDA_DA_BOMBA := 0.2
const PRONTA_PARA_OUTRA := 0.6
## O menor intervalo entre dois sopros do alívio (s): segurando, ele solta um
## atrás do outro.
const INTERVALO_DO_ALIVIO := 0.2
## A velocidade das moléculas nos canos (px/s), e o intervalo entre duas da
## mesma bombada (ou do mesmo sopro).
const VELOCIDADE_NO_CANO := 420.0
const ENTRE_BOLINHAS := 0.045
## Na hora do estrondo: quanto o êmbolo cede antes (px) e a força com que ele
## sai voando (px/s, para cima). Passando desta altura (px do nó, bem acima da
## tela), ele some de vez: não volta a cair por cima do cartão do estouro.
const EMBOLO_CEDENDO := 10.0
const EMBOLO_VOANDO := 1500.0
const EMBOLO_SUMIU := -600.0

# ── A geometria (px do nó) ──
## O suporte: as duas pernas, debaixo das paredes, e a base.
const PERNAS := [Rect2(40, 400, 8, 226), Rect2(512, 400, 8, 226)]
const BASE_DO_SUPORTE := Rect2(28, 626, 504, 10)
## O corpo da bomba e a base dela (em cima da do suporte).
const BOMBA := Rect2(80, 478, 40, 138)
const BASE_DA_BOMBA := Rect2(64, 616, 72, 10)
## A altura do cabo da bomba: em cima e no fim da bombada.
const CABO_DA_BOMBA_EM_CIMA := 432.0
const CABO_DA_BOMBA_EMBAIXO := 460.0
const LARGURA_DO_CABO_DA_BOMBA := 76.0
## O cano da bomba, em L: o vão do pedaço deitado (da bomba ao cotovelo) e o
## do pedaço em pé (do cotovelo ao furo no fundo da caixa).
const CANO_DEITADO := Rect2(120, 588, 32, 16)
const CANO_EM_PE := Rect2(152, 388, 16, 216)
## O manômetro, pendurado no meio do fundo.
const CENTRO_DO_MANOMETRO := Vector2(280, 498)
## O cano do alívio (o vão, do furo no fundo até a boca) e a válvula nele.
const CANO_DO_ALIVIO := Rect2(424, 388, 16, 128)
const VALVULA_DO_ALIVIO := Rect2(415, 446, 34, 16)
## O cadeado: quanto acima da placa do êmbolo fica o meio dele.
const TRAVA_ACIMA_DA_PLACA := 30.0

# ── As cores ──
## As do cilindro de nitrogênio da fase ("valvula de purga.png").
const COR_BOMBA := Color("349652")
const COR_BOMBA_CLARA := Color("6cce80")
const COR_BOMBA_ESCURA := Color("1c5c34")
const COR_ALIVIO := Color("ec6052")
const COR_ALIVIO_ESCURO := Color("bc3430")
const COR_CADEADO := Color("f2c84b")
const COR_CADEADO_ESCURO := Color("b07d12")
## Mais quente que a serpentina da fase: o aço em brasa.
const COR_BRASA := Color("e8463a")
const COR_BRASA_VIVA := Color("ffb347")
const COR_VAO_BRASA := Color("4a120a")

## Uma molécula fora da caixa: num cano, entrando ou saindo.
class Passagem:
	var m: CamaraDeCompressao.Molecula
	## Entrando: o tempo até ela sair da bomba. Saindo: o tempo até ela ir.
	var espera: float = 0.0
	## Os pontos por onde ela ainda vai passar, em ordem.
	var caminho := PackedVector2Array()
	## Saindo: já passou pela boca do alívio e vai sumindo no ar da sala.
	var no_ar: bool = false
	var vida: float = 0.0

## Peças acesas (o ponteiro em cima ou segurando).
var bomba_em_foco: bool = false
var alivio_em_foco: bool = false
var trava_em_foco: bool = false

var _entrando: Array[Passagem] = []
var _saindo: Array[Passagem] = []
## Os fiapos brancos do ar saindo pelo alívio.
var _sopros: Array[Dictionary] = []
## Há quanto tempo foi a última bombada e o último toque no alívio (INF =
## parados).
var _desde_a_bombada: float = INF
var _desde_o_alivio: float = INF
## O alívio: 0 fechado, 1 aberto. Abre no toque e fecha depois que a última
## molécula passou pela boca.
var _abertura_do_alivio: float = 0.0
## O êmbolo depois do estrondo: {"pos", "vel", "giro", "velocidade_do_giro"}.
var _embolo_voando := {}


func _init() -> void:
	com_nomes = false
	com_valvula = false
	nevoa_no_cilindro = 0.0


func reiniciar() -> void:
	_entrando.clear()
	_saindo.clear()
	_sopros.clear()
	_embolo_voando = {}
	_desde_a_bombada = INF
	_desde_o_alivio = INF
	_abertura_do_alivio = 0.0
	super.reiniciar()


func _quantas_bolinhas() -> int:
	if maquina is MaquinaDoSimulador:
		return (maquina as MaquinaDoSimulador).bolinhas
	return super()


func _maquina() -> MaquinaDoSimulador:
	return maquina as MaquinaDoSimulador


# ─────────────────────────────────────────────────────────────
# A CAIXA (o vão do gás, sem o cilindro)
# ─────────────────────────────────────────────────────────────

## A cara de baixo do êmbolo: a altura do gás é a do volume (a caixa cheia
## são 24,47 L). Estourando, o êmbolo cede um pouco antes de voar.
func _y_do_embolo_alvo() -> float:
	var litros := maquina.volume() if maquina else MaquinaDeCompressao.VOLUME_TOTAL
	var y := CAMARA.end.y - CAMARA.size.y * litros / MaquinaDeCompressao.VOLUME_TOTAL
	if _fase == Fase.INCHANDO:
		y -= ease(_tempo_da_explosao / TEMPO_DE_INCHAR, 2.0) * EMBOLO_CEDENDO
	return y


## A posição do êmbolo (0 a 1) que deixa o cabo na altura y (px da tela).
func posicao_no_ponto_da_tela(y_tela: float, pegada: float = 0.0) -> float:
	var cara := y_tela - global_position.y + pegada + ESPESSURA_DO_EMBOLO + HASTE + 2.0
	return MaquinaDoSimulador.posicao_do_volume((CAMARA.end.y - cara) / CAMARA.size.y * MaquinaDeCompressao.VOLUME_TOTAL)


## Por onde o meio de uma molécula de gás pode andar: a caixa, abaixo do êmbolo.
func _vao_do_gas() -> Rect2:
	return Rect2(CAMARA.position.x + RAIO, _y_do_embolo + RAIO, CAMARA.size.x - RAIO * 2.0,
		maxf(CAMARA.end.y - _y_do_embolo - RAIO * 2.0, 0.0))


func _dentro(p: Vector2) -> bool:
	return _vao_do_gas().has_point(p)


func _ponto_mais_perto_dentro(p: Vector2) -> Vector2:
	var vao := _vao_do_gas()
	return Vector2(clampf(p.x, vao.position.x, vao.end.x), clampf(p.y, vao.position.y, vao.end.y))


func _ponto_livre() -> Vector2:
	var vao := _vao_do_gas()
	return Vector2(randf_range(vao.position.x, vao.end.x), randf_range(vao.position.y, vao.end.y))


## Sem cilindro, não há geada nele (a das paredes continua, pela serpentina).
func _frio_do_gas() -> float:
	return 0.0


func _centro_do_manometro() -> Vector2:
	return CENTRO_DO_MANOMETRO


## O estouro sai pela boca da caixa, onde está o êmbolo.
func _centro_da_explosao() -> Vector2:
	return Vector2(CAMARA.get_center().x, _y_do_embolo)


# ─────────────────────────────────────────────────────────────
# A BOMBA E O ALÍVIO
# ─────────────────────────────────────────────────────────────

## Dá para bombear agora? Cabe mais ar (contando o que está no cano).
func pode_bombear() -> bool:
	var m := _maquina()
	return m != null and _fase == Fase.NORMAL and m.cabe_mais_ar() \
		and m.bolinhas + _entrando.size() + BOLINHAS_POR_BOMBADA <= MaquinaDoSimulador.BOLINHAS_MAXIMAS


## Uma bombada: o cabo desce e BOLINHAS_POR_BOMBADA moléculas vão para o cano.
## Devolve se bombeou (com o cabo ainda voltando da última, não).
func bombear() -> bool:
	if not pode_bombear() or _desde_a_bombada < (DESCIDA_DA_BOMBA + SUBIDA_DA_BOMBA) * PRONTA_PARA_OUTRA:
		return false
	_desde_a_bombada = 0.0
	for i in BOLINHAS_POR_BOMBADA:
		var p := Passagem.new()
		p.m = _nova_molecula(_chave_em_falta(), Vector2(CANO_DEITADO.position.x + RAIO, CANO_DEITADO.get_center().y))
		p.caminho = PackedVector2Array([Vector2(CANO_EM_PE.get_center().x, CANO_DEITADO.get_center().y),
			_furo_de_entrada()])
		# Saem da bomba uma atrás da outra, enquanto o cabo desce.
		p.espera = DESCIDA_DA_BOMBA * 0.5 + i * ENTRE_BOLINHAS
		_entrando.append(p)
	bombeou.emit()
	return true


func pode_soltar() -> bool:
	return _maquina() != null and _fase == Fase.NORMAL and _maquina().tem_ar()


## Abre o alívio: as moléculas de gás mais perto do furo de saída vão embora.
## Devolve se saiu alguma.
func soltar_ar() -> bool:
	if not pode_soltar() or _desde_o_alivio < INTERVALO_DO_ALIVIO:
		return false
	var furo := _furo_de_saida()
	var perto: Array[Molecula] = []
	for m in _moleculas:
		if m.estado == 0 and not m.solta:
			perto.append(m)
	if perto.is_empty():
		return false
	perto.sort_custom(func(a: Molecula, b: Molecula) -> bool:
		return a.pos.distance_squared_to(furo) < b.pos.distance_squared_to(furo))
	for i in mini(BOLINHAS_POR_ALIVIO, perto.size()):
		var p := Passagem.new()
		p.m = perto[i]
		p.caminho = PackedVector2Array([furo, _boca_do_alivio()])
		p.espera = i * ENTRE_BOLINHAS
		_moleculas.erase(p.m)
		_saindo.append(p)
	_desde_o_alivio = 0.0
	_abertura_do_alivio = 1.0
	aliviou.emit()
	return true


## O gás do ar que está mais em falta (contando as que estão no cano): é ele
## que a próxima bolinha vai ser, para a mistura seguir a do ar.
func _chave_em_falta() -> String:
	var contas := {}
	var total := 0
	for m in _moleculas:
		contas[m.chave] = int(contas.get(m.chave, 0)) + 1
		total += 1
	for p in _entrando:
		contas[p.m.chave] = int(contas.get(p.m.chave, 0)) + 1
		total += 1
	var escolhida := "N2"
	var maior_falta := -INF
	for chave: String in GasFechado.COMPOSICAO:
		var falta := float(GasFechado.COMPOSICAO[chave]) * (total + 1) - int(contas.get(chave, 0))
		if falta > maior_falta:
			maior_falta = falta
			escolhida = chave
	return escolhida


## Onde a molécula atravessa o fundo da caixa, do lado de dentro: o furo da
## bomba e o do alívio.
func _furo_de_entrada() -> Vector2:
	return Vector2(CANO_EM_PE.get_center().x, CAMARA.end.y - RAIO)


func _furo_de_saida() -> Vector2:
	return Vector2(CANO_DO_ALIVIO.get_center().x, CAMARA.end.y - RAIO)


func _boca_do_alivio() -> Vector2:
	return Vector2(CANO_DO_ALIVIO.get_center().x, CANO_DO_ALIVIO.end.y)


# ─────────────────────────────────────────────────────────────
# O TEMPO PASSANDO
# ─────────────────────────────────────────────────────────────

func avancar(delta: float) -> void:
	super.avancar(delta)
	_desde_a_bombada += delta
	_desde_o_alivio += delta
	_mover_as_que_entram(delta)
	_mover_as_que_saem(delta)
	_animar_os_sopros(delta)
	var passando := false
	for p in _saindo:
		if not p.no_ar:
			passando = true
			break
	if not passando:
		_abertura_do_alivio = move_toward(_abertura_do_alivio, 0.0, delta / 0.12)
	if not _embolo_voando.is_empty() and (_embolo_voando["pos"] as Vector2).y > EMBOLO_SUMIU:
		_embolo_voando["vel"] = (_embolo_voando["vel"] as Vector2) + Vector2(0.0, 900.0) * delta
		_embolo_voando["pos"] = (_embolo_voando["pos"] as Vector2) + (_embolo_voando["vel"] as Vector2) * delta
		_embolo_voando["giro"] = float(_embolo_voando["giro"]) + float(_embolo_voando["velocidade_do_giro"]) * delta


## Anda a molécula "distancia" px pelo caminho dela (tirando os pontos já
## alcançados).
func _andar_pelo_caminho(p: Passagem, distancia: float) -> void:
	while distancia > 0.0 and not p.caminho.is_empty():
		var alvo := p.caminho[0]
		var falta := p.m.pos.distance_to(alvo)
		if falta > distancia:
			p.m.pos = p.m.pos.move_toward(alvo, distancia)
			return
		p.m.pos = alvo
		distancia -= falta
		p.caminho.remove_at(0)


func _mover_as_que_entram(delta: float) -> void:
	if _fase == Fase.ESTOURADA:
		_entrando.clear()
		return
	for i in range(_entrando.size() - 1, -1, -1):
		var p := _entrando[i]
		if p.espera > 0.0:
			p.espera -= delta
			continue
		_andar_pelo_caminho(p, VELOCIDADE_NO_CANO * delta)
		if not p.caminho.is_empty():
			continue
		# Passou pelo furo: agora é gás da máquina, subindo para dentro da caixa.
		_entrando.remove_at(i)
		if _fase != Fase.NORMAL:
			continue
		var m := p.m
		m.vel = Vector2.from_angle(-PI * 0.5 + randf_range(-0.9, 0.9)) * _velocidade_de(m)
		_moleculas.append(m)
		_maquina().mudar_bolinhas(1)


func _mover_as_que_saem(delta: float) -> void:
	if _fase == Fase.ESTOURADA:
		_saindo.clear()
		return
	var passo := VELOCIDADE_NO_CANO * delta
	for i in range(_saindo.size() - 1, -1, -1):
		var p := _saindo[i]
		if p.espera > 0.0:
			p.espera -= delta
			# Esperando a vez, ela continua no gás, andando devagar para o furo.
			p.m.pos = p.m.pos.move_toward(p.caminho[0], passo * 0.25)
			continue
		if not p.no_ar:
			var antes := p.caminho.size()
			_andar_pelo_caminho(p, passo)
			# Passou pelo furo do fundo: é ar a menos na máquina.
			if antes == 2 and p.caminho.size() < 2:
				_maquina().mudar_bolinhas(-1)
			if p.caminho.is_empty():
				# Saiu pela boca: um sopro, e ela vai embora no ar da sala.
				p.no_ar = true
				p.m.vel = Vector2(randf_range(-70.0, 70.0), randf_range(150.0, 230.0))
				_soprar(_boca_do_alivio())
			continue
		p.vida += delta
		p.m.pos += p.m.vel * delta
		p.m.vel *= pow(0.3, delta)
		p.m.giro += p.m.velocidade_do_giro * delta * 2.0
		if p.vida > 0.9:
			_saindo.remove_at(i)


func _soprar(onde: Vector2) -> void:
	for k in 2:
		_sopros.append({"pos": onde + Vector2(randf_range(-4, 4), 0), "vel": Vector2(randf_range(-40, 40), randf_range(40, 90)),
			"raio": randf_range(3.0, 6.0), "vida": 0.0, "duracao": randf_range(0.4, 0.7)})


func _animar_os_sopros(delta: float) -> void:
	for i in range(_sopros.size() - 1, -1, -1):
		var s: Dictionary = _sopros[i]
		s["vida"] = float(s["vida"]) + delta
		s["pos"] = (s["pos"] as Vector2) + (s["vel"] as Vector2) * delta
		s["raio"] = float(s["raio"]) + delta * 14.0
		if float(s["vida"]) >= float(s["duracao"]):
			_sopros.remove_at(i)


## 0 com o cabo da bomba em cima, 1 no fim da bombada.
func _curso_da_bomba() -> float:
	if _desde_a_bombada < DESCIDA_DA_BOMBA:
		return _desde_a_bombada / DESCIDA_DA_BOMBA
	return clampf(1.0 - (_desde_a_bombada - DESCIDA_DA_BOMBA) / SUBIDA_DA_BOMBA, 0.0, 1.0)


# ─────────────────────────────────────────────────────────────
# O ESTOURO (a tampa voa)
# ─────────────────────────────────────────────────────────────

## As paredes racham perto do êmbolo, onde a caixa está cedendo.
func _nova_rachadura() -> PackedVector2Array:
	var x := CAMARA.position.x - PAREDE * 0.5 if randi() % 2 == 0 else CAMARA.end.x + PAREDE * 0.5
	var y := randf_range(_y_do_embolo + 6.0, minf(_y_do_embolo + 90.0, CAMARA.end.y - 6.0))
	return PackedVector2Array([Vector2(x, y).round()])


## O estrondo: o êmbolo sai voando para cima e o gás escapa pela boca aberta.
## O clarão, a onda de choque, a nuvem e as faíscas são os da fase
## (CamaraDeCompressao._estrondo), na boca da caixa.
func _estrondo() -> void:
	_fase = Fase.ESTOURADA
	_tempo_da_explosao = 0.0
	var boca := _centro_da_explosao()
	_embolo_voando = {"pos": Vector2(boca.x, boca.y - ESPESSURA_DO_EMBOLO * 0.5),
		"vel": Vector2(randf_range(-80.0, 80.0), -EMBOLO_VOANDO), "giro": 0.0,
		"velocidade_do_giro": randf_range(-2.5, 2.5)}
	# Lascas das vedações e da borda, dos dois cantos da boca.
	for i in 16:
		var lado := -1.0 if i % 2 == 0 else 1.0
		var cor: Color = [COR_ACO, COR_ACO_CLARO, COR_ACO_ESCURO, Color("1b1b24")][i % 4]
		_cacos.append({"pos": Vector2(boca.x + lado * CAMARA.size.x * 0.5, boca.y),
			"vel": Vector2(lado * randf_range(80, 320), -randf_range(300, 700)), "giro": randf() * TAU,
			"velocidade_do_giro": randf_range(-14, 14), "tamanho": Vector2(randf_range(5, 14), randf_range(4, 8)).round(),
			"cor": cor, "vida": 0.0, "tipo": "placa"})
	# O vidro do manômetro.
	for i in 10:
		_cacos.append({"pos": _centro_do_manometro(), "vel": Vector2.from_angle(randf() * TAU) * randf_range(180, 420),
			"giro": randf() * TAU, "velocidade_do_giro": randf_range(-16, 16),
			"tamanho": Vector2(randf_range(4, 9), randf_range(3, 6)).round(),
			"cor": Color(0.85, 0.95, 1.0, 0.85), "vida": 0.0, "tipo": "placa"})
	# As moléculas, todas, saindo pela boca, cada uma para um lado de cima.
	for m in _moleculas:
		m.solta = true
		m.estado = 0
		m.velocidade_do_giro *= 4.0
		var rumo := Vector2(m.pos.x + randf_range(-160.0, 160.0), boca.y - 240.0) - m.pos
		m.vel = rumo.normalized() * randf_range(600, 1150)
	# A nuvem, espalhada pela boca, e as faíscas, nos cantos.
	for i in 26:
		var branca := i % 4 != 0
		_fumaca.append({"pos": boca + Vector2(randf_range(-200, 200), randf_range(-16, 16)),
			"vel": Vector2(randf_range(-160, 160), -randf_range(60, 240)), "raio": randf_range(12, 26),
			"vida": 0.0, "duracao": randf_range(1.8, 3.0),
			"cor": Color(0.92, 0.96, 1.0) if branca else Color(0.45, 0.46, 0.52)})
	for i in 28:
		var lado := -1.0 if i % 2 == 0 else 1.0
		_faiscas.append({"pos": Vector2(boca.x + lado * CAMARA.size.x * 0.5, boca.y),
			"vel": Vector2.from_angle(randf_range(-PI, 0.0)) * randf_range(250, 760),
			"vida": 0.0, "duracao": randf_range(0.2, 0.55)})
	estrondo.emit()


## O êmbolo já saiu voando (depois do estrondo).
func embolo_voou() -> bool:
	return not _embolo_voando.is_empty()


# ─────────────────────────────────────────────────────────────
# PERGUNTAS DE QUEM USA
# ─────────────────────────────────────────────────────────────

## O meio do cadeado, na haste do êmbolo (px do nó).
func _meio_da_trava() -> Vector2:
	return Vector2(GARGALO.get_center().x, roundf(_y_do_embolo) - ESPESSURA_DO_EMBOLO - TRAVA_ACIMA_DA_PLACA)


func retangulo_da_trava_na_tela() -> Rect2:
	return Rect2(global_position + _meio_da_trava() - Vector2(18, 26), Vector2(36, 46))


func retangulo_da_bomba_na_tela() -> Rect2:
	var r := Rect2(BASE_DA_BOMBA.position.x, CABO_DA_BOMBA_EM_CIMA - 4.0, BASE_DA_BOMBA.size.x,
		BASE_DA_BOMBA.end.y - CABO_DA_BOMBA_EM_CIMA + 4.0)
	return Rect2(global_position + r.position, r.size)


func retangulo_do_alivio_na_tela() -> Rect2:
	var r := Rect2(VALVULA_DO_ALIVIO.position.x - 6.0, VALVULA_DO_ALIVIO.position.y - 26.0,
		VALVULA_DO_ALIVIO.size.x + 36.0, VALVULA_DO_ALIVIO.size.y + 40.0)
	return Rect2(global_position + r.position, r.size)


## Quantas moléculas estão a caminho agora: entrando pelo cano, ou saindo e
## ainda não fora da boca do alívio.
func moleculas_no_cano() -> int:
	var conta := _entrando.size()
	for p in _saindo:
		if not p.no_ar:
			conta += 1
	return conta


## Quantas moléculas a câmara desenha no gás da máquina (sem as dos canos).
func moleculas_na_maquina() -> int:
	return _moleculas.size()


# ─────────────────────────────────────────────────────────────
# O DESENHO
# ─────────────────────────────────────────────────────────────

func _draw() -> void:
	if maquina == null:
		return
	draw_set_transform(_tremor)
	_desenhar_o_suporte()
	_desenhar_a_bomba()
	_desenhar_os_canos()
	draw_set_transform(Vector2.ZERO)
	super()
	draw_set_transform(_tremor)
	_desenhar_o_alivio()
	_desenhar_as_passagens()
	_desenhar_os_sopros()
	if _fase != Fase.ESTOURADA:
		_desenhar_a_trava()
	draw_set_transform(Vector2.ZERO)
	_desenhar_o_embolo_voando()


## A cor de uma temperatura, a mesma da serpentina (o termômetro da tela pinta
## a coluna dele com ela).
func cor_da_temperatura(celsius: float) -> Color:
	return _cor_da_temperatura(celsius)


func _cor_da_temperatura(celsius: float) -> Color:
	if celsius <= 150.0:
		return super(celsius)
	var cor := COR_QUENTE.lerp(COR_BRASA, clampf(inverse_lerp(150.0, 600.0, celsius), 0.0, 1.0))
	return cor.lerp(COR_BRASA_VIVA, clampf(inverse_lerp(600.0, 1000.0, celsius), 0.0, 1.0))


func _cor_do_vao_agora() -> Color:
	var cor := super()
	var c := maquina.gas.celsius()
	if c > 200.0:
		cor = cor.lerp(COR_VAO_BRASA, clampf(inverse_lerp(200.0, 1000.0, c), 0.0, 1.0))
	return cor


## A caixa por dentro: o gás abaixo do êmbolo (depois do estrondo, vazia).
func _desenhar_vao() -> void:
	draw_rect(Rect2(CAMARA.position.x, 0.0, CAMARA.size.x, CAMARA.end.y), COR_VAO.darkened(0.35))
	if _fase == Fase.ESTOURADA:
		return
	draw_rect(Rect2(CAMARA.position.x, _y_do_embolo, CAMARA.size.x, CAMARA.end.y - _y_do_embolo), _cor_do_vao_agora())
	# A grade de raio X, bem fraca, no vão do gás.
	var x := CAMARA.position.x + 24.0
	while x < CAMARA.end.x:
		draw_rect(Rect2(x, _y_do_embolo, 2.0, CAMARA.end.y - _y_do_embolo), Color(1, 1, 1, 0.035))
		x += 24.0


## As paredes e o fundo inteiro, com os dois furos dos canos.
func _desenhar_paredes() -> void:
	var esquerda := Rect2(CAMARA.position.x - PAREDE, 0.0, PAREDE, CAMARA.end.y + PAREDE)
	var direita := Rect2(CAMARA.end.x, 0.0, PAREDE, CAMARA.end.y + PAREDE)
	for parede: Rect2 in [esquerda, direita]:
		draw_rect(parede.grow(2.0), EstiloHUD.CONTORNO)
		draw_rect(parede, COR_ACO)
		draw_rect(Rect2(parede.position.x + 2.0, parede.position.y, 2.0, parede.size.y), COR_ACO_CLARO)
	var cortes: Array[float] = [CAMARA.position.x, CANO_EM_PE.position.x, CANO_EM_PE.end.x,
		CANO_DO_ALIVIO.position.x, CANO_DO_ALIVIO.end.x, CAMARA.end.x]
	for i in range(0, cortes.size(), 2):
		var fundo := Rect2(cortes[i], CAMARA.end.y, cortes[i + 1] - cortes[i], PAREDE)
		draw_rect(Rect2(fundo.position.x, fundo.position.y, fundo.size.x, fundo.size.y + 2.0), EstiloHUD.CONTORNO)
		draw_rect(fundo, COR_ACO)
		draw_rect(Rect2(fundo.position.x, fundo.position.y, fundo.size.x, 2.0), COR_ACO_CLARO)
	# Os rebites.
	for y in range(20, int(CAMARA.end.y), 48):
		for x: float in [CAMARA.position.x - PAREDE * 0.5, CAMARA.end.x + PAREDE * 0.5]:
			draw_rect(Rect2(x - 1.0, y, 2.0, 2.0), COR_ACO_ESCURO)


## Estourado, o êmbolo é o que voa (_desenhar_o_embolo_voando).
func _desenhar_embolo() -> void:
	if _fase != Fase.ESTOURADA:
		super()


## Estourado, as moléculas que escaparam vão sumindo no ar da sala: quando o
## cartão do estouro chega, a tela já está limpa.
func _desenhar_moleculas() -> void:
	if _fase != Fase.ESTOURADA:
		super()
		return
	var alfa := clampf(1.0 - _tempo_da_explosao / TEMPO_DEPOIS_DO_ESTRONDO, 0.0, 1.0)
	if alfa <= 0.0:
		return
	for m in _moleculas:
		var quadro := int(floor(m.giro)) % MoleculasDoDestilador.QUADROS
		MoleculasDoDestilador.desenhar(self, m.chave, m.pos, quadro, AMPLIACAO, Color(1, 1, 1, alfa))


# Sem o cilindro, sem a válvula dele, sem as garras que o prendem e sem a
# volta da serpentina em torno dele.
func _desenhar_cilindro() -> void:
	pass


func _desenhar_serpentina_da_frente() -> void:
	pass


func _desenhar_valvula() -> void:
	pass


func _desenhar_garras() -> void:
	pass


## O cano curto do fundo da caixa até o manômetro.
func _desenhar_cano_do_manometro() -> void:
	var c := _centro_do_manometro()
	var cano := Rect2(c.x - 4.0, CAMARA.end.y + PAREDE, 8.0, c.y - MANOMETRO_RAIO - CAMARA.end.y - PAREDE + 2.0)
	draw_rect(cano.grow(2.0), EstiloHUD.CONTORNO)
	draw_rect(cano, COR_ACO)
	draw_rect(Rect2(cano.position.x + 1.0, cano.position.y, 2.0, cano.size.y), COR_ACO_CLARO)


func _desenhar_o_suporte() -> void:
	for perna: Rect2 in PERNAS:
		draw_rect(perna.grow(2.0), EstiloHUD.CONTORNO)
		draw_rect(perna, COR_ACO_ESCURO)
		draw_rect(Rect2(perna.position.x + 1.0, perna.position.y, 2.0, perna.size.y), COR_ACO)
	draw_rect(BASE_DO_SUPORTE.grow(2.0), EstiloHUD.CONTORNO)
	draw_rect(BASE_DO_SUPORTE, COR_ACO_ESCURO)
	draw_rect(Rect2(BASE_DO_SUPORTE.position.x, BASE_DO_SUPORTE.position.y, BASE_DO_SUPORTE.size.x, 2.0), COR_ACO)


## Os dois canos em raio X: as paredes de aço e o vão escuro, da bomba ao
## fundo da caixa (em L) e do fundo à boca do alívio.
func _desenhar_os_canos() -> void:
	var paredes: Array[Rect2] = [
		# O da bomba: a parede de cima e a de baixo do pedaço deitado, e as duas
		# do pedaço em pé.
		Rect2(CANO_DEITADO.position.x, CANO_DEITADO.position.y - 4.0, CANO_DEITADO.size.x, 4.0),
		Rect2(CANO_DEITADO.position.x, CANO_DEITADO.end.y, CANO_EM_PE.end.x + 4.0 - CANO_DEITADO.position.x, 4.0),
		Rect2(CANO_EM_PE.position.x - 4.0, CAMARA.end.y + PAREDE, 4.0, CANO_DEITADO.position.y - CAMARA.end.y - PAREDE),
		Rect2(CANO_EM_PE.end.x, CAMARA.end.y + PAREDE, 4.0, CANO_EM_PE.end.y + 4.0 - CAMARA.end.y - PAREDE),
		# O do alívio.
		Rect2(CANO_DO_ALIVIO.position.x - 4.0, CAMARA.end.y + PAREDE, 4.0, CANO_DO_ALIVIO.end.y - CAMARA.end.y - PAREDE),
		Rect2(CANO_DO_ALIVIO.end.x, CAMARA.end.y + PAREDE, 4.0, CANO_DO_ALIVIO.end.y - CAMARA.end.y - PAREDE),
	]
	for parede in paredes:
		draw_rect(parede.grow(2.0), EstiloHUD.CONTORNO)
	for parede in paredes:
		draw_rect(parede, COR_ACO)
	draw_rect(CANO_DEITADO, COR_VAO)
	draw_rect(CANO_EM_PE, COR_VAO)
	draw_rect(CANO_DO_ALIVIO, COR_VAO)
	# A boca do alívio, um anel de aço.
	var boca := Rect2(CANO_DO_ALIVIO.position.x - 7.0, CANO_DO_ALIVIO.end.y, CANO_DO_ALIVIO.size.x + 14.0, 6.0)
	draw_rect(boca.grow(2.0), EstiloHUD.CONTORNO)
	draw_rect(boca, COR_ACO_CLARO)


func _desenhar_a_bomba() -> void:
	var curso := _curso_da_bomba()
	var y_do_cabo := roundf(lerpf(CABO_DA_BOMBA_EM_CIMA, CABO_DA_BOMBA_EMBAIXO, curso))
	var meio := BOMBA.get_center().x
	# A haste, que entra no corpo.
	var haste := Rect2(meio - 3.0, y_do_cabo + 10.0, 6.0, BOMBA.position.y - y_do_cabo - 6.0)
	draw_rect(haste.grow(2.0), EstiloHUD.CONTORNO)
	draw_rect(haste, COR_ACO_CLARO)
	# O cabo em T, com as duas manoplas.
	var cabo := Rect2(meio - LARGURA_DO_CABO_DA_BOMBA * 0.5, y_do_cabo, LARGURA_DO_CABO_DA_BOMBA, 10.0)
	draw_rect(cabo.grow(2.0), EstiloHUD.CONTORNO)
	draw_rect(cabo, COR_AMARELO if bomba_em_foco else COR_ACO)
	for x: float in [cabo.position.x, cabo.end.x - 18.0]:
		draw_rect(Rect2(x, cabo.position.y, 18.0, cabo.size.y), Color("343a4a"))
		draw_rect(Rect2(x + 2.0, cabo.position.y + 2.0, 14.0, 2.0), Color(1, 1, 1, 0.2))
	# O corpo verde, com a tampa e o brilho da tinta.
	draw_rect(BOMBA.grow(2.0), EstiloHUD.CONTORNO)
	draw_rect(BOMBA, COR_BOMBA)
	draw_rect(Rect2(BOMBA.position.x + 4.0, BOMBA.position.y + 8.0, 4.0, BOMBA.size.y - 16.0), COR_BOMBA_CLARA)
	draw_rect(Rect2(BOMBA.end.x - 6.0, BOMBA.position.y + 8.0, 4.0, BOMBA.size.y - 16.0), COR_BOMBA_ESCURA)
	var tampa := Rect2(BOMBA.position.x - 3.0, BOMBA.position.y - 6.0, BOMBA.size.x + 6.0, 8.0)
	draw_rect(tampa.grow(1.0), EstiloHUD.CONTORNO)
	draw_rect(tampa, COR_ACO_ESCURO)
	# A faixa clara, como a do rótulo do cilindro de nitrogênio.
	draw_rect(Rect2(BOMBA.position.x, BOMBA.position.y + 46.0, BOMBA.size.x, 14.0), Color("e8eef0"))
	draw_rect(Rect2(BOMBA.position.x, BOMBA.position.y + 58.0, BOMBA.size.x, 2.0), Color("c4ccd2"))
	# A base, com os dois pés.
	draw_rect(BASE_DA_BOMBA.grow(2.0), EstiloHUD.CONTORNO)
	draw_rect(BASE_DA_BOMBA, COR_ACO_ESCURO)
	draw_rect(Rect2(BASE_DA_BOMBA.position.x, BASE_DA_BOMBA.position.y, BASE_DA_BOMBA.size.x, 2.0), COR_ACO)


## A válvula vermelha no cano do alívio: a alavanca deitada está fechada; em
## pé (no sentido do cano), aberta.
func _desenhar_o_alivio() -> void:
	var corpo := VALVULA_DO_ALIVIO
	var eixo := Vector2(corpo.end.x + 2.0, corpo.get_center().y)
	var ponta := eixo + Vector2.from_angle(lerpf(0.0, -1.4, _abertura_do_alivio)) * 24.0
	draw_line(eixo, ponta, EstiloHUD.CONTORNO, 10.0)
	draw_line(eixo, ponta, COR_AMARELO if alivio_em_foco else COR_ALIVIO, 6.0)
	draw_rect(corpo.grow(2.0), EstiloHUD.CONTORNO)
	draw_rect(corpo, COR_ALIVIO_ESCURO)
	draw_rect(Rect2(corpo.position.x, corpo.position.y, corpo.size.x, 4.0), COR_ALIVIO)
	draw_circle(eixo, 4.0, EstiloHUD.CONTORNO)
	# O canal por dentro dela: fechado, a comporta corta; aberto, passa gás.
	var canal := Rect2(CANO_DO_ALIVIO.position.x, corpo.position.y + 4.0, CANO_DO_ALIVIO.size.x, corpo.size.y - 8.0)
	draw_rect(canal, COR_VAO if _abertura_do_alivio > 0.0 else COR_ALIVIO_ESCURO.darkened(0.3))


func _desenhar_as_passagens() -> void:
	for p in _entrando:
		if p.espera <= 0.0:
			MoleculasDoDestilador.desenhar(self, p.m.chave, p.m.pos, _quadro_no_cano(p), AMPLIACAO)
	for p in _saindo:
		var alfa := 1.0
		var quadro := int(floor(p.m.giro)) % MoleculasDoDestilador.QUADROS
		if p.no_ar:
			alfa = clampf(1.0 - (p.vida - 0.4) / 0.5, 0.0, 1.0)
		elif p.m.pos.y > CAMARA.end.y - RAIO:
			quadro = _quadro_no_cano(p)
		MoleculasDoDestilador.desenhar(self, p.m.chave, p.m.pos, quadro, AMPLIACAO, Color(1, 1, 1, alfa))


## Num cano, a molécula vai deitada no sentido dele: 0 num pedaço deitado, 2
## num em pé.
func _quadro_no_cano(p: Passagem) -> int:
	if p.caminho.is_empty():
		return 2
	var rumo := p.caminho[0] - p.m.pos
	return 2 if absf(rumo.y) > absf(rumo.x) else 0


func _desenhar_os_sopros() -> void:
	for s in _sopros:
		var t := float(s["vida"]) / float(s["duracao"])
		draw_circle(s["pos"], s["raio"], Color(0.92, 0.96, 1.0, (1.0 - t) * 0.5))


## O cadeado na haste: fechado, a alça entra no corpo; aberto, ela sobe e
## solta de um lado.
func _desenhar_a_trava() -> void:
	var c := _meio_da_trava()
	var solto := _maquina() != null and _maquina().embolo_solto
	var corpo := Rect2(c.x - 12.0, c.y - 2.0, 24.0, 18.0)
	var subida := 7.0 if solto else 0.0
	var alca: Array[Rect2] = [
		Rect2(c.x - 9.0, c.y - 14.0 - subida, 4.0, 12.0 + subida),
		Rect2(c.x - 9.0, c.y - 18.0 - subida, 18.0, 4.0),
		Rect2(c.x + 5.0, c.y - 14.0 - subida, 4.0, 5.0 if solto else 12.0),
	]
	if trava_em_foco:
		EstiloHUD.bloco(self, Rect2(c.x - 16.0, c.y - 22.0 - subida, 32.0, 42.0 + subida), EstiloHUD.CLARO)
	for r in alca:
		draw_rect(r.grow(2.0), EstiloHUD.CONTORNO)
	for r in alca:
		draw_rect(r, COR_ACO_CLARO)
	draw_rect(corpo.grow(2.0), EstiloHUD.CONTORNO)
	draw_rect(corpo, COR_CADEADO)
	draw_rect(Rect2(corpo.position.x, corpo.end.y - 4.0, corpo.size.x, 4.0), COR_CADEADO_ESCURO)
	draw_rect(Rect2(corpo.position.x + 3.0, corpo.position.y + 3.0, 4.0, 3.0), Color(1, 1, 1, 0.45))
	# O buraco da chave.
	draw_rect(Rect2(c.x - 2.0, c.y + 3.0, 4.0, 4.0), EstiloHUD.CONTORNO)
	draw_rect(Rect2(c.x - 1.0, c.y + 6.0, 2.0, 5.0), EstiloHUD.CONTORNO)


## O êmbolo voando depois do estrondo: a placa, a haste e o cabo, girando
## devagar em volta do meio da placa.
func _desenhar_o_embolo_voando() -> void:
	if _embolo_voando.is_empty() or (_embolo_voando["pos"] as Vector2).y <= EMBOLO_SUMIU:
		return
	draw_set_transform(_embolo_voando["pos"], float(_embolo_voando["giro"]))
	var placa := Rect2(-CAMARA.size.x * 0.5, -ESPESSURA_DO_EMBOLO * 0.5, CAMARA.size.x, ESPESSURA_DO_EMBOLO)
	var haste := Rect2(-9.0, placa.position.y - HASTE, 18.0, HASTE)
	var cabo := Rect2(-50.0, haste.position.y - 12.0, 100.0, 18.0)
	for peca: Rect2 in [haste, cabo, placa]:
		draw_rect(peca.grow(2.0), EstiloHUD.CONTORNO)
	draw_rect(haste, COR_ACO)
	draw_rect(cabo, Color("d65a31"))
	draw_rect(placa, COR_ACO)
	draw_rect(Rect2(placa.position.x, placa.position.y, placa.size.x, 3.0), COR_ACO_CLARO)
	draw_rect(Rect2(placa.position.x, placa.end.y - 6.0, placa.size.x, 3.0), Color("1b1b24"))
	draw_set_transform(Vector2.ZERO)
