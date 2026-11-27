extends Control

const GAME_SCENE := "res://node_2d.tscn"
const MAX_CONFIRM_WAIT := 0.6  # segundos máximos que se espera al sonido antes de cambiar de escena

@onready var btn_jugar: Button = $VBoxContainer/Iniciar
@onready var btn_opciones: Button = $VBoxContainer/Opciones
@onready var btn_salir: Button = $VBoxContainer/Salir

@onready var sfx_Confirmar: AudioStreamPlayer2D = $SFXConfirmar
@onready var sfx_Seleccionar: AudioStreamPlayer2D = $SFXSelección

var buttons: Array[Button] = []


func _ready() -> void:
	buttons = [btn_jugar, btn_opciones, btn_salir]

	btn_jugar.pressed.connect(_on_jugar_pressed)
	btn_opciones.pressed.connect(_on_opciones_pressed)
	btn_salir.pressed.connect(_on_salir_pressed)

	# El primer botón empieza seleccionado (antes de conectar el sonido, para que no suene al abrir)
	btn_jugar.grab_focus()

	for btn in buttons:
		btn.focus_entered.connect(sfx_Seleccionar.play)


func _on_jugar_pressed() -> void:
	await _play_confirm_and_wait()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_opciones_pressed() -> void:
	sfx_Confirmar.play()
	print("Opciones")  # pendiente: pantalla de opciones


func _on_salir_pressed() -> void:
	await _play_confirm_and_wait()
	get_tree().quit()


## Reproduce el sonido de confirmar y espera a que termine (como mucho MAX_CONFIRM_WAIT),
## bloqueando los botones para que no se pueda pulsar dos veces.
func _play_confirm_and_wait() -> void:
	for btn in buttons:
		btn.disabled = true
	sfx_Confirmar.play()

	var wait := MAX_CONFIRM_WAIT
	if sfx_Confirmar.stream != null:
		wait = minf(sfx_Confirmar.stream.get_length(), MAX_CONFIRM_WAIT)
	await get_tree().create_timer(wait).timeout
