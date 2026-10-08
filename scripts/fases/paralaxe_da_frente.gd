@tool
class_name ParalaxeDaFrente
extends Node2D
## Uma camada de cenário que passa NA FRENTE de tudo, mais perto da câmera.
##
## É a paralaxe ao contrário da do fundo: o que é filho deste nó aparece maior
## e corre mais depressa que o cenário, por cima da personagem, em silhueta —
## as colunas escuras que cruzam a tela nos metroidvanias.
##
## [b]Como funciona.[/b] A camada é um plano mais perto da câmera. No jogo, tudo
## o que está aqui dentro é ampliado [member aproximacao] vezes a partir do
## CENTRO DA TELA. O tamanho e a velocidade saem do mesmo número — com 1,6 o
## pilar fica 1,6 vez mais largo e cruza a tela 1,6 vez mais rápido que a
## parede —, que é o que a perspectiva faz de verdade com o que está mais perto.
##
## [b]Onde pintar.[/b] No editor a camada aparece no tamanho normal, no lugar em
## que foi pintada, e é nesse x que ela cruza o MEIO da tela: um pilar pintado
## em x = 800 passa na frente da Cacau quando a câmera está em x = 800. Longe do
## meio da tela ele se afasta do lugar pintado (é a paralaxe: quanto mais longe
## do centro, mais ele "anda"). Para uma peça do cenário ganhar uma gêmea na
## frente, é só copiar os tiles dela e colar aqui, no mesmo lugar: a gêmea passa
## por cima da original quando as duas estão no meio da tela.
##
## [b]A altura.[/b] Na vertical a camada cresce do mesmo jeito, a partir do meio
## da tela — e uma peça da altura da parede, ampliada 1,6 vez, fica com as
## pontas para fora do quadro. [member aproximacao_vertical] dá à altura um
## número próprio: com ele a peça inteira cabe na tela (o capitel no alto, a
## base embaixo), e a largura e a velocidade continuam saindo da
## [member aproximacao].
##
## [b]A cor.[/b] [member cor] multiplica a arte dos filhos: preto dá a silhueta
## chapada. No editor a camada aparece meio transparente
## ([member opacidade_no_editor]), para não esconder o cenário que está atrás;
## no jogo é opaca. Nada disso é gravado na cena nem nos filhos: a tinta vai
## direto para o render.
##
## [b]Na frente de quê.[/b] Qualquer coisa serve de filho (TileMapLayer,
## Sprite2D...). Quem põe a camada por cima da personagem e do cenário é o
## [code]z_index[/code] DESTE nó, alto e com "Z As Relative" desligado. O HUD,
## as falas e a cortina da troca de cena continuam por cima: são outras camadas.
##
## Para usar em outra fase: um Node2D com este script (z_index 100, relativo
## desligado) e, dentro dele, o que for passar na frente. Num TileMapLayer,
## desligue a colisão e a navegação: a camada muda de lugar a cada quadro.

## Quantas vezes esta camada está "mais perto" que o cenário: é o quanto ela
## cresce e o quanto corre mais que ele. 1 = no mesmo plano do cenário (sem
## efeito); 2 = o dobro do tamanho e da velocidade.
@export_range(1.0, 4.0, 0.05) var aproximacao := 1.6
## Quanto a camada cresce NA VERTICAL. 0 (o normal) = igual à
## [member aproximacao]. Um número próprio serve para a peça caber na altura da
## tela: altura que a tela mostra ÷ altura da peça pintada (e um tico a mais,
## para não sobrar fresta).
@export_range(0.0, 4.0, 0.01) var aproximacao_vertical := 0.0
## Tinta da camada (multiplica a arte dos filhos). Preto = silhueta.
@export var cor := Color.BLACK
## Só no editor: quanto da camada aparece, de 0 (invisível) a 1 (como no jogo).
## Meio transparente, dá para pintar e ainda ver o cenário atrás dela.
@export_range(0.0, 1.0, 0.05) var opacidade_no_editor := 0.5

## Onde o nó foi deixado na cena (normalmente a origem, sem escala): a
## ampliação é aplicada por cima disto.
var _base := Transform2D.IDENTITY
var _tinta_enviada := Color(-1, -1, -1, -1)
## O `modulate` do nó na última vez em que a tinta foi enviada: se ele mudou, o
## nó mandou a cor dele para o render e a tinta precisa ir de novo.
var _modulate_visto := Color(-1, -1, -1, -1)
var _ate_reforcar := 0.0


func _enter_tree() -> void:
	_pintar(true)
	if not Engine.is_editor_hint() and not RenderingServer.frame_pre_draw.is_connected(_ao_desenhar):
		# Depois de tudo o que mexe na câmera neste quadro, logo antes de
		# desenhar: a camada nunca fica um quadro atrás do cenário.
		RenderingServer.frame_pre_draw.connect(_ao_desenhar)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_ao_desenhar):
		RenderingServer.frame_pre_draw.disconnect(_ao_desenhar)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	set_process(false)
	_base = global_transform
	encaixar()


func _process(delta: float) -> void:
	# Só roda no editor. A tinta é conferida a cada quadro (mexer no "modulate"
	# do nó pelo Inspector, ou desfazer, passa por cima dela) e reforçada de vez
	# em quando, para o caso de o editor ter refeito o desenho por conta própria.
	_ate_reforcar -= delta
	if _ate_reforcar <= 0.0:
		_ate_reforcar = 0.5
		_pintar(true)
	else:
		_pintar()


func _ao_desenhar() -> void:
	_pintar()
	encaixar()


## O ponto do mundo que está no meio da tela agora.
func centro_da_tela() -> Vector2:
	return get_canvas_transform().affine_inverse() * (get_viewport_rect().size * 0.5)


## O quanto a camada cresce em cada eixo.
func ampliacao() -> Vector2:
	return Vector2(aproximacao, aproximacao_vertical if aproximacao_vertical > 0.0 else aproximacao)


## Amplia a camada a partir do centro da tela: um ponto p da cena passa a ser
## desenhado em centro + (p - centro) * ampliacao. Roda sozinho a cada quadro
## desenhado; só precisa ser chamado na mão por quem não desenha (um teste sem
## janela).
func encaixar() -> void:
	if not is_inside_tree() or Engine.is_editor_hint():
		return
	var s := ampliacao()
	var centro := centro_da_tela()
	global_transform = Transform2D(Vector2(s.x, 0.0), Vector2(0.0, s.y), centro * (Vector2.ONE - s)) * _base


## A tinta vai direto para o render, por cima do `modulate` do nó (que continua
## valendo, multiplicado): o que está salvo na cena é sempre o que você deixou.
func _pintar(forcar: bool = false) -> void:
	if not is_inside_tree():
		return
	var m := modulate
	var alfa := m.a * cor.a
	if Engine.is_editor_hint():
		alfa *= opacidade_no_editor
	var tinta := Color(m.r * cor.r, m.g * cor.g, m.b * cor.b, alfa)
	if not forcar and m == _modulate_visto and tinta.is_equal_approx(_tinta_enviada):
		return
	_modulate_visto = m
	_tinta_enviada = tinta
	RenderingServer.canvas_item_set_modulate(get_canvas_item(), tinta)
