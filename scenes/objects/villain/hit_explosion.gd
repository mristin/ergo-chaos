extends Node2D

class_name HitExplosion

## A one-shot shockwave burst spawned wherever the villain hits a player. It
## expands and fades over `duration` seconds, then frees itself.

@export var duration: float = 0.45
@export var outer_color: Color = Color(0.05, 0.4, 1.0)
@export var mid_color: Color = Color(0.6, 0.9, 1.0)
@export var inner_color: Color = Color(1.0, 1.0, 1.0)

@onready var _mesh: MeshInstance2D = $MeshInstance2D
@onready var _material: ShaderMaterial = _mesh.material

var _age: float = 0.0

func _ready() -> void:
    _material.set_shader_parameter("outer_color", outer_color)
    _material.set_shader_parameter("mid_color", mid_color)
    _material.set_shader_parameter("inner_color", inner_color)

func _process(delta: float) -> void:
    _age += delta
    var progress: float = clamp(_age / duration, 0.0, 1.0)
    _material.set_shader_parameter("progress", progress)
    if progress >= 1.0:
        queue_free()
