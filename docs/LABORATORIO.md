# O menu principal e o Laboratório

O jogo agora abre por um **menu principal** (`scenes/menu_principal.tscn`), com
dois modos:

- **MODO HISTÓRIA** — a aventura da Cacau, que começa no `world1` como sempre
  começou. Nada da história foi mexido para isso.
- **LABORATÓRIO** — os puzzles e as simulações da história, soltos, para
  brincar e treinar: uma coleção de atividades no jeito do PhET.

O Laboratório tem seis atividades:

| Atividade | De onde vem | O que se faz |
|---|---|---|
| **Monte seu átomo** | o puzzle do bumerangue | Põe e tira prótons, nêutrons e elétrons; a tela diz na hora que átomo é, com Z, A, a carga e o símbolo. |
| **Que átomo é esse?** | o mesmo desenho, ao contrário | A tela desenha o átomo; a pessoa diz o elemento. Dez perguntas, das fáceis aos íons e isótopos. |
| **Balanceamento** | os puzzles do foguete e do maçarico | 24 reações em três níveis: fácil (moléculas e contagem), médio (só moléculas), difícil (só a equação escrita). |
| **Compressor de ar** | o compressor da fase do nitrogênio | O simulador de gases: uma caixa com um êmbolo; mexe no volume (o êmbolo), na quantidade de ar (a bomba) e na temperatura (o termostato), e vê P · V = n · R · T com os números de agora. Passou de 4 atm, a caixa estoura. |
| **Destilador** | a coluna da fase do nitrogênio | Seis misturas, um termômetro para mandar na temperatura do fundo, e a coluna em raio X separando tudo. |
| **Tabela periódica** | a caixa do hidrogênio do caderno | Os 118 elementos, cada um na caixa dele; clicar abre a ficha com o átomo no modelo de camadas. |

> **O material é o do jogo.** O menu e o Laboratório são feitos das mesmas
> peças do HUD (a ficha de papel com moldura de tinta),
> das partículas do puzzle do bumerangue, das moléculas da folha dos puzzles e
> da arte da coluna. As teclas das dicas são as da folha do teclado.

## Onde fica cada coisa

| Arquivo | O que é |
|---|---|
| `scenes/menu_principal.tscn` + `scripts/menu_principal.gd` | O menu principal: o cenário (a entrada da base à noite, com a lua atrás da Cacau e do Dr. Chico) e os três botões. |
| `scenes/laboratorio/menu_laboratorio.tscn` + `scripts/laboratorio/menu_laboratorio.gd` | O menu do Laboratório: um cartão por atividade. |
| `scenes/laboratorio/monte_seu_atomo.tscn` | Monte seu átomo. |
| `scenes/laboratorio/que_atomo_e_esse.tscn` | O quiz. |
| `scenes/laboratorio/balanceamento.tscn` | O balanceamento. |
| `scenes/laboratorio/compressor.tscn` | O simulador de gases (o compressor de ar). A física é a do compressor da fase (`gas_fechado.gd`), com o que o simulador muda nela em `scripts/laboratorio/maquina_do_simulador.gd`; o desenho é o da fase sem o cilindro (uma caixa com o êmbolo), com a bomba, o manômetro e o alívio no fundo e a trava no êmbolo, em `scripts/ui/camara_do_simulador.gd`. |
| `scenes/laboratorio/destilador.tscn` | O simulador de destilação. |
| `scenes/laboratorio/tabela_periodica.tscn` | A tabela periódica. |
| `scenes/laboratorio/painel_da_atividade.tscn` | O painel das atividades de conteúdo (Monte seu átomo, o quiz, o balanceamento): a área do conteúdo, o cabeçalho miúdo e o rodapé que avisa. Nada de monitor: o Laboratório acontece direto na tela, sobre o fundo quadriculado. |
| `scripts/laboratorio/*.gd` | O script de cada atividade e os DADOS: `elementos.gd`, `equacoes_do_laboratorio.gd`, `misturas_do_destilador.gd`; e a física da destilação, `equilibrio_liquido_vapor.gd` (pressão de vapor, ponto de bolha, composição do vapor). |
| `scripts/ui/tela_interativa.gd` | A base de todas essas telas (clique, foco, teclas, controle, voltar, sons). |
| `scripts/ui/caixa_elemento.gd`, `caixas_dos_elementos.gd` | A caixa de um elemento, igual à do caderno, para qualquer um dos 118. |
| `scripts/ui/atomo_camadas.gd` | O desenho de qualquer átomo no modelo de camadas. |
| `scripts/ui/coluna_do_simulador.gd`, `termometro.gd`, `moleculas_do_destilador.gd` | As peças do destilador. |
| `scripts/laboratorio/transicao_de_cena.gd` | A cortina que troca de cena entre o menu, o Laboratório e a história. |

