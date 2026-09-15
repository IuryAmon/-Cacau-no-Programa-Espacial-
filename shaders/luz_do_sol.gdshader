// O passe solar: contraluz, feixes e atmosfera num desenho só.
//
// Este shader é a metade em tela do rig de `iluminacao_solar.gd`. Ele roda uma
// vez por quadro sobre o quadro já montado e resolve, em ordem, as três coisas
// que o sol faz com uma cena que está inteira na frente dele:
//
//   1. CONTRALUZ  — o sol mora na camada mais funda do parallax, então a face
//      que a câmera vê é a que fica em sombra. O corpo do que está recortado
//      contra a luz afunda e esfria, e só a borda virada para o sol devolve um
//      fio quente. Esse fio é a única parte do objeto que o sol alcança de
//      onde estamos olhando — e era exatamente o que o rig antigo errava, ao
//      pendurar uma PointLight2D no sol e acender a frente de todo mundo.
//
//   2. FEIXES     — marcha radial (Mitchell): de cada pixel caminhamos até o
//      sol somando o brilho encontrado no caminho. Onde há objeto opaco não há
//      brilho para somar, então o feixe morre atrás dele com a forma exata da
//      silhueta. É oclusão de verdade, não leque procedural por cima de tudo.
//
//   3. ATMOSFERA  — o ar entre a câmera e a cena. Perto do sol ele LAVA e SOMA
//      (espalhamento), nunca multiplica: multiplicar pintaria o objeto como se
//      ele estivesse virado para a luz. Longe do sol a cena cai para o azul da
//      sombra aberta. Fecha com graduação, vinheta, óptica de lente e dither.
//
// Os três estágios moram no mesmo shader de propósito. Encadeados como passes
// separados, cada um pedindo `hint_screen_texture`, o último lê uma cópia do
// backbuffer anterior à execução dos outros e apaga o trabalho deles — foi o
// que aconteceu na primeira versão. Num passe só há uma leitura, uma escrita e
// um terço do custo.
//
// Para desligar um estágio, zere a força dele (`forca_rim`, `intensidade`,
// `lavagem`...): o `if` correspondente sai do caminho.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;

// Preenchidos por `iluminacao_solar.gd` — não mexa na mão.
uniform vec2 sol_uv = vec2(0.75, 0.37);
uniform float aspecto = 1.7777;
uniform float visibilidade : hint_range(0.0, 1.0) = 1.0;

// A paleta inteira da fase sai destes dois — o rig também os escreve.
uniform vec4 cor_luz : source_color = vec4(1.0, 0.87, 0.64, 1.0);
uniform vec4 cor_sombra : source_color = vec4(0.6, 0.7, 0.95, 1.0);

group_uniforms contraluz;
/// Força do fio de luz na borda virada para o sol.
uniform float forca_rim : hint_range(0.0, 3.0) = 1.0;
/// Espessura do fio, em pixels de tela.
uniform float espessura_rim : hint_range(0.5, 8.0) = 2.2;
/// Degrau mínimo de brilho para valer como borda de silhueta.
uniform float limiar_rim : hint_range(0.0, 0.6) = 0.08;
uniform float suavidade_rim : hint_range(0.01, 0.6) = 0.22;
/// Quanto o corpo em contraluz afunda e esfria.
uniform float afundar : hint_range(0.0, 0.8) = 0.18;
/// Acima deste brilho o pixel é fundo, não silhueta — não ganha rim nem afunda.
uniform float teto_sombra : hint_range(0.05, 1.0) = 0.72;
uniform float alcance_contraluz : hint_range(0.2, 4.0) = 1.8;
group_uniforms;

group_uniforms feixes;
uniform float intensidade : hint_range(0.0, 4.0) = 1.4;
/// Brilho mínimo para um pixel contar como fonte de luz.
uniform float limiar : hint_range(0.0, 1.0) = 0.86;
/// Tamanho da região em volta do sol que alimenta os feixes.
uniform float raio_fonte : hint_range(0.02, 1.5) = 0.18;
/// Fração do caminho até o sol que a marcha percorre. 1.0 = até o disco.
uniform float densidade : hint_range(0.1, 1.0) = 1.0;
/// Perda de energia por passo — perto de 1.0 o feixe vai mais longe.
uniform float decadencia : hint_range(0.8, 1.0) = 0.968;
/// Mipmap amostrado na marcha: suaviza os feixes e barateia o passe.
uniform float borrado : hint_range(0.0, 4.0) = 1.5;
/// Gama da marcha. Perto do sol quase todas as amostras caem dentro da fonte e
/// longe dele só as últimas caem, então o feixe cru despenca com a distância e
/// some antes de cruzar a cena. Abaixo de 1.0 este expoente levanta a cauda —
/// é licença artística, e é o que faz o feixe atravessar o quadro em LDR.
uniform float gama_feixe : hint_range(0.2, 1.0) = 0.55;
uniform float forca_estrias : hint_range(0.0, 1.0) = 0.4;
uniform float velocidade : hint_range(0.0, 1.0) = 0.06;
group_uniforms;

