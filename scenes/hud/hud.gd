extends Control

class_name Hud

@onready var goo_count: Label = $GooCount
@onready var _goo_icon: Sprite2D = $GooIcon
@onready var _goo_tank: ColorRect = $GooTank

## The goo of the level, set by the first count.
var _total_goo: int = 0
var _shown_level: float = 0.0
var _target_level: float = 0.0
var _splash: float = 0.0
var _icon_scale: Vector2
var _pop_tween: Tween

@onready var player_a_battery: ProgressBar = $PlayerABattery
@onready var player_b_battery: ProgressBar = $PlayerBBattery

## Hide the second battery when only one player plays and keep the rest centred.
func set_player_count(count: int) -> void:
    player_b_battery.visible = count == 2
    if count == 1:
        # Battery A and the goo tank span 0..590; centre them on the screen.
        position.x = 960.0 - 590.0 / 2.0

func _ready() -> void:
    _icon_scale = _goo_icon.scale

## Show how many goo are left; the first call sets the goo of the level.
func set_goo_count(count: int) -> void:
    if _total_goo == 0 or count > _total_goo:
        _total_goo = count
    goo_count.text = str(count)
    _target_level = 1.0 - float(count) / float(maxi(_total_goo, 1))

func on_goo_count_changed(count: int) -> void:
    set_goo_count(count)
    _pop()

## Splash the tank, punch the number and bounce the icon.
func _pop() -> void:
    _splash = 1.0
    if _pop_tween != null:
        _pop_tween.kill()
    goo_count.scale = Vector2.ONE * 1.45
    _goo_icon.scale = _icon_scale * 1.35
    _pop_tween = create_tween().set_parallel(true)
    _pop_tween.tween_property(goo_count, "scale", Vector2.ONE, 0.45) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    _pop_tween.tween_property(_goo_icon, "scale", _icon_scale, 0.5) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
    # The level rises smoothly, and the splash dies down.
    _shown_level = move_toward(_shown_level, _target_level, delta * 0.8)
    _splash = maxf(0.0, _splash - delta * 1.1)
    var material := _goo_tank.material as ShaderMaterial
    material.set_shader_parameter("level", _shown_level)
    material.set_shader_parameter("splash", _splash)

func on_player_a_battery_changed(amount: float) -> void:
    player_a_battery.value = amount
    
func on_player_b_battery_changed(amount: float) -> void:
    player_b_battery.value = amount
