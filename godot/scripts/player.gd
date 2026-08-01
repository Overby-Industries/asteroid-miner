extends CharacterBody2D
class_name PlayerRig

const Constants = preload("res://scripts/constants.gd")
const Terrain = preload("res://scripts/terrain.gd")

# Thruster-controlled mining rig. Moves like a light lander (gravity +
# directional thrust) rather than a platformer -- fits digging in every
# direction, and running dry on fuel means losing control, not stopping dead.

signal died(reason: String)
signal cargo_banked(value: int, count: int)

const GRAVITY := 260.0
const THRUST_ACCEL := 620.0
const DOWN_THRUST_ACCEL := 420.0
const SIDE_ACCEL := 520.0
const MAX_SPEED := 220.0
const FRICTION := 340.0

const DIG_RATE := 2.4
const DIG_RATE_CRACKED_MULT := 1.6
const DIG_REACH := 20.0
const FUEL_DIG_COST := 2.5

const FUEL_MAX := 100.0
const O2_MAX := 100.0
const FUEL_THRUST_DRAIN := 11.0
const O2_DRAIN := 2.6
const DOCK_REFILL_RATE := 60.0

var terrain: Terrain = null

var fuel := FUEL_MAX
var o2 := O2_MAX
var cargo_count := 0
var cargo_value := 0
var docked := false
var alive := true
var heat_drain := 0.0

var dig_progress := 0.0
var dig_target := Vector2i(-99999, -99999)

var body_poly: Polygon2D
var flame_poly: Polygon2D

func _ready() -> void:
    add_to_group("player")
    set_collision_layer_value(1, false)
    set_collision_layer_value(2, true)
    set_collision_mask_value(1, true)
    set_collision_mask_value(2, false)

    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(22, 22)
    shape.shape = rect
    add_child(shape)

    body_poly = Polygon2D.new()
    body_poly.color = Color(0.78, 0.82, 0.86)
    body_poly.polygon = PackedVector2Array([
        Vector2(-11, -9), Vector2(11, -9), Vector2(11, 9), Vector2(-11, 9),
    ])
    add_child(body_poly)

    var drill := Polygon2D.new()
    drill.color = Color(0.92, 0.58, 0.18)
    drill.polygon = PackedVector2Array([Vector2(11, -6), Vector2(19, 0), Vector2(11, 6)])
    add_child(drill)

    flame_poly = Polygon2D.new()
    flame_poly.color = Color(1.0, 0.65, 0.2, 0.9)
    flame_poly.polygon = PackedVector2Array([Vector2(-7, 9), Vector2(7, 9), Vector2(0, 18)])
    flame_poly.visible = false
    add_child(flame_poly)

func _physics_process(delta: float) -> void:
    if not alive:
        velocity = Vector2.ZERO
        return

    var input_dir := _read_input()

    if input_dir.x != 0.0:
        body_poly.scale.x = 1.0 if input_dir.x > 0 else -1.0

    var thrust_active := false
    if fuel > 0.0:
        if input_dir.x != 0.0:
            velocity.x = move_toward(velocity.x, input_dir.x * MAX_SPEED, SIDE_ACCEL * delta)
            thrust_active = true
        else:
            velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

        if input_dir.y < 0.0:
            velocity.y = move_toward(velocity.y, -MAX_SPEED, THRUST_ACCEL * delta)
            thrust_active = true
        elif input_dir.y > 0.0:
            velocity.y = move_toward(velocity.y, MAX_SPEED * 0.8, DOWN_THRUST_ACCEL * delta)
            thrust_active = true
        else:
            velocity.y += GRAVITY * delta
    else:
        velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
        velocity.y += GRAVITY * delta

    velocity.y = clamp(velocity.y, -MAX_SPEED, MAX_SPEED * 1.4)
    flame_poly.visible = thrust_active and input_dir.y < 0.0

    move_and_slide()

    _handle_digging(input_dir, delta)
    _tick_resources(delta, thrust_active)

    if docked:
        o2 = min(O2_MAX, o2 + DOCK_REFILL_RATE * delta)
        fuel = min(FUEL_MAX, fuel + DOCK_REFILL_RATE * delta)
    elif o2 <= 0.0:
        hit_by_hazard("ran out of oxygen")

func _read_input() -> Vector2:
    var d := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        d.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        d.x += 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE):
        d.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        d.y += 1.0
    return d

func _handle_digging(input_dir: Vector2, delta: float) -> void:
    if input_dir == Vector2.ZERO or terrain == null or fuel <= 0.0:
        dig_progress = 0.0
        dig_target = Vector2i(-99999, -99999)
        return

    var probe_world := global_position + input_dir.normalized() * DIG_REACH
    var cell := terrain.local_to_map(terrain.to_local(probe_world))
    if not terrain.is_diggable(cell):
        dig_progress = 0.0
        dig_target = Vector2i(-99999, -99999)
        return

    if cell != dig_target:
        dig_target = cell
        dig_progress = 0.0

    var rate := DIG_RATE
    if terrain.get_tile(cell) == Constants.Tile.CRACKED:
        rate *= DIG_RATE_CRACKED_MULT
    dig_progress += rate * delta

    if dig_progress >= 1.0:
        dig_progress = 0.0
        var tile_before := terrain.get_tile(cell)
        terrain.dig(cell, self)
        if tile_before == Constants.Tile.ORE:
            var depth_m := terrain.depth_meters(cell)
            cargo_count += 1
            cargo_value += int(10 + depth_m * 0.6)
        fuel = max(0.0, fuel - FUEL_DIG_COST)

func _tick_resources(delta: float, thrust_active: bool) -> void:
    if docked:
        return
    o2 -= O2_DRAIN * delta
    if heat_drain > 0.0:
        o2 -= heat_drain * delta
    if thrust_active:
        fuel = max(0.0, fuel - FUEL_THRUST_DRAIN * delta)
    o2 = clamp(o2, 0.0, O2_MAX)
    fuel = clamp(fuel, 0.0, FUEL_MAX)

func set_docked(is_docked: bool) -> void:
    var was_docked := docked
    docked = is_docked
    if is_docked and not was_docked and cargo_count > 0:
        cargo_banked.emit(cargo_value, cargo_count)
        cargo_count = 0
        cargo_value = 0

func enter_heat(rate: float) -> void:
    heat_drain += rate

func exit_heat(rate: float) -> void:
    heat_drain = max(0.0, heat_drain - rate)

func hit_by_hazard(reason: String) -> void:
    if not alive:
        return
    alive = false
    velocity = Vector2.ZERO
    died.emit(reason)
