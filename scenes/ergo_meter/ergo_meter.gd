extends GameController

class_name ErgoMeter

@onready var ergo_ski: Node2D = $ErgoSki
@onready var speedometer_a_left: Node2D = $SpeedometerALeft
@onready var speedometer_a_right: Node2D = $SpeedometerARight
@onready var speedometer_b_left: Node2D = $SpeedometerBLeft
@onready var speedometer_b_right: Node2D = $SpeedometerBRight

var _camera_feed: CameraFeed = null

## Where the camera picture goes in the player-count dialogue: large, centred.
const _DIALOG_CAMERA_POSITION := Vector2(480, 220)
const _DIALOG_CAMERA_SCALE := 3.0

var _game_camera_position: Vector2
var _game_camera_scale: Vector2
var _player_count: int = 2

func set_camera_feed(feed: CameraFeed) -> void:
    _camera_feed = feed

func _ready() -> void:
    _game_camera_position = ergo_ski.position
    _game_camera_scale = ergo_ski.scale

    ergo_ski.PlayerSpeedUpdated.connect(_on_player_speed_updated)

    assert(
        _camera_feed != null, 
        "Camera feed must be set before call to _ready."
    )    
    
    ergo_ski.SetCameraFeed(_camera_feed)

func _on_player_speed_updated(
    player: String, 
    hand: String, 
    normalized_speed: float
) -> void:
    # NOTE (mristin):
    # We keep the ErgoSki implementation general since we copy/pasted it from:
    # https://github.com/mristin/body-pose-estimation-with-godot.
    # Otherwise, this code could be refactored to match our design.
    
    match [player, hand]:
        ["A", "Left"]:
            speedometer_a_left.set_needle(normalized_speed)
            player_a_left_speed_updated.emit(normalized_speed)
        ["A", "Right"]:
            speedometer_a_right.set_needle(normalized_speed)
            player_a_right_speed_updated.emit(normalized_speed)
        ["B", "Left"]:
            speedometer_b_left.set_needle(normalized_speed)
            player_b_left_speed_updated.emit(normalized_speed)
        ["B", "Right"]:
            speedometer_b_right.set_needle(normalized_speed)
            player_b_right_speed_updated.emit(normalized_speed)


func set_player_count(count: int) -> void:
    _player_count = count
    ergo_ski.SetPlayerCount(count)
    speedometer_b_left.visible = count == 2
    speedometer_b_right.visible = count == 2


func use_dialog_layout() -> void:
    ergo_ski.position = _DIALOG_CAMERA_POSITION
    ergo_ski.scale = Vector2.ONE * _DIALOG_CAMERA_SCALE
    for speedometer in _speedometers():
        speedometer.visible = false


func use_game_layout() -> void:
    ergo_ski.position = _game_camera_position
    ergo_ski.scale = _game_camera_scale
    speedometer_a_left.visible = true
    speedometer_a_right.visible = true
    speedometer_b_left.visible = _player_count == 2
    speedometer_b_right.visible = _player_count == 2


func _speedometers() -> Array[Node2D]:
    return [speedometer_a_left, speedometer_a_right, speedometer_b_left, speedometer_b_right]
