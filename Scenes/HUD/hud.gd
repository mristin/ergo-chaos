extends Control

class_name Hud

@onready var goo_count: Label = $GooCount


func on_goo_count_changed(count: int):
    goo_count.text = str(count)
