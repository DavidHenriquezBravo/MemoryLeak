shader_type canvas_item;

// Corrupción del mapa: tiñe cualquier sprite o TileMapLayer con la paleta corrupta y,
// al subir "radio", una onda cyan lo va limpiando desde "centro" (coordenadas del mundo).
// Todos los nodos que comparten este material se limpian con la MISMA onda.

uniform vec2 centro = vec2(32.0, -310.0);
// -1 = todo corrupto · 0..N = onda de limpieza en marcha · >9999 = ya limpio
uniform float radio = -1.0;
uniform float escala_y = 1.7;
// true: el frente de la onda es una línea vertical que se abre desde el centro (como la banda del suelo)
uniform bool barrido_vertical = true;
// Donde la montaña toca la banda de corrupción del suelo: ahí se disuelve en bloques.
uniform float borde_y = -304.0;
uniform float desvanecer = 22.0;

varying vec2 wp;

const vec3 N0 = vec3(0.055, 0.055, 0.110);
const vec3 N1 = vec3(0.086, 0.086, 0.176);
const vec3 N2 = vec3(0.114, 0.114, 0.220);
const vec3 T0 = vec3(0.114, 0.310, 0.345);
const vec3 T1 = vec3(0.165, 0.498, 0.522);
const vec3 T2 = vec3(0.165, 0.624, 0.647);
const vec3 CYAN = vec3(0.239, 0.894, 0.867);
const vec3 ROSA = vec3(0.878, 0.404, 0.616);

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 corrupto(vec3 c, vec2 p) {
	if (c.r + c.g + c.b < 0.03) {
		return c;                                   // el contorno negro se queda
	}
	float L = dot(c, vec3(0.3, 0.59, 0.11));
	bool verde = c.g > c.r + 0.12 && c.g > c.b + 0.08;
	vec3 o;
	if (verde) {
		float n = hash(floor(p / 2.0));
		o = n > 0.9 ? T0 : (n > 0.35 ? N2 : N1);    // el pasto se vuelve suelo navy
	} else if (L < 0.25) {
		o = N0;                                     // caras en sombra
	} else if (L < 0.40) {
		o = N2;
	} else if (L < 0.55) {
		o = T0;                                     // caras de la roca
	} else if (L < 0.70) {
		o = T1;                                     // caras iluminadas
	} else {
		o = T2;                                     // filos con luz
	}
	float t = floor(TIME * 6.0);
	if (hash(vec2(floor(p.y / 3.0), floor(p.x / 36.0) * 7.0 + t)) > 0.975) {
		o = mix(o, T1, 0.45);                       // franjas glitch cortas
	}
	// la base se deshace en bloques hasta fundirse con la banda de abajo
	float k = clamp((p.y - (borde_y - desvanecer)) / desvanecer, 0.0, 1.0);
	if (hash(floor(p / 6.0) + 17.0) < k * k) {
		o = mod(floor(p.x / 2.0) + floor(p.y / 2.0), 2.0) < 1.0 ? N1 : N2;
	}
	float s = hash(floor(p) + t);
	if (s > 0.994) {
		o = CYAN;
	} else if (s > 0.998) {
		o = ROSA;
	}
	return o;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.01 || radio > 9999.0) {
		COLOR = c;
	} else {
		vec2 p = floor(wp);
		vec3 cor = corrupto(c.rgb, p);
		vec3 res = cor;
		if (radio >= 0.0) {
			float d = barrido_vertical ? abs(p.x - centro.x) : length(vec2(p.x - centro.x, (p.y - centro.y) * escala_y));
			float x = radio - d;                    // > 0: la onda ya pasó por aquí
			float chk = mod(p.x + p.y, 2.0);
			if (x > 16.0) {
				res = c.rgb;
			} else if (x > 8.0) {
				bool limpio = chk < 1.0 || (mod(floor(p.x / 2.0) + floor(p.y / 2.0), 3.0) < 1.0 && x > 12.0);
				res = limpio ? c.rgb : cor;
			} else if (x > 6.0) {
				res = T2;
			} else if (x > 2.0) {
				res = CYAN;
			} else if (x > -2.0) {
				res = chk < 1.0 ? N2 : T0;
			}
		}
		COLOR = vec4(res, c.a);
	}
}
