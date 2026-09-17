extends FaseBase

# --- FASE 1.2: O PÁTIO DA OFICINA (a parte de fora do laboratório) ---
#
# O andar de cima da Fase 1, do outro lado do elevador de carga. É uma TELA SÓ:
# a câmera não anda, como na casa do Yoshi — a pessoa vê o pátio inteiro de uma
# vez e o que acontece nele acontece todo dentro do quadro.
#
# O QUE MORA AQUI
#   Elevador   a cabine que liga o pátio à oficina lá embaixo (ver
#              elevador_fase.gd). É por ela que se chega e é por ela que se
#              volta: entre, aperte E e ela desce.
#   Patio/     a FORNALHA de carbonização e as três toras de lenha. O clímax da
#              Fase 1 mudou de endereço: a pirólise é queima de madeira e queima
#              de madeira é coisa de área aberta, não de galpão fechado.
#
# POR QUE A CÂMERA NÃO SE MEXE
#
# Não há script nenhum travando ela: o truque é o nó "LimitesDaCamera", que
# nesta fase tem EXATAMENTE o tamanho de uma tela (1067 x 600 — a janela de
# 1600x900 dividida pelo zoom 1.5 da câmera do player). Como a Camera2D nunca
# pode mostrar nada fora dos limites e o retângulo tem o tamanho de um quadro,
# só existe um enquadramento possível e ela fica parada nele.
#
#   PARA AUMENTAR O PÁTIO: estique o LimitesDaCamera. No instante em que ele
#   ficar maior que 1067x600 a câmera volta a acompanhar a personagem — é a
#   mesma regra de todas as outras fases, sem exceção nenhuma para esta.
#
# AS PAREDES DE FORA DO QUADRO (Paredes/)
#
# Dois StaticBody2D invisíveis, um em cada beirada da tela, para a personagem
# não sair andando para fora do pátio (a câmera não a seguiria e ela sumiria).
# Ficam FORA do quadro de propósito: mova-os se esticar a fase.
#
# O CÉU (BG/)
#
# O mesmo céu de camadas do world1 (as cinco "GandalfHardcore Background
# layers" com o shader de neblina aérea), só que com todas as camadas em
# motion_scale = 0: com a câmera parada não existe paralaxe para acontecer, e
# uma camada que não se move é desenho de fundo puro. Se um dia a fase crescer
# e a câmera voltar a andar, é só devolver os motion_scale (0.2, 0.4, 0.6, 0.8,
# de trás para a frente) que a profundidade volta junto.
#
# DESENHO: o TileMapLayer do terreno está em z_index 10, ACIMA de tudo. É o que
# faz a cabine do elevador (z_index 3) e a personagem (z_index 2) sumirem
# dentro do poço em vez de deslizarem por cima do chão na hora da viagem.
