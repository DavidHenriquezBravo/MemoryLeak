extends Control

enum Estado { MENU, ACCION_COMBATE, RESULTADO, VICTORIA }
enum Accion { ATACAR, DEFENDER, RECUPERAR }

var estado_actual: Estado = Estado.MENU
var accion_actual: Accion = Accion.ATACAR

# --- Puntero y esquiva (se pueden probar desde el Inspector del nodo Pelea) ---
## Con esquiva: el puntero se mueve libre por la caja con las flechas y hay que
## esquivar los bytes rosados (corruptos); los cian son datos sanos y no hacen daño.
## Sin esquiva: el puntero salta entre las respuestas con ← →.
@export var esquiva_activa := true
## Con esto activo basta con tocar una respuesta; si no, se confirma con Z.
@export var responder_al_tocar := false
## Cantidad y velocidad de los bytes (1 = normal, 0 = sin bytes).
@export_range(0.0, 2.0, 0.1) var intensidad_esquiva := 1.0

@export_group("Final del jefe")
## Nivel al que se vuelve al ganar (ej. res://scenes/stages/stage_1.tscn). Obligatorio.
@export_file("*.tscn") var escena_stage: String = ""
## Animación de muerte del jefe (sin loop). Si no existe, se usa un efecto de respaldo.
@export var anim_muerte: StringName = &"muerte"

const TEX_PUNTERO := preload("res://Sprites/Pelea/puntero.png")
const TEX_ESPADA := preload("res://Sprites/Pelea/icono_espada.png")
const TEX_ESCUDO := preload("res://Sprites/Pelea/icono_escudo.png")
const TEX_CRUZ := preload("res://Sprites/Pelea/icono_cruz.png")
const TEX_BYTE_ROSA := preload("res://Sprites/Pelea/byte_rosa.png")
const TEX_BYTE_CIAN := preload("res://Sprites/Pelea/byte_cian.png")
# Upheaval no tiene "&" (lo dibuja como "€") ni minúsculas: el código va en monoespaciada
const FUENTE_CODIGO := preload("res://Fuentes/fuente_codigo.tres")

const ESCALA := 2.0                  # los sprites de la pelea se ven a 2x
const VELOCIDAD_PUNTERO := 260.0
const TAMANO_FLECHA := Vector2(18, 26)  # parte visible del puntero a 2x
const DANIO_BYTE := 3
const INVULNERABLE_S := 0.8
const LECTURA_S := 1.5               # segundos sin bytes para leer la pregunta
const VEL_TEXTO := 45.0              # letras por segundo del texto de la caja

const CAJA_MENU := Rect2(64, 362, 1152, 182)
const CAJA_PREGUNTA := Rect2(282, 344, 716, 196)

const COLOR_CODIGO := Color("9a9a9a")
const COLOR_BIEN := Color("3fbf4f")
const COLOR_MAL := Color("ff3b3b")
const COLOR_CIAN := Color("3de4dd")
const COLOR_NARANJO := Color("ff8a1f")

# --- Referencias de la Escena ---
@onready var caja_central: PanelContainer = $CajaCentral
@onready var menu_panel = $CajaCentral/Menu
@onready var texto_superior: RichTextLabel = $CajaCentral/Menu/TextoSuperior
@onready var texto_inferior: Label = $CajaCentral/Menu/TextoInferior

@onready var ataque_panel: Control = $CajaCentral/Ataque
@onready var pregunta_label: RichTextLabel = $Pregunta
@onready var opciones_container: HBoxContainer = $CajaCentral/Ataque/Opciones
@onready var zona_bytes: Control = $CajaCentral/Ataque/Bytes
@onready var puntero: TextureRect = $CajaCentral/Ataque/Puntero

@onready var defensa_panel = $CajaCentral/Defensa # Si tienes minijuego visual en defensa

# Barra Superior
@onready var barra_superior = $BarraSuperior
@onready var timer_bar: ProgressBar = $BarraSuperior/Timer
@onready var timer_label: Label = $BarraSuperior/Tiempo
@onready var fase_label: Label = $BarraSuperior/Fase

# Jefe
@onready var nombre_jefe: Label = $CosasJefe/NombreJefe
@onready var jefe_anim: AnimatedSprite2D = $CosasJefe/Jefe
@onready var jefe_hp_bar: ProgressBar = $CosasJefe/BarraJefe

# Jugador (HUD)
@onready var player_hp_bar = $HUDJugador/Stats/ProgressBar
@onready var player_hp_label = $HUDJugador/Stats/Cantidad
@onready var danio_label = $HUDJugador/Stats/Daño
@onready var armadura_label = $HUDJugador/Stats/Armadura
@onready var btn_ataque = $HUDJugador/Botones/Ataque
@onready var btn_defender = $HUDJugador/Botones/Defender
@onready var btn_recuperar = $HUDJugador/Botones/Recuperar

