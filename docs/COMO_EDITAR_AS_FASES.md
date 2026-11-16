# Como editar as fases no editor do Godot

As fases deixaram de ser geradas por código: agora são cenas `.tscn` normais,
com nós nomeados, TileMapLayer pintado e um slot de sprite em cada objeto.
Tudo é arrastável, redimensionável e trocável direto no editor.

## Onde fica cada coisa

| Arquivo | O que é |
|---|---|
| `scenes/fases/fase1_oficina.tscn` | Oficina do Carbono |
| `scenes/fases/corredor_patio.tscn` | Corredor entre o elevador da oficina e o pátio — o elevador chega nele, e o fundo dele dá no pátio |
| `scenes/fases/fase1_2_exterior.tscn` | Pátio da Oficina (fase 1.2) — tela única, a céu aberto; entra-se andando pela esquerda, vindo do corredor do pátio |
| `scenes/fases/corredor_torre.tscn` | Corredor entre o laboratório e a fase 2 — a porta da torre dá nele, e o fundo dele dá na fase |
| `scenes/fases/fase2_torre.tscn` | Fase 2, a do nitrogênio: a rua da Torre de Gases, com os três prédios (ver "A fase 2", abaixo) |
| `scenes/fases/fase2_sala_compressor.tscn` | A sala do compressor (o puzzle do gás) |
| `scenes/fases/fase2_torre_interior.tscn` | A Torre de Gases por dentro: oito andares de subida |
| `scenes/fases/fase2_telhado.tscn` | O telhado da torre (o cilindro de amostra e o elevador de carga) |
| `scenes/fases/fase2_sala_destilacao.tscn` | A sala de destilação (a mochila de N₂, a coluna, o cilindro de N₂) |
| `scenes/fases/fase3_subsolo.tscn` | Subsolo em blecaute (P + S) |
| `scenes/fases/fase_final.tscn` | Torre de lançamento |
| `scenes/fases/final_orbita.tscn` | Encerramento em órbita |
| `scenes/fases/hub_fases.tscn` | Painel CHONPS + as 4 portas do laboratório |
| `scenes/fases/componentes/*.tscn` | Os 17 objetos reutilizáveis |
| `assets/tilesets/tileset_fases.tres` | TileSet compartilhado (o mesmo do laboratório) |

O `hub_fases.tscn` já está instanciado dentro de
`scenes/laboratório_(world_2).tscn` — edite-o abrindo o próprio arquivo dele,
sem precisar mexer na cena grande do laboratório.

## Trocar um sprite

Todo componente tem um nó **`Sprite`** vazio e um **`Placeholder`** colorido.
Arraste seu PNG para a propriedade `Texture` do `Sprite`: **o placeholder some
sozinho** e sua arte assume o lugar. Não precisa apagar nada nem mexer em
código.

Alguns componentes têm um segundo slot para o estado ligado:

- `AlvoBumerangue` e `Interruptor`: `Sprite` (desligado) e `SpriteAtivo`
  (aceso). Se você preencher só o `Sprite`, ele fica esverdeado quando ativa.
- `Chama`: o `Sprite` é um `AnimatedSprite2D` — monte os frames do fogo nele.
  Sem frames, valem as partículas do nó `Fogo`.
- `PainelChonps`: um slot por elemento (`SlotC/Sprite`, `SlotH/Sprite`, ...).
  Apagado/aceso é feito por transparência, então uma arte só já resolve.

## A arte das ferramentas (maçarico, bumerangue, mochila...)

Ferramenta é caso à parte porque a mesma arte aparece em três lugares: o
pickup no chão, a ficha de coleta e a ficha dela nos **equipamentos**, no canto
da tela. Por isso ela não fica presa a um `Sprite` de cena: mora em
**`scripts/ferramentas/catalogo_ferramentas.gd`**.

Para dar arte a uma ferramenta, solte o PNG em `assets/itens/` e escreva o
caminho no campo `icone` da ferramenta lá no catálogo. É o mesmo lugar onde
ficam o nome, a descrição da ficha de coleta e a cor do aro que abre em volta
da ficha quando ela chega. O maçarico e o bumerangue já estão preenchidos — as
outras estão com `icone` vazio esperando a arte.

Enquanto o `icone` estiver vazio, a ferramenta funciona normalmente, só sem
ficha de coleta e sem aparecer nos equipamentos. Preencheu o `icone`, os três
lugares acendem de uma vez, sem mexer em cena nenhuma.

Se você preferir uma arte diferente só para o pickup do chão, arraste ela para
o `Sprite` do `PickupHabilidade`: o slot preenchido tem prioridade sobre o
catálogo.

## As teclas desenhadas (E, F, W, M...)

Toda tecla que o jogo mostra sai da mesma folha, `assets/UI/gdb-keyboard-2.png`
(o teclado inteiro, com os quatro quadros de apertar de cada tecla): o E do
cenário (portas inclusive), o M do caderno — e também a tecla embaixo de cada
ferramenta dos **equipamentos**, o E de continuar da **ficha de coleta** e a tecla
do **tutorial** (o F que afunda quando a Cacau arremessa). De controle na mão,
todas viram o botão do controle.

Já estão ligadas: ESC, E, W, A, S, D, M, F e Q. Para ligar mais uma (o SHIFT da
mochila, por exemplo), abra `scripts/ui/botoes_controle.gd`, escreva o canto
dela na folha em `TECLAS` (cada tecla ocupa 16×16 px no primeiro bloco) e
acrescente o nome no **fim** de `NOMES`. Tecla que ainda não está ligada
aparece no HUD como uma tampinha com a letra escrita.

## O HUD: a vida, a mochila e os equipamentos

O HUD é feito de uma peça só, a **ficha**: o quadrado da caixa de elemento do
caderno (`Hidrogênio tabela periódica.png`) — papel do caderno, moldura de
tinta, canto de pixel e uma sombra dura embaixo. Não tem painel de vidro,
hexágono nem degradê. As cores (tiradas do caderno e das teclas) e as medidas
da ficha ficam no topo de `scripts/ui/estilo_hud.gd`: mudar ali muda todas as
peças de uma vez.

| Peça | Onde | Arquivo |
|---|---|---|
| A vida | canto de cima, à esquerda | `scripts/ui/hud_vital.gd` |
| A mochila | canto de cima, à direita | `scripts/ui/mochila_hud.gd` |
| Os equipamentos | canto de baixo, à direita | `scripts/ui/equipamentos_hud.gd` |
| A ficha de coleta | meio da tela, ao pegar algo | `scripts/ui/popup_item.gd` |

**A vida** é o nome da Cacau escrito com a tabela periódica: **Ca · Ca · U**
(cálcio, cálcio, urânio), uma ficha por vida. Levar dano arranca a última ficha
do nome; curar a faz brotar de volta; com uma só, ela pulsa. Os elementos estão
em `ELEMENTOS`, no topo do `hud_vital.gd`. O rosto ao lado é a
`assets/Cacau Assets/cara do hud.png`, com os três quadros que ela já tinha:
inteira, o clarão branco (a pancada) e machucada (quando só resta uma vida). Se
redesenhar a folha, os recortes de cada quadro são as constantes `ROSTO_...`.
No simulador a mesma peça vira a nave: o desenho dela, o casco em porcentagem e
uma barra.

**A mochila** mostra as três casas, as vazias também. O nome do item não fica
escrito embaixo dele: o rótulo MOCHILA vira o nome por uns segundos quando o
item chega, e enquanto o ponteiro está em cima dele num puzzle de arrastar.

**Os equipamentos** são as ferramentas que ela já tem, cada uma com a tecla que
a usa embaixo. A nova entra encostada no canto e empurra as antigas.

**A ficha de coleta** tem só o desenho do item, o nome e a descrição (os textos
são os que estão escritos na cena do item ou no catálogo das ferramentas). O que
vier entre parênteses no nome — "Cilindro de Oxigênio (Comburente)" — vira uma
linha miúda embaixo dele; "(Ferramenta)" não vira nada. Ela não escreve o que
aconteceu nem para onde o item foi: no **E**, o desenho voa até a mochila ou
até os equipamentos, e é o voo que mostra.

Para ver uma peça sem rodar o jogo, ligue a "Prévia no editor" dela no
Inspector (e desligue depois: ela mora no player, que está em toda fase). O
teste automático é `tools/teste_hud.tscn` (com `-- --capturas=<pasta>`, sem
`--headless`, ele salva imagens do HUD no pátio, no dano, no perigo e na
cura); a ficha de coleta e a mochila têm o `tools/teste_popup_item.tscn`.

## Pintar o cenário

Cada fase tem duas camadas de tiles:

- **`Fundo`** — o preenchimento sem colisão, atrás de tudo;
- **`Terreno`** — chão, paredes e plataformas, **com colisão** (a colisão vem
  do próprio tile, não de nós separados).

Selecione a camada, abra a aba TileMap embaixo e pinte. Os tiles em uso são os
mesmos do laboratório: o tileset industrial para o terreno e o tile de fundo
escuro atrás. Cada célula equivale a 32 px no mundo (tiles de 16 px com a
camada em escala 2).

Se você apagar um trecho de `Terreno`, o chão some de verdade — o jogador cai.

**A faixa de cornija vazada.** A faixa de cornija do `Buildings.png` (tiles 0
a 3 da primeira linha, na fonte 15 do `tileset_fases.tres`) tem duas versões:

- a **alternativa 0**, sólida por todos os lados — o chão, o teto e as paredes
  feitas da faixa girada;
- a **alternativa 1**, **vazada** (one-way) — as lajes no meio da parede e os
  telhados: a Cacau passa por baixo pulando, pisa em cima, e **S + espaço**
  (↓ + ✕ no controle) a atravessa para baixo. Os passos nela soam como
  concreto.

Na paleta da aba TileMap, a alternativa aparece logo à direita do atlas. Ela
só colide pintada numa camada com colisão: o `Terreno` ou, na rua da fase 2, a
camada `Lajes` (lá o `Terreno` é só o chão de grama). Pintada numa camada de
enfeite, como o `Fundo` ou o `Cenario`, ela é só desenho e a Cacau atravessa.

## Mudar tamanhos e comportamento

Selecione o nó e use o Inspetor. As propriedades mais usadas:

- `ChapaSoldada`, `PisoEletrificado`, `CorrenteVapor`, `BlocoAlternavel`:
  **`tamanho`** redimensiona colisão e placeholder juntos.
- `CorrenteVapor`: **`empuxo`** (a Cacau anda a 350 px/s) e **`direcao`**.
- `AlvoBumerangue`: **`permanece_ativo`** (interruptor definitivo) ou a
  **`janela`** em segundos (alvo temporizado).
- Portas entre as fases: todas são a porta da oficina (`porta_simulador.gd`) —
  a Ala de Pirólise com a arte dela (`porta_ala_eletrolise.tscn`) e as que ainda
  não têm arte própria (Torre de Gases, Torre de Lançamento, as voltas ao
  laboratório e a cápsula) com o `porta modelo.png` (`porta_modelo.tscn`).
  Mesma animação, mesmo botão: **E** (□ no controle), o `IconeInteragir` da
  porta — só a altura dele conta, o x vai sozinho para o meio. No Inspetor:
  **`cena_destino`** e o par **`tag_destino` / `tag_aqui`** — ao chegar, quem
  recebe a Cacau (e toca a saída pela porta) é a porta com **`recebe_chegada`**
  ligado cujo `tag_aqui` bate com o `tag_destino` de quem ela usou. Para trocar a
  arte de uma delas, duplique `porta_modelo.tscn` e troque a textura do
  `SpritePorta` (12 quadros de 148x134 na horizontal).
- `PortaFase`: sobrou só no alçapão do fosso de ventilação, no laboratório
  (**`no_piso`**, trancado por **`requer_habilidade`** = mochila). Usa o mesmo
  par de tags, e conversa com as portas acima.
- `PassagemDeCena` (`scripts/fases/passagem_de_cena.gd`): a ponta aberta de um
  corredor, sem porta. É um Node2D posto em cima da linha de saída: a Cacau
  cruza a linha andando e a cena troca sozinha (ela segue andando enquanto a
  tela apaga); vindo da outra cena, entra andando por ali. Mesmas
  **`cena_destino`** / **`tag_destino`** / **`tag_aqui`** das portas, então uma
  porta pode mandar para uma passagem e vice-versa. **`sentido`** diz o lado de
  fora (1 = direita) e **`distancia_entrada`** quanto ela anda para dentro ao
  chegar. O piso tem de continuar depois da linha.
- `MesaPuzzle`: **`puzzle_config`** guarda os slots, as peças e os textos do
  puzzle de arrastar.

## Mover o começo da fase e a câmera

- **`SpawnPadrao`** (Marker2D): onde a personagem nasce quando entra pela
  primeira vez.
- **`LimitesDaCamera`** (ReferenceRect, só visível no editor): arraste e
  redimensione para definir até onde a câmera acompanha.
- **`TrilhoCamera`** (Line2D amarela, só visível no editor): para rampas e
  subidas. Dentro do trecho da linha, a câmera deixa de ficar presa na altura
  do `LimitesDaCamera` e o centro dela passa a seguir a linha, com curva suave.
  Arraste os pontos para ajustar a altura; mantenha o primeiro e o último na
  altura em que a câmera já está do lado de fora, para a entrada e a saída não
  darem tranco. No Inspetor, `folga_vertical` deixa a câmera acompanhar um
  pouco os pulos e `margem_personagem` garante que ela nunca saia da tela.
  Pode haver mais de um trilho por fase (um por rampa). Na Oficina, o
  trilho cobre a rampa que começa por volta de x = 6270.
  O trilho só olha o x da personagem — não serve para subir na vertical; para
  isso use a `ZonaCamera` abaixo.
- **`ZonaCamera`** (Polygon2D azul, só visível no editor): para corredores e
  poços verticais. Enquanto a personagem está dentro do polígono, a câmera fica
  travada na horizontal em `centro_x` e só anda na vertical. Arraste os
  vértices para mudar a área. Com `subir_so_ao_pousar` ligado, a altura só muda
  quando ela pisa numa plataforma (os pulos não balançam a tela);
  `altura_do_olhar` diz quanto acima dela fica o centro da tela; `limite_topo`
  e `limite_base` param a câmera no teto/chão. Tem prioridade sobre o trilho.
  Na Oficina, `ZonaCorredorVertical` começa em x = 7840, no platô, e cobre o
  corredor das plataformas até o topo (y = -928); o `limite_topo` fica em
  -1100 para a câmera mostrar um pouco acima do alto do corredor. Se o
  corredor crescer para cima, suba o polígono e o `limite_topo` junto.
  `assumir_so_acima_de_y` serve para corredores que só se descem: a zona só
  assume se a personagem entrar no polígono acima dessa linha, e depois vale
  até ela sair. Assim quem passa lá embaixo, pelo chão, não trava a câmera.
  Na Oficina, `ZonaCorredorTorretas` cobre a descida das torretas: assume
  quando a personagem volta pelo andar de cima e passa de x = 3260 (acima de
  y = -700), trava o x da câmera entre 2250 e 3320 (`centro_x` = 2785, com
  `margem_lateral` = 0 para o x não sair do lugar nem com a personagem
  encostada na parede) e solta quando ela sai do corredor lá embaixo, pelos
  lados. Na vertical ela fica centrada na personagem o tempo todo
  (`altura_do_olhar` = 0 e `subir_so_ao_pousar` desligado), parando só no
  `limite_topo` e no `limite_base` (o chão, para não mostrar o vazio embaixo).
