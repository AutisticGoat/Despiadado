extends CharacterBody2D

const SPEED_FACTOR := 20.0   # multiplicador de la stat "speed" -> px/s
const JUMP_FORCE := 400.0    # se multiplica por la stat "jumpheight"
const JUMP_CUT := 0.5        # al soltar el botón en el ascenso, la velocidad vertical se multiplica por esto
const COYOTE_TIME := 0.1     # segundos en los que aún se puede saltar tras salir de un borde
const JUMP_BUFFER_TIME := 0.12  # segundos que se recuerda un salto pulsado antes de tocar el suelo
const SHAKE_ON_HIT := 0.35   # temblor de cámara al golpear a un enemigo (0..1)
const SHAKE_ON_HURT := 0.6   # temblor de cámara al recibir daño (0..1)
const GRAVITY_MULT := 1.5    # ~1470 px/s² con la gravedad 2D por defecto (980)
const HIT_FRAME := 2         # frame del ataque en el que el martillo golpea
const DEFENSE_SCALE := 100.0 # daño recibido = daño * 100 / (100 + defensa)
const INVULN_TIME := 1.0     # segundos de invulnerabilidad tras recibir un golpe
const KNOCKBACK := Vector2(300.0, -250.0)
const KNOCKBACK_TIME := 0.2  # segundos sin control horizontal tras un golpe
const RESPAWN_DELAY := 0.8
const STICK_DEADZONE := 0.3     # zona muerta del stick (evita el drift del mando)
const DEBUG_MIN_SPEED := 1.0    # velocidad mínima a la que se puede bajar con la tecla "-"

# Bonos por nivel: stat -> valor plano por cada nivel ganado
const LEVEL_SOURCE := "level"
const LEVEL_BONUSES := {
	"healthpoints": 5.0,
	"damage": 0.5,
	"defense": 1.0,
}

# Capas de colisión: 1 = mundo, 2 = cuerpo del jugador, 3 = enemigos, 4 = hurtbox del jugador
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_HURTBOX := 8
const HURTBOX_SIZE := Vector2(9.0, 14.0)

# Colores de debug (Debug > Visible Collision Shapes)
const COLOR_BODY := Color(0.0, 0.6, 0.7, 0.35)      # cuerpo: cian
const COLOR_ATTACK := Color(1.0, 0.8, 0.0, 0.45)    # martillo: amarillo
const COLOR_HURTBOX := Color(1.0, 0.1, 0.1, 0.65)   # hurtbox: rojo

signal hp_changed(current: float, maximum: float)
signal died

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var stats: StatsComponent = $StatsComponent
@onready var area_attack: Area2D = $AreaAttack
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var camera: Camera2D = get_node_or_null("Camera2D") as Camera2D

var step1 = preload("res://sfx/Step1.wav")
var step2 = preload("res://sfx/Step2.wav")
var step3 = preload("res://sfx/Step3.wav")
var hammerSwing = preload("res://sfx/HammerSwing.wav")
var hammerHit = preload("res://sfx/HammerHit.wav")

var attacking := false
var hit_done := false
var attack_time := 0.0
var debug_speed_bonus := 0.0
var attack_base_pos_x := 0.0    # posición X del área tal como la dejaste en el editor (mirando a la derecha)
var attack_base_scale_x := 1.0  # escala X del área en el editor
var hurtbox: Area2D
var experience: ExperienceComponent
var hp := 0.0
var dead := false
var invuln_time := 0.0
var knockback_time := 0.0
var step_player: AudioStreamPlayer2D  # reproductor propio para los pasos (no corta los sonidos del martillo)
var last_step_frame := -1             # último frame de "Walking" que ya sonó
var coyote_timer := 0.0
var jump_buffer_timer := 0.0


