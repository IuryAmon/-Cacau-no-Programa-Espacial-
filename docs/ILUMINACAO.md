# A iluminação das fases ao ar livre

O jogo tem hora. O `world1` começa ao **entardecer**, com o sol quase se pondo;
no mirante o sol se põe e a fase vira **noite**; o pátio da oficina (fase 1.2) e
a `fase2_torre` já são noite, com a lua. Tudo isso sai de um sistema só, em
`scripts/luz/`, com uma regra de estilo:

> **A luz cai em degraus.**
> Nada de degradê liso de foto. O céu é feito de faixas, o brilho do sol e da
> lua é feito de anéis, a luz do poste cai em patamares — e a emenda entre um
> degrau e o outro é pontilhada, no tamanho do pixel do cenário. É o que faz a
> luz parecer pintada junto com o resto.

## As peças

| Nó na cena | Script | O que faz |
|---|---|---|
| `Atmosfera` | `atmosfera.gd` | O regente: guarda a hora e distribui as cores dela para todo mundo. |
| `BG/Ceu` | `ceu_pixel.gd` | O céu: degradê em faixas, estrelas, clarão em volta do astro. |
| `BG/CamadaDoSol/Sol` | `astro_pixel.gd` | O sol: um sprite comum + o halo em anéis. |
| `BG/CamadaDaLua/Lua` | `astro_pixel.gd` | A lua (`assets/Area Aberta/Lua/2.png`) + o halo dela. |
| `BG/NuvensDoFundo`, `BG/Nuvens` | `nuvens.gd` | Duas faixas de nuvens passando (cloud1 a cloud6). |
| `PostesDeLuz` | `postes_de_luz.gd` | Acende todo poste pintado no TileMap. |
| `BG/BASE/.../Holofotes` | `arte_iluminada.gd` | Os holofotes do foguete lá no fundo, à noite. |

Mais duas, para usar onde quiser:

| Cena / script | Para quê |
|---|---|
| `scenes/luz/luz_de_poste.tscn` | Uma luz de lâmpada comprida, para acender o que não é tile. |
| `scripts/luz/luz_pontual.gd` | Uma luz redonda: fogo, laser, tela, farol. |

E os três horários, que são arquivos de cor: `assets/luz/entardecer.tres`,
`crepusculo.tres` e `noite.tres`.

## O que você mexe, e onde

**Mudar o sol de lugar.** Arraste `BG/CamadaDoSol/Sol` no editor. O quadro da
tela, para as camadas do fundo, é o retângulo de (0, 0) a (1067, 600). O clarão
do céu e o halo vão junto.

**Mudar a cara do sol.** Selecione o `Sol` e use o Inspector:

- a arte do disco é a `Texture` (é um Sprite2D: troque o PNG, mude a escala);
- grupo **Brilho** — `alcance`, `aneis`, as duas cores, `intensidade`,
  `pontilhado` (0 = anéis secos, 1 = todo pontilhado) e `cobertura` (1 cobre o
  céu com a tinta do anel, 0 só clareia);
- grupo **Pontas** — `pontas` acima de 0 dá raios ao sol;
- grupo **Animação** — os anéis respiram em quadros (`quadros_por_segundo`).

**A lua** é igual: `BG/CamadaDaLua/Lua`. No `world1` ela só aparece de noite;
para vê-la no editor, ponha `previa_no_editor` da `Atmosfera` em **Noite**.

**Mudar as cores de um horário.** Abra `assets/luz/entardecer.tres` (ou
`crepusculo`, ou `noite`) no Inspector com a fase aberta: a prévia acompanha.
Cada arquivo tem o céu (quatro cores, de cima para baixo), as estrelas, a luz
que bate no fundo, a cor do ar, a luz ambiente do mundo, as nuvens e a força
dos postes. Os três arquivos valem para todas as fases.

**Em que hora a fase começa.** `Atmosfera` → `momento`. O `world1` é
*Entardecer*; o pátio e a torre são *Noite*.

**Ver a noite sem mudar a fase.** `Atmosfera` → `previa_no_editor`. É só o que
o editor mostra — não é gravado na cena.

**Nuvens.** Cada nó `Nuvens` é uma faixa. No Inspector: `quantidade`, de que
tamanho (`menor` / `maior`, de 1 a 6), a `faixa` de altura, o `vento` (negativo
sopra para a esquerda), a `distancia` (quanto desbotam no céu) e a `semente`
(troque o número para embaralhar). A ordem dos nós dentro do `BG` é a ordem de
desenho: nuvem acima da serra na árvore = atrás da serra na tela.

**Postes.** Poste é tile: pinte o braço da lâmpada (as três células do
`Props-01.png`) em qualquer TileMapLayer e a luz aparece sozinha — no editor,
enquanto você pinta. Cor, força, alcance, tremor e mariposas são do nó
`PostesDeLuz`, e valem para todos os postes da fase. O poste tem **8 tiles** de
altura (o braço em cima, a base embaixo); os do `world1` foram acertados para
esse tamanho.