# --- Estadísticas del Informe ---
# Las del jugador se cargan desde GameState en _ready (así cuentan las recompensas de misiones)
var player_max_hp: int = 100
var player_hp: int = 100
var danio_base: int = 25
var armadura: float = 0.20 # 20% de mitigación
var suerte: float = 0.15   # probabilidad de golpe crítico
var boss_max_hp: int = 100
var boss_hp: int = 100

# --- Estados alterados del Jefe ---
var boss_cargando_ataque_pesado: bool = false
var ataque_corrompido: bool = false
var vida_corrompida: bool = false

# --- Temporizador ---
var tiempo_maximo: float = 15.0
var tiempo_restante: float = 0.0
var timer_activo: bool = false

# --- Puntero, esquiva y efectos ---
var indice_menu := 0
var opcion_marcada := -1     # respuesta que está bajo el puntero
var respondiendo := false    # true mientras se puede elegir respuesta
var bytes: Array = []        # [{nodo, vel, vida, total, malo}]
var espera_byte := 0.0
var tiempo_en_pregunta := 0.0
var invulnerable := 0.0
var tween_texto: Tween
var tween_caja: Tween
var botones_menu: Array = []
var iconos_menu: Array = []
var estilo_opcion: StyleBoxFlat
var estilo_marcada: StyleBoxFlat
var estilo_bien: StyleBoxFlat
var estilo_mal: StyleBoxFlat

# --- Bancos de Preguntas (Nivel 1: The Memory Leak) ---
var banco_atacar: Array[Dictionary] = [
	{
		"enunciado": "int vida_jefe = 70;  int *ptr = &vida_jefe;\n¿CÓMO BAJAS VIDA_JEFE A 45?",
		"opciones": ["ptr = 45;", "&ptr = 45;", "*ptr = 45;"],
		"correcta": 2,
		"mensaje_error": "MOVISTE EL PUNTERO EN VEZ DE MODIFICAR EL VALOR."
	},
	{
		"enunciado": "int cerradura = 1;  int *p = &cerradura;\n¿CÓMO LA DEJAS EN 0?",
		"opciones": ["p = 0;", "*p = 0;", "&p = 0;"],
		"correcta": 1,
		"mensaje_error": "NO DESREFERENCIASTE LA CERRADURA."
	},
	{
		"enunciado": "int base = 20;  int *p = &base;\n¿CÓMO LE SUMAS 5 AL ORIGINAL?",
		"opciones": ["*p = *p + 5;", "p = p + 5;", "*p = base + 5;"],
		"correcta": 0,
		"mensaje_error": "ALTERASTE LA DIRECCIÓN EN VEZ DEL CONTENIDO."
	}
]

var banco_defender: Array[Dictionary] = [
	{
		"enunciado": "! PREPARA UN NULL DEREFERENCE !\nint *p = NULL;\n¿CUÁL LÍNEA PROVOCA EL COLAPSO?",
		"opciones": ["p = &hp;", "*p = 0;", "p = NULL;"],
		"correcta": 1,
		"mensaje_error": "INTENTASTE DESREFERENCIAR UN PUNTERO NULL."
	},
	{
		"enunciado": "Un puntero vale NULL.\n¿QUÉ SIGNIFICA REALMENTE?",
		"opciones": ["Apunta a la dir 0 válida", "No apunta a nada válido", "Guarda un espacio en blanco"],
		"correcta": 1,
		"mensaje_error": "CONFUNDISTE NULL CON UNA DIRECCIÓN VÁLIDA."
	},
	{
		"enunciado": "int *ptr; // sin inicializar\n¿QUÉ CONTIENE ACTUALMENTE?",
		"opciones": ["Siempre 0", "El valor NULL", "Una dirección indeterminada"],
		"correcta": 2,
		"mensaje_error": "UN PUNTERO NO INICIALIZADO TIENE BASURA INDETERMINADA."
	}
]

var banco_recuperar: Array[Dictionary] = [
	{
		"enunciado": "int hp = 100;  int *ptr = &hp;\n¿QUÉ EXPRESIÓN DEVUELVE EL VALOR REAL?",
		"opciones": ["*ptr", "ptr", "&hp"],
		"correcta": 0,
		"mensaje_error": "NO LOGRASTE LEER LA CELDA DE MEMORIA CORRECTA."
	},
	{
		"enunciado": "Tu daño quedó en una dirección corrupta.\nint danio = 25; int *ptr = &danio;\n¿QUÉ RESTAURA TU ATAQUE?",
		"opciones": ["*ptr = 25;", "ptr = 25;", "&ptr = 25;"],
		"correcta": 0,
		"mensaje_error": "NO LOGRASTE RESTAURAR EL VALOR EN LA DIRECCIÓN."
	}
]

var pregunta_actual: Dictionary = {}

