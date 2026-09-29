extends SceneTree

# Teste da lista de objetivos (Objetivos + RoteiroObjetivos + ObjetivosHUD) e
# das setas "POR AQUI" da Oficina do Carbono (SetaGuia).
#
#   godot --headless --fixed-fps 60 --path . -s res://tools/teste_objetivos.gd
#
# Casos:
#   * todo caminho de nó que o roteiro consulta existe na cena dele;
#   * nada aparece antes da missão do cientista; depois, H₂ e O₂ juntos;
#   * o subitem "Use a caixa arrastável" entra logo abaixo do O₂ quando a
#     Cacau empurra a caixa (ou pega o H₂), e sai com check junto com o O₂;
#   * cumprir dá check (verde + som) e o próximo só entra depois dele;
#   * cumprido com a lista escondida (fala/ficha aberta) espera ela voltar;
#   * "Entre no laboratório" é cumprido na cena seguinte;
#   * apertar E na porta de metal sem o maçarico adianta "Pegue o maçarico",
#     e a linha continua a mesma quando a etapa dele chega;
#   * no laboratório, depois da revelação, aparece só a trilha do Carbono —
#     as alas vêm uma de cada vez, na ordem do jogo;
#   * visitar a Torre antes de terminar a oficina não pula a oficina no
#     laboratório — mas dentro da Torre vale só a trilha da Torre;
#   * a seta de descer só aparece depois de um tempo parada em cima do pilar;
#   * depois da queda, a seta de voltar aponta para a esquerda, some perto da
#     porta e se aposenta quando a porta derrete.

# O roteiro (e as setas) usam autoloads: carregados só depois que eles
# existem — o -s compila este arquivo antes deles.
var R: GDScript
var WORLD1: String
var LAB: String
var FASE1: String
var FASE1_2: String
var FASE2: String
## Marcas que a caixa e a porta de metal deixam no EstadoMundo.
var MARCA_EMPURRADA: String
var MARCA_TENTOU: String

var _falhas := 0


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	R = load("res://scripts/roteiro_objetivos.gd")
	WORLD1 = R.WORLD1
	LAB = R.LAB
	FASE1 = R.FASE1
	FASE1_2 = R.FASE1_2
	FASE2 = R.FASE2
	MARCA_EMPURRADA = load("res://scripts/caixa.gd").MARCA_EMPURRADA
	MARCA_TENTOU = load("res://scripts/fases/porta_metal_macarico.gd").MARCA_TENTOU
	await _testar_caminhos()
	_zerar_estado()
	await _testar_prologo()
	await _testar_oficina()
	await _testar_quebra_de_sequencia()
	await _testar_setas()

	print("")
	if _falhas == 0:
		print(">>> TUDO OK <<<")
	else:
		print(">>> %d FALHA(S) <<<" % _falhas)
	quit(1 if _falhas > 0 else 0)


# ─────────────────────────────────────────────

func _testar_caminhos() -> void:
	print("\n[caminhos do roteiro]")
	for cena in R.CAMINHOS_POR_CENA:
		await _abrir(cena)
		for caminho in R.CAMINHOS_POR_CENA[cena]:
			_checar(root.get_node_or_null(caminho) != null, "%s existe" % caminho)


