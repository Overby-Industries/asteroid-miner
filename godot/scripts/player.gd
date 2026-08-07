extends CharacterBody2D
class_name PlayerRig

const Constants = preload("res://scripts/constants.gd")
const Terrain = preload("res://scripts/terrain.gd")

# Thruster-controlled mining rig. Moves like a light lander (gravity +
# directional thrust) rather than a platformer -- fits digging in every
# direction, and running dry on fuel means losing control, not stopping dead.
# The rig always rotates to face wherever you're pushing, and the drill nose
# only bites rock while the left mouse button is held -- movement alone no
# longer digs.

signal died(reason: String)
signal cargo_banked(credit_value: int, fuel_ore: int, gold: int, nickel: int)

const GRAVITY := 260.0
const FRICTION := 340.0

const DIG_RATE_CRACKED_MULT := 1.6
const DIG_REACH := 20.0

const O2_DRAIN := 0.15           # per second, passive -- tuned for ~10-11 min per dive
const DOCK_REFILL_RATE := 60.0

# Base values for stats the upgrade track (see upgrades.gd) scales. Kept as
# mutable instance vars (not const) below so Upgrades.apply() can grow them
# per-run; _BASE is what a fresh, un-upgraded PlayerRig starts at.
const THRUST_ACCEL_BASE := 620.0
const DOWN_THRUST_ACCEL_BASE := 420.0
const SIDE_ACCEL_BASE := 520.0
const MAX_SPEED_BASE := 220.0
const DIG_RATE_BASE := 2.4
const FUEL_MAX_BASE := 100.0
const O2_MAX_BASE := 100.0
const FUEL_THRUST_DRAIN_BASE := 0.35  # per second while any thruster fires (includes digging pushes)

# See art/sprites/README.md -- if a pre-rendered hull image lands at this
# path, _ready() uses it instead of the procedural hull polygon. Rendered
# at any resolution and scaled to fit HULL_SPRITE_SIZE (world units), so
# export size doesn't need to match gameplay size exactly.
const HULL_SPRITE_PATH := "res://art/sprites/player_ship.png"
const HULL_SPRITE_SIZE := Vector2(26, 20)

var terrain: Terrain = null

var thrust_accel := THRUST_ACCEL_BASE
var down_thrust_accel := DOWN_THRUST_ACCEL_BASE
var side_accel := SIDE_ACCEL_BASE
var max_speed := MAX_SPEED_BASE
var dig_rate := DIG_RATE_BASE
var fuel_max := FUEL_MAX_BASE
var o2_max := O2_MAX_BASE
var fuel_thrust_drain := FUEL_THRUST_DRAIN_BASE
var can_wall_grip := false

var fuel := FUEL_MAX_BASE
var o2 := O2_MAX_BASE
var cargo_gold := 0
var cargo_nickel := 0
var cargo_fuel_ore := 0
var cargo_credit_value := 0
var docked := false
var alive := true
var control_enabled := true
var heat_drain := 0.0

var dig_progress := 0.0
var dig_target := Vector2i(-99999, -99999)
var facing_angle := 0.0

var flame_poly: Polygon2D
var drill_poly: Polygon2D
var thruster_player: AudioStreamPlayer2D
var _alarm_cooldown := 0.0

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

    if ResourceLoader.exists(HULL_SPRITE_PATH):
        var hull_sprite := Sprite2D.new()
        var hull_tex: Texture2D = load(HULL_SPRITE_PATH)
        hull_sprite.texture = hull_tex
        hull_sprite.scale = HULL_SPRITE_SIZE / hull_tex.get_size()
        add_child(hull_sprite)
    else:
        var body_poly := Polygon2D.new()
        body_poly.color = Color(0.78, 0.82, 0.86)
        body_poly.polygon = PackedVector2Array([
            Vector2(-11, -9), Vector2(11, -9), Vector2(11, 9), Vector2(-11, 9),
        ])
        add_child(body_poly)

    drill_poly = Polygon2D.new()
    drill_poly.color = Color(0.92, 0.58, 0.18)
    drill_poly.polygon = PackedVector2Array([Vector2(11, -6), Vector2(19, 0), Vector2(11, 6)])
    add_child(drill_poly)

    flame_poly = Polygon2D.new()
    flame_poly.color = Color(1.0, 0.65, 0.2, 0.9)
    flame_poly.polygon = PackedVector2Array([Vector2(-11, -6), Vector2(-19, 0), Vector2(-11, 6)])
    flame_poly.visible = false
    add_child(flame_poly)

    thruster_player = AudioStreamPlayer2D.new()
    thruster_player.stream = Sfx.stream("thruster_loop")
    thruster_player.volume_db = -8.0
    add_child(thruster_player)

