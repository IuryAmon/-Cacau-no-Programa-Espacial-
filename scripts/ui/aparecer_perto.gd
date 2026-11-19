class_name AparecerPerto
extends RefCounted

# --- AS FRASES DO CENÁRIO QUE APARECEM COM A CACAU POR PERTO ---
#
# As frases de tutorial escritas no world1 — "Pressione ... para
# movimentar-se" (botao_moviment.gd), "... para pular" (botao_pulo.gd) e
# "... para interagir" (interacao_samambaia.gd) — só aparecem com a Cacau
# por perto: chegando, surgem num fade in; indo embora, somem num fade out.
#
# Aqui ficam as contas que as três dividem. Cada frase tem os números dela no
# Inspetor (grupo "Aparecer"), com estes de padrão.

## A Cacau a menos disto do meio da frase, na horizontal (px do mundo), e a
## frase aparece.
const DISTANCIA := 300.0
## Ela some só depois de a Cacau se afastar um pouco mais que a DISTANCIA:
## parada bem no limite, a frase não fica piscando.
const FOLGA := 40.0
## Mais longe que isto na vertical (outro andar do mapa), não aparece.
const ALTURA := 280.0
## Duração do fade in e do fade out (segundos).
const DURACAO := 0.45


## A Cacau está perto deste ponto do mundo? "ja_a_vista" soma a folga: quem já
## apareceu só some um pouco mais longe.
static func cacau_perto(arvore: SceneTree, ponto: Vector2, distancia: float, altura: float,
		folga: float, ja_a_vista: bool) -> bool:
	var cacau := arvore.get_first_node_in_group("player") as Node2D
	if cacau == null:
		return false
	var d := cacau.global_position - ponto
	return absf(d.x) < distancia + (folga if ja_a_vista else 0.0) and absf(d.y) < altura


## O alfa do quadro seguinte, andando para 1 (mostrar) ou 0 no ritmo do fade.
static func alfa(atual: float, mostrar: bool, delta: float, duracao: float) -> float:
	return move_toward(atual, 1.0 if mostrar else 0.0, delta / maxf(duracao, 0.01))
