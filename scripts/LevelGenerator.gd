class_name LevelGenerator
extends RefCounted
## Generador de niveles de Water Sort por construcción inversa.
##
## Idea general:
## 1. Se parte de un tablero "resuelto": un tubo lleno de 4 bloques del mismo
##    color por cada color activo, y el resto de tubos vacíos.
## 2. Se aplican movimientos inversos. Un movimiento inverso saca el bloque
##    superior de un tubo D y lo coloca encima de otro tubo A sin comprobar el
##    color.
## 3. Para que el movimiento inverso sea realmente el inverso de una jugada
##    legal, D debe seguir aceptando ese bloque después de quitarlo: o queda
##    vacío, o su nuevo bloque superior es del mismo color. Por eso solo se
##    usan tubos cuyo bloque superior forme parte de una pareja del mismo
##    color (o tubos con un único bloque).
## 4. El movimiento directo que deshace cada paso es A -> D. Si se guardan
##    todos los pasos y se aplican en orden inverso, se obtiene una solución
##    legal desde el tablero generado hasta el tablero resuelto.
##
## Esto garantiza que el tablero entregado al jugador siempre tiene solución,
## sin necesidad de un solver BFS.

## Bloques que se ponen en cada tubo semilla. La maqueta usa capacidad 4.
const BLOCKS_PER_TUBE := 4

## Intentos completos de generación antes de usar el tablero de emergencia.
const MAX_GENERATION_ATTEMPTS := 60

## Intentos para romper tubos completos que hayan quedado tras el barajado.
const MAX_BREAK_ATTEMPTS := 80

## Movimientos directos (A -> D) que resuelven el último tablero generado.
## Se guardan en orden de construcción; para resolver hay que recorrerlos
## en orden inverso.
var last_solution: Array[Dictionary] = []

## RNG propio para que una semilla pueda reproducir el mismo nivel.
var _rng := RandomNumberGenerator.new()


## `rng_seed` negativo usa una semilla aleatoria. Un valor >= 0 permite
## reproducir un nivel concreto en pruebas o en el modo diario.
func _init(rng_seed: int = -1) -> void:
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()


## Genera un tablero resoluble en `tubes`.
##
## `color_count` limita cuántos colores distintos puede usar el nivel.
## `scramble_moves` es la cantidad de pasos inversos que se intentan aplicar.
##
## Devuelve true si se pudo completar el barajado pedido. Si no, deja un
## tablero resuelto de emergencia (también resoluble, aunque trivial).
func generate(
	tubes: Array[Tube],
	color_count: int = Block.MAX_COLORS,
	scramble_moves: int = 30
) -> bool:
	last_solution.clear()

	if tubes.is_empty():
		push_warning("LevelGenerator: no hay tubos para generar el nivel.")
		return false

	var active_colors := clampi(
		tubes.size() - 2,
		1,
		mini(color_count, Block.MAX_COLORS)
	)
	var requested_moves := maxi(scramble_moves, 0)

	for _attempt in range(MAX_GENERATION_ATTEMPTS):
		if _try_generate(tubes, active_colors, requested_moves):
			return true

	# Emergencia: tablero resuelto. Es trivial, pero sigue siendo resoluble.
	push_warning("LevelGenerator: no se pudo barajar; se usa un tablero resuelto.")
	_build_seed_board(tubes, active_colors)
	last_solution.clear()
	return false


## Número de movimientos que tiene la solución del último tablero.
func get_solution_length() -> int:
	return last_solution.size()


## Genera 4 colores para rellenar SOLO el tubo completado.
##
## No modifica otros tubos ni consume el mazo: solo devuelve los color_id que
## GameManager colocará en `target`. Elige dos colores distintos que estén en
## la cima de otros tubos y que tengan hueco suficiente, para que el jugador
## tenga movimientos legales inmediatos. Nunca devuelve 4 bloques iguales,
## así el tubo no se completa otra vez al instante.
##
## Es el "Relleno Inteligente" adaptado al tablero actual: mantiene la
## sensación de que el nuevo tubo encaja con el resto del puzzle.
func generate_refill_colors(
	tubes: Array[Tube],
	target: Tube,
	previous_color: int = -1,
	color_count: int = Block.MAX_COLORS
) -> Array[int]:
	var result: Array[int] = []
	if target == null:
		return result

	var capacities := _get_top_capacities(tubes, target, color_count)
	var first := -1
	var first_capacity := -1
	var second := -1
	var second_capacity := -1

	for color in capacities.keys():
		var capacity := int(capacities[color])
		if capacity > first_capacity:
			second = first
			second_capacity = first_capacity
			first = int(color)
			first_capacity = capacity
		elif capacity > second_capacity:
			second = int(color)
			second_capacity = capacity

	if first < 0:
		first = previous_color if previous_color >= 0 else 0

	if second < 0 or second == first:
		var fallback_count := maxi(color_count, 1)
		second = (first + 1) % fallback_count
		if second == first:
			second = (second + 1) % fallback_count

	var wanted := target.max_capacity
	var first_count := wanted / 2
	var second_count := wanted - first_count

	# Si un color no tiene hueco para su mitad, se prueba un reparto 3+1.
	if first_capacity < first_count or second_capacity < second_count:
		if first_capacity >= wanted - 1:
			first_count = wanted - 1
			second_count = 1
		elif second_capacity >= wanted - 1:
			first_count = 1
			second_count = wanted - 1

	# El color con más hueco va arriba para poder vaciarlo primero.
	var top_is_first := first_capacity >= second_capacity
	var bottom_color := second if top_is_first else first
	var top_color := first if top_is_first else second
	var bottom_count := second_count if top_is_first else first_count
	var top_count := first_count if top_is_first else second_count

	for _i in range(bottom_count):
		result.append(bottom_color)
	for _i in range(top_count):
		result.append(top_color)
	return result


