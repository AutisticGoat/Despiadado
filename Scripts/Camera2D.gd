extends Camera2D

@export var decay := 0.8  # Speeding up the fade out
@export var max_offset := Vector2(100, 75)  # Max horizontal/vertical shake in pixels
@export var max_roll := 0.1  # Max rotation in radians
@export var trauma_power := 2.0  # Multiplier for non-linear shake curve

var trauma := 0.0
var noise := FastNoiseLite.new()
var noise_y := 0

func _ready() -> void:
    randomize()
    noise.seed = randi()
    noise.frequency = 0.5

func add_trauma(amount: float) -> void:
    trauma = min(trauma + amount, 1.0)

func _process(delta: float) -> void:
    if trauma > 0:
        trauma = max(trauma - decay * delta, 0)
        shake()
    else:
        offset = Vector2.ZERO
        rotation = 0

func shake() -> void:
    var amt = pow(trauma, trauma_power)
    noise_y += 1
    # Smooth noise-based offsets
    offset.x = max_offset.x * amt * noise.get_noise_2d(noise_y, 0)
    offset.y = max_offset.y * amt * noise.get_noise_2d(0, noise_y)
    rotation = max_roll * amt * noise.get_noise_2d(noise_y, noise_y)
