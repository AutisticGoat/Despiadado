extends Resource
class_name Stat

## Recurso genérico que representa UNA estadística (velocidad, daño, ataque, etc).
## Se pueden crear archivos .tres a partir de este recurso, o instanciarlo por código.

## Identificador único de la stat, se usa como key en StatsComponent (ej: "speed", "attack")
@export var id: String = ""

## Nombre legible para mostrar en UI (ej: "Velocidad")
@export var display_name: String = ""

## Valor base, sin modificadores aplicados
@export var base_value: float = 0.0

## Valor mínimo y máximo permitidos (clamp). Si min == max, no se aplica clamp.
@export var min_value: float = 0.0
@export var max_value: float = 0.0

# Modificadores activos: cada uno es un Dictionary { "source": String, "type": "flat"/"percent", "value": float }
var _modifiers: Array[Dictionary] = []


func get_final_value() -> float:
	var flat_sum := 0.0
	var percent_sum := 0.0

	for mod in _modifiers:
		if mod.type == "flat":
			flat_sum += mod.value
		elif mod.type == "percent":
			percent_sum += mod.value

	var result := (base_value + flat_sum) * (1.0 + percent_sum)

	if max_value > min_value:
		result = clampf(result, min_value, max_value)

	return result


func add_modifier(source: String, type: String, value: float) -> void:
	_modifiers.append({ "source": source, "type": type, "value": value })


func remove_modifiers_from_source(source: String) -> void:
	_modifiers = _modifiers.filter(func(mod): return mod.source != source)


func clear_modifiers() -> void:
	_modifiers.clear()