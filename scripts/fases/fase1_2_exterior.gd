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
#   Patio/     a FORNALHA de carbonização e a ÁRVORE DA LENHA (ArvoreLenha).
#              O clímax da Fase 1 mudou de endereço: a pirólise é queima de
#              madeira e queima de madeira é coisa de área aberta, não de galpão
#              fechado. As três toras estão na copa do salgueiro (o
#              TileMapLayer Terreno/Arvore) e caem uma por arremesso do
#              bumerangue; só voltam para a copa se a queima falhar e a carga
#              virar cinza (ver arvore_lenha.gd).
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
# O CÉU (BG/) E A NOITE
#
# As mesmas quatro camadas de arte do world1 (serra, morros e as duas matas),
# só que com todas em motion_scale = 0: com a câmera parada não existe paralaxe
# para acontecer, e uma camada que não se move é desenho de fundo puro. Se um
# dia a fase crescer e a câmera voltar a andar, é só devolver os motion_scale
# (0.2, 0.4, 0.6, 0.8, de trás para a frente) que a profundidade volta junto.
#
# O pátio abre no CREPÚSCULO: a Cacau só chega aqui depois do pôr do sol do
# world1, com o céu um pouco mais escuro, sem sol e ainda sem lua. É AQUI que a
# noite cai: resolvido o painel da fornalha, com ela ainda pegando fogo, o
# tempo avança — o céu escurece, as estrelas acendem e a lua sobe de trás da serra
# (ver retorta.gd, _cair_a_noite). Depois disso o pátio — e o world1 — abrem
# sempre de noite.
#
# Quem cuida disso é o nó Atmosfera — que, como em toda fase, abre na hora da
# partida (o momento = Crepúsculo do Inspector é só o que o editor mostra) —,
# que pinta o céu (BG/Ceu), acende a lua (BG/CamadaDaLua/Lua — arraste
# para mudar o lugar em que ela PARA; de quanto ela sobe é `subida_da_lua`, na
# Atmosfera), tinge as nuvens e as camadas do fundo e escurece o mundo. O fogo
# da fornalha tem luz própria (Patio/Retorta/LuzDoFogo), e todo poste pintado
# no TileMap acende sozinho (nó PostesDeLuz). Ver docs/ILUMINACAO.md.
#
# DESENHO: o TileMapLayer do terreno está em z_index 10, ACIMA de tudo. É o que
# faz a cabine do elevador (z_index 3) e a personagem (z_index 2) sumirem
# dentro do poço em vez de deslizarem por cima do chão na hora da viagem.
#
# A ÁRVORE TEM DUAS PROFUNDIDADES: a personagem passa ENTRE elas.
#   Terreno/Arvore        o salgueiro inteiro (Weeping Willow2.png), fora da
#                         regra do Terreno: z_as_relative desligado, z_index 0
#                         — ATRÁS da personagem (2).
#   Terreno/Arvore/Frente os galhos que caem na frente (FRENTEARVORE1.png, o
#                         mesmo desenho com o tronco e o fundo da copa
#                         apagados), em z_index 10 — NA FRENTE dela.
# A Frente é filha da Arvore e está no mesmo ponto em que os tiles dela
# começam (a célula 11,4 × 16 px = 176,64): herda a vergada e o clarão da
# pancada do bumerangue sem código nenhum a mais. Se repintar a árvore em
# outro lugar do TileMapLayer, mova a Frente junto.
