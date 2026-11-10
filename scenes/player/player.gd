@tool
extends CharacterBody2D

class_name Player

var _base_speed: float = 60.0
var _base_turn_speed: float = 1.0
var _base_movement_cost: float = 0.01  # per pixel

var speed: float = _base_speed
var turn_speed: float = _base_turn_speed
var movement_cost: float = _base_movement_cost

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

@export var battery: float = 100.0
var max_battery: float = 100.0

var _active_effects: Array[PlayerEffect] = []

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
    amount = clamp(amount, 0.0, max_battery)

    if battery > 0.0 and amount == 0.0:
        died.emit()

    battery = amount
    battery_changed.emit(amount)

func add_effect(effect: PlayerEffect) -> void:
    _active_effects.append(effect)
    _recompute_stats()

func remove_effect(effect: PlayerEffect) -> void:
    _active_effects.erase(effect)
    _recompute_stats()

func drain_battery(amount: float) -> void:
    _set_battery(battery - amount)

func heal_battery(amount: float) -> void:
    _set_battery(battery + amount)

func _recompute_stats() -> void:
    var mc := 1.0
    var sp := 1.0
    var ts := 1.0
    for e in _active_effects:
        mc *= e.movement_cost_multiplier
        sp *= e.speed_multiplier
        ts *= e.turn_speed_multiplier
    movement_cost = _base_movement_cost * mc
    speed = _base_speed * sp
    turn_speed = _base_turn_speed * ts

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
        for e in _active_effects:
            cost += e.battery_drain_per_second * delta
        _set_battery(battery - cost)

    # region Flicker if drain    
    var extra_drain := 0.0
    for e in _active_effects:
        extra_drain += e.battery_drain_per_second
    
    if extra_drain > 0.0:
        var t = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
        sprite_2d.modulate = Color(0.3 + 0.7 * t, 0.3 + 0.7 * t, 0.3 + 0.7 * t, 1.0)
    else:
        sprite_2d.modulate = Color(1.0, 1.0, 1.0, 1.0)
    # endregion