- **`AndarCamera`** (ReferenceRect verde, só visível no editor): um segundo
  `LimitesDaCamera` para outro nível da fase. Quando a personagem **pisa** no
  chão dentro do retângulo, a câmera volta a ser a do começo da fase (solta na
  horizontal, travada na vertical entre o topo e a base do retângulo); quando
  ela sai do retângulo, volta a valer o resto. Vale para andar, zona e trilho:
  se a personagem sair de um deles NO AR e não entrar em nenhum outro, a
  câmera segura o enquadramento anterior até ela pousar (sem isso, subir do
  corredor das torretas para o andar de cima jogava a câmera por um instante
  lá para os limites do começo da fase). Tem prioridade sobre a zona e o
  trilho. Para repetir o enquadramento do começo, deixe o topo 532 px acima do
  chão e a base 78 px abaixo. Na Oficina, `AndarDeCima` cobre o caminho de
  volta pelo alto (chão em y = -928) até x = 7552, onde terminam as
  plataformas do corredor.

### Câmera parada (fase de tela única)

A **fase 1.2** (`fase1_2_exterior.tscn`) é uma tela só: a câmera não anda,
como na casa do Yoshi. Não há script travando nada — o truque é o
`LimitesDaCamera` ter **exatamente o tamanho de um quadro**: 1185 × 667, que é
a janela de 1600 × 900 dividida pelo zoom da câmera nesta fase — 1,35, o mesmo
do `world1` (`Zoom Da Camera`, no Inspector do `Player` da cena). Como a
Camera2D nunca mostra nada fora dos limites e o retângulo tem o tamanho da
tela, só existe um enquadramento possível.

- Para deixar QUALQUER fase de tela parada, é só encolher o `LimitesDaCamera`
  até o tamanho do quadro dela: 1067 × 600 no zoom padrão do player (1,5),
  1185 × 667 no 1,35.
- No instante em que o retângulo passar desse tamanho, a câmera volta a
  acompanhar a personagem — não há exceção escondida em lugar nenhum.
- Mudou o zoom de uma fase de tela única? Refaça o retângulo. No pátio a base
  ficou onde estava (y = 580, para a grama continuar na mesma faixa de baixo da
  tela) e ele cresceu para a direita e **para cima** — e o fundo teve de
  acompanhar: camada de `ParallaxBackground` com `motion_scale` 0 fica presa ao
  canto de cima da tela, não ao chão, então cada camada do `BG` ganhou
  `motion_offset.y = 67` (o quanto o topo subiu) para a mata continuar
  encostada na grama.
- Fase de tela única não tem para onde a personagem andar embora: a 1.2 tem
  dois `StaticBody2D` invisíveis (`Paredes/`) logo fora do quadro. Se esticar a
  fase, arraste as paredes junto.

**Teleportes e câmera:** qualquer código que mover a personagem de uma vez
(porta, passagem, volta de uma morte) deve chamar
`CameraJogador.encaixar(player)` logo depois. Ele esquece o andar/zona/trilho
de onde ela estava, escolhe o do lugar novo e põe a câmera lá sem deslizar.
Só `reset_smoothing()` não basta: a câmera ficaria com os limites do lugar
antigo e escorregaria até a personagem no quadro seguinte.

## Checkpoints: bandeiras e salas

Morrer recarrega a fase e a personagem volta no **último ponto de retorno
registrado**. O primeiro ponto de cada visita é a **porta por onde ela chegou**:
morrer antes de qualquer bandeira ou sala faz ela sair pela porta de novo, com
a mesma animação da entrada. Depois disso há dois jeitos de registrar, e todos
escrevem no mesmo lugar
(`PontoDeRetorno`, em `scripts/fases/ponto_de_retorno.gd`). Por isso eles
nunca entram em conflito: **vale sempre o mais recente**.

- **Bandeira** (`scenes/fases/componentes/checkpoint.tscn`): passar por ela
  registra o ponto, toca o som e mostra o letreiro. Só uma tremula por vez. Se
  depois disso a personagem entrar numa sala, o ponto passa a ser a sala (a
  bandeira continua tremulando). Tocar de novo na bandeira retoma o ponto, em
  silêncio.
- **Sala de retorno** (`SalaDeRetorno`: um nó `ReferenceRect` com o script
  `scripts/fases/sala_de_retorno.gd`, só visível no editor): desenhe o retângulo
  em volta de uma sala. Quando a personagem **entra** nele, o ponto é gravado
  sem nenhum aviso na tela.
  - **Com marcadores:** ponha um ou mais `Marker2D` como filhos do retângulo.
    Vale o mais perto de onde ela entrou; um em cada porta resolve as salas
    atravessadas nos dois sentidos. A origem do marcador é o meio da cápsula,
    ~37 px acima do chão.
  - **Sem marcadores:** vale o primeiro chão **seguro** que ela pisar lá
    dentro: tile ou `StaticBody2D`, por 6 quadros seguidos (`quadros_no_chao`)
    e sem tomar dano. Plataforma que cai, plataforma móvel e caixa não contam.
  - **Não grava:** a sala onde ela já está quando a cena abre (renascer numa
    bandeira no meio da sala não é trocado pelo começo dela), atravessar no ar
    sem pisar em chão seguro, e entrar morrendo ou no recuo de um golpe.
  - `ativa` desligado desativa a sala sem apagar o nó.

A memória do **lugar** vale só para mortes. Sair por uma porta e voltar começa
a fase do início (o player avisa o `PontoDeRetorno` antes de recarregar por
morte; qualquer outra abertura de cena é uma visita nova). Não há save em
arquivo: fechar o jogo esquece tudo.

O ponto de retorno guarda só ONDE ela renasce. O que ela já fez na fase (a
caixa elétrica quebrada, os espinhos desligados, a torreta estragada, o domo
aberto) é outra memória, que não depende de bandeira nenhuma: **morrer nunca
desfaz progresso**. Ver "O que a fase lembra", mais abaixo.

Teste automático (bandeira, sala, os dois juntos, sair e voltar, câmera):

```
godot --headless --fixed-fps 60 --path . -s res://tools/teste_ponto_de_retorno.gd
```

## Plataformas que caem

O nó **`PlataformasQueCaem`** (retângulo de borda vermelha, só visível no
editor) transforma tiles pintados em plataformas que cedem: quando a
personagem pousa, a plataforma afunda, treme soltando poeira, despenca, some e
volta ao lugar depois de um tempo, piscando antes. Volta sempre no horário,
mesmo com a personagem ocupando o espaço (embaixo ou na frente dela): nesse
caso a plataforma volta de mão única — não empurra nem prende, mas dá para
pular e pousar em cima dela — e fica sólida por todos os lados de novo assim
que o espaço fica livre.

- **Onde:** todo tile das `fontes` escolhidas (fonte 0 = `Plataformas.png`)
  que estiver dentro do retângulo, na camada `Terreno`. Para ter mais
  plataformas, pinte mais tiles lá dentro. Tiles encostados formam uma
  plataforma só.
- **No editor os tiles continuam visíveis**; eles só se soltam durante o jogo.
- **Ajustes** no Inspetor: `tempo_aviso` (janela para pular), `afundamento`,
  `intensidade_tremor`, `aceleracao_queda`, `velocidade_max_queda`,
  `tempo_ate_sumir`, `tremor_camera`, `tempo_retorno` e os três sons.
  Valem para todas as plataformas do retângulo — para um trecho com outro
  ritmo, duplique o nó e cubra só aquele trecho.
- Na Oficina, o retângulo cobre as plataformas do corredor vertical.
- **Som dos passos:** os tiles de `Plataformas.png` são "metal" na camada
  `superficie` do TileSet, e a plataforma que se solta leva isso junto — pisar
  nela soa metal (ver `scripts/som_passos.gd`).

## Plataforma móvel (parede a parede)

`scenes/fases/componentes/plataforma_movel.tscn` vai e volta na horizontal
entre duas paredes, saindo devagar, acelerando no meio e freando antes de
parar um instante em cada ponta. Quem está em cima é carregado junto.

- **Posicionar:** arraste para dentro da fase na altura desejada. Com
  `detectar_paredes` ligado ela acha sozinha a parede de cada lado ao começar
  a fase (mova o nó e o percurso acompanha). Desligado, valem
  `limite_esquerdo` / `limite_direito` (x global do centro em cada ponta).
- **Ritmo:** `velocidade` (média), `pausa_nas_pontas`, `comecar_para_direita`
  e `folga_da_parede`.
- **É de mão única:** sobe-se nela pulando por baixo, e ela não empurra
  ninguém de lado (evita esmagar a personagem num corredor apertado).
- **Cor:** usa a mesma arte das outras plataformas (`Plataformas.png`) com o
  shader `shaders/deslocar_matiz.gdshader`. No material do `Sprite`, `giro_matiz`
  troca a cor (0.5 = azul-ciano, 0.33 = verde, 0.75 = roxo) sem mexer no PNG.
- **Não use tiles da fonte 0 no lugar dela:** dentro do retângulo das
  `PlataformasQueCaem` eles viram plataforma que cai.
- Na Oficina ela fica no corredor vertical, em y = -608, no lugar de uma das
  plataformas que caíam.

## Bolas quicantes (rampa)

O nó **`GeradorBolas`** (`scripts/fases/gerador_bolas.gd`, a cruz de um
Marker2D) solta uma `BolaQuicante` de tempos em tempos. A bola cai, bate na
rampa e desce aos pulinhos, todos do mesmo tamanho; no **primeiro quique em
chão reto depois da rampa** ela se despedaça. Machuca a personagem no contato
e atravessa a personagem e as caixas.

- **Onde nasce:** arraste o nó. Na Oficina, `GeradorBolasRampa` fica em
  (7100, -550), no buraco do teto acima do topo da rampa; a bola se quebra no
  chão do pé da rampa, por volta de x = 6200.
- **Só por perto:** o gerador aponta (export `area`) para um retângulo da
  fase — na Oficina, `AreaBolasRampa` (borda laranja, x 5500 a 7840, do chão
  até um pouco acima do platô). Com a personagem dentro, as bolas caem; saiu,
  param de nascer (as que já estão descendo terminam e se quebram); voltou, a
  primeira cai na hora. Arraste/redimensione o retângulo para mudar a área.
  Sem `area`, caem sempre.
- **Ritmo:** `intervalo`, `atraso_inicial` (espera depois de entrar na área) e
  `maximo_simultaneas`.
- **Jeito dos pulinhos:** `velocidade_horizontal` (distância de cada pulo),
  `forca_quique` (altura) e `gravidade`. Mais `dano`, `tremor_ao_quebrar` e os
  dois sons.
- **Arte:** em `scenes/fases/componentes/bola_quicante.tscn`, arraste o PNG
  para `Visual/Giro/Sprite`; o círculo vermelho de placeholder some sozinho.
- Chão reto é qualquer superfície com até 12° de inclinação; as rampas do
  tileset têm ~26,6°.

## Acrescentar objetos

Arraste qualquer arquivo de `scenes/fases/componentes/` para dentro da fase e
posicione. Componentes que precisam de fiação com outros nós (esteiras,
guindastes, setores de luz) seguem um padrão de agrupamento que o script da
fase percorre sozinho:

- **Fase 3 — setores:** `AlaOeste/Setores/SetorN` com um `Interruptor` e uma
  `Luz` dentro. Duplique um setor inteiro e ele já funciona.
- **Fase 3 — esteiras:** `AlaLeste/Esteiras/EsteiraN` com `Alvo` e `Bloco`.
- **Final — guindastes:** `Guindastes/Conjuntos/GuindasteN` com `Alvo` e
  `Lanca`.

### O elevador entre fases (fase 1 ↔ corredor do pátio)

`scenes/fases/componentes/elevador_fase.tscn` é uma cabine de carga que liga
dois andares que são **cenas diferentes**. Ela fica sempre aberta (a rampa
estendida, o 1º dos 13 quadros do sheet): entre nela, aperte **E** e o resto
acontece sozinho — a Cacau anda até o meio da cabine, a rampa recolhe, a cabine
sai de quadro **sem a câmera acompanhar** e a fase de destino abre. Na chegada,
o elevador do outro lado toca a mesma cena ao contrário: a tela clareia com a
cabine ainda no poço e fechada, ela entra no lugar, a rampa abre (a mesma
animação rodada de trás para a frente) e o controle volta.

**É só arrastar.** A origem do nó é o **chão de fora, no meio da cabine**:
encoste-a na linha do piso da fase e pronto. No editor ele desenha o poço — uma
linha tracejada até onde a cabine vai parar, com o contorno dela no fim.

**A colisão é sua:** `Cabine/Piso/Colisao` é um `CollisionPolygon2D` comum —
edite os pontos no editor como qualquer polígono. Ele desenha o **estrado** da
cabine e a **rampinha** que sobe da rua até ele; é por essa rampa que se entra
andando e é esse polígono que segura a personagem durante a viagem (por isso o
`Piso` é `AnimatableBody2D`, e não `StaticBody2D`: ele anda). Os pontos ficam em
pixels da arte, então mudar a `escala_da_arte` leva o polígono junto. A altura
em que a personagem embarca sai sozinha do **ponto mais alto** do polígono —
redesenhe a rampa e o embarque acompanha, sem mexer em número nenhum.

**A grade:** `Cabine/Piso/Grade` é a gradinha da beirada **esquerda** da
cabine, o lado oposto ao da rampa: um retângulo fino que nasce no estrado e
sobe até o corrimão do desenho (33 px na tela). Andando, a Cacau para nela e
não desce pelo lado esquerdo; **pulando**, passa por cima. É um
`CollisionShape2D` comum, irmão do polígono: arraste as alças para mudar a
altura (mais alta que um pulo, uns 90 px, e ela vira parede) ou apague o nó
para a cabine voltar a ser aberta dos dois lados. Fica separada do polígono de
propósito — dentro dele, ela viraria o "ponto mais alto" e a Cacau embarcaria
em cima da grade.

No Inspetor:

