extends Node2D

## El Núcleo, dentro del volcán: la sala del jefe final.
##   - La primera vez: la cámara sube hasta el núcleo, el Anciano se materializa frente a él (corrupto y el doble de
##     grande), habla, y empieza la pelea final (escena_pelea).
##   - Si se vuelve sin haberlo vencido (perdiste y reintentaste desde aquí): el jefe espera; al acercarse, la pelea.
##   - Al volver ganando: el final. El jefe se deshace, el núcleo suelta los recuerdos robados, que vuelven al
##     jugador, y recupera su nombre (el Compilador Supremo). Cartel de FIN y vuelta al menú.

const ANCIANO_CORRUPTO := preload("res://scripts/data/anciano_corrupto.tres")
const SEGMENTATION_FAULT := preload("res://scripts/data/segmentation_fault.tres")
const SISTEMA := preload("res://data/npc/sistema.tres")
const SHADER := preload("res://shaders/corrupcion_anciano.gdshader")
const C_CYAN := Color("3de4dd")
const C_ROSA := Color("e0679d")

## La pelea contra The Segmentation Fault
@export_file("*.tscn") var escena_pelea: String = ""

const LINEAS_ANCIANO: Array[String] = [
	"Llegaste. Sabía que vendrías: siempre sigues las placas que te dejo.",
	"Mira el Núcleo. Cada luz ahí dentro es un recuerdo tuyo: tu nombre, tu casa, tu pasado.",
	"Con ellos reescribí la Realidad. Y el poder me devolvió mi verdadera forma.",
]
const LINEAS_JEFE: Array[String] = [
	"Ya no soy el Anciano. Soy el error que nadie atrapó a tiempo.",
	"Soy The Segmentation Fault. Y tú vas a acceder a una dirección que no existe.",
]
const LINEAS_REVANCHA: Array[String] = ["Volviste. Esta vez no saldrás del Núcleo."]
const LINEAS_DERROTA: Array[String] = [
	"No… las placas… se me escapan de las manos.",
	"Sin tu memoria no soy nada. Solo un acceso inválido… a una dirección que ya no existe.",
]
const LINEAS_SELLO: Array[String] = ["* Devuelves el bloque y sellas la placa."]
const LINEAS_FINAL: Array[String] = [
	"* La Tabla Principal de la Realidad se recompila.",
	"* Tus recuerdos vuelven, uno por uno: Nullville, el Distrito, el Núcleo… y tu nombre.",
	"* Recuperas tu nombre: el Compilador Supremo ha vuelto.",
]

@onready var jefe: AnimatedSprite2D = $"Objetos/The Segmentation Fault/Sprite"
@onready var nucleo: AnimatedSprite2D = $Objetos/Nucleo/Sprite
@onready var jugador = $Objetos/Player                                  # player.gd

var _mat: ShaderMaterial
var _cam: Camera2D


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("glitch", 0.12)
	jefe.material = _mat
	if GameState.final_visto_juego:
		jefe.visible = false
		$"Corrupcion piso".visible = false
	elif GameState.boss3_defeated:
		_final.call_deferred()
	elif GameState.nucleo_visto:
		_esperar_revancha()
	else:
		jefe.visible = false
		_llegada.call_deferred()


# ------------------------------------------------------------------ la primera vez
func _llegada() -> void:
	GameState.en_cinematica = true
	jugador.last_direction = Vector2.UP
	await get_tree().create_timer(1.3).timeout          # deja terminar el goteo de la transición
	_camara_cinematica()
	# la cámara sube por el puente hasta el núcleo, un poco más lejos que lo normal para que el diálogo no tape
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_cam, "global_position", _foco_jefe(), 2.4)
	t.tween_property(_cam, "zoom", Vector2(2.5, 2.5), 2.4)
	await t.finished
	await get_tree().create_timer(0.5).timeout

	# se materializa frente al núcleo: de los píxeles sueltos a la figura entera
	jefe.visible = true
	_mat.set_shader_parameter("progreso", 1.0)
	_mat.set_shader_parameter("glitch", 1.0)
	_temblar(1.8, 3.0)
	var t2 := create_tween().set_parallel()
	t2.tween_method(func(v: float): _mat.set_shader_parameter("progreso", v), 1.0, 0.0, 1.8)
	t2.tween_method(func(v: float): _mat.set_shader_parameter("glitch", v), 1.0, 0.12, 2.2)
	await t2.finished
	await get_tree().create_timer(0.4).timeout
	await Dialogue.say(ANCIANO_CORRUPTO, LINEAS_ANCIANO)

	# se revela: un golpe de glitch y dice su nombre
	_temblar(0.8, 4.0)
	var t3 := create_tween()
	t3.tween_method(func(v: float): _mat.set_shader_parameter("glitch", v), 0.9, 0.12, 0.8)
	await Dialogue.say(SEGMENTATION_FAULT, LINEAS_JEFE)
	GameState.nucleo_visto = true
	await _a_la_pelea()


