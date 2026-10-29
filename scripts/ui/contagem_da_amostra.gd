class_name ContagemDaAmostra
extends CanvasLayer

# --- O RELÓGIO DA AMOSTRA GELADA (fase do nitrogênio) ---
#
# Fechada a válvula do compressor, a Cacau sai correndo com o cilindro de ar
# líquido. Ele está ESQUENTANDO: o calor da sala vai entrando, o líquido
# ferve, a pressão sobe — e passou de 4 atm, estoura. Este nó é o relógio dessa
# corrida, e é física de verdade: a cada quadro ele esquenta a amostra
# (MissaoNitrogenio.amostra, um GasFechado) e mostra quanto falta para a
# pressão chegar lá.
#
#   NO ALTO DA TELA   a ficha do relógio: o cilindro gelado, os segundos que
#                     faltam (grandes), o manômetro dele e uma barra da pressão
#                     até a ruptura. Os números mudam de cor e a ficha treme
#                     quando a hora aperta.
#   NAS COSTAS DELA   o cilindro, soltando névoa fria (o ar gelado é pesado:
#                     a névoa escorre para baixo). Nos últimos segundos ele
#                     treme.
#   O SOM             um bipe, cada vez mais rápido; nos últimos 10 s, o bipe
#                     duplo e a borda da tela pulsando em vermelho.
#
# O relógio NÃO anda com o jogo parado nem com fala, ficha ou tela aberta (é
# a mesma regra dos morcegos: não é justo apanhar lendo) — e não anda na
# troca de cena (este nó mora na cena; a próxima monta outro, ver
# MissaoNitrogenio.instalar_na_fase).
#
# Chegou a 4 atm: a Cacau para, o cilindro incha e assobia, e estoura nas
# costas dela (ExplosaoDoCilindro). Acabada a explosão, o fim de jogo
# (TelaGameOver), e tentar de novo volta para o compressor.
#
# Quando a amostra entra na coluna (MissaoNitrogenio.entregar_amostra_na_coluna),
# a ficha se despede com um "CONECTADA!" e o nó some sozinho. A coluna pega o
# cilindro das costas com "tirar_cilindro_das_costas()".

const NOME := "ContagemDaAmostra"
const CAMADA := 85

const FONTE := preload("res://assets/fonts/ari-w9500-display.ttf")
const SOM_BIP := preload("res://sounds/compressor/bip.wav")
const SOM_BIP_URGENTE := preload("res://sounds/compressor/bip_urgente.wav")

## A ficha do relógio, no alto e no meio da tela.
const FICHA := Rect2(620, 16, 360, 96)
## De quanto em quanto tempo (s) a previsão é refeita.
const INTERVALO_DA_PREVISAO := 0.5
## Nos últimos segundos a coisa aperta.
const URGENTE := 10.0
const APERTADO := 20.0

const TXT_ATE := "ATÉ ESTOURAR"
const TXT_CONECTADA := "CONECTADA!"
const TXT_LEVE := "LEVE À COLUNA DE DESTILAÇÃO"

var _painel: Control
var _vinheta: Control
var _bip: AudioStreamPlayer
var _restante: float = INF
var _proxima_previsao: float = 0.0
var _proximo_bip: float = 0.0
var _relogio: float = 0.0
var _entrada: float = 0.0
var _saindo: float = -1.0
var _estourou: bool = false
var _cilindro: Sprite2D = null
var _nevoa: CPUParticles2D = null


func _ready() -> void:
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS

	_vinheta = Control.new()
	_vinheta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vinheta.draw.connect(_desenhar_vinheta)
	add_child(_vinheta)

	_painel = Control.new()
	_painel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_painel.draw.connect(_desenhar_painel)
	add_child(_painel)

	_bip = AudioStreamPlayer.new()
	_bip.stream = SOM_BIP
	_bip.volume_db = -8.0
	add_child(_bip)

	_prever()
	_por_nas_costas.call_deferred()


