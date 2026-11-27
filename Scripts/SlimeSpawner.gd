extends Node

const ENEMY_SCENES: Array[PackedScene] = [
	preload("res://slime_cobre.tscn"),
	preload("res://robot.tscn"),
]
const GROUP := "spawned_enemies"
const ACTION := "spawn_slime"

# Capas de colisión: 2 = cuerpo del jugador, 3 = enemigos
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4

@export var auto_spawn := true
@export var spawn_interval := 3.0                   # segundos entre apariciones
@export var max_enemies := 20
@export var spawn_offset := Vector2(250.0, -80.0)   # relativo al jugador (X se voltea según el lado elegido)

## Límites horizontales donde puede aparecer un enemigo (coinciden con el suelo, x ≈ 4..1451, con margen).
## Si amplías el nivel, actualiza estos valores.
@export var spawn_min_x := 30.0
@export var spawn_max_x := 1425.0

## Todo lo que caiga por debajo de esta altura (Y global) se elimina; el jugador muere.
@export var kill_y := 800.0

var spawn_timer: Timer


func _ready() -> void:
	_setup_input_action()
	_create_kill_zone()

	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = auto_spawn
	spawn_timer.timeout.connect(spawn_enemy)
	add_child(spawn_timer)


## Backspace genera un enemigo al instante (útil para pruebas).
func _setup_input_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_BACKSPACE
	InputMap.action_add_event(ACTION, ev)


## Zona de muerte: un límite infinito en kill_y que detecta al jugador y a los enemigos.
func _create_kill_zone() -> void:
	var boundary := WorldBoundaryShape2D.new()  # normal hacia arriba: todo lo que esté debajo la toca
	var col := CollisionShape2D.new()
	col.shape = boundary

	var zone := Area2D.new()
	zone.name = "KillZone"
	zone.position = Vector2(0.0, kill_y)
	zone.collision_layer = 0
	zone.collision_mask = LAYER_PLAYER | LAYER_ENEMY
	zone.monitorable = false
	zone.add_child(col)
	zone.body_entered.connect(_on_kill_zone_body_entered)
	add_child.call_deferred(zone)


func _on_kill_zone_body_entered(body: Node2D) -> void:
	if body.has_method("fall_out"):
		body.fall_out()   # el jugador
	else:
		body.queue_free() # enemigos: desaparecen sin dar XP y dejan de contar para max_enemies


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION) and not event.is_echo():
		spawn_enemy()


func spawn_enemy() -> void:
	if get_tree().get_nodes_in_group(GROUP).size() >= max_enemies:
		return

	var jugador := get_tree().get_first_node_in_group("Jugador") as Node2D
	if jugador == null:
		return

	var enemy := ENEMY_SCENES.pick_random().instantiate() as Node2D
	enemy.add_to_group(GROUP)
	enemy.position = _pick_spawn_position(jugador.global_position)  # antes de entrar al árbol
	get_tree().current_scene.add_child(enemy)


## Elige un lado al azar; si ese lado queda fuera del suelo prueba el otro, y al final ajusta a los límites.
func _pick_spawn_position(player_pos: Vector2) -> Vector2:
	var side := -1.0 if randf() < 0.5 else 1.0
	var x := player_pos.x + spawn_offset.x * side
	if x < spawn_min_x or x > spawn_max_x:
		x = player_pos.x - spawn_offset.x * side
	x = clampf(x, spawn_min_x, spawn_max_x)
	return Vector2(x, player_pos.y + spawn_offset.y)
