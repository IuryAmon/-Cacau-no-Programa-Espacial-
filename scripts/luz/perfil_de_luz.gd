@tool
class_name PerfilDeLuz
extends Resource
## Um horário do dia, do céu ao chão.
##
## Tudo o que muda de cor quando a hora muda está aqui, num arquivo só: o
## degradê do céu, o quanto de estrela aparece, a luz que bate no parallax, a
## cor do ar que come as camadas distantes, o ambiente do mundo, as nuvens e a
## força dos postes. A [Atmosfera] da cena lê um perfil destes (ou a mistura de
## dois, no meio de uma transição) e distribui para quem desenha.
##
## Os perfis do jogo moram em [code]res://assets/luz/[/code] — abra um deles no
## Inspector e mexa nas cores com a fase aberta: a prévia acompanha.

@export_group("Céu")
## O alto do céu.
@export var ceu_zenite := Color(0.36, 0.42, 0.62)
@export var ceu_alto := Color(0.66, 0.56, 0.6)
@export var ceu_baixo := Color(0.96, 0.72, 0.5)
## A faixa colada na serra.
@export var ceu_horizonte := Color(1.0, 0.88, 0.64)
## Quanto do céu estrelado aparece. Sobe aos poucos: as estrelas mais fortes
## acendem primeiro.
@export_range(0.0, 1.0, 0.01) var estrelas := 0.0
## O clarão que o astro abre no céu em volta dele (as faixas do degradê
## embarrigam para cima perto do sol ou da lua).
@export_range(0.0, 1.0, 0.01) var clarao := 0.35

@export_group("Astros")
## Presença do sol: 1 aceso, 0 fora do céu.
@export_range(0.0, 1.0, 0.01) var sol := 1.0
## Presença da lua.
@export_range(0.0, 1.0, 0.01) var lua := 0.0
## Tinta por cima das cores do sol — é o que avermelha o disco quando ele desce.
@export var tinta_do_sol := Color(1, 1, 1)

@export_group("Fundo (parallax)")
## Luz que bate nas camadas do fundo. Multiplica a arte.
@export var luz_do_fundo := Color(0.95, 0.84, 0.74)
## Cor do ar: é nela que as camadas distantes se desmancham.
@export var cor_do_ar := Color(0.98, 0.82, 0.62)
## Quanto o ar come as camadas (multiplica a profundidade de cada uma).
@export_range(0.0, 1.0, 0.01) var neblina := 0.5

@export_group("Mundo")
## Luz ambiente do mundo (chão, personagens, objetos). Multiplica tudo que não
## tem luz própria.
@export var ambiente := Color(0.92, 0.86, 0.82)

@export_group("Nuvens")
## Cor do lado da nuvem que pega luz.
@export var nuvem_luz := Color(1.0, 0.9, 0.78)
## Cor do lado de baixo, na sombra.
@export var nuvem_sombra := Color(0.86, 0.62, 0.6)
@export_range(0.0, 1.0, 0.01) var nuvem_opacidade := 0.9

@export_group("Luzes artificiais")
## Força dos postes: 0 apagados, 1 com tudo.
@export_range(0.0, 1.0, 0.01) var postes := 0.4


## A mistura de dois perfis, [param t] de 0 ([param a]) a 1 ([param b]).
static func misturar(a: PerfilDeLuz, b: PerfilDeLuz, t: float) -> PerfilDeLuz:
	if a == null:
		return b
	if b == null:
		return a
	var k := clampf(t, 0.0, 1.0)
	if k <= 0.0:
		return a
	if k >= 1.0:
		return b
	var p := PerfilDeLuz.new()
	p.ceu_zenite = a.ceu_zenite.lerp(b.ceu_zenite, k)
	p.ceu_alto = a.ceu_alto.lerp(b.ceu_alto, k)
	p.ceu_baixo = a.ceu_baixo.lerp(b.ceu_baixo, k)
	p.ceu_horizonte = a.ceu_horizonte.lerp(b.ceu_horizonte, k)
	p.estrelas = lerpf(a.estrelas, b.estrelas, k)
	p.clarao = lerpf(a.clarao, b.clarao, k)
	p.sol = lerpf(a.sol, b.sol, k)
	p.lua = lerpf(a.lua, b.lua, k)
	p.tinta_do_sol = a.tinta_do_sol.lerp(b.tinta_do_sol, k)
	p.luz_do_fundo = a.luz_do_fundo.lerp(b.luz_do_fundo, k)
	p.cor_do_ar = a.cor_do_ar.lerp(b.cor_do_ar, k)
	p.neblina = lerpf(a.neblina, b.neblina, k)
	p.ambiente = a.ambiente.lerp(b.ambiente, k)
	p.nuvem_luz = a.nuvem_luz.lerp(b.nuvem_luz, k)
	p.nuvem_sombra = a.nuvem_sombra.lerp(b.nuvem_sombra, k)
	p.nuvem_opacidade = lerpf(a.nuvem_opacidade, b.nuvem_opacidade, k)
	p.postes = lerpf(a.postes, b.postes, k)
	return p
