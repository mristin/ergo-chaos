extends Area2D

@onready var _lights = [
    $Light1,
    $Light2,
    $Light3,
    $Light4
]

const _RED_LIGHT: Texture2D = preload("res://Assets/Images/red-light.png")
const _GREEN_LIGHT: Texture2D = preload("res://Assets/Images/green-light.png")

const _RECHARGE_RATE: float = 5.0  # battery per second

var _player_effects: Dictionary = {}  # Player -> PlayerEffect

func _ready() -> void:
    _set_lights(_RED_LIGHT)
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _set_lights(texture: Texture2D) -> void:
    for light in _lights:
        light.texture = texture

func _on_body_entered(body: Node2D) -> void:
    if not (body is Player) or body in _player_effects:
        return
    var effect := PlayerEffect.new()
    effect.battery_drain_per_second = -_RECHARGE_RATE
    body.add_effect(effect)
    _player_effects[body] = effect
    _set_lights(_GREEN_LIGHT)

func _on_body_exited(body: Node2D) -> void:
    if body not in _player_effects:
        return
    body.remove_effect(_player_effects[body])
    _player_effects.erase(body)
    if _player_effects.is_empty():
        _set_lights(_RED_LIGHT)
