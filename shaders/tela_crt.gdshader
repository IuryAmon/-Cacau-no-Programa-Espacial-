shader_type canvas_item;

// --- VIDRO DE MONITOR (por cima de tudo o que a tela do computador mostra) ---
//
// Linhas de varredura bem fracas + vinheta nos cantos. É o que faz o conteúdo
// parecer estar DENTRO do monitor, e não um adesivo colado sobre o sprite.
// Tudo em preto translúcido: só escurece, então o texto continua legível por
// cima de qualquer coisa (e o fundo preto da tela não muda).

uniform float forca_linhas : hint_range(0.0, 1.0) = 0.10;
// Altura de cada par de linhas, em pixels da tela.
uniform float periodo : hint_range(1.0, 16.0) = 4.0;
uniform float vinheta : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	float linha = step(0.5, fract(FRAGCOORD.y / periodo));
	vec2 c = UV - 0.5;
	float canto = smoothstep(0.30, 0.78, length(c * vec2(1.0, 1.3))) * vinheta;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(linha * forca_linhas + canto, 0.0, 1.0));
}
