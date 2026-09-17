extends CharacterBody2D

@onready var Anim = $AnimatedSprite2D #Nodo hijo 
@onready var Stats = $StatsComponent #Nodo hijo

const MAX_SPEED = 500.0
const ACCELERATION = 1500.0
const FRICTION = 1500.0

var attack_state = false

#Función llamada cuando el nodo es inicializado
func _ready() -> void:
	Stats.add_modifier("healthpoints", "test", "flat", 10)
	Stats.add_modifier("jumpheight", "test", "flat", 2) 

#Función de prueba para ajustar la velocidad del personaje
func SetSpeed(value: float) -> void:
	var mult = 0
	if Input.is_key_pressed(Key.KEY_EQUAL):
		mult = 1
	elif Input.is_key_pressed(Key.KEY_MINUS):
		mult = -1
	
	if mult != 0:
		Stats.add_modifier("speed", "test", "flat", value * mult)


@export var acceleration: float = 3000.0
@export var friction: float = 1200.0
		

func AttackAnimManager(animation: String) -> void:
	if Input.is_key_pressed(Key.KEY_X): 
		attack_state = true

	if attack_state == true:
		if animation != "Attack":
			Anim.stop()
			Anim.play("Attack", 1)

	if (animation == "Attack" and Anim.frame == 2):
		Anim.stop()
		Anim.play("Idle", 1)
		attack_state = false

func NonAttackAnimManager(animation: String) -> void:
	var speed = Stats.get_value("speed")
	
	if animation != "Attack":
		if velocity.x != 0:
			Anim.play("Walking", 1 * (speed / 10))
		else:
			Anim.play("Idle", 1)

func JumpAnimManager() -> void:
	if is_on_floor(): return
	
	var velY = velocity.y

	Anim.play("Jump", 1)

	if velY < 0:
		Anim.frame = 3
	elif velY > 0:
		Anim.frame = 4

# Función llamada cada frame, delta es el tiempo que ha pasado desde el frame anterior
func _process(delta: float) -> void:	
	SetSpeed(1)

	var animation = Anim.animation

	NonAttackAnimManager(animation)
	AttackAnimManager(animation)
	JumpAnimManager()
	
var gravedad = ProjectSettings.get_setting("physics/3d/default_gravity")

const VELOCIDAD = 20
const FUERZA_SALTO = 50

#función llamada cada frame relacionado con físicas, delta es el tiempo que ha pasado desde el frame anterior
func _physics_process(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
	var jumpheight = Stats.get_value("jumpheight")
	var speed = Stats.get_value("speed")
	var target_speed = direction * speed

	if not is_on_floor():
		velocity.y += gravedad * 150 * delta

	if Input.is_key_pressed(Key.KEY_Z) and is_on_floor():
		velocity.y = -FUERZA_SALTO * 8 * jumpheight

	if direction:
		velocity.x = target_speed * VELOCIDAD

		if Anim.animation == "Idle":
			Anim.stop()
		Anim.flip_h = true if velocity.x < 0 else false
	else:
		velocity.x = move_toward(velocity.x, 0, VELOCIDAD * speed)

	move_and_slide()

func _on_animated_sprite_2d_animation_finished() -> void:
	pass # Replace with function body.
