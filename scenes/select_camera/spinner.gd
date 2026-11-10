extends Control

class_name Spinner

@export var rotation_speed: float = 4.0  # radians per second
@export var line_width: float = 6.0
@export var arc_color: Color = Color(1, 1, 1)
## Fraction of the arc to draw, 1.0 = full sweep, 0.0 = nothing. Lets the
## spinner double as a countdown ring when driven via `set_progress()`.
@export_range(0.0, 1.0) var progress: float = 1.0

var _angle: float = 0.0

func set_progress(value: float) -> void:
    progress = clamp(value, 0.0, 1.0)
    queue_redraw()

func _process(delta: float) -> void:
    _angle = wrapf(_angle + rotation_speed * delta, 0.0, TAU)
    queue_redraw()

func _draw() -> void:
    var center := size / 2.0
    var radius: float = min(size.x, size.y) / 2.0 - line_width
    draw_arc(center, radius, _angle, _angle + TAU * 0.75 * progress, 32, arc_color, line_width, true)
