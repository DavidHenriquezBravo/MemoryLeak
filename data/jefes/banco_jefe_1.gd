extends RefCounted
# Banco del JEFE NIVEL 1 — The Memory Leak (Anexo A del informe).
# 20 ítems: 8 ATACAR, 6 DEFENDER, 6 RECUPERAR.
#
# Cómo escribir un ítem:
#   - Lo que va entre `comillas invertidas` se muestra como código (monoespaciada).
#   - "correcta" es la posición (0, 1 o 2) dentro de "opciones" tal como están aquí;
#     el juego baraja las opciones cada vez que muestra la pregunta.
#   - "error" sale en la caja de texto si el jugador falla. Va en Upheaval, así que
#     no usar "&" (lo dibuja como "€").

const PROVOCACIONES := {
	"atacar": "REASIGNA LA MEMORIA ANTES DE QUE EXPIRE EL CICLO. SI ES QUE SABES CÓMO.",
	"defender": "TOMA ESTA DAGA. NO TE DIRÉ A DÓNDE APUNTA.",
	"recuperar": "NI SIQUIERA SABES CUÁNTO TE QUEDA. YO SÍ.",
}

const PREGUNTAS := [
	# --- ATACAR: escribir a través del puntero (OA2.4) ---
	{
		"id": "B1-ATK-01", "accion": "atacar",
		"situacion": "`int vida_pueblo = 50; int *ptr = &vida_pueblo;`",
		"pregunta": "¿Cómo lo subes a 100?",
		"opciones": ["`ptr = 100;`", "`*ptr = 100;`", "`&ptr = 100;`"], "correcta": 1,
		"error": "MOVISTE EL PUNTERO EN VEZ DE CAMBIAR EL VALOR.",
	},
	{
		"id": "B1-ATK-02", "accion": "atacar",
		"situacion": "`int cerradura = 1; int *p = &cerradura;`",
		"pregunta": "¿Cómo la dejas en 0?",
		"opciones": ["`p = 0;`", "`&p = 0;`", "`*p = 0;`"], "correcta": 2,
		"error": "NO DESREFERENCIASTE LA CERRADURA: SIGUE EN 1.",
	},
	{
		"id": "B1-ATK-03", "accion": "atacar",
		"situacion": "`int mana = 10; int *p = &mana;`",
		"pregunta": "¿Cómo le sumas 5 al original?",
		"opciones": ["`*p = *p + 5;`", "`p = p + 5;`", "`*p = p + 5;`"], "correcta": 0,
		"error": "LE SUMASTE A LA DIRECCIÓN EN VEZ DE AL CONTENIDO.",
	},
	{
		"id": "B1-ATK-04", "accion": "atacar",
		"situacion": "`int vida = 30; int *p = &vida;`",
		"pregunta": "¿Cuál línea NO modifica `vida`?",
		"opciones": ["`*p = 25;`", "`p = 25;`", "`*p = *p + 25;`"], "correcta": 1,
		"error": "ESA LÍNEA SÍ ESCRIBE EN VIDA. LA QUE NO LA TOCA ES LA QUE MUEVE EL PUNTERO.",
	},
	{
		"id": "B1-ATK-05", "accion": "atacar",
		"situacion": "`int muro = 8; int *p = &muro;`",
		"pregunta": "¿Cómo lo dejas en 0?",
		"opciones": ["`p = 0;`", "`&p = 0;`", "`*p = 0;`"], "correcta": 2,
		"error": "EL MURO SIGUE EN PIE: HAY QUE ESCRIBIR A TRAVÉS DEL PUNTERO.",
	},
	{
		"id": "B1-ATK-06", "accion": "atacar",
		"situacion": "`int vida = 40; int *p = &vida; *p = *p - 10;`",
		"pregunta": "¿Qué quedó modificado?",
		"opciones": ["`vida`, que ahora vale 30", "El puntero `p`", "Nada"], "correcta": 0,
		"error": "EL ASTERISCO ESCRIBE EN LA VARIABLE APUNTADA: VIDA BAJÓ A 30.",
	},
	{
		"id": "B1-ATK-07", "accion": "atacar",
		"situacion": "`int hp = 60; int *p = &hp;`",
		"pregunta": "¿Cómo duplicas `hp`?",
		"opciones": ["`p = p * 2;`", "`*p = *p * 2;`", "`*p = p * 2;`"], "correcta": 1,
		"error": "MULTIPLICASTE LA DIRECCIÓN EN VEZ DEL VALOR.",
	},
	{
		"id": "B1-ATK-08", "accion": "atacar",
		"situacion": "`int bandera = 0; int *p = &bandera;`",
		"pregunta": "¿Cuál línea la deja en 1?",
		"opciones": ["`p = 1;`", "`&p = 1;`", "`*p = 1;`"], "correcta": 2,
		"error": "LA BANDERA SIGUE EN 0: NO ENTRASTE A LA CASILLA.",
	},

	# --- DEFENDER: punteros sin destino (OA2.5) ---
	{
		"id": "B1-DEF-01", "accion": "defender",
		"situacion": "`int *p = NULL;`",
		"pregunta": "¿Cuál línea provoca el colapso?",
		"opciones": ["`*p = 0;`", "`p = &hp;`", "`p = NULL;`"], "correcta": 0,
		"error": "LO QUE ROMPE EL PROGRAMA ES DESREFERENCIAR NULL.",
	},
	{
		"id": "B1-DEF-02", "accion": "defender",
		"situacion": "Un puntero vale `NULL`.",
		"pregunta": "¿Qué significa?",
		"opciones": ["Apunta a la dirección 0, válida", "No apunta a nada válido", "Guarda un espacio en blanco"], "correcta": 1,
		"error": "CONFUNDISTE NULL CON UNA DIRECCIÓN VÁLIDA.",
	},
	{
		"id": "B1-DEF-03", "accion": "defender",
		"situacion": "`int *p;` sin inicializar",
		"pregunta": "¿Qué contiene `p`?",
		"opciones": ["Siempre `NULL`", "El valor 0", "Una dirección indeterminada"], "correcta": 2,
		"error": "UN PUNTERO SIN INICIALIZAR GUARDA BASURA, NO NULL.",
	},
	{
		"id": "B1-DEF-04", "accion": "defender",
		"situacion": "Vas a leer `*p` y no sabes si es válido.",
		"pregunta": "¿Cómo te proteges?",
		"opciones": ["`if (p != NULL)`", "`if (*p != NULL)`", "`if (&p != NULL)`"], "correcta": 0,
		"error": "SE COMPRUEBA EL PUNTERO ANTES DE ENTRAR, NO SU CONTENIDO.",
	},
	{
		"id": "B1-DEF-05", "accion": "defender",
		"situacion": "`int *p = &x;` y luego `p = NULL;`",
		"pregunta": "¿Es seguro leer `*p`?",
		"opciones": ["Sí, conserva el último valor", "No, ya no apunta a nada válido", "Solo si `x` sigue viva"], "correcta": 1,
		"error": "AL VALER NULL YA NO APUNTA A X: LEERLO ROMPE EL PROGRAMA.",
	},
	{
		"id": "B1-DEF-06", "accion": "defender",
		"situacion": "Vas a declarar un puntero que todavía no usarás.",
		"pregunta": "¿Cuál inicialización es segura?",
		"opciones": ["`int *p;`", "`int *p = 0.0;`", "`int *p = NULL;`"], "correcta": 2,
		"error": "UN PUNTERO QUE AÚN NO USAS SE INICIALIZA EN NULL.",
	},

	# --- RECUPERAR: leer el valor real (OA2.3) ---
	{
		"id": "B1-REC-01", "accion": "recuperar",
		"situacion": "`int hp = 40; int *d = &hp;`",
		"pregunta": "¿Qué expresión lee el HP real?",
		"opciones": ["`d`", "`*d`", "`&d`"], "correcta": 1,
		"error": "LEÍSTE LA PLACA, NO EL BALDE: PARA ENTRAR SE USA EL ASTERISCO.",
	},
	{
		"id": "B1-REC-02", "accion": "recuperar",
		"situacion": "`int oro = 50; int *p = &oro;`",
		"pregunta": "¿Qué imprime `printf(\"%d\", *p);`?",
		"opciones": ["La dirección", "Error", "`50`"], "correcta": 2,
		"error": "EL ASTERISCO ENTRA A LA CASILLA: SE IMPRIME EL VALOR.",
	},
	{
		"id": "B1-REC-03", "accion": "recuperar",
		"situacion": "`int agua = 7; int *p = &agua;`",
		"pregunta": "¿Qué expresión vale 7?",
		"opciones": ["`*p`", "`p`", "`&p`"], "correcta": 0,
		"error": "SIN ASTERISCO SOLO TIENES LA DIRECCIÓN, NO EL 7.",
	},
	{
		"id": "B1-REC-04", "accion": "recuperar",
		"situacion": "`int x = 3; int *p = &x; x = 9;`",
		"pregunta": "¿Cuánto vale `*p` ahora?",
		"opciones": ["`3`", "`9`", "La dirección de `x`"], "correcta": 1,
		"error": "EL PUNTERO NO GUARDA UNA COPIA: MIRA LA CASILLA, QUE AHORA TIENE 9.",
	},
	{
		"id": "B1-REC-05", "accion": "recuperar",
		"situacion": "`int arm = 20; int *p = &arm;`",
		"pregunta": "¿Qué devuelve `*p`?",
		"opciones": ["La dirección", "Error", "`20`"], "correcta": 2,
		"error": "DESREFERENCIAR DEVUELVE EL CONTENIDO: 20.",
	},
	{
		"id": "B1-REC-06", "accion": "recuperar",
		"situacion": "Tu suerte quedó en `0x00B4`: `int *p_suerte = 0x00B4;`",
		"pregunta": "¿Qué expresión devuelve el valor?",
		"opciones": ["`*p_suerte`", "`p_suerte`", "`&p_suerte`"], "correcta": 0,
		"error": "ESO ES LA DIRECCIÓN DE TU SUERTE, NO SU VALOR.",
	},
]
