@tool
extends Node2D

const _FIREBALL_SHADER: Shader = preload("res://Scenes/Objects/RotatingFireballs/fireball.gdshader")
const BATTERY_DRAIN_PER_SECOND: float = 7.0

const _DANGER_SIGNS: Array[Texture2D] = [
    preload("res://Assets/Images/danger1.png"),
    preload("res://Assets/Images/danger2.svg"),
    preload("res://Assets/Images/danger3.svg"),
    preload("res://Assets/Images/danger4.svg"),
]
const _SIGN_SIZE: float = 60.0

@export var fireball_count: int = 5:
    set(v):
        fireball_count = max(1, v)
        _rebuild_fireballs()

@export var radius: float = 200.0:
    set(v):
        radius = max(1.0, v)
        _rebuild_fireballs()
        queue_redraw()

@export var rotation_speed: float = 45.0  # degrees per second

@export var fireball_width: float = 70.0:
    set(v):
        fireball_width = max(1.0, v)
        _rebuild_fireballs()

@export var fireball_height: float = 16.0:
    set(v):
        fireball_height = max(1.0, v)
        _rebuild_fireballs()

var _angle: float = 0.0
var _fireball_nodes: Array[Area2D] = []
var _player_effects: Dictionary = {}  # body -> { fireball -> PlayerEffect }
var _sign_sprite: Sprite2D = null

func _ready() -> void:
    _rebuild_fireballs()

func _rebuild_fireballs() -> void:
    for body in _player_effects:
        if is_instance_valid(body):
            for fireball in _player_effects[body]:
                body.remove_effect(_player_effects[body][fireball])
    _player_effects.clear()

    for fb in _fireball_nodes:
        if is_instance_valid(fb):
            fb.queue_free()
    _fireball_nodes.clear()

    if is_instance_valid(_sign_sprite):
        _sign_sprite.queue_free()
        _sign_sprite = null

    if not is_inside_tree():
        return

    var texture: Texture2D = _DANGER_SIGNS.pick_random()
    _sign_sprite = Sprite2D.new()
    _sign_sprite.texture = texture
    _sign_sprite.scale = Vector2.ONE * (_SIGN_SIZE / texture.get_height())
    add_child(_sign_sprite)

    for i in range(fireball_count):
        var fb := _make_fireball()
        add_child(fb)
        _fireball_nodes.append(fb)
        if not Engine.is_editor_hint():
            fb.body_entered.connect(_on_body_entered.bind(fb))
            fb.body_exited.connect(_on_body_exited.bind(fb))

    _update_fireball_positions()

func _make_fireball() -> Area2D:
    var fb := Area2D.new()

    var col := CollisionShape2D.new()
    var shape := CapsuleShape2D.new()
    shape.radius = fireball_width / 2.0
    shape.height = max(fireball_height, fireball_width)
    col.shape = shape
    fb.add_child(col)

    var mesh_inst := MeshInstance2D.new()
    var quad := QuadMesh.new()
    quad.size = Vector2(fireball_width, fireball_height)
    mesh_inst.mesh = quad

    var mat := ShaderMaterial.new()
    mat.shader = _FIREBALL_SHADER
    mat.set_shader_parameter("time_offset", randf_range(0.0, TAU))
    mesh_inst.material = mat
    fb.add_child(mesh_inst)

    return fb

func _update_fireball_positions() -> void:
    for i in range(_fireball_nodes.size()):
        var theta := _angle + i * TAU / _fireball_nodes.size()
        var fb := _fireball_nodes[i]
        fb.position = Vector2(cos(theta), sin(theta)) * radius
        fb.rotation = theta + PI / 2.0  # orient long axis along direction of travel

func _process(delta: float) -> void:
    _angle += deg_to_rad(rotation_speed) * delta
    _update_fireball_positions()
    if is_instance_valid(_sign_sprite):
        _sign_sprite.rotation = _angle
    queue_redraw()

func _draw() -> void:
    draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.1, 0.6, 1.0, 0.5), 4.0)

func _on_body_entered(body: Node2D, fireball: Area2D) -> void:
    if not (body is Player):
        return
    if body not in _player_effects:
        _player_effects[body] = {}
    if fireball in _player_effects[body]:
        return
    var effect := PlayerEffect.new()
    effect.battery_drain_per_second = BATTERY_DRAIN_PER_SECOND
    body.add_effect(effect)
    _player_effects[body][fireball] = effect

func _on_body_exited(body: Node2D, fireball: Area2D) -> void:
    if body not in _player_effects:
        return
    if fireball not in _player_effects[body]:
        return
    body.remove_effect(_player_effects[body][fireball])
    _player_effects[body].erase(fireball)
    if _player_effects[body].is_empty():
        _player_effects.erase(body)
