extends FaseBase

# --- SALA DE DESTILAÇÃO (fase 2, prédio da direita da rua) ---
#
# A mochila de N₂ (a ferramenta que alcança o primeiro degrau da torre), a
# coluna de destilação (componentes/destilador.tscn) e o cilindro verde de
# nitrogênio, que salta da coluna quando a destilação termina.
#
# A sala é a sala do compressor (fase2_sala_compressor.gd) tile por tile: as
# camadas Terreno, Fundo, Cenario e Janelas têm os mesmos tiles nas mesmas
# posições — a laje vazada do meio, a parede verde, as luminárias, as janelas
# em escala 3 — e a câmera é a mesma (LimitesDaCamera e o zoom da Cacau).
# Mexeu numa sala, mexa na outra igual: o tools/teste_fase2.tscn compara as
# duas célula por célula.
#
# COMO EDITAR NO EDITOR: as camadas, como na sala do compressor. Só desta sala
# são os objetos:
#   PortaRua  a porta_predio, par da porta_destilacao da rua.
#   Mochila   entre a porta e a primeira janela do térreo.
#   Destilador  origem no chão, no vão entre as duas primeiras janelas: alta
#             como é, a coluna passa na frente da laje do meio, e é nesse vão
#             que ela não cobre janela nem luminária nos dois andares.
#   CilindroDeNitrogenio  origem no chão, depois da segunda janela; salta da
#             coluna ("destilador" aponta para ela).
#   Enfeites  a PlacaEbulicao, na parede livre do térreo, à direita.
#   SpawnPadrao  longe da mochila e do alcance da coluna.
