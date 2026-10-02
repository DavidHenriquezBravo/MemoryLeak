extends Control

enum Estado { MENU, ACCION_COMBATE, RESULTADO, VICTORIA, DERROTA }
enum Accion { ATACAR, DEFENDER, RECUPERAR }
enum Intencion { NADA, ATAQUE, ROBO }   # lo que hace el jefe al empezar cada turno

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
## Solo la velocidad de los bytes (1 = normal, 0.5 = la mitad). Cada jefe usa la suya.
@export_range(0.2, 2.0, 0.05) var velocidad_bytes := 1.0

@export_group("Jefe")
## Banco de preguntas del jefe (ver data/jefes/banco_jefe_1.gd).
@export_file("*.gd") var banco_preguntas: String = "res://data/jefes/banco_jefe_1.gd"
## Probabilidad por turno de que el jefe anuncie un ataque (ese turno solo se puede defender).
@export_range(0.0, 1.0, 0.05) var prob_ataque := 0.3
## Probabilidad por turno de que el jefe te robe vida o una estadística.
@export_range(0.0, 1.0, 0.05) var prob_robo := 0.25

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
const ESCENA_GAME_OVER := preload("res://scenes/ui/game_over.tscn")

const ESCALA := 2.0                  # los sprites de la pelea se ven a 2x
const VELOCIDAD_PUNTERO := 260.0
const TAMANO_FLECHA := Vector2(18, 26)  # parte visible del puntero a 2x
const DANIO_BYTE := 3
const INVULNERABLE_S := 0.8
const LECTURA_S := 1.5               # segundos sin bytes para leer la pregunta
const VEL_TEXTO := 45.0              # letras por segundo del texto de la caja

# Robo de memoria: cuánto se lleva el jefe de cada cosa
const ROBO_VIDA := 10                # HP que te quita (y que el jefe se cura)
const ROBO_DANIO := 5
const ROBO_ARMADURA := 0.10

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
@onready var musica: AudioStreamPlayer = $Musica

# --- Estadísticas del Informe ---
# Las del jugador se cargan desde GameState en _ready (así cuentan las recompensas de misiones)
var player_max_hp: int = 100
var player_hp: int = 100
var danio_base: int = 25
var armadura: float = 0.20 # 20% de mitigación
var suerte: float = 0.15   # probabilidad de golpe crítico
var boss_max_hp: int = 100
var boss_hp: int = 100

# --- Turno del Jefe ---
var turno := 0
var intencion: Intencion = Intencion.NADA
## Lo que el jefe te robó y todavía no recuperas: "vida" / "danio" / "armadura" -> cantidad
var robos := {}
var acciones_bloqueadas: Array[int] = []   # índices del menú que no se pueden elegir este turno

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

# --- Banco de Preguntas (carrusel) ---
var banco := {}            # Accion -> todas las preguntas de esa acción
var cola := {}             # Accion -> preguntas que faltan en la vuelta actual
var provocaciones := {}    # frases del jefe por acción
## La pregunta en pantalla: {"base": ítem del banco, "opciones": barajadas, "correcta": índice, "mensaje_error"}
var pregunta_actual: Dictionary = {}

func _ready() -> void:
	_cargar_stats()
	_cargar_banco()
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
	# Si llega con 0 HP (por ejemplo después de un game over), parte con la vida llena
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
		Estado.RESULTADO, Estado.DERROTA:
			if event.is_action_pressed("interact") and _texto_escribiendose():
				_terminar_texto()
			else:
				manejado = false
		_:
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
	# El borde vuelve a blanco solo al cambiar de turno; en RESULTADO y DERROTA se queda
	# rojo si el jugador acaba de recibir daño
	if estado_actual != Estado.RESULTADO and estado_actual != Estado.DERROTA:
		_set_borde_color(Color.WHITE)
	_actualizar_iconos_menu()

	match estado_actual:
		Estado.MENU:
			menu_panel.show()
			_mover_caja(CAJA_MENU, true)
			_decidir_intencion_jefe()
			if acciones_bloqueadas.has(indice_menu):
				_mover_menu(1)
			_actualizar_iconos_menu()
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
				Accion.DEFENDER:
					_estilo_fase("DEFENSA", COLOR_MAL, COLOR_MAL)
				Accion.RECUPERAR:
					_estilo_fase("RECUPERAR", COLOR_BIEN, COLOR_BIEN)
			_cargar_pregunta(_siguiente_pregunta(accion_actual))

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

		Estado.DERROTA:
			menu_panel.show()
			_mover_caja(CAJA_MENU, true)
			_escribir_texto()

