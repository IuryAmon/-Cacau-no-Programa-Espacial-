extends SceneTree

# --- ESTICA O CHÃO DA FASE 1 PARA A DIREITA ---
#
#   godot --headless --script res://tools/estender_chao_fase1.gd
#
# Ele NÃO regrava a cena: mexer numa cena que instancia outras (Player, serras,
# gaiolas...) e salvá-la de volta com ResourceSaver achataria todas essas
# instâncias em nós soltos. Em vez disso ele só monta o TileMapLayer em memória
# e cospe o "tile_map_data" novo em base64 num arquivo — quem troca a linha
# dentro do .tscn é o passo seguinte, no texto, sem tocar em mais nada.
#
# --- O PADRÃO DO CHÃO, LIDO DO PRÓPRIO MAPA ---
#
# A superfície são DUAS linhas (16 e 17) da fonte 12, e o atlas x anda em ciclo
# de quatro — 2, 3, 4, 5, 2, 3, 4, 5... — de forma que a coluna manda no tile:
# atlas x = CICLO[coluna % 4]. As DUAS últimas colunas fogem do ciclo e usam
# 6 e 7, que são as peças de PONTA do tileset (é o que fecha o chão do lado
# direito). Abaixo, as linhas 18 a 22 são só preenchimento, sorteado entre dois
# tiles quase iguais — menos as duas últimas, que são sólidas.
#
# A "parede" do fim é um pilar de duas colunas da fonte 13 — a peça (2,0) fecha
# o topo e a (2,2) faz o corpo, da linha -13 até a 15, apoiado na superfície.
# Ele fica sempre encostado nas duas colunas de ponta, então esticar a fase é
# levar esse bloco inteiro para a direita: o script apaga o pilar antigo do
# trecho que reconstrói e o redesenha na ponta nova.
#
# --- PARA ESTICAR DE NOVO DEPOIS ---
#
# Aumente COLUNA_FIM e rode outra vez. CUIDADO: o trecho de COLUNA_INICIO até
# COLUNA_FIM é REDESENHADO, então suba o COLUNA_INICIO se você já tiver
# construído alguma coisa lá dentro — o que estiver no caminho vira chão liso.

const CENA := "res://scenes/fases/fase1_oficina.tscn"
const SAIDA := "user://terreno_fase1.b64"

## Nova ponta direita da fase. A borda fica em (COLUNA_FIM + 1) × 32 px.
const COLUNA_FIM := 325   # x = 10432 (a fase terminava em 7872)
## De onde o chão é redesenhado. Cai antes da ponta antiga e depois de tudo o
## que já estava construído no mapa.
const COLUNA_INICIO := 240

# --- Assinatura dos tiles (medida no mapa atual) ---
const FONTE_CHAO := 12
const LINHA_SUPERFICIE := 16
const LINHA_MIOLO := 18
const LINHA_FUNDO := 22
## As duas últimas linhas do miolo não sorteiam nada.
const LINHAS_SOLIDAS := 2
const SUPERFICIE_CICLO := [2, 3, 4, 5]
const SUPERFICIE_PONTA := [6, 7]
const MIOLO_A := Vector2i(10, 4)
const MIOLO_B := Vector2i(11, 4)

const FONTE_PILAR := 13
## A primeira linha do pilar é uma peça de acabamento, diferente do corpo — sem
## ela o pilar sai com o topo cortado.
const TILE_PILAR_TOPO := Vector2i(2, 0)
const TILE_PILAR := Vector2i(2, 2)
const PILAR_LINHA_TOPO := -13
const PILAR_LINHA_BASE := 15
const PILAR_LARGURA := 2

## Ligue para cobrir a área nova com o teto do corredor. Desligado, ela nasce a
## céu aberto — que é como o pátio da retorta, a sala que ela continua, já é.
const COM_TETO := false
const TETO_LINHA_TOPO := -4
const TETO_LINHA_BASE := 1

## O miolo é sorteado, mas com semente fixa: rodar duas vezes dá o mesmo chão.
const SEMENTE := 82369


