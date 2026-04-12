@tool
extends Node2D

@export var needle_color: Color = Color.WHITE : set = _set_needle_color

@onready var needle: Line2D = $Needle

@onready var needle_fixed_point: Vector2 = needle.points[0]
@onready var needle_length: float = needle_fixed_point.distance_to(needle.points[1])

const MIN_ANGLE: float = -PI * 3.0 / 4.0  # -135 degrees
const MAX_ANGLE: float = PI * 3.0 / 4.0   # 135 degrees


func _ready():
    _update_needle_color()
    set_needle(0.0)


func _set_needle_color(color: Color):
    needle_color = color
    _update_needle_color()


func _update_needle_color():
    if needle != null:
        needle.default_color = needle_color


func set_needle(value: float):
    # Clamp value to [0, 1] range
    value = clamp(value, 0.0, 1.0)

    var angle: float = lerp(MIN_ANGLE, MAX_ANGLE, value)

    var needle_end_point: Vector2 = needle_fixed_point + Vector2(
        needle_length * sin(angle),
        needle_length * -cos(angle)
    )

    needle.set_point_position(0, needle_fixed_point)
    needle.set_point_position(1, needle_end_point)