**Acender outra coisa.** Arraste `scenes/luz/luz_de_poste.tscn` para a cena (o
ponto do nó é o centro do tubo), ou ponha um Node2D com o script
`luz_pontual.gd` para uma luz redonda. Com `segue_o_horario` ligado ela só
acende onde está escuro (é o caso do laser e do painel); desligado, brilha
sempre que estiver `acesa` (é o caso do fogo da fornalha).

**Holofotes no fundo.** `BG/BASE/SpritesTiros(4)/Holofotes`: cada filho é um
foco. Arraste, mude `raio`, `cor`, `forca`; `piscar` faz farol. Para acender
outro ponto da base, duplique um foco (cabem 8).

## A cena do mirante

Quem dirige é `scripts/colisao_cena_foguete.gd` (a Area2D `ColisaoCenaFoguete`):

1. a Cacau pisa no mirante: susto, fala, balão de coração — como sempre;
2. com o coração ainda no ar, o sol começa a descer atrás da serra. O céu vai
   do dourado ao roxo, as primeiras estrelas aparecem, o fundo e o mundo
   escurecem, os postes dão a piscada e os holofotes do foguete acendem;
3. no fim da descida a tela apaga;
4. no escuro, a fase vira noite;
5. a tela acende: lua, céu estrelado, postes com tudo. O controle volta.

Ela fica parada do começo ao fim e o HUD some junto. Os tempos estão no
Inspector da `ColisaoCenaFoguete` (`respiro_antes_do_sol`, `hora_da_cortina`,
`duracao_do_escurecer`, `pausa_no_escuro`, `duracao_do_clarear`) e da
`Atmosfera` (`duracao_do_por_do_sol`, `descida_do_sol`, `hora_dos_postes`).

Depois disso é noite pelo resto da partida (`EstadoMundo.anoiteceu`): o
`world1` abre escuro quando ela volta do laboratório, e a cena não repete — nem
se ela morrer antes de chegar lá (`EstadoMundo.viu_o_foguete`).

## Como funciona por dentro

**Um perfil por horário.** `PerfilDeLuz` é um recurso com todas as cores de uma
hora. A `Atmosfera` aplica um deles — ou a mistura de dois, a cada quadro do pôr
do sol — chamando `receber_perfil()` em quem está no grupo
`atmosfera_clientes` (céu, astros, nuvens, holofotes) e escrevendo
`intensidade` em quem está no grupo `luz_artificial` (postes e luzes que
seguem o horário).

**O fundo se veste sozinho.** Toda camada de arte do `BG` que não tenha
material próprio recebe o `camada_de_fundo.gdshader`: a luz do horário
multiplica a arte, e o ar come a camada conforme a distância. A profundidade
vem do `motion_scale` da ParallaxLayer (quem anda menos está mais longe). Onde
a câmera não anda (o pátio, com tudo em 0), vale a ordem das camadas. Para
mandar na mão, dê à ParallaxLayer o metadado `profundidade`, de 0 (perto) a 1
(longe) — a `BG/BASE` do `world1` usa 0,3 para a base não sumir na neblina.

**Nada disso é gravado na cena.** Céu, halo, nuvens e holofotes são desenhados
direto no servidor de render; as luzes dos postes são filhas internas; o
material do fundo vai por baixo do `material` (vazio) do nó. No `.tscn` fica só
o que está no Inspector. Dá para olhar a noite no editor e salvar sem medo.

**O sol desce com a serra; a lua não.** O céu e o sol estão em camadas com o
mesmo `motion_scale.y` da serra do fundo: quando a Cacau sobe no mirante, o
horizonte do céu e o sol acompanham a serra, e "sol quase se pondo" continua
verdade em qualquer altura. A lua está numa camada presa na tela — ela é
grande, e presa ao horizonte sairia do quadro lá embaixo.

**O mundo.** A luz ambiente é um `CanvasModulate` interno da `Atmosfera`. As
luzes dos postes e as pontuais são `PointLight2D` com textura em degraus
(`textura_de_luz.gd`, montada por conta e guardada: dez postes usam a mesma).

**A interface não escurece.** No jogo, tudo o que desenha uma arte de
`res://assets/UI/` (balões, teclas), todo `Label` e todo nó do grupo
`luz_propria` fica fora da luz ambiente. O contrário — algo da pasta da UI que
é do mundo, como a placa da estrada — vai no grupo `recebe_luz`.

## Pôr o sistema numa fase nova

1. No `BG` (ParallaxBackground), antes das camadas de arte: uma ParallaxLayer
   com `ceu_pixel.gd`; uma ParallaxLayer comum com um Sprite2D + `astro_pixel.gd`
   dentro (sol ou lua, pelo `tipo`); uma ou duas ParallaxLayer com `nuvens.gd`.
2. Na raiz: um Node com `atmosfera.gd` (`fundo` apontando para o `BG`) e um
   Node2D com `postes_de_luz.gd`.
3. Tire qualquer `CanvasModulate` que a fase já tenha: o da `Atmosfera` é o
   único que vale no mundo.

O jeito mais rápido é copiar esses nós da `fase2_torre.tscn`.

## Teste

```
godot --headless --path . res://tools/teste_atmosfera.tscn
```

Confere os postes (altura e luz), os três horários, a cena do mirante inteira
com o diálogo de verdade, a volta ao `world1` já de noite, o pátio e a torre, a
interface fora da luz e as luzes próprias.
