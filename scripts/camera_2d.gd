extends Camera2D

var shake_amount: float = 0.0
var shake_decay: float = 25.0 # O quão rápido o tremor vai sumindo

var zoom_padrao : Vector2
var posicao_padrao : Vector2
var tween_foco : Tween = null

# Enquadramentos especiais: AndarCamera (outro nível da fase, ver
# andar_camera.gd), ZonaCamera (corredor vertical, ver zona_camera.gd) e
# TrilhoCamera (rampas, ver trilho_camera.gd), nessa ordem de prioridade.
# Enquanto um deles comanda, os limites da fase ficam guardados aqui para
# voltar quando a personagem sair.
var _andar_ativo : Node = null
## Andar segurado no ar (ver _enquadrar_andar): distância mínima entre a
## personagem e a borda de cima ou de baixo da tela.
const MARGEM_ANDAR_SEGURADO := 110.0
var _zona_ativa : Node = null
var _trilho_ativo : Node = null
var _limites_guardados : bool = false
var _limite_left_fase : int = 0
var _limite_right_fase : int = 0
var _limite_top_fase : int = 0
var _limite_bottom_fase : int = 0
var _alvo_y_zona : float = 0.0
var _primeiro_quadro : bool = true


func _ready() -> void:
	zoom_padrao = zoom
	posicao_padrao = position


func _process(delta: float) -> void:
	_atualizar_enquadramento()

	if shake_amount > 0.0:
		# Reduz o tremor gradativamente ao longo do tempo
		shake_amount = move_toward(shake_amount, 0.0, shake_decay * delta)

		# Aplica o tremor mudando o offset (deslocamento) da câmera aleatoriamente
		offset.x = randf_range(-shake_amount, shake_amount)
		offset.y = randf_range(-shake_amount, shake_amount)
	else:
		# Quando o tremor acaba, garante que a câmera volte para a posição original (0,0)
		offset = Vector2.ZERO


# Andares, zonas e trilhos mexem só nos LIMITES da câmera (e não na posição).
# Assim continua valendo tudo o que já existia: o position_smoothing (que faz
# as trocas deslizarem), o tremor no offset e o aproximar()/restaurar() dos
# diálogos.
func _atualizar_enquadramento() -> void:
	var alvo := get_parent() as Node2D
	if alvo == null:
		return

	var andar := _achar_andar(alvo)
	var zona: Node = null
	var trilho: Node = null
	if andar == null:
		zona = _achar_zona(alvo)
		if zona == null:
			trilho = _primeiro_do_grupo(&"trilho_camera",
				func(t: Node) -> bool: return t.cobre(alvo.global_position.x))

	if andar == null and zona == null and trilho == null \
			and not (alvo is CharacterBody2D and (alvo as CharacterBody2D).is_on_floor()):
		# Saiu de um enquadramento especial NO AR (ex.: subindo do corredor
		# para o andar, que só assume ao pousar): segura o que estava até ela
		# pousar. Sem isso a câmera despencava por um instante até os limites
		# da fase, lá embaixo.
		if is_instance_valid(_andar_ativo):
			andar = _andar_ativo
		elif is_instance_valid(_zona_ativa):
			zona = _zona_ativa
		elif is_instance_valid(_trilho_ativo):
			trilho = _trilho_ativo

	if andar == null and zona == null and trilho == null:
		if _limites_guardados:
			limit_left = _limite_left_fase
			limit_right = _limite_right_fase
			limit_top = _limite_top_fase
			limit_bottom = _limite_bottom_fase
			_limites_guardados = false
		_andar_ativo = null
		_zona_ativa = null
		_trilho_ativo = null
		_primeiro_quadro = false
		return

	if not _limites_guardados:
		# Os limites da fase só são lidos aqui, na entrada: assim vale o que o
		# FaseBase (ou qualquer outro script) tiver definido antes.
		_limite_left_fase = limit_left
		_limite_right_fase = limit_right
		_limite_top_fase = limit_top
		_limite_bottom_fase = limit_bottom
		_limites_guardados = true

	# Metade do tamanho visível no mundo; muda com o zoom do aproximar().
	var meia := get_viewport_rect().size / zoom * 0.5
	if andar != null:
		_enquadrar_andar(andar, alvo)
	elif zona != null:
		_enquadrar_zona(zona, alvo, meia)
	else:
		_enquadrar_trilho(trilho, alvo, meia)
	_andar_ativo = andar
	_zona_ativa = zona
	_trilho_ativo = trilho

	# Nasceu já dentro (ex: "Testar A Partir Daqui"): começa no lugar certo em
	# vez de deslizar desde o enquadramento antigo.
	if _primeiro_quadro:
		_primeiro_quadro = false
		reset_smoothing()


# Andar: assume só quando a personagem pisa dentro dele (chegar pulando não
# troca a câmera no ar) e larga assim que ela sai do retângulo.
func _achar_andar(alvo: Node2D) -> Node:
	if is_instance_valid(_andar_ativo) and _andar_ativo.contem(alvo.global_position):
		return _andar_ativo
	var pisando := alvo is CharacterBody2D and (alvo as CharacterBody2D).is_on_floor()
	if not pisando:
		return null
	return _primeiro_do_grupo(&"andar_camera",
		func(a: Node) -> bool: return a.contem(alvo.global_position))


# Zona: a que já comanda segue valendo enquanto a personagem estiver dentro;
# para uma zona nova assumir, vale a regra de entrada dela (pode_assumir).
func _achar_zona(alvo: Node2D) -> Node:
	var p := alvo.global_position
	if is_instance_valid(_zona_ativa) and _zona_ativa.contem(p):
		return _zona_ativa
	return _primeiro_do_grupo(&"zona_camera",
		func(z: Node) -> bool: return z.pode_assumir(p))