func _ready() -> void:
	_cargar_stats()
	player_hp_bar.max_value = player_max_hp
	jefe_hp_bar.max_value = boss_max_hp
	jefe_hp_bar.value = boss_hp
	_actualizar_hud()

	if jefe_anim.sprite_frames != null:
		jefe_anim.play("default")
	jefe_anim.animation_finished.connect(_on_jefe_animacion_terminada)

	botones_menu = [btn_ataque, btn_defender, btn_recuperar]
	iconos_menu = [TEX_ESPADA, TEX_ESCUDO, TEX_CRUZ]
	_crear_estilos_opcion()
	puntero.size = Vector2(16, 16) * ESCALA
	pregunta_label.hide()

	cambiar_estado(Estado.MENU)

# Stats del jugador desde GameState (incluye las recompensas de misiones)
func _cargar_stats() -> void:
	player_max_hp = GameState.max_hp
	# Si llega con 0 HP (todavía no hay game over), parte con la vida llena
	player_hp = mini(GameState.hp, player_max_hp) if GameState.hp > 0 else player_max_hp
	danio_base = GameState.damage
	armadura = GameState.armor
	suerte = GameState.luck

func _process(delta: float) -> void:
	if timer_activo:
		tiempo_restante -= delta
		timer_bar.value = tiempo_restante
		timer_label.text = "%d S" % ceil(tiempo_restante)

		if tiempo_restante <= 0.0:
			timer_activo = false
			_terminar_respuesta()
			_on_tiempo_agotado()
			return

	if respondiendo:
		_mover_puntero(delta)
		_actualizar_bytes(delta)

	# El puntero parpadea mientras es invulnerable después de un golpe
	if invulnerable > 0.0:
		invulnerable -= delta
		puntero.modulate.a = 0.35 if int(invulnerable * 12.0) % 2 == 0 else 1.0
		if invulnerable <= 0.0:
			puntero.modulate.a = 1.0

# --- Controles: flechas para mover, Z (interact) para elegir ---
func _unhandled_input(event: InputEvent) -> void:
	var manejado := true
	match estado_actual:
		Estado.MENU:
			if event.is_action_pressed("ui_left"):
				_mover_menu(-1)
			elif event.is_action_pressed("ui_right"):
				_mover_menu(1)
			elif event.is_action_pressed("interact"):
				if _texto_escribiendose():
					_terminar_texto()
				else:
					_elegir_accion(indice_menu)
			else:
				manejado = false
		Estado.ACCION_COMBATE:
			if not respondiendo:
				manejado = false
			elif not esquiva_activa and event.is_action_pressed("ui_left"):
				_marcar_opcion(wrapi(opcion_marcada - 1, 0, _n_opciones()))
			elif not esquiva_activa and event.is_action_pressed("ui_right"):
				_marcar_opcion(wrapi(opcion_marcada + 1, 0, _n_opciones()))
			elif event.is_action_pressed("interact") and opcion_marcada >= 0:
				_confirmar_opcion(opcion_marcada)
			else:
				manejado = false
		Estado.RESULTADO:
			if event.is_action_pressed("interact") and _texto_escribiendose():
				_terminar_texto()
			else:
				manejado = false
	if manejado:
		get_viewport().set_input_as_handled()

# --- Máquina de Estados ---
func cambiar_estado(nuevo_estado: Estado) -> void:
	estado_actual = nuevo_estado
	timer_activo = false
	respondiendo = false

	menu_panel.hide()
	ataque_panel.hide()
	defensa_panel.hide()
	barra_superior.hide()
	pregunta_label.hide()
	nombre_jefe.show()
	# El borde vuelve a blanco solo al cambiar de turno; en RESULTADO se queda
	# rojo si el jugador acaba de recibir daño
	if estado_actual != Estado.RESULTADO:
		_set_borde_color(Color.WHITE)
	_actualizar_iconos_menu()

	match estado_actual:
		Estado.MENU:
			menu_panel.show()
			_mover_caja(CAJA_MENU, true)
			_decidir_intencion_jefe()
			_actualizar_hud()
			_escribir_texto()

		Estado.ACCION_COMBATE:
			ataque_panel.show()
			barra_superior.show()
			pregunta_label.show()
			nombre_jefe.hide()  # la barra de tiempo ocupa su lugar
			_mover_caja(CAJA_PREGUNTA, false)

			match accion_actual:
				Accion.ATACAR:
					_estilo_fase("ATAQUE", COLOR_BIEN, COLOR_NARANJO)
					_cargar_pregunta(banco_atacar.pick_random())
				Accion.DEFENDER:
					_estilo_fase("DEFENSA", COLOR_MAL, COLOR_MAL)
					_cargar_pregunta(banco_defender.pick_random())
				Accion.RECUPERAR:
					_estilo_fase("RECUPERAR", COLOR_BIEN, COLOR_BIEN)
					_cargar_pregunta(banco_recuperar.pick_random())

			_iniciar_timer(15.0)
			_empezar_respuesta()

		Estado.RESULTADO:
			menu_panel.show()
			_mover_caja(CAJA_MENU, true)
			_escribir_texto()
			await get_tree().create_timer(_duracion_texto() + 1.5).timeout
			if not is_inside_tree() or estado_actual != Estado.RESULTADO:
				return
			cambiar_estado(Estado.MENU)