Cada script tem, no topo, a explicação do que ele faz e uma seção **ONDE
MEXER**. Este documento é o mapa; o detalhe está lá.

## O que você mexe, e onde

**Pôr uma equação no balanceamento.** Acrescente uma linha no nível, em
`scripts/laboratorio/equacoes_do_laboratorio.gd`:

```gdscript
{"nome": "O MAGNÉSIO QUEIMANDO",
	"reagentes": ["Mg", "O2"], "produtos": ["MgO"], "resposta": [2, 1, 2]},
```

A tela aceita qualquer resposta balanceada (em dobro também); a `resposta` é a
que o PULAR mostra, e precisa ser a mais simples e caber nas setas, que vão até
9 (a queima do butano, 2-13-8-10, não cabe). No difícil vale qualquer fórmula,
com parênteses: `Ca3(PO4)2`.

No fácil e no médio toda fórmula precisa de **desenho**. Os desenhos saem da
folha dos puzzles (`scripts/ui/folha_moleculas.gd`): os que não estão
desenhados nela (CH₄, NH₃, C₃H₈, o etanol...) são montados com os átomos soltos
da folha, por uma receita em `MONTADAS` que diz onde vai cada átomo. Para uma
molécula nova de H, C, N e O, é escrever a receita dela ali.

O teste (`tools/teste_balanceamento.tscn`) confere sozinho que a resposta
balanceia, que é a mais simples, que cabe nas setas e que há desenho.

**Pôr uma mistura (ou uma substância) no destilador.** Em
`scripts/laboratorio/misturas_do_destilador.gd`: a substância entra em
`SUBSTANCIAS` (nome, fórmula, **ponto de ebulição de verdade**, as **constantes
de Antoine** da pressão de vapor em `"vapor"` — de uma tabela, como as que já
estão lá —, o formato da molécula e as cores) e a mistura em `MISTURAS`
(quantas moléculas de cada uma, a escala do termômetro e a temperatura do
resfriador, que é a do topo de uma coluna de verdade para aquela mistura). É só
isso: a coluna, o termômetro, as fichas e a lista se montam sozinhos. O teste
(`tools/teste_destilador_do_laboratorio.gd`) confere que as constantes dão o
ponto de ebulição a menos de 0,6 °C; acrescente em `SEPARACOES` a temperatura
do fundo que separa a mistura nova e o que tem de ficar mais rico no topo e no
fundo: ele passa a conferir a simulação dela também.

**Trocar o nome ou a massa de um elemento.** A linha dele em `DADOS`, em
`scripts/laboratorio/elementos.gd`. A caixa do elemento é desenhada a partir
dali (número, símbolo e massa na fonte do jogo, com a moldura da caixa do
caderno): não há 118 imagens para refazer.

**Mudar o quiz.** Em `scripts/laboratorio/que_atomo_e_esse.gd`: `PERGUNTAS`
(quantas por partida), `FASES` (até que elemento vai e de que tipo é cada
trecho da partida) e `IONS` (a carga do íon mais comum de cada elemento).

