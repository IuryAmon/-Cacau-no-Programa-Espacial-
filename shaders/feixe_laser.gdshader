shader_type canvas_item;

// --- FEIXE DE LASER (PIXEL ART) ---
//
// Desenha o raio do LaserContinuo em pixel art, de qualquer comprimento, com a
// MESMA paleta do laser_idle.png (vermelho / rosa / branco / branco / rosa /
// vermelho, 6 pixels de arte de espessura). Nada de degradê liso: tudo é
// arredondado para a grade de "tamanho_pixel", para casar com os tiles 2x.
//
// Vai num ColorRect deitado na horizontal; o raio corre pelo MEIO da altura.
// Quem mantém "tamanho" igual ao do retângulo é o script (laser_continuo.gd).
//
// Camadas, de dentro para fora:
//   núcleo branco   2 px; some em trechos curtos de vez em quando (o "chiado")
//   rosa            1 px de cada lado; vira branco quando um pulso passa
//   vermelho        1 px de cada lado; engorda 1 px em trechos sorteados
//   halo            1 px vermelho translúcido em volta
//   fagulhas        pontos soltos acima e abaixo do raio, a cada quadro

uniform vec2 tamanho = vec2(492.0, 32.0);
// Pixels de tela por pixel de arte (os tiles do jogo estão em 2x).
uniform float tamanho_pixel = 2.0;
// Quadros por segundo da animação. Baixo de propósito: é pixel art.
uniform float quadros_por_segundo : hint_range(1.0, 30.0) = 12.0;

group_uniforms Cores;
uniform vec4 cor_nucleo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cor_meio : source_color = vec4(0.976, 0.514, 0.514, 1.0);
uniform vec4 cor_borda : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 cor_halo : source_color = vec4(1.0, 0.0, 0.0, 0.28);
uniform vec4 cor_fagulha : source_color = vec4(0.85, 0.08, 0.16, 0.8);

group_uniforms Energia;
// Velocidade dos pulsos claros que correm pelo raio (px de tela/s).
uniform float velocidade_pulso = 260.0;
// Distância entre um pulso e o próximo (px de tela).
uniform float espacamento_pulso = 150.0;
// Chance (por trecho, por quadro) de o núcleo branco falhar.
uniform float chance_falha : hint_range(0.0, 1.0) = 0.1;
// Chance (por trecho, por quadro) de a borda engordar 1 px.
uniform float chance_engordar : hint_range(0.0, 1.0) = 0.22;
// Chance (por pixel, por quadro) de aparecer uma fagulha perto do raio.
uniform float chance_fagulha : hint_range(0.0, 0.2) = 0.018;
// Sentido em que os pulsos correm: 1 = para +X, -1 = para -X.
uniform float sentido = 1.0;

float sorteio(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 grade = floor(UV * tamanho / tamanho_pixel);
	vec2 celulas = floor(tamanho / tamanho_pixel);
	float quadro = floor(TIME * quadros_por_segundo);

	// Distância do pixel até a linha do meio, em pixels de arte (0.5, 1.5...).
	float d = abs(grade.y + 0.5 - celulas.y * 0.5);

	// O raio é quebrado em trechos de 3 px: cada um sorteia o próprio chiado.
	float trecho = floor(grade.x / 3.0);
	float engorda = step(1.0 - chance_engordar, sorteio(vec2(trecho, quadro)));
	float falha = step(1.0 - chance_falha, sorteio(vec2(trecho + 91.0, quadro * 1.37)));

	// Pulsos claros viajando pelo raio.
	float x_tela = grade.x * tamanho_pixel;
	float fase = fract((x_tela - sentido * TIME * velocidade_pulso) / espacamento_pulso);
	float pulso = step(fase, 16.0 / espacamento_pulso);

	vec4 cor = vec4(0.0);
	float meia_nucleo = 1.0 - falha + pulso;
	float meia_borda = 3.0 + engorda;

	if (d < meia_nucleo) {
		cor = cor_nucleo;
	} else if (d < 2.0) {
		cor = cor_meio;
	} else if (d < meia_borda) {
		cor = cor_borda;
	} else if (d < meia_borda + 1.0) {
		cor = cor_halo;
	} else if (d < meia_borda + 5.0) {
		float fagulha = step(1.0 - chance_fagulha, sorteio(grade + vec2(quadro * 7.13, quadro)));
		cor = cor_fagulha * fagulha;
	}

	// Uma leve oscilação de brilho no raio todo (não nas fagulhas).
	float tremida = 0.92 + 0.08 * sorteio(vec2(quadro, 3.0));
	cor.rgb *= mix(1.0, tremida, step(d, meia_borda));

	COLOR = cor;
}
