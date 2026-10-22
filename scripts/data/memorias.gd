class_name Memorias
extends RefCounted

# Las 6 memorias perdidas del protagonista en el nivel 2 (texto del boceto "5 Memorias perdidas").
# Cada una es un cristal (memoria_perdida.gd) que se recoge con E; quedan en el Registro, pestaña Memorias.

const TOTAL := 6
const LISTA := [
	{"id": &"M1", "lugar": "Junto a la puerta de la biblioteca",
		"texto": "Recuerdo un salón lleno de casillas encendidas. Yo revisaba cada dirección antes de que existiera."},
	{"id": &"M2", "lugar": "En la boca de mina del suroeste",
		"texto": "Mis manos sostenían la Daga Puntero. No cortaba: señalaba dónde vivía cada cosa."},
	{"id": &"M3", "lugar": "Entre los hongos luminosos",
		"texto": "El Distrito era el corazón del mundo: cada oficio recibía una placa y trabajaba sobre el original, nunca sobre una copia."},
	{"id": &"M4", "lugar": "A la orilla de la Laguna de los Espejos",
		"texto": "En el agua veo mi reflejo… pero mi nombre está escrito en ceros: `0x00000000`."},
	{"id": &"M5", "lugar": "Junto a la casa derrumbada",
		"texto": "Alguien liberó memoria sin avisar a quienes guardaban sus placas. Las casas desaparecían, pero las placas seguían en los bolsillos."},
	{"id": &"M6", "lugar": "En el terreno del jefe (al vencerlo)",
		"texto": "El Archivista del distrito nunca soltó sus placas. Era el hermano de Rivera: por eso su dirección, `0x03F0`, todavía late aquí abajo."},
]


static func buscar(id: StringName) -> Dictionary:
	for m: Dictionary in LISTA:
		if m["id"] == id:
			return m
	return {}
