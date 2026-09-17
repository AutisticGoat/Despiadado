extends Sprite2D

@onready var flash_rect: ColorRect = $ColorRect

func flash(duration: float = 0.15) -> void:
	# Make the color fill visible
	flash_rect.visible = true
	
	# Create a quick timer/tween to turn it off
	await get_tree().create_timer(duration).timeout
	
	# Hide the color fill to return to normal
	flash_rect.visible = false
