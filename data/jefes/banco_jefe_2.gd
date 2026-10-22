extends RefCounted
# Banco del JEFE NIVEL 2 — The Dangling Pointer (Anexo del informe, temporizador 12 s).
# 20 ítems: 8 ATACAR, 6 DEFENDER, 6 RECUPERAR.
#
# Cómo escribir un ítem:
#   - Lo que va entre `comillas invertidas` se muestra como código (monoespaciada).
#   - "correcta" es la posición (0, 1 o 2) dentro de "opciones" tal como están aquí;
#     el juego baraja las opciones cada vez que muestra la pregunta.
#   - "error" sale en la caja de texto si el jugador falla. Va en Upheaval, así que
#     no usar "&" (lo dibuja como "€").

const PROVOCACIONES := {
	"atacar": "ESCRIBE SOBRE UNA COPIA Y MÍRALA EVAPORARSE.",
	"defender": "AUNQUE ME SUELTES, DEJARÉ UNA PLACA EN TU MANO.",
	"recuperar": "TE DOY LA DIRECCIÓN DE LA CASA DE TU INFANCIA. ENTRA.",
}

const PREGUNTAS := [
	# --- ATACAR: paso por referencia (OA3.1, OA3.2) ---
	{
		"id": "B2-ATK-01", "accion": "atacar",
		"situacion": "`void subir(int *v) { ____ }` debe sumar 1 al original.",
		"pregunta": "¿Qué línea va adentro?",
		"opciones": ["`*v = *v + 1;`", "`v = v + 1;`", "`&v = *v + 1;`"], "correcta": 0,
		"error": "MOVISTE LA PLACA EN VEZ DE SUBIR EL VALOR: EL ORIGINAL NI SE ENTERÓ.",
	},
	{
		"id": "B2-ATK-02", "accion": "atacar",
		"situacion": "Quieres una función que modifique el original.",
		"pregunta": "¿Qué firma corresponde?",
		"opciones": ["`void f(int x)`", "`void f(int *x)`", "`void f(&int x)`"], "correcta": 1,
		"error": "ESA FUNCIÓN RECIBE UNA COPIA (O NI SIQUIERA COMPILA). NECESITA UN PUNTERO.",
	},
	{
		"id": "B2-ATK-03", "accion": "atacar",
		"situacion": "`void f(int *x)` y tienes `int a;`",
		"pregunta": "¿Cómo la llamas?",
		"opciones": ["`f(a);`", "`f(*a);`", "`f(&a);`"], "correcta": 2,
		"error": "LA FUNCIÓN ESPERA UNA DIRECCIÓN: HAY QUE ENTREGARLE LA PLACA DE A.",
	},
	{
		"id": "B2-ATK-04", "accion": "atacar",
		"situacion": "`void sumar(int n) { n = n + 10; }` con `sumar(total);`",
		"pregunta": "¿Por qué `total` no cambia?",
		"opciones": ["Recibe una copia local", "Falta `return`", "El tipo es incorrecto"], "correcta": 0,
		"error": "EL PROBLEMA ES EL PASO POR VALOR: N ES UNA COPIA QUE MUERE AL TERMINAR.",
	},
	{
		"id": "B2-ATK-05", "accion": "atacar",
		"situacion": "`void restar(int *v) { *v = *v - 3; }` con `int hp = 10; restar(&hp);`",
		"pregunta": "¿Cuánto vale `hp`?",
		"opciones": ["`10`", "`7`", "Indefinido"], "correcta": 1,
		"error": "LA FUNCIÓN ESCRIBIÓ EN LA DIRECCIÓN DE HP: BAJÓ DE 10 A 7.",
	},
	{
		"id": "B2-ATK-06", "accion": "atacar",
		"situacion": "`void poner(int *v, int n) { ____ }`",
		"pregunta": "¿Qué línea asigna `n` al original?",
		"opciones": ["`v = n;`", "`&v = n;`", "`*v = n;`"], "correcta": 2,
		"error": "CAMBIASTE LA PLACA, NO LO QUE HAY DETRÁS DE ELLA.",
	},
	{
		"id": "B2-ATK-07", "accion": "atacar",
		"situacion": "`void doblar(int *v)` y tienes `int oro;`",
		"pregunta": "¿Cuál llamada modifica `oro`?",
		"opciones": ["`doblar(&oro);`", "`doblar(oro);`", "`doblar(*oro);`"], "correcta": 0,
		"error": "LE DISTE EL VALOR DEL ORO, NO SU DIRECCIÓN. EL COFRE SIGUE IGUAL.",
	},
	{
		"id": "B2-ATK-08", "accion": "atacar",
		"situacion": "`void limpiar(int *v) { *v = 0; }` con `limpiar(&danio);`",
		"pregunta": "¿Qué ocurre?",
		"opciones": ["Solo la copia queda en 0", "`danio` queda en 0", "Error de compilación"], "correcta": 1,
		"error": "NO HAY COPIA: LA FUNCIÓN RECIBIÓ LA PLACA Y DEJÓ DANIO EN 0.",
	},

	# --- DEFENDER: casos límite, punteros colgantes (OA2.5, OA3.5) ---
	{
		"id": "B2-DEF-01", "accion": "defender",
		"situacion": "Una función retorna la dirección de una variable local.",
		"pregunta": "¿Qué recibe quien la llama?",
		"opciones": ["Una copia segura", "`NULL`", "Un puntero colgante"], "correcta": 2,
		"error": "LA VARIABLE MURIÓ CON LA FUNCIÓN: TE QUEDASTE CON UNA PLACA SIN CASA.",
	},
	{
		"id": "B2-DEF-02", "accion": "defender",
		"situacion": "`free(p);` y después se usa `*p`",
		"pregunta": "¿Qué ocurre?",
		"opciones": ["Comportamiento indefinido", "Se lee el último valor", "Devuelve `NULL`"], "correcta": 0,
		"error": "ESA MEMORIA YA NO ES TUYA: LEERLA ES COMPORTAMIENTO INDEFINIDO.",
	},
	{
		"id": "B2-DEF-03", "accion": "defender",
		"situacion": "Acabas de llamar `free(p);`",
		"pregunta": "¿Cómo evitas dejar un colgante?",
		"opciones": ["`p = 0.0;`", "`p = NULL;` después", "No hace falta nada"], "correcta": 1,
		"error": "LA PLACA SIGUE APUNTANDO AL BLOQUE LIBERADO. HAY QUE DEJARLA EN NULL.",
	},
	{
		"id": "B2-DEF-04", "accion": "defender",
		"situacion": "Tres punteros: uno a variable viva, uno liberado y uno `NULL`.",
		"pregunta": "¿Cuál es seguro de desreferenciar?",
		"opciones": ["El liberado", "El `NULL`", "El de la variable viva"], "correcta": 2,
		"error": "SOLO LA PLACA DE UNA VARIABLE VIVA LLEVA A UNA CASA QUE EXISTE.",
	},
	{
		"id": "B2-DEF-05", "accion": "defender",
		"situacion": "Recibes un puntero a una variable de una función que ya retornó.",
		"pregunta": "¿Puedes usarlo?",
		"opciones": ["No, es un puntero colgante", "Sí, el valor persiste", "Solo para leer"], "correcta": 0,
		"error": "LA FUNCIÓN YA RETORNÓ: ESA DIRECCIÓN QUEDÓ MUERTA, NI PARA LEER.",
	},
	{
		"id": "B2-DEF-06", "accion": "defender",
		"situacion": "Se ejecuta `free(NULL);`",
		"pregunta": "¿Qué ocurre?",
		"opciones": ["Provoca un fallo", "No hace nada, es seguro", "Libera toda la memoria"], "correcta": 1,
		"error": "LIBERAR NULL ES SEGURO: NO HAY NADA QUE SOLTAR.",
	},

	# --- RECUPERAR: indirección y aliasing (OA2.3, OA3.3) ---
	{
		"id": "B2-REC-01", "accion": "recuperar",
		"situacion": "`int *p = &x;` y `x` era local a una función que terminó.",
		"pregunta": "¿Qué ocurre con `p`?",
		"opciones": ["Apunta a memoria ya no válida", "Pasa a `NULL` solo", "Conserva una copia segura"], "correcta": 0,
		"error": "NADIE LO PASÓ A NULL: P SIGUE APUNTANDO A UNA CASA DERRUMBADA.",
	},
	{
		"id": "B2-REC-02", "accion": "recuperar",
		"situacion": "`void ver(int *v) { printf(\"%d\", *v); }` con `int x = 8; ver(&x);`",
		"pregunta": "¿Qué imprime?",
		"opciones": ["La dirección de `x`", "`8`", "Error"], "correcta": 1,
		"error": "LA FUNCIÓN DESREFERENCIA LA PLACA: IMPRIME EL 8 QUE GUARDA X.",
	},
	{
		"id": "B2-REC-03", "accion": "recuperar",
		"situacion": "`int m = 4; int *p = &m, *q = &m; *p = 20;`",
		"pregunta": "¿Cuánto vale `*q`?",
		"opciones": ["`4`", "Indefinido", "`20`"], "correcta": 2,
		"error": "P Y Q SON DOS PLACAS DE LA MISMA CASA: SI UNA ESCRIBE 20, LA OTRA LO VE.",
	},
	{
		"id": "B2-REC-04", "accion": "recuperar",
		"situacion": "`int a = 5, b = 5; int *p = &a, *q = &b;`",
		"pregunta": "¿Qué vale `p == q`?",
		"opciones": ["`0`", "`1`", "Error"], "correcta": 0,
		"error": "GUARDAN EL MISMO NÚMERO, PERO SON CASAS DISTINTAS: LAS PLACAS NO COINCIDEN.",
	},
	{
		"id": "B2-REC-05", "accion": "recuperar",
		"situacion": "`int arm = 20; int *p = &arm;`",
		"pregunta": "¿Qué imprime `printf(\"%d\", *p);`?",
		"opciones": ["La dirección", "`20`", "Error"], "correcta": 1,
		"error": "EL ASTERISCO ABRE LA CASA: SALE EL 20 DE LA ARMADURA.",
	},
	{
		"id": "B2-REC-06", "accion": "recuperar",
		"situacion": "`int *p = &v; int **pp = &p;`",
		"pregunta": "¿Cómo lees el valor de `v` desde `pp`?",
		"opciones": ["`*pp`", "`&pp`", "`**pp`"], "correcta": 2,
		"error": "UN SOLO SALTO TE DEJA EN LA PLACA DE V. HACEN FALTA DOS.",
	},
]
