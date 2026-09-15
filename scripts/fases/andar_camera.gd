class_name AndarCamera
extends ReferenceRect

# --- ANDAR DE CÂMERA ---
#
# Um segundo LimitesDaCamera para outro NÍVEL da fase (um caminho mais acima,
# por exemplo). Enquanto ele comanda, a câmera volta a ser a do começo da fase:
# anda solta na horizontal e fica travada na vertical entre o topo e a base
# deste retângulo.
#
# QUANDO ASSUME: só quando a personagem PISA no chão com a origem dentro do
# retângulo — chegar pulando não troca a câmera no ar. QUANDO LARGA: assim que
# ela sai do retângulo (cai por um buraco, pula para fora), e aí volta a valer
# o que houver lá (ZonaCamera, TrilhoCamera ou os limites da fase).
#
# Tem prioridade sobre a ZonaCamera e o TrilhoCamera.
#
# COMO EDITAR: arraste e redimensione o retângulo (só aparece no editor).
#   - Topo e base = até onde a câmera vê em cima e embaixo, igual ao
#     LimitesDaCamera. Para repetir o enquadramento do começo da fase, deixe o
#     topo 532 px acima do chão e a base 78 px abaixo.
#   - Esquerda e direita = até onde vale o andar. A borda do lado por onde a
#     personagem chega deve ficar onde começa o chão, para a troca acontecer no
#     primeiro passo nele. Os limites laterais da câmera continuam sendo os da
#     fase.

const GRUPO := &"andar_camera"


func _ready() -> void:
	add_to_group(GRUPO)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## True se o ponto (global) está dentro do andar.
func contem(ponto_global: Vector2) -> bool:
	return get_global_rect().has_point(ponto_global)
