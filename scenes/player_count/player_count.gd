extends Node2D

class_name PlayerCountDialog

## Ask how many skiers play: one, or two side by side.
##
## The camera picture is shown large in the middle, split like the game: the
## left half flies the red ship, the right half the blue one. Whoever swings
## their arms fills up their half. As soon as one half is full, we count the
## halves which are at least three quarters full: one skier or two. The keys 1
## and 2 work, too. The hand tracking gives the hands of a single skier to one
## player only (see HandDetector), so a hand over the middle does not count as
## a second skier.
##
## The dialogue does not own the camera picture: the ergo meter draws it on top
## (see ErgoMeter.use_dialog_layout()), so we only draw the background below it
## and the tints and bars above it.

signal chosen(count: int)

const _SWING_THRESHOLD := 0.15
const _FILL_SECONDS := 2.0
const _DRAIN_SECONDS := 1.5
const _RESULT_SECONDS := 1.5

## The second skier counts only if their half is this full when the first fills
## up; strict, so that a single skier with a hand over the middle stays one.
const _SECOND_SKIER_CHARGE := 0.75

## Must match ErgoMeter._DIALOG_CAMERA_* (320x240 picture, scaled 3x).
const _CAMERA_RECT := Rect2(480, 220, 960, 720)

const _RED := Color(1.0, 0.25, 0.2)
const _BLUE := Color(0.2, 0.45, 1.0)

var _speeds := [0.0, 0.0, 0.0, 0.0]  # A left, A right, B left, B right
var _charge := [0.0, 0.0]  # A, B
var _chosen := false

var _tints: Array[ColorRect] = []
var _bars: Array[ColorRect] = []
var _result: Label


func watch(controllers: Array[GameController]) -> void:
    for controller in controllers:
        controller.player_a_left_speed_updated.connect(func(v: float) -> void: _speeds[0] = v)
        controller.player_a_right_speed_updated.connect(func(v: float) -> void: _speeds[1] = v)
        controller.player_b_left_speed_updated.connect(func(v: float) -> void: _speeds[2] = v)
        controller.player_b_right_speed_updated.connect(func(v: float) -> void: _speeds[3] = v)


func _ready() -> void:
    _build()


func _build() -> void:
    var background := ColorRect.new()
    background.size = Vector2(1920, 1080)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var space := ShaderMaterial.new()
    space.shader = load("res://scenes/levels/common/deep_space.gdshader")
    space.set_shader_parameter("halo_strength", 0.0)
    space.set_shader_parameter("nebula_color_a", Color(0.35, 0.08, 0.45))
    space.set_shader_parameter("nebula_color_b", Color(0.03, 0.2, 0.4))
    background.material = space
    add_child(background)

    _add_label("How many skiers?", Vector2(0, 40), 84, Color.WHITE)
    _add_label(
        "Stand in front of the camera and swing your arms like a skier!",
        Vector2(0, 150), 40, Color(0.85, 0.9, 1.0)
    )
    _add_label(
        "Swing alone for one skier, or together for two.   Keys 1 and 2 work, too.",
        Vector2(0, 1015), 30, Color(0.7, 0.75, 0.9)
    )

    for i in 2:
        var color: Color = _RED if i == 0 else _BLUE
        var center_x := 240.0 if i == 0 else 1680.0

        var ship := Sprite2D.new()
        ship.texture = load(
            "res://assets/images/spaceship_red.png" if i == 0
            else "res://assets/images/spaceship_blue.png"
        )
        ship.position = Vector2(center_x, 520)
        ship.scale = Vector2(3, 3)
        add_child(ship)

        var name_label := _add_label(
            "Red ship" if i == 0 else "Blue ship",
            Vector2(center_x - 240, 640), 40, color
        )
        name_label.size.x = 480

    # Tints and bars are drawn above the camera picture.
    var overlay := Node2D.new()
    overlay.z_as_relative = false
    overlay.z_index = 5
    add_child(overlay)

    for i in 2:
        var color: Color = _RED if i == 0 else _BLUE
        var half := Rect2(
            _CAMERA_RECT.position + Vector2(_CAMERA_RECT.size.x / 2.0 * i, 0),
            Vector2(_CAMERA_RECT.size.x / 2.0, _CAMERA_RECT.size.y)
        )
        var tint := ColorRect.new()
        tint.position = half.position
        tint.size = half.size
        tint.color = Color(color, 0.0)
        tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
        overlay.add_child(tint)
        _tints.append(tint)

        var track := ColorRect.new()
        track.position = Vector2(half.position.x + 10, _CAMERA_RECT.end.y + 18)
        track.size = Vector2(half.size.x - 20, 30)
        track.color = Color(1, 1, 1, 0.15)
        track.mouse_filter = Control.MOUSE_FILTER_IGNORE
        overlay.add_child(track)

        var bar := ColorRect.new()
        bar.position = track.position
        bar.size = Vector2(0, track.size.y)
        bar.color = color
        bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
        overlay.add_child(bar)
        _bars.append(bar)

    _result = _add_label("", Vector2(0, 470), 140, Color.WHITE)
    _result.reparent(overlay)
    _result.z_index = 1


func _add_label(text: String, at: Vector2, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.position = at
    label.size = Vector2(1920, font_size * 1.4)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_outline_color", Color(0, 0, 0.05))
    label.add_theme_constant_override("outline_size", maxi(4, font_size / 8))
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(label)
    return label


func _process(delta: float) -> void:
    if _chosen:
        return

    for i in 2:
        var swinging: bool = maxf(_speeds[2 * i], _speeds[2 * i + 1]) > _SWING_THRESHOLD
        if swinging:
            _charge[i] = minf(1.0, _charge[i] + delta / _FILL_SECONDS)
        else:
            _charge[i] = maxf(0.0, _charge[i] - delta / _DRAIN_SECONDS)

        _tints[i].color.a = 0.05 + 0.35 * _charge[i]
        _bars[i].size.x = (_CAMERA_RECT.size.x / 2.0 - 20) * _charge[i]

    if _charge[0] >= 1.0 or _charge[1] >= 1.0:
        var both: bool = _charge[0] >= _SECOND_SKIER_CHARGE and _charge[1] >= _SECOND_SKIER_CHARGE
        _choose(2 if both else 1)


func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed and not event.echo):
        return
    match event.keycode:
        KEY_1, KEY_KP_1:
            _choose(1)
        KEY_2, KEY_KP_2:
            _choose(2)


func _choose(count: int) -> void:
    if _chosen:
        return
    _chosen = true
    _result.text = "One skier!" if count == 1 else "Two skiers!"
    await get_tree().create_timer(_RESULT_SECONDS).timeout
    chosen.emit(count)
