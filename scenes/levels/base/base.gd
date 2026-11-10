extends Node2D

## Bakes the static layer of the floor shader into a texture once, when the
## level loads.
##
## Every floor shader has a `bake_pass` switch. With `bake_pass = true` it
## renders only the expensive, unchanging detail (plates, wood, rock, ...) and
## puts a mask for the animated effects into the alpha channel. The visible
## floor then samples that texture through `baked` and only computes the cheap
## animated layer per frame. This keeps the backgrounds affordable on
## integrated GPUs, where the camera hand tracking competes for time as well.

@onready var _floor: ColorRect = $Floor


func _ready() -> void:
    var material := _floor.material as ShaderMaterial
    if material == null:
        return

    # Work on copies so that the materials stored in the level scenes are never
    # mutated and every instantiation of a level gets its own bake.
    var display_material := material.duplicate() as ShaderMaterial
    var bake_material := material.duplicate() as ShaderMaterial
    bake_material.set_shader_parameter("bake_pass", true)

    var viewport := SubViewport.new()
    viewport.name = "FloorBake"
    viewport.size = Vector2i(_floor.size.ceil())
    viewport.transparent_bg = true
    viewport.disable_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

    var bake_rect := ColorRect.new()
    bake_rect.size = _floor.size
    bake_rect.material = bake_material
    viewport.add_child(bake_rect)
    add_child(viewport)

    display_material.set_shader_parameter("baked", viewport.get_texture())
    _floor.material = display_material
