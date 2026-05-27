@tool
extends Area2D

@export var width: float = 400.0

const _PAD_X_INSET: float = 48.0
const _PAD_Y_OFFSET: float = 154.0

@onready var _lightning: ColorRect = $HitShape/Lightning
@onready var _hit_shape: CollisionShape2D = $HitShape
@onready var _left_post: LaserPost = $LeftPost
@onready var _right_post: LaserPost = $RightPost
@onready var _front_pad = $FrontPad
@onready var _back_pad = $BackPad

var _players_on_pads: int = 0
var _player_effects: Dictionary = {}

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
    var rect := _hit_shape.shape as RectangleShape2D
    if rect != null:
        rect.size.x = max(0.0, width - 36.0)
    _sync_lightning_to_hit_shape()
    _front_pad.position = Vector2(-half + _PAD_X_INSET, -_PAD_Y_OFFSET)
    _back_pad.position = Vector2(half - _PAD_X_INSET, _PAD_Y_OFFSET)

func _ready() -> void:
    _sync_width()
    if Engine.is_editor_hint():
        return
    _front_pad.on_enter.connect(_on_pad_enter)
    _front_pad.on_leave.connect(_on_pad_leave)
    _back_pad.on_enter.connect(_on_pad_enter)
    _back_pad.on_leave.connect(_on_pad_leave)
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    _apply_state()

func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        _sync_width()

func _apply_state() -> void:
    var gate_open := _players_on_pads > 0
    
    # NOTE (mristin):
    # Changing monitoring state during a physics callback (body_entered/exited) crashes;
    # set_deferred defers the shape toggle until after the physics step.
    _hit_shape.set_deferred("disabled", gate_open)
    
    _lightning.visible = not gate_open
    
    if gate_open:
        _left_post.set_green()
        _right_post.set_green()
    else:
        _left_post.set_red()
        _right_post.set_red()
    
    if gate_open:
        for body in _player_effects:
            body.remove_effect(_player_effects[body])
        _player_effects.clear()
    else:
        # NOTE (mristin):
        # The body_entered may not re-fire for players already inside when the shape
        # is re-enabled, so scan manually after the deferred enable settles.
        call_deferred("_zap_overlapping_players")

func _on_pad_enter() -> void:
    _players_on_pads += 1
    _apply_state()

func _on_pad_leave() -> void:
    _players_on_pads = maxi(_players_on_pads - 1, 0)
    _apply_state()

func _on_body_entered(body: Node2D) -> void:
    if not (body is Player) or body in _player_effects:
        return
        
    var effect := PlayerEffect.new()
    effect.battery_drain_per_second = 7.0
    body.add_effect(effect)
    _player_effects[body] = effect

func _on_body_exited(body: Node2D) -> void:
    if body not in _player_effects:
        return

    body.remove_effect(_player_effects[body])
    _player_effects.erase(body)

func _zap_overlapping_players() -> void:
    for body in get_overlapping_bodies():
        _on_body_entered(body)