# --- Inteligencia del Jefe por Turno ---
func _decidir_intencion_jefe() -> void:
	turno += 1
	intencion = Intencion.NADA
	acciones_bloqueadas.clear()
	if turno > 1:   # el primer turno siempre es tranquilo
		var r := randf()
		if r < prob_ataque:
			intencion = Intencion.ATAQUE
		elif r < prob_ataque + prob_robo and not _robos_disponibles().is_empty():
			intencion = Intencion.ROBO

	match intencion:
		Intencion.ATAQUE:
			# Este turno solo se puede defender: ATACAR y RECUPERAR quedan bloqueados
			acciones_bloqueadas = [0, 2]
			texto_superior.text = "* ! THE MEMORY LEAK PREPARA UN ATAQUE DEVASTADOR !"
			texto_inferior.text = "* ! SOLO PUEDES DEFENDERTE !"
		Intencion.ROBO:
			var robo := _robar(_robos_disponibles().pick_random())
			texto_superior.text = robo["aviso"]
			texto_inferior.text = robo["detalle"]
		_:
			_texto_turno_tranquilo()

func _jefe_ataca() -> bool:
	return intencion == Intencion.ATAQUE

func _texto_turno_tranquilo() -> void:
	# Si te falta algo, el jefe te lo recuerda; si no, gotea o te provoca
	if robos.has("danio"):
		texto_superior.text = "* TU DAÑO SIGUE ESCONDIDO EN UNA DIRECCIÓN CORRUPTA."
		texto_inferior.text = "* USA RECUPERAR PARA RESTAURARLO."
	elif robos.has("armadura"):
		texto_superior.text = "* TU ARMADURA SIGUE ESCONDIDA EN UNA DIRECCIÓN CORRUPTA."
		texto_inferior.text = "* USA RECUPERAR PARA RESTAURARLA."
	elif robos.has("vida"):
		texto_superior.text = "* EL JEFE SIGUE BLOQUEANDO EL PUNTERO A TU VIDA."
		texto_inferior.text = "* USA RECUPERAR PARA VOLVER A VERLA."
	else:
		var frases: Array = ["* THE MEMORY LEAK GOTEA BYTES SOBRE EL SUELO."]
		for p in provocaciones.values():
			frases.append("* \"%s\"" % p)
		texto_superior.text = frases.pick_random() if turno > 1 else frases[0]
		texto_inferior.text = "* ELIGE: ATACAR, DEFENDER O RECUPERAR."

# --- Robo de memoria ---
func _robos_disponibles() -> Array:
	var lista := []
	if not robos.has("vida") and player_hp > ROBO_VIDA:
		lista.append("vida")
	if not robos.has("danio") and danio_base > ROBO_DANIO:
		lista.append("danio")
	if not robos.has("armadura") and armadura > 0.0:
		lista.append("armadura")
	return lista

## Aplica el robo y devuelve los textos: "aviso" y "detalle" para la caja, "corto" para combinar
func _robar(tipo: String) -> Dictionary:
	var r := {}
	match tipo:
		"vida":
			var cantidad := mini(ROBO_VIDA, player_hp - 1)   # el robo nunca te deja en 0
			player_hp -= cantidad
			boss_hp = mini(boss_max_hp, boss_hp + cantidad)
			create_tween().tween_property(jefe_hp_bar, "value", boss_hp, 0.3)
			robos["vida"] = cantidad
			_guardar_hp()
			_parpadear(player_hp_label)
			r = {"aviso": "* THE MEMORY LEAK TE ROBÓ %d DE VIDA Y SE CURÓ." % cantidad,
				"detalle": "* ADEMÁS ESCONDIÓ TU VIDA. USA RECUPERAR PARA VERLA.",
				"corto": "%d DE VIDA" % cantidad}
		"danio":
			danio_base -= ROBO_DANIO
			robos["danio"] = ROBO_DANIO
			_parpadear(danio_label)
			r = {"aviso": "* THE MEMORY LEAK TE ROBÓ %d DE DAÑO." % ROBO_DANIO,
				"detalle": "* LO ESCONDIÓ EN UNA DIRECCIÓN CORRUPTA. USA RECUPERAR.",
				"corto": "%d DE DAÑO" % ROBO_DANIO}
		"armadura":
			var cantidad := minf(ROBO_ARMADURA, armadura)
			armadura -= cantidad
			robos["armadura"] = cantidad
			_parpadear(armadura_label)
			r = {"aviso": "* THE MEMORY LEAK TE ROBÓ %d%% DE ARMADURA." % roundi(cantidad * 100.0),
				"detalle": "* LA ESCONDIÓ EN UNA DIRECCIÓN CORRUPTA. USA RECUPERAR.",
				"corto": "%d%% DE ARMADURA" % roundi(cantidad * 100.0)}
	_actualizar_hud()
	return r

