shader_type canvas_item;
// Silueta a contraluz (el volcán atrás): el personaje queda oscuro, con el borde de arriba y el de atrás encendidos
// de naranja. La luz del farol del Anciano se queda encendida.
uniform vec4 oscuro : source_color = vec4(0.071, 0.047, 0.055, 1.0);
uniform vec4 borde : source_color = vec4(0.643, 0.275, 0.165, 1.0);
uniform vec4 borde_atras : source_color = vec4(0.416, 0.173, 0.09, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.5) {
		discard;
	}
	float arriba = texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a;
	float atras = texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a;
	vec3 col = oscuro.rgb;
	if (arriba < 0.5) {
		col = borde.rgb;
	} else if (atras < 0.5) {
		col = borde_atras.rgb;
	}
	if (c.r > 0.97 && c.g > 0.7 && c.b < 0.8) {
		col = c.rgb;
	}
	COLOR = vec4(col, 1.0);
}
