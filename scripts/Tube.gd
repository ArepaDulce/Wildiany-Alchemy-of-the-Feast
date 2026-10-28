class_name Tube
extends Node2D
## Botella de Water Sort.
##
## Mantiene la pila lógica de bloques en `blocks` y coloca cada nodo Block
## como hijo directo del Tube. El bloque en el índice 0 es el de abajo y
## el último índice es el bloque superior.
##
## Convención de posiciones (2D: +Y va hacia abajo):
##
##     y = stack_bottom_y - block_height * índice
##
## Es decir, el primer bloque se apoya en `stack_bottom_y` y cada bloque
## nuevo se dibuja por encima del anterior. Cambia esos exports en el
## inspector para adaptar la botella a tu arte.

## Se emite después de que el bloque se añadió a la pila y se posicionó.
signal block_added(block: Block)

## Se emite después de sacar el bloque superior de la pila.
signal block_removed(block: Block)

## Se emite cuando el tubo pasa a estar completo (4 bloques del mismo
## color, sin rocas). La lógica de combate puede escuchar esta señal.
signal completed

## Se emite al hacer clic izquierdo sobre el tubo.
## GameManager escucha esta señal para gestionar la selección y el movimiento.
signal clicked(tube: Tube)

## Se emite cuando el tubo se selecciona o se deselecciona.
signal selection_changed(tube: Tube, selected: bool)


## Escena que se usa en create_block(). Así el Tube puede fabricar sus
## propios bloques sin depender de otro script.
const DEFAULT_BLOCK_SCENE := preload("res://scenes/Block.tscn")


## Capacidad máxima de la botella. Por defecto 4, según las reglas.
@export_range(1, 12) var max_capacity: int = 4

## Escena de bloque a instanciar. Normalmente se deja la de por defecto.
@export var block_scene: PackedScene = DEFAULT_BLOCK_SCENE

@export_group("Layout")
## Altura de cada bloque en píxeles. Debe coincidir con el tamaño visual
## del bloque para que se apilen sin solaparse.
@export var block_height: float = 43.0

## Posición Y local del centro del bloque inferior (índice 0).
@export var stack_bottom_y: float = 0.0

## Posición X local de todos los bloques (centro horizontal de la botella).
@export var block_x: float = 0.0

@export_group("Feedback")
## Color del borde cuando el tubo está seleccionado.
@export var selected_border_color := Color(0.40, 0.95, 1.0)

## Color del borde al rechazar un movimiento.
@export var error_border_color := Color(0.95, 0.25, 0.25)

@export_group("Game Feel")
## Escala máxima del pop al completar un tubo.
@export var completion_pop_scale := 1.12

## Color del borde durante el pop de completado.
@export var completion_border_color := Color(1.0, 0.92, 0.45)


## Pila lógica de bloques. El último elemento es el bloque superior.
## No se exporta para evitar que el inspector y el estado interno se
## desincronicen; manipula la pila con add_block()/remove_top_block().
var blocks: Array[Block] = []

## True mientras este tubo es el origen seleccionado.
var is_selected := false

## Color original del borde, guardado para restaurarlo al deseleccionar.
var _normal_border_color := Color(0.85, 0.76, 0.58)

## Tween activo del parpadeo de error, para poder cancelarlo si se hace
## clic otra vez antes de que termine.
var _flash_tween: Tween = null

## Tween del pop de completado.
var _completion_tween: Tween = null

## Borde que cambia de color al seleccionar o rechazar un movimiento.
## Es opcional: si el tubo no tiene un nodo "Border", el juego sigue
## funcionando sin feedback visual.
@onready var _border: Line2D = get_node_or_null("Border") as Line2D

## Área que detecta los clics. Debe existir en Tube.tscn.
@onready var _click_area: Area2D = get_node_or_null("ClickArea") as Area2D


func _ready() -> void:
	if _border != null:
		_normal_border_color = _border.default_color

	# Conexión por código para no depender del inspector. El evento
	# input_event pertenece al Area2D hijo, no al Node2D raíz.
	if _click_area != null:
		if not _click_area.input_event.is_connected(_on_click_area_input_event):
			_click_area.input_event.connect(_on_click_area_input_event)


