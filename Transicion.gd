extends CanvasLayer
## Transición de "goteo" para entrar a la pelea.
## Se añade como Autoload con el nombre "Transicion" y se usa así:
##     Transicion.ir_a_pelea("res://Stages/Pelea.tscn")

const TAMANO_PIXEL := 3.0  # igual al zoom de la cámara del Player, así las gotas tienen el mismo píxel que el arte

const SHADER_CODE := """
shader_type canvas_item;

uniform float cubrir : hint_range(0.0, 1.0) = 0.0;     // 0 = nada negro, 1 = todo negro
uniform float descubrir : hint_range(0.0, 1.0) = 0.0;  // 0 = todo negro, 1 = ya se fue
uniform float destello : hint_range(0.0, 1.0) = 0.0;   // flash blanco
uniform vec2 tamano = vec2(320.0, 180.0);              // pantalla en pixeles del juego
uniform vec4 borde : source_color = vec4(0.239, 0.894, 0.867, 1.0);   // #3DE4DD
uniform vec4 borde2 : source_color = vec4(0.180, 0.486, 0.471, 1.0);  // teal del jefe

const float LARGO = 0.6;    // cuanto se adelantan las gotas (en pantallas)
const float LARGO_R = 0.25; // ondulacion al escurrirse
const float CELDA = 12.0;   // cada cuantos pixeles puede haber una gota

float azar(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

float ruido(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(azar(i), azar(i + 1.0), f);
}

float extra(float x, float crece) {
	float H = tamano.y;
	float base = 0.3 * LARGO * H * ruido(x / 26.0);
	float maxg = 0.7 * LARGO * H;
	float mejor = 0.0;
	float c = floor(x / CELDA);
	for (int k = -1; k <= 1; k++) {
		float cc = c + float(k);
		if (azar(cc * 1.7 + 1.0) >= 0.55) {
			continue;
		}
		float cx = cc * CELDA + 2.0 + azar(cc * 3.1 + 2.0) * (CELDA - 4.0);
		float r = 1.5 + floor(azar(cc * 5.3 + 3.0) * 3.0);
		float L = (0.3 + 0.7 * azar(cc * 7.9 + 4.0)) * maxg * crece;
		float dx = abs(x + 0.5 - cx);
		float v = 0.0;
		if (dx < r) {
			float d = dx / r;
			v = L - r * (1.0 - sqrt(1.0 - d * d));
		} else if (dx < r + 2.0) {
			v = min(L, 3.0) * (1.0 - (dx - r) / 2.0);
		}
		mejor = max(mejor, v);
	}
	return base + mejor;
}

float frente(float x) {
	float H = tamano.y;
	return cubrir * (1.0 + LARGO) * H - LARGO * H + extra(x, clamp(cubrir * 1.6, 0.0, 1.0));
}

float cola(float x) {
	float H = tamano.y;
	return descubrir * (1.0 + LARGO_R) * H - LARGO_R * H + LARGO_R * H * ruido(x / 30.0 + 100.0);
}

void fragment() {
	vec2 p = floor(UV * tamano);
	float f0 = frente(p.x - 1.0);
	float f1 = frente(p.x);
	float f2 = frente(p.x + 1.0);
	float c0 = cola(p.x - 1.0);
	float c1 = cola(p.x);
	float c2 = cola(p.x + 1.0);
	vec4 col = vec4(1.0, 1.0, 1.0, destello);
	if (p.y >= c1 && p.y < f1) {
		col = vec4(0.0, 0.0, 0.0, 1.0);
		if (cubrir < 1.0) {
			if (p.y >= f1 - 1.0 || p.y >= f0 || p.y >= f2) {
				col = borde;
			} else if (p.y >= f1 - 2.0 || p.y >= f0 - 1.0 || p.y >= f2 - 1.0) {
				col = borde2;
			}
		}
		if (descubrir > 0.0 && (p.y < c1 + 1.0 || p.y < c0 || p.y < c2)) {
			col = borde;
		}
	} else if (cubrir > 0.0 && cubrir < 1.0 && descubrir == 0.0) {
		float cc = floor(p.x / CELDA);
		float cx = cc * CELDA + 2.0 + azar(cc * 3.1 + 2.0) * (CELDA - 4.0);
		bool hay = azar(cc * 1.7 + 1.0) < 0.55 && azar(cc * 9.7 + 5.0) > 0.45;
		float y0 = f1 + 3.0 + 30.0 * cubrir * cubrir;
		if (hay && abs(p.x + 0.5 - cx) < 1.0 && p.y >= y0 && p.y < y0 + 2.0) {
			col = borde;
		}
	}
	COLOR = col;
}
"""

var rect := ColorRect.new()
var mat := ShaderMaterial.new()
var ocupado := false

func _ready() -> void:
	layer = 100  # por encima de todo, incluida la interfaz
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shader := Shader.new()
	shader.code = SHADER_CODE
	mat.shader = shader
	rect.material = mat
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	add_child(rect)

func ir_a_pelea(ruta_escena: String) -> void:
	await _ir(ruta_escena, true)

## El mismo goteo, sin los destellos de pelea (para pasar de un stage a otro).
func ir_a(ruta_escena: String) -> void:
	await _ir(ruta_escena, false)

func _ir(ruta_escena: String, destellos: bool) -> void:
	if ocupado:
		return
	ocupado = true
	mat.set_shader_parameter("tamano", rect.size / TAMANO_PIXEL)
	_cubrir(0.0)
	_descubrir(0.0)
	_destello(0.0)
	rect.visible = true

	var t := create_tween()
	# 1. dos destellos rápidos (solo al entrar a una pelea)
	if destellos:
		for i in 2:
			t.tween_method(_destello, 0.0, 0.8, 0.06)
			t.tween_method(_destello, 0.8, 0.0, 0.06)
	# 2. el negro gotea desde arriba
	t.tween_method(_cubrir, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished

	# 3. con la pantalla en negro se cambia de escena
	get_tree().change_scene_to_file(ruta_escena)
	await get_tree().create_timer(0.4).timeout

	# 4. el negro se escurre hacia abajo y aparece la escena nueva
	var t2 := create_tween()
	t2.tween_method(_descubrir, 0.0, 1.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t2.finished
	rect.visible = false
	ocupado = false

func _cubrir(v: float) -> void:
	mat.set_shader_parameter("cubrir", v)

func _descubrir(v: float) -> void:
	mat.set_shader_parameter("descubrir", v)

func _destello(v: float) -> void:
	mat.set_shader_parameter("destello", v)