# Outro nível da fase: igual ao começo dela, só que com o topo e a base do
# retângulo do andar.
func _enquadrar_andar(andar: Node, alvo: Node2D) -> void:
	var area: Rect2 = andar.get_global_rect()
	limit_left = _limite_left_fase
	limit_right = _limite_right_fase
	var topo := area.position.y
	var base := area.end.y
	# Andar segurado no ar com a personagem já fora do retângulo: a faixa
	# acompanha para ela não sumir da tela antes de pousar.
	var y := alvo.global_position.y
	if y < topo + MARGEM_ANDAR_SEGURADO:
		var subir := topo + MARGEM_ANDAR_SEGURADO - y
		if not andar.contem(alvo.global_position):
			topo -= subir
			base -= subir
	elif y > base - MARGEM_ANDAR_SEGURADO and not andar.contem(alvo.global_position):
		var descer := y - (base - MARGEM_ANDAR_SEGURADO)
		topo += descer
		base += descer
	limit_top = roundi(topo)
	limit_bottom = roundi(base)


# Rampas: a altura do centro vem da linha do trilho para o x da personagem.
func _enquadrar_trilho(trilho: Node, alvo: Node2D, meia: Vector2) -> void:
	limit_left = _limite_left_fase
	limit_right = _limite_right_fase

	var centro: float = trilho.altura_em(alvo.global_position.x)
	# Rede de segurança: por mais alto que seja o pulo ou mais funda a queda,
	# a personagem nunca sai do quadro.
	var alcance := maxf(meia.y - trilho.margem_personagem, 0.0)
	centro = clampf(centro, alvo.global_position.y - alcance, alvo.global_position.y + alcance)

	limit_top = roundi(centro - meia.y - trilho.folga_vertical)
	limit_bottom = roundi(centro + meia.y + trilho.folga_vertical)


# Corredor vertical: x travado, altura escolhida por pouso.
func _enquadrar_zona(zona: Node, alvo: Node2D, meia: Vector2) -> void:
	var x_fixo: float = zona.centro_x
	# Mesmo travada, não deixa a personagem sair pelos lados (pulo longo no ar).
	var margem_x: float = zona.margem_lateral
	if not zona.contem(alvo.global_position):
		# Zona segurada no ar com a personagem já fora dela: mesmo com o x
		# travado de verdade, ela não pode ficar cortada na borda da tela.
		margem_x = maxf(margem_x, zona.margem_personagem)
	var alcance_x := maxf(meia.x - margem_x, 0.0)
	x_fixo = clampf(x_fixo, alvo.global_position.x - alcance_x, alvo.global_position.x + alcance_x)
	limit_left = roundi(x_fixo - meia.x)
	limit_right = roundi(x_fixo + meia.x)

	var y := alvo.global_position.y
	if zona != _zona_ativa:
		# Acabou de entrar: parte da altura em que a câmera já está.
		_alvo_y_zona = get_screen_center_position().y

	var pisando := alvo is CharacterBody2D and (alvo as CharacterBody2D).is_on_floor()
	if pisando or not zona.subir_so_ao_pousar:
		_alvo_y_zona = y + zona.altura_do_olhar

	# Teto e chão da câmera dentro da zona.
	var menor_centro: float = zona.limite_topo + meia.y
	var maior_centro: float = zona.limite_base - meia.y
	if menor_centro <= maior_centro:
		_alvo_y_zona = clampf(_alvo_y_zona, menor_centro, maior_centro)

	# A personagem nunca sai do quadro (vem por último: vence os limites).
	var alcance := maxf(meia.y - zona.margem_personagem, 0.0)
	_alvo_y_zona = clampf(_alvo_y_zona, y - alcance, y + alcance)

	limit_top = roundi(_alvo_y_zona - meia.y)
	limit_bottom = roundi(_alvo_y_zona + meia.y)


func _primeiro_do_grupo(grupo: StringName, criterio: Callable) -> Node:
	for n in get_tree().get_nodes_in_group(grupo):
		if criterio.call(n):
			return n
	return null


# Função que outros scripts vão chamar para ativar o tremor
func disparar_tremor(intensidade: float):
	shake_amount = intensidade


# Aproxima a câmera de um personagem (ou do ponto médio entre a câmera e ele),
# dando zoom in. Como a câmera é filha do player, "position" aqui é um
# deslocamento local — não mexe em "offset" pra não brigar com o shake.
func aproximar(alvo: Node2D, zoom_alvo: float = 2.2, duracao: float = 0.6) -> void:
	if tween_foco and tween_foco.is_valid():
		tween_foco.kill()

	var deslocamento_local = Vector2.ZERO
	if alvo:
		# Desloca a câmera até a metade do caminho até o alvo (em coordenadas locais do player)
		deslocamento_local = (alvo.global_position - global_position) * 0.5

	tween_foco = create_tween()
	tween_foco.set_parallel(true)
	tween_foco.tween_property(self, "zoom", Vector2(zoom_alvo, zoom_alvo), duracao).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween_foco.tween_property(self, "position", posicao_padrao + deslocamento_local, duracao).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# Volta a câmera ao zoom/posição normais (ex: quando o diálogo termina).
func restaurar(duracao: float = 0.6) -> void:
	if tween_foco and tween_foco.is_valid():
		tween_foco.kill()

	tween_foco = create_tween()
	tween_foco.set_parallel(true)
	tween_foco.tween_property(self, "zoom", zoom_padrao, duracao).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween_foco.tween_property(self, "position", posicao_padrao, duracao).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
