extends Node2D

class_name GameController
## Define an abstract game controller such that we can have ergo ski, keyboard, etc.

@warning_ignore("unused_signal")
signal player_a_left_speed_updated(normalized_speed: float)

@warning_ignore("unused_signal")
signal player_a_right_speed_updated(normalized_speed: float)

@warning_ignore("unused_signal")
signal player_b_left_speed_updated(normalized_speed: float)

@warning_ignore("unused_signal")
signal player_b_right_speed_updated(normalized_speed: float)

## Tell the controller how many players play (1 or 2).
func set_player_count(_count: int) -> void:
    pass

## Arrange the controller's visuals for the player-count dialogue.
func use_dialog_layout() -> void:
    pass

## Arrange the controller's visuals for playing a level.
func use_game_layout() -> void:
    pass
