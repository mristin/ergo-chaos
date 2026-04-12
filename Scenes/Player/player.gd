@tool
extends CharacterBody2D

class_name Player

var speed: float = 60.0
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

var battery: float = 100.0
var max_battery: float = 100.0

var movement_cost: float = 0.02  # per pixel

signal battery_changed(battery: float)
signal died()

func _ready() -> void:
    _update_sprite_texture()

func set_left_engine(power: float) -> void:
    _left_engine_power = clamp(power, 0.0, 1.0)

func set_right_engine(power: float) -> void:
    _right_engine_power = clamp(power, 0.0, 1.0)

func _update_sprite_texture() -> void:
    if sprite_2d != null and texture != null:
        sprite_2d.texture = texture

func _set_battery(amount: float) -> void:
    if amount <= 0.0:
        amount = 0.0
        
    if battery > 0.0 and amount == 0.0:
        died.emit()
    
    battery = amount
    battery_changed.emit(amount)


func _physics_process(delta: float) -> void:
    if battery > 0.0:
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

        var old_position: Vector2 = position
        move_and_slide()
        
        var cost = (position - old_position).length() * movement_cost
        _set_battery(battery - cost)        
