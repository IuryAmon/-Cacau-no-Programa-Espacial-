# O menu principal e o Laboratório

O jogo agora abre por um **menu principal** (`scenes/menu_principal.tscn`), com
dois modos:

- **MODO HISTÓRIA** — a aventura da Cacau, que começa no `world1` como sempre
  começou. Nada da história foi mexido para isso.
- **LABORATÓRIO** — os puzzles e as simulações da história, soltos, para
  brincar e treinar: uma coleção de atividades no jeito do PhET.

O Laboratório tem cinco atividades:

| Atividade | De onde vem | O que se faz |
|---|---|---|
| **Monte seu átomo** | o puzzle do bumerangue | Põe e tira prótons, nêutrons e elétrons; o computador diz na hora que átomo é, com Z, A, a carga e o símbolo. |
| **Que átomo é esse?** | o mesmo desenho, ao contrário | O computador desenha o átomo; a pessoa diz o elemento. Dez perguntas, das fáceis aos íons e isótopos. |
| **Balanceamento** | os puzzles do foguete e do maçarico | 24 reações em três níveis: fácil (moléculas e contagem), médio (só moléculas), difícil (só a equação escrita). |
| **Destilador** | a coluna da fase do nitrogênio | Seis misturas, um termômetro para mandar na temperatura do fundo, e a coluna em raio X separando tudo. |
| **Tabela periódica** | a caixa do hidrogênio do caderno | Os 118 elementos, cada um na caixa dele; clicar abre a ficha com o átomo no modelo de camadas. |

> **O material é o do jogo.** O menu e o Laboratório são feitos das mesmas
> peças do HUD (a ficha de papel com moldura de tinta), do monitor da fase 1,
> das partículas do puzzle do bumerangue, das moléculas da folha dos puzzles e
> da arte da coluna. As teclas das dicas são as da folha do teclado.

## Onde fica cada coisa

| Arquivo | O que é |
|---|---|
| `scenes/menu_principal.tscn` + `scripts/menu_principal.gd` | O menu principal: o cenário (a entrada da base ao entardecer, com a Cacau e o Dr. Chico) e os três botões. |
| `scenes/laboratorio/menu_laboratorio.tscn` + `scripts/laboratorio/menu_laboratorio.gd` | O menu do Laboratório: um cartão por atividade. |
| `scenes/laboratorio/monte_seu_atomo.tscn` | Monte seu átomo. |
| `scenes/laboratorio/que_atomo_e_esse.tscn` | O quiz. |
| `scenes/laboratorio/balanceamento.tscn` | O balanceamento. |
| `scenes/laboratorio/destilador.tscn` | O simulador de destilação. |
| `scenes/laboratorio/tabela_periodica.tscn` | A tabela periódica. |
| `scenes/laboratorio/computador.tscn` | O monitor da fase 1, pronto para as atividades porem o conteúdo delas dentro. |
| `scripts/laboratorio/*.gd` | O script de cada atividade e os DADOS: `elementos.gd`, `equacoes_do_laboratorio.gd`, `misturas_do_destilador.gd`. |
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
`SUBSTANCIAS` (nome, fórmula, **ponto de ebulição de verdade**, o formato da
molécula e as cores) e a mistura em `MISTURAS` (quantas moléculas de cada uma,
a escala do termômetro e a temperatura do resfriador). É só isso: a coluna, o
termômetro, as fichas e a lista se montam sozinhos. No teste
(`tools/teste_destilador_do_laboratorio.gd`), acrescente em `SEPARACOES` a
temperatura que separa a mistura nova e onde cada substância tem de parar: ele
passa a conferir a simulação dela também.

**Trocar o nome ou a massa de um elemento.** A linha dele em `DADOS`, em
`scripts/laboratorio/elementos.gd`. A caixa do elemento é desenhada a partir
dali (número, símbolo e massa na fonte do jogo, com a moldura da caixa do
caderno): não há 118 imagens para refazer.

