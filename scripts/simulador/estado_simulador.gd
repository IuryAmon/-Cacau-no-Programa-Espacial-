class_name SimuladorEstado
extends RefCounted

# Memória do simulador de voo entre trocas de cena.
#
# Quando a Cacau entra no foguete do world3, o jogo troca de cena inteira para
# o simulador (é mais simples e seguro do que embutir o shoot'em up dentro do
# mapa: cada um tem sua própria câmera, parallax e resolução de jogo). Como a
# cena do world3 é destruída nesse momento, guardamos aqui o pouco que precisa
# sobreviver: de onde ela saiu e o que já conseguiu lá dentro.
#
# "static var" vive no script, não em um nó, então continua valendo depois do
# change_scene_to_file() — sem precisar de um autoload novo.

## Pontuação que o jogador precisa alcançar para concluir o treinamento.
const PONTUACAO_ALVO: int = 700

const CENA_SIMULADOR: String = "res://scenes/simulador/simulador_lua.tscn"

## Caminho da cena de onde o jogador entrou (normalmente o world3).
static var cena_de_retorno: String = ""
## Posição global exata em que ele estava ao entrar no foguete.
static var posicao_de_retorno: Vector2 = Vector2.ZERO
## True enquanto a volta ao world3 não foi processada (usado para o fade e
## para reposicionar o player exatamente onde ele estava).
static var voltando: bool = false
## True depois da primeira vez que ele entra (o briefing longo só toca uma vez).
static var ja_jogou: bool = false
## True depois de bater os 1000 pontos pelo menos uma vez. É por aqui que o
## resto do world3 pode saber se o treinamento já foi concluído (liberar uma
## porta, mudar uma fala, etc).
static var ja_completou: bool = false


static func registrar_entrada(cena: String, posicao: Vector2) -> void:
	cena_de_retorno = cena
	posicao_de_retorno = posicao
	voltando = false


static func registrar_saida() -> void:
	voltando = true
