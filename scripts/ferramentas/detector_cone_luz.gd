class_name DetectorConeLuz
extends Node2D

# --- DETECTOR DE CONE DE LUZ (componente reutilizável) ---
#
# Responde UMA pergunta: "este ponto está dentro do cone?" — em três testes,
# do mais barato ao mais caro:
#   (a) distância dentro do alcance;
#   (b) ângulo em relação ao vetor de mira dentro da METADE da abertura;
#   (c) linha de visão livre via raycast — parede entre a origem e o ponto
#       significa NÃO iluminado, mesmo dentro do alcance e do ângulo.
#
# Ele não conhece lanterna nem inimigo de propósito: a Lanterna é só o
# primeiro dono. Interruptores fotossensíveis, insetos atraídos pela luz etc.
# usam o mesmo nó — basta posicionar, apontar "direcao" e perguntar.
#
# O CONTRATO com o visual: quem desenha o feixe desenha com ESTES mesmos
# alcance e abertura (ver lanterna.gd, que gera a textura a partir daqui) —
# a jogadora nunca pode ver luz onde o jogo considera escuro, nem o contrário.

## Alcance do cone em px, medido a partir deste nó.
@export var alcance: float = 320.0
## Abertura TOTAL do cone em graus (cada lado usa a metade).
@export var abertura_graus: float = 45.0
## Desligado, nada está iluminado (lanterna apagada, bateria zerada).
@export var ativo: bool = true
## Camadas que BLOQUEIAM a luz. O projeto inteiro usa a camada 1 (padrão),
## então paredes de TileMap e caixas já contam como obstáculo.
@export_flags_2d_physics var mascara_paredes: int = 1

## Vetor de mira (normalizado no set). Quem aponta a luz escreve aqui.
var direcao: Vector2 = Vector2.RIGHT:
	set(v):
		if v.length_squared() > 0.0001:
			direcao = v.normalized()

## Corpos que o raycast ignora — no mínimo quem CARREGA a luz, senão o corpo
## do player "faz sombra" no primeiro pixel do próprio feixe.
var excluir: Array[RID] = []


## O ponto está iluminado? (distância -> ângulo -> linha de visão)
func is_point_lit(ponto_global: Vector2) -> bool:
	if not ativo or not is_inside_tree():
		return false

	var origem := global_position
	var vetor := ponto_global - origem
	var dist := vetor.length()
	if dist > alcance:
		return false
	# Colado na origem conta como iluminado (é o "bulbo" da lanterna; sem isso
	# o ângulo vira ruído numérico com o vetor quase nulo).
	if dist < 2.0:
		return true
	if absf(direcao.angle_to(vetor)) > deg_to_rad(abertura_graus) * 0.5:
		return false

	var consulta := PhysicsRayQueryParameters2D.create(
		origem, ponto_global, mascara_paredes, excluir)
	return get_world_2d().direct_space_state.intersect_ray(consulta).is_empty()


## O corpo está iluminado? Testa o CENTRO dele (a origem do nó — a Sentinela
## tem a colisão centrada na origem justamente por isso).
## TODO: se no playtest "metade do corpo na luz" precisar contar como
## iluminado, amostrar também topo e base do corpo em vez de só o centro.
func is_body_lit(corpo: Node2D) -> bool:
	if corpo == null or not is_instance_valid(corpo):
		return false
	return is_point_lit(corpo.global_position)
