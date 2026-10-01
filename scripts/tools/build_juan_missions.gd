@tool
extends EditorScript

# Se ejecuta UNA vez desde el editor de scripts: Archivo > Ejecutar (Ctrl+Mayús+X).
# Crea res://data/missions/ej_n1_02.tres y ej_n1_05.tres con el contenido de tus bocetos de Juan.
# Después puedes editar todo desde el inspector.

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/missions")
	_save(_daga(), "res://data/missions/ej_n1_02.tres")
	_save(_cerradura(), "res://data/missions/ej_n1_05.tres")
	EditorInterface.get_resource_filesystem().scan()
	print("Listo: misiones de Juan creadas en res://data/missions/")


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("No se pudo guardar %s (error %d)" % [path, err])


func _cell(address: String, value: String, label: String, points_to: String = "", masked: bool = false) -> MemoryCellData:
	var c := MemoryCellData.new()
	c.address = address
	c.value = value
	c.label = label
	c.points_to = points_to
	c.masked = masked
	return c


func _opt(text: String, correct: bool, feedback: String = "", concept: String = "", hint: String = "") -> OptionData:
	var o := OptionData.new()
	o.text = text
	o.is_correct = correct
	o.wrong_feedback = feedback
	o.concept_on_error = concept
	o.hint = hint
	return o


func _reward(stat: RewardData.Stat, amount: float) -> RewardData:
	var r := RewardData.new()
	r.stat = stat
	r.amount = amount
	return r


# ---------- EJ-N1-02 · La Daga que forjó Juan (prueba en diálogo) ----------
func _daga() -> MissionData:
	var m := MissionData.new()
	m.id = &"EJ-N1-02"
	m.oa_code = "OA2.1"
	m.title = "La Daga que forjó Juan"
	m.objective = "→ Muéstrale la daga a Juan"
	m.cell_address = ""
	m.intro_dialogue.assign([
		"Mira la inscripción del mango: `int *daga;`. La hoja está hueca a propósito: no corta, sostiene.",
	])
	m.success_dialogue.assign([
		"Exacto. Déjame afilarla un poco… Así sostiene mejor.",
	])
	m.done_dialogue.assign([
		"La daga ya sostiene bien. ¡Gracias por tu ayuda!",
	])

	var e := ExerciseData.new()
	e.title = "PRUEBA DEL HERRERO"
	e.code = "int *daga;"
	e.question = "¿Qué es capaz de guardar `daga`?"
	e.memory_cells.assign([
		_cell("0x0004", "30", "balde"),
		_cell("0x0040", "?", "daga", "", true),
	])
	e.options.assign([
		_opt("La dirección de una variable de tipo `int`", true),
		_opt("Un número entero cualquiera", false,
			"Intentaste meter el agua en la ranura de la placa. La daga la rechaza.",
			"Un puntero no guarda números cualquiera: guarda direcciones.",
			"La ranura de la hoja tiene el tamaño exacto de una placa del pozo."),
		_opt("El valor de un `int` junto con su nombre", false,
			"Querías cargar el balde entero, con su agua y su nombre. En la ranura solo cabe una placa.",
			"Un puntero guarda solo la dirección, no el contenido ni el nombre de la variable.",
			"Una placa solo dice dónde está el balde; no lleva el balde adentro."),
	])
	e.conceptual_hint = "Todo tiene contenido (el 30) y lugar (su placa `0x0004`). La daga guarda lugares."
	e.example_code = "int trigo = 5;\nint *p = &trigo;"
	e.example_cells.assign([
		_cell("0x0010", "5", "trigo"),
		_cell("0x0014", "0x0010", "p", "0x0010"),
	])
	e.example_text = "`p` no guarda un 5: guarda la placa `0x0010`, el lugar donde vive el 5."
	e.example_followup = "Mismo concepto, otra variable. Vuelve a tu daga: `int *daga;` ¿qué puede guardar?"
	e.success_title = "¡PUNTERO RECONOCIDO!"
	e.success_text = "La daga sostiene placas, no contenidos."
	e.concept_text = "`int *daga` guarda la dirección de un `int`."
	e.reward = _reward(RewardData.Stat.DAMAGE, 2)
	m.exercise = e
	return m


# ---------- EJ-N1-05 · La Puerta de la Herrería (casilla 0x0020) ----------
func _cerradura() -> MissionData:
	var m := MissionData.new()
	m.id = &"EJ-N1-05"
	m.oa_code = "OA2.4"
	m.title = "La Puerta de la Herrería"
	m.objective = "→ Abre la casilla `0x0020`"
	m.requires_mission = &"EJ-N1-02"
	m.cell_address = "0x0020"
	m.intro_dialogue.assign([
		"Me quedé fuera de mi propio taller. El candado marca {addr:0x0020} y no cede.",
	])
	m.reminder_dialogue.assign([
		"¿Pudiste abrir la casilla `0x0020`? El candado sigue sin ceder.",
	])
	m.success_dialogue.assign([
		"¡Clic! El candado ahora marca {addr:0x0020}. ¡Estoy dentro!",
	])
	m.done_dialogue.assign([
		"Gracias a ti volví a mi taller. ¡Sigue forjando tu daga!",
	])
	m.reveals.assign([
		_cell("0x0020", "0", "cerradura de Juan (antes 1)"),
	])

	var e := ExerciseData.new()
	e.title = "CASILLA DE MEMORIA"
	e.code = "int cerradura = 1;\nint *ptr = &cerradura;"
	e.question = "¿Cuál línea deja `cerradura` en 0?"
	e.memory_cells.assign([
		_cell("0x0020", "1", "cerradura"),
		_cell("0x0024", "0x0020", "ptr", "0x0020"),
	])
	e.options.assign([
		_opt("`ptr = 0;`", false,
			"Moviste la daga a otra dirección en vez de golpear la que apuntabas. La cerradura sigue en 1.",
			"Asignar a `ptr` cambia adónde apunta, no el valor apuntado.",
			"El candado ni se mueve: tu golpe cayó en otra parte."),
		_opt("`*ptr = 0;`", true),
		_opt("`&ptr = 0;`", false,
			"Intentaste cambiar la placa del propio puntero. Las placas no se reescriben a golpes.",
			"`&ptr` es la dirección de `ptr`: no es algo a lo que se pueda asignar.",
			"Una placa dice dónde vive algo; no se puede cambiar."),
	])
	e.conceptual_hint = "`*` viaja a la dirección guardada y trabaja sobre lo que hay allí."
	e.example_code = "int vida = 10;\nint *p = &vida;\n*p = 0;"
	e.example_cells.assign([
		_cell("0x0010", "10", "vida"),
		_cell("0x0014", "0x0010", "p", "0x0010"),
	])
	e.example_text = "`*p = 0` viaja a la placa `0x0010` y escribe 0 en `vida`."
	e.example_followup = "Mismo concepto, otra variable. Vuelve a tu candado: ¿qué línea escribe en `cerradura`?"
	e.success_title = "¡ESCRITURA POR REFERENCIA!"
	e.success_text = "El candado cede. Juan entra a su taller y te forja una mejora de daño."
	e.concept_text = "`*ptr = 0` escribe en la variable original, no en una copia."
	e.reward = _reward(RewardData.Stat.DAMAGE, 5)
	m.exercise = e
	return m
