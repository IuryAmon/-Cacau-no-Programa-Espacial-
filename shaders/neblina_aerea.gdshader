// Perspectiva aérea das camadas de parallax.
//
// Quanto mais longe a camada, mais ela perde contraste e desbota na cor do
// céu, que é como o olho lê profundidade. Perto do sol, além disso, a camada
// MERGULHA no brilho do ar (espalhamento) em vez de acender — é por isso que
// um morro contra o sol some no clarão em vez de dourar. Isto é fisicamente
// honesto: estas camadas ficam entre o sol e a câmera, logo o sol bate nas
// costas delas, e multiplicá-las por uma tinta quente acenderia a face errada.
//
// [b]Sem rim de borda aqui.[/b] Uma versão anterior detectava a silhueta pelo
// alfa cru da textura — opaco aqui, vazio rumo ao sol — e acendia um fio de luz
// na borda. Para uma camada cuja arte já é quase a cor do céu (as bandas de
// neblina distante, feitas pra desaparecer), a borda entre opaco e transparente
// ainda é um degrau de pixel bem definido, sem antialiasing algum, e virava uma
// escadinha visível de luz e sombra recortada contra o céu — um fantasma de
// montanha que ninguém devia ver. O contorno de verdade, para objetos que têm
// contraste real contra o que está atrás deles, já é feito uma vez só, no passe
// final (`luz_do_sol.gdshader`), que mede contraste de cor na tela composta em
// vez de alfa cru da textura — e por isso não cai nessa armadilha.
shader_type canvas_item;

group_uniforms distancia;
uniform vec4 cor_neblina : source_color = vec4(0.80, 0.85, 0.95, 1.0);
uniform float forca : hint_range(0.0, 1.0) = 0.22;
uniform float contraste : hint_range(0.0, 2.0) = 0.94;
group_uniforms;

group_uniforms contraluz;
uniform vec4 cor_sol : source_color = vec4(1.0, 0.85, 0.60, 1.0);
/// Quanto a camada mergulha no brilho do ar perto do sol.
uniform float calor : hint_range(0.0, 1.0) = 0.30;
uniform float alcance_calor : hint_range(0.1, 4.0) = 1.1;
group_uniforms;

// Preenchidos por `iluminacao_solar.gd` — não mexa na mão.
uniform vec2 sol_uv = vec2(0.74, 0.22);
uniform float aspecto = 1.7777;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec3 rgb = base.rgb;

	// Achatar o contraste antes de desbotar: distância também come o preto.
	rgb = clamp((rgb - 0.5) * contraste + 0.5, vec3(0.0), vec3(1.0));
	rgb = mix(rgb, cor_neblina.rgb, forca);

	// Direção e distância até o sol, em pixels (x esticado pelo aspecto).
	vec2 d = vec2((sol_uv.x - SCREEN_UV.x) * aspecto, sol_uv.y - SCREEN_UV.y);
	float prox = exp(-length(d) / alcance_calor);

	// Espalhamento: a camada some no ar em vez de acender.
	rgb = mix(rgb, cor_sol.rgb, prox * calor);
	rgb += cor_sol.rgb * (prox * prox * calor * 0.22);

	COLOR = vec4(rgb, base.a);
}
