extends Control

enum Estado { MENU, ACCION_COMBATE, RESULTADO }
enum Accion { ATACAR, DEFENDER, RECUPERAR }

var estado_actual: Estado = Estado.MENU
var accion_actual: Accion = Accion.ATACAR

# --- Referencias de la Escena ---
@onready var caja_central = $CajaCentral
@onready var menu_panel = $CajaCentral/Menu
@onready var texto_superior = $CajaCentral/Menu/TextoSuperior
@onready var texto_inferior = $CajaCentral/Menu/TextoInferior

@onready var ataque_panel = $CajaCentral/Ataque
@onready var pregunta_label = $CajaCentral/Ataque/Pregunta
@onready var opciones_container = $CajaCentral/Ataque/Opciones

@onready var defensa_panel = $CajaCentral/Defensa # Si tienes minijuego visual en defensa

# Barra Superior
@onready var barra_superior = $BarraSuperior
@onready var timer_bar = $BarraSuperior/Timer
@onready var timer_label = $BarraSuperior/Tiempo
@onready var fase_label = $BarraSuperior/Fase

# Jefe
@onready var jefe_anim = $CosasJefe/Jefe
@onready var jefe_hp_bar = $CosasJefe/BarraHP

# Jugador (HUD)
@onready var player_hp_bar = $HUDJugador/Stats/ProgressBar
@onready var player_hp_label = $HUDJugador/Stats/Cantidad
@onready var danio_label = $HUDJugador/Stats/Daño
@onready var armadura_label = $HUDJugador/Stats/Armadura
@onready var btn_ataque = $HUDJugador/Botones/Ataque
@onready var btn_defender = $HUDJugador/Botones/Defender
@onready var btn_recuperar = $HUDJugador/Botones/Recuperar

# --- Estadísticas del Informe ---
var player_max_hp: int = 100
var player_hp: int = 100
var danio_base: int = 25
var armadura: float = 0.20 # 20% de mitigación
var boss_max_hp: int = 70
var boss_hp: int = 70

# --- Estados alterados del Jefe ---
var boss_cargando_ataque_pesado: bool = false
var ataque_corrompido: bool = false
var vida_corrompida: bool = false

# --- Temporizador ---
var tiempo_maximo: float = 15.0
var tiempo_restante: float = 0.0
var timer_activo: bool = false

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
	player_hp_bar.max_value = player_max_hp
	jefe_hp_bar.max_value = boss_max_hp
	_actualizar_hud()
	
	if jefe_anim is AnimatedSprite2D and jefe_anim.sprite_frames != null:
		jefe_anim.play("default")
	
	btn_ataque.pressed.connect(_on_btn_ataque_pressed)
	btn_defender.pressed.connect(_on_btn_defender_pressed)
	btn_recuperar.pressed.connect(_on_btn_recuperar_pressed)
	
	cambiar_estado(Estado.MENU)

func _process(delta: float) -> void:
	if timer_activo:
		tiempo_restante -= delta
		timer_bar.value = tiempo_restante
		timer_label.text = "%d S" % ceil(tiempo_restante)
		
		if tiempo_restante <= 0.0:
			timer_activo = false
			_on_tiempo_agotado()

# --- Máquina de Estados ---
func cambiar_estado(nuevo_estado: Estado) -> void:
	estado_actual = nuevo_estado
	timer_activo = false
	
	menu_panel.hide()
	ataque_panel.hide()
	defensa_panel.hide()
	barra_superior.hide()
	_set_borde_color(Color.WHITE)
	
	match estado_actual:
		Estado.MENU:
			menu_panel.show()
			_decidir_intencion_jefe()
			_habilitar_botones(true)
			_actualizar_hud()
			
		Estado.ACCION_COMBATE:
			ataque_panel.show()
			barra_superior.show()
			_habilitar_botones(false)
			
			match accion_actual:
				Accion.ATACAR:
					fase_label.text = "ATAQUE"
					_cargar_pregunta(banco_atacar.pick_random())
				Accion.DEFENDER:
					fase_label.text = "DEFENSA"
					_cargar_pregunta(banco_defender.pick_random())
				Accion.RECUPERAR:
					fase_label.text = "RECUPERAR"
					_cargar_pregunta(banco_recuperar.pick_random())
			
			_iniciar_timer(15.0)
			
		Estado.RESULTADO:
			menu_panel.show()
			_habilitar_botones(false)
			await get_tree().create_timer(2.5).timeout
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

