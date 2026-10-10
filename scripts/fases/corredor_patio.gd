extends FaseBase

# --- CORREDOR DO PÁTIO (entre o elevador da oficina e o pátio) ---
#
# O elevador de carga da fase 1 não sobe mais direto para o pátio: ele chega
# neste corredor, e é andando até o fundo dele que se sai para o pátio, a céu
# aberto. Na volta é o mesmo caminho ao contrário.
#
#   oficina  Entrada/ElevadorPatio  <->  Elevador  [ corredor ]  SaidaPatio  <->  PassagemCorredor  pátio
#
# É o MESMO corredor da torre (corredor_torre.tscn), copiado: o cenário, a
# camada de pilastras que passa na frente e a câmera são iguais, e o que cada
# nó deles faz está explicado no cabeçalho do corredor_torre.gd. As duas cenas
# são independentes — pintar uma não muda a outra. Este é mais curto (1600 px,
# um terço a menos: duas pilastras em vez de três) e as pontas são outras:
#
#   Elevador    a cabine de carga, na ponta esquerda (elevador_fase.gd). É por
#               ela que a Cacau chega da oficina — a cabine sobe do poço, a
#               rampa abre e o controle volta — e por ela que desce de novo:
#               entrar na cabine e apertar E. A cabine vem de BAIXO, então
#               "direcao" é DESCE (o poço fica embaixo do piso).
#   Estrutura   piso e teto, como no outro corredor: ATRÁS da Cacau, que pisa
#               na frente do piso. Só enquanto a cabine viaja o elevador a põe
#               na frente de tudo (é o "cenario_do_poco" dele) — é isso que faz
#               a cabine sumir dentro do poço em vez de escorregar por cima do
#               chão.
#   SaidaPatio  a ponta aberta da direita, uma PassagemDeCena: cruzou a linha,
#               troca de cena para o pátio — onde ela entra andando pela
#               esquerda, na grama. É também por aqui que ela entra andando
#               quando volta do pátio.
#   Morcegos/   os inimigos (morcego.gd), como no outro corredor. Aqui são dois,
#               um depois do outro: é o primeiro corredor do jogo em que eles
#               aparecem, então cada briga é contra um só.
#
# O resto (Fundo, LuzDaSaida, Pilares, ParalaxeDaFrente, Colisoes,
# LimitesDaCamera, SpawnPadrao, Player) é igual ao do corredor da torre.
#
# A lista de objetivos mostra aqui a trilha do CARBONO: o corredor está entre
# as cenas dela no scripts/roteiro_objetivos.gd.
