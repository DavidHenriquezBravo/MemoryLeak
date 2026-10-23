extends Node2D

## El inicio del juego: de noche, en el claro del estanque de datos, a las afueras de Nullville.
##   1. Pantalla negra: el sistema intenta cargar al jugador y falla (el prólogo del PDF).
##   2. El jugador despierta botado junto al estanque. Una luz aparece en el sendero: el Anciano, de la nada.
##   3. Lo levanta y le pregunta cosas. Cuando le pregunta el nombre, el jugador lo escribe… y se corrompe en ceros.
##      El nombre queda en GameState.nombre_jugador: es el que recupera al final, en el Núcleo.
##   4. El Anciano le cuenta la historia del mundo y se adelanta a Nullville.
##   5. El jugador sigue el sendero al norte: cartel del nivel 1 y al Stage 1.

const ANCIANO := preload("res://scripts/data/anciano.tres")
const SISTEMA := preload("res://data/npc/sistema.tres")
const PROTAGONISTA := preload("res://scripts/data/protagonista.tres")
const FUENTE_TITULO := preload("res://Fuentes/upheavtt.ttf")
const FUENTE_TEXTO := preload("res://Fuentes/texto_dialogo.tres")
const FUENTE_CODIGO := preload("res://Fuentes/codigo.tres")
const CAJA := preload("res://Sprites/UI/Cajas/caja_dialogo_608x96.png")
const C_CYAN := Color("3de4dd")
const C_ROSA := Color("e0679d")
const HEX := "0123456789ABCDEF"

@export_file("*.tscn") var escena_stage_1: String = "res://scenes/levels/stage_1.tscn"

const TERMINAL: Array[String] = [
	"> Paso 1: Asignación de memoria... FALLIDO",
	"> Paso 2: Recuperando variable (nombre)...",
	"> Error: dirección de memoria no encontrada (0x00000000)",
]
const LINEAS_DESPERTAR: Array[String] = [
	"* Abres los ojos. La luz no es de sol: es una radiación azul que sube de un estanque de datos extinguidos.",
	"* Te duele el pecho. Tus estadísticas vitales están bajas… y no recuerdas nada.",
]
const LINEAS_LUZ: Array[String] = ["* Una luz se enciende en el sendero, de la nada. Alguien viene."]
const LINEAS_ENCUENTRO: Array[String] = [
	"¡Eh! ¡Muchacho! ¿Sigues con vida?",
	"Tranquilo, no te muevas tan rápido. Dame la mano… arriba, despacio.",
]
const LINEAS_PREGUNTA_1: Array[String] = ["Así está mejor. ¿Estás herido? Te encontré tirado junto al estanque."]
const LINEAS_RESPUESTA_1: Array[String] = ["Me duele todo… No sé cómo llegué aquí."]
const LINEAS_PREGUNTA_2: Array[String] = ["Nadie viene a este claro desde el colapso. ¿De dónde vienes?"]
const LINEAS_RESPUESTA_2: Array[String] = ["No lo sé. Intento recordar y es como mirar una página en blanco."]
const LINEAS_PREGUNTA_NOMBRE: Array[String] = ["Hmm. Probemos con algo más simple. ¿Cómo te llamas?"]
const LINEAS_ERROR: Array[String] = ["* Error: dirección de memoria no encontrada {addr:0x00000000}."]
const LINEAS_SIN_NOMBRE: Array[String] = [
	"Me llamo… me llamo…",
	"No puedo. Cuando busco mi nombre, solo encuentro ceros.",
]
const LINEAS_HISTORIA: Array[String] = [
	"Ceros… Así que el colapso también te alcanzó a ti.",
	"Escucha bien, porque nadie más te lo va a contar.",
	"Este mundo no está hecho de piedra ni de agua. Está hecho de direcciones de memoria.",
	"Todo lo que existe ocupa un bloque de bytes, inscrito en la Tabla Principal de la Realidad.",
	"Hubo un guardián, el Compilador Supremo, que cuidaba que cada cosa viviera en su dirección correcta y que los datos fluyeran sin errores.",
	"Pero una entidad corrupta provocó El Gran Segmentation Fault. La Pila del Mundo colapsó… y la realidad se partió en pedazos.",
]
const LINEAS_ESTANQUE: Array[String] = [
	"Mira ese estanque. Son datos que nadie volvió a leer: así se apaga todo lo que pierde su dirección.",
	"Desde el colapso, el mundo quedó congelado en tiempo de ejecución. La vida de la gente, los caminos, las armas… perdieron sus enlaces.",
]
const LINEAS_TU_VALOR: Array[String] = [
	"Y a ti te sobrescribieron con ceros. Pobre alma… tu valor sigue ahí dentro, pero perdiste tu dirección de origen.",
	"Si intentas actuar sin saber a dónde apuntas, él te destruirá.",
]
const LINEAS_PREGUNTA_YO: Array[String] = ["¿Él…? ¿Y cómo recupero mi nombre?"]
const LINEAS_CONSEJO: Array[String] = [
	"Allá afuera las copias ya no sirven. Si le pasas a alguien una copia, el mundo la olvida apenas termina la conversación.",
	"Para cambiar algo de verdad tienes que ir a su dirección: con `&` encuentras dónde vive, y con `*` lo modificas.",
	"Al norte está Nullville. Su gente también perdió sus recuerdos. Ayúdalos y los tuyos volverán, byte a byte.",
	"Ve por el sendero. Yo me adelanto… te estaré esperando en la aldea.",
]
const LINEAS_SOLO: Array[String] = ["* Sigue el sendero hacia el norte, hasta Nullville."]

