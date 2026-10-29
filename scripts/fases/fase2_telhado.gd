extends FaseBase

# --- O TELHADO DA TORRE DE GASES (fase 2) ---
#
# O alto da torre, ao ar livre e de noite (o mesmo céu da rua, BG copiado de
# lá, com a serra mais baixa no horizonte). Chega-se pela PortaEscada, a
# portinha da casinha da escada, que é o par da porta do último andar da torre
# (fase2_torre_interior.tscn). Aqui estão:
#
#   CilindroDeAr     o cilindro de amostra VAZIO (componentes/
#                    cilindro_do_telhado.tscn): o E pega e ele vai para a
#                    mochila.
#   ElevadorDeCarga  o elevador de carga que desce até a rua (um ElevadorFase
#                    com direcao DESCE, o par do elevador ao pé da torre). A
#                    cabine começa PARADA aqui e fica no andar em que a Cacau a
#                    deixou (MissaoNitrogenio.posicionar_cabine): se ela desceu
#                    nele e voltou pela escada, o poço está vazio e o E só dá a
#                    "fala_elevador_la_embaixo". O poço é o mesmo da fachada da
#                    rua — os trilhos e a faixa escura, no Cenario, colunas 31
#                    a 35, logo abaixo da laje (no Terreno, ali, um vão sem
#                    tijolo) — e a cabine fica no meio dele (x = 1072). Como na
#                    rua, ela desce pela FRENTE do poço, à vista: nada do
#                    cenário passa para a frente dela (sem cenario_do_poco).
#
# Chegar aqui marca MissaoNitrogenio.subiu_a_torre. Na primeira chegada, com o
# cilindro ainda no lugar, a Cacau comenta ("fala_ao_chegar").
#
# COMO EDITAR NO EDITOR: Terreno (a laje e as muretas, tileset das fases, e o
# telhado da casinha da escada: a faixa de cornija na versão vazada, para dar
# para subir nele), Cenario (a casinha de tijolo, o poço do elevador, o poste,
# os enfeites — tileset da cidade), e os três nós acima, com a origem de cada
# um no chão. Mudando o elevador de lugar, leve o poço junto: no Cenario, os
# trilhos e a faixa escura; no Terreno, o vão nos tijolos.

## A Cacau, na primeira vez que sai da escada para o telhado.
@export var fala_ao_chegar: String = "cacau_torre_telhado"
## A Cacau, apertando o E no poço vazio: a cabine ficou lá embaixo, na rua.
@export var fala_elevador_la_embaixo: String = "cacau_elevador_la_embaixo"


func _ready() -> void:
	super._ready()
	var elevador := get_node_or_null("ElevadorDeCarga") as ElevadorFase
	MissaoNitrogenio.posicionar_cabine(elevador, true)
	if elevador:
		elevador.fala_trancada = fala_elevador_la_embaixo
	var primeira_vez := not MissaoNitrogenio.subiu_a_torre
	MissaoNitrogenio.subiu_a_torre = true
	var cilindro := get_node_or_null("CilindroDeAr")
	var cilindro_no_lugar := cilindro != null and not cilindro.is_queued_for_deletion()
	if primeira_vez and cilindro_no_lugar and not fala_ao_chegar.is_empty():
		_falar_quando_livre()


## A fala espera a Cacau terminar de sair pela porta (o controle volta) e
## nenhuma outra tela estar aberta.
func _falar_quando_livre() -> void:
	await get_tree().create_timer(0.6).timeout
	while is_inside_tree() and player != null \
			and (not player.pode_se_mover or Interacao.ocupada()):
		await get_tree().process_frame
	if is_inside_tree():
		DialogicBridge.falar(fala_ao_chegar)
