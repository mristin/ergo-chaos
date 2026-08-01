extends Area2D

class_name Goo

signal collected()

var textures: Array[Texture2D] = [
    preload("res://assets/images/paint_splat_a.svg"),
    preload("res://assets/images/paint_splat_b.svg"),
    preload("res://assets/images/paint_splat_c.svg"),
    preload("res://assets/images/paint_splat_d.svg"),
]

@onready var sprite_2d: Sprite2D = $Sprite2D

func _ready() -> void:
    sprite_2d.texture = textures.pick_random()  

func _on_body_entered(body: Node2D) -> void:
    if body is Player:
        collected.emit()
        queue_free()        
