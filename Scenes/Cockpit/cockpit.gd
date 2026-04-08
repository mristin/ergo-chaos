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

@onready var current_scene: Container = $CurrentScene
var loaded_scene: Node2D

func _ready() -> void:
    ergo_ski.PlayerSpeedUpdated.connect(_on_player_speed_updated)

    set_playground("res://Scenes/Playground/playground.tscn")

func _set_scene(scene_path: String) -> void:
    if loaded_scene != null:
        loaded_scene.queue_free()
        loaded_scene = null
        
    var scene = load(scene_path).instantiate()
    current_scene.add_child(scene)
    loaded_scene = scene

func set_playground(scene_path: String) -> void:
    _set_scene(scene_path)
    
    var player_a = loaded_scene.get_node("PlayerA")
    var player_b = loaded_scene.get_node("PlayerB")

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
