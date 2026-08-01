extends Area2D
class_name FallingRock

const Constants = preload("res://scripts/constants.gd")

# Debris from a collapsed fracture. Falls under gravity until it hits solid
# ground, then settles permanently into the terrain as rubble -- a cave-in
# leaves the tunnel changed, not just a passing threat.

const GRAVITY := 900.0
const MAX_FALL_SPEED := 700.0
const MAX_LIFETIME := 8.0

var terrain: Node = null
var fall_speed := 0.0
var life := 0.0

func _ready() -> void:
    set_collision_layer_value(1, false)
    set_collision_mask_value(2, true)
    monitoring = true
    monitorable = false

    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 13.0
    shape.shape = circle
    add_child(shape)

    var visual := Polygon2D.new()
    visual.color = Color(0.5, 0.44, 0.4)
    visual.polygon = PackedVector2Array([
        Vector2(-12, -6), Vector2(-4, -13), Vector2(9, -10),
        Vector2(13, 2), Vector2(4, 13), Vector2(-10, 9),
    ])
    add_child(visual)

    body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
    life += delta
    if life > MAX_LIFETIME:
        queue_free()
        return

    fall_speed = min(fall_speed + GRAVITY * delta, MAX_FALL_SPEED)
    position.y += fall_speed * delta

    if terrain == null or not is_instance_valid(terrain):
        queue_free()
        return

    var cell: Vector2i = terrain.local_to_map(terrain.to_local(position))
    if cell.y >= Constants.GRID_HEIGHT - 1 or terrain.is_solid(cell + Vector2i.DOWN):
        terrain.fill_rubble(cell)
        queue_free()

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        body.hit_by_hazard("crushed in a cave-in")
    queue_free()
