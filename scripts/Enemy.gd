class_name Enemy
extends Node
## Enemigo simple de la prueba de combate.
##
## Puede asignarse a un ColorRect, a un Label o a un Node2D con un hijo
## visual. El script no necesita que el nodo sea 2D: usa CanvasItem.modulate
## para el cambio de color al morir.

## Se emite cada vez que cambia el HP.
signal health_changed(current_hp: int, max_hp: int)

## Se emite una sola vez, cuando el HP llega a 0.
signal died

## Vida máxima configurable desde el inspector.
@export var max_hp: int = 10

## Nombre que se muestra en el Label de vida, si existe.
@export var display_name := "Enemigo"

## Ruta al Label hijo que muestra la vida. Si el script está directamente
## en un Label, se usa ese mismo nodo como visual.
@export var health_label_path: NodePath = ^"HealthLabel"

## Tinte que se aplica al morir.
@export var death_tint := Color(0.35, 0.35, 0.35)

## Vida actual. Empieza en max_hp al entrar en escena.
var current_hp := 0

## True cuando ya ha recibido el daño letal.
var is_dead := false

var _canvas_item: CanvasItem = null
var _label: Label = null


func _ready() -> void:
	current_hp = max_hp

	# Enemy extiende Node, pero puede estar asignado a un ColorRect/Label.
	# Se hace el downcast a través de Node para que el analizador estático
	# no rechace la conversión entre clases no relacionadas directamente.
	var self_node: Node = self
	if self_node is CanvasItem:
		_canvas_item = self_node as CanvasItem

	_label = get_node_or_null(health_label_path) as Label
	# Si el script está puesto directamente sobre un Label, usarlo.
	if _label == null and self_node is Label:
		_label = self_node as Label
	_refresh_visual()


## Aplica daño. Ignora valores negativos o daño recibido tras morir.
func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	current_hp = maxi(current_hp - amount, 0)
	print("%s recibe %d de daño. HP: %d/%d" % [display_name, amount, current_hp, max_hp])
	health_changed.emit(current_hp, max_hp)
	_refresh_visual()

	if current_hp == 0:
		_die()


func _die() -> void:
	is_dead = true
	print("¡Enemigo Derrotado!")

	if _canvas_item != null:
		_canvas_item.modulate = death_tint
	if _label != null:
		_label.text = "%s\nDERROTADO" % display_name

	died.emit()


func _refresh_visual() -> void:
	if _label != null:
		_label.text = "%s\nHP: %d/%d" % [display_name, current_hp, max_hp]
