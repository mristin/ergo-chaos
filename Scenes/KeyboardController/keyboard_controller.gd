extends GameController

# Control the players by keyboard. This is used for debugging purposes only and
# the controller is usually not used in the games.

func _process(_delta: float) -> void:
    if Input.is_key_pressed(KEY_Q):
        player_a_left_speed_updated.emit(1.0)        
    elif Input.is_key_pressed(KEY_A):
        player_a_left_speed_updated.emit(0.5)
    elif Input.is_key_pressed(KEY_Z):
        player_a_left_speed_updated.emit(0.0)

    elif Input.is_key_pressed(KEY_W):
        player_a_right_speed_updated.emit(1.0)
    elif Input.is_key_pressed(KEY_S):
        player_a_right_speed_updated.emit(0.5)
    elif Input.is_key_pressed(KEY_X):
        player_a_right_speed_updated.emit(0.0)
    
    elif Input.is_key_pressed(KEY_I):
        player_b_left_speed_updated.emit(1.0)        
    elif Input.is_key_pressed(KEY_J):
        player_b_left_speed_updated.emit(0.5)
    elif Input.is_key_pressed(KEY_N):
        player_b_left_speed_updated.emit(0.0)

    elif Input.is_key_pressed(KEY_O):
        player_b_right_speed_updated.emit(1.0)
    elif Input.is_key_pressed(KEY_K):
        player_b_right_speed_updated.emit(0.5)
    elif Input.is_key_pressed(KEY_M):
        player_b_right_speed_updated.emit(0.0)
    