group_uniforms atmosfera;
/// Quanto a cena desbota na cor do ar perto do sol (espalhamento).
uniform float lavagem : hint_range(0.0, 1.0) = 0.16;
/// Véu aditivo por cima disso — o brilho do próprio ar.
uniform float veu : hint_range(0.0, 1.0) = 0.13;
/// Quanto o lado oposto ao sol puxa para o azul do céu.
uniform float forca_sombra : hint_range(0.0, 1.0) = 0.24;
uniform float alcance_luz : hint_range(0.2, 4.0) = 0.7;
group_uniforms;

group_uniforms graduacao;
uniform float exposicao : hint_range(0.5, 2.0) = 1.03;
uniform float contraste : hint_range(0.5, 2.0) = 1.06;
uniform float saturacao : hint_range(0.0, 2.0) = 1.06;
uniform float vinheta : hint_range(0.0, 1.0) = 0.22;
group_uniforms;

group_uniforms lente;
uniform float flare : hint_range(0.0, 2.0) = 0.3;
/// Raio do anel que sonda se o disco do sol está livre.
uniform float raio_oclusao : hint_range(0.005, 0.2) = 0.05;
group_uniforms;

const int PASSOS_RIM = 4;
const int AMOSTRAS = 24;

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// Ruído barato e estável por pixel. Serve para desalinhar a marcha dos feixes
// (senão os passos viram anéis) e para quebrar o banding no fim do passe.
float granulado(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Quanto este ponto da tela emite. Precisa ser claro E estar perto do sol:
// assim só o disco e o halo alimentam os feixes, e qualquer coisa que tape
// essa região corta a alimentação — que é o recorte que queremos.
float fonte_de_luz(vec2 uv) {
	float brilho = smoothstep(limiar, 1.0, luma(textureLod(tela, uv, borrado).rgb));
	vec2 d = vec2((uv.x - sol_uv.x) * aspecto, uv.y - sol_uv.y);
	return brilho * exp(-length(d) / raio_fonte);
}

// O disco está à vista? Sondamos um anel curto em volta dele num mip alto: se
// o que está lá é escuro, alguma coisa da cena tapou o sol — e a lente não tem
// o que refletir. Sem isto o flare atravessa parede.
float sol_a_vista() {
	float soma = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.78539816; // 2*PI / 8
		vec2 o = vec2(cos(a) / aspecto, sin(a)) * raio_oclusao;
		soma += luma(textureLod(tela, clamp(sol_uv + o, vec2(0.0), vec2(1.0)), 3.0).rgb);
	}
	return smoothstep(0.3, 0.72, soma / 8.0);
}

