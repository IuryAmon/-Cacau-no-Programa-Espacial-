extends CanvasLayer

# Casca do HUD de vida da Cacau. Existe só para dois motivos:
#   1. manter o caminho "Player/CanvasLayer/HealthHUD" que o resto do jogo usa;
#   2. repassar o sinal "health_changed" do player para o HudVital, que é quem
#      de fato desenha tudo (scripts/ui/hud_vital.gd).

var _hud: HudVital


## Recebe direto o sinal "health_changed" do player.
func update_health(vida_atual: int) -> void:
	var alvo := _obter_hud()
	if alvo:
		alvo.definir_vida(float(vida_atual))


## Chamado pelo player no _ready para o HUD nascer com o número certo de células.
func definir_vida_maxima(vida_maxima: int) -> void:
	var alvo := _obter_hud()
	if alvo:
		alvo.definir_vida_maxima(float(vida_maxima))


# Busca preguiçosa em vez de @onready: assim o HUD responde mesmo se alguém
# chamar antes do _ready deste nó.
func _obter_hud() -> HudVital:
	if not is_instance_valid(_hud):
		_hud = get_node_or_null("HudVital") as HudVital
	return _hud