func _physics_process(delta: float) -> void:
    if not alive or not control_enabled:
        velocity = Vector2.ZERO
        if thruster_player.playing:
            thruster_player.stop()
        return

    var input_dir := _read_move_input()

    if input_dir != Vector2.ZERO:
        facing_angle = input_dir.angle()
    rotation = facing_angle

    # Wall Grip (upgrade): once unlocked, holding a direction INTO whatever
    # solid surface the ship is already touching anchors it there -- no
    # gravity, no drift, no fuel burned just to hold position while digging
    # into a wall/ceiling with no floor below. is_on_wall()/is_on_ceiling()
    # reflect LAST frame's move_and_slide() result, checked here before this
    # frame's move_and_slide() runs -- the standard Godot coyote-check idiom.
    # Gating on current input pointing into the collision normal (not just
    # contact) is what makes detaching automatic: the moment input goes
    # neutral or points away, this falls straight through to normal physics.
    var gripped := can_wall_grip and (is_on_wall() or is_on_ceiling())
    var pushing_into_grip := false
    if gripped and input_dir != Vector2.ZERO:
        var col := get_last_slide_collision()
        if col != null and input_dir.normalized().dot(col.get_normal()) < -0.1:
            pushing_into_grip = true

    var thrust_active := false
    if pushing_into_grip:
        velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
    elif fuel > 0.0:
        if input_dir.x != 0.0:
            velocity.x = move_toward(velocity.x, input_dir.x * max_speed, side_accel * delta)
            thrust_active = true
        else:
            velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

        if input_dir.y < 0.0:
            velocity.y = move_toward(velocity.y, -max_speed, thrust_accel * delta)
            thrust_active = true
        elif input_dir.y > 0.0:
            velocity.y = move_toward(velocity.y, max_speed * 0.8, down_thrust_accel * delta)
            thrust_active = true
        else:
            velocity.y += GRAVITY * delta
    else:
        velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
        velocity.y += GRAVITY * delta

    velocity.y = clamp(velocity.y, -max_speed, max_speed * 1.4)
    flame_poly.visible = thrust_active

    if thrust_active and not docked and not thruster_player.playing:
        thruster_player.play()
    elif (not thrust_active or docked) and thruster_player.playing:
        thruster_player.stop()

    move_and_slide()

    var digging := _handle_digging(input_dir, delta)
    drill_poly.color = Color(1.0, 0.35, 0.1) if digging else Color(0.92, 0.58, 0.18)

    _tick_resources(delta, thrust_active)

    if docked:
        o2 = min(o2_max, o2 + DOCK_REFILL_RATE * delta)
        fuel = min(fuel_max, fuel + DOCK_REFILL_RATE * delta)
    elif o2 <= 0.0:
        hit_by_hazard("ran out of oxygen")

    _tick_alarm(delta)

func _tick_alarm(delta: float) -> void:
    _alarm_cooldown -= delta
    if alive and not docked and (o2 < 20.0 or fuel < 20.0) and _alarm_cooldown <= 0.0:
        Sfx.play("low_resource_alarm")
        _alarm_cooldown = 1.2

func _read_move_input() -> Vector2:
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

func _handle_digging(input_dir: Vector2, delta: float) -> bool:
    var lmb_held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
    if not lmb_held or input_dir == Vector2.ZERO or terrain == null or fuel <= 0.0:
        dig_progress = 0.0
        dig_target = Vector2i(-99999, -99999)
        return false

    var probe_world := global_position + input_dir.normalized() * DIG_REACH
    var cell := terrain.local_to_map(terrain.to_local(probe_world))
    if not terrain.is_diggable(cell):
        dig_progress = 0.0
        dig_target = Vector2i(-99999, -99999)
        return false

    if cell != dig_target:
        dig_target = cell
        dig_progress = 0.0

    var rate := dig_rate
    if terrain.get_tile(cell) == Constants.Tile.CRACKED:
        rate *= DIG_RATE_CRACKED_MULT
    dig_progress += rate * delta

    if dig_progress >= 1.0:
        dig_progress = 0.0
        var tile_before := terrain.get_tile(cell)
        terrain.dig(cell, self)
        var depth_m := terrain.depth_meters(cell)
        Sfx.play_at("dig_hit", global_position)
        match tile_before:
            Constants.Tile.GOLD_ORE:
                cargo_gold += 1
                cargo_credit_value += int(14 + depth_m * 0.8)
                Sfx.play_at("ore_pickup_gold", global_position)
            Constants.Tile.NICKEL_ORE:
                cargo_nickel += 1
                cargo_credit_value += int(6 + depth_m * 0.3)
                Sfx.play_at("ore_pickup_nickel", global_position)
            Constants.Tile.FUEL_ORE:
                cargo_fuel_ore += 1
                Sfx.play_at("ore_pickup_fuel", global_position)
    return true

func _tick_resources(delta: float, thrust_active: bool) -> void:
    if docked:
        return
    o2 -= O2_DRAIN * delta
    if heat_drain > 0.0:
        o2 -= heat_drain * delta
    if thrust_active:
        fuel = max(0.0, fuel - fuel_thrust_drain * delta)
    o2 = clamp(o2, 0.0, o2_max)
    fuel = clamp(fuel, 0.0, fuel_max)

func set_docked(is_docked: bool) -> void:
    var was_docked := docked
    docked = is_docked
    if is_docked and not was_docked and (cargo_gold > 0 or cargo_nickel > 0 or cargo_fuel_ore > 0):
        cargo_banked.emit(cargo_credit_value, cargo_fuel_ore, cargo_gold, cargo_nickel)
        cargo_gold = 0
        cargo_nickel = 0
        cargo_fuel_ore = 0
        cargo_credit_value = 0

func enter_heat(rate: float) -> void:
    heat_drain += rate

func exit_heat(rate: float) -> void:
    heat_drain = max(0.0, heat_drain - rate)

func hit_by_hazard(reason: String) -> void:
    if not alive:
        return
    alive = false
    velocity = Vector2.ZERO
    if thruster_player.playing:
        thruster_player.stop()
    Sfx.play("death_buzz")
    died.emit(reason)

func respawn_at(spawn_pos: Vector2) -> void:
    global_position = spawn_pos
    rotation = 0.0
    facing_angle = 0.0
    velocity = Vector2.ZERO
    fuel = fuel_max
    o2 = o2_max
    heat_drain = 0.0
    cargo_gold = 0
    cargo_nickel = 0
    cargo_fuel_ore = 0
    cargo_credit_value = 0
    dig_progress = 0.0
    alive = true
