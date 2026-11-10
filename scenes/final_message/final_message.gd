extends CanvasLayer

class_name FinalMessage

var _counter: int = 10

@onready var timer: Timer = $Timer
@onready var counter: Label = $Counter

signal done()

@onready var image: TextureRect = $Image


func set_image(texture: Texture2D) -> void:
    image.texture = texture
    image.visible = true

func set_countdown_seconds(seconds: int) -> void:
    _counter = seconds
    counter.text = str(_counter)

func _on_tic() -> void:
    _counter -= 1
    counter.text = str(_counter)

    if _counter == 0:
        done.emit()
        print("Game over shown")
    else:
        timer.start()

func _ready() -> void:
    counter.text = str(_counter)
    timer.timeout.connect(_on_tic)
    timer.start()