// Fantasmas de lente: cópias do sol espelhadas ao longo da reta que liga o sol
// ao centro da tela, cada uma com uma dominante de cor diferente.
vec3 fantasmas(vec2 uv) {
	vec3 acc = vec3(0.0);
	vec2 dir = vec2(0.5) - sol_uv;
	for (int i = 1; i <= 6; i++) {
		float fi = float(i);
		vec2 p = sol_uv + dir * (fi * 0.42);
		vec2 dd = vec2((uv.x - p.x) * aspecto, uv.y - p.y);
		float tam = 0.045 + 0.028 * fract(fi * 0.37);
		float g = smoothstep(tam, 0.0, length(dd));
		vec3 tinta = vec3(
			0.55 + 0.45 * sin(fi * 1.7),
			0.55 + 0.45 * sin(fi * 1.7 + 2.1),
			0.55 + 0.45 * sin(fi * 1.7 + 4.2));
		acc += g * tinta * (0.11 / fi);
	}
	return acc;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 cor = texture(tela, uv).rgb;
	float ruido = granulado(FRAGCOORD.xy);

	// Geometria comum: trabalhamos num espaço "quadrado" (x esticado pelo
	// aspecto) para que a direção do sol não entorte nas diagonais e para que
	// os raios sejam círculos de verdade.
	vec2 d = vec2((sol_uv.x - uv.x) * aspecto, sol_uv.y - uv.y);
	float dist = length(d);
	vec2 rumo = dist > 1e-5 ? d / dist : vec2(0.0, -1.0);

	// ---------------------------------------------------------------- 1. contraluz
	// Um pixel já claro é fundo; fundo não é silhueta.
	float aqui = luma(cor);
	float silhueta = 1.0 - smoothstep(teto_sombra * 0.6, teto_sombra, aqui);
	float perto_contraluz = exp(-dist / alcance_contraluz);

	if (forca_rim > 0.001 && silhueta > 0.001) {
		// 1px vale SCREEN_PIXEL_SIZE.y no espaço quadrado.
		vec2 passo = vec2(rumo.x / aspecto, rumo.y) * (SCREEN_PIXEL_SIZE.y * espessura_rim);
		float adiante = 0.0;
		float atras = 0.0;
		for (int i = 1; i <= PASSOS_RIM; i++) {
			float f = float(i);
			adiante += luma(texture(tela, clamp(uv + passo * f, vec2(0.0), vec2(1.0))).rgb);
			atras += luma(texture(tela, clamp(uv - passo * f, vec2(0.0), vec2(1.0))).rgb);
		}
		adiante /= float(PASSOS_RIM);
		atras /= float(PASSOS_RIM);
		// Claro lá na frente, escuro aqui: estamos na borda virada para o sol.
		float borda = smoothstep(limiar_rim, limiar_rim + suavidade_rim,
			max(adiante - aqui, 0.0));
		// E escuro também do lado oposto, senão isto é um fiapo — um galho, um
		// cabo, a quina de uma plataforma — mais fino que o próprio fio de luz.
		// Sem esta condição o fiapo acende inteiro e vira borrão, não contorno.
		float corpo = 1.0 - smoothstep(limiar_rim * 0.5, limiar_rim * 0.5 + suavidade_rim,
			max(atras - aqui, 0.0));
		cor += cor_luz.rgb * (borda * corpo * silhueta * forca_rim
			* (0.35 + 0.65 * perto_contraluz) * visibilidade);
	}

	cor = mix(cor, cor * cor_sombra.rgb,
		silhueta * perto_contraluz * afundar * visibilidade);

	// ---------------------------------------------------------------- 2. feixes
	if (intensidade > 0.001 && visibilidade > 0.001) {
		vec2 delta = (sol_uv - uv) * (densidade / float(AMOSTRAS));
		// O jitter desalinha a marcha entre pixels vizinhos: sem ele os passos
		// desenham anéis concêntricos em volta do sol.
		vec2 p = uv + delta * ruido;
		float acumulado = 0.0;
		float peso = 1.0;
		for (int i = 0; i < AMOSTRAS; i++) {
			p += delta;
			// Fora da tela não há informação: o passo é descartado em vez de
			// esborrachar a borda do backbuffer feixe adentro.
			vec2 dentro = step(vec2(0.0), p) * step(p, vec2(1.0));
			acumulado += fonte_de_luz(clamp(p, vec2(0.0), vec2(1.0)))
				* peso * dentro.x * dentro.y;
			peso *= decadencia;
		}
		float g = pow(clamp(acumulado / float(AMOSTRAS), 0.0, 1.0), gama_feixe);

		// Estrias: harmônicas inteiras do ângulo, então a função fecha o ciclo
		// em 2*PI e a costura em +/- PI não aparece.
		float ang = atan(-d.y, -d.x);
		float t = TIME * velocidade;
		float f = 0.55 * (0.5 + 0.5 * sin(ang * 7.0 + t * 1.3))
			+ 0.28 * (0.5 + 0.5 * sin(ang * 17.0 - t * 0.8 + 1.7))
			+ 0.17 * (0.5 + 0.5 * sin(ang * 29.0 + t * 2.1 + 3.9));
		g *= mix(1.0, pow(clamp(f, 0.0, 1.0), 1.8), forca_estrias);

		cor += cor_luz.rgb * (g * intensidade * visibilidade);
	}

	// ---------------------------------------------------------------- 3. atmosfera
	float perto = exp(-dist / alcance_luz);
	float k = perto * visibilidade;

	// Lado do sol: espalhamento. A cena some no ar (mix) e o ar brilha por cima
	// dela (soma). O quadrado deixa o véu mais apertado que a lavagem, então o
	// desbotar é largo e o brilho fica colado no disco.
	cor = mix(cor, cor_luz.rgb, clamp(lavagem * k, 0.0, 1.0));
	cor += cor_luz.rgb * (veu * k * k);

	// Lado oposto: sombra aberta, iluminada só pela abóbada azul.
	cor = mix(cor, cor * cor_sombra.rgb, (1.0 - perto) * forca_sombra);

	cor *= exposicao;
	cor = clamp((cor - 0.5) * contraste + 0.5, vec3(0.0), vec3(4.0));
	cor = mix(vec3(luma(cor)), cor, saturacao);

	// Vinheta deslocada para longe do sol — o canto na sombra fecha mais.
	vec2 vc = uv - mix(vec2(0.5), sol_uv, 0.2);
	vc.x *= aspecto * 0.8;
	cor *= 1.0 - vinheta * smoothstep(0.34, 1.05, length(vc));

	// Reflexos internos da lente, só quando há disco para refletir.
	float livre = flare > 0.001 ? sol_a_vista() * visibilidade : 0.0;
	if (livre > 0.001) {
		float estria = exp(-abs(d.y) * 110.0) * exp(-abs(d.x) * 1.7);
		float halo = exp(-dist * 6.5);
		cor += (cor_luz.rgb * (estria * 0.5 + halo * 0.28) + fantasmas(uv)) * flare * livre;
	}

	// Meio LSB de ruído: as rampas radiais deste passe são longas e suaves, e
	// sem isto elas se quebram em anéis de banding em telas de 8 bits.
	cor += (ruido - 0.5) / 255.0;

	COLOR = vec4(cor, 1.0);
}
