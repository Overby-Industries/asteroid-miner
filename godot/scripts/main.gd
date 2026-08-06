extends Node2D

const Constants = preload("res://scripts/constants.gd")
const Terrain = preload("res://scripts/terrain.gd")
const PlayerRig = preload("res://scripts/player.gd")
const Mothership = preload("res://scripts/mothership.gd")
const SurfaceVent = preload("res://scripts/surface_vent.gd")
const HUD = preload("res://scripts/hud.gd")
const MainMenu = preload("res://scripts/ui/main_menu.gd")
const PauseMenu = preload("res://scripts/ui/pause_menu.gd")
const LevelConfig = preload("res://scripts/levels/level_config.gd")

enum GameState { MENU, CUTSCENE, PLAYING }

var terrain: Terrain
var player: PlayerRig
var mothership: Mothership
var vent: SurfaceVent
var hud: HUD
var menu: MainMenu
var pause_menu: PauseMenu
var camera: Camera2D

var state: GameState = GameState.MENU
var skip_requested := false
var level_index := 0
var level_config: LevelConfig
var run_score := 0
var fuel_ore_banked := 0
var run_active := true

const GAMEPLAY_ZOOM := Vector2(2.0, 2.0)
const CUTSCENE_ZOOM := Vector2(1.3, 1.3)
const MOTHERSHIP_DROP_HEIGHT := 900.0
const MOTHERSHIP_DESCENT_TIME := 2.2
const CUTSCENE_HOLD_TIME := 1.6
const FADE_TIME := 0.35

func _ready() -> void:
    hud = HUD.new()
    add_child(hud)
    hud.set_gameplay_panels_visible(false)

    camera = Camera2D.new()
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 6.0
    add_child(camera)
    camera.make_current()

    menu = MainMenu.new()
    add_child(menu)

    pause_menu = PauseMenu.new()
    add_child(pause_menu)

func _start_game() -> void:
    menu.visible = false
    level_index = 0
    level_config = LevelConfig.for_level(level_index)
    run_score = 0
    fuel_ore_banked = 0
    run_active = true
    hud.hide_game_over()
    await _play_landing_cutscene()

func _advance_level() -> void:
    level_index += 1
    fuel_ore_banked = 0
    level_config = LevelConfig.for_level(level_index)
    await _play_landing_cutscene()

func _respawn_after_death() -> void:
    run_active = true
    hud.hide_game_over()
    player.respawn_at(terrain.get_spawn_world_pos())
    player.set_docked(true)

# Builds the new asteroid, then plays the ship's descent -- thruster burn,
# touchdown bounce, camera shake, dust, a beat to look at it, a level title
# card -- before fading into (or back into) player control. Shared by the
# very first launch and every level transition; the only difference is
# whether `player` already exists.
func _play_landing_cutscene() -> void:
    state = GameState.CUTSCENE
    skip_requested = false
    pause_menu.set_enabled(false)
    hud.set_gameplay_panels_visible(false)
    if player:
        player.visible = false
        player.control_enabled = false

    _build_terrain_and_hazards()
    var spawn_pos: Vector2 = terrain.get_spawn_world_pos()
    var landing_pos: Vector2 = mothership.position
    _update_camera_limits()

    camera.zoom = CUTSCENE_ZOOM
    camera.global_position = landing_pos

    hud.show_title_card("LEVEL %d" % (level_index + 1), level_config.level_name)

    var descent_tween := mothership.begin_landing(landing_pos, MOTHERSHIP_DROP_HEIGHT, MOTHERSHIP_DESCENT_TIME)
    await _wait_for_tween(descent_tween, func(): mothership.finish_landing_immediately(landing_pos))

    if not skip_requested:
        _play_impact_effects(landing_pos)
        var hold_tween := create_tween()
        hold_tween.tween_interval(CUTSCENE_HOLD_TIME)
        await _wait_for_tween(hold_tween, func(): pass)

    hud.hide_title_card()
    await hud.fade_to_black(FADE_TIME)

    if player == null:
        player = PlayerRig.new()
        player.died.connect(_on_player_died)
        player.cargo_banked.connect(_on_cargo_banked)
        add_child(player)
    player.terrain = terrain
    player.respawn_at(spawn_pos)
    player.visible = true
    player.control_enabled = true
    player.set_docked(true)

    camera.zoom = GAMEPLAY_ZOOM
    camera.global_position = player.global_position

    hud.set_gameplay_panels_visible(true)
    state = GameState.PLAYING
    pause_menu.set_enabled(true)
    await hud.fade_from_black(FADE_TIME)

