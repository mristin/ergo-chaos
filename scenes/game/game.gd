extends Node2D

class_name Game

const _GAME_FINISHED_IMAGE: Texture2D = preload("res://assets/images/game_finished.png")
const _MISSION_FAILED_IMAGE: Texture2D = preload("res://assets/images/mission_failed.png")
const _MISSION_ACCOMPLISHED_IMAGE: Texture2D = preload("res://assets/images/mission_accomplished.png")

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

## How many players play. 0 asks them first with the player-count dialogue;
## callers such as the test harness can set 1 or 2 to skip it.
var player_count: int = 0

## A single player can not hold a switch-gate pad and fly through the gate at
## the same time, so in one-player games the gate stays open this long.
const _SOLO_SWITCH_GATE_HOLD_SECONDS := 10.0

var _game_controllers: Array[GameController] = []

func own_game_controllers(controllers: Array[GameController]) -> void:
    # Take ownership of the game controllers and include them in this scene.
    _game_controllers = controllers    

func _ready() -> void:
    for controller in _game_controllers:
        add_child(controller)

    if player_count == 0:
        _ask_player_count()
    else:
        _start(player_count)


func _ask_player_count() -> void:
    for controller in _game_controllers:
        controller.use_dialog_layout()

    # NOTE: The dialogue lives in the Screen so that set_level() clears it, and
    # the controllers stay in the tree. Removing the ergo meter from the tree
    # would stop its hand tracking.
    var dialog: PlayerCountDialog = load(
        "res://scenes/player_count/player_count.tscn"
    ).instantiate()
    dialog.watch(_game_controllers)
    dialog.chosen.connect(_start)
    screen.add_child(dialog)


func _start(count: int) -> void:
    player_count = clampi(count, 1, 2)
    for controller in _game_controllers:
        controller.set_player_count(player_count)
        controller.use_game_layout()

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

    var solo := player_count == 1
    if solo:
        # Remove the second ship before the level enters the tree, so that
        # nothing in the level ever sees it.
        scene.remove_child(player_b)
        player_b.free()
        player_b = null

        for node in scene.find_children("*", "", true, false):
            if node.has_method("set_hold_open_seconds"):
                node.set_hold_open_seconds(_SOLO_SWITCH_GATE_HOLD_SECONDS)

    for game_controller in _game_controllers:        
        game_controller.player_a_left_speed_updated.connect(player_a.set_left_engine)
        game_controller.player_a_right_speed_updated.connect(player_a.set_right_engine)
        if not solo:
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

    var player_cameras := [[player_a, camera_a]]
    if solo:
        # One player gets the whole screen.
        var container_a: SubViewportContainer = game_screen.get_node("SubViewportContainerA")
        container_a.size = Vector2(1920, 1080)
        subviewport_a.size = Vector2i(1920, 1080)
        game_screen.get_node("SubViewportContainerB").visible = false
        subviewport_b.render_target_update_mode = SubViewport.UPDATE_DISABLED
        game_screen.get_node("Seam").visible = false
    else:
        player_cameras.append([player_b, camera_b])

    for player_camera in player_cameras:
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
    if not solo:
        player_b.died.connect(level_state.on_player_died)
    # endregion
    
    # region Wire up HUD
    var hud: Hud = game_screen.get_node("Hud")

    hud.set_player_count(player_count)
    hud.set_goo_count(goo_count)
    level_state.goo_count_changed.connect(hud.on_goo_count_changed)
    
    player_a.battery_changed.connect(hud.on_player_a_battery_changed)
    if not solo:
        player_b.battery_changed.connect(hud.on_player_b_battery_changed)
    # endregion
    
    # region Wire up the level transition        
    var final_message_scene: PackedScene = load(
        "res://scenes/final_message/final_message.tscn"
    ) 
    
    level_state.failed.connect(func():
        var final_message: FinalMessage = final_message_scene.instantiate()
        game_screen.add_child(final_message)
        final_message.set_image(_MISSION_FAILED_IMAGE)
        final_message.set_countdown_seconds(10)
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
            final_message.set_image(_MISSION_ACCOMPLISHED_IMAGE)
            final_message.done.connect(func():
                get_tree().paused = false
                set_level(level + 1)
            )
        else:
            final_message.set_image(_GAME_FINISHED_IMAGE)
            final_message.set_countdown_seconds(20)
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
        
    if not solo and player_b.z_index <= goo_container.z_index:
        push_error(
            (
                "The z-index of player B is below the goo container " +
                "on the level %s."
            ) % scene_path
        )
    # endregion
    
