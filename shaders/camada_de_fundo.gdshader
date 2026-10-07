// O tom de uma camada do parallax conforme a hora.
//
// Duas contas, e a ordem delas é a física do negócio:
//
//   1. a luz do horário bate na arte (multiplica) — ao entardecer esquenta, à
//      noite derruba tudo para o azul;
//   2. o ar entre a câmera e a camada come o que sobrou (mistura na cor do ar),
//      tanto mais quanto mais longe ela está. É assim que o olho lê distância:
//      a serra do fundo quase vira céu, o pinheiro da frente fica inteiro.
//
// Ninguém põe este material na mão. A `Atmosfera` veste com ele toda camada do
// fundo que não tenha material próprio, e preenche as cores a partir do
// PerfilDeLuz do momento. A profundidade sai do `motion_scale` da ParallaxLayer
// (quem anda menos está mais longe) ou do metadado `profundidade`, se houver.
shader_type canvas_item;
render_mode unshaded;

/// Luz do horário batendo na camada.
uniform vec4 luz : source_color = vec4(1.0);
/// Cor do ar.
uniform vec4 ar : source_color = vec4(0.8, 0.85, 0.95, 1.0);
/// Quanto o ar come esta camada: profundidade × neblina do perfil.
uniform float neblina : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec3 rgb = mix(base.rgb * luz.rgb, ar.rgb, neblina);
	COLOR = vec4(rgb, base.a);
}
