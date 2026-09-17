extends Sprite2D

@onready var flash_rect: ColorRect = $ColorRect

func flash_smooth() -> void:
	flash_rect.visible = true
	flash_rect.modulate.a = 1.0 # Fully solid color
	
	var tween = create_tween()
	# Smoothly fade the color block alpha to 0 over 0.2 seconds
	tween.tween_property(flash_rect, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): flash_rect.visible = false)
