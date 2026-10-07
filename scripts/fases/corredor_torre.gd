extends FaseBase

# --- CORREDOR DA TORRE (entre o laboratório e a fase do nitrogênio) ---
#
# A porta da torre, no laboratório, não cai mais direto na fase 2: ela dá neste
# corredor curto, e é andando até o fundo dele que se chega à torre de
# destilação. Na volta é o mesmo caminho ao contrário.
#
#   laboratório  PortaTorre  <->  PortaLab  [ corredor ]  SaidaTorre  <->  PortaHub  fase 2
#
# O cenário é o do laboratório: a parede azul-clara e o piso de metal, os
# mesmos tiles com os mesmos ids no tileset_fases.tres (14 e 13). O teto é o
# piso de cabeça para baixo, como a viga da entrada do laboratório, e a parede
# da ponta esquerda e os pilares são a coluna de lá.
#
#   Fundo       a parede azul-clara.
#   LuzDaSaida  o clarão da luz de fora no fundo do corredor (um degradê branco
#               por cima da parede, atrás dos pilares).
#   Pilares     as três colunas da parede do fundo. É só enfeite: apague ou
#               mude de lugar à vontade.
#   Estrutura   piso, teto e a parede da ponta esquerda.
#   Colisoes/   as três camadas acima são só desenho; quem segura a Cacau são
#               Piso, Teto e ParedeEsquerda. É assim porque o industrial do
#               tileset_fases não diz que chão é (o passo ficaria mudo): o Piso
#               carrega a superfície "metal", o som de passo do laboratório. Ele
#               passa da ponta direita de propósito — a Cacau ainda anda uns
#               passos enquanto a tela apaga.
#   PortaLab    a porta por onde ela chega do laboratório (e volta para ele).
#   SaidaTorre  a ponta aberta, uma PassagemDeCena (passagem_de_cena.gd): cruzou
#               a linha, troca de cena. É também por onde ela entra andando
#               quando volta da torre.
#   LimitesDaCamera, SpawnPadrao, Player   o de sempre (ver fase_base.gd). A
#               câmera tem exatamente uma tela de altura, então só anda de lado.
#
# PARA ESTICAR OU ENCURTAR: pinte mais (ou menos) piso, teto e parede, arraste a
# SaidaTorre para a ponta nova e leve a borda direita do LimitesDaCamera para
# uns 24 px depois dela. O Piso e o Teto de Colisoes/ já sobram para a direita.