func _testar_prologo() -> void:
	print("\n[prólogo]")
	await _abrir(WORLD1)
	await _segundos(0.6)
	_checar(_ids().is_empty(), "nada aparece antes da conversa com o cientista")

	_marcar(R.CIENTISTA_WORLD1, "plataforma")
	await _segundos(1.0)
	_checar(_ids() == PackedStringArray(["h2", "o2"]), "missão aceita: H₂ e O₂ aparecem juntos (%s)" % [_ids()])
	_checar(_hud().titulos() == PackedStringArray(["COMBUSTÃO DO HIDROGÊNIO"]),
		"cabeçalho é o da trilha (%s)" % [_hud().titulos()])

	# Encostou na caixa: a dica entra como subitem do O₂.
	_marcar(R.CAIXA_WORLD1, MARCA_EMPURRADA)
	await _segundos(1.0)
	_checar(_ids() == PackedStringArray(["h2", "o2", "caixa"]),
		"empurrou a caixa: 'Use a caixa arrastável' aparece (%s)" % [_ids()])
	var caixa := _linha("caixa")
	_checar(caixa != null and caixa.pai == "o2" and caixa.tam < ObjetivosHUD.TAM_TEXTO,
		"é subitem do O₂ (recuado e menor)")

	_marcar(R.ITEM_H2)
	await _segundos(0.3)
	_checar(_estado("h2") == ObjetivosHUD.Estado.CUMPRIDA, "pegar o H₂ dá o check")
	_checar(_hud()._som.playing, "e toca o check.mp3")
	_checar(_estado("o2") == ObjetivosHUD.Estado.ATIVA, "o O₂ continua valendo")
	_checar(_estado("caixa") == ObjetivosHUD.Estado.ATIVA, "e a dica da caixa também")
	await _segundos(2.8)
	_checar(not _hud().tem("h2"), "o H₂ cumprido sai da lista")

	# Cumprido com a lista escondida: o check espera.
	root.get_node("Inventario").popup_aberto = true
	await _segundos(0.4)
	_marcar(R.ITEM_O2)
	await _segundos(1.0)
	_checar(_linha("o2") != null and _linha("o2").estado == ObjetivosHUD.Estado.ATIVA \
		and _linha("o2").cumprir_na_fila, "com a ficha aberta, o check do O₂ espera")
	_checar(_linha("caixa") != null and _linha("caixa").cumprir_na_fila, "e o da caixa, junto")
	_checar(_esperando("computador"), "e o próximo objetivo espera invisível")
	root.get_node("Inventario").popup_aberto = false
	await _segundos(0.5)
	_checar(_estado("o2") == ObjetivosHUD.Estado.CUMPRIDA, "fechou a ficha: agora sim o check")
	await _segundos(0.35)
	_checar(_estado("caixa") == ObjetivosHUD.Estado.CUMPRIDA, "e a caixa ganha o dela logo depois")
	_checar(_esperando("computador"), "o computador espera o check assentar")
	await _segundos(1.0)
	_checar(_estado("computador") in [ObjetivosHUD.Estado.ENTRANDO, ObjetivosHUD.Estado.ATIVA],
		"e entra em seguida")
	_checar(_linha("computador").texto == "Coloque os cilindros no computador",
		"texto do computador sem 'ao lado do laser'")

	EstadoMundo.passagem_laser_aberta = true
	await _segundos(1.5)
	_checar(_hud().tem("entrar_lab"), "laser aberto: 'Entre no laboratório'")

	await _abrir(LAB)
	await _segundos(1.5)
	_checar(_estado("entrar_lab") == ObjetivosHUD.Estado.CUMPRIDA, "entrar no laboratório dá o check")
	await _segundos(3.0)
	_checar(_ids().is_empty(), "antes da revelação, nada novo aparece")

	EstadoMundo.revelou_dr_chico = true
	await _segundos(1.0)
	_checar(_pendentes() == PackedStringArray(["entrar_oficina"]),
		"depois da revelação: só 'Entre na Ala de Pirólise' (%s)" % [_pendentes()])
	_checar(_linha("entrar_oficina").texto == "Entre na Ala de Pirólise", "com esse texto")
	await _segundos(1.0)
	_checar(_hud().titulos() == PackedStringArray(["CARBONO"]), "só o cabeçalho CARBONO (%s)" % [_hud().titulos()])


