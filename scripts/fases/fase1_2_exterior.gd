extends FaseBase

# --- FASE 1.2: O PÁTIO DA OFICINA (a parte de fora do laboratório) ---
#
# O andar de cima da Fase 1: o elevador de carga da oficina sobe até o corredor
# do pátio (corredor_patio.tscn) e do fundo dele se sai para cá, a céu aberto.
# É uma TELA SÓ: a câmera não anda, como na casa do Yoshi — a pessoa vê o pátio
# inteiro de uma vez e o que acontece nele acontece todo dentro do quadro.
#
#   oficina  Entrada/ElevadorPatio  <->  Elevador  [ corredor ]  SaidaPatio  <->  PassagemCorredor  pátio
#
# O QUE MORA AQUI
#   PassagemCorredor   o pátio NÃO TEM PORTA nem elevador. Esta é a ponta
#              esquerda dele, uma PassagemDeCena (passagem_de_cena.gd), o par
#              da ponta do fundo do corredor do pátio:
#                * NA CHEGADA a Cacau vem de fora do quadro e entra andando
#                  pela esquerda, na grama, até uns 150 px para dentro, e o
#                  controle volta;
#                * NA VOLTA basta andar para a esquerda: cruzou a linha (x = 24,
#                  logo depois da beirada da tela), a tela apaga com ela ainda
#                  correndo e a cena troca para o fundo do corredor;
#                * COM A FORNALHA ACESA ela não sai: a mesma linha vira parede,
#                  a Cacau para na beirada e diz que precisa terminar o carvão
#                  primeiro. Quem segura a saída é a própria fornalha (ver
#                  segura_a_saida em retorta.gd); a brasa apagou, a linha volta
#                  a ser passagem.
#   Terreno    o chão: GRAMA de ponta a ponta. Ela começa antes da beirada
#              esquerda da tela, em x = -448 — é nesse trecho de fora do quadro
#              que a Cacau nasce e some. (Era aqui que ficava o prédio do
#              elevador, com piso de pedra, marquise e porta de metal: saiu
#              tudo quando o elevador passou a chegar no corredor.)
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
# nesta fase tem EXATAMENTE o tamanho de uma tela: 1185 x 667 — a janela de
# 1600x900 dividida pelo zoom 1,35 da câmera, o mesmo do world1 (é o
# `zoom_da_camera` do nó Player desta cena; sem ele valeria o 1,5 do player).
# Como a Camera2D nunca pode mostrar nada fora dos limites e o retângulo tem o
# tamanho de um quadro, só existe um enquadramento possível e ela fica parada
# nele.
#
#   PARA AUMENTAR O PÁTIO: estique o LimitesDaCamera. No instante em que ele
#   ficar maior que 1185x667 a câmera volta a acompanhar a personagem — é a
#   mesma regra de todas as outras fases, sem exceção nenhuma para esta.
#
#   PARA MUDAR O ZOOM: troque o `zoom_da_camera` do Player e refaça o
#   retângulo (1600 ÷ zoom por 900 ÷ zoom). A base dele fica em y = 580, para a
#   grama continuar na mesma faixa de baixo da tela; quem muda é a direita e o
#   TOPO — e, mudando o topo, o fundo tem de acompanhar (ver O CÉU, abaixo).
#
# AS PAREDES DE FORA DO QUADRO (Paredes/)
#
# Dois StaticBody2D invisíveis, para a personagem não cair para fora do mapa.
# O da direita fica logo depois da beirada da tela (a câmera não a seguiria e
# ela sumiria). O da esquerda fica recuado (x = -420), para lá do trecho em que
# ela chega e sai andando: quem segura a Cacau naquela ponta é a própria
# passagem, que troca de cena quando ela cruza a linha. Mova-os se esticar a
# fase.
#
# O CÉU (BG/) E A NOITE
#
# As mesmas quatro camadas de arte do world1 (serra, morros e as duas matas),
# só que com todas em motion_scale = 0: com a câmera parada não existe paralaxe
# para acontecer, e uma camada que não se move é desenho de fundo puro. Se um
# dia a fase crescer e a câmera voltar a andar, é só devolver os motion_scale
# (0.2, 0.4, 0.6, 0.8, de trás para a frente) que a profundidade volta junto.
#
# Camada em motion_scale = 0 fica presa ao CANTO DE CIMA DA TELA, não ao chão.
# Por isso TODAS as camadas do BG (céu, lua e nuvens também) têm
# motion_offset.y = 67: é o quanto o topo do LimitesDaCamera subiu quando o
# zoom passou de 1,5 para 1,35 (de -20 para -87). Sem isso a serra e a mata
# ficariam 67 px soltas acima da grama. Se o topo mudar de novo, a conta é
# motion_offset.y = -20 - topo. O editor não mostra o motion_offset: nele o
# fundo aparece 20 px abaixo de onde o jogo desenha, como sempre apareceu.
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
# DESENHO: o TileMapLayer do terreno está em z_index 10, ACIMA de tudo — a
# personagem (z_index 2) pisa por trás da grama. (Era o que escondia a cabine
# do elevador dentro do poço, quando ele chegava aqui; no corredor do pátio
# quem faz esse papel é a camada Estrutura de lá.)
#
# A ÁRVORE TEM DUAS PROFUNDIDADES: a personagem passa ENTRE elas.
#   Terreno/Arvore        o salgueiro inteiro (Weeping Willow2.png), fora da
#                         regra do Terreno: z_as_relative desligado, z_index 0
#                         — ATRÁS da personagem (2).
#   Terreno/Arvore/Frente os galhos que caem na frente (FRENTEARVORE1.png, o
#                         mesmo desenho com o tronco e o fundo da copa
#                         apagados), em z_index 10 — NA FRENTE dela.
# A Frente é filha da Arvore e está no mesmo ponto em que os tiles dela
# começam (a célula 7,4 × 16 px = 112,64): herda a vergada e o clarão da
# pancada do bumerangue sem código nenhum a mais. Se repintar a árvore em
# outro lugar do TileMapLayer, mova junto a Frente e o nó Patio/ArvoreLenha
# (o pé do tronco: é dele que saem a copa, o tronco e os galhos da lenha).