**Pôr uma atividade nova no Laboratório.** Uma linha em `ATIVIDADES`
(`scripts/laboratorio/menu_laboratorio.gd`) com a chave, o nome e
a cena; e o desenho do cartão em `_desenhar_a_figura`. Os cartões se arrumam
sozinhos. A cena nova deve ter, na raiz, um script que estende
`TelaInterativa` (veja "A base das telas").

**O menu principal.** O cenário é uma cena comum, montada como uma fase e só
com a arte do jogo: a entrada da base do `world1`, de noite, com a lua atrás
dos dois. Abra `scenes/menu_principal.tscn` e mexa:

- `Cenario/Cacau` e `Cenario/DrChico` — os dois personagens, cada um na
  animação de parado que tem no jogo. Arraste para mudar de lugar; *Flip H*
  vira para o outro lado.
- `Cenario/Chao` e `Cenario/Detalhes` — o gramado, o piso de pedra, o pilarete,
  o poste e os tufos de capim são **tiles**: pinte como numa fase. O poste
  pintado acende sozinho (nó `PostesDeLuz`), como nas fases.
- `BG/...` — o céu, a lua (`BG/CamadaDaLua/Lua`), as duas faixas de nuvens, a
  serra e as três fileiras de pinheiros (cada uma é um nó `Arte`: arraste para
  os lados para escolher o trecho, para cima e para baixo para mostrar mais ou
  menos dela).
- `Atmosfera.momento` — a hora. Ele está preso na noite e não mexe na
  hora da partida.

A tela do menu não tem câmera: as medidas são em pixels da tela (1600 × 900) e
a arte do cenário está em **escala 4** (nas fases é escala 2, com o zoom da
câmera por cima). As animações dos dois são cópias das do jogo (a mesma folha,
os mesmos quadros): se a animação de parado mudar em `player.tscn` ou em
`cientista.tscn`, o `teste_menus` avisa que a do menu ficou para trás.

Os botões e os textos estão em `OPCOES`, no script. O nome do jogo é escrito
com as caixas de três elementos: `ELEMENTOS_DO_NOME := [20, 20, 92]` (Ca, Ca, U).

**Onde o jogo abre.** `run/main_scene` no `project.godot` aponta para o menu.
Para testar uma fase direto, continue usando o F6 (rodar a cena aberta).

## Como cada atividade funciona

### Monte seu átomo
Três seletores com as setas dos puzzles (segurando, a seta repete cada vez mais
rápido; a roda do mouse em cima do seletor também vale). A cada partícula:

- **o elemento** é o número de prótons: a caixa e o nome trocam na hora
  (`CARBONO-12`);
- **Z** = prótons, **A** = prótons + nêutrons, **carga** = prótons − elétrons
  (neutro, cátion ou ânion);
- **a notação** do livro, com A, Z e a carga em volta do símbolo;
- **na natureza**: de cada 100 átomos do elemento, quantos são daquele isótopo;
  o que não existe na natureza aparece como instável;
- os elétrons vão sozinhos para a camada certa, inclusive nos íons (o Fe²⁺
  perde os dois da camada N, e não os da M).

Sem prótons não há elemento, e a tela explica. Os limites são 118 prótons, 177
nêutrons e 118 elétrons.

### Que átomo é esse?
Dez perguntas por partida, sem repetir elemento: as seis primeiras são de átomo
neutro (dá para contar os elétrons); depois entram os **isótopos** e os
**íons**, em que só contar os prótons resolve — e uma das alternativas erradas
é sempre a "conta trocada" (o elemento que teria aquele tanto de elétrons ou de
nêutrons). Depois de cada resposta o rodapé explica (quantos prótons o núcleo
tem, e que elemento é esse). Embaixo do átomo não há Z, A nem carga: só o
desenho.

