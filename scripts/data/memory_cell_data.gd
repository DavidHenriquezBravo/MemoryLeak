class_name MemoryCellData
extends Resource

# Una casilla del diagrama de memoria: [0x0004 | 30 | balde]

@export var address: String = "0x0000"
@export var value: String = ""
@export var label: String = ""
@export var masked: bool = false          # true = se muestra "?" en vez del valor
@export var points_to: String = ""        # si es un puntero: dirección a la que apunta (dibuja la flecha)
