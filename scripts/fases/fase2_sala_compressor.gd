extends FaseBase

# --- SALA DO COMPRESSOR (fase 2, prédio da esquerda da rua) ---
#
# Uma sala só: o portão da rua à esquerda e o compressor de ar no meio
# (componentes/compressor_de_ar.tscn). Toda a lógica do puzzle mora no
# componente e na MissaoNitrogenio; aqui é só a base comum das fases.
#
# A sala é o prédio escuro da rua por dentro, com a mesma arte de fora (o
# Buildings.png): a parede verde, a faixa de cornija do meio, as janelas, e o
# mesmo portão de rolamento, com o painel de luzes.
#
# COMO EDITAR NO EDITOR:
#   Terreno   tudo o que colide (tileset das fases, fonte 15 = Buildings.png):
#             a faixa de cornija sólida no teto e no piso, a faixa girada nas
#             paredes, a base escura (4,4) por fora delas e a LAJE DO MEIO, de
#             parede a parede, na faixa vazada (a alternativa 1 dos tiles da
#             faixa): a Cacau sobe nela pulando e desce com S + espaço. O som
#             dos passos vem do metadado "superficie" da camada (concreto).
#   Fundo     a parede verde (mesma fonte): o topo escuro (8,0) embaixo de cada
#             faixa, a parede (8,1) e as quinas (7,x) nas pontas.
#   Cenario   as luminárias, embaixo do teto e da laje do meio (tileset da
#             cidade).
#   Janelas   as janelas (mesmo tileset), numa camada só delas em escala 3 —
#             uma vez e meia o resto da sala, para não sumirem na parede alta.
#   LimitesDaCamera  de x = 0 a 1376, as bordas de fora das duas paredes.
#   PortaRua  o portão (componentes/porta_rolamento.tscn), par da
#             PortaCompressor da rua.
#   CompressorDeAr  origem no chão.
#
# A sala de destilação (fase2_sala_destilacao.gd) é esta mesma montagem, tile
# por tile, com a mesma câmera: mexeu nas camadas ou na câmera daqui, mexa lá
# igual (o tools/teste_fase2.tscn confere).
