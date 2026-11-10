extends CharacterBody2D

class_name Unicorn

## A friendly wandering NPC: it roams the level at random like Robot does,
## steering away from anything a forward-looking raycast hits that isn't a
## Player or a Goo pickup (so it respects walls, spark fields and laser
## gates, but happily tramples straight over goo). On contact with a player
## it replenishes their battery instead of harming them, with a short
## cooldown so a single touch doesn't refill them every physics frame.

@export var speed: float = 70.0
@export var turn_speed: float = 2.0  # radians per second, chassis turn rate
@export var look_ahead_distance: float = 90.0
@export var min_wander_seconds: float = 1.0
@export var max_wander_seconds: float = 3.0
@export var heal_amount: float = 25.0
@export var heal_cooldown_seconds: float = 2.0
@export var trail_interval_seconds: float = 0.12
@export var trail_offset: float = 45.0
@export var trail_star_duration: float = 1.8
@export var trail_position_jitter: float = 20.0
@export var trail_scale_jitter: float = 0.35

const _HIT_EXPLOSION_SCENE: PackedScene = preload(
    "res://scenes/objects/villain/hit_explosion.tscn"
)
const _RAINBOW_STAR_SCENE: PackedScene = preload(
    "res://scenes/objects/unicorn/rainbow_star.tscn"
)
const _HEAL_OUTER_COLOR := Color(1.0, 0.4, 0.85)
const _HEAL_MID_COLOR := Color(1.0, 0.85, 0.3)
const _HEAL_INNER_COLOR := Color(1.0, 1.0, 1.0)

@onready var _look_ahead: RayCast2D = $LookAhead

var _target_angle: float = 0.0
var _time_to_next_direction: float = 0.0
var _heal_cooldown_timer: float = 0.0
var _trail_timer: float = 0.0

func _ready() -> void:
    _look_ahead.add_exception(self)
    _pick_new_direction()
    rotation = _target_angle

func _pick_new_direction() -> void:
    _target_angle = randf_range(0.0, TAU)
    _time_to_next_direction = randf_range(min_wander_seconds, max_wander_seconds)

func _turn_away() -> void:
    var turn := randf_range(deg_to_rad(120.0), deg_to_rad(240.0))
    if randi() % 2 == 0:
        turn = -turn
    _target_angle = rotation + turn
    _time_to_next_direction = randf_range(min_wander_seconds, max_wander_seconds)

func _is_obstacle(collider: Object) -> bool:
    return not (collider is Player) and not (collider is Goo)

func _physics_process(delta: float) -> void:
    if _heal_cooldown_timer > 0.0:
        _heal_cooldown_timer -= delta

    _time_to_next_direction -= delta
    if _time_to_next_direction <= 0.0:
        _pick_new_direction()

    var blocked_ahead := (
        _look_ahead.is_colliding() and _is_obstacle(_look_ahead.get_collider())
    )
    if blocked_ahead:
        _turn_away()

    var angle_diff := wrapf(_target_angle - rotation, -PI, PI)
    rotation += clamp(angle_diff, -turn_speed * delta, turn_speed * delta)

    velocity = Vector2.UP.rotated(rotation) * (0.0 if blocked_ahead else speed)
    move_and_slide()

    if not blocked_ahead:
        _trail_timer -= delta
        if _trail_timer <= 0.0:
            _spawn_trail_star()
            _trail_timer = trail_interval_seconds

    _heal_players()

func _heal_players() -> void:
    if _heal_cooldown_timer > 0.0:
        return
    for i in range(get_slide_collision_count()):
        var collision := get_slide_collision(i)
        var collider := collision.get_collider()
        if collider is Player:
            collider.heal_battery(heal_amount)
            _heal_cooldown_timer = heal_cooldown_seconds
            _spawn_heal_sparkle(collision.get_position())
            return

func _spawn_heal_sparkle(at_position: Vector2) -> void:
    var sparkle: Node2D = _HIT_EXPLOSION_SCENE.instantiate()
    sparkle.outer_color = _HEAL_OUTER_COLOR
    sparkle.mid_color = _HEAL_MID_COLOR
    sparkle.inner_color = _HEAL_INNER_COLOR
    get_parent().add_child(sparkle)
    sparkle.global_position = at_position

func _spawn_trail_star() -> void:
    var star: Node2D = _RAINBOW_STAR_SCENE.instantiate()
    star.duration = trail_star_duration * randf_range(0.75, 1.25)

    var behind := Vector2.DOWN.rotated(rotation) * trail_offset
    var jitter := Vector2(
        randf_range(-trail_position_jitter, trail_position_jitter),
        randf_range(-trail_position_jitter, trail_position_jitter)
    )

    get_parent().add_child(star)
    star.global_position = global_position + behind + jitter
    star.rotation = randf_range(0.0, TAU)
    star.scale = Vector2.ONE * randf_range(1.0 - trail_scale_jitter, 1.0 + trail_scale_jitter)