# --- Inteligencia del Jefe por Turno ---
func _decidir_intencion_jefe() -> void:
	# 35% de probabilidad de preparar un ataque potente
	boss_cargando_ataque_pesado = randf() < 0.35

	if boss_cargando_ataque_pesado:
		texto_superior.text = "* ! ALERTA: THE MEMORY LEAK PREPARA UN ATAQUE DEVASTADOR !"
		texto_inferior.text = "* ! DEBES DEFENDERTE O SUFRIRÁS DAÑO MASIVO !"
	elif ataque_corrompido:
		texto_superior.text = "* TU ATAQUE ESTÁ EN UNA DIRECCIÓN CORRUPTA (DAÑO 0x???)."
		texto_inferior.text = "* USA RECUPERAR PARA DESREFERENCIAR Y RESTAURARLO."
	elif vida_corrompida:
		texto_superior.text = "* EL JEFE BLOQUEÓ EL PUNTERO A TU BARRA DE VIDA."
		texto_inferior.text = "* USA RECUPERAR PARA CORREGIR EL REGISTRO."
	else:
		texto_superior.text = "* THE MEMORY LEAK GOTEA BYTES SOBRE EL SUELO."
		texto_inferior.text = "* ELIGE: ATACAR, DEFENDER O RECUPERAR."

# --- Menú de acciones (el puntero reemplaza el ícono del botón elegido) ---
func _mover_menu(paso: int) -> void:
	indice_menu = wrapi(indice_menu + paso, 0, botones_menu.size())
	_actualizar_iconos_menu()

func _actualizar_iconos_menu() -> void:
	for i in botones_menu.size():
		var con_puntero := estado_actual == Estado.MENU and i == indice_menu
		botones_menu[i].icon = _puntero_centrado() if con_puntero else iconos_menu[i]

# El puntero en su hoja está en la esquina; para el botón se centra en 16x16
var _icono_puntero: AtlasTexture
func _puntero_centrado() -> AtlasTexture:
	if _icono_puntero == null:
		_icono_puntero = AtlasTexture.new()
		_icono_puntero.atlas = TEX_PUNTERO
		_icono_puntero.region = Rect2(0, 0, 9, 13)
		_icono_puntero.margin = Rect2(3, 1, 7, 3)
	return _icono_puntero

func _elegir_accion(i: int) -> void:
	accion_actual = [Accion.ATACAR, Accion.DEFENDER, Accion.RECUPERAR][i]
	cambiar_estado(Estado.ACCION_COMBATE)

# --- Cargar y Mostrar Pregunta Dinámica ---
func _cargar_pregunta(pregunta: Dictionary) -> void:
	pregunta_actual = pregunta
	_mostrar_enunciado(pregunta_actual["enunciado"])

	while opciones_container.get_child_count() < pregunta_actual["opciones"].size():
		opciones_container.add_child(opciones_container.get_child(0).duplicate())

	var botones = opciones_container.get_children()
	for i in range(botones.size()):
		var btn = botones[i] as Button
		if i < pregunta_actual["opciones"].size():
			btn.show()
			btn.text = pregunta_actual["opciones"][i]
			_pintar_opcion(i, estilo_opcion, Color.WHITE)
		else:
			btn.hide()

func _es_codigo(linea: String) -> bool:
	return ";" in linea or "//" in linea

# Las líneas de código van en gris y monoespaciada; el resto en Upheaval.
# Con "remate" se dejan solo las líneas de código y se agrega ese texto al final
# (así se muestra "¡DESREFERENCIA CORRECTA!" en lugar de la pregunta, como en el GIF).
func _mostrar_enunciado(texto: String, remate := "", color_remate := Color.WHITE) -> void:
	pregunta_label.clear()
	pregunta_label.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	var primera := true
	for linea in texto.split("\n"):
		var es_codigo := _es_codigo(linea)
		if remate != "" and not es_codigo:
			continue
		if not primera:
			pregunta_label.newline()
		primera = false
		if es_codigo:
			pregunta_label.push_font(FUENTE_CODIGO, 20)
			pregunta_label.push_color(COLOR_CODIGO)
			pregunta_label.add_text(linea)
			pregunta_label.pop()
			pregunta_label.pop()
		else:
			pregunta_label.add_text(linea)
	if remate != "":
		if not primera:
			pregunta_label.newline()
		pregunta_label.push_color(color_remate)
		pregunta_label.add_text(remate)
		pregunta_label.pop()
	pregunta_label.pop()

# --- Respuesta con el puntero ---
func _empezar_respuesta() -> void:
	puntero.hide()
	opcion_marcada = -1
	_limpiar_bytes()
	if tween_caja and tween_caja.is_running():
		await tween_caja.finished
	if estado_actual != Estado.ACCION_COMBATE:
		return
	tiempo_en_pregunta = 0.0
	espera_byte = 0.0
	invulnerable = 0.0
	puntero.modulate.a = 1.0
	puntero.show()
	if esquiva_activa:
		var area := _area_bytes()
		puntero.position = area.get_center() - TAMANO_FLECHA * 0.5
	else:
		_marcar_opcion(0)
	respondiendo = true