# ------------------------------------------------------------------ revancha: el jefe espera
func _esperar_revancha() -> void:
	var zona := Area2D.new()
	zona.name = "Zona del jefe"
	zona.position = (jefe.get_parent() as Node2D).position + Vector2(0, 70)
	var forma := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(320, 24)
	forma.shape = r
	zona.add_child(forma)
	$Objetos.add_child(zona)
	zona.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and not GameState.en_cinematica:
			_revancha())


func _revancha() -> void:
	GameState.en_cinematica = true
	_temblar_camara_jugador()
	await Dialogue.say(SEGMENTATION_FAULT, LINEAS_REVANCHA)
	await _a_la_pelea()


func _a_la_pelea() -> void:
	GameState.en_cinematica = false
	if escena_pelea != "":
		Transicion.ir_a_pelea(escena_pelea)
		return
	# sin pelea conectada: la cámara vuelve al jugador y el jefe se queda flotando
	await _volver_al_jugador()


# ------------------------------------------------------------------ el final
func _final() -> void:
	GameState.en_cinematica = true
	jugador.last_direction = Vector2.UP
	jefe.visible = true
	_mat.set_shader_parameter("glitch", 0.6)
	_camara_cinematica()
	_cam.zoom = Vector2(2.5, 2.5)
	_cam.global_position = _foco_jefe()
	await get_tree().create_timer(1.6).timeout          # deja terminar el goteo de la transición
	await Dialogue.say(SEGMENTATION_FAULT, LINEAS_DERROTA)

	# se deshace en píxeles, para siempre
	_temblar(2.0, 3.5)
	var t := create_tween().set_parallel()
	t.tween_method(func(v: float): _mat.set_shader_parameter("glitch", v), 0.6, 1.0, 0.6)
	t.tween_method(func(v: float): _mat.set_shader_parameter("progreso", v), 0.0, 1.0, 2.0)
	await t.finished
	jefe.visible = false
	await get_tree().create_timer(0.8).timeout

	# el jugador sube por el puente hasta el núcleo; la cámara deja el cristal arriba y lo espera entrando por abajo
	var t2 := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# (con zoom 2,5 quedan el cristal arriba y el jugador justo encima de la caja de diálogo)
	t2.tween_property(_cam, "global_position", Vector2(_foco_jefe().x, 246), 1.0)
	await _caminar_jugador(Vector2(_foco_jefe().x, 272), 2.6)
	await get_tree().create_timer(0.4).timeout
	await Dialogue.say(SISTEMA, LINEAS_SELLO)

	# sella la placa: el núcleo se enciende, destello blanco, y suelta los recuerdos, que vuelven al jugador
	var brillo := create_tween()
	brillo.tween_property(nucleo, "modulate", Color(3, 3, 3), 0.25)
	brillo.tween_property(nucleo, "modulate", Color(1, 1, 1), 1.2)
	_temblar(0.6, 2.5)
	_destello(Color.WHITE, 0.8)
	await get_tree().create_timer(0.5).timeout
	await _recuerdos_al_jugador()

	# la Realidad se recompila: la corrupción del piso se apaga
	var limpia := create_tween()
	limpia.tween_property($"Corrupcion piso", "modulate:a", 0.0, 2.5)
	await limpia.finished
	# el nombre que escribió en el inicio (inicio.gd) y que se le corrompió en ceros
	var final: Array[String] = []
	final.assign(LINEAS_FINAL)
	if GameState.nombre_jugador != "":
		final[-1] = "* Recuperas tu nombre: %s. El Compilador Supremo ha vuelto." % GameState.nombre_jugador
	await Dialogue.say(SISTEMA, final)

	GameState.final_visto_juego = true
	var banner = load("res://scenes/ui/banner_nivel.tscn").instantiate()
	add_child(banner)
	await banner.mostrar("¡RECUPERASTE TU MEMORIA!", "Derrotaste a THE SEGMENTATION FAULT. La Realidad vuelve a estar en orden.",
		"FIN · Gracias por jugar MemoryLeak")
	banner.queue_free()
	GameState.en_cinematica = false
	Transicion.ir_a(ProjectSettings.get_setting("application/run/main_scene"))


