@tool
extends StaticBody2D

@export var border_width := 10.0
@export var border_color := Color.DARK_GRAY

@onready var poly: Polygon2D = $Polygon2D

var line: Line2D

func _ready():
    print("Setting up the line.")
    setup_line()

    if not Engine.is_editor_hint():
        create_collision()

func _process(_delta):
    if Engine.is_editor_hint():
       update_line()
        
func setup_line():
    line = get_node_or_null("Line2D")

    if line == null:
        line = Line2D.new()
        line.name = "Line2D"
        add_child(line)
        line.owner = get_tree().edited_scene_root

    update_line()

func update_line():
    if not poly:
        return

    line.points = poly.polygon
    line.closed = true
    line.width = border_width
    line.default_color = border_color
    line.joint_mode = Line2D.LINE_JOINT_ROUND
    line.begin_cap_mode = Line2D.LINE_CAP_ROUND
    line.end_cap_mode = Line2D.LINE_CAP_ROUND
    line.antialiased = true

func create_collision():
    print("Creating collision polygon 2D...")
    var collision := CollisionPolygon2D.new()
    collision.polygon = poly.polygon
    add_child(collision)
    print("Collision created.")