# --- Cargar y Mostrar Pregunta Dinámica ---
func _cargar_pregunta(pregunta: Dictionary) -> void:
	pregunta_actual = pregunta
	pregunta_label.text = pregunta_actual["enunciado"]
	
	var botones = opciones_container.get_children()
	while botones.size() < 3:
		var nuevo_btn = Button.new()
		opciones_container.add_child(nuevo_btn)
		botones.append(nuevo_btn)
		
	for i in range(botones.size()):
		var btn = botones[i] as Button
		if i < pregunta_actual["opciones"].size():
			btn.show()
			btn.text = pregunta_actual["opciones"][i]
			btn.focus_mode = Control.FOCUS_NONE
			
			for con in btn.pressed.get_connections():
				btn.pressed.disconnect(con.callable)
				
			btn.pressed.connect(_on_opcion_seleccionada.bind(i))
		else:
			btn.hide()

# --- Resolución de Respuestas ---
func _on_opcion_seleccionada(indice: int) -> void:
	timer_activo = false
	var acierto = (indice == pregunta_actual["correcta"])
	
	match accion_actual:
		Accion.ATACAR:
			if acierto:
				# Mecánica de suerte del informe: bono por responder rápido (< 5 s)
				var danio_final = danio_base
				var tiempo_empleado = tiempo_maximo - tiempo_restante
				if tiempo_empleado <= 5.0:
					danio_final *= 2
					texto_superior.text = "* ¡GOLPE CRÍTICO RÁPIDO! (SUERTE DUPLICÓ EL DAÑO)"
				else:
					texto_superior.text = "* DESREFERENCIACIÓN CORRECTA: GOLPE EN LA MEMORIA."
				
				if ataque_corrompido:
					danio_final = 5 # Si atacó estando corrompido, hace daño mínimo
					texto_superior.text = "* ATACASTE CON DIRECCIÓN CORRUPTA: DAÑO REDUCIDO."
				
				daniar_jefe(danio_final)
				texto_inferior.text = "* VIDA_JEFE BAJÓ A %d." % boss_hp
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

# --- Acciones de Botones ---
func _on_btn_ataque_pressed() -> void:
	accion_actual = Accion.ATACAR
	cambiar_estado(Estado.ACCION_COMBATE)

func _on_btn_defender_pressed() -> void:
	accion_actual = Accion.DEFENDER
	cambiar_estado(Estado.ACCION_COMBATE)

func _on_btn_recuperar_pressed() -> void:
	accion_actual = Accion.RECUPERAR
	cambiar_estado(Estado.ACCION_COMBATE)

# --- Daño y Curación ---
func recibir_danio_jugador(cantidad: int, mensaje: String) -> void:
	# Aplicar absorción de armadura del informe
	var danio_mitigado = int(cantidad * (1.0 - armadura))
	player_hp = max(0, player_hp - danio_mitigado)
	_actualizar_hud()
	
	texto_superior.text = "* " + mensaje
	texto_inferior.text = "* RECIBISTE %d DE DAÑO. (HP: %d)" % [danio_mitigado, player_hp]
	_set_borde_color(Color("#ff3333"))
	cambiar_estado(Estado.RESULTADO)

func curar_jugador(cantidad: int) -> void:
	player_hp = min(player_max_hp, player_hp + cantidad)
	_actualizar_hud()

func daniar_jefe(cantidad: int) -> void:
	boss_hp = max(0, boss_hp - cantidad)
	var tween = create_tween()
	tween.tween_property(jefe_hp_bar, "value", boss_hp, 0.3)

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

# --- Temporizador y Visuales ---
func _iniciar_timer(duracion: float) -> void:
	tiempo_maximo = duracion
	tiempo_restante = duracion
	timer_bar.max_value = duracion
	timer_bar.value = duracion
	timer_label.text = "%d S" % ceil(duracion)
	timer_activo = true

func _set_borde_color(color: Color) -> void:
	var sb = caja_central.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		sb.border_color = color

func _habilitar_botones(habilitar: bool) -> void:
	btn_ataque.disabled = !habilitar
	btn_defender.disabled = !habilitar
	btn_recuperar.disabled = !habilitar
