extends Area2D
class_name Mothership

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
