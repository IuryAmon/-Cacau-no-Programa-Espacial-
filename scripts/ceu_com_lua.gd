extends Control

# --- O CÉU ESTRELADO COM A LUA ---
#
# Uma imagem da introdução (scripts/introducao.gd), montada com o que o jogo já
# tem: o céu da noite das fases (o shader do CeuPixel, nas cores de
# assets/luz/noite.tres, com as estrelas piscando) e a lua do pátio (a mesma
# arte e o mesmo brilho do AstroPixel). A cena cobre a telinha inteira e corta
# o que passar da borda.
#
# A LUA ESPERA A DEIXA: o quadro abre só com o céu estrelado ("Décadas depois,
# o Brasil partiria para sua maior missão…") e a lua aparece, acendendo junto
# com o clarão em volta dela, quando a página "pagina_da_lua" começa ("...a
# Lua!"). Quem avisa a página é a introdução (pagina_aberta).
#
# ONDE MEXER (scenes/ceu_com_lua.tscn):
#   o nó Lua        arraste para mudar o lugar dela; a escala muda o tamanho;
#   o nó Ceu        o tamanho do pixel e a quantidade de estrelas, no material;
#   a raiz          em que página a lua aparece e quanto ela leva acendendo.

const PERFIL := preload("res://assets/luz/noite.tres")
## Onde o degradê chega à cor do horizonte, em frações da altura (passa um
## pouco do pé da imagem: o céu todo fica no tom fundo da noite).
const HORIZONTE := 1.15

## A página do quadro (contando do 0) em que a lua aparece. -1: ela já está lá
## desde o começo.
@export var pagina_da_lua := 1
## Segundos da lua acendendo.
@export var acender_a_lua := 1.2

@onready var ceu: ColorRect = $Ceu
@onready var lua: Sprite2D = $Lua

var _tween: Tween


func _ready() -> void:
	var material := ceu.material as ShaderMaterial
	material.set_shader_parameter(&"cor_zenite", PERFIL.ceu_zenite)
	material.set_shader_parameter(&"cor_alto", PERFIL.ceu_alto)
	material.set_shader_parameter(&"cor_baixo", PERFIL.ceu_baixo)
	material.set_shader_parameter(&"cor_horizonte", PERFIL.ceu_horizonte)
	material.set_shader_parameter(&"estrelas", PERFIL.estrelas)
	_por_a_lua(0.0 if pagina_da_lua >= 0 else 1.0)
	resized.connect(_ajustar)
	_ajustar()


## A introdução avisa: a página [param indice] do quadro começou.
func pagina_aberta(indice: int) -> void:
	if pagina_da_lua < 0 or indice != pagina_da_lua:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_por_a_lua, lua.modulate.a, 1.0, acender_a_lua)


## Quanto da lua existe: o disco, o brilho dele e o clarão no céu.
func _por_a_lua(quanto: float) -> void:
	lua.modulate.a = quanto
	(ceu.material as ShaderMaterial).set_shader_parameter(&"clarao", PERFIL.clarao * quanto)


func lua_visivel() -> float:
	return lua.modulate.a


func _ajustar() -> void:
	var material := ceu.material as ShaderMaterial
	material.set_shader_parameter(&"y_zenite", 0.0)
	material.set_shader_parameter(&"y_horizonte", size.y * HORIZONTE)
	# O céu clareia em volta da lua.
	material.set_shader_parameter(&"astro", lua.position)