func _testar_oficina() -> void:
	print("\n[ala de pirólise]")
	var progresso := root.get_node("Progresso")
	await _abrir(FASE1)
	await _segundos(1.0)
	_checar(_pendentes() == PackedStringArray(["bumerangue"]), "entrou na oficina: pegar o bumerangue (%s)" % [_pendentes()])
	_checar(_hud().titulos() == PackedStringArray(["CARBONO"]), "dentro da oficina, só o CARBONO (%s)" % [_hud().titulos()])

	# E na porta de metal sem o maçarico: o maçarico entra adiantado.
	_marcar(R.PORTA_METAL_ELEVADOR, MARCA_TENTOU)
	await _segundos(1.0)
	_checar(_pendentes() == PackedStringArray(["bumerangue", "macarico"]),
		"tentou a porta de metal: 'Pegue o maçarico' entra adiantado (%s)" % [_pendentes()])
	var macarico := _linha("macarico")

	progresso._habilidades["bumerangue"] = true
	await _segundos(2.0)
	_checar(_pendentes() == PackedStringArray(["macarico", "espinhos"]),
		"bumerangue na mão: desativar os espinhos de laser (%s)" % [_pendentes()])

	_marcar(R.ESPINHOS_TREINO)
	await _segundos(2.0)
	_checar(_pendentes() == PackedStringArray(["macarico"]), "espinhos desligados: só o maçarico (%s)" % [_pendentes()])
	_checar(_linha("macarico") == macarico, "e é a mesma linha, sem sair e voltar")
	_checar(macarico.texto == "Pegue o maçarico no domo de vidro", "domo de vidro, não gaiola")

	progresso._habilidades["macarico"] = true
	await _segundos(2.0)
	_checar(_hud().tem("porta_metal"), "com o maçarico, a próxima é a porta de metal (%s)" % [_ids()])

	_marcar(R.PORTA_METAL)
	await _segundos(1.5)
	_checar(_hud().tem("porta_elevador"), "derreteu a de cima: voltar e derreter a do elevador")
	_marcar(R.PORTA_METAL_ELEVADOR)
	await _segundos(1.5)
	_checar(_hud().tem("patio") and _linha("patio").texto == "Suba até o pátio", "depois: 'Suba até o pátio'")

	await _abrir(FASE1_2)
	await _segundos(2.5)
	_checar(_pendentes() == PackedStringArray(["carvao"]), "no pátio: um objetivo só para o carvão (%s)" % [_pendentes()])
	_checar(_linha("carvao").texto == "Faça carvão a partir das madeiras", "com esse texto (sem 'babaçu')")
	progresso._amostras["C"] = true
	await _segundos(2.0)
	_checar(_hud().tem("entregar_c"), "carvão na mão: levar ao receptor")


func _testar_quebra_de_sequencia() -> void:
	print("\n[quebra de sequência]")
	# Visita a Torre com a oficina pela metade.
	await _abrir(FASE2)
	await _segundos(2.5)
	_checar(_hud().tem("alavanca") and _hud().tem("chapa"), "dentro da Torre vale a trilha da Torre (%s)" % [_ids()])
	_checar(_hud().titulos() == PackedStringArray(["NITROGÊNIO"]), "só com o cabeçalho NITROGÊNIO (%s)" % [_hud().titulos()])
	_checar(not _hud().tem("entregar_c") and not _hud().tem("entrar_subsolo"), "sem as outras alas")
	await _abrir(LAB)
	await _segundos(2.5)
	_checar(_hud().tem("entregar_c"), "no laboratório volta a valer a oficina (%s)" % [_ids()])
	_checar(not _hud().tem("alavanca") and not _hud().tem("entrar_subsolo"),
		"sem a Torre nem o subsolo, que vêm depois (%s)" % [_ids()])
	_checar(_hud().titulos() == PackedStringArray(["CARBONO"]), "só com o cabeçalho CARBONO (%s)" % [_hud().titulos()])


