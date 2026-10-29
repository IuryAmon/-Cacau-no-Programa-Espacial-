class_name MaquinaDoSimulador
extends MaquinaDeCompressao

# --- O COMPRESSOR DO LABORATÓRIO (o simulador de gases, sem o desenho) ---
#
# A máquina da sala do compressor (MaquinaDeCompressao) virada brinquedo para
# ver P · V = n · R · T funcionando: a mesma câmara e o mesmo êmbolo, SEM O
# CILINDRO. O ar fica todo na caixa, embaixo do êmbolo, e o êmbolo para no fim
# do curso com VOLUME_MINIMO ainda embaixo dele (é o volume do cilindro da
# fase, para as contas da máquina — volume(), a posição do êmbolo — serem as
# mesmas). Passando de 4 atm, estoura. Quem desenha é a CamaraDoSimulador
# (scripts/ui/camara_do_simulador.gd) e quem mexe é a tela do Laboratório
# (scripts/laboratorio/compressor.gd). O que muda da fase:
#
#   n   O AR ENTRA E SAI. A bomba põe e a válvula de alívio tira, uma BOLINHA
#       por vez: cada bolinha da tela vale MOL_POR_BOLINHA, e o ar da máquina é
#       sempre um número inteiro delas — o gás é exatamente o que se vê. Quem
#       avisa que uma bolinha passou pelo furo do fundo da caixa é o desenho,
#       com mudar_bolinhas(). Entrando ou saindo, o ar não muda de
#       temperatura (GasFechado.mudar_quantidade).
#   T   O TERMOSTATO vai de TERMOSTATO_MINIMO a TERMOSTATO_MAXIMO e é forte: o
#       gás chega perto da temperatura dele em TEMPO_DO_TERMOSTATO, tenha
#       pouco ou muito ar. E é ele que segura a temperatura quando o êmbolo
#       anda: o calor do trabalho do êmbolo (que na fase esquenta o gás) sai
#       pela serpentina na hora. Mexer no volume é uma transformação
#       ISOTÉRMICA, e a temperatura só muda quando a pessoa muda o termostato
#       — assim P · V = n · R · T se lê sem surpresa: apertou, só a pressão
#       sobe.
#   V   O ÊMBOLO PODE FICAR SOLTO (a trava aberta). Solto, ele anda sozinho
#       para a pressão ficar a de quando foi solto: esquentando ou pondo ar,
#       ele sobe; esfriando ou tirando, ele desce (as leis de Charles e de
#       Avogadro). Pegar nele (o cabo, as setas) trava de novo.
#   GÁS IDEAL   nada vira líquido (GasFechado.pode_condensar desligado). Na
#       faixa do termostato e abaixo de 4 atm o ar de verdade também não
#       viraria: ele só condensa abaixo de −140 °C, e bem mais apertado.
#
# A PRESSÃO É SEMPRE A CONSEQUÊNCIA: P = n·R·T/V. Passou da ruptura, estoura,
# com a mesma conta da fase (MaquinaDeCompressao._conferir_a_ruptura).
#
# OS NÚMEROS: começa como a fase, com 1 mol de ar da sala (1 atm, 25 °C,
# 24,47 L). Daí, estoura com uns 4 mol na caixa cheia, com 1 mol apertado até
# uns 6 L, ou com 1 mol esquentado acima de uns 920 °C (P dobra quando a
# temperatura em KELVIN dobra: de 298 K para 596 K, que são 323 °C).

## O volume com o êmbolo no fim do curso (L): o que sobra de caixa embaixo dele.
const VOLUME_MINIMO := VOLUME_DO_CILINDRO
## Quanto ar cada bolinha da tela vale: 1 mol são 50 bolinhas.
const MOL_POR_BOLINHA := 0.02
## O começo: 1 mol, o ar da sala com a câmara cheia (o mesmo da fase).
const BOLINHAS_NO_COMECO := 50
## O máximo que a bomba consegue pôr: 10 mol. Em nenhuma temperatura do
## termostato isso cabe sem estourar antes.
const BOLINHAS_MAXIMAS := 500
## A faixa do termostato, em °C.
const TERMOSTATO_MINIMO := -150.0
const TERMOSTATO_MAXIMO := 1000.0
## Quantos graus por segundo o termostato muda até chegar no que foi pedido.
const VELOCIDADE_DO_TERMOSTATO := 400.0
## Em quanto tempo (s) o gás chega perto da temperatura do termostato (a
## constante de tempo da troca de calor), qualquer que seja a quantidade de ar.
const TEMPO_DO_TERMOSTATO := 0.35
## A menor pressão que o êmbolo solto segura (atm): solto com a máquina
## vazia, ele não teria onde parar.
const PRESSAO_MINIMA_DO_EMBOLO_SOLTO := 0.05

