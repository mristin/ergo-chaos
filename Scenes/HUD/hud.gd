extends Control

class_name Hud

@onready var goo_count: Label = $GooCount

@onready var player_a_battery: ProgressBar = $PlayerABattery
@onready var player_b_battery: ProgressBar = $PlayerBBattery


func on_goo_count_changed(count: int) -> void:
    goo_count.text = str(count)

func on_player_a_battery_changed(amount: float) -> void:
    player_a_battery.value = amount
    
func on_player_b_battery_changed(amount: float) -> void:
    player_b_battery.value = amount
