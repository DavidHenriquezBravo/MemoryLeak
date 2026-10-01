class_name NPC
extends CharacterBody2D

# Un solo script para Andrés, Juan, Rivera, Vicente y el Anciano.
# Lo que cambia entre ellos se rellena en el inspector de cada escena.
#
# Si el NPC tiene misiones, al hablarle se lanza la primera que falte (MissionManager)
# y sobre su cabeza aparece un aviso:
#   "!"  -> tiene una misión nueva para darte
#   "…"  -> su misión ya está aceptada y te está esperando

const AVISO_SHEET := preload("res://Sprites/aviso_mision-Sheet.png")
const AVISO_ALTURA := -26.0          # cuántos píxeles sobre el centro del sprite

@export var npc_data: NpcData                     # nombre + retrato (el .tres del personaje)
@export var missions: Array[MissionData] = []     # en orden: la segunda se ofrece al terminar la primera
@export var lines: Array[String] = ["..."]        # lo que dice cuando no tiene misión que dar
@export var registro_text: String = ""            # pestaña para esas líneas ("" = sin pestaña)
@export var default_anim: StringName = &"idle_down"

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var player_near: Node2D = null
var _aviso: AnimatedSprite2D
var _aviso_activo := false        # si corresponde mostrar el aviso
var _hablando := false

static var _frames_aviso: SpriteFrames


func _ready() -> void:
	_play(default_anim)
	_crear_aviso()
	EventBus.mission_started.connect(_on_mision_cambio)
	EventBus.mission_completed.connect(_on_mision_cambio)
	GameState.stats_changed.connect(_actualizar_aviso)
	_actualizar_aviso()


func _process(_delta: float) -> void:
	# Mientras alguien habla o hay una casilla abierta, el aviso no estorba
	if _aviso != null:
		_aviso.visible = _aviso_activo and not (Dialogue.is_open or ExercisePanel.is_open)


func _unhandled_input(event: InputEvent) -> void:
	if player_near == null or _hablando or Dialogue.is_open or ExercisePanel.is_open:
		return
	if event.is_action_pressed("interact"):
		# Importante: marcar el evento como usado, si no el cuadro de diálogo
		# recibe esa misma pulsación de E y salta la primera frase.
		get_viewport().set_input_as_handled()
		_hablar()


func _hablar() -> void:
	_hablando = true
	_face(player_near.global_position)
	var m := mision_actual()
	if m != null and _puede_empezar(m):
		await MissionManager.start(m, npc_data)
	elif m == null and not missions.is_empty():
		# Ya terminó todas sus misiones: repite lo que dice la última al estar resuelta
		await MissionManager.start(missions[-1], npc_data)
	else:
		await Dialogue.say(npc_data, lines, registro_text)
	_play(default_anim)
	_hablando = false
	_actualizar_aviso()


# La primera misión de la lista que todavía no se completa (null si no queda ninguna)
func mision_actual() -> MissionData:
	for m in missions:
		if m != null and not GameState.is_completed(m.id):
			return m
	return null


func _puede_empezar(m: MissionData) -> bool:
	return m.requires_mission == &"" or GameState.is_completed(m.requires_mission)


# ------------------------------------------------------------------ aviso "!" / "…"
func _on_mision_cambio(_m: MissionData) -> void:
	_actualizar_aviso()


func _actualizar_aviso() -> void:
	if _aviso == null:
		return
	var m := mision_actual()
	if m == null:
		_aviso_activo = false
	elif MissionManager.active == m:
		_aviso_activo = true
		_aviso.play(&"pendiente")
	elif MissionManager.active == null and _puede_empezar(m):
		_aviso_activo = true
		_aviso.play(&"nueva")
	else:
		_aviso_activo = false


func _crear_aviso() -> void:
	if missions.is_empty():
		return
	_aviso = AnimatedSprite2D.new()
	_aviso.name = "AvisoMision"
	_aviso.sprite_frames = _frames()
	_aviso.position = Vector2(0, AVISO_ALTURA)
	_aviso.z_index = 10
	_aviso.visible = false
	add_child(_aviso)


# Arma las animaciones del aviso desde aviso_mision-Sheet.png (6 frames de "!" y 6 de "…")
static func _frames() -> SpriteFrames:
	if _frames_aviso != null:
		return _frames_aviso
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for anim_name: StringName in [&"nueva", &"pendiente"]:
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, 10.0)
		sf.set_animation_loop(anim_name, true)
	for i in 12:
		var frame := AtlasTexture.new()
		frame.atlas = AVISO_SHEET
		frame.region = Rect2(i * 16, 0, 16, 16)
		sf.add_frame(&"nueva" if i < 6 else &"pendiente", frame)
	_frames_aviso = sf
	return sf


# ------------------------------------------------------------------ animaciones
func _face(target: Vector2) -> void:
	var d := target - global_position
	var target_anim: StringName
	if absf(d.x) > absf(d.y):
		target_anim = &"idle_left" if d.x < 0.0 else &"idle_right"
	else:
		target_anim = &"idle_down"
	_play(target_anim)


# Solo reproduce si la animación existe (Juan no tiene idle_right, por ejemplo)
func _play(anim_name: StringName) -> void:
	if anim.sprite_frames and anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)


# Estas dos funciones ya están conectadas en tus escenas (señales del Area2D).
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_near = body


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == player_near:
		player_near = null