# Awaits a Tween to finish naturally, unless skip_requested gets set first --
# then it kills the tween and calls on_skip() to jump straight to whatever
# end-state the tween would have produced. skip_requested is set from an
# actual keypress *event* in _unhandled_key_input, not polled key state --
# polling Input.is_key_pressed() here would immediately "see" the still-held
# SPACE that was used to start the cutscene in the first place and skip it
# instantly, which is exactly the bug this used to have.
func _wait_for_tween(tween: Tween, on_skip: Callable) -> void:
    while is_instance_valid(tween) and tween.is_valid() and tween.is_running():
        if skip_requested:
            tween.kill()
            on_skip.call()
            return
        await get_tree().process_frame

func _play_impact_effects(pos: Vector2) -> void:
    _shake_camera(10.0, 0.3)
    _spawn_dust_puffs(pos)

func _shake_camera(strength: float, duration: float) -> void:
    var elapsed := 0.0
    while elapsed < duration:
        camera.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
        await get_tree().create_timer(0.03).timeout
        elapsed += 0.03
    camera.offset = Vector2.ZERO

func _spawn_dust_puffs(pos: Vector2) -> void:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    for i in range(8):
        var puff := Polygon2D.new()
        puff.color = Color(0.6, 0.55, 0.5, 0.55)
        var r := rng.randf_range(4.0, 7.0)
        var pts := PackedVector2Array()
        for j in range(8):
            var a := TAU * float(j) / 8.0
            pts.append(Vector2(cos(a), sin(a)) * r)
        puff.polygon = pts
        puff.position = pos + Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-4.0, 4.0))
        add_child(puff)

        var dir := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.6, -0.1)).normalized()
        var target := puff.position + dir * rng.randf_range(40.0, 90.0)
        var tw := puff.create_tween()
        tw.set_parallel(true)
        tw.tween_property(puff, "position", target, 0.5)
        tw.tween_property(puff, "modulate:a", 0.0, 0.5)
        tw.chain().tween_callback(puff.queue_free)

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
    camera.limit_top = -1000
    camera.limit_bottom = Constants.GRID_HEIGHT * Constants.CELL_SIZE

func _process(_delta: float) -> void:
    if state == GameState.PLAYING:
        camera.global_position = player.global_position

    if state != GameState.PLAYING or player == null or not is_instance_valid(player) or terrain == null:
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
    Sfx.play("dock_chime")
    if fuel_ore_banked >= level_config.fuel_ore_quota:
        Sfx.play("level_complete_sweep")
        _advance_level()

func _on_player_died(reason: String) -> void:
    run_active = false
    var depth := terrain.depth_at_world_y(player.global_position.y)
    hud.show_game_over(reason, run_score, int(depth))

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    var key_event := event as InputEventKey
    match state:
        GameState.MENU:
            if key_event.keycode == KEY_SPACE or key_event.keycode == KEY_ENTER:
                Sfx.play("menu_blip")
                _start_game()
        GameState.PLAYING:
            if not run_active and key_event.keycode == KEY_R:
                _respawn_after_death()
        GameState.CUTSCENE:
            if key_event.keycode == KEY_ENTER and not skip_requested:
                Sfx.play("menu_blip")
                skip_requested = true
