extends TileMapLayer
class_name Terrain

const Constants = preload("res://scripts/constants.gd")
const FallingRock = preload("res://scripts/falling_rock.gd")
const HeatVent = preload("res://scripts/heat_vent.gd")
const LevelConfig = preload("res://scripts/levels/level_config.gd")

# Procedurally generated asteroid body. Sparse grid dictionary (rather than a
# fixed array) since most gameplay-relevant lookups are near the player, not
# a full-grid scan. Rows above SURFACE_ROW are implicitly empty (open space).

signal collapse_triggered(cell: Vector2i)

var grid: Dictionary = {}
var collapsing: Dictionary = {}
var rng := RandomNumberGenerator.new()
var config: LevelConfig

func generate(seed_value: int, level_config: LevelConfig) -> void:
    config = level_config
    rng.seed = seed_value
    tile_set = _build_tile_set()
    grid.clear()
    collapsing.clear()
    clear()

    var noise := FastNoiseLite.new()
    noise.seed = seed_value
    noise.frequency = config.noise_frequency
    noise.fractal_octaves = 3

    for y in range(Constants.SURFACE_ROW, Constants.GRID_HEIGHT):
        var depth := y - Constants.SURFACE_ROW
        var depth_t := float(depth) / float(Constants.GRID_DEPTH)
        for x in range(Constants.GRID_WIDTH):
            var cell := Vector2i(x, y)

            if y >= Constants.GRID_HEIGHT - 1:
                _set_tile(cell, Constants.Tile.BEDROCK)
                continue

            if noise.get_noise_2d(x, y) > 0.35:
                continue # natural cave pocket -- left empty

            var t := _roll_tile_type(depth_t)
            _set_tile(cell, t)
            if t == Constants.Tile.HEAT_CORE:
                _spawn_heat_vent(cell)

    _carve_landing_shaft()

func _roll_tile_type(depth_t: float) -> int:
    var roll := rng.randf()

    var p_gold: float = lerp(0.015, 0.045, depth_t)
    if roll < p_gold:
        return Constants.Tile.GOLD_ORE
    roll -= p_gold

    var p_nickel: float = lerp(0.02, 0.05, depth_t)
    if roll < p_nickel:
        return Constants.Tile.NICKEL_ORE
    roll -= p_nickel

    var p_fuel: float = lerp(0.008, 0.035, depth_t)
    if roll < p_fuel:
        return Constants.Tile.FUEL_ORE
    roll -= p_fuel

    var p_cracked := 0.05 * config.hazard_density
    if roll < p_cracked:
        return Constants.Tile.CRACKED
    roll -= p_cracked

    if depth_t > 0.35:
        var p_heat: float = lerp(0.0, 0.05, (depth_t - 0.35) / 0.65) * config.hazard_density
        if roll < p_heat:
            return Constants.Tile.HEAT_CORE

    return Constants.Tile.ROCK

func get_spawn_world_pos() -> Vector2:
    return map_to_local(Vector2i(Constants.GRID_WIDTH / 2, Constants.SURFACE_ROW - 1))

func depth_at_world_y(world_y: float) -> float:
    return max(0.0, floor(world_y / float(Constants.CELL_SIZE)) - Constants.SURFACE_ROW)

func depth_meters(cell: Vector2i) -> float:
    return max(0.0, float(cell.y - Constants.SURFACE_ROW))

func get_tile(cell: Vector2i) -> int:
    return grid.get(cell, Constants.Tile.EMPTY)

func is_solid(cell: Vector2i) -> bool:
    return get_tile(cell) != Constants.Tile.EMPTY

func is_diggable(cell: Vector2i) -> bool:
    var t := get_tile(cell)
    return t != Constants.Tile.EMPTY and t != Constants.Tile.BEDROCK

func fill_rubble(cell: Vector2i) -> void:
    if get_tile(cell) == Constants.Tile.EMPTY:
        _set_tile(cell, Constants.Tile.ROCK)

func dig(cell: Vector2i, digger: Node) -> void:
    var t := get_tile(cell)
    if not is_diggable(cell):
        return
    var was_heat_core := t == Constants.Tile.HEAT_CORE
    _clear_tile(cell)
    _check_collapse_neighbors(cell)
    if was_heat_core and digger != null and digger.has_method("hit_by_hazard"):
        digger.hit_by_hazard("melted by a breached magma vent")

