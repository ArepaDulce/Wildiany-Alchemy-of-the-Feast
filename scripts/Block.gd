class_name Block
extends Node2D
## Bloque de agua (o roca) de una botella.
##
## Es un nodo 2D muy simple: no contiene lógica de juego, solo guarda su
## identidad (color_id / is_rock) y sabe pintarse. La posición la controla
## el Tube al que pertenece.

## Número total de colores jugables. Los ids válidos son 0..7.
const MAX_COLORS := 8

## Paleta de los 8 tipos de botella del diseño del juego.
## El índice del array es el color_id del bloque.
const COLOR_PALETTE: Array[Color] = [
	Color(0.85, 0.18, 0.22), # 0 - Guerrera (rojo)
	Color(0.20, 0.45, 0.90), # 1 - Guardiana (azul)
	Color(0.28, 0.72, 0.34), # 2 - Curativa (verde)
	Color(0.95, 0.80, 0.20), # 3 - Energética (amarillo)
	Color(0.62, 0.32, 0.82), # 4 - Venenosa (púrpura)
	Color(0.95, 0.52, 0.18), # 5 - Berserker (naranja)
	Color(0.30, 0.82, 0.86), # 6 - Glacial (cian)
	Color(0.93, 0.45, 0.68), # 7 - Caos (rosa)
]

## Color gris usado para las rocas (ignora el color_id).
const ROCK_COLOR := Color(0.42, 0.40, 0.45)

## Identificador de color del bloque: 0..7.
## El setter lo limita al rango válido y refresca el aspecto visual.
@export_range(0, 7) var color_id: int = 0:
	set(value):
		color_id = clampi(value, 0, MAX_COLORS - 1)
		_refresh_visual()

## Si es true, el bloque es una roca: no se puede mover y nunca cuenta
## para completar un tubo.
@export var is_rock: bool = false:
	set(value):
		is_rock = value
		_refresh_visual()


func _ready() -> void:
	# Refresca el color al entrar al árbol. Necesario porque los valores
	# puestos desde el inspector (o con configure() antes de add_child)
	# se aplicaron cuando el nodo todavía no estaba listo.
	_refresh_visual()


## Configura el bloque de una sola vez. Útil al crear niveles o al
## instanciar bloques desde código:
##     var b := block_scene.instantiate() as Block
##     b.configure(2, false) # bloque verde de agua
func configure(new_color_id: int, rock: bool = false) -> void:
	color_id = new_color_id
	is_rock = rock
	_refresh_visual()


## Devuelve el color que debe mostrarse. Las rocas siempre son grises.
func get_visual_color() -> Color:
	if is_rock:
		return ROCK_COLOR
	return COLOR_PALETTE[color_id]


## Aplica el color al nodo. `modulate` tiñe el Node2D y todos sus hijos,
## así que funciona tanto con el Polygon2D de ejemplo de Block.tscn como
## con cualquier Sprite2D que se añada más adelante.
func _refresh_visual() -> void:
	# Fuera del árbol el nodo todavía no puede dibujarse; _ready() volverá
	# a llamar a esta función cuando entre en escena.
	if not is_inside_tree():
		return
	modulate = get_visual_color()
