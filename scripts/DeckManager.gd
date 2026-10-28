class_name DeckManager
extends Node
## Mazo de colores del prototipo roguelite.
##
## El mazo es una lista de color_id (0..7). En esta versión se conserva como
## HUD del futuro inventario: muestra cuántos colores quedan y emite
## `deck_changed`. El combate actual ya no lo usa para rellenar tubos, porque
## al completar uno se reparte un tablero nuevo con LevelGenerator.
##
## `draw_smart_colors()` queda como API heredada del antiguo "Relleno
## Inteligente". Sigue funcionando si se necesita en el futuro, pero
## GameManager no la llama.

## Se emite cada vez que cambia el número de colores disponibles.
signal deck_changed(remaining: int)


## Tamaño con el que se rellena el mazo.
@export_range(1, 100) var initial_deck_size: int = 12

## Cantidad de colores distintos que puede entregar (0..color_count - 1).
@export var color_count: int = Block.MAX_COLORS


## Colores disponibles. Se extraen desde el principio del array.
var deck: Array[int] = []

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_fill_deck()
	print("DeckManager: mazo inicial (%d colores): %s" % [deck.size(), deck])


## Número de colores que quedan en el mazo.
func remaining() -> int:
	return deck.size()


## Extrae `count` colores del mazo y los devuelve en orden.
##
## Si el mazo no tiene suficientes colores, se rellena de nuevo antes de
## extraer. El mazo es infinito para esta prueba.
func draw_colors(count: int) -> Array[int]:
	var amount := maxi(count, 0)
	var result: Array[int] = []
	if amount == 0:
		return result

	if deck.size() < amount:
		print("DeckManager: mazo insuficiente (%d). Se rellena mágicamente." % deck.size())
		_fill_deck()

	# Protección por si initial_deck_size fuese menor que `count`.
	while deck.size() < amount:
		deck.append(_random_color())

	for i in range(amount):
		result.append(deck.pop_front())

	deck_changed.emit(remaining())
	return result


## Extrae `count` colores aplicando el Relleno Inteligente.
##
## Garantiza al menos `minimum` copias de `guaranteed_color`, que GameManager
## elige a partir de la cima de otro tubo. Los colores garantizados se
## colocan al final del array para que queden en la parte superior del tubo
## recargado, dejando una jugada legal disponible.
##
## El resto de posiciones se rellena con colores aleatorios del mazo.
func draw_smart_colors(
	count: int,
	guaranteed_color: int,
	minimum: int = 2
) -> Array[int]:
	var amount := maxi(count, 0)
	var result := draw_colors(amount)

	# Sin pista válida (por ejemplo, todos los demás tubos están vacíos) o
	# sin cantidad que garantizar: se devuelve el reparto aleatorio normal.
	if amount == 0 or guaranteed_color < 0 or minimum <= 0:
		return result

	var required := mini(minimum, amount)
	var guaranteed_count := 0
	for color in result:
		if color == guaranteed_color:
			guaranteed_count += 1

	# Sustituye colores aleatorios hasta alcanzar el mínimo garantizado.
	var missing := required - guaranteed_count
	var index := 0
	while missing > 0 and index < result.size():
		if result[index] != guaranteed_color:
			result[index] = guaranteed_color
			missing -= 1
		index += 1

	# Reordena: primero el resto de colores, al final los garantizados.
	# Así los bloques del color de la pista quedan en la cima del tubo.
	var others: Array[int] = []
	var guaranteed: Array[int] = []
	for color in result:
		if color == guaranteed_color:
			guaranteed.append(color)
		else:
			others.append(color)

	var reordered: Array[int] = []
	reordered.append_array(others)
	reordered.append_array(guaranteed)

	# Evita que el tubo recargado tenga 4 colores iguales y se complete solo.
	if reordered.size() > required and _all_same(reordered):
		reordered[0] = (guaranteed_color + 1) % maxi(color_count, 1)

	return reordered


## Rellena el mazo de nuevo manualmente y avisa a la UI.
func refill() -> void:
	_fill_deck()
	deck_changed.emit(remaining())


func _fill_deck() -> void:
	deck.clear()
	for i in range(initial_deck_size):
		deck.append(_random_color())
	_shuffle_colors()


## Fisher-Yates con el RNG propio del mazo.
func _shuffle_colors() -> void:
	for i in range(deck.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp := deck[i]
		deck[i] = deck[j]
		deck[j] = temp


func _all_same(colors: Array[int]) -> bool:
	if colors.is_empty():
		return false
	var first := colors[0]
	for color in colors:
		if color != first:
			return false
	return true


func _random_color() -> int:
	return _rng.randi_range(0, maxi(color_count - 1, 0))