func _testar_setas() -> void:
	print("\n[setas da oficina]")
	# A porta do elevador ainda inteira (o teste da oficina a derreteu).
	EstadoMundo._feitos.erase(R.PORTA_METAL_ELEVADOR)
	await _abrir(FASE1)
	var fase := current_scene
	var descer := fase.get_node("GuiasDeCaminho/SetaDescer")
	var voltar := fase.get_node("GuiasDeCaminho/SetaVoltarAoInicio")
	var player := fase.get_node("Player") as CharacterBody2D

	# Em cima do pilar do corredor das torretas (topo em y = -64).
	player.global_position = Vector2(2790, -110)
	player.velocity = Vector2.ZERO
	await _segundos(1.0)
	_checar(player.is_on_floor(), "a Cacau pousa no pilar")
	_checar(not descer._seta.mostrando(), "logo ao pousar, ainda sem seta")
	await _segundos(1.4)
	_checar(descer._seta.mostrando(), "parada um tempo no pilar: seta para baixo")
	_checar(not voltar._seta.mostrando(), "a de voltar ainda não")

	# Caiu: chão do corredor lá embaixo.
	player.global_position = Vector2(2640, 470)
	player.velocity = Vector2.ZERO
	await _segundos(0.2)
	_checar(not descer._seta.mostrando(), "saiu do pilar: a de descer some")
	await _segundos(0.6)
	_checar(voltar._seta.mostrando(), "caiu: seta para a esquerda")
	var ponta: Vector2 = voltar._seta.ponta
	_checar(ponta.x < 200.0, "a porta está fora da tela: a seta fica na borda esquerda (%s)" % ponta)

	# Andou para a direita, para longe: a seta continua (fora do gatilho também).
	player.global_position = Vector2(4500, 470)
	await _segundos(0.3)
	_checar(voltar._seta.mostrando(), "mesmo indo para o lado errado, a seta continua")

	# Chegou na porta.
	player.global_position = Vector2(390, 470)
	await _segundos(0.3)
	_checar(not voltar._seta.mostrando(), "perto da porta, a seta some")

	_marcar(R.PORTA_METAL_ELEVADOR)
	player.global_position = Vector2(2640, 470)
	await _segundos(0.6)
	_checar(not voltar._seta.mostrando() and not descer._seta.mostrando(), "porta derretida: setas aposentadas")


# ─────────────────────────────────────────────
#  Auxiliares
# ─────────────────────────────────────────────

func _zerar_estado() -> void:
	EstadoMundo._feitos.clear()
	EstadoMundo._valores.clear()
	EstadoMundo.passagem_laser_aberta = false
	EstadoMundo.revelou_dr_chico = false
	root.get_node("Progresso")._habilidades.clear()
	root.get_node("Progresso")._celulas.clear()
	root.get_node("Progresso")._amostras.clear()
	var objetivos := root.get_node("Objetivos")
	objetivos._visitadas.clear()
	objetivos._cena_atual = ""
	_hud()._linhas.clear()
	_hud()._cabecalhos.clear()


func _hud() -> ObjetivosHUD:
	return root.get_node("Objetivos/Lista") as ObjetivosHUD


func _ids() -> PackedStringArray:
	return _hud().ids()


## Os objetivos na lista que ainda valem (fora os que acabaram de ganhar check).
func _pendentes() -> PackedStringArray:
	var lista := PackedStringArray()
	for linha in _hud()._linhas:
		if not linha.cumprida and linha.estado != ObjetivosHUD.Estado.SAINDO:
			lista.append(linha.id)
	return lista


func _linha(id: String) -> ObjetivosHUD.Linha:
	return _hud()._achar(id)


func _linha_saindo(id: String) -> ObjetivosHUD.Linha:
	for linha in _hud()._linhas:
		if linha.id == id:
			return linha
	return null


func _estado(id: String) -> int:
	var linha := _linha_saindo(id)
	return linha.estado if linha else -1


func _esperando(id: String) -> bool:
	return _estado(id) == ObjetivosHUD.Estado.ESPERANDO


func _marcar(caminho: String, marca: String = "") -> void:
	EstadoMundo._feitos[caminho if marca.is_empty() else caminho + ":" + marca] = true


func _abrir(caminho: String) -> void:
	change_scene_to_file(caminho)
	await _quadros(3)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _segundos(s: float) -> void:
	await create_timer(s, true, false, true).timeout


func _checar(ok: bool, nome: String) -> void:
	print(("  ok   " if ok else "  FALHA ") + nome)
	if not ok:
		_falhas += 1
