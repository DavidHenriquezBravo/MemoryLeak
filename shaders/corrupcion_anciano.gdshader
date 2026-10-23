shader_type canvas_item;

// Corrupción de datos para el Anciano: «progreso» lo deshace en píxeles (0 = entero, 1 = ya no está; al revés,
// lo materializa) y «glitch» lo hace parpadear en franjas y píxeles rosa y cyan. Trabaja por píxel de la
// textura, así que sirve igual con las AtlasTexture de las hojas de animación.
uniform float progreso : hint_range(0.0, 1.0) = 0.0;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rosa : source_color = vec4(0.878, 0.404, 0.616, 1.0);
uniform vec4 cyan : source_color = vec4(0.239, 0.894, 0.867, 1.0);

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
	float t = floor(TIME * 14.0);
	if (col.a > 0.0) {
		// franjas de dos píxeles que se tiñen de golpe
		float fila = floor(px.y / 2.0);
		if (azar(vec2(fila, t)) < glitch * 0.35) {
			col.rgb = mix(col.rgb, azar(vec2(t, fila)) > 0.5 ? rosa.rgb : cyan.rgb, 0.75);
		}
		// píxeles sueltos que titilan
		if (azar(px + t) < glitch * 0.08) {
			col.rgb = azar(px * 1.7 + t) > 0.5 ? rosa.rgb : cyan.rgb;
		}
	}
	// deshacerse: cada píxel se va cuando el progreso pasa su número; justo antes, brilla
	float umbral = azar(px * 0.37);
	if (umbral < progreso) {
		col.a = 0.0;
	} else if (umbral < progreso + 0.12 && col.a > 0.0 && progreso > 0.0) {
		col.rgb = azar(px) > 0.5 ? rosa.rgb : cyan.rgb;
	}
	COLOR = col * COLOR;
}
