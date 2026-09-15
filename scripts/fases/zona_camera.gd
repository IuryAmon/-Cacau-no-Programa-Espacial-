class_name ZonaCamera
extends Polygon2D

# --- ZONA DE CÂMERA VERTICAL ---
#
# Polígono desenhado no editor. Enquanto a personagem estiver DENTRO dele, a
# câmera trava na horizontal (o centro fica em "centro_x") e passa a andar só
# na vertical — para corredores e poços de escalada.
#
# COMO EDITAR: selecione o nó e arraste os vértices do polígono no editor. O
# que vale é a ORIGEM da personagem (o meio da cápsula) estar dentro dele. A
# borda por onde ela entra deve ficar onde a câmera já estava centrada nela
# (ex.: borda em x = 7840 e centro_x = 7840): assim a troca não dá tranco.
#
# COMO A CÂMERA SOBE: com "subir_so_ao_pousar" ligado, a altura só muda quando a
# personagem pisa numa plataforma — os pulos não balançam a tela. Se ela subir
# ou cair demais no ar, a "margem_personagem" puxa a câmera antes de ela sair
# do quadro.
#
# Tem prioridade sobre o TrilhoCamera. O polígono só aparece no editor.

const GRUPO := &"zona_camera"

## X (global) em que o centro da câmera fica travado dentro da zona.
@export var centro_x: float = 0.0

## Onde fica o centro da câmera em relação à personagem, na vertical.
## Negativo = acima dela. -190 repete o enquadramento do resto da fase: a
## personagem no terço de baixo da tela, com o caminho de cima à vista.
@export var altura_do_olhar: float = -190.0

## Ligado: a câmera só muda de altura quando a personagem pousa.
## Desligado: acompanha a personagem o tempo todo, inclusive nos pulos.
@export var subir_so_ao_pousar: bool = true

## Até onde a borda de cima da tela pode subir (y global). -INF = sem limite.
@export var limite_topo: float = -INF

## Até onde a borda de baixo da tela pode descer (y global). INF = sem limite.
@export var limite_base: float = INF

## Distância mínima entre a personagem e a borda de cima ou de baixo da tela.
@export var margem_personagem: float = 110.0

## Distância mínima entre a personagem e as bordas dos lados: se ela chegar
## mais perto que isso, a câmera sai do centro_x para acompanhar. 0 = o x fica
## travado de verdade (bom quando a tela já cobre o corredor inteiro).
@export var margem_lateral: float = 110.0

## A zona só ASSUME se a personagem entrar no polígono acima desta linha (y
## global menor que isto); depois de assumir, vale até ela sair do polígono.
## Serve para corredores que só se DESCEM: quem passa lá embaixo, pelo chão,
## não trava a câmera. INF = assume entrando por qualquer lado.
@export var assumir_so_acima_de_y: float = INF

var _poligono_global := PackedVector2Array()


func _ready() -> void:
	add_to_group(GRUPO)
	visible = false
	var xf := global_transform
	for p in polygon:
		_poligono_global.append(xf * p)
	if _poligono_global.size() < 3:
		push_warning("%s: a zona precisa de pelo menos 3 vértices." % name)


## True se o ponto (global) está dentro da zona.
func contem(ponto_global: Vector2) -> bool:
	return _poligono_global.size() >= 3 \
		and Geometry2D.is_point_in_polygon(ponto_global, _poligono_global)


## True se, estando fora, a zona pode assumir com a personagem neste ponto.
func pode_assumir(ponto_global: Vector2) -> bool:
	return contem(ponto_global) and ponto_global.y <= assumir_so_acima_de_y
