class_name MemoriaPerdida
extends AnimatedSprite2D

# Memoria perdida del protagonista (nivel 2, M1–M6). Va en un AnimatedSprite2D con la hoja
# Memoria_perdida-Sheet.png (si no trae animación, la arma sola) y en el Inspector se le pone el id.
# Al acercarse aparece "[E] RECORDAR"; al apretar E el cristal se deshace, se cuenta el recuerdo
# y queda en el Registro (pestaña Memorias, tecla R). Si ya se recogió, no aparece.

const SHEET := preload("res://Sprites/Mundo/Memoria_perdida-Sheet.png")
const C_CYAN := Color(0.239, 0.894, 0.867)

@export var id: StringName = &"M1"
@export var solo_tras_jefe_2 := false    # la M6: aparece en la arena recién al vencer a The Dangling Pointer

var _cerca := false
var _recogiendo := false
var _aviso: Label

static var _frames_memoria: SpriteFrames


func _ready() -> void:
	if GameState.memorias.has(id):
		queue_free()
		return
	if sprite_frames == null:
		sprite_frames = _frames()
		play(&"default")
	var zona := Area2D.new()
	zona.name = "Zona"
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 22.0
	forma.shape = circulo
	zona.add_child(forma)
	add_child(zona)
	zona.body_entered.connect(_on_body_entered)
	zona.body_exited.connect(_on_body_exited)

	_aviso = Label.new()
	_aviso.text = "[E] RECORDAR"
	_aviso.z_index = 10
	_aviso.position = Vector2(-40, -30)
	_aviso.size = Vector2(80, 12)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_color_override("font_color", C_CYAN)
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 3)
	_aviso.add_theme_font_size_override("font_size", 8)
	_aviso.visible = false
	add_child(_aviso)


func _process(_delta: float) -> void:
	var activa := _disponible()
	visible = activa or _recogiendo
	_aviso.visible = activa and _cerca and not (Dialogue.is_open or ExercisePanel.is_open)


func _unhandled_input(event: InputEvent) -> void:
	if not _cerca or not _disponible() or Dialogue.is_open or ExercisePanel.is_open or GameState.en_cinematica:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_recoger()


func _disponible() -> bool:
	return not _recogiendo and (not solo_tras_jefe_2 or GameState.boss2_defeated)


func _recoger() -> void:
	_recogiendo = true
	_aviso.hide()
	GameState.recoger_memoria(id)
	var brillo := create_tween().set_parallel()
	brillo.tween_property(self, "scale", scale * 1.6, 0.4)
	brillo.tween_property(self, "modulate", Color(1.6, 1.6, 1.6, 0.0), 0.4)

	var datos := Memorias.buscar(id)
	var n := GameState.memorias.size()
	var lineas: Array[String] = [str(datos.get("texto", "…"))]
	if n == 1:
		lineas.append("(Las memorias quedan en el Registro: apreta R para leerlas otra vez.)")
	var quien := NpcData.new()
	quien.display_name = "// MEMORIA %s" % id
	var pestana := "MEMORIAS %d/%d" % [n, Memorias.TOTAL]
	if n == Memorias.TOTAL:
		pestana += " · OK"
	await Dialogue.say(quien, lineas, pestana)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_cerca = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_cerca = false


static func _frames() -> SpriteFrames:
	if _frames_memoria != null:
		return _frames_memoria
	var sf := SpriteFrames.new()
	sf.set_animation_speed(&"default", 5.0)
	for i in SHEET.get_width() / 32:
		var cuadro := AtlasTexture.new()
		cuadro.atlas = SHEET
		cuadro.region = Rect2(i * 32, 0, 32, 32)
		sf.add_frame(&"default", cuadro)
	_frames_memoria = sf
	return sf
