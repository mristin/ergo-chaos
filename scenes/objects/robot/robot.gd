extends CharacterBody2D

class_name Robot

## A wandering NPC that roams the level at random like a panzer: it turns its
## whole chassis towards a target heading and always drives forward along its
## current facing, steering away from anything a forward-looking raycast hits
## that is not a Player, and shoving the player aside on contact.

@export var speed: float = 30.0
@export var turn_speed: float = 2.0  # radians per second, chassis turn rate
@export var push_speed: float = 140.0
@export var look_ahead_distance: float = 90.0
@export var min_wander_seconds: float = 1.0
@export var max_wander_seconds: float = 3.0

const _HUE_SHIFT_SHADER: Shader = preload("res://scenes/objects/robot/robot_hue_shift.gdshader")

@onready var _look_ahead: RayCast2D = $LookAhead
@onready var _sprite: Sprite2D = $Sprite2D

var _target_angle: float = 0.0
var _time_to_next_direction: float = 0.0

func _ready() -> void:
    _look_ahead.add_exception(self)
    _pick_new_direction()
    rotation = _target_angle
    _randomize_color()

func _randomize_color() -> void:
    var mat := ShaderMaterial.new()
    mat.shader = _HUE_SHIFT_SHADER
    mat.set_shader_parameter("hue_shift", randf())
    _sprite.material = mat

func _pick_new_direction() -> void:
    _target_angle = randf_range(0.0, TAU)
    _time_to_next_direction = randf_range(min_wander_seconds, max_wander_seconds)

func _turn_away() -> void:
    var turn := randf_range(deg_to_rad(120.0), deg_to_rad(240.0))
    if randi() % 2 == 0:
        turn = -turn
    _target_angle = rotation + turn
    _time_to_next_direction = randf_range(min_wander_seconds, max_wander_seconds)

func _physics_process(delta: float) -> void:
    _time_to_next_direction -= delta
    if _time_to_next_direction <= 0.0:
        _pick_new_direction()

    var blocked_ahead := _look_ahead.is_colliding() and not (_look_ahead.get_collider() is Player)
    if blocked_ahead:
        _turn_away()

    var angle_diff := wrapf(_target_angle - rotation, -PI, PI)
    rotation += clamp(angle_diff, -turn_speed * delta, turn_speed * delta)

    # While something non-Player is sensed ahead, turn in place instead of
    # driving forward, so the chassis never advances into a wall or hazard
    # while it is still rotating away from it.
    velocity = Vector2.UP.rotated(rotation) * (0.0 if blocked_ahead else speed)
    move_and_slide()

    _push_players(delta)

func _push_players(delta: float) -> void:
    for i in range(get_slide_collision_count()):
        var collision := get_slide_collision(i)
        var collider := collision.get_collider()
        if collider is Player:
            collider.move_and_collide(Vector2.UP.rotated(rotation) * push_speed * delta)