func _terminar_respuesta() -> void:
	respondiendo = false
	invulnerable = 0.0
	puntero.modulate.a = 1.0
	_limpiar_bytes()

func _mover_puntero(delta: float) -> void:
	if not esquiva_activa:
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var limite := ataque_panel.size - TAMANO_FLECHA
	puntero.position = (puntero.position + dir * VELOCIDAD_PUNTERO * delta).clamp(Vector2.ZERO, limite)
	# La punta de la flecha es la que "toca" la respuesta
	_marcar_opcion(_opcion_en(puntero.global_position + Vector2(2, 2)))
	if responder_al_tocar and opcion_marcada >= 0:
		_confirmar_opcion(opcion_marcada)

func _opcion_en(punto_global: Vector2) -> int:
	for i in _n_opciones():
		var btn: Control = opciones_container.get_child(i)
		if btn.get_global_rect().has_point(punto_global):
			return i
	return -1

func _n_opciones() -> int:
	return pregunta_actual.get("opciones", []).size()

func _marcar_opcion(i: int) -> void:
	if i == opcion_marcada:
		return
	opcion_marcada = i
	for j in _n_opciones():
		_pintar_opcion(j, estilo_marcada if j == i else estilo_opcion, Color.WHITE)
	if not esquiva_activa and i >= 0:
		# Sin esquiva el puntero salta a la respuesta marcada
		var btn: Control = opciones_container.get_child(i)
		var rect := btn.get_global_rect()
		puntero.global_position = Vector2(rect.end.x - 34, rect.get_center().y - 8)

func _confirmar_opcion(i: int) -> void:
	if not respondiendo:
		return
	timer_activo = false
	_terminar_respuesta()
	var correcta: int = pregunta_actual["correcta"]
	var acierto := i == correcta
	# Se marca la correcta en verde y, si fallaste, la tuya en rojo
	_pintar_opcion(correcta, estilo_bien, Color.BLACK)
	if not acierto:
		_pintar_opcion(i, estilo_mal, Color.WHITE)
	_mostrar_enunciado(pregunta_actual["enunciado"], _texto_remate(acierto), COLOR_BIEN if acierto else COLOR_MAL)
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree() or estado_actual != Estado.ACCION_COMBATE:
		return
	_on_opcion_seleccionada(i)

func _texto_remate(acierto: bool) -> String:
	if not acierto:
		return "¡INCORRECTO!"
	match accion_actual:
		Accion.ATACAR:
			return "¡DESREFERENCIA CORRECTA!"
		Accion.DEFENDER:
			return "¡DEFENSA CORRECTA!"
	return "¡MEMORIA RESTAURADA!"

# --- Esquiva: bytes que flotan sobre las respuestas ---
func _parametros_bytes() -> Dictionary:
	# intervalo entre bytes, máximo en pantalla, rango de velocidad y probabilidad de que sea corrupto
	var p := {"intervalo": 0.6, "max": 7, "vel": Vector2(45, 85), "malo": 0.45}
	match accion_actual:
		Accion.DEFENDER:
			p = {"intervalo": 0.45, "max": 9, "vel": Vector2(60, 110), "malo": 0.6}
		Accion.RECUPERAR:
			p = {"intervalo": 0.8, "max": 5, "vel": Vector2(40, 70), "malo": 0.35}
	if boss_cargando_ataque_pesado:
		p["vel"] *= 1.3
	return p

# Los bytes viven arriba de las respuestas, así la fila de respuestas siempre se lee
func _area_bytes() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(ataque_panel.size.x, opciones_container.position.y - 6.0))

func _actualizar_bytes(delta: float) -> void:
	if not esquiva_activa or intensidad_esquiva <= 0.0:
		return
	tiempo_en_pregunta += delta
	if tiempo_en_pregunta < LECTURA_S:
		return

	var p := _parametros_bytes()
	espera_byte -= delta
	if espera_byte <= 0.0 and bytes.size() < maxi(1, int(p["max"] * intensidad_esquiva)):
		_crear_byte(p)
		espera_byte = p["intervalo"] / intensidad_esquiva

	var area := _area_bytes()
	var tam := Vector2(16, 16) * ESCALA
	var cuerpo_puntero := Rect2(puntero.position + Vector2(1, 1), Vector2(12, 18))
	for b in bytes.duplicate():
		var nodo: TextureRect = b["nodo"]
		b["vida"] -= delta
		if b["vida"] <= 0.0:
			nodo.queue_free()
			bytes.erase(b)
			continue
		var vel: Vector2 = b["vel"]
		var pos: Vector2 = nodo.position + vel * delta
		if pos.x < area.position.x or pos.x + tam.x > area.end.x:
			vel.x = -vel.x
			pos.x = clampf(pos.x, area.position.x, area.end.x - tam.x)
		if pos.y < area.position.y or pos.y + tam.y > area.end.y:
			vel.y = -vel.y
			pos.y = clampf(pos.y, area.position.y, area.end.y - tam.y)
		b["vel"] = vel
		nodo.position = pos
		# Aparece y se va con un fundido; solo hace daño cuando está sólido
		nodo.modulate.a = clampf(minf((b["total"] - b["vida"]) / 0.3, b["vida"] / 0.4), 0.0, 1.0)
		var rect_byte := Rect2(pos + Vector2(6, 6), Vector2(20, 20))
		if b["malo"] and invulnerable <= 0.0 and nodo.modulate.a >= 1.0 and cuerpo_puntero.intersects(rect_byte):
			_golpe_byte()

