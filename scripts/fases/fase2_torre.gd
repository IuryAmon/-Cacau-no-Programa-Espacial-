extends FaseBase

# --- FASE 2: NITROGÊNIO (em branco, esperando ser construída) ---
#
# A fase do nitrogênio vai ser refeita do zero, ao ar livre. A cena está só
# com o palco:
#
#   BG/        o céu de camadas da área aberta (o mesmo do pátio da fase 1.2 e
#              do world1). O céu e a lua ficam presos na tela; a serra, os
#              morros e as matas andam mais devagar que a câmera, só na
#              horizontal (motion_scale 0.2 / 0.4 / 0.6 / 0.8), e se repetem
#              sozinhos de 4096 em 4096 px.
#   Atmosfera  a hora da fase: NOITE, com a lua (BG/CamadaDaLua/Lua — arraste
#              para mudar de lugar), céu estrelado e nuvens. É ela que escurece
#              o mundo e tinge o fundo. Ver docs/ILUMINACAO.md.
#   PostesDeLuz  acende sozinho todo poste pintado no TileMap.
#   Terreno    o chão de grama da área aberta, reto (o topo fica em y = 512).
#              Ele começa ANTES da beirada esquerda da tela, em x = -448: é
#              nesse trecho de fora do quadro que a Cacau nasce e some (ver
#              PassagemCorredor). Pinte o resto por cima dele.
#   Paredes/   dois corpos invisíveis, para a Cacau não cair para fora do mapa.
#              O da esquerda fica recuado (x = -420), para lá do trecho em que
#              ela chega e sai andando. Mova-os junto quando esticar o chão.
#   PassagemCorredor   a fase NÃO TEM PORTA. Esta é a ponta esquerda dela, uma
#              PassagemDeCena (passagem_de_cena.gd), o par da ponta do fundo do
#              corredor da torre (corredor_torre.tscn):
#                * NA CHEGADA a Cacau vem de fora do quadro e entra andando
#                  pela esquerda, até uns 150 px para dentro, e o controle
#                  volta;
#                * NA VOLTA basta andar para a esquerda: cruzou a linha (x = 24,
#                  logo depois da beirada da câmera), a tela apaga com ela
#                  ainda correndo e a cena troca para o fundo do corredor.
#              "sentido" = -1 diz que o lado de fora é o esquerdo. O chão tem
#              de continuar uns 300 px para fora da linha, sem parede no meio.
#   LimitesDaCamera, SpawnPadrao, Player   o de sempre (ver fase_base.gd). O
#              SpawnPadrao só vale quando a cena é aberta direto, sem vir do
#              corredor.
#
# Este script não liga nada: a FaseBase já cuida da câmera, e a passagem de pôr
# a Cacau no lugar. A lógica da fase nova entra aqui conforme ela for sendo
# montada.
#
# O QUE O RESTO DO JOGO AINDA ESPERA DESTA FASE
#   * a MOCHILA DE N₂ (Progresso "mochila"), que era pega aqui;
#   * a amostra de NITROGÊNIO (Progresso, célula "N") — sem ela o painel
#     CHONPS não fecha;
#   * a trilha "nitrogenio" do scripts/roteiro_objetivos.gd, que hoje só tem
#     os passos que não dependem de nenhum objeto da cena.
