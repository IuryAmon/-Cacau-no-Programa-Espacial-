shader_type canvas_item;

// --- DESLOCAR MATIZ ---
//
// Gira a matiz só das cores VIVAS do sprite (laranja, amarelo, vermelho...),
// deixando contorno escuro, preto e brilhos brancos como estão. Serve para
// fazer uma variação de cor de uma arte sem duplicar o PNG.
//
// giro_matiz: 0.0 = cor original, 0.5 = cor oposta no círculo cromático
// (o laranja da Plataformas.png vira azul-ciano), 0.33 = verde, 0.75 = roxo.

uniform float giro_matiz : hint_range(0.0, 1.0) = 0.5;
// Pixels menos saturados que isto (cinzas, contorno) não mudam de cor.
uniform float saturacao_minima : hint_range(0.0, 1.0) = 0.35;
// Pixels mais escuros que isto (sombras, contorno) não mudam de cor.
uniform float valor_minimo : hint_range(0.0, 1.0) = 0.35;
// Multiplica o brilho das cores giradas.
uniform float brilho : hint_range(0.0, 2.0) = 1.0;

vec3 rgb_para_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_para_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	// COLOR já chega como textura x modulate.
	vec3 hsv = rgb_para_hsv(COLOR.rgb);
	float viva = step(saturacao_minima, hsv.y) * step(valor_minimo, hsv.z);
	vec3 girada = hsv_para_rgb(vec3(fract(hsv.x + giro_matiz), hsv.y, clamp(hsv.z * brilho, 0.0, 1.0)));
	COLOR.rgb = mix(COLOR.rgb, girada, viva);
}