### Balanceamento
As setas sobem e descem o coeficiente; o botão (ou ENTER) confere. Errando, o
terminal diz que elemento não bate; acertando em dobro, mostra a forma mais
simples. PULAR mostra a resposta e não conta. O que muda de nível para nível é
só a ajuda da tela:

| Nível | Moléculas | Contagem dos átomos |
|---|---|---|
| Fácil | sim | sim (fica verde quando bate) |
| Médio | sim | não — e nada muda de cor antes de confirmar |
| Difícil | não | não: só a equação escrita |

Nos níveis com moléculas a tela se arruma como nos puzzles da história, de
cima para baixo: a contagem dos átomos ("Reagentes" e "Produtos"), a equação
escrita e os desenhos — com **cada termo da equação centrado em cima da coluna
da molécula que ele representa**. Quem escreve a equação assim, aqui e nos
puzzles do foguete e do maçarico, é `scripts/ui/equacao_sobre_colunas.gd`; a
altura de cada faixa é a dos nós `LabelReagentesTitulo`, `LabelReagentesValor`
e `LinhaEquacao` de `scenes/laboratorio/balanceamento.tscn`. O nível difícil
não tem desenho e não mudou: a equação é a tela inteira.

### Compressor de ar
O compressor da sala do compressor, na fase do nitrogênio, solto da história
para o professor apresentar os **gases ideais** — sem o cilindro da fase: o ar
fica todo numa caixa com um êmbolo, apoiada num suporte. A bomba, o manômetro
e a válvula de alívio entram pelo **fundo** da caixa (que está sempre em
contato com o gás; o êmbolo nunca desce além de 3 L do fundo). Não há
objetivo nem texto explicando: cada letra da equação é uma peça da máquina,
marcada com uma **ficha** da cor dela, e a mesma ficha está na equação,
embaixo.

| Letra | Peça | Como se mexe |
|---|---|---|
| **V** (azul) | o êmbolo | arrastar o cabo ou as setas ao lado da caixa |
| **n** (verde) | a bomba de ar (à esquerda) e a válvula de alívio (à direita) | cada bombada põe 0,1 mol (5 bolinhas); o alívio tira |
| **T** (laranja) | o termômetro, que é o termostato | arrastar o ponteiro ou as setas; de −150 °C a 1000 °C |
| **P** (vermelho) | o manômetro | não se mexe: é a consequência das outras três |

A equação embaixo mostra os números de agora (P em atm, V em L, n em mol, T
em **kelvin**; o termômetro é em °C, e os dois lado a lado mostram a conta), e
uma **setinha** ao lado de cada ficha diz se aquele número está subindo ou
descendo — apertar o êmbolo acende V↓ e P↑ ao mesmo tempo. R aparece como
0,082, o valor dos livros.

- **Cada bolinha vale 0,02 mol**, e o ar da máquina é sempre um número inteiro
  delas: o gás é exatamente o que se vê. As que entram pela bomba e saem pelo
  alívio só contam quando passam pelo furo do fundo da caixa. A altura do gás
  embaixo do êmbolo é a do volume, e a densidade de bolinhas é a pressão (na
  mesma temperatura).
- **A velocidade das bolinhas é a temperatura** (√T): esquentando, elas
  correm e batem mais forte.
- **O cadeado na haste do êmbolo** solta o êmbolo: solto, ele anda sozinho e
  segura a pressão de quando foi solto. Esquentando, ele sobe; pondo ar,
  também (as leis de Charles e de Avogadro). Pegar no êmbolo trava de novo.