@onready var jugador = $Objetos/Player                                  # player.gd
@onready var botado: AnimatedSprite2D = $Objetos/Botado
@onready var anciano = $Objetos/Anciano                                 # anciano_guia.gd
@onready var farol: PointLight2D = $Objetos/Anciano/Farol
@onready var salida: Area2D = $"Salida a Nullville"
@onready var estanque: Node2D = $"Estanque de datos"

var _yo: NpcData                 # el protagonista: "???" y después "0x00000000"
var _cam: Camera2D
var _saliendo := false
var _aviso: CanvasLayer


func _ready() -> void:
	GameState.en_cinematica = true
	jugador.get_node("AnimatedSprite2D").visible = false
	botado.play("tendido")
	anciano.siguiendo = false
	anciano.velocidad = 55.0
	anciano.visible = false
	farol.energy = 0.0
	_yo = PROTAGONISTA.duplicate()
	salida.body_entered.connect(_on_salida)
	_prologo.call_deferred()


# ------------------------------------------------------------------ 1. el sistema falla
func _prologo() -> void:
	var negro := CanvasLayer.new()
	negro.layer = 30
	add_child(negro)
	var fondo := ColorRect.new()
	fondo.color = Color.BLACK
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	negro.add_child(fondo)
	var lineas := VBoxContainer.new()
	lineas.position = Vector2(150, 300)
	lineas.add_theme_constant_override("separation", 12)
	negro.add_child(lineas)
	await get_tree().create_timer(1.2).timeout
	for i in TERMINAL.size():
		var l := Label.new()
		l.add_theme_font_override("font", FUENTE_CODIGO)
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_color", C_ROSA if i == TERMINAL.size() - 1 else C_CYAN)
		l.text = TERMINAL[i]
		l.visible_characters = 0
		lineas.add_child(l)
		var t := create_tween()
		t.tween_property(l, "visible_characters", TERMINAL[i].length(), TERMINAL[i].length() * 0.035)
		await t.finished
		await get_tree().create_timer(0.8).timeout
	# el error tiembla con glitch y todo se apaga
	for k in 8:
		lineas.position.x = 150 + randf_range(-6, 6)
		lineas.modulate.a = 0.35 if k % 2 else 1.0
		await get_tree().create_timer(0.06).timeout
	lineas.position.x = 150
	lineas.modulate.a = 1.0
	await get_tree().create_timer(1.2).timeout
	var t2 := create_tween()
	t2.tween_property(lineas, "modulate:a", 0.0, 0.6)
	t2.tween_property(fondo, "color:a", 0.0, 2.4)
	await t2.finished
	negro.queue_free()
	await _despertar()


# ------------------------------------------------------------------ 2. despierta y llega el Anciano
func _despertar() -> void:
	await get_tree().create_timer(0.6).timeout
	for k in 3:                                          # parpadea antes de abrir los ojos del todo
		botado.play("despierto")
		await get_tree().create_timer(0.22).timeout
		botado.play("tendido")
		await get_tree().create_timer(0.16).timeout
	botado.play("despierto")
	await get_tree().create_timer(0.5).timeout
	await Dialogue.say(SISTEMA, LINEAS_DESPERTAR)

	# la cámara mira al sendero: arriba, una luz que se enciende de la nada
	_camara_cinematica()
	var t := _mover_camara(Vector2(352, 150), 2.5, 1.8)
	await t.finished
	anciano.global_position = $"Ida del Anciano".global_position
	anciano.visible = true
	var luz := create_tween()
	luz.tween_property(farol, "energy", 1.0, 0.12)
	luz.tween_property(farol, "energy", 0.1, 0.08)
	luz.tween_property(farol, "energy", 0.9, 0.1)
	luz.tween_property(farol, "energy", 0.3, 0.1)
	luz.tween_property(farol, "energy", 0.8, 0.5)
	await luz.finished
	await Dialogue.say(SISTEMA, LINEAS_LUZ)
	await anciano.ir_a($"Llegada del Anciano".global_position)
	var t2 := _mover_camara(_entre_los_dos(), 3.0, 1.4)
	await anciano.ir_a($"Junto al jugador".global_position)
	anciano.mirar_a(jugador.global_position)
	if t2.is_running():
		await t2.finished
	await Dialogue.say(ANCIANO, LINEAS_ENCUENTRO)
	await _levantarse()
	await _preguntas()


