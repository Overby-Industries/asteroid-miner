extends Area2D
class_name HeatVent

# A magma pocket buried in the rock. Doesn't need to be touched to hurt --
# lingering in its glow cooks the rig's air supply faster the longer you stay.

const RADIUS := 88.0
const DRAIN_PER_SEC := 6.0 # on top of passive O2 drain -- dangerous to linger, not instant

func _ready() -> void:
    set_collision_layer_value(1, false)
    set_collision_mask_value(2, true)
    monitoring = true
    monitorable = false

    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = RADIUS
    shape.shape = circle
    add_child(shape)

    var glow := Polygon2D.new()
    glow.color = Color(0.95, 0.28, 0.06, 0.16)
    glow.polygon = _circle_points(RADIUS, 24)
    add_child(glow)

    var core := Polygon2D.new()
    core.color = Color(1.0, 0.55, 0.1, 0.9)
    core.polygon = _circle_points(10.0, 10)
    add_child(core)

    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        body.enter_heat(DRAIN_PER_SEC)

func _on_body_exited(body: Node) -> void:
    if body.is_in_group("player"):
        body.exit_heat(DRAIN_PER_SEC)

func _circle_points(radius: float, segments: int) -> PackedVector2Array:
    var pts := PackedVector2Array()
    for i in range(segments):
        var a := TAU * float(i) / float(segments)
        pts.append(Vector2(cos(a), sin(a)) * radius)
    return pts
