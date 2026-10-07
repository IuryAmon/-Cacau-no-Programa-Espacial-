// Nuvem que muda de cor com a hora.
//
// As nuvens do pacote são pintadas em três tons — branco em cima, um cinza
// claro no meio e o azulado da barriga. Aqui cada tom é trocado pela cor do
// horário: o branco vira a cor da luz, o azulado vira a cor da sombra, e o do
// meio cai entre as duas. Os degraus da arte continuam degraus; nada é borrado.
//
// Quem preenche é o `nuvens.gd`. O alfa do vértice (o `modulate` de cada nuvem)
// é a transparência dela — as do fundo são mais apagadas.
shader_type canvas_item;
render_mode unshaded;

uniform vec4 cor_luz : source_color = vec4(1.0);
uniform vec4 cor_sombra : source_color = vec4(0.82, 0.89, 0.95, 1.0);
/// Cor do ar, para onde as nuvens distantes desbotam.
uniform vec4 ar : source_color = vec4(0.8, 0.85, 0.95, 1.0);
uniform float neblina : hint_range(0.0, 1.0) = 0.0;
uniform float opacidade : hint_range(0.0, 1.0) = 1.0;

// O vermelho dos três tons da arte: 255 (luz), 236 (meio) e 209 (sombra).
const float TOM_DA_SOMBRA = 0.8196;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float claro = clamp((t.r - TOM_DA_SOMBRA) / (1.0 - TOM_DA_SOMBRA), 0.0, 1.0);
	vec3 rgb = mix(cor_sombra.rgb, cor_luz.rgb, claro);
	rgb = mix(rgb, ar.rgb, neblina);
	COLOR = vec4(rgb, t.a * COLOR.a * opacidade);
}
