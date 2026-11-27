extends CharacterBody2D

## Enemigo cuerpo a cuerpo: detecta al jugador, lo persigue y lo ataca al estar cerca.
## Nodos requeridos: AnimatedSprite2D (animaciones "default", "attack" y "death") y CollisionShape2D.
## El área de ataque (AreaAttack) se crea por código si la escena no la tiene.

enum State { IDLE, CHASE, ATTACK, HURT, DEAD }

const GRAVITY_MULT := 1.5
const KNOCKBACK := Vector2(250.0, -200.0)   # X se orienta según el atacante
const KNOCKBACK_TIME := 0.25
const KNOCKBACK_FRICTION := 800.0
const VERTICAL_TOLERANCE := 40.0            # diferencia de altura máxima para atacar
const LOSE_TARGET_FACTOR := 1.5             # pierde al jugador a detection_range * este factor

# Capas de colisión: 1 = mundo, 2 = cuerpo del jugador, 3 = enemigos, 4 = hurtbox del jugador
const LAYER_WORLD := 1
const LAYER_ENEMY := 4
const LAYER_HURTBOX := 8

# Colores de debug (Debug > Visible Collision Shapes)
const COLOR_BODY := Color(0.2, 0.9, 0.3, 0.4)     # cuerpo: verde
const COLOR_ATTACK := Color(1.0, 0.5, 0.0, 0.45)  # área de ataque: naranja

@export var max_hp := 5.0
@export var attack_damage := 3.0
@export var move_speed := 80.0
@export var detection_range := 400.0   # distancia a la que empieza a perseguir
@export var attack_range := 30.0       # distancia horizontal que dispara el ataque
@export var attack_cooldown := 1.0     # segundos entre ataques
@export var hit_frame := 2             # frame de "attack" en el que cae el golpe
@export var xp_reward := 10
@export var sprite_faces_right := true # false si el sprite original mira a la izquierda
@export var attack_area_size := Vector2(24.0, 20.0)
@export var attack_area_offset := Vector2(20.0, 0.0)  # mirando a la derecha

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var state := State.IDLE
var jugador: Node2D
var attack_area: Area2D
var hp := 0.0
var facing := 1.0
var cooldown_timer := 0.0
var attack_time := 0.0
var knockback_time := 0.0
var hit_done := false
var attack_base_pos_x := 0.0
var attack_base_scale_x := 1.0


func _ready() -> void:
	hp = max_hp
	jugador = get_tree().get_first_node_in_group("Jugador") as Node2D

	collision_layer = LAYER_ENEMY
	collision_mask = LAYER_WORLD | LAYER_ENEMY
	body_shape.debug_color = COLOR_BODY

	_setup_attack_area()
	_setup_animations()
	_show_rest_frame()


## Usa el nodo AreaAttack de la escena si existe; si no, lo crea con attack_area_size/offset.
func _setup_attack_area() -> void:
	attack_area = get_node_or_null("AreaAttack") as Area2D
	if attack_area == null:
		attack_area = Area2D.new()
		attack_area.name = "AreaAttack"
		attack_area.position = attack_area_offset

		var shape := RectangleShape2D.new()
		shape.size = attack_area_size
		var col := CollisionShape2D.new()
		col.shape = shape
		attack_area.add_child(col)
		add_child(attack_area)

	attack_area.collision_layer = 0
	attack_area.collision_mask = LAYER_HURTBOX
	attack_base_pos_x = attack_area.position.x
	attack_base_scale_x = absf(attack_area.scale.x)

	for child in attack_area.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node != null:
			shape_node.debug_color = COLOR_ATTACK


## "attack" y "death" se reproducen una sola vez (no en bucle).
func _setup_animations() -> void:
	anim.sprite_frames.set_animation_loop("attack", false)
	anim.sprite_frames.set_animation_loop("death", false)


func _physics_process(delta: float) -> void:
	if jugador == null:
		jugador = get_tree().get_first_node_in_group("Jugador") as Node2D

	cooldown_timer = maxf(cooldown_timer - delta, 0.0)

	if not is_on_floor():
		velocity += get_gravity() * GRAVITY_MULT * delta

	match state:
		State.IDLE: _update_idle()
		State.CHASE: _update_chase()
		State.ATTACK: _update_attack(delta)
		State.HURT: _update_hurt(delta)
		State.DEAD: velocity.x = 0.0

	move_and_slide()


