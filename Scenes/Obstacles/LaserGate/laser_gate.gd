@tool
extends Area2D

@export var green_time: float = 1.0; # in seconds
@export var yellow_time: float = 1.0; # in seconds
@export var red_time: float = 10.0; # in seconds
@export var width: float = 400.0  # distance between the two post centers

var light_textures: Array[Texture2D] = [
    preload("res://Assets/Images/green-light.png"),
    preload("res://Assets/Images/yellow-light.png"),
    preload("res://Assets/Images/red-light.png"),
]

enum State { GREEN, YELLOW, RED }

var _state: State = State.GREEN
var _elapsed: float = 0.0

@onready var _lightning: ColorRect = $HitShape/Lightning
@onready var _hit_shape: CollisionShape2D = $HitShape
@onready var _left_post: Sprite2D = $Sprite2D
@onready var _right_post: Sprite2D = $Sprite2D2
@onready var _left_light: Sprite2D = $LeftLight
@onready var _right_light: Sprite2D = $RightLight

var _player_effects: Dictionary = {}  # Player -> PlayerEffect

func _sync_lightning_to_hit_shape() -> void:
    var rect := _hit_shape.shape as RectangleShape2D
    if rect == null:
        return
    _lightning.size = rect.size
    _lightning.position = -rect.size / 2.0

func _sync_width() -> void:
    var half := width / 2.0
    _left_post.position.x = -half
    _right_post.position.x = half
    _left_light.position.x = -half
    _right_light.position.x = half
    var rect := _hit_shape.shape as RectangleShape2D
    if rect != null:
        rect.size.x = max(0.0, width - 36.0)
    _sync_lightning_to_hit_shape()

func _ready() -> void:
    _sync_width()
    if Engine.is_editor_hint():
        return
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    _apply_state()

func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        _sync_width()

func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return
    _elapsed += delta
    var duration := _state_duration(_state)
    if _elapsed >= duration:
        _elapsed -= duration
        _state = _next_state(_state)
        _apply_state()

func _state_duration(s: State) -> float:
    match s:
        State.GREEN: return green_time
        State.YELLOW: return yellow_time
        State.RED: return red_time
    push_error("Unexpected state: %d" % s)
    return 0.0

func _next_state(s: State) -> State:
    match s:
        State.GREEN: return State.YELLOW
        State.YELLOW: return State.RED
        State.RED: return State.GREEN
    push_error("Unexpected state: %d" % s)
    return State.GREEN

func _apply_state() -> void:
    var texture := light_textures[_state]
    $LeftLight.texture = texture
    $RightLight.texture = texture
    $HitShape.disabled = (_state != State.RED)
    _lightning.visible = (_state == State.RED)
    if _state != State.RED:
        for body in _player_effects:
            body.remove_effect(_player_effects[body])
        _player_effects.clear()

func _on_body_entered(body: Node2D) -> void:
    if not (body is Player) or body in _player_effects:
        return
    var effect := PlayerEffect.new()
    effect.battery_drain_per_second = 0.5
    body.add_effect(effect)
    _player_effects[body] = effect

func _on_body_exited(body: Node2D) -> void:
    if body not in _player_effects:
        return
    body.remove_effect(_player_effects[body])
    _player_effects.erase(body)
