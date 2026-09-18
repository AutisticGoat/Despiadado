extends CollisionShape2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# print(get_parent())
	var player = get_parent() 
	var anim = player.get_node("AnimatedSprite2D")

	if anim.animation == "Attack" and anim.frame == 2:
		disabled = true
	else:
		disabled = false

	# print("Collider habilitado: ", disabled)

	pass
