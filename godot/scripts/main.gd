extends Node2D

const Constants = preload("res://scripts/constants.gd")
const Terrain = preload("res://scripts/terrain.gd")
const PlayerRig = preload("res://scripts/player.gd")
const Mothership = preload("res://scripts/mothership.gd")
const SurfaceVent = preload("res://scripts/surface_vent.gd")
const HUD = preload("res://scripts/hud.gd")
const LevelConfig = preload("res://scripts/levels/level_config.gd")

var terrain: Terrain
var player: PlayerRig
var mothership: Mothership
var vent: SurfaceVent
var hud: HUD
var camera: Camera2D

var level_index := 0
var level_config: LevelConfig
var run_score := 0
var fuel_ore_banked := 0
var run_active := true

func _ready() -> void:
    hud = HUD.new()
    add_child(hud)
    _new_game()

func _new_game() -> void:
    level_index = 0
    level_config = LevelConfig.for_level(level_index)
    run_score = 0
    fuel_ore_banked = 0
    run_active = true
    hud.hide_game_over()

    _build_terrain_and_hazards()

    player = PlayerRig.new()
    player.terrain = terrain
    player.position = terrain.get_spawn_world_pos()
    player.died.connect(_on_player_died)
    player.cargo_banked.connect(_on_cargo_banked)
    add_child(player)
    player.set_docked(true)

    camera = Camera2D.new()
    camera.zoom = Vector2(2.0, 2.0)
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 6.0
    player.add_child(camera)
    camera.make_current()
    _update_camera_limits()

func _advance_level() -> void:
    level_index += 1
    fuel_ore_banked = 0
    level_config = LevelConfig.for_level(level_index)

    _build_terrain_and_hazards()
    player.terrain = terrain
    player.respawn_at(terrain.get_spawn_world_pos())
    _update_camera_limits()
    hud.show_level_banner(level_config.level_name, level_index + 1)

func _respawn_after_death() -> void:
    run_active = true
    hud.hide_game_over()
    player.respawn_at(terrain.get_spawn_world_pos())
    player.set_docked(true)

func _build_terrain_and_hazards() -> void:
    for n in [terrain, mothership, vent]:
        if n != null and is_instance_valid(n):
            n.queue_free()

    terrain = Terrain.new()
    add_child(terrain)
    terrain.generate(randi(), level_config)

    var spawn_pos: Vector2 = terrain.get_spawn_world_pos()

    mothership = Mothership.new()
    mothership.position = spawn_pos + Vector2(0, -6)
    add_child(mothership)

    var mid := int(Constants.GRID_WIDTH / 2)
    vent = SurfaceVent.new()
    vent.position = terrain.map_to_local(Vector2i(mid, Constants.SURFACE_ROW + 3))
    add_child(vent)

func _update_camera_limits() -> void:
    camera.limit_left = 0
    camera.limit_right = Constants.GRID_WIDTH * Constants.CELL_SIZE
    camera.limit_top = -500
    camera.limit_bottom = Constants.GRID_HEIGHT * Constants.CELL_SIZE

func _process(_delta: float) -> void:
    if player == null or not is_instance_valid(player) or terrain == null:
        return

    var depth := int(terrain.depth_at_world_y(player.global_position.y))
    hud.update_stats(
        player.o2, player.fuel,
        player.cargo_gold, player.cargo_nickel, player.cargo_fuel_ore, player.cargo_credit_value,
        run_score, depth,
        level_config.level_name, level_index + 1,
        fuel_ore_banked, level_config.fuel_ore_quota
    )
    hud.update_minimap(float(depth) / float(Constants.GRID_DEPTH), depth, Constants.GRID_DEPTH, fuel_ore_banked, level_config.fuel_ore_quota)

func _on_cargo_banked(credit_value: int, fuel_ore: int, _gold: int, _nickel: int) -> void:
    run_score += credit_value
    fuel_ore_banked += fuel_ore
    if fuel_ore_banked >= level_config.fuel_ore_quota:
        _advance_level()

func _on_player_died(reason: String) -> void:
    run_active = false
    var depth := terrain.depth_at_world_y(player.global_position.y)
    hud.show_game_over(reason, run_score, int(depth))

func _unhandled_key_input(event: InputEvent) -> void:
    if run_active or not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
        _respawn_after_death()
