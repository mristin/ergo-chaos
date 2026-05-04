@tool
extends Area2D

const _SPARK_BORDER_SHADER = preload(
    "res://Scenes/Obstacles/SparkField/spark_border.gdshader"
)
const _SPARK_FILL_SHADER = preload(
    "res://Scenes/Obstacles/SparkField/spark_field_fill.gdshader"
)

@export var sign_count: int = 6:
    set(v):
        sign_count = v
        if Engine.is_editor_hint() and is_inside_tree():
            _refresh()

# Minimum pixel distance between sign centers (in Area2D local space)
@export var min_sign_spacing: float = 60.0:
    set(v):
        min_sign_spacing = v
        if Engine.is_editor_hint() and is_inside_tree():
            _refresh()

@export var border_width: float = 5.0:
    set(v):
        border_width = v
        if Engine.is_editor_hint() and is_inside_tree():
            _refresh()

const _DANGER_SIGNS: Array[Texture2D] = [
    preload("res://Assets/Images/danger1.png"),
    preload("res://Assets/Images/danger2.svg"),
    preload("res://Assets/Images/danger3.svg"),
    preload("res://Assets/Images/danger4.svg"),
]

func _ready() -> void:
    var collision_node := _find_collision_node()
    if collision_node == null:
        push_error(
            "SparkField: Area2D must have a CollisionPolygon2D or " +
            "CollisionShape2D child"
        )
        return
    _refresh_fill(collision_node)
    _sprinkle_signs(collision_node)
    _refresh_border(collision_node)

func _refresh() -> void:
    var collision_node := _find_collision_node()
    if collision_node != null:
        _refresh_fill(collision_node)
        _sprinkle_signs(collision_node)
        _refresh_border(collision_node)

func _find_collision_node() -> Node:
    for child in get_children():
        if child is CollisionPolygon2D or child is CollisionShape2D:
            return child
    return null

func _get_polygon(node: Node) -> PackedVector2Array:
    var local_pts: PackedVector2Array
    if node is CollisionPolygon2D:
        local_pts = node.polygon
    elif node is CollisionShape2D:
        var shape := (node as CollisionShape2D).shape
        if shape is RectangleShape2D:
            var h: Vector2 = shape.size / 2
            local_pts = PackedVector2Array([
                Vector2(-h.x, -h.y), Vector2(h.x, -h.y),
                Vector2(h.x, h.y), Vector2(-h.x, h.y),
            ])
        elif shape is CircleShape2D:
            local_pts = PackedVector2Array()
            for i in range(16):
                var a := TAU * i / 16.0
                local_pts.append(Vector2(cos(a), sin(a)) * shape.radius)
        else:
            return PackedVector2Array()
    else:
        return PackedVector2Array()

    # Transform from collision node local space to Area2D local space
    var result := PackedVector2Array()
    for p in local_pts:
        result.append(node.transform * p)
    return result

func _sprinkle_signs(collision_node: Node) -> void:
    for child in get_children():
        if child is Sprite2D:
            child.free()

    var polygon := _get_polygon(collision_node)
    if polygon.size() < 3:
        push_error("SparkField: could not derive a polygon from the collision shape")
        return

    var min_p := polygon[0]
    var max_p := polygon[0]
    for p in polygon:
        min_p = min_p.min(p)
        max_p = max_p.max(p)

    var placed: Array[Vector2] = []
    var attempts := 0

    while placed.size() < sign_count and attempts < sign_count * 200:
        attempts += 1
        var pt := Vector2(randf_range(min_p.x, max_p.x), randf_range(min_p.y, max_p.y))

        if not Geometry2D.is_point_in_polygon(pt, polygon):
            continue

        var too_close := false
        for p in placed:
            if pt.distance_to(p) < min_sign_spacing:
                too_close = true
                break
        if too_close:
            continue

        placed.append(pt)
        var texture: Texture2D = _DANGER_SIGNS.pick_random()
        var sprite := Sprite2D.new()
        sprite.texture = texture
        sprite.scale = Vector2.ONE * (50.0 / texture.get_height())
        sprite.position = pt
        sprite.rotation = randf_range(0.0, TAU)
        add_child(sprite)

func _refresh_fill(collision_node: Node) -> void:
    # TODO: check that this block will not delete the collision shape 2D!
    for child in get_children():
        if child is Polygon2D:
            child.free()

    var polygon := _get_polygon(collision_node)
    if polygon.size() < 3:
        return

    var min_p := polygon[0]
    var max_p := polygon[0]
    for p in polygon:
        min_p = min_p.min(p)
        max_p = max_p.max(p)
    var span := max_p - min_p
    if span.x < 1.0 or span.y < 1.0:
        return

    # TODO: infer correct uvs 
    
    var mat := ShaderMaterial.new()
    
    # TODO: re-generate the spark to be a simple gradient
    mat.shader = _SPARK_FILL_SHADER

    var poly := Polygon2D.new()
    poly.polygon = polygon
    poly.uv = uvs
    poly.material = mat
    poly.z_index = -1  # behind signs and border
    add_child(poly)

func _refresh_border(collision_node: Node) -> void:
    for child in get_children():
        if child is Line2D:
            child.free()

    var polygon := _get_polygon(collision_node)
    if polygon.size() < 3:
        return

    var mat := ShaderMaterial.new()
    mat.shader = _SPARK_BORDER_SHADER

    var line := Line2D.new()
    line.material = mat
    line.width = border_width
    line.default_color = Color.WHITE
    line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
    line.z_index = 1

    for p in polygon:
        line.add_point(p)
    line.add_point(polygon[0])  # close the loop

    add_child(line)
