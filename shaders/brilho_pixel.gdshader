// Brilho em pixel art: anéis chapados em volta de uma fonte de luz, com a
// emenda entre um anel e o outro feita em pontilhado.
//
// É o halo do sol e da lua (`astro_pixel.gd`). Em vez de um degradê liso que
// desmancha no céu, a luz cai em degraus — cada anel tem uma cor só — e os
// degraus respiram em quadros secos, um pixel para fora e um para dentro, como
// um sprite animado à mão.
//
// O anel pode COBRIR o céu ou SOMAR nele (`cobertura`):
//   * somando (0), o halo só clareia — é o que funciona num céu escuro, onde
//     há espaço para clarear (a lua);
//   * cobrindo (1), cada anel é uma tinta por cima do céu — é o que funciona
//     num céu que já é claro, onde somar estoura tudo no branco e os degraus
//     somem (o sol do entardecer).
shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

/// Raio da fonte (o disco), em pixels de arte. O brilho começa na borda dela.
uniform float raio_do_disco = 16.0;
/// Até onde o brilho chega, a partir do centro.
uniform float raio = 84.0;
/// Quantos anéis.
uniform float aneis : hint_range(1.0, 12.0, 1.0) = 5.0;
uniform vec4 cor_interna : source_color = vec4(1.0, 0.95, 0.66, 1.0);
uniform vec4 cor_externa : source_color = vec4(1.0, 0.56, 0.38, 1.0);
uniform float intensidade : hint_range(0.0, 2.0) = 0.9;
/// 0 = soma no que está atrás, 1 = cobre.
uniform float cobertura : hint_range(0.0, 1.0) = 1.0;
/// Curva da queda: maior aperta o brilho contra o disco.
uniform float queda : hint_range(0.3, 4.0) = 1.3;
/// Quanto de cada anel é pontilhado na emenda (0 = anéis secos).
uniform float pontilhado : hint_range(0.0, 1.0) = 0.5;
/// Achata o halo na vertical (1 = redondo).
uniform float achatamento : hint_range(0.3, 3.0) = 1.0;

group_uniforms raios_de_luz;
/// Quantas pontas (0 = sem pontas).
uniform float pontas : hint_range(0.0, 24.0, 1.0) = 0.0;
/// Quanto as pontas avançam além do halo.
uniform float alcance_das_pontas : hint_range(0.0, 1.0) = 0.35;
uniform float largura_das_pontas : hint_range(0.05, 1.0) = 0.42;
group_uniforms;

group_uniforms animacao;
/// Quadros por segundo da respiração (0 = parado).
uniform float quadros_por_segundo : hint_range(0.0, 12.0) = 2.0;
/// Quanto os anéis andam de um quadro para o outro, em anéis.
uniform float respiro : hint_range(0.0, 1.0) = 0.18;
group_uniforms;

varying vec2 local;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void vertex() {
	local = VERTEX;
}

void fragment() {
	// A cor do vértice é o `modulate` de quem desenha: a tinta e a presença do
	// astro chegam por ela.
	vec4 tinta = COLOR;
	vec2 cel = floor(local);
	vec2 p = (cel + 0.5) * vec2(1.0, achatamento);
	float d = length(p);

	float quadro = floor(TIME * quadros_por_segundo);
	float par = mod(quadro, 2.0);

	// As pontas alongam o halo ao longo de cada raio. As pares e as ímpares
	// trocam de tamanho a cada quadro — o brilho "gira" sem girar.
	float alcance = raio;
	if (pontas > 0.5) {
		float setor = 6.28318530718 / pontas;
		float ang = atan(p.y, p.x) + setor * 0.5;
		float indice = floor(ang / setor);
		float eixo = abs(fract(ang / setor) - 0.5) * 2.0;
		float ponta = max(0.0, 1.0 - eixo / largura_das_pontas);
		float longa = mod(indice + par, 2.0);
		alcance += (raio - raio_do_disco) * alcance_das_pontas * ponta * mix(0.45, 1.0, longa);
	}

	float k = clamp((d - raio_do_disco) / max(alcance - raio_do_disco, 0.001), 0.0, 1.0);
	float nivel = pow(1.0 - k, queda);

	float f = nivel * aneis + par * respiro;
	float anel = floor(f);
	ivec2 i = ivec2(mod(cel, 4.0));
	float limiar = (BAYER[i.x + i.y * 4] + 0.5) / 16.0;
	// Só o começo de cada anel (a borda de fora) é pontilhado.
	float emenda = clamp(fract(f) / max(pontilhado, 0.0001), 0.0, 1.0);
	anel = anel - 1.0 + step(limiar, emenda);
	float a = clamp(anel / aneis, 0.0, 1.0);

	vec3 cor = mix(cor_externa.rgb, cor_interna.rgb, a) * tinta.rgb;
	float forca = clamp(a * intensidade * tinta.a, 0.0, 1.0);
	// Alfa pré-multiplicado: o RGB entra somando, o alfa diz quanto do fundo
	// sai. Com cobertura 0 o fundo fica inteiro (soma pura).
	COLOR = vec4(cor * forca, forca * cobertura);
}