| Propriedade | O que faz |
|---|---|
| `escala_da_arte` | Tamanho da cabine. O resto do jogo desenha em 2x, mas em 2x o elevador fica quase da altura da Cacau — o padrão é **1,5x**, que o deixa com cara de carrinho de carga. Mexer aqui reposiciona sozinho a zona do E, o balão e o rascunho do poço. Use números "inteiros de meio" (1 / 1,5 / 2): escala quebrada engorda umas fileiras de pixel |
| `direcao` | De que lado fica o poço: `SOBE` (parte para cima e chega vindo de cima) ou `DESCE` |
| `curso` | Quantos pixels a cabine anda. Grande o bastante para ela sair inteira da tela — a câmera fica parada e o que sobrar em quadro fica boiando |
| `cena_destino` | O `.tscn` do outro andar |
| `tag_aqui` / `tag_destino` | O par que liga os dois elevadores, igual ao das portas de fase |
| `recebe_chegada` | Desligue no elevador que só leva e nunca recebe |
| Tempos | Duração da porta, do percurso, das pausas e dos fades |
| `requer_habilidade` | Deixa o elevador travado até a habilidade existir |
| `cabine_aqui` | Desligado, o poço fica vazio: a cabine está parada no outro andar (some o desenho e o estrado) e o E dá a `fala_trancada`. Quem chega de elevador chega com a cabine, então a chegada liga isto sozinha; o resto é com o script da fase |