## Devuelve lo robado y lo describe ("5 DE DAÑO, 10% DE ARMADURA"); "" si no faltaba nada
func _restaurar_robos() -> String:
	var partes: Array[String] = []
	if robos.has("danio"):
		danio_base += robos["danio"]
		partes.append("%d DE DAÑO" % robos["danio"])
	if robos.has("armadura"):
		armadura += robos["armadura"]
		partes.append("%d%% DE ARMADURA" % roundi(robos["armadura"] * 100.0))
	if robos.has("vida"):
		partes.append("EL REGISTRO DE TU VIDA")
	robos.clear()
	_actualizar_hud()
	return ", ".join(partes)

# --- Menú de acciones (el puntero reemplaza el ícono del botón elegido) ---
func _mover_menu(paso: int) -> void:
	# Salta los botones bloqueados (cuando el jefe ataca solo queda DEFENDER)
	for i in botones_menu.size():
		indice_menu = wrapi(indice_menu + paso, 0, botones_menu.size())
		if not acciones_bloqueadas.has(indice_menu):
			break
	_actualizar_iconos_menu()

func _actualizar_iconos_menu() -> void:
	for i in botones_menu.size():
		var con_puntero := estado_actual == Estado.MENU and i == indice_menu
		botones_menu[i].icon = _puntero_centrado() if con_puntero else iconos_menu[i]
		botones_menu[i].modulate.a = 0.25 if acciones_bloqueadas.has(i) else 1.0

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
	if acciones_bloqueadas.has(i):
		return
	accion_actual = [Accion.ATACAR, Accion.DEFENDER, Accion.RECUPERAR][i]
	cambiar_estado(Estado.ACCION_COMBATE)

# --- Banco de preguntas: carrusel sin repetir ---
func _cargar_banco() -> void:
	var datos: Dictionary = (load(banco_preguntas) as GDScript).get_script_constant_map()
	provocaciones = datos.get("PROVOCACIONES", {})
	var por_nombre := {"atacar": Accion.ATACAR, "defender": Accion.DEFENDER, "recuperar": Accion.RECUPERAR}
	for a in Accion.values():
		banco[a] = []
		cola[a] = []
	for q in datos.get("PREGUNTAS", []):
		banco[por_nombre[q["accion"]]].append(q)

# Cada pregunta sale una vez por vuelta. Las que respondes bien no vuelven a salir
# (quedan anotadas en GameState); las que fallas vuelven al final de la fila.
func _siguiente_pregunta(accion: Accion) -> Dictionary:
	if cola[accion].is_empty():
		var pendientes: Array = banco[accion].filter(
			func(q): return not GameState.preguntas_jefe_resueltas.has(q["id"]))
		if pendientes.is_empty():
			# Ya respondió bien todas las de esta acción: empieza una vuelta nueva
			for q in banco[accion]:
				GameState.preguntas_jefe_resueltas.erase(q["id"])
			pendientes = banco[accion].duplicate()
		pendientes.shuffle()
		cola[accion] = pendientes
	return cola[accion].pop_front()

func _registrar_respuesta(acierto: bool) -> void:
	var base: Dictionary = pregunta_actual["base"]
	if acierto:
		if not GameState.preguntas_jefe_resueltas.has(base["id"]):
			GameState.preguntas_jefe_resueltas.append(base["id"])
	elif not cola[accion_actual].has(base):
		cola[accion_actual].push_back(base)

