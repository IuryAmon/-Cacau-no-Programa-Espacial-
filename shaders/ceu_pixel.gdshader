// O céu em pixel art: degradê em faixas, estrelas e o clarão do astro.
//
// Tudo aqui é contado em "pixels de arte" — quadrados do tamanho de um pixel do
// cenário (`pixel`, em unidades da camada). É isso que deixa o céu com a mesma
// granulação do resto do fundo em vez de um degradê liso de foto: cada célula
// tem uma cor só, e a passagem de uma faixa para a outra é feita em pontilhado,
// como se pinta à mão.
//
// Quem preenche os uniformes é o `ceu_pixel.gd`, com as cores do PerfilDeLuz do
// momento. Não há textura: é só conta.
shader_type canvas_item;
render_mode unshaded;

group_uniforms degrade;
uniform vec4 cor_zenite : source_color = vec4(0.36, 0.42, 0.62, 1.0);
uniform vec4 cor_alto : source_color = vec4(0.66, 0.56, 0.6, 1.0);
uniform vec4 cor_baixo : source_color = vec4(0.96, 0.72, 0.5, 1.0);
uniform vec4 cor_horizonte : source_color = vec4(1.0, 0.88, 0.64, 1.0);
/// Onde ficam as duas cores do meio, de 0 (zênite) a 1 (horizonte).
uniform float parada_alto : hint_range(0.05, 0.9) = 0.42;
uniform float parada_baixo : hint_range(0.1, 0.98) = 0.78;
/// Altura (na camada) em que o degradê começa e termina.
uniform float y_zenite = -180.0;
uniform float y_horizonte = 300.0;
group_uniforms;

group_uniforms pixel_art;
/// Tamanho do pixel de arte, em unidades da camada.
uniform float pixel = 2.0;
/// Quantas faixas de cor o degradê tem.
uniform float degraus : hint_range(2.0, 48.0, 1.0) = 16.0;
/// Quanto de cada faixa é pontilhado na emenda com a próxima (0 = faixas secas).
uniform float pontilhado : hint_range(0.0, 1.0) = 0.6;
/// 0 = pontilhado em xadrez (Bayer), 1 = em linhas deitadas.
uniform float trama : hint_range(0.0, 1.0, 1.0) = 0.0;
group_uniforms;

group_uniforms astro;
/// Posição do astro na camada. Preenchido pelo script.
uniform vec2 astro = vec2(0.0);
/// Quanto as faixas embarrigam em volta dele.
uniform float clarao : hint_range(0.0, 1.0) = 0.0;
uniform vec2 raio_do_clarao = vec2(360.0, 150.0);
group_uniforms;

group_uniforms estrelas_do_ceu;
uniform float estrelas : hint_range(0.0, 1.0) = 0.0;
/// Fração das células que tem estrela.
uniform float densidade : hint_range(0.0, 0.1) = 0.002;
/// Tamanho do pixel das estrelas, em unidades da camada. Menor que `pixel`, elas
/// ficam mais finas que a granulação do céu; a quantidade não muda.
uniform float pixel_das_estrelas = 1.0;
/// Uma estrela grande (em cruz) a cada tantas células.
uniform float malha_das_grandes = 26.0;
uniform vec4 cor_das_estrelas : source_color = vec4(0.75, 0.79, 1.0, 1.0);
uniform float cintilar : hint_range(0.0, 2.0) = 1.0;
group_uniforms;

varying vec2 local;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);
const float LINHAS[4] = float[4](0.125, 0.625, 0.375, 0.875);

// Limiar do pontilhado desta célula, de 0 a 1.
float limiar(vec2 cel) {
	ivec2 i = ivec2(mod(cel, 4.0));
	float xadrez = (BAYER[i.x + i.y * 4] + 0.5) / 16.0;
	return mix(xadrez, LINHAS[i.y], trama);
}

