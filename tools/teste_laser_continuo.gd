extends SceneTree

# Teste dos LaserContinuo na Oficina do Carbono: cada raio vai de uma tampa de
# emissor até a outra e mata quem encosta.
#
#   godot --headless --fixed-fps 60 --path . -s res://tools/teste_laser_continuo.gd

const FASE := "res://scenes/fases/fase1_oficina.tscn"

## nome -> [boca de onde sai, boca onde chega]
const LASERS := {
	"LaserContinuo1": [Vector2(5898, -960), Vector2(6390, -960)],
	"LaserContinuo2": [Vector2(4938, -960), Vector2(5686, -960)],
	"LaserContinuo3": [Vector2(3658, -960), Vector2(4342, -960)],
	"LaserContinuo4": [Vector2(4640, -1366), Vector2(4640, -1066)],
}

var _falhas := 0


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	for nome in LASERS:
		await _abrir()
		var laser := current_scene.get_node(nome) as LaserContinuo
		_checar(laser != null, "%s está na fase" % nome)
		var pontas: Array = LASERS[nome]
		var fim := laser.to_global(Vector2(laser.comprimento, 0))
		_checar(laser.global_position.distance_to(pontas[0]) < 0.5 and fim.distance_to(pontas[1]) < 0.5,
			"%s vai de %s a %s (%s a %s)" % [nome, pontas[0], pontas[1], laser.global_position, fim])
		var forma := (laser.get_node("Hitbox/Colisao") as CollisionShape2D).shape as RectangleShape2D
		_checar(is_equal_approx(forma.size.x, laser.comprimento), "%s: hitbox do tamanho do raio" % nome)

		var player := current_scene.get_node("Player") as CharacterBody2D
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO
		player.global_position = (pontas[0] + pontas[1]) * 0.5
		player.esta_invencivel_dash = true
		for i in 5:
			await physics_frame
		_checar(player.current_health == 0, "%s mata no meio do raio, até dando dash" % nome)

	# Longe de tudo: vivo.
	await _abrir()
	var p := current_scene.get_node("Player") as CharacterBody2D
	p.set_physics_process(false)
	p.global_position = Vector2(6150, -960 - 44)
	for i in 10:
		await physics_frame
	_checar(p.current_health > 0, "passar logo acima do raio sem encostar não mata")

	print("RESULTADO: ", "tudo ok" if _falhas == 0 else "%d falha(s)" % _falhas)
	quit(_falhas)


func _abrir() -> void:
	change_scene_to_file(FASE)
	for i in 3:
		await process_frame


func _checar(ok: bool, nome: String) -> void:
	if not ok:
		_falhas += 1
	print(("  ok   " if ok else "  FALHA ") + nome)
