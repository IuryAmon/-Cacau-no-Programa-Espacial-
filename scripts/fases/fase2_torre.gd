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
#   Terreno    o chão de grama da área aberta, reto, de 0 a 3200 px (o topo
#              fica em y = 512). Pinte o resto por cima dele.
#   Paredes/   dois corpos invisíveis nas pontas, para a Cacau não cair para
#              fora do mapa. Mova-os junto quando esticar o chão.
#   PortaHub   a porta de volta — é também onde ela chega. Entre esta fase e o
#              laboratório fica o corredor da torre (corredor_torre.tscn): a
#              ponta do fundo dele procura por esta "tag_aqui", e a porta
#              devolve a Cacau para aquela ponta.
#   LimitesDaCamera, SpawnPadrao, Player   o de sempre (ver fase_base.gd).
#
# Este script não liga nada: a FaseBase já cuida da câmera e de pôr a Cacau na
# porta. A lógica da fase nova entra aqui conforme ela for sendo montada.
#
# O QUE O RESTO DO JOGO AINDA ESPERA DESTA FASE
#   * a MOCHILA DE N₂ (Progresso "mochila"), que era pega aqui;
#   * a amostra de NITROGÊNIO (Progresso, célula "N") — sem ela o painel
#     CHONPS não fecha;
#   * a trilha "nitrogenio" do scripts/roteiro_objetivos.gd, que hoje só tem
#     os passos que não dependem de nenhum objeto da cena.