# ---------------------------------------------------------------------------
# Consultas de estado
# ---------------------------------------------------------------------------

## Devuelve true si el tubo no está lleno y puede recibir `block`.
##
## Reglas:
## - El tubo vacío acepta cualquier bloque de agua.
## - Si hay bloques, el superior debe ser del mismo color y no ser roca.
## - Las rocas no se pueden mover, así que nunca se aceptan aquí.
func can_accept(block: Block) -> bool:
	if block == null:
		return false
	if is_full():
		return false
	# Las rocas son obstáculos estáticos: solo se colocan al generar el nivel.
	if block.is_rock:
		return false
	if is_empty():
		return true

	var top := get_top_block()
	return top != null and not top.is_rock and top.color_id == block.color_id


## True si el tubo puede recibir al menos un bloque del color indicado.
## Se usa para mover una tanda completa de bloques iguales.
func can_accept_color(color_id: int) -> bool:
	if is_full():
		return false
	if is_empty():
		return true

	var top := get_top_block()
	return top != null and not top.is_rock and top.color_id == color_id


## Devuelve los bloques consecutivos del mismo color que hay en la cima,
## en orden de arriba hacia abajo. Devuelve [] si la cima es una roca.
func get_top_run() -> Array[Block]:
	var run: Array[Block] = []
	var top := get_top_block()
	if top == null or top.is_rock:
		return run

	var run_color := top.color_id
	for i in range(blocks.size() - 1, -1, -1):
		var block := blocks[i]
		if block.is_rock or block.color_id != run_color:
			break
		run.append(block)
	return run


## Huecos libres que quedan en la botella.
func get_free_space() -> int:
	return maxi(max_capacity - blocks.size(), 0)


## Devuelve el bloque superior sin quitarlo, o null si está vacío.
func get_top_block() -> Block:
	if blocks.is_empty():
		return null
	return blocks.back()


## Devuelve true si no hay ningún bloque.
func is_empty() -> bool:
	return blocks.is_empty()


## Devuelve true si la pila alcanzó la capacidad máxima.
func is_full() -> bool:
	return blocks.size() >= max_capacity


## Devuelve true si el tubo está lleno, todos los bloques son del mismo
## color y ninguno es una roca.
func is_complete() -> bool:
	if blocks.is_empty() or blocks.size() != max_capacity:
		return false

	var first_color := blocks[0].color_id
	for block in blocks:
		if block.is_rock or block.color_id != first_color:
			return false
	return true


# ---------------------------------------------------------------------------
# Modificación de la pila
# ---------------------------------------------------------------------------

## Añade `block` al tubo y lo coloca encima del último bloque.
##
## Nota: esta función solo comprueba capacidad (y que el bloque no esté ya
## en este tubo). La validación de color se hace con can_accept() antes de
## llamar aquí, porque al generar niveles necesitamos poder poner rocas y
## colores arbitrarios.
##
## Devuelve true si se añadió correctamente.
func add_block(block: Block) -> bool:
	if block == null or is_full() or blocks.has(block):
		return false

	# Reparenta el bloque al tubo destino. add_child() lo hace solo cuando
	# el bloque viene huérfano de remove_top_block(); reparent() cubre el
	# caso de moverlo directamente desde otro tubo.
	var current_parent := block.get_parent()
	if current_parent == null:
		add_child(block)
	elif current_parent != self:
		block.reparent(self)

	blocks.append(block)
	_update_block_positions()

	block_added.emit(block)
	if is_complete():
		completed.emit()
	return true


## Saca el bloque superior de la pila y lo devuelve.
##
## El nodo queda fuera del árbol (huérfano) para que el llamador pueda
## animarlo, moverlo a otro tubo con add_block() o liberarlo con queue_free().
## Devuelve null si el tubo está vacío.
func remove_top_block() -> Block:
	if blocks.is_empty():
		return null

	var block: Block = blocks.pop_back()
	if block.get_parent() == self:
		remove_child(block)

	block_removed.emit(block)
	return block


