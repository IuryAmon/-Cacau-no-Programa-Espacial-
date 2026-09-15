shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	vec3 hsv = rgb_to_hsv(color.rgb);

	float hue = hsv.x;
	float sat = hsv.y;

	// Detecta pixels "vermelhos": hue perto de 0 ou de 1, com saturação relevante
	float is_red_low  = 1.0 - smoothstep(0.0, 0.12, hue);
	float is_red_high = 1.0 - smoothstep(0.0, 0.04, 1.0 - hue);
	float is_red = max(is_red_low, is_red_high) * smoothstep(0.15, 0.4, sat);

	// Desloca o hue +0.333 (120°) → vermelho vira verde, reduz brilho
	float shifted_hue = fract(hue + 0.333 * progress);
	float final_hue   = mix(hue, shifted_hue, is_red);
	float final_val   = hsv.z - is_red * progress * 0.28;

	color.rgb = hsv_to_rgb(vec3(final_hue, hsv.y, final_val));

	COLOR = color;
}
