extends Area2D

## La entrada del volcán en el Stage 3. Aquí el Anciano (que sigue al jugador y no se puede hablar con él) da su
## misión del nivel: «Listo para The Segmentation Fault» (EJ-N3-09), o el repaso de una misión fallada si la
## precisión del nivel quedó bajo el 70 % (MissionManager.con_repaso), o dice qué falta hacer en la ciudad.
## Al completarla viene EL GIRO: el Anciano confiesa que él robó la memoria del jugador, se corrompe y desaparece
## en el volcán. Después, [E] lleva al Núcleo (escena_nucleo), donde espera convertido en el jefe final.

const ANCIANO := preload("res://scripts/data/anciano.tres")
const ANCIANO_CORRUPTO := preload("res://scripts/data/anciano_corrupto.tres")
const MISION := preload("res://data/missions/ej_n3_09.tres")
const SHADER := preload("res://shaders/corrupcion_anciano.gdshader")
const C_CYAN := Color("3de4dd")
const C_ROSA := Color("e0679d")

## La escena del Núcleo (donde espera el jefe final).
@export_file("*.tscn") var escena_nucleo: String = ""
## Dónde se para el Anciano para confesar: al pie de la escalera, a un costado (delante del brasero)
@export var lugar_anciano: Vector2 = Vector2(1086, 160)

const LINEAS_CONFESION: Array[String] = [
	"Pero antes de entrar… hay algo que tienes que saber, viajero.",
	"¿Nunca te preguntaste cómo conocía cada placa, cada casa, cada nombre de este mundo?",
	"Tu memoria no se perdió en el colapso. Yo te la quité. Placa por placa, mientras dormías en Nullville.",
]
const LINEAS_CORRUPCION: Array[String] = [
	"Con tus recuerdos abrí el Núcleo. Con ellos alimenté a The Memory Leak y a The Dangling Pointer.",
	"Y te traje hasta aquí porque solo tú podías limpiar el camino. Cada placa que reparaste me abrió una puerta más.",
	"El caos ya está escrito. Solo falta borrar la última dirección que me estorba: la tuya.",
	"Te espero en el Núcleo.",
]

var _cerca := false
var _ocupado := false
var _aviso: Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_aviso = Label.new()
	_aviso.text = "[E] ENTRAR AL NÚCLEO"
	_aviso.z_index = 10
	_aviso.position = Vector2(-60, -44)
	_aviso.size = Vector2(120, 12)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_color_override("font_color", C_CYAN)
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 3)
	_aviso.add_theme_font_size_override("font_size", 8)
	_aviso.visible = false
	add_child(_aviso)
	# Después del giro el Anciano ya no acompaña al jugador
	if GameState.giro_visto:
		_quitar_anciano.call_deferred()


func _process(_delta: float) -> void:
	_aviso.visible = _cerca and not _ocupado and not _hay_algo_abierto()


func _unhandled_input(event: InputEvent) -> void:
	if not _cerca or _ocupado or _hay_algo_abierto():
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_hablar()


func _hay_algo_abierto() -> bool:
	return Dialogue.is_open or ExercisePanel.is_open or GameState.en_cinematica


func _hablar() -> void:
	_ocupado = true
	if not GameState.is_completed(MISION.id):
		# El Anciano da su misión, el repaso que toque o dice qué falta (MissionManager se encarga de cada caso)
		var m := MissionManager.con_repaso(MISION)
		await MissionManager.start(m, ANCIANO)
	if GameState.is_completed(MISION.id):
		if not GameState.giro_visto:
			await _giro()
		else:
			_entrar()
	_ocupado = false


func _entrar() -> void:
	if escena_nucleo == "":
		var lineas: Array[String] = ["* La entrada al Núcleo todavía está sellada."]
		await Dialogue.say(load("res://data/npc/sistema.tres"), lineas)
		return
	GameState.en_cinematica = true
	Transicion.ir_a(escena_nucleo)