- **Passou de 4 atm** (a mesma pressão que o cilindro da fase aguenta), o
  aparelho range e treme no amarelo; no vermelho, as paredes racham perto do
  êmbolo, o gás assobia pelas frestas, o êmbolo cede e, no estrondo, **sai
  voando** — a tampa é o ponto fraco da caixa — e o gás escapa pela boca, com
  o clarão, a onda de choque e a nuvem da explosão da fase. O cartão do
  estouro traz o RECOMEÇAR. Dá para estourar dos três jeitos: apertando (1 mol
  a 25 °C, abaixo de uns 6 L), esquentando (1 mol na caixa cheia, acima de
  uns 920 °C: a pressão só dobra quando a temperatura em kelvin dobra) e
  enchendo (uns 4 mol na caixa cheia a 25 °C).

As quatro transformações dos livros saem direto da máquina:

| Transformação | Como fazer | O que se vê |
|---|---|---|
| Isotérmica (Boyle) | só o êmbolo | metade do volume, o dobro da pressão |
| Isocórica (Gay-Lussac) | só o termostato, com o êmbolo travado | o dobro da temperatura em K, o dobro da pressão |
| Isobárica (Charles) | o termostato, com o cadeado aberto | o dobro da temperatura em K, o dobro do volume |
| Avogadro | a bomba (travado: a pressão sobe; solto: o volume) | o dobro de ar, o dobro da pressão (ou do volume) |

É um **gás ideal** de propósito: nada vira líquido (na faixa do termostato e
abaixo de 4 atm o ar de verdade também não viraria), e o termostato é forte o
bastante para segurar a temperatura enquanto o êmbolo anda (mexer no volume é
sempre isotérmico; a temperatura só muda pelo termostato). Na fase, ao
contrário, apertar esquenta o gás e o ar vira líquido — é o mesmo
`GasFechado`, com `pode_condensar` ligado.

Os números estão em `maquina_do_simulador.gd` (a faixa do termostato, quanto
vale cada bolinha, o máximo da bomba, o fim do curso do êmbolo); o desenho da
caixa sem o cilindro, do suporte, da bomba, do manômetro, do alívio, do
cadeado e do êmbolo voando, em `camara_do_simulador.gd` (que é a câmara da
fase, `camara_de_compressao.gd`, com essas peças trocadas); as cores das
fichas e as medidas da
equação, no topo de `scripts/laboratorio/compressor.gd`. Os dois sons novos (a
bombada e o "psss" do alívio) são sintetizados por
`tools/gerar_sons_compressor.gd`, como os outros do compressor.

### Destilador
O termômetro manda no aquecimento do **fundo**; o **topo** é o resfriador, numa
temperatura fixa; os andares do meio ficam repartidos entre os dois. A física
está toda em `scripts/laboratorio/equilibrio_liquido_vapor.gd` (o mesmo arquivo
serve à coluna da fase 2):

- **Evaporar não é ferver.** Todo líquido evapora um pouco abaixo do ponto de
  ebulição — é assim que a roupa seca no varal. A medida disso é a **pressão de
  vapor** de cada substância, que cresce com a temperatura (equação de
  Antoine). Na tela, é o vai-e-volta da superfície: moléculas que pulam para
  fora e voltam, mesmo com o fundo frio.
- **A mistura ferve no ponto de bolha dela.** Cada substância contribui com a
  sua pressão de vapor vezes a parte que ela é do líquido (lei de Raoult); a
  mistura ferve quando a soma chega a 1 atm. Esse ponto fica *entre* os pontos
  de ebulição das substâncias (o ar do jogo ferve a −193,6 °C), e o termômetro
  o marca ("O FUNDO FERVE"). Fervendo, o fundo não esquenta mais: o calor vira
  vapor. Como sai mais do que evapora fácil, o líquido que fica vai ficando
  mais rico no outro, e o ponto de bolha sobe.
- **O vapor é rico, não puro.** Quem evapora é escolhido na proporção da
  pressão de cada uma: o vapor do ar líquido de verdade sai com uns 94% de
  nitrogênio e 6% de oxigênio — que evapora ali 11 °C abaixo do ponto de
  ebulição dele.
