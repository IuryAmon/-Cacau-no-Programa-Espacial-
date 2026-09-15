# A iluminação solar do `world1`

O sol da Área Aberta não é um efeito solto: é um rig com uma regra só, e essa
regra decide tudo o que vem depois.

> **O sol está atrás de tudo.**
> Ele mora na camada mais funda do parallax. Tudo o que o jogador vê — o
> foguete, as plataformas, o tronco, a Cacau — está *entre* ele e a câmera.
> Logo a face virada para nós é justamente a que fica na sombra.

Era exatamente isso que o rig antigo errava: havia uma `PointLight2D` pendurada
na posição do sol, dentro do mundo, acendendo a frente de todo objeto que
passasse por perto. Um objeto na frente do sol ficava com a cara iluminada — o
oposto do que acontece na vida. Essa luz não existe mais.

## O que o sol devolve para a cena

| Papel | Onde mora | O que faz |
|---|---|---|
| **Chave** | `BG/sol/LuzSol` | `PointLight2D` presa às camadas de fundo (`range_layer` negativo). É o único lugar onde o sol de fato bate de frente no que a câmera vê. |
| **Fio** | passe solar, estágio 1 | Rim quente na borda da silhueta virada para o sol, e o corpo afundando e esfriando. |
| **Ar** | passe solar, estágio 2 | Feixes crepusculares recortados por quem estiver na frente. |
| **Graduação** | passe solar, estágio 3 | Véu quente perto do sol, sombra fria longe dele, vinheta, lente. |
| **Preenchimento** | `IluminacaoSolar/LuzDoCeu` | A abóbada azul, de cima. Fria, e de propósito **não** segue o sol — se seguisse, voltaríamos a acender o primeiro plano pelo lado errado. |
| **Ambiente** | `AmbienteSolar` (`CanvasModulate`) | O tom da sombra aberta no canvas do mundo. Não toca no parallax, que é outro canvas. |

## Os arquivos

| Arquivo | O que é |
|---|---|
| `scripts/iluminacao_solar.gd` | O rig. Projeta o sol na tela e distribui a posição para todo mundo. |
| `shaders/luz_do_sol.gdshader` | O passe solar: contraluz, feixes e atmosfera num desenho só. |
| `shaders/neblina_aerea.gdshader` | Perspectiva aérea das camadas de parallax, com rim por alfa. |

## Como mexer

**Mover o sol:** arraste `BG/sol/Sprite2D` no editor. O rig recalcula tudo —
feixes, contraluz, névoa, poeira e a direção do flare seguem junto. Mova também
`Halo` e `LuzSol` para a mesma posição (são irmãos, não filhos, para poderem ter
escalas independentes).

> A camada `BG/sol` está com `motion_scale = (0, 0)`, igual ao céu: um corpo
> celeste é a coisa mais distante do quadro e não pode deslizar na frente das
> nuvens. Por causa disso a posição do sprite é multiplicada pelo zoom da câmera
> (1.5) na hora de virar posição de tela: o sprite em `(843, 310)` cai em
> `(1265, 465)` na tela de 1600×900.

**Trocar a cor da luz:** `IluminacaoSolar` → grupo **Cor** → `cor_do_sol` e
`cor_da_sombra`. O rig propaga as duas para todos os materiais e para as luzes,
então a fase inteira concorda sobre a cor do sol sem ninguém ficar para trás.
Para dar cor a cada material na mão, desligue `propagar_cor`.

**Clarear ou apagar a fase:** `energia`, no mesmo nó. É o multiplicador mestre.

**Trocar a arte do sol:** `BG/sol/Sprite2D` é o disco. Hoje ele usa um gradiente
radial aditivo (`GradientTexture2D_nucleo`); largue qualquer PNG na propriedade
`Texture` para pôr arte própria no lugar. Mantenha o material aditivo, senão o
disco fica opaco em cima do céu.

## Os três estágios do passe solar

Estão no mesmo shader **de propósito**. Encadeados como passes separados, cada
um pedindo `hint_screen_texture`, o último lê uma cópia do backbuffer anterior à
execução dos outros e apaga o trabalho deles — foi o que aconteceu na primeira
versão deste rig, e o sintoma é o passe final funcionando sozinho enquanto os
outros somem sem erro nenhum no console. Num passe só há uma leitura, uma
escrita e um terço do custo.

**1. Contraluz.** Procura silhuetas na própria tela: caminha alguns pixels na
direção do sol e compara o brilho. Claro lá na frente e escuro aqui é borda
virada para a luz. Há uma terceira condição que parece detalhe e não é — do lado
oposto também precisa estar escuro. Sem ela, qualquer forma mais fina que o fio
de luz (um galho, um cabo, a copa de um pinheiro) sai vazia dos dois lados e
acende inteira, virando borrão claro em vez de contorno. O mesmo cuidado existe
na versão por alfa, dentro de `neblina_aerea`.

**2. Feixes.** Marcha radial: de cada pixel caminhamos até o sol somando o
brilho encontrado no caminho. Onde há objeto opaco não há brilho para somar, e
o feixe morre atrás dele com a forma exata da silhueta. É oclusão de verdade —
ande até a parede do laboratório e veja os feixes serem cortados por ela.

`gama_feixe` merece uma nota honesta: perto do sol quase todas as amostras caem
dentro da fonte e longe dele só as últimas caem, então o feixe cru despenca com
a distância e some antes de cruzar o quadro. O expoente levanta essa cauda. É
licença artística, não física.

**3. Atmosfera.** Perto do sol a cena **lava** (mix na cor do ar) e **soma**
(véu) — nunca multiplica. Multiplicar pinta o objeto como se ele estivesse
virado para a luz; somar é o que descreve ar iluminado *na frente* dele. Longe
do sol tudo cai para o azul da sombra aberta. O flare só acende quando um anel
de sondas em volta do disco encontra brilho lá: com o sol tapado, não há o que
refletir.

## Como acrescentar um efeito ao rig

Não há lista de nós para editar. O rig varre a cena e adota **todo material que
declare um uniforme `sol_uv`**, alimentando também `aspecto` e `visibilidade`
quando o shader os declara, e `cor_luz` / `cor_sol` / `cor_sombra` quando a
propagação de cor está ligada. Basta dar ao seu efeito um shader com esses
nomes.

## Coisas que ficaram assim de propósito

- **Objetos claros não recebem contraluz.** `teto_sombra` corta acima de um
  certo brilho, porque em espaço de tela não dá para distinguir "objeto claro"
  de "céu". Uma parede branca contra o sol continua clara.
- **O rig escreve uniformes todo quadro.** No editor isso marca a cena como
  suja, e os valores de `sol_uv` / `visibilidade` gravados no `.tscn` são só o
  último quadro desenhado — não têm valor nenhum, são recalculados no `_ready`.
- **`hdr_2d` continua desligado.** Foi testado: em HDR o canvas passa a compor
  em espaço linear, o `CanvasModulate` e a luz do parallax deixam de clipar e
  todo o primeiro plano lava. Ligar exigiria recalibrar a fase inteira.
- **`motion_mirroring` das camadas de parallax foi de 2048 para 4096.** Os
  sprites estão em escala 2, então a largura desenhada é 4096: com 2048 o Godot
  desenhava uma cópia por cima da outra, meio tile fora de fase.