func _carve_landing_shaft() -> void:
    var cx := Constants.GRID_WIDTH / 2
    for y in range(Constants.SURFACE_ROW, Constants.SURFACE_ROW + 5):
        for x in range(cx - 1, cx + 2):
            _clear_tile(Vector2i(x, y))

func _check_collapse_neighbors(cell: Vector2i) -> void:
    var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
    for dir in directions:
        var n: Vector2i = cell + dir
        if get_tile(n) == Constants.Tile.CRACKED and not collapsing.has(n):
            _begin_collapse(n)

func _begin_collapse(cell: Vector2i) -> void:
    collapsing[cell] = true
    var delay := rng.randf_range(0.35, 0.75)
    await get_tree().create_timer(delay).timeout
    collapsing.erase(cell)
    if not is_instance_valid(self) or get_tile(cell) != Constants.Tile.CRACKED:
        return
    _clear_tile(cell)
    collapse_triggered.emit(cell)
    _spawn_falling_rock(cell)
    _check_collapse_neighbors(cell)

func _spawn_falling_rock(cell: Vector2i) -> void:
    var rock := FallingRock.new()
    rock.terrain = self
    rock.position = map_to_local(cell)
    get_parent().add_child(rock)

func _spawn_heat_vent(cell: Vector2i) -> void:
    var vent := HeatVent.new()
    vent.position = map_to_local(cell)
    # Parented to the terrain itself (not get_parent()) so it's freed
    # automatically when this terrain generation is torn down on a level
    # transition -- otherwise every past level's heat vents would linger
    # forever, invisible but still live hazards at their old coordinates.
    add_child(vent)

func _set_tile(cell: Vector2i, tile: int) -> void:
    grid[cell] = tile
    set_cell(cell, 0, Vector2i(tile, 0))

func _clear_tile(cell: Vector2i) -> void:
    grid[cell] = Constants.Tile.EMPTY
    erase_cell(cell)

func _build_tile_set() -> TileSet:
    # Index order must match Constants.Tile's atlas-coordinate values.
    var colors := [
        config.rock_color,
        config.gold_color,
        config.nickel_color,
        config.fuel_ore_color,
        config.cracked_color,
        config.heat_color,
        config.bedrock_color,
    ]
    var glinted := [
        false, true, true, true, false, false, false,
    ]
    var img := Image.create_empty(Constants.CELL_SIZE * colors.size(), Constants.CELL_SIZE, false, Image.FORMAT_RGBA8)
    for i in range(colors.size()):
        _paint_tile(img, i, colors[i], glinted[i])
    var tex := ImageTexture.create_from_image(img)

    var ts := TileSet.new()
    ts.tile_size = Vector2i(Constants.CELL_SIZE, Constants.CELL_SIZE)
    ts.add_physics_layer()
    ts.set_physics_layer_collision_layer(0, 1)
    ts.set_physics_layer_collision_mask(0, 0)

    var source := TileSetAtlasSource.new()
    source.texture = tex
    source.texture_region_size = Vector2i(Constants.CELL_SIZE, Constants.CELL_SIZE)
    ts.add_source(source, 0)

    var half := Constants.CELL_SIZE / 2.0
    var poly := PackedVector2Array([
        Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
    ])
    for i in range(colors.size()):
        source.create_tile(Vector2i(i, 0))
        var data := source.get_tile_data(Vector2i(i, 0), 0)
        data.add_collision_polygon(0)
        data.set_collision_polygon_points(0, 0, poly)
    return ts

func _paint_tile(img: Image, index: int, base: Color, glinted: bool) -> void:
    var ox := index * Constants.CELL_SIZE
    var tile_rng := RandomNumberGenerator.new()
    tile_rng.seed = index * 977 + 13
    for py in range(Constants.CELL_SIZE):
        for px in range(Constants.CELL_SIZE):
            var jitter := tile_rng.randf_range(-0.07, 0.07)
            var c := base.lightened(jitter) if jitter > 0.0 else base.darkened(-jitter)
            img.set_pixel(ox + px, py, c)
    for i in range(Constants.CELL_SIZE):
        img.set_pixel(ox, i, base.darkened(0.35))
        img.set_pixel(ox + i, 0, base.darkened(0.35))

    if glinted:
        # A handful of bright glint specks so ore reads clearly against
        # the deliberately plain, flat regolith.
        var glint_count := 7
        for _i in range(glint_count):
            var gx := tile_rng.randi_range(3, Constants.CELL_SIZE - 4)
            var gy := tile_rng.randi_range(3, Constants.CELL_SIZE - 4)
            img.set_pixel(ox + gx, gy, base.lightened(0.65))
