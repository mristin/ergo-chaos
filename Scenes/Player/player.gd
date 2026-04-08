@tool
extends CharacterBody2D

class_name Player

var speed: float = 30.0
var turn_speed: float = 1.0

@onready var sprite_2d: Sprite2D = $Sprite2D

@export var texture: Texture2D:
    set(value):
        texture = value
        _update_sprite_texture()

var _left_engine_power: float = 0.0
var _right_engine_power: float = 0.0

var left_engine_power: float:
    get:
        return _left_engine_power

var right_engine_power: float:
    get:
        return _right_engine_power

func _ready() -> void:
    _update_sprite_texture()

func set_left_engine(power: float) -> void:
    _left_engine_power = clamp(power, 0.0, 1.0)

func set_right_engine(power: float) -> void:
    _right_engine_power = clamp(power, 0.0, 1.0)

func _update_sprite_texture() -> void:
    if sprite_2d != null and texture != null:
        sprite_2d.texture = texture

# NOTE (mristin):
# We leave this function here for manual debugging of the behavior.
# Usually, you can call it from _process.
func react_to_keys(_delta: float) -> void:
    if Input.is_key_pressed(KEY_Q):
        set_left_engine(1.0)
    elif Input.is_key_pressed(KEY_A):
        set_left_engine(0.5)
    elif Input.is_key_pressed(KEY_Z):
        set_left_engine(0.0)

    if Input.is_key_pressed(KEY_W):
        set_right_engine(1.0)
    elif Input.is_key_pressed(KEY_S):
        set_right_engine(0.5)
    elif Input.is_key_pressed(KEY_X):
        set_right_engine(0.0)

func _physics_process(delta: float) -> void:
    var engine_average = (_left_engine_power + _right_engine_power) * 0.5
    var engine_difference = _right_engine_power - _left_engine_power

    # The turning is based on engine difference.
    if engine_difference != 0:
        rotation += engine_difference * turn_speed * delta

    # The forward movement is based on average engine power.
    if engine_average > 0:
        velocity = Vector2.UP.rotated(rotation) * speed * engine_average
    else:
        velocity = Vector2.ZERO

    move_and_slide()
