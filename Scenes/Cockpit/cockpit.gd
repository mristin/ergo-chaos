extends Node2D

signal player_a_left_speed_updated(normalized_speed: float)
signal player_a_right_speed_updated(normalized_speed: float)
signal player_b_left_speed_updated(normalized_speed: float)
signal player_b_right_speed_updated(normalized_speed: float)

# NOTE (mristin):
# We intentionally put ergo ski and the speedometers here and not in the HUD since
# we use the ergo ski controls also for the menus, not just for the gameplay.
@onready var ergo_ski: Node2D = $ErgoSki
@onready var speedometer_a_left: Node2D = $SpeedometerALeft
@onready var speedometer_a_right: Node2D = $SpeedometerARight
@onready var speedometer_b_left: Node2D = $SpeedometerBLeft
@onready var speedometer_b_right: Node2D = $SpeedometerBRight

@onready var screen: Node2D = $Screen

var _camera_feed: CameraFeed = null

func set_camera_feed(feed: CameraFeed) -> void:
    _camera_feed = feed


var level_scene_paths: Array[String] = [
    "res://Scenes/Levels/Playground/playground.tscn",
    "res://Scenes/Levels/Playground2/playground2.tscn",
]

func _ready() -> void:
    ergo_ski.PlayerSpeedUpdated.connect(_on_player_speed_updated)

    if _camera_feed == null:
        push_error("Camera feed must be set before call to _ready on Cockpit.")
    
    ergo_ski.SetCameraFeed(_camera_feed)

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

    player_a_left_speed_updated.connect(player_a.set_left_engine)
    player_a_right_speed_updated.connect(player_a.set_right_engine)
    player_b_left_speed_updated.connect(player_b.set_left_engine)
    player_b_right_speed_updated.connect(player_b.set_right_engine)
    # endregion

    # region Set up cameras
    for child in screen.get_children():
        screen.remove_child(child)
        child.queue_free()

    var game_screen: Node2D = load(
        "res://Scenes/GameScreen/game_screen.tscn"
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
        "res://Scenes/LevelState/level_state.tscn"
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
        "res://Scenes/FinalMessage/final_message.tscn"
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
    
    
func _on_player_speed_updated(player: String, hand: String, normalized_speed: float) -> void:
    match [player, hand]:
        ["A", "Left"]:
            speedometer_a_left.set_needle(normalized_speed)
            player_a_left_speed_updated.emit(normalized_speed)
        ["A", "Right"]:
            speedometer_a_right.set_needle(normalized_speed)
            player_a_right_speed_updated.emit(normalized_speed)
        ["B", "Left"]:
            speedometer_b_left.set_needle(normalized_speed)
            player_b_left_speed_updated.emit(normalized_speed)
        ["B", "Right"]:
            speedometer_b_right.set_needle(normalized_speed)
            player_b_right_speed_updated.emit(normalized_speed)
