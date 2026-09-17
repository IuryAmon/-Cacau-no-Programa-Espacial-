shader_type canvas_item;

// --- SILHUETA COM CONTORNO (a vaga do item na tela do computador) ---
//
// Desenha o sprite chapado em "cor_silhueta" com um contorno de 1 texel em
// "cor_contorno" — preto com fio branco, para a vaga aparecer sobre a tela
// preta do computador.
//
// "aceso" enche o sprite com as cores dele DE BAIXO PARA CIMA, como um tanque
// sendo abastecido, com uma linha de luz na frente do enchimento. Quando o
// enchimento termina, o contorno já assumiu "cor_acesa" (a cor do item).
// "clarao" pinta tudo de branco por cima: é o estalo do instante em que acende.
//
// O contorno é medido nos vizinhos do texel, então a textura precisa de ao
// menos 1 texel transparente de folga em volta (o puzzle monta essa folga).

uniform vec4 cor_silhueta : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 cor_contorno : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cor_acesa : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float aceso : hint_range(0.0, 1.0) = 0.0;
uniform float clarao : hint_range(0.0, 1.0) = 0.0;
uniform float espessura : hint_range(0.0, 4.0) = 1.0;

// No fragment, COLOR já vem multiplicado pela textura — e o contorno mora
// justamente onde a textura é transparente. O modulate do nó vem por aqui.
varying vec4 modulacao;

void vertex() {
	modulacao = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 passo = TEXTURE_PIXEL_SIZE * espessura;
	float vizinhos = texture(TEXTURE, UV + vec2(passo.x, 0.0)).a;
	vizinhos = max(vizinhos, texture(TEXTURE, UV - vec2(passo.x, 0.0)).a);
	vizinhos = max(vizinhos, texture(TEXTURE, UV + vec2(0.0, passo.y)).a);
	vizinhos = max(vizinhos, texture(TEXTURE, UV - vec2(0.0, passo.y)).a);
	float contorno = clamp(vizinhos - base.a, 0.0, 1.0);

	// Enchimento de baixo para cima: 1 abaixo do nível, 0 acima.
	float nivel = 1.0 - aceso;
	float cheio = step(nivel, UV.y) * step(0.001, aceso);
	// Faixa de luz de ~2 texels logo acima do nível, só durante o enchimento.
	float frente = (step(nivel - TEXTURE_PIXEL_SIZE.y * 2.0, UV.y) - step(nivel, UV.y))
		* step(0.001, aceso) * step(aceso, 0.999);

	vec3 corpo = mix(cor_silhueta.rgb, base.rgb, cheio);
	corpo = mix(corpo, mix(cor_acesa.rgb, vec3(1.0), 0.6), frente);
	vec3 linha = mix(cor_contorno.rgb, cor_acesa.rgb, smoothstep(0.6, 1.0, aceso));

	float alfa = max(base.a, contorno);
	vec3 rgb = (corpo * base.a + linha * contorno) / max(alfa, 0.0001);
	rgb = mix(rgb, vec3(1.0), clarao);

	COLOR = vec4(rgb, alfa) * modulacao;
}
