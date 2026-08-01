extends Node2D

const Constants = preload("res://scripts/constants.gd")
const Terrain = preload("res://scripts/terrain.gd")
const PlayerRig = preload("res://scripts/player.gd")
const Mothership = preload("res://scripts/mothership.gd")
const SurfaceVent = preload("res://scripts/surface_vent.gd")
const HUD = preload("res://scripts/hud.gd")

var terrain: Terrain
var player: PlayerRig
var mothership: Mothership
var vent: SurfaceVent
var hud: HUD
var camera: Camera2D

var run_score := 0
var run_active := true

func _ready() -> void:
    hud = HUD.new()
    add_child(hud)
    _start_run()

func _start_run() -> void:
    for n in [terrain, player, mothership, vent]:
        if n != null and is_instance_valid(n):
            n.queue_free()

    run_score = 0
    run_active = true
    hud.hide_game_over()

    terrain = Terrain.new()
    add_child(terrain)
    terrain.generate(randi())

    var spawn_pos: Vector2 = terrain.get_spawn_world_pos()

    player = PlayerRig.new()
    player.terrain = terrain
    player.position = spawn_pos
    player.died.connect(_on_player_died)
    player.cargo_banked.connect(_on_cargo_banked)
    add_child(player)

    camera = Camera2D.new()
    camera.zoom = Vector2(2.0, 2.0)
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 6.0
    camera.limit_left = 0
    camera.limit_right = Constants.GRID_WIDTH * Constants.CELL_SIZE
    camera.limit_top = -500
    camera.limit_bottom = Constants.GRID_HEIGHT * Constants.CELL_SIZE
    player.add_child(camera)
    camera.make_current()

    mothership = Mothership.new()
    mothership.position = spawn_pos + Vector2(0, -6)
    add_child(mothership)

    var mid := int(Constants.GRID_WIDTH / 2)
    vent = SurfaceVent.new()
    vent.position = terrain.map_to_local(Vector2i(mid, Constants.SURFACE_ROW + 3))
    add_child(vent)

func _process(_delta: float) -> void:
    if not run_active or player == null or not is_instance_valid(player):
        return
    var depth := terrain.depth_at_world_y(player.global_position.y)
    hud.update_stats(player.o2, player.fuel, player.cargo_count, player.cargo_value, int(depth), run_score)

func _on_cargo_banked(value: int, _count: int) -> void:
    run_score += value

func _on_player_died(reason: String) -> void:
    run_active = false
    var depth := terrain.depth_at_world_y(player.global_position.y)
    hud.show_game_over(reason, run_score, int(depth))

func _unhandled_key_input(event: InputEvent) -> void:
    if run_active or not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
        _start_run()
