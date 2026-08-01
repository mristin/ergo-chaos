extends Node2D

class_name Game

@onready var screen: Node2D = $Screen

# Public so harness and other callers can override before _ready runs.
var level_scene_paths: Array[String] = [
    "res://scenes/levels/playground/playground.tscn",
    "res://scenes/levels/roundabout/roundabout.tscn",
    "res://scenes/levels/switcher/switcher.tscn",
    "res://scenes/levels/pit/pit.tscn",
    "res://scenes/levels/chase/chase.tscn",
    "res://scenes/levels/stable/stable.tscn",
]

var _game_controllers: Array[GameController] = []

func own_game_controllers(controllers: Array[GameController]) -> void:
    # Take ownership of the game controllers and include them in this scene.
    _game_controllers = controllers    

func _ready() -> void:
    for controller in _game_controllers:
        add_child(controller)
    
    set_level(0)


func set_level(level: int) -> void:
    assert(level >= 0)
    assert(level < level_scene_paths.size())

    var scene_path = level_scene_paths[level]

    var scene: Node2D = load(scene_path).instantiate()

    # region Wire players to the control
    var player_a: Player = scene.get_node("PlayerA")
    var player_b: Player = scene.get_node("PlayerB")

    if player_a == null:
        push_error("PlayerA not found in loaded scene: %s" % scene_path)
        return

    if player_b == null:
        push_error("PlayerB not found in loaded scene: %s" % scene_path)
        return

    if not player_a is Player:
        push_error("PlayerA is not of type Player in scene: %s" % scene_path)
        return

    if not player_b is Player:
        push_error("PlayerB is not of type Player in scene: %s" % scene_path)
        return

    for game_controller in _game_controllers:        
        game_controller.player_a_left_speed_updated.connect(player_a.set_left_engine)
        game_controller.player_a_right_speed_updated.connect(player_a.set_right_engine)
        game_controller.player_b_left_speed_updated.connect(player_b.set_left_engine)
        game_controller.player_b_right_speed_updated.connect(player_b.set_right_engine)
    # endregion

    # region Set up cameras
    for child in screen.get_children():
        screen.remove_child(child)
        child.queue_free()

    var game_screen: Node2D = load(
        "res://scenes/game_screen/game_screen.tscn"
    ).instantiate()
    screen.add_child(game_screen)
    
    var subviewport_a: SubViewport = game_screen.get_node(
        "SubViewportContainerA/SubViewportA"
    )
    subviewport_a.add_child(scene)
    var camera_a: Camera2D = subviewport_a.get_node("Camera2D")
    
    var subviewport_b: SubViewport = game_screen.get_node(
        "SubViewportContainerB/SubViewportB"
    )
    var camera_b: Camera2D = subviewport_b.get_node("Camera2D") 
    
    subviewport_b.world_2d = subviewport_a.world_2d
    
    for player_camera in [[player_a, camera_a], [player_b, camera_b]]:
        var player = player_camera[0]
        var camera = player_camera[1]
        
        var remote_transform = RemoteTransform2D.new()
        remote_transform.remote_path = camera.get_path()
        player.add_child(remote_transform)
    
    # endregion
    
    # region Set up level state    
    var level_state: LevelState = load(
        "res://scenes/level_state/level_state.tscn"
    ).instantiate()
    
    var goo_container = scene.get_node("GooContainer")
    for child in goo_container.get_children():
        var goo: Goo = child
        goo.collected.connect(level_state.on_goo_collected)
    
    var goo_count: int = goo_container.get_children().size()
    
    level_state.set_goo_count(goo_count)
    
    player_a.died.connect(level_state.on_player_died)
    player_b.died.connect(level_state.on_player_died)
    # endregion
    
    # region Wire up HUD
    var hud: Hud = game_screen.get_node("Hud")

    hud.set_goo_count(goo_count)
    level_state.goo_count_changed.connect(hud.on_goo_count_changed)
    
    player_a.battery_changed.connect(hud.on_player_a_battery_changed)
    player_b.battery_changed.connect(hud.on_player_b_battery_changed)
    # endregion
    
    # region Wire up the level transition        
    var final_message_scene: PackedScene = load(
        "res://scenes/final_message/final_message.tscn"
    ) 
    
    level_state.failed.connect(func():
        var final_message: FinalMessage = final_message_scene.instantiate()        
        game_screen.add_child(final_message)
        final_message.set_message(
            "You failed, but you will make it the next time 💪!"
        )
        get_tree().paused = true
        
        final_message.done.connect(func():
            get_tree().paused = false
            set_level(level)
        )
    )
    
    level_state.accomplished.connect(func():
        var final_message: FinalMessage = final_message_scene.instantiate()
        game_screen.add_child(final_message)
        get_tree().paused = true

        if level < level_scene_paths.size() - 1:                        
            final_message.set_message("Mission accomplished 🚀")
            final_message.done.connect(func():
                get_tree().paused = false
                set_level(level + 1)
            )
        else:
            # TODO: go to the dialogue: Do you want to play again? Yes/No
            final_message.set_message("You cleaned everything! Bravo! 🎉 🥳 🎉")
            final_message.done.connect(func():
                get_tree().paused = false
                set_level(0)
            )            
    )    
    # endregion
    
    # region Assert Player z-order correct
    if player_a.z_index <= goo_container.z_index:
        push_error(
            (
                "The z-index of player A is below the goo container " +
                "on the level %s."
            ) % scene_path
        )
        
    if player_b.z_index <= goo_container.z_index:
        push_error(
            (
                "The z-index of player B is below the goo container " +
                "on the level %s."
            ) % scene_path
        )
    # endregion
    
