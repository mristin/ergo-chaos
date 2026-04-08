extends Node2D

@onready var ergo_ski: Node2D = $ErgoSki
@onready var speedometer_a_left: Node2D = $SpeedometerALeft
@onready var speedometer_a_right: Node2D = $SpeedometerARight
@onready var speedometer_b_left: Node2D = $SpeedometerBLeft
@onready var speedometer_b_right: Node2D = $SpeedometerBRight

func _ready() -> void:
    ergo_ski.PlayerSpeedUpdated.connect(_on_player_speed_updated)


func _on_player_speed_updated(player: String, hand: String, normalized_speed: float) -> void:
    match [player, hand]:
        ["A", "Left"]:
            speedometer_a_left.set_needle(normalized_speed)
        ["A", "Right"]:
            speedometer_a_right.set_needle(normalized_speed)
        ["B", "Left"]:
            speedometer_b_left.set_needle(normalized_speed)
        ["B", "Right"]:
            speedometer_b_right.set_needle(normalized_speed)
