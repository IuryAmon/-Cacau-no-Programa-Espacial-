shader_type canvas_item;

// --- MORCEGO (contorno, olhos e clarão) ---
//
// Vai no AnimatedSprite2D do morcego (ver scripts/fases/morcego.gd). A arte
// dele é quase toda preta, e os corredores em que ele mora também: sem ajuda
// ele some na parede. Este shader não muda o desenho, só o que precisa para
// ele ser LIDO — e para o estado dele ser lido junto:
//
//   contorno  1 texel de luz em volta da silhueta. É o que recorta o morcego
//             do fundo escuro. O script troca a cor: lilás quando ele voa,
//             vermelho piscando quando vai dar o bote.
//   olhos     os dois pixels dos olhos, que na arte são um roxo apagado,
//             acendem em "cor_dos_olhos". Dormindo ficam apagados.
//   clarao    cobre o desenho inteiro de "cor_clarao": é o estalo do instante
//             em que o bumerangue acerta, e a tinta chapada do rastro que ele
//             deixa no mergulho.
//
// O contorno é medido nos vizinhos do texel, então cada quadro precisa de ao
// menos 1 texel transparente de folga em volta do desenho (a folha tem 3).

uniform vec4 cor_contorno : source_color = vec4(0.62, 0.54, 0.78, 1.0);
uniform float contorno : hint_range(0.0, 1.0) = 1.0;

// A cor que os olhos têm NA ARTE: é por ela que o shader acha os dois pixels.
uniform vec4 olho_na_arte : source_color = vec4(0.267, 0.204, 0.267, 1.0);
uniform vec4 cor_dos_olhos : source_color = vec4(1.0, 0.45, 0.5, 1.0);
uniform float olhos : hint_range(0.0, 1.0) = 1.0;

uniform vec4 cor_clarao : source_color = vec4(0.925, 0.831, 0.816, 1.0);
uniform float clarao : hint_range(0.0, 1.0) = 0.0;

// No fragment, COLOR já vem multiplicado pela textura — e o contorno mora
// justamente onde a textura é transparente. O modulate do nó vem por aqui.
varying vec4 modulacao;

void vertex() {
	modulacao = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 passo = TEXTURE_PIXEL_SIZE;
	float vizinhos = texture(TEXTURE, UV + vec2(passo.x, 0.0)).a;
	vizinhos = max(vizinhos, texture(TEXTURE, UV - vec2(passo.x, 0.0)).a);
	vizinhos = max(vizinhos, texture(TEXTURE, UV + vec2(0.0, passo.y)).a);
	vizinhos = max(vizinhos, texture(TEXTURE, UV - vec2(0.0, passo.y)).a);
	float linha = clamp(vizinhos - base.a, 0.0, 1.0) * contorno * cor_contorno.a;

	float olho = 1.0 - step(0.05, distance(base.rgb, olho_na_arte.rgb));
	vec3 corpo = mix(base.rgb, cor_dos_olhos.rgb, olho * olhos);
	corpo = mix(corpo, cor_clarao.rgb, clarao);
	vec3 cor_da_linha = mix(cor_contorno.rgb, cor_clarao.rgb, clarao);

	float alfa = max(base.a, linha);
	vec3 rgb = (corpo * base.a + cor_da_linha * linha) / max(alfa, 0.0001);
	COLOR = vec4(rgb, alfa) * modulacao;
}
