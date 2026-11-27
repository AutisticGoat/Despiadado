extends Label
class_name XpLabel

const POSITION := Vector2(1.0, 48.0)  # debajo de la etiqueta de Velocidad (y=25, alto 23)

var _experience: ExperienceComponent


func setup(experience: ExperienceComponent) -> void:
	_experience = experience
	position = POSITION
	experience.xp_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if _experience.is_max_level():
		text = "Nv. %d (MAX)" % _experience.level
	else:
		text = "Nv. %d  XP %d/%d" % [_experience.level, _experience.xp, _experience.xp_needed()]