- **Cada bandeja enriquece mais um pouco.** O vapor que chega numa bandeja
  condensa nela ou passa: passa mais fácil quanto mais volátil ele for ali
  (bandeja com 50% de eficiência); a bandeja mais quente que o ponto de bolha
  do líquido dela ferve de novo, e a que enche (3 moléculas) transborda para a
  de baixo, como numa coluna de verdade. No topo, o resfriador condensa o que
  pode; o que nem ele condensa fica gás (o neônio, o butano do petróleo). O
  que não evapora fica no fundo (o sal).
- **Misturas que não se deixam separar.** Álcool e água têm a conta corrigida
  (coeficientes de Van Laar): o vapor fica mais rico em álcool só até o
  **azeótropo**, com uns 89% das moléculas de etanol (95,6% da massa) — por
  isso o álcool destilado não passa de uns 96%.
- **O sal.** Ele não evapora, e o que dissolve (até a solubilidade, 36 g em
  100 g de água) segura a água: salgada, ela ferve acima de 100 °C. O que não
  cabe na água fica sólido no fundo — a ficha diz SÓLIDO (ou DISSOLVIDO,
  quando todo ele cabe na água), nunca líquido: o sal só derrete a 801 °C
  (`"fusao"`, em `misturas_do_destilador.gd`).

Por isso o resultado é o de verdade: **quase nada sai 100% puro**. A mistura
está **separada** quando a coluna assentou e cada substância (das que são ao
menos 15% da mistura) é a maioria num lugar diferente; a ficha de cada uma diz
onde está a maior parte dela ("20 DE 22 NO TOPO"). Esquentar demais seca o
fundo: tudo sobe, e o topo fica menos puro (o ar a −176 °C: o nitrogênio do
topo cai de 95% para 88%). Esfriar não desfaz; só RECOMEÇAR.

Nada é sorteado na física: a conta dá a proporção, e um "crédito" por lugar
escolhe na proporção exata. A mesma temperatura dá sempre o mesmo resultado.
É um **modelo simplificado**, e a tela diz isso: poucas moléculas, sempre a
1 atm, e a temperatura de cada andar é imposta (repartida entre o fundo e o
resfriador), não calculada pelo calor que o vapor leva.

Temperaturas que separam cada mistura, e como ela fica (o teste confere uma a
uma, do topo ao fundo):

| Mistura | Fundo | Como fica |
|---|---|---|
| Ar líquido | −188 °C | topo 20 N₂ + 1 O₂ (95% N₂); no meio, bandejas com O₂, N₂ e Ar; fundo 4 O₂ + 1 Ar + 1 N₂ (67% O₂) |
| Gases nobres | −120 °C | Ne gás; topo 6 Ar + 1 Kr; Kr nas bandejas; fundo só Xe |
| Gás natural | −20 °C | topo 8 CH₄ + 3 C₂H₆; etano e propano nas bandejas; fundo 4 C₄H₁₀ + 1 C₃H₈ |
| Petróleo | 260 °C | butano gás; topo octano; dodecano no 2º andar; fundo hexadecano |
| Álcool da cana | 90 °C | topo 7 etanol + 3 água (70%); fundo só água |
| Água do mar | 110 °C | topo só água; fundo só sal |

(Não são as únicas: o teste aceita qualquer resultado em que cada substância
seja a maioria num lugar diferente.)

### Tabela periódica
As casas dividem a moldura com as vizinhas, como numa tabela impressa, e o
papel de cada uma leva o tom da família. Clicar abre a ficha: a caixa ampliada
com o nome dentro (como na página do caderno), o átomo no modelo de camadas e
os números (partículas, camadas, família, lugar, isótopos da natureza). Com a
ficha aberta, ← e → passam de elemento.

## Controles

