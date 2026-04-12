extends Node2D

## Make a harness for testing individual levels with keyboard instead of camera.
##
## This makes the tests much more comfortable for the tester instead of moving
## all the time.

@export var scene_level_paths: Array[String] = [
    "res://Scenes/Levels/Playground/playground.tscn",
    "res://Scenes/Levels/Playground2/playground2.tscn",
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
            "res://Scenes/KeyboardController/keyboard_controller.tscn"
        ).instantiate()    

        var game: Game = load("res://Scenes/Game/game.tscn").instantiate()
        
        game.own_game_controllers([keyboard_controller])

        game.level_scene_paths = [path]
        
        get_tree().root.add_child(game)
        queue_free()
