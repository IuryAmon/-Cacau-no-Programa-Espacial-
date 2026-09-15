extends Node

# Teste de fumaça da CaixaEletrica: confere a troca de arte, o hitbox, e que o
# som e as faíscas saem no MESMO frame — tanto no baque do bumerangue quanto
# em cada estalo do arco elétrico.
#
#   godot --headless --path . res://tools/teste_caixa_eletrica.tscn

var _falhas := 0


func _ready() -> void:
	await _testar_componente()
	await _testar_na_fase1()
	print("\n>>> %s <<<" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  ok   " if condicao else "  FALHA ") + descricao)
	if not condicao:
		_falhas += 1


## Espera uma condicao virar verdadeira, com teto de tempo (o headless nao pode
## ficar pendurado se algo nao disparar).
func _esperar(condicao: Callable, limite: float) -> bool:
	var gasto := 0.0
	while gasto < limite:
		if condicao.call():
			return true
		await get_tree().process_frame
		gasto += 0.016
	return false


func _abrir(caminho: String) -> Node:
	var raiz: Node = (load(caminho) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(raiz)
	await get_tree().process_frame
	await get_tree().process_frame
	return raiz


func _testar_componente() -> void:
	print("\n--- COMPONENTE: CAIXA ELETRICA ---")
	var caixa: CaixaEletrica = await _abrir("res://scenes/fases/componentes/caixa_eletrica.tscn")

	# --- nós que o designer precisa achar no inspetor ---
	for nome in ["Visual", "Colisao", "LuzArco", "FaiscasImpacto", "FaiscasArco",
			"FiosSoltos", "Fumaca", "SomImpacto", "SomEletricidade", "TempoArco",
			"TempoEstalo", "Rotulo"]:
		_checar(caixa.get_node_or_null(nome) != null, "no '%s' existe" % nome)

	var visual: AnimatedSprite2D = caixa.get_node("Visual")
	var colisao: CollisionShape2D = caixa.get_node("Colisao")
	var som_metal: AudioStreamPlayer2D = caixa.get_node("SomImpacto")
	var som_eletr: AudioStreamPlayer2D = caixa.get_node("SomEletricidade")
	var f_impacto: CPUParticles2D = caixa.get_node("FaiscasImpacto")
	var f_arco: CPUParticles2D = caixa.get_node("FaiscasArco")
	var fios: CPUParticles2D = caixa.get_node("FiosSoltos")
	var quadros := visual.sprite_frames

	# --- arte ---
	_checar(quadros.has_animation(&"intacta"), "animacao 'intacta' existe")
	_checar(quadros.has_animation(&"quebrando"), "animacao 'quebrando' existe")
	_checar(quadros.get_frame_count(&"quebrando") == 4, "'quebrando' tem 4 quadros (0 a 3)")
	_checar(not quadros.get_animation_loop(&"quebrando"), "'quebrando' nao repete (trava no fim)")
	_checar(visual.animation == &"intacta", "comeca na arte intacta")
	_checar(quadros.get_frame_texture(&"intacta", 0).resource_path.ends_with("CAIXA ELETRICA1.png"),
		"sprite principal e o CAIXA ELETRICA1.png")
	for i in 4:
		var esperado := "CAIXA ELETRICA%d.png" % i
		_checar(quadros.get_frame_texture(&"quebrando", i).resource_path.ends_with(esperado),
			"quadro %d da quebra e o %s" % [i, esperado])

	# --- hitbox ---
	_checar(colisao.shape is RectangleShape2D, "hitbox e um retangulo ajustavel")
	_checar(caixa.monitorable, "a Area2D e visivel para o bumerangue")

	# --- som e sons carregados ---
	_checar(som_metal.stream != null and som_metal.stream.resource_path.ends_with("metal hit.mp3"),
		"SomImpacto carrega 'metal hit.mp3'")
	_checar(som_eletr.stream != null and som_eletr.stream.resource_path.ends_with("eletricidade.mp3"),
		"SomEletricidade carrega 'eletricidade.mp3'")

	# --- O ACERTO: som do metal + faiscas no mesmo frame ---
	_checar(not caixa.quebrada, "nasce inteira")
	_checar(not f_impacto.emitting, "faiscas de impacto paradas antes do acerto")
	caixa.atingir_bumerangue()
	_checar(som_metal.playing, "acerto tocou o som de metal")
	_checar(f_impacto.emitting, "acerto soltou as faiscas NO MESMO frame do som")
	_checar(caixa.quebrada, "caixa marcada como quebrada")
	_checar(visual.animation == &"quebrando" and visual.is_playing(), "animacao da quebra rodando")

	# --- FIM DA ANIMACAO: trava no ultimo quadro e comeca o arco ---
	await _esperar(func() -> bool: return not visual.is_playing(), 3.0)
	_checar(visual.frame == 3, "travou no CAIXA ELETRICA3")
	_checar(not visual.is_playing(), "animacao parada no ultimo quadro")
	_checar(som_eletr.playing, "arco tocou 'eletricidade.mp3' depois de quebrada")
	_checar(f_arco.emitting, "faiscas do arco sairam junto com a eletricidade")
	_checar(fios.emitting, "fios soltos chuviscando faiscas")
	_checar(caixa.get_node("Fumaca").emitting, "fumaca subindo")

	# --- O ESPACO ENTRE OS ESTALOS ---
	var tempo: Timer = caixa.get_node("TempoArco")
	_checar(not tempo.is_stopped(), "arco reagendado para o proximo estalo")
	_checar(tempo.wait_time >= caixa.intervalo_arco_min
		and tempo.wait_time <= caixa.intervalo_arco_max,
		"espera sorteada dentro da faixa (%.2fs a %.2fs)"
			% [caixa.intervalo_arco_min, caixa.intervalo_arco_max])
	_checar(caixa.intervalo_arco_min >= 1.0, "espaco entre os choques folgado")

	# A IMAGEM ACOMPANHA A PAUSA: o chuvisco fecha junto com o fim do estalo.
	var fim: Timer = caixa.get_node("TempoEstalo")
	_checar(not fim.is_stopped(), "chuvisco tem hora para acabar")
	fim.stop()
	fim.timeout.emit()
	_checar(not fios.emitting, "fios param de chuviscar na pausa entre os choques")

	# --- ESTALOS SEGUINTES: o relogio reagenda som+faisca+chuvisco juntos ---
	som_eletr.stop()
	f_arco.emitting = false
	tempo.stop()
	tempo.timeout.emit()
	_checar(som_eletr.playing and f_arco.emitting and fios.emitting,
		"novo estalo: som, faisca e chuvisco voltam juntos")

	# --- luz do arco acende ---
	await get_tree().process_frame
	_checar(caixa.get_node("LuzArco").energy > 0.0, "luz do arco acesa")

	caixa.queue_free()
	await get_tree().process_frame


func _testar_na_fase1() -> void:
	print("\n--- FASE 1: AS CAIXAS NO LUGAR DOS ALVOS ---")
	var f := await _abrir("res://scenes/fases/fase1_oficina.tscn")

	# O treino (escola do arremesso) ficou reduzido a uma única caixa de
	# placeholder — o resto da sala é montado a mão no editor.
	for caminho in ["Treino/AlvoFixo1", "Corredores/AlvoDuploA", "Corredores/AlvoDuploB"]:
		var no := f.get_node_or_null(caminho)
		_checar(no is CaixaEletrica, "%s virou CaixaEletrica" % caminho)
		_checar(no != null and no.is_in_group("alvo_bumerangue"),
			"%s continua no grupo do bumerangue" % caminho)

	f.queue_free()
	await get_tree().process_frame
