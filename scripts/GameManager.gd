extends Node2D
## GameManager de la prueba interactiva.
##
## Flujo:
## 1. Clic en un tubo con bloques -> se selecciona (borde iluminado).
## 2. Clic en otro tubo -> si acepta el bloque superior, se mueve.
## 3. Clic en el mismo tubo -> se deselecciona.
## 4. Si el destino no es válido -> parpadeo rojo y se conserva la selección.
## 5. Cada movimiento válido gasta 1 movimiento, aunque mueva varios bloques.
## 6. Al llegar a 0 movimientos, el enemigo ataca. El escudo absorbe primero.
## 7. Al completar un tubo, solo ese tubo se vacía y se rellena con
##    LevelGenerator. El resto del tablero se conserva.
##
## Tube detecta el clic y emite `clicked`; este script decide qué hacer.

# ---------------------------------------------------------------------------
# Efectos de color
# ---------------------------------------------------------------------------

## Rojo (Guerrera): daño directo al enemigo.
const RED_DAMAGE := 3

## Azul (Guardiana): escudo que absorbe el siguiente ataque.
const BLUE_SHIELD := 3

## Verde (Curativa): curación de HP.
const GREEN_HEAL := 2

## Amarillo (Energética): movimientos extra.
const YELLOW_MOVES := 2

## Cualquier otro color: daño genérico.
const GENERIC_DAMAGE := 1

# ---------------------------------------------------------------------------
# Configuración
# ---------------------------------------------------------------------------

## Movimientos disponibles al empezar y después de cada ataque enemigo.
@export var starting_moves: int = 15

## Vida máxima e inicial del jugador.
@export var max_player_hp: int = 10

## Daño que hace el enemigo cuando se agotan los movimientos.
@export var enemy_attack_damage: int = 2

## Pasos inversos que intenta aplicar el generador al barajar el tablero.
@export_range(0, 200) var scramble_moves: int = 30

## Tubo seleccionado actualmente, o null si no hay ninguno.
var selected_tube: Tube = null

## Movimientos que le quedan al jugador en este turno.
var moves_left := 0

## Vida actual del jugador.
var player_hp := 0

## Escudo actual. Absorbe daño antes que el HP.
var player_shield := 0

## Generador de niveles por construcción inversa.
var _level_generator: LevelGenerator = null

## Evita que los tubos completados durante la generación disparen combate.
var _is_generating := false

## True mientras se reproduce la animación de completado y se rellena el tubo.
var _is_resolving_completion := false

## Si el movimiento que completó un tubo debe gastar su turno al terminar
## la animación y el efecto de color.
var _pending_move_spend := false

## Tween del parpadeo rojo del Label de HP.
var _hp_flash_tween: Tween = null

## Todos los Tube hijos directos de la escena.
@onready var tubes: Array[Tube] = _collect_tubes()

## Enemigo al que atacan los tubos completados.
@onready var enemy: Enemy = $Enemy as Enemy

## Mazo de colores. En esta fase se mantiene como HUD para el futuro inventario.
@onready var deck_manager: DeckManager = $DeckManager as DeckManager

## Label de UI que muestra cuántos colores quedan en el mazo.
@onready var deck_label: Label = get_node_or_null("DeckLabel") as Label

## Label de UI que muestra los movimientos restantes.
@onready var moves_label: Label = get_node_or_null("MovesLabel") as Label

## Label de UI que muestra HP y escudo del jugador.
@onready var player_hp_label: Label = get_node_or_null("PlayerHpLabel") as Label

## Botón que reparte un tablero nuevo y reinicia los movimientos.
@onready var reset_button: Button = get_node_or_null("ResetButton") as Button


func _ready() -> void:
	_level_generator = LevelGenerator.new()

	moves_left = starting_moves
	player_hp = max_player_hp
	player_shield = 0

	for tube in tubes:
		tube.clicked.connect(_on_tube_clicked)
		tube.completed.connect(_on_tube_completed.bind(tube))

	if deck_manager != null:
		deck_manager.deck_changed.connect(_on_deck_changed)
		_on_deck_changed(deck_manager.remaining())
	else:
		push_warning("Falta el nodo DeckManager en la escena Test.")

	if reset_button != null:
		reset_button.pressed.connect(_on_reset_board_pressed)

	_update_moves_label()
	_update_player_hp_label()

	generate_solvable_level()
	print("GameManager listo: completa tubos para activar efectos.")
	print("El enemigo responde al agotar movimientos.")


## Recoge los tubos en orden de escena. Si añades más Tube como hijos
## directos de Test, se conectarán automáticamente.
func _collect_tubes() -> Array[Tube]:
	var result: Array[Tube] = []
	for child in get_children():
		if child is Tube:
			result.append(child as Tube)
	return result


# ---------------------------------------------------------------------------
# Generación de niveles
# ---------------------------------------------------------------------------

