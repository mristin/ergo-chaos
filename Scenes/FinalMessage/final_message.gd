extends Node2D

class_name FinalMessage

var _counter: int = 10
@onready var timer: Timer = $Timer
@onready var counter: Label = $Counter

signal done()

@onready var message: Label = $Message

func set_message(text: String) -> void:
    message.text = text

func _on_tic() -> void:
    _counter -= 1
    counter.text = str(_counter)
    
    if _counter == 0:
        done.emit()
        print("Game over shown")        
    else:
        timer.start()        

func _ready() -> void:
    timer.timeout.connect(_on_tic)
    timer.start()
