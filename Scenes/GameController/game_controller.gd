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
