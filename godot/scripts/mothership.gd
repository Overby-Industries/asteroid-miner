extends Area2D
class_name Mothership

# See art/sprites/README.md -- if a pre-rendered hull image lands at this
# path, _ready() uses it instead of the procedural hull polygon. Rendered
# at any resolution and scaled to fit HULL_SPRITE_SIZE (world units), so
# export size doesn't need to match gameplay size exactly.
const HULL_SPRITE_PATH := "res://art/sprites/mothership.png"
const HULL_SPRITE_SIZE := Vector2(100, 58)

var flame_poly: Polygon2D

func _ready() -> void:
    set_collision_layer_value(1, false)
    set_collision_mask_value(2, true)
    monitoring = true
    monitorable = false

    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(96, 54)
    shape.shape = rect
    add_child(shape)

    flame_poly = Polygon2D.new()
    flame_poly.color = Color(1.0, 0.6, 0.2, 0.85)
    flame_poly.polygon = PackedVector2Array([
        Vector2(-22, 27), Vector2(22, 27), Vector2(0, 70),
    ])
    flame_poly.visible = false
    add_child(flame_poly)

    if ResourceLoader.exists(HULL_SPRITE_PATH):
        var hull_sprite := Sprite2D.new()
        var hull_tex: Texture2D = load(HULL_SPRITE_PATH)
        hull_sprite.texture = hull_tex
        hull_sprite.scale = HULL_SPRITE_SIZE / hull_tex.get_size()
        add_child(hull_sprite)
    else:
        var hull := Polygon2D.new()
        hull.color = Color(0.58, 0.63, 0.7)
        hull.polygon = PackedVector2Array([
            Vector2(-48, -27), Vector2(48, -27), Vector2(48, 27), Vector2(-48, 27),
        ])
        add_child(hull)

        var window := Polygon2D.new()
        window.color = Color(0.35, 0.85, 0.95, 0.9)
        window.polygon = PackedVector2Array([
            Vector2(-14, -8), Vector2(14, -8), Vector2(14, 8), Vector2(-14, 8),
        ])
        add_child(window)

    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        body.set_docked(true)

func _on_body_exited(body: Node) -> void:
    if body.is_in_group("player"):
        body.set_docked(false)

# Drops the ship in from directly above its resting spot and eases it down
# like it's braking on thrusters. Returns the Tween so the caller can await
# it (or kill it early to skip straight to finish_landing_immediately).
func begin_landing(final_pos: Vector2, drop_height: float, duration: float = 2.2) -> Tween:
    position = final_pos + Vector2(0, -drop_height)
    scale = Vector2.ONE
    flame_poly.visible = true
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "position", final_pos, duration)
    tween.tween_callback(_on_landed)
    return tween

func finish_landing_immediately(final_pos: Vector2) -> void:
    position = final_pos
    _on_landed()

func _on_landed() -> void:
    flame_poly.visible = false
    Sfx.play_at("mothership_thump", global_position)
    var bounce := create_tween()
    bounce.tween_property(self, "scale", Vector2(1.1, 0.85), 0.08)
    bounce.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