func _initialize() -> void:
	var raiz: Node2D = load(CENA).instantiate()
	var t: TileMapLayer = raiz.get_node("Terreno")
	var antes := t.get_used_rect()

	var rng := RandomNumberGenerator.new()
	rng.seed = SEMENTE

	_apagar_pilar_antigo(t)
	_desenhar_chao(t, rng)
	_desenhar_pilar(t)
	if COM_TETO:
		_desenhar_teto(t)

	var arquivo := FileAccess.open(SAIDA, FileAccess.WRITE)
	arquivo.store_string(Marshalls.raw_to_base64(t.tile_map_data))
	arquivo.close()

	print("rect antes:  ", antes)
	print("rect depois: ", t.get_used_rect())
	print("chão vai até x = %d ; pilar do fim em x = %d" % [
		(COLUNA_FIM + 1) * 32, (COLUNA_FIM - 3) * 32])
	print("tile_map_data novo em: ", ProjectSettings.globalize_path(SAIDA))
	raiz.free()
	quit()


## Tira o pilar de onde ele estava — ele vai ser redesenhado na ponta nova.
func _apagar_pilar_antigo(t: TileMapLayer) -> void:
	for cx in range(COLUNA_INICIO, COLUNA_FIM + 1):
		for cy in range(PILAR_LINHA_TOPO, PILAR_LINHA_BASE + 1):
			var celula := Vector2i(cx, cy)
			if t.get_cell_source_id(celula) != FONTE_PILAR:
				continue
			var arte := t.get_cell_atlas_coords(celula)
			if arte == TILE_PILAR or arte == TILE_PILAR_TOPO:
				t.erase_cell(celula)


func _desenhar_chao(t: TileMapLayer, rng: RandomNumberGenerator) -> void:
	for cx in range(COLUNA_INICIO, COLUNA_FIM + 1):
		# As duas últimas colunas usam as peças de ponta; o resto segue o ciclo.
		var da_ponta: int = COLUNA_FIM - cx
		var ax: int
		if da_ponta < SUPERFICIE_PONTA.size():
			ax = SUPERFICIE_PONTA[SUPERFICIE_PONTA.size() - 1 - da_ponta]
		else:
			ax = SUPERFICIE_CICLO[posmod(cx, SUPERFICIE_CICLO.size())]

		t.set_cell(Vector2i(cx, LINHA_SUPERFICIE), FONTE_CHAO, Vector2i(ax, 0))
		t.set_cell(Vector2i(cx, LINHA_SUPERFICIE + 1), FONTE_CHAO, Vector2i(ax, 1))

		for cy in range(LINHA_MIOLO, LINHA_FUNDO + 1):
			var solida: bool = cy > LINHA_FUNDO - LINHAS_SOLIDAS
			var tile: Vector2i = MIOLO_B if solida or rng.randf() < 0.5 else MIOLO_A
			t.set_cell(Vector2i(cx, cy), FONTE_CHAO, tile)


func _desenhar_pilar(t: TileMapLayer) -> void:
	# Encostado nas duas colunas de ponta, como ele estava no fim antigo.
	var primeira: int = COLUNA_FIM - SUPERFICIE_PONTA.size() - PILAR_LARGURA + 1
	for i in PILAR_LARGURA:
		t.set_cell(Vector2i(primeira + i, PILAR_LINHA_TOPO), FONTE_PILAR, TILE_PILAR_TOPO)
		for cy in range(PILAR_LINHA_TOPO + 1, PILAR_LINHA_BASE + 1):
			t.set_cell(Vector2i(primeira + i, cy), FONTE_PILAR, TILE_PILAR)


func _desenhar_teto(t: TileMapLayer) -> void:
	# Só é chamado com COM_TETO ligado. Copia a coluna de teto que existe logo
	# antes do trecho novo, para não inventar tile nenhum.
	var modelo := []
	var cx_modelo: int = COLUNA_INICIO - 1
	while cx_modelo > 0 and t.get_cell_source_id(Vector2i(cx_modelo, TETO_LINHA_TOPO)) == -1:
		cx_modelo -= 1
	if cx_modelo <= 0:
		push_warning("não achei teto para copiar; a área nova fica a céu aberto")
		return
	for cy in range(TETO_LINHA_TOPO, TETO_LINHA_BASE + 1):
		var celula := Vector2i(cx_modelo, cy)
		modelo.append([t.get_cell_source_id(celula), t.get_cell_atlas_coords(celula)])
	for cx in range(COLUNA_INICIO, COLUNA_FIM + 1):
		for i in modelo.size():
			t.set_cell(Vector2i(cx, TETO_LINHA_TOPO + i), modelo[i][0], modelo[i][1])