func _levantarse() -> void:
	botado.play("levantarse")
	await botado.animation_finished
	await get_tree().create_timer(0.2).timeout
	botado.visible = false
	jugador.get_node("AnimatedSprite2D").visible = true
	jugador.last_direction = Vector2.RIGHT              # mira al Anciano
	jugador.update_animation(Vector2.ZERO)
	await get_tree().create_timer(0.4).timeout


# ------------------------------------------------------------------ 3. las preguntas y el nombre
func _preguntas() -> void:
	await Dialogue.say(ANCIANO, LINEAS_PREGUNTA_1)
	await Dialogue.say(_yo, LINEAS_RESPUESTA_1)
	await Dialogue.say(ANCIANO, LINEAS_PREGUNTA_2)
	await Dialogue.say(_yo, LINEAS_RESPUESTA_2)
	await Dialogue.say(ANCIANO, LINEAS_PREGUNTA_NOMBRE)
	GameState.nombre_jugador = await _pedir_nombre()
	await Dialogue.say(SISTEMA, LINEAS_ERROR)
	_yo.display_name = "0x00000000"
	await Dialogue.say(_yo, LINEAS_SIN_NOMBRE)
	await _historia()


## Caja para escribir el nombre. Al aceptarlo, las letras se corrompen hasta quedar en 0x00000000.
func _pedir_nombre() -> String:
	var capa := CanvasLayer.new()
	capa.layer = 15
	capa.scale = Vector2(2, 2)                           # mismo lienzo de 640x360 que la caja de diálogo
	add_child(capa)
	var caja := NinePatchRect.new()
	caja.texture = CAJA
	caja.patch_margin_left = 8
	caja.patch_margin_top = 8
	caja.patch_margin_right = 8
	caja.patch_margin_bottom = 8
	caja.position = Vector2(184, 112)
	caja.size = Vector2(272, 84)
	capa.add_child(caja)
	var titulo := Label.new()
	titulo.add_theme_font_override("font", FUENTE_TITULO)
	titulo.add_theme_font_size_override("font_size", 12)
	titulo.add_theme_color_override("font_color", C_CYAN)
	titulo.text = "¿CÓMO TE LLAMAS?"
	titulo.position = Vector2(14, 10)
	caja.add_child(titulo)
	var campo := LineEdit.new()
	campo.position = Vector2(14, 30)
	campo.size = Vector2(244, 24)
	campo.max_length = 12
	campo.placeholder_text = "Escribe tu nombre"
	campo.add_theme_font_override("font", FUENTE_TEXTO)
	campo.add_theme_font_size_override("font_size", 14)
	campo.add_theme_color_override("font_color", Color(0.933, 0.933, 0.965))
	campo.add_theme_color_override("font_uneditable_color", C_ROSA)
	campo.add_theme_color_override("caret_color", C_CYAN)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.06, 0.06, 0.12, 0.9)
	estilo.border_color = C_CYAN
	estilo.border_width_bottom = 1
	estilo.content_margin_left = 6
	estilo.content_margin_right = 6
	for s in ["normal", "focus", "read_only"]:
		campo.add_theme_stylebox_override(s, estilo)
	caja.add_child(campo)
	var ayuda := Label.new()
	ayuda.add_theme_font_override("font", FUENTE_TEXTO)
	ayuda.add_theme_font_size_override("font_size", 10)
	ayuda.add_theme_color_override("font_color", Color(0.6, 0.62, 0.72))
	ayuda.text = "Enter: aceptar"
	ayuda.position = Vector2(14, 60)
	caja.add_child(ayuda)
	caja.modulate.a = 0.0
	create_tween().tween_property(caja, "modulate:a", 1.0, 0.3)
	campo.grab_focus()

	var nombre := ""
	while nombre == "":
		nombre = String(await campo.text_submitted).strip_edges()
	campo.editable = false
	campo.release_focus()
	ayuda.text = ""

	# se corrompe: cada vez más letras pasan a dígitos hexadecimales, tiembla, y queda en ceros
	var base_x := caja.position.x
	for i in 16:
		var s := ""
		for c in nombre:
			s += HEX[randi() % 16] if randf() < 0.15 + i / 16.0 else c
		campo.text = s
		caja.position.x = base_x + randf_range(-3, 3)
		await get_tree().create_timer(0.07).timeout
	caja.position.x = base_x
	campo.text = "0x00000000"
	titulo.add_theme_color_override("font_color", C_ROSA)
	titulo.text = "ERROR"
	await get_tree().create_timer(1.3).timeout
	var t := create_tween()
	t.tween_property(caja, "modulate:a", 0.0, 0.3)
	await t.finished
	capa.queue_free()
	return nombre