## Los recuerdos: chispas rosa y cyan que salen del cristal, dan una vuelta y caen sobre el jugador, que brilla
## al recibirlas
func _recuerdos_al_jugador() -> void:
	var desde: Vector2 = nucleo.global_position + Vector2(48, 44)          # el centro del cristal
	var hasta: Vector2 = jugador.global_position + Vector2(0, -4)
	var ultimo: Tween
	for k in 36:
		var chispa := Polygon2D.new()
		chispa.polygon = PackedVector2Array([Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(1.5, 1.5), Vector2(-1.5, 1.5)])
		chispa.color = C_CYAN if k % 2 else C_ROSA
		chispa.z_index = 20
		chispa.global_position = desde
		add_child(chispa)
		var curva := desde.lerp(hasta, 0.4) + Vector2(randf_range(-110, 110), randf_range(-30, 30))
		var t := create_tween()
		t.tween_interval(k * 0.07)
		t.tween_method(func(u: float):
			chispa.global_position = desde.lerp(curva, u).lerp(curva.lerp(hasta, u), u), 0.0, 1.0, 1.2)
		t.tween_callback(chispa.queue_free)
		ultimo = t
	await get_tree().create_timer(1.0).timeout
	var luz := create_tween()
	for i in 4:
		luz.tween_property(jugador, "modulate", Color(2.2, 2.2, 2.2), 0.15)
		luz.tween_property(jugador, "modulate", Color(1, 1, 1), 0.3)
	if ultimo.is_running():
		await ultimo.finished
	if luz.is_running():
		await luz.finished


## Camina sin pasar por la física (en cinemática el jugador se queda quieto y en reposo)
func _caminar_jugador(destino: Vector2, segundos: float) -> void:
	jugador.set_physics_process(false)
	var spr: AnimatedSprite2D = jugador.animated_sprite
	spr.play("walk_up" if destino.y < jugador.global_position.y else "walk_down")
	var t := create_tween()
	t.tween_property(jugador, "global_position", destino, segundos)
	await t.finished
	jugador.last_direction = Vector2.UP
	spr.play("idle_up")
	jugador.set_physics_process(true)


## Pantalla de un color que aparece de golpe y se apaga
func _destello(color: Color, segundos: float) -> void:
	var capa := CanvasLayer.new()
	capa.layer = 50
	var velo := ColorRect.new()
	velo.color = color
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(velo)
	add_child(capa)
	var t := create_tween()
	t.tween_property(velo, "color:a", 0.0, segundos).from(0.9)
	t.tween_callback(capa.queue_free)


# ------------------------------------------------------------------ cámara
func _camara_cinematica() -> void:
	var del_jugador: Camera2D = jugador.get_node("Camera2D")
	_cam = Camera2D.new()
	_cam.zoom = del_jugador.zoom
	_cam.limit_left = del_jugador.limit_left
	_cam.limit_top = del_jugador.limit_top
	_cam.limit_right = del_jugador.limit_right
	_cam.limit_bottom = del_jugador.limit_bottom
	add_child(_cam)
	_cam.global_position = del_jugador.get_screen_center_position()
	_cam.make_current()


func _volver_al_jugador() -> void:
	var del_jugador: Camera2D = jugador.get_node("Camera2D")
	if _cam == null:
		return
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_cam, "global_position", del_jugador.get_screen_center_position(), 1.2)
	t.tween_property(_cam, "zoom", del_jugador.zoom, 1.2)
	await t.finished
	del_jugador.make_current()
	_cam.queue_free()
	_cam = null


## Arriba el núcleo, abajo el jefe
func _foco_jefe() -> Vector2:
	return (jefe.get_parent() as Node2D).global_position + Vector2(0, -34)


func _temblar(segundos: float, fuerza: float) -> void:
	if _cam == null:
		return
	var t := create_tween()
	for i in int(segundos / 0.05):
		var f := fuerza * (1.0 - float(i) / (segundos / 0.05))
		t.tween_property(_cam, "offset", Vector2(randf_range(-f, f), randf_range(-f, f)), 0.05)
	t.tween_property(_cam, "offset", Vector2.ZERO, 0.05)


func _temblar_camara_jugador() -> void:
	var cam: Camera2D = jugador.get_node("Camera2D")
	var t := create_tween()
	for i in 12:
		t.tween_property(cam, "offset", Vector2(randf_range(-2, 2), randf_range(-2, 2)), 0.05)
	t.tween_property(cam, "offset", Vector2.ZERO, 0.05)
