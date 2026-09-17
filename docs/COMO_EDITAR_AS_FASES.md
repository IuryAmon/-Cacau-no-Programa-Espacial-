# Como editar as fases no editor do Godot

As fases deixaram de ser geradas por código: agora são cenas `.tscn` normais,
com nós nomeados, TileMapLayer pintado e um slot de sprite em cada objeto.
Tudo é arrastável, redimensionável e trocável direto no editor.

## Onde fica cada coisa

| Arquivo | O que é |
|---|---|
| `scenes/fases/fase1_oficina.tscn` | Oficina do Carbono |
| `scenes/fases/fase1_2_exterior.tscn` | Pátio da Oficina (fase 1.2) — tela única, do outro lado do elevador |
| `scenes/fases/fase2_torre.tscn` | Torre de Gases e Estufa |
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
pickup no chão, o popup de conquista e o selo redondo do canto da tela. Por
isso ela não fica presa a um `Sprite` de cena: mora em
**`scripts/ferramentas/catalogo_ferramentas.gd`**.

Para dar arte a uma ferramenta, solte o PNG em `assets/itens/` e escreva o
caminho no campo `icone` da ferramenta lá no catálogo. É o mesmo lugar onde
ficam o nome, a descrição do popup e a cor do anel do selo. O maçarico já está
preenchido — as outras quatro estão com `icone` vazio esperando a arte.

Enquanto o `icone` estiver vazio, a ferramenta funciona normalmente, só sem
popup e sem selo (segue valendo o aviso flutuante do pickup). Preencheu o
`icone`, os três lugares acendem de uma vez, sem mexer em cena nenhuma.

Se você preferir uma arte diferente só para o pickup do chão, arraste ela para
o `Sprite` do `PickupHabilidade`: o slot preenchido tem prioridade sobre o
catálogo.

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

## Mudar tamanhos e comportamento

Selecione o nó e use o Inspetor. As propriedades mais usadas:

- `ChapaSoldada`, `PisoEletrificado`, `CorrenteVapor`, `BlocoAlternavel`:
  **`tamanho`** redimensiona colisão e placeholder juntos.
- `CorrenteVapor`: **`empuxo`** (a Cacau anda a 350 px/s) e **`direcao`**.
- `AlvoBumerangue`: **`permanece_ativo`** (interruptor definitivo) ou a
  **`janela`** em segundos (alvo temporizado).
- `PortaFase`: **`cena_destino`**, **`requer_habilidade`** e o par
  **`tag_aqui` / `tag_destino`**, que decide em qual porta o jogador nasce ao
  chegar de outra fase.
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
`LimitesDaCamera` ter **exatamente o tamanho de um quadro**: 1067 × 600, que é
a janela de 1600 × 900 dividida pelo zoom 1,5 da câmera do player. Como a
Camera2D nunca mostra nada fora dos limites e o retângulo tem o tamanho da
tela, só existe um enquadramento possível.

- Para deixar QUALQUER fase de tela parada, é só encolher o `LimitesDaCamera`
  até esse tamanho.
- No instante em que o retângulo passar de 1067 × 600, a câmera volta a
  acompanhar a personagem — não há exceção escondida em lugar nenhum.
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

A memória vale **só para mortes**. Sair por uma porta e voltar começa a fase
do início (o player avisa o `PontoDeRetorno` antes de recarregar por morte;
qualquer outra abertura de cena é uma visita nova). Não há save em arquivo:
fechar o jogo esquece tudo.

Teste automático (bandeira, sala, os dois juntos, sair e voltar, câmera):

