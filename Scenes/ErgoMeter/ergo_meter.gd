extends GameController

class_name ErgoMeter

@onready var ergo_ski: Node2D = $ErgoSki
@onready var speedometer_a_left: Node2D = $SpeedometerALeft
@onready var speedometer_a_right: Node2D = $SpeedometerARight
@onready var speedometer_b_left: Node2D = $SpeedometerBLeft
@onready var speedometer_b_right: Node2D = $SpeedometerBRight

var _camera_feed: CameraFeed = null

func set_camera_feed(feed: CameraFeed) -> void:
    _camera_feed = feed

func _ready() -> void:
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