func _ready() -> void:
	_setup_input_actions()
	_setup_collisions()
	_setup_step_player()
	attack_base_pos_x = area_attack.position.x
	attack_base_scale_x = absf(area_attack.scale.x)

	# Bonos de prueba (misma fuente "debug" para poder quitarlos limpiamente)
	stats.add_modifier("healthpoints", "debug", "flat", 10)
	stats.add_modifier("jumpheight", "debug", "flat", 0.5)

	hp = stats.get_value("healthpoints")
	stats.stat_changed.connect(_on_stat_changed)
	hp_changed.emit(hp, hp)

	_setup_experience()


## Segundo reproductor, con el mismo volumen y bus que el principal, solo para los pasos.
func _setup_step_player() -> void:
	step_player = AudioStreamPlayer2D.new()
	step_player.name = "StepPlayer"
	step_player.volume_db = audio_player.volume_db
	step_player.bus = audio_player.bus
	add_child(step_player)


func _setup_experience() -> void:
	# Usa el componente de la escena (así sus valores del Inspector cuentan); solo lo crea si no existe
	experience = get_node_or_null("ExperienceComponent") as ExperienceComponent
	if experience == null:
		experience = ExperienceComponent.new()
		experience.name = "ExperienceComponent"
		add_child(experience)
	experience.leveled_up.connect(_on_leveled_up)

	var canvas := get_node_or_null("CanvasLayer")
	if canvas != null:
		var label := XpLabel.new()
		canvas.add_child(label)
		label.setup(experience)


## Lo llaman los enemigos al morir.
func gain_xp(amount: int) -> void:
	experience.add_xp(amount)


func _on_leveled_up(new_level: int) -> void:
	for stat_id in LEVEL_BONUSES:
		stats.remove_modifiers_from_source(stat_id, LEVEL_SOURCE)
		stats.add_modifier(stat_id, LEVEL_SOURCE, "flat", LEVEL_BONUSES[stat_id] * (new_level - 1))

	# Cura completa al subir de nivel
	hp = stats.get_value("healthpoints")
	hp_changed.emit(hp, hp)


## Configura capas/máscaras y la hurtbox por código (crea la hurtbox si la escena no la tiene).
func _setup_collisions() -> void:
	collision_layer = LAYER_PLAYER
	collision_mask = LAYER_WORLD

	area_attack.collision_layer = 0
	area_attack.collision_mask = LAYER_ENEMY

	hurtbox = get_node_or_null("Hurtbox") as Area2D
	if hurtbox == null:
		hurtbox = Area2D.new()
		hurtbox.name = "Hurtbox"
		var shape := RectangleShape2D.new()
		shape.size = HURTBOX_SIZE
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = body_shape.position
		hurtbox.add_child(col)
		add_child(hurtbox)
	hurtbox.collision_layer = LAYER_HURTBOX
	hurtbox.collision_mask = 0

	_set_debug_color(body_shape, COLOR_BODY)
	_set_debug_color(area_attack, COLOR_ATTACK)
	_set_debug_color(hurtbox, COLOR_HURTBOX)


## Aplica el color a un CollisionShape2D, o a los de un Area2D.
func _set_debug_color(node: Node, color: Color) -> void:
	var single := node as CollisionShape2D
	if single != null:
		single.debug_color = color
		return
	for child in node.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node != null:
			shape_node.debug_color = color


func _on_stat_changed(id: String, new_value: float) -> void:
	if id == "healthpoints":
		hp = minf(hp, new_value)
		hp_changed.emit(hp, new_value)


## Lo llaman los enemigos. source_x (opcional) es la posición X del atacante, para el empuje.
func take_damage(amount: float, source_x := NAN) -> void:
	if dead or invuln_time > 0.0:
		return

	var defense := stats.get_value("defense")
	var dmg := amount * DEFENSE_SCALE / (DEFENSE_SCALE + defense)
	hp = maxf(hp - dmg, 0.0)
	hp_changed.emit(hp, stats.get_value("healthpoints"))
	_shake_camera(SHAKE_ON_HURT)

	if hp <= 0.0:
		_die()
		return

	invuln_time = INVULN_TIME
	if not is_nan(source_x):
		var knock_dir := signf(global_position.x - source_x)
		if knock_dir == 0.0:
			knock_dir = 1.0
		velocity = Vector2(KNOCKBACK.x * knock_dir, KNOCKBACK.y)
		knockback_time = KNOCKBACK_TIME


