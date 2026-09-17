extends Node
class_name StatsComponent

## Componente genérico y reutilizable de stats.
## Se agrega como hijo a cualquier entidad (Player, Enemy, Item, etc).
## No sabe nada sobre "quién lo usa": solo administra un diccionario de Stat.

## Lista de recursos Stat asignados desde el inspector (arrastrás archivos .tres de tipo Stat)
@export var initial_stats: Array[Stat] = []

## id -> Stat, para acceso O(1) en tiempo de ejecución
var _stats: Dictionary = {}

## Se emite cada vez que una stat cambia de valor final
signal stat_changed(id: String, new_value: float)

func _ready() -> void:
	for stat in initial_stats:
		if stat == null or stat.id.is_empty():
			push_warning("StatsComponent: stat inválida o sin id en %s" % get_parent())
			continue
		_stats[stat.id] = stat.duplicate(true)
	
	print("Stats registradas: ", _stats.keys())  # <-- línea temporal de debug

func has_stat(id: String) -> bool:
	return _stats.has(id)


func get_stat(id: String) -> Stat:
	if not _stats.has(id):
		push_warning("StatsComponent: stat '%s' no existe" % id)
		return null
	return _stats[id]


func get_value(id: String) -> float:
	var stat := get_stat(id)
	return stat.get_final_value() if stat else 0.0


func set_base_value(id: String, value: float) -> void:
	var stat := get_stat(id)
	if stat:
		stat.base_value = value
		stat_changed.emit(id, stat.get_final_value())


func add_modifier(id: String, source: String, type: String, value: float) -> void:
	var stat := get_stat(id)
	if stat:
		stat.add_modifier(source, type, value)
		stat_changed.emit(id, stat.get_final_value())


func remove_modifiers_from_source(id: String, source: String) -> void:
	var stat := get_stat(id)
	if stat:
		stat.remove_modifiers_from_source(source)
		stat_changed.emit(id, stat.get_final_value())


## Útil para registrar stats dinámicamente por código en vez de por inspector
func register_stat(stat: Stat) -> void:
	_stats[stat.id] = stat.duplicate(true)