# --- Cargar y Mostrar Pregunta Dinámica ---
func _cargar_pregunta(base: Dictionary) -> void:
	# Las opciones se barajan cada vez, así la correcta no queda siempre en el mismo botón
	var orden := range(base["opciones"].size())
	orden.shuffle()
	var opciones: Array = []
	for o in orden:
		opciones.append(base["opciones"][o])
	pregunta_actual = {
		"base": base,
		"opciones": opciones,
		"correcta": orden.find(int(base["correcta"])),
		"mensaje_error": base["error"],
	}
	_mostrar_enunciado()

	while opciones_container.get_child_count() < opciones.size():
		opciones_container.add_child(opciones_container.get_child(0).duplicate())

	var botones = opciones_container.get_children()
	for i in range(botones.size()):
		var btn = botones[i] as Button
		if i < opciones.size():
			btn.show()
			btn.text = (opciones[i] as String).replace("`", "")
			_pintar_opcion(i, estilo_opcion, Color.WHITE)
		else:
			btn.hide()

# Arriba la situación (código en gris) y abajo la pregunta. Con "remate" la pregunta
# se cambia por ese texto (así se muestra "¡DESREFERENCIA CORRECTA!", como en el GIF).
func _mostrar_enunciado(remate := "", color_remate := Color.WHITE) -> void:
	var base: Dictionary = pregunta_actual["base"]
	pregunta_label.clear()
	pregunta_label.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	_agregar_con_codigo(base["situacion"], COLOR_CODIGO)
	pregunta_label.newline()
	if remate != "":
		pregunta_label.push_color(color_remate)
		pregunta_label.add_text(remate)
		pregunta_label.pop()
	else:
		_agregar_con_codigo(base["pregunta"], Color.WHITE)
	pregunta_label.pop()

# Lo que va entre `comillas invertidas` se escribe con la fuente de código
func _agregar_con_codigo(texto: String, color: Color) -> void:
	var partes := texto.split("`")
	for i in partes.size():
		if partes[i] == "":
			continue
		if i % 2 == 1:
			pregunta_label.push_font(FUENTE_CODIGO, 20)
		pregunta_label.push_color(color)
		pregunta_label.add_text(partes[i])
		pregunta_label.pop()
		if i % 2 == 1:
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
		puntero.position = Vector2(area.get_center().x, area.size.y * 0.35) - TAMANO_FLECHA * 0.5
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
	_mostrar_enunciado(_texto_remate(acierto), COLOR_BIEN if acierto else COLOR_MAL)
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

# --- Esquiva: bytes que cruzan toda la caja, también las respuestas ---
func _parametros_bytes() -> Dictionary:
	# intervalo entre bytes, máximo en pantalla, rango de velocidad y probabilidad de que sea corrupto
	var p := {"intervalo": 0.6, "max": 7, "vel": Vector2(45, 85), "malo": 0.45}
	match accion_actual:
		Accion.DEFENDER:
			p = {"intervalo": 0.45, "max": 9, "vel": Vector2(60, 110), "malo": 0.6}
		Accion.RECUPERAR:
			p = {"intervalo": 0.8, "max": 5, "vel": Vector2(40, 70), "malo": 0.35}
	if _jefe_ataca():
		p["vel"] *= 1.3
	return p

func _area_bytes() -> Rect2:
	return Rect2(Vector2.ZERO, ataque_panel.size)

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
	var rapidez := randf_range(p["vel"].x, p["vel"].y) * clampf(intensidad_esquiva, 0.5, 1.5) * velocidad_bytes
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
	_registrar_respuesta(acierto)

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

				if robos.has("danio"):
					texto_superior.text = "* ATACASTE CON TU DAÑO CORRUPTO: EL GOLPE PERDIÓ FUERZA."

				daniar_jefe(danio_final)
				texto_inferior.text = "* VIDA_JEFE BAJÓ A %d." % boss_hp
				if boss_hp <= 0:
					_victoria()
					return
				cambiar_estado(Estado.RESULTADO)
			else:
				# Fallar un ataque deja que el jefe te robe algo, además del golpe
				var robo := {}
				var disponibles := _robos_disponibles()
				if not disponibles.is_empty():
					robo = _robar(disponibles.pick_random())
				recibir_danio_jugador(20, pregunta_actual["mensaje_error"], robo.get("corto", ""))

		Accion.DEFENDER:
			if acierto:
				texto_superior.text = "* ¡DEFENSA EXITOSA! EVITASTE EL COLAPSO."
				if _jefe_ataca():
					texto_inferior.text = "* ANULASTE SU ATAQUE DEVASTADOR."
				else:
					texto_inferior.text = "* NO RECIBES DAÑO."
				cambiar_estado(Estado.RESULTADO)
			else:
				var golpe = 45 if _jefe_ataca() else 25
				recibir_danio_jugador(golpe, pregunta_actual["mensaje_error"])

		Accion.RECUPERAR:
			if acierto:
				var recuperado := _restaurar_robos()
				curar_jugador(25)
				texto_superior.text = "* MEMORIA RESTAURADA: +25 HP."
				if recuperado != "":
					texto_inferior.text = "* RECUPERASTE %s." % recuperado
				else:
					texto_inferior.text = "* TUS ESTADÍSTICAS ESTÁN EN ORDEN."
				cambiar_estado(Estado.RESULTADO)
			else:
				recibir_danio_jugador(15, "FALLO AL RESTAURAR: " + pregunta_actual["mensaje_error"])

