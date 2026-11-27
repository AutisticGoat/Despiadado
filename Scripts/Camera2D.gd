extends Camera2D

## Temblor de cámara por "trauma": add_trauma(0..1) lo dispara y se desvanece solo.
## La intensidad crece de forma no lineal (trauma ^ trauma_power): golpes pequeños apenas se notan.

@export var decay := 1.5             # cuánto trauma se pierde por segundo
@export var max_offset := Vector2(12.0, 9.0)  # desplazamiento máximo en píxeles
@export var max_roll := 0.03         # rotación máxima en radianes
@export var trauma_power := 2.0      # curva no lineal del temblor
@export var noise_speed := 60.0      # qué tan rápido recorre el ruido (más = temblor más "nervioso")

var trauma := 0.0
var noise := FastNoiseLite.new()
var noise_t := 0.0
var base_offset := Vector2.ZERO      # el offset que tiene la cámara en el editor; el temblor se suma encima


func _ready() -> void:
	base_offset = offset
	ignore_rotation = false          # sin esto, max_roll no tiene efecto
	noise.seed = randi()
	noise.frequency = 0.5


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


func _process(delta: float) -> void:
	if trauma > 0.0:
		trauma = maxf(trauma - decay * delta, 0.0)
		_shake(delta)
	else:
		offset = base_offset
		rotation = 0.0


func _shake(delta: float) -> void:
	var amount := pow(trauma, trauma_power)
	noise_t += delta * noise_speed
	offset = base_offset + Vector2(
		max_offset.x * amount * noise.get_noise_2d(noise_t, 0.0),
		max_offset.y * amount * noise.get_noise_2d(0.0, noise_t))
	rotation = max_roll * amount * noise.get_noise_2d(noise_t, noise_t)