## Reparte un tablero resoluble nuevo.
##
## `reset_moves` vuelve a poner el contador en `starting_moves`. El botón
## "Reiniciar Tablero" lo deja en true; al completar un tubo también se
## reinicia el turno, tal como permite el fallback del diseño.
func generate_solvable_level(reset_moves: bool = true) -> void:
	if _level_generator == null:
		_level_generator = LevelGenerator.new()

	if tubes.is_empty():
		push_warning("No hay tubos: no se puede generar el nivel.")
		return

	_is_generating = true
	_clear_selection()

	var success := _level_generator.generate(
		tubes,
		Block.MAX_COLORS,
		scramble_moves
	)

	_is_generating = false

	if reset_moves:
		moves_left = starting_moves
		_update_moves_label()

	# El mazo se conserva como HUD de inventario; se refresca con el tablero.
	if deck_manager != null:
		deck_manager.refill()

	_update_player_hp_label()

	var active_colors := clampi(tubes.size() - 2, 1, Block.MAX_COLORS)
	print("Nivel generado: %d tubos, %d colores activos, solución de %d movimientos." % [
		tubes.size(), active_colors, _level_generator.get_solution_length()
	])

	if not success:
		push_warning("El generador usó el tablero de emergencia.")


## Botón "Reiniciar Tablero". Sigue disponible como emergencia.
func _on_reset_board_pressed() -> void:
	if _is_resolving_completion:
		return
	generate_solvable_level()


# ---------------------------------------------------------------------------
# Interacción
# ---------------------------------------------------------------------------

## Punto de entrada de toda la interacción.
func _on_tube_clicked(tube: Tube) -> void:
	# Si el jugador ha muerto o hay una animación de completado en curso,
	# el tablero deja de aceptar clics.
	if player_hp <= 0 or _is_resolving_completion:
		return

	# Protección por si el tubo seleccionado fue liberado entre clics.
	if selected_tube != null and not is_instance_valid(selected_tube):
		selected_tube = null

	# No hay selección: solo se puede seleccionar un tubo con contenido.
	if selected_tube == null:
		if not tube.is_empty():
			_select_tube(tube)
		return

	# Clic sobre el mismo tubo: cancela la selección (no gasta movimiento).
	if tube == selected_tube:
		_clear_selection()
		return

	var run := selected_tube.get_top_run()
	var run_color := -1
	if not run.is_empty():
		run_color = run[0].color_id

	# Destino inválido: feedback y se mantiene la selección para que el
	# jugador pueda probar otro tubo sin volver a seleccionar.
	if run.is_empty() or not tube.can_accept_color(run_color):
		tube.flash_error()
		return

	# Se mueve toda la tanda que quepa. Si hay espacio suficiente, se mueve
	# la tanda completa; si no, se mueve la parte que entra.
	var amount := mini(run.size(), tube.get_free_space())
	if amount <= 0:
		tube.flash_error()
		return

	var moved_blocks := selected_tube.remove_top_blocks(amount)

	# remove_top_blocks devuelve de arriba hacia abajo; se añaden al revés
	# para conservar el orden original de la pila.
	for i in range(moved_blocks.size() - 1, -1, -1):
		if not tube.add_block(moved_blocks[i]):
			# No debería ocurrir: el destino tenía hueco y el mismo color.
			selected_tube.add_block(moved_blocks[i])

	_clear_selection()

	# Si el destino se completó, el efecto y la animación se resuelven primero
	# y el movimiento se descuenta al final. Así el +2 amarillo o una curación
	# no se pierden por un ataque enemigo disparado en el mismo clic.
	if _is_resolving_completion:
		_pending_move_spend = true
	else:
		# Solo los movimientos válidos consumen un turno, aunque muevan
		# varios bloques a la vez.
		_spend_move()


func _select_tube(tube: Tube) -> void:
	if selected_tube == tube:
		return
	if selected_tube != null:
		selected_tube.set_selected(false)
	selected_tube = tube
	selected_tube.set_selected(true)


func _clear_selection() -> void:
	if selected_tube != null and is_instance_valid(selected_tube):
		selected_tube.set_selected(false)
	selected_tube = null


# ---------------------------------------------------------------------------
# Movimientos y turno del enemigo
# ---------------------------------------------------------------------------

## Descuenta un movimiento y, al llegar a 0, cede el turno al enemigo.
func _spend_move() -> void:
	moves_left = maxi(moves_left - 1, 0)
	_update_moves_label()

	if moves_left == 0:
		_enemy_turn()


## Ataque del enemigo al quedarse el jugador sin movimientos.
## El escudo absorbe primero y el resto se resta del HP.
func _enemy_turn() -> void:
	if enemy != null and not enemy.is_dead:
		var absorbed := mini(player_shield, enemy_attack_damage)
		player_shield -= absorbed
		var hp_damage := enemy_attack_damage - absorbed
		player_hp = maxi(player_hp - hp_damage, 0)

		print("¡El enemigo ataca! Daño: %d | Escudo absorbe: %d | Pierdes %d HP." % [
			enemy_attack_damage, absorbed, hp_damage
		])
		print("HP: %d/%d | Escudo: %d" % [player_hp, max_player_hp, player_shield])
		_update_player_hp_label()

		if player_hp == 0:
			print("¡Has muerto!")
			_set_player_dead_visual()
			_flash_player_hp_label(Color(0.95, 0.3, 0.3))
		else:
			_flash_player_hp_label(Color.WHITE)
	else:
		print("El enemigo está derrotado: no hay contraataque.")

	moves_left = starting_moves
	_update_moves_label()


