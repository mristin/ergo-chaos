class_name LaserPost
extends Sprite2D

const light_textures: Array[Texture2D] = [
    preload("res://Assets/Images/green-light.png"),
    preload("res://Assets/Images/yellow-light.png"),
    preload("res://Assets/Images/red-light.png"),
]

@onready var _light: Sprite2D = $Light

func set_green() -> void:
    _light.texture = light_textures[0]

func set_yellow() -> void:
    _light.texture = light_textures[1]

func set_red() -> void:
    _light.texture = light_textures[2]
