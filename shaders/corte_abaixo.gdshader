// Some com tudo o que o desenho fizer abaixo (e, se pedir, acima) de uma
// altura do MUNDO.
//
// Quem usa:
//   - o player.gd (esconder_abaixo_de): o muro da frente numa fase de andar
//     para a frente e para trás (o telhado da torre). A Cacau anda até a
//     beirada, e o que passaria abaixo do topo do muro — os pés, as canelas —
//     simplesmente não é desenhado, como se o muro estivesse na frente dela;
//   - o BlocoDeTiles (bloco_de_tiles.gd), nos elevadores de tile: a cabine do
//     telhado some no fundo do poço ao descer (corte_y), e o tubo da torre
//     some por cima conforme a plataforma desce sobre ele (corte_acima_y).
//
// A conta é em coordenadas do mundo (as do editor), então não depende da
// escala, do zoom da câmera nem do quadro da animação. A luz da cena continua
// valendo: o shader só descarta pixels.
shader_type canvas_item;

/// A altura (y do mundo) a partir da qual nada aparece. A fileira de pixels
/// que começa em "corte_y" já fica escondida.
uniform float corte_y = 1.0e9;
/// Acima desta altura (y do mundo) também nada aparece. A fileira que começa
/// em "corte_acima_y" ainda aparece.
uniform float corte_acima_y = -1.0e9;

varying float y_no_mundo;

void vertex() {
	y_no_mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}

void fragment() {
	if (y_no_mundo > corte_y || y_no_mundo < corte_acima_y) {
		discard;
	}
}