func _update_moves_label() -> void:
	if moves_label != null:
		moves_label.text = "Movimientos: %d" % moves_left


func _update_player_hp_label() -> void:
	if player_hp_label != null:
		player_hp_label.text = "HP: %d/%d | Escudo: %d" % [
			player_hp, max_player_hp, player_shield
		]


## Parpadeo rojo del Label de HP al recibir un ataque.
func _flash_player_hp_label(end_color: Color = Color.WHITE) -> void:
	if player_hp_label == null:
		return

	if _hp_flash_tween != null and _hp_flash_tween.is_valid():
		_hp_flash_tween.kill()

	player_hp_label.modulate = Color.WHITE
	_hp_flash_tween = create_tween()
	_hp_flash_tween.tween_property(
		player_hp_label, "modulate", Color(1.0, 0.22, 0.22), 0.08
	)
	_hp_flash_tween.tween_property(player_hp_label, "modulate", end_color, 0.20)


## Feedback visual de derrota del jugador en la UI.
func _set_player_dead_visual() -> void:
	if player_hp_label != null:
		player_hp_label.text = "HP: 0/%d | Escudo: %d — ¡Has muerto!" % [
			max_player_hp, player_shield
		]
		player_hp_label.modulate = Color(0.95, 0.3, 0.3)


# ---------------------------------------------------------------------------
# Combate al completar un tubo
# ---------------------------------------------------------------------------

## Se llama automáticamente cuando un tubo alcanza 4 bloques iguales.
##
## El resto del tablero NO se toca: se guarda el color, se reproduce el pop
## del tubo, se vacía SOLO ese tubo, se rellena con LevelGenerator y se
## aplica el efecto. Después se descuenta el movimiento pendiente.
func _on_tube_completed(tube: Tube) -> void:
	# Los completados que ocurren mientras se genera o se rellena no son
	# jugadas nuevas.
	if _is_generating or _is_resolving_completion:
		return

	var completed_color := -1
	var top := tube.get_top_block()
	if top != null:
		completed_color = top.color_id

	_is_resolving_completion = true
	_clear_selection()
	print("¡Tubo completado! Color %d." % completed_color)

	if is_instance_valid(tube):
		await tube.play_completion_animation()

	if not is_instance_valid(tube):
		_is_resolving_completion = false
		return

	tube.clear()

	var active_colors := clampi(tubes.size() - 2, 1, Block.MAX_COLORS)
	var refill_colors := _level_generator.generate_refill_colors(
		tubes, tube, completed_color, active_colors
	)

	if refill_colors.is_empty():
		# Caso excepcional: no hay datos para generar el relleno local.
		push_warning("Relleno local imposible: se usa un tablero de emergencia.")
		generate_solvable_level(false)
	else:
		_is_generating = true
		for color_id in refill_colors:
			tube.add_block(tube.create_block(color_id))
		_is_generating = false

		print("Tubo rellenado localmente con %d bloques: %s" % [
			refill_colors.size(), refill_colors
		])
		if refill_colors.size() < tube.max_capacity:
			push_warning("El relleno local dejó el tubo incompleto.")

	_apply_completion_effect(completed_color)
	_is_resolving_completion = false

	if _pending_move_spend:
		_pending_move_spend = false
		_spend_move()


## Aplica el efecto del color que completó el tubo.
func _apply_completion_effect(color_id: int) -> void:
	match color_id:
		0:
			print("Efecto rojo (Guerrera): %d de daño al enemigo." % RED_DAMAGE)
			if enemy != null:
				enemy.take_damage(RED_DAMAGE)
		1:
			player_shield += BLUE_SHIELD
			print("Efecto azul (Guardiana): +%d de escudo. Escudo: %d" % [
				BLUE_SHIELD, player_shield
			])
			_update_player_hp_label()
		2:
			var hp_before := player_hp
			player_hp = mini(player_hp + GREEN_HEAL, max_player_hp)
			print("Efecto verde (Curativa): +%d HP. HP: %d/%d" % [
				player_hp - hp_before, player_hp, max_player_hp
			])
			_update_player_hp_label()
		3:
			moves_left += YELLOW_MOVES
			print("Efecto amarillo (Energética): +%d movimientos. Movimientos: %d" % [
				YELLOW_MOVES, moves_left
			])
			_update_moves_label()
		_:
			print("Efecto genérico (color %d): %d de daño al enemigo." % [
				color_id, GENERIC_DAMAGE
			])
			if enemy != null:
				enemy.take_damage(GENERIC_DAMAGE)


## Actualiza el Label de UI cuando el mazo cambia.
func _on_deck_changed(remaining: int) -> void:
	if deck_label != null:
		deck_label.text = "Botellas en el mazo: %d" % remaining
