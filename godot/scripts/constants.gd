extends RefCounted
class_name Constants

const CELL_SIZE := 32

const GRID_WIDTH := 40
const SURFACE_ROW := 5
const GRID_DEPTH := 90
const GRID_HEIGHT := SURFACE_ROW + GRID_DEPTH

# Atlas x-coordinate order matters -- keep in sync with Terrain._build_tile_set.
enum Tile { EMPTY = -1, ROCK = 0, GOLD_ORE = 1, NICKEL_ORE = 2, FUEL_ORE = 3, CRACKED = 4, HEAT_CORE = 5, BEDROCK = 6 }
