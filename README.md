# 📋 Wildiany: Alchemy of the Feast — Documento de Diseño v1.0

**Fecha:** 28 de octubre de 2026
**Estado:** GDD v1.0 + prototipo jugable en Godot 4.7.2 con efectos de color, escudo, generador de niveles resoluble, relleno local y movimiento por tandas
**Próximo paso:** Iterar el prototipo técnico y validar el loop puzzle-combate

---

## 📑 Índice

1. [Visión y Pitch](#1-visión-y-pitch)
2. [Los 4 Pilares](#2-los-4-pilares)
3. [El Loop Central](#3-el-loop-central)
4. [Sistema de Inventario de Botellas](#4-sistema-de-inventario-de-botellas)
5. [Tipos de Botella](#5-tipos-de-botella)
6. [Combate](#6-combate)
7. [Enemigos y Modificadores](#7-enemigos-y-modificadores)
8. [Arcanos](#8-arcanos)
9. [Recursos y Economía](#9-recursos-y-economía)
10. [Estructura de la Run](#10-estructura-de-la-run)
11. [Narrativa](#11-narrativa)
12. [Progresión y Metaprogresión](#12-progresión-y-metaprogresión)
13. [Logros](#13-logros)
14. [Modo Diario](#14-modo-diario)
15. [Dirección de Arte](#15-dirección-de-arte)
16. [Plataformas y Port](#16-plataformas-y-port)
17. [Plan de Implementación](#17-plan-de-implementación)
18. [Decisiones Pendientes](#18-decisiones-pendientes)
19. [Glosario](#19-glosario)
20. [Registro de Cambios y Estado del Proyecto](#registro-de-cambios-y-estado-del-proyecto)

---

## Registro de Cambios y Estado del Proyecto

**Última actualización:** 28/10/2026
**Motor:** Godot 4.7.2
**Escena principal del prototipo:** `res://scenes/Test.tscn`

> Esta sección documenta el estado técnico del prototipo. El GDD original
> (secciones 1-19) sigue siendo el documento de diseño; aquí se registra lo
> que ya está implementado. Actualizar esta sección con cada cambio de
> scripts, escenas o lógica.

### Cambios de esta versión

- **Efectos de color:** al completar un tubo se aplica el efecto del color
  que lo completó (daño, escudo, curación o movimientos).
- **Escudo del jugador:** `player_shield` empieza en 0 y absorbe el daño del
  enemigo antes que el HP.
- **Generador de niveles inverso:** `LevelGenerator.gd` crea tableros con
  solución garantizada al 100% por construcción.
- **Relleno local al completar:** el tablero ya no se reinicia. Solo el tubo
  completado se vacía y se rellena con 4 colores generados por
  `LevelGenerator.generate_refill_colors()`. El resto de tubos conserva su
  contenido y el jugador no pierde el progreso.
- **Movimiento por tandas:** si la cima tiene varios bloques del mismo color,
  se mueven todos de una vez si el destino tiene hueco (o la parte que quepa).
  La tanda completa cuesta **1 movimiento**.
- **Separación visual:** el polígono del bloque mide **40×40** y el apilado usa
  `block_height = 43`, dejando un gap de **3 px** entre bloques.
- **Game feel:** el tubo hace un pop de escala con flash del borde antes de
  vaciarse, y el `PlayerHpLabel` parpadea en rojo cuando el enemigo ataca.
- **Botón “Reiniciar Tablero”:** se mantiene como emergencia. Reparte un nivel
  nuevo completo y vuelve a poner los movimientos en 15.
- **Escena ampliada a 6 tubos:** 4 colores activos (0-3) y 2 tubos de
  maniobra, suficientes para probar los cuatro efectos principales.
- **DeckManager:** se conserva como HUD del futuro inventario. Ya no decide
  el relleno de los tubos ni se consume al completar uno.

### Estado actual

El prototipo cubre el loop mínimo de puzzle + efectos + combate + turnos +
generación resoluble:

```text
Mover agua entre tubos (gasta 1 movimiento, aunque mueva varios bloques)
  → completar un tubo de 4 bloques iguales
  → pop de escala y flash del tubo
  → vaciar SOLO ese tubo y rellenarlo con 4 colores nuevos
  → aplicar el efecto del color completado
  → descontar el movimiento del turno
  → al agotar movimientos, el enemigo ataca (el Label de HP parpadea en rojo)
  → el escudo absorbe primero; el resto resta HP
```

- **Enemigo:** empieza con **10 HP** y ataca por **2 de daño**.
- **Jugador:** empieza con **10 HP** y **0 de escudo**.
- **Tubos:** 6 tubos de capacidad 4. Se usan 4 colores activos (0, 1, 2, 3).
  El generador parte de 4 tubos semilla y 2 vacíos, y luego baraja el tablero.
- **Movimientos:** empiezas con **15**. Cada movimiento válido gasta **1**,
  aunque mueva una tanda de varios bloques iguales. Cancelar la selección o
  intentar un destino inválido no gasta.
- **Ataque enemigo:** al llegar a **0 movimientos**, el enemigo ataca. El
  escudo absorbe primero y el resto se resta del HP. Después el contador
  vuelve a **15**. El Label de HP parpadea en rojo durante el ataque.
- **Muerte del jugador:** al llegar a **0 HP** se imprime `¡Has muerto!`, el
  Label se pone rojo y el tablero deja de aceptar clics.
- **Completar un tubo:** se vacía y rellena **solo ese tubo** con 4 colores
  nuevos. El resto del tablero se conserva y los movimientos no se reinician.
  El movimiento que completó el tubo se descuenta al final, después del efecto.

#### Efectos al completar un tubo

| `color_id` | Botella | Efecto en el prototipo |
|------------|---------|------------------------|
| 0 | Rojo / Guerrera | **3 de daño** al enemigo. |
| 1 | Azul / Guardiana | **+3 de escudo** al jugador. |
| 2 | Verde / Curativa | **+2 HP** al jugador, sin pasar de 10. |
| 3 | Amarillo / Energética | **+2 movimientos**. |
| 4-7 | Otros colores | **1 de daño genérico** al enemigo. |

- El escudo se acumula entre ataques y no caduca en esta maqueta.
- El HP se actualiza en `PlayerHpLabel` con el formato exacto
  `HP: 10/10 | Escudo: 3`.
- El Label del enemigo se actualiza solo mediante `Enemy.gd`.
- El efecto se aplica **antes** de descontar el movimiento del turno. Por eso
  el amarillo suma +2 y luego el movimiento de completado resta 1: el resultado
  neto es **+1 movimiento** (salvo que el contador esté a 0, que no puede ser
  porque el movimiento ya se estaba ejecutando).
- Si el efecto rojo o genérico mata al enemigo, el contador de movimientos se
  descuenta igualmente, pero el enemigo muerto ya no contraataca al llegar a 0.

#### Generador de niveles

- `LevelGenerator.gd` parte de un tablero resuelto: un tubo lleno de 4
  bloques del mismo color por cada color activo, y el resto vacíos.
- Aplica **30 pasos inversos** aleatorios. Cada paso mueve un bloque desde un
  tubo D a otro tubo A, guardando el movimiento directo `A -> D`.
- Para que la solución inversa sea legal, D debe seguir aceptando el bloque
  después de quitarlo: o queda vacío, o su nuevo bloque superior es del mismo
  color. Por eso solo se usan tubos cuyo bloque superior forma parte de una
  pareja del mismo color, o tubos con un único bloque.
- Al final se rompen los tubos completos que hayan quedado, para que el
  jugador no empiece con un tubo ya resuelto.
- La lista de movimientos directos, aplicada en orden inverso, resuelve el
  tablero. La generación se reintenta hasta 60 veces si un barajado se queda
  sin pasos válidos. Como último recurso se deja un tablero resuelto trivial,
  que también es resoluble.
- Solubilidad **100% garantizada por construcción**, sin solver BFS.

#### Relleno local del tubo completado

`LevelGenerator.generate_refill_colors()` no toca el resto del tablero. Solo
devuelve los 4 `color_id` que `GameManager` colocará en el tubo vacío:

- Calcula la capacidad libre por color en la cima de los demás tubos. Un tubo
  vacío cuenta como capacidad para cualquier color activo.
- Elige los dos colores con más capacidad y los reparte **2+2**; si un color no
  tiene hueco suficiente, prueba un reparto **3+1**.
- El color con más hueco se coloca arriba, para que el jugador pueda vaciarlo
  primero.
- Nunca genera 4 bloques del mismo color, así el tubo no se vuelve a completar
  solo y no se encadena un efecto inmediato.
- Es un relleno **heurístico**: mantiene la sensación de puzzle y ofrece
  movimientos legales inmediatos, pero no ejecuta un solver BFS para demostrar
  que el nuevo estado sigue siendo 100% resoluble. El generador completo sigue
  siendo la vía con garantía formal.
- Si `generate_refill_colors()` no pudiera producir colores, `GameManager` usa
  `generate_solvable_level(false)` como emergencia, sin reiniciar movimientos.

### Scripts del prototipo

| Archivo | Responsabilidad |
|---------|-----------------|
| `scripts/Block.gd` | Bloque de agua o roca. Guarda `color_id` (0..7), `is_rock`, paleta de colores y configuración visual. |
| `scripts/Tube.gd` | Botella de capacidad 4. Gestiona la pila `blocks`, `can_accept()`, `can_accept_color()`, `get_top_run()`, `get_free_space()`, `remove_top_blocks()`, `play_completion_animation()`, `add_block()`, `remove_top_block()`, `is_complete()`, `is_empty()`, el clic con `Area2D` y el feedback de selección/error. |
| `scripts/GameManager.gd` | Controlador de la escena. Gestiona selección y movimiento por tandas, movimientos, efectos de color, escudo, turno del enemigo, relleno local del tubo completado, botón de reinicio y actualización de la UI. |
| `scripts/LevelGenerator.gd` | Generador inverso de niveles. Crea el tablero semilla, aplica pasos inversos válidos, guarda la solución y rompe tubos completos. También genera los colores del relleno local con `generate_refill_colors()`. |
| `scripts/Enemy.gd` | Enemigo simple. Gestiona `max_hp`, `current_hp`, `take_damage()`, muerte, cambio de color y Label de vida. |
| `scripts/DeckManager.gd` | Mazo de 12 colores. Se conserva como HUD del futuro inventario y emite `deck_changed`. Su `draw_smart_colors()` queda como API heredada, pero el combate ya no lo usa. |

### Escenas y nodos

| Escena | Nodos principales |
|--------|-------------------|
| `scenes/Block.tscn` | `Block` (Node2D + `Block.gd`) → `Visual` (Polygon2D de 40×40 centrado). |
| `scenes/Tube.tscn` | `Tube` (Node2D + `Tube.gd`) → `Glass`, `Border`, `ClickArea` (Area2D) → `CollisionShape2D` (RectangleShape2D de 68×200 en y=20). `block_height = 43` deja 3 px de gap entre bloques. |
| `scenes/Test.tscn` | `Test` (Node2D + `GameManager.gd`) → 6 instancias de `Tube`, `Enemy`, `DeckManager`, `Title`, `DeckLabel`, `MovesLabel`, `PlayerHpLabel`, `ResetButton`. |

Árbol actual de `Test.tscn`:

```text
Test (Node2D) [GameManager.gd]
├── Tube     (instancia de Tube.tscn)  (150, 340)
├── Tube2    (instancia de Tube.tscn)  (310, 340)
├── Tube3    (instancia de Tube.tscn)  (470, 340)
├── Tube4    (instancia de Tube.tscn)  (630, 340)
├── Tube5    (instancia de Tube.tscn)  (790, 340)
├── Tube6    (instancia de Tube.tscn)  (950, 340)
├── Enemy    (ColorRect) [Enemy.gd]    max_hp = 10
│   └── HealthLabel (Label)
├── DeckManager (Node) [DeckManager.gd]
│                  initial_deck_size = 12
│                  color_count = 8
├── Title       (Label)  "Water Sort + Roguelite..."
├── DeckLabel   (Label)  "Botellas en el mazo: 12"
├── MovesLabel  (Label)  "Movimientos: 15"
├── PlayerHpLabel (Label) "HP: 10/10 | Escudo: 0"
└── ResetButton (Button) "Reiniciar Tablero"
```

Configuración importante:

- `Enemy` debe llamarse exactamente `Enemy`: `GameManager` lo obtiene con `$Enemy`.
- `DeckManager` debe llamarse exactamente `DeckManager`: `GameManager` lo obtiene con `$DeckManager`.
- `DeckLabel` debe llamarse exactamente `DeckLabel`: `GameManager` lo obtiene con `get_node_or_null("DeckLabel")`.
- `MovesLabel` debe llamarse exactamente `MovesLabel`: muestra `Movimientos: X`.
- `PlayerHpLabel` debe llamarse exactamente `PlayerHpLabel`: muestra `HP: X/10 | Escudo: Y`.
- `ResetButton` debe llamarse exactamente `ResetButton` para que `GameManager`
  conecte su señal `pressed`. Si falta, el juego funciona pero no hay botón.
- El hijo del enemigo debe llamarse `HealthLabel` (ruta por defecto de `health_label_path`).
- Los Labels están arriba a la izquierda: título (y=20), mazo (y=54),
  movimientos (y=90), HP/escudo (y=126) y botón de reinicio (y=170).
- Los valores de combate se pueden ajustar en el inspector del `Test`:
  `starting_moves = 15`, `max_player_hp = 10`,
  `enemy_attack_damage = 2`, `scramble_moves = 30`.
- La cantidad de colores activos se calcula como `tubos - 2`, limitada entre
  1 y 8. Con 6 tubos se usan 4 colores; con 5 tubos, 3; con 4 tubos, 2.
- Los efectos no necesitan Labels nuevos. El único nodo nuevo es
  `ResetButton`.

### Conexiones entre sistemas

1. **Selección y movimiento**
   - `Tube` detecta el clic con `ClickArea.input_event`.
   - `Tube` emite `clicked(tube)`.
   - `GameManager._on_tube_clicked()` selecciona, deselecciona o mueve la
	 tanda superior con `get_top_run()` y `can_accept_color()`.
   - Se mueven todos los bloques consecutivos del mismo color que quepan en el
	 destino (`min(tanda, hueco libre)`). Si no cabe la tanda completa, entra la
	 parte que quepa.
   - Solo los movimientos válidos llaman a `_spend_move()`; cancelar la
	 selección o intentar un destino inválido no gasta movimientos.
   - Una tanda completa cuesta 1 movimiento. Si el vertido completa el
	 destino, `_is_resolving_completion` bloquea clics y el movimiento se
	 descuenta al final con `_pending_move_spend`.

2. **Efectos y relleno local**
   - `Tube` emite `completed` al alcanzar 4 bloques iguales.
   - `GameManager._on_tube_completed(tube)` guarda el `color_id`, reproduce
	 `play_completion_animation()` (pop de escala + flash del borde), vacía
	 **solo ese tubo**, pide 4 colores a
	 `LevelGenerator.generate_refill_colors()` y los coloca.
   - Después llama a `_apply_completion_effect(color_id)`.
   - El resto de tubos no se modifica y los movimientos no se reinician.
   - Consola: `¡Tubo completado! Color X.`, `Tubo rellenado localmente...` y el
	 mensaje del efecto.

3. **Escudo y turno del enemigo**
   - Cada movimiento válido resta 1 a `moves_left` y actualiza `MovesLabel`.
   - Al llegar a 0, `_enemy_turn()` calcula
	 `absorbed = min(player_shield, enemy_attack_damage)`.
   - El escudo baja en `absorbed`; el HP baja en el resto.
   - Después actualiza `PlayerHpLabel`, imprime el resultado y reinicia
	 `moves_left` a 15.
   - El Label de HP parpadea en rojo (`_flash_player_hp_label()`); si el daño
	 es letal, termina en el color de derrota.
   - Si el enemigo ya está derrotado, no hay contraataque, pero el contador se
	 reinicia igualmente.
   - Consola: `¡El enemigo ataca! Daño: 2 | Escudo absorbe: 2 | Pierdes 0 HP.`
	 y `HP: 10/10 | Escudo: 1`.

4. **Generación y reinicio**
   - `GameManager.generate_solvable_level()` llama a
	 `LevelGenerator.generate(tubes, Block.MAX_COLORS, scramble_moves)`.
   - `LevelGenerator` rellena los tubos semilla, aplica los pasos inversos y
	 guarda la solución en `last_solution`.
   - `_is_generating` evita que los `completed` emitidos durante el relleno o
	 el barajado disparen efectos de combate.
   - `ResetButton.pressed` llama a `_on_reset_board_pressed()`, que reparte un
	 nivel nuevo completo y deja `moves_left = starting_moves`. Es el único
	 flujo que reinicia todo el tablero; se conserva como emergencia.

5. **UI del mazo**
   - `DeckManager` emite `deck_changed(remaining)`.
   - `GameManager._on_deck_changed()` actualiza `DeckLabel`.
   - El Label muestra `Botellas en el mazo: X`.
   - En esta versión el mazo es informativo: no se consume al completar tubos;
	 el relleno local lo genera `LevelGenerator`.

6. **Muerte del enemigo y del jugador**
   - `Enemy` imprime `¡Enemigo Derrotado!` y cambia a gris.
   - La señal `Enemy.died` está disponible para futuras recompensas o fin de
	 combate.
   - Si `player_hp` llega a 0, se imprime `¡Has muerto!`, `PlayerHpLabel`
	 se pone en rojo y el tablero deja de responder a clics.

### Generador inverso en detalle

El objetivo es que cualquier tablero entregado al jugador tenga una solución
legal, sin depender de un solver BFS.

1. **Colores activos:** `min(max(tubos - 2, 1), 8)`. Con 6 tubos se usan los
   colores 0, 1, 2 y 3.
2. **Tablero semilla:** los primeros `N` tubos se llenan con 4 bloques del
   mismo color. Los demás quedan vacíos.
3. **Paso inverso:** se elige un tubo D y otro tubo A con espacio. Se saca el
   bloque superior X de D y se coloca en A, sin comprobar el color. El
   movimiento directo que lo deshace es `A -> D`.
4. **Condición de reversibilidad:** para que `A -> D` sea legal en el tablero
   final, D debe aceptar X después de perderlo. Eso ocurre si D queda vacío o
   si su nuevo bloque superior también es X. Por eso D solo puede ser un tubo
   con un único bloque o con una pareja del mismo color en la cima.
5. **Solución:** cada paso se guarda como `{from: A, to: D, color: X}`. Al
   aplicar esos movimientos en orden inverso se llega al tablero resuelto.
6. **Limpieza:** si queda algún tubo completo, se rompe con pasos inversos
   adicionales que no completen otro tubo.
7. **Reintentos:** si el barajado se queda sin pasos válidos antes de los 30,
   se reinicia la generación. Como último recurso se entrega el tablero
   semilla resuelto.

Ejemplo de paso inverso:

```text
Antes (tablero resuelto):
  D: [rojo, rojo, rojo, rojo]
  A: []

Paso inverso:
  Se saca un rojo de D y se coloca en A.

Tablero generado:
  D: [rojo, rojo, rojo]
  A: [rojo]

Movimiento directo de la solución:
  A -> D  (rojo sobre rojo, legal)
```

La garantía no viene de que los pasos inversos sean jugadas legales, sino de
que **cada paso inverso tiene un movimiento directo legal que lo deshace**.
La solución completa es la lista de movimientos directos en orden inverso.

### Cómo probar en Godot

1. Abrir el proyecto con **Godot 4.7** o superior.
2. Confirmar que `project.godot` tiene como escena principal
   `res://scenes/Test.tscn`.
3. Pulsar **F5**.
4. Comprobar el estado inicial:
   - `DeckLabel`: `Botellas en el mazo: 12`.
   - `MovesLabel`: `Movimientos: 15`.
   - `PlayerHpLabel`: `HP: 10/10 | Escudo: 0`.
   - Enemigo: `HP: 10/10`.
   - Seis tubos y cuatro colores activos.
   - Consola: `Nivel generado: 6 tubos, 4 colores activos, solución de 30 movimientos.`
5. Probar que los clics no válidos no gastan movimientos:
   - Selecciona un tubo y haz clic en otro que no acepte su color.
   - Debe aparecer el parpadeo rojo y `Movimientos` no cambia.
   - Haz clic otra vez en el tubo seleccionado para deseleccionar; tampoco
	 gasta movimiento.
6. Probar el movimiento por tandas:
   - Prepara un tubo con 2-3 bloques iguales en la cima y otro con hueco.
   - Al hacer clic en el destino, se mueve toda la tanda que quepa.
   - `Movimientos` baja solo **1**, no uno por bloque.
7. Pulsar **Reiniciar Tablero** (emergencia):
   - El tablero completo cambia.
   - `MovesLabel` vuelve a `Movimientos: 15`.
   - `PlayerHpLabel` conserva HP y escudo.
   - Aparece otro mensaje `Nivel generado...`.
8. Completar un tubo resolviendo el puzzle con movimientos válidos:
   - Al cuarto bloque igual, el tubo hace un **pop de escala** con flash del
	 borde antes de vaciarse.
   - La consola muestra `¡Tubo completado! Color X.` y
	 `Tubo rellenado localmente con 4 bloques: [...]`.
   - **Solo ese tubo** cambia: el resto del tablero conserva sus bloques.
   - `MovesLabel` **no** vuelve a 15; solo se descuenta 1 por el movimiento.
   - El tubo relleno nunca sale con 4 bloques iguales.
9. Comprobar los efectos:
   - Rojo: el HP del enemigo baja 3.
   - Azul: `PlayerHpLabel` muestra `Escudo: 3`.
   - Verde: el HP del jugador sube 2, sin pasar de 10.
   - Amarillo: `Movimientos` sube 2 y luego baja 1 por el turno; el resultado
	 neto es +1.
   - Otro color: el enemigo recibe 1 de daño. Con 6 tubos el generador solo
	 usa los colores 0-3; para ver un color 4-7 hay que ampliar la escena o
	 ajustar el generador.
10. Comprobar el escudo:
	- Completa un tubo azul para ganar 3 de escudo.
	- Gasta movimientos hasta llegar a 0.
	- El primer ataque debe ser absorbido total o parcialmente.
	- El `PlayerHpLabel` parpadea en rojo durante el ataque.
	- Consola: `¡El enemigo ataca! Daño: 2 | Escudo absorbe: 2 | Pierdes 0 HP.`
	  y `HP: 10/10 | Escudo: 1`.
	- En el siguiente turno, el HP baja cuando ya no queda escudo.
11. Comprobar la muerte del jugador:
	- Repite el ciclo de agotar movimientos hasta que `player_hp` llegue a 0.
	- Aparece `¡Has muerto!`.
	- `PlayerHpLabel` termina en rojo con el texto de derrota.
	- El tablero deja de aceptar clics.
12. Comprobar la muerte del enemigo:
	- Repite tubos rojos hasta bajar sus 10 HP a 0.
	- Aparece `¡Enemigo Derrotado!` y el enemigo se pone gris.

> El generador completo garantiza una solución legal por construcción. El
> relleno local es heurístico: busca que el tablero siga jugable, pero no
> ejecuta un solver. Lo que ninguno garantiza es que el jugador encuentre la
> solución sin pensar: el puzzle sigue siendo un puzzle.

### Limitaciones conocidas

- Las animaciones son básicas: pop/flash al completar y parpadeo del Label de
  HP. No hay animación de vuelo de bloques, ataque ni explosión de partículas.
- No hay arcanos, múltiples enemigos, recompensas ni condición de victoria
  formal más allá de derrotar al enemigo.
- El ataque del enemigo es fijo (2 de daño) y no tiene patrones ni
  modificadores.
- Al completar un tubo se rellena ese mismo tubo; no entra una botella nueva
  desde un inventario como describe el GDD. `ResetButton` sigue siendo el
  reinicio completo de emergencia.
- El relleno local usa una heurística de capacidades y 2 colores; no está
  demostrado con un solver BFS que el estado resultante sea siempre 100%
  resoluble.
- El mazo es un HUD informativo. `DeckManager.draw_smart_colors()` ya no se
  usa en el combate.
- Los colores 4-7 aplican daño genérico; sus efectos de diseño (veneno,
  berserker, congelación, caos) todavía no están implementados.
- El generador completo no usa un solver BFS: la solubilidad está garantizada
  por la construcción inversa. Si el barajado falla, se usa un tablero resuelto
  trivial como emergencia.
- No hay semilla visible ni selector de dificultad para el jugador.

---

## 1. Visión y Pitch

### 🎯 Pitch de Elevador

> **"Wildiany: Alchemy of the Feast"** es un roguelite de puzzle y combate donde cada botella es un arma. Llenas frascos con aguas alquímicas para detonar sus efectos (daño, escudo, curación), construyes un inventario de botellas entre encuentros, y combinas arcanos del tarot para crear builds devastadoras. Un festín arruinado, tres actos, y un secreto al final.

### 🌟 Referencias e Inspiraciones

| Juego | Qué tomamos |
|-------|-------------|
| **Water Sort Puzzle** | Mecánica base de mover agua entre frascos. |
| **Balatro** | Sistema de "mano de cartas" → "mano de botellas". Arcanos como jokers. Economía de oro con interés. |
| **The Binding of Isaac** | Estructura de run por pisos, logros con pistas crípticas, personajes desbloqueables, narrativa ambiental. |
| **Slay the Spire** | Enemigos con modificadores combinados, decisiones tácticas bajo presión, checkpoint por acto. |
| **The Messenger** | Salto visual 16-bit → 32-bit como recurso narrativo. |

### 🎨 Identidad Única

- **El puzzle ES el combate.** No son dos sistemas separados; son uno solo.
- **El inventario ES el deck.** Construcción de build con botellas, no con cartas.
- **Cada color es una estrategia.** 8 tipos de botella = 8 formas de jugar.
- **El enemigo ES el puzzle.** Los modificadores reconfiguran el tablero en vivo.
- **Salto visual 16→32 bits** en el Acto 3 como giro narrativo.
- **Final secreto personal** oculto tras condiciones especiales.

---

## 2. Los 4 Pilares

### 🧬 Pilar 1: "Tu puzzle es tu arma"
Cada botella es un frasco que se llena con agua alquímica. Al completarla, **explota** y aplica su efecto (daño, escudo, curación, debuff). El puzzle y el combate son **el mismo sistema**. No hay "fase de puzzle" y "fase de combate" separadas.

### 🧬 Pilar 2: "Tu inventario es tu deck"
Tienes un **inventario de botellas** (10-20). En combate solo ves 3-5. Cuando una explota, sale del tablero y **entra una nueva del inventario**. Construyes tu colección comprando botellas en la tienda y eligiendo en drafts. Es **Balatro con botellas**.

### 🧬 Pilar 3: "Cada color es una estrategia"
8 tipos de botella (Guerrera, Guardiana, Curativa, Energética, Venenosa, Berserker, Glacial, Caos). Cada una tiene un efecto distinto. Los **arcanos** potencian tipos específicos. Construyes **builds temáticas** (build ofensiva, defensiva, de control, de caos).

### 🧬 Pilar 4: "El enemigo es el puzzle"
Los enemigos no son solo sacos de HP. Cada enemigo tiene un **modificador** que altera el tablero: rocas, blind, cursed, chain, timer. Múltiples enemigos = **múltiples modificadores simultáneos**. Cada encuentro es un puzzle único.

---

## 3. El Loop Central

### 🔄 Loop de Encuentro (30 segundos - 2 minutos)

```
1. Aparecen 1-3 enemigos con sus modificadores.
2. Se reparten 3-5 botellas en el tablero (parcialmente llenas).
3. Tienes N movimientos (15-25 según dificultad).
4. Cada movimiento: mueves agua entre botellas.
5. Al completar una botella → EXPLOTA → aplica su efecto.
6. La botella explotada sale → entra una nueva del inventario.
7. Cada 5 movimientos → todos los enemigos atacan.
8. Victoria: todos los enemigos mueren.
9. Derrota: HP = 0 o movimientos = 0 con enemigos vivos.
```

### 🔄 Loop de Run (30-60 minutos)

```
ACTO 1 (tutorial jugado) → Checkpoint
  ├── 5 encuentros progresivos
  ├── 1 tienda
  ├── 1 boss
  └── Desbloqueo: Acto 2 + Modo Festín

ACTO 2 (transición) → Checkpoint
  ├── 7 encuentros
  ├── 2 tiendas + 1 draft
  ├── 1 boss
  └── Desbloqueo: Acto 3 + Modo Ciclo

ACTO 3 (giro visual 16→32 bits)
  ├── 7 encuentros (enemigos entrelazados con puzzle)
  ├── 2 tiendas + 1 draft
  ├── 1 boss final
  └── Final + epílogo secreto
```

### 🔄 Loop de Metaprogresión (persistente)

```
Run terminada (victoria o derrota)
  → Ganas Esencia
  → Gastas Esencia en desbloqueos permanentes
  → Próxima run es más variada y (opcionalmente) más fácil
```

---

## 4. Sistema de Inventario de Botellas

### 📦 Concepto

**El sistema más importante del juego.** Es la fusión de "mano de cartas" (Balatro) con "frascos de agua" (Water Sort).

### 🎴 Estructura del Tablero

```
┌──────────────────────────────────────────────┐
│  ZONA DE ENEMIGOS (1-3)                      │
│  [Slime HP:5] [Gólem HP:8]                   │
│                                              │
│  ZONA DE COMBATE (3-5 botellas)              │
│  [🗡️ Guerrera]  [🛡️ Guardiana]  [🌿 Curativa] │
│   (parcial)      (parcial)       (parcial)   │
│                                              │
│  ZONA DE INVENTARIO (deck oculto, 10-20)     │
│  [🗡️][🗡️][🛡️][🌿][⚡][☠️][🔥][❄️]...          │
│                                              │
│  HUD:                                        │
│  Movimientos: 18/20                          │
│  HP: ♥♥♥♥♡ (8/10)                            │
│  Oro: 15                                     │
│  Arcanos: [🃏][🃏][🃏]                       │
└──────────────────────────────────────────────┘
```

### 🔄 Flujo de Combate

1. **Inicio del encuentro:**
   - Se reparten 3-5 botellas del inventario en el tablero (aleatorio).
   - Cada botella empieza con 1-3 bloques de agua ya puestos (parcial).
   - Se baraja el resto del inventario (deck oculto).

2. **Turno del jugador:**
   - Mueve agua de una botella a otra (consume 1 movimiento).
   - Reglas de Water Sort estándar: solo puedes mover a botella vacía o con mismo color arriba.

3. **Detección de completado:**
   - Si una botella tiene 4 bloques del mismo color → **EXPLOTA**.
   - Se aplica su efecto (daño, escudo, curación, etc.).
   - La botella **sale del tablero**.
   - **Entra una nueva botella del inventario** (aleatoria por defecto; algunos arcanos permiten elegir).

4. **Turno del enemigo:**
   - Cada 5 movimientos (configurable), todos los enemigos atacan.
   - Se aplican modificadores (rocas, blind, etc.).

5. **Fin del encuentro:**
   - **Victoria:** todos los enemigos mueren → recompensa (oro, draft de botella).
   - **Derrota:** HP = 0 o movimientos = 0 con enemigos vivos → fin de run (o checkpoint).

### 🎯 Decisiones Tácticas

El jugador decide **cada turno**:
- **¿Qué botella completar?** — ¿Guerrera (daño) o Guardiana (defensa)?
- **¿A qué enemigo atacar?** — ¿Al débil para eliminarlo o al fuerte para debilitarlo?
- **¿Cuándo usar arcanos?** — ¿Guardo El Loco para emergencia o lo uso ahora?
- **¿Cómo gestiono movimientos?** — ¿Soy eficiente o me preparo para el siguiente turno?

**Estas son las decisiones que hacen el juego profundo.**

---

## 5. Tipos de Botella

### 🎨 Las 8 Botellas (con sprites distintos, no solo colores)

| # | Botella | Color | Efecto al completar | Acto de intro |
|---|---------|-------|---------------------|---------------|
| 1 | 🗡️ **Guerrera** | Rojo | Daño directo al enemigo seleccionado (3 base). | Acto 1 |
| 2 | 🛡️ **Guardiana** | Azul | Escudo que absorbe el próximo ataque (3 base). | Acto 1 |
| 3 | 🌿 **Curativa** | Verde | Regenera HP (2 base). | Acto 1 |
| 4 | ⚡ **Energética** | Amarillo | +2 movimientos o recarga 1 arcano. | Acto 1 |
| 5 | ☠️ **Venenosa** | Púrpura | Aplica veneno (1 daño/turno por 3 turnos). | Acto 2 |
| 6 | 🔥 **Berserker** | Naranja | Daño masivo (5 base) a todos los enemigos, tú recibes 1 daño. | Acto 2 |
| 7 | ❄️ **Glacial** | Cian | Congela a un enemigo (pierde 1 turno de ataque). | Acto 3 |
| 8 | 🎲 **Caos** | Rosa | Efecto aleatorio: daño 2 / escudo 2 / curación 2 / +1 movimiento. | Acto 3 |

> **Estado en el prototipo:** los colores 0-3 ya aplican daño, escudo,
> curación y movimientos. Los colores 4-7 aplican 1 de daño genérico hasta
> que se implementen sus efectos de diseño.

### 📊 Stats Base (a balancear en playtesting)

- **Guerrera:** 3 daño. Con sinergias puede subir a 6-9.
- **Guardiana:** 3 escudo. Con sinergias puede subir a 6-9.
- **Curativa:** 2 HP. Con sinergias puede subir a 4-5.
- **Energética:** +2 movimientos. Con sinergias puede subir a +4.
- **Venenosa:** 1 daño × 3 turnos (total 3). Con sinergias puede subir a 2×3.
- **Berserker:** 5 daño a todos, -1 HP al jugador. Con sinergias puede subir a 8.
- **Glacial:** 1 turno congelado. Con sinergias puede subir a 2.
- **Caos:** 2 de efecto aleatorio. Con sinergias puede subir a 4.

**Nota:** Los números son **punto de partida**. Se ajustan en playtesting.

### 🎯 Sinergias entre Botellas

- **Guerrera + Guardiana:** "Build equilibrada". +1 daño por cada Guardiana en tablero.
- **Curativa + Energética:** "Build sostenible". +1 movimiento por cada Curativa completada.
- **Venenosa + Glacial:** "Build de control". El veneno hace +1 daño por cada enemigo congelado.
- **Berserker + Caos:** "Build de riesgo". El Caos puede activar Berserker gratis.

**Nota:** Las sinergias concretas se definen en arcanos, no en botellas (para mantener flexibilidad).

---

## 6. Combate

### ⚔️ Reglas de Combate

1. **HP del jugador:** 5 corazones de 2 HP = **10 HP** (ampliable a 8 corazones = 16 HP).
2. **Movimientos por encuentro:** 15-25 (configurable por dificultad).
   - Fácil: 25
   - Normal: 20
   - Difícil: 15
   - Boss: 30
3. **Ataque enemigo:** cada **5 movimientos** (configurable por enemigo).
   - Rápido: 3
   - Normal: 5
   - Lento: 7
4. **Escudo:** absorbe daño. Se resetea cada encuentro (no persiste entre encuentros).
5. **HP:** persiste entre encuentros. Solo se regenera con botellas Curativas o mejoras.
6. **Movimientos sobrantes:** al terminar un encuentro, los movimientos sobrantes se convierten en oro (1 movimiento = 1 oro, máx 5 oro por encuentro).

### 🎯 Condiciones de Victoria/Derrota

**Victoria:**
- Todos los enemigos tienen HP = 0.

**Derrota:**
- HP del jugador = 0.
- Movimientos = 0 con enemigos vivos → **-2 HP** y el encuentro continúa (con 0 movimientos, no puedes hacer nada, así que es derrota efectiva; esto se ajusta en playtesting).

### 🔄 Orden de Resolución

1. Jugador mueve agua (1 movimiento).
2. Se detectan botellas completadas → explotan (en orden de izquierda a derecha).
3. Se aplican efectos.
4. Se repone el tablero con nuevas botellas del inventario.
5. Se verifica victoria (¿enemigos muertos?).
6. Si no, y es turno enemigo (cada 5 movimientos), enemigos atacan.
7. Se verifica derrota (¿HP = 0?).

---

## 7. Enemigos y Modificadores

### 👹 Los 10 Enemigos del Acto 1

| # | Enemigo | HP | Ataque | Modificador | N (ataque) | Notas |
|---|---------|-----|--------|-------------|-----------|-------|
| 1 | **Slime** | 5 | 1 | Nada | 5 | Tutorial. |
| 2 | **Gólem** | 8 | 2 | Rocks (2) | 5 | Añade 2 rocas al tablero. |
| 3 | **Espectro** | 6 | 1 | Blind (1 frasco) | 5 | No ves 1 botella. |
| 4 | **Banshee** | 5 | 2 | Rápido (N=3) | 3 | Ataca más seguido. |
| 5 | **Arácnido** | 4 | 1 | Cursed (1 frasco) | 5 | 1 botella intocable. |
| 6 | **Rata** | 3 | 1 | Chain | 5 | Orden de botellas forzado. |
| 7 | **Vampiro** | 7 | 2 | Drain | 5 | Roba 1 HP al atacar. |
| 8 | **Ogro** | 12 | 3 | Heavy (N=7) | 7 | Lento pero pega duro. |
| 9 | **Hechicero** | 6 | 1 | Reverse | 5 | Solo puedes mover el bloque de abajo. |
| 10 | **El Engendro** (BOSS) | 30 | 3 | Rocks + Blind + Drain | 4 | 3 modificadores simultáneos. |

### 📋 Modificadores (definiciones)

| Modificador | Efecto |
|-------------|--------|
| **Rocks** | Añade N rocas al tablero (bloques grises que no se pueden mover). |
| **Blind** | 1 botella no muestra su contenido (solo el superior). |
| **Cursed** | 1 botella no se puede seleccionar. |
| **Chain** | Las botellas deben completarse en orden (de izquierda a derecha). |
| **Reverse** | Solo puedes mover el bloque de abajo, no el de arriba. |
| **Drain** | El enemigo roba HP al atacar (te quita 1, se cura 1). |
| **Rápido** | El enemigo ataca cada 3 movimientos. |
| **Heavy** | El enemigo ataca cada 7 movimientos pero por más daño. |

### 🎲 Combinaciones de Enemigos

- **1 enemigo:** fácil (1 modificador).
- **2 enemigos:** normal (2 modificadores).
- **3 enemigos:** difícil (máx 2 modificadores activos simultáneos).
- **Boss:** 1 enemigo con 3 modificadores.

**Regla:** máximo **2 modificadores activos** por encuentro (excepto bosses, que pueden tener 3).

### 🎯 Selección de Enemigos por Nivel

| Encuentro | Enemigos | Modificadores |
|-----------|----------|---------------|
| 1 | Slime | 0 |
| 2 | Slime + Slime | 0 |
| 3 | Gólem | Rocks |
| 4 | Espectro | Blind |
| 5 | Slime + Espectro | Blind |
| **BOSS 1** | El Engendro | Rocks + Blind + Drain |

**Nota:** esto es la progresión del Acto 1 (tutorial). Actos 2 y 3 tienen más variedad.

---

## 8. Arcanos

### 🃏 Los 20 Arcanos Iniciales

**Ofensivos (5):**
1. **El Mago** — Frascos Guerreros +50% daño.
2. **La Torre** — Al empezar encuentro, un frasco aleatorio empieza lleno.
3. **El Diablo** — Frascos Berserker dañan a todos los enemigos, pero tú recibes 1 daño extra.
4. **La Muerte** — Frascos Venenosos matan a enemigos con <20% HP.
5. **El Sol** — Cada frasco Guerrero completado da +1 HP temporal (máx 5).

**Defensivos (5):**
6. **La Sacerdotisa** — Frascos Curativos curan +1 HP extra.
7. **La Emperatriz** — Frascos Guardianes dan +1 escudo por cada Guerrero completado.
8. **El Hierofante** — Frascos completados no se pueden volver a tocar (protección).
9. **La Fuerza** — +1 corazón máximo (+2 HP).
10. **El Juicio** — Revives 1 vez con 1 HP.

**Utilitarios (5):**
11. **El Emperador** — Empiezas con 1 frasco Energético lleno.
12. **El Carro** — Puedes mover 5 bloques en vez de 4.
13. **La Rueda** — Reroll gratuito de tienda 1 vez por visita.
14. **El Ermitaño** — Deshacer cuesta 0 movimientos, 1 vez por encuentro.
15. **La Estrella** — Empiezas con 1 frasco extra vacío.

**Caóticos / Build (5):**
16. **Los Enamorados** — 2 frascos del mismo tipo en el mismo turno duplican su efecto.
17. **La Templanza** — Cada 3 frascos completados, +2 oro.
18. **El Loco** — Puedes mover 1 bloque a un frasco incompatible. 1 vez por encuentro.
19. **La Luna** — En Blind, ves el fondo de los frascos.
20. **El Mundo** — Al ganar encuentro, 10% del oro gastado → Esencia.

### 🎯 Sinergias por Categoría

- **3+ Ofensivos:** +2 daño global.
- **3+ Defensivos:** +1 escudo por turno.
- **3+ Utilitarios:** +3 movimientos por encuentro.
- **3+ Caóticos:** +1 oro por frasco completado.

### 🛒 Adquisición de Arcanos

- **Tienda:** comprar con oro (precio base 5-10 oro, según rareza).
- **Draft:** 1 de 3 opciones al final de ciertos encuentros.
- **Recompensa de boss:** arcano garantizado (1 de 3 a elegir).

### 🎒 Slots de Arcanos

- **Inicio:** 2 slots.
- **Acto 2:** 3 slots (mejora).
- **Acto 3:** 4 slots (mejora).
- **Máximo:** 4 slots (para forzar decisiones).

---

## 9. Recursos y Economía

### 💰 Los 4 Recursos

| Recurso | Para qué | Inicio | Ganancia |
|---------|----------|--------|----------|
| **HP** | Sobrevivir | 10 (5×2) | Botellas Curativas, mejoras |
| **Oro** | Tienda, rerolls, draft | 10 | Encuentros resueltos + arcanos |
| **Movimientos** | Por encuentro | 15-25 | Config por encuentro |
| **Esencia** (meta) | Desbloqueos permanentes | 0 | Al final de run |

### 💵 Economía del Oro

- **Ganancia por encuentro:** 5 oro base + bonificaciones.
- **Interés:** +10% del oro no gastado al final de cada acto (estilo Balatro).
- **Gasto en tienda:**
  - Botella: 3-5 oro.
  - Arcano: 5-10 oro.
  - Corazón: 8 oro.
  - Reroll: 2 oro.
- **Movimientos sobrantes:** 1 movimiento = 1 oro (máx 5 por encuentro).

### 💎 Economía de Esencia

- **Ganancia por run:** 10 base + 5 por acto completado + bonus por dificultad.
- **Gasto:**
  - Desbloquear arcano: 10-20 Esencia.
  - Desbloquear botella: 15-25 Esencia.
  - Desbloquear personaje: 50 Esencia.
  - Desbloquear modificador: 20 Esencia.

---

## 10. Estructura de la Run

### 🗺️ Los 3 Actos

**ACTO 1: "El Festín Arruinado"** (16-bit, tutorial jugado)
- 5 encuentros progresivos.
- 1 tienda.
- 1 boss (El Engendro).
- **Checkpoint al terminar.**
- **Duración:** 10-15 min.
- **Desbloquea:** Acto 2 + Modo Festín + Modo Diario.

**ACTO 2: "Los Arcanos Mayores"** (16-bit, transición)
- 7 encuentros.
- 2 tiendas + 1 draft.
- 1 boss (La Emperatriz).
- **Checkpoint al terminar.**
- **Duración:** 15-20 min.
- **Desbloquea:** Acto 3 + Modo Ciclo.

**ACTO 3: "El Banquete Eterno"** (32-bit, giro visual)
- 7 encuentros (enemigos entrelazados con puzzle).
- 2 tiendas + 1 draft.
- 1 boss final (El Mundo).
- **Final + epílogo secreto.**
- **Duración:** 20-25 min.
- **Desbloquea:** Finales alternativos + logros.

**Duración total de run:** 45-60 min.

### 🚪 Checkpoints

- **Checkpoint por acto.** Si mueres en Acto 2, reinicias Acto 2 (no Acto 1).
- **Al reiniciar:** HP vuelve al máximo del acto, oro se mantiene, arcanos se mantienen.
- **Movimientos:** se resetean por encuentro.

### 🎁 Modos de Juego (desbloqueables)

| Modo | Desbloqueo | Descripción |
|------|-----------|-------------|
| **Historia** | Inicio | Run de 3 actos. |
| **Festín** | Terminar Acto 1 | Run de 3 actos sin tutorial. |
| **Ciclo** | Terminar Acto 3 | Endless con dificultad creciente. |
| **Diario** | Terminar Acto 1 | Seed fija, leaderboard diario. |

---

## 11. Narrativa

### 📖 Premisa

> El Alquimista preparaba un festín para celebrar el solsticio. Pero algo en las sombras tenía hambre insaciable por los días felices. Una masa glotona emergió y devoró el festín frente a sus ojos, antes de arrastrarse hacia las profundidades. Ahora, el Alquimista debe descender por los tres Actos del Banquete, restaurar el orden de las esencias, y descubrir la verdad sobre el Engendro.

### 🎭 Estructura Narrativa

**Acto 1: El Festín Arruinado**
- Presentación del Alquimista.
- Introducción de los Arcanos Mayores.
- Boss: El Engendro (masa glotona).
- **Giro:** El Engendro no es un monstruo externo; es una parte del Alquimista.

**Acto 2: Los Arcanos Mayores**
- Los Arcanos Mayores revelan la verdad a medias.
- Decisiones morales (¿perdonar enemigos? ¿sacrificar arcanos?).
- Boss: La Emperatriz (manifestación de la gula).
- **Giro:** El Alquimista debe elegir entre restaurar el orden o abrazar el caos.

**Acto 3: El Banquete Eterno**
- Salto visual 16→32 bits (el mundo "se rompe").
- El Alquimista enfrenta su propia naturaleza.
- Boss: El Mundo (el Alquimista mismo, consumido).
- **Giro final:** 3 finales según decisiones.

### 🎬 Los 3 Finales

1. **Final del Orden:** El Alquimista restaura el festín. Sacrifica su gula. **Final "bueno" estándar.**
2. **Final del Caos:** El Alquimista abraza la gula. Se convierte en el nuevo Engendro. **Final "malo" estándar.**
3. **Final Secreto (El Regalo):** Solo se desbloquea al completar todas las condiciones ocultas. **Aquí está el mensaje personal para tu novia.** Estilo Undertale: críptico, oculto, recompensa por explorar.

**El Final Secreto se activa con:**
- Completar los 3 actos con los 3 personajes.
- Desbloquear los 50 logros.
- Encontrar 3 "ecos" ocultos en los actos.
- **Entonces:** se revela el mensaje.

---

## 12. Progresión y Metaprogresión

### 💎 Esencia (recurso meta)

- **Ganancia:** 10 base por run + 5 por acto + bonus por dificultad.
- **Persistencia:** se guarda en `SaveSystem.gd`.
- **Gasto:** desbloqueos permanentes.

### 🔓 Desbloqueos

| Categoría | Cantidad inicial | Cantidad máxima |
|-----------|------------------|-----------------|
| Arcanos | 20 | 60 |
| Botellas | 4 (Acto 1) | 8 |
| Personajes | 1 (El Alquimista) | 3 |
| Enemigos | 10 | 30 |
| Modificadores | 8 | 15 |

### 🧙 Los 3 Personajes Jugables

| Personaje | Estilo | Habilidad |
|-----------|--------|-----------|
| **El Alquimista** | Equilibrado | Empieza con 10 HP. Estándar. |
| **La Hechicera** | Frágil pero poderosa | 6 HP, pero +1 daño por botella. |
| **El Vagabundo** | Tanque | 14 HP, pero -1 movimiento por encuentro. |

### 🎯 Sistema de Logros (estilo TBOI)

- **50 logros en lanzamiento.**
- **Pistas crípticas** (no spoilers).
- **Recompensas:** desbloquean arcanos, botellas, personajes, modificadores.
- **Ejemplos:**
  - *"Ecos del Pasado"* — Termina el Acto 1 sin usar arcanos.
  - *"El Ciclo Sin Fin"* — Llega al Estrato 10 en Modo Ciclo.
  - *"El Banquete Perfecto"* — Completa una run sin perder HP.
  - *"El Coleccionista"* — Ten 4 arcanos de la misma categoría.

### 📊 Sistema de Ascensiones (post-lanzamiento)

- 20 niveles de dificultad creciente (estilo Slay the Spire).
- Cada nivel añade un modificador global.
- Se desbloquea al completar el Acto 3.

---

## 13. Logros (50 en lanzamiento)

**Categorías:**
- **Historia (10):** completar actos, ver finales.
- **Combate (10):** victorias sin daño, con tipos específicos.
- **Construcción (10):** builds con 4 arcanos de la misma categoría, etc.
- **Exploración (10):** encontrar ecos ocultos, secretos.
- **Desafío (10):** runs difíciles, sin arcanos, etc.

**Sistema de pistas:** cada logro tiene una pista críptica que se desbloquea al progresar. Ejemplo:
- **Logro:** "El Ciclo Sin Fin"
- **Pista inicial:** "Desciende más allá de lo conocido."
- **Pista completa (tras desbloquear):** "Llega al Estrato 10 en Modo Ciclo."

---

## 14. Modo Diario

### 📅 "El Festín Diario"

- **Seed fija** por día (misma para todos los jugadores).
- **Leaderboard diario** (local, escalable a online).
- **Desbloqueo:** completar Acto 1 una vez.
- **Duración:** 15-20 min (una run corta).
- **Recompensa:** Esencia bonus.

### 📅 "El Banquete Semanal" (futuro)

- **Seed fija** por semana.
- **Modificadores especiales.**
- **Leaderboard semanal.**

---

## 15. Dirección de Arte

### 🎨 Estilo Visual

- **Pixel art 16-bit** (Actos 1 y 2).
- **HD-2D 32-bit** (Acto 3, salto visual).
- **Inspiración:** Castlevania: SotN (gótico), Balatro (minimalista), The Messenger (salto visual).
- **Paleta:** oscura, gótica, con acentos de color brillante en botellas.
- **Resolución:** 320×180 (16-bit) → escalado a 1280×720 / 1920×1080.

### 🎨 Sprites Necesarios

**Botellas (8):** Guerrera, Guardiana, Curativa, Energética, Venenosa, Berserker, Glacial, Caos. Cada una con 4-6 frames de animación (llenado, explosión, idle).

**Enemigos (10+):** Slime, Gólem, Espectro, Banshee, Arácnido, Rata, Vampiro, Ogro, Hechicero, El Engendro. Cada uno con animaciones de idle, ataque, daño, muerte.

**Arcanos (20+):** Ilustraciones de cartas (estilo tarot).

**UI:** Botones, marcos, iconos, corazones, oro, movimientos.

**Fondos:** 3 actos × 3-4 fondos distintos = 10-12 fondos.

### 🎨 Herramientas

- **Aseprite** para pixel art.
- **IA (Midjourney, DALL-E)** para referencias.
- **Godot** para animaciones (AnimationPlayer).

---

## 16. Plataformas y Port

### 💻 Plataformas Objetivo

1. **PC (Windows, Linux, Mac)** — Prioridad 1.
2. **Android** — Prioridad 2.
3. **iOS** — Prioridad 3 (post-lanzamiento).
4. **Steam** — Distribución principal.

### 📱 Consideraciones de Port Android

- **Resolución:** 16:9 y 20:9 (adaptive).
- **Touch:** tap para seleccionar, tap para mover.
- **Botones grandes** (mínimo 44px).
- **Guardado automático** cada encuentro.

### 🎯 Distribución

- **itch.io** primero (gratis, comunidad indie).
- **Steam** después (página, wishlist, lanzamiento).
- **Google Play** (Android).

---

## 17. Plan de Implementación

### 🗓️ Fases (12 meses estimados)

| Fase | Duración | Qué se construye | Estado |
|------|----------|------------------|--------|
| **0. GDD v1.0** | 1 semana | Este documento. | ✅ Completado |
| **0.5. Prototipo de papel** | 1-2 semanas | Validar loop con cartas. | 🔜 Siguiente |
| **1. Puzzle base** | 1 semana | Frascos, mover agua. | ✅ Prototipo |
| **2. Generador + solver** | 1 semana | LevelGen con solver BFS. | ✅ Generador inverso; solver BFS pendiente |
| **3. Combate base** | 2 semanas | HP, enemigos, ataques. | ✅ Prototipo |
| **4. Inventario de botellas** | 2 semanas | Deck, mano, reemplazo. | 🔜 Mazo HUD |
| **5. Arcanos** | 2 semanas | 20 arcanos, efectos, tienda. | ⏳ Pendiente |
| **6. Acto 1 completo** | 3 semanas | 5 encuentros + boss + tienda + draft. | ⏳ Pendiente |
| **7. Playtesting** | 2 semanas | Balance, bugs, UX. | ⏳ Pendiente |
| **8. Acto 2 + 3** | 6 semanas | Contenido, enemigos, bosses, narrativa. | ⏳ Pendiente |
| **9. Salto 16→32 bits** | 2 semanas | Acto 3 en HD-2D. | ⏳ Pendiente |
| **10. Metaprogresión + logros** | 2 semanas | Esencia, desbloqueos, 50 logros. | ⏳ Pendiente |
| **11. Modo diario** | 1 semana | Seeds fijas, leaderboard. | ⏳ Pendiente |
| **12. Pixel art** | 8 semanas | Sprites, animaciones, UI. | ⏳ Pendiente |
| **13. Port Android** | 2 semanas | Touch, resolución, export. | ⏳ Pendiente |
| **14. Pulido + lanzamiento** | 4 semanas | Balance final, trailer, itch.io. | ⏳ Pendiente |

**Total:** ~12 meses a tiempo parcial.

### 🎯 Hitos (Milestones)

- **M1 (Mes 2):** Puzzle base funcional.
- **M2 (Mes 4):** Combate + inventario funcional.
- **M3 (Mes 6):** Acto 1 jugable completo.
- **M4 (Mes 8):** Actos 2 y 3 jugables.
- **M5 (Mes 10):** Metaprogresión + logros.
- **M6 (Mes 12):** Lanzamiento en itch.io.

---

## 18. Decisiones Pendientes

### ❓ Pendientes de Diseño

1. **Números exactos de los 20 arcanos** (daño, escudo, curación, etc.).
2. **Los 3 personajes jugables** (stats exactos, habilidades).
3. **El árbol narrativo ramificado** (3 ramas × 3 actos = 9 ramas).
4. **Los 10 enemigos del Acto 2 y 3** (stats).
5. **Los 2 bosses restantes** (La Emperatriz, El Mundo).
6. **El sistema de ecos ocultos** (para el Final Secreto).
7. **El style guide de pixel art** (paleta, resolución, referencia).
8. **El sistema de ascensiones** (20 niveles post-lanzamiento).

### ❓ Pendientes Técnicos

1. **Algoritmo del solver BFS** (para verificar solubilidad).
2. **Sistema de guardado** (JSON vs. binario).
3. **Sistema de seeds** (para modo diario).
4. **Sistema de localización** (i18n).

### ❓ Pendientes de Validación

1. **Prototipo de papel** (validar loop de combate + inventario).
2. **Playtesting con 3 personas** (tú, tu novia, un amigo).
3. **Balance de números** (ajustar tras playtesting).

---

## 19. Glosario

| Término | Definición |
|---------|------------|
| **Acto** | Una de las 3 secciones de una run (1: Festín Arruinado, 2: Arcanos Mayores, 3: Banquete Eterno). |
| **Arcano** | Mejora pasiva o activa, estilo joker de Balatro. 20 iniciales, 60 máx. |
| **Botella** | Frasco con agua alquímica. 8 tipos. Es el "arma" del juego. |
| **Checkpoint** | Punto de guardado al final de cada acto. |
| **Combate** | Encuentro contra 1-3 enemigos. |
| **Draft** | Elegir 1 de 3 botellas al final de ciertos encuentros. |
| **Encuentro** | Un combate individual. 5-7 por acto. |
| **Esencia** | Recurso meta para desbloqueos permanentes. |
| **Festín** | Modo de juego sin tutorial (desbloqueable). |
| **HP** | Puntos de vida. 5 corazones de 2 = 10 HP. |
| **Inventario** | Deck de botellas. 10-20 botellas. |
| **Modificador** | Efecto de enemigo que altera el tablero. |
| **Movimiento** | Acción de mover agua entre botellas. Recurso por encuentro. |
| **Oro** | Recurso para comprar en tienda. |
| **Personaje** | Avatar jugable. 3 en total. |
| **Run** | Una partida completa (3 actos). 45-60 min. |
| **Seed** | Semilla de aleatoriedad. Para modo diario. |
| **Sinergia** | Bonus por combinar arcanos o botellas. |
| **Tienda** | Lugar entre encuentros para comprar. |
| **Wildiany** | Nombre del juego. |

---

## ✅ Resumen Ejecutivo

**Wildiany: Alchemy of the Feast** es un roguelite de puzzle y combate donde:
- **Cada botella es un arma.** Llenas frascos para detonar efectos.
- **Cada inventario es un deck.** Construyes tu colección entre encuentros.
- **Cada color es una estrategia.** 8 tipos de botella.
- **Cada enemigo es un puzzle.** Modificadores reconfiguran el tablero.
- **3 actos, salto visual 16→32 bits, final secreto personal.**

**Estado actual:** GDD v1.0 + prototipo jugable en Godot con efectos, escudo y generador resoluble.
**Próximo paso:** Iterar el prototipo (inventario, enemigos y arcanos) y validar el loop.
**Objetivo:** Validar el loop antes de ampliar el alcance.

---

## 🎯 Próximos pasos inmediatos

1. **Hoy:** Guardar este documento en `docs/GDD_v1.0.md` en el repo del proyecto.
2. **Esta semana:** Prototipo de papel (ver guía abajo).
3. **Próxima semana:** Playtesting con 3 personas.
4. **En 2 semanas:** Ajustar GDD v1.1 según feedback.
5. **En 3 semanas:** Empezar Fase 1 en Godot.

---

## 🎲 Guía del Prototipo de Papel (empieza mañana)

### Materiales necesarios
- 20 cartas de botella (4 tipos × 5 copias).
- 10 cartas de enemigo (1 por enemigo).
- 20 cartas de arcano (1 por arcano).
- 10 fichas de "movimiento".
- 5 fichas de corazón (HP).
- 20 fichas de oro.
- 1 dado de 6 caras.
- Papel y lápiz.

### Setup
1. Baraja las 20 botellas. Reparte 5 al tablero, boca arriba.
2. Baraja las 10 enemigos. Elige 1 al azar.
3. Coloca los 5 corazones (HP = 10).
4. Coloca los 10 movimientos.
5. Coloca los 10 oros.

### Reglas simplificadas
- **Movimiento:** mueve una ficha de agua de una botella a otra (mismas reglas de Water Sort).
- **Completar botella:** si tienes 4 fichas del mismo tipo en una botella, explota → aplica efecto → roba 1 botella nueva.
- **Ataque enemigo:** cada 5 movimientos, tira 1 dado (daño = resultado).
- **Victoria:** enemigo HP = 0.
- **Derrota:** HP = 0.

### Qué observar
- ¿El loop es divertido?
- ¿Las decisiones son interesantes?
- ¿El ritmo es bueno?
- ¿Qué falta? ¿Qué sobra?

**Anota TODO.** Ese feedback va al GDD v1.1.

---

**Documento cerrado. Listo para guardar. 🎉**
