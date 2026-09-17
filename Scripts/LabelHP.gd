extends Label

@export var Stats: StatsComponent

func _ready() -> void:
	Stats.stat_changed.connect(_on_stat_changed)
	_update_text(Stats.get_value("healthpoints"))  # valor inicial

func _on_stat_changed(id: String, new_value: float) -> void:
	if id == "healthpoints":
		_update_text(new_value)

func _update_text(value: float) -> void:
	text = "HP: %.0f" % value