func _process(delta: float) -> void:
	_relogio += delta
	_entrada = move_toward(_entrada, 1.0, delta / 0.35)

	# A amostra foi entregue: a ficha se despede e o nó some.
	if not MissaoNitrogenio.carregando_amostra():
		if _saindo < 0.0:
			_saindo = 0.0
		_saindo += delta
		if _saindo > 1.4:
			queue_free()
		_painel.queue_redraw()
		_vinheta.queue_redraw()
		return

	if _estourou:
		return
	# No modo dev (ver modo_dev.gd) a amostra não esquenta.
	var parado := get_tree().paused or Interacao.ocupada() or ModoDev.ativo
	if not parado:
		MaquinaDeCompressao.esquentar_amostra(MissaoNitrogenio.amostra, delta)
		_restante = maxf(_restante - delta, 0.0)
		_proxima_previsao -= delta
		if _proxima_previsao <= 0.0:
			_prever()
		_bipar(delta)
		if MissaoNitrogenio.amostra.pressao() >= MaquinaDeCompressao.PRESSAO_DE_RUPTURA:
			_estourar()
	_animar_cilindro()
	_painel.queue_redraw()
	_vinheta.queue_redraw()


## Quanto tempo falta, pela física (refeito de tempos em tempos: a conta
## anda sozinha entre uma previsão e outra).
func _prever() -> void:
	_proxima_previsao = INTERVALO_DA_PREVISAO
	if MissaoNitrogenio.amostra == null:
		return
	_restante = MaquinaDeCompressao.tempo_ate_estourar(MissaoNitrogenio.amostra)


func segundos_restantes() -> float:
	return _restante


func _bipar(delta: float) -> void:
	_proximo_bip -= delta
	if _proximo_bip > 0.0:
		return
	if _restante <= URGENTE:
		_proximo_bip = 0.45
		_bip.stream = SOM_BIP_URGENTE
		_bip.volume_db = -4.0
	elif _restante <= APERTADO:
		_proximo_bip = 0.7
		_bip.stream = SOM_BIP
		_bip.volume_db = -6.0
	else:
		_proximo_bip = 1.0
		_bip.stream = SOM_BIP
		_bip.volume_db = -10.0
	_bip.play()


# ─────────────────────────────────────────────────────────────
# O CILINDRO NAS COSTAS
# ─────────────────────────────────────────────────────────────

func _cacau() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D


func _por_nas_costas() -> void:
	var cacau := _cacau()
	if cacau == null or cacau.get_node_or_null("CilindroNasCostas") != null:
		_cilindro = cacau.get_node_or_null("CilindroNasCostas") if cacau else null
		return
	_cilindro = Sprite2D.new()
	_cilindro.name = "CilindroNasCostas"
	_cilindro.texture = MissaoNitrogenio.TEXTURA_AMOSTRA
	_cilindro.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Atrás dela: o sprite dela está na frente, no mesmo nó.
	_cilindro.z_index = -1
	_cilindro.rotation = deg_to_rad(-14.0)
	cacau.add_child(_cilindro)

	_nevoa = CPUParticles2D.new()
	_nevoa.amount = 14
	_nevoa.lifetime = 1.3
	_nevoa.position = Vector2(0, 14)
	_nevoa.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_nevoa.emission_rect_extents = Vector2(6, 14)
	_nevoa.direction = Vector2(0, 1)
	_nevoa.spread = 40.0
	_nevoa.gravity = Vector2(0, 26)
	_nevoa.initial_velocity_min = 4.0
	_nevoa.initial_velocity_max = 14.0
	_nevoa.scale_amount_min = 2.0
	_nevoa.scale_amount_max = 4.5
	var sumir := Gradient.new()
	sumir.colors = PackedColorArray([Color(0.88, 0.95, 1.0, 0.55), Color(0.88, 0.95, 1.0, 0.0)])
	_nevoa.color_ramp = sumir
	_cilindro.add_child(_nevoa)
	_animar_cilindro()


## Do lado das costas (o contrário de para onde ela olha), e tremendo quando a
## hora aperta.
func _animar_cilindro() -> void:
	if not is_instance_valid(_cilindro):
		return
	var cacau := _cacau()
	if cacau == null:
		return
	var sprite := cacau.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var olhando := -1.0 if sprite and sprite.flip_h else 1.0
	var tremor := Vector2.ZERO
	if _restante < APERTADO:
		var forca := clampf(inverse_lerp(APERTADO, 0.0, _restante), 0.0, 1.0) * 1.6
		tremor = Vector2(randf_range(-forca, forca), randf_range(-forca, forca)).round()
	_cilindro.position = Vector2(-9.0 * olhando, -30.0) + tremor
	_cilindro.rotation = deg_to_rad(-14.0 * olhando)