## Saca hasta `count` bloques de la cima y los devuelve en orden de arriba
## hacia abajo. El llamador puede añadirlos a otro tubo en orden inverso
## para conservar la pila original.
func remove_top_blocks(count: int) -> Array[Block]:
	var removed: Array[Block] = []
	var amount := clampi(count, 0, blocks.size())
	for _i in range(amount):
		var block := remove_top_block()
		if block == null:
			break
		removed.append(block)
	return removed


## Vacía el tubo y libera sus bloques. Útil al reiniciar un encuentro.
func clear() -> void:
	# Copia la lista y vacía `blocks` antes de emitir señales para que los
	# listeners vean el tubo ya vacío y no puedan romper la iteración.
	var removed: Array[Block] = blocks.duplicate()
	blocks.clear()
	for block in removed:
		if block.get_parent() == self:
			remove_child(block)
		block_removed.emit(block)
		block.queue_free()


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

## Crea un Block configurado, sin añadirlo todavía al tubo.
## Ejemplo:
##     var b := tube.create_block(3) # amarillo
##     if tube.add_block(b):
##         ...
func create_block(new_color_id: int, rock: bool = false) -> Block:
	var block: Block = null
	if block_scene != null:
		block = block_scene.instantiate() as Block
	if block == null:
		# Fallback por si la escena no está asignada.
		block = Block.new()
	block.configure(new_color_id, rock)
	return block


## Recoloca todos los bloques según su índice en la pila.
## El índice 0 queda abajo y los siguientes suben (Y disminuye).
func _update_block_positions() -> void:
	for i in range(blocks.size()):
		blocks[i].position = Vector2(
			block_x,
			stack_bottom_y - block_height * i
		)


# ---------------------------------------------------------------------------
# Selección e interacción con el mouse
# ---------------------------------------------------------------------------

## Pequeño pop de escala y flash del borde antes de vaciar el tubo.
## GameManager espera esta función para que el efecto se vea completo.
func play_completion_animation() -> void:
	if _completion_tween != null and _completion_tween.is_valid():
		_completion_tween.kill()
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	_completion_tween = create_tween()
	_completion_tween.set_trans(Tween.TRANS_BACK)
	_completion_tween.set_ease(Tween.EASE_OUT)
	_completion_tween.tween_property(
		self, "scale", Vector2.ONE * completion_pop_scale, 0.10
	)
	if _border != null:
		_completion_tween.parallel().tween_property(
			_border, "default_color", completion_border_color, 0.10
		)

	_completion_tween.tween_property(self, "scale", Vector2.ONE, 0.16)
	if _border != null:
		_completion_tween.parallel().tween_property(
			_border, "default_color", _current_border_color(), 0.16
		)

	await _completion_tween.finished
	scale = Vector2.ONE
	_restore_border_color()


## Marca o desmarca el tubo como seleccionado y actualiza su borde.
## GameManager llama a esta función; el Tube no decide la selección.
func set_selected(value: bool) -> void:
	if is_selected == value:
		return

	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	is_selected = value
	_restore_border_color()
	selection_changed.emit(self, is_selected)


## Parpadeo rojo para indicar que el movimiento no es válido.
## El borde vuelve solo a su color normal o al de seleccionado.
func flash_error() -> void:
	if _border == null:
		return

	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	_flash_tween = create_tween()
	_flash_tween.tween_property(_border, "default_color", error_border_color, 0.06)
	_flash_tween.tween_property(_border, "default_color", _current_border_color(), 0.18)


## Restaura el borde al color que corresponde según el estado actual.
func _restore_border_color() -> void:
	if _border != null:
		_border.default_color = _current_border_color()


## Color que debe tener el borde ahora mismo.
func _current_border_color() -> Color:
	return selected_border_color if is_selected else _normal_border_color


## Callback conectado a ClickArea.input_event.
## La firma la define la señal del Area2D:
##     input_event(viewport: Node, event: InputEvent, shape_idx: int)
func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			clicked.emit(self)
