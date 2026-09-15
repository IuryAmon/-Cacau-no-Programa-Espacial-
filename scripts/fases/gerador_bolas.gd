class_name GeradorBolas
extends Marker2D

# --- GERADOR DE BOLAS QUICANTES ---
#
# Solta uma BolaQuicante (ver bola_quicante.gd) daqui de tempos em tempos. Ela
# cai, desce a rampa aos pulinhos e se despedaça no primeiro quique em chão
# reto lá embaixo.
#
# SÓ COM A PERSONAGEM POR PERTO: o gerador liga enquanto ela estiver dentro da
# "area" (um ReferenceRect da fase). Entrou, a primeira bola sai na hora (ou
# depois do "atraso_inicial"); saiu, param de nascer bolas — as que já estão
# descendo terminam o caminho e se quebram normalmente.
#
# COMO EDITAR NO EDITOR
#   - Arraste o nó (a cruz do Marker2D) para onde a bola deve nascer.
#   - Arraste/redimensione o retângulo da "area" para mudar onde as bolas caem.
#   - O ritmo (intervalo, atraso) e o jeito da bola (pulinhos, gravidade, dano,
#     sons) ficam no Inspetor deste nó e valem para todas as bolas que ele
#     solta. A arte da bola fica na cena bola_quicante.tscn, no nó Sprite.

@export var cena_bola: PackedScene = preload("res://scenes/fases/componentes/bola_quicante.tscn")
## Retângulo da fase em que a personagem precisa estar para as bolas caírem.
## Vazio = caem sempre.
@export var area: ReferenceRect
## Tempo entre uma bola e a próxima.
@export_range(0.2, 30.0, 0.1, "suffix:s") var intervalo: float = 2.5
## Espera entre a personagem entrar na área e a primeira bola.
@export_range(0.0, 30.0, 0.1, "suffix:s") var atraso_inicial: float = 0.0
## Limite de bolas vivas ao mesmo tempo.
@export_range(1, 30) var maximo_simultaneas: int = 6

@export_group("Bola")
## Velocidade para o lado em cada pulinho.
@export_range(0.0, 1500.0, 5.0, "suffix:px/s") var velocidade_horizontal: float = 260.0
## Impulso para cima em cada quique: é o que define a altura dos pulinhos.
@export_range(50.0, 2000.0, 10.0, "suffix:px/s") var forca_quique: float = 600.0
@export_range(100.0, 6000.0, 10.0, "suffix:px/s²") var gravidade: float = 1800.0
@export var dano: int = 1
## Tremor da câmera quando a bola se despedaça (0 = nenhum).
@export_range(0.0, 20.0, 0.1) var tremor_ao_quebrar: float = 3.0

@export_group("Sons")
## Vazios por enquanto: a bola ainda não tem som.
@export var som_quique: AudioStream
@export var som_quebra: AudioStream

## A personagem está na área (e o relógio está correndo).
var ligado := false

var _bolas: Array[Node] = []
var _relogio: Timer


func _ready() -> void:
	_relogio = Timer.new()
	_relogio.name = "Relogio"
	_relogio.one_shot = true
	_relogio.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_relogio.timeout.connect(_ao_estourar_relogio)
	add_child(_relogio)


func _physics_process(_delta: float) -> void:
	var dentro := _personagem_na_area()
	if dentro == ligado:
		return
	ligado = dentro
	if not ligado:
		_relogio.stop()
	elif atraso_inicial > 0.0:
		_relogio.start(atraso_inicial)
	else:
		_ao_estourar_relogio()


func _personagem_na_area() -> bool:
	if area == null:
		return true
	var jogador := get_tree().get_first_node_in_group("player") as Node2D
	return jogador != null and area.get_global_rect().has_point(jogador.global_position)


func _ao_estourar_relogio() -> void:
	_relogio.start(intervalo)
	if _pode_soltar():
		soltar()


func _pode_soltar() -> bool:
	for i in range(_bolas.size() - 1, -1, -1):
		if not is_instance_valid(_bolas[i]):
			_bolas.remove_at(i)
	return _bolas.size() < maximo_simultaneas


## Solta uma bola agora, fora do ritmo do relógio.
func soltar() -> BolaQuicante:
	var bola := cena_bola.instantiate() as BolaQuicante
	bola.velocidade_horizontal = velocidade_horizontal
	bola.forca_quique = forca_quique
	bola.gravidade = gravidade
	bola.dano = dano
	bola.tremor_ao_quebrar = tremor_ao_quebrar
	bola.som_quique = som_quique
	bola.som_quebra = som_quebra
	bola.position = get_parent().to_local(global_position)
	get_parent().add_child(bola)
	_bolas.append(bola)
	return bola
