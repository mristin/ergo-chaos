extends CharacterBody2D

class_name Player

@export var speed: float = 300.0
@export var turn_speed: float = 3.0

var movement_input: Vector2 = Vector2.ZERO
var turn_input: float = 0

func _process(_delta: float) -> void:
    movement_input = Vector2.ZERO
    turn_input = 0

    if Input.is_action_pressed("ui_up"):
        movement_input = Vector2.UP

    if Input.is_action_pressed("ui_right"):
        turn_input += 1

    if Input.is_action_pressed("ui_left"):
        turn_input -= 1

func _physics_process(delta: float) -> void:
    if turn_input != 0:
        rotation += turn_input * turn_speed * delta

    if movement_input != Vector2.ZERO:
        velocity = movement_input.rotated(rotation) * speed
    else:
        velocity = Vector2.ZERO

    move_and_slide()