# ------------------------------------------------------------------ el giro
func _giro() -> void:
	var anciano = get_tree().get_first_node_in_group("anciano_guia")     # anciano_guia.gd
	var jugador = get_tree().get_first_node_in_group("player")           # player.gd
	if anciano == null or jugador == null:
		GameState.giro_visto = true
		return
	GameState.en_cinematica = true
	await get_tree().create_timer(0.4).timeout
	# Se adelanta hasta la puerta y se da vuelta
	await anciano.ir_a(lugar_anciano)
	anciano.mirar_a(jugador.global_position)
	jugador.last_direction = Vector2.RIGHT if anciano.global_position.x > jugador.global_position.x else Vector2.LEFT
	# la cámara se acerca a los dos
	var del_jugador: Camera2D = jugador.get_node("Camera2D")
	var cam := Camera2D.new()
	cam.zoom = del_jugador.zoom
	add_child(cam)
	cam.global_position = del_jugador.get_screen_center_position()
	cam.make_current()
	var medio: Vector2 = (jugador.global_position + anciano.global_position) / 2.0 + Vector2(0, -14)
	var acercar := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	acercar.tween_property(cam, "global_position", medio, 1.0)
	acercar.tween_property(cam, "zoom", Vector2(5, 5), 1.0)
	await acercar.finished
	await Dialogue.say(ANCIANO, LINEAS_CONFESION)

	# Se corrompe: parpadea en rosa y cyan, la cueva tiembla, el retrato cambia
	var sprite: CanvasItem = anciano.get_node("AnimatedSprite2D")
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	sprite.material = mat
	var t := create_tween()
	t.tween_method(func(v: float): mat.set_shader_parameter("glitch", v), 0.0, 0.6, 1.2)
	_temblar(cam, 1.2, 2.0)
	await t.finished
	await Dialogue.say(ANCIANO_CORRUPTO, LINEAS_CORRUPCION)

	# Se deshace en píxeles y desaparece dentro del volcán
	_temblar(cam, 1.6, 3.5)
	var t2 := create_tween().set_parallel()
	t2.tween_method(func(v: float): mat.set_shader_parameter("glitch", v), 0.6, 1.0, 0.6)
	t2.tween_method(func(v: float): mat.set_shader_parameter("progreso", v), 0.0, 1.0, 1.6)
	await t2.finished
	await _destello()
	anciano.queue_free()
	GameState.giro_visto = true
	await get_tree().create_timer(0.8).timeout
	var alejar := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	alejar.tween_property(cam, "global_position", del_jugador.get_screen_center_position(), 0.8)
	alejar.tween_property(cam, "zoom", del_jugador.zoom, 0.8)
	await alejar.finished
	del_jugador.make_current()
	cam.queue_free()
	GameState.en_cinematica = false


func _quitar_anciano() -> void:
	var anciano = get_tree().get_first_node_in_group("anciano_guia")     # anciano_guia.gd
	if anciano:
		anciano.queue_free()


func _temblar(cam: Camera2D, segundos: float, fuerza: float) -> void:
	var t := create_tween()
	for i in int(segundos / 0.05):
		var f := fuerza * (1.0 - float(i) / (segundos / 0.05))
		t.tween_property(cam, "offset", Vector2(randf_range(-f, f), randf_range(-f, f)), 0.05)
	t.tween_property(cam, "offset", Vector2.ZERO, 0.05)


## Un destello rosa a pantalla completa (la corrupción entrando al volcán)
func _destello() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 50
	var r := ColorRect.new()
	r.color = Color(C_ROSA, 0.0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(r)
	add_child(capa)
	var t := create_tween()
	t.tween_property(r, "color:a", 0.7, 0.08)
	t.tween_property(r, "color:a", 0.0, 0.5)
	await t.finished
	capa.queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_cerca = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_cerca = false
