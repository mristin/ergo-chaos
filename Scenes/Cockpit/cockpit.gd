extends Node2D

signal player_a_left_speed_updated(normalized_speed: float)
signal player_a_right_speed_updated(normalized_speed: float)
signal player_b_left_speed_updated(normalized_speed: float)
signal player_b_right_speed_updated(normalized_speed: float)

@onready var ergo_ski: Node2D = $ErgoSki
@onready var speedometer_a_left: Node2D = $SpeedometerALeft
@onready var speedometer_a_right: Node2D = $SpeedometerARight
@onready var speedometer_b_left: Node2D = $SpeedometerBLeft
@onready var speedometer_b_right: Node2D = $SpeedometerBRight

@onready var screen: Node2D = $Screen

func _ready() -> void:
    ergo_ski.PlayerSpeedUpdated.connect(_on_player_speed_updated)

    set_game("res://Scenes/Playground/playground.tscn")

func set_game(scene_path: String) -> void:
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
