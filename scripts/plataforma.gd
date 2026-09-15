extends Path2D

@onready var path_follow = $PathFollow2D
@onready var som_ativacao = $platform/SomAtivacao

@export var duracao_trajeto : float = 5.0   # tempo de uma ponta à outra
@export var pausa_extremidade : float = 2.0 # tempo parada em cada ponta

## Em qual ponta do caminho ela fica esperando antes de ser acionada.
##
## Desligado (padrão): fica no COMEÇO da curva, que é como a plataforma do
## world1 sempre funcionou — nada muda lá.
##
## Ligado: fica no FIM da curva e o acionamento a traz de volta ao começo. É
## para a plataforma que espera no chão e sobe quando ligam: a curva precisa
## continuar desenhada de cima para baixo (o PathFollow2D gira junto com a
## tangente e o RemoteTransform2D compensa esse giro; com a curva invertida a
## plataforma viraria de cabeça para baixo e a colisão de mão única deixaria o
## jogador atravessar o piso dela).
@export var comecar_no_fim : bool = false

var ativa : bool = false  # só começa a se mover depois de alguém acionar


func _ready() -> void:
	path_follow.progress_ratio = 1.0 if comecar_no_fim else 0.0


# Chamado por quem libera a plataforma: o cientista, no world1, e o terminal
# do guincho, na fase 1.
func acionar() -> void:
	if ativa:
		return  # evita acionar mais de uma vez
	ativa = true
	# Sempre parte na direção da OUTRA ponta, seja ela qual for.
	_mover_para(0.0 if comecar_no_fim else 1.0)


# Move o progress_ratio até o destino (0.0 ou 1.0) e encadeia o ciclo
func _mover_para(destino: float) -> void:
	som_ativacao.play()

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)   # curva suave
	tween.set_ease(Tween.EASE_IN_OUT)   # desacelera nas duas pontas
	tween.tween_property(path_follow, "progress_ratio", destino, duracao_trajeto)

	# Pausa na extremidade após chegar
	tween.tween_interval(pausa_extremidade)

	# Quando terminar, vai para a outra ponta (loop)
	tween.tween_callback(_alternar.bind(destino))


func _alternar(destino_atual: float) -> void:
	# Se acabou de chegar no topo (1.0), próximo destino é a base (0.0), e vice-versa
	var proximo = 0.0 if destino_atual == 1.0 else 1.0
	_mover_para(proximo)
