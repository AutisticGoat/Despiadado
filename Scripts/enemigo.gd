extends CharacterBody2D

const AIR_SPEED := 200.0
const JUMP_VELOCITY := -500.0
const GRAVITY_MULT := 5.0
const JUMP_INTERVAL := 1.0      # segundos entre saltos
const FLEE_DISTANCE := 50.0     # distancia al jugador que dispara la retirada
const KNOCKBACK := Vector2(350.0, -250.0)  # empuje al recibir un golpe (X se orienta según el atacante)
const KNOCKBACK_TIME := 0.25    # segundos sin control de la IA tras un golpe
const STUN_TIME := 0.5          # pausa mínima antes del siguiente salto tras un golpe

# Frames de la animación "default" (índices desde 0)
const FRAME_IDLE := 0           # en el suelo
const FRAME_JUMP := 1           # subiendo
const FRAME_FALL := 3           # cayendo

# Capas de colisión: 1 = mundo, 2 = cuerpo del jugador, 3 = enemigos, 4 = hurtbox del jugador
const LAYER_WORLD := 1
const LAYER_ENEMY := 4          # valor de bits de la capa 3
const LAYER_HURTBOX := 8        # valor de bits de la capa 4

# Colores de debug (Debug > Visible Collision Shapes)
const COLOR_BODY := Color(0.2, 0.9, 0.3, 0.4)       # cuerpo del slime: verde
const COLOR_CONTACT := Color(1.0, 0.0, 1.0, 0.4)    # área de contacto: magenta

@export var max_hp := 3.0
@export var contact_damage := 2.0
@export var xp_reward := 5

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var jugador: Node2D
var hp := 0.0
var dir := 0.0
var jump_timer := 0.0
var knockback_time := 0.0
var contact_area: Area2D
var is_dead = false

func _ready() -> void:
	hp = max_hp
	jugador = get_tree().get_first_node_in_group("Jugador") as Node2D

	# El slime choca con el suelo y con otros slimes, pero atraviesa al jugador
	collision_layer = LAYER_ENEMY
	collision_mask = LAYER_WORLD | LAYER_ENEMY
	($CollisionShape2D as CollisionShape2D).debug_color = COLOR_BODY
	_create_contact_area()

	# "death" se reproduce una sola vez, para que emita animation_finished al terminar
	anim.sprite_frames.set_animation_loop("death", false)

	# Los frames se controlan a mano según la velocidad vertical
	anim.animation = "default"
	anim.pause()
	_update_animation()


## Área de contacto (copia del collider del slime) que detecta la hurtbox del jugador.
func _create_contact_area() -> void:
	var body_shape := $CollisionShape2D as CollisionShape2D

	var area_shape := CollisionShape2D.new()
	area_shape.shape = body_shape.shape
	area_shape.position = body_shape.position
	area_shape.scale = body_shape.scale
	area_shape.debug_color = COLOR_CONTACT

	contact_area = Area2D.new()
	contact_area.collision_layer = 0
	contact_area.collision_mask = LAYER_HURTBOX
	contact_area.add_child(area_shape)
	add_child(contact_area)


func _physics_process(delta: float) -> void:
	if is_dead:
		_update_dead(delta)
		return

	if jugador == null:
		jugador = get_tree().get_first_node_in_group("Jugador") as Node2D

	jump_timer = maxf(jump_timer - delta, 0.0)
	knockback_time = maxf(knockback_time - delta, 0.0)

	var away := 0.0
	if jugador != null and absf(jugador.global_position.x - global_position.x) <= FLEE_DISTANCE:
		away = -signf(jugador.global_position.x - global_position.x)

	if is_on_floor():
		if knockback_time <= 0.0:
			velocity.x = 0.0
			if jump_timer <= 0.0:
				dir = away if away != 0.0 else (-1.0 if randf() > 0.5 else 1.0)
				velocity.y = JUMP_VELOCITY
				jump_timer = JUMP_INTERVAL
	else:
		velocity.y += get_gravity().y * GRAVITY_MULT * delta
		if knockback_time <= 0.0:
			if away != 0.0:
				dir = away
			velocity.x = dir * AIR_SPEED

	move_and_slide()
	_update_animation()
	_check_contact_damage()


## Muerto: sigue cayendo hasta el suelo y frena en horizontal, sin IA ni daño por contacto.
func _update_dead(delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * GRAVITY_MULT * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, AIR_SPEED * 4.0 * delta)
	move_and_slide()


## En Godot, velocity.y < 0 es hacia ARRIBA (saltando) y velocity.y > 0 es hacia ABAJO (cayendo).
func _update_animation() -> void:
	if is_on_floor():
		anim.frame = FRAME_IDLE
	elif velocity.y < 0.0:
		anim.frame = FRAME_JUMP
	else:
		anim.frame = FRAME_FALL


func _check_contact_damage() -> void:
	for area in contact_area.get_overlapping_areas():
		var target := area.get_parent()
		if target != null and target.has_method("take_damage"):
			target.take_damage(contact_damage, global_position.x)


## Lo llaman el ataque del jugador (Character._apply_hit)
## source_x (opcional) es la posición X del atacante, para empujar al slime en sentido contrario.
func take_damage(amount: float, source_x := NAN) -> void:
	if is_dead: return  # evita dar la XP más de una vez

	hp -= amount

	if not is_nan(source_x):
		var knock_dir := signf(global_position.x - source_x)
		if knock_dir == 0.0:
			knock_dir = 1.0
		dir = knock_dir  # al terminar el empuje sigue en el mismo sentido, sin tirones
		velocity = Vector2(KNOCKBACK.x * knock_dir, KNOCKBACK.y)
		knockback_time = KNOCKBACK_TIME
		jump_timer = maxf(jump_timer, STUN_TIME)

	var tween := create_tween()
	modulate = Color(1.0, 0.4, 0.4)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)

	if hp > 0.0: return
	is_dead = true

	# El cadáver deja de ser sólido para los demás slimes y el martillo, pero sigue chocando con el suelo
	collision_layer = 0
	collision_mask = LAYER_WORLD
	contact_area.set_deferred("monitoring", false)

	if jugador != null and jugador.has_method("gain_xp"):
		jugador.gain_xp(xp_reward)

	# Se elimina al terminar la animación de muerte, dure lo que dure
	anim.play("death")
	await anim.animation_finished
	queue_free()