| | Mouse / teclado | Controle |
|---|---|---|
| Menus e tabela | mouse; setas ou WASD levam o foco; ENTER, ESPAÇO ou E entram | direcional ou analógico; ✕ entra |
| Atividades | mouse; nas setas, segurar repete | o cursor do controle (analógico), direcional pula de alvo em alvo, ✕ clica |
| Voltar | ESC | △ ou ○ |
| Destilador | arrastar o ponteiro do termômetro; ↑ ↓ ou W S, um grau | ✕ nas setas; segurar ✕ no termômetro e mover o cursor |
| Compressor de ar | arrastar o cabo do êmbolo e o ponteiro do termômetro; clicar na bomba, no alívio e no cadeado; W S ou ↑ ↓ o êmbolo, A D ou ← → a temperatura, E ou + bombeia, Q ou − solta ar, ESPAÇO o cadeado, R recomeça | ✕ nas peças e nas setas; segurar ✕ no cabo ou no termômetro e mover o cursor |

Do Laboratório, ESC volta ao menu principal. **Do modo história não há volta
para o menu** (não foi pedido; é fechar o jogo).

## A base das telas (`TelaInterativa`)

Toda tela do menu e do Laboratório tem na raiz um script que estende
`scripts/ui/tela_interativa.gd`. Quem estende não escreve `_ready`, `_process`
nem `_input`: escreve os ganchos e registra o que dá para clicar.

```gdscript
extends TelaInterativa

func _ao_abrir() -> void:
	registrar_alvo("limpar", botao.get_global_rect, limpar)

func limpar() -> void:
	tocar("tirar")
```

- `registrar_alvo(nome, retângulo, ao_apertar, disponível, repete)` — a base
  acha o alvo sob o ponteiro, troca a seta pela mãozinha, repete enquanto o
  botão fica segurado e oferece o alvo ao cursor do controle.
- `_ao_abrir()`, `_a_cada_quadro(delta)`, `_ao_receber(event)`,
  `_ao_pedir_para_voltar()`, `_ao_mudar_o_foco(nome)`, `_ao_dar_passo(direção)`.
- No Inspector: `titulo` (a plaquinha do alto), `cena_de_volta` (para onde o
  ESC leva), `navegar_com_teclas` (ligado nos menus: o foco anda pelas teclas e
  não há cursor de controle).

Os cliques são lidos nos eventos (`event.position`), que é o que o cursor do
controle pede.

## De onde vêm os números

Nada foi digitado de cabeça: cada dado foi conferido contra a fonte, e o teste
de cada arquivo guarda a conferência.

