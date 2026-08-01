extends CharacterBody2D

class_name Villain

## A relentless hunter NPC. It always chases whichever player (A or B) is
## currently closer, with a bit of random heading jitter so the pursuit isn't
## a perfectly straight line, while steering away from anything a
## forward-looking raycast hits that isn't a Player (walls, spark fields,
## other NPCs). On contact with a player it drains their battery and freezes
## for a while so the player has a real chance to get away before the hunt
## resumes. Its sprite is tinted to match the color of whichever player it is
## currently chasing.

@export var speed: float = 60.0
@export var turn_speed: float = 3.0  # radians per second, chassis turn rate
@export var look_ahead_distance: float = 90.0
@export var jitter_degrees: float = 15.0
@export var min_jitter_seconds: float = 0.5
@export var max_jitter_seconds: float = 1.5
@export var hit_battery_drain: float = 15.0
@export var stun_seconds: float = 3.5

enum TargetPreference { CLOSEST, PLAYER_A, PLAYER_B }
## Which player this villain hunts. CLOSEST (default) always goes after
## whichever player is nearer; PLAYER_A/PLAYER_B pin it to a specific player
## regardless of distance, for levels that want one villain per player.
@export var target_preference: TargetPreference = TargetPreference.CLOSEST

const _RED_TINT := Color(0.85, 0.16, 0.16)
const _BLUE_TINT := Color(0.16, 0.45, 0.85)
const _RED_TEXTURE: Texture2D = preload("res://assets/images/spaceship_red.png")
const _SPARKS_SHADER: Shader = preload(
    "res://scenes/objects/villain/villain_sparks.gdshader"
)
const _HIT_EXPLOSION_SCENE: PackedScene = preload(
    "res://scenes/objects/villain/hit_explosion.tscn"
)

@onready var _look_ahead: RayCast2D = $LookAhead
@onready var _sprite: Sprite2D = $Sprite2D

var _player_a: Player
var _player_b: Player
var _material: ShaderMaterial

var _target_angle: float = 0.0
var _jitter_offset: float = 0.0
var _time_to_next_jitter: float = 0.0
var _avoiding_timer: float = 0.0
var _stun_timer: float = 0.0

func _ready() -> void:
    _look_ahead.add_exception(self)
    _look_ahead.target_position = Vector2.UP * look_ahead_distance

    _player_a = get_parent().get_node("PlayerA")
    _player_b = get_parent().get_node("PlayerB")

    _material = ShaderMaterial.new()
    _material.shader = _SPARKS_SHADER
    _sprite.material = _material

    _pick_new_jitter()
    _target_angle = rotation

func _pick_new_jitter() -> void:
    _jitter_offset = deg_to_rad(randf_range(-jitter_degrees, jitter_degrees))
    _time_to_next_jitter = randf_range(min_jitter_seconds, max_jitter_seconds)

func _turn_away() -> void:
    var turn := randf_range(deg_to_rad(100.0), deg_to_rad(200.0))
    if randi() % 2 == 0:
        turn = -turn
    _target_angle = rotation + turn
    _avoiding_timer = randf_range(0.4, 0.9)

func _closer_player() -> Player:
    var a_valid := is_instance_valid(_player_a)
    var b_valid := is_instance_valid(_player_b)

    if target_preference == TargetPreference.PLAYER_A and a_valid:
        return _player_a
    if target_preference == TargetPreference.PLAYER_B and b_valid:
        return _player_b

    if a_valid and not b_valid:
        return _player_a
    if b_valid and not a_valid:
        return _player_b
    if not a_valid and not b_valid:
        return null
    var d_a := global_position.distance_squared_to(_player_a.global_position)
    var d_b := global_position.distance_squared_to(_player_b.global_position)
    return _player_a if d_a <= d_b else _player_b

# Converts a world-space direction into the same angle convention as
# `rotation`, given that the chassis drives forward along Vector2.UP.rotated(rotation).
func _heading_to(direction: Vector2) -> float:
    return atan2(direction.x, -direction.y)

func _physics_process(delta: float) -> void:
    if _stun_timer > 0.0:
        _stun_timer -= delta
        velocity = Vector2.ZERO
        move_and_slide()
        return

    var blocked_ahead := (
        _look_ahead.is_colliding() 
        and not (_look_ahead.get_collider() is Player)
    )

    if _avoiding_timer > 0.0:
        _avoiding_timer -= delta
        if blocked_ahead:
            _turn_away()
    elif blocked_ahead:
        _turn_away()
    else:
        var target := _closer_player()
        if target != null:
            _time_to_next_jitter -= delta
            if _time_to_next_jitter <= 0.0:
                _pick_new_jitter()

            _target_angle = (
                _heading_to(target.global_position - global_position) 
                + _jitter_offset
            )
            _material.set_shader_parameter(
                "tint_color", 
                _RED_TINT 
                if target.texture == _RED_TEXTURE 
                else _BLUE_TINT
            )

    var angle_diff := wrapf(_target_angle - rotation, -PI, PI)
    rotation += clamp(angle_diff, -turn_speed * delta, turn_speed * delta)

    velocity = Vector2.UP.rotated(rotation) * (0.0 if blocked_ahead else speed)
    move_and_slide()

    _handle_player_hit()

func _handle_player_hit() -> void:
    for i in range(get_slide_collision_count()):
        var collision := get_slide_collision(i)
        var collider := collision.get_collider()
        if collider is Player:
            collider.drain_battery(hit_battery_drain)
            _stun_timer = stun_seconds
            _spawn_hit_explosion(collision.get_position())
            return

func _spawn_hit_explosion(at_position: Vector2) -> void:
    var explosion: Node2D = _HIT_EXPLOSION_SCENE.instantiate()
    get_parent().add_child(explosion)
    explosion.global_position = at_position
