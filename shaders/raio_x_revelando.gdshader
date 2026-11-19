// O raio X dos puzzles do compressor e da destilação nascendo em cima da
// máquina do mapa (ver scripts/ui/varredura_raio_x.gd): o aparelho do puzzle só
// aparece ACIMA de uma linha. A linha desce e o raio X vai cobrindo a arte de
// aço; subindo, ela apaga o raio X e a arte de aço volta a aparecer embaixo.
//
// A conta é em px do próprio nó (o VERTEX antes de ir para a tela), então vale
// em qualquer lugar em que o aparelho esteja. Perto da linha o desenho acende
// na cor da luz, como se a luz do raio X estivesse passando por ele.
shader_type canvas_item;

/// O que está abaixo desta altura (y do nó) não aparece.
uniform float corte = 1.0e9;
/// A cor da luz que passa junto com a linha.
uniform vec4 cor_da_luz : source_color = vec4(0.62, 0.95, 1.0, 1.0);
/// Até quantos px acima da linha a luz chega, e com que força (0 = nada).
uniform float alcance_da_luz = 30.0;
uniform float forca_da_luz = 0.0;

varying float y_no_no;

void vertex() {
	y_no_no = VERTEX.y;
}

void fragment() {
	if (y_no_no > corte) {
		discard;
	}
	float perto = clamp(1.0 - (corte - y_no_no) / alcance_da_luz, 0.0, 1.0);
	COLOR.rgb = mix(COLOR.rgb, cor_da_luz.rgb, perto * perto * forca_da_luz);
}
