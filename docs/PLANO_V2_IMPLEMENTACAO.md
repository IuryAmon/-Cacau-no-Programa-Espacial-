# Plano de Level Design v2 — Revisão e Implementação (blockout)

Data: 18/08/2026 · Fonte: `Plano_de_Level_Design_v2_com_Mapas.docx`

## 1. Revisão do plano (o que foi checado)

**Consistente e verificado:**
- Contagem das células: Prólogo (H+O) → Carbono (C) → Torre (N) → Subsolo (P+S) = 2+1+1+2 = 6 = CHONPS. ✓
- Toda fechadura é visível antes da chave existir; toda fase reutiliza habilidades anteriores. ✓
- Química correta em todos os pontos: 2H₂ + O₂ → 2H₂O; pirólise (calor sem O₂ → carvão);
  inertização por N₂ (desloca o comburente); mochila SAFER a N₂; ciclo do nitrogênio;
  ATP; vulcanização por enxofre; pontes dissulfeto; 2LiOH + CO₂ → Li₂CO₃ + H₂O (balanceada). ✓
- Babaçu/Alcântara, Johanna Döbereiner, Apollo 13: âncoras corretas. ✓
- Os 5 mapas batem com o texto das seções. ✓
- Referências ao projeto existente conferem: o drag-and-drop "já pronto" é o
  `puzzle_foguete.gd`; o "projeto de ácido-base" é o simulador (meteoros ácido/base);
  a "ala de produção de lítio" é a `ala_de_produção_(world_4).tscn`. ✓

**Dois pontos desconexos encontrados (corrigir no documento):**
1. **Seção 8 (Final):** o texto diz "uma seção por habilidade *na ordem em que foram
   conquistadas*", mas a lista (botas → bumerangue → maçarico → mochila → sinalizador)
   não é a ordem de conquista (maçarico → bumerangue → mochila → sinalizador → botas)
   nem a inversa. O Mapa 5 repete a ordem da lista. A ordem listada faz sentido de
   design (pisos eletrificados no portão, galeria escura perto do topo) — o blockout
   segue a lista/mapa; a *frase* é que deve mudar no documento.
2. **Seção 10 (cartas):** "aqui vai a coleção proposta:" — e a lista das oito cartas
   não aparece; só Johanna Döbereiner é nomeada no documento inteiro. Falta escrever
   as outras sete + a nona secreta, e mapear onde cada uma vive.

## 2. O que foi implementado (blockout cinza, jogável)

> **Atualização (18/08/2026, tarde):** o blockout deixou de ser gerado por
> código em tempo de execução. As fases agora são cenas `.tscn` de verdade,
> com nós nomeados, TileMapLayer pintado e slot de sprite em cada objeto —
> tudo editável no editor. Veja `COMO_EDITAR_AS_FASES.md`.

Arquitetura exatamente como a seção 11 do plano pede:
- **`Progresso` (autoload):** flags de células e habilidades; toda trava só consulta ele.
- **Ferramentas como componentes** (`scripts/ferramentas/`): anexadas ao player,
  ativadas por flag — bumerangue (F), dash da mochila com jato de N₂ (Shift, no ar),
  botas passivas, e a lanterna de foco (R/botão direito): feixe em cone com
  dois modos de mira alternados por L — PRESA (padrão, sem mouse: o lado para
  onde a personagem olha) e LIVRE (mouse/analógico direito) — cuja detecção
  usa os MESMOS alcance e ângulo do visual (`DetectorConeLuz`, reutilizável),
  bateria que drena acesa e se recupera apagada, e que congela as Sentinelas
  do subsolo — monstros terrestres com raio de perseguição em
  `scripts/fases/sentinela.gd`, validável em `tools/test_lanterna.tscn` e
  `tools/teste_lanterna.tscn` (headless). O sinalizador saiu do fluxo do jogo
  na reformulação do subsolo (o código da ferramenta permanece dormente).
- **Componentes compartilhados:** `Dosagem` (barra com faixa-alvo: retorta, estação de
  recarga, masseira) e `PuzzleOrdenar` (arrastar e soltar: ciclo do N, ATP, LiOH).
- **Cenas editáveis**: cada retângulo dos mapas virou sala pintada em
  TileMapLayer (colisão vem do tile) com os objetos instanciados de
  `scenes/fases/componentes/`. Cada componente tem um `Sprite` vazio e um
  `Placeholder` colorido que some sozinho quando a arte chega.

**Cenas novas** (`scenes/fases/`): `fase1_oficina`, `fase2_torre`, `fase3_subsolo`,
`fase_final`, `final_orbita` — cada uma segue o mapa correspondente do documento.

**Hub:** o laboratório ganhou (por código, sem tocar no .tscn) o painel CHONPS,
as 4 portas (oficina, torre, fosso no piso — exige mochila —, torre de lançamento)
e a entrega do pacote do prólogo na primeira visita (as células H + O; quando a
cutscene do Dr. Chico existir no Dialogic, a entrega migra para lá).

