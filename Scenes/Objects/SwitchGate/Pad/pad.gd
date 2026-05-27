extends Area2D

signal on_enter
signal on_leave

const _RED_LIGHT := preload("res://Assets/Images/red-light.png")
const _GREEN_LIGHT := preload("res://Assets/Images/green-light.png")

const _CONNECTED := preload("res://Assets/Images/connected-switch-symbol.svg")
const _DISCONNECTED := preload("res://Assets/Images/disconnected-switch-symbol.svg")

@onready var _lights: Array[Sprite2D] = [$Light1, $Light2, $Light3, $Light4]
@onready var _symbol: Sprite2D = $Symbol

func _ready() -> void:
    _set_lights_green(false)
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _set_lights_green(green: bool) -> void:
    var texture := _GREEN_LIGHT if green else _RED_LIGHT
    for light in _lights:
        light.texture = texture

    if green:
        _symbol.texture = _DISCONNECTED
    else:
        _symbol.texture = _CONNECTED

func _on_body_entered(body: Node2D) -> void:
    if not body is Player:
        return
    _set_lights_green(true)
    on_enter.emit()

func _on_body_exited(body: Node2D) -> void:
    if not body is Player:
        return
    _set_lights_green(false)
    on_leave.emit()
