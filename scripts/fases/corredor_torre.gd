extends FaseBase

# --- CORREDOR DA TORRE (entre o laboratório e a fase do nitrogênio) ---
#
# Andando para a direita, para fora do laboratório, a Cacau cai neste corredor,
# e é andando até o fundo dele que se chega à torre de destilação. Na volta é o
# mesmo caminho ao contrário.
#
#   laboratório  SaidaCorredor  <->  EntradaLab  [ corredor ]  SaidaTorre  <->  PassagemCorredor  fase 2
#
# Não há porta nenhuma no caminho: são pontas abertas (PassagemDeCena). Ela sai
# andando pela direita do laboratório e entra andando pela esquerda daqui; sai
# andando pelo fundo daqui e entra andando pela esquerda da fase 2 — e a volta
# é o mesmo ao contrário.
#
# O cenário é pintado à mão, todo com o tileset_fases.tres.
#
#   Fundo       a parede.
#   LuzDaSaida  o clarão da luz de fora no fundo do corredor (um degradê branco
#               por cima da parede, atrás das pilastras).
#   Pilares     as pilastras e as peças encostadas na parede. É só enfeite:
#               apague ou mude de lugar à vontade.
#   Estrutura   piso e teto. A colisão é a dos PRÓPRIOS TILES: pintou piso, tem
#               chão. O som do passo sai do tile (a camada "superficie" do
#               tileset); para um tile que não diz que chão é, vale o metadado
#               "superficie" da camada (ver som_passos.gd).
#   ParalaxeDaFrente   a camada que passa NA FRENTE de tudo (ver
#               paralaxe_da_frente.gd): pilastras pretas que cruzam a tela por
#               cima da Cacau, maiores e mais rápidas que o cenário.
#               Cada uma é a GÊMEA de uma pilastra da camada Pilares: a mesma
#               pilastra, pintada no mesmo lugar, na camada PilaresDaFrente
#               (travada, para não roubar clique: selecione-a pela árvore de
#               cena). NO EDITOR a gêmea aparece meio transparente, bem em cima
#               da pilastra dela — a pilastra só fica mais escura. NO JOGO ela
#               cresce a partir do centro da tela: tapa a pilastra dela quando
#               as duas estão no meio da tela e, longe do meio, se adianta.
#               PILASTRA NOVA: para ela ganhar a gêmea, selecione-a no editor
#               de tiles (camada Pilares), copie, troque para a camada
#               PilaresDaFrente e cole no mesmo lugar. (Nas gêmeas o fuste usa
#               o tile cheio do miolo do capitel: os dois tiles do fuste têm um
#               dente de 1 px no canto, que apareceria no contorno preto.)
#               OS NÚMEROS ficam no nó ParalaxeDaFrente: `aproximacao` é a
#               largura e a velocidade com que a gêmea cruza a tela;
#               `aproximacao_vertical` é a altura — a tela mostra 520 px e a
#               pilastra tem 384 (520 ÷ 384 = 1,36), então ela cabe inteira, o
#               capitel no alto e a base embaixo.
#   Colisoes/   o que segura a Cacau fora do quadro, à esquerda, onde não há
#               tile: o PisoDaEntrada (um chão invisível que continua o piso
#               para fora da tela, para ela chegar e sair andando) e, no fim
#               dele, a ParedeEsquerda.
#   EntradaLab  a ponta esquerda, outra PassagemDeCena (sentido -1): é por ela
#               que ela chega andando do laboratório, e cruzando-a de volta
#               (para a esquerda) ela sai andando pela direita de lá. O par
#               dela no laboratório é a SaidaCorredor.
#   SaidaTorre  a ponta aberta, uma PassagemDeCena (passagem_de_cena.gd): cruzou
#               a linha, troca de cena. É também por onde ela entra andando
#               quando volta da torre. O par dela na fase 2 é a
#               PassagemCorredor, na ponta esquerda de lá.
#   Morcegos/   os inimigos do corredor (morcego.gd): dormem pendurados no teto
#               e acordam quando ela chega perto. São três — um sozinho, para
#               ela aprender a briga, e mais adiante uma dupla, que acorda junta
#               e faz fila na mesma diagonal (o arremesso que pega os dois). Para
#               mudar um de lugar é só arrastar; Ctrl+D cria outro. Deixe as
#               duas pontas do corredor livres (uns 300 px), para ninguém
#               acordar em cima de quem acabou de chegar.
#   LimitesDaCamera, SpawnPadrao, Player   o de sempre (ver fase_base.gd).
#
# A CÂMERA fica mais perto aqui que nas outras fases, e parada na vertical: o
# `zoom_da_camera` do Player é 900 ÷ a altura do LimitesDaCamera (520 px, de
# y = 60 a y = 580), para a tela mostrar exatamente essa faixa. Mexeu no topo
# ou na base do LimitesDaCamera, refaça as duas contas: a do zoom e a da
# `aproximacao_vertical` da camada da frente.
#
# PARA ESTICAR OU ENCURTAR: pinte mais (ou menos) piso, teto e parede, arraste a
# SaidaTorre para a ponta nova e leve a borda direita do LimitesDaCamera para
# uns 24 px depois dela. Pinte o piso passando da ponta direita: a Cacau ainda
# anda uns passos enquanto a tela apaga.
