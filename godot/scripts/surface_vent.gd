extends Area2D
class_name SurfaceVent

# Gates the shaft back to the mothership. Cycles safe -> warning -> eruption
# on randomized timings so it reads fair (the warning flash always precedes
# the blast) without being pure muscle-memory metronome timing.

enum State { SAFE, WARNING, ERUPTING }

var state: int = State.SAFE
var timer := 0.0
var rng := RandomNumberGenerator.new()
var visual: Polygon2D
var pulse_t := 0.0

func _ready() -> void:
    set_collision_layer_value(1, false)
    set_collision_mask_value(2, true)
    monitoring = true
    monitorable = false

    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(92, 46)
    shape.shape = rect
    add_child(shape)

    visual = Polygon2D.new()
    visual.polygon = PackedVector2Array([
        Vector2(-46, -23), Vector2(46, -23), Vector2(46, 23), Vector2(-46, 23),
    ])
    add_child(visual)

    rng.randomize()
    _enter_state(State.SAFE)

func _enter_state(s: int) -> void:
    state = s
    match s:
        State.SAFE:
            timer = rng.randf_range(1.8, 3.2)
            visual.color = Color(0.32, 0.32, 0.35, 0.55)
        State.WARNING:
            timer = 0.65
            visual.color = Color(0.95, 0.55, 0.1, 0.8)
        State.ERUPTING:
            timer = rng.randf_range(0.4, 0.6)
            visual.color = Color(1.0, 0.3, 0.12, 0.95)
            Sfx.play_at("vent_blast", global_position)

func _process(delta: float) -> void:
    timer -= delta
    if state == State.WARNING:
        pulse_t += delta
        visual.scale = Vector2.ONE * (1.0 + 0.12 * sin(pulse_t * 18.0))
    else:
        visual.scale = Vector2.ONE

    if timer <= 0.0:
        match state:
            State.SAFE:
                _enter_state(State.WARNING)
            State.WARNING:
                _enter_state(State.ERUPTING)
            State.ERUPTING:
                _enter_state(State.SAFE)

    if state == State.ERUPTING:
        for body in get_overlapping_bodies():
            if body.is_in_group("player"):
                body.hit_by_hazard("vented into the void")