func _crear_byte(p: Dictionary) -> void:
	var area := _area_bytes()
	if area.size.y < 40.0:
		return
	var malo: bool = randf() < p["malo"]
	var nodo := TextureRect.new()
	nodo.texture = TEX_BYTE_ROSA if malo else TEX_BYTE_CIAN
	nodo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	nodo.size = Vector2(16, 16) * ESCALA
	nodo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nodo.modulate.a = 0.0
	# Nunca aparece encima del puntero
	var pos := Vector2.ZERO
	for intento in 10:
		pos = Vector2(randf_range(area.position.x, area.end.x - 32.0), randf_range(area.position.y, area.end.y - 32.0))
		if pos.distance_to(puntero.position) > 110.0:
			break
	nodo.position = pos
	zona_bytes.add_child(nodo)
	var rapidez := randf_range(p["vel"].x, p["vel"].y) * clampf(intensidad_esquiva, 0.5, 1.5)
	var vida := randf_range(3.5, 5.0)
	bytes.append({"nodo": nodo, "vel": Vector2.RIGHT.rotated(randf() * TAU) * rapidez,
		"vida": vida, "total": vida, "malo": malo})

func _limpiar_bytes() -> void:
	for b in bytes:
		b["nodo"].queue_free()
	bytes.clear()

func _golpe_byte() -> void:
	invulnerable = INVULNERABLE_S
	var danio := maxi(1, roundi(DANIO_BYTE * (1.0 - armadura)))
	# Los bytes no pueden matarte: la vida se decide con las preguntas
	player_hp = maxi(1, player_hp - danio)
	_guardar_hp()
	_actualizar_hud()
	_numero_flotante(puntero.global_position + Vector2(22, -8), "-%d" % danio, COLOR_MAL, 18)
	_destello_borde()

# --- Resolución de Respuestas ---
func _on_opcion_seleccionada(indice: int) -> void:
	timer_activo = false
	var acierto = (indice == pregunta_actual["correcta"])

	match accion_actual:
		Accion.ATACAR:
			if acierto:
				# Mecánica de suerte del informe: bono por responder rápido (< 5 s)
				# o por la suerte del jugador (GameState.luck)
				var danio_final = danio_base
				var tiempo_empleado = tiempo_maximo - tiempo_restante
				if tiempo_empleado <= 5.0:
					danio_final *= 2
					texto_superior.text = "* ¡GOLPE CRÍTICO RÁPIDO! (SUERTE DUPLICÓ EL DAÑO)"
				elif randf() < suerte:
					danio_final *= 2
					texto_superior.text = "* ¡GOLPE DE SUERTE! (DAÑO x2)"
				else:
					texto_superior.text = "* DESREFERENCIACIÓN CORRECTA: GOLPE EN LA MEMORIA."

				if ataque_corrompido:
					danio_final = 5 # Si atacó estando corrompido, hace daño mínimo
					texto_superior.text = "* ATACASTE CON DIRECCIÓN CORRUPTA: DAÑO REDUCIDO."

				daniar_jefe(danio_final)
				texto_inferior.text = "* VIDA_JEFE BAJÓ A %d." % boss_hp
				if boss_hp <= 0:
					_victoria()
					return
				cambiar_estado(Estado.RESULTADO)
			else:
				# Fallar un ataque permite que el jefe robe un atributo
				if randf() < 0.5:
					ataque_corrompido = true
				else:
					vida_corrompida = true
				recibir_danio_jugador(20, pregunta_actual["mensaje_error"] + " EL JEFE CORROMPIÓ TU SISTEMA.")

		Accion.DEFENDER:
			if acierto:
				texto_superior.text = "* ¡DEFENSA EXITOSA! EVITASTE EL COLAPSO."
				if boss_cargando_ataque_pesado:
					texto_inferior.text = "* ANULASTE SU ATAQUE DEVASTADOR."
					boss_cargando_ataque_pesado = false
				else:
					texto_inferior.text = "* NO RECIBES DAÑO."
				cambiar_estado(Estado.RESULTADO)
			else:
				var golpe = 45 if boss_cargando_ataque_pesado else 25
				boss_cargando_ataque_pesado = false
				recibir_danio_jugador(golpe, pregunta_actual["mensaje_error"])

		Accion.RECUPERAR:
			if acierto:
				curar_jugador(25)
				ataque_corrompido = false
				vida_corrompida = false
				texto_superior.text = "* DIRECCIONES DE MEMORIA RESTAURADAS Y +25 HP."
				texto_inferior.text = "* TUS ESTADÍSTICAS VUELVEN A LA NORMALIDAD."
				cambiar_estado(Estado.RESULTADO)
			else:
				recibir_danio_jugador(15, "FALLO AL RESTAURAR: " + pregunta_actual["mensaje_error"])