```
godot --headless --path . -s res://tools/teste_ponto_de_retorno.gd
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

### O elevador entre fases (fase 1 ↔ fase 1.2)

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

As duas pontas montadas hoje são `Entrada/ElevadorPatio` (na Oficina, sobe,
tag `oficina` → `patio`) e `Elevador` (no Pátio, desce, tag `patio` →
`oficina`).

**Ordem de desenho:** a cena do componente vem em `z_index` 3, na frente da
personagem (que anda em `z_index` 2), para ela aparecer *atrás* da grade. Para
a cabine sumir dentro do poço em vez de deslizar por cima do chão, é o
**cenário** que precisa estar na frente: na fase 1.2 o `TileMapLayer` do
terreno está em `z_index` 10 só por causa disso. Se você puser um elevador
numa fase nova, faça o mesmo com o chão dela — ou aceite que a cabine passe
por cima até sair de quadro.

### As gaiolas de vidro (fase 1)

As duas ferramentas da Oficina do Carbono ficam trancadas na **gaiola de vidro
elétrica** (`scenes/fases/componentes/gaiola_vidro_eletrica.tscn`), exclusiva
desta fase — o prólogo continua com a gaiola de grade (`scenes/gaiola_puzzle.tscn`).
As duas cenas usam o mesmo script, `scripts/gaiola_puzzle.gd`.

- `Entrada/GaiolaBumerangue` — sem puzzle: chegar perto e apertar **E** abre.
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

A **origem da gaiola é o pé da base**: encoste o nó no chão. O item fica em
cima da base, dentro da cúpula — 4 px à esquerda e 55 px acima da origem da
gaiola. Para mover, arraste os **dois** nós juntos (gaiola e pickup). A gaiola
de vidro não tem colisão: ela é mais alta que o pulo da Cacau e, sólida,
fecharia o caminho do pátio.

### O puzzle do maçarico (fase 1)

`scenes/puzzle_macarico.tscn`, na tela do computador
(`assets/UI/Computador receptor/tela_computador.png`). É a mesma interface de
balanceamento do puzzle do foguete, mas **sem a ajuda do cientista** — quem
corrige é o rodapé da tela. Duas etapas:

1. `C₂H₂ + O₂ → CO + H₂` — o acetileno reagindo com o oxigênio;
2. `CO + H₂ + O₂ → CO₂ + H₂O` — os gases da etapa 1 queimando com oxigênio.

**Vale qualquer resposta balanceada** (C, H e O batendo dos dois lados): na
etapa 1, 1-1-2-1 ou qualquer múltiplo dele; na etapa 2, 1-1-1-1-1, 4-2-3-4-2,
3-1-2-3-1 etc. Resposta certa que não está na forma mais simples (como
2-2-4-2) passa do mesmo jeito, e o rodapé mostra a forma simplificada como dica.

As reações e todos os textos ficam na constante `ETAPAS`, no
topo de `scripts/puzzle_macarico.gd`. A coluna de cada substância (setas e
tamanho das moléculas) é `scenes/ui/termo_equacao.tscn`. Durante os testes, a
tecla **L** resolve o puzzle na hora; o teste automático é
`tools/teste_puzzle_macarico.tscn`.

### A folha de átomos e moléculas

Os dois puzzles de química (foguete e maçarico) desenham as moléculas a partir
de uma folha só: `assets/UI/Computador receptor/atomos e moleculas.png`. A
ordem dos desenhos é: 1ª linha H, O, C; 2ª linha H₂, O₂, C₂; 3ª linha H₂O,
CO₂; 4ª linha C₂H₂. **Os desenhos são achados sozinhos** (ver
`scripts/ui/folha_moleculas.gd`): pode redesenhar, mudar tamanho e posição,
desde que mantenha a ordem e um espaço vazio entre um desenho e outro. O CO não
tem desenho próprio — é recortado do CO₂.

## O que a fase lembra ao sair e voltar

Não existe save em arquivo: tudo abaixo vale enquanto o jogo estiver aberto
(fica no `EstadoMundo`, em `scripts/estado_mundo.gd`). Sair para o laboratório
e voltar — ou morrer e recarregar — encontra a fase como ficou:

- ferramentas pegas e gaiolas abertas; células do painel;
- painéis do portão, barreira, caixa das serras (serras recolhidas) e o
  terminal do guincho (o elevador volta a funcionar sozinho);
- **toras de madeira recolhidas** (não reaparecem; a lenha fica no inventário);
- **a retorta**: quantas toras estão dentro do forno, o carvão esperando para
  ser retirado e, claro, a célula C já retirada. Se a queima der errado, as
  toras voltam ao depósito e continuam lá mesmo saindo e voltando;
- **a caixa empurrável**: fica onde estava quando você **saiu pela porta**.
  Morrer não conta — a fase recarrega com a caixa na posição da última saída,
  o que desencalha uma caixa empurrada para onde não devia.

Não guardam de propósito: alvos temporizados (como o `AlvoFixo1` do treino),
plataformas que caem, bolas quicantes e torretas.

Para um objeto novo lembrar do estado: `EstadoMundo.marcar_feito(self)` /
`ja_feito(self)` para "já aconteceu", ou `guardar(self, "marca", valor)` /
`ler(self, "marca", padrao)` para valores. Se só deve anotar na saída por
porta, entre no grupo `EstadoMundo.GRUPO_SALVAR_AO_SAIR` e tenha um
`salvar_ao_sair()`. Nos alvos de bumerangue, ligue `persistir` no Inspetor.

## Regerar o blockout do zero

`tools/gerar_cenas_fases.tscn` reconstrói **todas** as cenas de fase e
componente. Ele **sobrescreve** o que estiver lá, então só rode se quiser
recomeçar o blockout e perder as edições feitas no editor:

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

O elevador entre a fase 1 e a 1.2 tem um teste só dele, com a mecânica miúda
(os 13 quadros da porta, o percurso levando a passageira sem levar a câmera, a
chegada que se encena sozinha):

```
godot --headless --path . res://tools/teste_elevador.tscn
```