## A coluna de destilação pega o cilindro: ele sai das costas dela (para a
## coluna animar a ida até a base) e o relógio se despede.
func tirar_cilindro_das_costas() -> Sprite2D:
	var cilindro := _cilindro
	_cilindro = null
	return cilindro


# ─────────────────────────────────────────────────────────────
# ESTOUROU
# ─────────────────────────────────────────────────────────────

func _estourar() -> void:
	if _estourou:
		return
	_estourou = true
	_bip.stop()
	var cacau := _cacau()
	var explosao := ExplosaoDoCilindro.new()
	var cena := get_tree().current_scene
	cena.add_child(explosao)
	explosao.comecar(cacau, _cilindro)
	explosao.terminou.connect(_mostrar_o_fim_de_jogo)


func _mostrar_o_fim_de_jogo() -> void:
	var amostra := MissaoNitrogenio.amostra
	var dados := {"motivo": "amostra",
		"pressao": amostra.pressao() if amostra else MaquinaDeCompressao.PRESSAO_DE_RUPTURA,
		"temperatura": amostra.celsius() if amostra else 0.0}
	TelaGameOver.mostrar(get_tree(), dados, _tentar_de_novo)


func _tentar_de_novo() -> void:
	MissaoNitrogenio.recomecar_depois_da_explosao()
	Engine.time_scale = 1.0
	get_tree().paused = false
	FadeTela.trocar_cena(get_tree().current_scene, MissaoNitrogenio.CENA_COMPRESSOR, 0.6)


# ─────────────────────────────────────────────────────────────
# DESENHO
# ─────────────────────────────────────────────────────────────

func _cor_do_tempo() -> Color:
	if _restante <= URGENTE:
		return Color("e8463a").lerp(Color("ffd0c8"), 0.5 + 0.5 * sin(_relogio * 14.0))
	if _restante <= APERTADO:
		return Color("f2c84b")
	return EstiloHUD.TINTA


func _desenhar_painel() -> void:
	var alfa := ease(_entrada, 0.4)
	if _saindo >= 0.0:
		alfa *= clampf(1.0 - (_saindo - 0.8) / 0.6, 0.0, 1.0)
	if alfa <= 0.0:
		return
	var caixa := FICHA
	caixa.position.y -= roundf((1.0 - ease(_entrada, 0.4)) * 60.0)
	if _restante <= URGENTE and _saindo < 0.0:
		caixa.position += Vector2(randf_range(-2, 2), randf_range(-1, 1)).round()
	EstiloHUD.ficha(_painel, caixa, alfa)

	# O cilindro gelado, à esquerda.
	EstiloHUD.icone(_painel, MissaoNitrogenio.TEXTURA_AMOSTRA, caixa.position + Vector2(40, 48), 64.0,
		Color(1, 1, 1, alfa))

	if _saindo >= 0.0:
		PecasDoLaboratorio.escrever_no_meio(_painel, caixa.get_center() + Vector2(20, -6), TXT_CONECTADA, 30,
			EstiloHUD.com_alfa(Color("1f7a3d"), alfa))
		return

	var amostra := MissaoNitrogenio.amostra
	# Os segundos que faltam, grandes.
	var texto := "--" if _restante == INF else "%d s" % ceili(_restante)
	PecasDoLaboratorio.escrever_no_meio(_painel, caixa.position + Vector2(150, 36), texto, 36,
		EstiloHUD.com_alfa(_cor_do_tempo(), alfa))
	PecasDoLaboratorio.escrever_no_meio(_painel, caixa.position + Vector2(150, 70), TXT_ATE, 11,
		EstiloHUD.com_alfa(EstiloHUD.TINTA_FRACA, alfa))

	# O manômetro dele, à direita, com a pressão e a temperatura embaixo.
	var centro := caixa.position + Vector2(290, 42)
	var p := amostra.pressao()
	_manometro(centro, 26.0, p, alfa)
	var numeros := "%s atm  %s" % [String.num(p, 1).replace(".", ","),
		MisturasDoDestilador.graus(roundf(amostra.celsius()))]
	PecasDoLaboratorio.escrever_no_meio(_painel, centro + Vector2(0, 38), numeros, 11,
		EstiloHUD.com_alfa(EstiloHUD.TINTA, alfa))

	# A barra da pressão, de 1 atm até a ruptura.
	var barra := Rect2(caixa.position.x + 12, caixa.end.y - 14, caixa.size.x - 24, 6)
	_painel.draw_rect(barra, EstiloHUD.com_alfa(EstiloHUD.PAPEL_DOBRA, alfa))
	var cheia := clampf(inverse_lerp(0.5, MaquinaDeCompressao.PRESSAO_DE_RUPTURA, p), 0.0, 1.0)
	var cor := Color("3ecf72").lerp(Color("e8463a"), cheia)
	_painel.draw_rect(Rect2(barra.position, Vector2(roundf(barra.size.x * cheia), barra.size.y)),
		EstiloHUD.com_alfa(cor, alfa))

	# O recado, embaixo da ficha.
	EstiloHUD.rotulo(_painel, FONTE, Vector2(caixa.get_center().x - PecasDoLaboratorio.largura(TXT_LEVE, 13) * 0.5,
		caixa.end.y + 26.0), TXT_LEVE, 13, Color(EstiloHUD.CLARO, alfa * (0.7 + 0.3 * sin(_relogio * 5.0))))