func _on_tiempo_agotado() -> void:
	var danio_recibido = 40 if boss_cargando_ataque_pesado else 20
	boss_cargando_ataque_pesado = false
	recibir_danio_jugador(danio_recibido, "SE AGOTÓ EL TIEMPO DE RESPUESTA.")

# --- Daño y Curación ---
func recibir_danio_jugador(cantidad: int, mensaje: String) -> void:
	# Aplicar absorción de armadura del informe
	var danio_mitigado = int(cantidad * (1.0 - armadura))
	player_hp = max(0, player_hp - danio_mitigado)
	_guardar_hp()
	_actualizar_hud()

	texto_superior.text = "* " + mensaje
	# Si el jefe ocultó tu vida, el mensaje tampoco la muestra
	var hp_texto = "??" if vida_corrompida else str(player_hp)
	texto_inferior.text = "* RECIBISTE %d DE DAÑO. (HP: %s)" % [danio_mitigado, hp_texto]
	_set_borde_color(Color("#ff3333"))
	cambiar_estado(Estado.RESULTADO)

func curar_jugador(cantidad: int) -> void:
	player_hp = min(player_max_hp, player_hp + cantidad)
	_guardar_hp()
	_actualizar_hud()

# La vida del jugador vive en GameState para que se mantenga fuera de la pelea
func _guardar_hp() -> void:
	GameState.hp = player_hp
	GameState.stats_changed.emit()

func daniar_jefe(cantidad: int) -> void:
	boss_hp = max(0, boss_hp - cantidad)
	var tween = create_tween()
	tween.tween_property(jefe_hp_bar, "value", boss_hp, 0.3)
	_efecto_golpe_jefe(cantidad)

# Corte diagonal, animación de daño y número rojo, como en el GIF de referencia
func _efecto_golpe_jefe(cantidad: int) -> void:
	# el cuerpo del slime está en la mitad de abajo de su cuadro de 112x96
	var centro := jefe_anim.global_position + Vector2(0, 30)
	var desde := centro + Vector2(-120, 90)
	var hasta := centro + Vector2(120, -90)
	var corte := Line2D.new()
	corte.width = 6.0
	corte.default_color = Color("dffcfa")
	corte.points = PackedVector2Array([desde, desde])
	add_child(corte)
	var t := create_tween()
	t.tween_method(func(v: float): corte.points = PackedVector2Array([desde, desde.lerp(hasta, v)]), 0.0, 1.0, 0.12)
	t.tween_property(corte, "modulate:a", 0.0, 0.25)
	t.tween_callback(corte.queue_free)

	if jefe_anim.sprite_frames.has_animation("dano"):
		jefe_anim.play("dano")
	_numero_flotante(centro + Vector2(80, -80), "-%d" % cantidad, COLOR_MAL, 28)

func _on_jefe_animacion_terminada() -> void:
	if jefe_anim.animation == "dano":
		jefe_anim.play("default")

func _numero_flotante(pos_global: Vector2, texto: String, color: Color, tamano: int) -> void:
	var l := Label.new()
	l.text = texto
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	l.global_position = pos_global
	var t := create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y - 30.0, 0.8)
	t.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.3)
	t.chain().tween_callback(l.queue_free)

func _actualizar_hud() -> void:
	# Manejo visual de corrupción de atributos
	if vida_corrompida:
		player_hp_label.text = "??/??"
		player_hp_bar.value = 0
	else:
		player_hp_label.text = "%d/%d" % [player_hp, player_max_hp]
		player_hp_bar.value = player_hp

	if ataque_corrompido:
		danio_label.text = "DAÑO 0x???"
	else:
		danio_label.text = "DAÑO %d" % danio_base

	armadura_label.text = "ARM %d%%" % roundi(armadura * 100.0)

# --- Texto de la caja: se escribe letra por letra (Z lo completa) ---
func _escribir_texto() -> void:
	texto_superior.visible_ratio = 0.0
	texto_inferior.visible_ratio = 0.0
	if tween_texto:
		tween_texto.kill()
	tween_texto = create_tween()
	tween_texto.tween_property(texto_superior, "visible_ratio", 1.0, maxf(0.05, texto_superior.get_parsed_text().length() / VEL_TEXTO))
	tween_texto.tween_property(texto_inferior, "visible_ratio", 1.0, maxf(0.05, texto_inferior.text.length() / VEL_TEXTO))

