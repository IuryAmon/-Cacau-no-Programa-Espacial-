@tool
class_name HitboxBumerangue
extends Area2D

# --- HITBOX DE BUMERANGUE (PEÇA AVULSA) ---
#
# O bumerangue só enxerga Area2D do grupo "alvo_bumerangue" com o método
# atingir_bumerangue() (ver bumerangue.gd). O AlvoBumerangue É essa área — mas
# nem todo objeto que apanha do bumerangue pode SER uma área: a TorretaLaser,
# por exemplo, é um Node2D com base, cabeça giratória e boca, e o que apanha
# ali é a cabeça, não a raiz do objeto.
#
# Esta é a solução: uma área solta, filha de quem quer que seja, que só faz
# UMA coisa — receber o acerto e avisar quem manda pelo sinal "atingida". Ela
# não decide nada, não tem estado e não sabe o que vai acontecer depois. Quem
# a pendura é que liga o sinal no próprio estrago.
#
# COMO USAR NO EDITOR:
#   1. filho do nó que apanha (pode estar dentro de um pivô que gira: a área
#      acompanha a peça, que é o ponto de pendurar aqui e não na raiz);
#   2. um CollisionShape2D dentro dela, com a forma por cima da arte;
#   3. o grupo "alvo_bumerangue" ligado no painel Node > Grupos — sem ele o
#      bumerangue passa batido;
#   4. no script do dono: `hitbox.atingida.connect(...)`.
#
# A camada de física é a 1, a mesma dos outros alvos: o bumerangue não filtra
# por camada, mas o resto do projeto vive nela e sair dali só criaria surpresa.

## O bumerangue passou por aqui. Quem pendurou a área decide o que isso
## significa — estragar, abrir, acender, contar ponto.
signal atingida


## Chamado pelo bumerangue, na ida E na volta (ele atravessa alvos de
## propósito, para o puzzle de dois alvos num arremesso só).
func atingir_bumerangue() -> void:
	atingida.emit()