## Intenta construir un tablero barajado. Devuelve false si el barajado se
## queda sin movimientos inversos válidos antes de llegar al objetivo.
func _try_generate(
	tubes: Array[Tube],
	active_colors: int,
	scramble_moves: int
) -> bool:
	_build_seed_board(tubes, active_colors)

	var solution: Array[Dictionary] = []

	for _i in range(scramble_moves):
		var move_data := _make_reverse_step(tubes)
		if move_data.is_empty():
			return false
		solution.append(move_data)

	# Un tubo completo al empezar quedaría "resuelto" sin que el jugador
	# interactúe. Se rompe con pasos inversos adicionales.
	var break_attempts := 0
	while _has_complete_tube(tubes):
		break_attempts += 1
		if break_attempts > MAX_BREAK_ATTEMPTS:
			return false
		var break_move := _break_one_complete_tube(tubes)
		if break_move.is_empty():
			return false
		solution.append(break_move)

	last_solution = solution
	return true


## Vacía todos los tubos y coloca un tubo lleno por cada color activo.
## Los colores activos son 0..active_colors-1 para que la maqueta pueda
## mostrar los efectos rojo, azul, verde y amarillo.
func _build_seed_board(tubes: Array[Tube], active_colors: int) -> void:
	for tube in tubes:
		tube.clear()

	for color_id in range(active_colors):
		var tube := tubes[color_id]
		var amount := mini(BLOCKS_PER_TUBE, tube.max_capacity)
		for _i in range(amount):
			tube.add_block(tube.create_block(color_id))


## Aplica un paso inverso aleatorio y devuelve el movimiento directo que lo
## deshace: { from: A, to: D, color: X }. Devuelve {} si no hay opciones.
func _make_reverse_step(tubes: Array[Tube]) -> Dictionary:
	var options: Array[Dictionary] = []

	for dest_index in range(tubes.size()):
		var dest := tubes[dest_index]
		if dest.is_empty():
			continue

		var top := dest.get_top_block()
		if top == null:
			continue

		# Condición clave: al quitar el bloque superior, el destino debe
		# quedar vacío o seguir mostrando el mismo color. Así el movimiento
		# directo A -> D vuelve a ser legal.
		if dest.blocks.size() > 1:
			var below := dest.blocks[dest.blocks.size() - 2]
			if below.is_rock or below.color_id != top.color_id:
				continue

		for source_index in range(tubes.size()):
			if source_index == dest_index:
				continue
			if tubes[source_index].is_full():
				continue
			options.append({
				"from": source_index,
				"to": dest_index,
				"color": top.color_id,
			})

	if options.is_empty():
		return {}

	var choice: Dictionary = options[_rng.randi_range(0, options.size() - 1)]
	if not _apply_reverse_move(tubes, choice):
		return {}
	return choice


## Busca un tubo completo, le quita el bloque superior y lo coloca en otro
## tubo que no vaya a completarse con ese bloque.
func _break_one_complete_tube(tubes: Array[Tube]) -> Dictionary:
	for dest_index in range(tubes.size()):
		var dest := tubes[dest_index]
		if not dest.is_complete():
			continue

		var top := dest.get_top_block()
		if top == null:
			continue

		for source_index in range(tubes.size()):
			if source_index == dest_index:
				continue
			var candidate := tubes[source_index]
			if candidate.is_full():
				continue
			if _would_complete(candidate, top.color_id):
				continue

			var move_data := {
				"from": source_index,
				"to": dest_index,
				"color": top.color_id,
			}
			if _apply_reverse_move(tubes, move_data):
				return move_data

	return {}


## Ejecuta el paso inverso: saca de D y coloca en A.
func _apply_reverse_move(tubes: Array[Tube], move_data: Dictionary) -> bool:
	var from_index: int = int(move_data["from"])
	var to_index: int = int(move_data["to"])

	var block := tubes[to_index].remove_top_block()
	if block == null:
		return false

	return tubes[from_index].add_block(block)


## True si añadir un bloque de `color_id` a `tube` lo dejaría completo.
## Se usa para no encadenar completados durante la generación.
func _would_complete(tube: Tube, color_id: int) -> bool:
	if tube.blocks.size() + 1 != tube.max_capacity:
		return false

	for block in tube.blocks:
		if block.is_rock or block.color_id != color_id:
			return false
	return true


func _has_complete_tube(tubes: Array[Tube]) -> bool:
	for tube in tubes:
		if tube.is_complete():
			return true
	return false


## Capacidad de recepción disponible por color en los demás tubos.
##
## Para cada color en la cima de otro tubo se suma el hueco de todos los
## tubos que muestran ese color. Si hay tubos vacíos, también se ofrece
## capacidad para cualquier color activo, porque un tubo vacío acepta
## cualquiera.
func _get_top_capacities(
	tubes: Array[Tube],
	target: Tube,
	color_count: int
) -> Dictionary:
	var capacities := {}
	var empty_tubes := 0

	for tube in tubes:
		if tube == target:
			continue
		if tube.is_empty():
			empty_tubes += 1
			continue

		var top := tube.get_top_block()
		if top == null or top.is_rock:
			continue

		var color := top.color_id
		capacities[color] = int(capacities.get(color, 0)) + tube.get_free_space()

	if empty_tubes > 0:
		var limit := clampi(color_count, 1, Block.MAX_COLORS)
		for color in range(limit):
			capacities[color] = int(capacities.get(color, 0)) + (
				empty_tubes * target.max_capacity
			)

	return capacities
