extends Node2D

# --- ENCERRAMENTO: EM ÓRBITA ---
#
# O fecho do plano: em órbita, gotículas de água no vidro — o produto da
# primeira reação do jogo — com a Terra ao fundo.
#
# COMO EDITAR NO EDITOR: tudo aqui é nó comum. A Terra é o nó Terra (troque
# por um Sprite2D com a sua arte), as gotas vivem em Gotas, a moldura da
# janela em Moldura e os textos em Texto/Rodape.
#
# (A sequência opcional da ascensão — o shoot 'em up de balanceamento do
# simulador — pode ser encaixada ANTES desta cena mais tarde.)

func _ready() -> void:
	FadeTela.clarear_na_chegada(self, 1.2)


func _process(_delta: float) -> void:
	if Interacao.pediu():
		Progresso.spawn_tag = ""
		FadeTela.trocar_cena(self, EstadoMundo.CENA_WORLD2)
