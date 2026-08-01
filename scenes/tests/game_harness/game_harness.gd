extends Node2D

## Make a harness for testing individual levels with keyboard instead of camera.
##
## This makes the tests much more comfortable for the tester instead of moving
## all the time.

@export var scene_level_paths: Array[String] = [
    "res://scenes/levels/playground/playground.tscn",
    "res://scenes/levels/roundabout/roundabout.tscn",
    "res://scenes/levels/pit/pit.tscn",
    "res://scenes/tests/levels/test_laser_gate/test_laser_gate.tscn",
    "res://scenes/tests/levels/test_recharge_pad/test_recharge_pad.tscn",
    "res://scenes/tests/levels/test_robot/test_robot.tscn",
    "res://scenes/tests/levels/test_rotating_fireballs/test_rotating_fireballs.tscn",
    "res://scenes/tests/levels/test_spark_field/test_spark_field.tscn",
    "res://scenes/tests/levels/test_static_wall/test_static_wall.tscn",
    "res://scenes/tests/levels/test_switch_gate/test_switch_gate.tscn",
    "res://scenes/tests/levels/test_villain/test_villain.tscn",
];

@onready var select_level: OptionButton = $SelectLevel

func _ready() -> void:
    for scene_level_path in scene_level_paths:
        if not FileAccess.file_exists(scene_level_path):
            push_error(
                "The scene level path could not be accessed: %s" % scene_level_path
            )
            continue

        select_level.add_item(scene_level_path)
        
    
func _on_play_pressed() -> void:
    var selected_index = select_level.get_selected_id()

    if selected_index >= 0 and selected_index < scene_level_paths.size():
        var path = scene_level_paths[selected_index]        
    
        var keyboard_controller: GameController = load(
            "res://scenes/keyboard_controller/keyboard_controller.tscn"
        ).instantiate()    

        var game: Game = load("res://scenes/game/game.tscn").instantiate()
        
        game.own_game_controllers([keyboard_controller])

        game.level_scene_paths = [path]
        
        get_tree().root.add_child(game)
        queue_free()