func _update_idle() -> void:
	velocity.x = 0.0
	_show_rest_frame()
	if _target_alive() and absf(_to_target().x) <= detection_range:
		state = State.CHASE


func _update_chase() -> void:
	if not _target_alive():
		state = State.IDLE
		return

	var to_target := _to_target()
	if absf(to_target.x) > detection_range * LOSE_TARGET_FACTOR:
		state = State.IDLE
		return

	_face(signf(to_target.x))

	if _can_attack(to_target):
		_start_attack()
	elif absf(to_target.x) > attack_range:
		velocity.x = signf(to_target.x) * move_speed
		_play_walk()
	else:
		# Ya está a distancia de ataque, espera a que termine el cooldown
		velocity.x = 0.0
		_show_rest_frame()


func _can_attack(to_target: Vector2) -> bool:
	return cooldown_timer <= 0.0 \
		and is_on_floor() \
		and absf(to_target.x) <= attack_range \
		and absf(to_target.y) <= VERTICAL_TOLERANCE


func _start_attack() -> void:
	state = State.ATTACK
	hit_done = false
	velocity.x = 0.0

	anim.play("attack")
	var frames := anim.sprite_frames
	attack_time = frames.get_frame_count("attack") / frames.get_animation_speed("attack")


func _update_attack(delta: float) -> void:
	velocity.x = 0.0
	attack_time -= delta

	if not hit_done and anim.animation == "attack" and anim.frame >= hit_frame:
		hit_done = true
		_apply_hit()

	if attack_time <= 0.0:
		cooldown_timer = attack_cooldown
		state = State.CHASE


## Daña a todo lo que tenga take_damage() cuyo hurtbox esté dentro de AreaAttack.
func _apply_hit() -> void:
	for area in attack_area.get_overlapping_areas():
		var target := area.get_parent()
		if target != null and target.has_method("take_damage"):
			target.take_damage(attack_damage, global_position.x)


func _update_hurt(delta: float) -> void:
	knockback_time -= delta
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_FRICTION * delta)
	if knockback_time <= 0.0 and is_on_floor():
		state = State.CHASE


## Lo llama el ataque del jugador (Character._apply_hit).
## source_x (opcional) es la posición X del atacante, para empujar al enemigo en sentido contrario.
func take_damage(amount: float, source_x := NAN) -> void:
	if state == State.DEAD:
		return

	hp -= amount

	var tween := create_tween()
	modulate = Color(1.0, 0.4, 0.4)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)

	if hp <= 0.0:
		_die()
		return

	if not is_nan(source_x):
		var knock_dir := signf(global_position.x - source_x)
		if knock_dir == 0.0:
			knock_dir = 1.0
		velocity = Vector2(KNOCKBACK.x * knock_dir, KNOCKBACK.y)

	# Un golpe interrumpe el ataque en curso
	knockback_time = KNOCKBACK_TIME
	state = State.HURT
	_show_rest_frame()


func _die() -> void:
	state = State.DEAD
	collision_layer = 0

	if jugador != null and jugador.has_method("gain_xp"):
		jugador.gain_xp(xp_reward)

	anim.play("death")
	var frames := anim.sprite_frames
	await get_tree().create_timer(frames.get_frame_count("death") / frames.get_animation_speed("death")).timeout
	queue_free()


## Mira hacia dirección (1.0 derecha, -1.0 izquierda): sprite y área de ataque.
func _face(direction: float) -> void:
	if direction == 0.0:
		return
	facing = direction
	anim.flip_h = (direction < 0.0) if sprite_faces_right else (direction > 0.0)
	attack_area.position.x = attack_base_pos_x * direction
	attack_area.scale.x = attack_base_scale_x * direction


func _play_walk() -> void:
	if anim.animation != "default" or not anim.is_playing():
		anim.play("default")


func _show_rest_frame() -> void:
	if anim.animation != "default":
		anim.animation = "default"
	anim.pause()
	anim.frame = 0


func _target_alive() -> bool:
	return jugador != null and not jugador.get("dead")


func _to_target() -> Vector2:
	return jugador.global_position - global_position