**Maçarico:** não é entregue no hub. Está trancado numa gaiola no fim do pátio da
Oficina do Carbono e sai de lá com o puzzle da mistura da chama
(`scripts/puzzle_macarico.gd`): abrir as válvulas na proporção que a reação
consome — 2 volumes de H₂ para 1 de O₂. Como é proporção, 2:1, 4:2 e 6:3 valem
igual; errar para cada lado dá a chama errada correspondente (fuliginosa com H₂
demais, oxidante com O₂ demais). A retorta, que pede a chama, fica no mesmo pátio.

**Persistência:** morte/recarga preserva o que foi feito (EstadoMundo); células e
habilidades vivem no Progresso. Célula não coletada reaparece na fase.

## 3. Controles novos

| Tecla | Ação |
|-------|------|
| F (+ direção) | Arremessar o bumerangue nas 8 direções (ativa alvos na ida e na volta). O arremesso **herda o momento da personagem**, como a granada de CS: parado alcança 320 px, em corrida ~400, saindo de um dash da mochila passa dos 550 — e correndo para trás sai fraco |
| F (com ele no ar) | **Chamar de volta**: o bumerangue dá meia volta no meio do voo em vez de esperar o alcance acabar |
| Clique esquerdo | Arremessar o bumerangue mirado no cursor — qualquer ângulo, não só as 8 direções do teclado; as duas formas convivem |
| Shift (+ direção) | Dash da mochila de N₂ em 8 direções, no chão ou no ar (apaga chamas; no ar vale 1 por salto, válvulas recarregam). Durante o dash a personagem fica **invulnerável a dano** e atravessa qualquer Sentinela (elas nunca colidem fisicamente com o player, dash ou não — a garantia extra do dash é só a invulnerabilidade) |
| R / botão direito | Liga/apaga a lanterna de foco — o feixe CONGELA as Sentinelas do subsolo enquanto as ilumina; acesa drena a bateria, apagada ela se recupera |
| L / clique do analógico esquerdo | Alterna a mira da lanterna entre PRESA (padrão: o lado para onde a personagem olha, mesmo flip_h do resto das ferramentas) e LIVRE (mouse/analógico direito) |
| E | Interagir (portas, juntas, mesas de puzzle) |
| M | **Debug**: equipa a mochila de N₂ na hora, em qualquer fase (só para testar o dash) |

## 4. Roteiro de playtest (fatia vertical primeiro, como o plano sugere)

1. Laboratório → porta "OFICINA DO CARBONO": pegar bumerangue, treinar alvos,
   porta temporizada, alvo duplo (um arremesso), recolher 3 toras de madeira
   (vão para o inventário) e abastecer a fornalha com 3 toques de E; no fim do
   pátio, gaiola do maçarico → puzzle da mistura 2 H₂ : 1 O₂; com a chama na
   mão, E na fornalha cheia → 2 s de fogo → dosagem → célula C.
2. Torre: alavanca atrás da grade (F) + chapa soldada (E) → mochila; subir
   apagando chamas (Shift), travando ventiladores (F), cortando atalhos;
   estufa → ciclo do N → célula N.
3. Fosso (agora com mochila) → subsolo em blecaute PERMANENTE: a lanterna de
   foco no armário de manutenção da chegada é a única luz da fase (acesa drena
   a bateria; apagada, a bateria se recupera). As Sentinelas — monstros que
   ANDAM, um por trecho do mapa — espreitam paradas e só perseguem quem entra
   no raio delas; apenas o feixe dirigido as congela, luz ambiente não conta.
   Oeste: gerador (puzzle do ATP) → célula P; leste: esteiras (F), masseira
   (dosagem) → botas; o corredor eletrificado guarda a célula S na sala do
   fim. Sem interruptores, setores religáveis ou luz geral — o sinalizador e
   a estação de recarga saíram do jogo, e a galeria escura da fase final
   passou a responder à lanterna.
4. Torre de lançamento (T-6 → T-1): portão checa o painel completo; prova geral
   de cada habilidade; purificador de LiOH; embarque → cena em órbita.

## 5. Pendências conscientes (fora do blockout)

- Timelines do Dialogic para o Dr. Chico ("comenta sempre a próxima fechadura")
  — as placas de blockout cumprem o papel por enquanto.
- As 8 cartas colecionáveis (bloqueadas pela lista ausente no documento — item 1.2).
- Sequência opcional da ascensão (adaptar o simulador) antes da cena em órbita.
- Variações da seção "Possibilidades" (negro de fumo, serpente do açúcar, mariposas,
  carga limitada da mochila, descida com planagem, modo acessibilidade).
- Arte/TileMap sobre o blockout, sons das novas interações.