| Dado | Fonte |
|---|---|
| Nomes e massas dos elementos | [Tabela Periódica da SBQ, v. 5.0 (jun. 2025)](https://www.sbq.org.br/wp-content/uploads/2025/06/tabelaperiodica_SBQ_5-0_jun2025.pdf), com os pesos atômicos padrão abreviados da IUPAC ([CIAAW](https://www.ciaaw.org/abridged-atomic-weights.htm)); para os sem isótopo estável, o nuclídeo mais estável ([CIAAW](https://www.ciaaw.org/radioactive-elements.htm)) |
| Isótopos e abundâncias | [NIST, Atomic Weights and Isotopic Compositions](https://www.nist.gov/pml/atomic-weights-and-isotopic-compositions-relative-atomic-masses) |
| Famílias, grupos e períodos | [PubChem, Periodic Table](https://pubchem.ncbi.nlm.nih.gov/periodic-table/) |
| Elétrons por camada | a regra dos subníveis com as 20 exceções, conferida para os 118 contra o [Periodic-Table-JSON](https://github.com/Bowserinator/Periodic-Table-JSON) |
| Pontos de ebulição | [NIST Chemistry WebBook](https://webbook.nist.gov/chemistry/) e a tabela do PubChem, a 1 atm, arredondados para o grau |
| Pressão de vapor (constantes de Antoine) | NIST Chemistry WebBook (metano, etano, octano, dodecano, hexadecano, etanol, água) e Lange's Handbook of Chemistry (N₂, O₂, Ar, propano, butano); para neônio, criptônio e xenônio, Clausius-Clapeyron com o calor de vaporização do CRC Handbook. A lista está no começo de `misturas_do_destilador.gd` |
| Álcool e água (Van Laar) | A₁₂ = 1,6798 e A₂₁ = 0,9227, de Seader & Henley, *Separation Process Principles* |
| Constante dos gases | R = 0,0820574 atm·L/(mol·K) (CODATA) nas contas; a equação do compressor mostra 0,082, como nos livros. A composição do ar seco e a pressão de vapor do N₂, do O₂ e do Ar estão em `gas_fechado.gd` |

Os nomes são os da SBQ, inclusive onde ela difere do costume: **crômio**,
**kriptônio**, **neptúnio**, **berkélio**, **tennesso**, **oganessônio**. Para
usar outra grafia, troque na linha do elemento em `DADOS`.

Dois números em que as fontes não concordam por inteiro: o ponto de ebulição do
**sal** (usei 1465 °C, o do CRC Handbook; há quem dê 1413 °C) e o do
**hexadecano** (usei 287 °C; as medidas variam alguns graus). Nenhum dos dois
muda a simulação: o sal fica fora da escala do termômetro de qualquer jeito, e
o hexadecano é sempre o último a ferver.

## Testes

Cada peça tem o seu, em `tools/`, e todos terminam com `>>> TUDO OK <<<`:

```
godot --headless --path . res://tools/teste_menus.tscn
```

| Teste | O que confere |
|---|---|
| `teste_menus` | O jogo abre pelo menu; os dois menus; o cenário do menu principal (só arte do jogo, a Cacau e o Dr. Chico animados e no lugar, o poste aceso); a cortina; cada cartão abre a cena dele e o ESC volta; o modo história chega ao `world1` com os HUDs ligados. |
| `teste_elementos` | Os 118: nomes, massas, grupos, períodos, famílias, camadas, isótopos. |
| `teste_caixas_dos_elementos` | A caixa montada do H e a do O são iguais, pixel por pixel, às do caderno; as 118 cabem. |
| `teste_atomo_camadas` | O desenho do átomo para os 118, os íons, o movimento. |
| `teste_monte_seu_atomo` | A atividade inteira, clicando: respostas na hora, limites, textos que cabem. |
| `teste_que_atomo_e_esse` | O sorteio (120 partidas), as respostas, a partida até o placar. |
| `teste_tabela_periodica` | As 118 casas no lugar, o foco pelas teclas, a ficha de cada elemento. |
| `teste_balanceamento` | A conta, as 24 equações (toda resposta balanceia e é a mais simples) e os três níveis jogados até o fim. |
| `teste_destilador_do_laboratorio` | Os pontos de ebulição e as pressões de vapor; a física (evaporar abaixo do ponto de ebulição, o ponto de bolha, o vapor rico mas não puro, o azeótropo, a água salgada); a simulação passo a passo das seis misturas; o termômetro e a tela. |
| `teste_compressor_do_laboratorio` | O gás ideal (só gás, pôr e tirar ar, vazio); as leis de Boyle, Gay-Lussac, Avogadro e Charles, uma a uma; P·V = n·R·T mexendo em tudo ao acaso; os três jeitos de estourar; a tela (a caixa sem cilindro, com a altura do gás igual à do volume; fichas, setas, arrastos, bomba e alívio, o ar que entra se espalhando, o cadeado, as teclas, as setinhas, o êmbolo cedendo e saindo voando no estouro, o RECOMEÇAR, o controle). |

Todos jogam com o mouse, o teclado e o controle de verdade (os eventos entram
pelo `Input`, como no jogo). Com `-- --capturas=<pasta>` e **sem** `--headless`,
salvam imagens de cada momento. A base comum deles é `tools/teste_de_tela.gd`.