## Lo llama la zona de muerte (KillZone) cuando el jugador cae fuera del mapa.
func fall_out() -> void:
	if dead:
		return
	hp = 0.0
	hp_changed.emit(hp, stats.get_value("healthpoints"))
	_die()


func _die() -> void:
	dead = true
	died.emit()
	velocity = Vector2.ZERO
	anim.modulate = Color(1.0, 0.3, 0.3)
	# process_always = false: el temporizador se detiene mientras el juego está en pausa,
	# así la escena no se recarga con la pausa activa (lo que dejaba el juego congelado)
	await get_tree().create_timer(RESPAWN_DELAY, false).timeout
	get_tree().reload_current_scene()


## Registra las acciones de input por código si no existen en el Input Map.
## Mando pensado para DualSense (PS5): Godot lo expone con el layout estándar
## (Cruz = JOY_BUTTON_A, Círculo = B, Cuadrado = X, Triángulo = Y).
func _setup_input_actions() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], -1.0)
	_add_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], 1.0)
	_add_action("jump", [KEY_Z, KEY_SPACE], [JOY_BUTTON_A])      # Cruz
	_add_action("attack", [KEY_X], [JOY_BUTTON_X])               # Cuadrado


## stick_direction: -1.0 / 1.0 asigna el stick izquierdo (eje X) en ese sentido; 0.0 no lo usa.
func _add_action(action: String, keys: Array, buttons: Array, stick_direction := 0.0) -> void:
	if InputMap.has_action(action):
		return

	InputMap.add_action(action, STICK_DEADZONE)

	for key in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key
		InputMap.action_add_event(action, key_event)

	for button in buttons:
		var button_event := InputEventJoypadButton.new()
		button_event.button_index = button
		InputMap.action_add_event(action, button_event)

	if stick_direction != 0.0:
		var motion_event := InputEventJoypadMotion.new()
		motion_event.axis = JOY_AXIS_LEFT_X
		motion_event.axis_value = stick_direction
		InputMap.action_add_event(action, motion_event)


## Debug: "+" y "-" suben/bajan la velocidad. Un solo modificador, sin acumular.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return

	if key.keycode == KEY_EQUAL:
		debug_speed_bonus += 1.0
	elif key.keycode == KEY_MINUS:
		# No deja bajar la velocidad de DEBUG_MIN_SPEED (con 0 el jugador no se mueve y la animación se congela)
		var current := stats.get_value("speed")
		if current - 1.0 < DEBUG_MIN_SPEED:
			return
		debug_speed_bonus -= 1.0
	else:
		return

	stats.remove_modifiers_from_source("speed", "debug")
	stats.add_modifier("speed", "debug", "flat", debug_speed_bonus)


