extends Node2D

class_name HitExplosion

## A one-shot shockwave burst spawned wherever the villain hits a player. It
## expands and fades over `duration` seconds, then frees itself.

@export var duration: float = 0.45

@onready var _mesh: MeshInstance2D = $MeshInstance2D
@onready var _material: ShaderMaterial = _mesh.material

var _age: float = 0.0

func _process(delta: float) -> void:
    _age += delta
    var progress: float = clamp(_age / duration, 0.0, 1.0)
    _material.set_shader_parameter("progress", progress)
    if progress >= 1.0:
        queue_free()