func _duracion_texto() -> float:
	return (texto_superior.get_parsed_text().length() + texto_inferior.text.length()) / VEL_TEXTO

func _texto_escribiendose() -> bool:
	return tween_texto != null and tween_texto.is_running()

func _terminar_texto() -> void:
	if tween_texto:
		tween_texto.kill()
	texto_superior.visible_ratio = 1.0
	texto_inferior.visible_ratio = 1.0

# --- Temporizador y Visuales ---
func _iniciar_timer(duracion: float) -> void:
	tiempo_maximo = duracion
	tiempo_restante = duracion
	timer_bar.max_value = duracion
	timer_bar.value = duracion
	timer_label.text = "%d S" % ceil(duracion)
	timer_activo = true

func _estilo_fase(nombre: String, color_texto: Color, color_barra: Color) -> void:
	fase_label.text = nombre
	fase_label.add_theme_color_override("font_color", color_texto)
	timer_label.add_theme_color_override("font_color", color_barra)
	var relleno := timer_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if relleno:
		relleno.bg_color = color_barra

# La caja se achica para las preguntas y vuelve a crecer para el texto
func _mover_caja(destino: Rect2, modo_menu: bool) -> void:
	var sb := caja_central.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		var m := 10.0
		sb.content_margin_left = 26.0 if modo_menu else m
		sb.content_margin_right = 26.0 if modo_menu else m
		sb.content_margin_top = 18.0 if modo_menu else m
		sb.content_margin_bottom = 16.0 if modo_menu else m
	if tween_caja:
		tween_caja.kill()
	tween_caja = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_caja.tween_property(caja_central, "position", destino.position, 0.18)
	tween_caja.tween_property(caja_central, "size", destino.size, 0.18)

func _set_borde_color(color: Color) -> void:
	var sb = caja_central.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		sb.border_color = color

func _destello_borde() -> void:
	_set_borde_color(COLOR_MAL)
	await get_tree().create_timer(0.12).timeout
	if is_inside_tree() and estado_actual == Estado.ACCION_COMBATE:
		_set_borde_color(Color.WHITE)

func _crear_estilos_opcion() -> void:
	estilo_opcion = (opciones_container.get_child(0) as Button).get_theme_stylebox("normal") as StyleBoxFlat
	estilo_marcada = _estilo_derivado(COLOR_CIAN, Color("0f2d2c"))
	estilo_bien = _estilo_derivado(COLOR_BIEN, COLOR_BIEN)
	estilo_mal = _estilo_derivado(COLOR_MAL, COLOR_MAL)

func _estilo_derivado(borde: Color, fondo: Color) -> StyleBoxFlat:
	var s := estilo_opcion.duplicate() as StyleBoxFlat
	s.border_color = borde
	s.bg_color = fondo
	return s

func _pintar_opcion(i: int, estilo: StyleBoxFlat, color_texto: Color) -> void:
	var btn := opciones_container.get_child(i) as Button
	btn.add_theme_stylebox_override("normal", estilo)
	btn.add_theme_color_override("font_color", color_texto)

# --- Victoria: muerte del jefe -> cartel de felicitación -> vuelta al nivel ---
func _victoria() -> void:
	cambiar_estado(Estado.VICTORIA)
	_limpiar_bytes()
	GameState.boss_defeated = true
	_guardar_hp()
	await get_tree().create_timer(0.6).timeout   # deja ver el último golpe
	await _muerte_jefe()

	var banner = load("res://scenes/ui/banner_nivel.tscn").instantiate()
	add_child(banner)
	await banner.mostrar("¡NIVEL 1 SUPERADO!", "Derrotaste a THE MEMORY LEAK.", "Recuperaste el control de la memoria.")
	banner.queue_free()
	await _ir_a_stage()

func _muerte_jefe() -> void:
	if jefe_anim.sprite_frames and jefe_anim.sprite_frames.has_animation(anim_muerte):
		jefe_anim.play(anim_muerte)
		await jefe_anim.animation_finished
		return
	# Respaldo mientras no esté la animación: tiembla, destella y se desvanece
	var base := jefe_anim.position
	var t := create_tween()
	for i in 10:
		t.tween_property(jefe_anim, "position", base + Vector2(randf_range(-8.0, 8.0), randf_range(-4.0, 4.0)), 0.05)
	t.tween_property(jefe_anim, "position", base, 0.05)
	t.tween_property(jefe_anim, "modulate", Color(3, 3, 3, 1), 0.15)
	t.tween_property(jefe_anim, "modulate", Color(1, 1, 1, 0), 0.8)
	await t.finished

func _ir_a_stage() -> void:
	if escena_stage == "":
		push_warning("Pelea: falta asignar 'Escena Stage' en el inspector")
		return
	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(velo)
	var t := create_tween()
	t.tween_property(velo, "color:a", 1.0, 0.6)
	await t.finished
	get_tree().change_scene_to_file(escena_stage)
