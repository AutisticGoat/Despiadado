extends Node
class_name ExperienceComponent

## Experiencia y nivel de una entidad. No sabe qué recompensas da subir de nivel:
## quien lo use se conecta a leveled_up.

signal xp_changed
signal leveled_up(new_level: int)

@export var base_xp := 10.0   # XP necesaria para pasar del nivel 1 al 2
@export var growth := 1.2     # qué tan rápido crece la XP necesaria por nivel
@export var max_level := 30

var level := 1
var xp := 0


## XP necesaria para pasar del nivel actual al siguiente.
func xp_needed() -> int:
	return roundi(base_xp * pow(level, growth))


func is_max_level() -> bool:
	return level >= max_level


func add_xp(amount: int) -> void:
	if amount <= 0 or is_max_level():
		return

	xp += amount
	while not is_max_level() and xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		leveled_up.emit(level)

	if is_max_level():
		xp = 0
	xp_changed.emit()