# ------------------------------------------------------------------ 4. la historia
func _historia() -> void:
	# un parpadeo del farol en rosa, apenas (el que habla sabe más de lo que dice)
	var t := create_tween()
	t.tween_property(farol, "color", C_ROSA, 0.05)
	t.tween_property(farol, "color", Color(1.0, 0.78, 0.45), 0.25)
	await Dialogue.say(ANCIANO, LINEAS_HISTORIA)
	await _mover_camara(estanque.global_position + Vector2(60, 0), 2.5, 1.6).finished
	await Dialogue.say(ANCIANO, LINEAS_ESTANQUE)
	await _mover_camara(_entre_los_dos(), 3.0, 1.4).finished
	await Dialogue.say(ANCIANO, LINEAS_TU_VALOR)
	await Dialogue.say(_yo, LINEAS_PREGUNTA_YO)
	await Dialogue.say(ANCIANO, LINEAS_CONSEJO)
	await _se_adelanta()


# ------------------------------------------------------------------ 5. se va, y el jugador queda solo
func _se_adelanta() -> void:
	await _volver_al_jugador()
	await anciano.ir_a($"Llegada del Anciano".global_position)
	var t := create_tween().set_parallel()
	t.tween_property(anciano, "modulate:a", 0.0, 3.6)
	t.tween_property(farol, "energy", 0.0, 3.6)
	await anciano.ir_a($"Ida del Anciano".global_position)
	anciano.visible = false
	jugador.last_direction = Vector2.UP
	await Dialogue.say(SISTEMA, LINEAS_SOLO)
	GameState.en_cinematica = false
	_mostrar_aviso()


func _mostrar_aviso() -> void:
	_aviso = CanvasLayer.new()
	_aviso.layer = 5
	add_child(_aviso)
	var l := Label.new()
	l.add_theme_font_override("font", FUENTE_TEXTO)
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", C_CYAN)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 6)
	l.text = "↑  Sigue el sendero hasta Nullville"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, 24)
	l.size = Vector2(1280, 40)
	_aviso.add_child(l)
	var t := l.create_tween().set_loops()               # muere con el aviso
	t.tween_property(l, "modulate:a", 0.45, 0.8)
	t.tween_property(l, "modulate:a", 1.0, 0.8)


func _on_salida(body: Node2D) -> void:
	if _saliendo or not body.is_in_group("player") or GameState.en_cinematica:
		return
	_saliendo = true
	GameState.en_cinematica = true
	if _aviso:
		_aviso.queue_free()
	var banner = load("res://scenes/ui/banner_nivel.tscn").instantiate()
	add_child(banner)
	await banner.mostrar("NIVEL 1: ALDEA NULLVILLE", "Sus habitantes olvidaron dónde dejaron sus recuerdos.",
		"Ayúdalos y tu memoria volverá, byte a byte.")
	banner.queue_free()
	GameState.en_cinematica = false
	Transicion.ir_a(escena_stage_1)


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


func _mover_camara(destino: Vector2, zoom: float, segundos: float) -> Tween:
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_cam, "global_position", destino, segundos)
	t.tween_property(_cam, "zoom", Vector2(zoom, zoom), segundos)
	return t


func _volver_al_jugador() -> void:
	if _cam == null:
		return
	var del_jugador: Camera2D = jugador.get_node("Camera2D")
	var t := _mover_camara(del_jugador.get_screen_center_position(), del_jugador.zoom.x, 1.2)
	await t.finished
	del_jugador.make_current()
	_cam.queue_free()
	_cam = null


## El punto medio entre el jugador y el Anciano, un poco arriba para que la caja de diálogo no los tape
func _entre_los_dos() -> Vector2:
	return jugador.global_position.lerp($"Junto al jugador".global_position, 0.5) + Vector2(0, 12)