func _physics_process(delta: float) -> void:
	if dead:
		return

	if invuln_time > 0.0:
		invuln_time -= delta
		anim.modulate.a = 1.0 if invuln_time <= 0.0 or int(invuln_time * 12.0) % 2 == 1 else 0.35
	knockback_time = maxf(knockback_time - delta, 0.0)

	var speed := stats.get_value("speed")
	var jump_height := stats.get_value("jumpheight")
	var direction := Input.get_axis("move_left", "move_right")

	if not is_on_floor():
		velocity += get_gravity() * GRAVITY_MULT * delta

	# Coyote time: tras salir de un borde, aún se puede saltar durante COYOTE_TIME
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	# Jump buffer: un salto pulsado justo antes de aterrizar se recuerda durante JUMP_BUFFER_TIME
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	# Salto variable: la altura depende de cuánto mantengas presionado el botón
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0 and knockback_time <= 0.0:
		velocity.y = -JUMP_FORCE * jump_height
		jump_buffer_timer = 0.0
		coyote_timer = 0.0  # evita un segundo salto con el mismo coyote time
		# Si el botón ya se soltó antes de aterrizar (salto guardado en el buffer), es un salto corto
		if not Input.is_action_pressed("jump"):
			velocity.y *= JUMP_CUT
	if Input.is_action_just_released("jump") and velocity.y < 0.0 and knockback_time <= 0.0:
		velocity.y *= JUMP_CUT

	if knockback_time > 0.0:
		pass  # el empuje manda sobre el input
	elif direction != 0.0 and not attacking:
		velocity.x = direction * speed * SPEED_FACTOR
		anim.flip_h = direction < 0.0
		_set_attack_facing(signf(direction))
	elif attacking and not is_on_floor():
		pass  # atacar en el aire conserva el impulso horizontal del salto
	else:
		# Equivale a la fricción original a 60 FPS, pero independiente del framerate
		velocity.x = move_toward(velocity.x, 0.0, speed * SPEED_FACTOR * 60.0 * delta)

	if Input.is_action_pressed("attack") and not attacking:
		_start_attack()
	if attacking:
		_update_attack(delta)

	move_and_slide()
	_update_animation(direction)


## Espeja el área del martillo: su posición y también su contenido (escala).
## facing = 1.0 (derecha) o -1.0 (izquierda). Usa lo que dejaste en el editor como base.
func _set_attack_facing(facing: float) -> void:
	area_attack.position.x = attack_base_pos_x * facing
	area_attack.scale.x = attack_base_scale_x * facing

func _start_attack() -> void:
	attacking = true
	hit_done = false

	var atk_speed := maxf(stats.get_value("attackspeed") + 0.75, 0.1)
	var frames := anim.sprite_frames
	anim.play("Attack", atk_speed)
	attack_time = frames.get_frame_count("Attack") / (frames.get_animation_speed("Attack") * atk_speed)

	audio_player.stream = hammerSwing
	audio_player.play()
	# hammerSwing

func _update_attack(delta: float) -> void:
	attack_time -= delta

	if not hit_done and anim.animation == "Attack" and anim.frame >= HIT_FRAME:
		hit_done = true
		_apply_hit()

	if attack_time <= 0.0:
		attacking = false


## Daña a todo cuerpo dentro de AreaAttack que tenga take_damage()
func _apply_hit() -> void:
	var damage := stats.get_value("damage")
	var hit_any := false
	for body in area_attack.get_overlapping_bodies():
		if body != self and body.has_method("take_damage"):
			body.take_damage(damage, global_position.x)
			hit_any = true

	if hit_any:  # un solo sonido y un solo temblor aunque el martillo alcance a varios enemigos
		audio_player.stream = hammerHit
		audio_player.play()
		_shake_camera(SHAKE_ON_HIT)


func _shake_camera(amount: float) -> void:
	if camera != null and camera.has_method("add_trauma"):
		camera.add_trauma(amount)


var step_sounds = {
	1: step1,
	2: step2,
	3: step3,
}

## Suena un paso una sola vez cada vez que "Walking" ENTRA en el frame 1 o 3.
func ManageStepsSFX() -> void:
	if anim.animation != "Walking":
		last_step_frame = -1
		return
	if anim.frame == last_step_frame:
		return
	last_step_frame = anim.frame
	if not (anim.frame == 1 or anim.frame == 3):
		return

	step_player.stream = step_sounds[randi_range(1, 3)]
	step_player.play()


func _update_animation(direction: float) -> void:
	if attacking:
		return

	if not is_on_floor():
		if anim.animation != "Jump":
			anim.play("Jump")
		anim.pause()
		anim.frame = 3 if velocity.y < 0.0 else 4
	elif direction != 0.0:
		anim.play("Walking", maxf(stats.get_value("speed") / 10.0, 0.1))
	else:
		anim.play("Idle")


	ManageStepsSFX()