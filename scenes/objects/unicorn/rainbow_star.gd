extends Node2D

class_name RainbowStar

## A single fading rainbow star left behind in the unicorn's trail. Picks a
## random hue, then shrinks, twinkles, and fades out over `duration` seconds
## before freeing itself.

@export var duration: float = 0.7

@onready var _mesh: MeshInstance2D = $MeshInstance2D
@onready var _material: ShaderMaterial = _mesh.material

var _age: float = 0.0

func _ready() -> void:
    _material.set_shader_parameter("hue", randf())

func _process(delta: float) -> void:
    _age += delta
    var progress: float = clamp(_age / duration, 0.0, 1.0)
    _material.set_shader_parameter("progress", progress)
    if progress >= 1.0:
        queue_free()
