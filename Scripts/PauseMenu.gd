extends CanvasLayer
class_name PauseMenu

## Menú de pausa: Esc / P / Start (Options en el DualSense) pausa y reanuda el juego.
## Se agrega como un nodo CanvasLayer en el nivel; la interfaz se crea por código.

const ACTION := "pause"
const MAIN_MENU_SCENE := "res://Menu.tscn"
const BUTTON_SIZE := Vector2(160.0, 40.0)

var overlay: Control
var resume_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue funcionando con el juego pausado
	layer = 100
	_setup_input_action()
	_build_ui()
	overlay.hide()


func _setup_input_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)

	for key in [KEY_ESCAPE, KEY_P]:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key
		InputMap.action_add_event(ACTION, key_event)

	var button_event := InputEventJoypadButton.new()
	button_event.button_index = JOY_BUTTON_START
	InputMap.action_add_event(ACTION, button_event)


func _build_ui() -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title := Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)

	resume_button = _add_button(box, "Reanudar", toggle_pause)
	_add_button(box, "Reiniciar", _on_restart_pressed)
	_add_button(box, "Menú principal", _on_main_menu_pressed)


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION) and not event.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	overlay.visible = paused
	if paused:
		resume_button.grab_focus()


## Reinicia el nivel actual desde cero.
func _on_restart_pressed() -> void:
	get_tree().paused = false  # la pausa sobrevive al cambio de escena si no se quita
	get_tree().reload_current_scene()


## Vuelve a la pantalla de inicio.
func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
