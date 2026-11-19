// O véu escuro em volta da máquina enquanto o puzzle está aberto no mapa (ver
// scripts/fases/zoom_no_objeto.gd): escurece a tela toda menos um retângulo de
// cantos redondos em volta da máquina, com a borda esfumada. É por ele que o
// resto da sala some de leve e os painéis do puzzle ficam fáceis de ler.
shader_type canvas_item;

uniform vec4 cor : source_color = vec4(0.047, 0.055, 0.110, 0.72);
/// O buraco, em px da tela: x, y, largura, altura.
uniform vec4 buraco = vec4(0.0, 0.0, 0.0, 0.0);
uniform float raio_do_canto = 18.0;
/// Quantos px leva para o véu ir do buraco até a cor inteira.
uniform float borda = 40.0;
/// 0 = sem véu, 1 = véu inteiro (para entrar e sair aos poucos).
uniform float forca = 0.0;

varying vec2 ponto;

void vertex() {
	ponto = VERTEX;
}

void fragment() {
	vec2 meia = buraco.zw * 0.5;
	vec2 q = abs(ponto - (buraco.xy + meia)) - meia + vec2(raio_do_canto);
	float distancia = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - raio_do_canto;
	float fora = smoothstep(0.0, borda, distancia);
	COLOR = vec4(cor.rgb, cor.a * fora * forca);
}
