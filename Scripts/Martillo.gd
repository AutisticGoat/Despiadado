extends CollisionShape2D

## NOTA: este script no está asignado a ningún nodo. El daño del martillo lo gestiona
## Character.gd (_update_attack / _apply_hit). Si no piensas usarlo, puedes borrarlo.
##
## Si se asigna a la forma de colisión del área de ataque, la deja activa SOLO desde el
## frame en el que golpea el martillo hasta el final de la animación "Attack".

const HIT_FRAME := 2  # debe coincidir con Character.HIT_FRAME

var anim: AnimatedSprite2D


func _ready() -> void:
	# Estructura esperada: Jugador > AreaAttack > CollisionShape2D (este nodo)
	var player := get_parent().get_parent() if get_parent() is Area2D else get_parent()
	anim = player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _process(_delta: float) -> void:
	if anim == null:
		return
	var golpeando := anim.animation == "Attack" and anim.frame >= HIT_FRAME
	set_deferred("disabled", not golpeando)
