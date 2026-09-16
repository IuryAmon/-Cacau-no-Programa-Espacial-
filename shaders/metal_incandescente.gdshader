shader_type canvas_item;

// --- METAL INCANDESCENTE ---
//
// Esquenta QUALQUER sprite de metal sem repintar um único quadro: em vez de
// jogar um vermelho por cima (que achataria o desenho numa silhueta), cada
// pixel é trocado por um ponto da curva de corpo negro — vermelho escuro ->
// laranja -> amarelo -> branco — escolhido pelo BRILHO original daquele pixel.
//
// É assim que o metal quente funciona de verdade: a chapa inteira sobe de
// temperatura junto, então o que era realce vira branco-fusão e o que era
// sombra fica no vermelho. O relevo do pixel art continua legível do começo ao
// fim, e a porta volta EXATAMENTE à arte original quando "calor" chega a zero.
//
// Quem liga e desliga isto é scripts/fases/porta_metal_macarico.gd — um tween
// sobe o calor no pré-aquecimento e outro desce enquanto a poça esfria.

// 0 = metal frio (sprite intocado)   1 = ponto de fusão
uniform float calor : hint_range(0.0, 1.0) = 0.0;

// Quanto o TOPO fica mais quente que a base. A chama do maçarico entra por
// cima, então a folha em pé derrete de cima para baixo; quando ela vira poça
// no chão o script zera isto e o calor passa a ser igual em tudo.
uniform float gradiente_vertical : hint_range(0.0, 1.0) = 0.35;

// Tremida da brasa — sem ela o metal quente parece uma lâmpada parada.
uniform float tremor : hint_range(0.0, 0.5) = 0.1;
uniform float velocidade_tremor : hint_range(0.0, 30.0) = 7.0;

// Clareamento extra no auge. Acima de 1.0 estoura para branco, que é o que dá
// a leitura de "luz saindo do metal" e não de "metal pintado de laranja".
uniform float brilho : hint_range(1.0, 3.0) = 1.55;


// Curva de corpo negro em quatro paradas (brasa -> fusão).
vec3 corpo_negro(float t) {
	vec3 c = mix(vec3(0.30, 0.02, 0.01), vec3(0.95, 0.20, 0.03), smoothstep(0.00, 0.35, t));
	c = mix(c, vec3(1.00, 0.55, 0.08), smoothstep(0.30, 0.65, t));
	c = mix(c, vec3(1.00, 0.88, 0.45), smoothstep(0.60, 0.88, t));
	c = mix(c, vec3(1.00, 0.98, 0.90), smoothstep(0.85, 1.00, t));
	return c;
}


void fragment() {
	vec4 cor = texture(TEXTURE, UV) * COLOR;

	// Frio ou transparente: a arte passa intacta, sem custo nenhum.
	if (calor <= 0.001 || cor.a <= 0.001) {
		COLOR = cor;
	} else {
		// UV.y é seguro aqui mesmo com AtlasTexture: os quadros do sheet de
		// derretimento ocupam a altura inteira da imagem, então 0 = topo e
		// 1 = base tanto na folha quanto na poça.
		float altura = 1.0 - UV.y;
		float perfil = mix(1.0, altura, gradiente_vertical);
		float tremida = 1.0 + tremor * sin(TIME * velocidade_tremor + UV.y * 14.0 + UV.x * 5.0);

		float t = clamp(calor * perfil * tremida, 0.0, 1.0);

		// O brilho original do pixel escolhe a temperatura LOCAL: é o que
		// preserva o desenho (realces viram fusão, sombras ficam em brasa).
		float luminancia = dot(cor.rgb, vec3(0.2126, 0.7152, 0.0722));
		float temperatura = clamp(t * (0.45 + 1.05 * luminancia), 0.0, 1.0);

		vec3 brasa = corpo_negro(temperatura);

		// O pé da curva de corpo negro é mais ESCURO que a chapa cinzenta, e
		// usá-lo cru fazia o metal passar por um marrom sujo de "queimado"
		// antes de acender. Aço esquentando não escurece: ele ganha cor sem
		// perder valor. Então, no começo, a brasa é reescalada para o brilho
		// do desenho original, e só vai assumindo o brilho próprio dela
		// conforme o calor sobe.
		float lum_brasa = dot(brasa, vec3(0.2126, 0.7152, 0.0722));
		float alvo = mix(luminancia, lum_brasa, smoothstep(0.0, 0.6, t));
		brasa *= alvo / max(lum_brasa, 0.001);
		brasa *= 1.0 + (brilho - 1.0) * t;

		// A troca entra rápido (smoothstep curto) para o metal não passar um
		// tempo longo "meio pintado", que é onde o efeito ficaria de plástico.
		COLOR = vec4(mix(cor.rgb, brasa, smoothstep(0.0, 0.30, t)), cor.a);
	}
}