func _manometro(centro: Vector2, raio: float, p: float, alfa: float) -> void:
	_painel.draw_circle(centro, raio + 3.0, EstiloHUD.com_alfa(EstiloHUD.CONTORNO, alfa))
	_painel.draw_circle(centro, raio, EstiloHUD.com_alfa(Color("f4ead3"), alfa))
	var inicio := deg_to_rad(135.0)
	var volta := deg_to_rad(270.0)
	var trabalho := MaquinaDeCompressao.PRESSAO_DE_TRABALHO / 5.0
	var ruptura := MaquinaDeCompressao.PRESSAO_DE_RUPTURA / 5.0
	_painel.draw_arc(centro, raio - 4.0, inicio, inicio + volta * trabalho, 12, EstiloHUD.com_alfa(Color("3ecf72"), alfa), 4.0)
	_painel.draw_arc(centro, raio - 4.0, inicio + volta * trabalho, inicio + volta * ruptura, 8, EstiloHUD.com_alfa(Color("f2c84b"), alfa), 4.0)
	_painel.draw_arc(centro, raio - 4.0, inicio + volta * ruptura, inicio + volta, 8, EstiloHUD.com_alfa(Color("e8463a"), alfa), 4.0)
	var tremida := randf_range(-0.05, 0.05) if _restante <= URGENTE else 0.0
	var angulo := inicio + volta * clampf(p / 5.0, 0.0, 1.05) + tremida
	_painel.draw_line(centro, centro + Vector2.from_angle(angulo) * (raio - 6.0), EstiloHUD.com_alfa(Color("c0392b"), alfa), 3.0)
	_painel.draw_circle(centro, 3.0, EstiloHUD.com_alfa(EstiloHUD.CONTORNO, alfa))


## Nos últimos segundos a borda da tela pulsa em vermelho.
func _desenhar_vinheta() -> void:
	if _saindo >= 0.0 or _restante > URGENTE or _estourou:
		return
	var forca := clampf(inverse_lerp(URGENTE, 0.0, _restante), 0.0, 1.0)
	var pulso := 0.5 + 0.5 * sin(_relogio * (6.0 + forca * 8.0))
	var tela := _vinheta.get_viewport_rect().size
	var cor := Color(0.85, 0.08, 0.05, (0.12 + 0.22 * forca) * pulso)
	for i in 6:
		var borda := 14.0 + i * 14.0
		var c := Color(cor, cor.a * (1.0 - i / 6.0))
		_vinheta.draw_rect(Rect2(0, 0, tela.x, borda), c)
		_vinheta.draw_rect(Rect2(0, tela.y - borda, tela.x, borda), c)
		_vinheta.draw_rect(Rect2(0, 0, borda, tela.y), c)
		_vinheta.draw_rect(Rect2(tela.x - borda, 0, borda, tela.y), c)
