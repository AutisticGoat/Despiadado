extends Label

@export var Stats: StatsComponent


func _ready() -> void:
	# El HP actual vive en el jugador (padre del StatsComponent)
	var jugador: Node = Stats.get_parent()
	if jugador.has_signal("hp_changed"):
		jugador.connect("hp_changed", _on_hp_changed)
	else:
		var max_hp := Stats.get_value("healthpoints")
		_on_hp_changed(max_hp, max_hp)


func _on_hp_changed(current: float, maximum: float) -> void:
	# Redondeo hacia arriba: con 0.3 de vida se muestra 1, nunca 0 mientras el jugador sigue vivo
	text = "HP: %d / %d" % [ceili(current), ceili(maximum)]