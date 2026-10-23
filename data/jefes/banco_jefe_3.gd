extends RefCounted
# Banco del JEFE FINAL — The Segmentation Fault (Anexo del informe, temporizador 10 s).
# 20 ítems: 8 ATACAR, 6 DEFENDER, 6 RECUPERAR.
#
# Cómo escribir un ítem:
#   - Lo que va entre `comillas invertidas` se muestra como código (monoespaciada).
#   - "correcta" es la posición (0, 1 o 2) dentro de "opciones" tal como están aquí;
#     el juego baraja las opciones cada vez que muestra la pregunta.
#   - "error" sale en la caja de texto si el jugador falla. Va en Upheaval, así que
#     no usar "&" (lo dibuja como "€").

const PROVOCACIONES := {
	"atacar": "MUEVE LA DAGA SI PUEDES. YO DECIDO A QUIÉN GOLPEAS.",
	"defender": "TODO LO QUE RESERVAS Y SUELTAS ME ALIMENTA.",
	"recuperar": "TIENES LA DAGA DOBLE Y NO SABES QUÉ SOSTIENE.",
}

const PREGUNTAS := [
	# --- ATACAR: doble indirección y aritmética, escritura (OA3.4) ---
	{
		"id": "B3-ATK-01", "accion": "atacar",
		"situacion": "Una función debe hacer que tu puntero apunte a otra variable.",
		"pregunta": "¿Qué parámetro recibe?",
		"opciones": ["`int **p`", "`int *p`", "`int p`"], "correcta": 0,
		"error": "PARA MOVER UNA DAGA HAY QUE RECIBIR DÓNDE ESTÁ LA DAGA: UN PUNTERO A PUNTERO.",
	},
	{
		"id": "B3-ATK-02", "accion": "atacar",
		"situacion": "`int a=1, b=2; int *p=&a; int **pp=&p; *pp = &b;`",
		"pregunta": "¿Qué hizo `*pp = &b`?",
		"opciones": ["Cambió el valor de `a`", "Movió `p` para que apunte a `b`", "Copió `b` en `a`"], "correcta": 1,
		"error": "ESCRIBIR EN *PP CAMBIA LA DAGA, NO LO QUE ELLA SOSTIENE.",
	},
	{
		"id": "B3-ATK-03", "accion": "atacar",
		"situacion": "`int arr[3] = {1,2,3}; int *p = arr; *(p + 1) = 99;`",
		"pregunta": "¿Qué elemento cambió?",
		"opciones": ["El primero", "El tercero", "El segundo"], "correcta": 2,
		"error": "P + 1 AVANZA UNA CASILLA DESDE EL INICIO: ES EL SEGUNDO.",
	},
	{
		"id": "B3-ATK-04", "accion": "atacar",
		"situacion": "`int v = 5; int *p = &v; int **pp = &p; **pp = 7;`",
		"pregunta": "¿Qué quedó modificado?",
		"opciones": ["`v`", "`p`", "`pp`"], "correcta": 0,
		"error": "DOS SALTOS DESDE PP LLEGAN HASTA V: ESE ES EL QUE CAMBIA.",
	},
	{
		"id": "B3-ATK-05", "accion": "atacar",
		"situacion": "`int arr[4] = {1,2,3,4}; int *p = arr; *(p + 3) = 0;`",
		"pregunta": "¿Qué elemento cambió?",
		"opciones": ["El tercero", "El cuarto", "Ninguno"], "correcta": 1,
		"error": "SE CUENTA DESDE CERO: P + 3 ES LA CUARTA CASILLA.",
	},
	{
		"id": "B3-ATK-06", "accion": "atacar",
		"situacion": "`int *p = &a; int **pp = &p; *pp = &z;`",
		"pregunta": "¿Qué quedó modificado?",
		"opciones": ["El valor de `a`", "El puntero `p`, que ahora apunta a `z`", "El valor de `z`"], "correcta": 1,
		"error": "UN SOLO SALTO DESDE PP CAE EN P: LA DAGA AHORA APUNTA A Z.",
	},
	{
		"id": "B3-ATK-07", "accion": "atacar",
		"situacion": "`int v = 4; int *p = &v; int **pp = &p; **pp = **pp + 1;`",
		"pregunta": "¿Cuánto vale `v`?",
		"opciones": ["`4`", "Indefinido", "`5`"], "correcta": 2,
		"error": "**PP ES V: LEE 4, SUMA 1 Y ESCRIBE 5 EN LA MISMA CASILLA.",
	},
	{
		"id": "B3-ATK-08", "accion": "atacar",
		"situacion": "Una función debe reservar memoria y dejarla en el puntero del llamador.",
		"pregunta": "¿Cuál firma sirve?",
		"opciones": ["`void crear(int **p)`", "`void crear(int *p)`", "`void crear(int p)`"], "correcta": 0,
		"error": "PARA DEJAR UNA DIRECCIÓN NUEVA EN EL PUNTERO DE AFUERA HAY QUE RECIBIR SU DIRECCIÓN.",
	},

	# --- DEFENDER: fugas y liberación (OA3.5) ---
	{
		"id": "B3-DEF-01", "accion": "defender",
		"situacion": "`int *p = malloc(sizeof(int)); *p = 42; p = NULL;`",
		"pregunta": "¿Qué ocurrió con el bloque?",
		"opciones": ["Se liberó solo", "Quedó inalcanzable: fuga de memoria", "Se volvió `NULL`"], "correcta": 1,
		"error": "SOLTAR LA PLACA NO DEVUELVE EL BLOQUE: QUEDÓ RESERVADO Y PERDIDO.",
	},
	{
		"id": "B3-DEF-02", "accion": "defender",
		"situacion": "Quieres liberar y no dejar un rastro peligroso.",
		"pregunta": "¿Cuál secuencia es correcta?",
		"opciones": ["`p = NULL; free(p);`", "Solo `p = NULL;`", "`free(p); p = NULL;`"], "correcta": 2,
		"error": "PRIMERO SE DEVUELVE EL BLOQUE, DESPUÉS SE SUELTA LA PLACA. AL REVÉS, SE PIERDE.",
	},
	{
		"id": "B3-DEF-03", "accion": "defender",
		"situacion": "Se llama `free(p)` dos veces sobre el mismo puntero.",
		"pregunta": "¿Qué ocurre?",
		"opciones": ["Comportamiento indefinido", "Se libera el doble de memoria", "No pasa nada"], "correcta": 0,
		"error": "EL BLOQUE YA NO ERA TUYO: LIBERARLO OTRA VEZ ES COMPORTAMIENTO INDEFINIDO.",
	},
	{
		"id": "B3-DEF-04", "accion": "defender",
		"situacion": "Buscas lo que provoca un fallo de segmentación seguro.",
		"pregunta": "¿Cuál acción es?",
		"opciones": ["Asignar `NULL` a un puntero", "Desreferenciar `NULL`", "Tomar `&` de una variable local"], "correcta": 1,
		"error": "ASIGNAR NULL ES SEGURO; LEER O ESCRIBIR A TRAVÉS DE NULL ES LO QUE ME DESPIERTA.",
	},
	{
		"id": "B3-DEF-05", "accion": "defender",
		"situacion": "`int arr[5];` y se accede a `arr[5]`",
		"pregunta": "¿Qué ocurre?",
		"opciones": ["Devuelve 0", "Acceso fuera de rango: comportamiento indefinido", "Error de compilación"], "correcta": 1,
		"error": "LAS CASILLAS VAN DE 0 A 4: ARR[5] YA ES MEMORIA AJENA.",
	},
	{
		"id": "B3-DEF-06", "accion": "defender",
		"situacion": "`int *p = malloc(sizeof(int));`",
		"pregunta": "¿Qué conviene hacer antes de usar `*p`?",
		"opciones": ["Nada, `malloc` nunca falla", "Llamar `free(p)` primero", "Comprobar `if (p != NULL)`"], "correcta": 2,
		"error": "MALLOC PUEDE DEVOLVER NULL: HAY QUE REVISARLO ANTES DE ENTRAR.",
	},

	# --- RECUPERAR: doble indirección y arreglos, lectura (OA3.4) ---
	{
		"id": "B3-REC-01", "accion": "recuperar",
		"situacion": "`int *p = &v; int **pp = &p;`",
		"pregunta": "¿Qué es `*pp`?",
		"opciones": ["El puntero `p`", "El valor de `v`", "La dirección de `pp`"], "correcta": 0,
		"error": "UN SOLO SALTO DESDE PP TE DEJA EN LA DAGA P, NO EN LO QUE SOSTIENE.",
	},
	{
		"id": "B3-REC-02", "accion": "recuperar",
		"situacion": "`int vida = 100; int *p = &vida; int **pp = &p;`",
		"pregunta": "¿Qué imprime `**pp`?",
		"opciones": ["La dirección de `p`", "`100`", "La dirección de `vida`"], "correcta": 1,
		"error": "DOS SALTOS: DEL CAJÓN A LA DAGA Y DE LA DAGA A LA VIDA. SON 100.",
	},
	{
		"id": "B3-REC-03", "accion": "recuperar",
		"situacion": "`int armas[4] = {10,20,30,40}; int *p = armas;`",
		"pregunta": "¿Qué vale `*(p + 2)`?",
		"opciones": ["`20`", "La dirección del tercero", "`30`"], "correcta": 2,
		"error": "DESDE EL INICIO, DOS CASILLAS, Y EL ASTERISCO ENTRA: LA TERCERA ARMA VALE 30.",
	},
	{
		"id": "B3-REC-04", "accion": "recuperar",
		"situacion": "`char *nombres[3] = {\"Andres\",\"Juan\",\"Rivera\"};`",
		"pregunta": "¿Qué es `nombres[1]`?",
		"opciones": ["Un puntero al inicio de \"Juan\"", "El carácter 'J'", "Una copia de \"Juan\""], "correcta": 0,
		"error": "CADA ESTANTERÍA DEL CENSO GUARDA UNA PLACA HACIA UN NOMBRE, NO UNA LETRA.",
	},
	{
		"id": "B3-REC-05", "accion": "recuperar",
		"situacion": "`char *nombres[3] = {\"Andres\",\"Juan\",\"Rivera\"}; char *n = nombres[2];`",
		"pregunta": "¿Qué imprime `printf(\"%s\", n);`?",
		"opciones": ["Andres", "Rivera", "Una dirección"], "correcta": 1,
		"error": "NOMBRES[2] ES LA TERCERA PLACA: LLEVA A RIVERA, Y %S IMPRIME EL TEXTO.",
	},
	{
		"id": "B3-REC-06", "accion": "recuperar",
		"situacion": "`int arr[4] = {5,6,7,8}; int *p = arr + 1;`",
		"pregunta": "¿Cuánto vale `*p`?",
		"opciones": ["`5`", "La dirección del segundo", "`6`"], "correcta": 2,
		"error": "ARR + 1 YA APUNTA A LA SEGUNDA CASILLA, Y *P LA ABRE: 6.",
	},
]
