class_name EstadoMundo
extends RefCounted

# Memória do mundo entre trocas de cena — mesmo truque do SimuladorEstado:
# "static var" vive no script e não em um nó, então continua valendo depois do
# change_scene_to_file().
#
# Hoje guarda só o que a passagem do laser precisa saber. Como não existe
# sistema de save, isso vale enquanto o jogo estiver aberto: fechar e abrir
# recomeça com o Dr. Chico ainda não revelado.

const CENA_WORLD1: String = "res://scenes/world1.tscn"
const CENA_WORLD2: String = "res://scenes/laboratório_(world_2).tscn"

## True depois que o cientista se revela como Dr. Chico, no fim do world1.
## É o que liga a passagem livre entre o world1 e o laboratório — antes disso
## os dois lasers são só o obstáculo normal da fase.
static var revelou_dr_chico: bool = false

## True enquanto a chegada pela passagem não foi processada. A cena que abrir
## consome isso para nascer com o player na saída do próprio laser.
static var chegando_pelo_laser: bool = false

## True no corte que acontece logo depois da revelação, no fim do world1. O
## laboratório consome isso para abrir com a Cacau e o Dr. Chico lado a lado,
## do jeito que os dois pararam na conversa — e não na porta do laser.
static var chegando_da_revelacao: bool = false


## Chamado no fim da cutscene de revelação: daqui em diante o world1 e o
## laboratório viram um mapa só, ligado pelos lasers.
static func registrar_revelacao() -> void:
	revelou_dr_chico = true


# --- O QUE JÁ FOI FEITO NO MAPA ---
#
# Trocar de cena (ou morrer, que recarrega a fase) monta a cena do zero: gaiola
# fechada de novo, item de volta no lugar, painel trancado. Cada um desses
# objetos avisa aqui quando é resolvido e pergunta aqui no _ready() se já foi.
#
# A chave é o caminho do nó na árvore ("/root/World/GaiolaHidrogenio"), que é
# estável entre recargas — dois objetos iguais em lugares diferentes do mapa
# continuam sendo coisas diferentes. O "marca" separa mais de um estado no
# mesmo nó.
static var _feitos: Dictionary = {}


static func marcar_feito(no: Node, marca: String = "") -> void:
	_feitos[_chave(no, marca)] = true


static func ja_feito(no: Node, marca: String = "") -> bool:
	return _feitos.has(_chave(no, marca))


## Esquece que algo foi feito — para objetos que VOLTAM ao mapa (as toras
## repostas depois de uma queima perdida na retorta). Recebe o caminho, e não o
## nó, porque o original pode já ter sido apagado.
static func desmarcar_caminho(caminho: String, marca: String = "") -> void:
	_feitos.erase(caminho if marca.is_empty() else caminho + ":" + marca)


static func _chave(no: Node, marca: String) -> String:
	var caminho := str(no.get_path())
	return caminho if marca.is_empty() else caminho + ":" + marca


# --- VALORES ---
#
# Para estado que não é só "feito ou não": quantas toras estão no forno, onde
# ficou uma caixa. Mesma chave do marcar_feito (caminho do nó + marca).
static var _valores: Dictionary = {}

## Grupo de quem quer anotar algo no instante em que a personagem SAI da cena
## por uma porta ou passagem (não na recarga de quando ela morre): o FadeTela
## chama salvar_ao_sair() em todos eles logo antes de trocar de cena.
const GRUPO_SALVAR_AO_SAIR := &"salvar_ao_sair"


static func guardar(no: Node, marca: String, valor: Variant) -> void:
	_valores[_chave(no, marca)] = valor


static func ler(no: Node, marca: String, padrao: Variant = null) -> Variant:
	return _valores.get(_chave(no, marca), padrao)