**Mudar o quiz.** Em `scripts/laboratorio/que_atomo_e_esse.gd`: `PERGUNTAS`
(quantas por partida), `FASES` (até que elemento vai e de que tipo é cada
trecho da partida) e `IONS` (a carga do íon mais comum de cada elemento).

**Pôr uma atividade nova no Laboratório.** Uma linha em `ATIVIDADES`
(`scripts/laboratorio/menu_laboratorio.gd`) com a chave, o nome, a descrição e
a cena; e o desenho do cartão em `_desenhar_a_figura`. Os cartões se arrumam
sozinhos. A cena nova deve ter, na raiz, um script que estende
`TelaInterativa` (veja "A base das telas").

**O menu principal.** O cenário é uma cena comum, montada como uma fase e só
com a arte do jogo: a entrada da base do `world1` ao entardecer, que é onde e
quando a história começa. Abra `scenes/menu_principal.tscn` e mexa:

- `Cenario/Cacau` e `Cenario/DrChico` — os dois personagens, cada um na
  animação de parado que tem no jogo. Arraste para mudar de lugar; *Flip H*
  vira para o outro lado.
- `Cenario/Chao` e `Cenario/Detalhes` — o gramado, o piso de pedra, o pilarete,
  o poste e os tufos de capim são **tiles**: pinte como numa fase. O poste
  pintado acende sozinho (nó `PostesDeLuz`), como nas fases.
- `BG/...` — o céu, o sol (`BG/CamadaDoSol/Sol`), as duas faixas de nuvens, a
  serra e as três fileiras de pinheiros (cada uma é um nó `Arte`: arraste para
  os lados para escolher o trecho, para cima e para baixo para mostrar mais ou
  menos dela).
- `Atmosfera.momento` — a hora. Ele está preso no entardecer e não mexe na
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
nêutrons). Depois de cada resposta a tela mostra Z, A e a carga, e o terminal
explica.

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

### Destilador
O termômetro manda na temperatura do **fundo**; o **topo** é o resfriador, numa
temperatura fixa; os andares do meio ficam repartidos entre os dois. A conta é
uma só: a molécula **ferve** se o andar em que ela está passou do ponto de
ebulição dela, sobe, e **condensa** no primeiro andar que está nesse ponto ou
abaixo. O que nem o topo condensa fica gás lá em cima (o neônio); o que não
ferve fica no fundo (o sal). A mistura está **separada** quando tudo assentou,
cada substância ficou inteira num lugar e nenhum lugar tem duas.

É um **modelo simplificado**, e a tela diz isso: numa mistura de verdade a
fervura não é tudo ou nada (o vapor sai mais rico no que ferve mais fácil, e as
bandejas servem para repetir esse enriquecimento), e o líquido de uma bandeja
escorre para a de baixo. Aqui, o líquido que parou numa bandeja fica nela:
esquentar demais mistura de novo, e só RECOMEÇAR desfaz.

Temperaturas que separam cada mistura (o teste confere uma a uma):

| Mistura | Fundo | Onde cada uma fica |
|---|---|---|
| Ar líquido | −183 °C | O₂ no fundo, Ar no 1º andar, N₂ no topo |
| Gases nobres | −110 °C | Xe no fundo, Kr no 2º, Ar no topo, Ne gás |
| Gás natural | −2 °C | butano no fundo, propano no 1º, etano no 3º, metano no topo |
| Petróleo | 280 °C | hexadecano no fundo, dodecano no 2º, octano no 3º, butano gás |
| Álcool da cana | 90 °C | água no fundo, etanol no 1º |
| Água do mar | 110 °C | sal no fundo, água no 1º |

(Não são as únicas: qualquer temperatura que ponha cada substância num andar
serve.)

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
| `teste_destilador_do_laboratorio` | Os pontos de ebulição, a simulação passo a passo das seis misturas, o termômetro e a tela. |

Todos jogam com o mouse, o teclado e o controle de verdade (os eventos entram
pelo `Input`, como no jogo). Com `-- --capturas=<pasta>` e **sem** `--headless`,
salvam imagens de cada momento. A base comum deles é `tools/teste_de_tela.gd`.
