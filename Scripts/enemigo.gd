extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var jugador = get_tree().get_first_node_in_group("Jugador")
@onready var Anim = $AnimatedSprite2D

var waitFrames = 0
var dir = 0
var rng = RandomNumberGenerator.new()

func _physics_process(delta: float) -> void:	
	if waitFrames > 0:
		waitFrames = waitFrames - 1
		
	if waitFrames == 1:
		dir = -1 if rng.randf() > 0.5 else 1
	
	if waitFrames == 0:
		velocity.y = -100 * 5
		waitFrames = 60

	print(abs(jugador.position.x - position.x))

	if (abs(jugador.position.x - position.x)) <= 50:
		print(position.direction_to(jugador.position).x)
		
		print("Jugador cerca de enemigo, iniciando retirada")
		dir = -position.direction_to(jugador.position).x

	if not is_on_floor():
		velocity.y += get_gravity().y * 5 * delta
		velocity.x = dir * 200
	else:
		velocity.x = 0
	# elif waitFrames == 0:
	# 	velocity.x = 0
	
	


	# if Anim.frame == 3:
	# 	Anim.Stomp



	# # Handle jump.
	# if Input.is_action_just_pressed("ui_accept") and is_on_floor():
	# 	velocity.y = JUMP_VELOCITY

	# # Get the input direction and handle the movement/deceleration.
	# # As good practice, you should replace UI actions with custom gameplay actions.
	# var direction := Input.get_axis("ui_left", "ui_right")
	# if direction:
	# 	velocity.x = direction * SPEED
	# else:
	# 	velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
