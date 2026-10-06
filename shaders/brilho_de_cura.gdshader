shader_type canvas_item;
// Luz própria: o clarão não escurece no blecaute nem pega o tom do céu.
render_mode unshaded;

// --- BRILHO DE CURA (a Cacau acendendo quando a vida volta) ---
//
// Vai num Sprite2D que copia o quadro da personagem e fica por cima dela (ver
// scripts/fx/brilho_de_cura.gd). No lugar das cores do desenho ele pinta só a
// SILHUETA: "corpo" cobre o desenho inteiro com "cor", e "contorno" acende
// 1 texel em volta dele, num tom mais claro.
//
// O contorno é medido nos vizinhos do texel, então o quadro precisa de ao
// menos 1 texel transparente de folga em volta do desenho.

uniform vec4 cor : source_color = vec4(0.24, 0.94, 0.60, 1.0);
uniform float corpo : hint_range(0.0, 1.0) = 0.0;
uniform float contorno : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float desenho = texture(TEXTURE, UV).a;
	vec2 passo = TEXTURE_PIXEL_SIZE;
	float vizinhos = texture(TEXTURE, UV + vec2(passo.x, 0.0)).a;
	vizinhos = max(vizinhos, texture(TEXTURE, UV - vec2(passo.x, 0.0)).a);
	vizinhos = max(vizinhos, texture(TEXTURE, UV + vec2(0.0, passo.y)).a);
	vizinhos = max(vizinhos, texture(TEXTURE, UV - vec2(0.0, passo.y)).a);
	float linha = clamp(vizinhos - desenho, 0.0, 1.0);

	vec3 cor_da_linha = mix(cor.rgb, vec3(1.0), 0.55);
	float alfa_corpo = desenho * corpo;
	float alfa_linha = linha * contorno;
	float alfa = alfa_corpo + alfa_linha;
	COLOR = vec4((cor.rgb * alfa_corpo + cor_da_linha * alfa_linha) / max(alfa, 0.0001), alfa);
}
