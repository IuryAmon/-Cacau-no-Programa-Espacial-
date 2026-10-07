// A arte do fundo acesa por luz artificial.
//
// De noite as camadas do parallax são derrubadas para o azul escuro
// (`camada_de_fundo.gdshader`). Este shader desenha, por cima, a MESMA arte nas
// cores originais — mas só onde bate um foco de luz. Fora dos focos ele é
// transparente e a versão escura continua aparecendo. É o holofote no foguete,
// a luz no portão do hangar, o farol na ponta da antena.
//
// Cada foco é uma poça redonda de luz LISA, como o resto da iluminação do
// jogo. Com `pixelado` ligado ela cai em degraus, com a emenda em pontilhado.
// Quem preenche os focos é o `arte_iluminada.gd`, a partir dos nós FocoDeLuz
// filhos dele.
shader_type canvas_item;
render_mode unshaded;

const int MAXIMO = 8;

/// xy = centro do foco (no espaço da arte), z = raio, w = força.
uniform vec4 focos[MAXIMO];
uniform vec4 cores[MAXIMO] : source_color;
uniform int quantidade = 0;
/// Força geral, vinda do horário (0 = tudo apagado).
uniform float intensidade : hint_range(0.0, 1.0) = 1.0;
/// 0 = luz lisa, 1 = em degraus pontilhados.
uniform float pixelado : hint_range(0.0, 1.0, 1.0) = 0.0;
uniform float degraus : hint_range(2.0, 12.0, 1.0) = 5.0;
uniform float pontilhado : hint_range(0.0, 1.0) = 0.5;
/// Tamanho do pixel de arte, em pixels da textura (só no pixelado).
uniform float pixel = 3.0;

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
	vec4 arte = texture(TEXTURE, UV);
	bool em_pixels = pixelado > 0.5;
	vec2 cel = floor(local / pixel);
	// No pixelado a conta é feita no centro de cada pixel de arte.
	vec2 ponto = em_pixels ? (cel + 0.5) * pixel : local;
	ivec2 i4 = ivec2(mod(cel, 4.0));
	float limiar = (BAYER[i4.x + i4.y * 4] + 0.5) / 16.0;

	vec3 luz = vec3(0.0);
	for (int i = 0; i < MAXIMO; i++) {
		if (i >= quantidade) {
			break;
		}
		float d = length(ponto - focos[i].xy) / max(focos[i].z, 0.001);
		float v = clamp(1.0 - d, 0.0, 1.0);
		v = clamp(v * v * focos[i].w, 0.0, 1.0);
		if (em_pixels) {
			float f = v * degraus;
			float patamar = floor(f);
			float emenda = clamp((fract(f) - (1.0 - pontilhado)) / max(pontilhado, 0.0001), 0.0, 1.0);
			v = min(patamar + step(limiar, emenda), degraus) / degraus;
		}
		luz += cores[i].rgb * v;
	}
	luz *= intensidade;

	// Quanto da arte clara aparece é o brilho do foco; a cor dela é a da arte
	// tingida pela cor da luz.
	float cobertura = clamp(max(luz.r, max(luz.g, luz.b)), 0.0, 1.0);
	vec3 tinta = luz / max(cobertura, 0.0001);
	COLOR = vec4(arte.rgb * min(tinta, vec3(1.25)), arte.a * cobertura);
}