## Quantas bolinhas de ar há dentro da máquina (n = bolinhas · MOL_POR_BOLINHA).
var bolinhas: int = BOLINHAS_NO_COMECO
## A trava do êmbolo aberta: ele anda sozinho para segurar "pressao_segurada".
var embolo_solto: bool = false
var pressao_segurada: float = 1.0


func reiniciar() -> void:
	super.reiniciar()
	gas.pode_condensar = false
	bolinhas = BOLINHAS_NO_COMECO
	gas.mudar_quantidade(bolinhas * MOL_POR_BOLINHA)
	embolo_solto = false
	pressao_segurada = gas.pressao()


# ─────────────────────────────────────────────────────────────
# O QUE A PESSOA FAZ
# ─────────────────────────────────────────────────────────────

## Leva o êmbolo para "nova" (0 = alto, 1 = fim). Pegar nele trava de novo:
## solto, ele para onde está antes de ir.
func mandar_embolo(nova: float) -> void:
	if embolo_solto:
		travar_embolo()
	super.mandar_embolo(nova)


## Abre a trava: daqui em diante o êmbolo segura a pressão de agora.
func soltar_embolo() -> void:
	if estourado or embolo_solto:
		return
	embolo_solto = true
	pressao_segurada = maxf(gas.pressao(), PRESSAO_MINIMA_DO_EMBOLO_SOLTO)


## Fecha a trava: o êmbolo para onde está.
func travar_embolo() -> void:
	embolo_solto = false
	alvo = posicao


func pedir_temperatura(kelvin: float) -> void:
	if estourado:
		return
	temperatura_pedida = clampf(kelvin, GasFechado.kelvin(TERMOSTATO_MINIMO), GasFechado.kelvin(TERMOSTATO_MAXIMO))


## Bolinhas que entraram (positivo) ou saíram (negativo) pelo furo do
## cilindro.
func mudar_bolinhas(quantas: int) -> void:
	if estourado:
		return
	bolinhas = clampi(bolinhas + quantas, 0, BOLINHAS_MAXIMAS)
	gas.mudar_quantidade(bolinhas * MOL_POR_BOLINHA)


# ─────────────────────────────────────────────────────────────
# O TEMPO PASSANDO
# ─────────────────────────────────────────────────────────────

func _passo(dt: float) -> void:
	temperatura_da_serpentina = move_toward(temperatura_da_serpentina, temperatura_pedida,
		VELOCIDADE_DO_TERMOSTATO * dt)
	# Solto, o êmbolo procura o volume em que a pressão é a segurada.
	if embolo_solto:
		alvo = posicao_do_volume(gas.mols * GasFechado.R * gas.temperatura / pressao_segurada)
	if not is_equal_approx(posicao, alvo):
		posicao = move_toward(posicao, alvo, VELOCIDADE_DO_EMBOLO * dt)
		# Isotérmica: o termostato leva o calor do trabalho do êmbolo na hora.
		var antes := gas.temperatura
		gas.mudar_volume(volume())
		gas.definir_temperatura(antes)
	# A troca de calor cresce com a quantidade de ar: o termostato leva
	# qualquer quantidade à temperatura dele no mesmo tempo.
	gas.trocar_calor_com(temperatura_da_serpentina, gas.mols * GasFechado.CV_GAS / TEMPO_DO_TERMOSTATO, dt)
	var p := gas.pressao()
	pressao_maxima = maxf(pressao_maxima, p)
	_conferir_a_ruptura(p, dt)


# ─────────────────────────────────────────────────────────────
# PERGUNTAS
# ─────────────────────────────────────────────────────────────

## A posição do êmbolo (0 = alto, 1 = fim) em que a máquina tem "litros",
## presa ao curso (de VOLUME_MINIMO à caixa cheia).
static func posicao_do_volume(litros: float) -> float:
	return clampf(1.0 - (litros - VOLUME_MINIMO) / (VOLUME_TOTAL - VOLUME_MINIMO), 0.0, 1.0)


func cabe_mais_ar() -> bool:
	return not estourado and bolinhas < BOLINHAS_MAXIMAS


func tem_ar() -> bool:
	return not estourado and bolinhas > 0
