extends Node2D

class_name LevelState

signal goo_count_changed(count: int)
signal accomplished()
signal failed()

var _goo_count: int = 100

func set_goo_count(count: int) -> void:
    _goo_count = count
    goo_count_changed.emit(count)
    
func on_goo_collected() -> void:
    set_goo_count(_goo_count - 1)
    
    if _goo_count == 0:
        accomplished.emit()

func on_player_died() -> void:    
    failed.emit()