func _on_tiempo_agotado() -> void:
	_registrar_respuesta(false)
	var danio_recibido = 40 if _jefe_ataca() else 20
	recibir_danio_jugador(danio_recibido, "SE AGOTÓ EL TIEMPO DE RESPUESTA.")

# --- Daño y Curación ---
func recibir_danio_jugador(cantidad: int, mensaje: String, robo_corto := "") -> void:
	# Aplicar absorción de armadura del informe
	var danio_mitigado = int(cantidad * (1.0 - armadura))
	player_hp = max(0, player_hp - danio_mitigado)
	_guardar_hp()
	_actualizar_hud()
	_set_borde_color(Color("#ff3333"))

	texto_superior.text = "* " + mensaje
	if player_hp <= 0:
		texto_inferior.text = "* RECIBISTE %d DE DAÑO. TU VIDA LLEGÓ A 0." % danio_mitigado
		_derrota()
		return
	if robo_corto != "":
		texto_inferior.text = "* RECIBISTE %d DE DAÑO Y EL JEFE TE ROBÓ %s." % [danio_mitigado, robo_corto]
	else:
		# Si el jefe escondió tu vida, el mensaje tampoco la muestra
		var hp_texto = "??" if robos.has("vida") else str(player_hp)
		texto_inferior.text = "* RECIBISTE %d DE DAÑO. (HP: %s)" % [danio_mitigado, hp_texto]
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
	# Lo que el jefe robó se muestra escondido hasta que uses RECUPERAR
	if robos.has("vida"):
		player_hp_label.text = "??/??"
		player_hp_bar.value = 0
	else:
		player_hp_label.text = "%d/%d" % [player_hp, player_max_hp]
		player_hp_bar.value = player_hp

	if robos.has("danio"):
		danio_label.text = "DAÑO 0x???"
	else:
		danio_label.text = "DAÑO %d" % danio_base

	if robos.has("armadura"):
		armadura_label.text = "ARM 0x??"
	else:
		armadura_label.text = "ARM %d%%" % roundi(armadura * 100.0)

func _parpadear(control: CanvasItem) -> void:
	var t := create_tween()
	for i in 3:
		t.tween_property(control, "modulate", COLOR_MAL, 0.08)
		t.tween_property(control, "modulate", Color.WHITE, 0.08)

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

# --- Derrota: la vida llegó a 0 -> pantalla de GAME OVER ---
func _derrota() -> void:
	cambiar_estado(Estado.DERROTA)
	_limpiar_bytes()
	await get_tree().create_timer(_duracion_texto() + 1.5).timeout
	if not is_inside_tree():
		return
	create_tween().tween_property(musica, "volume_db", -40.0, 1.0)
	var game_over := ESCENA_GAME_OVER.instantiate()
	game_over.reintentar.connect(_reintentar)
	game_over.salir.connect(_salir_al_menu)
	add_child(game_over)

# Reintentar: la pelea empieza de nuevo con la vida llena. Las preguntas que ya
# respondiste bien siguen fuera del carrusel (están en GameState).
func _reintentar() -> void:
	GameState.hp = GameState.max_hp
	GameState.stats_changed.emit()
	get_tree().reload_current_scene()

func _salir_al_menu() -> void:
	GameState.hp = GameState.max_hp
	GameState.stats_changed.emit()
	get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))

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
