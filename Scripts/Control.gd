extends Control

@onready var btn_jugar: Button = $VBoxContainer/Iniciar
@onready var btn_opciones: Button = $VBoxContainer/Opciones
@onready var btn_salir: Button = $VBoxContainer/Salir

@onready var sfx_Confirmar: AudioStreamPlayer2D = $SFXConfirmar
@onready var sfx_Seleccionar: AudioStreamPlayer2D = $SFXSelección

func _ready() -> void:
	btn_jugar.pressed.connect(_on_jugar_pressed)
	btn_opciones.pressed.connect(_on_opciones_pressed)
	btn_salir.pressed.connect(_on_salir_pressed)

	# El primer botón empieza seleccionado
	btn_jugar.grab_focus()

	for btn in [btn_jugar, btn_opciones, btn_salir]:
		btn.focus_entered.connect(sfx_Seleccionar.play)
		btn.pressed.connect(sfx_Confirmar.play)


func _on_jugar_pressed() -> void:
	print("Jugar")


func _on_opciones_pressed() -> void:
	print("Opciones")


func _on_salir_pressed() -> void:
	get_tree().quit()