// Sorteio estável por célula (hash sem seno: não desanda em GPU nenhuma).
float sorteio(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 rampa(float t) {
	vec3 c = mix(cor_zenite.rgb, cor_alto.rgb, clamp(t / parada_alto, 0.0, 1.0));
	c = mix(c, cor_baixo.rgb, clamp((t - parada_alto) / (parada_baixo - parada_alto), 0.0, 1.0));
	c = mix(c, cor_horizonte.rgb, clamp((t - parada_baixo) / (1.0 - parada_baixo), 0.0, 1.0));
	return c;
}

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 cel = floor(local / pixel);
	vec2 centro = (cel + 0.5) * pixel;

	// ------------------------------------------------------------ degradê
	float t = clamp((centro.y - y_zenite) / (y_horizonte - y_zenite), 0.0, 1.0);

	// Perto do astro o céu é mais claro: empurramos a conta rumo ao horizonte e
	// as faixas fazem arco em volta dele.
	vec2 d = (centro - astro) / raio_do_clarao;
	float perto = exp(-dot(d, d));
	float tc = clamp(t + clarao * perto * (1.0 - t * 0.35), 0.0, 1.0);

	float f = tc * degraus;
	float faixa = floor(f);
	// Só o fim de cada faixa é pontilhado; o resto é cor chapada.
	float emenda = clamp((fract(f) - (1.0 - pontilhado)) / max(pontilhado, 0.0001), 0.0, 1.0);
	faixa = min(faixa + step(limiar(cel), emenda), degraus);
	vec3 cor = rampa(faixa / degraus);

	// ------------------------------------------------------------ estrelas
	if (estrelas > 0.001) {
		// Rareiam rumo ao horizonte e somem no clarão do astro.
		float mascara = smoothstep(1.0, 0.5, t) * (1.0 - clamp(perto * clarao * 2.2, 0.0, 1.0));

		// As estrelas têm a grade delas, mais fina que a do céu. `densidade` e
		// `malha_das_grandes` continuam contadas em células do céu, então mudar o
		// tamanho da estrela não muda quantas são.
		float pe = max(pixel_das_estrelas, 0.01);
		float razao = pe / pixel;
		vec2 ce = floor(local / pe);
		float malha = max(floor(malha_das_grandes / razao), 6.0);

		// Miúdas: um pixel só. A grandeza decide o brilho e a ordem de acender.
		float grandeza = sorteio(ce + 71.7);
		float tem = step(sorteio(ce), densidade * razao * razao * mascara) * step(1.0 - estrelas, grandeza);
		float fase = sorteio(ce + 13.1);
		float ritmo = mix(0.25, 0.9, sorteio(ce + 5.3)) * cintilar;
		// Metade delas pisca, em dois tons secos — nada de brilho ondulando.
		float pisca = mix(1.0, step(0.22, fract(TIME * ritmo + fase)), step(0.5, fase));
		float brilho = tem * mix(0.3, 1.0, grandeza * grandeza) * mix(0.45, 1.0, pisca);

		// Grandes: uma por bloco, em cruz, com os braços piscando.
		vec2 bloco = floor(ce / malha);
		float sb = sorteio(bloco + 3.3);
		vec2 miolo = bloco * malha + 2.0
			+ floor(vec2(sorteio(bloco + 9.1), sorteio(bloco + 4.7)) * (malha - 4.0));
		vec2 dc = abs(ce - miolo);
		float dist = dc.x + dc.y;
		// A máscara é a do miolo, senão a cruz sairia cortada na divisa.
		float tg = clamp(((miolo.y + 0.5) * pe - y_zenite) / (y_horizonte - y_zenite), 0.0, 1.0);
		float tem_grande = step(sb, min(densidade * 40.0, 1.0) * smoothstep(0.9, 0.35, tg)) * step(1.0 - estrelas, 0.55 + 0.45 * sb);
		float acesa = step(0.4, fract(TIME * 0.35 * cintilar + sb * 7.0));
		float grande = tem_grande * (step(dist, 0.5) + (step(dist, 1.5) - step(dist, 0.5)) * 0.5 * acesa);
		grande *= 1.0 - clamp(perto * clarao * 2.2, 0.0, 1.0);

		// Um fio de cor: algumas puxam para o quente.
		vec3 tom = mix(cor_das_estrelas.rgb, vec3(1.0, 0.93, 0.82), step(0.86, fase));
		cor += tom * clamp(brilho + grande, 0.0, 1.0) * estrelas;
	}

	COLOR = vec4(cor, 1.0);
}