As duas pontas montadas hoje são `Entrada/ElevadorPatio` (na Oficina, sobe,
tag `oficina` → `patio`) e `Elevador` (no corredor do pátio,
`corredor_patio.tscn`, desce, tag `patio` → `oficina`). O elevador não chega
mais dentro do pátio: do corredor sai-se andando para ele (ver "O corredor do
pátio", mais abaixo).

**Na Oficina o elevador fica na ponta esquerda do mapa**, e o chão acaba logo
depois dele, já fora da tela. Quem segura a Cacau ali é
`Colisoes/ParedeEsquerda`, uma parede invisível com a face em x = -8: são 8 px
para fora da tela, o mínimo para ela caber em pé no vão entre a parede e a
grade da cabine (ela tem 26 px de largura, o vão tem 29,5). Pulando a grade ela
desce nesse vão, não cai do mundo, e volta pulando de novo. Se mudar o elevador
de lugar, leve a parede junto.

**Ordem de desenho:** a cena do componente vem em `z_index` 3, na frente da
personagem (que anda em `z_index` 2), para ela aparecer *atrás* da grade. Para
a cabine sumir dentro do poço em vez de deslizar por cima do chão, é o
**cenário** que precisa estar na frente: no corredor do pátio a camada do piso
(`Estrutura`) está em `z_index` 10 só por causa disso. Se você puser um elevador
numa fase nova, faça o mesmo com o chão dela — ou aceite que a cabine passe
por cima até sair de quadro.

### As gaiolas de vidro (fase 1)

As duas ferramentas da Oficina do Carbono ficam trancadas na **gaiola de vidro
elétrica** (`scenes/fases/componentes/gaiola_vidro_eletrica.tscn`), exclusiva
desta fase — o prólogo continua com a gaiola de grade (`scenes/gaiola_puzzle.tscn`).
As duas cenas usam o mesmo script, `scripts/gaiola_puzzle.gd`.

- `Entrada/GaiolaBumerangue` — abre o puzzle do carbono (montar o átomo).
- `Patio/GaiolaMacarico` — abre o puzzle do maçarico. Dentro do domo, encostada
  e inclinada no maçarico, está a `Patio/MascaraSolda`: um `Sprite2D` e nada
  mais — **não é item**, não entra no inventário e continua ali depois que a
  ferramenta é recolhida. É só arrastar/girar para reposicionar.

A arte é `assets/Gaiola/gaiola de vidro eletrica.png` (12 quadros de 504×576,
em escala 2/9 = o mesmo pixel 2x dos tiles). A gaiola fica parada no 1º quadro;
ao destravar, toca os 12 quadros e para no último (a cúpula recolhida na base).
O item só pode ser pego quando a animação termina.

Duas propriedades ligam cada gaiola ao resto:

- `puzzle_cena` → a cena do puzzle (vazio = abre direto com E);
- `item_alvo` → o pickup que ela mantém desligado até abrir.

**O puzzle pela metade não se perde numa morte.** A gaiola guarda, em nome
dela, o que o puzzle anotar (a etapa 1 do maçarico concluída, quantas
partículas já estão no átomo de carbono) e devolve ao puzzle novo quando a
fase recarrega. O puzzle que quiser isso só precisa de um sinal
`progresso_mudou(dados)` e de um método `restaurar_progresso(dados)` — está
explicado no cabeçalho de `scripts/gaiola_puzzle.gd`.

A **origem da gaiola é o pé da base**: encoste o nó no chão. O item fica em
cima da base, dentro da cúpula — 4 px à esquerda e 55 px acima da origem da
gaiola. Para mover, arraste os **dois** nós juntos (gaiola e pickup). A gaiola
de vidro não tem colisão: ela é mais alta que o pulo da Cacau e, sólida,
fecharia o caminho do pátio.

### O puzzle do maçarico (fase 1)

`scenes/puzzle_macarico.tscn`, na tela do computador
(`assets/UI/Computador receptor/tela_computador.png`). É a mesma interface de
balanceamento do puzzle do foguete, mas **sem a ajuda do cientista** — quem
corrige é o rodapé da tela. A tela se arruma como a do foguete (ver "As telas
de balanceamento", logo abaixo): contagem dos átomos no alto, equação escrita
embaixo dela e cada termo em cima da molécula dele. Duas etapas:

1. `C₂H₂ + O₂ → CO + H₂` — o acetileno reagindo com o oxigênio;
2. `CO + H₂ + O₂ → CO₂ + H₂O` — os gases da etapa 1 queimando com oxigênio.

**Vale qualquer resposta balanceada** (C, H e O batendo dos dois lados): na
etapa 1, 1-1-2-1 ou qualquer múltiplo dele; na etapa 2, 1-1-1-1-1, 4-2-3-4-2,
3-1-2-3-1 etc. Resposta certa que não está na forma mais simples (como
2-2-4-2) passa do mesmo jeito, e o rodapé mostra a forma simplificada como dica.

As reações e todos os textos ficam na constante `ETAPAS`, no
topo de `scripts/puzzle_macarico.gd`. A coluna de cada substância (setas e
tamanho das moléculas) é `scenes/ui/termo_equacao.tscn`. Concluir a etapa 1
fica guardado: fechar a tela, ou morrer, e voltar recomeça da etapa 2. Durante
os testes, a tecla **L** resolve o puzzle na hora; o teste automático é
`tools/teste_puzzle_macarico.tscn`.

### As telas de balanceamento (foguete, maçarico e Laboratório)

As três telas que desenham as moléculas têm a mesma arrumação, de cima para
baixo:

1. **a contagem dos átomos** — "Reagentes" e "Produtos", com "H = 4  O = 2"
   embaixo de cada título (verde quando o elemento bate dos dois lados);
2. **a equação escrita** — logo acima dos desenhos, com **cada termo centrado
   em cima da coluna da molécula que ele representa** ("2 H₂O" em cima das
   moléculas de água), e o "+" e a seta em cima dos vãos;
3. **as colunas** — seta de cima, as moléculas, seta de baixo.

Quem escreve a equação desse jeito, nas três telas, é
`scripts/ui/equacao_sobre_colunas.gd`: ele recebe o x do meio de cada coluna
e põe o termo ali. A letra é uma só para a linha inteira e encolhe até todo
termo caber em cima da coluna dele.

Na cena, o que dá para mexer:

- **subir ou descer a equação** — o nó `LinhaEquacao` (no foguete, o pai dele,
  `PainelEquacaoEscrita`). É um `Control` comum: a altura dele é a da linha,
  e os termos são postos lá dentro pelo script;
- **subir ou descer a contagem** — `LabelReagentesTitulo`, `LabelReagentesValor`
  e os dois de `Produtos`;
- **mover uma coluna** — no foguete, arraste os nós da coluna (`BotaoMaisH2`,
  `MoleculasH2`, `BotaoMenosH2`...): o termo escrito acompanha a seta de cima
  dela, que é o eixo da coluna. No maçarico e no Laboratório as colunas são
  montadas pelo script (uma `termo_equacao.tscn` por substância) e a equação
  segue junto.

**O balanceamento guiado do Dr. Chico** (só no foguete) é a constante
`ROTEIRO`, no topo de `scripts/puzzle_foguete.gd`, e as falas são as timelines
`timelines/cientista_balanceamento_1` a `_4`. O método que ele ensina:

1. **uma molécula de cada** substância — a reação precisa ter todos os
   reagentes e todos os produtos (uma fala só; a seta passa pelos três botões);
2. contar os átomos de cada elemento dos dois lados e adicionar uma molécula
   **onde o elemento está em menor quantidade** (falta oxigênio nos produtos:
   mais uma água);
3. repetir até **todos os elementos estarem igualados** (a água trouxe
   hidrogênio: falta nos reagentes — e esse último clique é da pessoa).

Cada passo do roteiro diz a fala, o que o holofote acende, o botão pedido e os
coeficientes que encerram o passo. Para o holofote trocar de lugar NO MEIO de
uma fala, a timeline solta `[signal arg="nome"]` na frase certa e o passo
declara esse nome em `"sinais"` (é assim que a moldura passa do "H = 2" para o
"O = 1" quando ele fala de cada um). Os testes são
`tools/teste_puzzle_foguete.tscn`, `tools/teste_puzzle_macarico.tscn` e
`tools/teste_balanceamento.tscn`; com `-- --capturas=<pasta>` e sem
`--headless` eles salvam uma imagem de cada momento.

### O puzzle do bumerangue (fase 1)

`scenes/puzzle_carbono.tscn`, na mesma tela do computador do puzzle do
maçarico. É a ideia do puzzle do hidrogênio do prólogo — montar o átomo com
as partículas —, agora com o **carbono**: 6 prótons e 6 nêutrons no núcleo,
2 elétrons na camada K e 4 na camada L. A caixa do elemento (6, C, 12,011) é a
pista: o número atômico dá os prótons, a massa menos os prótons dá os
nêutrons, e o átomo neutro tem tantos elétrons quantos prótons.

Tudo se mexe pelas **setas**, as mesmas dos puzzles de balanceamento. São
quatro seletores (`scenes/ui/seletor_particula.tscn`): prótons, nêutrons,
camada K e camada L. A seta de cima põe uma partícula no átomo, a de baixo
tira, e o número entre elas fica amarelo (falta), verde (bate) ou vermelho
(passou). O que não cabe (o terceiro elétron na camada K) a seta recusa, e o
rodapé diz por quê. Fechar a tela no meio não desmonta o átomo — nem morrer:
na fase recarregada, as partículas que já estavam no átomo saem dos seletores
e voltam ao lugar quando a tela abre.

O átomo pedido, os textos do terminal e os raios do desenho ficam nas
constantes do topo de `scripts/puzzle_carbono.gd`. Na cena, o átomo é
desenhado no meio do nó `Atomo`, e cada seletor é a cena do seletor com os
filhos editáveis: as partículas têm a arte e o tamanho do `Icone` do seletor
de cada uma (a arte é
`assets/UI/Computador receptor/particulas_atomo.png`). Durante os testes, a
tecla **L** resolve o puzzle na hora; o teste automático é
`tools/teste_puzzle_carbono.tscn`.

### O tutorial do bumerangue

Pegou o bumerangue, sobe a ficha de coleta de sempre (o desenho, o nome e a
descrição). No **E**, o ícone voa para os **equipamentos** e sobe uma segunda
ficha, o **tutorial**, limpa de propósito: um quadradinho animado e **uma
frase** embaixo dele. Nada de título nem rodapé escrito: só o **E** preso na
beirada de baixo, no canto direito, igual ao da ficha de coleta. O jogo fica
parado até fechar.

Ela fecha com o E e com **qualquer outra tecla de ação**: espaço, enter, ESC, shift, F, M,
o clique do mouse — e, no controle, ✕ ○ □ △. São todas as ações do mapa de
entrada do projeto (Projeto → Configurações → Mapa de Entrada), então tecla de
ferramenta nova já entra sozinha. Só não fecham as teclas de **andar** (WASD,
setas, direcional e analógico) e tecla que não faz nada no jogo. A tecla que
fecha não vira ação no mundo: o F não arremessa, o espaço não pula. A regra
está em "QUEM FECHA A FICHA", em `scripts/ui/ferramentas_hud.gd`.

No quadradinho, a Cacau está parada (a `idle` do jogo), a tecla **F** afunda
no alto, no meio, ela arremessa, o bumerangue vai até a caixa elétrica, a
caixa quebra e ele volta para a mão — e ela volta para a `idle`. De controle,
o F vira o **□**.

- **A frase** é o campo `tutorial` → `texto` do bumerangue, em
  `scripts/ferramentas/catalogo_ferramentas.gd`. É a única coisa escrita na
  ficha; ela quebra em linhas sozinha, na largura do quadradinho.
- **O quadradinho** é a cena `scenes/ui/demo_bumerangue.tscn`, com nós de
  verdade:
  - `Mundo/Cenario` é um `TileMapLayer` com o tileset das fases — pinte como
    se pinta o mapa. Hoje ele repete o que há em volta das caixas da fase 1: a
    placa rebitada da parede, o piso de faixa amarela e, em cima da caixa, as
    placas com os cabos dela subindo. A colisão fica desligada (é só desenho);
  - `Mundo/Cacau` tem as duas animações (`idle` e `jogando_bumerangue`) e a
    velocidade de cada uma; o bumerangue voa do `Mao` dela até o `Alvo` da
    `Mundo/Caixa`;
  - `Tecla` é a tecla F: arraste o nó para mudar o lugar e redimensione para
    mudar o tamanho (o desenho ocupa o nó inteiro; hoje 40×40, no alto e no
    meio);
  - o **tamanho** é do nó raiz: o Tamanho dele (300×210) é o quanto do
    cenário aparece, e a **Escala** (hoje 2, o dobro do tamanho do jogo) é o
    quanto ele é ampliado na ficha. A ficha inteira acompanha os dois.
  Os tempos do roteiro são as constantes do topo de
  `scripts/ui/demo_bumerangue.gd`.
- **A ficha** (margens, tamanho da letra — `TAM_TEXTO` —, tempos de entrada) é
  `scripts/ui/tutorial_ferramenta.gd`, desenhada como a ficha de coleta.

Para dar tutorial a outra ferramenta, escreva o campo `tutorial` dela no
catálogo (`texto` e, se quiser, a cena de `demo`). Sem o campo, a ferramenta
só ganha a ficha de coleta. O teste automático é
`tools/teste_tutorial_bumerangue.tscn`.

### A folha de átomos e moléculas

Os dois puzzles de química (foguete e maçarico) desenham as moléculas a partir
de uma folha só: `assets/UI/Computador receptor/atomos e moleculas.png`. A
ordem dos desenhos é: 1ª linha H, O, C; 2ª linha H₂, O₂, C₂; 3ª linha H₂O,
CO₂; 4ª linha C₂H₂. **Os desenhos são achados sozinhos** (ver
`scripts/ui/folha_moleculas.gd`): pode redesenhar, mudar tamanho e posição,
desde que mantenha a ordem e um espaço vazio entre um desenho e outro. O CO não
tem desenho próprio — é recortado do CO₂. O ar da fase do nitrogênio também
não: o **N₂** é o O₂ com as três cores trocadas e o **Ar** (argônio, um átomo
só) é o O com as cores trocadas; as cores estão em `RECOLORIDAS`, no mesmo
script. Se a folha ganhar um N₂ ou um Ar desenhado, é só pôr em `LINHAS`.

### As setas "POR AQUI" (estilo Metal Slug)

`SetaGuia` (`scripts/fases/seta_guia.gd`) é um `Node2D` que aponta o caminho: a
seta amarela pisca na tela com um "POR AQUI", como o "GO!" do Metal Slug. **O próprio nó é
o alvo** — arraste-o para onde a ponta deve apontar. Com o alvo na tela, a seta
fica em cima dele; fora da tela, ela gruda na borda, na direção dele, e escorrega
até ele quando a câmera chega perto. No editor aparece uma prévia da seta.

A filha `Gatilho` (ReferenceRect amarelo, só no editor) é a área em que a Cacau
precisa estar para a seta acordar. No Inspetor:

| Propriedade | O que faz |
|---|---|
| `direcao` | Para onde a seta aponta |
| `texto` | O que vai escrito ao lado (vazio = só a seta) |
| `requer_habilidade` | Ferramenta que ela já precisa ter |
| `depois_de` | Nó que já precisa ter sido feito (uma porta derretida...) |
| `ate` | Nó que, feito, aposenta a seta de vez |
| `espera` | Segundos dentro do Gatilho antes de a seta aparecer |
| `so_no_chao` | A espera só corre com os pés no chão |
| `manter_fora_do_gatilho` | Depois de acender, continua valendo fora do Gatilho |
| `raio_de_chegada` | Chegou a essa distância do alvo, a seta some |

Na Oficina elas moram em `GuiasDeCaminho/`, as duas valendo depois que a porta de
metal de cima (`Patio/PortaMetal`) derrete e até a do elevador
(`Patio/PortaMetal2`) derreter:

- `SetaDescer` — o Gatilho cobre o topo do pilar do corredor das torretas
  (y = -64, x de 2720 a 2848). Parada 2 s em cima dele, aparece a seta para
  baixo, na borda esquerda do pilar: é por ali que se cai.
- `SetaVoltarAoInicio` — o Gatilho cobre o chão lá de baixo. Logo depois da
  queda, a seta aponta para a esquerda, até a porta de metal que tranca o
  elevador do pátio; some quando a Cacau chega perto da porta.

## Os objetivos (canto superior esquerdo)

A lista de objetivos do jogo inteiro mora num arquivo só:
**`scripts/roteiro_objetivos.gd`**. Cada objetivo é um texto e uma pergunta de
"já foi feito?", que lê o que o jogo já guarda (ferramentas e células no
`Progresso`, itens no `Inventario`, portas e painéis no `EstadoMundo`). Para
mudar um texto ou a ordem, é só mexer na lista do `_init()` de lá — nenhum
objeto do cenário sabe que objetivo existe.

- O roteiro é dividido em **trilhas**, uma por ala (prólogo, Carbono,
  Nitrogênio, Enxofre e Fósforo, Torre de Lançamento). Dentro de uma fase
  aparece só a etapa atual da trilha dela; no laboratório, a da primeira trilha
  não terminada — uma ala de cada vez, na ordem do jogo: Carbono, depois
  Nitrogênio, depois Enxofre e Fósforo. O nome da trilha é o cabeçalho da lista.
- Objetivos da mesma etapa aparecem juntos (o H₂ e o O₂ do prólogo). Etapa sem
  objetivo é um portão: segura a lista vazia (é assim que nada aparece antes da
  primeira conversa com o cientista).
- Objetivo com **`aparece`** só entra quando a pergunta dele diz que sim e não
  segura a etapa: "Use a caixa arrastável" (quando a Cacau empurra a caixa ou
  pega o H₂) e o "Pegue o maçarico" adiantado (quando ela aperta E numa porta
  de metal sem o maçarico). Com **`_sub("pai", ...)`** o objetivo vira
  **subitem**: entra recuado, menor, logo abaixo do pai.
- Escreva os índices químicos direto no texto (H₂, CO₂): a lista desenha o
  número menor e abaixo da linha.
- Cumpriu: toca `sounds/check.mp3`, a caixinha fica verde com o check e o
  objetivo sai sozinho logo depois. Se isso acontecer atrás de uma fala, ficha
  de item ou puzzle, o check espera a tela fechar.
- As perguntas usam o **caminho do nó** na cena (`/root/Fase1Oficina/Patio/
  PortaMetal`). Renomeou ou moveu um nó que o roteiro consulta? Rode
  `tools/teste_objetivos.gd` (abaixo) — ele confere todos os caminhos.

## O mapa (a aba MAPA do caderno)

O **M** (△ no controle) abre o caderno, e o caderno tem duas abas no alto da
tela: **CADERNO** e **MAPA**. **Q** e **E** trocam de aba (**L1** e **R1** no
controle; clicar na aba também). O caderno abre na aba em que ficou — menos
quando chega nota nova: aí abre no CADERNO, na página dela.

O mapa é a planta do Centro de Lançamento no esquema das fases, numa folha de
papel quadriculado:

- **sala explorada**: cheia, na cor da fase (ciano a chegada, vermelho o
  laboratório, cinza o carbono, verde o nitrogênio, roxo o subsolo);
- **sala a explorar**: tracejada, com o nome escrito — já está no mapa para
  guiar, mas a Cacau nunca pisou lá;
- **você está aqui**: a sala ganha um aro, e o rosto da Cacau fica no ponto da
  sala que corresponde a onde ela está na cena (andando na cena, ela anda no
  mapa);
- **objetivo**: o losango na cor da trilha, na sala em que ele se cumpre;
- **cadeado**: a passagem que pede uma habilidade (o fosso do subsolo, sem a
  mochila);
- **fichinhas** em cima das salas: os elementos de cada fase, vazias até a Cacau
  pegá-los.

Do lado, o quadro diz onde ela está, o objetivo da vez (o mesmo da lista do
canto, com "→ sala" embaixo), os seis elementos, quanto do mapa ela já
explorou e a legenda.

Tudo o que está no mapa mora em **`scripts/planta_do_mapa.gd`** (o desenho é o
`scripts/ui/folha_do_mapa.gd`):

- **`AREAS`**: uma linha por sala — o nome, a cor e a `caixa`
  (`Rect2i(coluna, linha, largura, altura)` na grade, a coluna 0 à esquerda e a
  linha 0 em cima). Para mover uma sala, mude a caixa; o teste avisa se ela
  cair em cima de outra ou se o nome não couber.
- **`CENAS`**: cada cena e a sala em que ela fica, com o `trilho` (por onde o
  rosto anda no mapa enquanto a Cacau anda na cena). Cena nova sem trilho já
  ganha um, embaixo do nome da sala. Uma cena que atravessa mais de uma sala
  usa `trechos`: o subsolo é a ala oeste (FASE FÓSFORO) até x = 2000, o átrio
  (SUBSOLO) até x = 3400, e a ala leste (FASE ENXOFRE) daí em diante. Cada ala
  fica explorada quando a Cacau pisa nela.
- **`PASSAGENS`**: os corredores entre as salas, com `requer` para o cadeado.
- **`ONDE_FICA`**: em que cena cada objetivo do roteiro se cumpre
  (`[cena, sala]` nas cenas com trechos). Objetivo novo em
  `roteiro_objetivos.gd` precisa de uma linha aqui — o teste avisa.

Fase nova: ponha a cena em `CENAS` (sala nova: uma linha em `AREAS` e as
passagens dela) e os objetivos dela em `ONDE_FICA`. A Torre de Lançamento ainda
não tem sala: lá o mapa abre com "TORRE DE LANÇAMENTO — fora do mapa".

O mapa também existe em PNG de fundo transparente, só a planta (sem o papel, a
Cacau e o resto): **`docs/mapa.png`**, com os nomes das salas, e
**`docs/mapa_sem_nomes.png`**. Depois de mexer na planta, refaça os dois
(precisa abrir a janela — em `--headless` o PNG sai vazio):

```
godot --path . --windowed --resolution 800x450 res://tools/gerar_png_do_mapa.tscn
```

## O que a fase lembra

**A regra: morrer nunca desfaz progresso.** Morrer recarrega a cena inteira,
e cada objeto pergunta ao `EstadoMundo` (`scripts/estado_mundo.gd`) como ele
tinha ficado. O que a Cacau quebrou, desligou, abriu, derreteu, comeu ou pegou
continua assim — tenha sido antes ou depois da bandeira. Só recomeça o que é
desafio de reflexo. Sair para o laboratório e voltar encontra a fase do mesmo
jeito. Não existe save em arquivo: tudo vale enquanto o jogo estiver aberto.

Na Oficina do Carbono (fase 1):

| O quê | Depois de morrer |
|---|---|
| Caixa elétrica acertada (`AlvoFixo1`, `CaixaSerra`, `PainelA/B`) | continua arrebentada |
| Espinhos de laser e serras desligados pela caixa | continuam recolhidos |
| Torreta estragada pelo bumerangue | continua estragada, fumegando |
| Barreira dos dois painéis | continua aberta |
| Domo de vidro aberto, ferramenta pega | continuam (e o puzzle pela metade também: a etapa 1 do maçarico, o átomo de carbono) |
| Porta de metal derretida | continua no chão (vale desde o começo do corte) |
| Terminal do guincho resolvido | continua, e o elevador de carga volta a andar sozinho |
| Cesta de maçãs comida | continua vazia |
| Rádio do Dr. Chico | não chama de novo |
| Objetivos cumpridos | continuam cumpridos |
| A bandeira tocada | continua tremulando (é o ponto de retorno) |

Recomeçam de propósito, a cada vida:

- **a vida da Cacau**, cheia;
- **plataformas que caem, plataforma móvel, plataforma de viagem e bolas
  quicantes** — é o desafio do trecho;
- **serras e espinhos SEM caixa elétrica** (`ArmadilhasFixas`), que nunca
  desligam;
- **a caixa empurrável**, que volta para onde estava quando ela entrou na fase
  (ver abaixo: é o que desencalha uma caixa empurrada para onde não devia).

E só até ela sair da cena: **os morcegos dos corredores**. Enquanto a Cacau
não sai do corredor, o morcego morto continua morto e o ferido continua
ferido, mesmo que ela morra e a cena recarregue; na visita seguinte o bando
está inteiro de novo (ver "Os morcegos dos corredores").

No resto do jogo, o mesmo vale para:

- ferramentas pegas e gaiolas abertas; células do painel;
- painéis do portão, barreira, caixa das serras (serras recolhidas) e o
  terminal do guincho (o elevador volta a funcionar sozinho);
- **toras de madeira recolhidas** (não reaparecem; a lenha fica no inventário);
- **a retorta**: quantas toras estão dentro do forno, o forno pegando fogo à
  espera da porta (e a porta, se já foi apanhada, segue na mochila), o carvão
  esperando para ser retirado e, claro, a célula C já retirada. Se a queima
  der errado, as toras voltam ao depósito e continuam lá mesmo saindo e
  voltando;
- **a caixa empurrável**: fica onde estava quando você **saiu pela porta**.
  Morrer não conta — a fase recarrega com a caixa na posição da última saída,
  o que desencalha uma caixa empurrada para onde não devia.

**Nos componentes, lembrar é o padrão** — uma caixa ou uma torreta nova,
arrastada para a cena ou duplicada com `Ctrl+D`, já lembra sozinha:

- **alvo de bumerangue e caixa elétrica** — `Persistir` vem ligado. O alvo de
  trava (`Permanece Ativo`) volta ligado; o de janela (como o `AlvoFixo1`, de
  2 s) volta desligado, porque o tempo dele acabou, mas a caixa continua com a
  tampa arrebentada;
- **espinhos de laser e serra** — com `Desligar Para Sempre` (o padrão), a
  própria armadilha anota que foi desligada. Ela não depende de a caixa
  lembrar, nem da ordem dos dois nós na cena. Com `Desligar Para Sempre`
  desligado ela é uma passagem cronometrada, que recomeça de pé a cada vida;
- **torreta** — `Persistir` vem ligado (só importa nas de `Quebravel` ligado).

Desligue `Persistir` só num objeto que deve mesmo recomeçar a cada morte.

Para um objeto novo lembrar do estado: `EstadoMundo.marcar_feito(self)` /
`ja_feito(self)` para "já aconteceu", ou `guardar(self, "marca", valor)` /
`ler(self, "marca", padrao)` para valores. Se só deve anotar na saída por
porta, entre no grupo `EstadoMundo.GRUPO_SALVAR_AO_SAIR` e tenha um
`salvar_ao_sair()`. Para o que deve durar só enquanto ela não sai da cena (um
inimigo que volta a cada visita), `guardar_na_visita(self, "marca", valor)` /
`ler_da_visita(self, "marca", padrao)`. A chave de tudo isso é o **caminho do
nó** na cena: renomear ou mudar de pai um nó que já foi resolvido faz o jogo
esquecê-lo (só importa com o jogo aberto, já que não há save).

O teste que joga a fase 1, mata a Cacau e confere a tabela acima, linha por
linha (mais os morcegos do corredor):

```
godot --headless --fixed-fps 60 --path . res://tools/teste_estado_da_fase1.tscn
```

## A fase 2: a Torre de Gases (o nitrogênio)

A fase do nitrogênio é uma **rua com três prédios**, e cada prédio é uma cena.
Da esquerda para a direita:

| Cena | O que é |
|---|---|
| `fase2_torre.tscn` | A **rua**: o prédio escuro do compressor (com o portão de rolamento), a torre de tijolo e o prédio verde da destilação |
| `fase2_sala_compressor.tscn` | A **sala do compressor**: o mesmo prédio escuro por dentro, com o compressor de ar e o puzzle do gás |
| `fase2_torre_interior.tscn` | A **torre por dentro**: oito andares de subida até a porta do telhado |
| `fase2_telhado.tscn` | O **telhado**: o cilindro de amostra, num chão de andar para a frente e para trás (como Final Fight) |
| `fase2_sala_destilacao.tscn` | A **sala de destilação**: montada igual à sala do compressor, com a mochila de N₂, a coluna e o cilindro verde de nitrogênio |

**O caminho**, em ordem: pegar a **mochila de N₂** na sala de destilação (ela
é que alcança o primeiro degrau da torre) → subir a **torre** até o telhado e
pegar o **cilindro de amostra vazio** → descer pela **escada** → no
**compressor**, apertar e gelar o ar até virar líquido dentro do cilindro →
**correr** com a amostra gelada até a coluna antes que ela esquente e estoure →
**destilar** o ar → pegar o **cilindro verde de N₂** → levar ao painel CHONPS,
no laboratório. A lista de objetivos (`scripts/roteiro_objetivos.gd`, trilha
`nitrogenio`) acompanha passo a passo.

Quem guarda o que já foi feito entre as salas é a
`scripts/fases/missao_nitrogenio.gd` (cilindro preso no compressor, a amostra
na mão, a amostra na coluna, a subida da torre...): o mesmo truque do
`EstadoMundo`, com `static var`, então sair de uma sala e voltar encontra tudo
como estava. Fechar o jogo esquece. As portas se acham pelas
tags (`tag_aqui`/`tag_destino`), como no resto do jogo — o
`tools/teste_fase2.tscn` confere todos os pares.

### A rua

- `PortaTorre`, `PortaDestilacao` — as portas da torre e da destilação
  (`componentes/porta_predio.tscn`, a mesma nas outras portas da fase 2: o
  vão escuro de moldura verde do `Buildings.png`, montado no
  `assets/porta/porta predio.png` — 4×6 tiles, desenhado em escala 2. Ela não
  tem folha nem som: a Cacau entra e sai do escuro com a animação de sempre).
  Arraste pelo meio;
- `PortaCompressor` — o **portão de rolamento** do prédio escuro, o primeiro
  da rua (x = 512), que leva à sala do compressor
  (`componentes/porta_rolamento.tscn`, ver "O portão de rolamento", abaixo).
  Na volta da sala a Cacau sai andando para a direita, o lado da destilação.
  Arraste pelo meio: o pé do portão fica 116 px abaixo do nó, e o painel de
  luzes vai junto;
- o **elevador de carga** (do telhado para a rua), visto de lado. Ele é
  **pintado** no `Cenario 2`: a plataforma com a grade dentro da
  `Area Do Elevador` (Inspector do nó raiz, `Fase2Torre`; hoje x 1792 a 1888,
  y 128 a 192, pintada no meio do caminho só para dar para ver) e, embaixo
  dela até o chão, o **tubo** que a empurra (colunas 56 e 58). No jogo, a
  plataforma e o tubo saem do `Cenario 2` e viram os nós `ElevadorDeCarga` e
  `TuboDoElevador` (`scripts/fases/bloco_de_tiles.gd`). Parada, a plataforma
  fica com a base no `Chao Do Elevador` (y = 512) e dá para pisar nela (o piso
  fica `Altura Do Piso`, 32 px, abaixo do topo dela). Quem desce do telhado
  chega em cima dela lá no alto (`Topo Do Percurso`, y = −96, acima do que a
  câmera mostra) e desce até o chão em `Duracao Da Descida` (3 s). O tubo vai
  até a base da plataforma — o pintado é repetido para cima — e some por cima
  conforme ela desce, como se recolhesse. Por enquanto ele só desce: pela rua
  não se sobe;
- `Postes` — os seis postes da rua (um de cada lado do prédio do compressor,
  um antes da torre, um antes da destilação e dois no terreno vazio do fim da
  rua). Cada um é a cena
  `scenes/luz/poste_de_luz.tscn`, com a luz dentro: arraste pelo pé, que fica
  no chão (y = 512). Para pôr mais um, arraste a cena para dentro de `Postes`.
  No Inspector, `altura` (em tiles) e `espelhado` (braço para a esquerda);
- `Cenario` / `Cenario/Cenario 2` — os prédios, no tileset da cidade
  (`Buildings.png`): o prédio escuro do compressor (colunas 6 a 26, com o cano
  na 27 e a caçamba até a 29), no lugar do antigo prédio de concreto (colunas
  9 a 27), que saiu da rua; a torre de
  tijolo (40 a 61, subindo até a fileira -70, bem acima do que a câmera
  alcança) com o poço do elevador (os trilhos nas colunas 55 e 59), o prédio
  verde da destilação (75 a 95). Os três ficam perto: uns 320 px de rua entre
  a caçamba e a torre, e uns 400 px entre a torre e a destilação, com o
  pilarete e o banco (colunas 63 a 67) no meio. Depois da destilação vem a
  garagem (colunas 97 a 108) e um terreno vazio (colunas 109 a 169). Para
  mudar a distância, mova juntos os tiles do prédio (`Cenario` e `Cenario 2`),
  a porta dele e o poste do vão. O portão e o painel do
  prédio do compressor não são pintados: são a `PortaCompressor`, animada, no
  vão da fachada (colunas 12 a 19). A rua vai até x = 5504 (`LimitesDaCamera` e `ParedeDireita`);
  o que está pintado depois disso (a casa marrom, o banco e a placa, da coluna
  173 em diante) fica fora da área jogável;
- `Lajes` — as lajes em que dá para subir, com colisão (tileset das fases):
  as duas faixas de cornija do prédio do compressor, a do meio (fileira 9) e
  a do telhado (fileira 2), na versão **vazada** (ver "Pintar o cenário"). Ficam
  numa camada própria porque o `Terreno` da rua é só o chão de grama. As faixas
  giradas das quinas da torre e dos trilhos do elevador continuam no
  `Cenario`, sem colisão — senão a torre virava escada por fora;
- o resto (`BG`, `Atmosfera`, `PostesDeLuz`, `Terreno`, `Paredes`,
  `PassagemCorredor`) é o palco de antes: ver "O corredor da torre", abaixo.

**Com a amostra gelada na mão** a rua só deixa ir para a destilação (ou voltar
ao compressor): a saída para o corredor e a porta da torre barram,
e a Cacau diz que não dá tempo (`cacau_amostra_pressa`). Quem barra é o
próprio `fase2_torre.gd`.

### O portão de rolamento (a entrada do compressor)

`componentes/porta_rolamento.tscn` é a porta da oficina (`porta_simulador.gd`)
com o `assets/fase nitrogenio/porta de rolamento .png`: 11 quadros de 146x98
(com 1 px transparente em volta do desenho), em escala 1,8. O quadro 0 é o
portão fechado, do 1 ao 9 ele sobe e no 10 a trava lá de cima fecha. O vão
aberto é transparente: quem pinta o escuro de dentro é o `FundoDoVao`, atrás
do `SpritePorta`. A mesma cena é a porta da rua e a porta da sala por dentro.

**O painel ao lado** (`Painel`, `scripts/fases/painel_do_portao.gd`) é o tile
11,6 do `Buildings.png`, com quatro quadradinhos vermelhos. Enquanto o portão
sobe eles ficam verdes, um por um de cima para baixo, e o último acende na
trava; no baque do portão fechando voltam todos ao vermelho. O verde é o
quadradinho do painel vizinho na mesma folha (tile 12,6): cada `Luz` é um
recorte dele, posto em cima de um vermelho. Em que quadro do abrindo cada luz
acende fica em `quadros_que_acendem` (hoje 0, 4, 7 e 10).

**O som manda no tempo.** Os dois sons saem da gravação
`sounds/porta de Rolamento.mp3` (6,7 s, que fica lá, intacta):

| Arquivo | O que é |
|---|---|
| `sounds/porta_rolamento_abrindo.wav` | 2,39 s: a gravação a partir de 3,939 s (ficaram de fora o quase 1 s de silêncio e o começo do rolo). O rolo, até o silêncio antes do clunk (5,700 s), toca 25% mais rápido sem mudar o tom (rubberband); o clunk e o fim tocam como foram gravados, emendados numa fusão de 30 ms nesse silêncio. Fade-in de 0,16 s e fade-out nos últimos 0,35 s. O rolo morre aos poucos e a trava faz *clunk* em 1,466 s (e de novo em 1,575 s) |
| `sounds/porta_rolamento_fechando.wav` | 1,65 s: o pedaço do rolo logo antes desse (3,174 s a 3,900 s), emendado numa fusão de 30 ms no instante antes do clunk: o rolo para de uma vez quando o portão bate no chão (0,727 s) |

Os dois têm o mesmo ganho (pico em -1,9 dBFS, como os sons gerados do
compressor) e são mono, 16 bits, 44,1 kHz. Para refazer (ffmpeg 8.1):

```
ffmpeg -i "sounds/porta de Rolamento.mp3" -filter_complex "[0:a]asplit=2[a][b];[a]atrim=start_sample=173694:end_sample=251359,asetpts=PTS-STARTPTS,rubberband=tempo=1.25,afade=t=in:st=0:d=0.16:curve=qsin[ra];[b]atrim=start_sample=251359,asetpts=PTS-STARTPTS[rb];[ra][rb]acrossfade=ns=1323:c1=qsin:c2=qsin,afade=t=out:st=2.042608:d=0.35:curve=qsin,volume=-1.6589dB,aresample=osf=s16:dither_method=triangular[out]" -map "[out]" -ac 1 -ar 44100 -c:a pcm_s16le -map_metadata -1 -fflags +bitexact -flags:a +bitexact sounds/porta_rolamento_abrindo.wav

ffmpeg -i "sounds/porta de Rolamento.mp3" -filter_complex "[0:a]asplit=2[a][b];[a]atrim=start_sample=139968:end_sample=171985,asetpts=PTS-STARTPTS,afade=t=in:st=0:d=0.005:curve=qsin[r];[b]atrim=start_sample=253873,asetpts=PTS-STARTPTS[k];[r][k]acrossfade=ns=1323:c1=qsin:c2=qsin,afade=t=out:st=1.30272:d=0.35:curve=qsin,volume=-1.6589dB,aresample=osf=s16:dither_method=triangular[out]" -map "[out]" -ac 1 -ar 44100 -c:a pcm_s16le -map_metadata -1 -fflags +bitexact -flags:a +bitexact sounds/porta_rolamento_fechando.wav
```

**Os quadros seguem o som.** Cada quadro do `SpritePorta` tem a sua duração (a
animação roda a 10 quadros por segundo: duração 1,0 = 0,1 s):

- **abrindo** (1,59 s): o quadro 0 segura 0,064 s enquanto o som cresce; do 1
  ao 9 o portão sobe desacelerando, como o rolo morrendo (cada quadro um pouco
  mais longo que o anterior, de 0,10 s a 0,21 s); o 9, aberto, espera o motor
  parar; o 10, a trava, entra no clunk (1,466 s) e a Cacau entra logo depois
  do segundo — o resto do som toca enquanto ela anda;
- **fechando** (0,90 s): o 10 solta a trava no estalo do começo, o portão desce
  em velocidade constante (0,075 s por quadro) e o 0, fechado, entra na batida
  no chão (0,727 s).

Cortou o som de outro jeito? O `tools/teste_porta_rolamento.tscn` lê o .wav,
acha o clunk e mostra onde caíram o quadro da trava e o da porta fechada: é só
ajustar as durações até bater. O som de fechar já vem cortado no ponto certo,
por isso esta porta tem `inicio_som_fechando` = 0 (as outras pulam o meio
segundo de silêncio do começo do `somPorta_fechando.wav`).

**Ele não fecha na ida.** O portão tem `fica_aberta_na_viagem` ligado: ao
entrar, ele abre, a Cacau entra e a tela já apaga, com ele aberto. Na outra
cena o portão de lá aparece aberto (o último quadro do `abrindo`, com o painel
todo verde), ela sai andando e só então ele fecha. As outras portas continuam
fechando antes de trocar de cena.

### A sala do compressor e o puzzle do gás

A sala é o prédio escuro da rua **por dentro**, com a mesma arte de fora (o
`Buildings.png`), para entrar e sair sem trocar de mundo:

- `Terreno` — a estrutura em corte, no tileset das fases (fonte 15, a do
  `Buildings.png`): a faixa de cornija sólida no teto (fileira -2) e no piso
  (fileira 16), a faixa girada nas paredes (colunas 0 e 42), a base escura
  (4,4) por fora delas e, na fileira 7, a **laje do meio**, de parede a parede,
  na versão vazada (ver "Pintar o cenário"). A Cacau sobe nela pulando, e
  desce com S + espaço. O som dos passos sai do metadado `superficie` da
  camada (`concreto`);
- `Fundo` — a parede verde: o topo escuro (8,0) embaixo de cada faixa, a
  parede (8,1) e as quinas (7,x) nas pontas;
- `Cenario` — as luminárias, embaixo do teto e da laje do meio (tileset da
  cidade);
- `Janelas` — as janelas, no mesmo tileset, numa camada só delas em escala 3
  (uma vez e meia o resto da sala, para não sumirem na parede alta);
- `LimitesDaCamera` — de x = 0 a 1376 (as bordas de fora das duas paredes) e
  de y = 64 a 576, com o `zoom_da_camera` 1,7578125 da Cacau;
- `PortaRua` — o mesmo portão de rolamento, com o painel, par da
  `PortaCompressor`, em escala 1,25 (maior que isso encosta na luminária). Os
  filhos dele estão editáveis na cena: o `PontoDeSaida` foi acertado para ela
  sair no chão, e o `IconeInteragir` (o botão E/□), para o tamanho de sempre,
  na frente do topo do portão; a `PlacaPV` fica embaixo da faixa do meio.

A sala de destilação é esta mesma montagem, tile por tile (ver "A sala de
destilação"): mexendo nas camadas ou na câmera de uma, mexa na outra igual.

`CompressorDeAr` (`componentes/compressor_de_ar.tscn`) é a máquina do mapa:

- **sem o cilindro**, o E aproxima a câmera da máquina e a Cacau comenta que
  dá para pôr um cilindro ali;
- **com o cilindro**, ele é acoplado e abre o puzzle
  (`scenes/puzzle_compressor.tscn`, `scripts/puzzle_compressor.gd`): uma
  câmara com o ar da sala em cima do cilindro, o **êmbolo** que diminui o
  volume, o **resfriador** (o termômetro) e o **manômetro** no gargalo. O
  cilindro aguenta 4 atm: apertar sem resfriar estoura (na temperatura da
  sala, todo o ar no cilindro daria 8 atm). Resfriando, a pressão cai
  (P·V = n·R·T) e, frio o bastante, o ar começa a **virar líquido** e a
  pressão para de subir. Com todo o ar no cilindro e pelo menos 20% líquido, a
  válvula fecha e a Cacau sai correndo com a amostra.

A física é de verdade, e mora toda em `scripts/laboratorio/`:
`gas_fechado.gd` (gás ideal, trabalho do êmbolo, troca de calor, a condensação
do ar com as pressões de vapor do N₂, O₂ e Ar) e `maquina_de_compressao.gd`
(os números da máquina: volumes, a pressão de ruptura, o resfriador). O
desenho do aparelho é `scripts/ui/camara_de_compressao.gd`. A tela tem o
`modo_historia` desligável, para virar atividade do Laboratório depois.

**Estourou?** A explosão (`scripts/fx/explosao_do_cilindro.gd`) e o fim de
jogo (`scripts/ui/tela_game_over.gd`). Tentar de novo devolve o cilindro vazio
preso no compressor, com a máquina do começo.

**A corrida.** Fechada a válvula, o relógio da amostra
(`scripts/ui/contagem_da_amostra.gd`) aparece no alto da tela e o cilindro vai
nas costas da Cacau. A amostra **esquenta** de verdade (o calor da sala entra,
o líquido ferve, a pressão sobe): quanto mais fria e mais líquida ela saiu do
compressor, mais tempo aguenta. O relógio não anda com fala ou tela aberta.
Chegou a 4 atm, estoura nas costas dela: fim de jogo.

### A sala de destilação

A sala é **a sala do compressor, tile por tile**: as camadas `Terreno`,
`Fundo`, `Cenario` e `Janelas` têm os mesmos tiles nas mesmas posições (a
laje vazada do meio, a parede verde, as luminárias, as janelas em escala 3), e
a câmera é a mesma (`LimitesDaCamera` e o `zoom_da_camera` da Cacau). Mudou uma
sala, mude a outra igual: o `teste_fase2` compara as duas célula por célula. O
que é só desta sala são os objetos:

- `PortaRua` — a `porta_predio`, par da `PortaDestilacao` da rua, no térreo,
  à esquerda;
- `Mochila` — a mochila de N₂ num pedestal (um `PickupHabilidade` com
  `habilidade = "mochila"`; a arte sai do catálogo de ferramentas), entre a
  porta e a primeira janela do térreo;
- `Destilador` — a coluna de destilação, no vão entre as duas primeiras
  janelas: alta como é, passa na frente da laje do meio, e esse é o vão em que
  ela não cobre janela nem luminária nos dois andares. Ver a seção dela, logo
  abaixo. Sem a
  amostra, o E abre a explicação do Dr. Chico; **com a amostra**, o E recebe o
  cilindro, o relógio para e abre a tela em que a Cacau destila o ar
  (`scenes/puzzle_destilacao.tscn`, script `scripts/puzzle_destilacao.gd`): o
  simulador do Laboratório só com o ar. Ela esquenta o fundo até o vapor levar
  quase todo o nitrogênio para o topo — pelo menos 75% dele
  (`RECUPERACAO_MINIMA`), com pelo menos 80% de pureza (`PUREZA_MINIMA`) — e o
  oxigênio ficar sendo a maioria no fundo; aí retira o nitrogênio do topo.
  Com a amostra do jogo, isso acontece com o fundo entre -190 e -183 °C (topo
  com 91 a 95% de N₂: nunca 100%). Acima dos -183 °C do oxigênio o fundo
  ferve até secar e suja o topo, e só RECOMEÇAR desfaz;
- `CilindroDeNitrogenio` — o cilindro **verde** de N₂ (a amostra do elemento
  N). Fica escondido até a destilação acabar e salta da coluna para o lugar
  dele, depois da segunda janela; o campo `destilador` aponta para ela;
- `PlacaEbulicao` (em `Enfeites`) — os pontos de ebulição, na parede livre do
  térreo, à direita.

### A torre por dentro

Oito andares empilhados, de 20 fileiras cada (34 células de largura): o piso do
andar k tem o topo na fileira `16 - 20·k`. A laje entre dois andares tem um
**buraco**, e passar por ele é chegar ao andar de cima. Os buracos alternam de
lado — cair do fim de um andar não devolve ao andar de baixo.

| Andar | Tema |
|---|---|
| 0, térreo | A porta da rua e o **primeiro degrau**, a 8 células do chão: o pulo duplo não chega, só pulo + jato da mochila. Sem a mochila, embaixo dele (`AvisoDegrauAlto`) a Cacau comenta que é alto demais |
| 1 | Piso inteiro de **espinhos de laser**, vigas em escada por cima |
| 2 | A chaminé de **serras**, entre um pilar pendurado no teto e a parede. A `CaixaDasSerras`, no alto da esquerda, alimenta as serras da chaminé: o bumerangue nela as recolhe (as do piso continuam) |
| 3 | **Plataformas que caem** (as laranja) sobre laser e as **válvulas de purga**: encostar recarrega o jato no ar |
| 4 | **Morcegos** nos tetos; uma cesta de maçãs |
| 5 | Três **torretas** quebráveis (o bumerangue desarma cada uma de uma vez) |
| 6 | **Chamas** (o jato de N₂ apaga: nitrogênio não alimenta o fogo) e o **vapor** que empurra para a direita. O `Ventilador` é um alvo: acertou, o vapor para |
| 7 | O **laser** a meia altura, a **plataforma móvel** por baixo de uma fileira de espinhos (de pé ela passa; pulando, não) e a portinha do telhado |

Cada andar tem uma bandeira de checkpoint perto de onde se chega. A torre não
tem placas escritas.

**Para mexer na geometria** (camada `Terreno`, `tileset_fases`):

- as **paredes** da esquerda (colunas -6 a 1) e da direita (32 a 39) são as
  quinas da torre vista de fora, na `fase2_torre`: o tijolo do `Buildings.png`
  (fonte 15). Na face de dentro (colunas 1 e 32) fica a faixa escura girada
  (o tile `(1, 0)` transposto e espelhado), que é a única com colisão; do lado
  de fora dela, só tijolo (`(1..3, 1..3)`), espelhado na vertical como na
  fachada. O tijolo sombreado, como na rua, fica DENTRO do prédio, colado na
  faixa: é a primeira coluna da camada `Fundo` de cada lado (colunas 2 e 31,
  o tile `(0, 1..3)`; a da direita espelhada). As lajes encostam na faixa;
- a pedra do laboratório (a moldura de 8 × 8 do `level_tileset`) é o chão, o
  teto e os patamares; as **vigas** de mão única são os tiles
  `(10..15, 0)` (a fileira de baixo, `(10..15, 1)`, é só o corpo, sem
  colisão); o **bloquinho** de 2 × 2 é `(10..11, 2..3)`;
- as **plataformas que caem** são os tiles laranja da fonte 0
  (`Plataformas.png`): o retângulo `PlataformasQueCaem` cobre a torre inteira,
  então é só pintar;
- **as contas da Cacau**: o pulo sobe 94 px (2 células folgado), o pulo duplo
  188 (5 células), pulo + jato ~398. Degrau de **3 células** (96 px) não
  existe na torre: parece dar num pulo e não dá. Embaixo de laje, para ficar
  de pé, 3 células livres;
- `tools/teste_subida_torre.tscn` sobe a torre inteira, salto por salto, com
  as teclas de verdade (sem as armadilhas): rode depois de mexer nos andares.

**Os puzzles da torre.** Todo nó cujo nome começa com `Puzzle` junta ALVOS (os
`AlvoBumerangue` filhos dele — uma `CaixaEletrica` também é um) e EFEITOS (os
outros filhos): com todos os alvos acesos, cada `CorrenteVapor` desliga, cada
`Barreira` se abre e cada `BlocoAlternavel` some (um alvo de janela que apaga
traz o bloco de volta). Para um puzzle novo, é só montar outro grupo
`Puzzle...` (quem liga é o `fase2_torre_interior.gd`). A arte do alvo, da
válvula e da comporta é `assets/fase nitrogenio/alvo.png`, `alvo aceso.png`,
`valvula de purga.png` e `comporta.png`.

A câmera é a `ZonaDaTorre` (uma `ZonaCamera`): o meio fica travado na
horizontal e ela só sobe quando a Cacau pousa. A luz é o perfil
`assets/luz/torre.tres` (as salas usam `fase2_interior.tres`); as luminárias
são as pontas do poste do `Props-01` pintadas embaixo de cada laje — o
`PostesDeLuz` acende sozinho.

**As janelas** (camada `Janelas`, tileset da cidade) estão em escala 3, do
tamanho das das salas do compressor e da destilação: 96 × 144 px, em células
de 48 px. Um andar tem 640 px, que não é múltiplo de 48, então as janelas não
ficam exatamente na mesma altura em todos os andares (variam até 32 px). Três
por andar, logo abaixo das luminárias. Pintando uma janela, deixe-a fora das
portas: o `teste_fase2` confere.

### O telhado

**Aqui se anda para a frente e para trás**, como em Final Fight e Tartarugas
Ninja: ←/→ andam para os lados e ↑/↓ andam para o fundo e para a frente da
laje. Quem liga isso é o nó `FaixaDoChao` (ver abaixo); qualquer fase que
ganhar um nó com esse nome passa a andar assim (`fase_base.gd` e "ANDAR NA
FAIXA" no `player.gd`).

- `FaixaDoChao` — um `ReferenceRect` (o retângulo azul-claro, que só aparece
  no editor): é por onde os **pés** da Cacau andam (a base da cápsula de
  colisão). Hoje vai de y = 521 (logo abaixo da grade do fundo) a y = 570 (a
  base da grade da frente), de ponta a ponta da laje (x = 0 a 1408). Arraste e
  estique ele para mudar a faixa. As bordas seguram a Cacau dos quatro lados —
  os tiles e as `Paredes` não a seguram mais aqui. O pulo sobe e cai de volta
  na mesma linha;
- `Player` — aqui com `scale` 0,7 (a Cacau menor) e `Zoom Da Camera` 2 (a
  câmera mais perto; o padrão é 1,5). As velocidades na faixa ficam no
  Inspector dele: `Velocidade Na Faixa` (para os lados, 250) e
  `Velocidade De Profundidade` (para o fundo e para a frente, 90 — bem mais
  devagar, para o chão parecer mais fundo);
- **o muro na frente dela** — de y = 564 para baixo (a guia horizontal do
  editor) é a parede da frente: ali NADA do sprite da Cacau é desenhado. A
  faixa vai até 570, então na beirada os pés passam por trás do muro, sem
  vazar por cima da grade nem dos tijolos. O valor é o `Topo Do Muro Da
  Frente`, no Inspector do nó raiz (`Fase2Telhado`); quem esconde é o shader
  `shaders/corte_abaixo.gdshader`, posto no sprite dela
  (`esconder_abaixo_de`, no `player.gd`). Ele fica no script, e não num nó da
  cena, de propósito: com a cena aberta no editor, um nó novo gravado de fora
  some quando o editor salva a versão dele;
- as camadas, de trás para a frente: `Cenario` (a casinha, a grade do fundo, o
  poço, tileset da cidade), `Terreno` (o chão da laje e o telhado da casinha,
  tileset das fases), a Cacau, e as duas camadas da frente, ambas com
  `z_index` 10 (ela está no 2) e sem colisão:
  - `Frente` — a grade da frente da laje (tileset da cidade). O que for
    pintado nela tampa a personagem. Para pintar com outro tileset, troque o
    `Tile Set` dela no Inspector;
  - `MuroDaFrente` — o muro de tijolos embaixo da grade da frente (tileset das
    fases, na mesma grade do `Terreno`, de onde os tijolos saíram);
- `PortaEscada` — a portinha da casinha da escada (a `porta_predio` em 75%),
  o par da `PortaTelhado` do último andar. A Cacau sai dela já dentro da faixa
  (o `PontoDeSaida` fica com os pés em y = 530) e só alcança o E dela andando
  para o fundo, perto da casinha. O telhado da casinha (a faixa de cornija na
  fileira 9) continua no `Terreno`, mas andando na faixa não dá para subir nele;
- `CilindroDeAr` — o cilindro de amostra vazio
  (`componentes/cilindro_do_telhado.tscn`): o E pega, a ficha sobe e a Cacau
  diz para onde ele vai. Não volta mais;
- o **elevador de carga** (do telhado para a rua). A cabine é **pintada**:
  tudo, de qualquer camada de tile, dentro da `Area Do Elevador` (Inspector do
  nó raiz, `Fase2Telhado`; hoje x 1024 a 1120, y 480 a 608). Vale o **centro**
  de cada tile, então a grade da `Frente`, que está 3 px para a direita, entra
  certinha. No jogo, esses tiles saem das camadas e viram o nó
  `ElevadorDeCarga` (`scripts/fases/bloco_de_tiles.gd`), cada camada com o
  z_index dela (a grade continua na frente da Cacau). Com a Cacau em cima da
  cabine, aparece o E: ela anda até o meio e a cabine afunda levando ela, com
  a câmera parada. As duas somem na borda de baixo da área (y = 608, o fundo
  do poço), e o corte do sprite dela desce junto com a cabine. O lugar fica
  **vazio**: o que for pintado ali, numa camada, mas fora da área (um fundo),
  aparece. No fim a tela apaga e a rua abre com ela descendo na plataforma.
  `Duracao Da Descida` (1,8 s) é o tempo da cabine afundando;
- `Paredes` — duas paredes invisíveis (`ParedeEsquerda` em x = 0,
  `ParedeDireita` em x = 1408, nas bordas da câmera, bem altas). Andando na
  faixa quem segura é a `FaixaDoChao`; elas ficam para o modo dev voando;
- `BG` — o mesmo céu da rua, com a serra e a mata bem mais baixas no
  horizonte (lá de cima sobra céu).

Chegar ao telhado marca a subida e, na primeira vez, a Cacau comenta
(`cacau_torre_telhado`).

**Sem o cilindro, não se desce.** Enquanto ele estiver no suporte, a
`PortaEscada` fica travada: o E na porta dá a fala `cacau_pegar_cilindro_antes`
("Eu preciso pegar o cilindro antes!"). O E no elevador dá a mesma fala, e a
cabine não sai do lugar. Pegou, ela volta a descer. Quem trava é o
`fase2_telhado.gd` (o export `fala_sem_cilindro` escolhe a fala); no modo dev
a porta e o elevador ficam livres.

**As falas novas** (todas em `timelines/`):
`cacau_compressor_sem_cilindro`, `cientista_compressor`,
`cacau_compressor_concluido`, `cacau_amostra_pressa`, `cacau_degrau_alto`,
`cacau_torre_telhado`, `cacau_cilindro_pego`, `cacau_elevador_parado`,
`cacau_elevador_la_embaixo`, `cacau_pegar_cilindro_antes`,
`cientista_destilacao` e `cacau_tem_nitrogenio`.

**Atalhos de teste.** A tecla **L** deixa pronta na hora a amostra do
compressor e a separação da destilação; a **N** equipa a mochila.

## A coluna de destilação (fase 2)

Na sala de destilação da fase 2 fica a coluna de destilação
(`scenes/fases/componentes/destilador.tscn`). Chegando perto, o botão (E, ou □
de controle) acende na frente dela e a coluna ganha um contorno branco.
Apertando, o jogo para e **o Dr. Chico explica, pelo rádio, como ela separa o
ar**: a coluna sai do mapa, vem para a esquerda da tela, uma faixa de luz desce
por ela e o aço vira o desenho preto de raio X.

**Como uma coluna dessas funciona** (é o que o desenho mostra — e não é
encenado: é a conta do simulador do Laboratório, ver `docs/LABORATORIO.md`):

- cada substância tem um **ponto de ebulição**: o nitrogênio -196 °C, o
  argônio -186 °C, o oxigênio -183 °C. Mas **evaporar** elas evaporam abaixo
  dele: as moléculas mais agitadas da superfície escapam em qualquer
  temperatura — é assim que a roupa seca no varal, sem ferver. **Ferver** é o
  vapor se formar dentro do líquido, em bolhas: é o que acontece no ponto de
  ebulição;
- uma **mistura** ferve numa temperatura entre os pontos de ebulição das
  substâncias dela: o ar líquido, a uns -194 °C. E o vapor que sai tem de
  tudo: é rico em nitrogênio, o que evapora mais fácil, mas leva oxigênio e
  argônio junto — eles evaporam ali uns 10 °C abaixo do ponto de ebulição
  deles;
- o calor não vem de máquina nenhuma: a -200 °C o ar líquido é muito mais
  frio que tudo em volta, e o **calor do ambiente** vai entrando nele sozinho
  (as setinhas laranja embaixo do piso). Quem tira calor é o **resfriador**, a
  serpentina dentro da cúpula. Por isso o fundo, onde está o líquido, é o
  lugar menos frio e o topo o mais frio (-196 °C), e cada andar do meio fica
  entre um e outro. É a régua colorida colada na coluna;
- fervendo, o fundo não esquenta: o calor vai todo para virar vapor (a água
  na panela não passa de 100 °C). Mas, como sai mais nitrogênio, o líquido que
  fica vai ficando mais rico em oxigênio e ferve cada vez mais quente;
- o vapor sobe e esfria. Numa bandeja ele condensa (a tampa da panela: o vapor
  encosta no frio e vira gota) ou passa; a bandeja quente demais para o
  líquido dela ferve de novo, e a que enche transborda para a de baixo. Cada
  vez que condensa e evapora, o vapor fica mais rico em nitrogênio: é a
  destilação **fracionada**;
- resultado: o topo fica rico em nitrogênio (95%), o fundo rico em oxigênio
  (67%, com o argônio e um pouco de nitrogênio) e as bandejas do meio com
  misturas. **Nada sai 100% puro** — numa coluna de verdade também não; com
  muitas bandejas, chega-se perto.

O que acontece na tela, fala por fala (o nome de cada marca vem antes):

1. `raio_x` — a coluna vira o desenho de raio X;
2. `ar` — o ar entra no fundo já **líquido**, a -200 °C, e aparecem as fichas
   do que ele é feito: N₂ 78%, Ar 1%, O₂ 21% (na ordem dos andares da
   coluna);
3. `ebulicao` — cada ficha mostra o **ponto de ebulição** da substância;
4. `evaporar` — ainda a -200 °C, nada ferve, mas moléculas da superfície
   pulam para fora e voltam: a **evaporação** abaixo do ponto de ebulição;
5. `varal` — a fala compara com a roupa no varal; o desenho segue igual;
6. `ferver` — o calor do ambiente leva o fundo até o ponto de ebulição da
   mistura (a plaquinha dele vai contando) e ela **ferve**: o vapor sobe pelas
   fendas. A ficha de cada substância que começa a evaporar dá um pulo — a do
   oxigênio também, muito abaixo dos -183 °C dele;
7. `vapor` — a fala diz do que o vapor é feito; o desenho segue;
8. `esfriar` — um sopro de geada no resfriador: lá em cima o vapor **vira
   líquido de novo**, quase todo nitrogênio;
9. `separar` — o fundo segue até -188 °C e a coluna assenta; a plaquinha de
   cada andar toma a cor de quem é a maioria ali;
10. `pureza` — aparecem as etiquetas do topo e do fundo ("95% NITROGÊNIO",
    "67% OXIGÊNIO"): ricos, mas não puros;
11. `fim` — o título vira **DESTILAÇÃO FRACIONADA**.

Os termos: **evaporação** é o líquido virando gás pela superfície, em qualquer
temperatura; **ebulição** é ele fervendo, com bolhas, no ponto de ebulição (o
da mistura fica entre os das substâncias); gás virando líquido é
**condensação**. O que separa as substâncias é uma evaporar mais fácil que a
outra (é isso que o ponto de ebulição resume; o de fusão, sólido ↔ líquido,
não entra); o processo é a **destilação fracionada** do ar líquido.

Dá para ver quantas vezes quiser (cada E recomeça do zero) e o ESC fecha no
meio. A primeira vez fica anotada (`Destilador.ja_explicou()`), para quando a
fase quiser cobrar isso.

**As falas.** Estão em `timelines/cientista_destilador.dtl`, no editor do
Dialogic. Antes de cada fala há um `[signal arg="..."]`: é ele que faz o
desenho andar — `raio_x`, `ar`, `ebulicao`, `evaporar`, `varal`, `ferver`,
`vapor`, `esfriar`, `separar`, `pureza`, `fim`, nessa ordem (os onze passos da
lista acima). Reescreva,
junte ou tire falas à vontade; cada marca só precisa continuar antes da fala
que a comenta (marca que faltar é feita junto com a seguinte). Se o jogador
passar as falas depressa, o desenho corre para alcançar.

**A tela** (`scenes/explicacao_destilador.tscn`, script
`scripts/explicacao_destilador.gd`):

- `Raiz/Coluna` — onde a coluna fica (o tamanho é o da arte × 4). À esquerda
  dela vão a régua e as plaquinhas de temperatura: deixe uns 170 px livres;
- `Raiz/Fichas/*` — as três fichas da legenda
  (`scripts/ui/ficha_substancia.gd`): posição, `nome` e `parte_do_ar` no
  Inspector. O ponto de ebulição não se escreve ali: sai de
  `ColunaDestilacao.SUBSTANCIAS`. Elas não se mexem;
- `Raiz/Veu` — a cor e a força do escuro por cima do jogo;
- `timeline` e `deslocamento_da_fala` (quanto a caixa de fala anda para a
  direita, para não cobrir o pé da coluna) — no Inspector do nó raiz. Com a
  `timeline` vazia a tela passa só o desenho, sem fala;
- `SomPop` e `SomRadio` — o estalo de cada substância que começa a evaporar
  ou que vira líquido de novo, e o chiado do rádio; o volume é no nó.

**A química** (`scripts/ui/coluna_destilacao.gd`). Nada ali é encenado: por
baixo do desenho roda, escondida, a mesma coluna do simulador do Laboratório e
do puzzle (`ColunaDoSimulador`, o "motor"), com o mesmo ar
(`MisturasDoDestilador`, "ar": 22 N₂, 7 O₂ e 2 Ar — o argônio aumentado para
aparecer; a ficha é que diz os 78/21/1% do ar de verdade). A explicação só diz
até onde o calor do ambiente leva o fundo em cada etapa; qual molécula
evapora, condensa ou escorre, quem decide é a conta
(`scripts/laboratorio/equilibrio_liquido_vapor.gd`). Os números estão no topo
do script:

- `MISTURA` — a chave da mistura em `MisturasDoDestilador` (quantas moléculas
  de cada substância, e a pressão de vapor de cada uma);
- `SUBSTANCIAS` — o ponto de ebulição que as fichas mostram, a linha de cada
  uma na folha das moléculas e as cores do líquido;
- `TEMPERATURA_AO_FERVER` (-190, até onde o fundo vai em `ferver`),
  `TEMPERATURA_DO_FUNDO` (-188, onde ele estaciona no fim, abaixo dos -183 °C
  do oxigênio) e `TEMPERATURA_DO_TOPO` (-196, onde o resfriador segura o
  topo) — os andares do meio ficam repartidos por igual entre o fundo e o
  topo;
- `TEMPERATURA_DO_AR_LIQUIDO` (-200) e `GRAUS_POR_SEGUNDO` (a pressa com que
  o fundo ganha calor do ambiente enquanto não ferve; fervendo, quem manda é o
  ponto de ebulição da mistura);
- `RITMO_DOS_PULOS_AO_EVAPORAR` — quantas vezes mais frequente fica o
  vai-e-volta da superfície em `evaporar`, só para dar tempo de ver (não muda
  a conta).

Mudar um número muda o que acontece na tela: ponha o fundo acima dos -183 °C
do oxigênio e ele ferve até secar, o oxigênio sobe todo e o topo fica menos
puro. Nada é sorteado e a conta anda sempre no mesmo passo
(`PASSO_DO_MOTOR`): a explicação termina sempre igual, passem as falas
depressa ou devagar. `RAMPA_DE_TEMPERATURA` são as cores da régua e do gás, do
mais frio ao menos frio.

**A arte.** `assets/fase nitrogenio/coluna de destilação.png` tem os dois
desenhos lado a lado: o de aço (o do mapa) e o de raio X. **As bandejas são
lidas do desenho**: toda barra clara presa em uma parede só é uma bandeja, o
vão do outro lado é a fenda por onde o gás sobe, e o dente na ponta é a borda
que segura o líquido. Pode redesenhar, mudar o tamanho e o número de bandejas.
O calor do ambiente (as setinhas laranja entre os pés) e o resfriador (o fio
azul no alto da cúpula) são desenhados por código, nos vãos que a arte deixa.
Em lugar nenhum a tela fala em aquecedor: ninguém esquenta a coluna. Se mudar o
tamanho ou o lugar do desenho de aço na folha, acerte também o `region_rect`
do `Sprite` do `destilador.tscn`. As moléculas pequenas são
`assets/fase nitrogenio/moleculas do ar.png`: 3 linhas (N₂, O₂, Ar) de 4
quadros de 12 × 12 px — a molécula girando; o 1º quadro, deitada, é o de
dentro do líquido e o das plaquinhas.

**No mapa** (`destilador.tscn`): o ponto do nó é o chão, no meio da coluna;
`Dica` é o botão, `Colisao` a área em que ele acende e `Sprite/Contorno` a
linha (a cor é o `modulate` dele).

## O corredor da torre

A porta da torre, no laboratório, não cai direto na fase 2: ela dá em
`scenes/fases/corredor_torre.tscn`. Andando até o fundo do corredor a cena
troca sozinha para a fase 2, onde a Cacau entra andando pela esquerda; na
volta é o mesmo caminho ao contrário, e a porta de dentro do corredor leva ao
laboratório. Entre o corredor e a fase 2 não há porta: são duas pontas abertas.

```
laboratório  PortaTorre  <->  PortaLab  [ corredor ]  SaidaTorre  <->  PassagemCorredor  fase 2
```

O corredor é pintado à mão, e o que cada nó dele faz (o cenário, a colisão
pelos tiles, a camada de pilastras que passa na frente, a câmera mais perto e
presa na vertical) está no cabeçalho de `scripts/fases/corredor_torre.gd`.

Uma `PassagemDeCena` é uma linha vertical: cruzou, troca de cena. No Inspector,
`sentido` diz para que lado fica o lado de fora (1 = direita, no fundo do
corredor; -1 = esquerda, na fase 2), `cena_destino` e `tag_destino` dizem para
onde ela manda e `tag_aqui` é o nome pelo qual a outra ponta a procura. O chão
tem de continuar uns 300 px para fora da linha, sem parede no caminho — a Cacau
ainda corre uns passos enquanto a tela apaga, e é de lá que ela vem na chegada.

Para esticar ou encurtar o corredor: pinte mais (ou menos) piso, teto e parede,
arraste a `SaidaTorre` para a ponta nova e leve a borda direita do
`LimitesDaCamera` para uns 24 px depois dela.

## O corredor do pátio

O elevador de carga da oficina não sobe mais direto para o pátio: ele chega em
`scenes/fases/corredor_patio.tscn`, e é andando até o fundo desse corredor que
se sai para o pátio — onde a Cacau entra andando pela esquerda, na grama. Na
volta é o mesmo caminho ao contrário.

```
oficina  Entrada/ElevadorPatio  <->  Elevador  [ corredor ]  SaidaPatio  <->  PassagemCorredor  pátio
```

É o mesmo corredor da torre, copiado (as duas cenas são independentes: pintar
uma não muda a outra), um terço mais curto. O que muda são as pontas:

- `Elevador` — a cabine, na ponta esquerda, no lugar da porta. A camada
  `Estrutura` (piso e teto) fica em `z_index` 10 para a cabine sumir no poço;
- `SaidaPatio` — a `PassagemDeCena` do fundo, que leva ao pátio.

No pátio (`fase1_2_exterior.tscn`) o prédio do elevador saiu: não há mais
cabine, porta de metal, parede nem piso de pedra — o chão é grama desde antes
da beirada esquerda da tela, e a ponta esquerda é a `PassagemCorredor` (igual
à da fase 2).

O teste da viagem inteira, com as trocas de cena de verdade:

```
godot --headless --fixed-fps 60 --path . res://tools/teste_corredor_patio.tscn
```

## Os morcegos dos corredores

O inimigo dos dois corredores é `scenes/fases/componentes/morcego.tscn`
(`scripts/fases/morcego.gd` — a luta inteira está explicada no cabeçalho).
Ele dorme pendurado no teto, acorda quando a Cacau chega perto, vem voando e
dá botes. Morre no bumerangue, com **dois acertos** — e como o bumerangue
acerta na ida e na volta, um arremesso bem dado resolve: o primeiro toque o
deixa tonto, o segundo mata.

Eles moram no nó `Morcegos` de cada corredor: três no da torre (um sozinho e
depois uma dupla) e dois no do pátio. Para mexer:

- **mudar de lugar** — arraste o morcego. No editor ele já aparece de cabeça
  para baixo; solte-o logo abaixo do teto e no jogo ele sobe e se pendura
  sozinho, com os pés na face do tile (procura até 200 px para cima). Onde não
  houver teto com colisão, fica pendurado exatamente onde você deixou;
- **mais um** — `Ctrl+D` num deles, ou arraste `morcego.tscn` para a cena.
  Deixe uns 300 px livres perto das pontas do corredor, para ninguém acordar em
  cima de quem acabou de chegar. Dois a menos de 260 px um do outro acordam
  juntos e fazem fila na mesma diagonal — é o arremesso que pega os dois;
- **tirar** — apague o nó.

No Inspector de cada morcego:

- **Vida** — `Vida` (2 = ida e volta; 1 = morre no primeiro toque) e
  `Persistir` (ligado, o morcego morto não volta nunca mais; desligado, que é
  o padrão, o bando volta ao teto a cada VISITA ao corredor). Nos dois casos,
  morrer não devolve vida a ninguém: enquanto a Cacau não sai do corredor, o
  morto continua morto e o ferido continua a um golpe de cair;
- **Ninho** — `Dorme No Teto` (desligado, ele fica voando em volta do lugar);
- **Vigia** — `Raio De Alerta` (de que distância ele acorda) e
  `Raio De Desistencia` (de que distância ele larga dela e volta a dormir);
- **Voo** — `Velocidade De Voo` e `Posto` (onde ele fica em relação a ela: os
  dois números iguais = na diagonal, que é onde o arremesso em 8 direções
  alcança);
- **Bote** — `Dano`, `Tempo De Preparo` (o aviso: quanto ele pisca em vermelho
  antes de mergulhar), `Velocidade Do Mergulho` e o intervalo entre um bote e
  outro;
- **Arte** — a cor do contorno e a dos olhos;
- **Sons** — os oito arquivos. Os que estão lá (`sounds/morcego/`) são
  sintetizados por `tools/gerar_sons_morcego.gd`; para usar uma gravação, é só
  soltar o arquivo no campo.

Dentro da cena do morcego: `Visual` tem as sete animações (velocidade e
quadros no painel SpriteFrames), `AreaAlvo` é onde o bumerangue pega (aumente
as alças para ficar mais fácil de acertar) e `Voz` é o volume e o alcance de
todos os sons dele.

O teste dele — a luta inteira numa salinha, com a Cacau e o bumerangue de
verdade, e depois os dois corredores:

```
godot --headless --path . res://tools/teste_morcego.tscn
```

## A fornalha do pátio e a porta dela

A fornalha é `scenes/fases/componentes/retorta.tscn` (`scripts/fases/retorta.gd`,
com o passo a passo no cabeçalho). O carvão sai em duas partes:

1. **a temperatura**, no painel (`scripts/ui/painel_fornalha.gd`): segurar E
   até o líquido do termômetro entrar na região amarela e mantê-lo lá dentro
   até a barra ao lado encher. O painel fecha sozinho;
2. **tampar o forno**, no cenário: a fornalha fica pegando fogo de boca aberta,
   esperando. A Cacau apanha a porta encostada ao lado (E — ela vai para a
   mochila) e, com a porta na mochila, E na fornalha fecha a boca do forno.
   **Enquanto a porta não fecha o tempo não passa**: a noite não cai e o
   carvão não sai. Não há como perder nessa parte.

Se ela demorar, a Cacau fala sozinha: *"Talvez eu deva tampar o forno, evita a
entrada de oxigênio..."*.

**Quem guia a jogadora.** No pátio, a lista de objetivos (canto superior
esquerdo) mostra *"Faça carvão a partir das madeiras"* com o subitem *"Acerte a
árvore com o bumerangue e recolha a lenha"* e a contagem das toras (as da
mochila mais as que já estão no forno). Daí em diante quem aponta é o balão de
exclamação, **aceso de longe** (o pátio é uma tela só): na fornalha, quando é a
vez de pôr a lenha e de acender; na porta encostada, quando é a vez de
apanhá-la; na fornalha de novo, quando é a vez de tampar e, no fim, de retirar
o carvão — com o subitem *"Retire o carvão da fornalha"* na lista. Depois disso
a lista pede para levar o carvão ao baú do painel CHONPS, no laboratório. A
lógica do "!" fica em `_atualizar_exclamacao` (`retorta.gd`) e
`_atualizar_aviso` (`porta_da_fornalha.gd`); os textos da lista, em
`scripts/roteiro_objetivos.gd`.

**Com o forno aceso ninguém sai do pátio — nem com o carvão esquecido nele.**
Do instante em que o fogo pega até a Cacau retirar o carvão, a passagem da
ponta esquerda não deixa ela ir embora: ela para na beirada da tela e diz
*"Preciso terminar de fazer o carvão primeiro..."* (forno aceso) ou *"Eu
preciso pegar o carvão antes!"* (carvão pronto no forno). A fala sai uma vez
por tentativa (para ouvir de novo é preciso se afastar e voltar). Com o fogo
apagado e o forno sem carvão a saída é livre — antes de acender, depois de
desistir no painel (ESC) ou de a carga virar cinza, e com o carvão já na
mochila.

O que dá para mexer, tudo dentro de `retorta.tscn`:

- `Porta` — a porta encostada ao lado do forno. Arraste para mudar o lugar (é
  para lá que ela volta quando o carvão sai). A arte é o `Sprite` dela:
  `assets/Lab/fornalha/PortaDaFornalha.png`, 16 × 18 px na paleta da fornalha;
- `PortaFechada` — a mesma arte, já na boca do forno. Só aparece com o forno
  tampado; se a arte da fornalha mudar, é este nó que tem de cobrir a boca;
- `SomPorta` e `SomConcluido` — a batida da porta e o som de puzzle resolvido;
- no Inspector da `Retorta`, grupo **Porta**: `Espera Antes Da Dica` (segundos
  até a fala; 12 por padrão, 0 desliga) e `Fala Da Porta` (a timeline);
- o texto da fala: `timelines/cacau_tampar_forno.dtl`;
- no grupo **Saída**: `Fala Ao Sair`, a timeline de quando ela tenta sair com
  o forno aceso, e `Fala Sem Carvao`, a de quando tenta sair com o carvão
  pronto ainda no forno (vazio = é barrada do mesmo jeito, calada). Os textos
  estão em `timelines/cacau_terminar_carvao.dtl` e
  `timelines/cacau_pegar_carvao.dtl`. Quem barra é a própria passagem
  (`PassagemCorredor`): ela pergunta a quem estiver no grupo `segura_a_saida`
  — o cabeçalho de `scripts/fases/passagem_de_cena.gd` explica o contrato;
- a região do termômetro: em `scripts/ui/painel_fornalha.gd`, `LINHA_DA_REGIAO`
  é a linha do meio dela e `MEIA_REGIAO` quantas linhas ela tem para cada
  lado (6 hoje: 13 linhas ao todo). Aumentar alarga a faixa e facilita o
  puzzle; mantendo o número par, as bordas caem em cima dos traços da escala.
  O desenho acompanha sozinho.

O teste do painel, da porta e da fala (com `-- --capturas=<pasta>`, e sem
`--headless`, ele salva uma imagem de cada momento):

```
godot --headless --path . res://tools/teste_painel_fornalha.tscn
```

## A música

Quem toca a música é o autoload `TrilhaSonora` (`scripts/trilha_sonora.gd`), e
não a cena: por isso ela não recomeça quando a Cacau morre ou passa para outra
cena com a mesma música. Ela só muda quando a cena nova pede outra — a que sai
some enquanto a nova cresce, em 1 s.

Cada cena diz o que toca, nesta ordem:

1. **A música da raiz.** Toda fase (`FaseBase`) tem o grupo **Música** no
   Inspector da raiz: `musica` e `volume_da_musica_db`. A introdução também.
2. **Céu aberto: a música da hora.** Com o item 1 vazio e uma `Atmosfera` que
   não é de interior, toca a música da hora — a mesma em todo lugar ao ar
   livre. Ela troca junto quando a hora muda (o pôr do sol no mirante, a noite
   caindo no pátio, a tecla Ç), em 3 s. As três ficam na `Atmosfera`, grupo
   **Música** (ver `ILUMINACAO.md`).
3. **Nenhum dos dois:** silêncio.

Hoje:

| Onde | Música |
|---|---|
| céu aberto, de tarde com sol (world1, pátio, rua da torre, telhado) | `bossa nova estilo stardew valley.mp3` |
| o menu principal | silêncio, por enquanto (`sem_musica` em `menu_principal.gd`) |
| céu aberto, com o sol já posto | `bossa nova estila stardew valley2.mp3` |
| céu aberto, de noite | `jazz noite.mp3` |
| a oficina (fase 1) | `fase1.mp3` |
| os corredores do pátio e da torre | `esgoto ou algo assim.mp3` |
| a torre por dentro | `SPY JAZZ - dentro da torre.mp3` |
| a introdução | `intro1.mp3` no vídeo e na foto da base; some com a foto, e o resto (o sonho, a Lua, o quarto, o jornal) é em silêncio |
| o world1 chegando da introdução | silêncio com a câmera no céu; a bossa nova entra de uma vez junto com o nome do jogo (`abertura_da_historia.gd`) |
| o laboratório e as salas do compressor e da destilação | silêncio |

A cena do mirante toca a música dela por cima da trilha: o piano G junto com o
balão de exclamação, a trilha pausada e, um respiro depois do piano,
"vendo foguete2" até a cena acabar (`TrilhaSonora.pausar` e `continuar`). Os
volumes e o respiro (`espera_antes_da_musica`) ficam na `ColisaoCenaFoguete`,
grupo **Música**. No fim a trilha volta, já com a música do sol posto.

Toda música toca em loop e continua com o jogo pausado (caderno, mochila,
puzzles). O teste:

```
godot --headless --path . res://tools/teste_trilha_sonora.tscn
```

## O modo de desenvolvedor (F1)

Para andar pelo jogo inteiro sem jogar tudo de novo. Só funciona no jogo rodado
pelo editor; no jogo exportado as teclas não fazem nada. Quem cuida é o
autoload `ModoDev` (`scripts/modo_dev.gd`).

| Tecla | O que faz |
| --- | --- |
| **F1** | Liga/desliga o modo. Ligando, a Cacau ganha todas as ferramentas e já sai voando. Desligar não tira as ferramentas. |
| **V** | Voar/andar (com o modo ligado). |
| **F2** | Menu de cenas: escolhe uma e vai direto para ela, no ponto de nascimento. Vale mesmo com o modo desligado. |

Com o modo ligado, nada machuca (cair no buraco faz voltar a voar), nenhuma
porta de fase fica trancada, o elevador parado parte, a saída barrada deixa
passar e a amostra gelada da fase 2 não esquenta.

Voando: WASD/setas em 8 direções, **Shift** mais rápido, roda do mouse (ou
**-** e **+**) para o zoom. Ela atravessa parede, chão, porta de metal e
barreira, e a câmera se solta dos limites da cena. As portas abrem no **E**,
como fora do modo dev (o W é subir). O elevador também.

## Regerar o blockout do zero

`tools/gerar_cenas_fases.tscn` reconstrói **todas** as cenas de fase e
componente. Ele **sobrescreve** o que estiver lá, então só rode se quiser
recomeçar o blockout e perder as edições feitas no editor. Atenção: ele ainda
monta a Torre de Gases ANTIGA em `fase2_torre.tscn` — rodá-lo apaga a rua da
fase 2 (as salas, a torre por dentro e o telhado ficam, mas sem a rua não se
chega nelas):

```
godot --headless --path . res://tools/gerar_cenas_fases.tscn
```

## Conferir se nada quebrou

`tools/teste_fases.tscn` abre cada fase e testa a fiação (bumerangue abre a
grade, as duas travas abrem o armário, os disjuntores entregam a célula S...).
Rode depois de mexer bastante nas cenas:

```
godot --headless --path . res://tools/teste_fases.tscn
```

Ele imprime `>>> TUDO OK <<<` ou aponta exatamente qual ligação sumiu — útil
se você renomear ou apagar um nó que o script da fase procura pelo nome.

O elevador entre a fase 1 e o corredor do pátio tem um teste só dele, com a mecânica miúda
(os 13 quadros da porta, o percurso levando a passageira sem levar a câmera, a
chegada que se encena sozinha):

```
godot --headless --path . res://tools/teste_elevador.tscn
```

A lista de objetivos e as setas "POR AQUI" também têm o seu (os caminhos de nó que o
roteiro consulta, o check que espera a tela fechar, a volta da etapa quando a
queima da fornalha dá errado, e as duas setas da Oficina):

```
godot --headless --fixed-fps 60 --path . -s res://tools/teste_objetivos.gd
```

O mapa do caderno tem o dele (as salas sem se encostar, as portas de todas as
cenas batendo com as passagens da planta, todo objetivo do roteiro com lugar no
mapa, os nomes e o quadro do lado cabendo no papel, e as abas: M, Q/E, L1/R1 e
o clique). Com `-- --capturas=<pasta>` e sem `--headless`, salva o mapa em
alguns momentos do jogo:

```
godot --headless --path . res://tools/teste_mapa.tscn
```

As portas entre as fases têm o delas: a porta modelo, os pares de tags de todas
as portas (quem sai por uma acha quem a recebe do outro lado) e as viagens de
verdade — laboratório ↔ corredor ↔ Torre e alçapão do fosso ↔ subsolo:

```
godot --headless --fixed-fps 60 --path . res://tools/teste_porta_modelo.tscn
```

O portão de rolamento da sala do compressor tem o dele (os 11 quadros, os sons
lidos do próprio .wav — o fade-in, o pico, o fim em silêncio —, o quadro da
trava no clunk e o da porta fechada na batida, o painel acendendo verde e
voltando ao vermelho, o prédio no lugar do antigo e o fim da rua vazio, a ida
e a volta da sala do compressor, e a sala por dentro com a arte de fora,
fechada e com som de concreto no chão):

```
godot --headless --fixed-fps 60 --path . res://tools/teste_porta_rolamento.tscn
```

As lajes vazadas da fase 2 têm o delas (em cada uma — a do meio da sala do
compressor, a do meio e o telhado do prédio na rua, o telhado da casinha da
escada —: a faixa está numa camada com colisão (o `Terreno`, ou a `Lajes` da
rua) na versão vazada, a Cacau pisa caindo de cima, passa pulando por baixo e
desce com S + espaço; e a faixa sólida da sala continua segurando no teto e
nas paredes):

```
godot --headless --fixed-fps 60 --path . res://tools/teste_lajes_vazadas.tscn
```

O corredor da torre tem o dele: o cenário com os tiles do laboratório, o piso
de metal, e a ida e a volta correndo de verdade (a cena troca sozinha no fundo,
e na volta ela entra andando por lá):

```
godot --headless --fixed-fps 60 --path . res://tools/teste_corredor_torre.tscn
```

O modo de desenvolvedor tem o dele (o voo atravessando parede e chão, a câmera
solta, o dano, as travas, as portas no E e o menu de cenas):

```
godot --headless --path . res://tools/teste_modo_dev.tscn
```

E os passos da Cacau, com o som de cada chão (grama, concreto e metal):

```
godot --headless --path . res://tools/teste_passos.tscn
```

A coluna de destilação tem o dela (as bandejas lidas da arte, as temperaturas
do fundo ao topo, a superfície evaporando sem ferver, a mistura fervendo entre
os pontos de ebulição com o oxigênio evaporando junto, o topo rico em
nitrogênio e o fundo rico em oxigênio sem nenhum dos dois puro, o mesmo
resultado em qualquer ritmo, o puzzle da amostra — frio demais, a janela certa
e quente demais, com o aviso de cada uma —, a conversa do Dr. Chico fazendo o
desenho andar na fase 2, o fechar sozinho e o ESC). Com `-- --capturas=<pasta>`
e sem `--headless`, salva uma imagem de cada momento:

```
godot --headless --path . res://tools/teste_destilador.tscn
```

A fase 2 tem três: o puzzle do compressor (a física do gás, o estouro, a
amostra e o relógio dela), a fase inteira (as cinco cenas, os pares de portas
e passagens, as travas da rua, o cilindro do telhado e o andar para a frente e
para trás de lá, o primeiro degrau sem e
com a mochila, os puzzles da torre, as janelas grandes da torre fora das
portas, e a sala de destilação igual à do compressor, tile por
tile e com a mesma câmera, fechada e com chão de concreto) e a subida da torre
salto por salto:

```
godot --headless --path . res://tools/teste_compressor.tscn
godot --headless --path . res://tools/teste_fase2.tscn
godot --headless --path . res://tools/teste_subida_torre.tscn
```

Os morcegos dos corredores têm o deles (acordar, o bote e o aviso, o desvio, o
arremesso que acerta na ida e mata na volta, o corpo, e onde eles estão em
cada corredor):

```
godot --headless --path . res://tools/teste_morcego.tscn
```

E o que a fase 1 lembra quando a Cacau morre (espinhos, caixas elétricas,
torretas, domos, portas, maçãs, o puzzle pela metade e os morcegos do
corredor — ver "O que a fase lembra"):

```
godot --headless --fixed-fps 60 --path . res://tools/teste_estado_da_fase1.tscn
```
